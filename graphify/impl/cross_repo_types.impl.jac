impl link_shared_type_declarations(merged: "nx.Graph") -> int {
    by_declaration: dict[tuple[str, str], list[str]] = defaultdict(list[any]);
    for (`node, data) in merged.nodes(data=True) {
        if not data.get("_callable_class") or not data.get("source_file") {
            continue;
        }
        namespace: any = `str((data.get("metadata") or {}).get("namespace") or "");
        label: any = `str(data.get("label") or "");
        if not namespace or not label or not data.get("repo") {
            continue;
        }
        by_declaration[namespace, label].append(`node);
    }

    added: any = 0;
    for ((namespace, label), nodes) in by_declaration.items() {
        if len(nodes) < 2 {
            continue;
        }
        if len({merged.nodes[n].get("repo") for n in nodes}) < 2 {
            continue;
        }
        for (index, left) in enumerate(nodes) {
            for right in nodes[index + 1:] {
                if merged.nodes[left].get("repo") == merged.nodes[right].get("repo") {
                    continue;
                }
                if merged.has_edge(left, right) {
                    continue;
                }
                merged.add_edge(
                    left,
                    right,
                    relation=SHARED_TYPE_RELATION,
                    context="cross_repo",
                    confidence="INFERRED",
                    confidence_score=0.85,
                    source_file=`str(merged.nodes[left].get("source_file") or ""),
                    weight=1.0,
                    _src=left,
                    _tgt=right,
                );
                added += 1;
            }
        }
    }
    return added;
}
