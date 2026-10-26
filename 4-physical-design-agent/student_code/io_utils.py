"""Small, provided file-I/O helpers for student workflows."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def read_text(path: str | Path) -> str:
    """Read a UTF-8 text file."""
    return Path(path).read_text(encoding="utf-8")


def write_text(path: str | Path, content: str) -> Path:
    """Write UTF-8 text, creating parent directories when necessary."""
    output_path = Path(path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(content, encoding="utf-8")
    return output_path


def write_json(path: str | Path, data: Any) -> Path:
    """Write JSON with stable, human-readable formatting."""
    return write_text(path, json.dumps(data, indent=2, sort_keys=True) + "\n")
