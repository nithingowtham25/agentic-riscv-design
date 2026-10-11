// core_tb_assert.sv: Assertion-enabled processor testbench. Same memory model + signature protocol as
// core_tb.sv, but also binds YOUR student_assertions module into the core via hierarchical references
// (dut.<signal>). Prints the usual PASS/FAIL signature line AND "ASSERT_FAIL <name>" on any invariant
// violation. Used by `run.py --assertions ...` to check that your assertions stay SILENT on the correct
// core: if any ASSERT_FAIL prints here, your assertion is a false positive on correct RTL.
`timescale 1ns/1ps
module core_tb_assert;   // binds your student_assertions module into the core
    logic clk = 0, reset = 1;
    logic [31:0] InstrF, ReadData;
    logic [31:0] PCF, DataAdr, WriteData;
    logic [3:0]  ByteEnable;
    logic        MemRead, MemWrite, IllegalInstr;

    logic [31:0] imem[0:1023];
    logic [31:0] dmem[0:1023];
    string  prog;
    integer exp_sig, max_cycles, i, cycles = 0;
    localparam SIG_ADDR = 32'h00000100;

    datapath_pipelined dut(
        .clk(clk), .reset(reset), .InstrF(InstrF), .ReadData(ReadData),
        .PCF(PCF), .DataAdr(DataAdr), .WriteData(WriteData), .ByteEnable(ByteEnable),
        .MemRead(MemRead), .MemWrite(MemWrite), .IllegalInstr(IllegalInstr));

    assign InstrF   = imem[PCF[11:2]];
    assign ReadData = dmem[DataAdr[11:2]];

    // Bind the reference assertions to the DUT's RAW internal signals (hierarchical references). Passing
    // the true rd1D/rd2D (not a forced 0) means INV1 is a real check: a broken x0 read-mux shows through.
    student_assertions chk(
        .clk(clk), .reset(reset),
        .Rs1D(dut.Rs1D), .Rs2D(dut.Rs2D), .rd1D(dut.rd1D), .rd2D(dut.rd2D),
        .ForwardAE(dut.ForwardAE), .ForwardBE(dut.ForwardBE),
        .Rs1E(dut.Rs1E), .Rs2E(dut.Rs2E),
        .RegWriteM(dut.RegWriteM), .RdM(dut.RdM),
        .RegWriteW(dut.RegWriteW), .RdW(dut.RdW));

    always #5 clk = ~clk;

    always @(negedge clk) begin
        if (!reset && MemWrite) begin
            if (ByteEnable[0]) dmem[DataAdr[11:2]][7:0]   <= WriteData[7:0];
            if (ByteEnable[1]) dmem[DataAdr[11:2]][15:8]  <= WriteData[15:8];
            if (ByteEnable[2]) dmem[DataAdr[11:2]][23:16] <= WriteData[23:16];
            if (ByteEnable[3]) dmem[DataAdr[11:2]][31:24] <= WriteData[31:24];
            if (DataAdr == SIG_ADDR && ByteEnable == 4'b1111) begin
                if (WriteData === exp_sig[31:0])
                    $display("PASS signature=%08h cycles=%0d", WriteData, cycles);
                else
                    $display("FAIL signature got=%08h expected=%08h", WriteData, exp_sig);
                $finish;
            end
        end
    end

    always @(posedge clk) begin
        if (!reset) begin
            cycles <= cycles + 1;
            if (cycles >= max_cycles) begin $display("FAIL timeout PC=%08h", PCF); $finish; end
        end
    end

    initial begin
        for (i = 0; i < 1024; i = i + 1) begin imem[i] = 32'h00000013; dmem[i] = 0; end
        if (!$value$plusargs("PROGRAM=%s", prog)) begin $display("FAIL no +PROGRAM"); $finish; end
        if (!$value$plusargs("EXPECT=%h", exp_sig)) begin $display("FAIL no +EXPECT"); $finish; end
        if (!$value$plusargs("MAX_CYCLES=%d", max_cycles)) max_cycles = 2000;
        $readmemh(prog, imem);
        repeat (2) @(posedge clk);
        reset <= 0;
    end
endmodule
