#include "kernel.h"

const char* nom_fonction(int func_id) {
    switch (func_id) {
        case FUNC_SPHERE:     return "Sphere";
        case FUNC_RASTRIGIN:  return "Rastrigin";
        case FUNC_ROSENBROCK: return "Rosenbrock";
        case FUNC_GRIEWANK:   return "Griewank";
        default:              return "Inconnue";
    }
}

double host_fitness_function(const double x[], int dim, int func_id) {
    double res = 0.0;
    double somme = 0.0;
    double produit = 1.0;

    switch (func_id) {
        case FUNC_SPHERE: {
            for (int i = 0; i < dim; i++) {
                double zi = x[i];
                res += zi * zi;
            }
            res -= 450.0;
            break;
        }
        case FUNC_RASTRIGIN: {
            for (int i = 0; i < dim; i++) {
                double zi = x[i];
                res += zi * zi - 10.0 * cos(2.0 * M_PI * zi) + 10.0;
            }
            res -= 330.0;
            break;
        }
        case FUNC_ROSENBROCK: {
            for (int i = 0; i < dim - 1; i++) {
                double zi = x[i] + 1.0;
                double zip1 = x[i + 1] + 1.0;
                res += 100.0 * pow(zi * zi - zip1, 2.0) + pow(zi - 1.0, 2.0);
            }
            res += 390.0;
            break;
        }
        case FUNC_GRIEWANK: {
            for (int i = 0; i < dim; i++) {
                double zi = x[i];
                somme += zi * zi / 4000.0;
                produit *= cos(zi / sqrt((double)(i + 1)));
            }
            res = somme - produit + 1.0 - 180.0;
            break;
        }
    }
    return res;
}

double getRandom(double low, double high) {
    return low + (high - low) * (double)rand() / (RAND_MAX + 1.0);
}