# Forwarding unit (TODO 1) - truth table

The forwarding unit sets two 2-bit selects each cycle, one per Execute source operand:

- `ForwardAE` - for source A (register `Rs1E`)
- `ForwardBE` - for source B (register `Rs2E`)

Each select chooses where that operand's value comes from:

| Value | Source | Meaning |
|-------|--------|---------|
| `2'b00` | register file | no hazard - use the value read in Decode |
| `2'b10` | **Memory stage** | forward the result of the instruction now in M |
| `2'b01` | **Writeback stage** | forward the result of the instruction now in W |

## Rules

A source operand needs forwarding when an **in-flight producer** (an instruction still in M or W that
will write a register) has the **same destination register** as this operand's source, and that register
is **not x0**. When both M and W could supply it, **Memory wins** (it's the fresher, nearer value).

## Truth table (for source A; source B is identical with `Rs2E`)

Evaluate top-to-bottom; the first matching row wins.

| Condition | `ForwardAE` |
|-----------|-------------|
| `RegWriteM` and `RdM != 0` and `RdM == Rs1E` | `2'b10`  (forward from Memory) |
| else if `RegWriteW` and `RdW != 0` and `RdW == Rs1E` | `2'b01`  (forward from Writeback) |
| else | `2'b00`  (no forwarding) |

Source B uses the exact same table with `Rs2E` in place of `Rs1E`, writing `ForwardBE`.

## Signals available (already in the skeleton)

- `Rs1E`, `Rs2E` - the Execute instruction's two source registers.
- `RegWriteM`, `RdM` - the Memory-stage instruction: is it writing a register, and which one.
- `RegWriteW`, `RdW` - the Writeback-stage instruction: same.

## Why `RdM != 0` / `RdW != 0`

Register x0 is hardwired to 0. An instruction whose destination is x0 doesn't really "produce" a value,
so you must never forward from it - otherwise you'd inject a nonzero value where 0 is required. (This is
also one of the invariants you'll assert in Task 4.)

## Common mistakes

- Forgetting the `!= 0` guard -> forwards a bogus x0 producer.
- Checking Writeback before Memory -> forwards a stale value when both match.
- Only handling source A (Rs1E) and forgetting source B (Rs2E).
