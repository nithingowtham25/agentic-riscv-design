"""Starter script for a student-designed LLM-to-RTL workflow."""

import argparse
from pathlib import Path

# Provided helpers - already imported for you. Use these in your Phase A/B/C code;
# you should not need to add imports or edit any other file.
from io_utils import (
    find_default_spec,
    load_spec,
    read_file,
    write_file,
    strip_markdown_code_blocks,
)
from llm_clients import build_llm_client
from tool_runner import run_iverilog_compile, run_vvp


DEFAULT_MODEL = "gpt-5.4"


def parse_args():
    parser = argparse.ArgumentParser(
        description="Design an LLM-assisted RTL generation and verification workflow."
    )
    parser.add_argument("--spec", type=Path, help="Path to a YAML design specification.")
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path(__file__).resolve().parent / "output",
        help="Suggested directory for generated artifacts.",
    )
    parser.add_argument(
        "--model",
        default=DEFAULT_MODEL,
        help=f"Model name (default: {DEFAULT_MODEL}). Use the same model for all runs.",
    )
    parser.add_argument(
        "--provider",
        choices=["tamu", "openai"],
        default=None,
        help="LLM access path: 'tamu' (TAMU AI Chat) or 'openai' (own key). "
             "If omitted, auto-selects by which API key is set.",
    )
    parser.add_argument(
        "--smoke-test",
        action="store_true",
        help="Make one tiny LLM request to confirm the client works, then continue. "
             "Off by default so normal runs do not spend quota on a throwaway call.",
    )
    parser.add_argument(
        "--prompt-style",
        choices=["direct", "rules_constraints", "design_planning"],
        default="direct",
        help="Prompt style used for RTL generation."
    )
    return parser.parse_args()


