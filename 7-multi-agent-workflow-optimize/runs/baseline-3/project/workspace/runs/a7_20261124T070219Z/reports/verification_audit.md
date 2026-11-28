# Verification Audit – `memory_access`
**Run:** `a7_20261124T070219Z`  
**Stage:** VERIFY  
**Audit date:** 2026-11-24  
**Specification:** `workspace/specs/memory_access_spec.md`  
**TB file:** `workspace/runs/a7_20261124T070219Z/tb/tb_memory_access.sv`  
**RTL file:** `workspace/runs/a7_20261124T070219Z/src/memory_access.sv`

---

## 1. Prior simulation state

The DEBUG stage passed with 121/121 tests (RESULT: PASS).  
No RTL repair was required; the debug agent performed a no-change audit.

---

## 2. Covered behavior (pre-audit, 121 tests)

| Section | Behavior | #tests |
|---------|----------|--------|
| 1  | Idle defaults: `MemRW=00` and `MemRW=11` → all outputs zero | 7 |
| 2  | SB stores at all 4 byte offsets; zero/all-ones/alternating patterns | 12 |
| 3  | SH stores at both halfword offsets (bit1=0/1); 0x1234, 0xABCD, 0xFFFF, 0x0000 | 8 |
| 4  | SW stores (offset 0); DEAD, zero, all-ones, A5×4, 12345678 | 5 |
| 5  | LB sign-extension at all 4 byte offsets; 0x42 (pos), 0xFF, 0x80, 0x00 | 14 |
| 6  | LBU zero-extension at all 4 byte offsets; 0xFF, 0x80, A5B6C7D8 | 12 |
| 7  | LH sign-extension at both halfword offsets + lsb[0]=1 paths; 0x7FFF, 0xFFFF, 0x8000, 0x0000, 0xABCD | 10 |
| 8  | LHU zero-extension at both halfword offsets; 0xFFFF, 0x8000, 0xBEEFDEAD, 0x1234 | 8 |
| 9  | LW passthrough at offset 0; DEAD, zero, all-ones, A5×4, 5A×4 | 5 |
| 10 | Exhaustive store+load path independence sweep: 4 data × 4 lsb × (3 store + 5 load) | 32 |
| 11 | Unsupported Funct3 for store (3'b011/100/101/110/111) → defaults | 5 |
| 12 | Unsupported Funct3 for load (3'b011/110/111) → LoadData=0 | 3 |

---

## 3. Coverage gap analysis

After auditing against the spec the following defensible gaps were identified:

### Gap A – LHU with high-bit-set halfword at `AddrLSB`=01 / 11
- **Risk:** `LHU` extracts the halfword via the `sel_half` mux keyed on `AddrLSB[1]`.  
  The lsb=01 and lsb=11 paths (bit1=0 and bit1=1 respectively) were only exercised with `0x1234` whose halfword bit 15 is **0**.  
  A high-bit halfword (`0x8000`, `0xABCD`) was never applied at these lsb values, leaving the zero- vs sign-extension distinction untested for those paths.

### Gap B – LW with non-zero `AddrLSB`
- **Risk:** Spec scopes word accesses to offset 0, but the RTL passes `ReadData` through unconditionally. If `AddrLSB` were misused in a future RTL revision the existing tests would not catch it. Only lsb=00 was tested.

### Gap C – SW with non-zero `AddrLSB`
- **Risk:** `SW` sets `ByteEnable=1111` and `WriteData=StoreData` without inspecting `AddrLSB`. Only lsb=00 was tested; a latent mux using `AddrLSB` would go undetected.

### Gap D – LB max-positive byte boundary (`0x7F`)
- **Risk:** 0x7F is the boundary at which sign-extension must NOT fire (sign bit = 0). Existing positive tests used only 0x42, leaving the highest non-negative signed byte unchecked.

### Gap E – LBU minimum non-zero byte (`0x01`)
- **Risk:** Low-end zero-extension edge. 0x01 at different byte offsets was untested.

### Gap F – LH near-min-negative halfword (`0x8001`)
- **Risk:** 0x8001 sits one step above `0x8000` (the existing boundary test). Sign-extension must produce `0xFFFF8001`.

---

## 4. Added tests (Section 13 – 18 new test cases)

| Sub-group | Label(s) | Description |
|-----------|----------|-------------|
| 13a | `LHU_lsb1_0x8000_zero`, `LHU_lsb1_0xABCD_zero`, `LHU_lsb3_0x8000_zero`, `LHU_lsb3_0xABCD_zero` | LHU: high-bit halfword via bit1=0 and bit1=1 paths; confirms zero-extension |
| 13b | `LW_lsb1_passthru`, `LW_lsb2_passthru`, `LW_lsb3_passthru` | LW: full-word passthrough with lsb=01/10/11 |
| 13c | `SW_lsb1_BE_full`, `SW_lsb2_BE_full`, `SW_lsb3_BE_full` | SW: `ByteEnable=1111`, `WriteData=StoreData` at non-zero `AddrLSB` |
| 13d | `LB_lsb{0-3}_0x7F_maxpos` | LB: max-positive byte 0x7F at all four byte lanes; sign bit must be 0 |
| 13e | `LBU_lsb0_0x01`, `LBU_lsb3_0x01` | LBU: minimum non-zero byte (0x01); zero-extension at byte offsets 0 and 3 |
| 13f | `LH_lsb0_0x8001_neg`, `LH_lsb2_0x8001_neg` | LH: near-boundary negative halfword (0x8001); sign-extension must produce `0xFFFF8001` |

---

## 5. Post-addition simulation result

Controller re-run required (this audit is written before the VERIFY→SIMULATE step).  
Local dry-run:

```
--- Section 13: Targeted gap closures ---
---
TESTS_PASSED 139
TESTS_ERRORS 0
TESTS_TOTAL  139
RESULT: PASS
```

**Previous:** 121/121 PASS  
**After Section 13:** 139/139 PASS (18 new tests added, 0 regressions)

---

## 6. Intentionally out-of-scope behavior

The following behaviors are **not** tested and are **excluded by the spec** (`memory_access_spec.md §Alignment Scope`):

- Misaligned halfword accesses (SH/LH/LHU at odd byte offsets in a "real" alignment sense for 16-bit operations)
- Misaligned word accesses and architectural misalignment traps
- MemRW=11 functional behavior (unused encoding; only the deterministic-zero default is verified)
- Upper bits of `StoreData` for SB/SH (spec extracts only `[7:0]` / `[15:0]`)

---

## 7. Remaining risk

| Risk | Severity | Note |
|------|----------|------|
| Funct3=010 for MemRW=00 not explicitly varied across all lsb values | Negligible | The idle section already verifies all outputs are 0 regardless of Funct3/lsb via `check_idle`; no functional path exists |
| MemRW=01 or 10 with X/Z inputs (undefined inputs) | Negligible | Out of scope for synthesizable RTL verification; Icarus does propagate X through combinational paths but testbench uses fully defined stimuli |

---

## 8. Ownership declaration

- **Edited:** `TB_PATH` (`workspace/runs/a7_20261124T070219Z/tb/tb_memory_access.sv`)
- **Edited:** `REPORTS_DIR/verification_audit.md` (this file)
- **Not edited:** RTL, PD files, or any other run directory
