# -*- coding: utf-8 -*-
"""Generate the directed RV32I + Zicsr test program and golden results.

The output is consumed by model_tb/tb_top.v:
    program.hex          instruction memory image
    expected.hex         expected data-memory result words (dmem[0..N-1])
    trap_expected.hex    expected mcause values, in trap order
    defs.vh              TEST_NUM_RESULTS / TEST_NUM_TRAPS
    checks.txt           index -> test name (for humans)

Usage:
    python program/gen_test.py
"""

import os

# ---------------------------------------------------------------------------
# CSR addresses
# ---------------------------------------------------------------------------
CSR_MSTATUS  = 0x300
CSR_MISA     = 0x301
CSR_MIE      = 0x304
CSR_MTVEC    = 0x305
CSR_MSCRATCH = 0x340
CSR_MEPC     = 0x341
CSR_MCAUSE   = 0x342
CSR_MTVAL    = 0x343
CSR_MIP      = 0x344
CSR_MCYCLE   = 0xB00
CSR_MINSTRET = 0xB02
CSR_MCYCLEH  = 0xB80
CSR_MINSTRETH = 0xB82
CSR_MHARTID  = 0xF14

R_INSTR = {
    "add":  (0x00, 0), "sub":  (0x20, 0), "sll":  (0x00, 1),
    "slt":  (0x00, 2), "sltu": (0x00, 3), "xor":  (0x00, 4),
    "srl":  (0x00, 5), "sra":  (0x20, 5), "or":   (0x00, 6),
    "and":  (0x00, 7),
}
I_INSTR = {"addi": 0, "slti": 2, "sltiu": 3, "xori": 4, "ori": 6, "andi": 7}
LOADS   = {"lb": 0, "lh": 1, "lw": 2, "lbu": 4, "lhu": 5}
STORES  = {"sb": 0, "sh": 1, "sw": 2}
BRANCH  = {"beq": 0, "bne": 1, "blt": 4, "bge": 5, "bltu": 6, "bgeu": 7}
CSR_F3  = {"csrrw": 1, "csrrs": 2, "csrrc": 3,
           "csrrwi": 5, "csrrsi": 6, "csrrci": 7}


def u32(x):
    return x & 0xFFFFFFFF


