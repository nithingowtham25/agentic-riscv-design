# iss.py: Full architectural RV32I instruction-set simulator (reference model for Assignment 3).
# iss.py: Models registers, a byte-addressable data memory, branches, jumps, and loads/stores.
# iss.py: This is the correctness oracle: a pipelined core is correct iff, for every test program,
# iss.py: its committed state matches this ISS. Timing/pipelining are irrelevant here by design.
from rv32i_isa import (u32, s32, sext,
    OP_LOAD, OP_IMM, OP_AUIPC, OP_STORE, OP_REG, OP_LUI, OP_BRANCH, OP_JALR, OP_JAL)

SIG_ADDR = 0x00000100          # a full-word store here ends the program (matches core_tb.sv)


class ISS:
    """Cycle-agnostic RV32I simulator. Memory is a dict of word-addr -> 32-bit value."""

    def __init__(self, imem_words, max_steps=100000):
        self.regs = [0] * 32
        self.pc = 0
        self.imem = list(imem_words)
        self.mem = {}
        self.max_steps = max_steps
        self.signature = None      # value written to SIG_ADDR, if any
        self.halted = False

    # ---- memory helpers (little-endian, word store dict) ----
    def _load_word(self, addr):
        return self.mem.get(addr >> 2, 0)

    def _store_word(self, addr, val):
        self.mem[addr >> 2] = u32(val)

    def _load(self, addr, funct3):
        w = self._load_word(addr)
        off = addr & 3
        if funct3 == 0:   # LB
            byte = (w >> (8 * off)) & 0xff
            return sext(byte, 8)
        if funct3 == 4:   # LBU
            return (w >> (8 * off)) & 0xff
        if funct3 == 1:   # LH
            half = (w >> (16 * (off >> 1))) & 0xffff
            return sext(half, 16)
        if funct3 == 5:   # LHU
            return (w >> (16 * (off >> 1))) & 0xffff
        if funct3 == 2:   # LW
            return w
        return 0

    def _store(self, addr, val, funct3):
        off = addr & 3
        if funct3 == 0:   # SB
            w = self._load_word(addr)
            mask = 0xff << (8 * off)
            self._store_word(addr, (w & ~mask) | ((val & 0xff) << (8 * off)))
        elif funct3 == 1:  # SH
            w = self._load_word(addr)
            sh = 16 * (off >> 1)
            mask = 0xffff << sh
            self._store_word(addr, (w & ~mask) | ((val & 0xffff) << sh))
        elif funct3 == 2:  # SW
            self._store_word(addr, val)
            if addr == SIG_ADDR:
                self.signature = u32(val)
                self.halted = True

    # ---- single-instruction execution ----
    def step(self):
        ins = self.imem[self.pc >> 2] if (self.pc >> 2) < len(self.imem) else 0x00000013
        op = ins & 0x7f
        rd = (ins >> 7) & 31
        f3 = (ins >> 12) & 7
        rs1 = (ins >> 15) & 31
        rs2 = (ins >> 20) & 31
        f7 = (ins >> 25) & 0x7f
        a = self.regs[rs1]
        bval = self.regs[rs2]
        next_pc = u32(self.pc + 4)
        val = None

        if op == OP_REG:
            if f3 == 0:   val = u32(a - bval) if f7 == 0x20 else u32(a + bval)
            elif f3 == 1: val = u32(a << (bval & 31))
            elif f3 == 2: val = int(s32(a) < s32(bval))
            elif f3 == 3: val = int(a < bval)
            elif f3 == 4: val = a ^ bval
            elif f3 == 5: val = u32(s32(a) >> (bval & 31)) if f7 == 0x20 else a >> (bval & 31)
            elif f3 == 6: val = a | bval
            elif f3 == 7: val = a & bval
        elif op == OP_IMM:
            imm = sext(ins >> 20, 12)
            sh = (ins >> 20) & 31
            if f3 == 0:   val = u32(a + imm)
            elif f3 == 1: val = u32(a << sh)
            elif f3 == 2: val = int(s32(a) < s32(imm))
            elif f3 == 3: val = int(a < u32(imm))
            elif f3 == 4: val = a ^ u32(imm)
            elif f3 == 5: val = u32(s32(a) >> sh) if ((ins >> 30) & 1) else a >> sh
            elif f3 == 6: val = a | u32(imm)
            elif f3 == 7: val = a & u32(imm)
        elif op == OP_LUI:
            val = ins & 0xfffff000
        elif op == OP_AUIPC:
            val = u32(self.pc + (ins & 0xfffff000))
        elif op == OP_LOAD:
            imm = sext(ins >> 20, 12)
            val = u32(self._load(u32(a + imm), f3))
        elif op == OP_STORE:
            imm_lo = (ins >> 7) & 0x1f
            imm_hi = (ins >> 25) & 0x7f
            imm = sext((imm_hi << 5) | imm_lo, 12)
            self._store(u32(a + imm), bval, f3)
        elif op == OP_BRANCH:
            imm = sext((((ins >> 31) & 1) << 12) | (((ins >> 7) & 1) << 11) |
                       (((ins >> 25) & 0x3f) << 5) | (((ins >> 8) & 0xf) << 1), 13)
            take = {0: a == bval, 1: a != bval, 4: s32(a) < s32(bval),
                    5: s32(a) >= s32(bval), 6: a < bval, 7: a >= bval}.get(f3, False)
            if take:
                next_pc = u32(self.pc + imm)
        elif op == OP_JAL:
            imm = sext((((ins >> 31) & 1) << 20) | (((ins >> 12) & 0xff) << 12) |
                       (((ins >> 20) & 1) << 11) | (((ins >> 21) & 0x3ff) << 1), 21)
            val = next_pc
            next_pc = u32(self.pc + imm)
        elif op == OP_JALR:
            imm = sext(ins >> 20, 12)
            val = next_pc
            next_pc = u32(a + imm) & ~1

        if val is not None and rd != 0:
            self.regs[rd] = u32(val)
        self.regs[0] = 0
        self.pc = next_pc

    def run(self):
        steps = 0
        while not self.halted and steps < self.max_steps:
            self.step()
            steps += 1
        return self.regs, self.signature
