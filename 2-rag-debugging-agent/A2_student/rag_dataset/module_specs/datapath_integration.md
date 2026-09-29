# Single-cycle RV32I datapath integration (this core)

How the top-level datapath (`riscv_single`) wires the components. Common integration bugs
live here (mux selects swapped, wrong operand routed).

## ALU operand selects
- `ALUSrcAD`: 0 => rs1 (`rf_rd1`); 1 => PC. Used as ALU A input.
  `alu_a = ALUSrcAD ? pc : rf_rd1;`
- `ALUSrcBD`: 0 => rs2 (`rf_rd2`); 1 => **immediate** (`imm`). Used as ALU B input.
  `alu_b = ALUSrcBD ? imm : rf_rd2;`   // when ALUSrcBD=1 the immediate MUST be selected
  Bug symptom if swapped: I-type ALU / loads / stores use rs2 instead of the immediate,
  so `addi`/`lw`/`sw` compute wrong values (e.g. `addi x1,x0,5` leaves x1=0).

## Writeback / result select
- `ResultSrcD`: 000 => ALU/IEU result; 001 => load data (`dmem_rdata`).
- `ALUResultSrcD`: 1 selects the alternate result — immediate for LUI, `pc+4` for JAL/JALR.
- `rf_we = RegWriteD & ~IllegalInstrD;`  x0 writes are ignored inside the regfile.

## PC / branch
- `pc_plus4 = pc + 4`; taken branch or jump redirects: `pc_next = pc_sel ? target : pc_plus4`.
- `pc_sel = (BranchD & take_branch) | JumpD;` target LSB forced to 0.

Fix integration bugs by matching each mux select to the control-signal meaning above; do
not change the component module interfaces.
