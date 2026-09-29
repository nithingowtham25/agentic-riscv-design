# Project-specific memory addressing (THIS core)

## data_mem — word-addressed data RAM
- 64 words of 32 bits (`MEM_SIZE=64`). **Word-addressed:** the byte address is shifted
  right by 2 and taken mod 64: index = `wr_addr[DATA_WIDTH-1:2] % 64`.
- **Read is combinational**, **write is synchronous on `posedge clk`** (gated by `wr_en`).
- Read and write use the SAME address port (`wr_addr`) in this design.

```verilog
assign rd_data_mem = data_ram[wr_addr[31:2] % 64];
always @(posedge clk) if (wr_en) data_ram[wr_addr[31:2] % 64] <= wr_data;
```

## instr_mem — word-addressed instruction ROM
- 512 words; combinational read: `instr = instr_ram[instr_addr[31:2]]`.
- Loaded from a hex file via `$readmemh` in an `initial` block.

Common bug: indexing by the raw byte address instead of `addr[31:2]` (off by 4×), or
using a blocking assignment / wrong clock edge for the write.
