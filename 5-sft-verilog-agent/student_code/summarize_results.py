#!/usr/bin/env python3
"""Compare the two officially scored VerilogEval v2 result files."""
import argparse
import json
from pathlib import Path
from common import BENCHMARK, benchmark_problems


def load(path, expected):
    data = json.loads(Path(path).read_text(encoding='utf-8'))
    if data['benchmark'] != BENCHMARK or data['score']['total'] != 156:
        raise ValueError(f'Incorrect benchmark or total in {path}')
    rows = data['responses']
    ids = [x['task_id'] for x in rows]
    if len(ids) != 156 or len(set(ids)) != 156 or set(ids) != expected:
        raise ValueError(f'{path} must hold exactly 156 unique v2 problems')
    passed = sum(r['passed'] for r in rows)
    if passed != data['score']['passed'] or abs(data['score']['pass_at_1'] - passed / 156) > 1e-9:
        raise ValueError(f'Pass count mismatch in {path}')
    return data, {x['task_id']: x for x in rows}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dataset-dir', default='external/verilog-eval/dataset_spec-to-rtl')
    ap.add_argument('--before', default='output/before/benchmark_results.json')
    ap.add_argument('--after', default='output/after/benchmark_results.json')
    ap.add_argument('--out', default='output/comparison.json')
    args = ap.parse_args()
    expected = {p['task_id'] for p in benchmark_problems(args.dataset_dir)}
    before, b = load(args.before, expected)
    after, a = load(args.after, expected)
    improved = sorted(k for k in expected if not b[k]['passed'] and a[k]['passed'])
    regressed = sorted(k for k in expected if b[k]['passed'] and not a[k]['passed'])
    unchanged_pass = sum(b[k]['passed'] and a[k]['passed'] for k in expected)
    unchanged_fail = sum(not b[k]['passed'] and not a[k]['passed'] for k in expected)
    result = {'benchmark': BENCHMARK, 'before': before['score'], 'after': after['score'],
              'fail_to_pass': len(improved), 'pass_to_fail': len(regressed),
              'pass_to_pass': unchanged_pass, 'fail_to_fail': unchanged_fail,
              'delta_percentage_points': 100 * (after['score']['pass_at_1'] - before['score']['pass_at_1']),
              'improved_task_ids': improved, 'regressed_task_ids': regressed}
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
