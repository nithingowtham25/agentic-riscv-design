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

  function automatic [31:0] expected_imm(
    input logic [31:7] instr,
    input logic [2:0]  src
  );
    begin
      case (src)
        3'b000: expected_imm = {{20{instr[31]}}, instr[31:20]};                              // I
        3'b001: expected_imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};                // S
        3'b010: expected_imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}; // B
        3'b011: expected_imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0}; // J
        3'b100: expected_imm = {instr[31:12], 12'b0};                                        // U
        default: expected_imm = 32'hxxxxxxxx;
      endcase
    end
  endfunction

  task automatic run_test(
    input [255:0] name,
    input logic [31:7] instr,
    input logic [2:0]  src
  );
    logic [31:0] exp;
    begin
      InstrD  = instr;
      ImmSrcD = src;
      #1;
      exp = expected_imm(instr, src);
      tests_total = tests_total + 1;
      if (ImmExtD === exp) begin
        tests_passed = tests_passed + 1;
      end else begin
        tests_failed = tests_failed + 1;
        $display("FAIL: %0s src=%03b instr[31:7]=0x%07h expected=0x%08h actual=0x%08h",
                 name, src, instr, exp, ImmExtD);
      end
    end
  endtask

  initial begin
    tests_passed = 0;
    tests_failed = 0;
    tests_total  = 0;

    InstrD  = '0;
    ImmSrcD = '0;
    #1;

    // I-type tests
    run_test("I_type_neg1_sample", 25'hFFF0000, 3'b000);   // Instr[31:20]=0xFFF -> -1
    run_test("I_type_zero",        25'h0000000, 3'b000);
    run_test("I_type_pos_max",     25'h7FF0000, 3'b000);   // +2047
    run_test("I_type_neg_min",     25'h8000000, 3'b000);   // -2048

    // S-type tests
    run_test("S_type_zero",        25'h0000000, 3'b001);
    run_test("S_type_pos_2047",    25'h7E0008F, 3'b001);   // imm = 0x7FF
    run_test("S_type_neg1",        25'hFE0008F, 3'b001);   // imm = 0xFFF -> -1

    // B-type tests (fragmented layout, implicit bit0=0)
    run_test("B_type_plus8_sample", 25'h00000400, 3'b010); // imm = +8
    run_test("B_type_minus4_sample",25'hFE000E80, 3'b010); // imm = -4
    run_test("B_type_zero",         25'h00000000, 3'b010);
    run_test("B_type_plus4094",     25'h7E000F80, 3'b010); // max positive branch imm
    run_test("B_type_minus4096",    25'h80000000, 3'b010); // most negative branch imm

    // J-type tests (fragmented layout, implicit bit0=0)
    run_test("J_type_zero",         25'h00000000, 3'b011);
    run_test("J_type_plus2",        25'h00200000, 3'b011); // imm = +2
    run_test("J_type_minus2",       25'hFFFFF000, 3'b011); // imm = -2
    run_test("J_type_max_positive", 25'h7FFFF000, 3'b011); // max positive J imm
    run_test("J_type_min_negative", 25'h80000000, 3'b011); // most negative J imm

    // U-type tests
    run_test("U_type_sample",       25'hABCDE000, 3'b100); // -> 0xABCDE000
    run_test("U_type_zero",         25'h00000000, 3'b100);
    run_test("U_type_all_ones",     25'hFFFFF000, 3'b100);

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