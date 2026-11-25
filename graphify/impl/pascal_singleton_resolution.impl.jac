impl _is_pascal(source_file: object) -> bool {
    return isinstance(source_file, `str) and source_file.lower().endswith(_PASCAL_SUFFIXES);
}

impl _basename(path: str) -> str {
    return os.path.basename(path.replace("\\", "/"));
}

impl _unit_stem(source_file: str) -> str {
    return _basename(source_file).rsplit(".", 1)[0].lower();
}

impl _raw_path_of(result: dict) -> str | None {
    for `node in result.get("nodes", []) {
        if isinstance(`node, `dict) {
            source_file: any = `node.get("source_file");
            if isinstance(source_file, `str) and source_file {
                return source_file;
            }
        }
    }
    for raw_call in result.get("raw_calls", []) {
        if isinstance(raw_call, `dict) {
            source_file = raw_call.get("source_file");
            if isinstance(source_file, `str) and source_file {
                return source_file;
            }
        }
    }
    return None;
}

impl _corpus_path_matcher(corpus_files: set[str]) -> any {
    by_name: dict[str, list[str]];
    by_name = {};
    for source_file in corpus_files {
        by_name.setdefault(_basename(source_file).lower(), []).append(source_file);
    }

    def `match(raw_path: str) -> str | None {
        candidates: any = by_name.get(_basename(raw_path).lower());
        if not candidates {
            return None;
        }
        if len(candidates) == 1 {
            return candidates[0];
        }
        normalised: any = raw_path.replace("\\", "/").lower();
        tails: any = [
            c
            for c in candidates
            if normalised.endswith("/" + c.replace("\\", "/").lower())
        ];
        return tails[0] if len(tails) == 1 else None;
    }

    return `match;
}

