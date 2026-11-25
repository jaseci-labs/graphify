impl extract_commonlisp(path: Path) -> dict {
    source: any;
    stem: any;
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    function_bodies: list[tuple[str, object]];
    current_package: str | None;
    _CL_CHAR_MAP: any;
    file_nid: any;
    local_class_names: any;
    label_to_nid: dict[str, str];
    seen_call_pairs: set[tuple[str, str]];
    try {
        import tree_sitter_commonlisp as tscl;
        import from tree_sitter { Language, Parser }
    } except ImportError {
        return {"nodes": [], "edges": [], "error": "tree-sitter-commonlisp not installed"};
    }

    try {
        with warnings.catch_warnings() {
            warnings.filterwarnings(
                "ignore", message="int argument support is deprecated", category=DeprecationWarning
            );
            language: any = Language(tscl.language());
        }
        parser: any = Parser(language);
        source = _read_source_bytes(path);
        tree: any = parser.parse(source);
        `root: any = tree.root_node;
    } except Exception as e {
        return {"nodes": [], "edges": [], "error": `str(e)};
    }
    stem = _make_id(_file_stem(path));
    str_path = `str(path);
    nodes = [];
    edges = [];
    seen_ids = set[any]();
    function_bodies = [];
    current_package = None;

    def _text(`node) -> str {
        return source[`node.start_byte:`node.end_byte].decode("utf-8", errors="replace");
    }
    _CL_CHAR_MAP = {
        "=": "_eq",
        "<": "_lt",
        ">": "_gt",
        "?": "_p",
        "!": "_bang",
        "+": "_plus",
        "*": "_star",
        "/": "_slash",
        "%": "_pct",
        "&": "_amp",
    };

    def _cl_id(*parts_: str) -> str {
        parts: any = tuple(parts_);
        normalized: any = [];
        for p in parts {
            normalized.append("".join(_CL_CHAR_MAP.get(c, c) for c in p));
        }
        return _make_id(*normalized);
    }

    def add_node(nid: str, label: str, line: int, file_type: str = "code") -> None {
        if nid not in seen_ids {
            seen_ids.add(nid);
            nodes.append({
                "id": nid,
                "label": label,
                "file_type": file_type,
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
    ) -> None {
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

    file_nid = _cl_id(stem);
    add_node(file_nid, path.name, 1);

    """Mint a SOURCELESS stub for an imported package so its `imports` edge
        has a real target instead of dangling. The corpus rewire collapses it
        onto a unique in-corpus `defpackage` of the same name; an external one
        (cl, alexandria) stays a sourceless leaf. `origin_file` is stripped
        before persist (no #1899 leak); a sourced bare stub would salt the id."""
    def add_import_stub(mod_name: str) -> str {
        nid: any = _cl_id(mod_name);
        if nid not in seen_ids {
            seen_ids.add(nid);
            nodes.append({
                "id": nid,
                "label": mod_name,
                "file_type": "code",
                "source_file": "",
                "source_location": "",
                "origin_file": str_path,
            });
        }
        return nid;
    }

    """Resolve a superclass name to a node id.

        If the class is defined in THIS file, bind to its local node. Otherwise
        mint a SOURCELESS stub (like `add_import_stub`) so the corpus-level
        rewire can collapse it onto the real `defclass` in another file. Without
        this, a cross-file superclass had no matching node and its `inherits`
        edge was pruned by the dangling-edge filter — silently erasing every
        inheritance edge whose parent lives in a different file.

        `local` is checked against `local_class_names` (every class this file
        defines, gathered up front), not just `seen_ids`: forms are walked in
        file order, so a class referenced before its own `defclass` form is
        processed — e.g. a subclass listed above its parent — would otherwise
        still be in `seen_ids` as absent, and this would wrongly mint an
        external stub for a class that is right here in the same file."""
    def ensure_class_ref(name: str, line: int) -> str {
        local: any = _cl_id(stem, name);
        if local in seen_ids or name in local_class_names {
            return local;
        }
        stub: any = _cl_id(name);
        if stub not in seen_ids {
            seen_ids.add(stub);
            nodes.append({
                "id": stub,
                "label": name,
                "file_type": "code",
                "source_file": "",
                "source_location": "",
                "origin_file": str_path,
            });
        }
        return stub;
    }

    """Get the first sym_lit text from a list_lit's children."""
    def _first_sym(`node) -> str | None {
        for child in `node.children {
            if child.type == "sym_lit" {
                return _text(child);
            }
        }
        return None;
    }

    """Extract the symbol name from a kwd_lit, stripping the leading colon."""
    def _kwd_text(`node) -> str {
        t: any = _text(`node);
        return t.lstrip(":").lstrip("#:");
    }

    def _handle_defpackage(`node) -> None {
        children: any = `node.children;
        pkg_name: any = None;
        child: any;
        for child in children {
            if child.type == "kwd_lit" and pkg_name is None {
                pkg_name = _kwd_text(child);
                break;
            }
            if child.type == "sym_lit" and _text(child) != "defpackage" {
                pkg_name = _text(child);
                break;
            }
        }
        if not pkg_name {
            return;
        }
        current_package = pkg_name;
        pkg_nid: any = _cl_id(stem, pkg_name);
        line: any = `node.start_point[0] + 1;
        add_node(pkg_nid, pkg_name, line);
        add_edge(file_nid, pkg_nid, "contains", line);
        for child in children {
            if child.type == "list_lit" {
                first: any = _first_sym(child);
                if first is None {
                    for gc in child.children {
                        if gc.type == "kwd_lit" and _kwd_text(gc) == "use" {
                            for uc in child.children {
                                if uc.type == "kwd_lit" and uc != gc {
                                    mod_name: any = _kwd_text(uc);
                                    if mod_name != "use" {
                                        tgt_nid: any = add_import_stub(mod_name);
                                        add_edge(
                                            pkg_nid, tgt_nid, "imports", child.start_point[0] + 1
                                        );
                                    }
                                }
                            }
                            break;
                        }
                    }
                }
            }
        }
    }

    def _handle_defclass(`node) -> None {
        children: any = `node.children;
        sym_lits: any = [c for c in children if c.type == "sym_lit"];
        if len(sym_lits) < 2 {
            return;
        }
        class_name: any = _text(sym_lits[1]);
        line: any = `node.start_point[0] + 1;
        class_nid: any = _cl_id(stem, class_name);
        add_node(class_nid, class_name, line);

        parent_nid: any = file_nid;
        if current_package {
            pkg_nid: any = _cl_id(stem, current_package);
            if pkg_nid in seen_ids {
                parent_nid = pkg_nid;
            }
        }
        add_edge(parent_nid, class_nid, "contains", line);
        list_lits: any = [c for c in children if c.type == "list_lit"];
        if list_lits {
            superclass_list: any = list_lits[0];
            for sc in superclass_list.children {
                if sc.type == "sym_lit" {
                    sc_name: any = _text(sc);
                    sc_nid: any = ensure_class_ref(sc_name, superclass_list.start_point[0] + 1);
                    add_edge(class_nid, sc_nid, "inherits", superclass_list.start_point[0] + 1);
                }
            }
        }
    }

    """Handle a defun AST node (covers defun, defmethod, defgeneric, defmacro)."""
    def _handle_defun_node(`node) -> None {
        header: any = None;
        child: any;
        for child in `node.children {
            if child.type == "defun_header" {
                header = child;
                break;
            }
        }
        if not header {
            return;
        }
        keyword_type: any = "defun";
        func_name: any = None;
        for child in header.children {
            if child.type == "defun_keyword" {
                for kc in child.children {
                    if kc.type in ("defun", "defmethod", "defgeneric", "defmacro") {
                        keyword_type = kc.type;
                        break;
                    }
                }
            }
            if child.type == "sym_lit" and func_name is None {
                func_name = _text(child);
            }
        }

        if not func_name {
            return;
        }

        line: any = `node.start_point[0] + 1;
        func_nid: any = _cl_id(stem, func_name);

        if keyword_type == "defmethod" {
            label: any = f".{func_name}()";
        } elif keyword_type == "defmacro" {
            label = f"{func_name} (macro)";
        } elif keyword_type == "defgeneric" {
            label = f"{func_name} (generic)";
        } else {
            label = f"{func_name}()";
        }

        add_node(func_nid, label, line);

        parent_nid: any = file_nid;
        if current_package {
            pkg_nid: any = _cl_id(stem, current_package);
            if pkg_nid in seen_ids {
                parent_nid = pkg_nid;
            }
        }
        if keyword_type == "defmethod" {
            add_edge(parent_nid, func_nid, "method", line);
        } else {
            add_edge(parent_nid, func_nid, "contains", line);
        }
        if keyword_type == "defmethod" {
            for child in header.children {
                if child.type == "list_lit" {
                    for param in child.children {
                        if param.type == "list_lit" {
                            syms: any = [c for c in param.children if c.type == "sym_lit"];
                            if len(syms) >= 2 {
                                specializer_name: any = _text(syms[1]);
                                spec_nid: any = _cl_id(stem, specializer_name);
                                add_edge(
                                    func_nid, spec_nid, "specializes", param.start_point[0] + 1
                                );
                            }
                        }
                    }
                    break;
                }
            }
        }
        for child in `node.children {
            if child.type == "str_lit" {
                doc_text: any = _text(child).strip("\"");
                if doc_text {
                    doc_nid: any = _cl_id(func_nid, "rationale");
                    add_node(
                        doc_nid,
                        redact_secrets(doc_text)[:120],
                        child.start_point[0] + 1,
                        file_type="rationale",
                    );
                    add_edge(doc_nid, func_nid, "rationale_for", child.start_point[0] + 1);
                }
                break;
            }
        }
        body_nodes: any = [
            c
            for c in `node.children
            if c.type not in ("(", ")", "defun_header", "str_lit")
        ];
        if body_nodes {
            function_bodies.append((func_nid, body_nodes));
        }
    }

    """Get the name being defined. May be a sym_lit or a list_lit whose
        first sym_lit is the name (e.g. (defstruct (foo :conc-name "BAR-") ...))."""
    def _extract_def_name(`node, def_keyword: str) -> str | None {
        seen_keyword: any = False;
        for child in `node.children {
            if not seen_keyword {
                if child.type == "sym_lit" and _text(child).lower() == def_keyword {
                    seen_keyword = True;
                }
                continue;
            }
            if child.type == "sym_lit" {
                return _text(child);
            }
            if child.type == "list_lit" {
                for gc in child.children {
                    if gc.type == "sym_lit" {
                        return _text(gc);
                    }
                }
                return None;
            }
        }
        return None;
    }

    """Collect body forms from (DEFKEYWORD name (params) [doc] body...).
        Skips the def keyword, the name, the params list (if present), and
        a leading docstring str_lit."""
    def _collect_def_body(`node, def_keyword: str) -> list {
        children: any = [c for c in `node.children if c.type not in ("(", ")")];
        idx: any = 0;
        if idx < len(children)
            and children[idx].type == "sym_lit"
            and _text(children[idx]).lower() == def_keyword
        {
            idx += 1;
        }
        if idx < len(children) and children[idx].type in ("sym_lit", "list_lit") {
            idx += 1;
        }
        if idx < len(children) and children[idx].type == "list_lit" {
            idx += 1;
        }
        if idx < len(children) and children[idx].type == "str_lit" {
            idx += 1;
        }
        return children[idx:];
    }

    """Handle a generic (DEFKEYWORD name ...) form. Covers standard CL
        definers (defstruct, deftype, defvar, define-condition, etc.) and
        custom def-prefixed macros (definline, definline-maybe, etc.)."""
    def _handle_def_form(`node, def_keyword: str) -> None {
        name: any = _extract_def_name(`node, def_keyword);
        if not name {
            return;
        }
        line: any = `node.start_point[0] + 1;
        nid: any = _cl_id(stem, name);

        kw: any = def_keyword.lower();
        if kw in _CL_DATA_DEFINERS {
            label: any = name;
            is_callable: any = False;
        } elif kw in _CL_MACRO_DEFINERS or "macro" in kw {
            label = f"{name} (macro)";
            is_callable = True;
        } else {
            label = f"{name}()";
            is_callable = True;
        }

        add_node(nid, label, line);

        parent_nid: any = file_nid;
        if current_package {
            pkg_nid: any = _cl_id(stem, current_package);
            if pkg_nid in seen_ids {
                parent_nid = pkg_nid;
            }
        }
        add_edge(parent_nid, nid, "contains", line);
        if kw not in _CL_VALUE_DEFINERS {
            for child in `node.children {
                if child.type == "str_lit" {
                    doc_text: any = _text(child).strip("\"");
                    if doc_text {
                        doc_nid: any = _cl_id(nid, "rationale");
                        add_node(
                            doc_nid,
                            redact_secrets(doc_text)[:120],
                            child.start_point[0] + 1,
                            file_type="rationale",
                        );
                        add_edge(doc_nid, nid, "rationale_for", child.start_point[0] + 1);
                    }
                    break;
                }
            }
        }

        if is_callable {
            body_nodes: any = _collect_def_body(`node, def_keyword);
            if body_nodes {
                function_bodies.append((nid, body_nodes));
            }
        }
    }

    """Heuristic: does this symbol look like a definition macro?"""
    def _is_def_prefixed(sym: str) -> bool {
        if sym in _CL_NOT_DEFINERS {
            return False;
        }
        return sym.startswith("def") or sym.startswith("define-");
    }

    """Dispatch on a single list_lit form. Returns True if it was
        recognized as a definition or package directive (caller must NOT
        recurse into it). Returns False if unrecognized, so the caller can
        recurse to find defs nested inside wrapper macros like
        (optimizing ...), (eval-when ...), (progn ...), etc."""
    def _process_form(top) -> bool {
        child: any;
        for child in top.children {
            if child.type == "defun" {
                _handle_defun_node(child);
                return True;
            }
        }

        first: any = _first_sym(top);
        if not first {
            return False;
        }
        first_lower: any = first.lower();

        if first_lower == "defpackage" {
            _handle_defpackage(top);
            return True;
        }
        if first_lower == "in-package" {
            for child in top.children {
                if child.type == "kwd_lit" {
                    current_package = _kwd_text(child);
                    break;
                }
                if child.type == "sym_lit" and _text(child) != "in-package" {
                    current_package = _text(child);
                    break;
                }
            }
            return True;
        }
        if first_lower == "defclass" {
            _handle_defclass(top);
            return True;
        }
        if first_lower in ("require", "ql:quickload") {
            for child in top.children {
                if child.type in ("kwd_lit", "str_lit") {
                    mod_name: any = _kwd_text(child)
                        if child.type == "kwd_lit"
                        else _text(child).strip("\"");
                    if mod_name {
                        tgt_nid: any = add_import_stub(mod_name);
                        add_edge(file_nid, tgt_nid, "imports", top.start_point[0] + 1);
                    }
                    break;
                }
            }
            return True;
        }
        if first_lower in _CL_DATA_DEFINERS or first_lower in _CL_MACRO_DEFINERS {
            _handle_def_form(top, first_lower);
            return True;
        }
        if _is_def_prefixed(first_lower) {
            _handle_def_form(top, first_lower);
            return True;
        }

        return False;
    }

    """Walk list_lit children of `parent`, processing each. If a form
        isn't recognized, recurse into it — many CL codebases wrap
        definitions in macros like (optimizing ...), (eval-when ...), or
        (progn ...) that aren't themselves definers but contain defs.
        Also descends into reader conditionals (#+feature / #-feature),
        which wrap their guarded form in an include_reader_macro node."""
    def _walk_forms(parent) -> None {
        for top in parent.children {
            if top.type == "list_lit" {
                if not _process_form(top) {
                    _walk_forms(top);
                }
            } elif top.type == "include_reader_macro" {
                _walk_forms(top);
            }
        }
    }

    """Collect every name this file defines via `defclass`, regardless of
        where in the file the definition sits, so `ensure_class_ref` can tell
        a forward-referenced same-file class apart from a genuinely external
        one before `_walk_forms` reaches the defining form. Mirrors
        `_walk_forms`'s own recursion rule (stop at a recognized top-level
        form, descend into anything else) so it finds a `defclass` nested in
        a wrapper macro the same way the real walk later will."""
    def _prescan_class_names(parent) -> set[str] {
        names: set[str] = set[any]();
        for top in parent.children {
            if top.type == "list_lit" {
                first: any = _first_sym(top);
                first_lower: any = (first or "").lower();
                if first_lower == "defclass" {
                    sym_lits: any = [c for c in top.children if c.type == "sym_lit"];
                    if len(sym_lits) >= 2 {
                        names.add(_text(sym_lits[1]));
                    }
                } elif not first
                    or first_lower not in ("defpackage", "in-package", "require", "ql:quickload")
                        and first_lower not in _CL_DATA_DEFINERS
                        and first_lower not in _CL_MACRO_DEFINERS
                        and not _is_def_prefixed(first_lower)
                {
                    names |= _prescan_class_names(top);
                }
            } elif top.type == "include_reader_macro" {
                names |= _prescan_class_names(top);
            }
        }
        return names;
    }

    local_class_names = _prescan_class_names(`root);

    _walk_forms(`root);
    label_to_nid = {};
    for n in nodes {
        raw: any = n["label"];
        normalised: any = raw.replace(" (macro)", "").replace(" (generic)", "").strip("()").lstrip(
            "."
        );
        label_to_nid[normalised.lower()] = n["id"];
    }

    seen_call_pairs = set[any]();

    def walk_calls(`node, caller_nid: str) -> None {
        if `node.type == "defun" {
            return;
        }
        if `node.type == "list_lit" {
            callee: any = _first_sym(`node);
            if callee and callee.lower() not in _CL_SPECIAL_FORMS {
                tgt_nid: any = label_to_nid.get(callee.lower());
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
                }
            }
        }
        for child in `node.children {
            walk_calls(child, caller_nid);
        }
    }

    for (caller_nid, body_nodes) in function_bodies {
        for body_node in body_nodes {
            walk_calls(body_node, caller_nid);
        }
    }

    clean_edges: any = [
        e
        for e in edges
        if e["source"] in seen_ids
            and (e["target"] in seen_ids or e["relation"] in ("imports", "imports_from"))
    ];
    return {"nodes": nodes, "edges": clean_edges};
}
