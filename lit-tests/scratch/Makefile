MPL ?= $(HOME)/code/mpl/build/bin/mpl
MPL_FLAGS ?= -default-type int64 -default-type word64

.PHONY: test

test: minimize.ssa
	mkdir -p bin
	cd bin && $(MPL) $(MPL_FLAGS) $(EXTRA_MPL_FLAGS) -output minimize.bin ../minimize.ssa

clean:
	rm -rf bin
