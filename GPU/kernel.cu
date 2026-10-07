#include "kernel.h"
#include <cuda_runtime.h>
#include <curand_kernel.h>
#include <cmath>
#include <cstdio>

#define CONST_PI 3.14159265358979323846

// ============================================================================
// 1. RÉDUCTION PARALLÈLE DE FITNESS EN MÉMOIRE PARTAGÉE
// ============================================================================
__device__ double reduce_fitness_shmem(
    const double *trial,
    int dim,
    int func,
    int block_dim,
    double *s_sum,
    double *s_prod
) {
    int tid = threadIdx.x;

    double term_sum = 0.0;
    double term_prod = 1.0;

    if (tid < dim) {
        double z = trial[tid];
        switch (func) {
            case FUNC_SPHERE:
                term_sum = z * z;
                break;
            case FUNC_RASTRIGIN:
                term_sum = z * z - 10.0 * cos(2.0 * CONST_PI * z) + 10.0;
                break;
            case FUNC_ROSENBROCK:
                if (tid < dim - 1) {
                    double z_cur = trial[tid] + 1.0;
                    double z_next = trial[tid + 1] + 1.0;
                    term_sum = 100.0 * (z_cur * z_cur - z_next) * (z_cur * z_cur - z_next)
                             + (z_cur - 1.0) * (z_cur - 1.0);
                }
                break;
            case FUNC_GRIEWANK:
                term_sum = (z * z) / 4000.0;
                term_prod = cos(z / sqrt((double)(tid + 1)));
                break;
        }
    }

    s_sum[tid] = term_sum;
    if (func == FUNC_GRIEWANK) {
        s_prod[tid] = term_prod;
    }
    __syncthreads();

    // Arbre binaire de réduction
    for (int s = block_dim / 2; s > 0; s >>= 1) {
        if (tid < s) {
            s_sum[tid] += s_sum[tid + s];
            if (func == FUNC_GRIEWANK) {
                s_prod[tid] *= s_prod[tid + s];
            }
        }
        __syncthreads();
    }

    // Le thread 0 écrit le score final avec le biais
    if (tid == 0) {
        double val = 0.0;
        switch (func) {
            case FUNC_SPHERE:     val = s_sum[0] - 450.0; break;
            case FUNC_RASTRIGIN:  val = s_sum[0] - 330.0; break;
            case FUNC_ROSENBROCK: val = s_sum[0] + 390.0; break;
            case FUNC_GRIEWANK:   val = s_sum[0] - s_prod[0] + 1.0 - 180.0; break;
        }
        s_sum[0] = val;
    }
    __syncthreads();

    return s_sum[0];
}

// ============================================================================
// 2. INITIALISATIONS CURAND
// ============================================================================
__global__ void initCurandPop(
    curandState *states_P,
    curandState *states_scalar,
    unsigned long seed,
    int pop_size
) {
    int g_tid = blockDim.x * blockIdx.x + threadIdx.x;
    if (g_tid < pop_size) {
        curand_init(seed, g_tid, 0, &states_P[g_tid]);
        curand_init(seed + 99999UL, g_tid, 0, &states_scalar[g_tid]);
    }
}

__global__ void initCurandMCER(
    curandState *states_MCER,
    unsigned long seed,
    size_t total_threads
) {
    size_t g_tid = (size_t)blockDim.x * blockIdx.x + threadIdx.x;
    if (g_tid < total_threads) {
        curand_init(seed + 1337UL, g_tid, 0, &states_MCER[g_tid]);
    }
}

// ============================================================================
// 3. KERNEL IE : INITIALISATION & ÉVALUATION
// ============================================================================
__global__ void kernelIE(
    const double *pop,
    double *fitness,
    int dim,
    int func
) {
    extern __shared__ double s_mem[];
    int tpb = blockDim.x;
    double *s_sum = s_mem;
    double *s_prod = &s_mem[tpb];

    int ind_id = blockIdx.x;
    const double *ind_vec = &pop[ind_id * dim];

    double f = reduce_fitness_shmem(ind_vec, dim, func, tpb, s_sum, s_prod);

    if (threadIdx.x == 0) {
        fitness[ind_id] = f;
    }
}

