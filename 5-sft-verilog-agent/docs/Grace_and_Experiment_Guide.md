# Grace experiment guide - Assignment 5

Read `Course_Setup_Guide_A5.pdf` first. All commands below assume you are in
`A5_student/` on Grace. Never run inference, training or simulation on a login
node; use the Slurm batch scripts.

## Model and benchmark

Use the exact model `codellama/CodeLlama-7b-Instruct-hf`:
https://huggingface.co/codellama/CodeLlama-7b-Instruct-hf . The repository
currently appears ungated, unlike the official Meta mirror, but carries the
Meta Llama 2 license. The terms still apply even if downloading needs no
approval. A Hugging Face login may be unnecessary for this repository.

Use the upstream VerilogEval v2 Human `dataset_spec-to-rtl` directory, not v1
or the v2 code-completion benchmark. Record the cloned repository commit.
Both runs must use exactly the same 156 prompts, tokenizer prompt format,
model base weights, decoding, extraction and scoring. Only the LoRA adapter
changes.

## Dataset processing - student work

The finished `data/train.jsonl` must have **at least 2,500**
`{"prompt": ..., "completion": ...}` entries. In `student_code/data_methods.py`,
complete both `make_completion()` and `select_training_examples()`. The latter
must return `selected_rows, selection_notes`. `selection_notes` is saved to the
manifest so your seed, criteria and rejection counts are auditable.

Sampling may be random, quality-driven, verified-only, length-filtered, or
another defensible approach. Include checks for empty/malformed entries,
repeated questions and exact VerilogEval prompt overlap. The starter driver
checks final rows but does not choose them. Exact prompt checks cannot exclude
all semantic overlap; discuss this limit.

Reasoning followed by Verilog is recommended:

```text
<think>
...reasoning_trace...
</think>
<verilog>
...generated_verilog...
</verilog>
```

Verilog-only answers, tagged or plain, are permitted. Design a consistent
format, explain why you used it and inspect several completed examples.
**Code Llama has 16,384 context positions.** Count the entire formatted user
input + completion + end token, and use a smaller training maximum where
needed for memory. Filtering long reasoning is better than silently cutting
off the final RTL.

```bash
# After both data TODO functions are implemented:
sbatch --export=ALL,DATA_COUNT=2500,RESPONSE_FORMAT=reasoned,MAX_TOKENS=2048 slurm/cpu_prepare.sbatch
# After the CPU job finishes:
wc -l data/train.jsonl
cat data/selection_manifest.json
```

## Fine-tuning - student work

Fill every `None` in `student_code/student_config.py` (including warmup and
weight decay). In `train_sft.py`, implement `build_lora_config()` using
`peft.LoraConfig`; select suitable attention projection targets, rank, alpha,
and dropout. See the [PEFT LoRA reference](https://huggingface.co/docs/peft/en/conceptual_guides/lora)
and [TRL SFTTrainer docs](https://huggingface.co/docs/trl/en/sft_trainer).
The surrounding training script handles 4-bit loading, completion-only loss,
CSV/JSONL logs, metadata, and adapter saving.

```bash
# After completing code TODO and checking allocation:
sbatch slurm/gpu_train.sbatch
# After completion:
head output/sft_run/training_log.csv
cat output/sft_run/run_metadata.json
ls output/sft_run/adapter
```

## Budget: reserve the final benchmark before training

1. On Grace, use `myproject -l` to inspect your account allocation. Use
   `maxconfig -h` and HPRC AMS for job-cost calculations. HPRC lists **72
   additional SUs per Grace A100-hour** and **128 per FASTER A100-hour**,
   with CPU charges on top; check current rates.
2. Finish the full baseline evaluation first. Record the actual elapsed job
   time using `seff <JOB_ID>` or `sacct -j <JOB_ID> --format=JobID,Elapsed,State,AllocTRES`.
3. Estimate the cost of the *second* 156-problem GPU generation job from
   that runtime, using the same GPU/decoding settings. Allow headroom for
   longer trained responses or one rerun; include CPU scoring and remaining
   setup tasks. Do not spend these reserved SUs on extra training epochs.
4. State your cost estimate, training plan and remaining evaluation reserve
   in the report. Do not claim exact SU charges based only on time; use the
   local estimator and your project's accounting details.

See [HPRC AMS](https://hprc.tamu.edu/kb/User-Guides/AMS/) and
[Grace Batch](https://hprc.tamu.edu/kb/User-Guides/Grace/Batch/).

## Final scoring and analysis

```bash
sbatch --export=ALL,STAGE=after slurm/gpu_eval.sbatch
# After successful generation:
sbatch --export=ALL,STAGE=after slurm/cpu_score.sbatch
python student_code/summarize_results.py
```

Give pass counts and pass@1 percentages, plus how many problems switched
fail->pass and pass->fail. Discuss empty/invalid output, compilation problems
and functional mismatch when the evidence supports that classification.
Compare **two** before/after model responses (for example an improvement and a
regression) and tie observations to test outcomes. Explain the significance
and limitations of a single generation per problem and of training loss.

## Submission

Use the **two-file** submission checklist in the main handout: a report PDF
and a ZIP containing your completed scripts, 2,500+ data records and manifest,
training CSV and metadata, and both complete 156-result JSON files.
