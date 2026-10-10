// controller.sv: PLACEHOLDER STUB. Replace this file with the controller.sv you generated in Assignment 1.
// controller.sv: Keep the ports exactly as-is (the pipeline instantiates this module by these names).
// controller.sv: As shipped, all control signals are 0 -> wrong results until you drop in your Assignment 1 controller.
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
    // TODO: replace this whole file with your Assignment 1 controller.
    assign RegWriteD     = 1'b0;
    assign ImmSrcD       = 3'b0;
    assign ALUSrcAD      = 1'b0;
    assign ALUSrcBD      = 1'b0;
    assign MemRWD        = 2'b0;
    assign ResultSrcD    = 3'b0;
    assign BranchD       = 1'b0;
    assign JumpD         = 1'b0;
    assign ALUResultSrcD = 1'b0;
    assign ALUSelectD    = 3'b0;
    assign SubArithD     = 1'b0;
    assign IllegalInstrD = 1'b0;
endmodule
