impl _sibling_unit_files(form_file: str, known_files: set[str]) -> list[str] {
    lowered: any = form_file.lower();
    for (form_suffix, unit_suffixes) in _FORM_SUFFIX_UNITS.items() {
        if not lowered.endswith(form_suffix) {
            continue;
        }
        base: any = form_file[:-len(form_suffix)];
        return [base + s for s in unit_suffixes if base + s in known_files];
    }
    return [];
}

impl _method_name(label: str) -> str {
    return `str(label).removesuffix("()").strip().lower();
}

impl resolve_dfm_handlers(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None {
    existing_pairs: any;
    nodes_by_file: dict[str, list[dict]] = {};
    `node: any;
    for `node in all_nodes {
        source_file: any = `node.get("source_file");
        if isinstance(source_file, `str) and source_file {
            nodes_by_file.setdefault(source_file, []).append(`node);
        }
    }
    if not nodes_by_file {
        return;
    }
    node_by_id: any = {n.get("id"): n for n in all_nodes};
    methods_of: dict[str, dict[str, list[str]]] = {};
    for `edge in all_edges {
        if `edge.get("relation") != "method" {
            continue;
        }
        owner: any;
        method_nid: any;
        (owner, method_nid) = (`edge.get("source"), `edge.get("target"));
        method_node: any = node_by_id.get(method_nid);
        if not owner or method_node is None {
            continue;
        }
        bucket: any = methods_of.setdefault(owner, {}).setdefault(
            _method_name(method_node.get("label", "")), []
        );
        if method_nid not in bucket {
            bucket.append(method_nid);
        }
    }

    known_files: any = `set(nodes_by_file);
    existing_pairs = {(e.get("source"), e.get("target")) for e in all_edges};

    def _emit(source: str, target: str, context: str, form_file: str, location) -> None {
        pair: any = (source, target);
        if source == target or pair in existing_pairs {
            return;
        }
        existing_pairs.add(pair);
        all_edges.append({
            "source": source,
            "target": target,
            "relation": "references",
            "context": context,
            "confidence": "INFERRED",
            "confidence_score": 0.85,
            "source_file": form_file,
            "source_location": location,
            "weight": 1.0,
        });
    }

    for (form_file, form_nodes) in nodes_by_file.items() {
        unit_files: any = _sibling_unit_files(form_file, known_files);
        if not unit_files {
            continue;
        }
        unit_classes: dict[str, list[str]] = {};
        for unit_file in unit_files {
            for `node in nodes_by_file.get(unit_file, []) {
                nid: any = `node.get("id");
                if nid in methods_of {
                    unit_classes.setdefault(
                        `str(`node.get("label", "")).strip().lower(), []
                    ).append(nid);
                }
            }
        }
        matched_classes: list[str] = [];
        for `node in form_nodes {
            label: any = `str(`node.get("label", ""));
            if label.endswith("()") {
                continue;
            }
            candidates: any = unit_classes.get(label.strip().lower(), []);
            if len(candidates) != 1 {
                continue;
            }
            matched_classes.append(candidates[0]);
            _emit(
                `str(`node.get("id")),
                candidates[0],
                "form class",
                form_file,
                `node.get("source_location"),
            );
        }
        if not matched_classes {
            continue;
        }
        for `node in form_nodes {
            label = `str(`node.get("label", ""));
            if not label.endswith("()") {
                continue;
            }
            name: any = _method_name(label);
            targets: list[str] = [];
            for class_nid in matched_classes {
                for method_nid in methods_of.get(class_nid, {}).get(name, []) {
                    if method_nid not in targets {
                        targets.append(method_nid);
                    }
                }
            }
            if len(targets) != 1 {
                continue;
            }
            _emit(
                `str(`node.get("id")),
                targets[0],
                "event impl",
                form_file,
                `node.get("source_location"),
            );
        }
    }
}
