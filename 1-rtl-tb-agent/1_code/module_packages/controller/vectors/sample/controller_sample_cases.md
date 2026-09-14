# Sample Controller Test Cases

The visible suite contains one representative encoding for every supported instruction form, plus three representative illegal encodings.

| ID | Category | Instruction | InstrD | Illegal? |
|---:|---|---|---|---:|
| 1 | R_TYPE | ADD | `003100B3` | 0 |
| 2 | R_TYPE | SUB | `403100B3` | 0 |
| 3 | R_TYPE | SLL | `003110B3` | 0 |
| 4 | R_TYPE | SLT | `003120B3` | 0 |
| 5 | R_TYPE | SLTU | `003130B3` | 0 |
| 6 | R_TYPE | XOR | `003140B3` | 0 |
| 7 | R_TYPE | SRL | `003150B3` | 0 |
| 8 | R_TYPE | SRA | `403150B3` | 0 |
| 9 | R_TYPE | OR | `003160B3` | 0 |
| 10 | R_TYPE | AND | `003170B3` | 0 |
| 11 | I_TYPE | ADDI | `A5510093` | 0 |
| 12 | I_TYPE | SLLI | `00711093` | 0 |
| 13 | I_TYPE | SLTI | `A5512093` | 0 |
| 14 | I_TYPE | SLTIU | `A5513093` | 0 |
| 15 | I_TYPE | XORI | `A5514093` | 0 |
| 16 | I_TYPE | SRLI | `00715093` | 0 |
| 17 | I_TYPE | SRAI | `40715093` | 0 |
| 18 | I_TYPE | ORI | `A5516093` | 0 |
| 19 | I_TYPE | ANDI | `A5517093` | 0 |
| 20 | LOAD | LB | `12310083` | 0 |
| 21 | LOAD | LH | `12311083` | 0 |
| 22 | LOAD | LW | `12312083` | 0 |
| 23 | LOAD | LBU | `12314083` | 0 |
| 24 | LOAD | LHU | `12315083` | 0 |
| 25 | STORE | SB | `FE310823` | 0 |
| 26 | STORE | SH | `FE311823` | 0 |
| 27 | STORE | SW | `FE312823` | 0 |
| 28 | BRANCH | BEQ | `00310863` | 0 |
| 29 | BRANCH | BNE | `00311863` | 0 |
| 30 | BRANCH | BLT | `00314863` | 0 |
| 31 | BRANCH | BGE | `00315863` | 0 |
| 32 | BRANCH | BLTU | `00316863` | 0 |
| 33 | BRANCH | BGEU | `00317863` | 0 |
| 34 | U_TYPE | LUI | `ABCDE0B7` | 0 |
| 35 | U_TYPE | AUIPC | `12345097` | 0 |
| 36 | JUMP | JAL | `020000EF` | 0 |
| 37 | JUMP | JALR | `00C100E7` | 0 |
| 38 | ILLEGAL | Illegal branch funct3=010 | `00312463` | 1 |
| 39 | ILLEGAL | Illegal JALR funct3=001 | `000110E7` | 1 |
| 40 | ILLEGAL | Illegal R-type funct7 | `403170B3` | 1 |
