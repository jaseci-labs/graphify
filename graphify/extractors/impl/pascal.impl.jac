impl _pascal_strip_comments(text: str) -> str {
    def _sub(m: re.Match) -> str {
        tok: any = m.group(0);
        if tok.startswith("'") {
            return tok;
        }
        return "".join(c if c == "\n" else " " for c in tok);
    }
    return _PAS_TOKEN_RE.sub(_sub, text);
}

impl _pascal_split_sections(text: str) -> tuple[str, int, str, int] {
    iface_m: any = re.search("\\binterface\\b", text, re.IGNORECASE);
    impl_m: any = re.search("\\bimplementation\\b", text, re.IGNORECASE);
    if iface_m and impl_m {
        iface_off: any = iface_m.end();
        impl_off: any = impl_m.end();
        end_m: any = re.search(
            "\\b(initialization|finalization)\\b", text[impl_off:], re.IGNORECASE
        );
        impl_end: any = impl_off + end_m.start() if end_m else len(text);
        return (text[iface_off:impl_m.start()], iface_off, text[impl_off:impl_end], impl_off);
    }
    return ("", 0, text, 0);
}

impl _pascal_split_uses(s: str) -> list[str] {
    out: any = [];
    for chunk in s.split(",") {
        name: any = re.split("\\s+in\\s+", chunk.strip(), maxsplit=1, flags=re.IGNORECASE)[0];
        name = name.strip().strip(";");
        if name and re.match("[A-Za-z_][\\w.]*$", name) {
            out.append(name);
        }
    }
    return out;
}

impl _pascal_split_bases(s: str) -> list[str] {
    out: any;
    depth: any;
    buf: any;
    (out, depth, buf) = ([], 0, []);
    for ch in s {
        if ch == "<" {
            depth += 1;
            buf.append(ch);
        } elif ch == ">" {
            depth -= 1;
            buf.append(ch);
        } elif ch == "," and depth == 0 {
            name: any = re.sub("<.*$", "", "".join(buf).strip());
            if name {
                out.append(name);
            }
            buf = [];
        } else {
            buf.append(ch);
        }
    }
    name = re.sub("<.*$", "", "".join(buf).strip());
    if name {
        out.append(name);
    }
    return [n for n in out if re.match("[A-Za-z_]\\w*$", n)];
}

impl _pascal_find_body(text: str, start: int) -> tuple[int, int] {
    m: any = re.search("\\bbegin\\b", text[start:], re.IGNORECASE);
    if not m {
        return (0, 0);
    }
    body_start: any = start + m.end();
    depth: any = 1;
    for tok in _PAS_BEGIN_END_TOKEN_RE.finditer(text, body_start) {
        kw: any = tok.group(1).lower();
        if kw in ("begin", "case", "try", "asm", "record") {
            depth += 1;
        } elif kw == "end" {
            depth -= 1;
            if depth == 0 {
                return (body_start, tok.start());
            }
        }
    }
    return (body_start, len(text));
}

