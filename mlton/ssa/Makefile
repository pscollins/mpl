MLTON := mlton

# Uncomment to enable stack traces
DEBUG_FLAGS = -const 'Exn.keepHistory true'
# DEBUG_FLAGS =

.PHONY: unittest
unittest: test-util-tests.bin parse-ssa-test.bin parse-ssa2-test.bin parse-ssa2-roundtrip-test.bin shallow-flatten-tests pre-flatten-tests rewrite-ir rewrite-ssa2 flatten-util-test.bin

test-util-tests.bin: test-util-tests.mlb test-util-tests.sml test-util.sml
	$(MLTON) -output $@ $<
	./$@

rewrite-ir: rewrite-ir.mlb rewrite-ir.sml $(wildcard *.fun *.sig)
	$(MLTON) -output $@ $<

parse-ssa-test.bin: parse-ssa-test.mlb parse-ssa-test.sml $(wildcard *.fun *.sig)
	$(MLTON) -output $@ $<
	./$@

flatten-util-test.bin: flatten-util-test.mlb flatten-util-test.sml flatten-util-test-common.sml $(wildcard *.fun *.sig)
	$(MLTON) $(DEBUG_FLAGS) -output $@ $<
	./$@

SHALLOW_FLATTEN_TEST_MLBS := shallow-flatten-test.mlb
SHALLOW_FLATTEN_TEST_BINS := $(SHALLOW_FLATTEN_TEST_MLBS:.mlb=.bin)

.PHONY: shallow-flatten-tests
shallow-flatten-tests: $(SHALLOW_FLATTEN_TEST_BINS)

shallow-flatten-test.bin: shallow-flatten-test.mlb shallow-flatten-test.sml shallow-flatten-test-common.sml $(wildcard *.fun *.sig)
	$(MLTON) $(DEBUG_FLAGS) -output $@ $<
	./$@

PRE_FLATTEN_TEST_MLBS := $(wildcard pre-flatten-test-[0-9]*.mlb)
PRE_FLATTEN_TEST_BINS := $(PRE_FLATTEN_TEST_MLBS:.mlb=.bin)

.PHONY: pre-flatten-tests
pre-flatten-tests: $(PRE_FLATTEN_TEST_BINS)

pre-flatten-test-%.bin: pre-flatten-test-%.mlb pre-flatten-test-%.sml pre-flatten-test-common.sml $(wildcard *.fun *.sig)
	$(MLTON) $(DEBUG_FLAGS) -output $@ $<
	./$@

parse-ssa2-test.bin: parse-ssa2-test.mlb parse-ssa2-test.sml $(wildcard *.fun *.sig)
	$(MLTON) -output $@ $<
	./$@

parse-ssa2-roundtrip-test.bin: parse-ssa2-roundtrip-test.mlb parse-ssa2-roundtrip-test.sml $(wildcard *.fun *.sig)
	$(MLTON) -output $@ $<
	./$@

rewrite-ssa2: rewrite-ssa2.mlb rewrite-ssa2-test.sml $(wildcard *.fun *.sig)
	$(MLTON) -output $@ $<
	./$@


.PHONY: clean
clean:
	rm -f *.bin rewrite-ir rewrite-ssa2
