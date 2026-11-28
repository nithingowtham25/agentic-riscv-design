// memory_access.sv
// RV32I load/store data-formatting unit  (little-endian, 32-bit memory word)
//
// Store path  (MemRW==01): builds WriteData + ByteEnable from StoreData/Funct3/AddrLSB
// Load  path  (MemRW==10): builds LoadData from ReadData/Funct3/AddrLSB
// Defaults    (spec §Deterministic Defaults):
//   MemRW != 01  → ByteEnable=0, WriteData=0
//   MemRW != 10  → LoadData=0
//
// Synthesizable, latch-free SystemVerilog; compatible with Icarus Verilog 12.
// All ReadData/StoreData slices are hoisted to continuous assigns to avoid
// the iverilog "constant selects in always_*" limitation.

module memory_access (
    input  logic [1:0]  MemRW,
    input  logic [2:0]  Funct3,
    input  logic [1:0]  AddrLSB,
    input  logic [31:0] StoreData,
    input  logic [31:0] ReadData,
    output logic [31:0] WriteData,
    output logic [3:0]  ByteEnable,
    output logic [31:0] LoadData
);

    // -------------------------------------------------------------------------
    // ReadData lane slices (continuous assigns → no iverilog sorry: warnings)
    // -------------------------------------------------------------------------
    logic [7:0]  rd_b0, rd_b1, rd_b2, rd_b3;
    logic [15:0] rd_h0, rd_h1;

    assign rd_b0 = ReadData[ 7: 0];
    assign rd_b1 = ReadData[15: 8];
    assign rd_b2 = ReadData[23:16];
    assign rd_b3 = ReadData[31:24];
    assign rd_h0 = ReadData[15: 0];
    assign rd_h1 = ReadData[31:16];

    // -------------------------------------------------------------------------
    // StoreData lane slices
    // -------------------------------------------------------------------------
    logic [7:0]  sd_b0;
    logic [15:0] sd_h0;

    assign sd_b0 = StoreData[ 7: 0];
    assign sd_h0 = StoreData[15: 0];

    // -------------------------------------------------------------------------
    // AddrLSB bit-field aliases (continuous assigns to avoid iverilog sorry:)
    // -------------------------------------------------------------------------
    logic addr_bit1;   // AddrLSB[1] – selects halfword lane
    assign addr_bit1 = AddrLSB[1];

    // -------------------------------------------------------------------------
    // Addressed-byte / addressed-halfword mux
    // -------------------------------------------------------------------------
    logic [7:0]  sel_byte;
    logic [15:0] sel_half;

    always_comb begin
        case (AddrLSB)
            2'b00:   sel_byte = rd_b0;
            2'b01:   sel_byte = rd_b1;
            2'b10:   sel_byte = rd_b2;
            default: sel_byte = rd_b3;
        endcase

        if (addr_bit1 == 1'b0)
            sel_half = rd_h0;
        else
            sel_half = rd_h1;
    end

    // Sign-bit aliases for sign-extension (avoid constant selects inside always_comb)
    logic sel_byte_msb, sel_half_msb;
    assign sel_byte_msb = sel_byte[7];
    assign sel_half_msb = sel_half[15];

    // -------------------------------------------------------------------------
    // Store / Load output logic
    // -------------------------------------------------------------------------
    always_comb begin
        // Deterministic defaults
        WriteData  = 32'b0;
        ByteEnable = 4'b0000;
        LoadData   = 32'b0;

        // ==== STORE (MemRW == 01) ============================================
        if (MemRW == 2'b01) begin
            case (Funct3)

                // SB – place lowest byte of StoreData at addressed byte lane
                3'b000: begin
                    case (AddrLSB)
                        2'b00: begin ByteEnable = 4'b0001; WriteData = {24'b0,  sd_b0        }; end
                        2'b01: begin ByteEnable = 4'b0010; WriteData = {16'b0,  sd_b0,  8'b0}; end
                        2'b10: begin ByteEnable = 4'b0100; WriteData = { 8'b0,  sd_b0, 16'b0}; end
                        default: begin ByteEnable = 4'b1000; WriteData = {       sd_b0, 24'b0}; end
                    endcase
                end

                // SH – place lowest halfword of StoreData at addressed halfword lane
                3'b001: begin
                    if (addr_bit1 == 1'b0) begin
                        ByteEnable = 4'b0011;
                        WriteData  = {16'b0, sd_h0};
                    end else begin
                        ByteEnable = 4'b1100;
                        WriteData  = {sd_h0, 16'b0};
                    end
                end

                // SW – full 32-bit word
                3'b010: begin
                    ByteEnable = 4'b1111;
                    WriteData  = StoreData;
                end

                // Unsupported → defaults already set above
                default: begin
                    ByteEnable = 4'b0000;
                    WriteData  = 32'b0;
                end

            endcase
        end

        // ==== LOAD (MemRW == 10) =============================================
        if (MemRW == 2'b10) begin
            case (Funct3)
                3'b000: LoadData = {{24{sel_byte_msb}}, sel_byte};   // LB  sign-extend
                3'b001: LoadData = {{16{sel_half_msb}}, sel_half};  // LH  sign-extend
                3'b010: LoadData = ReadData;                        // LW  full word
                3'b100: LoadData = {24'b0, sel_byte};               // LBU zero-extend
                3'b101: LoadData = {16'b0, sel_half};               // LHU zero-extend
                default: LoadData = 32'b0;
            endcase
        end

    end // always_comb

endmodule
