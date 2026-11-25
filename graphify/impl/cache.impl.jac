impl _grammar_fingerprint -> str {
    if _GRAMMAR_FINGERPRINT_CACHE is not None {
        return _GRAMMAR_FINGERPRINT_CACHE;
    }
    parts: list[str] = [];
    try {
        import from importlib.metadata { distributions }

        for dist in distributions() {
            try {
                name: any = (dist.metadata.get("Name") or "").lower();
            } except Exception {
                continue;
            }
            if name == "tree-sitter"
                or name.startswith("tree-sitter-")
                or name.startswith("tree_sitter")
            {
                parts.append(f"{name}=={dist.version}");
            }
        }
    } except Exception {
        _GRAMMAR_FINGERPRINT_CACHE = "unknown";
        return _GRAMMAR_FINGERPRINT_CACHE;
    }
    if not parts {
        _GRAMMAR_FINGERPRINT_CACHE = "none";
        return _GRAMMAR_FINGERPRINT_CACHE;
    }
    digest: any = hashlib.sha256(";".join(sorted(parts)).encode("utf-8")).hexdigest();
    _GRAMMAR_FINGERPRINT_CACHE = digest[:12];
    return _GRAMMAR_FINGERPRINT_CACHE;
}

impl _cleanup_stale_ast_entries(ast_base: Path, current_dir: Path) -> None {
    key: any = `str(current_dir);
    if key in _cleaned_ast_dirs {
        return;
    }
    _cleaned_ast_dirs.add(key);
    if not ast_base.is_dir() {
        return;
    }
    import shutil;

    for child in ast_base.iterdir() {
        if child == current_dir {
            continue;
        }
        try {
            if child.is_dir() and child.name.startswith("v") {
                shutil.rmtree(child, ignore_errors=True);
            } elif child.suffix == ".json" {
                child.unlink();
            }
        } except OSError {}
    }
}

impl prompt_fingerprint(prompt: "str | Path") -> str {
    if isinstance(prompt, Path) {
        text: any = prompt.read_text(encoding="utf-8", errors="replace");
    } else {
        text = prompt;
    }
    normalized: any = "\n".join(
        line.rstrip() for line in text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    ).strip();
    return hashlib.sha256(normalized.encode()).hexdigest()[:_PROMPT_FP_LEN];
}

impl _resolve_prompt_fp(
    prompt: "str | Path | None" = None, prompt_file: "str | Path | None" = None
) -> str | None {
    memo_key: any = None;
    if prompt_file is not None {
        prompt = Path(prompt_file);
        try {
            st: any = prompt.stat();
            memo_key = (`str(prompt), st.st_size, st.st_mtime_ns);
            if memo_key in _prompt_fp_cache {
                return _prompt_fp_cache[memo_key];
            }
        } except OSError {}
    }
    if prompt is None {
        return None;
    }
    try {
        fp: any = prompt_fingerprint(prompt);
        if memo_key is not None {
            _prompt_fp_cache[memo_key] = fp;
        }
        return fp;
    } except (OSError, UnicodeError) as exc {
        warnings.warn(
            f"could not read extraction prompt {`str(prompt)!r} ({exc}); semantic cache entries cannot be attributed to a prompt version and fall back to the unversioned layout, so this run may replay entries from an older extraction prompt (#1939).",
            RuntimeWarning,
            stacklevel=3,
        );
        return None;
    }
}

impl _body_content(content: bytes) -> bytes {
    text: any = content.decode(errors="replace");
    opener: any = _FRONTMATTER_DELIM.match(text);
    if opener is None {
        return content;
    }
    closer: any = _FRONTMATTER_DELIM.search(text, opener.end());
    if closer is None {
        return content;
    }
    return text[closer.start() + 3:].encode();
}

impl _mtime_granularity_ns -> int {
    raw: any = os.environ.get("GRAPHIFY_MTIME_GRANULARITY_MS", "").strip();
    if raw {
        try {
            ms: any = `float(raw);
        } except ValueError {
            return _MTIME_GRANULARITY_NS;
        }
        if ms >= 0 {
            return `int(ms * 1000000);
        }
    }
    return _MTIME_GRANULARITY_NS;
}

