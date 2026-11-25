impl _unquote(value: str) -> str {
    value = value.strip();
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"" {
        return value[1:-1];
    }
    return value;
}

impl _rightmost_operand(`obj: Node) -> Node {
    base: any = `obj;
    while True {
        unwrapped: any = base.named_children[0]
            if base.type == "expression" and base.named_children
            else base;
        right: any = unwrapped.child_by_field_name("right")
            if unwrapped.type == "binary_expression"
            else unwrapped.child_by_field_name("argument")
                if unwrapped.type == "unary_expression"
                else None;
        if right is None {
            return base;
        }
        base = right;
    }
}

impl _member_callee(callee: Node) -> Node | None {
    inner: any = callee.named_children[0]
        if callee.type == "expression" and callee.named_children
        else callee;
    return inner if inner.type == "member_expression" else None;
}

impl _callee_text(callee: Node, source: bytes) -> str {
    inner: any = _member_callee(callee);
    if inner is not None {
        `obj: any = inner.child_by_field_name("object");
        prop: any = inner.child_by_field_name("property");
        if `obj is not None and prop is not None {
            base: any = _rightmost_operand(`obj);
            if base is not `obj {
                return f"{_read_text(base, source)}.{_read_text(prop, source)}";
            }
        }
    }
    return _read_text(callee, source);
}

impl _callable_signature(declaration: Node, source: bytes) -> str {
    parameters: any = [
        child
        for child in declaration.named_children
        if child.type in {"parameter", "fallback_receive_parameter"}
    ];
    types: any = ",".join(
        _read_text(child.child_by_field_name("type"), source)
        for child in parameters
        if child.child_by_field_name("type") is not None,
    );
    return f"{len(parameters)}:{types}";
}

impl _member_identity(member: Node, source: bytes) -> tuple[str, str, str] | None {
    if member.type in _SIMPLE_MEMBERS {
        name_node: any = member.child_by_field_name("name");
        if name_node is None {
            return None;
        }
        name: any = _read_text(name_node, source);
        return (_SIMPLE_MEMBERS[member.type], name, name);
    }
    if member.type == "constructor_definition" {
        return ("constructor", "constructor", _callable_signature(member, source));
    }
    if member.type == "fallback_receive_definition" {
        name = "receive"
            if _read_text(member, source).lstrip().startswith("receive")
            else "fallback";
        return (name, name, _callable_signature(member, source));
    }
    if member.type in {"function_definition", "modifier_definition"} {
        name_node = member.child_by_field_name("name");
        if name_node is None {
            return None;
        }
        kind: any = "modifier" if member.type == "modifier_definition" else "function";
        return (kind, _read_text(name_node, source), _callable_signature(member, source));
    }
    return None;
}

impl _collision_groups(declared: list[tuple[str, str]]) -> dict[str, set[str]] {
    groups: dict[str, set[str]] = {};
    for (plain, name) in declared {
        groups.setdefault(plain, set[any]()).add(name);
    }
    return {plain: names for (plain, names) in groups.items() if len(names) >= 2};
}

impl _normalize_type(text: str) -> str {
    text = re.sub("\\s+", " ", text).strip();
    text = re.sub(" ?([\\[\\]().,]|=>) ?", "\\1", text);
    return re.sub(
        "\\b(uint|int|byte)\\b", lambda (m) -> any { _ELEMENTARY_ALIASES[m.group(1)] }, text
    );
}

impl _element_type(text: str) -> str | None {
    if text.startswith("mapping(") and text.endswith(")") {
        inner: any = text[len("mapping("):-1];
        depth: any = 0;
        index: any;
        for (index, char) in enumerate(inner) {
            if char == "(" {
                depth += 1;
            } elif char == ")" {
                depth -= 1;
            } elif depth == 0 and inner.startswith("=>", index) {
                value: any = inner[index + 2:];
                named: any = _MAPPING_VALUE_NAME.fullmatch(value);
                if named and named.group(2) != "payable" {
                    value = named.group(1);
                }
                return value;
            }
        }
        return None;
    }
    if text.endswith("]") {
        depth = 0;
        for index in range(len(text) - 1, -1, -1) {
            if text[index] == "]" {
                depth += 1;
            } elif text[index] == "[" {
                depth -= 1;
                if depth == 0 {
                    return text[:index] or None;
                }
            }
        }
    }
    return None;
}

impl _inherited_call(
    caller_id: str, callee: str, arity: int | None, kind: str, source_file: str, `node: Node
) -> dict[str, Any] {
    return {
        "caller_nid": caller_id,
        "callee": callee,
        "arity": arity,
        "solidity_call": kind,
        "language": "solidity",
        "source_file": source_file,
        "source_location": f"L{`node.start_point[0] + 1}",
    };
}

impl _c3_linearization(type_id: str, bases: dict[str, list[str]]) -> list[str] {
    memo: dict[str, list[str]];
    memo = {};

    def linearize(tid: str, active: frozenset[str]) -> list[str] | None {
        seq: any;
        if tid in memo {
            return memo[tid];
        }
        if tid in active {
            return None;
        }
        parents: any = `list(reversed(bases.get(tid, [])));
        sequences: list[list[str]] = [];
        for parent in parents {
            `lin: any = linearize(parent, active | {tid});
            if `lin is None {
                return None;
            }
            sequences.append(`list(`lin));
        }
        sequences.append(`list(parents));
        result: any = [tid];
        while `any(sequences) {
            head: any = None;
            for seq_ in sequences {
                seq = seq_;
                if seq and not `any(seq[0] in other[1:] for other in sequences) {
                    head = seq[0];
                    break;
                }
            }
            if head is None {
                return None;
            }
            result.append(head);
            for seq__ in sequences {
                seq = seq__;
                if seq and seq[0] == head {
                    del seq[0];
                }
            }
        }
        memo[tid] = result;
        return result;
    }

    linear: any = linearize(type_id, frozenset());
    if linear is not None {
        return linear;
    }
    order: list[str] = [];
    stack: any = [type_id];
    while stack {
        tid: any = stack.pop();
        if tid in order {
            continue;
        }
        order.append(tid);
        stack.extend(bases.get(tid, []));
    }
    return order;
}

