# Binary-decimal converter orchestrator

Repair and organize a tiny bidirectional integer converter inside workspace/ only.
All paths below are relative to workspace/. Required layout: src/converter.py,
scripts/organize.sh, scripts/run.sh, tests/test_converter.py, results/decimal.json,
results/binary.json. Use only standard-library Python and Bash.

The module exports decimal_to_binary(n) and binary_to_decimal(bits).
- decimal_to_binary accepts non-negative integers and returns binary digits without
  a 0b prefix; zero must return "0". Negative integers raise ValueError.
- binary_to_decimal accepts a nonempty string of only 0/1 digits, including leading
  zeros, and returns an integer. Invalid strings raise ValueError.
- CLI: exactly one of --decimal INTEGER or --binary BITS, plus required --out PATH.
  Write {"decimal": INTEGER, "binary": "DIGITS"} as JSON. Invalid input exits nonzero.
  For binary input preserve the supplied digits in the JSON.

Keep the supplied zero-conversion bug until the verifier demonstrates it.
1. Delegate organizer: write the Bash scripts and move inbox/converter.py to src/.
2. Delegate verifier: write and run tests; report the exact failing zero case.
3. Delegate builder: repair src/converter.py using the observed test failure.
4. Delegate verifier again: rerun tests without weakening assertions.
5. Delegate organizer again: run scripts/run.sh, converting decimal 10 to binary
   and binary 1010 to decimal, saving results/decimal.json and results/binary.json.

Use only the three registered workers: organizer, verifier, builder. Wait for each
result; never run workers in the background. Each worker must actually edit its
assigned files and use tools. The orchestrator delegates and summarizes; do not do
the workers' coding yourself. Keep messages brief; this is a small Haiku demo.
Do not install packages, access the network, read credentials, or modify files
outside workspace/. End with an honest summary of test and conversion results.

Read sub_agents/ for worker instructions. Execute tools/test.sh and tools/build.sh
from the project root to test and run the converter.
