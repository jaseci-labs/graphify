impl extract_dm(path: Path) -> dict {
    source: any;
    stem: any;
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    function_bodies: list[tuple[str, Any, "str | None"]];
    file_nid: any;
    label_to_nids: dict[str, list[str]];
    path_to_nids: dict[str, list[str]];
    seen_call_pairs: set[tuple[str, str]];
    raw_calls: list[dict];
    try {
        import tree_sitter_dm as tsdm;
        import from tree_sitter { Language, Parser }
    } except ImportError {
        return {"nodes": [], "edges": [], "error": "tree-sitter-dm not installed"};
    }
    try {
        language: any = Language(tsdm.language());
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

    def add_node(nid: str, label: str, line: int) {
        if nid and nid not in seen_ids {
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
    ) {
        if not src or not tgt or src == tgt {
            return;
        }
        `edge: dict = {
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

    def _type_path_text(`node) -> str {
        return _read_text(`node, source).strip();
    }

    def _ensure_type(path_text: str, line: int) -> str {
        nid: any = _make_id(stem, path_text);
        add_node(nid, path_text, line);
        return nid;
    }

    def _find_child(`node, type_name: str) -> any {
        for c in `node.children {
            if c.type == type_name {
                return c;
            }
        }
        return None;
    }

    def _read_include_path(file_node) -> str {
        if file_node is None {
            return "";
        }
        if file_node.type == "string_literal" {
            parts: any = [];
            for c in file_node.children {
                if c.type == "string_content" {
                    parts.append(_read_text(c, source));
                }
            }
            return "".join(parts);
        }
        return _read_text(file_node, source).strip("'\"");
    }

    def walk(`node, parent_type_path: "str | None" = None, parent_type_nid: "str | None" = None) {
        t: any = `node.type;
        line: any = `node.start_point[0] + 1;

        if t == "preproc_include" {
            file_node: any = `node.child_by_field_name("file");
            raw: any = _read_include_path(file_node);
            if raw {
                norm: any = re.sub("^\\./", "", raw.replace("\\", "/"));
                resolved: any = (path.parent / norm).resolve();
                `edge: dict = {
                    "source": file_nid,
                    "target": _make_id(`str(resolved)) if resolved.exists() else _make_id(norm),
                    "relation": "imports_from" if resolved.exists() else "imports",
                    "context": "import",
                    "confidence": "EXTRACTED",
                    "source_file": str_path,
                    "source_location": f"L{line}",
                    "weight": 1.0,
                };
                if not resolved.exists() {
                    `edge["external"] = True;
                }
                edges.append(`edge);
            }
            return;
        }

        if t == "type_definition" {
            tp_node: any = _find_child(`node, "type_path");
            if tp_node is None {
                return;
            }
            type_path_str: any = _type_path_text(tp_node);
            type_nid: any = _ensure_type(type_path_str, line);
            add_edge(file_nid, type_nid, "contains", line);
            body: any = _find_child(`node, "type_body");
            if body is not None {
                c: any;
                for c in body.children {
                    walk(c, parent_type_path=type_path_str, parent_type_nid=type_nid);
                }
            }
            return;
        }

        if t in ("type_body_intended", "type_body_braced") {
            for c in `node.children {
                walk(c, parent_type_path, parent_type_nid);
            }
            return;
        }

        if t in ("type_proc_definition", "type_proc_override") {
            if parent_type_nid is None or parent_type_path is None {
                return;
            }
            name_node: any = `node.child_by_field_name("name");
            if name_node is None {
                return;
            }
            proc_name: any = _read_text(name_node, source);
            proc_nid: any = _make_id(stem, parent_type_path, proc_name);
            add_node(proc_nid, f"{parent_type_path}/{proc_name}()", line);
            add_edge(parent_type_nid, proc_nid, "method", line);
            block: any = _find_child(`node, "block");
            if block is not None {
                function_bodies.append((proc_nid, block, parent_type_path));
            }
            return;
        }

        if t in ("proc_definition", "proc_override") {
            tp_node = _find_child(`node, "type_path");
            owner_path: "str | None" = None;
            owner_nid: "str | None" = None;
            if tp_node is not None {
                owner_path = _type_path_text(tp_node);
                owner_nid = _ensure_type(owner_path, line);
                add_edge(file_nid, owner_nid, "contains", line);
            }
            name_node = `node.child_by_field_name("name");
            if name_node is None {
                return;
            }
            proc_name = _read_text(name_node, source);
            if owner_path and owner_nid {
                proc_nid = _make_id(stem, owner_path, proc_name);
                add_node(proc_nid, f"{owner_path}/{proc_name}()", line);
                add_edge(owner_nid, proc_nid, "method", line);
            } else {
                proc_nid = _make_id(stem, proc_name);
                add_node(proc_nid, f"{proc_name}()", line);
                add_edge(file_nid, proc_nid, "contains", line);
            }
            block = _find_child(`node, "block");
            if block is not None {
                function_bodies.append((proc_nid, block, owner_path));
            }
            return;
        }

        if t in ("operator_override", "type_operator_override") {
            return;
        }

        for child in `node.children {
            walk(child, parent_type_path, parent_type_nid);
        }
    }

    walk(`root);

    label_to_nids = {};
    path_to_nids = {};
    for n in nodes {
        label: any = n["label"].strip("()");
        last: any = label.rsplit("/", 1)[-1] if "/" in label else label;
        if last {
            label_to_nids.setdefault(last.lower(), []).append(n["id"]);
        }
        if label.startswith("/") {
            path_to_nids.setdefault(label.lower(), []).append(n["id"]);
        }
    }

    seen_call_pairs = set[any]();
    raw_calls = [];

    def _emit_call(caller_nid: str, callee: str, line: int, is_member: bool) {
        candidates: any = label_to_nids.get(callee.lower(), []);
        tgt_nid: any = candidates[0] if len(candidates) == 1 else None;
        if tgt_nid and tgt_nid != caller_nid {
            pair: any = (caller_nid, tgt_nid);
            if pair in seen_call_pairs {
                return;
            }
            seen_call_pairs.add(pair);
            edges.append({
                "source": caller_nid,
                "target": tgt_nid,
                "relation": "calls",
                "context": "call",
                "confidence": "EXTRACTED",
                "source_file": str_path,
                "source_location": f"L{line}",
                "weight": 1.0,
            });
        } else {
            raw_calls.append({
                "caller_nid": caller_nid,
                "callee": callee,
                "is_member_call": is_member,
                "source_file": str_path,
                "source_location": f"L{line}",
            });
        }
    }

    def walk_calls(body_node, caller_nid: str) {
        if body_node is None {
            return;
        }
        t: any = body_node.type;
        if t
            in (
                "proc_definition",
                "proc_override",
                "type_proc_definition",
                "type_proc_override",
                "type_definition",
            )
        {
            return;
        }
        if t == "call_expression" {
            name_node: any = body_node.child_by_field_name("name");
            if name_node is not None {
                callee: any = _read_text(name_node, source);
                if callee and callee != ".." {
                    _emit_call(caller_nid, callee, body_node.start_point[0] + 1, is_member=False);
                }
            }
        } elif t == "field_proc_expression" {
            proc_field: any = body_node.child_by_field_name("proc");
            if proc_field is not None {
                callee = _read_text(proc_field, source);
                if callee {
                    _emit_call(caller_nid, callee, body_node.start_point[0] + 1, is_member=True);
                }
            }
        } elif t == "new_expression" {
            tp_node: any = _find_child(body_node, "type_path");
            if tp_node is not None {
                target_text: any = _type_path_text(tp_node);
                candidates: any = path_to_nids.get(target_text.lower(), []);
                tgt_nid: any = candidates[0] if len(candidates) == 1 else None;
                if tgt_nid and tgt_nid != caller_nid {
                    pair: any = (caller_nid, tgt_nid);
                    if pair not in seen_call_pairs {
                        seen_call_pairs.add(pair);
                        edges.append({
                            "source": caller_nid,
                            "target": tgt_nid,
                            "relation": "instantiates",
                            "context": "call",
                            "confidence": "EXTRACTED",
                            "source_file": str_path,
                            "source_location": f"L{body_node.start_point[0] + 1}",
                            "weight": 1.0,
                        });
                    }
                }
            }
        }
        for child in body_node.children {
            walk_calls(child, caller_nid);
        }
    }

    for (proc_nid, block, _owner_path) in function_bodies {
        walk_calls(block, proc_nid);
    }

    return {"nodes": nodes, "edges": edges, "raw_calls": raw_calls};
}

impl _read_dmi_description(data: bytes) -> str {
    import struct;
    import zlib as _zlib;
    if not data.startswith(b"\x89PNG\r\n\x1a\n") {
        return "";
    }
    i: any = 8;
    while i + 8 <= len(data) {
        length: any = struct.unpack(">I", data[i:i + 4])[0];
        chunk_type: any = data[i + 4:i + 8];
        payload: any = data[i + 8:i + 8 + length];
        if chunk_type in (b"tEXt", b"zTXt") {
            try {
                null: any = payload.index(b"\x00");
            } except ValueError {
                return "";
            }
            keyword: any = payload[:null];
            if keyword == b"Description" {
                if chunk_type == b"zTXt" {
                    return _zlib.decompressobj().decompress(
                        payload[null + 2:], max_length=1024 * 1024
                    ).decode("utf-8", errors="replace");
                }
                return payload[null + 1:].decode("utf-8", errors="replace");
            }
        }
        i += 8 + length + 4;
    }
    return "";
}

impl extract_dmi(path: Path) -> dict {
    try {
        data: any = path.read_bytes();
    } except Exception as e {
        return {"nodes": [], "edges": [], "error": `str(e)};
    }

    str_path: any = `str(path);
    stem: any = _file_stem(path);
    file_nid: any = _make_id(`str(path));
    nodes: list[dict] = [
        {
            "id": file_nid,
            "label": path.name,
            "file_type": "code",
            "source_file": str_path,
            "source_location": "L1",
        },
    ];
    edges: list[dict] = [];
    seen: set[str] = {file_nid};

    description: any = _read_dmi_description(data);
    if not description {
        return {"nodes": nodes, "edges": edges};
    }

    line_no: any = 0;
    for raw_line in description.splitlines() {
        line_no += 1;
        stripped: any = raw_line.strip();
        if not stripped.startswith("state =") {
            continue;
        }
        value: any = stripped.split("=", 1)[1].strip();
        if value.startswith("\"") and value.endswith("\"") and len(value) >= 2 {
            state_name: any = value[1:-1];
        } else {
            state_name = value;
        }
        if not state_name {
            continue;
        }
        nid: any = _make_id(stem, "state", state_name);
        if nid in seen {
            continue;
        }
        seen.add(nid);
        nodes.append({
            "id": nid,
            "label": f"\"{state_name}\"",
            "file_type": "code",
            "source_file": str_path,
            "source_location": f"L{line_no}",
        });
        edges.append({
            "source": file_nid,
            "target": nid,
            "relation": "contains",
            "confidence": "EXTRACTED",
            "source_file": str_path,
            "source_location": f"L{line_no}",
            "weight": 1.0,
        });
    }

    return {"nodes": nodes, "edges": edges};
}

impl _split_dmm_tile(body: str) -> list[str] {
    out: list[str] = [];
    buf: list[str] = [];
    depth: any = 0;
    in_string: any = False;
    escape: any = False;
    for ch in body {
        if escape {
            buf.append(ch);
            escape = False;
            continue;
        }
        if in_string {
            buf.append(ch);
            if ch == "\\" {
                escape = True;
            } elif ch == "\"" {
                in_string = False;
            }
            continue;
        }
        if ch == "\"" {
            in_string = True;
            buf.append(ch);
        } elif ch in "({[" {
            depth += 1;
            buf.append(ch);
        } elif ch in ")}]" {
            depth -= 1;
            buf.append(ch);
        } elif ch == "," and depth == 0 {
            out.append("".join(buf).strip());
            buf = [];
        } else {
            buf.append(ch);
        }
    }
    tail: any = "".join(buf).strip();
    if tail {
        out.append(tail);
    }
    return out;
}

impl _dmm_type_path(`entry: str) -> str {
    brace: any = `entry.find("{");
    if brace != -1 {
        `entry = `entry[:brace];
    }
    return `entry.strip();
}

impl extract_dmm(path: Path) -> dict {
    try {
        if path.stat().st_size > 50 * 1024 * 1024 {
            return {"nodes": [], "edges": [], "error": "file too large (>50 MB)"};
        }
        text: any = _read_source_text(path);
    } except Exception as e {
        return {"nodes": [], "edges": [], "error": `str(e)};
    }

    str_path: any = `str(path);
    file_nid: any = _make_id(`str(path));
    nodes: list[dict] = [
        {
            "id": file_nid,
            "label": path.name,
            "file_type": "code",
            "source_file": str_path,
            "source_location": "L1",
        },
    ];
    edges: list[dict] = [];

    grid_match: any = _DMM_GRID_RE.search(text);
    dict_text: any = text[:grid_match.start()] if grid_match else text;

    seen_targets: set[str] = set[any]();
    buf: list[str] = [];
    open_line: any = 0;
    depth: any = 0;
    in_string: any = False;
    escape: any = False;
    for (line_idx, line) in enumerate(dict_text.splitlines(), 1) {
        for ch in line {
            if escape {
                escape = False;
            } elif in_string {
                if ch == "\\" {
                    escape = True;
                } elif ch == "\"" {
                    in_string = False;
                }
            } elif ch == "\"" {
                in_string = True;
            } elif ch == "(" {
                if depth == 0 {
                    open_line = line_idx;
                }
                depth += 1;
            } elif ch == ")" {
                depth -= 1;
            }
            buf.append(ch);
        }
        buf.append("\n");
        if depth == 0 and buf {
            chunk: any = "".join(buf);
            buf = [];
            lp: any = chunk.find("(");
            rp: any = chunk.rfind(")");
            if lp == -1 or rp == -1 or rp <= lp {
                continue;
            }
            inner: any = chunk[lp + 1:rp];
            for `entry in _split_dmm_tile(inner) {
                tpath: any = _dmm_type_path(`entry);
                if not tpath.startswith("/") {
                    continue;
                }
                tgt: any = _make_id(tpath);
                if tgt in seen_targets {
                    continue;
                }
                seen_targets.add(tgt);
                edges.append({
                    "source": file_nid,
                    "target": tgt,
                    "relation": "uses",
                    "context": "map",
                    "confidence": "EXTRACTED",
                    "source_file": str_path,
                    "source_location": f"L{open_line}",
                    "weight": 1.0,
                });
            }
        }
    }

    return {"nodes": nodes, "edges": edges};
}

