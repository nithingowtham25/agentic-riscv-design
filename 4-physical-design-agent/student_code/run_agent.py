#!/usr/bin/env python3
"""Assignment 4 physical-design evaluator and feedback-driven search."""
from __future__ import annotations

import argparse
import itertools
import json
import math
import os
from pathlib import Path
import shutil
import sys
import urllib.request
import uuid

from config import (CLOCK_PERIOD_PS, IO_DELAY_PS, DEFAULT_CONFIG_TEMPLATE,
                    DEFAULT_CONSTRAINT_TEMPLATE, DEFAULT_MODEL, DEFAULT_OUTPUT_DIR,
                    DEFAULT_WORK_DIR, DESIGN_PATH, RTL_FILES)
from search_space import BASELINE_PARAMS, param_space, search_space_as_json, valid_params
from tool_runner import (fill_template, unresolved_placeholders, run_synthesis, run_pnr,
                         generate_orfs_metadata, orfs_trial_paths, missing_artifacts,
                         SYNTHESIS_ARTIFACT_KEYS, PNR_ARTIFACT_KEYS)
from io_utils import write_json, write_text


def first_object(text):
    """Extract the first decodable JSON object, including from fenced replies."""
    decoder = json.JSONDecoder()
    for pos, char in enumerate(text):
        if char == '{':
            try:
                obj, _ = decoder.raw_decode(text[pos:])
            except json.JSONDecodeError:
                continue
            if isinstance(obj, dict):
                return obj
    raise ValueError('No JSON object found in model response')


def metrics_from_metadata(path):
    data = json.loads(Path(path).read_text(encoding='utf-8'))
    # ORFS metadata-generate uses stage-prefixed flattened keys.
    aliases = {
        'area_um2': ('finish__design__instance__area',),
        'power_w': ('finish__power__total',),
        'wns_ps': ('finish__timing__setup__ws',),
        'tns_ps': ('finish__timing__setup__tns',),
    }
    metrics = {}
    for name, keys in aliases.items():
        for key in keys:
            if key in data and data[key] is not None:
                try:
                    value = float(data[key])
                except (TypeError, ValueError):
                    continue
                if math.isfinite(value):
                    metrics[name] = value
                    break
        else:
            raise ValueError(f'Missing or non-numeric post-PnR metric {name}; expected {keys}; inspect metadata.json')
    if metrics['area_um2'] <= 0 or metrics['power_w'] <= 0:
        raise ValueError('Area and power must be positive for baseline normalization')
    return metrics


def score(metrics, baseline):
    # Dimensionless score; a negative WNS costs 1000 per clock period missed.
    return (metrics['area_um2'] / baseline['area_um2'] +
            metrics['power_w'] / baseline['power_w'] +
            1000.0 * max(0.0, -metrics['wns_ps']) / CLOCK_PERIOD_PS)


