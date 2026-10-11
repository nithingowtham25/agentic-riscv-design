# run.py: Student-facing harness. Run your generated tests and/or assertions against YOUR pipelined core and
# run.py: see pass/fail, coverage, and assertion firings -- the same signals used to evaluate your work.
# run.py: This does NOT score you; it lets you develop your Verification Agent locally.
#
# Usage:
#   python harness/run.py --tests results/tests            # run all .hex tests, report pass/fail + coverage
#   python harness/run.py --tests results/tests --assertions results/assertions.sv
#
# Each test is a .hex file: one 32-bit instruction word per line (hex). The expected result is computed by
# the reference ISS (reference/iss.py) from the program itself -- so a test must store its result to the
# signature address 0x100 with SW (see the handout). A program that never stores a signature is skipped.
import argparse
import glob
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, "reference"))
from iss import ISS  # noqa: E402

# Your pipelined core: core/datapath_pipelined.sv (the file you fill in). Override with --core if you
# keep it under a different name. This is the core the harness verifies -- YOUR core.
CORE = os.path.join(ROOT, "core", "datapath_pipelined.sv")
SUBMODULES = [os.path.join(ROOT, "core", "submodules", f)
              for f in sorted(os.listdir(os.path.join(ROOT, "core", "submodules"))) if f.endswith(".sv")]
CORE_TB = os.path.join(HERE, "core_tb.sv")
ASSERT_TB = os.path.join(HERE, "core_tb_assert.sv")   # binds student_assertions into the core

# Coverage bins (mirrors docs/coverage_metric.md).
INSTR = {"0110011": "OP_REG", "0010011": "OP_IMM", "0000011": "OP_LOAD", "0100011": "OP_STORE",
         "1100011": "OP_BRANCH", "1101111": "OP_JAL", "1100111": "OP_JALR",
         "0110111": "OP_LUI", "0010111": "OP_AUIPC"}
HAZARD = {"fwdA_mem", "fwdA_wb", "fwdB_mem", "fwdB_wb", "no_forward", "load_use_stall", "flush"}
CONTROL = {"branch_taken", "branch_not_taken", "jal", "jalr", "no_control"}
ALL_BINS = set(INSTR.values()) | HAZARD | CONTROL
COV_RE = re.compile(r"COV op=([01]{7}) f3=[01]{3} fwdA=([01]{2}) fwdB=([01]{2}) "
                    r"stall=(\d) flush=(\d) branchE=(\d) pcsrc=(\d) jump=(\d)")


def load(hexf):
    words = []
    for line in open(hexf):
        line = line.strip()
        if line:
            words.append(int(line, 16) & 0xffffffff)
    return words


def run_one(prog, cov_tb=None):
    exp = ISS(prog).run()[1]
    if exp is None:
        return "no_signature", ""
    tb = cov_tb or CORE_TB
    with tempfile.TemporaryDirectory() as t:
        hx = os.path.join(t, "p.hex")
        open(hx, "w").write("".join(f"{w:08x}\n" for w in prog))
        vvp = os.path.join(t, "c.vvp")
        c = subprocess.run(["iverilog", "-g2012", "-o", vvp, tb, CORE, *SUBMODULES],
                           capture_output=True, text=True)
        errs = [l for l in (c.stderr + c.stdout).splitlines()
                if "error" in l.lower() and "sorry" not in l.lower()]
        if c.returncode != 0 and errs:
            return "compile_error", "\n".join(errs[:3])
        try:
            r = subprocess.run(["vvp", vvp, f"+PROGRAM={hx}", f"+EXPECT={exp:08x}", "+MAX_CYCLES=6000"],
                               capture_output=True, text=True, timeout=60)
        except subprocess.TimeoutExpired:
            return "timeout", ""
        out = r.stdout + r.stderr
        verdict = "pass" if any(l.strip().startswith("PASS") for l in out.splitlines()) else "fail"
        return verdict, out


