module pc_unit (
    input  logic        clk,
    input  logic        reset,
    input  logic        PCSrc,
    input  logic [31:0] PCTarget,
    output logic [31:0] PC,
    output logic [31:0] PCPlus4
);

always_comb begin
    PCPlus4 = PC + 32'd2;   // INJECTED BUG: RV32I advances by 4, not 2
end

always_ff @(posedge clk) begin
    if (reset) begin
        PC <= 32'h00000000;
    end else if (PCSrc) begin
        PC <= PCTarget;
    end else begin
        PC <= PCPlus4;
    end
end

endmodule
