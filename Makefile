SVFILES := $(shell find ./ -type f -name '*.sv' | grep -v build/)
PROCESSED = $(patsubst %, build/%, $(SVFILES))

.PHONY: preprocess cpu

build/%.sv: %.sv
	@mkdir build ||:
	cpp -P $< > $@

preprocess: $(PROCESSED)

lint: $(PROCESSED)
	cd build && $(foreach x, $(SVFILES), verilator --default-language 1800-2017 -Wall -Wno-DECLFILENAME -Wno-UNUSED -Wno-WIDTH -Wno-STMTDLY -Wno-UNDRIVEN -Wno-PINCONNECTEMPTY -Wno-MULTIDRIVEN --lint-only $(x);)

build/cpu.v: $(PROCESSED)
	-rm build/cpu.v
	cd build && sv2v *.sv > cpu.v

cpu: build/cpu.v
	iverilog -g2009 -o cpu build/cpu.v -Wall

clean:
	rm -rf build

all: cpu
