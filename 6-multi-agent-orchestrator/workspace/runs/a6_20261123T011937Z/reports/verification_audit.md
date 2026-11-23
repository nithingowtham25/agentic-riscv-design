# Verification Audit – `memory_access`

**Run:** `a6_20261123T011937Z`  
**Stage:** VERIFY  
**Timestamp:** 2026-11-23T01:23:xx UTC  
**TB owner:** `workspace/runs/a6_20261123T011937Z/tb/tb_memory_access.sv`  
**RTL reviewed (read-only):** `workspace/runs/a6_20261123T011937Z/src/memory_access.sv`  
**Spec:** `workspace/specs/memory_access_spec.md`

---

## 1. Prior simulation baseline

Before this stage the testbench carried **75 tests across 7 sections**, all passing.

```
TESTS_PASSED: 75   TESTS_ERRORS: 0   TESTS_TOTAL: 75   RESULT: PASS
```

---

## 2. Coverage audit – what was already covered

| Behaviour group | Tests (pre-verify) | Assessment |
|---|---|---|
| MemRW=00 deterministic defaults | 4 | Complete (SB/SH/SW/LBU Funct3 × MemRW=00) |
| MemRW=11 unused encoding defaults | 2 | Adequate |
| SB (Funct3=000) all 4 byte offsets | 8 | Complete (nominal, zero, all-ones, upper-ignored) |
| SH (Funct3=001) offsets 0 & 2 | 6 | Offset 0/2 nominal+boundary; offset 1 as lower-half |
| SW (Funct3=010) | 5 | Nominal, zero, all-ones, boundary, bad-funct3 |
| LB sign-extension, all 4 offsets | 10 | Each offset pos+neg; 0x7F / 0x80 boundary |
| LH sign-extension, offsets 0 & 2 | 7 | Nominal±, maxpos/minneg boundary, off1 lower-half |
| LW passthrough | 4 | Nominal, zero, all-ones, MSB-set |
| LBU zero-extension, all 4 offsets | 6 | Offset 0–3 + 0x80 no-signext at off0 |
| LHU zero-extension, offsets 0 & 2 | 6 + bad-funct3 | Nominal±, boundary, off1 lower-half, bad-funct3 |
| Store/load path isolation | 4 | SW/SB LoadData=0; LW/LB ByteEnable=0+WriteData=0 |
| All-zeros / all-ones corner cases | 7 | SW, LW, LB, LH, LBU, LHU edge data |
| Spec verbatim examples | 5 | SB×2, SH×2, SW×1 direct from spec |

---

## 3. Coverage gaps identified

| Gap ID | Dimension | Detail |
|---|---|---|
| A | Store Funct3 default | Only `011` tested as bad Funct3; `100,101,110,111` untested |
| B | Load Funct3 default | Only `011` tested; `110,111` untested |
| C | SW AddrLSB independence | SW only exercised at AddrLSB=00; RTL ignores AddrLSB for SW |
| D | LW AddrLSB independence | LW only exercised at AddrLSB=00; RTL ignores AddrLSB for LW |
| E | SH at AddrLSB=11 | Exercises `AddrLSB[1]==1` upper-half path; spec misaligned, RTL consistent |
| F | LH at AddrLSB=11 | Upper-half sign-extension; positive and negative values |
| G | LHU at AddrLSB=11 | Upper-half zero-extension |
| H | LBU no-sign-extension at offsets 1/2/3 | Only offset 0 had `0x80` check; offsets 1–3 lacked this |
| I | LH at AddrLSB=01, negative halfword | Off1 tested only with positive `0x5678`; sign-ext not exercised there |

---

## 4. Tests added (Section 8 – Extended Robustness)

20 new tests appended as **Section 8** in `tb_memory_access.sv`.

