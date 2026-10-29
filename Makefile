# CompEng 361 - Lab 3 Student Makefile

CPU ?= template_lab3.v
SIM_BIN = single

.PHONY: all test tier-a tier-b sim clean

all: test

$(SIM_BIN): $(CPU) lab3_tb.v
	iverilog -o $(SIM_BIN) $(CPU) lab3_tb.v

sim: $(SIM_BIN)
	./$(SIM_BIN)

test:
	python3 run_tests.py $(CPU)

tier-a:
	python3 run_tests.py $(CPU) --tier A

tier-b:
	python3 run_tests.py $(CPU) --tier B

clean:
	rm -f $(SIM_BIN) single_test_sim single.vcd trace.txt mem_out.hex regs_out.hex