def check_assertions(assert_file, programs):
    """Compile the student's assertions + the binding TB + the core, run each program on your core,
    and collect any ASSERT_FAIL lines. On a correct core, correct assertions must be SILENT -- any
    ASSERT_FAIL here means that assertion is a false positive (it would score 0). Returns
    (status, fired_set): status in {compile_error, ok}; fired_set = names that fired.
    """
    fired = set()
    for name, prog in programs:
        exp = ISS(prog).run()[1]
        if exp is None:
            continue
        with tempfile.TemporaryDirectory() as t:
            hx = os.path.join(t, "p.hex")
            open(hx, "w").write("".join(f"{w:08x}\n" for w in prog))
            vvp = os.path.join(t, "c.vvp")
            c = subprocess.run(["iverilog", "-g2012", "-o", vvp, ASSERT_TB, assert_file, CORE, *SUBMODULES],
                               capture_output=True, text=True)
            errs = [l for l in (c.stderr + c.stdout).splitlines()
                    if "error" in l.lower() and "sorry" not in l.lower()]
            if c.returncode != 0 and errs:
                return "compile_error", errs[:4]
            try:
                r = subprocess.run(["vvp", vvp, f"+PROGRAM={hx}", f"+EXPECT={exp:08x}", "+MAX_CYCLES=6000"],
                                   capture_output=True, text=True, timeout=60)
            except subprocess.TimeoutExpired:
                continue
            out = r.stdout + r.stderr
            for l in out.splitlines():
                l = l.strip()
                if l.startswith("ASSERT_FAIL") and len(l.split()) > 1:
                    fired.add(l.split()[1])
    return "ok", fired


def coverage(traces):
    hit = set()
    for txt in traces:
        for m in COV_RE.finditer(txt):
            op, fa, fb, stall, flush, br, pcsrc, jmp = m.groups()
            if op in INSTR: hit.add(INSTR[op])
            if fa == "10": hit.add("fwdA_mem")
            if fa == "01": hit.add("fwdA_wb")
            if fb == "10": hit.add("fwdB_mem")
            if fb == "01": hit.add("fwdB_wb")
            if fa == "00" and fb == "00": hit.add("no_forward")
            if stall == "1": hit.add("load_use_stall")
            if flush == "1": hit.add("flush")
            if jmp == "1": hit.add("jalr" if op == "1100111" else "jal")
            elif br == "1": hit.add("branch_taken" if pcsrc == "1" else "branch_not_taken")
            else: hit.add("no_control")
    return hit


def main():
    ap = argparse.ArgumentParser()
    global CORE
    ap.add_argument("--tests", required=True, help="directory of .hex test programs")
    ap.add_argument("--assertions", help="results/assertions.sv (optional; checks silent-on-your-core)")
    ap.add_argument("--core", default=CORE,
                    help="your pipelined core .sv (default: core/datapath_pipelined.sv)")
    a = ap.parse_args()
    CORE = os.path.abspath(a.core)
    if not os.path.exists(CORE):
        print(f"core not found: {CORE}\n"
              f"Fill in the 3 TODOs in core/datapath_pipelined.sv "
              f"(or pass --core <your file>).", file=sys.stderr)
        sys.exit(2)

    cov_tb = os.path.join(HERE, "core_tb_cov.sv")
    have_cov = os.path.exists(cov_tb)
    traces, npass, nrun = [], 0, 0
    for hx in sorted(glob.glob(os.path.join(a.tests, "*.hex"))):
        prog = load(hx)
        v, out = run_one(prog, cov_tb if have_cov else None)
        if v == "no_signature":
            print(f"  [skip] {os.path.basename(hx)} (no signature store)")
            continue
        nrun += 1
        ok = v == "pass"
        npass += ok
        print(f"  [{'PASS' if ok else v.upper()}] {os.path.basename(hx)}")
        if ok and have_cov:
            traces.append(out)
    print(f"\n{npass}/{nrun} tests pass your core")
    if have_cov:
        hit = coverage(traces)
        print(f"coverage: {len(hit & ALL_BINS)}/{len(ALL_BINS)} bins = {len(hit & ALL_BINS)/len(ALL_BINS)*100:.0f}%")
        missed = sorted(ALL_BINS - hit)
        if missed:
            print("missed bins:", ", ".join(missed))
    else:
        print("(coverage trace TB not present in this package; pass/fail only)")

    if a.assertions:
        print(f"\nassertions: running {a.assertions} on your core (must stay silent on a CORRECT core) ...")
        progs = [(os.path.basename(h), load(h)) for h in sorted(glob.glob(os.path.join(a.tests, "*.hex")))]
        if not progs:
            print("  (no tests to run assertions against - add some .hex tests first)")
        else:
            status, fired = check_assertions(a.assertions, progs)
            if status == "compile_error":
                print("  [FAIL] assertions.sv did not compile:")
                for e in fired:                      # fired holds the error lines in this case
                    print(f"    {e}")
                print("  Fix the compile error (module must be named student_assertions with the template ports).")
            elif fired:
                print(f"  [FAIL] your assertions FIRE on the CORRECT core: {', '.join(sorted(fired))}")
                print("  These are false positives - they would score 0. An assertion must be silent on")
                print("  correct RTL. Re-check the conditions in docs/required_invariants.md.")
            else:
                print("  [ OK ] silent across all your tests (no false positives on your core).")
                print("  Note: this checks silence only; whether they CATCH the hidden bugs is scored when")
                print("  your submission is evaluated.")


if __name__ == "__main__":
    main()
