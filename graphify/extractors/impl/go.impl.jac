impl _go_alias_re_exports(alias_node, source: bytes) -> bool {
    target: any = alias_node.child_by_field_name("type");
    if target is not None and target.type == "generic_type" {
        target = target.child_by_field_name("type");
    }
    if target is None or target.type != "qualified_type" {
        return False;
    }
    name: any;
    target_name: any;
    (name, target_name) = (
        alias_node.child_by_field_name("name"),
        target.child_by_field_name("name"),
    );
    return name is not None
        and target_name is not None
        and operator.eq(_read_text(name, source), _read_text(target_name, source));
}

impl _go_type_param_names(decl_node, source: bytes) -> frozenset[str] {
    names: set[str] = set[any]();
    for child in decl_node.children {
        if child.type != "type_parameter_list" {
            continue;
        }
        for decl in child.children {
            if decl.type != "type_parameter_declaration" {
                continue;
            }
            for c in decl.children {
                if c.type == "identifier" {
                    text: any = _read_text(c, source);
                    if text {
                        names.add(text);
                    }
                }
            }
        }
    }
    receiver: any = decl_node.child_by_field_name("receiver");
    if receiver is not None {
        stack: any = [receiver];
        while stack {
            n: any = stack.pop();
            if n.type == "type_arguments" {
                leaves: any = [n];
                while leaves {
                    leaf: any = leaves.pop();
                    if leaf.type == "type_identifier" {
                        text = _read_text(leaf, source);
                        if text {
                            names.add(text);
                        }
                    }
                    leaves.extend(leaf.children);
                }
                continue;
            }
            stack.extend(n.children);
        }
    }
    return frozenset(names);
}

