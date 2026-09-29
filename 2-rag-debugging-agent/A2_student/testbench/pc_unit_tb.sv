`timescale 1ns/1ps
module pc_unit_tb; logic clk,reset,PCSrc; logic[31:0]PCTarget,PC,PCPlus4; pc_unit dut(.*); string f; integer fd,rc,id,edg,rst,src,total=0,pass=0; logic[31:0]tgt,ePC,eP4;
initial begin clk=0;reset=0;PCSrc=0;PCTarget=0;if(!$value$plusargs("VECTORS=%s",f))f="vectors/sample/pc_unit_sample.txt";fd=$fopen(f,"r");
while(!$feof(fd))begin rc=$fscanf(fd,"%d %d %d %d %h %h %h\n",id,edg,rst,src,tgt,ePC,eP4);if(rc==7)begin reset=rst;PCSrc=src;PCTarget=tgt;#1;if(edg)begin clk=1;#1;clk=0;#1;end total++;if(PC===ePC&&PCPlus4===eP4)pass++;else $display("FAIL %0d PC=%h/%h PC+4=%h/%h",id,PC,ePC,PCPlus4,eP4);end end
$display("Passed: %0d Failed: %0d Total: %0d",pass,total-pass,total);if(pass==total)$finish(0);else $finish(1);end endmodule
