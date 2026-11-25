impl extract_julia(path: Path) -> dict {
    source: any;
    stem: any;
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    function_bodies: list[tuple[str, object]];
    file_nid: any;
    decl_registry: any;
    try {
        import tree_sitter_julia as tsjulia;
        import from tree_sitter { Language, Parser }
    } except ImportError {
        return {"nodes": [], "edges": [], "error": "tree-sitter-julia not installed"};
    }

    try {
        language: any = Language(tsjulia.language());
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

    def add_node(nid: str, label: str, line: int) {
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
    ) {
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
    decl_registry = DeclIdRegistry(reserved_ids=(file_nid,));

    def decl_id(nid: str, name: str, kind: str) -> str {
        return decl_registry.resolve(nid, name, kind, seen_ids);
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
    def _type_name_of(`node) -> str | None {
        if `node is None {
            return None;
        }
        if `node.type == "identifier" {
            return _read_text(`node, source);
        }
        if `node.type == "parametrized_type_expression" {
            ident: any = next((c for c in `node.children if c.type == "identifier"), None);
            return _read_text(ident, source) if ident else None;
        }
        return None;
    }
    def _type_head_names(type_head) -> tuple[str | None, str | None] {
        bin_expr: any = next(
            (c for c in type_head.children if c.type == "binary_expression"), None
        );
        if bin_expr {
            operands: any = [
                c
                for c in bin_expr.children
                if c.type in ("identifier", "parametrized_type_expression")
            ];
            if operands {
                name: any = _type_name_of(operands[0]);
                super_name: any = _type_name_of(operands[-1]) if len(operands) >= 2 else None;
                return (name, super_name);
            }
            return (None, None);
        }
        name_node: any = next(
            (c
            for c in type_head.children
            if c.type in ("identifier", "parametrized_type_expression")),
            None,
        );
        return (_type_name_of(name_node), None);
    }
    def _type_head_params(type_head) -> set[str] {
        pte: any = None;
        c: any;
        for c in type_head.children {
            if c.type == "parametrized_type_expression" {
                pte = c;
                break;
            }
            if c.type == "binary_expression" {
                pte = next(
                    (cc for cc in c.children if cc.type == "parametrized_type_expression"), None
                );
                break;
            }
        }
        if pte is None {
            return set[any]();
        }
        curly: any = next((c for c in pte.children if c.type == "curly_expression"), None);
        if curly is None {
            return set[any]();
        }
        params: set[str] = set[any]();
        for c in curly.children {
            if c.type == "identifier" {
                params.add(_read_text(c, source));
            } elif c.type == "binary_expression" {
                first: any = next((cc for cc in c.children if cc.type == "identifier"), None);
                if first {
                    params.add(_read_text(first, source));
                }
            }
        }
        return params;
    }
    def _unwrap_call_expression(`node) -> any {
        while `node is not None and `node.type in ("where_expression", "typed_expression") {
            `node = `node.children[0] if `node.children else None;
        }
        if `node is not None and `node.type == "call_expression" {
            return `node;
        }
        return None;
    }
    def _functor_type_name(`node) -> str | None {
        while `node is not None {
            if `node.type == "identifier" {
                return _read_text(`node, source);
            }
            if `node.type == "parametrized_type_expression" {
                `node = `node.children[0] if `node.children else None;
            } elif `node.type == "field_expression" {
                `node = `node.children[-1] if `node.children else None;
            } else {
                return None;
            }
        }
        return None;
    }
    def _def_name(call) -> tuple[str, str] | None {
        if call is None or not call.children {
            return None;
        }
        callee: any = call.children[0];
        if callee.type in ("identifier", "operator") {
            name: any = _read_text(callee, source);
            return (name, name);
        }
        if callee.type == "field_expression" and callee.children {
            last: any = callee.children[-1];
            if last.type == "quote_expression" {
                last = next(
                    (c for c in last.children if c.type in ("operator", "identifier")), None
                );
            }
            if last is not None and last.type in ("identifier", "operator") {
                return (_read_text(last, source), _read_text(callee, source));
            }
            return None;
        }
        if callee.type == "parenthesized_expression" {
            typed: any = next(
                (c
                for c in callee.children
                if c.type in ("typed_expression", "unary_typed_expression")),
                None,
            );
            if typed is not None and typed.children {
                tname: any = _functor_type_name(typed.children[-1]);
                if tname {
                    return (tname + "#call", f"({tname})");
                }
            }
        }
        return None;
    }
    def _func_name_from_signature(sig_node) -> tuple[str, str] | None {
        for child in sig_node.children {
            call: any = _unwrap_call_expression(child);
            if call is not None {
                return _def_name(call);
            }
        }
        return None;
    }

    def walk_calls(body_node, func_nid: str) {
        if body_node is None {
            return;
        }
        t: any = body_node.type;
        if t in ("function_definition", "short_function_definition") {
            return;
        }
        if t == "call_expression" and body_node.children {
            callee: any = body_node.children[0];
            if callee.type == "identifier" {
                callee_name: any = _read_text(callee, source);
                target_nid: any = _make_id(stem, callee_name);
                add_edge(
                    func_nid,
                    target_nid,
                    "calls",
                    body_node.start_point[0] + 1,
                    confidence="EXTRACTED",
                    context="call",
                );
            } elif callee.type == "field_expression" and len(callee.children) >= 3 {
                method_node: any = callee.children[-1];
                method_name: any = _read_text(method_node, source);
                target_nid = _make_id(stem, method_name);
                add_edge(
                    func_nid,
                    target_nid,
                    "calls",
                    body_node.start_point[0] + 1,
                    confidence="EXTRACTED",
                    context="call",
                );
            }
        } elif t == "broadcast_call_expression" and body_node.children {
            callee = body_node.children[0];
            if callee.type == "identifier" {
                add_edge(
                    func_nid,
                    _make_id(stem, _read_text(callee, source)),
                    "calls",
                    body_node.start_point[0] + 1,
                    confidence="EXTRACTED",
                    context="call",
                );
            }
        } elif t == "binary_expression" and len(body_node.children) == 3 {
            op: any;
            rhs: any;
            (op, rhs) = (body_node.children[1], body_node.children[2]);
            if _read_text(op, source) in ("|>", ".|>") and rhs.type == "identifier" {
                add_edge(
                    func_nid,
                    _make_id(stem, _read_text(rhs, source)),
                    "calls",
                    body_node.start_point[0] + 1,
                    confidence="EXTRACTED",
                    context="call",
                );
            }
        }
        for child in body_node.children {
            walk_calls(child, func_nid);
        }
    }

    def walk(`node, scope_nid: str) {
        line: any;
        c: any;
        t: any = `node.type;
        if t == "module_definition" {
            name_node: any = next((c for c in `node.children if c.type == "identifier"), None);
            if name_node {
                mod_name: any = _read_text(name_node, source);
                mod_nid: any = decl_id(_make_id(stem, mod_name), mod_name, "ns");
                line = `node.start_point[0] + 1;
                add_node(mod_nid, mod_name, line);
                add_edge(file_nid, mod_nid, "defines", line);
                child: any;
                for child in `node.children {
                    walk(child, mod_nid);
                }
            }
            return;
        }
        if t == "struct_definition" {
            type_head: any = next((c for c in `node.children if c.type == "type_head"), None);
            if not type_head {
                return;
            }
            struct_name: any;
            super_name: any;
            (struct_name, super_name) = _type_head_names(type_head) as any;
            if not struct_name {
                return;
            }
            struct_nid: any = decl_id(_make_id(stem, struct_name), struct_name, "type");
            line = `node.start_point[0] + 1;
            add_node(struct_nid, struct_name, line);
            add_edge(scope_nid, struct_nid, "defines", line);
            if super_name {
                add_edge(
                    struct_nid,
                    ensure_named_node(super_name, line),
                    "inherits",
                    line,
                    confidence="EXTRACTED",
                );
            }
            type_params: any = _type_head_params(type_head);
            for child in `node.children {
                if child.type == "typed_expression" {
                    type_ids: any = [c for c in child.children if c.type == "identifier"];
                    if len(type_ids) >= 2 {
                        field_line: any = child.start_point[0] + 1;
                        type_name: any = _read_text(type_ids[-1], source);
                        if type_name in type_params {
                            continue;
                        }
                        type_nid: any = ensure_named_node(type_name, field_line);
                        edges.append(
                            _semantic_reference_edge(
                                struct_nid, type_nid, "field", str_path, field_line
                            ),
                        );
                    }
                }
            }
            return;
        }
        if t == "abstract_definition" {
            type_head = next((c for c in `node.children if c.type == "type_head"), None);
            if type_head {
                abs_name: any;
                (abs_name, super_name) = _type_head_names(type_head) as any;
                if abs_name {
                    abs_nid: any = decl_id(_make_id(stem, abs_name), abs_name, "type");
                    line = `node.start_point[0] + 1;
                    add_node(abs_nid, abs_name, line);
                    add_edge(scope_nid, abs_nid, "defines", line);
                    if super_name {
                        add_edge(
                            abs_nid,
                            ensure_named_node(super_name, line),
                            "inherits",
                            line,
                            confidence="EXTRACTED",
                        );
                    }
                }
            }
            return;
        }
        if t == "function_definition" {
            sig_node: any = next((c for c in `node.children if c.type == "signature"), None);
            if sig_node {
                named: any = _func_name_from_signature(sig_node);
                if named {
                    func_name: any;
                    label: any;
                    (func_name, label) = named as any;
                    func_nid: any = decl_id(_make_id(stem, func_name), func_name, "fn");
                    line = `node.start_point[0] + 1;
                    add_node(func_nid, f"{label}()", line);
                    add_edge(scope_nid, func_nid, "defines", line);
                    function_bodies.append((func_nid, `node));
                }
            }
            return;
        }
        if t == "macro_definition" {
            sig_node = next((c for c in `node.children if c.type == "signature"), None);
            if sig_node {
                named = _func_name_from_signature(sig_node);
                macro_name: any = named[0] if named else None;
                if macro_name {
                    macro_nid: any = _make_id(stem, "@" + macro_name);
                    line = `node.start_point[0] + 1;
                    add_node(macro_nid, f"@{macro_name}", line);
                    add_edge(scope_nid, macro_nid, "defines", line);
                    function_bodies.append((macro_nid, `node));
                }
            }
            return;
        }
        if t == "macrocall_expression" {
            macro_id: any = next((c for c in `node.children if c.type == "macro_identifier"), None);
            macro_name = None;
            if macro_id is not None {
                id_node: any = next((c for c in macro_id.children if c.type == "identifier"), None);
                if id_node is not None {
                    macro_name = _read_text(id_node, source);
                }
            }
            if macro_name == "enum" {
                arglist: any = next(
                    (c for c in `node.children if c.type == "macro_argument_list"), None
                );
                arg_nodes: any = [];
                if arglist is not None {
                    for c in arglist.children {
                        if c.type in ("identifier", "typed_expression", "assignment") {
                            arg_nodes.append(c);
                        } elif c.type == "compound_statement" {
                            arg_nodes.extend(
                                cc for cc in c.children if cc.type in ("identifier", "assignment")
                            );
                        }
                    }
                }

                def _member_ident(n) -> any {
                    if n.type == "identifier" {
                        return n;
                    }
                    return next((cc for cc in n.children if cc.type == "identifier"), None);
                }

                type_node: any = _member_ident(arg_nodes[0]) if arg_nodes else None;
                if type_node is not None {
                    enum_name: any = _read_text(type_node, source);
                    line = `node.start_point[0] + 1;
                    enum_nid: any = decl_id(_make_id(stem, enum_name), enum_name, "type");
                    add_node(enum_nid, enum_name, line);
                    add_edge(scope_nid, enum_nid, "defines", line);
                    for member in arg_nodes[1:] {
                        m_node: any = _member_ident(member);
                        if m_node is None {
                            continue;
                        }
                        m_name: any = _read_text(m_node, source);
                        m_line: any = m_node.start_point[0] + 1;
                        m_nid: any = _make_id(stem, enum_name, m_name);
                        add_node(m_nid, m_name, m_line);
                        add_edge(enum_nid, m_nid, "case_of", m_line);
                    }
                }
                return;
            }
            for child in `node.children {
                walk(child, scope_nid);
            }
            return;
        }
        if t == "assignment" {
            lhs: any = `node.children[0] if `node.children else None;
            named = _def_name(_unwrap_call_expression(lhs));
            if named {
                (func_name, label) = named as any;
                func_nid = decl_id(_make_id(stem, func_name), func_name, "fn");
                line = `node.start_point[0] + 1;
                add_node(func_nid, f"{label}()", line);
                add_edge(scope_nid, func_nid, "defines", line);
                rhs: any = `node.children[-1] if len(`node.children) >= 3 else None;
                if rhs {
                    function_bodies.append((func_nid, rhs));
                }
            }
            return;
        }
        if t in ("using_statement", "import_statement") {
            line = `node.start_point[0] + 1;

            def _julia_mod_name(n) -> any {
                if n.type == "import_path" {
                    ids: any = [c for c in n.children if c.type == "identifier"];
                    return _read_text(ids[-1], source) if ids else None;
                }
                if n.type in ("identifier", "scoped_identifier") {
                    return _read_text(n, source);
                }
                return None;
            }

            def _emit_import(name) -> any {
                if not name {
                    return;
                }
                imp_nid: any = _make_id(name);
                add_node(imp_nid, name, line);
                add_edge(scope_nid, imp_nid, "imports", line, context="import");
            }

            for child in `node.children {
                if child.type in ("identifier", "scoped_identifier", "import_path") {
                    _emit_import(_julia_mod_name(child));
                } elif child.type == "selected_import" {
                    pkg: any = next(
                        (c
                        for c in child.children
                        if c.type in ("identifier", "scoped_identifier", "import_path")),
                        None,
                    );
                    if pkg is not None {
                        _emit_import(_julia_mod_name(pkg));
                    }
                }
            }
            return;
        }

        for child in `node.children {
            walk(child, scope_nid);
        }
    }

    walk(`root, file_nid);

    for (func_nid, body_node) in function_bodies {
        if body_node.type in ("function_definition", "macro_definition") {
            for child in body_node.children {
                if child.type != "signature" {
                    walk_calls(child, func_nid);
                }
            }
        } else {
            walk_calls(body_node, func_nid);
        }
    }

    return {"nodes": nodes, "edges": edges};
}
