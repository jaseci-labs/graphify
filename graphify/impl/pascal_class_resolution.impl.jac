impl _is_pascal(source_file: object) -> bool {
    return isinstance(source_file, `str) and source_file.lower().endswith(_PASCAL_SUFFIXES);
}

impl resolve_pascal_base_classes(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) {
    node_by_id: any;
    imports_of: dict[str, set[str]];
    by_name: dict[str, list[str]];
    node_by_id = {n.get("id"): n for n in all_nodes};
    declared_ids: set[str] = set[any]();
    imports_of = {};
    `edge: any;
    for `edge in all_edges {
        relation: any = `edge.get("relation");
        if relation == "contains" {
            declared_ids.add(`edge.get("target"));
        } elif relation == "imports" {
            source: any = node_by_id.get(`edge.get("source"), {}).get("source_file");
            target: any = node_by_id.get(`edge.get("target"), {}).get("source_file");
            if isinstance(source, `str) and isinstance(target, `str) {
                imports_of.setdefault(source, set[any]()).add(target);
            }
        }
    }
    by_name = {};
    for `node in all_nodes {
        nid: any = `node.get("id");
        if nid not in declared_ids or not _is_pascal(`node.get("source_file")) {
            continue;
        }
        label: any = `str(`node.get("label", ""));
        if label.endswith("()") or not label {
            continue;
        }
        by_name.setdefault(label.lower(), []).append(nid);
    }
    if not by_name {
        return;
    }
    def _declaration_for(name: str, from_file: object) -> str | None {
        candidates: any = by_name.get(name.lower());
        if not candidates {
            return None;
        }
        if len(candidates) == 1 {
            return candidates[0];
        }
        visible: any = imports_of.get(from_file, set[any]())
            if isinstance(from_file, `str)
            else set[any]();
        scoped: any = [
            nid
            for nid in candidates
            if node_by_id.get(nid, {}).get("source_file") in visible
        ];
        return scoped[0] if len(scoped) == 1 else None;
    }
    existing_pairs: any = {
        (e.get("source"), e.get("target"))
        for e in all_edges
        if e.get("relation") == "inherits"
    };
    for `edge in all_edges {
        if `edge.get("relation") != "inherits" {
            continue;
        }
        target_id: any = `edge.get("target");
        if target_id in declared_ids {
            continue;
        }
        stub: any = node_by_id.get(target_id);
        source = node_by_id.get(`edge.get("source"));
        if stub is None or source is None or not _is_pascal(source.get("source_file")) {
            continue;
        }
        declaration: any = _declaration_for(`str(stub.get("label", "")), source.get("source_file"));
        if declaration is None or declaration == `edge.get("source") {
            continue;
        }
        pair: any = (`edge.get("source"), declaration);
        if pair in existing_pairs {
            continue;
        }
        existing_pairs.add(pair);
        `edge["target"] = declaration;
    }
}
