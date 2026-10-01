# Project-specific load/store sizing (THIS core)

Two modules handle sub-word memory access. Both are `sel`/`funct3`-indexed with fixed codes.

## store_extend — shapes store data by size (`sel[1:0]`)
| sel | store | data out |
|-----|-------|----------|
| `10` | SW (word) | `y` (all 32 bits) |
| `00` | SB (byte) | `{24'b0, y[7:0]}` |
| `01` | SH (half) | `{16'b0, y[15:0]}` |
| default | — | `y` |

Note: **SW is `10`, not `00`** in this core; `00` is byte.

## sgn_zero_extend — extends loaded data by `funct3`
| funct3 | load | ext_out |
|--------|------|---------|
| `000` | lb  | sign-extend `read_data_mem[7:0]`  → `{{24{bit7}}, [7:0]}` |
| `001` | lh  | sign-extend `read_data_mem[15:0]` → `{{16{bit15}}, [15:0]}` |
| `100` | lbu | zero-extend byte  → `{24'b0, [7:0]}` |
| `101` | lhu | zero-extend half  → `{16'b0, [15:0]}` |
| `010` | lw  | full word (`read_data_mem`) |

Common bug: swapping sign- vs zero-extend (lb vs lbu, lh vs lhu), or using the wrong
`funct3` code for a size.
