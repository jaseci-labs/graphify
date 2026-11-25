impl _sv_first_identifier(`node, source: bytes) -> str | None {
    if `node is None {
        return None;
    }
    for child in `node.children {
        if child.type == "simple_identifier" {
            return _read_text(child, source);
        }
        found: any = _sv_first_identifier(child, source);
        if found {
            return found;
        }
    }
    return None;
}

impl _sv_child(`node, type_name: str) -> object | None {
    if `node is None {
        return None;
    }
    for child in `node.children {
        if child.type == type_name {
            return child;
        }
    }
    return None;
}

impl _sv_strip_comments(text: str) -> str {
    text = re.sub("/\\*.*?\\*/", "", text, flags=re.DOTALL);
    return re.sub("//.*", "", text);
}

impl _sv_split_type_list(text: str) -> list[str] {
    parts: list[str] = [];
    depth: any = 0;
    start: any = 0;
    for (idx, ch) in enumerate(text) {
        if ch == "(" {
            depth += 1;
        } elif ch == ")" {
            depth = max(0, depth - 1);
        } elif ch == "," and depth == 0 {
            item: any = text[start:idx].strip();
            if item {
                parts.append(item);
            }
            start = idx + 1;
        }
    }
    item = text[start:].strip();
    if item {
        parts.append(item);
    }
    return parts;
}

