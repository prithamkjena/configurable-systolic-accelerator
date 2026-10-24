# SPDX-FileCopyrightText: © 2026 Pritham Kumar Jena
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


@cocotb.test()
async def test_three_sram_banks(dut):

    cocotb.start_soon(
        Clock(dut.clk, 10, unit="ns").start()
    )

    # Initialize inputs.
    dut.rst_n.value = 0
    dut.ena.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0

    await Timer(25, unit="ns")

    dut.rst_n.value = 1
    await Timer(1, unit="ns")

    dut.ena.value = 1

    matrix_a = [
        -128, -1, 0, 127,
        1, -2, 42, -42,
        13, -13, 64, -64,
        100, -100, 85, -86,
    ]

    matrix_b = [
        5, 10, 15, 20,
        -5, -10, -15, -20,
        30, 40, 50, 60,
        -30, -40, -50, -60,
    ]

    # Write one byte to A and one byte to B per clock.
    for address in range(16):

        dut.ui_in.value = matrix_a[address] & 0xFF
        dut.uio_in.value = matrix_b[address] & 0xFF

        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")

    # Check SRAM A's stored bytes.
    for address in range(16):

        actual = int(dut.user_project.SRAM_A.mem[address].value)
        expected = matrix_a[address] & 0xFF

        assert actual == expected, (
            f"SRAM A address {address}: "
            f"expected 0x{expected:02X}, got 0x{actual:02X}"
        )

    # Check SRAM B's stored bytes.
    for address in range(16):

        actual = int(dut.user_project.SRAM_B.mem[address].value)
        expected = matrix_b[address] & 0xFF

        assert actual == expected, (
            f"SRAM B address {address}: "
            f"expected 0x{expected:02X}, got 0x{actual:02X}"
        )

    # C's memory was reset to zero and has not been written.
    for address in range(16):

        actual = int(dut.user_project.SRAM_C.mem[address].value)

        assert actual == 0, (
            f"SRAM C address {address} should be zero, got {actual}"
        )

    dut._log.info("PASS: SRAM A stores all 16 bytes correctly")
    dut._log.info("PASS: SRAM B stores all 16 bytes correctly")
    dut._log.info("PASS: SRAM A and B store independent data")
    dut._log.info("PASS: SRAM C remains zero without writes")