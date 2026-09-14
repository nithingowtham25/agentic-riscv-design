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

        case (opcode)
            7'b0000011: begin
                RegWriteD  = 1'b1;
                ImmSrcD    = 3'b000;
                ALUSrcAD   = 1'b0;
                ALUSrcBD   = 1'b1;
                MemRWD     = 2'b10;
                ResultSrcD = 3'b001;
                ALUSelectD = 3'b000;

                case (funct3)
                    3'b000, 3'b001, 3'b010, 3'b100, 3'b101: IllegalInstrD = 1'b0;
                    default: IllegalInstrD = 1'b1;
                endcase
            end

            7'b0010011: begin
                RegWriteD  = 1'b1;
                ImmSrcD    = 3'b000;
                ALUSrcAD   = 1'b0;
                ALUSrcBD   = 1'b1;
                MemRWD     = 2'b00;
                ResultSrcD = 3'b000;
                ALUSelectD = funct3;

                case (funct3)
                    3'b000,
                    3'b010,
                    3'b011,
                    3'b100,
                    3'b110,
                    3'b111: begin
                        SubArithD     = (funct3 == 3'b010) || (funct3 == 3'b011);
                        IllegalInstrD = 1'b0;
                    end

                    3'b001: begin
                        if (funct7 == 7'b0000000) begin
                            SubArithD     = 1'b0;
                            IllegalInstrD = 1'b0;
                        end
                        else begin
                            IllegalInstrD = 1'b1;
                        end
                    end

                    3'b101: begin
                        if (funct7 == 7'b0000000) begin
                            SubArithD     = 1'b0;
                            IllegalInstrD = 1'b0;
                        end
                        else if (funct7 == 7'b0100000) begin
                            SubArithD     = 1'b1;
                            IllegalInstrD = 1'b0;
                        end
                        else begin
                            IllegalInstrD = 1'b1;
                        end
                    end

                    default: IllegalInstrD = 1'b1;
                endcase
            end

            7'b0010111: begin
                RegWriteD  = 1'b1;
                ImmSrcD    = 3'b100;
                ALUSrcAD   = 1'b1;
                ALUSrcBD   = 1'b1;
                MemRWD     = 2'b00;
                ResultSrcD = 3'b000;
                ALUSelectD = 3'b000;
            end

            7'b0100011: begin
                RegWriteD  = 1'b0;
                ImmSrcD    = 3'b001;
                ALUSrcAD   = 1'b0;
                ALUSrcBD   = 1'b1;
                MemRWD     = 2'b01;
                ResultSrcD = 3'b000;
                ALUSelectD = 3'b000;

                case (funct3)
                    3'b000, 3'b001, 3'b010: IllegalInstrD = 1'b0;
                    default: IllegalInstrD = 1'b1;
                endcase
            end

            7'b0110011: begin
                RegWriteD  = 1'b1;
                ImmSrcD    = 3'b000;
                ALUSrcAD   = 1'b0;
                ALUSrcBD   = 1'b0;
                MemRWD     = 2'b00;
                ResultSrcD = 3'b000;
                ALUSelectD = funct3;

                case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0000000) begin
                            SubArithD     = 1'b0;
                            IllegalInstrD = 1'b0;
                        end
                        else if (funct7 == 7'b0100000) begin
                            SubArithD     = 1'b1;
                            IllegalInstrD = 1'b0;
                        end
                        else begin
                            IllegalInstrD = 1'b1;
                        end
                    end

                    3'b001: begin
                        if (funct7 == 7'b0000000) begin
                            SubArithD     = 1'b0;
                            IllegalInstrD = 1'b0;
                        end
                        else begin
                            IllegalInstrD = 1'b1;
                        end
                    end

                    3'b010: begin
                        if (funct7 == 7'b0000000) begin
                            SubArithD     = 1'b1;
                            IllegalInstrD = 1'b0;
                        end
                        else begin
                            IllegalInstrD = 1'b1;
                        end
                    end

                    3'b011: begin
                        if (funct7 == 7'b0000000) begin
                            SubArithD     = 1'b1;
                            IllegalInstrD = 1'b0;
                        end
                        else begin
                            IllegalInstrD = 1'b1;
                        end
                    end

                    3'b100: begin
                        if (funct7 == 7'b0000000) begin
                            SubArithD     = 1'b0;
                            IllegalInstrD = 1'b0;
                        end
                        else begin
                            IllegalInstrD = 1'b1;
                        end
                    end

                    3'b101: begin
                        if (funct7 == 7'b0000000) begin
                            SubArithD     = 1'b0;
                            IllegalInstrD = 1'b0;
                        end
                        else if (funct7 == 7'b0100000) begin
                            SubArithD     = 1'b1;
                            IllegalInstrD = 1'b0;
                        end
                        else begin
                            IllegalInstrD = 1'b1;
                        end
                    end

                    3'b110: begin
                        if (funct7 == 7'b0000000) begin
                            SubArithD     = 1'b0;
                            IllegalInstrD = 1'b0;
                        end
                        else begin
                            IllegalInstrD = 1'b1;
                        end
                    end

                    3'b111: begin
                        if (funct7 == 7'b0000000) begin
                            SubArithD     = 1'b0;
                            IllegalInstrD = 1'b0;
                        end
                        else begin
                            IllegalInstrD = 1'b1;
                        end
                    end

                    default: IllegalInstrD = 1'b1;
                endcase
            end

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

            7'b1100011: begin
                RegWriteD  = 1'b0;
                ImmSrcD    = 3'b010;
                ALUSrcAD   = 1'b1;
                ALUSrcBD   = 1'b1;
                MemRWD     = 2'b00;
                ResultSrcD = 3'b000;
                BranchD    = 1'b1;
                ALUSelectD = 3'b000;

                case (funct3)
                    3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111: IllegalInstrD = 1'b0;
                    default: IllegalInstrD = 1'b1;
                endcase
            end

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

            default: begin
                IllegalInstrD = 1'b1;
            end
        endcase

        if (IllegalInstrD) begin
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
        end
    end

endmodule