# PD Agent Notes — ORFS Handoff

**Run ID:** a7_20261124T053859Z  
**Module:** `memory_access`  
**Flow Variant:** `a6_memory_access`  
**PD Agent timestamp:** 2026-11-24  
**Simulation status entering PD:** PASS (TESTS_PASSED 99 / TESTS_ERRORS 0 / TESTS_TOTAL 99)

---

## 1. Top Module

| Field | Value |
|---|---|
| `DESIGN_NAME` | `memory_access` |
| RTL source | `workspace/runs/a7_20261124T053859Z/src/memory_access.sv` |
| TB (not used in synthesis) | `workspace/runs/a7_20261124T053859Z/tb/tb_memory_access.sv` |

The module is **purely combinational** (`always_comb` block only). No registers, no latches, no clocks present in the RTL. This has three important PD consequences:

1. No real clock net is synthesised; all timing is I/O-to-I/O through combinational logic.
2. Timing closure is dominated by the depth of the mux/case trees in the store and load paths.
3. Synthesis area will be very small (mux trees + sign/zero-extend logic only).

---

## 2. Interface Summary

```systemverilog
module memory_access (
    input  logic [1:0]  MemRW,      // 00=idle 01=store 10=load
    input  logic [2:0]  Funct3,     // RV32I funct3 encoding
    input  logic [1:0]  AddrLSB,    // byte offset within word
    input  logic [31:0] StoreData,  // data to write to memory
    input  logic [31:0] ReadData,   // data read from memory
    output logic [31:0] WriteData,  // formatted store word
    output logic [3:0]  ByteEnable, // per-byte write enable
    output logic [31:0] LoadData    // sign/zero extended load word
);
```

Total port widths: 70 input bits, 68 output bits.

---

## 3. Constraint Rationale

**SDC file:** `workspace/pd/memory_access.sdc`

```tcl
current_design memory_access
set virtual_clk a6_memory_access_io
create_clock -name $virtual_clk -period 10.0
set_input_delay 1.0  -clock $virtual_clk [all_inputs]
set_output_delay 1.0 -clock $virtual_clk [all_outputs]
```

**Rationale:**
- Because there is no real flip-flop clock, a *virtual clock* at 10 ns provides a legal SDC timing context. OpenROAD requires at least one clock to perform timing analysis.
- The 10 ns period (100 MHz equivalent) is intentionally relaxed for ASAP7. The combinational depth through the deepest store/load mux path is estimated at 5–8 logic levels; ASAP7 fastest cells can easily close this in < 2 ns. The 8 ns of remaining slack after I/O delays leaves plenty of margin.
- `input_delay 1.0 ns` and `output_delay 1.0 ns` model a typical register-to-register boundary context, consuming 2 ns of the 10 ns budget for combinational-path evaluation.
- **No multicycle or false-path exceptions are needed.** All paths are combinational and must meet the full period.

---

## 4. ORFS Configuration

The run-local configuration is at:

```
workspace/runs/a7_20261124T053859Z/pd/config.mk
```

Key settings and their rationale:

| Variable | Value | Rationale |
|---|---|---|
| `PLATFORM` | `asap7` | Standard academic 7-nm PDK used by Assignment 6 flow |
| `ABC_AREA` | `1` | Favour area over speed; timing budget is very relaxed for this design |
| `CORE_UTILIZATION` | `40` | Conservative utilisation for a small design to avoid placement congestion |
| `PLACE_DENSITY` | `0.8` | Moderate density; leaves room for routing |
| `GPL_TIMING_DRIVEN` | `1` | Still run timing-driven global placement even in area-opt mode |
| `LEC_CHECK` | `0` | LEC not required for this assignment |
| `WORK_HOME` | `…/pd/orfs_work` | Isolated per-run; prevents collisions with other runs |

---

## 5. Expected Metric Limitations

> **Policy:** No PPA numbers are fabricated. The values below are *qualitative expectations only*. The synthesis tool is the sole source of final metrics.

| Metric | Qualitative expectation | Reason |
|---|---|---|
| Cell count | Very small (< 50 standard cells likely) | Module is 70-bit mux tree; no memory or DSP |
| Combinational depth | Shallow (5–8 LUT/gate levels) | Nested case statements on 2-bit / 3-bit selects |
| Timing | Easily meets 10 ns virtual clock | Combinational-only with generous budget |
| Total negative slack | Expected 0 (no violations anticipated) | Relaxed period vs shallow logic depth |
| Power | Very low (pure combinational, no toggling on a fixed clock) | No registers; power dominated by switching activity |
| DRC | Not anticipated (small, low-density cell count) | ASAP7 PDK well-characterised for this scale |

---

## 6. Icarus Compile Warnings

The final simulation produced 11 `sorry: constant selects in always_* processes` warnings from Icarus Verilog 12. These are known IVerilog 12 tool limitations for certain constant-index bit-select idioms inside `always_comb`. They do **not** indicate a synthesisability problem; synthesis tools (Yosys/OpenROAD) handle these constructs correctly.

---

## 7. Synthesis Command Context

The synthesis step driven by the controller should invoke ORFS using the run-local `config.mk`:

```bash
# Example invocation (controller fills actual ORFS path)
make -C <ORFS_ROOT>/flow  \
     DESIGN_CONFIG=<RUN_DIR>/pd/config.mk \
     FLOW_VARIANT=a6_memory_access        \
     synth
```

Reports will be written under `<RUN_DIR>/pd/orfs_work/results/asap7/memory_access/base/`.

---

## 8. Ownership and Immutability Declarations

- **RTL NOT modified** (`workspace/runs/a7_20261124T053859Z/src/memory_access.sv` — read-only to PD agent)
- **TB NOT modified** (`workspace/runs/a7_20261124T053859Z/tb/tb_memory_access.sv` — read-only to PD agent)
- **Artifacts created this stage:**
  - `workspace/runs/a7_20261124T053859Z/pd/config.mk` ← run-local ORFS configuration
  - `workspace/runs/a7_20261124T053859Z/reports/pd_agent_notes.md` ← this file
