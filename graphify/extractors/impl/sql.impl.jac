impl _scan_sql(text: str) -> tuple[str, list[tuple[int, int]]] {
    out: list[str];
    i: any;
    n: any;
    ident_spans: list[tuple[int, int]] = [];
    out = [];
    (i, n) = (0, len(text));

    """Blank [i, upto), keeping newlines; return upto."""
    def _blank(upto: int) -> int {
        for c in text[i:upto] {
            out.append("\n" if c == "\n" else " ");
        }
        return upto;
    }

    """Blank from start to end-of-line, carrying comment state forward.

        The union-of-readings blank for an ambiguous stretch: the rest of the
        line is blanked outright; if the raw text of that stretch leaves a /*
        unclosed on its own line (the maximum comment depth any reading could
        be left holding), blanking continues, nesting-aware, to the closing
        */ or EOF. Where a carry closes MID-line the same rule applies to the
        remainder of that line — under the reading where the carry never
        opened, that whole line may be a comment or a string, so emitting the
        post-*/ text verbatim exposed it (found by differential fuzzing).
        Repeats until a line ends with no carry pending. Appends one output
        character per input character; returns the resume index.
        """
    def _blank_tail_and_carry(start: int) -> int {
        k: any = start;
        while True {
            eol: any = text.find("\n", k);
            eol = n if eol == -1 else eol;
            depth: any = 0;
            m2: any = k;
            while m2 < eol {
                if text.startswith("/*", m2) {
                    depth += 1;
                    m2 += 2;
                } elif text.startswith("*/", m2) {
                    if depth {
                        depth -= 1;
                    }
                    m2 += 2;
                } else {
                    m2 += 1;
                }
            }
            ch: any;
            for ch in text[k:eol] {
                out.append("\n" if ch == "\n" else " ");
            }
            k = eol;
            if not depth {
                return k;
            }
            j2: any = k;
            while j2 < n and depth {
                if text.startswith("/*", j2) {
                    depth += 1;
                    j2 += 2;
                } elif text.startswith("*/", j2) {
                    depth -= 1;
                    j2 += 2;
                } else {
                    j2 += 1;
                }
            }
            for ch in text[k:j2] {
                out.append("\n" if ch == "\n" else " ");
            }
            k = j2;
            if k >= n {
                return k;
            }
        }
    }

    while i < n {
        c: any = text[i];
        if c == "'" {
            j: any = i + 1;
            while j < n and text[j] != "\n" {
                if text[j] == "'" {
                    if j + 1 < n and text[j + 1] == "'" {
                        j += 2;
                        continue;
                    }
                    j += 1;
                    break;
                }
                j += 1;
            }
            i = _blank(j);
        } elif c == "\"" or c == "[" {
            closer: any = "\"" if c == "\"" else "]";
            j = i + 1;
            closed: any = False;
            while j < n and text[j] != "\n" {
                if text[j] == closer {
                    if j + 1 < n and text[j + 1] == closer {
                        j += 2;
                        continue;
                    }
                    j += 1;
                    closed = True;
                    break;
                }
                j += 1;
            }
            span: any = text[i:j];
            if closed and "--" not in span and "/*" not in span {
                ident_spans.append((i, j));
                out.append(span);
                i = j;
            } else {
                i = _blank_tail_and_carry(i);
            }
        } elif c == "-" and i + 1 < n and text[i + 1] == "-" {
            j = i;
            while j < n and text[j] != "\n" {
                j += 1;
            }
            i = _blank(j);
        } elif c == "/" and i + 1 < n and text[i + 1] == "*" {
            depth: any;
            (depth, j) = (1, i + 2);
            while j < n and depth {
                if text[j] == "/" and j + 1 < n and text[j + 1] == "*" {
                    depth += 1;
                    j += 2;
                } elif text[j] == "*" and j + 1 < n and text[j + 1] == "/" {
                    depth -= 1;
                    j += 2;
                } else {
                    j += 1;
                }
            }
            i = _blank(j);
        } else {
            out.append(c);
            i += 1;
        }
    }
    return ("".join(out), ident_spans);
}

