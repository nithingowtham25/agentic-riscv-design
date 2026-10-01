# ECEN 689 — Assignment 2: Debugging Agent (RAG + Iterative Tool Feedback)

In Assignment 2 you build a **Debugging Agent**: an LLM-driven workflow that integrates a single-cycle RV32I processor and then *debugs it automatically* using Icarus Verilog feedback and retrieved knowledge (RAG). This builds on Assignment 1 and you reuse your own Assignment 1 modules.

See the **Course Setup Guide** for the one-time environment/API setup, then run the preflight from the package root:

```bash
bash check_setup.sh
```

The full assignment instructions are in **Assignment_2_Fall2026** (the handout). This file (`README_A2.md`) is the provided guide to the package.

---


## Package contents

- `README_A2.md`: this guide (provided). Your submission adds your own `README.md`.
- `specs/`: specifications for the four new modules
- `rtl/`: where your generated + Assignment 1 modules live (`README_A1_MODULES.md` explains the carry-forward)
- `scripts/`: per-module run scripts + `run_all_sample.sh` integration runner + `install_icarus.sh`
- `testbench/`, `vectors/`, `programs/sample/`: the sample test infrastructure
- `agent/`: the Debugging Agent (`iterative_rtl_agent.py`, `tool_feedback.py`, `run_debug_agent.py`, `llm_clients.py`, `io_utils.py`)
- `rag/`: the RAG index builder + query interface
- `rag_dataset/`: the RV32I knowledge base (specs, encodings, common bugs, Icarus messages)
- `bugs/`: four deliberately-broken modules (pc_unit, branch_unit, memory_access, datapath) for the seeded repair exercise (Task 3)
- `check_setup.sh`: preflight setup checker


Note: The **Assignment_2_Fall2026** handout asks you to submit your own README.md. Refer to the **Deliverables** section of the handout for more details. Create your README.md separately and do not overwrite this README_A2.md file.