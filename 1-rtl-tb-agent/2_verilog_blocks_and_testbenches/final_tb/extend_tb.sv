module tb_extend;

  logic [31:7] InstrD;
  logic [2:0]  ImmSrcD;
  logic [31:0] ImmExtD;

  integer tests_passed;
  integer tests_failed;
  integer tests_total;

  extend dut (
    .InstrD(InstrD),
    .ImmSrcD(ImmSrcD),
    .ImmExtD(ImmExtD)
  );

  function automatic [31:0] exp_imm(
    input logic [31:7] instr,
    input logic [2:0]  src
  );
    begin
      case (src)
        3'b000: exp_imm = {{20{instr[31]}}, instr[31:20]};
        3'b001: exp_imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
        3'b010: exp_imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
        3'b011: exp_imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
        3'b100: exp_imm = {instr[31:12], 12'b0};
        default: exp_imm = 32'hxxxxxxxx;
      endcase
    end
  endfunction

  task automatic run_test(
    input [255:0] name,
    input logic [31:7] instr,
    input logic [2:0]  src
  );
    reg [31:0] expected;
    begin
      InstrD   = instr;
      ImmSrcD  = src;
      expected = exp_imm(instr, src);
      #1;
      tests_total = tests_total + 1;
      if (ImmExtD === expected) begin
        tests_passed = tests_passed + 1;
      end else begin
        tests_failed = tests_failed + 1;
        $display("FAIL: %0s src=%03b instr=0x%h expected=0x%08h actual=0x%08h",
                 name, src, instr, expected, ImmExtD);
      end
    end
  endtask

  initial begin
    tests_passed = 0;
    tests_failed = 0;
    tests_total  = 0;

    InstrD  = '0;
    ImmSrcD = 3'b000;
    #1;

    // I-type tests
    run_test("I-type -1 sample", 25'hFFF0000, 3'b000);
    run_test("I-type zero",      25'h0000000, 3'b000);
    run_test("I-type max pos",   25'h7FF0000, 3'b000);
    run_test("I-type min neg",   25'h8000000, 3'b000);

    // S-type tests
    run_test("S-type zero",      25'h0000000, 3'b001);
    run_test("S-type +2047",     {7'b0111111, 13'b0, 5'b11111}, 3'b001);
    run_test("S-type -2048",     {7'b1000000, 13'b0, 5'b00000}, 3'b001);
    run_test("S-type -1",        {7'b1111111, 13'b0, 5'b11111}, 3'b001);

    // B-type tests, including fragmented bit placements and sign extension
    run_test("B-type +8 sample",  {1'b0, 6'b000000, 13'b0, 4'b0100, 1'b0}, 3'b010);
    run_test("B-type -4 sample",  {1'b1, 6'b111111, 13'b0, 4'b1110, 1'b1}, 3'b010);
    run_test("B-type +4094",      {1'b0, 6'b111111, 13'b0, 4'b1111, 1'b1}, 3'b010);
    run_test("B-type -4096",      {1'b1, 6'b000000, 13'b0, 4'b0000, 1'b0}, 3'b010);
    run_test("B-type bit11 from instr7", {1'b0, 6'b000000, 13'b0, 4'b0000, 1'b1}, 3'b010);

    // J-type tests, including fragmented bit11 from InstrD[20]
    run_test("J-type zero",       25'h0000000, 3'b011);
    run_test("J-type bit11 only", {1'b0, 11'b0, 1'b1, 10'b0, 2'b00}, 3'b011);
    run_test("J-type +2",         {1'b0, 11'b0, 1'b0, 10'b0000000001, 2'b00}, 3'b011);
    run_test("J-type -2",         {1'b1, 11'b11111111_11, 1'b1, 10'b1111111111, 2'b00}, 3'b011);
    run_test("J-type max pos",    {1'b0, 8'hFF, 1'b1, 10'h3FF, 5'b0}, 3'b011);

    // U-type tests
    run_test("U-type sample",     25'hABCDE00, 3'b100);
    run_test("U-type zero",       25'h0000000, 3'b100);
    run_test("U-type all ones",   25'hFFFFF00, 3'b100);
    run_test("U-type sign bit set", {1'b1, 19'h00000, 5'b0}, 3'b100);

    $display("TESTS_PASSED: %0d", tests_passed);
    $display("TESTS_FAILED: %0d", tests_failed);
    $display("TESTS_TOTAL: %0d", tests_total);
    if (tests_failed == 0)
      $display("RESULT: PASS");
    else
      $display("RESULT: FAIL");

    $finish;
  end

endmodule