#!/usr/bin/env bash
# Source this script before running the Assignment 6 orchestration workflow.
# Usage: source scripts/activate_olympus_env.sh

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Use: source scripts/activate_olympus_env.sh" >&2
    exit 1
fi

# Caller may override this location after extracting the project on another account.
export A6_TOOLS_DIR="${A6_TOOLS_DIR:-/home/grads/n/nithingowtham25/Fall_2026/ecen-689-agentic_hw_dsgn/.tools/a6}"

if [[ ! -f "$A6_TOOLS_DIR/miniforge3/etc/profile.d/conda.sh" ]]; then
    echo "ERROR: Miniforge was not found under $A6_TOOLS_DIR." >&2
    return 1
fi

if [[ ! -x "$A6_TOOLS_DIR/a6_icarus/bin/iverilog" ]]; then
    echo "ERROR: Icarus Verilog was not found under $A6_TOOLS_DIR/a6_icarus." >&2
    return 1
fi

source "$A6_TOOLS_DIR/miniforge3/etc/profile.d/conda.sh"
export PATH="$A6_TOOLS_DIR/miniforge3/bin:$A6_TOOLS_DIR/a6_icarus/bin:$PATH"

if [[ -x "$HOME/.local/bin/claude" ]]; then
    export PATH="$HOME/.local/bin:$PATH"
else
    echo "WARNING: Claude Code was not found at $HOME/.local/bin/claude." >&2
    return 1
fi

# TAMU AI gateway settings. The token is intentionally never stored in this file.
unset ANTHROPIC_API_KEY
export ANTHROPIC_BASE_URL="https://chat-api.tamu.ai/api"
export ANTHROPIC_DEFAULT_SONNET_MODEL="protected.Claude Sonnet 4.6"
export ANTHROPIC_MODEL="sonnet"

if [[ -z "${ANTHROPIC_AUTH_TOKEN:-}" ]]; then
    read -rsp "Enter TAMU API key: " ANTHROPIC_AUTH_TOKEN
    echo
    export ANTHROPIC_AUTH_TOKEN
fi

echo "Assignment 6 Olympus environment ready: $(iverilog -V 2>&1 | head -1)"
echo "Python runtime: $(python3 --version)"
echo "Claude Code ready through the TAMU gateway: $(claude --version | head -1)"
