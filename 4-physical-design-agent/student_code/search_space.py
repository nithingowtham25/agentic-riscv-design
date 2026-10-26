"""Provided discrete ORFS parameter search space."""

from __future__ import annotations

import json
from typing import Any


syn_param_space = {
    "ABC_AREA": [0, 1],
}

pnr_param_space = {
    "CORE_UTILIZATION": [40, 55, 70],
    "PLACE_DENSITY": [0.60, 0.70, 0.80],
    "GPL_TIMING_DRIVEN": [0, 1],
}

param_space = {**syn_param_space, **pnr_param_space}


BASELINE_PARAMS = {
    "ABC_AREA": 1,
    "CORE_UTILIZATION": 40,
    "PLACE_DENSITY": 0.80,
    "GPL_TIMING_DRIVEN": 1,
}


def valid_params(params: Any) -> bool:
    """Return True only for a complete, exact, legal flat parameter mapping."""
    if not isinstance(params, dict) or set(params) != set(param_space):
        return False
    return all(
        any(
            type(params[key]) is type(candidate) and params[key] == candidate
            for candidate in allowed
        )
        for key, allowed in param_space.items()
    )


def split_params(params: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    """Validate and split a complete mapping into synthesis and PnR mappings."""
    if not valid_params(params):
        raise ValueError("Parameter mapping is incomplete or contains illegal values")
    return (
        {key: params[key] for key in syn_param_space},
        {key: params[key] for key in pnr_param_space},
    )


def search_space_as_json() -> str:
    """Return the complete search space in a prompt-friendly representation."""
    return json.dumps(param_space, indent=2, sort_keys=True)