impl _stat_sig_fresh(`entry: object, st: "os.stat_result") -> bool {
    if not isinstance(`entry, `dict) {
        return False;
    }
    if `entry.get("size") != st.st_size or `entry.get("mtime_ns") != st.st_mtime_ns {
        return False;
    }
    indexed_at: any = `entry.get("indexed_at_ns");
    if not isinstance(indexed_at, `int) {
        return False;
    }
    return operator.le(st.st_mtime_ns + _mtime_granularity_ns(), indexed_at);
}

impl _stat_entry_for(abs_key: str, st: "os.stat_result", observed_at_ns: int) -> dict {
    `entry: any = _stat_index.get(abs_key);
    if not isinstance(`entry, `dict)
        or `entry.get("size") != st.st_size
        or `entry.get("mtime_ns") != st.st_mtime_ns
    {
        `entry = {"size": st.st_size, "mtime_ns": st.st_mtime_ns};
        _stat_index[abs_key] = `entry;
    }
    `entry["indexed_at_ns"] = observed_at_ns;
    return `entry;
}

impl _stat_key_to_relative(key: str, anchor: Path) -> str {
    p: any = Path(key);
    if not p.is_absolute() {
        return key;
    }
    try {
        rel: any = os.path.relpath(p, anchor);
    } except (ValueError, OSError) {
        return key;
    }
    if rel == ".." or rel.startswith(".." + os.sep) or rel.startswith("../") {
        return key;
    }
    return rel.replace(os.sep, "/");
}

impl _stat_key_to_absolute(key: str, anchor: Path) -> str {
    p: any = Path(key);
    if p.is_absolute() {
        return `str(p);
    }
    return `str(anchor / p);
}

impl _stat_index_file(`root: Path) -> Path {
    _out: any = Path(_GRAPHIFY_OUT);
    base: any = _out if _out.is_absolute() else Path(`root).resolve() / _out;
    return base / "cache" / "stat-index.json";
}

impl _ensure_stat_index(`root: Path, cache_root: "Path | None" = None) -> None {
    new_root: any = Path(cache_root if cache_root is not None else `root).resolve();
    if _stat_index_root is not None {
        if _stat_index_root == new_root {
            return;
        }
        warnings.warn(
            f"stat index switched from cache root {`str(_stat_index_root)!r} to {`str(new_root)!r} within one process; each root's stat-index.json now only reflects its own files, but library callers crossing project roots in one process should still use a fresh process per root to avoid losing the fastpath (#3989).",
            RuntimeWarning,
            stacklevel=3,
        );
        _flush_stat_index();
    }
    _stat_index_root = new_root;
    _stat_index_anchor = _normalize_path(Path(`root).resolve());
    p: any = _stat_index_file(_stat_index_root);
    _stat_index_path = p;
    _stat_index = {};
    if p.exists() {
        try {
            raw: any = json.loads(p.read_text(encoding="utf-8"));
            if isinstance(raw, `dict) {
                for (k, v) in raw.items() {
                    if not isinstance(k, `str) {
                        continue;
                    }
                    if Path(k).is_absolute() {
                        _stat_index.setdefault(k, v);
                    } else {
                        _stat_index[_stat_key_to_absolute(k, _stat_index_anchor)] = v;
                    }
                }
            }
        } except (json.JSONDecodeError, OSError) {
            _stat_index = {};
        }
    }
    _stat_index_dirty = False;
    if not _stat_index_atexit_registered {
        atexit.register(_flush_stat_index);
        _stat_index_atexit_registered = True;
    }
}

impl _flush_stat_index -> None {
    if not _stat_index_dirty or _stat_index_root is None {
        return;
    }
    p: any = _stat_index_path
        if _stat_index_path is not None
        else _stat_index_file(_stat_index_root);
    on_disk: dict[str, dict] = {};
    for (k, v) in _stat_index.items() {
        try {
            if not os.path.exists(k) {
                continue;
            }
        } except OSError {
            continue;
        }
        dk: any = _stat_key_to_relative(k, _stat_index_anchor)
            if _stat_index_anchor is not None
            else k;
        on_disk[dk] = v;
    }
    try {
        if not _stat_index_root.is_dir() {
            _stat_index_dirty = False;
            return;
        }
    } except OSError {
        _stat_index_dirty = False;
        return;
    }
    try {
        p.parent.mkdir(parents=True, exist_ok=True);
        fd: any;
        tmp: any;
        (fd, tmp) = tempfile.mkstemp(dir=p.parent, prefix="stat-index.", suffix=".tmp") as any;
        try {
            os.write(fd, json.dumps(on_disk, separators=(",", ":")).encode());
            os.close(fd);
            _os_replace_with_fallback(tmp, p);
        } except Exception {
            try {
                os.close(fd);
            } except OSError {}
            try {
                os.unlink(tmp);
            } except OSError {}
        }
    } except OSError {}
    _stat_index_dirty = False;
}

impl _normalize_path(path: Path) -> Path {
    import sys;
    if sys.platform != "win32" {
        return path;
    }
    s: any = `str(path);
    if s.startswith("\\\\?\\UNC\\") {
        s = "\\\\" + s[8:];
    } elif s.startswith("\\\\?\\") {
        s = s[4:];
    }
    return Path(os.path.normpath(s));
}

impl file_hash(path: Path, `root: Path = root_default_, cache_root: "Path | None" = None) -> str {
    raw_path: any = Path(path);
    raw_root: any = Path(`root);
    src: any = Path(_os_long_path(raw_path));
    root_src: any = Path(_os_long_path(raw_root));
    if not src.is_file() {
        raise IsADirectoryError(f"file_hash requires a file, got: {src}");
    }
    _ensure_stat_index(_normalize_path(raw_root), cache_root=cache_root);
    resolved: any = _normalize_path(src.resolve());
    abs_key: any = `str(resolved);
    resolved_root: any = _normalize_path(root_src.resolve());
    try {
        resolved_rel: any = resolved.relative_to(resolved_root);
    } except ValueError {
        salt: any = resolved.as_posix();
    } else {
        walked: any = Path(os.path.abspath(raw_path));
        walked_root: any = Path(os.path.abspath(raw_root));
        try {
            walked_rel: any = walked.relative_to(walked_root);
        } except ValueError {
            walked_rel = None;
            for parent in walked.parents {
                try {
                    if _normalize_path(parent.resolve()) == resolved_root {
                        walked_rel = walked.relative_to(parent);
                        break;
                    }
                } except OSError {
                    continue;
                }
            }
            if walked_rel is None {
                walked_rel = resolved_rel;
            }
        }
        salt = walked_rel.as_posix();
    }

    st: "os.stat_result | None" = None;
    try {
        st = src.stat();
        if _stat_sig_fresh(_stat_index.get(abs_key), st) {
            hashes: any = _stat_index[abs_key].get("hashes");
            if isinstance(hashes, `dict) {
                cached: any = hashes.get(salt);
                if isinstance(cached, `str) {
                    return cached;
                }
            }
        }
    } except OSError {}
    observed_at_ns: any = time.time_ns();
    raw: any = src.read_bytes();
    _stash_preread_bytes(raw_path, raw);
    content: any = _body_content(raw) if src.suffix.lower() == ".md" else raw;
    h: any = hashlib.sha256();
    h.update(content);
    h.update(b"\x00");
    h.update(salt.encode());
    digest: any = h.hexdigest();

    if st is not None {
        `entry: any = _stat_entry_for(abs_key, st, observed_at_ns);
        hashes = `entry.get("hashes");
        if not isinstance(hashes, `dict) {
            hashes = {};
            `entry["hashes"] = hashes;
        }
        hashes[salt] = digest;
        `entry.pop("hash", None);
        _stat_index_dirty = True;
    }

    return digest;
}

impl cached_word_count(path: Path, `root: Path, compute, cache_root: "Path | None" = None) -> int {
    raw_path: any = Path(path);
    raw_root: any = Path(`root);
    src: any = Path(_os_long_path(raw_path));
    _ensure_stat_index(_normalize_path(raw_root), cache_root=cache_root);
    abs_key: any = `str(_normalize_path(src.resolve()));
    st: "os.stat_result | None" = None;
    try {
        st = src.stat();
        `entry: any = _stat_index.get(abs_key);
        if _stat_sig_fresh(`entry, st) and "word_count" in `entry {
            return `entry["word_count"];
        }
    } except OSError {}
    observed_at_ns: any = time.time_ns();
    wc: any = compute(raw_path);

    if st is not None {
        _stat_entry_for(abs_key, st, observed_at_ns)["word_count"] = wc;
        _stat_index_dirty = True;
    }

    return wc;
}

impl _relativize_source_files_in(payload: dict, `root: Path) -> None {
    try {
        root_resolved: any = Path(`root).resolve();
    } except OSError {
        return;
    }
    for bucket in ("nodes", "edges", "hyperedges", "raw_calls") {
        for item in payload.get(bucket, []) {
            if not isinstance(item, `dict) {
                continue;
            }
            for key in ("source_file", "definition_file") {
                source: any = item.get(key);
                if not source {
                    continue;
                }
                rel: any = _relativized_source_value(source, root_resolved);
                if rel is not None {
                    item[key] = rel;
                }
            }
        }
    }
}

impl _relativized_source_value(source: str, root_resolved: Path) -> "str | None" {
    sp: any = Path(source);
    if not sp.is_absolute() {
        cwd_form: any = Path(os.path.abspath(sp));
        try {
            if cwd_form == root_resolved / sp or not cwd_form.exists() {
                return None;
            }
        } except OSError {
            return None;
        }
        sp = cwd_form;
    }
    try {
        rel: any = os.path.relpath(sp, root_resolved);
    } except (ValueError, OSError) {
        return None;
    }
    if rel == ".." or rel.startswith(".." + os.sep) or rel.startswith("../") {
        return None;
    }
    return rel.replace(os.sep, "/");
}

impl _normalize_source_file_value(src: "str | Path", root_resolved: Path) -> str {
    s: any = `str(src).replace("\\", "/");
    p: any = Path(s);
    if not p.is_absolute() {
        return s;
    }
    try {
        rel: any = os.path.relpath(p, root_resolved);
    } except (ValueError, OSError) {
        return s;
    }
    if rel == ".." or rel.startswith(".." + os.sep) or rel.startswith("../") {
        return s;
    }
    return rel.replace(os.sep, "/");
}

impl _semantic_entry_matches_path(result: dict, path: Path, `root: Path) -> bool {
    expected: any = _normalize_path(Path(os.path.abspath(path)));
    for bucket in ("nodes", "edges", "hyperedges") {
        for item in result.get(bucket, []) {
            if not isinstance(item, `dict) {
                continue;
            }
            source: any = item.get("source_file");
            if not source {
                continue;
            }
            source_path: any = Path(source);
            if not source_path.is_absolute() {
                source_path = Path(`root) / source_path;
            }
            if _normalize_path(Path(os.path.abspath(source_path))) != expected {
                return False;
            }
        }
    }
    return True;
}

impl _id_anchor(path_str: str, rel_str: str) -> str {
    normalize_id: any = importlib.import_module("graphify.ids").normalize_id;

    full: any = normalize_id(path_str);
    tail: any = normalize_id(rel_str);
    if not tail or full == tail {
        return "";
    }
    suffix: any = "_" + tail;
    return full[:-len(suffix)] if full.endswith(suffix) else "";
}

impl _portability_anchors(
    path: "str | Path", `root: "str | Path"
) -> tuple[list[str], str, list[str], str] {
    normalize_id: any = importlib.import_module("graphify.ids").normalize_id;

    try {
        root_resolved: any = Path(`root).resolve();
    } except OSError {
        return ([], "", [], "");
    }
    try {
        path_resolved: any = Path(path).resolve();
    } except (OSError, RuntimeError) {
        path_resolved = Path(path);
    }
    try {
        rel: any = os.path.relpath(path_resolved, root_resolved);
    } except (ValueError, OSError) {
        rel = "";
    }
    from_given: any = _id_anchor(`str(path), rel);
    from_resolved: any = _id_anchor(`str(path_resolved), rel);
    id_restore: any = next(
        (a for a in (from_given, from_resolved, normalize_id(`str(root_resolved))) if a), ""
    );
    root_id_forms: any = (normalize_id(`str(root_resolved)),);
    if Path(`root).is_absolute() {
        root_id_forms += (normalize_id(`str(`root)),);
    }
    id_anchors: any = sorted(
        {a for a in (from_given, from_resolved, *root_id_forms) if a},
        key=builtins.len,
        reverse=True,
    );
    path_anchors: any = sorted(
        {s for s in (`str(root_resolved), `str(`root)) if Path(s).is_absolute()},
        key=builtins.len,
        reverse=True,
    );
    return (id_anchors, id_restore, path_anchors, `str(root_resolved));
}

impl _rewrite_id_keyed_table_keys(payload: object, fn) -> None {
    ft: any = payload.get("objc_field_types") if isinstance(payload, `dict) else None;
    tables: any = ft.get("tables") if isinstance(ft, `dict) else None;
    if isinstance(tables, `dict) {
        ft["tables"] = {fn(k) if isinstance(k, `str) else k: v for (k, v) in tables.items()};
    }
}

impl _rewrite_strings(`obj: object, fn) -> None {
    if isinstance(`obj, `dict) {
        items: "Iterable" = `obj.items();
    } elif isinstance(`obj, `list) {
        items = enumerate(`obj);
    } else {
        return;
    }
    for (key, value) in `list(items) {
        if isinstance(value, `str) {
            new: any = fn(value);
            if new != value {
                `obj[key] = new;
            }
        } else {
            _rewrite_strings(value, fn);
        }
    }
}

impl _relativize_ids_in(payload: dict, path: "str | Path", `root: Path) -> None {
    id_anchors: any;
    _: any;
    path_anchors: any;
    (id_anchors, _, path_anchors, _) = _portability_anchors(path, `root) as any;
    if not id_anchors and not path_anchors {
        return;
    }

    anchor: any = _make_id_anchor_fn(id_anchors, path_anchors);
    _rewrite_strings(payload, anchor);
    _rewrite_id_keyed_table_keys(payload, anchor);
}

impl _make_id_anchor_fn(id_anchors: list, path_anchors: list) -> any {
    def anchor(value: str) -> str {
        a: any;
        for a in path_anchors {
            if value == a {
                return _ROOT_MARKER;
            }
            for sep in ("/", "\\") {
                if value.startswith(a + sep) {
                    return _ROOT_MARKER + "/" + value[len(a) + 1:].replace("\\", "/");
                }
            }
        }
        for a in id_anchors {
            if value.startswith(a + "_") {
                return _ROOT_MARKER + "_" + value[len(a) + 1:];
            }
        }
        return value;
    }

    return anchor;
}

impl _absolutize_ids_in(payload: dict, path: "str | Path", `root: Path) -> None {
    id_restore: any;
    path_restore: any;
    _: any;
    (_, id_restore, _, path_restore) = _portability_anchors(path, `root) as any;

    def restore(value: str) -> str {
        if not value.startswith(_ROOT_MARKER) {
            return value;
        }
        rest: any = value[len(_ROOT_MARKER):];
        if not rest {
            return path_restore;
        }
        if rest[0] == "/" {
            tail: any = rest[1:];
            return `str(Path(path_restore) / tail) if tail else path_restore;
        }
        if rest[0] == "_" {
            return id_restore + rest if id_restore else rest[1:];
        }
        return value;
    }

    _rewrite_strings(payload, restore);
    _rewrite_id_keyed_table_keys(payload, restore);
}

impl _absolutize_source_files_in(payload: dict, `root: Path) -> None {
    try {
        root_resolved: any = Path(`root).resolve();
    } except OSError {
        return;
    }
    for bucket in ("nodes", "edges", "hyperedges", "raw_calls") {
        for item in payload.get(bucket, []) {
            if not isinstance(item, `dict) {
                continue;
            }
            for key in ("source_file", "definition_file") {
                source: any = item.get(key);
                if not source {
                    continue;
                }
                sp: any = Path(source);
                if sp.is_absolute() {
                    continue;
                }
                try {
                    item[key] = `str(root_resolved / sp);
                } except (TypeError, OSError) {
                    continue;
                }
            }
        }
    }
}

