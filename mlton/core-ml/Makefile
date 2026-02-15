MLTON := mlton

.PHONY: unittest
unittest: core-ml-test.bin
	clean
	./core-ml-test.bin
# unittest: inline-trace-test.bin core-ml-test.bin
# 	./inline-trace-test.bin
# 	./core-ml-test.bin

# inline-trace-test.bin: inline-trace-test.mlb inline-trace-test.sml
# 	$(MLTON) -output $@ $<

core-ml-test.bin: core-ml-test.mlb core-ml-test.sml
	$(MLTON) -output $@ $<

.PHONY: clean
clean:
	rm -f *.bin
