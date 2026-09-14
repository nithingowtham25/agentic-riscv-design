`timescale 1ns/1ps

module controller_tb;

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

    string vector_file;
    integer fd;
    integer rc;
    integer total;
    integer passed;
    integer failed;

    integer test_id;
    integer category_id;
    logic [31:0] instr_tmp;
    integer exp_RegWriteD;
    integer exp_ImmSrcD;
    integer exp_ALUSrcAD;
    integer exp_ALUSrcBD;
    integer exp_MemRWD;
    integer exp_ResultSrcD;
    integer exp_BranchD;
    integer exp_JumpD;
    integer exp_ALUResultSrcD;
    integer exp_ALUSelectD;
    integer exp_SubArithD;
    integer exp_IllegalInstrD;

    initial begin
        InstrD = 32'b0;
        total = 0;
        passed = 0;
        failed = 0;

        if (!$value$plusargs("VECTORS=%s", vector_file))
            vector_file = "vectors/sample/controller_sample.txt";

        fd = $fopen(vector_file, "r");
        if (fd == 0) begin
            $display("ERROR: could not open vector file: %s", vector_file);
            $finish(2);
        end

        $display("============================================================");
        $display("Assignment 1 RV32I Controller Testbench");
        $display("Vectors: %s", vector_file);
        $display("============================================================");

        while (!$feof(fd)) begin
            rc = $fscanf(
                fd,
                "%d %d %h %d %b %d %d %b %b %d %d %d %b %d %d\n",
                test_id,
                category_id,
                instr_tmp,
                exp_RegWriteD,
                exp_ImmSrcD,
                exp_ALUSrcAD,
                exp_ALUSrcBD,
                exp_MemRWD,
                exp_ResultSrcD,
                exp_BranchD,
                exp_JumpD,
                exp_ALUResultSrcD,
                exp_ALUSelectD,
                exp_SubArithD,
                exp_IllegalInstrD
            );

            if (rc == 15) begin
                InstrD = instr_tmp;
                #1;
                total = total + 1;

                if ((RegWriteD     === exp_RegWriteD[0])     &&
                    (ImmSrcD       === exp_ImmSrcD[2:0])     &&
                    (ALUSrcAD      === exp_ALUSrcAD[0])      &&
                    (ALUSrcBD      === exp_ALUSrcBD[0])      &&
                    (MemRWD        === exp_MemRWD[1:0])      &&
                    (ResultSrcD    === exp_ResultSrcD[2:0])  &&
                    (BranchD       === exp_BranchD[0])       &&
                    (JumpD         === exp_JumpD[0])         &&
                    (ALUResultSrcD === exp_ALUResultSrcD[0]) &&
                    (ALUSelectD    === exp_ALUSelectD[2:0])  &&
                    (SubArithD     === exp_SubArithD[0])     &&
                    (IllegalInstrD === exp_IllegalInstrD[0])) begin
                    passed = passed + 1;
                end else begin
                    failed = failed + 1;
                    $display("FAIL test=%0d category=%0d Instr=%08h", test_id, category_id, InstrD);
                    $display("  RegWriteD     got=%0d exp=%0d", RegWriteD, exp_RegWriteD);
                    $display("  ImmSrcD       got=%03b exp=%03b", ImmSrcD, exp_ImmSrcD);
                    $display("  ALUSrcAD      got=%0d exp=%0d", ALUSrcAD, exp_ALUSrcAD);
                    $display("  ALUSrcBD      got=%0d exp=%0d", ALUSrcBD, exp_ALUSrcBD);
                    $display("  MemRWD        got=%02b exp=%02b", MemRWD, exp_MemRWD);
                    $display("  ResultSrcD    got=%03b exp=%03b", ResultSrcD, exp_ResultSrcD);
                    $display("  BranchD       got=%0d exp=%0d", BranchD, exp_BranchD);
                    $display("  JumpD         got=%0d exp=%0d", JumpD, exp_JumpD);
                    $display("  ALUResultSrcD got=%0d exp=%0d", ALUResultSrcD, exp_ALUResultSrcD);
                    $display("  ALUSelectD    got=%03b exp=%03b", ALUSelectD, exp_ALUSelectD);
                    $display("  SubArithD     got=%0d exp=%0d", SubArithD, exp_SubArithD);
                    $display("  IllegalInstrD got=%0d exp=%0d", IllegalInstrD, exp_IllegalInstrD);
                end
            end else if (rc != -1) begin
                $display("ERROR: malformed vector file near test %0d (fscanf returned %0d)", total + 1, rc);
                $fclose(fd);
                $finish(3);
            end
        end

        $fclose(fd);

        $display("------------------------------------------------------------");
        $display("Passed: %0d", passed);
        $display("Failed: %0d", failed);
        $display("Total : %0d", total);
        if (total > 0)
            $display("Score : %0.2f%%", (100.0 * passed) / total);
        $display("------------------------------------------------------------");

        if (failed == 0 && total > 0) begin
            $display("PASS");
            $finish(0);
        end else begin
            $display("FAIL");
            $finish(1);
        end
    end

endmodule
