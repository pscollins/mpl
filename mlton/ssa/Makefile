MLTON := mlton

.PHONY: unittest
unittest: parse-ssa-test.bin parse-ssa2-test.bin parse-ssa2-roundtrip-test.bin rewrite-ir rewrite-ssa2

rewrite-ir: rewrite-ir.mlb rewrite-ir.sml $(wildcard *.fun *.sig)
	$(MLTON) -output $@ $<

parse-ssa-test.bin: parse-ssa-test.mlb parse-ssa-test.sml $(wildcard *.fun *.sig)
	$(MLTON) -output $@ $<
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
