FPGA DSP System
===============

Description
-----------
This project implements a complete digital-signal-processing pipeline on an FPGA, including:

- **Signal generation**  
  • Sine and square wave lookup via ROM (`rom_sin.vhd` / `rom_square.vhd`)  
  • Configurable amplitude and harmonic content  
- **Filtering**  
  • Six cascaded 2nd-order IIR sections (12th-order total) (`filter_iir.vhd`, `filter_iir12.vhd`)  
  • Supports “alpha” and “beta” filter types via generics  
- **Frequency analysis**  
  • 32-point (or configurable) FFT using vendor IP core (`xfft_0`)  
  • AXI-Stream handshake for data in/out  
- **Clock-domain crossing**  
  • Asynchronous FIFO for crossing from processing clock to UART clock (`fifo.vhd`)  
  • Dual-port RAM as the storage medium (`dpram.vhd`)  
- **Control sequencers**  
  • High-level sequencer to manage acquisition, FFT requests, and FIFO writes (`sequencer.vhd`)  
  • UART-side sequencer to accept commands and stream data bytes (`sequ_2.vhd`)  
- **UART interface**  
  • 230400 baud, 8-N-1 receiver (`uart_rx.vhd`) and transmitter (`uart_tx.vhd`)  
- **Reset & synchronization**  
  • Reset synchronizer (`rst_sync.vhd`)  
  • Pulse synchronizer & generic 2-stage synchronizer (`pulse_synchronizer.vhd`, `synchronizer.vhd`)  
- **Top-level integration**  
  • `dsp_system_top.vhd` ties together clocks, resets, modulator, filter, FFT, FIFO, UART

Two Python utilities live in `scripts/`:

1. **`genrom.py`**  
   Generates `sin.rom` or `square.rom` files (hex-formatted) for the two ROM modules.  
2. **`uart_acquisition.py`**  
   Sends control bytes over UART to trigger acquisition, reads back FFT output, and plots real/imag/magnitude.

Repository Layout
----------------
```text
├── README.md                    ← project overview & build/run instructions
│
├── dsp_final.srcs/              ← all FPGA/VHDL sources & constraints
│   ├── sources_1/               ← VHDL source files
│   │   ├── new/
│   │   │   ├── dsp_system_top.vhd
│   │   │   ├── filter_iir.vhd
│   │   │   ├── filter_iir12.vhd
│   │   │   ├── fifo.vhd
│   │   │   ├── pulse_synchronizer.vhd
│   │   │   ├── rom_sin.vhd
│   │   │   ├── rom_square.vhd
│   │   │   ├── sequencer.vhd
│   │   │   ├── sequ_2.vhd
│   │   │   ├── SignalModulator.vhd
│   │   │   ├── synchronizer.vhd
│   │   │   ├── uart_rx.vhd
│   │   │   ├── uart_tx.vhd
│   │   │   └── rst_sync.vhd
│   ├── mem/                     ← ROM initialization data
│   │   ├── sin.rom
│   │   └── square.rom
│   ├── constrs_1/               ← pin & timing constraints
│   │   ├── new/
│   │   │   └── Spec_analyzer.xdc
│   ├── scripts/                 ← utility scripts & generators
│   │   ├── genrom.py            ← builds .rom files from data
│   │   └── uart_acquisition.py  ← captures and plots UART data
│   ├── sim_1/                   ← test benches, simulation scripts
│   │   ├── new/
│   │   │   └── dsp_tb.vhd

```

Prerequisites
-------------
- **FPGA toolchain**  
  • Xilinx Vivado 2020.1 or newer (or equivalent Intel toolchain)  
- **Python**  
  • Version 3.7 or newer  
  • Required packages: `matplotlib`, `pyserial`

Generating ROM Initialization Files
-----------------------------------
1. Install Python requirements:  
    pip install matplotlib
2. Run the ROM generator:  
    python scripts/genrom.py -o rom_files/sin.rom -s 8 --sin
    python scripts/genrom.py -o rom_files/square.rom -s 8 --square


Building the FPGA Bitstream
---------------------------
1. Open your Vivado project or create a new one.  
2. Add all VHDL sources from `src/vhdl/`.  
3. Add `dsp_system_top.xdc` from `src/constraints/`.  
4. Synthesize, implement, and generate the bitstream.  

Programming & Running
---------------------
1. Program the bitstream into your FPGA board.  
2. Ensure the UART pins connect to your host PC (230400 baud, 8-N-1).  
3. To acquire and plot data:  
    pip install pyserial matplotlib
    python scripts/uart_acquisition.py -p /dev/ttyUSB0 -b 230400

This will trigger the FPGA to fill the FIFO, read back 512 complex FFT bins, and display real, imaginary, and magnitude plots.

Author
------
Dheshik Subbiah

Acknowledgements
----------------
• FFT IP core courtesy of Xilinx 
• Clocking Wizard IP core courtesy of Xilinx  
