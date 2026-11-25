impl resolve_vbnet_partial_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None {
    methods: dict[tuple[str, str, int], list[str]] = {};
    for `node in all_nodes {
        metadata: any = `node.get("metadata");
        if not isinstance(metadata, `dict) or metadata.get("language") != "vbnet" {
            continue;
        }
        if metadata.get("kind") not in {"method", "constructor"} {
            continue;
        }
        owner: any = metadata.get("owner");
        name: any = metadata.get("name");
        accepted_arities: any = metadata.get("accepted_arities");
        if isinstance(owner, `str)
            and isinstance(name, `str)
            and isinstance(accepted_arities, `list)
        {
            for arity in accepted_arities {
                if isinstance(arity, `int) {
                    methods.setdefault((owner.casefold(), name.casefold(), arity), []).append(
                        `node["id"]
                    );
                }
            }
        }
    }

    existing: any = {
        (`edge.get("source"), `edge.get("target"))
        for `edge in all_edges
        if `edge.get("relation") == "calls"
    };
    for result in per_file {
        for call in result.get("raw_calls", []) {
            if call.get("language") != "vbnet" or not call.get("owner") {
                continue;
            }
            key: any = (
                `str(call["owner"]).casefold(),
                `str(call.get("callee", "")).casefold(),
                `int(call.get("arity", -1)),
            );
            candidates: any = methods.get(key, []);
            caller: any = call.get("caller_nid");
            if len(candidates) != 1 or candidates[0] == caller {
                continue;
            }
            pair: any = (caller, candidates[0]);
            if pair in existing {
                continue;
            }
            existing.add(pair);
            all_edges.append({
                "source": caller,
                "target": candidates[0],
                "relation": "calls",
                "context": "partial_type_call",
                "confidence": "EXTRACTED",
                "confidence_score": 1.0,
                "source_file": call.get("source_file", ""),
                "source_location": call.get("source_location"),
                "weight": 1.0,
            });
        }
    }
}

impl _flatten_multiline_strings(source: bytes) -> bytes {
    out: any = bytearray();
    i: any = 0;
    n: any = len(source);
    at_token_start: any = True;
    while i < n {
        ch: any = source[i];
        if ch == 39
            or at_token_start
                and source[i:i + 3].lower() == b"rem"
                and (i + 3 == n or source[i + 3] in b" \t:\r\n")
        {
            end: any = source.find(b"\n", i);
            end = n if end == -1 else end;
            out += source[i:end];
            i = end;
            continue;
        }
        if ch == 34 or ch == 36 and source[i + 1:i + 2] == b"\"" {
            start: any = i;
            interpolated: any = operator.eq(ch, 36);
            j: any = i + (2 if interpolated else 1);
            depth: any = 0;
            while j < n {
                c: any = source[j];
                if interpolated and c == 123 {
                    depth += 1;
                } elif interpolated and c == 125 and depth {
                    depth -= 1;
                } elif c == 34 and not depth {
                    if source[j + 1:j + 2] == b"\"" {
                        j += 2;
                        continue;
                    }
                    break;
                }
                j += 1;
            }
            if j >= n {
                out += source[start:];
                break;
            }
            literal: any = source[start:j + 1];
            if b"\n" in literal {
                out += b"\"\"" + b" _\n" * literal.count(b"\n");
            } else {
                out += literal;
            }
            i = j + 1;
            at_token_start = False;
            continue;
        }
        out.append(ch);
        at_token_start = not (chr(ch).isalnum() or ch == 95 or ch >= 128);
        i += 1;
    }
    return `bytes(out);
}

impl extract_vbnet(path: Path) -> dict {
    source: any;
    source_file: any;
    stem: any;
    nodes: list[dict[str, Any]];
    edges: list[dict[str, Any]];
    seen_ids: set[str];
    seen_edges: set[tuple[str, str, str]];
    types_by_name: dict[str, str];
    owner_by_short: dict[str, str];
    methods: dict[tuple[str, str, int], list[str]];
    events: dict[tuple[str, str], str];
    bodies: list[tuple[Node, str, str, str]];
    pending_handles: list[tuple[str, str, str, Node]];
    `node: any;
    try {
        import tree_sitter_vb_dotnet;
        import from tree_sitter { Language, Parser }
    } except ImportError {
        return {"nodes": [], "edges": [], "error": "tree-sitter-vb-dotnet not installed"};
    }

    try {
        source = _read_source_bytes(path);
        parser: any = Parser(Language(tree_sitter_vb_dotnet.language()));
        if _OPEN_STRING_LINE.search(source) {
            source = _flatten_multiline_strings(source);
        }
        `root: any = parser.parse(source).root_node;
    } except Exception as exc {
        return {"nodes": [], "edges": [], "error": f"VB.NET grammar failed to load: {exc}"};
    }

    source_file = `str(path);
    stem = _file_stem(path);
    file_id: any = _make_id(source_file);
    nodes = [];
    edges = [];
    raw_calls: list[dict[str, Any]] = [];
    seen_ids = set[any]();
    seen_edges = set[any]();
    types_by_name = {};
    owner_by_short = {};
    methods = {};
    events = {};
    bodies = [];
    pending_handles = [];

    def add_node(
        nid: str,
        label: str,
        `node: Node,
        *,
        kind: str,
        source_backed: bool = True,
        callable_node: bool = False,
        metadata: dict[str, Any] | None = None,
    ) -> str {
        if nid not in seen_ids {
            seen_ids.add(nid);
            details: dict[str, Any] = {"language": "vbnet", "kind": kind};
            if metadata {
                details.update(metadata);
            }
            item: dict[str, Any] = {
                "id": nid,
                "label": label,
                "file_type": "code",
                "source_file": source_file if source_backed else "",
                "source_location": f"L{`node.start_point[0] + 1}" if source_backed else "",
                "metadata": details,
            };
            if callable_node {
                item["_callable"] = True;
            }
            nodes.append(item);
        }
        return nid;
    }

    def add_edge(source_id: str, target_id: str, relation: str, `node: Node) -> None {
        key: any = (source_id, target_id, relation);
        if not source_id or not target_id or source_id == target_id or key in seen_edges {
            return;
        }
        seen_edges.add(key);
        edges.append({
            "source": source_id,
            "target": target_id,
            "relation": relation,
            "confidence": "EXTRACTED",
            "source_file": source_file,
            "source_location": f"L{`node.start_point[0] + 1}",
            "weight": 1.0,
        });
    }

    add_node(file_id, path.name, `root, kind="file");

    for statement in (`node
    for `node in `root.named_children
    if `node.type == "imports_statement") {
        namespace_node: any = next(
            (child for child in statement.named_children if child.type == "namespace_name"), None
        );
        if namespace_node is None {
            continue;
        }
        namespace: any = _read_text(namespace_node, source);
        target: any = add_node(
            _make_id("vbnet", "namespace", namespace.casefold()),
            namespace,
            namespace_node,
            kind="external_namespace",
            source_backed=False,
        );
        add_edge(file_id, target, "imports", statement);
    }

    def type_reference(name: str, `node: Node) -> str {
        short_name: any = name.split(".")[-1];
        target: any = types_by_name.get(short_name.casefold());
        if target is not None {
            return target;
        }
        return add_node(
            _make_id("vbnet", "type", name.casefold()),
            short_name,
            `node,
            kind="external_type",
            source_backed=False,
        );
    }

    def add_data_member(
        type_id: str, member: Node, name: str, kind: str, relation: str = "contains"
    ) -> str {
        member_id: any = add_node(
            _make_id(type_id, kind, name.casefold(), `str(member.start_point[0])),
            name,
            member,
            kind=kind,
        );
        add_edge(type_id, member_id, relation, member);
        return member_id;
    }

    def process_type(block: Node, parent_id: str, namespace: str) -> None {
        kind: any = _TYPE_BLOCKS[block.type];
        name_node: any = block.child_by_field_name("name");
        if name_node is None {
            return;
        }
        name: any = _read_text(name_node, source);
        full_name: any = f"{namespace}.{name}" if namespace else name;
        owner_key: any = full_name.casefold();
        type_id: any = add_node(
            _make_id(stem, "type", owner_key),
            name,
            block,
            kind=kind,
            callable_node=kind in {"class", "structure"},
            metadata={"name": name, "full_name": full_name},
        );
        add_edge(parent_id, type_id, "contains", block);
        types_by_name[name.casefold()] = type_id;
        owner_by_short.setdefault(name.casefold(), owner_key);

        clause: any;
        for clause in block.named_children {
            if clause.type not in {"inherits_clause", "implements_clause"} {
                continue;
            }
            relation: any = "inherits" if clause.type == "inherits_clause" else "implements";
            for type_node in (child for child in clause.named_children if child.type == "type") {
                referenced: any = _read_text(type_node, source);
                add_edge(type_id, type_reference(referenced, type_node), relation, clause);
            }
        }

        for member in block.named_children {
            if member.type == "enum_member" {
                member_name: any = member.child_by_field_name("name");
                if member_name is not None {
                    add_data_member(
                        type_id,
                        member,
                        _read_text(member_name, source),
                        "enum_member",
                        relation="case_of",
                    );
                }
                continue;
            }
            if member.type == "field_declaration" {
                for declarator in (child
                for child in member.named_children
                if child.type == "variable_declarator") {
                    member_name = declarator.child_by_field_name("name");
                    if member_name is not None {
                        add_data_member(
                            type_id, declarator, _read_text(member_name, source), "field"
                        );
                    }
                }
                continue;
            }
            if member.type in {"property_declaration", "event_declaration"} {
                member_name = member.child_by_field_name("name");
                if member_name is not None {
                    data_name: any = _read_text(member_name, source);
                    member_id: any = add_data_member(
                        type_id,
                        member,
                        data_name,
                        "property" if member.type == "property_declaration" else "event",
                    );
                    if member.type == "event_declaration" {
                        events[owner_key, data_name.casefold()] = member_id;
                    }
                }
                continue;
            }
            if member.type not in {
                "method_declaration",
                "constructor_declaration",
                "operator_declaration",
            }
            {
                continue;
            }

            if member.type == "constructor_declaration" {
                method_name: any = "New";
                method_kind: any = "constructor";
            } else {
                method_name_node: any = member.child_by_field_name("name");
                if method_name_node is None {
                    continue;
                }
                method_name = _read_text(method_name_node, source);
                method_kind = "operator" if member.type == "operator_declaration" else "method";
            }
            parameters: any = member.child_by_field_name("parameters");
            parameter_nodes: any = [
                child
                for child in parameters.named_children
                if child.type == "parameter"
            ]
                if parameters is not None
                else [];
            arity: any = len(parameter_nodes);
            required_arity: any = sum(
                parameter.child_by_field_name("default_value") is None
                for parameter in parameter_nodes,
            );
            accepted_arities: any = `list(range(required_arity, arity + 1));
            method_id: any = add_node(
                _make_id(
                    type_id,
                    method_kind,
                    method_name.casefold(),
                    `str(arity),
                    `str(member.start_point[0]),
                ),
                f"{method_name}()",
                member,
                kind=method_kind,
                callable_node=True,
                metadata={
                    "owner": owner_key,
                    "name": method_name,
                    "arity": arity,
                    "accepted_arities": accepted_arities,
                },
            );
            add_edge(type_id, method_id, "method", member);
            for accepted_arity in accepted_arities {
                methods.setdefault((owner_key, method_name.casefold(), accepted_arity), []).append(
                    method_id
                );
            }
            for clause in (child
            for child in member.named_children
            if child.type == "handles_clause") {
                for handled in (child
                for child in clause.named_children
                if child.type == "namespace_name") {
                    pending_handles.append((
                        method_id,
                        owner_key,
                        _read_text(handled, source),
                        handled,
                    ));
                }
            }
            bodies.append((member, method_id, owner_key, name));
        }
    }

    def scan(`node: Node, parent_id: str, namespace: str) -> None {
        if `node.type == "imports_statement" {
            return;
        }
        if `node.type == "namespace_block" {
            name_node: any = `node.child_by_field_name("name");
            if name_node is None {
                return;
            }
            local_name: any = _read_text(name_node, source);
            full_namespace: any = f"{namespace}.{local_name}" if namespace else local_name;
            namespace_id: any = add_node(
                _make_id(stem, "namespace", full_namespace.casefold()),
                local_name,
                `node,
                kind="namespace",
                metadata={"full_name": full_namespace},
            );
            add_edge(parent_id, namespace_id, "contains", `node);
            child: any;
            for child in `node.named_children {
                if child != name_node {
                    scan(child, namespace_id, full_namespace);
                }
            }
            return;
        }
        if `node.type in _TYPE_BLOCKS {
            process_type(`node, parent_id, namespace);
            for child in `node.named_children {
                if child.type == "type_declaration" {
                    scan(child, parent_id, namespace);
                }
            }
            return;
        }
        for child in `node.named_children {
            scan(child, parent_id, namespace);
        }
    }

    scan(`root, file_id, "");

    owner_key: any;
    written: any;
    for (method_id, owner_key, written, handled_node) in pending_handles {
        event_name: any = written.split(".")[-1];
        target = events.get((owner_key, event_name.casefold()));
        if target is None {
            target = add_node(
                _make_id("vbnet", "event", written.casefold()),
                written,
                handled_node,
                kind="external_event",
                source_backed=False,
            );
        }
        add_edge(method_id, target, "handles", handled_node);
    }

    for (body, caller_id, owner_key, type_name) in bodies {
        stack: any = [body];
        while stack {
            `node = stack.pop();
            if `node != body
                and `node.type in {
                    "method_declaration",
                    "constructor_declaration",
                    "property_declaration",
                    "operator_declaration",
                }
            {
                continue;
            }
            if `node.type == "invocation" {
                target_node: any = `node.child_by_field_name("target");
                arguments: any = `node.child_by_field_name("arguments");
                if target_node is not None {
                    written = _read_text(target_node, source);
                    parts: any = written.split(".");
                    receiver: any = ".".join(parts[:-1]).casefold();
                    callee: any = parts[-1];
                    self_receiver: any = not receiver
                        or receiver in {"me", "myclass", type_name.casefold()};
                    target_owner: any = None;
                    if self_receiver {
                        target_owner = owner_key;
                    } else {
                        target_owner = owner_by_short.get(receiver.split(".")[-1]);
                    }
                    if target_owner is not None {
                        arity: any = len(arguments.named_children) if arguments is not None else 0;
                        candidates: any = methods.get((target_owner, callee.casefold(), arity), []);
                        if len(candidates) == 1 {
                            add_edge(caller_id, candidates[0], "calls", `node);
                        } else {
                            raw_calls.append({
                                "caller_nid": caller_id,
                                "callee": callee,
                                "arity": arity,
                                "owner": target_owner,
                                "is_member_call": True,
                                "language": "vbnet",
                                "source_file": source_file,
                                "source_location": f"L{`node.start_point[0] + 1}",
                            });
                        }
                    }
                }
            }
            stack.extend(reversed(`node.named_children));
        }
    }

    clean_edges: any = [
        `edge
        for `edge in edges
        if `edge["source"] in seen_ids and `edge["target"] in seen_ids
    ];
    return {"nodes": nodes, "edges": clean_edges, "raw_calls": raw_calls};
}
