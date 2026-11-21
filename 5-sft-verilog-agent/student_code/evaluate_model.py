#!/usr/bin/env python3
"""Run local Code Llama on VerilogEval v2 spec-to-RTL prompts (no API)."""
import argparse
import json
from pathlib import Path

import torch
from peft import PeftModel
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
from common import BASE_MODEL, BENCHMARK, benchmark_problems, model_prompt, extract_verilog


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dataset-dir', default='external/verilog-eval/dataset_spec-to-rtl')
    parser.add_argument('--model', default=BASE_MODEL)
    parser.add_argument('--adapter', default=None)
    parser.add_argument('--out', required=True)
    parser.add_argument('--max-new-tokens', type=int, default=2048)
    parser.add_argument('--limit', type=int, help='Smoke test only; cannot be scored as a full run')
    args = parser.parse_args()
    if not torch.cuda.is_available():
        raise RuntimeError('Reserve a Grace GPU via Slurm before running inference')
    problems = benchmark_problems(args.dataset_dir)
    if args.limit:
        problems = problems[:args.limit]
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    if any((out / n).exists() for n in ('responses.jsonl', 'samples.jsonl')):
        raise FileExistsError(f'{out}: remove old experimental files or use a new directory')

    tokenizer = AutoTokenizer.from_pretrained(args.model)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
    dtype = torch.bfloat16 if torch.cuda.is_bf16_supported() else torch.float16
    quantization = BitsAndBytesConfig(
        load_in_4bit=True, bnb_4bit_quant_type='nf4',
        bnb_4bit_use_double_quant=True, bnb_4bit_compute_dtype=dtype,
    )
    model = AutoModelForCausalLM.from_pretrained(
        args.model, quantization_config=quantization, torch_dtype=dtype, device_map={'': 0},
    )
    if args.adapter:
        model = PeftModel.from_pretrained(model, args.adapter)
    model.eval()
    settings = {'do_sample': False, 'max_new_tokens': args.max_new_tokens,
                'num_return_sequences': 1, 'temperature': None, 'top_p': None,
                'quantization': '4bit-nf4'}
    with (out / 'responses.jsonl').open('w', encoding='utf-8') as responses, \
         (out / 'samples.jsonl').open('w', encoding='utf-8') as samples:
        for i, problem in enumerate(problems, 1):
            instruction = model_prompt(tokenizer, problem['prompt'])
            inputs = tokenizer(instruction, add_special_tokens=False, return_tensors='pt')
            inputs = {k: v.to('cuda') for k, v in inputs.items()}
            with torch.inference_mode():
                result = model.generate(
                    **inputs, do_sample=False, max_new_tokens=args.max_new_tokens,
                    pad_token_id=tokenizer.eos_token_id,
                )
            raw = tokenizer.decode(result[0, inputs['input_ids'].shape[1]:], skip_special_tokens=True)
            completion = extract_verilog(raw)
            record = {
                'task_id': problem['task_id'], 'prompt': problem['prompt'],
                'raw_response': raw, 'completion': completion,
                'base_model': args.model, 'adapter': args.adapter,
                'generation_settings': settings,
            }
            responses.write(json.dumps(record, ensure_ascii=False) + '\n')
            responses.flush()
            samples.write(json.dumps({'task_id': problem['task_id'],
                                      'completion': completion}, ensure_ascii=False) + '\n')
            samples.flush()
            print(f"{i:03}/{len(problems)} {problem['task_id']}", flush=True)
    (out / 'generation_settings.json').write_text(
        json.dumps({'model': args.model, 'adapter': args.adapter, **settings,
                    'benchmark': BENCHMARK, 'task_count': len(problems)}, indent=2) + '\n')
    print('Generation complete. Next, run slurm/cpu_score.sbatch to use the v2 Makefile.')


if __name__ == '__main__':
    main()