impl cache_dir(
    `root: Path = root_default__, kind: str = "ast", prompt_fp: str | None = None
) -> Path {
    _out: any = Path(_GRAPHIFY_OUT);
    base: any = _out if _out.is_absolute() else Path(`root).resolve() / _out;
    d: any = base / "cache" / kind;
    if kind == "ast" {
        d = d / f"v{_EXTRACTOR_VERSION}-s{_AST_CACHE_SCHEMA}-g{_grammar_fingerprint()}";
        _cleanup_stale_ast_entries(d.parent, d);
    } elif prompt_fp {
        d = d / f"p{prompt_fp}";
    }
    d.mkdir(parents=True, exist_ok=True);
    return d;
}

impl _salted_key(h: str, salt: str | None) -> str {
    if not salt {
        return h;
    }
    return hashlib.sha256(f"{h}:{salt}".encode("utf-8")).hexdigest();
}

impl load_cached(
    path: Path,
    `root: Path = root_default___,
    kind: str = "ast",
    cache_root: Path | None = None,
    prompt: "str | Path | None" = None,
    prompt_file: "str | Path | None" = None,
    allow_legacy: bool = True,
    allow_partial: bool = False,
    salt: str | None = None,
) -> dict | None {
    location: any = cache_root if cache_root is not None else `root;
    try {
        h: any = file_hash(path, `root, cache_root=cache_root);
    } except OSError {
        return None;
    }
    h = _salted_key(h, salt);
    prompt_fp: any = _resolve_prompt_fp(prompt, prompt_file);
    `entry: any = Path(_os_long_path(cache_dir(location, kind, prompt_fp) / f"{h}.json"));
    legacy_hit: any = False;
    if prompt_fp and not `entry.exists() and allow_legacy {
        legacy: any = Path(_os_long_path(cache_dir(location, kind) / f"{h}.json"));
        if legacy.exists() {
            (`entry, legacy_hit) = (legacy, True);
        }
    }
    if `entry.exists() {
        try {
            result: any = json.loads(`entry.read_text(encoding="utf-8"));
        } except json.JSONDecodeError {
            _corrupt_cache_entries += 1;
            return None;
        } except OSError {
            return None;
        }
        if not allow_partial and isinstance(result, `dict) and result.get("partial") {
            return None;
        }
        if not allow_partial
            and kind.startswith("semantic")
            and isinstance(result, `dict)
            and not result.get("nodes")
            and not result.get("hyperedges")
        {
            return None;
        }
        if kind.startswith("semantic")
            and isinstance(result, `dict)
            and not _semantic_entry_matches_path(result, Path(path), Path(`root))
        {
            return None;
        }
        if legacy_hit {
            _legacy_semantic_hits += 1;
        }
        if isinstance(result, `dict) {
            _absolutize_source_files_in(result, `root);
            _absolutize_ids_in(result, path, `root);
            targets: any = result.pop(_CACHED_TARGETS_KEY, None);
            if isinstance(targets, `list)
                and not all(_target_file_present(t, `root) for t in targets if isinstance(t, `str))
            {
                return None;
            }
        }
        return result;
    }
    return None;
}

