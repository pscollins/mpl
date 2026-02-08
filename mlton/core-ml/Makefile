MLTON := mlton

.PHONY: unittest
unittest: inline-trace-test core-ml-test
	./inline-trace-test
	./core-ml-test

inline-trace-test: inline-trace-test.mlb inline-trace-test.sml
	$(MLTON) -output $@ $<

core-ml-test: core-ml-test.mlb core-ml-test.sml
	$(MLTON) -output $@ $<
