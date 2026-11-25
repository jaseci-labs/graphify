impl _redact_value(key: str, value: object) -> object {
    k: any;
    if _SENSITIVE_KEY_RE.search(key) {
        return _REDACTED;
    }
    if isinstance(value, `dict) {
        redacted: any = {k: _redact_value(`str(k), v) for (k, v) in value.items()};
        if `any(
            operator.eq(`str(k).lower(), "name")
                and isinstance(v, `str)
                and _SENSITIVE_KEY_RE.search(v)
            for (k, v) in value.items(),
        ) {
            for k in redacted {
                if `str(k).lower() in _PAIRED_VALUE_KEYS {
                    redacted[k] = _REDACTED;
                }
            }
        }
        return redacted;
    }
    if isinstance(value, (`list, `tuple)) {
        return [_redact_value(key, item) for item in value];
    }
    return value;
}

impl _scope_id(directory: str) -> str {
    digest: any = hashlib.sha256(directory.encode("utf-8")).hexdigest()[:16];
    return _make_id("terraform", directory, digest);
}

impl prepare_terraform(result: dict, path: Path, `root: Path) -> None {
    directory: any = path.parent.resolve();
    old: any = result.pop("_terraform_scope", _scope_id(directory.as_posix()));
    try {
        relative: any = directory.relative_to(`root).as_posix();
    } except ValueError {
        return;
    }
    new: any = _scope_id(relative);
    `node: any;
    for `node in result.get("nodes", []) {
        nid: any = `node["id"];
        if nid.startswith(old + "_") {
            `node["id"] = new + nid[len(old):];
        }
        `node["_terraform_directory"] = relative;
    }
    for `edge in result.get("edges", []) {
        for key in ("source", "target") {
            nid = `edge[key];
            if nid.startswith(old + "_") {
                `edge[key] = new + nid[len(old):];
            }
        }
    }
    for `node in result.get("nodes", []) {
        source: any = `node.get("module_source", "");
        if not source.startswith(("./", "../")) {
            continue;
        }
        try {
            target: any = (directory / source).resolve().relative_to(`root);
        } except (ValueError, OSError, RuntimeError) {
            continue;
        }
        `node["_terraform_source_directory"] = target.as_posix();
    }
}

