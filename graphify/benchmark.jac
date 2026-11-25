"""Token-reduction benchmark - measures how much context graphify saves vs naive full-corpus approach."""

import from __future__ { annotations }

import sys;

import networkx as nx;

glob _CHARS_PER_TOKEN: any = 4;

"""Return unicode_char if stdout can encode it, else ascii_fallback.

    Windows consoles often default to cp1252 which cannot encode box-drawing
    or arrow glyphs; printing them raises UnicodeEncodeError mid-output.
    """
def _safe(unicode_char: str, ascii_fallback: str) -> str;

"""Horizontal rule that survives non-UTF-8 stdout (e.g. Windows cp1252 console)."""
def _hr(width: int = 50) -> str;

def _estimate_tokens(text: str) -> int;

"""Estimated tokens of the answer query_graph returns for ``question`` (BFS,
    the MCP tool's defaults), 0 when nothing in the graph matches it. The
    answer is the real one an agent receives: seeds, budget cut and notices."""
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

"""Measure token reduction: corpus tokens vs graphify query tokens.

    Args:
        graph_path: path to the built graph
        corpus_words: total word count from detect() output; if None, estimated from graph
        questions: list of questions to benchmark; defaults to _SAMPLE_QUESTIONS

    Returns dict with: corpus_tokens, avg_query_tokens, reduction_ratio, per_question
    """
def run_benchmark(
    graph_path: str | None = None,
    corpus_words: int | None = None,
    questions: list[str] | None = None,
) -> dict;

"""Print a human-readable benchmark report."""
def print_benchmark(result: dict) -> None;
