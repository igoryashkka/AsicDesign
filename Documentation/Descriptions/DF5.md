# DF5 — MicroBlaze + AXI Interconnect IP + FIFO + FSK Modulator

Description

DF5 continues from DF4: it reuses the MicroBlaze block design approach from
`DF4/AXI_Slave_example`. The AXI interconnect itself is a stock Vivado IP block (AXI
Interconnect / AXI SmartConnect from IP Integrator) — not hand-written RTL. A new
AXI4-Lite FIFO peripheral is added behind it, whose output feeds a very simplified
hardware FSK (frequency-shift keying) modulator. Every AXI write transaction into the
FIFO also drives an on-board LED.

Where to look

- `DF5/AXI_FIFO_Modulator/task_readme.md` — full assignment, architecture, register map
- `DF5/AXI_FIFO_Modulator/README.md` — build instructions
- `DF5/AXI_FIFO_Modulator/docs/scripts_and_xdc_guide.md` — beginner-friendly explanation of the build scripts and `.xdc` constraints
- `DF5/AXI_FIFO_Modulator/sources/rtl/{sync_fifo,axi_fifo_regs,fsk_modulator,top}.vhd` — skeletons to implement

Goals

- Launch MicroBlaze and route its AXI traffic through a stock Vivado AXI Interconnect/SmartConnect IP.
- Implement an AXI4-Lite FIFO peripheral (data/status/control/freq registers around a plain synchronous FIFO).
- Implement a very simplified hardware FSK modulator that consumes the FIFO output and drives an external pin.
- Drive an on-board LED on every AXI write transaction into the FIFO, so transactions are visible without a debugger.
