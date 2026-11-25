impl _safe(unicode_char: str, ascii_fallback: str) -> str {
    encoding: any = getattr(sys.stdout, "encoding", None) or "";
    try {
        unicode_char.encode(encoding);
        return unicode_char;
    } except (UnicodeEncodeError, LookupError) {
        return ascii_fallback;
    }
}

impl _hr(width: int = 50) -> str {
    return _safe("─", "-") * width;
}

impl _estimate_tokens(text: str) -> int {
    return max(1, len(text) // _CHARS_PER_TOKEN);
}

impl _query_subgraph_tokens(
    G: nx.Graph, question: str, depth: int = 3, token_budget: int = 2000
) -> int {
    text: any = _query_graph_text(G, question, mode="bfs", depth=depth, token_budget=token_budget);
    if text == "No matching nodes found." {
        return 0;
    }
    return _estimate_tokens(text);
}

impl run_benchmark(
    graph_path: str | None = None,
    corpus_words: int | None = None,
    questions: list[str] | None = None,
) -> dict {
    graph_path = graph_path or _default_graph_json();
    G: any = _read_graph(`str(graph_path));

    if corpus_words is None {
        corpus_words = G.number_of_nodes() * 50;
    }

    corpus_tokens: any = corpus_words * 100 // 75;

    qs: any = questions or _SAMPLE_QUESTIONS;
    per_question: any = [];
    for q in qs {
        qt: any = _query_subgraph_tokens(G, q);
        if qt > 0 {
            per_question.append({
                "question": q,
                "query_tokens": qt,
                "reduction": round(corpus_tokens / qt, 1),
            });
        }
    }

    if not per_question {
        return {"error": "No matching nodes found for sample questions. Build the graph first."};
    }

    avg_query_tokens: any = sum(p["query_tokens"] for p in per_question) // len(per_question);
    reduction_ratio: any = round(corpus_tokens / avg_query_tokens, 1)
        if avg_query_tokens > 0
        else 0;

    return {
        "corpus_tokens": corpus_tokens,
        "corpus_words": corpus_words,
        "nodes": G.number_of_nodes(),
        "edges": G.number_of_edges(),
        "avg_query_tokens": avg_query_tokens,
        "reduction_ratio": reduction_ratio,
        "per_question": per_question,
    };
}

impl print_benchmark(result: dict) -> None {
    if "error" in result {
        print("Benchmark error: " + format(result["error"], ""));
        return;
    }

    print(f"\ngraphify token reduction benchmark");
    print(_hr(50));
    arrow: any = _safe("→", "->");
    print(
        "  Corpus:          "
            + format(result["corpus_words"], ",")
            + " words "
            + format(arrow, "")
            + " ~"
            + format(result["corpus_tokens"], ",")
            + " tokens (naive)",
    );
    print(
        "  Graph:           "
            + format(result["nodes"], ",")
            + " nodes, "
            + format(result["edges"], ",")
            + " edges",
    );
    print("  Avg query cost:  ~" + format(result["avg_query_tokens"], ",") + " tokens");
    print(
        "  Reduction:       " + format(result["reduction_ratio"], "") + "x fewer tokens per query"
    );
    print(f"\n  Per question:");
    for p in result["per_question"] {
        print("    [" + format(p["reduction"], "") + "x] " + format(p["question"][:55], ""));
    }
    print();
}
