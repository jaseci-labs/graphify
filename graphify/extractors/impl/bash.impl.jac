impl _bash_source_suffix(raw: str, allow_dotdot: bool = False) -> str | None {
    suffix: any = _BASH_LEADING_EXPANSION.sub("", raw, count=1).lstrip("/");
    if not suffix or "$" in suffix {
        return None;
    }
    if not allow_dotdot and ".." in suffix.split("/") {
        return None;
    }
    return suffix;
}

impl _within_tree(ceiling: Path, target: Path) -> bool {
    c: any = os.path.normpath(`str(ceiling));
    t: any = os.path.normpath(`str(target));
    return operator.eq(t, c) or t.startswith(c + os.sep);
}

impl _safe_to_probe(target: Path, scan_root: Path | None) -> bool {
    if `str(target)[:2] in ("\\\\", "//") {
        return False;
    }
    if scan_root is None {
        return True;
    }
    abs_target: any = os.path.abspath(`str(target));
    if abs_target[:2] in ("\\\\", "//") {
        return False;
    }
    return _within_tree(scan_root, Path(abs_target));
}

impl _resolve_safe(candidate: Path, scan_root: Path | None) -> "Path | None" {
    if not _safe_to_probe(candidate, scan_root) {
        return None;
    }
    try {
        resolved: any = candidate.resolve();
    } except OSError {
        return None;
    }
    if not _safe_to_probe(resolved, scan_root) {
        return None;
    }
    return resolved;
}

impl _bash_assignment_base(value: str, script_dir: Path) -> Path | None {
    val: any = value.strip().strip("'\"");
    if not val {
        return None;
    }
    if "dirname" in val and ("BASH_SOURCE" in val or "$0" in val) {
        m: any = _BASH_DIRNAME_IDIOM.search(val);
        base: any = script_dir;
        for _ in range(m.group(1).count("..") if m else 0) {
            base = base.parent;
        }
        return base;
    }
    if "$" in val or "`" in val {
        return None;
    }
    candidate: any = Path(val);
    return candidate if candidate.is_absolute() else script_dir / candidate;
}

impl extract_bash(path: Path) -> dict {
    source: any;
    stem: any;
    str_path: any;
    scan_root: any;
    nodes: list[dict];
    edges: list[dict];
    raw_calls: list[dict];
    bash_sources: list[dict];
    raw_seen: set[tuple[str, str]];
    seen_ids: set[str];
    function_bodies: list[tuple[str, Any]];
    defined_functions: set[str];
    file_nid: any;
    entry_nid: any;
    _BASH_SOURCE_COMMANDS: any;
    _BASH_SCRIPT_RUNNERS: any;
    _SCRIPT_INVOKERS: any;
    _INVOKABLE_SCRIPT_EXTENSIONS: any;
    _BASH_EXPANSION_PARENTS: any;
    var_bases: dict[str, Path];
    try {
        import tree_sitter_bash as tsbash;
        import from tree_sitter { Language, Parser }
    } except ImportError {
        return {"nodes": [], "edges": [], "error": "tree-sitter-bash not installed"};
    }