impl _routine_body_refs(masked: str, *, plsql: bool = False) -> list[tuple[str, str, int]] {
    non_tables: any;
    m: any;
    pos: any;
    name: any;
    non_tables = `set(_BODY_NON_TABLES);
    cm: any;
    for cm in _BODY_CTE_RX.finditer(masked) {
        non_tables.add(_norm_ident(cm.group(1)));
    }

    def _usable(name: str) -> bool {
        return _norm_ident(name) not in non_tables;
    }

    writes: list[tuple[int, int, str, str]] = [];
    for m_ in _BODY_WRITE_RX.finditer(masked) {
        m = m_;
        if plsql and m.group(1).upper() == "INTO" {
            continue;
        }
        if m.group(1).upper() != "INTO"
            and _BODY_EVENT_RX.search(masked[max(0, m.start() - 30):m.start()])
        {
            continue;
        }
        if _usable(m.group(2)) {
            writes.append((m.start(), m.end(), "writes_to", m.group(2)));
        }
    }

    reads: list[tuple[int, str]] = [];
    aliases: dict[str, str] = {};
    for m__ in _BODY_READ_RX.finditer(masked) {
        m = m__;
        if `any(
            s <= m.start() and m.start() < e
            for (s, e, _r, _n) in writes,
        ) {
            continue;
        }
        if _BODY_FROM_NOT_TABLE_RX.search(masked[max(0, m.start() - 200):m.start()]) {
            continue;
        }
        if not _usable(m.group(1)) or masked[m.end():].lstrip().startswith("(") {
            continue;
        }
        reads.append((m.start(), m.group(1)));
        curr_pos: any = m.end();
        am: any = _BODY_ALIAS_RX.match(masked, curr_pos);
        if am and am.group(1).lower() not in non_tables {
            aliases.setdefault(am.group(1).lower(), m.group(1));
            curr_pos = am.end();
        }
        if m.group(0).lstrip()[:4].upper() == "FROM" {
            while True {
                cm = _BODY_COMMA_TABLE_RX.match(masked, curr_pos);
                if not cm {
                    break;
                }
                c_tbl: any = cm.group(1);
                if not _usable(c_tbl) or masked[cm.end():].lstrip().startswith("(") {
                    break;
                }
                reads.append((cm.start(1), c_tbl));
                curr_pos = cm.end();
                cam: any = _BODY_ALIAS_RX.match(masked, curr_pos);
                if cam and cam.group(1).lower() not in non_tables {
                    aliases.setdefault(cam.group(1).lower(), c_tbl);
                    curr_pos = cam.end();
                }
            }
        }
    }

    refs: any = [(pos, "reads_from", name) for (pos, name) in reads];
    for (pos, _end, relation, name) in writes {
        if "." not in name {
            name = aliases.get(name.lower(), name);
        }
        refs.append((pos, relation, name));
    }
    return [(relation, name, pos) for (pos, relation, name) in sorted(refs)];
}

impl _package_members(masked: str, start: int, limit: int) -> list[tuple[str, int, tuple[int, int]
    | None, bool]] {
    pkg_head: any = _PLSQL_HEAD_END_RX.search(masked, start, limit);
    if pkg_head is None or pkg_head.group() == ";" {
        return [];
    }
    members: list[tuple[str, int, tuple[int, int] | None, bool]] = [];
    stack: list[bool] = [];
    open_member: tuple[int, int] | None = None;
    in_init: any = False;
    for tok in _PLSQL_BLOCK_RX.finditer(masked, pkg_head.end(), limit) {
        if tok.group(1) {
            if stack and not stack[-1] {
                continue;
            }
            head: any = _PLSQL_HEAD_END_RX.search(masked, tok.end(), limit);
            is_def: any = head is not None and operator.ne(head.group(), ";");
            if not stack {
                members.append((tok.group(1), tok.start(), None, is_def));
            }
            if head is not None
                and is_def
                and not _PLSQL_CALL_SPEC_RX.match(masked, head.end(), limit)
            {
                if not stack {
                    open_member = (len(members) - 1, head.end());
                }
                stack.append(True);
            }
        } elif tok.group(2) {
            if tok.group(2).upper() == "BEGIN" and stack and stack[-1] {
                stack[-1] = False;
            } else {
                in_init = in_init or not stack and operator.eq(tok.group(2).upper(), "BEGIN");
                stack.append(False);
            }
        } elif not tok.group(3) {
            if not stack {
                break;
            }
            stack.pop();
            if not stack and in_init {
                break;
            }
            if not stack and open_member is not None {
                idx: any;
                body_start: any;
                (idx, body_start) = open_member as any;
                name: any;
                pos: any;
                _span: any;
                (name, pos, _span, is_def) = members[idx] as any;
                members[idx] = (name, pos, (body_start, tok.start()), is_def);
                open_member = None;
            }
        }
    }
    return members;
}

impl _go_separators(source: bytes) -> list[tuple[int, int]] {
    try {
        text: any = source.decode("utf-8");
    } except UnicodeDecodeError {
        return [];
    }
    masked: any = _scan_sql(text)[0];
    spans: list[tuple[int, int]] = [];
    size: any = len(masked);
    value_: any = 0;
    char_pos: any = value_;
    byte_pos: any = value_;
    for m in _GO_LINE_RX.finditer(masked) {
        before: any;
        after: any;
        (before, after) = (m.start() - 1, m.end());
        while before >= 0 and masked[before].isspace() {
            before -= 1;
        }
        while after < size and masked[after].isspace() {
            after += 1;
        }
        start: any;
        end: any;
        (start, end) = (m.start(1), m.end(1));
        byte_start: any = byte_pos + len(text[char_pos:start].encode("utf-8"));
        byte_end: any = byte_start + len(text[start:end].encode("utf-8"));
        (char_pos, byte_pos) = (end, byte_end);
        if before >= 0 and masked[before] == "," or after < size and masked[after] in ",)" {
            continue;
        }
        spans.append((byte_start, byte_end));
    }
    return spans;
}

impl _mask_sql_comments(text: str) -> str {
    return _scan_sql(text)[0];
}

impl _clean_part(part: str) -> str {
    return part.removeprefix("[").removesuffix("]").replace("]]", "]");
}

impl _clean_ident(name: str) -> str {
    if "@" in name {
        tbl: any;
        link: any;
        (tbl, link) = name.split("@", 1) as any;
        return f"{_clean_ident(tbl)}@{link}";
    }
    if "[" not in name and "]" not in name {
        return name;
    }
    return ".".join(
        p if p.startswith("\"") else _clean_part(p)
        for p in (part.strip() for part in name.split(".")),
    );
}

