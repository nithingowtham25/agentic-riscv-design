"""Physical-design guidance, measured feedback, and ORFS image collection."""
from __future__ import annotations

import json
import math
from pathlib import Path
import shutil
from config import CLOCK_PERIOD_PS, IO_DELAY_PS

SYSTEM_PROMPT = """You are a physical-design optimization assistant for a fixed five-stage RV32I core using ASAP7 and ORFS. Propose exactly one previously untried configuration. The RTL, clock period, I/O delays, platform, and scoring formula are fixed. Never suggest changing them.

The four legal knobs and general tradeoffs are:
1. ABC_AREA: 0 favors delay-oriented synthesis and 1 favors area-oriented synthesis. Either can affect cell area, power and timing; outcomes depend on synthesis and implementation.
2. CORE_UTILIZATION: 40, 55 or 70 percent. Higher utilization generally reduces floorplan space for a fixed cell area but may increase routing pressure; lower utilization generally provides more space at the cost of a larger core. Floorplan area and measured standard-cell area are different quantities.
3. PLACE_DENSITY: 0.60, 0.70 or 0.80. Higher target density may lead to tighter placement but can increase congestion; lower density may reduce local pressure but can alter wirelength and timing. The effective density is subject to the tool flow and floorplan interactions.
4. GPL_TIMING_DRIVEN: 0 disables and 1 enables timing-driven global placement. Enabling it can prioritize critical timing paths but may affect routing, buffering, area and power; disabling it can change these tradeoffs in either direction.
These are general tendencies, not promises. Use only the allowed values and exact types in the user prompt.

Consider the baseline, latest and best measured runs, score, positive or negative setup slack, TNS, power, area and available diagnostics. Favor timing closure, then optimize the provided score. Compare changes and note possible interactions; values marked unavailable must not be guessed. Avoid duplicates, including failed tool runs. Never claim that an unmeasured result is known. A failed run is not evidence of its PPA. Diagnostics are estimates, not signoff and not necessarily comparable across stages.

Use this evidence-guided proposal policy, rather than broad or random exploration:
1. Treat the best measured configuration as the incumbent. Preserve a value that has directly helped the incumbent unless there is a stated hypothesis for changing it.
2. Read the supplied single-parameter comparisons first. When a comparison changes only one knob and improves score while maintaining non-negative WNS, carry that direction forward to the next adjacent legal value if one is available.
3. The general knob tradeoffs above are priors for values that have not yet been measured. Use them to choose the most consequential remaining experiment; they are not measured facts about this core.
4. Normally change one parameter from the incumbent. You may change two parameters together only for an explicit coupled physical-design hypothesis (for example, utilization and density as a congestion-versus-area tradeoff). Do not change unrelated knobs together.
5. Do not revisit a known poor setting merely for exploration. If the data are inconclusive, prefer an untried adjacent value over a distant, arbitrary combination.
6. In the rationale, name every changed knob, whether the choice follows measured evidence or a general prior, and the expected score/timing tradeoff. The JSON still must contain only the four required knobs.

Respond first with one JSON object containing exactly ABC_AREA, CORE_UTILIZATION, PLACE_DENSITY and GPL_TIMING_DRIVEN. PLACE_DENSITY must be a decimal float (e.g. 0.80); other values must be integers. After that object, add a short 'Rationale:' paragraph explaining which knobs changed relative to the best measured configuration, evidence for the hypothesis, expected tradeoffs and uncertainty. Do not put rationale inside the JSON object or return another JSON object."""

FIELDS = {
    'core_area_um2': 'finish__design__core__area',
    'die_area_um2': 'finish__design__die__area',
    'stdcell_count': 'finish__design__instance__count__stdcell',
    'sequential_cell_area_um2': 'finish__design__instance__area__class__sequential_cell',
    'combinational_cell_area_um2': 'finish__design__instance__area__class__multi_input_combinational_cell',
    'timing_repair_buffer_count': 'finish__design__instance__count__class__timing_repair_buffer',
    'internal_power_w': 'finish__power__internal__total',
    'switching_power_w': 'finish__power__switching__total',
    'leakage_power_w': 'finish__power__leakage__total',
    'setup_violation_count': 'finish__timing__drv__setup_violation_count',
    'hold_worst_slack_ps': 'finish__timing__hold__ws',
    'hold_tns_ps': 'finish__timing__hold__tns',
    'hold_violation_count': 'finish__timing__drv__hold_violation_count',
    'route_drc_errors': 'detailedroute__route__drc_errors',
    'global_route_congestion_rsmt_s': 'globalroute__global_route__fastroute__congestion_rsmt_s',
    'finish_warning_count': 'finish__flow__warnings__count',
}


def diagnostics(path):
    raw = json.loads(Path(path).read_text(encoding='utf-8'))
    result = {}
    for label, key in FIELDS.items():
        value = raw.get(key)
        if isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value):
            result[label] = value
        else:
            result[label] = None
    return result


def changes(metrics, reference):
    if not metrics or not reference:
        return None
    out = {}
    for key in ('area_um2', 'power_w', 'wns_ps', 'tns_ps'):
        x, y = metrics.get(key), reference.get(key)
        if x is None or y is None:
            out[key] = None
        else:
            out[key] = {'absolute': x-y, 'percent': (100*(x-y)/abs(y) if y else None)}
    return out


