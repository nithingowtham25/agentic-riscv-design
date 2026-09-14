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
    reg fail;
    begin
      fail = 0;
      InstrD = instr;
      #1;
      tests_total = tests_total + 1;

      if (RegWriteD !== exp_RegWriteD) begin
        $display("FAIL %0s: RegWriteD expected=%0b actual=%0b instr=%h", name, exp_RegWriteD, RegWriteD, instr);
        fail = 1;
      end
      if (ImmSrcD !== exp_ImmSrcD) begin
        $display("FAIL %0s: ImmSrcD expected=%03b actual=%03b instr=%h", name, exp_ImmSrcD, ImmSrcD, instr);
        fail = 1;
      end
      if (ALUSrcAD !== exp_ALUSrcAD) begin
        $display("FAIL %0s: ALUSrcAD expected=%0b actual=%0b instr=%h", name, exp_ALUSrcAD, ALUSrcAD, instr);
        fail = 1;
      end
      if (ALUSrcBD !== exp_ALUSrcBD) begin
        $display("FAIL %0s: ALUSrcBD expected=%0b actual=%0b instr=%h", name, exp_ALUSrcBD, ALUSrcBD, instr);
        fail = 1;
      end
      if (MemRWD !== exp_MemRWD) begin
        $display("FAIL %0s: MemRWD expected=%02b actual=%02b instr=%h", name, exp_MemRWD, MemRWD, instr);
        fail = 1;
      end
      if (ResultSrcD !== exp_ResultSrcD) begin
        $display("FAIL %0s: ResultSrcD expected=%03b actual=%03b instr=%h", name, exp_ResultSrcD, ResultSrcD, instr);
        fail = 1;
      end
      if (BranchD !== exp_BranchD) begin
        $display("FAIL %0s: BranchD expected=%0b actual=%0b instr=%h", name, exp_BranchD, BranchD, instr);
        fail = 1;
      end
      if (JumpD !== exp_JumpD) begin
        $display("FAIL %0s: JumpD expected=%0b actual=%0b instr=%h", name, exp_JumpD, JumpD, instr);
        fail = 1;
      end
      if (ALUResultSrcD !== exp_ALUResultSrcD) begin
        $display("FAIL %0s: ALUResultSrcD expected=%0b actual=%0b instr=%h", name, exp_ALUResultSrcD, ALUResultSrcD, instr);
        fail = 1;
      end
      if (ALUSelectD !== exp_ALUSelectD) begin
        $display("FAIL %0s: ALUSelectD expected=%03b actual=%03b instr=%h", name, exp_ALUSelectD, ALUSelectD, instr);
        fail = 1;
      end
      if (SubArithD !== exp_SubArithD) begin
        $display("FAIL %0s: SubArithD expected=%0b actual=%0b instr=%h", name, exp_SubArithD, SubArithD, instr);
        fail = 1;
      end
      if (IllegalInstrD !== exp_IllegalInstrD) begin
        $display("FAIL %0s: IllegalInstrD expected=%0b actual=%0b instr=%h", name, exp_IllegalInstrD, IllegalInstrD, instr);
        fail = 1;
      end

      if (!exp_IllegalInstrD) begin
        if (IllegalInstrD !== 1'b0) begin
          fail = 1;
        end
      end else begin
        if (RegWriteD !== 1'b0 || MemRWD !== 2'b00 || BranchD !== 1'b0 || JumpD !== 1'b0) begin
          $display("FAIL %0s: illegal instruction side effects not suppressed instr=%h RegWriteD=%0b MemRWD=%02b BranchD=%0b JumpD=%0b",
                   name, instr, RegWriteD, MemRWD, BranchD, JumpD);
          fail = 1;
        end
      end

      if (fail) begin
        tests_failed = tests_failed + 1;
      end else begin
        tests_passed = tests_passed + 1;
      end
    end
  endtask

  initial begin
    tests_passed = 0;
    tests_failed = 0;
    tests_total  = 0;
    InstrD = 32'h0;

    // R-type ADD: add x1,x2,x3
    check_case("R_ADD",
               {7'b0000000, 5'd3, 5'd2, 3'b000, 5'd1, 7'b0110011},
               1'b1, 3'b000, 1'b0, 1'b0, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b000, 1'b0, 1'b0);

    // R-type SUB: sub x1,x2,x3
    check_case("R_SUB",
               {7'b0100000, 5'd3, 5'd2, 3'b000, 5'd1, 7'b0110011},
               1'b1, 3'b000, 1'b0, 1'b0, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b000, 1'b1, 1'b0);

    // R-type SRA
    check_case("R_SRA",
               {7'b0100000, 5'd3, 5'd2, 3'b101, 5'd1, 7'b0110011},
               1'b1, 3'b000, 1'b0, 1'b0, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b101, 1'b1, 1'b0);

    // R-type SLTU
    check_case("R_SLTU",
               {7'b0000000, 5'd3, 5'd2, 3'b011, 5'd1, 7'b0110011},
               1'b1, 3'b000, 1'b0, 1'b0, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b011, 1'b1, 1'b0);

    // I-type ADDI
    check_case("I_ADDI",
               {12'h123, 5'd2, 3'b000, 5'd1, 7'b0010011},
               1'b1, 3'b000, 1'b0, 1'b1, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b000, 1'b0, 1'b0);

    // I-type SRAI (legal shift immediate)
    check_case("I_SRAI",
               {7'b0100000, 5'd3, 5'd2, 3'b101, 5'd1, 7'b0010011},
               1'b1, 3'b000, 1'b0, 1'b1, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b101, 1'b1, 1'b0);

    // Load LW
    check_case("LW",
               {12'h000, 5'd2, 3'b010, 5'd1, 7'b0000011},
               1'b1, 3'b000, 1'b0, 1'b1, 2'b10, 3'b001, 1'b0, 1'b0, 1'b0, 3'b000, 1'b0, 1'b0);

    // Store SW
    check_case("SW",
               {7'b0000000, 5'd1, 5'd2, 3'b010, 5'd0, 7'b0100011},
               1'b0, 3'b001, 1'b0, 1'b1, 2'b01, 3'b000, 1'b0, 1'b0, 1'b0, 3'b000, 1'b0, 1'b0);

    // Branch BEQ
    check_case("BEQ",
               {7'b0000000, 5'd2, 5'd1, 3'b000, 5'd0, 7'b1100011},
               1'b0, 3'b010, 1'b1, 1'b1, 2'b00, 3'b000, 1'b1, 1'b0, 1'b0, 3'b000, 1'b0, 1'b0);

    // JALR
    check_case("JALR",
               {12'h004, 5'd2, 3'b000, 5'd1, 7'b1100111},
               1'b1, 3'b000, 1'b0, 1'b1, 2'b00, 3'b000, 1'b0, 1'b1, 1'b1, 3'b000, 1'b0, 1'b0);

    // JAL
    check_case("JAL",
               {20'h12345, 5'd1, 7'b1101111},
               1'b1, 3'b011, 1'b1, 1'b1, 2'b00, 3'b000, 1'b0, 1'b1, 1'b1, 3'b000, 1'b0, 1'b0);

    // AUIPC
    check_case("AUIPC",
               {20'hABCDE, 5'd1, 7'b0010111},
               1'b1, 3'b100, 1'b1, 1'b1, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b000, 1'b0, 1'b0);

    // LUI
    check_case("LUI",
               {20'h54321, 5'd1, 7'b0110111},
               1'b1, 3'b100, 1'b0, 1'b1, 2'b00, 3'b000, 1'b0, 1'b0, 1'b1, 3'b000, 1'b0, 1'b0);

    // Illegal opcode
    check_case("ILLEGAL_OPCODE",
               32'hFFFFFFFF,
               1'b0, 3'b000, 1'b0, 1'b0, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1);

    // Illegal load funct3
    check_case("ILLEGAL_LOAD_FUNCT3",
               {12'h000, 5'd2, 3'b111, 5'd1, 7'b0000011},
               1'b0, 3'b000, 1'b0, 1'b0, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1);

    // Illegal store funct3
    check_case("ILLEGAL_STORE_FUNCT3",
               {7'b0000000, 5'd1, 5'd2, 3'b011, 5'd0, 7'b0100011},
               1'b0, 3'b000, 1'b0, 1'b0, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1);

    // Illegal branch funct3
    check_case("ILLEGAL_BRANCH_FUNCT3",
               {7'b0000000, 5'd2, 5'd1, 3'b010, 5'd0, 7'b1100011},
               1'b0, 3'b000, 1'b0, 1'b0, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1);

    // Illegal JALR funct3 != 000
    check_case("ILLEGAL_JALR_FUNCT3",
               {12'h000, 5'd2, 3'b001, 5'd1, 7'b1100111},
               1'b0, 3'b000, 1'b0, 1'b0, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1);

    // Illegal R-type funct7
    check_case("ILLEGAL_R_FUNCT7",
               {7'b0000001, 5'd3, 5'd2, 3'b000, 5'd1, 7'b0110011},
               1'b0, 3'b000, 1'b0, 1'b0, 2'b00, 3'b000, 1'b0, 1'b0, 1'b0, 3'b000, 1'b0, 1'b1);

    // Illegal shift-immediate encoding (reserved funct7 for shift imm)
    check_case("ILLEGAL_SHIFT_IMM",
               {7'b0010000, 5'd3, 5'd2, 3'b101, 5'd1, 7'b0010011},
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