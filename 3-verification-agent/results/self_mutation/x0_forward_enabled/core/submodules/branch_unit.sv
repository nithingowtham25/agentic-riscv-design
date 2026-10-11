module branch_unit (
    input  logic [31:0] A,
    input  logic [31:0] B,
    input  logic [2:0]  Funct3,
    input  logic        Branch,
    input  logic        Jump,
    output logic        BranchCond,
    output logic        PCSrc
);

always_comb begin
    BranchCond = 1'b0;
    case (Funct3)
        3'b000: BranchCond = (A == B);
        3'b001: BranchCond = (A != B);
        3'b100: BranchCond = ($signed(A) < $signed(B));
        3'b101: BranchCond = ($signed(A) >= $signed(B));
        3'b110: BranchCond = (A < B);
        3'b111: BranchCond = (A >= B);
        default: BranchCond = 1'b0;
    endcase
end

always_comb begin
    PCSrc = Jump || (Branch && BranchCond);
end

endmodule