// ============================================================================
// 4. KERNEL P : SÉLECTION DES INDICES EXCLUSIFS r1, r2, r3
// ============================================================================
__global__ void kernelP(
    curandState *states_P,
    int *devR,
    int pop_size
) {
    int id = blockDim.x * blockIdx.x + threadIdx.x;
    if (id >= pop_size) return;

    curandState localState = states_P[id];
    int r1, r2, r3;

    do {
        r1 = curand(&localState) % pop_size;
    } while (r1 == id);

    do {
        r2 = curand(&localState) % pop_size;
    } while (r2 == id || r2 == r1);

    do {
        r3 = curand(&localState) % pop_size;
    } while (r3 == id || r3 == r1 || r3 == r2);

    devR[id * 3 + 0] = r1;
    devR[id * 3 + 1] = r2;
    devR[id * 3 + 2] = r3;

    states_P[id] = localState;
}

// ============================================================================
// 5. KERNEL MCER : MUTATION, CROISEMENT, ÉVALUATION ET REMPLACEMENT FUSIONNÉS
// ============================================================================
__global__ void kernelMCER(
    const double *popOld,
    double *popNew,
    double *fitness,
    const int *devR,
    curandState *states_MCER,
    curandState *states_scalar,
    int pop_size,
    int dim,
    double F,
    double CR,
    double b_min,
    double b_max,
    int func
) {
    int ind_id = blockIdx.x;
    int tid = threadIdx.x;
    int tpb = blockDim.x;

    extern __shared__ double s_data[];
    double *s_trial = s_data;
    double *s_sum   = &s_data[tpb];
    double *s_prod  = &s_data[2 * tpb];

    __shared__ int r1, r2, r3, j_rand;
    __shared__ double old_fit;
    __shared__ volatile bool accepted;

    if (tid == 0) {
        curandState s_state = states_scalar[ind_id];
        r1 = devR[ind_id * 3 + 0];
        r2 = devR[ind_id * 3 + 1];
        r3 = devR[ind_id * 3 + 2];
        j_rand = curand(&s_state) % dim;
        old_fit = fitness[ind_id];
        states_scalar[ind_id] = s_state;
    }
    __syncthreads();

    int state_idx = ind_id * tpb + tid;
    curandState localState = states_MCER[state_idx];

    if (tid < dim) {
        double rand_cr = curand_uniform_double(&localState);

        if (rand_cr < CR || tid == j_rand) {
            double v = popOld[r1 * dim + tid] + F * (popOld[r2 * dim + tid] - popOld[r3 * dim + tid]);
            if (v < b_min || v > b_max) {
                v = curand_uniform_double(&localState) * (b_max - b_min) + b_min;
            }
            s_trial[tid] = v;
        } else {
            s_trial[tid] = popOld[ind_id * dim + tid];
        }
    }
    states_MCER[state_idx] = localState;
    __syncthreads();

    double f_trial = reduce_fitness_shmem(s_trial, dim, func, tpb, s_sum, s_prod);

    if (tid == 0) {
        bool is_better = (f_trial <= old_fit);
        accepted = is_better;
        if (is_better) {
            fitness[ind_id] = f_trial;
        }
    }
    __syncthreads();

    if (tid < dim) {
        popNew[ind_id * dim + tid] = accepted ? s_trial[tid] : popOld[ind_id * dim + tid];
    }
}