impl _resolve_pascal_callee_factory(
    records: list[tuple], edges: list[dict], module_nid: str
) -> Callable[[str, str], str | None] {
    class_bases: dict[str, list[str]];
    class_procs: dict[str, dict[str, list[str]]];
    module_procs: dict[str, list[str]];
    global_procs: dict[str, list[str]];
    proc_owner: dict[str, str];
    class_bases = {};
    for e in edges {
        if e.get("relation") == "inherits" {
            class_bases.setdefault(e["source"], []).append(e["target"]);
        }
    }

    class_procs = {};
    module_procs = {};
    global_procs = {};
    proc_owner = {};
    for rec in records {
        proc_nid: any;
        container: any;
        name_lower: any;
        (proc_nid, container, name_lower) = (rec[0], rec[-2], rec[-1]);
        proc_owner[proc_nid] = container;
        global_procs.setdefault(name_lower, []).append(proc_nid);
        if container == module_nid {
            module_procs.setdefault(name_lower, []).append(proc_nid);
        } else {
            class_procs.setdefault(container, {}).setdefault(name_lower, []).append(proc_nid);
        }
    }

    def _resolve(caller_nid: str, name_lower: str) -> str | None {
        owner: any = proc_owner.get(caller_nid);
        if owner is not None {
            candidates: any = class_procs.get(owner, {}).get(name_lower);
            if candidates {
                return candidates[0] if len(candidates) == 1 else None;
            }
            seen_bases: set[str] = set[any]();
            queue: any = `list(class_bases.get(owner, []));
            while queue {
                base: any = queue.pop(0);
                if base in seen_bases {
                    continue;
                }
                seen_bases.add(base);
                candidates = class_procs.get(base, {}).get(name_lower);
                if candidates {
                    return candidates[0] if len(candidates) == 1 else None;
                }
                queue.extend(class_bases.get(base, []));
            }
        }
        candidates = module_procs.get(name_lower);
        if candidates {
            return candidates[0] if len(candidates) == 1 else None;
        }
        candidates = global_procs.get(name_lower);
        if candidates and len(candidates) == 1 {
            return candidates[0];
        }
        return None;
    }

    return _resolve;
}

impl _pascal_parse_health(`root) -> tuple[int, int] {
    covered: any;
    first: any;
    (covered, first) = (0, -1);
    stack: any = [`root];
    while stack {
        `node: any = stack.pop();
        if `node.type == "ERROR" or `node.is_missing {
            covered += `node.end_byte - `node.start_byte;
            if first < 0 or `node.start_byte < first {
                first = `node.start_byte;
            }
            continue;
        }
        stack.extend(`node.children);
    }
    return (covered, 1) if covered == 0 else (covered, -first);
}

impl _normalize_pascal_escaped_string_literals(source: bytes) -> bytes | None {
    out: any = bytearray(source);
    i: any;
    n: any;
    changed: any;
    (i, n, changed) = (0, len(source), False);
    while i < n {
        byte: any = source[i:i + 1];
        if byte == b"/" and source[i:i + 2] == b"//" {
            j: any = source.find(b"\n", i);
            i = n if j < 0 else j + 1;
            continue;
        }
        if byte == b"{" {
            j = source.find(b"}", i);
            i = n if j < 0 else j + 1;
            continue;
        }
        if byte == b"(" and source[i:i + 2] == b"(*" {
            j = source.find(b"*)", i);
            i = n if j < 0 else j + 2;
            continue;
        }
        if byte == b"'" {
            start: any = i;
            leading: any = operator.eq(source[i + 1:i + 3], b"''");
            i += 1;
            while i < n {
                if source[i:i + 1] == b"'" {
                    if source[i + 1:i + 2] == b"'" {
                        i += 2;
                        continue;
                    }
                    i += 1;
                    break;
                }
                if source[i:i + 1] == b"\n" {
                    break;
                }
                i += 1;
            }
            if leading and i - start >= 4 {
                out[start + 1:start + 3] = b"xx";
                changed = True;
            }
            continue;
        }
        i += 1;
    }
    return `bytes(out) if changed else None;
}

impl _normalize_pascal_compiler_directives(source: bytes) -> bytes | None {
    out: any = bytearray(source);
    i: any;
    n: any;
    changed: any;
    (i, n, changed) = (0, len(source), False);
    while i < n {
        byte: any = source[i:i + 1];
        if byte == b"/" and source[i:i + 2] == b"//" {
            j: any = source.find(b"\n", i);
            i = n if j < 0 else j + 1;
            continue;
        }
        if byte == b"'" {
            i += 1;
            while i < n {
                if source[i:i + 1] == b"'" {
                    if source[i + 1:i + 2] == b"'" {
                        i += 2;
                        continue;
                    }
                    i += 1;
                    break;
                }
                if source[i:i + 1] == b"\n" {
                    break;
                }
                i += 1;
            }
            continue;
        }
        if byte == b"{" {
            j = source.find(b"}", i);
            if source[i + 1:i + 2] == b"$" {
                out[i + 1:i + 2] = b" ";
                changed = True;
            }
            i = n if j < 0 else j + 1;
            continue;
        }
        if byte == b"(" and source[i:i + 2] == b"(*" {
            j = source.find(b"*)", i);
            i = n if j < 0 else j + 2;
            continue;
        }
        i += 1;
    }
    return `bytes(out) if changed else None;
}

impl _extract_pascal_regex(path: Path) -> dict {
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    seen_edges: set[tuple[str, str, str]];
    try {
        raw: any = _read_source_text(path, warn=False);
    } except Exception as exc {
        return {"nodes": [], "edges": [], "error": `str(exc)};
    }

    str_path = `str(path);
    stem: any = _file_stem(path);
    nodes = [];
    edges = [];
    seen_ids = set[any]();
    seen_call_pairs: set[tuple[str, str]] = set[any]();
    seen_edges = set[any]();

    def _add_node(nid: str, label: str, line: int) -> None {
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

    def _add_edge(
        src: str, tgt: str, relation: str, line: int, context: str | None = None
    ) -> None {
        key: any = (src, tgt, relation);
        if key in seen_edges {
            return;
        }
        seen_edges.add(key);
        `edge: dict = {
            "source": src,
            "target": tgt,
            "relation": relation,
            "confidence": "EXTRACTED",
            "source_file": str_path,
            "source_location": f"L{line}",
            "weight": 1.0,
        };
        if context {
            `edge["context"] = context;
        }
        edges.append(`edge);
    }

    def _lineno(text: str, offset: int) -> int {
        return text.count("\n", 0, offset) + 1;
    }

    file_nid: any = _make_id(str_path);
    _add_node(file_nid, path.name, 1);

    stripped: any = _pascal_strip_comments(raw);
    module_nid: any = file_nid;
    mod_m: any = _PAS_MODULE_RE.search(stripped);
    if mod_m {
        mod_name: any = mod_m.group(2);
        module_nid = _make_id(stem, mod_name);
        _add_node(module_nid, mod_name, _lineno(stripped, mod_m.start()));
        _add_edge(file_nid, module_nid, "contains", _lineno(stripped, mod_m.start()));
    }

    iface_text: any;
    iface_off: any;
    impl_text: any;
    impl_off: any;
    (iface_text, iface_off, impl_text, impl_off) = _pascal_split_sections(stripped) as any;
    for (section_text, section_off) in ((iface_text, iface_off), (impl_text, impl_off)) {
        for um in _PAS_USES_RE.finditer(section_text) {
            line: any = _lineno(stripped, section_off + um.start());
            for unit_name in _pascal_split_uses(um.group(1)) {
                tgt_nid: any = _pascal_resolve_unit(path, unit_name);
                _add_edge(module_nid, tgt_nid, "imports", line, context="import");
            }
        }
    }
    search_text: any = iface_text or stripped;
    search_off: any = iface_off if iface_text else 0;
    pos: any = 0;
    while pos < len(search_text) {
        hm: any = _PAS_TYPE_HEADER_RE.search(search_text, pos);
        if not hm {
            break;
        }
        type_name: any = hm.group("name");
        bases_raw: any = hm.group("bases") or "";
        line = _lineno(stripped, search_off + hm.start());
        cls_nid: any = _make_id(stem, type_name);
        _add_node(cls_nid, type_name, line);
        _add_edge(module_nid, cls_nid, "contains", line);

        for base_name in _pascal_split_bases(bases_raw) {
            same_file_nid: any = _make_id(stem, base_name);
            if same_file_nid in seen_ids {
                base_nid: any = same_file_nid;
            } else {
                resolved: any = _pascal_resolve_class(path, base_name);
                if resolved {
                    base_nid = resolved;
                } else {
                    base_nid = _make_id(base_name);
                    if base_nid not in seen_ids {
                        _add_node(base_nid, base_name, line);
                    }
                }
            }
            _add_edge(cls_nid, base_nid, "inherits", line);
        }
        end_m: any = _PAS_END_SEMI_RE.search(search_text, hm.end());
        body_text: any = search_text[hm.end():end_m.start()] if end_m else "";
        body_off: any = search_off + hm.end();
        for mm in _PAS_METHOD_DECL_RE.finditer(body_text) {
            mname: any = mm.group("name");
            mline: any = _lineno(stripped, body_off + mm.start());
            method_nid: any = _make_id(cls_nid, mname);
            _add_node(method_nid, f"{mname}()", mline);
            _add_edge(cls_nid, method_nid, "method", mline);
        }

        pos = end_m.end() if end_m else len(search_text);
    }
    impl_records: list[tuple[str, int, str, str, str]] = [];
    for fm in _PAS_IMPL_HEADER_RE.finditer(impl_text) {
        qualified: any = fm.group("qual");
        line = _lineno(stripped, impl_off + fm.start());
        if "." in qualified {
            cls_part: any;
            method_part: any;
            (cls_part, method_part) = qualified.split(".", 1) as any;
            cls_nid = _make_id(stem, cls_part);
            container: any = cls_nid if cls_nid in seen_ids else module_nid;
            relation: any = "method" if cls_nid in seen_ids else "contains";
            label: any = f"{method_part}()";
            name_lower: any = method_part.lower();
        } else {
            (container, relation) = (module_nid, "contains");
            label = f"{qualified}()";
            name_lower = qualified.lower();
        }
        proc_nid: any = _make_id(stem, qualified);
        _add_node(proc_nid, label, line);
        _add_edge(container, proc_nid, relation, line);

        body_start: any;
        body_end: any;
        (body_start, body_end) = _pascal_find_body(impl_text, fm.end()) as any;
        body_text = impl_text[body_start:body_end] if body_start else "";
        impl_records.append((proc_nid, line, body_text, container, name_lower));
    }
    callee_nid: any = _resolve_pascal_callee_factory(impl_records, edges, module_nid);
    raw_calls: list[dict] = [];
    for (caller_nid, caller_line, body_text, _container, _name_lower) in impl_records {
        for cm in _PAS_CALL_RE.finditer(body_text) {
            callee_name: any = cm.group(1).split(".")[-1].lower();
            if callee_name in _PAS_KEYWORDS {
                continue;
            }
            call_line: any = caller_line + body_text.count("\n", 0, cm.start());
            target_nid: any = callee_nid(caller_nid, callee_name);
            if target_nid == caller_nid {
                continue;
            }
            if not target_nid {
                raw_calls.append({
                    "source_file": str_path,
                    "source_location": f"L{call_line}",
                    "caller_nid": caller_nid,
                    "callee": callee_name,
                });
                continue;
            }
            pair: any = (caller_nid, target_nid);
            if pair in seen_call_pairs {
                continue;
            }
            seen_call_pairs.add(pair);
            _add_edge(caller_nid, target_nid, "calls", call_line, context="call");
        }
    }

    return {
        "nodes": nodes,
        "edges": edges,
        "input_tokens": 0,
        "output_tokens": 0,
        "raw_calls": raw_calls,
    };
}

