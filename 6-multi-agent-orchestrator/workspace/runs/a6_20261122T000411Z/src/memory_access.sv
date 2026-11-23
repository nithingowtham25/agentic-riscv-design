// memory_access.sv
// RV32I Data-Memory Formatting Unit
//
// Implements little-endian byte/halfword/word store lane placement and
// byte/halfword/word load extraction with sign or zero extension.
//
// Spec: workspace/specs/memory_access_spec.md
// Owner: RTL Agent (Assignment 6)

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

    // Internal temporaries for load extraction
    logic [7:0]  sel_byte;   // byte addressed by AddrLSB
    logic [15:0] sel_half;   // halfword addressed by AddrLSB[1]

    always_comb begin
        // ----------------------------------------------------------------
        // Deterministic defaults (spec §"Deterministic Defaults")
        // ----------------------------------------------------------------
        WriteData  = 32'b0;
        ByteEnable = 4'b0000;
        LoadData   = 32'b0;

        // ----------------------------------------------------------------
        // Load lane selection (independent of MemRW; used only when MemRW==10)
        // ----------------------------------------------------------------
        // Byte selection: little-endian byte addressed by AddrLSB
        case (AddrLSB)
            2'b00:   sel_byte = ReadData[7:0];
            2'b01:   sel_byte = ReadData[15:8];
            2'b10:   sel_byte = ReadData[23:16];
            default: sel_byte = ReadData[31:24];   // 2'b11
        endcase

        // Halfword selection: naturally aligned to bit [1] of address
        if (AddrLSB[1] == 1'b0)
            sel_half = ReadData[15:0];
        else
            sel_half = ReadData[31:16];

        // ----------------------------------------------------------------
        // Store path  (MemRW == 01)
        // ----------------------------------------------------------------
        if (MemRW == 2'b01) begin
            case (Funct3)
                // SB: replicate low byte into the addressed lane
                3'b000: begin
                    case (AddrLSB)
                        2'b00: begin
                            ByteEnable = 4'b0001;
                            WriteData  = {24'b0, StoreData[7:0]};
                        end
                        2'b01: begin
                            ByteEnable = 4'b0010;
                            WriteData  = {16'b0, StoreData[7:0], 8'b0};
                        end
                        2'b10: begin
                            ByteEnable = 4'b0100;
                            WriteData  = {8'b0, StoreData[7:0], 16'b0};
                        end
                        default: begin  // 2'b11
                            ByteEnable = 4'b1000;
                            WriteData  = {StoreData[7:0], 24'b0};
                        end
                    endcase
                end

                // SH: replicate low halfword into the addressed aligned lane
                3'b001: begin
                    if (AddrLSB[1] == 1'b0) begin
                        ByteEnable = 4'b0011;
                        WriteData  = {16'b0, StoreData[15:0]};
                    end else begin
                        ByteEnable = 4'b1100;
                        WriteData  = {StoreData[15:0], 16'b0};
                    end
                end

                // SW: full 32-bit write
                3'b010: begin
                    ByteEnable = 4'b1111;
                    WriteData  = StoreData;
                end

                // All other Funct3 encodings: keep defaults (ByteEnable=0)
                default: begin
                    ByteEnable = 4'b0000;
                    WriteData  = 32'b0;
                end
            endcase
        end // store path

        // ----------------------------------------------------------------
        // Load path  (MemRW == 10)
        // ----------------------------------------------------------------
        if (MemRW == 2'b10) begin
            case (Funct3)
                3'b000: LoadData = {{24{sel_byte[7]}}, sel_byte};          // LB  – sign extend
                3'b001: LoadData = {{16{sel_half[15]}}, sel_half};         // LH  – sign extend
                3'b010: LoadData = ReadData;                                // LW  – full word
                3'b100: LoadData = {24'b0, sel_byte};                      // LBU – zero extend
                3'b101: LoadData = {16'b0, sel_half};                      // LHU – zero extend
                default: LoadData = 32'b0;                                 // unused encodings
            endcase
        end // load path

    end // always_comb

endmodule
