"""Provided file, YAML, and LLM-output utilities for the lab."""

import re
from pathlib import Path

import yaml


def write_file(path, content):
    """Write UTF-8 text to `path`, creating parent directories if needed."""
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(content, encoding="utf-8")


def read_file(path):
    """Read UTF-8 text from `path`."""
    return Path(path).read_text(encoding="utf-8")


def strip_markdown_code_blocks(text):
    """Return HDL inside the last fenced block, or stripped input text."""
    matches = re.findall(
        r"```(?:verilog|systemverilog)?\n(.*?)```",
        text,
        flags=re.DOTALL | re.IGNORECASE,
    )
    return matches[-1].strip() if matches else text.strip()


def load_spec(spec_path):
    """Load a YAML spec and return `(top_module, content, full_spec)`."""
    spec = yaml.safe_load(read_file(spec_path))
    if not isinstance(spec, dict) or not spec:
        raise ValueError(f"Invalid spec file: {spec_path}")
    top_module, content = next(iter(spec.items()))
    return top_module, content, spec


def find_default_spec(workdir):
    """Fallback when --spec is not given: a spec.yaml here, or the only *.yaml in `workdir`.

    Normally you pass --spec specs/<module>.yaml (there are four module specs under specs/),
    so this is only a convenience for a directory containing a single YAML file.
    """
    workdir = Path(workdir)

    spec_yaml = workdir / "spec.yaml"
    if spec_yaml.exists():
        return spec_yaml

    yaml_files = sorted(workdir.glob("*.yaml"))
    if len(yaml_files) == 1:
        return yaml_files[0]
    if len(yaml_files) > 1:
        names = ", ".join(path.name for path in yaml_files)
        raise FileNotFoundError(
            f"Multiple YAML files found: {names}. Please pass --spec explicitly "
            f"(e.g. --spec specs/alu.yaml)."
        )
    raise FileNotFoundError("No YAML spec found. Pass --spec specs/<module>.yaml.")
