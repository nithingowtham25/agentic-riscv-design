#!/usr/bin/env python3
"""Score local RTL with the unmodified VerilogEval v2 Makefile/testbench flow.
Only the generated RTL is passed as the design-under-test.
"""
import argparse
import csv
import json
import shutil
import subprocess
from pathlib import Path

from common import BENCHMARK, benchmark_problems


def read_jsonl(path):
    return [json.loads(x) for x in Path(path).read_text(encoding='utf-8').splitlines() if x.strip()]


def configure_build(repo, dataset, build):
    build.mkdir(parents=True, exist_ok=True)
    cmd = [str(repo / 'configure'), '--with-task=spec-to-rtl',
           '--with-model=manual-rtl-coder', '--with-examples=0',
           '--with-samples=1', '--with-temperature=0', '--with-top-p=0.01',
           f'--with-dataset={dataset}', f'--with-problems={dataset / "problems.txt"}']
    subprocess.run(cmd, cwd=build, check=True)


def parse_official_csv(path, expected):
    results = {}
    with open(path, newline='', encoding='utf-8') as handle:
        for fields in csv.reader(handle):
            if not fields:
                continue
            if len(fields) != 5:
                raise ValueError(f'Unexpected VerilogEval CSV row: {fields}')
            task_id, passed, total, rate, code = fields
            if task_id in results or task_id not in expected:
                raise ValueError('Unexpected or duplicate benchmark ID ' + task_id)
            if int(total) != 1 or int(passed) not in (0, 1):
                raise ValueError(f'Expected one scored sample per task: {fields}')
            # The official v2 analyzer uses a dot (.) for a passing test.
            if (code == '.') != (int(passed) == 1):
                raise ValueError(f'Contradictory official result: {fields}')
            results[task_id] = {'passed': bool(int(passed)), 'result': code}
    if set(results) != set(expected):
        raise ValueError(f'Official CSV has {len(results)} of {len(expected)} required problems')
    return results


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', default='external/verilog-eval')
    ap.add_argument('--stage', required=True, choices=('before', 'after'))
    ap.add_argument('--jobs', type=int, default=4)
    args = ap.parse_args()
    repo = Path(args.repo).resolve()
    dataset = repo / 'dataset_spec-to-rtl'
    problems = benchmark_problems(dataset)
    expected = {p['task_id'] for p in problems}
    stage = Path('output') / args.stage
    responses = read_jsonl(stage / 'responses.jsonl')
    samples = read_jsonl(stage / 'samples.jsonl')
    if len(responses) != 156 or len(samples) != 156:
        raise ValueError('Full run required: 156 responses and 156 code samples')
    for rows in (responses, samples):
        ids = [r['task_id'] for r in rows]
        if set(ids) != expected or len(set(ids)) != 156:
            raise ValueError('Missing, extra, or duplicated problem IDs')
    raw_by_id = {r['task_id']: r for r in responses}
    for row in samples:
        if raw_by_id[row['task_id']]['completion'] != row['completion']:
            raise ValueError('Raw response and submitted RTL differ: ' + row['task_id'])

    build = (stage / 'v2_build').resolve()
    if (build / 'summary.csv').exists():
        raise FileExistsError(f'{build}/summary.csv exists: do not overwrite scored evidence')
    configure_build(repo, dataset, build)
    for row in samples:
        task_id = row['task_id']
        folder = build / task_id
        folder.mkdir(parents=True, exist_ok=True)
        stem = f'{task_id}_sample01'
        (folder / (stem + '.sv')).write_text(row['completion'] + '\n', encoding='utf-8')
        # Official v2 analyzer expects these generation-log fields.
        (folder / (stem + '-sv-generate.log')).write_text(
            'prompt_tokens = 0\nresp_tokens = 0\ntotal_cost = 0.0\n', encoding='utf-8')
    print('Scoring using the upstream VerilogEval v2 make targets.', flush=True)
    subprocess.run(['make', '-j', str(args.jobs), 'sv-iv-test'], cwd=build, check=True)
    with (stage / 'official_v2_summary.txt').open('w', encoding='utf-8') as logfile:
        subprocess.run(['make', 'sv-iv-analyze'], cwd=build, stdout=logfile,
                       stderr=subprocess.STDOUT, check=True)
    if not (build / 'summary.csv').is_file():
        raise FileNotFoundError('The official v2 analyzer did not produce summary.csv')
    shutil.copy2(build / 'summary.csv', stage / 'official_v2_summary.csv')
    official = parse_official_csv(build / 'summary.csv', expected)
    scored_rows = []
    merged = []
    for row in responses:
        code = official[row['task_id']]
        scored_rows.append({'task_id': row['task_id'], 'completion': row['completion'], **code})
        merged.append({**row, **code})
    with (stage / 'samples.jsonl_results.jsonl').open('w', encoding='utf-8') as handle:
        for row in scored_rows:
            handle.write(json.dumps(row, ensure_ascii=False) + '\n')
    passed = sum(x['passed'] for x in merged)
    score = {'passed': passed, 'total': 156, 'pass_at_1': passed / 156}
    result = {'benchmark': BENCHMARK, 'score': score, 'responses': merged}
    (stage / 'benchmark_results.json').write_text(
        json.dumps(result, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(f'{args.stage}: {passed}/156 pass; pass@1={score["pass_at_1"]:.4f}')


if __name__ == '__main__':
    main()
