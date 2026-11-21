"""Shared Code Llama prompt and Verilog extraction routines."""
import re
from pathlib import Path

BASE_MODEL = "codellama/CodeLlama-7b-Instruct-hf"
TASK = "spec-to-rtl"
BENCHMARK = "VerilogEval v2 Human spec-to-rtl"
MODEL_CONTEXT_TOKENS = 16_384
MIN_TRAIN_SAMPLES = 2_500
SYSTEM_PROMPT = (
    "You are a Verilog RTL designer. Produce a complete, syntactically correct "
    "Verilog module that implements the user's specification. "
    "The response can contain an explanation and/or Verilog code. "
    "If using <verilog> tags, place the complete module inside them. "
    "Use the module name and ports required by the specification."
)


def model_prompt(tokenizer, question):
    """Code Llama Instruct chat template, with an open assistant response."""
    return tokenizer.apply_chat_template(
        [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": question},
        ], tokenize=False, add_generation_prompt=True,
    )



def validate_sample_count(count):
    if count < MIN_TRAIN_SAMPLES:
        raise ValueError(f"At least {MIN_TRAIN_SAMPLES:,} training examples are required")


def validate_token_ceiling(limit):
    if not 1 <= limit <= MODEL_CONTEXT_TOKENS:
        raise ValueError(f"Token limit must be from 1 to {MODEL_CONTEXT_TOKENS:,}")


def extract_verilog(raw):
    """Extract a full module; do not repair model errors or change RTL semantics.

    VerilogEval v2 spec-to-RTL expects a complete TopModule. Empty output is a
    failed generation, not an automatically reconstructed correct answer.
    """
    match = re.search(r"<verilog>\s*(.*?)\s*</verilog>", raw, flags=re.S | re.I)
    if match:
        text = match.group(1)
    else:
        text = re.sub(r"<think>.*?</think>", "", raw, flags=re.S | re.I)
        match = re.search(r"\[BEGIN\](.*?)\[DONE\]", text, flags=re.S)
        if match:
            text = match.group(1)
        else:
            match = re.search(r"```(?:verilog|systemverilog|sv)?\s*\n(.*?)```", text, flags=re.S | re.I)
            if match:
                text = match.group(1)
    text = re.sub(r"</?verilog>", "", text, flags=re.I).strip()
    start = re.search(r"\bmodule\s+TopModule\b", text)
    if not start:
        return ""
    end = re.search(r"\bendmodule\b", text[start.start():])
    if not end:
        return text[start.start():].strip()  # incomplete module; tester will fail
    return text[start.start():start.start() + end.end()].strip() + "\n"


def benchmark_problems(dataset_dir):
    """Read the exact v2 problem list, not a glob of possibly extra files."""
    dataset_dir = Path(dataset_dir)
    ids_file = dataset_dir / "problems.txt"
    if not ids_file.is_file():
        raise FileNotFoundError(f"VerilogEval v2 spec-to-rtl list not found: {ids_file}")
    ids = [line.strip() for line in ids_file.read_text().splitlines()
           if line.strip() and not line.lstrip().startswith('#')]
    if len(ids) != 156 or len(set(ids)) != 156:
        raise ValueError(f"Expected 156 unique VerilogEval v2 Human problems; found {len(ids)}")
    problems = []
    for task_id in ids:
        path = dataset_dir / f"{task_id}_prompt.txt"
        if not path.is_file():
            raise FileNotFoundError(path)
        problems.append({"task_id": task_id, "prompt": path.read_text(encoding="utf-8")})
    return problems
