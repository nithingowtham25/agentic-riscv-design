# VERIFY Agent – Verification Audit Report

**Run:** a7_20261124T062636Z  
**Stage:** VERIFY  
**Timestamp:** 2026-11-24  
**TB_PATH:** workspace/runs/a7_20261124T062636Z/tb/tb_memory_access.sv  
**TB changed:** YES – 29 targeted tests added across 8 new groups (106 total, up from 77)

---

## Prior State

Incoming simulation: **PASS** · 77 tests · 0 errors (all 15 original groups).  
Debug audit confirmed RTL is functionally correct and interface-conformant.

---

## Coverage Gap Analysis

The existing 15 groups exercised all five load types, all three store types, all byte offsets, sign/unsigned extension, and MemRW defaults. The following defensible gaps remained:

| Gap ID | Description | Risk |
|--------|-------------|------|
| G1 | SB: upper bits of StoreData (bits [31:8]) not verified as harmless | Could mask a masking bug |
| G2 | SH: upper halfword of StoreData (bits [31:16]) not verified as harmless | Could mask a masking bug |
| G3 | SW: behaviour with AddrLSB≠0 not documented | Undefined-corner documentation |
| G4 | LW: behaviour with AddrLSB≠0 not documented | Undefined-corner documentation |
| G5 | LB boundary bytes 0x00/0xFF only tested at offset 0; offsets 1–3 not covered | Could mask off-by-one in byte mux |
| G6 | LBU: 0x80 (sign bit set) only tested at offset 0; offsets 1–3 not covered | Could mask wrong sign-extension on those lanes |
| G7 | LHU: 0x8000 at offset 2 never tested; LH 0x0000/0xFFFF at offset 2 never tested | Could mask wrong half-mux or sign extension |
| G8 | Cross-path isolation: LB/LHU with non-zero StoreData; SH/SB with non-zero ReadData | Could mask unexpected coupling |

---

## Tests Added

### GROUP 16 – SB upper-byte isolation (4 new vectors)

Verifies that for every byte offset only `StoreData[7:0]` appears in the addressed lane, and upper bits (`StoreData[31:8]`) are discarded.

| Label | lsb | StoreData | Expected WriteData | Expected BE |
|-------|-----|-----------|-------------------|-------------|
| SB_UBI_OFF0 | 00 | 0xDEAD_BEAB | 0x0000_00AB | 0001 |
| SB_UBI_OFF1 | 01 | 0xDEAD_BECD | 0x0000_CD00 | 0010 |
| SB_UBI_OFF2 | 10 | 0xDEAD_BEEF | 0x00EF_0000 | 0100 |
| SB_UBI_OFF3 | 11 | 0xDEAD_BE5A | 0x5A00_0000 | 1000 |

### GROUP 17 – SH upper-halfword isolation (2 new vectors)

Verifies that for SH only `StoreData[15:0]` enters the addressed halfword lane; `StoreData[31:16]` must not appear in WriteData.

| Label | lsb | StoreData | Expected WriteData | Expected BE |
|-------|-----|-----------|-------------------|-------------|
| SH_UHI_OFF0 | 00 | 0xDEAD_5678 | 0x0000_5678 | 0011 |
| SH_UHI_OFF2 | 10 | 0xDEAD_9ABC | 0x9ABC_0000 | 1100 |

### GROUP 18 – SW with non-zero AddrLSB (3 new vectors)

