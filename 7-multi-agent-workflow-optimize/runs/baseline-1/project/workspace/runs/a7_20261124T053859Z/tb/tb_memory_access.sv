// tb_memory_access.sv
// Self-checking testbench for the memory_access RV32I load/store unit.
// Compatible with Icarus Verilog 12.
// Covers: store (SB/SH/SW) at all natural-align offsets, load (LB/LH/LW/LBU/LHU)
// at all natural-align offsets, default/inactive MemRW, boundary values, and
// sign/zero-extension edge cases.

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
    // Instantiate DUT
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
    integer tid;

    // -----------------------------------------------------------------------
    // Check task – compares all three outputs against expected values
    // -----------------------------------------------------------------------
    task check_outputs;
        input [31:0] exp_WriteData;
        input [3:0]  exp_ByteEnable;
        input [31:0] exp_LoadData;
        begin
            tests_total = tests_total + 1;
            if (WriteData  !== exp_WriteData  ||
                ByteEnable !== exp_ByteEnable  ||
                LoadData   !== exp_LoadData) begin
                tests_errors = tests_errors + 1;
                $display("  MISMATCH test %0d", tid);
                if (WriteData  !== exp_WriteData)
                    $display("    WriteData : got %08h  expected %08h",
                             WriteData, exp_WriteData);
                if (ByteEnable !== exp_ByteEnable)
                    $display("    ByteEnable: got %04b  expected %04b",
                             ByteEnable, exp_ByteEnable);
                if (LoadData !== exp_LoadData)
                    $display("    LoadData  : got %08h  expected %08h",
                             LoadData, exp_LoadData);
            end else begin
                tests_passed = tests_passed + 1;
            end
            tid = tid + 1;
        end
    endtask

    // -----------------------------------------------------------------------
    // Apply stimulus then settle (combinational DUT, 1-ns settle)
    // -----------------------------------------------------------------------
    task apply;
        input [1:0]  r_MemRW;
        input [2:0]  r_Funct3;
        input [1:0]  r_AddrLSB;
        input [31:0] r_StoreData;
        input [31:0] r_ReadData;
        begin
            MemRW     = r_MemRW;
            Funct3    = r_Funct3;
            AddrLSB   = r_AddrLSB;
            StoreData = r_StoreData;
            ReadData  = r_ReadData;
            #1;
        end
    endtask

    // -----------------------------------------------------------------------
    // Test body
    // -----------------------------------------------------------------------
    initial begin
        tests_passed = 0;
        tests_errors = 0;
        tests_total  = 0;
        tid          = 0;

        $display("=== memory_access testbench ===");

        // ===================================================================
        // GROUP 1 – Default / inactive MemRW
        // ===================================================================
        $display("-- Group 1: Inactive / default MemRW --");

        // MemRW=00 → all outputs zero regardless of other inputs
        apply(2'b00, 3'b000, 2'b00, 32'hDEADBEEF, 32'hCAFEBABE);
        check_outputs(32'h0, 4'b0000, 32'h0);

        apply(2'b00, 3'b010, 2'b01, 32'hFFFFFFFF, 32'hFFFFFFFF);
        check_outputs(32'h0, 4'b0000, 32'h0);

        // MemRW=11 (unused) → all outputs zero
        apply(2'b11, 3'b000, 2'b00, 32'hDEADBEEF, 32'hCAFEBABE);
        check_outputs(32'h0, 4'b0000, 32'h0);

        apply(2'b11, 3'b010, 2'b00, 32'hFFFFFFFF, 32'hFFFFFFFF);
        check_outputs(32'h0, 4'b0000, 32'h0);

        // ===================================================================
        // GROUP 2 – Store: SB (Funct3=000)
        // ===================================================================
        $display("-- Group 2: Store SB --");

        // SB @ offset 0
        apply(2'b01, 3'b000, 2'b00, 32'h000000AB, 32'h0);
        check_outputs(32'h000000AB, 4'b0001, 32'h0);

        // SB @ offset 1
        apply(2'b01, 3'b000, 2'b01, 32'h000000CD, 32'h0);
        check_outputs(32'h0000CD00, 4'b0010, 32'h0);

        // SB @ offset 2
        apply(2'b01, 3'b000, 2'b10, 32'h000000EF, 32'h0);
        check_outputs(32'h00EF0000, 4'b0100, 32'h0);

        // SB @ offset 3
        apply(2'b01, 3'b000, 2'b11, 32'h00000012, 32'h0);
        check_outputs(32'h12000000, 4'b1000, 32'h0);

        // SB – only LSB of StoreData is used; upper bytes must be masked out
        apply(2'b01, 3'b000, 2'b00, 32'hDEADBEEF, 32'h0);
        check_outputs(32'h000000EF, 4'b0001, 32'h0);

        apply(2'b01, 3'b000, 2'b11, 32'hDEADBEEF, 32'h0);
        check_outputs(32'hEF000000, 4'b1000, 32'h0);

        // SB – 0x00 (zero byte)
        apply(2'b01, 3'b000, 2'b00, 32'h00000000, 32'h0);
        check_outputs(32'h00000000, 4'b0001, 32'h0);

        // SB – 0xFF (all-ones byte) @ offset 2
        apply(2'b01, 3'b000, 2'b10, 32'h000000FF, 32'h0);
        check_outputs(32'h00FF0000, 4'b0100, 32'h0);

        // SB – LoadData must be 0 during a store (ReadData irrelevant)
        apply(2'b01, 3'b000, 2'b01, 32'h000000AB, 32'hFFFFFFFF);
        check_outputs(32'h0000AB00, 4'b0010, 32'h0);

        // ===================================================================
        // GROUP 3 – Store: SH (Funct3=001)
        // ===================================================================
        $display("-- Group 3: Store SH --");

        // SH @ offset 0 (AddrLSB[1]=0)
        apply(2'b01, 3'b001, 2'b00, 32'h0000BEEF, 32'h0);
        check_outputs(32'h0000BEEF, 4'b0011, 32'h0);

        // SH @ offset 2 (AddrLSB[1]=1)
        apply(2'b01, 3'b001, 2'b10, 32'h0000CAFE, 32'h0);
        check_outputs(32'hCAFE0000, 4'b1100, 32'h0);

        // SH – only lower 16 bits of StoreData used @ offset 0
        apply(2'b01, 3'b001, 2'b00, 32'hDEADBEEF, 32'h0);
        check_outputs(32'h0000BEEF, 4'b0011, 32'h0);

        // SH – only lower 16 bits used @ offset 2
        apply(2'b01, 3'b001, 2'b10, 32'hDEADBEEF, 32'h0);
        check_outputs(32'hBEEF0000, 4'b1100, 32'h0);

        // SH – zero halfword @ offset 0
        apply(2'b01, 3'b001, 2'b00, 32'h00000000, 32'h0);
        check_outputs(32'h00000000, 4'b0011, 32'h0);

        // SH – 0xFFFF @ offset 2
        apply(2'b01, 3'b001, 2'b10, 32'h0000FFFF, 32'h0);
        check_outputs(32'hFFFF0000, 4'b1100, 32'h0);

        // SH: LoadData must be 0 during a store
        apply(2'b01, 3'b001, 2'b00, 32'h1234ABCD, 32'hDEADBEEF);
        check_outputs(32'h0000ABCD, 4'b0011, 32'h0);

        // ===================================================================
        // GROUP 4 – Store: SW (Funct3=010)
        // ===================================================================
        $display("-- Group 4: Store SW --");

        apply(2'b01, 3'b010, 2'b00, 32'hDEADBEEF, 32'h0);
        check_outputs(32'hDEADBEEF, 4'b1111, 32'h0);

        apply(2'b01, 3'b010, 2'b00, 32'h00000000, 32'h0);
        check_outputs(32'h00000000, 4'b1111, 32'h0);

        apply(2'b01, 3'b010, 2'b00, 32'hFFFFFFFF, 32'h0);
        check_outputs(32'hFFFFFFFF, 4'b1111, 32'h0);

        apply(2'b01, 3'b010, 2'b00, 32'h12345678, 32'hABCDEF00);
        check_outputs(32'h12345678, 4'b1111, 32'h0);

        // ===================================================================
        // GROUP 5 – Store: undefined Funct3 during store
        // ===================================================================
        $display("-- Group 5: Store undefined Funct3 --");

        apply(2'b01, 3'b011, 2'b00, 32'hDEADBEEF, 32'hCAFEBABE);
        check_outputs(32'h0, 4'b0000, 32'h0);

        apply(2'b01, 3'b100, 2'b00, 32'hDEADBEEF, 32'hCAFEBABE);
        check_outputs(32'h0, 4'b0000, 32'h0);

        apply(2'b01, 3'b101, 2'b00, 32'hDEADBEEF, 32'hCAFEBABE);
        check_outputs(32'h0, 4'b0000, 32'h0);

        apply(2'b01, 3'b110, 2'b00, 32'hDEADBEEF, 32'hCAFEBABE);
        check_outputs(32'h0, 4'b0000, 32'h0);

        apply(2'b01, 3'b111, 2'b00, 32'hDEADBEEF, 32'hCAFEBABE);
        check_outputs(32'h0, 4'b0000, 32'h0);

        // ===================================================================
        // GROUP 6 – Load: LB (Funct3=000) – sign-extend byte
        // ===================================================================
        $display("-- Group 6: Load LB (sign extend) --");

        // ReadData = 32'hA1B2C3D4; LE byte map: off0=D4, off1=C3, off2=B2, off3=A1
        apply(2'b10, 3'b000, 2'b00, 32'h0, 32'hA1B2C3D4);
        check_outputs(32'h0, 4'b0000, 32'hFFFFFFD4);

        apply(2'b10, 3'b000, 2'b01, 32'h0, 32'hA1B2C3D4);
        check_outputs(32'h0, 4'b0000, 32'hFFFFFFC3);

        apply(2'b10, 3'b000, 2'b10, 32'h0, 32'hA1B2C3D4);
        check_outputs(32'h0, 4'b0000, 32'hFFFFFFB2);

        apply(2'b10, 3'b000, 2'b11, 32'h0, 32'hA1B2C3D4);
        check_outputs(32'h0, 4'b0000, 32'hFFFFFFA1);

        // LB – positive byte (MSB=0): 0x37 → 32'h00000037
        apply(2'b10, 3'b000, 2'b00, 32'h0, 32'h00000037);
        check_outputs(32'h0, 4'b0000, 32'h00000037);

        // LB – 0x7F (max positive) → 32'h0000007F
        apply(2'b10, 3'b000, 2'b01, 32'h0, 32'h00007F00);
        check_outputs(32'h0, 4'b0000, 32'h0000007F);

        // LB – 0x80 (min negative) → 32'hFFFFFF80
        apply(2'b10, 3'b000, 2'b10, 32'h0, 32'h00800000);
        check_outputs(32'h0, 4'b0000, 32'hFFFFFF80);

        // LB – 0xFF → 32'hFFFFFFFF
        apply(2'b10, 3'b000, 2'b11, 32'h0, 32'hFF000000);
        check_outputs(32'h0, 4'b0000, 32'hFFFFFFFF);

        // LB – 0x00 → 32'h00000000
        apply(2'b10, 3'b000, 2'b00, 32'h0, 32'h12345600);
        check_outputs(32'h0, 4'b0000, 32'h00000000);

        // LB: WriteData and ByteEnable must be 0 during load
        apply(2'b10, 3'b000, 2'b00, 32'hDEADBEEF, 32'h000000AB);
        check_outputs(32'h0, 4'b0000, 32'hFFFFFFAB);

        // ===================================================================
        // GROUP 7 – Load: LH (Funct3=001) – sign-extend halfword
        // ===================================================================
        $display("-- Group 7: Load LH (sign extend) --");

        // ReadData = 32'hA1B2C3D4
        // AddrLSB[1]=0 → lower half 0xC3D4 → sign-ext → 0xFFFFC3D4
        apply(2'b10, 3'b001, 2'b00, 32'h0, 32'hA1B2C3D4);
        check_outputs(32'h0, 4'b0000, 32'hFFFFC3D4);

        // AddrLSB=01 (AddrLSB[1]=0): still lower half
        apply(2'b10, 3'b001, 2'b01, 32'h0, 32'hA1B2C3D4);
        check_outputs(32'h0, 4'b0000, 32'hFFFFC3D4);

        // AddrLSB=10 (AddrLSB[1]=1): upper half 0xA1B2 → 0xFFFFA1B2
        apply(2'b10, 3'b001, 2'b10, 32'h0, 32'hA1B2C3D4);
        check_outputs(32'h0, 4'b0000, 32'hFFFFA1B2);

        // AddrLSB=11 (AddrLSB[1]=1): upper half 0xA1B2
        apply(2'b10, 3'b001, 2'b11, 32'h0, 32'hA1B2C3D4);
        check_outputs(32'h0, 4'b0000, 32'hFFFFA1B2);

        // LH – positive half: 0x7FFF → 32'h00007FFF
        apply(2'b10, 3'b001, 2'b00, 32'h0, 32'h00007FFF);
        check_outputs(32'h0, 4'b0000, 32'h00007FFF);

        // LH – 0x8000 → 32'hFFFF8000
        apply(2'b10, 3'b001, 2'b00, 32'h0, 32'h00008000);
        check_outputs(32'h0, 4'b0000, 32'hFFFF8000);

        // LH – 0xFFFF @ offset 2 → 32'hFFFFFFFF
        apply(2'b10, 3'b001, 2'b10, 32'h0, 32'hFFFF0000);
        check_outputs(32'h0, 4'b0000, 32'hFFFFFFFF);

        // LH – 0x0000 → 32'h00000000
        apply(2'b10, 3'b001, 2'b00, 32'h0, 32'hABCD0000);
        check_outputs(32'h0, 4'b0000, 32'h00000000);

        // ===================================================================
        // GROUP 8 – Load: LW (Funct3=010) – full 32-bit word
        // ===================================================================
        $display("-- Group 8: Load LW --");

        apply(2'b10, 3'b010, 2'b00, 32'h0, 32'hDEADBEEF);
        check_outputs(32'h0, 4'b0000, 32'hDEADBEEF);

        apply(2'b10, 3'b010, 2'b00, 32'h0, 32'h00000000);
        check_outputs(32'h0, 4'b0000, 32'h00000000);

        apply(2'b10, 3'b010, 2'b00, 32'h0, 32'hFFFFFFFF);
        check_outputs(32'h0, 4'b0000, 32'hFFFFFFFF);

        apply(2'b10, 3'b010, 2'b00, 32'h0, 32'h12345678);
        check_outputs(32'h0, 4'b0000, 32'h12345678);

        apply(2'b10, 3'b010, 2'b00, 32'h0, 32'h80000000);
        check_outputs(32'h0, 4'b0000, 32'h80000000);

        // ===================================================================
        // GROUP 9 – Load: LBU (Funct3=100) – zero-extend byte
        // ===================================================================
        $display("-- Group 9: Load LBU (zero extend) --");

        // ReadData = 32'hA1B2C3D4
        apply(2'b10, 3'b100, 2'b00, 32'h0, 32'hA1B2C3D4);
        check_outputs(32'h0, 4'b0000, 32'h000000D4);

        apply(2'b10, 3'b100, 2'b01, 32'h0, 32'hA1B2C3D4);
        check_outputs(32'h0, 4'b0000, 32'h000000C3);

        apply(2'b10, 3'b100, 2'b10, 32'h0, 32'hA1B2C3D4);
        check_outputs(32'h0, 4'b0000, 32'h000000B2);

        apply(2'b10, 3'b100, 2'b11, 32'h0, 32'hA1B2C3D4);
        check_outputs(32'h0, 4'b0000, 32'h000000A1);

        // LBU – 0xFF → 32'h000000FF (zero-extend, NOT sign)
        apply(2'b10, 3'b100, 2'b00, 32'h0, 32'h000000FF);
        check_outputs(32'h0, 4'b0000, 32'h000000FF);

        // LBU – 0x80 → 32'h00000080
        apply(2'b10, 3'b100, 2'b01, 32'h0, 32'h00008000);
        check_outputs(32'h0, 4'b0000, 32'h00000080);

        // LBU – 0x00 → 32'h00000000
        apply(2'b10, 3'b100, 2'b10, 32'h0, 32'hFF00FFFF);
        check_outputs(32'h0, 4'b0000, 32'h00000000);

        // ===================================================================
        // GROUP 10 – Load: LHU (Funct3=101) – zero-extend halfword
        // ===================================================================
        $display("-- Group 10: Load LHU (zero extend) --");

        // ReadData = 32'hA1B2C3D4
        apply(2'b10, 3'b101, 2'b00, 32'h0, 32'hA1B2C3D4);
        check_outputs(32'h0, 4'b0000, 32'h0000C3D4);

        apply(2'b10, 3'b101, 2'b10, 32'h0, 32'hA1B2C3D4);
        check_outputs(32'h0, 4'b0000, 32'h0000A1B2);

        // LHU – 0xFFFF → 32'h0000FFFF (zero-extend)
        apply(2'b10, 3'b101, 2'b00, 32'h0, 32'hABCDFFFF);
        check_outputs(32'h0, 4'b0000, 32'h0000FFFF);

        // LHU – 0x8000 @ offset 2 → 32'h00008000 (zero, not sign)
        apply(2'b10, 3'b101, 2'b10, 32'h0, 32'h80000000);
        check_outputs(32'h0, 4'b0000, 32'h00008000);

        // LHU – 0x0000 → 32'h00000000
        apply(2'b10, 3'b101, 2'b00, 32'h0, 32'hABCD0000);
        check_outputs(32'h0, 4'b0000, 32'h00000000);

        // ===================================================================
        // GROUP 11 – Load: undefined Funct3
        // ===================================================================
        $display("-- Group 11: Load undefined Funct3 --");

        apply(2'b10, 3'b011, 2'b00, 32'h0, 32'hDEADBEEF);
        check_outputs(32'h0, 4'b0000, 32'h0);

        apply(2'b10, 3'b110, 2'b00, 32'h0, 32'hDEADBEEF);
        check_outputs(32'h0, 4'b0000, 32'h0);

        apply(2'b10, 3'b111, 2'b00, 32'h0, 32'hDEADBEEF);
        check_outputs(32'h0, 4'b0000, 32'h0);

        // ===================================================================
        // GROUP 12 – Cross-output isolation
        // ===================================================================
        $display("-- Group 12: Cross-output isolation --");

        // Store: LoadData must be 0
        apply(2'b01, 3'b010, 2'b00, 32'hABCDEF01, 32'hFEDCBA98);
        check_outputs(32'hABCDEF01, 4'b1111, 32'h0);

        // Load: WriteData and ByteEnable must be 0
        apply(2'b10, 3'b010, 2'b00, 32'hABCDEF01, 32'hFEDCBA98);
        check_outputs(32'h0, 4'b0000, 32'hFEDCBA98);

        // ===================================================================
        // GROUP 13 – Boundary / walking-bit patterns
        // ===================================================================
        $display("-- Group 13: Boundary patterns --");

        apply(2'b01, 3'b010, 2'b00, 32'hAAAAAAAA, 32'h0);
        check_outputs(32'hAAAAAAAA, 4'b1111, 32'h0);

        apply(2'b01, 3'b010, 2'b00, 32'h55555555, 32'h0);
        check_outputs(32'h55555555, 4'b1111, 32'h0);

        apply(2'b10, 3'b010, 2'b00, 32'h0, 32'hAAAAAAAA);
        check_outputs(32'h0, 4'b0000, 32'hAAAAAAAA);

        // LBU walk through 0xAABBCCDD
        apply(2'b10, 3'b100, 2'b00, 32'h0, 32'hAABBCCDD);
        check_outputs(32'h0, 4'b0000, 32'h000000DD);

        apply(2'b10, 3'b100, 2'b01, 32'h0, 32'hAABBCCDD);
        check_outputs(32'h0, 4'b0000, 32'h000000CC);

        apply(2'b10, 3'b100, 2'b10, 32'h0, 32'hAABBCCDD);
        check_outputs(32'h0, 4'b0000, 32'h000000BB);

        apply(2'b10, 3'b100, 2'b11, 32'h0, 32'hAABBCCDD);
        check_outputs(32'h0, 4'b0000, 32'h000000AA);

        // ===================================================================
        // GROUP 14 – Store: SH with odd AddrLSB (AddrLSB[1] is selector)
        // Gap G-1: verify AddrLSB=01 and AddrLSB=11 route correctly
        // ===================================================================
        $display("-- Group 14: Store SH odd AddrLSB --");

        // SH @ AddrLSB=01 → AddrLSB[1]=0 → lower half → BE=0011
        apply(2'b01, 3'b001, 2'b01, 32'h0000BEEF, 32'h0);
        check_outputs(32'h0000BEEF, 4'b0011, 32'h0);

        // SH @ AddrLSB=01 with upper bits set in StoreData → only lower 16 used
        apply(2'b01, 3'b001, 2'b01, 32'hDEADBEEF, 32'h0);
        check_outputs(32'h0000BEEF, 4'b0011, 32'h0);

        // SH @ AddrLSB=11 → AddrLSB[1]=1 → upper half → BE=1100
        apply(2'b01, 3'b001, 2'b11, 32'h0000CAFE, 32'h0);
        check_outputs(32'hCAFE0000, 4'b1100, 32'h0);

        // SH @ AddrLSB=11 with upper bits set in StoreData → only lower 16 used
        apply(2'b01, 3'b001, 2'b11, 32'hDEADBEEF, 32'h0);
        check_outputs(32'hBEEF0000, 4'b1100, 32'h0);

        // SH @ AddrLSB=11 all-ones halfword
        apply(2'b01, 3'b001, 2'b11, 32'h0000FFFF, 32'h0);
        check_outputs(32'hFFFF0000, 4'b1100, 32'h0);

        // ===================================================================
        // GROUP 15 – Store: SB upper-byte masking at offsets 1 and 2
        // Gap G-2: upper bytes of StoreData must be stripped at mid-word offsets
        // ===================================================================
        $display("-- Group 15: Store SB masking at offsets 1 and 2 --");

        // SB @ offset 1 with multi-byte StoreData: only [7:0]=0xEF placed
        apply(2'b01, 3'b000, 2'b01, 32'hDEADBEEF, 32'h0);
        check_outputs(32'h0000EF00, 4'b0010, 32'h0);

        // SB @ offset 2 with multi-byte StoreData: only [7:0]=0xEF placed
        apply(2'b01, 3'b000, 2'b10, 32'hDEADBEEF, 32'h0);
        check_outputs(32'h00EF0000, 4'b0100, 32'h0);

        // SB @ offset 1 with 0xFF byte
        apply(2'b01, 3'b000, 2'b01, 32'h000000FF, 32'h0);
        check_outputs(32'h0000FF00, 4'b0010, 32'h0);

        // SB @ offset 2 with 0x00 byte
        apply(2'b01, 3'b000, 2'b10, 32'hFFFFFF00, 32'h0);
        check_outputs(32'h00000000, 4'b0100, 32'h0);

        // ===================================================================
        // GROUP 16 – Load: LHU with odd AddrLSB
        // Gap G-3: AddrLSB=01 (→ lower half) and AddrLSB=11 (→ upper half)
        // ===================================================================
        $display("-- Group 16: Load LHU odd AddrLSB --");

        // ReadData = 32'hA1B2C3D4
        // AddrLSB=01 → AddrLSB[1]=0 → lower half C3D4 → 32'h0000C3D4
        apply(2'b10, 3'b101, 2'b01, 32'h0, 32'hA1B2C3D4);
        check_outputs(32'h0, 4'b0000, 32'h0000C3D4);

        // AddrLSB=11 → AddrLSB[1]=1 → upper half A1B2 → 32'h0000A1B2
        apply(2'b10, 3'b101, 2'b11, 32'h0, 32'hA1B2C3D4);
        check_outputs(32'h0, 4'b0000, 32'h0000A1B2);

        // LHU @ odd offset with high-bit halfword (must NOT sign-extend)
        // AddrLSB=01, upper half = 0x8000 → 32'h00008000
        apply(2'b10, 3'b101, 2'b01, 32'h0, 32'h00008000);
        check_outputs(32'h0, 4'b0000, 32'h00008000);

        // LHU @ AddrLSB=11, lower half = 0xFFFF (ReadData[31:16]=0xFFFF)
        apply(2'b10, 3'b101, 2'b11, 32'h0, 32'hFFFF0000);
        check_outputs(32'h0, 4'b0000, 32'h0000FFFF);

        // ===================================================================
        // GROUP 17 – Extended cross-output isolation for all load types
        // Gap G-4: WriteData and ByteEnable must be 0 for LB/LH/LBU/LHU
        // ===================================================================
        $display("-- Group 17: Cross-output isolation LB/LH/LBU/LHU --");

        // LB: WriteData=0, ByteEnable=0 even when StoreData is non-zero
        apply(2'b10, 3'b000, 2'b00, 32'hDEADBEEF, 32'h000000AB);
        check_outputs(32'h0, 4'b0000, 32'hFFFFFFAB);

        // LH: WriteData=0, ByteEnable=0
        apply(2'b10, 3'b001, 2'b00, 32'hDEADBEEF, 32'h00007FFF);
        check_outputs(32'h0, 4'b0000, 32'h00007FFF);

        // LBU: WriteData=0, ByteEnable=0
        apply(2'b10, 3'b100, 2'b00, 32'hDEADBEEF, 32'h000000FF);
        check_outputs(32'h0, 4'b0000, 32'h000000FF);

        // LHU: WriteData=0, ByteEnable=0
        apply(2'b10, 3'b101, 2'b00, 32'hDEADBEEF, 32'h0000BEEF);
        check_outputs(32'h0, 4'b0000, 32'h0000BEEF);

        // ===================================================================
        // GROUP 18 – LBU zero-extension at all offsets with high-bit bytes;
        //            MemRW=00 with Funct3=001 (SH encoding) stays zero
        // Gap G-5 & G-6
        // ===================================================================
        $display("-- Group 18: LBU high-bit offsets; MemRW=00 SH --");

        // LBU offset 2: ReadData[23:16]=0xAA → 32'h000000AA (zero extend)
        apply(2'b10, 3'b100, 2'b10, 32'h0, 32'h00AA0000);
        check_outputs(32'h0, 4'b0000, 32'h000000AA);

        // LBU offset 3: ReadData[31:24]=0xAA → 32'h000000AA (zero extend)
        apply(2'b10, 3'b100, 2'b11, 32'h0, 32'hAA000000);
        check_outputs(32'h0, 4'b0000, 32'h000000AA);

        // LBU offset 3: ReadData[31:24]=0x80 → 32'h00000080 (zero, not sign)
        apply(2'b10, 3'b100, 2'b11, 32'h0, 32'h80000000);
        check_outputs(32'h0, 4'b0000, 32'h00000080);

        // LBU offset 3: ReadData[31:24]=0xFF → 32'h000000FF (zero, not sign)
        apply(2'b10, 3'b100, 2'b11, 32'h0, 32'hFF000000);
        check_outputs(32'h0, 4'b0000, 32'h000000FF);

        // MemRW=00 with Funct3=001 (SH encoding): all outputs must be zero
        apply(2'b00, 3'b001, 2'b00, 32'hDEADBEEF, 32'hCAFEBABE);
        check_outputs(32'h0, 4'b0000, 32'h0);

        // MemRW=00 with Funct3=100 (LBU encoding): all outputs must be zero
        apply(2'b00, 3'b100, 2'b01, 32'hDEADBEEF, 32'hCAFEBABE);
        check_outputs(32'h0, 4'b0000, 32'h0);

        // ===================================================================
        // Final summary
        // ===================================================================
        $display("");
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
