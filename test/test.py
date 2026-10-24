# SPDX-FileCopyrightText: © 2026 Pritham Kumar Jena
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge, Timer


@cocotb.test()
async def test_three_sram_blocks(dut):
    dut._log.info("Starting three-SRAM test")

    # Start the clock
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # Drive initial inputs and reset the design
    dut.ena.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 3)
    await FallingEdge(dut.clk)

    dut.rst_n.value = 1
    dut.ena.value = 1

    # Access the three SRAM instances through the testbench hierarchy
    top = dut.user_project
    sram_a = top.SRAM_A
    sram_b = top.SRAM_B
    sram_c = top.SRAM_C

    # ---------------------------------------------------------
    # Test 1: Write distinct data into all three SRAMs
    # ---------------------------------------------------------

    data_a = [(0x31 + 7 * i) & 0xFF for i in range(16)]
    data_b = [(0xA6 - 3 * i) & 0xFF for i in range(16)]
    data_c = [data_a[i] ^ data_b[i] for i in range(16)]

    dut._log.info("Writing test patterns into SRAM A, B and C")

    for addr in range(16):
        dut.ui_in.value = data_a[addr]
        dut.uio_in.value = data_b[addr]

        # The RTL writes:
        # SRAM A <- ui_in
        # SRAM B <- uio_in
        # SRAM C <- ui_in XOR uio_in
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")

        assert int(sram_a.mem[addr].value) == data_a[addr], (
            f"SRAM A address {addr}: expected {data_a[addr]}, "
            f"got {int(sram_a.mem[addr].value)}"
        )

        assert int(sram_b.mem[addr].value) == data_b[addr], (
            f"SRAM B address {addr}: expected {data_b[addr]}, "
            f"got {int(sram_b.mem[addr].value)}"
        )

        assert int(sram_c.mem[addr].value) == data_c[addr], (
            f"SRAM C address {addr}: expected {data_c[addr]}, "
            f"got {int(sram_c.mem[addr].value)}"
        )

    dut._log.info("All SRAM write checks passed")

    # ---------------------------------------------------------
    # Test 2: Verify synchronous reads and overwrite behavior
    # ---------------------------------------------------------
    # The address counters have wrapped back to zero.
    # On each clock edge, read_data receives the OLD memory
    # value while the memory is overwritten with NEW data.

    dut._log.info("Testing synchronous SRAM reads")

    for addr in range(16):
        old_a = data_a[addr]
        old_b = data_b[addr]
        old_c = data_c[addr]

        new_a = (0xE1 - 5 * addr) & 0xFF
        new_b = (0x42 + 9 * addr) & 0xFF
        new_c = new_a ^ new_b

        dut.ui_in.value = new_a
        dut.uio_in.value = new_b

        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")

        # Confirm that the memories were overwritten
        assert int(sram_a.mem[addr].value) == new_a
        assert int(sram_b.mem[addr].value) == new_b
        assert int(sram_c.mem[addr].value) == new_c

        # Synchronous reads return the old values from
        # before the writes on this clock edge.
        assert int(sram_a.read_data.value) == old_a, (
            f"SRAM A read mismatch at address {addr}"
        )
        assert int(sram_b.read_data.value) == old_b, (
            f"SRAM B read mismatch at address {addr}"
        )
        assert int(sram_c.read_data.value) == old_c, (
            f"SRAM C read mismatch at address {addr}"
        )

        # SRAM C stores A XOR B, so A XOR B XOR C is zero.
        expected_output = old_a ^ old_b ^ old_c
        assert int(dut.uo_out.value) == expected_output, (
            f"Output mismatch at address {addr}: "
            f"expected {expected_output}, got {int(dut.uo_out.value)}"
        )

        data_a[addr] = new_a
        data_b[addr] = new_b
        data_c[addr] = new_c

    # These outputs should remain tied low
    assert int(dut.uio_out.value) == 0
    assert int(dut.uio_oe.value) == 0

    dut._log.info("PASS: All three SRAMs passed write and read tests")