def evaluate(params, directory, variant):
    directory.mkdir(parents=True, exist_ok=True)
    print(f'[{directory.name}] Preparing configuration; variant={variant}', flush=True)
    result = {'parameters': params, 'status': 'tool_failed', 'metrics': None, 'score': None,
              'units': {'area_um2': 'um^2', 'power_w': 'W', 'wns_ps': 'ps', 'tns_ps': 'ps'},
              'variant': variant}
    try:
        absent = [str(p) for p in RTL_FILES if not p.is_file()]
        if absent:
            raise RuntimeError('Missing RTL: ' + ', '.join(absent))
        sdc = directory / 'constraint.sdc'
        sdc_values = {'CLOCK_PERIOD_PS': CLOCK_PERIOD_PS, 'IO_DELAY_PS': IO_DELAY_PS}
        content = fill_template(DEFAULT_CONSTRAINT_TEMPLATE, sdc_values)
        if unresolved_placeholders(content, sdc_values):
            raise RuntimeError('Unresolved SDC placeholders')
        write_text(sdc, content)
        replacements = dict(params, RTL_FILES=' '.join(str(p) for p in RTL_FILES),
                            RTL_INCLUDE_DIRS=str(DESIGN_PATH / 'submodules'),
                            SDC_FILE=str(sdc.resolve()), WORK_HOME=str(DEFAULT_WORK_DIR), TRIAL_ID=variant)
        content = fill_template(DEFAULT_CONFIG_TEMPLATE, replacements)
        if unresolved_placeholders(content, replacements):
            raise RuntimeError('Unresolved config placeholders')
        config = write_text(directory / 'config.mk', content)
        paths = orfs_trial_paths(DEFAULT_WORK_DIR, variant)
        print(f'[{directory.name}] Synthesis starting (synth-report)...', flush=True)
        ok, _ = run_synthesis(config, variant, log_path=directory / 'synthesis.log')
        if not ok:
            raise RuntimeError('Synthesis failed; see synthesis.log')
        missing = missing_artifacts(paths, SYNTHESIS_ARTIFACT_KEYS)
        if missing:
            raise RuntimeError('Missing synthesis artifacts: ' + ', '.join(missing))
        print(f'[{directory.name}] Synthesis complete; place-and-route starting (finish)...', flush=True)
        ok, _ = run_pnr(config, variant, log_path=directory / 'pnr.log')
        if not ok:
            raise RuntimeError('Place-and-route failed; see pnr.log')
        missing = missing_artifacts(paths, PNR_ARTIFACT_KEYS)
        if missing:
            raise RuntimeError('Missing PnR artifacts: ' + ', '.join(missing))
        print(f'[{directory.name}] Place-and-route complete; generating metadata...', flush=True)
        ok, _ = generate_orfs_metadata(config, variant, log_path=directory / 'metadata_generation.log')
        if not ok or not paths['metadata'].is_file():
            raise RuntimeError('Metadata generation failed; see metadata_generation.log')
        shutil.copy2(paths['metadata'], directory / 'metadata.json')
        for key in ('synthesis_report', 'final_report', 'final_report_log'):
            shutil.copy2(paths[key], directory / (key + paths[key].suffix))
        result['metrics'] = metrics_from_metadata(directory / 'metadata.json')
        result['status'] = 'success'
        print(f'[{directory.name}] Metadata parsed; evaluation complete.', flush=True)
    except (OSError, ValueError, RuntimeError, KeyError) as exc:
        result['reason'] = str(exc)
        print(f'[{directory.name}] Evaluation failed: {exc}', flush=True)
    return result