impl _norm_ident(name: str) -> str {
    if "@" in name {
        tbl: any;
        link: any;
        (tbl, link) = name.split("@", 1) as any;
        return f"{_norm_ident(tbl)}@{_norm_ident(link)}";
    }
    parts: any = [];
    for part in name.split(".") {
        p: any = part.strip();
        if len(p) >= 2 and p[0] == p[-1] and p[0] in ("\"", "`") {
            p = p[1:-1];
        } else {
            p = _clean_part(p);
        }
        parts.append(p.lower());
    }
    return ".".join(parts);
}

impl extract_sql(path: Path, content: str | bytes | None = None) -> dict {
    source: any;
    stem: any;
    str_path: any;
    file_nid: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    table_nids: dict[str, str];
    routine_nids: dict[str, str];
    structured_routine_lines: dict[str, int];
    error_routines: set[str];
    m: any;
    try {
        import tree_sitter_sql as tssql;
        import from tree_sitter { Language, Parser }
    } except ImportError as e {
        import importlib.util;
        if importlib.util.find_spec("tree_sitter_sql") is None {
            return {
                "nodes": [],
                "edges": [],
                "error": "tree_sitter_sql not installed. Run: pip install tree-sitter-sql",
            };
        }
        return {
            "nodes": [],
            "edges": [],
            "error": f"tree_sitter_sql is installed but failed to load: {e}",
        };
    }

