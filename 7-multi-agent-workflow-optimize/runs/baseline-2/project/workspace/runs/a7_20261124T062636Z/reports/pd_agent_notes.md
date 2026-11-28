# PD Agent Notes – ORFS Handoff

**Run ID:** a7_20261124T062636Z  
**Module:** `memory_access`  
**Flow Variant:** `a6_memory_access`  
**PD Stage Timestamp:** 2026-11-24  
**Simulation Prerequisite:** PASS (106/106 tests, 0 errors)

---

## 1. Top-Module Confirmation

| Field | Value |
|-------|-------|
| `DESIGN_NAME` / `DESIGN_NICKNAME` | `memory_access` |
| RTL source | `workspace/runs/a7_20261124T062636Z/src/memory_access.sv` |
| Specification | `workspace/specs/memory_access_spec.md` |
| Prior verification | VERIFY PASS · 106/106 tests · `RESULT: PASS` |

The RTL was **not modified** by Debug (no-change audit) or Verify (TB-only patch). The `memory_access` module is **purely combinational** – it contains a single `always_comb` block with no clock, reset, or state elements.

---

## 2. Interface Inventory

```systemverilog
module memory_access (
    input  logic [1:0]  MemRW,      // 00=inactive, 01=store, 10=load, 11=unused
    input  logic [2:0]  Funct3,     // RV32I load/store sub-type
    input  logic [1:0]  AddrLSB,    // 2 LSBs of effective address
    input  logic [31:0] StoreData,  // register data to write
    input  logic [31:0] ReadData,   // 32-bit memory read bus
    output logic [31:0] WriteData,  // 32-bit memory write data
    output logic [3:0]  ByteEnable, // per-byte write enables
    output logic [31:0] LoadData    // value written to register file
);
```

No clocks. No reset. No I/O direction ambiguity. All ports are single-driver combinational.

---

## 3. Constraint Rationale (SDC)

**File:** `workspace/pd/memory_access.sdc`

```tcl
# memory_access is combinational; constrain I/O timing through a virtual clock.
current_design memory_access
set virtual_clk a6_memory_access_io
create_clock -name $virtual_clk -period 10.0
set_input_delay 1.0 -clock $virtual_clk [all_inputs]
set_output_delay 1.0 -clock $virtual_clk [all_outputs]
```

**Rationale:**
- Because there is no functional clock, OpenROAD/ORFS requires a _virtual_ reference clock to anchor input/output delay constraints.
- A 10 ns virtual clock period (100 MHz) provides a realistic constraint envelope for ASAP7 PDK at typical corner; the combinational depth of an 8→3 mux cascade with sign-extension should achieve well under 1 ns of logic delay, leaving comfortable margin.
- `input_delay 1.0` and `output_delay 1.0` reserve 2 ns for external routing/hold margins and leave 8 ns of combinational budget, which is very generous for this design.
- These constraints do **not** imply a synchronous register boundary; they exist solely to give the timing engine a reference for I/O path checking.

---

## 4. Isolated ORFS Configuration

The run-local `config.mk` is written to `workspace/runs/a7_20261124T062636Z/pd/config.mk` and points directly at this run's RTL source and the shared SDC. It must not reference the global `workspace/pd/config.mk` or any other run's files.

**Key settings:**

| Makefile Variable | Value | Rationale |
|---|---|---|
| `PLATFORM` | `asap7` | Standard ECEN-689 PDK |
| `DESIGN_NAME` | `memory_access` | Exact module name from spec |
| `DESIGN_NICKNAME` | `memory_access` | Used by ORFS log naming |
| `VERILOG_FILES` | _(run-local RTL path, see below)_ | Isolated; never shared |
| `SDC_FILE` | `workspace/pd/memory_access.sdc` | Shared SDC (read-only) |
| `FLOW_VARIANT` | `a6_memory_access` | Matches controller config |
| `ABC_AREA` | `1` | Favour area, combinational block |
| `CORE_UTILIZATION` | `40` | Conservative – small module |
| `PLACE_DENSITY` | `0.8` | Standard for small cells |
| `GPL_TIMING_DRIVEN` | `1` | Enable timing-driven placement |
| `LEC_CHECK` | `0` | LEC not available in course flow |

---

## 5. Expected Metric Limitations

Because `memory_access` is **purely combinational** and small (< 20 logic levels estimated):

| PPA Dimension | Expectation | Notes |
|---|---|---|
| Cell area | Very small (< 50 μm² in ASAP7) | 8-to-1 byte mux + sign-ext replicated 3× |
| Logic levels | ≤ 10 (store path) / ≤ 12 (load+sign-ext) | No feedback, single cone |
| Combinational delay | < 1 ns at ASAP7 typical | Well within 10 ns virtual clock budget |
| Power | Negligible leakage; dynamic power proportional to toggle rate | No register overhead |
| Hold violations | None expected (combinational-only) | Virtual clock has no real flip-flop |
| DRC / LVS | Dependent on ASAP7 standard-cell library version; flag only reported errors | Cannot be pre-validated |

**Important caveat:** Icarus 12 emits 11 `sorry: constant selects in always_* processes` warnings for `always_comb` with variable-index part-selects. These are **simulation tool warnings only** and do not affect RTL synthesizability; OpenROAD's yosys front-end handles these constructs correctly.

---

## 6. Synthesis Command Context

The synthesis step is driven by the run_synthesis tool, which will use the ORFS Makefile with:

```
make -f <ORFS_ROOT>/flow/Makefile WORK_HOME=<RUN_PD_DIR> synth
```

The run-local `config.mk` is loaded by ORFS before the platform defaults. All paths in that file are absolute, so the flow is portable across invocation directories.

**Authoritative PPA source:** Final metrics must come from ORFS synthesis reports under `<RUN_PD_DIR>/results/asap7/memory_access/base/` and `<RUN_PD_DIR>/reports/asap7/memory_access/base/`. No metric values are assumed or fabricated here.

---

## 7. Artifact Checklist

| Artifact | Status |
|----------|--------|
| `workspace/runs/a7_20261124T062636Z/src/memory_access.sv` | ✅ Verified PASS RTL |
| `workspace/runs/a7_20261124T062636Z/tb/tb_memory_access.sv` | ✅ 106-test TB |
| `workspace/pd/memory_access.sdc` | ✅ Present (virtual-clock SDC) |
| `workspace/runs/a7_20261124T062636Z/pd/config.mk` | ✅ Created (run-local ORFS config) |
| `workspace/runs/a7_20261124T062636Z/reports/pd_agent_notes.md` | ✅ This document |

---

## 8. Ownership Confirmation

- RTL (`RTL_PATH`) – **NOT modified** by PD agent.
- TB (`TB_PATH`) – **NOT modified** by PD agent.
- Files written: `pd/config.mk` and `reports/pd_agent_notes.md` under `RUN_DIR` only.
