// core_tb.sv: Processor-level testbench for the pipelined RV32I core (Assignment 3).
// core_tb.sv: Harvard memories; a program runs to completion and stores a 32-bit signature to
// core_tb.sv: SIG_ADDR. The signature is compared to +EXPECT (computed by the reference ISS).
// core_tb.sv: Because the core is architecturally correct, the committed signature is independent
// core_tb.sv: of pipelining. Prints a single terminal PASS or FAIL line (self-checking convention).
`timescale 1ns/1ps
module core_tb;
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

    // Combinational instruction fetch and data read (word-indexed).
    assign InstrF   = imem[PCF[11:2]];
    assign ReadData = dmem[DataAdr[11:2]];

    always #5 clk = ~clk;

    // Synchronous store; a full-word store to SIG_ADDR ends the test with a signature check.
    always @(negedge clk) begin
        if (!reset && MemWrite) begin
            if (ByteEnable[0]) dmem[DataAdr[11:2]][7:0]   <= WriteData[7:0];
            if (ByteEnable[1]) dmem[DataAdr[11:2]][15:8]  <= WriteData[15:8];
            if (ByteEnable[2]) dmem[DataAdr[11:2]][23:16] <= WriteData[23:16];
            if (ByteEnable[3]) dmem[DataAdr[11:2]][31:24] <= WriteData[31:24];
            if (DataAdr == SIG_ADDR && ByteEnable == 4'b1111) begin
                if (WriteData === exp_sig[31:0]) begin
                    $display("PASS signature=%08h cycles=%0d", WriteData, cycles);
                    $finish;
                end else begin
                    $display("FAIL signature got=%08h expected=%08h", WriteData, exp_sig);
                    $finish;
                end
            end
        end
    end

    always @(posedge clk) begin
        if (!reset) begin
            cycles <= cycles + 1;
            if (cycles >= max_cycles) begin
                $display("FAIL timeout PC=%08h", PCF);
                $finish;
            end
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
