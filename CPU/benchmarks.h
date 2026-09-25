#ifndef BENCHMARKS_H
#define BENCHMARKS_H

// Numéro de chaque fonction benchmark
// (mêmes numéros que SELECTED_OBJ_FUNC dans le code GPU de Lorris)
// 1 = Rastrigin, 2 = Rosenbrock, 3 = Griewank, 4 = Sphere
enum Fonction { RASTRIGIN = 1, ROSENBROCK = 2, GRIEWANK = 3, SPHERE = 4 };

// Calcule f(x) pour un point x de dimension dim
double evaluer(int fonction, const double* x, int dim);

// Bornes de l'espace de recherche de chaque fonction
double borneMin(int fonction);
double borneMax(int fonction);

// Valeur du minimum global (le "biais"), atteinte en x = (0, ..., 0)
double valeurOptimum(int fonction);

// Nom lisible de la fonction (pour les affichages et les fichiers CSV)
const char* nomFonction(int fonction);

#endif
