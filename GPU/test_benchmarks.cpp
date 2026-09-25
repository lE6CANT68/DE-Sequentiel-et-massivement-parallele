// Test des fonctions benchmark
// Compilation : g++ -O2 -o test_benchmarks test_benchmarks.cpp benchmarks.cpp
#include "benchmarks.h"
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <vector>

int main() {
    int dims[] = {10, 50, 100};
    int erreurs = 0;

    for (int d = 0; d < 3; d++) {
        int dim = dims[d];
        std::vector<double> zero(dim, 0.0);      // le point (0, ..., 0)
        std::vector<double> autre(dim);          // un point au hasard

        for (int f = 0; f < 4; f++) {
            // Test 1 : en (0,...,0), on doit trouver exactement le minimum
            double v = evaluer(f, zero.data(), dim);
            bool ok1 = fabs(v - valeurOptimum(f)) < 1e-9;

            // Test 2 : n'importe quel autre point doit donner une valeur plus grande
            for (int i = 0; i < dim; i++)
                autre[i] = borneMin(f) + (borneMax(f) - borneMin(f)) * rand() / (double)RAND_MAX;
            double w = evaluer(f, autre.data(), dim);
            bool ok2 = w > valeurOptimum(f);

            printf("%-10s D=%-3d  f(0) = %9.3f (attendu %7.1f) %s   point au hasard : %.3e %s\n",
                   nomFonction(f), dim, v, valeurOptimum(f), ok1 ? "OK" : "ERREUR",
                   w, ok2 ? "OK" : "ERREUR");
            if (!ok1 || !ok2) erreurs++;
        }
    }

    printf("\n%s\n", erreurs == 0 ? "Tous les tests sont OK." : "Il y a des erreurs !");
    return erreurs;
}
