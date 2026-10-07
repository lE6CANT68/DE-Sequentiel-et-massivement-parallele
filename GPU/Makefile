# Makefile pour GPU DE avec CUDA

NVCC = nvcc
CXX = g++
CXXFLAGS = -O2 -std=c++11
NVCCFLAGS = -O2 -arch=sm_50 --use_fast_math -Xcompiler "$(CXXFLAGS)"

# Cibles
TARGETS = de_gpu test_benchmarks

all: $(TARGETS)

# Compilation principale GPU
de_gpu: main.cpp kernel.cu kernel.cpp benchmarks.cpp
	$(NVCC) $(NVCCFLAGS) -o $@ $^

# Test des benchmarks
test_benchmarks: test_benchmarks.cpp benchmarks.cpp
	$(CXX) $(CXXFLAGS) -o $@ $^

clean:
	rm -f $(TARGETS) *.o

.PHONY: all clean