def parameter_effect_cards(best, history, space):
    """Summarize what has actually been sampled without inferring causality."""
    cards = {}
    for knob, legal_values in space.items():
        evaluated = []
        for entry in history:
            params = entry.get('parameters')
            if isinstance(params, dict) and knob in params and params[knob] not in evaluated:
                evaluated.append(params[knob])
        cards[knob] = {
            'incumbent_value': best['parameters'][knob],
            'legal_values': list(legal_values),
            'evaluated_values': evaluated,
            'untried_values': [value for value in legal_values if value not in evaluated],
            'guidance': (
                'Keep the incumbent unless a direct comparison or an explicit, coupled '
                'physical-design hypothesis supports changing it. A value appearing in an '
                'evaluated run is not by itself evidence that the value caused that run outcome.'),
        }
    return cards


def make_brief(baseline, best, history, attempt, limit, space):
    compact = []
    for entry in history:
        compact.append({k: entry.get(k) for k in ('parameters', 'status', 'metrics', 'score', 'reason', 'diagnostics')})
    attempted = [x['parameters'] for x in compact if isinstance(x.get('parameters'), dict)]
    latest = history[-1]
    pairs = []
    for i, left in enumerate(compact):
        if left['status'] != 'success' or not isinstance(left['parameters'], dict):
            continue
        for j in range(i + 1, len(compact)):
            right = compact[j]
            if right['status'] != 'success' or not isinstance(right['parameters'], dict):
                continue
            different = [k for k in space if left['parameters'].get(k) != right['parameters'].get(k)]
            if len(different) == 1:
                pairs.append({'earlier_history_index': i, 'later_history_index': j,
                              'changed_parameter': different[0],
                              'earlier_value': left['parameters'][different[0]],
                              'later_value': right['parameters'][different[0]],
                              'measured_later_minus_earlier': changes(right['metrics'], left['metrics']),
                              'score_difference': right['score']-left['score']})
    data = {'attempt': attempt, 'proposal_limit': limit, 'remaining_including_this': limit-attempt+1,
            'search_space': space, 'baseline': compact[0],
            'best': {k: best.get(k) for k in ('parameters','metrics','score','diagnostics')},
            'latest_attempt': compact[-1], 'latest_vs_baseline': changes(latest.get('metrics'),baseline['metrics']),
            'latest_vs_best': changes(latest.get('metrics'),best['metrics']),
            'attempted_parameters': attempted, 'history': compact,
            'score_formula': 'area / baseline_area + power / baseline_power + 1000 * max(0, -setup_worst_slack_ps) / clock_period_ps',
            'clock_period_ps': CLOCK_PERIOD_PS, 'io_delay_ps': IO_DELAY_PS,
            'units': {'area_um2': 'um^2', 'power_w': 'W', 'wns_ps': 'ps', 'tns_ps': 'ps'},
            'single_parameter_comparisons': pairs,
            'parameter_effect_cards': parameter_effect_cards(best, history, space),
            'next_proposal_policy': [
                'Start from the best measured configuration, not from an arbitrary point.',
                'Prefer a one-knob adjacent experiment supported by a measured single-parameter comparison.',
                'For unmeasured settings, use the documented knob tradeoffs as a hypothesis and say so.',
                'Change two knobs only when they form one stated physical-design tradeoff; otherwise retain the incumbent values.',
                'Every changed knob must be justified in the rationale using a measurement or a stated general prior.'
            ],
            'diagnostic_note': 'Null means unavailable. Congestion rsmt_s is a raw ORFS metric, not a percentage. Power is estimated. History index 0 is baseline; later indices are proposal attempts. Single-parameter comparisons are observations, not general causal proof.'}
    return ('Review the following measured evidence and propose one new setting. '
            'Do not invent results. Follow the response format in the system instructions.\n' +
            json.dumps(data, indent=2, sort_keys=True, allow_nan=False))


def collect_physical_images(reports_dir, directory, final_log):
    """Copy ORFS-rendered images; a file alone does not prove populated heatmaps."""
    reports_dir, directory = Path(reports_dir), Path(directory)
    figures = directory / 'figures'
    expected = ('final_all.webp', 'final_placement.webp', 'final_routing.webp',
                'final_congestion.webp', 'final_worst_path.webp', 'final_clocks.webp',
                'final_ir_drop.webp', 'final_resizer.webp')
    result = {'source': 'ORFS final report images', 'files': {}, 'warnings': []}
    log = Path(final_log)
    if log.is_file():
        result['warnings'] = [line.strip() for line in log.read_text(encoding='utf-8', errors='replace').splitlines()
                              if 'Heat map' in line and 'not been populated' in line]
    for name in expected:
        src = reports_dir / name
        if not src.is_file() or src.stat().st_size == 0:
            result['files'][name] = {'status': 'unavailable'}
            continue
        try:
            figures.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, figures / name)
            unpopulated = ((name == 'final_congestion.webp' and any('Routing Congestion' in w for w in result['warnings'])) or
                           (name == 'final_ir_drop.webp' and any('IR Drop' in w for w in result['warnings'])))
            result['files'][name] = {'status': 'heatmap_unpopulated' if unpopulated else 'copied',
                                     'path': 'figures/' + name}
        except OSError as exc:
            result['files'][name] = {'status': 'copy_failed', 'reason': str(exc)}
    return result
