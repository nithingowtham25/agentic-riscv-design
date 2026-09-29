# Project-specific mux select encodings (THIS core)

All muxes are `sel`-indexed, `d0` first:

- **mux2** (`sel` 1 bit): `y = sel ? d1 : d0`.
- **mux3** (`sel[1:0]`): `y = sel[1] ? d2 : (sel[0] ? d1 : d0)` → sel 00=d0, 01=d1, 10=d2.
  (sel=11 also selects d2 in this implementation.)
- **mux4** (`sel[1:0]`): 00=d0, 01=d1, 10=d2, 11=d3.

Common bug: reversing the ternary (selecting `d0` when `sel` is high), or swapping the
`sel[1]`/`sel[0]` priority so the wrong input is chosen for sel=10 vs 01.
