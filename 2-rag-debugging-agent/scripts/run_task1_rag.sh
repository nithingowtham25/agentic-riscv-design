#!/usr/bin/env bash
# Task 1: build the semantic index and capture five reproducible retrieval examples.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p logs
python -m rag.build_index --dataset rag_dataset --index-dir .rag_index
python - <<'PY' | tee logs/task1_rag_queries.txt
from pathlib import Path
from rag.index import RAGIndex
index = RAGIndex.load(Path('.rag_index'))
queries = [
    'controller PCSrc branch and jump control integration',
    'signed arithmetic shift right ALU SystemVerilog',
    'RV32I byte halfword word load store little endian byte enable',
    'Icarus Verilog syntax error module port mismatch debug',
    'datapath JAL JALR target PC plus four writeback',
]
for number, query in enumerate(queries, 1):
    print(f'=== QUERY {number}: {query} ===')
    for rank, chunk in enumerate(index.retrieve_chunks(query, k=5), 1):
        print(f'[{rank}] source={chunk.source} id={chunk.chunk_id}')
        print(chunk.text)
        print()
PY