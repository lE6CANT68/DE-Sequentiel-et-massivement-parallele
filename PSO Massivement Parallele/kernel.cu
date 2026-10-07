#include <cuda_runtime.h>
#include <cuda.h>
#include <math_functions.h>

#include "kernel.h"

/* Objective function
0: Levy 3-dimensional
1: Shifted Rastigrin's Function
2: Shifted Rosenbrock's Function
3: Shifted Griewank's Function
4: Shifted Sphere's Function
*/
__device__ float fitness_function(float x[]) {
    float res = 0;
    float somme = 0;
    float produit = 0;

    switch (SELECTED_OBJ_FUNC)  {
        case 0: {
            float y1 = 1 + (x[0] - 1)/4;
            float yn = 1 + (x[NUM_OF_DIMENSIONS-1] - 1)/4;

            res += pow(sin(phi*y1), 2);

            for (int i = 0; i < NUM_OF_DIMENSIONS-1; i++) {
                float y = 1 + (x[i] - 1)/4;
                float yp = 1 + (x[i+1] - 1)/4;
                res += pow(y - 1, 2)*(1 + 10*pow(sin(phi*yp), 2)) + pow(yn - 1, 2);
            }
            break;
        }
        case 1: {
            for (int i = 0; i < NUM_OF_DIMENSIONS; i++) {
                float zi = x[i] - 0;
                res += pow(zi, 2) - 10*cos(2*phi*zi) + 10;
            }
            res -= 330;
            break;
        }
        case 2: {
            for (int i = 0; i < NUM_OF_DIMENSIONS-1; i++) {
                float zi = x[i] - 0 + 1;
                float zip1 = x[i+1] - 0 + 1;
                res += 100 * (pow(pow(zi, 2) - zip1, 2)) + pow(zi - 1, 2);
            }
            res += 390;
            break;
        }
        case 3: {
            produit = 1.0f; 
            for (int i = 0; i < NUM_OF_DIMENSIONS; i++) {
                float zi = x[i] - 0;
                somme += pow(zi, 2)/4000;
                produit *= cos(zi/pow((float)(i+1), 0.5f));
            }
            res = somme - produit + 1 - 180; 
            break;
        }
        case 4: {
            for(int i = 0; i < NUM_OF_DIMENSIONS; i++) {
                float zi = x[i] - 0;
                res += pow(zi, 2);
            }
            res -= 450;
            break;
        }
    }
    return res;
}

/**
 * Met à jour la vitesse et la position : 1 thread = 1 particule complète
*/
__global__ void kernelUpdateParticle(float *positions, float *velocities, 
                                     float *pBests, float *gBest, float r1, float r2)
{
    int tid = blockIdx.x * blockDim.x + threadIdx.x;

    if(tid >= NUM_OF_PARTICLES) return;

    int p_idx = tid * NUM_OF_DIMENSIONS;

    for (int d = 0; d < NUM_OF_DIMENSIONS; d++) {
        int idx = p_idx + d;
        velocities[idx] = OMEGA * velocities[idx] + 
                        c1 * r1 * (pBests[idx] - positions[idx]) + 
                        c2 * r2 * (gBest[d] - positions[idx]);

        positions[idx] += velocities[idx];
    }
}

/**
 * Evalue et met à jour les pBests : 1 thread = 1 particule
*/
__global__ void kernelUpdatePBest(float *positions, float *pBests)
{
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    
    if(tid >= NUM_OF_PARTICLES) return;

    int p_idx = tid * NUM_OF_DIMENSIONS;
    float tempPos[NUM_OF_DIMENSIONS];
    float tempPBest[NUM_OF_DIMENSIONS];

    for (int j = 0; j < NUM_OF_DIMENSIONS; j++) {
        tempPos[j] = positions[p_idx + j];
        tempPBest[j] = pBests[p_idx + j];
    }

    if (fitness_function(tempPos) < fitness_function(tempPBest)) {
        for (int k = 0; k < NUM_OF_DIMENSIONS; k++) {
            pBests[p_idx + k] = tempPos[k];
        }
    }
}

