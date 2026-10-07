#ifndef KERNEL_H
#define KERNEL_H

#include <cstdio>
#include <cstdlib>
#include <cmath>

// Paramètres de l'algorithme DE/rand/1/bin (Qin et al.)
#define DE_F  0.5
#define DE_CR 0.3

// Identifiants des fonctions de test
enum BenchmarkFunc {
    FUNC_SPHERE     = 0,
    FUNC_RASTRIGIN  = 1,
    FUNC_ROSENBROCK = 2,
    FUNC_GRIEWANK   = 3
};

inline double get_bound_min(int func_id) {
    switch (func_id) {
        case FUNC_SPHERE:     return -100.0;
        case FUNC_RASTRIGIN:  return -5.0;
        case FUNC_ROSENBROCK: return -100.0;
        case FUNC_GRIEWANK:   return -600.0;
        default:              return -100.0;
    }
}

inline double get_bound_max(int func_id) {
    return -get_bound_min(func_id);
}

inline double get_optimum_value(int func_id) {
    switch (func_id) {
        case FUNC_SPHERE:     return -450.0;
        case FUNC_RASTRIGIN:  return -330.0;
        case FUNC_ROSENBROCK: return  390.0;
        case FUNC_GRIEWANK:   return -180.0;
        default:              return 0.0;
    }
}

const char* nom_fonction(int func_id);
double getRandom(double low, double high);
double host_fitness_function(const double x[], int dim, int func_id);

extern "C" void cuda_de(
    double *h_positions,
    double *h_best,
    int pop,
    int dim,
    int max_iter,
    int func,
    unsigned long seed
);

#endif // KERNEL_H