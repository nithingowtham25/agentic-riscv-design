#!/usr/bin/env python3
"""Driver for the student-written VeriThoughts sampling and formatting code."""
import argparse
import hashlib
import json
import re
from pathlib import Path

from datasets import load_dataset
from transformers import AutoTokenizer

from common import (BASE_MODEL, MODEL_CONTEXT_TOKENS, MIN_TRAIN_SAMPLES,
                    benchmark_problems, validate_sample_count,
                    validate_token_ceiling)
from data_methods import count_training_tokens, select_training_examples


def normalize(text):
    return re.sub(r'\s+', ' ', text).strip().casefold()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--benchmark-dir', default='external/verilog-eval/dataset_spec-to-rtl')
    parser.add_argument('--model', default=BASE_MODEL)
    parser.add_argument('--dataset', default='wilyub/VeriThoughtsTrainSet')
    parser.add_argument('--revision', default=None)
    parser.add_argument('--count', type=int, default=2500)
    parser.add_argument('--response-format', default='reasoned',
                        help='Passed to your make_completion() implementation')
    parser.add_argument('--max-tokens', type=int, required=True,
                        help='Total input + output + EOS token budget (max 16384)')
    parser.add_argument('--seed', type=int, default=42)
    parser.add_argument('--verified-only', action='store_true')
    parser.add_argument('--out', default='data/train.jsonl')
    args = parser.parse_args()
    validate_sample_count(args.count)
    validate_token_ceiling(args.max_tokens)

    tokenizer = AutoTokenizer.from_pretrained(args.model)
    source = load_dataset(args.dataset, split='train', revision=args.revision)
    if not {'question', 'generated_verilog'}.issubset(source.column_names):
        raise ValueError('Dataset must have question and generated_verilog columns')
    excluded = {normalize(p['prompt']) for p in benchmark_problems(args.benchmark_dir)}

    rows, selection_notes = select_training_examples(
        source, tokenizer, count=args.count, max_tokens=args.max_tokens,
        seed=args.seed, response_format=args.response_format,
        verified_only=args.verified_only, benchmark_prompts=excluded)
    if not isinstance(selection_notes, dict):
        raise ValueError('Return a dictionary with your selection decisions and counts')
    if len(rows) != args.count:
        raise ValueError(f'Expected {args.count} selected rows; got {len(rows)}')

    seen, lengths = set(), []
    for i, row in enumerate(rows):
        if set(row) != {'prompt', 'completion'}:
            raise ValueError(f'Row {i} must have exactly prompt and completion')
        question, answer = row['prompt'], row['completion']
        if not isinstance(question, str) or not question.strip() or not isinstance(answer, str) or not answer.strip():
            raise ValueError(f'Row {i} has an empty or invalid field')
        key = normalize(question)
        if key in seen or key in excluded:
            raise ValueError(f'Row {i} duplicates another prompt or the benchmark')
        seen.add(key)
        tokens = count_training_tokens(tokenizer, question, answer)
        if tokens > args.max_tokens:
            raise ValueError(f'Row {i} is {tokens} tokens; cap is {args.max_tokens}')
        lengths.append(tokens)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open('w', encoding='utf-8') as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + '\n')
    manifest = {
        'dataset': args.dataset,
        'revision_requested': args.revision,
        'dataset_fingerprint': source._fingerprint,
        'dataset_rows': len(source),
        'tokenizer': args.model,
        'seed': args.seed,
        'verified_only': args.verified_only,
        'response_format': args.response_format,
        'max_tokens': args.max_tokens,
        'model_context_tokens': MODEL_CONTEXT_TOKENS,
        'minimum_required': MIN_TRAIN_SAMPLES,
        'selected_count': len(rows),
        'min_selected_tokens': min(lengths),
        'max_selected_tokens': max(lengths),
        'average_selected_tokens': round(sum(lengths) / len(lengths), 1),
        'train_sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
        'benchmark_overlap_check': 'Normalized exact prompt match; does not detect semantic overlap',
        'student_selection_notes': selection_notes,
    }
    (out.parent / 'selection_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Wrote {len(rows)} rows to {out}; length range {min(lengths)}-{max(lengths)} tokens')


if __name__ == '__main__':
    main()
