import from __future__ { annotations }
import sys;

import networkx as nx;

glob _CHARS_PER_TOKEN: any = 4;
def _safe(unicode_char: str, ascii_fallback: str) -> str;
def _hr(width: int = 50) -> str;

def _estimate_tokens(text: str) -> int;
def _query_subgraph_tokens(
    G: nx.Graph, question: str, depth: int = 3, token_budget: int = 2000
) -> int;

glob _SAMPLE_QUESTIONS: any = [
    "how does authentication work",
    "what is the main entry point",
    "how are errors handled",
    "what connects the data layer to the api",
    "what are the core abstractions",
];
def run_benchmark(
    graph_path: str | None = None,
    corpus_words: int | None = None,
    questions: list[str] | None = None,
) -> dict;
def print_benchmark(result: dict);
