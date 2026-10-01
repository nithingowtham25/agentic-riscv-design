# RV32I ALU operations (reference)

Expected behavior of the core RV32I ALU operations (32-bit):

| Op   | Meaning                | Notes |
|------|------------------------|-------|
| ADD  | a + b                  | wraps mod 2^32 |
| SUB  | a - b                  | wraps mod 2^32 |
| AND  | a & b                  | bitwise |
| OR   | a \| b                 | bitwise |
| XOR  | a ^ b                  | bitwise |
| SLL  | a << b[4:0]            | shift amount is low 5 bits only |
| SRL  | a >> b[4:0]            | logical (zero-fill) right shift |
| SRA  | a >>> b[4:0]           | arithmetic (sign-extend) right shift; operand must be signed |
| SLT  | (signed)a < (signed)b  | result is 1 or 0; **signed** compare |
| SLTU | (unsigned)a < b        | result is 1 or 0; **unsigned** compare |

Common pitfalls: using an unsigned compare for SLT; using the full `b` as a shift
amount instead of `b[4:0]`; using logical `>>` where arithmetic `>>>` is required.
