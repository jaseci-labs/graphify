impl extract_ocaml(path: Path) -> dict {
    source: any;
    stem: any;
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    local_defs: dict[str, str];
    ambiguous: set[str];
    local_modules: set[str];
    call_sites: list[tuple[str, str, str | None, str, int]];
    file_nid: any;
    try {
        import tree_sitter_ocaml as tsocaml;
        import from tree_sitter { Language, Parser }
    } except ImportError {
        return {"nodes": [], "edges": [], "error": "tree-sitter-ocaml not installed"};
    }

    try {
        if effective_suffix(path) == ".mli" {
            language: any = Language(tsocaml.language_ocaml_interface());
        } else {
            language = Language(tsocaml.language_ocaml());
        }
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
    local_defs = {};
    ambiguous = set[any]();
    local_modules = set[any]();
    call_sites = [];

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
    ) {
        edges.append({
            "source": src,
            "target": tgt,
            "relation": relation,
            "confidence": confidence,
            "source_file": str_path,
            "source_location": f"L{line}",
            "weight": weight,
        });
    }

    file_nid = _make_id(`str(path));
    add_node(file_nid, path.name, 1);
    def ref_stub(name: str) -> str {
        nid: any = _make_id(name);
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

    def line_of(`node) -> int {
        return `node.start_point[0] + 1;
    }
    def _find_object_body(binding) -> any {
        stack: any = `list(binding.children);
        while stack {
            n: any = stack.pop();
            if n.type in ("object_expression", "class_body_type") {
                return n;
            }
            stack.extend(n.children);
        }
        return None;
    }

    def named_child_text(`node, child_type: str) -> str | None {
        for child in `node.children {
            if child.type == child_type {
                return _read_text(child, source);
            }
        }
        return None;
    }
    def last_name(path_node) -> str | None {
        found: str | None = None;
        for n in path_node.children {
            if n.type in ("value_name", "module_name", "constructor_name") {
                found = _read_text(n, source);
            }
        }
        return found;
    }
    def path_root_module(path_node) -> str | None {
        mp: any = next((c for c in path_node.children if c.type == "module_path"), None);
        if mp is None {
            return None;
        }
        `node: any = mp;
        while True {
            inner: any = next((c for c in `node.children if c.type == "module_path"), None);
            if inner is None {
                break;
            }
            `node = inner;
        }
        mn: any = next((c for c in `node.children if c.type == "module_name"), None);
        return _read_text(mn, source) if mn is not None else None;
    }

    def register_def(name: str, nid: str) {
        if name in ambiguous {
            return;
        }
        if name in local_defs and local_defs[name] != nid {
            ambiguous.add(name);
            local_defs.pop(name, None);
            return;
        }
        local_defs[name] = nid;
    }

    def emit_type(binding, container_nid: str) {
        type_name: any = named_child_text(binding, "type_constructor");
        if not type_name {
            return;
        }
        line: any = line_of(binding);
        nid: any = _make_id(stem, type_name);
        add_node(nid, type_name, line);
        add_edge(container_nid, nid, "defines" if container_nid == file_nid else "contains", line);
        register_def(type_name, nid);
        for vd in binding.children {
            if vd.type != "variant_declaration" {
                continue;
            }
            for cd in vd.children {
                if cd.type != "constructor_declaration" {
                    continue;
                }
                cname: any = named_child_text(cd, "constructor_name");
                if not cname {
                    continue;
                }
                cnid: any = _make_id(stem, type_name, cname);
                add_node(cnid, cname, line_of(cd));
                add_edge(nid, cnid, "contains", line_of(cd));
            }
        }
    }

    def walk(`node, container_nid: str, enclosing_value: str) {
        t: any = `node.type;

        if t == "open_module" {
            mp: any = next((c for c in `node.children if c.type == "module_path"), None);
            name: any = last_name(mp) if mp is not None else None;
            if name {
                add_edge(
                    container_nid,
                    ref_stub(name),
                    "imports_from",
                    line_of(`node),
                    confidence="INFERRED",
                );
            }
            return;
        }

        if t == "module_definition" {
            binding: any;
            for binding in `node.children {
                if binding.type != "module_binding" {
                    continue;
                }
                mname: any = named_child_text(binding, "module_name");
                if mname {
                    line: any = line_of(binding);
                    mnid: any = _make_id(stem, mname);
                    add_node(mnid, mname, line);
                    add_edge(
                        container_nid,
                        mnid,
                        "defines" if container_nid == file_nid else "contains",
                        line,
                    );
                    register_def(mname, mnid);
                    local_modules.add(mname);
                    child: any;
                    for child in binding.children {
                        walk(child, mnid, enclosing_value);
                    }
                }
            }
            return;
        }

        if t == "module_type_definition" {
            mname = named_child_text(`node, "module_type_name");
            if mname {
                line = line_of(`node);
                mnid = _make_id(stem, mname);
                add_node(mnid, mname, line);
                add_edge(
                    container_nid,
                    mnid,
                    "defines" if container_nid == file_nid else "contains",
                    line,
                );
                register_def(mname, mnid);
                local_modules.add(mname);
                for child in `node.children {
                    walk(child, mnid, enclosing_value);
                }
                return;
            }
        }

        if t == "value_definition" {
            is_toplevel: any = `node.parent is not None
                and `node.parent.type in ("compilation_unit", "structure");
            for lb in `node.children {
                if lb.type != "let_binding" {
                    continue;
                }
                vname: any = named_child_text(lb, "value_name");
                new_scope: any = enclosing_value;
                if vname and is_toplevel {
                    line = line_of(lb);
                    nid: any = _make_id(stem, vname);
                    add_node(nid, vname, line);
                    add_edge(
                        container_nid,
                        nid,
                        "defines" if container_nid == file_nid else "contains",
                        line,
                    );
                    register_def(vname, nid);
                    new_scope = nid;
                }
                for child in lb.children {
                    walk(child, container_nid, new_scope);
                }
            }
            return;
        }

        if t == "value_specification" {
            vname = named_child_text(`node, "value_name");
            if vname {
                line = line_of(`node);
                nid = _make_id(stem, vname);
                add_node(nid, vname, line);
                add_edge(
                    container_nid, nid, "defines" if container_nid == file_nid else "contains", line
                );
                register_def(vname, nid);
            }
            return;
        }

        if t == "type_definition" {
            for binding in `node.children {
                if binding.type == "type_binding" {
                    emit_type(binding, container_nid);
                }
            }
            return;
        }

        if t == "class_definition" {
            for binding in `node.children {
                if binding.type != "class_binding" {
                    continue;
                }
                cname: any = named_child_text(binding, "class_name");
                if not cname {
                    continue;
                }
                line = line_of(binding);
                cnid: any = _make_id(stem, cname);
                add_node(cnid, cname, line);
                add_edge(
                    container_nid,
                    cnid,
                    "defines" if container_nid == file_nid else "contains",
                    line,
                );
                register_def(cname, cnid);
                body: any = _find_object_body(binding);
                if body is not None {
                    for member in body.children {
                        if member.type in ("method_definition", "method_specification") {
                            mname = named_child_text(member, "method_name");
                            if not mname {
                                continue;
                            }
                            mline: any = line_of(member);
                            mnid = _make_id(stem, cname, mname);
                            add_node(mnid, mname, mline);
                            add_edge(cnid, mnid, "method", mline);
                            for child in member.children {
                                walk(child, cnid, mnid);
                            }
                        } elif member.type
                            in ("instance_variable_definition", "instance_variable_specification")
                        {
                            vname = named_child_text(member, "instance_variable_name");
                            if not vname {
                                continue;
                            }
                            vline: any = line_of(member);
                            vnid: any = _make_id(stem, cname, vname);
                            add_node(vnid, vname, vline);
                            add_edge(cnid, vnid, "contains", vline);
                        }
                    }
                }
            }
            return;
        }

        if t == "application_expression" {
            fn: any = `node.named_children[0] if `node.named_children else None;
            if fn is not None and fn.type == "value_path" {
                callee: any = last_name(fn);
                if callee {
                    caller: any = enclosing_value or file_nid;
                    call_sites.append((
                        caller,
                        callee,
                        path_root_module(fn),
                        _read_text(fn, source),
                        line_of(`node),
                    ));
                }
            }
        }

        for child in `node.children {
            walk(child, container_nid, enclosing_value);
        }
    }

    walk(`root, file_nid, "");

    for (caller, callee, qualifier, full_path, line) in call_sites {
        if qualifier is not None and qualifier not in local_modules {
            if callee in local_defs {
                add_edge(caller, ref_stub(full_path), "calls", line, confidence="INFERRED");
            } else {
                add_edge(caller, ref_stub(callee), "calls", line, confidence="INFERRED");
            }
        } elif callee in local_defs {
            add_edge(caller, local_defs[callee], "calls", line);
        } else {
            add_edge(caller, ref_stub(callee), "calls", line, confidence="INFERRED");
        }
    }

    return {"nodes": nodes, "edges": edges};
}