| Label | Gap | Stimulus | Expected output |
|---|---|---|---|
| `store_funct3_100` | A | MemRW=01, Funct3=100 | BE=0, WD=0, LD=0 |
| `store_funct3_101` | A | MemRW=01, Funct3=101 | BE=0, WD=0, LD=0 |
| `store_funct3_110` | A | MemRW=01, Funct3=110 | BE=0, WD=0, LD=0 |
| `store_funct3_111` | A | MemRW=01, Funct3=111 | BE=0, WD=0, LD=0 |
| `load_funct3_110`  | B | MemRW=10, Funct3=110 | LD=0, WD=0, BE=0 |
| `load_funct3_111`  | B | MemRW=10, Funct3=111 | LD=0, WD=0, BE=0 |
| `SW_off1_addrlsb_ignored` | C | SW, AddrLSB=01, SD=0xDEADBEEF | BE=1111, WD=0xDEADBEEF |
| `SW_off2_addrlsb_ignored` | C | SW, AddrLSB=10, SD=0xCAFEBABE | BE=1111, WD=0xCAFEBABE |
| `SW_off3_addrlsb_ignored` | C | SW, AddrLSB=11, SD=0x12345678 | BE=1111, WD=0x12345678 |
| `LW_off1_addrlsb_ignored` | D | LW, AddrLSB=01, RD=0xDEADBEEF | LD=0xDEADBEEF |
| `LW_off2_addrlsb_ignored` | D | LW, AddrLSB=10, RD=0xCAFEBABE | LD=0xCAFEBABE |
| `LW_off3_addrlsb_ignored` | D | LW, AddrLSB=11, RD=0x12345678 | LD=0x12345678 |
| `SH_off3_as_hi`           | E | SH, AddrLSB=11, SD=0xABCD1234 | BE=1100, WD=0x12340000 |
| `LH_off3_positive`        | F | LH, AddrLSB=11, RD=0x12345678 | LD=0x00001234 |
| `LH_off3_negative`        | F | LH, AddrLSB=11, RD=0xABCD5678 | LD=0xFFFFABCD |
| `LHU_off3_neg_val`        | G | LHU, AddrLSB=11, RD=0xABCD5678 | LD=0x0000ABCD |
| `LBU_off1_no_signext`     | H | LBU, AddrLSB=01, RD=0x00008056 | LD=0x00000080 |
| `LBU_off2_no_signext`     | H | LBU, AddrLSB=10, RD=0x00800056 | LD=0x00000080 |
| `LBU_off3_no_signext`     | H | LBU, AddrLSB=11, RD=0x80005678 | LD=0x00000080 |
| `LH_off1_negative`        | I | LH, AddrLSB=01, RD=0xABCDFEDC | LD=0xFFFFFEDC |

---

## 5. Post-verify simulation result

Simulation rerun with 95-test TB (compile + vvp, Icarus 12):

```
TESTS_PASSED: 95   TESTS_ERRORS: 0   TESTS_TOTAL: 95   RESULT: PASS
```

The controller will re-run the official simulation; this local run confirms no regression.

---

## 6. Behaviour intentionally out of scope

Per spec §Alignment Scope, the following are **not** tested and are architecturally undefined at this level:

- Misaligned halfword store/load (SH/LH/LHU at odd byte offsets where `AddrLSB[1:0]` = 01 or 11 is treated consistent with `AddrLSB[1]` selection, not as a trap).
- Misaligned word store/load (SW/LW at non-zero byte offsets — the RTL ignores AddrLSB for word operations, which the new tests confirm).
- `Funct3=011` encoding ambiguity in the load path (covered by existing `load_bad_funct3`).
- X-propagation and unknown-state assertion sequences (Icarus 12 does not support SVA natively; out of tool scope).

---

## 7. Remaining risk

| Risk | Severity | Rationale |
|---|---|---|
| Icarus `constant selects in always_*` warnings | Low | Known tool limitation; compilation and simulation succeed with RC=0. RTL is functionally equivalent to reference. |
| Synthesis behaviour under misaligned AddrLSB for SW/LW | Low | Spec excludes misaligned word access. New tests confirm RTL ignores AddrLSB for SW/LW at all offsets. |
| Downstream integration reset-state | Out of scope | Module is purely combinational; no state to reset. |

---

## 8. Summary

- **Pre-verify:** 75 tests, 7 sections, PASS.  
- **Added:** 20 targeted tests (Section 8) closing 9 coverage gaps.  
- **Post-verify:** 95 tests, 8 sections, **RESULT: PASS**.  
- **RTL unchanged** (VERIFY owns TB and audit only).