The spec constrains SW to offset 0, but the DUT's combinational logic must still produce a deterministic output for other AddrLSB values. Verified: `ByteEnable=4'b1111` and `WriteData=StoreData` for lsb=01, 10, 11.

### GROUP 19 – LW with non-zero AddrLSB (3 new vectors)

LW must pass `ReadData` unchanged regardless of AddrLSB. Verified lsb=01, 10, 11.

### GROUP 20 – Cross-path output isolation (4 new vectors)

Confirms that the inactive output path remains zero when the complementary inputs hold non-trivial data:

- `XISO_LB_NO_WD`  : LB load with `StoreData=0xDEAD_BEEF` → `ByteEnable=0, WriteData=0`
- `XISO_LHU_NO_WD` : LHU load with `StoreData=0xDEAD_BEEF` → `ByteEnable=0, WriteData=0`
- `XISO_SH_NO_LD`  : SH store with `ReadData=0xCAFE_BABE` → `LoadData=0`
- `XISO_SB_NO_LD`  : SB store with `ReadData=0xDEAD_BEEF` → `LoadData=0`

### GROUP 21 – LB boundary bytes at offsets 1–3 (6 new vectors)

`0x00` byte → `LoadData=0x00000000`, `0xFF` byte → `LoadData=0xFFFFFFFF`, exercised at all three remaining offsets.

### GROUP 22 – LBU 0x80 at offsets 1, 2, 3 (3 new vectors)

Byte value 0x80 (high-bit set) must zero-extend to `0x00000080`, not sign-extend to `0xFFFFFF80`. Previously only tested at offset 0; now verified at offsets 1, 2, 3.

### GROUP 23 – LHU/LH at offset 2 boundary values (4 new vectors)

| Label | Funct3 | lsb | ReadData | Expected LoadData |
|-------|--------|-----|----------|-------------------|
| LHU_OFF2_C | LHU | 10 | 0x8000_DEAD | 0x0000_8000 (no sign ext) |
| LHU_OFF2_D | LHU | 11 | 0x8000_DEAD | 0x0000_8000 (lsb[1]=1 same path) |
| LH_ZERO_OFF2 | LH | 10 | 0x0000_DEAD | 0x0000_0000 |
| LH_FFFF_OFF2 | LH | 10 | 0xFFFF_DEAD | 0xFFFF_FFFF (full sign ext) |

---

## Covered Behaviour Summary

| Behaviour | Coverage | Notes |
|-----------|----------|-------|
| MemRW inactive (00) | ✅ GRP 1 | 3 vectors, varied Funct3/AddrLSB |
| MemRW unused (11) | ✅ GRP 2 | 2 vectors |
| SB all 4 byte offsets | ✅ GRP 3, 16 | Functional + upper-byte isolation |
| SH both halfword offsets (lsb[1] key) | ✅ GRP 4, 17 | Functional + upper-half isolation |
| SW (AldrLSB=0 and ≠0) | ✅ GRP 5, 18 | AddrLSB-independent behaviour confirmed |
| Undefined store Funct3 → 0 | ✅ GRP 6 | 5 Funct3 values |
| LB sign-ext, all offsets, +/− and boundaries | ✅ GRP 7, 21 | 0x00/0x7F/0x80/0xFF at all 4 offsets |
| LH sign-ext, both offsets incl. boundary | ✅ GRP 8, 23 | 0x0000/0x7FFF/0x8000/0xFFFF at both |
| LW pass-through (AddrLSB=0 and ≠0) | ✅ GRP 9, 19 | AddrLSB-independent |
| LBU zero-ext 0xFF and 0x80 all offsets | ✅ GRP 10, 22 | No sign-extension confirmed |
| LHU zero-ext 0xFFFF and 0x8000 at both offsets | ✅ GRP 11, 23 | No sign-extension confirmed |
| Undefined load Funct3 → 0 | ✅ GRP 12 | Funct3 011, 110, 111 |
| Spec verbatim examples | ✅ GRP 13 | SB/SH/SW spec table examples |
| Store outputs zero during load | ✅ GRP 14, 20 | ByteEnable=0, WriteData=0 |
| Load outputs zero during store | ✅ GRP 15, 20 | LoadData=0 |
| Cross-path with non-trivial complementary inputs | ✅ GRP 20 | LB/LHU/SH/SB variants |

---

## Intentionally Out-of-Scope

- Misaligned halfword/word accesses and trap generation (outside Assignment 2 scope per spec §Alignment Scope).
- Timing / sequential behaviour (purely combinational DUT; no clock).
- Memory arbitration, stall signals, pipeline integration.
- Random/exhaustive 32-bit input sweep (not cost-effective; corner-based coverage is sufficient).

---

## Remaining Risk

**Low.** All spec-required load and store encodings are tested across alignment-legal byte offsets, with sign/zero extension verified at both positive and negative boundaries for all offsets. The only untested inputs are combinations the spec explicitly excludes (misaligned LH/LW, unused Funct3 encodings for loads beyond the three already exercised). These carry negligible integration risk.

---

## Simulation Evidence

| Metric | Before VERIFY | After VERIFY |
|--------|--------------|-------------|
| TESTS_TOTAL | 77 | **106** |
| TESTS_PASSED | 77 | **106** |
| TESTS_ERRORS | 0 | **0** |
| RESULT | PASS | **PASS** |
| compile_returncode | 0 | **0** |
| simulation_returncode | 0 | **0** |

*(Note: Icarus Verilog 12 emits 11 `sorry: constant selects in always_* processes are not currently supported` warnings at RTL line 21. These are tool-limitation diagnostics only; compile and simulation return codes remain 0 and all tests pass. No RTL change is warranted.)*

---

## Artifacts Modified

| File | Action |
|------|--------|
| `workspace/runs/a7_20261124T062636Z/tb/tb_memory_access.sv` | **Updated** – 8 new groups, 29 new vectors |
| `workspace/runs/a7_20261124T062636Z/reports/verification_audit.md` | **Created** (this report) |

RTL (`workspace/runs/a7_20261124T062636Z/src/memory_access.sv`) was **not modified** (VERIFY owns TB_PATH only).
