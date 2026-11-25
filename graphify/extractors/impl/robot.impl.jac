impl _resolve_robot_import(raw: str, source_path: Path) -> Path | None {
    s: any = raw.strip();
    anchored: any = False;
    parts: any = [];
    last: any = 0;
    for m in _ROBOT_VAR_RE.finditer(s) {
        name: any = m.group(1).replace(" ", "").replace("_", "").lower();
        if name == "/" {
            repl: any = "/";
        } elif name == "curdir" {
            repl = `str(source_path.parent);
            anchored = True;
        } elif name == "execdir" {
            if source_path.is_absolute() {
                return None;
            }
            repl = ".";
            anchored = True;
        } else {
            return None;
        }
        parts.append(s[last:m.start()]);
        parts.append(repl);
        last = m.end();
    }
    parts.append(s[last:]);
    s = "".join(parts);
    if "%{" in s {
        return None;
    }
    p: any = Path(s);
    if not anchored and not p.is_absolute() {
        p = source_path.parent / p;
    }
    return Path(os.path.normpath(p));
}

impl _kw_id(name: str) -> str {
    return _make_id(name.replace(" ", "").replace("_", ""));
}

impl extract_robot(path: Path) -> dict {
    stem: any;
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    seen_edges: set[tuple];
    file_nid: any;
    test_name_counts: dict[str, int];
    try {
        import from robot.api { get_model, get_resource_model }
        import from robot.api.parsing { ModelVisitor }
    } except ImportError {
        return {
            "nodes": [],
            "edges": [],
            "error": "robotframework not installed. Run: pip install robotframework",
        };
    }

    stem = _file_stem(path);
    str_path = `str(path);
    nodes = [];
    edges = [];
    seen_ids = set[any]();
    seen_edges = set[any]();

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
        context: str | None = None,
    ) -> None {
        if not src or not tgt or src == tgt {
            return;
        }
        key: any = (src, tgt, relation);
        if key in seen_edges {
            return;
        }
        seen_edges.add(key);
        `edge: any = {
            "source": src,
            "target": tgt,
            "relation": relation,
            "confidence": confidence,
            "source_file": str_path,
            "source_location": f"L{line}",
            "weight": 1.0,
        };
        if context {
            `edge["context"] = context;
        }
        edges.append(`edge);
    }

    file_nid = _make_id(str_path);
    add_node(file_nid, path.name, 1);

    try {
        if effective_suffix(path).lower() == ".resource" {
            model: any = get_resource_model(str_path);
        } else {
            model = get_model(str_path);
        }
    } except Exception as e {
        return {"nodes": nodes, "edges": edges, "error": `str(e)};
    }

    def kw_targets(name: str) -> list {
        name = name.rsplit(".", 1)[-1].strip();
        targets: any = [_kw_id(name)];
        low: any = name.lower();
        for prefix in _BDD_PREFIXES {
            if low.startswith(prefix) and len(name) > len(prefix) {
                targets.append(_kw_id(name[len(prefix):]));
                break;
            }
        }
        return targets;
    }

    def add_call_edges(src: str, name: str, line: int) -> None {
        for tgt in kw_targets(name) {
            add_edge(src, tgt, "calls", line, context="call");
        }
    }
    test_name_counts = {};
    def count_test_case(self, `node) -> any {
        if `node.name {
            test_name_counts[`node.name] = test_name_counts.get(`node.name, 0) + 1;
        }
    }

    _TestCaseCountVisitor: any = builtins.type(
        "_TestCaseCountVisitor", (ModelVisitor,), {"visit_TestCase": count_test_case}
    );

    def init_scope(self) -> any {
        `self.scope_nid = file_nid;
    }

    def path_import(self, `node) -> any {
        raw: any = (`node.name or "").strip();
        if not raw {
            return;
        }
        target: any = _resolve_robot_import(raw, path);
        if target is not None {
            add_edge(file_nid, _make_id(`str(target)), "imports", `node.lineno);
        }
    }

    def library_import(self, `node) -> any {
        raw: any = (`node.name or "").strip();
        if not raw {
            return;
        }
        if raw.endswith(".py") or "/" in raw or "\\" in raw {
            path_import(`self, `node);
        } elif raw not in _ROBOT_STDLIBS {
            nid: any = _make_id("robot_library", raw);
            add_node(nid, raw, `node.lineno);
            add_edge(file_nid, nid, "imports", `node.lineno);
        }
    }
    def file_call(self, `node) -> any {
        if `node.name {
            add_call_edges(file_nid, `node.name, `node.lineno);
        }
    }

    def file_template(self, `node) -> any {
        if `node.value {
            add_call_edges(file_nid, `node.value, `node.lineno);
        }
    }
    def scope_call(self, `node) -> any {
        if `node.name {
            add_call_edges(`self.scope_nid, `node.name, `node.lineno);
        }
    }

    def scope_template(self, `node) -> any {
        if `node.value {
            add_call_edges(`self.scope_nid, `node.value, `node.lineno);
        }
    }

    def keyword_call(self, `node) -> any {
        if `node.keyword {
            add_call_edges(`self.scope_nid, `node.keyword, `node.lineno);
        }
        `self.generic_visit(`node);
    }

    def define(self, `node, nid) -> any {
        add_node(nid, `node.name, `node.lineno);
        add_edge(file_nid, nid, "contains", `node.lineno);
        items_: any = list((`self.scope_nid, nid));
        if len(items_) != 2 {
            raise ValueError(
                f"too many values to unpack (expected 2, got {len(items_)})"
                    if len(items_) > 2
                    else f"not enough values to unpack (expected 2, got {len(items_)})",
            );
        }
        prev: any = items_[0];
        `self.scope_nid = items_[1];
        `self.generic_visit(`node);
        `self.scope_nid = prev;
    }

    def test_case(self, `node) -> any {
        if not `node.name {
            return;
        }
        if test_name_counts.get(`node.name, 0) >= 2 {
            define(`self, `node, _make_id(stem, `node.name, f"L{`node.lineno}"));
        } else {
            define(`self, `node, _make_id(stem, `node.name));
        }
    }

    def keyword(self, `node) -> any {
        if `node.name {
            define(`self, `node, _kw_id(`node.name));
        }
    }

    _RobotVisitor: any = builtins.type(
        "_RobotVisitor",
        (ModelVisitor,),
        {
            "__init__": init_scope,
            "visit_ResourceImport": path_import,
            "visit_LibraryImport": library_import,
            "visit_VariablesImport": path_import,
            "visit_SuiteSetup": file_call,
            "visit_SuiteTeardown": file_call,
            "visit_TestSetup": file_call,
            "visit_TestTeardown": file_call,
            "visit_TestTemplate": file_template,
            "visit_TestCase": test_case,
            "visit_Keyword": keyword,
            "visit_KeywordCall": keyword_call,
            "visit_Setup": scope_call,
            "visit_Teardown": scope_call,
            "visit_Template": scope_template,
        },
    );

    try {
        _TestCaseCountVisitor().visit(model);
        _RobotVisitor().visit(model);
    } except Exception as e {
        return {"nodes": nodes, "edges": edges, "error": `str(e)};
    }

    return {"nodes": nodes, "edges": edges};
}
