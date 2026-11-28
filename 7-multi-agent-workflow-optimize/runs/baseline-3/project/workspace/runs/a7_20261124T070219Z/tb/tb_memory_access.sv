// tb_memory_access.sv
// Self-checking testbench for the memory_access RV32I load/store unit.
//
// Coverage:
//   - STORE (MemRW=01): SB at all 4 byte offsets, SH at both halfword offsets, SW
//   - LOAD  (MemRW=10): LB/LBU at all 4 byte offsets; LH/LHU at both halfword
//                       offsets; LW; sign/zero extension edge cases
//   - DEFAULTS         : MemRW=00 (idle), MemRW=11 (unused) → deterministic zeros
//   - BOUNDARY VALUES  : all-zeros / all-ones patterns, alternating bits
//
// Summary lines (required by framework):
//   TESTS_PASSED <n>
//   TESTS_ERRORS <n>
//   TESTS_TOTAL  <n>
//   RESULT: PASS | RESULT: FAIL

`timescale 1ns/1ps

module tb_memory_access;

    // -----------------------------------------------------------------------
    // DUT ports
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
    // Counters
    // -----------------------------------------------------------------------
    integer tests_passed;
    integer tests_errors;
    integer tests_total;

    // -----------------------------------------------------------------------
    // Convenience task: apply inputs, evaluate after propagation delay,
    // compare expected values and update counters.
    // -----------------------------------------------------------------------
    task automatic check_store(
        input logic [1:0]  t_MemRW,
        input logic [2:0]  t_Funct3,
        input logic [1:0]  t_AddrLSB,
        input logic [31:0] t_StoreData,
        input logic [3:0]  exp_BE,
        input logic [31:0] exp_WD,
        input string       label
    );
        MemRW     = t_MemRW;
        Funct3    = t_Funct3;
        AddrLSB   = t_AddrLSB;
        StoreData = t_StoreData;
        ReadData  = 32'h0;
        #1;
        tests_total = tests_total + 1;
        if ((ByteEnable === exp_BE) && (WriteData === exp_WD) && (LoadData === 32'h0)) begin
            tests_passed = tests_passed + 1;
        end else begin
            tests_errors = tests_errors + 1;
            $display("MISMATCH [%s]", label);
            if (ByteEnable !== exp_BE)
                $display("  ByteEnable: got %04b  exp %04b", ByteEnable, exp_BE);
            if (WriteData !== exp_WD)
                $display("  WriteData:  got %08h  exp %08h", WriteData, exp_WD);
            if (LoadData !== 32'h0)
                $display("  LoadData:   got %08h  exp 00000000 (store, should be 0)", LoadData);
        end
    endtask

    task automatic check_load(
        input logic [1:0]  t_MemRW,
        input logic [2:0]  t_Funct3,
        input logic [1:0]  t_AddrLSB,
        input logic [31:0] t_ReadData,
        input logic [31:0] exp_LD,
        input string       label
    );
        MemRW     = t_MemRW;
        Funct3    = t_Funct3;
        AddrLSB   = t_AddrLSB;
        StoreData = 32'h0;
        ReadData  = t_ReadData;
        #1;
        tests_total = tests_total + 1;
        if ((LoadData === exp_LD) && (ByteEnable === 4'h0) && (WriteData === 32'h0)) begin
            tests_passed = tests_passed + 1;
        end else begin
            tests_errors = tests_errors + 1;
            $display("MISMATCH [%s]", label);
            if (LoadData !== exp_LD)
                $display("  LoadData:   got %08h  exp %08h", LoadData, exp_LD);
            if (ByteEnable !== 4'h0)
                $display("  ByteEnable: got %04b  exp 0000 (load, should be 0)", ByteEnable);
            if (WriteData !== 32'h0)
                $display("  WriteData:  got %08h  exp 00000000 (load, should be 0)", WriteData);
        end
    endtask

    task automatic check_idle(
        input logic [1:0]  t_MemRW,
        input logic [2:0]  t_Funct3,
        input logic [1:0]  t_AddrLSB,
        input logic [31:0] t_StoreData,
        input logic [31:0] t_ReadData,
        input string       label
    );
        MemRW     = t_MemRW;
        Funct3    = t_Funct3;
        AddrLSB   = t_AddrLSB;
        StoreData = t_StoreData;
        ReadData  = t_ReadData;
        #1;
        tests_total = tests_total + 1;
        if ((ByteEnable === 4'h0) && (WriteData === 32'h0) && (LoadData === 32'h0)) begin
            tests_passed = tests_passed + 1;
        end else begin
            tests_errors = tests_errors + 1;
            $display("MISMATCH [%s]", label);
            if (ByteEnable !== 4'h0)
                $display("  ByteEnable: got %04b  exp 0000", ByteEnable);
            if (WriteData !== 32'h0)
                $display("  WriteData:  got %08h  exp 00000000", WriteData);
            if (LoadData !== 32'h0)
                $display("  LoadData:   got %08h  exp 00000000", LoadData);
        end
    endtask

    // -----------------------------------------------------------------------
    // Reference functions – pure combinational gold model
    // -----------------------------------------------------------------------

    // Compute expected ByteEnable for a store
    function automatic logic [3:0] ref_be(
        input logic [2:0] f3,
        input logic [1:0] lsb
    );
        case (f3)
            3'b000: begin   // SB
                case (lsb)
                    2'b00: ref_be = 4'b0001;
                    2'b01: ref_be = 4'b0010;
                    2'b10: ref_be = 4'b0100;
                    default: ref_be = 4'b1000;
                endcase
            end
            3'b001: begin   // SH
                ref_be = (lsb[1] == 1'b0) ? 4'b0011 : 4'b1100;
            end
            3'b010: ref_be = 4'b1111;   // SW
            default: ref_be = 4'b0000;
        endcase
    endfunction

    // Compute expected WriteData for a store
    function automatic logic [31:0] ref_wd(
        input logic [2:0]  f3,
        input logic [1:0]  lsb,
        input logic [31:0] sd
    );
        logic [7:0]  b0;
        logic [15:0] h0;
        b0 = sd[7:0];
        h0 = sd[15:0];
        case (f3)
            3'b000: begin   // SB
                case (lsb)
                    2'b00: ref_wd = {24'h0,  b0        };
                    2'b01: ref_wd = {16'h0,  b0,  8'h0};
                    2'b10: ref_wd = { 8'h0,  b0, 16'h0};
                    default: ref_wd = {       b0, 24'h0};
                endcase
            end
            3'b001: begin   // SH
                ref_wd = (lsb[1] == 1'b0) ? {16'h0, h0} : {h0, 16'h0};
            end
            3'b010: ref_wd = sd;    // SW
            default: ref_wd = 32'h0;
        endcase
    endfunction

    // Compute expected LoadData for a load
    function automatic logic [31:0] ref_ld(
        input logic [2:0]  f3,
        input logic [1:0]  lsb,
        input logic [31:0] rd
    );
        logic [7:0]  sel_b;
        logic [15:0] sel_h;
        case (lsb)
            2'b00: sel_b = rd[ 7: 0];
            2'b01: sel_b = rd[15: 8];
            2'b10: sel_b = rd[23:16];
            default: sel_b = rd[31:24];
        endcase
        sel_h = (lsb[1] == 1'b0) ? rd[15:0] : rd[31:16];

        case (f3)
            3'b000: ref_ld = {{24{sel_b[7]}},  sel_b};  // LB
            3'b001: ref_ld = {{16{sel_h[15]}}, sel_h};  // LH
            3'b010: ref_ld = rd;                         // LW
            3'b100: ref_ld = {24'h0, sel_b};             // LBU
            3'b101: ref_ld = {16'h0, sel_h};             // LHU
            default: ref_ld = 32'h0;
        endcase
    endfunction

    // -----------------------------------------------------------------------
    // Test stimulus
    // -----------------------------------------------------------------------
    initial begin
        tests_passed = 0;
        tests_errors = 0;
        tests_total  = 0;

        // ===================================================================
        // Section 1: DEFAULT / IDLE behavior
        // ===================================================================
        $display("--- Section 1: Defaults (MemRW=00 and MemRW=11) ---");

        // MemRW=00 with various Funct3 and address
        check_idle(2'b00, 3'b000, 2'b00, 32'hDEADBEEF, 32'hCAFEBABE, "IDLE_00_f0_lsb0");
        check_idle(2'b00, 3'b001, 2'b01, 32'hDEADBEEF, 32'hCAFEBABE, "IDLE_00_f1_lsb1");
        check_idle(2'b00, 3'b010, 2'b10, 32'hDEADBEEF, 32'hCAFEBABE, "IDLE_00_f2_lsb2");
        check_idle(2'b00, 3'b100, 2'b11, 32'hFFFFFFFF, 32'hFFFFFFFF, "IDLE_00_f4_lsb3_allones");
        // MemRW=11 unused encoding
        check_idle(2'b11, 3'b000, 2'b00, 32'hDEADBEEF, 32'hCAFEBABE, "IDLE_11_f0_lsb0");
        check_idle(2'b11, 3'b010, 2'b00, 32'hFFFFFFFF, 32'h12345678, "IDLE_11_f2_lsb0");
        check_idle(2'b11, 3'b101, 2'b10, 32'hA5A5A5A5, 32'h5A5A5A5A, "IDLE_11_f5_lsb2");

        // ===================================================================
        // Section 2: STORE SB – all 4 byte offsets, varied patterns
        // ===================================================================
        $display("--- Section 2: SB (Funct3=000) stores ---");

        // Nominal byte offsets with 0xAB
        check_store(2'b01, 3'b000, 2'b00, 32'hAB, 4'b0001, 32'h000000AB, "SB_lsb0_0xAB");
        check_store(2'b01, 3'b000, 2'b01, 32'hAB, 4'b0010, 32'h0000AB00, "SB_lsb1_0xAB");
        check_store(2'b01, 3'b000, 2'b10, 32'hAB, 4'b0100, 32'h00AB0000, "SB_lsb2_0xAB");
        check_store(2'b01, 3'b000, 2'b11, 32'hAB, 4'b1000, 32'hAB000000, "SB_lsb3_0xAB");

        // All-zeros store data
        check_store(2'b01, 3'b000, 2'b00, 32'h0, 4'b0001, 32'h00000000, "SB_lsb0_zero");
        check_store(2'b01, 3'b000, 2'b11, 32'h0, 4'b1000, 32'h00000000, "SB_lsb3_zero");

        // All-ones byte (only LSB matters: 0xFF)
        check_store(2'b01, 3'b000, 2'b00, 32'hFFFFFFFF, 4'b0001, 32'h000000FF, "SB_lsb0_allones");
        check_store(2'b01, 3'b000, 2'b01, 32'hFFFFFFFF, 4'b0010, 32'h0000FF00, "SB_lsb1_allones");
        check_store(2'b01, 3'b000, 2'b10, 32'hFFFFFFFF, 4'b0100, 32'h00FF0000, "SB_lsb2_allones");
        check_store(2'b01, 3'b000, 2'b11, 32'hFFFFFFFF, 4'b1000, 32'hFF000000, "SB_lsb3_allones");

        // Alternating bit pattern
        check_store(2'b01, 3'b000, 2'b00, 32'hA5A5A5A5, 4'b0001, 32'h000000A5, "SB_lsb0_A5A5");
        check_store(2'b01, 3'b000, 2'b10, 32'h5A5A5A5A, 4'b0100, 32'h005A0000, "SB_lsb2_5A5A");

        // ===================================================================
        // Section 3: STORE SH – both halfword offsets, varied patterns
        // ===================================================================
        $display("--- Section 3: SH (Funct3=001) stores ---");

        // Nominal with 0x1234
        check_store(2'b01, 3'b001, 2'b00, 32'h00001234, 4'b0011, 32'h00001234, "SH_lsb0_0x1234");
        check_store(2'b01, 3'b001, 2'b10, 32'h00001234, 4'b1100, 32'h12340000, "SH_lsb2_0x1234");
        // AddrLSB=01 → still selects lower halfword (bit1=0)
        check_store(2'b01, 3'b001, 2'b01, 32'h0000ABCD, 4'b0011, 32'h0000ABCD, "SH_lsb1_0xABCD");
        // AddrLSB=11 → selects upper halfword (bit1=1)
        check_store(2'b01, 3'b001, 2'b11, 32'h0000ABCD, 4'b1100, 32'hABCD0000, "SH_lsb3_0xABCD");

        // All-ones halfword
        check_store(2'b01, 3'b001, 2'b00, 32'hFFFFFFFF, 4'b0011, 32'h0000FFFF, "SH_lsb0_allones");
        check_store(2'b01, 3'b001, 2'b10, 32'hFFFFFFFF, 4'b1100, 32'hFFFF0000, "SH_lsb2_allones");

        // Zero halfword
        check_store(2'b01, 3'b001, 2'b00, 32'h0, 4'b0011, 32'h00000000, "SH_lsb0_zero");
        check_store(2'b01, 3'b001, 2'b10, 32'h0, 4'b1100, 32'h00000000, "SH_lsb2_zero");

        // ===================================================================
        // Section 4: STORE SW – full word
        // ===================================================================
        $display("--- Section 4: SW (Funct3=010) stores ---");

        check_store(2'b01, 3'b010, 2'b00, 32'hDEADBEEF, 4'b1111, 32'hDEADBEEF, "SW_0xDEADBEEF");
        check_store(2'b01, 3'b010, 2'b00, 32'h00000000, 4'b1111, 32'h00000000, "SW_zero");
        check_store(2'b01, 3'b010, 2'b00, 32'hFFFFFFFF, 4'b1111, 32'hFFFFFFFF, "SW_allones");
        check_store(2'b01, 3'b010, 2'b00, 32'hA5A5A5A5, 4'b1111, 32'hA5A5A5A5, "SW_A5A5A5A5");
        check_store(2'b01, 3'b010, 2'b00, 32'h12345678, 4'b1111, 32'h12345678, "SW_12345678");

        // ===================================================================
        // Section 5: LOAD LB – sign extension, all 4 byte offsets
        // ===================================================================
        $display("--- Section 5: LB (Funct3=000) loads ---");

        // Positive byte (bit7=0): zero upper 24
        check_load(2'b10, 3'b000, 2'b00, 32'h00000042, 32'h00000042, "LB_lsb0_pos");
        check_load(2'b10, 3'b000, 2'b01, 32'h00004200, 32'h00000042, "LB_lsb1_pos");
        check_load(2'b10, 3'b000, 2'b10, 32'h00420000, 32'h00000042, "LB_lsb2_pos");
        check_load(2'b10, 3'b000, 2'b11, 32'h42000000, 32'h00000042, "LB_lsb3_pos");

        // Negative byte (bit7=1): sign-extend to 0xFFFFFFxx
        check_load(2'b10, 3'b000, 2'b00, 32'h000000FF, 32'hFFFFFFFF, "LB_lsb0_0xFF");
        check_load(2'b10, 3'b000, 2'b01, 32'h0000FF00, 32'hFFFFFFFF, "LB_lsb1_0xFF");
        check_load(2'b10, 3'b000, 2'b10, 32'h00FF0000, 32'hFFFFFFFF, "LB_lsb2_0xFF");
        check_load(2'b10, 3'b000, 2'b11, 32'hFF000000, 32'hFFFFFFFF, "LB_lsb3_0xFF");

        check_load(2'b10, 3'b000, 2'b00, 32'h00000080, 32'hFFFFFF80, "LB_lsb0_0x80_neg");
        check_load(2'b10, 3'b000, 2'b01, 32'h00008000, 32'hFFFFFF80, "LB_lsb1_0x80_neg");
        check_load(2'b10, 3'b000, 2'b10, 32'h00800000, 32'hFFFFFF80, "LB_lsb2_0x80_neg");
        check_load(2'b10, 3'b000, 2'b11, 32'h80000000, 32'hFFFFFF80, "LB_lsb3_0x80_neg");

        // Zero byte
        check_load(2'b10, 3'b000, 2'b00, 32'hFFFFFF00, 32'h00000000, "LB_lsb0_zero");
        check_load(2'b10, 3'b000, 2'b11, 32'h00FFFFFF, 32'h00000000, "LB_lsb3_zero");

        // ===================================================================
        // Section 6: LOAD LBU – zero extension
        // ===================================================================
        $display("--- Section 6: LBU (Funct3=100) loads ---");

        check_load(2'b10, 3'b100, 2'b00, 32'h000000FF, 32'h000000FF, "LBU_lsb0_0xFF");
        check_load(2'b10, 3'b100, 2'b01, 32'h0000FF00, 32'h000000FF, "LBU_lsb1_0xFF");
        check_load(2'b10, 3'b100, 2'b10, 32'h00FF0000, 32'h000000FF, "LBU_lsb2_0xFF");
        check_load(2'b10, 3'b100, 2'b11, 32'hFF000000, 32'h000000FF, "LBU_lsb3_0xFF");

        check_load(2'b10, 3'b100, 2'b00, 32'h00000080, 32'h00000080, "LBU_lsb0_0x80");
        check_load(2'b10, 3'b100, 2'b01, 32'h00008000, 32'h00000080, "LBU_lsb1_0x80");
        check_load(2'b10, 3'b100, 2'b10, 32'h00800000, 32'h00000080, "LBU_lsb2_0x80");
        check_load(2'b10, 3'b100, 2'b11, 32'h80000000, 32'h00000080, "LBU_lsb3_0x80");

        check_load(2'b10, 3'b100, 2'b00, 32'hA5B6C7D8, 32'h000000D8, "LBU_lsb0_A5B6C7D8");
        check_load(2'b10, 3'b100, 2'b01, 32'hA5B6C7D8, 32'h000000C7, "LBU_lsb1_A5B6C7D8");
        check_load(2'b10, 3'b100, 2'b10, 32'hA5B6C7D8, 32'h000000B6, "LBU_lsb2_A5B6C7D8");
        check_load(2'b10, 3'b100, 2'b11, 32'hA5B6C7D8, 32'h000000A5, "LBU_lsb3_A5B6C7D8");

        // ===================================================================
        // Section 7: LOAD LH – sign extension, both halfword offsets
        // ===================================================================
        $display("--- Section 7: LH (Funct3=001) loads ---");

        // Positive halfword
        check_load(2'b10, 3'b001, 2'b00, 32'h00007FFF, 32'h00007FFF, "LH_lsb0_pos");
        check_load(2'b10, 3'b001, 2'b10, 32'h7FFF0000, 32'h00007FFF, "LH_lsb2_pos");

        // Negative halfword (bit15=1)
        check_load(2'b10, 3'b001, 2'b00, 32'h0000FFFF, 32'hFFFFFFFF, "LH_lsb0_0xFFFF");
        check_load(2'b10, 3'b001, 2'b10, 32'hFFFF0000, 32'hFFFFFFFF, "LH_lsb2_0xFFFF");

        check_load(2'b10, 3'b001, 2'b00, 32'h00008000, 32'hFFFF8000, "LH_lsb0_0x8000_neg");
        check_load(2'b10, 3'b001, 2'b10, 32'h80000000, 32'hFFFF8000, "LH_lsb2_0x8000_neg");

        // Zero halfword
        check_load(2'b10, 3'b001, 2'b00, 32'hFFFF0000, 32'h00000000, "LH_lsb0_zero");
        check_load(2'b10, 3'b001, 2'b10, 32'h0000FFFF, 32'h00000000, "LH_lsb2_zero");

        // AddrLSB=01 / 11 (same selection as 00 / 10 via bit1)
        check_load(2'b10, 3'b001, 2'b01, 32'h0000ABCD, 32'hFFFFABCD, "LH_lsb1_0xABCD_neg");
        check_load(2'b10, 3'b001, 2'b11, 32'hABCD0000, 32'hFFFFABCD, "LH_lsb3_0xABCD_neg");

        // ===================================================================
        // Section 8: LOAD LHU – zero extension
        // ===================================================================
        $display("--- Section 8: LHU (Funct3=101) loads ---");

        check_load(2'b10, 3'b101, 2'b00, 32'h0000FFFF, 32'h0000FFFF, "LHU_lsb0_0xFFFF");
        check_load(2'b10, 3'b101, 2'b10, 32'hFFFF0000, 32'h0000FFFF, "LHU_lsb2_0xFFFF");

        check_load(2'b10, 3'b101, 2'b00, 32'h00008000, 32'h00008000, "LHU_lsb0_0x8000");
        check_load(2'b10, 3'b101, 2'b10, 32'h80000000, 32'h00008000, "LHU_lsb2_0x8000");

        check_load(2'b10, 3'b101, 2'b00, 32'hBEEFDEAD, 32'h0000DEAD, "LHU_lsb0_0xBEEFDEAD");
        check_load(2'b10, 3'b101, 2'b10, 32'hBEEFDEAD, 32'h0000BEEF, "LHU_lsb2_0xBEEFDEAD");

        check_load(2'b10, 3'b101, 2'b01, 32'h00001234, 32'h00001234, "LHU_lsb1_0x1234");
        check_load(2'b10, 3'b101, 2'b11, 32'h12340000, 32'h00001234, "LHU_lsb3_0x1234");

        // ===================================================================
        // Section 9: LOAD LW – full word pass-through
        // ===================================================================
        $display("--- Section 9: LW (Funct3=010) loads ---");

        check_load(2'b10, 3'b010, 2'b00, 32'hDEADBEEF, 32'hDEADBEEF, "LW_DEADBEEF");
        check_load(2'b10, 3'b010, 2'b00, 32'h00000000, 32'h00000000, "LW_zero");
        check_load(2'b10, 3'b010, 2'b00, 32'hFFFFFFFF, 32'hFFFFFFFF, "LW_allones");
        check_load(2'b10, 3'b010, 2'b00, 32'hA5A5A5A5, 32'hA5A5A5A5, "LW_A5A5A5A5");
        check_load(2'b10, 3'b010, 2'b00, 32'h5A5A5A5A, 32'h5A5A5A5A, "LW_5A5A5A5A");

        // ===================================================================
        // Section 10: Exhaustive sweep – store then load same data
        //             (verify separation of store/load paths)
        // ===================================================================
        $display("--- Section 10: Store/Load path independence sweep ---");
        begin
            logic [31:0] sweep_data [0:3];
            logic [1:0]  sweep_lsb  [0:3];
            logic [2:0]  store_f3   [0:2];
            logic [2:0]  load_f3    [0:4];
            integer i, j, k;

            sweep_data[0] = 32'hDEADBEEF;
            sweep_data[1] = 32'h12345678;
            sweep_data[2] = 32'hA5A5A5A5;
            sweep_data[3] = 32'h00000000;

            sweep_lsb[0] = 2'b00;
            sweep_lsb[1] = 2'b01;
            sweep_lsb[2] = 2'b10;
            sweep_lsb[3] = 2'b11;

            store_f3[0] = 3'b000;  // SB
            store_f3[1] = 3'b001;  // SH
            store_f3[2] = 3'b010;  // SW

            load_f3[0] = 3'b000;   // LB
            load_f3[1] = 3'b001;   // LH
            load_f3[2] = 3'b010;   // LW
            load_f3[3] = 3'b100;   // LBU
            load_f3[4] = 3'b101;   // LHU

            for (i = 0; i < 4; i++) begin
                for (j = 0; j < 3; j++) begin
                    // Store check using reference function
                    check_store(2'b01, store_f3[j], sweep_lsb[i], sweep_data[i],
                                ref_be(store_f3[j], sweep_lsb[i]),
                                ref_wd(store_f3[j], sweep_lsb[i], sweep_data[i]),
                                "SWEEP_STORE");
                end
                for (k = 0; k < 5; k++) begin
                    // Load check using reference function
                    check_load(2'b10, load_f3[k], sweep_lsb[i], sweep_data[i],
                               ref_ld(load_f3[k], sweep_lsb[i], sweep_data[i]),
                               "SWEEP_LOAD");
                end
            end
        end

        // ===================================================================
        // Section 11: Unsupported Funct3 for store → defaults
        // ===================================================================
        $display("--- Section 11: Unsupported Funct3 store defaults ---");

        check_store(2'b01, 3'b011, 2'b00, 32'hDEAD, 4'b0000, 32'h00000000, "STORE_f3_011_default");
        check_store(2'b01, 3'b100, 2'b00, 32'hDEAD, 4'b0000, 32'h00000000, "STORE_f3_100_default");
        check_store(2'b01, 3'b101, 2'b00, 32'hDEAD, 4'b0000, 32'h00000000, "STORE_f3_101_default");
        check_store(2'b01, 3'b110, 2'b00, 32'hDEAD, 4'b0000, 32'h00000000, "STORE_f3_110_default");
        check_store(2'b01, 3'b111, 2'b00, 32'hDEAD, 4'b0000, 32'h00000000, "STORE_f3_111_default");

        // ===================================================================
        // Section 12: Unsupported Funct3 for load → LoadData=0
        // ===================================================================
        $display("--- Section 12: Unsupported Funct3 load defaults ---");

        check_load(2'b10, 3'b011, 2'b00, 32'hDEADBEEF, 32'h00000000, "LOAD_f3_011_default");
        check_load(2'b10, 3'b110, 2'b00, 32'hDEADBEEF, 32'h00000000, "LOAD_f3_110_default");
        check_load(2'b10, 3'b111, 2'b00, 32'hDEADBEEF, 32'h00000000, "LOAD_f3_111_default");

        // ===================================================================
        // Section 13: Targeted gap closures
        //
        //  13a  LHU with high-bit-set halfword at AddrLSB=01 / 11:
        //       confirms zero-extension (not sign-extension) for the
        //       non-canonical offset paths that share the sel_half mux.
        //
        //  13b  LW passthrough with non-zero AddrLSB:
        //       RTL assigns LoadData = ReadData unconditionally; spec scopes
        //       word accesses to offset 0 but RTL must not corrupt the word.
        //
        //  13c  SW independence from AddrLSB:
        //       RTL ignores AddrLSB[1:0] for SW; ByteEnable must stay 1111
        //       and WriteData must equal StoreData at any offset encoding.
        //
        //  13d  LB max-positive boundary (0x7F):
        //       Confirms sign-bit = 0 → upper 24 bits zeroed (no sign fill).
        //
        //  13e  LBU minimum non-zero byte (0x01):
        //       Confirms zero-extension at the low end of the range.
        //
        //  13f  LH near-boundary halfword (0x8001):
        //       One step above 0x8000; sign-extension must fill upper 16.
        // ===================================================================
        $display("--- Section 13: Targeted gap closures ---");

        // 13a – LHU high-bit halfword via lsb=01 (AddrLSB[1]=0 path)
        check_load(2'b10, 3'b101, 2'b01, 32'h00008000, 32'h00008000, "LHU_lsb1_0x8000_zero");
        check_load(2'b10, 3'b101, 2'b01, 32'h0000ABCD, 32'h0000ABCD, "LHU_lsb1_0xABCD_zero");
        // 13a – LHU high-bit halfword via lsb=11 (AddrLSB[1]=1 path)
        check_load(2'b10, 3'b101, 2'b11, 32'h80000000, 32'h00008000, "LHU_lsb3_0x8000_zero");
        check_load(2'b10, 3'b101, 2'b11, 32'hABCD0000, 32'h0000ABCD, "LHU_lsb3_0xABCD_zero");

        // 13b – LW passthrough at non-zero AddrLSB
        check_load(2'b10, 3'b010, 2'b01, 32'h12345678, 32'h12345678, "LW_lsb1_passthru");
        check_load(2'b10, 3'b010, 2'b10, 32'hDEADBEEF, 32'hDEADBEEF, "LW_lsb2_passthru");
        check_load(2'b10, 3'b010, 2'b11, 32'hCAFEBABE, 32'hCAFEBABE, "LW_lsb3_passthru");

        // 13c – SW ByteEnable=1111 and WriteData=StoreData regardless of AddrLSB
        check_store(2'b01, 3'b010, 2'b01, 32'hDEADBEEF, 4'b1111, 32'hDEADBEEF, "SW_lsb1_BE_full");
        check_store(2'b01, 3'b010, 2'b10, 32'hA5A5A5A5, 4'b1111, 32'hA5A5A5A5, "SW_lsb2_BE_full");
        check_store(2'b01, 3'b010, 2'b11, 32'h5A5A5A5A, 4'b1111, 32'h5A5A5A5A, "SW_lsb3_BE_full");

        // 13d – LB max-positive byte 0x7F at all four byte lanes
        check_load(2'b10, 3'b000, 2'b00, 32'h0000007F, 32'h0000007F, "LB_lsb0_0x7F_maxpos");
        check_load(2'b10, 3'b000, 2'b01, 32'h00007F00, 32'h0000007F, "LB_lsb1_0x7F_maxpos");
        check_load(2'b10, 3'b000, 2'b10, 32'h007F0000, 32'h0000007F, "LB_lsb2_0x7F_maxpos");
        check_load(2'b10, 3'b000, 2'b11, 32'h7F000000, 32'h0000007F, "LB_lsb3_0x7F_maxpos");

        // 13e – LBU minimum non-zero byte 0x01 at byte offsets 0 and 3
        check_load(2'b10, 3'b100, 2'b00, 32'h00000001, 32'h00000001, "LBU_lsb0_0x01");
        check_load(2'b10, 3'b100, 2'b11, 32'h01000000, 32'h00000001, "LBU_lsb3_0x01");

        // 13f – LH near-boundary halfword 0x8001 at both halfword offsets
        check_load(2'b10, 3'b001, 2'b00, 32'h00008001, 32'hFFFF8001, "LH_lsb0_0x8001_neg");
        check_load(2'b10, 3'b001, 2'b10, 32'h80010000, 32'hFFFF8001, "LH_lsb2_0x8001_neg");

        // ===================================================================
        // Final summary
        // ===================================================================
        $display("---");
        $display("TESTS_PASSED %0d", tests_passed);
        $display("TESTS_ERRORS %0d", tests_errors);
        $display("TESTS_TOTAL  %0d", tests_total);

        if (tests_errors == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");

        $finish;
    end

endmodule
