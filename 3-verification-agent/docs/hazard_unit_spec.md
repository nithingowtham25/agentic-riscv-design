# Hazard unit + redirect/flush (TODO 2 and TODO 3)

Forwarding (TODO 1) handles most read-after-write hazards. Two situations it cannot fix on its own - a
**load-use hazard** (needs a stall) and a **control-flow change** (needs a flush + redirect).

---

## TODO 2 - load-use hazard (stall)

A load produces its value in the **Memory** stage, one cycle later than an ALU instruction. So if the
instruction **immediately after a load** uses the loaded register, the value isn't available in time even
with forwarding - the pipeline must **stall one cycle**.

**Detect it.** Set `LoadUseHazard = 1` when **all** of:
- the instruction in Execute is a **load** - identified by `ResultSrcE == 3'b001`, and
- its destination `RdE` is **not x0** (`RdE != 5'b0`), and
- `RdE` equals a source register of the instruction in Decode: `RdE == Rs1D` **or** `RdE == Rs2D`.

```
LoadUseHazard = (ResultSrcE == 3'b001) && (RdE != 0) && ((RdE == Rs1D) || (RdE == Rs2D))
```

What the stall does (wired for you once you set the signals in TODO 3): hold the F and D stages one cycle
and insert a bubble into E, so next cycle the load has reached M and can forward normally.

---

## TODO 3 - redirect + flush, and the stall/flush wiring

A **taken branch or any jump** is resolved in the **Execute** stage. By then, the two instructions behind
it (in Decode and Execute-input) were fetched sequentially and are on the **wrong path** - they must be
**flushed**, and the PC redirected to the branch/jump target.

`PCSrcE` is already computed for you: it is 1 exactly when a branch is taken or an instruction is a jump.
`RedirectTargetE` is the correct target address (already computed).

Set these signals:

| Signal | Set it to | Meaning |
|--------|-----------|---------|
| `RedirectE` | `PCSrcE` | a redirect is needed this cycle |
| `PCNextF`   | `RedirectE ? RedirectTargetE : PCPlus4F` | next PC: target on redirect, else sequential |
| `StallF`    | `LoadUseHazard` | hold Fetch during a load-use stall |
| `StallD`    | `LoadUseHazard` | hold Decode during a load-use stall |
| `FlushD`    | `RedirectE` | bubble the Decode instruction on a redirect (wrong path) |
| `FlushE`    | `RedirectE \|\| LoadUseHazard` | bubble Execute on a redirect **or** to insert the load-use bubble |

## Order of reasoning

1. Implement forwarding (TODO 1) first - most dependency tests will then pass.
2. Add the load-use stall (TODO 2) - load-then-use tests pass.
3. Add redirect + flush (TODO 3) - branch/jump tests pass, and wrong-path instructions stop corrupting
   your results.

## Signals available (already in the skeleton)

`ResultSrcE`, `RdE`, `Rs1D`, `Rs2D` (for the stall); `PCSrcE`, `RedirectTargetE`, `PCPlus4F` (for the
redirect); `LoadUseHazard` (you set it in TODO 2, use it in TODO 3).

## Common mistakes

- Stalling but not also flushing E (`FlushE`) -> the load-use bubble isn't inserted.
- Flushing only D and not redirecting the PC -> the target is never fetched.
- Forgetting `RdE != 0` in the load-use check -> spurious stalls on `lw x0, ...`.
