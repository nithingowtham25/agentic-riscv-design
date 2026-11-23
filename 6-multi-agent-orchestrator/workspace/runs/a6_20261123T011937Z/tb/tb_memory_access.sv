// tb_memory_access.sv
// Self-checking testbench for the memory_access RV32I load/store unit.
//
// Compatible with Icarus Verilog 12 (SystemVerilog subset).
// Covers: store path (SB/SH/SW at all aligned offsets), load path
// (LB/LH/LW/LBU/LHU with sign/zero extension), deterministic defaults,
// boundary values, and corner cases per the spec.
//
// Summary lines printed at end of simulation:
//   TESTS_PASSED: N
//   TESTS_ERRORS: N
//   TESTS_TOTAL:  N
//   RESULT: PASS | FAIL

`timescale 1ns/1ps

module tb_memory_access;

    // -----------------------------------------------------------------------
    // DUT interface signals
    // -----------------------------------------------------------------------
    logic [1:0]  MemRW;
    logic [2:0]  Funct3;
    logic [1:0]  AddrLSB;
    logic [31:0] StoreData;
    logic [31:0] ReadData;

    logic [31:0] WriteData;
    logic [3:0]  ByteEnable;
    logic [31:0] LoadData;

    // -----------------------------------------------------------------------
    // DUT instantiation
    // -----------------------------------------------------------------------
    memory_access dut (
        .MemRW     (MemRW),
        .Funct3    (Funct3),
        .AddrLSB   (AddrLSB),
        .StoreData (StoreData),
        .ReadData  (ReadData),
        .WriteData (WriteData),
        .ByteEnable(ByteEnable),
        .LoadData  (LoadData)
    );

    // -----------------------------------------------------------------------
    // Test counters
    // -----------------------------------------------------------------------
    integer tests_passed;
    integer tests_errors;
    integer tests_total;

    // -----------------------------------------------------------------------
    // Apply-and-check task
    // Drives inputs, waits for combinational settling, compares all outputs.
    // -----------------------------------------------------------------------
    task automatic apply_check;
        input [1:0]  t_MemRW;
        input [2:0]  t_Funct3;
        input [1:0]  t_AddrLSB;
        input [31:0] t_StoreData;
        input [31:0] t_ReadData;
        input [31:0] exp_WriteData;
        input [3:0]  exp_ByteEnable;
        input [31:0] exp_LoadData;
        input string label;
        begin : chk
            logic pass_flag;
            MemRW     = t_MemRW;
            Funct3    = t_Funct3;
            AddrLSB   = t_AddrLSB;
            StoreData = t_StoreData;
            ReadData  = t_ReadData;
            #2;  // allow combinational propagation

            pass_flag = 1'b1;

            if (WriteData !== exp_WriteData) begin
                $display("MISMATCH [%s] WriteData: got %08h expected %08h",
                         label, WriteData, exp_WriteData);
                pass_flag = 1'b0;
            end
            if (ByteEnable !== exp_ByteEnable) begin
                $display("MISMATCH [%s] ByteEnable: got %04b expected %04b",
                         label, ByteEnable, exp_ByteEnable);
                pass_flag = 1'b0;
            end
            if (LoadData !== exp_LoadData) begin
                $display("MISMATCH [%s] LoadData: got %08h expected %08h",
                         label, LoadData, exp_LoadData);
                pass_flag = 1'b0;
            end

            tests_total = tests_total + 1;
            if (pass_flag) begin
                tests_passed = tests_passed + 1;
            end else begin
                tests_errors = tests_errors + 1;
            end
        end
    endtask

    // -----------------------------------------------------------------------
    // Main test sequence
    // -----------------------------------------------------------------------
    initial begin
        tests_passed = 0;
        tests_errors = 0;
        tests_total  = 0;

        // Initialise to safe state
        MemRW     = 2'b00;
        Funct3    = 3'b000;
        AddrLSB   = 2'b00;
        StoreData = 32'h0;
        ReadData  = 32'h0;
        #5;

        // ===================================================================
        // Section 1: Deterministic defaults – MemRW=00 (no access)
        // Expect: WriteData=0, ByteEnable=0, LoadData=0
        // ===================================================================
        $display("-- Section 1: No-access defaults (MemRW=00) --");

        apply_check(2'b00, 3'b000, 2'b00, 32'hDEADBEEF, 32'hCAFEBABE,
                    32'h0, 4'b0000, 32'h0, "noop_SB_offset0");

        apply_check(2'b00, 3'b001, 2'b10, 32'hDEADBEEF, 32'hCAFEBABE,
                    32'h0, 4'b0000, 32'h0, "noop_SH_offset2");

        apply_check(2'b00, 3'b010, 2'b00, 32'hDEADBEEF, 32'hCAFEBABE,
                    32'h0, 4'b0000, 32'h0, "noop_SW");

        apply_check(2'b00, 3'b100, 2'b01, 32'hDEADBEEF, 32'hCAFEBABE,
                    32'h0, 4'b0000, 32'h0, "noop_LBU");

        // ===================================================================
        // Section 2: MemRW=11 (unused encoding) – same defaults
        // ===================================================================
        $display("-- Section 2: Unused encoding (MemRW=11) --");

        apply_check(2'b11, 3'b000, 2'b00, 32'hABCDABCD, 32'h12341234,
                    32'h0, 4'b0000, 32'h0, "unused_MemRW11_SB");

        apply_check(2'b11, 3'b010, 2'b00, 32'hABCDABCD, 32'h12341234,
                    32'h0, 4'b0000, 32'h0, "unused_MemRW11_SW");

        // ===================================================================
        // Section 3: Store path  (MemRW=01)
        // Verify WriteData, ByteEnable; LoadData must remain 0.
        // ===================================================================
        $display("-- Section 3: SB (Funct3=000) stores --");

        // SB offset 0 – byte in [7:0]
        apply_check(2'b01, 3'b000, 2'b00, 32'hABCDEF42, 32'h0,
                    32'h00000042, 4'b0001, 32'h0, "SB_off0_nominal");

        // SB offset 1 – byte in [15:8]
        apply_check(2'b01, 3'b000, 2'b01, 32'hABCDEF42, 32'h0,
                    32'h00004200, 4'b0010, 32'h0, "SB_off1_nominal");

        // SB offset 2 – byte in [23:16]
        apply_check(2'b01, 3'b000, 2'b10, 32'hABCDEF42, 32'h0,
                    32'h00420000, 4'b0100, 32'h0, "SB_off2_nominal");

        // SB offset 3 – byte in [31:24]
        apply_check(2'b01, 3'b000, 2'b11, 32'hABCDEF42, 32'h0,
                    32'h42000000, 4'b1000, 32'h0, "SB_off3_nominal");

        // SB boundary: StoreData all-zeros
        apply_check(2'b01, 3'b000, 2'b00, 32'h00000000, 32'h0,
                    32'h00000000, 4'b0001, 32'h0, "SB_off0_zero");

        // SB boundary: StoreData all-ones, only LSByte matters
        apply_check(2'b01, 3'b000, 2'b00, 32'hFFFFFFFF, 32'h0,
                    32'h000000FF, 4'b0001, 32'h0, "SB_off0_allones");

        apply_check(2'b01, 3'b000, 2'b11, 32'hFFFFFFFF, 32'h0,
                    32'hFF000000, 4'b1000, 32'h0, "SB_off3_allones");

        // SB: upper bits of StoreData must be ignored (only [7:0] placed)
        apply_check(2'b01, 3'b000, 2'b01, 32'hFFFFFF5A, 32'h0,
                    32'h00005A00, 4'b0010, 32'h0, "SB_off1_upper_ignored");

        $display("-- Section 3: SH (Funct3=001) stores --");

        // SH offset 0 – halfword in [15:0]
        apply_check(2'b01, 3'b001, 2'b00, 32'hABCD1234, 32'h0,
                    32'h00001234, 4'b0011, 32'h0, "SH_off0_nominal");

        // SH offset 2 – halfword in [31:16]
        apply_check(2'b01, 3'b001, 2'b10, 32'hABCD1234, 32'h0,
                    32'h12340000, 4'b1100, 32'h0, "SH_off2_nominal");

        // SH boundary: all-zeros
        apply_check(2'b01, 3'b001, 2'b00, 32'h00000000, 32'h0,
                    32'h00000000, 4'b0011, 32'h0, "SH_off0_zero");

        // SH boundary: all-ones (only lower 16b of StoreData placed)
        apply_check(2'b01, 3'b001, 2'b00, 32'hFFFFFFFF, 32'h0,
                    32'h0000FFFF, 4'b0011, 32'h0, "SH_off0_allones");

        apply_check(2'b01, 3'b001, 2'b10, 32'hFFFFFFFF, 32'h0,
                    32'hFFFF0000, 4'b1100, 32'h0, "SH_off2_allones");

        // SH offset 1 (AddrLSB[1]==0) – treated same as offset 0 per spec
        apply_check(2'b01, 3'b001, 2'b01, 32'hABCD5678, 32'h0,
                    32'h00005678, 4'b0011, 32'h0, "SH_off1_treated_as_lo");

        $display("-- Section 3: SW (Funct3=010) stores --");

        // SW: WriteData == StoreData, ByteEnable=1111
        apply_check(2'b01, 3'b010, 2'b00, 32'hDEADBEEF, 32'h0,
                    32'hDEADBEEF, 4'b1111, 32'h0, "SW_nominal");

        apply_check(2'b01, 3'b010, 2'b00, 32'h00000000, 32'h0,
                    32'h00000000, 4'b1111, 32'h0, "SW_zero");

        apply_check(2'b01, 3'b010, 2'b00, 32'hFFFFFFFF, 32'h0,
                    32'hFFFFFFFF, 4'b1111, 32'h0, "SW_allones");

        apply_check(2'b01, 3'b010, 2'b00, 32'h80000001, 32'h0,
                    32'h80000001, 4'b1111, 32'h0, "SW_boundary");

        // Store with unknown Funct3 – default: ByteEnable=0, WriteData=0
        apply_check(2'b01, 3'b011, 2'b00, 32'hDEADBEEF, 32'h0,
                    32'h00000000, 4'b0000, 32'h0, "store_bad_funct3");

        // ===================================================================
        // Section 4: Load path  (MemRW=10)
        // Verify LoadData; WriteData and ByteEnable must remain 0.
        // ===================================================================
        $display("-- Section 4: LB (Funct3=000, sign-extend) loads --");

        // LB off0: ReadData[7:0]=0x78 (positive) => 0x00000078
        apply_check(2'b10, 3'b000, 2'b00, 32'h0, 32'h12345678,
                    32'h0, 4'b0000, 32'h00000078, "LB_off0_positive");

        // LB off0: ReadData[7:0]=0xFF (negative) => 0xFFFFFFFF
        apply_check(2'b10, 3'b000, 2'b00, 32'h0, 32'h123456FF,
                    32'h0, 4'b0000, 32'hFFFFFFFF, "LB_off0_negative");

        // LB off1: ReadData[15:8]=0x56
        apply_check(2'b10, 3'b000, 2'b01, 32'h0, 32'h12345678,
                    32'h0, 4'b0000, 32'h00000056, "LB_off1_positive");

        // LB off1: ReadData[15:8]=0x80 => 0xFFFFFF80
        apply_check(2'b10, 3'b000, 2'b01, 32'h0, 32'h12348056,
                    32'h0, 4'b0000, 32'hFFFFFF80, "LB_off1_negative");

        // LB off2: ReadData[23:16]=0x34
        apply_check(2'b10, 3'b000, 2'b10, 32'h0, 32'h12345678,
                    32'h0, 4'b0000, 32'h00000034, "LB_off2_positive");

        // LB off2: ReadData[23:16]=0xAB => 0xFFFFFFAB
        apply_check(2'b10, 3'b000, 2'b10, 32'h0, 32'h12AB5678,
                    32'h0, 4'b0000, 32'hFFFFFFAB, "LB_off2_negative");

        // LB off3: ReadData[31:24]=0x12
        apply_check(2'b10, 3'b000, 2'b11, 32'h0, 32'h12345678,
                    32'h0, 4'b0000, 32'h00000012, "LB_off3_positive");

        // LB off3: ReadData[31:24]=0xDE => 0xFFFFFFDE
        apply_check(2'b10, 3'b000, 2'b11, 32'h0, 32'hDE345678,
                    32'h0, 4'b0000, 32'hFFFFFFDE, "LB_off3_negative");

        // LB boundary: 0x7F (max positive signed byte) => 0x0000007F
        apply_check(2'b10, 3'b000, 2'b00, 32'h0, 32'h0000007F,
                    32'h0, 4'b0000, 32'h0000007F, "LB_off0_maxpos");

        // LB boundary: 0x80 (min negative signed byte) => 0xFFFFFF80
        apply_check(2'b10, 3'b000, 2'b00, 32'h0, 32'h00000080,
                    32'h0, 4'b0000, 32'hFFFFFF80, "LB_off0_minneg");

        $display("-- Section 4: LH (Funct3=001, sign-extend) loads --");

        // LH off0: ReadData[15:0]=0x5678 (positive)
        apply_check(2'b10, 3'b001, 2'b00, 32'h0, 32'h12345678,
                    32'h0, 4'b0000, 32'h00005678, "LH_off0_positive");

        // LH off0: ReadData[15:0]=0xFEDC (negative) => 0xFFFFFEDC
        apply_check(2'b10, 3'b001, 2'b00, 32'h0, 32'h1234FEDC,
                    32'h0, 4'b0000, 32'hFFFFFEDC, "LH_off0_negative");

        // LH off2: ReadData[31:16]=0x1234
        apply_check(2'b10, 3'b001, 2'b10, 32'h0, 32'h12345678,
                    32'h0, 4'b0000, 32'h00001234, "LH_off2_positive");

        // LH off2: ReadData[31:16]=0xABCD => 0xFFFFABCD
        apply_check(2'b10, 3'b001, 2'b10, 32'h0, 32'hABCD5678,
                    32'h0, 4'b0000, 32'hFFFFABCD, "LH_off2_negative");

        // LH boundary: 0x7FFF (max pos) => 0x00007FFF
        apply_check(2'b10, 3'b001, 2'b00, 32'h0, 32'h00007FFF,
                    32'h0, 4'b0000, 32'h00007FFF, "LH_off0_maxpos");

        // LH boundary: 0x8000 (min neg) => 0xFFFF8000
        apply_check(2'b10, 3'b001, 2'b00, 32'h0, 32'h00008000,
                    32'h0, 4'b0000, 32'hFFFF8000, "LH_off0_minneg");

        // LH off1 (AddrLSB[1]==0) => treated as lower halfword
        apply_check(2'b10, 3'b001, 2'b01, 32'h0, 32'hABCD5678,
                    32'h0, 4'b0000, 32'h00005678, "LH_off1_lower_half");

        $display("-- Section 4: LW (Funct3=010) loads --");

        // LW: LoadData == ReadData
        apply_check(2'b10, 3'b010, 2'b00, 32'h0, 32'hDEADBEEF,
                    32'h0, 4'b0000, 32'hDEADBEEF, "LW_nominal");

        apply_check(2'b10, 3'b010, 2'b00, 32'h0, 32'h00000000,
                    32'h0, 4'b0000, 32'h00000000, "LW_zero");

        apply_check(2'b10, 3'b010, 2'b00, 32'h0, 32'hFFFFFFFF,
                    32'h0, 4'b0000, 32'hFFFFFFFF, "LW_allones");

        apply_check(2'b10, 3'b010, 2'b00, 32'h0, 32'h80000000,
                    32'h0, 4'b0000, 32'h80000000, "LW_msb_set");

        $display("-- Section 4: LBU (Funct3=100, zero-extend) loads --");

        // LBU off0: 0xFF => 0x000000FF (no sign extension)
        apply_check(2'b10, 3'b100, 2'b00, 32'h0, 32'h123456FF,
                    32'h0, 4'b0000, 32'h000000FF, "LBU_off0_max");

        apply_check(2'b10, 3'b100, 2'b00, 32'h0, 32'h12345678,
                    32'h0, 4'b0000, 32'h00000078, "LBU_off0_low");

        // LBU off1: ReadData[15:8]=0x56 => 0x00000056
        apply_check(2'b10, 3'b100, 2'b01, 32'h0, 32'h12345678,
                    32'h0, 4'b0000, 32'h00000056, "LBU_off1");

        // LBU off2: ReadData[23:16]=0xEF => 0x000000EF
        apply_check(2'b10, 3'b100, 2'b10, 32'h0, 32'h12EF5678,
                    32'h0, 4'b0000, 32'h000000EF, "LBU_off2");

        // LBU off3: ReadData[31:24]=0xAB => 0x000000AB
        apply_check(2'b10, 3'b100, 2'b11, 32'h0, 32'hABCDEF99,
                    32'h0, 4'b0000, 32'h000000AB, "LBU_off3");

        // LBU boundary: 0x80 must NOT sign-extend => 0x00000080
        apply_check(2'b10, 3'b100, 2'b00, 32'h0, 32'h00000080,
                    32'h0, 4'b0000, 32'h00000080, "LBU_off0_no_signext");

        $display("-- Section 4: LHU (Funct3=101, zero-extend) loads --");

        // LHU off0: 0xFEDC => 0x0000FEDC
        apply_check(2'b10, 3'b101, 2'b00, 32'h0, 32'h1234FEDC,
                    32'h0, 4'b0000, 32'h0000FEDC, "LHU_off0_max");

        // LHU off2: 0xABCD => 0x0000ABCD
        apply_check(2'b10, 3'b101, 2'b10, 32'h0, 32'hABCD5678,
                    32'h0, 4'b0000, 32'h0000ABCD, "LHU_off2_neg_val");

        // LHU off0: 0x0000 => 0x00000000
        apply_check(2'b10, 3'b101, 2'b00, 32'h0, 32'h12340000,
                    32'h0, 4'b0000, 32'h00000000, "LHU_off0_zero");

        // LHU off2: 0x7FFF => 0x00007FFF
        apply_check(2'b10, 3'b101, 2'b10, 32'h0, 32'h7FFF1234,
                    32'h0, 4'b0000, 32'h00007FFF, "LHU_off2_pos");

        // LHU off1 (AddrLSB[1]==0 => lower half): 0xFEDC => 0x0000FEDC
        apply_check(2'b10, 3'b101, 2'b01, 32'h0, 32'hABCDFEDC,
                    32'h0, 4'b0000, 32'h0000FEDC, "LHU_off1_lower");

        // LHU: 0x8000 must NOT sign-extend => 0x00008000
        apply_check(2'b10, 3'b101, 2'b00, 32'h0, 32'h00008000,
                    32'h0, 4'b0000, 32'h00008000, "LHU_off0_no_signext");

        // Load with unknown Funct3 – default: LoadData=0
        apply_check(2'b10, 3'b011, 2'b00, 32'h0, 32'hDEADBEEF,
                    32'h0, 4'b0000, 32'h00000000, "load_bad_funct3");

        // ===================================================================
        // Section 5: Store/load isolation – wrong path output must be 0
        // ===================================================================
        $display("-- Section 5: Path isolation checks --");

        // Store: LoadData must be 0 regardless of ReadData content
        apply_check(2'b01, 3'b010, 2'b00, 32'hDEADBEEF, 32'hCAFEBABE,
                    32'hDEADBEEF, 4'b1111, 32'h0, "store_loaddata_isolated");

        apply_check(2'b01, 3'b000, 2'b01, 32'h000000AA, 32'hCAFEBABE,
                    32'h0000AA00, 4'b0010, 32'h0, "SB_loaddata_isolated");

        // Load: WriteData and ByteEnable must be 0 regardless of StoreData
        apply_check(2'b10, 3'b010, 2'b00, 32'hDEADBEEF, 32'hCAFEBABE,
                    32'h0, 4'b0000, 32'hCAFEBABE, "load_writedata_isolated");

        apply_check(2'b10, 3'b000, 2'b00, 32'hDEADBEEF, 32'h000000AB,
                    32'h0, 4'b0000, 32'hFFFFFFAB, "LB_writedata_isolated");

        // ===================================================================
        // Section 6: All-zeros and all-ones corner cases
        // ===================================================================
        $display("-- Section 6: All-zeros / all-ones corner cases --");

        apply_check(2'b01, 3'b010, 2'b00, 32'h00000000, 32'hFFFFFFFF,
                    32'h00000000, 4'b1111, 32'h0, "SW_zero_storedata");

        apply_check(2'b10, 3'b010, 2'b00, 32'h00000000, 32'hFFFFFFFF,
                    32'h0, 4'b0000, 32'hFFFFFFFF, "LW_allones_readdata");

        apply_check(2'b10, 3'b010, 2'b00, 32'h00000000, 32'h00000000,
                    32'h0, 4'b0000, 32'h00000000, "LW_allzeros_readdata");

        apply_check(2'b10, 3'b000, 2'b00, 32'h0, 32'h00000000,
                    32'h0, 4'b0000, 32'h00000000, "LB_zero_readdata");

        apply_check(2'b10, 3'b001, 2'b00, 32'h0, 32'h00000000,
                    32'h0, 4'b0000, 32'h00000000, "LH_zero_readdata");

        apply_check(2'b10, 3'b100, 2'b00, 32'h0, 32'h00000000,
                    32'h0, 4'b0000, 32'h00000000, "LBU_zero_readdata");

        apply_check(2'b10, 3'b101, 2'b00, 32'h0, 32'h00000000,
                    32'h0, 4'b0000, 32'h00000000, "LHU_zero_readdata");

        // ===================================================================
        // Section 7: Explicit spec examples (from spec document)
        // ===================================================================
        $display("-- Section 7: Spec verbatim examples --");

        // SB at byte offset 0: ByteEnable=0001, byte placed in WriteData[7:0]
        apply_check(2'b01, 3'b000, 2'b00, 32'hABCDEFAA, 32'h0,
                    32'h000000AA, 4'b0001, 32'h0, "spec_SB_off0");

        // SB at byte offset 2: ByteEnable=0100, byte in WriteData[23:16]
        apply_check(2'b01, 3'b000, 2'b10, 32'hABCDEFAA, 32'h0,
                    32'h00AA0000, 4'b0100, 32'h0, "spec_SB_off2");

        // SH at offset 0: ByteEnable=0011
        apply_check(2'b01, 3'b001, 2'b00, 32'hABCD1234, 32'h0,
                    32'h00001234, 4'b0011, 32'h0, "spec_SH_off0");

        // SH at offset 2: ByteEnable=1100
        apply_check(2'b01, 3'b001, 2'b10, 32'hABCD1234, 32'h0,
                    32'h12340000, 4'b1100, 32'h0, "spec_SH_off2");

        // SW at offset 0: ByteEnable=1111, WriteData=StoreData
        apply_check(2'b01, 3'b010, 2'b00, 32'h12345678, 32'h0,
                    32'h12345678, 4'b1111, 32'h0, "spec_SW_off0");

        // ===================================================================
        // Section 8: Extended robustness – targeted gap closure
        //
        // Gap A: Store Funct3 outside SB/SH/SW (must all yield defaults)
        // Gap B: Load  Funct3 outside LB/LH/LW/LBU/LHU (must yield LoadData=0)
        // Gap C: SW  AddrLSB independence (spec: offset 0 only;
        //        RTL must ignore AddrLSB and always produce BE=1111, WD=StoreData)
        // Gap D: LW  AddrLSB independence (RTL must ignore AddrLSB; LD=ReadData)
        // Gap E: SH  at AddrLSB=11 (AddrLSB[1]==1 → upper-half lane, same as off2)
        // Gap F: LH  at AddrLSB=11 – positive and negative sign-extension
        // Gap G: LHU at AddrLSB=11
        // Gap H: LBU no-sign-extension at offsets 1/2/3 with MSB-set byte
        // Gap I: LH  at AddrLSB=01 with negative halfword (sign-extension of lower
        //        halfword when AddrLSB[1]==0)
        // ===================================================================
        $display("-- Section 8: Extended robustness checks --");

        // --- Gap A: Store bad Funct3=100,101,110,111 (default: BE=0, WD=0) ---
        apply_check(2'b01, 3'b100, 2'b00, 32'hDEADBEEF, 32'h0,
                    32'h0, 4'b0000, 32'h0, "store_funct3_100");

        apply_check(2'b01, 3'b101, 2'b00, 32'hDEADBEEF, 32'h0,
                    32'h0, 4'b0000, 32'h0, "store_funct3_101");

        apply_check(2'b01, 3'b110, 2'b00, 32'hDEADBEEF, 32'h0,
                    32'h0, 4'b0000, 32'h0, "store_funct3_110");

        apply_check(2'b01, 3'b111, 2'b00, 32'hDEADBEEF, 32'h0,
                    32'h0, 4'b0000, 32'h0, "store_funct3_111");

        // --- Gap B: Load bad Funct3=110,111 (default: LoadData=0) ---
        apply_check(2'b10, 3'b110, 2'b00, 32'h0, 32'hDEADBEEF,
                    32'h0, 4'b0000, 32'h0, "load_funct3_110");

        apply_check(2'b10, 3'b111, 2'b00, 32'h0, 32'hDEADBEEF,
                    32'h0, 4'b0000, 32'h0, "load_funct3_111");

        // --- Gap C: SW AddrLSB independence ---
        // SW (Funct3=010) ignores AddrLSB; ByteEnable=1111, WriteData=StoreData
        apply_check(2'b01, 3'b010, 2'b01, 32'hDEADBEEF, 32'h0,
                    32'hDEADBEEF, 4'b1111, 32'h0, "SW_off1_addrlsb_ignored");

        apply_check(2'b01, 3'b010, 2'b10, 32'hCAFEBABE, 32'h0,
                    32'hCAFEBABE, 4'b1111, 32'h0, "SW_off2_addrlsb_ignored");

        apply_check(2'b01, 3'b010, 2'b11, 32'h12345678, 32'h0,
                    32'h12345678, 4'b1111, 32'h0, "SW_off3_addrlsb_ignored");

        // --- Gap D: LW AddrLSB independence ---
        // LW (Funct3=010) ignores AddrLSB; LoadData=ReadData
        apply_check(2'b10, 3'b010, 2'b01, 32'h0, 32'hDEADBEEF,
                    32'h0, 4'b0000, 32'hDEADBEEF, "LW_off1_addrlsb_ignored");

        apply_check(2'b10, 3'b010, 2'b10, 32'h0, 32'hCAFEBABE,
                    32'h0, 4'b0000, 32'hCAFEBABE, "LW_off2_addrlsb_ignored");

        apply_check(2'b10, 3'b010, 2'b11, 32'h0, 32'h12345678,
                    32'h0, 4'b0000, 32'h12345678, "LW_off3_addrlsb_ignored");

        // --- Gap E: SH at AddrLSB=11 → AddrLSB[1]==1 → upper-half lane ---
        // Expected: ByteEnable=1100, WriteData={StoreData[15:0],16'b0}
        apply_check(2'b01, 3'b001, 2'b11, 32'hABCD1234, 32'h0,
                    32'h12340000, 4'b1100, 32'h0, "SH_off3_as_hi");

        // --- Gap F: LH at AddrLSB=11 → upper-half sign-extension ---
        // Off3: AddrLSB[1]==1 → sel_half = ReadData[31:16]
        apply_check(2'b10, 3'b001, 2'b11, 32'h0, 32'h12345678,
                    32'h0, 4'b0000, 32'h00001234, "LH_off3_positive");

        apply_check(2'b10, 3'b001, 2'b11, 32'h0, 32'hABCD5678,
                    32'h0, 4'b0000, 32'hFFFFABCD, "LH_off3_negative");

        // --- Gap G: LHU at AddrLSB=11 → upper-half zero-extension ---
        apply_check(2'b10, 3'b101, 2'b11, 32'h0, 32'hABCD5678,
                    32'h0, 4'b0000, 32'h0000ABCD, "LHU_off3_neg_val");

        // --- Gap H: LBU no-sign-extension at offsets 1,2,3 with MSB-set byte ---
        // 0x80 must NOT sign-extend: LoadData must be 0x00000080
        // Off1: ReadData[15:8]=0x80
        apply_check(2'b10, 3'b100, 2'b01, 32'h0, 32'h00008056,
                    32'h0, 4'b0000, 32'h00000080, "LBU_off1_no_signext");

        // Off2: ReadData[23:16]=0x80
        apply_check(2'b10, 3'b100, 2'b10, 32'h0, 32'h00800056,
                    32'h0, 4'b0000, 32'h00000080, "LBU_off2_no_signext");

        // Off3: ReadData[31:24]=0x80
        apply_check(2'b10, 3'b100, 2'b11, 32'h0, 32'h80005678,
                    32'h0, 4'b0000, 32'h00000080, "LBU_off3_no_signext");

        // --- Gap I: LH at AddrLSB=01 with negative lower halfword ---
        // AddrLSB[1]==0 → sel_half = ReadData[15:0] = 0xFEDC → sign-extend to 0xFFFFFEDC
        apply_check(2'b10, 3'b001, 2'b01, 32'h0, 32'hABCDFEDC,
                    32'h0, 4'b0000, 32'hFFFFFEDC, "LH_off1_negative");

        // ===================================================================
        // Final summary
        // ===================================================================
        $display("--------------------------------------------------");
        $display("TESTS_PASSED: %0d", tests_passed);
        $display("TESTS_ERRORS: %0d", tests_errors);
        $display("TESTS_TOTAL:  %0d", tests_total);
        if (tests_errors == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");

        $finish;
    end

endmodule
