MLTON := mlton

.PHONY: unittest
unittest: inline-trace-test
	./inline-trace-test

inline-trace-test: inline-trace-test.mlb inline-trace-test.sml
	$(MLTON) -output $@ $<
