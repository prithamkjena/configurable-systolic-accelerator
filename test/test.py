# SPDX-FileCopyrightText: © 2026 Pritham Kumar Jena
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge, Timer
import random

# ==============================================================================
# Helper Functions and Protocol Drivers
# ==============================================================================

# Dataflow constants
DF_OS = 0  # Output Stationary
DF_WS = 1  # Weight Stationary
DF_IS = 2  # Input Stationary

def matmul_golden(A, B):
    """Reference 4x4 matrix multiplication in Python with signed 32-bit accumulation."""
    C = [[0 for _ in range(4)] for _ in range(4)]
    for i in range(4):
        for j in range(4):
            s = 0
            for k in range(4):
                s += A[i][k] * B[k][j]
            C[i][j] = s
    return C

async def reset_dut(dut):
    """Start clock and apply active-low reset."""
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0

    await ClockCycles(dut.clk, 5)
    await FallingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

async def write_matrix_byte(dut, matrix_name, byte_idx, val):
    """Write an 8-bit element into Matrix A or B shadow buffer and SRAM."""
    opcode = 0x1 if matrix_name == 'A' else 0x2
    dut.uio_in.value = (opcode << 4) | (byte_idx & 0x0F)
    dut.ui_in.value = val & 0xFF
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

async def load_matrix_A(dut, matrix_4x4):
    """Load complete 4x4 matrix into A (16 bytes)."""
    for i in range(4):
        for j in range(4):
            idx = i * 4 + j
            await write_matrix_byte(dut, 'A', idx, matrix_4x4[i][j])
    dut.uio_in.value = 0x00
    dut.ui_in.value = 0x00
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

async def load_matrix_B(dut, matrix_4x4):
    """Load complete 4x4 matrix into B (16 bytes)."""
    for i in range(4):
        for j in range(4):
            idx = i * 4 + j
            await write_matrix_byte(dut, 'B', idx, matrix_4x4[i][j])
    dut.uio_in.value = 0x00
    dut.ui_in.value = 0x00
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

async def set_dataflow_policy(dut, df_policy):
    """Configure dataflow architecture (OS=0, WS=1, IS=2)."""
    dut.uio_in.value = 0x30
    dut.ui_in.value = df_policy & 0x03
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

async def start_accelerator(dut):
    """Issue start pulse to begin SRAM loading, computation, and result storage."""
    dut.uio_in.value = 0x70
    dut.ui_in.value = 0
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

async def wait_for_done(dut, max_cycles=300):
    """Poll status until computation completes and C is written into SRAM C."""
    dut.uio_in.value = 0x00  # NOP displays status
    dut.ui_in.value = 0x00
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
        status = int(dut.uo_out.value)
        done = status & 0x01
        if done:
            return True
    raise TimeoutError(f"Accelerator did not complete within {max_cycles} cycles")

async def read_sram_c_word(dut, word_idx, byte_sel=0):
    """Read a 16-bit word from SRAM C (word_idx: 0..31)."""
    op = (0x4 << 4) | (word_idx & 0x0F)
    dut.uio_in.value = op
    dut.ui_in.value = ((byte_sel & 1) << 1) | ((word_idx >> 4) & 1)
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    low_byte = int(dut.uo_out.value)
    high_byte = int(dut.uio_out.value)
    return (high_byte << 8) | low_byte

async def read_sram_a_word(dut, word_idx):
    """Read a 16-bit word from SRAM A (word_idx: 0..7)."""
    op = (0x5 << 4) | (word_idx & 0x07)
    dut.uio_in.value = op
    dut.ui_in.value = 0
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    low_byte = int(dut.uo_out.value)
    high_byte = int(dut.uio_out.value)
    dut.uio_in.value = 0x00
    return (high_byte << 8) | low_byte

async def read_sram_b_word(dut, word_idx):
    """Read a 16-bit word from SRAM B (word_idx: 0..7)."""
    op = (0x6 << 4) | (word_idx & 0x07)
    dut.uio_in.value = op
    dut.ui_in.value = 0
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    low_byte = int(dut.uo_out.value)
    high_byte = int(dut.uio_out.value)
    dut.uio_in.value = 0x00
    return (high_byte << 8) | low_byte

async def read_matrix_C(dut):
    """Read the complete 4x4 signed 32-bit result matrix from SRAM C."""
    result = [[0 for _ in range(4)] for _ in range(4)]
    for i in range(4):
        for j in range(4):
            elem = i * 4 + j
            w_low = await read_sram_c_word(dut, 2 * elem)
            w_high = await read_sram_c_word(dut, 2 * elem + 1)
            val_u32 = ((w_high & 0xFFFF) << 16) | (w_low & 0xFFFF)
            if val_u32 >= (1 << 31):
                val_s32 = val_u32 - (1 << 32)
            else:
                val_s32 = val_u32
            result[i][j] = val_s32
    dut.uio_in.value = 0x00
    dut.ui_in.value = 0x00
    return result

