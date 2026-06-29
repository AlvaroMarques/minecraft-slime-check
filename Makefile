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

bin:
	@mkdir -p bin

clean:
	rm bin/main
	rm bin/*.o