impl resolve_solidity_inherited_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None {
    node_by_id: any;
    owner: dict[str, str];
    functions: dict[str, dict[str, list[tuple[str, Any]]]];
    modifiers: dict[str, dict[str, list[str]]];
    bases: dict[str, list[str]];
    using: dict[str, list[dict]];
    state_variables: dict[str, dict[str, str]];
    types_by_file: dict[tuple[str, str], list[str]];
    imported: dict[str, set[str]];
    file_using: dict[str, list[dict]];
    global_using: list[tuple[dict, str]];
    free_functions: dict[tuple[str, str], list[str]];
    `node: any;
    node_file: any;
    reachable_cache: dict[str, list[str]];
    linear_cache: dict[str, list[str]];
    rc: any;
    calls: any = [
        rc
        for result in per_file
        for rc in result.get("raw_calls", []) or []
        if rc.get("solidity_call")
    ];
    if not calls {
        return;
    }
    node_by_id = {`node.get("id"): `node for `node in all_nodes};

    def meta(nid: Any) -> dict {
        `node: any = node_by_id.get(nid);
        value: any = `node.get("metadata") if `node else None;
        return value if isinstance(value, `dict) else {};
    }

    type_kinds: any = `set(_TYPE_DECLARATIONS.values());
    owner = {};
    functions = {};
    modifiers = {};
    bases = {};
    using = {};
    state_variables = {};
    existing: set[tuple[Any, Any, Any]] = set[any]();
    `edge: any;
    for `edge in all_edges {
        source: any;
        target: any;
        relation: any;
        (source, target, relation) = (
            `edge.get("source"),
            `edge.get("target"),
            `edge.get("relation"),
        );
        existing.add((source, target, relation));
        if not isinstance(source, `str) or not isinstance(target, `str) {
            continue;
        }
        source_meta: any = meta(source);
        if source_meta.get("language") != "solidity" or source_meta.get("kind") not in type_kinds {
            continue;
        }
        if isinstance(source_meta.get("using"), `list) {
            using[source] = source_meta["using"];
        }
        if relation == "method" {
            member: any = meta(target);
            name: any = `str(node_by_id.get(target, {}).get("label", ""));
            name = name[:-2] if name.endswith("()") else name;
            owner[target] = source;
            if member.get("kind") == "function" {
                functions.setdefault(source, {}).setdefault(name, []).append((
                    target,
                    member.get("arity"),
                ));
            } elif member.get("kind") == "modifier" {
                modifiers.setdefault(source, {}).setdefault(name, []).append(target);
            }
        } elif relation == "contains" and meta(target).get("kind") == "state_variable" {
            state_variables.setdefault(source, {})[`str(
                node_by_id.get(target, {}).get("label", "")
            )] = target;
        } elif relation == "contains" and meta(target).get("kind") in {"event", "error"} {
            functions.setdefault(source, {}).setdefault(
                `str(node_by_id.get(target, {}).get("label", "")), []
            ).append((target, meta(target).get("arity")));
        } elif relation == "inherits" and meta(target).get("kind") in type_kinds {
            bases.setdefault(source, []).append(target);
        }
    }

    def find(linear: list[str], name: str, arity: Any, kind: str) -> str | None {
        for type_id in linear {
            if kind == "member" and name in state_variables.get(type_id, {}) {
                return None;
            }
            if kind == "modifier" {
                found: any = modifiers.get(type_id, {}).get(name, []);
            } else {
                found = [
                    nid
                    for (nid, declared) in functions.get(type_id, {}).get(name, [])
                    if (arity is None or declared is None or declared == arity)
                        and (kind != "member" or meta(nid).get("kind") == "function")
                ];
            }
            if found {
                return found[0] if len(found) == 1 else None;
            }
        }
        return None;
    }
    types_by_file = {};
    file_by_id: dict[Any, str] = {};
    imported = {};
    file_using = {};
    global_using = [];
    free_functions = {};
    if `any(rc["solidity_call"] in {"qualified", "member"} for rc in calls) {
        for `node in all_nodes {
            node_file = `node.get("source_file");
            if not node_file {
                continue;
            }
            if `node.get("label") == Path(`str(node_file)).name {
                file_by_id[`node.get("id")] = `str(node_file);
                directives: any = meta(`node.get("id")).get("using");
                if isinstance(directives, `list) {
                    file_using[`str(node_file)] = directives;
                    global_using.extend(
                        (d, `str(node_file)) for d in directives if d.get("global")
                    );
                }
            } elif meta(`node.get("id")).get("kind") in type_kinds {
                types_by_file.setdefault(
                    (`str(node_file), `str(`node.get("label", ""))), []
                ).append(`node["id"]);
            }
        }
        for `edge in all_edges {
            if `edge.get("relation") == "imports_from" {
                importer: any = file_by_id.get(`edge.get("source"));
                imported_file: any = file_by_id.get(`edge.get("target"));
                if importer and imported_file {
                    imported.setdefault(importer, set[any]()).add(imported_file);
                }
            } elif `edge.get("relation") == "contains"
                and `edge.get("source") in file_by_id
                and meta(`edge.get("target")).get("kind") == "function"
            {
                name = `str(node_by_id.get(`edge.get("target"), {}).get("label", ""));
                free_functions.setdefault(
                    (file_by_id[`edge["source"]], name[:-2] if name.endswith("()") else name), []
                ).append(`str(`edge["target"]));
            }
        }
    }

    reachable_cache = {};

    """Every file ``caller_file`` imports, directly or through the files
        it imports (`import {IERC20} from "./ERC20.sol"` re-exports a type
        ERC20.sol itself imports)."""
    def reachable(caller_file: str) -> list[str] {
        if caller_file not in reachable_cache {
            seen: set[str] = set[any]();
            stack: any = sorted(imported.get(caller_file, set[any]()));
            while stack {
                current: any = stack.pop();
                if current in seen or current == caller_file {
                    continue;
                }
                seen.add(current);
                stack.extend(sorted(imported.get(current, set[any]())));
            }
            reachable_cache[caller_file] = sorted(seen);
        }
        return reachable_cache[caller_file];
    }

    """The types named ``name`` that ``caller_file`` declares or imports
        directly; with ``transitive``, when there is none, those of every
        file it reaches through its imports."""
    def visible_types(caller_file: str, name: str, transitive: bool = False) -> list[str] {
        found: any = types_by_file.get((caller_file, name), []) + [
            type_id
            for imported_file in sorted(imported.get(caller_file, set[any]()))
            for type_id in types_by_file.get((imported_file, name), [])
        ];
        if found or not transitive {
            return found;
        }
        return [
            type_id
            for reached in reachable(caller_file)
            for type_id in types_by_file.get((reached, name), [])
        ];
    }

    linear_cache = {};

    def linearization(type_id: str) -> list[str] {
        if type_id not in linear_cache {
            linear_cache[type_id] = _c3_linearization(type_id, bases);
        }
        return linear_cache[type_id];
    }

    """``(type, file)`` readings of a member call's receiver, best first:
        the type the extractor read (a local, parameter, own state variable
        or conversion), a base contract's state variable of the receiver's
        name, or the declared return type of the function ``g`` in
        ``g(..).f()``. ``file`` is the file whose scope names the type."""
    def receiver_types(rc: dict) -> list[tuple[str, str]] {
        caller: any = rc.get("caller_nid");
        readings: list[tuple[str, str]] = [];
        caller_file: any = `str(node_by_id.get(caller, {}).get("source_file", ""));
        if rc.get("receiver_type") {
            readings.append((`str(rc["receiver_type"]), caller_file));
        }
        contract: any = owner.get(`str(caller));
        if not contract {
            return readings;
        }
        linear: any = linearization(contract);
        variable: any = rc.get("qualifier") if rc["solidity_call"] == "qualified" else None;
        if variable {
            for type_id in linear[1:] {
                nid: any = state_variables.get(type_id, {}).get(`str(variable));
                if nid is not None {
                    declared: any = meta(nid).get("declared_type");
                    if declared {
                        readings.append((
                            `str(declared),
                            `str(node_by_id[nid].get("source_file", "")),
                        ));
                    }
                    break;
                }
            }
        }
        result_of: any = rc.get("receiver_call");
        if isinstance(result_of, `list) and len(result_of) == 2 {
            function: any = find(linear, `str(result_of[0]), result_of[1], "inherited");
            returned: any = meta(function).get("returns") if function else None;
            if function and returned {
                readings.append((
                    `str(returned),
                    `str(node_by_id[function].get("source_file", "")),
                ));
            }
        }
        return readings;
    }

    """``recv.name()`` bound through the receiver's contract/interface
        type, the first reading of it that names a visible type."""
    def typed_member(rc: dict, name: str) -> str | None {
        for (type_name, scope_file) in receiver_types(rc) {
            scope: any = visible_types(scope_file, type_name, transitive=True);
            if not scope {
                continue;
            }
            if len(scope) != 1 or meta(scope[0]).get("kind") not in {"contract", "interface"} {
                return None;
            }
            return find(linearization(scope[0]), name, rc.get("arity"), "member");
        }
    }

    def visible_free_functions(scope_file: str, name: str) -> list[str] {
        direct: any = free_functions.get((scope_file, name), []) + [
            nid
            for imported_file in sorted(imported.get(scope_file, set[any]()))
            for nid in free_functions.get((imported_file, name), [])
        ];
        return direct or [
            nid
            for reached in reachable(scope_file)
            for nid in free_functions.get((reached, name), [])
        ];
    }

    """The functions named ``name`` that ``directive`` attaches, read in
        ``scope_file``; ``None`` when its library is ambiguous."""
    def attached_functions(directive: dict, scope_file: str, name: str) -> list[str] | None {
        if "library" in directive {
            libraries: any = visible_types(scope_file, `str(directive["library"]), transitive=True);
            if not libraries {
                return [];
            }
            if len(libraries) != 1 or meta(libraries[0]).get("kind") != "library" {
                return None;
            }
            return [nid for (nid, _arity) in functions.get(libraries[0], {}).get(name, [])];
        }
        attached: list[str] = [];
        for bound in directive.get("functions", []) {
            qualifier: any;
            _: any;
            function: any;
            (qualifier, _, function) = `str(bound).rpartition(".") as any;
            if function != name {
                continue;
            }
            if not qualifier {
                attached.extend(visible_free_functions(scope_file, function));
                continue;
            }
            libraries = visible_types(scope_file, qualifier, transitive=True);
            if len(libraries) > 1 {
                return None;
            }
            if libraries {
                attached.extend(
                    nid for (nid, _arity) in functions.get(libraries[0], {}).get(function, [])
                );
            }
        }
        return attached;
    }

    """``recv.name()`` bound to the one function a ``using`` directive in
        scope attaches to the receiver's type, if there is exactly one."""
    def using_member(rc: dict, name: str) -> str | None {
        arity: any;
        type_name: any;
        caller: any = `str(rc.get("caller_nid"));
        caller_file: any = `str(node_by_id.get(caller, {}).get("source_file", ""));
        contract: any = owner.get(caller);
        scoped: any = [(d, caller_file) for d in using.get(contract or "", [])] + [
            (d, caller_file)
            for d in file_using.get(caller_file, [])
            if not d.get("global")
        ];
        arity = rc.get("arity");
        if not isinstance(arity, `int) {
            return None;
        }
        _scope_file: any;
        for item_ in receiver_types(rc) {
            (type_name, _scope_file) = item_;
            directives: any = scoped + [
                (d, f)
                for (d, f) in global_using
                if d.get("for") == type_name
            ];
            found: set[str] = set[any]();
            for (directive, scope_file) in directives {
                if directive.get("for") not in {"*", type_name} {
                    continue;
                }
                attached: any = attached_functions(directive, scope_file, name);
                if attached is None {
                    return None;
                }
                found.update(
                    nid
                    for nid in attached
                    if meta(nid).get("arity") == arity + 1
                        and meta(nid).get("first_param_type") == type_name,
                );
            }
            if found {
                return next(iter(found)) if len(found) == 1 else None;
            }
        }
        return None;
    }

    for rc in calls {
        caller: any = rc.get("caller_nid");
        name = rc.get("callee");
        if not caller or not name {
            continue;
        }
        kind: any = rc["solidity_call"];
        contract: any = owner.get(caller);
        if kind == "member" {
            target = typed_member(rc, name) or using_member(rc, name);
        } elif kind == "qualified" {
            caller_file: any = `str(node_by_id.get(caller, {}).get("source_file", ""));
            scope: any = visible_types(caller_file, `str(rc.get("qualifier", "")));
            target = find(scope, name, rc.get("arity"), kind)
                if len(scope) == 1
                else typed_member(rc, name) or using_member(rc, name) if not scope else None;
        } elif not contract {
            continue;
        } else {
            target = find(linearization(contract)[1:], name, rc.get("arity"), kind);
        }
        if target is None or target == caller {
            continue;
        }
        relation = "uses" if kind == "modifier" else "calls";
        if (caller, target, relation) in existing {
            continue;
        }
        existing.add((caller, target, relation));
        all_edges.append({
            "source": caller,
            "target": target,
            "relation": relation,
            "confidence": "EXTRACTED",
            "source_file": rc.get("source_file"),
            "source_location": rc.get("source_location"),
            "weight": 1.0,
        });
    }
}

impl resolve_solidity_type_references(
    _per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None {
    `node: any;
    node_by_id: any = {`node.get("id"): `node for `node in all_nodes};
    file_id_by_source: any = {
        `str(`node["source_file"]): `node["id"]
        for `node in all_nodes
        if `node.get("source_file") and `node.get("label") == Path(`str(`node["source_file"])).name
    };
    source_by_file_id: any = {nid: source for (source, nid) in file_id_by_source.items()};
    imported_sources: dict[str, set[str]] = {};
    `edge: any;
    for `edge in all_edges {
        if `edge.get("relation") != "imports_from" {
            continue;
        }
        source_file: any = source_by_file_id.get(`edge.get("source"));
        target_file: any = source_by_file_id.get(`edge.get("target"));
        if source_file and target_file {
            imported_sources.setdefault(source_file, set[any]()).add(target_file);
        }
    }

    types: dict[tuple[str, str], list[str]] = {};
    for `node in all_nodes {
        metadata: any = `node.get("metadata");
        if not isinstance(metadata, `dict)
            or metadata.get("kind") not in _TYPE_DECLARATIONS.values()
        {
            continue;
        }
        source_file = `node.get("source_file");
        if source_file {
            types.setdefault((`str(source_file), `str(`node.get("label", ""))), []).append(
                `node["id"]
            );
        }
    }

    for `edge in all_edges {
        context: any = `edge.get("context");
        if not isinstance(context, `str) or not context.startswith("solidity_type:") {
            continue;
        }
        source_node: any = node_by_id.get(`edge.get("source"));
        if not source_node or not source_node.get("source_file") {
            continue;
        }
        source_file = `str(source_node["source_file"]);
        name: any = context.split(":", 1)[1];
        candidates: any = `list(types.get((source_file, name), []));
        for imported in imported_sources.get(source_file, set[any]()) {
            candidates.extend(types.get((imported, name), []));
        }
        if len(candidates) == 1 {
            `edge["target"] = candidates[0];
        }
    }
}

impl extract_solidity(path: Path) -> dict {
    source: any;
    source_file: any;
    nodes: list[dict[str, Any]];
    edges: list[dict[str, Any]];
    raw_calls: list[dict[str, Any]];
    seen_ids: set[str];
    seen_edges: set[tuple[str, str, str]];
    import_aliases: dict[str, str];
    name_node: any;
    file_context: TypeContext;
    struct_fields: dict[str, tuple[TypeContext, dict[str, str]]];
    member: any;
    type_id: any;
    member_groups: any;
    kind: any;
    name: any;
    signature: any;
    try {
        import tree_sitter_solidity;
        import from tree_sitter { Language, Parser }
    } except ImportError {
        return {"nodes": [], "edges": [], "error": "tree-sitter-solidity not installed"};
    }

    try {
        source = _read_source_bytes(path);
        `root: any = Parser(Language(tree_sitter_solidity.language())).parse(source).root_node;
    } except Exception as exc {
        return {"nodes": [], "edges": [], "error": f"Solidity grammar failed to load: {exc}"};
    }

    source_file = `str(path);
    stem: any = _file_stem(path);
    file_id: any = _make_id(source_file);
    nodes = [];
    edges = [];
    raw_calls = [];
    seen_ids = set[any]();
    seen_edges = set[any]();

    def add_node(
        nid: str,
        label: str,
        `node: Node,
        *,
        kind: str,
        source_backed: bool = True,
        callable_node: bool = False,
        arity: int | None = None,
        extra: dict[str, Any] | None = None,
    ) -> str {
        if nid not in seen_ids {
            seen_ids.add(nid);
            metadata: dict[str, Any] = {"language": "solidity", "kind": kind};
            if arity is not None {
                metadata["arity"] = arity;
            }
            if extra {
                metadata.update(extra);
            }
            item: dict[str, Any] = {
                "id": nid,
                "label": label,
                "file_type": "code",
                "source_location": f"L{`node.start_point[0] + 1}",
                "metadata": metadata,
            };
            if source_backed {
                item["source_file"] = source_file;
            }
            if callable_node {
                item["_callable"] = True;
            }
            nodes.append(item);
        }
        return nid;
    }

    def add_edge(
        source_id: str,
        target_id: str,
        relation: str,
        `node: Node,
        *,
        context: str | None = None,
        target_file: str | None = None,
    ) -> None {
        key: any = (source_id, target_id, relation);
        if not source_id or not target_id or source_id == target_id or key in seen_edges {
            return;
        }
        seen_edges.add(key);
        item: dict[str, Any] = {
            "source": source_id,
            "target": target_id,
            "relation": relation,
            "confidence": "EXTRACTED",
            "source_file": source_file,
            "source_location": f"L{`node.start_point[0] + 1}",
            "weight": 1.0,
        };
        if context {
            item["context"] = context;
        }
        if target_file {
            item["target_file"] = target_file;
        }
        edges.append(item);
    }

    add_node(file_id, path.name, `root, kind="file");

    def type_stub(name: str, `node: Node) -> str {
        name = name.split(".")[-1];
        nid: any = _make_id("solidity", "type", name);
        add_node(nid, name, `node, kind="external_type", source_backed=False);
        return nid;
    }

    """Park ``Qualifier.member(..)`` for resolve_solidity_inherited_calls,
        which binds it through a type the file declares or imports."""
    def qualified_call(
        caller_id: str, qualifier: str, member: str, arity: int, `node: Node
    ) -> None {
        call: any = _inherited_call(caller_id, member, arity, "qualified", source_file, `node);
        call["qualifier"] = import_aliases.get(qualifier, qualifier);
        raw_calls.append(call);
    }

    """Park ``recv.member(..)`` for resolve_solidity_inherited_calls, with
        the receiver's declared type and/or, for ``g(..).member()``, the call
        whose result it is (typed there from ``g``'s return type)."""
    def member_call(
        caller_id: str,
        member: str,
        arity: int,
        `node: Node,
        receiver: str | None,
        receiver_call: tuple[str, int] | None,
    ) -> None {
        call: any = _inherited_call(caller_id, member, arity, "member", source_file, `node);
        if receiver {
            call["receiver_type"] = receiver;
        }
        if receiver_call {
            call["receiver_call"] = `list(receiver_call);
        }
        raw_calls.append(call);
    }

    """``("Lib", "f")`` for ``Lib.f``; ``None`` for ``a.b.f``, ``x[i].f``,
        ``f().g``, ``super.f`` or ``this.f``."""
    def split_qualified(written: str) -> tuple[str, str] | None {
        qualifier: any;
        _: any;
        member: any;
        (qualifier, _, member) = written.partition(".") as any;
        if qualifier in {"super", "this"}
            or not _IDENTIFIER.fullmatch(qualifier)
            or not _IDENTIFIER.fullmatch(member)
        {
            return None;
        }
        return (qualifier, member);
    }
    import_aliases = {};
    declaration: any;
    for declaration in `root.named_children {
        if declaration.type != "import_directive" {
            continue;
        }
        imported_name: str | None = None;
        child: any;
        for (index, child) in enumerate(declaration.children) {
            field: any = declaration.field_name_for_child(index);
            if field == "import_name" {
                imported_name = _read_text(child, source);
            } elif field == "alias" and imported_name is not None {
                import_aliases[_read_text(child, source)] = imported_name;
                imported_name = None;
            } elif child.type == "," {
                imported_name = None;
            }
        }
        source_node: any = declaration.child_by_field_name("source");
        if source_node is None {
            continue;
        }
        relative: any = _unquote(_read_text(source_node, source));
        if not relative or relative.startswith(("http:", "https:")) {
            continue;
        }
        target: any = Path(os.path.normpath(path.parent / relative));
        add_edge(
            file_id, _make_id(`str(target)), "imports_from", declaration, target_file=`str(target)
        );
    }
    type_groups: any = _collision_groups([
        (
            _make_id(stem, _TYPE_DECLARATIONS[declaration.type], _read_text(name_node, source)),
            _read_text(name_node, source),
        )
        for declaration in `root.named_children
        if declaration.type in _TYPE_DECLARATIONS
            and (name_node := declaration.child_by_field_name("name")) is not None
            and declaration.child_by_field_name("body") is not None
    ]);
    file_context = (None, frozenset());
    contract_contexts: dict[int, TypeContext] = {};
    struct_fields = {};

    def field_types(struct: Node) -> dict[str, str] {
        struct_body: any = struct.child_by_field_name("body");
        fields: dict[str, str] = {};
        for field in struct_body.named_children if struct_body is not None else [] {
            field_type: any = field.child_by_field_name("type");
            field_name: any = field.child_by_field_name("name");
            if field.type == "struct_member" and field_type is not None and field_name is not None {
                fields[_read_text(field_name, source)] = _normalize_type(
                    _read_text(field_type, source)
                );
            }
        }
        return fields;
    }

    for declaration in `root.named_children {
        if declaration.type == "struct_declaration" {
            name_node = declaration.child_by_field_name("name");
            if name_node is not None {
                struct_fields[_read_text(name_node, source)] = (
                    file_context,
                    field_types(declaration),
                );
            }
            continue;
        }
        if declaration.type not in _TYPE_DECLARATIONS {
            continue;
        }
        name_node = declaration.child_by_field_name("name");
        body: any = declaration.child_by_field_name("body");
        if name_node is None or body is None {
            continue;
        }
        owner_name: any = _read_text(name_node, source);
        local_types: any = frozenset(
            _read_text(member.child_by_field_name("name"), source)
            for member in body.named_children
            if member.type in {
                "struct_declaration",
                "enum_declaration",
                "user_defined_type_definition",
            }
                and member.child_by_field_name("name") is not None,
        );
        context: TypeContext = (owner_name, local_types);
        contract_contexts[declaration.id] = context;
        for member in body.named_children {
            member_name: any = member.child_by_field_name("name");
            if member.type == "struct_declaration" and member_name is not None {
                struct_fields[f"{owner_name}.{_read_text(member_name, source)}"] = (
                    context,
                    field_types(member),
                );
            }
        }
    }

    """``text`` as written in ``context``, with its leading type name
        qualified (``Trace208`` in library Checkpoints -> ``Checkpoints.Trace208``)
        and an import alias replaced by the name it imports."""
    def qualify(text: str, context: TypeContext) -> str {
        `match: any = _IDENTIFIER.match(text);
        if `match is None {
            return text;
        }
        head: any;
        rest: any;
        (head, rest) = (`match.group(0), text[`match.end():]);
        owner_name: any;
        local_types: any;
        (owner_name, local_types) = context as any;
        if not rest.startswith(".") and owner_name and head in local_types {
            return f"{owner_name}.{head}{rest}";
        }
        return import_aliases.get(head, head) + rest;
    }

    """The ``using A for T;`` / ``using A for *;`` / ``using {f, L.g} for
        T [global];`` directives directly in ``scope`` (a contract body or the
        file), for the resolver: ``{"for": T or "*", "library": A}`` or
        ``{"for": T, "functions": [..]}``, plus ``"global": True``. ``T`` is
        qualified like a receiver type so the two compare equal. An operator
        binding (`using {eq as ==} for T`) attaches no member and is skipped."""
    def using_directives(scope: Node, context: TypeContext) -> list[dict[str, Any]] {
        directives: list[dict[str, Any]] = [];
        for directive in scope.named_children {
            if directive.type != "using_directive" {
                continue;
            }
            target: any = directive.child_by_field_name("source");
            if target is None {
                continue;
            }
            item: dict[str, Any] = {
                "for": "*"
                    if target.type == "any_source_type"
                    else qualify(_normalize_type(_read_text(target, source)), context),
            };
            library: any = next(
                (child for child in directive.named_children if child.type == "type_alias"), None
            );
            if library is not None {
                item["library"] = qualify(
                    _normalize_type(_read_text(library, source)), file_context
                );
            } else {
                functions: any = [
                    _normalize_type(_read_text(bound, source))
                    for alias in directive.named_children
                    if alias.type == "using_alias"
                        and not `any(operator.eq(child.type, "as") for child in alias.children)
                    for bound in alias.named_children
                    if bound.type == "user_defined_type"
                ];
                if not functions {
                    continue;
                }
                item["functions"] = [qualify(function, file_context) for function in functions];
            }
            if `any(operator.eq(child.type, "global") for child in directive.children) {
                item["global"] = True;
            }
            directives.append(item);
        }
        return directives;
    }

    """``{"first_param_type": T}`` for a library or free function, the
        type a ``using`` directive attaches it to (``x.f()`` passes ``x``)."""
    def first_parameter_type(callable_node: Node, context: TypeContext) -> dict[str, Any] {
        first: any = next(
            (child for child in callable_node.named_children if child.type == "parameter"), None
        );
        type_node: any = first.child_by_field_name("type") if first is not None else None;
        if type_node is None {
            return {};
        }
        return {
            "first_param_type": qualify(_normalize_type(_read_text(type_node, source)), context),
        };
    }

    """Parameter, return and local variable types visible in a function
        or modifier, over ``inherited`` (the contract's state variables). A
        name declared twice with different types (sibling blocks) is
        ambiguous and maps to ``None``."""
    def declared_types(
        callable_node: Node, context: TypeContext, inherited: VariableTypes
    ) -> VariableTypes {
        found: dict[str, set[str]] = {};
        stack: any = [callable_node];
        while stack {
            current: any = stack.pop();
            if current.type in {"parameter", "variable_declaration"} {
                type_node: any = current.child_by_field_name("type");
                name_node: any = current.child_by_field_name("name");
                if type_node is not None and name_node is not None {
                    found.setdefault(_read_text(name_node, source), set[any]()).add(
                        _normalize_type(_read_text(type_node, source))
                    );
                }
            }
            stack.extend(current.named_children);
        }
        scope: VariableTypes = `dict(inherited);
        for (name, types) in found.items() {
            scope[name] = (next(iter(types)), context) if len(types) == 1 else None;
        }
        return scope;
    }

    def unwrap(`node: Node) -> Node {
        while `node.type in {"expression", "parenthesized_expression"}
            and len(`node.named_children) == 1
        {
            `node = `node.named_children[0];
        }
        return `node;
    }

    """The qualified declared type of the receiver of the member call
        ``callee``: a typed variable, an element of a typed mapping/array, a
        field of a struct declared in this file, a conversion (`IERC20(a)`,
        `uint256(x)`) or a builtin. ``None`` (fail closed) for anything else,
        including `super`, `this` and a type name (`Lib.f()`)."""
    def typed_receiver(
        callee: Node, scope: VariableTypes, context: TypeContext, local_functions: set[str]
    ) -> str | None {
        member: any = _member_callee(callee);
        `obj: any = member.child_by_field_name("object") if member is not None else None;
        if `obj is None {
            return None;
        }
        typed: any = typed_expression(
            unwrap(_rightmost_operand(`obj)), scope, context, local_functions
        );
        return qualify(*typed) if typed is not None else None;
    }

    """``(declared type, (g, arity))`` of a member call's receiver, either
        part ``None`` when unknown; ``None`` when both are."""
    def member_receiver(
        callee: Node, scope: VariableTypes, context: TypeContext, local_functions: set[str]
    ) -> tuple[str | None, tuple[str, int] | None] | None {
        typed: any = typed_receiver(callee, scope, context, local_functions);
        result_of: any = call_receiver(callee, scope);
        return (typed, result_of) if typed or result_of else None;
    }

    """``(g, arity)`` when the receiver of the member call ``callee`` is
        the result of a bare call ``g(..)``, which the resolver types from
        ``g``'s declared return type."""
    def call_receiver(callee: Node, scope: VariableTypes) -> tuple[str, int] | None {
        member: any = _member_callee(callee);
        `obj: any = member.child_by_field_name("object") if member is not None else None;
        receiver: any = unwrap(_rightmost_operand(`obj)) if `obj is not None else None;
        if receiver is None or receiver.type != "call_expression" {
            return None;
        }
        function: any = receiver.child_by_field_name("function");
        name: any = _read_text(unwrap(function), source) if function is not None else "";
        if not _IDENTIFIER.fullmatch(name) or name in scope or name in _BUILTIN_CALL_TYPES {
            return None;
        }
        return (
            name,
            sum(operator.eq(child.type, "call_argument") for child in receiver.named_children),
        );
    }

    def typed_expression(
        `node: Node, scope: VariableTypes, context: TypeContext, local_functions: set[str]
    ) -> tuple[str, TypeContext] | None {
        if `node.type == "identifier" {
            return scope.get(_read_text(`node, source));
        }
        if `node.type == "array_access" {
            base: any = `node.child_by_field_name("base");
            typed: any = typed_expression(unwrap(base), scope, context, local_functions)
                if base is not None
                else None;
            element: any = _element_type(typed[0]) if typed is not None else None;
            return (element, typed[1]) if typed is not None and element else None;
        }
        if `node.type == "member_expression" {
            written: any = _read_text(`node, source);
            if written in _BUILTIN_MEMBER_TYPES {
                return (_BUILTIN_MEMBER_TYPES[written], file_context);
            }
            `obj: any = `node.child_by_field_name("object");
            prop: any = `node.child_by_field_name("property");
            typed = typed_expression(unwrap(`obj), scope, context, local_functions)
                if `obj is not None
                else None;
            struct: any = struct_fields.get(qualify(*typed)) if typed is not None else None;
            field: any = struct[1].get(_read_text(prop, source))
                if struct is not None and prop is not None
                else None;
            return (field, struct[0]) if struct is not None and field else None;
        }
        if `node.type == "type_cast_expression" {
            type_node: any = next(
                (child for child in `node.named_children if child.type == "primitive_type"), None
            );
            return (_normalize_type(_read_text(type_node, source)), file_context)
                if type_node is not None
                else None;
        }
        if `node.type == "payable_conversion_expression" {
            return ("address payable", file_context);
        }
        if `node.type == "call_expression" {
            function: any = `node.child_by_field_name("function");
            if function is None {
                return None;
            }
            written = _normalize_type(_read_text(unwrap(function), source));
            if written in _BUILTIN_CALL_TYPES {
                return (_BUILTIN_CALL_TYPES[written], file_context);
            }
            arguments: any = sum(
                operator.eq(child.type, "call_argument") for child in `node.named_children
            );
            if arguments == 1
                and _IDENTIFIER.fullmatch(written)
                and written not in scope
                and written not in local_functions
            {
                return (written, context);
            }
        }
        return None;
    }

    file_using: any = using_directives(`root, file_context);
    if file_using {
        nodes[0]["metadata"]["using"] = file_using;
    }

    for declaration in `root.named_children {
        type_kind: any = _TYPE_DECLARATIONS.get(declaration.type);
        if type_kind is None {
            continue;
        }
        name_node = declaration.child_by_field_name("name");
        body = declaration.child_by_field_name("body");
        if name_node is None or body is None {
            continue;
        }
        type_name: any = _read_text(name_node, source);
        contract_using: any = using_directives(body, contract_contexts[declaration.id]);
        type_id = add_node(
            _underscore_salted_nid(_make_id(stem, type_kind, type_name), type_name, type_groups),
            type_name,
            declaration,
            kind=type_kind,
            callable_node=operator.eq(type_kind, "contract"),
            extra={"using": contract_using} if contract_using else None,
        );
        add_edge(file_id, type_id, "contains", declaration);

        for child in declaration.named_children {
            if child.type != "inheritance_specifier" {
                continue;
            }
            ancestor: any = child.child_by_field_name("ancestor");
            if ancestor is None {
                continue;
            }
            base_name: any = _read_text(ancestor, source).split(".")[-1];
            add_edge(
                type_id,
                type_stub(base_name, child),
                "inherits",
                child,
                context=f"solidity_type:{base_name}",
            );
        }

        functions: dict[tuple[str, int], list[str]] = {};
        modifiers: dict[str, str] = {};
        reference_targets: dict[tuple[str, int], str] = {};
        bodies: list[tuple[Node, str, Node]] = [];
        type_context: any = contract_contexts[declaration.id];
        state_types: VariableTypes = {};
        pending_modifiers: list[tuple[str, str, Node]] = [];
        member_groups = _collision_groups([
            (_make_id(type_id, kind, name, signature), name)
            for member in body.named_children
            if (identity := _member_identity(member, source)) is not None
            for (kind, name, signature) in [identity]
        ]);

        def add_member(
            member: Node,
            name: str,
            label: str,
            kind: str,
            *,
            relation: str = "contains",
            signature: str = "",
            callable_node: bool = False,
            arity: int | None = None,
            extra: dict[str, Any] | None = None,
        ) -> str {
            member_id: any = _underscore_salted_nid(
                _make_id(type_id, kind, name, signature or name), name, member_groups
            );
            add_node(
                member_id,
                label,
                member,
                kind=kind,
                callable_node=callable_node,
                arity=arity,
                extra=extra,
            );
            add_edge(type_id, member_id, relation, member);
            return member_id;
        }

        for member in body.named_children {
            kind = member.type;
            if kind == "using_directive" {
                alias_nodes: any = [
                    child
                    for child in member.named_children
                    if child.type in {"type_alias", "identifier", "user_defined_type"}
                ];
                for child in member.named_children {
                    if child.type == "using_alias" {
                        alias_nodes.extend(
                            grandchild
                            for grandchild in child.named_children
                            if grandchild.type in {"type_alias", "identifier", "user_defined_type"},
                        );
                    }
                }
                for alias_node in alias_nodes {
                    alias: any = _read_text(alias_node, source);
                    if not alias {
                        continue;
                    }
                    name = alias.split(".")[-1];
                    add_edge(
                        type_id,
                        type_stub(name, member),
                        "uses",
                        member,
                        context=f"solidity_type:{name}",
                    );
                }
                continue;
            }

            if kind == "struct_declaration" {
                member_name_node: any = member.child_by_field_name("name");
                struct_body: any = member.child_by_field_name("body");
                if member_name_node is None {
                    continue;
                }
                name = _read_text(member_name_node, source);
                struct_id: any = add_member(member, name, name, "struct");
                if struct_body is not None {
                    for field in struct_body.named_children {
                        if field.type != "struct_member" {
                            continue;
                        }
                        field_name_node: any = field.child_by_field_name("name");
                        if field_name_node is None {
                            continue;
                        }
                        field_name: any = _read_text(field_name_node, source);
                        field_id: any = _make_id(struct_id, "field", field_name);
                        add_node(field_id, field_name, field, kind="field");
                        add_edge(struct_id, field_id, "contains", field);
                    }
                }
                continue;
            }

            if kind == "enum_declaration" {
                member_name_node = member.child_by_field_name("name");
                enum_body: any = member.child_by_field_name("body");
                if member_name_node is None {
                    continue;
                }
                name = _read_text(member_name_node, source);
                enum_id: any = add_member(member, name, name, "enum");
                if enum_body is not None {
                    for value in enum_body.named_children {
                        if value.type != "enum_value" {
                            continue;
                        }
                        value_name: any = _read_text(value, source);
                        value_id: any = _make_id(enum_id, value_name);
                        add_node(value_id, value_name, value, kind="enum_value");
                        add_edge(enum_id, value_id, "case_of", value);
                    }
                }
                continue;
            }

            simple_kinds: any = {
                "event_definition": "event",
                "error_declaration": "error",
                "state_variable_declaration": "state_variable",
            };
            if kind in simple_kinds {
                member_name_node = member.child_by_field_name("name");
                if member_name_node is None {
                    continue;
                }
                name = _read_text(member_name_node, source);
                arity: any = sum(
                    child.type in {"event_parameter", "error_parameter", "parameter"}
                    for child in member.named_children,
                );
                if kind == "state_variable_declaration" {
                    type_node: any = member.child_by_field_name("type");
                    declared: dict[str, Any] = {};
                    if type_node is not None {
                        state_type: any = _normalize_type(_read_text(type_node, source));
                        state_types[name] = (state_type, type_context);
                        declared["declared_type"] = qualify(state_type, type_context);
                    }
                    reference_targets[name, arity] = add_member(
                        member, name, name, "state_variable", extra=declared
                    );
                } else {
                    member_id: any = add_member(
                        member, name, name, simple_kinds[kind], arity=arity
                    );
                    functions.setdefault((name, arity), []).append(member_id);
                }
                continue;
            }

            if kind not in {
                "function_definition",
                "constructor_definition",
                "modifier_definition",
                "fallback_receive_definition",
            }
            {
                continue;
            }

            name_node = member.child_by_field_name("name");
            if kind == "constructor_definition" {
                name = "constructor";
                callable_kind: any = "constructor";
            } elif kind == "fallback_receive_definition" {
                text: any = _read_text(member, source).lstrip();
                name = "receive" if text.startswith("receive") else "fallback";
                callable_kind = name;
            } else {
                if name_node is None {
                    continue;
                }
                name = _read_text(name_node, source);
                callable_kind = "modifier" if kind == "modifier_definition" else "function";
            }

            parameters: any = [
                child
                for child in member.named_children
                if child.type in {"parameter", "fallback_receive_parameter"}
            ];
            signature = ",".join(
                _read_text(child.child_by_field_name("type"), source)
                for child in parameters
                if child.child_by_field_name("type") is not None,
            );
            arity = len(parameters);
            returned: dict[str, Any] = {};
            return_types: any = [
                parameter.child_by_field_name("type")
                for returns in member.named_children
                if returns.type == "return_type_definition"
                for parameter in returns.named_children
                if parameter.type == "parameter"
            ];
            if type_kind == "library" and callable_kind == "function" {
                returned.update(first_parameter_type(member, type_context));
            }
            if len(return_types) == 1 and return_types[0] is not None {
                returned["returns"] = qualify(
                    _normalize_type(_read_text(return_types[0], source)), type_context
                );
            }
            member_id = add_member(
                member,
                name,
                f"{name}()",
                callable_kind,
                relation="method",
                signature=f"{arity}:{signature}",
                callable_node=True,
                arity=arity,
                extra=returned,
            );
            if callable_kind == "modifier" {
                modifiers[name] = member_id;
            } else {
                functions.setdefault((name, arity), []).append(member_id);
            }
            member_body: any = member.child_by_field_name("body");
            if member_body is not None {
                bodies.append((member_body, member_id, member));
            }
            if callable_kind != "modifier" {
                for child in member.named_children {
                    if child.type != "modifier_invocation" {
                        continue;
                    }
                    modifier_name: any = next(
                        (_read_text(item, source)
                        for item in child.named_children
                        if item.type == "identifier"),
                        "",
                    );
                    if modifier_name {
                        pending_modifiers.append((member_id, modifier_name, child));
                    }
                }
            }
        }

        caller_id: any;
        for (caller_id, modifier_name, modifier_node) in pending_modifiers {
            target = modifiers.get(modifier_name);
            if target {
                add_edge(caller_id, target, "uses", modifier_node);
            } else {
                raw_calls.append(
                    _inherited_call(
                        caller_id, modifier_name, None, "modifier", source_file, modifier_node
                    ),
                );
            }
        }

        own_functions: any = {name for (name, _arity) in functions};
        function_body: any;
        callable_node: any;
        for (function_body, caller_id, callable_node) in bodies {
            scope: any = declared_types(callable_node, type_context, state_types);
            stack: any = [function_body];
            while stack {
                `node: any = stack.pop();
                if `node.type == "call_expression" {
                    callee_node: any = `node.child_by_field_name("function");
                    if callee_node is not None {
                        written: any = _callee_text(callee_node, source);
                        callee: any = written.split(".")[-1];
                        arity = sum(
                            operator.eq(child.type, "call_argument")
                            for child in `node.named_children,
                        );
                        candidates: list[str] = [];
                        if "." not in written or written.startswith("this.") {
                            candidates = functions.get((callee, arity), []);
                        }
                        if len(candidates) == 1 {
                            add_edge(caller_id, candidates[0], "calls", `node);
                        } else {
                            referenced: any = reference_targets.get((callee, arity));
                            if referenced is not None and "." not in written {
                                add_edge(caller_id, referenced, "references", `node);
                            } elif not candidates
                                and callee
                                and ("." not in written or written.startswith("this."))
                            {
                                raw_calls.append(
                                    _inherited_call(
                                        caller_id, callee, arity, "inherited", source_file, `node
                                    ),
                                );
                            } elif written.startswith("super.") and written.count(".") == 1 {
                                raw_calls.append(
                                    _inherited_call(
                                        caller_id, callee, arity, "super", source_file, `node
                                    ),
                                );
                            } elif callee
                                and (
                                    receiver := member_receiver(
                                        callee_node, scope, type_context, own_functions
                                    )
                                )
                            {
                                member_call(caller_id, callee, arity, `node, *receiver);
                            } elif callee and (qualified := split_qualified(written)) {
                                qualified_call(caller_id, *qualified, arity, `node);
                            } elif callee and "." in written {
                                raw_calls.append({
                                    "caller_nid": caller_id,
                                    "callee": callee,
                                    "is_member_call": True,
                                    "language": "solidity",
                                    "source_file": source_file,
                                    "source_location": f"L{`node.start_point[0] + 1}",
                                });
                            }
                        }
                    }
                } elif `node.type in {"emit_statement", "revert_statement"} {
                    emitted: any = `node.child_by_field_name(
                        "name" if `node.type == "emit_statement" else "error"
                    );
                    if emitted is not None
                        and emitted.type == "expression"
                        and emitted.named_children
                    {
                        emitted = emitted.named_children[0];
                    }
                    args: any = `node
                        if `node.type == "emit_statement"
                        else next(
                            (child
                            for child in `node.named_children
                            if child.type == "revert_arguments"),
                            None,
                        );
                    arity = sum(
                        operator.eq(child.type, "call_argument") for child in args.named_children
                    )
                        if args
                        else 0;
                    if emitted is not None and emitted.type == "identifier" {
                        callee = _read_text(emitted, source);
                        candidates = functions.get((callee, arity), []);
                        if len(candidates) == 1 {
                            add_edge(caller_id, candidates[0], "calls", `node);
                        } elif not candidates {
                            raw_calls.append(
                                _inherited_call(
                                    caller_id, callee, arity, "inherited", source_file, `node
                                ),
                            );
                        }
                    } elif emitted is not None and emitted.type == "member_expression" {
                        qualifier: any = emitted.child_by_field_name("object");
                        prop: any = emitted.child_by_field_name("property");
                        if qualifier is not None
                            and prop is not None
                            and qualifier.type == "identifier"
                        {
                            qualified_call(
                                caller_id,
                                _read_text(qualifier, source),
                                _read_text(prop, source),
                                arity,
                                `node,
                            );
                        }
                    }
                }
                stack.extend(reversed(`node.named_children));
            }
        }
    }
    free_functions: dict[tuple[str, int], list[str]] = {};
    free_groups: any = _collision_groups([
        (
            _make_id(
                stem,
                "function",
                _read_text(name_node, source),
                _callable_signature(declaration, source),
            ),
            _read_text(name_node, source),
        )
        for declaration in `root.named_children
        if declaration.type == "function_definition"
            and (name_node := declaration.child_by_field_name("name")) is not None
    ]);
    free_bodies: list[tuple[Node, str, Node]] = [];
    for declaration in `root.named_children {
        if declaration.type != "function_definition" {
            continue;
        }
        name_node = declaration.child_by_field_name("name");
        if name_node is None {
            continue;
        }
        name = _read_text(name_node, source);
        parameters = [child for child in declaration.named_children if child.type == "parameter"];
        signature = ",".join(
            _read_text(child.child_by_field_name("type"), source)
            for child in parameters
            if child.child_by_field_name("type") is not None,
        );
        arity = len(parameters);
        func_id: any = add_node(
            _underscore_salted_nid(
                _make_id(stem, "function", name, f"{arity}:{signature}"), name, free_groups
            ),
            f"{name}()",
            declaration,
            kind="function",
            callable_node=True,
            arity=arity,
            extra=first_parameter_type(declaration, file_context),
        );
        add_edge(file_id, func_id, "contains", declaration);
        free_functions.setdefault((name, arity), []).append(func_id);
        body = declaration.child_by_field_name("body");
        if body is not None {
            free_bodies.append((body, func_id, declaration));
        }
    }
    free_names: any = {name for (name, _arity) in free_functions};
    for (function_body, caller_id, callable_node) in free_bodies {
        scope = declared_types(callable_node, file_context, {});
        stack = [function_body];
        while stack {
            `node = stack.pop();
            if `node.type == "call_expression" {
                callee_node = `node.child_by_field_name("function");
                if callee_node is not None {
                    written = _callee_text(callee_node, source);
                    callee = written.split(".")[-1];
                    arity = sum(
                        operator.eq(child.type, "call_argument") for child in `node.named_children
                    );
                    if "." not in written {
                        candidates = free_functions.get((callee, arity), []);
                        if len(candidates) == 1 {
                            add_edge(caller_id, candidates[0], "calls", `node);
                        }
                    } elif callee
                        and (
                            receiver := member_receiver(
                                callee_node, scope, file_context, free_names
                            )
                        )
                    {
                        member_call(caller_id, callee, arity, `node, *receiver);
                    } elif callee and (qualified := split_qualified(written)) {
                        qualified_call(caller_id, *qualified, arity, `node);
                    } elif callee {
                        raw_calls.append({
                            "caller_nid": caller_id,
                            "callee": callee,
                            "is_member_call": True,
                            "language": "solidity",
                            "source_file": source_file,
                            "source_location": f"L{`node.start_point[0] + 1}",
                        });
                    }
                }
            }
            stack.extend(reversed(`node.named_children));
        }
    }

    clean_edges: any = [
        `edge
        for `edge in edges
        if `edge["source"] in seen_ids
            and (`edge["target"] in seen_ids or `edge["relation"] == "imports_from")
    ];
    return {"nodes": nodes, "edges": clean_edges, "raw_calls": raw_calls};
}
