#ifndef BENCHMARKS_H
#define BENCHMARKS_H

// Numéro de chaque fonction benchmark
// (0 = Sphere, 1 = Rastrigin, 2 = Rosenbrock, 3 = Griewank)
enum Fonction { SPHERE = 0, RASTRIGIN = 1, ROSENBROCK = 2, GRIEWANK = 3 };

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
