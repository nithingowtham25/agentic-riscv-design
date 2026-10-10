// branch_unit.sv: PLACEHOLDER STUB. Replace this file with the branch_unit.sv you generated in Assignment 2.
// branch_unit.sv: Keep the ports exactly as-is (the pipeline instantiates this module by these names).
// branch_unit.sv: As shipped, the outputs are 0 -> branches/jumps never taken -> wrong results until you
// branch_unit.sv: drop in your Assignment 2 branch_unit.
module branch_unit(
    input  logic [31:0] A, B,
    input  logic [2:0]  Funct3,
    input  logic        Branch, Jump,
    output logic        BranchCond, PCSrc
);
    // TODO: replace this whole file with your Assignment 2 branch_unit.
    assign BranchCond = 1'b0;
    assign PCSrc      = 1'b0;
endmodule
