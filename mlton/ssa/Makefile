MLTON := mlton

.PHONY: unittest
unittest: parse-ssa2-test.bin parse-ssa2-roundtrip-test.bin

parse-ssa2-test.bin: parse-ssa2-test.mlb parse-ssa2-test.sml $(wildcard *.fun *.sig)
	$(MLTON) -output $@ $<
	./$@

parse-ssa2-roundtrip-test.bin: parse-ssa2-roundtrip-test.mlb parse-ssa2-roundtrip-test.sml $(wildcard *.fun *.sig)
	$(MLTON) -output $@ $<
	./$@


.PHONY: clean
clean:
	rm -f *.bin
