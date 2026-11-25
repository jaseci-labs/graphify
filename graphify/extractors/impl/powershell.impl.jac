impl extract_powershell(path: Path) -> dict {
    source: any;
    stem: any;
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    function_bodies: list[tuple[str, Any, str | None]];
    class_ids_by_name: dict[str, list[str]];
    class_names_by_id: dict[str, str];
    methods_by_class: dict[str, dict[str, str]];
    file_nid: any;
    _PS_SKIP: any;
    _PS_NAMED_BLOCK_CMDS: any;
    label_to_nid: any;
    seen_call_pairs: set[tuple[str, str]];
    raw_calls: list[dict];
    try {
        import tree_sitter_powershell as tsps;
        import from tree_sitter { Language, Parser }
    } except ImportError {
        return {"nodes": [], "edges": [], "error": "tree_sitter_powershell not installed"};
    }

    try {
        language: any = Language(tsps.language());
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
    function_bodies = [];
    class_ids_by_name = {};
    class_names_by_id = {};
    methods_by_class = {};

    def add_node(nid: str, label: str, line: int) -> None {
        if nid not in seen_ids {
            seen_ids.add(nid);
            nodes.append({
                "id": nid,
                "label": label,
                "file_type": "code",
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
        confidence: str = "EXTRACTED",
        weight: float = 1.0,
        context: str | None = None,
    ) -> None {
        `edge: any = {
            "source": src,
            "target": tgt,
            "relation": relation,
            "confidence": confidence,
            "source_file": str_path,
            "source_location": f"L{line}",
            "weight": weight,
        };
        if context {
            `edge["context"] = context;
        }
        edges.append(`edge);
    }

    file_nid = _make_id(`str(path));
    add_node(file_nid, path.name, 1);

    _PS_SKIP = frozenset({
        "using",
        "return",
        "if",
        "else",
        "elseif",
        "foreach",
        "for",
        "while",
        "do",
        "switch",
        "try",
        "catch",
        "finally",
        "throw",
        "break",
        "continue",
        "exit",
        "param",
        "begin",
        "process",
        "end",
        "import-module",
    });
    _PS_NAMED_BLOCK_CMDS = frozenset({"begin", "process", "end", "dynamicparam", "clean"});

    def _find_script_block_body(`node) -> any {
        for child in `node.children {
            if child.type == "script_block" {
                for sc in child.children {
                    if sc.type == "script_block_body" {
                        return sc;
                    }
                }
                return child;
            }
        }
        return None;
    }

    def ensure_named_node(name: str, line: int) -> str {
        nid: any = _make_id(stem, name);
        if nid in seen_ids {
            return nid;
        }
        nid = _make_id(name);
        if nid not in seen_ids {
            seen_ids.add(nid);
            nodes.append({
                "id": nid,
                "label": name,
                "file_type": "code",
                "source_file": "",
                "source_location": "",
                "origin_file": str_path,
            });
        }
        return nid;
    }

    """Drill into a type_literal node and return the inner type_identifier text."""
    def _ps_type_name(type_literal_node) -> str | None {
        if type_literal_node is None {
            return None;
        }
        for spec in type_literal_node.children {
            if spec.type != "type_spec" {
                continue;
            }
            for tname in spec.children {
                if tname.type != "type_name" {
                    continue;
                }
                for tid in tname.children {
                    if tid.type == "type_identifier" {
                        return _read_text(tid, source);
                    }
                }
            }
        }
        return None;
    }

    def walk(`node, parent_class_nid: str | None = None) -> None {
        t: any = `node.type;

        if t == "function_statement" {
            name_node: any = next((c for c in `node.children if c.type == "function_name"), None);
            if name_node {
                func_name: any = _read_text(name_node, source);
                line: any = `node.start_point[0] + 1;
                func_nid: any = _make_id(stem, func_name);
                add_node(func_nid, f"{func_name}()", line);
                add_edge(file_nid, func_nid, "contains", line);
                body: any = _find_script_block_body(`node);
                if body {
                    function_bodies.append((func_nid, body, None));
                    walk(body, parent_class_nid);
                }
            }
            return;
        }

        if t == "enum_statement" {
            name_node = next((c for c in `node.children if c.type == "simple_name"), None);
            if name_node {
                enum_name: any = _read_text(name_node, source);
                line = `node.start_point[0] + 1;
                enum_nid: any = _make_id(stem, enum_name);
                add_node(enum_nid, enum_name, line);
                add_edge(file_nid, enum_nid, "contains", line);
                for member in `node.children {
                    if member.type != "enum_member" {
                        continue;
                    }
                    mname_node: any = next(
                        (c for c in member.children if c.type == "simple_name"), None
                    );
                    if mname_node is None {
                        continue;
                    }
                    member_name: any = _read_text(mname_node, source);
                    m_line: any = member.start_point[0] + 1;
                    member_nid: any = _make_id(enum_nid, member_name);
                    add_node(member_nid, member_name, m_line);
                    add_edge(enum_nid, member_nid, "case_of", m_line);
                }
            }
            return;
        }

        if t == "class_statement" {
            name_node = next((c for c in `node.children if c.type == "simple_name"), None);
            if name_node {
                class_name: any = _read_text(name_node, source);
                line = `node.start_point[0] + 1;
                class_nid: any = _make_id(stem, class_name);
                class_ids_by_name.setdefault(class_name.lower(), []).append(class_nid);
                class_names_by_id[class_nid] = class_name.lower();
                add_node(class_nid, class_name, line);
                add_edge(file_nid, class_nid, "contains", line);
                colon_seen: any = False;
                base_index: any = 0;
                child: any;
                for child in `node.children {
                    if child.type == ":" {
                        colon_seen = True;
                    } elif colon_seen and child.type == "simple_name" {
                        base_nid: any = ensure_named_node(_read_text(child, source), line);
                        if base_nid != class_nid {
                            rel: any = "inherits" if base_index == 0 else "implements";
                            add_edge(class_nid, base_nid, rel, line);
                        }
                        base_index += 1;
                    }
                }
                for child in `node.children {
                    walk(child, parent_class_nid=class_nid);
                }
            }
            return;
        }

        if t == "class_property_definition" and parent_class_nid {
            type_literal: any = next((c for c in `node.children if c.type == "type_literal"), None);
            type_name: any = _ps_type_name(type_literal);
            if type_name {
                line = `node.start_point[0] + 1;
                target_nid: any = ensure_named_node(type_name, line);
                if target_nid != parent_class_nid {
                    add_edge(parent_class_nid, target_nid, "references", line, context="field");
                }
            }
            return;
        }

        if t == "class_method_definition" {
            name_node = next((c for c in `node.children if c.type == "simple_name"), None);
            if name_node {
                method_name: any = _read_text(name_node, source);
                line = `node.start_point[0] + 1;
                if parent_class_nid {
                    method_nid: any = _make_id(parent_class_nid, method_name);
                    add_node(method_nid, f".{method_name}()", line);
                    add_edge(parent_class_nid, method_nid, "method", line);
                    methods_by_class.setdefault(
                        parent_class_nid, {}
                    )[method_name.lower()] = method_nid;
                } else {
                    method_nid = _make_id(stem, method_name);
                    add_node(method_nid, f"{method_name}()", line);
                    add_edge(file_nid, method_nid, "contains", line);
                }
                return_type_literal: any = next(
                    (c for c in `node.children if c.type == "type_literal"), None
                );
                return_type_name: any = _ps_type_name(return_type_literal);
                if return_type_name {
                    target_nid = ensure_named_node(return_type_name, line);
                    if target_nid != method_nid {
                        add_edge(method_nid, target_nid, "references", line, context="return_type");
                    }
                }
                param_list: any = next(
                    (c for c in `node.children if c.type == "class_method_parameter_list"), None
                );
                if param_list is not None {
                    for p in param_list.children {
                        if p.type != "class_method_parameter" {
                            continue;
                        }
                        ptype_literal: any = next(
                            (c for c in p.children if c.type == "type_literal"), None
                        );
                        ptype_name: any = _ps_type_name(ptype_literal);
                        if not ptype_name {
                            continue;
                        }
                        p_line: any = p.start_point[0] + 1;
                        target_nid = ensure_named_node(ptype_name, p_line);
                        if target_nid != method_nid {
                            add_edge(
                                method_nid,
                                target_nid,
                                "references",
                                p_line,
                                context="parameter_type",
                            );
                        }
                    }
                }
                body = _find_script_block_body(`node);
                if body {
                    function_bodies.append((method_nid, body, parent_class_nid));
                }
            }
            return;
        }

        if t == "command" {
            invoke_op: any = next(
                (c for c in `node.children if c.type == "command_invokation_operator"), None
            );
            if invoke_op is not None and _read_text(invoke_op, source).strip() == "." {
                name_expr: any = next(
                    (c for c in `node.children if c.type == "command_name_expr"), None
                );
                if name_expr is not None {
                    name_node = next(
                        (c
                        for c in name_expr.children
                        if c.type in ("command_name", "path_command_name", "string_literal")),
                        None,
                    );
                    if name_node {
                        raw_path: any = _read_text(name_node, source).strip().strip("'\"");
                        module_stem: any = re.sub("^[./\\\\]+", "", raw_path);
                        module_stem = re.sub("\\.[^.]+$", "", module_stem).replace("\\", "/");
                        module_name: str | None = module_stem.split("/")[-1];
                        if module_name {
                            add_edge(
                                file_nid,
                                _make_id(module_name),
                                "imports_from",
                                `node.start_point[0] + 1,
                            );
                        }
                    }
                }
                return;
            }

            cmd_name_node: any = next(
                (c for c in `node.children if c.type == "command_name"), None
            );
            if cmd_name_node {
                cmd_text: any = _read_text(cmd_name_node, source).lower();
                if cmd_text == "using" {
                    tokens: any = [];
                    for child in `node.children {
                        if child.type == "command_elements" {
                            el: any;
                            for el in child.children {
                                if el.type == "generic_token" {
                                    tokens.append(_read_text(el, source));
                                }
                            }
                        }
                    }
                    using_kind: any = tokens[0].lower() if tokens else "";
                    module_tokens: any = [
                        t
                        for t in tokens
                        if t.lower() not in ("namespace", "module", "assembly")
                    ];
                    if module_tokens {
                        raw: any = module_tokens[-1];
                        if using_kind == "namespace" {
                            module_name = raw.split(".")[-1];
                        } else {
                            module_name = re.sub(
                                "\\.(psm1|psd1|ps1|dll|exe)$", "", raw, flags=re.IGNORECASE
                            ).split("/")[-1].split("\\")[-1];
                        }
                        if module_name {
                            add_edge(
                                file_nid,
                                _make_id(module_name),
                                "imports_from",
                                `node.start_point[0] + 1,
                            );
                        }
                    }
                } elif cmd_text == "import-module" {
                    module_name = None;
                    expect_name: any = False;
                    for child in `node.children {
                        if child.type != "command_elements" {
                            continue;
                        }
                        for el in child.children {
                            if el.type == "command_parameter" {
                                param_text: any = _read_text(el, source).lstrip("-").lower();
                                expect_name = param_text in ("name", "n");
                            } elif el.type == "generic_token" {
                                token: any = _read_text(el, source);
                                if module_name is None or expect_name {
                                    module_name = token;
                                    expect_name = False;
                                }
                            }
                        }
                    }
                    if module_name {
                        bare: any = re.sub("\\.[^.]+$", "", module_name).split("/")[-1].split(
                            "\\"
                        )[-1];
                        if bare {
                            add_edge(
                                file_nid, _make_id(bare), "imports_from", `node.start_point[0] + 1
                            );
                        }
                    }
                } elif cmd_text in _PS_NAMED_BLOCK_CMDS {
                    for child in `node.children {
                        walk(child, parent_class_nid);
                    }
                }
            }
            return;
        }

        for child in `node.children {
            walk(child, parent_class_nid);
        }
    }

    walk(`root);

    label_to_nid = {n["label"].strip("()").lstrip(".").lower(): n["id"] for n in nodes};
    seen_call_pairs = set[any]();
    raw_calls = [];

    def walk_calls(`node, caller_nid: str, parent_class_nid: str | None) -> None {
        if `node.type in ("function_statement", "class_statement") {
            return;
        }
        if `node.type == "command" {
            cmd_name_node: any = next(
                (c for c in `node.children if c.type == "command_name"), None
            );
            if cmd_name_node {
                cmd_text: any = _read_text(cmd_name_node, source);
                if cmd_text.lower() not in _PS_SKIP {
                    tgt_nid: any = label_to_nid.get(cmd_text.lower());
                    if tgt_nid and tgt_nid != caller_nid {
                        pair: any = (caller_nid, tgt_nid);
                        if pair not in seen_call_pairs {
                            seen_call_pairs.add(pair);
                            add_edge(
                                caller_nid,
                                tgt_nid,
                                "calls",
                                `node.start_point[0] + 1,
                                confidence="EXTRACTED",
                                weight=1.0,
                            );
                        }
                    } elif cmd_text {
                        raw_calls.append({
                            "caller_nid": caller_nid,
                            "callee": cmd_text,
                            "is_member_call": False,
                            "source_file": str_path,
                            "source_location": f"L{`node.start_point[0] + 1}",
                        });
                    }
                }
            }
        } elif `node.type == "invokation_expression" {
            member_node: any = next((c for c in `node.children if c.type == "member_name"), None);
            if member_node is not None {
                method_name: any = _read_text(member_node, source);
                receiver_class: any = None;
                receiver: any = `node.children[0] if `node.children else None;
                access_op: any = `node.children[1].type if len(`node.children) > 1 else None;
                if receiver is not None and receiver.type == "variable" and access_op == "." {
                    if _read_text(receiver, source).lower() == "$this" and parent_class_nid {
                        name: any = class_names_by_id[parent_class_nid];
                        if len(class_ids_by_name[name]) == 1 {
                            receiver_class = parent_class_nid;
                        }
                    }
                } elif receiver is not None
                    and receiver.type == "type_literal"
                    and access_op == "::"
                {
                    type_name: any = _read_text(receiver, source)[1:-1].strip()
                        if not receiver.has_error
                        else "";
                    class_ids: any = class_ids_by_name.get(type_name.lower(), [])
                        if type_name
                        else [];
                    if len(class_ids) == 1 {
                        receiver_class = class_ids[0];
                    }
                }
                literal_member: any = operator.eq(len(member_node.named_children), 1)
                    and operator.eq(member_node.named_children[0].type, "simple_name");
                tgt_nid = methods_by_class.get(receiver_class, {}).get(method_name.lower())
                    if receiver_class and literal_member
                    else None;
                if tgt_nid and tgt_nid != caller_nid {
                    pair = (caller_nid, tgt_nid);
                    if pair not in seen_call_pairs {
                        seen_call_pairs.add(pair);
                        add_edge(
                            caller_nid,
                            tgt_nid,
                            "calls",
                            `node.start_point[0] + 1,
                            confidence="EXTRACTED",
                            weight=1.0,
                        );
                    }
                } elif method_name and not tgt_nid {
                    raw_calls.append({
                        "caller_nid": caller_nid,
                        "callee": method_name,
                        "is_member_call": True,
                        "source_file": str_path,
                        "source_location": f"L{`node.start_point[0] + 1}",
                    });
                }
            }
        }
        for child in `node.children {
            walk_calls(child, caller_nid, parent_class_nid);
        }
    }

    for (caller_nid, body_node, parent_class_nid) in function_bodies {
        walk_calls(body_node, caller_nid, parent_class_nid);
    }
    walk_calls(`root, file_nid, None);

    clean_edges: any = [
        e
        for e in edges
        if e["source"] in seen_ids
            and (e["target"] in seen_ids or e["relation"] in ("imports_from", "imports"))
    ];
    return {"nodes": nodes, "edges": clean_edges, "raw_calls": raw_calls};
}

impl _psd1_collect_string_literals(`node, source: bytes) -> list[str] {
    results: list[str];
    results = [];

    def _walk(n) -> None {
        if n.type == "string_literal" {
            raw: any = source[n.start_byte:n.end_byte].decode(errors="replace");
            results.append(raw.strip("'\""));
            return;
        }
        for child in n.children {
            _walk(child);
        }
    }

    _walk(`node);
    return results;
}

impl _psd1_module_name(raw: str) -> str {
    name: any = raw.replace("\\", "/").split("/")[-1];
    name = re.sub("\\.[^.]+$", "", name);
    return name.strip();
}

impl extract_powershell_manifest(path: Path) -> dict {
    source: any;
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    file_nid: any;
    try {
        import tree_sitter_powershell as tsps;
        import from tree_sitter { Language, Parser }
    } except ImportError {
        return {"nodes": [], "edges": [], "error": "tree_sitter_powershell not installed"};
    }

    try {
        language: any = Language(tsps.language());
        parser: any = Parser(language);
        source = _read_source_bytes(path);
        tree: any = parser.parse(source);
        `root: any = tree.root_node;
    } except Exception as e {
        return {"nodes": [], "edges": [], "error": `str(e)};
    }

    str_path = `str(path);
    nodes = [];
    edges = [];
    seen_ids = set[any]();

    def add_node(nid: str, label: str, line: int) -> None {
        if nid not in seen_ids {
            seen_ids.add(nid);
            nodes.append({
                "id": nid,
                "label": label,
                "file_type": "code",
                "source_file": str_path,
                "source_location": f"L{line}",
            });
        }
    }

    def add_import_edge(src: str, module_raw: str, line: int) -> None {
        name: any = _psd1_module_name(module_raw);
        if not name {
            return;
        }
        tgt_nid: any = _make_id(name);
        edges.append({
            "source": src,
            "target": tgt_nid,
            "relation": "imports_from",
            "confidence": "EXTRACTED",
            "source_file": str_path,
            "source_location": f"L{line}",
            "weight": 1.0,
            "context": "import",
        });
    }

    file_nid = _make_id(`str(path));
    add_node(file_nid, path.name, 1);

    """Walk the AST and emit edges for import-relevant hash_entry nodes."""
    def walk_manifest(`node) -> None {
        module_name_strings: list[str];
        inside_hash_entries: set[int];
        if `node.type != "hash_entry" {
            for child in `node.children {
                walk_manifest(child);
            }
            return;
        }
        key_node: any = next((c for c in `node.children if c.type == "key_expression"), None);
        if key_node is None {
            return;
        }
        key_text: any = source[key_node.start_byte:key_node.end_byte].decode(
            errors="replace"
        ).strip();

        if key_text not in _PSD1_IMPORT_KEYS {
            return;
        }

        line: any = `node.start_point[0] + 1;
        value_node: any = next((c for c in `node.children if c.type == "pipeline"), None);
        if value_node is None {
            return;
        }

        if key_text == "RootModule" {
            strings: any = _psd1_collect_string_literals(value_node, source);
            s: any;
            for s in strings {
                add_import_edge(file_nid, s, line);
            }
        } elif key_text == "NestedModules" {
            strings = _psd1_collect_string_literals(value_node, source);
            for s in strings {
                add_import_edge(file_nid, s, line);
            }
        } elif key_text == "RequiredModules" {
            module_name_strings = [];
            inside_hash_entries = set[any]();

            """Return all string_literal nodes in subtree."""
            def _collect_string_nodes(n) -> Generator[any, any, any] {
                if n.type == "string_literal" {
                    yield n;
                    return;
                }
                for child in n.children {
                    yield from _collect_string_nodes(child);
                }
            }

            def find_modulename_entries(n) -> None {
                c: any;
                if n.type == "hash_entry" {
                    sub_key: any = next(
                        (c for c in n.children if c.type == "key_expression"), None
                    );
                    if sub_key is not None {
                        sk_text: any = source[sub_key.start_byte:sub_key.end_byte].decode(
                            errors="replace"
                        ).strip();
                        for c in n.children {
                            if c.type == "pipeline" {
                                for s_node in _collect_string_nodes(c) {
                                    inside_hash_entries.add(s_node.start_byte);
                                }
                            }
                        }
                        if sk_text == "ModuleName" {
                            for c in n.children {
                                if c.type == "pipeline" {
                                    for s in _psd1_collect_string_literals(c, source) {
                                        module_name_strings.append(s);
                                    }
                                }
                            }
                        }
                    }
                    return;
                }
                for child in n.children {
                    find_modulename_entries(child);
                }
            }

            find_modulename_entries(value_node);
            direct_strings: list[str] = [];
            for s_node in _collect_string_nodes(value_node) {
                if s_node.start_byte not in inside_hash_entries {
                    raw: any = source[s_node.start_byte:s_node.end_byte].decode(errors="replace");
                    direct_strings.append(raw.strip("'\""));
                }
            }

            for s in direct_strings + module_name_strings {
                add_import_edge(file_nid, s, line);
            }
        }
    }

    walk_manifest(`root);

    return {"nodes": nodes, "edges": edges, "raw_calls": []};
}
