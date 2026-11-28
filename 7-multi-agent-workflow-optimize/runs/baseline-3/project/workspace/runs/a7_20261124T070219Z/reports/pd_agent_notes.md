# PD Agent Notes – `memory_access`

**Run ID:** `a7_20261124T070219Z`  
**Stage:** PHYSICAL_DESIGN  
**Agent:** PD specialist  
**Date:** 2026-11-24  
**Flow variant:** `a6_memory_access`

---

## 1. Simulation pre-condition

Final simulation status confirmed before preparing ORFS handoff:

| Metric | Value |
|--------|-------|
| Simulation result | **RESULT: PASS** |
| TESTS_PASSED | 139 |
| TESTS_ERRORS | 0 |
| TESTS_TOTAL | 139 |
| Compile return code | 0 |
| Simulation return code | 0 |

Evidence source: `workspace/runs/a7_20261124T070219Z/reports/sim_summary.json` and `sim_output.log`.

---

## 2. Top-module and interface confirmation

**Module name (from RTL, matches AGENTS.md `MODULE_NAME`):** `memory_access`

**Port list (extracted from `src/memory_access.sv`):**

| Port | Direction | Width | Function |
|------|-----------|-------|----------|
| `MemRW` | input | [1:0] | 00=idle, 01=store, 10=load, 11=unused |
| `Funct3` | input | [2:0] | Store/load sub-operation selector |
| `AddrLSB` | input | [1:0] | Byte/halfword lane selector within 32-bit word |
| `StoreData` | input | [31:0] | Data to write to memory |
| `ReadData` | input | [31:0] | Data read from memory |
| `WriteData` | output | [31:0] | Formatted write-data bus |
| `ByteEnable` | output | [3:0] | Active-high byte-lane enables |
| `LoadData` | output | [31:0] | Sign/zero-extended load result |

**Design type:** Fully combinational (no clocks, no latches, no flip-flops).  
All logic is implemented via `always_comb` blocks and continuous `assign` statements.

---

## 3. Constraint rationale

**SDC file:** `workspace/runs/a7_20261124T070219Z/pd/memory_access.sdc`

```sdc
current_design memory_access
set virtual_clk a6_memory_access_io
create_clock -name $virtual_clk -period 10.0
set_input_delay 1.0 -clock $virtual_clk [all_inputs]
set_output_delay 1.0 -clock $virtual_clk [all_outputs]
```

**Rationale:**
- `memory_access` is a purely combinational block; there is no functional clock port on the DUT.
- A **virtual clock** (`a6_memory_access_io`, period 10 ns = 100 MHz) is created solely to constrain I/O timing for synthesis and static-timing analysis.
- Input/output delays of 1.0 ns each leave 8.0 ns of combinational budget for the internal mux-and-select tree.
- The 10 ns period is conservative for ASAP7; the critical path (a 4:1 byte mux feeding a 32-bit output) is expected to be well under 1 ns in ASAP7, so the constraint is timing-corner-safe and will not over-constrain the tool.
- `LEC_CHECK=0` is set because there is no golden reference netlist; `ABC_AREA=1` targets minimum area for this small mux-based logic block.

---

## 4. Expected PPA characteristics

> **No fabricated numbers are provided here.** The synthesis tool is the sole source of area, timing, and power metrics.

Qualitative expectations (for sanity-checking post-synthesis reports only):

| Attribute | Expectation |
|-----------|-------------|
| Design type | Combinational; no sequential cells expected |
| Dominant cell types | MUX2, MUX4, BUF, INV, AND/OR for byte-enable decoding |
| Critical path | AddrLSB → sel_byte → LoadData sign-extension chain |
| Area footprint | Small; estimated tens to low hundreds of ASAP7 standard cells |
| Dynamic power | Very low due to absence of registers; depends on switching activity |
| Hold violations | Not applicable (no flip-flops) |

---

## 5. Run-local ORFS handoff artifacts

| Artifact | Location | Purpose |
|----------|----------|---------|
| Run-local config | `workspace/runs/a7_20261124T070219Z/pd/config.mk` | ORFS `make` entry point for this isolated run |
| Run-local SDC | `workspace/runs/a7_20261124T070219Z/pd/memory_access.sdc` | Timing constraints (copy from canonical `workspace/pd/`) |
| RTL source | `workspace/runs/a7_20261124T070219Z/src/memory_access.sv` | Frozen post-verification RTL (must not be modified) |
| ORFS work dir | `workspace/runs/a7_20261124T070219Z/pd/orfs_work/` | Synthesis/PnR artefacts written here (created at run time) |

**Reference canonical config (for comparison):** `workspace/pd/config.mk`  
**Key delta from canonical:** `VERILOG_FILES`, `VERILOG_INCLUDE_DIRS`, `SDC_FILE`, and `WORK_HOME` all point to the run-specific paths under `workspace/runs/a7_20261124T070219Z/` to guarantee full isolation.

---

## 6. Synthesis command context

Assuming ORFS is available and the container root maps `RUN_DIR` to `/workspace/Assignment6/workspace/runs/a7_20261124T070219Z/`:

```bash
# From the ORFS container:
cd /path/to/OpenROAD-flow-scripts/flow
make DESIGN_CONFIG=/workspace/Assignment6/workspace/runs/a7_20261124T070219Z/pd/config.mk synth
```

The synthesis tool writes reports to `WORK_HOME/results/asap7/memory_access/base/` and  
`WORK_HOME/reports/asap7/memory_access/base/`.  
PPA metrics are extracted only from those report files.

---

## 7. Ownership declaration

- **Created:** `workspace/runs/a7_20261124T070219Z/pd/config.mk` (run-local ORFS config)
- **Copied:** `workspace/runs/a7_20261124T070219Z/pd/memory_access.sdc` (from canonical `workspace/pd/`)
- **Created:** `workspace/runs/a7_20261124T070219Z/reports/pd_agent_notes.md` (this file)
- **Not modified:** RTL (`src/memory_access.sv`), TB (`tb/tb_memory_access.sv`), any other run directory
