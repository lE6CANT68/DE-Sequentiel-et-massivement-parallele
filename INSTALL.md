# Installation des Compilateurs Nécessaires

## 🪟 Windows

### Pour la version CPU (Compiler g++)

#### Option 1 : MinGW-w64 (Recommandé)
```powershell
# 1. Télécharger depuis: https://www.mingw-w64.org/
#    Choisir: x86_64, posix, dwarf, latest version

# 2. Installer dans C:\mingw64\ (ou autre chemin simple sans espaces)

# 3. Ajouter au PATH:
#    - Ouvrir: Paramètres → Variables d'environnement
#    - Ajouter: C:\mingw64\bin
#    - Ou via PowerShell:
$env:Path += ";C:\mingw64\bin"

# 4. Vérifier l'installation
g++ --version
```

#### Option 2 : MSYS2 (Include MinGW)
```bash
# https://www.msys2.org/
# Installation graphique, puis dans terminal MSYS2:
pacman -S base-devel mingw-w64-x86_64-gcc mingw-w64-x86_64-gdb
```

---

### Pour la version GPU (Compiler CUDA + MSVC)

#### 1. Installer Visual Studio Community (Gratuit)

```powershell
# Télécharger: https://visualstudio.microsoft.com/fr/vs/community/
# 
# Lors de l'installation, cocher:
# ✓ Desktop development with C++
# ✓ MSVC v143 C++ compiler
#
# Cela installe cl.exe (généralement en:
# C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.X\bin\Hostx64\x64\
```

#### 2. Installer CUDA Toolkit 13.2

```powershell
# Télécharger: https://developer.nvidia.com/cuda-13-2-0-download-archive
# Choisir: Windows → x86_64 → Windows 10/11
#
# Installateur graphique (suivre les étapes)
# Location par défaut: C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.2
```

#### 3. Configurer les variables d'environnement

```powershell
# Ajouter CUDA à PATH:
$CudaPath = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.2\bin"
$env:Path += ";$CudaPath"

# Vérifier:
nvcc --version
cl.exe /?
```

---

## 🐧 Linux / WSL

### Installation (Ubuntu/Debian)

```bash
# Mise à jour des paquets
sudo apt update
sudo apt upgrade -y

# GCC/G++ (CPU)
sudo apt install -y build-essential g++ gcc

# CUDA Toolkit (GPU) - optionnel
# Voir: https://developer.nvidia.com/cuda-toolkit-archive

# Vérifier:
g++ --version
gcc --version
```

---

## 🍎 macOS

### Installation (Homebrew recommandé)

```bash
# Installer Homebrew si pas fait:
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# GCC/G++ (CPU)
brew install gcc

# Vérifier:
g++ --version

# Note: CUDA ne supporte pas macOS (GPU impossible)
#       Utiliser Metal GPU framework ou compiler sur Linux/Windows
```

---

## ✅ Vérifier l'Installation

### Windows PowerShell

```powershell
# Tous les compilateurs
Get-Command g++ -ErrorAction SilentlyContinue
Get-Command cl.exe -ErrorAction SilentlyContinue
Get-Command nvcc -ErrorAction SilentlyContinue

# Affichage de version
g++ --version
cl.exe
nvcc --version
```

### Linux/macOS

```bash
# Vérifier disponibilité
which g++
which gcc
which nvcc (Linux only)

# Affichage de version
g++ --version
gcc --version
nvcc --version  # Si CUDA installé
```

---

## 🔧 Dépannage

### Erreur : "g++ not found in PATH"

**Windows :**
```powershell
# 1. Vérifier l'installation
Get-ChildItem "C:\mingw64\bin\g++.exe" -ErrorAction SilentlyContinue

# 2. Ajouter à PATH manuellement:
$newPath = "C:\mingw64\bin"
$env:Path =  "$env:Path;$newPath"

# 3. Vérifier:
g++ --version
```

**Linux/macOS :**
```bash
# Réinstaller
sudo apt install build-essential  # Ubuntu/Debian
brew install gcc                   # macOS (si pas précédent)
```

---

### Erreur : "cl.exe not found in PATH"

**Solution :** VS Community ne trouve pas MSVC

```powershell
# 1. Vérifier l'installation VS:
Get-ChildItem "C:\Program Files*\Microsoft Visual Studio" -Filter "cl.exe" -Recurse

# 2. Ajouter VS Build Tools à PATH (si trouvé):
$vsPath = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.38.33130\bin\Hostx64\x64"
$env:Path += ";$vsPath"

# 3. Vérifier:
cl.exe /?
```

**Alternative :** Utiliser "x64 Native Tools Command Prompt for VS 2022" qui configure PATH automatiquement

---

### Erreur : "nvcc not found in PATH"

```powershell
# Vérifier installation CUDA:
Get-ChildItem "C:\Program Files\NVIDIA GPU Computing Toolkit" -Filter "nvcc.exe" -Recurse

# Ajouter à PATH:
$cudaPath = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.2\bin"
$env:Path += ";$cudaPath"

# Vérifier:
nvcc --version
```

---

## 📝 Résumé Installation Minimale

| Cible | Windows | Linux | macOS |
|-------|---------|-------|-------|
| **CPU** | MinGW-w64 | gcc/g++ | ?Homebrew gcc |
| **GPU** | Visual Studio + CUDA | CUDA Toolkit | ❌ Pas supporté |

---

## 🚀 Après Installation

Retournez à [../BUILDING.md](../BUILDING.md) pour compiler votre projet.

```powershell
cd CPU
.\build.ps1 -Test
cd ..\GPU
.\build.ps1 -Test
```

---

**Mise à jour :** Septembre 2026
