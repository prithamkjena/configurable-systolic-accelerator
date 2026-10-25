![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Configurable 4×4 Systolic Accelerator (OS / WS / IS)

A hardware-accelerated 4×4 2D systolic array supporting **Output Stationary (OS)**, **Weight Stationary (WS)**, and **Input Stationary (IS)** dataflows, coupled with 3 on-chip IHP SG13CMOS5L SRAM macros (`RM_IHPSG13_1P_64x16_c2`) on an 8×4 Tiny Tapeout tile.

- [Read the full datasheet and technical documentation](docs/info.md)

---

## Project Overview

This project implements a matrix multiplication engine ($C = A \times B$) for 4×4 matrices with 8-bit signed integer elements, producing exact 18-bit signed results without overflow.

### Key Highlights
- **Reconfigurable Systolic Architecture**: Dynamically switchable at runtime between:
  - **Output Stationary (OS)**: Accumulators stay stationary inside PEs; activations and weights stream continuously.
  - **Weight Stationary (WS)**: Stationary weights pre-loaded into PE registers; activations stream horizontally while partial sums accumulate down columns.
  - **Input Stationary (IS)**: Stationary activations pre-loaded; weights and partial sums stream through the grid.
- **Embedded SRAM Macro Storage**:
  - Three on-chip compiled IHP SRAM macros (`RM_IHPSG13_1P_64x16_c2`, 64×16 bits).
  - SRAM A: 4×4 Matrix A (16 bytes = 8 words).
  - SRAM B: 4×4 Matrix B (16 bytes = 8 words).
  - SRAM C: 4×4 Matrix C (16 elements × 18 bits = 32 words).
- **Physical Design & PDN Optimization**:
  - Designed for IHP 130 nm SG13CMOS5L PDK within an 8×4 Tiny Tapeout tile.
  - Custom LibreLane PDN plugin (`Project.ExtendPowerStripes`) ensuring continuous Metal4 power delivery across embedded SRAM macros.
- **Optimized Datapath**: Sized with exact mathematical bitwidths (18-bit partial sums and 288-bit output bus), saving 672 unnecessary flip-flops over a naive 32-bit datapath.

---

## Quick Start & Verification

Run the full Cocotb regression suite (18 automated tests covering all dataflows, boundary conditions, and SRAM operations):

```bash
cd test
make -B
```

---

## Architecture & I/O Protocol

Communication with the accelerator is handled over the standard Tiny Tapeout 8-bit interfaces (`ui_in`, `uio_in`, `uo_out`):

### Command Interface (`uio_in[7:4] = Opcode`, `uio_in[3:0] = Operand`)

| Opcode | Name | Operand (`uio_in[3:0]`) | Data In (`ui_in`) | Output (`uo_out`) | Description |
|:---:|:---|:---|:---|:---|:---|
| `0x0` | `NOP` | Don't care | Don't care | Status flags | Poll status flags |
| `0x1` | `WRITE_A` | Byte index (0–15) | 8-bit signed data | Status flags | Write byte to staging buffer & commit word to SRAM A |
| `0x2` | `WRITE_B` | Byte index (0–15) | 8-bit signed data | Status flags | Write byte to staging buffer & commit word to SRAM B |
| `0x3` | `SET_DF` | Don't care | `[1:0]` policy | Status flags | Set dataflow: `00`=OS, `01`=WS, `10`=IS |
| `0x4` | `READ_C` | Word addr `[3:0]` | `ui[0]`=addr[4], `ui[1]`=byte_sel | Selected byte | Read 16-bit word from SRAM C (`uio_out` has high byte) |
| `0x5` | `READ_A` | Word addr `[2:0]` | `ui[1]`=byte_sel | Selected byte | Read 16-bit word from SRAM A |
| `0x6` | `READ_B` | Word addr `[2:0]` | `ui[1]`=byte_sel | Selected byte | Read 16-bit word from SRAM B |
| `0x7` | `START` | Don't care | Don't care | Status flags | Trigger accelerator execution bridge |
| `0x8` | `STATUS` | Don't care | Don't care | Status flags | Explicit poll status: `{4'b0, df_policy[1:0], busy, done}` |

---

## What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and cheaper than ever to get your digital and analog designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

## Set up your Verilog project

1. Add your Verilog files to the `src` folder.
2. Edit the [info.yaml](info.yaml) and update information about your project, paying special attention to the `source_files` and `top_module` properties. If you are upgrading an existing Tiny Tapeout project, check out our [online info.yaml migration tool](https://tinytapeout.github.io/tt-yaml-upgrade-tool/).
3. Edit [docs/info.md](docs/info.md) and add a description of your project.
4. Adapt the testbench to your design. See [test/README.md](test/README.md) for more information.

The GitHub action will automatically build the ASIC files using [LibreLane](https://www.zerotoasiccourse.com/terminology/librelane/).

## Enable GitHub actions to build the results page

- [Enabling GitHub Pages](https://tinytapeout.com/faq/#my-github-action-is-failing-on-the-pages-part)

## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://tinytapeout.com/discord)
- [Build your design locally](https://www.tinytapeout.com/guides/local-hardening/)

## What next?

- [Submit your design to the next shuttle](https://app.tinytapeout.com/).
- Edit [this README](README.md) and explain your design, how it works, and how to test it.
- Share your project on your social network of choice:
  - LinkedIn [#tinytapeout](https://www.linkedin.com/search/results/content/?keywords=%23tinytapeout) [@TinyTapeout](https://www.linkedin.com/company/100708654/)
  - Mastodon [#tinytapeout](https://chaos.social/tags/tinytapeout) [@matthewvenn](https://chaos.social/@matthewvenn)
  - X (formerly Twitter) [#tinytapeout](https://twitter.com/hashtag/tinytapeout) [@tinytapeout](https://twitter.com/tinytapeout)
  - Bluesky [@tinytapeout.com](https://bsky.app/profile/tinytapeout.com)
