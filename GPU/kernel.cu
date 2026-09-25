#include <iostream>          // std::cout
#include <cstdlib>          // malloc, free
#include <ctime>            // time()
#include <cmath>             // fonctions mathématiques
#include <cuda_runtime.h>   // CUDA : cudaMalloc, cudaMemcpy, cudaFree...
#include <curand_kernel.h>  // cuRAND : curandState, curand_init, curand...

#include "kernel.h"

// ============================================================================
// 1. FONCTIONS OBJECTIF EXÉCUTÉES SUR GPU
// ============================================================================
__device__ float dev_fitness_function(const float *x, int dim) {
    float res = 0.0f;
    float somme = 0.0f;
    float produit = 1.0f;

    switch (SELECTED_OBJ_FUNC) {
        case 0: { // Shifted Sphere
            for (int i = 0; i < dim; i++) {
                float zi = x[i];
                res += zi * zi;
            }
            res -= 450.0f;
            break;
        }

        case 1: { // Shifted Rastrigin
            for (int i = 0; i < dim; i++) {
                float zi = x[i];
                res += zi * zi
                    - 10.0f * cosf(2.0f * phi * zi)
                    + 10.0f;
            }
            res -= 330.0f;
            break;
        }

        case 2: { // Shifted Rosenbrock
            for (int i = 0; i < dim - 1; i++) {
                float zi = x[i] + 1.0f;
                float zip1 = x[i + 1] + 1.0f;

                res += 100.0f * powf(zi * zi - zip1, 2.0f)
                    + powf(zi - 1.0f, 2.0f);
            }

            res += 390.0f;
            break;
        }

        case 3: { // Shifted Griewank
            for (int i = 0; i < dim; i++) {
                float zi = x[i];

                somme += zi * zi / 4000.0f;
                produit *= cosf(
                    zi / sqrtf((float)(i + 1))
                );
            }

            res = somme - produit + 1.0f - 180.0f;
            break;
        }
    }

    return res;
}

// ============================================================================
// 2. KERNEL D'INITIALISATION cuRAND
// ============================================================================
__global__ void initCurandKernel(
    curandState *states,
    unsigned long seed,
    int pop
) {
    int id = blockDim.x * blockIdx.x + threadIdx.x;

    if (id < pop) {
        curand_init(seed, id, 0, &states[id]);
    }
}

// ============================================================================
// 3. KERNEL IE (Initial Evaluation)
// ============================================================================
__global__ void kernelIE(
    const float *pop,
    float *fitness,
    int pop_size,
    int dim
) {
    int id = blockDim.x * blockIdx.x + threadIdx.x;

    if (id < pop_size) {
        fitness[id] =
            dev_fitness_function(&pop[id * dim], dim);
    }
}

// ============================================================================
// 4. KERNEL P
// Sélection de trois parents différents : r1, r2, r3
// ============================================================================
__global__ void kernelP(
    curandState *states,
    int *devR,
    int pop_size
) {
    int id = blockDim.x * blockIdx.x + threadIdx.x;

    if (id < pop_size) {

        curandState localState = states[id];

        int r1, r2, r3;

        do {
            r1 = curand(&localState) % pop_size;
        } while (r1 == id);

        do {
            r2 = curand(&localState) % pop_size;
        } while (r2 == id || r2 == r1);

        do {
            r3 = curand(&localState) % pop_size;
        } while (
            r3 == id ||
            r3 == r1 ||
            r3 == r2
        );

        devR[id * 3 + 0] = r1;
        devR[id * 3 + 1] = r2;
        devR[id * 3 + 2] = r3;

        states[id] = localState;
    }
}

// ============================================================================
// 5. KERNEL MCER
// Mutation, Croisement, Évaluation, Remplacement
// ============================================================================
__global__ void kernelMCER(
    float *pop,
    float *fitness,
    const int *devR,
    curandState *states,
    int pop_size,
    int dim,
    float F,
    float CR,
    float bound_min,
    float bound_max
) {
    int id = blockDim.x * blockIdx.x + threadIdx.x;

    if (id >= pop_size)
        return;

    curandState localState = states[id];

    int r1 = devR[id * 3 + 0];
    int r2 = devR[id * 3 + 1];
    int r3 = devR[id * 3 + 2];

    int j_rand = curand(&localState) % dim;

    // Vecteur d'essai
    // Dimension maximale fixée à 100 par le sujet
    float trial[100];

    // ------------------------------------------------------------
    // Mutation + Croisement
    // ------------------------------------------------------------
    for (int d = 0; d < dim; d++) {

        float rand_cr =
            curand_uniform(&localState);

        if (rand_cr < CR || d == j_rand) {

            // Mutation DE/rand/1
            float val =
                pop[r1 * dim + d]
                + F * (
                    pop[r2 * dim + d]
                    - pop[r3 * dim + d]
                );

            // Respect des bornes
            if (val < bound_min)
                val = bound_min;

            if (val > bound_max)
                val = bound_max;

            trial[d] = val;
        }
        else {
            trial[d] = pop[id * dim + d];
        }
    }

    // ------------------------------------------------------------
    // Évaluation
    // ------------------------------------------------------------
    float f_trial =
        dev_fitness_function(trial, dim);

    // ------------------------------------------------------------
    // Remplacement glouton
    // ------------------------------------------------------------
    if (f_trial <= fitness[id]) {

        fitness[id] = f_trial;

        for (int d = 0; d < dim; d++) {
            pop[id * dim + d] = trial[d];
        }
    }

    states[id] = localState;
}

