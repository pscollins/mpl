MPL=../build/bin/mpl
FLAGS = -default-type int64 -default-type word64
# Extra flags applied to .dbg targets
EXTRA_DEBUG_FLAGS = -debug true \
	-debug-runtime true \
	-const 'MLton.debug true'
# Full sets of flags for debug targets
DEBUG_FLAGS = $(FLAGS) $(EXTRA_DEBUG_FLAGS)

# Hook to run the test under some other program (e.g. lldb)
RUN_UNDER =

TARGETS=\
  lib-test \
	simd

DBG_TARGETS := $(addsuffix .dbg,$(TARGETS))

all: $(TARGETS)
all-dbg: $(TARGETS)

$(TARGETS): %: phony
	@mkdir -p bin
	$(MPL) $(FLAGS) -output bin/$*.bin $*/sources.mlb
	@echo "successfully built bin/$*.bin, executing..."
	$(RUN_UNDER) bin/$*.bin

$(DBG_TARGETS): %.dbg: phony
	@mkdir -p bin
	$(MPL) $(DEBUG_FLAGS) -output bin/$*.bin $*/sources.mlb
	@echo "successfully built bin/$*.bin, executing..."
	$(RUN_UNDER) bin/$*.bin

.PHONY: clean phony

phony:

clean:
	rm -rf bin/