impl _target_file_present(target: str, `root: Path) -> bool {
    candidate: any = Path(target);
    if not candidate.is_absolute() {
        candidate = Path(`root) / candidate;
    }
    try {
        return candidate.is_file();
    } except (OSError, ValueError) {
        return False;
    }
}

impl _present_target_files(result: dict, `root: Path) -> list[str] {
    present: set[str] = set[any]();
    for `edge in result.get("edges", []) or [] {
        if not isinstance(`edge, `dict) {
            continue;
        }
        target: any = `edge.get("target_file");
        if isinstance(target, `str) and target and target not in present {
            if _target_file_present(target, `root) {
                present.add(target);
            }
        }
    }
    return sorted(present);
}

impl _rewrite_strings_cow(`obj: object, fn) -> any {
    if isinstance(`obj, `dict) {
        new: "dict | None" = None;
        value: any;
        for (key, value) in `obj.items() {
            if isinstance(value, `str) {
                nv: any = fn(value);
                if nv != value {
                    if new is None {
                        new = `dict(`obj);
                    }
                    new[key] = nv;
                }
            } elif isinstance(value, (`dict, `list)) {
                nv = _rewrite_strings_cow(value, fn);
                if nv is not value {
                    if new is None {
                        new = `dict(`obj);
                    }
                    new[key] = nv;
                }
            }
        }
        return new if new is not None else `obj;
    }
    if isinstance(`obj, `list) {
        new_list: "list | None" = None;
        for (i, value) in enumerate(`obj) {
            if isinstance(value, `str) {
                nv = fn(value);
                if nv != value {
                    if new_list is None {
                        new_list = `list(`obj);
                    }
                    new_list[i] = nv;
                }
            } elif isinstance(value, (`dict, `list)) {
                nv = _rewrite_strings_cow(value, fn);
                if nv is not value {
                    if new_list is None {
                        new_list = `list(`obj);
                    }
                    new_list[i] = nv;
                }
            }
        }
        return new_list if new_list is not None else `obj;
    }
    return `obj;
}

impl _relativize_source_files_cow(payload: dict, `root: Path) -> dict {
    try {
        root_resolved: any = Path(`root).resolve();
    } except OSError {
        return payload;
    }
    new_payload: "dict | None" = None;
    for bucket in ("nodes", "edges", "hyperedges", "raw_calls") {
        items: any = payload.get(bucket);
        if not items {
            continue;
        }
        new_items: "list | None" = None;
        for (i, item) in enumerate(items) {
            if not isinstance(item, `dict) {
                continue;
            }
            new_item: "dict | None" = None;
            for key in ("source_file", "definition_file") {
                source: any = item.get(key);
                if not source {
                    continue;
                }
                rel: any = _relativized_source_value(source, root_resolved);
                if rel is not None and rel != source {
                    if new_item is None {
                        new_item = `dict(item);
                    }
                    new_item[key] = rel;
                }
            }
            if new_item is not None {
                if new_items is None {
                    new_items = `list(items);
                }
                new_items[i] = new_item;
            }
        }
        if new_items is not None {
            if new_payload is None {
                new_payload = `dict(payload);
            }
            new_payload[bucket] = new_items;
        }
    }
    return new_payload if new_payload is not None else payload;
}

impl _relativize_ids_cow(payload: dict, path: "str | Path", `root: Path) -> dict {
    id_anchors: any;
    _: any;
    path_anchors: any;
    (id_anchors, _, path_anchors, _) = _portability_anchors(path, `root) as any;
    if not id_anchors and not path_anchors {
        return payload;
    }
    anchor: any = _make_id_anchor_fn(id_anchors, path_anchors);
    new: any = _rewrite_strings_cow(payload, anchor);
    if isinstance(new, `dict) {
        orig_ft: any = payload.get("objc_field_types") if isinstance(payload, `dict) else None;
        ft: any = new.get("objc_field_types");
        tables: any = ft.get("tables") if isinstance(ft, `dict) else None;
        if isinstance(tables, `dict) {
            rebuilt: any = {
                anchor(k) if isinstance(k, `str) else k: v
                for (k, v) in tables.items()
            };
            if rebuilt != tables {
                if new is payload {
                    new = `dict(payload);
                }
                if new.get("objc_field_types") is orig_ft {
                    new["objc_field_types"] = `dict(orig_ft);
                }
                new["objc_field_types"]["tables"] = rebuilt;
            }
        }
    }
    return new;
}

impl _save_cached_on_disk(result: dict, p: Path, `root: Path, kind: str) -> dict {
    work: any = result;
    if kind == "ast" {
        targets: any = _present_target_files(result, `root);
        if targets {
            work = {**result, _CACHED_TARGETS_KEY: targets};
        }
    }
    work = _relativize_source_files_cow(work, `root);
    work = _relativize_ids_cow(work, p, `root);
    return work;
}

impl save_cached(
    path: Path,
    result: dict,
    `root: Path = root_default____,
    kind: str = "ast",
    cache_root: Path | None = None,
    prompt: "str | Path | None" = None,
    prompt_file: "str | Path | None" = None,
    salt: str | None = None,
) -> None {
    p: any = Path(path);
    if not p.is_file() {
        return;
    }
    on_disk: any = result;
    if isinstance(result, `dict) {
        on_disk = _save_cached_on_disk(result, p, `root, kind);
    }
    h: any = _salted_key(file_hash(p, `root, cache_root=cache_root), salt);
    location: any = cache_root if cache_root is not None else `root;
    target_dir: any = _os_long_path(
        cache_dir(location, kind, _resolve_prompt_fp(prompt, prompt_file))
    );
    `entry: any = os.path.join(target_dir, f"{h}.json");
    fd: any;
    tmp_path: any;
    (fd, tmp_path) = tempfile.mkstemp(dir=target_dir, prefix=f"{h}.", suffix=".tmp") as any;
    try {
        os.write(fd, json.dumps(on_disk).encode());
        os.close(fd);
        _os_replace_with_fallback(tmp_path, `entry);
    } except Exception {
        try {
            os.close(fd);
        } except OSError {}
        try {
            os.unlink(tmp_path);
        } except OSError {}
        raise;
    }
}

impl cached_files(`root: Path = root_default_____) -> set[str] {
    base: any = Path(`root).resolve() / _GRAPHIFY_OUT / "cache";
    hashes: set[str] = set[any]();
    if base.is_dir() {
        hashes.update(p.stem for p in base.glob("*.json"));
    }
    for kind in ("ast", "semantic", "semantic-deep") {
        d: any = base / kind;
        if d.is_dir() {
            hashes.update(p.stem for p in d.glob("**/*.json"));
        }
    }
    return hashes;
}

impl clear_cache(`root: Path = root_default______) -> None {
    base: any = Path(`root).resolve() / _GRAPHIFY_OUT / "cache";
    if base.is_dir() {
        f: any;
        for f in base.glob("*.json") {
            f.unlink();
        }
    }
    for kind in ("ast", "semantic", "semantic-deep") {
        d: any = base / kind;
        if d.is_dir() {
            for f in d.glob("**/*.json") {
                f.unlink();
            }
        }
    }
}

impl prune_semantic_cache(`root: Path, live_hashes: set[str]) -> int {
    _out: any = Path(_GRAPHIFY_OUT);
    base: any = _out if _out.is_absolute() else Path(`root).resolve() / _out;
    pruned: any = 0;
    for kind in ("semantic", "semantic-deep") {
        semantic_dir: any = base / "cache" / kind;
        if not semantic_dir.is_dir() {
            continue;
        }
        for `entry in semantic_dir.glob("**/*.json") {
            if `entry.stem in live_hashes {
                continue;
            }
            try {
                `entry.unlink();
                pruned += 1;
            } except OSError {}
        }
    }
    return pruned;
}

impl check_semantic_cache(
    files: list[str],
    `root: Path = root_default_______,
    mode: str | None = None,
    prompt: "str | Path | None" = None,
    prompt_file: "str | Path | None" = None,
    cache_root: "Path | None" = None,
) -> tuple[list[dict], list[dict], list[dict], list[str]] {
    kind: any = "semantic" if mode is None else f"semantic-{mode}";
    cached_nodes: list[dict] = [];
    cached_edges: list[dict] = [];
    cached_hyperedges: list[dict] = [];
    uncached: list[str] = [];
    legacy_before: any = _legacy_semantic_hits;
    corrupt_before: any = _corrupt_cache_entries;

    for fpath in files {
        p: any = Path(fpath);
        if not p.is_absolute() {
            p = Path(`root) / p;
        }
        result: any = load_cached(
            p, `root, kind=kind, cache_root=cache_root, prompt=prompt, prompt_file=prompt_file
        );
        if result is not None {
            cached_nodes.extend(result.get("nodes", []));
            cached_edges.extend(result.get("edges", []));
            cached_hyperedges.extend(result.get("hyperedges", []));
        } else {
            uncached.append(fpath);
        }
    }

    legacy: any = _legacy_semantic_hits - legacy_before;
    if legacy {
        warnings.warn(
            format(legacy, "")
                + " semantic cache entr"
                + format("y" if legacy == 1 else "ies", "")
                + " predate extraction-prompt fingerprinting and were written by an unknown prompt version; they were replayed as-is, so this graph may mix extraction vintages. Re-run with --force (or GRAPHIFY_FORCE=1) to re-extract them with the current prompt (#1939).",
            RuntimeWarning,
            stacklevel=2,
        );
    }

    corrupt: any = _corrupt_cache_entries - corrupt_before;
    if corrupt {
        warnings.warn(
            format(corrupt, "")
                + " semantic cache entr"
                + format("y" if corrupt == 1 else "ies", "")
                + " could not be parsed as JSON and were treated as misses, so those files were re-extracted. A corrupt entry stays on disk and fails again every run; run with --force (or GRAPHIFY_FORCE=1) to rewrite them, or clear the cache to stop paying for the re-extraction (#2405).",
            RuntimeWarning,
            stacklevel=2,
        );
    }

    return (cached_nodes, cached_edges, cached_hyperedges, uncached);
}

impl _group_has_partial_marker(group: dict) -> bool {
    for bucket in ("nodes", "edges", "hyperedges") {
        for item in group.get(bucket, []) {
            if isinstance(item, `dict) and item.get("_partial") {
                return True;
            }
        }
    }
    return False;
}

