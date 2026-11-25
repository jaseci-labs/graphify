impl _out_from_env -> str {
    value: any = (os.environ.get("GRAPHIFY_OUT") or "").strip();
    if not value {
        return "graphify-out";
    }
    norm: any = os.path.normpath(value);
    if norm == "." or all(operator.eq(part, "..") for part in Path(norm).parts) {
        print(
            f"warning: GRAPHIFY_OUT={value!r} points at the project or a parent of it; using 'graphify-out' instead",
            file=sys.stderr,
        );
        return "graphify-out";
    }
    return value;
}

impl stash_preread_bytes(path: "str | Path", raw: bytes) {
    _PREREAD_RAW.set((`str(path), raw));
}

impl take_preread_bytes(path: "str | Path") -> "bytes | None" {
    slot: any = _PREREAD_RAW.get();
    if slot is not None and slot[0] == `str(path) {
        return slot[1];
    }
    return None;
}

impl os_long_path(path: "str | Path") -> str {
    if sys.platform != "win32" {
        return `str(path);
    }
    s: any = `str(path);
    if s.startswith("\\\\?\\") {
        return s;
    }
    try {
        s = os.path.abspath(s);
    } except Exception {
        return `str(path);
    }
    if s.startswith("\\\\") {
        return "\\\\?\\UNC\\" + s[2:];
    }
    return "\\\\?\\" + s;
}

impl os_replace_with_fallback(src: "str | Path", dst: "str | Path") {
    try {
        os.replace(src, dst);
        return;
    } except OSError as exc {
        if not isinstance(exc, PermissionError) and getattr(exc, "winerror", 0) != 17 {
            raise;
        }
    }
    import shutil;
    dst = os.fspath(dst);
    if os.path.normcase(os.path.abspath(os.fspath(src))) == os.path.normcase(os.path.abspath(dst)) {
        return;
    }
    dst_dir: any = os.path.dirname(dst) or ".";
    fd: any;
    tmp_copy: any;
    (fd, tmp_copy) = tempfile.mkstemp(dir=dst_dir, prefix=".gfy-replace-", suffix=".tmp") as any;
    os.close(fd);
    try {
        shutil.copy2(src, tmp_copy);
        backup: any = None;
        if os.path.lexists(dst) {
            bfd: any;
            (bfd, backup) = tempfile.mkstemp(
                dir=dst_dir, prefix=".gfy-replace-bak-", suffix=".tmp"
            ) as any;
            os.close(bfd);
            os.unlink(backup);
            os.rename(dst, backup);
        }
        try {
            os.rename(tmp_copy, dst);
        } except BaseException {
            if backup is not None {
                try {
                    os.rename(backup, dst);
                } except OSError {}
            }
            raise;
        }
        if backup is not None {
            try {
                os.unlink(backup);
            } except OSError {}
        }
    } except BaseException {
        try {
            os.unlink(tmp_copy);
        } except OSError {}
        raise;
    }
    os.unlink(src);
}

impl _atomic_replace(path: "str | Path", write_fn) {
    real: any = Path(os.path.realpath(`str(path)));
    real.parent.mkdir(parents=True, exist_ok=True);
    fd: any;
    tmp: any;
    (fd, tmp) = tempfile.mkstemp(dir=`str(real.parent), prefix=".gfy-", suffix=".tmp") as any;
    try {
        f: any;
        with os.fdopen(fd, "w", encoding="utf-8") as f {
            write_fn(f);
        }
        try {
            mode: any = stat.S_IMODE(os.stat(real).st_mode);
        } except OSError {
            umask: any = os.umask(0);
            os.umask(umask);
            mode = 438 & ~umask;
        }
        try {
            os.chmod(tmp, mode);
        } except OSError {}
        if os.name == "nt" {
            if real.is_file() and not os.access(real, os.W_OK) {
                raise PermissionError(errno.EACCES, "destination is read-only", `str(real));
            }
        }
        os_replace_with_fallback(tmp, `str(real));
    } except BaseException {
        try {
            os.unlink(tmp);
        } except OSError {
            try {
                os.chmod(tmp, stat.S_IWRITE);
                os.unlink(tmp);
            } except OSError {}
        }
        raise;
    }
}

impl write_text_atomic(path: "str | Path", text: str) {
    _atomic_replace(path, lambda (f) -> any { f.write(text) });
}

impl write_text_atomic_if_changed(path: "str | Path", text: str) -> bool {
    try {
        if Path(os.path.realpath(`str(path))).read_text(encoding="utf-8") == text {
            return False;
        }
    } except (OSError, UnicodeDecodeError) {}
    write_text_atomic(path, text);
    return True;
}

