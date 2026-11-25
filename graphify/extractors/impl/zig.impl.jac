impl _is_tagged_union(`node) -> bool {
    return operator.eq(`node.type, "union_declaration")
        and `any(operator.eq(child.type, "(") for child in `node.children);
}

impl extract_zig(path: Path) -> dict {
    source: any;
    stem: any;
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    function_bodies: list[tuple[str, Any]];
    file_nid: any;
    seen_call_pairs: set[tuple[str, str]];
    raw_calls: list[dict];
    try {
        import tree_sitter_zig as tszig;
        import from tree_sitter { Language, Parser }
    } except ImportError {
        return {"nodes": [], "edges": [], "error": "tree_sitter_zig not installed"};
    }

    try {
        language: any = Language(tszig.language());
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

    def _extract_import(`node) -> None {
        for child in `node.children {
            if child.type == "builtin_function" {
                bi: any = None;
                args: any = None;
                for c in child.children {
                    if c.type == "builtin_identifier" {
                        bi = _read_text(c, source);
                    } elif c.type == "arguments" {
                        args = c;
                    }
                }
                if bi in ("@import", "@cImport") and args {
                    for arg in args.children {
                        if arg.type in ("string_literal", "string") {
                            raw: any = _read_text(arg, source).strip("\"");
                            module_name: any = raw.split("/")[-1].split(".")[0];
                            if module_name {
                                tgt_nid: any = _make_id(module_name);
                                add_edge(
                                    file_nid, tgt_nid, "imports_from", `node.start_point[0] + 1
                                );
                            }
                            return;
                        }
                    }
                }
            } elif child.type == "field_expression" {
                _extract_import(child);
                return;
            }
        }
    }

    def walk(`node, parent_struct_nid: str | None = None) -> None {
        t: any = `node.type;
        if t == "container_field"
            and parent_struct_nid
            and `node.parent is not None
            and (`node.parent.type == "enum_declaration" or _is_tagged_union(`node.parent))
        {
            name_node: any = `node.child_by_field_name("name");
            if name_node is None {
                name_node = next((c for c in `node.children if c.type == "identifier"), None);
            }
            if name_node is not None {
                member_name: any = _read_text(name_node, source);
                if member_name {
                    line: any = `node.start_point[0] + 1;
                    member_nid: any = _make_id(parent_struct_nid, member_name);
                    add_node(member_nid, member_name, line);
                    add_edge(parent_struct_nid, member_nid, "case_of", line);
                }
            }
            return;
        }

        if t == "function_declaration" {
            name_node = `node.child_by_field_name("name");
            if name_node {
                func_name: any = _read_text(name_node, source);
                line = `node.start_point[0] + 1;
                if parent_struct_nid {
                    func_nid: any = _make_id(parent_struct_nid, func_name);
                    add_node(func_nid, f".{func_name}()", line);
                    add_edge(parent_struct_nid, func_nid, "method", line);
                } else {
                    func_nid = _make_id(stem, func_name);
                    add_node(func_nid, f"{func_name}()", line);
                    add_edge(file_nid, func_nid, "contains", line);
                }
                body: any = `node.child_by_field_name("body");
                if body {
                    function_bodies.append((func_nid, body));
                }
            }
            return;
        }

        if t == "variable_declaration" {
            name_node = None;
            value_node: any = None;
            child: any;
            for child in `node.children {
                if child.type == "identifier" {
                    name_node = child;
                } elif child.type
                    in (
                        "struct_declaration",
                        "enum_declaration",
                        "union_declaration",
                        "error_set_declaration",
                        "builtin_function",
                        "field_expression",
                    )
                {
                    value_node = child;
                }
            }

            if value_node and value_node.type == "struct_declaration" {
                if name_node {
                    struct_name: any = _read_text(name_node, source);
                    line = `node.start_point[0] + 1;
                    struct_nid: any = _make_id(stem, struct_name);
                    add_node(struct_nid, struct_name, line);
                    add_edge(file_nid, struct_nid, "contains", line);
                    for child in value_node.children {
                        walk(child, parent_struct_nid=struct_nid);
                    }
                }
                return;
            }

            if value_node and value_node.type in ("enum_declaration", "union_declaration") {
                if name_node {
                    type_name: any = _read_text(name_node, source);
                    line = `node.start_point[0] + 1;
                    type_nid: any = _make_id(stem, type_name);
                    add_node(type_nid, type_name, line);
                    add_edge(file_nid, type_nid, "contains", line);
                    for child in value_node.children {
                        walk(child, parent_struct_nid=type_nid);
                    }
                }
                return;
            }

            if value_node and value_node.type == "error_set_declaration" {
                if name_node {
                    type_name = _read_text(name_node, source);
                    line = `node.start_point[0] + 1;
                    type_nid = _make_id(stem, type_name);
                    add_node(type_nid, type_name, line);
                    add_edge(file_nid, type_nid, "contains", line);
                    for child in value_node.children {
                        if child.type != "identifier" {
                            continue;
                        }
                        member_name = _read_text(child, source);
                        if not member_name {
                            continue;
                        }
                        member_line: any = child.start_point[0] + 1;
                        member_nid = _make_id(type_nid, member_name);
                        add_node(member_nid, member_name, member_line);
                        add_edge(type_nid, member_nid, "case_of", member_line);
                    }
                }
                return;
            }

            if value_node and value_node.type in ("builtin_function", "field_expression") {
                _extract_import(`node);
            }
            return;
        }

        for child in `node.children {
            walk(child, parent_struct_nid);
        }
    }

    walk(`root);

    seen_call_pairs = set[any]();
    raw_calls = [];

    def walk_calls(`node, caller_nid: str) -> None {
        wanted_label: any;
        if `node.type == "function_declaration" {
            return;
        }
        if `node.type == "call_expression" {
            fn: any = `node.child_by_field_name("function");
            if fn {
                fn_text: any = _read_text(fn, source);
                callee: any = fn_text.split(".")[-1];
                is_member_call: any = "." in fn_text;
                wanted_label = f".{callee}()" if is_member_call else f"{callee}()";
                tgt_nid: any = next((n["id"] for n in nodes if n["label"] == wanted_label), None);
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
                } elif callee {
                    raw_calls.append({
                        "caller_nid": caller_nid,
                        "callee": callee,
                        "is_member_call": is_member_call,
                        "source_file": str_path,
                        "source_location": f"L{`node.start_point[0] + 1}",
                    });
                }
            }
        }
        for child in `node.children {
            walk_calls(child, caller_nid);
        }
    }

    for (caller_nid, body_node) in function_bodies {
        walk_calls(body_node, caller_nid);
    }

    clean_edges: any = [
        e
        for e in edges
        if e["source"] in seen_ids and (e["target"] in seen_ids or e["relation"] == "imports_from")
    ];
    return {"nodes": nodes, "edges": clean_edges, "raw_calls": raw_calls};
}
