# Task 3 – Processor Generation, Integration, and Seeded-Bug Repair Analysis

## 1. Objective

The objective of Task 3 was to use the debugging agent developed in Task 2 to generate and integrate a complete single-cycle RV32I processor. Three new processor modules—`pc_unit`, `branch_unit`, and `memory_access`—were generated independently using the `rag_feedback` arm, followed by generation of the `datapath` module after integrating the four Assignment 1 modules: `alu`, `regfile`, `extend`, and `controller`.

The resulting eight-module processor was then tested using the provided integration programs. Finally, four intentionally corrupted RTL modules were supplied to the same RAG + iterative feedback agent to evaluate whether the agent could identify and repair functional bugs from simulation feedback.

The Task 3 workflow therefore evaluates two capabilities of the agent:

1. **Generation and integration:** whether RAG-assisted generation can produce modules that satisfy their individual specifications and work together as a processor.
2. **Iterative debugging:** whether the agent can use simulation failures and retrieved hardware-design knowledge to repair seeded RTL automatically.

---

## 2. Generation of the New Processor Modules

The three independent modules were generated using the `rag_feedback` arm with the TAMU provider and `gpt-5.4` model.

### Clean-generation results

| Module | Initial Status | Tests Passed | Final Status | Repair Needed |
|---|---|---:|---|---|
| `pc_unit` | PASS | 30/30 | PASS | No |
| `branch_unit` | PASS | 40/40 | PASS | No |
| `memory_access` | PASS | 44/44 | PASS | No |
| `datapath` | PASS | Integration test passed | PASS | No |

The `pc_unit` generation passed all 30 tests on its first iteration with return code 0.

The generated `branch_unit` also passed all 40 tests on its initial candidate, demonstrating that the generated branch comparison logic and `PCSrc` behavior satisfied the provided testbench.

The `memory_access` module achieved **44/44 passing tests** on its first iteration. The tool output contained several Icarus messages such as `constant selects in always_* processes are not fully supported`, but these did not cause the test to fail because the tool returned status `pass` with return code 0.

The `datapath` was subsequently generated using RAG context containing the required module interfaces and processor integration rules. Its JSON record reports a final `pass` status.

### Observation

All four newly generated modules passed without requiring a repair iteration. This indicates that the RAG context was useful not only for debugging existing RTL, but also for generating RTL that was initially compatible with the supplied specifications and testbenches.

The retrieval records also show that the agent received project-specific information rather than relying only on generic Verilog knowledge. For example, the `datapath` generation retrieved information about exact module interfaces, ALU operand selection, memory access, writeback behavior, and processor-level integration.

---

## 3. RAG Retrieval Analysis

Each module generated using `rag_feedback` retrieved five chunks from the knowledge base. The retrieved information was generally closely related to the functionality of the module being generated.

### `pc_unit`

The retrieved chunks included:

- `module_interfaces.md`
- `memory_addressing.md`
- `controller_pcsrc.md`
- `datapath_integration.md`
- `blocking_nonblocking.md`

The `datapath_integration.md` information was particularly relevant because it specifies the required `PC + 4` behavior and the selection between sequential execution and control-flow targets.

### `branch_unit`

The retrieval included:

- `controller_pcsrc.md`
- `module_interfaces.md`
- `immediate_encoding.md`
- `alu_spec.md`
- `operator_precedence.md`

The `controller_pcsrc.md` chunk is particularly relevant because it describes the relationship between branch conditions, comparison results, and `PCSrc`.

### `memory_access`

The retrieved context included:

- `memory_addressing.md`
- `immediate_encoding.md`
- `load_store_encoding.md`
- `module_interfaces.md`

The `load_store_encoding.md` knowledge is particularly relevant to signed and unsigned load behavior and the different `funct3` encodings.

### `datapath`

The datapath retrieved project-specific integration information, including:

- exact interfaces of the seven required modules,
- datapath wiring,
- memory-addressing behavior,
- register-file `x0` behavior.

