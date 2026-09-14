# Sample Register-File Test Transactions

The sample suite is stateful and must be executed in order. `edge=1` causes one falling clock edge before the expected read outputs are checked; `edge=0` checks combinational reads without a state transition.

| ID | Category | Description | Edge | Reset | WE3 | A1 | A2 | A3 | WD3 |
|---:|---|---|---:|---:|---:|---:|---:|---:|---|
| 1 | RESET | Reset all writable registers | 1 | 1 | 0 | 0 | 0 | 0 | `00000000` |
| 2 | X0 | Read x0 from both ports | 0 | 0 | 0 | 0 | 0 | 0 | `00000000` |
| 3 | READ | Read unwritten x1 and x31 after reset | 0 | 0 | 0 | 1 | 31 | 0 | `00000000` |
| 4 | TIMING | Prepare write to x5 without a falling edge | 0 | 0 | 1 | 5 | 0 | 5 | `12345678` |
| 5 | WRITE | Commit x5 write on falling edge | 1 | 0 | 1 | 5 | 0 | 5 | `12345678` |
| 6 | DUAL_READ | Read x5 simultaneously from both ports | 0 | 0 | 0 | 5 | 5 | 0 | `00000000` |
| 7 | WRITE | Write x7 = DEADBEEF | 1 | 0 | 1 | 5 | 7 | 7 | `DEADBEEF` |
| 8 | DUAL_READ | Read x5 and x7 independently | 0 | 0 | 0 | 5 | 7 | 0 | `00000000` |
| 9 | DUAL_READ | Swap read-port addresses x7 and x5 | 0 | 0 | 0 | 7 | 5 | 0 | `00000000` |
| 10 | WRITE_DISABLE | Attempt to overwrite x5 with write-enable low | 1 | 0 | 0 | 5 | 7 | 5 | `AAAAAAAA` |
| 11 | WRITE_DISABLE | Confirm x5 was not modified | 0 | 0 | 0 | 5 | 7 | 0 | `00000000` |
| 12 | OVERWRITE | Overwrite x5 with CAFEBABE | 1 | 0 | 1 | 5 | 7 | 5 | `CAFEBABE` |
| 13 | OVERWRITE | Confirm x5 new value and x7 unchanged | 0 | 0 | 0 | 5 | 7 | 0 | `00000000` |
| 14 | X0 | Attempt write FFFFFFFF to x0 | 1 | 0 | 1 | 0 | 5 | 0 | `FFFFFFFF` |
| 15 | X0 | Confirm x0 is still zero | 0 | 0 | 0 | 0 | 0 | 0 | `00000000` |
| 16 | X0 | Confirm x5 remains intact after x0 write | 0 | 0 | 0 | 5 | 0 | 0 | `00000000` |
| 17 | WRITE | Write x1 | 1 | 0 | 1 | 1 | 31 | 1 | `00000001` |
| 18 | WRITE | Write x31 | 1 | 0 | 1 | 1 | 31 | 31 | `FFFFFFFF` |
| 19 | DUAL_READ | Read x1 and x31 | 0 | 0 | 0 | 1 | 31 | 0 | `00000000` |
| 20 | WRITE | Write x16 = 80000000 | 1 | 0 | 1 | 16 | 7 | 16 | `80000000` |
| 21 | WRITE | Write x17 = 7FFFFFFF | 1 | 0 | 1 | 16 | 17 | 17 | `7FFFFFFF` |
| 22 | DUAL_READ | Read x16 and x17 | 0 | 0 | 0 | 16 | 17 | 0 | `00000000` |
| 23 | WRITE | Write x30 = 00000000 | 1 | 0 | 1 | 30 | 31 | 30 | `00000000` |
| 24 | DUAL_READ | Read explicitly written zero and x31 | 0 | 0 | 0 | 30 | 31 | 0 | `00000000` |
| 25 | RESET | Reset while requesting write x9 = ABCDEF01 | 1 | 1 | 1 | 9 | 5 | 9 | `ABCDEF01` |
| 26 | RESET | Confirm reset cleared x5 and x7 | 0 | 0 | 0 | 5 | 7 | 0 | `00000000` |
| 27 | RESET | Confirm reset suppressed x9 write | 0 | 0 | 0 | 9 | 16 | 0 | `00000000` |
| 28 | WRITE | Write x9 after reset | 1 | 0 | 1 | 9 | 0 | 9 | `ABCDEF01` |
| 29 | DUAL_READ | Read x9 and x0 | 0 | 0 | 0 | 9 | 0 | 0 | `00000000` |
| 30 | TIMING | No-edge write request must not change x9 | 0 | 0 | 1 | 9 | 0 | 9 | `11111111` |
| 31 | TIMING | Read x9 again before edge | 0 | 0 | 0 | 9 | 0 | 0 | `00000000` |
| 32 | OVERWRITE | Commit new x9 value | 1 | 0 | 1 | 9 | 0 | 9 | `11111111` |
| 33 | READ | Read committed x9 | 0 | 0 | 0 | 9 | 9 | 0 | `00000000` |
| 34 | WRITE | Write x2 pattern | 1 | 0 | 1 | 2 | 9 | 2 | `22222222` |
| 35 | WRITE | Write x15 pattern | 1 | 0 | 1 | 2 | 15 | 15 | `15151515` |
| 36 | WRITE | Write x29 pattern | 1 | 0 | 1 | 29 | 15 | 29 | `29292929` |
| 37 | DUAL_READ | Read x2 and x29 | 0 | 0 | 0 | 2 | 29 | 0 | `00000000` |
| 38 | DUAL_READ | Read x15 and x9 | 0 | 0 | 0 | 15 | 9 | 0 | `00000000` |
| 39 | X0 | Final x0/readable-register check | 0 | 0 | 0 | 0 | 29 | 0 | `00000000` |