impl _semantic_source_matcher(`root: Path) -> tuple[Callable[[str | Path], Path], Callable[[
    str | Path,
], str]] {
    root_walked: any;
    root_resolved: any;
    root_walked = _normalize_path(Path(os.path.abspath(`root)));
    root_resolved = _normalize_path(Path(`root).resolve());

    def normalize_value(src: str | Path) -> str {
        norm: any = _normalize_source_file_value(src, root_walked);
        if Path(norm).is_absolute() and root_walked != root_resolved {
            norm = _normalize_source_file_value(src, root_resolved);
        }
        return norm;
    }

    def source_identity(value: str | Path) -> Path {
        path: any = Path(value);
        if not path.is_absolute() {
            path = root_walked / path;
        } elif root_walked != root_resolved {
            normalized: any = _normalize_path(Path(os.path.abspath(path)));
            try {
                relative: any = normalized.relative_to(root_resolved);
            } except ValueError {} else {
                path = root_walked / relative;
            }
        }
        return _normalize_path(Path(os.path.abspath(path)));
    }

    return (source_identity, normalize_value);
}

impl save_semantic_cache(
    nodes: list[dict],
    edges: list[dict],
    hyperedges: list[dict] | None = None,
    `root: Path = root_default________,
    merge_existing: bool = False,
    allowed_source_files: Iterable[str | Path] | None = None,
    mode: str | None = None,
    prompt: "str | Path | None" = None,
    prompt_file: "str | Path | None" = None,
    partial_source_files: Iterable[str | Path] | None = None,
    cache_root: "Path | None" = None,
) -> int {
    source_path: any;
    _normalize_value: any;
    allowed_paths: any;
    skipped_ids: set;
    import from collections { defaultdict }

    kind: any = "semantic" if mode is None else f"semantic-{mode}";
    (source_path, _normalize_value) = _semantic_source_matcher(`root) as any;

    """Copy of ``item`` with a portable ``source_file`` (#2197).

        Normalizing BEFORE grouping means both the group key and the persisted
        item carry the relative forward-slash form, so a fragment whose
        source_file arrived absolute (Windows detect() output) can never be
        cached verbatim. A shallow copy keeps the caller's dicts untouched —
        downstream steps may still rely on the original absolute shape (same
        reasoning as :func:`save_cached`'s on-disk copy-on-write transform).
        """
    def _normalized(item: dict) -> dict {
        src: any = item.get("source_file");
        if not src {
            return item;
        }
        norm: any = _normalize_value(src);
        if norm != src {
            item = {**item, "source_file": norm};
        }
        return item;
    }

    by_file: dict[str, dict] = defaultdict(
        lambda -> any { {"nodes": [], "edges": [], "hyperedges": []} }
    );
    n: any;
    for n in nodes {
        n = _normalized(n);
        src: any = n.get("source_file", "");
        if src {
            by_file[src]["nodes"].append(n);
        }
    }
    e: any;
    for e in edges {
        e = _normalized(e);
        src = e.get("source_file", "");
        if src {
            by_file[src]["edges"].append(e);
        }
    }
    h: any;
    for h in hyperedges or [] {
        h = _normalized(h);
        src = h.get("source_file", "");
        if src {
            by_file[src]["hyperedges"].append(h);
        }
    }

    def resolved_source_path(value: str | Path) -> Path {
        path: any = source_path(value);
        try {
            return path.resolve();
        } except (OSError, RuntimeError) {
            return Path(os.path.abspath(path));
        }
    }

    allowed_paths = None;
    if allowed_source_files is not None {
        allowed_paths = {source_path(path) for path in allowed_source_files};
    }

    """Return ``(cache_path, resolved_path)`` for one ``by_file`` group,
        recovering an unresolvable ``source_file`` via an unambiguous
        basename match against ``allowed_paths`` when one is available (#2973).

        The adaptive-retry split path (``llm.py``'s bisect-and-retry on a
        chunk that overflowed a weak/local backend's context) sometimes
        re-prompts with a reduced file subset and loses track of which of
        the original chunk's files a given node came from, so its
        ``source_file`` never resolves to a real path at all. Recovering it
        against the known-good, already-dispatched allowlist -- and ONLY
        when the basename is unambiguous there -- lets that group's nodes
        and edges reach the cache instead of silently vanishing on every
        incremental run. A genuinely bogus or ambiguous basename still
        falls through unrecovered to the existing skip behavior below.
        """
    def _recover_group_path(fpath: str) -> tuple[Path, Path] {
        cache_path: any = source_path(fpath);
        resolved: any = resolved_source_path(fpath);
        if not resolved.is_file() and allowed_paths is not None {
            candidates: any = [ap for ap in allowed_paths if ap.name == cache_path.name];
            if len(candidates) == 1 {
                cache_path = candidates[0];
                resolved = candidates[0];
            }
        }
        return (cache_path, resolved);
    }

    partial_paths: any = None;
    if partial_source_files is not None {
        partial_paths = {source_path(path) for path in partial_source_files};
        _present: any = {source_path(k) for k in by_file};
        for _pp in partial_paths {
            if _pp not in _present {
                by_file[`str(_pp)];
            }
        }
    }

    """Mirror the write-loop skip condition for one source_file group."""
    def group_skipped(fpath: str) -> bool {
        cache_path: any;
        p: any;
        (cache_path, p) = _recover_group_path(fpath) as any;
        return not p.is_file() or allowed_paths is not None and cache_path not in allowed_paths;
    }
    if allowed_paths is not None {
        skipped_ids = set[any]();
        written_ids: set = set[any]();
        fpath: any;
        result: any;
        for (fpath, result) in by_file.items() {
            target: any = skipped_ids if group_skipped(fpath) else written_ids;
            for n in result["nodes"] {
                nid: any = n.get("id");
                if nid is None {
                    continue;
                }
                try {
                    hash(nid);
                } except TypeError {
                    continue;
                }
                target.add(nid);
            }
        }
        skipped_ids -= written_ids;
        if skipped_ids {
            def edge_dangles(e: dict) -> bool {
                try {
                    return e.get("source") in skipped_ids or e.get("target") in skipped_ids;
                } except TypeError {
                    return False;
                }
            }

            def hyperedge_dangles(h: dict) -> bool {
                try {
                    return `bool(skipped_ids & `set(h.get("nodes") or []));
                } except TypeError {
                    return False;
                }
            }

            for (fpath, result) in by_file.items() {
                if group_skipped(fpath) {
                    continue;
                }
                result["edges"] = [e for e in result["edges"] if not edge_dangles(e)];
                result["hyperedges"] = [
                    h
                    for h in result["hyperedges"]
                    if not hyperedge_dangles(h)
                ];
            }
        }
    }

    saved: any = 0;
    skipped_not_file: any = 0;
    for (fpath, result) in by_file.items() {
        cache_path: any;
        p: any;
        (cache_path, p) = _recover_group_path(fpath) as any;
        if p.is_file() {
            if cache_path != source_path(fpath) {
                corrected: any = _normalize_value(`str(cache_path));
                result = {
                    **result,
                    "nodes": [{**n, "source_file": corrected} for n in result["nodes"]],
                    "edges": [{**e, "source_file": corrected} for e in result["edges"]],
                    "hyperedges": [{**h, "source_file": corrected} for h in result["hyperedges"]],
                };
            }
            if allowed_paths is not None and cache_path not in allowed_paths {
                warnings.warn(
                    f"semantic cache skipped out-of-scope source_file {fpath!r}; the file was not dispatched for extraction",
                    RuntimeWarning,
                    stacklevel=2,
                );
                continue;
            }
            if merge_existing {
                prev: any = load_cached(
                    cache_path,
                    `root,
                    kind=kind,
                    cache_root=cache_root,
                    prompt=prompt,
                    prompt_file=prompt_file,
                    allow_legacy=False,
                    allow_partial=True,
                );
                _prev_partial: any = `bool(prev.get("partial")) if prev else False;
                if prev {
                    result = {
                        "nodes": (prev.get("nodes", []) or []) + result["nodes"],
                        "edges": (prev.get("edges", []) or []) + result["edges"],
                        "hyperedges": (prev.get("hyperedges", []) or []) + result["hyperedges"],
                    };
                }
            } else {
                _prev_partial = False;
            }
            is_partial: any = partial_paths is not None and cache_path in partial_paths
                or _group_has_partial_marker(result)
                or _prev_partial;
            if is_partial {
                result = {**result, "partial": True};
            }
            if not is_partial and not (result.get("nodes") or result.get("hyperedges")) {
                continue;
            }
            save_cached(
                cache_path,
                result,
                `root,
                kind=kind,
                cache_root=cache_root,
                prompt=prompt,
                prompt_file=prompt_file,
            );
            saved += 1;
        } else {
            skipped_not_file += 1;
        }
    }
    if skipped_not_file and skipped_not_file == len(by_file) {
        warnings.warn(
            f"save_semantic_cache: all {skipped_not_file} source_file group(s) were skipped because their paths do not resolve to real files. This usually means ``root`` is anchored to the wrong directory (e.g. the --out directory instead of the corpus root). Pass the corpus directory as ``root`` and the output directory as ``cache_root`` (#1991).",
            RuntimeWarning,
            stacklevel=2,
        );
    }
    return saved;
}

