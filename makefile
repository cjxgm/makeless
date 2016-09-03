all: build
build:
	make build -C src
clean:
	make clean -C src
cleanall: clean
	rm -f makeless
install:
	install -vm 755 makeless /usr/local/bin/makeless
	ln -sf makeless /usr/local/bin/ml