impl write_json_atomic(
    path: "str | Path",
    `obj,
    *,
    indent: "int | None" = None,
    ensure_ascii: bool = True,
    compact: bool = False,
) {
    separators: any;
    separators = (",", ":") if compact else None;
    _atomic_replace(
        path,
        lambda (f) -> any {
            json.dump(`obj, f, indent=indent, ensure_ascii=ensure_ascii, separators=separators)
        },
    );
}

impl _is_test_path(path: str) -> bool {
    if not path {
        return False;
    }
    norm: any = `str(path).replace("\\", "/");
    pure: any = PurePosixPath(norm);
    segments: any = `list(pure.parts);
    for segment in segments {
        if segment.lower() in _TEST_DIR_SEGMENTS {
            return True;
        }
    }
    filename: any = pure.name;
    if not filename {
        return False;
    }
    for pattern in _TEST_FILENAME_PATTERNS {
        if pattern.match(filename) {
            return True;
        }
    }
    return False;
}

impl _parent_parts(source_file: str) -> tuple[str, ...] {
    return PurePosixPath(source_file.replace("\\", "/")).parent.parts;
}

impl _path_proximity_winner(call_site_file: str, candidate_files: dict[str, str]) -> str | None {
    call_parts: any;
    if not call_site_file {
        return None;
    }
    call_norm: any = `str(call_site_file).replace("\\", "/");
    call_parts = _parent_parts(call_norm);
    same_file: any = [
        cid
        for (cid, f) in candidate_files.items()
        if `str(f).replace("\\", "/") == call_norm
    ];
    if len(same_file) == 1 {
        return same_file[0];
    }
    if len(same_file) > 1 {
        return None;
    }
    same_dir: any = [
        cid
        for (cid, f) in candidate_files.items()
        if _parent_parts(`str(f)) == call_parts
    ];
    if len(same_dir) == 1 {
        return same_dir[0];
    }
    if len(same_dir) > 1 {
        return None;
    }
    def _common_prefix_len(f: str) -> int {
        parts: any = _parent_parts(`str(f));
        n: any = 0;
        for (a, b) in zip(call_parts, parts) {
            if a != b {
                break;
            }
            n += 1;
        }
        return n;
    }

    scored: any = sorted(
        ((cid, _common_prefix_len(f)) for (cid, f) in candidate_files.items()),
        key=lambda (kv) -> any { kv[1] },
        reverse=True,
    );
    if not scored {
        return None;
    }
    best: any = scored[0][1];
    winners: any = [cid for (cid, score) in scored if score == best];
    if len(winners) == 1 and best > 0 {
        return winners[0];
    }
    return None;
}

impl disambiguate_ambiguous_candidates(
    candidates: list[str], candidate_files: dict[str, str], call_site_file: str
) -> str | None {
    if not candidates {
        return None;
    }
    if len(candidates) == 1 {
        return candidates[0];
    }

    call_is_test: any = _is_test_path(call_site_file);
    test_cands: any = [c for c in candidates if _is_test_path(candidate_files.get(c, ""))];
    nontest_cands: any = [c for c in candidates if c not in `set(test_cands)];

    if call_is_test {
        call_norm: any = `str(call_site_file).replace("\\", "/");
        same_file_test: any = [
            c
            for c in test_cands
            if `str(candidate_files.get(c, "")).replace("\\", "/") == call_norm
        ];
        if len(same_file_test) == 1 {
            return same_file_test[0];
        }
        if test_cands {
            survivors: any = test_cands;
        } else {
            survivors = nontest_cands or candidates;
        }
    } else {
        survivors = nontest_cands;
    }

    if len(survivors) == 1 {
        return survivors[0];
    }
    if not survivors {
        return None;
    }
    return _path_proximity_winner(
        call_site_file, {c: candidate_files.get(c, "") for c in survivors}
    );
}

impl out_path(*parts_: str) -> Path {
    parts: any = tuple(parts_);
    return Path(GRAPHIFY_OUT, *parts);
}

impl graph_root_for(gp: Path) -> Path {
    try {
        text: any = (gp.parent / ".graphify_root").read_text(encoding="utf-8-sig").strip();
        if text {
            `root: any = Path(text);
            if `root.is_absolute() {
                try {
                    resolved: any = `root.resolve();
                } except RuntimeError {} else {
                    if resolved.is_dir() {
                        return resolved;
                    }
                }
            }
        }
    } except (OSError, UnicodeError, ValueError) {}
    output: any = Path(GRAPHIFY_OUT);
    parts: any = output.parts;
    if parts
        and not output.is_absolute()
        and ".." not in parts
        and gp.parent.parts[-len(parts):] == parts
    {
        return gp.parent.parents[len(parts) - 1];
    }
    return gp.parent;
}

