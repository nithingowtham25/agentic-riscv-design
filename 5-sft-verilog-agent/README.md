# Assignment 5 - Code Llama SFT for Verilog

**Base checkpoint:** https://huggingface.co/codellama/CodeLlama-7b-Instruct-hf  
**Cluster:** TAMU HPRC Grace (one allocated A100 GPU)  
**Benchmark:** VerilogEval v2 Human `spec-to-rtl`, 156 prompts  
**Training source:** `wilyub/VeriThoughtsTrainSet`, at least 2,500 examples

See `Course_Setup_Guide_A5.pdf` for Grace login/environment details and the
assignment handout for grading. This folder contains runnable wrappers plus
**three deliberately unfinished student implementation tasks**:

1. `student_code/data_methods.py` -> `make_completion()`: select the response
   format. Reasoning + Verilog with `<think>`/`<verilog>` tags is recommended;
   tagged or plain Verilog alone is also acceptable.
2. `student_code/data_methods.py` -> `select_training_examples()`: design and
   implement the sampling, quality, overlap and token-length filtering policy.
   Return the selected `prompt`/`completion` records and a JSON-compatible
   dictionary explaining your selection and rejection counts.
3. `student_code/train_sft.py` -> `build_lora_config()`: choose the target
   projections and build the PEFT `LoraConfig` using values in
   `student_code/student_config.py`. Fill out **all** the `None` training values.

The TODOs intentionally raise `NotImplementedError` until completed. Don't
remove these exceptions without implementing the required behavior. The driver
will then check the 2,500+ rows, exact two-column schema, duplicates,
benchmark prompt overlap, and **full formatted sequence length**.

Code Llama's configured context window is **16,384 tokens**. Use an SFT cap
that fits this window and GPU memory; e.g. 2,048 or 4,096 tokens. Do not
silently truncate the end of generated Verilog. Filtering long reasoning
sequences may be helpful.

## Grace sequence

Run from `A5_student/`. Before GPU jobs, check `myproject -l` for allocation
balance, and use `maxconfig -h` / HPRC AMS for a cost estimate. The HPRC table
lists an A100 surcharge of **72 SUs per hour on Grace** (128 on FASTER),
**plus CPU charges**; rates and your account's terms should be checked.

```bash
# Environment and VerilogEval installation: see the setup PDF.
python -m unittest discover -s tests -v

# Baseline, then CPU-based official v2 scoring.
sbatch --export=ALL,STAGE=before slurm/gpu_eval.sbatch
sbatch --export=ALL,STAGE=before slurm/cpu_score.sbatch  # AFTER baseline finishes

# Record the baseline GPU job's elapsed runtime; reserve enough SUs for a
# second complete 156-problem inference run, CPU scoring, and a safety margin.
myproject -l
seff <BASELINE_JOB_ID>

# After completing both TODOs in data_methods.py:
sbatch --export=ALL,DATA_COUNT=2500,RESPONSE_FORMAT=reasoned,MAX_TOKENS=2048 slurm/cpu_prepare.sbatch
# Check selected records and manifest after job completes.
wc -l data/train.jsonl
cat data/selection_manifest.json

# Complete build_lora_config() and student_config.py, then submit training.
sbatch slurm/gpu_train.sbatch

# Run the *same* 156-prompt evaluation with the adapter.
sbatch --export=ALL,STAGE=after slurm/gpu_eval.sbatch
sbatch --export=ALL,STAGE=after slurm/cpu_score.sbatch   # AFTER inference finishes
python student_code/summarize_results.py
```

A returned `sbatch` job number does **not** mean the job has finished. Check
`squeue -u "$USER"` and Slurm logs before submitting the next stage. For the
three TODOs, optional offline tests can be enabled once the functions exist:

```bash
A5_TEST_STUDENT=1 python -m unittest discover -s tests -v
```

## Submit exactly two files

`<UIN>_A5_Report.pdf`: methods and observations for each task, dataset selection
and sample examples, LoRA setup and training-loss plot, base/trained pass@1
and status transitions, analysis of **two paired problems**, and your GPU
budget planning based on the original evaluation time.

`<UIN>_A5.zip`: include only these evidence paths (no weights, caches or keys):

```text
student_code/                         # completed source and config
slurm/                                # batch scripts
 data/train.jsonl                     # at least 2,500 records
 data/selection_manifest.json         # student method, counts and provenance
 output/sft_run/training_log.csv
 output/sft_run/run_metadata.json
 output/before/benchmark_results.json # all 156 responses and scores
 output/after/benchmark_results.json  # all 156 responses and scores
```

The `benchmark_results.json` files already include raw responses, extracted
RTL, and simulation outcome. Keep full Slurm logs and adapter weights on the
cluster but do not include them in the required submission.

**Model access:** This exact `codellama` Hugging Face repository does not
currently display an approval gate. However, it is labeled `llama2` and its
model card says the **Meta license still applies**. That is separate from
whether Hugging Face requires manual access approval. Follow the applicable
model terms.
