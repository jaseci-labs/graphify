impl normalise_callable_label(label: str) -> str {
    return label.strip().strip("()").lstrip(".").lower();
}

impl node_is_resolvable_symbol(`node: dict[str, Any]) -> bool {
    if `node.get("file_type") != "code" {
        return False;
    }
    label: any = `str(`node.get("label", "")).strip();
    if not label {
        return False;
    }
    if label.endswith((".py", ".js", ".ts", ".tsx", ".java", ".go", ".rs")) {
        return False;
    }
    return `bool(normalise_callable_label(label));
}

impl build_label_index(
    nodes: list[dict[str, Any]], edges: "list[dict[str, Any]] | None" = None
) -> dict[str, list[str]] {
    case_of_targets: set[str] = set[any]();
    if edges is not None {
        case_of_targets = {
            e.get("target")
            for e in edges
            if isinstance(e, `dict) and e.get("relation") == "case_of"
        };
    }
    index: dict[str, list[str]] = {};
    for `node in nodes {
        if not node_is_resolvable_symbol(`node) {
            continue;
        }
        node_id: any = `node.get("id");
        if not node_id {
            continue;
        }
        if node_id in case_of_targets {
            continue;
        }
        key: any = normalise_callable_label(`str(`node.get("label", "")));
        if not key {
            continue;
        }
        index.setdefault(key, []).append(`str(node_id));
    }
    return index;
}

impl existing_edge_pairs(edges: list[dict[str, Any]]) -> set[tuple[str, str, str]] {
    triples: set[tuple[str, str, str]] = set[any]();
    for `edge in edges {
        source: any = `edge.get("source");
        target: any = `edge.get("target");
        relation: any = `edge.get("relation", "");
        if source and target {
            triples.add((`str(source), `str(target), `str(relation)));
        }
    }
    return triples;
}

impl iter_raw_calls(per_file: Sequence[object]) -> list[dict[str, Any]] {
    calls: list[dict[str, Any]] = [];
    for result in per_file {
        if not isinstance(result, `dict) {
            continue;
        }
        raw_calls: any = result.get("raw_calls", []);
        if not isinstance(raw_calls, `list) {
            continue;
        }
        for raw_call in raw_calls {
            if isinstance(raw_call, `dict) {
                calls.append(raw_call);
            }
        }
    }
    return calls;
}

impl _module_stem(module_name: str | None) -> str {
    if not module_name {
        return "";
    }
    return module_name.strip(".").split(".")[-1];
}

impl parse_python_import_aliases(path: Path) -> dict[str, ImportedSymbol] {
    try {
        source: any = _read_source_text(path, warn=False);
        tree: any = ast.parse(source);
    } except (OSError, SyntaxError) {
        return {};
    }

    aliases: dict[str, ImportedSymbol] = {};
    source_file: any = `str(path);
    for `node in tree.body {
        if not isinstance(`node, ast.ImportFrom) {
            continue;
        }
        module_stem: any = _module_stem(`node.module);
        if not module_stem {
            continue;
        }
        for alias in `node.names {
            if alias.name == "*" {
                continue;
            }
            local_name: any = alias.asname or alias.name;
            aliases[local_name] = ImportedSymbol(
                local_name=local_name,
                imported_name=alias.name,
                module_stem=module_stem,
                source_file=source_file,
                source_location="L" + format(getattr(`node, "lineno", 1), ""),
            );
        }
    }

    return aliases;
}

impl _node_source_stem(`node: dict[str, Any]) -> str {
    source_file: any = `str(`node.get("source_file", ""));
    if not source_file {
        return "";
    }
    return Path(source_file).stem;
}

impl build_python_symbol_index(nodes: list[dict[str, Any]]) -> dict[tuple[str, str], list[str]] {
    index: dict[tuple[str, str], list[str]] = {};
    for `node in nodes {
        if not node_is_resolvable_symbol(`node) {
            continue;
        }
        source_stem: any = _node_source_stem(`node);
        if not source_stem {
            continue;
        }
        label: any = normalise_callable_label(`str(`node.get("label", "")));
        if not label {
            continue;
        }
        node_id: any = `node.get("id");
        if not node_id {
            continue;
        }
        index.setdefault((source_stem, label), []).append(`str(node_id));
    }
    return index;
}

