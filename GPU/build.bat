@echo off
REM Build script for GPU version on Windows
REM Requires: NVCC (CUDA Toolkit) in PATH

setlocal enabledelayedexpansion

echo ========================================
echo DE GPU Build Script (Windows)
echo ========================================

REM Check if NVCC is available
where nvcc >nul 2>nul
if errorlevel 1 (
    echo ERROR: NVCC not found in PATH
    echo Please install CUDA Toolkit and ensure nvcc is in PATH
    exit /b 1
)

REM Check if G++ is available (for host compilation)
where g++ >nul 2>nul
if errorlevel 1 (
    echo WARNING: G++ not found in PATH
    echo Trying to compile with CL.exe (MSVC)...
    set USE_MSVC=1
)

set NVCC_FLAGS=-O2 -arch=sm_70
set CUDA_EXE=de_gpu.exe
set TEST_EXE=test_benchmarks.exe

echo.
echo Step 1: Compiling CUDA kernel (kernel.cu)...
nvcc %NVCC_FLAGS% -c kernel.cu -o kernel.obj
if errorlevel 1 (
    echo ERROR: Failed to compile kernel.cu
    exit /b 1
)

echo Step 2: Compiling host C++ files...
if defined USE_MSVC (
    echo Using MSVC compiler
    cl /O2 /c main.cpp kernel.cpp benchmarks.cpp 1>nul 2>&1
    if errorlevel 1 (
        echo ERROR: Failed to compile C++ files with MSVC
        exit /b 1
    )
) else (
    echo Using G++ compiler
    g++ -O2 -Wall -c main.cpp kernel.cpp benchmarks.cpp
    if errorlevel 1 (
        echo ERROR: Failed to compile C++ files
        exit /b 1
    )
)

echo Step 3: Linking...
if defined USE_MSVC (
    link /OUT:%CUDA_EXE% kernel.obj main.obj kernel.obj benchmarks.obj cuda.lib cudart.lib 1>nul 2>&1
) else (
    g++ -O2 -o %CUDA_EXE% kernel.obj main.o kernel.o benchmarks.o -lcuda -lcudart
)

if errorlevel 1 (
    echo ERROR: Failed to link
    exit /b 1
)

echo.
echo ========================================
echo Build successful!
echo Executable: %CUDA_EXE%
echo ========================================
echo.
echo Usage:
echo   %CUDA_EXE% ^<dimension^> ^<population^>
echo.
echo Example:
echo   %CUDA_EXE% 10 50
echo.

endlocal
