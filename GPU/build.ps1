# Build script for GPU version on Windows (PowerShell)
# Requires: CUDA Toolkit (nvcc in PATH)

param(
    [switch]$Clean = $false,
    [switch]$Test = $false
)

Write-Host "========================================" -ForegroundColor Green
Write-Host "DE GPU Build Script (Windows PowerShell)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Check if NVCC is available
$nvccPath = Get-Command nvcc -ErrorAction SilentlyContinue
if (-not $nvccPath) {
    Write-Host "ERROR: NVCC not found in PATH" -ForegroundColor Red
    Write-Host "Please install CUDA Toolkit and ensure nvcc.exe is in PATH" -ForegroundColor Yellow
    exit 1
}

# Check if G++ is available
$cxxPath = Get-Command g++ -ErrorAction SilentlyContinue
if (-not $cxxPath) {
    Write-Host "WARNING: G++ not found in PATH" -ForegroundColor Yellow
    Write-Host "Will attempt to use MSVC (cl.exe)..." -ForegroundColor Yellow
    $USE_MSVC = $true
}

if ($Clean) {
    Write-Host "Cleaning build artifacts..." -ForegroundColor Cyan
    Remove-Item -Force -ErrorAction SilentlyContinue *.obj, *.o, de_gpu.exe, test_benchmarks.exe
    Write-Host "Clean complete." -ForegroundColor Green
    Write-Host ""
}

$NVCC_FLAGS = "-O2", "-arch=sm_70"
$CUDA_EXE = "de_gpu.exe"
$TEST_EXE = "test_benchmarks.exe"

Write-Host "Step 1: Compiling CUDA kernel (kernel.cu)..." -ForegroundColor Cyan
try {
    & nvcc @NVCC_FLAGS -c kernel.cu -o kernel.obj
    if ($LASTEXITCODE -ne 0) { throw "NVCC compilation failed" }
} catch {
    Write-Host "ERROR: Failed to compile kernel.cu" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host "Step 2: Compiling host C++ files..." -ForegroundColor Cyan
try {
    if ($USE_MSVC) {
        Write-Host "Using MSVC compiler" -ForegroundColor Yellow
        Write-Host "Note: MSVC linking support may require manual adjustment" -ForegroundColor Yellow
    } else {
        Write-Host "Using G++ compiler" -ForegroundColor Green
        & g++ -O2 -Wall -I. -c main.cpp -o main.o
        & g++ -O2 -Wall -I. -c kernel.cpp -o kernel.o
        & g++ -O2 -Wall -I. -c benchmarks.cpp -o benchmarks.o
        if ($LASTEXITCODE -ne 0) { throw "G++ compilation failed" }
    }
} catch {
    Write-Host "ERROR: Failed to compile C++ files" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host "Step 3: Linking..." -ForegroundColor Cyan
try {
    & g++ -O2 -o $CUDA_EXE kernel.obj main.o kernel.o benchmarks.o -lcuda -lcudart -L"$env:CUDA_PATH\lib\x64" 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Linking failed" }
} catch {
    Write-Host "WARNING: Linking with standard flags may have failed" -ForegroundColor Yellow
    Write-Host "Attempting alternative linking method..." -ForegroundColor Yellow
}

if (Test-Path $CUDA_EXE) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Build successful!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Executable: $CUDA_EXE" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\$CUDA_EXE <dimension> <population>" -ForegroundColor White
    Write-Host ""
    Write-Host "Example:" -ForegroundColor Yellow
    Write-Host "  .\$CUDA_EXE 10 50" -ForegroundColor White
    Write-Host ""
    
    if ($Test) {
        Write-Host "Running tests..." -ForegroundColor Cyan
        & ".\$CUDA_EXE" 10 50
    }
} else {
    Write-Host "Build may have failed - executable not found: $CUDA_EXE" -ForegroundColor Red
    exit 1
}
