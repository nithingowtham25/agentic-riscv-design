"""Smoke tests for the provided Assignment 4 infrastructure.

These cover ONLY the bare-minimum modules shipped with the assignment
(search_space, tool_runner). You build the LLM client, metric parsing/scoring,
and the orchestration loop yourself -- those are not tested here.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from student_code.search_space import (
    BASELINE_PARAMS,
    param_space,
    split_params,
    valid_params,
)
from student_code.tool_runner import (
    fill_template,
    missing_artifacts,
    run_command,
    unresolved_placeholders,
    validate_trial_id,
)


class SearchSpaceTests(unittest.TestCase):
    def test_baseline_is_valid(self) -> None:
        self.assertTrue(valid_params(BASELINE_PARAMS))
        synthesis, pnr = split_params(BASELINE_PARAMS)
        self.assertEqual(set(synthesis) | set(pnr), set(param_space))

    def test_rejects_schema_and_value_errors(self) -> None:
        missing = dict(BASELINE_PARAMS)
        missing.pop(next(iter(missing)))
        self.assertFalse(valid_params(missing))

        extra = {**BASELINE_PARAMS, "UNSUPPORTED": 1}
        self.assertFalse(valid_params(extra))

        illegal = dict(BASELINE_PARAMS)
        illegal["CORE_UTILIZATION"] = 999
        self.assertFalse(valid_params(illegal))

        # Strict type check: an int where a float is required is rejected.
        wrong_type = dict(BASELINE_PARAMS)
        wrong_type["PLACE_DENSITY"] = 0
        self.assertFalse(valid_params(wrong_type))

        with self.assertRaises(ValueError):
            split_params(extra)


class ToolRunnerTests(unittest.TestCase):
    def test_template_and_placeholder_helpers(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            template = Path(directory) / "template.txt"
            template.write_text("A={A} B={B}\n", encoding="utf-8")
            completed = fill_template(template, {"A": 1})
            self.assertEqual(unresolved_placeholders(completed, ("A", "B")), ["B"])

    def test_trial_id_validation(self) -> None:
        self.assertEqual(validate_trial_id("trial_003"), "trial_003")
        for invalid in ("", "../escape", "has space", "/absolute"):
            with self.assertRaises(ValueError):
                validate_trial_id(invalid)

    def test_command_and_artifact_failures_are_explicit(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "command.log"
            success, output = run_command(
                ["lab4-command-that-does-not-exist"], log_path=log
            )
            self.assertFalse(success)
            self.assertIn("Failed to start command", output)
            self.assertEqual(missing_artifacts({"x": Path(directory) / "x"}, ("x",)), ["x"])
            self.assertTrue(log.is_file())


if __name__ == "__main__":
    unittest.main()
