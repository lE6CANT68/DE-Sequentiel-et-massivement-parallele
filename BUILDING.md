# Guide de Compilation - DE CPU/GPU

Ce guide explique comment compiler et exécuter les versions CPU (séquentielle) et GPU (CUDA) de l'algorithme Differential Evolution.

## Prérequis

### Pour la version CPU
- **Windows** : MinGW-w64 (g++/gcc) ou MSVC
- **Linux/macOS** : g++ (généralement préinstallé)

### Pour la version GPU
- **NVIDIA CUDA Toolkit** (avec `nvcc` compilateur)
- **g++** ou **MSVC** pour la compilation du code hôte

### Vérifier les outils disponibles (Windows PowerShell)

```powershell
# Vérifier g++
Get-Command g++ -ErrorAction SilentlyContinue

# Vérifier nvcc (CUDA)
Get-Command nvcc -ErrorAction SilentlyContinue

# Vérifier cl.exe (MSVC)
Get-Command cl.exe -ErrorAction SilentlyContinue
```

---

## 📦 Compilation CPU (Séquentielle)

### Option 1 : PowerShell (Windows)
```powershell
cd CPU
.\build.ps1
```

Pour compiler ET tester :
```powershell
.\build.ps1 -Test
```

Pour nettoyer les fichiers de compilation :
```powershell
.\build.ps1 -Clean
```

### Option 2 : Ligne de commande directe (Windows/Linux/macOS)
```bash
cd CPU
g++ -O2 -o de_sequentiel de_sequentiel.cpp benchmarks.cpp
g++ -O2 -o test_benchmarks test_benchmarks.cpp benchmarks.cpp
```

### Option 3 : GNU Make (Linux/macOS ou MSYS2 sur Windows)
```bash
cd CPU
make
make test
```

---

## 🚀 Exécution CPU

### Tester les fonctions benchmark
```bash
./test_benchmarks
```

Sortie attendue :
```
Sphere     D=10   f(0) =  -450.000 (attendu  -450.0) OK   point au hasard : 1.234e+03 OK
Rastrigin  D=10   f(0) =  -330.000 (attendu  -330.0) OK   point au hasard : 2.567e+02 OK
...
Tous les tests sont OK.
```

### Optimiser une fonction benchmark

Format :
```
de_sequentiel <fonction> <dimension> <population> <seed> [strategie]
```

Stratégie (optionnelle) : `0` = DE/rand/1/bin (défaut), `1` = DE/best/1/bin, `2` = DE/current-to-best/1/bin, `3` = jDE. Détails dans [CPU/README.md](CPU/README.md).

Codes de fonction :
- `0` = Shifted Sphere
- `1` = Shifted Rastrigin
- `2` = Shifted Rosenbrock
- `3` = Shifted Griewank

Exemple : Optimiser Sphere (fonction 0) avec dimension 10, population 50, seed 1
```bash
./de_sequentiel 0 10 50 1
```

Résultat (CSV, en-tête avec `./de_sequentiel --entete`) :
```
version,strategie,fonction,dim,pop,graine,meilleure_valeur,erreur,temps_s
CPU,rand1,Sphere,10,50,1,-450.000000,0.000000e+00,0.012373
```

Campagne complète du sujet (4 fonctions × 3 dimensions × 3 populations × 10 runs), résultats dans `resultats/` :
```powershell
cd CPU
.\run_campagne.ps1
```

---

## 🎯 Compilation GPU (CUDA)

### Option 1 : PowerShell (Windows) 🟦
```powershell
cd GPU
.\build.ps1
```

Pour compiler ET exécuter un test :
```powershell
.\build.ps1 -Test
```

### Option 2 : Batch Windows
```cmd
cd GPU
build.bat
```

### Option 3 : GNU Make (Linux ou MSYS2 sur Windows)
```bash
cd GPU
make
make test
```

### Option 4 : Compilation manuelle

**Compiler le kernel CUDA :**
```bash
nvcc -O2 -arch=sm_50 -c kernel.cu -o kernel.obj
```

**Compiler les fichiers hôte (C++) :**
```bash
g++ -O2 -Wall -c main.cpp kernel.cpp benchmarks.cpp
```

