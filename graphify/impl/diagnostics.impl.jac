impl _safe_text(value: Any) -> str {
    if value is None {
        return "";
    }
    if isinstance(value, (`str, `int, `float, `bool)) {
        return `str(value);
    }
    return json.dumps(value, sort_keys=True, default=str, ensure_ascii=False);
}

impl _edge_list(extraction: dict[str, Any]) -> list[Any] {
    edges: any = extraction.get("edges");
    if edges is None {
        edges = extraction.get("links");
    }
    return edges if isinstance(edges, `list) else [];
}

impl _node_ids(extraction: dict[str, Any]) -> set[str] {
    nodes: any = extraction.get("nodes", []);
    if not isinstance(nodes, `list) {
        return set[any]();
    }
    return {
        `str(`node["id"])
        for `node in nodes
        if isinstance(`node, `dict) and "id" in `node and `node.get("id") is not None
    };
}

impl _canonical_edge(`edge: Any) -> dict[str, str] {
    if not isinstance(`edge, `dict) {
        return {
            "source": "",
            "target": "",
            "relation": "",
            "confidence": "",
            "source_file": "",
            "source_location": "",
            "context": "",
            "_invalid": "non_object_edge",
        };
    }
    source: any = `edge.get("source", `edge.get("from"));
    target: any = `edge.get("target", `edge.get("to"));
    return {
        "source": _safe_text(source),
        "target": _safe_text(target),
        "relation": _safe_text(`edge.get("relation")),
        "confidence": _safe_text(`edge.get("confidence")),
        "source_file": _safe_text(`edge.get("source_file")),
        "source_location": _safe_text(`edge.get("source_location")),
        "context": _safe_text(`edge.get("context")),
        "_invalid": "",
    };
}

impl _exact_signature(`edge: Any) -> str {
    if not isinstance(`edge, `dict) {
        return "<non-object>";
    }
    normalized: any = `dict(`edge);
    if "source" not in normalized and "from" in normalized {
        normalized["source"] = normalized["from"];
    }
    if "target" not in normalized and "to" in normalized {
        normalized["target"] = normalized["to"];
    }
    normalized.pop("from", None);
    normalized.pop("to", None);
    return json.dumps(
        normalized, sort_keys=True, default=str, ensure_ascii=False, separators=(",", ":")
    );
}

impl _count_extra(counter: Counter[Any]) -> int {
    return sum(count - 1 for count in counter.values() if count > 1);
}

impl _variant_group_count(
    grouped_edges: dict[tuple[str, str], list[dict[str, str]]],
    field: str,
    *,
    relation_sensitive: bool = False,
) -> int {
    groups: any = 0;
    for edges in grouped_edges.values() {
        if relation_sensitive {
            by_relation: dict[str, set[str]] = defaultdict(set[any]);
            for `edge in edges {
                by_relation[`edge["relation"]].add(`edge[field]);
            }
            groups += sum(1 for values in by_relation.values() if len(values) > 1);
        } elif len({`edge[field] for `edge in edges}) > 1 {
            groups += 1;
        }
    }
    return groups;
}

