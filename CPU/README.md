# DE séquentiel (version CPU de référence)

Implémentation séquentielle de l'algorithme d'Évolution Différentielle **DE/rand/1/bin**,
utilisée comme référence pour vérifier et comparer la version CUDA.
Trois autres stratégies sont disponibles pour la partie « améliorer la qualité des résultats » du sujet.

## Fichiers

| Fichier | Rôle |
|---|---|
| `benchmarks.h` / `benchmarks.cpp` | Les 4 fonctions benchmark (Sphere, Rastrigin, Rosenbrock, Griewank), leurs bornes et leurs minimums |
| `test_benchmarks.cpp` | Vérifie que chaque fonction donne bien son minimum en x = (0, ..., 0) |
| `de_sequentiel.cpp` | L'algorithme DE séquentiel |
| `build.ps1` | Compilation sous Windows (trouve tout seul le MinGW de `C:\mingw64`) |
| `run_campagne.ps1` | Lance toute la campagne du sujet et écrit les CSV dans `../resultats/` |
| `Makefile` | Compilation sous Linux / MSYS2 |

## Compilation

Windows (PowerShell) :

```
.\build.ps1          # compile
.\build.ps1 -Test    # compile + lance les tests
```

Linux / MSYS2 : `make`, ou sans make :

```
g++ -O2 -o de_sequentiel de_sequentiel.cpp benchmarks.cpp
g++ -O2 -o test_benchmarks test_benchmarks.cpp benchmarks.cpp
```

Sous Windows, `build.ps1` compile avec `-static` : les `.exe` se lancent sans avoir MinGW dans le PATH.

## Utilisation

```
./de_sequentiel <fonction> <dim> <pop> <graine> [strategie]
```

- `fonction` : 0 = Sphere, 1 = Rastrigin, 2 = Rosenbrock, 3 = Griewank
- `dim` : dimension du problème (10, 50, 100)
- `pop` : taille de la population (50, 100, 500), au moins 4
- `graine` : graine aléatoire (un numéro différent par run)
- `strategie` (optionnel) : 0 = DE/rand/1/bin (par défaut), 1 = DE/best/1/bin,
  2 = DE/current-to-best/1/bin, 3 = jDE

Exemple :

```
./de_sequentiel 0 10 50 1
```

Sortie (une ligne CSV, en-tête obtenu avec `./de_sequentiel --entete`) :

```
version,strategie,fonction,dim,pop,graine,meilleure_valeur,erreur,temps_s
CPU,rand1,Sphere,10,50,1,-450.000000,0.000000e+00,0.012373
```

`erreur` = meilleure valeur trouvée − minimum connu (0 = minimum parfait).
`temps_s` = temps de l'optimisation seule (initialisation comprise, sans le lancement du programme).

## Campagne d'expériences

```
.\run_campagne.ps1                       # DE/rand/1/bin : 4 fonctions x 3 dim x 3 pop x 10 runs
.\run_campagne.ps1 -Strategies 0,1,2,3   # toutes les stratégies
.\run_campagne.ps1 -Dims 10 -Runs 3      # version courte pour tester
```

Chaque stratégie donne un fichier `../resultats/cpu_<strategie>.csv` (360 lignes),
puis un résumé s'affiche : moyenne et écart-type de l'erreur, temps moyen,
taux de succès (erreur < 1e-8, comme dans l'article).

## Paramètres

- F = 0.5, CR = 0.3 (comme dans Qin et al., GECCO 2012)
- Arrêt après 10⁴ × Dim évaluations de la fonction objectif (initialisation comprise)
- Remplacement synchrone (toute la génération est mise à jour d'un coup, comme sur GPU)
- Une coordonnée qui sort des bornes est retirée au hasard dans les bornes

## Stratégies

Notations : X_i l'individu courant, X_best le meilleur de la génération, r1, r2, r3 trois
individus tirés au hasard, différents entre eux et de i.

| N° | Nom | Mutant V |
|---|---|---|
| 0 | DE/rand/1/bin | X_r1 + F (X_r2 − X_r3) |
| 1 | DE/best/1/bin | X_best + F (X_r1 − X_r2) |
| 2 | DE/current-to-best/1/bin | X_i + F (X_best − X_i) + F (X_r1 − X_r2) |
| 3 | jDE | comme rand/1, mais chaque individu a son propre F et son propre CR |

jDE (Brest et al., IEEE TEC 2006) : au départ F = 0.5 et CR = 0.9 pour chaque individu.
À chaque essai, avec une probabilité de 0.1, F est retiré dans [0.1, 1] et, avec une probabilité de 0.1,
CR est retiré dans [0, 1]. Les nouvelles valeurs ne sont gardées que si l'essai remplace l'individu :
les bons réglages survivent avec les bons individus.

## Fonctions benchmark

| N° | Fonction | Bornes | Minimum f(x*) en x* = 0 |
|---|---|---|---|
| 0 | Shifted Sphere | [-100, 100] | -450 |
| 1 | Shifted Rastrigin | [-5, 5] | -330 |
| 2 | Shifted Rosenbrock | [-100, 100] | 390 |
| 3 | Shifted Griewank | [-600, 600] | -180 |

Le vecteur de décalage o vaut 0 (comme dans le code fourni).
