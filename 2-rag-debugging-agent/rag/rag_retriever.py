"""rag_retriever.py: Adapter that exposes the RAG index through the course Retriever interface.
rag_retriever.py: Wraps the persisted RAGIndex so the debugging agent can call retrieve(query, top_k).

This connects the two provided pieces without either side depending on the other's internals:
- `rag/index.py` (RAGIndex) builds and queries the local index (lexical by default; semantic optional).
- `rag/retriever_interface.py` defines the small Retriever Protocol the agent depends on.

Typical use:
    # build once (from the package root):
    #   python -m rag.build_index --dataset rag_dataset --index-dir .rag_index --backend lexical
    from rag.rag_retriever import IndexRetriever
    retriever = IndexRetriever.load(".rag_index")
    hits = retriever.retrieve("controller pcsrc branch logic", top_k=5)
    # each hit has .text, .source, .score
"""

from __future__ import annotations

from pathlib import Path
from typing import Sequence

from .index import RAGIndex
from .retriever_interface import RetrievedExample


class IndexRetriever:
    """Retriever backed by a persisted RAGIndex (satisfies the Retriever Protocol)."""

    def __init__(self, index: RAGIndex):
        self._index = index

    @classmethod
    def load(cls, index_dir: str | Path) -> "IndexRetriever":
        """Load a previously built index from disk."""
        return cls(RAGIndex.load(Path(index_dir)))

    def retrieve(self, query: str, top_k: int = 5) -> Sequence[RetrievedExample]:
        """Return the top-k retrieved chunks as RetrievedExample objects (text + source)."""
        chunks = self._index.retrieve_chunks(query, k=top_k)
        return [
            RetrievedExample(text=chunk.text, score=None, source=chunk.source)
            for chunk in chunks
        ]
