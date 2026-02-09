.PHONY: unittest
unittest: emit-diagnostics-test
	./emit-diagnostics-test

emit-diagnostics-test: emit-diagnostics-test.mlb emit-diagnostics-test.sml
	mlton -stop tc emit-diagnostics-test.mlb
	mlton emit-diagnostics-test.mlb
