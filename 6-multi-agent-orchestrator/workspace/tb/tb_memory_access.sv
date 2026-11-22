// tb_memory_access.sv
// Self-checking testbench for the RV32I memory_access module.
// Compatible with Icarus Verilog 12.
//
// Coverage:
//   - Inactive / default state (MemRW == 2'b00, 2'b11)
//   - SB: all four byte offsets (AddrLSB = 0,1,2,3)
//   - SH: both halfword offsets (AddrLSB[1] = 0, 1)
//   - SW: full-word store (AddrLSB independence confirmed)
//   - LB:  signed byte at all four offsets (positive and negative)
//   - LBU: unsigned byte at all four offsets
//   - LH:  signed halfword at offsets 0 and 2 (positive and negative)
//   - LHU: unsigned halfword at offsets 0 and 2
//   - LW:  full 32-bit word
//   - Store outputs (WriteData/ByteEnable) are zero when MemRW == 10
//   - Load output (LoadData) is zero when MemRW == 01
//   - Unused store Funct3 encodings (3'b011,100,101,110,111) → ByteEnable=0, WriteData=0
//   - Unused load  Funct3 encodings (3'b011,110,111)        → LoadData=0

`timescale 1ns/1ps

module tb_memory_access;

    // ----------------------------------------------------------------
    // DUT port declarations
    // ----------------------------------------------------------------
    logic [1:0]  MemRW;
    logic [2:0]  Funct3;
    logic [1:0]  AddrLSB;
    logic [31:0] StoreData;
    logic [31:0] ReadData;
    logic [31:0] WriteData;
    logic [3:0]  ByteEnable;
    logic [31:0] LoadData;

    // ----------------------------------------------------------------
    // DUT instantiation
    // ----------------------------------------------------------------
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

    // ----------------------------------------------------------------
    // Scoreboard (module-level to avoid Icarus 'automatic' restriction)
    // ----------------------------------------------------------------
    integer passed;
    integer errors;
    integer total;

    // ----------------------------------------------------------------
    // Check task – purely combinational outputs; no clock needed.
    // ----------------------------------------------------------------
    task check_outputs;
        input [31:0]  exp_WriteData;
        input [3:0]   exp_ByteEnable;
        input [31:0]  exp_LoadData;
        input [127:0] label;
    begin
        total = total + 1;
        if ((WriteData   === exp_WriteData)  &&
            (ByteEnable  === exp_ByteEnable) &&
            (LoadData    === exp_LoadData)) begin
            passed = passed + 1;
        end else begin
            errors = errors + 1;
            $display("MISMATCH [%s]", label);
            $display("  Inputs : MemRW=%b Funct3=%b AddrLSB=%b StoreData=%08h ReadData=%08h",
                     MemRW, Funct3, AddrLSB, StoreData, ReadData);
            if (WriteData !== exp_WriteData)
                $display("  WriteData  got=%08h  exp=%08h", WriteData,  exp_WriteData);
            if (ByteEnable !== exp_ByteEnable)
                $display("  ByteEnable got=%04b   exp=%04b",  ByteEnable, exp_ByteEnable);
            if (LoadData !== exp_LoadData)
                $display("  LoadData   got=%08h  exp=%08h",  LoadData,   exp_LoadData);
        end
    end
    endtask

    // ----------------------------------------------------------------
    // Convenience helper: set inputs then #1 for combinational settle
    // ----------------------------------------------------------------
    task apply;
        input [1:0]  t_MemRW;
        input [2:0]  t_Funct3;
        input [1:0]  t_AddrLSB;
        input [31:0] t_StoreData;
        input [31:0] t_ReadData;
    begin
        MemRW     = t_MemRW;
        Funct3    = t_Funct3;
        AddrLSB   = t_AddrLSB;
        StoreData = t_StoreData;
        ReadData  = t_ReadData;
        #1;
    end
    endtask

    // ----------------------------------------------------------------
    // Expected-value functions (independent reference model)
    // ----------------------------------------------------------------

    // --- Store helpers ---
    function [31:0] sb_write_data;
        input [7:0]  byte_val;
        input [1:0]  offset;
        begin
            case (offset)
                2'b00: sb_write_data = {24'h000000, byte_val};
                2'b01: sb_write_data = {16'h0000,   byte_val, 8'h00};
                2'b10: sb_write_data = {8'h00,      byte_val, 16'h0000};
                2'b11: sb_write_data = {byte_val, 24'h000000};
            endcase
        end
    endfunction

    function [3:0] sb_byte_en;
        input [1:0] offset;
        begin
            case (offset)
                2'b00: sb_byte_en = 4'b0001;
                2'b01: sb_byte_en = 4'b0010;
                2'b10: sb_byte_en = 4'b0100;
                2'b11: sb_byte_en = 4'b1000;
            endcase
        end
    endfunction

    function [31:0] sh_write_data;
        input [15:0] half_val;
        input [1:0]  offset;
        begin
            if (offset[1] == 1'b0)
                sh_write_data = {16'h0000, half_val};
            else
                sh_write_data = {half_val, 16'h0000};
        end
    endfunction

    function [3:0] sh_byte_en;
        input [1:0] offset;
        begin
            if (offset[1] == 1'b0)
                sh_byte_en = 4'b0011;
            else
                sh_byte_en = 4'b1100;
        end
    endfunction

    // --- Load helpers ---
    function [7:0] select_byte;
        input [31:0] rd;
        input [1:0]  offset;
        begin
            case (offset)
                2'b00: select_byte = rd[7:0];
                2'b01: select_byte = rd[15:8];
                2'b10: select_byte = rd[23:16];
                2'b11: select_byte = rd[31:24];
            endcase
        end
    endfunction

    function [15:0] select_half;
        input [31:0] rd;
        input [1:0]  offset;
        begin
            if (offset[1] == 1'b0)
                select_half = rd[15:0];
            else
                select_half = rd[31:16];
        end
    endfunction

    function [31:0] lb_load;
        input [31:0] rd;
        input [1:0]  offset;
        reg [7:0] b;
        begin
            b = select_byte(rd, offset);
            lb_load = {{24{b[7]}}, b};
        end
    endfunction

    function [31:0] lbu_load;
        input [31:0] rd;
        input [1:0]  offset;
        begin
            lbu_load = {24'h000000, select_byte(rd, offset)};
        end
    endfunction

    function [31:0] lh_load;
        input [31:0] rd;
        input [1:0]  offset;
        reg [15:0] h;
        begin
            h = select_half(rd, offset);
            lh_load = {{16{h[15]}}, h};
        end
    endfunction

    function [31:0] lhu_load;
        input [31:0] rd;
        input [1:0]  offset;
        begin
            lhu_load = {16'h0000, select_half(rd, offset)};
        end
    endfunction

    // ================================================================
    // Main test sequence
    // ================================================================
    initial begin
        passed    = 0;
        errors    = 0;
        total     = 0;
        MemRW     = 2'b00;
        Funct3    = 3'b000;
        AddrLSB   = 2'b00;
        StoreData = 32'h0;
        ReadData  = 32'h0;
        #2;

        // ============================================================
        // GROUP 1: Inactive / default state
        // ============================================================
        apply(2'b00, 3'b010, 2'b00, 32'hDEADBEEF, 32'hCAFEBABE);
        check_outputs(32'h0, 4'b0000, 32'h0, "IDLE_SW");

        apply(2'b00, 3'b000, 2'b01, 32'hAA55AA55, 32'h12345678);
        check_outputs(32'h0, 4'b0000, 32'h0, "IDLE_SB");

        // MemRW == 11 (unused) → same defaults
        apply(2'b11, 3'b010, 2'b00, 32'hFFFFFFFF, 32'hFFFFFFFF);
        check_outputs(32'h0, 4'b0000, 32'h0, "UNUSED_11");

        // ============================================================
        // GROUP 2: SB – all four byte offsets
        // ============================================================
        apply(2'b01, 3'b000, 2'b00, 32'hABCDEF42, 32'h0);
        check_outputs(sb_write_data(8'h42, 2'b00), sb_byte_en(2'b00), 32'h0, "SB_OFF0");

        apply(2'b01, 3'b000, 2'b01, 32'hABCDEF99, 32'h0);
        check_outputs(sb_write_data(8'h99, 2'b01), sb_byte_en(2'b01), 32'h0, "SB_OFF1");

        apply(2'b01, 3'b000, 2'b10, 32'hABCDEFAA, 32'h0);
        check_outputs(sb_write_data(8'hAA, 2'b10), sb_byte_en(2'b10), 32'h0, "SB_OFF2");

        apply(2'b01, 3'b000, 2'b11, 32'hABCDEF7F, 32'h0);
        check_outputs(sb_write_data(8'h7F, 2'b11), sb_byte_en(2'b11), 32'h0, "SB_OFF3");

        // SB with all-ones source, offset 0 – only low byte placed
        apply(2'b01, 3'b000, 2'b00, 32'hFFFFFFFF, 32'h0);
        check_outputs(32'h000000FF, 4'b0001, 32'h0, "SB_ALLF_OFF0");

        // SB with zero data, offset 0 – ByteEnable must still assert
        apply(2'b01, 3'b000, 2'b00, 32'h0, 32'h0);
        check_outputs(32'h0, 4'b0001, 32'h0, "SB_OFF0_ZERO");

        // ============================================================
        // GROUP 3: SH – both halfword offsets
        // ============================================================
        apply(2'b01, 3'b001, 2'b00, 32'hABCD1234, 32'h0);
        check_outputs(sh_write_data(16'h1234, 2'b00), sh_byte_en(2'b00), 32'h0, "SH_OFF0");

        apply(2'b01, 3'b001, 2'b10, 32'hABCDFACE, 32'h0);
        check_outputs(sh_write_data(16'hFACE, 2'b10), sh_byte_en(2'b10), 32'h0, "SH_OFF2");

        // AddrLSB bit-0 ignored for SH – only bit[1] is significant
        apply(2'b01, 3'b001, 2'b01, 32'hABCD5A5A, 32'h0);
        check_outputs(sh_write_data(16'h5A5A, 2'b01), sh_byte_en(2'b01), 32'h0, "SH_OFF1_B0ign");

        apply(2'b01, 3'b001, 2'b11, 32'hABCDBEEF, 32'h0);
        check_outputs(sh_write_data(16'hBEEF, 2'b11), sh_byte_en(2'b11), 32'h0, "SH_OFF3_B0ign");

        // SH zero data, offset 2 – ByteEnable must still assert
        apply(2'b01, 3'b001, 2'b10, 32'h0, 32'h0);
        check_outputs(32'h0, 4'b1100, 32'h0, "SH_OFF2_ZERO");

        // ============================================================
        // GROUP 4: SW
        // ============================================================
        apply(2'b01, 3'b010, 2'b00, 32'hDEADBEEF, 32'h0);
        check_outputs(32'hDEADBEEF, 4'b1111, 32'h0, "SW_DEADBEEF");

        apply(2'b01, 3'b010, 2'b00, 32'h00000000, 32'h0);
        check_outputs(32'h00000000, 4'b1111, 32'h0, "SW_ZERO");

        apply(2'b01, 3'b010, 2'b00, 32'hFFFFFFFF, 32'h0);
        check_outputs(32'hFFFFFFFF, 4'b1111, 32'h0, "SW_ALLONES");

        // ============================================================
        // GROUP 5: LoadData is 0 during stores; WriteData/BE are 0 during loads
        // ============================================================
        apply(2'b01, 3'b010, 2'b00, 32'hDEADBEEF, 32'hCAFEBABE);
        check_outputs(32'hDEADBEEF, 4'b1111, 32'h0, "STORE_LD=0");

        apply(2'b10, 3'b010, 2'b00, 32'hDEADBEEF, 32'hCAFEBABE);
        check_outputs(32'h0, 4'b0000, 32'hCAFEBABE, "LOAD_WD=0");

        // ============================================================
        // GROUP 6: LB – signed byte load, all four offsets
        // ============================================================
        // Negative: ReadData = 32'h81828384 (all bytes have MSB=1)
        apply(2'b10, 3'b000, 2'b00, 32'h0, 32'h81828384);
        check_outputs(32'h0, 4'b0000, lb_load(32'h81828384, 2'b00), "LB_NEG_OFF0");

        apply(2'b10, 3'b000, 2'b01, 32'h0, 32'h81828384);
        check_outputs(32'h0, 4'b0000, lb_load(32'h81828384, 2'b01), "LB_NEG_OFF1");

        apply(2'b10, 3'b000, 2'b10, 32'h0, 32'h81828384);
        check_outputs(32'h0, 4'b0000, lb_load(32'h81828384, 2'b10), "LB_NEG_OFF2");

        apply(2'b10, 3'b000, 2'b11, 32'h0, 32'h81828384);
        check_outputs(32'h0, 4'b0000, lb_load(32'h81828384, 2'b11), "LB_NEG_OFF3");

        // Positive: ReadData = 32'h01020304 (all bytes have MSB=0)
        apply(2'b10, 3'b000, 2'b00, 32'h0, 32'h01020304);
        check_outputs(32'h0, 4'b0000, lb_load(32'h01020304, 2'b00), "LB_POS_OFF0");

        apply(2'b10, 3'b000, 2'b01, 32'h0, 32'h01020304);
        check_outputs(32'h0, 4'b0000, lb_load(32'h01020304, 2'b01), "LB_POS_OFF1");

        apply(2'b10, 3'b000, 2'b10, 32'h0, 32'h01020304);
        check_outputs(32'h0, 4'b0000, lb_load(32'h01020304, 2'b10), "LB_POS_OFF2");

        apply(2'b10, 3'b000, 2'b11, 32'h0, 32'h01020304);
        check_outputs(32'h0, 4'b0000, lb_load(32'h01020304, 2'b11), "LB_POS_OFF3");

        // ============================================================
        // GROUP 7: LBU – unsigned byte, all four offsets
        // ============================================================
        apply(2'b10, 3'b100, 2'b00, 32'h0, 32'hDEADBEEF);
        check_outputs(32'h0, 4'b0000, lbu_load(32'hDEADBEEF, 2'b00), "LBU_OFF0");

        apply(2'b10, 3'b100, 2'b01, 32'h0, 32'hDEADBEEF);
        check_outputs(32'h0, 4'b0000, lbu_load(32'hDEADBEEF, 2'b01), "LBU_OFF1");

        apply(2'b10, 3'b100, 2'b10, 32'h0, 32'hDEADBEEF);
        check_outputs(32'h0, 4'b0000, lbu_load(32'hDEADBEEF, 2'b10), "LBU_OFF2");

        apply(2'b10, 3'b100, 2'b11, 32'h0, 32'hDEADBEEF);
        check_outputs(32'h0, 4'b0000, lbu_load(32'hDEADBEEF, 2'b11), "LBU_OFF3");

        // ============================================================
        // GROUP 8: LH – signed halfword, offsets 0 and 2
        // ============================================================
        apply(2'b10, 3'b001, 2'b00, 32'h0, 32'hFEEDCAFE);
        check_outputs(32'h0, 4'b0000, lh_load(32'hFEEDCAFE, 2'b00), "LH_NEG_OFF0");

        apply(2'b10, 3'b001, 2'b10, 32'h0, 32'hFEEDCAFE);
        check_outputs(32'h0, 4'b0000, lh_load(32'hFEEDCAFE, 2'b10), "LH_NEG_OFF2");

        apply(2'b10, 3'b001, 2'b00, 32'h0, 32'h00011234);
        check_outputs(32'h0, 4'b0000, lh_load(32'h00011234, 2'b00), "LH_POS_OFF0");

        apply(2'b10, 3'b001, 2'b10, 32'h0, 32'h56780001);
        check_outputs(32'h0, 4'b0000, lh_load(32'h56780001, 2'b10), "LH_POS_OFF2");

        // ============================================================
        // GROUP 9: LHU – unsigned halfword, offsets 0 and 2
        // ============================================================
        apply(2'b10, 3'b101, 2'b00, 32'h0, 32'hFEEDCAFE);
        check_outputs(32'h0, 4'b0000, lhu_load(32'hFEEDCAFE, 2'b00), "LHU_OFF0");

        apply(2'b10, 3'b101, 2'b10, 32'h0, 32'hFEEDCAFE);
        check_outputs(32'h0, 4'b0000, lhu_load(32'hFEEDCAFE, 2'b10), "LHU_OFF2");

        apply(2'b10, 3'b101, 2'b00, 32'h0, 32'h0000BEEF);
        check_outputs(32'h0, 4'b0000, lhu_load(32'h0000BEEF, 2'b00), "LHU_SMALL");

        // ============================================================
        // GROUP 10: LW – full 32-bit word
        // ============================================================
        apply(2'b10, 3'b010, 2'b00, 32'h0, 32'hDEADBEEF);
        check_outputs(32'h0, 4'b0000, 32'hDEADBEEF, "LW_DEADBEEF");

        apply(2'b10, 3'b010, 2'b00, 32'h0, 32'h00000000);
        check_outputs(32'h0, 4'b0000, 32'h00000000, "LW_ZERO");

        apply(2'b10, 3'b010, 2'b00, 32'h0, 32'hFFFFFFFF);
        check_outputs(32'h0, 4'b0000, 32'hFFFFFFFF, "LW_ALLONES");

        // ============================================================
        // GROUP 11: Sign/zero extension boundary values
        // ============================================================
        // LB byte=0x7F (max positive, no sign extension)
        apply(2'b10, 3'b000, 2'b00, 32'h0, 32'hDEADBE7F);
        check_outputs(32'h0, 4'b0000, 32'h0000007F, "LB_MAX_POS");

        // LB byte=0x80 (min negative → sign extend to 0xFFFFFF80)
        apply(2'b10, 3'b000, 2'b00, 32'h0, 32'hDEADBE80);
        check_outputs(32'h0, 4'b0000, 32'hFFFFFF80, "LB_MIN_NEG");

        // LB byte=0xFF → sign-extend to 0xFFFFFFFF
        apply(2'b10, 3'b000, 2'b00, 32'h0, 32'hDEADBEFF);
        check_outputs(32'h0, 4'b0000, 32'hFFFFFFFF, "LB_0xFF");

        // LBU byte=0xFF → zero-extend to 0x000000FF
        apply(2'b10, 3'b100, 2'b00, 32'h0, 32'hDEADBEFF);
        check_outputs(32'h0, 4'b0000, 32'h000000FF, "LBU_0xFF");

        // LH half=0x7FFF (max positive)
        apply(2'b10, 3'b001, 2'b00, 32'h0, 32'hABCD7FFF);
        check_outputs(32'h0, 4'b0000, 32'h00007FFF, "LH_MAX_POS");

        // LH half=0x8000 (min negative → 0xFFFF8000)
        apply(2'b10, 3'b001, 2'b00, 32'h0, 32'hABCD8000);
        check_outputs(32'h0, 4'b0000, 32'hFFFF8000, "LH_MIN_NEG");

        // LH half=0xFFFF → sign-extend to 0xFFFFFFFF
        apply(2'b10, 3'b001, 2'b00, 32'h0, 32'hABCDFFFF);
        check_outputs(32'h0, 4'b0000, 32'hFFFFFFFF, "LH_0xFFFF");

        // LHU half=0xFFFF → zero-extend to 0x0000FFFF
        apply(2'b10, 3'b101, 2'b00, 32'h0, 32'hABCDFFFF);
        check_outputs(32'h0, 4'b0000, 32'h0000FFFF, "LHU_0xFFFF");

        // ============================================================
        // GROUP 12: SW AddrLSB independence (SW ignores byte offset)
        // ============================================================
        // SW with AddrLSB=2 must still produce full ByteEnable and full WriteData
        apply(2'b01, 3'b010, 2'b10, 32'hA5A5A5A5, 32'h0);
        check_outputs(32'hA5A5A5A5, 4'b1111, 32'h0, "SW_ADDRLSB2");

        apply(2'b01, 3'b010, 2'b11, 32'h12345678, 32'h0);
        check_outputs(32'h12345678, 4'b1111, 32'h0, "SW_ADDRLSB3");

        // ============================================================
        // GROUP 13: Unused store Funct3 encodings (MemRW=01)
        //           Spec: only 000/001/010 are defined stores.
        //           RTL must default to ByteEnable=0, WriteData=0.
        // ============================================================
        apply(2'b01, 3'b011, 2'b00, 32'hDEADBEEF, 32'h0);
        check_outputs(32'h0, 4'b0000, 32'h0, "STORE_F3_011");

        apply(2'b01, 3'b100, 2'b00, 32'hDEADBEEF, 32'h0);
        check_outputs(32'h0, 4'b0000, 32'h0, "STORE_F3_100");

        apply(2'b01, 3'b101, 2'b00, 32'hDEADBEEF, 32'h0);
        check_outputs(32'h0, 4'b0000, 32'h0, "STORE_F3_101");

        apply(2'b01, 3'b110, 2'b00, 32'hDEADBEEF, 32'h0);
        check_outputs(32'h0, 4'b0000, 32'h0, "STORE_F3_110");

        apply(2'b01, 3'b111, 2'b00, 32'hDEADBEEF, 32'h0);
        check_outputs(32'h0, 4'b0000, 32'h0, "STORE_F3_111");

        // ============================================================
        // GROUP 14: Unused load Funct3 encodings (MemRW=10)
        //           Spec: only 000/001/010/100/101 are defined loads.
        //           RTL must default to LoadData=0.
        // ============================================================
        apply(2'b10, 3'b011, 2'b00, 32'h0, 32'hDEADBEEF);
        check_outputs(32'h0, 4'b0000, 32'h0, "LOAD_F3_011");

        apply(2'b10, 3'b110, 2'b00, 32'h0, 32'hDEADBEEF);
        check_outputs(32'h0, 4'b0000, 32'h0, "LOAD_F3_110");

        apply(2'b10, 3'b111, 2'b00, 32'h0, 32'hDEADBEEF);
        check_outputs(32'h0, 4'b0000, 32'h0, "LOAD_F3_111");

        // ============================================================
        // Print summary
        // ============================================================
        $display("TESTS_PASSED: %0d", passed);
        $display("TESTS_ERRORS: %0d", errors);
        $display("TESTS_TOTAL: %0d",  total);
        if (errors == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");

        $finish;
    end

endmodule
