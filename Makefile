.PHONY: cuda run-cuda fmt

CLANG_FORMAT ?= clang-format-21

run-cuda: bin/main-cu
	./bin/main-cu

cuda: bin/main-cu


fmt:
	@$(CLANG_FORMAT) -i *.cpp *.cu
	echo "Formatted!"

bin/main-cu: bin main.cu
	nvcc main.cu -o bin/main-cu

bin/main: bin/main.o
	g++ -o bin/main bin/main.o

bin/main.o: main.cpp bin
	g++ -c main.cpp -o bin/main.o

bin/test: test.cpp bin
	g++ test.cpp -o bin/test

test: bin/test
	./bin/test --world-seed -100 --init-z 0 --final-z 256
	./bin/test --world-seed

bin:
	@mkdir -p bin

clean:
	rm bin/*
