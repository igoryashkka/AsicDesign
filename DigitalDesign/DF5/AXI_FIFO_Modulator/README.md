
# DF5 — MicroBlaze + AXI Interconnect IP + FIFO + FSK Modulator
This project based on `DF4/AXI_Slave_example` (MicroBlaze block designm see note below). The interconnect between
MicroBlaze and the peripheral is a **stock Vivado IP block** (AXI Interconnect added
via IP Integrator) — unlike DF4/AXI_Interconnect, writing the interconnect itself is not part of this
task. It wires MicroBlaze through that IP to a new AXI4-Lite FIFO peripheral whose output feeds a very
simplified hardware **FSK** (frequency-shift keying) modulator, plus an LED that reacts to every AXI
write transaction into the FIFO.

Note: MicroBlaze is a soft CPU core originally designed for Xilinx FPGA. It can run C programs as a standalone CPU. What is idea of MicroBlaze, read in DF5/DOC folder. 


See [`task_readme.md`](task_readme.md) for the full assignment and [`docs/scripts_and_xdc_guide.md`](docs/scripts_and_xdc_guide.md)
for a beginner-friendly explanation of what the build scripts and the `.xdc` constraints file actually do.

## Build Instructions

Project stages are managed via the provided `build.bat` script.

### Create Project

```bash
.\scripts\build.bat
```

After the project is generated:

* Open the project in Vivado GUI.
* Create/import the MicroBlaze block design (reuse `DF4/AXI_Slave_example/sources/bd/microblaze.bd` as a starting point).
* In IP Integrator, add a stock **AXI Interconnect** (or **AXI SmartConnect**) IP block between MicroBlaze and the new peripheral.
* Add `axi_fifo_regs` (wrapping `sync_fifo` + `fsk_modulator`, see `top.vhd`) as an RTL module / AXI peripheral in the block design.

---

## Build Options

### Build All Stages (Synthesis + Implementation + Bitstream)

```bash
.\scripts\build.bat -all
```

### Run Synthesis Only

```bash
.\scripts\build.bat -syn
```

### Run Implementation and Generate Bitstream

```bash
.\scripts\build.bat -impl -bit
```

### Generate XSA File (for Vitis)

```bash
.\scripts\build.bat -xsa
```

---

## ⚠️ Important Notes

* Synthesis may fail if generated IP cores (e.g. `clk_wiz_0`, AXI Interconnect) are not properly created — regenerate IP in the Vivado GUI if needed.
* The AXI interconnect is a Vivado IP block configured in the block design GUI, not RTL under `sources/rtl` — there is nothing to hand-write there.
