// regfile.sv: PLACEHOLDER STUB. Replace this file with the regfile.sv you generated in Assignment 1.
// regfile.sv: Keep the ports exactly as-is (the pipeline instantiates this module by these names).
// regfile.sv: As shipped, the read ports return 0 -> wrong results until you drop in your Assignment 1 regfile.
module regfile (
    input  logic        clk,
    input  logic        reset,
    input  logic        we3,
    input  logic [4:0]  a1,
    input  logic [4:0]  a2,
    input  logic [4:0]  a3,
    input  logic [31:0] wd3,
    output logic [31:0] rd1,
    output logic [31:0] rd2
);
    // TODO: replace this whole file with your Assignment 1 regfile.
    assign rd1 = 32'b0;
    assign rd2 = 32'b0;
endmodule
