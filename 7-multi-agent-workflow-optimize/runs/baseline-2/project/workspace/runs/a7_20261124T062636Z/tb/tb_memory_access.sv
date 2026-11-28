// tb_memory_access.sv
// Self-checking testbench for the memory_access module.
// Compatible with Icarus Verilog 12 (no SystemVerilog-only constructs that
// iverilog-12 rejects).  Pure combinational DUT → no clock required.
//
// Summary lines (required by AGENTS.md §Rule 7):
//   TESTS_PASSED : <n>
//   TESTS_ERRORS : <n>
//   TESTS_TOTAL  : <n>
//   RESULT: PASS | RESULT: FAIL

`timescale 1ns/1ps

module tb_memory_access;

    // ------------------------------------------------------------------ //
    //  DUT ports
    // ------------------------------------------------------------------ //
    logic [1:0]  MemRW;
    logic [2:0]  Funct3;
    logic [1:0]  AddrLSB;
    logic [31:0] StoreData;
    logic [31:0] ReadData;
    logic [31:0] WriteData;
    logic [3:0]  ByteEnable;
    logic [31:0] LoadData;

    // ------------------------------------------------------------------ //
    //  DUT instantiation
    // ------------------------------------------------------------------ //
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

    // ------------------------------------------------------------------ //
    //  Scoreboard counters
    // ------------------------------------------------------------------ //
    integer tests_passed;
    integer tests_errors;
    integer tests_total;

    // ------------------------------------------------------------------ //
    //  Reference / expected value helpers
    // ------------------------------------------------------------------ //

    // ---- store helpers ----
    function automatic [3:0] exp_be (
        input [1:0] rw,
        input [2:0] f3,
        input [1:0] lsb
    );
        if (rw != 2'b01) begin
            exp_be = 4'b0000;
        end else begin
            case (f3)
                3'b000: // SB
                    case (lsb)
                        2'b00:   exp_be = 4'b0001;
                        2'b01:   exp_be = 4'b0010;
                        2'b10:   exp_be = 4'b0100;
                        default: exp_be = 4'b1000;
                    endcase
                3'b001: // SH
                    exp_be = lsb[1] ? 4'b1100 : 4'b0011;
                3'b010: // SW
                    exp_be = 4'b1111;
                default:
                    exp_be = 4'b0000;
            endcase
        end
    endfunction

    function automatic [31:0] exp_wd (
        input [1:0]  rw,
        input [2:0]  f3,
        input [1:0]  lsb,
        input [31:0] sd
    );
        if (rw != 2'b01) begin
            exp_wd = 32'b0;
        end else begin
            case (f3)
                3'b000: // SB
                    case (lsb)
                        2'b00:   exp_wd = {24'b0,       sd[7:0]        };
                        2'b01:   exp_wd = {16'b0,       sd[7:0], 8'b0  };
                        2'b10:   exp_wd = { 8'b0,       sd[7:0], 16'b0 };
                        default: exp_wd = {              sd[7:0], 24'b0 };
                    endcase
                3'b001: // SH
                    exp_wd = lsb[1] ? {sd[15:0], 16'b0} : {16'b0, sd[15:0]};
                3'b010: // SW
                    exp_wd = sd;
                default:
                    exp_wd = 32'b0;
            endcase
        end
    endfunction

    // ---- load helpers ----
    function automatic [31:0] exp_ld (
        input [1:0]  rw,
        input [2:0]  f3,
        input [1:0]  lsb,
        input [31:0] rd
    );
        logic [7:0]  byt;
        logic [15:0] half;
        if (rw != 2'b10) begin
            exp_ld = 32'b0;
        end else begin
            // byte/half selection
            case (lsb)
                2'b00:   byt = rd[7:0];
                2'b01:   byt = rd[15:8];
                2'b10:   byt = rd[23:16];
                default: byt = rd[31:24];
            endcase
            half = lsb[1] ? rd[31:16] : rd[15:0];

            case (f3)
                3'b000: exp_ld = {{24{byt[7]}},  byt};   // LB
                3'b001: exp_ld = {{16{half[15]}}, half};  // LH
                3'b010: exp_ld = rd;                       // LW
                3'b100: exp_ld = {24'b0, byt};             // LBU
                3'b101: exp_ld = {16'b0, half};            // LHU
                default: exp_ld = 32'b0;
            endcase
        end
    endfunction

    // ------------------------------------------------------------------ //
    //  Check task
    // ------------------------------------------------------------------ //
    task automatic check_outputs (
        input string         label,
        input [3:0]          exp_be_v,
        input [31:0]         exp_wd_v,
        input [31:0]         exp_ld_v
    );
        logic ok;
        ok = 1'b1;

        tests_total = tests_total + 1;

        if (ByteEnable !== exp_be_v) begin
            $display("MISMATCH [%s] ByteEnable: got 4'b%b  exp 4'b%b  (MemRW=%b Funct3=%b AddrLSB=%b StoreData=%h ReadData=%h)",
                     label, ByteEnable, exp_be_v, MemRW, Funct3, AddrLSB, StoreData, ReadData);
            ok = 1'b0;
        end
        if (WriteData !== exp_wd_v) begin
            $display("MISMATCH [%s] WriteData:  got %h  exp %h  (MemRW=%b Funct3=%b AddrLSB=%b StoreData=%h)",
                     label, WriteData, exp_wd_v, MemRW, Funct3, AddrLSB, StoreData);
            ok = 1'b0;
        end
        if (LoadData !== exp_ld_v) begin
            $display("MISMATCH [%s] LoadData:   got %h  exp %h  (MemRW=%b Funct3=%b AddrLSB=%b ReadData=%h)",
                     label, LoadData, exp_ld_v, MemRW, Funct3, AddrLSB, ReadData);
            ok = 1'b0;
        end

        if (ok) begin
            tests_passed = tests_passed + 1;
        end else begin
            tests_errors = tests_errors + 1;
        end
    endtask

    // ------------------------------------------------------------------ //
    //  Apply-and-check convenience task
    // ------------------------------------------------------------------ //
    task automatic apply_and_check (
        input string         label,
        input [1:0]          rw,
        input [2:0]          f3,
        input [1:0]          lsb,
        input [31:0]         sd,
        input [31:0]         rd
    );
        MemRW     = rw;
        Funct3    = f3;
        AddrLSB   = lsb;
        StoreData = sd;
        ReadData  = rd;
        #1; // allow combinational settle

        check_outputs(label,
                      exp_be(rw, f3, lsb),
                      exp_wd(rw, f3, lsb, sd),
                      exp_ld(rw, f3, lsb, rd));
    endtask

    // ------------------------------------------------------------------ //
    //  Test stimulus
    // ------------------------------------------------------------------ //
    initial begin
        tests_passed = 0;
        tests_errors = 0;
        tests_total  = 0;

        // ============================================================
        // GROUP 1 – Inactive / no-access  (MemRW = 2'b00)
        //   Expect: ByteEnable=0, WriteData=0, LoadData=0
        // ============================================================
        apply_and_check("INACTIVE_00_A", 2'b00, 3'b000, 2'b00, 32'hDEAD_BEEF, 32'hCAFE_BABE);
        apply_and_check("INACTIVE_00_B", 2'b00, 3'b001, 2'b01, 32'hFFFF_FFFF, 32'hFFFF_FFFF);
        apply_and_check("INACTIVE_00_C", 2'b00, 3'b010, 2'b10, 32'h1234_5678, 32'h8765_4321);

        // ============================================================
        // GROUP 2 – Unused MemRW = 2'b11
        //   Expect: ByteEnable=0, WriteData=0, LoadData=0
        // ============================================================
        apply_and_check("UNUSED_11_A",   2'b11, 3'b000, 2'b00, 32'hDEAD_BEEF, 32'hCAFE_BABE);
        apply_and_check("UNUSED_11_B",   2'b11, 3'b010, 2'b00, 32'hFFFF_FFFF, 32'hFFFF_FFFF);

        // ============================================================
        // GROUP 3 – SB (Funct3=000, MemRW=01) all four byte offsets
        // ============================================================
        // offset 0 – byte placed in [7:0]
        apply_and_check("SB_OFF0_A", 2'b01, 3'b000, 2'b00, 32'hABCD_EF12, 32'h0);
        apply_and_check("SB_OFF0_B", 2'b01, 3'b000, 2'b00, 32'h0000_00FF, 32'h0);  // max byte
        apply_and_check("SB_OFF0_C", 2'b01, 3'b000, 2'b00, 32'h0000_0000, 32'h0);  // zero byte
        // offset 1 – byte placed in [15:8]
        apply_and_check("SB_OFF1_A", 2'b01, 3'b000, 2'b01, 32'hABCD_EF12, 32'h0);
        apply_and_check("SB_OFF1_B", 2'b01, 3'b000, 2'b01, 32'h0000_0080, 32'h0);  // sign-bit byte
        // offset 2 – byte placed in [23:16]
        apply_and_check("SB_OFF2_A", 2'b01, 3'b000, 2'b10, 32'hABCD_EF12, 32'h0);
        apply_and_check("SB_OFF2_B", 2'b01, 3'b000, 2'b10, 32'hFFFF_FF55, 32'h0);
        // offset 3 – byte placed in [31:24]
        apply_and_check("SB_OFF3_A", 2'b01, 3'b000, 2'b11, 32'hABCD_EF12, 32'h0);
        apply_and_check("SB_OFF3_B", 2'b01, 3'b000, 2'b11, 32'h0000_00AA, 32'h0);

        // ============================================================
        // GROUP 4 – SH (Funct3=001, MemRW=01) aligned offsets 0 and 2
        // ============================================================
        apply_and_check("SH_OFF0_A", 2'b01, 3'b001, 2'b00, 32'hABCD_1234, 32'h0);
        apply_and_check("SH_OFF0_B", 2'b01, 3'b001, 2'b00, 32'h0000_FFFF, 32'h0);  // max half
        apply_and_check("SH_OFF0_C", 2'b01, 3'b001, 2'b00, 32'h0000_0000, 32'h0);  // zero
        apply_and_check("SH_OFF0_D", 2'b01, 3'b001, 2'b01, 32'hABCD_1234, 32'h0);  // lsb=01 → same as 00 (lsb[1]=0)

        apply_and_check("SH_OFF2_A", 2'b01, 3'b001, 2'b10, 32'hABCD_1234, 32'h0);
        apply_and_check("SH_OFF2_B", 2'b01, 3'b001, 2'b10, 32'hFFFF_8000, 32'h0);  // sign half
        apply_and_check("SH_OFF2_C", 2'b01, 3'b001, 2'b11, 32'hABCD_BEEF, 32'h0);  // lsb=11 → same as 10 (lsb[1]=1)

        // ============================================================
        // GROUP 5 – SW (Funct3=010, MemRW=01)
        // ============================================================
        apply_and_check("SW_A",      2'b01, 3'b010, 2'b00, 32'hDEAD_BEEF, 32'h0);
        apply_and_check("SW_B",      2'b01, 3'b010, 2'b00, 32'h0000_0000, 32'h0);  // zero word
        apply_and_check("SW_C",      2'b01, 3'b010, 2'b00, 32'hFFFF_FFFF, 32'h0);  // all ones
        apply_and_check("SW_D",      2'b01, 3'b010, 2'b00, 32'h8000_0000, 32'h0);  // sign word

        // ============================================================
        // GROUP 6 – Undefined Funct3 for stores → expect defaults (0)
        // ============================================================
        apply_and_check("ST_UNK_F3A",2'b01, 3'b011, 2'b00, 32'hDEAD_BEEF, 32'h0);
        apply_and_check("ST_UNK_F3B",2'b01, 3'b100, 2'b00, 32'hDEAD_BEEF, 32'h0);
        apply_and_check("ST_UNK_F3C",2'b01, 3'b101, 2'b00, 32'hDEAD_BEEF, 32'h0);
        apply_and_check("ST_UNK_F3D",2'b01, 3'b110, 2'b00, 32'hDEAD_BEEF, 32'h0);
        apply_and_check("ST_UNK_F3E",2'b01, 3'b111, 2'b00, 32'hDEAD_BEEF, 32'h0);

        // ============================================================
        // GROUP 7 – LB (Funct3=000, MemRW=10) sign-extend byte
        // ============================================================
        // positive byte (bit 7 = 0) → zero-padded upper 24
        apply_and_check("LB_OFF0_POS", 2'b10, 3'b000, 2'b00, 32'h0, 32'hABCD_EF7F);
        apply_and_check("LB_OFF1_POS", 2'b10, 3'b000, 2'b01, 32'h0, 32'hABCD_7FEF);
        apply_and_check("LB_OFF2_POS", 2'b10, 3'b000, 2'b10, 32'h0, 32'hAB7F_EFCD);
        apply_and_check("LB_OFF3_POS", 2'b10, 3'b000, 2'b11, 32'h0, 32'h7FCD_EFAB);
        // negative byte (bit 7 = 1) → sign-extend to 0xFFFFFFxx
        apply_and_check("LB_OFF0_NEG", 2'b10, 3'b000, 2'b00, 32'h0, 32'hABCD_EF80);
        apply_and_check("LB_OFF1_NEG", 2'b10, 3'b000, 2'b01, 32'h0, 32'hABCD_80EF);
        apply_and_check("LB_OFF2_NEG", 2'b10, 3'b000, 2'b10, 32'h0, 32'hAB80_EFCD);
        apply_and_check("LB_OFF3_NEG", 2'b10, 3'b000, 2'b11, 32'h0, 32'h80CD_EFAB);
        // boundary: 0x00 and 0xFF
        apply_and_check("LB_ZERO",     2'b10, 3'b000, 2'b00, 32'h0, 32'hFFFF_FF00);
        apply_and_check("LB_FF",       2'b10, 3'b000, 2'b00, 32'h0, 32'h0000_00FF);

        // ============================================================
        // GROUP 8 – LH (Funct3=001, MemRW=10) sign-extend halfword
        // ============================================================
        // positive half (bit 15 = 0)
        apply_and_check("LH_OFF0_POS", 2'b10, 3'b001, 2'b00, 32'h0, 32'hDEAD_7FFF);
        apply_and_check("LH_OFF0_ALT", 2'b10, 3'b001, 2'b01, 32'h0, 32'hDEAD_7FFF); // lsb[1]=0
        apply_and_check("LH_OFF2_POS", 2'b10, 3'b001, 2'b10, 32'h0, 32'h7FFF_DEAD);
        apply_and_check("LH_OFF2_ALT", 2'b10, 3'b001, 2'b11, 32'h0, 32'h7FFF_DEAD); // lsb[1]=1
        // negative half (bit 15 = 1) → sign extend
        apply_and_check("LH_OFF0_NEG", 2'b10, 3'b001, 2'b00, 32'h0, 32'hDEAD_8000);
        apply_and_check("LH_OFF2_NEG", 2'b10, 3'b001, 2'b10, 32'h0, 32'h8000_DEAD);
        // boundary: 0x0000, 0xFFFF
        apply_and_check("LH_ZERO",     2'b10, 3'b001, 2'b00, 32'h0, 32'hFFFF_0000);
        apply_and_check("LH_FFFF",     2'b10, 3'b001, 2'b00, 32'h0, 32'h0000_FFFF);

        // ============================================================
        // GROUP 9 – LW (Funct3=010, MemRW=10) full 32-bit pass-through
        // ============================================================
        apply_and_check("LW_A",        2'b10, 3'b010, 2'b00, 32'h0, 32'hDEAD_BEEF);
        apply_and_check("LW_B",        2'b10, 3'b010, 2'b00, 32'h0, 32'h0000_0000);
        apply_and_check("LW_C",        2'b10, 3'b010, 2'b00, 32'h0, 32'hFFFF_FFFF);
        apply_and_check("LW_D",        2'b10, 3'b010, 2'b00, 32'h0, 32'h8000_0000);
        apply_and_check("LW_E",        2'b10, 3'b010, 2'b00, 32'h0, 32'h0000_0001);

        // ============================================================
        // GROUP 10 – LBU (Funct3=100, MemRW=10) zero-extend byte
        // ============================================================
        apply_and_check("LBU_OFF0_A",  2'b10, 3'b100, 2'b00, 32'h0, 32'hABCD_EFFF); // byte=FF
        apply_and_check("LBU_OFF1_A",  2'b10, 3'b100, 2'b01, 32'h0, 32'hABCD_FFEF);
        apply_and_check("LBU_OFF2_A",  2'b10, 3'b100, 2'b10, 32'h0, 32'hABFF_EFCD);
        apply_and_check("LBU_OFF3_A",  2'b10, 3'b100, 2'b11, 32'h0, 32'hFFCD_EFAB);
        apply_and_check("LBU_OFF0_B",  2'b10, 3'b100, 2'b00, 32'h0, 32'hFFFF_FF80); // byte=80, no sign ext
        apply_and_check("LBU_ZERO",    2'b10, 3'b100, 2'b00, 32'h0, 32'hFFFF_FF00); // byte=00

        // ============================================================
        // GROUP 11 – LHU (Funct3=101, MemRW=10) zero-extend halfword
        // ============================================================
        apply_and_check("LHU_OFF0_A",  2'b10, 3'b101, 2'b00, 32'h0, 32'hDEAD_FFFF); // half=FFFF
        apply_and_check("LHU_OFF0_B",  2'b10, 3'b101, 2'b01, 32'h0, 32'hDEAD_FFFF); // lsb[1]=0
        apply_and_check("LHU_OFF2_A",  2'b10, 3'b101, 2'b10, 32'h0, 32'hFFFF_DEAD); // half=FFFF
        apply_and_check("LHU_OFF2_B",  2'b10, 3'b101, 2'b11, 32'h0, 32'hFFFF_DEAD); // lsb[1]=1
        apply_and_check("LHU_OFF0_C",  2'b10, 3'b101, 2'b00, 32'h0, 32'hDEAD_8000); // half=8000, no sign ext
        apply_and_check("LHU_ZERO",    2'b10, 3'b101, 2'b00, 32'h0, 32'hFFFF_0000); // half=0000

        // ============================================================
        // GROUP 12 – Undefined Funct3 for loads → LoadData=0
        // ============================================================
        apply_and_check("LD_UNK_F3A",  2'b10, 3'b011, 2'b00, 32'h0, 32'hDEAD_BEEF);
        apply_and_check("LD_UNK_F3B",  2'b10, 3'b110, 2'b00, 32'h0, 32'hDEAD_BEEF);
        apply_and_check("LD_UNK_F3C",  2'b10, 3'b111, 2'b00, 32'h0, 32'hDEAD_BEEF);

        // ============================================================
        // GROUP 13 – Spec example cross-checks
        //  These exercise the exact examples from the spec document.
        // ============================================================
        // SB off 0: BE=0001, WD[7:0]=byte
        apply_and_check("SPEC_SB_OFF0", 2'b01, 3'b000, 2'b00, 32'h0000_00AB, 32'h0);
        // SB off 2: BE=0100, WD[23:16]=byte
        apply_and_check("SPEC_SB_OFF2", 2'b01, 3'b000, 2'b10, 32'h0000_00CD, 32'h0);
        // SH off 0: BE=0011
        apply_and_check("SPEC_SH_OFF0", 2'b01, 3'b001, 2'b00, 32'h0000_ABCD, 32'h0);
        // SH off 2: BE=1100
        apply_and_check("SPEC_SH_OFF2", 2'b01, 3'b001, 2'b10, 32'h0000_ABCD, 32'h0);
        // SW off 0: BE=1111, WD=StoreData
        apply_and_check("SPEC_SW",      2'b01, 3'b010, 2'b00, 32'hDEAD_BEEF, 32'h0);

        // ============================================================
        // GROUP 14 – Store outputs inactive during load
        //   MemRW=10 → ByteEnable=0, WriteData=0
        // ============================================================
        apply_and_check("LOAD_SIDE_EFFECT_LB",  2'b10, 3'b000, 2'b00, 32'hABCD_1234, 32'h0000_0042);
        apply_and_check("LOAD_SIDE_EFFECT_LW",  2'b10, 3'b010, 2'b00, 32'hABCD_1234, 32'hDEAD_CAFE);

        // ============================================================
        // GROUP 15 – Load outputs inactive during store
        //   MemRW=01 → LoadData=0
        // ============================================================
        apply_and_check("STORE_SIDE_EFFECT_SB", 2'b01, 3'b000, 2'b00, 32'hABCD_1234, 32'hDEAD_CAFE);
        apply_and_check("STORE_SIDE_EFFECT_SW", 2'b01, 3'b010, 2'b00, 32'hABCD_1234, 32'hDEAD_CAFE);

        // ============================================================
        // GROUP 16 – SB upper-byte isolation
        //   Only StoreData[7:0] must appear in the addressed byte lane.
        //   Upper bits of StoreData must NOT bleed into WriteData.
        // ============================================================
        apply_and_check("SB_UBI_OFF0", 2'b01, 3'b000, 2'b00, 32'hDEAD_BEAB, 32'h0); // WD=0x000000AB, BE=0001
        apply_and_check("SB_UBI_OFF1", 2'b01, 3'b000, 2'b01, 32'hDEAD_BECD, 32'h0); // WD=0x0000CD00, BE=0010
        apply_and_check("SB_UBI_OFF2", 2'b01, 3'b000, 2'b10, 32'hDEAD_BEEF, 32'h0); // WD=0x00EF0000, BE=0100
        apply_and_check("SB_UBI_OFF3", 2'b01, 3'b000, 2'b11, 32'hDEAD_BE5A, 32'h0); // WD=0x5A000000, BE=1000

        // ============================================================
        // GROUP 17 – SH upper-halfword isolation
        //   Only StoreData[15:0] must appear in the addressed halfword
        //   lane.  StoreData[31:16] must NOT appear in WriteData.
        // ============================================================
        apply_and_check("SH_UHI_OFF0", 2'b01, 3'b001, 2'b00, 32'hDEAD_5678, 32'h0); // WD=0x00005678, BE=0011
        apply_and_check("SH_UHI_OFF2", 2'b01, 3'b001, 2'b10, 32'hDEAD_9ABC, 32'h0); // WD=0x9ABC0000, BE=1100

        // ============================================================
        // GROUP 18 – SW with non-zero AddrLSB
        //   SW forces BE=1111 and WD=StoreData regardless of AddrLSB;
        //   the spec restricts SW to offset 0 only, but the DUT should
        //   produce the same well-defined combinational output.
        // ============================================================
        apply_and_check("SW_LSB1", 2'b01, 3'b010, 2'b01, 32'h1234_5678, 32'h0); // BE=1111, WD=StoreData
        apply_and_check("SW_LSB2", 2'b01, 3'b010, 2'b10, 32'hABCD_EF01, 32'h0); // BE=1111, WD=StoreData
        apply_and_check("SW_LSB3", 2'b01, 3'b010, 2'b11, 32'hDEAD_BEEF, 32'h0); // BE=1111, WD=StoreData

        // ============================================================
        // GROUP 19 – LW with non-zero AddrLSB
        //   LW must pass ReadData through unchanged regardless of AddrLSB.
        // ============================================================
        apply_and_check("LW_LSB1", 2'b10, 3'b010, 2'b01, 32'h0, 32'hDEAD_C0DE);
        apply_and_check("LW_LSB2", 2'b10, 3'b010, 2'b10, 32'h0, 32'hFEED_F00D);
        apply_and_check("LW_LSB3", 2'b10, 3'b010, 2'b11, 32'h0, 32'hCA75_0FEE);

        // ============================================================
        // GROUP 20 – Cross-path output isolation
        //   Active path output must be correct; inactive path outputs
        //   must be zero even when the complementary inputs are non-trivial.
        // ============================================================
        // LB load with non-zero StoreData → ByteEnable=0, WriteData=0
        apply_and_check("XISO_LB_NO_WD",  2'b10, 3'b000, 2'b00, 32'hDEAD_BEEF, 32'h0000_00AA);
        // LHU load with non-zero StoreData → ByteEnable=0, WriteData=0
        apply_and_check("XISO_LHU_NO_WD", 2'b10, 3'b101, 2'b00, 32'hDEAD_BEEF, 32'hCAFE_1234);
        // SH store with non-zero ReadData → LoadData=0
        apply_and_check("XISO_SH_NO_LD",  2'b01, 3'b001, 2'b00, 32'hABCD_1234, 32'hCAFE_BABE);
        // SB store with non-zero ReadData → LoadData=0
        apply_and_check("XISO_SB_NO_LD",  2'b01, 3'b000, 2'b10, 32'h0000_0055, 32'hDEAD_BEEF);

        // ============================================================
        // GROUP 21 – LB boundary bytes (0x00 and 0xFF) at all offsets
        //   0x00 → LoadData must be 0x00000000 (no spurious sign bits)
        //   0xFF → LoadData must be 0xFFFFFFFF (full sign extension)
        // ============================================================
        apply_and_check("LB_ZERO_OFF1", 2'b10, 3'b000, 2'b01, 32'h0, 32'hFFFF_00FF); // [15:8]=0x00
        apply_and_check("LB_ZERO_OFF2", 2'b10, 3'b000, 2'b10, 32'h0, 32'hFF00_FFFF); // [23:16]=0x00
        apply_and_check("LB_ZERO_OFF3", 2'b10, 3'b000, 2'b11, 32'h0, 32'h00FF_FFFF); // [31:24]=0x00
        apply_and_check("LB_FF_OFF1",   2'b10, 3'b000, 2'b01, 32'h0, 32'h0000_FF00); // [15:8]=0xFF
        apply_and_check("LB_FF_OFF2",   2'b10, 3'b000, 2'b10, 32'h0, 32'h00FF_0000); // [23:16]=0xFF
        apply_and_check("LB_FF_OFF3",   2'b10, 3'b000, 2'b11, 32'h0, 32'hFF00_0000); // [31:24]=0xFF

        // ============================================================
        // GROUP 22 – LBU 0x80 (high-bit set) at offsets 1, 2, 3
        //   Must zero-extend to 0x00000080, NOT sign-extend to 0xFFFFFF80.
        // ============================================================
        apply_and_check("LBU_OFF1_B", 2'b10, 3'b100, 2'b01, 32'h0, 32'hFFFF_80FF); // [15:8]=0x80
        apply_and_check("LBU_OFF2_B", 2'b10, 3'b100, 2'b10, 32'h0, 32'hFF80_FFFF); // [23:16]=0x80
        apply_and_check("LBU_OFF3_B", 2'b10, 3'b100, 2'b11, 32'h0, 32'h80FF_FFFF); // [31:24]=0x80

        // ============================================================
        // GROUP 23 – LHU/LH boundary halfwords at offset 2
        //   LHU 0x8000 at offset 2 → 0x00008000 (no sign extension)
        //   LH  0x0000 and 0xFFFF at offset 2
        // ============================================================
        apply_and_check("LHU_OFF2_C",   2'b10, 3'b101, 2'b10, 32'h0, 32'h8000_DEAD); // half[31:16]=0x8000
        apply_and_check("LHU_OFF2_D",   2'b10, 3'b101, 2'b11, 32'h0, 32'h8000_DEAD); // lsb[1]=1 same path
        apply_and_check("LH_ZERO_OFF2", 2'b10, 3'b001, 2'b10, 32'h0, 32'h0000_DEAD); // half[31:16]=0x0000
        apply_and_check("LH_FFFF_OFF2", 2'b10, 3'b001, 2'b10, 32'h0, 32'hFFFF_DEAD); // half[31:16]=0xFFFF

        // ============================================================
        // Print required summary lines
        // ============================================================
        $display("TESTS_PASSED : %0d", tests_passed);
        $display("TESTS_ERRORS : %0d", tests_errors);
        $display("TESTS_TOTAL  : %0d", tests_total);
        if (tests_errors == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");

        $finish;
    end

endmodule