/**
 * Kernel de réduction parallèle pour trouver le gBest sur le GPU
 * Dimension de bloc attendue : >= NUM_OF_PARTICLES (ex: 512 threads, 1 seul bloc)
*/
__global__ void kernelUpdateGBest(float *pBests, float *gBest) 
{
    __shared__ float sharedFitness[NUM_OF_PARTICLES];
    __shared__ int sharedIndex[NUM_OF_PARTICLES];

    int tid = threadIdx.x;
    
    if (tid < NUM_OF_PARTICLES) {
        float temp[NUM_OF_DIMENSIONS];
        for (int d = 0; d < NUM_OF_DIMENSIONS; d++) {
            temp[d] = pBests[tid * NUM_OF_DIMENSIONS + d];
        }
        sharedFitness[tid] = fitness_function(temp);
        sharedIndex[tid] = tid;
    } else {
        sharedFitness[tid] = 1e30f; 
    }
    
    __syncthreads();
    for (int s = blockDim.x / 2; s > 0; s >>= 1) {
        if (tid < s && tid + s < NUM_OF_PARTICLES) {
            if (sharedFitness[tid + s] < sharedFitness[tid]) {
                sharedFitness[tid] = sharedFitness[tid + s];
                sharedIndex[tid] = sharedIndex[tid + s];
            }
        }
        __syncthreads();
    }
    if (tid == 0) {
        int bestIdx = sharedIndex[0];
        float bestSwarmFitness = sharedFitness[0];
        
        float tempG[NUM_OF_DIMENSIONS];
        for (int d = 0; d < NUM_OF_DIMENSIONS; d++) {
            tempG[d] = gBest[d];
        }
        
        if (bestSwarmFitness < fitness_function(tempG)) {
            for (int d = 0; d < NUM_OF_DIMENSIONS; d++) {
                gBest[d] = pBests[bestIdx * NUM_OF_DIMENSIONS + d];
            }
        }
    }
}

extern "C" void cuda_pso(float *positions, float *velocities, float *pBests, float *gBest)
{
    int size = NUM_OF_PARTICLES * NUM_OF_DIMENSIONS;
    
    float *devPos, *devVel, *devPBest, *devGBest;
        
    cudaMalloc((void**)&devPos, sizeof(float) * size);
    cudaMalloc((void**)&devVel, sizeof(float) * size);
    cudaMalloc((void**)&devPBest, sizeof(float) * size);
    cudaMalloc((void**)&devGBest, sizeof(float) * NUM_OF_DIMENSIONS);
    cudaMemcpy(devPos, positions, sizeof(float) * size, cudaMemcpyHostToDevice);
    cudaMemcpy(devVel, velocities, sizeof(float) * size, cudaMemcpyHostToDevice);
    cudaMemcpy(devPBest, pBests, sizeof(float) * size, cudaMemcpyHostToDevice);
    cudaMemcpy(devGBest, gBest, sizeof(float) * NUM_OF_DIMENSIONS, cudaMemcpyHostToDevice);
    int threadsNum = 256; 
    int blocksNum = (NUM_OF_PARTICLES + threadsNum - 1) / threadsNum;
    int reductionThreads = NUM_OF_PARTICLES; 
    
    for (int iter = 0; iter < MAX_ITER; iter++)
    {     
        kernelUpdateParticle<<<blocksNum, threadsNum>>>(devPos, devVel, 
                                                        devPBest, devGBest, 
                                                        getRandomClamped(), 
                                                        getRandomClamped());  

        kernelUpdatePBest<<<blocksNum, threadsNum>>>(devPos, devPBest);
        kernelUpdateGBest<<<1, reductionThreads>>>(devPBest, devGBest);
    }
    
    cudaMemcpy(positions, devPos, sizeof(float) * size, cudaMemcpyDeviceToHost);
    cudaMemcpy(velocities, devVel, sizeof(float) * size, cudaMemcpyDeviceToHost);
    cudaMemcpy(pBests, devPBest, sizeof(float) * size, cudaMemcpyDeviceToHost);
    cudaMemcpy(gBest, devGBest, sizeof(float) * NUM_OF_DIMENSIONS, cudaMemcpyDeviceToHost); 
    
    cudaFree(devPos);
    cudaFree(devVel);
    cudaFree(devPBest);
    cudaFree(devGBest);
}