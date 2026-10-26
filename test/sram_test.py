import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge, Timer


@cocotb.test()
async def test_three_sram_macros(dut):
    """Run the RTL BIST and check all 64x16 words in SRAM_A/B/C."""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())

    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 5)
    await FallingEdge(dut.clk)
    dut.rst_n.value = 1

    # Four full-memory patterns take about 516 cycles; leave margin for models.
    for cycle in range(1000):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
        status = int(dut.uo_out.value)

        # uo_out[3:1] are sticky failure flags for SRAM_C, SRAM_B and SRAM_A.
        failures = (status >> 1) & 0x7
        assert failures == 0, (
            f"SRAM BIST readback failure at cycle {cycle}: "
            f"SRAM_A_fail={(status >> 1) & 1}, "
            f"SRAM_B_fail={(status >> 2) & 1}, "
            f"SRAM_C_fail={(status >> 3) & 1}, "
            f"status=0x{status:02X}"
        )

        if status & 0x01:
            dut._log.info(
                "SRAM_A, SRAM_B and SRAM_C passed all four 64-word readback patterns"
            )
            return

    raise TimeoutError("SRAM BIST did not finish within 1000 clock cycles")