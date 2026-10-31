.PHONY: doctor setup build kernel rootfs image test demo clean

doctor:
	python3 toolkit/duo.py doctor

setup:
	python3 toolkit/duo.py setup --native

build:
	python3 toolkit/duo.py build

kernel:
	python3 toolkit/duo.py kernel

rootfs:
	python3 toolkit/duo.py rootfs

image:
	python3 toolkit/duo.py image

test:
	python3 -m unittest discover -s tests -v

demo:
	python3 toolkit/duo.py demo

clean:
	rm -rf out build
