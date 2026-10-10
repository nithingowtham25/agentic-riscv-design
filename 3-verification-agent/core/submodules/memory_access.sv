// memory_access.sv: PLACEHOLDER STUB. Replace this file with the memory_access.sv you generated in Assignment 2.
// memory_access.sv: Keep the ports exactly as-is (the pipeline instantiates this module by these names).
// memory_access.sv: As shipped, the outputs are 0 -> loads/stores are wrong until you drop in your Assignment 2
// memory_access.sv: memory_access.
module memory_access(
    input  logic [1:0]  MemRW,
    input  logic [2:0]  Funct3,
    input  logic [1:0]  AddrLSB,
    input  logic [31:0] StoreData, ReadData,
    output logic [31:0] WriteData,
    output logic [3:0]  ByteEnable,
    output logic [31:0] LoadData
);
    // TODO: replace this whole file with your Assignment 2 memory_access.
    assign WriteData  = 32'b0;
    assign ByteEnable = 4'b0;
    assign LoadData   = 32'b0;
endmodule
