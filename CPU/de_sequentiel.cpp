// DE séquentiel (DE/rand/1/bin) - version de référence sur CPU
//
// Compilation : g++ -O2 -o de_sequentiel de_sequentiel.cpp benchmarks.cpp
// Utilisation : ./de_sequentiel <fonction> <dim> <pop> <graine>
//   fonction : 0 = Sphere, 1 = Rastrigin, 2 = Rosenbrock, 3 = Griewank
//   exemple  : ./de_sequentiel 0 10 50 1
//
// Affiche une ligne CSV :
//   fonction,dim,pop,graine,meilleure_valeur,erreur,temps_s

#include "benchmarks.h"
#include <cstdio>
#include <cstdlib>
#include <vector>
#include <random>
#include <chrono>

// Paramètres de DE (les mêmes que dans l'article de Qin et al.)
const double F  = 0.5;   // facteur d'échelle de la mutation
const double CR = 0.3;   // probabilité de croisement

int main(int argc, char** argv) {
    if (argc != 5) {
        printf("Utilisation : %s <fonction> <dim> <pop> <graine>\n", argv[0]);
        return 1;
    }
    int fonction = atoi(argv[1]);
    int dim      = atoi(argv[2]);
    int pop      = atoi(argv[3]);
    int graine   = atoi(argv[4]);

    // Vérifier que fonction est dans [0, 3]
    if (fonction < 0 || fonction > 3) {
        printf("Erreur : fonction doit être entre 0 et 3\n");
        return 1;
    }

    double bmin = borneMin(fonction);
    double bmax = borneMax(fonction);

    // Budget du sujet : 10^4 x Dim évaluations de la fonction
    long budget = 10000L * dim;
    long nbEvaluations = 0;

    // Générateur de nombres aléatoires (graine différente pour chaque run)
    std::mt19937 gen(graine);
    std::uniform_real_distribution<double> alea01(0.0, 1.0);
    std::uniform_real_distribution<double> aleaPosition(bmin, bmax);
    std::uniform_int_distribution<int> aleaIndividu(0, pop - 1);
    std::uniform_int_distribution<int> aleaDimension(0, dim - 1);

    // Les tableaux : population[i*dim + j] = coordonnée j de l'individu i
    std::vector<double> population(pop * dim);   // les individus actuels
    std::vector<double> fitness(pop);            // la valeur f de chacun
    std::vector<double> essais(pop * dim);       // les vecteurs d'essai U
    std::vector<double> fitnessEssais(pop);

    auto debut = std::chrono::high_resolution_clock::now();

    // ---------- 1. INITIALISATION : points au hasard dans les bornes ----------
    for (int i = 0; i < pop; i++) {
        for (int j = 0; j < dim; j++)
            population[i * dim + j] = aleaPosition(gen);
        fitness[i] = evaluer(fonction, &population[i * dim], dim);
        nbEvaluations++;
    }

    // ---------- 2. BOUCLE PRINCIPALE : une génération par tour ----------
    // On s'arrête quand il ne reste plus assez de budget pour une génération entière
    while (nbEvaluations + pop <= budget) {

        for (int i = 0; i < pop; i++) {
            // --- Mutation : choisir r1, r2, r3 tous différents entre eux et de i ---
            int r1, r2, r3;
            do { r1 = aleaIndividu(gen); } while (r1 == i);
            do { r2 = aleaIndividu(gen); } while (r2 == i || r2 == r1);
            do { r3 = aleaIndividu(gen); } while (r3 == i || r3 == r1 || r3 == r2);

            // --- Croisement : k garantit au moins une coordonnée venant du mutant ---
            int k = aleaDimension(gen);
            for (int j = 0; j < dim; j++) {
                if (alea01(gen) <= CR || j == k) {
                    // Coordonnée du mutant : V = X_r1 + F * (X_r2 - X_r3)
                    double v = population[r1 * dim + j]
                             + F * (population[r2 * dim + j] - population[r3 * dim + j]);
                    // Si on sort des bornes, on retire au hasard dans les bornes
                    if (v < bmin || v > bmax) v = aleaPosition(gen);
                    essais[i * dim + j] = v;
                } else {
                    // Coordonnée de l'individu actuel
                    essais[i * dim + j] = population[i * dim + j];
                }
            }

            // --- Évaluation du vecteur d'essai ---
            fitnessEssais[i] = evaluer(fonction, &essais[i * dim], dim);
            nbEvaluations++;
        }

        // --- Remplacement : l'essai remplace l'individu s'il est meilleur ou égal ---
        // (fait après la boucle, comme sur GPU où tous les individus avancent en même temps)
        for (int i = 0; i < pop; i++) {
            if (fitnessEssais[i] <= fitness[i]) {
                for (int j = 0; j < dim; j++)
                    population[i * dim + j] = essais[i * dim + j];
                fitness[i] = fitnessEssais[i];
            }
        }
    }

    auto fin = std::chrono::high_resolution_clock::now();
    double temps = std::chrono::duration<double>(fin - debut).count();

    // ---------- 3. RÉSULTAT : le meilleur individu trouvé ----------
    double meilleur = fitness[0];
    for (int i = 1; i < pop; i++)
        if (fitness[i] < meilleur) meilleur = fitness[i];

    double erreur = meilleur - valeurOptimum(fonction);   // 0 = minimum parfait

    printf("%s,%d,%d,%d,%.6f,%.6e,%.4f\n",
           nomFonction(fonction), dim, pop, graine, meilleur, erreur, temps);
    return 0;
}
