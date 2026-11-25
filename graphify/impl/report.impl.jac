impl _portable_root_label(`root: str) -> str {
    raw: any = `str(`root).replace("\\", "/");
    name: any = Path(raw).name;
    if name in ("", ".", "..") {
        try {
            name = Path(raw).resolve().name;
        } except (OSError, RuntimeError) {
            name = "";
        }
    }
    return name or raw;
}

impl _safe_community_name(label: str) -> str {
    _obsidian_safe_stem: any = importlib.import_module("graphify.export")._obsidian_safe_stem;
    return _obsidian_safe_stem(label);
}

impl load_report_token_cost(graphify_out: Path) -> dict[str, int] {
    cost_path: any = Path(graphify_out) / "cost.json";
    try {
        cost: any = json.loads(cost_path.read_text(encoding="utf-8"));
    } except (OSError, ValueError) {
        return {"input": 0, "output": 0};
    }
    if not isinstance(cost, `dict) {
        return {"input": 0, "output": 0};
    }
    inp: any;
    out: any;
    (inp, out) = (cost.get("total_input_tokens", 0), cost.get("total_output_tokens", 0));
    if `type(inp) is not int or `type(out) is not int {
        return {"input": 0, "output": 0};
    }
    return {"input": inp, "output": out};
}

impl load_learning_for_report(graph_path) -> dict | None {
    import from pathlib { Path as _Path }
    try {
        gp: any = _Path(graph_path);
        load_learning_overlay: any = importlib.import_module("graphify.reflect").load_learning_overlay;
        load_memory_docs: any = importlib.import_module("graphify.reflect").load_memory_docs;
        aggregate_lessons: any = importlib.import_module("graphify.reflect").aggregate_lessons;
        overlay: any = load_learning_overlay(gp);
        dead_ends: list[dict] = [];
        mem: any = gp.parent / "memory";
        if mem.is_dir() {
            agg: any = aggregate_lessons(load_memory_docs(mem));
            dead_ends = agg.get("dead_ends", []);
        }
        if not overlay and not dead_ends {
            return None;
        }
        return {"overlay": overlay, "dead_ends": dead_ends};
    } except Exception {
        return None;
    }
}

impl _learning_section(lines: list, learning: dict | None, top_n: int = 10) -> None {
    nid: any;
    e: any;
    if not learning {
        return;
    }
    overlay: any = learning.get("overlay") or {};
    dead_ends: any = learning.get("dead_ends") or [];
    preferred: any = [
        (nid, e)
        for (nid, e) in overlay.items()
        if isinstance(e, `dict) and e.get("status") == "preferred"
    ];
    preferred.sort(
        key=lambda (kv) -> any {
            (-kv[1].get("uses", 0), -`float(kv[1].get("score", 0) or 0), kv[0])
        },
    );
    if not preferred and not dead_ends {
        return;
    }
    lines += ["", "## Work-memory lessons"];
    if preferred {
        lines += ["", "**Preferred sources** — corroborated by past sessions; start here."];
        for (nid, e) in preferred[:top_n] {
            label: any = e.get("label") or nid;
            stale: any = " _(code changed — re-verify)_" if e.get("stale") else "";
            lines.append(
                "- `"
                    + format(label, "")
                    + "` ("
                    + format(e.get("uses", 0), "")
                    + "× useful, score="
                    + format(e.get("score", 0), "")
                    + ")"
                    + format(stale, ""),
            );
        }
    }
    if dead_ends {
        lines += ["", "**Known dead ends** — questions that led nowhere; don't re-derive."];
        for d in dead_ends {
            nodes: any = ", ".join(f"`{n}`" for n in d.get("nodes", []));
            lines.append(
                "- \""
                    + format(d.get("question", ""), "")
                    + "\""
                    + (f" -> {nodes}" if nodes else ""),
            );
        }
    }
}