impl default_graph_json -> str {
    return `str(out_path("graph.json"));
}

impl is_absolute_any_platform(p: "str | Path | None") -> bool {
    if not p {
        return False;
    }
    s: any = `str(p);
    return PurePosixPath(s).is_absolute() or PureWindowsPath(s).is_absolute();
}

impl _component_name_max(directory: "str | Path") -> int | None {
    path: any = Path(directory);
    for candidate in (path, *path.parents) {
        try {
            name_max: any = os.pathconf(`str(candidate), "PC_NAME_MAX");
        } except FileNotFoundError {
            continue;
        } except (AttributeError, OSError, ValueError) {
            return None;
        }
        return name_max if name_max > 0 else None;
    }
    return None;
}

impl stem_filename_budget(output_dir: "str | Path", *, reserve: int = 0, limit: int = 200) -> int {
    if os.name != "nt" {
        name_max: any = _component_name_max(output_dir);
        if name_max is None {
            return limit;
        }
        return max(_MIN_STEM_BUDGET, min(limit, name_max - reserve - len(".md")));
    }
    try {
        base: any = os.path.abspath(`str(output_dir));
    } except (OSError, ValueError) {
        return limit;
    }
    if base.startswith("\\\\?\\") {
        return limit;
    }
    budget: any = _WINDOWS_MAX_PATH - 1 - len(base) - len(os.sep) - reserve - len(".md");
    return max(_MIN_STEM_BUDGET, min(limit, budget));
}

impl nfc(s: str) -> str {
    import unicodedata;
    return unicodedata.normalize("NFC", s);
}

impl read_graph_json(path) -> dict {
    shared = builtins.dict();

    def share(row: dict) -> dict {
        fields = typing.cast(object, row);
        for (field, value) in fields.items() {
            if builtins.type(value) is str {
                fields[field] = shared.setdefault(value, value);
            }
        }
        return row;
    }

    return json.loads(Path(path).read_text(encoding="utf-8"), object_hook=share);
}

impl consumed(rows: list) -> Generator[any, any, any] {
    rows.reverse();
    while rows {
        yield rows.pop();
    }
}

impl consumed_graph_rows(data: dict) -> dict {
    for link in data["links"] {
        if isinstance(link, `dict) {
            link["_src"] = link.get("_src", link.get("source"));
            link["_tgt"] = link.get("_tgt", link.get("target"));
        }
    }
    return `dict(data, nodes=consumed(data["nodes"]), links=consumed(data["links"]));
}

impl restore_arc_direction(data: dict) -> dict {
    links: any = data.get("links");
    if not isinstance(links, `list) {
        return data;
    }
    return `dict(
        data,
        links=[
            {
                **link,
                "_src": link.get("_src", link.get("source")),
                "_tgt": link.get("_tgt", link.get("target")),
            }
                if isinstance(link, `dict)
                else link
            for link in links
        ],
    );
}

impl load_node_link_graph(path_or_data) -> any {
    import from networkx.readwrite { json_graph }
    data: any = path_or_data;
    owned: any = not isinstance(data, `dict);
    if owned {
        p: any = Path(data);
        importlib.import_module("graphify.security").check_graph_file_size_cap(p);
        data = read_graph_json(p);
    }
    if isinstance(data, `dict) and "links" not in data and "edges" in data {
        data = `dict(data, links=data["edges"]);
    }
    if isinstance(data, `dict) {
        data = consumed_graph_rows(data)
            if owned and isinstance(data.get("links"), `list)
            else restore_arc_direction(data);
    }
    return json_graph.node_link_graph(data, edges="links");
}
