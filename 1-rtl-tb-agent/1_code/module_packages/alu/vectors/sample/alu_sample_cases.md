# Sample ALU Test Cases

These cases are supplied to students. The SystemVerilog testbench also checks the independent `Sum` output for every case.

| ID | Category | Description | ALUSelect | SubArith | A | B |
|---:|---|---|---|---:|---|---|
| 1 | ADD | ADD 1 + 2 | `000` | 0 | `00000001` | `00000002` |
| 2 | ADD | ADD zero + zero | `000` | 0 | `00000000` | `00000000` |
| 3 | ADD | ADD unsigned wraparound | `000` | 0 | `FFFFFFFF` | `00000001` |
| 4 | ADD | ADD signed positive overflow bits | `000` | 0 | `7FFFFFFF` | `00000001` |
| 5 | ADD | ADD two high-bit operands | `000` | 0 | `80000000` | `80000000` |
| 6 | SUB | SUB 3 - 2 | `000` | 1 | `00000003` | `00000002` |
| 7 | SUB | SUB zero - one | `000` | 1 | `00000000` | `00000001` |
| 8 | SUB | SUB min-int - one | `000` | 1 | `80000000` | `00000001` |
| 9 | SUB | SUB positive - negative-bit-pattern | `000` | 1 | `7FFFFFFF` | `FFFFFFFF` |
| 10 | SUB | SUB equal operands | `000` | 1 | `DEADBEEF` | `DEADBEEF` |
| 11 | LOGIC | XOR complementary patterns | `100` | 0 | `AAAAAAAA` | `55555555` |
| 12 | LOGIC | XOR identical patterns | `100` | 0 | `12345678` | `12345678` |
| 13 | LOGIC | OR complementary patterns | `110` | 0 | `AAAAAAAA` | `55555555` |
| 14 | LOGIC | OR sparse masks | `110` | 0 | `0000F000` | `0000000F` |
| 15 | LOGIC | AND complementary patterns | `111` | 0 | `AAAAAAAA` | `55555555` |
| 16 | LOGIC | AND overlapping masks | `111` | 0 | `FF00FF00` | `0F0F0F0F` |
| 17 | SLL | SLL by 0 | `001` | 0 | `12345678` | `00000000` |
| 18 | SLL | SLL by 1 | `001` | 0 | `00000001` | `00000001` |
| 19 | SLL | SLL by 31 | `001` | 0 | `00000001` | `0000001F` |
| 20 | SLL | SLL uses only B[4:0]: B=32 | `001` | 0 | `12345678` | `00000020` |
| 21 | SLL | SLL truncates shifted-out bits | `001` | 0 | `F000000F` | `00000004` |
| 22 | RIGHT_SHIFT | SRL high bit by 1 | `101` | 0 | `80000000` | `00000001` |
| 23 | RIGHT_SHIFT | SRA high bit by 1 | `101` | 1 | `80000000` | `00000001` |
| 24 | RIGHT_SHIFT | SRL by 31 | `101` | 0 | `80000000` | `0000001F` |
| 25 | RIGHT_SHIFT | SRA negative by 31 | `101` | 1 | `80000000` | `0000001F` |
| 26 | RIGHT_SHIFT | SRA positive by 4 | `101` | 1 | `70000000` | `00000004` |
| 27 | RIGHT_SHIFT | SRL uses only B[4:0]: B=33 | `101` | 0 | `80000000` | `00000021` |
| 28 | RIGHT_SHIFT | SRA uses only B[4:0]: B=33 | `101` | 1 | `80000000` | `00000021` |
| 29 | SLT | SLT -1 < 0 | `010` | 1 | `FFFFFFFF` | `00000000` |
| 30 | SLT | SLT 0 < -1 | `010` | 1 | `00000000` | `FFFFFFFF` |
| 31 | SLT | SLT min-int < max-int | `010` | 1 | `80000000` | `7FFFFFFF` |
| 32 | SLT | SLT max-int < min-int | `010` | 1 | `7FFFFFFF` | `80000000` |
| 33 | SLT | SLT equal | `010` | 1 | `81234567` | `81234567` |
| 34 | SLTU | SLTU FFFFFFFF < 0 | `011` | 1 | `FFFFFFFF` | `00000000` |
| 35 | SLTU | SLTU 0 < FFFFFFFF | `011` | 1 | `00000000` | `FFFFFFFF` |
| 36 | SLTU | SLTU 80000000 < 7FFFFFFF | `011` | 1 | `80000000` | `7FFFFFFF` |
| 37 | SLTU | SLTU equal | `011` | 1 | `81234567` | `81234567` |
| 38 | MIXED | XOR mixed arbitrary | `100` | 0 | `CAFEBABE` | `0BADF00D` |
| 39 | MIXED | SRA mixed negative | `101` | 1 | `F1234567` | `ABCDEF03` |
| 40 | MIXED | AND mixed arbitrary | `111` | 0 | `13579BDF` | `2468ACE0` |
