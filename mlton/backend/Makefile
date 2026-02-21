MLTON := mlton

.PHONY: unittest
unittest: emit-diagnostics-test.bin trace-heap-ops-test.bin
	./emit-diagnostics-test.bin
	./trace-heap-ops-test.bin

emit-diagnostics-test.bin: emit-diagnostics-test.mlb emit-diagnostics-test.sml $(wildcard *.fun *.sig)
	$(MLTON) -output $@ $<

trace-heap-ops-test.bin: trace-heap-ops-test.mlb trace-heap-ops-test.sml $(wildcard *.fun *.sig)
	$(MLTON) -output $@ $<


.PHONY: clean
clean:
	rm -f *.bin