impl _tuple_arity_from_annotation(line: str) -> int {
    `match: any = _TYPE_TUPLE_RE.search(line);
    if not `match {
        return 0;
    }
    inside: any = `match.group("inside").strip();
    if not inside {
        return 0;
    }
    return inside.count(",") + 1;
}

impl scan_producer_suppression_sites(path: str | Path) -> dict[str, Any] {
    source_path: any = Path(path);
    if not source_path.exists() {
        return {
            "path": `str(source_path),
            "total_sites": 0,
            "sites": [],
            "error": "file not found",
        };
    }

    sites: list[dict[str, Any]] = [];
    lines: any = source_path.read_text(encoding="utf-8").splitlines();
    for (lineno, line) in enumerate(lines, 1) {
        `match: any = _SUPPRESSION_DECL_RE.match(line);
        if not `match {
            continue;
        }
        sites.append({
            "line": lineno,
            "name": `match.group("name"),
            "tuple_arity": _tuple_arity_from_annotation(line),
            "sample": line.strip()[:120],
        });
    }

    return {"path": `str(source_path), "total_sites": len(sites), "sites": sites, "error": ""};
}

impl diagnose_extraction(
    extraction: dict[str, Any],
    *,
    directed: bool = True,
    `root: str | Path | None = None,
    max_examples: int = 5,
    extract_path: str | Path | None = None,
) -> dict[str, Any] {
    `edge: any;
    build_from_json: any = importlib.import_module("graphify.build").build_from_json;

    node_ids: any = _node_ids(extraction);
    raw_edges: any = _edge_list(extraction);
    canonical_edges: any = [_canonical_edge(`edge) for `edge in raw_edges];
    raw_nodes: any = extraction.get("nodes");
    unverified_node_count: any = sum(
        1
        for n in (raw_nodes if isinstance(raw_nodes, `list) else [])
        if isinstance(n, `dict) and n.get("verification") == "unverified",
    );

    exact_counts: Counter[str] = Counter(_exact_signature(`edge) for `edge in raw_edges);
    directed_pairs: Counter[tuple[str, str]] = Counter();
    undirected_pairs: Counter[tuple[str, str]] = Counter();
    grouped: dict[tuple[str, str], list[dict[str, str]]] = defaultdict(list[any]);

    non_object_edges: any = 0;
    missing_endpoint_edges: any = 0;
    dangling_endpoint_edges: any = 0;
    external_reference_edges: any = 0;
    self_loop_edges: any = 0;
    valid_candidate_edges: any = 0;

    for `edge in canonical_edges {
        if `edge["_invalid"] {
            non_object_edges += 1;
            continue;
        }
        source: any = `edge["source"];
        target: any = `edge["target"];
        if not source or not target {
            missing_endpoint_edges += 1;
            continue;
        }
        if source not in node_ids or target not in node_ids {
            if source in node_ids and target.startswith("ref_") {
                external_reference_edges += 1;
            } else {
                dangling_endpoint_edges += 1;
            }
            continue;
        }
        if source == target {
            self_loop_edges += 1;
        }
        valid_candidate_edges += 1;
        directed_pair: any = (source, target);
        undirected_pair: any = (source, target) if source <= target else (target, source);
        directed_pairs[directed_pair] += 1;
        undirected_pairs[undirected_pair] += 1;
        grouped[directed_pair].append(`edge);
    }

    examples: list[dict[str, Any]] = [];
    if max_examples > 0 {
        for ((source, target), count) in directed_pairs.most_common() {
            if count < 2 {
                continue;
            }
            edges: any = grouped[source, target];
            examples.append({
                "source": source,
                "target": target,
                "edge_count": count,
                "relations": sorted({`edge["relation"] for `edge in edges}),
                "source_files": sorted({`edge["source_file"] for `edge in edges}),
                "source_locations": sorted({`edge["source_location"] for `edge in edges}),
                "contexts": sorted({`edge["context"] for `edge in edges}),
            });
            if len(examples) >= max_examples {
                break;
            }
        }
    }

    build_error: any = "";
    graph_type: any = "";
    post_build_edge_count: int | None = None;
    post_build_node_count: int | None = None;
    try {
        graph_input: any = deepcopy(extraction);
        `graph: nx.Graph = build_from_json(graph_input, directed=directed, root=`root);
        graph_type = `type(`graph).__name__;
        post_build_edge_count = `graph.number_of_edges();
        post_build_node_count = `graph.number_of_nodes();
    } except Exception as exc {
        build_error = f"{`type(exc).__name__}: {exc}";
    }

    suppression_path: any = Path(extract_path)
        if extract_path
        else Path(__file__).with_name("extract.py");

    return {
        "node_count": len(node_ids),
        "unverified_node_count": unverified_node_count,
        "raw_edge_count": len(raw_edges),
        "non_object_edges": non_object_edges,
        "missing_endpoint_edges": missing_endpoint_edges,
        "dangling_endpoint_edges": dangling_endpoint_edges,
        "external_reference_edges": external_reference_edges,
        "self_loop_edges": self_loop_edges,
        "valid_candidate_edges": valid_candidate_edges,
        "exact_duplicate_edges": _count_extra(exact_counts),
        "directed_unique_endpoint_pairs": len(directed_pairs),
        "directed_same_endpoint_collapsed_edges": _count_extra(directed_pairs),
        "undirected_unique_endpoint_pairs": len(undirected_pairs),
        "undirected_same_endpoint_collapsed_edges": _count_extra(undirected_pairs),
        "same_endpoint_group_count": sum(1 for count in directed_pairs.values() if count > 1),
        "relation_variant_groups": _variant_group_count(grouped, "relation"),
        "source_file_variant_groups": _variant_group_count(
            grouped, "source_file", relation_sensitive=True
        ),
        "source_location_variant_groups": _variant_group_count(
            grouped, "source_location", relation_sensitive=True
        ),
        "context_variant_groups": _variant_group_count(grouped, "context", relation_sensitive=True),
        "post_build_graph_type": graph_type,
        "post_build_node_count": post_build_node_count,
        "post_build_edge_count": post_build_edge_count,
        "post_build_error": build_error,
        "producer_suppression": scan_producer_suppression_sites(suppression_path),
        "examples": examples,
    };
}

impl _read_json_file(path: str | Path) -> dict[str, Any] {
    check_graph_file_size_cap: any = importlib.import_module("graphify.security").check_graph_file_size_cap;

    json_path: any = Path(path);
    check_graph_file_size_cap(json_path);
    try {
        data: any = json.loads(json_path.read_text(encoding="utf-8"));
    } except (json.JSONDecodeError, OSError) as exc {
        raise RuntimeError(
            f"Cannot parse {json_path}: {exc}. The file may be corrupted — re-run 'graphify extract'.",
        ) from exc;
    }
    if not isinstance(data, `dict) {
        raise ValueError("diagnostic input must be a JSON object");
    }
    return data;
}

impl diagnose_file(
    path: str | Path,
    *,
    directed: bool | None = None,
    `root: str | Path | None = None,
    max_examples: int = 5,
    extract_path: str | Path | None = None,
) -> dict[str, Any] {
    data: any = _read_json_file(path);
    if directed is None {
        raw_directed: any = data.get("directed");
        effective_directed: any = raw_directed if isinstance(raw_directed, `bool) else True;
    } else {
        effective_directed = directed;
    }

    summary: any = diagnose_extraction(
        data,
        directed=effective_directed,
        root=`root,
        max_examples=max_examples,
        extract_path=extract_path,
    );
    summary["input_path"] = `str(path);
    summary["effective_directed"] = effective_directed;
    return summary;
}

impl format_diagnostic_json(summary: dict[str, Any]) -> dict[str, Any] {
    return {
        "schema_version": 1,
        "summary": {
            key: value
            for (key, value) in summary.items()
            if key not in {"examples", "producer_suppression"}
        },
        "examples": summary.get("examples", []),
        "producer_suppression": summary.get("producer_suppression", {}),
        "notes": [
            "Diagnostics are read-only.",
            "A normal graph.json is already post-build and cannot recover raw producer edges.",
            "Producer suppression sites are heuristic source-code evidence.",
        ],
    };
}

impl format_diagnostic_report(summary: dict[str, Any]) -> str {
    suppression: any = summary.get("producer_suppression", {});
    lines: any = [
        "[graphify] MultiDiGraph edge-collapse diagnostic",
        "input: " + format(summary.get("input_path", "<in-memory>"), ""),
        "input_stage: provided JSON (normal graph.json is post-build)",
        "effective_directed: " + format(summary.get("effective_directed", "<direct-call>"), ""),
        "nodes: " + format(summary["node_count"], ""),
        "unverified_code_nodes: " + format(summary.get("unverified_node_count", 0), ""),
        "raw_edges: " + format(summary["raw_edge_count"], ""),
        "valid_candidate_edges: " + format(summary["valid_candidate_edges"], ""),
        "missing_endpoint_edges: " + format(summary["missing_endpoint_edges"], ""),
        "dangling_endpoint_edges: " + format(summary["dangling_endpoint_edges"], ""),
        "external_reference_edges: " + format(summary.get("external_reference_edges", 0), ""),
        "self_loop_edges: " + format(summary["self_loop_edges"], ""),
        "exact_duplicate_edges: " + format(summary["exact_duplicate_edges"], ""),
        "directed_unique_endpoint_pairs: " + format(summary["directed_unique_endpoint_pairs"], ""),
        "directed_same_endpoint_collapsed_edges: "
            + format(summary["directed_same_endpoint_collapsed_edges"], ""),
        "undirected_unique_endpoint_pairs: "
            + format(summary["undirected_unique_endpoint_pairs"], ""),
        "undirected_same_endpoint_collapsed_edges: "
            + format(summary["undirected_same_endpoint_collapsed_edges"], ""),
        "same_endpoint_group_count: " + format(summary["same_endpoint_group_count"], ""),
        "relation_variant_groups: " + format(summary["relation_variant_groups"], ""),
        "source_file_variant_groups: " + format(summary["source_file_variant_groups"], ""),
        "source_location_variant_groups: " + format(summary["source_location_variant_groups"], ""),
        "context_variant_groups: " + format(summary["context_variant_groups"], ""),
        "post_build_graph_type: " + format(summary["post_build_graph_type"], ""),
        "post_build_edges: " + format(summary["post_build_edge_count"], ""),
        "producer_suppression_sites: " + format(suppression.get("total_sites", 0), ""),
    ];
    if summary.get("post_build_error") {
        lines.append("post_build_error: " + format(summary["post_build_error"], ""));
    }
    if suppression.get("error") {
        lines.append("producer_suppression_error: " + format(suppression["error"], ""));
    }
    if suppression.get("sites") {
        lines.append("producer_suppression_examples:");
        for site in suppression["sites"][:8] {
            lines.append(
                "  - L"
                    + format(site["line"], "")
                    + " "
                    + format(site["name"], "")
                    + " arity="
                    + format(site["tuple_arity"] or "unknown", ""),
            );
        }
    }
    if summary.get("examples") {
        lines.append("examples:");
        for example in summary["examples"] {
            lines.append(
                "  - "
                    + format(example["source"], "")
                    + " -> "
                    + format(example["target"], "")
                    + " edges="
                    + format(example["edge_count"], "")
                    + " relations="
                    + format(example["relations"], "")
                    + " locations="
                    + format(example["source_locations"], "")
                    + " contexts="
                    + format(example["contexts"], ""),
            );
        }
    }
    lines.append(
        "note: normal graph.json is post-build; raw producer loss must be measured earlier."
    );
    return "\n".join(lines);
}
