"""Offline format tests; no GPU, token or dataset download needed."""
import sys
import tempfile
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parents[1] / 'student_code'))
from common import (extract_verilog, benchmark_problems,
                    validate_sample_count, validate_token_ceiling)
from score_v2 import parse_official_csv


class FormatTests(unittest.TestCase):
    def test_minimum_count_and_context(self):
        validate_sample_count(2500)
        validate_sample_count(5000)
        validate_token_ceiling(16384)
        with self.assertRaises(ValueError):
            validate_sample_count(2499)
        with self.assertRaises(ValueError):
            validate_token_ceiling(16385)

    def test_extract_full_module(self):
        raw = '<think>Reason</think><verilog>module TopModule(input a, output y); assign y=a; endmodule</verilog>'
        self.assertEqual(extract_verilog(raw), 'module TopModule(input a, output y); assign y=a; endmodule\n')

    def test_extract_fence(self):
        raw = '```verilog\nmodule TopModule; endmodule\n```'
        self.assertEqual(extract_verilog(raw), 'module TopModule; endmodule\n')

    def test_no_module_is_not_repaired(self):
        self.assertEqual(extract_verilog('<think>hello</think>'), '')

    def test_benchmark_list_and_csv(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            (directory / 'problems.txt').write_text('\n'.join(f'Prob{i:03}' for i in range(156)))
            for i in range(156):
                (directory / f'Prob{i:03}_prompt.txt').write_text('Design an adder')
            self.assertEqual(len(benchmark_problems(directory)), 156)
            csv_file = directory / 'summary.csv'
            csv_file.write_text('\n'.join(f'Prob{i:03},{int(i==0)},1,{float(i==0)},' + ('.' if i == 0 else 'S') for i in range(156)))
            result = parse_official_csv(csv_file, {f'Prob{i:03}' for i in range(156)})
            self.assertEqual(sum(v['passed'] for v in result.values()), 1)


if __name__ == '__main__':
    unittest.main()
