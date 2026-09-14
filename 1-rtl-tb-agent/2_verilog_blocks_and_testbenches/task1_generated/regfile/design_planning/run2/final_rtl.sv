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

    // Analysis:
    // 1. Inputs/outputs:
    //    - clk   : 1-bit clock
    //    - reset : 1-bit synchronous-to-negedge reset
    //    - we3   : 1-bit write enable
    //    - a1/a2 : 5-bit read addresses
    //    - a3    : 5-bit write address
    //    - wd3   : 32-bit write data
    //    - rd1/rd2 : 32-bit read data outputs
    //
    // 2. Required operations:
    //    - 32 x 32-bit integer register file
    //    - Two combinational read ports
    //    - One write port on falling edge of clk
    //    - Reset sampled on falling edge; reset clears x1..x31
    //    - x0 is hardwired to zero:
    //         * reads of address 0 return 0
    //         * writes to address 0 are ignored
    //
    // 3. Corner cases:
    //    - reset has priority over write on negedge
    //    - we3=0 -> no write
    //    - a3=0 with we3=1 -> ignore write, x0 remains zero
    //    - reads of a1=0 or a2=0 always return 32'h00000000
    //    - no asynchronous reset behavior
    //
    // 4. Logic partitioning:
    //    - Sequential logic:
    //         * register array update on negedge clk
    //         * reset clearing on negedge clk
    //    - Combinational logic:
    //         * rd1/rd2 muxing from register array with x0 forced to zero
    //
    // 5. RTL structure:
    //    - Internal array regs[31:0] of 32-bit logic
    //    - always_ff @(negedge clk) for reset/write behavior
    //    - always_comb for the two read ports

    logic [31:0] regs [31:0];
    integer i;

    always_ff @(negedge clk) begin
        if (reset) begin
            regs[0] <= 32'h00000000;
            for (i = 1; i < 32; i = i + 1) begin
                regs[i] <= 32'h00000000;
            end
        end else begin
            // Keep x0 hardwired to zero.
            regs[0] <= 32'h00000000;

            if (we3 && (a3 != 5'd0)) begin
                regs[a3] <= wd3;
            end
        end
    end

    always_comb begin
        rd1 = (a1 == 5'd0) ? 32'h00000000 : regs[a1];
        rd2 = (a2 == 5'd0) ? 32'h00000000 : regs[a2];
    end

endmodule