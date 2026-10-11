MASK=0xffffffff

def u32(x): return x&MASK

def s32(x): x&=MASK; return x-(1<<32) if x&0x80000000 else x

def sext(x,b): x &= (1<<b)-1; return u32(x-(1<<b) if x&(1<<(b-1)) else x)

def r(op,rd,f3,rs1,rs2,f7): return u32((f7<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op)
def i(op,rd,f3,rs1,imm): return u32(((imm&0xfff)<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op)
def s(op,f3,rs1,rs2,imm):
    x=imm&0xfff; return u32(((x>>5)<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|((x&31)<<7)|op)
def b(op,f3,rs1,rs2,imm):
    x=imm&0x1fff; return u32((((x>>12)&1)<<31)|(((x>>5)&0x3f)<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(((x>>1)&0xf)<<8)|(((x>>11)&1)<<7)|op)
def u(op,rd,imm): return u32((imm&0xfffff000)|(rd<<7)|op)
def j(op,rd,imm):
    x=imm&0x1fffff; return u32((((x>>20)&1)<<31)|(((x>>1)&0x3ff)<<21)|(((x>>11)&1)<<20)|(((x>>12)&0xff)<<12)|(rd<<7)|op)
OP_LOAD=0x03; OP_IMM=0x13; OP_AUIPC=0x17; OP_STORE=0x23; OP_REG=0x33; OP_LUI=0x37; OP_BRANCH=0x63; OP_JALR=0x67; OP_JAL=0x6f

def ADD(rd,a,b): return r(OP_REG,rd,0,a,b,0)
def SUB(rd,a,b): return r(OP_REG,rd,0,a,b,0x20)
def SLL(rd,a,b): return r(OP_REG,rd,1,a,b,0)
def SLT(rd,a,b): return r(OP_REG,rd,2,a,b,0)
def SLTU(rd,a,b): return r(OP_REG,rd,3,a,b,0)
def XOR(rd,a,b): return r(OP_REG,rd,4,a,b,0)
def SRL(rd,a,b): return r(OP_REG,rd,5,a,b,0)
def SRA(rd,a,b): return r(OP_REG,rd,5,a,b,0x20)
def OR(rd,a,b): return r(OP_REG,rd,6,a,b,0)
def AND(rd,a,b): return r(OP_REG,rd,7,a,b,0)
def ADDI(rd,a,imm): return i(OP_IMM,rd,0,a,imm)
def SLLI(rd,a,sh): return i(OP_IMM,rd,1,a,sh)
def SLTI(rd,a,imm): return i(OP_IMM,rd,2,a,imm)
def SLTIU(rd,a,imm): return i(OP_IMM,rd,3,a,imm)
def XORI(rd,a,imm): return i(OP_IMM,rd,4,a,imm)
def SRLI(rd,a,sh): return i(OP_IMM,rd,5,a,sh)
def SRAI(rd,a,sh): return i(OP_IMM,rd,5,a,(0x20<<5)|(sh&31))
def ORI(rd,a,imm): return i(OP_IMM,rd,6,a,imm)
def ANDI(rd,a,imm): return i(OP_IMM,rd,7,a,imm)
def LB(rd,a,imm): return i(OP_LOAD,rd,0,a,imm)
def LH(rd,a,imm): return i(OP_LOAD,rd,1,a,imm)
def LW(rd,a,imm): return i(OP_LOAD,rd,2,a,imm)
def LBU(rd,a,imm): return i(OP_LOAD,rd,4,a,imm)
def LHU(rd,a,imm): return i(OP_LOAD,rd,5,a,imm)
def SB(a,breg,imm): return s(OP_STORE,0,a,breg,imm)
def SH(a,breg,imm): return s(OP_STORE,1,a,breg,imm)
def SW(a,breg,imm): return s(OP_STORE,2,a,breg,imm)
def BEQ(a,breg,imm): return b(OP_BRANCH,0,a,breg,imm)
def BNE(a,breg,imm): return b(OP_BRANCH,1,a,breg,imm)
def BLT(a,breg,imm): return b(OP_BRANCH,4,a,breg,imm)
def BGE(a,breg,imm): return b(OP_BRANCH,5,a,breg,imm)
def BLTU(a,breg,imm): return b(OP_BRANCH,6,a,breg,imm)
def BGEU(a,breg,imm): return b(OP_BRANCH,7,a,breg,imm)
def LUI(rd,imm): return u(OP_LUI,rd,imm)
def AUIPC(rd,imm): return u(OP_AUIPC,rd,imm)
def JAL(rd,imm): return j(OP_JAL,rd,imm)
def JALR(rd,a,imm): return i(OP_JALR,rd,0,a,imm)
