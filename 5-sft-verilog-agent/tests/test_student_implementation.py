"""Optional checks for the student-owned data processing functions.

Run after implementing the TODOs:
    A5_TEST_STUDENT=1 python -m unittest discover -s tests -v

These tests assume you use the suggested response format strings. If you define
an alternate output format, adapt the tests and document that decision.
"""
import os
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1] / 'student_code'))


class DummyTokenizer:
    eos_token = '</s>'

    def apply_chat_template(self, messages, tokenize=False, add_generation_prompt=True):
        return 'PROMPT:' + messages[-1]['content'] + '\nRESPONSE:'

    def __call__(self, text, add_special_tokens=False):
        return {'input_ids': list(text)}  # one character per test token


@unittest.skipUnless(os.environ.get('A5_TEST_STUDENT') == '1',
                     'Complete the student TODOs, then set A5_TEST_STUDENT=1')
class StudentImplementationTests(unittest.TestCase):
    def test_target_format(self):
        from data_methods import make_completion
        row = {'question': 'Design a register', 'reasoning_trace': 'Use flip-flops',
               'generated_verilog': 'module TopModule; endmodule'}
        result = make_completion(row, 'reasoned')
        self.assertIn('Use flip-flops', result)
        self.assertIn('<think>', result)
        self.assertIn('<verilog>', result)
        self.assertIn('module TopModule', result)
        plain = make_completion(row, 'verilog-plain')
        self.assertIn('module TopModule', plain)

    def test_sampling_dedup_and_length(self):
        from data_methods import select_training_examples
        rows = [
            {'question': 'Implement item A', 'reasoning_trace': 'small',
             'generated_verilog': 'module TopModule; endmodule'},
            {'question': 'Implement item B', 'reasoning_trace': 'small',
             'generated_verilog': 'module TopModule; endmodule'},
            {'question': 'Implement item B', 'reasoning_trace': 'duplicate',
             'generated_verilog': 'module TopModule; endmodule'},
            {'question': 'Benchmark prompt', 'reasoning_trace': 'small',
             'generated_verilog': 'module TopModule; endmodule'},
        ]
        selected, notes = select_training_examples(
            rows, DummyTokenizer(), count=2, max_tokens=500, seed=7,
            response_format='reasoned', verified_only=False,
            benchmark_prompts={'benchmark prompt'})
        self.assertEqual(len(selected), 2)
        self.assertEqual({r['prompt'] for r in selected},
                         {'Implement item A', 'Implement item B'})
        self.assertTrue(all(set(row) == {'prompt', 'completion'} for row in selected))
        self.assertIsInstance(notes, dict)


if __name__ == '__main__':
    unittest.main()
