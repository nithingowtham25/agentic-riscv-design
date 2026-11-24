"""Register this project's markdown roles; telemetry does not import this file."""

import json
from pathlib import Path

roles = {}
for path in sorted(Path("sub_agents").glob("*.md")):
    prompt = path.read_text().strip()
    if not prompt:
        continue  # A6 has empty placeholders; supply your working role instructions.
    name = path.stem.lower().removesuffix("_agent")
    if name in roles:
        raise ValueError("Duplicate role name: " + name)
    roles[name] = {
        "description": f"Project role {name}: see {path}",
        "prompt": prompt,
        "model": "inherit",
    }
print(json.dumps(roles))
