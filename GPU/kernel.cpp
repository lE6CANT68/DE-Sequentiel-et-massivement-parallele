#include "kernel.h"

// Paramètre : 1 individu avec ses positions et sa dimension
float host_fitness_function(const float x[], int dim) {
    float res = 0.0f;
    float somme = 0.0f;
    float produit = 1.0f;

    switch (SELECTED_OBJ_FUNC) {
        case 0: { // 0 = Shifted Sphere
            for (int i = 0; i < dim; i++) {
                float zi = x[i];
                res += zi * zi;
            }
            res -= 450.0f;
            break;
        }
        case 1: { // 1 = Shifted Rastrigin
            for (int i = 0; i < dim; i++) {
                float zi = x[i];
                res += zi * zi - 10.0f * cosf(2.0f * phi * zi) + 10.0f;
            }
            res -= 330.0f;
            break;
        }
        case 2: { // 2 = Shifted Rosenbrock
            for (int i = 0; i < dim - 1; i++) {
                float zi = x[i] + 1.0f;
                float zip1 = x[i + 1] + 1.0f;
                res += 100.0f * powf(zi * zi - zip1, 2.0f) + powf(zi - 1.0f, 2.0f);
            }
            res += 390.0f;
            break;
        }
        case 3: { // 3 = Shifted Griewank
            for (int i = 0; i < dim; i++) {
                float zi = x[i];
                somme += zi * zi / 4000.0f;
                produit *= cosf(zi / sqrtf((float)(i + 1)));
            }
            res = somme - produit + 1.0f - 180.0f;
            break;
        }
    }
    return res;
}

// Obtenir un random entre low et high
float getRandom(float low, float high) {
    return low + float(((high - low) + 1.0f) * rand() / (RAND_MAX + 1.0));
}

// Obtenir un random entre 0.0f et 1.0f inclus
float getRandomClamped() {
    return (float) rand() / (float) RAND_MAX;
}