def ask_tamu(model, prompt):
    key = os.environ.get('TAMUS_AI_CHAT_API_KEY')
    if not key:
        raise RuntimeError('TAMUS_AI_CHAT_API_KEY is not set')
    endpoint = os.environ.get('TAMUS_AI_CHAT_API_ENDPOINT', 'https://chat-api.tamu.ai').rstrip('/')
    model_id = model if model.startswith('protected.') else 'protected.' + model
    payload = {'model': model_id, 'stream': False,
               'messages': [{'role': 'user', 'content': prompt}]}
    request = urllib.request.Request(endpoint + '/openai/chat/completions',
        data=json.dumps(payload).encode(), method='POST',
        headers={'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json',
                 'Accept': 'application/json', 'User-Agent': 'tamu-ai-chat/1.0'})
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            envelope = json.loads(response.read().decode('utf-8'))
    except Exception as exc:
        raise RuntimeError(f'TAMU request failed ({type(exc).__name__}); check connectivity, model and credentials') from exc
    try:
        return envelope['choices'][0]['message']['content'], envelope.get('usage'), envelope.get('model')
    except (KeyError, IndexError, TypeError) as exc:
        raise RuntimeError('TAMU response lacked chat completion content') from exc


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--provider', choices=['tamu'], required=True)
    parser.add_argument('--trials', type=int, required=True)
    parser.add_argument('--model', default=DEFAULT_MODEL)
    args = parser.parse_args(argv)
    if args.trials < 1:
        parser.error('--trials must be at least 1')
    out = DEFAULT_OUTPUT_DIR
    if (out / 'baseline').exists() or (out / 'summary.json').exists() or any(out.glob('trial_*')):
        raise SystemExit('Existing output records found. Archive or move output/ before a new run to preserve evidence.')
    out.mkdir(parents=True, exist_ok=True)
    run_id = uuid.uuid4().hex[:12]
    print(f'Starting baseline; up to {args.trials} proposal attempts; provider={args.provider}; model={args.model}', flush=True)
    baseline = evaluate(dict(BASELINE_PARAMS), out / 'baseline', 'a4_' + run_id + '_baseline')
    if baseline['status'] != 'success':
        write_json(out / 'baseline' / 'result.json', baseline)
        write_json(out / 'summary.json', {'baseline': baseline, 'best': None, 'attempt_count': 0,
                   'stopping_reason': 'baseline_failed'})
        print('Baseline failed:', baseline.get('reason'), flush=True)
        return 1
    baseline['score'] = score(baseline['metrics'], baseline['metrics'])
    write_json(out / 'baseline' / 'result.json', baseline)
    print('Baseline:', json.dumps(baseline['metrics']), 'score:', baseline['score'], flush=True)
    best = baseline
    seen = {tuple(BASELINE_PARAMS[k] for k in sorted(param_space))}
    history = [baseline]
    attempts = 0
    unsuccessful = 0
    stop = 'trial_limit'
    for number in range(1, args.trials + 1):
        attempts = number
        folder = out / f'trial_{number:03d}'
        folder.mkdir()
        prompt = ('Optimize the fixed RV32I core PPA. Return one NEW parameter set as a single JSON object, '
                  'exactly the four keys below; PLACE_DENSITY must be a decimal float, others integers. '
                  'Minimize score and avoid negative WNS. Do not repeat a proposed set.\nSearch space:\n' +
                  search_space_as_json() + '\nResults and rejected attempts so far:\n' +
                  json.dumps(history, indent=2) + '\nScore = area/baseline area + power/baseline power '
                  '+ 1000*max(0,-WNS_ps)/1000_ps. Timing and RTL are fixed.')
        record = {'prompt': prompt, 'raw_response': None, 'parameters': None, 'metrics': None,
                  'score': None, 'status': 'rejected', 'provider': args.provider, 'model': args.model,
                  'generation_settings': {'stream': False, 'temperature': 'provider default'}}
        write_text(folder / 'prompt.txt', prompt + '\n')
        try:
            print(f'[trial_{number:03d}] Requesting proposal from {args.provider} ({args.model})...', flush=True)
            raw, usage, actual_model = ask_tamu(args.model, prompt)
            print(f'[trial_{number:03d}] Response received; validating proposal...', flush=True)
            record.update(raw_response=raw, usage=usage, actual_model=actual_model)
            write_text(folder / 'response.txt', str(raw) + '\n')
            proposed = first_object(raw)
            record['parameters'] = proposed
            if not valid_params(proposed):
                raise ValueError('Invalid parameters, keys or Python types')
            signature = tuple(proposed[k] for k in sorted(param_space))
            if signature in seen:
                raise ValueError('Duplicate parameter set')
            seen.add(signature)
            print(f'[trial_{number:03d}] Proposal accepted: {json.dumps(proposed, sort_keys=True)}', flush=True)
            outcome = evaluate(proposed, folder, f'a4_{run_id}_{number:03d}')
            record.update(outcome)
            if outcome['status'] == 'success':
                record['score'] = score(outcome['metrics'], baseline['metrics'])
                if record['score'] < best['score']:
                    best = record
                    unsuccessful = -1
        except (ValueError, RuntimeError, TypeError) as exc:
            record['reason'] = str(exc)
            if isinstance(exc, RuntimeError):
                record['status'] = 'llm_error'
        write_json(folder / 'result.json', record)
        history.append({key: record.get(key) for key in
                        ('parameters', 'status', 'metrics', 'score', 'reason')})
        unsuccessful += 1
        print(f"Attempt {number}: {record['status']} score={record['score']} {record.get('reason', '')}", flush=True)
        if len(seen) == math.prod(len(v) for v in param_space.values()):
            stop = 'search_space_exhausted'
            break
        if unsuccessful >= 3:
            stop = 'three_consecutive_attempts_without_improvement'
            break
    summary = {'baseline': baseline, 'best': best, 'best_parameters': best['parameters'],
               'attempt_count': attempts, 'stopping_reason': stop, 'provider': args.provider,
               'model': args.model, 'generation_settings': {'stream': False, 'temperature': 'provider default'},
               'score_formula': 'area/baseline_area + power/baseline_power + 1000*max(0,-wns_ps)/clock_period_ps',
               'clock_period_ps': CLOCK_PERIOD_PS, 'io_delay_ps': IO_DELAY_PS}
    write_json(out / 'summary.json', summary)
    print('Stop:', stop, 'best score:', best['score'], flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
