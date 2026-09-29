#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <math.h>
#include <iostream>
#include <string>

/* Aligné sur benchmarks.h de Filip :
0: Shifted Sphere ([-100, 100], optimum = -450)
1: Shifted Rastrigin ([-5, 5], optimum = -330)
2: Shifted Rosenbrock ([-100, 100], optimum = 390)
3: Shifted Griewank ([-600, 600], optimum = -180)
*/
const int SELECTED_OBJ_FUNC = 0; // 0 = Sphere par défaut pour valider

// Paramètres DE classiques (alignés sur CPU)
const float F_WEIGHT = 0.5f;   // Facteur de mutation
const float CR = 0.3f;         // Taux de croisement (Qin et al.)

// Constante PI précise
const float phi = 3.141592653589793f;

// Bornes alignées sur benchmarks.cpp de Filip
inline float get_bound_min(int func_id) {
    switch (func_id) {
        case 0: return -100.0f; // Sphere
        case 1: return -5.0f;   // Rastrigin
        case 2: return -100.0f; // Rosenbrock
        case 3: return -600.0f; // Griewank
        default: return -100.0f;
    }
}

inline float get_bound_max(int func_id) {
    return -get_bound_min(func_id); // Bornes symétriques
}

// Utilitaires CPU
float getRandom(float low, float high);
float getRandomClamped();
float host_fitness_function(const float x[], int dim);

// Entrée GPU
extern "C" void cuda_de(float *h_positions, float *h_best, int pop, int dim, int max_iter);