    try {
        language: any = Language(tsbash.language());
        parser: any = Parser(language);
        source = _read_source_bytes(path);
        tree: any = parser.parse(source);
        `root: any = tree.root_node;
    } except Exception as e {
        return {"nodes": [], "edges": [], "error": `str(e)};
    }

    stem = _file_stem(path);
    str_path = `str(path);
    scan_root = active_scan_root();
    nodes = [];
    edges = [];
    raw_calls = [];
    bash_sources = [];
    raw_seen = set[any]();
    seen_ids = set[any]();
    function_bodies = [];
    defined_functions = set[any]();

    import from graphify.security { sanitize_metadata }

    def add_node(nid: str, label: str, line: int, kind: str = "code") -> None {
        if nid and nid not in seen_ids {
            seen_ids.add(nid);
            nodes.append({
                "id": nid,
                "label": label,
                "file_type": "code",
                "source_file": str_path,
                "source_location": f"L{line}",
                "metadata": sanitize_metadata({"language": "bash", "kind": kind}),
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
        target_file: str | None = None,
    ) -> None {
        if not src or not tgt or src == tgt {
            return;
        }
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
        if target_file is not None {
            `edge["target_file"] = target_file;
        }
        edges.append(`edge);
    }

    file_nid = _make_id(`str(path));
    entry_nid = file_nid + "__entry";
    add_node(file_nid, path.name, 1, kind="file");
    add_node(entry_nid, f"{path.name} script", 1, kind="bash_entrypoint");
    add_edge(file_nid, entry_nid, "contains", 1);

    _BASH_SOURCE_COMMANDS = frozenset({"source", "."});
    _BASH_SCRIPT_RUNNERS = frozenset({"bash", "sh", "zsh", "ksh", "dash"});
    _SCRIPT_INVOKERS = frozenset({
        "python",
        "python3",
        "python2",
        "node",
        "nodejs",
        "ruby",
        "perl",
    });
    _INVOKABLE_SCRIPT_EXTENSIONS = (".py", ".js", ".mjs", ".cjs", ".rb", ".pl", ".sh");
    _BASH_EXPANSION_PARENTS = frozenset({"command_substitution", "process_substitution"});

    def text(`node) -> str {
        return source[`node.start_byte:`node.end_byte].decode("utf-8", errors="replace");
    }

    def is_inside_expansion(`node) -> bool {
        parent: any = `node.parent;
        while parent is not None {
            if parent.type in _BASH_EXPANSION_PARENTS {
                return True;
            }
            parent = parent.parent;
        }
        return False;
    }

    """Whether a command node should emit call edges.

        Bare ``$(fn)`` at script level and process substitutions stay suppressed
        (#2141). Value capture via ``x=$(fn)`` is a real invocation (#2978).
        """
    def _bash_call_in_command_allowed(cmd_node) -> bool {
        parent: any = cmd_node.parent;
        saw_command_substitution: any = False;
        while parent is not None {
            if parent.type == "process_substitution" {
                return False;
            }
            if parent.type == "command_substitution" {
                saw_command_substitution = True;
            }
            if parent.type == "variable_assignment" and saw_command_substitution {
                return True;
            }
            parent = parent.parent;
        }
        return not saw_command_substitution;
    }

    def literal(`node) -> str | None {
        raw: any;
        raw = text(`node).strip();
        if not raw {
            return None;
        }
        if raw[0:1] in {"'", "\""} and raw[-1:] == raw[0] {
            raw = raw[1:-1];
        }
        if `any(token in raw for token in ("$", "`", "$(", "<(", ">", "|", ";", "&")) {
            return None;
        }
        return raw;
    }

    """Get the name from a function_definition node."""
    def _bash_func_name(`node) -> str | None {
        for child in `node.children {
            if child.type == "word" {
                return literal(child);
            }
        }
        return None;
    }

    def walk_calls(body_node, func_nid: str, seen_calls: set) -> None {
        if body_node is None {
            return;
        }
        for child in body_node.children {
            if child.type == "function_definition" {
                continue;
            }
            if child.type == "command" and _bash_call_in_command_allowed(child) {
                cmd_name_node: any = child.child_by_field_name("name");
                if cmd_name_node is None and child.children {
                    cmd_name_node = child.children[0];
                }
                if cmd_name_node {
                    name: any = literal(cmd_name_node);
                    if name and name in defined_functions {
                        tgt: any = _make_id(stem, name);
                        key: any = (func_nid, tgt);
                        if tgt and key not in seen_calls {
                            seen_calls.add(key);
                            add_edge(
                                func_nid,
                                tgt,
                                "calls",
                                child.start_point[0] + 1,
                                confidence="EXTRACTED",
                                context="call",
                            );
                        }
                    } elif name
                        and name not in _BASH_SOURCE_COMMANDS
                        and name not in _BASH_SCRIPT_RUNNERS
                    {
                        raw_key: any = (func_nid, name);
                        if raw_key not in raw_seen {
                            raw_seen.add(raw_key);
                            raw_calls.append({
                                "language": "bash",
                                "callee": name,
                                "caller_nid": func_nid,
                                "source_file": str_path,
                                "source_location": f"L{child.start_point[0] + 1}",
                            });
                        }
                    }
                }
            }
            walk_calls(child, func_nid, seen_calls);
        }
    }

    def walk(`node, parent_nid: str) -> None {
        t: any = `node.type;
        if t == "function_definition" {
            name: any = _bash_func_name(`node);
            if name {
                fn_nid: any = _make_id(stem, name);
                line: any = `node.start_point[0] + 1;
                add_node(fn_nid, f"{name}()", line, kind="bash_function");
                add_edge(parent_nid, fn_nid, "defines", line);
                defined_functions.add(name);
                body: any = None;
                child: any;
                for child in `node.children {
                    if child.type == "compound_statement" {
                        body = child;
                        break;
                    }
                }
                function_bodies.append((fn_nid, body));
                if body is not None {
                    walk(body, fn_nid);
                }
            }
            return;
        }

        if t == "command" {
            if is_inside_expansion(`node) {
                return;
            }
            cmd_name_node: any = `node.child_by_field_name("name");
            if cmd_name_node is None and `node.children {
                cmd_name_node = `node.children[0];
            }
            if cmd_name_node {
                cmd: any = literal(cmd_name_node);
                args: any = [
                    c
                    for c in `node.children
                    if c.type in ("word", "string", "concatenation") and c != cmd_name_node
                ];
                if cmd in _BASH_SOURCE_COMMANDS and cmd not in defined_functions {
                    if args {
                        raw: any = _read_text(args[0], source).strip().strip("'\"");
                        line = `node.start_point[0] + 1;
                        if raw.startswith((".", "/")) {
                            resolved: any = _resolve_safe(path.parent / raw, scan_root);
                            if resolved is not None and resolved.exists() {
                                tgt_nid: any = _make_id(`str(resolved));
                                add_edge(
                                    file_nid,
                                    tgt_nid,
                                    "imports_from",
                                    line,
                                    context="import",
                                    target_file=`str(resolved),
                                );
                                bash_sources.append({
                                    "target_path": raw,
                                    "source_file": str_path,
                                    "source_location": f"L{line}",
                                });
                            }
                        } elif "$" in raw {
                            dirname_match: any = _BASH_SOURCE_DIRNAME.match(raw);
                            if dirname_match {
                                var_name: any = dirname_match.group(1);
                                if var_name in var_bases {
                                    base: any = var_bases[var_name].parent;
                                } else {
                                    base = path.parent.parent;
                                }
                                suffix: any = raw[dirname_match.end():].lstrip("/");
                                if suffix and "$" not in suffix and ".." not in suffix.split("/") {
                                    resolved = _resolve_safe(base / suffix, scan_root);
                                    if resolved is not None and resolved.is_file() {
                                        add_edge(
                                            file_nid,
                                            _make_id(`str(resolved)),
                                            "imports_from",
                                            line,
                                            confidence="INFERRED",
                                            context="import",
                                            target_file=`str(resolved),
                                        );
                                        bash_sources.append({
                                            "target_path": `str(resolved),
                                            "source_file": str_path,
                                            "source_location": f"L{line}",
                                        });
                                    }
                                }
                            } else {
                                var_match: any = _BASH_LEADING_VAR.match(raw);
                                allow_dotdot: any = False;
                                if var_match {
                                    _vn: any = var_match.group(1) or var_match.group(2);
                                    if _vn in var_bases {
                                        allow_dotdot = True;
                                    }
                                }
                                suffix = _bash_source_suffix(raw, allow_dotdot=allow_dotdot);
                                if suffix {
                                    base = path.parent;
                                    if var_match {
                                        var_name = var_match.group(1) or var_match.group(2);
                                        if var_name in var_bases {
                                            base = var_bases[var_name];
                                        }
                                    }
                                    if var_match and var_name in var_bases {
                                        resolved = Path(os.path.normpath(base / suffix));
                                        ceiling: any = base.parent;
                                    } else {
                                        resolved = (base / suffix).resolve();
                                        ceiling = base;
                                    }
                                    if _within_tree(ceiling, resolved) and resolved.is_file() {
                                        add_edge(
                                            file_nid,
                                            _make_id(`str(resolved)),
                                            "imports_from",
                                            line,
                                            confidence="INFERRED",
                                            context="import",
                                            target_file=`str(resolved),
                                        );
                                        bash_sources.append({
                                            "target_path": `str(resolved),
                                            "source_file": str_path,
                                            "source_location": f"L{line}",
                                        });
                                    }
                                }
                            }
                        } else {
                            sibling: Path | None = None;
                            if raw {
                                try {
                                    cand: any = _resolve_safe(path.parent / raw, scan_root);
                                    if cand is not None and cand.is_file() {
                                        sibling = cand;
                                    }
                                } except OSError {
                                    sibling = None;
                                }
                            }
                            if sibling is not None {
                                add_edge(
                                    file_nid,
                                    _make_id(`str(sibling)),
                                    "imports_from",
                                    line,
                                    confidence="INFERRED",
                                    context="import",
                                    target_file=`str(sibling),
                                );
                                bash_sources.append({
                                    "target_path": raw,
                                    "source_file": str_path,
                                    "source_location": f"L{line}",
                                });
                            } else {
                                tgt_nid = _make_id(raw);
                                if tgt_nid {
                                    add_edge(file_nid, tgt_nid, "imports", line, context="import");
                                }
                            }
                        }
                    }
                } elif cmd not in defined_functions {
                    raw = cmd if cmd and cmd.endswith(".sh") else None;
                    if cmd and cmd in _BASH_SCRIPT_RUNNERS and args {
                        raw = literal(args[0]);
                    }
                    if raw is None {
                        cand = _read_text(cmd_name_node, source).strip().strip("'\"");
                        if cand.endswith(".sh") and "$" in cand {
                            raw = _bash_source_suffix(cand) or None;
                        }
                    }
                    if raw and raw.endswith(".sh") {
                        resolved = _resolve_safe(path.parent / raw, scan_root);
                        if resolved is not None and resolved.is_file() {
                            target_path: any = resolved;
                            if not path.is_absolute() {
                                try {
                                    target_path = resolved.relative_to(Path.cwd().resolve());
                                } except ValueError {}
                            }
                            caller_nid: any = entry_nid if parent_nid == file_nid else parent_nid;
                            add_edge(
                                caller_nid,
                                _make_id(`str(target_path)) + "__entry",
                                "calls",
                                `node.start_point[0] + 1,
                                context="script_invocation",
                                target_file=`str(target_path),
                            );
                        }
                    }
                }
                is_known_interpreter: any = cmd is not None
                    and cmd in _SCRIPT_INVOKERS
                    and cmd not in defined_functions;
                cmd_word: any = text(cmd_name_node).strip();
                if cmd_word[0:1] in {"'", "\""} and cmd_word[-1:] == cmd_word[0] {
                    cmd_word = cmd_word[1:-1];
                }
                is_interpreter_variable: any = cmd is None
                    and cmd_word.startswith("$")
                    and "$(" not in cmd_word
                    and "/" not in cmd_word;
                if (is_known_interpreter or is_interpreter_variable) and args {
                    invoked_raw: any = literal(args[0]);
                    if invoked_raw and invoked_raw.endswith(_INVOKABLE_SCRIPT_EXTENSIONS) {
                        resolved = _resolve_safe(path.parent / invoked_raw, scan_root);
                        if resolved is not None and resolved.is_file() {
                            target_path = resolved;
                            if not path.is_absolute() {
                                try {
                                    target_path = resolved.relative_to(Path.cwd().resolve());
                                } except ValueError {}
                            }
                            caller_nid = entry_nid if parent_nid == file_nid else parent_nid;
                            tgt_nid = _make_id(`str(target_path));
                            if resolved.suffix == ".sh" {
                                tgt_nid += "__entry";
                            }
                            add_edge(
                                caller_nid,
                                tgt_nid,
                                "invokes",
                                `node.start_point[0] + 1,
                                confidence="INFERRED",
                                context="script_invocation",
                                target_file=`str(target_path),
                            );
                        }
                    }
                }
            }
            return;
        }

        if t == "declaration_command" {
            if `node.parent and `node.parent.type == "program" {
                for child in `node.children {
                    if child.type == "variable_assignment" {
                        var_node: any = child.child_by_field_name("name");
                        if var_node {
                            var: any = _read_text(var_node, source).strip();
                            if var {
                                var_nid: any = _make_id(stem, var);
                                line = child.start_point[0] + 1;
                                add_node(var_nid, var, line);
                                add_edge(file_nid, var_nid, "defines", line);
                            }
                        }
                    }
                }
            }
            return;
        }

        for child in `node.children {
            walk(child, parent_nid);
        }
    }
    def _prescan_functions(`node) -> None {
        if `node.type == "function_definition" {
            name: any = _bash_func_name(`node);
            if name {
                defined_functions.add(name);
            }
            child: any;
            for child in `node.children {
                _prescan_functions(child);
            }
        } else {
            for child in `node.children {
                _prescan_functions(child);
            }
        }
    }

    _prescan_functions(`root);
    var_bases = {};
    for _assign in `root.children {
        if _assign.type != "variable_assignment" {
            continue;
        }
        _name_node: any = _assign.child_by_field_name("name");
        _value_node: any = _assign.child_by_field_name("value");
        if _name_node is None or _value_node is None {
            continue;
        }
        _name: any = _read_text(_name_node, source).strip();
        if not _name {
            continue;
        }
        _base: any = _bash_assignment_base(_read_text(_value_node, source), path.parent);
        if _base is not None {
            var_bases[_name] = _base;
        }
    }

    walk(`root, file_nid);
    top_seen: set = set[any]();
    walk_calls(`root, entry_nid, top_seen);
    for (fn_nid, body) in function_bodies {
        walk_calls(body, fn_nid, set[any]());
    }

    return {"nodes": nodes, "edges": edges, "raw_calls": raw_calls, "bash_sources": bash_sources};
}
