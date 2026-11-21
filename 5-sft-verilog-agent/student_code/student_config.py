"""Fill the None values yourself, then submit the Grace training job.

Examples are guidance only. Keep your exact choices in the report.
"""
TRAIN_DATA = 'data/train.jsonl'
BASE_MODEL = 'codellama/CodeLlama-7b-Instruct-hf'
OUTPUT_DIR = 'output/sft_run'
MAX_LENGTH = 2048           # Retain longer verified sequential-design examples.
LEARNING_RATE = 5e-5        # Stable rate retained from the successful 5k run.
NUM_EPOCHS = 1              # 10k diverse examples gives about the prior update count.
LORA_R = 16                 # Attention-projection adapter rank.
LORA_ALPHA = 32             # 2x rank scaling.
BATCH_SIZE = 1              # Safe per-device batch size for 7B QLoRA at 2048 tokens.
GRAD_ACCUM = 16             # Effective batch size: 16 sequences.
LORA_DROPOUT = 0.05
WARMUP_RATIO = 0.03
WEIGHT_DECAY = 0.01
SEED = 42
LOG_EVERY = 10
