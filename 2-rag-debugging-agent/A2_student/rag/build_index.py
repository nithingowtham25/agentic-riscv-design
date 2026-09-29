from __future__ import annotations

import argparse
import json
from pathlib import Path

from .index import RAGIndex, discover_sources, make_chunks


def main() -> int:
    parser = argparse.ArgumentParser(description="Build the local RAG index for the RTL debugging lab")
    parser.add_argument("--dataset", type=Path, default=Path("rag_dataset"))
    parser.add_argument("--index-dir", type=Path, default=Path(".rag_index"))
    parser.add_argument("--model", default="sentence-transformers/all-MiniLM-L6-v2")
    parser.add_argument("--chunk-words", type=int, default=180)
    parser.add_argument("--overlap-words", type=int, default=30)
    parser.add_argument("--extra-source", type=Path, action="append", default=[])
    args = parser.parse_args()

    sources = discover_sources(args.dataset)
    sources.extend(args.extra_source)
    sources = list(dict.fromkeys(path.resolve() for path in sources))
    chunks = make_chunks(sources, Path.cwd(), args.chunk_words, args.overlap_words)
    index = RAGIndex.build(chunks, model_name=args.model)
    index.save(args.index_dir)
    print(json.dumps({
        "model": index.model_name,
        "chunk_count": len(index.chunks),
        "source_count": len(sources),
        "index_dir": str(args.index_dir),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
