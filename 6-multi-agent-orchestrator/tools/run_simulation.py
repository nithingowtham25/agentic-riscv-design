#!/usr/bin/env python3
import subprocess
import os

SRC_FILE = "workspace/src/memory_stage.v"
TB_FILE = "workspace/tb/tb_memory_stage.v"
OUT_BIN = "workspace/sim.out"
LOG_FILE = "workspace/reports/sim_output.log"

os.makedirs("workspace/reports", exist_ok=True)

def run_sim():
    if not os.path.exists(SRC_FILE) or not os.path.exists(TB_FILE):
        with open(LOG_FILE, "w") as f:
            f.write("ERROR: Missing RTL or Testbench source file.\n")
        print("Simulation Tool Error: Files missing.")
        return

    # Compile with Icarus Verilog
    compile_cmd = f"iverilog -o {OUT_BIN} {SRC_FILE} {TB_FILE}"
    res = subprocess.run(compile_cmd, shell=True, capture_output=True, text=True)
    
    if res.returncode != 0:
        with open(LOG_FILE, "w") as f:
            f.write(f"COMPILATION ERROR:\n{res.stderr}\n")
        print("Compilation Failed.")
        return

    # Execute simulation
    run_cmd = f"vvp {OUT_BIN}"
    sim_res = subprocess.run(run_cmd, shell=True, capture_output=True, text=True)
    
    with open(LOG_FILE, "w") as f:
        f.write(sim_res.stdout)
    
    if "ERROR" in sim_res.stdout or "FAIL" in sim_res.stdout:
        print("Simulation finished with test failures.")
    else:
        print("SIMULATION SUCCESS")

if __name__ == "__main__":
    run_sim()