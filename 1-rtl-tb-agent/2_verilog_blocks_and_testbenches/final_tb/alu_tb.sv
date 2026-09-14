module tb_alu;

    logic [31:0] A;
    logic [31:0] B;
    logic [2:0]  ALUSelect;
    logic        SubArith;
    logic [31:0] ALUResult;
    logic [31:0] Sum;

    integer tests_passed;
    integer tests_failed;
    integer tests_total;

    alu dut (
        .A(A),
        .B(B),
        .ALUSelect(ALUSelect),
        .SubArith(SubArith),
        .ALUResult(ALUResult),
        .Sum(Sum)
    );

    function automatic [31:0] exp_sum(
        input [31:0] a,
        input [31:0] b,
        input        sub
    );
        begin
            if (sub)
                exp_sum = a - b;
            else
                exp_sum = a + b;
        end
    endfunction

    function automatic [31:0] exp_alu(
        input [31:0] a,
        input [31:0] b,
        input [2:0]  sel,
        input        sub
    );
        begin
            case (sel)
                3'b000: exp_alu = sub ? (a - b) : (a + b);
                3'b001: exp_alu = a << b[4:0];
                3'b010: exp_alu = ($signed(a) < $signed(b)) ? 32'h00000001 : 32'h00000000;
                3'b011: exp_alu = (a < b) ? 32'h00000001 : 32'h00000000;
                3'b100: exp_alu = a ^ b;
                3'b101: exp_alu = sub ? ($signed(a) >>> b[4:0]) : (a >> b[4:0]);
                3'b110: exp_alu = a | b;
                3'b111: exp_alu = a & b;
                default: exp_alu = 32'hxxxxxxxx;
            endcase
        end
    endfunction

    task automatic run_test(
        input [31:0] a,
        input [31:0] b,
        input [2:0]  sel,
        input        sub,
        input [255:0] name
    );
        reg [31:0] expected_result;
        reg [31:0] expected_sum;
        begin
            A = a;
            B = b;
            ALUSelect = sel;
            SubArith = sub;
            #1;

            expected_result = exp_alu(a, b, sel, sub);
            expected_sum    = exp_sum(a, b, sub);

            tests_total = tests_total + 1;
            if ((ALUResult !== expected_result) || (Sum !== expected_sum)) begin
                tests_failed = tests_failed + 1;
                $display("FAIL: %0s", name);
                $display("  Inputs: A=0x%08h B=0x%08h ALUSelect=%03b SubArith=%0d", a, b, sel, sub);
                $display("  Expected: ALUResult=0x%08h Sum=0x%08h", expected_result, expected_sum);
                $display("  Actual  : ALUResult=0x%08h Sum=0x%08h", ALUResult, Sum);
            end else begin
                tests_passed = tests_passed + 1;
            end
        end
    endtask

    initial begin
        tests_passed = 0;
        tests_failed = 0;
        tests_total  = 0;

        A = 32'd0;
        B = 32'd0;
        ALUSelect = 3'd0;
        SubArith = 1'b0;

        run_test(32'h0000000A, 32'h00000003, 3'b000, 1'b0, "ADD sample");
        run_test(32'h0000000A, 32'h00000003, 3'b000, 1'b1, "SUB sample");
        run_test(32'hFFFFFFFF, 32'h00000001, 3'b010, 1'b1, "SLT signed true sample");
        run_test(32'hFFFFFFFF, 32'h00000001, 3'b011, 1'b1, "SLTU unsigned false sample");
        run_test(32'h0000000F, 32'h0000001F, 3'b001, 1'b0, "SLL by 31 sample");

        run_test(32'hFFFFFFFF, 32'h00000001, 3'b000, 1'b0, "ADD wraparound");
        run_test(32'h00000000, 32'h00000001, 3'b000, 1'b1, "SUB wraparound");

        run_test(32'h12345678, 32'h00000020, 3'b001, 1'b0, "SLL uses B[4:0], shift 32->0");
        run_test(32'h87654321, 32'h00000024, 3'b101, 1'b0, "SRL uses B[4:0], shift 36->4");
        run_test(32'h80000001, 32'h0000001F, 3'b101, 1'b0, "SRL by 31 logical");

        run_test(32'h80000000, 32'h7FFFFFFF, 3'b010, 1'b1, "SLT signed true minint < maxint");
        run_test(32'h80000000, 32'h7FFFFFFF, 3'b011, 1'b1, "SLTU unsigned false");
        run_test(32'h00000005, 32'h00000005, 3'b010, 1'b1, "SLT equal false");
        run_test(32'h00000005, 32'h00000005, 3'b011, 1'b1, "SLTU equal false");

        run_test(32'hA5A5F00F, 32'h5A5A0FF0, 3'b100, 1'b0, "XOR pattern");
        run_test(32'hA5A50000, 32'h0F0FF0F0, 3'b110, 1'b0, "OR pattern");
        run_test(32'hFFFF0000, 32'h0F0FF0F0, 3'b111, 1'b0, "AND pattern");

        run_test(32'h33333333, 32'h11111111, 3'b100, 1'b0, "Sum independent of XOR result when SubArith=0");

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