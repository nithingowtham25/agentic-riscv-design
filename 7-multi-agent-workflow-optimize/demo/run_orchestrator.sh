#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# Student-owned invocation. Change roles, tools, model and orchestration here.
args=(--agents "$(python3 register_agents.py)")
claude -p "Read AGENTS.md and execute the project workflow. Use registered subagents when the workflow calls for them." \
    --model "${AGENT_MODEL:-haiku}" \
    --tools Agent,Read,Write,Edit,Bash --allowedTools Agent Read Write Edit Bash \
    --permission-mode dontAsk "${args[@]}"
