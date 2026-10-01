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

    // 32 x 32-bit integer register file storage.
    // x0 is hardwired to zero by logic below.
    logic [31:0] rf [31:0];
    integer i;

    // Sequential logic:
    // - sampled on FALLING edge of clk
    // - reset has priority over write
    // - x0 remains zero
    always_ff @(negedge clk) begin
        if (reset) begin
            rf[0] <= 32'h00000000;
            for (i = 1; i < 32; i = i + 1) begin
                rf[i] <= 32'h00000000;
            end
        end else begin
            // Keep x0 hardwired to zero even across attempted writes
            rf[0] <= 32'h00000000;

            if (we3 && (a3 != 5'd0)) begin
                rf[a3] <= wd3;
            end
        end
    end

    // Combinational read port 1
    always_comb begin
        if (a1 == 5'd0) begin
            rd1 = 32'h00000000;
        end else begin
            rd1 = rf[a1];
        end
    end

    // Combinational read port 2
    always_comb begin
        if (a2 == 5'd0) begin
            rd2 = 32'h00000000;
        end else begin
            rd2 = rf[a2];
        end
    end

endmodule