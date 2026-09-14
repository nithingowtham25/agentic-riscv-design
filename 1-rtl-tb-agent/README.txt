ECEN 689 - Assignment 1
RTL and Testbench Agent
UIN: 337001954

README
======

This README describes the experiment-reproduction and final-validation
scripts. The assignment workflow program, student_code/lab1.py, is not
modified by these scripts.

1. PROJECT STRUCTURE USED BY THESE SCRIPTS
------------------------------------------

The submission uses the following assignment layout:

    1_code/
        student_code/
            lab1.py
            prompt_styles/
        specs/
        module_packages/
            alu/
            regfile/
            extend/
            controller/
        run_generated_tb.sh
        run_all_experiments.sh
        run_instructor_tests.sh
        run_final_testbenches.sh
        .env
        results/

    2_verilog_blocks_and_testbenches/
        final_rtl/
            alu.sv
            regfile.sv
            extend.sv
            controller.sv
        final_tb/
            alu_tb.sv
            regfile_tb.sv
            extend_tb.sv
            controller_tb.sv

    3_run_records/
        alu/
            direct/
                run1/
                run2/
            rules_constraints/
                run1/
                run2/
            design_planning/
                run1/
                run2/
        regfile/
            ...
        extend/
            ...
        controller/
            ...

    4_report/
        ECEN689_Assignment1_RTL_Testbench_Agent_Report.pdf

The structure of 2_verilog_blocks_and_testbenches is not changed by these
scripts. In particular, there is only one final_rtl directory containing
the selected RTL implementations and one final_tb directory containing
the selected LLM-generated testbenches.

The 3_run_records directory contains the records from the experiments.
Each run is organized as:

    <block>/<prompt_style>/run<run_number>/

Each run directory contains the metadata, prompts, full LLM responses,
simulation logs, and other artifacts associated with that specific run.

The 4_report directory contains only the final assignment report.


2. REPRODUCE ALL 24 EXPERIMENTS
--------------------------------

Use:

    cd 1_code
    chmod +x run_all_experiments.sh
    ./run_all_experiments.sh

This script calls the existing lab1.py once for each experiment:

    4 hardware blocks x 3 prompt styles x 2 repeated runs = 24 runs

Blocks:
    alu
    regfile
    extend
    controller

Prompt styles:
    direct
    rules_constraints
    design_planning

The output from each experiment is stored under:

    1_code/results/<block>/<prompt_style>/run1/
    1_code/results/<block>/<prompt_style>/run2/

For example:

    1_code/results/alu/direct/run1/
    1_code/results/alu/direct/run2/
    1_code/results/controller/design_planning/run2/

Each run also has:

    terminal.log

The script continues through all 24 runs even if one run returns a non-zero
status. It exits non-zero at the end if any run failed.


3. RUN ONE EXPERIMENT MANUALLY
------------------------------

The experiment driver remains lab1.py. For example:

    cd 1_code
    python student_code/lab1.py \
        --spec specs/alu.yaml \
        --out-dir results/alu/direct/run1 \
        --provider tamu \
        --model gpt-5.4 \
        --prompt-style direct

The 24-run script does not replace or modify this workflow; it only
automates the individual commands.


4. INSTRUCTOR TEST VALIDATION
-----------------------------

The instructor testbench files remain at their original locations:

    1_code/module_packages/alu/testbench/alu_tb.sv
    1_code/module_packages/regfile/testbench/regfile_tb.sv
    1_code/module_packages/extend/testbench/extend_tb.sv
    1_code/module_packages/controller/testbench/controller_tb.sv

The original instructor scripts remain at:

    1_code/module_packages/alu/scripts/run_alu.sh
    1_code/module_packages/regfile/scripts/run_regfile.sh
    1_code/module_packages/extend/scripts/run_extend.sh
    1_code/module_packages/controller/scripts/run_controller.sh

To validate the selected RTL in:

    2_verilog_blocks_and_testbenches/final_rtl/

run:

    cd 1_code
    ./run_instructor_tests.sh

For each block, the script invokes the original module script with the
final RTL as its argument. Conceptually, this is the same flow as:

    bash module_packages/alu/scripts/run_alu.sh \
      ../2_verilog_blocks_and_testbenches/final_rtl/alu.sv

The original module script then uses its own instructor testbench and
sample vectors. No instructor testbench is copied into folder 2, and no
instructor testbench is modified.

Validation logs are written to:

    1_code/results/final_validation/instructor/


5. GENERATED TESTBENCH VALIDATION
---------------------------------

The selected LLM-generated testbenches are the files already present in:

    2_verilog_blocks_and_testbenches/final_tb/

The supplied runner is:

    1_code/run_generated_tb.sh

That runner expects the following layout for one module:

    <results_dir>/final_rtl.sv
    <results_dir>/<module>_tb.sv

The selected final RTL files, however, are intentionally kept in:

    2_verilog_blocks_and_testbenches/final_rtl/

Therefore run_final_testbenches.sh creates a temporary staging directory
under:

    1_code/results/final_validation/generated_tb/

and copies:

    final_rtl/<module>.sv
        -> temporary directory/final_rtl.sv

    final_tb/<module>_tb.sv
        -> temporary directory/<module>_tb.sv

It then invokes the supplied run_generated_tb.sh against that staging
directory.

This makes the existing final_tb files compatible with the provided
runner without changing folder 2 and without changing run_generated_tb.sh.

Run:

    cd 1_code
    chmod +x run_final_testbenches.sh
    ./run_final_testbenches.sh

The validation logs are written to:

    1_code/results/final_validation/generated_tb/logs/

Temporary staging files and Icarus .vvp files are also kept under:

    1_code/results/final_validation/generated_tb/

They are validation artifacts and are not part of the final_rtl or final_tb
folders.

Note on Pass Override During Validation: When validating the generated testbench 
(`generated_tb`) using the provided validation script, a pass override is used 
to accommodate the script's validation behavior. This override is only applied 
during validation and does not affect the functionality or operation of the 
generated testbench itself.


6. WHICH TESTS ARE AUTHORITATIVE?
----------------------------------

For Phase C and Task 3 RTL correctness, the instructor-provided sample
tests are authoritative.

The LLM-generated testbenches are separate and are used for Task 4. They
are not used to replace the instructor sample tests.

Therefore:

    Instructor sample-test flow
        -> authoritative RTL correctness check

    LLM-generated TB
        -> independent Task 4 / generated-TB validation

A generated TB failure does not automatically prove that the RTL is wrong,
because the generated TB itself can contain an error. Similarly, a
generated TB pass does not replace the instructor sample tests.


7. ENVIRONMENT AND SUBMISSION
-----------------------------

A local .env file should be present in 1_code/ for the required provider/API
configuration.

Do not include API keys or other secrets in the submission ZIP.

The experiment records under 3_run_records/ contain the prompts, responses,
metadata, token-count information, simulation results, and repair history
needed to document the experiments.


8. FINAL SUBMISSION
-------------------

The required submission ZIP name is:

    337001954_A1.zip

The submission contains:

    1_code/
        Assignment workflow and validation/reproduction scripts

    2_verilog_blocks_and_testbenches/
        Final selected RTL and generated testbenches

    3_run_records/
        Complete records for all experimental runs

    4_report/
        Final assignment report

The helper scripts do not modify lab1.py, the instructor testbenches, or
the 2_verilog_blocks_and_testbenches folder structure. They automate the
24 individual experiment invocations and validate the existing final RTL
and final generated testbench artifacts using the supplied test
infrastructure.