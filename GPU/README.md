# DE GPU (version CUDA de référence)

Implémentation CUDA de l'algorithme d'Évolution Différentielle **DE/rand/1/bin**, conforme aux spécifications du sujet.

## Fichiers

| Fichier | Rôle |
|---|---|
| `benchmarks.h` / `benchmarks.cpp` | Les 4 fonctions benchmark (Rastrigin, Rosenbrock, Griewank, Sphere), leurs bornes et leurs minimums |
| `kernel.h` / `kernel.cu` / `kernel.cpp` | Implémentation CUDA de l'algorithme DE |
| `main.cpp` | Point d'entrée et interface utilisateur |
| `test_benchmarks.cpp` | Vérifie que chaque fonction donne bien son minimum en x = (0, ..., 0) |
| `Makefile` | Compilation |

## Compilation

```
make
```

ou sans make :

```
nvcc -O2 -arch=sm_50 --use_fast_math -Xcompiler "-O2 -std=c++11" -o de_gpu main.cpp kernel.cu kernel.cpp benchmarks.cpp
g++ -O2 -std=c++11 -o test_benchmarks test_benchmarks.cpp benchmarks.cpp
```

## Utilisation

```
./de_gpu <fonction> <dim> <pop> <graine>
```

- `fonction` : 0 = Sphere, 1 = Rastrigin, 2 = Rosenbrock, 3 = Griewank
- `dim` : dimension du problème (10, 50, 100)
- `pop` : taille de la population (50, 100, 500)
- `graine` : graine aléatoire (pour reproductibilité)

Exemple :

```
./de_gpu 0 10 50 1
```

Sortie (une ligne CSV) :

```
fonction,dim,pop,graine,meilleure_valeur,erreur,temps_s
Sphere,10,50,1,-450.000000,0.000000e+00,0.0089
```

`erreur` = meilleure valeur trouvée − minimum connu (0 = minimum parfait).

## Conformité aux spécifications

Cette implémentation GPU est maintenant **entièrement conforme** aux spécifications du sujet :

- ✓ Variante `DE/rand/1/bin`
- ✓ Paramètres F = 0.5, CR = 0.3 (Qin et al., GECCO 2012)
- ✓ Budget : 10⁴ × Dim évaluations de la fonction objectif
- ✓ **Gestion des bornes** : coordonnée hors bornes = remplacement aléatoire uniforme (conforme)
- ✓ Remplacement synchrone (générationnel)
- ✓ 4 benchmarks avec formules exactes
- ✓ Reproductibilité : accepte graine en paramètre
- ✓ Format de sortie CSV (identique au CPU)

## Paramètres

- F = 0.5, CR = 0.3 (comme dans Qin et al., GECCO 2012)
- Arrêt après 10⁴ × Dim évaluations de la fonction objectif
- Remplacement synchrone (toute la génération est mise à jour d'un coup)
- Une coordonnée qui sort des bornes est remplacée par une valeur aléatoire **uniforme** dans les bornes

## Fonctions benchmark

| N° | Fonction | Bornes | Minimum f(x*) en x* = 0 |
|---|---|---|---|
| 0 | Shifted Sphere | [-100, 100] | -450 |
| 1 | Shifted Rastrigin | [-5, 5] | -330 |
| 2 | Shifted Rosenbrock | [-100, 100] | 390 |
| 3 | Shifted Griewank | [-600, 600] | -180 |

Le vecteur de décalage o vaut 0 (comme dans le code fourni).

## Architecture GPU

Le code CUDA utilise plusieurs kernels :

1. **Initialisation cuRAND** : Initialisation des générateurs de nombres aléatoires
2. **Évaluation initiale** : Évaluation de la population initiale
3. **Sélection des parents** : Sélection de trois indices parentaux distincts r1, r2, r3
4. **MCER** : Mutation + Croisement + Évaluation + Remplacement (en un seul kernel)

Tous les mécanismes de DE/rand/1/bin sont respectés.
