#include "kernel.h"

#include <iostream>
#include <vector>
#include <cstdlib>
#include <ctime>

int main(int argc, char** argv) {
    // 1. Lecture des paramètres : ./program <dimension> <population>
    if (argc < 3) {
        std::cerr << "Usage : " << argv[0]
                  << " <dimension> <population>" << std::endl;
        return 1;
    }

    int dim = std::stoi(argv[1]);
    int pop = std::stoi(argv[2]);

    if (dim <= 0 || pop <= 0) {
        std::cerr << "Erreur : la dimension et la population doivent "
                  << "être positives." << std::endl;
        return 1;
    }

    // 2. Budget d'évaluations imposé : 10^4 * Dim
    int max_evaluations = 10000 * dim;
    int max_iter = max_evaluations / pop;

    std::cout << "--- Lancement DE (GPU) ---" << std::endl;
    std::cout << "Dimension : " << dim
              << " | Population : " << pop << std::endl;
    std::cout << "Nombre de generations : " << max_iter
              << " (" << max_evaluations << " evals)" << std::endl;

    // 3. Allocation dynamique sur l'hôte (CPU)
    std::vector<float> h_positions(pop * dim);
    std::vector<float> h_best(dim);

    // Initialisation du générateur aléatoire CPU
    std::srand(static_cast<unsigned>(std::time(nullptr)));

    float bound_min = get_bound_min(SELECTED_OBJ_FUNC);
    float bound_max = get_bound_max(SELECTED_OBJ_FUNC);

    for (int i = 0; i < pop * dim; ++i) {
        h_positions[i] = getRandom(bound_min, bound_max);
    }

    // 4. Appel du point d'entrée CUDA
    clock_t begin = std::clock();

    cuda_de(
        h_positions.data(),
        h_best.data(),
        pop,
        dim,
        max_iter
    );

    clock_t end = std::clock();

    // 5. Affichage des résultats
    double time_spent =
        static_cast<double>(end - begin) / CLOCKS_PER_SEC;

    std::cout << "Temps GPU : "
              << time_spent << " s" << std::endl;

    std::cout << "Meilleure fitness : "
              << host_fitness_function(h_best.data(), dim)
              << std::endl;

    return 0;
}