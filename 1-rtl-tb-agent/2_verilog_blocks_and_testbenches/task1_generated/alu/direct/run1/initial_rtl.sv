module alu (
    input  logic [31:0] A,
    input  logic [31:0] B,
    input  logic [2:0]  ALUSelect,
    input  logic        SubArith,
    output logic [31:0] ALUResult,
    output logic [31:0] Sum
);

    logic [4:0] shamt;

    always_comb begin
        shamt = B[4:0];

        // Independent sum output: add when SubArith=0, subtract when SubArith=1
        if (SubArith) begin
            Sum = A - B;
        end else begin
            Sum = A + B;
        end

        // Default to zero for unspecified ALUSelect/SubArith combinations
        ALUResult = 32'h0000_0000;

        unique case (ALUSelect)
            3'b000: begin
                // ADD / SUB
                ALUResult = Sum;
            end

            3'b001: begin
                // SLL (defined for SubArith=0)
                if (!SubArith)
                    ALUResult = A << shamt;
            end

            3'b010: begin
                // SLT (defined for SubArith=1)
                if (SubArith)
                    ALUResult = ($signed(A) < $signed(B)) ? 32'h0000_0001 : 32'h0000_0000;
            end

            3'b011: begin
                // SLTU (defined for SubArith=1)
                if (SubArith)
                    ALUResult = (A < B) ? 32'h0000_0001 : 32'h0000_0000;
            end

            3'b100: begin
                // XOR (defined for SubArith=0)
                if (!SubArith)
                    ALUResult = A ^ B;
            end

            3'b101: begin
                // SRL / SRA
                if (SubArith)
                    ALUResult = $signed(A) >>> shamt;
                else
                    ALUResult = A >> shamt;
            end

            3'b110: begin
                // OR (defined for SubArith=0)
                if (!SubArith)
                    ALUResult = A | B;
            end

            3'b111: begin
                // AND (defined for SubArith=0)
                if (!SubArith)
                    ALUResult = A & B;
            end

            default: begin
                ALUResult = 32'h0000_0000;
            end
        endcase
    end

endmodule