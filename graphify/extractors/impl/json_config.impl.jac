impl _local_extends_target(config: Path, ref: str) -> "Path | None" {
    if not (ref.startswith(("./", "../")) or os.path.isabs(ref)) {
        return None;
    }
    cand: any = Path(os.path.normpath(config.parent / ref));
    if cand.is_file() {
        return cand;
    }
    if not ref.endswith(".json") {
        with_json: any = cand.with_name(cand.name + ".json");
        if with_json.is_file() {
            return with_json;
        }
    }
    return None;
}

impl _paths_base(config: Path) -> "Path | None" {
    seen: set[str] = set[any]();
    current: any = config;
    while `str(current) not in seen {
        seen.add(`str(current));
        data: any = _read_json_config(current) or {};
        opts: any = data.get("compilerOptions");
        base: any = opts.get("baseUrl") if isinstance(opts, `dict) else None;
        if isinstance(base, `str) and base {
            return Path(os.path.normpath(current.parent / base));
        }
        ext: any = data.get("extends");
        if not ext {
            return config.parent;
        }
        if isinstance(ext, `list) {
            ext = next((e for e in reversed(ext) if isinstance(e, `str)), None);
        } elif not isinstance(ext, `str) {
            ext = None;
        }
        nxt: any = _local_extends_target(current, ext) if ext else None;
        if nxt is None {
            return None;
        }
        current = nxt;
    }
    return None;
}

impl _is_config_json(path: Path, obj_node, source: bytes) -> bool {
    name: any = path.name.casefold();
    if name in _CONFIG_JSON_NAMES {
        return True;
    }
    if name.endswith((
        ".eslintrc.json",
        ".prettierrc.json",
        ".babelrc.json",
        "tsconfig.json",
        "jsconfig.json",
    )) {
        return True;
    }
    root_keys: set[str] = set[any]();
    for top_key in obj_node.children {
        if top_key.type != "pair" {
            continue;
        }
        key_node: any = top_key.child_by_field_name("key");
        if key_node is None {
            continue;
        }
        kc: any = key_node.child_by_field_name("string_content");
        root_keys.add(_read_text(kc, source) if kc else _read_text(key_node, source).strip("\"'"));
    }
    if "$schema" in root_keys and root_keys & _SCHEMA_DEFINITION_KEYS {
        return False;
    }
    if root_keys & _CONFIG_JSON_KEYS {
        return True;
    }
    return False;
}

impl extract_json(path: Path) -> dict {
    source: any;
    stem: any;
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    _DEP_KEYS: any;
    _base_memo: list;
    file_nid: any;
    _JSON_MAX_BYTES: any = 1048576;

    try {
        import tree_sitter_json as tsjson;
        import from tree_sitter { Language, Parser }
    } except ImportError {
        return {"nodes": [], "edges": [], "error": "tree-sitter-json not installed"};
    }

    try {
        _f: any;
        with path.open("rb") as _f {
            source = _f.read(_JSON_MAX_BYTES + 1);
        }
        if len(source) > _JSON_MAX_BYTES {
            return {"nodes": [], "edges": [], "skipped": "json file over 1 MiB (not indexed)"};
        }
        language: any = Language(tsjson.language());
        parser: any = Parser(language);
        tree: any = parser.parse(source);
        `root: any = tree.root_node;
    } except Exception as e {
        return {"nodes": [], "edges": [], "error": `str(e)};
    }

    stem = _file_stem(path);
    str_path = `str(path);
    nodes = [];
    edges = [];
    seen_ids = set[any]();
    _DEP_KEYS = frozenset({
        "dependencies",
        "devDependencies",
        "peerDependencies",
        "optionalDependencies",
        "bundleDependencies",
        "bundledDependencies",
    });

    def add_node(nid: str, label: str, line: int, file_type: str = "code") -> None {
        if nid and nid not in seen_ids {
            seen_ids.add(nid);
            nodes.append({
                "id": nid,
                "label": label,
                "file_type": file_type,
                "source_file": str_path,
                "source_location": f"L{line}",
            });
        }
    }

    def add_edge(
        src: str,
        tgt: str,
        relation: str,
        line: int,
        context: str | None = None,
        target_file: "Path | None" = None,
    ) -> None {
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
        if target_file is not None {
            `edge["target_file"] = `str(target_file);
        }
        edges.append(`edge);
    }

    _base_memo = [];

    def paths_base -> "Path | None" {
        if not _base_memo {
            _base_memo.append(_paths_base(path));
        }
        return _base_memo[0];
    }

    file_nid = _make_id(`str(path));
    add_node(file_nid, path.name, 1);

    """Extract the string content of a pair's key."""
    def _key_text(pair_node) -> str | None {
        key_node: any = pair_node.child_by_field_name("key");
        if key_node is None {
            return None;
        }
        if key_node.type == "string" {
            content: any = key_node.child_by_field_name("string_content");
            if content {
                return _read_text(content, source);
            }
            raw: any = _read_text(key_node, source);
            return raw.strip("\"'");
        }
        return _read_text(key_node, source);
    }

    def _val_node(pair_node) -> any {
        return pair_node.child_by_field_name("value");
    }

    def walk_object(
        obj_node, parent_nid: str, parent_key: str | None, depth: int, pair_count: list
    ) -> None {
        if depth > 6 {
            return;
        }
        for child in obj_node.children {
            if child.type != "pair" {
                continue;
            }
            if pair_count[0] >= 500 {
                return;
            }
            pair_count[0] += 1;
            key: any = _key_text(child);
            if not key {
                continue;
            }
            if not normalize_id(key) {
                continue;
            }
            key_nid: any = _make_id(stem, *(([parent_key] if parent_key else []) + [key]));
            if not key_nid {
                continue;
            }
            line: any = child.start_point[0] + 1;
            add_node(key_nid, key, line);
            add_edge(parent_nid, key_nid, "contains", line);

            val: any = _val_node(child);
            if val is None {
                continue;
            }

            if val.type == "object" {
                walk_object(val, key_nid, key, depth + 1, pair_count);
            } elif val.type == "array" and key == "extends" {
                item: any;
                for item in val.children {
                    if item.type == "string" {
                        content: any = item.child_by_field_name("string_content");
                        ref: any = _read_text(content, source)
                            if content
                            else _read_text(item, source).strip("\"'");
                        local: any = _local_extends_target(path, ref) if ref else None;
                        if local is not None {
                            add_edge(
                                key_nid,
                                _make_id(`str(local)),
                                "extends",
                                line,
                                context="import",
                                target_file=local,
                            );
                        } elif ref {
                            ref_nid: any = _make_id("ref", ref);
                            if ref_nid {
                                add_node(ref_nid, ref, line, file_type="concept");
                                add_edge(key_nid, ref_nid, "extends", line, context="import");
                            }
                        }
                    }
                }
            } elif val.type == "array" and parent_key == "paths" and "*" not in key {
                base: any = paths_base();
                for item in val.children if base is not None else () {
                    if item.type != "string" {
                        continue;
                    }
                    content = item.child_by_field_name("string_content");
                    t: any = _read_text(content, source)
                        if content
                        else _read_text(item, source).strip("\"");
                    if not t or "*" in t {
                        continue;
                    }
                    hit: any = _resolve_js_module_path(Path(os.path.normpath(base / t)));
                    if hit is not None and hit.is_file() {
                        add_edge(
                            file_nid, _make_id(`str(hit)), "references", line, target_file=hit
                        );
                        break;
                    }
                }
            } elif val.type == "string" {
                content = val.child_by_field_name("string_content");
                val_text: any = _read_text(content, source)
                    if content
                    else _read_text(val, source).strip("\"'");

                local = _local_extends_target(path, val_text)
                    if key == "extends" and val_text
                    else None;
                if local is not None {
                    add_edge(
                        file_nid,
                        _make_id(`str(local)),
                        "extends",
                        line,
                        context="import",
                        target_file=local,
                    );
                } elif key == "extends" and val_text {
                    ref_nid = _make_id("ref", val_text);
                    if ref_nid {
                        add_node(ref_nid, val_text, line, file_type="concept");
                        add_edge(file_nid, ref_nid, "extends", line, context="import");
                    }
                } elif key == "$ref" and val_text {
                    ref_nid = _make_id("ref", val_text);
                    if ref_nid {
                        add_edge(parent_nid, ref_nid, "references", line);
                    }
                } elif parent_key in _DEP_KEYS and val_text.strip() {
                    dep_nid: any = _make_id("ref", key);
                    if dep_nid {
                        add_node(dep_nid, key, line, file_type="concept");
                        add_edge(file_nid, dep_nid, "imports", line, context="import");
                        add_edge(key_nid, dep_nid, "declares", line);
                        version: any = " ".join(val_text.split());
                        if len(version) > 40 {
                            version = version[:37] + "...";
                        }
                        for `node in nodes {
                            if `node["id"] == key_nid and `node["source_location"] == f"L{line}" {
                                `node["label"] = f"{key}@{version}";
                                break;
                            }
                        }
                    }
                }
            }
        }
    }
    doc: any = `root;
    if doc.type == "document" and doc.child_count > 0 {
        doc = doc.children[0];
    }
    if doc.type == "object" {
        if not _is_config_json(path, doc, source) {
            return {"nodes": [], "edges": [], "skipped": "data json (not a config/manifest)"};
        }
        walk_object(doc, file_nid, None, 0, [0]);
    } else {
        return {"nodes": [], "edges": [], "skipped": "data json (non-object root)"};
    }

    return {"nodes": nodes, "edges": edges};
}
