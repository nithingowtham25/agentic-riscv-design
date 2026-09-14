"""Provided wrappers for invoking Icarus Verilog from Python."""

import subprocess


def run_command(command):
    """Run a command and return `(success, stdout, stderr)`."""
    try:
        result = subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
        )
        return True, result.stdout, result.stderr
    except subprocess.CalledProcessError as error:
        return False, error.stdout, error.stderr
    except OSError as error:
        return False, "", str(error)


def run_iverilog_compile(design_file, tb_file=None, output_file="sim.out"):
    """Compile RTL, optionally with a testbench, and return `(success, output)`."""
    command = ["iverilog", "-g2012", "-o", str(output_file), str(design_file)]
    if tb_file is not None:
        command.append(str(tb_file))
    ok, stdout, stderr = run_command(command)
    return ok, (stdout + stderr).strip()


def run_vvp(sim_file="sim.out"):
    """Run an Icarus simulation binary and return `(success, output)`."""
    ok, stdout, stderr = run_command(["vvp", str(sim_file)])
    return ok, (stdout + stderr).strip()
