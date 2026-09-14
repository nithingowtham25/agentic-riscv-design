module alu (
    input  logic [31:0] A,
    input  logic [31:0] B,
    input  logic [2:0]  ALUSelect,
    input  logic        SubArith,
    output logic [31:0] ALUResult,
    output logic [31:0] Sum
);

    logic [4:0] shamt;

    assign shamt = B[4:0];
    assign Sum   = SubArith ? (A - B) : (A + B);

    always_comb begin
        unique case (ALUSelect)
            3'b000: ALUResult = Sum;
            3'b001: ALUResult = A << shamt;
            3'b010: ALUResult = (SubArith && ($signed(A) < $signed(B))) ? 32'h0000_0001 : 32'h0000_0000;
            3'b011: ALUResult = (SubArith && (A < B)) ? 32'h0000_0001 : 32'h0000_0000;
            3'b100: ALUResult = A ^ B;
            3'b101: ALUResult = SubArith ? ($signed({1'b0, A}) >>> shamt)[31:0] : (A >> shamt);
            3'b110: ALUResult = A | B;
            3'b111: ALUResult = A & B;
            default: ALUResult = 32'h0000_0000;
        endcase
    end

endmodule