impl extract_dmf(path: Path) -> dict {
    try {
        text: any = _read_source_text(path);
    } except Exception as e {
        return {"nodes": [], "edges": [], "error": `str(e)};
    }

    str_path: any = `str(path);
    stem: any = _file_stem(path);
    file_nid: any = _make_id(`str(path));
    nodes: list[dict] = [
        {
            "id": file_nid,
            "label": path.name,
            "file_type": "code",
            "source_file": str_path,
            "source_location": "L1",
        },
    ];
    edges: list[dict] = [];
    seen: set[str] = {file_nid};

    current_window_nid: str | None = None;
    current_window_name: str | None = None;
    current_elem_nid: str | None = None;
    current_elem_name: str | None = None;

    for (line_idx, line) in enumerate(text.splitlines(), 1) {
        m: any = _DMF_WINDOW_RE.match(line);
        if m {
            name: any = m.group(1);
            nid: any = _make_id(stem, "window", name);
            if nid not in seen {
                seen.add(nid);
                nodes.append({
                    "id": nid,
                    "label": f"window \"{name}\"",
                    "file_type": "code",
                    "source_file": str_path,
                    "source_location": f"L{line_idx}",
                });
                edges.append({
                    "source": file_nid,
                    "target": nid,
                    "relation": "contains",
                    "confidence": "EXTRACTED",
                    "source_file": str_path,
                    "source_location": f"L{line_idx}",
                    "weight": 1.0,
                });
            }
            current_window_nid = nid;
            current_window_name = name;
            current_elem_nid = None;
            current_elem_name = None;
            continue;
        }
        m = _DMF_ELEM_RE.match(line);
        if m and current_window_nid is not None and current_window_name is not None {
            name = m.group(1);
            nid = _make_id(stem, "elem", current_window_name, name);
            if nid not in seen {
                seen.add(nid);
                nodes.append({
                    "id": nid,
                    "label": f"elem \"{name}\"",
                    "file_type": "code",
                    "source_file": str_path,
                    "source_location": f"L{line_idx}",
                });
                edges.append({
                    "source": current_window_nid,
                    "target": nid,
                    "relation": "contains",
                    "confidence": "EXTRACTED",
                    "source_file": str_path,
                    "source_location": f"L{line_idx}",
                    "weight": 1.0,
                });
            }
            current_elem_nid = nid;
            current_elem_name = name;
            continue;
        }
        m = _DMF_TYPE_RE.match(line);
        if m and current_elem_nid is not None and current_elem_name is not None {
            ctype: any = m.group(1);
            for n in nodes {
                if n["id"] == current_elem_nid and " [" not in n["label"] {
                    n["label"] = f"elem \"{current_elem_name}\" [{ctype}]";
                    break;
                }
            }
        }
    }

    return {"nodes": nodes, "edges": edges};
}
