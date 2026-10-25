import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles


@cocotb.test()
async def test_two_sram_macros(dut):
    """Test both 512x32 SRAM macros through the standalone BIST."""

    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 5)
    await FallingEdge(dut.clk)
    dut.rst_n.value = 1

    # Four patterns, each writing and reading all 512 addresses.
    # Allow margin for the complete BIST sequence.
    for cycle in range(10000):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")

        status = int(dut.uo_out.value)

        done = status & 0x01
        fail_a = (status >> 1) & 0x01
        fail_b = (status >> 2) & 0x01

        assert not fail_a, (
            f"SRAM_A failed its readback test at cycle {cycle}"
        )

        assert not fail_b, (
            f"SRAM_B failed its readback test at cycle {cycle}"
        )

        if done:
            dut._log.info(
                f"BIST completed successfully after {cycle + 1} cycles"
            )
            return

    raise AssertionError("SRAM BIST did not complete within 10000 cycles")