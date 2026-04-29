MLTON := mlton

# Uncomment to enable stack traces
# DEBUG_FLAGS = -const 'Exn.keepHistory true'
DEBUG_FLAGS = 

.PHONY: unittest
unittest: parse-ssa-test.bin parse-ssa2-test.bin parse-ssa2-roundtrip-test.bin pre-flatten-tests rewrite-ir rewrite-ssa2

rewrite-ir: rewrite-ir.mlb rewrite-ir.sml $(wildcard *.fun *.sig)
	$(MLTON) -output $@ $<

parse-ssa-test.bin: parse-ssa-test.mlb parse-ssa-test.sml $(wildcard *.fun *.sig)
	$(MLTON) -output $@ $<
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
