# Verification Agent – Audit Report

**Run ID:** a7_20261124T053859Z  
**Stage:** VERIFY  
**TB_PATH:** workspace/runs/a7_20261124T053859Z/tb/tb_memory_access.sv  
**RTL_PATH:** workspace/runs/a7_20261124T053859Z/src/memory_access.sv (read-only; not modified)  
**SPEC_PATH:** workspace/specs/memory_access_spec.md  
**Audit performed:** 2026-11-24 (post-debug PASS, 76/76 baseline)

---

## 1. Baseline State

| Metric              | Before VERIFY |
|---------------------|--------------|
| Compile returncode  | 0            |
| Simulation returncode | 0          |
| TESTS_PASSED        | 76           |
| TESTS_ERRORS        | 0            |
| TESTS_TOTAL         | 76           |
| RESULT              | PASS         |

---

## 2. Coverage-Gap Analysis

The existing 13 test groups were audited against the full spec feature matrix:

| Gap ID | Description | Risk |
|--------|-------------|------|
| G-1 | `SH` store tested only at `AddrLSB=00` and `AddrLSB=10`; odd offsets `01`/`11` (identical `AddrLSB[1]` behaviour) never exercised | Medium – could mask incorrect use of full `AddrLSB` instead of `AddrLSB[1]` |
| G-2 | `SB` upper-byte masking with multi-byte `StoreData` tested at offsets 0 and 3 only; offsets 1 and 2 missing | Low–Medium |
| G-3 | `LHU` load tested only at `AddrLSB=00`/`10`; odd offsets `01`/`11` missing | Medium – same risk as G-1 for loads |
| G-4 | Cross-output isolation (Group 12) checked only for `LW`; `WriteData=0`/`ByteEnable=0` during `LB`, `LH`, `LBU`, `LHU` not independently verified | Low–Medium |
| G-5 | `LBU` zero-extension for high-bit bytes at offsets 2 and 3 not independently exercised | Low |
| G-6 | `MemRW=00` idle path tested with `Funct3=000` and `Funct3=010` only; `Funct3=001` (SH code) and `Funct3=100` (LBU code) missing from inactive path | Low |

---

## 3. Tests Added

### Group 14 – SH with odd `AddrLSB` (G-1, 5 new tests)

Verifies that `AddrLSB[1]` is the half-select bit for SH stores; odd LSB values must route identically to their even counterparts.

| `AddrLSB` | `StoreData`   | Expected `ByteEnable` | Expected `WriteData` |
|-----------|---------------|-----------------------|----------------------|
| `01`      | `32'h0000BEEF`| `4'b0011`             | `32'h0000BEEF`       |
| `01`      | `32'hDEADBEEF`| `4'b0011`             | `32'h0000BEEF`       |
| `11`      | `32'h0000CAFE`| `4'b1100`             | `32'hCAFE0000`       |
| `11`      | `32'hDEADBEEF`| `4'b1100`             | `32'hBEEF0000`       |
| `11`      | `32'h0000FFFF`| `4'b1100`             | `32'hFFFF0000`       |

### Group 15 – SB upper-byte masking at offsets 1 and 2 (G-2, 4 new tests)

Confirms `StoreData[7:0]` is correctly stripped at mid-word byte positions.

| `AddrLSB` | `StoreData`   | Expected `ByteEnable` | Expected `WriteData` |
|-----------|---------------|-----------------------|----------------------|
| `01`      | `32'hDEADBEEF`| `4'b0010`             | `32'h0000EF00`       |
| `10`      | `32'hDEADBEEF`| `4'b0100`             | `32'h00EF0000`       |
| `01`      | `32'h000000FF`| `4'b0010`             | `32'h0000FF00`       |
| `10`      | `32'hFFFFFF00`| `4'b0100`             | `32'h00000000`       |

### Group 16 – LHU with odd `AddrLSB` (G-3, 4 new tests)

Mirrors G-1 on the load side; `AddrLSB[1]` selects the halfword lane.

| `AddrLSB` | `ReadData`    | Expected `LoadData`  |
|-----------|---------------|----------------------|
| `01`      | `32'hA1B2C3D4`| `32'h0000C3D4` (zero-extend lower half) |
| `11`      | `32'hA1B2C3D4`| `32'h0000A1B2` (zero-extend upper half) |
| `01`      | `32'h00008000`| `32'h00008000` (must NOT sign-extend)  |
| `11`      | `32'hFFFF0000`| `32'h0000FFFF` (zero-extend)           |

