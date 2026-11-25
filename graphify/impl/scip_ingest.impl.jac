impl ingest_scip_json(
    doc: object, source_file: str = "", language: str = "python"
) -> dict[str, Any] {
    nodes: list[dict[str, Any]] = [];
    edges: list[dict[str, Any]] = [];
    seen_node_ids: set[str] = set[any]();
    seen_edges: set[tuple[str, str, str, str | None]] = set[any]();

    if not isinstance(doc, `dict) {
        return {"nodes": nodes, "edges": edges};
    }

    documents: any = doc.get("documents", []);
    if not isinstance(documents, `list) {
        return {"nodes": nodes, "edges": edges};
    }
    per_doc_index: dict[tuple[str, str], str] = {};
    global_index: dict[str, list[str]] = {};
    symbol_records: list[dict[str, Any]] = [];
    for document in documents {
        if not isinstance(document, `dict) {
            continue;
        }
        doc_path: any = _coerce_str(document.get("relative_path"), source_file);
        doc_language: any = _coerce_str(document.get("language"), language);
        symbols: any = document.get("symbols", []);
        if not isinstance(symbols, `list) {
            continue;
        }
        for symbol in symbols {
            if not isinstance(symbol, `dict) {
                continue;
            }
            symbol_id: any = _coerce_str(symbol.get("symbol"), "");
            if not symbol_id {
                continue;
            }
            node_id: any = _make_scip_node_id(symbol_id, doc_path);
            per_doc_index.setdefault((symbol_id, doc_path), node_id);
            candidates: any = global_index.setdefault(symbol_id, []);
            if node_id not in candidates {
                candidates.append(node_id);
            }
            symbol_records.append({
                "node_id": node_id,
                "symbol_id": symbol_id,
                "doc_path": doc_path,
                "language": doc_language,
                "raw": symbol,
            });
        }
    }
    for record in symbol_records {
        _emit_symbol_node(record, nodes, seen_node_ids);
        _emit_relationships(
            record, per_doc_index, global_index, nodes, edges, seen_node_ids, seen_edges
        );
    }

    return {"nodes": nodes, "edges": edges};
}

impl _emit_symbol_node(
    record: dict[str, Any], nodes: list[dict[str, Any]], seen_node_ids: set[str]
) {
    node_id: any = record["node_id"];
    if node_id in seen_node_ids {
        return;
    }
    raw: any = record["raw"];
    symbol_id: any = record["symbol_id"];
    doc_path: any = record["doc_path"];
    kind: any = _coerce_str(raw.get("kind"), "unknown");
    display_name: any = _coerce_str(raw.get("display_name"), "");
    documentation: any = raw.get("documentation", []);
    description: any = "";
    if isinstance(documentation, `list) and documentation {
        first: any = documentation[0];
        if isinstance(first, `str) {
            description = first;
        }
    }
    occurrences: any = raw.get("occurrences", []);
    sourceline: any = _first_occurrence_line(occurrences);
    suffix: any = symbol_id.split("#")[-1] if "#" in symbol_id else symbol_id;
    label: any = display_name or suffix or symbol_id;
    seen_node_ids.add(node_id);
    nodes.append({
        "id": node_id,
        "label": label,
        "file_type": _scip_kind_to_file_type(kind),
        "source_file": doc_path,
        "source_location": f"L{sourceline}" if sourceline else "",
        "metadata": sanitize_metadata(_build_scip_metadata(symbol_id, kind, description)),
    });
}

impl _emit_relationships(
    record: dict[str, Any],
    per_doc_index: dict[tuple[str, str], str],
    global_index: dict[str, list[str]],
    nodes: list[dict[str, Any]],
    edges: list[dict[str, Any]],
    seen_node_ids: set[str],
    seen_edges: set[tuple[str, str, str, str | None]],
) {
    raw: any = record["raw"];
    source_node_id: any = record["node_id"];
    doc_path: any = record["doc_path"];
    occurrences: any = raw.get("occurrences", []);
    sourceline: any = _first_occurrence_line(occurrences);
    relationships: any = raw.get("relationships");
    if not isinstance(relationships, `list) {
        return;
    }
    for rel in relationships {
        if not isinstance(rel, `dict) {
            continue;
        }
        target_symbol: any = _coerce_str(rel.get("symbol"), "");
        if not target_symbol {
            continue;
        }
        target_node_id: any = _resolve_relationship_target(
            target_symbol, doc_path, per_doc_index, global_index
        );
        if target_node_id is None {
            target_node_id = _make_scip_node_id(target_symbol, doc_path);
            if target_node_id not in seen_node_ids {
                seen_node_ids.add(target_node_id);
                suffix: any = target_symbol.split("#")[-1]
                    if "#" in target_symbol
                    else target_symbol;
                nodes.append({
                    "id": target_node_id,
                    "label": suffix or target_symbol,
                    "file_type": "code",
                    "source_file": doc_path,
                    "source_location": "",
                    "metadata": sanitize_metadata(
                        _build_scip_metadata(target_symbol, "external", "")
                    ),
                });
            }
        }
        relation: any = _scip_relation_for(rel);
        source_location: any = f"L{sourceline}" if sourceline else "";
        key: any = (source_node_id, target_node_id, relation, source_location);
        if key in seen_edges {
            continue;
        }
        seen_edges.add(key);
        edges.append({
            "source": source_node_id,
            "target": target_node_id,
            "relation": relation,
            "confidence": "EXTRACTED",
            "confidence_score": 1.0,
            "source_file": doc_path,
            "source_location": source_location,
            "weight": 1.0,
            "context": "scip",
            "metadata": sanitize_metadata({"scip_relationship": rel}),
        });
    }
}

impl _resolve_relationship_target(
    target_symbol: str,
    source_doc_path: str,
    per_doc_index: dict[tuple[str, str], str],
    global_index: dict[str, list[str]],
) -> str | None {
    same_doc: any = per_doc_index.get((target_symbol, source_doc_path));
    if same_doc is not None {
        return same_doc;
    }
    candidates: any = global_index.get(target_symbol, []);
    if len(candidates) == 1 {
        return candidates[0];
    }
    return None;
}

impl _is_true(value: object) -> bool {
    return value is True;
}

impl _scip_relation_for(rel: dict[str, Any]) -> str {
    if _is_true(rel.get("is_implementation")) {
        return "scip_impl";
    }
    if _is_true(rel.get("is_type_definition")) {
        return "scip_typed";
    }
    if _is_true(rel.get("is_definition")) {
        return "scip_def";
    }
    return "scip_ref";
}

impl _first_occurrence_line(occurrences: object) -> int {
    if not isinstance(occurrences, `list) or not occurrences {
        return 0;
    }
    first: any = occurrences[0];
    if not isinstance(first, `dict) {
        return 0;
    }
    rng: any = first.get("range", []);
    if not isinstance(rng, `list) or len(rng) < 1 {
        return 0;
    }
    line: any = rng[0];
    if isinstance(line, `bool) or not isinstance(line, `int) or line < 0 {
        return 0;
    }
    return line;
}

impl _coerce_str(value: object, `default: str) -> str {
    if isinstance(value, `str) {
        return value;
    }
    if isinstance(`default, `str) {
        return `default;
    }
    return "";
}

impl _make_scip_node_id(symbol: str, source_file: str) -> str {
    raw: any = f"{source_file}:{symbol}";
    h: any = hashlib.sha1(raw.encode(), usedforsecurity=False).hexdigest()[:12];
    parts: any = symbol.split("#");
    suffix: any = parts[-1] if parts else symbol;
    suffix = re.sub("[^a-zA-Z0-9_]", "_", suffix).strip("_").lower();
    if suffix {
        return f"scip_{suffix}_{h}";
    }
    return f"scip_{h}";
}

impl _scip_kind_to_file_type(kind: str) -> str {
    _: any = kind;
    return "code";
}

impl _build_scip_metadata(symbol_id: str, kind: str, description: str) -> dict[str, str] {
    meta: dict[str, str] = {"scip_symbol": symbol_id, "scip_kind": kind};
    if description {
        meta["scip_description"] = description;
    }
    return meta;
}