impl resolve_pascal_singleton_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) {
    node_by_id: any;
    globals_of: dict[str, dict[str, str]];
    uses_of: dict[str, set[str]];
    methods_of: dict[str, dict[str, set[str]]];
    bases_of: dict[str, list[str]];
    candidates: any;
    types_by_name: dict[str, list[str]];
    node_by_id = {n.get("id"): n for n in all_nodes};
    corpus_files: set[str] = set[any]();
    files_by_stem: dict[str, list[str]] = {};
    `node: any;
    for `node in all_nodes {
        source_file: any = `node.get("source_file");
        if _is_pascal(source_file) and source_file not in corpus_files {
            corpus_files.add(`str(source_file));
            files_by_stem.setdefault(_unit_stem(`str(source_file)), []).append(`str(source_file));
        }
    }
    if not corpus_files {
        return;
    }
    file_by_unit_id: dict[str, str] = {
        _make_id(stem): candidates[0]
        for (stem, candidates) in files_by_stem.items()
        if len(candidates) == 1
    };
    to_corpus_path: any = _corpus_path_matcher(corpus_files);
    globals_of = {};
    result: any;
    for result in per_file {
        if not isinstance(result, `dict) {
            continue;
        }
        declared: any = result.get("global_vars");
        if not isinstance(declared, `dict) or not declared {
            continue;
        }
        raw_path: any = _raw_path_of(result);
        source_file = to_corpus_path(raw_path) if raw_path else None;
        if source_file is not None {
            globals_of.setdefault(source_file, {}).update(declared);
        }
    }
    if not globals_of {
        return;
    }

    declared_ids: set[str] = set[any]();
    uses_of = {};
    methods_of = {};
    bases_of = {};
    for `edge in all_edges {
        relation: any = `edge.get("relation");
        if relation == "contains" {
            declared_ids.add(`edge.get("target"));
        } elif relation == "imports" {
            source_file = node_by_id.get(`edge.get("source"), {}).get("source_file");
            if not _is_pascal(source_file) {
                continue;
            }
            target_node: any = node_by_id.get(`edge.get("target"), {});
            target_file: any = target_node.get("source_file");
            if _is_pascal(target_file) {
                uses_of.setdefault(`str(source_file), set[any]()).add(`str(target_file));
                continue;
            }
            used: any = file_by_unit_id.get(`str(`edge.get("target")));
            if used is None {
                label: any = `str(target_node.get("label", ""));
                candidates = files_by_stem.get(_unit_stem(label)) if label else None;
                used = candidates[0] if candidates and len(candidates) == 1 else None;
            }
            if used is not None and used != source_file {
                uses_of.setdefault(`str(source_file), set[any]()).add(used);
            }
        } elif relation == "method" {
            method_node: any = node_by_id.get(`edge.get("target"));
            if method_node is None {
                continue;
            }
            name: any = `str(method_node.get("label", "")).removesuffix("()").lower();
            methods_of.setdefault(`edge.get("source"), {}).setdefault(name, set[any]()).add(
                `edge.get("target")
            );
        } elif relation == "inherits" {
            bases_of.setdefault(`edge.get("source"), []).append(`edge.get("target"));
        }
    }

    types_by_name = {};
    for `node in all_nodes {
        nid: any = `node.get("id");
        if nid not in declared_ids or not _is_pascal(`node.get("source_file")) {
            continue;
        }
        label = `str(`node.get("label", ""));
        if not label or label.endswith("()") {
            continue;
        }
        types_by_name.setdefault(label.lower(), []).append(nid);
    }
    if not types_by_name {
        return;
    }
    def _visible_type(qualifier: str, from_file: str) -> str | None {
        found: set[str] = set[any]();
        for unit in (from_file, *uses_of.get(from_file, ())) {
            type_name: any = globals_of.get(unit, {}).get(qualifier);
            if type_name {
                found.add(type_name);
            }
        }
        return found.pop() if len(found) == 1 else None;
    }

    def _class_for(type_name: str, from_file: str) -> str | None {
        candidates: any = types_by_name.get(type_name);
        if not candidates {
            return None;
        }
        if len(candidates) == 1 {
            return candidates[0];
        }
        visible: any = uses_of.get(from_file, set[any]());
        scoped: any = [
            nid
            for nid in candidates
            if node_by_id.get(nid, {}).get("source_file") in visible
        ];
        return scoped[0] if len(scoped) == 1 else None;
    }
    def _method_for(class_nid: str, name: str) -> str | None {
        seen: set[str] = set[any]();
        queue: any = [class_nid];
        while queue {
            current: any = queue.pop(0);
            if current in seen {
                continue;
            }
            seen.add(current);
            candidates: any = methods_of.get(current, {}).get(name);
            if candidates {
                return next(iter(candidates)) if len(candidates) == 1 else None;
            }
            queue.extend(bases_of.get(current, []));
        }
        return None;
    }

    existing_pairs: any = {
        (e.get("source"), e.get("target"))
        for e in all_edges
        if e.get("relation") == "calls"
    };
    for result in per_file {
        if not isinstance(result, `dict) {
            continue;
        }
        for raw_call in result.get("raw_calls", []) {
            if not isinstance(raw_call, `dict) {
                continue;
            }
            qualifier: any = raw_call.get("qualifier");
            caller: any = raw_call.get("caller_nid");
            callee: any = raw_call.get("callee");
            if not qualifier or not caller or not callee {
                continue;
            }
            caller_node: any = node_by_id.get(caller);
            if caller_node is None {
                continue;
            }
            source_file = caller_node.get("source_file");
            if not _is_pascal(source_file) {
                continue;
            }
            type_name: any = _visible_type(`str(qualifier), `str(source_file));
            if not type_name {
                continue;
            }
            class_nid: any = _class_for(type_name, `str(source_file));
            if class_nid is None {
                continue;
            }
            target: any = _method_for(class_nid, `str(callee));
            if not target or target == caller {
                continue;
            }
            pair: any = (caller, target);
            if pair in existing_pairs {
                continue;
            }
            existing_pairs.add(pair);
            all_edges.append({
                "source": caller,
                "target": target,
                "relation": "calls",
                "context": "global object call",
                "confidence": "EXTRACTED",
                "confidence_score": 1.0,
                "source_file": source_file,
                "source_location": raw_call.get("source_location"),
                "weight": 1.0,
            });
        }
    }
}