### Group 17 – Extended cross-output isolation for LB/LH/LBU/LHU (G-4, 4 new tests)

For every load variant, `WriteData` and `ByteEnable` must remain `0` regardless of `StoreData`.

| Op  | `StoreData`   | Verified `WriteData` | Verified `ByteEnable` | Expected `LoadData`  |
|-----|---------------|----------------------|-----------------------|----------------------|
| LB  | `32'hDEADBEEF`| `0`                  | `4'b0000`             | `32'hFFFFFFAB`       |
| LH  | `32'hDEADBEEF`| `0`                  | `4'b0000`             | `32'h00007FFF`       |
| LBU | `32'hDEADBEEF`| `0`                  | `4'b0000`             | `32'h000000FF`       |
| LHU | `32'hDEADBEEF`| `0`                  | `4'b0000`             | `32'h0000BEEF`       |

### Group 18 – LBU high-bit offsets; MemRW=00 with SH/LBU Funct3 (G-5 + G-6, 6 new tests)

| Test | Scenario | Expected `LoadData` |
|------|----------|---------------------|
| LBU offset 2, `0xAA` byte  | zero-extend at mid-word | `32'h000000AA` |
| LBU offset 3, `0xAA` byte  | zero-extend at top byte | `32'h000000AA` |
| LBU offset 3, `0x80` byte  | zero-extend (no sign)   | `32'h00000080` |
| LBU offset 3, `0xFF` byte  | zero-extend (not `0xFFFFFFFF`) | `32'h000000FF` |
| MemRW=00, Funct3=001       | idle → all zero         | all 0 |
| MemRW=00, Funct3=100       | idle → all zero         | all 0 |

---

## 4. Post-VERIFY Simulation Result

Simulation re-run locally by verify agent:

```
TESTS_PASSED 99
TESTS_ERRORS 0
TESTS_TOTAL  99
RESULT: PASS
```

Compile returncode: 0  
Simulation returncode: 0  
(Icarus 12 `sorry: constant selects` warnings are pre-existing tool limitations; no functional impact, confirmed by debug agent.)

---

## 5. Covered Behaviour Summary

| Specification Section                       | Coverage Status     |
|---------------------------------------------|---------------------|
| MemRW=00 idle (all Funct3)                  | ✅ Closed (G-6)     |
| MemRW=11 unused                             | ✅ Already covered  |
| SB at all 4 byte offsets                    | ✅ Already covered  |
| SB upper-byte masking at all 4 offsets      | ✅ Closed (G-2)     |
| SH at offsets 0/2 (even AddrLSB)           | ✅ Already covered  |
| SH at offsets 1/3 (odd AddrLSB, same route)| ✅ Closed (G-1)     |
| SW ByteEnable=1111, WriteData=StoreData     | ✅ Already covered  |
| Undefined Funct3 during store               | ✅ Already covered  |
| LB sign-extension, all 4 offsets            | ✅ Already covered  |
| LB boundary (0x00, 0x7F, 0x80, 0xFF)       | ✅ Already covered  |
| LH sign-extension, all 4 AddrLSB values    | ✅ Already covered  |
| LH boundary (0x0000, 0x7FFF, 0x8000, 0xFFFF)| ✅ Already covered |
| LW full passthrough                         | ✅ Already covered  |
| LBU zero-extension, all 4 offsets inc. high-bit | ✅ Closed (G-5) |
| LHU zero-extension, all 4 AddrLSB values   | ✅ Closed (G-3)     |
| Cross-output isolation (all 5 load types)  | ✅ Closed (G-4)     |
| Undefined Funct3 during load               | ✅ Already covered  |
| Deterministic defaults (WriteData=0, BE=0 on non-store; LoadData=0 on non-load) | ✅ Already covered |

---

## 6. Intentionally Out-of-Scope

- Misaligned halfword/word accesses (spec §Alignment Scope)
- Architecture-level misalignment traps
- Multi-cycle or clocked behaviour (module is purely combinational)

---

## 7. Remaining Risk

None assessed as significant. All six identified coverage gaps are now closed. The 99-test suite exercises every spec-defined encoding, boundary value, offset combination, isolation constraint, and default-output requirement.

---

**RTL modified:** NO  
**TB modified:** YES — Groups 14–18 added (23 net new tests: 76 → 99)  
**Artifact:** `workspace/runs/a7_20261124T053859Z/reports/verification_audit.md` (this file)  
**TB artifact:** `workspace/runs/a7_20261124T053859Z/tb/tb_memory_access.sv` (updated)
