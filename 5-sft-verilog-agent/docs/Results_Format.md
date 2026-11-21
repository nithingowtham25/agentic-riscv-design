# Result files and training logs

`score_v2.py` reads responses made by `evaluate_model.py`, runs the **official
VerilogEval v2** Icarus Makefile tests and analyzer, and writes
`benchmark_results.json` for each stage. Only the generated `TopModule` is
submitted as the device under test, with the original test/reference files
inside the v2 checkout. The schema is in `schemas/benchmark_results.schema.json`.

The following is an **illustrative shape**, not a measured result; the actual
`responses` array has 156 unique `task_id` records:

```json
{
  "benchmark": "VerilogEval v2 Human spec-to-rtl",
  "score": {"passed": 0, "total": 156, "pass_at_1": 0.0},
  "responses": [
    {
      "task_id": "EXAMPLE_ONLY",
      "prompt": "VerilogEval v2 specification text",
      "raw_response": "<think>Explanation</think><verilog>module TopModule; endmodule</verilog>",
      "completion": "module TopModule; endmodule\n",
      "base_model": "codellama/CodeLlama-7b-Instruct-hf",
      "adapter": null,
      "generation_settings": {
        "do_sample": false,
        "max_new_tokens": 2048,
        "num_return_sequences": 1,
        "temperature": null,
        "top_p": null,
        "quantization": "4bit-nf4"
      },
      "passed": false,
      "result": "S"
    }
  ]
}
```

The `result` field is the official v2 analyzer's status character: `.` means
functional pass; other codes indicate a failure category such as syntax,
compile, runtime, or timeout. Keep `official_v2_summary.csv` and
`official_v2_summary.txt` as evidence. `samples.jsonl` stores just each task ID
and extracted RTL, while `samples.jsonl_results.jsonl` adds the analyzer's
pass/fail status. The raw model answer must remain unedited in `raw_response`.

The formula is `pass_at_1 = number of passing tasks / 156`. The before and
after sets must use the same problem IDs and prompt texts. `summarize_results.py`
creates `output/comparison.json` after both full evaluation stages complete.

## Loss and training metadata

`training_log.jsonl` is appended and flushed at every training log event.
After successful training, `training_log.csv` contains
`step,epoch,loss,grad_norm,learning_rate`; `trainer_state.json` has the full
Trainer log history, `run_metadata.json` has configuration and device details,
and `adapter/` contains the trained LoRA weights. Save Slurm stdout/stderr as
well. A low loss is not itself evidence of functional correctness.