impl _go_collect_type_refs(
    `node,
    source: bytes,
    generic: bool,
    out: list[tuple[str, str]],
    `skip: frozenset[str] = skip_default_,
) -> None {
    if `node is None {
        return;
    }
    t: any = `node.type;
    if t == "type_identifier" {
        text: any = _read_text(`node, source);
        if text and text not in _GO_PREDECLARED_TYPES and text not in `skip {
            out.append((text, "generic_arg" if generic else "type"));
        }
        return;
    }
    if t == "qualified_type" {
        text = _read_text(`node, source);
        if text {
            out.append((text, "generic_arg" if generic else "type"));
        }
        return;
    }
    if t == "generic_type" {
        type_field: any = `node.child_by_field_name("type");
        if type_field is not None {
            sub: list[tuple[str, str]] = [];
            _go_collect_type_refs(type_field, source, generic, sub, `skip);
            out.extend(sub);
        }
        c: any;
        for c in `node.children {
            if c.type == "type_arguments" {
                for arg in c.children {
                    if arg.is_named {
                        _go_collect_type_refs(arg, source, True, out, `skip);
                    }
                }
            }
        }
        return;
    }
    if t
        in (
            "pointer_type",
            "slice_type",
            "array_type",
            "map_type",
            "channel_type",
            "parenthesized_type",
        )
    {
        for c in `node.children {
            if c.is_named {
                _go_collect_type_refs(c, source, generic, out, `skip);
            }
        }
        return;
    }
    if `node.is_named {
        for c in `node.children {
            if c.is_named {
                _go_collect_type_refs(c, source, generic, out, `skip);
            }
        }
    }
}

impl _go_strip_generic_args(type_text: str) -> str {
    return type_text.split("[", 1)[0].strip();
}

impl _go_single_type_name(`node, source: bytes) -> str | None {
    while `node is not None
        and `node.type in ("pointer_type", "parenthesized_type", "generic_type")
    {
        `node = `node.child_by_field_name("type")
            or next((c for c in `node.children if c.is_named), None);
    }
    if `node is not None and `node.type == "qualified_type" {
        package: any = `node.child_by_field_name("package");
        name_node: any = `node.child_by_field_name("name");
        if package is None or name_node is None {
            return None;
        }
        return f"{_read_text(package, source)}.{_read_text(name_node, source)}";
    }
    if `node is None or `node.type != "type_identifier" {
        return None;
    }
    name: any = _read_text(`node, source);
    return name if name and name not in _GO_PREDECLARED_TYPES else None;
}

impl _go_inferred_composite_bindings(names, values, source: bytes) -> Generator[any, any, any] {
    value: any;
    for (name_node, value) in zip(names, values) {
        if value.type == "unary_expression" {
            value = value.child_by_field_name("operand") or value;
        }
        if value.type != "composite_literal" {
            continue;
        }
        type_name: any = _go_single_type_name(value.child_by_field_name("type"), source);
        if type_name {
            yield (_read_text(name_node, source), type_name);
        }
    }
}

impl _go_receiver_type_table(`root, source: bytes, *, package_only: bool = False) -> dict[str, str
    | None] {
    table: dict[str, str | None] = {};
    stack: any = [`root];
    while stack {
        n: any = stack.pop();
        t: any = n.type;
        if t == "block" or t == "func_literal" and n != `root {
            continue;
        }
        if package_only
            and t
                in (
                    "function_declaration",
                    "method_declaration",
                    "func_literal",
                    "type_declaration",
                )
        {
            continue;
        }
        if t
            in (
                "field_declaration",
                "parameter_declaration",
                "variadic_parameter_declaration",
                "var_spec",
            )
        {
            names: any = [c for c in n.children if c.type in ("field_identifier", "identifier")];
            type_name: any = None
                if t == "variadic_parameter_declaration"
                else _go_single_type_name(n.child_by_field_name("type"), source);
            inferred: any = {};
            if t == "var_spec" and not type_name {
                value: any = n.child_by_field_name("value");
                if value is not None {
                    inferred = `dict(
                        _go_inferred_composite_bindings(
                            names, [c for c in value.children if c.is_named], source
                        ),
                    );
                }
            }
            name_node: any;
            for name_node in names {
                name: any = _read_text(name_node, source);
                table.setdefault(name, type_name or inferred.get(name));
            }
        } elif t == "short_var_declaration" {
            left: any;
            right: any;
            (left, right) = (n.child_by_field_name("left"), n.child_by_field_name("right"));
            if left is not None and right is not None {
                names = [c for c in left.children if c.type == "identifier"];
                values: any = [c for c in right.children if c.is_named];
                inferred = `dict(_go_inferred_composite_bindings(names, values, source));
                for name_node in names {
                    name = _read_text(name_node, source);
                    table.setdefault(name, inferred.get(name));
                }
            }
        } elif t == "range_clause" and `any(operator.eq(c.type, ":=") for c in n.children) {
            left = n.child_by_field_name("left");
            for name_node in left.named_children if left is not None else () {
                if name_node.type == "identifier" {
                    table.setdefault(_read_text(name_node, source), None);
                }
            }
        }
        stack.extend(reversed(n.children));
    }
    return table;
}

impl _go_struct_field_types(`root, source: bytes) -> dict[str, dict[str, str]] {
    fields_by_struct: dict[str, dict[str, str]] = {};
    stack: any = [`root];
    while stack {
        n: any = stack.pop();
        if n.type in ("function_declaration", "method_declaration") {
            continue;
        }
        if n.type == "type_spec" {
            name_node: any = n.child_by_field_name("name");
            body: any = n.child_by_field_name("type");
            if name_node is not None and body is not None and body.type == "struct_type" {
                fields: dict[str, str] = {};
                for fdl in body.children {
                    if fdl.type != "field_declaration_list" {
                        continue;
                    }
                    for field in fdl.children {
                        if field.type != "field_declaration" {
                            continue;
                        }
                        type_name: any = _go_single_type_name(
                            field.child_by_field_name("type"), source
                        );
                        for c in field.children if type_name else () {
                            if c.type == "field_identifier" {
                                fields.setdefault(_read_text(c, source), type_name);
                            }
                        }
                    }
                }
                if fields {
                    fields_by_struct[_read_text(name_node, source)] = fields;
                }
            }
            continue;
        }
        stack.extend(n.children);
    }
    return fields_by_struct;
}

impl extract_go(path: Path) -> dict {
    source: any;
    stem: any;
    pkg_scope: any;
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    function_bodies: list[tuple[str, object, str | None, str | None, dict[str, str | None]]];
    callable_nids: set[str];
    callable_class_nids: set[str];
    interface_nids: set[str];
    go_imported_pkgs: dict[str, str];
    file_nid: any;
    decl_registry: any;
    case_groups: dict[str, set[str]];
    local_type_names: any;
    label_to_nid: dict[str, str];
    seen_call_pairs: set[tuple[str, str]];
    raw_calls: list[dict];
    try {
        import tree_sitter_go as tsgo;
        import from tree_sitter { Language, Parser }
    } except ImportError {
        return {"nodes": [], "edges": [], "error": "tree-sitter-go not installed"};
    }

    try {
        language: any = Language(tsgo.language());
        parser: any = Parser(language);
        source = _read_source_bytes(path);
        tree: any = parser.parse(source);
        `root: any = tree.root_node;
    } except Exception as e {
        return {"nodes": [], "edges": [], "error": `str(e)};
    }

    stem = _file_stem(path);
    pkg_scope = path.parent.name or stem;
    str_path = `str(path);
    nodes = [];
    edges = [];
    seen_ids = set[any]();
    function_bodies = [];
    callable_nids = set[any]();
    callable_class_nids = set[any]();
    interface_nids = set[any]();
    go_imported_pkgs = {};

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
    decl_registry = DeclIdRegistry(reserved_ids=(file_nid,));

    def ensure_named_node(name: str, line: int) -> str {
        nid: any = type_symbol_nid(name);
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

    type_params_default_: any = frozenset();

    def emit_go_method_refs(
        func_node, func_nid: str, line: int, type_params: frozenset[str] = type_params_default_
    ) -> None {
        `skip: any = type_params | _go_type_param_names(func_node, source);
        params: any = func_node.child_by_field_name("parameters");
        if params is not None {
            p: any;
            for p in params.children {
                if p.type not in ("parameter_declaration", "variadic_parameter_declaration") {
                    continue;
                }
                type_node: any = p.child_by_field_name("type");
                refs: list[tuple[str, str]] = [];
                _go_collect_type_refs(type_node, source, False, refs, `skip);
                ref_name: any;
                role: any;
                for (ref_name, role) in refs {
                    ctx: any = "generic_arg" if role == "generic_arg" else "parameter_type";
                    tgt: any = ensure_named_node(ref_name, line);
                    if tgt != func_nid {
                        add_edge(func_nid, tgt, "references", line, context=ctx);
                    }
                }
            }
        }
        result: any = func_node.child_by_field_name("result");
        if result is not None {
            if result.type == "parameter_list" {
                for p in result.children {
                    if p.type != "parameter_declaration" {
                        continue;
                    }
                    type_node = p.child_by_field_name("type");
                    if type_node is None {
                        for c in p.children {
                            if c.is_named {
                                type_node = c;
                                break;
                            }
                        }
                    }
                    refs = [];
                    _go_collect_type_refs(type_node, source, False, refs, `skip);
                    for (ref_name, role) in refs {
                        ctx = "generic_arg" if role == "generic_arg" else "return_type";
                        tgt = ensure_named_node(ref_name, line);
                        if tgt != func_nid {
                            add_edge(func_nid, tgt, "references", line, context=ctx);
                        }
                    }
                }
            } else {
                refs = [];
                _go_collect_type_refs(result, source, False, refs, `skip);
                for (ref_name, role) in refs {
                    ctx = "generic_arg" if role == "generic_arg" else "return_type";
                    tgt = ensure_named_node(ref_name, line);
                    if tgt != func_nid {
                        add_edge(func_nid, tgt, "references", line, context=ctx);
                    }
                }
            }
        }
    }

    def emit_go_package_var_type_refs(var_decl) -> None {
        type_nodes: any;
        stack: any = [var_decl];
        while stack {
            n: any = stack.pop();
            if n.type == "func_literal" {
                continue;
            }
            type_nodes = [];
            if n.type in ("var_spec", "composite_literal") {
                type_nodes.append(n.child_by_field_name("type"));
            } elif n.type == "argument_list" {
                type_nodes.extend(c for c in n.children if c.type in _GO_TYPE_NODES);
            }
            for type_node in type_nodes {
                refs: list[tuple[str, str]] = [];
                _go_collect_type_refs(type_node, source, False, refs);
                for (ref_name, role) in refs {
                    ctx: any = "generic_arg" if role == "generic_arg" else "variable_type";
                    line: any = type_node.start_point[0] + 1;
                    add_edge(
                        file_nid, ensure_named_node(ref_name, line), "references", line, context=ctx
                    );
                }
            }
            stack.extend(c for c in n.children if c not in type_nodes);
        }
    }
    case_groups = {};

    def _receiver_type_of(`node) -> str | None {
        receiver: any = `node.child_by_field_name("receiver");
        if not receiver {
            return None;
        }
        for param in receiver.children {
            if param.type == "parameter_declaration" {
                type_node: any = param.child_by_field_name("type");
                if type_node {
                    return _go_strip_generic_args(
                        _read_text(type_node, source).lstrip("*").strip()
                    );
                }
                break;
            }
        }
        return None;
    }

    def _plain_symbol_nid(`node) -> tuple[str, str] | None {
        name_node: any = `node.child_by_field_name("name");
        if not name_node {
            return None;
        }
        name: any = _read_text(name_node, source);
        if `node.type == "method_declaration" {
            receiver_type: any = _receiver_type_of(`node);
            base: any = type_symbol_nid(receiver_type) if receiver_type else stem;
        } else {
            base = stem;
        }
        return (_make_id(base, name), name);
    }

    def _scan_type_names(`node) -> None {
        if `node.type == "type_spec"
            or `node.type == "type_alias" and not _go_alias_re_exports(`node, source)
        {
            name_node: any = `node.child_by_field_name("name");
            if name_node is not None {
                name: any = _read_text(name_node, source);
                case_groups.setdefault(_make_id(pkg_scope, name), set[any]()).add(name);
            }
        }
        if `node.type in ("function_declaration", "method_declaration") {
            return;
        }
        for child in `node.children {
            _scan_type_names(child);
        }
    }

    def _scan_declarations(`node) -> None {
        if `node.type == "type_spec" {
            name_node: any = `node.child_by_field_name("name");
            if name_node is not None {
                owner_nid: any = type_symbol_nid(_read_text(name_node, source));
                for body in `node.children {
                    if body.type != "interface_type" {
                        continue;
                    }
                    for elem in body.children {
                        if elem.type != "method_elem" {
                            continue;
                        }
                        method_name: any = elem.child_by_field_name("name");
                        if method_name is not None {
                            name: any = _read_text(method_name, source);
                            plain_nid: any = _make_id(owner_nid, name);
                            case_groups.setdefault(plain_nid, set[any]()).add(name);
                        }
                    }
                }
            }
        }
        if `node.type in ("function_declaration", "method_declaration") {
            found: any = _plain_symbol_nid(`node);
            if found {
                case_groups.setdefault(found[0], set[any]()).add(found[1]);
            }
            return;
        }
        for child in `node.children {
            _scan_declarations(child);
        }
    }

    def symbol_nid(plain_nid: str, name: str, kind: str = "fn") -> str {
        nid: any = plain_nid;
        names: any = case_groups.get(plain_nid) or set[any]();
        if len(names) >= 2
            and not (
                len([n for n in names if n[:1].isupper()]) == 1
                and name == [n for n in names if n[:1].isupper()][0]
            )
        {
            salt: any = hashlib.sha1(name.encode("utf-8"), usedforsecurity=False).hexdigest()[:6];
            nid = _make_id(plain_nid, salt);
        }
        return decl_registry.resolve(nid, name, kind, seen_ids);
    }

    def type_symbol_nid(name: str) -> str {
        plain_nid: any = _make_id(pkg_scope, name);
        if name not in case_groups.get(plain_nid, ()) {
            return decl_registry.resolve(plain_nid, name, "type", seen_ids);
        }
        return symbol_nid(plain_nid, name, "type");
    }

    def walk(`node) -> None {
        fc: any;
        t: any = `node.type;

        if t == "function_declaration" {
            name_node: any = `node.child_by_field_name("name");
            if name_node {
                func_name: any = _read_text(name_node, source);
                line: any = `node.start_point[0] + 1;
                func_nid: any = symbol_nid(_make_id(stem, func_name), func_name);
                add_node(func_nid, f"{func_name}()", line);
                callable_nids.add(func_nid);
                add_edge(file_nid, func_nid, "contains", line);
                emit_go_method_refs(`node, func_nid, line);
                body: any = `node.child_by_field_name("body");
                if body {
                    function_bodies.append((
                        func_nid,
                        body,
                        None,
                        None,
                        _go_receiver_type_table(`node, source),
                    ));
                }
            }
            return;
        }

        if t == "method_declaration" {
            receiver: any = `node.child_by_field_name("receiver");
            receiver_type: str | None = None;
            receiver_name: str | None = None;
            if receiver {
                for param in receiver.children {
                    if param.type == "parameter_declaration" {
                        type_node: any = param.child_by_field_name("type");
                        if type_node {
                            receiver_type = _go_strip_generic_args(
                                _read_text(type_node, source).lstrip("*").strip()
                            );
                        }
                        name_node = param.child_by_field_name("name");
                        if name_node {
                            receiver_name = _read_text(name_node, source);
                        }
                        break;
                    }
                }
            }
            name_node = `node.child_by_field_name("name");
            if not name_node {
                return;
            }
            method_name: any = _read_text(name_node, source);
            line = `node.start_point[0] + 1;

            if receiver_type {
                parent_nid: any = type_symbol_nid(receiver_type);
                add_node(parent_nid, receiver_type, line);
                callable_class_nids.add(parent_nid);
                method_nid: any = symbol_nid(_make_id(parent_nid, method_name), method_name);
                add_node(method_nid, f".{method_name}()", line);
                add_edge(parent_nid, method_nid, "method", line);
            } else {
                method_nid = symbol_nid(_make_id(stem, method_name), method_name);
                add_node(method_nid, f"{method_name}()", line);
                add_edge(file_nid, method_nid, "contains", line);
            }
            callable_nids.add(method_nid);

            emit_go_method_refs(`node, method_nid, line);
            body = `node.child_by_field_name("body");
            if body {
                function_bodies.append((
                    method_nid,
                    body,
                    receiver_name,
                    receiver_type,
                    _go_receiver_type_table(`node, source),
                ));
            }
            return;
        }

        if t == "type_declaration" {
            child: any;
            for child in `node.children {
                if child.type not in ("type_spec", "type_alias") {
                    continue;
                }
                if child.type == "type_alias" and _go_alias_re_exports(child, source) {
                    continue;
                }
                name_node = child.child_by_field_name("name");
                if not name_node {
                    continue;
                }
                type_name: any = _read_text(name_node, source);
                line = child.start_point[0] + 1;
                type_nid: any = type_symbol_nid(type_name);
                add_node(type_nid, type_name, line);
                callable_class_nids.add(type_nid);
                add_edge(file_nid, type_nid, "contains", line);
                if child.type == "type_alias" {
                    continue;
                }
                type_params: any = _go_type_param_names(child, source);
                type_body: any = None;
                for tc in child.children {
                    if tc.type in ("struct_type", "interface_type") {
                        type_body = tc;
                        break;
                    }
                }
                if type_body is None {
                    continue;
                }
                if type_body.type == "struct_type" {
                    for fdl in type_body.children {
                        if fdl.type != "field_declaration_list" {
                            continue;
                        }
                        for field in fdl.children {
                            if field.type != "field_declaration" {
                                continue;
                            }
                            has_name: any = `any(
                                operator.eq(fc.type, "field_identifier") for fc in field.children
                            );
                            type_node = field.child_by_field_name("type");
                            if type_node is None {
                                for fc in field.children {
                                    if fc.is_named and fc.type != "field_identifier" {
                                        type_node = fc;
                                        break;
                                    }
                                }
                            }
                            refs: list[tuple[str, str]] = [];
                            _go_collect_type_refs(type_node, source, False, refs, type_params);
                            ref_name: any;
                            role: any;
                            for (ref_name, role) in refs {
                                tgt: any = ensure_named_node(ref_name, field.start_point[0] + 1);
                                if tgt == type_nid {
                                    continue;
                                }
                                if not has_name and role == "type" {
                                    add_edge(type_nid, tgt, "embeds", field.start_point[0] + 1);
                                } else {
                                    ctx: any = "generic_arg" if role == "generic_arg" else "field";
                                    add_edge(
                                        type_nid,
                                        tgt,
                                        "references",
                                        field.start_point[0] + 1,
                                        context=ctx,
                                    );
                                }
                            }
                        }
                    }
                } elif type_body.type == "interface_type" {
                    interface_nids.add(type_nid);
                    for elem in type_body.children {
                        if elem.type == "method_elem" {
                            m_name_node: any = elem.child_by_field_name("name");
                            if m_name_node is None {
                                for mc in elem.children {
                                    if mc.type == "field_identifier" {
                                        m_name_node = mc;
                                        break;
                                    }
                                }
                            }
                            if m_name_node is None {
                                continue;
                            }
                            m_name: any = _read_text(m_name_node, source);
                            m_line: any = elem.start_point[0] + 1;
                            m_nid: any = symbol_nid(_make_id(type_nid, m_name), m_name);
                            add_node(m_nid, f".{m_name}()", m_line);
                            add_edge(type_nid, m_nid, "method", m_line);
                            emit_go_method_refs(elem, m_nid, m_line, type_params);
                            continue;
                        }
                        if elem.type != "type_elem" {
                            continue;
                        }
                        is_type_set: any = `any(
                            operator.eq(c.type, "|") or operator.eq(c.type, "negated_type")
                            for c in elem.children,
                        );
                        refs = [];
                        for sub in elem.children {
                            if sub.is_named {
                                _go_collect_type_refs(sub, source, False, refs, type_params);
                            }
                        }
                        for (ref_name, role) in refs {
                            tgt = ensure_named_node(ref_name, elem.start_point[0] + 1);
                            if tgt == type_nid {
                                continue;
                            }
                            if is_type_set {
                                add_edge(
                                    type_nid,
                                    tgt,
                                    "references",
                                    elem.start_point[0] + 1,
                                    context="type_constraint",
                                );
                            } elif role == "type" {
                                add_edge(type_nid, tgt, "embeds", elem.start_point[0] + 1);
                            } else {
                                add_edge(
                                    type_nid,
                                    tgt,
                                    "references",
                                    elem.start_point[0] + 1,
                                    context="generic_arg",
                                );
                            }
                        }
                    }
                }
            }
            return;
        }

        if t == "var_declaration"
            and `node.parent is not None
            and `node.parent.type == "source_file"
        {
            emit_go_package_var_type_refs(`node);
            function_bodies.append((
                file_nid,
                `node,
                None,
                None,
                _go_receiver_type_table(`node, source),
            ));
            return;
        }

        if t == "import_declaration" {
            for child in `node.children {
                if child.type == "import_spec_list" {
                    for spec in child.children {
                        if spec.type == "import_spec" {
                            path_node: any = spec.child_by_field_name("path");
                            if path_node {
                                raw: any = _read_text(path_node, source).strip("\"");
                                tgt_nid: any = _make_id("go", "pkg", raw);
                                add_edge(
                                    file_nid,
                                    tgt_nid,
                                    "imports_from",
                                    spec.start_point[0] + 1,
                                    context="import",
                                );
                                alias: any = spec.child_by_field_name("name");
                                local_name: any = _read_text(alias, source)
                                    if alias
                                    else raw.split("/")[-1];
                                if local_name and local_name != "_" and local_name != "." {
                                    go_imported_pkgs[local_name] = raw;
                                }
                            }
                        }
                    }
                } elif child.type == "import_spec" {
                    path_node = child.child_by_field_name("path");
                    if path_node {
                        raw = _read_text(path_node, source).strip("\"");
                        tgt_nid = _make_id("go", "pkg", raw);
                        add_edge(
                            file_nid,
                            tgt_nid,
                            "imports_from",
                            child.start_point[0] + 1,
                            context="import",
                        );
                        alias = child.child_by_field_name("name");
                        local_name = _read_text(alias, source) if alias else raw.split("/")[-1];
                        if local_name and local_name != "_" and local_name != "." {
                            go_imported_pkgs[local_name] = raw;
                        }
                    }
                }
            }
            return;
        }

        for child in `node.children {
            walk(child);
        }
    }

    _scan_type_names(`root);
    _scan_declarations(`root);
    walk(`root);
    package_path: any = _go_import_path_for_file(path.absolute(), path.absolute().parent);
    n: any;
    for n in nodes {
        if n["id"] in callable_nids or n["id"] in callable_class_nids {
            n["_callable"] = True;
            if n["id"] in callable_class_nids {
                n["_callable_class"] = True;
                if package_path {
                    n["_go_package_path"] = package_path;
                }
            }
        }
        if n["id"] in interface_nids {
            n["metadata"] = {"language": "go", "kind": "interface"};
        }
    }
    struct_fields: dict[str, dict[str, str]] = {};
    for (name, fields) in _go_struct_field_types(`root, source).items() {
        typed: dict[str, str] = {};
        for (field, type_name) in fields.items() {
            alias: any;
            dot: any;
            bare: any;
            (alias, dot, bare) = type_name.partition(".") as any;
            if not dot {
                typed[field] = type_name;
            } elif alias in go_imported_pkgs {
                typed[field] = f"{go_imported_pkgs[alias]}.{bare}";
            }
        }
        if typed {
            struct_fields[type_symbol_nid(name)] = `dict(sorted(typed.items()));
        }
    }
    if struct_fields {
        file_node: any = next(n for n in nodes if n["id"] == file_nid);
        file_node["_go_fields"] = `dict(sorted(struct_fields.items()));
    }

    type_table: any = _go_receiver_type_table(`root, source);
    package_types: any = _go_receiver_type_table(`root, source, package_only=True);
    local_type_names = {n["label"] for n in nodes if n["id"] in callable_class_nids};

    method_nids: any = {e["target"] for e in edges if e["relation"] == "method"};
    label_to_nid = {};
    for n in nodes {
        if n["id"] in method_nids {
            continue;
        }
        raw: any = n["label"];
        normalised: any = raw.strip("()").lstrip(".");
        label_to_nid[normalised] = n["id"];
    }

    seen_call_pairs = set[any]();
    raw_calls = [];

    def walk_calls(
        `node,
        caller_nid: str,
        self_name: str | None,
        self_type: str | None,
        scope_types: dict[str, str | None],
    ) -> None {
        if `node.type in ("function_declaration", "method_declaration") {
            return;
        }
        if `node.type
            in (
                "block",
                "if_statement",
                "for_statement",
                "expression_switch_statement",
                "type_switch_statement",
                "select_statement",
                "expression_case",
                "type_case",
                "communication_case",
                "default_case",
                "func_literal",
            )
        {
            scope_types = scope_types.copy();
            if `node.type == "func_literal" {
                scope_types.update(_go_receiver_type_table(`node, source));
            }
        }
        if `node.type == "call_expression" {
            func_node: any = `node.child_by_field_name("function");
            callee_name: str | None = None;
            is_member_call: bool = False;
            is_bare_identifier: bool = False;
            package_receiver: str | None = None;
            member_receiver: str | None = None;
            member_receiver_type: str | None = None;
            field_owner: str | None = None;
            import_path: str | None = None;
            if func_node {
                if func_node.type == "identifier" {
                    is_bare_identifier = True;
                    callee_name = _read_text(func_node, source);
                } elif func_node.type == "selector_expression" {
                    field: any = func_node.child_by_field_name("field");
                    operand: any = func_node.child_by_field_name("operand");
                    receiver_name: any = _read_text(operand, source) if operand else "";
                    is_member_call = receiver_name in scope_types
                        or receiver_name not in go_imported_pkgs;
                    if not is_member_call {
                        package_receiver = receiver_name;
                        import_path = go_imported_pkgs[receiver_name];
                    } elif operand is not None and operand.type == "identifier" {
                        member_receiver = receiver_name;
                        member_receiver_type = scope_types.get(receiver_name);
                        if receiver_name not in scope_types and receiver_name in local_type_names {
                            member_receiver_type = receiver_name;
                        }
                    } elif operand is not None and operand.type == "parenthesized_expression" {
                        expression: any = operand;
                        while expression.type == "parenthesized_expression"
                            and expression.named_children
                        {
                            expression = expression.named_children[0];
                        }
                        if expression.type == "unary_expression"
                            and _read_text(expression, source).startswith("*")
                        {
                            expression = expression.child_by_field_name("operand");
                            name: any = _read_text(expression, source)
                                if expression is not None
                                else "";
                            if name in local_type_names and name not in scope_types {
                                member_receiver = name;
                                member_receiver_type = name;
                            }
                        }
                    } elif operand is not None and operand.type == "selector_expression" {
                        inner: any = operand.child_by_field_name("operand");
                        if self_name
                            and inner is not None
                            and inner.type == "identifier"
                            and _read_text(inner, source) == self_name
                            and scope_types.get(self_name) == self_type
                        {
                            member_receiver = _read_text(
                                operand.child_by_field_name("field"), source
                            );
                            field_owner = self_type;
                        }
                    }
                    if field {
                        callee_name = _read_text(field, source);
                    }
                }
            }
            if is_bare_identifier and callee_name in _GO_PREDECLARED_FUNCS {
                callee_name = None;
            }
            if callee_name and callee_name not in _LANGUAGE_BUILTIN_GLOBALS {
                tgt_nid: any = None
                    if import_path or is_member_call
                    else label_to_nid.get(callee_name);
                if tgt_nid and tgt_nid != caller_nid {
                    pair: any = (caller_nid, tgt_nid);
                    if pair not in seen_call_pairs {
                        seen_call_pairs.add(pair);
                        line: any = `node.start_point[0] + 1;
                        edges.append({
                            "source": caller_nid,
                            "target": tgt_nid,
                            "relation": "calls",
                            "context": "call",
                            "confidence": "EXTRACTED",
                            "source_file": str_path,
                            "source_location": f"L{line}",
                            "weight": 1.0,
                        });
                    }
                } elif callee_name {
                    raw_calls.append({
                        "caller_nid": caller_nid,
                        "callee": callee_name,
                        "is_member_call": is_member_call,
                        "language": "go",
                        "receiver": package_receiver,
                        "member_receiver": member_receiver,
                        "receiver_type": member_receiver_type,
                        "receiver_bound": not field_owner and member_receiver in scope_types,
                        "field_owner": field_owner,
                        "import_path": import_path,
                        "source_file": str_path,
                        "source_location": f"L{`node.start_point[0] + 1}",
                    });
                }
            }
            args: any = `node.child_by_field_name("arguments");
            for arg in args.children if args is not None else () {
                if arg.type != "selector_expression" {
                    continue;
                }
                operand = arg.child_by_field_name("operand");
                field = arg.child_by_field_name("field");
                if operand is None or field is None {
                    continue;
                }
                arg_field_owner: str | None = None;
                if operand.type == "identifier" {
                    name = _read_text(operand, source);
                    if name in go_imported_pkgs and name not in scope_types {
                        continue;
                    }
                    arg_receiver_type: any = scope_types.get(name);
                } elif operand.type == "selector_expression" {
                    inner = operand.child_by_field_name("operand");
                    if not (
                        self_name
                        and inner is not None
                        and inner.type == "identifier"
                        and _read_text(inner, source) == self_name
                        and scope_types.get(self_name) == self_type
                    ) {
                        continue;
                    }
                    name = _read_text(operand.child_by_field_name("field"), source);
                    arg_receiver_type = None;
                    arg_field_owner = self_type;
                } else {
                    continue;
                }
                raw_calls.append({
                    "caller_nid": caller_nid,
                    "callee": _read_text(field, source),
                    "is_member_call": True,
                    "indirect": True,
                    "context": "argument",
                    "language": "go",
                    "receiver": None,
                    "member_receiver": name,
                    "receiver_type": arg_receiver_type,
                    "receiver_bound": name in scope_types if not arg_field_owner else False,
                    "field_owner": arg_field_owner,
                    "import_path": None,
                    "source_file": str_path,
                    "source_location": f"L{arg.start_point[0] + 1}",
                });
            }
        }
        for child in `node.children {
            walk_calls(child, caller_nid, self_name, self_type, scope_types);
            if child.type in ("short_var_declaration", "var_spec", "range_clause") {
                scope_types.update(_go_receiver_type_table(child, source));
            }
        }
    }

    for (caller_nid, body_node, self_name, self_type, scope_types) in function_bodies {
        walk_calls(body_node, caller_nid, self_name, self_type, scope_types);
    }

    valid_ids: any = seen_ids;
    clean_edges: any = [];
    for `edge in edges {
        src: any;
        tgt: any;
        (src, tgt) = (`edge["source"], `edge["target"]);
        if src in valid_ids
            and (tgt in valid_ids or `edge["relation"] in ("imports", "imports_from"))
        {
            clean_edges.append(`edge);
        }
    }

    return {
        "nodes": nodes,
        "edges": clean_edges,
        "raw_calls": raw_calls,
        "go_imports": `dict(go_imported_pkgs),
        "go_type_table": {
            "path": str_path,
            "table": type_table,
            "package_vars": package_types,
            "package_path": package_path,
        },
    };
}