The retrieval included `module_interfaces.md`, `datapath_integration.md`, `memory_addressing.md`, and `register_x0_hardwired.md`.

### Overall RAG observation

The retrieved chunks were strongly aligned with the functionality being implemented. In particular, the retrieval system repeatedly surfaced **project-specific integration rules** instead of only generic Verilog information.

This is important for the processor-level task because many failures can arise from incorrect port names, control encodings, operand selection, or inter-module connections even when individual RTL blocks are syntactically valid.

---

## 4. Processor Integration

After generating the three new modules, the four Assignment 1 modules were integrated:

```text
alu
regfile
extend
controller
```

The final processor therefore consisted of the required eight modules:

```text
alu
regfile
extend
controller
pc_unit
branch_unit
memory_access
datapath
```

The eight RTL files supplied for the backup contain the expected module definitions.

The complete processor was then tested using:

```bash
bash scripts/run_all_sample.sh
```

The integration test produced a **PASS result** in the terminal.

This is significant because the individual module tests alone do not establish that the modules are correctly connected. The integration test exercises the processor as a complete system and provides evidence that the generated `datapath` correctly interfaces with the Assignment 1 modules and the three new Assignment 2 modules.

The datapath specification requires the seven component modules to be instantiated with their expected interfaces and defines the connections for ALU operands, memory access, writeback, and PC/branch behavior.

### Integration observation

No unresolved integration failure remained before proceeding to the seeded-bug experiments. The final eight-module RTL therefore represented a functioning integrated processor rather than merely a collection of independently passing modules.

---

# 5. Seeded-Bug Repair Experiment

The second major part of Task 3 evaluated the debugging capability of the agent.

Each of the four deliberately broken modules was supplied through `--seed-rtl`:

```text
pc_unit_buggy.sv
branch_unit_buggy.sv
memory_access_buggy.sv
datapath_buggy.sv
```

The assignment requires these runs to start at `sim_fail` and eventually reach `pass`.

### Seeded repair results

| Module | Initial Result | Initial Tests | Repair Iterations | Final Result |
|---|---|---:|---:|---|
| `pc_unit` | `sim_fail` | 0/30 | 1 | `pass` — 30/30 |
| `branch_unit` | `sim_fail` | 26/40 | 1 | `pass` — 40/40 |
| `memory_access` | `sim_fail` | 38/44 | 1 | `pass` — 44/44 |
| `datapath` | `sim_fail` | Functional failure | 1 | `pass` |

All four seeded bugs were repaired in exactly **one repair iteration**.

---

## 6. Analysis of Individual Seeded Bugs

### 6.1 `pc_unit`

The seeded `pc_unit` failed all 30 tests initially.

The simulation output showed that the faulty implementation was incrementing the program counter by **2 instead of 4**. This caused the expected `PCPlus4` values and subsequent PC values to be incorrect.

Initial result:

```text
Passed: 0 Failed: 30 Total: 30
```

After one repair iteration:

```text
Passed: 30 Failed: 0 Total: 30
```

The retrieved `datapath_integration.md` chunk specifically describes the required:

```text
pc_plus4 = pc + 4
```

behavior.

### Analysis

The agent was able to use the simulation feedback together with the retrieved processor integration information to identify and correct the incorrect PC increment in a single repair iteration.

This demonstrates how the feedback loop can convert a functional simulation failure into a targeted RTL correction.

---

### 6.2 `branch_unit`

The seeded `branch_unit` initially passed:

```text
26/40
```

but failed 14 tests.

The failures occurred across several branch-condition cases. The repair retrieved project-specific branch/control information, including `controller_pcsrc.md`, which describes the relationship between branch conditions, comparison results, and `PCSrc`.

After one repair iteration:

```text
Passed: 40 Failed: 0 Total: 40
```

### Analysis

Unlike `pc_unit`, the seeded `branch_unit` was already partially functional, passing 65% of the tests initially. The remaining failures were therefore associated with specific branch-condition behavior.

