# 5-stage pipeline reference

The core you edit (`core/datapath_pipelined.sv`) already wires the five stages and the pipeline
registers between them. You fill in three pieces of logic (the TODOs): the **forwarding unit**, the
**hazard-detection unit**, and the **redirect/flush logic**. This diagram shows the structure so you know
what each TODO signal means.

## Stages

```
  F (Fetch) -> F/D reg -> D (Decode) -> D/E reg -> E (Execute) -> E/M reg -> M (Memory) -> M/W reg -> W (Writeback)
```

| Stage | What happens | Key signals (suffix = stage) |
|-------|--------------|------------------------------|
| **F** Fetch     | read instruction at PC; compute PC+4 | `PCF`, `PCPlus4F`, `InstrF` |
| **D** Decode    | decode control; read registers; build immediate | `InstrD`, `Rs1D`, `Rs2D`, `rd1D`, `rd2D`, `ImmExtD` |
| **E** Execute   | ALU op; resolve branches/jumps; **forwarding happens here** | `Rs1E`, `Rs2E`, `RdE`, `ForwardAE`, `ForwardBE`, `ALUResultE`, `PCSrcE` |
| **M** Memory    | data-memory access | `RdM`, `RegWriteM`, `ALUResultM` |
| **W** Writeback | write result back to the register file | `RdW`, `RegWriteW`, `WritebackDataW` |

## Pipeline registers (already provided)

Each stage boundary latches its signals into the next stage. These are written for you - e.g. the D/E
register copies `Rs1D -> Rs1E`, `RdD -> RdE`, the control bits, etc. You do **not** modify the registers;
you only fill the three combinational units below.

## The three things you implement

1. **Forwarding unit** (TODO 1) - chooses, for each Execute source operand, whether to use the register
   value or a fresher value still in the Memory or Writeback stage. Controls `ForwardAE` / `ForwardBE`.
   Spec: `docs/forwarding_truth_table.md`.

2. **Hazard-detection unit** (TODO 2) - detects a **load-use hazard**: a load in Execute whose result a
   dependent instruction in Decode needs before it's available. Sets `LoadUseHazard`.
   Spec: `docs/hazard_unit_spec.md`.

3. **Redirect + flush logic** (TODO 3) - on a taken branch or jump (resolved in Execute), redirect the PC
   and flush the two wrong-path instructions already fetched; also stall/bubble on a load-use hazard.
   Sets `RedirectE`, `PCNextF`, `StallF`, `StallD`, `FlushD`, `FlushE`.
   Spec: `docs/hazard_unit_spec.md`.

## Producer/consumer picture (why forwarding + stalls exist)

```
   cycle:      an instruction that WRITES a register (producer) is in E, then M, then W
   the next instruction that READS that register (consumer) reaches E one or two cycles later
   -> its register read in D is stale; the fresh value is still in M or W
   -> FORWARD it (TODO 1).  Exception: a LOAD's value isn't ready until M, so a use in the very next
      instruction must STALL one cycle (TODO 2) before forwarding can supply it.
   A taken branch/jump isn't known until E, by which point two younger instructions were fetched on the
   wrong path -> FLUSH them and redirect the PC (TODO 3).
```
