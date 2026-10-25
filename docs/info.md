## How it works

The **Configurable Systolic Accelerator** is a high-performance 4×4 2D processing array designed for matrix-matrix multiplication ($C = A \times B$), integrated on a Tiny Tapeout 8×4 tile using the IHP SG13CMOS5L 130 nm open-source PDK.

### Core Features
- **4×4 Processing Element (PE) Array**: 16 hardware PEs featuring 8-bit signed multipliers and 18-bit accumulators capable of computing exact dot products with zero overflow (range $[-65024, +65536]$).
- **Three Supported Dataflow Architectures**:
  1. **Output Stationary (OS)** (`2'b00`): Accumulators remain local inside each PE, while Matrix A rows stream horizontally and Matrix B columns stream vertically. Best for minimizing writeback bandwidth.
  2. **Weight Stationary (WS)** (`2'b01`): Stationary weights are pre-loaded into PE registers. Inputs stream horizontally and partial sums accumulate as they flow vertically. Minimizes weight movement energy.
  3. **Input Stationary (IS)** (`2'b10`): Activations remain stationary within the array while weights and partial sums stream through.
- **Embedded On-Chip SRAM Storage**: Utilizes three IHP compiled SRAM macros (`RM_IHPSG13_1P_64x16_c2`, 64 words × 16 bits):
  - **SRAM A**: Stores 4×4 Matrix A (16 bytes = 8 words of 16-bit).
  - **SRAM B**: Stores 4×4 Matrix B (16 bytes = 8 words of 16-bit).
  - **SRAM C**: Stores 4×4 Result Matrix C (16 elements × 18-bit = 32 words of 16-bit).
- **Low-Pin-Count Host Protocol**: Operates entirely within the Tiny Tapeout 8-bit input (`ui_in`), 8-bit bidirectional input (`uio_in`), and 8-bit output (`uo_out`) interfaces using a packetized command controller.

### Block Architecture

```
                      +-------------------+
                      |   Host / TT I/O   |
                      +---------+---------+
                                |
                   +------------v------------+
                   |      io_controller      |
                   +----+---------------+----+
                        |               |
             +----------v---+     +-----v----------+
             | SRAM A, B, C | <-> | sram_acc_bridge|
             +--------------+     +-----+----------+
                                        |
                            +-----------v------------+
                            |   systolic_acc_top     |
                            | - Control FSM          |
                            | - Stream Buffer (skew) |
                            | - 4x4 PE Array         |
                            | - Output Buffer        |
                            +------------------------+
```

### Host Command Set (`uio_in[7:4] = Opcode`, `uio_in[3:0] = Operand`)

| Opcode | Name | Operand (`uio_in[3:0]`) | Data In (`ui_in`) | Output (`uo_out`) | Description |
|:---:|:---|:---|:---|:---|:---|
| `0x0` | `NOP` | Don't care | Don't care | Status flags | Poll status flags |
| `0x1` | `WRITE_A` | Byte index (0–15) | 8-bit signed data | Status flags | Write byte to staging buffer & commit word to SRAM A |
| `0x2` | `WRITE_B` | Byte index (0–15) | 8-bit signed data | Status flags | Write byte to staging buffer & commit word to SRAM B |
| `0x3` | `SET_DF` | Don't care | `[1:0]` policy | Status flags | Configure dataflow: `00`=OS, `01`=WS, `10`=IS |
| `0x4` | `READ_C` | Word addr `[3:0]` | `ui[0]`=addr[4], `ui[1]`=byte_sel | Selected byte | Read 16-bit word from SRAM C (`uio_out` has high byte) |
| `0x5` | `READ_A` | Word addr `[2:0]` | `ui[1]`=byte_sel | Selected byte | Read 16-bit word from SRAM A |
| `0x6` | `READ_B` | Word addr `[2:0]` | `ui[1]`=byte_sel | Selected byte | Read 16-bit word from SRAM B |
| `0x7` | `START` | Don't care | Don't care | Status flags | Trigger accelerator execution bridge |
| `0x8` | `STATUS` | Don't care | Don't care | Status flags | Explicit poll status: `{4'b0, df_policy[1:0], busy, done}` |

### Matrix Memory Mapping
- **Input Matrices A & B**: 16 signed 8-bit numbers mapped row-major as 8 consecutive 16-bit words. Word $k$ stores bytes $2k$ (bits `[7:0]`) and $2k+1$ (bits `[15:8]`).
- **Result Matrix C**: 16 signed 18-bit numbers mapped across 32 consecutive 16-bit words. For element index $e \in [0, 15]$:
  - Word $2e$: lower 16 bits of accumulator result (`C[15:0]`).
  - Word $2e+1$: sign-extended upper 2 bits (`{{14{C[17]}}, C[17:16]}`).

---

## How to test

### 1. Automated Simulation Tests (Cocotb)
The project includes a comprehensive regression testbench using Cocotb and Icarus Verilog verifying all dataflow architectures, corner cases, and SRAM read/write transactions:
```bash
cd test
make -B
```
All 18 test cases should report `PASSED`:
- Host write & readback of SRAM A and SRAM B
- Output Stationary (OS) execution with identity, signed, and mixed matrices
- Weight Stationary (WS) execution with identity, signed, and mixed matrices
- Input Stationary (IS) execution with identity, signed, and mixed matrices
- Zero-matrix, negative overflow boundary checks, and full 4×4 random matrix multiplication validated against NumPy golden models.

### 2. Hardware / Board Testing Workflow
1. **Power-On & Reset**: Hold `rst_n` low for at least 2 clock cycles with `ena = 1`.
2. **Load Matrix A**:
   - For byte index $i = 0 \dots 15$:
     - Set `uio_in = {4'h1, i[3:0]}` (Opcode `0x1`).
     - Set `ui_in = matrix_a[i]`.
     - Pulse clock.
3. **Load Matrix B**:
   - For byte index $i = 0 \dots 15$:
     - Set `uio_in = {4'h2, i[3:0]}` (Opcode `0x2`).
     - Set `ui_in = matrix_b[i]`.
     - Pulse clock.
4. **Configure Dataflow**:
   - Set `uio_in = 8'h30` (Opcode `0x3`).
   - Set `ui_in = 8'h00` for OS, `8'h01` for WS, or `8'h02` for IS.
   - Pulse clock.
5. **Start Accelerator**:
   - Set `uio_in = 8'h70` (Opcode `0x7`).
   - Pulse clock.
6. **Wait for Completion**:
   - Set `uio_in = 8'h80` (Opcode `0x8`).
   - Poll `uo_out[0]` (`done` flag) until it transitions to `1` (takes approx. 45 clock cycles).
7. **Read Matrix C Results**:
   - For word index $w = 0 \dots 31$:
     - Set `uio_in = {4'h4, w[3:0]}` (Opcode `0x4`).
     - Set `ui_in = {6'b0, 1'b0, w[4]}` to read low byte on `uo_out` (or `ui_in[1] = 1` for high byte).
     - Read result byte on `uo_out`.

---

## External hardware

- **Tiny Tapeout Demo Board**: Compatible with any standard Tiny Tapeout carrier board (e.g. RP2040-based or FTDI host).
- **Host Controller**: An RP2040, Arduino, FPGA, Raspberry Pi, or USB-to-GPIO bridge capable of driving 16 inputs (`ui_in[7:0]`, `uio_in[7:0]`) and reading 8 outputs (`uo_out[7:0]`) at 3.3V / 1.2V logic levels.