# ==============================================================================
# Cocotb Test Cases
# ==============================================================================

@cocotb.test()
async def test_01_reset_state(dut):
    """Test 1: Verify power-on reset state and default pin levels."""
    dut._log.info("Starting test_01_reset_state")
    await reset_dut(dut)

    assert int(dut.uio_oe.value) == 0, f"Expected uio_oe == 0, got {dut.uio_oe.value}"
    status = int(dut.uo_out.value)
    done_bit = status & 0x01
    busy_bit = (status >> 1) & 0x01
    assert done_bit == 0, f"Expected done==0 at reset, got {done_bit}"
    assert busy_bit == 0, f"Expected busy==0 at reset, got {busy_bit}"
    dut._log.info("Reset state verified successfully")


@cocotb.test()
async def test_02_matrix_a_write_readback(dut):
    """Test 2: Write Matrix A via protocol and verify word readback from SRAM A."""
    dut._log.info("Starting test_02_matrix_a_write_readback")
    await reset_dut(dut)

    test_data = [
        [10, 11, 12, 13],
        [20, 21, 22, 23],
        [30, 31, 32, 33],
        [40, 41, 42, 43]
    ]

    await load_matrix_A(dut, test_data)

    # Read back all 8 words of SRAM A
    for w in range(8):
        word_val = await read_sram_a_word(dut, w)
        r0 = (2 * w) // 4
        c0 = (2 * w) % 4
        r1 = (2 * w + 1) // 4
        c1 = (2 * w + 1) % 4
        byte0 = test_data[r0][c0] & 0xFF
        byte1 = test_data[r1][c1] & 0xFF
        expected_word = (byte0 << 8) | byte1
        assert word_val == expected_word, (
            f"SRAM A word {w} mismatch: expected 0x{expected_word:04X}, got 0x{word_val:04X}"
        )

    dut._log.info("Matrix A write and readback verified")


@cocotb.test()
async def test_03_matrix_b_write_readback(dut):
    """Test 3: Write Matrix B via protocol and verify word readback from SRAM B."""
    dut._log.info("Starting test_03_matrix_b_write_readback")
    await reset_dut(dut)

    test_data = [
        [-5, 15, -25, 35],
        [45, -55, 65, -75],
        [85, -95, 105, -115],
        [125, -1, 0, 7]
    ]

    await load_matrix_B(dut, test_data)

    for w in range(8):
        word_val = await read_sram_b_word(dut, w)
        r0 = (2 * w) // 4
        c0 = (2 * w) % 4
        r1 = (2 * w + 1) // 4
        c1 = (2 * w + 1) % 4
        byte0 = test_data[r0][c0] & 0xFF
        byte1 = test_data[r1][c1] & 0xFF
        expected_word = (byte0 << 8) | byte1
        assert word_val == expected_word, (
            f"SRAM B word {w} mismatch: expected 0x{expected_word:04X}, got 0x{word_val:04X}"
        )

    dut._log.info("Matrix B write and readback verified")


@cocotb.test()
async def test_04_dataflow_config(dut):
    """Test 4: Configure dataflow policy and verify status reporting."""
    dut._log.info("Starting test_04_dataflow_config")
    await reset_dut(dut)

    for df in [DF_OS, DF_WS, DF_IS, DF_OS]:
        await set_dataflow_policy(dut, df)
        dut.uio_in.value = 0x00
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
        status = int(dut.uo_out.value)
        reported_df = (status >> 2) & 0x03
        assert reported_df == df, f"Expected df_policy={df}, got {reported_df}"

    dut._log.info("Dataflow policy configuration verified")


@cocotb.test()
async def test_05_output_stationary_identity(dut):
    """Test 5: OS Dataflow with Identity Matrix (I * I = I)."""
    dut._log.info("Starting test_05_output_stationary_identity")
    await reset_dut(dut)

    I = [
        [1, 0, 0, 0],
        [0, 1, 0, 0],
        [0, 0, 1, 0],
        [0, 0, 0, 1]
    ]

    await load_matrix_A(dut, I)
    await load_matrix_B(dut, I)
    await set_dataflow_policy(dut, DF_OS)
    await start_accelerator(dut)
    await wait_for_done(dut)

    C = await read_matrix_C(dut)
    expected_C = matmul_golden(I, I)

    for i in range(4):
        for j in range(4):
            assert C[i][j] == expected_C[i][j], (
                f"OS I*I mismatch at [{i}][{j}]: expected {expected_C[i][j]}, got {C[i][j]}"
            )

    dut._log.info("OS Identity matrix test passed")