    try {
        language: any = Language(tssql.language());
        parser: any = Parser(language);
        source = content.encode("utf-8")
            if isinstance(content, `str)
            else content if content is not None else _read_source_bytes(path);
        patched: any = bytearray(source);
        end: any;
        for (start, end) in _go_separators(source) {
            patched[start:end] = b";" + b" " * (end - start - 1);
        }
        tree: any = parser.parse(`bytes(patched));
        `root: any = tree.root_node;
    } except Exception as e {
        return {"nodes": [], "edges": [], "error": `str(e)};
    }

    stem = _file_stem(path);
    str_path = `str(path);
    file_nid = _make_id(str_path);
    nodes = [
        {
            "id": file_nid,
            "label": path.name,
            "file_type": "code",
            "source_file": str_path,
            "source_location": None,
        },
    ];
    edges = [];
    seen_ids = {file_nid};
    table_nids = {};
    routine_nids = {};
    structured_routine_lines = {};
    error_routines = set[any]();

    def _read(n) -> str {
        return source[n.start_byte:n.end_byte].decode("utf-8", errors="replace");
    }

    def _obj_name(n) -> str | None {
        for c in n.children {
            if c.type == "object_reference" {
                return _read(c);
            }
        }
        return None;
    }

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
            edges.append({
                "source": file_nid,
                "target": nid,
                "relation": "contains",
                "confidence": "EXTRACTED",
                "source_file": str_path,
                "source_location": f"L{line}",
                "weight": 1.0,
            });
        }
    }

    def _add_edge(src: str, tgt: str, relation: str, line: int) -> None {
        if not src or not tgt {
            return;
        }
        edges.append({
            "source": src,
            "target": tgt,
            "relation": relation,
            "confidence": "EXTRACTED",
            "source_file": str_path,
            "source_location": f"L{line}",
            "weight": 1.0,
        });
    }

    """Sourceless bare-name stub for a table referenced but not defined here.

        SQL references are NAME-based, so a table defined in another file (e.g.
        prisma migration m2 referencing a table created in m1) can only resolve
        at the corpus level. Minting `_make_id(stem, name)` under THIS file's
        stem fabricated a node-less compound id — an absolute-path slug when the
        input path was absolute — that could never match the real definition
        (#2324). Instead emit a SOURCELESS stub, mirroring the Go extractor's
        cross-file pattern (#1402): `_rewire_unique_stub_nodes` collapses it
        onto the unique real table definition, and an unresolvable name survives
        as a portable name-only node instead of dangling. No contains edge: a
        sourced/contained stub would get the referencing file's path baked into
        its id by disambiguation, blocking the rewire.
        """
    def _ref_stub(name: str) -> str {
        nid: any = _make_id(name);
        if not nid {
            return nid;
        }
        if nid not in seen_ids {
            seen_ids.add(nid);
            nodes.append({
                "id": nid,
                "label": _clean_ident(name),
                "file_type": "code",
                "source_file": "",
                "source_location": "",
                "origin_file": str_path,
            });
        }
        return nid;
    }

    def walk(`node) -> None {
        cd: any;
        t: any = `node.type;
        line: any = `node.start_point[0] + 1;

        if t == "create_table" {
            name: any = _obj_name(`node);
            if name {
                nid: any = _make_id(stem, name);
                _add_node(nid, _clean_ident(name), line);
                table_nids[_norm_ident(name)] = nid;
                for col in `node.children {
                    if col.type == "column_definitions" {
                        has_error: any = `any(operator.eq(cd.type, "ERROR") for cd in col.children);
                        seen_refs: set[str] = set[any]();
                        for cd in col.children {
                            if cd.type == "column_definition" {
                                ref_name: str | None = None;
                                found_ref: any = False;
                                cc: any;
                                for cc in cd.children {
                                    if cc.type == "keyword_references" {
                                        found_ref = True;
                                    } elif found_ref and cc.type == "object_reference" {
                                        ref_name = _read(cc);
                                        break;
                                    }
                                }
                                if ref_name {
                                    ref_nid: any = table_nids.get(_norm_ident(ref_name))
                                        or _ref_stub(ref_name);
                                    _add_edge(nid, ref_nid, "references", line);
                                    seen_refs.add(_norm_ident(ref_name));
                                }
                            } elif cd.type == "constraints" {
                                for constraint in cd.children {
                                    if constraint.type != "constraint" {
                                        continue;
                                    }
                                    ref_name = None;
                                    found_ref = False;
                                    for cc in constraint.children {
                                        if cc.type == "keyword_references" {
                                            found_ref = True;
                                        } elif found_ref and cc.type == "object_reference" {
                                            ref_name = _read(cc);
                                            break;
                                        }
                                    }
                                    if ref_name {
                                        ref_nid = table_nids.get(_norm_ident(ref_name))
                                            or _ref_stub(ref_name);
                                        _add_edge(nid, ref_nid, "references", line);
                                        seen_refs.add(_norm_ident(ref_name));
                                    }
                                }
                            }
                        }
                        if has_error {
                            col_text: any = _read(col);
                            rm: any;
                            for rm in re.finditer(
                                "\\bREFERENCES\\s+([\\w$]+)", col_text, re.IGNORECASE
                            ) {
                                ref_name = rm.group(1);
                                if _norm_ident(ref_name) not in seen_refs {
                                    ref_nid = table_nids.get(_norm_ident(ref_name))
                                        or _ref_stub(ref_name);
                                    _add_edge(nid, ref_nid, "references", line);
                                    seen_refs.add(_norm_ident(ref_name));
                                }
                            }
                        }
                    }
                }
            }
        } elif t == "create_view" {
            name = _obj_name(`node);
            if name {
                nid = _make_id(stem, name);
                _add_node(nid, _clean_ident(name), line);
                table_nids[_norm_ident(name)] = nid;
                _walk_from_refs(`node, nid, line);
            }
        } elif t == "create_function" {
            name = _obj_name(`node);
            if name {
                nid = _make_id(stem, name);
                _add_node(nid, f"{_clean_ident(name)}()", line);
                routine_nids[_norm_ident(name)] = nid;
                structured_routine_lines[nid] = line;
                _walk_from_refs(`node, nid, line);
                _walk_writes(`node, nid);
                if `node.has_error {
                    error_routines.add(nid);
                }
            }
        } elif t == "create_procedure" {
            name = _obj_name(`node);
            if name {
                nid = _make_id(stem, name);
                _add_node(nid, f"{_clean_ident(name)}()", line);
                routine_nids[_norm_ident(name)] = nid;
                structured_routine_lines[nid] = line;
                _walk_from_refs(`node, nid, line);
                _walk_writes(`node, nid);
                if `node.has_error {
                    error_routines.add(nid);
                }
            }
        } elif t == "alter_table" {
            name = _obj_name(`node);
            if name {
                src_nid: any = table_nids.get(_norm_ident(name));
                if not src_nid {
                    src_nid = _ref_stub(name);
                    table_nids[_norm_ident(name)] = src_nid;
                }
                child: any;
                for child in `node.children {
                    if child.type == "add_constraint" {
                        for cc in child.children {
                            if cc.type != "constraint" {
                                continue;
                            }
                            found_ref = False;
                            ref_name = None;
                            for ccc in cc.children {
                                if ccc.type == "keyword_references" {
                                    found_ref = True;
                                } elif found_ref and ccc.type == "object_reference" {
                                    ref_name = _read(ccc);
                                    break;
                                }
                            }
                            if ref_name {
                                ref_nid = table_nids.get(_norm_ident(ref_name))
                                    or _ref_stub(ref_name);
                                _add_edge(src_nid, ref_nid, "references", line);
                            }
                        }
                    }
                }
            }
        } elif t == "create_trigger" {
            trig_name: str | None = None;
            tbl_name: str | None = None;
            exec_name: str | None = None;
            after_trigger: any = False;
            after_on: any = False;
            after_execute: any = False;
            c: any;
            for c in `node.children {
                if c.type == "keyword_trigger" {
                    after_trigger = True;
                } elif after_trigger and not trig_name and c.type == "object_reference" {
                    trig_name = _read(c);
                } elif c.type == "keyword_on" {
                    after_on = True;
                } elif after_on and not tbl_name and c.type == "object_reference" {
                    tbl_name = _read(c);
                } elif c.type == "keyword_execute" {
                    after_execute = True;
                } elif after_execute and not exec_name and c.type == "object_reference" {
                    exec_name = _read(c);
                }
            }
            if trig_name {
                trig_nid: any = _make_id(stem, trig_name);
                _add_node(trig_nid, trig_name, line);
                if tbl_name {
                    tbl_nid: any = table_nids.get(_norm_ident(tbl_name)) or _ref_stub(tbl_name);
                    _add_edge(trig_nid, tbl_nid, "triggers", line);
                }
                if exec_name {
                    routine_nid: any = routine_nids.get(_norm_ident(exec_name));
                    if routine_nid {
                        _add_edge(trig_nid, routine_nid, "executes", line);
                    }
                }
            }
        } elif t == "create_index" {
            index_name: str | None = None;
            index_table: str | None = None;
            after_on = False;
            for c in `node.children {
                if c.type == "keyword_on" {
                    after_on = True;
                } elif not after_on and index_name is None and c.type in ("identifier", "literal") {
                    index_name = _read(c).strip("\"`");
                } elif after_on and index_table is None and c.type == "object_reference" {
                    index_table = _read(c);
                }
            }
            if index_name {
                index_nid: any = _make_id(stem, index_name);
                _add_node(index_nid, index_name, line);
                if index_table {
                    index_tbl_nid: any = table_nids.get(_norm_ident(index_table))
                        or _ref_stub(index_table);
                    _add_edge(index_nid, index_tbl_nid, "indexes", line);
                }
            }
        } elif t == "fb_proc_or_trigger" {
            text: any = _read(`node);
            m: any = re.match(
                "CREATE\\s+(?:OR\\s+(?:REPLACE|ALTER)\\s+)?(PROCEDURE|TRIGGER|FUNCTION)\\s+([\\w$]+)",
                text,
                re.IGNORECASE,
            );
            if m {
                obj_type: any = m.group(1).upper();
                obj_name: any = m.group(2);
                obj_nid: any = _make_id(stem, obj_name);
                label: any = obj_name if obj_type == "TRIGGER" else f"{obj_name}()";
                _add_node(obj_nid, label, line);
                if obj_type == "TRIGGER" {
                    fm: any = re.search("\\bFOR\\s+([\\w$]+)", text, re.IGNORECASE);
                    if fm {
                        tbl: any = fm.group(1);
                        tbl_nid = table_nids.get(_norm_ident(tbl)) or _ref_stub(tbl);
                        _add_edge(obj_nid, tbl_nid, "triggers", line);
                    }
                }
                _NON_TABLES: any = {
                    "select",
                    "where",
                    "set",
                    "dual",
                    "null",
                    "true",
                    "false",
                    "first",
                    "skip",
                    "rows",
                    "next",
                    "only",
                    "lateral",
                };
                for cm in re.finditer(
                    "(?:\\bWITH\\s+(?:RECURSIVE\\s+)?|,\\s*)([\\w$]+)\\s*(?:\\([^()]*\\))?\\s+AS\\s*\\(",
                    text,
                    re.IGNORECASE,
                ) {
                    _NON_TABLES.add(_norm_ident(cm.group(1)));
                }
                seen_tbls: set[str] = set[any]();
                for rm in re.finditer("\\b(?:FROM|JOIN|INTO)\\s+([\\w$]+)", text, re.IGNORECASE) {
                    tbl = rm.group(1);
                    if _norm_ident(tbl) not in _NON_TABLES and _norm_ident(tbl) not in seen_tbls {
                        seen_tbls.add(_norm_ident(tbl));
                        tbl_nid = table_nids.get(_norm_ident(tbl)) or _ref_stub(tbl);
                        _add_edge(obj_nid, tbl_nid, "reads_from", line);
                    }
                }
                for rm in re.finditer("\\bUPDATE\\s+([\\w$]+)", text, re.IGNORECASE) {
                    tbl = rm.group(1);
                    if _norm_ident(tbl) not in _NON_TABLES and _norm_ident(tbl) not in seen_tbls {
                        seen_tbls.add(_norm_ident(tbl));
                        tbl_nid = table_nids.get(_norm_ident(tbl)) or _ref_stub(tbl);
                        _add_edge(obj_nid, tbl_nid, "reads_from", line);
                    }
                }
            }
        }

        for child in `node.children {
            walk(child);
        }
    }

    """(table as written, alias) of a `relation`, a bare `from`, or a naked
        object_reference — the three places this grammar puts a table name.

        Only `relation` (and the bare `from` of a DELETE) can carry an alias:
        the bare identifier next to the object_reference is one (`dbo.Orders
        o`). The identifiers INSIDE an object_reference are its name parts and
        must not be read as an alias.
        """
    def _table_of(`node) -> tuple[str | None, str | None] {
        c: any;
        has_siblings: any = `node.type in ("relation", "from");
        `obj: any = `node;
        if has_siblings {
            `obj = next((c for c in `node.children if c.type == "object_reference"), None);
            if `obj is None {
                alias_node: any = next(
                    (c
                    for c in `node.children
                    if c.type == "identifier" and not _read(c).startswith("@")),
                    None,
                );
                return (None, _read(alias_node) if alias_node is not None else None);
            }
        } elif `node.type != "object_reference" {
            return (None, None);
        }

        name: any = _read(`obj);
        suffix: any = "";
        alias: any = None;
        if has_siblings {
            for c in `node.children {
                if c is `obj or c.type != "identifier" {
                    continue;
                }
                text: any = _read(c);
                if text.startswith("@") {
                    suffix = text;
                } else {
                    alias = text;
                }
            }
            if alias is None and not _is_temp(name) and len(`node.children) == 1 {
                if len(`obj.children) == 1 and `obj.children[0].type == "identifier" {
                    return (None, name);
                }
            }
        }
        if suffix and name.startswith("@") {
            return (name, alias);
        }
        return (f"{name}{suffix}", alias);
    }

    """`#t` / `##t` / `@t`: a temp table or a table variable, i.e. session
        state rather than a schema object."""
    def _is_temp(tbl: str) -> bool {
        return tbl.lstrip("[").startswith(("#", "@"));
    }

    """The table a DELETE/UPDATE/INSERT/MERGE writes, as written.

        A session object (`#t`, `##t`, `@t`) is returned as-is; the caller drops
        it, since `_is_temp` has to answer that for the earlier shapes too.
        """
    def _write_table(write_node) -> str | None {
        if write_node.type == "insert"
            and not `any(operator.eq(c.type, "keyword_into") for c in write_node.children)
        {
            return None;
        }
        first: any = next(
            (c for c in write_node.children if c.type in ("object_reference", "relation")), None
        );
        if first is not None {
            marker: any = first.prev_sibling;
            while marker is not None and marker.type.startswith("keyword_") {
                marker = marker.prev_sibling;
            }
            if marker is not None and _read(marker).strip() in ("#", "##", "@") {
                return f"#{_read(first).strip()}";
            }
        }
        target: any = next(
            (c for c in write_node.children if c.type in ("relation", "object_reference", "from")),
            None,
        );
        tbl: any;
        alias: any;
        (tbl, alias) = (_table_of(target) if target is not None else (None, None)) as any;
        if tbl is not None {
            return tbl;
        }
        if target is None {
            stmt: any = write_node.parent;
            clause: any;
            for clause in (c for c in (stmt.children if stmt else []) if c.type == "from") {
                rel: any;
                for rel in clause.children {
                    if rel.type in ("object_reference", "relation") {
                        return _table_of(rel)[0];
                    }
                }
            }
            return None;
        }
        stmt = write_node.parent;
        if stmt is None {
            return None;
        }
        scopes: any = [write_node, stmt];
        for scope in scopes {
            for clause in (c for c in scope.children if c.type in ("from", "join")) {
                rels: any = clause.children
                    if clause.type == "from"
                    else [cc for cc in clause.children if cc.type == "relation"];
                for rel in rels {
                    r_tbl: any;
                    r_alias: any;
                    (r_tbl, r_alias) = _table_of(rel) as any;
                    if r_tbl and alias and r_alias and r_alias.lower() == alias.lower() {
                        return r_tbl;
                    }
                }
            }
        }
        return None;
    }

    """Emit `writes_to` for the writes in a structurally parsed routine.

        tree-sitter-sql 0.3.13 parses T-SQL `CREATE PROCEDURE ... AS BEGIN
        ... END` into `procedure_body`, so its statements stay in the tree
        instead of an ERROR node. The masked-text scan that reads writes only
        runs when the parse failed, and `_walk_from_refs` only looked at
        FROM/JOIN — so a DELETE/UPDATE/INSERT or `SELECT ... INTO` in such a
        procedure silently lost its edge (#5146).

        Deliberately separate from _walk_from_refs, whose CTE and derived-table
        handling this does not need to touch.
        """
    def _walk_writes(`node, caller_nid: str) -> None {
        if `node.type in ("delete", "update", "insert", "merge") {
            tbl: any = _write_table(`node);
            if tbl and not _is_temp(tbl) {
                tbl_nid: any = table_nids.get(_norm_ident(tbl)) or _ref_stub(tbl);
                _add_edge(caller_nid, tbl_nid, "writes_to", `node.start_point[0] + 1);
            }
        } elif `node.type == "statement" {
            for (i, c) in enumerate(`node.children) {
                if c.type != "keyword_into" {
                    continue;
                }
                target: any = next(
                    (cc for cc in `node.children[i + 1:] if cc.type == "select_expression"), None
                );
                if target is not None {
                    tbl = _read(target).strip();
                    if tbl and not _is_temp(tbl) {
                        tbl_nid = table_nids.get(_norm_ident(tbl)) or _ref_stub(tbl);
                        _add_edge(caller_nid, tbl_nid, "writes_to", c.start_point[0] + 1);
                    }
                }
                break;
            }
        }
        for child in `node.children {
            _walk_writes(child, caller_nid);
        }
    }

    cte_names_default_: any = frozenset();

    """Recursively find FROM/JOIN table references inside a node, skipping CTEs.

        A name bound by `WITH <name> AS (...)` is not a table: emitting it as a
        `reads_from` target minted a bare `_ref_stub`, and because that stub is
        intentionally sourceless (see `_ref_stub`) it carried no schema, file, or
        language namespace, so a CTE named `levels` or `slug` collided with any
        same-named node from another language during the build (#2577).

        Scoping matters: a CTE is visible only inside the query that declares it,
        and a `WITH` inside a subquery is scoped to that subquery alone. So the
        active set is extended PER SUBTREE — each node's directly-owned `cte`
        children (`create_query` for a statement-level WITH, `subquery` for a
        nested one) join the set passed down into that node's recursion only. A
        single statement-wide pre-collect would also suppress an OUTER reference
        to a real table that merely shares a subquery-CTE's name
        (`... FROM t2 JOIN (WITH t2 AS (...) SELECT ...) sub`), dropping the
        real `-> t2` edge.
        """
    def _walk_from_refs(
        `node, caller_nid: str, line: int, cte_names: frozenset[str] = cte_names_default_
    ) -> None {
        `own: set[str] = set[any]();
        c: any;
        for c in `node.children {
            if c.type != "cte" {
                continue;
            }
            cc: any;
            for cc in c.children {
                if cc.type in ("identifier", "object_reference") {
                    `own.add(_norm_ident(_read(cc)));
                    break;
                }
            }
        }
        if `own {
            cte_names = frozenset(cte_names | `own);
        }
        if `node.type in ("from", "join") {
            prev: any = None;
            for c in `node.children {
                after_failed_subquery: any = prev is not None
                    and operator.eq(prev.type, "ERROR")
                    and _read(prev).lstrip().startswith("(")
                    and _read(prev).rstrip().endswith(")");
                prev = c;
                before: any = c.prev_sibling;
                marker: any = _read(before).strip() if before is not None else "";
                if c.type == "relation" and marker in ("#", "##", "@") {
                    continue;
                }
                if c.type == "relation" and not after_failed_subquery {
                    tbl_ref: str | None = None;
                    dblink: str | None = None;
                    for cc in c.children {
                        if cc.type == "object_reference" {
                            tbl_ref = _read(cc);
                        } elif cc.type == "identifier" and _read(cc).startswith("@") {
                            dblink = _read(cc);
                        }
                    }
                    if tbl_ref {
                        tbl: any = f"{tbl_ref}{dblink}" if dblink else tbl_ref;
                        if _is_temp(tbl) {
                            continue;
                        }
                        if _norm_ident(tbl) not in cte_names {
                            tbl_nid: any = table_nids.get(_norm_ident(tbl)) or _ref_stub(tbl);
                            _add_edge(caller_nid, tbl_nid, "reads_from", c.start_point[0] + 1);
                        }
                    }
                }
            }
        }
        for child in `node.children {
            _walk_from_refs(child, caller_nid, line, cte_names);
        }
    }

    src_text: any = source.decode("utf-8", errors="replace");
    def _collect_defined_names(`node) -> None {
        if `node.type in ("create_table", "create_view") {
            name: any = _obj_name(`node);
            if name {
                table_nids[_norm_ident(name)] = _make_id(stem, name);
            }
        }
        for child in `node.children {
            _collect_defined_names(child);
        }
    }

    _collect_defined_names(`root);
    if `root.has_error {
        _masked: any;
        _ident_spans: any;
        (_masked, _ident_spans) = _scan_sql(src_text) as any;
        for m___ in _TABLE_RECOVERY_RX.finditer(_masked) {
            m = m___;
            if `any(
                s <= m.start() and m.start() < e
                for (s, e) in _ident_spans,
            ) {
                continue;
            }
            table_nids.setdefault(_norm_ident(m.group(1)), _make_id(stem, m.group(1)));
        }
    }
    bare_candidates: dict[str, str | None] = {};
    key: any;
    alias_nid: any;
    for (key, alias_nid) in table_nids.items() {
        if "." in key {
            bare: any = key.rsplit(".", 1)[1];
            bare_candidates[bare] = alias_nid
                if bare_candidates.get(bare, alias_nid) == alias_nid
                else None;
        }
    }
    for (bare, alias_nid) in bare_candidates.items() {
        if alias_nid is not None and bare not in table_nids {
            table_nids[bare] = alias_nid;
        }
    }

    for stmt in `root.children {
        if stmt.type == "statement" {
            for child in stmt.children {
                walk(child);
            }
        } elif stmt.type == "transaction" {
            walk(stmt);
        } elif stmt.type == "block" {
            walk(stmt);
        } elif stmt.type
            in ("fb_proc_or_trigger", "set_term", "declare_external_function", "ERROR")
        {
            walk(stmt);
        }
    }
    emitted: any = {(e["source"], e["target"]) for e in edges if e["relation"] == "references"};
    for m____ in re.finditer("CREATE\\s+TABLE\\s+([\\w$]+)\\s*\\(", src_text, re.IGNORECASE) {
        m = m____;
        tbl_name: any = m.group(1);
        tbl_nid: any = table_nids.get(_norm_ident(tbl_name));
        if tbl_nid is None {
            continue;
        }
        tbl_line: any = src_text[:m.start()].count("\n") + 1;
        tail: any = src_text[m.start():];
        end = re.search("(?:^|\\n)(?:CREATE|SET\\s+TERM|ALTER)\\s", tail[1:], re.IGNORECASE);
        block: any = tail[:end.start() + 1] if end else tail;
        for rm in re.finditer("\\bREFERENCES\\s+([\\w$]+)", block, re.IGNORECASE) {
            ref_name: any = rm.group(1);
            ref_nid: any = table_nids.get(_norm_ident(ref_name)) or _ref_stub(ref_name);
            if (tbl_nid, ref_nid) not in emitted {
                _add_edge(tbl_nid, ref_nid, "references", tbl_line);
                emitted.add((tbl_nid, ref_nid));
            }
        }
    }
    if `root.has_error {
        masked_src: any;
        ident_spans: any;
        (masked_src, ident_spans) = _scan_sql(src_text) as any;
        def in_identifier(offset: int) -> bool {
            return `any(s <= offset and offset < e for (s, e) in ident_spans);
        }
        routine_matches: any = [
            found
            for found in _ROUTINE_RECOVERY_RX.finditer(masked_src)
            if not in_identifier(found.start())
        ];
        recovered_on_line: dict[int, set[str]] = {};
        for m_____ in routine_matches {
            m = m_____;
            recovered_on_line.setdefault(src_text[:m.start()].count("\n") + 1, set[any]()).add(
                _make_id(stem, m.group(1))
            );
        }
        for m______ in routine_matches {
            m = m______;
            fn_name: any = m.group(1);
            fn_line: any = src_text[:m.start()].count("\n") + 1;
            fn_nid: any = _make_id(stem, fn_name);
            for dup in [
                nid
                for (nid, ln) in structured_routine_lines.items()
                if ln == fn_line and nid not in recovered_on_line[fn_line]
            ] {
                nodes[:] = [n for n in nodes if n["id"] != dup];
                edges[:] = [e for e in edges if e["source"] != dup and e["target"] != dup];
                structured_routine_lines.pop(dup);
                for key in [k for (k, v) in routine_nids.items() if v == dup] {
                    del routine_nids[key];
                }
                seen_ids.discard(dup);
            }
            from_tree: any = fn_nid in seen_ids;
            _add_node(fn_nid, f"{_clean_ident(fn_name)}()", fn_line);
            if from_tree and fn_nid not in error_routines {
                continue;
            }
            end = _BODY_END_RX.search(masked_src, m.end());
            seen_refs: set[tuple[str, str]] = {
                (e["relation"], e["target"])
                for e in edges
                if e["source"] == fn_nid
            };
            relation: any;
            tbl: any;
            pos: any;
            for (relation, tbl, pos) in _routine_body_refs(
                masked_src[m.end():end.start() if end else len(masked_src)]
            ) {
                tbl_nid = table_nids.get(_norm_ident(tbl)) or _ref_stub(_clean_ident(tbl));
                if (relation, tbl_nid) in seen_refs {
                    continue;
                }
                seen_refs.add((relation, tbl_nid));
                _add_edge(fn_nid, tbl_nid, relation, masked_src.count("\n", 0, m.end() + pos) + 1);
            }
        }
        member_refs: dict[str, set[tuple[str, str]]] = {};
        for m_______ in sorted(
            _PACKAGE_RECOVERY_RX.finditer(masked_src), key=lambda (pm) -> any { not pm.group(1) }
        ) {
            m = m_______;
            if in_identifier(m.start()) {
                continue;
            }
            pkg_name: any = m.group(2);
            pkg_nid: any = _make_id(stem, pkg_name);
            _add_node(pkg_nid, _clean_ident(pkg_name), masked_src.count("\n", 0, m.start()) + 1);
            end = _BODY_END_RX.search(masked_src, m.end());
            limit: any = end.start() if end else len(masked_src);
            pkg_line: any = masked_src.count("\n", 0, m.start()) + 1;
            limit_line: any = masked_src.count("\n", 0, limit) + 1;
            for (member, pos, span, is_def) in _package_members(masked_src, m.end(), limit) {
                if m.group(1) and not is_def {
                    continue;
                }
                member_nid: any = _make_id(stem, f"{pkg_name}.{member}");
                plain_nid: any = _make_id(stem, member);
                if plain_nid != member_nid
                    and pkg_line <= structured_routine_lines.get(plain_nid, -1) <= limit_line
                {
                    nodes[:] = [n for n in nodes if n["id"] != plain_nid];
                    edges[:] = [
                        e
                        for e in edges
                        if e["source"] != plain_nid and e["target"] != plain_nid
                    ];
                    structured_routine_lines.pop(plain_nid, None);
                    seen_ids.discard(plain_nid);
                }
                if member_nid not in seen_ids {
                    member_line: any = masked_src.count("\n", 0, pos) + 1;
                    seen_ids.add(member_nid);
                    nodes.append({
                        "id": member_nid,
                        "label": f"{_clean_ident(pkg_name)}.{member}()",
                        "file_type": "code",
                        "source_file": str_path,
                        "source_location": f"L{member_line}",
                    });
                    _add_edge(pkg_nid, member_nid, "contains", member_line);
                }
                if span is None {
                    continue;
                }
                seen_refs = member_refs.setdefault(member_nid, set[any]());
                for (relation, tbl, ref_pos) in _routine_body_refs(
                    masked_src[span[0]:span[1]], plsql=True
                ) {
                    tbl_nid = table_nids.get(_norm_ident(tbl)) or _ref_stub(_clean_ident(tbl));
                    if (relation, tbl_nid) in seen_refs {
                        continue;
                    }
                    seen_refs.add((relation, tbl_nid));
                    _add_edge(
                        member_nid,
                        tbl_nid,
                        relation,
                        masked_src.count("\n", 0, span[0] + ref_pos) + 1,
                    );
                }
            }
        }

        for m________ in _TRIGGER_RECOVERY_RX.finditer(masked_src) {
            m = m________;
            if in_identifier(m.start()) {
                continue;
            }
            trig_name: any = m.group(1);
            trig_nid: any = _make_id(stem, trig_name);
            if trig_nid in seen_ids {
                continue;
            }
            trig_line: any = src_text[:m.start()].count("\n") + 1;
            _add_node(trig_nid, trig_name, trig_line);
            tbl_name = m.group(2);
            tbl_nid = table_nids.get(_norm_ident(tbl_name)) or _ref_stub(tbl_name);
            _add_edge(trig_nid, tbl_nid, "triggers", trig_line);
        }
        for m_________ in _TABLE_RECOVERY_RX.finditer(masked_src) {
            m = m_________;
            if in_identifier(m.start()) {
                continue;
            }
            tbl_name = m.group(1);
            tbl_line = src_text[:m.start()].count("\n") + 1;
            _add_node(_make_id(stem, tbl_name), _clean_ident(tbl_name), tbl_line);
        }
    }

    return {"nodes": nodes, "edges": edges};
}