impl extract_pascal(path: Path) -> dict {
    source: any;
    stem: any;
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    seen_edges: set[tuple[str, str, str]];
    proc_bodies: list[tuple[str, Any, str, str]];
    file_nid: any;
    module_nid: any;
    global_vars: dict[str, str];
    fields_of: dict[str, set[str]];
    shadow_by_proc: dict[str, set[str]];
    resolve_callee: any;
    seen_call_pairs: set[tuple[str, str]];
    raw_calls: list[dict];
    try {
        import tree_sitter_pascal as tspascal;
        import from tree_sitter { Language, Parser }
    } except ImportError {
        return _extract_pascal_regex(path);
    }

    try {
        language: any = Language(tspascal.language());
        parser: any = Parser(language);
        source = _read_source_bytes(path);
        tree: any = parser.parse(source);
        `root: any = tree.root_node;
        if `root.has_error {
            masked: any = _normalize_pascal_escaped_string_literals(source) or source;
            masked = _normalize_pascal_compiler_directives(masked) or masked;
            if masked != source {
                retry: any = parser.parse(masked);
                if _pascal_parse_health(retry.root_node) < _pascal_parse_health(`root) {
                    (tree, `root) = (retry, retry.root_node);
                }
            }
        }
    } except Exception {
        return _extract_pascal_regex(path);
    }

    stem = _file_stem(path);
    str_path = `str(path);
    nodes = [];
    edges = [];
    seen_ids = set[any]();
    seen_edges = set[any]();
    proc_bodies = [];

    def _read(`node) -> str {
        return source[`node.start_byte:`node.end_byte].decode("utf-8", errors="replace");
    }

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
        key: any = (src, tgt, relation);
        if key in seen_edges {
            return;
        }
        seen_edges.add(key);
        `edge: dict[str, Any] = {
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
    module_nid = file_nid;
    global_vars = {};
    fields_of = {};
    shadow_by_proc = {};

    """The type of a ``declVar``/``declField``, when it is a plain typeref.

        ``array[1..12] of TDateTime``, records and pointers return None on
        purpose: only a variable holding a class instance can receive a
        method call, and an array's element type is not that variable's type.
        """
    def _plain_type_name(decl_node) -> str | None {
        for child in decl_node.children {
            if child.type != "type" {
                continue;
            }
            for grandchild in child.children {
                if grandchild.type == "typeref" {
                    names: any = [
                        _read(ident)
                        for ident in grandchild.children
                        if ident.type == "identifier"
                    ];
                    if names {
                        return names[-1];
                    }
                }
            }
            return None;
        }
        return None;
    }

    def _declared_names(decl_node) -> list[str] {
        return [_read(child) for child in decl_node.children if child.type == "identifier"];
    }

    def _proc_name(header_node) -> str | None {
        name_node: any = header_node.child_by_field_name("name");
        if name_node {
            return _read(name_node);
        }
        for child in header_node.children {
            if child.type in ("identifier", "genericDot", "genericTpl") {
                return _read(child);
            }
        }
        return None;
    }

    def walk(`node, parent_nid: str) -> None {
        field_names: set[str];
        t: any = `node.type;
        line: any = `node.start_point[0] + 1;

        if t in ("unit", "program", "library") {
            name_node: any = next((c for c in `node.children if c.type == "moduleName"), None);
            mod_name: any = _read(name_node) if name_node else path.stem;
            mod_nid: any = _make_id(stem, mod_name);
            add_node(mod_nid, mod_name, line);
            add_edge(file_nid, mod_nid, "contains", line);
            module_nid = mod_nid;
            child: any;
            for child in `node.children {
                walk(child, mod_nid);
            }
            return;
        }

        if t == "declVars" and parent_nid == module_nid {
            decl: any;
            for decl in `node.children {
                if decl.type != "declVar" {
                    continue;
                }
                type_name: any = _plain_type_name(decl);
                if not type_name {
                    continue;
                }
                for var_name in _declared_names(decl) {
                    global_vars[var_name.lower()] = type_name.lower();
                }
            }
            return;
        }

        if t == "declUses" {
            for child in `node.children {
                if child.type == "moduleName" {
                    mod_name = _read(child);
                    tgt_nid: any = _pascal_resolve_unit(path, mod_name);
                    add_edge(parent_nid, tgt_nid, "imports", line, context="import");
                }
            }
            return;
        }

        if t == "declType" {
            type_name = None;
            kind_node: any = None;
            enum_node: any = None;
            for child in `node.children {
                if child.type == "identifier" and type_name is None {
                    type_name = _read(child);
                } elif child.type in ("declClass", "declIntf", "declHelper") and kind_node is None {
                    kind_node = child;
                } elif child.type == "type" and enum_node is None {
                    enum_node = next((gc for gc in child.children if gc.type == "declEnum"), None);
                }
            }
            if type_name and enum_node is not None {
                enum_nid: any = _make_id(stem, type_name);
                add_node(enum_nid, type_name, line);
                add_edge(parent_nid, enum_nid, "contains", line);
                for value in enum_node.children {
                    if value.type != "declEnumValue" {
                        continue;
                    }
                    value_name_node: any = next(
                        (c for c in value.children if c.type == "identifier"), None
                    );
                    if value_name_node is None {
                        continue;
                    }
                    value_name: any = _read(value_name_node);
                    if not value_name {
                        continue;
                    }
                    value_line: any = value.start_point[0] + 1;
                    value_nid: any = _make_id(enum_nid, value_name);
                    add_node(value_nid, value_name, value_line);
                    add_edge(enum_nid, value_nid, "case_of", value_line);
                }
                return;
            }
            if type_name and kind_node {
                cls_nid: any = _make_id(stem, type_name);
                add_node(cls_nid, type_name, line);
                add_edge(parent_nid, cls_nid, "contains", line);
                field_names = set[any]();

                def _collect_fields(scope_node) -> None {
                    for member in scope_node.children {
                        if member.type == "declField" {
                            field_names.update(name.lower() for name in _declared_names(member));
                        } elif member.type in ("declSection", "declVars") {
                            _collect_fields(member);
                        }
                    }
                }

                _collect_fields(kind_node);
                fields_of[cls_nid] = field_names;
                for child in kind_node.children {
                    if child.type == "typeref" {
                        base_name: any = _read(child);
                        base_nid: any = _make_id(stem, base_name);
                        if base_nid not in seen_ids {
                            resolved: any = _pascal_resolve_class(path, base_name);
                            if resolved {
                                base_nid = resolved;
                            } else {
                                base_nid = _make_id(base_name);
                                if base_nid not in seen_ids {
                                    add_node(base_nid, base_name, line);
                                }
                            }
                        }
                        add_edge(cls_nid, base_nid, "inherits", line);
                    }
                }
                for child in kind_node.children {
                    walk(child, cls_nid);
                }
                return;
            }
            for child in `node.children {
                walk(child, parent_nid);
            }
            return;
        }

        if t == "declProcFwd" {
            header: any = next((c for c in `node.children if c.type == "declProc"), None);
            if header {
                name: any = _proc_name(header);
                if name and "." not in name {
                    method_nid: any = _make_id(parent_nid, name);
                    add_node(method_nid, f"{name}()", line);
                    add_edge(parent_nid, method_nid, "method", line);
                }
            }
            return;
        }

        if t == "defProc" {
            header = next((c for c in `node.children if c.type == "declProc"), None);
            body_node: any = next((c for c in `node.children if c.type == "block"), None);
            if not header {
                for child in `node.children {
                    walk(child, parent_nid);
                }
                return;
            }
            name = _proc_name(header);
            if not name {
                for child in `node.children {
                    walk(child, parent_nid);
                }
                return;
            }
            container: any = parent_nid;
            if "." in name {
                parts: any = name.split(".", 1);
                cls_nid = _make_id(stem, parts[0]);
                if cls_nid in seen_ids {
                    container = cls_nid;
                }
                label: any = f"{parts[-1]}()";
            } else {
                label = f"{name}()";
            }
            proc_nid: any = _make_id(stem, name);
            add_node(proc_nid, label, line);
            add_edge(
                container, proc_nid, "method" if container != parent_nid else "contains", line
            );
            if body_node {
                proc_bodies.append((
                    proc_nid,
                    body_node,
                    container,
                    label.removesuffix("()").lower(),
                ));
                shadowed: any = `set(fields_of.get(container, ()));
                for scope_node in (header, `node) {
                    for member in scope_node.children {
                        if member.type == "declArgs" {
                            for arg in member.children {
                                if arg.type == "declArg" {
                                    shadowed.update(n.lower() for n in _declared_names(arg));
                                }
                            }
                        } elif member.type == "declVars" {
                            for decl in member.children {
                                if decl.type == "declVar" {
                                    shadowed.update(n.lower() for n in _declared_names(decl));
                                }
                            }
                        }
                    }
                }
                shadow_by_proc[proc_nid] = shadowed;
            }
            return;
        }

        for child in `node.children {
            walk(child, parent_nid);
        }
    }

    walk(`root, file_nid);
    resolve_callee = _resolve_pascal_callee_factory(proc_bodies, edges, module_nid);
    seen_call_pairs = set[any]();
    raw_calls = [];

    """``(qualifier, member)`` for a plain ``Ident.Ident`` exprDot.

        Only a bare identifier on the left is accepted. A chain
        (``Grid.Columns.Add``) nests another exprDot there, and its receiver
        is an expression whose type this pass cannot know -- reporting a
        qualifier for it would invite the resolver to guess.
        """
    def _qualified_pair(`node) -> tuple[str, str] | None {
        if `node.type != "exprDot" {
            return None;
        }
        parts: any = [c for c in `node.children if c.is_named and c.type != "kDot"];
        if len(parts) != 2 {
            return None;
        }
        if parts[0].type != "identifier" or parts[1].type != "identifier" {
            return None;
        }
        return (_read(parts[0]).lower(), _read(parts[1]).lower());
    }

    """Keep the qualifier only when it could name a global object.

        `Self` is dropped so a `Self.Foo` call keeps reaching the inherited-call
        resolver, and so is any name the routine declares itself.
        """
    def _visible_qualifier(caller_nid: str, qualifier: str | None) -> str | None {
        if not qualifier or qualifier == "self" {
            return None;
        }
        if qualifier in shadow_by_proc.get(caller_nid, ()) {
            return None;
        }
        return qualifier;
    }

    def _emit_or_report(
        caller_nid: str, name_lower: str, line: int, qualifier: str | None = None
    ) -> None {
        target: any = resolve_callee(caller_nid, name_lower);
        if target == caller_nid {
            return;
        }
        if not target {
            raw_call: dict[str, Any] = {
                "source_file": str_path,
                "source_location": f"L{line}",
                "caller_nid": caller_nid,
                "callee": name_lower,
            };
            qualifier = _visible_qualifier(caller_nid, qualifier);
            if qualifier {
                raw_call["qualifier"] = qualifier;
            }
            raw_calls.append(raw_call);
            return;
        }
        pair: any = (caller_nid, target);
        if pair not in seen_call_pairs {
            seen_call_pairs.add(pair);
            add_edge(caller_nid, target, "calls", line, context="call");
        }
    }

    def walk_calls(`node, caller_nid: str) -> None {
        if `node.type == "exprCall" {
            callee_text: any = None;
            qualifier: any = None;
            child: any;
            for child in `node.children {
                if child.is_named and child.type not in ("exprArgs",) {
                    pair: any = _qualified_pair(child);
                    if pair {
                        (qualifier, callee_text) = pair as any;
                    } else {
                        callee_text = _read(child).split(".")[-1];
                    }
                    break;
                }
            }
            if callee_text {
                _emit_or_report(
                    caller_nid, callee_text.lower(), `node.start_point[0] + 1, qualifier
                );
            }
        } elif `node.type == "statement" {
            named: any = [c for c in `node.children if c.is_named];
            if len(named) == 1 and named[0].type == "identifier" {
                callee_text = _read(named[0]);
                _emit_or_report(caller_nid, callee_text.lower(), `node.start_point[0] + 1);
            } elif len(named) == 1 and named[0].type == "exprDot" {
                pair = _qualified_pair(named[0]);
                if pair {
                    (qualifier, callee_text) = pair as any;
                    qualifier = _visible_qualifier(caller_nid, qualifier);
                    if qualifier {
                        raw_calls.append({
                            "source_file": str_path,
                            "source_location": f"L{`node.start_point[0] + 1}",
                            "caller_nid": caller_nid,
                            "callee": callee_text,
                            "qualifier": qualifier,
                        });
                    }
                }
            }
        }
        for child in `node.children {
            walk_calls(child, caller_nid);
        }
    }

    for (proc_nid, body_node, _container, _name_lower) in proc_bodies {
        walk_calls(body_node, proc_nid);
    }

    return {
        "nodes": nodes,
        "edges": edges,
        "input_tokens": 0,
        "output_tokens": 0,
        "raw_calls": raw_calls,
        "global_vars": global_vars,
    };
}
