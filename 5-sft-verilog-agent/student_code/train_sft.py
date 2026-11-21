#!/usr/bin/env python3
"""Single-GPU QLoRA supervised fine-tuning on Grace with TRL SFTTrainer."""
import csv
import json
import platform
from pathlib import Path

import torch
from datasets import Dataset
from peft import LoraConfig
from transformers import (AutoModelForCausalLM, AutoTokenizer,
                          BitsAndBytesConfig, TrainerCallback, set_seed)
from trl import SFTConfig, SFTTrainer

import student_config as cfg
from common import (model_prompt, validate_sample_count, validate_token_ceiling,
                    MODEL_CONTEXT_TOKENS)


class JsonlLog(TrainerCallback):
    """Flush every trainer log event to disk; survives an interrupted job."""
    def __init__(self, path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text("", encoding="utf-8")

    def on_log(self, args, state, control, logs=None, **kwargs):
        record = {"step": state.global_step, "epoch": state.epoch, **(logs or {})}
        with self.path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(record, default=str) + "\n")


def build_lora_config():
    """Configure the LoRA adapter for Code Llama's attention projections.

    PEFT reference: https://huggingface.co/docs/peft/en/conceptual_guides/lora
    You may choose other suitable Llama projections if you explain why.
    The result must be a peft.LoraConfig instance.
    """
    # STUDENT IMPLEMENTATION 3: set rank, alpha, dropout, bias,
    # task_type="CAUSAL_LM" and target_modules. For example, inspect
    # q_proj, k_proj, v_proj and o_proj in the model architecture.
    return LoraConfig(
        r=cfg.LORA_R,
        lora_alpha=cfg.LORA_ALPHA,
        lora_dropout=cfg.LORA_DROPOUT,
        bias="none",
        task_type="CAUSAL_LM",
        target_modules=["q_proj", "k_proj", "v_proj", "o_proj"],
    )


def validate_configuration():
    needed = ["TRAIN_DATA", "MAX_LENGTH", "LEARNING_RATE", "NUM_EPOCHS",
              "LORA_R", "LORA_ALPHA", "BATCH_SIZE", "GRAD_ACCUM",
              "WARMUP_RATIO", "WEIGHT_DECAY"]
    missing = [key for key in needed if getattr(cfg, key) is None]
    if missing:
        raise ValueError("Fill student_config.py: " + ", ".join(missing))
    validate_token_ceiling(cfg.MAX_LENGTH)
    if not torch.cuda.is_available():
        raise EnvironmentError("This training script requires an allocated CUDA GPU")


def main():
    validate_configuration()
    set_seed(cfg.SEED)
    out = Path(cfg.OUTPUT_DIR)
    out.mkdir(parents=True, exist_ok=True)
    tok = AutoTokenizer.from_pretrained(cfg.BASE_MODEL)
    if tok.pad_token is None:
        tok.pad_token = tok.eos_token
    rows = Dataset.from_json(cfg.TRAIN_DATA)
    if set(rows.column_names) != {"prompt", "completion"}:
        raise ValueError("Expected two columns: prompt and completion")
    validate_sample_count(len(rows))
    rows = rows.map(lambda x: {"prompt": model_prompt(tok, x["prompt"]),
                               "completion": x["completion"] + tok.eos_token})
    # Check for avoidable code truncation before training.
    for idx, row in enumerate(rows):
        total = len(tok(row["prompt"] + row["completion"],
                        add_special_tokens=False)["input_ids"])
        if total > cfg.MAX_LENGTH:
            raise ValueError(f"Example {idx} has {total} tokens; regenerate data "
                             f"with --max-tokens {cfg.MAX_LENGTH}")
    bf16 = torch.cuda.is_bf16_supported()
    dtype = torch.bfloat16 if bf16 else torch.float16
    quant = BitsAndBytesConfig(
        load_in_4bit=True, bnb_4bit_quant_type="nf4",
        bnb_4bit_use_double_quant=True, bnb_4bit_compute_dtype=dtype,
    )
    model = AutoModelForCausalLM.from_pretrained(
        cfg.BASE_MODEL, quantization_config=quant,
        torch_dtype=dtype, device_map={"": torch.cuda.current_device()},
    )
    model.config.use_cache = False
    lora = build_lora_config()
    args = SFTConfig(
        output_dir=str(out / "checkpoints"),
        max_length=cfg.MAX_LENGTH,
        learning_rate=cfg.LEARNING_RATE,
        warmup_ratio=cfg.WARMUP_RATIO,
        weight_decay=cfg.WEIGHT_DECAY,
        num_train_epochs=cfg.NUM_EPOCHS,
        per_device_train_batch_size=cfg.BATCH_SIZE,
        gradient_accumulation_steps=cfg.GRAD_ACCUM,
        logging_steps=cfg.LOG_EVERY,
        logging_first_step=True,
        logging_strategy="steps",
        save_strategy="epoch",
        save_total_limit=2,
        completion_only_loss=True,
        packing=False,
        gradient_checkpointing=True,
        optim="paged_adamw_8bit",
        bf16=bf16, fp16=not bf16,
        seed=cfg.SEED, report_to="none",
    )
    trainer = SFTTrainer(
        model=model, args=args, train_dataset=rows,
        processing_class=tok, peft_config=lora,
        callbacks=[JsonlLog(out / "training_log.jsonl")],
    )
    trainer.model.print_trainable_parameters()
    result = trainer.train()
    trainer.save_model(str(out / "adapter"))
    tok.save_pretrained(out / "adapter")
    (out / "trainer_state.json").write_text(
        json.dumps(trainer.state.log_history, indent=2, default=str), encoding="utf-8"
    )
    with (out / "training_log.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["step", "epoch", "loss", "grad_norm", "learning_rate"])
        writer.writeheader()
        for log in trainer.state.log_history:
            if "loss" in log:
                writer.writerow({k: log.get(k) for k in writer.fieldnames})
    metadata = {
        "base_model": cfg.BASE_MODEL, "train_data": cfg.TRAIN_DATA,
        "train_example_count": len(rows), "model_context_tokens": MODEL_CONTEXT_TOKENS,
        "hyperparameters": {key: getattr(cfg, key) for key in (
            "MAX_LENGTH", "LEARNING_RATE", "NUM_EPOCHS", "LORA_R",
            "LORA_ALPHA", "LORA_DROPOUT", "BATCH_SIZE", "GRAD_ACCUM",
            "WARMUP_RATIO", "WEIGHT_DECAY", "SEED")},
        "rows": len(rows), "precision": "bf16" if bf16 else "fp16",
        "gpu": torch.cuda.get_device_name(), "python": platform.python_version(),
        "torch": torch.__version__, "training_loss": result.training_loss,
        "global_steps": trainer.state.global_step,
    }
    (out / "run_metadata.json").write_text(json.dumps(metadata, indent=2, default=str) + "\n")
    print("Adapter:", out / "adapter")
    print("Loss logs:", out / "training_log.jsonl", out / "training_log.csv")


if __name__ == "__main__":
    main()
