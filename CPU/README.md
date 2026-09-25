# DE séquentiel (version CPU de référence)

Implémentation séquentielle de l'algorithme d'Évolution Différentielle **DE/rand/1/bin**,
utilisée comme référence pour vérifier et comparer la version CUDA.

## Fichiers

| Fichier | Rôle |
|---|---|
| `benchmarks.h` / `benchmarks.cpp` | Les 4 fonctions benchmark (Rastrigin, Rosenbrock, Griewank, Sphere), leurs bornes et leurs minimums |
| `test_benchmarks.cpp` | Vérifie que chaque fonction donne bien son minimum en x = (0, ..., 0) |
| `de_sequentiel.cpp` | L'algorithme DE séquentiel |
| `Makefile` | Compilation |

## Compilation

```
make
```

ou sans make :

```
g++ -O2 -o de_sequentiel de_sequentiel.cpp benchmarks.cpp
g++ -O2 -o test_benchmarks test_benchmarks.cpp benchmarks.cpp
```

## Utilisation

```
./de_sequentiel <fonction> <dim> <pop> <graine>
```

- `fonction` : 1 = Rastrigin, 2 = Rosenbrock, 3 = Griewank, 4 = Sphere (mêmes numéros que la version GPU)
- `dim` : dimension du problème (10, 50, 100)
- `pop` : taille de la population (50, 100, 500)
- `graine` : graine aléatoire (un numéro différent par run)

Exemple :

```
./de_sequentiel 4 10 50 1
```

Sortie (une ligne CSV) :

```
fonction,dim,pop,graine,meilleure_valeur,erreur,temps_s
Sphere,10,50,1,-450.000000,0.000000e+00,0.0189
```

`erreur` = meilleure valeur trouvée − minimum connu (0 = minimum parfait).

## Paramètres

- F = 0.5, CR = 0.3 (comme dans Qin et al., GECCO 2012)
- Arrêt après 10⁴ × Dim évaluations de la fonction objectif
- Remplacement synchrone (toute la génération est mise à jour d'un coup, comme sur GPU)
- Une coordonnée qui sort des bornes est retirée au hasard dans les bornes

## Fonctions benchmark

| N° | Fonction | Bornes | Minimum f(x*) en x* = 0 |
|---|---|---|---|
| 1 | Shifted Rastrigin | [-5, 5] | -330 |
| 2 | Shifted Rosenbrock | [-100, 100] | 390 |
| 3 | Shifted Griewank | [-600, 600] | -180 |
| 4 | Shifted Sphere | [-100, 100] | -450 |

Le vecteur de décalage o vaut 0 (comme dans le code fourni).
