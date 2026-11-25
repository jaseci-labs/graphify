impl validate_semantic_fragment(fragment: object) -> list[str] {
    if not isinstance(fragment, `dict) {
        return ["fragment must be a JSON object"];
    }

    errors: list[str] = [];
    try {
        payload: any = json.dumps(fragment, ensure_ascii=False).encode("utf-8");
    } except (TypeError, ValueError) as exc {
        return [f"fragment is not JSON-serializable: {exc}"];
    }

    if len(payload) > MAX_SEMANTIC_FRAGMENT_BYTES {
        errors.append(f"payload is {len(payload)} bytes; max is {MAX_SEMANTIC_FRAGMENT_BYTES}");
    }

    nodes: any = fragment.get("nodes", []);
    edges: any = fragment.get("edges", []);
    if not isinstance(nodes, `list) {
        errors.append("nodes must be a list");
        nodes = [];
    } elif len(nodes) > MAX_SEMANTIC_FRAGMENT_NODES {
        errors.append(f"nodes has {len(nodes)} entries; max is {MAX_SEMANTIC_FRAGMENT_NODES}");
    }

    if not isinstance(edges, `list) {
        errors.append("edges must be a list");
        edges = [];
    } elif len(edges) > MAX_SEMANTIC_FRAGMENT_EDGES {
        errors.append(f"edges has {len(edges)} entries; max is {MAX_SEMANTIC_FRAGMENT_EDGES}");
    }

    i: any;
    for (i, `node) in enumerate(nodes) {
        if not isinstance(`node, `dict) {
            errors.append(f"nodes[{i}] must be an object");
            continue;
        }
        _validate_semantic_id(errors, f"nodes[{i}].id", `node.get("id"));
    }

    for (i, `edge) in enumerate(edges) {
        if not isinstance(`edge, `dict) {
            errors.append(f"edges[{i}] must be an object");
            continue;
        }
        _validate_semantic_id(errors, f"edges[{i}].source", `edge.get("source"));
        _validate_semantic_id(errors, f"edges[{i}].target", `edge.get("target"));
    }

    hyperedges: any = fragment.get("hyperedges", []);
    if hyperedges is None {
        hyperedges = [];
    }
    if not isinstance(hyperedges, `list) {
        errors.append("hyperedges must be a list");
    } else {
        if len(hyperedges) > MAX_SEMANTIC_FRAGMENT_HYPEREDGES {
            errors.append(
                f"hyperedges has {len(hyperedges)} entries; max is {MAX_SEMANTIC_FRAGMENT_HYPEREDGES}",
            );
        }
        for (i, he) in enumerate(hyperedges) {
            if not isinstance(he, `dict) {
                errors.append(f"hyperedges[{i}] must be an object");
                continue;
            }
            _normalize_hyperedge_members(he);
            _validate_semantic_id(errors, f"hyperedges[{i}].id", he.get("id"));
            he_nodes: any = he.get("nodes");
            if not isinstance(he_nodes, `list) {
                errors.append(f"hyperedges[{i}].nodes must be a list");
                continue;
            }
            if len(he_nodes) > MAX_SEMANTIC_HYPEREDGE_NODES {
                errors.append(
                    f"hyperedges[{i}].nodes has {len(he_nodes)} entries; max is {MAX_SEMANTIC_HYPEREDGE_NODES}",
                );
            }
            for (j, ref) in enumerate(he_nodes) {
                _validate_semantic_id(errors, f"hyperedges[{i}].nodes[{j}]", ref);
            }
        }
    }

    return errors;
}

impl load_validated_semantic_fragment(path: Path) -> tuple[dict | None, list[str]] {
    try {
        size: any = path.stat().st_size;
    } except OSError as exc {
        return (None, [f"could not stat {path}: {exc}"]);
    }
    if size > MAX_SEMANTIC_FRAGMENT_BYTES {
        return (None, [f"payload is {size} bytes; max is {MAX_SEMANTIC_FRAGMENT_BYTES}"]);
    }
    try {
        fragment: any = json.loads(path.read_text(encoding="utf-8"));
    } except json.JSONDecodeError as exc {
        return (None, [f"invalid JSON: {exc}"]);
    } except OSError as exc {
        return (None, [f"could not read {path}: {exc}"]);
    }
    errors: any = validate_semantic_fragment(fragment);
    return (None, errors) if errors else (fragment, []);
}

impl _validate_semantic_id(errors: list[str], field: str, value: object) {
    if not isinstance(value, `str) {
        errors.append(f"{field} must be a string");
        return;
    }
    if not value {
        errors.append(f"{field} must not be empty");
        return;
    }
    if len(value) > MAX_SEMANTIC_ID_LENGTH {
        errors.append(f"{field} is {len(value)} chars; max is {MAX_SEMANTIC_ID_LENGTH}");
    }
    if "/" in value or "\\" in value or ".." in value {
        errors.append(f"{field} must not contain path separators or '..'");
    }
    if not _SEMANTIC_ID_RE.fullmatch(value) {
        errors.append(f"{field} contains unsupported characters");
    }
}

impl sanitize_semantic_fragment(fragment: dict) -> dict {
    _invalid_ft: any = frozenset({"rationale", "concept"});

    nodes: list[dict] = fragment.get("nodes", []);
    edges: list[dict] = fragment.get("edges", []);
    hyperedges: list[dict] = fragment.get("hyperedges", []) or [];
    node_by_id: dict[str, dict] = {};
    n: any;
    for n in nodes {
        nid: any = n.get("id", "");
        if nid {
            node_by_id[nid] = n;
        }
    }
    rationale_for_sources: set[str] = set[any]();
    e: any;
    for e in edges {
        if e.get("relation") == "rationale_for" {
            src: any = e.get("source", "");
            if src {
                rationale_for_sources.add(src);
            }
        }
    }
    rationale_candidates: list[dict] = [];
    remove_ids: set[str] = set[any]();
    keep_nodes: list[dict] = [];
    for n in nodes {
        nid = n.get("id", "");
        if not nid {
            continue;
        }
        ft: any = n.get("file_type", "");
        label: any = n.get("label", "");
        if ft in _invalid_ft {
            if _is_sentence_like_rationale_label(label) {
                rationale_candidates.append(n);
            }
            remove_ids.add(nid);
            continue;
        }
        if nid in rationale_for_sources and _is_sentence_like_rationale_label(label) {
            rationale_candidates.append(n);
            remove_ids.add(nid);
            continue;
        }
        keep_nodes.append(n);
    }
    rationale_attrs: dict[str, list[str]] = {};
    for rn in rationale_candidates {
        rn_id: any = rn.get("id", "");
        text: any = rn.get("label", "").strip();
        for e in edges {
            if e.get("relation") != "rationale_for" {
                continue;
            }
            if e.get("source") != rn_id {
                continue;
            }
            target_id: any = e.get("target");
            if target_id not in node_by_id or target_id in remove_ids {
                continue;
            }
            rationale_attrs.setdefault(target_id, []).append(text);
        }
    }

    for (target_id, texts) in rationale_attrs.items() {
        if target_id in node_by_id and target_id not in remove_ids {
            _append_rationale_attr(node_by_id[target_id], texts);
        }
    }
    keep_edges: list[dict] = [];
    for e in edges {
        src = e.get("source", "");
        tgt: any = e.get("target", "");
        if src in remove_ids or tgt in remove_ids {
            continue;
        }
        keep_edges.append(e);
    }
    surviving_ids: set[str] = {n.get("id", "") for n in keep_nodes};
    surviving_ids.discard("");
    keep_hyperedges: list[dict] = [];
    he: any;
    for he in hyperedges {
        if not isinstance(he, `dict) {
            continue;
        }
        _normalize_hyperedge_members(he);
        he_nodes: any = he.get("nodes");
        if not isinstance(he_nodes, `list) {
            continue;
        }
        filtered: any = [ref for ref in he_nodes if isinstance(ref, `str) and ref in surviving_ids];
        if len(filtered) < 2 {
            continue;
        }
        if len(filtered) != len(he_nodes) {
            he = `dict(he);
            he["nodes"] = filtered;
        }
        keep_hyperedges.append(he);
    }

    fragment["nodes"] = keep_nodes;
    fragment["edges"] = keep_edges;
    fragment["hyperedges"] = keep_hyperedges;
    return fragment;
}

impl _is_sentence_like_rationale_label(label: str) -> bool {
    if not label {
        return False;
    }
    label = label.strip();
    if len(label) < _RATIONALE_MIN_CHARS {
        word_count: any = len(label.split());
        if word_count < _RATIONALE_MIN_WORDS {
            return False;
        }
    }
    return `bool(re.search("[.!?:]", label));
}

impl _append_rationale_attr(`node: dict, texts: list[str]) {
    existing: any = `node.get("rationale", "");
    new_text: any = "\n\n".join(texts).strip();
    if existing {
        `node["rationale"] = existing + "\n\n" + new_text;
    } else {
        `node["rationale"] = new_text;
    }
}