@cocotb.test()
async def test_06_weight_stationary_identity(dut):
    """Test 6: WS Dataflow with Identity Matrix (I * I = I)."""
    dut._log.info("Starting test_06_weight_stationary_identity")
    await reset_dut(dut)

    I = [
        [1, 0, 0, 0],
        [0, 1, 0, 0],
        [0, 0, 1, 0],
        [0, 0, 0, 1]
    ]

    await load_matrix_A(dut, I)
    await load_matrix_B(dut, I)
    await set_dataflow_policy(dut, DF_WS)
    await start_accelerator(dut)
    await wait_for_done(dut)

    C = await read_matrix_C(dut)
    expected_C = matmul_golden(I, I)

    for i in range(4):
        for j in range(4):
            assert C[i][j] == expected_C[i][j], (
                f"WS I*I mismatch at [{i}][{j}]: expected {expected_C[i][j]}, got {C[i][j]}"
            )

    dut._log.info("WS Identity matrix test passed")


@cocotb.test()
async def test_07_input_stationary_identity(dut):
    """Test 7: IS Dataflow with Identity Matrix (I * I = I)."""
    dut._log.info("Starting test_07_input_stationary_identity")
    await reset_dut(dut)

    I = [
        [1, 0, 0, 0],
        [0, 1, 0, 0],
        [0, 0, 1, 0],
        [0, 0, 0, 1]
    ]

    await load_matrix_A(dut, I)
    await load_matrix_B(dut, I)
    await set_dataflow_policy(dut, DF_IS)
    await start_accelerator(dut)
    await wait_for_done(dut)

    C = await read_matrix_C(dut)
    expected_C = matmul_golden(I, I)

    for i in range(4):
        for j in range(4):
            assert C[i][j] == expected_C[i][j], (
                f"IS I*I mismatch at [{i}][{j}]: expected {expected_C[i][j]}, got {C[i][j]}"
            )

    dut._log.info("IS Identity matrix test passed")


@cocotb.test()
async def test_08_output_stationary_ones(dut):
    """Test 8: OS Dataflow with all-ones matrices (ones * ones = 4*ones)."""
    dut._log.info("Starting test_08_output_stationary_ones")
    await reset_dut(dut)

    ones = [[1 for _ in range(4)] for _ in range(4)]

    await load_matrix_A(dut, ones)
    await load_matrix_B(dut, ones)
    await set_dataflow_policy(dut, DF_OS)
    await start_accelerator(dut)
    await wait_for_done(dut)

    C = await read_matrix_C(dut)

    for i in range(4):
        for j in range(4):
            assert C[i][j] == 4, f"OS ones*ones mismatch at [{i}][{j}]: expected 4, got {C[i][j]}"

    dut._log.info("OS all-ones test passed")


@cocotb.test()
async def test_09_weight_stationary_ones(dut):
    """Test 9: WS Dataflow with all-ones matrices (ones * ones = 4*ones)."""
    dut._log.info("Starting test_09_weight_stationary_ones")
    await reset_dut(dut)

    ones = [[1 for _ in range(4)] for _ in range(4)]

    await load_matrix_A(dut, ones)
    await load_matrix_B(dut, ones)
    await set_dataflow_policy(dut, DF_WS)
    await start_accelerator(dut)
    await wait_for_done(dut)

    C = await read_matrix_C(dut)

    for i in range(4):
        for j in range(4):
            assert C[i][j] == 4, f"WS ones*ones mismatch at [{i}][{j}]: expected 4, got {C[i][j]}"

    dut._log.info("WS all-ones test passed")


@cocotb.test()
async def test_10_input_stationary_ones(dut):
    """Test 10: IS Dataflow with all-ones matrices (ones * ones = 4*ones)."""
    dut._log.info("Starting test_10_input_stationary_ones")
    await reset_dut(dut)

    ones = [[1 for _ in range(4)] for _ in range(4)]

    await load_matrix_A(dut, ones)
    await load_matrix_B(dut, ones)
    await set_dataflow_policy(dut, DF_IS)
    await start_accelerator(dut)
    await wait_for_done(dut)

    C = await read_matrix_C(dut)

    for i in range(4):
        for j in range(4):
            assert C[i][j] == 4, f"IS ones*ones mismatch at [{i}][{j}]: expected 4, got {C[i][j]}"

    dut._log.info("IS all-ones test passed")


