from dataclasses import dataclass
from typing import Protocol, Sequence

@dataclass
class RetrievedExample:
    text: str
    score: float | None = None
    source: str | None = None

class Retriever(Protocol):
    def retrieve(self, query: str, top_k: int = 5) -> Sequence[RetrievedExample]: ...

def format_examples(examples: Sequence[RetrievedExample]) -> str:
    blocks=[]
    for i,x in enumerate(examples,1):
        meta=f"source={x.source or 'unknown'} score={x.score if x.score is not None else 'n/a'}"
        blocks.append(f"[Retrieved example {i}; {meta}]\n{x.text}")
    return "\n\n".join(blocks)