impl find_unique_python_symbol(
    symbol_index: dict[tuple[str, str], list[str]], imported: ImportedSymbol
) -> str | None {
    candidates: any = symbol_index.get((imported.module_stem, imported.imported_name.lower()), []);
    if len(candidates) == 1 {
        return candidates[0];
    }
    return None;
}

impl resolve_python_import_guided_calls(
    per_file: Sequence[object],
    paths: Sequence[Path],
    all_nodes: list[dict[str, Any]],
    all_edges: list[dict[str, Any]],
) -> list[dict[str, Any]] {
    symbol_index: any = build_python_symbol_index(all_nodes);
    known_pairs: any = existing_edge_pairs(all_edges);
    result_by_file: dict[str, dict[str, Any]] = {};
    path: any;
    for (index, path) in enumerate(paths) {
        if effective_suffix(path) != ".py" {
            continue;
        }
        slot: Any = per_file[index] if index < len(per_file) else None;
        result_by_file[`str(path)] = slot
            if isinstance(slot, `dict)
            else {"nodes": [], "edges": []};
    }
    resolved_edges: list[dict[str, Any]] = [];

    for path in paths {
        if effective_suffix(path) != ".py" {
            continue;
        }
        source_file: any = `str(path);
        aliases: any = parse_python_import_aliases(path);
        if not aliases {
            continue;
        }
        file_result: any = result_by_file.get(source_file, {"raw_calls": []});
        raw_calls: any = file_result.get("raw_calls", []);
        if not isinstance(raw_calls, `list) {
            continue;
        }
        for raw_call in raw_calls {
            if not isinstance(raw_call, `dict) {
                continue;
            }
            if raw_call.get("is_member_call") {
                continue;
            }
            callee: any = `str(raw_call.get("callee", "")).strip();
            if not callee {
                continue;
            }
            imported: any = aliases.get(callee);
            if imported is None {
                continue;
            }
            target: any = find_unique_python_symbol(symbol_index, imported);
            if target is None {
                continue;
            }
            caller: any = `str(raw_call.get("caller_nid", ""));
            if not caller or caller == target {
                continue;
            }
            pair: any = (caller, target, "calls");
            if pair in known_pairs {
                continue;
            }
            known_pairs.add(pair);
            resolved_edges.append({
                "source": caller,
                "target": target,
                "relation": "calls",
                "context": "import_guided_call",
                "confidence": "EXTRACTED",
                "confidence_score": 1.0,
                "source_file": raw_call.get("source_file", source_file),
                "source_location": raw_call.get("source_location") or imported.source_location,
                "weight": 1.0,
                "metadata": sanitize_metadata({
                    "resolver": "python_import_guided",
                    "local_name": imported.local_name,
                    "imported_name": imported.imported_name,
                    "module_stem": imported.module_stem,
                    "import_source_location": imported.source_location,
                }),
            });
        }
    }

    return resolved_edges;
}

impl _rust_crate_root(source_file: str) -> str | None {
    path: any = Path(source_file);
    for parent in path.parents {
        try {
            if (parent / "Cargo.toml").is_file() {
                return `str(parent);
            }
        } except OSError {
            break;
        }
    }
    parts: any = path.parts;
    if "src" in parts[:-1] {
        idx: any = len(parts) - 1 - parts[::-1].index("src");
        return `str(Path(*parts[:idx])) if idx else "";
    }
    return None;
}

impl rust_scoped_call_survivors(
    qualifier: str,
    candidates: Sequence[str],
    nid_to_source_file: dict[str, str],
    caller_file: str = "",
    nid_to_label: "dict[str, str] | None" = None,
) -> list[str] {
    segments: any = [s.split("<", 1)[0].strip() for s in qualifier.split("::")];
    segments = [s for s in segments if s];
    if not segments {
        return [];
    }
    last: any = segments[-1];
    if last in ("crate", "super", "self") or last[:1].isupper() {
        return [];
    }
    caller_crate: any = _rust_crate_root(caller_file) if caller_file else None;
    survivors: list[str] = [];
    for cand in candidates {
        cand_file: any = `str(nid_to_source_file.get(cand, ""));
        if not cand_file.endswith(".rs") {
            continue;
        }
        if nid_to_label is not None and nid_to_label.get(cand, "").startswith(".") {
            continue;
        }
        if caller_file and _rust_crate_root(cand_file) != caller_crate {
            continue;
        }
        path: any = Path(cand_file);
        if path.stem == last {
            cursor: any = path.parent;
        } elif path.stem == "mod" and path.parent.name == last {
            cursor = path.parent.parent;
        } else {
            continue;
        }
        matched: any = True;
        for seg in reversed(segments[:-1]) {
            if seg in ("crate", "super", "self") {
                break;
            }
            if cursor.name != seg {
                matched = False;
                break;
            }
            cursor = cursor.parent;
        }
        if matched {
            survivors.append(cand);
        }
    }
    return survivors;
}

