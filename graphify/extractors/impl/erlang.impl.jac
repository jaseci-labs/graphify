impl _atom(value: str) -> str {
    value = value.strip();
    if len(value) >= 2 and value[0] == value[-1] == "'" {
        return value[1:-1];
    }
    return value;
}

impl _descendants(`node: Node) -> Generator[any, any, any] {
    for child in `node.named_children {
        yield child;
        yield from _descendants(child);
    }
}

impl resolve_erlang_remote_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) {
    functions: dict[tuple[str, str, int], list[str]] = {};
    for `node in all_nodes {
        metadata: any = `node.get("metadata");
        if not isinstance(metadata, `dict) or metadata.get("language") != "erlang" {
            continue;
        }
        if metadata.get("kind") != "function" {
            continue;
        }
        module: any = metadata.get("module");
        name: any = metadata.get("name");
        arity: any = metadata.get("arity");
        if isinstance(module, `str) and isinstance(name, `str) and isinstance(arity, `int) {
            functions.setdefault((module, name, arity), []).append(`node["id"]);
        }
    }

    existing: any = {
        (`edge.get("source"), `edge.get("target"))
        for `edge in all_edges
        if `edge.get("relation") == "calls"
    };
    for result in per_file {
        for call in result.get("raw_calls", []) {
            if call.get("language") != "erlang" or not call.get("remote_module") {
                continue;
            }
            key: any = (
                `str(call["remote_module"]),
                `str(call.get("callee", "")),
                `int(call.get("arity", -1)),
            );
            candidates: any = functions.get(key, []);
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
                "context": "remote_call",
                "confidence": "EXTRACTED",
                "confidence_score": 1.0,
                "source_file": call.get("source_file", ""),
                "source_location": call.get("source_location"),
                "weight": 1.0,
            });
        }
    }
}

