`timescale 1ns/1ps
module datapath_tb;
logic clk=0,reset=1;logic[31:0]Instr,ReadData;logic[31:0]PC,DataAdr,WriteData;logic[3:0]ByteEnable;logic MemRead,MemWrite,IllegalInstr;
logic[31:0] imem[0:255];logic[31:0] dmem[0:255];string prog;integer exp_sig,max_cycles,i,cycles=0;localparam SIG_ADDR=32'h00000100;
datapath dut(.*);assign Instr=imem[PC[9:2]];assign ReadData=dmem[DataAdr[9:2]];
always #5 clk=~clk;
always @(negedge clk) begin
 if(MemWrite) begin
  if(ByteEnable[0]) dmem[DataAdr[9:2]][7:0]   <= WriteData[7:0];
  if(ByteEnable[1]) dmem[DataAdr[9:2]][15:8]  <= WriteData[15:8];
  if(ByteEnable[2]) dmem[DataAdr[9:2]][23:16] <= WriteData[23:16];
  if(ByteEnable[3]) dmem[DataAdr[9:2]][31:24] <= WriteData[31:24];
  if(DataAdr==SIG_ADDR && ByteEnable==4'b1111) begin
   if(WriteData===exp_sig[31:0]) begin $display("PASS signature=%08h cycles=%0d",WriteData,cycles);$finish(0);end
   else begin $display("FAIL signature got=%08h expected=%08h",WriteData,exp_sig);$finish(1);end
  end
 end
end
always @(posedge clk) begin if(!reset) begin cycles<=cycles+1;if(cycles>=max_cycles)begin $display("FAIL timeout PC=%08h",PC);$finish(1);end end end
initial begin for(i=0;i<256;i=i+1)begin imem[i]=32'h00000013;dmem[i]=0;end
 if(!$value$plusargs("PROGRAM=%s",prog))begin $display("ERROR +PROGRAM required");$finish(2);end if(!$value$plusargs("EXPECT=%h",exp_sig))begin $display("ERROR +EXPECT required");$finish(2);end if(!$value$plusargs("MAX_CYCLES=%d",max_cycles))max_cycles=100;
 $readmemh(prog,imem); repeat(2)@(posedge clk); reset<=0; end
endmodule
