module tb_controller;

  logic [31:0] InstrD;
  logic        RegWriteD;
  logic [2:0]  ImmSrcD;
  logic        ALUSrcAD;
  logic        ALUSrcBD;
  logic [1:0]  MemRWD;
  logic [2:0]  ResultSrcD;
  logic        BranchD;
  logic        JumpD;
  logic        ALUResultSrcD;
  logic [2:0]  ALUSelectD;
  logic        SubArithD;
  logic        IllegalInstrD;

  integer tests_passed;
  integer tests_failed;
  integer tests_total;

  controller dut (
    .InstrD(InstrD),
    .RegWriteD(RegWriteD),
    .ImmSrcD(ImmSrcD),
    .ALUSrcAD(ALUSrcAD),
    .ALUSrcBD(ALUSrcBD),
    .MemRWD(MemRWD),
    .ResultSrcD(ResultSrcD),
    .BranchD(BranchD),
    .JumpD(JumpD),
    .ALUResultSrcD(ALUResultSrcD),
    .ALUSelectD(ALUSelectD),
    .SubArithD(SubArithD),
    .IllegalInstrD(IllegalInstrD)
  );

  task automatic check_case(
    input [255:0] name,
    input [31:0] instr,
    input exp_RegWriteD,
    input [2:0] exp_ImmSrcD,
    input exp_ALUSrcAD,
    input exp_ALUSrcBD,
    input [1:0] exp_MemRWD,
    input [2:0] exp_ResultSrcD,
    input exp_BranchD,
    input exp_JumpD,
    input exp_ALUResultSrcD,
    input [2:0] exp_ALUSelectD,
    input exp_SubArithD,
    input exp_IllegalInstrD
  );
    begin
      InstrD = instr;
      #1;
      tests_total = tests_total + 1;
      if ((RegWriteD      === exp_RegWriteD)     &&
          (ImmSrcD        === exp_ImmSrcD)       &&
          (ALUSrcAD       === exp_ALUSrcAD)      &&
          (ALUSrcBD       === exp_ALUSrcBD)      &&
          (MemRWD         === exp_MemRWD)        &&
          (ResultSrcD     === exp_ResultSrcD)    &&
          (BranchD        === exp_BranchD)       &&
          (JumpD          === exp_JumpD)         &&
          (ALUResultSrcD  === exp_ALUResultSrcD) &&
          (ALUSelectD     === exp_ALUSelectD)    &&
          (SubArithD      === exp_SubArithD)     &&
          (IllegalInstrD  === exp_IllegalInstrD)) begin
        tests_passed = tests_passed + 1;
      end else begin
        tests_failed = tests_failed + 1;
        $display("FAIL: %0s instr=%h", name, instr);
        $display("  Expected: RegWrite=%0d ImmSrc=%03b ALUSrcA=%0d ALUSrcB=%0d MemRW=%02b ResultSrc=%03b Branch=%0d Jump=%0d ALUResultSrc=%0d ALUSelect=%03b SubArith=%0d Illegal=%0d",
                 exp_RegWriteD, exp_ImmSrcD, exp_ALUSrcAD, exp_ALUSrcBD, exp_MemRWD, exp_ResultSrcD,
                 exp_BranchD, exp_JumpD, exp_ALUResultSrcD, exp_ALUSelectD, exp_SubArithD, exp_IllegalInstrD);
        $display("  Actual  : RegWrite=%0d ImmSrc=%03b ALUSrcA=%0d ALUSrcB=%0d MemRW=%02b ResultSrc=%03b Branch=%0d Jump=%0d ALUResultSrc=%0d ALUSelect=%03b SubArith=%0d Illegal=%0d",
                 RegWriteD, ImmSrcD, ALUSrcAD, ALUSrcBD, MemRWD, ResultSrcD,
                 BranchD, JumpD, ALUResultSrcD, ALUSelectD, SubArithD, IllegalInstrD);
      end
    end
  endtask

  initial begin
    tests_passed = 0;
    tests_failed = 0;
    tests_total  = 0;
    InstrD = 32'h00000013;

    // R-type legal
    check_case("ADD x1,x2,x3",
               {7'b0000000,5'd3,5'd2,3'b000,5'd1,7'b0110011},
               1'b1, 3'b000, 1'b0, 1'b0, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b000, 1'b0, 1'b0);

    check_case("SUB x1,x2,x3",
               {7'b0100000,5'd3,5'd2,3'b000,5'd1,7'b0110011},
               1'b1, 3'b000, 1'b0, 1'b0, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b000, 1'b1, 1'b0);

    check_case("SRA x1,x2,x3",
               {7'b0100000,5'd3,5'd2,3'b101,5'd1,7'b0110011},
               1'b1, 3'b000, 1'b0, 1'b0, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b101, 1'b1, 1'b0);

    check_case("SLTU x1,x2,x3",
               {7'b0000000,5'd3,5'd2,3'b011,5'd1,7'b0110011},
               1'b1, 3'b000, 1'b0, 1'b0, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b011, 1'b1, 1'b0);

    // I-type ALU legal
    check_case("ADDI x1,x2,5",
               {12'd5,5'd2,3'b000,5'd1,7'b0010011},
               1'b1, 3'b000, 1'b0, 1'b1, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b000, 1'b0, 1'b0);

    check_case("SRAI x1,x2,3",
               {7'b0100000,5'd3,5'd2,3'b101,5'd1,7'b0010011},
               1'b1, 3'b000, 1'b0, 1'b1, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b101, 1'b1, 1'b0);

    // Load/store
    check_case("LW x1,0(x2)",
               {12'd0,5'd2,3'b010,5'd1,7'b0000011},
               1'b1, 3'b000, 1'b0, 1'b1, 2'b10, 3'b001, 1'b0, 1'b0, 1'b0, 3'b000, 1'b0, 1'b0);

    check_case("SW x1,0(x2)",
               {7'd0,5'd1,5'd2,3'b010,5'd0,7'b0100011},
               1'b0, 3'b001, 1'b0, 1'b1, 2'b01, 3'b000, 1'b0, 1'b0, 1'b0, 3'b000, 1'b0, 1'b0);

    // PC-relative / upper / control flow
    check_case("AUIPC x1,imm20",
               {20'h12345,5'd1,7'b0010111},
               1'b1, 3'b100, 1'b1, 1'b1, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b000, 1'b0, 1'b0);

    check_case("LUI x1,imm20",
               {20'hABCDE,5'd1,7'b0110111},
               1'b1, 3'b100, 1'b0, 1'b1, 2'b00, 3'b000, 1'b0, 1'b0, 1'b1, 3'b000, 1'b0, 1'b0);

    check_case("BEQ x1,x2,off",
               {7'b0000000,5'd2,5'd1,3'b000,5'd0,7'b1100011},
               1'b0, 3'b010, 1'b1, 1'b1, 2'b00, 3'b000, 1'b1, 1'b0, 1'b0, 3'b000, 1'b0, 1'b0);

    check_case("JALR x1,x2,0",
               {12'd0,5'd2,3'b000,5'd1,7'b1100111},
               1'b1, 3'b000, 1'b0, 1'b1, 2'b00, 3'b000, 1'b0, 1'b1, 1'b1, 3'b000, 1'b0, 1'b0);

    check_case("JAL x1,off",
               {20'h00010,5'd1,7'b1101111},
               1'b1, 3'b011, 1'b1, 1'b1, 2'b00, 3'b000, 1'b0, 1'b1, 1'b1, 3'b000, 1'b0, 1'b0);

    // Illegal opcode
    check_case("Illegal opcode 1111111",
               32'h0000007F,
               1'b0, 3'b000, 1'b0, 1'b0, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1);

    // Illegal load funct3
    check_case("Illegal load funct3=011",
               {12'd0,5'd2,3'b011,5'd1,7'b0000011},
               1'b0, 3'b000, 1'b0, 1'b0, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1);

    // Illegal store funct3
    check_case("Illegal store funct3=011",
               {7'd0,5'd1,5'd2,3'b011,5'd0,7'b0100011},
               1'b0, 3'b000, 1'b0, 1'b0, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1);

    // Illegal branch funct3
    check_case("Illegal branch funct3=010",
               {7'b0000000,5'd2,5'd1,3'b010,5'd0,7'b1100011},
               1'b0, 3'b000, 1'b0, 1'b0, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1);

    // Illegal JALR funct3
    check_case("Illegal JALR funct3=001",
               {12'd0,5'd2,3'b001,5'd1,7'b1100111},
               1'b0, 3'b000, 1'b0, 1'b0, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1);

    // Illegal R-type funct7
    check_case("Illegal R-type funct7",
               {7'b0000001,5'd3,5'd2,3'b000,5'd1,7'b0110011},
               1'b0, 3'b000, 1'b0, 1'b0, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1);

    // Illegal shift-immediate encoding
    check_case("Illegal shift-immediate encoding",
               {7'b0010000,5'd3,5'd2,3'b101,5'd1,7'b0010011},
               1'b0, 3'b000, 1'b0, 1'b0, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1);

    // Other extension/system instruction illegal
    check_case("ECALL illegal",
               32'h00000073,
               1'b0, 3'b000, 1'b0, 1'b0, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1);

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