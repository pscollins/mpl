MPL ?= $(HOME)/code/mpl/build/bin/mpl
MPL_FLAGS ?= -default-type int64 -default-type word64

.PHONY: test

test: repro-crash.mlb
	mkdir -p bin
	cd bin && $(MPL) $(MPL_FLAGS) $(EXTRA_MPL_FLAGS) -output minimize.bin ../repro-crash.mlb

standalone: standalone-sched.mlb
	mkdir -p bin
	cd bin && $(MPL) $(MPL_FLAGS) $(EXTRA_MPL_FLAGS) -output minimize.bin ../standalone-sched.mlb

clean:
	rm -rf bin
