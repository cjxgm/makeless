all: build
build:
	make build -C src
clean:
	make clean -C src
cleanall: clean
	rm -f makeless

