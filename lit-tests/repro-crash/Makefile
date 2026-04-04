MPL ?= $(HOME)/code/mpl/build/bin/mpl
MPL_FLAGS ?= -default-type int64 -default-type word64

.PHONY: test

SRCS = ../repro-crash.mlb ../ffi_stubs.c

test: repro-crash.mlb
	mkdir -p bin
	cd bin && $(MPL) $(MPL_FLAGS) $(EXTRA_MPL_FLAGS) -output minimize.bin $(SRCS)

clean:
	rm -rf bin
