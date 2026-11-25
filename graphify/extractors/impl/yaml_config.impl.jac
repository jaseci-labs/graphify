impl _construct_permissive(loader: Any, tag_suffix: str, `node: Any) -> Any {
    import yaml;
    if isinstance(`node, yaml.ScalarNode) {
        return loader.construct_scalar(`node);
    }
    if isinstance(`node, yaml.SequenceNode) {
        return loader.construct_sequence(`node);
    }
    if isinstance(`node, yaml.MappingNode) {
        return loader.construct_mapping(`node);
    }
    return None;
}

impl _permissive_loader -> Any {
    if _permissive_loader_cls is None {
        import yaml;

        _PermissiveSafeLoader: any = types.new_class("_PermissiveSafeLoader", (yaml.SafeLoader,));
        _PermissiveSafeLoader.add_multi_constructor("!", _construct_permissive);
        _permissive_loader_cls = _PermissiveSafeLoader;
    }
    return _permissive_loader_cls;
}

impl _is_config_yaml(path: Path, data: Any, key_texts: set[str] | None = None) -> bool {
    name: any = path.name.casefold();
    if name in _CONFIG_YAML_NAMES {
        return True;
    }
    if "/.github/workflows/" in path.as_posix().casefold() {
        return True;
    }
    if isinstance(data, `list) {
        return `any(
            isinstance(item, `dict)
                and {"hosts", "tasks", "roles"} & {`str(k).casefold() for k in item}
            for item in data,
        );
    }
    if not isinstance(data, `dict) {
        return False;
    }
    keys: any = key_texts if key_texts is not None else {`str(k).casefold() for k in data.keys()};
    if ("openapi" in keys or "swagger" in keys) and "paths" in keys {
        return False;
    }
    if "$schema" in keys and {"$defs", "definitions", "$id"} & keys {
        return False;
    }
    if keys & _CONFIG_YAML_KEYS {
        return True;
    }
    return `any(isinstance(v, (`dict, `list)) for v in data.values());
}

impl _doc_label(doc: Any, index: int) -> str {
    if isinstance(doc, `dict) {
        kind: any = doc.get("kind");
        if isinstance(kind, `str) and kind {
            meta: any = doc.get("metadata");
            nm: any = meta.get("name") if isinstance(meta, `dict) else None;
            return f"{kind} {nm}" if isinstance(nm, `str) and nm else kind;
        }
    }
    return f"doc {index}";
}

impl _mapping_pairs(`node: Any) -> list[tuple[str, Any, Any]] {
    import yaml;

    merged: list[tuple[str, Any, Any]] = [];
    explicit: list[tuple[str, Any, Any]] = [];
    key_node: any;
    value_node: any;
    for (key_node, value_node) in `node.value {
        if key_node.tag == _MERGE_TAG {
            sources: any = value_node.value
                if isinstance(value_node, yaml.SequenceNode)
                else [value_node];
            for src in reversed(sources) {
                if isinstance(src, yaml.MappingNode) {
                    merged.extend(_mapping_pairs(src));
                }
            }
        } elif isinstance(key_node, yaml.ScalarNode) {
            explicit.append((key_node.value, key_node, value_node));
        }
    }
    pairs: dict[str, tuple[str, Any, Any]] = {};
    for (text, key_node, value_node) in merged + explicit {
        pairs[text] = (text, key_node, value_node);
    }
    return `list(pairs.values());
}

impl extract_yaml(path: Path) -> dict {
    stem: any;
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    pair_count: any;
    try {
        import yaml;
    } except ImportError {
        return {
            "nodes": [],
            "edges": [],
            "error": "pyyaml not installed; install with `pip install pyyaml`",
        };
    }

    try {
        _f: any;
        with path.open("rb") as _f {
            raw: any = _f.read(_YAML_MAX_BYTES + 1);
        }
        if len(raw) > _YAML_MAX_BYTES {
            return {"nodes": [], "edges": [], "error": "yaml file too large to index"};
        }
        text: any = raw.decode("utf-8", errors="ignore");
        docs: any = `list(yaml.load_all(text, Loader=_permissive_loader()));
        trees: any = `list(yaml.compose_all(text, Loader=yaml.SafeLoader));
    } except Exception as exc {
        return {"nodes": [], "edges": [], "error": `str(exc)};
    }

    structured: any = [(d, n) for (d, n) in zip(docs, trees) if isinstance(d, (`dict, `list))];
    if not structured {
        return {"nodes": [], "edges": [], "skipped": "scalar yaml"};
    }

    def _top_keys(tree: Any) -> set[str] | None {
        if isinstance(tree, yaml.MappingNode) {
            return {text.casefold() for (text, _k, _v) in _mapping_pairs(tree)};
        }
        return None;
    }

    config_docs: any = [(d, n) for (d, n) in structured if _is_config_yaml(path, d, _top_keys(n))];
    if not config_docs {
        return {"nodes": [], "edges": [], "skipped": "data yaml (not a config/manifest)"};
    }

    stem = _file_stem(path);
    str_path = `str(path);
    nodes = [];
    edges = [];
    seen_ids = set[any]();

    def add_node(nid: str, label: str, line: int = 1, file_type: str = "code") {
        if nid and nid not in seen_ids {
            seen_ids.add(nid);
            nodes.append({
                "id": nid,
                "label": `str(label),
                "file_type": file_type,
                "source_file": str_path,
                "source_location": f"L{line}",
            });
        }
    }

    def add_edge(src: str, tgt: str, relation: str, line: int = 1, context: str | None = None) {
        if not src or not tgt or src == tgt {
            return;
        }
        `edge: any = {
            "source": src,
            "target": tgt,
            "relation": relation,
            "confidence": "EXTRACTED",
            "source_file": str_path,
            "source_location": f"L{line}",
            "weight": 1.0,
        };
        if context {
            `edge["context"] = context;
        }
        edges.append(`edge);
    }

    file_nid: any = _make_id(`str(path));
    add_node(file_nid, path.name, 1);

    pair_count = [0];

    def walk(`node: Any, parent_nid: str, parent_key: str | None, depth: int) {
        if depth > _MAX_DEPTH {
            return;
        }
        if isinstance(`node, yaml.MappingNode) {
            for (key_str, key_node, val) in _mapping_pairs(`node) {
                if pair_count[0] >= _MAX_PAIRS {
                    return;
                }
                pair_count[0] += 1;
                if not normalize_id(key_str) {
                    continue;
                }
                key_nid: any = _make_id(stem, *(([parent_key] if parent_key else []) + [key_str]));
                if not key_nid {
                    continue;
                }
                line: any = key_node.start_mark.line + 1;
                add_node(key_nid, key_str, line);
                add_edge(parent_nid, key_nid, "contains", line);
                if isinstance(val, (yaml.MappingNode, yaml.SequenceNode)) {
                    walk(val, key_nid, key_str, depth + 1);
                }
            }
        } elif isinstance(`node, yaml.SequenceNode) {
            for item in `node.value {
                if isinstance(item, (yaml.MappingNode, yaml.SequenceNode)) {
                    walk(item, parent_nid, parent_key, depth + 1);
                }
            }
        }
    }

    multi: any = operator.gt(len(config_docs), 1);
    for (index, (doc, tree)) in enumerate(config_docs) {
        if multi {
            label: any = _doc_label(doc, index);
            doc_nid: any = _make_id(stem, f"doc{index}", label) or _make_id(stem, f"doc{index}");
            if not doc_nid {
                continue;
            }
            doc_line: any = tree.start_mark.line + 1;
            add_node(doc_nid, label, doc_line);
            add_edge(file_nid, doc_nid, "contains", doc_line);
            walk(tree, doc_nid, label, 1);
        } else {
            walk(tree, file_nid, None, 0);
        }
    }

    return {"nodes": nodes, "edges": edges};
}