class Asm:
    def __init__(self):
        self.words = []
        self.labels = {}
        self.fixups = []
        self.results = []
        self.traps = []

    # ------------------------------------------------------------------
    # basic emission
    # ------------------------------------------------------------------
    def pc(self):
        return len(self.words) * 4

    def label(self, name):
        self.labels[name] = self.pc()

    def emit(self, word):
        self.words.append(word & 0xFFFFFFFF)

    def nop(self):
        self.i("addi", 0, 0, 0)

    # ------------------------------------------------------------------
    # encoders
    # ------------------------------------------------------------------
    def r(self, name, rd, rs1, rs2):
        f7, f3 = R_INSTR[name]
        self.emit((f7 << 25) | ((rs2 & 31) << 20) | ((rs1 & 31) << 15) |
                  (f3 << 12) | ((rd & 31) << 7) | 0x33)

    def i(self, name, rd, rs1, imm):
        imm &= 0xFFF
        if name in I_INSTR:
            f3 = I_INSTR[name]
        elif name == "slli":
            f3 = 1
        elif name in ("srli", "srai"):
            f3 = 5
            if name == "srai":
                imm = 0x400 | (imm & 0x1F)
        else:
            raise ValueError(name)
        self.emit((imm << 20) | ((rs1 & 31) << 15) | (f3 << 12) |
                  ((rd & 31) << 7) | 0x13)

    def lui(self, rd, imm20):
        self.emit(((imm20 & 0xFFFFF) << 12) | ((rd & 31) << 7) | 0x37)

    def auipc(self, rd, imm20):
        self.emit(((imm20 & 0xFFFFF) << 12) | ((rd & 31) << 7) | 0x17)

    def load(self, name, rd, rs1, imm):
        self.emit(((imm & 0xFFF) << 20) | ((rs1 & 31) << 15) |
                  (LOADS[name] << 12) | ((rd & 31) << 7) | 0x03)

    def store(self, name, rs2, rs1, imm):
        imm &= 0xFFF
        self.emit((((imm >> 5) & 0x7F) << 25) | ((rs2 & 31) << 20) |
                  ((rs1 & 31) << 15) | (STORES[name] << 12) |
                  ((imm & 0x1F) << 7) | 0x23)

    def jalr(self, rd, rs1, imm):
        self.emit(((imm & 0xFFF) << 20) | ((rs1 & 31) << 15) |
                  ((rd & 31) << 7) | 0x67)

    def csr(self, name, rd, addr, rs1_or_zimm):
        self.emit(((addr & 0xFFF) << 20) | ((rs1_or_zimm & 31) << 15) |
                  (CSR_F3[name] << 12) | ((rd & 31) << 7) | 0x73)

    def csrr(self, rd, addr):
        self.csr("csrrs", rd, addr, 0)

    def csrw(self, addr, rs1):
        self.csr("csrrw", 0, addr, rs1)

    def fence(self):
        self.emit(0x0FF0000F)

    def fence_i(self):
        self.emit(0x0000100F)

    def ecall(self):
        self.emit(0x00000073)

    def ebreak(self):
        self.emit(0x00100073)

    def mret(self):
        self.emit(0x30200073)

    def word(self, value):
        self.emit(value)

    def li(self, rd, value):
        value = u32(value)
        sval = value if value < 0x80000000 else value - 0x100000000
        if -2048 <= sval <= 2047:
            self.i("addi", rd, 0, sval)
        else:
            hi = ((value + 0x800) >> 12) & 0xFFFFF
            lo = value - (hi << 12)
            if lo >= 0x800:
                lo -= 0x1000
            self.lui(rd, hi)
            self.i("addi", rd, rd, lo)

    # ------------------------------------------------------------------
    # labels / fixups
    # ------------------------------------------------------------------
    def branch(self, name, rs1, rs2, label):
        idx = len(self.words)
        self.emit(0)
        self.fixups.append(("b", idx, label, rs1, rs2, BRANCH[name]))

    def jal(self, rd, label):
        idx = len(self.words)
        self.emit(0)
        self.fixups.append(("j", idx, label, rd))

    def la(self, rd, label):
        idx = len(self.words)
        self.emit(0)
        self.emit(0)
        self.fixups.append(("la", idx, label, rd))

    def check(self, name, expected, reg=5):
        off = len(self.results) * 4
        if off > 2047:
            raise ValueError("too many result words")
        self.store("sw", reg, 1, off)
        self.results.append((name, u32(expected)))

    def expect_trap(self, cause):
        self.traps.append(cause)

    # ------------------------------------------------------------------
    def finalize(self):
        for fx in self.fixups:
            kind, idx = fx[0], fx[1]
            label = fx[2]
            if label not in self.labels:
                raise KeyError("undefined label: %s" % label)
            off = self.labels[label] - idx * 4
            if kind == "b":
                _, _, _, rs1, rs2, f3 = fx
                imm = off & 0x1FFF
                w = (((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) | \
                    ((rs2 & 31) << 20) | ((rs1 & 31) << 15) | (f3 << 12) | \
                    (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 1) << 7) | 0x63
                self.words[idx] = w
            elif kind == "j":
                _, _, _, rd = fx
                imm = off & 0x1FFFFF
                w = (((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3FF) << 21) | \
                    (((imm >> 11) & 1) << 20) | (((imm >> 12) & 0xFF) << 12) | \
                    ((rd & 31) << 7) | 0x6F
                self.words[idx] = w
            elif kind == "la":
                _, _, _, rd = fx
                addr = self.labels[label]
                hi = ((addr + 0x800) >> 12) & 0xFFFFF
                lo = addr - (hi << 12)
                if lo >= 0x800:
                    lo -= 0x1000
                self.words[idx] = ((hi & 0xFFFFF) << 12) | ((rd & 31) << 7) | 0x37
                self.words[idx + 1] = ((lo & 0xFFF) << 20) | ((rd & 31) << 15) | \
                                      ((rd & 31) << 7) | 0x13
            else:
                raise ValueError(kind)


# ===========================================================================
# program
# ===========================================================================
a = Asm()

# Entry: jump over the trap handler.
a.jal(0, "_start")
while a.pc() < 0x80:
    a.nop()

# ---------------------------------------------------------------------------
# Trap handler: log mcause/mepc/mtval, skip the faulting instruction, mret.
#   x27 = log pointer, x31 = trap count; x28..x30 = scratch.
# ---------------------------------------------------------------------------
a.label("trap_handler")
a.csrr(28, CSR_MCAUSE)
a.csrr(29, CSR_MEPC)
a.csrr(30, CSR_MTVAL)
a.store("sw", 28, 27, 0)
a.store("sw", 29, 27, 4)
a.store("sw", 30, 27, 8)
a.i("addi", 27, 27, 12)
a.i("addi", 31, 31, 1)
a.i("addi", 29, 29, 4)
a.csrw(CSR_MEPC, 29)
a.mret()

while a.pc() < 0x100:
    a.nop()

# ---------------------------------------------------------------------------
# Start
# ---------------------------------------------------------------------------
a.label("_start")
a.i("addi", 1, 0, 0)        # result pointer
a.i("addi", 2, 0, 0x400)    # data base for load/store tests
a.i("addi", 27, 0, 0x600)   # trap log pointer
a.i("addi", 31, 0, 0)       # trap count
a.la(3, "trap_handler")
a.csrw(CSR_MTVEC, 3)

# ---------------------------------------------------------------------------
# R-type
# ---------------------------------------------------------------------------
a.i("addi", 3, 0, 10)
a.i("addi", 4, 0, 3)

a.r("add", 5, 3, 4);  a.check("ADD", 13)
a.r("sub", 5, 3, 4);  a.check("SUB", 7)
a.r("sll", 5, 3, 4);  a.check("SLL", 80)
a.r("slt", 5, 4, 3);  a.check("SLT", 1)
a.r("sltu", 5, 4, 3); a.check("SLTU", 1)
a.r("xor", 5, 3, 4);  a.check("XOR", 9)
a.r("srl", 5, 3, 4);  a.check("SRL", 1)
a.r("sra", 5, 3, 4);  a.check("SRA", 1)
a.r("or", 5, 3, 4);   a.check("OR", 11)
a.r("and", 5, 3, 4);  a.check("AND", 2)

a.i("addi", 3, 0, -8)
a.i("addi", 4, 0, 2)
a.r("sra", 5, 3, 4);  a.check("SRA_NEG", -2)
a.r("slt", 5, 3, 4);  a.check("SLT_NEG", 1)
a.r("sltu", 5, 3, 4); a.check("SLTU_NEG", 0)

# ---------------------------------------------------------------------------
# I-type
# ---------------------------------------------------------------------------
a.i("addi", 5, 0, -5);       a.check("ADDI", -5)
a.i("slti", 5, 3, -4);       a.check("SLTI", 1)
a.i("sltiu", 5, 3, -4);      a.check("SLTIU", 1)
a.i("xori", 5, 3, 0x0F);     a.check("XORI", -9)
a.i("ori", 5, 3, 0x0F);      a.check("ORI", -1)
a.i("andi", 5, 3, 0x0F);     a.check("ANDI", 8)
a.i("slli", 5, 3, 2);        a.check("SLLI", -32)
a.i("srli", 5, 3, 2);        a.check("SRLI", 0x3FFFFFFE)
a.i("srai", 5, 3, 2);        a.check("SRAI", -2)

# ---------------------------------------------------------------------------
# Loads / stores
# ---------------------------------------------------------------------------
a.i("addi", 3, 0, -1)
a.store("sw", 3, 2, 0)            # dmem[0x400] = 0xFFFFFFFF
a.lui(4, 0x1)
a.i("addi", 4, 4, 0x234)          # 0x1234
a.store("sh", 4, 2, 4)            # dmem[0x404] = 0x1234
a.i("addi", 4, 0, 0x55)
a.store("sb", 4, 2, 7)            # dmem[0x407] = 0x55

a.load("lb", 5, 2, 0);   a.check("LB", -1)
a.load("lbu", 5, 2, 0);  a.check("LBU", 255)
a.load("lh", 5, 2, 4);   a.check("LH", 0x1234)
a.load("lhu", 5, 2, 4);  a.check("LHU", 0x1234)
a.load("lw", 5, 2, 0);   a.check("LW", -1)
a.load("lbu", 5, 2, 5);  a.check("LBU_OFFSET", 0x12)
a.load("lh", 5, 2, 2);   a.check("LH_OFFSET", -1)
a.load("lb", 5, 2, 7);   a.check("LB_OFFSET", 0x55)

# ---------------------------------------------------------------------------
# Branches: taken / not-taken pairs
# ---------------------------------------------------------------------------
branch_id = 0


def branch_test(name, op, va, vb, taken):
    global branch_id
    tag = branch_id
    branch_id += 1
    a.li(3, va)
    a.li(4, vb)
    a.i("addi", 5, 0, 0)
    a.branch(op, 3, 4, "br_taken_%d" % tag)
    a.jal(0, "br_end_%d" % tag)
    a.label("br_taken_%d" % tag)
    a.i("addi", 5, 0, 1)
    a.label("br_end_%d" % tag)
    a.check(name, 1 if taken else 0)


branch_test("BEQ_TAKEN", "beq", 5, 5, True)
branch_test("BEQ_NOT", "beq", 5, 6, False)
branch_test("BNE_TAKEN", "bne", 5, 6, True)
branch_test("BNE_NOT", "bne", 5, 5, False)
branch_test("BLT_TAKEN", "blt", -1, 1, True)
branch_test("BLT_NOT", "blt", 1, -1, False)
branch_test("BGE_TAKEN", "bge", 1, -1, True)
branch_test("BGE_NOT", "bge", -1, 1, False)
branch_test("BLTU_TAKEN", "bltu", 1, -1, True)
branch_test("BLTU_NOT", "bltu", -1, 1, False)
branch_test("BGEU_TAKEN", "bgeu", -1, 1, True)
branch_test("BGEU_NOT", "bgeu", 1, -1, False)

# ---------------------------------------------------------------------------
# JAL / JALR
# ---------------------------------------------------------------------------
a.jal(5, "jal_target")
a.label("jal_link")
a.i("addi", 6, 0, 0)              # skipped
a.label("jal_target")
a.i("addi", 6, 0, 0x55)
a.la(7, "jal_link")
a.r("sub", 8, 5, 7)
a.check("JAL_LINK", 0, 8)
a.check("JAL_TARGET", 0x55, 6)

# JAL link used by the immediately following instruction (PC+4 forwarding)
a.label("jal_fwd")
a.jal(5, "jal_fwd_target")
a.label("jal_fwd_target")
a.r("add", 6, 5, 0)
a.la(7, "jal_fwd_target")
a.r("sub", 8, 6, 7)
a.check("JAL_LINK_FWD", 0, 8)

a.la(7, "jalr_target")
a.jalr(8, 7, 0)
a.label("jalr_link")
a.i("addi", 6, 0, 0)              # skipped
a.label("jalr_target")
a.i("addi", 6, 0, 0x66)
a.la(9, "jalr_link")
a.r("sub", 10, 8, 9)
a.check("JALR_LINK", 0, 10)
a.check("JALR_TARGET", 0x66, 6)

# ---------------------------------------------------------------------------
# LUI / AUIPC
# ---------------------------------------------------------------------------
a.lui(5, 0x12345)
a.check("LUI", 0x12345000)

a.label("auipc0")
a.auipc(5, 0)
a.la(6, "auipc0")
a.r("sub", 7, 5, 6)
a.check("AUIPC", 0, 7)

a.label("auipc1")
a.auipc(5, 1)
a.la(6, "auipc1")
a.r("sub", 7, 5, 6)
a.check("AUIPC_HI", 0x1000, 7)

# ---------------------------------------------------------------------------
# FENCE / FENCE.I
# ---------------------------------------------------------------------------
a.fence()
a.i("addi", 5, 0, 0x11)
a.fence_i()
a.i("addi", 6, 0, 0x22)
a.check("FENCE", 0x11)
a.check("FENCE_I", 0x22, 6)

# ---------------------------------------------------------------------------
# CSR instructions
# ---------------------------------------------------------------------------
a.li(3, 0x0F0)
a.csrw(CSR_MSCRATCH, 3)
a.csrr(4, CSR_MSCRATCH)
a.check("CSR_READ", 0x0F0, 4)

a.li(5, 0x00F)
a.csr("csrrw", 6, CSR_MSCRATCH, 5)
a.check("CSRRW_OLD", 0x0F0, 6)
a.csrr(7, CSR_MSCRATCH)
a.check("CSRRW_NEW", 0x00F, 7)

a.li(8, 0x300)
a.csr("csrrs", 9, CSR_MSCRATCH, 8)
a.check("CSRRS_OLD", 0x00F, 9)
a.csrr(10, CSR_MSCRATCH)
a.check("CSRRS_NEW", 0x30F, 10)

a.li(11, 0x3FF)
a.csrw(CSR_MSCRATCH, 11)
a.li(12, 0x0F0)
a.csr("csrrc", 13, CSR_MSCRATCH, 12)
a.check("CSRRC_OLD", 0x3FF, 13)
a.csrr(14, CSR_MSCRATCH)
a.check("CSRRC_NEW", 0x30F, 14)

a.csr("csrrwi", 15, CSR_MSCRATCH, 5)
a.check("CSRRWI_OLD", 0x30F, 15)
a.csrr(16, CSR_MSCRATCH)
a.check("CSRRWI_NEW", 5, 16)

a.csr("csrrsi", 17, CSR_MSCRATCH, 0x10)
a.check("CSRRSI_OLD", 5, 17)
a.csrr(18, CSR_MSCRATCH)
a.check("CSRRSI_NEW", 0x15, 18)

a.csr("csrrci", 19, CSR_MSCRATCH, 0x01)
a.check("CSRRCI_OLD", 0x15, 19)
a.csrr(20, CSR_MSCRATCH)
a.check("CSRRCI_NEW", 0x14, 20)

a.csr("csrrs", 21, CSR_MSCRATCH, 0)
a.check("CSR_PURE_READ", 0x14, 21)
a.csrr(22, CSR_MSCRATCH)
a.check("CSR_PURE_READ_NEW", 0x14, 22)

a.csrr(23, CSR_MHARTID)
a.check("CSR_MHARTID", 0, 23)
a.csrr(24, CSR_MISA)
a.check("CSR_MISA", 0x40000100, 24)

a.csrr(25, CSR_MTVEC)
a.la(26, "trap_handler")
a.r("sub", 5, 25, 26)
a.check("CSR_MTVEC", 0, 5)

a.csrr(5, CSR_MSTATUS)
a.check("CSR_MSTATUS_INIT", 0, 5)

a.csrr(5, CSR_MCYCLE)
a.csrr(6, CSR_MCYCLE)
a.r("sltu", 7, 5, 6)
a.check("CSR_MCYCLE_MONO", 1, 7)

a.csrr(5, CSR_MINSTRET)
a.csrr(6, CSR_MINSTRET)
a.r("sltu", 7, 5, 6)
a.check("CSR_MINSTRET_MONO", 1, 7)

a.li(5, 0x8)
a.csrw(CSR_MSTATUS, 5)
a.csrr(6, CSR_MSTATUS)
a.check("CSR_MSTATUS_WRITE", 0x8, 6)

a.li(5, 0x80)
a.csrw(CSR_MIE, 5)
a.csrr(6, CSR_MIE)
a.check("CSR_MIE", 0x80, 6)

a.li(5, 0)
a.csrw(CSR_MIP, 5)
a.csrr(6, CSR_MIP)
a.check("CSR_MIP", 0, 6)

# CSRRSI with zimm=0 must not write
a.li(3, 0x55)
a.csrw(CSR_MSCRATCH, 3)
a.csr("csrrsi", 5, CSR_MSCRATCH, 0)
a.check("CSRRSI_ZERO_OLD", 0x55, 5)
a.csrr(6, CSR_MSCRATCH)
a.check("CSRRSI_ZERO_NEW", 0x55, 6)

# ---------------------------------------------------------------------------
# Traps
# ---------------------------------------------------------------------------
a.ecall()
a.i("addi", 5, 0, 0xAA)
a.check("ECALL_RET", 0xAA)
a.expect_trap(11)

a.ebreak()
a.i("addi", 5, 0, 0xBB)
a.check("EBREAK_RET", 0xBB)
a.expect_trap(3)

a.word(0x00000000)                  # illegal instruction
a.i("addi", 5, 0, 0xCC)
a.check("ILLEGAL_RET", 0xCC)
a.expect_trap(2)

a.li(3, 0x400)
a.load("lw", 5, 3, 2)               # misaligned load
a.i("addi", 5, 0, 0xDD)
a.check("LOAD_MIS_RET", 0xDD)
a.expect_trap(4)

a.li(3, 0x400)
a.store("sw", 5, 3, 2)              # misaligned store
a.i("addi", 5, 0, 0xEE)
a.check("STORE_MIS_RET", 0xEE)
a.expect_trap(6)

a.la(3, "instr_target")
a.i("addi", 3, 3, 2)                # target + 2 is not 4-byte aligned
a.jalr(0, 3, 0)
a.i("addi", 5, 0, 0xFF)
a.check("INST_MIS_RET", 0xFF)
a.expect_trap(0)

a.li(3, 1)
a.csrw(CSR_MHARTID, 3)              # write read-only CSR
a.i("addi", 5, 0, 0x123)
a.check("CSR_RO_RET", 0x123)
a.expect_trap(2)

a.csrr(3, 0x7C0)                    # unimplemented CSR
a.i("addi", 5, 0, 0x321)
a.check("CSR_IMPL_RET", 0x321)
a.expect_trap(2)

# ---------------------------------------------------------------------------
# Trap summary / final checks
# ---------------------------------------------------------------------------
a.check("TRAP_COUNT", len(a.traps), 31)

a.csrr(5, CSR_MSTATUS)
a.i("andi", 6, 5, 0x8)
a.check("MSTATUS_MIE_AFTER_MRET", 0x8, 6)

a.csrr(5, CSR_MCAUSE)
a.check("MCAUSE_LAST", 2, 5)

# Label used as a misaligned JALR target.
a.label("instr_target")
a.nop()

a.label("_end")
a.jal(0, "_end")

# ---------------------------------------------------------------------------
# finalize / output
# ---------------------------------------------------------------------------
a.finalize()

here = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(here, "program.hex"), "w", encoding="ascii", newline="\n") as f:
    for w in a.words:
        f.write("%08x\n" % w)

with open(os.path.join(here, "expected.hex"), "w", encoding="ascii", newline="\n") as f:
    for _, v in a.results:
        f.write("%08x\n" % v)

with open(os.path.join(here, "trap_expected.hex"), "w", encoding="ascii", newline="\n") as f:
    for c in a.traps:
        f.write("%01x\n" % c)

with open(os.path.join(here, "defs.vh"), "w", encoding="ascii", newline="\n") as f:
    f.write("`define TEST_NUM_RESULTS %d\n" % len(a.results))
    f.write("`define TEST_NUM_TRAPS %d\n" % len(a.traps))

with open(os.path.join(here, "checks.txt"), "w", encoding="utf-8", newline="\n") as f:
    for i, (name, v) in enumerate(a.results):
        f.write("%3d  %-24s 0x%08x\n" % (i, name, v))

print("program words : %d (0x%x bytes)" % (len(a.words), len(a.words) * 4))
print("results       : %d" % len(a.results))
print("traps         : %d" % len(a.traps))
print("entry/start   : 0x%x" % a.labels["_start"])
print("handler       : 0x%x" % a.labels["trap_handler"])
print("end           : 0x%x" % a.labels["_end"])