@cocotb.test()
async def test_11_output_stationary_random(dut):
    """Test 11: OS Dataflow with random signed int8 matrices vs reference model."""
    dut._log.info("Starting test_11_output_stationary_random")
    await reset_dut(dut)

    random.seed(42)
    A = [[random.randint(-50, 50) for _ in range(4)] for _ in range(4)]
    B = [[random.randint(-50, 50) for _ in range(4)] for _ in range(4)]

    await load_matrix_A(dut, A)
    await load_matrix_B(dut, B)
    await set_dataflow_policy(dut, DF_OS)
    await start_accelerator(dut)
    await wait_for_done(dut)

    C = await read_matrix_C(dut)
    expected_C = matmul_golden(A, B)

    for i in range(4):
        for j in range(4):
            assert C[i][j] == expected_C[i][j], (
                f"OS random mismatch at [{i}][{j}]: expected {expected_C[i][j]}, got {C[i][j]}"
            )

    dut._log.info("OS random matrix test passed")


@cocotb.test()
async def test_12_weight_stationary_random(dut):
    """Test 12: WS Dataflow with random signed int8 matrices vs reference model."""
    dut._log.info("Starting test_12_weight_stationary_random")
    await reset_dut(dut)

    random.seed(123)
    A = [[random.randint(-50, 50) for _ in range(4)] for _ in range(4)]
    B = [[random.randint(-50, 50) for _ in range(4)] for _ in range(4)]

    await load_matrix_A(dut, A)
    await load_matrix_B(dut, B)
    await set_dataflow_policy(dut, DF_WS)
    await start_accelerator(dut)
    await wait_for_done(dut)

    C = await read_matrix_C(dut)
    expected_C = matmul_golden(A, B)

    for i in range(4):
        for j in range(4):
            assert C[i][j] == expected_C[i][j], (
                f"WS random mismatch at [{i}][{j}]: expected {expected_C[i][j]}, got {C[i][j]}"
            )

    dut._log.info("WS random matrix test passed")


@cocotb.test()
async def test_13_input_stationary_random(dut):
    """Test 13: IS Dataflow with random signed int8 matrices vs reference model."""
    dut._log.info("Starting test_13_input_stationary_random")
    await reset_dut(dut)

    random.seed(999)
    A = [[random.randint(-50, 50) for _ in range(4)] for _ in range(4)]
    B = [[random.randint(-50, 50) for _ in range(4)] for _ in range(4)]

    await load_matrix_A(dut, A)
    await load_matrix_B(dut, B)
    await set_dataflow_policy(dut, DF_IS)
    await start_accelerator(dut)
    await wait_for_done(dut)

    C = await read_matrix_C(dut)
    expected_C = matmul_golden(A, B)

    for i in range(4):
        for j in range(4):
            assert C[i][j] == expected_C[i][j], (
                f"IS random mismatch at [{i}][{j}]: expected {expected_C[i][j]}, got {C[i][j]}"
            )

    dut._log.info("IS random matrix test passed")


@cocotb.test()
async def test_14_boundary_max_positive(dut):
    """Test 14: Boundary values: +127 * +127 * 4 = +64516."""
    dut._log.info("Starting test_14_boundary_max_positive")
    await reset_dut(dut)

    max_pos = [[127 for _ in range(4)] for _ in range(4)]

    await load_matrix_A(dut, max_pos)
    await load_matrix_B(dut, max_pos)
    await set_dataflow_policy(dut, DF_OS)
    await start_accelerator(dut)
    await wait_for_done(dut)

    C = await read_matrix_C(dut)
    expected = 4 * 127 * 127  # 64516

    for i in range(4):
        for j in range(4):
            assert C[i][j] == expected, (
                f"Max positive mismatch at [{i}][{j}]: expected {expected}, got {C[i][j]}"
            )

    dut._log.info("Max positive boundary test passed")


@cocotb.test()
async def test_15_boundary_max_negative(dut):
    """Test 15: Boundary values: -128 * -128 * 4 = +65536, and -128 * +127 * 4 = -65024."""
    dut._log.info("Starting test_15_boundary_max_negative")
    await reset_dut(dut)

    A_neg = [[-128 for _ in range(4)] for _ in range(4)]
    B_pos = [[127 for _ in range(4)] for _ in range(4)]

    await load_matrix_A(dut, A_neg)
    await load_matrix_B(dut, B_pos)
    await set_dataflow_policy(dut, DF_WS)
    await start_accelerator(dut)
    await wait_for_done(dut)

    C = await read_matrix_C(dut)
    expected = 4 * (-128) * 127  # -65024

    for i in range(4):
        for j in range(4):
            assert C[i][j] == expected, (
                f"Negative boundary mismatch at [{i}][{j}]: expected {expected}, got {C[i][j]}"
            )

    dut._log.info("Negative boundary test passed")