impl generate(
    G: nx.Graph,
    communities: dict[int, list[str]],
    cohesion_scores: dict[int, float],
    community_labels: dict[int, str],
    god_node_list: list[dict],
    surprise_list: list[dict],
    detection_result: dict,
    token_cost: dict,
    `root: str,
    suggested_questions: list[dict] | None = None,
    min_community_size: int = 3,
    built_at_commit: str | None = None,
    learning: dict | None = None,
    obsidian: bool = False,
) -> str {
    cid: any;
    nodes: any;
    u: any;
    v: any;
    d: any;
    q: any;
    today: any = date.today().isoformat();
    if community_labels {
        community_labels = {
            `int(k) if isinstance(k, `str) else k: v
            for (k, v) in community_labels.items()
        };
    }

    confidences: any = [d.get("confidence", "EXTRACTED") for (_, _, d) in G.edges(data=True)];
    total: any = len(confidences) or 1;
    ext_pct: any = round(confidences.count("EXTRACTED") / total * 100);
    inf_pct: any = round(confidences.count("INFERRED") / total * 100);
    amb_pct: any = round(confidences.count("AMBIGUOUS") / total * 100);

    inf_edges: any = [
        (u, v, d)
        for (u, v, d) in G.edges(data=True)
        if d.get("confidence") == "INFERRED"
    ];
    inf_scores: any = [d.get("confidence_score", 0.5) for (_, _, d) in inf_edges];
    inf_avg: any = round(sum(inf_scores) / len(inf_scores), 2) if inf_scores else None;

    lines: any = [
        f"# Graph Report - {_portable_root_label(`root)}  ({today})",
        "",
        "## Corpus Check",
    ];
    if detection_result.get("warning") {
        lines.append("- " + format(detection_result["warning"], ""));
    } else {
        lines += [
            "- "
                + format(detection_result["total_files"], "")
                + " files · ~"
                + format(detection_result["total_words"], ",")
                + " words",
            "- Verdict: corpus is large enough that graph structure adds value.",
        ];
        unclassified: any = detection_result.get("unclassified") or [];
        if unclassified {
            import from collections { Counter as _Counter }
            ext_counts: any = _Counter(Path(p).suffix or "(none)" for p in unclassified);
            top: any = ", ".join(f"{ext} {n}" for (ext, n) in ext_counts.most_common(3));
            lines.append(
                f"- Unclassified: {len(unclassified)} file(s) not represented in the graph (top: {top})",
            );
        }
        unclassified_warning: any = detection_result.get("unclassified_warning");
        if unclassified_warning {
            lines.append(f"- WARNING: {unclassified_warning}");
        }
    }

    import from .analyze { _is_file_node, _is_concept_node, _is_contains_only_ast_node }

    def _real_node(n) -> bool {
        return not _is_file_node(G, n)
            and not _is_concept_node(G, n)
            and operator.ne(G.nodes[n].get("file_type"), "rationale");
    }

    def _real_count(nodes) -> int {
        return sum(1 for n in nodes if _real_node(n));
    }

    non_empty: any = {
        cid: nodes
        for (cid, nodes) in communities.items()
        if `any(_real_node(n) for n in nodes)
    };
    thin_count_summary: any = sum(
        1 for nodes in communities.values() if _real_count(nodes) < min_community_size
    );
    shown_count: any = sum(
        1 for nodes in communities.values() if _real_count(nodes) >= min_community_size
    );

    lines += [
        "",
        "## Summary",
        f"- {G.number_of_nodes()} nodes · {G.number_of_edges()} edges · {len(communities)} communities"
            + (
                f" ({shown_count} shown, {thin_count_summary} thin omitted)"
                    if thin_count_summary
                    else ""
            ),
        f"- Extraction: {ext_pct}% EXTRACTED · {inf_pct}% INFERRED · {amb_pct}% AMBIGUOUS"
            + (
                f" · INFERRED: {len(inf_edges)} edges (avg confidence: {inf_avg})"
                    if inf_avg is not None
                    else ""
            ),
        "- Token cost: "
            + format(token_cost.get("input", 0), ",")
            + " input · "
            + format(token_cost.get("output", 0), ",")
            + " output",
    ];

    if built_at_commit {
        lines += [
            "",
            "## Graph Freshness",
            f"- Built from commit: `{built_at_commit[:8]}`",
            "- Run `git rev-parse HEAD` and compare to check if the graph is stale.",
            "- Run `graphify update .` after code changes (no API cost).",
        ];
    }
    if non_empty {
        lines += ["", "## Community Hubs (Navigation)"];
        for cid in non_empty {
            label: any = community_labels.get(cid, f"Community {cid}");
            if obsidian {
                safe: any = _safe_community_name(label);
                lines.append(f"- [[_COMMUNITY_{safe}|{label}]]");
            } else {
                lines.append(f"- {label}");
            }
        }
    }

    lines += ["", "## God Nodes (most connected - your core abstractions)"];
    for (i, `node) in enumerate(god_node_list, 1) {
        lines.append(
            format(i, "")
                + ". `"
                + format(`node["label"], "")
                + "` - "
                + format(`node["degree"], "")
                + " edges",
        );
    }

    lines += ["", "## Surprising Connections (you probably didn't know these)"];
    if surprise_list {
        for s in surprise_list {
            relation: any = s.get("relation", "related_to");
            note: any = s.get("note", "");
            files: any = s.get("source_files", ["", ""]);
            conf: any = s.get("confidence", "EXTRACTED");
            cscore: any = s.get("confidence_score");
            if conf == "INFERRED" and cscore is not None {
                conf_tag: any = f"INFERRED {cscore:.2f}";
            } else {
                conf_tag = conf;
            }
            sem_tag: any = " [semantically similar]"
                if relation == "semantically_similar_to"
                else "";
            lines += [
                "- `"
                    + format(s["source"], "")
                    + "` --"
                    + format(relation, "")
                    + "--> `"
                    + format(s["target"], "")
                    + "`  ["
                    + format(conf_tag, "")
                    + "]"
                    + format(sem_tag, ""),
                f"  {files[0]} → {files[1]}" + (f"  _{note}_" if note else ""),
            ];
        }
    } else {
        lines.append("- None detected - all connections are within the same source files.");
    }
    _has_code: any = `any(operator.eq(d.get("file_type"), "code") for (_, d) in G.nodes(data=True))
        or `any(
            _edge[-1].get("relation") in ("imports", "imports_from") for _edge in G.edges(data=True)
        );
    if _has_code {
        import from .analyze { find_import_cycles }
        cycles: any = find_import_cycles(G);
        lines += ["", "## Import Cycles"];
        if cycles {
            for c in cycles {
                cycle: any = c.get("cycle", []);
                length: any = c.get("length", len(cycle));
                if not cycle {
                    continue;
                }
                cycle_path: any = " -> ".join(cycle + [cycle[0]]);
                lines.append(f"- {length}-file cycle: `{cycle_path}`");
            }
        } else {
            lines.append("- None detected.");
        }
    }

    hyperedges: any = G.graph.get("hyperedges", []);
    if hyperedges {
        lines += ["", "## Hyperedges (group relationships)"];
        for h in hyperedges {
            node_labels: any = ", ".join(h.get("nodes", []));
            conf = h.get("confidence", "INFERRED");
            cscore = h.get("confidence_score");
            conf_tag = f"{conf} {cscore:.2f}" if cscore is not None else conf;
            lines.append(
                "- **"
                    + format(h.get("label", h.get("id", "")), "")
                    + "** — "
                    + format(node_labels, "")
                    + " ["
                    + format(conf_tag, "")
                    + "]",
            );
        }
    }

    lines += ["", f"## Communities ({len(communities)} total, {thin_count_summary} thin omitted)"];
    for (cid, nodes) in communities.items() {
        label = community_labels.get(cid, f"Community {cid}");
        score: any = cohesion_scores.get(cid, 0.0);
        real_nodes: any = [n for n in nodes if _real_node(n)];
        if not real_nodes {
            continue;
        }
        if len(real_nodes) < min_community_size {
            continue;
        }
        display: any = [G.nodes[n].get("label", n) for n in real_nodes[:8]];
        suffix: any = f" (+{len(real_nodes) - 8} more)" if len(real_nodes) > 8 else "";
        lines += [
            "",
            f"### Community {cid} - \"{label}\"",
            f"Cohesion: {score:.2f}",
            "Nodes ("
                + format(len(real_nodes), "")
                + "): "
                + format(", ".join(display), "")
                + format(suffix, ""),
        ];
    }

    ambiguous: any = [
        (u, v, d)
        for (u, v, d) in G.edges(data=True)
        if d.get("confidence") == "AMBIGUOUS"
    ];
    if ambiguous {
        lines += ["", "## Ambiguous Edges - Review These"];
        for (u, v, d) in ambiguous {
            ul: any = G.nodes[u].get("label", u);
            vl: any = G.nodes[v].get("label", v);
            lines += [
                f"- `{ul}` → `{vl}`  [AMBIGUOUS]",
                "  "
                    + format(d.get("source_file", ""), "")
                    + " · relation: "
                    + format(d.get("relation", "unknown"), ""),
            ];
        }
    }
    isolated: any = [
        n
        for n in G.nodes()
        if G.degree(n) <= 1 and _real_node(n) and not _is_contains_only_ast_node(G, n)
    ];
    thin_communities: any = {
        cid: nodes
        for (cid, nodes) in communities.items()
        if _real_count(nodes) < min_community_size
    };
    gap_count: any = len(isolated) + len(thin_communities);

    if gap_count > 0 or amb_pct > 20 {
        lines += ["", "## Knowledge Gaps"];
        if isolated {
            isolated_labels: any = [G.nodes[n].get("label", n) for n in isolated[:5]];
            suffix = f" (+{len(isolated) - 5} more)" if len(isolated) > 5 else "";
            raw_isolated: any = sum(1 for n in G.nodes() if G.degree(n) <= 1);
            lines.append(
                "- **"
                    + format(len(isolated), "")
                    + " isolated node(s):** "
                    + format(", ".join(f"`{l}`" for l in isolated_labels), "")
                    + format(suffix, ""),
            );
            has_semantic_layer: any = `any(
                G.nodes[n].get("file_type") in ("document", "paper", "image") for n in G.nodes()
            );
            reason: any = "possible missing edges or undocumented components"
                if has_semantic_layer
                else "possible missing edges";
            lines.append(
                f"  These have ≤1 connection - {reason}. (Counts symbols only; {raw_isolated} node(s) total have ≤1 connection when file, concept and rationale nodes are included.)",
            );
        }
        if thin_communities {
            lines.append(
                f"- **{len(thin_communities)} thin communities (<{min_community_size} nodes) omitted from report** — run `graphify query` to explore isolated nodes.",
            );
        }
        if amb_pct > 20 {
            lines.append(
                f"- **High ambiguity: {amb_pct}% of edges are AMBIGUOUS.** Review the Ambiguous Edges section above.",
            );
        }
    }
    _learning_section(lines, learning);

    if suggested_questions {
        no_signal: any = operator.eq(len(suggested_questions), 1)
            and operator.eq(suggested_questions[0].get("type"), "no_signal");
        high_conf: any = [q for q in suggested_questions if not q.get("low_confidence")];
        low_conf: any = [q for q in suggested_questions if q.get("low_confidence")];

        lines += ["", "## Suggested Questions"];
        if no_signal {
            lines.append("_" + format(suggested_questions[0]["why"], "") + "_");
        } else {
            lines.append("_Questions this graph is uniquely positioned to answer:_");
            lines.append("");
            for q in high_conf {
                if q.get("question") {
                    lines.append("- **" + format(q["question"], "") + "**");
                    lines.append("  _" + format(q["why"], "") + "_");
                }
            }
            if low_conf {
                lines += ["", "### Low-confidence Hints"];
                lines.append(
                    "_AMBIGUOUS edges — the extractor was unsure. Verify before acting on these._"
                );
                lines.append("");
                for q in low_conf {
                    if q.get("question") {
                        lines.append("- **" + format(q["question"], "") + "**");
                        lines.append("  _" + format(q["why"], "") + "_");
                    }
                }
            }
        }
    }

    return "\n".join(lines);
}
