#include "benchmarks.h"
#include <cmath>

// Valeur exacte de pi (l'ancien code utilisait 3.1415, trop imprécis)
const double PI = 3.14159265358979323846;

// Shifted Sphere : somme des z_i^2, minimum -450
static double sphere(const double* x, int dim) {
    double res = 0.0;
    for (int i = 0; i < dim; i++) {
        double z = x[i];                 // z = x - o, avec o = 0
        res += z * z;
    }
    return res - 450.0;
}

// Shifted Rastrigin : somme de (z_i^2 - 10 cos(2 pi z_i) + 10), minimum -330
static double rastrigin(const double* x, int dim) {
    double res = 0.0;
    for (int i = 0; i < dim; i++) {
        double z = x[i];
        res += z * z - 10.0 * cos(2.0 * PI * z) + 10.0;
    }
    return res - 330.0;
}

// Shifted Rosenbrock : z = x - o + 1, minimum 390 atteint en z = (1,...,1), donc x = 0
static double rosenbrock(const double* x, int dim) {
    double res = 0.0;
    for (int i = 0; i < dim - 1; i++) {
        double z  = x[i] + 1.0;
        double z1 = x[i + 1] + 1.0;
        res += 100.0 * (z * z - z1) * (z * z - z1) + (z - 1.0) * (z - 1.0);
    }
    return res + 390.0;
}

// Shifted Griewank : somme(z_i^2/4000) - produit(cos(z_i/sqrt(i))) + 1, minimum -180
static double griewank(const double* x, int dim) {
    double somme = 0.0;
    double produit = 1.0;                // CORRECTION : valait 0 dans le code fourni
    for (int i = 0; i < dim; i++) {
        double z = x[i];
        somme   += z * z / 4000.0;
        produit *= cos(z / sqrt((double)(i + 1)));
    }
    return somme - produit + 1.0 - 180.0;
}

double evaluer(int fonction, const double* x, int dim) {
    switch (fonction) {
        case SPHERE:     return sphere(x, dim);
        case RASTRIGIN:  return rastrigin(x, dim);
        case ROSENBROCK: return rosenbrock(x, dim);
        case GRIEWANK:   return griewank(x, dim);
    }
    return 0.0;
}

// Bornes données dans le sujet (CEC 2005)
double borneMin(int fonction) {
    switch (fonction) {
        case SPHERE:     return -100.0;
        case RASTRIGIN:  return -5.0;
        case ROSENBROCK: return -100.0;
        case GRIEWANK:   return -600.0;
    }
    return 0.0;
}

double borneMax(int fonction) {
    return -borneMin(fonction);          // les bornes sont symétriques
}

double valeurOptimum(int fonction) {
    switch (fonction) {
        case SPHERE:     return -450.0;
        case RASTRIGIN:  return -330.0;
        case ROSENBROCK: return  390.0;
        case GRIEWANK:   return -180.0;
    }
    return 0.0;
}

const char* nomFonction(int fonction) {
    switch (fonction) {
        case SPHERE:     return "Sphere";
        case RASTRIGIN:  return "Rastrigin";
        case ROSENBROCK: return "Rosenbrock";
        case GRIEWANK:   return "Griewank";
    }
    return "?";
}
