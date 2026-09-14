`timescale 1ns/1ps

module regfile_tb;

    logic        clk;
    logic        reset;
    logic        we3;
    logic [4:0]  a1;
    logic [4:0]  a2;
    logic [4:0]  a3;
    logic [31:0] wd3;
    logic [31:0] rd1;
    logic [31:0] rd2;

    regfile dut (
        .clk(clk),
        .reset(reset),
        .we3(we3),
        .a1(a1),
        .a2(a2),
        .a3(a3),
        .wd3(wd3),
        .rd1(rd1),
        .rd2(rd2)
    );

    string vector_file;
    integer fd;
    integer rc;
    integer total;
    integer passed;
    integer failed;

    integer test_id;
    integer category_id;
    integer edge_tmp;
    integer reset_tmp;
    integer we3_tmp;
    integer a1_tmp;
    integer a2_tmp;
    integer a3_tmp;
    logic [31:0] wd3_tmp;
    logic [31:0] expected_rd1;
    logic [31:0] expected_rd2;

    task automatic return_clock_high;
        begin
            // Move to high level without creating an additional falling edge.
            if (clk !== 1'b1) begin
                #1 clk = 1'b1;
                #1;
            end
        end
    endtask

    initial begin
        clk = 1'b1;
        reset = 1'b0;
        we3 = 1'b0;
        a1 = '0;
        a2 = '0;
        a3 = '0;
        wd3 = '0;
        total = 0;
        passed = 0;
        failed = 0;

        if (!$value$plusargs("VECTORS=%s", vector_file))
            vector_file = "vectors/sample/regfile_sample.txt";

        fd = $fopen(vector_file, "r");
        if (fd == 0) begin
            $display("ERROR: could not open vector file: %s", vector_file);
            $finish(2);
        end

        $display("============================================================");
        $display("Assignment 1 RV32I Register File Testbench");
        $display("Vectors: %s", vector_file);
        $display("============================================================");

        while (!$feof(fd)) begin
            rc = $fscanf(
                fd,
                "%d %d %d %d %d %d %d %d %h %h %h\n",
                test_id,
                category_id,
                edge_tmp,
                reset_tmp,
                we3_tmp,
                a1_tmp,
                a2_tmp,
                a3_tmp,
                wd3_tmp,
                expected_rd1,
                expected_rd2
            );

            if (rc == 11) begin
                // Every transaction starts with clk high.
                return_clock_high();

                reset = reset_tmp[0];
                we3   = we3_tmp[0];
                a1    = a1_tmp[4:0];
                a2    = a2_tmp[4:0];
                a3    = a3_tmp[4:0];
                wd3   = wd3_tmp;

                #1;

                if (edge_tmp != 0) begin
                    // Generate exactly one falling edge.
                    clk = 1'b0;
                    #1;
                end

                // Check reads after the optional state transition.
                total = total + 1;

                if ((rd1 === expected_rd1) && (rd2 === expected_rd2)) begin
                    passed = passed + 1;
                end else begin
                    failed = failed + 1;
                    $display(
                        "FAIL test=%0d category=%0d edge=%0d reset=%0d we3=%0d a1=%0d a2=%0d a3=%0d wd3=%08h | rd1 got=%08h exp=%08h | rd2 got=%08h exp=%08h",
                        test_id, category_id, edge_tmp, reset, we3, a1, a2, a3, wd3,
                        rd1, expected_rd1, rd2, expected_rd2
                    );
                end
            end else if (rc != -1) begin
                $display("ERROR: malformed transaction file near test %0d (fscanf returned %0d)", total + 1, rc);
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
