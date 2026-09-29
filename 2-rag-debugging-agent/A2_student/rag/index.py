from __future__ import annotations

import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable, Sequence


TOKEN_RE = re.compile(r"0x[0-9a-fA-F]+|[A-Za-z_][A-Za-z0-9_]*|[0-9]+")
TEXT_SUFFIXES = {".md", ".txt", ".sv", ".svh", ".log", ".tsv"}

DEFAULT_MODEL = "sentence-transformers/all-MiniLM-L6-v2"


@dataclass(frozen=True)
class Chunk:
    """One self-contained retrieval unit."""

    chunk_id: str
    source: str
    text: str
    kind: str


def chunk_text(text: str, chunk_words: int = 180, overlap_words: int = 30) -> list[str]:
    words = text.split()
    if not words:
        return []
    if chunk_words <= 0 or overlap_words < 0 or overlap_words >= chunk_words:
        raise ValueError("chunk_words must be positive and overlap_words must be smaller")
    chunks: list[str] = []
    step = chunk_words - overlap_words
    for start in range(0, len(words), step):
        part = words[start : start + chunk_words]
        if not part:
            break
        chunks.append(" ".join(part))
        if start + chunk_words >= len(words):
            break
    return chunks


def _read_pdf(path: Path) -> str:
    try:
        from pypdf import PdfReader
    except ImportError as exc:
        raise RuntimeError(f"cannot index PDF {path}: install pypdf or omit the PDF source") from exc
    reader = PdfReader(str(path))
    return "\n".join(page.extract_text() or "" for page in reader.pages)


def read_source(path: Path) -> str:
    if path.suffix.lower() == ".pdf":
        return _read_pdf(path)
    return path.read_text(encoding="utf-8", errors="replace")


def discover_sources(dataset_dir: Path) -> list[Path]:
    return sorted(
        path for path in dataset_dir.rglob("*") if path.is_file() and path.suffix.lower() in TEXT_SUFFIXES
    )


def make_chunks(
    sources: Iterable[Path],
    root: Path,
    chunk_words: int = 180,
    overlap_words: int = 30,
) -> list[Chunk]:
    chunks: list[Chunk] = []
    for path in sources:
        text = read_source(path).strip()
        if not text:
            continue
        try:
            source_name = str(path.relative_to(root))
        except ValueError:
            source_name = str(path)
        kind = path.parent.name if path.parent.name else path.suffix.lstrip(".")
        for index, part in enumerate(chunk_text(text, chunk_words, overlap_words)):
            chunks.append(Chunk(f"{source_name}#{index}", source_name, part, kind))
    return chunks


class RAGIndex:
    """A semantic (embedding) retrieval index over the RV32I knowledge base.

    Documents are chunked, embedded with a sentence-transformer model, and stored in a FAISS
    index. At query time, the query is embedded and the nearest chunks are returned.

    Chunking, embedding, index building, and save/load are provided. YOU implement the query-time
    retrieval in retrieve_chunks (Phase A): embed the query, search the FAISS index, and return the
    top-k chunks.
    """

    FORMAT_VERSION = 2

    def __init__(self, chunks: Sequence[Chunk], model_name: str = DEFAULT_MODEL,
                 semantic_index=None, encoder=None) -> None:
        self.chunks = list(chunks)
        self.model_name = model_name
        self._index = semantic_index   # a FAISS index (inner-product over normalized vectors)
        self._encoder = encoder        # a SentenceTransformer

    @classmethod
    def build(cls, chunks: Sequence[Chunk], model_name: str = DEFAULT_MODEL) -> "RAGIndex":
        """Embed every chunk and build a FAISS index (provided)."""
        if not chunks:
            raise ValueError("cannot build an index with no chunks")
        try:
            import faiss
            from sentence_transformers import SentenceTransformer
        except ImportError as exc:
            raise RuntimeError(
                "the RAG index needs sentence-transformers and faiss-cpu "
                "(pip install -r requirements-rag.txt)"
            ) from exc
        encoder = SentenceTransformer(model_name)
        vectors = encoder.encode(
            [chunk.text for chunk in chunks], normalize_embeddings=True, show_progress_bar=False,
        )
        index = faiss.IndexFlatIP(vectors.shape[1])  # cosine similarity (vectors are normalized)
        index.add(vectors)
        return cls(chunks, model_name, semantic_index=index, encoder=encoder)

    def embed_query(self, query: str):
        """Embed a query string into a normalized vector (provided). Returns a (1, dim) array."""
        return self._encoder.encode([query], normalize_embeddings=True)

    def retrieve_chunks(self, query: str, k: int = 4) -> list[Chunk]:
        """Return the k chunks most relevant to `query` (YOU implement this - Phase A).

        Use the provided pieces:
          - self.embed_query(query) -> a (1, dim) normalized query vector.
          - self._index.search(vectors, k) -> (scores, indices); indices[0] are the row numbers of
            the top-k chunks (an index of -1 means "no result" and should be skipped).
          - self.chunks[i] -> the Chunk at row i.
        Return a list of the top-k Chunk objects, best first.
        """
        if k <= 0:
            return []

        # ------------------------------------------------------------------
        # STUDENT: embed the query, search the FAISS index for the k nearest chunks,
        # and return those Chunk objects (skip any index that is negative).
        #
        # >>> BEGIN STUDENT PHASE A (RAG retrieval)
        raise NotImplementedError("Implement semantic retrieve_chunks: embed query, FAISS search, return top-k.")
        # <<< END STUDENT PHASE A (RAG retrieval)

    def retrieve(self, query: str, k: int = 4) -> list[str]:
        """Return the top-k chunk texts, matching the assignment interface."""
        return [chunk.text for chunk in self.retrieve_chunks(query, k)]

    def save(self, index_dir: Path) -> None:
        """Persist chunks, metadata, and the FAISS vectors (provided)."""
        import faiss

        index_dir.mkdir(parents=True, exist_ok=True)
        (index_dir / "chunks.json").write_text(
            json.dumps([asdict(chunk) for chunk in self.chunks], indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        metadata = {
            "format_version": self.FORMAT_VERSION,
            "model_name": self.model_name,
            "chunk_count": len(self.chunks),
        }
        (index_dir / "metadata.json").write_text(
            json.dumps(metadata, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        faiss.write_index(self._index, str(index_dir / "vectors.faiss"))

    @classmethod
    def load(cls, index_dir: Path) -> "RAGIndex":
        """Load a persisted index and its embedding model (provided)."""
        import faiss
        from sentence_transformers import SentenceTransformer

        metadata = json.loads((index_dir / "metadata.json").read_text(encoding="utf-8"))
        if metadata.get("format_version") != cls.FORMAT_VERSION:
            raise ValueError("unsupported RAG index format")
        chunks = [Chunk(**item) for item in json.loads((index_dir / "chunks.json").read_text(encoding="utf-8"))]
        model_name = metadata["model_name"]
        encoder = SentenceTransformer(model_name)
        index = faiss.read_index(str(index_dir / "vectors.faiss"))
        return cls(chunks, model_name, semantic_index=index, encoder=encoder)
