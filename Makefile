.PHONY: sim synth gate lint clean

sim: build/tb_watchdog.vvp
	vvp $<

build/tb_watchdog.vvp: rtl/watchdog_scan.v tb/tb_watchdog.sv | build
	iverilog -g2012 -Wall -s tb_watchdog -o $@ $^

synth: | build
	yosys -l build/synthesis.log -s synth/synth.ys

gate: synth
	mkdir -p build/gate/build
	iverilog -g2012 -s tb_watchdog -o build/tb_gate.vvp build/watchdog_scan_netlist.v tb/tb_watchdog.sv
	cd build/gate && vvp ../tb_gate.vvp

lint:
	verilator --lint-only -Wall --top-module watchdog_scan rtl/watchdog_scan.v

build:
	mkdir -p $@

clean:
	rm -rf build