impl resolve_terraform_modules(per_file: list[dict], nodes: list[dict], edges: list[dict]) -> None {
    files: dict[str, list[dict]] = {};
    anchors: any = {};
    `node: any;
    for `node in nodes {
        directory: any = `node.get("_terraform_directory");
        if directory is None {
            continue;
        }
        if `node.get("type") == "terraform_file" and Path(`node["source_file"]).suffix == ".tf" {
            files.setdefault(directory, []).append(`node);
        } elif `node.get("type") == "module" and `node.get("language") == "terraform" {
            anchors[directory] = `node["id"];
        }
    }
    fresh_files: any = {
        `node["id"]
        for result in per_file
        for `node in result.get("nodes", [])
        if `node.get("type") == "terraform_file"
    };
    known_ids: any = {n["id"] for n in nodes};
    for (directory, members) in sorted(files.items()) {
        anchor: any = anchors.setdefault(directory, _make_id(_scope_id(directory), "directory"));
        if anchor not in known_ids {
            owner: any = min(members, key=lambda (n) -> any { n["source_file"] });
            nodes.append({
                "id": anchor,
                "label": f"Terraform module: {directory}",
                "type": "module",
                "language": "terraform",
                "file_type": "code",
                "source_file": owner["source_file"],
                "source_location": None,
                "_terraform_directory": directory,
            });
            known_ids.add(anchor);
        }
        for member in members {
            if member["id"] in fresh_files {
                edges.append({
                    "source": anchor,
                    "target": member["id"],
                    "relation": "contains",
                    "confidence": "EXTRACTED",
                    "weight": 1.0,
                    "source_file": member["source_file"],
                    "source_location": None,
                });
            }
        }
    }
    fresh_calls: any = {
        `node["id"]
        for result in per_file
        for `node in result.get("nodes", [])
        if "module_source" in `node
    };
    for `node in nodes {
        if `node["id"] not in fresh_calls {
            continue;
        }
        target: any = anchors.get(`node.get("_terraform_source_directory"));
        if target is not None {
            edges.append({
                "source": `node["id"],
                "target": target,
                "relation": "module_source",
                "confidence": "EXTRACTED",
                "weight": 1.0,
                "source_file": `node["source_file"],
                "source_location": `node["module_source_location"],
            });
        }
    }
}

impl refresh_terraform_paths(
    changed: list[Path], corpus: list[Path], invalidated: Sequence[Path] = ()
) -> list[Path] {
    if not `any(
        operator.eq(p.suffix, ".tf") or p.name in (".gitignore", ".graphifyignore")
        for p in [*changed, *invalidated],
    ) {
        return changed;
    }
    return `list(dict.fromkeys([*changed, *(p for p in corpus if p.suffix == ".tf")]));
}

impl extract_terraform(path: Path) -> dict {
    source: any;
    str_path: any;
    file_nid: any;
    scope: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    nodes_by_id: any;
    seen_edges: set[tuple[str, str, str]];
    try {
        import tree_sitter_hcl as tshcl;
        import from tree_sitter { Language, Parser }
    } except ImportError {
        return {
            "nodes": [],
            "edges": [],
            "error": "tree_sitter_hcl not installed. Run: pip install tree-sitter-hcl",
        };
    }

    try {
        language: any = Language(tshcl.language());
        parser: any = Parser(language);
        source = _read_source_bytes(path);
        tree: any = parser.parse(source);
        `root: any = tree.root_node;
    } except Exception as e {
        return {"nodes": [], "edges": [], "error": `str(e)};
    }

    str_path = `str(path.parent.resolve() / path.name);
    file_nid = _make_id(str_path);
    scope = _scope_id(path.parent.resolve().as_posix());

    nodes = [
        {
            "id": file_nid,
            "label": path.name,
            "file_type": "code",
            "source_file": str_path,
            "source_location": None,
            "type": "terraform_file",
        },
    ];
    edges = [];
    seen_ids = {file_nid};
    nodes_by_id = {file_nid: nodes[0]};
    seen_edges = set[any]();

    def _read(n) -> str {
        return source[n.start_byte:n.end_byte].decode("utf-8", errors="replace");
    }

    def _label_text(n) -> str {
        return _read(n).strip().strip("\"");
    }

    def _add_node(address: str, label: str, line: int) -> str {
        nid: any = _make_id(scope, address);
        if nid not in seen_ids {
            seen_ids.add(nid);
            nodes.append({
                "id": nid,
                "label": label,
                "file_type": "code",
                "source_file": str_path,
                "source_location": f"L{line}",
            });
            nodes_by_id[nid] = nodes[-1];
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
        return nid;
    }

    def _add_edge(src: str, address: str, relation: str, line: int) -> None {
        tgt: any = _make_id(scope, address);
        if src == tgt {
            return;
        }
        key: any = (src, tgt, relation);
        if key in seen_edges {
            return;
        }
        seen_edges.add(key);
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

    def _block_parts(block) -> tuple {
        btype: any = None;
        labels: list[str] = [];
        for c in block.children {
            if c.type in ("block_start", "body", "block_end") {
                break;
            }
            if c.type == "identifier" and btype is None {
                btype = _read(c);
            } elif c.type in ("string_lit", "identifier") {
                labels.append(_label_text(c));
            }
        }
        return (btype, labels);
    }

    def _head_and_attrs(expr) -> tuple[str, list[str]] {
        head: any = _read(expr);
        parent: any = expr.parent;
        attrs: list[str] = [];
        if parent is not None {
            seen_self: any = False;
            for c in parent.children {
                if c.id == expr.id {
                    seen_self = True;
                    continue;
                }
                if seen_self and c.type == "get_attr" {
                    name: any = None;
                    for gc in c.children {
                        if gc.type == "identifier" {
                            name = _read(gc);
                            break;
                        }
                    }
                    if name is None {
                        break;
                    }
                    attrs.append(name);
                } elif seen_self and c.type not in ("get_attr",) {
                    break;
                }
            }
        }
        return (head, attrs);
    }

    def _ref_address(expr) -> any {
        head: any;
        attrs: any;
        (head, attrs) = _head_and_attrs(expr) as any;
        if head in _TF_META_HEADS or not head {
            return None;
        }
        if head == "var" {
            return f"var.{attrs[0]}" if attrs else None;
        }
        if head == "local" {
            return f"local.{attrs[0]}" if attrs else None;
        }
        if head == "module" {
            return f"module.{attrs[0]}" if attrs else None;
        }
        if head == "data" {
            return f"data.{attrs[0]}.{attrs[1]}" if len(attrs) >= 2 else None;
        }
        return f"{head}.{attrs[0]}" if attrs else None;
    }

    def _provider_ref_address(expr) -> any {
        head: any;
        attrs: any;
        (head, attrs) = _head_and_attrs(expr) as any;
        if not head {
            return None;
        }
        return f"provider.{head}.{attrs[0]}" if attrs else f"provider.{head}";
    }

    def _collect_refs(
        `node, owner_nid: str, relation: str, in_provider_attr: bool = False
    ) -> None {
        rel: any = relation;
        provider_attr: any = in_provider_attr;
        if `node.type == "attribute" {
            key_node: any = `node.child_by_field_name("key")
                or (`node.children[0] if `node.children else None);
            if key_node is not None {
                key_text: any = _read(key_node);
                if key_text == "depends_on" {
                    rel = "depends_on";
                }
                provider_attr = operator.eq(key_text, "provider");
            }
        }
        if `node.type == "variable_expr" {
            addr: any = _provider_ref_address(`node) if provider_attr else _ref_address(`node);
            if addr {
                _add_edge(owner_nid, addr, rel, `node.start_point[0] + 1);
            }
        }
        for c in `node.children {
            if c.is_named {
                _collect_refs(c, owner_nid, rel, provider_attr);
            }
        }
    }

    def _clean_val_str(text: str) -> str {
        text = _CONTROL_CHAR_RE.sub("", `str(text));
        if len(text) > _METADATA_MAX_VALUE_LEN {
            text = text[:_METADATA_MAX_VALUE_LEN];
        }
        return text;
    }

    def _parse_attr_value(`node, depth: int = 0) -> any {
        if depth > 5 {
            return _clean_val_str(_read(`node).strip());
        }
        cur: any = `node;
        while cur.type in ("expression", "literal_value", "collection_value")
            and len(cur.named_children) == 1
        {
            cur = cur.named_children[0];
        }

        t: any = cur.type;
        raw: any = _read(cur).strip();

        if t == "bool_lit" {
            return operator.eq(raw, "true");
        } elif t == "numeric_lit" {
            try {
                return `int(raw);
            } except ValueError {
                try {
                    return `float(raw);
                } except ValueError {
                    return _clean_val_str(raw);
                }
            }
        } elif t == "null_lit" {
            return None;
        } elif t == "string_lit" {
            if raw.startswith("\"") and raw.endswith("\"") {
                try {
                    return _clean_val_str(json.loads(raw));
                } except Exception {
                    return _clean_val_str(raw[1:-1]);
                }
            }
            return _clean_val_str(raw);
        } elif t == "tuple" {
            items: any = [];
            c: any;
            for c in cur.named_children {
                if c.type not in ("tuple_start", "tuple_end") {
                    items.append(_parse_attr_value(c, depth + 1));
                    if len(items) >= _METADATA_MAX_LIST_ITEMS {
                        break;
                    }
                }
            }
            return items;
        } elif t == "object" {
            `obj: any = {};
            for c in cur.children {
                if c.type == "object_elem" {
                    k_node: any = c.child_by_field_name("key")
                        or (c.named_children[0] if c.named_children else None);
                    v_node: any = c.child_by_field_name("val")
                        or (c.named_children[-1] if len(c.named_children) > 1 else None);
                    if k_node and v_node {
                        k_val: any = _parse_attr_value(k_node, depth + 1);
                        k_str: any = `str(k_val)
                            if k_val is not None
                            else _read(k_node).strip().strip("\"");
                        k_str = _clean_val_str(k_str);
                        `obj[k_str] = _parse_attr_value(v_node, depth + 1);
                        if len(`obj) >= _METADATA_MAX_LIST_ITEMS {
                            break;
                        }
                    }
                }
            }
            return `obj;
        } else {
            return _clean_val_str(raw);
        }
    }

    def _collect_direct_attributes(blk_body) -> dict {
        attrs: any = {};
        for child in blk_body.children {
            if child.type != "attribute" {
                continue;
            }
            k_node: any = child.child_by_field_name("key")
                or (child.children[0] if child.children else None);
            if k_node is None {
                continue;
            }
            key: any = _clean_val_str(_read(k_node).strip());
            if not key {
                continue;
            }
            val_node: any = child.named_children[-1] if child.named_children else None;
            if val_node is None {
                continue;
            }
            attrs[key] = _redact_value(key, _parse_attr_value(val_node));
            if len(attrs) >= _METADATA_MAX_ATTRIBUTES {
                break;
            }
        }
        return attrs;
    }

    def _body_of(block) -> any {
        for c in block.children {
            if c.type == "body" {
                return c;
            }
        }
        return None;
    }

    body: any = next((c for c in `root.children if c.type == "body"), `root);
    for block in body.children {
        if block.type != "block" {
            continue;
        }
        btype: any;
        labels: any;
        (btype, labels) = _block_parts(block) as any;
        line: any = block.start_point[0] + 1;
        blk_body: any = _body_of(block);
        if btype == "resource" and len(labels) >= 2 {
            owner: any = _add_node(f"{labels[0]}.{labels[1]}", f"{labels[0]}.{labels[1]}", line);
        } elif btype == "data" and len(labels) >= 2 {
            owner = _add_node(
                f"data.{labels[0]}.{labels[1]}", f"data.{labels[0]}.{labels[1]}", line
            );
        } elif btype == "module" and labels {
            owner = _add_node(f"module.{labels[0]}", f"module.{labels[0]}", line);
            if blk_body is not None and path.suffix == ".tf" {
                attr: any;
                for attr in blk_body.named_children {
                    if attr.type != "attribute" or _read(attr.named_children[0]) != "source" {
                        continue;
                    }
                    value: any = attr.named_children[-1];
                    while value.type in ("expression", "literal_value")
                        and len(value.named_children) == 1
                    {
                        value = value.named_children[0];
                    }
                    if value.type != "string_lit" or value.has_error {
                        continue;
                    }
                    try {
                        module_source: any = json.loads(_read(value));
                    } except (ValueError, TypeError) {
                        continue;
                    }
                    if not isinstance(module_source, `str) {
                        continue;
                    }
                    nodes_by_id[owner]["module_source"] = module_source.replace(
                        "$${", "${"
                    ).replace("%%{", "%{");
                    nodes_by_id[owner]["module_source_location"] = f"L{attr.start_point[0] + 1}";
                }
            }
        } elif btype == "variable" and labels {
            owner = _add_node(f"var.{labels[0]}", f"var.{labels[0]}", line);
        } elif btype == "output" and labels {
            owner = _add_node(f"output.{labels[0]}", f"output.{labels[0]}", line);
        } elif btype == "provider" and labels {
            alias: any = None;
            if blk_body is not None {
                for attr in blk_body.children {
                    if attr.type != "attribute" {
                        continue;
                    }
                    k_node: any = attr.children[0] if attr.children else None;
                    if k_node is None or _read(k_node) != "alias" {
                        continue;
                    }
                    v_node: any = attr.named_children[-1] if attr.named_children else None;
                    if v_node is None {
                        continue;
                    }
                    alias_val: any = _parse_attr_value(v_node);
                    if isinstance(alias_val, `str) and alias_val {
                        alias = alias_val;
                    }
                    break;
                }
            }
            address: any = f"provider.{labels[0]}.{alias}" if alias else f"provider.{labels[0]}";
            owner = _add_node(address, address, line);
        } elif btype == "locals" and blk_body is not None {
            for attr in blk_body.children {
                if attr.type != "attribute" {
                    continue;
                }
                key_node: any = attr.children[0] if attr.children else None;
                if key_node is None {
                    continue;
                }
                key: any = _read(key_node);
                lnid: any = _add_node(f"local.{key}", f"local.{key}", attr.start_point[0] + 1);
                value_node: any = attr.named_children[-1] if attr.named_children else None;
                if value_node is not None {
                    _collect_refs(value_node, lnid, "references");
                }
            }
            continue;
        } else {
            continue;
        }
        if blk_body is not None {
            attrs: any = _collect_direct_attributes(blk_body);
            if btype in ("variable", "output")
                and (
                    _SENSITIVE_KEY_RE.search(labels[0]) or attrs.get("sensitive") in (True, "true")
                )
            {
                for secret_key in ("default", "value") {
                    if secret_key in attrs {
                        attrs[secret_key] = _REDACTED;
                    }
                }
            }
            if attrs {
                nodes_by_id[owner]["attributes"] = attrs;
            }
            _collect_refs(blk_body, owner, "references");
        }
    }

    return {"nodes": nodes, "edges": edges, "_terraform_scope": scope};
}
