MPL=../build/bin/mpl
FLAGS = -default-type int64 -default-type word64
# Extra flags applied to .dbg targets
EXTRA_DEBUG_FLAGS = -debug true \
	-debug-runtime true \
	-const 'MLton.debug true' \
	-verbose 3 \
	-const 'Exn.keepHistory true'
# List of IRs to keep
KEEP_IRS = ssa \
	ssa2 \
	rssa \
	xml \
	g
KEEP_IR_FLAGS=$(addprefix -keep ,$(KEEP_IRS)) -keep-output-dir bin/

# Full sets of flags for debug targets
DEBUG_FLAGS = $(FLAGS) $(EXTRA_DEBUG_FLAGS)

KEEP_FLAGS = $(FLAGS) $(EXTRA_DEBUG_FLAGS) ${KEEP_IR_FLAGS}

# Hook to run the test under some other program (e.g. lldb)
RUN_UNDER =

TARGETS = lib-test \
	simd

DBG_TARGETS := $(addsuffix .dbg,$(TARGETS))
KEEP_TARGETS := $(addsuffix .keep,$(TARGETS))

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

# TODO(pscollins): Put -keep outputs in a different directory
$(KEEP_TARGETS): %.keep: phony
	@mkdir -p bin
	$(MPL) $(KEEP_FLAGS) -output bin/$*.bin $*/sources.mlb
	@echo "successfully built bin/$*.bin, executing..."
	$(RUN_UNDER) bin/$*.bin

.PHONY: clean phony

phony:

clean:
	rm -rf bin/
