# Sample Immediate-Extension Test Cases

These 40 cases are provided to students. Each test supplies the exact `InstrD[31:7]` bus value used by the RTL module.

| ID | Format | Description | ImmSrcD | InstrD[31:7] | Expected ImmExtD |
|---:|---|---|---|---|---|
| 1 | I | I zero | `000` | `0000000` | `00000000` |
| 2 | I | I +1 | `000` | `0002000` | `00000001` |
| 3 | I | I -1 | `000` | `1FFE000` | `FFFFFFFF` |
| 4 | I | I max +2047 | `000` | `0FFE000` | `000007FF` |
| 5 | I | I min -2048 | `000` | `1000000` | `FFFFF800` |
| 6 | I | I +0x123 | `000` | `0246000` | `00000123` |
| 7 | I | I negative pattern -0x123 | `000` | `1DBA000` | `FFFFFEDD` |
| 8 | I | I sign boundary +1024 | `000` | `0800000` | `00000400` |
| 9 | S | S zero | `001` | `0000000` | `00000000` |
| 10 | S | S +1 | `001` | `0000001` | `00000001` |
| 11 | S | S -1 | `001` | `1FC001F` | `FFFFFFFF` |
| 12 | S | S max +2047 | `001` | `0FC001F` | `000007FF` |
| 13 | S | S min -2048 | `001` | `1000000` | `FFFFF800` |
| 14 | S | S low field only | `001` | `000001F` | `0000001F` |
| 15 | S | S high field only | `001` | `07C0000` | `000003E0` |
| 16 | S | S mixed fragmented bits | `001` | `0B40005` | `000005A5` |
| 17 | B | B zero | `010` | `0000000` | `00000000` |
| 18 | B | B +2 | `010` | `0000002` | `00000002` |
| 19 | B | B -2 | `010` | `1FC001F` | `FFFFFFFE` |
| 20 | B | B max +4094 | `010` | `0FC001F` | `00000FFE` |
| 21 | B | B min -4096 | `010` | `1000000` | `FFFFF000` |
| 22 | B | B bit11 only | `010` | `0000001` | `00000800` |
| 23 | B | B middle/low fields | `010` | `0AC000A` | `0000056A` |
| 24 | B | B negative fragmented | `010` | `1500017` | `FFFFFA96` |
| 25 | J | J zero | `011` | `0000000` | `00000000` |
| 26 | J | J +2 | `011` | `0004000` | `00000002` |
| 27 | J | J -2 | `011` | `1FFFFE0` | `FFFFFFFE` |
| 28 | J | J max +1048574 | `011` | `0FFFFE0` | `000FFFFE` |
| 29 | J | J min -1048576 | `011` | `1000000` | `FFF00000` |
| 30 | J | J bit11 only | `011` | `0002000` | `00000800` |
| 31 | J | J upper fragmented field | `011` | `0000B40` | `0005A000` |
| 32 | J | J mixed fragmented bits | `011` | `0654A80` | `0005432A` |
| 33 | U | U zero | `100` | `0000000` | `00000000` |
| 34 | U | U one upper unit | `100` | `0000020` | `00001000` |
| 35 | U | U all upper ones | `100` | `1FFFFE0` | `FFFFF000` |
| 36 | U | U sign bit only | `100` | `1000000` | `80000000` |
| 37 | U | U max positive-pattern | `100` | `0FFFFE0` | `7FFFF000` |
| 38 | U | U pattern ABCDE | `100` | `1579BC0` | `ABCDE000` |
| 39 | U | U pattern 12345 | `100` | `02468A0` | `12345000` |
| 40 | U | U alternating upper bits | `100` | `1555540` | `AAAAA000` |
