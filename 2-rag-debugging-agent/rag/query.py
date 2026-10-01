from __future__ import annotations

import argparse
import json
from pathlib import Path

from .index import RAGIndex


def main() -> int:
    parser = argparse.ArgumentParser(description="Query a persisted local RAG index")
    parser.add_argument("query")
    parser.add_argument("--index-dir", type=Path, default=Path(".rag_index"))
    parser.add_argument("-k", type=int, default=4)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    index = RAGIndex.load(args.index_dir)
    chunks = index.retrieve_chunks(args.query, args.k)
    if args.json:
        print(json.dumps([{"source": item.source, "kind": item.kind, "text": item.text} for item in chunks], indent=2))
    else:
        for position, item in enumerate(chunks, 1):
            print(f"[{position}] {item.source}\n{item.text}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