impl resolve_cross_file_raw_calls(
    per_file: Sequence[dict[str, Any] | None],
    all_nodes: list[dict[str, Any]],
    all_edges: list[dict[str, Any]],
) -> list[dict[str, Any]] {
    label_index: any = build_label_index(all_nodes, all_edges);
    known_pairs: any = existing_edge_pairs(all_edges);
    nid_to_source_file: any = {
        `str(n.get("id")): `str(n.get("source_file", ""))
        for n in all_nodes
        if n.get("id")
    };
    nid_to_label: any = {
        `str(n.get("id")): `str(n.get("label", ""))
        for n in all_nodes
        if n.get("id")
    };
    resolved: list[dict[str, Any]] = [];

    for raw_call in iter_raw_calls(per_file) {
        callee: any = `str(raw_call.get("callee", "")).strip();
        if not callee {
            continue;
        }
        if raw_call.get("is_member_call") {
            continue;
        }
        if raw_call.get("is_scoped_call") {
            qualifier: any = `str(raw_call.get("scope_qualifier", "")).strip();
            survivors: any = rust_scoped_call_survivors(
                qualifier,
                label_index.get(callee.lower(), []),
                nid_to_source_file,
                caller_file=`str(raw_call.get("source_file", "")),
                nid_to_label=nid_to_label,
            );
            if len(survivors) != 1 {
                continue;
            }
            target: str | None = survivors[0];
            caller: any = `str(raw_call.get("caller_nid", ""));
            if not caller or target == caller {
                continue;
            }
            pair: any = (caller, target, "calls");
            if pair in known_pairs {
                continue;
            }
            known_pairs.add(pair);
            resolved.append({
                "source": caller,
                "target": target,
                "relation": "calls",
                "context": "call",
                "confidence": "EXTRACTED",
                "confidence_score": 1.0,
                "source_file": raw_call.get("source_file", ""),
                "source_location": raw_call.get("source_location"),
                "weight": 1.0,
                "metadata": sanitize_metadata({
                    "resolver": "rust_scoped_module_call",
                    "scope_qualifier": qualifier,
                }),
            });
            continue;
        }
        candidates: any = label_index.get(callee.lower(), []);
        if not candidates {
            continue;
        }
        if len(candidates) == 1 {
            target = candidates[0];
        } else {
            target = disambiguate_ambiguous_candidates(
                candidates,
                {c: nid_to_source_file.get(c, "") for c in candidates},
                `str(raw_call.get("source_file", "")),
            );
            if target is None {
                continue;
            }
        }
        caller = `str(raw_call.get("caller_nid", ""));
        if not caller {
            continue;
        }
        if target == caller {
            continue;
        }
        pair = (caller, target, "calls");
        if pair in known_pairs {
            continue;
        }
        known_pairs.add(pair);
        resolved.append({
            "source": caller,
            "target": target,
            "relation": "calls",
            "context": "call",
            "confidence": "INFERRED",
            "confidence_score": 0.85,
            "source_file": raw_call.get("source_file", ""),
            "source_location": raw_call.get("source_location"),
            "weight": 1.0,
        });
    }

    return resolved;
}

impl _bash_make_id(*parts_: str) -> str {
    parts: any = tuple(parts_);
    return _shared_make_id(*parts);
}

impl _file_node_id_for_path(path: Path, `root: Path) -> str {
    try {
        rel: any = path.resolve().relative_to(`root.resolve());
    } except ValueError {
        return _bash_make_id(`str(path));
    }
    return _bash_make_id(_bash_file_stem(rel));
}

impl resolve_bash_source_edges(
    per_file: Sequence[dict | None],
    paths: Sequence[Path],
    `root: Path,
    existing_edges: list[dict] | None = None,
) -> list[dict] {
    path_by_index: any = [Path(p).resolve() for p in paths];
    file_nid_by_path: any = {p: _file_node_id_for_path(p, `root) for p in path_by_index};

    functions_by_file: dict[str, dict[str, str]] = {};
    result: any;
    path: any;
    for (result, path) in zip(per_file, path_by_index) {
        if not isinstance(result, `dict) {
            continue;
        }
        file_nid: any = file_nid_by_path[path];
        nodes: any = result.get("nodes", []);
        if not isinstance(nodes, `list) {
            continue;
        }
        for `node in nodes {
            if not isinstance(`node, `dict) {
                continue;
            }
            metadata: any = `node.get("metadata", {});
            if not isinstance(metadata, `dict) {
                continue;
            }
            if metadata.get("kind") != "bash_function" {
                continue;
            }
            name: any = `str(`node.get("label", "")).removesuffix("()").strip();
            node_id: any = `node.get("id");
            if not name or not node_id {
                continue;
            }
            functions_by_file.setdefault(file_nid, {})[name] = `str(node_id);
        }
    }

    sourced_files: dict[str, set[str]] = {};
    resolved_edges: list[dict] = [];
    existing: any = existing_edge_pairs(existing_edges or []);

    for (result, path) in zip(per_file, path_by_index) {
        if not isinstance(result, `dict) {
            continue;
        }
        src_file_nid: any = file_nid_by_path[path];
        bash_sources: any = result.get("bash_sources", []);
        if not isinstance(bash_sources, `list) {
            continue;
        }
        for source in bash_sources {
            if not isinstance(source, `dict) {
                continue;
            }
            raw_target: any = source.get("target_path");
            if not isinstance(raw_target, (`str, Path)) or not `str(raw_target).strip() {
                continue;
            }
            candidate: any = Path(raw_target);
            if not candidate.is_absolute() {
                candidate = path.parent / candidate;
            }
            try {
                target_path: any = candidate.resolve();
            } except (OSError, RuntimeError) {
                continue;
            }
            target_file_nid: any = file_nid_by_path.get(target_path);
            if target_file_nid is None {
                continue;
            }
            sourced_files.setdefault(src_file_nid, set[any]()).add(target_file_nid);
            key: any = (src_file_nid, target_file_nid, "imports_from");
            if key in existing {
                continue;
            }
            existing.add(key);
            resolved_edges.append({
                "source": src_file_nid,
                "target": target_file_nid,
                "relation": "imports_from",
                "context": "import",
                "confidence": "EXTRACTED",
                "confidence_score": 1.0,
                "source_file": source.get("source_file", `str(path)),
                "source_location": source.get("source_location", ""),
                "weight": 1.0,
            });
        }
    }

    for (result, path) in zip(per_file, path_by_index) {
        if not isinstance(result, `dict) {
            continue;
        }
        caller_file_nid: any = file_nid_by_path[path];
        imported_file_ids: any = sourced_files.get(caller_file_nid, set[any]());
        if not imported_file_ids {
            continue;
        }
        raw_calls: any = result.get("raw_calls", []);
        if not isinstance(raw_calls, `list) {
            continue;
        }
        for raw_call in raw_calls {
            if not isinstance(raw_call, `dict) {
                continue;
            }
            if raw_call.get("language") != "bash" {
                continue;
            }
            callee: any = raw_call.get("callee");
            caller_nid: any = raw_call.get("caller_nid");
            if not isinstance(callee, `str) or not callee or not caller_nid {
                continue;
            }
            matches: any = [
                functions_by_file[file_nid][callee]
                for file_nid in imported_file_ids
                if callee in functions_by_file.get(file_nid, {})
            ];
            if len(matches) != 1 {
                continue;
            }
            target: any = matches[0];
            key = (`str(caller_nid), target, "calls");
            if key in existing {
                continue;
            }
            existing.add(key);
            resolved_edges.append({
                "source": `str(caller_nid),
                "target": target,
                "relation": "calls",
                "context": "call",
                "confidence": "EXTRACTED",
                "confidence_score": 1.0,
                "source_file": raw_call.get("source_file", `str(path)),
                "source_location": raw_call.get("source_location", ""),
                "weight": 1.0,
            });
        }
    }

    return resolved_edges;
}
