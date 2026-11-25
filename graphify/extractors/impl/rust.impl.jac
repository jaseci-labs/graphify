impl _rust_collect_type_refs(
    `node,
    source: bytes,
    generic: bool,
    out: list[tuple[str, str]],
    local_types: frozenset[str] = local_types_default_,
) -> None {
    def _keep(text: str) -> bool {
        return `bool(text) and (text not in _RUST_BUILTIN_TYPES or text in local_types);
    }

    if `node is None {
        return;
    }
    t: any = `node.type;
    if t == "primitive_type" {
        return;
    }
    if t == "type_identifier" {
        text: any = _read_text(`node, source);
        if _keep(text) {
            out.append((text, "generic_arg" if generic else "type"));
        }
        return;
    }
    if t == "scoped_type_identifier" {
        text = _read_text(`node, source).rsplit("::", 1)[-1];
        if _keep(text) {
            out.append((text, "generic_arg" if generic else "type"));
        }
        return;
    }
    if t == "generic_type" {
        name_node: any = `node.child_by_field_name("type");
        if name_node is None {
            c: any;
            for c in `node.children {
                if c.type in ("type_identifier", "scoped_type_identifier") {
                    name_node = c;
                    break;
                }
            }
        }
        if name_node is not None {
            text = _read_text(name_node, source).rsplit("::", 1)[-1];
            if _keep(text) {
                out.append((text, "generic_arg" if generic else "type"));
            }
        }
        for c in `node.children {
            if c.type == "type_arguments" {
                for arg in c.children {
                    if arg.is_named {
                        _rust_collect_type_refs(arg, source, True, out, local_types);
                    }
                }
            }
        }
        return;
    }
    if t in ("reference_type", "pointer_type", "array_type", "tuple_type", "slice_type") {
        for c in `node.children {
            if c.is_named {
                _rust_collect_type_refs(c, source, generic, out, local_types);
            }
        }
        return;
    }
    if `node.is_named {
        for c in `node.children {
            if c.is_named {
                _rust_collect_type_refs(c, source, generic, out, local_types);
            }
        }
    }
}

impl _rust_simple_generic_impl_key(`node, source: bytes) -> str | None {
    if `node.child_by_field_name("trait") is not None {
        return None;
    }
    parameters: any = `node.child_by_field_name("type_parameters");
    owner_type: any = `node.child_by_field_name("type");
    if parameters is None or owner_type is None or owner_type.type != "generic_type" {
        return None;
    }
    if `any(operator.eq(child.type, "where_clause") for child in `node.named_children) {
        return None;
    }

    parameter_names: list[str] = [];
    for parameter in parameters.named_children {
        if parameter.type != "type_parameter" {
            return None;
        }
        named: any = parameter.named_children;
        if len(named) != 1 or named[0].type != "type_identifier" {
            return None;
        }
        name: any = _read_text(named[0], source);
        if not name or name in parameter_names {
            return None;
        }
        parameter_names.append(name);
    }
    if not parameter_names {
        return None;
    }

    owner: any = owner_type.child_by_field_name("type");
    if owner is None or owner.type != "type_identifier" {
        return None;
    }
    arguments: any = next(
        (child for child in owner_type.named_children if child.type == "type_arguments"), None
    );
    if arguments is None {
        return None;
    }
    argument_names: any = [
        _read_text(argument, source)
        for argument in arguments.named_children
        if argument.type == "type_identifier"
    ];
    if len(argument_names) != len(arguments.named_children) {
        return None;
    }
    if argument_names != parameter_names {
        return None;
    }

    owner_name: any = _read_text(owner, source);
    return f"{owner_name}/{len(parameter_names)}" if owner_name else None;
}

impl _rust_use_module(argument: str) -> str {
    clean: any = argument.split("{")[0].rstrip(":").rstrip("*").rstrip(":");
    return clean.split("::")[-1].strip();
}

