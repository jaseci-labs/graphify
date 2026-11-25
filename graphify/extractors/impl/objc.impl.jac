impl _objc_category_base_stem(stem: str) -> str {
    head: any;
    sep: any;
    tail: any;
    (head, sep, tail) = stem.rpartition("/") as any;
    base: any;
    plus: any;
    suffix: any;
    (base, plus, suffix) = tail.partition("+") as any;
    if not plus or not _OBJC_STEM_PART.fullmatch(base) or not _OBJC_STEM_PART.fullmatch(suffix) {
        return stem;
    }
    return f"{head}{sep}{base}";
}

impl _objc_is_category(`node) -> bool {
    return `any(operator.eq(c.type, "(") for c in `node.children);
}

impl _objc_local_var_types(body_node, source: bytes, table: dict[str, str]) {
    stack: any = [body_node];
    while stack {
        n: any = stack.pop();
        if n.type == "method_definition" and n is not body_node {
            continue;
        }
        if n.type == "declaration" {
            type_node: any = n.child_by_field_name("type");
            if type_node is None {
                c: any;
                for c in n.children {
                    if c.type == "type_identifier" {
                        type_node = c;
                        break;
                    }
                }
            }
            if type_node is not None and type_node.type == "type_identifier" {
                type_name: any = _read_text(type_node, source).strip();
                declarators: any = [
                    c
                    for c in n.children
                    if c.type in ("identifier", "pointer_declarator", "init_declarator")
                ];
                if type_name and type_name[:1].isupper() and len(declarators) == 1 {
                    var: any = _cpp_declarator_name(declarators[0], source);
                    if var and var not in table {
                        table[var] = type_name;
                    }
                }
            }
        }
        for c in n.children {
            stack.append(c);
        }
    }
}

impl extract_objc(path: Path) -> dict {
    parser: any;
    source: any;
    `root: any;
    stem: any;
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    method_bodies: list[tuple[str, Any, str]];
    raw_calls: list[dict];
    objc_field_types: dict[str, dict[str, str | None]];
    file_nid: any;
    method_name_groups: dict[str, set[str]];
    all_method_nids: any;
    container_nid: any;
    seen_calls: set[tuple[str, str]];
    caller_nid: any;
    sibling_nids: any;
    try {
        import tree_sitter_objc as tsobjc;
        import from tree_sitter { Language, Parser }
    } except ImportError {
        return {"nodes": [], "edges": [], "error": "tree_sitter_objc not installed"};
    }

    try {
        language: any = Language(tsobjc.language());
        parser = Parser(language);
        source = _read_source_bytes(path);
        _OBJC_BLANK_MACROS: any = (b"NS_ASSUME_NONNULL_BEGIN", b"NS_ASSUME_NONNULL_END");
        for _m in _OBJC_BLANK_MACROS {
            source = source.replace(_m, b" " * len(_m));
        }
        tree: any = parser.parse(source);
        `root = tree.root_node;
    } except Exception as e {
        return {"nodes": [], "edges": [], "error": `str(e)};
    }

    stem = _file_stem(path);
    str_path = `str(path);
    nodes = [];
    edges = [];
    seen_ids = set[any]();
    method_bodies = [];
    raw_calls = [];
    objc_type_table: dict[str, str] = {};
    objc_field_types = {};

    def add_node(nid: str, label: str, line: int, markers: tuple[str, ...] = ()) {
        if nid not in seen_ids {
            seen_ids.add(nid);
            `node: any = {
                "id": nid,
                "label": label,
                "file_type": "code",
                "source_file": str_path,
                "source_location": f"L{line}",
            };
            for marker in markers {
                `node[marker] = True;
            }
            nodes.append(`node);
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
        metadata: dict | None = None,
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
        if metadata {
            `edge["metadata"] = metadata;
        }
        edges.append(`edge);
    }

    file_nid = _make_id(`str(path));
    add_node(file_nid, path.name, 1);

    def _read(`node) -> str {
        return source[`node.start_byte:`node.end_byte].decode("utf-8", errors="replace");
    }

    def _get_name(`node, field: str) -> str | None {
        n: any = `node.child_by_field_name(field);
        return _read(n) if n else None;
    }
    def _type_identifiers(`node) -> Generator[any, any, any] {
        if `node.type == "type_identifier" {
            yield `node;
            return;
        }
        for c in `node.children {
            yield from _type_identifiers(c);
        }
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
    def _field_decl_entry(sd) -> tuple[str, str] | None {
        type_ids: any = [s for s in sd.children if s.type == "type_identifier"];
        declarators: any = [s for s in sd.children if s.type == "struct_declarator"];
        if len(type_ids) != 1 or len(declarators) != 1 {
            return None;
        }
        type_name: any = _read(type_ids[0]).strip();
        if not type_name or not type_name[:1].isupper() {
            return None;
        }
        inner: any = declarators[0].children;
        if len(inner) != 1 {
            return None;
        }
        field: any = _cpp_declarator_name(inner[0], source);
        if not field {
            return None;
        }
        return (field, type_name);
    }

    def _record_field_type(cls_nid: str, field: str, type_name: str) {
        table: any = objc_field_types.setdefault(cls_nid, {});
        if field in table {
            if table[field] != type_name {
                table[field] = None;
            }
        } else {
            table[field] = type_name;
        }
    }
    def _collect_instance_variables(ivars_node, cls_nid: str) {
        for iv in ivars_node.children {
            if iv.type != "instance_variable" {
                continue;
            }
            for sd in iv.children {
                if sd.type == "struct_declaration" {
                    `entry: any = _field_decl_entry(sd);
                    if `entry is not None {
                        _record_field_type(cls_nid, *`entry);
                    }
                }
            }
        }
    }
    def _emit_enum(
        enum_spec, name: str, line: int, mapped_members: list[tuple[str, int]] | None = None
    ) {
        enum_nid: any = _make_id(stem, name);
        add_node(enum_nid, name, line);
        add_edge(file_nid, enum_nid, "contains", line);
        if mapped_members is None {
            body: any = next((c for c in enum_spec.children if c.type == "enumerator_list"), None);
            if body is None {
                return;
            }
            mapped_members = [];
            for member in body.children {
                if member.type != "enumerator" {
                    continue;
                }
                mname: any = next(
                    (_read(c) for c in member.children if c.type == "identifier"), None
                );
                if mname {
                    mapped_members.append((mname, member.start_point[0] + 1));
                }
            }
        }
        for (mname, m_line) in mapped_members {
            member_nid: any = _make_id(enum_nid, mname);
            add_node(member_nid, mname, m_line);
            add_edge(enum_nid, member_nid, "case_of", m_line);
        }
    }
    def _macro_enum_members -> list[tuple[str, int, list[tuple[str, int]]]] {
        opening: any;
        closing: any;
        comma: any;
        names: any;
        underlying_type: any;
        token: any;
        previous_member_end: any;
        member: any;
        def descendants(`node, kind: str) -> Generator[any, any, any] {
            if `node.type == kind {
                yield `node;
            }
            for child in `node.children {
                yield from descendants(child, kind);
            }
        }

        def leaves(`node) -> Generator[any, any, any] {
            if `node.type == "comment" {
                return;
            }
            if not `node.children {
                yield `node;
            } else {
                for child in `node.children {
                    yield from leaves(child);
                }
            }
        }

        source_leaves: any = `list(leaves(`root));
        accepted: any = [];
        for macro in descendants(`root, "macro_type_specifier") {
            macro_name: any = macro.child_by_field_name("name");
            if macro_name is None
                or _read(macro_name) not in ("NS_ENUM", "NS_OPTIONS", "NS_CLOSED_ENUM")
            {
                continue;
            }
            ancestor: any = macro.parent;
            while ancestor is not None {
                preceding: any = [
                    token
                    for token in leaves(ancestor)
                    if token.end_byte <= macro.start_byte
                ];
                if preceding and preceding[-1].type == "typedef" {
                    break;
                }
                ancestor = ancestor.parent;
            }
            if ancestor is None {
                continue;
            }

            tokens: any = `list(leaves(macro));
            opens: any = [token for token in tokens if token.type == "("];
            closes: any = [token for token in tokens if token.type == ")"];
            commas: any = [token for token in tokens if token.type == ","];
            if len(opens) != 1 or len(closes) != 1 or len(commas) != 1 {
                continue;
            }
            (opening, closing, comma) = (opens[0], closes[0], commas[0]);
            if not opening.end_byte <= comma.start_byte < comma.end_byte <= closing.start_byte {
                continue;
            }
            underlying: any = [
                `node
                for `node in descendants(macro, "type_descriptor")
                if opening.end_byte <= `node.start_byte and `node.end_byte <= comma.start_byte
            ];
            outer_types: any = [
                `node
                for `node in underlying
                if not `any(
                    other is not `node
                        and operator.le(other.start_byte, `node.start_byte)
                        and operator.le(`node.end_byte, other.end_byte)
                    for other in underlying,
                )
            ];
            names = [
                token
                for token in tokens
                if comma.end_byte <= token.start_byte < closing.start_byte and token.is_named
            ];
            if len(outer_types) != 1
                or len(names) != 1
                or names[0].type not in ("identifier", "type_identifier")
            {
                continue;
            }
            underlying_type = outer_types[0];
            if `any(token.is_missing for token in tokens)
                or `any(
                    opening.end_byte <= token.start_byte
                        and token.start_byte < comma.start_byte
                        and not (
                            underlying_type.start_byte <= token.start_byte
                            and token.end_byte <= underlying_type.end_byte
                        )
                        or comma.end_byte <= token.start_byte
                            and token.start_byte < closing.start_byte
                            and not (
                                names[0].start_byte <= token.start_byte
                                and token.end_byte <= names[0].end_byte
                            )
                    for token in tokens,
                )
            {
                continue;
            }

            following: any = [
                token
                for token in source_leaves
                if token.start_byte >= macro.end_byte
            ];
            if not following or following[0].type != "{" {
                continue;
            }
            open_brace: any = following[0];
            depth: any = 0;
            close_brace: any = None;
            for token in following {
                if token.type == "{" {
                    depth += 1;
                } elif token.type == "}" {
                    depth -= 1;
                    if depth == 0 {
                        close_brace = token;
                        break;
                    }
                }
                if depth < 0 {
                    break;
                }
            }
            if close_brace is None {
                continue;
            }
            after_body: any = [
                token
                for token in source_leaves
                if token.start_byte >= close_brace.end_byte
            ];
            if not after_body or after_body[0].type != ";" {
                continue;
            }

            name_bytes: any = source[names[0].start_byte:names[0].end_byte];
            body_bytes: any = source[open_brace.start_byte:close_brace.end_byte];
            prefix: any = b"enum " + name_bytes + b" ";
            fragment: any = prefix + body_bytes + b";";
            fragment_root: any = parser.parse(fragment).root_node;
            enum_specs: any = `list(descendants(fragment_root, "enum_specifier"));
            if fragment_root.has_error or len(enum_specs) != 1 {
                continue;
            }
            enum_spec: any = enum_specs[0];
            enum_name: any = enum_spec.child_by_field_name("name");
            body: any = enum_spec.child_by_field_name("body");
            if enum_name is None
                or fragment[enum_name.start_byte:enum_name.end_byte] != name_bytes
                or enum_spec.has_error
                or body is None
                or body.type != "enumerator_list"
                or body.has_error
                or body.start_byte != len(prefix)
                or body.end_byte != len(prefix) + len(body_bytes)
            {
                continue;
            }
            if `any(
                child.type not in {"{", "}", ",", "comment", "enumerator", "attribute_specifier"}
                for child in body.children,
            ) {
                continue;
            }

            members: list[tuple[str, int]] = [];
            previous_member_end = None;
            for member_ in body.children {
                member = member_;
                if member.type != "enumerator" {
                    continue;
                }
                if previous_member_end is not None
                    and not `any(
                        operator.eq(token.type, ",")
                            and (
                                previous_member_end <= token.start_byte
                                and token.start_byte < member.start_byte
                            )
                        for token in body.children,
                    )
                {
                    break;
                }
                identifier: any = member.child_by_field_name("name");
                if identifier is None {
                    identifier = next((c for c in member.children if c.type == "identifier"), None);
                }
                if identifier is None
                    or member.has_error
                    or identifier.start_byte < body.start_byte
                {
                    break;
                }
                original_start: any = open_brace.start_byte
                    + identifier.start_byte
                    - body.start_byte;
                original_end: any = open_brace.start_byte + identifier.end_byte - body.start_byte;
                name: any = fragment[identifier.start_byte:identifier.end_byte];
                if original_end > close_brace.end_byte
                    or source[original_start:original_end] != name
                {
                    break;
                }
                line: any = open_brace.start_point[0]
                    + identifier.start_point[0]
                    - body.start_point[0]
                    + 1;
                members.append((name.decode("utf-8", errors="replace"), line));
                previous_member_end = member.end_byte;
            } else {
                accepted.append((_read(names[0]), macro.start_point[0] + 1, members));
            }
        }
        return accepted;
    }

    macro_enums: any = _macro_enum_members();
    method_name_groups = {};

    def _scan_method_groups(`node, container_nid: str | None = None) {
        t: any = `node.type;
        if t == "class_interface" {
            identifiers: any = [c for c in `node.children if c.type == "identifier"];
            if not identifiers {
                child: any;
                for child in `node.children {
                    _scan_method_groups(child, container_nid);
                }
                return;
            }
            name: any = _read(identifiers[0]);
            cls_stem: any = _objc_category_base_stem(stem) if _objc_is_category(`node) else stem;
            container_nid = _make_id(cls_stem, name);
        } elif t == "class_implementation" {
            name = next((_read(c) for c in `node.children if c.type == "identifier"), None);
            if not name {
                for child in `node.children {
                    _scan_method_groups(child, container_nid);
                }
                return;
            }
            impl_stem: any = _objc_category_base_stem(stem) if _objc_is_category(`node) else stem;
            container_nid = _make_id(impl_stem, name);
        } elif t == "protocol_declaration" {
            name = next((_read(c) for c in `node.children if c.type == "identifier"), None);
            if name {
                container_nid = _make_id(stem, name);
            }
        } elif t in ("method_declaration", "method_definition") {
            if container_nid is not None {
                parts: any = [_read(c) for c in `node.children if c.type == "identifier"];
                method_name: any = "".join(parts) if parts else None;
                if method_name {
                    key: any = _make_id(container_nid, method_name);
                    method_name_groups.setdefault(key, set[any]()).add(method_name);
                }
            }
            return;
        }
        for child in `node.children {
            _scan_method_groups(child, container_nid);
        }
    }

    _scan_method_groups(`root);

    def walk(`node, parent_nid: str | None = None) {
        t: any = `node.type;
        line: any = `node.start_point[0] + 1;

        if t == "preproc_include" {
            child: any;
            for child in `node.children {
                if child.type == "system_lib_string" {
                    raw: any = _read(child).strip("<>");
                    module: any = raw.split("/")[-1].replace(".h", "");
                    if module {
                        tgt_nid: any = _make_id(module);
                        add_edge(file_nid, tgt_nid, "imports", line, context="import");
                    }
                } elif child.type == "string_literal" {
                    sub: any;
                    for sub in child.children {
                        if sub.type == "string_content" {
                            raw = _read(sub);
                            resolved: any = _resolve_c_include_path(raw, str_path);
                            if resolved is not None {
                                add_edge(
                                    file_nid,
                                    _make_id(`str(resolved)),
                                    "imports",
                                    line,
                                    context="import",
                                );
                            } else {
                                module = raw.split("/")[-1].replace(".h", "");
                                if module {
                                    add_edge(
                                        file_nid,
                                        _make_id(module),
                                        "imports",
                                        line,
                                        context="import",
                                        metadata=sanitize_metadata({
                                            "raw_include": raw,
                                            "include_kind": "quoted",
                                        }),
                                    );
                                }
                            }
                        }
                    }
                }
            }
            return;
        }

        if t == "module_import" {
            path_node: any = `node.child_by_field_name("path");
            if path_node is not None {
                module = _read(path_node).split(".")[0].strip();
                if module {
                    add_edge(file_nid, _make_id(module), "imports", line, context="import");
                }
            }
            return;
        }

        if t == "class_interface" {
            identifiers: any = [c for c in `node.children if c.type == "identifier"];
            if not identifiers {
                for child in `node.children {
                    walk(child, parent_nid);
                }
                return;
            }
            name: any = _read(identifiers[0]);
            cls_stem: any = _objc_category_base_stem(stem) if _objc_is_category(`node) else stem;
            cls_nid: any = _make_id(cls_stem, name);
            add_node(cls_nid, name, line, _CALLABLE_CLASS);
            add_edge(file_nid, cls_nid, "contains", line);
            colon_seen: any = False;
            for child in `node.children {
                if child.type == ":" {
                    colon_seen = True;
                } elif colon_seen and child.type == "identifier" {
                    super_nid: any = ensure_named_node(_read(child), line);
                    add_edge(cls_nid, super_nid, "inherits", line);
                    colon_seen = False;
                } elif child.type == "parameterized_arguments" {
                    for sub in child.children {
                        if sub.type == "type_name" {
                            s: any;
                            for s in sub.children {
                                if s.type == "type_identifier" {
                                    proto_nid: any = ensure_named_node(_read(s), line);
                                    add_edge(cls_nid, proto_nid, "implements", line);
                                }
                            }
                        }
                    }
                } elif child.type == "property_declaration" {
                    prop_line: any = child.start_point[0] + 1;
                    for sub in child.children {
                        if sub.type == "struct_declaration" {
                            seen_types: set[str] = set[any]();
                            for s in sub.children {
                                if s.type in ("struct_declarator", ";") {
                                    continue;
                                }
                                for ti in _type_identifiers(s) {
                                    tname: any = _read(ti);
                                    if tname in seen_types {
                                        continue;
                                    }
                                    seen_types.add(tname);
                                    type_nid: any = ensure_named_node(tname, prop_line);
                                    edges.append(
                                        _semantic_reference_edge(
                                            cls_nid, type_nid, "field", str_path, prop_line
                                        ),
                                    );
                                }
                            }
                            `entry: any = _field_decl_entry(sub);
                            if `entry is not None {
                                _record_field_type(cls_nid, *`entry);
                            }
                        }
                    }
                } elif child.type == "instance_variables" {
                    _collect_instance_variables(child, cls_nid);
                } elif child.type == "method_declaration" {
                    walk(child, cls_nid);
                }
            }
            return;
        }

        if t == "class_implementation" {
            name = None;
            for child in `node.children {
                if child.type == "identifier" {
                    name = _read(child);
                    break;
                }
            }
            if not name {
                for child in `node.children {
                    walk(child, parent_nid);
                }
                return;
            }
            impl_stem: any = _objc_category_base_stem(stem) if _objc_is_category(`node) else stem;
            impl_nid: any = _make_id(impl_stem, name);
            if impl_nid not in seen_ids {
                add_node(impl_nid, name, line, _CALLABLE_CLASS);
                add_edge(file_nid, impl_nid, "contains", line);
            }
            for child in `node.children {
                if child.type == "instance_variables" {
                    _collect_instance_variables(child, impl_nid);
                } elif child.type == "implementation_definition" {
                    for sub in child.children {
                        walk(sub, impl_nid);
                    }
                }
            }
            return;
        }

        if t == "protocol_declaration" {
            name = None;
            for child in `node.children {
                if child.type == "identifier" {
                    name = _read(child);
                    break;
                }
            }
            if name {
                proto_nid = _make_id(stem, name);
                add_node(proto_nid, f"<{name}>", line, _CALLABLE_CLASS);
                add_edge(file_nid, proto_nid, "contains", line);
                for child in `node.children {
                    if child.type == "protocol_reference_list" {
                        for sub in child.children {
                            if sub.type == "identifier" {
                                base_nid: any = ensure_named_node(_read(sub), line);
                                if base_nid != proto_nid {
                                    add_edge(proto_nid, base_nid, "implements", line);
                                }
                            }
                        }
                    }
                }
                for child in `node.children {
                    walk(child, proto_nid);
                }
            }
            return;
        }

        if t in ("method_declaration", "method_definition") {
            container: any = parent_nid or file_nid;
            prefix: any = "-";
            for child in `node.children {
                if child.type in ("+", "-") {
                    prefix = child.type;
                    break;
                }
            }
            parts: any = [_read(c) for c in `node.children if c.type == "identifier"];
            method_name: any = "".join(parts) if parts else None;
            if method_name {
                method_nid: any = _underscore_salted_nid(
                    _make_id(container, method_name), method_name, method_name_groups
                );
                add_node(method_nid, f"{prefix}{method_name}", line, _CALLABLE);
                add_edge(container, method_nid, "method", line);
                if t == "method_definition" {
                    method_bodies.append((method_nid, `node, container));
                }
            }
            return;
        }

        if t == "type_definition" {
            enum_spec: any = next((c for c in `node.children if c.type == "enum_specifier"), None);
            if enum_spec is not None
                and `any(operator.eq(c.type, "enumerator_list") for c in enum_spec.children)
            {
                alias: any = next(
                    (_read(c) for c in reversed(`node.children) if c.type == "type_identifier"),
                    None,
                );
                if alias is None {
                    alias = next(
                        (_read(c) for c in enum_spec.children if c.type == "type_identifier"), None
                    );
                }
                if alias {
                    _emit_enum(enum_spec, alias, line);
                    return;
                }
            }
        }

        if t == "enum_specifier" {
            name = next((_read(c) for c in `node.children if c.type == "type_identifier"), None);
            if name and `any(operator.eq(c.type, "enumerator_list") for c in `node.children) {
                _emit_enum(`node, name, line);
            }
            return;
        }

        for child in `node.children {
            walk(child, parent_nid);
        }
    }

    walk(`root);
    for (name, line, members) in macro_enums {
        _emit_enum(None, name, line, members);
    }
    all_method_nids = {n["id"] for n in nodes if n["id"] != file_nid};
    class_method_nids: dict[str, set[str]] = {};
    m_nid: any;
    _: any;
    for item_ in method_bodies {
        (m_nid, _, container_nid) = item_;
        class_method_nids.setdefault(container_nid, set[any]()).add(m_nid);
    }
    seen_calls = set[any]();
    body_node: any;
    for (_m_nid, body_node, _container) in method_bodies {
        _objc_local_var_types(body_node, source, objc_type_table);
    }

    for item__ in method_bodies {
        (caller_nid, body_node, container_nid) = item__;
        sibling_nids = class_method_nids.get(container_nid, set[any]());

        def walk_calls(n) {
            child: any;
            if n.type == "message_expression" {
                meth: any = n.child_by_field_name("method");
                recv: any = n.child_by_field_name("receiver");
                if meth is not None
                    and meth.type == "identifier"
                    and _read(meth) == "alloc"
                    and recv is not None
                    and recv.type == "identifier"
                {
                    tname: any = _read(recv);
                    ref_line: any = n.start_point[0] + 1;
                    type_nid: any = ensure_named_node(tname, ref_line);
                    if type_nid != caller_nid {
                        edges.append(
                            _semantic_reference_edge(
                                caller_nid, type_nid, "type", str_path, ref_line
                            ),
                        );
                    }
                }
                sel_parts: any = [
                    _read(child)
                    for (i, child) in enumerate(n.children)
                    if n.field_name_for_child(i) == "method" and child.type == "identifier"
                ];
                method_name: any = "".join(sel_parts);
                if method_name {
                    needle: any = _make_id("", method_name).lstrip("_");
                    for candidate in all_method_nids {
                        if candidate.endswith(needle) {
                            pair: any = (caller_nid, candidate);
                            if pair not in seen_calls and caller_nid != candidate {
                                seen_calls.add(pair);
                                add_edge(
                                    caller_nid,
                                    candidate,
                                    "calls",
                                    n.start_point[0] + 1,
                                    confidence="EXTRACTED",
                                    weight=1.0,
                                    context="call",
                                );
                            }
                        }
                    }
                    if recv is not None and recv.type == "identifier" {
                        raw_calls.append({
                            "caller_nid": caller_nid,
                            "callee": method_name,
                            "is_member_call": True,
                            "source_file": str_path,
                            "source_location": f"L{n.start_point[0] + 1}",
                            "receiver": _read(recv),
                            "lang": "objc",
                        });
                    } elif recv is not None and recv.type == "field_expression" {
                        kids: any = recv.children;
                        if len(kids) == 3
                            and kids[0].type == "identifier"
                            and _read(kids[0]) == "self"
                            and kids[1].type == "."
                            and kids[2].type == "field_identifier"
                        {
                            raw_calls.append({
                                "caller_nid": caller_nid,
                                "callee": method_name,
                                "is_member_call": True,
                                "source_file": str_path,
                                "source_location": f"L{n.start_point[0] + 1}",
                                "receiver": _read(kids[2]),
                                "receiver_kind": "self_field",
                                "lang": "objc",
                            });
                        }
                    }
                }
            } elif n.type == "field_expression" {
                for child in n.children {
                    if child.type == "field_identifier" {
                        field_name: any = _read(child);
                        target: any = _make_id(container_nid, field_name);
                        if target in sibling_nids and target != caller_nid {
                            pair = (caller_nid, target);
                            if pair not in seen_calls {
                                seen_calls.add(pair);
                                add_edge(
                                    caller_nid,
                                    target,
                                    "accesses",
                                    n.start_point[0] + 1,
                                    confidence="EXTRACTED",
                                    weight=1.0,
                                );
                            }
                        }
                    }
                }
            } elif n.type == "selector_expression" {
                sel_parts = [_read(c) for c in n.children if c.type == "identifier"];
                sel_name: any = "".join(sel_parts);
                if sel_name {
                    matches: any = sorted({
                        m
                        for (m, _, cont) in method_bodies
                        if m == _make_id(cont, sel_name) and m != caller_nid
                    });
                    if len(matches) == 1 {
                        pair = (caller_nid, matches[0]);
                        if pair not in seen_calls {
                            seen_calls.add(pair);
                            add_edge(
                                caller_nid,
                                matches[0],
                                "calls",
                                n.start_point[0] + 1,
                                confidence="EXTRACTED",
                                weight=1.0,
                                context="call",
                            );
                        }
                    }
                }
            }
            for child in n.children {
                walk_calls(child);
            }
        }
        walk_calls(body_node);
    }

    result: any = {
        "nodes": nodes,
        "edges": edges,
        "raw_calls": raw_calls,
        "input_tokens": 0,
        "output_tokens": 0,
    };
    if objc_type_table {
        result["objc_type_table"] = {"path": str_path, "table": objc_type_table};
    }
    field_tables: any = {
        cls: {f: t for (f, t) in tbl.items() if t}
        for (cls, tbl) in objc_field_types.items()
    };
    field_tables = {cls: tbl for (cls, tbl) in field_tables.items() if tbl};
    if field_tables {
        result["objc_field_types"] = {"path": str_path, "tables": field_tables};
    }
    return result;
}
