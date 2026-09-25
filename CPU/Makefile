CXX = g++
CXXFLAGS = -O2 -Wall

all: de_sequentiel test_benchmarks

de_sequentiel: de_sequentiel.cpp benchmarks.cpp benchmarks.h
	$(CXX) $(CXXFLAGS) -o de_sequentiel de_sequentiel.cpp benchmarks.cpp

test_benchmarks: test_benchmarks.cpp benchmarks.cpp benchmarks.h
	$(CXX) $(CXXFLAGS) -o test_benchmarks test_benchmarks.cpp benchmarks.cpp

test: test_benchmarks
	./test_benchmarks

clean:
	rm -f de_sequentiel test_benchmarks
