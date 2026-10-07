#include "kernel.h"
#include <iostream>
#include <vector>
#include <cstdlib>
#include <chrono>

int main(int argc, char** argv) {
    if (argc < 5) {
        std::cerr << "Usage : " << argv[0] << " <fonction> <dim> <pop> <graine>\n";
        return 1;
    }

    int fonction = std::stoi(argv[1]);
    int dim = std::stoi(argv[2]);
    int pop = std::stoi(argv[3]);
    unsigned long graine = std::stoul(argv[4]);

    if (fonction < 0 || fonction > 3 || dim <= 0 || pop <= 0) {
        std::cerr << "Paramètres invalides.\n";
        return 1;
    }

    // Budget imposé : 10^4 * Dim évaluations au total
    int max_evaluations = 10000 * dim;
    int max_iter = (max_evaluations / pop) - 1;

    std::vector<double> h_positions(pop * dim);
    std::vector<double> h_best(dim);

    std::srand(static_cast<unsigned>(graine));
    double bound_min = get_bound_min(fonction);
    double bound_max = get_bound_max(fonction);

    for (int i = 0; i < pop * dim; ++i) {
        h_positions[i] = getRandom(bound_min, bound_max);
    }

    auto debut = std::chrono::high_resolution_clock::now();

    cuda_de(
        h_positions.data(),
        h_best.data(),
        pop,
        dim,
        max_iter,
        fonction,
        graine
    );

    auto fin = std::chrono::high_resolution_clock::now();
    double temps = std::chrono::duration<double>(fin - debut).count();

    double meilleur_fitness = host_fitness_function(h_best.data(), dim, fonction);
    double optimum = get_optimum_value(fonction);
    double erreur = meilleur_fitness - optimum;

    // Ligne CSV : fonction,dimension,population,graine,meilleur_fitness,erreur,temps_sec
    printf("%s,%d,%d,%lu,%.6f,%.6e,%.4f\n",
           nom_fonction(fonction), dim, pop, graine, meilleur_fitness, erreur, temps);

    return 0;
}