@cocotb.test()
async def test_16_boundary_zeros(dut):
    """Test 16: Zero matrix multiplication."""
    dut._log.info("Starting test_16_boundary_zeros")
    await reset_dut(dut)

    zeros = [[0 for _ in range(4)] for _ in range(4)]
    non_zero = [[7 for _ in range(4)] for _ in range(4)]

    await load_matrix_A(dut, zeros)
    await load_matrix_B(dut, non_zero)
    await set_dataflow_policy(dut, DF_IS)
    await start_accelerator(dut)
    await wait_for_done(dut)

    C = await read_matrix_C(dut)

    for i in range(4):
        for j in range(4):
            assert C[i][j] == 0, f"Zero test mismatch at [{i}][{j}]: expected 0, got {C[i][j]}"

    dut._log.info("Zero matrix test passed")


@cocotb.test()
async def test_17_consecutive_computes_no_reset(dut):
    """Test 17: Consecutive computations with all three dataflows without hardware reset."""
    dut._log.info("Starting test_17_consecutive_computes_no_reset")
    await reset_dut(dut)

    test_pairs = [
        # (A, B, policy, name)
        (
            [[2, 1, 0, 0], [0, 2, 1, 0], [0, 0, 2, 1], [0, 0, 0, 2]],
            [[1, 0, 0, 0], [1, 1, 0, 0], [0, 1, 1, 0], [0, 0, 1, 1]],
            DF_OS, "Run 1: OS"
        ),
        (
            [[3, -1, 2, 0], [1, 2, -1, 1], [0, 1, 3, -2], [2, 0, 1, 1]],
            [[1, 2, 0, 1], [-1, 0, 2, 1], [2, 1, -1, 0], [0, 1, 1, 2]],
            DF_WS, "Run 2: WS"
        ),
        (
            [[1, 2, 3, 4], [4, 3, 2, 1], [2, 1, 4, 3], [3, 4, 1, 2]],
            [[2, 0, 1, 1], [1, 2, 0, 1], [0, 1, 2, 0], [1, 0, 1, 2]],
            DF_IS, "Run 3: IS"
        )
    ]

    for A, B, policy, run_name in test_pairs:
        dut._log.info(f"Executing {run_name}")
        await load_matrix_A(dut, A)
        await load_matrix_B(dut, B)
        await set_dataflow_policy(dut, policy)
        await start_accelerator(dut)
        await wait_for_done(dut)

        C = await read_matrix_C(dut)
        expected_C = matmul_golden(A, B)

        for i in range(4):
            for j in range(4):
                assert C[i][j] == expected_C[i][j], (
                    f"{run_name} mismatch at [{i}][{j}]: expected {expected_C[i][j]}, got {C[i][j]}"
                )
        dut._log.info(f"{run_name} passed")

    dut._log.info("All consecutive runs passed without reset")


@cocotb.test()
async def test_18_protocol_byte_select(dut):
    """Test 18: Verify 8-bit host byte-select reading from SRAM C on uo_out."""
    dut._log.info("Starting test_18_protocol_byte_select")
    await reset_dut(dut)

    A = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
    B = [[5, 0, 0, 0], [0, 5, 0, 0], [0, 0, 5, 0], [0, 0, 0, 5]]

    await load_matrix_A(dut, A)
    await load_matrix_B(dut, B)
    await set_dataflow_policy(dut, DF_OS)
    await start_accelerator(dut)
    await wait_for_done(dut)

    # Word 0 corresponds to element C[0][0] low 16 bits (expected: 5 = 0x0005)
    # Read low byte (byte_sel=0)
    op = 0x40  # opcode 4, word 0
    dut.uio_in.value = op
    dut.ui_in.value = 0x00  # byte_sel=0
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    low_b = int(dut.uo_out.value)
    assert low_b == 0x05, f"Expected low byte 0x05, got 0x{low_b:02X}"

    # Read high byte (byte_sel=1)
    dut.uio_in.value = op
    dut.ui_in.value = 0x02  # byte_sel=1 (bit 1 = 1)
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    high_b = int(dut.uo_out.value)
    assert high_b == 0x00, f"Expected high byte 0x00, got 0x{high_b:02X}"

    dut._log.info("Protocol byte select verified successfully")