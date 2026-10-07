// DE séquentiel - version de référence sur CPU
//
// Compilation : g++ -O2 -o de_sequentiel de_sequentiel.cpp benchmarks.cpp
// Utilisation : ./de_sequentiel <fonction> <dim> <pop> <graine> [strategie]
//   fonction  : 0 = Sphere, 1 = Rastrigin, 2 = Rosenbrock, 3 = Griewank
//               (mêmes numéros que dans le code GPU)
//   strategie : 0 = DE/rand/1/bin (par défaut, celle de l'article de Qin et al.)
//               1 = DE/best/1/bin
//               2 = DE/current-to-best/1/bin
//               3 = jDE : DE/rand/1/bin avec F et CR auto-adaptatifs (Brest et al., 2006)
//   exemple   : ./de_sequentiel 0 10 50 1
//
// Affiche une ligne CSV :
//   version,strategie,fonction,dim,pop,graine,meilleure_valeur,erreur,temps_s
// ./de_sequentiel --entete affiche seulement la ligne d'en-tête.

#include "benchmarks.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <random>
#include <chrono>

// Paramètres de DE (les mêmes que dans l'article de Qin et al.)
const double F  = 0.5;   // facteur d'échelle de la mutation
const double CR = 0.3;   // probabilité de croisement

// Paramètres de jDE (valeurs de l'article de Brest et al.)
const double TAU_F   = 0.1;   // probabilité de retirer F d'un individu
const double TAU_CR  = 0.1;   // probabilité de retirer CR d'un individu
const double F_MIN   = 0.1;   // le nouveau F est tiré dans [F_MIN, F_MIN + F_PLAGE]
const double F_PLAGE = 0.9;
const double F_INIT  = 0.5;   // valeurs de départ de chaque individu
const double CR_INIT = 0.9;

enum Strategie { RAND_1 = 0, BEST_1 = 1, CURRENT_TO_BEST_1 = 2, JDE = 3 };

const char* nomStrategie(int strategie) {
    switch (strategie) {
        case RAND_1:            return "rand1";
        case BEST_1:            return "best1";
        case CURRENT_TO_BEST_1: return "current-to-best1";
        case JDE:               return "jDE";
    }
    return "?";
}

int main(int argc, char** argv) {
    if (argc == 2 && strcmp(argv[1], "--entete") == 0) {
        printf("version,strategie,fonction,dim,pop,graine,meilleure_valeur,erreur,temps_s\n");
        return 0;
    }
    if (argc != 5 && argc != 6) {
        fprintf(stderr, "Utilisation : %s <fonction> <dim> <pop> <graine> [strategie]\n", argv[0]);
        fprintf(stderr, "  fonction  : 0 = Sphere, 1 = Rastrigin, 2 = Rosenbrock, 3 = Griewank\n");
        fprintf(stderr, "  strategie : 0 = rand/1 (defaut), 1 = best/1, 2 = current-to-best/1, 3 = jDE\n");
        return 1;
    }
    int fonction  = atoi(argv[1]);
    int dim       = atoi(argv[2]);
    int pop       = atoi(argv[3]);
    int graine    = atoi(argv[4]);
    int strategie = (argc == 6) ? atoi(argv[5]) : RAND_1;

    if (fonction < 0 || fonction > 3) {
        fprintf(stderr, "Erreur : la fonction doit valoir 0, 1, 2 ou 3.\n");
        return 1;
    }
    if (dim < 1) {
        fprintf(stderr, "Erreur : la dimension doit etre au moins 1.\n");
        return 1;
    }
    if (pop < 4) {   // il faut i, r1, r2, r3 tous différents
        fprintf(stderr, "Erreur : la population doit etre au moins 4.\n");
        return 1;
    }
    if (strategie < 0 || strategie > 3) {
        fprintf(stderr, "Erreur : la strategie doit valoir 0, 1, 2 ou 3.\n");
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

    // jDE : chaque individu a son propre F et son propre CR
    std::vector<double> Findiv(pop, F_INIT), CRindiv(pop, CR_INIT);
    std::vector<double> Fessais(pop), CRessais(pop);

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

        // Meilleur individu de la génération (utilisé par best/1 et current-to-best/1)
        int best = 0;
        for (int i = 1; i < pop; i++)
            if (fitness[i] < fitness[best]) best = i;

        for (int i = 0; i < pop; i++) {
            // --- Choisir r1, r2, r3 tous différents entre eux et de i ---
            int r1, r2, r3;
            do { r1 = aleaIndividu(gen); } while (r1 == i);
            do { r2 = aleaIndividu(gen); } while (r2 == i || r2 == r1);
            do { r3 = aleaIndividu(gen); } while (r3 == i || r3 == r1 || r3 == r2);

            // --- F et CR utilisés pour cet individu ---
            double Fi = F, CRi = CR;
            if (strategie == JDE) {
                // Avec une petite probabilité, on essaie de nouvelles valeurs ;
                // elles ne sont gardées que si l'essai remplace l'individu
                Fi  = (alea01(gen) < TAU_F)  ? F_MIN + F_PLAGE * alea01(gen) : Findiv[i];
                CRi = (alea01(gen) < TAU_CR) ? alea01(gen)                   : CRindiv[i];
                Fessais[i]  = Fi;
                CRessais[i] = CRi;
            }

            // --- Croisement : k garantit au moins une coordonnée venant du mutant ---
            int k = aleaDimension(gen);
            for (int j = 0; j < dim; j++) {
                if (alea01(gen) <= CRi || j == k) {
                    // Coordonnée du mutant V, selon la stratégie
                    double v;
                    switch (strategie) {
                        case BEST_1:              // V = X_best + F * (X_r1 - X_r2)
                            v = population[best * dim + j]
                              + Fi * (population[r1 * dim + j] - population[r2 * dim + j]);
                            break;
                        case CURRENT_TO_BEST_1:   // V = X_i + F * (X_best - X_i) + F * (X_r1 - X_r2)
                            v = population[i * dim + j]
                              + Fi * (population[best * dim + j] - population[i * dim + j])
                              + Fi * (population[r1 * dim + j] - population[r2 * dim + j]);
                            break;
                        default:                  // rand/1 et jDE : V = X_r1 + F * (X_r2 - X_r3)
                            v = population[r1 * dim + j]
                              + Fi * (population[r2 * dim + j] - population[r3 * dim + j]);
                    }
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
                if (strategie == JDE) {
                    Findiv[i]  = Fessais[i];
                    CRindiv[i] = CRessais[i];
                }
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

    printf("CPU,%s,%s,%d,%d,%d,%.6f,%.6e,%.6f\n",
           nomStrategie(strategie), nomFonction(fonction), dim, pop, graine,
           meilleur, erreur, temps);
    return 0;
}