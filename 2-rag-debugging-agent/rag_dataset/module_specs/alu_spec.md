# Module spec: alu

**Ports**
- `input  [31:0] a, b` — operands
- `input  [3:0]  op` — 0:ADD 1:SUB 2:AND 3:OR 4:XOR 5:SLL 6:SRL 7:SLT
- `output [31:0] result`
- `output zero` — high when `result == 0`

**Expected behavior:** purely combinational; `result` follows `op` per the RV32I
ALU reference. `SLT` (op=7) must be a **signed** less-than comparison.

**Golden check:** `a=-1, b=1, op=7` must give `result=1` (since -1 < 1 signed).
