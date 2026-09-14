module alu (
    input  logic [31:0] A,
    input  logic [31:0] B,
    input  logic [2:0]  ALUSelect,
    input  logic        SubArith,
    output logic [31:0] ALUResult,
    output logic [31:0] Sum
);

    // ------------------------------------------------------------------------
    // Design analysis
    // 1) Inputs/outputs
    //    - A, B        : 32-bit operands
    //    - ALUSelect   : 3-bit operation select
    //    - SubArith    : modifies arithmetic/compare/shift behavior as specified
    //    - ALUResult   : 32-bit selected ALU result
    //    - Sum         : independent 32-bit add/sub result
    //
    // 2) Required operations
    //    ALUSelect=000 : ADD if SubArith=0, SUB if SubArith=1
    //    ALUSelect=001 : SLL
    //    ALUSelect=010 : SLT  (used with SubArith=1 per spec)
    //    ALUSelect=011 : SLTU (used with SubArith=1 per spec)
    //    ALUSelect=100 : XOR
    //    ALUSelect=101 : SRL if SubArith=0, SRA if SubArith=1
    //    ALUSelect=110 : OR
    //    ALUSelect=111 : AND
    //
    // 3) Corner cases
    //    - No reset/clock exists.
    //    - Arithmetic is 32-bit modular wraparound.
    //    - Shift amount uses only B[4:0].
    //    - SLT compares signed values; SLTU compares unsigned values.
    //    - Arithmetic right shift must replicate sign bit of A.
    //    - Sum is always valid independent of ALUSelect:
    //         SubArith=0 => A+B
    //         SubArith=1 => A-B
    //
    // 4) Combinational vs sequential
    //    - Entire block is purely combinational.
    //    - No always_ff, no latches, no state.
    //
    // 5) RTL structure
    //    - Continuous assignment for Sum.
    //    - always_comb with unique case for ALUResult.
    // ------------------------------------------------------------------------

    logic [4:0] shamt;

    assign shamt = B[4:0];
    assign Sum   = SubArith ? (A - B) : (A + B);

    always_comb begin
        unique case (ALUSelect)
            3'b000: ALUResult = Sum;
            3'b001: ALUResult = A << shamt;
            3'b010: ALUResult = ($signed(A) < $signed(B)) ? 32'h0000_0001 : 32'h0000_0000;
            3'b011: ALUResult = (A < B) ? 32'h0000_0001 : 32'h0000_0000;
            3'b100: ALUResult = A ^ B;
            3'b101: ALUResult = SubArith ? ($signed(A) >>> shamt) : (A >> shamt);
            3'b110: ALUResult = A | B;
            3'b111: ALUResult = A & B;
            default: ALUResult = 32'h0000_0000;
        endcase
    end

endmodule