The retrieved branch/control information provided the agent with project-specific information needed to correct the faulty behavior rather than requiring a complete regeneration of the module.

---

### 6.3 `memory_access`

The seeded `memory_access` implementation initially passed:

```text
38/44
```

and failed six tests.

The failures were associated with load-data behavior, including incorrect sign or zero extension. For example, the simulation showed cases where values such as:

```text
Expected: ffffffff
Actual:   000000ff
```

and:

```text
Expected: ffffff80
Actual:   00000080
```

were produced.

After one repair iteration:

```text
Passed: 44 Failed: 0 Total: 44
```

The retrieved knowledge included `load_store_encoding.md`, which provides the signed and unsigned load encodings and their required behavior.

### Analysis

This is a clear example of the interaction between simulation feedback and RAG knowledge.

The simulation output identifies the numerical mismatch, while the retrieved load/store information provides the architectural interpretation needed to distinguish sign extension from zero extension.

The agent was therefore able to correct the load behavior in a single iteration.

---

### 6.4 `datapath`

The seeded `datapath` initially produced a `sim_fail` result and reached `pass` after one repair iteration.

The repair retrieved information from:

- `module_interfaces.md`
- `datapath_integration.md`
- `memory_addressing.md`
- `register_x0_hardwired.md`

These sources are directly relevant to debugging a top-level integration module because the datapath depends on correct connections between multiple processor components.

The initial output also contained several Icarus messages such as:

```text
sorry: constant selects in always_* processes are not fully supported
```

These messages also appeared during successful runs, demonstrating that they were tool warnings rather than the functional cause of the failure.

### Analysis

The datapath repair is particularly significant because it is the highest-level module in this task. A datapath failure can result from incorrect module connectivity, mux selection, memory control, register-file connections, or control-signal propagation.

The fact that the seeded datapath reached `pass` after one feedback iteration demonstrates that the retrieved integration information was sufficient to guide a successful repair.

---

# 7. Repair Efficiency

The seeded repair experiment can be summarized quantitatively:

| Metric | Result |
|---|---:|
| Seeded modules tested | 4 |
| Modules initially passing | 0 |
| Modules eventually passing | 4 |
| Successful repair rate | 4/4 = 100% |
| Average repair iterations | 1 |
| Maximum repair iterations | 1 |
| Modules requiring >1 repair | 0 |

The debugging loop therefore achieved a **100% successful repair rate across the four seeded bugs**, with every successful repair occurring on the first repair attempt.

The fixed debugging policy allows up to five repair iterations after the initial candidate and stops immediately when a passing candidate is obtained. None of the four seeded experiments required the full repair budget.

---

# 8. Overall Analysis

The Task 3 results demonstrate that the debugging agent developed in Task 2 can be extended from isolated RTL debugging to the generation, integration, and repair of a multi-module processor.

All three newly generated modules passed their independent testbenches on the initial generation, and the generated `datapath` subsequently passed the integration testing. The final processor consisted of the required eight RTL modules, and the complete integration sample suite produced a PASS result.

The RAG retrieval results show that the agent consistently retrieved project-specific information related to module interfaces, control behavior, memory operations, and datapath connectivity. This was particularly important for the `datapath`, where correct integration depends on matching the exact interfaces and control signals of the seven component modules.

The seeded-bug experiments provide additional evidence for the iterative feedback mechanism. All four deliberately broken modules initially produced `sim_fail`, but each reached `pass` after exactly one repair iteration. The seeded faults covered different categories:

- incorrect PC increment in `pc_unit`,
- branch-condition behavior in `branch_unit`,
- signed/unsigned load behavior in `memory_access`,
- processor-level integration behavior in `datapath`.

The results therefore show that the combination of **RAG retrieval, simulation feedback, and iterative RTL repair** was able to successfully address both individual functional errors and higher-level processor integration errors within the Task 3 workflow.