impl extract_erlang(path: Path) -> dict {
    source_file: any;
    nodes: list[dict[str, Any]];
    edges: list[dict[str, Any]];
    seen_ids: set[str];
    seen_edges: set[tuple[str, str, str]];
    `node: any;
    try {
        import from tree_sitter { Parser }
        import from tree_sitter_language_pack { get_language }
    } except ImportError {
        return {"nodes": [], "edges": [], "error": "tree-sitter-language-pack not installed"};
    }

    try {
        source: any = _read_source_bytes(path);
        `root: any = Parser(get_language("erlang")).parse(source).root_node;
    } except Exception as exc {
        return {"nodes": [], "edges": [], "error": f"Erlang grammar failed to load: {exc}"};
    }

    source_file = `str(path);
    stem: any = _file_stem(path);
    file_id: any = _make_id(source_file);
    nodes = [];
    edges = [];
    raw_calls: list[dict[str, Any]] = [];
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
        metadata: dict[str, Any] | None = None,
    ) -> str {
        if nid not in seen_ids {
            seen_ids.add(nid);
            details: dict[str, Any] = {"language": "erlang", "kind": kind};
            if metadata {
                details.update(metadata);
            }
            item: dict[str, Any] = {
                "id": nid,
                "label": label,
                "file_type": "code",
                "source_location": f"L{`node.start_point[0] + 1}",
                "metadata": details,
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

    def add_edge(source_id: str, target_id: str, relation: str, `node: Node) {
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

    module_name: any = path.stem;
    module_declaration: any = next(
        (`node for `node in `root.named_children if `node.type == "module_attribute"), None
    );
    module_id: any = file_id;
    if module_declaration is not None {
        name_node: any = module_declaration.child_by_field_name("name");
        if name_node is not None {
            module_name = _atom(_read_text(name_node, source));
            module_id = add_node(
                _make_id(stem, "module", module_name),
                module_name,
                module_declaration,
                kind="module",
                metadata={"module": module_name},
            );
            add_edge(file_id, module_id, "contains", module_declaration);
        }
    }

    functions: dict[tuple[str, int], str] = {};
    bodies: list[tuple[Node, str]] = [];
    export_specs: list[tuple[str, int, Node]] = [];

    for `node in `root.named_children {
        if `node.type == "export_attribute" {
            for fa in (item for item in _descendants(`node) if item.type == "fa") {
                atom_node: any = next(
                    (item for item in _descendants(fa) if item.type == "atom"), None
                );
                integer: any = next(
                    (item for item in _descendants(fa) if item.type == "integer"), None
                );
                if atom_node is not None and integer is not None {
                    export_specs.append((
                        _atom(_read_text(atom_node, source)),
                        `int(_read_text(integer, source)),
                        fa,
                    ));
                }
            }
            continue;
        }

        if `node.type == "behaviour_attribute" {
            name_node = `node.child_by_field_name("name");
            if name_node is not None {
                name: any = _atom(_read_text(name_node, source));
                target: any = add_node(
                    _make_id("erlang", "behaviour", name),
                    name,
                    name_node,
                    kind="behaviour",
                    source_backed=False,
                );
                add_edge(module_id, target, "implements", `node);
            }
            continue;
        }

        if `node.type in {"pp_include", "pp_include_lib"} {
            string_node: any = next(
                (item for item in `node.named_children if item.type == "string"), None
            );
            if string_node is None {
                continue;
            }
            `include: any = _read_text(string_node, source).strip("\"");
            if `node.type == "pp_include" {
                target = path.parent / `include;
                target_id: any = _make_id(`str(target));
                `edge: any = {
                    "source": module_id,
                    "target": target_id,
                    "relation": "imports_from",
                    "confidence": "EXTRACTED",
                    "source_file": source_file,
                    "source_location": f"L{`node.start_point[0] + 1}",
                    "weight": 1.0,
                    "target_file": `str(target),
                };
                key: any = (module_id, target_id, "imports_from");
                if key not in seen_edges {
                    seen_edges.add(key);
                    edges.append(`edge);
                }
            } else {
                target = add_node(
                    _make_id("erlang", "include_lib", `include),
                    `include,
                    string_node,
                    kind="include_lib",
                    source_backed=False,
                );
                add_edge(module_id, target, "imports", `node);
            }
            continue;
        }

        declaration_kinds: any = {
            "record_decl": ("record", "name"),
            "type_alias": ("type", "name"),
            "opaque": ("type", "name"),
            "pp_define": ("macro", "lhs"),
        };
        if `node.type in declaration_kinds {
            kind: any;
            field: any;
            (kind, field) = declaration_kinds[`node.type] as any;
            name_container: any = `node.child_by_field_name(field);
            if name_container is None {
                continue;
            }
            if kind == "type" {
                name_node = name_container.child_by_field_name("name");
                name = _atom(_read_text(name_node or name_container, source));
                args: any = name_container.child_by_field_name("args");
                arity: any = len(args.named_children) if args is not None else 0;
                label: any = f"{name}/{arity}";
            } elif kind == "macro" {
                name_node = name_container.child_by_field_name("name");
                name = _read_text(name_node or name_container, source);
                label = name;
            } else {
                name = _atom(_read_text(name_container, source));
                label = name;
            }
            declaration_id: any = add_node(
                _make_id(module_id, kind, name),
                label,
                `node,
                kind=kind,
                metadata={"module": module_name, "name": name},
            );
            add_edge(module_id, declaration_id, "contains", `node);
            continue;
        }

        if `node.type != "fun_decl" {
            continue;
        }
        clauses: any = [child for child in `node.named_children if child.type == "function_clause"];
        for clause in clauses {
            name_node = clause.child_by_field_name("name");
            args = clause.child_by_field_name("args");
            if name_node is None or args is None {
                continue;
            }
            name = _atom(_read_text(name_node, source));
            arity = len(args.named_children);
            key = (name, arity);
            function_id: any = functions.get(key);
            if function_id is None {
                function_id = add_node(
                    _make_id(module_id, "function", name, `str(arity)),
                    f"{name}/{arity}",
                    clause,
                    kind="function",
                    callable_node=True,
                    metadata={"module": module_name, "name": name, "arity": arity},
                );
                functions[key] = function_id;
                add_edge(module_id, function_id, "contains", clause);
            }
            body: any = clause.child_by_field_name("body");
            if body is not None {
                bodies.append((body, function_id));
            }
        }
    }

    for (name, arity, spec) in export_specs {
        target = functions.get((name, arity));
        if target is not None {
            add_edge(module_id, target, "exports", spec);
        }
    }

    for (body, caller_id) in bodies {
        stack: any = [body];
        while stack {
            `node = stack.pop();
            if `node.type == "call" {
                callee_node: any = `node.child_by_field_name("expr");
                args = `node.child_by_field_name("args");
                if callee_node is not None and args is not None {
                    arity = len(args.named_children);
                    if callee_node.type == "atom" {
                        name = _atom(_read_text(callee_node, source));
                        target = functions.get((name, arity));
                        if target is not None {
                            add_edge(caller_id, target, "calls", `node);
                        }
                    } elif callee_node.type == "remote" {
                        written: any = _read_text(callee_node, source);
                        module: any;
                        separator: any;
                        (module, separator, name) = written.partition(":") as any;
                        if separator {
                            raw_calls.append({
                                "caller_nid": caller_id,
                                "callee": _atom(name),
                                "arity": arity,
                                "remote_module": _atom(module),
                                "is_member_call": True,
                                "language": "erlang",
                                "source_file": source_file,
                                "source_location": f"L{`node.start_point[0] + 1}",
                            });
                        }
                    }
                }
            } elif `node.type == "internal_fun" {
                name_node = `node.child_by_field_name("fun");
                arity_node: any = `node.child_by_field_name("arity");
                if name_node is not None and arity_node is not None {
                    digits: any = "".join(
                        ch for ch in _read_text(arity_node, source) if ch.isdigit()
                    );
                    if digits {
                        name = _atom(_read_text(name_node, source));
                        target = functions.get((name, `int(digits)));
                        if target is not None {
                            add_edge(caller_id, target, "indirect_call", `node);
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
        if `edge["source"] in seen_ids
            and (`edge["target"] in seen_ids or `edge["relation"] == "imports_from")
    ];
    return {"nodes": nodes, "edges": clean_edges, "raw_calls": raw_calls};
}
