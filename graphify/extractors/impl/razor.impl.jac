impl extract_razor(path: Path) -> dict {
    file_nid: any;
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    try {
        src: any = _read_source_text(path);
    } except OSError {
        return {"nodes": [], "edges": [], "error": f"cannot read {path}"};
    }

    file_nid = _make_id(`str(path));
    str_path = `str(path);
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
    seen_ids = set[any]();
    seen_ids.add(file_nid);

    def _add_ref(target_name: str, relation: str, line: int) -> None {
        tgt_nid: any = _make_id(target_name);
        if not tgt_nid {
            return;
        }
        if tgt_nid not in seen_ids {
            seen_ids.add(tgt_nid);
            nodes.append({
                "id": tgt_nid,
                "label": target_name,
                "file_type": "code",
                "source_file": str_path,
                "source_location": f"L{line}",
            });
        }
        edges.append({
            "source": file_nid,
            "target": tgt_nid,
            "relation": relation,
            "confidence": "EXTRACTED",
            "source_file": str_path,
            "source_location": f"L{line}",
            "weight": 1.0,
        });
    }

    for (i, line) in enumerate(src.splitlines(), 1) {
        m: any = re.match("@using\\s+(.+)", line);
        if m {
            raw_using: any = m.group(1).strip().rstrip(";");
            using_kind: any = "namespace";
            alias: any = None;
            target_fqn: any = raw_using;
            if raw_using.startswith("static ") {
                using_kind = "static";
                target_fqn = raw_using[len("static "):].strip();
            } elif "=" in raw_using {
                lhs: any;
                rhs: any;
                (lhs, rhs) = raw_using.split("=", 1) as any;
                using_kind = "alias";
                alias = lhs.strip();
                target_fqn = rhs.strip();
            }
            if target_fqn {
                tgt_nid: any = _make_id(target_fqn);
                if tgt_nid and tgt_nid not in seen_ids {
                    seen_ids.add(tgt_nid);
                    nodes.append({
                        "id": tgt_nid,
                        "label": target_fqn,
                        "file_type": "code",
                        "source_file": str_path,
                        "source_location": f"L{i}",
                    });
                }
                md: any = {
                    "using_kind": using_kind,
                    "target_fqn": target_fqn,
                    "scope_kind": "file",
                    "scope_id": None,
                };
                if alias {
                    md["alias"] = alias;
                }
                edges.append({
                    "source": file_nid,
                    "target": tgt_nid,
                    "relation": "imports",
                    "context": "import",
                    "confidence": "EXTRACTED",
                    "source_file": str_path,
                    "source_location": f"L{i}",
                    "weight": 1.0,
                    "metadata": sanitize_metadata({k: v for (k, v) in md.items() if v is not None}),
                });
            }
            continue;
        }

        m = re.match("@inject\\s+([\\w.<>\\[\\]]+)\\s+(\\w+)", line);
        if m {
            raw_type: any = m.group(1).strip();
            base_type: any = raw_type.split("<", 1)[0].strip();
            qualified: any = "." in base_type;
            if qualified {
                prefix: any;
                _: any;
                ref_token: any;
                (prefix, _, ref_token) = base_type.rpartition(".") as any;
            } else {
                prefix = "";
                ref_token = base_type;
            }
            if ref_token {
                tgt_nid = _make_id(ref_token);
                if tgt_nid and tgt_nid not in seen_ids {
                    seen_ids.add(tgt_nid);
                    nodes.append({
                        "id": tgt_nid,
                        "label": ref_token,
                        "file_type": "code",
                        "source_file": "",
                        "source_location": "",
                        "origin_file": str_path,
                    });
                }
                md = {"ref_token": ref_token};
                if qualified {
                    md["qualified"] = True;
                    if prefix {
                        md["ref_qualifier"] = prefix;
                    }
                }
                edges.append({
                    "source": file_nid,
                    "target": tgt_nid,
                    "relation": "references",
                    "context": "field",
                    "confidence": "EXTRACTED",
                    "source_file": str_path,
                    "source_location": f"L{i}",
                    "weight": 1.0,
                    "metadata": sanitize_metadata(md),
                });
            }
            continue;
        }

        m = re.match("@inherits\\s+([\\w.<>\\[\\]]+)", line);
        if m {
            _add_ref(m.group(1), "inherits", i);
            continue;
        }
        m = re.match("@implements\\s+([\\w.<>\\[\\]]+)", line);
        if m {
            _add_ref(m.group(1), "implements", i);
            continue;
        }

        m = re.match("@model\\s+([\\w.<>\\[\\]]+)", line);
        if m {
            _add_ref(m.group(1), "references", i);
            continue;
        }

        m = re.match("@page\\s+\"([^\"]+)\"", line);
        if m {
            route: any = m.group(1);
            route_nid: any = _make_id("route", route);
            if route_nid and route_nid not in seen_ids {
                seen_ids.add(route_nid);
                nodes.append({
                    "id": route_nid,
                    "label": f"route:{route}",
                    "file_type": "concept",
                    "source_file": str_path,
                    "source_location": f"L{i}",
                });
                edges.append({
                    "source": file_nid,
                    "target": route_nid,
                    "relation": "references",
                    "confidence": "EXTRACTED",
                    "source_file": str_path,
                    "weight": 1.0,
                });
            }
            continue;
        }
    }

    _COMPONENT_RE: any = re.compile("<([A-Z][A-Za-z0-9]+)[\\s/>]");
    _HTML_TAGS: any = frozenset({
        "DOCTYPE",
        "Html",
        "Head",
        "Body",
        "Div",
        "Span",
        "Table",
        "Form",
        "Input",
        "Button",
        "Select",
        "Option",
        "Label",
        "Textarea",
        "Script",
        "Style",
        "Link",
        "Meta",
        "Title",
        "Header",
        "Footer",
        "Nav",
        "Main",
        "Section",
        "Article",
        "Aside",
    });
    for m in _COMPONENT_RE.finditer(src) {
        comp_name: any = m.group(1);
        if comp_name in _HTML_TAGS {
            continue;
        }
        line_num: any = src[:m.start()].count("\n") + 1;
        _add_ref(comp_name, "calls", line_num);
    }
    _CODE_BLOCK_RE: any = re.compile("@(?:code|functions)\\s*\\{", re.MULTILINE);
    for m in _CODE_BLOCK_RE.finditer(src) {
        block_start: any = m.end();
        depth: any = 1;
        pos: any = block_start;
        while pos < len(src) and depth > 0 {
            if src[pos] == "{" {
                depth += 1;
            } elif src[pos] == "}" {
                depth -= 1;
            }
            pos += 1;
        }
        code_block: any = src[block_start:pos - 1] if depth == 0 else "";

        _METHOD_RE: any = re.compile(
            "(?:public|private|protected|internal|static|async|override|virtual|abstract)\\s+[\\w<>\\[\\],\\s]+\\s+(\\w+)\\s*\\(",
        );
        for mm in _METHOD_RE.finditer(code_block) {
            method_name: any = mm.group(1);
            abs_pos: any = block_start + mm.start();
            method_line: any = src[:abs_pos].count("\n") + 1;
            method_nid: any = _make_id(_file_stem(path), method_name);
            if method_nid and method_nid not in seen_ids {
                seen_ids.add(method_nid);
                nodes.append({
                    "id": method_nid,
                    "label": method_name,
                    "file_type": "code",
                    "source_file": str_path,
                    "source_location": f"L{method_line}",
                });
                edges.append({
                    "source": file_nid,
                    "target": method_nid,
                    "relation": "contains",
                    "confidence": "EXTRACTED",
                    "source_file": str_path,
                    "weight": 1.0,
                });
            }
        }
    }

    return {"nodes": nodes, "edges": edges};
}
