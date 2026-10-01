module pc_unit (
    input  logic        clk,
    input  logic        reset,
    input  logic        PCSrc,
    input  logic [31:0] PCTarget,
    output logic [31:0] PC,
    output logic [31:0] PCPlus4
);

assign PCPlus4 = PC + 32'd4;

always_ff @(posedge clk) begin
    if (reset)
        PC <= 32'h00000000;
    else if (PCSrc)
        PC <= PCTarget;
    else
        PC <= PCPlus4;
end

endmodule
