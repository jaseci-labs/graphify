impl _raise_recursion_limit {
    if sys.getrecursionlimit() < _RECURSION_LIMIT {
        sys.setrecursionlimit(_RECURSION_LIMIT);
    }
}

impl _redact_rationale_labels(result: dict) -> dict {
    for `node in result.get("nodes") or () {
        label: any = `node.get("label");
        if `node.get("file_type") == "rationale" and isinstance(label, `str) {
            `node["label"] = redact_secrets(label);
        }
    }
    return result;
}

impl _safe_extract(extractor: Callable, path: Path, *, scan_root: Path | None = None) -> dict {
    try {
        if extractor is extract_python {
            return _redact_rationale_labels(extractor(path, root=scan_root));
        }
        return _redact_rationale_labels(extractor(path));
    } except RecursionError {
        print(f"  warning: skipped {path} (recursion limit exceeded)", file=sys.stderr, flush=True);
        return {"nodes": [], "edges": [], "error": "recursion_limit_exceeded"};
    } except Exception as e {
        if os.environ.get("GRAPHIFY_DEBUG") {
            import traceback;
            traceback.print_exc(file=sys.stderr);
        }
        print(f"  warning: skipped {path} ({`type(e).__name__}: {e})", file=sys.stderr, flush=True);
        return {"nodes": [], "edges": [], "error": f"{`type(e).__name__}: {e}"};
    }
}

impl _file_node_id(rel_path: Path) -> str {
    return _make_id(_file_stem(rel_path));
}

impl _python_absolute_import_alias_files(paths, `root) -> tuple[dict[str, set[str]], set[str]] {
    package_dirs: dict[Path, bool];
    try {
        `root = Path(`root).resolve();
    } except OSError {
        `root = Path(`root);
    }

    package_dirs = {};

    def _is_package(path: Path) -> bool {
        if path not in package_dirs {
            package_dirs[path] = (path / "__init__.py").is_file();
        }
        return package_dirs[path];
    }

    aliases: dict[str, set[str]] = {};
    scan_root_aliases: set[str] = set[any]();
    for raw_path in paths {
        p: any = Path(raw_path);
        if p.suffix.lower() != ".py" {
            continue;
        }
        try {
            p = p.resolve();
            rel: any = p.relative_to(`root);
        } except (ValueError, OSError, RuntimeError) {
            continue;
        }

        module_path: any = p.parent if p.name == "__init__.py" else p.with_suffix("");
        candidate_roots: any = [`root];
        for ancestor in p.parents {
            if ancestor == `root {
                break;
            }
            try {
                ancestor.relative_to(`root);
            } except ValueError {
                break;
            }
            if not _is_package(ancestor) {
                candidate_roots.append(ancestor);
            }
        }

        for candidate_root in candidate_roots {
            try {
                module_rel: any = module_path.relative_to(candidate_root);
            } except ValueError {
                continue;
            }
            if not module_rel.parts or not all(part.isidentifier() for part in module_rel.parts) {
                continue;
            }
            module_name: any = ".".join(module_rel.parts);
            candidate: any = candidate_root.joinpath(*module_rel.parts);
            try {
                hit: any = _probe_python_module_candidate(candidate);
                if hit is None or hit.resolve() != p {
                    continue;
                }
            } except (OSError, RuntimeError) {
                continue;
            }
            module_id: any = _make_id(module_name);
            aliases.setdefault(module_id, set[any]()).add(`str(p));
            if candidate_root == `root {
                scan_root_aliases.add(module_id);
            }
        }
    }
    return (aliases, scan_root_aliases);
}

impl _suppress_ambiguous_python_imports(
    edges: list[dict],
    nodes: list[dict],
    raw_calls: list[dict],
    ambiguous_modules: set[str],
    module_alias_files: dict[str, set[str]],
    `root: Path,
) {
    local: any;
    module_prefix: any;
    node_ids: any = {n.get("id") for n in nodes if isinstance(n, `dict)};
    ambiguous_bindings_by_file: dict[str, set[str]] = {};
    ambiguous_all_call_files: set[str] = set[any]();
    def _is_resolved_loose_sibling(`edge: dict, module_id: str) -> bool {
        target_path: any;
        target_file: any = `edge.get("target_file");
        source_file: any = `edge.get("source_file");
        if not target_file or not source_file {
            return False;
        }
        candidates: any = module_alias_files.get(module_id, set[any]());
        if not candidates {
            return False;
        }
        try {
            source_path: any = Path(source_file);
            if not source_path.is_absolute() {
                source_path = `root / source_path;
            }
            source_path = source_path.resolve();
            target_path = Path(target_file).resolve();
            if target_path.parent != source_path.parent {
                return False;
            }
            if (source_path.parent / "__init__.py").is_file()
                or (source_path.parent / "__init__.pyi").is_file()
            {
                return False;
            }
            return `any(
                operator.eq(Path(candidate).resolve(), target_path) for candidate in candidates
            );
        } except (OSError, RuntimeError) {
            return False;
        }
    }
    def _root_relative_source_file(source_file: str) -> str {
        if not source_file {
            return "";
        }
        path: any = Path(source_file);
        if not path.is_absolute() {
            return path.as_posix();
        }
        try {
            return path.relative_to(`root).as_posix();
        } except ValueError {}
        try {
            return path.resolve().relative_to(`root).as_posix();
        } except (OSError, RuntimeError, ValueError) {}
        try {
            return os.path.relpath(`str(path), `str(`root)).replace("\\", "/");
        } except ValueError {
            return path.name;
        }
    }

    kept_edges: list[dict] = [];
    for `edge in edges {
        if not isinstance(`edge, `dict) {
            kept_edges.append(`edge);
            continue;
        }
        module_name: any = `edge.pop("_python_import_module", None);
        bindings: any = `edge.pop("_python_import_bindings", []);
        is_module_binding: any = `edge.pop("_python_import_module_binding", False);
        if is_module_binding is True {
            `edge["_python_plain_import"] = True;
        }
        marker_only: any = `edge.pop("_python_import_marker_only", False);
        if not module_name {
            if not marker_only {
                kept_edges.append(`edge);
            }
            continue;
        }
        if not marker_only and `edge.get("relation") not in ("imports", "imports_from") {
            kept_edges.append(`edge);
            continue;
        }
        module_id: any = _make_id(module_name);
        module_is_ambiguous: any = module_id in ambiguous_modules;
        if module_is_ambiguous
            and is_module_binding
            and "." not in module_name
            and _is_resolved_loose_sibling(`edge, module_id)
        {
            module_is_ambiguous = False;
        }
        if is_module_binding {
            if module_is_ambiguous {
                ambiguous_bindings_by_file.setdefault(
                    `str(`edge.get("source_file", "")), set[any]()
                ).update(local for (_, local) in bindings);
            }
        } else {
            for (imported, local) in bindings {
                if imported == "*" {
                    module_prefix = _make_id(module_name) + "_";
                    if module_is_ambiguous
                        or `any(name.startswith(module_prefix) for name in ambiguous_modules)
                    {
                        ambiguous_all_call_files.add(`str(`edge.get("source_file", "")));
                    }
                    continue;
                }
                if module_is_ambiguous
                    or _make_id(f"{module_name}.{imported}") in ambiguous_modules
                {
                    ambiguous_bindings_by_file.setdefault(
                        `str(`edge.get("source_file", "")), set[any]()
                    ).add(local);
                }
            }
        }
        if marker_only {
            continue;
        }
        if not module_is_ambiguous {
            kept_edges.append(`edge);
            continue;
        }
        identity: any = "\x00".join((
            `str(module_name),
            _root_relative_source_file(`str(`edge.get("source_file", ""))),
            `str(`edge.get("source_location", "")),
        ));
        target: any = _make_id(
            f"ambiguous_python_import_{hashlib.sha1(identity.encode()).hexdigest()[:12]}"
        );
        while target in node_ids {
            target += "_";
        }
        `edge["target"] = target;
        `edge.pop("target_file", None);
        kept_edges.append(`edge);
    }

    edges[:] = kept_edges;

    for raw_call in raw_calls {
        source_file: any = `str(raw_call.get("source_file", ""));
        if source_file in ambiguous_all_call_files {
            raw_call["_ambiguous_python_import"] = True;
            continue;
        }
        bindings = ambiguous_bindings_by_file.get(source_file);
        if not bindings {
            continue;
        }
        callee: any = `str(raw_call.get("callee", ""));
        receiver: any = `str(raw_call.get("receiver", ""));
        receiver_root: any = receiver.split(".", 1)[0];
        if callee in bindings or receiver_root in bindings {
            raw_call["_ambiguous_python_import"] = True;
        }
    }
}

impl _namespace_src_module_parts(parts: tuple[str, ...]) -> tuple[str, ...] | None {
    dirs: any = parts[:-1];
    if "src" not in dirs {
        return None;
    }
    after: any = parts[len(dirs) - dirs[::-1].index("src"):];
    if len(after) < 2 or after[0] in _PYTHON_STDLIB_MODULE_NAMES {
        return None;
    }
    return after;
}

impl _repoint_python_package_imports(paths, all_nodes, all_edges, `root) {
    try {
        `root = Path(`root).resolve();
    } except OSError {
        `root = Path(`root);
    }
    node_ids: any = {n.get("id") for n in all_nodes if isinstance(n, `dict)};
    alias_to_files: dict[str, set[str]] = {};
    for p in paths {
        if effective_suffix(p).lower() not in (".py", ".pyi") {
            continue;
        }
        try {
            rel: any = Path(p).resolve().relative_to(`root);
        } except (ValueError, OSError) {
            continue;
        }
        parts: any = rel.parts;
        if len(parts) < 2 {
            continue;
        }
        d: any = Path(p).resolve().parent;
        levels: any = 0;
        while levels < len(parts) - 1 and _is_python_package_dir(d) {
            levels += 1;
            d = d.parent;
        }
        if levels == 0 {
            mod_parts: any = _namespace_src_module_parts(parts);
            if mod_parts is None {
                continue;
            }
        } else {
            mod_parts = parts[-(levels + 1):];
        }
        if len(mod_parts) == len(parts) {
            continue;
        }
        file_node: any = _file_node_id(rel);
        alias: any = _make_id(`str(Path(*mod_parts).with_suffix("")));
        alias_to_files.setdefault(alias, set[any]()).add(file_node);
        if p.stem == "__init__" and effective_suffix(p) in (".py", ".pyi") and len(mod_parts) > 1 {
            pkg_alias: any = _make_id(`str(Path(*mod_parts[:-1])));
            alias_to_files.setdefault(pkg_alias, set[any]()).add(file_node);
        }
    }
    alias_map: any = {
        a: next(iter(fs))
        for (a, fs) in alias_to_files.items()
        if len(fs) == 1 and a not in node_ids
    };
    if not alias_map {
        return;
    }
    for e in all_edges {
        if isinstance(e, `dict)
            and e.get("relation") in ("imports", "imports_from")
            and effective_suffix(`str(e.get("source_file", ""))).lower() in (".py", ".pyi")
        {
            tgt: any = e.get("target");
            if tgt in alias_map {
                e["target"] = alias_map[tgt];
            }
        }
    }
}

impl _repoint_python_sibling_imports(paths, all_nodes, all_edges, `root) {
    try {
        `root = Path(`root).resolve();
    } except OSError {
        `root = Path(`root);
    }

    node_ids: any = {n.get("id") for n in all_nodes if isinstance(n, `dict)};
    dir_siblings: dict[Path, dict[str, set[str]]] = {};
    for p in paths {
        if effective_suffix(p).lower() not in (".py", ".pyi") {
            continue;
        }
        try {
            p_res: any = Path(p).resolve();
            rel: any = p_res.relative_to(`root);
        } except (ValueError, OSError) {
            continue;
        }

        file_node: any = _file_node_id(rel);
        if file_node not in node_ids {
            continue;
        }

        if p_res.stem == "__init__" and effective_suffix(p_res) in (".py", ".pyi") {
            pkg_dir: any = p_res.parent;
            parent_dir: any = pkg_dir.parent;
            if pkg_dir.name in _PYTHON_STDLIB_MODULE_NAMES {
                continue;
            }
            if not _is_python_package_dir(parent_dir, (".py", ".pyi")) {
                mod_key: any = _make_id(pkg_dir.name);
                dir_siblings.setdefault(parent_dir, {}).setdefault(mod_key, set[any]()).add(
                    file_node
                );
            }
            continue;
        }

        d: any = p_res.parent;
        if _is_python_package_dir(d, (".py", ".pyi")) {
            continue;
        }
        if p_res.stem in _PYTHON_STDLIB_MODULE_NAMES {
            continue;
        }

        mod_key = _make_id(p_res.stem);
        dir_siblings.setdefault(d, {}).setdefault(mod_key, set[any]()).add(file_node);
    }
    dir_alias_map: dict[Path, dict[str, str]] = {
        d: {mod: next(iter(fns)) for (mod, fns) in mod_map.items() if len(fns) == 1}
        for (d, mod_map) in dir_siblings.items()
    };

    if not dir_alias_map {
        return;
    }

    for e in all_edges {
        if not (
            isinstance(e, `dict)
            and e.get("relation") in ("imports", "imports_from")
            and effective_suffix(`str(e.get("source_file", ""))).lower() in (".py", ".pyi")
        ) {
            continue;
        }

        sf: any = e.get("source_file");
        if not sf {
            continue;
        }
        try {
            sf_path: any = Path(sf);
            if not sf_path.is_absolute() {
                sf_path = (`root / sf_path).resolve();
            } else {
                sf_path = sf_path.resolve();
            }
        } except OSError {
            continue;
        }

        imp_dir: any = sf_path.parent;
        aliases: any = dir_alias_map.get(imp_dir);
        if not aliases {
            continue;
        }

        tgt: any = e.get("target");
        if tgt in aliases {
            repointed: any = aliases[tgt];
            if repointed != e.get("source") {
                e["target"] = repointed;
            }
        }
    }
}

impl _repoint_python_sys_path_imports(per_file, all_nodes, all_edges, `root) {
    n: any;
    r: any;
    if not per_file or not `any(r and r.get("_python_sys_path_entries") for r in per_file) {
        return;
    }

    node_ids: any = {n.get("id") for n in all_nodes if isinstance(n, `dict)};
    file_node_by_path: dict[Path, str] = {};
    for n in all_nodes {
        if not isinstance(n, `dict) {
            continue;
        }
        sf: any = n.get("source_file") or "";
        if not sf or effective_suffix(sf).lower() not in (".py", ".pyi") {
            continue;
        }
        nid: any = n.get("id");
        if not isinstance(nid, `str) {
            continue;
        }
        lbl: any = `str(n.get("label", ""));
        rel_name: any = Path(sf).name;
        if lbl != rel_name {
            continue;
        }
        try {
            p: any = Path(sf);
            if not p.is_absolute() {
                p = (`root / p).resolve();
            } else {
                p = p.resolve();
            }
            file_node_by_path[p] = nid;
        } except (ValueError, OSError) {
            continue;
        }
    }

    try {
        root_path: any = Path(`root).resolve();
    } except OSError {
        root_path = Path(`root);
    }

    for r in per_file {
        if not r or not r.get("_python_sys_path_entries") {
            continue;
        }
        sf = "";
        for n in r.get("nodes", []) {
            if n.get("source_file") {
                sf = `str(n["source_file"]);
                break;
            }
        }
        if not sf {
            continue;
        }
        try {
            sf_p: any = Path(sf);
            if not sf_p.is_absolute() {
                sf_p = (root_path / sf_p).resolve();
            } else {
                sf_p = sf_p.resolve();
            }
        } except OSError {
            continue;
        }

        file_dir: any = sf_p.parent;
        target_dirs: list[Path] = [];
        for `entry in r["_python_sys_path_entries"] {
            curr: any = file_dir;
            while True {
                try {
                    cand_dir: any = (curr / `entry).resolve();
                    if cand_dir.is_dir() and cand_dir not in target_dirs {
                        target_dirs.append(cand_dir);
                    }
                } except OSError {}
                if curr == root_path or curr == curr.parent {
                    break;
                }
                curr = curr.parent;
            }
            try {
                cand_dir = (root_path / `entry).resolve();
                if cand_dir.is_dir() and cand_dir not in target_dirs {
                    target_dirs.append(cand_dir);
                }
            } except OSError {}
        }

        if not target_dirs {
            continue;
        }

        for e in all_edges {
            if not (
                isinstance(e, `dict)
                and e.get("relation") in ("imports", "imports_from")
                and `str(e.get("source_file", "")) == sf
            ) {
                continue;
            }
            tgt: any = e.get("target");
            if tgt in node_ids {
                continue;
            }
            if not isinstance(tgt, `str) {
                continue;
            }
            if tgt in _PYTHON_STDLIB_MODULE_NAMES {
                continue;
            }

            hits: any = set[any]();
            for td in target_dirs {
                py_cand: any = td / f"{tgt}.py";
                pyi_cand: any = td / f"{tgt}.pyi";
                pkg_cand: any = td / tgt / "__init__.py";
                hit_nid: any = file_node_by_path.get(py_cand)
                    or file_node_by_path.get(pyi_cand)
                    or file_node_by_path.get(pkg_cand);
                if hit_nid is not None and hit_nid != e.get("source") {
                    hits.add(hit_nid);
                }
            }
            if len(hits) == 1 {
                e["target"] = next(iter(hits));
            }
        }
    }
}

impl _python_import_bindings(`node, source: bytes) -> list[tuple[str, str]] {
    bindings: list[tuple[str, str]] = [];
    past_import: any = False;
    for child in typing.cast(object, `node).children {
        if child.type == "import" {
            past_import = True;
            continue;
        }
        if not past_import {
            continue;
        }
        if child.type == "dotted_name" {
            imported: any = _read_text(child, source);
            bindings.append((imported, imported.split(".")[-1]));
        } elif child.type == "aliased_import" {
            name_node: any = child.child_by_field_name("name");
            alias_node: any = child.child_by_field_name("alias");
            if name_node is None {
                continue;
            }
            imported = _read_text(name_node, source);
            local: any = _read_text(alias_node, source)
                if alias_node is not None
                else imported.split(".")[-1];
            bindings.append((imported, local));
        } elif child.type == "wildcard_import" {
            bindings.append(("*", "*"));
        }
    }
    return bindings;
}

impl _missing_relative_module_name(attempted: Path, `root: Path, raw: str) -> str {
    try {
        rel: any = attempted.relative_to(`root);
    } except ValueError {
        return f"ref:{raw}";
    }
    parts: any = `list(rel.with_suffix("").parts);
    if parts and parts[-1] == "__init__" {
        parts.pop();
    }
    return ".".join(parts) if parts else f"ref:{raw}";
}

impl _python_under_type_checking(`node, source: bytes) -> bool {
    child: any;
    parent: any;
    (child, parent) = (`node, `node.parent);
    while parent is not None {
        if parent.type in ("if_statement", "elif_clause")
            and parent.child_by_field_name("consequence") == child
        {
            cond: any = parent.child_by_field_name("condition");
            if cond is not None and cond.type == "attribute" {
                cond = cond.child_by_field_name("attribute");
            }
            if cond is not None
                and cond.type == "identifier"
                and _read_text(cond, source) == "TYPE_CHECKING"
            {
                return True;
            }
        }
        (child, parent) = (parent, parent.parent);
    }
    return False;
}

impl _import_python(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
    scan_root: Path | None = None,
) {
    t: any = `node.type;
    current_path: any = Path(str_path);
    try {
        current_path = current_path.resolve();
    } except OSError {}
    `root: any = Path(scan_root) if scan_root is not None else current_path.parent;
    try {
        `root = `root.resolve();
    } except OSError {}
    type_only: any = _python_under_type_checking(`node, source);
    if t == "import_statement" {
        for child in typing.cast(object, `node).children {
            if child.type in ("dotted_name", "aliased_import") {
                raw: any = _read_text(child, source);
                raw_module: any;
                _: any;
                raw_alias: any;
                (raw_module, _, raw_alias) = raw.partition(" as ") as any;
                module_name: any = raw_module.strip().lstrip(".");
                local_binding: any = raw_alias.strip() if raw_alias else module_name.split(".")[0];
                target_path: "Path | None" = _resolve_python_module_path(
                    module_name, current_path, `root, level=0
                );
                if target_path is not None {
                    try {
                        if target_path.resolve() == current_path {
                            target_path = None;
                        }
                    } except OSError {}
                }
                tgt_nid: any = _make_id(`str(target_path))
                    if target_path is not None
                    else _make_id(module_name);
                `edge: any = {
                    "source": file_nid,
                    "target": tgt_nid,
                    "relation": "imports",
                    "context": "import",
                    "confidence": "EXTRACTED",
                    "source_file": str_path,
                    "source_location": f"L{`node.start_point[0] + 1}",
                    "weight": 1.0,
                    "_python_import_module": module_name,
                    "_python_import_bindings": [(module_name, local_binding)],
                    "_python_import_module_binding": True,
                };
                if target_path is not None {
                    `edge["target_file"] = `str(target_path);
                }
                if raw_alias {
                    `edge["local_alias"] = raw_alias.strip();
                }
                if type_only {
                    `edge["type_only"] = True;
                }
                edges.append(`edge);
            }
        }
    } elif t == "import_from_statement" {
        module_node: any = `node.child_by_field_name("module_name");
        if module_node {
            raw = _read_text(module_node, source);
            target_path = None;
            if raw.startswith(".") {
                dots: any = len(raw) - len(raw.lstrip("."));
                module_name = raw.lstrip(".");
                target_path = _resolve_python_module_path(
                    module_name, current_path, `root, level=dots
                );
                missing: any = False;
                if target_path is None {
                    base: any = current_path.parent;
                    for _ in range(dots - 1) {
                        base = base.parent;
                    }
                    rel: any = module_name.replace(".", "/") + ".py"
                        if module_name
                        else "__init__.py";
                    target_path = base / rel;
                    missing = not target_path.is_file();
                }
                if missing {
                    tgt_nid = _make_id(_missing_relative_module_name(target_path, `root, raw));
                } else {
                    tgt_nid = _make_id(`str(target_path));
                }
            } else {
                target_path = _resolve_python_module_path(raw, current_path, `root, level=0);
                if target_path is None
                    and _resolve_python_namespace_dir(raw, current_path, `root, level=0) is not None
                {
                    edges.append({
                        "source": file_nid,
                        "target": "",
                        "relation": "_python_import_marker",
                        "source_file": str_path,
                        "_python_import_module": raw,
                        "_python_import_bindings": _python_import_bindings(`node, source),
                        "_python_import_marker_only": True,
                    });
                    return;
                }
                if target_path is not None {
                    try {
                        if target_path.resolve() == current_path {
                            target_path = None;
                        }
                    } except OSError {}
                }
                tgt_nid = _make_id(`str(target_path)) if target_path is not None else _make_id(raw);
            }
            `edge = {
                "source": file_nid,
                "target": tgt_nid,
                "relation": "imports_from",
                "context": "import",
                "confidence": "EXTRACTED",
                "source_file": str_path,
                "source_location": f"L{`node.start_point[0] + 1}",
                "weight": 1.0,
            };
            if not raw.startswith(".") {
                `edge["_python_import_module"] = raw;
                `edge["_python_import_bindings"] = _python_import_bindings(`node, source);
            }
            if target_path is not None {
                try {
                    if target_path.is_file() {
                        `edge["target_file"] = `str(target_path);
                    }
                } except OSError {}
            }
            if type_only {
                `edge["type_only"] = True;
            }
            edges.append(`edge);
        }
    }
}

impl _import_js(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
) {
    child: any;
    sub: any;
    is_reexport: any = operator.eq(`node.type, "export_statement");
    if is_reexport {
        has_from: any = `any(
            operator.eq(child.type, "from") or operator.eq(_read_text(child, source), "from")
            for child in typing.cast(object, `node).children
            if child.type in ("from", "identifier"),
        );
        if not has_from {
            return;
        }
    }
    is_type_only: any = `any(
        operator.eq(child.type, "type") and not child.is_named for child in typing.cast(object, `node).children
    );
    resolved_path: "Path | None" = None;
    module_string: any = None;
    for child in typing.cast(object, `node).children {
        if child.type == "string" {
            module_string = child;
            break;
        }
        if child.type == "import_require_clause" {
            module_string = next((sub for sub in typing.cast(object, child).children if sub.type == "string"), None);
            break;
        }
    }
    if module_string is not None {
        raw: any = _read_text(module_string, source).strip("'\"` ");
        resolved: any = _resolve_js_import_target(raw, str_path);
        if resolved is not None {
            tgt_nid: any;
            (tgt_nid, resolved_path) = resolved as any;
            try {
                is_file: any = resolved_path is not None and resolved_path.is_file();
            } except OSError {
                is_file = False;
            }
            if resolved_path is not None and not is_file {
                tgt_nid = _make_id("ref", raw);
                resolved_path = None;
            }
            `edge: any = {
                "source": file_nid,
                "target": tgt_nid,
                "relation": "imports_from",
                "context": "re-export" if is_reexport else "import",
                "confidence": "EXTRACTED",
                "source_file": str_path,
                "source_location": f"L{`node.start_point[0] + 1}",
                "weight": 1.0,
            };
            if resolved_path is not None {
                `edge["target_file"] = `str(resolved_path);
            }
            if is_type_only {
                `edge["type_only"] = True;
            }
            edges.append(`edge);
        }
    }
    if resolved_path is not None {
        target_stem: any = _file_stem(resolved_path);
        line: any = `node.start_point[0] + 1;

        if is_reexport {
            for child in typing.cast(object, `node).children {
                if child.type == "export_clause" {
                    spec: any;
                    for spec in typing.cast(object, child).children {
                        if spec.type == "export_specifier" {
                            name_node: any = spec.child_by_field_name("name");
                            if name_node {
                                sym: any = _read_text(name_node, source);
                                if sym == "default" {
                                    continue;
                                }
                                edges.append({
                                    **{"type_only": True} if is_type_only else {},
                                    "source": file_nid,
                                    "target": _make_id(target_stem, sym),
                                    "relation": "re_exports",
                                    "context": "re-export",
                                    "confidence": "EXTRACTED",
                                    "source_file": str_path,
                                    "source_location": f"L{line}",
                                    "weight": 1.0,
                                    "target_file": `str(resolved_path),
                                });
                            }
                        }
                    }
                }
            }
        } else {
            for child in typing.cast(object, `node).children {
                if child.type == "import_clause" {
                    for sub in typing.cast(object, child).children {
                        if sub.type == "named_imports" {
                            for spec in typing.cast(object, sub).children {
                                if spec.type == "import_specifier" {
                                    name_node = spec.child_by_field_name("name");
                                    if name_node {
                                        sym = _read_text(name_node, source);
                                        edges.append({
                                            "source": file_nid,
                                            "target": _make_id(target_stem, sym),
                                            "relation": "imports",
                                            "context": "import",
                                            "confidence": "EXTRACTED",
                                            "source_file": str_path,
                                            "source_location": f"L{line}",
                                            "weight": 1.0,
                                            "target_file": `str(resolved_path),
                                        });
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

impl _import_java(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
) {
    def _walk_scoped(n) -> str {
        parts: list[str] = [];
        cur: any = n;
        while cur {
            if cur.type == "scoped_identifier" {
                name_node: any = cur.child_by_field_name("name");
                if name_node {
                    parts.append(_read_text(name_node, source));
                }
                cur = cur.child_by_field_name("scope");
            } elif cur.type == "identifier" {
                parts.append(_read_text(cur, source));
                break;
            } else {
                break;
            }
        }
        parts.reverse();
        return ".".join(parts);
    }

    for child in typing.cast(object, `node).children {
        if child.type in ("scoped_identifier", "identifier") {
            path_str: any = _walk_scoped(child);
            module_name: any = path_str.split(".")[-1].strip("*").strip(".")
                or (path_str.split(".")[-2] if len(path_str.split(".")) > 1 else path_str);
            if module_name {
                tgt_nid: any = _make_id(module_name);
                edges.append({
                    "source": file_nid,
                    "target": tgt_nid,
                    "relation": "imports",
                    "context": "import",
                    "confidence": "EXTRACTED",
                    "source_file": str_path,
                    "source_location": f"L{`node.start_point[0] + 1}",
                    "weight": 1.0,
                });
            }
            break;
        }
    }
}

impl _import_c(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
) {
    for child in typing.cast(object, `node).children {
        if child.type in ("string_literal", "system_lib_string", "string") {
            raw: any = _read_text(child, source).strip("\"<> ");
            if child.type != "system_lib_string" {
                resolved: any = _resolve_c_include_path(raw, str_path);
                if resolved is not None {
                    tgt_nid: any = _make_id(`str(resolved));
                    parent: any = `node.parent;
                    unconditional: any = True;
                    while parent is not None {
                        if parent.type.startswith("preproc_")
                            and not _cpp_is_header_guard(parent, source)
                        {
                            unconditional = False;
                        }
                        parent = parent.parent;
                    }
                    edges.append({
                        "source": file_nid,
                        "target": tgt_nid,
                        "relation": "imports",
                        "context": "import",
                        "confidence": "EXTRACTED",
                        "source_file": str_path,
                        "source_location": f"L{`node.start_point[0] + 1}",
                        "weight": 1.0,
                        "target_file": `str(resolved),
                        "_cpp_include_proof": unconditional,
                    });
                    break;
                }
            }
            module_name: any = raw.split("/")[-1].split(".")[0];
            if module_name {
                tgt_nid = _make_id(module_name);
                edge_dict: any = {
                    "source": file_nid,
                    "target": tgt_nid,
                    "relation": "imports",
                    "context": "import",
                    "confidence": "EXTRACTED",
                    "source_file": str_path,
                    "source_location": f"L{`node.start_point[0] + 1}",
                    "weight": 1.0,
                };
                edge_dict["metadata"] = sanitize_metadata({
                    "raw_include": raw,
                    "include_kind": "quoted" if child.type != "system_lib_string" else "angle",
                });
                edges.append(edge_dict);
            }
            break;
        }
    }
}

impl _import_csharp(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
) {
    text: any = _read_text(`node, source).strip().rstrip(";");
    if text.startswith("global ") {
        text = text[len("global "):].strip();
    }
    if not text.startswith("using") {
        return;
    }
    body: any = text[len("using"):].strip();
    using_kind: any;
    alias: any;
    target_fqn: any;
    (using_kind, alias, target_fqn) = ("namespace", None, body);
    if body.startswith("static ") {
        (using_kind, target_fqn) = ("static", body[len("static "):].strip());
    } elif "=" in body {
        lhs: any;
        rhs: any;
        (lhs, rhs) = body.split("=", 1) as any;
        (using_kind, alias, target_fqn) = ("alias", lhs.strip(), rhs.strip());
    }
    if not target_fqn {
        return;
    }
    edges.append({
        "source": file_nid,
        "target": _make_id(target_fqn),
        "relation": "imports",
        "context": "import",
        "confidence": "EXTRACTED",
        "source_file": str_path,
        "source_location": f"L{`node.start_point[0] + 1}",
        "weight": 1.0,
        "metadata": sanitize_metadata({
            k: v
            for (k, v) in {
                "using_kind": using_kind,
                "alias": alias,
                "target_fqn": target_fqn,
                "scope_kind": "namespace" if scope_stack else "file",
                "scope_id": scope_stack[-1] if scope_stack else None,
            }.items()
            if v is not None
        }),
    });
}

impl _import_kotlin(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
) {
    path_node: any = `node.child_by_field_name("path");
    if path_node is None {
        path_node = next((c for c in typing.cast(object, `node).children if c.type == "qualified_identifier"), None);
    }
    if path_node is not None {
        raw: any = _read_text(path_node, source).strip();
    } else {
        raw = next(
            (_read_text(c, source).strip() for c in typing.cast(object, `node).children if c.type == "identifier"), ""
        );
    }
    if not raw {
        return;
    }
    if raw.endswith(".*") or raw == "*" or `any(operator.eq(c.type, "*") for c in typing.cast(object, `node).children) {
        return;
    }
    alias: any = None;
    saw_as: any = False;
    for child in typing.cast(object, `node).children {
        if not saw_as {
            saw_as = operator.eq(child.type, "as");
        } elif child.type in ("identifier", "simple_identifier") {
            alias = _read_text(child, source).strip() or None;
            break;
        }
    }
    module_name: any = raw.split(".")[-1].strip();
    if not module_name {
        return;
    }
    edges.append({
        "source": file_nid,
        "target": _make_id(module_name),
        "relation": "imports",
        "context": "import",
        "confidence": "EXTRACTED",
        "source_file": str_path,
        "source_location": f"L{`node.start_point[0] + 1}",
        "weight": 1.0,
        "metadata": sanitize_metadata({
            k: v
            for (k, v) in {"target_fqn": raw, "alias": alias}.items()
            if v is not None
        }),
    });
}

impl _import_scala(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
) {
    for child in typing.cast(object, `node).children {
        if child.type in ("stable_id", "identifier") {
            raw: any = _read_text(child, source);
            module_name: any = raw.split(".")[-1].strip("{} ");
            if module_name and module_name != "_" {
                tgt_nid: any = _make_id(module_name);
                edges.append({
                    "source": file_nid,
                    "target": tgt_nid,
                    "relation": "imports",
                    "context": "import",
                    "confidence": "EXTRACTED",
                    "source_file": str_path,
                    "source_location": f"L{`node.start_point[0] + 1}",
                    "weight": 1.0,
                });
            }
            break;
        }
    }
}

impl _import_php(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
) {
    saw_as: any = False;
    module_name: any = None;
    for child in typing.cast(object, `node).children {
        if child.type == "as" {
            saw_as = True;
            continue;
        }
        if child.type in ("qualified_name", "name", "identifier") {
            bare: any = _read_text(child, source).split("\\")[-1].strip();
            if saw_as {
                module_name = bare;
                break;
            }
            if module_name is None {
                module_name = bare;
            }
        }
    }
    if module_name {
        tgt_nid: any = _make_id(module_name);
        edges.append({
            "source": file_nid,
            "target": tgt_nid,
            "relation": "imports",
            "context": "import",
            "confidence": "EXTRACTED",
            "source_file": str_path,
            "source_location": f"L{`node.start_point[0] + 1}",
            "weight": 1.0,
        });
    }
}

impl _get_c_func_name(`node, source: bytes) -> str | None {
    if `node.type == "identifier" {
        return _read_text(`node, source);
    }
    decl: any = `node.child_by_field_name("declarator");
    if decl {
        return _get_c_func_name(decl, source);
    }
    for child in typing.cast(object, `node).children {
        if child.type == "identifier" {
            return _read_text(child, source);
        }
    }
    return None;
}

impl _ruby_sanitize_method_name(name: str) -> str {
    if not name {
        return name;
    }
    if name.endswith("!") {
        return f"{name[:-1]}_bang";
    }
    if name.endswith("?") {
        return f"{name[:-1]}_pred";
    }
    if name.endswith("=") {
        return f"{name[:-1]}_eq";
    }
    return name;
}

impl _import_lua(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
) {
    text: any = _read_text(`node, source);
    import re;
    m: any = re.search("require\\s*[\\('\"]\\s*['\"]?([^'\")\\s]+)", text);
    if m {
        raw_module: any = m.group(1);
        if raw_module {
            tgt_nid: any = _resolve_lua_import_target(raw_module, str_path);
            if tgt_nid {
                edges.append({
                    "source": file_nid,
                    "target": tgt_nid,
                    "relation": "imports",
                    "context": "import",
                    "confidence": "EXTRACTED",
                    "confidence_score": 1.0,
                    "source_file": str_path,
                    "source_location": `str(`node.start_point[0] + 1),
                    "weight": 1.0,
                });
            }
        }
    }
}

impl _import_swift(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
) -> list[tuple[str, str]] {
    modules: list[tuple[str, str]] = [];
    for child in typing.cast(object, `node).children {
        if child.type == "identifier" {
            raw: any = _read_text(child, source);
            tgt_nid: any = _make_id(raw);
            edges.append({
                "source": file_nid,
                "target": tgt_nid,
                "relation": "imports",
                "context": "import",
                "confidence": "EXTRACTED",
                "source_file": str_path,
                "source_location": f"L{`node.start_point[0] + 1}",
                "weight": 1.0,
            });
            modules.append((tgt_nid, raw));
            break;
        }
    }
    return modules;
}

impl _shorten_rationale_label(text: str, width: int = 80) -> str {
    text = redact_secrets(text);
    label: any = textwrap.shorten(text, width=width, placeholder="…");
    if label in ("", "…") {
        flat: any = " ".join(text.split());
        label = flat if len(flat) <= width else flat[:width - 1] + "…";
    }
    return label;
}

impl _is_autogenerated_python(source: bytes) -> bool {
    head: any;
    head = source[:2048].decode("utf-8", errors="replace");
    if `any(m in head for m in ("DO NOT EDIT", "@generated", "Generated by the protocol buffer")) {
        return True;
    }
    if re.search("^revision\\s*[:=]", head, re.MULTILINE)
        and "def upgrade(" in head
        and "down_revision" in head
    {
        return True;
    }
    if "class Migration(migrations.Migration)" in head and "operations" in head {
        return True;
    }
    return False;
}

impl _extract_python_rationale(path: Path, result: dict) {
    source: any;
    stem: any;
    str_path: any;
    nodes: any;
    edges: any;
    seen_ids: any;
    file_nid: any;
    stripped: any;
    try {
        import tree_sitter_python as tspython;
        import from tree_sitter { Language, Parser }
        language: any = Language(tspython.language());
        parser: any = Parser(language);
        source = _read_source_bytes(path, warn=False);
        tree: any = parser.parse(source);
        `root: any = tree.root_node;
    } except Exception {
        return;
    }
    sys_path_entries: list[str] = [];
    for stmt in typing.cast(object, `root).children {
        if stmt.type != "expression_statement" {
            continue;
        }
        for child in typing.cast(object, stmt).children {
            if child.type == "call" {
                fn: any = child.child_by_field_name("function");
                if fn and fn.type == "attribute" {
                    attr: any = fn.child_by_field_name("attribute");
                    `obj: any = fn.child_by_field_name("object");
                    if attr and `obj and `obj.type == "attribute" {
                        sub_attr: any = `obj.child_by_field_name("attribute");
                        sub_obj: any = `obj.child_by_field_name("object");
                        if source[sub_obj.start_byte:sub_obj.end_byte] == b"sys"
                            and source[sub_attr.start_byte:sub_attr.end_byte] == b"path"
                            and source[attr.start_byte:attr.end_byte] in (b"insert", b"append")
                        {
                            args: any = child.child_by_field_name("arguments");
                            if args {
                                for a in typing.cast(object, args).children {
                                    if a.type in ("string", "concatenated_string") {
                                        val: any = source[a.start_byte:a.end_byte].decode(
                                            "utf-8", errors="replace"
                                        );
                                        val = val.strip("\"'");
                                        if val {
                                            sys_path_entries.append(val);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    if sys_path_entries {
        result["_python_sys_path_entries"] = sys_path_entries;
    }

    stem = _file_stem(path);
    str_path = `str(path);
    nodes = result["nodes"];
    edges = result["edges"];
    seen_ids = {n["id"] for n in nodes};
    file_nid = _make_id(`str(path));
    def _get_docstring(body_node) -> tuple[str, int] | None {
        if not body_node {
            return None;
        }
        for child in typing.cast(object, body_node).children {
            if child.type == "comment" {
                continue;
            }
            if child.type == "expression_statement" {
                for sub in typing.cast(object, child).children {
                    if sub.type in ("string", "concatenated_string") {
                        text: any = source[sub.start_byte:sub.end_byte].decode(
                            "utf-8", errors="replace"
                        );
                        text = text.strip("\"'").strip("\"\"\"").strip("'''").strip();
                        if len(text) > 20 {
                            return (text, child.start_point[0] + 1);
                        }
                    }
                }
            }
            break;
        }
        return None;
    }

    def _add_rationale(text: str, line: int, parent_nid: str) {
        label: any = _shorten_rationale_label(text);
        rid: any = _make_id(stem, "rationale", `str(line));
        if rid not in seen_ids {
            seen_ids.add(rid);
            nodes.append({
                "id": rid,
                "label": label,
                "file_type": "rationale",
                "source_file": str_path,
                "source_location": f"L{line}",
            });
        }
        edges.append({
            "source": rid,
            "target": parent_nid,
            "relation": "rationale_for",
            "confidence": "EXTRACTED",
            "source_file": str_path,
            "source_location": f"L{line}",
            "weight": 1.0,
        });
    }
    if not _is_autogenerated_python(source) {
        ds: any = _get_docstring(`root);
        if ds {
            _add_rationale(ds[0], ds[1], file_nid);
        }
    }
    def walk_docstrings(`node, parent_nid: str) {
        t: any = `node.type;
        if t == "class_definition" {
            name_node: any = `node.child_by_field_name("name");
            body: any = `node.child_by_field_name("body");
            if name_node and body {
                class_name: any = source[name_node.start_byte:name_node.end_byte].decode(
                    "utf-8", errors="replace"
                );
                nid: any = _make_id(parent_nid, class_name)
                    if parent_nid != file_nid
                    else _make_id(stem, class_name);
                ds: any = _get_docstring(body);
                if ds {
                    _add_rationale(ds[0], ds[1], nid);
                }
                child: any;
                for child in typing.cast(object, body).children {
                    walk_docstrings(child, nid);
                }
            }
            return;
        }
        if t == "function_definition" {
            name_node = `node.child_by_field_name("name");
            body = `node.child_by_field_name("body");
            if name_node and body {
                func_name: any = source[name_node.start_byte:name_node.end_byte].decode(
                    "utf-8", errors="replace"
                );
                nid = _make_id(parent_nid, func_name)
                    if parent_nid != file_nid
                    else _make_id(stem, func_name);
                ds = _get_docstring(body);
                if ds {
                    _add_rationale(ds[0], ds[1], nid);
                }
            }
            return;
        }
        for child in typing.cast(object, `node).children {
            walk_docstrings(child, parent_nid);
        }
    }

    walk_docstrings(`root, file_nid);
    source_text = typing.cast(object, source).decode("utf-8", errors="replace");
    lineno = 0;
    for line_text in source_text.splitlines() {
        lineno += 1;
        stripped = line_text.strip();
        if stripped.startswith(_RATIONALE_PREFIXES) {
            _add_rationale(stripped, lineno, file_nid);
        }
    }
}

impl _ts_import_is_code(`root: Any, start: int) -> bool {
    `node: any = `root.descendant_for_byte_range(start, start + 1);
    if `node is None {
        return True;
    }
    in_template_substitution: any = False;
    while `node is not None {
        if `node.type == "comment" or `node.type in ("string", "regex", "regex_pattern") {
            return False;
        }
        if `node.type == "template_substitution" {
            in_template_substitution = True;
        } elif `node.type == "template_string" and not in_template_substitution {
            return False;
        }
        `node = `node.parent;
    }
    return True;
}

impl _ts_type_argument_ranges(`root: Any, *, call_only: bool) -> list[tuple[int, int]] {
    ranges: list[tuple[int, int]] = [];
    stack: any = [`root];
    while stack {
        `node: any = stack.pop();
        if `node.type == "type_arguments" {
            parent: any = `node.parent;
            if not call_only
                or parent is not None and parent.type in ("call_expression", "new_expression")
            {
                ranges.append((`node.start_byte, `node.end_byte));
            }
        }
        stack.extend(`node.children);
    }
    return ranges;
}

impl _ts_ranges_containing(ranges: _TsRangeIndex, offset: int) -> list[tuple[int, int]] {
    starts: any;
    spans: any;
    prefix_max_end: any;
    (starts, spans, prefix_max_end) = ranges as any;
    hits: list[tuple[int, int]] = [];
    index: any = bisect_right(starts, offset) - 1;
    while index >= 0 and prefix_max_end[index] > offset {
        start: any;
        end: any;
        (start, end) = spans[index] as any;
        if end > offset {
            hits.append((start, end));
        }
        index -= 1;
    }
    hits.reverse();
    return hits;
}

impl _ts_build_range_index(`root: Any, *, call_only: bool) -> _TsRangeIndex {
    spans: any = sorted(_ts_type_argument_ranges(`root, call_only=call_only));
    starts: any = [start for (start, _) in spans];
    prefix_max_end: list[int] = [];
    running: any = -1;
    for (_, end) in spans {
        running = max(running, end);
        prefix_max_end.append(running);
    }
    return (starts, spans, prefix_max_end);
}

impl _ts_error_nodes(`root: Any) -> list[Any] {
    errors: list[Any] = [];
    stack: any = [`root];
    while stack {
        `node: any = stack.pop();
        if `node.type == "ERROR" or `node.is_error {
            errors.append(`node);
        }
        stack.extend(`node.children);
    }
    return errors;
}

impl _ts_mask_candidate_is_malformed(
    original_root: Any, masked_range: tuple[int, int], errors: list[Any]
) -> bool {
    start: any;
    end: any;
    (start, end) = masked_range as any;
    opener: any = original_root.descendant_for_byte_range(start, start + 1);
    if opener is None or opener.type != "<" {
        return True;
    }
    if opener.parent is None or opener.parent.type != "binary_expression" {
        return True;
    }
    for error in errors {
        if error.start_byte <= end + 2 and error.end_byte >= end - 1 {
            return True;
        }
    }
    return False;
}

impl _normalize_ts_export_type_star(source: bytes) -> bytes | None {
    matches: any = `list(_TS_EXPORT_TYPE_STAR_RE.finditer(source));
    if not matches {
        return None;
    }
    masked: any = bytearray(source);
    for `match in matches {
        start: any;
        end: any;
        (start, end) = `match.span(1) as any;
        masked[start:end] = b" " * (end - start);
    }
    return `bytes(masked);
}

impl _normalize_ts_import_types(source: bytes, *, tsx: bool = False) -> bytes | None {
    original_root: any;
    `match: any;
    errors: any;
    raw_matches: any = `list(_TS_IMPORT_CALL_RE.finditer(source));
    if not raw_matches {
        return None;
    }
    try {
        import tree_sitter_typescript as ts_typescript;
        import from tree_sitter { Language, Parser }

        language_factory: any = ts_typescript.language_tsx
            if tsx
            else ts_typescript.language_typescript;
        parser: any = Parser(Language(language_factory()));
        original_root = parser.parse(source).root_node;
    } except Exception {
        return None;
    }

    matches: any = [
        `match
        for `match in raw_matches
        if _ts_import_is_code(original_root, `match.start())
    ];
    if not matches {
        return None;
    }
    original_type_ranges: any = _ts_build_range_index(original_root, call_only=False);
    matches = [
        `match
        for `match in matches
        if not _ts_ranges_containing(original_type_ranges, `match.start())
    ];
    if not matches {
        return None;
    }

    def placeholder(`match: "re.Match[bytes]") -> bytes {
        matched: any = `match.group(0);
        return b"T" + re.sub(b"[^\\r\\n]", b" ", matched[1:]);
    }

    masked: any = bytearray(source);
    for `match in matches {
        masked[`match.start():`match.end()] = placeholder(`match);
    }

    `root: any = parser.parse(`bytes(masked)).root_node;
    type_argument_ranges: any = _ts_build_range_index(`root, call_only=True);
    errors = _ts_error_nodes(original_root);
    if not type_argument_ranges[1] {
        return None;
    }

    norm: any = bytearray(source);
    changed: any = False;
    for `match in matches {
        containing_ranges: any = _ts_ranges_containing(type_argument_ranges, `match.start());
        if containing_ranges
            and `any(
                _ts_mask_candidate_is_malformed(original_root, candidate, errors)
                for candidate in containing_ranges,
            )
        {
            norm[`match.start():`match.end()] = placeholder(`match);
            changed = True;
        }
    }
    return `bytes(norm) if changed else None;
}

impl extract_python(path: Path, *, `root: Path | None = None) -> dict {
    result: any;
    result = _extract_generic(path, _PYTHON_CONFIG, scan_root=`root);
    if "error" not in result {
        _extract_python_rationale(path, result);
    }
    return result;
}

impl _normalize_ts_tag_and_import_annotations(source: bytes, *, tsx: bool = False) -> bytes | None {
    end: any;
    backtick: any;
    result: any;
    tags: any = `list(_TS_TYPED_TAG_RE.finditer(source));
    imports: any = `list(_TS_QUALIFIED_IMPORT_TYPE_RE.finditer(source));
    if not tags and not imports {
        return None;
    }
    try {
        import tree_sitter_typescript as ts_typescript;
        import from tree_sitter { Language, Parser }
        factory: any = ts_typescript.language_tsx if tsx else ts_typescript.language_typescript;
        parser: any = Parser(Language(factory()));
        original: any = parser.parse(source).root_node;
    } except Exception {
        return None;
    }
    if not original.has_error {
        return None;
    }
    missing: any = [];
    stack: any = [original];
    while stack {
        `node: any = stack.pop();
        if `node.is_missing {
            missing.append(`node.start_byte);
        }
        stack.extend(`node.children);
    }

    candidates: any = [];
    `match: any;
    for `match in tags {
        start: any;
        (start, end) = `match.span("types") as any;
        backtick = source.find(b"`", end);
        if backtick >= 0
            and `any(operator.le(end, pos) and operator.le(pos, backtick) for pos in missing)
            and _ts_import_is_code(original, `match.start("tag"))
        {
            candidates.append((start, end, `match.start("tag"), "tag"));
        }
    }
    for `match in imports {
        if _ts_import_is_code(original, `match.start()) {
            candidates.append((
                `match.start(),
                `match.start("name"),
                `match.start("name"),
                "annotation",
            ));
        }
    }
    if not candidates {
        return None;
    }

    masked: any = bytearray(source);
    _: any;
    for item_ in candidates {
        (start, end, _, _) = item_;
        masked[start:end] = re.sub(b"[^\\r\\n]", b" ", source[start:end]);
    }
    recovered: any = parser.parse(`bytes(masked)).root_node;
    accepted: any = [];
    anchor: any;
    kind: any;
    for item__ in candidates {
        (start, end, anchor, kind) = item__;
        `node = recovered.descendant_for_byte_range(anchor, anchor + 1);
        while `node is not None {
            if kind == "annotation" and `node.type == "type_annotation" {
                accepted.append((start, end));
                break;
            }
            if kind == "tag" and `node.type == "call_expression" {
                arguments: any = `node.child_by_field_name("arguments");
                if arguments is not None and arguments.type == "template_string" {
                    accepted.append((start, end));
                }
                break;
            }
            `node = `node.parent;
        }
    }
    if not accepted {
        return None;
    }
    result = bytearray(source);
    for item___ in accepted {
        (start, end) = item___;
        result[start:end] = masked[start:end];
    }
    return `bytes(result);
}

impl extract_js(path: Path) -> dict {
    normalized: any;
    result: any;
    suffix: any = effective_suffix(path).lower();
    is_ts: any = suffix in (".ts", ".tsx", ".mts", ".cts");
    if suffix == ".tsx" {
        config: any = _TSX_CONFIG;
    } elif suffix in (".ts", ".mts", ".cts") {
        config = _TS_CONFIG;
    } else {
        config = _JS_CONFIG;
    }
    source_override: any = None;
    type_only_import_offsets: set[int] = set[any]();
    if is_ts {
        try {
            source: any = _read_source_bytes(path);
            working: any = _normalize_ts_export_type_star(source) or source;
            normalized = _normalize_ts_import_types(working, tsx=operator.eq(suffix, ".tsx"));
            if normalized is not None {
                type_only_import_offsets.update(
                    `match.start()
                    for `match in _TS_IMPORT_CALL_RE.finditer(working)
                    if normalized[`match.start():`match.start() + 6] != b"import",
                );
            }
            working = normalized if normalized is not None else working;
            before_annotations: any = working;
            normalized = _normalize_ts_tag_and_import_annotations(
                before_annotations, tsx=operator.eq(suffix, ".tsx")
            );
            if normalized is not None {
                type_only_import_offsets.update(
                    `match.start()
                    for `match in _TS_QUALIFIED_IMPORT_TYPE_RE.finditer(before_annotations)
                    if normalized[`match.start():`match.start() + 6] != b"import",
                );
            }
            working = normalized if normalized is not None else working;
            source_override = working if working is not source else None;
        } except OSError {}
    }
    result = _extract_generic(path, config, source_override=source_override);
    if "error" not in result {
        _extract_js_rationale(path, result);
        _rescue_js_dynamic_imports(path, result, type_only_import_offsets=type_only_import_offsets);
    }
    return result;
}

impl _rescue_js_dynamic_imports(
    path: Path, result: dict, *, type_only_import_offsets: set[int] | None = None
) {
    `root: any;
    try {
        import re as _re;
        src: any = _read_source_text(path, warn=False);
        if not _re.search("(?<!\\w)import\\s*\\(", src) {
            return;
        }
        type_only_positions: set[int] = set[any]();
        if effective_suffix(path).lower() in (".ts", ".tsx", ".mts", ".cts") {
            import from tree_sitter { Language, Parser }
            import tree_sitter_typescript as ts_typescript;

            raw_source: any = _read_source_bytes(path, warn=False);
            factory: any = ts_typescript.language_tsx
                if effective_suffix(path).lower() == ".tsx"
                else ts_typescript.language_typescript;
            `root = Parser(Language(factory())).parse(raw_source).root_node;
            type_only_import_offsets = `set(type_only_import_offsets or ());
            type_only_import_offsets.update(
                `match.start()
                for `match in _TS_IMPORT_CALL_RE.finditer(raw_source)
                if _js_import_is_type_only(
                    `root.descendant_for_byte_range(`match.start(), `match.start() + 1)
                ),
            );
        }
        if type_only_import_offsets {
            raw_source = _read_source_bytes(path, warn=False);
            value_: any = 0;
            cursor: any = value_;
            position: any = value_;
            for offset in sorted(type_only_import_offsets) {
                if offset < cursor or raw_source[offset:offset + 6] != b"import" {
                    continue;
                }
                segment: any = raw_source[cursor:offset].decode("utf-8");
                position += len(segment.replace("\r\n", "\n").replace("\r", "\n"));
                type_only_positions.add(position);
                cursor = offset;
            }
        }
        existing_ids: any = {n["id"] for n in result.get("nodes", [])};
        file_node_id: any = _make_id(`str(path));
        aliases: any = _load_tsconfig_aliases(path.parent);
        base_url: any = _load_tsconfig_base_url(path.parent);
        deferred_ids: set[str] = set[any]();
        deferred_files: set[str] = set[any]();
        rescued_targets: set[str] = set[any]();
        for e in result.get("edges", []) {
            if e.get("deferred")
                and e.get("relation") == "imports_from"
                and e.get("source") == file_node_id
            {
                deferred_ids.add(e.get("target"));
                tf: any = e.get("target_file");
                if tf {
                    try {
                        deferred_files.add(`str(Path(tf).resolve()));
                    } except OSError {
                        deferred_files.add(`str(tf));
                    }
                }
            }
        }
        for m in _re.finditer(
            "(?<!\\w)import\\s*\\(\\s*(?:'([^'\\n]+)'|\"([^\"\\n]+)\"|`([^`$\\n]+)`)\\s*\\)", src
        ) {
            if m.start() in type_only_positions {
                continue;
            }
            raw: any = m.group(1) or m.group(2) or m.group(3);
            if not raw {
                continue;
            }
            line_start: any = src.rfind("\n", 0, m.start()) + 1;
            if "//" in src[line_start:m.start()] {
                continue;
            }
            resolution: any = _resolve_rescued_specifier(path, raw, aliases, base_url);
            if resolution is None {
                continue;
            }
            node_id: any;
            _stub_sf: any;
            resolved_file: any;
            _is_external: any;
            (node_id, _stub_sf, resolved_file, _is_external) = resolution as any;
            if node_id in deferred_ids or _make_id("ref", raw) in deferred_ids {
                continue;
            }
            if resolved_file is not None {
                try {
                    if `str(resolved_file.resolve()) in deferred_files {
                        continue;
                    }
                } except OSError {}
            }
            emit_key: any = `str(resolved_file.resolve()) if resolved_file is not None else raw;
            if emit_key in rescued_targets {
                continue;
            }
            rescued_targets.add(emit_key);
            _emit_rescued_import(
                result, existing_ids, file_node_id, path, raw, "dynamic_import", aliases, base_url
            );
        }
    } except Exception {}
}

impl _extract_js_rationale(path: Path, result: dict) {
    stem: any;
    str_path: any;
    nodes: any;
    edges: any;
    seen_ids: any;
    file_nid: any;
    seen_doc_refs: set[str];
    stripped: any;
    try {
        source_text: any = _read_source_text(path, warn=False);
    } except Exception {
        return;
    }

    stem = _file_stem(path);
    str_path = `str(path);
    nodes = result["nodes"];
    edges = result["edges"];
    seen_ids = {n["id"] for n in nodes};
    file_nid = _make_id(`str(path));
    seen_doc_refs = set[any]();

    def _add_rationale(text: str, line: int) {
        label: any = _shorten_rationale_label(text);
        rid: any = _make_id(stem, "rationale", `str(line));
        if rid not in seen_ids {
            seen_ids.add(rid);
            nodes.append({
                "id": rid,
                "label": label,
                "file_type": "rationale",
                "source_file": str_path,
                "source_location": f"L{line}",
            });
        }
        edges.append({
            "source": rid,
            "target": file_nid,
            "relation": "rationale_for",
            "confidence": "EXTRACTED",
            "source_file": str_path,
            "source_location": f"L{line}",
            "weight": 1.0,
        });
    }

    def _add_doc_ref(token: str, line: int) {
        kind: any;
        num: any;
        (kind, num) = re.match("([A-Za-z]+)[- ]?(\\d+)", token).groups() as any;
        kind = kind.upper();
        label: any = f"{kind}-{num.zfill(4)}" if kind == "ADR" else f"{kind}-{num}";
        if label in seen_doc_refs {
            return;
        }
        seen_doc_refs.add(label);
        rid: any = _make_id("docref", label);
        if rid not in seen_ids {
            seen_ids.add(rid);
            nodes.append({
                "id": rid,
                "label": label,
                "file_type": "doc_ref",
                "source_file": str_path,
                "source_location": f"L{line}",
            });
        }
        edges.append({
            "source": file_nid,
            "target": rid,
            "relation": "cites",
            "confidence": "EXTRACTED",
            "source_file": str_path,
            "source_location": f"L{line}",
            "weight": 1.0,
        });
    }

    lineno = 0;
    for line_text in typing.cast(object, source_text).splitlines() {
        lineno += 1;
        stripped = line_text.strip();
        if stripped.startswith(_JS_RATIONALE_PREFIXES) {
            _add_rationale(stripped.lstrip("/* "), lineno);
        }
        if _JS_COMMENT_LINE_RE.match(line_text) {
            for m in _JS_DOC_REF_RE.finditer(stripped) {
                _add_doc_ref(m.group(1), lineno);
            }
        }
    }
}

impl _resolve_rescued_specifier(
    path: Path, raw: str, aliases, base_url
) -> "tuple[str, str, Path | None, bool] | None" {
    if raw.startswith(".") {
        resolved: any = _resolve_js_module_path(Path(os.path.normpath(path.parent / raw)));
        resolved_file: any = resolved if resolved is not None and resolved.is_file() else None;
        return (_make_id(`str(resolved)), `str(resolved), resolved_file, False);
    }
    resolved_alias: any = _resolve_tsconfig_alias(raw, aliases, base_url=base_url);
    if resolved_alias is not None {
        resolved_alias = _resolve_js_module_path(resolved_alias);
        resolved_file = resolved_alias
            if resolved_alias is not None and resolved_alias.is_file()
            else None;
        return (_make_id(`str(resolved_alias)), `str(resolved_alias), resolved_file, False);
    }
    if raw.startswith("@/") {
        resolved_unmapped: any = _resolve_js_module_path(raw, path.parent);
        if resolved_unmapped is not None and resolved_unmapped.is_file() {
            return (
                _make_id(`str(resolved_unmapped)),
                `str(resolved_unmapped),
                resolved_unmapped,
                False,
            );
        }
    }
    parts: any = raw.split("/");
    module_name: any = "/".join(parts[:2]) if raw.startswith("@") and len(parts) >= 2 else parts[0];
    if not module_name {
        return None;
    }
    return (_make_id(module_name), module_name, None, True);
}

impl _emit_rescued_import(
    result: dict,
    existing_ids: set,
    file_node_id: str,
    path: Path,
    raw: str,
    relation: str,
    aliases,
    base_url,
) {
    resolution: any = _resolve_rescued_specifier(path, raw, aliases, base_url);
    if resolution is None {
        return;
    }
    node_id: any;
    stub_source_file: any;
    resolved_file: any;
    is_external: any;
    (node_id, stub_source_file, resolved_file, is_external) = resolution as any;
    `edge: any = {
        "source": file_node_id,
        "target": node_id,
        "relation": relation,
        "confidence": "EXTRACTED",
        "source_file": `str(path),
    };
    if resolved_file is not None {
        `edge["target_file"] = `str(resolved_file);
        result.setdefault("edges", []).append(`edge);
        return;
    }
    if node_id in existing_ids {
        result.setdefault("edges", []).append(`edge);
        return;
    }
    stub: dict = {
        "id": node_id,
        "label": raw,
        "file_type": "code",
        "source_file": stub_source_file,
        "confidence": "EXTRACTED",
    };
    if is_external {
        stub["type"] = "module";
        stub["label"] = stub_source_file;
    }
    result.setdefault("nodes", []).append(stub);
    result.setdefault("edges", []).append(`edge);
    existing_ids.add(node_id);
}

impl extract_svelte(path: Path) -> dict {
    result: any;
    try {
        src: any = _read_source_text(path);
    } except OSError as e {
        return {"nodes": [], "edges": [], "error": `str(e)};
    }

    masked: any;
    lang: any;
    (masked, lang) = _svelte_mask_non_script(src) as any;
    config: any = _JS_CONFIG if lang in ("js", "jsx") else _TS_CONFIG;
    masked_bytes: any = masked.encode("utf-8");
    if config is _TS_CONFIG {
        masked_bytes = _normalize_ts_import_types(masked_bytes) or masked_bytes;
    }

    result = _extract_generic(path, config, source_override=masked_bytes);
    try {
        import re as _re;
        existing_ids: any = {n["id"] for n in result.get("nodes", [])};
        file_node_id: any = _make_id(`str(path));
        aliases: any = _load_tsconfig_aliases(path.parent);
        base_url: any = _load_tsconfig_base_url(path.parent);
        m: any;
        for m in _re.finditer("import\\(\\s*['\"]([^'\"]+)['\"]\\s*\\)", src) {
            raw: any = m.group(1);
            if not raw {
                continue;
            }
            _emit_rescued_import(
                result, existing_ids, file_node_id, path, raw, "dynamic_import", aliases, base_url
            );
        }
        script_re: any = _re.compile("<script\\b[^>]*>([\\s\\S]*?)</script\\s*>", _re.IGNORECASE);
        static_import_re: any = _re.compile(
            "import\\s+(?:[^'\"`;]+?\\s+from\\s+)?['\"]([^'\"]+)['\"]"
        );
        for script_match in script_re.finditer(src) {
            script_body: any = script_match.group(1);
            for m in static_import_re.finditer(script_body) {
                raw = m.group(1);
                if not raw {
                    continue;
                }
                _emit_rescued_import(
                    result, existing_ids, file_node_id, path, raw, "imports_from", aliases, base_url
                );
            }
        }
    } except Exception {}
    return result;
}

impl _astro_mask_non_script(src: str) -> str {
    keep: list[tuple[int, int]] = [];
    fm: any = _ASTRO_FRONTMATTER_RE.match(src);
    if fm {
        keep.append((fm.start(1), fm.end(1)));
    }
    for m in _ASTRO_SCRIPT_RE.finditer(src, fm.end() if fm else 0) {
        if not _ASTRO_NON_JS_TYPE_RE.search(m.group(1)) {
            keep.append((m.start(2), m.end(2)));
        }
    }
    chars: any = [c if c in "\r\n" else " " for c in src];
    for (start, end) in keep {
        chars[start:end] = src[start:end];
        if end < len(chars) and chars[end] == " " {
            chars[end:end + 4] = [" ", ";", "", ""];
        }
    }
    return "".join(chars);
}

impl extract_astro(path: Path) -> dict {
    result: any;
    try {
        src: any = _read_source_text(path);
    } except OSError {
        return {"nodes": [], "edges": []};
    }
    masked: any = _astro_mask_non_script(src).encode("utf-8");
    masked = _normalize_ts_import_types(masked) or masked;
    result = _extract_generic(path, _TS_CONFIG, source_override=masked);
    try {
        import re as _re;
        src = _read_source_text(path, warn=False);
        existing_ids: any = {n["id"] for n in result.get("nodes", [])};
        file_node_id: any = _make_id(`str(path));
        aliases: any = _load_tsconfig_aliases(path.parent);
        base_url: any = _load_tsconfig_base_url(path.parent);
        m: any;
        for m in _re.finditer("import\\(\\s*['\"]([^'\"]+)['\"]\\s*\\)", src) {
            raw: any = m.group(1);
            if not raw {
                continue;
            }
            _emit_rescued_import(
                result, existing_ids, file_node_id, path, raw, "dynamic_import", aliases, base_url
            );
        }
        frontmatter_re: any = _re.compile(
            "\\A\\s*---\\s*\\r?\\n([\\s\\S]*?)\\r?\\n---\\s*(?:\\r?\\n|\\Z)"
        );
        script_re: any = _re.compile("<script\\b[^>]*>([\\s\\S]*?)</script\\s*>", _re.IGNORECASE);
        static_import_re: any = _re.compile(
            "import\\s+(?:[^'\"`;]+?\\s+from\\s+)?['\"]([^'\"]+)['\"]"
        );
        regions: list[str] = [];
        fm: any = frontmatter_re.search(src);
        if fm {
            regions.append(fm.group(1));
        }
        for script_match in script_re.finditer(src) {
            regions.append(script_match.group(1));
        }
        for region in regions {
            for m in static_import_re.finditer(region) {
                raw = m.group(1);
                if not raw {
                    continue;
                }
                _emit_rescued_import(
                    result, existing_ids, file_node_id, path, raw, "imports_from", aliases, base_url
                );
            }
        }
    } except Exception {}
    return result;
}

impl _ejs_mask_non_script(src: str) -> str {
    n: any = len(src);
    keep: any = bytearray(n);
    neutralize: any = bytearray(n);

    for m in _EJS_SCRIPT_TAG_RE.finditer(src) {
        if _NON_JS_SCRIPT_TYPE_RE.search(m.group(1)) {
            continue;
        }
        p: any;
        for p in range(m.start(2), m.end(2)) {
            keep[p] = 1;
        }
    }

    i: any = 0;
    while True {
        j: any = src.find("<%", i);
        if j < 0 {
            break;
        }
        if j + 2 < n and src[j + 2] == "%" {
            for p in range(j, min(j + 3, n)) {
                keep[p] = 0;
            }
            i = j + 3;
            continue;
        }
        marker: any = src[j + 2] if j + 2 < n else "";
        close: any = src.find("%>", j + 2);
        if close < 0 {
            break;
        }
        for p in (j, j + 1, close, close + 1) {
            if p < n {
                keep[p] = 0;
            }
        }
        if marker in ("=", "-") {
            for p in range(j + 2, close) {
                if keep[p] {
                    neutralize[p] = 1;
                }
            }
        } elif marker == "#" {
            for p in range(j, close + 2) {
                keep[p] = 0;
            }
        } else {
            body_start: any = j + 3 if marker == "_" else j + 2;
            if marker == "_" {
                keep[j + 2] = 0;
            }
            for p in range(body_start, close) {
                keep[p] = 1;
            }
        }
        i = close + 2;
    }

    out: list[str] = [];
    in_output: any = False;
    for p in range(n) {
        c: any = src[p];
        if c in "\r\n" {
            out.append(c);
            in_output = False;
        } elif not keep[p] {
            out.append(" ");
            in_output = False;
        } elif neutralize[p] {
            out.append(" " if in_output else "0");
            in_output = True;
        } else {
            out.append(c);
            in_output = False;
        }
    }
    return "".join(out);
}

impl _emit_ejs_include(
    result: dict, existing_ids: set, file_node_id: str, path: Path, raw: str, line: int
) {
    base: any = Path(os.path.normpath(path.parent / raw));
    resolved: any = _resolve_js_import_path(base);
    `edge: any = {
        "source": file_node_id,
        "relation": "includes",
        "confidence": "EXTRACTED",
        "source_file": `str(path),
        "source_location": f"L{line}",
    };
    if resolved.is_file() {
        `edge["target"] = _make_id(`str(resolved));
        `edge["target_file"] = `str(resolved);
        result.setdefault("edges", []).append(`edge);
        return;
    }
    node_id: any = _make_id(raw);
    if node_id not in existing_ids {
        existing_ids.add(node_id);
        result.setdefault("nodes", []).append({
            "id": node_id,
            "label": raw,
            "file_type": "code",
            "source_file": `str(path),
            "source_location": f"L{line}",
            "confidence": "EXTRACTED",
        });
    }
    `edge["target"] = node_id;
    result.setdefault("edges", []).append(`edge);
}

impl extract_ejs(path: Path) -> dict {
    result: any;
    try {
        src: any = _read_source_text(path);
    } except OSError as e {
        return {"nodes": [], "edges": [], "error": `str(e)};
    }

    masked: any = _ejs_mask_non_script(src).encode("utf-8");
    masked = _normalize_ts_import_types(masked) or masked;
    result = _extract_generic(path, _TS_CONFIG, source_override=masked);

    try {
        existing_ids: any = {n["id"] for n in result.get("nodes", [])};
        file_node_id: any = _make_id(`str(path));
        aliases: any = _load_tsconfig_aliases(path.parent);
        base_url: any = _load_tsconfig_base_url(path.parent);
        m: any;
        for m in re.finditer("import\\(\\s*['\"]([^'\"]+)['\"]\\s*\\)", src) {
            if m.group(1) {
                _emit_rescued_import(
                    result,
                    existing_ids,
                    file_node_id,
                    path,
                    m.group(1),
                    "dynamic_import",
                    aliases,
                    base_url,
                );
            }
        }
        for m in _EJS_INCLUDE_RE.finditer(src) {
            if m.group(1) {
                _emit_ejs_include(
                    result,
                    existing_ids,
                    file_node_id,
                    path,
                    m.group(1),
                    src.count("\n", 0, m.start()) + 1,
                );
            }
        }
    } except Exception {}
    return result;
}

impl extract_vue(path: Path) -> dict {
    result: any;
    try {
        src: any = _read_source_text(path);
    } except OSError {
        return {"nodes": [], "edges": []};
    }

    masked: any;
    lang: any;
    (masked, lang) = _vue_mask_non_script(src) as any;
    if lang == "tsx" {
        config: any = _TSX_CONFIG;
    } elif lang in ("js", "jsx") {
        config = _JS_CONFIG;
    } else {
        config = _TS_CONFIG;
    }
    masked_bytes: any = masked.encode("utf-8");
    if config in (_TS_CONFIG, _TSX_CONFIG) {
        masked_bytes = _normalize_ts_import_types(masked_bytes, tsx=config is _TSX_CONFIG)
            or masked_bytes;
    }

    result = _extract_generic(path, config, source_override=masked_bytes);
    try {
        existing_ids: any = {n["id"] for n in result.get("nodes", [])};
        file_node_id: any = _make_id(`str(path));
        aliases: any = _load_tsconfig_aliases(path.parent);
        base_url: any = _load_tsconfig_base_url(path.parent);
        for m in re.finditer("import\\(\\s*['\"]([^'\"]+)['\"]\\s*\\)", src) {
            raw: any = m.group(1);
            if not raw {
                continue;
            }
            _emit_rescued_import(
                result, existing_ids, file_node_id, path, raw, "dynamic_import", aliases, base_url
            );
        }
    } except Exception {}
    return result;
}

impl extract_java(path: Path) -> dict {
    return _extract_generic(path, _JAVA_CONFIG);
}

impl _is_spock_file(path: Path, ts_result: dict) -> bool {
    import re as _re;
    _SPOCK_FEATURE_RE: any = _re.compile("^\\s*def\\s+[\\\"']", _re.MULTILINE);
    try {
        return `bool(_SPOCK_FEATURE_RE.search(_read_source_text(path, warn=False)));
    } except OSError {
        return False;
    }
}

impl _extract_spock_fallback(path: Path, ts_result: dict) -> dict {
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    import re as _re;
    source: any = _read_source_text(path, warn=False);
    str_path = `str(path);
    stem: any = _file_stem(path);
    file_node: any = next(
        (n for n in ts_result.get("nodes", []) if n.get("label") == path.name), None
    );
    nodes = [file_node] if file_node else [];
    edges = [e for e in ts_result.get("edges", []) if e.get("context") == "import"];
    seen_ids = {n["id"] for n in nodes};

    def _add_node(nid: str, label: str, line: int) {
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

    def _add_edge(src: str, tgt: str, relation: str, line: int, confidence: str = "EXTRACTED") {
        edges.append({
            "source": src,
            "target": tgt,
            "relation": relation,
            "confidence": confidence,
            "source_file": str_path,
            "source_location": f"L{line}",
            "weight": 1.0,
        });
    }

    lines_text: any = source.splitlines();
    class_re: any = _re.compile("^\\s*(?:[\\w@]+\\s+)*class\\s+(\\w+)");
    feature_re: any = _re.compile("^\\s*def\\s+(?:\\\"([^\\\"]+)\\\"|'([^']+)')\\s*\\(");
    plain_method_re: any = _re.compile("^\\s*def\\s+(\\w+)\\s*\\(");

    current_class_nid: str | None = None;
    file_nid: any = _make_id(str_path);
    if file_nid not in seen_ids {
        _add_node(file_nid, path.name, 1);
    }

    for (lineno, line_text) in enumerate(lines_text, 1) {
        cm: any = class_re.match(line_text);
        if cm {
            class_name: any = cm.group(1);
            class_nid: any = _make_id(stem, class_name);
            _add_node(class_nid, class_name, lineno);
            _add_edge(file_nid, class_nid, "contains", lineno);
            current_class_nid = class_nid;
            continue;
        }

        if current_class_nid is None {
            continue;
        }

        fm: any = feature_re.match(line_text);
        if fm {
            method_name: any = fm.group(1) or fm.group(2);
            method_label: any = f"\"{method_name}\"";
            method_nid: any = _make_id(current_class_nid, method_name);
            _add_node(method_nid, method_label, lineno);
            _add_edge(current_class_nid, method_nid, "method", lineno);
            continue;
        }

        pm: any = plain_method_re.match(line_text);
        if pm {
            method_name = pm.group(1);
            if method_name not in ("if", "while", "for", "switch", "catch") {
                method_label = f".{method_name}()";
                method_nid = _make_id(current_class_nid, method_name);
                _add_node(method_nid, method_label, lineno);
                _add_edge(current_class_nid, method_nid, "method", lineno);
            }
        }
    }

    return {"nodes": nodes, "edges": edges};
}

impl extract_groovy(path: Path) -> dict {
    result: any;
    result = _extract_generic(path, _GROOVY_CONFIG);
    if _is_spock_file(path, result) {
        result = _extract_spock_fallback(path, result);
    }
    return result;
}

impl extract_c(path: Path) -> dict {
    return _extract_generic(path, _C_CONFIG);
}

impl _augment_cpp_string_tests(path: Path, result: dict) -> dict {
    try {
        source: any = _read_source_text(path, warn=False);
    } except OSError {
        return result;
    }
    matches: any = `list(_CPP_STRING_TEST_RE.finditer(source));
    if not matches {
        return result;
    }

    str_path: any = `str(path);
    stem: any = _file_stem(path);
    file_nid: any = _make_id(str_path);
    stem_collapse_id: any = _make_id(stem);
    nodes: any = result.setdefault("nodes", []);
    edges: any = result.setdefault("edges", []);
    seen_ids: any = {n.get("id") for n in nodes};

    for m in matches {
        test_name: any = m.group(1);
        line: any = source.count("\n", 0, m.start()) + 1;
        test_nid: any = _make_id(stem, test_name);
        if test_nid == stem_collapse_id {
            test_nid = _make_id(stem, "test", f"L{line}");
        }
        if test_nid in seen_ids {
            continue;
        }
        seen_ids.add(test_nid);
        nodes.append({
            "id": test_nid,
            "label": f"\"{test_name}\"",
            "file_type": "code",
            "source_file": str_path,
            "source_location": f"L{line}",
        });
        edges.append({
            "source": file_nid,
            "target": test_nid,
            "relation": "contains",
            "confidence": "EXTRACTED",
            "source_file": str_path,
            "source_location": f"L{line}",
            "weight": 1.0,
        });
    }
    return result;
}

impl _blank_keeping_newlines(m: "re.Match[bytes]") -> bytes {
    return re.sub(b"[^\\r\\n]", b" ", m.group(0));
}

impl _normalize_cpp_cli(source: bytes) -> bytes | None {
    if not _CPP_CLI_MARKER_RE.search(source) {
        return None;
    }
    out: any = _CPP_CLI_CLASS_RE.sub(_blank_keeping_newlines, source);
    out = re.sub(b"\\bgcnew\\b", b"new  ", out);
    out = _CPP_CLI_SUFFIX_UNAMBIGUOUS_RE.sub(b" ", out);
    out = _CPP_CLI_SUFFIX_DECL_RE.sub(b"\\1 ", out);
    return _CPP_CLI_ATTR_RE.sub(_blank_keeping_newlines, out);
}

impl _normalize_cpp_export_macros(source: bytes) -> bytes {
    def repl(m: re.Match[bytes]) -> bytes {
        start: any = m.start();
        idx: any = start - 1;
        while idx >= 0 and source[idx] in b" \t\r\n" {
            idx -= 1;
        }
        if idx >= 0 and source[idx] == 40 {
            return m.group(0);
        }
        if m.group(4) == b"{" {
            end: any = m.end();
            idx_after: any = end;
            while idx_after < len(source) and source[idx_after] in b" \t\r\n" {
                idx_after += 1;
            }
            if idx_after < len(source) {
                next_char: any = source[idx_after:idx_after + 1];
                if next_char in b"0123456789\"'-" {
                    return m.group(0);
                }
            }
        }
        macro_text: any = m.group(2);
        blanked_macro: any = bytearray(macro_text);
        for i in range(len(blanked_macro)) {
            if blanked_macro[i] not in b"\r\n" {
                blanked_macro[i] = 32;
            }
        }

        return m.group(1) + `bytes(blanked_macro) + m.group(3) + m.group(4);
    }

    return _CPP_EXPORT_MACRO_RE.sub(repl, source);
}

impl _cpp_conditional_tokens(source: bytes) -> Generator[any, any, any] {
    pos: any = 0;
    while `match := _CPP_CONDITIONAL_TOKEN_RE.search(source, pos) {
        pos = `match.end();
        if `match.group(1) is not None {
            end: any = source.find(b")" + `match.group(1) + b"\"", pos);
            pos = len(source) if end == -1 else end + len(`match.group(1)) + 2;
        }
        yield (`match, pos);
    }
}

impl _cpp_conditional_groups(source: bytes) -> tuple[list[dict], str | None] {
    groups: list[dict] = [];
    stack: list[dict] = [];
    for (`match, _) in _cpp_conditional_tokens(source) {
        word: any = `match.group(2);
        if source[max(0, `match.start() - 3):`match.start()].endswith((b"\\\n", b"\\\r\n")) {
            continue;
        }
        if word not in (b"if", b"ifdef", b"ifndef", b"elif", b"else", b"endif") {
            continue;
        }
        text: any = `match.group().strip();
        argument: any = re.sub(b"/\\*[\\s\\S]*?\\*/|//[^\\r\\n]*", b"", text);
        argument = re.sub(b"^#[ \\t]*[A-Za-z_]+", b"", argument).strip();
        if word in (b"if", b"elif") and not argument
            or word in (b"ifdef", b"ifndef")
                and not re.fullmatch(b"[A-Za-z_][A-Za-z_0-9]*", argument)
            or word in (b"else", b"endif") and argument
        {
            return (groups, "malformed conditional directive");
        }
        line: any = source.count(b"\n", 0, `match.start()) + 1;
        branch: any = {
            "directive": text.decode("utf-8", errors="replace"),
            "directive_line": line,
            "start_byte": `match.end(),
            "start_line": source.count(b"\n", 0, `match.end()) + 2,
        };
        if word in (b"if", b"ifdef", b"ifndef") {
            if len(groups) >= 128 {
                return (groups, "conditional-group limit exceeded");
            }
            group: any = {
                "line": line,
                "start_byte": `match.start(),
                "branches": [branch],
                "directives": [(`match.start(), `match.end())],
            };
            if stack {
                group["parent"] = groups.index(stack[-1]);
                group["parent_branch"] = len(stack[-1]["branches"]) - 1;
            }
            groups.append(group);
            stack.append(group);
            continue;
        }
        if not stack {
            return (groups, "unbalanced conditional directives");
        }
        group = stack[-1];
        if group.get("has_else") {
            if word != b"endif" {
                return (groups, "conditional branch after else");
            }
        }
        previous: any = group["branches"][-1];
        previous.update(end_byte=`match.start(), end_line=line - 1);
        group["directives"].append((`match.start(), `match.end()));
        if word in (b"elif", b"else") {
            group["branches"].append(branch);
            group["has_else"] = operator.eq(word, b"else");
        } else {
            if not group.get("has_else") {
                group["branches"].append({
                    "directive": "#else (implicit)",
                    "directive_line": line,
                    "start_byte": `match.start(),
                    "end_byte": `match.start(),
                    "start_line": line,
                    "end_line": line - 1,
                    "implicit": True,
                });
            }
            group["end_byte"] = `match.end();
            stack.pop();
        }
    }
    return (groups, "unbalanced conditional directives" if stack else None);
}

impl _cpp_expression_conditional_groups(source: bytes, groups: list[dict]) -> set[int] {
    code: any = bytearray(source);
    for (`match, end) in _cpp_conditional_tokens(source) {
        code[`match.start():end] = re.sub(b"[^\\r\\n]", b" ", source[`match.start():end]);
    }
    tokens: any = iter(re.finditer(b"[A-Za-z_][A-Za-z_0-9]*|[^\\s]", code));
    token: any = next(tokens, None);
    stack: list[tuple[bytes, bool]] = [];
    previous: any = b"";
    statement: any = 0;
    selected: any = set[any]();
    for (index, group) in enumerate(groups) {
        while token is not None and token.start() < group["start_byte"] {
            value: any = token.group();
            if value in (b"(", b"[", b"{") {
                expression: any = operator.eq(value, b"(");
                if value == b"{" {
                    prefix: any = `bytes(code[statement:token.start()]);
                    expression = previous in (b"=", b"return", b"co_return")
                        or previous in (b",", b"{") and `bool(stack) and stack[-1][1]
                        or re.fullmatch(b"[A-Za-z_][A-Za-z_0-9]*|>|\\]", previous) is not None
                            and previous not in (b"else", b"try", b"do")
                            and not re.search(
                                b"\\b(?:namespace|class|struct|enum|union|extern)\\b", prefix
                            );
                    statement = token.end();
                }
                stack.append((value, expression));
            } elif value in (b")", b"]", b"}") {
                if stack {
                    stack.pop();
                }
                if value == b"}" {
                    statement = token.end();
                }
            } elif value == b";" {
                statement = token.end();
            }
            previous = value;
            token = next(tokens, None);
        }
        if stack and stack[-1][1] or group.get("parent") in selected {
            selected.add(index);
        }
    }
    return selected;
}

impl _recover_cpp_conditional_initializers(path: Path, source: bytes, original: dict) -> dict {
    groups: any;
    coverage: any;
    selected: any;
    merged: dict | None;
    seen: dict[str, dict[str, int]];
    view: any;
    result: any;
    key: any;
    guards: any;
    if not original.get("parse_errors") {
        return original;
    }
    problem: any;
    (groups, problem) = _cpp_conditional_groups(source) as any;
    if not groups and not problem {
        return original;
    }
    coverage = {
        "schema": 1,
        "status": "unrecovered",
        "coverage": "branch-wise syntax",
        "conditions_evaluated": False,
        "combinations_enumerated": False,
        "recovered_from": original["parse_errors"],
    };

    def annotate(result: dict) -> dict {
        file_node: any = next(
            (n for n in result.get("nodes", []) if n.get("id") == _make_id(`str(path))), None
        );
        if file_node is not None {
            file_node.setdefault("metadata", {})["cpp_conditional_recovery"] = coverage;
        }
        return result;
    }

    if problem {
        coverage["reason"] = problem;
        return annotate(original);
    }
    selected = _cpp_expression_conditional_groups(source, groups);
    if not selected {
        return original;
    }
    coverage["groups"] = [
        {k: v for (k, v) in g.items() if k not in ("directives", "has_else")} | {
            "recovered": i in selected,
        }
        for (i, g) in enumerate(groups)
    ];
    choices: any = [`tuple(0 for _ in groups)];
    index: any;
    for index in sorted(selected) {
        branch: any;
        for branch in range(len(groups[index]["branches"])) {
            choice: any = `list(choices[0]);
            choice[index] = branch;
            current: any = groups[index];
            while "parent" in current {
                parent: any = current["parent"];
                choice[parent] = current["parent_branch"];
                current = groups[parent];
            }
            value: any = `tuple(choice);
            if value not in choices {
                choices.append(value);
            }
            if len(choices) > _CPP_CONDITIONAL_VARIANT_LIMIT {
                coverage["reason"] = "branch-view limit exceeded";
                return annotate(original);
            }
        }
    }
    coverage["variant_count"] = len(choices);

    def active(index: int, choice: tuple[int, ...]) -> bool {
        current: any = groups[index];
        while "parent" in current {
            parent: any = current["parent"];
            if parent in selected and choice[parent] != current["parent_branch"] {
                return False;
            }
            current = groups[parent];
        }
        return True;
    }

    coverage["views"] = [
        [
            {"group_line": groups[index]["line"], "branch": choice[index]}
            for index in sorted(selected)
            if active(index, choice)
        ]
        for choice in choices
    ];
    import from tree_sitter { Language, Parser }

    parser: any = Parser(Language(importlib.import_module("tree_sitter_cpp").language()));
    for index in sorted(selected) {
        start: any;
        end: any;
        for (start, end) in groups[index]["directives"][:-1] {
            head: any = source[start:end];
            if re.search(b"#[ \\t]*(?:if|ifdef|ifndef|elif)\\b", head) {
                head = re.sub(b"(#[ \\t]*)elif\\b", b"\\1if", head);
                if parser.parse(head + b"\n#endif\n").root_node.has_error {
                    coverage["reason"] = "malformed conditional expression";
                    return annotate(original);
                }
            }
        }
    }
    merged = None;
    seen = {key: dict[any, any]() for key in ("nodes", "edges", "raw_calls")};
    node_ids: dict[str, dict] = {};
    for (view_index, choice) in enumerate(choices) {
        view = bytearray(source);

        def blank(start: int, end: int) {
            view[start:end] = re.sub(b"[^\\r\\n]", b" ", source[start:end]);
        }

        for index in sorted(selected) {
            group: any = groups[index];
            for (start, end) in group["directives"] {
                blank(start, end);
            }
            for (branch_index, branch) in enumerate(group["branches"]) {
                if branch_index != choice[index] {
                    blank(branch["start_byte"], branch["end_byte"]);
                }
            }
        }
        `root: any = parser.parse(`bytes(view)).root_node;
        if `root.has_error {
            coverage["reason"] = "a branch view still has parse errors";
            return annotate(original);
        }
        for index in sorted(selected) {
            if not active(index, choice) {
                continue;
            }
            start = groups[index]["start_byte"];
            `node: any = `root.descendant_for_byte_range(start, start);
            while `node is not None
                and `node.type not in ("initializer_list", "argument_list", "compound_statement")
            {
                `node = `node.parent;
            }
            if `node is None or `node.type == "compound_statement" {
                coverage["reason"] = "a branch view falls outside initializer or argument syntax";
                return annotate(original);
            }
        }
        result = _extract_generic(
            path, _CPP_CONFIG, source_override=`bytes(view), preserve_call_sites=True
        );
        if result.get("parse_errors") or result.get("error") {
            coverage["reason"] = "a branch view still has parse errors";
            return annotate(original);
        }
        if merged is None {
            merged = {key: value for (key, value) in result.items() if key not in seen};
            merged.update({key: [] for key in seen});
        } elif `any(
            operator.ne(result.get(key), merged.get(key))
            for key in result.keys() | merged.keys()
            if key not in seen,
        ) {
            coverage["reason"] = "branch views have incompatible resolver metadata";
            return annotate(original);
        }
        for key in seen {
            record: any;
            for record in result.get(key, []) {
                if key == "nodes" {
                    previous: any = node_ids.setdefault(record["id"], record);
                    if previous != record {
                        coverage["reason"] = "branch views have conflicting symbol identities";
                        return annotate(original);
                    }
                }
                signature: any = json.dumps(record, sort_keys=True);
                if signature not in seen[key] {
                    merged[key].append(record);
                }
                seen[key][signature] = seen[key].get(signature, 0) | 1 << view_index;
            }
        }
    }
    assert merged is not None;
    coverage["status"] = "recovered";
    for key in seen {
        for record in merged[key] {
            location: any = re.match("L(\\d+)", record.get("source_location") or "");
            line: any = `int(location[1]) if location else 0;
            guards = [
                (index, branch_index)
                for (index, g) in enumerate(groups)
                for (branch_index, branch) in enumerate(g["branches"])
                if branch["start_line"] <= line <= branch["end_line"]
            ];
            expected: any = sum(
                1 << view_index
                for (view_index, choice) in enumerate(choices)
                if all(
                    operator.eq(choice[index], branch)
                    for (index, branch) in guards
                    if index in selected,
                ),
            );
            if seen[key][json.dumps(record, sort_keys=True)] != expected {
                coverage["status"] = "unrecovered";
                coverage["reason"] = "branch-spanning records lack source guard provenance";
                return annotate(original);
            }
            conditions: any = [
                {"group_line": groups[index]["line"], "branch": branch}
                for (index, branch) in guards
            ];
            if conditions {
                record.setdefault("metadata", {})["cpp_conditions"] = conditions;
            }
        }
    }
    return annotate(merged);
}

impl _stamp_cpp_condition_provenance(nodes: list[dict], edges: list[dict]) {
    ranges: dict[str, list[tuple[int, int, int, int]]];
    branch: any;
    ranges = {};
    `node: any;
    for `node in nodes {
        metadata: any = `node.get("metadata");
        coverage: any = metadata.get("cpp_conditional_recovery")
            if isinstance(metadata, `dict)
            else None;
        if not isinstance(coverage, `dict) or coverage.get("status") != "recovered" {
            continue;
        }
        sf: any = `node.get("source_file");
        groups: any = coverage.get("groups");
        if not isinstance(sf, `str) or not sf or not isinstance(groups, `list) {
            continue;
        }
        sf = PurePath(sf).as_posix();
        for group in groups {
            if not isinstance(group, `dict)
                or `type(group.get("line")) is not int
                or not isinstance(group.get("branches"), `list)
            {
                continue;
            }
            index: any;
            for item____ in enumerate(group["branches"]) {
                (index, branch) = item____;
                if not isinstance(branch, `dict)
                    or `any(`type(branch.get(key)) is not int for key in ("start_line", "end_line"))
                {
                    continue;
                }
                ranges.setdefault(sf, []).append((
                    branch["start_line"],
                    branch["end_line"],
                    group["line"],
                    index,
                ));
            }
        }
    }
    if not ranges {
        return;
    }

    def stamp(record: dict, file_key: str, line_key: str) {
        sf: any = PurePath(`str(record.get(file_key) or "")).as_posix();
        location: any = re.match("L(\\d+)", `str(record.get(line_key) or ""));
        if sf not in ranges or location is None {
            return;
        }
        line: any = `int(location[1]);
        conditions: any = [
            {"group_line": group_line, "branch": branch}
            for (start, end, group_line, branch) in ranges[sf]
            if start <= line <= end
        ];
        if conditions {
            metadata: any = record.setdefault("metadata", {});
            if isinstance(metadata, `dict) {
                metadata["cpp_conditions"] = conditions;
            }
        }
    }

    for `edge in edges {
        stamp(`edge, "source_file", "source_location");
    }
    for `node in nodes {
        metadata = `node.get("metadata");
        if isinstance(metadata, `dict) {
            for `entry in metadata.get(UNRESOLVED_CALLS_KEY) or () {
                if isinstance(`entry, `dict) and `entry.get("lang") == "cpp" {
                    stamp(`entry, "file", "line");
                }
            }
        }
    }
}

impl extract_cpp(path: Path) -> dict {
    result: any;
    try {
        source: any = _read_source_bytes(path);
    } except OSError {
        return _augment_cpp_string_tests(path, _extract_generic(path, _CPP_CONFIG));
    }
    source_override: any = _normalize_cpp_cli(source) or source;
    source_override = _normalize_cpp_export_macros(source_override);
    result = _extract_generic(path, _CPP_CONFIG, source_override=source_override);
    result = _recover_cpp_conditional_initializers(path, source_override, result);
    return _augment_cpp_string_tests(path, result);
}

impl extract_ruby(path: Path) -> dict {
    return _extract_generic(path, _RUBY_CONFIG);
}

impl _csharp_string_opener(source: bytes, i: int) -> "tuple[int, int, bool, bool]" {
    j: any = i;
    interpolated: any = False;
    verbatim: any = False;
    while j < len(source) {
        ch: any = source[j:j + 1];
        if ch == b"$" {
            interpolated = True;
        } elif ch == b"@" {
            verbatim = True;
        } else {
            break;
        }
        j += 1;
    }
    if source[j:j + 1] != b"\"" {
        return (j, 0, interpolated, verbatim);
    }
    run: any = 0;
    while source[j + run:j + run + 1] == b"\"" {
        run += 1;
    }
    return (j, run, interpolated, verbatim);
}

impl _csharp_broken_escape_offsets(source: bytes) -> list[int] {
    offsets: list[int] = [];
    n: any = len(source);
    i: any = 0;
    while i < n {
        if source.startswith(b"//", i) {
            nl: any = source.find(b"\n", i);
            i = n if nl == -1 else nl + 1;
            continue;
        }
        if source.startswith(b"/*", i) {
            end: any = source.find(b"*/", i + 2);
            i = n if end == -1 else end + 2;
            continue;
        }
        if source[i:i + 1] == b"'" {
            j: any = i + 1;
            while j < n {
                if source[j:j + 1] == b"\\" {
                    j += 2;
                    continue;
                }
                if source[j:j + 1] in (b"'", b"\n") {
                    break;
                }
                j += 1;
            }
            i = j + 1;
            continue;
        }
        quote: any;
        run: any;
        interpolated: any;
        verbatim: any;
        (quote, run, interpolated, verbatim) = _csharp_string_opener(source, i) as any;
        if run == 0 {
            i = quote if quote > i else i + 1;
            continue;
        }
        if run >= 3 {
            end = source.find(b"\"" * run, quote + run);
            i = n if end == -1 else end + run;
            continue;
        }
        if run == 2 {
            i = quote + 2;
            continue;
        }
        j = quote + 1;
        if verbatim {
            while j < n {
                if source.startswith(b"\"\"", j) {
                    j += 2;
                    continue;
                }
                if source[j:j + 1] == b"\"" {
                    break;
                }
                j += 1;
            }
            if j < n
                and interpolated
                and j - 2 > quote
                and source[j - 2:j] == b"\"\""
                and source[j - 3:j - 2] == b"}"
            {
                offsets.append(j - 2);
            }
        } else {
            while j < n {
                ch: any = source[j:j + 1];
                if ch == b"\\" {
                    j += 2;
                    continue;
                }
                if ch in (b"\"", b"\n") {
                    break;
                }
                j += 1;
            }
        }
        i = j + 1;
    }
    return offsets;
}

impl _normalize_csharp_verbatim_interpolation(source: bytes) -> bytes | None {
    try {
        import tree_sitter_c_sharp as ts_c_sharp;
        import from tree_sitter { Language, Parser }

        parser: any = Parser(Language(ts_c_sharp.language()));
    } except Exception {
        return None;
    }
    try {
        if not parser.parse(source).root_node.has_error {
            return None;
        }
        offsets: any = _csharp_broken_escape_offsets(source);
        if not offsets {
            return None;
        }
        masked: any = bytearray(source);
        for start in offsets {
            masked[start:start + 2] = b"  ";
        }
        out: any = `bytes(masked);
        if parser.parse(out).root_node.has_error {
            return None;
        }
    } except Exception {
        return None;
    }
    return out;
}

impl _csharp_word_byte(b: int) -> bool {
    return operator.ge(b, 128)
        or operator.eq(b, 95)
        or operator.eq(b, 64)
        or operator.le(48, b) and operator.le(b, 57)
        or operator.le(65, b) and operator.le(b, 90)
        or operator.le(97, b) and operator.le(b, 122);
}

impl _csharp_used_as_name(source: bytes, start: int, stop: int) -> bool {
    n: any = len(source);
    j: any = stop;
    while j < n {
        if source[j] in b" \t\r\n" {
            j += 1;
        } elif source.startswith((b"//", b"/*"), j) {
            j = _csharp_token_end(source, j);
        } else {
            break;
        }
    }
    if j >= n or source.startswith(b"=>", j) {
        return False;
    }
    if source[start:stop] in (b"nint", b"nuint") {
        return source.startswith(_CSHARP_ASSIGNMENT_OPERATORS, j) or operator.eq(source[j], 61);
    }
    if source[j] not in _CSHARP_NAME_FOLLOWERS {
        return False;
    }
    k: any = start - 1;
    while k >= 0 and source[k] in b" \t\r\n" {
        k -= 1;
    }
    return operator.lt(k, 0) or operator.ne(source[k], 46);
}

impl _csharp_contextual_name_offsets(source: bytes) -> list[int] {
    offsets: list[int] = [];
    n: any = len(source);
    i: any = 0;
    while i < n {
        end: any = _csharp_token_end(source, i);
        if end > i {
            i = end;
            continue;
        }
        if not _csharp_word_byte(source[i]) {
            i += 1;
            continue;
        }
        stop: any = i + 1;
        while stop < n and _csharp_word_byte(source[stop]) {
            stop += 1;
        }
        if source[i:stop] in _CSHARP_CONTEXTUAL_NAMES and _csharp_used_as_name(source, i, stop) {
            offsets.append(i);
        }
        i = stop;
    }
    return offsets;
}

impl _escape_csharp_contextual_names(source: bytes) -> bytes | None {
    try {
        import tree_sitter_c_sharp as ts_c_sharp;
        import from tree_sitter { Language, Parser }

        parser: any = Parser(Language(ts_c_sharp.language()));
    } except Exception {
        return None;
    }
    try {
        if not parser.parse(source).root_node.has_error {
            return None;
        }
        by_word: dict[bytes, list[tuple[int, int, bytes]]] = {};
        for start in _csharp_contextual_name_offsets(source) {
            stop: any = start;
            while stop < len(source) and 97 <= source[stop] <= 122 {
                stop += 1;
            }
            word: any = source[start:stop];
            if source[stop:stop + 1] in (b" ", b"\t") {
                by_word.setdefault(word, []).append((start, stop + 1, b"@" + word));
            } elif start and source[start - 1:start] in (b" ", b"\t") {
                by_word.setdefault(word, []).append((start - 1, stop, b"@" + word));
            }
        }
        if not by_word {
            return None;
        }
        out: any = bytearray(source);
        spans: any;
        for spans in by_word.values() {
            lo: any;
            hi: any;
            escaped: any;
            for (lo, hi, escaped) in spans {
                out[lo:hi] = escaped;
            }
        }
        if parser.parse(`bytes(out)).root_node.has_error {
            return None;
        }
        for spans in by_word.values() {
            for (lo, hi, _escaped) in spans {
                out[lo:hi] = source[lo:hi];
            }
            if parser.parse(`bytes(out)).root_node.has_error {
                for (lo, hi, escaped) in spans {
                    out[lo:hi] = escaped;
                }
            }
        }
    } except Exception {
        return None;
    }
    return `bytes(out);
}

impl _csharp_token_end(source: bytes, i: int) -> int {
    n: any = len(source);
    if source.startswith(b"//", i) {
        nl: any = source.find(b"\n", i);
        return n if nl == -1 else nl;
    }
    if source.startswith(b"/*", i) {
        end: any = source.find(b"*/", i + 2);
        return n if end == -1 else end + 2;
    }
    if source[i:i + 1] == b"'" {
        j: any = i + 1;
        while j < n and source[j:j + 1] not in (b"'", b"\n") {
            j += 2 if source[j:j + 1] == b"\\" else 1;
        }
        return j + 1 if source[j:j + 1] == b"'" else min(j, n);
    }
    quote: any;
    run: any;
    interpolated: any;
    verbatim: any;
    (quote, run, interpolated, verbatim) = _csharp_string_opener(source, i) as any;
    if run == 0 {
        return i;
    }
    if run >= 3 {
        end = source.find(b"\"" * run, quote + run);
        return n if end == -1 else end + run;
    }
    if run == 2 {
        return quote + 2;
    }
    j = quote + 1;
    while j < n {
        ch: any = source[j:j + 1];
        if verbatim and source.startswith(b"\"\"", j) {
            j += 2;
        } elif ch == b"\\" and not verbatim {
            j += 2;
        } elif ch == b"\"" {
            return j + 1;
        } elif ch == b"\n" and not verbatim {
            return j;
        } elif interpolated and source.startswith(b"{{", j) {
            j += 2;
        } elif interpolated and ch == b"{" {
            depth: any = 1;
            j += 1;
            while j < n and depth {
                end = _csharp_token_end(source, j);
                if end > j {
                    j = end;
                    continue;
                }
                c: any = source[j:j + 1];
                depth += operator.eq(c, b"{") - operator.eq(c, b"}");
                j += 1;
            }
        } else {
            j += 1;
        }
    }
    return n;
}

impl _csharp_branch_balanced(text: bytearray, start: int, end: int) -> bool {
    src: any = `bytes(text[start:end]);
    value__: any = 0;
    brace: any = value__;
    paren: any = value__;
    j: any = 0;
    while j < len(src) {
        tok: any = _csharp_token_end(src, j);
        if tok > j {
            j = tok;
            continue;
        }
        ch: any = src[j:j + 1];
        brace += operator.eq(ch, b"{") - operator.eq(ch, b"}");
        paren += operator.eq(ch, b"(") - operator.eq(ch, b")");
        j += 1;
    }
    return operator.eq(brace, 0) and operator.eq(paren, 0);
}

impl _csharp_branch_member_sigs(text: bytearray, start: int, end: int) -> set[tuple[bytes, int]] {
    src: any = `bytes(text[start:end]);
    masked: any = bytearray(src);
    j: any = 0;
    while j < len(src) {
        tok: any = _csharp_token_end(src, j);
        if tok > j {
            masked[j:tok] = src[j:tok].translate(_CSHARP_BLANK_TABLE);
            j = tok;
        } else {
            j += 1;
        }
    }
    code: any = `bytes(masked);
    depth_at: any = [];
    d: any = 0;
    for ch in code {
        depth_at.append(d);
        if ch == 123 {
            d += 1;
        } elif ch == 125 {
            d -= 1;
        }
    }
    sigs: set[tuple[bytes, int]] = set[any]();
    for m in _CSHARP_MEMBER_DECL_RE.finditer(code) {
        if depth_at[m.start(2)] != 0 or m.group(1) in _CSHARP_NOT_A_TYPE {
            continue;
        }
        name: any = m.group(2);
        if m.group(3) != b"(" {
            sigs.add((name, -1));
            continue;
        }
        k: any = m.end(3);
        level: any;
        angle: any;
        commas: any;
        empty: any;
        (level, angle, commas, empty) = (1, 0, 0, True);
        while k < len(code) and level {
            c: any = code[k:k + 1];
            if c in (b"(", b"[", b"{") {
                level += 1;
            } elif c in (b")", b"]", b"}") {
                level -= 1;
            } elif c == b"<" {
                angle += 1;
            } elif c == b">" {
                angle = max(0, angle - 1);
            } elif c == b"," and level == 1 and angle == 0 {
                commas += 1;
            }
            if level and not c.isspace() {
                empty = False;
            }
            k += 1;
        }
        sigs.add((name, 0 if empty else commas + 1));
    }
    return sigs;
}

impl _blank_csharp_preprocessor(source: bytes) -> bytes | None {
    out: any;
    n: any = len(source);
    directives: list[tuple[int, int, bytes]] = [];
    i: any = 0;
    while i < n {
        p: any = i;
        while p < n and source[p:p + 1] in (b" ", b"\t", b"\x0b", b"\x0c") {
            p += 1;
        }
        if source[p:p + 1] == b"#" {
            nl: any = source.find(b"\n", p);
            end: any = n if nl == -1 else nl;
            k: any = p + 1;
            while k < end and source[k:k + 1] in (b" ", b"\t") {
                k += 1;
            }
            w: any = k;
            while w < end and source[w:w + 1].isalpha() {
                w += 1;
            }
            directives.append((i, end, source[k:w]));
            i = end + 1;
            continue;
        }
        j: any = p;
        while j < n {
            ch: any = source[j:j + 1];
            if ch == b"\n" {
                break;
            }
            end = _csharp_token_end(source, j);
            if end > j {
                j = end;
            } elif ch in (b"$", b"@") {
                j = max(j + 1, _csharp_string_opener(source, j)[0]);
            } else {
                j += 1;
            }
        }
        i = j + 1;
    }
    if not directives {
        return None;
    }

    out = bytearray(source);

    def blank(start: int, end: int) {
        out[start:end] = source[start:end].translate(_CSHARP_BLANK_TABLE);
    }

    def keep(branch: int, bodies: list[tuple[int, int]], kept: list[int]) -> bool {
        sigs: any;
        if branch == 0 {
            return True;
        }
        start: any;
        end: any;
        (start, end) = bodies[branch] as any;
        if not _csharp_branch_balanced(out, start, end) {
            return False;
        }
        sigs = _csharp_branch_member_sigs(out, start, end);
        return not `any(sigs & _csharp_branch_member_sigs(out, *bodies[k]) for k in kept);
    }
    stack: list[list[tuple[int, int]]] = [];

    def close(heads: list[tuple[int, int]], endif_start: int) {
        k: any;
        bodies: any = [
            (heads[k][1], heads[k + 1][0] if k + 1 < len(heads) else endif_start)
            for k in range(len(heads))
        ];
        kept: list[int] = [];
        for k in range(len(bodies)) {
            if keep(k, bodies, kept) {
                kept.append(k);
            } else {
                blank(*bodies[k]);
            }
        }
    }

    for (start, end, word) in directives {
        blank(start, end);
        if word == b"if" {
            stack.append([(start, end)]);
        } elif word in (b"elif", b"else") and stack {
            stack[-1].append((start, end));
        } elif word == b"endif" and stack {
            close(stack.pop(), start);
        }
    }
    while stack {
        close(stack.pop(), n);
    }
    return `bytes(out);
}

impl extract_csharp(path: Path) -> dict {
    source_override: any = None;
    try {
        source: any = _read_source_bytes(path);
    } except OSError {
        source = None;
    }
    if source is not None {
        source_override = _blank_csharp_preprocessor(source);
        source_override = _normalize_csharp_verbatim_interpolation(source_override or source)
            or source_override;
        source_override = _escape_csharp_contextual_names(source_override or source)
            or source_override;
    }
    return _extract_generic(path, _CSHARP_CONFIG, source_override=source_override);
}

impl extract_kotlin(path: Path) -> dict {
    return _extract_generic(path, _KOTLIN_CONFIG);
}

impl extract_scala(path: Path) -> dict {
    return _extract_generic(path, _SCALA_CONFIG);
}

impl _php_mask_to_script_blocks(src: str) -> tuple[str, bool] {
    def _blank(s: str) -> str {
        return re.sub("[^\\r\\n]", " ", s);
    }

    out: list[str] = [];
    pos: any = 0;
    had_script: any = False;
    for m in _PHP_SCRIPT_RE.finditer(src) {
        had_script = True;
        out.append(_blank(src[pos:m.start(1)]));
        out.append(m.group(1));
        out.append(_blank(src[m.end(1):m.end()]));
        pos = m.end();
    }
    if not had_script {
        return (src, False);
    }
    out.append(_blank(src[pos:]));
    return ("".join(out), True);
}

impl _php_blank_unparsed_casts(source: bytes) -> bytes {
    matches: any = `list(_PHP_UNPARSED_CAST_RE.finditer(source));
    if not matches {
        return source;
    }
    import tree_sitter_php;
    import from tree_sitter { Language, Parser }
    `root: any = Parser(Language(tree_sitter_php.language_php())).parse(source).root_node;
    out: any = bytearray(source);
    for m in matches {
        `node: any = `root.descendant_for_byte_range(m.start(), m.start() + 1);
        while `node is not None and `node.type not in _PHP_NON_CODE {
            `node = `node.parent;
        }
        if `node is None {
            out[m.start():m.end()] = re.sub(b"[^\\r\\n]", b" ", m.group());
        }
    }
    return `bytes(out);
}

impl extract_php(path: Path) -> dict {
    result: any;
    n: any;
    try {
        source: any = _php_blank_unparsed_casts(_read_source_bytes(path));
    } except Exception {
        source = None;
    }
    result = _extract_generic(path, _PHP_CONFIG, source_override=source, preserve_call_sites=True);
    try {
        src: any = _read_source_text(path, warn=False);
        masked: any;
        had_script: any;
        (masked, had_script) = _php_mask_to_script_blocks(src) as any;
        if not had_script {
            return result;
        }
        js_result: any = _extract_generic(path, _JS_CONFIG, source_override=masked.encode("utf-8"));
        file_node_id: any = result["nodes"][0]["id"] if result.get("nodes") else None;
        existing_ids: any = {n["id"] for n in result.get("nodes", [])};
        colliding_ids: set = set[any]();
        for n in js_result.get("nodes", []) {
            if n["id"] in existing_ids {
                if n["id"] != file_node_id {
                    colliding_ids.add(n["id"]);
                }
                continue;
            }
            result.setdefault("nodes", []).append(n);
            existing_ids.add(n["id"]);
        }
        for e in js_result.get("edges", []) {
            if e.get("source") in colliding_ids or e.get("target") in colliding_ids {
                continue;
            }
            result.setdefault("edges", []).append(e);
        }
    } except Exception {}
    return result;
}

impl extract_lua(path: Path) -> dict {
    return _extract_generic(path, _LUA_CONFIG);
}

impl extract_swift(path: Path) -> dict {
    return _extract_generic(path, _SWIFT_CONFIG);
}

impl _canonicalize_csharp_namespace_nodes(all_nodes: list[dict], all_edges: list[dict]) {
    by_label: dict[str, list[dict]] = {};
    `node: any;
    for `node in all_nodes {
        if `node.get("type") != "namespace" {
            continue;
        }
        label: any = `node.get("label");
        if isinstance(label, `str) {
            by_label.setdefault(label, []).append(`node);
        }
    }

    remap: dict[str, str] = {};
    drop_node_ids: set[int] = set[any]();
    for group in by_label.values() {
        if len(group) < 2 {
            continue;
        }
        canonical: any = sorted(
            group,
            key=lambda (`node) -> any {
                (
                    `str(`node.get("source_file") or ""),
                    `str(`node.get("source_location") or ""),
                    `str(`node.get("id") or ""),
                )
            },
        )[0];
        canonical_id: any = canonical.get("id");
        for `node in group {
            if `node is canonical {
                continue;
            }
            drop_node_ids.add(id(`node));
            dup_id: any = `node.get("id");
            if isinstance(dup_id, `str) and isinstance(canonical_id, `str) {
                remap[dup_id] = canonical_id;
            }
        }
    }

    if remap {
        for `edge in all_edges {
            if `edge.get("source") in remap {
                `edge["source"] = remap[`str(`edge["source"])];
            }
            if `edge.get("target") in remap {
                `edge["target"] = remap[`str(`edge["target"])];
            }
        }
    }

    if drop_node_ids {
        all_nodes[:] = [`node for `node in all_nodes if id(`node) not in drop_node_ids];
    }
}

impl _lang_is_case_insensitive(source_file: object) -> bool {
    if not source_file {
        return False;
    }
    return effective_suffix(`str(source_file)).lower() in _CASE_INSENSITIVE_EXTS;
}

impl _lang_family(source_file: object) -> str | None {
    if not source_file {
        return None;
    }
    return _LANG_FAMILY_BY_EXT.get(effective_suffix(`str(source_file)).lower());
}

impl _node_label_key(`node: dict, fold: bool = False) -> str {
    label: any = `str(`node.get("label", "")).strip();
    key: any = re.sub("[^a-zA-Z0-9_]+", "", label);
    return key.lower() if fold else key;
}

impl _is_top_level_function_definition(`node: dict) -> bool {
    label: any = `str(`node.get("label", "")).strip();
    return operator.eq(`node.get("file_type"), "code")
        and label.endswith(")")
        and not label.startswith(".")
        and "." not in label;
}

impl _rewire_unique_stub_nodes(nodes: list[dict], edges: list[dict], `root: Path | None = None) {
    scan_root: any;
    crate_by_dir: dict[Path, str | None];
    workspace_crates: set[str];
    reexports: dict[tuple[str, str], set[str]];
    _SUPERTYPE_RELATIONS: any;
    by_id: any;
    scan_root = Path(`root).resolve() if `root is not None else None;
    crate_by_dir = {};
    def crate_of(source_file: str) -> str | None {
        if not source_file {
            return None;
        }
        path: any = Path(source_file);
        if not path.is_absolute() and scan_root is not None {
            path = scan_root / path;
        }
        directory: any = path.parent;
        walked: list[Path] = [];
        crate: str | None = None;
        while True {
            if directory in crate_by_dir {
                crate = crate_by_dir[directory];
                break;
            }
            walked.append(directory);
            manifest: any = directory / "Cargo.toml";
            if manifest.is_file() and (crate := package_name(manifest)) {
                break;
            }
            if directory == scan_root or directory.parent == directory {
                break;
            }
            directory = directory.parent;
        }
        for seen in walked {
            crate_by_dir[seen] = crate;
        }
        return crate;
    }
    workspace_crates = set[any]();
    `node: any;
    for `node in nodes {
        sf: any = `str(`node.get("source_file", ""));
        if sf.endswith(".rs") and (crate := crate_of(sf)) {
            workspace_crates.add(crate);
        }
    }
    reexports = {};
    `edge: any;
    for `edge in edges {
        info: any = `edge.get("_rust_pub_use");
        owner: any = crate_of(`str(`edge.get("source_file", "")));
        if not isinstance(info, `dict) or owner is None {
            continue;
        }
        `root = `str(info.get("root", ""));
        if `root != "crate" {
            reexports.setdefault((owner, `str(info.get("label", ""))), set[any]()).add(`root);
        }
    }
    for _ in range(len(workspace_crates)) {
        changed: any = False;
        targets: any;
        for ((crate, label), targets) in `tuple(reexports.items()) {
            more: any = {
                deep
                for `root in `tuple(targets)
                for deep in reexports.get((`root, label), ())
            };
            if not more <= targets {
                targets |= more;
                changed = True;
            }
        }
        if not changed {
            break;
        }
    }
    def in_stub_crate(stub: dict, candidates: list[dict]) -> list[dict] {
        `root: any;
        origin: any = `str(stub.get("origin_file", ""));
        `own: any = crate_of(origin) if origin.endswith(".rs") else None;
        if `own is None {
            return candidates;
        }
        roots: any = stub.get("_rust_use_roots") or ["crate"];
        label: any = `str(stub.get("label", ""));
        named: any = {`own if `root == "crate" else `root for `root in roots} & workspace_crates;
        allowed: any = `set(named);
        for `root in named {
            allowed |= reexports.get((`root, label), set[any]());
        }

        def keep(crates: set[str]) -> list[dict] {
            return [
                candidate
                for candidate in candidates
                if not `str(candidate.get("source_file", "")).endswith(".rs")
                    or crate_of(`str(candidate.get("source_file", ""))) in crates | {None}
            ];
        }

        scoped_named: any = keep(named);
        return scoped_named if len(scoped_named) == 1 else keep(allowed);
    }

    real_by_label: dict[str, list[dict]] = {};
    real_by_label_ci: dict[str, list[dict]] = {};
    func_by_label: dict[str, list[dict]] = {};
    stubs: list[dict] = [];

    for `node in nodes {
        key: any = _node_label_key(`node);
        if not key {
            continue;
        }
        if `node.get("source_file") {
            if _is_type_like_definition(`node) {
                real_by_label.setdefault(key, []).append(`node);
                if _lang_is_case_insensitive(`node.get("source_file")) {
                    real_by_label_ci.setdefault(_node_label_key(`node, fold=True), []).append(
                        `node
                    );
                }
            } elif _is_top_level_function_definition(`node) {
                func_by_label.setdefault(key, []).append(`node);
            }
            continue;
        }
        if `node.get("_cpp_std") {
            continue;
        }
        stubs.append(`node);
    }
    stub_ids: any = {`str(s.get("id")) for s in stubs if s.get("id")};
    stub_families: dict[str, set] = {};
    supertype_stub_ids: set[str] = set[any]();
    _SUPERTYPE_RELATIONS = {"inherits", "implements", "extends"};
    for `edge in edges {
        rel: any = `edge.get("relation");
        for endpoint in ("source", "target") {
            nid: any = `edge.get(endpoint);
            if nid in stub_ids {
                fam: any = _lang_family(`edge.get("source_file"));
                if fam is not None {
                    stub_families.setdefault(`str(nid), set[any]()).add(fam);
                }
                if endpoint == "target" and rel in _SUPERTYPE_RELATIONS {
                    supertype_stub_ids.add(`str(nid));
                }
            }
        }
    }

    remap: dict[str, str] = {};
    file_remap: dict[tuple[str, str], str | None] = {};
    stub: any;
    for stub in stubs {
        stub_id: any = `str(stub.get("id", ""));
        if not stub_id {
            continue;
        }
        candidates: any = in_stub_crate(stub, real_by_label.get(_node_label_key(stub), []));
        if len(candidates) > 1
            and all(operator.eq(_lang_family(c.get("source_file")), "rust") for c in candidates)
        {
            declared: any = [c for c in candidates if c.get("_rust_declaration_count")];
            if len(declared) == 1 and declared[0].get("_rust_declaration_count") == 1 {
                candidates = declared;
            }
        }
        if len(candidates) != 1 {
            candidates = in_stub_crate(
                stub, real_by_label_ci.get(_node_label_key(stub, fold=True), [])
            );
        }
        if len(candidates) != 1 {
            fcands: any = in_stub_crate(stub, func_by_label.get(_node_label_key(stub), []));
            if len(fcands) == 1 and stub_id not in supertype_stub_ids {
                fams: any = stub_families.get(stub_id, set[any]());
                cand_fam: any = _lang_family(fcands[0].get("source_file"));
                if not fams or cand_fam is None or cand_fam in fams {
                    candidates = fcands;
                }
            }
        }
        resolved: str | None = None;
        if len(candidates) == 1 {
            target_id: any = candidates[0].get("id");
            if isinstance(target_id, `str) and target_id and target_id != stub_id {
                resolved = target_id;
            }
        }
        origin: any = `str(stub.get("origin_file", ""));
        if origin.endswith(".rs") {
            key = (stub_id, origin);
            file_remap[key] = resolved if file_remap.get(key, resolved) == resolved else None;
        }
        if resolved is not None {
            remap[stub_id] = resolved;
        }
    }
    sql_stubs: dict[str, list[str]] = {};
    real_by_id: any = {`node.get("id"): `node for `node in nodes if `node.get("source_file")};
    for stub in stubs {
        stub_id = `str(stub.get("id", ""));
        if not stub_id or not `str(stub.get("origin_file", "")).lower().endswith(".sql") {
            continue;
        }
        if _lang_family(real_by_id.get(remap.get(stub_id), {}).get("source_file"))
            not in (None, "sql")
        {
            del remap[stub_id];
        }
        if stub_id not in remap {
            sql_stubs.setdefault(_sql_norm_ident(`str(stub.get("label", ""))), []).append(stub_id);
        }
    }
    for stub_ids in sql_stubs.values() {
        survivor: any = min(stub_ids);
        for stub_id in stub_ids {
            if stub_id != survivor {
                remap[stub_id] = survivor;
            }
        }
    }

    if not remap {
        return;
    }

    by_id = {`node.get("id"): `node for `node in nodes if `node.get("id")};
    csharp_scoped_relations: any = {"inherits", "implements", "references", "imports"};
    def _names_own_builtin_base(`edge: dict, stub_id: str, remapped_id: str) -> bool {
        if `edge.get("relation") not in _SUPERTYPE_RELATIONS {
            return False;
        }
        edge_fam: any = _lang_family(`edge.get("source_file"));
        if edge_fam is None {
            return False;
        }
        label: any = `str(by_id.get(stub_id, {}).get("label", "")).strip();
        if _lang_is_case_insensitive(`edge.get("source_file")) {
            builtins: any = _LANGUAGE_BUILTIN_BASE_CLASSES_CI.get(edge_fam, frozenset());
            label = label.lower();
        } else {
            builtins = _LANGUAGE_BUILTIN_BASE_CLASSES.get(edge_fam, frozenset());
        }
        if label not in builtins {
            return False;
        }
        target_fam: any = _lang_family(by_id.get(remapped_id, {}).get("source_file"));
        return target_fam is not None and operator.ne(target_fam, edge_fam);
    }
    def _cross_language_candidate(`edge: dict, remapped_id: str) -> bool {
        edge_fam: any = _lang_family(`edge.get("source_file"));
        cand_fam: any = _lang_family(by_id.get(remapped_id, {}).get("source_file"));
        return edge_fam is not None and cand_fam is not None and operator.ne(edge_fam, cand_fam);
    }
    def _scoped_by_a_use(stub: dict) -> bool {
        roots: any = stub.get("_rust_use_roots") or [];
        return "crate" in roots or `bool(`set(roots) & workspace_crates);
    }
    rust_by_name_only: any = {
        stub_id
        for stub_id in remap
        if `str(by_id.get(stub_id, {}).get("origin_file", "")).endswith(".rs")
            and not _scoped_by_a_use(by_id.get(stub_id, {}))
    } - {`edge.get("target") for `edge in edges if `edge.get("_rust_use_name")};

    for `edge in edges {
        is_csharp_scoped_edge: any = _is_dotnet_source_file(`str(`edge.get("source_file", "")))
            and `edge.get("relation") in csharp_scoped_relations;
        source: any = `edge.get("source");
        if source in remap {
            remapped_source: any = remap[`str(source)];
            if not (
                is_csharp_scoped_edge
                and _is_cs_file(`str(by_id.get(remapped_source, {}).get("source_file", "")))
            )
                and not _cross_language_candidate(`edge, remapped_source)
            {
                `edge["source"] = remapped_source;
            }
        }
        target: any = `edge.get("target");
        own_key: any = (`str(target), `str(`edge.get("source_file", "")));
        if own_key in file_remap {
            remapped_target: any = file_remap[own_key];
        } else {
            remapped_target = remap.get(`str(target));
        }
        if remapped_target is not None {
            if not (
                is_csharp_scoped_edge
                and _is_cs_file(`str(by_id.get(remapped_target, {}).get("source_file", "")))
            )
                and not _names_own_builtin_base(`edge, `str(target), remapped_target)
                and not _cross_language_candidate(`edge, remapped_target)
            {
                `edge["target"] = remapped_target;
                if target in rust_by_name_only {
                    `edge["confidence"] = "INFERRED";
                }
            }
        }
    }

    referenced: any = {x for e in edges for x in (e.get("source"), e.get("target"))};
    drop_ids: any = {stub_id for stub_id in remap if stub_id not in referenced};
    nodes[:] = [`node for `node in nodes if `node.get("id") not in drop_ids];
}

impl _remap_objc_field_tables(per_file: list, mapping: dict) {
    result: any;
    for result in per_file {
        ft: any = result.get("objc_field_types") if isinstance(result, `dict) else None;
        tables: any = ft.get("tables") if isinstance(ft, `dict) else None;
        if not isinstance(tables, `dict) {
            continue;
        }
        if `any(k in mapping for k in tables) {
            ft["tables"] = {mapping.get(k, k): v for (k, v) in tables.items()};
        }
    }
}

impl _merge_swift_extensions(per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]) {
    result: any;
    e: any;
    extension_nids: set[str] = set[any]();
    extension_labels: dict[str, str] = {};
    for result in per_file {
        for ext in result.get("swift_extensions", []) or [] {
            extension_nids.add(ext["nid"]);
            extension_labels[ext["nid"]] = ext["label"];
        }
    }

    if not extension_nids {
        return;
    }
    contained: any = {e.get("target") for e in all_edges if e.get("relation") == "contains"};

    label_to_canonical: dict[str, list[str]] = {};
    for n in all_nodes {
        if n.get("id") in extension_nids {
            continue;
        }
        label: any = n.get("label");
        if not label {
            continue;
        }
        if _lang_family(n.get("source_file")) != "native" {
            continue;
        }
        if label in _LANGUAGE_BUILTIN_GLOBALS {
            continue;
        }
        if not (n.get("source_file") and n.get("id") in contained and _is_type_like_definition(n)) {
            continue;
        }
        label_to_canonical.setdefault(label, []).append(n["id"]);
    }

    remap: dict[str, str] = {};
    for ext_nid in extension_nids {
        candidates: any = label_to_canonical.get(extension_labels[ext_nid], []);
        if len(candidates) != 1 {
            continue;
        }
        canonical_nid: any = candidates[0];
        if canonical_nid != ext_nid {
            remap[ext_nid] = canonical_nid;
        }
    }

    if not remap {
        return;
    }

    all_nodes[:] = [n for n in all_nodes if n.get("id") not in remap];
    def _key_of(e: dict, src: str, tgt: str) -> tuple {
        return (src, tgt, e.get("relation"), e.get("source_file"), e.get("source_location"));
    }

    rewritten: list[dict] = [];
    seen_keys: set[tuple] = set[any]();
    for e in all_edges {
        src0: any;
        tgt0: any;
        (src0, tgt0) = (e.get("source"), e.get("target"));
        src: any = remap.get(src0, src0);
        tgt: any = remap.get(tgt0, tgt0);
        if src == src0 and tgt == tgt0 {
            seen_keys.add(_key_of(e, src0, tgt0));
            rewritten.append(e);
            continue;
        }
        if src == tgt {
            continue;
        }
        e["source"] = src;
        e["target"] = tgt;
        key: any = _key_of(e, src, tgt);
        if key in seen_keys {
            continue;
        }
        seen_keys.add(key);
        rewritten.append(e);
    }
    all_edges[:] = rewritten;
}

impl _merge_csharp_partial_class_nodes(
    per_file: list[dict],
    all_nodes: list[dict],
    all_edges: list[dict],
    paths: list[Path],
    `root: Path,
) {
    nid_to_path: dict[str, Path];
    result: any;
    proj_exts: any;
    project_dirs: set[Path];
    stop: any;
    dir_assembly: dict[Path, str];
    members: any;
    groups: dict[tuple[str, str], list[dict]] = {};
    n: any;
    for n in all_nodes {
        if not _is_cs_file(`str(n.get("source_file", ""))) {
            continue;
        }
        if n.get("file_type") != "code" {
            continue;
        }
        md: any = n.get("metadata") or {};
        if not md.get("is_partial") {
            continue;
        }
        type_path: any = md.get("type_path");
        if not type_path {
            if md.get("is_nested_type") {
                continue;
            }
            type_path = n.get("label");
        }
        if not type_path {
            continue;
        }
        groups.setdefault((`str(md.get("namespace", "")), `str(type_path)), []).append(n);
    }

    if not `any(operator.ge(len(members), 2) for members in groups.values()) {
        return;
    }
    nid_to_path = {};
    for (result, path) in zip(per_file, paths) {
        for pn in result.get("nodes") or [] {
            nid_to_path.setdefault(pn["id"], path);
        }
    }

    proj_exts = (".csproj", ".fsproj", ".vbproj");
    project_dirs = set[any]();
    for p in paths {
        if p.suffix.lower() in proj_exts {
            try {
                project_dirs.add(p.resolve().parent);
            } except OSError {}
        }
    }
    try {
        stop = `root.resolve();
    } except OSError {
        stop = `root;
    }
    dir_assembly = {};
    def _assembly_of_dir(d: Path) -> str {
        c: any;
        chain: list[Path] = [];
        key: any = "";
        while True {
            cached: any = dir_assembly.get(d);
            if cached is not None {
                key = cached;
                break;
            }
            chain.append(d);
            if d in project_dirs {
                key = `str(d);
                break;
            }
            try {
                has_project: any = `any(c.suffix.lower() in proj_exts for c in d.iterdir());
            } except OSError {
                has_project = False;
            }
            if has_project {
                key = `str(d);
                break;
            }
            if d == stop or d.parent == d {
                break;
            }
            d = d.parent;
        }
        for c in chain {
            dir_assembly[c] = key;
        }
        return key;
    }

    def _assembly_of_node(nid: str) -> str {
        path: any = nid_to_path.get(nid);
        if path is None {
            return "";
        }
        try {
            d: any = path.resolve().parent;
        } except OSError {
            return "";
        }
        return _assembly_of_dir(d);
    }

    remap: dict[str, str] = {};
    for members in groups.values() {
        if len(members) < 2 {
            continue;
        }
        by_assembly: dict[str, list[dict]] = {};
        for n in members {
            by_assembly.setdefault(_assembly_of_node(n["id"]), []).append(n);
        }
        for halves in by_assembly.values() {
            if len(halves) < 2 {
                continue;
            }
            halves.sort(
                key=lambda (n) -> any {
                    (
                        `str(n.get("source_file", "")),
                        `str(n.get("source_location", "")),
                        `str(n.get("id", "")),
                    )
                },
            );
            canonical_nid: any = halves[0]["id"];
            for other in halves[1:] {
                if other["id"] != canonical_nid {
                    remap[other["id"]] = canonical_nid;
                }
            }
        }
    }

    if not remap {
        return;
    }

    all_nodes[:] = [n for n in all_nodes if n.get("id") not in remap];
    def _key_of(e: dict, src: str | None, tgt: str | None) -> tuple {
        return (src, tgt, e.get("relation"), e.get("source_file"), e.get("source_location"));
    }

    rewritten: list[dict] = [];
    seen_keys: set[tuple] = set[any]();
    for e in all_edges {
        src0: any;
        tgt0: any;
        (src0, tgt0) = (e.get("source"), e.get("target"));
        src: any = remap.get(src0, src0);
        tgt: any = remap.get(tgt0, tgt0);
        if src == src0 and tgt == tgt0 {
            seen_keys.add(_key_of(e, src0, tgt0));
            rewritten.append(e);
            continue;
        }
        if src == tgt and src0 != tgt0 {
            continue;
        }
        e["source"] = src;
        e["target"] = tgt;
        key: any = _key_of(e, src, tgt);
        if key in seen_keys {
            continue;
        }
        seen_keys.add(key);
        rewritten.append(e);
    }
    all_edges[:] = rewritten;
    for result in per_file {
        for rc in result.get("raw_calls", []) or [] {
            cn: any = rc.get("caller_nid");
            if cn in remap {
                rc["caller_nid"] = remap[cn];
            }
            eo: any = rc.get("evidence_owner");
            if eo in remap {
                rc["evidence_owner"] = remap[eo];
            }
        }
    }
}

impl _drop_shadowed_csharp_partial_bases(all_nodes: list[dict], all_edges: list[dict]) {
    nodes_by_id: any;
    aliases_by_file: dict[str, set[str]];
    real_bases: dict[str, set[str]];
    nodes_by_id = {`str(n.get("id", "")): n for n in all_nodes};
    aliases_by_file = {};
    e: any;
    for e in all_edges {
        md: any = e.get("metadata");
        if not isinstance(md, `dict) or md.get("using_kind") != "alias" {
            continue;
        }
        alias: any = md.get("alias");
        src_node: any = nodes_by_id.get(`str(e.get("source", ""))) or {};
        if isinstance(alias, `str) and alias {
            aliases_by_file.setdefault(`str(src_node.get("source_file", "")), set[any]()).add(
                alias
            );
        }
    }

    def _is_partial_cs(nid: str) -> bool {
        n: any = nodes_by_id.get(nid) or {};
        return `str(n.get("source_file", "")).endswith(".cs")
            and `bool((n.get("metadata") or {}).get("is_partial"));
    }

    real_bases = {};
    for e in all_edges {
        if e.get("relation") not in ("inherits", "implements") {
            continue;
        }
        src: any = `str(e.get("source", ""));
        if not _is_partial_cs(src) {
            continue;
        }
        tgt: any = nodes_by_id.get(`str(e.get("target", ""))) or {};
        if tgt.get("source_file") {
            real_bases.setdefault(src, set[any]()).add(`str(tgt.get("label", "")));
        }
    }
    if not real_bases {
        return;
    }

    def _shadowed(e: dict) -> bool {
        if e.get("relation") not in ("inherits", "implements") {
            return False;
        }
        names: any = real_bases.get(`str(e.get("source", "")));
        if not names {
            return False;
        }
        tgt: any = nodes_by_id.get(`str(e.get("target", ""))) or {};
        label: any = `str(tgt.get("label", ""));
        if tgt.get("source_file") or label not in names {
            return False;
        }
        md: any = e.get("metadata");
        if isinstance(md, `dict) and md.get("qualified") {
            return False;
        }
        return label not in aliases_by_file.get(`str(e.get("source_file", "")), set[any]());
    }

    all_edges[:] = [e for e in all_edges if not _shadowed(e)];
}

impl _park_unresolved_member_call(
    caller_node: dict | None, callee: str, receiver_type: str, lang: str, raw_call: dict
) {
    if not caller_node or not callee or not receiver_type {
        return;
    }
    metadata: any = caller_node.setdefault("metadata", {});
    if not isinstance(metadata, `dict) {
        return;
    }
    parked: any = metadata.setdefault(UNRESOLVED_CALLS_KEY, []);
    if not isinstance(parked, `list) or len(parked) >= _MAX_PARKED_CALLS_PER_NODE {
        return;
    }
    (callee, receiver_type) = (`str(callee), `str(receiver_type));
    arity: any = raw_call.get("arity");
    arity = arity if isinstance(arity, `int) and not isinstance(arity, `bool) else None;
    for previous in parked {
        if isinstance(previous, `dict)
            and previous.get("callee") == callee
            and previous.get("receiver_type") == receiver_type
            and previous.get("arity") == arity
        {
            return;
        }
    }
    `entry: dict[str, object] = {"callee": callee, "receiver_type": receiver_type, "lang": lang};
    if arity is not None {
        `entry["arity"] = arity;
    }
    location: any = raw_call.get("source_location");
    if location {
        `entry["line"] = `str(location);
    }
    call_file: any = raw_call.get("source_file");
    if call_file {
        `entry["file"] = `str(call_file);
    }
    parked.append(`entry);
}

impl _resolve_swift_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) {
    result: any;
    top_level_type_nids: dict[str, list[str]];
    node_by_id: dict[str, dict];
    lexical_parents: dict[str, str];
    nested_types: dict[tuple[str, str], set[str]];
    method_index: dict[tuple[str, str], str];
    exact_methods: dict[tuple[str, str], set[str]];
    e: any;
    type_table_by_file: dict[str, dict[str, str]] = {};
    for result in per_file {
        tt: any = result.get("swift_type_table");
        if tt and tt.get("path") {
            type_table_by_file[tt["path"]] = tt.get("table", {});
        }
    }
    def _key(label: str) -> str {
        return re.sub("[^a-zA-Z0-9]+", "", `str(label)).lower();
    }
    contained: any = {e.get("target") for e in all_edges if e.get("relation") == "contains"};
    type_def_nids: dict[str, list[str]] = {};
    top_level_type_nids = {};
    node_by_id = {};
    for n in all_nodes {
        node_by_id[n.get("id")] = n;
        if `str(n.get("source_file", "")).lower().endswith(".swift")
            and n.get("id") in contained
            and _is_type_like_definition(n)
        {
            type_def_nids.setdefault(_key(n.get("label", "")), []).append(n["id"]);
            path: any = (n.get("metadata") or {}).get("type_path", n.get("label", ""));
            if "." not in path {
                top_level_type_nids.setdefault(_key(n.get("label", "")), []).append(n["id"]);
            }
        }
    }

    type_ids: any = {nid for definitions in type_def_nids.values() for nid in definitions};
    lexical_parents = {};
    nested_types = {};
    for `edge in all_edges {
        parent: any;
        child: any;
        (parent, child) = (`edge.get("source"), `edge.get("target"));
        if not isinstance(parent, `str) or not isinstance(child, `str) or parent not in type_ids {
            continue;
        }
        if `edge.get("relation") == "contains" and child in type_ids {
            lexical_parents[child] = parent;
            nested_types.setdefault(
                (parent, _key(node_by_id[child].get("label", ""))), set[any]()
            ).add(child);
        } elif `edge.get("relation") == "method" {
            lexical_parents[child] = parent;
        }
    }

    def scoped_type_definitions(name: str, caller: str) -> list[str] {
        if "." in name {
            first: any;
            _: any;
            rest: any;
            (first, _, rest) = name.partition(".") as any;
            definitions: any = scoped_type_definitions(first, caller);
            for segment in rest.split(".") {
                if len(definitions) != 1 {
                    return [];
                }
                definitions = sorted(nested_types.get((definitions[0], _key(segment)), ()));
            }
            return definitions;
        }
        scope: any = lexical_parents.get(caller);
        seen: set[str] = set[any]();
        while scope and scope not in seen {
            seen.add(scope);
            nested: any = nested_types.get((scope, _key(name)));
            if nested {
                return sorted(nested);
            }
            if _key(node_by_id[scope].get("label", "")) == _key(name) {
                return [scope];
            }
            scope = lexical_parents.get(scope);
        }
        return top_level_type_nids.get(_key(name), []);
    }
    method_index = {};
    exact_methods = {};
    for e in all_edges {
        if e.get("relation") != "method" {
            continue;
        }
        src: any;
        tgt: any;
        (src, tgt) = (e.get("source"), e.get("target"));
        tnode: any = node_by_id.get(tgt);
        if tnode is not None {
            label: any = `str(tnode.get("label", ""));
            method_index[src, _key(label)] = tgt;
            if src and tgt {
                exact_methods.setdefault(
                    (src, label.removesuffix("()").lstrip(".")), set[any]()
                ).add(tgt);
            }
        }
    }

    def _member(type_nid: str, name: str) -> str | None {
        exact: any = exact_methods.get((type_nid, name), set[any]());
        if len(exact) == 1 {
            return next(iter(exact));
        }
        return method_index.get((type_nid, _key(name)));
    }
    factory_by_file: dict[str, dict] = {};
    for result in per_file {
        tt = result.get("swift_type_table");
        if tt and tt.get("path") and tt.get("factory") {
            factory_by_file[tt["path"]] = tt["factory"];
        }
    }
    if factory_by_file {
        return_targets_by_method: dict[str, set[str]] = {};
        for e in all_edges {
            if e.get("relation") == "references"
                and e.get("context") == "return_type"
                and (e.get("metadata") or {}).get("swift_plain_return")
            {
                return_targets_by_method.setdefault(e.get("source"), set[any]()).add(
                    e.get("target")
                );
            }
        }
        for (path, pending) in factory_by_file.items() {
            table: any = `dict(type_table_by_file.get(path, {}));
            type_table_by_file[path] = table;
            receiver: any;
            for (receiver, bind) in pending.items() {
                try {
                    factory_type: any;
                    factory_method: any;
                    (factory_type, factory_method) = bind as any;
                } except (TypeError, ValueError) {
                    continue;
                }
                if factory_type in _LANGUAGE_BUILTIN_GLOBALS {
                    continue;
                }
                factory_defs: any = type_def_nids.get(_key(factory_type), []);
                if len(factory_defs) != 1 {
                    continue;
                }
                method_nid: any = _member(factory_defs[0], factory_method);
                if method_nid is None {
                    continue;
                }
                targets: any = return_targets_by_method.get(method_nid, set[any]());
                if len(targets) != 1 {
                    continue;
                }
                tnode = node_by_id.get(next(iter(targets)));
                ret_label: any = `str(tnode.get("label", "")) if tnode else "";
                if not ret_label or ret_label in _LANGUAGE_BUILTIN_GLOBALS {
                    continue;
                }
                if len(type_def_nids.get(_key(ret_label), [])) != 1 {
                    continue;
                }
                table.setdefault(receiver, ret_label);
            }
        }
    }

    all_raw_calls: list[dict] = [];
    for result in per_file {
        all_raw_calls.extend(result.get("raw_calls", []));
    }

    existing_pairs: any = {(e.get("source"), e.get("target")) for e in all_edges};
    for rc in all_raw_calls {
        if not rc.get("is_member_call")
            or not `str(rc.get("source_file", "")).lower().endswith(".swift")
        {
            continue;
        }
        receiver = rc.get("receiver");
        callee: any = rc.get("callee");
        caller: any = rc.get("caller_nid");
        if not receiver or not callee or not caller {
            continue;
        }
        if receiver[:1].isupper() {
            type_name: any = receiver;
            type_qualified: any = True;
        } else {
            type_name = type_table_by_file.get(rc.get("source_file", ""), {}).get(receiver);
            type_qualified = False;
        }
        if not type_name {
            continue;
        }
        if type_name in _LANGUAGE_BUILTIN_GLOBALS {
            continue;
        }
        type_defs: any = scoped_type_definitions(type_name, caller);
        if not type_defs {
            if `str(rc.get("source_file", "")).lower().endswith(".swift") {
                _park_unresolved_member_call(
                    node_by_id.get(caller), callee, type_name, "swift", rc
                );
            }
            continue;
        }
        if len(type_defs) != 1 {
            continue;
        }
        type_nid: any = type_defs[0];
        method_nid = _member(type_nid, callee);
        target: any = method_nid or type_nid;
        relation: any = "calls" if method_nid else "references";
        if target == caller or (caller, target) in existing_pairs {
            continue;
        }
        existing_pairs.add((caller, target));
        all_edges.append({
            "source": caller,
            "target": target,
            "relation": relation,
            "context": "call",
            "confidence": "EXTRACTED" if type_qualified else "INFERRED",
            "confidence_score": 1.0 if type_qualified else 0.85,
            "source_file": rc.get("source_file", ""),
            "source_location": rc.get("source_location"),
            "weight": 1.0,
        });
    }
}

impl _stamp_python_fixture_paths(per_file: "list[dict | None]", `root: Path) {
    result: any;
    def rel(source_file: str) -> str {
        path: any = Path(source_file);
        if not path.is_absolute() {
            return path.as_posix();
        }
        try {
            return path.resolve().relative_to(`root).as_posix();
        } except (OSError, ValueError) {
            return path.as_posix();
        }
    }

    for result in per_file {
        if not result {
            continue;
        }
        for rc in result.get("raw_calls", []) {
            if rc.get("_python_fixture_param") and rc.get("source_file") {
                rc["_python_test_file"] = rel(`str(rc["source_file"]));
            }
        }
        located: any = {
            n["id"]: rel(`str(n["source_file"]))
            for n in result.get("nodes", [])
            if n.get("_py_fixture") and n.get("source_file")
        };
        if located {
            result["_python_fixture_files"] = located;
        }
    }
}

impl _resolve_python_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) {
    node_by_id: dict[str, dict];
    method_index: dict[tuple[str, str], list[str]];
    result: any;
    file_of_node: dict[str, str];
    imported_by_filenode: dict[str, set[str]];
    existing_pairs: any;
    call_like_pairs: any;
    method_class: dict[str, str];
    fixtures_by_name: dict[str, list[tuple[str, dict]]];
    n: any;
    resolved_call_sites: dict[tuple[str, tuple[int, ...]], set[str]];
    bases_of: dict[str, list[str]];
    def _key(label: str) -> str {
        return re.sub("[^a-zA-Z0-9]+", "", `str(label)).lower();
    }

    def _is_python_file(source_file: object) -> bool {
        suffix: any = effective_suffix(`str(source_file or ""));
        if suffix.lower() in (".py", ".pyi") {
            return True;
        }
        return suffix not in _DISPATCH and suffix.lower() not in _DISPATCH;
    }

    node_by_id = {n.get("id"): n for n in all_nodes};
    class_def_nids: dict[str, list[str]] = {};
    method_index = {};
    owner_of: dict[str, str] = {};
    e: any;
    for e in all_edges {
        if e.get("relation") != "method" {
            continue;
        }
        src: any;
        tgt: any;
        (src, tgt) = (e.get("source"), e.get("target"));
        if src and tgt {
            owner_of[tgt] = src;
        }
        cnode: any = node_by_id.get(src);
        if cnode is not None and _is_python_file(cnode.get("source_file")) {
            class_def_nids.setdefault(_key(cnode.get("label", "")), []).append(src);
        }
        tnode: any = node_by_id.get(tgt);
        if tnode is not None {
            slot: any = method_index.setdefault((src, _key(tnode.get("label", ""))), []);
            if tgt not in slot {
                slot.append(tgt);
            }
        }
    }

    def _method_of(cls: str, callee: str) -> "str | None" {
        hits: any = method_index.get((cls, _key(callee)), []);
        if len(hits) > 1 {
            hits = [
                m
                for m in hits
                if `str(node_by_id.get(m, {}).get("label", "")).strip().lstrip(".").removesuffix(
                    "()"
                )
                    == callee
            ];
        }
        return hits[0] if len(hits) == 1 else None;
    }
    for k in `list(class_def_nids) {
        class_def_nids[k] = sorted(`set(class_def_nids[k]));
    }

    all_raw_calls: list[dict] = [];
    for result in per_file {
        all_raw_calls.extend(result.get("raw_calls", []));
    }
    contains_children: dict[str, dict[str, list[str]]] = {};
    contains_exact: dict[tuple[str, str], list[str]] = {};
    file_of_node = {};
    for e in all_edges {
        if e.get("relation") == "contains" {
            (src, tgt) = (e.get("source"), e.get("target"));
            tnode = node_by_id.get(tgt);
            if tnode is not None {
                label: any = `str(tnode.get("label", ""));
                contains_children.setdefault(src, {}).setdefault(_key(label), []).append(tgt);
                contains_exact.setdefault((src, label.strip("()").lstrip(".")), []).append(tgt);
                file_of_node[tgt] = src;
            }
        }
    }
    imported_by_filenode = {};
    import_alias_by_filenode: dict[str, dict[str, str]] = {};
    external_plain_imports: dict[str, dict[str, list[str]]] = {};
    for e in all_edges {
        if e.get("relation") in ("imports", "imports_from") {
            imported_by_filenode.setdefault(e.get("source"), set[any]()).add(e.get("target"));
            alias: any = e.get("local_alias");
            if alias {
                import_alias_by_filenode.setdefault(e.get("source"), {})[e.get("target")] = _key(
                    alias
                );
            }
        }
        if e.get("relation") == "imports" and e.get("_python_plain_import") is True {
            target: any;
            (src, target) = (e.get("source"), e.get("target"));
            if not isinstance(src, `str) or not isinstance(target, `str) {
                continue;
            }
            if target in node_by_id or target in contains_children or target in file_of_node {
                continue;
            }
            binding: any = e.get("local_alias") or target;
            if isinstance(binding, `str) {
                external_plain_imports.setdefault(src, {}).setdefault(binding, []).append(target);
            }
        }
    }

    def _module_stem_key(nid: str) -> str {
        n: any = node_by_id.get(nid);
        if not n {
            return "";
        }
        sf: any = n.get("source_file") or "";
        stem: any = Path(sf).stem if sf else "";
        return _key(stem or n.get("label", ""));
    }

    existing_pairs = {(e.get("source"), e.get("target")) for e in all_edges};
    call_like_pairs = {
        (e.get("source"), e.get("target"))
        for e in all_edges
        if e.get("relation") in ("calls", "indirect_call")
    };
    method_class = {};
    for e in all_edges {
        (src, tgt) = (e.get("source"), e.get("target"));
        if e.get("relation") == "method" and isinstance(src, `str) and isinstance(tgt, `str) {
            method_class[tgt] = src;
        }
    }
    fixture_locations: dict[str, str] = {};
    for result in per_file {
        fixture_locations.update(result.get("_python_fixture_files") or {});
    }
    fixtures_by_name = {};
    for n in all_nodes {
        if n.get("_py_fixture") and n.get("source_file") {
            where: any = fixture_locations.get(n["id"])
                or `str(n["source_file"]).replace("\\", "/");
            name: any = `str(n.get("label", "")).strip().lstrip(".").removesuffix("()");
            fixtures_by_name.setdefault(name, []).append((where, n));
        }
    }

    def _nearest_fixture(test_file: str, name: str) -> dict | None {
        candidates: any = fixtures_by_name.get(name, []);
        if not test_file or not candidates {
            return None;
        }
        `here: any = [n for (where, n) in candidates if where == test_file];
        directory: any = test_file;
        while not `here {
            parent: any = posixpath.dirname(directory);
            if parent == directory {
                return None;
            }
            directory = parent;
            conftest: any = posixpath.join(directory, "conftest.py")
                if directory
                else "conftest.py";
            `here = [n for (where, n) in candidates if where == conftest];
            if not directory {
                break;
            }
        }
        if `here {
            return `here[0] if len(`here) == 1 else None;
        }
        return None;
    }

    def _file_node(nid: str) -> "str | None" {
        seen: set[str] = set[any]();
        parent: "str | None" = None;
        while nid and nid not in seen {
            seen.add(nid);
            up: any = file_of_node.get(nid) or method_class.get(nid);
            if not up {
                return parent;
            }
            value___: any = up;
            parent = value___;
            nid = value___;
        }
        return None;
    }

    resolved_call_sites = {};

    def _emit_call(caller: str, target_nid: "str | None", rc: dict, inferred: bool = False) {
        if not target_nid or target_nid == caller {
            return;
        }
        target_file: any = node_by_id.get(target_nid, {}).get("source_file");
        if target_file and not _is_python_file(target_file) {
            return;
        }
        if rc.get("indirect") {
            if (caller, target_nid) in call_like_pairs {
                return;
            }
            if not node_by_id.get(target_nid, {}).get("_callable")
                or node_by_id.get(target_nid, {}).get("_callable_class")
            {
                return;
            }
            call_like_pairs.add((caller, target_nid));
            existing_pairs.add((caller, target_nid));
            all_edges.append({
                "source": caller,
                "target": target_nid,
                "relation": "indirect_call",
                "context": rc.get("context", "collection"),
                "confidence": "INFERRED",
                "confidence_score": 0.85,
                "source_file": rc.get("source_file", ""),
                "source_location": rc.get("source_location"),
                "weight": 1.0,
            });
            return;
        }
        if rc.get("_python_attr_read") {
            target: any = node_by_id.get(target_nid, {});
            label: any = `str(target.get("label", "")).strip().lstrip(".").removesuffix("()");
            if not target.get("_py_property") or label != rc.get("callee") {
                return;
            }
        } elif rc.get("_python_call_site") {
            site: any = (caller, `tuple(rc["_python_call_site"]));
            resolved_call_sites.setdefault(site, set[any]()).add(target_nid);
        }
        if (caller, target_nid) in existing_pairs {
            return;
        }
        existing_pairs.add((caller, target_nid));
        if not rc.get("_python_attr_read") {
            call_like_pairs.add((caller, target_nid));
        }
        all_edges.append({
            "source": caller,
            "target": target_nid,
            "relation": "references" if rc.get("_python_attr_read") else "calls",
            "context": "property_read" if rc.get("_python_attr_read") else "call",
            "confidence": "INFERRED" if inferred else "EXTRACTED",
            "confidence_score": 0.85 if inferred else 1.0,
            "source_file": rc.get("source_file", ""),
            "source_location": rc.get("source_location"),
            "weight": 1.0,
        });
    }
    inherits_edges: any = [`dict(e) for e in all_edges if e.get("relation") == "inherits"];
    if `any(
        not node_by_id.get(`str(e.get("target")), {}).get("source_file") for e in inherits_edges
    ) {
        _rewire_unique_stub_nodes(`list(all_nodes), inherits_edges);
    }
    bases_of = {};
    for e in inherits_edges {
        (src, tgt) = (e.get("source"), e.get("target"));
        if isinstance(src, `str) and isinstance(tgt, `str) {
            bases_of.setdefault(src, []);
            if tgt not in bases_of[src] {
                bases_of[src].append(tgt);
            }
        }
    }

    def _inherited_method(caller: str, callee: str, skip_own: bool) -> "str | None" {
        cls: any = method_class.get(caller);
        seen: set[str] = set[any]();
        first_hop: any = True;
        while cls and cls not in seen {
            seen.add(cls);
            if not skip_own {
                hit: any = _method_of(cls, callee);
                if hit {
                    return hit;
                }
            }
            skip_own = False;
            if (node_by_id.get(cls, {}).get("metadata") or {}).get("python_opaque_bases") {
                return None;
            }
            bases: any = bases_of.get(cls, []);
            if len(bases) != 1 or bases[0] == cls {
                return None;
            }
            base: any = bases[0];
            cls_file: any;
            base_file: any;
            (cls_file, base_file) = (_file_node(cls), _file_node(base));
            if cls_file is None
                or base_file is None
                or not node_by_id.get(base, {}).get("source_file")
            {
                return None;
            }
            if first_hop {
                imported: any = imported_by_filenode.get(cls_file, set[any]());
                if not (base_file == cls_file or base in imported or base_file in imported) {
                    return None;
                }
            }
            first_hop = False;
            cls = base;
        }
        return None;
    }

    factory_receivers: list[dict] = [];
    rc: any;
    for rc in [r for r in all_raw_calls if not r.get("indirect")] + [
        r
        for r in all_raw_calls
        if r.get("indirect")
    ] {
        if rc.get("_ambiguous_python_import") {
            continue;
        }
        if not rc.get("is_member_call") {
            continue;
        }
        if not _is_python_file(rc.get("source_file")) {
            continue;
        }
        receiver: any = rc.get("receiver");
        callee: any = rc.get("callee");
        caller: any = rc.get("caller_nid");
        if rc.get("indirect")
            and not (receiver and callee and caller and not receiver[:1].isupper())
        {
            continue;
        }
        if not rc.get("indirect")
            and receiver in ("self", "cls", "super")
            and callee
            and caller
            and not rc.get("_python_super_args")
        {
            target = _inherited_method(caller, callee, skip_own=operator.eq(receiver, "super"));
            if target {
                _emit_call(caller, target, rc);
                continue;
            }
        }
        attr_type: any = rc.get("_python_self_attr_type");
        if attr_type and callee and caller and not rc.get("indirect") {
            class_nids: any = class_def_nids.get(_key(attr_type), []);
            caller_file: any = file_of_node.get(owner_of.get(caller, ""));
            if len(class_nids) == 1
                and caller_file is not None
                and (
                    file_of_node.get(class_nids[0]) == caller_file
                    or class_nids[0] in imported_by_filenode.get(caller_file, ())
                )
            {
                method_nid: any = _method_of(class_nids[0], callee);
                _emit_call(caller, method_nid, rc, inferred=True);
            }
            continue;
        }
        if not receiver or not callee or not caller {
            continue;
        }
        if rc.get("_python_receiver_factory") {
            factory_receivers.append(rc);
            continue;
        }
        if rc.get("_python_receiver_shadowed") is False {
            caller_file = file_of_node.get(caller);
            targets: any = external_plain_imports.get(caller_file, {}).get(receiver, [])
                if caller_file is not None
                else [];
            if len(targets) == 1 {
                _emit_call(caller, targets[0], rc);
                continue;
            }
            if targets {
                continue;
            }
        }
        if rc.get("_python_fixture_param") {
            fixture: any = _nearest_fixture(`str(rc.get("_python_test_file") or ""), receiver);
            fixture_type: any = fixture.get("_py_fixture") if fixture is not None else None;
            if fixture is not None and fixture_type and fixture_type != PYTEST_FIXTURE_UNTYPED {
                class_nids = class_def_nids.get(_key(fixture_type), []);
                fixture_file: any = _file_node(fixture["id"]);
                if len(class_nids) == 1 and fixture_file is not None {
                    cls: any = class_nids[0];
                    imported: any = imported_by_filenode.get(fixture_file, set[any]());
                    cls_file: any = _file_node(cls);
                    if cls_file == fixture_file
                        or cls in imported
                        or cls_file is not None and cls_file in imported
                    {
                        _emit_call(caller, _method_of(cls, callee), rc, inferred=True);
                    }
                }
            }
            continue;
        }
        receiver_type: any = rc.get("receiver_type");
        if receiver_type and (not receiver[:1].isupper() or rc.get("_python_module_instance")) {
            class_nids = class_def_nids.get(_key(receiver_type), []);
            if rc.get("_python_module_instance") {
                class_nids = [
                    nid
                    for nid in class_nids
                    if node_by_id[nid].get("label") == receiver_type
                ];
            }
            caller_file = _file_node(caller);
            if len(class_nids) == 1 and caller_file is not None {
                cls = class_nids[0];
                imported = imported_by_filenode.get(caller_file, set[any]());
                cls_file = _file_node(cls);
                if cls_file == caller_file
                    or cls in imported
                    or cls_file is not None and cls_file in imported
                {
                    _emit_call(caller, _method_of(cls, callee), rc, inferred=True);
                }
            }
            continue;
        }
        if receiver[:1].isupper() {
            class_nids = class_def_nids.get(_key(receiver), []);
            if len(class_nids) != 1 {
                continue;
            }
            _emit_call(caller, _method_of(class_nids[0], callee), rc);
        } else {
            rkey: any = _key(receiver);
            caller_file = _file_node(caller);
            if caller_file is None
                and rc.get("indirect")
                and caller in imported_by_filenode
                and caller not in file_of_node
            {
                caller_file = `str(caller);
            }
            file_aliases: any = import_alias_by_filenode.get(caller_file, {});
            mods: any = [
                t
                for t in imported_by_filenode.get(caller_file, ())
                if t in contains_children
                    and t not in file_of_node
                    and (_module_stem_key(t) == rkey or file_aliases.get(t) == rkey)
            ];
            if len(mods) != 1 {
                continue;
            }
            children: any = contains_children[mods[0]].get(_key(callee), []);
            if len(children) > 1 {
                children = contains_exact.get((mods[0], callee), []);
            }
            if len(children) != 1 {
                continue;
            }
            _emit_call(caller, children[0], rc);
        }
    }
    return_classes: dict[str, set[str]] = {};
    class_ids: any = {nid for group in class_def_nids.values() for nid in group};
    for `edge in all_edges {
        if `edge.get("relation") == "references" and `edge.get("context") == "return_type" {
            if not node_by_id.get(`edge["source"], {}).get("_py_return_type") {
                continue;
            }
            return_classes.setdefault(`edge["source"], set[any]()).add(`edge["target"]);
        }
    }
    for rc in factory_receivers {
        site: any = (rc["caller_nid"], `tuple(rc["_python_receiver_factory"]));
        producers: any = resolved_call_sites.get(site, set[any]());
        if len(producers) != 1 {
            continue;
        }
        classes: any = return_classes.get(next(iter(producers)), set[any]());
        if len(classes) != 1 {
            continue;
        }
        cls = next(iter(classes));
        if cls in class_ids {
            _emit_call(rc["caller_nid"], _method_of(cls, rc["callee"]), rc, inferred=True);
        }
    }
}

impl _resolve_typescript_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) {
    result: any;
    ts_fields_by_id: dict[tuple[str, bool], dict[str, str]];
    node_by_id: dict[str, dict];
    e: any;
    file_of_node: dict[str, str];
    bases: dict[str, list[str]];
    field_classes_by_key: dict[str, list[str]];
    caller_file: any;
    imported: any;
    def _key(label: str) -> str {
        return re.sub("[^a-zA-Z0-9]+", "", `str(label)).lower();
    }

    type_table_by_file: dict[str, dict[str, str]] = {};
    for result in per_file {
        tt: any = result.get("ts_type_table");
        if tt and tt.get("path") {
            type_table_by_file[tt["path"]] = tt.get("table", {});
        }
    }
    ts_fields_by_id = {};
    n: any;
    for n in all_nodes {
        for (`static, attr) in ((False, "_ts_fields"), (True, "_ts_static_fields")) {
            for (fname, ftype) in (n.get(attr) or {}).items() {
                ts_fields_by_id.setdefault((`str(n.get("id")), `static), {}).setdefault(
                    fname, ftype
                );
            }
        }
    }
    if not type_table_by_file and not ts_fields_by_id {
        return;
    }

    contained: any = {e.get("target") for e in all_edges if e.get("relation") == "contains"};
    type_def_nids: dict[str, list[str]] = {};
    node_by_id = {};
    for n in all_nodes {
        node_by_id[n.get("id")] = n;
        if _lang_family(n.get("source_file")) == "jsts"
            and n.get("id") in contained
            and _is_type_like_definition(n)
        {
            type_def_nids.setdefault(_key(n.get("label", "")), []).append(n["id"]);
        }
    }

    method_index: dict[tuple[str, str], str] = {};
    method_exact: dict[tuple[str, str], str] = {};
    method_key_ambiguous: set[tuple[str, str]] = set[any]();
    class_of_method: dict[str, str] = {};
    for e in all_edges {
        if e.get("relation") != "method" {
            continue;
        }
        src: any;
        tgt: any;
        (src, tgt) = (e.get("source"), e.get("target"));
        tnode: any = node_by_id.get(tgt);
        if tnode is not None {
            key: any = (src, _key(tnode.get("label", "")));
            if method_index.get(key, tgt) != tgt {
                method_key_ambiguous.add(key);
            }
            method_index[key] = tgt;
            method_exact[src, `str(tnode.get("label", "")).removesuffix("()").removeprefix(
                "."
            )] = tgt;
        }
        if isinstance(src, `str) and isinstance(tgt, `str) {
            class_of_method[tgt] = src;
        }
    }
    file_of_node = {};
    for e in all_edges {
        if e.get("relation") == "contains" {
            file_of_node[e.get("target")] = e.get("source");
        }
    }
    for e in all_edges {
        if e.get("relation") == "method" {
            owner_file: any = file_of_node.get(e.get("source"));
            if owner_file is not None {
                file_of_node.setdefault(e.get("target"), owner_file);
            }
        }
    }
    imported_by_filenode: dict[str, set[str]] = {};
    for e in all_edges {
        if e.get("relation") in ("imports", "imports_from") {
            imported_by_filenode.setdefault(e.get("source"), set[any]()).add(e.get("target"));
        }
    }
    bases = {};
    for e in all_edges {
        if e.get("relation") == "inherits" {
            bases.setdefault(`str(e.get("source")), []).append(`str(e.get("target")));
        }
    }
    field_classes_by_key = {};
    for n in all_nodes {
        if (n.get("_ts_fields") or n.get("_ts_static_fields"))
            and n["id"] not in field_classes_by_key.get(_key(n.get("label", "")), [])
        {
            field_classes_by_key.setdefault(_key(n.get("label", "")), []).append(n["id"]);
        }
    }

    def _field_type(class_nid: str, field: str, `static: bool, depth: int = 0) -> tuple[str, str]
        | None {
        found: any = ts_fields_by_id.get((class_nid, `static), {}).get(field);
        if found {
            return (found, class_nid);
        }
        if depth >= 8 {
            return None;
        }
        for base in bases.get(class_nid, []) {
            base_nid: any = base if (base, `static) in ts_fields_by_id else None;
            if base_nid is None {
                same: any = field_classes_by_key.get(
                    _key(node_by_id.get(base, {}).get("label", "")), []
                );
                base_nid = same[0] if len(same) == 1 else None;
            }
            hit: any = _field_type(base_nid, field, `static, depth + 1) if base_nid else None;
            if hit {
                return hit;
            }
        }
        return None;
    }

    all_raw_calls: list[dict] = [];
    for result in per_file {
        all_raw_calls.extend(result.get("raw_calls", []));
    }

    existing_pairs: any = {(e.get("source"), e.get("target")) for e in all_edges};
    for rc in all_raw_calls {
        if not rc.get("is_member_call") {
            continue;
        }
        receiver: any = rc.get("receiver");
        callee: any = rc.get("callee");
        caller: any = rc.get("caller_nid");
        if not receiver or not callee or not caller {
            continue;
        }
        declaring_nid: str | None = None;
        if receiver[:1].isupper() {
            type_name: any = receiver;
            type_qualified: any = True;
        } else {
            type_qualified = False;
            type_name = None;
            owner_nid: any = class_of_method.get(caller) if rc.get("ts_this_field") else None;
            if owner_nid is not None {
                hit: any = _field_type(owner_nid, `str(receiver), `bool(rc.get("ts_static_this")));
                (type_name, declaring_nid) = (hit or (None, None)) as any;
            } else {
                type_name = type_table_by_file.get(rc.get("source_file", ""), {}).get(receiver);
            }
        }
        if not type_name {
            continue;
        }
        if type_name in _LANGUAGE_BUILTIN_GLOBALS {
            continue;
        }
        type_defs: any = type_def_nids.get(_key(type_name), []);
        if not type_defs {
            if not type_qualified and _lang_family(rc.get("source_file")) == "jsts" {
                _park_unresolved_member_call(
                    node_by_id.get(caller), callee, type_name, "typescript", rc
                );
            }
            continue;
        }
        caller_file = file_of_node.get(declaring_nid or caller);
        imported = imported_by_filenode.get(caller_file, set[any]());

        def _visible(nid: str) -> bool {
            type_file: any = file_of_node.get(nid);
            return caller_file is not None and operator.eq(caller_file, type_file)
                or nid in imported
                or type_file is not None and type_file in imported;
        }

        visible: any = [nid for nid in type_defs if _visible(nid)];
        if len(visible) != 1 {
            continue;
        }
        type_nid: any = visible[0];
        method_nid: any = method_exact.get((type_nid, `str(callee)));
        exact: any = method_nid is not None;
        if not exact and (type_nid, _key(callee)) not in method_key_ambiguous {
            method_nid = method_index.get((type_nid, _key(callee)));
        }
        if not method_nid {
            continue;
        }
        method_node: any = node_by_id.get(method_nid, {});
        if not exact
            and `str(method_node.get("label", "")).lstrip(".").startswith("#")
            and not `str(callee).startswith("#")
            and not method_node.get("_ts_public_twin")
        {
            continue;
        }
        if method_nid == caller or (caller, method_nid) in existing_pairs {
            continue;
        }
        existing_pairs.add((caller, method_nid));
        all_edges.append({
            "source": caller,
            "target": method_nid,
            "relation": "calls",
            "context": "call",
            "confidence": "EXTRACTED" if type_qualified else "INFERRED",
            "confidence_score": 1.0 if type_qualified else 0.85,
            "source_file": rc.get("source_file", ""),
            "source_location": rc.get("source_location"),
            "weight": 1.0,
        });
    }
}

impl _attach_cpp_out_of_line_methods(
    nodes: list[dict],
    edges: list[dict],
    raw_calls: list[dict],
    *,
    context_nodes: list[dict] | None = None,
    context_edges: list[dict] | None = None,
) {
    members: dict[str, set[str]];
    sf: any;
    by_id: any = {n["id"]: n for n in context_nodes or []};
    by_id.update({n["id"]: n for n in nodes});
    basenames: any = {`str(n["source_file"]): "" for n in by_id.values() if n.get("source_file")};
    basenames = {sf: Path(sf).name for sf in basenames};
    file_ids: any = {
        `str(n["source_file"]): n["id"]
        for n in by_id.values()
        if n.get("source_file") and n.get("label") == basenames[`str(n["source_file"])]
    };
    imports: dict[str, set[str]] = {};
    class_files: dict[str, str] = {};
    members = {};
    already_owned: any = set[any]();
    for `edge in edges + (context_edges or []) {
        source: any;
        target: any;
        (source, target) = (`edge.get("source"), `edge.get("target"));
        if not isinstance(source, `str) or not isinstance(target, `str) {
            continue;
        }
        if `edge.get("relation") == "imports" {
            imports.setdefault(source, set[any]()).add(target);
        } elif `edge.get("relation") == "contains"
            and by_id.get(target, {}).get("_callable_class")
        {
            class_files[target] = source;
        } elif `edge.get("relation") in {"method", "defines"} {
            label: any = `str(by_id.get(target, {}).get("label", ""));
            if label.startswith(".") and label.endswith("()") {
                members.setdefault(source, set[any]()).add(label[1:-2]);
                already_owned.add(target);
            }
        }
    }
    by_name: dict[str, list[str]] = {};
    for owner in members {
        identity: any = by_id.get(owner, {}).get("_cpp_qualified");
        if isinstance(identity, `str) and identity {
            by_name.setdefault(identity, []).append(owner);
        }
    }
    visible_members: dict[str, set[str]] = {};
    for `node in nodes {
        label = `str(`node.get("label", ""));
        sf = `str(`node.get("source_file", ""));
        if `node["id"] in already_owned
            or not label.endswith("()")
            or "::" not in label
            or Path(sf).suffix.lower() not in {
                ".cpp",
                ".cc",
                ".cxx",
                ".h",
                ".hpp",
                ".hh",
                ".hxx",
                ".cu",
            }
        {
            continue;
        }
        qualified: any = `node.get("_cpp_qualified");
        if not isinstance(qualified, `str) or "::" not in qualified {
            continue;
        }
        scope: any;
        method: any;
        (scope, method) = qualified.rsplit("::", 1) as any;
        own_file: any = file_ids.get(sf);
        if own_file is None {
            continue;
        }
        visible: any = imports.get(own_file, set[any]()) | {own_file};
        candidates: any = [
            owner
            for owner in by_name.get(scope, ())
            if method in members[owner] and class_files.get(owner) in visible
        ];
        if not candidates {
            continue;
        }
        visible_members[`node["id"]] = set[any]().union(*(members[c] for c in candidates));
        if len(candidates) == 1 {
            edges.append({
                "source": candidates[0],
                "target": `node["id"],
                "relation": "method",
                "confidence": "EXTRACTED",
                "source_file": sf,
                "source_location": `node.get("source_location"),
                "weight": 1.0,
            });
        }
    }
    for call in raw_calls {
        caller: any = call.get("caller_nid");
        if not isinstance(caller, `str) {
            continue;
        }
        if call.get("lang") == "cpp"
            and not call.get("is_member_call")
            and call.get("callee") in visible_members.get(caller, set[any]())
        {
            call["is_member_call"] = True;
            call["receiver"] = "this";
        }
    }
}

impl _resolve_cpp_member_calls(per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]) {
    result: any;
    node_by_id: dict[str, dict];
    enclosing_type: dict[str, str];
    e: any;
    type_lookup: any;
    type_table_by_file: dict[str, dict[str, str]] = {};
    for result in per_file {
        tt: any = result.get("cpp_type_table");
        if tt and tt.get("path") {
            type_table_by_file[tt["path"]] = tt.get("table", {});
        }
    }

    def _key(label: str) -> str {
        return re.sub("[^a-zA-Z0-9]+", "", `str(label)).lower();
    }
    contained: any = {e.get("target") for e in all_edges if e.get("relation") == "contains"};

    type_def_nids: dict[str, list[str]] = {};
    node_by_id = {};
    n: any;
    for n in all_nodes {
        node_by_id[n.get("id")] = n;
        if n.get("source_file") and n.get("id") in contained and _is_type_like_definition(n) {
            type_def_nids.setdefault(_key(n.get("label", "")), []).append(n["id"]);
        }
    }
    method_index: dict[tuple[str, str], str] = {};
    enclosing_type = {};
    rel: any;
    for rel in ("defines", "method") {
        for e in all_edges {
            if e.get("relation") != rel {
                continue;
            }
            src: any;
            tgt: any;
            (src, tgt) = (e.get("source"), e.get("target"));
            tnode: any = node_by_id.get(tgt);
            if tnode is None {
                continue;
            }
            enclosing_type.setdefault(tgt, src);
            method_index[src, _key(tnode.get("label", ""))] = tgt;
        }
    }
    qualified_method_nids: dict[str, list[str]] = {};
    for n in all_nodes {
        label: any = `str(n.get("label", ""));
        if n.get("source_file") and label.endswith("()") and "::" in label {
            qualified_method_nids.setdefault(label, []).append(n["id"]);
        }
    }
    exact_methods: dict[tuple[str, str], set[str]] = {};
    type_lookup = CppTypeLookup(all_nodes, all_edges);
    for rel in ("defines", "method") {
        grouped: dict[tuple[str, str], set[str]] = {};
        for e in all_edges {
            target_node: any = node_by_id.get(e.get("target", ""), {});
            label = target_node.get("label", "");
            if e.get("relation") == rel and label.endswith("()") {
                name: any = label.removesuffix("()").lstrip(".").rsplit("::", 1)[-1];
                grouped.setdefault((e["source"], name), set[any]()).add(e["target"]);
            }
        }
        exact_methods.update(grouped);
    }

    def resolve_chain(rc: dict) -> str | None {
        chain: any = rc["cpp_receiver_chain"];
        if not chain {
            return None;
        }
        root_name: any = chain[0][0];
        owner: any = enclosing_type.get(rc["caller_nid"], "");
        owner_node: any = node_by_id.get(owner, {});
        scope: any = owner_node.get("_cpp_qualified") or rc.get("cpp_receiver_scope", "");
        if root_name == "this" {
            name: any = owner_node.get("_cpp_qualified", "") + "*";
        } elif "cpp_receiver_type" in rc {
            name = rc["cpp_receiver_type"];
        } else {
            field_owner: any = type_lookup.member_owner(owner, root_name, "field")
                if owner
                else None;
            if not isinstance(field_owner, `str) {
                return None;
            }
            owner_node = node_by_id[field_owner];
            scope = owner_node.get("_cpp_qualified", "");
            name = owner_node.get("_cpp_fields", {}).get(root_name, "");
        }
        source: any = rc.get("source_file", "");
        use_source: any = source;
        use_position: any = rc.get("cpp_call_byte", 0);
        position: any = rc.get("cpp_receiver_byte", rc.get("cpp_call_byte", 0));
        if root_name != "this" and "cpp_receiver_type" not in rc {
            source = owner_node.get("source_file", source);
            position = owner_node.get("_cpp_field_positions", {}).get(root_name, position);
        }
        type_nid: any = "";
        for (index, (member, access_op)) in enumerate(chain) {
            if index {
                field_owner = type_lookup.member_owner(type_nid, member, "field");
                if not isinstance(field_owner, `str) {
                    return None;
                }
                owner_node = node_by_id[field_owner];
                name = owner_node.get("_cpp_fields", {}).get(member, "");
                scope = owner_node.get("_cpp_qualified", "");
                source = owner_node.get("source_file", source);
                position = owner_node.get("_cpp_field_positions", {}).get(member, 0);
            }
            type_nid = type_lookup.resolve(
                name,
                scope,
                source,
                position,
                access_op,
                use_source=use_source,
                use_position=use_position,
            );
            if type_nid is None {
                return None;
            }
        }
        return type_nid;
    }
    def chain_park_name(rc: dict) -> str | None {
        chain: any = rc["cpp_receiver_chain"];
        if len(chain) != 1 or "cpp_receiver_type" not in rc {
            return None;
        }
        name: any = re.sub("\\b(const|volatile)\\b", "", rc["cpp_receiver_type"]).strip();
        identifier: any = "(?:::)?[A-Za-z_]\\w*(?:::[A-Za-z_]\\w*)*";
        if chain[0][1] == "->" {
            smart: any = re.fullmatch(
                f"std::(?:unique_ptr|shared_ptr)\\s*<\\s*({identifier})\\s*>", name
            );
            if smart {
                name = smart[1];
            } elif name.endswith("*") {
                name = name[:-1].strip();
            } else {
                return None;
            }
        }
        name = name.removeprefix("::");
        return name if re.fullmatch("[A-Za-z_]\\w*", name) else None;
    }

    all_raw_calls: list[dict] = [];
    for result in per_file {
        all_raw_calls.extend(result.get("raw_calls", []));
    }

    existing_pairs: any = {(e.get("source"), e.get("target")) for e in all_edges};
    for rc in all_raw_calls {
        if not rc.get("is_member_call") {
            continue;
        }
        receiver: any = rc.get("receiver");
        callee: any = rc.get("callee");
        caller: any = rc.get("caller_nid");
        if not receiver or not callee or not caller {
            continue;
        }
        src_file: any = rc.get("source_file", "");
        if rc.get("lang") != "cpp" {
            continue;
        }
        qualified_fallback_label: str | None = None;
        if "cpp_receiver_chain" in rc {
            type_nid: any = resolve_chain(rc);
            if type_nid is None {
                park_name: any = chain_park_name(rc);
                owner: any = node_by_id.get(enclosing_type.get(caller, ""), {});
                alias: any = park_name is not None
                    and type_lookup.is_alias(
                        park_name,
                        owner.get("_cpp_qualified") or rc.get("cpp_receiver_scope", ""),
                        src_file,
                        rc.get("cpp_receiver_byte", rc.get("cpp_call_byte", 0)),
                    );
                if park_name is not None and not alias and not type_def_nids.get(_key(park_name)) {
                    _park_unresolved_member_call(
                        node_by_id.get(caller), callee, park_name, "cpp", rc
                    );
                }
                continue;
            }
            type_qualified: any = operator.eq(receiver, "this")
                and operator.eq(len(rc["cpp_receiver_chain"]), 1);
        } elif rc.get("cpp_scoped_call") {
            type_nid = type_lookup.resolve(
                receiver, rc.get("cpp_call_scope", ""), src_file, rc.get("cpp_call_byte", 0), "."
            );
            if type_nid is None {
                alias = type_lookup.is_alias(
                    receiver, rc.get("cpp_call_scope", ""), src_file, rc.get("cpp_call_byte", 0)
                );
                if receiver[:1].isupper() and not alias and not type_def_nids.get(_key(receiver)) {
                    _park_unresolved_member_call(
                        node_by_id.get(caller), callee, receiver, "cpp", rc
                    );
                }
                continue;
            }
            qualified_fallback_label = f"{receiver}::{callee}()";
            type_qualified = True;
        } elif receiver == "this" {
            type_nid = enclosing_type.get(caller);
            if not type_nid {
                continue;
            }
            type_qualified = True;
        } elif receiver[:1].isupper() {
            qualified_fallback_label = f"{receiver}::{callee}()";
            type_defs: any = type_def_nids.get(_key(receiver), []);
            if len(type_defs) == 1 {
                type_nid = type_defs[0];
                type_qualified = True;
            } else {
                type_name: any = type_table_by_file.get(src_file, {}).get(receiver);
                if not type_name {
                    if not type_defs {
                        _park_unresolved_member_call(
                            node_by_id.get(caller), callee, receiver, "cpp", rc
                        );
                    }
                    continue;
                }
                type_defs = type_def_nids.get(_key(type_name), []);
                if len(type_defs) != 1 {
                    continue;
                }
                type_nid = type_defs[0];
                type_qualified = False;
            }
        } else {
            type_name = type_table_by_file.get(src_file, {}).get(receiver);
            if not type_name {
                continue;
            }
            type_defs = type_def_nids.get(_key(type_name), []);
            if not type_defs {
                _park_unresolved_member_call(node_by_id.get(caller), callee, type_name, "cpp", rc);
                continue;
            }
            if len(type_defs) != 1 {
                continue;
            }
            type_nid = type_defs[0];
            type_qualified = False;
        }
        if "cpp_receiver_chain" in rc or rc.get("cpp_scoped_call") {
            methods: any = exact_methods.get((type_nid, callee), set[any]());
            method_nid: any = next(iter(methods)) if len(methods) == 1 else None;
        } else {
            methods = exact_methods.get((type_nid, callee), set[any]());
            method_nid = next(iter(methods))
                if len(methods) == 1
                else method_index.get((type_nid, _key(callee)));
        }
        if method_nid is None {
            inherited_owner: any = type_lookup.member_owner(type_nid, callee, "method");
            if isinstance(inherited_owner, `str) and inherited_owner != type_nid {
                methods = exact_methods.get((inherited_owner, callee), set[any]());
                method_nid = next(iter(methods)) if len(methods) == 1 else None;
            }
        }
        if method_nid is None and qualified_fallback_label is not None {
            candidates: any = qualified_method_nids.get(qualified_fallback_label, []);
            if len(candidates) == 1 {
                method_nid = candidates[0];
            }
        }
        target: any = method_nid or type_nid;
        relation: any = "calls" if method_nid else "references";
        if target == caller or (caller, target) in existing_pairs {
            continue;
        }
        existing_pairs.add((caller, target));
        all_edges.append({
            "source": caller,
            "target": target,
            "relation": relation,
            "context": "call",
            "confidence": "EXTRACTED" if type_qualified else "INFERRED",
            "confidence_score": 1.0 if type_qualified else 0.85,
            "source_file": src_file,
            "source_location": rc.get("source_location"),
            "weight": 1.0,
        });
        if isinstance(rc.get("metadata"), `dict) {
            all_edges[-1]["metadata"] = `dict(rc["metadata"]);
        }
    }
}

impl _csharp_keyword_type(name: str) -> str {
    name = name.removeprefix("global::");
    bare: any = name[len("System."):] if name.startswith("System.") else name;
    return _CSHARP_SYSTEM_TYPE_KEYWORDS.get(
        bare, bare if bare in _CSHARP_KEYWORD_TYPE_ALIASES else name
    );
}

impl _csharp_overload_index(nodes: list[dict], edges: list[dict]) -> dict {
    node_by_id: any = {n.get("id"): n for n in nodes};
    return {
        "node": node_by_id,
        "owner": {
            e.get("target"): e.get("source")
            for e in edges
            if e.get("relation") == "method"
                and "arity" in ((node_by_id.get(e.get("target")) or {}).get("metadata") or {})
                and not is_csharp_constructor_node(node_by_id.get(e.get("target")) or {})
                and not is_csharp_explicit_interface_node(node_by_id.get(e.get("target")) or {})
        },
    };
}

impl _csharp_collapse_overloads(candidates: list[str], argc: object, index: dict) -> list[str] {
    owner: any = index["owner"];
    groups: dict[tuple, list[str]] = {};
    for c in candidates {
        groups.setdefault((owner[c],) if c in owner else (None, c), []).append(c);
    }
    if len(groups) == len(candidates) {
        return candidates;
    }
    keep: set[str] = set[any]();
    for members in groups.values() {
        if len(members) == 1 {
            keep.add(members[0]);
            continue;
        }
        picked: any = _csharp_pick_overload(
            [index["node"][m] for m in members], argc if isinstance(argc, `int) else None
        );
        keep.add(picked["id"] if picked is not None else members[0]);
    }
    return [c for c in candidates if c in keep];
}

impl _resolve_csharp_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) {
    type_def_nids: dict[str, list[str]];
    node_by_id: dict[str, dict];
    resolver: any;
    method_index: dict[tuple[str, str], str];
    enclosing_type: dict[str, str];
    e: any;
    bases_of: dict[str, list[str]];
    unresolved_base: set[str];
    class_fields: any;
    type_nids: any;
    method_returns: any;
    result: any;
    field: any;
    def _key(label: str) -> str {
        return re.sub("\\W+", "", `str(label));
    }

    contained: any = {e.get("target") for e in all_edges if e.get("relation") == "contains"};

    type_def_nids = {};
    node_by_id = {};
    for n in all_nodes {
        node_by_id[n.get("id")] = n;
        if n.get("source_file") and n.get("id") in contained and _is_type_like_definition(n) {
            type_def_nids.setdefault(_key(n.get("label", "")), []).append(n["id"]);
        }
    }
    resolver = CsharpNameResolver(all_nodes, all_edges);
    method_index = {};
    method_peers: dict[tuple[str, str], list[dict]] = {};
    enclosing_type = {};
    for e in all_edges {
        if e.get("relation") == "defines" and e.get("context") == "field" {
            owner: any;
            member: any;
            (owner, member) = (e.get("source"), e.get("target"));
            if _is_cs_file(e.get("source_file"))
                and isinstance(owner, `str)
                and isinstance(member, `str)
            {
                enclosing_type.setdefault(member, owner);
            }
            continue;
        }
        if e.get("relation") != "method" {
            continue;
        }
        src: any;
        tgt: any;
        (src, tgt) = (e.get("source"), e.get("target"));
        tnode: any = node_by_id.get(tgt);
        if tnode is None {
            continue;
        }
        enclosing_type.setdefault(tgt, src);
        if is_csharp_constructor_node(tnode) {
            continue;
        }
        if is_csharp_explicit_interface_node(tnode) {
            continue;
        }
        if (tnode.get("metadata") or {}).get("kind") == "operator" {
            continue;
        }
        method_key: any = (src, _key(tnode.get("label", "")));
        method_index.setdefault(method_key, tgt);
        method_peers.setdefault(method_key, []).append(tnode);
    }
    bases_of = {};
    unresolved_base = set[any]();
    for e in all_edges {
        if e.get("relation") != "inherits" {
            continue;
        }
        src_file: any = e.get("source_file");
        if not _is_cs_file(src_file) {
            continue;
        }
        (src, tgt) = (e.get("source"), e.get("target"));
        if not (isinstance(src, `str) and isinstance(tgt, `str)) {
            continue;
        }
        tnode = node_by_id.get(tgt);
        if tnode is None or not tnode.get("source_file") {
            unresolved_base.add(src);
        } else {
            bucket: any = bases_of.setdefault(src, []);
            if tgt not in bucket {
                bucket.append(tgt);
            }
        }
    }
    def _method_on_type_or_bases(type_nid: str, callee_key: str) -> str | None {
        hits: set[str] = set[any]();
        seen: set[str] = set[any]();
        frontier: any = [type_nid];
        while frontier {
            nid: any = frontier.pop();
            if nid in seen {
                continue;
            }
            seen.add(nid);
            method_nid: any = method_index.get((nid, callee_key));
            if method_nid {
                hits.add(method_nid);
                continue;
            }
            if nid in unresolved_base {
                return None;
            }
            frontier.extend(bases_of.get(nid, []));
        }
        return next(iter(hits)) if len(hits) == 1 else None;
    }
    def _resolve_type_name_nid(
        type_name: str | None, caller_node: dict | None, src_file: str
    ) -> str | None {
        if not type_name {
            return None;
        }
        if caller_node is not None {
            resolved: any;
            decisive: any;
            (resolved, decisive) = resolver.resolve_type_name(
                type_name, caller_node, src_file
            ) as any;
            if resolved {
                return resolved;
            }
            if decisive {
                return None;
            }
        }
        type_defs: any = type_def_nids.get(_key(type_name), []);
        return type_defs[0] if len(type_defs) == 1 else None;
    }
    def _park_if_absent(type_name: str | None, caller_node: dict | None, rc: dict) {
        if type_name and not type_def_nids.get(_key(type_name)) {
            if `str(type_name).lower() in _CSHARP_WELL_KNOWN_TYPES {
                return;
            }
            _park_unresolved_member_call(caller_node, rc.get("callee"), type_name, "csharp", rc);
        }
    }
    class_fields = _bind_member_field_tables(per_file, all_nodes, lang="csharp");
    type_nids = {nid for nids in type_def_nids.values() for nid in nids};
    def _field_type_nid(type_nid: str, field: str) -> str | None {
        hits: set[tuple[str, str]] = set[any]();
        seen: set[str] = set[any]();
        frontier: any = [type_nid];
        while frontier {
            nid: any = frontier.pop();
            if nid in seen {
                continue;
            }
            seen.add(nid);
            fields: any = class_fields.get(nid, {});
            if field in fields {
                if field + "[]" in fields {
                    return None;
                }
                hits.add((nid, fields[field]));
                continue;
            }
            if nid in unresolved_base {
                return None;
            }
            frontier.extend(bases_of.get(nid, []));
        }
        if len(hits) != 1 {
            return None;
        }
        owner_nid: any;
        field_type: any;
        (owner_nid, field_type) = next(iter(hits)) as any;
        owner: any = node_by_id.get(owner_nid);
        return _resolve_type_name_nid(field_type, owner, (owner or {}).get("source_file", ""));
    }
    method_returns = _bind_member_field_tables(per_file, all_nodes, lang="csharp_returns");
    def _call_return_type_nid(
        call: list, caller: str, caller_node: dict | None, src_file: str
    ) -> str | None {
        recv: any;
        method: any;
        targs: any;
        (recv, method, targs) = call as any;
        if recv == "this" or not recv {
            owner: any = enclosing_type.get(caller) or (caller if caller in type_nids else None);
        } else {
            owner = _resolve_type_name_nid(recv, caller_node, src_file);
        }
        method_nid: any = _method_on_type_or_bases(owner, _key(method)) if owner else None;
        decl_type: any = enclosing_type.get(method_nid) if method_nid else None;
        decls: any = method_returns.get(decl_type, {}).get(method) if decl_type else None;
        if not isinstance(decls, `list) {
            return None;
        }
        if targs {
            decls = [d for d in decls if d[1] == len(targs)];
        }
        if len(decls) != 1 {
            return None;
        }
        ret: any = decls[0][0];
        if isinstance(ret, `str) and ret.startswith("#") {
            idx: any = `int(ret[1:]);
            ret = targs[idx] if idx < len(targs) else None;
            return _resolve_type_name_nid(ret, caller_node, src_file);
        }
        decl_node: any = node_by_id.get(decl_type or "");
        return _resolve_type_name_nid(ret, decl_node, (decl_node or {}).get("source_file", ""));
    }

    all_raw_calls: list[dict] = [];
    for result in per_file {
        all_raw_calls.extend(result.get("raw_calls", []));
    }

    existing_pairs: any = {(e.get("source"), e.get("target")) for e in all_edges};
    for rc in all_raw_calls {
        if rc.get("lang") != "csharp" or not rc.get("is_member_call") {
            continue;
        }
        receiver: any = rc.get("receiver");
        callee: any = rc.get("callee");
        caller: any = rc.get("caller_nid");
        chain: any = rc.get("receiver_chain") or [];
        if not (receiver or chain) or not callee or not caller {
            continue;
        }
        src_file = rc.get("source_file", "");
        caller_node: any = node_by_id.get(caller);
        if not receiver {
            type_nid: any = _resolve_type_name_nid(chain[0], caller_node, src_file);
            for field in chain[1:] {
                if not type_nid {
                    break;
                }
                type_nid = _field_type_nid(type_nid, field);
            }
            if not type_nid {
                continue;
            }
            type_qualified: any = False;
        } elif receiver == "this" {
            type_nid = enclosing_type.get(caller) or (caller if caller in type_nids else None);
            if not type_nid {
                continue;
            }
            type_qualified = True;
        } elif receiver == "base" {
            enclosing: any = enclosing_type.get(caller)
                or (caller if caller in type_nids else None);
            if not enclosing or enclosing in unresolved_base {
                continue;
            }
            bases: any = bases_of.get(enclosing, []);
            if len(bases) != 1 {
                continue;
            }
            type_nid = bases[0];
            type_qualified = True;
        } elif rc.get("receiver_var_chain") {
            var_chain: any = rc["receiver_var_chain"];
            type_nid = _resolve_type_name_nid(var_chain[0], caller_node, src_file);
            for field in var_chain[1:] {
                if not type_nid {
                    break;
                }
                type_nid = _field_type_nid(type_nid, field);
            }
            if not type_nid {
                continue;
            }
            type_qualified = False;
        } elif receiver[:1].isupper() {
            type_name: any = rc.get("receiver_type");
            type_nid = _resolve_type_name_nid(type_name, caller_node, src_file);
            if not type_nid {
                type_nid = _resolve_type_name_nid(receiver, caller_node, src_file);
                if not type_nid {
                    _park_if_absent(type_name or receiver, caller_node, rc);
                    continue;
                }
            }
            type_qualified = True;
        } elif rc.get("receiver_call") and not rc.get("receiver_type") {
            type_nid = _call_return_type_nid(rc["receiver_call"], caller, caller_node, src_file);
            if not type_nid {
                continue;
            }
            type_qualified = False;
        } elif rc.get("receiver_type") {
            type_name = rc["receiver_type"];
            type_nid = _resolve_type_name_nid(type_name, caller_node, src_file);
            if not type_nid {
                _park_if_absent(type_name, caller_node, rc);
                continue;
            }
            type_qualified = False;
        } elif rc.get("receiver_undeclared") {
            type_nid = _resolve_type_name_nid(receiver, caller_node, src_file);
            if not type_nid {
                continue;
            }
            type_qualified = True;
        } else {
            continue;
        }
        method_nid: any = _method_on_type_or_bases(type_nid, _key(callee));
        if not method_nid {
            continue;
        }
        peers: any = method_peers.get((enclosing_type.get(method_nid), _key(callee)), []);
        if len(peers) > 1 {
            picked: any = _csharp_pick_overload(peers, rc.get("arity"));
            if picked is not None {
                method_nid = picked["id"];
            }
        }
        if method_nid == caller or (caller, method_nid) in existing_pairs {
            continue;
        }
        existing_pairs.add((caller, method_nid));
        all_edges.append({
            "source": caller,
            "target": method_nid,
            "relation": "calls",
            "context": "call",
            "confidence": "EXTRACTED" if type_qualified else "INFERRED",
            "confidence_score": 1.0 if type_qualified else 0.85,
            "source_file": src_file,
            "source_location": rc.get("source_location"),
            "weight": 1.0,
        });
    }
}

impl _resolve_csharp_extension_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) {
    node_by_id: dict[str, dict];
    type_def_nids: dict[str, list[str]];
    n: any;
    resolver: any;
    method_index: dict[tuple[str, str], list[str]];
    e: any;
    supers: dict[str, set[str]];
    closure_cache: dict[str, tuple[set[str], bool]];
    result: any;
    callee: any;
    def _key(label: str) -> str {
        return re.sub("\\W+", "", `str(label));
    }

    node_by_id = {n.get("id"): n for n in all_nodes};
    contained: any = {e.get("target") for e in all_edges if e.get("relation") == "contains"};

    type_def_nids = {};
    for nid in contained {
        n = node_by_id.get(nid);
        if n is not None and _is_cs_file(n.get("source_file")) and _is_type_like_definition(n) {
            type_def_nids.setdefault(_key(n.get("label", "")), []).append(nid);
        }
    }

    resolver = CsharpNameResolver(all_nodes, all_edges);
    ext_by_name: dict[str, list[dict]] = {};
    method_owner: dict[str, str] = {};
    method_index = {};
    for e in all_edges {
        if e.get("relation") != "method" {
            continue;
        }
        owner: any;
        method_nid: any;
        (owner, method_nid) = (e.get("source"), e.get("target"));
        mnode: any = node_by_id.get(method_nid);
        if mnode is None or not _is_cs_file(mnode.get("source_file")) {
            continue;
        }
        method_owner.setdefault(method_nid, owner);
        method_index.setdefault((owner, _key(mnode.get("label", ""))), []).append(method_nid);
        meta: any = mnode.get("metadata") or {};
        arity: any = meta.get("arity");
        if not meta.get("extension") or not isinstance(arity, `int) {
            continue;
        }
        low: any = meta.get("min_arity");
        ext_by_name.setdefault(_key(mnode.get("label", "")), []).append({
            "method": method_nid,
            "extended": `str(meta.get("extended_type") or ""),
            "ext_arity": meta.get("extended_type_arity") or 0,
            "is_type_param": `bool(meta.get("extended_is_type_param")),
            "arity": arity,
            "low": low if isinstance(low, `int) else arity,
            "variadic": `bool(meta.get("variadic")),
            "namespace": `str(meta.get("namespace") or ""),
        });
    }
    if not ext_by_name {
        return;
    }
    ext_method_ids: any = {d["method"] for decls in ext_by_name.values() for d in decls};
    regular_method_names: any = {
        key
        for ((_owner, key), mids) in method_index.items()
        for mid in mids
        if mid not in ext_method_ids
    };
    supers = {};
    for e in all_edges {
        if e.get("relation") not in ("inherits", "implements") {
            continue;
        }
        if not _is_cs_file(e.get("source_file")) {
            continue;
        }
        src: any;
        tgt: any;
        (src, tgt) = (e.get("source"), e.get("target"));
        if isinstance(src, `str) and isinstance(tgt, `str) {
            supers.setdefault(src, set[any]()).add(tgt);
        }
    }

    closure_cache = {};

    def _closure(nid: str) -> tuple[set[str], bool] {
        cached: any = closure_cache.get(nid);
        if cached is not None {
            return cached;
        }
        out: set[str] = set[any]();
        unresolved: any = False;
        stack: any = [nid];
        while stack {
            cur: any = stack.pop();
            if cur in out {
                continue;
            }
            out.add(cur);
            for sup in supers.get(cur, ()) {
                snode: any = node_by_id.get(sup);
                if snode is None or not snode.get("source_file") {
                    unresolved = True;
                    continue;
                }
                stack.append(sup);
            }
        }
        closure_cache[nid] = (out, unresolved);
        return (out, unresolved);
    }
    def _resolve_type_nid(
        type_name: str | None, caller_node: dict | None, src_file: str
    ) -> tuple[str | None, bool] {
        if not type_name {
            return (None, False);
        }
        if caller_node is not None {
            resolved: any;
            decisive: any;
            (resolved, decisive) = resolver.resolve_type_name(
                type_name, caller_node, src_file
            ) as any;
            if resolved {
                return (resolved, True);
            }
            if decisive {
                if type_name.removeprefix("global::").startswith("System.")
                    and _csharp_keyword_type(type_name) in _CSHARP_KEYWORD_TYPE_ALIASES
                    and (
                        type_name.startswith("global::")
                        or "System" not in resolver.aliases_by_file.get(src_file, {})
                    )
                {
                    return (None, False);
                }
                return (None, True);
            }
        }
        hits: any = type_def_nids.get(_key(type_name), []);
        if len(hits) == 1 {
            return (hits[0], True);
        }
        return (None, `bool(hits));
    }
    def _same_type(extended: str, recv_name: str) -> bool {
        if _key(extended) == _key(recv_name) {
            return True;
        }
        if type_def_nids.get(_key(extended)) or type_def_nids.get(_key(recv_name)) {
            return False;
        }
        kw: any = _csharp_keyword_type(extended);
        return kw in _CSHARP_KEYWORD_TYPE_ALIASES
            and operator.eq(kw, _csharp_keyword_type(recv_name));
    }

    existing_pairs: any = {(e.get("source"), e.get("target")) for e in all_edges};
    for result in per_file {
        for rc in result.get("raw_calls") or [] {
            if rc.get("lang") != "csharp" or not rc.get("is_member_call") {
                continue;
            }
            caller: any = rc.get("caller_nid");
            callee = rc.get("callee");
            argc: any = rc.get("arity");
            receiver: any = rc.get("receiver");
            chain: any = rc.get("receiver_chain") or [];
            if not caller or not callee or not isinstance(argc, `int) {
                continue;
            }
            if receiver == "base" {
                continue;
            }
            src_file: any = `str(rc.get("source_file") or "");
            caller_node: any = node_by_id.get(caller);
            if caller_node is None {
                continue;
            }

            recv_name: any = rc.get("receiver_type");
            if not recv_name
                and len(chain) == 2
                and chain[1] == "Value"
                and _csharp_keyword_type(chain[0]) in _CSHARP_KEYWORD_VALUE_TYPES
                and not type_def_nids.get(_key(chain[0]))
            {
                chain = chain[:1];
            }
            if not recv_name and chain {
                if len(chain) > 1 {
                    continue;
                }
                recv_name = chain[0];
            }
            if not recv_name and receiver == "this" {
                owner = method_owner.get(caller);
                owner_node: any = node_by_id.get(owner) if owner else None;
                recv_name = (owner_node or {}).get("label");
            }

            candidates: any = ext_by_name.get(_key(callee));
            if not candidates {
                continue;
            }

            closure: set[str] = set[any]();
            if not recv_name {
                if receiver and not rc.get("receiver_type") and `str(receiver)[:1].isupper() {
                    continue;
                }
                roc: any = True;
            } else {
                recv_nid: any;
                decisive: any;
                (recv_nid, decisive) = _resolve_type_nid(recv_name, caller_node, src_file) as any;
                if recv_nid is None and decisive {
                    continue;
                }
                roc = recv_nid is None;
            }

            if not roc {
                unresolved: any;
                (closure, unresolved) = _closure(recv_nid) as any;
                if unresolved {
                    continue;
                }
                if `any(method_index.get((owner, _key(callee))) for owner in closure) {
                    continue;
                }
            } else {
                if callee in _CSHARP_BCL_MEMBER_NAMES {
                    continue;
                }
                if _key(callee) in regular_method_names {
                    continue;
                }
            }

            for visible in resolver.visible_namespaces(caller_node, src_file) {
                at_level: any = [d for d in candidates if d["namespace"] in visible];
                if at_level {
                    candidates = at_level;
                    break;
                }
            } else {
                continue;
            }

            if not recv_name {
                applicable: any = candidates;
            } else {
                exact: any = [
                    d
                    for d in candidates
                    if not d["is_type_param"] and _same_type(d["extended"], recv_name)
                ];
                inherited: any = [];
                if not roc {
                    inherited = [
                        d
                        for d in candidates
                        if not d["is_type_param"]
                            and _key(d["extended"]) in {
                                _key((node_by_id.get(c) or {}).get("label", ""))
                                for c in closure
                            }
                    ];
                }
                applicable = exact or inherited;
                if not applicable {
                    applicable = [
                        d
                        for d in candidates
                        if d["is_type_param"] or d["extended"].lower() in ("object", "dynamic")
                    ];
                }
            }
            if not applicable {
                continue;
            }

            fits: any = [
                d
                for d in applicable
                if d["low"] <= argc and (argc <= d["arity"] - 1 or d["variadic"])
            ];
            if len(fits) != 1 {
                continue;
            }

            method_nid = fits[0]["method"];
            if method_nid == caller or (caller, method_nid) in existing_pairs {
                continue;
            }
            existing_pairs.add((caller, method_nid));
            all_edges.append({
                "source": caller,
                "target": method_nid,
                "relation": "calls",
                "context": "call",
                "confidence": "INFERRED",
                "confidence_score": 0.75 if roc else 0.85,
                "source_file": src_file,
                "source_location": rc.get("source_location"),
                "weight": 1.0,
            });
        }
    }
}

impl _bind_member_field_tables(
    per_file: list[dict], all_nodes: list[dict], *, lang: str
) -> dict[str, dict[str, str]] {
    result: any;
    by_label: dict[str, list[dict]] = {};
    for n in all_nodes {
        if n.get("label") and n.get("source_file") {
            by_label.setdefault(`str(n["label"]), []).append(n);
        }
    }
    bound: dict[str, dict[str, str]] = {};
    for result in per_file {
        for `entry in result.get("member_field_tables") or [] {
            if not isinstance(`entry, `dict) or `entry.get("lang") != lang {
                continue;
            }
            label: any;
            fields: any;
            (label, fields) = (`entry.get("class_label"), `entry.get("fields"));
            if not label or not isinstance(fields, `dict) {
                continue;
            }
            candidates: any = by_label.get(`str(label), []);
            if `entry.get("type_path") {
                candidates = [
                    n
                    for n in candidates
                    if (n.get("metadata") or {}).get("type_path") == `entry["type_path"]
                        and (n.get("metadata") or {}).get("namespace", "")
                            == `entry.get("namespace", "")
                ];
            }
            if len(candidates) > 1 {
                sf: any = `str(`entry.get("source_file") or "");
                exact: any = [n for n in candidates if `str(n.get("source_file")) == sf];
                if len(exact) == 1 {
                    candidates = exact;
                } else {
                    base: any = os.path.basename(sf);
                    candidates = [
                        n
                        for n in candidates
                        if os.path.basename(`str(n.get("source_file"))) == base
                    ];
                }
            }
            if len(candidates) != 1 {
                continue;
            }
            merged: any = bound.setdefault(candidates[0]["id"], {});
            for (fname, tname) in fields.items() {
                if merged.get(fname) not in (None, tname) {
                    merged.pop(fname, None);
                } else {
                    merged[fname] = tname;
                }
            }
        }
    }
    return bound;
}

impl _resolve_php_member_calls(per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]) {
    `node: any;
    method_index: dict[tuple[str, str], set[str]];
    `edge: any;
    inherits_bases: dict[str, list[str]];
    used_traits: dict[str, list[str]];
    result: any;
    def key(label: str) -> str {
        return `str(label).strip().removeprefix(".").removesuffix("()").lower();
    }

    def class_key(name: str) -> str {
        return `str(name).strip().lstrip("\\").rsplit("\\", 1)[-1].lower();
    }

    contained: any = {
        `edge.get("target")
        for `edge in all_edges
        if `edge.get("relation") == "contains"
    };
    node_by_id: any = {`node.get("id"): `node for `node in all_nodes};

    type_def_nids: dict[str, list[str]] = {};
    for `node in all_nodes {
        if _lang_family(`node.get("source_file")) == "php"
            and `node.get("id") in contained
            and _is_type_like_definition(`node)
        {
            type_def_nids.setdefault(class_key(`node.get("label", "")), []).append(`node["id"]);
        }
    }

    method_index = {};
    enclosing_type: dict[str, str] = {};
    for `edge in all_edges {
        if `edge.get("relation") != "method" {
            continue;
        }
        owner: any;
        method: any;
        (owner, method) = (`edge.get("source"), `edge.get("target"));
        method_node: any = node_by_id.get(method);
        if method_node is None {
            continue;
        }
        enclosing_type.setdefault(method, owner);
        method_index.setdefault((owner, key(method_node.get("label", ""))), set[any]()).add(method);
    }

    inherits_bases = {};
    used_traits = {};
    for `edge in all_edges {
        if `edge.get("relation") == "inherits" {
            inherits_bases.setdefault(`edge["source"], []).append(`edge["target"]);
        } elif `edge.get("relation") == "mixes_in" {
            used_traits.setdefault(`edge["source"], []).append(`edge["target"]);
        }
    }

    type_table_by_file: dict[str, dict[str, str]] = {};
    for result in per_file {
        tt: any = result.get("php_type_table");
        if tt and tt.get("path") {
            type_table_by_file[`str(tt["path"])] = tt.get("table", {});
        }
    }

    def provided_by(type_nid: str, name: str) -> set[str] {
        level: any;
        seen: any;
        (level, seen) = ([type_nid], {type_nid});
        while level {
            found: set[str] = set[any]();
            for nid in level {
                found |= method_index.get((nid, name), set[any]());
            }
            if found {
                return found;
            }
            traits: any = [t for nid in level for t in used_traits.get(nid, []) if t not in seen];
            seen.update(traits);
            level = `list(dict.fromkeys(traits));
        }
        return set[any]();
    }

    def declared_from(type_nid: str, name: str) -> str | None {
        level: any;
        seen: any;
        (level, seen) = ([type_nid], {type_nid});
        while level {
            found: set[str] = set[any]();
            for nid in level {
                found |= provided_by(nid, name);
            }
            if found {
                return next(iter(found)) if len(found) == 1 else None;
            }
            bases: any = [
                base
                for nid in level
                for base in inherits_bases.get(nid, [])
                if base not in seen
            ];
            seen.update(bases);
            level = `list(dict.fromkeys(bases));
        }
        return None;
    }
    existing_sites: any = {
        (`edge.get("source"), `edge.get("target"), `edge.get("source_location"))
        for `edge in all_edges
    };
    for result in per_file {
        for raw_call in result.get("raw_calls", []) {
            if not raw_call.get("is_member_call") {
                continue;
            }
            if _lang_family(raw_call.get("source_file")) != "php" {
                continue;
            }
            receiver: any = raw_call.get("receiver");
            callee: any = raw_call.get("callee");
            caller: any = raw_call.get("caller_nid");
            if not receiver or not callee or not caller {
                continue;
            }

            inferred: any = False;
            receiver_lower: any = receiver.lower();
            if receiver_lower in ("self", "static") {
                type_nid: any = enclosing_type.get(caller);
                if not type_nid {
                    continue;
                }
            } elif receiver_lower == "parent" {
                bases: any = inherits_bases.get(enclosing_type.get(caller), []);
                if len(bases) != 1 {
                    continue;
                }
                type_nid = bases[0];
            } elif receiver_lower == "this" and not raw_call.get("php_scoped") {
                type_nid = enclosing_type.get(caller);
                if not type_nid {
                    continue;
                }
            } elif not raw_call.get("php_scoped") and not receiver.startswith("$") {
                typed: any = type_table_by_file.get(`str(raw_call.get("source_file", "")), {}).get(
                    receiver
                );
                if typed is None {
                    continue;
                }
                inferred = True;
                type_defs: any = type_def_nids.get(class_key(typed), []);
                if not type_defs {
                    _park_unresolved_member_call(
                        node_by_id.get(caller), callee, typed, "php", raw_call
                    );
                    continue;
                }
                if len(type_defs) != 1 {
                    continue;
                }
                type_nid = type_defs[0];
            } elif not receiver.startswith("$") {
                type_defs = type_def_nids.get(class_key(receiver), []);
                if not type_defs {
                    _park_unresolved_member_call(
                        node_by_id.get(caller), callee, receiver, "php", raw_call
                    );
                    continue;
                }
                if len(type_defs) != 1 {
                    continue;
                }
                type_nid = type_defs[0];
            } else {
                continue;
            }

            method_nid: any = declared_from(type_nid, key(callee));
            site: any = (caller, method_nid, raw_call.get("source_location"));
            if method_nid is None or method_nid == caller or site in existing_sites {
                continue;
            }
            existing_sites.add(site);
            all_edges.append({
                "source": caller,
                "target": method_nid,
                "relation": "calls",
                "context": "call",
                "confidence": "INFERRED" if inferred else "EXTRACTED",
                "confidence_score": 0.85 if inferred else 1.0,
                "source_file": raw_call.get("source_file", ""),
                "source_location": raw_call.get("source_location"),
                "weight": 1.0,
            });
        }
    }
}

impl _resolve_java_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) {
    node_by_id: any;
    type_def_nids: dict[str, list[str]];
    `node: any;
    method_index: dict[tuple[str, str], set[str]];
    enclosing_type: dict[str, str];
    `edge: any;
    existing_pairs: any;
    inherits_bases: dict[str, list[str]];
    supertypes: dict[str, list[str]];
    class_fields: any;
    static_fields: any;
    qualified_types: dict[str, list[str]];
    result: any;
    def key(label: str) -> str {
        return `str(label).strip().removeprefix(".").removesuffix("()");
    }

    contained: any = {
        `edge.get("target")
        for `edge in all_edges
        if `edge.get("relation") == "contains"
    };
    node_by_id = {`node.get("id"): `node for `node in all_nodes};

    type_def_nids = {};
    for `node in all_nodes {
        if `node.get("source_file")
            and `node.get("id") in contained
            and _is_type_like_definition(`node)
        {
            type_def_nids.setdefault(key(`node.get("label", "")), []).append(`node["id"]);
        }
    }

    method_index = {};
    enclosing_type = {};
    for `edge in all_edges {
        if `edge.get("relation") != "method" {
            continue;
        }
        owner: any;
        method: any;
        (owner, method) = (`edge.get("source"), `edge.get("target"));
        method_node: any = node_by_id.get(method);
        if method_node is None {
            continue;
        }
        enclosing_type.setdefault(method, owner);
        method_index.setdefault((owner, key(method_node.get("label", ""))), set[any]()).add(method);
    }
    def _one(hits: set[str] | list[str], argc: object) -> str | None {
        h: any;
        if len(hits) == 1 {
            return next(iter(hits));
        }
        owners: any = {enclosing_type.get(h) for h in hits};
        if len(owners) != 1 or not isinstance(argc, `int) {
            return None;
        }
        def _line(h: str) -> int {
            loc: any = `str((node_by_id.get(h) or {}).get("source_location") or "");
            return `int(loc[1:]) if loc[1:].isdigit() else 0;
        }

        fits: any = [];
        for h in hits {
            meta: any = (node_by_id.get(h) or {}).get("metadata") or {};
            arity: any = meta.get("arity");
            if isinstance(arity, `int)
                and meta.get("min_arity", arity) <= argc
                and (argc <= arity or meta.get("variadic"))
            {
                fits.append(h);
            }
        }
        if len(fits) == 1 {
            return fits[0];
        }
        return min(hits, key=lambda (h) -> any { (_line(h), h) });
    }

    existing_pairs = {(`edge.get("source"), `edge.get("target")) for `edge in all_edges};
    inherits_bases = {};
    supertypes = {};
    for `edge in all_edges {
        if `edge.get("relation") == "inherits" {
            inherits_bases.setdefault(`edge["source"], []).append(`edge["target"]);
        }
        if `edge.get("relation") in ("inherits", "implements") {
            supertypes.setdefault(`edge["source"], []).append(`edge["target"]);
        }
    }
    class_fields = _bind_member_field_tables(per_file, all_nodes, lang="java");
    static_fields = _bind_member_field_tables(per_file, all_nodes, lang="java_static");
    qualified_types = {};
    for `node in all_nodes {
        identity: any = `node.get("_java_type");
        if not isinstance(identity, `dict) or `node.get("id") not in contained {
            continue;
        }
        qualified: any = ".".join(
            part for part in (identity.get("package"), identity.get("path")) if part
        );
        qualified_types.setdefault(qualified, []).append(`node["id"]);
    }

    bases_default_: any = inherits_bases;

    def _inherited_field_type(
        class_nid: str | None,
        field: str,
        bases: dict[str, list[str]] = bases_default_,
        tables: dict[str, dict[str, str]] | None = None,
    ) -> tuple[str, str] | None {
        fields: any = class_fields if tables is None else tables;
        seen: set = set[any]();
        queue: any = [class_nid];
        while queue {
            cls: any = queue.pop(0);
            if not cls or cls in seen {
                continue;
            }
            seen.add(cls);
            hit: any = fields.get(cls, {}).get(field);
            if hit {
                return (hit, cls);
            }
            queue.extend(bases.get(cls, []));
        }
        return None;
    }

    def _inherited_method(class_nid: str, callee_key: str, argc: object = None) -> str | None {
        seen: any;
        seen = {class_nid};
        chain: list[str] = [];
        cls: any = class_nid;
        while len(parents := [b for b in inherits_bases.get(cls, []) if b not in seen]) == 1 {
            cls = parents[0];
            seen.add(cls);
            chain.append(cls);
        }
        nid: any;
        for nid in chain {
            source_file: any = node_by_id.get(nid, {}).get("source_file");
            if source_file and _lang_family(source_file) != "jvm" {
                return None;
            }
            declared: any = method_index.get((nid, callee_key));
            if declared {
                return _one(declared, argc);
            }
        }
        level: any = `list(
            dict.fromkeys(
                base
                for nid in [class_nid, *chain]
                for base in supertypes.get(nid, [])
                if base not in seen,
            ),
        );
        while level {
            hits: set[str] = set[any]();
            for nid in level {
                seen.add(nid);
                source_file = node_by_id.get(nid, {}).get("source_file");
                if source_file and _lang_family(source_file) != "jvm" {
                    return None;
                }
                hits |= method_index.get((nid, callee_key), set[any]());
            }
            if hits {
                return _one(hits, argc);
            }
            level = `list(
                dict.fromkeys(
                    base for nid in level for base in supertypes.get(nid, []) if base not in seen
                ),
            );
        }
        return None;
    }

    def _emit(caller: str, method_nid: str, raw_call: dict, exact: bool) {
        existing_pairs.add((caller, method_nid));
        all_edges.append({
            "source": caller,
            "target": method_nid,
            "relation": "calls",
            "context": "call",
            "confidence": "EXTRACTED" if exact else "INFERRED",
            "confidence_score": 1.0 if exact else 0.85,
            "source_file": raw_call.get("source_file", ""),
            "source_location": raw_call.get("source_location"),
            "weight": 1.0,
        });
    }

    def _jvm_bases(type_nid: str) -> list[str] | None {
        bases: any = inherits_bases.get(type_nid, []);
        for base in bases {
            family: any = _lang_family(node_by_id.get(base, {}).get("source_file"));
            if base == type_nid or family != "jvm" {
                return None;
            }
        }
        return bases;
    }

    def _method_on_type_or_bases(type_nid: str, callee_key: str, argc: object = None) -> str
        | None {
        hits: set[str] = set[any]();
        seen: set[str] = set[any]();
        frontier: any = [type_nid];
        while frontier {
            nid: any = frontier.pop();
            if nid in seen {
                continue;
            }
            seen.add(nid);
            declared: any = method_index.get((nid, callee_key));
            if declared {
                hits |= declared;
                continue;
            }
            bases: any = _jvm_bases(nid);
            if bases is None {
                return None;
            }
            frontier.extend(bases);
        }
        return _one(hits, argc);
    }

    def _type_named(name: str, near: str | None) -> str | None {
        name = key(name);
        owner: any = enclosing_type.get(near or "", near);
        context: any = node_by_id.get(owner, {}).get("_java_type", {});
        package: any = context.get("package", "");

        def lookup(qualified: str) -> list[str] {
            return qualified_types.get(qualified, []);
        }

        def unique(defs: list[str] | set[str]) -> str | None {
            return next(iter(defs)) if len(defs) == 1 else None;
        }

        first: any;
        dot: any;
        rest: any;
        (first, dot, rest) = name.partition(".") as any;

        def member_types(scope: str, member: str) -> set[str] {
            hits: set[str] = set[any]();
            seen: set[str] = set[any]();
            frontier: any = [scope];
            while frontier {
                nid: any = frontier.pop();
                if nid in seen {
                    continue;
                }
                seen.add(nid);
                identity: any = node_by_id.get(nid, {}).get("_java_type", {});
                if not identity {
                    continue;
                }
                qualified: any = ".".join(
                    part for part in (identity.get("package"), identity.get("path"), member) if part
                );
                declared: any = lookup(qualified);
                if declared {
                    hits.update(declared);
                } else {
                    frontier.extend(supertypes.get(nid, []));
                }
            }
            return hits;
        }

        def nested_type(defs: list[str] | set[str], suffix: str) -> str | None {
            target: any = unique(defs);
            for member in suffix.split(".") if suffix else [] {
                if target is None {
                    return None;
                }
                target = unique(member_types(target, member));
            }
            return target;
        }

        path: any = context.get("path", "");
        while path {
            scope_name: any = ".".join(part for part in (package, path) if part);
            scopes: any = lookup(scope_name);
            if path.rsplit(".", 1)[-1] == first {
                return nested_type(scopes, rest);
            }
            members: any = {nid for scope in scopes for nid in member_types(scope, first)};
            if members {
                return nested_type(members, rest);
            }
            path = path.rpartition(".")[0];
        }
        imports: any = context.get("imports", []);
        explicit: any = [
            imported
            for imported in imports
            if not imported.endswith(".*") and imported.rsplit(".", 1)[-1] == first
        ];
        if explicit {
            imported_hits: any = {nid for imported in explicit for nid in lookup(imported)};
            return nested_type(imported_hits, rest);
        }
        for qualified in dict.fromkeys((".".join(part for part in (package, name) if part), name)) {
            parts: any = qualified.split(".");
            for length in range(1, len(parts) + 1) {
                if hits := lookup(".".join(parts[:length])) {
                    return nested_type(hits, ".".join(parts[length:]));
                }
            }
        }
        wildcard_hits: any = {
            nid
            for imported in imports
            if imported.endswith(".*")
            for nid in lookup(imported[:-1] + first)
        };
        if wildcard_hits {
            return nested_type(wildcard_hits, rest);
        }
        if dot or imports {
            return None;
        }
        defs: any = type_def_nids.get(name, []);
        return unique(defs);
    }

    def _chain_type(chain: list, caller: str, depth: int = 0) -> str | None {
        kind: any = chain[0] if chain and depth <= 16 else None;
        if kind == "type" {
            return _type_named(chain[1], caller);
        }
        if kind == "field_type" {
            declared: any = _inherited_field_type(enclosing_type.get(caller), chain[1], supertypes);
            return _type_named(*declared) if declared else None;
        }
        if kind == "this" {
            return enclosing_type.get(caller);
        }
        if kind == "super" {
            bases: any = _jvm_bases(enclosing_type.get(caller, ""));
            return bases[0] if bases and len(bases) == 1 else None;
        }
        if kind == "call" {
            owner: any = enclosing_type.get(caller)
                if chain[2] is None
                else _chain_type(chain[2], caller, depth + 1);
            method_nid: any = _method_on_type_or_bases(
                owner, key(chain[1]), chain[3] if len(chain) > 3 else None
            )
                if owner
                else None;
            returned: any = node_by_id.get(method_nid or "", {}).get("_java_ret");
            return _type_named(returned, method_nid) if returned else None;
        }
        if kind == "field" {
            owner = _chain_type(chain[2], caller, depth + 1);
            declared = _inherited_field_type(owner, chain[1], tables=static_fields)
                if owner
                else None;
            return _type_named(*declared) if declared else None;
        }
        return None;
    }

    for result in per_file {
        for raw_call in result.get("raw_calls", []) {
            if raw_call.get("lang") != "java" {
                continue;
            }
            receiver: any = raw_call.get("receiver");
            callee: any = raw_call.get("callee");
            caller: any = raw_call.get("caller_nid");
            if not raw_call.get("is_member_call") {
                class_nid: any = enclosing_type.get(caller);
                method_nid: any = _inherited_method(class_nid, key(callee), raw_call.get("arity"))
                    if class_nid and callee
                    else None;
                owner = node_by_id.get(enclosing_type.get(method_nid or ""), {});
                if method_nid
                    and method_nid != caller
                    and key(owner.get("label", "")) != key(callee)
                    and (caller, method_nid) not in existing_pairs
                {
                    _emit(caller, method_nid, raw_call, True);
                }
                continue;
            }
            chain: any = raw_call.get("java_receiver_chain");
            if chain and not receiver and callee and caller {
                type_nid: any = _chain_type(chain, caller);
                method_nid = _method_on_type_or_bases(type_nid, key(callee), raw_call.get("arity"))
                    if type_nid
                    else None;
                if method_nid
                    and method_nid != caller
                    and (caller, method_nid) not in existing_pairs
                {
                    existing_pairs.add((caller, method_nid));
                    all_edges.append({
                        "source": caller,
                        "target": method_nid,
                        "relation": "calls",
                        "context": "call",
                        "confidence": "INFERRED",
                        "confidence_score": 0.85,
                        "source_file": raw_call.get("source_file", ""),
                        "source_location": raw_call.get("source_location"),
                        "weight": 1.0,
                    });
                }
                continue;
            }
            if not receiver or not callee or not caller {
                continue;
            }

            exact: any = False;
            if receiver == "this" {
                type_nid = enclosing_type.get(caller);
                exact = True;
                if not type_nid {
                    continue;
                }
            } elif receiver == "super" {
                superclasses: any = _jvm_bases(enclosing_type.get(caller, ""));
                if not superclasses or len(superclasses) != 1 {
                    continue;
                }
                type_nid = superclasses[0];
                exact = True;
            } else {
                type_name: any = raw_call.get("receiver_type");
                type_context: any = caller;
                if field_name := raw_call.get("receiver_field") {
                    declared: any = _inherited_field_type(
                        enclosing_type.get(caller), field_name, supertypes
                    );
                    if not declared {
                        continue;
                    }
                    (type_name, type_context) = declared as any;
                }
                if not type_name and raw_call.get("receiver_unbound") {
                    declared = _inherited_field_type(
                        enclosing_type.get(caller), receiver, supertypes
                    );
                    if declared {
                        (type_name, type_context) = declared as any;
                    }
                }
                if not type_name and receiver[:1].isupper() {
                    type_name = receiver;
                    exact = True;
                }
                if not type_name and receiver.startswith("this.") {
                    declared = _inherited_field_type(
                        enclosing_type.get(caller), receiver[len("this."):]
                    );
                    if declared {
                        (type_name, type_context) = declared as any;
                    }
                }
                if not type_name {
                    continue;
                }
                type_nid = _type_named(type_name, type_context);
                if not type_nid and not type_def_nids.get(key(type_name.rsplit(".", 1)[-1])) {
                    _park_unresolved_member_call(
                        node_by_id.get(caller), callee, type_name, "java", raw_call
                    );
                    continue;
                }
                if not type_nid {
                    continue;
                }
            }

            method_nid = _method_on_type_or_bases(type_nid, key(callee), raw_call.get("arity"));
            if not method_nid or method_nid == caller or (caller, method_nid) in existing_pairs {
                continue;
            }
            _emit(caller, method_nid, raw_call, exact);
        }
    }
}

impl _resolve_objc_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) {
    result: any;
    field_types_by_class: dict[str, dict[str, str]];
    field: any;
    node_by_id: dict[str, dict];
    method_index: dict[tuple[str, str], str];
    e: any;
    _objc_bases: dict[str, list[str]];
    type_table_by_file: dict[str, dict[str, str]] = {};
    for result in per_file {
        tt: any = result.get("objc_type_table");
        if tt and tt.get("path") {
            type_table_by_file[tt["path"]] = tt.get("table", {});
        }
    }
    field_types_by_class = {};
    field_conflicts: set[tuple[str, str]] = set[any]();
    for result in per_file {
        ft: any = result.get("objc_field_types");
        if not ft {
            continue;
        }
        for (cls_nid, tbl) in (ft.get("tables") or {}).items() {
            merged: any = field_types_by_class.setdefault(cls_nid, {});
            for (field, tname) in tbl.items() {
                if (cls_nid, field) in field_conflicts {
                    continue;
                }
                prev: any = merged.get(field);
                if prev is None {
                    merged[field] = tname;
                } elif prev != tname {
                    del merged[field];
                    field_conflicts.add((cls_nid, field));
                }
            }
        }
    }

    def _key(label: str) -> str {
        return re.sub("[^a-zA-Z0-9]+", "", `str(label)).lower();
    }

    contained: any = {e.get("target") for e in all_edges if e.get("relation") == "contains"};
    def _is_protocol_declaration(n: dict) -> bool {
        label: any = `str(n.get("label", "")).strip();
        return label.startswith("<") and label.endswith(">");
    }

    type_def_nids: dict[str, list[str]] = {};
    node_by_id = {};
    for n in all_nodes {
        node_by_id[n.get("id")] = n;
        if n.get("source_file")
            and n.get("id") in contained
            and _is_type_like_definition(n)
            and not _is_protocol_declaration(n)
        {
            type_def_nids.setdefault(_key(n.get("label", "")), []).append(n["id"]);
        }
    }

    method_index = {};
    enclosing_type: dict[str, str] = {};
    for e in all_edges {
        if e.get("relation") != "method" {
            continue;
        }
        src: any;
        tgt: any;
        (src, tgt) = (e.get("source"), e.get("target"));
        enclosing_type.setdefault(tgt, src);
        tnode: any = node_by_id.get(tgt);
        if tnode is not None {
            method_index[src, _key(tnode.get("label", ""))] = tgt;
        }
    }

    all_raw_calls: list[dict] = [];
    for result in per_file {
        all_raw_calls.extend(result.get("raw_calls", []));
    }

    existing_pairs: any = {(e.get("source"), e.get("target")) for e in all_edges};
    _objc_bases = {};
    for e in all_edges {
        if e.get("relation") == "inherits" {
            _objc_bases.setdefault(e["source"], []).append(e["target"]);
        }
    }

    def _field_type_up_chain(cls, receiver) -> any {
        seen: set = set[any]();
        queue: any = [cls];
        while queue {
            c: any = queue.pop(0);
            if not c or c in seen {
                continue;
            }
            seen.add(c);
            hit: any = field_types_by_class.get(c, {}).get(receiver);
            if hit {
                return hit;
            }
            queue.extend(_objc_bases.get(c, []));
        }
        return None;
    }
    def _park_absent(caller: str, callee: str, type_name: str, rc: dict) {
        if type_name in _LANGUAGE_BUILTIN_GLOBALS {
            return;
        }
        _park_unresolved_member_call(node_by_id.get(caller), callee, type_name, "objc", rc);
    }
    def _defines_selector(n: dict | None) -> bool {
        if not n {
            return False;
        }
        if n.get("definition_file") {
            return True;
        }
        return Path(`str(n.get("source_file", ""))).suffix.lower() in (".m", ".mm");
    }
    def _resolve_member_target(type_defs: list[str], callee: str) -> any {
        m: any;
        ck: any = _key(callee);
        if len(type_defs) == 1 {
            mnid: any = method_index.get((type_defs[0], ck));
            return (mnid, "calls") if mnid else (type_defs[0], "references");
        }
        defs: any = {
            m
            for t in type_defs
            if (m := method_index.get((t, ck))) is not None and _defines_selector(node_by_id.get(m))
        };
        if len(defs) == 1 {
            return (next(iter(defs)), "calls");
        }
        return (None, None);
    }

    for rc in all_raw_calls {
        if not rc.get("is_member_call") {
            continue;
        }
        receiver: any = rc.get("receiver");
        callee: any = rc.get("callee");
        caller: any = rc.get("caller_nid");
        if not receiver or not callee or not caller {
            continue;
        }
        src_file: any = rc.get("source_file", "");
        if rc.get("lang") != "objc" {
            continue;
        }
        if rc.get("receiver_kind") == "self_field" {
            cls: any = enclosing_type.get(caller);
            type_name: any = _field_type_up_chain(cls, receiver) if cls else None;
            if not type_name {
                continue;
            }
            type_defs: any = type_def_nids.get(_key(type_name), []);
            if not type_defs {
                _park_absent(caller, callee, type_name, rc);
                continue;
            }
            type_qualified: any = False;
        } elif receiver in ("self", "super") {
            enc: any = enclosing_type.get(caller);
            if not enc {
                continue;
            }
            type_defs = [enc];
            type_qualified = True;
        } elif receiver[:1].isupper() {
            type_defs = type_def_nids.get(_key(receiver), []);
            if not type_defs {
                _park_absent(caller, callee, receiver, rc);
                continue;
            }
            type_qualified = True;
        } else {
            type_name = type_table_by_file.get(src_file, {}).get(receiver);
            if not type_name {
                cls = enclosing_type.get(caller);
                type_name = _field_type_up_chain(cls, receiver) if cls else None;
            }
            if not type_name {
                continue;
            }
            type_defs = type_def_nids.get(_key(type_name), []);
            if not type_defs {
                _park_absent(caller, callee, type_name, rc);
                continue;
            }
            type_qualified = False;
        }
        target: any;
        relation: any;
        (target, relation) = _resolve_member_target(type_defs, callee) as any;
        if target is None {
            continue;
        }
        if target == caller or (caller, target) in existing_pairs {
            continue;
        }
        existing_pairs.add((caller, target));
        all_edges.append({
            "source": caller,
            "target": target,
            "relation": relation,
            "context": "call",
            "confidence": "EXTRACTED" if type_qualified else "INFERRED",
            "confidence_score": 1.0 if type_qualified else 0.85,
            "source_file": src_file,
            "source_location": rc.get("source_location"),
            "weight": 1.0,
        });
    }
}

impl _kotlin_package_index(per_file: list[dict]) -> dict[str, list[dict]] {
    result: any;
    pkg_results: dict[str, list[dict]] = {};
    for result in per_file {
        pkg: any = result.get("kotlin_package");
        if pkg {
            pkg_results.setdefault(pkg, []).append(result);
        }
    }
    return pkg_results;
}

impl _jvm_package_name(path: Path, result: dict) -> tuple[str, str] | None {
    suffix: any = effective_suffix(path).lower();
    if suffix in (".kt", ".kts") {
        source_file: any = next(
            (n.get("source_file") for n in result.get("nodes", []) if n.get("source_file")),
            `str(path),
        );
        return (`str(source_file), `str(result.get("kotlin_package") or ""));
    }
    if suffix != ".java" {
        return None;
    }
    source_file = next(
        (n.get("source_file") for n in result.get("nodes", []) if n.get("source_file")), `str(path)
    );
    try {
        text: any = _read_source_text(path, warn=False);
    } except OSError {
        text = "";
    }
    `match: any = re.search("(?m)^\\s*package\\s+([\\w.]+)\\s*;", text);
    return (`str(source_file), `match.group(1) if `match else "");
}

impl _jvm_imports_by_file(path: Path, result: dict) -> dict[str, str] {
    imports: dict[str, str] = {};
    suffix: any = effective_suffix(path).lower();
    if suffix in (".kt", ".kts") {
        for `edge in result.get("edges", []) {
            if `edge.get("relation") != "imports" {
                continue;
            }
            md: any = `edge.get("metadata") or {};
            fqn: any = md.get("target_fqn");
            if fqn {
                imports[`str(fqn).split(".")[-1]] = `str(fqn);
            }
        }
        return imports;
    }
    if suffix != ".java" {
        return imports;
    }
    try {
        text: any = _read_source_text(path, warn=False);
    } except OSError {
        return imports;
    }
    for `match in _JAVA_IMPORT_RE.finditer(text) {
        body: any = `match.group(1).strip();
        if body.endswith(".*") or "." not in body {
            continue;
        }
        simple: any = body.split(".")[-1];
        if simple and simple[0].isupper() {
            imports[simple] = body;
        }
    }
    return imports;
}

impl _resolve_jvm_references(
    per_file: list[dict], paths: list[Path], all_nodes: list[dict], all_edges: list[dict]
) {
    result: any;
    by_fqn: dict[str, list[str]] = {};
    pkg_by_file: dict[str, str] = {};
    imports_by_file: dict[str, dict[str, str]] = {};

    for (path, result) in zip(paths, per_file) {
        package_entry: any = _jvm_package_name(path, result);
        if package_entry is None {
            continue;
        }
        source_file: any;
        package: any;
        (source_file, package) = package_entry as any;
        pkg_by_file[source_file] = package;
        imports_by_file[source_file] = _jvm_imports_by_file(path, result);
        for `node in result.get("nodes", []) {
            node_source: any = `str(`node.get("source_file") or "");
            if node_source != source_file {
                continue;
            }
            if not _is_type_like_definition(`node) {
                continue;
            }
            label: any = `str(`node.get("label", "")).strip();
            if not label {
                continue;
            }
            fqn: any = f"{package}.{label}" if package else label;
            by_fqn.setdefault(fqn, []).append(`str(`node["id"]));
        }
    }

    if not by_fqn {
        return;
    }

    node_by_id: any = {`str(n.get("id")): n for n in all_nodes if n.get("id")};
    repoint: any = {"imports", "inherits", "extends", "implements", "references"};
    for `edge in all_edges {
        if `edge.get("relation") not in repoint {
            continue;
        }
        source_file = `str(`edge.get("source_file") or "");
        if effective_suffix(source_file).lower() not in _JVM_NAME_SUFFIXES {
            continue;
        }
        target: any = `str(`edge.get("target") or "");
        if not target {
            continue;
        }
        target_node: any = node_by_id.get(target) or {};
        fqn = `str((`edge.get("metadata") or {}).get("target_fqn") or "");
        simple: any = "";
        if not fqn {
            label = `str(target_node.get("label") or "");
            if target_node and not target_node.get("source_file") and "." in label {
                fqn = label;
            } elif label and not target_node.get("source_file") {
                simple = label;
            } else {
                for name in imports_by_file.get(source_file, {}) {
                    if _make_id(name) == target {
                        simple = name;
                        break;
                    }
                }
            }
            if not fqn and simple {
                fqn = imports_by_file.get(source_file, {}).get(simple, "");
                if not fqn {
                    package = pkg_by_file.get(source_file, "");
                    fqn = f"{package}.{simple}" if package else simple;
                }
            }
        }
        if not fqn {
            continue;
        }
        candidates: any = by_fqn.get(fqn, []);
        if len(candidates) != 1 {
            continue;
        }
        candidate: any = candidates[0];
        if candidate == target {
            continue;
        }
        if `edge.get("relation") == "imports" and not target_node {
            resolved: any = `dict(`edge);
            resolved["target"] = candidate;
            all_edges.append(resolved);
        } else {
            `edge["target"] = candidate;
        }
    }
}

impl _resolve_kotlin_import_targets(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) {
    result: any;
    pkg_results: any = _kotlin_package_index(per_file);
    pkg_symbols: dict[str, dict[str, set[str]]] = {};
    pkg: any;
    for (pkg, results) in pkg_results.items() {
        by_label: any = pkg_symbols.setdefault(pkg, {});
        for result in results {
            for n in result.get("nodes", []) {
                if not n.get("source_file") or n.get("type") == "namespace" {
                    continue;
                }
                label: any = `str(n.get("label", ""));
                if not label or label.startswith(".") {
                    continue;
                }
                by_label.setdefault(label.strip("()"), set[any]()).add(n["id"]);
            }
        }
    }
    for `node in all_nodes {
        if not `str(`node.get("source_file", "")).endswith((".kt", ".kts")) {
            continue;
        }
        metadata: any = `node.get("metadata") or {};
        package: any = metadata.get("namespace");
        label = `str(`node.get("label", ""));
        if package and label and not label.startswith(".") and `node.get("type") != "namespace" {
            pkg_symbols.setdefault(package, {}).setdefault(
                metadata.get("type_path", label.strip("()")), set[any]()
            ).add(`node["id"]);
        }
    }
    for e in all_edges {
        if e.get("relation") != "imports" {
            continue;
        }
        if not `str(e.get("source_file", "")).endswith((".kt", ".kts")) {
            continue;
        }
        fqn: any = (e.get("metadata") or {}).get("target_fqn", "");
        _: any;
        name: any;
        (pkg, _, name) = `str(fqn).rpartition(".") as any;
        if not pkg or not name {
            continue;
        }
        candidates: any = pkg_symbols.get(pkg, {}).get(name, set[any]());
        if len(candidates) == 1 {
            e["target"] = next(iter(candidates));
        }
    }
}

impl _resolve_c_include_edges(
    edges: list[dict], resolution_nodes: list[dict], `root: Path | None = None
) {
    `node: any;
    if not edges or not resolution_nodes {
        return;
    }

    headers_by_basename: dict[str, list[tuple[dict, str]]] = {};
    headers_by_basename_ci: dict[str, list[tuple[dict, str]]] = {};

    for n in resolution_nodes {
        if n.get("type") == "namespace" or n.get("file_type") == "rationale" {
            continue;
        }
        sf: any = n.get("source_file");
        if not sf {
            continue;
        }
        sf_str: any = `str(sf);
        sf_p: any = Path(sf_str);
        if sf_p.suffix.lower() not in _C_FAMILY_HEADER_EXTS {
            continue;
        }
        if n.get("label") != sf_p.name {
            continue;
        }
        if not n.get("id") {
            continue;
        }

        sf_key: any = _source_key(sf_str, `root) if `root else sf_str;
        cand_path: any = sf_key.replace("\\", "/").rstrip("/");
        basename: any = cand_path.split("/")[-1];

        headers_by_basename.setdefault(basename, []).append((n, cand_path));
        headers_by_basename_ci.setdefault(basename.lower(), []).append((n, cand_path));
    }

    if not headers_by_basename {
        return;
    }

    def _shared_dir_prefix_len(p1_parts: list[str], p2_parts: list[str]) -> int {
        score: any = 0;
        for (a, b) in zip(p1_parts, p2_parts) {
            if a == b {
                score += 1;
            } else {
                break;
            }
        }
        return score;
    }

    for e in edges {
        if e.get("relation") != "imports" {
            continue;
        }
        md: any = e.get("metadata");
        if not isinstance(md, `dict) {
            continue;
        }
        include_kind: any = md.get("include_kind");
        if include_kind not in ("quoted", "angle") {
            continue;
        }
        raw: any = md.get("raw_include");
        if not raw or not isinstance(raw, `str) {
            continue;
        }

        raw_norm: any = raw.replace("\\", "/").strip();
        if not raw_norm {
            continue;
        }
        if include_kind == "angle" and "/" not in raw_norm {
            continue;
        }

        if raw_norm.startswith(("./", "../", "/")) {
            continue;
        }
        try {
            if Path(raw).is_absolute() {
                continue;
            }
        } except Exception {}

        target_base: any = raw_norm.split("/")[-1];
        if not target_base {
            continue;
        }

        exact_cands: any = headers_by_basename.get(target_base, []);
        matches: any = [
            (`node, cand_path)
            for (`node, cand_path) in exact_cands
            if cand_path == raw_norm or cand_path.endswith("/" + raw_norm)
        ];

        if not matches {
            ci_cands: any = headers_by_basename_ci.get(target_base.lower(), []);
            raw_norm_lower: any = raw_norm.lower();
            matches = [
                (`node, cand_path)
                for (`node, cand_path) in ci_cands
                if cand_path.lower() == raw_norm_lower
                    or cand_path.lower().endswith("/" + raw_norm_lower)
            ];
        }

        if not matches {
            continue;
        }

        winner_node: dict | None = None;
        if len(matches) == 1 {
            winner_node = matches[0][0];
        } else {
            imp_sf: any = `str(e.get("source_file", ""));
            imp_key: any = _source_key(imp_sf, `root) if `root else imp_sf;
            imp_path: any = imp_key.replace("\\", "/").rstrip("/");
            imp_parts: any = imp_path.split("/")[:-1];

            scored: list[tuple[int, dict]] = [];
            for (`node, cand_path) in matches {
                cand_parts: any = cand_path.split("/")[:-1];
                score: any = _shared_dir_prefix_len(imp_parts, cand_parts);
                scored.append((score, `node));
            }

            max_score: any = max(s[0] for s in scored);
            top_matches: any = [`node for (score, `node) in scored if score == max_score];
            if len(top_matches) == 1 {
                winner_node = top_matches[0];
            } else {
                winner_node = None;
            }
        }

        if winner_node is not None {
            e["target"] = winner_node["id"];
            e.pop("target_file", None);
        }
    }
}

impl _resolve_csharp_constructor_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) {
    ctors_of: dict[str, list[dict]];
    tnode: any;
    rc: any;
    records: any = [
        rc
        for result in per_file
        if isinstance(result, `dict)
        for rc in result.get("raw_calls", []) or []
        if rc.get("lang") == "csharp" and (rc.get("csharp_ctor_site") or rc.get("csharp_ctor_init"))
    ];
    if not records {
        return;
    }
    node_by_id: any = {n.get("id"): n for n in all_nodes};
    ctors_of = {};
    owner_of: dict[str, str] = {};
    e: any;
    for e in all_edges {
        if e.get("relation") != "method" {
            continue;
        }
        tnode = node_by_id.get(e.get("target"));
        type_nid: any = e.get("source");
        if tnode is None
            or not isinstance(type_nid, `str)
            or not is_csharp_constructor_node(tnode)
        {
            continue;
        }
        owner_of.setdefault(tnode["id"], type_nid);
        bucket: any = ctors_of.setdefault(type_nid, []);
        if all(operator.ne(c["id"], tnode["id"]) for c in bucket) {
            bucket.append(tnode);
        }
    }

    def _pick(type_nid: str | None, argc: object) -> dict | None {
        ctors: any = [
            c
            for c in ctors_of.get(type_nid or "", [])
            if (c.get("metadata") or {}).get("signature") != "static"
        ];
        if not ctors or not isinstance(argc, `int) {
            return None;
        }
        return _csharp_pick_overload(ctors, argc);
    }

    def _bare(label: object) -> str {
        return re.sub("\\W+", "", `str(label or ""));
    }
    built: dict[str, dict[str, dict[str, str]]] = {};
    callers: any = {rc.get("caller_nid") for rc in records if rc.get("csharp_ctor_site")};
    for e in all_edges {
        if e.get("relation") != "calls" or e.get("source") not in callers {
            continue;
        }
        tnode = node_by_id.get(e.get("target"));
        if tnode is None or tnode["id"] in owner_of or not tnode.get("source_file") {
            continue;
        }
        built.setdefault(e["source"], {}).setdefault(
            _bare(tnode.get("label")), {}
        )[tnode["id"]] = `str(e.get("confidence") or "INFERRED");
    }

    bases_of: dict[str, set[str]] = {};
    unresolved_base: set[str] = set[any]();
    for e in all_edges {
        derived: any = e.get("source");
        if e.get("relation") != "inherits"
            or not isinstance(derived, `str)
            or not _is_cs_file(e.get("source_file"))
        {
            continue;
        }
        tnode = node_by_id.get(e.get("target"));
        if tnode is None or not tnode.get("source_file") {
            unresolved_base.add(derived);
        } else {
            bases_of.setdefault(derived, set[any]()).add(tnode["id"]);
        }
    }

    existing: any = {
        (e.get("source"), e.get("target"))
        for e in all_edges
        if e.get("relation") == "calls"
    };
    for rc in records {
        caller: any = rc.get("caller_nid");
        if not caller {
            continue;
        }
        confidence: any = "EXTRACTED";
        if rc.get("csharp_ctor_site") {
            types: any = built.get(caller, {}).get(rc["csharp_ctor_site"], {});
            if len(types) != 1 {
                continue;
            }
            (type_nid, confidence) = next(iter(types.items())) as any;
        } elif rc.get("csharp_ctor_init") == "this" {
            type_nid = owner_of.get(caller);
        } else {
            owner: any = owner_of.get(caller);
            bases: any = bases_of.get(owner or "", set[any]());
            if owner is None or owner in unresolved_base or len(bases) != 1 {
                continue;
            }
            type_nid = next(iter(bases));
        }
        target: any = _pick(type_nid, rc.get("arity"));
        if target is None or target["id"] == caller or (caller, target["id"]) in existing {
            continue;
        }
        existing.add((caller, target["id"]));
        all_edges.append({
            "source": caller,
            "target": target["id"],
            "relation": "calls",
            "context": "call",
            "confidence": confidence,
            "confidence_score": 1.0 if confidence == "EXTRACTED" else 0.85,
            "source_file": rc.get("source_file", ""),
            "source_location": rc.get("source_location"),
            "weight": 1.0,
        });
    }
}

impl _resolve_csharp_qualified_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) {
    rc: any;
    raw: any = [
        rc
        for result in per_file
        for rc in result.get("raw_calls", [])
        if rc.get("lang") == "csharp"
            and rc.get("qualified_prefix")
            and rc.get("callee")
            and rc.get("caller_nid")
    ];
    if not raw {
        return;
    }
    by_namespace: dict[tuple[str, str], list[str]] = {};
    for n in all_nodes {
        if not n.get("_callable_class") or not n.get("source_file") {
            continue;
        }
        namespace: any = `str((n.get("metadata") or {}).get("namespace") or "");
        label: any = `str(n.get("label", "")).strip("()");
        if namespace and label {
            by_namespace.setdefault((namespace, label), []).append(n["id"]);
        }
    }
    if not by_namespace {
        return;
    }
    existing_pairs: any = {
        (e.get("source"), e.get("target"))
        for e in all_edges
        if e.get("relation") == "calls"
    };
    for rc in raw {
        candidates: any = by_namespace.get((rc["qualified_prefix"], rc["callee"]), []);
        if len(candidates) != 1 {
            continue;
        }
        caller: any = rc["caller_nid"];
        tgt: any = candidates[0];
        if tgt == caller or (caller, tgt) in existing_pairs {
            continue;
        }
        existing_pairs.add((caller, tgt));
        all_edges.append({
            "source": caller,
            "target": tgt,
            "relation": "calls",
            "context": "call",
            "confidence": "EXTRACTED",
            "confidence_score": 1.0,
            "source_file": rc.get("source_file", ""),
            "source_location": rc.get("source_location"),
            "weight": 1.0,
        });
    }
}

impl _resolve_kotlin_qualified_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) {
    result: any;
    n: any;
    rc: any;
    pkg_results: any = _kotlin_package_index(per_file);
    if not pkg_results {
        return;
    }
    raw: any = [
        rc
        for result in per_file
        for rc in result.get("raw_calls", [])
        if rc.get("lang") == "kotlin"
            and rc.get("qualified_prefix")
            and rc.get("callee")
            and rc.get("caller_nid")
    ];
    if not raw {
        return;
    }

    node_by_id: dict[str, dict] = {n.get("id"): n for n in all_nodes};
    contains_by_source: dict[str, list[str]] = {};
    methods_by_type: dict[str, list[str]] = {};
    for e in all_edges {
        rel: any = e.get("relation");
        if rel == "contains" {
            contains_by_source.setdefault(e.get("source"), []).append(e.get("target"));
        } elif rel == "method" {
            methods_by_type.setdefault(e.get("source"), []).append(e.get("target"));
        }
    }
    pkg_callables: dict[str, dict[str, list[str]]] = {};
    pkg_types: dict[str, dict[str, list[str]]] = {};
    pkg: any;
    for (pkg, results) in pkg_results.items() {
        callables: any = pkg_callables.setdefault(pkg, {});
        types: any = pkg_types.setdefault(pkg, {});
        for result in results {
            file_nid: any = next(
                (n["id"]
                for n in result.get("nodes", [])
                if n.get("source_file") and n.get("label") == Path(`str(n["source_file"])).name),
                None,
            );
            if file_nid is None {
                continue;
            }
            tgt: any;
            for tgt in contains_by_source.get(file_nid, []) {
                n = node_by_id.get(tgt);
                if n is None or not n.get("source_file") {
                    continue;
                }
                name: any = `str(n.get("label", "")).strip("()");
                if not name or name.startswith(".") {
                    continue;
                }
                if n.get("_callable") {
                    callables.setdefault(name, []).append(tgt);
                }
                if n.get("_callable_class") {
                    types.setdefault(name, []).append(tgt);
                }
            }
        }
    }

    existing_pairs: any = {(e.get("source"), e.get("target")) for e in all_edges};
    for rc in raw {
        prefix: any = rc["qualified_prefix"];
        callee: any = rc["callee"];
        caller: any = rc["caller_nid"];
        candidates: list[str] = [];
        if prefix in pkg_callables {
            candidates = pkg_callables[prefix].get(callee, []);
        } else {
            _: any;
            type_name: any;
            (pkg, _, type_name) = prefix.rpartition(".") as any;
            type_nids: any = pkg_types.get(pkg, {}).get(type_name, []) if pkg else [];
            if len(type_nids) == 1 {
                wanted: any = f".{callee}";
                candidates = [
                    m
                    for m in methods_by_type.get(type_nids[0], [])
                    if `str(node_by_id.get(m, {}).get("label", "")).strip("()") == wanted
                ];
            }
        }
        if len(candidates) != 1 {
            continue;
        }
        tgt = candidates[0];
        if tgt == caller or (caller, tgt) in existing_pairs {
            continue;
        }
        existing_pairs.add((caller, tgt));
        all_edges.append({
            "source": caller,
            "target": tgt,
            "relation": "calls",
            "context": "call",
            "confidence": "EXTRACTED",
            "confidence_score": 1.0,
            "source_file": rc.get("source_file", ""),
            "source_location": rc.get("source_location"),
            "weight": 1.0,
        });
    }
}

impl _resolve_rust_self_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) {
    node_by_id: dict[str, dict];
    n: any;
    contains_targets: any;
    e: any;
    rc: any;
    raw: any = [
        rc
        for result in per_file
        for rc in result.get("raw_calls", [])
        if rc.get("rust_self_type") and rc.get("callee") and rc.get("caller_nid")
    ];
    if not raw {
        return;
    }

    node_by_id = {n.get("id"): n for n in all_nodes};
    nids_by_label: dict[str, list[str]] = {};
    nids_by_rust_impl_key: dict[str, list[str]] = {};
    for n in all_nodes {
        if `str(n.get("source_file") or "").endswith(".rs") {
            nids_by_label.setdefault(n.get("label", ""), []).append(n.get("id"));
            impl_key: any = n.get("_rust_impl_key");
            if isinstance(impl_key, `str) and impl_key {
                nids_by_rust_impl_key.setdefault(impl_key, []).append(n.get("id"));
            }
        }
    }
    declared_type_count: dict[str, int] = {};
    generic_declared_type_count: dict[str, int] = {};
    contains_targets = {e.get("target") for e in all_edges if e.get("relation") == "contains"};
    for (label, nids) in nids_by_label.items() {
        declared_type_count[label] = sum(1 for nid in nids if nid in contains_targets);
        generic_declared_type_count[label] = sum(
            count
            for count in (node_by_id.get(nid, {}).get("_rust_declaration_count") for nid in nids)
            if isinstance(count, `int) and not isinstance(count, `bool) and count > 0,
        );
    }
    method_index: dict[tuple[str, str], set[str]] = {};
    for e in all_edges {
        if e.get("relation") != "method" {
            continue;
        }
        src: any;
        tgt: any;
        (src, tgt) = (e.get("source"), e.get("target"));
        tnode: any = node_by_id.get(tgt);
        if tnode is not None {
            name: any = `str(tnode.get("label", "")).strip("()").lstrip(".");
            method_index.setdefault((src, name), set[any]()).add(tgt);
        }
    }
    existing_pairs: any = {
        (e.get("source"), e.get("target"))
        for e in all_edges
        if e.get("relation") == "calls"
    };
    for rc in raw {
        caller: any = rc["caller_nid"];
        callee: any = rc["callee"];
        self_type: any = rc["rust_self_type"];
        impl_key = rc.get("rust_self_impl_key");
        if isinstance(impl_key, `str) and impl_key {
            if generic_declared_type_count.get(self_type, 0) != 1 {
                continue;
            }
            owner_nids: any = nids_by_rust_impl_key.get(impl_key, []);
        } else {
            if declared_type_count.get(self_type, 0) >= 2 {
                continue;
            }
            owner_nids = nids_by_label.get(self_type, []);
        }
        candidates: set[str] = set[any]();
        for nid in owner_nids {
            candidates |= method_index.get((nid, callee), set[any]());
        }
        if len(candidates) != 1 {
            continue;
        }
        tgt = next(iter(candidates));
        if tgt == caller or (caller, tgt) in existing_pairs {
            continue;
        }
        existing_pairs.add((caller, tgt));
        all_edges.append({
            "source": caller,
            "target": tgt,
            "relation": "calls",
            "context": "call",
            "confidence": "EXTRACTED",
            "confidence_score": 1.0,
            "source_file": rc.get("source_file", ""),
            "source_location": rc.get("source_location"),
            "weight": 1.0,
        });
    }
}

impl _resolve_go_member_calls(per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]) {
    result: any;
    type_def_nids: dict[str, list[str]];
    package_paths_by_nid: dict[str, set[str]];
    rc: any;
    raw: any = [
        rc
        for result in per_file
        for rc in result.get("raw_calls", [])
        if rc.get("language") == "go"
            and rc.get("is_member_call")
            and rc.get("member_receiver")
            and rc.get("callee")
            and rc.get("caller_nid")
    ];
    if not raw {
        return;
    }
    package_vars_by_file: dict[str, dict[str, str | None]] = {};
    imports_by_file: dict[str, dict[str, str]] = {};
    package_path_by_file: dict[str, str] = {};
    for result in per_file {
        tt: any = result.get("go_type_table");
        if tt and tt.get("path") {
            package_vars_by_file[tt["path"]] = tt.get("package_vars", {});
            imports_by_file[tt["path"]] = result.get("go_imports") or {};
            if tt.get("package_path") {
                package_path_by_file[tt["path"]] = tt["package_path"];
            }
        }
    }

    def _key(label: object) -> str {
        return `str(label or "").strip().removeprefix(".").removesuffix("()");
    }
    type_def_nids = {};
    node_by_id: dict[str, dict] = {};
    fields_by_type: dict[str, list[dict[str, str]]] = {};
    package_paths_by_nid = {};
    for n in all_nodes {
        node_by_id[n.get("id")] = n;
        if n.get("_callable_class") and _lang_family(n.get("source_file")) == "go" {
            type_def_nids.setdefault(_key(n.get("label", "")), []).append(n["id"]);
            if n.get("_go_package_path") {
                package_paths_by_nid.setdefault(n["id"], set[any]()).add(n["_go_package_path"]);
            }
        }
        for (struct_nid, fields) in (n.get("_go_fields") or {}).items() {
            fields_by_type.setdefault(struct_nid, []).append(fields);
        }
    }

    def same_package_types(label: str, caller_package: str | None) -> list[str] {
        candidates: any = type_def_nids.get(_key(label), []);
        if caller_package {
            scoped: any = [
                nid
                for nid in candidates
                if caller_package in package_paths_by_nid.get(nid, ())
            ];
            if scoped {
                return scoped;
            }
        }
        return candidates;
    }

    method_index: dict[tuple[str, str], list[str]] = {};
    for e in all_edges {
        if e.get("relation") != "method" {
            continue;
        }
        tnode: any = node_by_id.get(e.get("target"));
        if tnode is not None {
            method_index.setdefault((e.get("source"), _key(tnode.get("label", ""))), []).append(
                e["target"]
            );
        }
    }

    existing_pairs: any = {(e.get("source"), e.get("target")) for e in all_edges};
    for rc in sorted(raw, key=lambda (call) -> any { `bool(call.get("indirect")) }) {
        receiver: any;
        callee: any;
        caller: any;
        (receiver, callee, caller) = (rc["member_receiver"], rc["callee"], rc["caller_nid"]);
        caller_package: any = package_path_by_file.get(rc.get("source_file", ""));
        type_name: any = rc.get("receiver_type");
        from_sibling: any = False;
        if rc.get("field_owner") {
            type_name = None;
            owner_defs: any = same_package_types(rc["field_owner"], caller_package);
            declared: any = fields_by_type.get(owner_defs[0], []) if len(owner_defs) == 1 else [];
            if len(declared) == 1 {
                type_name = declared[0].get(receiver);
                from_sibling = True;
            }
        } elif not type_name and not rc.get("receiver_bound") {
            type_name = package_vars_by_file.get(rc.get("source_file", ""), {}).get(receiver);
        }
        if not type_name or type_name in _LANGUAGE_BUILTIN_GLOBALS {
            continue;
        }
        if "." in type_name {
            if from_sibling {
                import_path: any;
                _: any;
                bare: any;
                (import_path, _, bare) = type_name.rpartition(".") as any;
            } else {
                alias: any;
                (alias, _, bare) = type_name.partition(".") as any;
                import_path = imports_by_file.get(rc.get("source_file", ""), {}).get(alias);
            }
            type_defs: any = [
                nid
                for nid in type_def_nids.get(_key(bare), [])
                if import_path and import_path in package_paths_by_nid.get(nid, ())
            ];
            if not type_defs {
                continue;
            }
        } else {
            type_defs = same_package_types(type_name, caller_package);
        }
        if not type_defs {
            if not rc.get("indirect") {
                _park_unresolved_member_call(node_by_id.get(caller), callee, type_name, "go", rc);
            }
            continue;
        }
        if len(type_defs) != 1 {
            continue;
        }
        targets: any = method_index.get((type_defs[0], _key(callee)), []);
        if len(targets) != 1 {
            continue;
        }
        target: any = targets[0];
        if target == caller or (caller, target) in existing_pairs {
            continue;
        }
        existing_pairs.add((caller, target));
        indirect: any = `bool(rc.get("indirect"));
        all_edges.append({
            "source": caller,
            "target": target,
            "relation": "indirect_call" if indirect else "calls",
            "context": rc.get("context", "argument") if indirect else "call",
            "confidence": "INFERRED",
            "confidence_score": 0.85,
            "source_file": rc.get("source_file", ""),
            "source_location": rc.get("source_location"),
            "weight": 1.0,
        });
    }
}

impl _resolve_elixir_import_targets(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) {
    node_by_id: dict[str, dict] = {};
    module_nids_by_bare_id: dict[str, list[str]] = {};
    for n in all_nodes {
        node_by_id[n["id"]] = n;
        if not n.get("_elixir_module") {
            continue;
        }
        label: any = `str(n.get("label") or "");
        if not label {
            continue;
        }
        module_nids_by_bare_id.setdefault(_make_id(label), []).append(n["id"]);
    }
    if not module_nids_by_bare_id {
        return;
    }

    node_ids: any = `set(node_by_id);
    for e in all_edges {
        if e.get("relation") != "imports"
            or e.get("context") != "import"
            or not `str(e.get("source_file") or "").endswith((".ex", ".exs"))
        {
            continue;
        }
        tgt: any = e.get("target");
        if tgt in node_ids {
            continue;
        }
        candidates: any = module_nids_by_bare_id.get(tgt, []);
        if len(candidates) != 1 {
            continue;
        }
        target_nid: any = candidates[0];
        target_node: any = node_by_id.get(target_nid);
        if target_node is not None
            and `str(target_node.get("source_file") or "") == `str(e.get("source_file") or "")
        {
            continue;
        }
        e["target"] = target_nid;
    }
}

impl _resolve_elixir_qualified_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) {
    rc: any;
    raw: any = [
        rc
        for result in per_file
        for rc in result.get("raw_calls", [])
        if rc.get("elixir_module") and rc.get("callee") and rc.get("caller_nid")
    ];
    if not raw {
        return;
    }

    module_nids: dict[str, list[str]] = {};
    labels: dict[str, str] = {};
    for n in all_nodes {
        labels[n["id"]] = `str(n.get("label") or "");
        if n.get("_elixir_module") and n.get("source_file") {
            module_nids.setdefault(labels[n["id"]], []).append(n["id"]);
        }
    }
    defs: dict[tuple[str, str], str] = {};
    for e in all_edges {
        if e.get("relation") == "method" {
            name: any = labels.get(e.get("target", ""), "");
            if name.endswith("()") {
                defs.setdefault((e["source"], name[:-2]), e["target"]);
            }
        }
    }

    existing_pairs: any = {
        (e.get("source"), e.get("target"))
        for e in all_edges
        if e.get("relation") == "calls"
    };
    for rc in raw {
        candidates: any = module_nids.get(rc["elixir_module"], []);
        if len(candidates) != 1 {
            continue;
        }
        caller: any = rc["caller_nid"];
        tgt: any = defs.get((candidates[0], rc["callee"]));
        if tgt is None or tgt == caller or (caller, tgt) in existing_pairs {
            continue;
        }
        existing_pairs.add((caller, tgt));
        all_edges.append({
            "source": caller,
            "target": tgt,
            "relation": "calls",
            "context": "call",
            "confidence": "EXTRACTED",
            "confidence_score": 1.0,
            "source_file": rc.get("source_file", ""),
            "source_location": rc.get("source_location"),
            "weight": 1.0,
        });
    }
}

impl _jvm_scope_index(
    all_nodes: list[dict], all_edges: list[dict]
) -> tuple[dict[str, str], dict[str, list[str]], dict[str, str], set[str]] {
    owner_of: dict[str, str] = {};
    bases_of: dict[str, list[str]] = {};
    enclosing_of: dict[str, str] = {};
    for e in all_edges {
        rel: any = e.get("relation");
        if rel == "method" {
            owner_of[e["target"]] = e["source"];
        } elif rel == "inherits" {
            bases_of.setdefault(e["source"], []).append(e["target"]);
        } elif rel == "contains" {
            enclosing_of[e["target"]] = e["source"];
        }
    }
    sourceless: any = {n["id"] for n in all_nodes if not n.get("source_file")};
    return (owner_of, bases_of, enclosing_of, sourceless);
}

impl _jvm_reachable_candidates(
    candidates: list[str],
    caller: str,
    callee: str,
    index: tuple[dict[str, str], dict[str, list[str]], dict[str, str], set[str]],
    imported_symbols: set[str],
) -> list[str] {
    owner_of: any;
    bases_of: any;
    enclosing_of: any;
    sourceless: any;
    (owner_of, bases_of, enclosing_of, sourceless) = index as any;
    chain: set[str] = set[any]();
    todo: any = [owner_of.get(caller, caller)];
    external_base: any = False;
    while todo {
        cls: any = todo.pop();
        if cls in chain {
            continue;
        }
        chain.add(cls);
        for base in bases_of.get(cls, ()) {
            if base in sourceless {
                external_base = True;
            } else {
                todo.append(base);
            }
        }
        if cls in enclosing_of {
            todo.append(enclosing_of[cls]);
        }
    }
    if not external_base {
        return candidates;
    }
    imported_by_name: any = _make_id(callee) in imported_symbols;
    return [
        c
        for c in candidates
        if c not in owner_of or owner_of[c] in chain or c in imported_symbols or imported_by_name
    ];
}

impl _resolve_kotlin_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) {
    node_by_id: dict[str, dict];
    n: any;
    rc: any;
    wanted: any;
    raw: any = [
        rc
        for result in per_file
        for rc in result.get("raw_calls", [])
        if rc.get("lang") == "kotlin"
            and (rc.get("kotlin_object_receiver") or rc.get("kotlin_receiver_type"))
            and rc.get("callee")
            and rc.get("caller_nid")
    ];
    if not raw {
        return;
    }

    node_by_id = {n.get("id"): n for n in all_nodes};
    methods_by_type: dict[str, list[str]] = {};
    for e in all_edges {
        if e.get("relation") == "method" {
            methods_by_type.setdefault(e.get("source"), []).append(e.get("target"));
        }
    }
    types_by_name: dict[str, list[str]] = {};
    for n in all_nodes {
        if not n.get("_callable_class") {
            continue;
        }
        sf: any = `str(n.get("source_file") or "");
        if _lang_family(sf) != "jvm" {
            continue;
        }
        name: any = `str(n.get("label", ""));
        if name {
            types_by_name.setdefault(name, []).append(n["id"]);
        }
    }

    type_ids: any = {nid for definitions in types_by_name.values() for nid in definitions};
    imported_types: dict[str, dict[str, set[str]]] = {};
    for `edge in all_edges {
        if `edge.get("relation") != "imports" {
            continue;
        }
        source_file: any = `str(`edge.get("source_file") or "");
        if not source_file.endswith((".kt", ".kts")) {
            continue;
        }
        fqn: any = (`edge.get("metadata") or {}).get("target_fqn");
        if isinstance(fqn, `str) and fqn and not fqn.endswith(".*") {
            local_name: any = (`edge.get("metadata") or {}).get("alias") or fqn.rsplit(".", 1)[-1];
            imported_types.setdefault(source_file, {}).setdefault(local_name, set[any]()).add(
                `edge["target"]
            );
        }
    }

    existing_pairs: any = {(e.get("source"), e.get("target")) for e in all_edges};
    for rc in raw {
        receiver: any = rc.get("kotlin_object_receiver") or rc["kotlin_receiver_type"];
        callee: any = rc["callee"];
        caller: any = rc["caller_nid"];
        type_nids: any = types_by_name.get(receiver, []);
        explicit: any = imported_types.get(rc.get("source_file", ""), {}).get(receiver);
        if explicit is not None {
            type_nids = sorted(explicit & type_ids);
        }
        if not type_nids {
            if receiver not in _LANGUAGE_BUILTIN_GLOBALS {
                _park_unresolved_member_call(
                    node_by_id.get(caller), callee, receiver, "kotlin", rc
                );
            }
            continue;
        }
        if len(type_nids) != 1 {
            continue;
        }
        wanted = f".{callee}";
        candidates: any = `list(
            dict.fromkeys(
                m
                for m in methods_by_type.get(type_nids[0], [])
                if `str(node_by_id.get(m, {}).get("label", "")).strip("()") == wanted,
            ),
        );
        overloaded: any = operator.gt(len(candidates), 1)
            and all(
                isinstance((node_by_id.get(c, {}).get("metadata") or {}).get("arity"), `int)
                for c in candidates,
            );
        if overloaded {
            candidates.sort(
                key=lambda (c) -> any {
                    (
                        `int(`str(node_by_id[c].get("source_location") or "L0")[1:] or 0)
                            if `str(node_by_id[c].get("source_location") or "L0")[1:].isdigit()
                            else 0,
                        c,
                    )
                },
            );
        } elif len(candidates) != 1 {
            continue;
        }
        tgt: any = candidates[0];
        if tgt == caller or (caller, tgt) in existing_pairs {
            continue;
        }
        existing_pairs.add((caller, tgt));
        all_edges.append({
            "source": caller,
            "target": tgt,
            "relation": "calls",
            "context": "call",
            "confidence": "INFERRED" if overloaded else "EXTRACTED",
            "confidence_score": 0.85 if overloaded else 1.0,
            "source_file": rc.get("source_file", ""),
            "source_location": rc.get("source_location"),
            "weight": 1.0,
        });
    }
}

impl _project_xml_is_safe(src: bytes) -> bool {
    lowered: any = src.lower();
    return b"<!doctype" not in lowered and b"<!entity" not in lowered;
}

impl extract_lazarus_package(path: Path) -> dict {
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    try {
        import xml.etree.ElementTree as ET;
        src: any = path.read_bytes();
    } except OSError as e {
        return {"nodes": [], "edges": [], "error": `str(e)};
    }

    if len(src) > _PROJECT_XML_MAX_BYTES {
        return {"nodes": [], "edges": [], "error": "package file too large"};
    }
    if not _project_xml_is_safe(src) {
        return {"nodes": [], "edges": [], "error": "refusing XML with DOCTYPE/ENTITY declaration"};
    }

    try {
        xml_root: any = ET.fromstring(src);
    } except Exception as e {
        return {"nodes": [], "edges": [], "error": `str(e)};
    }

    str_path = `str(path);
    stem: any = _file_stem(path);
    nodes = [];
    edges = [];
    seen_ids = set[any]();

    def add_node(nid: str, label: str) {
        if nid not in seen_ids {
            seen_ids.add(nid);
            nodes.append({
                "id": nid,
                "label": label,
                "file_type": "code",
                "source_file": str_path,
                "source_location": "L1",
            });
        }
    }

    def add_edge(src: str, tgt: str, relation: str, context: str | None = None) {
        `edge: dict[str, Any] = {
            "source": src,
            "target": tgt,
            "relation": relation,
            "confidence": "EXTRACTED",
            "source_file": str_path,
            "source_location": "L1",
            "weight": 1.0,
        };
        if context {
            `edge["context"] = context;
        }
        edges.append(`edge);
    }

    file_nid: any = _make_id(`str(path));
    add_node(file_nid, path.name);

    name_elem: any = xml_root.find(".//Package/Name");
    pkg_name: any = name_elem.get("Value") if name_elem is not None else path.stem;
    pkg_nid: any = _make_id(stem, pkg_name);
    add_node(pkg_nid, pkg_name);
    add_edge(file_nid, pkg_nid, "contains");
    item: any;
    for item in xml_root.findall(".//RequiredPkgs/") {
        dep_elem: any = item.find("PackageName");
        if dep_elem is not None {
            dep_name: any = dep_elem.get("Value", "");
            if dep_name {
                dep_nid: any = _make_id(dep_name);
                add_node(dep_nid, dep_name);
                add_edge(pkg_nid, dep_nid, "imports", context="import");
            }
        }
    }
    for item in xml_root.findall(".//Files/") {
        unit_elem: any = item.find("UnitName");
        if unit_elem is not None {
            unit_name: any = unit_elem.get("Value", "");
            if unit_name {
                unit_nid: any = _pascal_resolve_unit(path, unit_name);
                add_node(unit_nid, unit_name);
                add_edge(pkg_nid, unit_nid, "contains");
            }
        }
    }

    return {"nodes": nodes, "edges": edges, "input_tokens": 0, "output_tokens": 0};
}

impl _check_tree_sitter_version {
    try {
        import from tree_sitter { LANGUAGE_VERSION }
    } except ImportError {
        raise ImportError("tree-sitter is not installed. Run: pip install 'tree-sitter>=0.23.0'");
    }
    if LANGUAGE_VERSION < 14 {
        import tree_sitter as _ts;
        raise RuntimeError(
            "tree-sitter "
                + format(getattr(_ts, "__version__", "unknown"), "")
                + " is too old. graphify requires tree-sitter >= 0.23.0 (Language API v2). Run: pip install --upgrade tree-sitter",
        );
    }
}

impl extract_slnx(path: Path) -> dict {
    import xml.etree.ElementTree as ET;

    try {
        src: any = path.read_bytes();
    } except OSError {
        return {"nodes": [], "edges": [], "error": f"cannot read {path}"};
    }

    if len(src) > _PROJECT_XML_MAX_BYTES {
        return {"nodes": [], "edges": [], "error": "project file too large"};
    }
    if not _project_xml_is_safe(src) {
        return {"nodes": [], "edges": [], "error": "refusing XML with DOCTYPE/ENTITY declaration"};
    }

    try {
        tree: any = ET.fromstring(src);
    } except ET.ParseError as e {
        return {"nodes": [], "edges": [], "error": f"XML parse error: {e}"};
    }

    file_nid: any = _make_id(`str(path));
    str_path: any = `str(path);
    nodes: list[dict] = [
        {
            "id": file_nid,
            "label": path.name,
            "file_type": "code",
            "source_file": str_path,
            "source_location": None,
        },
    ];
    edges: list[dict] = [];
    seen_ids: set[str] = set[any]();
    seen_ids.add(file_nid);

    ns: any = "";
    if tree.tag.startswith("{") {
        ns = tree.tag.split("}")[0] + "}";
    }

    def _resolve(proj_path: str) -> str {
        proj_path = proj_path.replace("\\", "/");
        try {
            return `str((path.parent / proj_path).resolve());
        } except Exception {
            return proj_path;
        }
    }
    project_nids: set[str] = set[any]();
    proj: any;
    for proj in tree.iter(f"{ns}Project") {
        proj_path: any = proj.get("Path");
        if not proj_path {
            continue;
        }
        abs_proj: any = _resolve(proj_path);
        proj_nid: any = _make_id(abs_proj);
        if proj_nid and proj_nid not in seen_ids {
            seen_ids.add(proj_nid);
            label: any = Path(proj_path).stem;
            nodes.append({
                "id": proj_nid,
                "label": label,
                "file_type": "code",
                "source_file": abs_proj,
                "source_location": None,
            });
            edges.append({
                "source": file_nid,
                "target": proj_nid,
                "relation": "contains",
                "confidence": "EXTRACTED",
                "source_file": str_path,
                "weight": 1.0,
            });
        }
        if proj_nid {
            project_nids.add(proj_nid);
        }
    }
    for proj in tree.iter(f"{ns}Project") {
        proj_path = proj.get("Path");
        if not proj_path {
            continue;
        }
        from_nid: any = _make_id(_resolve(proj_path));
        for dep in proj.iter(f"{ns}BuildDependency") {
            dep_path: any = dep.get("Project");
            if not dep_path {
                continue;
            }
            to_nid: any = _make_id(_resolve(dep_path));
            if from_nid and to_nid and from_nid != to_nid and to_nid in project_nids {
                edges.append({
                    "source": from_nid,
                    "target": to_nid,
                    "relation": "imports",
                    "confidence": "EXTRACTED",
                    "source_file": str_path,
                    "weight": 1.0,
                });
            }
        }
    }

    return {"nodes": nodes, "edges": edges};
}

impl extract_csproj(path: Path) -> dict {
    tree: any;
    ns: any;
    import xml.etree.ElementTree as ET;

    try {
        src: any = path.read_bytes();
    } except OSError {
        return {"nodes": [], "edges": [], "error": f"cannot read {path}"};
    }

    if len(src) > _PROJECT_XML_MAX_BYTES {
        return {"nodes": [], "edges": [], "error": "project file too large"};
    }
    if not _project_xml_is_safe(src) {
        return {"nodes": [], "edges": [], "error": "refusing XML with DOCTYPE/ENTITY declaration"};
    }

    try {
        tree = ET.fromstring(src);
    } except ET.ParseError as e {
        return {"nodes": [], "edges": [], "error": f"XML parse error: {e}"};
    }

    file_nid: any = _make_id(`str(path));
    str_path: any = `str(path);
    nodes: list[dict] = [
        {
            "id": file_nid,
            "label": path.name,
            "file_type": "code",
            "source_file": str_path,
            "source_location": None,
        },
    ];
    edges: list[dict] = [];
    seen_ids: set[str] = set[any]();
    seen_ids.add(file_nid);

    ns = "";
    root_tag: any = tree.tag;
    if root_tag.startswith("{") {
        ns = root_tag.split("}")[0] + "}";
    }

    def find_all(tag: str) -> any {
        return tree.iter(f"{ns}{tag}");
    }

    tf: any;
    for tf in find_all("TargetFramework") {
        if tf.text {
            fw_nid: any = _make_id("framework", tf.text.strip());
            if fw_nid and fw_nid not in seen_ids {
                seen_ids.add(fw_nid);
                nodes.append({
                    "id": fw_nid,
                    "label": tf.text.strip(),
                    "file_type": "concept",
                    "source_file": str_path,
                    "source_location": None,
                });
                edges.append({
                    "source": file_nid,
                    "target": fw_nid,
                    "relation": "references",
                    "confidence": "EXTRACTED",
                    "source_file": str_path,
                    "weight": 1.0,
                });
            }
        }
    }

    for tf in find_all("TargetFrameworks") {
        if tf.text {
            fw: any;
            for fw in tf.text.strip().split(";") {
                fw = fw.strip();
                if fw {
                    fw_nid = _make_id("framework", fw);
                    if fw_nid and fw_nid not in seen_ids {
                        seen_ids.add(fw_nid);
                        nodes.append({
                            "id": fw_nid,
                            "label": fw,
                            "file_type": "concept",
                            "source_file": str_path,
                            "source_location": None,
                        });
                        edges.append({
                            "source": file_nid,
                            "target": fw_nid,
                            "relation": "references",
                            "confidence": "EXTRACTED",
                            "source_file": str_path,
                            "weight": 1.0,
                        });
                    }
                }
            }
        }
    }

    for pkg in find_all("PackageReference") {
        name: any = pkg.get("Include") or pkg.get("include") or "";
        version: any = pkg.get("Version") or pkg.get("version") or "";
        if not name {
            continue;
        }
        pkg_nid: any = _make_id("nuget", name);
        label: any = f"{name} ({version})" if version else name;
        if pkg_nid and pkg_nid not in seen_ids {
            seen_ids.add(pkg_nid);
            nodes.append({
                "id": pkg_nid,
                "label": label,
                "file_type": "code",
                "source_file": str_path,
                "source_location": None,
            });
        }
        edges.append({
            "source": file_nid,
            "target": pkg_nid,
            "relation": "imports",
            "confidence": "EXTRACTED",
            "source_file": str_path,
            "weight": 1.0,
        });
    }

    for proj in find_all("ProjectReference") {
        ref_path: any = proj.get("Include") or proj.get("include") or "";
        if not ref_path {
            continue;
        }
        ref_path_norm: any = ref_path.replace("\\", "/");
        try {
            abs_ref: any = `str((path.parent / ref_path_norm).resolve());
        } except Exception {
            abs_ref = ref_path_norm;
        }
        proj_nid: any = _make_id(abs_ref);
        if proj_nid and proj_nid not in seen_ids {
            seen_ids.add(proj_nid);
            proj_label: any = Path(ref_path_norm).name;
            nodes.append({
                "id": proj_nid,
                "label": proj_label,
                "file_type": "code",
                "source_file": abs_ref,
                "source_location": None,
            });
        }
        edges.append({
            "source": file_nid,
            "target": proj_nid,
            "relation": "imports",
            "confidence": "EXTRACTED",
            "source_file": str_path,
            "weight": 1.0,
        });
    }

    sdk: any = tree.get("Sdk") or "";
    if sdk {
        sdk_nid: any = _make_id("sdk", sdk);
        if sdk_nid and sdk_nid not in seen_ids {
            seen_ids.add(sdk_nid);
            nodes.append({
                "id": sdk_nid,
                "label": sdk,
                "file_type": "concept",
                "source_file": str_path,
                "source_location": None,
            });
            edges.append({
                "source": file_nid,
                "target": sdk_nid,
                "relation": "references",
                "confidence": "EXTRACTED",
                "source_file": str_path,
                "weight": 1.0,
            });
        }
    }

    return {"nodes": nodes, "edges": edges};
}

impl _xml_local_name(name: str) -> str {
    return name.rsplit("}", 1)[-1] if name.startswith("{") else name;
}

impl _xaml_markup_extension(value: str) -> tuple[str, str] | None {
    value = value.strip();
    if not (value.startswith("{") and value.endswith("}")) {
        return None;
    }
    inner: any = value[1:-1].strip();
    if not inner or inner.startswith("}") {
        return None;
    }
    name: any;
    _: any;
    args: any;
    (name, _, args) = inner.partition(" ") as any;
    return (name, args.strip());
}

impl _xaml_split_markup_args(args: str) -> list[str] {
    parts: list[str] = [];
    start: any = 0;
    depth: any = 0;
    for (idx, ch) in enumerate(args) {
        if ch == "{" {
            depth += 1;
        } elif ch == "}" and depth {
            depth -= 1;
        } elif ch == "," and depth == 0 {
            parts.append(args[start:idx].strip());
            start = idx + 1;
        }
    }
    tail: any = args[start:].strip();
    if tail {
        parts.append(tail);
    }
    return parts;
}

impl _xaml_static_resource_key(value: str) -> str | None {
    markup: any = _xaml_markup_extension(value);
    if not markup {
        return None;
    }
    name: any;
    args: any;
    (name, args) = markup as any;
    if name != "StaticResource" {
        return None;
    }
    for part in _xaml_split_markup_args(args) {
        if "=" not in part {
            return part.strip() or None;
        }
        key: any;
        resource: any;
        (key, resource) = part.split("=", 1) as any;
        if key.strip() == "ResourceKey" {
            return resource.strip() or None;
        }
    }
    return None;
}

impl _xaml_binding_refs(value: str) -> tuple[str | None, str | None] {
    markup: any = _xaml_markup_extension(value);
    if not markup {
        return (None, None);
    }
    name: any;
    args: any;
    (name, args) = markup as any;
    if name != "Binding" {
        return (None, None);
    }

    path_ref: any = None;
    converter_ref: any = None;
    for part in _xaml_split_markup_args(args) {
        if not part {
            continue;
        }
        if "=" not in part {
            if path_ref is None {
                path_ref = part.strip();
            }
            continue;
        }
        key: any;
        raw_value: any;
        (key, raw_value) = part.split("=", 1) as any;
        key = key.strip();
        raw_value = raw_value.strip();
        if key == "Path" {
            path_ref = raw_value;
        } elif key == "Converter" {
            converter_ref = _xaml_static_resource_key(raw_value);
        }
    }

    if path_ref and ("{" in path_ref or "}" in path_ref) {
        path_ref = None;
    }
    return (path_ref or None, converter_ref or None);
}

impl _xaml_codebehind_path(path: Path) -> Path | None {
    expected: any = path.with_suffix(path.suffix + ".cs");
    if expected.exists() {
        return expected;
    }
    try {
        for sibling in sorted(path.parent.iterdir(), key=lambda (p) -> any { p.name }) {
            if sibling.name.casefold() == expected.name.casefold() {
                return sibling;
            }
        }
    } except OSError {
        return None;
    }
    return None;
}

impl _xaml_codebehind_symbols(path: Path, class_name: str | None) -> tuple[dict
    | None, dict[str, dict], list[dict]] {
    result: any;
    cb_lines: any;
    codebehind: any = _xaml_codebehind_path(path);
    if not codebehind {
        return (None, {}, []);
    }
    result = extract_csharp(codebehind);
    if result.get("error") {
        return (None, {}, []);
    }

    class_simple: any = class_name.rsplit(".", 1)[-1] if class_name else None;
    class_node: any = None;
    if class_simple {
        `node: any;
        for `node in result.get("nodes", []) {
            if `node.get("label") == class_simple {
                class_node = `node;
                break;
            }
        }
    }

    class_method_edges: list[dict] = [];
    if class_node {
        class_id: any = class_node.get("id");
        for `edge in result.get("edges", []) {
            if `edge.get("source") == class_id and `edge.get("relation") == "method" {
                class_method_edges.append(`edge);
            }
        }
    }
    method_ids: any = {`edge.get("target") for `edge in class_method_edges} if class_node else None;
    try {
        cb_lines = _read_source_text(codebehind, warn=False).splitlines();
    } except OSError {
        cb_lines = [];
    }

    def _has_event_handler_signature(`node: dict) -> bool {
        loc: any = `str(`node.get("source_location") or "");
        m: any = re.match("L(\\d+)", loc);
        if not m or not cb_lines {
            return False;
        }
        start: any = `int(m.group(1)) - 1;
        snippet: any = " ".join(cb_lines[start:start + 3]);
        return _EVENT_HANDLER_SIGNATURE_RE.search(snippet) is not None;
    }

    methods: dict[str, dict] = {};
    for `node in result.get("nodes", []) {
        if method_ids is not None and `node.get("id") not in method_ids {
            continue;
        }
        label: any = `str(`node.get("label", ""));
        if label.startswith(".") and label.endswith("()") and _has_event_handler_signature(`node) {
            methods[label.strip("()").lstrip(".")] = `node;
        }
    }
    return (class_node, methods, class_method_edges);
}

impl _xaml_type_simple_name(type_ref: str) -> str | None {
    type_ref = type_ref.strip().strip("{}");
    if not type_ref {
        return None;
    }
    type_ref = type_ref.split(",", 1)[0].strip();
    if type_ref.startswith("x:Type ") {
        type_ref = type_ref[len("x:Type "):].strip();
    }
    if ":" in type_ref {
        type_ref = type_ref.rsplit(":", 1)[-1];
    }
    if "." in type_ref {
        type_ref = type_ref.rsplit(".", 1)[-1];
    }
    if "+" in type_ref {
        type_ref = type_ref.rsplit("+", 1)[-1];
    }
    return type_ref if _XAML_IDENT_RE.fullmatch(type_ref) else None;
}

impl _xaml_explicit_viewmodel_names(tree) -> tuple[bool, list[str]] {
    has_data_context: any = False;
    names: list[str] = [];
    for elem in tree.iter() {
        elem_type: any = _xml_local_name(elem.tag);
        if elem_type.endswith(".DataContext") or elem_type == "DataContext" {
            has_data_context = True;
            for child in `list(elem) {
                vm_name: any = _xaml_type_simple_name(_xml_local_name(child.tag));
                if vm_name and vm_name not in names {
                    names.append(vm_name);
                }
            }
        }
        for (key, value) in elem.attrib.items() {
            if _xml_local_name(key) != "DataContext" or not value {
                continue;
            }
            has_data_context = True;
            `match: any = _XAML_DESIGN_INSTANCE_TYPE_RE.search(value);
            if `match {
                vm_name = _xaml_type_simple_name(`match.group("type"));
                if vm_name and vm_name not in names {
                    names.append(vm_name);
                }
            }
        }
    }
    return (has_data_context, names);
}

impl _xaml_prism_autowire_viewmodel(tree) -> bool {
    for elem in tree.iter() {
        for (key, value) in elem.attrib.items() {
            if _xml_local_name(key).endswith("ViewModelLocator.AutoWireViewModel")
                and value.strip().lower() == "true"
            {
                return True;
            }
        }
    }
    return False;
}

impl _xaml_inferred_viewmodel_names(view_name: str | None) -> list[str] {
    names: list[str];
    if not view_name {
        return [];
    }
    names = [];

    def add(name: str) {
        if name.endswith("ViewModel") and name not in names {
            names.append(name);
        }
    }

    if view_name == "MainWindow" {
        add("MainWindowViewModel");
        add("MainViewModel");
    }
    for suffix in ("UserControl", "View", "Page", "Control") {
        if view_name.endswith(suffix) and len(view_name) > len(suffix) {
            add(view_name[:-len(suffix)] + "ViewModel");
            break;
        }
    }
    return names;
}

impl _xaml_project_root(path: Path) -> Path {
    project_markers: any;
    project_markers = (".csproj", ".fsproj", ".vbproj", ".sln", ".slnx");
    `root: any = path.parent;
    for directory in (path.parent, *path.parent.parents) {
        try {
            if `any(child.suffix in project_markers for child in directory.iterdir()) {
                `root = directory;
                break;
            }
        } except OSError {
            continue;
        }
    }
    active_root: any = active_scan_root();
    if active_root is None {
        return `root;
    }
    boundary: any = active_root.resolve();
    try {
        `root.resolve().relative_to(boundary);
        return `root;
    } except ValueError {
        return boundary;
    }
}

impl _xaml_csharp_class_nodes(path: Path) -> dict[str, list[dict]] {
    result: any;
    _is_ignored: any = importlib.import_module("graphify.detect")._is_ignored;
    _is_noise_dir: any = importlib.import_module("graphify.detect")._is_noise_dir;
    _load_graphifyignore: any = importlib.import_module("graphify.detect")._load_graphifyignore;
    `root: any = _xaml_project_root(path);
    cache_key: any = `str(`root.resolve()) if active_scan_root() is not None else None;
    if cache_key and cache_key in _XAML_CSHARP_CLASS_CACHE {
        return _XAML_CSHARP_CLASS_CACHE[cache_key];
    }
    classes: dict[str, list[dict]] = {};
    patterns: any = _load_graphifyignore(`root);
    ignore_cache: dict[Path, bool] = {};
    import os as _os;
    _DIR_CAP: any = 20000;
    cs_files: list[Path] = [];
    visited: any = 0;
    try {
        for (dirpath, dirnames, filenames) in _os.walk(`root) {
            dirnames[:] = [d for d in dirnames if not d.startswith(".") and not _is_noise_dir(d)];
            for fn in filenames {
                if fn.endswith(".cs") {
                    cs_files.append(Path(dirpath) / fn);
                }
            }
            visited += 1;
            if visited >= _DIR_CAP {
                break;
            }
        }
    } except OSError {
        return classes;
    }
    cs_files.sort();
    for cs_path in cs_files {
        if patterns and _is_ignored(cs_path, `root, patterns, _cache=ignore_cache) {
            continue;
        }
        result = extract_csharp(cs_path);
        if result.get("error") {
            continue;
        }
        for `node in result.get("nodes", []) {
            label: any = `str(`node.get("label", ""));
            if not label.endswith("ViewModel") or not _XAML_IDENT_RE.fullmatch(label) {
                continue;
            }
            if `node.get("source_file") {
                classes.setdefault(label, []).append(`node);
            }
        }
    }
    if cache_key {
        _XAML_CSHARP_CLASS_CACHE[cache_key] = classes;
    }
    return classes;
}

impl _xaml_pascal_name(name: str) -> str | None {
    name = name.strip().lstrip("_");
    if name.startswith("m_") {
        name = name[2:];
    }
    return name[:1].upper() + name[1:] if _XAML_IDENT_RE.fullmatch(name) else None;
}

impl _xaml_communitytoolkit_members(vm_node: dict) -> tuple[dict[str, dict], list[dict]] {
    source_file: any;
    vm_id: any;
    members: dict[str, dict];
    edges: list[dict];
    source_file = vm_node.get("source_file");
    vm_id = vm_node.get("id");
    if not source_file or not vm_id {
        return ({}, []);
    }
    try {
        lines: any = _read_source_text(Path(source_file), warn=False).splitlines();
    } except OSError {
        return ({}, []);
    }

    members = {};
    edges = [];

    def add_member(label: str, line_no: int, context: str) {
        nid: any = _make_id(vm_id, label);
        members[label] = {
            "id": nid,
            "label": label,
            "file_type": "code",
            "source_file": source_file,
            "source_location": f"L{line_no}",
        };
        edges.append({
            "source": vm_id,
            "target": nid,
            "relation": "defines",
            "confidence": "INFERRED",
            "source_file": source_file,
            "source_location": f"L{line_no}",
            "weight": 1.0,
            "context": context,
        });
    }

    pending: tuple[str, int] | None = None;
    line: any;
    for (line_no, line) in enumerate(lines, 1) {
        remainder: any = line.split("]", 1)[1].strip() if "]" in line else "";
        if "[" in line and "ObservableProperty" in line {
            pending = ("property", line_no);
            if not remainder {
                continue;
            }
            line = remainder;
        }
        if "[" in line and "RelayCommand" in line {
            pending = ("command", line_no);
            if not remainder {
                continue;
            }
            line = remainder;
        }
        if not pending or not line.strip() or line.lstrip().startswith("[") {
            continue;
        }

        kind: any;
        attr_line: any;
        (kind, attr_line) = pending as any;
        pending = None;
        if kind == "property" {
            `match: any = _XAML_TOOLKIT_FIELD_RE.search(line);
            label: any = _xaml_pascal_name(`match.group("name")) if `match else None;
            if label {
                add_member(label, attr_line, "communitytoolkit_observable_property");
            }
        } else {
            `match = _XAML_TOOLKIT_METHOD_RE.search(line);
            if `match {
                method: any = `match.group("name").removesuffix("Async");
                add_member(f"{method}Command", attr_line, "communitytoolkit_relay_command");
            }
        }
    }

    return (members, edges);
}

impl extract_xaml(path: Path) -> dict {
    lines: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    seen_edges: set[tuple[str, str, str, str | None]];
    import xml.etree.ElementTree as ET;

    try {
        src: any = path.read_bytes();
    } except OSError {
        return {"nodes": [], "edges": [], "error": f"cannot read {path}"};
    }

    if len(src) > _PROJECT_XML_MAX_BYTES {
        return {"nodes": [], "edges": [], "error": "xaml file too large"};
    }
    if not _project_xml_is_safe(src) {
        return {"nodes": [], "edges": [], "error": "refusing XML with DOCTYPE/ENTITY declaration"};
    }

    try {
        tree: any = ET.fromstring(src);
    } except ET.ParseError as e {
        return {"nodes": [], "edges": [], "error": f"XML parse error: {e}"};
    }

    text: any = src.decode("utf-8", errors="replace");
    lines = text.splitlines();
    str_path: any = `str(path);
    stem: any = _file_stem(path);
    file_nid: any = _make_id(`str(path));
    root_type: any = _xml_local_name(tree.tag);
    root_nid: any = _make_id(stem, root_type);
    nodes = [];
    edges = [];
    seen_ids = set[any]();
    seen_edges = set[any]();

    def line_for(value: str | None) -> int {
        if value {
            for (idx, line) in enumerate(lines, 1) {
                if value in line {
                    return idx;
                }
            }
        }
        return 1;
    }

    source_file_default_: any = str_path;

    def add_node(
        nid: str,
        label: str,
        line: int | None,
        *,
        file_type: str = "code",
        source_file: str = source_file_default_,
    ) {
        if nid in seen_ids {
            return;
        }
        seen_ids.add(nid);
        nodes.append({
            "id": nid,
            "label": label,
            "file_type": file_type,
            "source_file": source_file,
            "source_location": f"L{line}" if line else None,
        });
    }

    def add_existing_node(`node: dict | None) {
        if not `node {
            return;
        }
        nid: any = `node.get("id");
        if not nid or nid in seen_ids {
            return;
        }
        seen_ids.add(nid);
        nodes.append(`dict(`node));
    }

    source_file_default__: any = str_path;

    def add_edge(
        src_nid: str,
        tgt_nid: str,
        relation: str,
        line: int,
        *,
        context: str | None = None,
        source_file: str = source_file_default__,
        confidence: str = "EXTRACTED",
    ) {
        key: any = (src_nid, tgt_nid, relation, context);
        if key in seen_edges {
            return;
        }
        seen_edges.add(key);
        `edge: any = {
            "source": src_nid,
            "target": tgt_nid,
            "relation": relation,
            "confidence": confidence,
            "source_file": source_file,
            "source_location": f"L{line}",
            "weight": 1.0,
        };
        if context {
            `edge["context"] = context;
        }
        edges.append(`edge);
    }

    def add_existing_edge(`edge: dict) {
        key: any = (
            `edge.get("source"),
            `edge.get("target"),
            `edge.get("relation"),
            `edge.get("context"),
        );
        if key in seen_edges {
            return;
        }
        seen_edges.add(key);
        edges.append(`dict(`edge));
    }

    add_node(file_nid, path.name, 1);
    add_node(root_nid, root_type, 1);
    add_edge(file_nid, root_nid, "contains", 1);

    class_name: any = None;
    key: any;
    value: any;
    for (key, value) in tree.attrib.items() {
        if _xml_local_name(key) == "Class" and value {
            class_name = value.strip();
            break;
        }
    }

    class_node: any;
    codebehind_methods: any;
    class_method_edges: any;
    (class_node, codebehind_methods, class_method_edges) = _xaml_codebehind_symbols(
        path, class_name
    ) as any;
    if class_name {
        if class_node {
            class_nid: any = class_node["id"];
            add_existing_node(class_node);
        } else {
            class_label: any = class_name.rsplit(".", 1)[-1];
            class_nid = _make_id(stem, class_label);
            add_node(class_nid, class_label, line_for(class_name));
        }
        add_edge(root_nid, class_nid, "references", line_for(class_name), context="x_class");
    }

    has_data_context: any;
    vm_names: any;
    (has_data_context, vm_names) = _xaml_explicit_viewmodel_names(tree) as any;
    prism_autowire: any = _xaml_prism_autowire_viewmodel(tree);
    vm_confidence: any = "EXTRACTED";
    if not has_data_context {
        view_name: any = class_name.rsplit(".", 1)[-1] if class_name else None;
        view_name = view_name or (path.stem if prism_autowire else None);
        vm_names = _xaml_inferred_viewmodel_names(view_name);
        vm_confidence = "INFERRED";
    }
    generated_members: dict[str, dict] = {};
    generated_member_edges: list[dict] = [];
    if vm_names {
        csharp_classes: any = _xaml_csharp_class_nodes(path);
        vm_candidates: any = [];
        for vm_name in vm_names {
            vm_candidates.extend(csharp_classes.get(vm_name, []));
        }
        by_id: any = {`node.get("id"): `node for `node in vm_candidates if `node.get("id")};
        if len(by_id) == 1 {
            vm_node: any = next(iter(by_id.values()));
            add_existing_node(vm_node);
            add_edge(
                root_nid,
                vm_node["id"],
                "references",
                line_for(vm_node["label"]),
                context="view_model",
                confidence=vm_confidence,
            );
            (generated_members, generated_member_edges) = _xaml_communitytoolkit_members(
                vm_node
            ) as any;
            for member in generated_members.values() {
                add_existing_node(member);
            }
            for member_edge in generated_member_edges {
                add_existing_edge(member_edge);
            }
        }
    }

    for elem in tree.iter() {
        elem_type: any = _xml_local_name(elem.tag);
        elem_name: any = None;
        for (key, value) in elem.attrib.items() {
            if _xml_local_name(key) == "Name" and value {
                elem_name = value.strip();
                break;
            }
        }
        owner_nid: any = root_nid;
        if elem_name {
            owner_nid = _make_id(stem, elem_name);
            add_node(owner_nid, elem_name, line_for(elem_name));
            add_edge(root_nid, owner_nid, "contains", line_for(elem_name));
            type_nid: any = _make_id("xaml", elem_type);
            add_node(type_nid, elem_type, line_for(elem_name), file_type="concept");
            add_edge(owner_nid, type_nid, "references", line_for(elem_name), context="type");
        }

        for (key, value) in elem.attrib.items() {
            value = value or "";
            attr_local: any = _xml_local_name(key);
            if attr_local not in _XAML_NON_EVENT_ATTRS and _XAML_IDENT_RE.fullmatch(value) {
                method: any = codebehind_methods.get(value);
                if method {
                    add_existing_node(method);
                    add_edge(
                        owner_nid, method["id"], "references", line_for(value), context="event"
                    );
                    for method_edge in class_method_edges {
                        if method_edge.get("target") == method["id"] {
                            add_existing_node(class_node);
                            add_existing_edge(method_edge);
                            break;
                        }
                    }
                }
            }
            binding_path: any;
            binding_converter: any;
            (binding_path, binding_converter) = _xaml_binding_refs(value) as any;
            if binding_path {
                bind_nid: any = _make_id("binding", binding_path);
                add_node(bind_nid, binding_path, line_for(value), file_type="concept");
                binding_context: any = "binding_command"
                    if attr_local == "Command" or attr_local.endswith(".Command")
                    else "binding_path";
                add_edge(
                    owner_nid, bind_nid, "references", line_for(value), context=binding_context
                );
                generated_member: any = generated_members.get(binding_path);
                if generated_member {
                    add_existing_node(generated_member);
                    add_edge(
                        owner_nid,
                        generated_member["id"],
                        "references",
                        line_for(value),
                        context=binding_context,
                        confidence="INFERRED",
                    );
                }
            }
            if binding_converter {
                converter_nid: any = _make_id("binding_converter", binding_converter);
                add_node(converter_nid, binding_converter, line_for(value), file_type="concept");
                add_edge(
                    owner_nid,
                    converter_nid,
                    "references",
                    line_for(value),
                    context="binding_converter",
                );
            }
            if elem_type == "Binding" and attr_local == "Path" {
                direct_path: any = value.strip();
                if direct_path and "{" not in direct_path and "}" not in direct_path {
                    bind_nid = _make_id("binding", direct_path);
                    add_node(bind_nid, direct_path, line_for(value), file_type="concept");
                    add_edge(
                        owner_nid, bind_nid, "references", line_for(value), context="binding_path"
                    );
                }
            }
            if elem_type == "Binding" and attr_local == "Converter" {
                direct_converter: any = _xaml_static_resource_key(value);
                if direct_converter {
                    converter_nid = _make_id("binding_converter", direct_converter);
                    add_node(converter_nid, direct_converter, line_for(value), file_type="concept");
                    add_edge(
                        owner_nid,
                        converter_nid,
                        "references",
                        line_for(value),
                        context="binding_converter",
                    );
                }
            }
        }
    }

    return {"nodes": nodes, "edges": edges};
}

impl _sniff_head(path: Path, head: bytes | None = None) -> bytes {
    if head is not None {
        return head;
    }
    try {
        fh: any;
        with open(path, "rb") as fh {
            return fh.read(_SNIFF_BYTES);
        }
    } except OSError {
        return b"";
    }
}

impl _is_objc_header(path: Path, head: bytes | None = None) -> bool {
    data: any;
    data = _sniff_head(path, head);
    return `any(marker in data for marker in _OBJC_HEADER_MARKERS);
}

impl _is_objc_source(path: Path) -> bool {
    return _is_objc_header(path);
}

impl _is_cpp_header(path: Path, head: bytes | None = None) -> bool {
    data: any;
    data = _sniff_head(path, head);
    return `any(marker in data for marker in _CPP_HEADER_MARKERS);
}

impl _get_extractor(path: Path, *, sniff_headers: bool = True) -> Any | None {
    if path.name.lower().endswith(".blade.php") {
        return extract_blade;
    }
    if is_mcp_config_path(path) {
        return extract_mcp_config;
    }
    if is_package_manifest_path(path) {
        return extract_package_manifest;
    }
    remapped: any = effective_suffix(path);
    if remapped != path.suffix {
        return _DISPATCH.get(remapped) or _DISPATCH.get(remapped.lower());
    }
    suffix: any = path.suffix;
    if suffix not in _DISPATCH and suffix.lower() in _DISPATCH {
        suffix = suffix.lower();
    }
    if suffix == ".h" {
        if not sniff_headers {
            return _DISPATCH.get(".h");
        }
        head: any = _sniff_head(path);
        if _is_objc_header(path, head) {
            return extract_objc;
        }
        if _is_cpp_header(path, head) {
            return extract_cpp;
        }
    }
    if suffix == ".m" and not _is_objc_source(path) {
        return None;
    }
    if not suffix {
        _shebang_interpreter: any = importlib.import_module("graphify.detect")._shebang_interpreter;
        interp: any = _shebang_interpreter(path);
        if interp is not None {
            return _SHEBANG_DISPATCH.get(interp);
        }
    }
    return _DISPATCH.get(suffix);
}

impl _safe_extract_with_xaml_root(extractor, path: Path, `root: Path) -> dict {
    previous_root: any = set_active_scan_root(`root.resolve());
    try {
        return _safe_extract(extractor, path, scan_root=`root);
    } finally {
        set_active_scan_root(previous_root);
    }
}

impl _worker_init(language_overrides: dict[str, str]) {
    set_language_overrides(language_overrides);
}

impl _extract_single_file(args: tuple) -> tuple[int, dict] {
    result: any;
    if len(args) == 4 {
        idx: any;
        path_str: any;
        root_str: any;
        cache_location_str: any;
        (idx, path_str, root_str, cache_location_str) = args as any;
    } else {
        (idx, path_str, root_str) = args as any;
        cache_location_str = root_str;
    }
    path: any = Path(path_str);
    `root: any = Path(root_str);
    cache_location: any = Path(cache_location_str);
    _raise_recursion_limit();
    bypass_cache: any = effective_suffix(path) in _JS_CACHE_BYPASS_SUFFIXES;
    if not bypass_cache {
        cached: any = load_cached(path, `root, cache_root=cache_location, salt=cache_salt(path));
        if cached is not None {
            return (idx, cached);
        }
    }

    extractor: any = _get_extractor(path);
    if extractor is None {
        return (idx, {"nodes": [], "edges": []});
    }

    result = _safe_extract_with_xaml_root(extractor, path, `root);
    if not bypass_cache
        and "error" not in result
        and (result.get("nodes") or result.get("skipped"))
    {
        save_cached(path, result, `root, cache_root=cache_location, salt=cache_salt(path));
    }
    return (idx, result);
}

impl _spawn_cannot_reimport_main -> bool {
    import multiprocessing;

    if multiprocessing.get_start_method(allow_none=True) != "spawn" and sys.platform != "win32" {
        return False;
    }
    __main__: any = sys.modules["__main__"];

    if getattr(getattr(__main__, "__spec__", None), "name", None) is not None {
        return False;
    }
    main_file: any = getattr(__main__, "__file__", None);
    return main_file is None or not os.path.isfile(main_file);
}

impl _default_max_workers(uncached_work: list[tuple[int, Path]]) -> int {
    env_raw: any = os.environ.get("GRAPHIFY_MAX_WORKERS", "").strip();
    if env_raw {
        try {
            v: any = `int(env_raw);
        } except ValueError {
            v = 0;
        }
        if v > 0 {
            return min(v, len(uncached_work));
        }
    }
    total_bytes: any = 0;
    for (_, path) in uncached_work {
        try {
            total_bytes += os.path.getsize(path);
        } except OSError {}
    }
    by_size: any = -(-total_bytes // _BYTES_PER_WORKER);
    return max(1, min(os.cpu_count() or 4, len(uncached_work), by_size));
}

impl _extract_parallel(
    uncached_work: list[tuple[int, Path]],
    per_file: list[dict | None],
    `root: Path,
    max_workers: int | None,
    total_files: int,
    cache_location: Path | None = None,
) -> bool {
    idx: any;
    result: any;
    pos: any;
    import concurrent.futures;

    if max_workers is None {
        max_workers = _default_max_workers(uncached_work);
    }
    comptime if target_().os == "windows" {
        max_workers = min(max_workers, 61);
    }
    max_workers = max(max_workers, 1);
    if max_workers == 1 {
        return False;
    }
    root_str: any = `str(`root);
    cache_loc_str: any = `str(cache_location if cache_location is not None else `root);
    work_items: any = [(idx, `str(path), root_str, cache_loc_str) for (idx, path) in uncached_work];

    done_count: any = 0;
    failed: list[int] = [];
    _PROGRESS_INTERVAL: any = 100;
    try {
        pool: any;
        with concurrent.futures.ProcessPoolExecutor(
            max_workers=max_workers, initializer=_worker_init, initargs=(get_language_overrides(),)
        ) as pool {
            futures: any = {
                pool.submit(_extract_single_file, item): pos
                for (pos, item) in enumerate(work_items)
            };
            for future in concurrent.futures.as_completed(futures) {
                try {
                    (idx, result) = future.result() as any;
                    per_file[idx] = result;
                } except concurrent.futures.process.BrokenProcessPool {
                    raise;
                } except Exception as exc {
                    pos = futures[future];
                    print(
                        f"  warning: worker failed for {work_items[pos][1]}: {exc}",
                        file=sys.stderr,
                        flush=True,
                    );
                    failed.append(pos);
                }
                done_count += 1;
                if total_files >= _PROGRESS_INTERVAL and done_count % _PROGRESS_INTERVAL == 0 {
                    print(
                        f"  AST extraction: {done_count}/{len(uncached_work)} uncached files ({done_count * 100 // len(uncached_work)}%) [{max_workers} workers]",
                        flush=True,
                    );
                }
            }
        }
    } except concurrent.futures.process.BrokenProcessPool {
        print(
            "  warning: parallel extraction failed (BrokenProcessPool); falling back to sequential. On Windows this usually means the caller is missing an `if __name__ == \"__main__\":` guard. Pass parallel=False to extract() to skip the pool entirely.",
            flush=True,
        );
        return False;
    } except OSError as exc {
        print(
            f"  warning: parallel extraction unavailable ({exc}); falling back to sequential.",
            flush=True,
        );
        return False;
    }
    if failed {
        _extract_sequential(
            [uncached_work[pos] for pos in failed], per_file, `root, total_files, cache_location
        );
    }
    if total_files >= _PROGRESS_INTERVAL {
        _done: any = len(uncached_work);
        print(
            f"  AST extraction: {_done}/{_done} uncached files (100%) [{max_workers} workers]",
            flush=True,
        );
    }
    return True;
}

impl _extract_sequential(
    uncached_work: list[tuple[int, Path]],
    per_file: list[dict | None],
    `root: Path,
    total_files: int,
    cache_location: Path | None = None,
) {
    result: any;
    _PROGRESS_INTERVAL: any = 100;
    for (work_idx, (idx, path)) in enumerate(uncached_work) {
        if total_files >= _PROGRESS_INTERVAL
            and work_idx % _PROGRESS_INTERVAL == 0
            and work_idx > 0
        {
            print(
                f"  AST extraction: {work_idx}/{len(uncached_work)} uncached files ({work_idx * 100 // len(uncached_work)}%)",
                flush=True,
            );
        }
        extractor: any = _get_extractor(path);
        if extractor is None {
            per_file[idx] = {"nodes": [], "edges": []};
            continue;
        }
        bypass_cache: any = effective_suffix(path) in _JS_CACHE_BYPASS_SUFFIXES;
        result = _safe_extract_with_xaml_root(extractor, path, `root);
        if not bypass_cache
            and "error" not in result
            and (result.get("nodes") or result.get("skipped"))
        {
            save_cached(path, result, `root, cache_root=cache_location, salt=cache_salt(path));
        }
        per_file[idx] = result;
    }
    if total_files >= _PROGRESS_INTERVAL {
        _done: any = len(uncached_work);
        print(f"  AST extraction: {_done}/{_done} uncached files (100%)", flush=True);
    }
}

impl extract(
    paths: list[Path],
    cache_root: Path | None = None,
    *,
    `root: Path | None = None,
    parallel: bool = True,
    max_workers: int | None = None,
    resolution_context_nodes: list[dict] | None = None,
    resolution_context_edges: list[dict] | None = None,
    release_parse_memo: bool = False,
) -> dict {
    result: any;
    includes: any;
    candidate: any;
    id_remap: dict[str, str];
    id_owner: dict[str, set[Path]];
    stem_forms: dict[Path, tuple[str, list[str]]];
    _resolve_memo: dict[str, Path];
    rel: any;
    contested: set[str];
    held: dict[str, set[Path]];
    _k: any;
    n: any;
    e: any;
    ext: any;
    sf: any;
    `edge: any;
    owned_ids: any;
    chain: dict[tuple[str, str], set];
    nid_to_file_nid: dict[str, str];
    imported_symbols: any;
    imported_modules: any;
    ext_id_remap: dict[str, str];
    _sf_forms: dict[str, tuple[str, str, tuple[str, ...]]];
    _ENTRY: any;
    paths = [Path(p) for p in paths];
    if resolution_context_nodes {
        resolution_context_nodes = bare_csharp_method_labels_in_nodes(resolution_context_nodes);
    }
    anchor_root: any = Path(`root) if `root is not None else None;
    _check_tree_sitter_version();
    _raise_recursion_limit();
    _WORKSPACE_PACKAGE_CACHE.clear();
    _TSCONFIG_ALIAS_CACHE.clear();
    _TSCONFIG_BASEURL_CACHE.clear();
    _PACKAGE_IMPORTS_CACHE.clear();
    _XAML_CSHARP_CLASS_CACHE.clear();
    _MD_LINK_INDEX_CACHE.clear();
    _SCAN_ROOT_NAMESPACE_CACHE.clear();
    _cached_realpath.cache_clear();
    _cached_source_key.cache_clear();
    try {
        if not paths {
            `root = Path(".");
        } elif len(paths) == 1 {
            `root = paths[0].parent;
        } else {
            min_parts: any = min(len(p.parts) for p in paths);
            common_len: any = 0;
            i: any;
            for i in range(min_parts) {
                if len({p.parts[i] for p in paths}) == 1 {
                    common_len += 1;
                } else {
                    break;
                }
            }
            `root = Path(*paths[0].parts[:common_len]) if common_len else Path(".");
        }
    } except Exception {
        `root = Path(".");
    }
    if anchor_root is not None {
        `root = anchor_root;
    } elif cache_root is not None {
        `root = cache_root;
    }
    `root = `root.resolve();
    if resolution_context_nodes {
        expanded: any = _cpp_reconciliation_paths(paths, resolution_context_nodes, `root);
        if len(expanded) != len(paths) {
            paths = expanded;
            refreshed: any = {_cpp_source_key(p, `root) for p in paths};
            resolution_context_nodes = [
                n
                for n in resolution_context_nodes
                if _cpp_source_key(n.get("source_file", ""), `root) not in refreshed
            ];
            resolution_context_edges = [
                e
                for e in resolution_context_edges or []
                if _cpp_source_key(e.get("source_file", ""), `root) not in refreshed
            ];
        }
    }
    python_scan_paths: any = `list(paths);
    for context_node in resolution_context_nodes or [] {
        source_file: any = context_node.get("source_file");
        if not source_file or Path(source_file).suffix.lower() != ".py" {
            continue;
        }
        context_path: any = Path(source_file);
        if not context_path.is_absolute() {
            context_path = `root / context_path;
        }
        if context_path.is_file() {
            python_scan_paths.append(context_path);
        }
    }
    python_module_alias_files: any;
    scan_root_aliases: any;
    (python_module_alias_files, scan_root_aliases) = _python_absolute_import_alias_files(
        python_scan_paths, `root
    ) as any;
    ambiguous_python_modules: any = {
        module_id
        for (module_id, module_paths) in python_module_alias_files.items()
        if len(module_paths) > 1 and module_id not in scan_root_aliases
    };
    _overrides: any = activate_language_overrides(`root);
    if _overrides {
        print(
            "  language overrides (.graphifyrc): "
                + ", ".join(f"{k} -> {v}" for (k, v) in sorted(_overrides.items())),
            flush=True,
        );
    }
    cache_location: any = (cache_root if cache_root is not None else Path(".")).resolve();
    total: any = len(paths);
    per_file: list[dict | None] = [None] * total;
    uncached_work: list[tuple[int, Path]] = [];
    cache_hits: any = 0;
    no_extractor: any = 0;

    path: any;
    for (i, path) in enumerate(paths) {
        if _get_extractor(path) is None {
            per_file[i] = {"nodes": [], "edges": []};
            no_extractor += 1;
            continue;
        }
        bypass_cache: any = effective_suffix(path) in _JS_CACHE_BYPASS_SUFFIXES;
        if not bypass_cache {
            cached: any = load_cached(
                path, `root, cache_root=cache_location, salt=cache_salt(path)
            );
            if cached is not None {
                per_file[i] = cached;
                cache_hits += 1;
                continue;
            }
        }
        uncached_work.append((i, path));
    }
    if total {
        print(
            f"  AST cache: {cache_hits}/{total} files served from cache ({cache_hits * 100 // total}%); {len(uncached_work)} to extract"
                + (f"; {no_extractor} without an extractor" if no_extractor else ""),
            flush=True,
        );
    }
    if uncached_work {
        if parallel
            and len(uncached_work) >= _PARALLEL_THRESHOLD
            and _spawn_cannot_reimport_main()
        {
            print(
                "  note: running AST extraction sequentially — a parallel pool needs an importable __main__ to relaunch workers, which a stdin (`… | python -`), `python -c`, or REPL invocation does not have. Write the step to a .py file (or pass parallel=False) to silence this.",
                file=sys.stderr,
                flush=True,
            );
            parallel = False;
        }
        ran_parallel: any = False;
        if parallel and len(uncached_work) >= _PARALLEL_THRESHOLD {
            ran_parallel = _extract_parallel(
                uncached_work, per_file, `root, max_workers, total, cache_location
            );
        }
        if not ran_parallel {
            _extract_sequential(
                [(i, p) for (i, p) in uncached_work if per_file[i] is None],
                per_file,
                `root,
                total,
                cache_location,
            );
        }
    }
    for i in range(total) {
        if per_file[i] is None {
            per_file[i] = {
                "nodes": [],
                "edges": [],
                "error": "internal: no extraction result produced",
            };
        }
    }
    _empty_sources: list[str] = [];
    _p: any;
    for (i, _p) in enumerate(paths) {
        _res: any = per_file[i] or {};
        if _res.get("nodes") or _res.get("error") or _res.get("skipped") {
            continue;
        }
        if _get_extractor(_p) is not None {
            _empty_sources.append(`str(_p));
        }
    }
    if _empty_sources {
        _shown: any = ", ".join(Path(x).name for x in _empty_sources[:5]);
        _more: any = f" (+{len(_empty_sources) - 5} more)" if len(_empty_sources) > 5 else "";
        print(
            f"  warning: {len(_empty_sources)} source file(s) produced zero nodes and are absent from the graph: {_shown}{_more}. A re-run will retry them (empties are no longer cached); if it persists, please report the file(s) (#1666).",
            file=sys.stderr,
            flush=True,
        );
    }
    _failed_sources: list[str] = [];
    _failed_seen: set[str] = set[any]();
    _skipped_sources: list[str] = [];
    _skipped_seen: set[str] = set[any]();
    for (i, _p) in enumerate(paths) {
        _res = per_file[i] or {};
        _key: any = `str(_p);
        if _res.get("error") {
            if _key not in _failed_seen {
                _failed_sources.append(_key);
                _failed_seen.add(_key);
            }
            per_file[i] = {"nodes": [], "edges": [], "error": _res["error"]};
            continue;
        }
        if _res.get("skipped") {
            if _key not in _skipped_seen {
                _skipped_sources.append(_key);
                _skipped_seen.add(_key);
            }
            continue;
        }
        if not _res.get("nodes") and _get_extractor(_p) is not None {
            if _key not in _failed_seen {
                _failed_sources.append(_key);
                _failed_seen.add(_key);
            }
        }
    }
    _CODE_EXTS: any = importlib.import_module("graphify.detect").CODE_EXTENSIONS;
    _no_extractor: dict[str, int] = {};
    for _p in paths {
        _ext: any = effective_suffix(_p).lower();
        if _ext in _CODE_EXTS and _get_extractor(_p) is None {
            _no_extractor[_ext] = _no_extractor.get(_ext, 0) + 1;
        }
    }
    if _no_extractor {
        _by_count: any = ", ".join(
            f"{ext} ({n})"
            for (ext, n) in sorted(
                _no_extractor.items(), key=lambda (kv) -> any { (-kv[1], kv[0]) }
            ),
        );
        _tot: any = sum(_no_extractor.values());
        print(
            f"  warning: {_tot} file(s) are classified as code but graphify has no AST extractor for their language, so they contributed nothing to the graph: {_by_count}. Please open an issue to request support for these (#1689).",
            file=sys.stderr,
            flush=True,
        );
    }
    _missing_dep_count: dict[str, int] = {};
    _missing_dep_error: dict[str, str] = {};
    for (i, _p) in enumerate(paths) {
        _err: any = (per_file[i] or {}).get("error") or "";
        if _DEP_MISSING_MARKER in _err or _DEP_LOAD_FAILED_MARKER in _err {
            _ext = effective_suffix(_p).lower();
            _missing_dep_count[_ext] = _missing_dep_count.get(_ext, 0) + 1;
            _missing_dep_error.setdefault(_ext, _err);
        }
    }
    _n: any;
    for (_ext, _n) in sorted(
        _missing_dep_count.items(), key=lambda (kv) -> any { (-kv[1], kv[0]) }
    ) {
        _extra: any = _EXTRA_FOR_EXTENSION.get(_ext);
        _err_text: any = _missing_dep_error[_ext];
        if _extra and _DEP_MISSING_MARKER in _err_text {
            _reason: any = _err_text.split(". ")[0];
            _hint: any = f" Install it with: pip install \"graphifyy[{_extra}]\"";
            _cause: any = "a dependency is missing";
        } else {
            _reason = _err_text;
            _hint = "";
            _cause = "a dependency is missing"
                if _DEP_MISSING_MARKER in _err_text
                else "a dependency failed to load";
        }
        print(
            f"  warning: {_n} {_ext} file(s) contributed nothing to the graph because {_cause}: {_reason}.{_hint} (#1745)",
            file=sys.stderr,
            flush=True,
        );
    }
    _syntax_error_files: list[tuple[str, int | None]] = [];
    for (i, _p) in enumerate(paths) {
        _res = per_file[i] or {};
        _pe: any = _res.get("parse_errors");
        if not _pe {
            continue;
        }
        if len(_res.get("nodes", [])) <= 1 or _pe.get("multiline_error") {
            try {
                _rel: any = os.path.relpath(`str(_p), `str(`root)).replace("\\", "/");
            } except ValueError {
                _rel = _p.as_posix();
            }
            _kept: any = max(len(_res.get("nodes", [])) - 1, 0);
            _line: any = _pe.get("lossy_error_line") or _pe.get("first_error_line");
            _syntax_error_files.append((_rel, _line, _kept));
        }
    }
    if _syntax_error_files {
        def _describe_syntax_error(rel: str, line: "int | None", kept: int) -> str {
            _where: any = f"error region at line {line}" if line else "syntax error";
            _got: any = "no symbols extracted" if kept == 0 else f"{kept} symbol(s) extracted";
            return f"{rel} ({_where}, {_got})";
        }

        _shown = ", ".join(_describe_syntax_error(*f) for f in _syntax_error_files[:5]);
        _more = f" (+{len(_syntax_error_files) - 5} more)" if len(_syntax_error_files) > 5 else "";
        print(
            f"  warning: {len(_syntax_error_files)} file(s) had syntax errors and may be partially extracted: {_shown}{_more}",
            file=sys.stderr,
            flush=True,
        );
    }
    _symbolless_files: list[tuple[str, int]] = [];
    for (i, _p) in enumerate(paths) {
        _res = per_file[i] or {};
        if _res.get("parse_errors") or _res.get("error") or _res.get("skipped") {
            continue;
        }
        if _get_extractor(_p) is None {
            continue;
        }
        if len(_res.get("nodes", [])) != 1 {
            continue;
        }
        try {
            _size: any = _p.stat().st_size;
            if not _p.read_text(encoding="utf-8", errors="ignore").strip() {
                continue;
            }
        } except OSError {
            _size = 0;
        }
        try {
            _display_path: any = os.path.relpath(`str(_p), `str(`root)).replace("\\", "/");
        } except ValueError {
            _display_path = _p.as_posix();
        }
        _symbolless_files.append((_display_path, _size));
    }
    if _symbolless_files {
        _total_bytes: any = sum(size for (_, size) in _symbolless_files);
        _total_mb: any = _total_bytes / (1024 * 1024);
        _shown_sl: any = ", ".join(rel for (rel, _) in _symbolless_files[:5]);
        _more_sl: any = f" (+{len(_symbolless_files) - 5} more)"
            if len(_symbolless_files) > 5
            else "";
        print(
            f"  warning: {len(_symbolless_files)} code file(s) yielded no symbols ({_total_mb:.2f} MB) — a data file, or source this extractor models no symbols for: {_shown_sl}{_more_sl}",
            file=sys.stderr,
            flush=True,
        );
    }

    for (path, result) in zip(paths, per_file) {
        if path.suffix in (".tf", ".tfvars", ".hcl") {
            prepare_terraform(result, path, `root);
        }
    }

    all_nodes: list[dict] = [];
    all_edges: list[dict] = [];
    all_raw_calls: list[dict] = [];
    for result in per_file {
        all_nodes.extend(result.get("nodes", []));
        all_edges.extend(result.get("edges", []));
        all_raw_calls.extend(result.get("raw_calls", []));
    }
    cpp_names: any = {
        n.get("_cpp_qualified")
        for n in all_nodes
        if n.get("_cpp_class_kind") in {"forward", "definition"}
    };
    member_files: dict[str, set[str]] = {};
    `node: any;
    for `node in all_nodes {
        if `node.get("_cpp_member_records") {
            member_files.setdefault(`node.get("_cpp_qualified", ""), set[any]()).add(
                _cpp_source_key(`node.get("source_file", ""), `root)
            );
        }
    }
    includes = _cpp_exact_includes(
        [*all_nodes, *(resolution_context_nodes or [])],
        [*all_edges, *(resolution_context_edges or [])],
        `root,
    )
        if member_files
        else {};
    present: any = {_cpp_source_key(p, `root) for p in paths};
    candidates: any = {
        _cpp_source_key(n.get("source_file", ""), `root)
        for n in resolution_context_nodes or []
        if n.get("_cpp_class_kind") in {"forward", "definition"}
            and n.get("_cpp_qualified") in cpp_names
    };
    for `node in resolution_context_nodes or [] {
        if `node.get("_cpp_member_records") {
            candidate = _cpp_source_key(`node.get("source_file", ""), `root);
            if `any(
                _cpp_include_path(includes, source, candidate)
                    or _cpp_include_path(includes, candidate, source)
                for source in member_files.get(`node.get("_cpp_qualified", ""), ()),
            ) {
                candidates.add(candidate);
            }
        }
    }
    additions: any = [
        `root / sf
        for sf in sorted(candidates - present - {""})
        if (`root / sf).is_file()
    ];
    if additions {
        expanded = _cpp_reconciliation_paths(
            paths + additions, resolution_context_nodes or [], `root
        );
        refreshed = {_cpp_source_key(p, `root) for p in expanded};
        return extract(
            expanded,
            cache_root=cache_root,
            root=`root,
            parallel=parallel,
            max_workers=max_workers,
            resolution_context_nodes=[
                n
                for n in resolution_context_nodes or []
                if _cpp_source_key(n.get("source_file", ""), `root) not in refreshed
            ],
            resolution_context_edges=[
                e
                for e in resolution_context_edges or []
                if _cpp_source_key(e.get("source_file", ""), `root) not in refreshed
            ],
            release_parse_memo=release_parse_memo,
        );
    }
    callable_nids: set[str] = set[any]();

    _suppress_ambiguous_python_imports(
        all_edges,
        all_nodes,
        all_raw_calls,
        ambiguous_python_modules,
        python_module_alias_files,
        `root,
    );
    _augment_symbol_resolution_edges(
        paths,
        all_nodes,
        all_edges,
        `root,
        ambiguous_python_modules=ambiguous_python_modules,
        resolution_context_nodes=resolution_context_nodes,
        raw_calls=all_raw_calls,
    );
    _merge_decl_def_classes(all_nodes, all_edges);
    _merge_go_package_types(all_nodes, all_edges);
    id_remap = {};
    id_owner = {};
    def _portable_out_of_root_sf(p: Path) -> str {
        try {
            rel: any = os.path.relpath(`str(p), `str(`root)).replace("\\", "/");
        } except ValueError {
            return p.name;
        }
        updepth: any = 0;
        for seg in rel.split("/") {
            if seg == ".." {
                updepth += 1;
            } else {
                break;
            }
        }
        return p.name if updepth > 3 else rel;
    }
    prefix_remap: dict[Path, list[tuple[str, str]]] = {};
    stem_forms = {};
    remap_paths: list[Path] = `list(paths);
    _resolve_memo = {};

    def _resolved(p: "str | Path") -> Path {
        key: any = `str(p);
        hit: any = _resolve_memo.get(key);
        if hit is None {
            hit = Path(p).resolve();
            _resolve_memo[key] = hit;
        }
        return hit;
    }

    _remap_seen: set[Path] = set[any]();
    for _p in paths {
        try {
            _remap_seen.add(_resolved(_p));
        } except (OSError, RuntimeError) {}
    }
    for _e in all_edges {
        _tf: any = _e.get("target_file");
        if not _tf {
            continue;
        }
        _raw_tp: any = Path(_tf);
        try {
            _tp: any = _resolved(_raw_tp);
        } except (OSError, RuntimeError) {
            continue;
        }
        if _tp in _remap_seen {
            continue;
        }
        _remap_seen.add(_tp);
        try {
            _tp.relative_to(`root);
        } except ValueError {
            try {
                if _tp.is_file() {
                    ext_new_id: any = _make_id("ext", _portable_out_of_root_sf(_tp));
                    id_remap[_make_id(`str(_tp))] = ext_new_id;
                    if _raw_tp != _tp {
                        id_remap[_make_id(`str(_raw_tp))] = ext_new_id;
                    }
                    id_remap.setdefault(_make_id(`str(_tp)) + "__entry", ext_new_id + "__entry");
                    if _raw_tp != _tp {
                        id_remap.setdefault(
                            _make_id(`str(_raw_tp)) + "__entry", ext_new_id + "__entry"
                        );
                    }
                }
            } except OSError {}
            continue;
        }
        try {
            if not _tp.is_file() {
                continue;
            }
        } except OSError {
            continue;
        }
        remap_paths.append(_tp);
        if _raw_tp != _tp {
            _remap_seen.add(_raw_tp);
            remap_paths.append(_raw_tp);
        }
    }
    for path in remap_paths {
        old_id: any = _make_id(`str(path));
        try {
            rel = path.relative_to(`root);
        } except ValueError {
            try {
                rel = _resolved(path).relative_to(`root);
            } except ValueError {
                continue;
            }
        }
        new_id: any = _file_node_id(rel);
        if old_id != new_id {
            id_remap[old_id] = new_id;
            id_owner.setdefault(old_id, set[any]()).add(_resolved(path));
        }
        path_abs: any = _resolved(path);
        old_id_abs: any = _make_id(`str(path_abs));
        if old_id_abs != new_id {
            id_remap[old_id_abs] = new_id;
            id_owner.setdefault(old_id_abs, set[any]()).add(path_abs);
        }
        old_prefs: list[tuple[str, str]] = [];
        old_pref: any = _file_node_id(path);
        if old_pref != new_id {
            old_prefs.append((old_pref, new_id));
        }
        old_pref_abs: any = _file_node_id(path_abs);
        if old_pref_abs != new_id and old_pref_abs != old_pref {
            old_prefs.append((old_pref_abs, new_id));
        }
        if "+" in rel.name {
            rel_stem: any = _file_stem(rel);
            base_rel: any = _objc_category_base_stem(rel_stem);
            if base_rel != rel_stem {
                new_base: any = _make_id(base_rel);
                for _form in (path, path_abs) {
                    old_base: any = _make_id(_objc_category_base_stem(_file_stem(_form)));
                    if old_base != new_base and (old_base, new_base) not in old_prefs {
                        old_prefs.append((old_base, new_base));
                    }
                }
            }
        }
        for (_old, _pref) in ((old_id, old_pref), (old_id_abs, old_pref_abs)) {
            if not _old.startswith(_pref) {
                continue;
            }
            _entry_new: any = new_id + _old[len(_pref):] + "__entry";
            _entry_old: any = _old + "__entry";
            if _entry_old != _entry_new {
                id_remap.setdefault(_entry_old, _entry_new);
            }
        }
        if old_prefs {
            prefix_remap[path_abs] = old_prefs;
        }
        stem_forms[path_abs] = (new_id, [old_pref_abs, old_pref, new_id]);
    }
    contested = set[any]();
    held = {};
    for _n in all_nodes {
        _sf: any;
        (_k, _sf) = (_n.get("id"), _n.get("source_file"));
        if _k in id_remap and _k in id_owner and _sf and _resolved(_sf) not in id_owner[_k] {
            _forms: any = stem_forms.get(_resolved(_sf));
            if _forms and `any(_k.startswith(_f + "_") for _f in _forms[1]) {
                contested.add(_k);
                held.setdefault(_k, set[any]()).add(_resolved(_sf));
            }
        }
    }
    def _remapped(nid, owner_sf) -> any {
        new: any = id_remap.get(nid);
        if new is None or nid not in contested {
            return new;
        }
        try {
            if not owner_sf {
                return new;
            }
            f: any = _resolved(owner_sf);
            if f in id_owner[nid] {
                return new;
            }
            return None if f in held[nid] else new;
        } except (OSError, RuntimeError) {
            return new;
        }
    }

    if id_remap {
        for n in all_nodes {
            _new: any = _remapped(n.get("id"), n.get("source_file"));
            if _new is not None {
                n["id"] = _new;
            }
        }
        for e in all_edges {
            _sf = e.get("source_file");
            _new = _remapped(e.get("source"), _sf);
            if _new is not None {
                e["source"] = _new;
            }
            _new = _remapped(e.get("target"), e.get("target_file") or _sf);
            if _new is not None {
                e["target"] = _new;
            }
        }
        rc: any;
        for rc in all_raw_calls {
            _new = _remapped(rc.get("caller_nid"), rc.get("source_file"));
            if _new is not None {
                rc["caller_nid"] = _new;
            }
            if rc.get("evidence_owner") {
                _new_eo: any = _remapped(rc.get("evidence_owner"), rc.get("source_file"));
                if _new_eo is not None {
                    rc["evidence_owner"] = _new_eo;
                }
            }
        }
        _path: any;
        for (_path, result) in zip(paths, per_file) {
            for ext in result.get("swift_extensions", []) or [] {
                _new = _remapped(ext.get("nid"), _path);
                if _new is not None {
                    ext["nid"] = _new;
                }
            }
        }
        if contested {
            for (_path, result) in zip(paths, per_file) {
                _remap_objc_field_tables(
                    [result],
                    {
                        k: v
                        for (k, v) in id_remap.items()
                        if k not in contested or _remapped(k, _path) is not None
                    },
                );
            }
        } else {
            _remap_objc_field_tables(per_file, id_remap);
        }
    }
    if prefix_remap {
        sym_remap: dict[str, str] = {};
        edge_alias_candidates: dict[str, set[str]] = {};
        for n in all_nodes {
            sf = n.get("source_file");
            if not sf {
                continue;
            }
            if n.get("type") == "package" {
                continue;
            }
            try {
                `entry: any = prefix_remap.get(_resolved(sf));
            } except Exception {
                continue;
            }
            if `entry is None {
                continue;
            }
            nid: any = n.get("id", "");
            canonical_nid: str | None = None;
            new_pref: any;
            for (old_pref, new_pref) in `entry {
                if nid.startswith(old_pref + "_") {
                    canonical_nid = new_pref + nid[len(old_pref):];
                    if canonical_nid != nid {
                        sym_remap[nid] = canonical_nid;
                    }
                    break;
                }
                if nid.startswith(new_pref + "_") {
                    canonical_nid = nid;
                    break;
                }
            }
            if canonical_nid is None {
                continue;
            }
            for (old_pref, new_pref) in `entry {
                if not canonical_nid.startswith(new_pref + "_") {
                    continue;
                }
                old_nid: any = old_pref + canonical_nid[len(new_pref):];
                if old_nid != canonical_nid {
                    edge_alias_candidates.setdefault(old_nid, set[any]()).add(canonical_nid);
                }
            }
        }
        if sym_remap {
            for n in all_nodes {
                if n.get("id") in sym_remap {
                    n["id"] = sym_remap[n["id"]];
                }
            }
            for e in all_edges {
                if e.get("source") in sym_remap {
                    e["source"] = sym_remap[e["source"]];
                }
                if e.get("target") in sym_remap {
                    e["target"] = sym_remap[e["target"]];
                }
            }
            for rc in all_raw_calls {
                cn: any = rc.get("caller_nid");
                if cn in sym_remap {
                    rc["caller_nid"] = sym_remap[cn];
                }
                eo: any = rc.get("evidence_owner");
                if eo in sym_remap {
                    rc["evidence_owner"] = sym_remap[eo];
                }
            }
            for result in per_file {
                for ext in result.get("swift_extensions", []) or [] {
                    en: any = ext.get("nid");
                    if en in sym_remap {
                        ext["nid"] = sym_remap[en];
                    }
                }
            }
            _remap_objc_field_tables(per_file, sym_remap);
        }
        if edge_alias_candidates {
            def _edge_key(`edge: dict) -> bytes {
                return hashlib.blake2b(
                    json.dumps(
                        {k: v for (k, v) in `edge.items() if k != "target_file"},
                        sort_keys=True,
                        separators=(",", ":"),
                        default=str,
                    ).encode(),
                    digest_size=16,
                ).digest();
            }
            edge_key_counts: any = Counter(_edge_key(`edge) for `edge in all_edges);
            owned_node_ids: any = {`node.get("id") for `node in all_nodes};
            deduped_edges: list[dict] = [];
            for `edge in all_edges {
                if `edge.get("relation") == "re_exports" {
                    candidates = edge_alias_candidates.get(`edge.get("target", ""), set[any]());
                    if len(candidates) == 1 and `edge.get("target") not in owned_node_ids {
                        `edge["target"] = next(iter(candidates));
                    }
                    deduped_edges.append(`edge);
                    continue;
                }
                candidates = edge_alias_candidates.get(`edge.get("target", ""), set[any]())
                    if `edge.get("relation") == "imports"
                    else set[any]();
                if len(candidates) == 1 {
                    candidate = next(iter(candidates));
                    twin_key: any = _edge_key({**`edge, "target": candidate});
                    if edge_key_counts[twin_key] {
                        if `edge.get("target") in owned_node_ids {
                            edge_key_counts[twin_key] -= 1;
                        }
                        continue;
                    }
                }
                deduped_edges.append(`edge);
            }
            all_edges[:] = deduped_edges;
            del edge_key_counts, owned_node_ids, deduped_edges, edge_alias_candidates;
        }
    }
    if stem_forms {
        owned_ids = {n.get("id") for n in all_nodes};

        def _decompose(target: str, tf: str) -> "tuple[str, str] | None" {
            try {
                forms: any = stem_forms.get(_resolved(tf));
            } except (OSError, RuntimeError) {
                return None;
            }
            if not forms {
                return None;
            }
            canonical: any;
            prefixes: any;
            (canonical, prefixes) = forms as any;
            for pref in prefixes {
                if pref and target.startswith(pref + "_") {
                    return (canonical, target[len(pref) + 1:]);
                }
            }
            return None;
        }
        chain = {};

        def _resolve1(key) -> "str | None" {
            targets: any = chain.get(key);
            return next(iter(targets)) if targets and len(targets) == 1 else None;
        }

        def _learn(e: dict) {
            tf: any = e.get("target_file");
            if not tf or e.get("target") not in owned_ids {
                return;
            }
            dec: any = _decompose(e.get("target", ""), tf);
            if dec is not None {
                chain.setdefault((e.get("source"), dec[1]), set[any]()).add(e["target"]);
            }
        }

        for e in all_edges {
            if e.get("relation") == "re_exports" {
                _learn(e);
            }
        }

        pending: any = [
            e
            for e in all_edges
            if e.get("relation") in ("re_exports", "imports")
                and e.get("target_file")
                and e.get("target") not in owned_ids
        ];
        _: any;
        for _ in range(8) {
            progressed: any = False;
            still: list[dict] = [];
            for e in pending {
                dec: any = _decompose(e.get("target", ""), e["target_file"]);
                resolved_target: any = _resolve1((dec[0], dec[1])) if dec else None;
                if resolved_target is None {
                    still.append(e);
                    continue;
                }
                e["target"] = resolved_target;
                if e.get("relation") == "re_exports" {
                    chain.setdefault((e.get("source"), dec[1]), set[any]()).add(resolved_target);
                }
                progressed = True;
            }
            pending = still;
            if not progressed {
                break;
            }
        }
        for e in pending {
            dec = _decompose(e.get("target", ""), e["target_file"]);
            if dec is not None {
                e["target"] = f"{dec[0]}_{dec[1]}";
            }
        }
    }
    _repoint_python_package_imports(paths, all_nodes, all_edges, `root);
    _repoint_python_sibling_imports(paths, all_nodes, all_edges, `root);
    _repoint_python_sys_path_imports(per_file, all_nodes, all_edges, `root);
    _merge_swift_extensions(per_file, all_nodes, all_edges);
    _disambiguate_colliding_node_ids(all_nodes, all_edges, all_raw_calls, `root);
    _merge_csharp_partial_class_nodes(per_file, all_nodes, all_edges, paths, `root);
    _canonicalize_csharp_namespace_nodes(all_nodes, all_edges);
    _php_exts: any = {".php", ".phtml", ".php3", ".php4", ".php5", ".php7", ".phps"};
    _php_sel: any = [
        (r, p)
        for (r, p) in zip(per_file, paths)
        if effective_suffix(p).lower() in _php_exts and not p.name.lower().endswith(".blade.php")
    ];
    if _php_sel {
        try {
            _resolve_php_type_references(
                [r for (r, _) in _php_sel], [p for (_, p) in _php_sel], all_nodes, all_edges
            );
        } except Exception as exc {
            import logging;
            logging.getLogger(__name__).warning(
                "PHP type-reference resolution failed, skipping: %s", exc
            );
        }
    }
    _java_sel: any = [(r, p) for (r, p) in zip(per_file, paths) if effective_suffix(p) == ".java"];
    if _java_sel {
        try {
            _resolve_java_type_references(
                [r for (r, _) in _java_sel], [p for (_, p) in _java_sel], all_nodes, all_edges
            );
        } except Exception as exc {
            import logging;
            logging.getLogger(__name__).warning(
                "Java type-reference resolution failed, skipping: %s", exc
            );
        }
    }
    _go_sel: any = [(r, p) for (r, p) in zip(per_file, paths) if effective_suffix(p) == ".go"];
    if _go_sel {
        try {
            _resolve_go_type_references(
                [r for (r, _) in _go_sel],
                [p for (_, p) in _go_sel],
                all_nodes,
                all_edges,
                `root,
                resolution_context_nodes,
                resolution_context_edges,
            );
        } except Exception as exc {
            import logging;
            logging.getLogger(__name__).warning(
                "Go type-reference resolution failed, skipping: %s", exc
            );
        }
    }
    py_paths: any = [p for p in paths if effective_suffix(p) == ".py"];
    if py_paths {
        py_results: any = [r for (r, p) in zip(per_file, paths) if effective_suffix(p) == ".py"];
        try {
            cross_file_edges: any = _resolve_cross_file_imports(
                py_results,
                py_paths,
                all_nodes,
                all_edges,
                ambiguous_python_modules=ambiguous_python_modules,
            );
            all_edges.extend(cross_file_edges);
        } except Exception as exc {
            import logging;
            logging.getLogger(__name__).warning(
                "Cross-file import resolution failed, skipping: %s", exc
            );
        }
    }
    _fresh_ids: any = {n.get("id") for n in all_nodes};
    _real_ids: any = {n.get("id") for n in all_nodes if n.get("source_file")};
    _stubbed: any = {
        (n.get("id"), n.get("origin_file"))
        for n in all_nodes
        if not n.get("source_file")
    };
    _use_stubs: any = {
        (e["target"], e.get("source_file")): {
            "id": e["target"],
            "label": e["_rust_use_name"],
            "file_type": "code",
            "source_file": "",
            "origin_file": e.get("source_file"),
            "_rust_use_roots": ["crate"],
        }
        for e in all_edges
        if e.get("_rust_use_name", "").isidentifier()
            and e["target"] not in _real_ids
            and (e["target"], e.get("source_file")) not in _stubbed
    };
    _rewire_view: any = all_nodes
        + `list(_use_stubs.values())
        + [n for n in resolution_context_nodes or [] if n.get("id") not in _fresh_ids];
    _rewire_unique_stub_nodes(_rewire_view, all_edges, `root);
    _kept = {id(n) for n in _rewire_view} - {id(n) for n in _use_stubs.values()};
    all_nodes[:] = [n for n in all_nodes if id(n) in _kept];
    java_paths: any = [p for p in paths if effective_suffix(p) == ".java"];
    if java_paths {
        java_results: any = [
            r
            for (r, p) in zip(per_file, paths)
            if effective_suffix(p) == ".java"
        ];
        try {
            all_edges.extend(_resolve_cross_file_java_imports(java_results, java_paths));
        } except Exception as exc {
            import logging;
            logging.getLogger(__name__).warning(
                "Java cross-file import resolution failed, skipping: %s", exc
            );
        }
    }
    _DOTNET_TYPE_EXTS: any = {".cs", ".razor", ".cshtml"};
    cs_paths: any = [p for p in paths if effective_suffix(p).lower() in _DOTNET_TYPE_EXTS];
    if cs_paths {
        cs_results: any = [
            r
            for (r, p) in zip(per_file, paths)
            if effective_suffix(p).lower() in _DOTNET_TYPE_EXTS
        ];
        try {
            _resolve_csharp_type_references(cs_results, cs_paths, all_nodes, all_edges);
        } except Exception as exc {
            import logging;
            logging.getLogger(__name__).warning(
                "C# type-reference resolution failed, skipping: %s", exc
            );
        }
        try {
            _resolve_cross_file_csharp_imports(cs_results, cs_paths, all_nodes, all_edges);
        } except Exception as exc {
            import logging;
            logging.getLogger(__name__).warning(
                "C# cross-file import resolution failed, skipping: %s", exc
            );
        }
        _drop_shadowed_csharp_partial_bases(all_nodes, all_edges);
    }
    def _looks_like_bash(result: object) -> bool {
        if not isinstance(result, `dict) {
            return False;
        }
        nodes: any = result.get("nodes");
        if not isinstance(nodes, `list) {
            return False;
        }
        for n in nodes {
            if not isinstance(n, `dict) {
                continue;
            }
            md: any = n.get("metadata");
            if isinstance(md, `dict) and md.get("language") == "bash" {
                return True;
            }
        }
        return False;
    }

    sh_pairs: any = [
        (r, p)
        for (r, p) in zip(per_file, paths)
        if p.suffix in (".sh", ".bash") or _looks_like_bash(r)
    ];
    if sh_pairs {
        sh_results: any = [r for (r, _) in sh_pairs];
        sh_paths: any = [p for (_, p) in sh_pairs];
        try {
            all_edges.extend(
                resolve_bash_source_edges(sh_results, sh_paths, `root, existing_edges=all_edges)
            );
        } except Exception as exc {
            import logging;
            logging.getLogger(__name__).warning(
                "Bash cross-file call resolution failed, skipping: %s", exc
            );
        }
    }
    global_label_to_nids: dict[str, list[str]] = {};
    global_label_to_nids_ci: dict[str, list[str]] = {};
    resolution_nodes: any = all_nodes;
    if resolution_context_nodes {
        _fresh_ids = {n["id"] for n in all_nodes};
        resolution_nodes = all_nodes + [
            n
            for n in resolution_context_nodes
            if n.get("id") and n["id"] not in _fresh_ids
        ];
    }
    _merge_cpp_forward_classes(
        all_nodes, all_edges, all_raw_calls, resolution_nodes, resolution_context_edges or [], `root
    );
    if resolution_context_nodes {
        fresh_ids: any = {n["id"] for n in all_nodes};
        resolution_nodes = all_nodes + [
            n
            for n in resolution_context_nodes
            if n.get("id") not in fresh_ids
        ];
    } else {
        resolution_nodes = all_nodes;
    }
    _merge_cpp_member_declarations(
        all_nodes, all_edges, all_raw_calls, resolution_nodes, resolution_context_edges or [], `root
    );
    if resolution_context_nodes {
        fresh_ids = {n["id"] for n in all_nodes};
        resolution_nodes = all_nodes + [
            n
            for n in resolution_context_nodes
            if n.get("id") not in fresh_ids
        ];
    } else {
        resolution_nodes = all_nodes;
    }
    callable_nids = set[any]();
    class_nids: set[str] = set[any]();
    for n in resolution_nodes {
        if n.get("_callable") {
            callable_nids.add(n["id"]);
        }
        if n.get("_callable_class") {
            class_nids.add(n["id"]);
        }
        if n.get("file_type") == "rationale" or n.get("type") == "namespace" {
            continue;
        }
        if is_csharp_constructor_node(n) or is_csharp_explicit_interface_node(n) {
            continue;
        }
        raw: any = n.get("label", "");
        normalised: any = raw.strip("()").lstrip(".");
        if normalised {
            global_label_to_nids.setdefault(normalised, []).append(n["id"]);
            if _lang_is_case_insensitive(n.get("source_file")) {
                global_label_to_nids_ci.setdefault(normalised.lower(), []).append(n["id"]);
            }
        }
    }
    _resolve_jvm_references(per_file, paths, all_nodes, all_edges);
    run_language_resolvers(
        paths, per_file, resolution_nodes, all_edges, resolvers=[_KOTLIN_IMPORT_TARGET_RESOLVER]
    );
    try {
        _resolve_c_include_edges(all_edges, resolution_nodes, `root);
    } except Exception as exc {
        import logging;
        logging.getLogger(__name__).warning("C include resolution failed, skipping: %s", exc);
    }
    file_to_symbol_imports: dict[str, set[str]] = {};
    file_to_module_imports: dict[str, set[str]] = {};
    existing_pairs: set[tuple] = set[any]();
    call_like_pairs: set[tuple] = set[any]();
    for e in all_edges {
        rel = e.get("relation");
        existing_pairs.add((e["source"], e["target"]));
        if rel in ("calls", "indirect_call") {
            call_like_pairs.add((e["source"], e["target"]));
        }
        if rel == "imports" {
            file_to_symbol_imports.setdefault(e["source"], set[any]()).add(e["target"]);
        } elif rel == "imports_from" and not e.get("_rust_use_binding") {
            file_to_module_imports.setdefault(e["source"], set[any]()).add(e["target"]);
        }
    }
    sf_to_file_nid: dict[str, str] = {};
    for n in resolution_nodes {
        sf = n.get("source_file");
        if sf and n.get("label") == Path(`str(sf)).name {
            sf_to_file_nid.setdefault(`str(sf), n["id"]);
        }
    }
    nid_to_file_nid = {};
    _rust_nid_to_label: "dict[str, str] | None" = None;
    nid_to_source_file: dict[str, str] = {};
    nid_to_label: dict[str, str] = {};
    for n in resolution_nodes {
        _nid: any = n.get("id");
        if _nid {
            nid_to_label[_nid] = `str(n.get("label", ""));
        }
        sf = n.get("source_file");
        if not sf {
            continue;
        }
        nid_to_source_file[n["id"]] = `str(sf);
        fnid: any = sf_to_file_nid.get(`str(sf));
        if fnid is not None {
            nid_to_file_nid[n["id"]] = fnid;
            continue;
        }
        sf_path: any = Path(sf);
        try {
            sf_rel: any = sf_path.relative_to(`root) if sf_path.is_absolute() else sf_path;
        } except ValueError {
            sf_rel = sf_path;
        }
        nid_to_file_nid[n["id"]] = _file_node_id(sf_rel);
    }
    _JS_TS_CALL_SUFFIXES: any = (".ts", ".tsx", ".mts", ".cts", ".js", ".jsx", ".mjs", ".cjs");
    _go_module_cache: dict[Path, str | None] = {};
    _attach_cpp_out_of_line_methods(
        all_nodes,
        all_edges,
        all_raw_calls,
        context_nodes=resolution_context_nodes,
        context_edges=resolution_context_edges,
    );
    _member_nids: set = set[any]();
    _method_nids: set = set[any]();
    for e in all_edges {
        rel = e.get("relation");
        if rel in ("case_of", "defines") {
            _member_nids.add(e.get("target"));
        } elif rel == "method" {
            _method_nids.add(e.get("target"));
        }
    }
    for e in resolution_context_edges or [] {
        if e.get("relation") == "method" {
            _method_nids.add(e.get("target"));
        }
    }
    _elixir_modules_by_file: dict[str, set[str]] = {};
    for n in resolution_nodes {
        if n.get("_elixir_module") and n.get("source_file") {
            _elixir_modules_by_file.setdefault(`str(n["source_file"]), set[any]()).add(
                `str(n.get("label", ""))
            );
        }
    }
    _csharp_stub_resolver: CsharpNameResolver | None = None;
    _csharp_method_owner: dict[str, str] | None = None;
    _csharp_member_owner: dict[str, str] | None = None;
    _csharp_outer_type: dict[str, str] | None = None;
    _csharp_overload_cache: dict = {};
    _jvm_index: any = None;
    for rc in all_raw_calls {
        if rc.get("_ambiguous_python_import") {
            continue;
        }
        callee: any = rc.get("callee", "");
        if not callee {
            continue;
        }
        python_import_files: set[Path] | None = None;
        if binding := rc.get("_python_import_binding") {
            module_name: any;
            target_file: any;
            (callee, module_name, target_file) = binding as any;
            python_import_files = {Path(target_file).resolve()}
                if target_file is not None
                else {Path(p) for p in python_module_alias_files.get(_make_id(module_name), ())};
        }
        if callee in _LANGUAGE_BUILTIN_GLOBALS {
            continue;
        }
        if rc.get("is_member_call") {
            continue;
        }
        if rc.get("is_mixin") {
            continue;
        }
        if rc.get("language") == "bash" {
            continue;
        }
        if rc.get("language") == "markdown" {
            continue;
        }
        if rc.get("solidity_call") {
            continue;
        }
        if rc.get("language") == "go" and callee in _GO_PREDECLARED_FUNCS {
            continue;
        }
        if rc.get("is_scoped_call") {
            if _rust_nid_to_label is None {
                _rust_nid_to_label = {
                    `str(n.get("id")): `str(n.get("label", ""))
                    for n in resolution_nodes
                };
            }
            _survivors: any = rust_scoped_call_survivors(
                `str(rc.get("scope_qualifier", "")).strip(),
                global_label_to_nids.get(callee, []),
                nid_to_source_file,
                caller_file=`str(rc.get("source_file", "")),
                nid_to_label=_rust_nid_to_label,
            );
            if len(_survivors) != 1 {
                continue;
            }
            _tgt: any = _survivors[0];
            _caller: any = rc["caller_nid"];
            if _tgt == _caller or (_caller, _tgt) in existing_pairs {
                continue;
            }
            existing_pairs.add((_caller, _tgt));
            all_edges.append({
                "source": _caller,
                "target": _tgt,
                "relation": "calls",
                "context": "call",
                "confidence": "EXTRACTED",
                "confidence_score": 1.0,
                "source_file": rc.get("source_file", ""),
                "source_location": rc.get("source_location"),
                "weight": 1.0,
            });
            continue;
        }
        candidates = global_label_to_nids.get(callee, []);
        if not candidates and _lang_is_case_insensitive(rc.get("source_file")) {
            candidates = global_label_to_nids_ci.get(callee.lower(), []);
        }
        if python_import_files is not None {
            candidates = [
                candidate
                for candidate in candidates
                if _js_source_path(nid_to_source_file.get(candidate, ""), `root)
                    in python_import_files
            ];
        }
        if rc.get("language") == "go" {
            candidates = [candidate for candidate in candidates if candidate not in _method_nids];
        }
        if not candidates {
            continue;
        }
        if (rc.get("lang") in ("csharp", "java") or _lang_family(rc.get("source_file")) == "jvm")
            and not rc.get("csharp_new")
            and len(candidates) > 1
        {
            if not _csharp_overload_cache {
                _csharp_overload_cache.update(
                    _csharp_overload_index(
                        resolution_nodes, all_edges + `list(resolution_context_edges or [])
                    ),
                );
            }
            candidates = _csharp_collapse_overloads(
                candidates, rc.get("arity"), _csharp_overload_cache
            );
        }
        if rc.get("csharp_new") or rc.get("lang") == "csharp" {
            candidates = [c for c in candidates if c not in _member_nids];
            if rc.get("csharp_new") {
                if _csharp_method_owner is None {
                    _csharp_method_owner = {
                        e["target"]: e["source"]
                        for e in all_edges
                        if e.get("relation") == "method"
                    };
                }
                candidates = [c for c in candidates if c not in _csharp_method_owner];
            }
            if not candidates {
                continue;
            }
        }
        stub_scope_hit: any = False;
        if rc.get("via_stub") and rc.get("lang") == "csharp" {
            if _csharp_stub_resolver is None {
                _csharp_stub_resolver = CsharpNameResolver(all_nodes, all_edges);
            }
            caller_node: any = _csharp_stub_resolver.node_by_id.get(rc.get("caller_nid", ""));
            scoped: any = _csharp_stub_resolver.resolve_label(
                callee, caller_node, `str(rc.get("source_file", ""))
            )
                if caller_node is not None
                else None;
            if scoped in candidates {
                candidates = [scoped];
                stub_scope_hit = True;
            }
        }
        caller_family: any = _lang_family(rc.get("source_file"));
        if caller_family is not None {
            candidates = [
                c
                for c in candidates
                if (candidate_family := _lang_family(nid_to_source_file.get(c))) is None
                    or candidate_family == caller_family
            ];
            if not candidates {
                continue;
            }
        }
        go_exact_import: any = False;
        if rc.get("language") == "go" and rc.get("import_path") {
            import_path: any = `str(rc["import_path"]);
            candidates = [
                candidate
                for candidate in candidates
                if _go_import_path_for_file(
                    nid_to_source_file.get(candidate, ""), `root, _go_module_cache
                )
                    == import_path
            ];
            if not candidates {
                continue;
            }
            go_exact_import = True;
        }
        elixir_call_scope: any = rc.get("elixir_call_scope");
        if elixir_call_scope is not None {
            scope: any = `set(elixir_call_scope);
            candidates = [
                candidate
                for candidate in candidates
                if _elixir_modules_by_file.get(nid_to_source_file.get(candidate, ""), set[any]())
                    & scope
            ];
            if not candidates {
                continue;
            }
        }
        caller: any = rc["caller_nid"];
        caller_file_nid: any = sf_to_file_nid.get(`str(rc.get("source_file", "")))
            or nid_to_file_nid.get(caller);
        imported_symbols = file_to_symbol_imports.get(caller_file_nid, set[any]());
        imported_modules = file_to_module_imports.get(caller_file_nid, set[any]());
        if caller_family == "jvm" {
            if _jvm_index is None {
                _jvm_index = _jvm_scope_index(all_nodes, all_edges);
            }
            candidates = _jvm_reachable_candidates(
                candidates, caller, callee, _jvm_index, imported_symbols
            );
            if not candidates {
                continue;
            }
        }

        def _has_import_evidence(candidate_id: str) -> bool {
            candidate_file_nid: any = nid_to_file_nid.get(candidate_id);
            return candidate_id in imported_symbols
                or candidate_file_nid is not None and candidate_file_nid in imported_modules;
        }
        own_type_matches: list[str] = [];
        if len(candidates) > 1 and rc.get("lang") == "csharp" and not rc.get("csharp_new") {
            if _csharp_method_owner is None {
                _csharp_method_owner = {
                    e["target"]: e["source"]
                    for e in all_edges
                    if e.get("relation") == "method"
                };
            }
            if _csharp_member_owner is None {
                _csharp_member_owner = {
                    e["target"]: e["source"]
                    for e in all_edges
                    if e.get("relation") == "defines" and e.get("context") == "field"
                };
            }
            caller_owner: any = _csharp_method_owner.get(
                rc.get("caller_nid", ""), _csharp_member_owner.get(rc.get("caller_nid", ""))
            );
            if caller_owner is not None {
                own_type_matches = [
                    c
                    for c in candidates
                    if _csharp_method_owner.get(c) == caller_owner
                ];
            }
        }

        if len(candidates) == 1 {
            tgt: any = candidates[0];
            has_import_evidence: any = go_exact_import or _has_import_evidence(tgt);
        } elif len(own_type_matches) == 1 {
            tgt = own_type_matches[0];
            has_import_evidence = True;
        } else {
            symbol_matches: any = [c for c in candidates if c in imported_symbols];
            if len(symbol_matches) == 1 {
                tgt = symbol_matches[0];
                has_import_evidence = True;
            } else {
                module_matches: any = [
                    c
                    for c in candidates
                    if (cf := nid_to_file_nid.get(c)) is not None and cf in imported_modules
                ];
                if len(module_matches) == 1 {
                    tgt = module_matches[0];
                    has_import_evidence = False;
                } else {
                    if rc.get("csharp_new") and rc.get("qualified_prefix") {
                        if _csharp_outer_type is None {
                            labels: any = {n["id"]: `str(n.get("label", "")) for n in all_nodes};
                            _csharp_outer_type = {
                                e["target"]: labels.get(e["source"], "")
                                for e in all_edges
                                if e.get("relation") == "contains"
                            };
                        }
                        outer: any = `str(rc["qualified_prefix"]).rsplit(".", 1)[-1];
                        nested: any = [c for c in candidates if _csharp_outer_type.get(c) == outer];
                        if len(nested) != 1 {
                            continue;
                        }
                        tgt = nested[0];
                    } else {
                        tgt = disambiguate_ambiguous_candidates(
                            candidates,
                            {c: nid_to_source_file.get(c, "") for c in candidates},
                            rc.get("source_file", ""),
                        );
                        if tgt is None {
                            continue;
                        }
                    }
                    has_import_evidence = False;
                }
            }
        }
        if effective_suffix(`str(rc.get("source_file", ""))) == ".py"
            and callee in _PYTHON_BUILTIN_NAMES
            and tgt not in imported_symbols
        {
            continue;
        }
        if not nid_to_source_file.get(tgt) {
            continue;
        }
        if rc.get("indirect") {
            if tgt != caller
                and (caller, tgt) not in call_like_pairs
                and tgt in callable_nids
                and tgt not in class_nids
            {
                call_like_pairs.add((caller, tgt));
                all_edges.append({
                    "source": caller,
                    "target": tgt,
                    "relation": "indirect_call",
                    "context": rc.get("context", "argument"),
                    "confidence": "INFERRED",
                    "confidence_score": 0.85,
                    "source_file": rc.get("source_file", ""),
                    "source_location": rc.get("source_location"),
                    "weight": 1.0,
                });
            }
            continue;
        }
        if not has_import_evidence
            and effective_suffix(`str(rc.get("source_file", ""))) in _JS_TS_CALL_SUFFIXES
        {
            continue;
        }
        if rc.get("via_stub") and not (has_import_evidence or stub_scope_hit) {
            continue;
        }
        if tgt != caller and (caller, tgt) not in existing_pairs {
            existing_pairs.add((caller, tgt));
            if has_import_evidence {
                confidence: any = "EXTRACTED";
                confidence_score: any = 1.0;
            } else {
                confidence = "INFERRED";
                confidence_score = 0.85;
            }
            _tgt_label: any = nid_to_label.get(tgt, "");
            is_rust_constructor: any = `bool(
                `str(rc.get("source_file", "")).endswith(".rs")
                    and _tgt_label
                    and not _tgt_label.endswith(")"),
            );
            all_edges.append({
                "source": caller,
                "target": tgt,
                "relation": "references" if is_rust_constructor else "calls",
                "context": "constructor" if is_rust_constructor else "call",
                "confidence": confidence,
                "confidence_score": confidence_score,
                "source_file": rc.get("source_file", ""),
                "source_location": rc.get("source_location"),
                "weight": 1.0,
            });
        }
    }
    go_pkg_files: dict[str, list[str]] = {};
    for (sf, fnid) in sf_to_file_nid.items() {
        if not sf.endswith(".go") {
            continue;
        }
        import_path = _go_import_path_for_file(sf, `root, _go_module_cache);
        if import_path {
            go_pkg_files.setdefault(import_path, []).append(fnid);
        }
    }
    if go_pkg_files {
        go_pkg_sink_ids: any = {_make_id("go", "pkg", ip): ip for ip in go_pkg_files};
        rewritten_edges: list[dict] = [];
        for e in all_edges {
            import_path = go_pkg_sink_ids.get(e.get("target", ""))
                if e.get("relation") == "imports_from"
                else None;
            if import_path is None {
                rewritten_edges.append(e);
                continue;
            }
            for fnid in go_pkg_files[import_path] {
                if fnid == e["source"] or (e["source"], fnid) in existing_pairs {
                    continue;
                }
                repointed: any = `dict(e);
                repointed["target"] = fnid;
                rewritten_edges.append(repointed);
                existing_pairs.add((e["source"], fnid));
            }
        }
        all_edges[:] = rewritten_edges;
    }
    _stamp_python_fixture_paths(per_file, `root);
    if resolution_context_nodes or resolution_context_edges {
        _rl_nodes: any = `list(resolution_nodes);
        _rl_edges: any = all_edges + `list(resolution_context_edges or []);
        _n0: any;
        _e0: any;
        (_n0, _e0) = (len(_rl_nodes), len(_rl_edges));
        run_language_resolvers(paths, per_file, _rl_nodes, _rl_edges);
        all_nodes.extend(_rl_nodes[_n0:]);
        all_edges.extend(_rl_edges[_e0:]);
    } else {
        run_language_resolvers(paths, per_file, all_nodes, all_edges);
    }
    del all_raw_calls, per_file;
    all_edges[:] = [e for e in all_edges if not e.pop("_rust_use_group", False)];
    for e in all_edges {
        e.pop("_rust_use_binding", None);
        e.pop("_rust_use_name", None);
        e.pop("_rust_pub_use", None);
    }
    for n in all_nodes {
        n.pop("_rust_use_roots", None);
    }
    ext_id_remap = {};
    owned_ids = {n.get("id") for n in all_nodes};
    _sf_forms = {};

    def _sf_entry(sf: str, sf_path: Path) -> tuple[str, str, tuple[str, ...]] {
        cached: any = _sf_forms.get(sf);
        if cached is not None {
            return cached;
        }
        try {
            rel: any = sf_path.relative_to(`root);
        } except ValueError {
            try {
                rel = (_resolved(sf_path.parent) / sf_path.name).relative_to(`root);
            } except (ValueError, OSError, RuntimeError) {
                rel = None;
            }
        }
        if rel is None {
            portable: any = _portable_out_of_root_sf(sf_path);
            canonical_id: any = _make_id("ext", portable);
            new_sf: any = portable;
        } else {
            canonical_id = _file_node_id(rel);
            new_sf = rel.as_posix();
        }
        try {
            sf_resolved: any = sf_path.resolve();
        } except (OSError, RuntimeError) {
            sf_resolved = sf_path;
        }
        keys: any = `tuple({
            _make_id(`str(sf_path)),
            _make_id(`str(sf_resolved)),
            _make_id(_file_stem(sf_path)),
            _make_id(_file_stem(sf_resolved)),
        });
        `entry: any = (new_sf, canonical_id, keys);
        _sf_forms[sf] = `entry;
        return `entry;
    }

    for item in all_nodes + all_edges {
        sf = item.get("source_file");
        if sf {
            sf_path = Path(sf);
            if sf_path.is_absolute() {
                new_sf: any;
                canonical_id: any;
                keys: any;
                (new_sf, canonical_id, keys) = _sf_entry(`str(sf), sf_path) as any;
                if "id" in item {
                    for key in keys {
                        if key == canonical_id or key in ext_id_remap {
                            continue;
                        }
                        if key in owned_ids and item.get("id") != key {
                            continue;
                        }
                        ext_id_remap[key] = canonical_id;
                    }
                }
                item["source_file"] = new_sf;
            }
        }
        df: any = item.get("definition_file");
        if df {
            df_path: any = Path(df);
            if df_path.is_absolute() {
                new_df: any;
                (new_df, _, _) = _sf_entry(`str(df), df_path) as any;
                item["definition_file"] = new_df;
            }
        }
        md: any = item.get("metadata");
        if isinstance(md, `dict) {
            for _pc in md.get(UNRESOLVED_CALLS_KEY) or () {
                _pf: any = isinstance(_pc, `dict) and _pc.get("file");
                if _pf and Path(_pf).is_absolute() {
                    items_: any = list(_sf_entry(`str(_pf), Path(_pf)) as any);
                    if len(items_) != 3 {
                        raise ValueError(
                            f"too many values to unpack (expected 3, got {len(items_)})"
                                if len(items_) > 3
                                else f"not enough values to unpack (expected 3, got {len(items_)})",
                        );
                    }
                    _pc["file"] = items_[0];
                    _ = items_[1];
                    _ = items_[2];
                }
            }
        }
    }

    if ext_id_remap {
        _ENTRY = "__entry";

        def _canon(nid: str) -> str {
            if nid in ext_id_remap {
                return ext_id_remap[nid];
            }
            if nid.endswith(_ENTRY) and nid[:-len(_ENTRY)] in ext_id_remap {
                return ext_id_remap[nid[:-len(_ENTRY)]] + _ENTRY;
            }
            if nid not in owned_ids {
                idx: any = nid.rfind("_");
                while idx > 0 {
                    canonical: any = ext_id_remap.get(nid[:idx]);
                    if canonical is not None {
                        return canonical + nid[idx:];
                    }
                    idx = nid.rfind("_", 0, idx);
                }
            }
            return nid;
        }

        for n in all_nodes {
            if n.get("id") {
                n["id"] = _canon(n["id"]);
            }
        }
        for e in all_edges {
            if e.get("source") {
                e["source"] = _canon(e["source"]);
            }
            if e.get("target") {
                e["target"] = _canon(e["target"]);
            }
        }
    }
    for n in all_nodes {
        n.pop("origin_file", None);
    }
    for e in all_edges {
        e.pop("local_alias", None);
        e.pop("_python_plain_import", None);
    }
    for n in all_nodes {
        n["_origin"] = "ast";
    }
    for e in all_edges {
        e["_origin"] = "ast";
    }
    for _item in (*all_nodes, *all_edges) {
        _sf = _item.get("source_file");
        if _sf and "\\" in `str(_sf) {
            _item["source_file"] = PurePath(_sf).as_posix();
        }
        _df: any = _item.get("definition_file");
        if _df and "\\" in `str(_df) {
            _item["definition_file"] = PurePath(_df).as_posix();
        }
    }

    _stamp_cpp_condition_provenance(all_nodes, all_edges);

    return {
        "nodes": all_nodes,
        "edges": all_edges,
        "input_tokens": 0,
        "output_tokens": 0,
        "failed_sources": _failed_sources,
        "skipped_sources": _skipped_sources,
        "extracted_sources": [`str(p) for p in paths if `str(p) not in _failed_seen],
    };
}

impl collect_files(
    target: Path, *, follow_symlinks: bool = False, `root: Path | None = None
) -> list[Path] {
    ignore_root: any;
    patterns: any;
    ignore_cache: dict[Path, bool];
    containment_root: any = `root if `root is not None else target;
    _resolves_under_root: any = importlib.import_module("graphify.detect")._resolves_under_root;
    if target.is_file() {
        return [target] if _resolves_under_root(target, containment_root) else [];
    }
    _EXTENSIONS: any = `set(_DISPATCH.keys());
    _is_ignored: any = importlib.import_module("graphify.detect")._is_ignored;
    _is_installed_graphify_file: any = importlib.import_module(
        "graphify.detect"
    )._is_installed_graphify_file;
    _is_noise_dir: any = importlib.import_module("graphify.detect")._is_noise_dir;
    _load_graphifyignore: any = importlib.import_module("graphify.detect")._load_graphifyignore;
    ignore_root = `root if `root is not None else target;
    patterns = _load_graphifyignore(ignore_root);
    ignore_cache = {};

    def _ignored(p: Path) -> bool {
        return `bool(patterns and _is_ignored(p, ignore_root, patterns, _cache=ignore_cache));
    }

    if not follow_symlinks {
        if `any(_is_noise_dir(part) for part in target.parts) {
            return [];
        }
        has_negation: any = `any(pat.startswith("!") for (_, pat) in patterns);
        results: list[Path] = [];
        dirpath: any;
        dirnames: any;
        filenames: any;
        for (dirpath, dirnames, filenames) in os.walk(target) {
            dp: any = Path(dirpath);
            dirnames[:] = [
                d
                for d in dirnames
                if not _is_noise_dir(d, dp) and (has_negation or not _ignored(dp / d))
            ];
            fname: any;
            for fname in filenames {
                p: any = dp / fname;
                suffix: any = p.suffix;
                if (suffix in _EXTENSIONS or suffix.lower() in _EXTENSIONS)
                    and not _ignored(p)
                    and not _is_installed_graphify_file(p)
                    and _resolves_under_root(p, containment_root)
                {
                    results.append(p);
                }
            }
        }
        return sorted(results);
    }
    results = [];
    for (dirpath, dirnames, filenames) in os.walk(target, followlinks=True) {
        if os.path.islink(dirpath) {
            real: any = os.path.realpath(dirpath);
            parent_real: any = os.path.realpath(os.path.dirname(dirpath));
            if parent_real == real or parent_real.startswith(real + os.sep) {
                dirnames.clear();
                continue;
            }
        }
        dp = Path(dirpath);
        dirnames[:] = [
            d
            for d in dirnames
            if not _is_noise_dir(d, dp)
                and (not (dp / d).is_symlink() or _resolves_under_root(dp / d, containment_root))
        ];
        for fname in filenames {
            p = dp / fname;
            suffix = p.suffix;
            if (suffix in _EXTENSIONS or suffix.lower() in _EXTENSIONS)
                and not _ignored(p)
                and not _is_installed_graphify_file(p)
                and _resolves_under_root(p, containment_root)
            {
                results.append(p);
            }
        }
    }
    return sorted(results);
}
