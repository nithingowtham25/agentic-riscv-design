# PD Agent Notes – `memory_access`

**Run:** `a6_20261123T011937Z`  
**Stage:** PD  
**Agent:** PD specialist  
**Timestamp:** 2026-11-23T01:25:xx UTC  

---

## 1. Design characterisation

| Attribute | Value |
|---|---|
| Module | `memory_access` |
| RTL source | `workspace/runs/a6_20261123T011937Z/src/memory_access.sv` |
| Design type | **Purely combinational** – single `always_comb` block, no clock or reset ports |
| Interface (inputs) | `MemRW[1:0]`, `Funct3[2:0]`, `AddrLSB[1:0]`, `StoreData[31:0]`, `ReadData[31:0]` |
| Interface (outputs) | `WriteData[31:0]`, `ByteEnable[3:0]`, `LoadData[31:0]` |
| Specification | `workspace/specs/memory_access_spec.md` |

The module is purely combinational; there is no sequential state and therefore no functional clock or reset.

---

## 2. Simulation baseline (accepted)

Final simulation from stage VERIFY/re-simulation (`re-simulation_06.log`):

```
TESTS_PASSED: 95   TESTS_ERRORS: 0   TESTS_TOTAL: 95   RESULT: PASS
```

Compile return code: 0.  Simulation return code: 0.  
No functional defects remain. RTL was not modified after the initial RTL stage.

---

## 3. Timing-constraint rationale

Because `memory_access` is combinational, there is no natural clock. The SDC at  
`workspace/pd/memory_access.sdc` creates a **virtual clock** (`a6_memory_access_io`)  
with a 10 ns period and assigns 1 ns input/output delay margins to all ports:

```tcl
create_clock -name a6_memory_access_io -period 10.0
set_input_delay  1.0 -clock a6_memory_access_io [all_inputs]
set_output_delay 1.0 -clock a6_memory_access_io [all_outputs]
```

This leaves **8 ns of combinational slack budget** for the full data-path  
(MemRW → ByteEnable/WriteData/LoadData), which is conservative for ASAP7 at any  
reasonable clock target. The constraint is shared from the workspace-level SDC and  
is not modified per-run.

---

## 4. ORFS / OpenROAD Flow Scripts configuration

| Parameter | Value | Rationale |
|---|---|---|
| `PLATFORM` | `asap7` | Standard ASAP7 7nm PDK predictive library used by the course |
| `DESIGN_NAME` | `memory_access` | Matches RTL top-module name exactly |
| `ABC_AREA` | `1` | Optimise for area; timing slack is large for a combinational block |
| `CORE_UTILIZATION` | `40` | Leaves routing headroom; small block may lower automatically |
| `PLACE_DENSITY` | `0.8` | Fine-grained placement to avoid congestion |
| `GPL_TIMING_DRIVEN` | `1` | Timing-aware global placement |
| `LEC_CHECK` | `0` | Formal LEC not available in course container |
| `FLOW_VARIANT` | `a6_memory_access` | Run-unique tag isolates ORFS artefacts |

The run-local `config.mk` is at:  
`workspace/runs/a6_20261123T011937Z/pd/config.mk`

ORFS working tree (output of synthesis/place-and-route):  
`workspace/runs/a6_20261123T011937Z/pd/orfs_work/`

---

## 5. Synthesis command context

The controller invokes synthesis via `tools/run_synthesis.py` with the following  
effective arguments (resolved from the run configuration):

```bash
python3 tools/run_synthesis.py \
  --rtl    workspace/runs/a6_20261123T011937Z/src/memory_access.sv \
  --reports workspace/runs/a6_20261123T011937Z/reports \
  --pd-work workspace/runs/a6_20261123T011937Z/pd/orfs_work \
  --top    memory_access \
  --sdc    workspace/pd/memory_access.sdc \
  --flow-variant a6_memory_access
```

The script:
1. Checks for the ORFS Singularity image at `../4-physical-design-agent/lab4-orfs-fall2026-v1.sif`.
2. Regenerates `workspace/runs/a6_20261123T011937Z/pd/config.mk` with per-run container paths.
3. Invokes `singularity exec` → `make … finish` inside the ORFS container.
4. Collects `.rpt` files from `pd/orfs_work/reports/asap7/memory_access/a6_memory_access/`.
5. Writes `reports/synthesis_output.log`, `reports/synth_summary.json`, and  
   `reports/synth_summary.rpt`.

Metrics parsed: `design_area`, `worst_slack`, `total_power` (from ORFS `.rpt` files  
and stdout).

---

## 6. Expected metric limitations

| Metric | Expectation | Reason |
|---|---|---|
| Area | Very small (sub-100 µm² in ASAP7) | 95 two-input mux/AND primitives maximum |
| Worst slack | Positive (timing met) | 8 ns combinational budget; path depth ≤ 5 logic levels |
| Total power | Negligible dynamic power | No registers; purely switching/leakage |
| DRC | 0 expected | Combinational block; no clock routing complexity |

**No PPA numbers are fabricated here.** All final values come exclusively from the  
ORFS tool reports at synthesis time.

---

## 7. Icarus compatibility note

Icarus Verilog 12 issues `sorry: constant selects in always_* processes` warnings for  
the indexed part-selects inside `always_comb` (11 occurrences). These are **warnings  
only** – compile and simulation both return code 0, and functional correctness is  
confirmed by the 95-test pass. These constructs (`ReadData[7:0]`, `ReadData[15:8]`, etc.)  
are standard synthesizable SystemVerilog that ORFS/Yosys handles correctly.

---

## 8. Files owned by this agent

| Path | Description |
|---|---|
| `workspace/runs/a6_20261123T011937Z/pd/config.mk` | Run-local ORFS configuration (reference copy) |
| `workspace/runs/a6_20261123T011937Z/reports/pd_agent_notes.md` | This document |

RTL (`src/memory_access.sv`) and testbench (`tb/tb_memory_access.sv`) are **not  
modified** by this agent.
