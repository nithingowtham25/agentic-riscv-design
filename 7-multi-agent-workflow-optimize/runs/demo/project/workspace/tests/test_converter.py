"""Tests for src/converter.py – run from workspace/ directory."""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

# Make sure workspace/ is on sys.path so "from src.converter import …" works
# when the test runner is invoked from workspace/.
_WORKSPACE = Path(__file__).resolve().parent.parent
if str(_WORKSPACE) not in sys.path:
    sys.path.insert(0, str(_WORKSPACE))

from src.converter import binary_to_decimal, decimal_to_binary  # noqa: E402


class TestDecimalToBinary(unittest.TestCase):
    def test_zero(self):
        self.assertEqual(decimal_to_binary(0), "0")

    def test_one(self):
        self.assertEqual(decimal_to_binary(1), "1")

    def test_two(self):
        self.assertEqual(decimal_to_binary(2), "10")

    def test_ten(self):
        self.assertEqual(decimal_to_binary(10), "1010")

    def test_255(self):
        self.assertEqual(decimal_to_binary(255), "11111111")

    def test_negative_raises(self):
        with self.assertRaises(ValueError):
            decimal_to_binary(-1)


class TestBinaryToDecimal(unittest.TestCase):
    def test_zero_string(self):
        self.assertEqual(binary_to_decimal("0"), 0)

    def test_one_string(self):
        self.assertEqual(binary_to_decimal("1"), 1)

    def test_1010(self):
        self.assertEqual(binary_to_decimal("1010"), 10)

    def test_leading_zeros(self):
        self.assertEqual(binary_to_decimal("00101"), 5)

    def test_empty_raises(self):
        with self.assertRaises(ValueError):
            binary_to_decimal("")

    def test_invalid_digit_raises(self):
        with self.assertRaises(ValueError):
            binary_to_decimal("102")

    def test_negative_string_raises(self):
        with self.assertRaises(ValueError):
            binary_to_decimal("-1")

    def test_0b_prefix_raises(self):
        with self.assertRaises(ValueError):
            binary_to_decimal("0b10")

    def test_space_prefix_raises(self):
        with self.assertRaises(ValueError):
            binary_to_decimal(" 10")


class TestCLI(unittest.TestCase):
    """Exercise the __main__ entry-point via subprocess."""

    _CONVERTER = str(_WORKSPACE / "src" / "converter.py")

    def _run(self, *args):
        return subprocess.run(
            [sys.executable, self._CONVERTER, *args],
            capture_output=True,
            text=True,
        )

    def test_decimal_to_binary_cli(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "result.json"
            proc = self._run("--decimal", "10", "--out", str(out))
            self.assertEqual(proc.returncode, 0, msg=proc.stderr)
            data = json.loads(out.read_text())
            self.assertEqual(data["decimal"], 10)
            self.assertEqual(data["binary"], "1010")

    def test_binary_to_decimal_cli(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "result.json"
            proc = self._run("--binary", "1010", "--out", str(out))
            self.assertEqual(proc.returncode, 0, msg=proc.stderr)
            data = json.loads(out.read_text())
            self.assertEqual(data["decimal"], 10)
            self.assertEqual(data["binary"], "1010")

    def test_cli_preserves_leading_zeros_in_binary(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "result.json"
            proc = self._run("--binary", "00101", "--out", str(out))
            self.assertEqual(proc.returncode, 0, msg=proc.stderr)
            data = json.loads(out.read_text())
            self.assertEqual(data["binary"], "00101")
            self.assertEqual(data["decimal"], 5)

    def test_invalid_binary_cli_exits_nonzero(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "result.json"
            proc = self._run("--binary", "102", "--out", str(out))
            self.assertNotEqual(proc.returncode, 0)

    def test_negative_decimal_cli_exits_nonzero(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "result.json"
            proc = self._run("--decimal", "-5", "--out", str(out))
            self.assertNotEqual(proc.returncode, 0)


if __name__ == "__main__":
    unittest.main()
