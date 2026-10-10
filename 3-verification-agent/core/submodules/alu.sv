// alu.sv: PLACEHOLDER STUB. Replace this file with the alu.sv you generated in Assignment 1.
// alu.sv: The ports below must stay exactly as-is (the pipeline instantiates this module by these names).
// alu.sv: As shipped, every output is 0 -> the core will compute wrong results until you drop in your Assignment 1 alu.
module alu (
    input  logic [31:0] A,
    input  logic [31:0] B,
    input  logic [2:0]  ALUSelect,
    input  logic        SubArith,
    output logic [31:0] ALUResult,
    output logic [31:0] Sum
);
    // TODO: replace this whole file with your Assignment 1 alu.
    assign ALUResult = 32'b0;
    assign Sum       = 32'b0;
endmodule
