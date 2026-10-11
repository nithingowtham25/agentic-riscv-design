// assertions_template.sv: STARTER for your assertion checker. Rename/copy this to results/assertions.sv
// assertions_template.sv: and fill in the assertions. The module MUST be named `student_assertions` and
// assertions_template.sv: MUST keep exactly these ports - it is bound into the core by name when evaluated.
//
// IMPORTANT: use IMMEDIATE assertions inside a clocked block, e.g.
//     always @(posedge clk) if (!reset)
//         assert (<your condition>) else $display("ASSERT_FAIL <your_name> ...");
// Icarus Verilog (-g2012) does NOT support concurrent `assert property (...)`. On a violation, print a
// line beginning with "ASSERT_FAIL" so you (and the evaluation) can see which invariant failed. Your
// assertions must be SILENT on the correct core and FIRE only when an invariant is actually violated.
//
// The ports below give you a view into the pipeline. You do not have to use all of them.
module student_assertions(
    input logic        clk,
    input logic        reset,
    // Decode-stage register read: source addresses and the values actually read from the register file.
    input logic [4:0]  Rs1D,
    input logic [4:0]  Rs2D,
    input logic [31:0] rd1D,
    input logic [31:0] rd2D,
    // Execute-stage forwarding selects + their source-register ids.
    input logic [1:0]  ForwardAE,   // 00 none / 10 from Memory stage / 01 from Writeback stage
    input logic [1:0]  ForwardBE,
    input logic [4:0]  Rs1E,
    input logic [4:0]  Rs2E,
    // In-flight producers that forwarding may source from (Memory and Writeback stages).
    input logic        RegWriteM,
    input logic [4:0]  RdM,
    input logic        RegWriteW,
    input logic [4:0]  RdW
);

    // TODO: write your invariant assertions here. See docs/required_invariants.md for the required set.
    // Example shape (replace with a real invariant):
    // always @(posedge clk) if (!reset)
    //     assert (/* something that must always hold */)
    //     else $display("ASSERT_FAIL my_invariant_name");

endmodule
