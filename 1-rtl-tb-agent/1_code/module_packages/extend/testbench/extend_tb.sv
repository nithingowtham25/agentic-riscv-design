`timescale 1ns/1ps

module extend_tb;

    logic [31:7] InstrD;
    logic [2:0]  ImmSrcD;
    logic [31:0] ImmExtD;

    extend dut (
        .InstrD(InstrD),
        .ImmSrcD(ImmSrcD),
        .ImmExtD(ImmExtD)
    );

    string vector_file;
    integer fd;
    integer rc;
    integer total;
    integer passed;
    integer failed;

    integer test_id;
    integer category_id;
    integer src_tmp;
    logic [24:0] instr_tmp;
    logic [31:0] expected_imm;

    initial begin
        InstrD = '0;
        ImmSrcD = '0;
        total = 0;
        passed = 0;
        failed = 0;

        if (!$value$plusargs("VECTORS=%s", vector_file))
            vector_file = "vectors/sample/extend_sample.txt";

        fd = $fopen(vector_file, "r");
        if (fd == 0) begin
            $display("ERROR: could not open vector file: %s", vector_file);
            $finish(2);
        end

        $display("============================================================");
        $display("Assignment 1 RV32I Immediate Extension Testbench");
        $display("Vectors: %s", vector_file);
        $display("============================================================");

        while (!$feof(fd)) begin
            rc = $fscanf(
                fd,
                "%d %d %b %h %h\n",
                test_id,
                category_id,
                src_tmp,
                instr_tmp,
                expected_imm
            );

            if (rc == 5) begin
                ImmSrcD = src_tmp[2:0];
                InstrD  = instr_tmp;
                #1;

                total = total + 1;

                if (ImmExtD === expected_imm) begin
                    passed = passed + 1;
                end else begin
                    failed = failed + 1;
                    $display(
                        "FAIL test=%0d category=%0d ImmSrcD=%03b InstrD[31:7]=%07h | got=%08h expected=%08h",
                        test_id, category_id, ImmSrcD, InstrD, ImmExtD, expected_imm
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
