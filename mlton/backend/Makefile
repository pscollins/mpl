MLTON := mlton

.PHONY: unittest
unittest: emit-diagnostics-test.bin
	./emit-diagnostics-test.bin

emit-diagnostics-test.bin: emit-diagnostics-test.mlb emit-diagnostics-test.sml $(wildcard *.fun *.sig)
	$(MLTON) -output $@ $<


.PHONY: clean
clean:
	rm -f *.bin