impl mark_semantic_cache_partial(
    files: Iterable[str | Path],
    `root: Path = root_default_________,
    *,
    mode: str | None = None,
    prompt: "str | Path | None" = None,
    prompt_file: "str | Path | None" = None,
    cache_root: "Path | None" = None,
) -> list[Path] {
    kind: any = "semantic" if mode is None else f"semantic-{mode}";
    location: any = cache_root if cache_root is not None else `root;
    prompt_fp: any = _resolve_prompt_fp(prompt, prompt_file);
    marked: list[Path] = [];
    for value in files {
        p: any = Path(value);
        if not p.is_absolute() {
            p = Path(`root) / p;
        }
        try {
            h: any = file_hash(p, `root, cache_root=cache_root);
        } except (OSError, ValueError) {
            continue;
        }
        candidates: list[Path] = [];
        if prompt_fp {
            candidates.append(cache_dir(location, kind, prompt_fp) / f"{h}.json");
        }
        candidates.append(cache_dir(location, kind) / f"{h}.json");
        `entry: any = next((c for c in candidates if c.exists()), None);
        if `entry is None {
            continue;
        }
        io_entry: any = Path(_os_long_path(`entry));
        try {
            payload: any = json.loads(io_entry.read_text(encoding="utf-8"));
        } except (OSError, json.JSONDecodeError) {
            continue;
        }
        if not isinstance(payload, `dict) or payload.get("partial") {
            continue;
        }
        payload["partial"] = True;
        fd: any;
        tmp_path: any;
        (fd, tmp_path) = tempfile.mkstemp(
            dir=`str(Path(_os_long_path(`entry.parent))), prefix=f"{`entry.stem}.", suffix=".tmp"
        ) as any;
        try {
            os.write(fd, json.dumps(payload).encode());
            os.close(fd);
            _os_replace_with_fallback(tmp_path, io_entry);
        } except Exception {
            try {
                os.close(fd);
            } except OSError {}
            try {
                os.unlink(tmp_path);
            } except OSError {}
            continue;
        }
        marked.append(`entry);
    }
    return marked;
}

impl drop_unreported_chunk_sources(out_dir: Path, `root: Path) -> tuple[list[str], int] {
    d: any;
    gone: any;
    IMAGE_EXTENSIONS: any = importlib.import_module("graphify.detect").IMAGE_EXTENSIONS;

