module controller (
    input  logic [31:0] InstrD,
    output logic        RegWriteD,
    output logic [2:0]  ImmSrcD,
    output logic        ALUSrcAD,
    output logic        ALUSrcBD,
    output logic [1:0]  MemRWD,
    output logic [2:0]  ResultSrcD,
    output logic        BranchD,
    output logic        JumpD,
    output logic        ALUResultSrcD,
    output logic [2:0]  ALUSelectD,
    output logic        SubArithD,
    output logic        IllegalInstrD
);

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = InstrD[6:0];
    assign funct3 = InstrD[14:12];
    assign funct7 = InstrD[31:25];

    always_comb begin
        // Safe defaults
        RegWriteD      = 1'b0;
        ImmSrcD        = 3'b000;
        ALUSrcAD       = 1'b0;
        ALUSrcBD       = 1'b0;
        MemRWD         = 2'b00;
        ResultSrcD     = 3'b000;
        BranchD        = 1'b0;
        JumpD          = 1'b0;
        ALUResultSrcD  = 1'b0;
        ALUSelectD     = 3'b000;
        SubArithD      = 1'b0;
        IllegalInstrD  = 1'b0;

        unique case (opcode)
            // Load
            7'b0000011: begin
                RegWriteD  = 1'b1;
                ImmSrcD    = 3'b000;
                ALUSrcAD   = 1'b0;
                ALUSrcBD   = 1'b1;
                MemRWD     = 2'b10;
                ResultSrcD = 3'b001;
                ALUSelectD = 3'b000;

                // RV32I legal loads: LB, LH, LW, LBU, LHU
                unique case (funct3)
                    3'b000, 3'b001, 3'b010, 3'b100, 3'b101: IllegalInstrD = 1'b0;
                    default: begin
                        IllegalInstrD = 1'b1;
                    end
                endcase
            end

            // I-type ALU
            7'b0010011: begin
                RegWriteD  = 1'b1;
                ImmSrcD    = 3'b000;
                ALUSrcAD   = 1'b0;
                ALUSrcBD   = 1'b1;
                MemRWD     = 2'b00;
                ResultSrcD = 3'b000;
                ALUSelectD = funct3;

                unique case (funct3)
                    3'b000, // ADDI
                    3'b010, // SLTI
                    3'b011, // SLTIU
                    3'b100, // XORI
                    3'b110, // ORI
                    3'b111: begin // ANDI
                        SubArithD     = (funct3 == 3'b010) || (funct3 == 3'b011);
                        IllegalInstrD = 1'b0;
                    end

                    3'b001: begin // SLLI
                        if (funct7 == 7'b0000000) begin
                            SubArithD     = 1'b0;
                            IllegalInstrD = 1'b0;
                        end
                        else begin
                            IllegalInstrD = 1'b1;
                        end
                    end

                    3'b101: begin // SRLI/SRAI
                        if (funct7 == 7'b0000000) begin
                            SubArithD     = 1'b0; // SRLI
                            IllegalInstrD = 1'b0;
                        end
                        else if (funct7 == 7'b0100000) begin
                            SubArithD     = 1'b1; // SRAI
                            IllegalInstrD = 1'b0;
                        end
                        else begin
                            IllegalInstrD = 1'b1;
                        end
                    end

                    default: begin
                        IllegalInstrD = 1'b1;
                    end
                endcase
            end

            // AUIPC
            7'b0010111: begin
                RegWriteD  = 1'b1;
                ImmSrcD    = 3'b100;
                ALUSrcAD   = 1'b1;
                ALUSrcBD   = 1'b1;
                MemRWD     = 2'b00;
                ResultSrcD = 3'b000;
                ALUSelectD = 3'b000;
            end

            // Store
            7'b0100011: begin
                RegWriteD  = 1'b0;
                ImmSrcD    = 3'b001;
                ALUSrcAD   = 1'b0;
                ALUSrcBD   = 1'b1;
                MemRWD     = 2'b01;
                ResultSrcD = 3'b000;
                ALUSelectD = 3'b000;

                // RV32I legal stores: SB, SH, SW
                unique case (funct3)
                    3'b000, 3'b001, 3'b010: IllegalInstrD = 1'b0;
                    default: begin
                        IllegalInstrD = 1'b1;
                    end
                endcase
            end

            // R-type ALU
            7'b0110011: begin
                RegWriteD  = 1'b1;
                ImmSrcD    = 3'b000;
                ALUSrcAD   = 1'b0;
                ALUSrcBD   = 1'b0;
                MemRWD     = 2'b00;
                ResultSrcD = 3'b000;
                ALUSelectD = funct3;

                unique case (funct3)
                    3'b000: begin // ADD/SUB
                        if (funct7 == 7'b0000000) begin
                            SubArithD     = 1'b0; // ADD
                            IllegalInstrD = 1'b0;
                        end
                        else if (funct7 == 7'b0100000) begin
                            SubArithD     = 1'b1; // SUB
                            IllegalInstrD = 1'b0;
                        end
                        else begin
                            IllegalInstrD = 1'b1;
                        end
                    end

                    3'b001: begin // SLL
                        if (funct7 == 7'b0000000) begin
                            SubArithD     = 1'b0;
                            IllegalInstrD = 1'b0;
                        end
                        else begin
                            IllegalInstrD = 1'b1;
                        end
                    end

                    3'b010: begin // SLT
                        if (funct7 == 7'b0000000) begin
                            SubArithD     = 1'b1;
                            IllegalInstrD = 1'b0;
                        end
                        else begin
                            IllegalInstrD = 1'b1;
                        end
                    end

                    3'b011: begin // SLTU
                        if (funct7 == 7'b0000000) begin
                            SubArithD     = 1'b1;
                            IllegalInstrD = 1'b0;
                        end
                        else begin
                            IllegalInstrD = 1'b1;
                        end
                    end

                    3'b100: begin // XOR
                        if (funct7 == 7'b0000000) begin
                            SubArithD     = 1'b0;
                            IllegalInstrD = 1'b0;
                        end
                        else begin
                            IllegalInstrD = 1'b1;
                        end
                    end

                    3'b101: begin // SRL/SRA
                        if (funct7 == 7'b0000000) begin
                            SubArithD     = 1'b0; // SRL
                            IllegalInstrD = 1'b0;
                        end
                        else if (funct7 == 7'b0100000) begin
                            SubArithD     = 1'b1; // SRA
                            IllegalInstrD = 1'b0;
                        end
                        else begin
                            IllegalInstrD = 1'b1;
                        end
                    end

                    3'b110: begin // OR
                        if (funct7 == 7'b0000000) begin
                            SubArithD     = 1'b0;
                            IllegalInstrD = 1'b0;
                        end
                        else begin
                            IllegalInstrD = 1'b1;
                        end
                    end

                    3'b111: begin // AND
                        if (funct7 == 7'b0000000) begin
                            SubArithD     = 1'b0;
                            IllegalInstrD = 1'b0;
                        end
                        else begin
                            IllegalInstrD = 1'b1;
                        end
                    end

                    default: begin
                        IllegalInstrD = 1'b1;
                    end
                endcase
            end

            // LUI
            7'b0110111: begin
                RegWriteD      = 1'b1;
                ImmSrcD        = 3'b100;
                ALUSrcAD       = 1'b0;
                ALUSrcBD       = 1'b1;
                MemRWD         = 2'b00;
                ResultSrcD     = 3'b000;
                ALUResultSrcD  = 1'b1;
                ALUSelectD     = 3'b000;
            end

            // Branch
            7'b1100011: begin
                RegWriteD  = 1'b0;
                ImmSrcD    = 3'b010;
                ALUSrcAD   = 1'b1;
                ALUSrcBD   = 1'b1;
                MemRWD     = 2'b00;
                ResultSrcD = 3'b000;
                BranchD    = 1'b1;
                ALUSelectD = 3'b000;

                // RV32I legal branches: BEQ, BNE, BLT, BGE, BLTU, BGEU
                unique case (funct3)
                    3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111: IllegalInstrD = 1'b0;
                    default: begin
                        IllegalInstrD = 1'b1;
                    end
                endcase
            end

            // JALR
            7'b1100111: begin
                RegWriteD      = 1'b1;
                ImmSrcD        = 3'b000;
                ALUSrcAD       = 1'b0;
                ALUSrcBD       = 1'b1;
                MemRWD         = 2'b00;
                ResultSrcD     = 3'b000;
                JumpD          = 1'b1;
                ALUResultSrcD  = 1'b1;
                ALUSelectD     = 3'b000;

                if (funct3 != 3'b000) begin
                    IllegalInstrD = 1'b1;
                end
            end

            // JAL
            7'b1101111: begin
                RegWriteD      = 1'b1;
                ImmSrcD        = 3'b011;
                ALUSrcAD       = 1'b1;
                ALUSrcBD       = 1'b1;
                MemRWD         = 2'b00;
                ResultSrcD     = 3'b000;
                JumpD          = 1'b1;
                ALUResultSrcD  = 1'b1;
                ALUSelectD     = 3'b000;
            end

            // All other opcodes, including FENCE/FENCE.I/SYSTEM/CSR/extensions
            default: begin
                IllegalInstrD = 1'b1;
            end
        endcase

        // Suppress architecturally visible side effects on illegal instructions
        if (IllegalInstrD) begin
            RegWriteD = 1'b0;
            MemRWD    = 2'b00;
            BranchD   = 1'b0;
            JumpD     = 1'b0;
        end
    end

endmodule