**Linker :**
```bash
g++ -O2 -o de_gpu kernel.obj main.o kernel.o benchmarks.o -lcuda -lcudart
```

---

## 🚀 Exécution GPU

### Tester les fonctions benchmark
```bash
./test_benchmarks
```

### Optimiser une fonction (GPU)

Format :
```
de_gpu <dimension> <population>
```

**Note** : La fonction objectif est définie par la constante `SELECTED_OBJ_FUNC` dans `kernel.h` (ligne 16)

Valeurs possibles :
- `0` = Shifted Sphere (par défaut)
- `1` = Shifted Rastrigin
- `2` = Shifted Rosenbrock
- `3` = Shifted Griewank

Exemple : Optimiser Sphere avec dimension 10, population 50
```bash
./de_gpu 10 50
```

Pour changer la fonction, éditez `kernel.h` et recompilez :
```cpp
const int SELECTED_OBJ_FUNC = 0;  // Changer le numéro ici
```

---

## 🔧 Architecture de la Compilation

### CPU (Sequential)
```
benchmarks.cpp ─┐
de_sequentiel.cpp ─→ [g++] ─→ de_sequentiel.exe
```

### GPU (CUDA)
```
kernel.cu ───────────→ [nvcc] ──→ kernel.obj ──┐
main.cpp ────────────→ [g++] ───→ main.o ------→ [g++] ─→ de_gpu.exe
kernel.cpp ──────────→ [g++] ───→ kernel.o ────→ (link)
benchmarks.cpp ──────→ [g++] ───→ benchmarks.o ─→
```

---

## ⚙️ Paramètres DE (communs CPU/GPU)

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| **F** | 0.5 | Facteur d'échelle pour la mutation |
| **CR** | 0.3 | Taux de croisement |
| **Stratégie** | DE/rand/1/bin | Type de sélection et mutation |
| **Budget** | 10⁴ × Dim | Nombre total d'évaluations |
| **Remplacement** | Synchrone | Toute la génération mise à jour ensemble |

---

## 📊 Comparaison CPU vs GPU

| Aspect | CPU | GPU |
|--------|-----|-----|
| **Compilation** | g++ simple | CUDA + g++ |
| **Interface** | Ligne de commande | Ligne de commande |
| **Fonction** | Paramètre | Constante à éditer |
| **Vitesse** | Référence (100%) | À mesurer |
| **Synchronisation** | Implicite | Explicite (cudaDeviceSynchronize) |

---

## 🐛 Dépannage

### Erreur : "g++ not found"
**Windows** : Installez [MinGW-w64](https://www.mingw-w64.org/) et ajoutez le répertoire `bin` au PATH

### Erreur : "nvcc not found"
**Windows** : Installez [CUDA Toolkit](https://developer.nvidia.com/cuda-downloads) et ajoutez `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.X\bin` au PATH

### Erreur : Undefined reference to "cuda..."
Le linker CUDA est peut-être manquant. Assurez-vous que :
- CUDA Toolkit est correctement installé
- La variable d'environnement `CUDA_PATH` est définie

### Erreur : "cuda_runtime.h not found"
Défaut : ajouter le chemin d'inclusion CUDA lors de la compilation :
```bash
nvcc -I"C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.X\include" -c kernel.cu
```

---

## 📝 Fichiers modifiés dans cette correction

- ✅ `GPU/kernel.h` : CR corrigé (0.9 → 0.3)
- ✅ `CPU/benchmarks.h` : Enum harmonisée (0-3)
- ✅ `CPU/de_sequentiel.cpp` : Numéros de fonction 0-3 (comme le GPU), vérification des arguments, stratégies DE, sortie CSV commune
- ✅ `CPU/test_benchmarks.cpp` : Boucle 0-3
- ✅ `CPU/README.md` : Documentation mise à jour
- ✅ `GPU/Makefile` : Créé (Unix/Linux)
- ✅ `GPU/build.ps1` : Créé (Windows PowerShell)
- ✅ `GPU/build.bat` : Créé (Windows Batch)
- ✅ `CPU/build.ps1` : Créé (Windows PowerShell)

---

**Dernière mise à jour** : Septembre 2026
