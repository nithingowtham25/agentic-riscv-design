`timescale 1ns/1ps

module alu_tb;

    logic [31:0] A;
    logic [31:0] B;
    logic [2:0]  ALUSelect;
    logic        SubArith;
    logic [31:0] ALUResult;
    logic [31:0] Sum;

    alu dut (
        .A(A),
        .B(B),
        .ALUSelect(ALUSelect),
        .SubArith(SubArith),
        .ALUResult(ALUResult),
        .Sum(Sum)
    );

    string vector_file;
    integer fd;
    integer rc;
    integer total;
    integer passed;
    integer failed;

    integer test_id;
    integer category_id;
    integer sel_tmp;
    integer sub_tmp;
    logic [31:0] a_tmp;
    logic [31:0] b_tmp;
    logic [31:0] expected_result;
    logic [31:0] expected_sum;

    initial begin
        A = '0;
        B = '0;
        ALUSelect = '0;
        SubArith = '0;
        total = 0;
        passed = 0;
        failed = 0;

        if (!$value$plusargs("VECTORS=%s", vector_file)) begin
            vector_file = "vectors/sample/alu_sample.txt";
        end

        fd = $fopen(vector_file, "r");
        if (fd == 0) begin
            $display("ERROR: could not open vector file: %s", vector_file);
            $finish(2);
        end

        $display("============================================================");
        $display("Assignment 1 RV32I ALU Testbench");
        $display("Vectors: %s", vector_file);
        $display("============================================================");

        while (!$feof(fd)) begin
            rc = $fscanf(
                fd,
                "%d %d %b %d %h %h %h %h\n",
                test_id,
                category_id,
                sel_tmp,
                sub_tmp,
                a_tmp,
                b_tmp,
                expected_result,
                expected_sum
            );

            if (rc == 8) begin
                A          = a_tmp;
                B          = b_tmp;
                ALUSelect  = sel_tmp[2:0];
                SubArith   = sub_tmp[0];
                #1;

                total = total + 1;

                if ((ALUResult === expected_result) && (Sum === expected_sum)) begin
                    passed = passed + 1;
                end else begin
                    failed = failed + 1;
                    $display(
                        "FAIL test=%0d category=%0d select=%03b sub=%0d A=%08h B=%08h | ALUResult got=%08h exp=%08h | Sum got=%08h exp=%08h",
                        test_id, category_id, ALUSelect, SubArith, A, B,
                        ALUResult, expected_result, Sum, expected_sum
                    );
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
