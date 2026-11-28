// memory_access.sv
// RV32I load/store data-formatting unit.
// Implements the Assignment 2 specification: little-endian, 32-bit memory
// interface with byte-enable steering for stores and sign/zero extension for
// loads.  Purely combinational; no latches.

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

    // ---------------------------------------------------------------------------
    // Byte/halfword lane selectors (used by loads)
    // ---------------------------------------------------------------------------
    logic [7:0]  sel_byte;
    logic [15:0] sel_half;

    always_comb begin
        // -----------------------------------------------------------------------
        // Deterministic defaults (spec §Deterministic Defaults)
        // -----------------------------------------------------------------------
        WriteData  = 32'b0;
        ByteEnable = 4'b0000;
        LoadData   = 32'b0;

        // -----------------------------------------------------------------------
        // Select the addressed byte from ReadData (little-endian)
        // -----------------------------------------------------------------------
        case (AddrLSB)
            2'b00:   sel_byte = ReadData[7:0];
            2'b01:   sel_byte = ReadData[15:8];
            2'b10:   sel_byte = ReadData[23:16];
            default: sel_byte = ReadData[31:24];   // 2'b11
        endcase

        // -----------------------------------------------------------------------
        // Select the addressed halfword from ReadData
        // AddrLSB[1]==0 → lower half, AddrLSB[1]==1 → upper half
        // -----------------------------------------------------------------------
        if (AddrLSB[1] == 1'b0)
            sel_half = ReadData[15:0];
        else
            sel_half = ReadData[31:16];

        // -----------------------------------------------------------------------
        // STORE path  (MemRW == 2'b01)
        // -----------------------------------------------------------------------
        if (MemRW == 2'b01) begin
            case (Funct3)
                // SB – place LSB of StoreData into the addressed byte lane
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

                // SH – place lower 16 bits of StoreData into the addressed
                //      halfword lane (only AddrLSB[1] is relevant for alignment)
                3'b001: begin
                    if (AddrLSB[1] == 1'b0) begin
                        ByteEnable = 4'b0011;
                        WriteData  = {16'b0, StoreData[15:0]};
                    end else begin
                        ByteEnable = 4'b1100;
                        WriteData  = {StoreData[15:0], 16'b0};
                    end
                end

                // SW – full 32-bit word
                3'b010: begin
                    ByteEnable = 4'b1111;
                    WriteData  = StoreData;
                end

                // All other Funct3 values → default (ByteEnable=0, WriteData=0)
                default: begin
                    ByteEnable = 4'b0000;
                    WriteData  = 32'b0;
                end
            endcase
        end

        // -----------------------------------------------------------------------
        // LOAD path  (MemRW == 2'b10)
        // -----------------------------------------------------------------------
        if (MemRW == 2'b10) begin
            case (Funct3)
                3'b000: LoadData = {{24{sel_byte[7]}}, sel_byte};          // LB
                3'b001: LoadData = {{16{sel_half[15]}}, sel_half};         // LH
                3'b010: LoadData = ReadData;                                // LW
                3'b100: LoadData = {24'b0, sel_byte};                      // LBU
                3'b101: LoadData = {16'b0, sel_half};                      // LHU
                default: LoadData = 32'b0;
            endcase
        end

    end // always_comb

endmodule