impl _rust_use_bindings(
    `node, source: bytes, prefix: str = "", self_path: str = ""
) -> list[tuple[str, int]] {
    t: any;
    line: any;
    (t, line) = (`node.type, `node.start_point[0] + 1);
    if t == "use_list" {
        return [
            binding
            for child in `node.named_children
            for binding in _rust_use_bindings(child, source, prefix, self_path)
        ];
    }
    if t == "scoped_use_list" {
        path: any;
        group: any;
        (path, group) = (`node.child_by_field_name("path"), `node.child_by_field_name("list"));
        lead: any = prefix
            + source[`node.start_byte:group.start_byte].decode("utf-8", errors="replace")
            if group is not None
            else "";
        owner: any = prefix + _read_text(path, source) if path is not None else "";
        return _rust_use_bindings(group, source, lead, owner) if group is not None else [];
    }
    alias: any = "";
    if t == "use_as_clause" {
        clause: any;
        (clause, `node) = (`node, `node.child_by_field_name("path"));
        alias = source[`node.end_byte:clause.end_byte].decode("utf-8", errors="replace")
            if `node is not None
            else "";
    }
    if `node is not None and `node.type == "self" and self_path {
        return [(self_path + alias, line)];
    }
    if `node is not None
        and `node.type
            in ("use_wildcard", "identifier", "scoped_identifier", "crate", "self", "super")
    {
        return [(prefix + _read_text(`node, source) + alias, line)];
    }
    return [];
}

impl _rust_macro_arg_calls(token_tree) -> list[tuple[str, int]] {
    found: list[tuple[str, int]] = [];
    stack: any = [token_tree];
    while stack {
        tree: any = stack.pop();
        children: any = tree.children;
        for (i, child) in enumerate(children) {
            if child.type == "token_tree" {
                stack.append(child);
                continue;
            }
            if child.type != "identifier" or i + 1 >= len(children) {
                continue;
            }
            nxt: any = children[i + 1];
            if nxt.type != "token_tree" or not nxt.children or nxt.children[0].type != "(" {
                continue;
            }
            if i > 0 and children[i - 1].type in (".", "::", "fn", "$", "#") {
                continue;
            }
            name: any = child.text.decode("utf-8", errors="replace") if child.text else "";
            if name {
                found.append((name, child.start_point[0] + 1));
            }
        }
    }
    found.sort(key=lambda (item) -> any { item[1] });
    return found;
}

impl _rust_qualifier_type(path_node, source: bytes) -> str | None {
    if path_node is None {
        return None;
    }
    last: any = _rust_type_last_segment(_read_text(path_node, source));
    return last if last[:1].isupper() or last in _RUST_PRIMITIVE_TYPES else None;
}

impl _rust_is_trait_ref(`node, idx: int, role: str) -> bool {
    if `node.type == "higher_ranked_trait_bound" {
        `node = `node.child_by_field_name("type") or `node;
    }
    return operator.eq(idx, 0)
        and operator.eq(role, "type")
        and operator.ne(`node.type, "function_type");
}

impl _rust_type_last_segment(text: str) -> str {
    text = re.sub("^(?:&\\s*(?:'\\w+\\s+)?(?:mut\\s+)?|dyn\\s+)", "", text.strip());
    depth: any;
    kept: any;
    (depth, kept) = (0, []);
    for ch in text {
        if ch == "<" {
            depth += 1;
        } elif ch == ">" {
            depth = max(depth - 1, 0);
        } elif depth == 0 {
            kept.append(ch);
        }
    }
    segments: any = [s.strip() for s in "".join(kept).split("::") if s.strip()];
    return segments[-1] if segments else "";
}

impl extract_rust(path: Path) -> dict {
    source: any;
    stem: any;
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    function_bodies: list[tuple[str, object, str | None, str | None]];
    impl_keys: dict[str, str | None];
    local_types: set[str];
    local_type_names: any;
    use_roots: dict[str, set[str]];
    macro_nids_by_name: dict[str, str];
    inline_mods: set[str];
    impl_methods: dict[tuple[str, str], set[str]];
    node_by_id: dict[str, dict];
    file_nid: any;
    decl_registry: any;
    items_by_id: dict[str, set[tuple[bool, str]]];
    declared_type_names: dict[str, set[str]];
    impl_method_names: dict[str, set[str]];
    impl_bare_names: dict[int, str];
    label_to_nid: dict[str, str];
    method_label_to_nid: dict[str, str];
    type_nids: set[str];
    seen_call_pairs: set[tuple[str, str]];
    raw_calls: list[dict];
    macro_arg_edges: list[dict];
    try {
        import tree_sitter_rust as tsrust;
        import from tree_sitter { Language, Parser }
    } except ImportError {
        return {"nodes": [], "edges": [], "error": "tree-sitter-rust not installed"};
    }

    try {
        language: any = Language(tsrust.language());
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
    impl_keys = {};
    local_types = set[any]();

    def _scan_local_types(scan_node) -> None {
        if scan_node.type in ("struct_item", "enum_item", "trait_item", "union_item", "type_item") {
            name_node: any = scan_node.child_by_field_name("name");
            if name_node is not None {
                name: any = _read_text(name_node, source);
                if name {
                    local_types.add(name);
                }
            }
        }
        for child in scan_node.children {
            _scan_local_types(child);
        }
    }

    _scan_local_types(`root);
    local_type_names = frozenset(local_types);
    use_roots = {};
    macro_nids_by_name = {};
    inline_mods = set[any]();
    _mod_stack: any = [`root];
    while _mod_stack {
        _n: any = _mod_stack.pop();
        if _n.type == "mod_item" and _n.child_by_field_name("body") is not None {
            _name: any = _n.child_by_field_name("name");
            if _name is not None {
                inline_mods.add(_read_text(_name, source));
            }
        }
        _mod_stack.extend(_n.children);
    }
    impl_methods = {};
    node_by_id = {};

    def add_node(nid: str, label: str, line: int) -> None {
        if nid not in seen_ids {
            seen_ids.add(nid);
            node_by_id[nid] = {
                "id": nid,
                "label": label,
                "file_type": "code",
                "source_file": str_path,
                "source_location": f"L{line}",
            };
            nodes.append(node_by_id[nid]);
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
    items_by_id = {};
    declared_type_names = {};
    impl_method_names = {};

    def _scan_type_items(`node) -> None {
        t: any = `node.type;
        if t
            in (
                "struct_item",
                "enum_item",
                "trait_item",
                "union_item",
                "type_item",
                "function_item",
                "function_signature_item",
                "static_item",
                "const_item",
            )
        {
            name_node: any = `node.child_by_field_name("name");
            if name_node {
                name: any = _read_text(name_node, source);
                if t in ("static_item", "const_item") and name == "_" {
                    return;
                }
                nid: any = _make_id(stem, name);
                is_type: any = t
                    in ("struct_item", "enum_item", "trait_item", "union_item", "type_item");
                items_by_id.setdefault(nid, set[any]()).add((is_type, name));
                if is_type {
                    declared_type_names.setdefault(nid, set[any]()).add(name);
                }
            }
            return;
        }
        if t == "impl_item" {
            type_node: any = `node.child_by_field_name("type");
            if type_node is not None {
                type_name: any = _read_text(type_node, source).strip();
                refs: list[tuple[str, str]] = [];
                _rust_collect_type_refs(type_node, source, False, refs);
                bare: any = next((ref for (ref, role) in refs if role == "type"), type_name);
                impl_pre_nid: any = _make_id(stem, type_name);
                items_by_id.setdefault(impl_pre_nid, set[any]()).add((True, bare));
                impl_bare_names[`node.start_byte] = bare;
                body: any = `node.child_by_field_name("body");
                if body is not None {
                    child: any;
                    for child in body.children {
                        if child.type
                            not in (
                                "function_item",
                                "function_signature_item",
                                "static_item",
                                "const_item",
                            )
                        {
                            continue;
                        }
                        member_name_node: any = child.child_by_field_name("name");
                        if member_name_node is None {
                            continue;
                        }
                        member_name: any = _read_text(member_name_node, source);
                        if not member_name or member_name == "_" {
                            continue;
                        }
                        member_key: any = _make_id(impl_pre_nid, member_name);
                        impl_method_names.setdefault(member_key, set[any]()).add(member_name);
                    }
                }
            }
            return;
        }
        if t == "use_declaration" {
            return;
        }
        for child in `node.children {
            _scan_type_items(child);
        }
    }

    impl_bare_names = {};
    _scan_type_items(`root);
    def only_types(item_nid: str, type_name: str) -> bool {
        return all(is_type for (is_type, item_name) in items_by_id[item_nid] if item_name == type_name);
    }
    local_type_names = frozenset(
        declared
        for (declared_nid, declared_names) in declared_type_names.items()
        for declared in declared_names
        if only_types(declared_nid, declared),
    );
    def file_item_nid(plain_nid: str, name: str) -> str {
        nid: any = plain_nid;
        names: any = {item_name for (_is_type, item_name) in items_by_id.get(plain_nid, ())};
        if len(names) >= 2 and name in names and declared_type_names.get(plain_nid) != {name} {
            salt: any = hashlib.sha1(name.encode("utf-8"), usedforsecurity=False).hexdigest()[:6];
            nid = _make_id(plain_nid, salt);
        }
        return decl_registry.resolve(nid, name, "type", seen_ids);
    }
    def impl_member_nid(parent_impl_nid: str, pre_impl_nid: str | None, name: str) -> str {
        nid: any = _make_id(parent_impl_nid, name);
        if pre_impl_nid is None {
            return nid;
        }
        names: any = impl_method_names.get(_make_id(pre_impl_nid, name), ());
        if len(names) >= 2 and name in names {
            salt: any = hashlib.sha1(name.encode("utf-8"), usedforsecurity=False).hexdigest()[:6];
            nid = _make_id(nid, salt);
        }
        return nid;
    }

    def ensure_named_node(name: str, line: int) -> str {
        nid: any = file_item_nid(_make_id(stem, name), name);
        if nid in seen_ids or name in local_type_names {
            return nid;
        }
        nid = _make_id(name);
        if nid not in seen_ids {
            seen_ids.add(nid);
            node_by_id[nid] = {
                "id": nid,
                "label": name,
                "file_type": "code",
                "source_file": "",
                "source_location": "",
                "origin_file": str_path,
            };
            nodes.append(node_by_id[nid]);
        }
        return nid;
    }

    def emit_param_return_refs(func_node, func_nid: str, line: int) -> None {
        params: any = func_node.child_by_field_name("parameters");
        if params is not None {
            for p in params.children {
                if p.type != "parameter" {
                    continue;
                }
                type_node: any = p.child_by_field_name("type");
                refs: list[tuple[str, str]] = [];
                _rust_collect_type_refs(type_node, source, False, refs, local_type_names);
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
        return_type: any = func_node.child_by_field_name("return_type");
        if return_type is not None {
            refs = [];
            _rust_collect_type_refs(return_type, source, False, refs, local_type_names);
            for (ref_name, role) in refs {
                ctx = "generic_arg" if role == "generic_arg" else "return_type";
                tgt = ensure_named_node(ref_name, line);
                if tgt != func_nid {
                    add_edge(func_nid, tgt, "references", line, context=ctx);
                }
            }
        }
    }

    def walk(
        `node,
        parent_impl_nid: str | None = None,
        parent_impl_type: str | None = None,
        parent_impl_key: str | None = None,
        parent_impl_pre_nid: str | None = None,
    ) -> None {
        item_nid: any;
        vc: any;
        scope_mods: any;
        reexport: any;
        t: any = `node.type;

        if t == "function_item" {
            name_node: any = `node.child_by_field_name("name");
            if name_node {
                func_name: any = _read_text(name_node, source);
                line: any = `node.start_point[0] + 1;
                if parent_impl_nid {
                    func_nid: any = impl_member_nid(
                        parent_impl_nid, parent_impl_pre_nid, func_name
                    );
                    add_node(func_nid, f".{func_name}()", line);
                    add_edge(parent_impl_nid, func_nid, "method", line);
                    if parent_impl_type {
                        owner: any = _rust_type_last_segment(parent_impl_type);
                        impl_methods.setdefault((owner, func_name), set[any]()).add(func_nid);
                    }
                } else {
                    func_nid = file_item_nid(_make_id(stem, func_name), func_name);
                    add_node(func_nid, f"{func_name}()", line);
                    add_edge(file_nid, func_nid, "contains", line);
                }
                emit_param_return_refs(`node, func_nid, line);
                body: any = `node.child_by_field_name("body");
                if body {
                    function_bodies.append((func_nid, body, parent_impl_type, parent_impl_key));
                }
            }
            return;
        }

        if t == "function_signature_item" {
            name_node = `node.child_by_field_name("name");
            if name_node {
                func_name = _read_text(name_node, source);
                line = `node.start_point[0] + 1;
                if parent_impl_nid {
                    func_nid = impl_member_nid(parent_impl_nid, parent_impl_pre_nid, func_name);
                    add_node(func_nid, f".{func_name}()", line);
                    add_edge(parent_impl_nid, func_nid, "method", line);
                } else {
                    func_nid = file_item_nid(_make_id(stem, func_name), func_name);
                    add_node(func_nid, f"{func_name}()", line);
                    add_edge(file_nid, func_nid, "contains", line);
                }
                emit_param_return_refs(`node, func_nid, line);
            }
            return;
        }

        if t == "macro_definition" {
            name_node = `node.child_by_field_name("name");
            if name_node {
                macro_name: any = _read_text(name_node, source);
                if macro_name {
                    line = `node.start_point[0] + 1;
                    macro_nid: any = _make_id(stem, "macro", macro_name);
                    add_node(macro_nid, f"{macro_name}!", line);
                    add_edge(file_nid, macro_nid, "contains", line);
                    macro_nids_by_name.setdefault(macro_name, macro_nid);
                }
            }
            return;
        }
        if t == "type_item"
            and `node.parent is not None
            and `node.parent.parent is not None
            and `node.parent.parent.type == "impl_item"
        {
            return;
        }
        if t in ("struct_item", "enum_item", "trait_item", "union_item", "type_item") {
            name_node = `node.child_by_field_name("name");
            if name_node {
                item_name: any = _read_text(name_node, source);
                line = `node.start_point[0] + 1;
                item_nid = file_item_nid(_make_id(stem, item_name), item_name);
                add_node(item_nid, item_name, line);
                declaration_node: any = node_by_id[item_nid];
                declaration_node["_rust_declaration_count"] = declaration_node.get(
                    "_rust_declaration_count", 0
                )
                    + 1;
                add_edge(file_nid, item_nid, "contains", line);
                if t == "trait_item" {
                    c: any;
                    for c in `node.children {
                        if c.type != "trait_bounds" {
                            continue;
                        }
                        for sub in c.children {
                            if not sub.is_named {
                                continue;
                            }
                            refs: list[tuple[str, str]] = [];
                            _rust_collect_type_refs(sub, source, False, refs, local_type_names);
                            idx: any;
                            ref_name: any;
                            role: any;
                            for (idx, (ref_name, role)) in enumerate(refs) {
                                tgt: any = ensure_named_node(ref_name, line);
                                if tgt == item_nid {
                                    continue;
                                }
                                rel: any = "inherits"
                                    if _rust_is_trait_ref(sub, idx, role)
                                    else "references";
                                if rel == "inherits" {
                                    add_edge(item_nid, tgt, "inherits", line);
                                } else {
                                    add_edge(
                                        item_nid, tgt, "references", line, context="generic_arg"
                                    );
                                }
                            }
                        }
                    }
                }
                if t in ("struct_item", "union_item") {
                    for c in `node.children {
                        if c.type != "field_declaration_list" {
                            continue;
                        }
                        field: any;
                        for field in c.children {
                            if field.type != "field_declaration" {
                                continue;
                            }
                            type_node: any = field.child_by_field_name("type");
                            if type_node is None {
                                for fc in field.children {
                                    if fc.type
                                        in (
                                            "type_identifier",
                                            "generic_type",
                                            "scoped_type_identifier",
                                            "reference_type",
                                            "primitive_type",
                                        )
                                    {
                                        type_node = fc;
                                        break;
                                    }
                                }
                            }
                            refs = [];
                            _rust_collect_type_refs(
                                type_node, source, False, refs, local_type_names
                            );
                            for (ref_name, role) in refs {
                                ctx: any = "generic_arg" if role == "generic_arg" else "field";
                                tgt = ensure_named_node(ref_name, field.start_point[0] + 1);
                                if tgt != item_nid {
                                    add_edge(
                                        item_nid,
                                        tgt,
                                        "references",
                                        field.start_point[0] + 1,
                                        context=ctx,
                                    );
                                }
                            }
                        }
                    }
                    for c in `node.children {
                        if c.type != "ordered_field_declaration_list" {
                            continue;
                        }
                        fline: any = c.start_point[0] + 1;
                        tc: any;
                        for tc in c.children {
                            if tc.type
                                not in (
                                    "type_identifier",
                                    "generic_type",
                                    "scoped_type_identifier",
                                    "reference_type",
                                    "primitive_type",
                                    "tuple_type",
                                    "array_type",
                                )
                            {
                                continue;
                            }
                            refs = [];
                            _rust_collect_type_refs(tc, source, False, refs, local_type_names);
                            for (ref_name, role) in refs {
                                ctx = "generic_arg" if role == "generic_arg" else "field";
                                tgt = ensure_named_node(ref_name, fline);
                                if tgt != item_nid {
                                    add_edge(item_nid, tgt, "references", fline, context=ctx);
                                }
                            }
                        }
                    }
                }
                if t == "enum_item" {
                    _TYPE_NODES: any = (
                        "type_identifier",
                        "generic_type",
                        "scoped_type_identifier",
                        "reference_type",
                        "primitive_type",
                        "tuple_type",
                        "array_type",
                    );

                    def _emit_enum_type(type_node, at_line) -> any {
                        if type_node is None {
                            return;
                        }
                        refs2: list[tuple[str, str]] = [];
                        _rust_collect_type_refs(type_node, source, False, refs2, local_type_names);
                        for (ref_name, role) in refs2 {
                            ctx: any = "generic_arg" if role == "generic_arg" else "field";
                            tgt: any = ensure_named_node(ref_name, at_line);
                            if tgt != item_nid {
                                add_edge(item_nid, tgt, "references", at_line, context=ctx);
                            }
                        }
                    }

                    for c in `node.children {
                        if c.type != "enum_variant_list" {
                            continue;
                        }
                        for variant in c.children {
                            if variant.type != "enum_variant" {
                                continue;
                            }
                            vline: any = variant.start_point[0] + 1;
                            vname_node: any = next(
                                (vc for vc in variant.children if vc.type == "identifier"), None
                            );
                            if vname_node is not None {
                                vname: any = _read_text(vname_node, source);
                                if vname {
                                    variant_nid: any = _make_id(item_nid, vname);
                                    add_node(variant_nid, vname, vline);
                                    add_edge(item_nid, variant_nid, "case_of", vline);
                                }
                            }
                            for vc in variant.children {
                                if vc.type == "ordered_field_declaration_list" {
                                    for tc in vc.children {
                                        if tc.type in _TYPE_NODES {
                                            _emit_enum_type(tc, vline);
                                        }
                                    }
                                } elif vc.type == "field_declaration_list" {
                                    for field in vc.children {
                                        if field.type != "field_declaration" {
                                            continue;
                                        }
                                        type_node = field.child_by_field_name("type");
                                        _emit_enum_type(type_node, field.start_point[0] + 1);
                                    }
                                }
                            }
                        }
                    }
                }
                if t == "trait_item" {
                    body = `node.child_by_field_name("body");
                    if body {
                        child: any;
                        for child in body.children {
                            walk(child, parent_impl_nid=item_nid);
                        }
                    }
                }
            }
            return;
        }

        if t in ("static_item", "const_item") {
            name_node = `node.child_by_field_name("name");
            if name_node {
                item_name = _read_text(name_node, source);
                if item_name == "_" {
                    return;
                }
                line = `node.start_point[0] + 1;
                if parent_impl_nid {
                    item_nid = impl_member_nid(parent_impl_nid, parent_impl_pre_nid, item_name);
                    add_node(item_nid, f".{item_name}", line);
                    add_edge(parent_impl_nid, item_nid, "contains", line);
                } else {
                    item_nid = file_item_nid(_make_id(stem, item_name), item_name);
                    add_node(item_nid, item_name, line);
                    add_edge(file_nid, item_nid, "contains", line);
                }
                type_node = `node.child_by_field_name("type");
                if type_node is not None {
                    refs = [];
                    _rust_collect_type_refs(type_node, source, False, refs, local_type_names);
                    for (ref_name, role) in refs {
                        tgt = ensure_named_node(ref_name, line);
                        if tgt == item_nid {
                            continue;
                        }
                        ctx = "generic_arg" if role == "generic_arg" else "field";
                        add_edge(item_nid, tgt, "references", line, context=ctx);
                    }
                }
            }
            return;
        }

        if t == "impl_item" {
            type_node = `node.child_by_field_name("type");
            trait_node: any = `node.child_by_field_name("trait");
            impl_nid: str | None = None;
            impl_type_bare: str | None = None;
            impl_key: str | None = None;
            impl_pre_nid: str | None = None;
            if type_node {
                type_name: any = _read_text(type_node, source).strip();
                impl_pre_nid = _make_id(stem, type_name);
                impl_nid = file_item_nid(
                    impl_pre_nid, impl_bare_names.get(`node.start_byte, type_name)
                );
                add_node(impl_nid, type_name, `node.start_point[0] + 1);
                impl_key = _rust_simple_generic_impl_key(`node, source);
                impl_type_bare = type_name.split("<")[0].strip();
            }
            if trait_node is not None and impl_nid is not None {
                refs = [];
                _rust_collect_type_refs(trait_node, source, False, refs, local_type_names);
                for (idx, (ref_name, role)) in enumerate(refs) {
                    tgt = ensure_named_node(ref_name, `node.start_point[0] + 1);
                    if tgt == impl_nid {
                        continue;
                    }
                    if _rust_is_trait_ref(trait_node, idx, role) {
                        add_edge(impl_nid, tgt, "implements", `node.start_point[0] + 1);
                    } else {
                        add_edge(
                            impl_nid,
                            tgt,
                            "references",
                            `node.start_point[0] + 1,
                            context="generic_arg",
                        );
                    }
                }
            }
            body = `node.child_by_field_name("body");
            if body {
                has_methods: any = `any(
                    child.type in ("function_item", "function_signature_item")
                    for child in body.children,
                );
                if impl_nid is not None and has_methods {
                    if impl_nid not in impl_keys {
                        impl_keys[impl_nid] = impl_key;
                    } elif impl_keys[impl_nid] != impl_key {
                        impl_keys[impl_nid] = None;
                    }
                    impl_node: any = node_by_id[impl_nid];
                    if impl_keys[impl_nid] {
                        impl_node["_rust_impl_key"] = impl_keys[impl_nid];
                    } else {
                        impl_node.pop("_rust_impl_key", None);
                    }
                }
                for child in body.children {
                    walk(
                        child,
                        parent_impl_nid=impl_nid,
                        parent_impl_type=impl_type_bare,
                        parent_impl_key=impl_key,
                        parent_impl_pre_nid=impl_pre_nid,
                    );
                }
            }
            return;
        }

        if t == "use_declaration" {
            arg: any = `node.child_by_field_name("argument");
            if arg {
                scope_mods = {
                    _read_text(name_node, source)
                    for sibling in (`node.parent.children if `node.parent is not None else ())
                    if sibling.type == "mod_item"
                        and (name_node := sibling.child_by_field_name("name")) is not None
                };
                visibility: any = next(
                    (child for child in `node.children if child.type == "visibility_modifier"), None
                );
                reexport = visibility is not None
                    and operator.eq(_read_text(visibility, source).strip(), "pub");

                def name_use(written: str, path: str) -> None {
                    first: any = path.lstrip(": ").split("::")[0].strip();
                    bound: any = written.split(" as ")[-1].strip();
                    ident: any = re.match("[A-Za-z_][A-Za-z0-9_]*", first);
                    if first in ("crate", "self", "super")
                        or ident is not None
                            and ident.group() in scope_mods
                            and not path.lstrip().startswith("::")
                    {
                        edges[-1]["_rust_use_name"] = written.split(" as ")[0].strip();
                        use_roots.setdefault(bound, set[any]()).add("crate");
                    } else {
                        use_roots.setdefault(bound, set[any]()).add(first);
                        if reexport and bound.isidentifier() {
                            edges[-1]["_rust_pub_use"] = {"label": bound, "root": first};
                        }
                    }
                }
                module_name: any = _rust_use_module(_read_text(arg, source));
                grouped: any = arg.type in ("use_list", "scoped_use_list");
                if module_name {
                    tgt_nid: any = _make_id(module_name);
                    add_edge(
                        file_nid,
                        tgt_nid,
                        "imports_from",
                        `node.start_point[0] + 1,
                        context="import",
                    );
                    name_use(module_name, _read_text(arg, source));
                    if grouped {
                        edges[-1]["_rust_use_group"] = True;
                    }
                }
                for (binding, line) in _rust_use_bindings(arg, source) if grouped else [] {
                    if binding_name := _rust_use_module(binding) {
                        add_edge(
                            file_nid, _make_id(binding_name), "imports_from", line, context="import"
                        );
                        name_use(binding_name, binding);
                        edges[-1]["_rust_use_binding"] = True;
                    }
                }
            }
            return;
        }

        for child in `node.children {
            walk(child, parent_impl_nid=None);
        }
    }

    walk(`root);
    label_to_nid = {};
    method_label_to_nid = {};
    for n in nodes {
        raw: any = n["label"];
        normalised: any = raw.strip("()").lstrip(".");
        if raw.startswith(".") {
            if raw.endswith(")") {
                method_label_to_nid[normalised] = n["id"];
            }
        } else {
            label_to_nid[normalised] = n["id"];
        }
    }
    type_nids = {n["id"] for n in nodes if not n["label"].endswith(")")};

    seen_call_pairs = set[any]();
    raw_calls = [];
    macro_arg_edges = [];

    def walk_calls(
        `node, caller_nid: str, self_type: str | None = None, self_impl_key: str | None = None
    ) -> None {
        if `node.type == "function_item" {
            return;
        }
        if `node.type == "macro_invocation" {
            macro_node: any = `node.child_by_field_name("macro");
            if macro_node is not None and macro_node.type == "identifier" {
                macro_name: any = _read_text(macro_node, source);
                tgt_nid: any = macro_nids_by_name.get(macro_name);
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
                }
            }
            args: any = next((c for c in `node.children if c.type == "token_tree"), None);
            invoked: any = macro_node.child_by_field_name("name")
                if macro_node is not None and macro_node.type == "scoped_identifier"
                else macro_node;
            if args is None
                or invoked is None
                or _read_text(invoked, source) not in _RUST_EXPRESSION_MACROS
            {
                args = None;
            }
            callee_name: str | None;
            for (callee_name, line) in _rust_macro_arg_calls(args) if args is not None else () {
                if callee_name[:1].isupper()
                    or callee_name in _LANGUAGE_BUILTIN_GLOBALS
                    or callee_name in _RUST_BUILTIN_TYPES
                    or callee_name.lower() in _RUST_TRAIT_METHOD_BLOCKLIST
                {
                    continue;
                }
                tgt_nid = label_to_nid.get(callee_name);
                if tgt_nid in type_nids {
                    continue;
                }
                if tgt_nid {
                    if tgt_nid != caller_nid {
                        macro_arg_edges.append({
                            "source": caller_nid,
                            "target": tgt_nid,
                            "relation": "calls",
                            "context": "macro_argument_call",
                            "confidence": "INFERRED",
                            "confidence_score": 0.85,
                            "source_file": str_path,
                            "source_location": f"L{line}",
                            "weight": 1.0,
                        });
                    }
                    continue;
                }
                raw_calls.append({
                    "caller_nid": caller_nid,
                    "callee": callee_name,
                    "is_member_call": False,
                    "source_file": str_path,
                    "source_location": f"L{line}",
                });
            }
        }
        if `node.type == "call_expression" {
            func_node: any = `node.child_by_field_name("function");
            callee_name = None;
            is_member_call: bool = False;
            is_scoped_call: bool = False;
            is_self_call: bool = False;
            qualifier_type: str | None = None;
            if func_node {
                if func_node.type == "identifier" {
                    callee_name = _read_text(func_node, source);
                } elif func_node.type == "field_expression" {
                    is_member_call = True;
                    field: any = func_node.child_by_field_name("field");
                    if field {
                        callee_name = _read_text(field, source);
                    }
                    receiver: any = func_node.child_by_field_name("value");
                    if receiver is not None and receiver.type == "self" {
                        is_self_call = True;
                    }
                } elif func_node.type == "scoped_identifier" {
                    is_scoped_call = True;
                    name: any = func_node.child_by_field_name("name");
                    if name {
                        callee_name = _read_text(name, source);
                    }
                    qualifier_type = _rust_qualifier_type(
                        func_node.child_by_field_name("path"), source
                    );
                    if qualifier_type == "Self" {
                        qualifier_type = self_type or "";
                    }
                }
            }
            if callee_name
                and callee_name not in _LANGUAGE_BUILTIN_GLOBALS
                and (callee_name not in _RUST_BUILTIN_TYPES or callee_name in local_types)
            {
                if qualifier_type is not None or is_self_call and self_type {
                    owner: any = _rust_type_last_segment(qualifier_type or self_type or "");
                    owned: any = impl_methods.get((owner, callee_name), set[any]());
                    tgt_nid = next(iter(owned)) if len(owned) == 1 else None;
                    if tgt_nid is None and qualifier_type is not None {
                        named: any = label_to_nid.get(callee_name);
                        tgt_nid = named if named in type_nids else None;
                    }
                } elif is_member_call {
                    tgt_nid = method_label_to_nid.get(callee_name);
                } elif is_scoped_call {
                    path_node: any = func_node.child_by_field_name("path") if func_node else None;
                    qual: any = _read_text(path_node, source) if path_node is not None else "";
                    head: any = qual.split("::")[-1].strip();
                    tgt_nid = label_to_nid.get(callee_name)
                        if qual == "self" or head in inline_mods
                        else None;
                } else {
                    tgt_nid = label_to_nid.get(callee_name);
                }
                if tgt_nid and tgt_nid != caller_nid {
                    pair = (caller_nid, tgt_nid);
                    if pair not in seen_call_pairs {
                        seen_call_pairs.add(pair);
                        line = `node.start_point[0] + 1;
                        is_constructor: any = tgt_nid in type_nids;
                        edges.append({
                            "source": caller_nid,
                            "target": tgt_nid,
                            "relation": "references" if is_constructor else "calls",
                            "context": "constructor" if is_constructor else "call",
                            "confidence": "EXTRACTED",
                            "source_file": str_path,
                            "source_location": f"L{line}",
                            "weight": 1.0,
                        });
                    }
                } elif is_scoped_call {
                    qual_node: any = func_node.child_by_field_name("path");
                    qualifier: any = _read_text(qual_node, source) if qual_node else "";
                    first_seg: any = qualifier.split("::", 1)[0].split("<", 1)[0].strip();
                    roots: any = use_roots.get(first_seg, {"crate"});
                    if not roots <= {"crate", "super", "self"} {
                        qualifier = "";
                    }
                    if qualifier {
                        raw_calls.append({
                            "caller_nid": caller_nid,
                            "callee": callee_name,
                            "is_member_call": False,
                            "is_scoped_call": True,
                            "scope_qualifier": qualifier,
                            "source_file": str_path,
                            "source_location": f"L{`node.start_point[0] + 1}",
                        });
                    }
                } elif callee_name.lower() not in _RUST_TRAIT_METHOD_BLOCKLIST {
                    rc_entry: any = {
                        "caller_nid": caller_nid,
                        "callee": callee_name,
                        "is_member_call": is_member_call,
                        "source_file": str_path,
                        "source_location": f"L{`node.start_point[0] + 1}",
                    };
                    if is_self_call and self_type {
                        rc_entry["rust_self_type"] = self_type;
                        if self_impl_key {
                            rc_entry["rust_self_impl_key"] = self_impl_key;
                        }
                    }
                    raw_calls.append(rc_entry);
                }
            }
        }
        for child in `node.children {
            walk_calls(child, caller_nid, self_type, self_impl_key);
        }
    }

    for (caller_nid, body_node, impl_type, impl_key) in function_bodies {
        walk_calls(body_node, caller_nid, impl_type, impl_key);
    }
    `edge: any;
    for `edge in macro_arg_edges {
        pair: any = (`edge["source"], `edge["target"]);
        if pair not in seen_call_pairs {
            seen_call_pairs.add(pair);
            edges.append(`edge);
        }
    }

    for `node in nodes {
        if not `node["source_file"] and `node["label"] in use_roots {
            `node["_rust_use_roots"] = sorted(use_roots[`node["label"]]);
        }
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

    return {"nodes": nodes, "edges": clean_edges, "raw_calls": raw_calls};
}
