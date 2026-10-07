# Build script for CPU version on Windows (PowerShell)
# Requires: G++ or MSVC compiler

param(
    [switch]$Clean = $false,
    [switch]$Test = $false
)

Write-Host "========================================" -ForegroundColor Green
Write-Host "DE CPU Build Script (Windows PowerShell)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Check if G++ is available (otherwise try the MinGW installed in C:\mingw64)
$cxxPath = Get-Command g++ -ErrorAction SilentlyContinue
if (-not $cxxPath -and (Test-Path "C:\mingw64\bin\g++.exe")) {
    $env:Path = "C:\mingw64\bin;$env:Path"
    $cxxPath = Get-Command g++ -ErrorAction SilentlyContinue
}
if (-not $cxxPath) {
    Write-Host "ERROR: G++ not found in PATH" -ForegroundColor Red
    Write-Host "Please install MinGW-w64 and ensure g++.exe is in PATH" -ForegroundColor Yellow
    exit 1
}

if ($Clean) {
    Write-Host "Cleaning build artifacts..." -ForegroundColor Cyan
    Remove-Item -Force -ErrorAction SilentlyContinue *.o, de_sequentiel.exe, test_benchmarks.exe
    Write-Host "Clean complete." -ForegroundColor Green
    Write-Host ""
}

$CXX_FLAGS = "-O2", "-Wall", "-static"   # -static : pas besoin des DLL MinGW pour lancer les .exe
$SEQ_EXE = "de_sequentiel.exe"
$TEST_EXE = "test_benchmarks.exe"

Write-Host "Compiling sequential DE..." -ForegroundColor Cyan
try {
    & g++ @CXX_FLAGS -o $SEQ_EXE de_sequentiel.cpp benchmarks.cpp
    if ($LASTEXITCODE -ne 0) { throw "Compilation failed" }
} catch {
    Write-Host "ERROR: Failed to compile de_sequentiel" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host "Compiling benchmark tests..." -ForegroundColor Cyan
try {
    & g++ @CXX_FLAGS -o $TEST_EXE test_benchmarks.cpp benchmarks.cpp
    if ($LASTEXITCODE -ne 0) { throw "Compilation failed" }
} catch {
    Write-Host "ERROR: Failed to compile test_benchmarks" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Build successful!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Executables:" -ForegroundColor Cyan
Write-Host "  $SEQ_EXE" -ForegroundColor White
Write-Host "  $TEST_EXE" -ForegroundColor White
Write-Host ""
Write-Host "Usage:" -ForegroundColor Yellow
Write-Host "  .\$SEQ_EXE <fonction> <dimension> <population> <seed> [strategie]" -ForegroundColor White
Write-Host ""
Write-Host "Function codes (0-3):" -ForegroundColor Cyan
Write-Host "  0 = Shifted Sphere" -ForegroundColor Gray
Write-Host "  1 = Shifted Rastrigin" -ForegroundColor Gray
Write-Host "  2 = Shifted Rosenbrock" -ForegroundColor Gray
Write-Host "  3 = Shifted Griewank" -ForegroundColor Gray
Write-Host ""
Write-Host "Strategies (optionnel, 0 par defaut):" -ForegroundColor Cyan
Write-Host "  0 = DE/rand/1/bin   1 = DE/best/1/bin" -ForegroundColor Gray
Write-Host "  2 = DE/current-to-best/1/bin   3 = jDE" -ForegroundColor Gray
Write-Host ""
Write-Host "Example:" -ForegroundColor Yellow
Write-Host "  .\$SEQ_EXE 0 10 50 1" -ForegroundColor White
Write-Host ""

if ($Test) {
    Write-Host "Running tests..." -ForegroundColor Cyan
    & ".\$TEST_EXE"
    Write-Host ""
    Write-Host "Running benchmark (Sphere, dim=10, pop=50, seed=1)..." -ForegroundColor Cyan
    & ".\$SEQ_EXE" 0 10 50 1
}
