SVFILES := $(shell find ./ -type f -name '*.sv' | grep -v build/)
PROCESSED = $(patsubst %, build/%, $(SVFILES))

.PHONY: preprocess cpu

build/%.sv: %.sv
	-mkdir build
	cpp -P $< > $@

preprocess: $(PROCESSED)

lint: $(PROCESSED)
	cd build && $(foreach x, $(SVFILES), verilator --default-language 1800-2017 -Wall -Wno-DECLFILENAME -Wno-UNUSED -Wno-WIDTH -Wno-STMTDLY -Wno-UNDRIVEN -Wno-PINCONNECTEMPTY --lint-only $(x);)

cpu: $(PROCESSED)
	iverilog -g2009 -o cpu build/*.sv -Wall

clean:
	rm -rf build

all: cpu