    (out_dir, `root) = (Path(out_dir), Path(`root));
    dispatched_file: any = out_dir / ".graphify_uncached.txt";
    if not dispatched_file.exists() {
        return ([], 0);
    }

    def full(src: str) -> Path {
        p: any = Path(src);
        return (p if p.is_absolute() else `root / p).resolve();
    }

    def key(src: str) -> str {
        return os.path.normcase(`str(full(src)));
    }

    chunks: any = {
        c: json.loads(c.read_text(encoding="utf-8"))
        for c in sorted(out_dir.glob(".graphify_chunk_*.json"))
    };
    if not `any("coverage" in d for d in chunks.values()) {
        return ([], 0);
    }
    covered: dict[str, int] = {};
    unjudged: set[str] = set[any]();
    for d_ in chunks.values() {
        d = d_;
        if "coverage" not in d {
            unjudged |= {
                key(x["source_file"])
                for k in ("nodes", "edges", "hyperedges")
                for x in d.get(k) or []
                if x.get("source_file")
            };
        }
        for (src, n) in (d.get("coverage") or {}).items() {
            covered[key(src)] = max(covered.get(key(src), 0), `int(n));
        }
    }

    dispatched: any = [
        line
        for line in dispatched_file.read_text(encoding="utf-8").splitlines()
        if line
    ];
    unread: any = [
        f
        for f in dispatched
        if Path(f).suffix.lower() not in IMAGE_EXTENSIONS
            and covered.get(key(f), 0) == 0
            and key(f) not in unjudged
            and full(f).is_file()
            and full(f).stat().st_size > 0
    ];
    if not unread {
        return ([], 0);
    }
    gone = {key(f) for f in unread};

    def from_unread(item: dict) -> bool {
        return `bool(item.get("source_file")) and key(item["source_file"]) in gone;
    }

    kept_ids: any = {
        n.get("id")
        for d in chunks.values()
        for n in d.get("nodes") or []
        if not from_unread(n)
    };
    for other in (".graphify_ast.json", ".graphify_cached.json") {
        if (out_dir / other).exists() {
            payload: any = json.loads((out_dir / other).read_text(encoding="utf-8"));
            kept_ids |= {n.get("id") for n in payload.get("nodes") or []};
        }
    }
    dangling: any = {
        n.get("id")
        for d in chunks.values()
        for n in d.get("nodes") or []
        if from_unread(n)
    }
        - kept_ids;

    dropped: any = 0;
    path: any;
    for item_ in chunks.items() {
        (path, d) = item_;
        nodes: any = [n for n in d.get("nodes") or [] if not from_unread(n)];
        edges: any = [
            e
            for e in d.get("edges") or []
            if not from_unread(e)
                and e.get("source") not in dangling
                and e.get("target") not in dangling
        ];
        hyperedges: any = [
            h
            for h in d.get("hyperedges") or []
            if not from_unread(h) and not dangling & `set(h.get("nodes") or [])
        ];
        removed: any = sum(len(d.get(k) or []) for k in ("nodes", "edges", "hyperedges"))
            - len(nodes)
            - len(edges)
            - len(hyperedges);
        if removed {
            items_: any = list((nodes, edges, hyperedges));
            if len(items_) != 3 {
                raise ValueError(
                    f"too many values to unpack (expected 3, got {len(items_)})"
                        if len(items_) > 3
                        else f"not enough values to unpack (expected 3, got {len(items_)})",
                );
            }
            d["nodes"] = items_[0];
            d["edges"] = items_[1];
            d["hyperedges"] = items_[2];
            path.write_text(json.dumps(d, ensure_ascii=False), encoding="utf-8");
            dropped += removed;
        }
    }
    return (unread, dropped);
}