def main():
    args = parse_args()

    # Provided setup: select and load the hardware specification.
    spec_path = args.spec if args.spec else find_default_spec(Path.cwd())
    top_module, content, spec = load_spec(spec_path)

    # Provided setup: build the LLM client (TAMU AI Chat or OpenAI, same model).
    model = build_llm_client(args.model, provider=args.provider)

    print(f"Using spec: {spec_path}")
    print(f"Top module: {top_module}")
    print(f"Model: {args.model}")
    print(f"Suggested output directory: {args.out_dir.resolve()}")

    # Optional one-off check that the LLM client works (opt-in so normal runs
    # do not spend quota on a throwaway request).
    if args.smoke_test:
        test_reply = model.generate(
            "Reply with exactly: LLM client initialization successful.",
            system_prompt="Follow the user's requested output format exactly.",
        )
        print(f"LLM smoke-test reply: {test_reply}")

    # From this point onward, design and implement your own workflow. You may
    # add helper functions or modules. You may place these functions in
    # separate files and import them here.
    #
    # The three phases below are the internal steps of YOUR workflow. They are
    # NOT the five graded tasks in the handout - the handout describes the whole
    # experiment (multiple prompt styles, repeated runs, analysis) that runs on
    # top of this workflow.

    # ------------------------------------------------------------------
    # WORKFLOW PHASE A: GENERATE RTL
    # Use `content`/`spec` and `model.generate(...)` to
    # produce RTL for `top_module`, then save it so that it can be compiled.
    # Preserve the interface and behavior in the YAML spec. You need to decide
    # how to construct the prompt, clean the response, name output files, and
    # determine whether the RTL is ready for the next phase.
    #
    # >>> BEGIN STUDENT PHASE A CODE

    # -------------------------------------------------------------------------
    # Overall clean experiment log
    #
    # run.log is the human-readable summary of the entire experiment.
    # Each phase adds its own information to this log.
    # -------------------------------------------------------------------------

    run_log_path = args.out_dir / "run.log"
    run_log = []


    def add_run_log(text=""):
        run_log.append(text)


    # -------------------------------------------------------------------------
    # Basic run information
    # -------------------------------------------------------------------------

    add_run_log("=" * 70)
    add_run_log("ECEN 689 - ASSIGNMENT 1")
    add_run_log("LLM-BASED HARDWARE DESIGN RUN")
    add_run_log("=" * 70)
    add_run_log("")
    add_run_log(f"Block              : {top_module}")
    add_run_log(f"Specification      : {spec_path}")
    add_run_log(f"Output Directory   : {args.out_dir.resolve()}")
    add_run_log(f"Provider           : {args.provider}")
    add_run_log(f"Model              : {args.model}")
    add_run_log("")


    # -------------------------------------------------------------------------
    # Phase A: Generate RTL
    #
    # The system prompt is FIXED.
    # The experimental variable is the user prompt.
    # The prompt is generic and receives the hardware-specific information
    # from the YAML specification.
    # -------------------------------------------------------------------------

    system_prompt = (
        "You are an RTL design agent responsible for translating hardware "
        "specifications into SystemVerilog. "
        "Use the hardware specification provided by the user as the source "
        "of truth for the requested design. "
        "Your goal is to produce a correct implementation that follows the "
        "provided specification."
    )

    prompt_file = Path(__file__).parent / "prompt_styles" / f"{args.prompt_style}.txt"

    prompt_template = read_file(prompt_file)

    user_prompt = prompt_template.format(
        top_module=top_module,
        content=content
    )


    # -------------------------------------------------------------------------
    # Check whether this experiment already has an initial RTL.
    #
    # If it exists, reuse it instead of generating a new RTL.
    # -------------------------------------------------------------------------

    args.out_dir.mkdir(parents=True, exist_ok=True)

    rtl_path = args.out_dir / "initial_rtl.sv"

    if rtl_path.exists():

        rtl_code = read_file(rtl_path)

        print(f"Phase A: reusing existing RTL at {rtl_path}")

    else:

        result = model.generate_full(
            user_prompt,
            system_prompt=system_prompt,
        )

        # Preserve the complete LLM response.
        rtl_response = result.content

        # Remove Markdown code fences before saving the RTL.
        rtl_code = strip_markdown_code_blocks(rtl_response)

        # Save the first RTL version.
        write_file(
            rtl_path,
            rtl_code,
        )

        # Save the exact system prompt.
        write_file(
            args.out_dir / "phaseA_prompt_system.txt",
            system_prompt + "\n",
        )

        # Save the exact user prompt.
        write_file(
            args.out_dir / "phaseA_prompt_user.txt",
            user_prompt + "\n",
        )

        # Save the complete, unmodified LLM response.
        write_file(
            args.out_dir / "phaseA_response.txt",
            rtl_response,
        )

        # Save generation metadata.
        metadata = (
            f"model: {result.model}\n"
            f"provider: {result.provider}\n"
            f"settings: {result.settings}\n"
            f"usage: {result.usage}\n"
        )

        write_file(
            args.out_dir / "phaseA_metadata.txt",
            metadata,
        )

        print(f"Phase A: generated RTL saved to {rtl_path}")
        print(f"Phase A: model returned: {result.model}")
        print(f"Phase A: usage: {result.usage}")

    # -------------------------------------------------------------------------
    # TEMPORARY: Intentionally introduce a functional error
    # to test the Phase C repair loop.
    # REMOVE THIS AFTER TESTING.
    # -------------------------------------------------------------------------

    # if top_module == "regfile":
    #     rtl_code = rtl_code.replace(
    #         "if (we3 && (a3 != 5'd0)) begin",
    #         "if (!we3 && (a3 != 5'd0)) begin"
    #     )

    #     write_file(
    #         rtl_path,
    #         rtl_code,
    #     )

    #     print("TEMPORARY: RegFile RTL intentionally corrupted for Phase C testing.")

    # -------------------------------------------------------------------------
    # Basic sanity checks.
    # -------------------------------------------------------------------------

    if not rtl_code.strip():
        raise RuntimeError("RTL file is empty.")

    if f"module {top_module}" not in rtl_code:
        raise RuntimeError(
            f"Generated RTL does not contain the expected module "
            f"'{top_module}'."
        )

    if "endmodule" not in rtl_code:
        raise RuntimeError(
            "RTL does not contain 'endmodule'."
        )


    # -------------------------------------------------------------------------
    # Add Phase A summary to the overall run.log.
    # -------------------------------------------------------------------------

    add_run_log("=" * 70)
    add_run_log("PHASE A - RTL GENERATION")
    add_run_log("=" * 70)
    add_run_log("")
    add_run_log(f"RTL                : {rtl_path.name}")

    phaseA_metadata_path = args.out_dir / "phaseA_metadata.txt"

    if phaseA_metadata_path.exists():
        add_run_log("")
        add_run_log("Model generation:")
        add_run_log(read_file(phaseA_metadata_path))

    add_run_log("")

    # <<< END STUDENT PHASE A CODE

    # ------------------------------------------------------------------
    # WORKFLOW PHASE B: DEFINE TESTBENCH GENERATION
    # The detailed TB prompt is retained, but generation is intentionally
    # deferred until Phase C has accepted final_rtl.sv using instructor tests.
    # >>> BEGIN STUDENT PHASE B CODE

    MAX_TB_RETRIES = 3
    initial_tb_path = args.out_dir / f"initial_{top_module}_tb.sv"
    final_tb_path = args.out_dir / f"{top_module}_tb.sv"

    tb_system_prompt = (
        "You are a SystemVerilog verification engineer responsible for "
        "creating self-checking testbenches for hardware blocks. "
        "Use the provided hardware specification as the authoritative source "
        "for determining expected behavior. "
        "\n\n"
        "Follow these rules:\n"
        "1. Instantiate the DUT using the exact module name and interface "
        "specified in the hardware specification. Do not modify the DUT.\n"
        "\n"
        "2. Create a self-checking SystemVerilog testbench that drives inputs "
        "to the DUT and compares its outputs against expected values derived "
        "from the specification.\n"
        "\n"
        "3. Exercise the normal operations, control conditions, examples, "
        "boundary cases, and important corner cases described by the "
        "specification.\n"
        "\n"
        "4. For clocked designs, correctly implement the clock, reset, and "
        "sampling behavior specified by the design. For combinational "
        "designs, allow sufficient time for outputs to respond after inputs "
        "change.\n"
        "\n"
        "5. Check all relevant DUT outputs. Pay particular attention to "
        "signed versus unsigned behavior, bit widths, boundary values, "
        "control encodings, and reset behavior where applicable.\n"
        "\n"
        "6. The testbench must compile successfully with Icarus Verilog using "
        "SystemVerilog mode (-g2012). Use only SystemVerilog constructs that are "
        "supported by Icarus Verilog. Avoid simulator-specific, experimental, or "
        "unnecessary language features when a simpler construct can be used.\n"
        "\n"
        "7. Before returning the testbench, perform a careful syntax sanity check. "
        "Ensure that all declarations, begin/end blocks, tasks, functions, loops, "
        "conditionals, expressions, module instantiation, and procedural statements "
        "are syntactically valid SystemVerilog and properly terminated. The generated "
        "testbench must not contain syntax errors or malformed statements.\n"
        "\n"
        "8. Keep the testbench compact enough to fit completely within the available "
        "output limit. Use a small number of representative test cases that provide "
        "meaningful coverage of the specified instruction types, control conditions, "
        "boundary cases, and important corner cases. Do not generate exhaustive "
        "or highly repetitive tests. A complete compilable testbench is more important "
        "than a large number of test cases. The response must always reach the final "
        "endmodule statement.\n"
        "\n"
        "9. Maintain explicit counts of passed and failed test cases. "
        "Report individual test failures clearly before the final summary, "
        "including the test case and expected versus actual values where "
        "practical.\n"
        "\n"
        "10. At the end of the simulation, report the following four lines "
        "exactly, using integer values:\n"
        "TESTS_PASSED: <number>\n"
        "TESTS_ERRORS: <number>\n"
        "TESTS_TOTAL: <number>\n"
        "RESULT: PASS\n"
        "or\n"
        "RESULT: FAIL\n"
        "The TESTS_TOTAL value must equal TESTS_PASSED + TESTS_ERRORS. "
        "When the simulation passes, do not print the literal substring FAIL "
        "anywhere in runtime output; print RESULT: FAIL only conditionally when "
        "one or more checks fail.\n"
        "\n"
        "11. Return only the complete SystemVerilog testbench inside one "
        "fenced code block. Do not provide explanations or additional text."
    )

    tb_user_prompt = (
        f"Generate a self-checking SystemVerilog testbench for the following "
        f"hardware block.\n\n"
        f"Top module: {top_module}\n\n"
        f"Hardware specification:\n"
        f"{content}\n\n"
        f"The testbench should independently verify the behavior described "
        f"in the specification. Exercise the specified operations and "
        f"important corner cases, compare the DUT outputs with expected "
        f"values, and clearly report whether the tests PASS or FAIL.\n\n"
        f"Ensure the generated testbench is syntactically valid and can be "
        f"compiled directly with Icarus Verilog using 'iverilog -g2012'. "
        f"Prefer simple, well-supported SystemVerilog constructs over complex "
        f"or simulator-specific features. Carefully check all begin/end blocks, "
        f"declarations, tasks, functions, loops, conditionals, and expressions "
        f"before returning the final code.\n\n"
        f"Maintain explicit counts of passed and failed tests and report "
        f"the required standardized summary at the end of the simulation.\n\n"
        f"Keep the testbench compact. Use representative tests rather than exhaustive "
        f"or repetitive testing so the complete testbench fits within the output limit. "
        f"The testbench must be complete and must end with 'endmodule'.\n"
    )

    def generate_or_reuse_initial_tb():
        if final_tb_path.exists():
            print(f"Phase B: reusing accepted testbench at {final_tb_path}")
            return final_tb_path
        if initial_tb_path.exists():
            print(f"Phase B: reusing initial testbench at {initial_tb_path}")
            return initial_tb_path

        result = model.generate_full(tb_user_prompt, system_prompt=tb_system_prompt)
        tb_response = result.content
        tb_code = strip_markdown_code_blocks(tb_response)
        if not tb_code.strip() or "module" not in tb_code or "endmodule" not in tb_code:
            raise RuntimeError("LLM returned an incomplete testbench.")

        write_file(initial_tb_path, tb_code)
        write_file(args.out_dir / "phaseB_prompt_system.txt", tb_system_prompt + "\n")
        write_file(args.out_dir / "phaseB_prompt_user.txt", tb_user_prompt + "\n")
        write_file(args.out_dir / "phaseB_response.txt", tb_response)
        write_file(
            args.out_dir / "phaseB_metadata.txt",
            f"model: {result.model}\nprovider: {result.provider}\n"
            f"settings: {result.settings}\nusage: {result.usage}\n",
        )
        print(f"Phase B: generated initial testbench at {initial_tb_path}")
        return initial_tb_path

    # <<< END STUDENT PHASE B CODE

    # ------------------------------------------------------------------
    # WORKFLOW PHASE C: SIMULATE AND ITERATIVELY REVISE
    # Compile the RTL and testbench with the provided
    # `run_iverilog_compile(...)` utility, run the result with `run_vvp(...)`,
    # and retain the diagnostics and simulation output. When compilation or
    # functional checks fail, use that feedback to revise the RTL, testbench,
    # or both, then compile and simulate again. Decide how to distinguish tool
    # execution success from functional success, use a finite stopping policy
    # (a maximum number of revision attempts), and preserve enough history to
    # explain what changed and why. The spec remains the source of truth when
    # deciding which artifact is incorrect.
    #
    # >>> BEGIN STUDENT PHASE C CODE
    import subprocess

    MAX_RETRIES = 3

    # -------------------------------------------------------------------------
    # Phase C1: Validate and iteratively repair RTL using only the instructor
    # sample suite. The suite is the authoritative correctness and repair gate.
    # Generated-TB work is deferred until an accepted final RTL has been saved.
    # The repair agent receives instructor feedback plus the immediately prior
    # failed RTL, helping it avoid repeating an unsuccessful implementation.
    # -------------------------------------------------------------------------


    # -------------------------------------------------------------------------
    # Phase C setup
    # -------------------------------------------------------------------------

    current_rtl_path = args.out_dir / "initial_rtl.sv"

    # Instructor-provided sample-test script.
    sample_script = (
        Path("module_packages")
        / top_module
        / "scripts"
        / f"run_{top_module}.sh"
    )

    if not sample_script.exists():
        raise RuntimeError(
            f"Instructor test script not found: {sample_script}"
        )


    # Store one summary record for every RTL version.
    attempt_results = []

    attempt = 0

    # -------------------------------------------------------------------------
    # Previous failed RTL version.
    #
    # This is used only as a sanity check by the repair agent.
    #
    # Repair attempt 1:
    #   current  = RTL version 0
    #   previous = none
    #
    # Repair attempt 2:
    #   current  = RTL version 1
    #   previous = RTL version 0
    #
    # Repair attempt 3:
    #   current  = RTL version 2
    #   previous = RTL version 1
    # -------------------------------------------------------------------------

    previous_rtl = None


    while True:

        # ---------------------------------------------------------------------
        # The RTL file on disk is the single source of truth.
        #
        # This guarantees that the RTL being tested and the RTL supplied to
        # the repair agent are the same version.
        # ---------------------------------------------------------------------

        current_rtl = read_file(current_rtl_path)

        print()
        print("=" * 70)
        print(f"Phase C: RTL version {attempt}")
        print(f"RTL: {current_rtl_path}")
        print("=" * 70)


        # ---------------------------------------------------------------------
        # Add this RTL version to the clean run.log.
        # ---------------------------------------------------------------------

        add_run_log("")
        add_run_log("")
        add_run_log(
            f"---------------------- RTL VERSION {attempt} "
            f"----------------------"
        )
        add_run_log("")
        add_run_log(f"RTL: {current_rtl_path.name}")
        add_run_log("")


        # =====================================================================
        # 1. GENERATED-TB VALIDATION IS DEFERRED
        # =====================================================================
        # The instructor suite alone decides RTL acceptance. Testbench generation
        # and validation begin only after final_rtl.sv is frozen below.
        generated_output = "Deferred until an instructor-accepted final RTL exists."
        generated_passed = None
        generated_failed = None
        generated_total = None
        generated_result = "DEFERRED"
        # =====================================================================
        # 2. RUN INSTRUCTOR SAMPLE TESTS
        # =====================================================================

        print("Running instructor sample tests...")


        instructor_process = subprocess.run(
            [
                "bash",
                str(sample_script),
                str(current_rtl_path),
            ],
            capture_output=True,
            text=True,
        )


        instructor_output = (
            instructor_process.stdout
            + instructor_process.stderr
        )


        print(instructor_output)


        # ---------------------------------------------------------------------
        # Instructor tests are the authoritative correctness signal.
        #
        # Only an explicit instructor PASS is considered a pass.
        # ---------------------------------------------------------------------

        instructor_passed = (
            ">>> RESULT: PASS" in instructor_output
        )


        instructor_result = (
            "PASS"
            if instructor_passed
            else "FAIL"
        )


        # ---------------------------------------------------------------------
        # Try to extract generic instructor test counts.
        #
        # We only use counts if the actual instructor output provides them.
        # No hardware-specific test names or categories are inferred.
        # ---------------------------------------------------------------------

        instructor_tests_passed = None
        instructor_tests_total = None


        for line in instructor_output.splitlines():

            line = line.strip()

            if line.startswith("Passed:"):

                try:
                    instructor_tests_passed = int(
                        line.split(":", 1)[1].strip()
                    )
                except ValueError:
                    pass

            elif line.startswith("Total"):

                try:
                    instructor_tests_total = int(
                        line.split(":", 1)[1].strip()
                    )
                except ValueError:
                    pass


        # =====================================================================
        # 3. SAVE COMPLETE RAW OUTPUT FOR THIS RTL VERSION
        # =====================================================================

        log_path = (
            args.out_dir
            / f"phaseC_attempt_{attempt}.log"
        )


        raw_attempt_log = (
            "=" * 70
            + "\n"
            + f"RTL VERSION {attempt}\n"
            + "=" * 70
            + "\n\n"

            + f"RTL: {current_rtl_path}\n\n"

            + "=" * 70
            + "\n"
            + "GENERATED TESTBENCH\n"
            + "=" * 70
            + "\n\n"

            + generated_output

            + "\n\n"

            + "=" * 70
            + "\n"
            + "INSTRUCTOR SAMPLE TESTS\n"
            + "=" * 70
            + "\n\n"

            + instructor_output
        )


        write_file(
            log_path,
            raw_attempt_log,
        )


        # =====================================================================
        # 4. ADD INSTRUCTOR RESULTS TO CLEAN RUN.LOG
        # =====================================================================

        add_run_log("Instructor Sample Tests")
        add_run_log("-----------------------")

        add_run_log(
            f"Result       : {instructor_result}"
        )


        if instructor_tests_passed is not None:

            add_run_log(
                f"Tests Passed : {instructor_tests_passed}"
            )


        if instructor_tests_total is not None:

            add_run_log(
                f"Tests Total  : {instructor_tests_total}"
            )


        add_run_log("")


        # =====================================================================
        # 5. STORE THIS RTL VERSION'S RESULTS
        # =====================================================================

        attempt_results.append(
            {
                "attempt": attempt,
                "rtl": current_rtl_path.name,

                "generated_result": generated_result,
                "generated_passed": generated_passed,
                "generated_failed": generated_failed,
                "generated_total": generated_total,

                "instructor_result": instructor_result,
                "instructor_passed": instructor_tests_passed,
                "instructor_total": instructor_tests_total,
            }
        )


        # =====================================================================
        # 6. INSTRUCTOR TESTS DETERMINE WHETHER REPAIR IS NEEDED
        # =====================================================================

        if instructor_passed:

            add_run_log("Decision:")
            add_run_log(
                "  Instructor tests PASSED."
            )
            add_run_log(
                "  No repair required."
            )


            print(
                f"Phase C: RTL version {attempt} PASSED "
                "the instructor sample tests."
            )


            final_path = args.out_dir / "final_rtl.sv"


            # Re-read the file so final RTL is always copied from the
            # exact version that passed the instructor tests.
            current_rtl = read_file(current_rtl_path)


            write_file(
                final_path,
                current_rtl,
            )


            print(
                f"Phase C: final RTL saved to {final_path}"
            )


            final_rtl_source = current_rtl_path.name

            final_status = "PASS"

            break


        # ---------------------------------------------------------------------
        # Instructor tests failed.
        #
        # Even if the generated TB passed, we repair because the instructor
        # tests are the correctness gate.
        # ---------------------------------------------------------------------

        if attempt >= MAX_RETRIES:

            add_run_log("Decision:")
            add_run_log(
                "  Instructor tests FAILED."
            )
            add_run_log(
                f"  Maximum repair attempts "
                f"({MAX_RETRIES}) reached."
            )


            print(
                f"Phase C: maximum repair attempts "
                f"({MAX_RETRIES}) reached."
            )


            final_path = args.out_dir / "final_rtl.sv"


            # Preserve the last RTL version even when repair ultimately fails.
            current_rtl = read_file(current_rtl_path)


            write_file(
                final_path,
                current_rtl,
            )


            print(
                f"Phase C: last RTL saved to {final_path}"
            )


            final_rtl_source = current_rtl_path.name

            final_status = "FAIL"

            break


        # =====================================================================
        # 7. REQUEST RTL REPAIR
        # =====================================================================

        add_run_log("Decision:")
        add_run_log(
            "  Instructor tests FAILED."
        )
        add_run_log(
            "  Sending RTL to repair agent."
        )


        repair_attempt = attempt + 1


        # ---------------------------------------------------------------------
        # Build previous-RTL sanity-check section.
        #
        # On the first repair there is no previous RTL version.
        # On later repairs, previous_rtl contains the RTL version that failed
        # immediately before the current version.
        # ---------------------------------------------------------------------

        if previous_rtl is None:

            previous_rtl_section = (
                "No previous RTL version is available. "
                "This is the first repair attempt.\n\n"
            )

        else:

            previous_rtl_section = (
                "Previous failed RTL version for sanity checking:\n"
                "```systemverilog\n"
                f"{previous_rtl}\n"
                "```\n\n"
            )


        # ---------------------------------------------------------------------
        # Repair system prompt.
        #
        # The instructor tests are the authoritative feedback source.
        # ---------------------------------------------------------------------

        repair_system_prompt = (
            "You are an RTL debugging and repair agent. "
            "You are given a hardware specification, a current RTL "
            "implementation, and feedback from instructor-provided "
            "verification tests.\n\n"

            "Your task is to repair the current RTL so that it implements "
            "the specification correctly and passes the reported instructor "
            "tests.\n\n"

            "Rules:\n"

            "1. Treat the hardware specification as the authoritative "
            "source of truth.\n"

            "2. Treat the instructor test output as evidence of the current "
            "RTL's observed behavior. Use it to identify the root cause.\n"

            "3. Preserve the module name, port names, port directions, "
            "port widths, port types, and control encodings exactly.\n"

            "4. Preserve functionality that is already correct. Make the "
            "smallest necessary RTL change that fixes the reported problem.\n"

            "5. Do not add unrelated functionality, extra ports, new "
            "interfaces, or test-specific special cases.\n"

            "6. Produce synthesizable SystemVerilog compatible with "
            "Icarus Verilog using -g2012.\n"

            "7. Carefully verify signed versus unsigned operations, bit "
            "widths, truncation, casting, shift semantics, comparisons, "
            "control conditions, reset/clock behavior, and combinational "
            "versus sequential logic when applicable.\n"

            "8. Do not assume that compilation means functional correctness.\n"

            "9. Do not make speculative changes. Every modification should "
            "be justified by the specification and the reported instructor "
            "failure.\n"

            "10. Preserve correct fixes already present in the current RTL. "
            "Do not undo a previous correction unless the instructor feedback "
            "and specification demonstrate that it is incorrect.\n"

            "11. When a previous failed RTL version is provided, compare it "
            "against the current RTL before proposing the repair. Do not "
            "repeat the same implementation strategy that already failed. "
            "If the previous attempt failed to address the reported behavior, "
            "reconsider the underlying RTL logic rather than making only "
            "cosmetic changes such as renaming signals or reformatting code.\n"

            "12. The previous RTL is provided only as a sanity check. The "
            "current RTL, hardware specification, and instructor feedback "
            "remain authoritative. Do not revert correct changes merely to "
            "make the new RTL different.\n"

            "13. Return only the complete corrected SystemVerilog RTL inside "
            "one fenced code block. Do not return explanations, analysis, "
            "or multiple alternatives.\n"
        )


        # ---------------------------------------------------------------------
        # Repair user prompt.
        #
        # The repair agent receives:
        #
        #   1. Hardware specification
        #   2. Current RTL
        #   3. Immediately previous failed RTL (if available)
        #   4. Instructor feedback
        #
        # The generated TB is NOT supplied to the repair agent.
        # ---------------------------------------------------------------------

        repair_user_prompt = (
            f"Repair the following SystemVerilog RTL.\n\n"

            f"Top module: {top_module}\n\n"

            f"Hardware specification:\n"
            f"{content}\n\n"

            f"Current RTL:\n"
            f"```systemverilog\n"
            f"{current_rtl}\n"
            f"```\n\n"

            f"{previous_rtl_section}"

            f"Instructor sample-test feedback for THIS EXACT RTL VERSION:\n"
            f"```text\n"
            f"{instructor_output}\n"
            f"```\n\n"

            f"First identify the specific behavior demonstrated by the "
            f"reported instructor failures. Compare the expected and actual "
            f"behavior when that information is available. Determine the "
            f"smallest RTL construct that is responsible for the mismatch.\n\n"

            f"Before producing the repair, compare the current RTL with the "
            f"previous failed RTL version when one is provided. Use this "
            f"comparison as a sanity check to avoid repeating the same failed "
            f"implementation strategy. Do not make superficial changes merely "
            f"to make the RTL text look different.\n\n"

            f"If the previous implementation already attempted to address the "
            f"same issue and the instructor tests still failed, reconsider the "
            f"underlying RTL logic and use a different correction strategy.\n\n"

            f"Then modify the current RTL to correct that root cause while "
            f"preserving all behavior that is already correct.\n\n"

            f"Pay particular attention to signedness, bit widths, truncation, "
            f"explicit casts, shift semantics, comparisons, control conditions, "
            f"reset/clock behavior, and combinational versus sequential logic "
            f"where applicable.\n\n"

            f"Do not introduce test-specific logic or special cases. "
            f"Do not change the module interface or control encodings. "
            f"Do not remove a correct existing fix without evidence that it "
            f"conflicts with the specification or instructor feedback.\n\n"

            f"Mentally re-evaluate the reported failing cases after the repair "
            f"and ensure the corrected RTL remains consistent with the complete "
            f"hardware specification.\n\n"

            f"Return only the complete corrected SystemVerilog RTL inside one "
            f"fenced code block. Do not provide explanations."
        )


        print(
            f"Phase C: requesting repair attempt "
            f"{repair_attempt}..."
        )


        repair_result = model.generate_full(
            repair_user_prompt,
            system_prompt=repair_system_prompt,
        )


        repair_response = repair_result.content


        repaired_rtl = strip_markdown_code_blocks(
            repair_response
        )


        # ---------------------------------------------------------------------
        # Save revised RTL and complete repair history.
        # ---------------------------------------------------------------------

        revised_rtl_path = (
            args.out_dir
            / f"revised_rtl_{repair_attempt}.sv"
        )


        write_file(
            revised_rtl_path,
            repaired_rtl,
        )


        write_file(
            args.out_dir
            / f"phaseC_prompt_system_{repair_attempt}.txt",
            repair_system_prompt + "\n",
        )


        write_file(
            args.out_dir
            / f"phaseC_prompt_user_{repair_attempt}.txt",
            repair_user_prompt + "\n",
        )


        write_file(
            args.out_dir
            / f"phaseC_response_{repair_attempt}.txt",
            repair_response,
        )


        repair_metadata = (
            f"model: {repair_result.model}\n"
            f"provider: {repair_result.provider}\n"
            f"settings: {repair_result.settings}\n"
            f"usage: {repair_result.usage}\n"
        )


        write_file(
            args.out_dir
            / f"phaseC_metadata_{repair_attempt}.txt",
            repair_metadata,
        )


        # ---------------------------------------------------------------------
        # Sanity-check repaired RTL.
        # ---------------------------------------------------------------------

        if not repaired_rtl.strip():

            raise RuntimeError(
                f"LLM returned empty RTL on repair attempt "
                f"{repair_attempt}."
            )


        if f"module {top_module}" not in repaired_rtl:

            raise RuntimeError(
                f"Repair attempt {repair_attempt} does not contain "
                f"the expected module '{top_module}'."
            )


        if "endmodule" not in repaired_rtl:

            raise RuntimeError(
                f"Repair attempt {repair_attempt} does not contain "
                "'endmodule'."
            )


        print(
            f"Phase C: saved revised RTL to "
            f"{revised_rtl_path}"
        )


        # ---------------------------------------------------------------------
        # Move to the repaired RTL for the next iteration.
        #
        # IMPORTANT:
        # Save the RTL that JUST FAILED as previous_rtl BEFORE moving to the
        # newly generated RTL.
        #
        # On the next iteration:
        #
        #   current_rtl  = newly repaired RTL
        #   previous_rtl = RTL that just failed
        # ---------------------------------------------------------------------

        previous_rtl = current_rtl

        current_rtl_path = revised_rtl_path

        attempt += 1


    # =========================================================================
    # PHASE B / C2: GENERATE, VALIDATE, AND REPAIR THE TESTBENCH
    # =========================================================================
    # This stage is reached only when the instructor suite accepted final_rtl.sv.
    # The RTL is frozen; failures here can repair only the generated testbench.
    tb_final_result = "SKIPPED"
    tb_repair_attempt = 0

    if final_status == "PASS":
        tb_path = generate_or_reuse_initial_tb()
        add_run_log("")
        add_run_log("PHASE B - TESTBENCH GENERATION AFTER RTL ACCEPTANCE")
        add_run_log("===================================================")
        add_run_log(f"Initial Testbench : {tb_path.name}")

        while True:
            tb_code = read_file(tb_path)
            if not tb_code.strip() or "module" not in tb_code or "endmodule" not in tb_code:
                raise RuntimeError("Current generated testbench is incomplete.")

            generated_sim_dir = args.out_dir / "simulation_build"
            generated_sim_dir.mkdir(parents=True, exist_ok=True)
            generated_sim_file = generated_sim_dir / f"generated_tb_final_rtl_attempt_{tb_repair_attempt}.vvp"
            generated_compile_ok, generated_compile_output = run_iverilog_compile(
                final_path, tb_path, output_file=generated_sim_file
            )
            generated_output = generated_compile_output
            if generated_compile_ok:
                _, generated_run_output = run_vvp(generated_sim_file)
                generated_output += "\n" + generated_run_output

            generated_passed = None
            generated_failed = None
            generated_total = None
            tb_final_result = "UNKNOWN"
            for line in generated_output.splitlines():
                line = line.strip()
                try:
                    if line.startswith("TESTS_PASSED:"):
                        generated_passed = int(line.split(":", 1)[1].strip())
                    elif line.startswith("TESTS_ERRORS:") or line.startswith("TESTS_FAILED:"):
                        generated_failed = int(line.split(":", 1)[1].strip())
                    elif line.startswith("TESTS_TOTAL:"):
                        generated_total = int(line.split(":", 1)[1].strip())
                except ValueError:
                    pass
                if line == "RESULT: PASS":
                    tb_final_result = "PASS"
                elif line == "RESULT: FAIL":
                    tb_final_result = "FAIL"
            if not generated_compile_ok:
                tb_final_result = "COMPILE FAIL"

            tb_protocol_passed = (
                generated_compile_ok
                and tb_final_result == "PASS"
                and generated_passed is not None
                and generated_failed == 0
                and generated_total is not None
                and generated_total > 0
                and generated_total == generated_passed + generated_failed
            )
            write_file(
                args.out_dir / f"phaseD_attempt_{tb_repair_attempt}.log",
                f"FROZEN RTL: {final_path}\nTESTBENCH: {tb_path}\n\n"
                "GENERATED TESTBENCH VALIDATION\n" + "=" * 70 + "\n" + generated_output,
            )
            add_run_log("")
            add_run_log(f"PHASE C2 - TESTBENCH ATTEMPT {tb_repair_attempt}")
            add_run_log(f"Testbench     : {tb_path.name}")
            add_run_log(f"Compile       : {'PASS' if generated_compile_ok else 'FAIL'}")
            add_run_log(f"Result        : {tb_final_result}")
            if generated_passed is not None:
                add_run_log(f"Tests Passed  : {generated_passed}")
            if generated_failed is not None:
                add_run_log(f"Tests Failed  : {generated_failed}")
            if generated_total is not None:
                add_run_log(f"Tests Total   : {generated_total}")

            if tb_protocol_passed:
                write_file(final_tb_path, tb_code)
                add_run_log(f"Accepted TB   : {final_tb_path.name}")
                break

            if tb_repair_attempt >= MAX_TB_RETRIES:
                add_run_log("TB repair budget exhausted; testbench was not accepted.")
                break

            repair_number = tb_repair_attempt + 1
            tb_repair_system_prompt = (
                "You are a SystemVerilog testbench debugging and repair agent. "
                "You are given a hardware specification, an instructor-accepted frozen RTL, "
                "a current self-checking testbench, and compile/simulation feedback.\n\n"
                "Your task is to repair only the testbench so that it correctly verifies the "
                "specified design when compiled with Icarus Verilog.\n\n"
                "Rules:\n"
                "1. Treat the hardware specification as the authoritative source of expected behavior.\n"
                "2. The frozen RTL passed the instructor suite; provide it only to confirm the DUT interface and diagnose simulator behavior. Do not treat unspecified RTL behavior as the oracle.\n"
                "3. Do not modify, regenerate, or request changes to the RTL or DUT interface.\n"
                "4. Preserve the exact DUT module name, ports, widths, directions, clocking, reset, and sampling requirements.\n"
                "5. Use the supplied compile and simulation log as concrete evidence of syntax, interface, timing, scheduling, checker, expected-value, or result-reporting faults.\n"
                "6. Derive every expected value from the specification, including signedness, widths, boundary values, reset behavior, and control encodings.\n"
                "7. Preserve meaningful coverage of normal behavior, corner cases, and boundary conditions. Do not remove, weaken, bypass, or tailor checks merely to make the frozen RTL pass.\n"
                "8. Maintain self-checking behavior, explicit passed/error counts, clear failure messages, and the standardized TESTS_PASSED, TESTS_ERRORS, TESTS_TOTAL, and RESULT lines.\n"
                "9. Ensure TESTS_TOTAL equals TESTS_PASSED plus TESTS_ERRORS. On a passing simulation, do not print the literal substring FAIL anywhere in runtime output; print RESULT: FAIL only conditionally when one or more checks fail.\n"
                "10. Produce Icarus Verilog compatible SystemVerilog using -g2012 and avoid simulator-specific or unsupported constructs.\n"
                "11. Carefully check declarations, tasks, functions, begin/end pairs, loops, timing controls, module instantiation, and all procedural statements before returning.\n"
                "12. Return only one complete corrected testbench in a single fenced SystemVerilog code block."
            )
            tb_repair_user_prompt = (
                f"Repair the following self-checking SystemVerilog testbench.\n\n"
                f"Top module: {top_module}\n\n"
                f"Hardware specification:\n{content}\n\n"
                f"Frozen instructor-accepted RTL (interface and simulation diagnosis only):\n"
                f"```systemverilog\n{read_file(final_path)}\n```\n\n"
                f"Current testbench:\n```systemverilog\n{tb_code}\n```\n\n"
                f"Compile and simulation feedback for this exact RTL/TB pair:\n"
                f"```text\n{generated_output}\n```\n\n"
                f"Repair only the demonstrated testbench issue. Keep the testbench specification-derived and do not weaken checks simply to obtain a PASS."
            )
            repair_result = model.generate_full(tb_repair_user_prompt, system_prompt=tb_repair_system_prompt)
            repair_response = repair_result.content
            repaired_tb = strip_markdown_code_blocks(repair_response)
            if not repaired_tb.strip() or "module" not in repaired_tb or "endmodule" not in repaired_tb:
                raise RuntimeError(f"Testbench repair attempt {repair_number} is incomplete.")
            tb_path = args.out_dir / f"revised_{top_module}_tb_{repair_number}.sv"
            write_file(tb_path, repaired_tb)
            write_file(args.out_dir / f"phaseD_prompt_system_{repair_number}.txt", tb_repair_system_prompt + "\n")
            write_file(args.out_dir / f"phaseD_prompt_user_{repair_number}.txt", tb_repair_user_prompt + "\n")
            write_file(args.out_dir / f"phaseD_response_{repair_number}.txt", repair_response)
            write_file(
                args.out_dir / f"phaseD_metadata_{repair_number}.txt",
                f"model: {repair_result.model}\nprovider: {repair_result.provider}\n"
                f"settings: {repair_result.settings}\nusage: {repair_result.usage}\n",
            )
            add_run_log(f"Decision      : requested testbench repair {repair_number}")
            tb_repair_attempt += 1
    else:
        add_run_log("")
        add_run_log("PHASE B/C2 - TESTBENCH SKIPPED")
        add_run_log("Reason: no RTL version passed the authoritative instructor suite.")
    # =========================================================================
    # FINAL CLEAN RUN LOG
    # =========================================================================

    add_run_log("")
    add_run_log("")
    add_run_log("=" * 70)
    add_run_log("FINAL RESULT")
    add_run_log("=" * 70)
    add_run_log("")


    add_run_log(
        f"Final RTL        : {final_path.name}"
    )


    add_run_log(
        f"Final RTL Source : {final_rtl_source}"
    )


    add_run_log("")


    # -------------------------------------------------------------------------
    # Final generated-TB result from the post-RTL Phase C2 validation.
    # -------------------------------------------------------------------------

    add_run_log(
        f"Generated TB     : {tb_final_result}"
    )


    # -------------------------------------------------------------------------
    # Final instructor result.
    # -------------------------------------------------------------------------

    if (
        instructor_tests_passed is not None
        and instructor_tests_total is not None
    ):

        add_run_log(
            f"Instructor Tests : "
            f"{instructor_tests_passed}/{instructor_tests_total} "
            f"{instructor_result}"
        )

    else:

        add_run_log(
            f"Instructor Tests : {instructor_result}"
        )


    add_run_log("")


    add_run_log(
        f"Repairs Attempted: {attempt}"
    )


    add_run_log(
        f"RTL Versions     : {len(attempt_results)}"
    )


    add_run_log("")


    add_run_log(
        f"FINAL STATUS: {'PASS' if final_status == 'PASS' and tb_final_result == 'PASS' else 'FAIL'}"
    )


    add_run_log("")
    add_run_log("=" * 70)
    add_run_log("RUN COMPLETE")
    add_run_log("=" * 70)


    # -------------------------------------------------------------------------
    # Write the complete clean run log.
    # -------------------------------------------------------------------------

    write_file(
        run_log_path,
        "\n".join(run_log) + "\n",
    )


    print()
    print("=" * 70)
    print("Run complete.")
    print(f"Clean run log saved to: {run_log_path}")
    print("=" * 70)

    # <<< END STUDENT PHASE C CODE

if __name__ == "__main__":
    main()
