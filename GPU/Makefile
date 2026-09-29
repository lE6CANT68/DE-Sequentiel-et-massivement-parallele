# Makefile para versión GPU - CUDA
# Compilar con: make
# Limpiar con: make clean

NVCC = nvcc
NVCCFLAGS = -O2 -arch=sm_70

CXX = g++
CXXFLAGS = -O2 -Wall -I.

# Detect CUDA installation
CUDA_PATH ?= /usr/local/cuda
INCLUDE_FLAGS = -I$(CUDA_PATH)/include
LDFLAGS = -L$(CUDA_PATH)/lib64 -lcuda -lcudart

# Source files
CUDA_SOURCES = kernel.cu
CXX_SOURCES = main.cpp kernel.cpp benchmarks.cpp
HEADERS = kernel.h kernel.cu

# Object files
CUDA_OBJS = kernel.o
CXX_OBJS = main.o kernel_host.o benchmarks_gpu.o

# Executables
GPU_EXE = de_gpu
TEST_EXE = test_benchmarks_gpu

# Default target
all: $(GPU_EXE)

# Main GPU DE executable
$(GPU_EXE): $(CUDA_OBJS) $(CXX_OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

# CUDA kernel compilation
kernel.o: kernel.cu kernel.h
	$(NVCC) $(NVCCFLAGS) -c kernel.cu -o kernel.o

# Host-side C++ files
main.o: main.cpp kernel.h benchmarks.h
	$(CXX) $(CXXFLAGS) -c main.cpp -o main.o

kernel_host.o: kernel.cpp kernel.h
	$(CXX) $(CXXFLAGS) -c kernel.cpp -o kernel_host.o

benchmarks_gpu.o: benchmarks.cpp benchmarks.h
	$(CXX) $(CXXFLAGS) -c benchmarks.cpp -o benchmarks_gpu.o

# Test benchmark functions
test_benchmarks: test_benchmarks.cpp benchmarks.cpp benchmarks.h
	$(CXX) $(CXXFLAGS) -o test_benchmarks test_benchmarks.cpp benchmarks.cpp

# Run tests
test: test_benchmarks $(GPU_EXE)
	./test_benchmarks
	./$(GPU_EXE) 10 50

# Clean build artifacts
clean:
	rm -f $(GPU_EXE) test_benchmarks $(CUDA_OBJS) $(CXX_OBJS)

# Clean all
distclean: clean
	rm -f *.o *.a *.so

.PHONY: all test clean distclean