impl _sv_collect_type_refs(
    type_text: str, generic: bool = False, `skip: frozenset[str] = skip_default_
) -> list[tuple[str, str]] {
    refs: list[tuple[str, str]] = [];
    text: any = type_text.strip();
    if not text {
        return refs;
    }
    head: any = re.match("([A-Za-z_]\\w*)", text);
    if head {
        name: any = head.group(1);
        if name not in _SV_BUILTIN_TYPES and name not in _SV_NON_TYPE_WORDS and name not in `skip {
            refs.append((name, "generic_arg" if generic else "type"));
        }
    }
    params: any = re.search("#\\s*\\((" + _SV_PARENS_INNER + ")\\)", text);
    if params {
        for arg in _sv_split_type_list(params.group(1)) {
            refs.extend(_sv_collect_type_refs(arg, generic=True, skip=`skip));
        }
    }
    return refs;
}

impl _augment_systemverilog_semantics(
    raw: str,
    stem: str,
    str_path: str,
    file_nid: str,
    nodes: list[dict],
    edges: list[dict],
    seen_ids: set[str],
) {
    label_to_nid: any;
    label_to_nid = {`node["label"]: `node["id"] for `node in nodes};

    def line_for(offset: int) -> int {
        return raw.count("\n", 0, offset) + 1;
    }

    def add_node(nid: str, label: str, line: int) {
        if nid not in seen_ids {
            seen_ids.add(nid);
            nodes.append({
                "id": nid,
                "label": label,
                "file_type": "code",
                "source_file": str_path,
                "source_location": f"L{line}",
                "confidence_score": 1.0,
            });
        }
        label_to_nid[label] = nid;
    }

    def ensure_type(label: str, line: int) -> str {
        if label in label_to_nid {
            return label_to_nid[label];
        }
        nid: any = _make_id(stem, label);
        add_node(nid, label, line);
        return nid;
    }

    def add_edge(
        src: str, target_label: str, relation: str, line: int, context: str | None = None
    ) {
        tgt: any = ensure_type(target_label, line);
        `edge: any = {
            "source": src,
            "target": tgt,
            "relation": relation,
            "confidence": "EXTRACTED",
            "confidence_score": 1.0,
            "source_file": str_path,
            "source_location": f"L{line}",
            "weight": 1.0,
        };
        if context {
            `edge["context"] = context;
        }
        edges.append(`edge);
    }

    text: any = _sv_strip_comments(raw);
    class_re: any = re.compile(
        "\\b(?:(interface)\\s+)?class\\s+(\\w+)([^;{]*)\\s*;(.*?)\\bendclass\\b", re.DOTALL
    );
    for `match in class_re.finditer(text) {
        class_name: any = `match.group(2);
        header: any = `match.group(3) or "";
        body: any = `match.group(4) or "";
        line: any = line_for(`match.start());
        type_params: any = frozenset(re.findall("\\btype\\s+(\\w+)", header));
        class_nid: any = _make_id(stem, class_name);
        add_node(class_nid, class_name, line);
        edges.append({
            "source": file_nid,
            "target": class_nid,
            "relation": "defines",
            "confidence": "EXTRACTED",
            "confidence_score": 1.0,
            "source_file": str_path,
            "source_location": f"L{line}",
            "weight": 1.0,
        });

        ext: any = re.search("\\bextends\\s+(\\w+)", header);
        if ext {
            add_edge(class_nid, ext.group(1), "inherits", line);
        }
        `impl: any = re.search("\\bimplements\\s+([^;{]+)", header);
        if `impl {
            for iface_name in _sv_split_type_list(`impl.group(1)) {
                add_edge(class_nid, iface_name.split("#", 1)[0].strip(), "implements", line);
            }
        }
        body_without_methods: any = re.sub(
            "\\bfunction\\b.*?\\bendfunction\\b",
            lambda (m) -> any { "\n" * m.group(0).count("\n") },
            body,
            flags=re.DOTALL,
        );
        body_without_methods = re.sub(
            "\\btask\\b.*?\\bendtask\\b",
            lambda (m) -> any { "\n" * m.group(0).count("\n") },
            body_without_methods,
            flags=re.DOTALL,
        );
        for field in re.finditer(
            "^\\s*(?:(?:rand|randc|local|protected|static|const|automatic|var)\\s+)*([A-Za-z_]\\w*(?:\\s*#\\s*\\([^;]+?\\))?)\\s+\\w+\\s*;",
            body_without_methods,
            re.MULTILINE,
        ) {
            field_line: any = line + body_without_methods.count("\n", 0, field.start(1));
            ref_name: any;
            role: any;
            for (ref_name, role) in _sv_collect_type_refs(field.group(1), skip=type_params) {
                add_edge(
                    class_nid,
                    ref_name,
                    "references",
                    field_line,
                    "generic_arg" if role == "generic_arg" else "field",
                );
            }
        }

        for fm in _SV_FUNC_RE.finditer(body) {
            return_type: any;
            func_name: any;
            params: any;
            (return_type, func_name, params) = (fm.group(1), fm.group(2), fm.group(3));
            func_line: any = line + body.count("\n", 0, fm.start());
            func_nid: any = _make_id(class_nid, func_name);
            add_node(func_nid, func_name, func_line);
            edges.append({
                "source": class_nid,
                "target": func_nid,
                "relation": "method",
                "confidence": "EXTRACTED",
                "confidence_score": 1.0,
                "source_file": str_path,
                "source_location": f"L{func_line}",
                "weight": 1.0,
            });
            if return_type {
                for (ref_name, role) in _sv_collect_type_refs(return_type, skip=type_params) {
                    add_edge(
                        func_nid,
                        ref_name,
                        "references",
                        func_line,
                        "generic_arg" if role == "generic_arg" else "return_type",
                    );
                }
            }
            param: any;
            for param in _sv_split_type_list(params) {
                pm: any = _SV_PARAM_RE.match(param);
                if not pm {
                    continue;
                }
                for (ref_name, role) in _sv_collect_type_refs(pm.group(1), skip=type_params) {
                    add_edge(
                        func_nid,
                        ref_name,
                        "references",
                        func_line,
                        "generic_arg" if role == "generic_arg" else "parameter_type",
                    );
                }
            }
        }

        for tm in _SV_TASK_RE.finditer(body) {
            task_name: any;
            (task_name, params) = (tm.group(1), tm.group(2));
            task_line: any = line + body.count("\n", 0, tm.start());
            task_nid: any = _make_id(class_nid, task_name);
            add_node(task_nid, task_name, task_line);
            edges.append({
                "source": class_nid,
                "target": task_nid,
                "relation": "method",
                "confidence": "EXTRACTED",
                "confidence_score": 1.0,
                "source_file": str_path,
                "source_location": f"L{task_line}",
                "weight": 1.0,
            });
            for param in _sv_split_type_list(params) {
                pm = _SV_PARAM_RE.match(param);
                if not pm {
                    continue;
                }
                for (ref_name, role) in _sv_collect_type_refs(pm.group(1), skip=type_params) {
                    add_edge(
                        task_nid,
                        ref_name,
                        "references",
                        task_line,
                        "generic_arg" if role == "generic_arg" else "parameter_type",
                    );
                }
            }
        }
    }
}

impl extract_verilog(path: Path) -> dict {
    source: any;
    stem: any;
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    file_nid: any;
    local_modules: set[str];
    try {
        import tree_sitter_verilog as tsverilog;
        import from tree_sitter { Language, Parser }
    } except ImportError {
        return {"nodes": [], "edges": [], "error": "tree_sitter_verilog not installed"};
    }

    try {
        language: any = Language(tsverilog.language());
        parser: any = Parser(language);
        source = _read_source_bytes(path);
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

    def add_node(nid: str, label: str, line: int) {
        if nid not in seen_ids {
            seen_ids.add(nid);
            nodes.append({
                "id": nid,
                "label": label,
                "file_type": "code",
                "source_file": str_path,
                "source_location": f"L{line}",
                "confidence_score": 1.0,
            });
        }
    }

    def add_edge(
        src: str,
        tgt: str,
        relation: str,
        line: int,
        confidence: str = "EXTRACTED",
        score: float = 1.0,
    ) {
        edges.append({
            "source": src,
            "target": tgt,
            "relation": relation,
            "confidence": confidence,
            "confidence_score": score,
            "source_file": str_path,
            "source_location": f"L{line}",
            "weight": 1.0,
        });
    }

    file_nid = _make_id(`str(path));
    add_node(file_nid, path.name, 1);
    local_modules = set[any]();

    def _scan_modules(`node) {
        if `node.type == "module_declaration" {
            mn: any = _sv_first_identifier(_sv_child(`node, "module_header"), source);
            if mn {
                local_modules.add(mn);
            }
        }
        for child in `node.children {
            _scan_modules(child);
        }
    }

    _scan_modules(`root);

    def walk(`node, module_nid: str | None = None) {
        t: any = `node.type;
        if t in ("class_declaration", "interface_class_declaration") {
            return;
        }

        if t == "module_declaration" {
            mod_name: any = _sv_first_identifier(_sv_child(`node, "module_header"), source);
            if mod_name {
                line: any = `node.start_point[0] + 1;
                nid: any = _make_id(stem, mod_name);
                add_node(nid, mod_name, line);
                add_edge(file_nid, nid, "defines", line);
                child: any;
                for child in `node.children {
                    walk(child, nid);
                }
                return;
            }
        } elif t == "function_declaration" {
            fn_body: any = _sv_child(`node, "function_body_declaration");
            func_name: any = _sv_first_identifier(
                _sv_child(fn_body, "function_identifier"), source
            );
            if func_name {
                line = `node.start_point[0] + 1;
                parent: any = module_nid or file_nid;
                nid = _make_id(parent, func_name);
                add_node(nid, f"{func_name}()", line);
                add_edge(parent, nid, "contains", line);
            }
        } elif t == "task_declaration" {
            tk_body: any = _sv_child(`node, "task_body_declaration");
            task_name: any = _sv_first_identifier(_sv_child(tk_body, "task_identifier"), source);
            if task_name {
                line = `node.start_point[0] + 1;
                parent = module_nid or file_nid;
                nid = _make_id(parent, task_name);
                add_node(nid, task_name, line);
                add_edge(parent, nid, "contains", line);
            }
        } elif t == "package_import_declaration" {
            for child in `node.children {
                if child.type == "package_import_item" {
                    pkg_text: any = _read_text(child, source);
                    pkg_name: any = pkg_text.split("::")[0].strip();
                    if pkg_name {
                        line = `node.start_point[0] + 1;
                        tgt_nid: any = _make_id(pkg_name);
                        add_node(tgt_nid, pkg_name, line);
                        src_nid: any = module_nid or file_nid;
                        add_edge(src_nid, tgt_nid, "imports_from", line);
                    }
                }
            }
        } elif t in ("module_instantiation", "checker_instantiation") {
            if module_nid {
                type_node: any = `node.child_by_field_name("module_type");
                inst_type: any = _read_text(type_node, source).strip()
                    if type_node
                    else _sv_first_identifier(`node, source);
                if inst_type {
                    line = `node.start_point[0] + 1;
                    if inst_type in local_modules {
                        tgt_nid = _make_id(stem, inst_type);
                    } else {
                        tgt_nid = _make_id(inst_type);
                        if tgt_nid not in seen_ids {
                            seen_ids.add(tgt_nid);
                            nodes.append({
                                "id": tgt_nid,
                                "label": inst_type,
                                "file_type": "code",
                                "source_file": "",
                                "source_location": "",
                                "confidence_score": 1.0,
                            });
                        }
                    }
                    add_edge(module_nid, tgt_nid, "instantiates", line);
                }
            }
        }

        for child in `node.children {
            walk(child, module_nid);
        }
    }

    walk(`root);
    _augment_systemverilog_semantics(
        source.decode("utf-8", errors="replace"), stem, str_path, file_nid, nodes, edges, seen_ids
    );
    return {"nodes": nodes, "edges": edges};
}
