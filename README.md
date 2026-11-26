# MiniWatchdog

An 8-bit watchdog timer in Verilog-2001 with manual scan DFT through the counter register.

## Interface

| Signal | Kind | Width | Behavior |
| --- | --- | ---: | --- |
| `clk` | Input | 1 | Rising-edge clock for counting, reload, and scan shift. |
| `rst_n` | Input | 1 | Active-low asynchronous reset. Loads `RELOAD_VALUE` in either mode. |
| `kick` | Input | 1 | Reloads the count at the next rising edge in functional mode. |
| `scan_enable` | Input | 1 | Selects scan shift when high and functional mode when low. |
| `scan_in` | Input | 1 | Serial bit shifted into bit 0. |
| `scan_out` | Output | 1 | Current value of bit 7. |
| `timeout` | Output | 1 | High when the count is zero in functional mode. |
| `RELOAD_VALUE` | Parameter | 8 | Reset and kick reload value. Defaults to `8'd10`. |

## Architecture

```text
Reload / decrement / hold ──┐
                            ├─► [mux] ─► [8-bit counter] ─┬─► bit 7 ───────► scan_out
{count[6:0], scan_in} ──────┘                             └─► zero detect ─► timeout
```

In functional mode, a rising edge reloads the counter if `kick` is high. Otherwise the count decrements and holds at zero. With the default reload, ten rising edges without a kick bring the count to zero.

`scan_enable` selects the shift path and masks the zero detector output. Eight MSB-first shifts can load any count. Sampling `scan_out` before each shift reads the previous contents in the same order. Functional mode resumes from the value left in the register.

## Verification

The self-checking SystemVerilog testbench runs with Icarus Verilog (`-g2012`). All seven scenarios passed, covering reset, countdown, reload, timeout, saturation, a scan round-trip with `8'hB2`, and mode switching.

The GTKWave capture shows the count reload to `0A`, reach `00` at timeout, and take the value `B2` during scan.

![GTKWave capture of the watchdog countdown, timeout, and B2 scan pattern](assets/gtkwave-watchdog-rtl.png)

## Synthesis

The original Yosys 0.52 run reported 49 generic cells, including 8 flip-flops. The synthesis script runs `check -assert` and writes cell statistics, a log, and a Verilog netlist to `build/`. These are generic logic synthesis results, before technology mapping to an ASIC cell library.

## Run locally

Use Windows 10 or 11 and place the native Windows executables on `PATH`. Simulation requires Icarus Verilog (`iverilog.exe` and `vvp.exe`). Synthesis requires `yosys.exe` with its bundled ABC tool. GTKWave is optional for viewing waveforms. The batch flow omits Verilator lint because a working native installation has not been verified.

From PowerShell or Command Prompt in the repository root:

```powershell
.\run.bat sim     # Verilog-2001 RTL check and RTL simulation (default)
.\run.bat synth   # Generic synthesis and structural check
.\run.bat gate    # Synthesis and zero-delay gate-level simulation
.\run.bat all     # RTL simulation, synthesis, and gate-level simulation
.\run.bat clean   # Remove the generated build directory
```

Both simulations use the same self-checking testbench. Open `build/watchdog.vcd` for RTL or `build/watchdog_gate.vcd` for the netlist.
