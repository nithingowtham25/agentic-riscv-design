# PD Agent Notes — `memory_access`

**Run ID:** a6_20261122T000411Z  
**Agent:** PD  
**Timestamp:** 2026-11-22T00:09 UTC (after VERIFIED state)  
**Orchestration state at entry:** `PHYSICAL_DESIGN`

---

## 1. Top Module Confirmation

| Item | Value |
|------|-------|
| Module name | `memory_access` |
| Source file | `workspace/src/memory_access.sv` |
| Design type | **Purely combinational** (single `always_comb` block) |
| Sequential elements | **None** — no `always_ff`, no `posedge`/`negedge`, no `clk` port |
| Port list (spec-matched) | `MemRW[1:0]`, `Funct3[2:0]`, `AddrLSB[1:0]`, `StoreData[31:0]`, `ReadData[31:0]` *(inputs)* / `WriteData[31:0]`, `ByteEnable[3:0]`, `LoadData[31:0]` *(outputs)* |

The module name and port list are identical to the functional contract in
`workspace/specs/memory_access_spec.md`. No clock port was added. Rule 5 is
satisfied: the PD Agent has not modified `workspace/src/memory_access.sv`.

---

## 2. PD Configuration Review

### `workspace/pd/config.mk`

| Variable | Value | Rationale |
|----------|-------|-----------|
| `PLATFORM` | `asap7` | Pinned to Assignment 4 ASAP7 PDK. |
| `DESIGN_NAME` | `memory_access` | Matches RTL top-module name exactly. |
| `VERILOG_FILES` | `/workspace/Assignment6/workspace/src/memory_access.sv` | Container-mapped absolute path. |
| `SDC_FILE` | `/workspace/Assignment6/workspace/pd/memory_access.sdc` | Virtual-clock SDC (see §3). |
| `WORK_HOME` | `/workspace/Assignment6/workspace/pd/orfs_work` | Isolated Assignment 6 ORFS work directory; does not pollute any Assignment 4 artifacts. |
| `FLOW_VARIANT` | `a6_memory_access` | Unique variant tag ensures reports land under a distinct sub-tree. |
| `ABC_AREA` | `1` | Area-optimisation pass active; appropriate for a small combinational block. |
| `CORE_UTILIZATION` | `40` | Conservative utilisation; leaves routing headroom for the ASAP7 node. |
| `PLACE_DENSITY` | `0.8` | Matches Assignment 4 baseline. |

No changes were made to `config.mk`; the existing settings are correct and
consistent with the ORFS container's expected paths.

### `workspace/pd/memory_access.sdc`

```tcl
current_design memory_access
set virtual_clk a6_memory_access_io
create_clock -name $virtual_clk -period 10.0
set_input_delay  1.0 -clock $virtual_clk [all_inputs]
set_output_delay 1.0 -clock $virtual_clk [all_outputs]
```

**Constraint rationale:**  
`memory_access` has no real clock. A *virtual clock* at 10 ns is the standard
OpenROAD/ORFS idiom for constraining combinational I/O paths: it gives the
synthesis and timing-analysis engines a numeric budget to optimise against
without implying any flip-flop or latch in the design.  
`set_input_delay 1.0` and `set_output_delay 1.0` reserve 1 ns at each boundary,
leaving an effective combinational budget of 8 ns (10 − 1 − 1) for the worst-case
cone through the store/load mux logic.  
No changes were made to `memory_access.sdc`; the constraints are retained as
specified.

---

## 3. Timing and Power Interpretation Limitations

Because `memory_access` is **entirely combinational**, the following limitations
apply to PPA interpretation:

| Metric | Limitation |
|--------|-----------|
| **Timing (WNS)** | Reported against the virtual clock; does not correspond to a real operating frequency. The 10 ns period is an analysis convenience, not a silicon target. |
| **Dynamic power** | Will be near-zero or unreported: ORFS requires a switching-activity file (`.saif`) or frequency annotation to estimate dynamic power. Without a real clock, the tool's power estimator has no switching events. Only leakage power may be meaningful. |
| **Area** | Reported in µm² (ASAP7 standard cells). This is the most reliable metric for a purely combinational block and is the primary PPA indicator for this stage. |
| **Place & Route** | Full place-and-route results depend on successful ORFS container execution. If the SIF or Singularity runtime is unavailable, the script records `missing_orfs_runtime`; that is a tool infrastructure gap, not an RTL defect. |

PPA values will **not** be fabricated here. The synthesis tool (`run_synthesis.py`)
is the sole source of reported metrics, written to
`workspace/reports/synth_summary.json` and
`workspace/reports/synth_summary.rpt`.

---

## 4. Prior-Stage Simulation Evidence

| Stage | Result |
|-------|--------|
| Initial simulation | PASS (log: `transcripts/simulation_initial_02.log`) |
| Verification audit | 59 / 59 tests, 0 errors — **RESULT: PASS** (`verification_audit.md`) |
| Post-audit simulation | PASS (log: `transcripts/simulation_after_verification_05.log`) |

The functional contract is fully satisfied across all in-scope behaviors. The
module is cleared for physical synthesis.

---

## 5. Next Step

```
python3 tools/run_synthesis.py
```

This command invokes the pinned ORFS/OpenROAD container (Assignment 4 SIF) with
the isolated Assignment 6 work directory, synthesises `memory_access` using the
ASAP7 PDK and the virtual-clock SDC above, and writes:

- `workspace/reports/synthesis_output.log` — full ORFS transcript  
- `workspace/reports/synth_summary.json` — structured PPA metrics  
- `workspace/reports/synth_summary.rpt` — human-readable summary  

---

*PD Agent owns: `workspace/pd/` configuration files and `workspace/reports/pd_agent_notes.md` only.*  
*RTL (`workspace/src/memory_access.sv`) was read but not modified.*
