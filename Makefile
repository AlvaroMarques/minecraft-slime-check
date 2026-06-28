bin/main: bin/main.o
	g++ -o bin/main bin/main.o

bin/main.o: main.cpp bin
	g++ -c main.cpp -o bin/main.o

bin:
	@mkdir -p bin

clean:
	rm bin/main
	rm bin/*.o
