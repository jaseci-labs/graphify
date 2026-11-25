impl extract_lazarus_form(path: Path) -> dict {
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    seen_edge_pairs: set[tuple[str, str, str]];
    try {
        text: any = _read_source_text(path);
    } except Exception as e {
        return {"nodes": [], "edges": [], "error": `str(e)};
    }

    import re;
    str_path = `str(path);
    stem: any = _file_stem(path);
    nodes = [];
    edges = [];
    seen_ids = set[any]();
    seen_edge_pairs = set[any]();

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

    def add_edge(src: str, tgt: str, relation: str, line: int, context: str | None = None) {
        key: any = (src, tgt, relation);
        if key in seen_edge_pairs {
            return;
        }
        seen_edge_pairs.add(key);
        `edge: dict[str, Any] = {
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

    file_nid: any = _make_id(`str(path));
    add_node(file_nid, path.name, 1);

    obj_re: any = re.compile(
        "^\\s*(?:object|inherited|inline)\\s+\\w+\\s*:\\s*(\\w+)", re.IGNORECASE
    );
    event_re: any = re.compile("^\\s*On\\w+\\s*=\\s*(\\w+)", re.IGNORECASE);
    end_re: any = re.compile("^\\s*end\\s*$", re.IGNORECASE);
    stack: list[str] = [file_nid];

    for (lineno, line) in enumerate(text.splitlines(), 1) {
        m: any = obj_re.match(line);
        if m {
            class_name: any = m.group(1);
            nid: any = _make_id(stem, class_name);
            add_node(nid, class_name, lineno);
            add_edge(stack[-1], nid, "contains", lineno);
            stack.append(nid);
            continue;
        }

        m = event_re.match(line);
        if m and len(stack) > 1 {
            handler: any = m.group(1);
            handler_nid: any = _make_id(stem, handler);
            add_node(handler_nid, f"{handler}()", lineno);
            add_edge(stack[-1], handler_nid, "references", lineno, context="event");
            continue;
        }

        if end_re.match(line) and len(stack) > 1 {
            stack.pop();
        }
    }

    return {"nodes": nodes, "edges": edges, "input_tokens": 0, "output_tokens": 0};
}

impl extract_delphi_form(path: Path) -> dict {
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    seen_edge_pairs: set[tuple[str, str, str]];
    try {
        raw: any = path.read_bytes();
    } except Exception as e {
        return {"nodes": [], "edges": [], "error": `str(e)};
    }
    if raw[:2] == b"\xff\n" {
        return {
            "nodes": [],
            "edges": [],
            "error": f"binary DFM (convert to text in Delphi IDE to index): {path.name}",
        };
    }
    try {
        text: any = raw.decode("utf-8", errors="replace");
    } except Exception as e {
        return {"nodes": [], "edges": [], "error": `str(e)};
    }

    import re;
    str_path = `str(path);
    stem: any = _file_stem(path);
    nodes = [];
    edges = [];
    seen_ids = set[any]();
    seen_edge_pairs = set[any]();

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

    def add_edge(src: str, tgt: str, relation: str, line: int, context: str | None = None) {
        key: any = (src, tgt, relation);
        if key in seen_edge_pairs {
            return;
        }
        seen_edge_pairs.add(key);
        `edge: dict[str, Any] = {
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

    file_nid: any = _make_id(`str(path));
    add_node(file_nid, path.name, 1);

    obj_re: any = re.compile(
        "^\\s*(?:object|inherited|inline)\\s+\\w+\\s*:\\s*(\\w+)", re.IGNORECASE
    );
    event_re: any = re.compile("^\\s*On\\w+\\s*=\\s*(\\w+)", re.IGNORECASE);
    end_re: any = re.compile("^\\s*end\\s*$", re.IGNORECASE);
    stack: list[str] = [file_nid];

    for (lineno, line) in enumerate(text.splitlines(), 1) {
        m: any = obj_re.match(line);
        if m {
            class_name: any = m.group(1);
            nid: any = _make_id(stem, class_name);
            add_node(nid, class_name, lineno);
            add_edge(stack[-1], nid, "contains", lineno);
            stack.append(nid);
            continue;
        }
        m = event_re.match(line);
        if m and len(stack) > 1 {
            handler: any = m.group(1);
            handler_nid: any = _make_id(stem, handler);
            add_node(handler_nid, f"{handler}()", lineno);
            add_edge(stack[-1], handler_nid, "references", lineno, context="event");
            continue;
        }
        if end_re.match(line) and len(stack) > 1 {
            stack.pop();
        }
    }

    return {"nodes": nodes, "edges": edges, "input_tokens": 0, "output_tokens": 0};
}
