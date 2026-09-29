# Bug: register x0 not hardwired to zero (RISC-V register file)

**Symptom:** reads of register x0 return whatever was last written, instead of 0.
In RISC-V, register x0 is architecturally **hardwired to zero** — writes are ignored
and reads always return 0.

**Cause:** the register file returns `reg_array[addr]` directly for the read ports,
without special-casing address 0.

**Fix:** force the read data to 0 when the read address is 0:

```verilog
assign rd_data1 = (rd_addr1 != 0) ? reg_file_arr[rd_addr1] : 0;
assign rd_data2 = (rd_addr2 != 0) ? reg_file_arr[rd_addr2] : 0;
```