// ============================================================================
// 6. FONCTION DE PILOTAGE GPU
// ============================================================================
extern "C" void cuda_de(
    float *h_positions,
    float *h_best,
    int pop,
    int dim,
    int max_iter
) {
    size_t size_pop =
        (size_t)pop * dim * sizeof(float);

    size_t size_fitness =
        (size_t)pop * sizeof(float);

    size_t size_r =
        (size_t)pop * 3 * sizeof(int);

    float *devPop = nullptr;
    float *devFitness = nullptr;

    int *devR = nullptr;

    curandState *devStates = nullptr;

    // ------------------------------------------------------------
    // Allocation mémoire GPU
    // ------------------------------------------------------------
    cudaMalloc(
        (void**)&devPop,
        size_pop
    );

    cudaMalloc(
        (void**)&devFitness,
        size_fitness
    );

    cudaMalloc(
        (void**)&devR,
        size_r
    );

    cudaMalloc(
        (void**)&devStates,
        pop * sizeof(curandState)
    );

    // ------------------------------------------------------------
    // CPU → GPU
    // ------------------------------------------------------------
    cudaMemcpy(
        devPop,
        h_positions,
        size_pop,
        cudaMemcpyHostToDevice
    );

    int threadsPerBlock = 128;

    int blocks =
        (pop + threadsPerBlock - 1)
        / threadsPerBlock;

    // ------------------------------------------------------------
    // Initialisation cuRAND
    // ------------------------------------------------------------
    initCurandKernel<<<blocks, threadsPerBlock>>>(
        devStates,
        (unsigned long)time(NULL),
        pop
    );

    cudaDeviceSynchronize();

    // ------------------------------------------------------------
    // Récupération des bornes
    // ------------------------------------------------------------
    float b_min =
        get_bound_min(SELECTED_OBJ_FUNC);

    float b_max =
        get_bound_max(SELECTED_OBJ_FUNC);

    // ------------------------------------------------------------
    // Évaluation initiale
    // ------------------------------------------------------------
    kernelIE<<<blocks, threadsPerBlock>>>(
        devPop,
        devFitness,
        pop,
        dim
    );

    cudaDeviceSynchronize();

    // ------------------------------------------------------------
    // Boucle principale Differential Evolution
    // ------------------------------------------------------------
    for (int iter = 0; iter < max_iter; ++iter) {

        // Sélection des parents
        kernelP<<<blocks, threadsPerBlock>>>(
            devStates,
            devR,
            pop
        );

        cudaDeviceSynchronize();

        // Mutation + Croisement
        // + Évaluation + Remplacement
        kernelMCER<<<blocks, threadsPerBlock>>>(
            devPop,
            devFitness,
            devR,
            devStates,
            pop,
            dim,
            F_WEIGHT,
            CR,
            b_min,
            b_max
        );

        cudaDeviceSynchronize();
    }

    // ------------------------------------------------------------
    // GPU → CPU
    // ------------------------------------------------------------
    float *h_fitness =
        (float*)malloc(size_fitness);

    cudaMemcpy(
        h_fitness,
        devFitness,
        size_fitness,
        cudaMemcpyDeviceToHost
    );

    cudaMemcpy(
        h_positions,
        devPop,
        size_pop,
        cudaMemcpyDeviceToHost
    );

    // ------------------------------------------------------------
    // Recherche du meilleur individu
    // ------------------------------------------------------------
    int best_idx = 0;

    float best_val =
        h_fitness[0];

    for (int i = 1; i < pop; i++) {

        if (h_fitness[i] < best_val) {
            best_val = h_fitness[i];
            best_idx = i;
        }
    }

    // ------------------------------------------------------------
    // Copie du meilleur individu
    // ------------------------------------------------------------
    for (int d = 0; d < dim; d++) {
        h_best[d] =
            h_positions[best_idx * dim + d];
    }

    // ------------------------------------------------------------
    // Libération mémoire
    // ------------------------------------------------------------
    free(h_fitness);

    cudaFree(devPop);
    cudaFree(devFitness);
    cudaFree(devR);
    cudaFree(devStates);
}
