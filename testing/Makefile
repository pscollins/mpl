MPL=../build/bin/mpl
FLAGS=-default-type int64 -default-type word64

TARGETS=\
  lib-test

all: $(TARGETS)

$(TARGETS): %: phony
	@mkdir -p bin
	$(MPL) $(FLAGS) -output bin/$*.bin $*/sources.mlb
	@echo "successfully built bin/$*.bin, executing..."
	bin/$*.bin

.PHONY: clean phony

phony:

clean:
	rm -rf bin/
