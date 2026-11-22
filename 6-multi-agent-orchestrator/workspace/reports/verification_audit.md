# Verification Audit — `memory_access`

**Run ID:** a6_20261122T000411Z  
**Agent:** VERIFY  
**Timestamp:** 2026-11-22T00:08 UTC  
**RTL source:** `workspace/src/memory_access.sv`  
**Testbench:** `workspace/tb/tb_memory_access.sv`  
**Simulation result (post-audit):** TESTS_PASSED: 59 / TESTS_ERRORS: 0 / TESTS_TOTAL: 59 — **RESULT: PASS**

---

## 1. Covered Behaviors (pre-existing, confirmed correct)

| Group | Behavior | Tests |
|-------|----------|-------|
| 1 | Inactive/idle defaults: MemRW=00 → WriteData=0, ByteEnable=0, LoadData=0 | 2 |
| 1 | Unused MemRW=11 → same all-zero defaults | 1 |
| 2 | SB at all four byte offsets (0,1,2,3) with distinct data | 4 |
| 2 | SB all-ones source (upper bytes must not bleed into WriteData) | 1 |
| 2 | SB zero data: ByteEnable must still assert at correct lane | 1 |
| 3 | SH at both aligned halfword offsets (0, 2) with negative-looking data | 2 |
| 3 | SH with AddrLSB bit[0]=1 (odd offsets), confirming bit[1]-only selection | 2 |
| 3 | SH zero data at offset 2: ByteEnable=1100 must still assert | 1 |
| 4 | SW with representative values (0xDEADBEEF, 0x0, 0xFFFFFFFF) | 3 |
| 5 | Output isolation: LoadData=0 during stores; WriteData/ByteEnable=0 during loads | 2 |
| 6 | LB sign-extend at all four offsets, negative (MSB=1) values | 4 |
| 6 | LB sign-extend at all four offsets, positive (MSB=0) values | 4 |
| 7 | LBU zero-extend at all four offsets | 4 |
| 8 | LH sign-extend at offsets 0 and 2 (negative and positive halfwords) | 4 |
| 9 | LHU zero-extend at offsets 0 and 2 | 3 |
| 10 | LW full 32-bit word (DEADBEEF, 0x0, 0xFFFFFFFF) | 3 |
| 11 | Sign-/zero-extension boundary values: 0x7F, 0x80, 0xFF (byte); 0x7FFF, 0x8000, 0xFFFF (half) | 8 |

**Pre-existing total: 49 tests (all passed)**

---

## 2. Newly Added Targeted Cases (10 tests)

### GROUP 12 — SW AddrLSB independence (2 tests)
**Rationale:** The spec states SW occupies offset 0 for natural alignment, but the RTL uses `AddrLSB` only for byte/half lane selection, not for SW. The existing tests only applied SW with AddrLSB=0. Added checks with AddrLSB=2 and AddrLSB=3 to confirm SW always produces ByteEnable=4'b1111 and passes StoreData through unchanged, regardless of AddrLSB.

| Label | Inputs | Expected |
|-------|--------|----------|
| SW_ADDRLSB2 | MemRW=01, Funct3=010, AddrLSB=10, StoreData=0xA5A5A5A5 | WD=A5A5A5A5, BE=1111 |
| SW_ADDRLSB3 | MemRW=01, Funct3=010, AddrLSB=11, StoreData=0x12345678 | WD=12345678, BE=1111 |

### GROUP 13 — Unused store Funct3 encodings (5 tests)
**Rationale:** The spec defines only Funct3=000(SB), 001(SH), 010(SW) for stores. Encodings 3'b011, 3'b100, 3'b101, 3'b110, 3'b111 are unused. The RTL `default` branch drives ByteEnable=0, WriteData=0. These encodings were previously untested; a RTL defect (e.g., missing `default`) would have silently produced non-zero outputs.

| Label | Funct3 | Expected |
|-------|--------|----------|
| STORE_F3_011 | 3'b011 | WD=0, BE=0000 |
| STORE_F3_100 | 3'b100 | WD=0, BE=0000 |
| STORE_F3_101 | 3'b101 | WD=0, BE=0000 |
| STORE_F3_110 | 3'b110 | WD=0, BE=0000 |
| STORE_F3_111 | 3'b111 | WD=0, BE=0000 |

### GROUP 14 — Unused load Funct3 encodings (3 tests)
**Rationale:** The spec defines only Funct3=000(LB), 001(LH), 010(LW), 100(LBU), 101(LHU) for loads. Encodings 3'b011, 3'b110, 3'b111 are unused. The RTL `default` branch drives LoadData=0. These encodings were previously untested.

| Label | Funct3 | Expected |
|-------|--------|----------|
| LOAD_F3_011 | 3'b011 | LoadData=0 |
| LOAD_F3_110 | 3'b110 | LoadData=0 |
| LOAD_F3_111 | 3'b111 | LoadData=0 |

---

## 3. Out-of-Scope Behavior (not tested)

Per **spec §Alignment Scope**, the following are explicitly out of scope for Assignment 2 and are intentionally not covered:

- Misaligned halfword accesses (SH/LH/LHU at odd byte offsets with architectural trap behavior)
- Misaligned word accesses (SW/LW at non-zero offsets)
- MemRW=11 functional semantics beyond the all-zero default (unused encoding)

---

## 4. Evidence-Based Conclusion

The RTL (`memory_access.sv`) correctly implements the full RV32I load/store formatting unit as specified. The 10 newly added targeted tests exercised the two previously unverified categories — SW AddrLSB independence and all unused Funct3 encodings for both store and load paths — and confirmed the RTL's `default` handling is correct.

**Post-audit simulation:** 59 / 59 tests passed, 0 errors — **RESULT: PASS**

The functional contract (`workspace/specs/memory_access_spec.md`) is satisfied across all in-scope behaviors. The module is cleared for physical design synthesis.
