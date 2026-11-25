impl _strip_include_directives(source: bytes) -> bytes {
    return b"\n".join(
        b"" if _INCLUDE_DIRECTIVE_RE.match(line) else line for line in source.split(b"\n")
    );
}

impl _cpp_preprocess(path: Path) -> bytes {
    import shutil;
    import subprocess;
    safe: any = _strip_include_directives(_read_source_bytes(path));
    if not shutil.which("cpp") {
        return safe;
    }
    try {
        result: any = subprocess.run(
            ["cpp", "-w", "-P", "-nostdinc", "-I", "/dev/null"],
            input=safe,
            capture_output=True,
            timeout=30,
        );
        if result.returncode == 0 and result.stdout {
            return result.stdout;
        }
    } except Exception {}
    return safe;
}

impl extract_fortran(path: Path) -> dict {
    source: any;
    stem: any;
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    scope_bodies: list[tuple[str, object]];
    file_nid: any;
    type_bound_procs: list[tuple[str, str, int]];
    generic_procs: list[tuple[str, str, int]];
    try {
        import tree_sitter_fortran as tsfortran;
        import from tree_sitter { Language, Parser }
    } except ImportError {
        return {"nodes": [], "edges": [], "error": "tree-sitter-fortran not installed"};
    }

    try {
        language: any = Language(tsfortran.language());
        parser: any = Parser(language);
        source = _cpp_preprocess(path)
            if path.suffix in _FORTRAN_CPP_EXTS
            else _read_source_bytes(path);
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
    scope_bodies = [];

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
    type_bound_procs = [];
    generic_procs = [];

    """Extract name from a *_statement node. Fortran is case-insensitive; lowercase."""
    def _fortran_name(stmt_node) -> str | None {
        for child in stmt_node.children {
            if child.type in ("name", "identifier") {
                return _read_text(child, source).lower();
            }
        }
        return None;
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

    """Emit references[parameter_type] / references[return_type] edges for
        a subroutine/function based on its variable_declaration siblings."""
    def emit_signature_refs(scope_node, fn_nid: str, is_function: bool) -> None {
        stmt_type: any;
        c: any;
        stmt_type = "function_statement" if is_function else "subroutine_statement";
        stmt: any = next((c for c in scope_node.children if c.type == stmt_type), None);
        if stmt is None {
            return;
        }
        param_names: set[str] = set[any]();
        params_node: any = next((c for c in stmt.children if c.type == "parameters"), None);
        if params_node is not None {
            for c in params_node.children {
                if c.type == "identifier" {
                    param_names.add(_read_text(c, source).lower());
                }
            }
        }
        result_name: str | None = None;
        if is_function {
            result_node: any = next(
                (c for c in stmt.children if c.type == "function_result"), None
            );
            if result_node is not None {
                res_id: any = next(
                    (c for c in result_node.children if c.type == "identifier"), None
                );
                if res_id is not None {
                    result_name = _read_text(res_id, source).lower();
                }
            } else {
                result_name = _fortran_name(stmt);
            }
        }
        for child in scope_node.children {
            if child.type != "variable_declaration" {
                continue;
            }
            derived: any = next((c for c in child.children if c.type == "derived_type"), None);
            if derived is None {
                continue;
            }
            type_name_node: any = next(
                (c for c in derived.children if c.type == "type_name"), None
            );
            if type_name_node is None {
                continue;
            }
            type_name: any = _read_text(type_name_node, source).lower();
            for var in child.children {
                if var.type != "identifier" {
                    continue;
                }
                var_name: any = _read_text(var, source).lower();
                var_line: any = var.start_point[0] + 1;
                if var_name in param_names {
                    tgt: any = ensure_named_node(type_name, var_line);
                    if tgt != fn_nid {
                        add_edge(fn_nid, tgt, "references", var_line, context="parameter_type");
                    }
                } elif is_function and var_name == result_name {
                    tgt = ensure_named_node(type_name, var_line);
                    if tgt != fn_nid {
                        add_edge(fn_nid, tgt, "references", var_line, context="return_type");
                    }
                }
            }
        }
    }

    """The module procedure implementing a type-bound `procedure` statement.

        `procedure :: area => circle_area` binds the method name `area` to the
        implementation `circle_area` (a `binding` node with a `method_name`
        child); `procedure :: scale` binds `scale` to a same-named procedure
        (a bare `method_name` child)."""
    def _type_bound_impl_name(proc_stmt) -> str | None {
        binding: any = next((c for c in proc_stmt.children if c.type == "binding"), None);
        if binding is not None {
            mn: any = next((c for c in binding.children if c.type == "method_name"), None);
            if mn is not None {
                return _read_text(mn, source).lower();
            }
        }
        mn = next((c for c in proc_stmt.children if c.type == "method_name"), None);
        if mn is not None {
            return _read_text(mn, source).lower();
        }
        return None;
    }

    def walk_calls(`node, scope_nid: str) -> None {
        if `node is None {
            return;
        }
        t: any = `node.type;
        if t in ("subroutine", "function", "module", "program", "internal_procedures") {
            return;
        }
        if t == "subroutine_call" {
            name_node: any = next((c for c in `node.children if c.type == "identifier"), None);
            if name_node {
                callee: any = _read_text(name_node, source).lower();
                target_nid: any = ensure_named_node(callee, `node.start_point[0] + 1);
                if target_nid != scope_nid {
                    add_edge(
                        scope_nid,
                        target_nid,
                        "calls",
                        `node.start_point[0] + 1,
                        confidence="EXTRACTED",
                        context="call",
                    );
                }
            }
        } elif t == "call_expression" {
            name_node = next((c for c in `node.children if c.type == "identifier"), None);
            if name_node {
                callee = _read_text(name_node, source).lower();
                target_nid = _make_id(stem, callee);
                if target_nid in seen_ids and target_nid != scope_nid {
                    add_edge(
                        scope_nid,
                        target_nid,
                        "calls",
                        `node.start_point[0] + 1,
                        confidence="EXTRACTED",
                        context="call",
                    );
                }
            }
        }
        for child in `node.children {
            walk_calls(child, scope_nid);
        }
    }

    def walk(`node, scope_nid: str) -> None {
        t: any = `node.type;

        if t == "program" {
            stmt: any = next((c for c in `node.children if c.type == "program_statement"), None);
            name: any = _fortran_name(stmt) if stmt else None;
            if name {
                nid: any = _make_id(stem, name);
                line: any = `node.start_point[0] + 1;
                add_node(nid, name, line);
                add_edge(file_nid, nid, "defines", line);
                scope_bodies.append((nid, `node));
                child: any;
                for child in `node.children {
                    walk(child, nid);
                }
            }
            return;
        }

        if t == "module" {
            stmt = next((c for c in `node.children if c.type == "module_statement"), None);
            name = _fortran_name(stmt) if stmt else None;
            if name {
                nid = _make_id(stem, name);
                line = `node.start_point[0] + 1;
                add_node(nid, name, line);
                add_edge(file_nid, nid, "defines", line);
                for child in `node.children {
                    walk(child, nid);
                }
            }
            return;
        }
        if t == "internal_procedures" {
            for child in `node.children {
                walk(child, scope_nid);
            }
            return;
        }

        if t == "derived_type_definition" {
            stmt = next((c for c in `node.children if c.type == "derived_type_statement"), None);
            if stmt is not None {
                name_node: any = next((c for c in stmt.children if c.type == "type_name"), None);
                if name_node is not None {
                    type_name: any = _read_text(name_node, source).lower();
                    type_nid: any = _make_id(stem, type_name);
                    line = `node.start_point[0] + 1;
                    add_node(type_nid, type_name, line);
                    add_edge(scope_nid, type_nid, "defines", line);
                    base_spec: any = next(
                        (c for c in stmt.children if c.type == "base_type_specifier"), None
                    );
                    if base_spec is not None {
                        base_name_node: any = next(
                            (c for c in base_spec.children if c.type == "identifier"), None
                        );
                        if base_name_node is not None {
                            base_name: any = _read_text(base_name_node, source).lower();
                            base_nid: any = ensure_named_node(base_name, line);
                            if base_nid != type_nid {
                                add_edge(type_nid, base_nid, "inherits", line);
                            }
                        }
                    }
                    procs: any = next(
                        (c for c in `node.children if c.type == "derived_type_procedures"), None
                    );
                    if procs is not None {
                        for stmt in procs.children {
                            if stmt.type != "procedure_statement" {
                                continue;
                            }
                            `impl: any = _type_bound_impl_name(stmt);
                            if `impl {
                                type_bound_procs.append((type_nid, `impl, stmt.start_point[0] + 1));
                            }
                        }
                    }
                }
            }
            return;
        }

        if t == "subroutine" {
            stmt = next((c for c in `node.children if c.type == "subroutine_statement"), None);
            name = _fortran_name(stmt) if stmt else None;
            if name {
                nid = _make_id(stem, name);
                line = `node.start_point[0] + 1;
                add_node(nid, f"{name}()", line);
                add_edge(scope_nid, nid, "defines", line);
                scope_bodies.append((nid, `node));
                emit_signature_refs(`node, nid, is_function=False);
                for child in `node.children {
                    walk(child, nid);
                }
            }
            return;
        }

        if t == "function" {
            stmt = next((c for c in `node.children if c.type == "function_statement"), None);
            name = _fortran_name(stmt) if stmt else None;
            if name {
                nid = _make_id(stem, name);
                line = `node.start_point[0] + 1;
                add_node(nid, f"{name}()", line);
                add_edge(scope_nid, nid, "defines", line);
                scope_bodies.append((nid, `node));
                emit_signature_refs(`node, nid, is_function=True);
                for child in `node.children {
                    walk(child, nid);
                }
            }
            return;
        }

        if t == "interface" {
            stmt = next((c for c in `node.children if c.type == "interface_statement"), None);
            name_node = next((c for c in stmt.children if c.type == "name"), None)
                if stmt is not None
                else None;
            if name_node is not None {
                gen_name: any = _read_text(name_node, source).lower();
                gen_nid: any = _make_id(stem, gen_name);
                line = `node.start_point[0] + 1;
                add_node(gen_nid, f"{gen_name}()", line);
                add_edge(scope_nid, gen_nid, "defines", line);
                for proc_stmt in `node.children {
                    if proc_stmt.type != "procedure_statement" {
                        continue;
                    }
                    for mn in proc_stmt.children {
                        if mn.type == "method_name" {
                            generic_procs.append((
                                gen_nid,
                                _read_text(mn, source).lower(),
                                proc_stmt.start_point[0] + 1,
                            ));
                        }
                    }
                }
                return;
            }
            for child in `node.children {
                walk(child, scope_nid);
            }
            return;
        }

        if t == "use_statement" {
            line = `node.start_point[0] + 1;
            name_node = next(
                (c for c in `node.children if c.type in ("module_name", "name", "identifier")), None
            );
            if name_node {
                mod_name: any = _read_text(name_node, source).lower();
                imp_nid: any = _make_id(mod_name);
                add_node(imp_nid, mod_name, line);
                add_edge(scope_nid, imp_nid, "imports", line, context="use");
            }
            return;
        }

        for child in `node.children {
            walk(child, scope_nid);
        }
    }

    walk(`root, file_nid);
    impl_name: any;
    line: any;
    for (type_nid, impl_name, line) in type_bound_procs {
        tgt: any = ensure_named_node(impl_name, line);
        if tgt != type_nid {
            add_edge(type_nid, tgt, "method", line, context="type_bound_procedure");
        }
    }
    for (gen_nid, impl_name, line) in generic_procs {
        tgt = ensure_named_node(impl_name, line);
        if tgt != gen_nid {
            add_edge(gen_nid, tgt, "dispatches_to", line, context="generic_interface");
        }
    }

    _stmt_headers: any = {
        "subroutine_statement",
        "function_statement",
        "program_statement",
        "module_statement",
    };
    for (scope_nid, body_node) in scope_bodies {
        for child in body_node.children {
            if child.type not in _stmt_headers {
                walk_calls(child, scope_nid);
            }
        }
    }

    return {"nodes": nodes, "edges": edges};
}
