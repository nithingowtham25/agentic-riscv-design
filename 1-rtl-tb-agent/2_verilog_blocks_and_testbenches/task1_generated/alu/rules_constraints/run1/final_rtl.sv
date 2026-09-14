module alu (
    input  logic [31:0] A,
    input  logic [31:0] B,
    input  logic [2:0]  ALUSelect,
    input  logic        SubArith,
    output logic [31:0] ALUResult,
    output logic [31:0] Sum
);

    logic signed [31:0] A_signed;
    logic signed [31:0] B_signed;

    assign A_signed = A;
    assign B_signed = B;

    always_comb begin
        // Independent sum output: add when SubArith=0, subtract when SubArith=1
        if (SubArith) begin
            Sum = A - B;
        end else begin
            Sum = A + B;
        end

        // Default assignment to avoid unintended latches
        ALUResult = 32'h00000000;

        case (ALUSelect)
            3'b000: begin
                // ADD / SUB
                ALUResult = Sum;
            end

            3'b001: begin
                // SLL
                ALUResult = A << B[4:0];
            end

            3'b010: begin
                // SLT (valid when SubArith=1 per spec table)
                ALUResult = (A_signed < B_signed) ? 32'h00000001 : 32'h00000000;
            end

            3'b011: begin
                // SLTU (valid when SubArith=1 per spec table)
                ALUResult = (A < B) ? 32'h00000001 : 32'h00000000;
            end

            3'b100: begin
                // XOR
                ALUResult = A ^ B;
            end

            3'b101: begin
                // SRL / SRA
                if (SubArith) begin
                    ALUResult = A_signed >>> B[4:0];
                end else begin
                    ALUResult = A >> B[4:0];
                end
            end

            3'b110: begin
                // OR
                ALUResult = A | B;
            end

            3'b111: begin
                // AND
                ALUResult = A & B;
            end

            default: begin
                ALUResult = 32'h00000000;
            end
        endcase
    end

endmodule