// ============================================================================
// 6. FONCTION HÔTE DE PILOTAGE GPU (cudaDE_i)
// ============================================================================
extern "C" void cuda_de(
    double *h_positions,
    double *h_best,
    int pop,
    int dim,
    int max_iter,
    int func,
    unsigned long seed
) {
    size_t size_pop = (size_t)pop * dim * sizeof(double);
    size_t size_fit = (size_t)pop * sizeof(double);
    size_t size_r   = (size_t)pop * 3 * sizeof(int);

    int tpb = 32;
    while (tpb < dim && tpb < 1024) {
        tpb <<= 1;
    }

    size_t total_mcer_threads = (size_t)pop * tpb;

    double *d_pop[2];
    int *d_R[2];
    double *d_fitness;
    curandState *d_states_P;
    curandState *d_states_MCER;
    curandState *d_states_scalar;

    cudaMalloc((void**)&d_pop[0], size_pop);
    cudaMalloc((void**)&d_pop[1], size_pop);
    cudaMalloc((void**)&d_R[0], size_r);
    cudaMalloc((void**)&d_R[1], size_r);
    cudaMalloc((void**)&d_fitness, size_fit);

    cudaMalloc((void**)&d_states_P, pop * sizeof(curandState));
    cudaMalloc((void**)&d_states_scalar, pop * sizeof(curandState));
    cudaMalloc((void**)&d_states_MCER, total_mcer_threads * sizeof(curandState));

    cudaMemcpy(d_pop[0], h_positions, size_pop, cudaMemcpyHostToDevice);

    int tpb_init = 128;
    int b_pop = (pop + tpb_init - 1) / tpb_init;
    initCurandPop<<<b_pop, tpb_init>>>(d_states_P, d_states_scalar, seed, pop);

    int b_mcer = (int)((total_mcer_threads + tpb_init - 1) / tpb_init);
    initCurandMCER<<<b_mcer, tpb_init>>>(d_states_MCER, seed, total_mcer_threads);
    cudaDeviceSynchronize();

    size_t shmem_ie   = (size_t)2 * tpb * sizeof(double);

    int alloc_dim = (dim > tpb) ? dim : tpb;
    size_t shmem_mcer = (size_t)(3 * tpb) * sizeof(double);
    
    double b_min = get_bound_min(func);
    double b_max = get_bound_max(func);

    // Évaluation initiale de la population
    kernelIE<<<pop, tpb, shmem_ie>>>(d_pop[0], d_fitness, dim, func);
    cudaDeviceSynchronize();

    // Configuration des Streams et Events
    cudaStream_t stream_compute, stream_prep;
    cudaStreamCreate(&stream_compute);
    cudaStreamCreate(&stream_prep);

    cudaEvent_t event_P[2];
    cudaEvent_t event_MCER[2];
    for (int i = 0; i < 2; ++i) {
        cudaEventCreate(&event_P[i]);
        cudaEventCreate(&event_MCER[i]);
    }

    int b_p = (pop + tpb_init - 1) / tpb_init;

    // Pré-génération pour la première itération
    kernelP<<<b_p, tpb_init, 0, stream_prep>>>(d_states_P, d_R[0], pop);
    cudaEventRecord(event_P[0], stream_prep);

    int p_read = 0;
    int r_idx = 0;

    for (int iter = 0; iter < max_iter; ++iter) {
        int p_write = 1 - p_read;
        int next_r = 1 - r_idx;

        if (iter + 1 < max_iter) {
            if (iter > 0) {
                cudaStreamWaitEvent(stream_prep, event_MCER[next_r], 0);
            }
            kernelP<<<b_p, tpb_init, 0, stream_prep>>>(d_states_P, d_R[next_r], pop);
            cudaEventRecord(event_P[next_r], stream_prep);
        }

        cudaStreamWaitEvent(stream_compute, event_P[r_idx], 0);

        kernelMCER<<<pop, tpb, shmem_mcer, stream_compute>>>(
            d_pop[p_read], d_pop[p_write], d_fitness, d_R[r_idx],
            d_states_MCER, d_states_scalar, pop, dim, DE_F, DE_CR, b_min, b_max, func
        );
        cudaEventRecord(event_MCER[r_idx], stream_compute);

        p_read = p_write;
        r_idx = next_r;
    }

    cudaStreamSynchronize(stream_compute);

    // Récupération des résultats sur l'hôte
    double *h_fitness = (double*)malloc(size_fit);
    cudaMemcpy(h_fitness, d_fitness, size_fit, cudaMemcpyDeviceToHost);
    cudaMemcpy(h_positions, d_pop[p_read], size_pop, cudaMemcpyDeviceToHost);

    int best_idx = 0;
    double best_val = h_fitness[0];
    for (int i = 1; i < pop; ++i) {
        if (h_fitness[i] < best_val) {
            best_val = h_fitness[i];
            best_idx = i;
        }
    }
    for (int d = 0; d < dim; ++d) {
        h_best[d] = h_positions[best_idx * dim + d];
    }

    free(h_fitness);
    for (int i = 0; i < 2; ++i) {
        cudaEventDestroy(event_P[i]);
        cudaEventDestroy(event_MCER[i]);
    }
    cudaStreamDestroy(stream_compute);
    cudaStreamDestroy(stream_prep);
    cudaFree(d_pop[0]);
    cudaFree(d_pop[1]);
    cudaFree(d_R[0]);
    cudaFree(d_R[1]);
    cudaFree(d_fitness);
    cudaFree(d_states_P);
    cudaFree(d_states_MCER);
    cudaFree(d_states_scalar);
}