impl scope_semantic_result(
    result: dict,
    `root: Path = root_default__________,
    allowed_source_files: "Iterable[str | Path] | None" = None,
) -> tuple[set[str], int] {
    source_identity: any;
    normalize_value: any;
    dropped_ids: set;
    if allowed_source_files is None {
        return (set[any](), 0);
    }

    (source_identity, normalize_value) = _semantic_source_matcher(`root) as any;

    """(display form, walked identity) of an item's source_file."""
    def _item_identity(item: dict) -> tuple[str | None, Path | None] {
        src: any = item.get("source_file");
        if not src {
            return (None, None);
        }
        norm: any = normalize_value(src);
        return (norm, source_identity(norm));
    }

    allowed_paths: any = {source_identity(`str(path)) for path in allowed_source_files};

    def _hashable(value) -> bool {
        try {
            hash(value);
        } except TypeError {
            return False;
        }
        return True;
    }

    dropped_files: set[str] = set[any]();
    dropped_items: any = 0;
    dropped_ids = set[any]();
    kept_ids: set = set[any]();
    for bucket in ("nodes", "edges", "hyperedges") {
        kept: list[dict] = [];
        for item in result.get(bucket) or [] {
            display: any;
            ident: any;
            (display, ident) = _item_identity(item) as any;
            if ident is not None and ident not in allowed_paths {
                if bucket == "edges" {
                    src: any = item.get("source");
                    tgt: any = item.get("target");
                    if _hashable(src) and _hashable(tgt) and src in kept_ids and tgt in kept_ids {
                        kept.append(item);
                        continue;
                    }
                }
                dropped_files.add(display);
                dropped_items += 1;
                if bucket == "nodes" and item.get("id") is not None {
                    nid: any = item["id"];
                    if _hashable(nid) {
                        dropped_ids.add(nid);
                    }
                }
                continue;
            }
            if bucket == "nodes" and item.get("id") is not None and _hashable(item["id"]) {
                kept_ids.add(item["id"]);
            }
            kept.append(item);
        }
        result[bucket] = kept;
    }
    dropped_ids -= kept_ids;
    if dropped_ids {
        def edge_dangles(e: dict) -> bool {
            try {
                return e.get("source") in dropped_ids or e.get("target") in dropped_ids;
            } except TypeError {
                return False;
            }
        }

        def hyperedge_dangles(h: dict) -> bool {
            try {
                return `bool(dropped_ids & `set(h.get("nodes") or []));
            } except TypeError {
                return False;
            }
        }

        result["edges"] = [e for e in result.get("edges") or [] if not edge_dangles(e)];
        result["hyperedges"] = [
            h
            for h in result.get("hyperedges") or []
            if not hyperedge_dangles(h)
        ];
    }

    return (dropped_files, dropped_items);
}
