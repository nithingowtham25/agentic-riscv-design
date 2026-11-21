"""Student TODO: selecting and formatting VeriThoughts examples.

Keep this file in your submission. The preparation driver loads the dataset,
checks the finished records, and writes the JSONL and selection manifest.

You implement the policy used to choose records and build target responses.
"""

import random
import re

from common import model_prompt


def make_completion(row, response_format):
    """Return the target response for one VeriThoughts record.

    Available fields include 'question', 'reasoning_trace', 'generated_verilog'
    (and possibly 'verified'). Decide how to handle missing fields.

    Suggested formats:
      reasoned:        <think>...reasoning...</think> then <verilog>...RTL...</verilog>
      verilog-tagged:  <verilog>...RTL...</verilog>
      verilog-plain:   ...RTL...

    You may implement another consistent format if you document it and the
    evaluation extractor can retrieve the generated Verilog without repair.
    """
    source = row["generated_verilog"].strip()
    modules = list(re.finditer(r"(?mi)^\s*module\s+[A-Za-z_]\w*", source))
    endings = list(re.finditer(r"(?mi)(?:^\s*|;\s*)endmodule\b", source))
    if len(modules) != 1 or len(endings) != 1 or endings[0].start() < modules[0].start():
        raise ValueError("Expected exactly one complete Verilog module")
    # Remove source prose, Markdown fences, and wrapper tags. The score-oriented
    # target is only the complete module, never an explanation before it.
    verilog = source[modules[0].start():endings[0].end()].strip()
    if response_format == "reasoned":
        reasoning = row["reasoning_trace"].strip()
        return f"<think>\n{reasoning}\n</think>\n<verilog>\n{verilog}\n</verilog>"
    if response_format == "verilog-tagged":
        return f"<verilog>\n{verilog}\n</verilog>"
    if response_format == "verilog-plain":
        return verilog
    raise ValueError(f"Unsupported response format: {response_format}")


def count_training_tokens(tokenizer, question, completion):
    """Measure *all* tokens that SFTTrainer will see, not just the answer."""
    full_text = model_prompt(tokenizer, question) + completion + tokenizer.eos_token
    return len(tokenizer(full_text, add_special_tokens=False)["input_ids"])


def select_training_examples(dataset, tokenizer, *, count, max_tokens, seed,
                             response_format, verified_only, benchmark_prompts):
    """Select and return (training_records, selection_notes).

    training_records: list of {'prompt': str, 'completion': str}; exactly count rows.
    selection_notes: JSON-serializable dict describing the method and rejections.

    Requirements:
      - Select at least the requested number of usable source records.
      - Base the prompt on VeriThoughts 'question'.
      - Explain and implement a sampling policy (e.g., seeded shuffle, verified
        subset, reasoning/length filters, or another justified policy).
      - Filter empty/malformed records, exact duplicate prompts, and exact
        normalized matches in benchmark_prompts. These checks are not proof
        against conceptual overlap; discuss limitations in your report.
      - Never silently cut off Verilog to satisfy max_tokens. Skip or otherwise
        handle long records with a stated policy.
      - Count tokens for the combined *formatted input + expected output + EOS*.

    Hints: random.Random(seed).shuffle(indices); use make_completion(...);
           count_training_tokens(tokenizer, question, completion).
    """
    if response_format not in {"reasoned", "verilog-tagged", "verilog-plain"}:
        raise ValueError(f"Unsupported response format: {response_format}")

    def normalized(text):
        return re.sub(r"\s+", " ", text).strip().casefold()

    def nonempty_string(value):
        return isinstance(value, str) and bool(value.strip())

    def is_verified(row):
        value = row.get("verified")
        return value is True or (isinstance(value, str)
                                 and value.strip().casefold() in {"true", "1", "yes"})

    rejection_counts = {
        "invalid_question": 0,
        "missing_reasoning": 0,
        "missing_verilog": 0,
        "unusable_verilog": 0,
        "duplicate_prompt": 0,
        "benchmark_prompt_overlap": 0,
        "not_verified": 0,
        "over_token_limit": 0,
    }
    indices = list(range(len(dataset)))
    random.Random(seed).shuffle(indices)
    # Keep the shuffled order within each group, but prefer verified examples.
    # Eligible unverified examples are a deterministic fallback if needed.
    indices = ([i for i in indices if is_verified(dataset[i])] +
               [i for i in indices if not is_verified(dataset[i])])
    selected, seen_prompts = [], set()
    selected_verified = 0
    scanned = 0

    for index in indices:
        if len(selected) == count:
            break
        scanned += 1
        row = dataset[index]
        question = row.get("question")
        if not nonempty_string(question):
            rejection_counts["invalid_question"] += 1
            continue
        prompt_key = normalized(question)
        if prompt_key in benchmark_prompts:
            rejection_counts["benchmark_prompt_overlap"] += 1
            continue
        if prompt_key in seen_prompts:
            rejection_counts["duplicate_prompt"] += 1
            continue
        if verified_only and not is_verified(row):
            rejection_counts["not_verified"] += 1
            continue
        if response_format == "reasoned" and not nonempty_string(row.get("reasoning_trace")):
            rejection_counts["missing_reasoning"] += 1
            continue
        if not nonempty_string(row.get("generated_verilog")):
            rejection_counts["missing_verilog"] += 1
            continue
        try:
            completion = make_completion(row, response_format)
        except (KeyError, ValueError):
            rejection_counts["unusable_verilog"] += 1
            continue
        token_count = count_training_tokens(tokenizer, question, completion)
        if token_count > max_tokens:
            rejection_counts["over_token_limit"] += 1
            continue

        seen_prompts.add(prompt_key)
        selected_verified += is_verified(row)
        selected.append({"prompt": question.strip(), "completion": completion})

    if len(selected) != count:
        raise ValueError(
            f"Only found {len(selected)} eligible records out of {len(dataset)}; "
            f"requested {count}. Rejections: {rejection_counts}"
        )

    selection_notes = {
        "sampling_policy": (
            "Seeded shuffle; select verified eligible rows first, then use "
            "eligible unverified rows only if needed."
        ),
        "seed": seed,
        "response_format": response_format,
        "verified_only": verified_only,
        "verified_examples_selected": selected_verified,
        "unverified_examples_selected": len(selected) - selected_verified,
        "max_tokens": max_tokens,
        "source_dataset_rows": len(dataset),
        "source_rows_scanned": scanned,
        "selected_count": len(selected),
        "rejection_counts": rejection_counts,
        "prompt_deduplication": "Normalized whitespace and case-folded exact question match.",
        "benchmark_overlap_check": (
            "Normalized exact question match against VerilogEval prompts; "
            "semantic overlap is not detected."
        ),
        "overlength_policy": "Skipped records over max_tokens; no Verilog was truncated.",
    }
    return selected, selection_notes
