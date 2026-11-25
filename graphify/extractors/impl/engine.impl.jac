impl _csharp_namespace_id(dotted_name: str) -> str {
    digest: any = hashlib.sha1(dotted_name.encode("utf-8")).hexdigest()[:16];
    return f"csharp_namespace:{digest}";
}

impl _source_location(line: int | str | None) -> str | None {
    if line is None {
        return None;
    }
    if isinstance(line, `str) {
        return line if line.startswith("L") else f"L{line}";
    }
    return f"L{line}";
}

impl _semantic_reference_edge(
    source: str, target: str, context: str, source_file: str, line: int | str | None
) -> dict {
    if context not in REFERENCE_CONTEXTS {
        raise ValueError(f"unknown reference context: {context}");
    }
    return {
        "source": source,
        "target": target,
        "relation": "references",
        "context": context,
        "confidence": "EXTRACTED",
        "source_file": source_file,
        "source_location": _source_location(line),
        "weight": 1.0,
    };
}

impl _python_collect_type_refs(`node, source: bytes, generic: bool, out: list[tuple[str, str]]) {
    if `node is None {
        return;
    }
    t: any = `node.type;
    if t == "type" {
        c: any;
        for c in typing.cast(object, `node).children {
            if c.is_named {
                _python_collect_type_refs(c, source, generic, out);
            }
        }
        return;
    }
    if t == "identifier" {
        name: any = _read_text(`node, source);
        if name and name not in _PYTHON_TYPE_CONTAINERS and name not in _PYTHON_ANNOTATION_NOISE {
            out.append((name, "generic_arg" if generic else "type"));
        }
        return;
    }
    if t == "attribute" {
        tail: any = _read_text(`node, source).rsplit(".", 1)[-1];
        if tail and tail not in _PYTHON_TYPE_CONTAINERS and tail not in _PYTHON_ANNOTATION_NOISE {
            out.append((tail, "generic_arg" if generic else "type"));
        }
        return;
    }
    if t == "generic_type" {
        for c in typing.cast(object, `node).children {
            if c.type == "identifier" {
                container: any = _read_text(c, source);
                if container
                    and container not in _PYTHON_TYPE_CONTAINERS
                    and container not in _PYTHON_ANNOTATION_NOISE
                {
                    out.append((container, "generic_arg" if generic else "type"));
                }
            } elif c.type == "type_parameter" {
                for sub in typing.cast(object, c).children {
                    if sub.is_named {
                        _python_collect_type_refs(sub, source, True, out);
                    }
                }
            }
        }
        return;
    }
    if t == "subscript" {
        value: any = `node.child_by_field_name("value");
        if value is not None {
            _python_collect_type_refs(value, source, generic, out);
        }
        for c in typing.cast(object, `node).children {
            if c == value or not c.is_named {
                continue;
            }
            _python_collect_type_refs(c, source, True, out);
        }
        return;
    }
    if `node.is_named {
        for c in typing.cast(object, `node).children {
            if c.is_named {
                _python_collect_type_refs(c, source, generic, out);
            }
        }
    }
}

impl _csharp_pre_scan_interfaces(root_node, source: bytes) -> set[str] {
    out: set[str] = set[any]();
    stack: any = [root_node];
    while stack {
        n: any = stack.pop();
        if n.type == "interface_declaration" {
            name_node: any = n.child_by_field_name("name");
            if name_node is not None {
                text: any = _read_text(name_node, source);
                if text {
                    out.add(text);
                }
            }
        }
        stack.extend(n.children);
    }
    return out;
}

impl _csharp_type_name_for_id(`node, class_name: str) -> str {
    arity: any = sum(
        1
        for c in typing.cast(object, `node).children
        if c.type == "type_parameter_list"
        for _p in typing.cast(object, c).children
        if _p.type in ("type_parameter", "identifier"),
    );
    return f"{class_name}`{arity}" if arity else class_name;
}

impl _csharp_explicit_interface_name(specifier: str) -> str {
    text: any = specifier.strip().rstrip(".");
    depth: any = 0;
    out: list[str] = [];
    for ch in text {
        if ch == "<" {
            depth += 1;
        } elif ch == ">" {
            depth -= 1;
        } elif depth == 0 {
            out.append(ch);
        }
    }
    return "".join(out).rsplit(".", 1)[-1].strip();
}

impl _csharp_method_signature(`node, source: bytes, params=None) -> tuple[str, dict] {
    parts: list[str] = [];
    value_: any = 0;
    arity: any = value_;
    required: any = value_;
    value__: any = False;
    variadic: any = value__;
    extension: any = value__;
    primary: any = params is not None;
    if params is None {
        params = `node.child_by_field_name("parameters");
    }
    type_param_nodes: any = [
        p
        for c in typing.cast(object, `node).children
        if c.type == "type_parameter_list"
        for p in typing.cast(object, c).children
        if p.type in ("type_parameter", "identifier")
    ];
    type_param_names: any = {"".join(_read_text(p, source).split()) for p in type_param_nodes};
    extended_type: str | None = None;
    extended_arity: any = 0;
    extended_is_type_param: any = False;
    children: any = params.children if params is not None else [];
    for (i, c) in enumerate(children) {
        if c.type == "parameter" {
            mods: any = [_read_text(m, source) for m in typing.cast(object, c).children if m.type == "modifier"];
            type_node: any = c.child_by_field_name("type");
            type_text: any = "".join(_read_text(type_node, source).split())
                if type_node is not None
                else "";
            parts.append(" ".join(mods + [type_text]));
            arity += 1;
            if "this" in mods and arity == 1 {
                extension = True;
                ext_info: any = _read_csharp_type_name(type_node, source);
                if ext_info and ext_info[0] {
                    extended_type = ext_info[0];
                    extended_arity = sum(
                        1
                        for ch in (type_node.children if type_node is not None else [])
                        if ch.type == "type_argument_list"
                        for a in typing.cast(object, ch).children
                        if a.is_named,
                    );
                }
                extended_is_type_param = `bool(extended_type and extended_type in type_param_names);
            }
            if not `any(operator.eq(x.type, "=") for x in typing.cast(object, c).children) {
                required += 1;
            }
        } elif c.type == "params" {
            type_node = children[i + 1] if i + 1 < len(children) else None;
            parts.append(
                "params "
                    + (
                        "".join(_read_text(type_node, source).split())
                            if type_node is not None
                            else ""
                    ),
            );
            arity += 1;
            variadic = True;
        }
    }
    type_params: any = 0 if primary else len(type_param_nodes);
    signature: any = ",".join(parts);
    if type_params {
        signature = f"`{type_params}:{signature}";
    }
    meta: dict = {"arity": arity};
    min_arity: any = required - 1 if extension else required;
    if min_arity < arity {
        meta["min_arity"] = min_arity;
    }
    if variadic {
        meta["variadic"] = True;
    }
    if extension {
        meta["extension"] = True;
        if extended_type {
            meta["extended_type"] = extended_type;
            meta["extended_type_arity"] = extended_arity;
        }
        if extended_is_type_param {
            meta["extended_is_type_param"] = True;
        }
    }
    return (signature, meta);
}

impl _csharp_argc(call_node) -> int | None {
    if call_node.type != "invocation_expression" {
        return None;
    }
    args: any = call_node.child_by_field_name("arguments");
    return sum(1 for c in args.children if c.type == "argument") if args is not None else 0;
}

impl _csharp_creation_argc(`node) -> int {
    args: any = `node.child_by_field_name("arguments");
    if args is None {
        args = next((c for c in typing.cast(object, `node).children if c.type == "argument_list"), None);
    }
    return sum(1 for c in args.children if c.type == "argument") if args is not None else 0;
}

impl _csharp_pick_overload(overloads: list[dict], argc: int | None) -> dict | None {
    if argc is None {
        return None;
    }
    fits: any = [];
    for n in overloads {
        meta: any = n.get("metadata") or {};
        arity: any = meta.get("arity");
        if not isinstance(arity, `int) {
            return None;
        }
        low: any = meta.get("min_arity", arity);
        if low <= argc and (argc <= arity or meta.get("variadic")) {
            fits.append(n);
        }
    }
    return fits[0] if len(fits) == 1 else None;
}

impl _csharp_pre_scan_name_collisions(
    root_node, source: bytes, stem: str
) -> tuple[dict[str, set[str]], dict[str, set[str]], set[str]] {
    member_names: dict[str, set[str]];
    type_scopes: dict[tuple[str, tuple[str, ...]], list[tuple[object, str]]];
    member_names = {};
    type_decls: list[tuple[object, str, str]] = [];
    type_scopes = {};

    def _visit(n, ns: list[str], owners: tuple[str, ...] = ()) {
        scoped: any = `list(ns);
        for c in typing.cast(object, n).children {
            if c.type == "namespace_declaration" {
                ns_name: any = _csharp_namespace_name(c, source);
                body: any = c.child_by_field_name("body");
                if body is not None {
                    _visit(body, scoped + [ns_name] if ns_name else scoped, owners);
                }
            } elif c.type == "file_scoped_namespace_declaration" {
                ns_name = _csharp_namespace_name(c, source);
                if ns_name {
                    scoped = scoped + [ns_name];
                }
            } elif c.type in _CSHARP_TYPE_DECLARATIONS {
                name_node: any = c.child_by_field_name("name");
                name: any = _read_text(name_node, source) if name_node is not None else "";
                if name {
                    type_scopes.setdefault((".".join(scoped), owners), []).append((c, name));
                    _visit(c, scoped, (*owners, _csharp_type_name_for_id(c, name)));
                }
            } elif c.type == "declaration_list" or c.type.startswith("preproc_") {
                _visit(c, scoped, owners);
            }
        }
    }

    _visit(root_node, []);
    type_groups: dict[str, set[str]] = {};
    owner_ids: dict[tuple[str, tuple[str, ...]], str] = {};
    for ((namespace, owners), declarations) in sorted(
        type_scopes.items(), key=lambda (item) -> any { len(item[0][1]) }
    ) {
        parent: any = owner_ids.get((namespace, owners));
        names_by_id: dict[str, set[str]] = {};
        proposed: any = [];
        decl: any;
        name: any;
        for (decl, name) in declarations {
            type_name: any = _csharp_type_name_for_id(decl, name);
            plain: any = _make_id(parent, type_name)
                if parent
                else _make_id(stem, namespace, type_name);
            names_by_id.setdefault(plain, set[any]()).add(name);
            proposed.append((decl, plain, name, type_name));
        }
        type_groups.update({nid: names for (nid, names) in names_by_id.items() if len(names) >= 2});
        for (decl, plain, name, type_name) in proposed {
            owner_ids[namespace, (*owners, type_name)] = _underscore_salted_nid(
                plain, name, type_groups
            );
            type_decls.append((decl, plain, name));
        }
    }

    def _members(n, type_nid: str) {
        for c in typing.cast(object, n).children {
            if c.type in ("method_declaration", "property_declaration", "enum_member_declaration") {
                name_node: any = c.child_by_field_name("name");
                name: any = _read_text(name_node, source) if name_node is not None else "";
                if name {
                    member_names.setdefault(_make_id(type_nid, name), set[any]()).add(name);
                }
            } elif c.type in ("declaration_list", "enum_member_declaration_list")
                or c.type.startswith("preproc_")
            {
                _members(c, type_nid);
            }
        }
    }

    for (decl, plain, name) in type_decls {
        _members(decl, _underscore_salted_nid(plain, name, type_groups));
    }
    member_groups: any = {nid: names for (nid, names) in member_names.items() if len(names) >= 2};
    return (type_groups, member_groups, `set(member_names));
}

impl _csharp_classify_base(name: str, interface_names: set[str]) -> str {
    if name in interface_names {
        return "implements";
    }
    if len(name) >= 2 and name[0] == "I" and name[1].isupper() {
        return "implements";
    }
    return "inherits";
}

impl _csharp_type_parameters_in_scope(`node, source: bytes) -> frozenset[str] {
    names: set[str] = set[any]();
    scope: any = `node;
    while scope is not None {
        if scope.type in _CSHARP_TYPE_PARAMETER_SCOPE_DECLARATIONS {
            for child in typing.cast(object, scope).children {
                if child.type != "type_parameter_list" {
                    continue;
                }
                for param in typing.cast(object, child).children {
                    if param.type == "type_parameter" {
                        name_node: any = next(
                            (sub for sub in typing.cast(object, param).children if sub.type == "identifier"), None
                        );
                        if name_node is not None {
                            name: any = _read_text(name_node, source);
                            if name {
                                names.add(name);
                            }
                        }
                    } elif param.type == "identifier" {
                        name = _read_text(param, source);
                        if name {
                            names.add(name);
                        }
                    }
                }
            }
        }
        scope = scope.parent;
    }
    return frozenset(names);
}

impl _csharp_collect_type_refs(
    `node,
    source: bytes,
    generic: bool,
    out: list[tuple[str, str, bool, str]],
    `skip: frozenset[str] | None = None,
) {
    if `node is None {
        return;
    }
    if `skip is None {
        `skip = _csharp_type_parameters_in_scope(`node, source);
    }
    t: any = `node.type;
    if t == "predefined_type" {
        return;
    }
    if t == "identifier" {
        name: any = _read_text(`node, source);
        if name and name not in `skip {
            out.append((name, "generic_arg" if generic else "type", False, ""));
        }
        return;
    }
    if t == "qualified_name" {
        prefix: any;
        _: any;
        text: any;
        (prefix, _, text) = _read_text(`node, source).rpartition(".") as any;
        text = text.split("<", 1)[0];
        if text and text not in `skip {
            out.append((text, "generic_arg" if generic else "type", True, prefix));
        }
        return;
    }
    if t == "generic_name" {
        name_child: any = `node.child_by_field_name("name");
        if name_child is None {
            sub: any;
            for sub in typing.cast(object, `node).children {
                if sub.type == "identifier" {
                    name_child = sub;
                    break;
                }
            }
        }
        if name_child is not None {
            qualified: any = operator.eq(name_child.type, "qualified_name");
            (prefix, _, name) = _read_text(name_child, source).rpartition(".") as any;
            if name and name not in `skip {
                out.append((
                    name,
                    "generic_arg" if generic else "type",
                    qualified,
                    prefix if qualified else "",
                ));
            }
        }
        for sub in typing.cast(object, `node).children {
            if sub.type == "type_argument_list" {
                for arg in typing.cast(object, sub).children {
                    if arg.is_named {
                        _csharp_collect_type_refs(arg, source, True, out, `skip);
                    }
                }
            }
        }
        return;
    }
    if t in ("nullable_type", "array_type", "pointer_type", "ref_type") {
        c: any;
        for c in typing.cast(object, `node).children {
            if c.is_named {
                _csharp_collect_type_refs(c, source, generic, out, `skip);
            }
        }
        return;
    }
    if t == "tuple_type" {
        for el in typing.cast(object, `node).children {
            if el.type == "tuple_element" {
                type_child: any = el.child_by_field_name("type");
                if type_child is not None {
                    _csharp_collect_type_refs(type_child, source, generic, out, `skip);
                }
            }
        }
        return;
    }
    if `node.is_named {
        for c in typing.cast(object, `node).children {
            if c.is_named {
                _csharp_collect_type_refs(c, source, generic, out, `skip);
            }
        }
    }
}

impl _csharp_attribute_names(method_node, source: bytes) -> list[tuple[str, bool, str]] {
    names: list[tuple[str, bool, str]] = [];
    `skip: any = _csharp_type_parameters_in_scope(method_node, source);
    for child in typing.cast(object, method_node).children {
        if child.type != "attribute_list" {
            continue;
        }
        for attr in typing.cast(object, child).children {
            if attr.type != "attribute" {
                continue;
            }
            name_node: any = attr.child_by_field_name("name");
            if name_node is None {
                for sub in typing.cast(object, attr).children {
                    if sub.type in ("identifier", "qualified_name") {
                        name_node = sub;
                        break;
                    }
                }
            }
            if name_node is not None {
                qualified: any = operator.eq(name_node.type, "qualified_name");
                prefix: any;
                _: any;
                text: any;
                (prefix, _, text) = _read_text(name_node, source).rpartition(".") as any;
                if text and text not in `skip {
                    names.append((text, qualified, prefix if qualified else ""));
                }
            }
        }
    }
    return names;
}

impl _java_type_parameters_in_scope(`node, source: bytes) -> frozenset[str] {
    names: set[str] = set[any]();
    scope: any = `node;
    while scope is not None {
        if scope.type in _JAVA_TYPE_PARAMETER_SCOPE_DECLARATIONS {
            params: any = scope.child_by_field_name("type_parameters");
            if params is not None {
                for param in typing.cast(object, params).children {
                    if param.type != "type_parameter" {
                        continue;
                    }
                    name_node: any = next(
                        (child for child in typing.cast(object, param).children if child.type == "type_identifier"), None
                    );
                    if name_node is not None {
                        names.add(_read_text(name_node, source));
                    }
                }
            }
        }
        scope = scope.parent;
    }
    return frozenset(names);
}

impl _java_collect_type_refs(
    `node,
    source: bytes,
    generic: bool,
    out: list[tuple[str, str]],
    `skip: frozenset[str] | None = None,
    preserve_qualified: bool = False,
) {
    if `node is None {
        return;
    }
    if `skip is None {
        `skip = _java_type_parameters_in_scope(`node, source);
    }
    t: any = `node.type;
    if t in ("integral_type", "floating_point_type", "boolean_type", "void_type") {
        return;
    }
    if t == "type_identifier" {
        name: any = _read_text(`node, source);
        if name and name not in `skip and name not in _JAVA_BUILTIN_TYPES {
            out.append((name, "generic_arg" if generic else "type"));
        }
        return;
    }
    if t == "scoped_type_identifier" {
        raw: any = _read_text(`node, source);
        simple: any = raw.rsplit(".", 1)[-1];
        text: any = raw if preserve_qualified else raw.rsplit(".", 1)[-1];
        if text and simple not in _JAVA_BUILTIN_TYPES {
            out.append((text, "generic_arg" if generic else "type"));
        }
        return;
    }
    if t == "generic_type" {
        c: any;
        for c in typing.cast(object, `node).children {
            if c.type in ("type_identifier", "scoped_type_identifier") {
                raw = _read_text(c, source);
                simple = raw.rsplit(".", 1)[-1];
                text = raw if preserve_qualified and c.type == "scoped_type_identifier" else simple;
                if text
                    and simple not in _JAVA_BUILTIN_TYPES
                    and (c.type == "scoped_type_identifier" or simple not in `skip)
                {
                    out.append((text, "generic_arg" if generic else "type"));
                }
                break;
            }
        }
        for c in typing.cast(object, `node).children {
            if c.type == "type_arguments" {
                for arg in typing.cast(object, c).children {
                    if arg.is_named {
                        _java_collect_type_refs(arg, source, True, out, `skip, preserve_qualified);
                    }
                }
            }
        }
        return;
    }
    if t == "array_type" {
        for c in typing.cast(object, `node).children {
            if c.is_named {
                _java_collect_type_refs(c, source, generic, out, `skip, preserve_qualified);
            }
        }
        return;
    }
    if `node.is_named {
        for c in typing.cast(object, `node).children {
            if c.is_named {
                _java_collect_type_refs(c, source, generic, out, `skip, preserve_qualified);
            }
        }
    }
}

impl _java_receiver_type_name(type_node, source: bytes) -> str | None {
    if type_node is None {
        return None;
    }
    t: any = type_node.type;
    if t == "type_identifier" {
        name: any = _read_text(type_node, source);
    } elif t == "scoped_type_identifier" {
        name = _read_text(type_node, source);
    } elif t == "generic_type" {
        base: any = next(
            (child
            for child in typing.cast(object, type_node).children
            if child.type in ("type_identifier", "scoped_type_identifier")),
            None,
        );
        return _java_receiver_type_name(base, source);
    } else {
        return None;
    }
    if not name
        or name in _JAVA_BUILTIN_TYPES
        or name in _java_type_parameters_in_scope(type_node, source)
    {
        return None;
    }
    return name;
}

impl _java_receiver_chain(`node, source: bytes, depth: int = 0) -> list | None {
    if `node is None or depth > 16 {
        return None;
    }
    t: any = `node.type;
    if t == "parenthesized_expression" {
        inner: any = [c for c in typing.cast(object, `node).named_children if c.type != "comment"];
        return _java_receiver_chain(inner[0], source, depth + 1) if len(inner) == 1 else None;
    }
    if t in ("object_creation_expression", "cast_expression") {
        name: any = _java_receiver_type_name(`node.child_by_field_name("type"), source);
        return ["type", name] if name else None;
    }
    if t in ("this", "super") {
        return [t];
    }
    if t == "identifier" {
        return ["name", _read_text(`node, source)];
    }
    if t == "field_access" {
        owner: any;
        field: any;
        (owner, field) = (`node.child_by_field_name("object"), `node.child_by_field_name("field"));
        if owner is not None and owner.type == "this" and field is not None {
            return ["name", f"this.{_read_text(field, source)}"];
        }
        if owner is None or field is None {
            return None;
        }
        inner = _java_receiver_chain(owner, source, depth + 1);
        if inner is None {
            return None;
        }
        return ["field", _read_text(field, source), inner];
    }
    if t == "method_invocation" {
        name_node: any = `node.child_by_field_name("name");
        if name_node is None {
            return None;
        }
        receiver: any = `node.child_by_field_name("object");
        inner = None;
        if receiver is not None {
            inner = _java_receiver_chain(receiver, source, depth + 1);
            if inner is None {
                return None;
            }
        }
        return ["call", _read_text(name_node, source), inner, _java_argc(`node)];
    }
    return None;
}

impl _java_type_chain_leaf(
    chain: list,
    receiver_types: dict,
    bound_names: set[str] | None = None,
    field_names: set[str] | None = None,
) -> list | None {
    bound: any = bound_names or set[any]();
    if chain[0] == "call" {
        if chain[2] is None {
            return chain;
        }
        inner: any = _java_type_chain_leaf(chain[2], receiver_types, bound, field_names);
        return ["call", chain[1], inner, *chain[3:]] if inner else None;
    }
    if chain[0] == "field" {
        owner: any = chain[2];
        if not owner or owner[0] != "name" {
            return None;
        }
        name: any = owner[1];
        if not name or name in receiver_types or name in bound or not name[:1].isupper() {
            return None;
        }
        return ["field", chain[1], ["type", name]];
    }
    if chain[0] == "name" {
        name = chain[1];
        if name in (field_names or ())
            or name.startswith("this.")
            or name not in bound and name not in receiver_types and not name[:1].isupper()
        {
            return ["field_type", name.removeprefix("this.")];
        }
        declared: any = receiver_types.get(name);
        if declared {
            return ["type", declared];
        }
        return ["type", chain[1]] if chain[1][:1].isupper() else None;
    }
    return chain;
}

impl _java_declarator_names(declaration_node, source: bytes) -> list[str] {
    names: list[str] = [];
    for child in typing.cast(object, declaration_node).children {
        if child.type != "variable_declarator" {
            continue;
        }
        name_node: any = child.child_by_field_name("name");
        if name_node is not None {
            name: any = _read_text(name_node, source);
            if name {
                names.append(name);
            }
        }
    }
    return names;
}

impl _java_bound_names(method_node, source: bytes) -> set[str] {
    names: set[str] = set[any]();
    stack: any = [
        method_node.child_by_field_name("parameters"),
        method_node.child_by_field_name("body"),
    ];
    while stack {
        `node: any = stack.pop();
        if `node is None {
            continue;
        }
        if `node.type in _JAVA_NAMED_BINDINGS {
            name_node: any = `node.child_by_field_name("name");
            if name_node is not None and name_node.type == "identifier" {
                names.add(_read_text(name_node, source));
            }
        } elif `node.type in _JAVA_LISTED_BINDINGS {
            names.update(_read_text(c, source) for c in typing.cast(object, `node).children if c.type == "identifier");
        } elif `node.type == "lambda_expression" {
            params: any = `node.child_by_field_name("parameters");
            if params is not None and params.type == "identifier" {
                names.add(_read_text(params, source));
            }
        }
        stack.extend(`node.children);
    }
    return names;
}

impl _java_lambda_parameters(lambda_node, source: bytes) -> list[tuple[str, str | None]] {
    parameters: any = lambda_node.child_by_field_name("parameters");
    if parameters is None {
        return [];
    }
    if parameters.type == "identifier" {
        return [(_read_text(parameters, source), None)];
    }
    if parameters.type == "inferred_parameters" {
        return [
            (_read_text(child, source), None)
            for child in typing.cast(object, parameters).children
            if child.type == "identifier"
        ];
    }
    bindings: list[tuple[str, str | None]] = [];
    for parameter in typing.cast(object, parameters).children {
        if parameter.type not in ("formal_parameter", "spread_parameter") {
            continue;
        }
        name_node: any = parameter.child_by_field_name("name");
        if name_node is not None {
            bindings.append((
                _read_text(name_node, source),
                _java_receiver_type_name(parameter.child_by_field_name("type"), source),
            ));
        }
    }
    return bindings;
}

impl _java_method_receiver_types(
    method_node, source: bytes, field_types: dict[str, str]
) -> dict[str, str] {
    method_types: dict[str, str];
    ambiguous: set[str];
    method_types = {};
    ambiguous = set[any]();

    def bind(name: str, type_name: str | None) {
        if not name or not type_name or name in ambiguous {
            return;
        }
        previous: any = method_types.get(name);
        if previous is not None and previous != type_name {
            method_types.pop(name, None);
            ambiguous.add(name);
        } else {
            method_types[name] = type_name;
        }
    }

    params: any = method_node.child_by_field_name("parameters");
    if params is not None {
        for param in typing.cast(object, params).children {
            if param.type not in ("formal_parameter", "spread_parameter") {
                continue;
            }
            type_name: any = _java_receiver_type_name(param.child_by_field_name("type"), source);
            name_node: any = param.child_by_field_name("name");
            if name_node is not None {
                bind(_read_text(name_node, source), type_name);
            }
        }
    }

    body: any = method_node.child_by_field_name("body");
    stack: any = `list(body.children) if body is not None else [];
    while stack {
        `node: any = stack.pop();
        if `node.type
            in (
                "class_declaration",
                "class_body",
                "interface_declaration",
                "record_declaration",
                "enum_declaration",
                "annotation_type_declaration",
            )
        {
            continue;
        }
        if `node.type == "lambda_expression" {
            name: any;
            for (name, type_name) in _java_lambda_parameters(`node, source) {
                if type_name is None or field_types.get(name) not in (None, type_name) {
                    method_types.pop(name, None);
                    ambiguous.add(name);
                } else {
                    bind(name, type_name);
                }
            }
        }
        if `node.type == "local_variable_declaration" {
            type_name = _java_receiver_type_name(`node.child_by_field_name("type"), source);
            for name in _java_declarator_names(`node, source) {
                if field_types.get(name) not in (None, type_name) {
                    method_types.pop(name, None);
                    ambiguous.add(name);
                } else {
                    bind(name, type_name);
                }
            }
        }
        stack.extend(`node.children);
    }

    table: any = `dict(field_types);
    table.update(method_types);
    for name in ambiguous {
        table.pop(name, None);
    }
    table.update({f"this.{name}": type_name for (name, type_name) in field_types.items()});
    return table;
}

impl _java_has_modifier(declaration_node, modifier: str) -> bool {
    for child in typing.cast(object, declaration_node).children {
        if child.type == "modifiers" {
            return `any(operator.eq(mod.type, modifier) for mod in typing.cast(object, child).children);
        }
    }
    return False;
}

impl _java_annotation_nodes(declaration_node) -> list {
    modifiers: any = None;
    for child in typing.cast(object, declaration_node).children {
        if child.type == "modifiers" {
            modifiers = child;
            break;
        }
    }
    if modifiers is None {
        return [];
    }
    return [
        child
        for child in typing.cast(object, modifiers).children
        if child.type in ("marker_annotation", "annotation")
    ];
}

impl _java_annotation_names(declaration_node, source: bytes) -> list[tuple[str, str]] {
    names: list[tuple[str, str]] = [];
    for anno in _java_annotation_nodes(declaration_node) {
        name_node: any = anno.child_by_field_name("name");
        if name_node is None {
            for sub in typing.cast(object, anno).children {
                if sub.type in ("identifier", "scoped_identifier", "type_identifier") {
                    name_node = sub;
                    break;
                }
            }
        }
        if name_node is not None {
            raw: any = _read_text(name_node, source);
            text: any = raw.rsplit(".", 1)[-1];
            if text {
                names.append((text, raw));
            }
        }
    }
    return names;
}

impl _java_annotation_class_literal_refs(declaration_node, source: bytes) -> list[str] {
    names: list[str] = [];
    for anno in _java_annotation_nodes(declaration_node) {
        arguments: any = anno.child_by_field_name("arguments");
        if arguments is None {
            continue;
        }
        stack: any = [arguments];
        while stack {
            current: any = stack.pop();
            if current.type == "class_literal" {
                type_node: any = next(
                    (child for child in typing.cast(object, current).children if child.is_named), None
                );
                refs: list[tuple[str, str]] = [];
                _java_collect_type_refs(type_node, source, False, refs, preserve_qualified=True);
                names.extend(name for (name, _role) in refs);
                continue;
            }
            stack.extend(child for child in typing.cast(object, current).children if child.is_named);
        }
    }
    return names;
}

impl _php_name_text(`node, source: bytes) -> str | None {
    if `node is None {
        return None;
    }
    return _read_text(`node, source).rsplit("\\", 1)[-1] or None;
}

impl _php_collect_type_refs(`node, source: bytes, generic: bool, out: list[tuple[str, str]]) {
    if `node is None {
        return;
    }
    t: any = `node.type;
    if t == "primitive_type" {
        return;
    }
    if t == "named_type" {
        c: any;
        for c in typing.cast(object, `node).children {
            if c.type in ("name", "qualified_name") {
                text: any = _php_name_text(c, source);
                if text {
                    out.append((text, "generic_arg" if generic else "type"));
                }
                return;
            }
        }
        return;
    }
    if t in ("name", "qualified_name") {
        text = _php_name_text(`node, source);
        if text {
            out.append((text, "generic_arg" if generic else "type"));
        }
        return;
    }
    if t in ("nullable_type", "union_type", "intersection_type", "optional_type") {
        for c in typing.cast(object, `node).children {
            if c.is_named {
                _php_collect_type_refs(c, source, generic, out);
            }
        }
        return;
    }
    if `node.is_named {
        for c in typing.cast(object, `node).children {
            if c.is_named {
                _php_collect_type_refs(c, source, generic, out);
            }
        }
    }
}

impl _php_declared_type_name(`node, source: bytes) -> str | None {
    if `node is None {
        return None;
    }
    if `node.type == "optional_type" {
        `node = next((c for c in typing.cast(object, `node).children if c.is_named), None);
        if `node is None {
            return None;
        }
    }
    if `node.type != "named_type" {
        return None;
    }
    return next(
        (_php_name_text(c, source) for c in typing.cast(object, `node).children if c.type in ("name", "qualified_name")),
        None,
    );
}

impl _php_variable_text(`node, source: bytes) -> str | None {
    if `node is None or `node.type != "variable_name" {
        return None;
    }
    return next((_read_text(c, source) for c in typing.cast(object, `node).children if c.type == "name"), None);
}

impl _php_first_declared_type(`node, source: bytes) -> str | None {
    return next(
        (name for name in (_php_declared_type_name(c, source) for c in typing.cast(object, `node).children) if name),
        None,
    );
}

impl _php_receiver_type_table(`root, source: bytes, table: dict[str, str]) {
    stack: any = [`root];
    while stack {
        n: any = stack.pop();
        t: any = n.type;
        if t == "property_declaration" {
            type_name: any = _php_first_declared_type(n, source);
            for element in n.children if type_name else [] {
                if element.type != "property_element" {
                    continue;
                }
                name: any = next(
                    (_php_variable_text(c, source)
                    for c in typing.cast(object, element).children
                    if c.type == "variable_name"),
                    None,
                );
                if name and name not in table {
                    table[name] = type_name;
                }
            }
        } elif t in ("property_promotion_parameter", "simple_parameter") {
            type_name = _php_first_declared_type(n, source);
            name = next(
                (_php_variable_text(c, source) for c in typing.cast(object, n).children if c.type == "variable_name"),
                None,
            );
            if name and type_name and name not in table {
                table[name] = type_name;
            }
        } elif t == "assignment_expression" {
            right: any = n.child_by_field_name("right");
            if right is not None and right.type == "object_creation_expression" {
                name = _php_variable_text(n.child_by_field_name("left"), source);
                type_name = next(
                    (_php_name_text(c, source)
                    for c in typing.cast(object, right).children
                    if c.type in ("name", "qualified_name")),
                    None,
                );
                if name and type_name and name not in table {
                    table[name] = type_name;
                }
            }
        }
        stack.extend(reversed(n.children));
    }
}

impl _php_method_return_type_node(method_node) -> any {
    saw_params: any = False;
    for c in typing.cast(object, method_node).children {
        if c.type == "formal_parameters" {
            saw_params = True;
            continue;
        }
        if saw_params and c.is_named and c.type not in ("compound_statement",) {
            if c.type
                in (
                    "named_type",
                    "primitive_type",
                    "nullable_type",
                    "union_type",
                    "intersection_type",
                    "optional_type",
                )
            {
                return c;
            }
        }
    }
    return None;
}

impl _kotlin_user_type_name(user_type_node, source: bytes) -> str | None {
    if user_type_node is None {
        return None;
    }
    name: str | None = None;
    for c in typing.cast(object, user_type_node).children {
        if c.type in ("type_identifier", "identifier") {
            text: any = _read_text(c, source);
            if text {
                name = text;
            }
        } elif c.type == "simple_user_type" {
            for sub in typing.cast(object, c).children {
                if sub.type in ("identifier", "type_identifier") {
                    text = _read_text(sub, source);
                    if text {
                        name = text;
                    }
                    break;
                }
            }
        }
    }
    return name;
}

impl _kotlin_annotation_names(declaration_node, source: bytes) -> list[tuple[str, str]] {
    names: list[tuple[str, str]] = [];
    modifiers: any = None;
    if declaration_node is None {
        return names;
    }
    for child in typing.cast(object, declaration_node).children {
        if child.type == "modifiers" {
            modifiers = child;
            break;
        }
    }
    if modifiers is None {
        return names;
    }
    for anno in typing.cast(object, modifiers).children {
        if anno.type != "annotation" {
            continue;
        }
        for sub in typing.cast(object, anno).children {
            user_type_node: any = None;
            if sub.type == "user_type" {
                user_type_node = sub;
            } elif sub.type == "constructor_invocation" {
                for inner in typing.cast(object, sub).children {
                    if inner.type == "user_type" {
                        user_type_node = inner;
                        break;
                    }
                }
            }
            if user_type_node is not None {
                name: any = _kotlin_user_type_name(user_type_node, source);
                if name {
                    raw: any = _read_text(user_type_node, source);
                    names.append((name, raw));
                }
            }
        }
    }
    return names;
}

impl _kotlin_annotation_class_literal_refs(declaration_node, source: bytes) -> list[str] {
    names: list[str] = [];
    if declaration_node is None {
        return names;
    }
    modifiers: any = None;
    for child in typing.cast(object, declaration_node).children {
        if child.type == "modifiers" {
            modifiers = child;
            break;
        }
    }
    if modifiers is None {
        return names;
    }
    seen: set[str] = set[any]();
    for anno in typing.cast(object, modifiers).children {
        if anno.type != "annotation" {
            continue;
        }
        for sub in typing.cast(object, anno).children {
            ci: any = sub if sub.type == "constructor_invocation" else None;
            if ci is None {
                continue;
            }
            args_node: any = None;
            for c in typing.cast(object, ci).children {
                if c.type == "value_arguments" {
                    args_node = c;
                    break;
                }
            }
            if args_node is None {
                continue;
            }
            stack: any = [args_node];
            while stack {
                curr: any = stack.pop();
                if curr.type == "navigation_expression" {
                    has_double_colon: any = False;
                    rhs_is_class: any = False;
                    lhs_node: any = None;
                    for ch in typing.cast(object, curr).children {
                        ch_text: any = _read_text(ch, source);
                        if ch.type == "::" or ch_text == "::" {
                            has_double_colon = True;
                        } elif has_double_colon
                            and ch.type in ("identifier", "simple_identifier")
                            and ch_text == "class"
                        {
                            rhs_is_class = True;
                        } elif not has_double_colon and ch.is_named {
                            lhs_node = ch;
                        }
                    }
                    if has_double_colon and rhs_is_class and lhs_node is not None {
                        raw: any = _read_text(lhs_node, source);
                        text: any = raw.rsplit(".", 1)[-1];
                        if text
                            and text not in seen
                            and text not in _KOTLIN_BUILTIN_TYPES
                            and text not in _JAVA_BUILTIN_TYPES
                        {
                            names.append(text);
                            seen.add(text);
                        }
                        continue;
                    }
                }
                stack.extend(child for child in typing.cast(object, curr).children if child.is_named);
            }
        }
    }
    return names;
}

impl _kotlin_type_parameters_in_scope(`node, source: bytes) -> frozenset[str] {
    names: set[str] = set[any]();
    scope: any = `node;
    while scope is not None {
        for child in typing.cast(object, scope).children {
            if child.type != "type_parameters" {
                continue;
            }
            for param in typing.cast(object, child).children {
                if param.type != "type_parameter" {
                    continue;
                }
                for sub in typing.cast(object, param).children {
                    if sub.type in ("identifier", "type_identifier") {
                        name: any = _read_text(sub, source);
                        if name {
                            names.add(name);
                        }
                        break;
                    }
                }
            }
        }
        scope = scope.parent;
    }
    return frozenset(names);
}

impl _kotlin_collect_type_refs(
    `node,
    source: bytes,
    generic: bool,
    out: list[tuple[str, str]],
    `skip: frozenset[str] | None = None,
) {
    if `node is None {
        return;
    }
    if `skip is None {
        `skip = _kotlin_type_parameters_in_scope(`node, source);
    }
    t: any = `node.type;
    if t in ("integral_literal", "boolean_literal") {
        return;
    }
    if t == "user_type" {
        c: any;
        for c in typing.cast(object, `node).children {
            if c.type in ("identifier", "type_identifier") {
                text: any = _read_text(c, source);
                if text
                    and text not in _KOTLIN_BUILTIN_TYPES
                    and text not in _JAVA_BUILTIN_TYPES
                    and text not in `skip
                {
                    out.append((text, "generic_arg" if generic else "type"));
                }
                break;
            }
            if c.type == "simple_user_type" {
                sub: any;
                for sub in typing.cast(object, c).children {
                    if sub.type in ("identifier", "type_identifier") {
                        text = _read_text(sub, source);
                        if text
                            and text not in _KOTLIN_BUILTIN_TYPES
                            and text not in _JAVA_BUILTIN_TYPES
                            and text not in `skip
                        {
                            out.append((text, "generic_arg" if generic else "type"));
                        }
                        break;
                    }
                }
                break;
            }
        }
        for c in typing.cast(object, `node).children {
            if c.type == "type_arguments" {
                for arg in typing.cast(object, c).children {
                    if arg.type == "type_projection" {
                        for sub in typing.cast(object, arg).children {
                            if sub.is_named {
                                _kotlin_collect_type_refs(sub, source, True, out, `skip);
                            }
                        }
                    } elif arg.is_named {
                        _kotlin_collect_type_refs(arg, source, True, out, `skip);
                    }
                }
            }
        }
        return;
    }
    if t in ("identifier", "type_identifier") {
        text = _read_text(`node, source);
        if text
            and text not in _KOTLIN_BUILTIN_TYPES
            and text not in _JAVA_BUILTIN_TYPES
            and text not in `skip
        {
            out.append((text, "generic_arg" if generic else "type"));
        }
        return;
    }
    if t in ("nullable_type", "parenthesized_type", "type_reference") {
        for c in typing.cast(object, `node).children {
            if c.is_named {
                _kotlin_collect_type_refs(c, source, generic, out, `skip);
            }
        }
        return;
    }
    if `node.is_named {
        for c in typing.cast(object, `node).children {
            if c.is_named {
                _kotlin_collect_type_refs(c, source, generic, out, `skip);
            }
        }
    }
}

impl _kotlin_property_type_node(property_node) -> any {
    for c in typing.cast(object, property_node).children {
        if c.type == "variable_declaration" {
            for sub in typing.cast(object, c).children {
                if sub.type in ("user_type", "nullable_type", "type_reference") {
                    return sub;
                }
            }
        }
        if c.type in ("user_type", "nullable_type", "type_reference") {
            return c;
        }
    }
    return None;
}

impl _kotlin_function_return_type_node(func_node) -> any {
    saw_params: any = False;
    saw_colon: any = False;
    for c in typing.cast(object, func_node).children {
        if c.type == "function_value_parameters" {
            saw_params = True;
            continue;
        }
        if saw_params and c.type == ":" {
            saw_colon = True;
            continue;
        }
        if saw_colon {
            if c.is_named {
                return c;
            }
        }
    }
    return None;
}

impl _swift_declaration_keyword(`node) -> str | None {
    for c in typing.cast(object, `node).children {
        if not c.is_named and c.type in ("class", "struct", "enum", "extension", "actor") {
            return c.type;
        }
    }
    return None;
}

impl _python_alias_name(stmt, source: bytes) -> str | None {
    if stmt.type == "type_alias_statement" {
        left: any;
        right: any;
        (left, right) = (stmt.child_by_field_name("left"), stmt.child_by_field_name("right"));
        name: any = _read_text(left, source).split("[", 1)[0].strip() if left is not None else "";
    } elif stmt.type == "expression_statement" and len(stmt.named_children) == 1 {
        assign: any = stmt.named_children[0];
        left = assign.child_by_field_name("left") if assign.type == "assignment" else None;
        if left is None or left.type != "identifier" {
            return None;
        }
        (name, right) = (_read_text(left, source), assign.child_by_field_name("right"));
        annotation: any = assign.child_by_field_name("type");
        if annotation is None {
            callee: any = right.child_by_field_name("function")
                if right is not None and right.type == "call"
                else None;
            return name
                if callee is not None and _read_text(callee, source) in _PY_NEW_TYPE_CALLEES
                else None;
        }
        if _read_text(annotation, source).strip() not in _PY_TYPE_ALIAS_ANNOTATIONS {
            return None;
        }
    } else {
        return None;
    }
    if not name.isidentifier() {
        return None;
    }
    target: any = _read_text(right, source).split("[", 1)[0].strip() if right is not None else "";
    if target.rsplit(".", 1)[-1] == name {
        return None;
    }
    return name;
}

impl _python_pre_scan_underscore_collisions(
    root_node, source: bytes, stem: str
) -> dict[str, set[str]] {
    groups: dict[str, set[str]];
    groups = {};

    def _record(plain_nid: str, name: str) {
        groups.setdefault(plain_nid, set[any]()).add(name);
    }

    def _undecorated(`node) -> any {
        if `node.type == "decorated_definition" {
            return `node.child_by_field_name("definition") or `node;
        }
        return `node;
    }

    classes: list = [];
    for child in map(_undecorated, root_node.children) {
        alias_name: any = _python_alias_name(child, source);
        if alias_name {
            _record(_make_id(stem, alias_name), alias_name);
        } elif child.type == "function_definition" {
            name_node: any = child.child_by_field_name("name");
            if name_node is not None {
                name: any = _read_text(name_node, source);
                if name {
                    _record(_make_id(stem, name), name);
                }
            }
        } elif child.type == "class_definition" {
            class_name_node: any = child.child_by_field_name("name");
            body: any = child.child_by_field_name("body");
            if class_name_node is None or body is None {
                continue;
            }
            class_name: any = _read_text(class_name_node, source);
            if not class_name {
                continue;
            }
            _record(_make_id(stem, class_name), class_name);
            classes.append((class_name, body));
        }
    }

    module_groups: any = {nid: names for (nid, names) in groups.items() if len(names) >= 2};
    for (class_name, body) in classes {
        class_nid: any = _underscore_salted_nid(
            _make_id(stem, class_name), class_name, module_groups
        );
        for member in map(_undecorated, body.children) {
            if member.type != "function_definition" {
                continue;
            }
            name_node = member.child_by_field_name("name");
            if name_node is None {
                continue;
            }
            name = _read_text(name_node, source);
            if name {
                _record(_make_id(class_nid, name), name);
            }
        }
    }

    return {nid: names for (nid, names) in groups.items() if len(names) >= 2};
}

impl _underscore_salted_nid(
    plain_nid: str,
    name: str,
    groups: dict[str, set[str]],
    private_prefixes: tuple[str, ...] = ("_",),
    private_suffixes: tuple[str, ...] = (),
    leaf=None,
) -> str {
    names: any = groups.get(plain_nid);
    if not names or len(names) < 2 {
        return plain_nid;
    }
    public: any = [
        n
        for n in names
        for part in [leaf(n) if leaf is not None else n]
        if not part.startswith(private_prefixes) and not part.endswith(private_suffixes)
    ];
    if len(public) == 1 and name == public[0] {
        return plain_nid;
    }
    salt: any = hashlib.sha1(name.encode("utf-8"), usedforsecurity=False).hexdigest()[:6];
    return _make_id(plain_nid, salt);
}

impl _js_member_nid(
    class_nid: str, member_node, name: str, source: bytes, groups_cache: dict
) -> str {
    body: any = member_node.parent;
    if body is None {
        return _make_id(class_nid, name);
    }
    key: any = (class_nid, body.start_byte, body.end_byte);
    groups: any = groups_cache.get(key);
    if groups is None {
        names: dict[str, set[str]] = {};
        for c in typing.cast(object, body).children {
            if c.type in _JS_MEMBER_METHOD_TYPES {
                name_node: any = c.child_by_field_name("name");
            } elif c.type in ("field_definition", "public_field_definition") {
                value: any = c.child_by_field_name("value");
                if value is None or value.type not in _JS_FUNCTION_VALUE_TYPES {
                    continue;
                }
                name_node = c.child_by_field_name("property") or c.child_by_field_name("name");
            } else {
                continue;
            }
            text: any = _read_text(name_node, source) if name_node is not None else "";
            if text {
                names.setdefault(_make_id(class_nid, text), set[any]()).add(text);
            }
        }
        groups = {nid: ns for (nid, ns) in names.items() if len(ns) >= 2};
        groups_cache[key] = groups;
    }
    return _underscore_salted_nid(
        _make_id(class_nid, name), name, groups, _JS_PRIVATE_MEMBER_PREFIXES
    );
}

impl _php_member_nid(
    class_nid: str, member_node, name: str, source: bytes, groups_cache: dict
) -> str {
    folded: any = name.casefold();
    body: any = member_node.parent;
    if body is None or body.type not in ("declaration_list", "enum_declaration_list") {
        return _make_id(class_nid, name);
    }
    key: any = (class_nid, body.start_byte, body.end_byte);
    groups: any = groups_cache.get(key);
    if groups is None {
        names: dict[str, set[str]] = {};
        for c in typing.cast(object, body).children {
            if c.type != "method_declaration" {
                continue;
            }
            name_node: any = c.child_by_field_name("name");
            text: any = _read_text(name_node, source) if name_node is not None else "";
            if text {
                names.setdefault(_make_id(class_nid, text), set[any]()).add(text.casefold());
            }
        }
        groups = {nid: ns for (nid, ns) in names.items() if len(ns) >= 2};
        groups_cache[key] = groups;
    }
    return _underscore_salted_nid(_make_id(class_nid, name), folded, groups);
}

impl _java_lombok_getter_annotation(declaration_node, source: bytes) -> any {
    for anno in _java_annotation_nodes(declaration_node) {
        name_node: any = anno.child_by_field_name("name");
        raw: any = _read_text(name_node, source) if name_node is not None else "";
        if raw == "Getter" and not _JAVA_LOMBOK_IMPORT_RE.search(source) {
            continue;
        }
        if raw not in ("Getter", "lombok.Getter") {
            continue;
        }
        args: any = anno.child_by_field_name("arguments");
        if args is not None and re.search("\\bNONE\\b", _read_text(args, source)) {
            return None;
        }
        return anno;
    }
    return None;
}

impl _java_lombok_getters(field_node, source: bytes) -> list[str] {
    body: any = field_node.parent;
    owner: any = body.parent if body is not None else None;
    if owner is None {
        return [];
    }
    `own: any = _java_lombok_getter_annotation(field_node, source);
    if `own is None {
        if `any(
            a.child_by_field_name("name") is not None
                and _read_text(a.child_by_field_name("name"), source) in ("Getter", "lombok.Getter")
            for a in _java_annotation_nodes(field_node),
        ) {
            return [];
        }
        if _java_has_modifier(field_node, "static")
            or _java_lombok_getter_annotation(owner, source) is None
        {
            return [];
        }
    }
    type_node: any = field_node.child_by_field_name("type");
    is_boolean: any = type_node is not None
        and operator.eq(_read_text(type_node, source), "boolean");
    declared: any = set[any]();
    for c in typing.cast(object, body).children {
        if c.type != "method_declaration" {
            continue;
        }
        params: any = c.child_by_field_name("parameters");
        name_node: any = c.child_by_field_name("name");
        if name_node is not None
            and params is not None
            and not `any(
                p.type in ("formal_parameter", "spread_parameter") for p in typing.cast(object, params).children
            )
        {
            declared.add(_read_text(name_node, source).lower());
        }
    }
    names: any = [];
    for field in _java_declarator_names(field_node, source) {
        if is_boolean and field.startswith("is") and field[2:3].isupper() {
            `getter: any = field;
        } else {
            `getter = ("is" if is_boolean else "get") + field[:1].upper() + field[1:];
        }
        if `getter.lower() not in declared {
            names.append(`getter);
        }
    }
    return names;
}

impl _java_member_nid(
    class_nid: str, member_node, name: str, source: bytes, groups_cache: dict
) -> str {
    body: any = member_node.parent;
    if body is None {
        return _make_id(class_nid, name);
    }
    key: any = (class_nid, body.start_byte, body.end_byte);
    groups: any = groups_cache.get(key);
    if groups is None {
        names: dict[str, set[str]] = {};
        for c in typing.cast(object, body).children {
            if c.type not in _JAVA_MEMBER_CALLABLE_TYPES {
                continue;
            }
            name_node: any = c.child_by_field_name("name");
            text: any = _read_text(name_node, source) if name_node is not None else "";
            if text {
                names.setdefault(_make_id(class_nid, text), set[any]()).add(text);
            }
        }
        groups = {nid: ns for (nid, ns) in names.items() if len(ns) >= 2};
        groups_cache[key] = groups;
    }
    return _underscore_salted_nid(_make_id(class_nid, name), name, groups);
}

impl _java_erase_type(text: str) -> str {
    out: list[str] = [];
    depth: any = 0;
    for ch in text {
        if ch == "<" {
            depth += 1;
        } elif ch == ">" {
            depth = max(0, depth - 1);
        } elif depth == 0 and not ch.isspace() {
            out.append(ch);
        }
    }
    return "".join(out);
}

impl _java_type_var_bounds(`node, source: bytes) -> dict[str, str] {
    scopes: any = [];
    cur: any = `node;
    while cur is not None {
        if cur.type in _JAVA_TYPE_PARAM_OWNERS {
            scopes.append(cur);
        }
        cur = cur.parent;
    }
    bounds: dict[str, str] = {};
    for owner in reversed(scopes) {
        tparams: any = next((c for c in typing.cast(object, owner).children if c.type == "type_parameters"), None);
        if tparams is None {
            continue;
        }
        local: dict[str, str] = {};
        for tp in typing.cast(object, tparams).children {
            if tp.type != "type_parameter" {
                continue;
            }
            name_node: any = next((c for c in typing.cast(object, tp).children if c.type == "type_identifier"), None);
            if name_node is None {
                continue;
            }
            bound: any = next((c for c in typing.cast(object, tp).children if c.type == "type_bound"), None);
            first: any = next((c for c in typing.cast(object, bound).children if c.is_named), None)
                if bound is not None
                else None;
            erased: any = _java_erase_type(_read_text(first, source))
                if first is not None
                else "Object";
            local[_read_text(name_node, source)] = erased or "Object";
        }
        resolved: dict[str, str] = {};
        for name in local {
            seen: any;
            (erased, seen) = (local[name], {name});
            while erased not in seen and (erased in local or erased in bounds) {
                seen.add(erased);
                erased = local[erased] if erased in local else bounds[erased];
            }
            resolved[name] = erased;
        }
        bounds.update(resolved);
    }
    return bounds;
}

impl _java_erase_type_var(text: str, bounds: dict[str, str]) -> str {
    base: any = text.rstrip("[].");
    suffix: any = text[len(base):];
    return bounds.get(base, base) + suffix;
}

impl _java_method_signature(`node, source: bytes) -> tuple[str, dict] {
    bounds: any = _java_type_var_bounds(`node, source);
    params: any = `node.child_by_field_name("parameters");
    parts: list[str] = [];
    arity: any = 0;
    variadic: any = False;
    for c in params.children if params is not None else [] {
        if c.type == "formal_parameter" {
            type_node: any = c.child_by_field_name("type");
            text: any = _java_erase_type(_read_text(type_node, source))
                if type_node is not None
                else "";
            dims: any = c.child_by_field_name("dimensions");
            if dims is not None {
                text += "".join(_read_text(dims, source).split());
            }
            parts.append(_java_erase_type_var(text, bounds));
            arity += 1;
        } elif c.type == "spread_parameter" {
            type_node = next(
                (x
                for x in typing.cast(object, c).children
                if x.is_named and x.type not in ("modifiers", "variable_declarator")),
                None,
            );
            text = _java_erase_type(_read_text(type_node, source)) if type_node is not None else "";
            parts.append(_java_erase_type_var(text, bounds) + "...");
            arity += 1;
            variadic = True;
        }
    }
    meta: dict = {"arity": arity};
    if variadic {
        meta["variadic"] = True;
        meta["min_arity"] = arity - 1;
    }
    return (",".join(parts), meta);
}

impl _java_argc(call_node) -> int | None {
    if call_node.type != "method_invocation" {
        return None;
    }
    args: any = call_node.child_by_field_name("arguments");
    return sum(
        1 for c in typing.cast(object, args).children if c.is_named and c.type not in ("line_comment", "block_comment")
    )
        if args is not None
        else 0;
}

impl _kotlin_function_name(`node, source: bytes) -> str {
    name_node: any = `node.child_by_field_name("name");
    if name_node is None {
        name_node = next((c for c in typing.cast(object, `node).children if c.type == "simple_identifier"), None);
    }
    return _read_text(name_node, source) if name_node is not None else "";
}

impl _kotlin_member_nid(
    class_nid: str, member_node, name: str, source: bytes, groups_cache: dict
) -> str {
    body: any = member_node.parent;
    if body is None or body.type not in _KOTLIN_MEMBER_BODY_TYPES or body.parent is None {
        return _make_id(class_nid, name);
    }
    owner: any = body.parent;
    if owner.type == "companion_object"
        and owner.parent is not None
        and owner.parent.type in _KOTLIN_MEMBER_BODY_TYPES
    {
        body = owner.parent;
    }
    key: any = (class_nid, body.start_byte, body.end_byte);
    groups: any = groups_cache.get(key);
    if groups is None {
        names: dict[str, set[str]] = {};
        bodies: any = [body];
        while bodies {
            for c in bodies.pop().children {
                if c.type == "function_declaration" {
                    text: any = _kotlin_function_name(c, source);
                    if text and normalize_id(text) {
                        names.setdefault(_make_id(class_nid, text), set[any]()).add(
                            text.strip("`")
                        );
                    }
                } elif c.type == "companion_object" {
                    bodies.extend(b for b in typing.cast(object, c).children if b.type in _KOTLIN_MEMBER_BODY_TYPES);
                }
            }
        }
        groups = {nid: ns for (nid, ns) in names.items() if len(ns) >= 2};
        groups_cache[key] = groups;
    }
    return _underscore_salted_nid(_make_id(class_nid, name), name.strip("`"), groups);
}

impl _swift_type_decl_name(decl, source: bytes) -> str {
    name_node: any = decl.child_by_field_name("name");
    if name_node is None {
        name_node = next((c for c in typing.cast(object, decl).children if c.type in _SWIFT_TYPE_NAME_TYPES), None);
    }
    return _read_text(name_node, source) if name_node is not None else "";
}

impl _swift_member_nid(
    class_nid: str, member_node, name: str, source: bytes, groups_cache: dict
) -> str {
    decl: any;
    owner: any = member_node.parent;
    while owner is not None and owner.type not in _SWIFT_TYPE_DECL_TYPES {
        owner = owner.parent;
    }
    if owner is None {
        return _make_id(class_nid, name);
    }
    owner_name: any = _swift_type_decl_name(owner, source);
    key: any = (class_nid, owner_name);
    groups: any = groups_cache.get(key);
    if groups is None {
        by_owner: any = groups_cache.get(None);
        if by_owner is None {
            by_owner = {};
            `root: any = owner;
            while `root.parent is not None {
                `root = `root.parent;
            }
            stack: any = [(`root, None)];
            while stack {
                n: any;
                (n, decl) = stack.pop() as any;
                if n.type in _SWIFT_MEMBER_CALLABLE_TYPES {
                    name_node: any = n.child_by_field_name("name");
                    if name_node is None {
                        name_node = next(
                            (c for c in typing.cast(object, n).children if c.type == "simple_identifier"), None
                        );
                    }
                    text: any = _read_text(name_node, source) if name_node is not None else "";
                    if decl is not None and text and normalize_id(text) {
                        by_owner.setdefault(_swift_type_decl_name(decl, source), set[any]()).add(
                            text
                        );
                    }
                    continue;
                }
                if n.type in _SWIFT_TYPE_DECL_TYPES {
                    decl = n;
                }
                stack.extend((c, decl) for c in typing.cast(object, n).children);
            }
            groups_cache[None] = by_owner;
        }
        names: dict[str, set[str]] = {};
        for text in by_owner.get(owner_name, ()) {
            names.setdefault(_make_id(class_nid, text), set[any]()).add(text);
        }
        groups = {nid: ns for (nid, ns) in names.items() if len(ns) >= 2};
        groups_cache[key] = groups;
    }
    return _underscore_salted_nid(_make_id(class_nid, name), name, groups);
}

impl _ruby_member_nid(
    class_nid: str, member_node, name: str, source: bytes, groups_cache: dict, sanitize
) -> str {
    body: any = member_node.parent;
    if body is not None and body.parent is not None and body.parent.type == "singleton_class" {
        body = body.parent.parent;
    }
    if body is None {
        return _make_id(class_nid, name);
    }
    key: any = (class_nid, body.start_byte, body.end_byte);
    groups: any = groups_cache.get(key);
    if groups is None {
        names: dict[str, set[str]] = {};
        stack: any = `list(body.children);
        while stack {
            c: any = stack.pop();
            if c.type == "singleton_class" {
                inner: any = c.child_by_field_name("body");
                if inner is not None {
                    stack.extend(inner.children);
                }
                continue;
            }
            if c.type not in _RUBY_MEMBER_CALLABLE_TYPES {
                continue;
            }
            name_node: any = c.child_by_field_name("name");
            text: any = sanitize(_read_text(name_node, source)) if name_node is not None else "";
            if text and normalize_id(text) {
                names.setdefault(_make_id(class_nid, text), set[any]()).add(text);
            }
        }
        groups = {nid: ns for (nid, ns) in names.items() if len(ns) >= 2};
        groups_cache[key] = groups;
    }
    return _underscore_salted_nid(_make_id(class_nid, name), name, groups);
}

impl _lua_field_name(name: str) -> str {
    return name.replace(":", ".");
}

impl _lua_field_leaf(name: str) -> str {
    return name.rsplit(".", 1)[-1];
}

impl _lua_pre_scan_field_collisions(`root, source: bytes, stem: str) -> dict[str, set[str]] {
    names: dict[str, set[str]] = {};
    stack: any = [`root];
    while stack {
        n: any = stack.pop();
        if n.type == "function_declaration" {
            name_node: any = n.child_by_field_name("name");
            if name_node is not None
                and name_node.type in ("dot_index_expression", "method_index_expression")
            {
                text: any = _lua_field_name(_read_text(name_node, source));
                if normalize_id(_lua_field_leaf(text)) {
                    names.setdefault(_make_id(stem, text), set[any]()).add(text);
                }
            }
        }
        stack.extend(n.children);
    }
    return {nid: ns for (nid, ns) in names.items() if len(ns) >= 2};
}

impl _scala_member_nid(
    class_nid: str, member_node, name: str, source: bytes, groups_cache: dict
) -> str {
    body: any = member_node.parent;
    owner: any = body.parent if body is not None else None;
    if owner is None or owner.type not in _SCALA_OWNER_TYPES or owner.parent is None {
        return _make_id(class_nid, name);
    }
    name_node: any = owner.child_by_field_name("name");
    owner_name: any = _read_text(name_node, source) if name_node is not None else "";
    scope: any = owner.parent;
    key: any = (class_nid, scope.start_byte, scope.end_byte, owner_name);
    groups: any = groups_cache.get(key);
    if groups is None {
        names: dict[str, set[str]] = {};
        for decl in typing.cast(object, scope).children {
            if decl.type not in _SCALA_OWNER_TYPES {
                continue;
            }
            decl_name: any = decl.child_by_field_name("name");
            if decl is not owner
                and (decl_name is None or _read_text(decl_name, source) != owner_name)
            {
                continue;
            }
            for b in typing.cast(object, decl).children {
                if b.type not in ("template_body", "enum_body", "with_template_body") {
                    continue;
                }
                for c in typing.cast(object, b).children {
                    if c.type not in _SCALA_MEMBER_CALLABLE_TYPES {
                        continue;
                    }
                    member_name: any = c.child_by_field_name("name");
                    text: any = _read_text(member_name, source) if member_name is not None else "";
                    if text and normalize_id(text) {
                        names.setdefault(_make_id(class_nid, text), set[any]()).add(text);
                    }
                }
            }
        }
        groups = {nid: ns for (nid, ns) in names.items() if len(ns) >= 2};
        groups_cache[key] = groups;
    }
    return _underscore_salted_nid(
        _make_id(class_nid, name), name, groups, private_suffixes=_SCALA_PRIVATE_MEMBER_SUFFIXES
    );
}

impl _cpp_is_method_declarator(decl) -> bool {
    return operator.eq(decl.type, "function_declarator")
        or decl.type in ("pointer_declarator", "reference_declarator")
            and `any(operator.eq(c.type, "function_declarator") for c in typing.cast(object, decl).children);
}

impl _cpp_member_nid(
    class_nid: str, member_node, name: str, source: bytes, groups_cache: dict
) -> str {
    body: any = member_node.parent;
    while body is not None and body.type == "template_declaration" {
        body = body.parent;
    }
    if body is None or body.type != "field_declaration_list" {
        return _make_id(class_nid, name);
    }
    key: any = (class_nid, body.start_byte, body.end_byte);
    groups: any = groups_cache.get(key);
    if groups is None {
        names: dict[str, set[str]] = {};
        stack: any = `list(body.children);
        while stack {
            c: any = stack.pop();
            texts: list[str] = [];
            if c.type == "function_definition" {
                d: any = c.child_by_field_name("declarator");
                text: any = _get_cpp_func_name(d, source) if d is not None else None;
                texts = [text] if text else [];
            } elif c.type == "field_declaration"
                or c.type == "declaration"
                    and c.parent is not None
                    and c.parent.type == "template_declaration"
            {
                texts = [
                    t
                    for d in c.children_by_field_name("declarator")
                    if _cpp_is_method_declarator(d)
                    for t in [_get_cpp_func_name(d, source)]
                    if t
                ];
            } elif c.type == "template_declaration" {
                stack.extend(c.children);
            }
            for text in texts {
                if "::" not in text and not text.startswith("operator") and normalize_id(text) {
                    names.setdefault(_make_id(class_nid, text), set[any]()).add(text);
                }
            }
        }
        groups = {nid: ns for (nid, ns) in names.items() if len(ns) >= 2};
        groups_cache[key] = groups;
    }
    return _underscore_salted_nid(
        _make_id(class_nid, name),
        name,
        groups,
        _CPP_PRIVATE_MEMBER_PREFIXES,
        _CPP_PRIVATE_MEMBER_SUFFIXES,
    );
}

impl _swift_pre_scan(root_node, source: bytes) -> tuple[set[str], set[str]] {
    protocols: set[str] = set[any]();
    classes: set[str] = set[any]();
    stack: any = [root_node];
    while stack {
        n: any = stack.pop();
        if n.type == "protocol_declaration" {
            name_node: any = n.child_by_field_name("name");
            if name_node is None {
                for c in typing.cast(object, n).children {
                    if c.type == "type_identifier" {
                        name_node = c;
                        break;
                    }
                }
            }
            if name_node is not None {
                text: any = _read_text(name_node, source);
                if text {
                    protocols.add(text);
                }
            }
        } elif n.type == "class_declaration" {
            kw: any = _swift_declaration_keyword(n);
            if kw in ("class", "struct", "enum", "actor") {
                name_node = n.child_by_field_name("name");
                if name_node is not None {
                    text = _read_text(name_node, source);
                    if text {
                        classes.add(text);
                    }
                }
            }
        }
        stack.extend(n.children);
    }
    return (protocols, classes);
}

impl _swift_classify_base(
    name: str, kind: str | None, is_first: bool, protocols: set[str], classes: set[str]
) -> str {
    if name in protocols {
        return "implements";
    }
    if name in classes {
        return "inherits";
    }
    if kind in ("struct", "enum", "extension", "actor") {
        return "implements";
    }
    return "inherits" if is_first else "implements";
}

impl _swift_user_type_name(user_type_node, source: bytes) -> str | None {
    if user_type_node is None {
        return None;
    }
    for c in typing.cast(object, user_type_node).children {
        if c.type == "type_identifier" {
            text: any = _read_text(c, source);
            return text or None;
        }
    }
    return None;
}

impl _swift_receiver_type_name(`node, source: bytes) -> str | None {
    child: any;
    if `node is None {
        return None;
    }
    if `node.type == "user_type" {
        names: any = [
            _read_text(child, source)
            for child in typing.cast(object, `node).children
            if child.type == "type_identifier"
        ];
        return ".".join(names) or None;
    }
    if `node.type in ("type_annotation", "optional_type", "implicitly_unwrapped_optional_type") {
        for child in typing.cast(object, `node).named_children {
            if name := _swift_receiver_type_name(child, source) {
                return name;
            }
        }
    }
    return None;
}

impl _swift_type_parameters_in_scope(`node, source: bytes) -> frozenset[str] {
    names: set[str] = set[any]();
    scope: any = `node;
    while scope is not None {
        for child in typing.cast(object, scope).children {
            if child.type != "type_parameters" {
                continue;
            }
            for param in typing.cast(object, child).children {
                if param.type != "type_parameter" {
                    continue;
                }
                for sub in typing.cast(object, param).children {
                    if sub.type == "type_identifier" {
                        name: any = _read_text(sub, source);
                        if name {
                            names.add(name);
                        }
                        break;
                    }
                }
            }
        }
        scope = scope.parent;
    }
    return frozenset(names);
}

impl _swift_collect_type_refs(
    `node,
    source: bytes,
    generic: bool,
    out: list[tuple[str, str]],
    `skip: frozenset[str] | None = None,
) {
    if `node is None {
        return;
    }
    if `skip is None {
        `skip = _swift_type_parameters_in_scope(`node, source);
    }
    t: any = `node.type;
    if t == "type_annotation" {
        c: any;
        for c in typing.cast(object, `node).children {
            if c.is_named {
                _swift_collect_type_refs(c, source, generic, out, `skip);
            }
        }
        return;
    }
    if t == "user_type" {
        for c in typing.cast(object, `node).children {
            if c.type == "type_identifier" {
                text: any = _read_text(c, source);
                if text and text != "Self" and text not in `skip {
                    out.append((text, "generic_arg" if generic else "type"));
                }
                break;
            }
        }
        for c in typing.cast(object, `node).children {
            if c.type == "type_arguments" {
                for arg in typing.cast(object, c).children {
                    if arg.is_named {
                        _swift_collect_type_refs(arg, source, True, out, `skip);
                    }
                }
            }
        }
        return;
    }
    if t == "type_identifier" {
        text = _read_text(`node, source);
        if text and text != "Self" and text not in `skip {
            out.append((text, "generic_arg" if generic else "type"));
        }
        return;
    }
    if t
        in (
            "optional_type",
            "implicitly_unwrapped_optional_type",
            "array_type",
            "dictionary_type",
            "tuple_type",
        )
    {
        for c in typing.cast(object, `node).children {
            if c.is_named {
                _swift_collect_type_refs(c, source, generic, out, `skip);
            }
        }
        return;
    }
    if `node.is_named {
        for c in typing.cast(object, `node).children {
            if c.is_named {
                _swift_collect_type_refs(c, source, generic, out, `skip);
            }
        }
    }
}

impl _swift_property_type_node(property_node) -> any {
    for c in typing.cast(object, property_node).children {
        if c.type == "type_annotation" {
            return c;
        }
    }
    return None;
}

impl _swift_attribute_type_name(property_node, source: bytes) -> str | None {
    for c in typing.cast(object, property_node).children {
        if c.type != "modifiers" {
            continue;
        }
        for attr in typing.cast(object, c).children {
            if attr.type != "attribute" {
                continue;
            }
            head: any = next((a for a in typing.cast(object, attr).children if a.type == "user_type"), None);
            if head is None or _read_text(head, source) != "Environment" {
                continue;
            }
            arg: any = next((a for a in typing.cast(object, attr).children if a.type == "navigation_expression"), None);
            if arg is None {
                continue;
            }
            named: any = [a for a in typing.cast(object, arg).children if a.is_named];
            if len(named) != 2 {
                continue;
            }
            ident: any;
            suffix: any;
            (ident, suffix) = named as any;
            if ident.type != "simple_identifier" or suffix.type != "navigation_suffix" {
                continue;
            }
            if _read_text(suffix, source) != ".self" {
                continue;
            }
            name: any = _read_text(ident, source);
            if name and name[:1].isupper() {
                return name;
            }
        }
    }
    return None;
}

impl _swift_factory_call(call_node, source: bytes) -> tuple[str, str] | None {
    first: any = call_node.children[0] if call_node.children else None;
    if first is None or first.type != "navigation_expression" {
        return None;
    }
    named: any = [c for c in typing.cast(object, first).children if c.is_named];
    if len(named) != 2 {
        return None;
    }
    head: any;
    suffix: any;
    (head, suffix) = named as any;
    if head.type != "simple_identifier" or suffix.type != "navigation_suffix" {
        return None;
    }
    htext: any = _read_text(head, source);
    if not htext or not htext[:1].isupper() {
        return None;
    }
    mname: any = next(
        (_read_text(sc, source) for sc in typing.cast(object, suffix).children if sc.type == "simple_identifier"), None
    );
    if not mname {
        return None;
    }
    return (htext, mname);
}

impl _swift_property_name(property_node, source: bytes) -> str | None {
    for c in typing.cast(object, property_node).children {
        if c.type == "pattern" {
            for sc in typing.cast(object, c).children {
                if sc.type == "simple_identifier" {
                    return _read_text(sc, source);
                }
            }
        }
        if c.type == "simple_identifier" {
            return _read_text(c, source);
        }
    }
    return None;
}

impl _swift_constructor_type(call_node, source: bytes) -> str | None {
    first: any = call_node.children[0] if call_node.children else None;
    if first is not None and first.type == "simple_identifier" {
        text: any = _read_text(first, source);
        if text and text[:1].isupper() {
            return text;
        }
    }
    if first is not None and first.type == "navigation_expression" {
        name: any = _swift_receiver_name(first, source);
        if name and "." in name {
            return name;
        }
    }
    return None;
}

impl _swift_receiver_name(recv_node, source: bytes) -> str | None {
    if recv_node is None {
        return None;
    }
    if recv_node.type == "simple_identifier" {
        return _read_text(recv_node, source);
    }
    if recv_node.type == "navigation_expression" {
        names: list[str] = [];
        stack: any = [recv_node];
        while stack {
            child: any = stack.pop();
            if child.type == "simple_identifier" {
                names.append(_read_text(child, source));
            } elif child.type in ("navigation_expression", "navigation_suffix") {
                stack.extend(reversed(child.named_children));
            } else {
                break;
            }
        } else {
            if names and all(name[:1].isupper() for name in names) {
                return ".".join(names);
            }
        }
        head: any = recv_node.children[0] if recv_node.children else None;
        if head is not None and head.type == "simple_identifier" {
            return _read_text(head, source);
        }
        if head is not None and head.type == "self_expression" {
            for child in typing.cast(object, recv_node).children {
                if child.type == "navigation_suffix" {
                    for sc in typing.cast(object, child).children {
                        if sc.type == "simple_identifier" {
                            return _read_text(sc, source);
                        }
                    }
                }
            }
        }
    }
    return None;
}

impl _swift_operand_tail(`node) -> any {
    while `node is not None {
        if `node.type in ("additive_expression", "multiplicative_expression") {
            `node = `node.child_by_field_name("rhs");
        } elif `node.type == "prefix_expression"
            and `node.children
            and `node.children[0].type != "."
        {
            `node = `node.child_by_field_name("target");
        } else {
            break;
        }
    }
    return `node;
}

impl _c_collect_type_refs(`node, source: bytes, generic: bool, out: list[tuple[str, str]]) {
    if `node is None or `node.type in _C_PRIMITIVE_TYPE_NODES {
        return;
    }
    t: any = `node.type;
    if t == "type_identifier" {
        text: any = _read_text(`node, source);
        if text {
            out.append((text, "generic_arg" if generic else "type"));
        }
        return;
    }
    if t
        in (
            "pointer_declarator",
            "reference_declarator",
            "array_declarator",
            "type_qualifier",
            "type_descriptor",
            "abstract_pointer_declarator",
            "abstract_reference_declarator",
            "abstract_array_declarator",
        )
    {
        for c in typing.cast(object, `node).children {
            if c.is_named {
                _c_collect_type_refs(c, source, generic, out);
            }
        }
    }
}

impl _cpp_type_parameters_in_scope(`node, source: bytes) -> frozenset[str] {
    parameter_types: any;
    names: set[str] = set[any]();
    parameter_types = (
        "type_parameter_declaration",
        "optional_type_parameter_declaration",
        "variadic_type_parameter_declaration",
    );
    scope: any = `node;
    while scope is not None {
        for child in typing.cast(object, scope).children {
            if child.type != "template_parameter_list" {
                continue;
            }
            param: any;
            for param in typing.cast(object, child).children {
                if param.type == "template_template_parameter_declaration" {
                    param = next((c for c in typing.cast(object, param).children if c.type in parameter_types), None);
                }
                if param is None or param.type not in parameter_types {
                    continue;
                }
                for sub in typing.cast(object, param).children {
                    if sub.type == "type_identifier" {
                        name: any = _read_text(sub, source);
                        if name {
                            names.add(name);
                        }
                        break;
                    }
                }
            }
        }
        scope = scope.parent;
    }
    return frozenset(names);
}

impl _cpp_collect_type_refs(
    `node,
    source: bytes,
    generic: bool,
    out: list[tuple[str, str]],
    `skip: frozenset[str] | None = None,
    dialect_quals: frozenset[str] = dialect_quals_default_,
) {
    if `node is None or `node.type in _C_PRIMITIVE_TYPE_NODES {
        return;
    }
    if `skip is None {
        `skip = _cpp_type_parameters_in_scope(`node, source);
    }
    t: any = `node.type;
    if t == "type_identifier" {
        text: any = _read_text(`node, source);
        if text and text not in `skip and text not in dialect_quals {
            out.append((text, "generic_arg" if generic else "type"));
        }
        return;
    }
    if t == "qualified_identifier" {
        name_node: any = `node.child_by_field_name("name");
        scope_node: any = `node.child_by_field_name("scope");
        if scope_node is not None and _read_text(scope_node, source) == "std" {
            while name_node is not None and name_node.type == "qualified_identifier" {
                name_node = name_node.child_by_field_name("name");
            }
            if name_node is None {
                return;
            }
            role: any = "generic_arg" if generic else "type";
            if name_node.type == "type_identifier" {
                text = _read_text(name_node, source);
                if text and text not in dialect_quals {
                    out.append((_CppStdName(text), role));
                }
            } elif name_node.type == "template_type" {
                base: any = name_node.child_by_field_name("name");
                text = _read_text(base, source) if base is not None else "";
                if text and text not in dialect_quals {
                    out.append((_CppStdName(text), role));
                }
                args_node: any = name_node.child_by_field_name("arguments");
                if args_node is not None {
                    c: any;
                    for c in typing.cast(object, args_node).children {
                        if c.is_named {
                            _cpp_collect_type_refs(c, source, True, out, `skip, dialect_quals);
                        }
                    }
                }
            }
            return;
        }
        if name_node is not None {
            _cpp_collect_type_refs(name_node, source, generic, out, `skip, dialect_quals);
        }
        return;
    }
    if t == "template_type" {
        name_node = `node.child_by_field_name("name");
        if name_node is not None {
            text = _read_text(name_node, source);
            if text and text not in `skip and text not in dialect_quals {
                out.append((text, "generic_arg" if generic else "type"));
            }
        }
        args_node = `node.child_by_field_name("arguments");
        if args_node is not None {
            for c in typing.cast(object, args_node).children {
                if c.is_named {
                    _cpp_collect_type_refs(c, source, True, out, `skip, dialect_quals);
                }
            }
        }
        return;
    }
    if t
        in (
            "type_descriptor",
            "pointer_declarator",
            "reference_declarator",
            "array_declarator",
            "type_qualifier",
            "abstract_pointer_declarator",
            "abstract_reference_declarator",
            "abstract_array_declarator",
        )
    {
        for c in typing.cast(object, `node).children {
            if c.is_named {
                _cpp_collect_type_refs(c, source, generic, out, `skip, dialect_quals);
            }
        }
    }
}

impl _scala_given_synthetic_name(`node, source: bytes) -> str | None {
    for c in typing.cast(object, `node).children {
        base: any = None;
        if c.type == "generic_type" {
            base = next(
                (cc
                for cc in typing.cast(object, c).children
                if cc.type in ("type_identifier", "stable_type_identifier", "identifier")),
                None,
            );
        } elif c.type in ("type_identifier", "stable_type_identifier") {
            base = c;
        }
        if base is not None {
            text: any = _read_text(base, source).strip();
            if text {
                return f"given {text}";
            }
        }
    }
    return "given";
}

impl _scala_type_parameters_in_scope(`node, source: bytes) -> frozenset[str] {
    names: set[str] = set[any]();
    scope: any = `node;
    while scope is not None {
        for child in typing.cast(object, scope).children {
            if child.type != "type_parameters" {
                continue;
            }
            for param in typing.cast(object, child).children {
                if param.type in ("identifier", "type_identifier") {
                    name: any = _read_text(param, source);
                    if name {
                        names.add(name);
                    }
                } elif param.type in ("covariant_type_parameter", "contravariant_type_parameter") {
                    for sub in typing.cast(object, param).children {
                        if sub.type in ("identifier", "type_identifier") {
                            name = _read_text(sub, source);
                            if name {
                                names.add(name);
                            }
                            break;
                        }
                    }
                }
            }
        }
        scope = scope.parent;
    }
    return frozenset(names);
}

impl _scala_collect_type_refs(
    `node,
    source: bytes,
    generic: bool,
    out: list[tuple[str, str]],
    `skip: frozenset[str] | None = None,
) {
    if `node is None {
        return;
    }
    if `skip is None {
        `skip = _scala_type_parameters_in_scope(`node, source);
    }
    t: any = `node.type;
    if t == "type_identifier" {
        text: any = _read_text(`node, source);
        if text and text not in `skip {
            out.append((text, "generic_arg" if generic else "type"));
        }
        return;
    }
    if t == "generic_type" {
        base: any = `node.child_by_field_name("type");
        if base is None {
            c: any;
            for c in typing.cast(object, `node).children {
                if c.type == "type_identifier" {
                    base = c;
                    break;
                }
            }
        }
        if base is not None and base.type == "type_identifier" {
            text = _read_text(base, source);
            if text and text not in `skip {
                out.append((text, "generic_arg" if generic else "type"));
            }
        }
        for c in typing.cast(object, `node).children {
            if c.type == "type_arguments" {
                for arg in typing.cast(object, c).children {
                    if arg.is_named {
                        _scala_collect_type_refs(arg, source, True, out, `skip);
                    }
                }
            }
        }
        return;
    }
    if t
        in (
            "compound_type",
            "infix_type",
            "function_type",
            "tuple_type",
            "annotated_type",
            "projected_type",
            "repeated_parameter_type",
            "lazy_parameter_type",
        )
    {
        for c in typing.cast(object, `node).children {
            if c.is_named {
                _scala_collect_type_refs(c, source, generic, out, `skip);
            }
        }
    }
    if t in ("match_type", "type_case_clause") {
        for c in typing.cast(object, `node).children {
            if c.is_named {
                _scala_collect_type_refs(c, source, generic, out, `skip);
            }
        }
    }
}

impl _scala_collect_context_bounds(tp_node, source: bytes, out: list[tuple[str, str]]) {
    if tp_node is None {
        return;
    }
    for c in typing.cast(object, tp_node).children {
        if c.type == "type_parameters" {
            _scala_collect_context_bounds(c, source, out);
        } elif c.type == "context_bound" {
            bound_type: any = c.child_by_field_name("type");
            if bound_type is not None {
                _scala_collect_type_refs(bound_type, source, False, out);
            }
        }
    }
}

impl _python_collect_param_refs(params_node, source: bytes) -> list[tuple[str, str]] {
    out: list[tuple[str, str]] = [];
    if params_node is None {
        return out;
    }
    for child in typing.cast(object, params_node).children {
        if child.type in ("typed_parameter", "typed_default_parameter") {
            type_node: any = child.child_by_field_name("type");
            _python_collect_type_refs(type_node, source, False, out);
        }
    }
    return out;
}

impl _python_is_pytest_fixture(func_node, source: bytes) -> bool {
    parent: any = func_node.parent;
    if parent is None or parent.type != "decorated_definition" {
        return False;
    }
    for dec in typing.cast(object, parent).children {
        if dec.type != "decorator" {
            continue;
        }
        expr: any = next(iter(dec.named_children), None);
        if expr is not None and expr.type == "call" {
            expr = expr.child_by_field_name("function");
        }
        if expr is not None and _read_text(expr, source) in _PYTEST_FIXTURE_DECORATORS {
            return True;
        }
    }
    return False;
}

impl _python_base_name_node(arg) -> any {
    if arg.type == "subscript" {
        arg = arg.child_by_field_name("value");
    }
    return arg if arg is not None and arg.type == "identifier" else None;
}

impl _python_annotation_class(type_node, source: bytes) -> str | None {
    `node: any = type_node;
    while `node is not None and `node.type == "type" {
        `node = next(iter(`node.named_children), None);
    }
    if `node is None {
        return None;
    }
    if `node.type == "generic_type" {
        head: any = next(
            (c for c in typing.cast(object, `node).named_children if c.type in ("identifier", "attribute")), None
        );
        params: any = next((c for c in typing.cast(object, `node).named_children if c.type == "type_parameter"), None);
        if head is None or params is None {
            return None;
        }
        if _read_text(head, source).rsplit(".", 1)[-1] not in _PYTHON_ITERATOR_WRAPPERS {
            return None;
        }
        return _python_annotation_class(next(iter(params.named_children), None), source);
    }
    if `node.type not in ("identifier", "attribute") {
        return None;
    }
    name: any = _read_text(`node, source).rsplit(".", 1)[-1];
    return name if name[:1].isupper() else None;
}

impl _python_fixture_type(func_node, source: bytes, local_types: dict[str, str | None]) -> str {
    ret: any = func_node.child_by_field_name("return_type");
    if ret is not None {
        return _python_annotation_class(ret, source) or PYTEST_FIXTURE_UNTYPED;
    }
    found: set[str | None] = set[any]();
    body: any = func_node.child_by_field_name("body");
    stack: any = `list(body.children) if body is not None else [];
    while stack {
        `node: any = stack.pop();
        if `node.type in ("function_definition", "class_definition", "lambda") {
            continue;
        }
        value: any = None;
        if `node.type == "return_statement" {
            value = next(iter(`node.named_children), None);
        } elif `node.type == "yield" {
            value = next(iter(`node.named_children), None);
        } else {
            stack.extend(`node.children);
            continue;
        }
        if value is None {
            continue;
        }
        if value.type == "call" {
            fn: any = value.child_by_field_name("function");
            name: any = _read_text(fn, source).rsplit(".", 1)[-1]
                if fn is not None and fn.type in ("identifier", "attribute")
                else "";
            found.add(name if name[:1].isupper() else None);
        } elif value.type == "identifier" {
            found.add(local_types.get(_read_text(value, source)));
        } else {
            found.add(None);
        }
    }
    if len(found) == 1 {
        only: any = next(iter(found));
        if only {
            return only;
        }
    }
    return PYTEST_FIXTURE_UNTYPED;
}

impl _python_untouched_params(func_node, source: bytes) -> set[str] {
    params: any = func_node.child_by_field_name("parameters");
    names: set[str] = set[any]();
    if params is not None {
        for child in typing.cast(object, params).children {
            if child.type == "identifier" {
                names.add(_read_text(child, source));
            }
        }
    }
    rebound: set[str] = set[any]();
    body: any = func_node.child_by_field_name("body");
    stack: any = `list(body.children) if body is not None else [];
    while stack {
        `node: any = stack.pop();
        if `node.type in ("function_definition", "class_definition", "lambda") {
            continue;
        }
        if `node.type in ("assignment", "augmented_assignment", "for_statement", "for_in_clause") {
            _python_collect_assignment_targets(`node.child_by_field_name("left"), source, rebound);
        } elif `node.type == "named_expression" {
            _python_collect_assignment_targets(`node.child_by_field_name("name"), source, rebound);
        } elif `node.type
            in ("as_pattern_target", "global_statement", "nonlocal_statement", "delete_statement")
        {
            stack_ids: any = [`node];
            while stack_ids {
                cur: any = stack_ids.pop();
                if cur.type == "identifier" {
                    rebound.add(_read_text(cur, source));
                }
                stack_ids.extend(cur.children);
            }
        }
        stack.extend(`node.children);
    }
    return names - rebound - {"self", "cls"};
}

impl _python_is_test_module(str_path: str) -> bool {
    name: any = str_path.replace("\\", "/").rsplit("/", 1)[-1];
    return operator.eq(name, "conftest.py")
        or name.startswith("test_") and name.endswith(".py")
        or name.endswith("_test.py");
}

impl _python_collect_assignment_targets(`node, source: bytes, out: set[str]) {
    if `node is None {
        return;
    }
    if `node.type == "identifier" {
        out.add(_read_text(`node, source));
        return;
    }
    if `node.type in ("pattern_list", "tuple_pattern", "list_pattern") {
        for c in typing.cast(object, `node).children {
            _python_collect_assignment_targets(c, source, out);
        }
    }
}

impl _self_call_target(
    caller_nid: str,
    callee: str,
    receiver: str,
    label_to_nid: dict[str, str],
    scope_parents: dict[str, str],
    method_owner: dict[str, str],
    methods_by_owner: dict[tuple[str, str], str],
    class_bases: dict[str, list[str]],
    walk_bases: bool = True,
    require_method_owner: bool = False,
) -> str | None {
    seen: set[str];
    scope: str | None = caller_nid;
    while scope and scope not in method_owner {
        scope = scope_parents.get(scope);
    }
    fallback: any = label_to_nid.get(callee);
    if not scope {
        return None if require_method_owner else fallback;
    }
    level: any = [method_owner[scope]];
    seen = set[any]();
    skip_own: any = operator.eq(receiver, "super");
    while level {
        seen.update(level);
        if not skip_own {
            hits: any = {
                methods_by_owner[c, callee]
                for c in level
                if (c, callee) in methods_by_owner
            };
            if hits {
                return hits.pop() if len(hits) == 1 else None;
            }
        }
        if not walk_bases {
            return None if skip_own else fallback;
        }
        skip_own = False;
        level = `list(
            dict.fromkeys(
                base for c in level for base in class_bases.get(c, ()) if base not in seen
            ),
        );
    }
    return None if fallback in method_owner else fallback;
}

impl _lexical_class_bases(
    edges: list[dict],
    relations: tuple[str, ...],
    label_by_nid: dict[str, str],
    nid_to_sf: dict[str, str],
    method_owner: dict[str, str],
    methods_by_owner: dict[tuple[str, str], str],
    class_parent: dict[str, str],
    interfaces: set[str],
) -> dict[str, list[str]] {
    e: any;
    supers: any = [
        e
        for e in edges
        if e["relation"] in relations and label_by_nid.get(e["target"]) not in interfaces
    ];
    by_name: dict[str, list[str]] = {};
    nid: any;
    for nid in dict.fromkeys(
        [owner for (owner, _) in methods_by_owner] + [e["source"] for e in supers]
    ) {
        if class_parent.get(nid) not in method_owner {
            by_name.setdefault(label_by_nid.get(nid, ""), []).append(nid);
        }
    }
    bases: dict[str, list[str]] = {};
    for e in supers {
        target: any = e["target"];
        if not nid_to_sf.get(target) {
            named: any = by_name.get(label_by_nid.get(target, ""), []);
            if len(named) == 1 {
                target = named[0];
            }
        }
        bases.setdefault(e["source"], []).append(target);
    }
    for (nid, outer) in class_parent.items() {
        if outer in method_owner {
            named = by_name.get(label_by_nid.get(nid, "").split("<", 1)[0].strip(), []);
            if len(named) == 1 {
                bases.setdefault(nid, []).append(named[0]);
            }
        }
    }
    return bases;
}

impl _lexical_call_target(
    caller_nid: str,
    callee: str,
    label_to_nid: dict[str, str],
    method_owner: dict[str, str],
    methods_by_owner: dict[tuple[str, str], str],
    class_bases: dict[str, list[str]],
    class_parent: dict[str, str],
) -> str | None {
    seen: set[str];
    cls: str | None = method_owner.get(caller_nid, caller_nid);
    visited: set[str] = set[any]();
    while cls and cls not in visited {
        visited.add(cls);
        level: any = [cls];
        seen = set[any]();
        while level {
            seen.update(level);
            hits: any = {
                methods_by_owner[c, callee]
                for c in level
                if (c, callee) in methods_by_owner
            };
            if hits {
                return hits.pop() if len(hits) == 1 else None;
            }
            level = `list(
                dict.fromkeys(
                    base for c in level for base in class_bases.get(c, ()) if base not in seen
                ),
            );
        }
        outer: any = class_parent.get(cls);
        cls = method_owner.get(outer, outer) if outer else None;
    }
    return label_to_nid.get(callee);
}

impl _python_local_bound_names(func_def_node, source: bytes) -> set[str] {
    bound: set[str];
    bound = set[any]();
    bound |= _python_param_names(func_def_node.child_by_field_name("parameters"), source);

    def walk(n) {
        for child in typing.cast(object, n).children {
            t: any = child.type;
            if t in ("function_definition", "class_definition", "lambda") {
                continue;
            }
            if t == "assignment" {
                _python_collect_assignment_targets(
                    child.child_by_field_name("left"), source, bound
                );
            } elif t in ("for_statement", "for_in_clause") {
                _python_collect_assignment_targets(
                    child.child_by_field_name("left"), source, bound
                );
            } elif t == "with_statement" {
                for item in typing.cast(object, child).children {
                    if item.type == "with_clause" {
                        for wi in typing.cast(object, item).children {
                            if wi.type == "with_item" {
                                alias: any = wi.child_by_field_name("alias");
                                _python_collect_assignment_targets(alias, source, bound);
                            }
                        }
                    }
                }
            } elif t == "named_expression" {
                _python_collect_assignment_targets(
                    child.child_by_field_name("name"), source, bound
                );
            }
            walk(child);
        }
    }

    body: any = func_def_node.child_by_field_name("body");
    if body is not None {
        walk(body);
    }
    return bound;
}

impl _python_module_bound_names(`root, source: bytes) -> set[str] {
    bound: set[str];
    bound = set[any]();

    def walk(n) {
        for child in typing.cast(object, n).children {
            t: any = child.type;
            if t in ("function_definition", "class_definition", "lambda") {
                continue;
            }
            if t == "assignment" {
                _python_collect_assignment_targets(
                    child.child_by_field_name("left"), source, bound
                );
            } elif t in ("for_statement", "for_in_clause") {
                _python_collect_assignment_targets(
                    child.child_by_field_name("left"), source, bound
                );
            } elif t == "named_expression" {
                _python_collect_assignment_targets(
                    child.child_by_field_name("name"), source, bound
                );
            }
            walk(child);
        }
    }

    walk(`root);
    return bound;
}

impl _python_receiver_shadow_checker(`root, source: bytes, *, module_bindings=None) -> any {
    scope_types: any;
    scopes: dict[int, tuple[set[str], dict[str, int], bool]];
    dynamic_binding: any;
    scope_types = {"module", "function_definition", "class_definition", "lambda"};
    scopes = {};
    dynamic_binding = False;
    dynamic_names: any = {"exec", "eval", "globals", "locals", "vars", "setattr", "delattr"};
    pending: any = [`root];
    while pending {
        candidate: any = pending.pop();
        if candidate.type in {"global_statement", "nonlocal_statement"}
            or candidate.type == "identifier" and _read_text(candidate, source) in dynamic_names
        {
            dynamic_binding = True;
            break;
        }
        pending.extend(candidate.named_children);
    }

    def target_names(`node, names: set[str]) -> bool {
        if `node is None {
            return False;
        }
        if `node.type == "identifier" {
            names.add(_read_text(`node, source));
            return True;
        }
        if `node.type in {
            "tuple_pattern",
            "list_pattern",
            "pattern_list",
            "parenthesized_expression",
            "as_pattern_target",
        }
        {
            return all(target_names(c, names) for c in typing.cast(object, `node).named_children);
        }
        if `node.type in {"attribute", "subscript"} {
            return target_names(
                `node.child_by_field_name("object") or `node.named_children[0], names
            );
        }
        return False;
    }

    def import_names(`node) -> list[str] | None {
        names: list[str] = [];
        past_import: any = False;
        for item in typing.cast(object, `node).children {
            if item.type == "import" {
                past_import = True;
                continue;
            }
            if not past_import {
                continue;
            }
            if item.type == "aliased_import" {
                alias: any = item.child_by_field_name("alias");
                if alias is None {
                    return None;
                }
                names.append(_read_text(alias, source));
            } elif item.type == "dotted_name" {
                names.append(_read_text(item, source).split(".")[0]);
            } elif item.type == "wildcard_import" {
                return None;
            }
        }
        return names;
    }

    def facts(scope) -> any {
        bound: set[str];
        plain_imports: dict[str, int];
        unsafe: any;
        key: any = scope.id;
        if key in scopes {
            return scopes[key];
        }
        bound = set[any]();
        plain_imports = {};
        unsafe = `bool(
            scope.has_error
                or scope.child_by_field_name("type_parameters")
                or operator.eq(scope.type, "module") and dynamic_binding,
        );
        if scope.type in {"function_definition", "lambda"} {
            bound.update(_python_param_names(scope.child_by_field_name("parameters"), source));
        }

        def bind_names(`node, names) {
            bound.update(
                name
                for name in names
                if not (
                    scope.type == "module"
                    and module_bindings is not None
                    and `node.id in module_bindings.get(name, ())
                ),
            );
        }

        def walk(`node) {
            for child in typing.cast(object, `node).named_children {
                kind: any = child.type;
                if kind in {"function_definition", "class_definition"} {
                    name: any = child.child_by_field_name("name");
                    if name is None {
                        unsafe = True;
                    } else {
                        bind_names(child, [_read_text(name, source)]);
                    }
                    continue;
                }
                if kind == "lambda" {
                    continue;
                }
                if kind in {"global_statement", "nonlocal_statement", "match_statement", "ERROR"} {
                    unsafe = True;
                    continue;
                }
                if kind in {"import_statement", "import_from_statement"} {
                    names: any = import_names(child);
                    if names is None {
                        unsafe = True;
                    } elif kind == "import_statement"
                        and scope.type == "module"
                        and `node == scope
                    {
                        for name in names {
                            plain_imports[name] = plain_imports.get(name, 0) + 1;
                        }
                    } else {
                        bind_names(child, names);
                    }
                    continue;
                }
                if kind in {"assignment", "augmented_assignment", "for_statement", "for_in_clause"}
                {
                    assigned_names: set[str] = set[any]();
                    if not target_names(child.child_by_field_name("left"), assigned_names) {
                        unsafe = True;
                    }
                    bind_names(child, assigned_names);
                } elif kind == "type_alias_statement" {
                    left: any = child.child_by_field_name("left");
                    name = _read_text(left, source).split("[", 1)[0].strip()
                        if left is not None
                        else "";
                    if name.isidentifier() {
                        bound.add(name);
                    } else {
                        unsafe = True;
                    }
                } elif kind == "named_expression" {
                    if not target_names(child.child_by_field_name("name"), bound) {
                        unsafe = True;
                    }
                } elif kind == "with_item" {
                    alias: any = child.child_by_field_name("alias");
                    value: any = child.child_by_field_name("value");
                    if alias is None and value is not None and value.type == "as_pattern" {
                        alias = value.child_by_field_name("alias");
                    }
                    if alias is not None and not target_names(alias, bound) {
                        unsafe = True;
                    }
                } elif kind == "as_pattern" and `node.type == "except_clause" {
                    if not target_names(child.child_by_field_name("alias"), bound) {
                        unsafe = True;
                    }
                } elif kind == "delete_statement" {
                    for item in typing.cast(object, child).named_children {
                        if not target_names(item, bound) {
                            unsafe = True;
                        }
                    }
                }
                walk(child);
            }
        }

        body: any = scope if scope.type == "module" else scope.child_by_field_name("body");
        if body is None {
            unsafe = True;
        } else {
            walk(body);
        }
        scopes[key] = (bound, plain_imports, unsafe);
        return scopes[key];
    }

    def is_shadowed(call, receiver: str) -> bool {
        `node: any = call;
        found_module: any = False;
        while `node is not None {
            if `node.type in scope_types {
                bound: any;
                plain_imports: any;
                unsafe: any;
                (bound, plain_imports, unsafe) = facts(`node) as any;
                if unsafe or receiver in bound {
                    return True;
                }
                if `node.type == "module" {
                    found_module = True;
                    if module_bindings is not None {
                        if receiver not in module_bindings or plain_imports.get(receiver) {
                            return True;
                        }
                    } elif plain_imports.get(receiver) != 1 {
                        return True;
                    }
                }
            }
            `node = `node.parent;
        }
        return not found_module;
    }

    return is_shadowed;
}

impl _python_module_instance_types(`root, source: bytes) -> any {
    declarations: dict[str, list[tuple[str, Node]]] = {};
    assignments: any = [];
    for statement in typing.cast(object, `root).named_children {
        if statement.type == "class_definition" {
            name: any = _read_text(statement.child_by_field_name("name"), source);
            declarations.setdefault(name, []).append((name, statement));
        } elif statement.type == "import_from_statement" {
            for item in statement.children_by_field_name("name") {
                if item.type == "aliased_import" {
                    name = _read_text(item.child_by_field_name("name"), source);
                    local: any = _read_text(item.child_by_field_name("alias"), source);
                } else {
                    value___: any = _read_text(item, source);
                    name = value___;
                    local = value___;
                }
                if name.isidentifier() and local.isidentifier() {
                    declarations.setdefault(local, []).append((name, statement));
                }
            }
        } elif statement.type == "expression_statement" {
            assignments.extend(c for c in typing.cast(object, statement).named_children if c.type == "assignment");
        }
    }

    instances: any = {};
    for assignment in assignments {
        left: any = assignment.child_by_field_name("left");
        right: any = assignment.child_by_field_name("right");
        if left is None or left.type != "identifier" or right is None or right.type != "call" {
            continue;
        }
        function: any = right.child_by_field_name("function");
        if function is None or function.type != "identifier" {
            continue;
        }
        receiver: any;
        constructor: any;
        (receiver, constructor) = (_read_text(left, source), _read_text(function, source));
        origins: any = declarations.get(constructor, []);
        if len(origins) != 1 or origins[0][1].start_byte >= assignment.start_byte {
            continue;
        }
        class_name: any;
        declaration: any;
        (class_name, declaration) = origins[0] as any;
        allowed: any = {constructor: {declaration.id}};
        allowed.setdefault(receiver, set[any]()).add(assignment.id);
        shadowed: any = _python_receiver_shadow_checker(`root, source, module_bindings=allowed);
        if not shadowed(assignment, constructor) and not shadowed(assignment, receiver) {
            instances[receiver] = (class_name, shadowed);
        }
    }
    return instances;
}

impl _python_is_property(func_node, source: bytes) -> bool {
    parent: any = func_node.parent;
    if parent is None or parent.type != "decorated_definition" {
        return False;
    }
    for dec in typing.cast(object, parent).children {
        if dec.type != "decorator" {
            continue;
        }
        expr: any = next(iter(dec.named_children), None);
        text: any = _read_text(expr, source) if expr is not None else "";
        if text in _PYTHON_PROPERTY_DECORATORS or text.endswith(".getter") {
            return True;
        }
    }
    return False;
}

impl _same_node(a, b) -> bool {
    return a is not None
        and b is not None
        and operator.eq((a.start_byte, a.end_byte, a.type), (b.start_byte, b.end_byte, b.type));
}

impl _python_attribute_is_store(`node) -> bool {
    child: any;
    parent: any;
    (child, parent) = (`node, `node.parent);
    while parent is not None and parent.type in ("pattern_list", "tuple_pattern", "list_pattern") {
        (child, parent) = (parent, parent.parent);
    }
    if parent is None {
        return False;
    }
    if parent.type in ("assignment", "for_statement", "for_in_clause") {
        return _same_node(parent.child_by_field_name("left"), child);
    }
    return operator.eq(parent.type, "delete_statement");
}

impl _python_property_reads(
    function_bodies,
    source: bytes,
    str_path: str,
    var_types: dict[str, dict[str, str | None]],
    attr_types: dict[str, dict[str, str | None]],
    method_owner: dict[str, str],
) -> list[dict] {
    out: list[dict] = [];
    for (caller_nid, body) in function_bodies {
        owner: any = method_owner.get(caller_nid, "");
        fields: any = attr_types.get(owner, {});
        stack: any = `list(getattr(body, "children", ()));
        while stack {
            `node: any = stack.pop();
            if `node.type in ("function_definition", "class_definition", "lambda") {
                continue;
            }
            stack.extend(`node.children);
            if `node.type != "attribute" {
                continue;
            }
            parent: any = `node.parent;
            if parent is not None
                and parent.type == "call"
                and _same_node(parent.child_by_field_name("function"), `node)
            {
                continue;
            }
            if _python_attribute_is_store(`node) {
                continue;
            }
            `obj: any;
            attr_n: any;
            (`obj, attr_n) = (
                `node.child_by_field_name("object"),
                `node.child_by_field_name("attribute"),
            );
            if `obj is None or attr_n is None {
                continue;
            }
            attr: any = _read_text(attr_n, source);
            typed: dict = {};
            if `obj.type == "identifier" {
                name: any = _read_text(`obj, source);
                if name == "self" {
                    if owner and attr not in fields {
                        typed = {"receiver": "self"};
                    }
                } else {
                    cls: any = var_types.get(caller_nid, {}).get(name);
                    if cls {
                        typed = {"receiver": name, "receiver_type": cls};
                    }
                }
            } else {
                self_attr: any = _python_self_attr(`obj, source);
                cls = fields.get(self_attr) if self_attr else None;
                if cls {
                    typed = {"receiver": f"self.{self_attr}", "_python_self_attr_type": cls};
                }
            }
            if typed {
                out.append({
                    "caller_nid": caller_nid,
                    "callee": attr,
                    "is_member_call": True,
                    "source_file": str_path,
                    "source_location": f"L{`node.start_point[0] + 1}",
                    "_python_attr_read": True,
                    **typed,
                });
            }
        }
    }
    return out;
}

impl _python_self_attr(`node, source: bytes) -> str | None {
    if `node is None or `node.type != "attribute" {
        return None;
    }
    `obj: any;
    attr: any;
    (`obj, attr) = (`node.child_by_field_name("object"), `node.child_by_field_name("attribute"));
    if `obj is None or attr is None or _read_text(`obj, source) != "self" {
        return None;
    }
    return _read_text(attr, source);
}

impl _python_self_attr_bindings(
    body, source: bytes, local_types: dict[str, str | None] | None = None
) -> Generator[any, any, any] {
    local_types = local_types or {};
    stack: any = `list(body.named_children);
    while stack {
        `node: any = stack.pop();
        if `node.type in ("function_definition", "class_definition", "lambda") {
            continue;
        }
        stack.extend(`node.named_children);
        left: any = `node.child_by_field_name("left") if `node.type == "assignment" else None;
        if left is None {
            continue;
        }
        value: any;
        right: any;
        (value, right) = (`node.child_by_field_name("type"), `node.child_by_field_name("right"));
        bound_type: any = None;
        if value is None and right is not None {
            if right.type == "none" {
                continue;
            }
            if right.type == "identifier" {
                bound_type = local_types.get(_read_text(right, source));
            }
            value = right.child_by_field_name("function") if right.type == "call" else None;
        }
        name: any = _read_text(value, source) if value is not None else bound_type or "";
        typed: any = name.isidentifier() and name[:1].isupper();
        for target in left.named_children if left.type == "pattern_list" else [left] {
            attr: any = _python_self_attr(target, source);
            if attr {
                yield (attr, name if typed and target is left else None);
            }
        }
    }
}

impl _js_collect_pattern_idents(`node, source: bytes, bound: set) {
    t: any = `node.type;
    if t in ("identifier", "shorthand_property_identifier_pattern") {
        bound.add(_read_text(`node, source));
        return;
    }
    if t == "type_annotation" {
        return;
    }
    if t == "assignment_pattern" {
        left: any = `node.child_by_field_name("left");
        if left is not None {
            _js_collect_pattern_idents(left, source, bound);
        }
        return;
    }
    if t == "pair_pattern" {
        val: any = `node.child_by_field_name("value");
        if val is not None {
            _js_collect_pattern_idents(val, source, bound);
        }
        return;
    }
    for c in typing.cast(object, `node).children {
        if c.is_named {
            _js_collect_pattern_idents(c, source, bound);
        }
    }
}

impl _js_local_bound_names(func_node, source: bytes) -> set[str] {
    bound: set[str];
    bound = set[any]();
    params: any = func_node.child_by_field_name("parameters");
    if params is not None {
        _js_collect_pattern_idents(params, source, bound);
    }
    solo: any = func_node.child_by_field_name("parameter");
    if solo is not None {
        _js_collect_pattern_idents(solo, source, bound);
    }

    def walk(n) {
        for c in typing.cast(object, n).children {
            if c.type in _JS_SCOPE_BOUNDARY {
                continue;
            }
            if c.type == "variable_declarator" and n.type == "variable_declaration" {
                name: any = c.child_by_field_name("name");
                if name is not None {
                    _js_collect_pattern_idents(name, source, bound);
                }
            } elif c.type == "for_in_statement"
                and `any(operator.eq(gc.type, "var") for gc in typing.cast(object, c).children)
            {
                left: any = c.child_by_field_name("left");
                if left is not None {
                    _js_collect_pattern_idents(left, source, bound);
                }
            }
            walk(c);
        }
    }

    body: any = func_node.child_by_field_name("body");
    if body is not None {
        walk(body);
    }
    return bound;
}

impl _js_direct_lexical_names(`node, source: bytes) -> frozenset[str] {
    names: set[str] = set[any]();
    for child in typing.cast(object, `node).children {
        if child.type != "lexical_declaration" {
            continue;
        }
        for declarator in typing.cast(object, child).children {
            if declarator.type == "variable_declarator" {
                val: any = declarator.child_by_field_name("value");
                if val is not None and val.type == "call_expression" {
                    fn: any = val.child_by_field_name("function");
                    if fn is not None
                        and fn.type == "identifier"
                        and _read_text(fn, source) == "require"
                    {
                        continue;
                    }
                }
                name: any = declarator.child_by_field_name("name");
                if name is not None {
                    _js_collect_pattern_idents(name, source, names);
                }
            }
        }
    }
    return frozenset(names);
}

impl _js_enclosing_bound_names(`node, source: bytes) -> set[str] {
    bound: set[str] = set[any]();
    anc: any = `node.parent;
    while anc is not None and anc.type != "program" {
        t: any = anc.type;
        if t in _JS_SCOPE_BOUNDARY and t not in ("class_declaration", "class") {
            bound |= _js_local_bound_names(anc, source);
        } elif t in ("statement_block", "for_statement") {
            bound |= _js_direct_lexical_names(anc, source);
        } elif t == "for_in_statement" {
            left: any = anc.child_by_field_name("left");
            if left is not None {
                _js_collect_pattern_idents(left, source, bound);
            }
        } elif t == "catch_clause" {
            param: any = anc.child_by_field_name("parameter");
            if param is not None {
                _js_collect_pattern_idents(param, source, bound);
            }
        }
        anc = anc.parent;
    }
    return bound;
}

impl _js_receiver_shadowed(
    `node, name: str | None, source: bytes, bindings_by_scope: dict
) -> bool {
    if not name {
        return False;
    }
    scope: any = `node.parent;
    while scope is not None {
        bindings: any = bindings_by_scope.get(scope);
        if bindings is None {
            bound: set[str] = set[any]();
            if scope.type in _JS_SCOPE_BOUNDARY {
                bound.update(_js_local_bound_names(scope, source));
                if scope.type not in ("method_definition", "arrow_function") {
                    own_name: any = scope.child_by_field_name("name");
                    if own_name is not None {
                        bound.add(_read_text(own_name, source));
                    }
                }
            }
            if scope.type in ("program", "statement_block", "for_statement") {
                bound.update(_js_direct_lexical_names(scope, source));
                for child in typing.cast(object, scope).named_children {
                    if child.type
                        in (
                            "function_declaration",
                            "generator_function_declaration",
                            "class_declaration",
                            "abstract_class_declaration",
                        )
                    {
                        declared_name: any = child.child_by_field_name("name");
                        if declared_name is not None {
                            bound.add(_read_text(declared_name, source));
                        }
                    }
                }
            }
            if scope.type in ("catch_clause", "for_in_statement") {
                field: any = "parameter" if scope.type == "catch_clause" else "left";
                pattern: any = scope.child_by_field_name(field);
                if pattern is not None {
                    _js_collect_pattern_idents(pattern, source, bound);
                }
            }
            bindings = frozenset(bound);
            bindings_by_scope[scope] = bindings;
        }
        if name in bindings {
            return True;
        }
        scope = scope.parent;
    }
    return False;
}

impl _js_module_bound_names(`root, source: bytes) -> set[str] {
    bound: set[str];
    bound = set[any]();

    def walk(n) {
        for c in typing.cast(object, n).children {
            if c.type in _JS_SCOPE_BOUNDARY {
                continue;
            }
            if c.type == "variable_declarator" {
                value: any = c.child_by_field_name("value");
                if value is None or value.type not in _JS_FUNCTION_VALUE_TYPES {
                    name: any = c.child_by_field_name("name");
                    if name is not None {
                        _js_collect_pattern_idents(name, source, bound);
                    }
                }
            }
            walk(c);
        }
    }

    walk(`root);
    return bound;
}

impl _js_import_binds_external(raw: str, str_path: str) -> bool {
    resolved: any = _resolve_js_import_target(raw, str_path);
    if resolved is None {
        return False;
    }
    _target_nid: any;
    resolved_path: any;
    (_target_nid, resolved_path) = resolved as any;
    if resolved_path is None {
        return True;
    }
    return "node_modules" in resolved_path.parts;
}

impl _js_external_import_names(`root, source: bytes, str_path: str) -> set[str] {
    bound: set[str];
    bound = set[any]();

    def _clause_names(clause) {
        for c in typing.cast(object, clause).children {
            if c.type == "identifier" {
                bound.add(_read_text(c, source));
            } elif c.type == "namespace_import" {
                for ident in typing.cast(object, c).children {
                    if ident.type == "identifier" {
                        bound.add(_read_text(ident, source));
                    }
                }
            } elif c.type == "named_imports" {
                for spec in typing.cast(object, c).children {
                    if spec.type != "import_specifier" {
                        continue;
                    }
                    idents: any = [g for g in typing.cast(object, spec).children if g.type == "identifier"];
                    if idents {
                        bound.add(_read_text(idents[-1], source));
                    }
                }
            }
        }
    }

    def walk(n) {
        for c in typing.cast(object, n).children {
            if c.type == "import_statement" {
                src_node: any = c.child_by_field_name("source");
                if src_node is not None {
                    raw: any = _read_text(src_node, source).strip("\"'`");
                    if _js_import_binds_external(raw, str_path) {
                        for child in typing.cast(object, c).children {
                            if child.type == "import_clause" {
                                _clause_names(child);
                            }
                        }
                    }
                }
                continue;
            }
            walk(c);
        }
    }

    walk(`root);
    return bound;
}

impl _js_dispatch_value_idents(coll_node) -> Generator[any, any, any] {
    if coll_node.type == "object" {
        for c in typing.cast(object, coll_node).children {
            if c.type == "pair" {
                val: any = c.child_by_field_name("value");
                if val is not None and val.type == "identifier" {
                    yield val;
                }
            } elif c.type == "shorthand_property_identifier" {
                yield c;
            }
        }
    } else {
        for el in typing.cast(object, coll_node).children {
            if el.type == "identifier" {
                yield el;
            }
        }
    }
}

impl _find_body(`node, config: LanguageConfig) -> any {
    b: any = `node.child_by_field_name(config.body_field);
    if b {
        return b;
    }
    for child in typing.cast(object, `node).children {
        if child.type in config.body_fallback_child_types {
            return child;
        }
    }
    return None;
}

impl _js_import_is_type_only(`node) -> bool {
    while `node is not None {
        if `node.type in {
            "type_annotation",
            "type_alias_declaration",
            "type_query",
            "interface_declaration",
            "constraint",
            "default_type",
        }
        {
            return True;
        }
        if `node.type in {"statement_block", "program"} {
            break;
        }
        `node = `node.parent;
    }
    return False;
}

impl _dynamic_import_js(
    `node, source: bytes, caller_nid: str, str_path: str, edges: list, seen_dyn_pairs: set
) -> bool {
    func_node: any = `node.child_by_field_name("function");
    if func_node is None {
        if `node.children and _read_text(`node.children[0], source) == "import" {
            func_node = `node.children[0];
        } else {
            return False;
        }
    }
    if _read_text(func_node, source) != "import" {
        return False;
    }
    if _js_import_is_type_only(`node) {
        return True;
    }
    args: any = `node.child_by_field_name("arguments");
    if args is None {
        return True;
    }
    for arg in typing.cast(object, args).children {
        if arg.type == "template_string" {
            if `any(operator.eq(c.type, "template_substitution") for c in typing.cast(object, arg).children) {
                break;
            }
            raw: any = _read_text(arg, source).strip("`");
        } elif arg.type == "string" {
            raw = _read_text(arg, source).strip("'\" ");
        } else {
            continue;
        }
        if not raw {
            break;
        }
        resolved: any = _resolve_js_import_target(raw, str_path);
        if resolved is None {
            break;
        }
        tgt_nid: any;
        resolved_path: any;
        (tgt_nid, resolved_path) = resolved as any;
        pair: any = (caller_nid, tgt_nid);
        if pair not in seen_dyn_pairs {
            seen_dyn_pairs.add(pair);
            `edge: any = {
                "source": caller_nid,
                "target": tgt_nid,
                "relation": "imports_from",
                "context": "import",
                "deferred": True,
                "confidence": "EXTRACTED",
                "source_file": str_path,
                "source_location": f"L{`node.start_point[0] + 1}",
                "weight": 1.0,
            };
            if resolved_path is not None {
                `edge["target_file"] = `str(resolved_path);
            }
            edges.append(`edge);
        }
        break;
    }
    return True;
}

impl _get_cpp_func_name(`node, source: bytes) -> str | None {
    if `node.type == "identifier" {
        return _read_text(`node, source);
    }
    if `node.type in ("field_identifier", "destructor_name", "operator_name") {
        return _read_text(`node, source);
    }
    if `node.type == "qualified_identifier" {
        return _read_text(`node, source);
    }
    decl: any = `node.child_by_field_name("declarator");
    if decl {
        return _get_cpp_func_name(decl, source);
    }
    for child in typing.cast(object, `node).children {
        if child.type == "identifier" {
            return _read_text(child, source);
        }
        if child.type == "function_declarator" {
            return _get_cpp_func_name(child, source);
        }
    }
    return None;
}

impl _cpp_declarator_name(`node, source: bytes) -> str | None {
    t: any = `node.type;
    if t in ("identifier", "field_identifier") {
        return _read_text(`node, source);
    }
    if t in ("pointer_declarator", "reference_declarator", "init_declarator") {
        inner: any = `node.child_by_field_name("declarator");
        if inner is None {
            for c in typing.cast(object, `node).children {
                if c.type
                    in (
                        "identifier",
                        "field_identifier",
                        "pointer_declarator",
                        "reference_declarator",
                    )
                {
                    inner = c;
                    break;
                }
            }
        }
        if inner is not None {
            return _cpp_declarator_name(inner, source);
        }
    }
    return None;
}

impl _cpp_parameter_types(body_node, source: bytes, table: dict[str, str]) {
    fn: any = body_node.parent;
    while fn is not None and fn.type != "function_definition" {
        fn = fn.parent;
    }
    if fn is None {
        return;
    }
    decl: any = fn.child_by_field_name("declarator");
    while decl is not None and decl.type != "function_declarator" {
        decl = decl.child_by_field_name("declarator");
    }
    if decl is None {
        return;
    }
    params: any = decl.child_by_field_name("parameters");
    if params is None {
        return;
    }
    for p in typing.cast(object, params).children {
        if p.type != "parameter_declaration" {
            continue;
        }
        type_node: any = p.child_by_field_name("type");
        if type_node is None or type_node.type not in ("type_identifier", "qualified_identifier") {
            continue;
        }
        type_name: any = _read_text(type_node, source).split("::")[-1].strip();
        d: any = p.child_by_field_name("declarator");
        if d is None {
            continue;
        }
        var: any = _cpp_declarator_name(d, source);
        if var and type_name and type_name[:1].isupper() and var not in table {
            table[var] = type_name;
        }
    }
}

impl _cpp_field_types(`root, source: bytes, table: dict[str, str]) {
    stack: any = [`root];
    while stack {
        n: any = stack.pop();
        if n.type == "field_declaration" {
            type_node: any = n.child_by_field_name("type");
            if type_node is not None
                and type_node.type in ("type_identifier", "qualified_identifier")
            {
                type_name: any = _read_text(type_node, source).split("::")[-1].strip();
                d: any = n.child_by_field_name("declarator");
                var: any = _cpp_declarator_name(d, source) if d is not None else None;
                if var and type_name and type_name[:1].isupper() {
                    table[var] = type_name if table.get(var, type_name) == type_name else "";
                }
            }
        }
        stack.extend(n.children);
    }
}

impl _cpp_is_header_guard(`node, source: bytes) -> bool {
    if `node.type != "preproc_ifdef"
        or `node.parent is None
        or `node.parent.type != "translation_unit"
        or `node.children[0].type != "#ifndef"
    {
        return False;
    }
    siblings: any = [n for n in `node.parent.named_children if n.type != "comment"];
    contents: any = [n for n in typing.cast(object, `node).named_children if n.type != "comment"];
    if siblings != [`node]
        or len(contents) < 2
        or contents[1].type != "preproc_def"
        or `any(n.type in {"preproc_else", "preproc_elif", "preproc_elifdef"} for n in contents)
    {
        return False;
    }
    name: any = `node.child_by_field_name("name");
    define: any = contents[1].child_by_field_name("name");
    if name is None or define is None or _read_text(name, source) != _read_text(define, source) {
        return False;
    }
    return not `any(
        line.replace(" ", "").replace("\t", "").startswith("#undef")
        for line in _read_text(`node, source).splitlines(),
    );
}

impl _cpp_lookup_scope(`node, source: bytes) -> str {
    parents: any = [];
    parent: any = `node.parent;
    while parent is not None {
        if parent.type in {"namespace_definition", "class_specifier", "struct_specifier"} {
            part: any = parent.child_by_field_name("name");
            if part is None and parent.type != "namespace_definition" {
                return "";
            }
            parents.append(_read_text(part, source) if part is not None else "(anonymous)");
        }
        parent = parent.parent;
    }
    return "::".join(reversed(parents));
}

impl _cpp_qualified_name(`node, name: str, source: bytes) -> str {
    parents: any = [];
    parent: any = `node.parent;
    while parent is not None {
        if parent.type in {"namespace_definition", "class_specifier", "struct_specifier"} {
            part: any = parent.child_by_field_name("name");
            if part is None {
                return "";
            }
            parents.append(_read_text(part, source));
        }
        parent = parent.parent;
    }
    return "::".join([*reversed(parents), name]);
}

impl _cpp_member_record(`node, declarator, name: str, source: bytes) -> dict {
    function: any = declarator;
    while function is not None and function.type in {"pointer_declarator", "reference_declarator"} {
        function = function.child_by_field_name("declarator")
            or next(
                (n
                for n in typing.cast(object, function).named_children
                if n.type in {"function_declarator", "pointer_declarator", "reference_declarator"}),
                None,
            );
    }
    parameters: any = function.child_by_field_name("parameters") if function is not None else None;
    zero_args: any = parameters is not None
        and not `any(operator.ne(n.type, "comment") for n in typing.cast(object, parameters).named_children);
    qualified: any = _cpp_qualified_name(`node, name, source);
    record: dict = {
        "qualified": qualified,
        "kind": "definition" if `node.type == "function_definition" else "declaration",
        "zero_args": zero_args,
        "signature": None,
        "source_location": f"L{declarator.start_point[0] + 1}",
    };
    type_node: any = `node.child_by_field_name("type");
    safe: any = zero_args
        and type_node is not None
        and not `node.has_error
        and name.rsplit("::", 1)[-1].isidentifier()
        and `node.child_by_field_name("default_value") is None
        and (
            operator.ne(`node.type, "function_definition")
            or `node.child_by_field_name("body") is not None
        );
    parent: any = `node.parent;
    while parent is not None {
        if parent.type.startswith("preproc_") and not _cpp_is_header_guard(parent, source)
            or parent.type in {"template_declaration", "function_definition", "lambda_expression"}
        {
            safe = False;
        }
        parent = parent.parent;
    }
    if not safe
        or function is None
        or parameters is None
        or function.type != "function_declarator"
    {
        return record;
    }
    suffix: any = [
        n
        for n in typing.cast(object, function).named_children
        if n.start_byte >= parameters.end_byte and n.type != "comment"
    ];
    prefix: any = [
        n
        for n in typing.cast(object, `node).named_children
        if n.end_byte <= declarator.start_byte and n != type_node
    ];
    if `any(n.type not in {"type_qualifier", "ref_qualifier", "noexcept"} for n in suffix)
        or `any(
            operator.ne(n.type, "type_qualifier")
                and not (
                    n.type == "storage_class_specifier"
                    and _read_text(n, source) in {"static", "inline", "constexpr", "consteval"}
                )
            for n in prefix,
        )
    {
        return record;
    }
    record["signature"] = {
        "return_type": _read_text(type_node, source),
        "return_qualifiers": [_read_text(n, source) for n in prefix if n.type == "type_qualifier"],
        "return_declarator": source[declarator.start_byte:function.start_byte].decode(
            "utf-8", errors="replace"
        ).strip(),
        "member_qualifiers": [_read_text(n, source) for n in suffix],
    };
    return record;
}

impl _cpp_plain_template_parameters(`node, source: bytes) -> list[str] {
    if `node is None or `node.type != "template_declaration" {
        return [];
    }
    if len([c for c in typing.cast(object, `node).named_children if c.type != "comment"]) != 2 {
        return [];
    }
    parameters: any = `node.child_by_field_name("parameters");
    names: any = [];
    for parameter in parameters.named_children if parameters is not None else [] {
        if parameter.type != "type_parameter_declaration"
            or len(parameter.named_children) != 1
            or parameter.named_children[0].type != "type_identifier"
        {
            return [];
        }
        names.append(_read_text(parameter.named_children[0], source));
    }
    return names if len(`set(names)) == len(names) else [];
}

impl _cpp_zero_arg_member_signature(`node, source: bytes) -> tuple | None {
    type_node: any = `node.child_by_field_name("type");
    declarator: any = `node.child_by_field_name("declarator");
    if type_node is None
        or type_node.type != "primitive_type"
        or declarator is None
        or declarator.type != "function_declarator"
        or `any(
            c.type not in {"primitive_type", "function_declarator", "compound_statement", "comment"}
            for c in typing.cast(object, `node).named_children,
        )
    {
        return None;
    }
    name: any = declarator.child_by_field_name("declarator");
    parameters: any = declarator.child_by_field_name("parameters");
    if name is None or parameters is None or parameters.named_children {
        return None;
    }
    suffix: any = [c for c in typing.cast(object, declarator).named_children if c != name];
    if `any(
        c.type not in {"parameter_list", "type_qualifier", "ref_qualifier", "noexcept"}
            or operator.eq(c.type, "noexcept") and c.named_children
        for c in suffix,
    ) {
        return None;
    }
    return (
        _read_text(type_node, source),
        `tuple("".join(_read_text(c, source).split()) for c in suffix),
    );
}

impl _cpp_primary_template_function_name(`node, source: bytes, classes: dict) -> str | None {
    parameters: any = _cpp_plain_template_parameters(`node.parent, source);
    signature: any = _cpp_zero_arg_member_signature(`node, source);
    if not parameters or signature is None {
        return None;
    }
    declarator: any = `node.child_by_field_name("declarator").child_by_field_name("declarator");
    if declarator.type != "qualified_identifier" {
        return None;
    }
    owner: any = declarator.child_by_field_name("scope");
    member: any = declarator.child_by_field_name("name");
    if owner is None
        or owner.type != "template_type"
        or member is None
        or member.type != "identifier"
    {
        return None;
    }
    owner_name: any = owner.child_by_field_name("name");
    arguments: any = owner.child_by_field_name("arguments");
    if owner_name is None or owner_name.type != "type_identifier" or arguments is None {
        return None;
    }
    if ["".join(_read_text(c, source).split()) for c in typing.cast(object, arguments).named_children] != parameters {
        return None;
    }
    name: any = _read_text(owner_name, source);
    candidates: any = classes.get(normalize_id(name), []);
    if len(candidates) != 1 {
        return None;
    }
    primary: any = candidates[0];
    template: any = primary.parent;
    scope: any = `node.parent.parent;
    if scope is None
        or scope.type not in {"translation_unit", "declaration_list"}
        or template is None
        or template.parent != scope
        or len(_cpp_plain_template_parameters(template, source)) != len(parameters)
        or _read_text(primary.child_by_field_name("name"), source) != name
    {
        return None;
    }
    body: any = primary.child_by_field_name("body");
    if body is None {
        return None;
    }
    method: any = _read_text(member, source);
    declarations: any = [];
    for child in typing.cast(object, body).named_children {
        declaration: any = child;
        while declaration.type == "template_declaration" {
            declaration = declaration.named_children[-1];
        }
        for item in declaration.children_by_field_name("declarator") {
            if normalize_id(_get_cpp_func_name(item, source) or "") == normalize_id(method) {
                declarations.append((child, declaration));
            }
        }
    }
    if len(declarations) != 1
        or declarations[0][0].type != "field_declaration"
        or _get_cpp_func_name(declarations[0][1], source) != method
        or _cpp_zero_arg_member_signature(declarations[0][1], source) != signature
    {
        return None;
    }
    return f"{name}::{method}";
}

impl _cpp_type_is_dependent(`node, source: bytes) -> bool {
    parameters: any = _cpp_type_parameters_in_scope(`node, source);
    pending: any = [`node];
    while parameters and pending {
        current: any = pending.pop();
        if current.type == "qualified_identifier" {
            scope: any = current.child_by_field_name("scope");
            if scope is not None {
                pending.append(scope);
            }
            name: any = current.child_by_field_name("name");
            if name is not None and name.type == "template_type" {
                arguments: any = name.child_by_field_name("arguments");
                if arguments is not None {
                    pending.append(arguments);
                }
            }
        } elif current.type in {"type_identifier", "namespace_identifier"}
            and _read_text(current, source) in parameters
        {
            return True;
        } else {
            pending.extend(current.named_children);
        }
    }
    return False;
}

impl _cpp_declared_receiver_type(`node, declarator, source: bytes) -> str {
    type_node: any = `node.child_by_field_name("type");
    if type_node is None
        or type_node.type not in {"type_identifier", "qualified_identifier", "template_type"}
    {
        return "";
    }
    name: any = _read_text(type_node, source);
    if _cpp_type_is_dependent(type_node, source) {
        return "";
    }
    while declarator is not None and declarator.type not in {"identifier", "field_identifier"} {
        if declarator.type == "pointer_declarator" {
            name += "*";
        } elif declarator.type not in {"reference_declarator", "init_declarator"} {
            return "";
        }
        inner: any = declarator.child_by_field_name("declarator");
        if inner is None and declarator.type == "reference_declarator" {
            inner = next(
                (c for c in typing.cast(object, declarator).named_children if c.type != "type_qualifier"), None
            );
        }
        declarator = inner;
    }
    return name if declarator is not None else "";
}

impl _cpp_call_name(`node, source: bytes) -> str | None {
    while `node is not None
        and `node.type in {"template_method", "template_function", "dependent_name"}
    {
        `node = `node.child_by_field_name("name") or next(iter(`node.named_children), None);
    }
    return _read_text(`node, source) if `node is not None else None;
}

impl _cpp_receiver_chain(`node, source: bytes) -> list[list[str]] {
    members: any;
    operators: any;
    (members, operators) = ([], []);
    while `node is not None {
        if `node.type == "parenthesized_expression" and len(`node.named_children) == 1 {
            `node = `node.named_children[0];
        } elif `node.type == "field_expression" {
            field: any = `node.child_by_field_name("field");
            operator_node: any = `node.child_by_field_name("operator");
            if field is None
                or operator_node is None
                or field.type != "field_identifier"
                    and (members or field.type not in {"template_method", "dependent_name"})
            {
                return [];
            }
            name: any = _cpp_call_name(field, source);
            if not name {
                return [];
            }
            members.append(name);
            operators.append(_read_text(operator_node, source));
            `node = `node.child_by_field_name("argument");
        } elif `node.type in {"identifier", "this"} {
            members.append(_read_text(`node, source));
            return [`list(pair) for pair in zip(reversed(members[1:]), reversed(operators))];
        } else {
            return [];
        }
    }
    return [];
}

impl _cpp_resolution_facts(
    `root, source: bytes
) -> tuple[list[dict], dict[str, int], dict[str, str]] {
    bindings: any;
    includes: any;
    include_paths: any;
    (bindings, includes, include_paths) = ([], {}, {});
    pending: any = [`root];
    while pending {
        `node: any = pending.pop();
        pending.extend(reversed(`node.named_children));
        if `node.type == "preproc_include" {
            parent: any = `node.parent;
            while parent is not None
                and parent.type not in {
                    "namespace_definition",
                    "class_specifier",
                    "struct_specifier",
                    "union_specifier",
                    "function_definition",
                    "compound_statement",
                }
            {
                parent = parent.parent;
            }
            if parent is not None {
                continue;
            }
            line: any = `str(`node.start_point[0] + 1);
            includes[line] = `node.start_byte;
            path: any = `node.child_by_field_name("path");
            if path is not None and path.type == "string_literal" {
                include_paths[line] = _read_text(path, source)[1:-1];
            }
        }
        if `node.type not in {
            "alias_declaration",
            "type_definition",
            "class_specifier",
            "struct_specifier",
            "union_specifier",
            "using_declaration",
            "namespace_definition",
            "namespace_alias_definition",
        }
        {
            continue;
        }
        scope: any = _cpp_lookup_scope(`node, source);
        parent = `node.parent;
        block: any = None;
        dependent: any = False;
        conditional: any = False;
        while parent is not None {
            if parent.type == "template_declaration" {
                dependent = True;
            }
            if parent.type == "namespace_definition"
                and parent.child_by_field_name("name") is None
            {
                dependent = True;
            }
            if parent.type in {"preproc_if", "preproc_ifdef", "preproc_else", "preproc_elif"} {
                guard: any = _cpp_is_header_guard(parent, source);
                conditional = conditional or not guard;
            }
            if block is None
                and parent.type in {
                    "compound_statement",
                    "for_statement",
                    "for_range_loop",
                    "if_statement",
                    "switch_statement",
                    "catch_clause",
                    "lambda_expression",
                }
            {
                block = parent;
            }
            parent = parent.parent;
        }
        alias: any = `node.type in {
            "alias_declaration",
            "type_definition",
            "namespace_alias_definition",
        };
        directive: any = False;
        names: any = [(`node.child_by_field_name("name"), "")];
        if `node.type == "namespace_definition" and names[0][0] is not None {
            parts: any = _read_text(names[0][0], source).split("::");
            names = [("::".join(parts[:index + 1]), "") for index in range(len(parts))];
        }
        if `node.type == "using_declaration" {
            using: any = re.fullmatch(
                "using\\s+(namespace\\s+)?((?:::)?[A-Za-z_]\\w*(?:::[A-Za-z_]\\w*)*)\\s*;",
                _read_text(`node, source),
            );
            if using is None {
                continue;
            }
            directive = `bool(using[1]);
            names = [("*" if directive else using[2].rsplit("::", 1)[-1], using[2])];
            alias = not directive;
        }
        if alias and `node.type != "namespace_alias_definition" {
            type_node: any = `node.child_by_field_name("type");
            target: any = _read_text(type_node, source)
                if type_node is not None and not dependent
                else "";
            if `node.type == "alias_declaration" {
                names = [(`node.child_by_field_name("name"), target)];
            } else {
                names = [];
                for declarator in `node.children_by_field_name("declarator") {
                    current: any;
                    suffix: any;
                    (current, suffix) = (declarator, "");
                    while current is not None and current.type != "type_identifier" {
                        if current.type == "pointer_declarator" {
                            suffix += "*";
                        } elif current.type != "reference_declarator" {
                            current = None;
                            break;
                        }
                        current = current.child_by_field_name("declarator");
                    }
                    name: any = _cpp_declarator_type_name(declarator, source);
                    if name {
                        original: any = type_node.child_by_field_name("name")
                            if type_node is not None
                            else None;
                        if original is not None and _read_text(original, source) == name {
                            continue;
                        }
                        names.append((
                            name,
                            target + suffix if current is not None and target else "",
                        ));
                    }
                }
            }
        }
        for (name_node, target) in names {
            name = name_node
                if isinstance(name_node, `str)
                else _read_text(name_node, source) if name_node is not None else "";
            if not name or "::" in name and `node.type != "namespace_definition" {
                continue;
            }
            bindings.append({
                "name": name,
                "scope": scope,
                "target": "" if alias and conditional else target,
                "alias": alias,
                "complete": `node.type in {"class_specifier", "struct_specifier", "union_specifier"}
                    and `node.child_by_field_name("body") is not None,
                "directive": directive,
                "namespace": operator.eq(`node.type, "namespace_definition"),
                "start": `node.start_byte,
                "end": block.end_byte if block is not None else len(source),
                "local": block is not None,
                "block": block.start_byte if block is not None else 0,
            });
            projected_scope: any = scope;
            while block is None
                and not directive
                and projected_scope.split("::")[-1] == "(anonymous)"
            {
                projected_scope = projected_scope.rsplit("::", 1)[0]
                    if "::" in projected_scope
                    else "";
                bindings.append({
                    **bindings[-1],
                    "scope": projected_scope,
                    "target": "",
                    "alias": True,
                    "complete": False,
                    "namespace": False,
                    "implicit_anonymous": True,
                });
            }
        }
    }
    return (bindings, includes, include_paths);
}

impl _cpp_class_lookup_facts(`node, source: bytes) -> dict {
    bases: any;
    members: any;
    signatures: any;
    (bases, members, signatures) = ([], set[any](), {});
    clause: any = next((c for c in typing.cast(object, `node).named_children if c.type == "base_class_clause"), None);
    if clause is not None {
        virtual: any = False;
        for child in typing.cast(object, clause).children {
            if child.type == "virtual" {
                virtual = True;
            } elif child.type == "," {
                virtual = False;
            } elif child.is_named and child.type != "access_specifier" {
                bases.append({
                    "type": _read_text(child, source),
                    "position": child.start_byte,
                    "virtual": virtual,
                });
            }
        }
    }
    body: any = `node.child_by_field_name("body");
    pending: any = [(child, False) for child in typing.cast(object, body).named_children] if body is not None else [];
    while pending {
        member: any;
        unsupported: any;
        (member, unsupported) = pending.pop() as any;
        if member.type.startswith("preproc_") or member.type == "template_declaration" {
            pending.extend((child, True) for child in typing.cast(object, member).named_children);
            continue;
        }
        name: any = member.child_by_field_name("name");
        if name is not None
            and member.type in {
                "alias_declaration",
                "class_specifier",
                "struct_specifier",
                "union_specifier",
                "enum_specifier",
            }
        {
            members.add(_read_text(name, source));
        }
        nested_type: any = member.child_by_field_name("type");
        if nested_type is not None
            and nested_type.type in {
                "class_specifier",
                "struct_specifier",
                "union_specifier",
                "enum_specifier",
            }
        {
            name = nested_type.child_by_field_name("name");
            if name is not None {
                members.add(_read_text(name, source));
            }
        }
        union: any = member if member.type == "union_specifier" else nested_type;
        if union is not None
            and union.type == "union_specifier"
            and union.child_by_field_name("name") is None
        {
            union_body: any = union.child_by_field_name("body");
            if union_body is not None {
                pending.extend((child, True) for child in typing.cast(object, union_body).named_children);
            }
        }
        `enum: any = member if member.type == "enum_specifier" else nested_type;
        if `enum is not None
            and `enum.type == "enum_specifier"
            and not `any(c.type in {"class", "struct"} for c in typing.cast(object, `enum).children)
        {
            enum_body: any = `enum.child_by_field_name("body");
            for enumerator in enum_body.named_children if enum_body is not None else [] {
                name = enumerator.child_by_field_name("name");
                if name is not None {
                    members.add(_read_text(name, source));
                }
            }
        }
        if member.type == "using_declaration" {
            `match: any = re.search("([A-Za-z_]\\w*)\\s*;\\s*$", _read_text(member, source));
            if `match {
                members.add(`match[1]);
            }
        }
        for declarator in member.children_by_field_name("declarator") {
            current: any;
            function: any;
            (current, function) = (declarator, None);
            while current is not None
                and current.type not in {"identifier", "field_identifier", "type_identifier"}
            {
                if current.type == "function_declarator" {
                    function = current;
                }
                inner: any = current.child_by_field_name("declarator");
                if inner is None
                    and current.type in {"parenthesized_declarator", "reference_declarator"}
                {
                    inner = next(
                        (child
                        for child in typing.cast(object, current).named_children
                        if child.type != "type_qualifier"),
                        None,
                    );
                }
                current = inner;
            }
            if current is None {
                continue;
            }
            name = _read_text(current, source);
            members.add(name);
            if function is not None
                and not unsupported
                and function.child_by_field_name("declarator") == current
            {
                signatures.setdefault(name, set[any]()).add(_read_text(function, source));
            }
        }
    }
    return {
        "bases": bases,
        "members": sorted(members),
        "methods": {name: len(values) for (name, values) in signatures.items()},
    };
}

impl _cpp_class_fields(`node, source: bytes, positions: dict[str, int]) -> dict[str, str] {
    fields: dict[str, str] = {};
    body: any = `node.child_by_field_name("body");
    if body is not None {
        for field in typing.cast(object, body).named_children {
            if field.type != "field_declaration" {
                continue;
            }
            for declarator in field.children_by_field_name("declarator") {
                name: any = _cpp_declarator_name(declarator, source);
                if name {
                    value: any = _cpp_declared_receiver_type(field, declarator, source);
                    fields[name] = value if fields.get(name, value) == value else "";
                    positions[name] = declarator.start_byte;
                }
            }
        }
    }
    return fields;
}

impl _cpp_local_binding_ranges(
    body, source: bytes
) -> dict[str, list[tuple[int, int, str, str, str, bool]]] {
    ranges: dict[str, list[tuple[int, int, str, str, bool]]] = {};
    scopes: any = {
        "compound_statement",
        "for_statement",
        "for_range_loop",
        "if_statement",
        "switch_statement",
        "catch_clause",
        "function_definition",
        "lambda_expression",
    };
    stack: any = [body];
    function: any = body.parent;
    if function is not None and function.type == "function_definition" {
        declarator: any = function.child_by_field_name("declarator");
        if declarator is not None {
            stack.append(declarator);
        }
    }
    while stack {
        `node: any = stack.pop();
        if `node.type in {"class_specifier", "struct_specifier", "function_definition"} {
            continue;
        }
        if `node.type in {
            "declaration",
            "parameter_declaration",
            "optional_parameter_declaration",
            "lambda_capture_initializer",
        }
        {
            scope: any = `node.parent;
            while scope is not None and scope.type not in scopes {
                scope = scope.parent;
            }
            if scope is not None {
                declarators: any = `node.children_by_field_name(
                    "left" if `node.type == "lambda_capture_initializer" else "declarator"
                );
                for declarator in declarators {
                    name: any = _cpp_declarator_name(declarator, source);
                    if name {
                        type_node: any = `node.child_by_field_name("type");
                        dependent: any = type_node is not None
                            and (
                                operator.eq(type_node.type, "dependent_type")
                                or _cpp_type_is_dependent(type_node, source)
                            );
                        ranges.setdefault(name, []).append((
                            declarator.start_byte,
                            scope.end_byte,
                            _cpp_declared_receiver_type(`node, declarator, source),
                            _cpp_lookup_scope(`node, source),
                            _cpp_qualified_name(`node, "", source).rstrip(":"),
                            dependent,
                        ));
                    }
                }
            }
        }
        stack.extend(`node.named_children);
    }
    return ranges;
}

impl _cpp_local_var_types(body_node, source: bytes, table: dict[str, str]) {
    c: any;
    stack: any = [body_node];
    while stack {
        n: any = stack.pop();
        if n.type in ("function_definition", "lambda_expression") {
            if n is not body_node {
                continue;
            }
        }
        if n.type == "declaration" {
            type_node: any = n.child_by_field_name("type");
            if type_node is not None
                and type_node.type in ("type_identifier", "qualified_identifier")
            {
                type_name: any = _read_text(type_node, source).split("::")[-1].strip();
                declarators: any = [
                    c
                    for c in typing.cast(object, n).children
                    if c.type
                        in (
                            "identifier",
                            "pointer_declarator",
                            "reference_declarator",
                            "init_declarator",
                        )
                ];
                if type_name and type_name[:1].isupper() and len(declarators) == 1 {
                    var: any = _cpp_declarator_name(declarators[0], source);
                    if var and var not in table {
                        table[var] = type_name;
                    }
                }
            }
        }
        for c in typing.cast(object, n).children {
            stack.append(c);
        }
    }
}

impl _swift_local_var_types(
    body_node,
    source: bytes,
    table: dict[str, str],
    factory: dict[str, tuple[str, str]] | None = None,
) {
    stack: any = [body_node];
    while stack {
        n: any = stack.pop();
        if n.type == "function_declaration" and n is not body_node {
            continue;
        }
        if n.type == "property_declaration" {
            prop_type: str | None = None;
            factory_bind: tuple[str, str] | None = None;
            for child in typing.cast(object, n).children {
                if child.type == "call_expression" {
                    prop_type = _swift_constructor_type(child, source);
                    if prop_type is None {
                        factory_bind = _swift_factory_call(child, source);
                    }
                    break;
                }
                if child.type == "navigation_expression" {
                    head: any = child.children[0] if child.children else None;
                    if head is not None and head.type == "simple_identifier" {
                        htext: any = _read_text(head, source);
                        if htext and htext[:1].isupper() {
                            prop_type = htext;
                        }
                    }
                    break;
                }
            }
            name: any = _swift_property_name(n, source);
            if name and prop_type and name not in table {
                table[name] = prop_type;
            } elif name
                and factory_bind is not None
                and factory is not None
                and name not in table
                and name not in factory
            {
                factory[name] = factory_bind;
            }
        }
        for c in typing.cast(object, n).children {
            stack.append(c);
        }
    }
}

impl _csharp_receiver_type_name(type_node, source: bytes) -> str | None {
    info: any = _read_csharp_type_name(type_node, source);
    if not info {
        return None;
    }
    name: any = ".".join((info[2], info[0])) if info[1] and info[2] else info[0];
    return name or None;
}

impl _csharp_loop_element_types(type_node, source: bytes) -> dict[str, str] {
    if type_node is None {
        return {};
    }
    if type_node.type == "array_type" {
        args: any = [type_node.child_by_field_name("type")];
        suffixes: any = ("",);
    } elif type_node.type == "generic_name" {
        info: any = _read_csharp_type_name(type_node, source);
        arg_list: any = next(
            (c for c in typing.cast(object, type_node).children if c.type == "type_argument_list"), None
        );
        args = arg_list.named_children if arg_list is not None else [];
        if info and info[0] in _CSHARP_LOOP_SEQUENCES and len(args) == 1 {
            suffixes = ("",);
        } elif info and info[0] in _CSHARP_LOOP_DICTIONARIES and len(args) == 2 {
            suffixes = (".Keys", ".Values");
        } else {
            return {};
        }
    } else {
        return {};
    }
    type_params: any = _csharp_type_parameters_in_scope(type_node, source);
    out: dict[str, str] = {};
    for (suffix, arg) in zip(suffixes, args) {
        if arg is None or arg.type not in ("identifier", "qualified_name", "generic_name") {
            continue;
        }
        name: any = _csharp_receiver_type_name(arg, source);
        if name
            and name not in type_params
            and name not in _CSHARP_LOOP_SEQUENCES
            and name not in _CSHARP_LOOP_DICTIONARIES
        {
            out[suffix] = name;
        }
    }
    return out;
}

impl _csharp_loop_source(expr, source: bytes) -> tuple[str, str] | None {
    if expr is None {
        return None;
    }
    if expr.type == "identifier" {
        return (_read_text(expr, source), "");
    }
    if expr.type != "member_access_expression" {
        return None;
    }
    inner: any = expr.child_by_field_name("expression");
    name: any = expr.child_by_field_name("name");
    if inner is None or name is None or name.type != "identifier" {
        return None;
    }
    member: any = _read_text(name, source);
    if inner.type in ("this", "this_expression") {
        return (member, "");
    }
    if member in ("Values", "Keys") {
        `root: any = _csharp_loop_source(inner, source);
        if `root is not None and `root[1] == "" {
            return (`root[0], "." + member);
        }
    }
    return None;
}

impl _csharp_element_type_name(type_node, source: bytes) -> str | None {
    if type_node is None {
        return None;
    }
    if type_node.type == "array_type" {
        elem: any = type_node.child_by_field_name("type");
    } elif type_node.type == "generic_name" {
        info: any = _read_csharp_type_name(type_node, source);
        if not info or info[0] not in ("List", "IList", "IReadOnlyList") {
            return None;
        }
        args: any = next((c for c in typing.cast(object, type_node).children if c.type == "type_argument_list"), None);
        named: any = args.named_children if args is not None else [];
        elem = named[0] if len(named) == 1 else None;
    } else {
        return None;
    }
    if elem is None or elem.type not in ("identifier", "qualified_name", "generic_name") {
        return None;
    }
    name: any = _csharp_receiver_type_name(elem, source);
    if name in ("List", "IList", "IReadOnlyList")
        or name in _csharp_type_parameters_in_scope(type_node, source)
    {
        return None;
    }
    return name;
}

impl _csharp_return_info(method_node, source: bytes) -> list {
    tparams: list[str] = [];
    tpl: any = method_node.child_by_field_name("type_parameters");
    for param in tpl.named_children if tpl is not None else [] {
        name_node: any = param.child_by_field_name("name");
        tparams.append(_read_text(name_node, source) if name_node is not None else "");
    }
    rtype: any = method_node.child_by_field_name("returns");
    ret: any = _csharp_receiver_type_name(rtype, source);
    if ret is not None and rtype is not None and rtype.type == "identifier" and ret in tparams {
        ret = "#%d" % tparams.index(ret);
    } elif ret in tparams or ret in _csharp_type_parameters_in_scope(method_node, source) {
        ret = None;
    }
    return [ret, len(tparams)];
}

impl _csharp_deferred_member(access, source: bytes) -> list | None {
    inner: any = access.child_by_field_name("expression");
    name: any = access.child_by_field_name("name");
    if inner is None or name is None or inner.type != "identifier" or name.type != "identifier" {
        return None;
    }
    return ["member", _read_text(inner, source), _read_text(name, source), []];
}

impl _csharp_deferred_call(invocation, source: bytes) -> list | None {
    fn: any = invocation.child_by_field_name("function");
    recv: any = "";
    if fn is not None and fn.type == "member_access_expression" {
        inner: any = fn.child_by_field_name("expression");
        fn = fn.child_by_field_name("name");
        if inner is not None and inner.type in ("this", "this_expression") {
            recv = "this";
        } elif inner is not None and inner.type == "identifier" {
            recv = _read_text(inner, source);
        } else {
            return None;
        }
    }
    if fn is None or fn.type not in ("identifier", "generic_name") {
        return None;
    }
    args: list[str | None] = [];
    if fn.type == "generic_name" {
        tal: any = next((c for c in typing.cast(object, fn).children if c.type == "type_argument_list"), None);
        for arg in tal.named_children if tal is not None else [] {
            args.append(_csharp_receiver_type_name(arg, source));
        }
        name_node: any = next((c for c in typing.cast(object, fn).children if c.type == "identifier"), None);
    } else {
        name_node = fn;
    }
    if name_node is None {
        return None;
    }
    return ["call", recv, _read_text(name_node, source), args];
}

impl _csharp_method_receiver_types(
    method_node, source: bytes, field_types: dict[str, str]
) -> tuple[dict[str, list[tuple[int, int, str | list | None]]], dict[str, str | None]] {
    bindings: dict[str, list[tuple[int, int, str | list | None]]];
    field_poisoned: set[str];
    g: any;
    child_scope: any;
    loop: any;
    bindings = {};
    field_poisoned = set[any]();
    pending_loops: list[tuple] = [];

    def bind(
        name: str | None, type_name: str | list | None, scope_node, elem_type: str | None = None
    ) {
        if not name or scope_node is None {
            return;
        }
        for (key, value) in ((name, type_name), (name + "[]", elem_type)) {
            if field_types.get(key) not in (None, value) {
                field_poisoned.add(key);
            }
            bindings.setdefault(key, []).append((
                scope_node.start_byte,
                scope_node.end_byte,
                value,
            ));
        }
    }

    def bind_parameter(param, scope_node) {
        name_node: any = param.child_by_field_name("name");
        if name_node is not None {
            ptype: any = param.child_by_field_name("type");
            bind(
                _read_text(name_node, source),
                _csharp_receiver_type_name(ptype, source),
                scope_node,
                _csharp_element_type_name(ptype, source),
            );
        }
    }

    body: any = method_node.child_by_field_name("body");
    param_scope: any = body if body is not None else method_node;
    params: any = method_node.child_by_field_name("parameters");
    if params is not None {
        param: any;
        for param in typing.cast(object, params).children {
            if param.type == "parameter" {
                bind_parameter(param, param_scope);
            }
        }
    }

    stack: any = [(child, param_scope) for child in typing.cast(object, body).children] if body is not None else [];
    while stack {
        `node: any;
        scope: any;
        (`node, scope) = stack.pop() as any;
        if `node.type
            in (
                "class_declaration",
                "struct_declaration",
                "interface_declaration",
                "record_declaration",
                "enum_declaration",
            )
        {
            continue;
        }
        if `node.type == "lambda_expression" {
            lam_params: any = `node.child_by_field_name("parameters");
            if lam_params is not None {
                if lam_params.type == "implicit_parameter" {
                    bind(_read_text(lam_params, source), None, `node);
                } else {
                    for param in typing.cast(object, lam_params).children {
                        if param.type == "parameter" {
                            bind_parameter(param, `node);
                        } elif param.type == "implicit_parameter" {
                            bind(_read_text(param, source), None, `node);
                        }
                    }
                }
            }
        } elif `node.type == "local_function_statement" {
            lf_params: any = `node.child_by_field_name("parameters");
            if lf_params is not None {
                for param in typing.cast(object, lf_params).children {
                    if param.type == "parameter" {
                        bind_parameter(param, `node);
                    }
                }
            }
        } elif `node.type == "local_declaration_statement" {
            vd: any = next((c for c in typing.cast(object, `node).children if c.type == "variable_declaration"), None);
            if vd is not None {
                declared: any = _csharp_receiver_type_name(vd.child_by_field_name("type"), source);
                declared_elem: any = _csharp_element_type_name(
                    vd.child_by_field_name("type"), source
                );
                for declarator in typing.cast(object, vd).children {
                    if declarator.type != "variable_declarator" {
                        continue;
                    }
                    name_node: any = declarator.child_by_field_name("name")
                        or next((g for g in typing.cast(object, declarator).children if g.type == "identifier"), None);
                    if name_node is None {
                        continue;
                    }
                    type_name: any = declared;
                    if type_name is None {
                        for g in typing.cast(object, declarator).children {
                            if g.type == "object_creation_expression" {
                                type_name = _csharp_receiver_type_name(
                                    g.child_by_field_name("type"), source
                                );
                                break;
                            }
                            if g.type == "invocation_expression" {
                                type_name = _csharp_deferred_call(g, source);
                                break;
                            }
                            if g.type == "member_access_expression" {
                                type_name = _csharp_deferred_member(g, source);
                                break;
                            }
                        }
                    }
                    bind(_read_text(name_node, source), type_name, scope, declared_elem);
                }
            }
        } elif `node.type == "foreach_statement" {
            left: any = `node.child_by_field_name("left");
            if left is not None and left.type == "identifier" {
                loop_type: any = _csharp_receiver_type_name(
                    `node.child_by_field_name("type"), source
                );
                loop_source: any = None
                    if loop_type
                    else _csharp_loop_source(`node.child_by_field_name("right"), source);
                if loop_source is not None {
                    pending_loops.append((_read_text(left, source), *loop_source, `node));
                } else {
                    bind(_read_text(left, source), loop_type, `node);
                }
            }
        } elif `node.type in ("declaration_expression", "declaration_pattern") {
            name_node = `node.child_by_field_name("name");
            if name_node is not None and name_node.type == "identifier" {
                bind(
                    _read_text(name_node, source),
                    _csharp_receiver_type_name(`node.child_by_field_name("type"), source),
                    scope,
                );
            }
        }
        child_scope = `node
            if `node.type in ("block", "lambda_expression", "local_function_statement")
            else scope;
        stack.extend((child, child_scope) for child in typing.cast(object, `node).children);
    }

    name: any;
    field: any;
    suffix: any;
    for item_ in pending_loops {
        (name, field, suffix, loop) = item_;
        shadowed: any = `any(
            start <= loop.start_byte and loop.start_byte < end
            for (start, end, _) in bindings.get(field, []),
        );
        bind(name, None if shadowed else field_types.get(field + suffix + "{}"), loop);
    }
    base: dict[str, str | None] = {
        name: None if name in field_poisoned else type_name
        for (name, type_name) in field_types.items()
    };
    for name in field_poisoned {
        bindings.pop(name, None);
    }
    return (bindings, base);
}

impl _csharp_scoped_receiver_type(
    table: tuple[dict[str, list[tuple[int, int, str | list | None]]], dict[str, str | None]] | None,
    name: str | None,
    call_byte: int,
) -> str | list | None {
    if not table or not name {
        return None;
    }
    bindings: any;
    base: any;
    (bindings, base) = table as any;
    candidates: any = [b for b in bindings.get(name, ()) if b[0] <= call_byte < b[1]];
    if not candidates {
        return base.get(name);
    }
    innermost: any = min(end - start for (start, end, _) in candidates);
    inner: any = [b for b in candidates if b[1] - b[0] == innermost];
    if len(inner) == 1 {
        return inner[0][2];
    }
    return None;
}

impl _csharp_receiver_is_declared(
    table: tuple[dict[str, list[tuple[int, int, str | list | None]]], dict[str, str | None]] | None,
    name: str,
    call_byte: int,
) -> bool {
    if not table {
        return False;
    }
    bindings: any;
    base: any;
    (bindings, base) = table as any;
    if name in base {
        return True;
    }
    return `any(
        operator.le(start, call_byte) and operator.lt(call_byte, end)
        for (start, end, _) in bindings.get(name, ()),
    );
}

impl _ts_receiver_type_table(
    `root,
    source: bytes,
    table: dict[str, str],
    field_table: "dict[str, dict[str, str]] | None" = None,
) {
    p: any;
    c: any;
    def _bare_type_ident(type_annotation) -> any {
        idents: any = [c for c in typing.cast(object, type_annotation).children if c.type == "type_identifier"];
        others: any = [
            c
            for c in typing.cast(object, type_annotation).children
            if c.is_named and c.type not in ("type_identifier",)
        ];
        if len(idents) == 1 and not others {
            return _read_text(idents[0], source);
        }
        return None;
    }

    def _optional_type_ident(type_annotation) -> any {
        unions: any = [c for c in typing.cast(object, type_annotation).children if c.is_named];
        if len(unions) != 1 or unions[0].type != "union_type" {
            return None;
        }
        members: any = [c for c in unions[0].children if c.is_named];
        idents: any = [c for c in members if c.type == "type_identifier"];
        empties: any = [c for c in members if _read_text(c, source) in ("undefined", "null")];
        if len(idents) == 1 and len(idents) + len(empties) == len(members) {
            return _read_text(idents[0], source);
        }
        return None;
    }

    def _class_name(class_body) -> str | None {
        owner: any = class_body.parent
            if class_body is not None and class_body.type == "class_body"
            else None;
        name: any = owner.child_by_field_name("name") if owner is not None else None;
        return _read_text(name, source) if name is not None else None;
    }

    def _new_type(new_expr) -> str | None {
        ctor: any = new_expr.child_by_field_name("constructor");
        return _read_text(ctor, source)
            if ctor is not None and ctor.type in ("identifier", "type_identifier")
            else None;
    }

    constructor_assigned: dict[str, dict[str, set[str]]] = {};
    method_assigned: dict[str, dict[str, set[str]]] = {};
    stack: any = [`root];
    while stack {
        n: any = stack.pop();
        t: any = n.type;
        if t == "variable_declarator" {
            name_n: any = n.child_by_field_name("name");
            value: any = n.child_by_field_name("value");
            if name_n is not None
                and name_n.type == "identifier"
                and value is not None
                and value.type == "new_expression"
            {
                ctor: any = value.child_by_field_name("constructor");
                if ctor is not None and ctor.type in ("identifier", "type_identifier") {
                    name: any = _read_text(name_n, source);
                    tname: any = _read_text(ctor, source);
                    if name and tname and name not in table {
                        table[name] = tname;
                    }
                }
            }
        } elif t == "required_parameter" or t == "optional_parameter" {
            pat: any = n.child_by_field_name("pattern");
            ann: any = n.child_by_field_name("type");
            if pat is not None and pat.type == "identifier" and ann is not None {
                tname = _bare_type_ident(ann);
                name = _read_text(pat, source);
                if name and tname and name not in table {
                    table[name] = tname;
                }
            }
        } elif t in ("public_field_definition", "field_definition") and field_table is not None {
            name_n = n.child_by_field_name("name") or n.child_by_field_name("property");
            owner_name: any = _class_name(n.parent);
            if owner_name is not None and `any(operator.eq(c.type, "static") for c in typing.cast(object, n).children) {
                owner_name += _TS_STATIC_SUFFIX;
            }
            if name_n is not None
                and name_n.type in ("property_identifier", "private_property_identifier")
            {
                ann = n.child_by_field_name("type");
                value = n.child_by_field_name("value");
                tname = None;
                if ann is not None {
                    tname = _bare_type_ident(ann) or _optional_type_ident(ann);
                } elif value is not None and value.type == "new_expression" {
                    tname = _new_type(value);
                }
                name = _read_text(name_n, source);
                if name and tname {
                    if owner_name is not None {
                        field_table.setdefault(owner_name, {}).setdefault(name, tname);
                    } elif name not in table {
                        table[name] = tname;
                    }
                }
            }
        } elif t == "method_definition" and field_table is not None {
            mname: any = n.child_by_field_name("name");
            owner_name = _class_name(n.parent);
            if mname is not None and owner_name is not None {
                method_name: any = _read_text(mname, source);
                is_constructor: any = operator.eq(method_name, "constructor");
                is_static: any = `any(operator.eq(c.type, "static") for c in typing.cast(object, n).children);
                field_owner: any = owner_name + _TS_STATIC_SUFFIX if is_static else owner_name;

                accessor: any = next(
                    (c.type for c in typing.cast(object, n).children if c.type in ("get", "set")), None
                );
                if accessor is not None {
                    tname = None;
                    if accessor == "get" {
                        ret: any = n.child_by_field_name("return_type");
                        tname = _bare_type_ident(ret) or _optional_type_ident(ret)
                            if ret is not None
                            else None;
                    } else {
                        params: any = n.child_by_field_name("parameters");
                        first: any = next(
                            (p
                            for p in typing.cast(object, params).named_children
                            if p.type in ("required_parameter", "optional_parameter")),
                            None,
                        )
                            if params is not None
                            else None;
                        ann = first.child_by_field_name("type") if first is not None else None;
                        tname = _bare_type_ident(ann) or _optional_type_ident(ann)
                            if ann is not None
                            else None;
                    }
                    if tname {
                        field_table.setdefault(field_owner, {}).setdefault(
                            _read_text(mname, source), tname
                        );
                    }
                }
                params = n.child_by_field_name("parameters");
                typed: dict[str, str] = {};
                for p in params.named_children if params is not None else [] {
                    if p.type not in ("required_parameter", "optional_parameter") {
                        continue;
                    }
                    (pat, ann) = (p.child_by_field_name("pattern"), p.child_by_field_name("type"));
                    if pat is None or pat.type != "identifier" or ann is None {
                        continue;
                    }
                    tname = _bare_type_ident(ann) or _optional_type_ident(ann);
                    if not tname {
                        continue;
                    }
                    pname: any = _read_text(pat, source);
                    typed[pname] = tname;
                    if is_constructor
                        and `any(
                            c.type in ("accessibility_modifier", "readonly") for c in typing.cast(object, p).children
                        )
                    {
                        field_table.setdefault(owner_name, {}).setdefault(pname, tname);
                    }
                }
                body: any = n.child_by_field_name("body");
                pending: any = [body] if body is not None else [];
                while pending {
                    item: any = pending.pop();
                    if item is not body
                        and item.type
                            in (
                                "method_definition",
                                "function_declaration",
                                "function_expression",
                                "generator_function_declaration",
                                "generator_function",
                            )
                    {
                        continue;
                    }
                    if item.type == "assignment_expression" {
                        left: any = item.child_by_field_name("left");
                        right: any = item.child_by_field_name("right");
                        if left is not None
                            and right is not None
                            and left.type == "member_expression"
                        {
                            `obj: any = left.child_by_field_name("object");
                            prop: any = left.child_by_field_name("property");
                            if `obj is not None and `obj.type == "this" and prop is not None {
                                field_name: any = _read_text(prop, source);
                                tname = typed.get(_read_text(right, source))
                                    if right.type == "identifier"
                                    else _new_type(right)
                                        if right.type == "new_expression"
                                        else None;
                                if field_name and tname {
                                    assignments: any = constructor_assigned
                                        if is_constructor
                                        else method_assigned;
                                    assignments.setdefault(field_owner, {}).setdefault(
                                        field_name, set[any]()
                                    ).add(tname);
                                }
                            }
                        }
                    }
                    pending.extend(item.children);
                }
            }
        }
        for c in typing.cast(object, n).children {
            stack.append(c);
        }
    }
    if field_table is not None {
        constructor_conflicts: set[tuple[str, str]] = set[any]();
        cls: any;
        fields: any;
        for (cls, fields) in constructor_assigned.items() {
            types: any;
            for (name, types) in fields.items() {
                if len(types) == 1 {
                    field_table.setdefault(cls, {}).setdefault(name, next(iter(types)));
                } elif len(types) > 1 {
                    constructor_conflicts.add((cls, name));
                }
            }
        }
        for (cls, fields) in method_assigned.items() {
            for (name, types) in fields.items() {
                if (cls, name) in constructor_conflicts {
                    continue;
                }
                if len(types) == 1 {
                    field_table.setdefault(cls, {}).setdefault(name, next(iter(types)));
                }
            }
        }
    }
}

impl _ts_attach_class_fields(result: dict, field_table: dict[str, dict[str, str]], str_path: str) {
    def _fold(label: str) -> str {
        return "".join(c for c in `str(label) if c.isascii() and c.isalnum()).lower();
    }

    by_key: dict[tuple[str, bool], dict[str, str]] = {};
    fields: any;
    for (cls, fields) in field_table.items() {
        `static: any = cls.endswith(_TS_STATIC_SUFFIX);
        merged: any = by_key.setdefault((_fold(cls.removesuffix(_TS_STATIC_SUFFIX)), `static), {});
        for (name, tname) in fields.items() {
            merged[name] = tname if merged.get(name, tname) == tname else "";
        }
    }
    if not by_key {
        return;
    }
    for `node in result.get("nodes", []) {
        if `node.get("source_file") != str_path {
            continue;
        }
        for (`static, attr) in ((False, "_ts_fields"), (True, "_ts_static_fields")) {
            fields = by_key.get((_fold(`node.get("label", "")), `static));
            kept: any = {k: v for (k, v) in sorted((fields or {}).items()) if v};
            if kept {
                `node[attr] = kept;
            }
        }
    }
}

impl _ts_in_static_method(`node) -> bool {
    while `node is not None {
        if `node.type == "method_definition" {
            return `any(operator.eq(c.type, "static") for c in typing.cast(object, `node).children);
        }
        if `node.type in _TS_FUNCTION_NODES and `node.type != "arrow_function" {
            return False;
        }
        `node = `node.parent;
    }
    return False;
}

impl _ts_field_destructured_from_this(ident, name: str, source: bytes) -> str | None {
    `node: any = ident.parent;
    while `node is not None {
        if `node.type in _TS_FUNCTION_NODES {
            body: any = `node.child_by_field_name("body");
            stack: any = [body] if body is not None else [];
            while stack {
                n: any = stack.pop();
                if n.type == "variable_declarator" {
                    pattern: any;
                    value: any;
                    (pattern, value) = (
                        n.child_by_field_name("name"),
                        n.child_by_field_name("value"),
                    );
                    if pattern is not None
                        and pattern.type == "object_pattern"
                        and value is not None
                        and value.type == "this"
                    {
                        for p in typing.cast(object, pattern).named_children {
                            if p.type == "shorthand_property_identifier_pattern"
                                and _read_text(p, source) == name
                            {
                                return name;
                            }
                            if p.type == "pair_pattern" {
                                key: any;
                                val: any;
                                (key, val) = (
                                    p.child_by_field_name("key"),
                                    p.child_by_field_name("value"),
                                );
                                if key is not None
                                    and val is not None
                                    and val.type == "identifier"
                                    and _read_text(val, source) == name
                                {
                                    return _read_text(key, source);
                                }
                            }
                        }
                    }
                }
                stack.extend(c for c in typing.cast(object, n).children if c.type not in _TS_FUNCTION_NODES);
            }
            if `node.type != "arrow_function" {
                return None;
            }
        }
        `node = `node.parent;
    }
    return None;
}

impl _find_require_call(value_node) -> any {
    if value_node is None {
        return None;
    }
    if value_node.type == "call_expression" {
        fn: any = value_node.child_by_field_name("function");
        if fn is not None and fn.type == "identifier" {
            return value_node;
        }
    }
    if value_node.type == "member_expression" {
        `obj: any = value_node.child_by_field_name("object");
        return _find_require_call(`obj);
    }
    return None;
}

impl _js_value_is_require(value_node, source: bytes) -> bool {
    call: any = _find_require_call(value_node);
    if call is None {
        return False;
    }
    fn: any = call.child_by_field_name("function");
    return fn is not None and operator.eq(_read_text(fn, source), "require");
}

impl _js_require_specifier(value_node, source: bytes) -> str | None {
    call: any = _find_require_call(value_node);
    if call is None {
        return None;
    }
    args: any = call.child_by_field_name("arguments");
    if args is None {
        return None;
    }
    for arg in typing.cast(object, args).children {
        if arg.type == "string" {
            raw: any = _read_text(arg, source).strip("'\"` ");
            if raw {
                return raw;
            }
        }
    }
    return None;
}

impl _js_require_resolves_locally(value_node, source: bytes, str_path: str) -> bool {
    raw: any = _js_require_specifier(value_node, source);
    if raw is None {
        return False;
    }
    resolved: any = _resolve_js_import_target(raw, str_path);
    return resolved is not None and resolved[1] is not None;
}

impl _require_imports_js(
    `node, source: bytes, importer_nid: str, stem: str, edges: list, str_path: str
) -> bool {
    if `node.type not in ("lexical_declaration", "variable_declaration") {
        return False;
    }
    found: any = False;
    for child in typing.cast(object, `node).children {
        if child.type != "variable_declarator" {
            continue;
        }
        value: any = child.child_by_field_name("value");
        call: any = _find_require_call(value);
        if call is None {
            continue;
        }
        fn: any = call.child_by_field_name("function");
        if fn is None or _read_text(fn, source) != "require" {
            continue;
        }
        args: any = call.child_by_field_name("arguments");
        if args is None {
            continue;
        }
        raw: any = None;
        for arg in typing.cast(object, args).children {
            if arg.type == "string" {
                raw = _read_text(arg, source).strip("'\"` ");
                break;
            }
        }
        if not raw {
            continue;
        }
        resolved: any = _resolve_js_import_target(raw, str_path);
        if resolved is None {
            continue;
        }
        tgt_nid: any;
        resolved_path: any;
        (tgt_nid, resolved_path) = resolved as any;
        if resolved_path is not None and not resolved_path.is_file() {
            tgt_nid = _make_id("ref", raw);
            resolved_path = None;
        }
        line: any = `node.start_point[0] + 1;
        `edge: any = {
            "source": importer_nid,
            "target": tgt_nid,
            "relation": "imports_from",
            "context": "import",
            "confidence": "EXTRACTED",
            "source_file": str_path,
            "source_location": f"L{line}",
            "weight": 1.0,
        };
        if resolved_path is not None {
            `edge["target_file"] = `str(resolved_path);
        }
        edges.append(`edge);
        found = True;
        target_stem: any = _file_stem(resolved_path) if resolved_path is not None else None;
        name_node: any = child.child_by_field_name("name");
        sym_names: list[str] = [];
        if name_node is not None and name_node.type == "object_pattern" {
            prop: any;
            for prop in typing.cast(object, name_node).children {
                if prop.type == "shorthand_property_identifier_pattern" {
                    sym_names.append(_read_text(prop, source));
                } elif prop.type == "pair_pattern" {
                    key: any = prop.child_by_field_name("key");
                    if key is not None {
                        sym_names.append(_read_text(key, source));
                    }
                }
            }
        } elif value is not None and value.type == "member_expression" {
            prop = value.child_by_field_name("property");
            if prop is not None {
                sym_names.append(_read_text(prop, source));
            }
        }
        if target_stem is not None {
            for sym in sym_names {
                edges.append({
                    "source": importer_nid,
                    "target": _make_id(target_stem, sym),
                    "relation": "imports",
                    "context": "import",
                    "confidence": "EXTRACTED",
                    "source_file": str_path,
                    "source_location": f"L{line}",
                    "weight": 1.0,
                    "_require_target_file": `str(resolved_path),
                    "_require_imported_name": sym,
                });
            }
        }
    }
    return found;
}

impl _scan_js_nested_function_declarations(
    container_node,
    parent_nid: str,
    *,
    source: bytes,
    config,
    add_node,
    add_edge,
    callable_def_nids: set | None,
    local_bound_names: dict | None,
    function_bodies: list,
    scope_parents: dict[str, str] | None = None,
    lexical_nids_by_scope: dict[str, dict[str, str]] | None = None,
) {
    if container_node is None {
        return;
    }
    for child in typing.cast(object, container_node).children {
        if child.type in ("function_declaration", "generator_function_declaration") {
            name_node: any = child.child_by_field_name(config.name_field);
            if name_node is None {
                for c in typing.cast(object, child).children {
                    if c.type in config.name_fallback_child_types {
                        name_node = c;
                        break;
                    }
                }
            }
            func_name: any = _read_text(name_node, source) if name_node else None;
            if func_name and normalize_id(func_name) {
                line: any = child.start_point[0] + 1;
                nested_nid: any = _make_id(parent_nid, func_name);
                add_node(nested_nid, f"{func_name}()", line);
                add_edge(parent_nid, nested_nid, "contains", line);
                if scope_parents is not None {
                    scope_parents[nested_nid] = parent_nid;
                }
                if lexical_nids_by_scope is not None {
                    lexical_nids_by_scope.setdefault(parent_nid, {})[func_name] = nested_nid;
                    lexical_nids_by_scope.setdefault(nested_nid, {})[func_name] = nested_nid;
                }
                if callable_def_nids is not None {
                    callable_def_nids.add(nested_nid);
                }
                if local_bound_names is not None {
                    local_bound_names[nested_nid] = _js_local_bound_names(child, source);
                }
                nested_body: any = _find_body(child, config);
                if nested_body {
                    function_bodies.append((nested_nid, nested_body));
                    _scan_js_nested_function_declarations(
                        nested_body,
                        nested_nid,
                        source=source,
                        config=config,
                        add_node=add_node,
                        add_edge=add_edge,
                        callable_def_nids=callable_def_nids,
                        local_bound_names=local_bound_names,
                        function_bodies=function_bodies,
                        scope_parents=scope_parents,
                        lexical_nids_by_scope=lexical_nids_by_scope,
                    );
                }
            }
        } elif child.type in _JS_FUNCTION_VALUE_TYPES {
            _scan_js_nested_function_declarations(
                _find_body(child, config),
                parent_nid,
                source=source,
                config=config,
                add_node=add_node,
                add_edge=add_edge,
                callable_def_nids=callable_def_nids,
                local_bound_names=local_bound_names,
                function_bodies=function_bodies,
                scope_parents=scope_parents,
                lexical_nids_by_scope=lexical_nids_by_scope,
            );
        } else {
            _scan_js_nested_function_declarations(
                child,
                parent_nid,
                source=source,
                config=config,
                add_node=add_node,
                add_edge=add_edge,
                callable_def_nids=callable_def_nids,
                local_bound_names=local_bound_names,
                function_bodies=function_bodies,
                scope_parents=scope_parents,
                lexical_nids_by_scope=lexical_nids_by_scope,
            );
        }
    }
}

impl _scan_python_nested_function_declarations(
    container_node,
    parent_nid: str,
    *,
    source: bytes,
    config,
    add_node,
    add_edge,
    callable_def_nids: set | None,
    local_bound_names: dict | None,
    function_bodies: list,
    scope_parents: dict[str, str] | None = None,
    lexical_nids_by_scope: dict[str, dict[str, str]] | None = None,
) {
    if container_node is None {
        return;
    }
    for child in typing.cast(object, container_node).children {
        target: any = child;
        if target.type == "decorated_definition" {
            inner: any = target.child_by_field_name("definition");
            if inner is not None {
                target = inner;
            }
        }
        if target.type == "function_definition" {
            name_node: any = target.child_by_field_name(config.name_field);
            if name_node is None {
                for c in typing.cast(object, target).children {
                    if c.type in config.name_fallback_child_types {
                        name_node = c;
                        break;
                    }
                }
            }
            func_name: any = _read_text(name_node, source) if name_node else None;
            if func_name and normalize_id(func_name) {
                line: any = target.start_point[0] + 1;
                nested_nid: any = _make_id(parent_nid, func_name);
                add_node(nested_nid, f"{func_name}()", line);
                add_edge(parent_nid, nested_nid, "contains", line);
                if callable_def_nids is not None {
                    callable_def_nids.add(nested_nid);
                }
                if local_bound_names is not None {
                    local_bound_names[nested_nid] = _python_local_bound_names(target, source);
                }
                if scope_parents is not None {
                    scope_parents[nested_nid] = parent_nid;
                }
                if lexical_nids_by_scope is not None {
                    lexical_nids_by_scope.setdefault(parent_nid, {})[func_name] = nested_nid;
                    lexical_nids_by_scope.setdefault(nested_nid, {})[func_name] = nested_nid;
                }
                nested_body: any = _find_body(target, config);
                if nested_body {
                    function_bodies.append((nested_nid, nested_body));
                    _scan_python_nested_function_declarations(
                        nested_body,
                        nested_nid,
                        source=source,
                        config=config,
                        add_node=add_node,
                        add_edge=add_edge,
                        callable_def_nids=callable_def_nids,
                        local_bound_names=local_bound_names,
                        function_bodies=function_bodies,
                        scope_parents=scope_parents,
                        lexical_nids_by_scope=lexical_nids_by_scope,
                    );
                }
            }
        } else {
            _scan_python_nested_function_declarations(
                child,
                parent_nid,
                source=source,
                config=config,
                add_node=add_node,
                add_edge=add_edge,
                callable_def_nids=callable_def_nids,
                local_bound_names=local_bound_names,
                function_bodies=function_bodies,
                scope_parents=scope_parents,
                lexical_nids_by_scope=lexical_nids_by_scope,
            );
        }
    }
}

impl _js_topmost_closures(`node, out: list) {
    for c in typing.cast(object, `node).children {
        if c.type in _JS_FUNCTION_VALUE_TYPES {
            out.append(c);
        } else {
            _js_topmost_closures(c, out);
        }
    }
}

impl _js_member_assignment_target(left, source: bytes) -> any {
    if left is None or left.type != "member_expression" {
        return None;
    }
    prop: any = left.child_by_field_name("property");
    if prop is None {
        return None;
    }
    member_name: any = _read_text(prop, source);
    if not member_name {
        return None;
    }
    `obj: any = left.child_by_field_name("object");
    if `obj is None {
        return None;
    }
    if `obj.type == "this" {
        return ("this", None, member_name);
    }
    if `obj.type == "identifier" {
        if _read_text(`obj, source) == "exports" {
            return ("exports", None, member_name);
        }
        return ("object", _read_text(`obj, source), member_name);
    }
    if `obj.type == "member_expression" {
        inner_obj: any = `obj.child_by_field_name("object");
        inner_prop: any = `obj.child_by_field_name("property");
        if inner_obj is None or inner_prop is None {
            return None;
        }
        inner_prop_name: any = _read_text(inner_prop, source);
        if inner_obj.type == "identifier" {
            inner_obj_name: any = _read_text(inner_obj, source);
            if inner_obj_name == "module" and inner_prop_name == "exports" {
                return ("exports", None, member_name);
            }
            if inner_prop_name == "prototype" {
                return ("prototype", inner_obj_name, member_name);
            }
        }
    }
    return None;
}

impl _js_scan_member_assignments(
    body,
    this_owner_nid: str,
    source: bytes,
    *,
    this_as_method: bool,
    add_node_fn,
    add_edge_fn,
    function_bodies: list,
    closure_locals_by_body: dict | None = None,
) {
    object_bindings: dict[str, object] = {};
    stmt: any;
    for stmt in typing.cast(object, body).children {
        if stmt.type not in ("lexical_declaration", "variable_declaration") {
            continue;
        }
        for declarator in typing.cast(object, stmt).children {
            if declarator.type != "variable_declarator" {
                continue;
            }
            name: any = declarator.child_by_field_name("name");
            value: any = declarator.child_by_field_name("value");
            if name is not None
                and name.type == "identifier"
                and value is not None
                and value.type == "object"
            {
                object_bindings[_read_text(name, source)] = declarator;
            }
        }
    }
    contained_owners: set[str] = set[any]();
    for stmt in typing.cast(object, body).children {
        if stmt.type != "expression_statement" {
            continue;
        }
        assign: any = next((c for c in typing.cast(object, stmt).children if c.type == "assignment_expression"), None);
        if assign is None {
            continue;
        }
        val: any = assign.child_by_field_name("right");
        if val is None or val.type not in _JS_FUNCTION_VALUE_TYPES {
            continue;
        }
        tgt: any = _js_member_assignment_target(assign.child_by_field_name("left"), source);
        if tgt is None {
            continue;
        }
        as_method: any = True;
        if tgt[0] == "this" {
            owner_nid: any = this_owner_nid;
            as_method = this_as_method;
        } elif tgt[0] == "object" and tgt[1] in object_bindings {
            object_name: any = tgt[1];
            owner_nid = _make_id(this_owner_nid, object_name);
            owner_line: any = object_bindings[object_name].start_point[0] + 1;
            add_node_fn(owner_nid, object_name, owner_line);
            if owner_nid not in contained_owners {
                contained_owners.add(owner_nid);
                add_edge_fn(this_owner_nid, owner_nid, "contains", owner_line);
            }
        } else {
            continue;
        }
        m_name: any = tgt[2];
        m_line: any = stmt.start_point[0] + 1;
        m_nid: any = _make_id(owner_nid, m_name);
        if as_method {
            add_node_fn(m_nid, f".{m_name}()", m_line);
            add_edge_fn(owner_nid, m_nid, "method", m_line);
        } else {
            add_node_fn(m_nid, f"{m_name}()", m_line);
            add_edge_fn(owner_nid, m_nid, "contains", m_line);
        }
        m_body: any = val.child_by_field_name("body");
        if m_body {
            if closure_locals_by_body is not None {
                closure_locals_by_body[id(m_body)] = _js_local_bound_names(val, source)
                    | _js_enclosing_bound_names(val, source);
            }
            function_bodies.append((m_nid, m_body));
        }
    }
}

impl _js_find_exported_objects(program_node, source: bytes) -> set[str] {
    if program_node is None or program_node.type != "program" {
        return set[any]();
    }
    exported: any = set[any]();
    for child in typing.cast(object, program_node).children {
        if child.type == "export_statement" {
            for c in typing.cast(object, child).children {
                if c.type == "identifier" {
                    exported.add(_read_text(c, source));
                } elif c.type == "export_clause" {
                    for sc in typing.cast(object, c).children {
                        if sc.type == "export_specifier" {
                            name_node: any = sc.child_by_field_name("name");
                            if name_node {
                                exported.add(_read_text(name_node, source));
                            }
                        }
                    }
                } elif c.type in ("variable_declaration", "lexical_declaration") {
                    decl: any;
                    for decl in typing.cast(object, c).children {
                        if decl.type == "variable_declarator" {
                            name_node = decl.child_by_field_name("name");
                            if name_node and name_node.type == "identifier" {
                                exported.add(_read_text(name_node, source));
                            }
                        }
                    }
                }
            }
        } elif child.type in ("variable_declaration", "lexical_declaration") {
            for decl in typing.cast(object, child).children {
                if decl.type != "variable_declarator" {
                    continue;
                }
                name_node = decl.child_by_field_name("name");
                val_node: any = decl.child_by_field_name("value");
                if name_node and name_node.type == "identifier" and val_node {
                    name_str: any = _read_text(name_node, source);
                    curr: any = val_node;
                    while curr and curr.type == "assignment_expression" {
                        left: any = curr.child_by_field_name("left");
                        if left {
                            left_str: any = _read_text(left, source);
                            if left_str in ("module.exports", "exports")
                                or left_str.startswith(("module.exports.", "exports."))
                            {
                                exported.add(name_str);
                                break;
                            }
                        }
                        curr = curr.child_by_field_name("right");
                    }
                    if curr {
                        val_str: any = _read_text(curr, source);
                        if val_str in ("module.exports", "exports") {
                            exported.add(name_str);
                        }
                    }
                }
            }
        } elif child.type == "expression_statement" {
            assign: any = next(
                (c for c in typing.cast(object, child).children if c.type == "assignment_expression"), None
            );
            if assign {
                left = assign.child_by_field_name("left");
                right: any = assign.child_by_field_name("right");
                if left {
                    left_str = _read_text(left, source);
                    if left_str in ("module.exports", "exports")
                        or left_str.startswith(("module.exports.", "exports."))
                    {
                        curr = right;
                        while curr and curr.type == "assignment_expression" {
                            l: any = curr.child_by_field_name("left");
                            if l and l.type == "identifier" {
                                exported.add(_read_text(l, source));
                            }
                            curr = curr.child_by_field_name("right");
                        }
                        if curr and curr.type == "identifier" {
                            exported.add(_read_text(curr, source));
                        } elif curr and curr.type == "object" {
                            for prop in typing.cast(object, curr).children {
                                if prop.type == "shorthand_property_identifier" {
                                    exported.add(_read_text(prop, source));
                                } elif prop.type == "pair" {
                                    v: any = prop.child_by_field_name("value");
                                    if v and v.type == "identifier" {
                                        exported.add(_read_text(v, source));
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    return exported;
}

impl _js_extra_walk(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    str_path: str,
    nodes: list,
    edges: list,
    seen_ids: set,
    function_bodies: list,
    parent_class_nid: str | None,
    add_node_fn,
    add_edge_fn,
    callable_def_nids: set | None = None,
    local_bound_names: dict | None = None,
    closure_locals_by_body: dict | None = None,
    config=None,
    js_member_groups: dict | None = None,
    scope_parents: dict | None = None,
    lexical_nids_by_scope: dict | None = None,
    decl_node_fn=None,
    decl_lookup_fn=None,
) -> bool {
    def _decl(nid, name, kind, label, line) -> any {
        if decl_node_fn is not None {
            return decl_node_fn(nid, name, kind, label, line);
        }
        add_node_fn(nid, label, line);
        return nid;
    }

    def _lookup(name) -> any {
        return decl_lookup_fn(name) if decl_lookup_fn is not None else None;
    }
    if `node.type == "expression_statement" {
        call_stmt: any = next(
            (c for c in typing.cast(object, `node).children if c.type in ("call_expression", "new_expression")), None
        );
        if call_stmt is not None {
            _stmt_closures: list = [];
            _js_topmost_closures(call_stmt, _stmt_closures);
            closure: any;
            for closure in _stmt_closures {
                closure_body: any = closure.child_by_field_name("body");
                if closure_body is not None {
                    _js_scan_member_assignments(
                        closure_body,
                        file_nid,
                        source,
                        this_as_method=False,
                        add_node_fn=add_node_fn,
                        add_edge_fn=add_edge_fn,
                        function_bodies=function_bodies,
                        closure_locals_by_body=closure_locals_by_body,
                    );
                    if closure_locals_by_body is not None {
                        closure_locals_by_body[id(closure_body)] = _js_local_bound_names(
                            closure, source
                        )
                            | _js_enclosing_bound_names(closure, source);
                    }
                    function_bodies.append((file_nid, closure_body));
                }
            }
        }
        assign: any = next((c for c in typing.cast(object, `node).children if c.type == "assignment_expression"), None);
        if assign is not None {
            value: any = assign.child_by_field_name("right");
            if value is not None {
                target: any = _js_member_assignment_target(
                    assign.child_by_field_name("left"), source
                );
                if target is not None {
                    kind: any;
                    owner_name: any;
                    member_name: any;
                    (kind, owner_name, member_name) = target as any;
                    line: any = `node.start_point[0] + 1;
                    if value.type in _JS_FUNCTION_VALUE_TYPES {
                        handled: any = False;
                        if kind == "exports" {
                            nid: any = _decl(
                                _make_id(stem, member_name),
                                member_name,
                                "fn",
                                f"{member_name}()",
                                line,
                            );
                            add_edge_fn(file_nid, nid, "contains", line);
                            handled = True;
                        } elif kind == "prototype" {
                            owner_nid: any = _lookup(owner_name) or _make_id(stem, owner_name);
                            nid = _make_id(owner_nid, member_name);
                            add_node_fn(nid, f".{member_name}()", line);
                            add_edge_fn(owner_nid, nid, "method", line);
                            handled = True;
                        } elif kind == "object" {
                            is_exported: any = False;
                            if `node.parent is not None and `node.parent.type == "program" {
                                exported_names: any = _js_find_exported_objects(
                                    `node.parent, source
                                );
                                is_exported = owner_name in exported_names;
                            }
                            if is_exported {
                                owner_nid = _lookup(owner_name) or _make_id(stem, owner_name);
                                _owner_new: any = owner_nid not in seen_ids;
                                nid = _make_id(owner_nid, member_name);
                                if _owner_new {
                                    add_node_fn(owner_nid, owner_name, line);
                                    add_edge_fn(file_nid, owner_nid, "contains", line);
                                }
                                add_node_fn(nid, f".{member_name}()", line);
                                add_edge_fn(owner_nid, nid, "method", line);
                                handled = True;
                            }
                        }
                        if handled {
                            if callable_def_nids is not None {
                                callable_def_nids.add(nid);
                            }
                            if local_bound_names is not None {
                                local_bound_names[nid] = _js_local_bound_names(value, source);
                            }
                            body: any = value.child_by_field_name("body");
                            if body {
                                function_bodies.append((nid, body));
                            }
                            return True;
                        }
                    } elif kind == "exports" {
                        inner: any = value;
                        while inner is not None
                            and inner.type in ("as_expression", "satisfies_expression")
                        {
                            inner = inner.named_children[0] if inner.named_children else None;
                        }
                        if inner is not None
                            and inner.type in ("call_expression", "new_expression")
                        {
                            closures: list = [];
                            _js_topmost_closures(inner, closures);
                            if closures {
                                nid = _decl(
                                    _make_id(stem, member_name),
                                    member_name,
                                    "fn",
                                    f"{member_name}()",
                                    line,
                                );
                                add_edge_fn(file_nid, nid, "contains", line);
                                if callable_def_nids is not None {
                                    callable_def_nids.add(nid);
                                }
                                for closure in closures {
                                    body = closure.child_by_field_name("body");
                                    if body {
                                        if closure_locals_by_body is not None {
                                            closure_locals_by_body[id(
                                                body
                                            )] = _js_local_bound_names(closure, source);
                                        }
                                        function_bodies.append((nid, body));
                                    }
                                }
                                return True;
                            }
                        }
                    }
                }
            }
        }
    }
    if parent_class_nid and `node.type in ("field_definition", "public_field_definition") {
        prop: any = `node.child_by_field_name("property") or `node.child_by_field_name("name");
        value = `node.child_by_field_name("value");
        if prop is not None and value is not None and value.type in _JS_FUNCTION_VALUE_TYPES {
            field_name: any = _read_text(prop, source);
            if field_name {
                line = `node.start_point[0] + 1;
                nid = _js_member_nid(
                    parent_class_nid,
                    `node,
                    field_name,
                    source,
                    js_member_groups if js_member_groups is not None else {},
                );
                add_node_fn(nid, f".{field_name}()", line);
                add_edge_fn(parent_class_nid, nid, "method", line);
                if callable_def_nids is not None {
                    callable_def_nids.add(nid);
                }
                if local_bound_names is not None {
                    local_bound_names[nid] = _js_local_bound_names(value, source);
                }
                body = value.child_by_field_name("body");
                if body {
                    function_bodies.append((nid, body));
                }
                return True;
            }
        }
    }

    if `node.type in ("lexical_declaration", "variable_declaration") {
        require_found: any = _require_imports_js(`node, source, file_nid, stem, edges, str_path);
        parent: any = `node.parent;
        is_exported = parent is not None and operator.eq(parent.type, "export_statement");
        is_module_level: any = parent is not None
            and (
                operator.eq(parent.type, "program")
                or is_exported
                    and parent.parent is not None
                    and operator.eq(parent.parent.type, "program")
            );
        arrow_found: any = False;
        const_found: any = False;
        if `node.type == "lexical_declaration" and is_module_level {
            for child in typing.cast(object, `node).children {
                if child.type == "variable_declarator" {
                    value = child.child_by_field_name("value");
                    name_node: any = child.child_by_field_name("name");
                    is_exported_scalar_binding: any = is_exported
                        and name_node is not None
                        and operator.eq(name_node.type, "identifier")
                        and `bool(normalize_id(_read_text(name_node, source)));
                    if value and value.type in _JS_FUNCTION_VALUE_TYPES {
                        if name_node {
                            func_name: any = _read_text(name_node, source);
                            line = child.start_point[0] + 1;
                            if not normalize_id(func_name) {
                                continue;
                            }
                            func_nid: any = _decl(
                                _make_id(stem, func_name), func_name, "fn", f"{func_name}()", line
                            );
                            add_edge_fn(file_nid, func_nid, "contains", line);
                            if callable_def_nids is not None {
                                callable_def_nids.add(func_nid);
                            }
                            if local_bound_names is not None {
                                local_bound_names[func_nid] = _js_local_bound_names(value, source);
                            }
                            body = value.child_by_field_name("body");
                            if body {
                                function_bodies.append((func_nid, body));
                                _scan_js_nested_function_declarations(
                                    body,
                                    func_nid,
                                    source=source,
                                    config=config,
                                    add_node=add_node_fn,
                                    add_edge=add_edge_fn,
                                    callable_def_nids=callable_def_nids,
                                    local_bound_names=local_bound_names,
                                    function_bodies=function_bodies,
                                    scope_parents=scope_parents,
                                    lexical_nids_by_scope=lexical_nids_by_scope,
                                );
                                _js_scan_member_assignments(
                                    body,
                                    func_nid,
                                    source,
                                    this_as_method=True,
                                    add_node_fn=add_node_fn,
                                    add_edge_fn=add_edge_fn,
                                    function_bodies=function_bodies,
                                    closure_locals_by_body=closure_locals_by_body,
                                );
                            }
                            arrow_found = True;
                        }
                    } elif value
                        and not (
                            _js_value_is_require(value, source)
                            and _js_require_resolves_locally(value, source, str_path)
                        )
                        and (
                            is_exported_scalar_binding
                            or value.type
                                in (
                                    "object",
                                    "array",
                                    "as_expression",
                                    "satisfies_expression",
                                    "call_expression",
                                    "new_expression",
                                )
                        )
                    {
                        if name_node is not None
                            and name_node.type == "object_pattern"
                            and is_exported
                        {
                            line = child.start_point[0] + 1;
                            for prop in typing.cast(object, name_node).named_children {
                                if prop.type == "shorthand_property_identifier_pattern" {
                                    export_name: any = _read_text(prop, source);
                                } elif prop.type == "pair_pattern" {
                                    key_node: any = prop.child_by_field_name("key");
                                    export_name = _read_text(key_node, source)
                                        if key_node
                                        else None;
                                } else {
                                    export_name = None;
                                }
                                if not export_name or not normalize_id(export_name) {
                                    continue;
                                }
                                prop_nid: any = _decl(
                                    _make_id(stem, export_name),
                                    export_name,
                                    "var",
                                    export_name,
                                    line,
                                );
                                add_edge_fn(file_nid, prop_nid, "contains", line);
                            }
                            const_found = True;
                        } elif name_node {
                            const_name: any = _read_text(name_node, source);
                            line = child.start_point[0] + 1;
                            const_nid: any = _decl(
                                _make_id(stem, const_name), const_name, "var", const_name, line
                            );
                            add_edge_fn(file_nid, const_nid, "contains", line);
                            const_found = True;
                            inner = value;
                            while inner is not None
                                and inner.type in ("as_expression", "satisfies_expression")
                            {
                                inner = inner.named_children[0] if inner.named_children else None;
                            }
                            if inner is not None
                                and inner.type in ("call_expression", "new_expression")
                            {
                                closures = [];
                                _js_topmost_closures(inner, closures);
                                for closure in closures {
                                    body = closure.child_by_field_name("body");
                                    if body {
                                        if closure_locals_by_body is not None {
                                            closure_locals_by_body[id(
                                                body
                                            )] = _js_local_bound_names(closure, source);
                                        }
                                        function_bodies.append((const_nid, body));
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        if arrow_found {
            return True;
        }
        if const_found {
            return True;
        }
        if require_found {
            return True;
        }
    }
    return False;
}

impl _ts_extra_walk(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    str_path: str,
    nodes: list,
    edges: list,
    seen_ids: set,
    function_bodies: list,
    parent_class_nid: str | None,
    add_node_fn,
    add_edge_fn,
    walk_fn,
    decl_node_fn=None,
    namespace_stack: list[str] | None = None,
) -> bool {
    def _decl(nid, name, kind, label, line) -> any {
        if decl_node_fn is not None {
            return decl_node_fn(nid, name, kind, label, line);
        }
        add_node_fn(nid, label, line);
        return nid;
    }

    if parent_class_nid
        and `node.parent is not None
        and `node.parent.type == "enum_body"
        and `node.type in ("property_identifier", "enum_assignment")
    {
        name_node: any = `node
            if `node.type == "property_identifier"
            else `node.child_by_field_name("name");
        member_name: any = "";
        if name_node is not None {
            member_name = _read_text(name_node, source);
            if name_node.type == "string" {
                member_name = member_name.strip("'\"`");
            }
        }
        if member_name {
            line: any = `node.start_point[0] + 1;
            member_nid: any = _make_id(parent_class_nid, member_name);
            if member_nid not in seen_ids {
                add_node_fn(member_nid, member_name, line);
                add_edge_fn(parent_class_nid, member_nid, "case_of", line);
            }
        }
        if `node.type == "enum_assignment" {
            value_node: any = `node.child_by_field_name("value");
            if value_node is not None {
                walk_fn(value_node, parent_class_nid);
            }
        }
        return True;
    }
    if `node.is_named and `node.type in ("internal_module", "module") {
        name_node = `node.child_by_field_name("name");
        if name_node is None {
            child: any;
            for child in typing.cast(object, `node).children {
                if child.is_named and child.type in ("identifier", "nested_identifier", "string") {
                    name_node = child;
                    break;
                }
            }
        }
        body: any = `node.child_by_field_name("body");
        if body is None {
            for child in typing.cast(object, `node).children {
                if child.type == "statement_block" {
                    body = child;
                    break;
                }
            }
        }
        if name_node is not None {
            ns_name: any = _read_text(name_node, source);
            if name_node.type == "string" {
                ns_name = ns_name.strip("'\"`");
            }
            if ns_name {
                line = `node.start_point[0] + 1;
                ns_nid: any = _decl(
                    _make_id(stem, ".".join(namespace_stack or []), ns_name),
                    ns_name,
                    "ns",
                    ns_name,
                    line,
                );
                add_edge_fn(file_nid, ns_nid, "contains", line);
            }
        }
        if namespace_stack is not None and name_node is not None and ns_name {
            namespace_stack.append(ns_name);
            try {
                if body is not None {
                    for child in typing.cast(object, body).children {
                        walk_fn(child, parent_class_nid);
                    }
                }
            } finally {
                namespace_stack.pop();
            }
        } elif body is not None {
            for child in typing.cast(object, body).children {
                walk_fn(child, parent_class_nid);
            }
        }
        return True;
    }
    return False;
}

impl _csharp_scope_id(`node) -> str {
    row: any;
    column: any;
    (row, column) = `node.start_point as any;
    return f"s{row}:{column}";
}

impl _csharp_namespace_name(`node, source: bytes) -> str {
    name_node: any = `node.child_by_field_name("name");
    if name_node is not None {
        return _read_text(name_node, source).strip();
    }
    for child in typing.cast(object, `node).children {
        if child.type in ("identifier", "qualified_name") {
            return _read_text(child, source).strip();
        }
    }
    return "";
}

impl _csharp_extra_walk(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    str_path: str,
    nodes: list,
    edges: list,
    seen_ids: set,
    function_bodies: list,
    parent_class_nid: str | None,
    add_node_fn,
    add_edge_fn,
    walk_fn,
    namespace_stack: list[str],
    scope_stack: list[str],
    member_groups: dict[str, set[str]] | None = None,
) -> bool {
    if `node.type == "enum_member_declaration" and parent_class_nid {
        name_node: any = `node.child_by_field_name("name");
        if name_node is None {
            return True;
        }
        member_name: any = _read_text(name_node, source);
        if not member_name {
            return True;
        }
        line: any = `node.start_point[0] + 1;
        member_nid: any = _underscore_salted_nid(
            _make_id(parent_class_nid, member_name), member_name, member_groups or {}
        );
        if member_nid not in seen_ids {
            add_node_fn(member_nid, member_name, line);
            add_edge_fn(parent_class_nid, member_nid, "case_of", line);
        }
        return True;
    }
    if `node.type == "namespace_declaration" {
        ns_name: any = _csharp_namespace_name(`node, source);
        pushed: any = False;
        if ns_name {
            namespace_stack.append(ns_name);
            scope_stack.append(_csharp_scope_id(`node));
            pushed = True;
            ns_label: any = ".".join(namespace_stack);
            ns_nid: any = _csharp_namespace_id(ns_label);
            line = `node.start_point[0] + 1;
            add_node_fn(
                ns_nid, ns_label, line, node_type="namespace", metadata={"kind": "csharp_namespace"}
            );
            add_edge_fn(file_nid, ns_nid, "contains", line);
        }
        body: any = `node.child_by_field_name("body");
        if body {
            try {
                child: any;
                for child in typing.cast(object, body).children {
                    walk_fn(child, parent_class_nid);
                }
            } finally {
                if pushed {
                    namespace_stack.pop();
                    scope_stack.pop();
                }
            }
        } elif pushed {
            namespace_stack.pop();
            scope_stack.pop();
        }
        return True;
    }
    if `node.type == "file_scoped_namespace_declaration" {
        ns_name = _csharp_namespace_name(`node, source);
        if ns_name {
            namespace_stack.append(ns_name);
            scope_stack.append(_csharp_scope_id(`node));
            ns_label = ".".join(namespace_stack);
            ns_nid = _csharp_namespace_id(ns_label);
            line = `node.start_point[0] + 1;
            add_node_fn(
                ns_nid, ns_label, line, node_type="namespace", metadata={"kind": "csharp_namespace"}
            );
            add_edge_fn(file_nid, ns_nid, "contains", line);
        }
        return True;
    }
    if parent_class_nid and `node.type.startswith("preproc_") {
        for child in typing.cast(object, `node).children {
            walk_fn(child, parent_class_nid);
        }
        return True;
    }
    return False;
}

impl _swift_extra_walk(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    str_path: str,
    nodes: list,
    edges: list,
    seen_ids: set,
    function_bodies: list,
    parent_class_nid: str | None,
    add_node_fn,
    add_edge_fn,
    ensure_named_node_fn,
) -> bool {
    if `node.type == "enum_entry" and parent_class_nid {
        line: any = `node.start_point[0] + 1;
        child: any;
        for child in typing.cast(object, `node).children {
            if child.type == "simple_identifier" {
                case_name: any = _read_text(child, source);
                case_nid: any = _make_id(parent_class_nid, case_name);
                add_node_fn(case_nid, case_name, line);
                add_edge_fn(parent_class_nid, case_nid, "case_of", line);
            }
        }
        for child in typing.cast(object, `node).children {
            if child.type != "enum_type_parameters" {
                continue;
            }
            for grand in typing.cast(object, child).children {
                if not grand.is_named {
                    continue;
                }
                refs: list[tuple[str, str]] = [];
                _swift_collect_type_refs(grand, source, False, refs);
                for (ref_name, role) in refs {
                    ctx: any = "generic_arg" if role == "generic_arg" else "type";
                    target_nid: any = ensure_named_node_fn(ref_name, line);
                    if target_nid != parent_class_nid {
                        add_edge_fn(parent_class_nid, target_nid, "references", line, context=ctx);
                    }
                }
            }
        }
        return True;
    }
    return False;
}

impl _scala_extension_receiver_name(`node, source: bytes) -> str | None {
    clause: any = next(
        (c
        for c in typing.cast(object, `node).children
        if c.type == "parameters" and not `any(operator.eq(cc.type, "using") for cc in typing.cast(object, c).children)),
        None,
    );
    if clause is None {
        return None;
    }
    param: any = next((c for c in typing.cast(object, clause).children if c.type == "parameter"), None);
    if param is None {
        return None;
    }
    type_node: any = next(
        (c
        for c in typing.cast(object, param).children
        if c.type in ("type_identifier", "generic_type", "stable_type_identifier")),
        None,
    );
    if type_node is not None and type_node.type == "generic_type" {
        type_node = next(
            (c
            for c in typing.cast(object, type_node).children
            if c.type in ("type_identifier", "stable_type_identifier")),
            None,
        );
    }
    if type_node is not None and type_node.type == "stable_type_identifier" {
        type_node = next(
            (c for c in reversed(type_node.children) if c.type == "type_identifier"), None
        );
    }
    if type_node is None {
        return None;
    }
    name: any = _read_text(type_node, source).strip();
    if not name or name in _scala_type_parameters_in_scope(`node, source) {
        return None;
    }
    return name;
}

impl _scala_extra_walk(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    str_path: str,
    nodes: list,
    edges: list,
    seen_ids: set,
    function_bodies: list,
    parent_class_nid: str | None,
    add_node_fn,
    add_edge_fn,
    walk_fn,
    ensure_named_node_fn,
) -> bool {
    if `node.type == "enum_case_definitions" and parent_class_nid {
        for `case in typing.cast(object, `node).children {
            if `case.type not in ("simple_enum_case", "full_enum_case") {
                continue;
            }
            name_node: any = next((c for c in typing.cast(object, `case).children if c.type == "identifier"), None);
            if name_node is None {
                continue;
            }
            case_name: any = _read_text(name_node, source);
            if not case_name {
                continue;
            }
            line: any = `case.start_point[0] + 1;
            case_nid: any = _make_id(parent_class_nid, case_name);
            if case_nid not in seen_ids {
                add_node_fn(case_nid, case_name, line);
                add_edge_fn(parent_class_nid, case_nid, "case_of", line);
            }
        }
        return True;
    }
    if `node.type == "extension_definition" {
        receiver: any = _scala_extension_receiver_name(`node, source);
        if receiver is None {
            return False;
        }
        receiver_nid: any = ensure_named_node_fn(receiver, `node.start_point[0] + 1);
        for member in `node.children_by_field_name("body") {
            walk_fn(member, parent_class_nid=receiver_nid);
        }
        return True;
    }
    return False;
}

impl _cpp_declarator_type_name(declarator, source: bytes) -> str | None {
    `node: any = declarator;
    while `node is not None and `node.type != "type_identifier" {
        inner: any = `node.child_by_field_name("declarator");
        if inner is None and `node.type == "parenthesized_declarator" {
            inner = next(iter(`node.named_children), None);
        }
        `node = inner;
    }
    return _read_text(`node, source) if `node is not None else None;
}

impl _cpp_type_last_name(type_node, source: bytes) -> str | None {
    if type_node is not None and type_node.type == "type_descriptor" {
        type_node = type_node.child_by_field_name("type");
    }
    if type_node is None or type_node.type != "qualified_identifier" {
        return None;
    }
    while type_node is not None and type_node.type == "qualified_identifier" {
        type_node = type_node.child_by_field_name("name");
    }
    if type_node is not None and type_node.type == "template_type" {
        type_node = type_node.child_by_field_name("name");
    }
    return _read_text(type_node, source) if type_node is not None else None;
}

impl _cpp_alias_names(`node, source: bytes) -> list[str] {
    scope: any = `node.parent;
    while scope is not None
        and (scope.type == "template_declaration" or scope.type.startswith("preproc_"))
    {
        scope = scope.parent;
    }
    if scope is None or scope.type not in ("translation_unit", "declaration_list") {
        return [];
    }
    target: any = `node.child_by_field_name("type");
    if `node.type == "alias_declaration" {
        name_node: any = `node.child_by_field_name("name");
        candidates: any = [_read_text(name_node, source)] if name_node is not None else [];
    } else {
        candidates = [
            _cpp_declarator_type_name(d, source)
            for d in `node.children_by_field_name("declarator")
        ];
    }
    own_names: any = {_cpp_type_last_name(target, source)};
    if target is not None
        and target.type
            in ("struct_specifier", "class_specifier", "union_specifier", "enum_specifier")
    {
        spec_name: any = target.child_by_field_name("name");
        if spec_name is not None {
            own_names.add(_read_text(spec_name, source));
        }
    }
    names: list[str] = [];
    seen: any = `set(own_names);
    for name in candidates {
        if name and name not in seen {
            seen.add(name);
            names.append(name);
        }
    }
    return names;
}

impl _cpp_extra_walk(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    str_path: str,
    nodes: list,
    edges: list,
    seen_ids: set,
    function_bodies: list,
    parent_class_nid: str | None,
    add_node_fn,
    add_edge_fn,
    decl_node_fn=None,
) -> bool {
    if `node.type in ("alias_declaration", "type_definition") {
        line: any = `node.start_point[0] + 1;
        for alias_name in _cpp_alias_names(`node, source) {
            alias_nid: any = _make_id(stem, alias_name);
            known: any = len(seen_ids);
            if decl_node_fn is not None {
                alias_nid = decl_node_fn(alias_nid, alias_name, "alias", alias_name, line);
            } else {
                add_node_fn(alias_nid, alias_name, line);
            }
            if len(seen_ids) > known {
                add_edge_fn(file_nid, alias_nid, "contains", line);
            }
        }
        return False;
    }
    if `node.type == "enumerator" and parent_class_nid {
        name_node: any = `node.child_by_field_name("name");
        if name_node is None {
            name_node = next((c for c in typing.cast(object, `node).children if c.type == "identifier"), None);
        }
        if name_node is None {
            return True;
        }
        member_name: any = _read_text(name_node, source);
        if member_name {
            line = `node.start_point[0] + 1;
            member_nid: any = _make_id(parent_class_nid, member_name);
            if member_nid not in seen_ids {
                add_node_fn(member_nid, member_name, line);
                add_edge_fn(parent_class_nid, member_nid, "case_of", line);
            }
        }
        return True;
    }
    return False;
}

impl _php_extra_walk(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    str_path: str,
    nodes: list,
    edges: list,
    seen_ids: set,
    function_bodies: list,
    parent_class_nid: str | None,
    add_node_fn,
    add_edge_fn,
) -> bool {
    if `node.type == "enum_case" and parent_class_nid {
        name_node: any = `node.child_by_field_name("name");
        if name_node is None {
            name_node = next((c for c in typing.cast(object, `node).children if c.type == "name"), None);
        }
        if name_node is None {
            return True;
        }
        case_name: any = _read_text(name_node, source);
        if case_name {
            line: any = `node.start_point[0] + 1;
            case_nid: any = _make_id(parent_class_nid, case_name);
            if case_nid not in seen_ids {
                add_node_fn(case_nid, case_name, line);
                add_edge_fn(parent_class_nid, case_nid, "case_of", line);
            }
        }
        return True;
    }
    return False;
}

impl _java_extra_walk(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    str_path: str,
    nodes: list,
    edges: list,
    seen_ids: set,
    function_bodies: list,
    parent_class_nid: str | None,
    add_node_fn,
    add_edge_fn,
    walk_fn,
) -> bool {
    if `node.type == "enum_constant" and parent_class_nid {
        name_node: any = `node.child_by_field_name("name");
        if name_node is None {
            return True;
        }
        const_name: any = _read_text(name_node, source);
        line: any = `node.start_point[0] + 1;
        const_nid: any = _make_id(parent_class_nid, const_name);
        add_node_fn(const_nid, const_name, line);
        add_edge_fn(parent_class_nid, const_nid, "case_of", line);
        for child in typing.cast(object, `node).children {
            if child.type == "class_body" {
                for member in typing.cast(object, child).children {
                    walk_fn(member, parent_class_nid=const_nid);
                }
            }
        }
        return True;
    }
    return False;
}

impl _kotlin_extra_walk(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    str_path: str,
    nodes: list,
    edges: list,
    seen_ids: set,
    function_bodies: list,
    parent_class_nid: str | None,
    add_node_fn,
    add_edge_fn,
    walk_fn,
) -> bool {
    if `node.type == "enum_entry" and parent_class_nid {
        name_node: any = None;
        child: any;
        for child in typing.cast(object, `node).children {
            if child.type in ("simple_identifier", "identifier") {
                name_node = child;
                break;
            }
        }
        if name_node is None {
            return True;
        }
        const_name: any = _read_text(name_node, source);
        line: any = `node.start_point[0] + 1;
        const_nid: any = _make_id(parent_class_nid, const_name);
        add_node_fn(const_nid, const_name, line);
        add_edge_fn(parent_class_nid, const_nid, "case_of", line);
        for child in typing.cast(object, `node).children {
            if child.type == "class_body" {
                for member in typing.cast(object, child).children {
                    walk_fn(member, parent_class_nid=const_nid);
                }
            }
        }
        return True;
    }
    return False;
}

impl _kotlin_package_name(`root, source: bytes) -> str | None {
    for child in typing.cast(object, `root).children {
        if child.type != "package_header" {
            continue;
        }
        for c in typing.cast(object, child).children {
            if c.type in ("qualified_identifier", "identifier") {
                pkg: any = _read_text(c, source).strip();
                return pkg or None;
            }
        }
        return None;
    }
    return None;
}

impl _kotlin_nav_identifier_segments(nav, source: bytes) -> list[str] | None {
    segments: list[str] = [];
    `node: any = nav;
    while `node is not None and `node.type == "navigation_expression" {
        named: any = [c for c in typing.cast(object, `node).children if c.is_named];
        if len(named) != 2 {
            return None;
        }
        head: any;
        tail: any;
        (head, tail) = named as any;
        if tail.type not in ("simple_identifier", "identifier") {
            return None;
        }
        segments.append(_read_text(tail, source));
        `node = head;
    }
    if `node is None or `node.type not in ("simple_identifier", "identifier") {
        return None;
    }
    segments.append(_read_text(`node, source));
    segments.reverse();
    return segments;
}

impl _kotlin_type_name(type_node, source: bytes) -> str | None {
    if type_node is not None and type_node.type == "nullable_type" {
        type_node = next((c for c in typing.cast(object, type_node).children if c.type == "user_type"), None);
    }
    if type_node is None or type_node.type != "user_type" {
        return None;
    }
    parts: any = [c for c in typing.cast(object, type_node).children if c.type == "simple_user_type"] or [type_node];
    names: any = [c for c in parts[-1].children if c.type in _KOTLIN_IDENTIFIERS];
    return _read_text(names[-1 if len(parts) == 1 else 0], source) if names else None;
}

impl _kotlin_declared_type(decl, initializer, source: bytes) -> str {
    for child in typing.cast(object, decl).children {
        name: any = _kotlin_type_name(child, source);
        if name {
            return name;
        }
    }
    if initializer is not None and initializer.type == "call_expression" and initializer.children {
        callee: any = initializer.children[0];
        if callee.type in _KOTLIN_IDENTIFIERS {
            text: any = _read_text(callee, source);
            if text[:1].isupper() {
                return text;
            }
        }
    }
    return "";
}

impl _kotlin_binding_name(decl, source: bytes) -> str | None {
    return next(
        (_read_text(c, source) for c in typing.cast(object, decl).children if c.type in _KOTLIN_IDENTIFIERS), None
    );
}

impl _kotlin_variable_binding(decl, name: str, initializer, source: bytes) -> str | None {
    if decl.type == "variable_declaration" and _kotlin_binding_name(decl, source) == name {
        return _kotlin_declared_type(decl, initializer, source);
    }
    if decl.type == "multi_variable_declaration"
        and `any(
            operator.eq(_kotlin_binding_name(v, source), name)
            for v in typing.cast(object, decl).children
            if v.type == "variable_declaration",
        )
    {
        return "";
    }
    return None;
}

impl _kotlin_property_binding(prop, name: str, source: bytes) -> str | None {
    named: any = [c for c in typing.cast(object, prop).children if c.is_named];
    for (i, child) in enumerate(named) {
        initializer: any = named[i + 1] if i + 1 < len(named) else None;
        bound: any = _kotlin_variable_binding(child, name, initializer, source);
        if bound is not None {
            return bound;
        }
    }
    return None;
}

impl _kotlin_receiver_type(call, name: str, source: bytes, *, this_field: bool = False) -> str
    | None {
    `node: any = call.parent;
    while `node is not None {
        t: any = `node.type;
        if not this_field {
            bound: any = None;
            if t in ("function_declaration", "anonymous_function", "secondary_constructor") {
                params: any;
                for params in typing.cast(object, `node).children {
                    param: any;
                    for param in params.children
                        if params.type == "function_value_parameters"
                        else [] {
                        if param.type == "parameter"
                            and _kotlin_binding_name(param, source) == name
                        {
                            bound = _kotlin_declared_type(param, None, source);
                        }
                    }
                }
            } elif t == "lambda_literal" {
                params = next((c for c in typing.cast(object, `node).children if c.type == "lambda_parameters"), None);
                if params is None {
                    bound = "" if name == "it" else None;
                } else {
                    decl: any;
                    for decl in typing.cast(object, params).children {
                        bound = _kotlin_variable_binding(decl, name, None, source)
                            if bound is None
                            else bound;
                    }
                }
            } elif t == "for_statement" {
                decl = next((c for c in typing.cast(object, `node).children if c.is_named), None);
                if decl is not None {
                    bound = _kotlin_variable_binding(decl, name, None, source);
                }
            } elif t == "catch_block" {
                if _kotlin_binding_name(`node, source) == name {
                    bound = "";
                }
            }
            if bound is not None {
                return bound;
            }
            if t in ("block", "statements", "source_file", "lambda_literal") {
                stmt: any;
                for stmt in typing.cast(object, `node).children {
                    if stmt.start_byte >= call.start_byte {
                        break;
                    }
                    if stmt.type == "property_declaration" {
                        found: any = _kotlin_property_binding(stmt, name, source);
                        bound = found if found is not None else bound;
                    }
                }
                if bound is not None {
                    return bound;
                }
            }
        }
        if t == "class_body" {
            for stmt in typing.cast(object, `node).children {
                if stmt.type == "property_declaration" {
                    bound = _kotlin_property_binding(stmt, name, source);
                    if bound is not None {
                        return bound;
                    }
                }
            }
        } elif t == "class_declaration" {
            for ctor in typing.cast(object, `node).children {
                for params in ctor.children if ctor.type == "primary_constructor" else [] {
                    for param in params.children if params.type == "class_parameters" else [] {
                        if param.type == "class_parameter"
                            and `any(c.type in ("val", "var") for c in typing.cast(object, param).children)
                            and _kotlin_binding_name(param, source) == name
                        {
                            return _kotlin_declared_type(param, None, source);
                        }
                    }
                }
            }
            if this_field {
                return None;
            }
        }
        `node = `node.parent;
    }
    return None;
}

impl _first_parse_error_line(`root) -> int {
    `node: any = `root;
    while True {
        if `node.type == "ERROR" or `node.is_missing {
            return `node.start_point[0] + 1;
        }
        child: any = next((c for c in typing.cast(object, `node).children if c.has_error), None);
        if child is None {
            return `node.start_point[0] + 1;
        }
        `node = child;
    }
}

impl _first_multiline_error_line(`root) -> int {
    best: any = None;
    stack: any = [`root];
    while stack {
        n: any = stack.pop();
        if n.type == "ERROR" and n.end_point[0] > n.start_point[0] {
            if best is None or n.start_byte < best.start_byte {
                best = n;
            }
        }
        stack.extend(c for c in typing.cast(object, n).children if c.has_error);
    }
    if best is None {
        return _first_parse_error_line(`root);
    }
    return best.start_point[0] + 1;
}

impl _has_multiline_error(`root) -> bool {
    stack: any = [`root];
    while stack {
        n: any = stack.pop();
        if n.type == "ERROR" and n.end_point[0] > n.start_point[0] {
            return True;
        }
        stack.extend(c for c in typing.cast(object, n).children if c.has_error);
    }
    return False;
}

impl _csharp_bare_call_name(name_node, source: bytes) -> str {
    if name_node.type == "generic_name" {
        for child in typing.cast(object, name_node).children {
            if child.type == "identifier" {
                return _read_text(child, source);
            }
        }
    }
    return _read_text(name_node, source);
}

impl _csharp_member_call_parts(fn_node) -> any {
    if fn_node is None {
        return None;
    }
    if fn_node.type == "member_access_expression" {
        return (fn_node.child_by_field_name("name"), fn_node.child_by_field_name("expression"));
    }
    if fn_node.type == "conditional_access_expression" {
        for child in typing.cast(object, fn_node).named_children {
            if child.type == "member_binding_expression" {
                return (
                    child.child_by_field_name("name"),
                    fn_node.child_by_field_name("condition"),
                );
            }
        }
    }
    return None;
}

impl _read_csharp_type_name(`node, source: bytes) -> tuple[str, bool, str] | None {
    if `node is None {
        return None;
    }
    if `node.type in ("identifier", "predefined_type") {
        return (_read_text(`node, source), False, "");
    }
    if `node.type == "qualified_name" {
        prefix: any;
        _: any;
        tail: any;
        (prefix, _, tail) = _read_text(`node, source).rpartition(".") as any;
        tail = tail.split("<", 1)[0];
        return (tail, True, prefix);
    }
    if `node.type == "generic_name" {
        name_node: any = `node.child_by_field_name("name");
        if name_node is not None {
            qualified: any = operator.eq(name_node.type, "qualified_name");
            (prefix, _, tail) = _read_text(name_node, source).rpartition(".") as any;
            return (tail, qualified, prefix if qualified else "");
        }
    }
    for child in typing.cast(object, `node).children {
        if not child.is_named {
            continue;
        }
        result: any = _read_csharp_type_name(child, source);
        if result {
            return result;
        }
    }
    return None;
}

impl _ruby_new_class_name(`node, source: bytes) -> str | None {
    if `node is None or `node.type != "call" {
        return None;
    }
    recv: any = `node.child_by_field_name("receiver");
    meth: any = `node.child_by_field_name("method");
    if recv is None or meth is None {
        return None;
    }
    if recv.type != "constant" or _read_text(meth, source) != "new" {
        return None;
    }
    return _read_text(recv, source);
}

impl _python_class_ref(`node, source: bytes) -> str | None {
    if `node is None {
        return None;
    }
    kind: any = `node.type;
    if kind == "type" {
        named: any = [c for c in typing.cast(object, `node).children if c.is_named];
        return _python_class_ref(named[0], source) if len(named) == 1 else None;
    }
    if kind == "identifier" {
        name: any = _read_text(`node, source);
        return name if name[:1].isupper() else None;
    }
    if kind == "attribute" {
        return _python_class_ref(`node.child_by_field_name("attribute"), source);
    }
    if kind == "string" {
        name = _read_text(`node, source).strip("\"'").split(".")[-1].strip();
        return name if name.isidentifier() and name[:1].isupper() else None;
    }
    if kind == "subscript" {
        value: any = `node.child_by_field_name("value");
        subs: any = `node.children_by_field_name("subscript");
        if value is not None
            and _read_text(value, source).split(".")[-1] == "Optional"
            and len(subs) == 1
        {
            return _python_class_ref(subs[0], source);
        }
        return None;
    }
    if kind == "generic_type" {
        named = [c for c in typing.cast(object, `node).children if c.is_named];
        if len(named) == 2
            and named[0].type == "identifier"
            and _read_text(named[0], source) == "Optional"
            and named[1].type == "type_parameter"
        {
            inner: any = [c for c in named[1].children if c.is_named];
            return _python_class_ref(inner[0], source) if len(inner) == 1 else None;
        }
        return None;
    }
    if kind == "binary_operator" {
        left: any;
        right: any;
        (left, right) = (`node.child_by_field_name("left"), `node.child_by_field_name("right"));
        if right is not None and right.type == "none" {
            return _python_class_ref(left, source);
        }
        if left is not None and left.type == "none" {
            return _python_class_ref(right, source);
        }
    }
    return None;
}

impl _python_local_class_bindings(
    body_node, source: bytes, *, factory_bindings: dict[str, list[int]] | None = None
) -> dict[str, str | None] {
    bindings: dict[str, str | tuple[int, int] | None];
    poison_only: any;
    bindings = {};
    poison_only = False;

    def bind(name: str, cls: str | tuple[int, int] | None) {
        if poison_only or cls is None or bindings.get(name, cls) != cls {
            bindings[name] = None;
        } elif name not in bindings {
            bindings[name] = cls;
        }
    }

    def poison(target) {
        names: set[str] = set[any]();
        _python_collect_assignment_targets(target, source, names);
        for name in names {
            bindings[name] = None;
        }
    }

    def poison_identifiers(`node) {
        stack: any = [`node];
        while stack {
            cur: any = stack.pop();
            if cur.type == "identifier" {
                bindings[_read_text(cur, source)] = None;
            }
            stack.extend(cur.children);
        }
    }

    func: any = body_node.parent;
    params: any = func.child_by_field_name("parameters")
        if func is not None and func.type == "function_definition"
        else None;
    name: any;
    for name in _python_param_names(params, source) {
        bindings[name] = None;
    }
    if params is not None {
        for child in typing.cast(object, params).children {
            if child.type in ("typed_parameter", "typed_default_parameter") {
                name_n: any = child.child_by_field_name("name")
                    or next((c for c in typing.cast(object, child).children if c.type == "identifier"), None);
                if name_n is not None {
                    name = _read_text(name_n, source);
                    bindings.pop(name, None);
                    bind(name, _python_class_ref(child.child_by_field_name("type"), source));
                }
            }
        }
    }

    def `visit(n) {
        c: any;
        for child in typing.cast(object, n).children {
            if child.type == "function_definition" {
                fn_stack = builtins.list((child,));
                while fn_stack {
                    fn_cur = fn_stack.pop();
                    if fn_cur.type == "nonlocal_statement" {
                        poison_identifiers(fn_cur);
                    }
                    fn_stack.extend(fn_cur.children);
                }
                continue;
            }
            if child.type in ("lambda", "class_definition") {
                params: any = child.child_by_field_name("parameters");
                if child.type == "lambda" and params is not None {
                    poison_identifiers(params);
                }
                outer: any;
                (outer, poison_only) = (poison_only, True);
                `visit(child);
                poison_only = outer;
                continue;
            }
            if child.type in ("case_pattern", "import_statement", "import_from_statement") {
                poison_identifiers(child);
                continue;
            }
            if child.type == "assignment" {
                left: any = child.child_by_field_name("left");
                if left is not None and left.type == "identifier" {
                    name: any = _read_text(left, source);
                    annotation: any = child.child_by_field_name("type");
                    right: any = child.child_by_field_name("right");
                    if annotation is not None {
                        bind(name, _python_class_ref(annotation, source));
                    } elif right is not None and right.type == "call" {
                        fn: any = right.child_by_field_name("function");
                        cls: any = _python_class_ref(fn, source);
                        if cls is None
                            and factory_bindings is not None
                            and fn is not None
                            and fn.type == "attribute"
                        {
                            bind(name, (right.start_byte, right.end_byte));
                        } else {
                            bind(name, cls);
                        }
                    } else {
                        bindings[name] = None;
                    }
                } else {
                    poison(left);
                }
            } elif child.type == "augmented_assignment" {
                poison(child.child_by_field_name("left"));
            } elif child.type == "as_pattern" {
                alias: any = child.child_by_field_name("alias");
                target: any = next((c for c in typing.cast(object, alias).children if c.type == "identifier"), None)
                    if alias is not None
                    else None;
                value: any = next((c for c in typing.cast(object, child).children if c.is_named), None);
                if target is not None {
                    name = _read_text(target, source);
                    if child.parent is not None
                        and child.parent.type == "with_item"
                        and value is not None
                        and value.type == "call"
                    {
                        bind(
                            name, _python_class_ref(value.child_by_field_name("function"), source)
                        );
                    } else {
                        bindings[name] = None;
                    }
                } elif alias is not None {
                    poison_identifiers(alias);
                }
            } elif child.type in ("for_statement", "for_in_clause") {
                poison(child.child_by_field_name("left"));
            } elif child.type == "named_expression" {
                poison(child.child_by_field_name("name"));
            } elif child.type in ("global_statement", "nonlocal_statement") {
                for c in typing.cast(object, child).children {
                    if c.type == "identifier" {
                        bindings[_read_text(c, source)] = None;
                    }
                }
            }
            `visit(child);
        }
    }

    `visit(body_node);
    if factory_bindings is not None {
        factory_bindings.update({
            name: `list(value)
            for (name, value) in bindings.items()
            if isinstance(value, `tuple)
        });
    }
    return {name: value if isinstance(value, `str) else None for (name, value) in bindings.items()};
}

impl _ruby_local_class_bindings(body_node, source: bytes) -> dict[str, str | None] {
    bindings: dict[str, str | None];
    boundary: any;
    bindings = {};
    boundary = {"method", "singleton_method"};

    def `visit(n) {
        for child in typing.cast(object, n).children {
            if child.type in boundary {
                continue;
            }
            if child.type == "assignment" {
                left: any = child.child_by_field_name("left");
                right: any = child.child_by_field_name("right");
                if left is not None and left.type == "identifier" {
                    var: any = _read_text(left, source);
                    cls: any = _ruby_new_class_name(right, source) if right is not None else None;
                    if cls is None {
                        if var in bindings {
                            bindings[var] = None;
                        }
                    } elif var in bindings {
                        if bindings[var] != cls {
                            bindings[var] = None;
                        }
                    } else {
                        bindings[var] = cls;
                    }
                }
            }
            `visit(child);
        }
    }

    `visit(body_node);
    return bindings;
}

impl _ruby_local_names(body_node, source: bytes) -> frozenset[str] {
    names: set[str];
    boundary: any;
    param_lists: any;
    param_wrappers: any;
    names = set[any]();
    boundary = {"method", "singleton_method"};
    param_lists = {"method_parameters", "block_parameters", "lambda_parameters", "bare_parameters"};
    param_wrappers = {
        "optional_parameter",
        "splat_parameter",
        "hash_splat_parameter",
        "keyword_parameter",
        "block_parameter",
        "destructured_parameter",
        "forward_parameter",
    };

    def _first_identifier(n) -> any {
        if n.type == "identifier" {
            return n;
        }
        for c in typing.cast(object, n).children {
            found: any = _first_identifier(c);
            if found is not None {
                return found;
            }
        }
        return None;
    }

    def _add_params(param_list) {
        for child in typing.cast(object, param_list).children {
            if child.type == "identifier" {
                names.add(_read_text(child, source));
            } elif child.type in param_wrappers {
                ident: any = _first_identifier(child);
                if ident is not None {
                    names.add(_read_text(ident, source));
                }
            }
        }
    }

    def _add_targets(n) {
        if n.type == "identifier" {
            names.add(_read_text(n, source));
            return;
        }
        for c in typing.cast(object, n).children {
            _add_targets(c);
        }
    }
    parent: any = body_node.parent;
    if parent is not None {
        for child in typing.cast(object, parent).children {
            if child.type in param_lists {
                _add_params(child);
            }
        }
    }

    def `visit(n) {
        for child in typing.cast(object, n).children {
            if child.type in boundary {
                continue;
            }
            if child.type in ("assignment", "operator_assignment") {
                left: any = child.child_by_field_name("left");
                if left is not None {
                    if left.type == "identifier" {
                        names.add(_read_text(left, source));
                    } elif left.type not in ("call", "element_reference") {
                        _add_targets(left);
                    }
                }
            } elif child.type in param_lists {
                _add_params(child);
            } elif child.type == "exception_variable" {
                ident: any = _first_identifier(child);
                if ident is not None {
                    names.add(_read_text(ident, source));
                }
            } elif child.type == "for" {
                for sub in typing.cast(object, child).children {
                    if sub.type == "identifier" {
                        names.add(_read_text(sub, source));
                    } elif sub.type == "left_assignment_list" {
                        _add_targets(sub);
                    }
                }
            }
            `visit(child);
        }
    }

    `visit(body_node);
    return frozenset(names);
}

impl _ruby_const_last_name(`node, source: bytes) -> str {
    if `node is None {
        return "";
    }
    if `node.type == "constant" {
        return _read_text(`node, source);
    }
    if `node.type == "scope_resolution" {
        consts: any = [c for c in typing.cast(object, `node).children if c.type == "constant"];
        if consts {
            return _read_text(consts[-1], source);
        }
    }
    return "";
}

impl _ruby_const_full_name(`node, source: bytes) -> str {
    if `node is None or `node.type not in ("constant", "scope_resolution") {
        return "";
    }
    return _read_text(`node, source).strip();
}

impl _ruby_body_has_lookup_barrier(body_node, source: bytes) -> bool {
    method_scopes: any;
    method_scopes = {"method", "singleton_method"};

    def `visit(`node, *, direct: bool = False) -> bool {
        for child in typing.cast(object, `node).children {
            if child.type in {"class", "module"} {
                continue;
            }
            if child.type == "singleton_class" {
                if not direct {
                    return True;
                }
                continue;
            }
            if child.type in method_scopes {
                if not direct {
                    return True;
                }
                continue;
            }
            if child.type in {"alias", "undef"} {
                return True;
            }
            if child.type == "call" {
                receiver: any = child.child_by_field_name("receiver");
                method: any = child.child_by_field_name("method");
                if (receiver is None or _read_text(receiver, source) == "self")
                    and method is not None
                    and _read_text(method, source) in _RUBY_LOOKUP_MUTATORS
                {
                    return True;
                }
            }
            if `visit(child) {
                return True;
            }
        }
        return False;
    }

    return `visit(body_node, direct=True);
}

impl _ruby_file_has_refinement_barrier(root_node, source: bytes) -> bool {
    def `visit(`node) -> bool {
        if `node.type == "call" {
            method: any = `node.child_by_field_name("method");
            if method is not None and _read_text(method, source) in {"refine", "using"} {
                return True;
            }
        }
        return `any(`visit(child) for child in typing.cast(object, `node).children);
    }

    return `visit(root_node);
}

impl _ruby_external_method_owners(root_node, source: bytes) -> list[str] {
    owners: set[str];
    owners = set[any]();

    def constant_refs(`node) -> set[str] {
        if `node.type in {"constant", "scope_resolution"} {
            raw: any = _ruby_const_full_name(`node, source);
            return {raw} if raw else set[any]();
        }
        if `node.type not in {"left_assignment_list", "parenthesized_statements", "splat_argument"}
        {
            return set[any]();
        }
        refs: set[str] = set[any]();
        for child in typing.cast(object, `node).children {
            if child.is_named {
                refs.update(constant_refs(child));
            }
        }
        return refs;
    }

    def alias_rhs_refs(`node, *, allow_array: bool = False) -> set[str] {
        if `node.type in {"constant", "scope_resolution"} {
            raw: any = _ruby_const_full_name(`node, source);
            return {raw} if raw else set[any]();
        }
        if `node.type in {"parenthesized_statements", "right_assignment_list"}
            or allow_array and `node.type == "array"
        {
            refs: set[str] = set[any]();
            for child in typing.cast(object, `node).children {
                if child.is_named {
                    refs.update(alias_rhs_refs(child, allow_array=allow_array));
                }
            }
            return refs;
        }
        return set[any]();
    }

    def prefix_marker(raw: str) -> str {
        return f"{raw}::*";
    }

    def `visit(`node) {
        raw: any;
        if `node.type in {"assignment", "operator_assignment"} {
            left: any = `node.child_by_field_name("left");
            lhs_refs: any = constant_refs(left) if left is not None else set[any]();
            if lhs_refs {
                owners.update(prefix_marker(raw) for raw in lhs_refs);
            }
            right: any = `node.child_by_field_name("right");
            if `node.type == "assignment" and lhs_refs and right is not None {
                owners.update(
                    prefix_marker(raw)
                    for raw in alias_rhs_refs(
                        right,
                        allow_array=left is not None
                            and operator.eq(left.type, "left_assignment_list"),
                    ),
                );
            }
        }
        if `node.type in {"class", "module"} {
            name: any = `node.child_by_field_name("name");
            if name is not None and name.type == "scope_resolution" {
                raw = _ruby_const_full_name(name, source);
                if raw {
                    owners.add(raw);
                }
            }
        }
        if `node.type == "singleton_method" {
            owner: any = `node.child_by_field_name("object");
            if owner is not None and _read_text(owner, source) != "self" {
                raw = _ruby_const_full_name(owner, source);
                if raw {
                    owners.add(raw);
                }
            }
            return;
        }
        if `node.type == "singleton_class" {
            owner = `node.child_by_field_name("value");
            if owner is not None and _read_text(owner, source) != "self" {
                raw = _ruby_const_full_name(owner, source);
                if raw {
                    owners.add(raw);
                }
            }
        }
        if `node.type == "call" {
            receiver: any = `node.child_by_field_name("receiver");
            method: any = `node.child_by_field_name("method");
            if receiver is not None
                and receiver.type in {"constant", "scope_resolution"}
                and method is not None
                and _read_text(method, source) in _RUBY_EXTERNAL_OWNER_MUTATORS
            {
                raw = _ruby_const_full_name(receiver, source);
                if raw {
                    owners.add(raw);
                }
            }
        }
        if `node.type == "method" {
            return;
        }
        for child in typing.cast(object, `node).children {
            `visit(child);
        }
    }

    `visit(root_node);
    return sorted(owners);
}

impl _ruby_extra_walk(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    str_path: str,
    nodes: list,
    edges: list,
    seen_ids: set,
    function_bodies: list,
    parent_class_nid: str | None,
    add_node,
    add_edge,
    walk,
    callable_def_nids: set,
    callable_class_nids: set,
    ruby_namespace: list,
    ruby_lexical_scopes: list,
) -> bool {
    if `node.type != "assignment" {
        return False;
    }
    left: any = `node.child_by_field_name("left");
    right: any = `node.child_by_field_name("right");
    if left is None or right is None or left.type != "constant" or right.type != "call" {
        return False;
    }
    recv: any = right.child_by_field_name("receiver");
    meth: any = right.child_by_field_name("method");
    if recv is None or meth is None or recv.type != "constant" {
        return False;
    }
    if (_read_text(recv, source), _read_text(meth, source)) not in _RUBY_CLASS_FACTORIES {
        return False;
    }

    const_name: any = _read_text(left, source);
    if not const_name {
        return False;
    }
    const_segments: any = const_name.split("::");
    const_name = "::".join(ruby_namespace + const_segments);
    line: any = `node.start_point[0] + 1;
    class_nid: any = _make_id(stem, const_name);
    add_node(class_nid, const_name, line, metadata={"ruby_lookup_unsafe": True});
    callable_def_nids.add(class_nid);
    callable_class_nids.add(class_nid);
    add_edge(file_nid, class_nid, "contains", line);
    if _read_text(recv, source) == "Class" {
        args: any = next((c for c in typing.cast(object, right).children if c.type == "argument_list"), None);
        if args is not None {
            for arg in typing.cast(object, args).children {
                if arg.type in ("constant", "scope_resolution") {
                    base: any = _ruby_const_last_name(arg, source);
                    raw_base: any = _ruby_const_full_name(arg, source);
                    if base {
                        base_nid: any = _make_id(stem, base);
                        if base_nid not in seen_ids {
                            base_nid = _make_id(base);
                            if base_nid not in seen_ids {
                                nodes.append({
                                    "id": base_nid,
                                    "label": base,
                                    "file_type": "code",
                                    "source_file": "",
                                    "source_location": "",
                                    "origin_file": str_path,
                                });
                                seen_ids.add(base_nid);
                            }
                        }
                        add_edge(
                            class_nid,
                            base_nid,
                            "inherits",
                            line,
                            metadata={
                                "ruby_superclass_ref": raw_base,
                                "ruby_lexical_scopes": `list(reversed(ruby_lexical_scopes)),
                            },
                        );
                    }
                    break;
                }
            }
        }
    }
    block: any = next((c for c in typing.cast(object, right).children if c.type in ("do_block", "block")), None);
    if block is not None {
        body: any = next((c for c in typing.cast(object, block).children if c.type == "body_statement"), block);
        ruby_namespace.extend(const_segments);
        ruby_lexical_scopes.append(const_name);
        try {
            for child in typing.cast(object, body).children {
                walk(child, parent_class_nid=class_nid);
            }
        } finally {
            ruby_lexical_scopes.pop();
            del ruby_namespace[-len(const_segments):];
        }
    }
    return True;
}

impl _lua_is_require_call(`node, source: bytes) -> bool {
    name_node: any = `node.child_by_field_name("name");
    if name_node is None or name_node.type != "identifier" {
        return False;
    }
    return operator.eq(_read_text(name_node, source), "require");
}

impl _php_get_route_name(closure_node, src: bytes) -> str | None {
    prefixes: any = [];
    verb: any = None;

    curr: any = closure_node.parent;
    while curr is not None {
        if curr.type in ("function_definition", "method_declaration", "class_declaration") {
            break;
        }

        if curr.type == "argument" {
            arg_list: any = curr.parent;
            if arg_list is not None and arg_list.type == "arguments" {
                call: any = arg_list.parent;
                if call is not None
                    and call.type
                        in (
                            "member_call_expression",
                            "function_call_expression",
                            "scoped_call_expression",
                        )
                {
                    name_node: any = call.child_by_field_name("name");
                    if name_node is None {
                        name_node = call.child_by_field_name("function");
                    }

                    raw_method: any = (_read_text(name_node, src) if name_node else "").lower();
                    path_text: any = None;

                    for sibling in typing.cast(object, arg_list).children {
                        if sibling == curr {
                            break;
                        }

                        target: any = sibling;
                        if sibling.type == "argument" {
                            c: any;
                            for c in typing.cast(object, sibling).children {
                                if c.type in ("string", "encapsed_string") {
                                    target = c;
                                    break;
                                }
                            }
                        }

                        if target.type in ("string", "encapsed_string") {
                            path_text = _read_text(target, src).strip("'\"");
                            break;
                        }
                    }

                    if verb is None {
                        if path_text is not None
                            and path_text.startswith("/")
                            and raw_method in _PHP_ROUTING_VERBS
                        {
                            verb = raw_method.upper();
                            prefixes.append(path_text);
                        } else {
                            return None;
                        }
                    } elif path_text is not None and path_text {
                        prefixes.append(
                            path_text if path_text.startswith("/") else "/" + path_text
                        );
                    }
                    fluent: any = call.child_by_field_name("object");
                    while fluent is not None and fluent.type == "member_call_expression" {
                        f_args: any = fluent.child_by_field_name("arguments");
                        if f_args {
                            for c in typing.cast(object, f_args).children {
                                if c.type == "argument" {
                                    for cc in typing.cast(object, c).children {
                                        if cc.type in ("string", "encapsed_string") {
                                            f_path: any = _read_text(cc, src).strip("'\"");
                                            if f_path {
                                                prefixes.append(
                                                    f_path
                                                        if f_path.startswith("/")
                                                        else "/" + f_path,
                                                );
                                            }
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                        fluent = fluent.child_by_field_name("object");
                    }

                    curr = call.parent;
                    continue;
                }
            }
        } elif curr.type in ("anonymous_function", "arrow_function") {
            if verb is None {
                return None;
            }
            curr = curr.parent;
            continue;
        }

        curr = curr.parent;
    }

    if verb and prefixes {
        full_path: any = "/" + "/".join(p.strip("/") for p in reversed(prefixes) if p.strip("/"));
        return f"{verb} {full_path}";
    }

    return None;
}

impl _get_parser(ts_module: str, ts_language_fn: str) -> any {
    cache: any = getattr(_parser_tls, "parsers", None);
    if cache is None {
        cache = {};
        _parser_tls.parsers = cache;
    }
    key: any = (ts_module, ts_language_fn);
    `entry: any = cache.get(key);
    if `entry is None {
        `entry = _build_parser(ts_module, ts_language_fn);
        cache[key] = `entry;
    }
    return `entry;
}

impl _build_parser(ts_module: str, ts_language_fn: str) -> any {
    try {
        mod: any = importlib.import_module(ts_module);
        import from tree_sitter { Language, Parser }
        lang_fn: any = getattr(mod, ts_language_fn, None);
        if lang_fn is None {
            lang_fn = getattr(mod, "language", None);
        }
        if lang_fn is None {
            return (None, f"No language function in {ts_module}");
        }
        language: any = Language(lang_fn());
        return (Parser(language), None);
    } except ImportError {
        return (None, f"{ts_module} not installed");
    } except TypeError as e {
        return (
            None,
            f"tree-sitter version mismatch for {ts_module}: {e}. Try: pip install --upgrade tree-sitter tree-sitter-languages",
        );
    } except Exception as e {
        return (None, `str(e));
    }
}

impl _extract_generic(
    path: Path,
    config: LanguageConfig,
    *,
    source_override: bytes | None = None,
    scan_root: Path | None = None,
    preserve_call_sites: bool = False,
) -> dict {
    source: any;
    e: any;
    stem: any;
    str_path: any;
    dialect_type_quals: frozenset[str];
    js_external_imports: set[str];
    python_receiver_shadowed: any;
    python_param_shadowed: any;
    python_module_instances: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    namespace_stack: list[str];
    ruby_namespace: list[str];
    ruby_lexical_scopes: list[str];
    scope_stack: list[str];
    function_bodies: list[tuple[str, object]];
    callable_def_nids: set[str];
    callable_class_nids: set[str];
    cpp_qualified_names: dict[str, str];
    cpp_classes: dict[str, list];
    local_bound_names: dict[str, set[str]];
    scope_parents: dict[str, str];
    lexical_nids_by_scope: dict[str, dict[str, str]];
    closure_locals_by_body: dict[int, set[str]];
    js_receiver_bindings: dict;
    php_closure_counts: dict[str, int];
    pending_listen_edges: list[tuple[str, str, int]];
    swift_extensions: list[dict];
    initializer_nodes: list[tuple[str, object]];
    _ruby_mixin_calls: list[dict];
    ruby_singleton_context_depth: any;
    ruby_method_kinds: dict[str, set[str]];
    ruby_method_counts: dict[str, int];
    type_table: dict[str, str];
    swift_factory_bindings: dict[str, tuple[str, str]];
    java_field_types: dict[str, dict[str, str]];
    java_static_field_types: dict[str, dict[str, str]];
    java_field_names: dict[str, set[str]];
    java_return_types: dict[str, str];
    java_method_scopes: dict[int, tuple[object, str]];
    type_paths: dict[str, str];
    java_package: any;
    java_imports: list[str];
    csharp_field_types: dict[str, dict[str, str]];
    csharp_method_scopes: dict[int, tuple[object, str]];
    csharp_method_returns: dict[str, dict[str, list]];
    csharp_overloads: dict[str, dict[str, dict]];
    csharp_interface_names: set[str];
    csharp_type_groups: dict[str, set[str]];
    csharp_member_groups: dict[str, set[str]];
    csharp_member_ids: set[str];
    csharp_ctor_overloads: dict[str, dict[str, dict]];
    csharp_indexer_overloads: dict[str, dict[str, dict]];
    swift_protocol_names: set[str];
    swift_class_names: set[str];
    js_member_groups: dict;
    php_member_groups: dict;
    java_member_groups: dict;
    java_overloads: dict[str, dict[str, dict]];
    kotlin_member_groups: dict;
    swift_member_groups: dict;
    cpp_member_groups: dict;
    ruby_member_groups: dict;
    scala_member_groups: dict;
    python_underscore_groups: dict[str, set[str]];
    lua_field_groups: dict[str, set[str]];
    stem_forward_refs: dict[str, str];
    file_nid: any;
    decl_registry: any;
    csharp_ctor_records: list[dict];
    label_to_nid: dict[str, str];
    label_to_nid_ci: dict[str, str];
    nid_to_sf: dict[str, str];
    lua_self_table: dict[str, str];
    python_free_label_to_nid: dict[str, str];
    n: any;
    csharp_overload_peers: dict[str, list[dict]];
    seen_call_pairs: set[tuple[str, str]];
    seen_indirect_pairs: set[tuple[str, str]];
    seen_dyn_import_pairs: set[tuple[str, str]];
    seen_static_ref_pairs: set[tuple[str, str, str]];
    seen_helper_ref_pairs: set[tuple[str, str, str]];
    seen_bind_pairs: set[tuple[str, str, str]];
    raw_calls: list[dict];
    ruby_var_types: dict[str, dict[str, str | None]];
    python_var_types: dict[str, dict[str, str | None]];
    python_fixture_params: dict[str, set[str]];
    ruby_local_names: dict[str, frozenset[str]];
    _local_bases: dict[str, list[str]];
    method_owner: dict[str, str];
    methods_by_owner: dict[tuple[str, str], str];
    class_parent: dict[str, str];
    lexical_bases: dict[str, list[str]];
    lexical_calls: any;
    js_factory_scope: dict[str, str];
    kotlin_types_by_label: dict[str, list[str]];
    kotlin_methods_by_owner: dict[tuple[str, str], str];
    kotlin_callable_counts: dict[str, int];
    java_bound_names: dict[str, set[str]];
    _java_field_name_tables: any;
    body_id: any;
    method_node: any;
    class_nid: any;
    python_lambda_bindings: dict[int, tuple[str, set[str]]];
    _tracked_body_ids: set[object];
    _JS_DESCEND_TYPES: any;
    python_attr_types: dict[str, dict[str, str | None]];
    python_factory_bindings: dict[str, dict[str, list[int]]];
    cpp_local_bindings: dict[str, dict[str, list[tuple[int, int, str, str, str, bool]]]];
    cpp_unknown_fields: dict[str, set[str]];
    conflicting: set[str];
    module_bound: any;
    js_module_bound: any;
    _n: any;
    parser: any;
    parser_error: any;
    ts_mod = `str(config.ts_module);
    (parser, parser_error) = _get_parser(ts_mod, config.ts_language_fn) as any;
    if parser_error is not None {
        return {"nodes": [], "edges": [], "error": parser_error};
    }

    try {
        source = _read_source_bytes(path) if source_override is None else source_override;
        if ts_mod == "tree_sitter_cpp" {
            source = source.replace(b"\r\n", b"\n");
        }
        if source and not source.endswith(b"\n") {
            source = source + b"\n";
        }
        tree: any = parser.parse(source);
        `root: any = tree.root_node;
    } except Exception as e_ {
        return {"nodes": [], "edges": [], "error": `str(e_)};
    }

    stem = _file_stem(path);
    str_path = `str(path);
    dialect_type_quals = _CPP_DIALECT_TYPE_QUALIFIERS.get(path.suffix.lower(), frozenset());
    js_external_imports = _js_external_import_names(`root, source, str_path)
        if ts_mod in ("tree_sitter_javascript", "tree_sitter_typescript")
        else set[any]();
    python_receiver_shadowed = _python_receiver_shadow_checker(`root, source)
        if ts_mod == "tree_sitter_python"
        else None;
    python_param_shadowed = _python_param_shadow_checker(source)
        if ts_mod == "tree_sitter_python"
        else None;
    python_module_instances = _python_module_instance_types(`root, source)
        if ts_mod == "tree_sitter_python"
        else {};
    nodes = [];
    edges = [];
    seen_ids = set[any]();
    namespace_stack = [];
    ruby_namespace = [];
    ruby_lexical_scopes = [];
    scope_stack = [];
    function_bodies = [];
    callable_def_nids = set[any]();
    callable_class_nids = set[any]();
    cpp_qualified_names = {};
    cpp_classes = {};
    if ts_mod == "tree_sitter_cpp" {
        pending: any = [`root];
        while pending {
            current: any = pending.pop();
            if current.type in config.class_types {
                name: any = current.child_by_field_name("name");
                if name is not None {
                    cpp_classes.setdefault(normalize_id(_read_text(name, source)), []).append(
                        current
                    );
                }
            }
            pending.extend(current.named_children);
        }
    }
    local_bound_names = {};
    scope_parents = {};
    lexical_nids_by_scope = {};
    closure_locals_by_body = {};
    js_receiver_bindings = {};
    php_closure_counts = {};
    pending_listen_edges = [];
    swift_extensions = [];
    initializer_nodes = [];
    _ruby_mixin_calls = [];
    ruby_singleton_context_depth = 0;
    ruby_method_kinds = {};
    ruby_method_counts = {};
    type_table = {};
    swift_factory_bindings = {};
    java_field_types = {};
    java_static_field_types = {};
    java_field_names = {};
    java_return_types = {};
    java_method_scopes = {};
    type_paths = {};
    java_package = "";
    java_imports = [];
    if ts_mod == "tree_sitter_java" {
        for child in typing.cast(object, `root).children {
            if child.type == "package_declaration" {
                java_package = _read_text(child, source).removeprefix("package").strip().rstrip(
                    ";"
                ).strip();
            } elif child.type == "import_declaration" {
                imported: any = _read_text(child, source).removeprefix("import").strip().rstrip(
                    ";"
                ).strip();
                java_imports.append(imported.removeprefix("static ").strip());
            }
        }
    }
    csharp_field_types = {};
    csharp_method_scopes = {};
    csharp_method_returns = {};
    csharp_overloads = {};

    csharp_interface_names = set[any]();
    csharp_type_groups = {};
    csharp_member_groups = {};
    csharp_member_ids = set[any]();
    csharp_ctor_overloads = {};
    csharp_indexer_overloads = {};
    if ts_mod == "tree_sitter_c_sharp" {
        csharp_interface_names = _csharp_pre_scan_interfaces(`root, source);
        (
            csharp_type_groups,
            csharp_member_groups,
            csharp_member_ids,
        ) = _csharp_pre_scan_name_collisions(`root, source, stem) as any;
    }

    swift_protocol_names = set[any]();
    swift_class_names = set[any]();
    if ts_mod == "tree_sitter_swift" {
        (swift_protocol_names, swift_class_names) = _swift_pre_scan(`root, source) as any;
    }
    js_member_groups = {};
    php_member_groups = {};
    java_member_groups = {};
    java_overloads = {};
    kotlin_member_groups = {};
    swift_member_groups = {};
    cpp_member_groups = {};
    ruby_member_groups = {};
    scala_member_groups = {};

    python_underscore_groups = {};
    if ts_mod == "tree_sitter_python" {
        python_underscore_groups = _python_pre_scan_underscore_collisions(`root, source, stem);
    }
    lua_field_groups = {};
    if ts_mod == "tree_sitter_lua" {
        lua_field_groups = _lua_pre_scan_field_collisions(`root, source, stem);
    }

    def add_node(
        nid: str,
        label: str,
        line: int,
        *,
        node_type: str | None = None,
        metadata: dict | None = None,
    ) {
        if nid in seen_ids {
            return;
        }
        seen_ids.add(nid);
        merged: any = `dict(metadata or {});
        if namespace_stack {
            merged.setdefault("namespace", ".".join(namespace_stack));
        }
        if scope_stack and node_type != "namespace" {
            merged.setdefault("scope_chain", `list(scope_stack));
        }
        `node: any = {
            "id": nid,
            "label": label,
            "file_type": "code",
            "source_file": str_path,
            "source_location": f"L{line}",
        };
        if node_type {
            `node["type"] = node_type;
        }
        if merged {
            `node["metadata"] = sanitize_metadata(merged);
        }
        nodes.append(`node);
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
            `edge["metadata"] = sanitize_metadata(metadata);
        }
        edges.append(`edge);
    }

    def ensure_named_node(name: str, line: int) -> str {
        if isinstance(name, _CppStdName) {
            std_nid: any = _make_id("std", `str(name));
            if std_nid not in seen_ids {
                seen_ids.add(std_nid);
                nodes.append({
                    "id": std_nid,
                    "label": `str(name),
                    "file_type": "code",
                    "source_file": "",
                    "source_location": "",
                    "origin_file": str_path,
                    "_cpp_std": True,
                });
            }
            return std_nid;
        }
        declared: any = decl_registry.lookup(name);
        if declared is not None {
            return declared;
        }
        nid: any = _make_id(stem, ".".join(namespace_stack), name);
        if ts_mod == "tree_sitter_c_sharp" {
            nid = _underscore_salted_nid(nid, name, csharp_type_groups);
        } elif ts_mod == "tree_sitter_python" {
            nid = _underscore_salted_nid(nid, name, python_underscore_groups);
        }
        if nid in seen_ids and nid != file_nid {
            return nid;
        }
        nid = _make_id(name);
        if nid == _make_id(path.stem) {
            stem_forward_refs[nid] = _make_id(stem, name);
        }
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

    stem_forward_refs = {};
    file_nid = _make_id(`str(path));
    add_node(file_nid, path.name, 1);

    decl_registry = DeclIdRegistry(reserved_ids=(file_nid,));

    def _php_const_ref_target(cca) -> "str | None" {
        first: any = next((c for c in typing.cast(object, cca).children if c.is_named), None);
        if first is None or first.type not in ("name", "qualified_name") {
            return None;
        }
        name: any = _read_text(first, source);
        if first.type == "qualified_name" {
            name = name.rsplit("\\", 1)[-1];
        }
        declared: any = decl_registry.lookup(name);
        if declared is not None {
            return declared;
        }
        nid: any = _make_id(stem, ".".join(namespace_stack), name);
        return nid if nid in seen_ids and nid != file_nid else None;
    }

    def decl_node(nid: str, name: str, kind: str, label: str, line: int, **kwargs) -> str {
        resolved: any = decl_registry.resolve(nid, name, kind, seen_ids);
        add_node(resolved, label, line, **kwargs);
        return resolved;
    }
    if not source {
        next(n for n in nodes if n["id"] == file_nid)["source_location"] = None;
    }
    if ts_mod == "tree_sitter_ruby" {
        file_node: any = next(n for n in nodes if n["id"] == file_nid);
        file_metadata: any = {"ruby_resolution_schema": 1};
        if _ruby_body_has_lookup_barrier(`root, source)
            or _ruby_file_has_refinement_barrier(`root, source)
        {
            file_metadata["ruby_lookup_unsafe"] = True;
        }
        external_owners: any = _ruby_external_method_owners(`root, source);
        if external_owners {
            file_metadata["ruby_external_method_owners"] = external_owners;
        }
        file_node["metadata"] = sanitize_metadata(file_metadata);
    }
    csharp_ctor_records = [];
    def csharp_add_constructor(
        type_nid: str, type_name: str, decl, params, line: int, `static: bool
    ) -> str {
        signature: any;
        meta: any;
        (signature, meta) = _csharp_method_signature(decl, source, params) as any;
        if `static {
            (signature, meta) = ("static", {"arity": 0});
        }
        ctor_nid: any = _make_id(type_nid, type_name);
        if ctor_nid in csharp_member_ids {
            ctor_nid = _make_id(
                ctor_nid, hashlib.sha1(b".ctor", usedforsecurity=False).hexdigest()[:6]
            );
        }
        group: any = csharp_ctor_overloads.setdefault(ctor_nid, {});
        if group and signature not in group {
            ctor_nid = _make_id(
                ctor_nid,
                hashlib.sha1(signature.encode("utf-8"), usedforsecurity=False).hexdigest()[:6],
            );
        }
        add_node(
            ctor_nid,
            f".{type_name}()",
            line,
            metadata={**meta, "signature": signature, "kind": "constructor"},
        );
        if signature not in group and nodes and nodes[-1]["id"] == ctor_nid {
            group[signature] = nodes[-1];
        }
        add_edge(type_nid, ctor_nid, "method", line);
        return ctor_nid;
    }
    def csharp_queue_member_bodies(member_nid: str, decl, class_nid: str) {
        bodies: any = [];
        accessors: any = decl.child_by_field_name("accessors");
        if accessors is not None {
            for accessor in typing.cast(object, accessors).children {
                if accessor.type == "accessor_declaration" {
                    body: any = accessor.child_by_field_name("body");
                    if body is not None {
                        bodies.append(body);
                    }
                }
            }
        }
        value: any = decl.child_by_field_name("value");
        if value is not None and value.type == "arrow_expression_clause" {
            bodies.append(value);
        }
        for body in bodies {
            csharp_method_scopes[id(body)] = (decl, class_nid);
            function_bodies.append((member_nid, body));
        }
    }

    def walk(`node, parent_class_nid: str | None = None) {
        class_nid: any;
        c: any;
        getter_nid: any;
        member_nid: any;
        func_nid: any;
        p: any;
        t: any = `node.type;
        if ts_mod == "tree_sitter_lua"
            and t == "function_call"
            and config.import_handler
            and _lua_is_require_call(`node, source)
        {
            config.import_handler(`node, source, file_nid, stem, edges, str_path, scope_stack);
            return;
        }
        if t in config.import_types {
            if config.import_handler {
                if ts_mod == "tree_sitter_python" {
                    imported_modules: any = config.import_handler(
                        `node, source, file_nid, stem, edges, str_path, scope_stack, scan_root
                    );
                } else {
                    imported_modules = config.import_handler(
                        `node, source, file_nid, stem, edges, str_path, scope_stack
                    );
                }
                if imported_modules {
                    line: any = `node.start_point[0] + 1;
                    for (mod_nid, mod_label) in imported_modules {
                        if mod_nid not in seen_ids {
                            seen_ids.add(mod_nid);
                            nodes.append({
                                "id": mod_nid,
                                "label": mod_label,
                                "file_type": "code",
                                "type": "module",
                                "source_file": str_path,
                                "source_location": f"L{line}",
                            });
                        }
                    }
                }
            }
            if t == "export_statement" {
                has_source: any = `any(operator.eq(c.type, "string") for c in typing.cast(object, `node).children);
                if not has_source {
                    child: any;
                    for child in typing.cast(object, `node).children {
                        walk(child, parent_class_nid);
                    }
                }
            }
            return;
        }
        if t in config.class_types {
            name_node: any = `node.child_by_field_name(config.name_field);
            if name_node is None {
                for child in typing.cast(object, `node).children {
                    if child.type in config.name_fallback_child_types {
                        name_node = child;
                        break;
                    }
                }
            }
            synthetic_name: any = None;
            if not name_node {
                if ts_mod == "tree_sitter_scala" and t == "given_definition" {
                    synthetic_name = _scala_given_synthetic_name(`node, source);
                }
                if not synthetic_name {
                    return;
                }
            }
            class_name: any = synthetic_name or _read_text(name_node, source);
            ruby_absolute_declaration: any = operator.eq(ts_mod, "tree_sitter_ruby")
                and class_name.startswith("::");
            ruby_segments: list[str] = [];
            if ts_mod == "tree_sitter_ruby" {
                ruby_segments = class_name.split("::");
                class_name = "::".join(ruby_namespace + ruby_segments);
            }
            class_name_for_id: any = class_name;
            if ts_mod == "tree_sitter_c_sharp" {
                class_name_for_id = _csharp_type_name_for_id(`node, class_name);
            }
            class_nid = _make_id(stem, ".".join(namespace_stack), class_name_for_id);
            if parent_class_nid and ts_mod != "tree_sitter_ruby" {
                class_nid = _make_id(parent_class_nid, class_name_for_id);
            }
            if ts_mod == "tree_sitter_c_sharp" {
                class_nid = _underscore_salted_nid(class_nid, class_name, csharp_type_groups);
            }
            if ts_mod == "tree_sitter_python" and not parent_class_nid {
                class_nid = _underscore_salted_nid(class_nid, class_name, python_underscore_groups);
            }
            line = `node.start_point[0] + 1;
            metadata: any = None;
            ruby_reopened: any = operator.eq(ts_mod, "tree_sitter_ruby")
                and class_nid in seen_ids;
            if ts_mod == "tree_sitter_c_sharp" {
                if parent_class_nid {
                    metadata = {"is_nested_type": True};
                }
                if t
                    in (
                        "class_declaration",
                        "struct_declaration",
                        "interface_declaration",
                        "record_declaration",
                    )
                    and `any(
                        operator.eq(c.type, "modifier")
                            and operator.eq(_read_text(c, source), "partial")
                        for c in typing.cast(object, `node).children,
                    )
                {
                    partial_metadata: dict[str, object] = `dict(metadata or {});
                    partial_metadata["is_partial"] = True;
                    metadata = partial_metadata;
                }
            }
            if ts_mod == "tree_sitter_ruby" {
                ruby_body: any = _find_body(`node, config);
                if ruby_absolute_declaration
                    or ruby_reopened
                    or ruby_body is not None and _ruby_body_has_lookup_barrier(ruby_body, source)
                {
                    metadata = `dict(metadata or {});
                    if ruby_absolute_declaration {
                        metadata["ruby_lookup_unsafe"] = True;
                    }
                    if ruby_reopened {
                        metadata["ruby_reopened"] = True;
                    }
                    if ruby_body is not None and _ruby_body_has_lookup_barrier(ruby_body, source) {
                        metadata["ruby_lookup_unsafe"] = True;
                    }
                }
            }
            if ts_mod == "tree_sitter_python" {
                _py_bases: any = `node.child_by_field_name("superclasses");
                if _py_bases is not None
                    and `any(
                        c.is_named
                            and c.type not in ("keyword_argument", "comment")
                            and _python_base_name_node(c) is None
                        for c in typing.cast(object, _py_bases).children,
                    )
                {
                    metadata = `dict(metadata or {});
                    metadata["python_opaque_bases"] = True;
                }
            }
            class_nid = decl_node(
                class_nid, class_name, "type", class_name, line, metadata=metadata
            );
            parent_path: any = type_paths.get(parent_class_nid or "");
            type_path: any = f"{parent_path}.{class_name_for_id}"
                if parent_path and not ruby_segments
                else class_name_for_id;
            type_paths[class_nid] = type_path;
            class_node: any = next(n for n in nodes if n["id"] == class_nid);
            class_node["metadata"] = sanitize_metadata({
                **class_node.get("metadata", {}),
                "type_path": type_path,
            });
            if ts_mod == "tree_sitter_java" {
                class_node["_java_type"] = {
                    "path": type_path,
                    "package": java_package,
                    "imports": java_imports,
                };
            }
            if ts_mod == "tree_sitter_ruby" and metadata {
                class_node = next(n for n in nodes if n["id"] == class_nid);
                class_metadata: any = `dict(class_node.get("metadata") or {});
                class_metadata.update(metadata);
                class_node["metadata"] = sanitize_metadata(class_metadata);
            }
            callable_def_nids.add(class_nid);
            callable_class_nids.add(class_nid);
            if ts_mod == "tree_sitter_cpp" {
                qualified: any = _cpp_qualified_name(`node, class_name, source);
                cpp_qualified_names[class_nid] = qualified
                    if cpp_qualified_names.get(class_nid, qualified) == qualified
                    else "";
                class_node = next(n for n in nodes if n["id"] == class_nid);
                safe: any = t in {"class_specifier", "struct_specifier"}
                    and operator.eq(name_node.type, "type_identifier")
                    and `bool(qualified)
                    and not `node.has_error
                    and "_cpp_class_kind" not in class_node;
                parent: any = `node.parent;
                while parent is not None {
                    if parent.type.startswith("preproc_")
                        and not _cpp_is_header_guard(parent, source)
                        or parent.type in {
                            "template_declaration",
                            "function_definition",
                            "lambda_expression",
                            "class_specifier",
                            "struct_specifier",
                            "union_specifier",
                        }
                    {
                        safe = False;
                    }
                    parent = parent.parent;
                }
                class_node["_cpp_class_kind"] = (
                    "definition" if `node.child_by_field_name("body") is not None else "forward"
                )
                    if safe
                    else "unsafe";
                if `node.child_by_field_name("body") is not None {
                    class_node = next(n for n in nodes if n["id"] == class_nid);
                    class_node["_cpp_field_positions"] = {};
                    class_node["_cpp_fields"] = _cpp_class_fields(
                        `node, source, class_node["_cpp_field_positions"]
                    );
                    class_node["_cpp_lookup"] = _cpp_class_lookup_facts(`node, source);
                }
            }
            if parent_class_nid and parent_class_nid != class_nid {
                add_edge(parent_class_nid, class_nid, "contains", line);
            } else {
                add_edge(file_nid, class_nid, "contains", line);
            }
            if ts_mod == "tree_sitter_c_sharp" and t != "interface_declaration" {
                primary_params: any = next(
                    (c for c in typing.cast(object, `node).children if c.type == "parameter_list"), None
                );
                if primary_params is not None {
                    csharp_add_constructor(
                        class_nid, class_name, `node, primary_params, line, False
                    );
                }
            }
            if ts_mod in ("tree_sitter_javascript", "tree_sitter_typescript") {
                _ts_emit_decorator_edges(
                    `node, class_nid, stem, source, ensure_named_node, add_edge
                );
            }

            if ts_mod == "tree_sitter_swift"
                and `any(operator.eq(c.type, "extension") for c in typing.cast(object, `node).children)
            {
                swift_extensions.append({"nid": class_nid, "label": class_name});
            }
            if ts_mod == "tree_sitter_python" {
                args: any = `node.child_by_field_name("superclasses");
                if args {
                    arg: any;
                    for arg in typing.cast(object, args).children {
                        base_node: any = _python_base_name_node(arg);
                        if base_node is not None {
                            base: any = _read_text(base_node, source);
                            base_nid: any = ensure_named_node(base, line);
                            add_edge(class_nid, base_nid, "inherits", line);
                        }
                    }
                }
            }
            if ts_mod == "tree_sitter_swift" {
                swift_kind: any = _swift_declaration_keyword(`node)
                    if t == "class_declaration"
                    else "protocol";
                seen_swift_base: any = False;
                for child in typing.cast(object, `node).children {
                    if child.type != "inheritance_specifier" {
                        continue;
                    }
                    base_name: str | None = None;
                    user_type_node: any = None;
                    sub: any;
                    for sub in typing.cast(object, child).children {
                        if sub.type == "user_type" {
                            user_type_node = sub;
                            base_name = _swift_user_type_name(sub, source);
                            break;
                        }
                        if sub.type == "type_identifier" {
                            base_name = _read_text(sub, source) or None;
                            break;
                        }
                    }
                    if not base_name {
                        continue;
                    }
                    base_nid = _make_id(stem, base_name);
                    if base_nid not in seen_ids {
                        base_nid = _make_id(base_name);
                        if base_nid not in seen_ids {
                            nodes.append({
                                "id": base_nid,
                                "label": base_name,
                                "file_type": "code",
                                "source_file": "",
                                "source_location": "",
                            });
                            seen_ids.add(base_nid);
                        }
                    }
                    if t == "protocol_declaration" {
                        relation: any = "inherits";
                    } else {
                        relation = _swift_classify_base(
                            base_name,
                            swift_kind,
                            not seen_swift_base,
                            swift_protocol_names,
                            swift_class_names,
                        );
                    }
                    seen_swift_base = True;
                    add_edge(class_nid, base_nid, relation, line);
                    if user_type_node is not None {
                        arg_child: any;
                        for arg_child in typing.cast(object, user_type_node).children {
                            if arg_child.type != "type_arguments" {
                                continue;
                            }
                            for arg in typing.cast(object, arg_child).children {
                                if not arg.is_named {
                                    continue;
                                }
                                refs: list[tuple[str, str]] = [];
                                _swift_collect_type_refs(arg, source, True, refs);
                                ref_name: any;
                                _role: any;
                                for (ref_name, _role) in refs {
                                    target: any = ensure_named_node(ref_name, line);
                                    add_edge(
                                        class_nid, target, "references", line, context="generic_arg"
                                    );
                                }
                            }
                        }
                    }
                }
            }
            if ts_mod == "tree_sitter_php" {
                def _php_emit_base(base_name: str, rel: str, at_line: int) {
                    if not base_name {
                        return;
                    }
                    base_nid: any = _make_id(stem, base_name);
                    if base_nid not in seen_ids {
                        base_nid = _make_id(base_name);
                        if base_nid not in seen_ids {
                            nodes.append({
                                "id": base_nid,
                                "label": base_name,
                                "file_type": "code",
                                "source_file": "",
                                "source_location": "",
                            });
                            seen_ids.add(base_nid);
                        }
                    }
                    add_edge(class_nid, base_nid, rel, at_line);
                }

                for child in typing.cast(object, `node).children {
                    if child.type == "base_clause" {
                        for sub in typing.cast(object, child).children {
                            if sub.type in ("name", "qualified_name") {
                                _php_emit_base(
                                    _php_name_text(sub, source) or "",
                                    "inherits",
                                    child.start_point[0] + 1,
                                );
                            }
                        }
                    } elif child.type == "class_interface_clause" {
                        for sub in typing.cast(object, child).children {
                            if sub.type in ("name", "qualified_name") {
                                _php_emit_base(
                                    _php_name_text(sub, source) or "",
                                    "implements",
                                    child.start_point[0] + 1,
                                );
                            }
                        }
                    }
                }
                body: any = `node.child_by_field_name("body");
                if body is None {
                    for c in typing.cast(object, `node).children {
                        if c.type == "declaration_list" {
                            body = c;
                            break;
                        }
                    }
                }
                if body is not None {
                    member: any;
                    for member in typing.cast(object, body).children {
                        if member.type != "use_declaration" {
                            continue;
                        }
                        for sub in typing.cast(object, member).children {
                            if sub.type in ("name", "qualified_name") {
                                _php_emit_base(
                                    _php_name_text(sub, source) or "",
                                    "mixes_in",
                                    member.start_point[0] + 1,
                                );
                            }
                        }
                    }
                }
            }
            if ts_mod == "tree_sitter_kotlin" {
                for child in typing.cast(object, `node).children {
                    if child.type != "delegation_specifiers" {
                        continue;
                    }
                    spec: any;
                    for spec in typing.cast(object, child).children {
                        if spec.type != "delegation_specifier" {
                            continue;
                        }
                        relation = "implements";
                        user_type_node = None;
                        for sub in typing.cast(object, spec).children {
                            if sub.type == "constructor_invocation" {
                                relation = "inherits";
                                inner: any;
                                for inner in typing.cast(object, sub).children {
                                    if inner.type == "user_type" {
                                        user_type_node = inner;
                                        break;
                                    }
                                }
                                break;
                            }
                            if sub.type == "user_type" {
                                user_type_node = sub;
                                break;
                            }
                            if sub.type == "explicit_delegation" {
                                for inner in typing.cast(object, sub).children {
                                    if inner.type == "user_type" {
                                        user_type_node = inner;
                                        break;
                                    }
                                }
                                break;
                            }
                        }
                        if user_type_node is None {
                            continue;
                        }
                        base = _kotlin_user_type_name(user_type_node, source);
                        if not base {
                            continue;
                        }
                        base_nid = ensure_named_node(base, line);
                        add_edge(class_nid, base_nid, relation, line);
                        for arg_child in typing.cast(object, user_type_node).children {
                            if arg_child.type != "type_arguments" {
                                continue;
                            }
                            for arg in typing.cast(object, arg_child).children {
                                if arg.type == "type_projection" {
                                    for inner in typing.cast(object, arg).children {
                                        if not inner.is_named {
                                            continue;
                                        }
                                        refs = [];
                                        _kotlin_collect_type_refs(inner, source, True, refs);
                                        for (ref_name, _role) in refs {
                                            target = ensure_named_node(ref_name, line);
                                            add_edge(
                                                class_nid,
                                                target,
                                                "references",
                                                line,
                                                context="generic_arg",
                                            );
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                annotation_targets: set[str] = set[any]();
                anno_name: any;
                anno_raw: any;
                for (anno_name, anno_raw) in _kotlin_annotation_names(`node, source) {
                    target_nid: any = ensure_named_node(anno_name, line);
                    if target_nid != class_nid and target_nid not in annotation_targets {
                        add_edge(class_nid, target_nid, "references", line, context="attribute");
                        annotation_targets.add(target_nid);
                    }
                }
                for ref_name in _kotlin_annotation_class_literal_refs(`node, source) {
                    target_nid = ensure_named_node(ref_name, line);
                    if target_nid != class_nid and target_nid not in annotation_targets {
                        add_edge(class_nid, target_nid, "references", line, context="attribute");
                        annotation_targets.add(target_nid);
                    }
                }

                for c in typing.cast(object, `node).children {
                    if c.type == "primary_constructor" {
                        for cp_list in typing.cast(object, c).children {
                            if cp_list.type == "class_parameters" {
                                cp: any;
                                for cp in typing.cast(object, cp_list).children {
                                    if cp.type != "class_parameter" {
                                        continue;
                                    }
                                    has_val_var: any = False;
                                    for sub in typing.cast(object, cp).children {
                                        if sub.type in ("val", "var") {
                                            has_val_var = True;
                                            break;
                                        }
                                    }
                                    if not has_val_var {
                                        continue;
                                    }
                                    ptype: any = None;
                                    for sub in typing.cast(object, cp).children {
                                        if sub.type
                                            in ("user_type", "nullable_type", "type_reference")
                                        {
                                            ptype = sub;
                                            break;
                                        }
                                    }
                                    if ptype is not None {
                                        cp_line: any = cp.start_point[0] + 1;
                                        refs = [];
                                        _kotlin_collect_type_refs(ptype, source, False, refs);
                                        role: any;
                                        for (ref_name, role) in refs {
                                            ctx: any = "generic_arg"
                                                if role == "generic_arg"
                                                else "field";
                                            target_nid = ensure_named_node(ref_name, cp_line);
                                            if target_nid != class_nid {
                                                add_edge(
                                                    class_nid,
                                                    target_nid,
                                                    "references",
                                                    cp_line,
                                                    context=ctx,
                                                );
                                            }
                                        }
                                        param_annotation_targets: set[str] = set[any]();
                                        for (anno_name, anno_raw) in _kotlin_annotation_names(
                                            cp, source
                                        ) {
                                            target_nid = ensure_named_node(anno_name, cp_line);
                                            if target_nid != class_nid
                                                and target_nid not in param_annotation_targets
                                            {
                                                add_edge(
                                                    class_nid,
                                                    target_nid,
                                                    "references",
                                                    cp_line,
                                                    context="attribute",
                                                );
                                                param_annotation_targets.add(target_nid);
                                            }
                                        }
                                        for ref_name in _kotlin_annotation_class_literal_refs(
                                            cp, source
                                        ) {
                                            target_nid = ensure_named_node(ref_name, cp_line);
                                            if target_nid != class_nid
                                                and target_nid not in param_annotation_targets
                                            {
                                                add_edge(
                                                    class_nid,
                                                    target_nid,
                                                    "references",
                                                    cp_line,
                                                    context="attribute",
                                                );
                                                param_annotation_targets.add(target_nid);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if ts_mod == "tree_sitter_ruby" {
                sup: any = `node.child_by_field_name("superclass");
                if sup is not None {
                    base = "";
                    raw_base: any = "";
                    for sub in typing.cast(object, sup).children {
                        if sub.type == "constant" {
                            base = _read_text(sub, source);
                            raw_base = base;
                            break;
                        }
                        if sub.type == "scope_resolution" {
                            raw_base = _read_text(sub, source).strip();
                            consts: any = [c for c in typing.cast(object, sub).children if c.type == "constant"];
                            if consts {
                                base = _read_text(consts[-1], source);
                            }
                            break;
                        }
                    }
                    if base {
                        base_nid = ensure_named_node(base, line);
                        add_edge(
                            class_nid,
                            base_nid,
                            "inherits",
                            line,
                            metadata={
                                "ruby_superclass_ref": raw_base,
                                "ruby_lexical_scopes": `list(reversed(ruby_lexical_scopes)),
                            },
                        );
                    }
                }
                _rb_body: any = _find_body(`node, config);
                if _rb_body is not None {
                    _rb_mixin_stmts: any = `list(_rb_body.children);
                    for _sc in typing.cast(object, _rb_body).children {
                        if _sc.type != "singleton_class" {
                            continue;
                        }
                        _sc_value: any = _sc.child_by_field_name("value");
                        if _sc_value is None or _sc_value.type != "self" {
                            continue;
                        }
                        _sc_body: any = _sc.child_by_field_name("body");
                        if _sc_body is not None {
                            _rb_mixin_stmts.extend(_sc_body.children);
                        }
                    }
                    for _stmt in _rb_mixin_stmts {
                        if _stmt.type != "call"
                            or _stmt.child_by_field_name("receiver") is not None
                        {
                            continue;
                        }
                        _m: any = _stmt.child_by_field_name("method");
                        if _m is None
                            or _read_text(_m, source) not in ("include", "extend", "prepend")
                        {
                            continue;
                        }
                        _args: any = _stmt.child_by_field_name("arguments");
                        if _args is None {
                            continue;
                        }
                        for _arg in typing.cast(object, _args).children {
                            if _arg.type not in ("constant", "scope_resolution") {
                                continue;
                            }
                            _mod: any = _ruby_const_full_name(_arg, source);
                            if _mod {
                                _ruby_mixin_calls.append({
                                    "caller_nid": class_nid,
                                    "callee": _mod,
                                    "is_mixin": True,
                                    "source_file": str_path,
                                    "source_location": f"L{_stmt.start_point[0] + 1}",
                                });
                            }
                        }
                    }
                }
            }
            if ts_mod == "tree_sitter_c_sharp" {
                csharp_type_params: any = _csharp_type_parameters_in_scope(`node, source);
                for child in typing.cast(object, `node).children {
                    if child.type != "base_list" {
                        continue;
                    }
                    for sub in typing.cast(object, child).children {
                        if sub.type not in ("identifier", "generic_name", "qualified_name") {
                            continue;
                        }
                        base_info: any = _read_csharp_type_name(sub, source);
                        if base_info is None {
                            continue;
                        }
                        qualifier: any;
                        (base, qualified, qualifier) = base_info as any;
                        if not base or base in csharp_type_params {
                            continue;
                        }
                        base_arity: any = 0;
                        if sub.type == "generic_name" {
                            for _tal in typing.cast(object, sub).children {
                                if _tal.type != "type_argument_list" {
                                    continue;
                                }
                                base_arity = sum(1 for _a in typing.cast(object, _tal).children if _a.is_named);
                            }
                        }
                        base_nid = None;
                        if base_arity {
                            _arity_nid: any = _underscore_salted_nid(
                                _make_id(stem, ".".join(namespace_stack), f"{base}`{base_arity}"),
                                base,
                                csharp_type_groups,
                            );
                            if _arity_nid in seen_ids {
                                base_nid = _arity_nid;
                            }
                        }
                        if base_nid is None {
                            base_nid = _underscore_salted_nid(
                                _make_id(stem, ".".join(namespace_stack), base),
                                base,
                                csharp_type_groups,
                            );
                        }
                        if base_nid not in seen_ids {
                            base_nid = _make_id(base);
                            if base_nid not in seen_ids {
                                nodes.append({
                                    "id": base_nid,
                                    "label": base,
                                    "file_type": "code",
                                    "source_file": "",
                                    "source_location": "",
                                });
                                seen_ids.add(base_nid);
                            }
                        }
                        if t == "interface_declaration" {
                            relation = "inherits";
                        } else {
                            relation = _csharp_classify_base(base, csharp_interface_names);
                        }
                        metadata = {"ref_token": base};
                        if qualified {
                            metadata["qualified"] = True;
                        }
                        if qualifier {
                            metadata["ref_qualifier"] = qualifier;
                        }
                        add_edge(class_nid, base_nid, relation, line, metadata=metadata);
                        if sub.type == "generic_name" {
                            for tal in typing.cast(object, sub).children {
                                if tal.type != "type_argument_list" {
                                    continue;
                                }
                                for arg in typing.cast(object, tal).children {
                                    if not arg.is_named {
                                        continue;
                                    }
                                    refs = [];
                                    _csharp_collect_type_refs(
                                        arg, source, True, refs, csharp_type_params
                                    );
                                    ref_qualified: any;
                                    ref_qualifier: any;
                                    for (ref_name, _role, ref_qualified, ref_qualifier) in refs {
                                        target = ensure_named_node(ref_name, line);
                                        metadata = {"ref_token": ref_name};
                                        if ref_qualified {
                                            metadata["qualified"] = True;
                                        }
                                        if ref_qualifier {
                                            metadata["ref_qualifier"] = ref_qualifier;
                                        }
                                        add_edge(
                                            class_nid,
                                            target,
                                            "references",
                                            line,
                                            context="generic_arg",
                                            metadata=metadata,
                                        );
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if ts_mod in ("tree_sitter_java", "tree_sitter_groovy") {
                def _emit_java_parent(base_name: str, rel: str, at_line: int) {
                    if not base_name {
                        return;
                    }
                    base_nid: any = _make_id(stem, base_name);
                    if base_nid not in seen_ids {
                        base_nid = _make_id(base_name);
                        if base_nid not in seen_ids {
                            nodes.append({
                                "id": base_nid,
                                "label": base_name,
                                "file_type": "code",
                                "source_file": "",
                                "source_location": "",
                            });
                            seen_ids.add(base_nid);
                        }
                    }
                    add_edge(class_nid, base_nid, rel, at_line);
                }

                def _emit_java_parent_type(type_node, rel: str, at_line: int) {
                    refs: list[tuple[str, str]] = [];
                    _java_collect_type_refs(type_node, source, False, refs);
                    parent_emitted: any = False;
                    for (ref_name, role) in refs {
                        if role == "type" and not parent_emitted {
                            _emit_java_parent(ref_name, rel, at_line);
                            parent_emitted = True;
                        } elif role == "generic_arg" {
                            target_nid: any = ensure_named_node(ref_name, at_line);
                            if target_nid != class_nid {
                                add_edge(
                                    class_nid,
                                    target_nid,
                                    "references",
                                    at_line,
                                    context="generic_arg",
                                );
                            }
                        }
                    }
                }

                sup = `node.child_by_field_name("superclass");
                if sup is not None {
                    for sub in typing.cast(object, sup).children {
                        if sub.is_named {
                            _emit_java_parent_type(sub, "inherits", line);
                            break;
                        }
                    }
                }

                ifs: any = `node.child_by_field_name("interfaces");
                if ifs is not None {
                    for sub in typing.cast(object, ifs).children {
                        if sub.type == "type_list" {
                            tid: any;
                            for tid in typing.cast(object, sub).children {
                                if tid.is_named {
                                    _emit_java_parent_type(tid, "implements", line);
                                }
                            }
                        }
                    }
                }

                if t == "interface_declaration" {
                    for child in typing.cast(object, `node).children {
                        if child.type == "extends_interfaces" {
                            for sub in typing.cast(object, child).children {
                                if sub.type == "type_list" {
                                    for tid in typing.cast(object, sub).children {
                                        if tid.is_named {
                                            _emit_java_parent_type(tid, "inherits", line);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                annotation_targets = set[any]();
                for (anno_name, anno_raw) in _java_annotation_names(`node, source) {
                    if "." in anno_raw and ts_mod == "tree_sitter_java" {
                        anno_name = anno_raw;
                    }
                    target_nid = ensure_named_node(anno_name, line);
                    if target_nid != class_nid and target_nid not in annotation_targets {
                        add_edge(class_nid, target_nid, "references", line, context="attribute");
                        annotation_targets.add(target_nid);
                    }
                }
                for ref_name in _java_annotation_class_literal_refs(`node, source) {
                    target_nid = ensure_named_node(ref_name, line);
                    if target_nid != class_nid and target_nid not in annotation_targets {
                        add_edge(class_nid, target_nid, "references", line, context="attribute");
                        annotation_targets.add(target_nid);
                    }
                }

                if t == "record_declaration" {
                    components: any = `node.child_by_field_name("parameters");
                    if components is not None {
                        for component in typing.cast(object, components).children {
                            if component.type == "formal_parameter" {
                                type_node: any = component.child_by_field_name("type");
                            } elif component.type == "spread_parameter" {
                                type_node = next(
                                    (child
                                    for child in typing.cast(object, component).children
                                    if child.is_named
                                        and child.type not in ("modifiers", "variable_declarator")),
                                    None,
                                );
                            } else {
                                continue;
                            }
                            refs = [];
                            _java_collect_type_refs(type_node, source, False, refs);
                            component_line: any = component.start_point[0] + 1;
                            for (ref_name, role) in refs {
                                ctx = "generic_arg" if role == "generic_arg" else "field";
                                target_nid = ensure_named_node(ref_name, component_line);
                                if target_nid != class_nid {
                                    add_edge(
                                        class_nid,
                                        target_nid,
                                        "references",
                                        component_line,
                                        context=ctx,
                                    );
                                }
                            }
                        }
                    }
                }
            }
            if ts_mod == "tree_sitter_scala" {
                extend: any = `node.child_by_field_name("extend");
                if extend is None {
                    for c in typing.cast(object, `node).children {
                        if c.type == "extends_clause" {
                            extend = c;
                            break;
                        }
                    }
                }
                if extend is not None {
                    bases: list[tuple[str, int]] = [];

                    def scala_base_name(type_node) -> str | None {
                        if type_node.type == "type_identifier" {
                            return _read_text(type_node, source);
                        }
                        if type_node.type == "stable_type_identifier" {
                            tail: any = next(
                                (child
                                for child in reversed(type_node.children)
                                if child.type in ("type_identifier", "identifier")),
                                None,
                            );
                            return _read_text(tail, source) if tail is not None else None;
                        }
                        if type_node.type == "generic_type" {
                            base: any = type_node.child_by_field_name("type");
                            if base is None {
                                base = next(
                                    (child
                                    for child in typing.cast(object, type_node).children
                                    if child.type in ("type_identifier", "stable_type_identifier")),
                                    None,
                                );
                            }
                            return scala_base_name(base) if base is not None else None;
                        }
                        return None;
                    }

                    for c in typing.cast(object, extend).children {
                        base_name = scala_base_name(c);
                        if base_name is not None {
                            bases.append((base_name, c.start_point[0] + 1));
                        }
                    }
                    for (idx, (base_name, base_line)) in enumerate(bases) {
                        rel: any = "inherits" if idx == 0 else "mixes_in";
                        base_nid = ensure_named_node(base_name, base_line);
                        if base_nid != class_nid {
                            add_edge(class_nid, base_nid, rel, base_line);
                        }
                    }
                }
                for c in typing.cast(object, `node).children {
                    if c.type != "class_parameters" {
                        continue;
                    }
                    for cp in typing.cast(object, c).children {
                        if cp.type != "class_parameter" {
                            continue;
                        }
                        ptype = cp.child_by_field_name("type");
                        if ptype is None {
                            continue;
                        }
                        cp_line = cp.start_point[0] + 1;
                        refs = [];
                        _scala_collect_type_refs(ptype, source, False, refs);
                        for (ref_name, role) in refs {
                            ctx = "generic_arg" if role == "generic_arg" else "field";
                            target_nid = ensure_named_node(ref_name, cp_line);
                            if target_nid != class_nid {
                                add_edge(class_nid, target_nid, "references", cp_line, context=ctx);
                            }
                        }
                    }
                }
                for c in typing.cast(object, `node).children {
                    if c.type != "type_parameters" {
                        continue;
                    }
                    bound_refs: list[tuple[str, str]] = [];
                    _scala_collect_context_bounds(c, source, bound_refs);
                    for (ref_name, role) in bound_refs {
                        ctx = "generic_arg" if role == "generic_arg" else "type_bound";
                        target_nid = ensure_named_node(ref_name, line);
                        if target_nid != class_nid {
                            add_edge(class_nid, target_nid, "references", line, context=ctx);
                        }
                    }
                }
                derive: any = `node.child_by_field_name("derive");
                for d in derive.children_by_field_name("type") if derive is not None else [] {
                    tail: any = d
                        if d.type == "type_identifier"
                        else next(
                            (x for x in reversed(d.children) if x.type == "type_identifier"), None
                        );
                    if tail is None {
                        continue;
                    }
                    d_line: any = d.start_point[0] + 1;
                    target_nid = ensure_named_node(_read_text(tail, source), d_line);
                    if target_nid != class_nid {
                        add_edge(class_nid, target_nid, "references", d_line, context="derives");
                    }
                }
            }
            if ts_mod == "tree_sitter_c_sharp"
                and t in ("class_declaration", "record_declaration", "struct_declaration")
            {
                csharp_type_params = _csharp_type_parameters_in_scope(`node, source);
                for c in typing.cast(object, `node).children {
                    if c.type != "parameter_list" {
                        continue;
                    }
                    for param in typing.cast(object, c).children {
                        if param.type != "parameter" {
                            continue;
                        }
                        ptype = param.child_by_field_name("type");
                        if ptype is None {
                            continue;
                        }
                        pname: any = param.child_by_field_name("name");
                        p_line: any = param.start_point[0] + 1;
                        recv: any = _csharp_receiver_type_name(ptype, source);
                        if pname is not None and recv and recv not in csharp_type_params {
                            csharp_field_types.setdefault(class_nid, {})[_read_text(
                                pname, source
                            )] = recv;
                        }
                        refs = [];
                        _csharp_collect_type_refs(ptype, source, False, refs, csharp_type_params);
                        for (ref_name, role, qualified, qualifier) in refs {
                            ctx = "generic_arg" if role == "generic_arg" else "field";
                            target_nid = ensure_named_node(ref_name, p_line);
                            if target_nid != class_nid {
                                metadata = {"ref_token": ref_name};
                                if qualified {
                                    metadata["qualified"] = True;
                                }
                                if qualifier {
                                    metadata["ref_qualifier"] = qualifier;
                                }
                                add_edge(
                                    class_nid,
                                    target_nid,
                                    "references",
                                    p_line,
                                    context=ctx,
                                    metadata=metadata,
                                );
                            }
                        }
                    }
                }
            }
            if ts_mod == "tree_sitter_cpp" {
                for child in typing.cast(object, `node).children {
                    if child.type != "base_class_clause" {
                        continue;
                    }
                    for sub in typing.cast(object, child).children {
                        base = "";
                        template_args_node: any = None;
                        if sub.type == "type_identifier" {
                            base = _read_text(sub, source);
                        } elif sub.type == "qualified_identifier" {
                            tail = sub.child_by_field_name("name");
                            base = _read_text(tail, source) if tail else _read_text(sub, source);
                        } elif sub.type == "template_type" {
                            tname: any = sub.child_by_field_name("name");
                            base = _read_text(tname, source) if tname else _read_text(sub, source);
                            template_args_node = sub.child_by_field_name("arguments");
                        } else {
                            continue;
                        }
                        if not base {
                            continue;
                        }
                        base_nid = ensure_named_node(base, line);
                        add_edge(class_nid, base_nid, "inherits", line);
                        if template_args_node is not None {
                            arg_refs: list[tuple[str, str]] = [];
                            for arg in typing.cast(object, template_args_node).children {
                                if arg.is_named {
                                    _cpp_collect_type_refs(
                                        arg,
                                        source,
                                        True,
                                        arg_refs,
                                        dialect_quals=dialect_type_quals,
                                    );
                                }
                            }
                            for (ref_name, _role) in arg_refs {
                                target_nid = ensure_named_node(ref_name, line);
                                if target_nid != class_nid {
                                    add_edge(
                                        class_nid,
                                        target_nid,
                                        "references",
                                        line,
                                        context="generic_arg",
                                    );
                                }
                            }
                        }
                    }
                }
            }
            body = _find_body(`node, config);
            if body {
                ruby_namespace.extend(ruby_segments);
                if ts_mod == "tree_sitter_ruby" {
                    ruby_lexical_scopes.append(class_name);
                }
                previous_singleton_depth: any = ruby_singleton_context_depth;
                if ts_mod == "tree_sitter_ruby" {
                    ruby_singleton_context_depth = 0;
                }
                try {
                    for child in typing.cast(object, body).children {
                        walk(child, parent_class_nid=class_nid);
                    }
                } finally {
                    ruby_singleton_context_depth = previous_singleton_depth;
                    if ts_mod == "tree_sitter_ruby" {
                        ruby_lexical_scopes.pop();
                    }
                    if ruby_segments {
                        del ruby_namespace[-len(ruby_segments):];
                    }
                }
            }
            return;
        }
        if t == "property_declaration" and parent_class_nid and config.event_listener_properties {
            handled_event_listener: any = False;
            for element in typing.cast(object, `node).children {
                if element.type != "property_element" {
                    continue;
                }
                prop_name: str | None = None;
                array_node: any = None;
                for c in typing.cast(object, element).children {
                    if c.type == "variable_name" {
                        sc: any;
                        for sc in typing.cast(object, c).children {
                            if sc.type == "name" {
                                prop_name = _read_text(sc, source);
                                break;
                            }
                        }
                    } elif c.type == "array_creation_expression" {
                        array_node = c;
                    }
                }
                if prop_name is None
                    or prop_name not in config.event_listener_properties
                    or array_node is None
                {
                    continue;
                }
                handled_event_listener = True;
                for `entry in typing.cast(object, array_node).children {
                    if `entry.type != "array_element_initializer" {
                        continue;
                    }
                    event_cls: str | None = None;
                    listener_arr: any = None;
                    for sub in typing.cast(object, `entry).children {
                        if sub.type == "class_constant_access_expression" and event_cls is None {
                            for sc in typing.cast(object, sub).children {
                                if sc.is_named and sc.type in ("name", "qualified_name") {
                                    event_cls = _read_text(sc, source);
                                    break;
                                }
                            }
                        } elif sub.type == "array_creation_expression" {
                            listener_arr = sub;
                        }
                    }
                    if not event_cls or listener_arr is None {
                        continue;
                    }
                    for listener_entry in typing.cast(object, listener_arr).children {
                        if listener_entry.type != "array_element_initializer" {
                            continue;
                        }
                        for item in typing.cast(object, listener_entry).children {
                            if item.type != "class_constant_access_expression" {
                                continue;
                            }
                            for sc in typing.cast(object, item).children {
                                if sc.is_named and sc.type in ("name", "qualified_name") {
                                    listener_cls: any = _read_text(sc, source);
                                    line_no: any = item.start_point[0] + 1;
                                    pending_listen_edges.append((event_cls, listener_cls, line_no));
                                    break;
                                }
                            }
                            break;
                        }
                    }
                }
            }
            if handled_event_listener {
                return;
            }
        }

        if ts_mod == "tree_sitter_c_sharp"
            and t == "constructor_declaration"
            and parent_class_nid
        {
            ctor_name_node: any = `node.child_by_field_name("name");
            ctor_name: any = _read_text(ctor_name_node, source)
                if ctor_name_node is not None
                else "";
            if ctor_name {
                ctor_line: any = `node.start_point[0] + 1;
                ctor_nid: any = csharp_add_constructor(
                    parent_class_nid,
                    ctor_name,
                    `node,
                    None,
                    ctor_line,
                    `any(
                        operator.eq(c.type, "modifier")
                            and operator.eq(_read_text(c, source), "static")
                        for c in typing.cast(object, `node).children,
                    ),
                );
                for part in typing.cast(object, `node).children {
                    if part.type == "constructor_initializer" {
                        csharp_method_scopes[id(part)] = (`node, parent_class_nid);
                        function_bodies.append((ctor_nid, part));
                        keyword: any = next(
                            (c.type for c in typing.cast(object, part).children if c.type in ("base", "this")), None
                        );
                        if keyword is not None {
                            csharp_ctor_records.append({
                                "caller_nid": ctor_nid,
                                "lang": "csharp",
                                "csharp_ctor_init": keyword,
                                "arity": _csharp_creation_argc(part),
                                "source_file": str_path,
                                "source_location": f"L{part.start_point[0] + 1}",
                            });
                        }
                    }
                }
                ctor_body: any = `node.child_by_field_name("body");
                if ctor_body is not None {
                    csharp_method_scopes[id(ctor_body)] = (`node, parent_class_nid);
                    function_bodies.append((ctor_nid, ctor_body));
                }
            }
        }

        if ts_mod == "tree_sitter_c_sharp"
            and t == "indexer_declaration"
            and parent_class_nid
        {
            signature: any;
            meta: any;
            (signature, meta) = _csharp_method_signature(`node, source) as any;
            explicit: any = next(
                (c for c in typing.cast(object, `node).children if c.type == "explicit_interface_specifier"), None
            );
            if explicit is not None {
                signature = "".join(_read_text(explicit, source).split()) + signature;
            }
            indexer_line: any = `node.start_point[0] + 1;
            indexer_nid: any = _make_id(parent_class_nid, "this");
            if indexer_nid in csharp_member_ids {
                indexer_nid = _make_id(
                    indexer_nid, hashlib.sha1(b"this[]", usedforsecurity=False).hexdigest()[:6]
                );
            }
            group: any = csharp_indexer_overloads.setdefault(indexer_nid, {});
            if group and signature not in group {
                indexer_nid = _make_id(
                    indexer_nid,
                    hashlib.sha1(signature.encode("utf-8"), usedforsecurity=False).hexdigest()[:6],
                );
            }
            add_node(
                indexer_nid,
                "this[]",
                indexer_line,
                metadata={**meta, "signature": signature, "kind": "indexer"},
            );
            if signature not in group and nodes and nodes[-1]["id"] == indexer_nid {
                group[signature] = nodes[-1];
            }
            add_edge(parent_class_nid, indexer_nid, "defines", indexer_line, context="field");
            csharp_queue_member_bodies(indexer_nid, `node, parent_class_nid);
            return;
        }

        if ts_mod == "tree_sitter_c_sharp"
            and t in ("operator_declaration", "conversion_operator_declaration")
            and parent_class_nid
        {
            if t == "operator_declaration" {
                op: any = `node.child_by_field_name("operator");
                op_name: any = "operator " + (_read_text(op, source) if op is not None else "");
                op_key: any = op_name;
            } else {
                to_type: any = `node.child_by_field_name("type");
                op_name = "operator "
                    + ("".join(_read_text(to_type, source).split()) if to_type is not None else "");
                direction: any = next(
                    (c.type for c in `node.children if c.type in ("implicit", "explicit")), ""
                );
                op_key = f"{direction} {op_name}";
            }
            (signature, meta) = _csharp_method_signature(`node, source) as any;
            signature = f"{op_key}:{signature}";
            op_line: any = `node.start_point[0] + 1;
            op_nid: any = _make_id(
                parent_class_nid,
                "operator",
                hashlib.sha1(signature.encode("utf-8"), usedforsecurity=False).hexdigest()[:6],
            );
            add_node(
                op_nid,
                f".{op_name}()",
                op_line,
                metadata={**meta, "signature": signature, "kind": "operator"},
            );
            add_edge(parent_class_nid, op_nid, "method", op_line);
            op_body: any = `node.child_by_field_name("body");
            if op_body is not None {
                csharp_method_scopes[id(op_body)] = (`node, parent_class_nid);
                function_bodies.append((op_nid, op_body));
            }
            return;
        }

        if ts_mod == "tree_sitter_c_sharp"
            and t == "field_declaration"
            and parent_class_nid
        {
            type_node = `node.child_by_field_name("type");
            if type_node is None {
                for child in typing.cast(object, `node).children {
                    if child.type == "variable_declaration" {
                        type_node = child.child_by_field_name("type");
                        if type_node is not None {
                            break;
                        }
                    }
                }
            }
            type_info: any = _read_csharp_type_name(type_node, source);
            if type_info {
                type_name: any;
                (type_name, qualified, qualifier) = type_info as any;
                csharp_type_params = _csharp_type_parameters_in_scope(
                    type_node if type_node is not None else `node, source
                );
                if not type_name or type_name in csharp_type_params {
                    return;
                }
                if type_name {
                    fields: any = csharp_field_types.setdefault(parent_class_nid, {});
                    elem_type: any = _csharp_element_type_name(type_node, source);
                    loop_elems: any = _csharp_loop_element_types(type_node, source);
                    for child in typing.cast(object, `node).children {
                        if child.type != "variable_declaration" {
                            continue;
                        }
                        declarator: any;
                        for declarator in typing.cast(object, child).children {
                            if declarator.type != "variable_declarator" {
                                continue;
                            }
                            name_node = declarator.child_by_field_name("name")
                                or next(
                                    (g for g in typing.cast(object, declarator).children if g.type == "identifier"), None
                                );
                            if name_node is not None {
                                fields[_read_text(name_node, source)] = type_name;
                                if elem_type {
                                    fields[_read_text(name_node, source) + "[]"] = elem_type;
                                }
                                suffix: any;
                                loop_elem: any;
                                for (suffix, loop_elem) in loop_elems.items() {
                                    fields[_read_text(name_node, source)
                                        + suffix
                                        + "{}"] = loop_elem;
                                }
                            }
                        }
                    }
                }
                line = `node.start_point[0] + 1;
                refs = [];
                _csharp_collect_type_refs(type_node, source, False, refs, csharp_type_params);
                for (ref_name, role, ref_qualified, ref_qualifier) in refs {
                    ctx = "generic_arg" if role == "generic_arg" else "field";
                    target_nid = ensure_named_node(ref_name, line);
                    if target_nid != parent_class_nid {
                        metadata = {"ref_token": ref_name};
                        if ref_qualified {
                            metadata["qualified"] = True;
                        }
                        if ref_qualifier {
                            metadata["ref_qualifier"] = ref_qualifier;
                        }
                        add_edge(
                            parent_class_nid,
                            target_nid,
                            "references",
                            line,
                            context=ctx,
                            metadata=metadata,
                        );
                    }
                }
            }
            return;
        }

        if ts_mod == "tree_sitter_c_sharp"
            and t == "property_declaration"
            and parent_class_nid
        {
            prop_node_name: any = `node.child_by_field_name("name");
            if prop_node_name is not None {
                property_name: any = _read_text(prop_node_name, source);
                if property_name {
                    property_line: any = `node.start_point[0] + 1;
                    property_nid: any = _underscore_salted_nid(
                        _make_id(parent_class_nid, property_name),
                        property_name,
                        csharp_member_groups,
                    );
                    if property_nid not in seen_ids {
                        add_node(property_nid, property_name, property_line);
                        add_edge(
                            parent_class_nid,
                            property_nid,
                            "defines",
                            property_line,
                            context="field",
                        );
                        csharp_queue_member_bodies(property_nid, `node, parent_class_nid);
                    }
                }
            }
            type_node = `node.child_by_field_name("type");
            if type_node is not None {
                prop_name_node: any = `node.child_by_field_name("name");
                prop_type: str | None = _csharp_receiver_type_name(type_node, source);
                if prop_name_node is not None and prop_type {
                    csharp_field_types.setdefault(parent_class_nid, {})[_read_text(
                        prop_name_node, source
                    )] = prop_type;
                    prop_elem: any = _csharp_element_type_name(type_node, source);
                    if prop_elem {
                        csharp_field_types[parent_class_nid][_read_text(prop_name_node, source)
                            + "[]"] = prop_elem;
                    }
                    for (suffix, loop_elem) in _csharp_loop_element_types(
                        type_node, source
                    ).items() {
                        csharp_field_types[parent_class_nid][_read_text(prop_name_node, source)
                            + suffix
                            + "{}"] = loop_elem;
                    }
                }
                line = `node.start_point[0] + 1;
                refs = [];
                _csharp_collect_type_refs(type_node, source, False, refs);
                for (ref_name, role, qualified, qualifier) in refs {
                    ctx = "generic_arg" if role == "generic_arg" else "field";
                    target_nid = ensure_named_node(ref_name, line);
                    if target_nid != parent_class_nid {
                        metadata = {"ref_token": ref_name};
                        if qualified {
                            metadata["qualified"] = True;
                        }
                        if qualifier {
                            metadata["ref_qualifier"] = qualifier;
                        }
                        add_edge(
                            parent_class_nid,
                            target_nid,
                            "references",
                            line,
                            context=ctx,
                            metadata=metadata,
                        );
                    }
                }
            }
            return;
        }

        if ts_mod == "tree_sitter_java"
            and t == "field_declaration"
            and parent_class_nid
        {
            field_names: any = _java_declarator_names(`node, source);
            java_field_names.setdefault(parent_class_nid, set[any]()).update(field_names);
            type_node = `node.child_by_field_name("type");
            if type_node is not None {
                receiver_type: any = _java_receiver_type_name(type_node, source);
                if receiver_type {
                    fields = java_field_types.setdefault(parent_class_nid, {});
                    field_name: any;
                    for field_name in field_names {
                        fields[field_name] = receiver_type;
                    }
                    if _java_has_modifier(`node, "static") {
                        static_fields: any = java_static_field_types.setdefault(
                            parent_class_nid, {}
                        );
                        for field_name in field_names {
                            static_fields[field_name] = receiver_type;
                        }
                    }
                }
                for `getter in _java_lombok_getters(`node, source) {
                    getter_nid = _make_id(parent_class_nid, `getter);
                    if `any(operator.eq(n["id"], getter_nid) for n in nodes) {
                        continue;
                    }
                    getter_line: any = `node.start_point[0] + 1;
                    add_node(
                        getter_nid,
                        f".{`getter}()",
                        getter_line,
                        metadata={"arity": 0, "signature": "", "lombok": "Getter"},
                    );
                    add_edge(parent_class_nid, getter_nid, "method", getter_line);
                    java_return_types[getter_nid] = receiver_type;
                }
                line = `node.start_point[0] + 1;
                refs = [];
                _java_collect_type_refs(type_node, source, False, refs);
                for (ref_name, role) in refs {
                    ctx = "generic_arg" if role == "generic_arg" else "field";
                    target_nid = ensure_named_node(ref_name, line);
                    if target_nid != parent_class_nid {
                        add_edge(parent_class_nid, target_nid, "references", line, context=ctx);
                    }
                }
            }
            return;
        }

        if ts_mod == "tree_sitter_java"
            and t == "annotation_type_element_declaration"
            and parent_class_nid
        {
            type_node = `node.child_by_field_name("type");
            line = `node.start_point[0] + 1;
            refs = [];
            _java_collect_type_refs(type_node, source, False, refs, preserve_qualified=True);
            for (ref_name, role) in refs {
                ctx = "generic_arg" if role == "generic_arg" else "return_type";
                target_nid = ensure_named_node(ref_name, line);
                if target_nid != parent_class_nid {
                    add_edge(parent_class_nid, target_nid, "references", line, context=ctx);
                }
            }
            return;
        }

        if ts_mod == "tree_sitter_php"
            and parent_class_nid
            and t in ("const_declaration", "property_declaration")
        {
            seen_here: set[str] = set[any]();
            stack: any = `list(`node.children);
            while stack {
                sub = stack.pop();
                if sub.type == "class_constant_access_expression" {
                    tgt: any = _php_const_ref_target(sub);
                    if tgt is not None and tgt != parent_class_nid and tgt not in seen_here {
                        seen_here.add(tgt);
                        add_edge(
                            parent_class_nid, tgt, "references_constant", sub.start_point[0] + 1
                        );
                    }
                }
                stack.extend(sub.children);
            }
        }

        if ts_mod == "tree_sitter_php"
            and t == "property_declaration"
            and parent_class_nid
        {
            for c in typing.cast(object, `node).children {
                if c.type
                    not in (
                        "named_type",
                        "primitive_type",
                        "nullable_type",
                        "union_type",
                        "intersection_type",
                        "optional_type",
                    )
                {
                    continue;
                }
                line = `node.start_point[0] + 1;
                refs = [];
                _php_collect_type_refs(c, source, False, refs);
                for (ref_name, role) in refs {
                    ctx = "generic_arg" if role == "generic_arg" else "field";
                    target_nid = ensure_named_node(ref_name, line);
                    if target_nid != parent_class_nid {
                        add_edge(parent_class_nid, target_nid, "references", line, context=ctx);
                    }
                }
                break;
            }
            return;
        }

        if ts_mod == "tree_sitter_kotlin" and t == "anonymous_initializer" {
            initializer_nodes.append((parent_class_nid or file_nid, `node));
            return;
        }

        if ts_mod == "tree_sitter_kotlin" and t == "property_declaration" {
            if parent_class_nid {
                line = `node.start_point[0] + 1;
                type_node = _kotlin_property_type_node(`node);
                if type_node is not None {
                    refs = [];
                    _kotlin_collect_type_refs(type_node, source, False, refs);
                    for (ref_name, role) in refs {
                        ctx = "generic_arg" if role == "generic_arg" else "field";
                        target_nid = ensure_named_node(ref_name, line);
                        if target_nid != parent_class_nid {
                            add_edge(parent_class_nid, target_nid, "references", line, context=ctx);
                        }
                    }
                }
                annotation_targets = set[any]();
                for (anno_name, anno_raw) in _kotlin_annotation_names(`node, source) {
                    target_nid = ensure_named_node(anno_name, line);
                    if target_nid != parent_class_nid and target_nid not in annotation_targets {
                        add_edge(
                            parent_class_nid, target_nid, "references", line, context="attribute"
                        );
                        annotation_targets.add(target_nid);
                    }
                }
                for ref_name in _kotlin_annotation_class_literal_refs(`node, source) {
                    target_nid = ensure_named_node(ref_name, line);
                    if target_nid != parent_class_nid and target_nid not in annotation_targets {
                        add_edge(
                            parent_class_nid, target_nid, "references", line, context="attribute"
                        );
                        annotation_targets.add(target_nid);
                    }
                }
            }
            owner_nid: any = parent_class_nid or file_nid;
            seen_eq: any = False;
            for child in typing.cast(object, `node).children {
                if not child.is_named {
                    seen_eq = seen_eq or operator.eq(child.type, "=");
                    continue;
                }
                if seen_eq {
                    initializer_nodes.append((owner_nid, child));
                } elif child.type == "property_delegate" {
                    for sub in typing.cast(object, child).children {
                        if sub.is_named {
                            initializer_nodes.append((owner_nid, sub));
                        }
                    }
                }
            }
            return;
        }

        if ts_mod == "tree_sitter_swift"
            and t == "property_declaration"
            and parent_class_nid
        {
            line = `node.start_point[0] + 1;
            prop_type = None;
            type_anno: any = _swift_property_type_node(`node);
            if type_anno is not None {
                prop_type = _swift_receiver_type_name(type_anno, source);
                refs = [];
                _swift_collect_type_refs(type_anno, source, False, refs);
                for (ref_name, role) in refs {
                    ctx = "generic_arg" if role == "generic_arg" else "field";
                    target_nid = ensure_named_node(ref_name, line);
                    if target_nid != parent_class_nid {
                        add_edge(parent_class_nid, target_nid, "references", line, context=ctx);
                    }
                    if prop_type is None and role == "type" {
                        prop_type = ref_name;
                    }
                }
            }
            pending_factory: tuple[str, str] | None = None;
            for child in typing.cast(object, `node).children {
                if child.type in config.call_types {
                    initializer_nodes.append((parent_class_nid, child));
                    if prop_type is None {
                        ctor: any = _swift_constructor_type(child, source);
                        if ctor is not None {
                            prop_type = ctor;
                        } else {
                            pending_factory = _swift_factory_call(child, source);
                        }
                    }
                } elif child.type == "navigation_expression" and prop_type is None {
                    head: any = child.children[0] if child.children else None;
                    if head is not None and head.type == "simple_identifier" {
                        htext: any = _read_text(head, source);
                        if htext and htext[:1].isupper() {
                            prop_type = htext;
                        }
                    }
                }
            }
            if prop_type is None {
                prop_type = _swift_attribute_type_name(`node, source);
            }
            prop_name = _swift_property_name(`node, source);
            if prop_name and prop_type {
                type_table[prop_name] = prop_type;
            } elif prop_name
                and pending_factory is not None
                and prop_name not in swift_factory_bindings
            {
                swift_factory_bindings[prop_name] = pending_factory;
            }
            comp_bodies: any = [
                c
                for c in typing.cast(object, `node).children
                if c.type in ("computed_property", "willset_didset_block")
            ];
            if comp_bodies and prop_name {
                prop_nid: any = _make_id(parent_class_nid, prop_name);
                add_node(prop_nid, f".{prop_name}", line);
                add_edge(parent_class_nid, prop_nid, "method", line);
                for body_block in comp_bodies {
                    function_bodies.append((prop_nid, body_block));
                }
            }
            return;
        }

        if ts_mod == "tree_sitter_scala"
            and t in ("val_definition", "var_definition", "type_definition")
        {
            owner_nid = parent_class_nid or file_nid;
            type_node = `node.child_by_field_name("type");
            if type_node is not None {
                line = `node.start_point[0] + 1;
                refs = [];
                _scala_collect_type_refs(type_node, source, False, refs);
                for (ref_name, role) in refs {
                    ctx = "generic_arg" if role == "generic_arg" else "field";
                    target_nid = ensure_named_node(ref_name, line);
                    if target_nid != owner_nid {
                        add_edge(owner_nid, target_nid, "references", line, context=ctx);
                    }
                }
            }
        }
        if ts_mod == "tree_sitter_scala" and t == "self_type" and parent_class_nid {
            named: any = [c for c in typing.cast(object, `node).children if c.is_named];
            type_node = named[1] if len(named) >= 2 else None;
            if type_node is not None {
                line = `node.start_point[0] + 1;
                refs = [];
                _scala_collect_type_refs(type_node, source, False, refs);
                for (ref_name, role) in refs {
                    target_nid = ensure_named_node(ref_name, line);
                    if target_nid != parent_class_nid {
                        add_edge(parent_class_nid, target_nid, "requires", line);
                    }
                }
            }
            return;
        }

        if ts_mod == "tree_sitter_cpp"
            and (
                t == "field_declaration"
                or t == "declaration"
                    and `node.parent is not None
                    and `node.parent.type == "template_declaration"
            )
            and parent_class_nid
        {
            decls: any = `list(`node.children_by_field_name("declarator"));
            is_method: any = `any(
                operator.eq(d.type, "function_declarator")
                    or d.type in ("pointer_declarator", "reference_declarator")
                        and `any(operator.eq(c.type, "function_declarator") for c in typing.cast(object, d).children)
                for d in decls,
            );
            type_node = `node.child_by_field_name("type");
            is_nested_type: any = type_node is not None
                and type_node.type in config.class_types
                and type_node.child_by_field_name("body") is not None;
            if is_nested_type {
                walk(type_node, parent_class_nid);
            }
            if not is_method and not is_nested_type {
                if type_node is not None {
                    line = `node.start_point[0] + 1;
                    refs = [];
                    _cpp_collect_type_refs(
                        type_node, source, False, refs, dialect_quals=dialect_type_quals
                    );
                    for (ref_name, role) in refs {
                        ctx = "generic_arg" if role == "generic_arg" else "field";
                        target_nid = ensure_named_node(ref_name, line);
                        if target_nid != parent_class_nid {
                            add_edge(parent_class_nid, target_nid, "references", line, context=ctx);
                        }
                    }
                }
            }
            decl: any;
            for decl in decls {
                name: any = _get_cpp_func_name(decl, source);
                if not name {
                    continue;
                }
                line = decl.start_point[0] + 1;
                member_nid = _make_id(parent_class_nid, name);
                decl_is_method: any = _cpp_is_method_declarator(decl);
                if decl_is_method {
                    member_nid = _cpp_member_nid(
                        parent_class_nid, `node, name, source, cpp_member_groups
                    );
                    add_node(member_nid, f".{name}()", line);
                    add_edge(parent_class_nid, member_nid, "method", line);
                    callable_def_nids.add(member_nid);
                    cpp_qualified_names[member_nid] = _cpp_qualified_name(`node, name, source);
                    member_node: any = next(n for n in nodes if n["id"] == member_nid);
                    member_node.setdefault("_cpp_member_records", []).append(
                        _cpp_member_record(`node, decl, name, source)
                    );
                } else {
                    add_node(member_nid, name, line);
                    add_edge(parent_class_nid, member_nid, "defines", line, context="field");
                }
            }
            return;
        }
        if ts_mod == "tree_sitter_ruby" and t == "singleton_class" and parent_class_nid {
            value: any = `node.child_by_field_name("value");
            body = `node.child_by_field_name("body");
            if value is not None and _read_text(value, source) == "self" and body {
                if _ruby_body_has_lookup_barrier(body, source) {
                    class_node = next(n for n in nodes if n["id"] == parent_class_nid);
                    class_metadata = `dict(class_node.get("metadata") or {});
                    class_metadata["ruby_lookup_unsafe"] = True;
                    class_node["metadata"] = sanitize_metadata(class_metadata);
                }
                ruby_singleton_context_depth += 1;
                try {
                    for child in typing.cast(object, body).children {
                        walk(child, parent_class_nid=parent_class_nid);
                    }
                } finally {
                    ruby_singleton_context_depth -= 1;
                }
                return;
            }
        }
        if t in config.function_types {
            if t == "deinit_declaration" {
                func_name: str | None = "deinit";
            } elif t == "subscript_declaration" {
                func_name = "subscript";
            } elif config.resolve_function_name_fn is not None {
                declarator = `node.child_by_field_name("declarator");
                func_name = None;
                if declarator {
                    func_name = config.resolve_function_name_fn(declarator, source);
                }
            } else {
                name_node = `node.child_by_field_name(config.name_field);
                if name_node is None {
                    for child in typing.cast(object, `node).children {
                        if child.type in config.name_fallback_child_types {
                            name_node = child;
                            break;
                        }
                    }
                }
                func_name = _read_text(name_node, source) if name_node else None;
            }

            if not func_name {
                if ts_mod == "tree_sitter_php"
                    and t in ("anonymous_function", "arrow_function")
                {
                    route_name: any = _php_get_route_name(`node, source);
                    if route_name {
                        func_name = route_name;
                    } else {
                        _scope_key: any = parent_class_nid or stem;
                        php_closure_counts[_scope_key] = php_closure_counts.get(_scope_key, 0) + 1;
                        func_name = "{closure#" + `str(php_closure_counts[_scope_key]) + "}";
                    }
                } else {
                    return;
                }
            }
            if ts_mod == "tree_sitter_cpp" and "<" in func_name {
                primary_name: any = _cpp_primary_template_function_name(`node, source, cpp_classes);
                primary_qualified: any = _cpp_qualified_name(`node, primary_name, source)
                    if primary_name
                    else "";
                if primary_name is not None
                    and primary_qualified
                    and cpp_qualified_names.get(_make_id(stem, primary_name)) == primary_qualified
                {
                    func_name = primary_name;
                }
            }
            sanitized_name: any = config.sanitize_symbol_name_fn(func_name)
                if config.sanitize_symbol_name_fn is not None
                else func_name;
            if not normalize_id(sanitized_name) {
                return;
            }

            line = `node.start_point[0] + 1;
            ruby_method_kind: any = None;
            if ts_mod == "tree_sitter_ruby" and parent_class_nid {
                if t == "singleton_method" {
                    singleton_object: any = `node.child_by_field_name("object");
                    if ruby_singleton_context_depth == 0
                        and singleton_object is not None
                        and _read_text(singleton_object, source) == "self"
                    {
                        ruby_method_kind = "singleton";
                    } else {
                        ruby_method_kind = "ambiguous";
                    }
                } elif ruby_singleton_context_depth == 1 {
                    ruby_method_kind = "singleton";
                } elif ruby_singleton_context_depth == 0 {
                    ruby_method_kind = "instance";
                } else {
                    ruby_method_kind = "ambiguous";
                }
            }
            if parent_class_nid {
                func_nid = _make_id(parent_class_nid, sanitized_name);
                if ts_mod == "tree_sitter_python" {
                    func_nid = _underscore_salted_nid(
                        func_nid, sanitized_name, python_underscore_groups
                    );
                } elif ts_mod == "tree_sitter_c_sharp" {
                    func_nid = _underscore_salted_nid(
                        func_nid, sanitized_name, csharp_member_groups
                    );
                    if t == "method_declaration" {
                        csharp_sig: any;
                        csharp_sig_meta: any;
                        (csharp_sig, csharp_sig_meta) = _csharp_method_signature(
                            `node, source
                        ) as any;
                        csharp_group_key: any = csharp_sig;
                        explicit = next(
                            (c for c in typing.cast(object, `node).children if c.type == "explicit_interface_specifier"),
                            None,
                        );
                        if explicit is not None {
                            explicit_text: any = "".join(_read_text(explicit, source).split());
                            csharp_group_key = explicit_text + csharp_sig;
                            csharp_sig_meta = {
                                **csharp_sig_meta,
                                "explicit_interface": _csharp_explicit_interface_name(
                                    explicit_text
                                ),
                            };
                        }
                        group = csharp_overloads.setdefault(func_nid, {});
                        if explicit is not None or group and csharp_group_key not in group {
                            salt: any = hashlib.sha1(
                                csharp_group_key.encode("utf-8"), usedforsecurity=False
                            ).hexdigest()[:6];
                            func_nid = _make_id(func_nid, salt);
                        }
                    }
                } elif ts_mod in ("tree_sitter_javascript", "tree_sitter_typescript")
                    and t in _JS_MEMBER_METHOD_TYPES
                {
                    func_nid = _js_member_nid(
                        parent_class_nid, `node, sanitized_name, source, js_member_groups
                    );
                } elif ts_mod == "tree_sitter_php" and t == "method_declaration" {
                    func_nid = _php_member_nid(
                        parent_class_nid, `node, sanitized_name, source, php_member_groups
                    );
                } elif ts_mod == "tree_sitter_java" and t in _JAVA_MEMBER_CALLABLE_TYPES {
                    func_nid = _java_member_nid(
                        parent_class_nid, `node, sanitized_name, source, java_member_groups
                    );
                    if t == "method_declaration" {
                        java_sig: any;
                        java_sig_meta: any;
                        (java_sig, java_sig_meta) = _java_method_signature(`node, source) as any;
                        java_group: any = java_overloads.setdefault(func_nid, {});
                        if java_group and java_sig not in java_group {
                            salt = hashlib.sha1(
                                java_sig.encode("utf-8"), usedforsecurity=False
                            ).hexdigest()[:6];
                            func_nid = _make_id(func_nid, salt);
                        }
                    }
                } elif ts_mod == "tree_sitter_kotlin" and t == "function_declaration" {
                    func_nid = _kotlin_member_nid(
                        parent_class_nid, `node, sanitized_name, source, kotlin_member_groups
                    );
                } elif ts_mod == "tree_sitter_swift"
                    and t in _SWIFT_MEMBER_CALLABLE_TYPES
                {
                    func_nid = _swift_member_nid(
                        parent_class_nid, `node, sanitized_name, source, swift_member_groups
                    );
                } elif ts_mod == "tree_sitter_cpp" and t == "function_definition" {
                    func_nid = _cpp_member_nid(
                        parent_class_nid, `node, sanitized_name, source, cpp_member_groups
                    );
                } elif ts_mod == "tree_sitter_ruby" and t in _RUBY_MEMBER_CALLABLE_TYPES {
                    func_nid = _ruby_member_nid(
                        parent_class_nid,
                        `node,
                        sanitized_name,
                        source,
                        ruby_member_groups,
                        config.sanitize_symbol_name_fn or (lambda (n) -> any { n }),
                    );
                } elif ts_mod == "tree_sitter_scala"
                    and t in _SCALA_MEMBER_CALLABLE_TYPES
                {
                    func_nid = _scala_member_nid(
                        parent_class_nid, `node, sanitized_name, source, scala_member_groups
                    );
                }
                ruby_method_metadata: any = None;
                if ruby_method_kind is not None {
                    kinds: any = ruby_method_kinds.setdefault(func_nid, set[any]());
                    kinds.add(ruby_method_kind);
                    ruby_method_counts[func_nid] = ruby_method_counts.get(func_nid, 0) + 1;
                    stored_kind: any = next(iter(kinds))
                        if len(kinds) == 1
                            and ruby_method_counts[func_nid] == 1
                            and next(iter(kinds)) in {"instance", "singleton"}
                        else "ambiguous";
                    ruby_method_metadata = {"ruby_method_kind": stored_kind};
                    existing_method: any = next((n for n in nodes if n["id"] == func_nid), None);
                    if existing_method is not None {
                        existing_metadata: any = `dict(existing_method.get("metadata") or {});
                        existing_metadata.update(ruby_method_metadata);
                        existing_method["metadata"] = sanitize_metadata(existing_metadata);
                    }
                }
                method_metadata: any = ruby_method_metadata;
                if ts_mod == "tree_sitter_c_sharp" and t == "method_declaration" {
                    method_metadata = {**csharp_sig_meta, "signature": csharp_sig};
                } elif ts_mod == "tree_sitter_java" and t == "method_declaration" {
                    method_metadata = {**java_sig_meta, "signature": java_sig};
                }
                add_node(func_nid, f".{func_name}()", line, metadata=method_metadata);
                if ts_mod == "tree_sitter_c_sharp"
                    and t == "method_declaration"
                    and explicit is None
                    and csharp_group_key not in group
                    and nodes
                    and nodes[-1]["id"] == func_nid
                {
                    group[csharp_group_key] = nodes[-1];
                }
                if ts_mod == "tree_sitter_java"
                    and t == "method_declaration"
                    and java_sig not in java_group
                    and nodes
                    and nodes[-1]["id"] == func_nid
                {
                    java_group[java_sig] = nodes[-1];
                }
                add_edge(parent_class_nid, func_nid, "method", line);
                if ts_mod == "tree_sitter_c_sharp" and t == "method_declaration" {
                    csharp_method_returns.setdefault(parent_class_nid, {}).setdefault(
                        func_name, []
                    ).append(_csharp_return_info(`node, source));
                }
            } else {
                func_nid = _make_id(stem, sanitized_name);
                if ts_mod == "tree_sitter_python" {
                    func_nid = _underscore_salted_nid(
                        func_nid, sanitized_name, python_underscore_groups
                    );
                } elif lua_field_groups and func_nid in lua_field_groups {
                    func_nid = _underscore_salted_nid(
                        func_nid,
                        _lua_field_name(sanitized_name),
                        lua_field_groups,
                        leaf=_lua_field_leaf,
                    );
                }
                if ts_mod == "tree_sitter_cpp"
                    and "::" in func_name
                    and cpp_qualified_names.get(func_nid)
                        != _cpp_qualified_name(`node, func_name, source)
                {
                    leaf: any = func_name.rsplit("::", 1)[1];
                    salted_nid: any = _make_id(
                        func_nid,
                        hashlib.sha1(leaf.encode("utf-8"), usedforsecurity=False).hexdigest()[:6],
                    );
                    if cpp_qualified_names.get(salted_nid)
                        == _cpp_qualified_name(`node, func_name, source)
                    {
                        func_nid = salted_nid;
                    }
                }
                if not (
                    ts_mod == "tree_sitter_cpp"
                    and "::" in func_name
                    and cpp_qualified_names.get(func_nid)
                        == _cpp_qualified_name(`node, func_name, source)
                ) {
                    func_nid = decl_node(func_nid, sanitized_name, "fn", f"{func_name}()", line);
                }
                add_edge(file_nid, func_nid, "contains", line);
            }
            callable_def_nids.add(func_nid);
            if ts_mod == "tree_sitter_cpp" and (parent_class_nid or "::" in func_name) {
                qualified = _cpp_qualified_name(`node, func_name, source);
                cpp_qualified_names[func_nid] = qualified
                    if cpp_qualified_names.get(func_nid, qualified) == qualified
                    else "";
                member_node = next(n for n in nodes if n["id"] == func_nid);
                member_node.setdefault("_cpp_member_records", []).append(
                    _cpp_member_record(`node, declarator, func_name, source)
                );
            }
            if ts_mod == "tree_sitter_python" {
                local_bound_names[func_nid] = _python_local_bound_names(`node, source);
            } elif ts_mod in ("tree_sitter_javascript", "tree_sitter_typescript") {
                local_bound_names[func_nid] = _js_local_bound_names(`node, source);
            }

            if ts_mod == "tree_sitter_python" {
                params_node: any = `node.child_by_field_name("parameters");
                for (ref_name, role) in _python_collect_param_refs(params_node, source) {
                    ctx = "generic_arg" if role == "generic_arg" else "parameter_type";
                    target_nid = ensure_named_node(ref_name, line);
                    if target_nid != func_nid {
                        edges.append(
                            _semantic_reference_edge(func_nid, target_nid, ctx, str_path, line)
                        );
                    }
                }
                return_type_node: any = `node.child_by_field_name("return_type");
                if return_type_node is not None {
                    return_refs: list[tuple[str, str]] = [];
                    _python_collect_type_refs(return_type_node, source, False, return_refs);
                    for (ref_name, role) in return_refs {
                        ctx = "generic_arg" if role == "generic_arg" else "return_type";
                        target_nid = ensure_named_node(ref_name, line);
                        if target_nid != func_nid {
                            edges.append(
                                _semantic_reference_edge(func_nid, target_nid, ctx, str_path, line)
                            );
                        }
                    }
                }
            }

            if ts_mod == "tree_sitter_c_sharp" {
                csharp_type_params = _csharp_type_parameters_in_scope(`node, source);
                params_node = `node.child_by_field_name("parameters");
                if params_node is not None {
                    type_nodes: any = [
                        p.child_by_field_name("type")
                        for p in typing.cast(object, params_node).children
                        if p.type == "parameter"
                    ];
                    type_nodes.append(params_node.child_by_field_name("type"));
                    for type_node in type_nodes {
                        refs = [];
                        _csharp_collect_type_refs(
                            type_node, source, False, refs, csharp_type_params
                        );
                        for (ref_name, role, qualified, qualifier) in refs {
                            ctx = "generic_arg" if role == "generic_arg" else "parameter_type";
                            target_nid = ensure_named_node(ref_name, line);
                            if target_nid != func_nid {
                                metadata = {"ref_token": ref_name};
                                if qualified {
                                    metadata["qualified"] = True;
                                }
                                if qualifier {
                                    metadata["ref_qualifier"] = qualifier;
                                }
                                add_edge(
                                    func_nid,
                                    target_nid,
                                    "references",
                                    line,
                                    context=ctx,
                                    metadata=metadata,
                                );
                            }
                        }
                    }
                }
                return_node: any = `node.child_by_field_name("returns");
                if return_node is not None {
                    refs = [];
                    _csharp_collect_type_refs(return_node, source, False, refs, csharp_type_params);
                    for (ref_name, role, qualified, qualifier) in refs {
                        ctx = "generic_arg" if role == "generic_arg" else "return_type";
                        target_nid = ensure_named_node(ref_name, line);
                        if target_nid != func_nid {
                            metadata = {"ref_token": ref_name};
                            if qualified {
                                metadata["qualified"] = True;
                            }
                            if qualifier {
                                metadata["ref_qualifier"] = qualifier;
                            }
                            add_edge(
                                func_nid,
                                target_nid,
                                "references",
                                line,
                                context=ctx,
                                metadata=metadata,
                            );
                        }
                    }
                }
                for (attr_name, qualified, qualifier) in _csharp_attribute_names(`node, source) {
                    target_nid = ensure_named_node(attr_name, line);
                    if target_nid != func_nid {
                        metadata = {"ref_token": attr_name};
                        if qualified {
                            metadata["qualified"] = True;
                        }
                        if qualifier {
                            metadata["ref_qualifier"] = qualifier;
                        }
                        add_edge(
                            func_nid,
                            target_nid,
                            "references",
                            line,
                            context="attribute",
                            metadata=metadata,
                        );
                    }
                }
            }

            if ts_mod == "tree_sitter_java" {
                params_node = `node.child_by_field_name("parameters");
                if params_node is not None {
                    for p in typing.cast(object, params_node).children {
                        if p.type == "formal_parameter" {
                            type_node = p.child_by_field_name("type");
                        } elif p.type == "spread_parameter" {
                            type_node = next(
                                (c
                                for c in typing.cast(object, p).children
                                if c.is_named
                                    and c.type not in ("modifiers", "variable_declarator")),
                                None,
                            );
                        } else {
                            continue;
                        }
                        refs = [];
                        _java_collect_type_refs(type_node, source, False, refs);
                        for (ref_name, role) in refs {
                            ctx = "generic_arg" if role == "generic_arg" else "parameter_type";
                            target_nid = ensure_named_node(ref_name, line);
                            if target_nid != func_nid {
                                add_edge(func_nid, target_nid, "references", line, context=ctx);
                            }
                        }
                    }
                }
                return_node = `node.child_by_field_name("type");
                if return_node is not None {
                    refs = [];
                    _java_collect_type_refs(return_node, source, False, refs);
                    for (ref_name, role) in refs {
                        ctx = "generic_arg" if role == "generic_arg" else "return_type";
                        target_nid = ensure_named_node(ref_name, line);
                        if target_nid != func_nid {
                            add_edge(func_nid, target_nid, "references", line, context=ctx);
                        }
                    }
                }
                annotation_targets = set[any]();
                for (anno_name, anno_raw) in _java_annotation_names(`node, source) {
                    target_nid = ensure_named_node(
                        anno_raw if "." in anno_raw else anno_name, line
                    );
                    if target_nid != func_nid and target_nid not in annotation_targets {
                        add_edge(func_nid, target_nid, "references", line, context="attribute");
                        annotation_targets.add(target_nid);
                    }
                }
                for ref_name in _java_annotation_class_literal_refs(`node, source) {
                    target_nid = ensure_named_node(ref_name, line);
                    if target_nid != func_nid and target_nid not in annotation_targets {
                        add_edge(func_nid, target_nid, "references", line, context="attribute");
                        annotation_targets.add(target_nid);
                    }
                }
            }

            if ts_mod == "tree_sitter_php" {
                params_container: any = None;
                for c in typing.cast(object, `node).children {
                    if c.type == "formal_parameters" {
                        params_container = c;
                        break;
                    }
                }
                if params_container is not None {
                    for p in typing.cast(object, params_container).children {
                        if p.type
                            not in (
                                "simple_parameter",
                                "property_promotion_parameter",
                                "variadic_parameter",
                            )
                        {
                            continue;
                        }
                        is_promoted: any = operator.eq(p.type, "property_promotion_parameter");
                        type_node = None;
                        for sub in typing.cast(object, p).children {
                            if sub.type
                                in (
                                    "named_type",
                                    "primitive_type",
                                    "nullable_type",
                                    "union_type",
                                    "intersection_type",
                                    "optional_type",
                                )
                            {
                                type_node = sub;
                                break;
                            }
                        }
                        refs = [];
                        _php_collect_type_refs(type_node, source, False, refs);
                        for (ref_name, role) in refs {
                            ctx = "generic_arg" if role == "generic_arg" else "parameter_type";
                            target_nid = ensure_named_node(ref_name, line);
                            if target_nid != func_nid {
                                add_edge(func_nid, target_nid, "references", line, context=ctx);
                            }
                            if is_promoted and parent_class_nid and target_nid != parent_class_nid {
                                fctx: any = "generic_arg" if role == "generic_arg" else "field";
                                add_edge(
                                    parent_class_nid, target_nid, "references", line, context=fctx
                                );
                            }
                        }
                        const_src: any = parent_class_nid or func_nid;
                        seen_param: set[str] = set[any]();
                        pstack: any = `list(p.children);
                        while pstack {
                            psub: any = pstack.pop();
                            if psub.type == "class_constant_access_expression" {
                                ptgt: any = _php_const_ref_target(psub);
                                if ptgt is not None
                                    and ptgt != const_src
                                    and ptgt not in seen_param
                                {
                                    seen_param.add(ptgt);
                                    add_edge(
                                        const_src,
                                        ptgt,
                                        "references_constant",
                                        psub.start_point[0] + 1,
                                    );
                                }
                            }
                            pstack.extend(psub.children);
                        }
                    }
                }
                return_node = _php_method_return_type_node(`node);
                if return_node is not None {
                    refs = [];
                    _php_collect_type_refs(return_node, source, False, refs);
                    for (ref_name, role) in refs {
                        ctx = "generic_arg" if role == "generic_arg" else "return_type";
                        target_nid = ensure_named_node(ref_name, line);
                        if target_nid != func_nid {
                            add_edge(func_nid, target_nid, "references", line, context=ctx);
                        }
                    }
                }
            }

            if ts_mod == "tree_sitter_kotlin" {
                params_container = None;
                for c in typing.cast(object, `node).children {
                    if c.type == "function_value_parameters" {
                        params_container = c;
                        break;
                    }
                }
                if params_container is not None {
                    for p in typing.cast(object, params_container).children {
                        if p.type != "parameter" {
                            continue;
                        }
                        param_type_node: any = None;
                        for sub in typing.cast(object, p).children {
                            if sub.type in ("user_type", "nullable_type", "type_reference") {
                                param_type_node = sub;
                                break;
                            }
                        }
                        refs = [];
                        _kotlin_collect_type_refs(param_type_node, source, False, refs);
                        for (ref_name, role) in refs {
                            ctx = "generic_arg" if role == "generic_arg" else "parameter_type";
                            target_nid = ensure_named_node(ref_name, line);
                            if target_nid != func_nid {
                                add_edge(func_nid, target_nid, "references", line, context=ctx);
                            }
                        }
                    }
                }
                return_type_node = _kotlin_function_return_type_node(`node);
                if return_type_node is not None {
                    refs = [];
                    _kotlin_collect_type_refs(return_type_node, source, False, refs);
                    for (ref_name, role) in refs {
                        ctx = "generic_arg" if role == "generic_arg" else "return_type";
                        target_nid = ensure_named_node(ref_name, line);
                        if target_nid != func_nid {
                            add_edge(func_nid, target_nid, "references", line, context=ctx);
                        }
                    }
                }
                annotation_targets = set[any]();
                for (anno_name, anno_raw) in _kotlin_annotation_names(`node, source) {
                    target_nid = ensure_named_node(anno_name, line);
                    if target_nid != func_nid and target_nid not in annotation_targets {
                        add_edge(func_nid, target_nid, "references", line, context="attribute");
                        annotation_targets.add(target_nid);
                    }
                }
            }

            if ts_mod == "tree_sitter_swift" {
                for p in typing.cast(object, `node).children {
                    if p.type != "parameter" {
                        continue;
                    }
                    type_node = p.child_by_field_name("type");
                    refs = [];
                    _swift_collect_type_refs(type_node, source, False, refs);
                    param_type: any = _swift_receiver_type_name(type_node, source);
                    for (ref_name, role) in refs {
                        ctx = "generic_arg" if role == "generic_arg" else "parameter_type";
                        target_nid = ensure_named_node(ref_name, line);
                        if target_nid != func_nid {
                            add_edge(func_nid, target_nid, "references", line, context=ctx);
                        }
                        if param_type is None and role == "type" {
                            param_type = ref_name;
                        }
                    }
                    if param_type {
                        name_node = p.child_by_field_name("name");
                        pname = _read_text(name_node, source) if name_node else None;
                        if pname {
                            type_table[pname] = param_type;
                        }
                    }
                }
                return_node = `node.child_by_field_name("return_type");
                if return_node is not None {
                    refs = [];
                    _swift_collect_type_refs(return_node, source, False, refs);
                    plain_return: any = operator.eq(return_node.type, "user_type")
                        and operator.eq(sum(1 for (_, r) in refs if r == "type"), 1);
                    for (ref_name, role) in refs {
                        ctx = "generic_arg" if role == "generic_arg" else "return_type";
                        target_nid = ensure_named_node(ref_name, line);
                        if target_nid != func_nid {
                            add_edge(
                                func_nid,
                                target_nid,
                                "references",
                                line,
                                context=ctx,
                                metadata={"swift_plain_return": True}
                                    if plain_return and role == "type"
                                    else None,
                            );
                        }
                    }
                }
            }

            if ts_mod in ("tree_sitter_javascript", "tree_sitter_typescript")
                and func_name == "constructor"
            {
                params_node = `node.child_by_field_name("parameters");
                if params_node is not None {
                    for p in typing.cast(object, params_node).children {
                        if p.type != "required_parameter" {
                            continue;
                        }
                        has_modifier: any = `any(
                            c.type in ("accessibility_modifier", "readonly") for c in typing.cast(object, p).children
                        );
                        if not has_modifier {
                            continue;
                        }
                        name_n: any = p.child_by_field_name("pattern");
                        type_n: any = p.child_by_field_name("type");
                        if name_n is None or type_n is None {
                            continue;
                        }
                        pname = _read_text(name_n, source);
                        for tc in typing.cast(object, type_n).children {
                            if tc.type == "type_identifier" {
                                ptype = _read_text(tc, source);
                                if pname and ptype {
                                    type_table[pname] = ptype;
                                }
                                break;
                            }
                        }
                    }
                }
            }

            if ts_mod in ("tree_sitter_c", "tree_sitter_cpp") {
                if ts_mod == "tree_sitter_cpp" {
                    def collect(`node, source: bytes, generic: bool, out: list[tuple[str, str]]) {
                        _cpp_collect_type_refs(
                            `node, source, generic, out, None, dialect_type_quals
                        );
                    }
                } else {
                    collect = _c_collect_type_refs;
                }
                return_node = `node.child_by_field_name("type");
                if return_node is not None {
                    refs = [];
                    collect(return_node, source, False, refs);
                    for (ref_name, role) in refs {
                        ctx = "generic_arg" if role == "generic_arg" else "return_type";
                        target_nid = ensure_named_node(ref_name, line);
                        if target_nid != func_nid {
                            add_edge(func_nid, target_nid, "references", line, context=ctx);
                        }
                    }
                }
                decl = `node.child_by_field_name("declarator");
                while decl is not None
                    and decl.type in ("pointer_declarator", "reference_declarator")
                {
                    decl = decl.child_by_field_name("declarator");
                }
                if decl is not None and decl.type == "function_declarator" {
                    params_node = decl.child_by_field_name("parameters");
                    if params_node is not None {
                        for p in typing.cast(object, params_node).children {
                            if p.type != "parameter_declaration" {
                                continue;
                            }
                            ptype = p.child_by_field_name("type");
                            if ptype is None {
                                continue;
                            }
                            refs = [];
                            collect(ptype, source, False, refs);
                            for (ref_name, role) in refs {
                                ctx = "generic_arg" if role == "generic_arg" else "parameter_type";
                                target_nid = ensure_named_node(ref_name, line);
                                if target_nid != func_nid {
                                    add_edge(func_nid, target_nid, "references", line, context=ctx);
                                }
                            }
                        }
                    }
                }
            }

            if ts_mod == "tree_sitter_scala" {
                params_node = None;
                for c in typing.cast(object, `node).children {
                    if c.type == "parameters" {
                        params_node = c;
                        break;
                    }
                }
                if params_node is not None {
                    for p in typing.cast(object, params_node).children {
                        if p.type != "parameter" {
                            continue;
                        }
                        ptype = p.child_by_field_name("type");
                        if ptype is None {
                            continue;
                        }
                        refs = [];
                        _scala_collect_type_refs(ptype, source, False, refs);
                        for (ref_name, role) in refs {
                            ctx = "generic_arg" if role == "generic_arg" else "parameter_type";
                            target_nid = ensure_named_node(ref_name, line);
                            if target_nid != func_nid {
                                add_edge(func_nid, target_nid, "references", line, context=ctx);
                            }
                        }
                    }
                }
                return_node = `node.child_by_field_name("return_type");
                if return_node is not None {
                    refs = [];
                    _scala_collect_type_refs(return_node, source, False, refs);
                    for (ref_name, role) in refs {
                        ctx = "generic_arg" if role == "generic_arg" else "return_type";
                        target_nid = ensure_named_node(ref_name, line);
                        if target_nid != func_nid {
                            add_edge(func_nid, target_nid, "references", line, context=ctx);
                        }
                    }
                }
                for c in typing.cast(object, `node).children {
                    if c.type != "type_parameters" {
                        continue;
                    }
                    bound_refs = [];
                    _scala_collect_context_bounds(c, source, bound_refs);
                    for (ref_name, role) in bound_refs {
                        ctx = "generic_arg" if role == "generic_arg" else "type_bound";
                        target_nid = ensure_named_node(ref_name, line);
                        if target_nid != func_nid {
                            add_edge(func_nid, target_nid, "references", line, context=ctx);
                        }
                    }
                }
            }

            if ts_mod == "tree_sitter_java"
                and parent_class_nid
                and `node.type == "method_declaration"
            {
                ret: any = _java_receiver_type_name(`node.child_by_field_name("type"), source)
                    or "";
                java_return_types[func_nid] = ret
                    if java_return_types.get(func_nid, ret) == ret
                    else "";
            }

            body = _find_body(`node, config);
            if body is not None
                and ts_mod in ("tree_sitter_javascript", "tree_sitter_typescript")
            {
                function_owner_nid: any = parent_class_nid or func_nid;
                _js_scan_member_assignments(
                    body,
                    function_owner_nid,
                    source,
                    this_as_method=True,
                    add_node_fn=add_node,
                    add_edge_fn=add_edge,
                    function_bodies=function_bodies,
                    closure_locals_by_body=closure_locals_by_body,
                );
            }
            if body {
                if ts_mod == "tree_sitter_java" and parent_class_nid {
                    java_method_scopes[id(body)] = (`node, parent_class_nid);
                }
                if ts_mod == "tree_sitter_c_sharp" and parent_class_nid {
                    csharp_method_scopes[id(body)] = (`node, parent_class_nid);
                }
                function_bodies.append((func_nid, body));
                if ts_mod in ("tree_sitter_javascript", "tree_sitter_typescript") {
                    _scan_js_nested_function_declarations(
                        body,
                        func_nid,
                        source=source,
                        config=config,
                        add_node=add_node,
                        add_edge=add_edge,
                        callable_def_nids=callable_def_nids,
                        local_bound_names=local_bound_names,
                        function_bodies=function_bodies,
                        scope_parents=scope_parents,
                        lexical_nids_by_scope=lexical_nids_by_scope,
                    );
                }
                if ts_mod == "tree_sitter_python" {
                    _scan_python_nested_function_declarations(
                        body,
                        func_nid,
                        source=source,
                        config=config,
                        add_node=add_node,
                        add_edge=add_edge,
                        callable_def_nids=callable_def_nids,
                        local_bound_names=local_bound_names,
                        function_bodies=function_bodies,
                        scope_parents=scope_parents,
                        lexical_nids_by_scope=lexical_nids_by_scope,
                    );
                }
                if ts_mod == "tree_sitter_php" {
                    walk(body, parent_class_nid=parent_class_nid);
                }
                if ts_mod == "tree_sitter_kotlin" {
                    _kt_literals: any = [];
                    _kt_stack: any = `list(body.children);
                    while _kt_stack {
                        _kt_node: any = _kt_stack.pop();
                        if _kt_node.type == "function_declaration" {
                            continue;
                        }
                        if _kt_node.type == "object_literal" {
                            _kt_literals.append(_kt_node);
                            continue;
                        }
                        _kt_stack.extend(_kt_node.children);
                    }
                    _kt_literals.sort(key=lambda (n) -> any { n.start_byte });
                    for lit in _kt_literals {
                        lit_line: any = lit.start_point[0] + 1;
                        lit_bases: list[tuple[str, str]] = [];
                        for dchild in typing.cast(object, lit).children {
                            if dchild.type != "delegation_specifiers" {
                                continue;
                            }
                            for spec in typing.cast(object, dchild).children {
                                if spec.type != "delegation_specifier" {
                                    continue;
                                }
                                relation = "implements";
                                user_type_node = None;
                                for sub in typing.cast(object, spec).children {
                                    if sub.type == "constructor_invocation" {
                                        relation = "inherits";
                                        for inner in typing.cast(object, sub).children {
                                            if inner.type == "user_type" {
                                                user_type_node = inner;
                                                break;
                                            }
                                        }
                                        break;
                                    }
                                    if sub.type == "user_type" {
                                        user_type_node = sub;
                                        break;
                                    }
                                    if sub.type == "explicit_delegation" {
                                        for inner in typing.cast(object, sub).children {
                                            if inner.type == "user_type" {
                                                user_type_node = inner;
                                                break;
                                            }
                                        }
                                        break;
                                    }
                                }
                                base = _kotlin_user_type_name(user_type_node, source);
                                if base {
                                    lit_bases.append((base, relation));
                                }
                            }
                        }
                        obj_label: any = lit_bases[0][0] if lit_bases else f"object@L{lit_line}";
                        obj_nid: any = _make_id(func_nid, f"object:{obj_label}", f"L{lit_line}");
                        add_node(obj_nid, obj_label, lit_line);
                        add_edge(func_nid, obj_nid, "contains", lit_line);
                        callable_def_nids.add(obj_nid);
                        callable_class_nids.add(obj_nid);
                        for (base, relation) in lit_bases {
                            base_nid = ensure_named_node(base, lit_line);
                            if base_nid != obj_nid {
                                add_edge(obj_nid, base_nid, relation, lit_line);
                            }
                        }
                        lit_body: any = next(
                            (c for c in typing.cast(object, lit).children if c.type == "class_body"), None
                        );
                        if lit_body is not None {
                            for child in typing.cast(object, lit_body).children {
                                walk(child, parent_class_nid=obj_nid);
                            }
                        }
                    }
                }
                if ts_mod in ("tree_sitter_java", "tree_sitter_groovy") {
                    _jv_anon: any = [];
                    _jv_stack: any = `list(body.children);
                    while _jv_stack {
                        _jv_node: any = _jv_stack.pop();
                        if _jv_node.type in ("method_declaration", "lambda_expression") {
                            continue;
                        }
                        if _jv_node.type == "object_creation_expression"
                            and `any(operator.eq(c.type, "class_body") for c in typing.cast(object, _jv_node).children)
                        {
                            _jv_anon.append(_jv_node);
                            continue;
                        }
                        _jv_stack.extend(_jv_node.children);
                    }
                    _jv_anon.sort(key=lambda (n) -> any { n.start_byte });
                    for anon in _jv_anon {
                        anon_line: any = anon.start_point[0] + 1;
                        type_node = anon.child_by_field_name("type");
                        base = _read_text(type_node, source).strip() if type_node else "";
                        obj_label = base or f"object@L{anon_line}";
                        obj_nid = _make_id(func_nid, f"object:{obj_label}", f"L{anon_line}");
                        add_node(obj_nid, obj_label, anon_line);
                        add_edge(func_nid, obj_nid, "contains", anon_line);
                        callable_def_nids.add(obj_nid);
                        callable_class_nids.add(obj_nid);
                        anon_body: any = next(
                            (c for c in typing.cast(object, anon).children if c.type == "class_body"), None
                        );
                        if anon_body is not None {
                            for child in typing.cast(object, anon_body).children {
                                walk(child, parent_class_nid=obj_nid);
                            }
                        }
                    }
                }
            }
            return;
        }
        if ts_mod in ("tree_sitter_javascript", "tree_sitter_typescript") {
            if _js_extra_walk(
                `node,
                source,
                file_nid,
                stem,
                str_path,
                nodes,
                edges,
                seen_ids,
                function_bodies,
                parent_class_nid,
                add_node,
                add_edge,
                callable_def_nids,
                local_bound_names,
                closure_locals_by_body,
                config=config,
                decl_node_fn=decl_node,
                decl_lookup_fn=decl_registry.lookup,
                js_member_groups=js_member_groups,
                scope_parents=scope_parents,
                lexical_nids_by_scope=lexical_nids_by_scope,
            ) {
                return;
            }
        }
        if ts_mod == "tree_sitter_typescript" {
            if _ts_extra_walk(
                `node,
                source,
                file_nid,
                stem,
                str_path,
                nodes,
                edges,
                seen_ids,
                function_bodies,
                parent_class_nid,
                add_node,
                add_edge,
                walk,
                decl_node_fn=decl_node,
                namespace_stack=namespace_stack,
            ) {
                return;
            }
        }

        if ts_mod == "tree_sitter_c_sharp" {
            if _csharp_extra_walk(
                `node,
                source,
                file_nid,
                stem,
                str_path,
                nodes,
                edges,
                seen_ids,
                function_bodies,
                parent_class_nid,
                add_node,
                add_edge,
                walk,
                namespace_stack,
                scope_stack,
                csharp_member_groups,
            ) {
                return;
            }
        }

        if ts_mod == "tree_sitter_swift" {
            if _swift_extra_walk(
                `node,
                source,
                file_nid,
                stem,
                str_path,
                nodes,
                edges,
                seen_ids,
                function_bodies,
                parent_class_nid,
                add_node,
                add_edge,
                ensure_named_node,
            ) {
                return;
            }
        }
        if ts_mod in ("tree_sitter_java", "tree_sitter_groovy") {
            if _java_extra_walk(
                `node,
                source,
                file_nid,
                stem,
                str_path,
                nodes,
                edges,
                seen_ids,
                function_bodies,
                parent_class_nid,
                add_node,
                add_edge,
                walk,
            ) {
                return;
            }
        }

        if ts_mod == "tree_sitter_kotlin" {
            if _kotlin_extra_walk(
                `node,
                source,
                file_nid,
                stem,
                str_path,
                nodes,
                edges,
                seen_ids,
                function_bodies,
                parent_class_nid,
                add_node,
                add_edge,
                walk,
            ) {
                return;
            }
        }
        if ts_mod == "tree_sitter_php" {
            if _php_extra_walk(
                `node,
                source,
                file_nid,
                stem,
                str_path,
                nodes,
                edges,
                seen_ids,
                function_bodies,
                parent_class_nid,
                add_node,
                add_edge,
            ) {
                return;
            }
        }
        if ts_mod == "tree_sitter_scala" {
            if _scala_extra_walk(
                `node,
                source,
                file_nid,
                stem,
                str_path,
                nodes,
                edges,
                seen_ids,
                function_bodies,
                parent_class_nid,
                add_node,
                add_edge,
                walk,
                ensure_named_node,
            ) {
                return;
            }
        }
        if ts_mod == "tree_sitter_cpp" {
            if _cpp_extra_walk(
                `node,
                source,
                file_nid,
                stem,
                str_path,
                nodes,
                edges,
                seen_ids,
                function_bodies,
                parent_class_nid,
                add_node,
                add_edge,
                decl_node_fn=decl_node,
            ) {
                return;
            }
        }

        if ts_mod == "tree_sitter_ruby" {
            if _ruby_extra_walk(
                `node,
                source,
                file_nid,
                stem,
                str_path,
                nodes,
                edges,
                seen_ids,
                function_bodies,
                parent_class_nid,
                add_node,
                add_edge,
                walk,
                callable_def_nids,
                callable_class_nids,
                ruby_namespace,
                ruby_lexical_scopes,
            ) {
                return;
            }
        }
        if t in ("type_alias_statement", "expression_statement")
            and ts_mod == "tree_sitter_python"
            and parent_class_nid is None
            and `node.parent is not None
            and `node.parent.type == "module"
        {
            alias_name: any = _python_alias_name(`node, source);
            if alias_name {
                alias_line: any = `node.start_point[0] + 1;
                alias_nid: any = _underscore_salted_nid(
                    _make_id(stem, alias_name), alias_name, python_underscore_groups
                );
                add_node(alias_nid, alias_name, alias_line);
                add_edge(file_nid, alias_nid, "contains", alias_line);
            }
        }
        if t == "decorated_definition" {
            if ts_mod == "tree_sitter_python" {
                inner = `node.child_by_field_name("definition");
                inner_name: any = None;
                if inner is not None {
                    name_node = inner.child_by_field_name("name");
                    inner_name = _read_text(name_node, source) if name_node else None;
                }
                if inner_name and normalize_id(inner_name) {
                    if inner.type in config.class_types {
                        owner_nid = _make_id(stem, ".".join(namespace_stack), inner_name);
                        if ts_mod == "tree_sitter_python" and parent_class_nid {
                            owner_nid = _make_id(parent_class_nid, inner_name);
                        }
                    } elif parent_class_nid {
                        owner_nid = _make_id(parent_class_nid, inner_name);
                    } else {
                        owner_nid = _make_id(stem, inner_name);
                    }
                    for child in typing.cast(object, `node).children {
                        if child.type != "decorator" {
                            continue;
                        }
                        deco_expr: any = next(iter(child.named_children), None);
                        deco_text: any = _read_text(deco_expr, source)
                            if deco_expr is not None
                            else "";
                        if deco_text.endswith(_PYTHON_PROPERTY_ACCESSOR_SUFFIXES) {
                            continue;
                        }
                        deco_name: any = _python_decorator_name(child, source);
                        if not deco_name or deco_name in _PYTHON_DECORATOR_NOISE {
                            continue;
                        }
                        deco_line: any = child.start_point[0] + 1;
                        target = ensure_named_node(deco_name, deco_line);
                        if target != owner_nid {
                            add_edge(
                                owner_nid, target, "references", deco_line, context="decorator"
                            );
                        }
                    }
                }
            }
            for child in typing.cast(object, `node).children {
                walk(child, parent_class_nid=parent_class_nid);
            }
            return;
        }
        if ts_mod == "tree_sitter_kotlin" and t == "companion_object" {
            for child in typing.cast(object, `node).children {
                if child.type == "class_body" {
                    for member in typing.cast(object, child).children {
                        walk(member, parent_class_nid=parent_class_nid);
                    }
                } else {
                    walk(child, parent_class_nid=parent_class_nid);
                }
            }
            return;
        }
        if t == "enum_body_declarations" {
            for child in typing.cast(object, `node).children {
                walk(child, parent_class_nid=parent_class_nid);
            }
            return;
        }
        if t == "ERROR" {
            for child in typing.cast(object, `node).children {
                walk(child, parent_class_nid=parent_class_nid);
            }
            return;
        }
        if ts_mod == "tree_sitter_cpp" and t == "template_declaration" {
            for child in typing.cast(object, `node).children {
                walk(child, parent_class_nid=parent_class_nid);
            }
            return;
        }
        if ts_mod == "tree_sitter_ruby"
            and t == "call"
            and parent_class_nid
            and `node.child_by_field_name("receiver") is None
        {
            args = `node.child_by_field_name("arguments");
            if args is not None and `any(c.type in config.function_types for c in typing.cast(object, args).children) {
                for child in typing.cast(object, `node).children {
                    if child == args {
                        for arg in typing.cast(object, args).children {
                            walk(
                                arg,
                                parent_class_nid=parent_class_nid
                                    if arg.type in config.function_types
                                    else None,
                            );
                        }
                    } else {
                        walk(child, parent_class_nid=None);
                    }
                }
                return;
            }
        }
        for child in typing.cast(object, `node).children {
            walk(child, parent_class_nid=None);
        }
    }

    walk(`root);
    for (stub_nid, local_nid) in stem_forward_refs.items() {
        if local_nid not in callable_class_nids {
            continue;
        }
        `edge: any;
        for `edge in edges {
            if `edge["target"] == stub_nid {
                `edge["target"] = local_nid;
            }
        }
        nodes[:] = [n for n in nodes if not (n["id"] == stub_nid and not n["source_file"])];
        seen_ids.discard(stub_nid);
    }
    label_to_nid = {};
    label_to_nid_ci = {};
    nid_to_sf = {};
    lua_self_table = {};
    _case_of_targets: any = {e.get("target") for e in edges if e.get("relation") == "case_of"};
    python_free_label_to_nid = {};
    _python_method_nids: any = {e["target"] for e in edges if e.get("relation") == "method"}
        if ts_mod == "tree_sitter_python"
        else set[any]();
    for n in nodes {
        nid_to_sf[n["id"]] = `str(n.get("source_file") or "");
        if n.get("type") == "namespace" {
            continue;
        }
        if n["id"] in _case_of_targets {
            continue;
        }
        if ts_mod == "tree_sitter_c_sharp"
            and (n.get("metadata") or {}).get("kind") == "constructor"
        {
            continue;
        }
        if ts_mod == "tree_sitter_c_sharp"
            and (n.get("metadata") or {}).get("explicit_interface")
        {
            continue;
        }
        raw: any = n["label"];
        normalised: any = raw.strip("()").lstrip(".");
        if ts_mod == "tree_sitter_lua" {
            sep: any = ":" if ":" in normalised else "." if "." in normalised else None;
            if sep {
                lua_self_table[n["id"]] = normalised.rsplit(sep, 1)[0];
            }
        }
        if n["id"] not in scope_parents {
            label_to_nid[normalised] = n["id"];
            label_to_nid_ci[normalised.lower()] = n["id"];
            if ts_mod == "tree_sitter_python" and n["id"] not in _python_method_nids {
                python_free_label_to_nid[normalised] = n["id"];
            }
        } elif ts_mod in ("tree_sitter_javascript", "tree_sitter_typescript") {
            continue;
        } else {
            label_to_nid.setdefault(normalised, n["id"]);
            label_to_nid_ci.setdefault(normalised.lower(), n["id"]);
        }
    }
    _csharp_callable_groups: any = [
        [p for p in group.values() if not (p.get("metadata") or {}).get("explicit_interface")]
        for group in csharp_overloads.values()
    ];
    csharp_overload_peers = {
        peer["id"]: peers
        for peers in _csharp_callable_groups
        if len(peers) > 1
        for peer in peers
    };
    for _java_group in java_overloads.values() {
        _java_peers: any = `list(_java_group.values());
        if len(_java_peers) > 1 {
            for _peer in _java_peers {
                csharp_overload_peers[_peer["id"]] = _java_peers;
            }
        }
    }

    seen_call_pairs = set[any]();
    seen_indirect_pairs = set[any]();
    seen_dyn_import_pairs = set[any]();
    seen_static_ref_pairs = set[any]();
    seen_helper_ref_pairs = set[any]();
    seen_bind_pairs = set[any]();
    raw_calls = [];
    ruby_var_types = {};
    python_var_types = {};
    python_fixture_params = {};
    ruby_local_names = {};
    _local_bases = {};
    for _e in edges {
        if _e.get("relation") == "inherits" {
            _local_bases.setdefault(_e["source"], []).append(_e["target"]);
        }
    }
    method_owner = {};
    methods_by_owner = {};
    class_parent = {};
    lexical_bases = {};
    lexical_calls = ts_mod in _LEXICAL_CALL_LANGUAGES;
    js_factory_scope = {};
    if ts_mod in _SELF_CALL_LANGUAGES or lexical_calls {
        label_by_nid: any = {n["id"]: n["label"] for n in nodes};
        csharp_explicit_nids: any = {
            n["id"]
            for n in nodes
            if (n.get("metadata") or {}).get("explicit_interface")
        }
            if ts_mod == "tree_sitter_c_sharp"
            else set[any]();
        for e in edges {
            if ts_mod == "tree_sitter_c_sharp"
                and e["relation"] == "defines"
                and e.get("context") == "field"
            {
                method_owner.setdefault(e["target"], e["source"]);
            }
            if e["relation"] == "method" {
                method_owner[e["target"]] = e["source"];
                name = label_by_nid.get(e["target"], "").strip("()").lstrip(".");
                if ts_mod == "tree_sitter_php" {
                    name = name.casefold();
                }
                if e["target"] not in csharp_explicit_nids {
                    methods_by_owner.setdefault((e["source"], name), e["target"]);
                }
            } elif ts_mod in ("tree_sitter_javascript", "tree_sitter_typescript")
                and e["relation"] == "contains"
            {
                js_factory_scope.setdefault(e["target"], e["source"]);
            } elif lexical_calls and e["relation"] == "contains" {
                if class_parent.setdefault(e["target"], e["source"]) != e["source"] {
                    class_parent[e["target"]] = "";
                }
            }
        }
        if lexical_calls {
            lexical_bases = _lexical_class_bases(
                edges,
                _LEXICAL_CALL_LANGUAGES[ts_mod],
                label_by_nid,
                nid_to_sf,
                method_owner,
                methods_by_owner,
                class_parent,
                csharp_interface_names,
            );
        }
    }
    kotlin_types_by_label = {};
    kotlin_methods_by_owner = {};
    kotlin_callable_counts = {};
    if ts_mod == "tree_sitter_kotlin" {
        kotlin_labels: any = {n["id"]: n["label"] for n in nodes};
        for e in edges {
            if e["relation"] == "method" {
                name = kotlin_labels.get(e["target"], "").strip("()").lstrip(".");
                kotlin_methods_by_owner.setdefault((e["source"], name), e["target"]);
            }
        }
        for owner in {owner for (owner, _) in kotlin_methods_by_owner} {
            kotlin_types_by_label.setdefault(kotlin_labels.get(owner, ""), []).append(owner);
        }
        for n in nodes {
            if n["label"].endswith("()") {
                name = n["label"].strip("()").lstrip(".");
                kotlin_callable_counts[name] = kotlin_callable_counts.get(name, 0) + 1;
            }
        }
    }

    def _fields_up_chain(tables: dict, class_nid) -> dict {
        if not class_nid {
            return {};
        }
        merged: dict = {};
        seen: set = set[any]();
        queue: any = [class_nid];
        while queue {
            cls: any = queue.pop(0);
            if cls in seen {
                continue;
            }
            seen.add(cls);
            for (_name, _tname) in tables.get(cls, {}).items() {
                merged.setdefault(_name, _tname);
            }
            queue.extend(_local_bases.get(cls, []));
        }
        return merged;
    }

    java_receiver_types: any = {
        body_id: _java_method_receiver_types(
            method_node, source, _fields_up_chain(java_field_types, class_nid)
        )
        for (body_id, (method_node, class_nid)) in java_method_scopes.items()
    };
    java_bound_names = {};
    java_local_names_by_body: any = {
        body_id: _java_bound_names(method_node, source)
        for (body_id, (method_node, _)) in java_method_scopes.items()
    };
    _java_body_caller: any = {id(body): nid for (nid, body) in function_bodies};
    _java_field_name_tables = {
        c: dict.fromkeys(names, "")
        for (c, names) in java_field_names.items()
    };
    for (body_id, (method_node, class_nid)) in java_method_scopes.items() {
        caller: any = _java_body_caller.get(body_id);
        if caller {
            java_bound_names.setdefault(caller, set[any]()).update(
                java_local_names_by_body[body_id],
                _fields_up_chain(_java_field_name_tables, class_nid),
            );
        }
    }
    csharp_receiver_types: any = {
        body_id: _csharp_method_receiver_types(
            method_node, source, _fields_up_chain(csharp_field_types, class_nid)
        )
        for (body_id, (method_node, class_nid)) in csharp_method_scopes.items()
    };
    def _emit_indirect_by_name(ident_name: str, loc_node, scope_nid: str, context: str) {
        ref_nid: any = None;
        if ts_mod in ("tree_sitter_javascript", "tree_sitter_typescript") {
            curr_scope: any = scope_nid;
            while curr_scope and ref_nid is None {
                ref_nid = lexical_nids_by_scope.get(curr_scope, {}).get(ident_name);
                curr_scope = scope_parents.get(curr_scope);
            }
        }
        if ref_nid is None {
            ref_nid = label_to_nid.get(ident_name);
        }
        if ref_nid is None
            or ref_nid not in callable_def_nids and nid_to_sf.get(ref_nid, "") != str_path
        {
            raw_calls.append({
                "caller_nid": scope_nid,
                "callee": ident_name,
                "is_member_call": False,
                "indirect": True,
                "context": context,
                "source_file": str_path,
                "source_location": f"L{loc_node.start_point[0] + 1}",
            });
            return;
        }
        if ref_nid == scope_nid or ref_nid not in callable_def_nids {
            return;
        }
        if ref_nid in callable_class_nids {
            return;
        }
        if (scope_nid, ref_nid) in seen_call_pairs {
            return;
        }
        if (scope_nid, ref_nid) in seen_indirect_pairs {
            return;
        }
        seen_indirect_pairs.add((scope_nid, ref_nid));
        edges.append({
            "source": scope_nid,
            "target": ref_nid,
            "relation": "indirect_call",
            "context": context,
            "confidence": "INFERRED",
            "confidence_score": 0.85,
            "source_file": str_path,
            "source_location": f"L{loc_node.start_point[0] + 1}",
            "weight": 1.0,
        });
    }

    python_lambda_bindings = {};

    def _python_private_prefix(`node) -> str {
        while (parent := `node.parent) is not None {
            if parent.type == "class_definition" and `node == parent.child_by_field_name("body") {
                class_name: any = parent.child_by_field_name("name");
                if class_name is None {
                    return "";
                }
                name: any = normalize("NFKC", _read_text(class_name, source)).lstrip("_");
                return f"_{name}" if name else "";
            }
            `node = parent;
        }
        return "";
    }

    def _python_binding_name(name: str, private_prefix: str) -> str {
        name = normalize("NFKC", name);
        if name.startswith("__") and not name.endswith("__") {
            return private_prefix + name;
        }
        return name;
    }
    def _python_lambda_param_shadows(`node, name: str) -> bool {
        while (parent := `node.parent) is not None {
            if parent.type in ("function_definition", "class_definition", "module") {
                break;
            }
            if parent.type == "lambda" and `node == parent.child_by_field_name("body") {
                if parent.id not in python_lambda_bindings {
                    prefix: any = _python_private_prefix(parent);
                    parameters: any = _python_param_names(
                        parent.child_by_field_name("parameters"), source
                    );
                    python_lambda_bindings[parent.id] = (
                        prefix,
                        {_python_binding_name(param, prefix) for param in parameters},
                    );
                }
                (prefix, parameters) = python_lambda_bindings[parent.id] as any;
                if _python_binding_name(name, prefix) in parameters {
                    return True;
                }
            }
            `node = parent;
        }
        return False;
    }
    def _emit_indirect_ref(ident, scope_nid: str, enclosing_locals, context: str) {
        if ident is None or ident.type not in ("identifier", "shorthand_property_identifier") {
            return;
        }
        ident_name: any = _read_text(ident, source);
        if ident_name in enclosing_locals or ident_name in ("self", "cls") {
            return;
        }
        if ident_name in js_external_imports {
            return;
        }
        if ts_mod == "tree_sitter_python"
            and _python_lambda_param_shadows(ident, ident_name)
        {
            return;
        }
        _emit_indirect_by_name(ident_name, ident, scope_nid, context);
    }
    def _python_dispatch_value_idents(coll_node) -> Generator[any, any, any] {
        if coll_node.type == "dictionary" {
            for pair in typing.cast(object, coll_node).children {
                if pair.type == "pair" {
                    val: any = pair.child_by_field_name("value");
                    if val is not None and val.type == "identifier" {
                        yield val;
                    }
                }
            }
        } else {
            for el in typing.cast(object, coll_node).children {
                if el.type == "identifier" {
                    yield el;
                }
            }
        }
    }
    def _python_dispatch_value_attrs(coll_node) -> Generator[any, any, any] {
        if coll_node.type == "dictionary" {
            values: any = (p.child_by_field_name("value")
            for p in typing.cast(object, coll_node).children
            if p.type == "pair");
        } else {
            values = iter(coll_node.children);
        }
        for val in values {
            if val is None or val.type != "attribute" {
                continue;
            }
            `obj: any = val.child_by_field_name("object");
            if `obj is not None
                and `obj.type == "identifier"
                and val.child_by_field_name("attribute") is not None
            {
                yield val;
            }
        }
    }
    def _emit_indirect_member_ref(attr_node, scope_nid: str, enclosing_locals, context: str) {
        receiver: any = _read_text(attr_node.child_by_field_name("object"), source);
        if receiver in enclosing_locals or receiver in ("self", "cls") {
            return;
        }
        raw_calls.append({
            "caller_nid": scope_nid,
            "callee": _read_text(attr_node.child_by_field_name("attribute"), source),
            "is_member_call": True,
            "receiver": receiver,
            "indirect": True,
            "context": context,
            "source_file": str_path,
            "source_location": f"L{attr_node.start_point[0] + 1}",
        });
    }
    def _python_ref_value_idents(value_node) -> Generator[any, any, any] {
        if value_node is None {
            return;
        }
        if value_node.type == "identifier" {
            yield value_node;
        } elif value_node.type == "expression_list" {
            for ch in typing.cast(object, value_node).children {
                if ch.type == "identifier" {
                    yield ch;
                }
            }
        }
    }
    def _getattr_ref_name(call_node) -> any {
        fn: any = call_node.child_by_field_name("function");
        if fn is None or fn.type != "identifier" or _read_text(fn, source) != "getattr" {
            return None;
        }
        args: any = call_node.child_by_field_name("arguments");
        if args is None {
            return None;
        }
        positional: any = [
            c
            for c in typing.cast(object, args).children
            if c.is_named and c.type not in ("keyword_argument", "comment")
        ];
        if len(positional) < 2 {
            return None;
        }
        name_node: any = positional[1];
        if name_node.type != "string"
            or `any(operator.eq(ch.type, "interpolation") for ch in typing.cast(object, name_node).children)
        {
            return None;
        }
        content: any = next((ch for ch in typing.cast(object, name_node).children if ch.type == "string_content"), None);
        if content is None {
            return None;
        }
        return (_read_text(content, source), name_node);
    }

    def _php_class_const_scope(n) -> str | None {
        scope: any = n.child_by_field_name("scope");
        if scope is None {
            for c in typing.cast(object, n).children {
                if c.is_named and c.type in ("name", "qualified_name", "identifier") {
                    scope = c;
                    break;
                }
            }
        }
        if scope is None {
            return None;
        }
        return _read_text(scope, source);
    }

    _tracked_body_ids = set[any]();
    _JS_CLOSURE_TYPES: any = ("arrow_function", "function_expression");
    _JS_DESCEND_TYPES = _JS_CLOSURE_TYPES
        + ("function_declaration", "generator_function_declaration", "generator_function");

    extra_locals_default_: any = frozenset();

    fn_boundary_types: any = config.function_boundary_types;
    call_types_: any = config.call_types;

    def walk_calls(
        `node,
        caller_nid: str,
        receiver_types: dict[str, str] | tuple | None = None,
        extra_locals: frozenset[str] = extra_locals_default_,
    ) {
        wn = typing.cast(object, `node);
        ntype = wn.type;
        if ntype in fn_boundary_types {
            if ts_mod in ("tree_sitter_javascript", "tree_sitter_typescript")
                and ntype in _JS_DESCEND_TYPES
            {
                body: any = wn.child_by_field_name("body");
                if body is not None and body not in _tracked_body_ids {
                    closure_locals: any = extra_locals | _js_local_bound_names(`node, source);
                    child: any;
                    for child in wn.children {
                        walk_calls(child, caller_nid, receiver_types, closure_locals);
                    }
                }
            }
            return;
        }
        if ts_mod in ("tree_sitter_javascript", "tree_sitter_typescript")
            and ntype in ("lexical_declaration", "variable_declaration")
        {
            _require_imports_js(`node, source, caller_nid, stem, edges, str_path);
        }
        _ruby_bare_self_send: any = False;
        if ts_mod == "tree_sitter_ruby" and ntype == "identifier" {
            _parent: any = wn.parent;
            _call_field: any = _parent is not None
                and operator.eq(_parent.type, "call")
                and `node
                    in (
                        _parent.child_by_field_name("method"),
                        _parent.child_by_field_name("receiver"),
                    );
            if not _call_field {
                _bare_name: any = _read_text(`node, source);
                if _bare_name
                    and _bare_name not in ruby_local_names.get(caller_nid, frozenset())
                    and _bare_name not in extra_locals
                {
                    _ruby_bare_self_send = True;
                }
            }
        }

        if ntype in call_types_ or _ruby_bare_self_send {
            if ts_mod in ("tree_sitter_javascript", "tree_sitter_typescript") {
                if _dynamic_import_js(
                    `node, source, caller_nid, str_path, edges, seen_dyn_import_pairs
                ) {
                    for child in wn.children {
                        walk_calls(child, caller_nid, receiver_types, extra_locals);
                    }
                    return;
                }
            }

            callee_name: str | None = None;
            is_member_call: bool = False;
            is_this_field_call: bool = False;
            self_receiver: str | None = None;
            is_scoped_call: bool = False;
            swift_receiver: str | None = None;
            member_receiver: str | None = None;
            kotlin_qualified_prefix: str | None = None;
            kotlin_object_receiver: str | None = None;
            kotlin_receiver: str | None = None;
            kotlin_receiver_type: str | None = None;
            csharp_qualified_prefix: str | None = None;
            csharp_receiver_chain: list[str] | None = None;
            java_receiver_chain: list | None = None;
            lua_self_qualified: bool = False;
            if _ruby_bare_self_send {
                callee_name = _read_text(`node, source);
                self_receiver = "self";
            } elif ts_mod == "tree_sitter_swift" {
                if ntype == "macro_invocation" {
                    for child in wn.children {
                        if child.type == "simple_identifier" {
                            callee_name = _read_text(child, source);
                            break;
                        }
                    }
                }
                first: any = _swift_operand_tail(wn.children[0]) if wn.children else None;
                if ntype != "macro_invocation" and first {
                    if first.type == "simple_identifier" {
                        callee_name = _read_text(first, source);
                        self_receiver = "self";
                    } elif first.type == "navigation_expression" {
                        is_member_call = True;
                        for child in typing.cast(object, first).children {
                            if child.type == "navigation_suffix" {
                                sc: any;
                                for sc in typing.cast(object, child).children {
                                    if sc.type == "simple_identifier" {
                                        callee_name = _read_text(sc, source);
                                    }
                                }
                            }
                        }
                        recv_node: any = _swift_operand_tail(first.children[0])
                            if first.children
                            else None;
                        swift_receiver = _swift_receiver_name(recv_node, source);
                        if recv_node is not None and recv_node.type == "self_expression" {
                            self_receiver = "self";
                        } elif recv_node is not None and recv_node.type == "super_expression" {
                            self_receiver = "super";
                        }
                    }
                }
            } elif ts_mod == "tree_sitter_kotlin" {
                first = wn.children[0] if wn.children else None;
                while first is not None and first.type == "unary_expression" {
                    first = first.child_by_field_name("argument");
                }
                if first {
                    if first.type in ("simple_identifier", "identifier") {
                        callee_name = _read_text(first, source);
                    } elif first.type == "navigation_expression" {
                        is_member_call = True;
                        for child in reversed(first.children) {
                            if child.type in ("simple_identifier", "identifier") {
                                callee_name = _read_text(child, source);
                                break;
                            }
                        }
                        segments: any = _kotlin_nav_identifier_segments(first, source);
                        if segments is not None and len(segments) >= 3 {
                            kotlin_qualified_prefix = ".".join(segments[:-1]);
                        } elif segments is not None
                            and len(segments) == 2
                            and segments[0][:1].isupper()
                        {
                            kotlin_object_receiver = segments[0];
                        }
                        this_field: any = False;
                        if segments is not None and len(segments) == 2 {
                            kotlin_receiver = segments[0]
                                if not segments[0][:1].isupper()
                                else None;
                        } else {
                            head: any = next((c for c in typing.cast(object, first).children if c.is_named), None);
                            parts: any = [c for c in typing.cast(object, head).children if c.is_named]
                                if head is not None
                                else [];
                            if head is not None
                                and head.type == "navigation_expression"
                                and len(parts) == 2
                                and parts[0].type == "this_expression"
                                and parts[1].type in _KOTLIN_IDENTIFIERS
                            {
                                (kotlin_receiver, this_field) = (
                                    _read_text(parts[1], source),
                                    True,
                                );
                            }
                        }
                        if kotlin_receiver {
                            kotlin_receiver_type = _kotlin_receiver_type(
                                `node, kotlin_receiver, source, this_field=this_field
                            );
                        }
                    }
                }
            } elif ts_mod == "tree_sitter_scala" {
                first = wn.children[0] if wn.children else None;
                if first {
                    if first.type == "identifier" {
                        callee_name = _read_text(first, source);
                    } elif first.type == "field_expression" {
                        is_member_call = True;
                        field: any = first.child_by_field_name("field");
                        if field {
                            callee_name = _read_text(field, source);
                        } else {
                            for child in reversed(first.children) {
                                if child.type == "identifier" {
                                    callee_name = _read_text(child, source);
                                    break;
                                }
                            }
                        }
                    }
                }
            } elif ts_mod == "tree_sitter_php"
                and ntype == "object_creation_expression"
            {
                for _oce_child in wn.children {
                    if _oce_child.type in ("name", "qualified_name") {
                        _oce_text: any = _read_text(_oce_child, source).rsplit("\\", 1)[-1];
                        if _oce_text.lower() not in ("self", "static", "parent") {
                            callee_name = _oce_text;
                        }
                        break;
                    }
                }
            } elif ts_mod == "tree_sitter_c_sharp"
                and ntype == "object_creation_expression"
            {
                type_info: any = _read_csharp_type_name(wn.child_by_field_name("type"), source);
                if type_info and type_info[0] {
                    callee_name = type_info[0];
                    if type_info[1] and type_info[2] {
                        csharp_qualified_prefix = type_info[2];
                    }
                }
            } elif ts_mod == "tree_sitter_c_sharp"
                and ntype == "invocation_expression"
            {
                fn_node: any = wn.child_by_field_name("function");
                member_parts: any = _csharp_member_call_parts(fn_node);
                csharp_table: any = receiver_types if isinstance(receiver_types, `tuple) else None;
                if member_parts is not None {
                    mname: any;
                    recv: any;
                    (mname, recv) = member_parts as any;
                    if mname is not None {
                        callee_name = _csharp_bare_call_name(mname, source);
                        is_member_call = True;
                        if recv is not None and recv.type == "identifier" {
                            member_receiver = _read_text(recv, source);
                        } elif recv is not None and recv.type in ("this", "this_expression") {
                            member_receiver = "this";
                        } elif recv is not None and recv.type in ("base", "base_expression") {
                            member_receiver = "base";
                        } elif recv is not None and recv.type == "member_access_expression" {
                            inner: any = recv.child_by_field_name("expression");
                            fname: any = recv.child_by_field_name("name");
                            if inner is not None
                                and inner.type in ("this", "this_expression")
                                and fname is not None
                                and fname.type == "identifier"
                            {
                                member_receiver = _read_text(fname, source);
                            } elif inner is not None
                                and inner.type == "identifier"
                                and fname is not None
                                and fname.type == "identifier"
                            {
                                root_type: any = _csharp_scoped_receiver_type(
                                    csharp_table, _read_text(inner, source), wn.start_byte
                                );
                                if isinstance(root_type, `str) {
                                    csharp_receiver_chain = [root_type, _read_text(fname, source)];
                                } elif root_type is None
                                    and csharp_table is not None
                                    and not _csharp_receiver_is_declared(
                                        csharp_table, _read_text(inner, source), wn.start_byte
                                    )
                                {
                                    csharp_receiver_chain = [
                                        _read_text(inner, source),
                                        _read_text(fname, source),
                                    ];
                                }
                            }
                        } elif recv is not None and recv.type == "element_access_expression" {
                            inner = recv.child_by_field_name("expression");
                            if inner is not None and inner.type == "identifier" {
                                elem_type: any = _csharp_scoped_receiver_type(
                                    csharp_table, _read_text(inner, source) + "[]", wn.start_byte
                                );
                                if isinstance(elem_type, `str) {
                                    csharp_receiver_chain = [elem_type];
                                }
                            }
                        } elif recv is not None and recv.type == "object_creation_expression" {
                            type_info = _read_csharp_type_name(
                                recv.child_by_field_name("type"), source
                            );
                            if type_info and type_info[0] {
                                csharp_receiver_chain = [type_info[0]];
                            }
                        } elif recv is not None and recv.type == "parenthesized_expression" {
                            inner = recv.named_children[0] if recv.named_children else None;
                            cast_type: any = None;
                            if inner is not None and inner.type == "cast_expression" {
                                cast_type = inner.child_by_field_name("type");
                            } elif inner is not None and inner.type == "as_expression" {
                                cast_type = inner.child_by_field_name("right");
                            }
                            type_info = _read_csharp_type_name(cast_type, source);
                            if type_info and type_info[0] {
                                member_receiver = type_info[0];
                            }
                        }
                    }
                } elif fn_node is not None and fn_node.type == "identifier" {
                    callee_name = _read_text(fn_node, source);
                } elif fn_node is not None and fn_node.type == "generic_name" {
                    callee_name = _csharp_bare_call_name(fn_node, source);
                } else {
                    name_node: any = wn.child_by_field_name("name");
                    if name_node {
                        callee_name = _read_text(name_node, source);
                    } else {
                        for child in wn.children {
                            if child.is_named {
                                raw: any = _read_text(child, source);
                                if "." in raw {
                                    callee_name = raw.split(".")[-1];
                                    is_member_call = True;
                                    parts = raw.split(".");
                                    if len(parts) == 2 and parts[0] {
                                        member_receiver = parts[0];
                                    }
                                } else {
                                    callee_name = raw;
                                }
                                break;
                            }
                        }
                    }
                }
                if fn_node is not None {
                    call_tal: any = None;
                    if member_parts is not None {
                        ma_name: any = member_parts[0];
                        if ma_name is not None and ma_name.type == "generic_name" {
                            tal_child: any;
                            for tal_child in typing.cast(object, ma_name).children {
                                if tal_child.type == "type_argument_list" {
                                    call_tal = tal_child;
                                    break;
                                }
                            }
                        }
                    } elif fn_node.type == "generic_name" {
                        for tal_child in typing.cast(object, fn_node).children {
                            if tal_child.type == "type_argument_list" {
                                call_tal = tal_child;
                                break;
                            }
                        }
                    }
                    if call_tal is not None {
                        call_type_params: any = _csharp_type_parameters_in_scope(`node, source);
                        call_line: any = wn.start_point[0] + 1;
                        for call_arg in typing.cast(object, call_tal).children {
                            if not call_arg.is_named {
                                continue;
                            }
                            call_refs: list[tuple[str, str, bool, str]] = [];
                            _csharp_collect_type_refs(
                                call_arg, source, True, call_refs, call_type_params
                            );
                            for (
                                call_ref_name,
                                _call_role,
                                call_qualified,
                                call_qualifier,
                            ) in call_refs {
                                call_target: any = ensure_named_node(call_ref_name, call_line);
                                if call_target == caller_nid {
                                    continue;
                                }
                                call_meta: any = {"ref_token": call_ref_name};
                                if call_qualified {
                                    call_meta["qualified"] = True;
                                }
                                if call_qualifier {
                                    call_meta["ref_qualifier"] = call_qualifier;
                                }
                                add_edge(
                                    caller_nid,
                                    call_target,
                                    "references",
                                    call_line,
                                    context="generic_arg",
                                    metadata=call_meta,
                                );
                            }
                        }
                    }
                }
            } elif ts_mod == "tree_sitter_php" {
                if ntype == "function_call_expression" {
                    func_node: any = wn.child_by_field_name("function");
                    if func_node {
                        callee_name = _read_text(func_node, source);
                        if callee_name.lower() in _PHP_LANGUAGE_CONSTRUCTS {
                            callee_name = None;
                        }
                    }
                } elif ntype == "scoped_call_expression" {
                    is_member_call = True;
                    is_scoped_call = True;
                    name_node = wn.child_by_field_name("name");
                    if name_node {
                        callee_name = _read_text(name_node, source);
                    }
                    scope_node: any = wn.child_by_field_name("scope");
                    if scope_node {
                        member_receiver = _read_text(scope_node, source);
                    }
                } else {
                    is_member_call = True;
                    name_node = wn.child_by_field_name("name");
                    if name_node {
                        callee_name = _read_text(name_node, source);
                    }
                    receiver: any = wn.child_by_field_name("object");
                    if receiver is not None
                        and _read_text(receiver, source) == "$this"
                        and callee_name
                        and callee_name.casefold() in _LANGUAGE_BUILTIN_GLOBALS
                    {
                        self_receiver = "this";
                    }
                    `obj: any = wn.child_by_field_name("object");
                    if `obj is not None and `obj.type == "variable_name" {
                        member_receiver = _php_variable_text(`obj, source);
                    } elif `obj is not None and `obj.type == "member_access_expression" {
                        inner = `obj.child_by_field_name("object");
                        if inner is not None
                            and inner.type == "variable_name"
                            and _php_variable_text(inner, source) == "this"
                        {
                            member_receiver = _read_text(`obj.child_by_field_name("name"), source);
                        }
                    }
                }
            } elif ts_mod == "tree_sitter_cpp" {
                cpp_chain: any = [];
                cpp_binding: any = None;
                func_node = wn.child_by_field_name(config.call_function_field)
                    if config.call_function_field
                    else None;
                if func_node {
                    if func_node.type in ("identifier", "template_function") {
                        callee_name = _cpp_call_name(func_node, source);
                        if callee_name
                            and `any(
                                _span[0] <= wn.start_byte and wn.start_byte < _span[1]
                                for _span in cpp_local_bindings.get(caller_nid, {}).get(
                                    callee_name, ()
                                ),
                            )
                        {
                            callee_name = None;
                        }
                    } elif func_node.type == "field_expression" {
                        is_member_call = True;
                        name: any = func_node.child_by_field_name("field");
                        if name {
                            callee_name = _cpp_call_name(name, source);
                        }
                        cpp_chain = _cpp_receiver_chain(func_node, source);
                        if cpp_chain {
                            member_receiver = cpp_chain[0][0];
                            bindings: any = [
                                b
                                for b in cpp_local_bindings.get(caller_nid, {}).get(
                                    member_receiver, ()
                                )
                                if b[0] <= `node.start_byte < b[1]
                            ];
                            cpp_binding = max(bindings, key=lambda (b) -> any { b[0] })
                                if bindings
                                else None;
                        }
                    } elif func_node.type == "qualified_identifier" {
                        is_member_call = True;
                        name = func_node.child_by_field_name("name");
                        if name {
                            callee_name = _cpp_call_name(name, source);
                        }
                        scope: any = func_node.child_by_field_name("scope");
                        if scope is not None {
                            member_receiver = _read_text(scope, source);
                            if _cpp_type_is_dependent(scope, source) {
                                callee_name = None;
                            }
                        }
                    }
                }
            } elif ts_mod == "tree_sitter_java" {
                if ntype == "object_creation_expression" {
                    type_node: any = wn.child_by_field_name("type");
                    if type_node is not None {
                        raw = _read_text(type_node, source).split("<", 1)[0].strip();
                        if raw {
                            callee_name = raw.rsplit(".", 1)[-1];
                        }
                    }
                } elif ntype == "method_invocation" {
                    name_node = wn.child_by_field_name("name");
                    if name_node is not None {
                        callee_name = _read_text(name_node, source);
                    }
                    receiver = wn.child_by_field_name("object");
                    if receiver is not None {
                        is_member_call = True;
                        if receiver.type == "identifier" {
                            member_receiver = _read_text(receiver, source);
                        } elif receiver.type in ("this", "super") {
                            member_receiver = receiver.type;
                        } elif receiver.type == "field_access" {
                            owner: any = receiver.child_by_field_name("object");
                            field = receiver.child_by_field_name("field");
                            if owner is not None and owner.type == "this" and field is not None {
                                member_receiver = f"this.{_read_text(field, source)}";
                                is_this_field_call = True;
                            } else {
                                java_receiver_chain = _java_receiver_chain(receiver, source);
                            }
                        } else {
                            java_receiver_chain = _java_receiver_chain(receiver, source);
                        }
                    }
                }
            } elif ts_mod == "tree_sitter_ruby" {
                meth: any = wn.child_by_field_name("method");
                if meth is not None {
                    callee_name = _read_text(meth, source);
                }
                recv = wn.child_by_field_name("receiver");
                if recv is None or recv.type == "self" {
                    self_receiver = "self";
                }
                if recv is not None {
                    is_member_call = True;
                    if recv.type in ("identifier", "constant") {
                        member_receiver = _read_text(recv, source);
                    } elif recv.type == "scope_resolution" {
                        member_receiver = _ruby_const_full_name(recv, source) or None;
                    }
                }
            } else {
                func_node = wn.child_by_field_name(config.call_function_field)
                    if config.call_function_field
                    else None;
                if func_node is None and ntype == "new_expression" {
                    func_node = wn.child_by_field_name("constructor");
                }
                if ntype in _JSX_ELEMENT_TYPES {
                    func_node = wn.child_by_field_name("name");
                    if func_node is None
                        or func_node.type != "identifier"
                        or _read_text(func_node, source)[:1].islower()
                    {
                        func_node = None;
                    }
                }
                if func_node {
                    if func_node.type == "identifier" {
                        callee_name = _read_text(func_node, source);
                    } elif ts_mod == "tree_sitter_c"
                        and func_node.type == "field_expression"
                    {
                        callee_name = None;
                    } elif func_node.type in config.call_accessor_node_types {
                        is_member_call = True;
                        if config.call_accessor_field {
                            attr: any = func_node.child_by_field_name(config.call_accessor_field);
                            if attr {
                                callee_name = _read_text(attr, source);
                            }
                        }
                        if config.call_accessor_object_field {
                            `obj = func_node.child_by_field_name(config.call_accessor_object_field);
                            if `obj is not None and `obj.type == "identifier" {
                                member_receiver = _read_text(`obj, source);
                                if ts_mod
                                    in ("tree_sitter_javascript", "tree_sitter_typescript")
                                {
                                    _this_field: any = _ts_field_destructured_from_this(
                                        `obj, member_receiver, source
                                    );
                                    if _this_field {
                                        member_receiver = _this_field;
                                        is_this_field_call = True;
                                    }
                                }
                            } elif `obj is not None
                                and `obj.type in ("this", "super")
                                and ts_mod in _SELF_CALL_LANGUAGES
                            {
                                self_receiver = `obj.type;
                            } elif ts_mod == "tree_sitter_python"
                                and `obj is not None
                                and `obj.type == "call"
                            {
                                receiver_func: any = `obj.child_by_field_name("function");
                                if receiver_func is not None
                                    and receiver_func.type == "identifier"
                                    and _read_text(receiver_func, source) == "super"
                                {
                                    member_receiver = "super";
                                }
                            } elif `obj is not None
                                and `obj.type in config.call_accessor_node_types
                                and config.call_accessor_object_field
                            {
                                inner_obj: any = `obj.child_by_field_name(
                                    config.call_accessor_object_field
                                );
                                if inner_obj is not None and inner_obj.type == "this" {
                                    inner_prop: any = `obj.child_by_field_name(
                                        config.call_accessor_field
                                    );
                                    if inner_prop is not None {
                                        member_receiver = _read_text(inner_prop, source);
                                        is_this_field_call = True;
                                    }
                                }
                            }
                        }
                    } else {
                        callee_name = _read_text(func_node, source);
                    }
                }
            }
            if ts_mod == "tree_sitter_lua"
                and is_member_call
                and member_receiver == "self"
                and callee_name
            {
                _self_table: any = lua_self_table.get(caller_nid);
                if _self_table {
                    _dot: any = f"{_self_table}.{callee_name}";
                    callee_name = f"{_self_table}:{callee_name}";
                    if callee_name not in label_to_nid and _dot in label_to_nid {
                        callee_name = _dot;
                    }
                    member_receiver = None;
                    lua_self_qualified = True;
                }
            }
            _builtin_member_call: any = is_member_call and callee_name in _LANGUAGE_BUILTIN_GLOBALS;
            php_builtin_self_call: any = operator.eq(ts_mod, "tree_sitter_php")
                and operator.eq(self_receiver, "this");
            _python_param_call: any = python_param_shadowed is not None
                and not is_member_call
                and `bool(callee_name)
                and python_param_shadowed(`node, callee_name);
            if callee_name
                and not _python_param_call
                and (callee_name not in _LANGUAGE_BUILTIN_GLOBALS or _builtin_member_call)
                and not (
                    ts_mod == "tree_sitter_python"
                    and not is_member_call
                    and _python_lambda_param_shadows(`node, callee_name)
                )
            {
                _csharp_defer: any = operator.eq(ts_mod, "tree_sitter_c_sharp")
                    and is_member_call;
                _python_defer: any = operator.eq(ts_mod, "tree_sitter_python")
                    and is_member_call
                    and member_receiver not in {"self", "cls", "super"};
                _java_defer: any = operator.eq(ts_mod, "tree_sitter_java")
                    and is_member_call;
                _kotlin_member_defer: any = operator.eq(ts_mod, "tree_sitter_kotlin")
                    and is_member_call
                    and kotlin_receiver is not None;
                _swift_defer: any = operator.eq(ts_mod, "tree_sitter_swift")
                    and is_member_call
                    and not self_receiver;
                _lua_member_defer: any = operator.eq(ts_mod, "tree_sitter_lua")
                    and is_member_call
                    and not lua_self_qualified;
                _js_factory_sibling_call: any = False;
                if ts_mod in ("tree_sitter_javascript", "tree_sitter_typescript")
                    and is_member_call
                    and member_receiver
                {
                    _owner: any = method_owner.get(caller_nid);
                    if _owner is not None
                        and _make_id(js_factory_scope.get(_owner, ""), member_receiver) == _owner
                    {
                        _js_factory_sibling_call = True;
                    }
                }
                _js_member_defer: any = ts_mod
                    in ("tree_sitter_javascript", "tree_sitter_typescript")
                    and is_member_call
                    and not self_receiver
                    and not _js_factory_sibling_call;
                _cpp_member_defer: any = operator.eq(ts_mod, "tree_sitter_cpp")
                    and is_member_call
                    and not is_scoped_call
                    and func_node is not None
                    and operator.eq(func_node.type, "field_expression")
                    and (
                        operator.ne(len(cpp_chain), 1)
                        or operator.eq(member_receiver, "this")
                        or member_receiver in type_table
                        or name is not None and operator.ne(name.type, "field_identifier")
                        or cpp_binding is not None and (`bool(cpp_binding[2]) or cpp_binding[5])
                        or cpp_binding is None
                            and member_receiver
                                in cpp_unknown_fields.get(method_owner.get(caller_nid, ""), ())
                    );
                if _python_defer
                    or _java_defer
                    or _csharp_defer
                    or _kotlin_member_defer
                    or _swift_defer
                    or _js_member_defer
                    or _cpp_member_defer
                    or _builtin_member_call and not php_builtin_self_call
                    or _lua_member_defer
                    or is_scoped_call
                    or is_member_call
                        and member_receiver
                        and (member_receiver[:1].isupper() or is_this_field_call)
                {
                    tgt_nid: any = None;
                    if _kotlin_member_defer and not _builtin_member_call {
                        if kotlin_receiver_type {
                            owners: any = kotlin_types_by_label.get(kotlin_receiver_type, []);
                            if len(owners) == 1 {
                                tgt_nid = kotlin_methods_by_owner.get((owners[0], callee_name));
                            }
                        } elif kotlin_callable_counts.get(callee_name) == 1 {
                            tgt_nid = label_to_nid.get(callee_name);
                        }
                    }
                } else {
                    if ts_mod
                        in (
                            "tree_sitter_python",
                            "tree_sitter_javascript",
                            "tree_sitter_typescript",
                        )
                        and not is_member_call
                    {
                        curr_scope: any = caller_nid;
                        tgt_nid = None;
                        while curr_scope {
                            if curr_scope in lexical_nids_by_scope
                                and callee_name in lexical_nids_by_scope[curr_scope]
                            {
                                tgt_nid = lexical_nids_by_scope[curr_scope][callee_name];
                                break;
                            }
                            curr_scope = scope_parents.get(curr_scope);
                        }
                        if not tgt_nid {
                            tgt_nid = label_to_nid.get(callee_name);
                        }
                        if ts_mod == "tree_sitter_python"
                            and tgt_nid in method_owner
                            and method_owner[tgt_nid] != caller_nid
                        {
                            tgt_nid = python_free_label_to_nid.get(callee_name);
                        }
                    } elif self_receiver
                        or ts_mod == "tree_sitter_python"
                            and is_member_call
                            and member_receiver in ("self", "cls", "super")
                    {
                        tgt_nid = _self_call_target(
                            caller_nid,
                            callee_name.casefold() if php_builtin_self_call else callee_name,
                            self_receiver or member_receiver or "",
                            label_to_nid,
                            scope_parents,
                            method_owner,
                            methods_by_owner,
                            _local_bases,
                            walk_bases=ts_mod
                                not in ("tree_sitter_javascript", "tree_sitter_typescript"),
                            require_method_owner=php_builtin_self_call,
                        );
                        if php_builtin_self_call and tgt_nid not in method_owner {
                            tgt_nid = None;
                        }
                    } elif lexical_calls and not is_member_call {
                        tgt_nid = _lexical_call_target(
                            caller_nid,
                            callee_name,
                            label_to_nid,
                            method_owner,
                            methods_by_owner,
                            lexical_bases,
                            class_parent,
                        );
                    } elif _js_factory_sibling_call {
                        tgt_nid = methods_by_owner.get((method_owner.get(caller_nid), callee_name));
                    } else {
                        tgt_nid = label_to_nid.get(callee_name);
                    }
                    if csharp_qualified_prefix and tgt_nid and not nid_to_sf.get(tgt_nid) {
                        tgt_nid = None;
                    }
                    if ts_mod == "tree_sitter_c_sharp"
                        and ntype == "object_creation_expression"
                        and tgt_nid in method_owner
                    {
                        tgt_nid = None;
                    }
                }
                if tgt_nid in csharp_overload_peers {
                    peers: any = csharp_overload_peers[tgt_nid];
                    picked: any = _csharp_pick_overload(
                        peers,
                        _java_argc(`node)
                            if ts_mod == "tree_sitter_java"
                            else _csharp_argc(`node),
                    );
                    tgt_nid = (picked or peers[0])["id"];
                }
                if ts_mod == "tree_sitter_c_sharp"
                    and ntype == "object_creation_expression"
                    and callee_name
                {
                    csharp_ctor_records.append({
                        "caller_nid": caller_nid,
                        "lang": "csharp",
                        "csharp_ctor_site": callee_name,
                        "arity": _csharp_creation_argc(`node),
                        "source_file": str_path,
                        "source_location": f"L{wn.start_point[0] + 1}",
                    });
                }
                external_stub_target: any = `bool(tgt_nid and not nid_to_sf.get(tgt_nid));
                if tgt_nid and not external_stub_target {
                    pair: any = (caller_nid, tgt_nid);
                    if preserve_call_sites or pair not in seen_call_pairs {
                        seen_call_pairs.add(pair);
                        line: any = wn.start_point[0] + 1;
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
                } elif callee_name and (not tgt_nid or external_stub_target) {
                    is_py_local_data: any = operator.eq(ts_mod, "tree_sitter_python")
                        and not is_member_call
                        and callee_name
                            in local_bound_names.get(caller_nid, frozenset()) | extra_locals;
                    if not is_py_local_data {
                        rc_entry: any = {
                            "caller_nid": caller_nid,
                            "callee": callee_name,
                            "is_member_call": is_member_call,
                            "source_file": str_path,
                            "source_location": f"L{wn.start_point[0] + 1}",
                            "receiver": swift_receiver or member_receiver,
                        };
                        if ts_mod in ("tree_sitter_javascript", "tree_sitter_typescript")
                            and is_member_call
                        {
                            rc_entry["_js_receiver_shadowed"] = _js_receiver_shadowed(
                                `node, member_receiver, source, js_receiver_bindings
                            );
                            rc_entry["_js_construct"] = operator.eq(ntype, "new_expression");
                        }
                        if python_receiver_shadowed is not None and is_member_call {
                            rc_entry["_python_receiver_shadowed"] = python_receiver_shadowed(
                                `node, member_receiver or ""
                            );
                        }
                        if ts_mod == "tree_sitter_python" and is_member_call {
                            _fn: any = wn.child_by_field_name("function");
                            _recv: any = _fn.child_by_field_name("object")
                                if _fn is not None
                                else None;
                            _fields: any = python_attr_types.get(
                                method_owner.get(caller_nid, ""), {}
                            );
                            _attr_type: any = _fields.get(_python_self_attr(_recv, source) or "");
                            if _attr_type {
                                rc_entry["_python_self_attr_type"] = _attr_type;
                            }
                        }
                        if external_stub_target {
                            rc_entry["via_stub"] = True;
                        }
                        if member_receiver and ts_mod == "tree_sitter_ruby" {
                            rc_entry["receiver_type"] = ruby_var_types.get(caller_nid, {}).get(
                                member_receiver
                            );
                        }
                        if member_receiver and ts_mod == "tree_sitter_python" {
                            _py_type: any = python_var_types.get(caller_nid, {}).get(
                                member_receiver
                            );
                            if _py_type {
                                rc_entry["receiver_type"] = _py_type;
                            } elif member_receiver in python_factory_bindings.get(caller_nid, {}) {
                                rc_entry["_python_receiver_factory"] = python_factory_bindings[caller_nid][member_receiver];
                            } elif member_receiver in python_fixture_params.get(caller_nid, ()) {
                                rc_entry["_python_fixture_param"] = True;
                            } elif member_receiver in python_module_instances {
                                class_name: any;
                                shadowed: any;
                                (
                                    class_name,
                                    shadowed,
                                ) = python_module_instances[member_receiver] as any;
                                if not shadowed(`node, member_receiver) {
                                    rc_entry["receiver_type"] = class_name;
                                    rc_entry["_python_module_instance"] = True;
                                }
                            }
                        }
                        if ts_mod == "tree_sitter_python" {
                            rc_entry["_python_call_site"] = [wn.start_byte, wn.end_byte];
                        }
                        if member_receiver == "super" and ts_mod == "tree_sitter_python" {
                            _sfn: any = wn.child_by_field_name("function");
                            _sobj: any = _sfn.child_by_field_name("object")
                                if _sfn is not None
                                else None;
                            _sargs: any = _sobj.child_by_field_name("arguments")
                                if _sobj is not None
                                else None;
                            if _sargs is not None and `any(c.is_named for c in typing.cast(object, _sargs).children) {
                                rc_entry["_python_super_args"] = True;
                            }
                        }
                        if is_this_field_call
                            and ts_mod
                                in ("tree_sitter_javascript", "tree_sitter_typescript")
                        {
                            rc_entry["ts_this_field"] = True;
                            if _ts_in_static_method(`node) {
                                rc_entry["ts_static_this"] = True;
                            }
                        }
                        if ts_mod == "tree_sitter_cpp" {
                            rc_entry["lang"] = "cpp";
                            rc_entry["cpp_call_byte"] = wn.start_byte;
                            rc_entry["cpp_call_scope"] = _cpp_lookup_scope(`node, source);
                            rc_entry["cpp_scoped_call"] = func_node is not None
                                and operator.eq(func_node.type, "qualified_identifier");
                            if func_node is not None and func_node.type == "field_expression" {
                                rc_entry["cpp_receiver_chain"] = cpp_chain;
                                if cpp_binding is not None {
                                    rc_entry["cpp_receiver_type"] = cpp_binding[2];
                                    rc_entry["cpp_receiver_scope"] = cpp_binding[3];
                                    rc_entry["cpp_receiver_byte"] = cpp_binding[0];
                                }
                            }
                        }
                        if ts_mod == "tree_sitter_php" {
                            rc_entry["php_scoped"] = is_scoped_call;
                        }
                        if ts_mod == "tree_sitter_c_sharp" {
                            rc_entry["lang"] = "csharp";
                            argc: any = _csharp_argc(`node);
                            if argc is not None {
                                rc_entry["arity"] = argc;
                            }
                            if ntype == "object_creation_expression" {
                                rc_entry["csharp_new"] = True;
                            }
                            if csharp_qualified_prefix {
                                rc_entry["qualified_prefix"] = csharp_qualified_prefix;
                            }
                            if csharp_receiver_chain {
                                rc_entry["receiver_chain"] = csharp_receiver_chain;
                            }
                            receiver_type: any = _csharp_scoped_receiver_type(
                                receiver_types, member_receiver, wn.start_byte
                            );
                            if isinstance(receiver_type, `list) and receiver_type[0] == "member" {
                                _: any;
                                member: any;
                                _unused: any;
                                (_, recv, member, _unused) = receiver_type as any;
                                csharp_scope: any = receiver_types
                                    if isinstance(receiver_types, `tuple)
                                    else None;
                                recv_t: any = _csharp_scoped_receiver_type(
                                    csharp_scope, recv, wn.start_byte
                                );
                                if isinstance(recv_t, `str) {
                                    rc_entry["receiver_var_chain"] = [recv_t, member];
                                } elif recv_t is None
                                    and csharp_scope is not None
                                    and not _csharp_receiver_is_declared(
                                        csharp_scope, recv, wn.start_byte
                                    )
                                {
                                    rc_entry["receiver_var_chain"] = [recv, member];
                                }
                            } elif isinstance(receiver_type, `list) {
                                method: any;
                                targs: any;
                                (_, recv, method, targs) = receiver_type as any;
                                if recv and recv != "this" {
                                    recv_t = _csharp_scoped_receiver_type(
                                        receiver_types
                                            if isinstance(receiver_types, `tuple)
                                            else None,
                                        recv,
                                        wn.start_byte,
                                    );
                                    if isinstance(recv_t, `str) {
                                        recv = recv_t;
                                    } elif recv_t is not None or not recv[:1].isupper() {
                                        recv = None;
                                    }
                                }
                                if recv is not None {
                                    rc_entry["receiver_call"] = [recv, method, targs];
                                }
                            } elif receiver_type {
                                rc_entry["receiver_type"] = receiver_type;
                            } elif member_receiver
                                and not _csharp_receiver_is_declared(
                                    receiver_types if isinstance(receiver_types, `tuple) else None,
                                    member_receiver,
                                    wn.start_byte,
                                )
                            {
                                rc_entry["receiver_undeclared"] = True;
                            }
                        }
                        if ts_mod == "tree_sitter_java" {
                            rc_entry["lang"] = "java";
                            java_argc: any = _java_argc(`node);
                            if java_argc is not None {
                                rc_entry["arity"] = java_argc;
                            }
                            field_names: any = `set(
                                _fields_up_chain(
                                    _java_field_name_tables,
                                    method_owner.get(caller_nid, caller_nid),
                                ),
                            )
                                - extra_locals;
                            if member_receiver
                                and (is_this_field_call or member_receiver in field_names)
                            {
                                rc_entry["receiver_field"] = member_receiver.removeprefix("this.");
                            }
                            receiver_type = (receiver_types or {}).get(member_receiver or "");
                            if receiver_type {
                                rc_entry["receiver_type"] = receiver_type;
                            } elif is_member_call
                                and member_receiver
                                and member_receiver.isidentifier()
                                and member_receiver not in java_bound_names.get(caller_nid, ())
                            {
                                rc_entry["receiver_unbound"] = True;
                            }
                            if java_receiver_chain {
                                chain: any = _java_type_chain_leaf(
                                    java_receiver_chain,
                                    receiver_types if isinstance(receiver_types, `dict) else {},
                                    java_bound_names.get(caller_nid),
                                    field_names,
                                );
                                if chain {
                                    rc_entry["java_receiver_chain"] = chain;
                                }
                            }
                        }
                        if kotlin_qualified_prefix {
                            rc_entry["lang"] = "kotlin";
                            rc_entry["qualified_prefix"] = kotlin_qualified_prefix;
                        }
                        if kotlin_object_receiver {
                            rc_entry["lang"] = "kotlin";
                            rc_entry["kotlin_object_receiver"] = kotlin_object_receiver;
                        }
                        if kotlin_receiver_type {
                            rc_entry["lang"] = "kotlin";
                            rc_entry["kotlin_receiver_type"] = kotlin_receiver_type;
                        }
                        raw_calls.append(rc_entry);
                    }
                }
            }
            if ts_mod == "tree_sitter_python" {
                args_node: any = wn.child_by_field_name("arguments");
                if args_node is not None {
                    enclosing_locals: any = local_bound_names.get(caller_nid, frozenset())
                        | extra_locals;
                    arg: any;
                    for arg in typing.cast(object, args_node).children {
                        if arg.type == "identifier" {
                            _emit_indirect_ref(arg, caller_nid, enclosing_locals, "argument");
                        } elif arg.type == "keyword_argument" {
                            _emit_indirect_ref(
                                arg.child_by_field_name("value"),
                                caller_nid,
                                enclosing_locals,
                                "argument",
                            );
                        }
                    }
                }
                getattr_ref: any = _getattr_ref_name(`node);
                if getattr_ref is not None {
                    ref_name: any;
                    loc: any;
                    (ref_name, loc) = getattr_ref as any;
                    _emit_indirect_by_name(ref_name, loc, caller_nid, "getattr");
                }
            } elif ts_mod in ("tree_sitter_javascript", "tree_sitter_typescript") {
                args_node = wn.child_by_field_name("arguments");
                if args_node is not None {
                    enclosing_locals = local_bound_names.get(caller_nid, frozenset())
                        | extra_locals;
                    for arg in typing.cast(object, args_node).children {
                        if arg.type == "identifier" {
                            _emit_indirect_ref(arg, caller_nid, enclosing_locals, "argument");
                        }
                    }
                }
            }
            if callee_name and callee_name in config.helper_fn_names {
                args_node = wn.child_by_field_name("arguments");
                first_key: str | None = None;
                if args_node {
                    for arg in typing.cast(object, args_node).children {
                        if arg.type != "argument" {
                            continue;
                        }
                        for inner in typing.cast(object, arg).children {
                            if inner.type == "string" {
                                for sc in typing.cast(object, inner).children {
                                    if sc.type == "string_content" {
                                        first_key = _read_text(sc, source);
                                        break;
                                    }
                                }
                                break;
                            }
                        }
                        if first_key {
                            break;
                        }
                    }
                }
                if first_key {
                    segment: any = first_key.split(".")[0];
                    tgt_nid = label_to_nid_ci.get(segment.lower())
                        or label_to_nid_ci.get(f"{segment}.php".lower());
                    if tgt_nid and tgt_nid != caller_nid {
                        relation: any = f"uses_{callee_name}";
                        pair3: any = (caller_nid, tgt_nid, relation);
                        if pair3 not in seen_helper_ref_pairs {
                            seen_helper_ref_pairs.add(pair3);
                            line = wn.start_point[0] + 1;
                            edges.append({
                                "source": caller_nid,
                                "target": tgt_nid,
                                "relation": relation,
                                "confidence": "EXTRACTED",
                                "confidence_score": 1.0,
                                "source_file": str_path,
                                "source_location": f"L{line}",
                                "weight": 1.0,
                            });
                        }
                    }
                }
            }
            if ntype == "member_call_expression"
                and callee_name
                and callee_name in config.container_bind_methods
            {
                args_node = wn.child_by_field_name("arguments");
                class_args: list[str] = [];
                if args_node {
                    for arg in typing.cast(object, args_node).children {
                        if arg.type != "argument" {
                            continue;
                        }
                        for inner in typing.cast(object, arg).children {
                            if inner.type == "class_constant_access_expression" {
                                cls: any = _php_class_const_scope(inner);
                                if cls {
                                    class_args.append(cls);
                                }
                                break;
                            }
                        }
                        if len(class_args) >= 2 {
                            break;
                        }
                    }
                }
                if len(class_args) == 2 {
                    contract_name: any;
                    impl_name: any;
                    (contract_name, impl_name) = class_args as any;
                    contract_nid: any = label_to_nid_ci.get(contract_name.lower());
                    impl_nid: any = label_to_nid_ci.get(impl_name.lower());
                    if contract_nid and impl_nid and contract_nid != impl_nid {
                        pair3 = (contract_nid, impl_nid, "bound_to");
                        if pair3 not in seen_bind_pairs {
                            seen_bind_pairs.add(pair3);
                            line = wn.start_point[0] + 1;
                            edges.append({
                                "source": contract_nid,
                                "target": impl_nid,
                                "relation": "bound_to",
                                "confidence": "EXTRACTED",
                                "confidence_score": 1.0,
                                "source_file": str_path,
                                "source_location": f"L{line}",
                                "weight": 1.0,
                            });
                        }
                    }
                }
            }
        }
        if ntype in config.static_prop_types {
            scope_node = wn.child_by_field_name("scope");
            if scope_node is None {
                for child in wn.children {
                    if child.is_named and child.type in ("name", "qualified_name", "identifier") {
                        scope_node = child;
                        break;
                    }
                }
            }
            if scope_node is not None {
                class_name = _read_text(scope_node, source);
                tgt_nid = label_to_nid_ci.get(class_name.lower());
                if tgt_nid and tgt_nid != caller_nid {
                    pair3 = (caller_nid, tgt_nid, "uses_static_prop");
                    if pair3 not in seen_static_ref_pairs {
                        seen_static_ref_pairs.add(pair3);
                        line = wn.start_point[0] + 1;
                        edges.append({
                            "source": caller_nid,
                            "target": tgt_nid,
                            "relation": "uses_static_prop",
                            "confidence": "EXTRACTED",
                            "confidence_score": 1.0,
                            "source_file": str_path,
                            "source_location": f"L{line}",
                            "weight": 1.0,
                        });
                    }
                }
            }
        }
        if ts_mod == "tree_sitter_php"
            and ntype == "class_constant_access_expression"
        {
            class_name = _php_class_const_scope(`node);
            if class_name {
                tgt_nid = label_to_nid_ci.get(class_name.lower());
                if tgt_nid and tgt_nid != caller_nid {
                    pair3 = (caller_nid, tgt_nid, "references_constant");
                    if pair3 not in seen_static_ref_pairs {
                        seen_static_ref_pairs.add(pair3);
                        line = wn.start_point[0] + 1;
                        edges.append({
                            "source": caller_nid,
                            "target": tgt_nid,
                            "relation": "references_constant",
                            "confidence": "EXTRACTED",
                            "confidence_score": 1.0,
                            "source_file": str_path,
                            "source_location": f"L{line}",
                            "weight": 1.0,
                        });
                    }
                }
            }
        }
        if ts_mod == "tree_sitter_python"
            and ntype in ("dictionary", "list", "set", "tuple")
        {
            enclosing_locals = local_bound_names.get(caller_nid, frozenset()) | extra_locals;
            ident: any;
            for ident in _python_dispatch_value_idents(`node) {
                _emit_indirect_ref(ident, caller_nid, enclosing_locals, "collection");
            }
            for attr in _python_dispatch_value_attrs(`node) {
                _emit_indirect_member_ref(attr, caller_nid, enclosing_locals, "collection");
            }
        } elif ts_mod in ("tree_sitter_javascript", "tree_sitter_typescript")
            and ntype in ("object", "array")
        {
            enclosing_locals = local_bound_names.get(caller_nid, frozenset()) | extra_locals;
            for ident in _js_dispatch_value_idents(`node) {
                _emit_indirect_ref(ident, caller_nid, enclosing_locals, "collection");
            }
        }
        if ts_mod == "tree_sitter_python" and ntype == "assignment" {
            enclosing_locals = local_bound_names.get(caller_nid, frozenset()) | extra_locals;
            for ident in _python_ref_value_idents(wn.child_by_field_name("right")) {
                _emit_indirect_ref(ident, caller_nid, enclosing_locals, "assignment");
            }
        } elif ts_mod == "tree_sitter_python" and ntype == "return_statement" {
            enclosing_locals = local_bound_names.get(caller_nid, frozenset()) | extra_locals;
            value: any = next((c for c in wn.children if c.is_named), None);
            for ident in _python_ref_value_idents(value) {
                _emit_indirect_ref(ident, caller_nid, enclosing_locals, "return");
            }
        }
        if ts_mod in ("tree_sitter_javascript", "tree_sitter_typescript")
            and ntype == "catch_clause"
        {
            param: any = wn.child_by_field_name("parameter");
            if param is not None {
                caught: set[str] = set[any]();
                _js_collect_pattern_idents(param, source, caught);
                extra_locals = extra_locals | frozenset(caught);
            }
        }
        if ts_mod in ("tree_sitter_javascript", "tree_sitter_typescript")
            and ntype in ("statement_block", "for_statement")
        {
            block_locals: any = _js_direct_lexical_names(`node, source);
            if block_locals {
                extra_locals = extra_locals | block_locals;
            }
        }
        if ts_mod in ("tree_sitter_javascript", "tree_sitter_typescript")
            and ntype == "for_in_statement"
        {
            left: any = wn.child_by_field_name("left");
            if left is not None {
                loop_locals: set[str] = set[any]();
                _js_collect_pattern_idents(left, source, loop_locals);
                if loop_locals {
                    extra_locals = extra_locals | frozenset(loop_locals);
                }
            }
        }

        for child in wn.children {
            walk_calls(child, caller_nid, receiver_types, extra_locals);
        }
    }
    python_attr_types = {};
    python_factory_bindings = {};
    if ts_mod == "tree_sitter_python" {
        caller_nid: any;
        body_node: any;
        for (caller_nid, body_node) in function_bodies {
            factories: dict[str, list[int]] = {};
            python_var_types[caller_nid] = _python_local_class_bindings(
                body_node, source, factory_bindings=factories
            );
            python_factory_bindings[caller_nid] = factories;
            if caller_nid in method_owner {
                fields: any = python_attr_types.setdefault(method_owner[caller_nid], {});
                for (attr, type_name) in _python_self_attr_bindings(
                    body_node, source, python_var_types[caller_nid]
                ) {
                    fields[attr] = type_name if fields.get(attr, type_name) == type_name else None;
                }
            }
        }
    }

    if ts_mod == "tree_sitter_ruby" {
        for (caller_nid, body_node) in function_bodies {
            ruby_var_types[caller_nid] = _ruby_local_class_bindings(body_node, source);
            ruby_local_names[caller_nid] = _ruby_local_names(body_node, source);
        }
    }

    if ts_mod == "tree_sitter_python" {
        _py_node_by_id: any = {n["id"]: n for n in nodes};
        _py_test_module: any = _python_is_test_module(str_path);
        for (caller_nid, body_node) in function_bodies {
            func: any = getattr(body_node, "parent", None);
            if func is None or func.type != "function_definition" {
                continue;
            }
            return_class: any = _python_class_ref(func.child_by_field_name("return_type"), source);
            if caller_nid in _py_node_by_id and return_class {
                _py_node_by_id[caller_nid]["_py_return_type"] = return_class;
            }
            if caller_nid in _py_node_by_id and _python_is_property(func, source) {
                _py_node_by_id[caller_nid]["_py_property"] = True;
            }
            if not _py_test_module {
                continue;
            }
            is_fixture: any = _python_is_pytest_fixture(func, source);
            if is_fixture and caller_nid in _py_node_by_id {
                _py_node_by_id[caller_nid]["_py_fixture"] = _python_fixture_type(
                    func, source, python_var_types[caller_nid]
                );
            }
            name_n: any = func.child_by_field_name("name");
            if is_fixture or name_n is not None and _read_text(name_n, source).startswith("test") {
                python_fixture_params[caller_nid] = _python_untouched_params(func, source);
            }
        }
    }
    cpp_local_bindings = {};
    cpp_unknown_fields = {};
    if ts_mod == "tree_sitter_cpp" {
        cpp_unknown_fields = {
            n["id"]: {name for (name, value) in n.get("_cpp_fields", {}).items() if not value}
            for n in nodes
            if "_cpp_fields" in n
        };
        conflicting = set[any]();

        def _fold(table: dict[str, str]) {
            for (var, type_name) in table.items() {
                if not type_name or type_table.setdefault(var, type_name) != type_name {
                    conflicting.add(var);
                }
            }
        }

        _caller_nid: any;
        for (_caller_nid, body_node) in function_bodies {
            fn_table: dict[str, str] = {};
            _cpp_local_var_types(body_node, source, fn_table);
            _cpp_parameter_types(body_node, source, fn_table);
            _fold(fn_table);
            cpp_local_bindings[_caller_nid] = _cpp_local_binding_ranges(body_node, source);
        }
        field_table: dict[str, str] = {};
        _cpp_field_types(`root, source, field_table);
        _fold(field_table);
        for var in conflicting {
            type_table.pop(var, None);
        }
    }
    if ts_mod == "tree_sitter_swift" {
        for (_caller_nid, body_node) in function_bodies {
            _swift_local_var_types(body_node, source, type_table, factory=swift_factory_bindings);
        }
    }
    _tracked_body_ids.update(b for (_, b) in function_bodies);
    receiver_types_by_body: any = {**java_receiver_types, **csharp_receiver_types};
    for (caller_nid, body_node) in function_bodies {
        walk_calls(
            body_node,
            caller_nid,
            receiver_types_by_body.get(id(body_node)),
            frozenset(closure_locals_by_body.get(id(body_node), ()))
                | frozenset(java_local_names_by_body.get(id(body_node), ())),
        );
    }
    for (owner_nid, init_node) in initializer_nodes {
        walk_calls(init_node, owner_nid);
    }
    seen_listen_pairs: set[tuple[str, str]] = set[any]();
    for (event_name, listener_name, line) in pending_listen_edges {
        event_nid: any = label_to_nid_ci.get(event_name.lower());
        listener_nid: any = label_to_nid_ci.get(listener_name.lower());
        if not event_nid or not listener_nid or event_nid == listener_nid {
            continue;
        }
        pair2: any = (event_nid, listener_nid);
        if pair2 in seen_listen_pairs {
            continue;
        }
        seen_listen_pairs.add(pair2);
        edges.append({
            "source": event_nid,
            "target": listener_nid,
            "relation": "listened_by",
            "confidence": "EXTRACTED",
            "confidence_score": 1.0,
            "source_file": str_path,
            "source_location": f"L{line}",
            "weight": 1.0,
        });
    }
    if ts_mod == "tree_sitter_python" {
        module_bound = _python_module_bound_names(`root, source);

        def _scan_module_dispatch(n) {
            if n.type in ("function_definition", "class_definition") {
                return;
            }
            if n.type in ("dictionary", "list", "set", "tuple") {
                ident: any;
                for ident in _python_dispatch_value_idents(n) {
                    _emit_indirect_ref(ident, file_nid, module_bound, "collection");
                }
                for attr in _python_dispatch_value_attrs(n) {
                    _emit_indirect_member_ref(attr, file_nid, module_bound, "collection");
                }
            } elif n.type == "assignment" {
                for ident in _python_ref_value_idents(n.child_by_field_name("right")) {
                    _emit_indirect_ref(ident, file_nid, module_bound, "assignment");
                }
            } elif n.type == "call" {
                getattr_ref: any = _getattr_ref_name(n);
                if getattr_ref is not None {
                    ref_name: any;
                    loc: any;
                    (ref_name, loc) = getattr_ref as any;
                    _emit_indirect_by_name(ref_name, loc, file_nid, "getattr");
                }
            }
            for c in typing.cast(object, n).children {
                _scan_module_dispatch(c);
            }
        }

        _scan_module_dispatch(`root);
    } elif ts_mod in ("tree_sitter_javascript", "tree_sitter_typescript") {
        js_module_bound = _js_module_bound_names(`root, source);

        def _scan_js_module_dispatch(n) {
            if n.type in _JS_SCOPE_BOUNDARY {
                return;
            }
            if n.type in ("object", "array") {
                for ident in _js_dispatch_value_idents(n) {
                    _emit_indirect_ref(ident, file_nid, js_module_bound, "collection");
                }
            } elif n.type in ("call_expression", "new_expression") {
                margs: any = n.child_by_field_name("arguments");
                if margs is not None {
                    for marg in typing.cast(object, margs).children {
                        if marg.type == "identifier" {
                            _emit_indirect_ref(marg, file_nid, js_module_bound, "argument");
                        }
                    }
                }
            }
            for c in typing.cast(object, n).children {
                _scan_js_module_dispatch(c);
            }
        }

        _scan_js_module_dispatch(`root);
    }
    valid_ids: any = seen_ids;
    clean_edges: any = [];
    _seen_edge_payloads: set[str] = set[any]();
    for `edge in edges {
        src: any;
        tgt: any;
        (src, tgt) = (`edge["source"], `edge["target"]);
        if src in valid_ids
            and (tgt in valid_ids or `edge["relation"] in ("imports", "imports_from", "re_exports"))
        {
            payload: any = json.dumps(`edge, sort_keys=True, default=str);
            if payload in _seen_edge_payloads {
                continue;
            }
            _seen_edge_payloads.add(payload);
            clean_edges.append(`edge);
        }
    }
    if _ruby_mixin_calls {
        raw_calls.extend(_ruby_mixin_calls);
    }
    if ts_mod == "tree_sitter_python" {
        raw_calls.extend(
            _python_property_reads(
                function_bodies, source, str_path, python_var_types, python_attr_types, method_owner
            ),
        );
    }
    raw_calls.extend(csharp_ctor_records);
    result: any = {"nodes": nodes, "edges": clean_edges, "raw_calls": raw_calls};
    def first_node_with_id(nid: any) -> any {
        return next((x for x in nodes if x["id"] == nid), None);
    }
    _field_table_export: any = [
        {
            "lang": _lang,
            "class_label": _n.get("label"),
            "source_file": _n.get("source_file"),
            "fields": `dict(_tbl),
            "type_path": type_paths.get(_cls),
            "namespace": (_n.get("metadata") or {}).get("namespace", ""),
        }
        for (_lang, _tables) in (
            ("java", java_field_types),
            ("java_static", java_static_field_types),
            ("csharp", csharp_field_types),
            ("csharp_returns", csharp_method_returns),
        )
        for (_cls, _tbl) in _tables.items()
        if _tbl
        for _n in (first_node_with_id(_cls),)
        if _n is not None and _n.get("label")
    ];
    if _field_table_export {
        result["member_field_tables"] = _field_table_export;
    }
    for _n in nodes {
        if java_return_types.get(_n["id"]) {
            _n["_java_ret"] = java_return_types[_n["id"]];
        }
    }
    if `root.has_error {
        _multiline: any = _has_multiline_error(`root);
        result["parse_errors"] = {
            "first_error_line": _first_parse_error_line(`root),
            "multiline_error": _multiline,
        };
        if _multiline {
            result["parse_errors"]["lossy_error_line"] = _first_multiline_error_line(`root);
        }
    }
    if ts_mod == "tree_sitter_kotlin" {
        _pkg: any = _kotlin_package_name(`root, source);
        if _pkg {
            result["kotlin_package"] = _pkg;
            for n in nodes {
                if n["id"] in callable_def_nids {
                    n["metadata"] = sanitize_metadata({
                        **n.get("metadata") or {},
                        "namespace": _pkg,
                    });
                }
            }
            for `entry in result.get("member_field_tables", []) {
                `entry["namespace"] = _pkg;
            }
        }
    }
    if callable_def_nids {
        for n in nodes {
            if n["id"] in cpp_qualified_names {
                n["_cpp_qualified"] = cpp_qualified_names[n["id"]];
            }
            if n["id"] in callable_def_nids {
                n["_callable"] = True;
                if n["id"] in callable_class_nids {
                    n["_callable_class"] = True;
                }
            }
        }
    }
    if swift_extensions {
        result["swift_extensions"] = swift_extensions;
    }
    ts_field_types: dict[str, dict[str, str]] = {};
    if ts_mod in ("tree_sitter_javascript", "tree_sitter_typescript") {
        _ts_receiver_type_table(`root, source, type_table, ts_field_types);
        _ts_mark_public_twins(`root, source, result);
        _ts_attach_class_fields(result, ts_field_types, str_path);
    }
    if ts_mod == "tree_sitter_cpp" {
        file_node = next(n for n in nodes if n["id"] == file_nid);
        items_: any = list(_cpp_resolution_facts(`root, source) as any);
        if len(items_) != 3 {
            raise ValueError(
                f"too many values to unpack (expected 3, got {len(items_)})"
                    if len(items_) > 3
                    else f"not enough values to unpack (expected 3, got {len(items_)})",
            );
        }
        file_node["_cpp_type_bindings"] = items_[0];
        file_node["_cpp_include_positions"] = items_[1];
        file_node["_cpp_include_paths"] = items_[2];
    }
    if ts_mod == "tree_sitter_php" {
        _php_receiver_type_table(`root, source, type_table);
    }
    if ts_mod == "tree_sitter_swift" {
        if type_table or swift_factory_bindings {
            result["swift_type_table"] = {"path": str_path, "table": type_table};
            if swift_factory_bindings {
                result["swift_type_table"]["factory"] = {
                    k: `list(v)
                    for (k, v) in swift_factory_bindings.items()
                };
            }
        }
    } elif type_table {
        if ts_mod in ("tree_sitter_javascript", "tree_sitter_typescript") {
            result["ts_type_table"] = {"path": str_path, "table": type_table};
        } elif ts_mod == "tree_sitter_cpp" {
            result["cpp_type_table"] = {"path": str_path, "table": type_table};
        } elif ts_mod == "tree_sitter_php" {
            result["php_type_table"] = {"path": str_path, "table": type_table};
        }
    }
    return result;
}

impl _ts_mark_public_twins(`root, source: bytes, result: dict) {
    shared: dict[str, set[str]] = {};
    stack: any = [`root];
    while stack {
        n: any = stack.pop();
        if n.type == "class_body" and n.parent is not None {
            cls: any = n.parent.child_by_field_name("name");
            public: set[str] = set[any]();
            private: set[str] = set[any]();
            for member in typing.cast(object, n).named_children {
                if member.type
                    not in ("method_definition", "public_field_definition", "field_definition")
                {
                    continue;
                }
                name: any = member.child_by_field_name("name")
                    or member.child_by_field_name("property");
                if name is None {
                    continue;
                }
                text: any = _read_text(name, source);
                if name.type == "private_property_identifier" {
                    private.add(text.lstrip("#"));
                } elif name.type == "property_identifier" {
                    public.add(text);
                }
            }
            if cls is not None and public & private {
                shared.setdefault(_read_text(cls, source), set[any]()).update(public & private);
            }
        }
        stack.extend(n.children);
    }
    if not shared {
        return;
    }
    labels: any = {n["id"]: n.get("label", "") for n in result.get("nodes", [])};
    marked: any = {
        e["target"]
        for e in result.get("edges", [])
        if e.get("relation") == "method"
            and `str(labels.get(e["target"], "")).strip("()").lstrip(".").lstrip("#")
                in shared.get(`str(labels.get(e["source"], "")), set[any]())
    };
    for n in result.get("nodes", []) {
        if n["id"] in marked {
            n["_ts_public_twin"] = True;
        }
    }
}

impl _python_decorator_name(deco_node, source: bytes) -> str | None {
    for child in typing.cast(object, deco_node).children {
        if not child.is_named {
            continue;
        }
        target: any = child;
        if target.type == "call" {
            target = target.child_by_field_name("function") or target;
        }
        if target.type == "attribute" {
            attr: any = target.child_by_field_name("attribute");
            return _read_text(attr, source) if attr else None;
        }
        if target.type == "identifier" {
            return _read_text(target, source);
        }
        return None;
    }
    return None;
}

impl _ts_decorator_target_name(expr, source: bytes) -> str | None {
    if expr is None {
        return None;
    }
    if expr.type == "parenthesized_expression" {
        calls: any = [c for c in typing.cast(object, expr).named_children if c.type == "call_expression"];
        if calls {
            return _ts_decorator_target_name(calls[-1], source);
        }
        if `any(operator.eq(c.type, "ERROR") for c in typing.cast(object, expr).named_children) {
            return None;
        }
        named: any = [c for c in typing.cast(object, expr).named_children if c.type != "ERROR"];
        return _ts_decorator_target_name(named[0], source) if named else None;
    }
    if expr.type == "call_expression" {
        fn: any = expr.child_by_field_name("function");
        if fn is None {
            return None;
        }
        if fn.type == "member_expression" {
            prop: any = fn.child_by_field_name("property");
            return _read_text(prop, source) if prop else None;
        }
        if fn.type == "identifier" {
            return _read_text(fn, source);
        }
        return None;
    }
    if expr.type == "member_expression" {
        prop = expr.child_by_field_name("property");
        return _read_text(prop, source) if prop else None;
    }
    if expr.type == "identifier" {
        return _read_text(expr, source);
    }
    return None;
}

impl _ts_decorator_name(deco_node, source: bytes) -> str | None {
    for child in typing.cast(object, deco_node).children {
        if not child.is_named {
            continue;
        }
        return _ts_decorator_target_name(child, source);
    }
    return None;
}

impl _ts_method_name(method_node, source: bytes) -> str | None {
    name_node: any = method_node.child_by_field_name("name");
    return _read_text(name_node, source) if name_node else None;
}

impl _ts_descendant_decorators(`node) -> list {
    out: list;
    out = [];

    def rec(n, top: bool) {
        for child in typing.cast(object, n).children {
            ct: any = child.type;
            if ct == "decorator" {
                out.append(child);
            } elif ct in ("class_declaration", "abstract_class_declaration") {
                continue;
            } elif ct == "method_definition" and not top {
                continue;
            } else {
                rec(child, False);
            }
        }
    }

    rec(`node, True);
    return out;
}

impl _ts_emit_decorator_edges(
    class_node, class_nid: str, stem: str, source: bytes, ensure_named_node, add_edge
) {
    def emit(deco_node, owner_nid: str) {
        name: any = _ts_decorator_name(deco_node, source);
        if not name {
            return;
        }
        line: any = deco_node.start_point[0] + 1;
        target: any = ensure_named_node(name, line);
        if target != owner_nid {
            add_edge(owner_nid, target, "references", line, context="decorator");
        }
    }
    child: any;
    for child in typing.cast(object, class_node).children {
        if child.type == "decorator" {
            emit(child, class_nid);
        }
    }
    parent: any = class_node.parent;
    if parent is not None and parent.type == "export_statement" {
        for child in typing.cast(object, parent).children {
            if child.type == "decorator" {
                emit(child, class_nid);
            } elif child.type in ("class_declaration", "abstract_class_declaration") {
                break;
            }
        }
    }
    body: any = next((c for c in typing.cast(object, class_node).children if c.type == "class_body"), None);
    if body is None {
        return;
    }
    for member in typing.cast(object, body).children {
        mt: any = member.type;
        if mt == "decorator" {
            owner: any = class_nid;
            sib: any = member.next_named_sibling;
            while sib is not None and sib.type == "decorator" {
                sib = sib.next_named_sibling;
            }
            if sib is not None and sib.type == "method_definition" {
                mname: any = _ts_method_name(sib, source);
                if mname {
                    owner = _make_id(class_nid, mname);
                }
            }
            emit(member, owner);
        } elif mt == "method_definition" {
            mname = _ts_method_name(member, source);
            m_nid: any = _make_id(class_nid, mname) if mname else class_nid;
            deco: any;
            for deco in _ts_descendant_decorators(member) {
                emit(deco, m_nid);
            }
        } else {
            for deco in _ts_descendant_decorators(member) {
                emit(deco, class_nid);
            }
        }
    }
}
