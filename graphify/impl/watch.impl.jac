impl _queue_pending(out_dir: Path, changed_paths: list[Path]) -> None {
    if not changed_paths {
        return;
    }
    out_dir.mkdir(parents=True, exist_ok=True);
    pending: any = out_dir / _PENDING_FILENAME;
    payload: any = "".join(f"{os.fspath(p)}\n" for p in changed_paths);
    fh: any;
    with open(pending, "a", encoding="utf-8") as fh {
        fh.write(payload);
    }
}

impl _drain_pending(out_dir: Path) -> list[Path] {
    pending: any = out_dir / _PENDING_FILENAME;
    if not pending.exists() {
        return [];
    }
    try {
        raw: any = pending.read_text(encoding="utf-8");
    } except OSError {
        return [];
    }
    with contextlib.suppress(FileNotFoundError) {
        pending.unlink();
    }
    seen: set[str] = set[any]();
    out: list[Path] = [];
    for line in raw.splitlines() {
        s: any = line.strip();
        if not s or s in seen {
            continue;
        }
        seen.add(s);
        out.append(Path(s));
    }
    return out;
}

impl _queue_pending_full(out_dir: Path) -> None {
    out_dir.mkdir(parents=True, exist_ok=True);
    (out_dir / _PENDING_FULL_FILENAME).touch();
}

impl _drain_pending_full(out_dir: Path) -> bool {
    try {
        (out_dir / _PENDING_FULL_FILENAME).unlink();
    } except FileNotFoundError {
        return False;
    }
    return True;
}

impl _queue_pending_incremental(out_dir: Path) -> None {
    out_dir.mkdir(parents=True, exist_ok=True);
    (out_dir / _PENDING_INCREMENTAL_FILENAME).touch();
}

impl _drain_pending_incremental(out_dir: Path) -> bool {
    try {
        (out_dir / _PENDING_INCREMENTAL_FILENAME).unlink();
    } except FileNotFoundError {
        return False;
    }
    return True;
}

impl _write_build_config(
    out_dir: Path,
    *,
    excludes: "list[str] | None",
    gitignore: bool | None = None,
    code_only: bool | None = None,
) -> None {
    if not excludes and gitignore is None and code_only is None {
        return;
    }
    try {
        out_dir.mkdir(parents=True, exist_ok=True);
        path: any = out_dir / _BUILD_CONFIG_FILENAME;
        try {
            config: any = json.loads(path.read_text(encoding="utf-8")) if path.is_file() else {};
        } except (OSError, json.JSONDecodeError) {
            config = {};
        }
        if not isinstance(config, `dict) {
            config = {};
        }
        if excludes {
            config["excludes"] = `list(excludes);
        }
        if gitignore is not None {
            config["gitignore"] = gitignore;
        }
        if code_only is not None {
            config["code_only"] = code_only;
        }
        path.write_text(json.dumps(config), encoding="utf-8");
    } except OSError {}
}

impl _read_build_excludes(out_dir: Path) -> list[str] {
    try {
        path: any = out_dir / _BUILD_CONFIG_FILENAME;
        if path.is_file() {
            cfg: any = json.loads(path.read_text(encoding="utf-8"));
            ex: any = cfg.get("excludes") if isinstance(cfg, `dict) else None;
            if isinstance(ex, `list) {
                return [`str(x) for x in ex if isinstance(x, `str) and x];
            }
        }
    } except (OSError, json.JSONDecodeError) {}
    return [];
}

impl _read_build_gitignore(out_dir: Path) -> bool {
    try {
        path: any = out_dir / _BUILD_CONFIG_FILENAME;
        if path.is_file() {
            cfg: any = json.loads(path.read_text(encoding="utf-8"));
            if isinstance(cfg, `dict) and isinstance(cfg.get("gitignore"), `bool) {
                return cfg["gitignore"];
            }
        }
    } except (OSError, json.JSONDecodeError) {}
    return True;
}

impl _read_build_code_only(out_dir: Path) -> bool {
    try {
        path: any = out_dir / _BUILD_CONFIG_FILENAME;
        if path.is_file() {
            cfg: any = json.loads(path.read_text(encoding="utf-8"));
            if isinstance(cfg, `dict) and cfg.get("code_only") is True {
                return True;
            }
        }
    } except (OSError, json.JSONDecodeError) {}
    return False;
}

impl _merge_changed_paths(*sources_: "list[Path] | None") -> list[Path] {
    sources: any = tuple(sources_);
    seen: set[str] = set[any]();
    out: list[Path] = [];
    for src in sources {
        if not src {
            continue;
        }
        for p in src {
            key: any = os.fspath(p);
            if key in seen {
                continue;
            }
            seen.add(key);
            out.append(p);
        }
    }
    return out;
}

impl _win_try_lock(fh, msvcrt, offset: int) -> OSError | None {
    try {
        fh.seek(offset);
        msvcrt.locking(fh.fileno(), msvcrt.LK_NBLCK, 1);
    } except OSError as exc {
        return exc;
    }
    return None;
}

impl _rebuild_lock(out_dir: Path, *, blocking: bool = False) -> Generator[any, any, any] {
    try {
        import fcntl;
    } except ImportError {
        fcntl = None;
    }
    try {
        import msvcrt;
    } except ImportError {
        msvcrt = None;
    }

    if fcntl is None and msvcrt is None {
        yield True;
        return;
    }

    out_dir.mkdir(parents=True, exist_ok=True);
    lock_path: any = out_dir / ".rebuild.lock";
    created_lock_file: any = not lock_path.exists();
    fh: any = open(lock_path, "a+", encoding="utf-8");
    acquired: any = False;
    _win_lock_offset: any = 4096;
    try {
        if fcntl is not None {
            flags: any = fcntl.LOCK_EX if blocking else fcntl.LOCK_EX | fcntl.LOCK_NB;
            try {
                fcntl.flock(fh.fileno(), flags);
            } except BlockingIOError {
                yield False;
                return;
            }
            for _ in range(100) {
                try {
                    fh_stat: any = os.fstat(fh.fileno());
                    path_stat: any = os.stat(lock_path);
                } except OSError {
                    same_file: any = False;
                } else {
                    same_file = operator.eq(fh_stat.st_dev, path_stat.st_dev)
                        and operator.eq(fh_stat.st_ino, path_stat.st_ino);
                }
                if same_file {
                    break;
                }
                with contextlib.suppress(OSError) {
                    fcntl.flock(fh.fileno(), fcntl.LOCK_UN);
                }
                fh.close();
                fh = open(lock_path, "a+", encoding="utf-8");
                try {
                    fcntl.flock(fh.fileno(), flags);
                } except BlockingIOError {
                    fh.close();
                    yield False;
                    return;
                }
            } else {
                with contextlib.suppress(OSError) {
                    fcntl.flock(fh.fileno(), fcntl.LOCK_UN);
                }
                fh.close();
                yield False;
                return;
            }
        } else {
            while True {
                lock_error: any = _win_try_lock(fh, msvcrt, _win_lock_offset);
                if lock_error is None {
                    break;
                }
                if lock_error.errno not in _WIN_LOCK_CONTENDED_ERRNOS {
                    print(
                        f"[graphify watch] cannot lock {lock_path} ({lock_error.__class__.__name__}: {lock_error}); this filesystem does not support byte-range locks, so rebuilds of this graph are not serialized.",
                        file=sys.stderr,
                    );
                    fh.close();
                    if created_lock_file {
                        with contextlib.suppress(OSError) {
                            if lock_path.stat().st_size == 0 {
                                lock_path.unlink();
                            }
                        }
                    }
                    yield True;
                    return;
                }
                if not blocking {
                    yield False;
                    return;
                }
                time.sleep(0.05);
            }
        }
        acquired = True;
        try {
            fh.seek(0);
            fh.truncate();
            fh.write(f"{os.getpid()}\n");
            fh.flush();
        } except OSError {}
        yield True;
    } finally {
        if acquired {
            if fcntl is not None {
                with contextlib.suppress(OSError) {
                    lock_path.unlink();
                }
                try {
                    fcntl.flock(fh.fileno(), fcntl.LOCK_UN);
                } except OSError {}
            } elif msvcrt is not None {
                try {
                    fh.seek(_win_lock_offset);
                    msvcrt.locking(fh.fileno(), msvcrt.LK_UNLCK, 1);
                } except OSError {}
            }
        }
        fh.close();
        if acquired and fcntl is None {
            with contextlib.suppress(OSError) {
                lock_path.unlink();
            }
        }
    }
}

impl _apply_resource_limits -> None {
    try {
        os.nice(10);
    } except (OSError, AttributeError) {}
    mb: any = os.environ.get("GRAPHIFY_REBUILD_MEMORY_LIMIT_MB", "").strip();
    if not mb {
        return;
    }
    try {
        limit: any = `int(mb) * 1024 * 1024;
    } except ValueError {
        return;
    }
    try {
        import resource;
        which: any = resource.RLIMIT_DATA if sys.platform == "darwin" else resource.RLIMIT_AS;
        soft: any;
        hard: any;
        (soft, hard) = resource.getrlimit(which) as any;
        new_hard: any = hard if hard != resource.RLIM_INFINITY and hard < limit else limit;
        resource.setrlimit(which, (limit, new_hard));
    } except (ImportError, ValueError, OSError) {}
}

impl _git_head(cwd: Path | str | None = None) -> str | None {
    import subprocess as _sp;
    try {
        r: any = _sp.run(
            ["git", "rev-parse", "HEAD"],
            stdin=_sp.DEVNULL,
            capture_output=True,
            text=True,
            timeout=3,
            cwd=`str(cwd) if cwd is not None else None,
        );
        return r.stdout.strip() if r.returncode == 0 else None;
    } except Exception {
        return None;
    }
}

impl _report_root_label(watch_path: Path) -> str {
    if watch_path.is_absolute() {
        return watch_path.name or `str(watch_path);
    }
    return Path.cwd().name if watch_path == Path(".") else `str(watch_path);
}

impl _graphify_root_marker_value(watch_path: Path) -> str {
    if Path(_GRAPHIFY_OUT).is_absolute() {
        return `str(watch_path.resolve());
    }
    return `str(watch_path);
}

impl _is_relative_to(path: Path, `root: Path) -> bool {
    try {
        path.relative_to(`root);
        return True;
    } except ValueError {
        return False;
    }
}

impl _changed_path_candidates(raw: Path, *, change_root: Path, watch_root: Path) -> list[Path] {
    if raw.is_absolute() {
        lexical: any = Path(os.path.abspath(raw));
        resolved: any = raw.resolve();
        return [lexical] if lexical == resolved else [lexical, resolved];
    }

    candidates: list[Path] = [];
    seen: set[str] = set[any]();
    for base in (change_root, watch_root) {
        lexical = Path(os.path.abspath(base / raw));
        for cand in (lexical, lexical.resolve()) {
            key: any = os.fspath(cand);
            if key in seen {
                continue;
            }
            seen.add(key);
            candidates.append(cand);
        }
    }
    return candidates;
}

impl _relativize_source_files(payload: dict, `root: Path, *, scope: Path | None = None) -> None {
    for bucket in ("nodes", "edges", "hyperedges") {
        for item in payload.get(bucket, []) {
            for key in _PORTABLE_PATH_KEYS {
                source: any = item.get(key);
                if not source {
                    continue;
                }
                source_path: any = Path(source);
                if not source_path.is_absolute() {
                    continue;
                }
                try {
                    resolved: any = source_path.resolve();
                    if scope is not None and not _is_relative_to(resolved, scope) {
                        continue;
                    }
                    item[key] = resolved.relative_to(`root).as_posix();
                } except ValueError {
                    continue;
                }
            }
        }
    }
}

impl _rebase_relative_source_files(payload: dict, source_root: Path, target_root: Path) -> None {
    if source_root == target_root {
        return;
    }
    for bucket in ("nodes", "edges", "hyperedges") {
        for item in payload.get(bucket, []) {
            declarations: any = (item.get("metadata") or {}).get("cpp_declaration_sites", []);
            proofs: any = [{"source_file": sf} for sf in item.get("_cpp_reconcile_files", [])];
            for record in [item, *declarations, *proofs] {
                for key in _PORTABLE_PATH_KEYS {
                    source: any = record.get(key);
                    if not source or Path(source).is_absolute() {
                        continue;
                    }
                    try {
                        record[key] = (source_root / source).relative_to(target_root).as_posix();
                    } except ValueError {
                        continue;
                    }
                }
            }
            if proofs {
                item["_cpp_reconcile_files"] = [proof["source_file"] for proof in proofs];
            }
        }
    }
}

impl _StoredSourcePaths.init(
    existing: dict, *, out: Path, project_root: Path, watch_root: Path, normalize_source
) {
    self.project_root = project_root;
    self.watch_root = watch_root;
    self._normalize_source = normalize_source;
    self.existing_source_root = project_root;
    self._identity_cache = {};
    self._in_watch_root_cache = {};
    self._absolute_identity_cache = {};
    self._rebased_cache = {};
    relative_marker_prefix: str | None = None;

    root_marker: any = out / ".graphify_root";
    if root_marker.exists() {
        try {
            saved_root: any = Path(root_marker.read_text(encoding="utf-8-sig").strip());
            if saved_root.is_absolute() {
                resolved: any = saved_root.resolve();
                if self._anchors_stored_sources(existing, resolved) {
                    self.existing_source_root = resolved;
                } else {
                    for candidate in (self.project_root, Path.cwd().resolve()) {
                        if self._anchors_stored_sources(existing, candidate) {
                            self.existing_source_root = candidate;
                            break;
                        }
                    } else {
                        self.existing_source_root = resolved;
                    }
                }
            } else {
                invocation_root: any = Path.cwd().resolve();
                if (invocation_root / saved_root).resolve() == watch_root {
                    self.existing_source_root = invocation_root;
                    relative_marker_prefix = posixpath.normpath(saved_root.as_posix());
                }
            }
        } except (OSError, ValueError) {}
    }

    self.legacy_watch_relative = False;
    if relative_marker_prefix not in (None, ".") {
        has_project_relative_source: any = False;
        for bucket in ("nodes", "links", "edges", "hyperedges") {
            for item in existing.get(bucket, []) {
                stored: any = normalize_source(item.get("source_file"));
                if not stored or Path(stored).is_absolute() {
                    continue;
                }
                normalized: any = posixpath.normpath(stored);
                if normalized == relative_marker_prefix
                    or normalized.startswith(relative_marker_prefix + "/")
                {
                    has_project_relative_source = True;
                    break;
                }
            }
            if has_project_relative_source {
                break;
            }
        }
        self.legacy_watch_relative = not has_project_relative_source;
    }
}

impl _StoredSourcePaths._anchors_stored_sources(
    existing: dict, `root: Path, sample: int = 25
) -> bool {
    checked: any = 0;
    for bucket in ("nodes", "links", "edges", "hyperedges") {
        for item in existing.get(bucket, []) {
            raw: any = item.get("source_file") if isinstance(item, `dict) else None;
            stored: any = self._normalize_source(raw) if raw else None;
            if not stored or is_absolute_any_platform(stored) {
                continue;
            }
            checked += 1;
            if (`root / Path(posixpath.normpath(stored))).exists() {
                return True;
            }
            if checked >= sample {
                return False;
            }
        }
    }
    return operator.eq(checked, 0);
}

impl _StoredSourcePaths.normalize(source_file: str | None) -> str | None {
    normalized: any = self._normalize_source(source_file, `str(self.project_root));
    return posixpath.normpath(normalized) if normalized else normalized;
}

impl _StoredSourcePaths.absolute_identity(source_file: str | None, `root: Path) -> str | None {
    if not isinstance(source_file, `str) {
        return self._absolute_identity_uncached(source_file, `root);
    }
    key: any = (source_file, `root);
    try {
        return self._absolute_identity_cache[key];
    } except KeyError {
        value_: any = self._absolute_identity_uncached(source_file, `root);
        identity: any = value_;
        self._absolute_identity_cache[key] = value_;
        return identity;
    }
}

impl _StoredSourcePaths._absolute_identity_uncached(source_file: str | None, `root: Path) -> str
    | None {
    normalized: any = self._normalize_source(source_file);
    if not normalized {
        return normalized;
    }
    source_path: any = Path(posixpath.normpath(normalized));
    if not source_path.is_absolute() {
        source_path = `root / source_path;
    }
    return Path(os.path.abspath(source_path)).as_posix();
}

impl _StoredSourcePaths.identity(source_file: str | None) -> str | None {
    if not isinstance(source_file, `str) {
        return self._identity_uncached(source_file);
    }
    try {
        return self._identity_cache[source_file];
    } except KeyError {
        value__: any = self._identity_uncached(source_file);
        identity: any = value__;
        self._identity_cache[source_file] = value__;
        return identity;
    }
}

impl _StoredSourcePaths._identity_uncached(source_file: str | None) -> str | None {
    normalized: any = self._normalize_source(source_file);
    if normalized and not Path(normalized).is_absolute() and self.legacy_watch_relative {
        return self.absolute_identity(normalized, self.watch_root);
    }
    return self.absolute_identity(normalized, self.existing_source_root);
}

impl _StoredSourcePaths.in_watch_root(source_file: str | None) -> bool {
    if isinstance(source_file, `str) and source_file in self._in_watch_root_cache {
        return self._in_watch_root_cache[source_file];
    }
    identity: any = self.identity(source_file);
    inside: any = `bool(identity) and _is_relative_to(Path(identity), self.watch_root);
    if isinstance(source_file, `str) {
        self._in_watch_root_cache[source_file] = inside;
    }
    return inside;
}

impl _StoredSourcePaths.is_evicted(item: dict, identities: set[str]) -> bool {
    return self.identity(item.get("source_file")) in identities;
}

impl _StoredSourcePaths.rebase_preserved(item: dict) -> None {
    source_file: any = item.get("source_file");
    if not isinstance(source_file, `str) {
        rebased: any = self._rebased_uncached(source_file);
    } else {
        try {
            rebased = self._rebased_cache[source_file];
        } except KeyError {
            value___: any = self._rebased_uncached(source_file);
            rebased = value___;
            self._rebased_cache[source_file] = value___;
        }
    }
    if rebased is not None {
        item["source_file"] = rebased;
    }
}

impl _StoredSourcePaths._rebased_uncached(source_file: str | None) -> str | None {
    identity: any = self.identity(source_file);
    if not identity {
        return None;
    }
    identity_path: any = Path(identity);
    if not _is_relative_to(identity_path, self.watch_root) {
        return self.normalize(source_file) or None;
    }
    try {
        return identity_path.relative_to(self.project_root).as_posix();
    } except ValueError {
        return identity;
    }
}

impl _StoredSourcePaths.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl _StoredSourcePaths.__eq__(other: any) -> bool {
    return self is other;
}

impl _StoredSourcePaths.__hash__ -> int {
    return id(self);
}

impl _is_remote_source(source_file: str) -> bool {
    return `bool(_REMOTE_SOURCE_RE.match(source_file));
}

impl _reconcile_markdown_links(
    result: dict,
    preserved_edges: list[dict],
    preserved_nodes: list[dict],
    code_files: list[Path],
    extract_targets: list[Path],
    full_rebuild: bool,
    project_root: Path,
    source_paths,
) -> list[dict] {
    nodes_by_id: any;
    `node: any;
    parsed_sources: set[str];
    authored_links: set[tuple[str, str]];
    authored_raw_pairs: set[frozenset[str]];
    unresolved_authored_sites: dict[tuple[str, str], set[str]];
    resolved_raw_pairs: dict[frozenset[str], frozenset[str]];
    node_sources: any;
    desired_file_pairs: any;
    desired_reps_by_file_pair: any;
    _is_ast_tier: any = importlib.import_module("graphify.build")._is_ast_tier;
    _file_node_id: any = importlib.import_module("graphify.extract")._file_node_id;
    _safe_extract_with_xaml_root: any = importlib.import_module("graphify.extract")._safe_extract_with_xaml_root;
    _make_id: any = importlib.import_module("graphify.extractors.base")._make_id;
    extract_markdown: any = importlib.import_module("graphify.extractors.markdown").extract_markdown;
    MARKDOWN_MENTION_SUFFIXES: any = importlib.import_module("graphify.markdown_resolution").MARKDOWN_MENTION_SUFFIXES;
    _is_file_node: any = importlib.import_module("graphify.markdown_resolution")._is_file_node;

    all_nodes: any = result.get("nodes", []) + preserved_nodes;
    nodes_by_id = {`node["id"]: `node for `node in all_nodes if `node.get("id")};
    nodes_by_source: dict[str, list[dict]] = {};
    for `node in all_nodes {
        if source_file := `node.get("source_file") {
            normalized: any = source_paths.normalize(source_file);
            nodes_by_source.setdefault(normalized, []).append(`node);
        }
    }

    representatives: dict[str, str | None] = {};
    for (source_file, nodes) in nodes_by_source.items() {
        canonical_id: any = _file_node_id(Path(source_file));
        canonical: any = [`node for `node in nodes if `node["id"] == canonical_id];
        pages: any = [`node for `node in nodes if `node.get("node_kind") == "page"];
        semantic_documents: any = [
            `node
            for `node in nodes
            if `node.get("file_type") == "document" and `node.get("_origin") != "ast"
        ];
        if len(canonical) == 1 {
            representatives[source_file] = canonical[0]["id"];
        } elif len(pages) == 1 {
            representatives[source_file] = pages[0]["id"];
        } elif len(semantic_documents) == 1 {
            representatives[source_file] = semantic_documents[0]["id"];
        } else {
            representatives[source_file] = None;
        }
    }

    markdown_files: any = code_files if full_rebuild else extract_targets;
    markdown_files = [
        path
        for path in markdown_files
        if path.suffix.lower() in MARKDOWN_MENTION_SUFFIXES
    ];
    parsed_sources = set[any]();
    authored_links = set[any]();
    authored_raw_pairs = set[any]();
    unresolved_authored_sites = {};
    resolved_raw_pairs = {};
    desired_edges: list[tuple[str, str, dict, str, str]] = [];
    node_sources = {
        `node["id"]: source_paths.normalize(`node["source_file"])
        for `node in all_nodes
        if `node.get("source_file")
    };

    for markdown_file in markdown_files {
        try {
            relative_source: any = markdown_file.relative_to(project_root);
        } except ValueError {
            relative_source = markdown_file;
        }
        source_file = source_paths.normalize(`str(relative_source));
        source_rep: any = representatives.get(source_file);

        extraction: any = _safe_extract_with_xaml_root(
            extract_markdown, markdown_file, project_root
        );
        if extraction.get("error") {
            continue;
        }
        parsed_sources.add(source_file);
        `edge: any;
        for `edge in extraction.get("edges", []) {
            if `edge.get("relation") != "references" {
                continue;
            }
            if not `edge.get("target_file") {
                source_location: any = `str(`edge.get("source_location") or "");
                if source_location {
                    unresolved_authored_sites.setdefault(
                        (source_file, source_location), set[any]()
                    ).add(`str(`edge.get("target") or ""));
                }
                continue;
            }
            target_path: any = Path(`edge["target_file"]);
            try {
                target_path = target_path.relative_to(project_root);
            } except ValueError {}
            target_file: any = source_paths.normalize(`str(target_path));
            authored_links.add((source_file, target_file));
            raw_pair: any = frozenset((
                _file_node_id(Path(source_file)),
                _file_node_id(Path(target_file)),
            ));
            authored_raw_pairs.add(raw_pair);

            target_rep: any = representatives.get(target_file);
            if not source_rep or not target_rep {
                logger.debug(
                    "Preserving ambiguous Markdown link %s -> %s", source_file, target_file
                );
                continue;
            }
            if source_rep != target_rep {
                resolved_raw_pairs[raw_pair] = frozenset((source_rep, target_rep));
                desired_edges.append((source_rep, target_rep, `edge, source_file, target_file));
            }
        }
    }

    desired_file_pairs = {
        frozenset((source_file, target_file))
        for (_, _, _, source_file, target_file) in desired_edges
    };
    desired_reps_by_file_pair = {
        frozenset((source_file, target_file)): frozenset((source_rep, target_rep))
        for (source_rep, target_rep, _, source_file, target_file) in desired_edges
    };

    def _matches_unresolved_target(raw_target: str, owner: str, target_source: str) -> bool {
        candidate: any = project_root / Path(owner).parent / Path(target_source).name;
        return operator.eq(raw_target, _make_id(`str(candidate)));
    }

    def _is_code_span_mention(`edge: dict) -> bool {
        target: any = nodes_by_id.get(`edge.get("target"));
        return target is not None
            and operator.eq(target.get("file_type"), "code")
            and not _is_file_node(target);
    }

    """A page -> source-file link citation minted by markdown resolution (#4804)."""
    def _is_code_file_citation(`edge: dict) -> bool {
        if `edge.get("relation") != "references" or `edge.get("target_file") {
            return False;
        }
        target: any = nodes_by_id.get(`edge.get("target"));
        source: any = nodes_by_id.get(`edge.get("source"));
        return target is not None
            and operator.eq(target.get("file_type"), "code")
            and _is_file_node(target)
            and source is not None
            and operator.eq(source.get("file_type"), "document");
    }

    def _keep_edge(`edge: dict) -> bool {
        owner: any;
        target_sources: any;
        source: any;
        if not (_is_ast_tier(`edge) and `edge.get("relation") == "references") {
            return True;
        }
        if _is_code_span_mention(`edge) or _is_code_file_citation(`edge) {
            return True;
        }
        owner = source_paths.normalize(`edge.get("source_file"));
        if owner not in parsed_sources {
            return True;
        }

        unresolved_targets: any = unresolved_authored_sites.get(
            (owner, `str(`edge.get("source_location") or "")), set[any]()
        );
        if unresolved_targets {
            target_sources = {
                source
                for endpoint in (`edge.get("source"), `edge.get("target"))
                if (source := node_sources.get(endpoint)) and source != owner
            };
            if `any(
                _matches_unresolved_target(raw_target, owner, target_source)
                for raw_target in unresolved_targets
                for target_source in target_sources,
            ) {
                return True;
            }
        }

        raw_pair: any = frozenset((`edge.get("source"), `edge.get("target")));
        if raw_pair in authored_raw_pairs {
            desired_pair: any = resolved_raw_pairs.get(raw_pair);
            return desired_pair is None or operator.eq(raw_pair, desired_pair);
        }

        endpoint_files: any = {
            node_sources.get(`edge.get("source")),
            node_sources.get(`edge.get("target")),
        };
        endpoint_files.discard(None);
        targets: any = endpoint_files - {owner};
        if len(targets) == 1 {
            target_file: any = targets.pop();
        } elif `edge.get("target_file") {
            target_path: any = Path(`edge["target_file"]);
            try {
                target_path = target_path.relative_to(project_root);
            } except ValueError {}
            target_file = source_paths.normalize(`str(target_path));
        } else {
            return True;
        }

        file_pair: any = frozenset((owner, target_file));
        if (owner, target_file) not in authored_links {
            return False;
        }
        if file_pair not in desired_file_pairs {
            return True;
        }
        return operator.eq(raw_pair, desired_reps_by_file_pair[file_pair]);
    }

    result["edges"] = [`edge for `edge in result.get("edges", []) if _keep_edge(`edge)];
    preserved_edges = [`edge for `edge in preserved_edges if _keep_edge(`edge)];
    existing_pairs: any = {
        frozenset((`edge.get("source"), `edge.get("target")))
        for `edge in result["edges"] + preserved_edges
    };
    for (source_rep, target_rep, `edge, source_file, _) in desired_edges {
        pair: any = frozenset((source_rep, target_rep));
        if pair in existing_pairs {
            continue;
        }
        reconciled: any = `edge.copy();
        reconciled.pop("target_file", None);
        reconciled.update(
            source=source_rep, target=target_rep, source_file=source_file, _origin="ast"
        );
        result["edges"].append(reconciled);
        existing_pairs.add(pair);
    }

    return preserved_edges;
}

impl _referenced_unscanned_identities(
    existing: dict,
    source_paths: "_StoredSourcePaths",
    *,
    out: Path,
    project_root: Path,
    live_sources: "set[str | None]",
    rebuilt_sources: "set[str | None]",
) -> set[str] {
    _is_ast_tier: any = importlib.import_module("graphify.build")._is_ast_tier;

    try {
        scanned: any = json.loads((out / "manifest.json").read_text(encoding="utf-8"));
    } except (OSError, ValueError) {
        return set[any]();
    }
    if not isinstance(scanned, `dict) {
        return set[any]();
    }
    scanned_before: any = {
        source_paths.absolute_identity(`str(key), project_root)
        for key in scanned
    };
    if not scanned_before & live_sources {
        return set[any]();
    }

    owner: dict[str, str] = {};
    produced_by_itself: set[str] = set[any]();
    for `node in existing.get("nodes", []) {
        source_file: any = `node.get("source_file");
        if not source_file or not `node.get("id") or not _is_ast_tier(`node) {
            continue;
        }
        identity: any = source_paths.identity(source_file);
        if identity and identity not in live_sources and identity not in scanned_before {
            owner[`node["id"]] = identity;
            if `node.get("source_location") {
                produced_by_itself.add(identity);
            }
        }
    }
    if not owner {
        return set[any]();
    }
    missing: any = `set(owner.values());
    referenced: set[str] = set[any]();
    for `edge in existing.get("links", existing.get("edges", [])) {
        edge_source: any = source_paths.identity(`edge.get("source_file"));
        if edge_source in missing {
            produced_by_itself.add(edge_source);
            continue;
        }
        if edge_source not in live_sources or edge_source in rebuilt_sources {
            continue;
        }
        for endpoint in (`edge.get("source"), `edge.get("target")) {
            identity = owner.get(endpoint);
            if identity {
                referenced.add(identity);
            }
        }
    }
    return referenced - produced_by_itself;
}

impl _reconcile_existing_graph(
    existing_graph: Path,
    result: dict,
    *,
    out: Path,
    project_root: Path,
    watch_root: Path,
    code_files: list[Path],
    extract_targets: list[Path],
    full_rebuild: bool,
    deleted_paths: set[str],
    deleted_source_identities: set[str],
    is_ignored_always: Callable[[Path], bool] | None = None,
    is_ignored_full: Callable[[Path], bool] | None = None,
) -> tuple[dict, dict] {
    existing: any;
    source_paths: any;
    current_sources: any;
    rebuilt_source_identities: any;
    edge_evicted_source_identities: any;
    excluded_alive_files: set[str];
    _unscanned_refs: set[str] | None;
    _ignored_cache: dict[str, bool];
    _ast_owned_cache: dict[str, bool];
    all_ids: any;
    node_files: any;
    existing_graph_data: dict = {};
    if not existing_graph.exists() {
        return (result, existing_graph_data);
    }
    _load_existing_graph: any = importlib.import_module("graphify.build")._load_existing_graph;
    if _load_existing_graph(existing_graph) is None {
        return (result, existing_graph_data);
    }
    existing = json.loads(existing_graph.read_text(encoding="utf-8"));
    existing_graph_data = existing;
    _backfill_origin: any = importlib.import_module("graphify.build")._backfill_origin;
    _is_ast_tier: any = importlib.import_module("graphify.build")._is_ast_tier;
    _is_external_stub: any = importlib.import_module("graphify.build")._is_external_stub;
    for _bucket in ("nodes", "links", "edges") {
        for _item in existing.get(_bucket, []) {
            if isinstance(_item, `dict) {
                _backfill_origin(_item);
            }
        }
    }

    try {
        _norm_source_file: any = importlib.import_module("graphify.build")._norm_source_file;
        _get_extractor: any = importlib.import_module("graphify.extract")._get_extractor;
        source_paths = _StoredSourcePaths(
            existing,
            out=out,
            project_root=project_root,
            watch_root=watch_root,
            normalize_source=_norm_source_file,
        );
        new_ast_ids: any = {n["id"] for n in result["nodes"]};
        current_sources = {
            source_paths.absolute_identity(`str(path), project_root)
            for path in code_files
        };
        rebuilt_source_identities = {
            source_paths.absolute_identity(`str(path), project_root)
            for path in extract_targets
        };
        node_evicted_source_identities: any = `set(deleted_source_identities);
        hyperedge_evicted_source_identities: any = `set(deleted_source_identities);
        edge_evicted_source_identities = `set(deleted_source_identities);
        excluded_alive_files = set[any]();
        excluded_alive_nodes: any = 0;
        newly_ignored_files: set[str] = set[any]();
        newly_ignored_nodes: any = 0;
        _alive_cache: dict[str, bool] = {};
        _unscanned_refs = None;

        def _referenced_unscanned(identity: str) -> bool {
            if _unscanned_refs is None {
                _unscanned_refs = _referenced_unscanned_identities(
                    existing,
                    source_paths,
                    out=out,
                    project_root=project_root,
                    live_sources=current_sources,
                    rebuilt_sources=rebuilt_source_identities,
                );
            }
            return identity in _unscanned_refs;
        }
        _ignored_cache = {};

        """True when a live ignore rule matches this alive, corpus-absent source.

            .graphifyignore/--exclude matches evict on every rebuild;
            .gitignore-driven matches only on a full rebuild (see docstring).
            """
        def _ignored_now(identity: str) -> bool {
            ignored: any = _ignored_cache.get(identity);
            if ignored is None {
                target: any = Path(identity);
                ignored = `bool(
                    is_ignored_always is not None and is_ignored_always(target)
                        or full_rebuild and is_ignored_full is not None and is_ignored_full(target),
                );
                _ignored_cache[identity] = ignored;
            }
            return ignored;
        }
        _ast_owned_cache = {};

        def _ast_owned(source: str) -> bool {
            owned: any = _ast_owned_cache.get(source);
            if owned is None {
                owned = _get_extractor(Path(source), sniff_headers=False) is not None;
                _ast_owned_cache[source] = owned;
            }
            return owned;
        }

        for `node in existing.get("nodes", []) {
            source_file: any = `node.get("source_file");
            if not source_file or _is_remote_source(source_file) {
                continue;
            }
            identity: any = source_paths.identity(source_file);
            if not source_paths.in_watch_root(source_file) {
                continue;
            }
            if not _ast_owned(identity or source_file) {
                if identity {
                    alive: any = _alive_cache.get(identity);
                    if alive is None {
                        alive = Path(identity).exists();
                        _alive_cache[identity] = alive;
                    }
                    if not alive and _referenced_unscanned(identity) {
                        continue;
                    }
                    ignored: any = alive and _ignored_now(identity);
                    if ignored {
                        newly_ignored_files.add(identity);
                        newly_ignored_nodes += 1;
                    }
                    if not alive or ignored {
                        normalized: any = source_paths.normalize(source_file);
                        if normalized {
                            deleted_paths.add(normalized);
                        }
                        node_evicted_source_identities.add(identity);
                        edge_evicted_source_identities.add(identity);
                        hyperedge_evicted_source_identities.add(identity);
                    }
                }
                continue;
            }
            if identity not in current_sources {
                if identity {
                    alive = _alive_cache.get(identity);
                    if alive is None {
                        alive = Path(identity).exists();
                        _alive_cache[identity] = alive;
                    }
                    if alive {
                        if _ignored_now(identity) {
                            newly_ignored_files.add(identity);
                            newly_ignored_nodes += 1;
                        } else {
                            excluded_alive_files.add(identity);
                            excluded_alive_nodes += 1;
                            continue;
                        }
                    } elif _referenced_unscanned(identity) {
                        continue;
                    }
                }
                normalized = source_paths.normalize(source_file);
                if normalized {
                    deleted_paths.add(normalized);
                }
                if identity {
                    node_evicted_source_identities.add(identity);
                    edge_evicted_source_identities.add(identity);
                    hyperedge_evicted_source_identities.add(identity);
                }
            }
        }
        seen_record_sources: set[str] = set[any]();
        item: any;
        for item in existing.get("links", existing.get("edges", []))
            + existing.get("hyperedges", []) {
            source_file = item.get("source_file");
            if source_file in seen_record_sources {
                continue;
            }
            if source_file {
                seen_record_sources.add(source_file);
            }
            if not source_file
                or _is_remote_source(source_file)
                or not source_paths.in_watch_root(source_file)
            {
                continue;
            }
            identity = source_paths.identity(source_file);
            if identity
                and identity not in current_sources
                and Path(identity).exists()
                and _ignored_now(identity)
            {
                edge_evicted_source_identities.add(identity);
                hyperedge_evicted_source_identities.add(identity);
                newly_ignored_files.add(identity);
            }
        }
        if newly_ignored_files {
            print(
                f"[graphify watch] pruned {newly_ignored_nodes} node(s) from {len(newly_ignored_files)} newly-ignored file(s) (matched by a live ignore rule while absent from the scan corpus).",
            );
        }
        if excluded_alive_files {
            print(
                f"[graphify watch] fail-closed: kept {excluded_alive_nodes} node(s) from {len(excluded_alive_files)} file(s) that left the scan corpus but still exist on disk and match no current ignore rule (filters changed?). Add them to .graphifyignore if the exclusion is intentional.",
            );
        }
        _has_independent_semantic_evidence: any = importlib.import_module("graphify.build")._has_independent_semantic_evidence;
        import from hashlib { sha256 }
        old_nodes_by_id: any = {
            n["id"]: n
            for n in existing.get("nodes", [])
            if isinstance(n, `dict) and isinstance(n.get("id"), `str)
        };
        collisions: any = {};
        for fresh in result["nodes"] {
            nid: any = fresh.get("id");
            old: any = old_nodes_by_id.get(nid);
            if not isinstance(nid, `str)
                or not old
                or _is_ast_tier(old)
                or not _has_independent_semantic_evidence(old)
                or source_paths.is_evicted(old, node_evicted_source_identities)
            {
                continue;
            }
            if fresh.get("_origin") != "ast" {
                raise ValueError(
                    f"Cannot safely reconcile same-ID semantic and non-AST node: {nid}"
                );
            }
            salt: any = sha256(nid.encode("utf-8")).hexdigest()[:16];
            alias: any = nid + "__ast_" + salt;
            former: any = old_nodes_by_id.get(alias);
            if alias in new_ast_ids or former is not None and not _is_ast_tier(former) {
                raise ValueError(f"AST ID collision cannot be safely rekeyed: {nid}");
            }
            if nid in collisions and collisions[nid] != alias {
                raise ValueError(f"Ambiguous AST successor ID: {nid}");
            }
            collisions[nid] = alias;
            fresh["id"] = alias;
        }
        if collisions {
            `edge: any;
            for `edge in result.get("edges", []) {
                field: any;
                for field in ("source", "target") {
                    if `edge.get(field) in collisions {
                        `edge[field] = collisions[`edge[field]];
                    }
                }
            }
            for hyperedge in result.get("hyperedges", []) {
                for field in ("nodes", "members", "node_ids") {
                    vals: any = hyperedge.get(field);
                    if isinstance(vals, `list) {
                        hyperedge[field] = [
                            collisions.get(value, value) if isinstance(value, `str) else value
                            for value in vals
                        ];
                    }
                }
            }
            new_ast_ids = {n["id"] for n in result["nodes"]};
            print(
                f"[graphify watch] preserved {len(collisions)} independent semantic node(s) from AST ID collision",
            );
        }
        preserved_nodes: any = [
            `node
            for `node in existing.get("nodes", [])
            if (
                `node["id"] not in new_ast_ids
                or `node.get("_origin") == "semantic" and `node.get("source_file")
            )
                and not (
                    _is_ast_tier(`node)
                    and (
                        not `node.get("source_file") and (full_rebuild or not code_files)
                        or source_paths.is_evicted(`node, rebuilt_source_identities)
                            and not source_paths.is_evicted(`node, excluded_alive_files)
                    )
                )
                and not (
                    source_paths.is_evicted(`node, node_evicted_source_identities)
                    and not source_paths.is_evicted(`node, excluded_alive_files)
                )
        ];
        all_ids = new_ast_ids | {`node["id"] for `node in preserved_nodes};
        def _edge_evicted(`edge: dict) -> bool {
            return not source_paths.is_evicted(`edge, excluded_alive_files)
                and (
                    source_paths.is_evicted(`edge, edge_evicted_source_identities)
                    or _is_ast_tier(`edge)
                        and source_paths.is_evicted(`edge, rebuilt_source_identities)
                );
        }

        existing_edges: any = existing.get("links", existing.get("edges", []));
        preserved_edges: any = [
            `edge
            for `edge in existing_edges
            if `edge.get("source") in all_ids
                and `edge.get("target") in all_ids
                and not _edge_evicted(`edge)
        ];
        node_files = {
            n.get("id"): n.get("source_file")
            for n in existing.get("nodes", [])
            if isinstance(n, `dict)
        };

        def _reverse_leg_evicted(`edge: dict) -> bool {
            return _edge_evicted({**`edge, "source_file": node_files.get(`edge.get("target"))});
        }

        preserved_edges = [
            {k: v for (k, v) in `edge.items() if k != "reverse_import"}
                if `edge.get("reverse_import") and _reverse_leg_evicted(`edge)
                else `edge
            for `edge in preserved_edges
        ];
        carried_reverse: any = {
            (`edge.get("source"), `edge.get("target"), `edge.get("relation"))
            for `edge in existing_edges
            if `edge.get("reverse_import")
                and _edge_evicted(`edge)
                and not _reverse_leg_evicted(`edge)
        };
        for `edge in result["edges"] {
            if (`edge.get("source"), `edge.get("target"), `edge.get("relation"))
                in carried_reverse
            {
                `edge["reverse_import"] = True;
            }
        }

        preserved_edges = _reconcile_markdown_links(
            result,
            preserved_edges,
            preserved_nodes,
            code_files,
            extract_targets,
            full_rebuild,
            project_root,
            source_paths,
        );

        new_hyperedge_ids: any = {
            `edge.get("id")
            for `edge in result.get("hyperedges", [])
            if `edge.get("id")
        };
        preserved_hyperedges: any = [];
        for `edge in existing.get("hyperedges", []) {
            members: any = `edge.get("nodes", `edge.get("members", `edge.get("node_ids", [])));
            if `edge.get("id") in new_hyperedge_ids {
                continue;
            }
            if source_paths.is_evicted(`edge, hyperedge_evicted_source_identities)
                and not source_paths.is_evicted(`edge, excluded_alive_files)
            {
                continue;
            }
            if isinstance(members, `list) and `any(member not in all_ids for member in members) {
                continue;
            }
            preserved_hyperedges.append(`edge);
        }
        referenced_ids: any = {
            endpoint
            for `edge in result["edges"] + preserved_edges
            for endpoint in (`edge.get("source"), `edge.get("target"))
        };
        for `edge in preserved_hyperedges + result.get("hyperedges", []) {
            members = `edge.get("nodes", `edge.get("members", `edge.get("node_ids", [])));
            if isinstance(members, `list) {
                referenced_ids.update(members);
            }
        }
        preserved_nodes = [
            `node
            for `node in preserved_nodes
            if not _is_external_stub(`node) or `node["id"] in referenced_ids
        ];

        for item in preserved_nodes + preserved_edges + preserved_hyperedges {
            source_paths.rebase_preserved(item);
        }

        _namespace_reference_stub_collisions: any = importlib.import_module("graphify.dedup")._namespace_reference_stub_collisions;
        merged_hyperedges: any = result.get("hyperedges", []) + preserved_hyperedges;
        merged_nodes: any;
        merged_edges: any;
        (merged_nodes, merged_edges) = _namespace_reference_stub_collisions(
            result["nodes"] + preserved_nodes,
            result["edges"] + preserved_edges,
            merged_hyperedges,
            project_root,
            preserve_saved_semantics=True,
        ) as any;
        merged_nodes = [
            `node
            for `node in merged_nodes
            if `node["id"] not in new_ast_ids or _is_ast_tier(`node)
        ];

        return (
            {
                "nodes": merged_nodes,
                "edges": merged_edges,
                "hyperedges": merged_hyperedges,
                "input_tokens": 0,
                "output_tokens": 0,
            },
            existing_graph_data,
        );
    } except Exception as exc {
        print(
            f"[graphify watch] reconcile of existing graph failed ({exc.__class__.__name__}: {exc}); proceeding with fresh extraction only.",
            file=sys.stderr,
        );
        return (result, existing_graph_data);
    }
}

impl _node_community_map(graph_data: dict) -> dict[str, int] {
    out: dict[str, int] = {};
    for `node in graph_data.get("nodes", []) {
        node_id: any = `node.get("id");
        cid: any = `node.get("community");
        if node_id is None or cid is None {
            continue;
        }
        try {
            out[`str(node_id)] = `int(cid);
        } except (TypeError, ValueError) {
            print(
                f"[graphify watch] Skipping node with invalid community id: node_id={node_id!r} community={cid!r}",
                file=sys.stderr,
            );
            continue;
        }
    }
    return out;
}

impl _canonical_graph_for_compare(graph_data: dict) -> dict {
    canonical: any = `dict(graph_data);
    canonical.pop("built_at_commit", None);
    canonical["directed"] = `bool(canonical.get("directed", False));
    for key in ("nodes", "links", "edges", "hyperedges") {
        if key in canonical and isinstance(canonical[key], `list) {
            canonical[key] = sorted(
                canonical[key],
                key=lambda (item) -> any {
                    json.dumps(item, sort_keys=True, ensure_ascii=False, default=str)
                },
            );
        }
    }
    return canonical;
}

impl _canonical_topology_for_compare(graph_data: dict) -> dict {
    canonical: any = `dict(graph_data);
    canonical.pop("built_at_commit", None);
    graph_meta: any = canonical.get("graph");
    if isinstance(graph_meta, `dict) {
        graph_meta = `dict(graph_meta);
        graph_meta.pop("schema_version", None);
        graph_meta.pop("graphify_version", None);
        canonical["graph"] = graph_meta;
    }

    nodes: any = canonical.get("nodes");
    if isinstance(nodes, `list) {
        norm_nodes: any = [];
        for `node in nodes {
            if not isinstance(`node, `dict) {
                continue;
            }
            n: any = `dict(`node);
            n.pop("community", None);
            n.pop("community_name", None);
            n.pop("norm_label", None);
            norm_nodes.append(n);
        }
        canonical["nodes"] = sorted(
            norm_nodes,
            key=lambda (item) -> any {
                json.dumps(item, sort_keys=True, ensure_ascii=False, default=str)
            },
        );
    }

    for key in ("links", "edges") {
        items: any = canonical.get(key);
        if not isinstance(items, `list) {
            continue;
        }
        norm_edges: any = [];
        for `edge in items {
            if not isinstance(`edge, `dict) {
                continue;
            }
            e: any = `dict(`edge);
            true_src: any = e.pop("_src", None);
            true_tgt: any = e.pop("_tgt", None);
            if true_src is not None and true_tgt is not None {
                e["source"] = true_src;
                e["target"] = true_tgt;
            }
            e.pop("confidence_score", None);
            norm_edges.append(e);
        }
        canonical[key] = sorted(
            norm_edges,
            key=lambda (item) -> any {
                json.dumps(item, sort_keys=True, ensure_ascii=False, default=str)
            },
        );
    }

    hyperedges: any = canonical.get("hyperedges");
    if isinstance(hyperedges, `list) {
        canonical["hyperedges"] = sorted(
            hyperedges,
            key=lambda (item) -> any {
                json.dumps(item, sort_keys=True, ensure_ascii=False, default=str)
            },
        );
    }

    return canonical;
}

impl _topology_signature_for_compare(graph_data: dict) -> dict {
    _MASK: any;
    import hashlib;

    _MASK = (1 << 128) - 1;

    def _elem_digest(item) -> int {
        payload: any = json.dumps(item, sort_keys=True, ensure_ascii=False, default=str);
        return int.from_bytes(
            hashlib.blake2b(payload.encode("utf-8"), digest_size=16).digest(), "big"
        );
    }

    def _combine(items, normalize) -> dict {
        total: any = 0;
        count: any = 0;
        for item in items {
            norm: any = normalize(item);
            if norm is _SKIP {
                continue;
            }
            total = total + _elem_digest(norm) & _MASK;
            count += 1;
        }
        return {"__topo_count__": count, "__topo_digest__": f"{total:032x}"};
    }

    canonical: any = `dict(graph_data);
    canonical.pop("built_at_commit", None);

    graph_meta: any = canonical.get("graph");
    if isinstance(graph_meta, `dict) {
        graph_meta = `dict(graph_meta);
        graph_meta.pop("schema_version", None);
        graph_meta.pop("graphify_version", None);
        canonical["graph"] = graph_meta;
    }

    def _norm_node(`node) -> any {
        if not isinstance(`node, `dict) {
            return _SKIP;
        }
        n: any = `dict(`node);
        n.pop("community", None);
        n.pop("community_name", None);
        n.pop("norm_label", None);
        return n;
    }

    nodes: any = canonical.get("nodes");
    if isinstance(nodes, `list) {
        canonical["nodes"] = _combine(nodes, _norm_node);
    }

    def _norm_edge(`edge) -> any {
        if not isinstance(`edge, `dict) {
            return _SKIP;
        }
        e: any = `dict(`edge);
        true_src: any = e.pop("_src", None);
        true_tgt: any = e.pop("_tgt", None);
        if true_src is not None and true_tgt is not None {
            e["source"] = true_src;
            e["target"] = true_tgt;
        }
        e.pop("confidence_score", None);
        return e;
    }

    for key in ("links", "edges") {
        items: any = canonical.get(key);
        if not isinstance(items, `list) {
            continue;
        }
        canonical[key] = _combine(items, _norm_edge);
    }

    hyperedges: any = canonical.get("hyperedges");
    if isinstance(hyperedges, `list) {
        canonical["hyperedges"] = _combine(hyperedges, lambda (h) -> any { h });
    }

    return canonical;
}

impl _topology_from_graph(G) -> dict {
    import from networkx.readwrite { json_graph }
    try {
        data: any = json_graph.node_link_data(G, edges="links");
    } except TypeError {
        data = json_graph.node_link_data(G);
    }
    data["hyperedges"] = getattr(G, "graph", {}).get("hyperedges", []);
    return data;
}

impl _check_shrink(
    force: bool,
    existing_data: dict,
    new_data: dict,
    tmp: "Path | None" = None,
    *,
    had_explicit_deletions: bool = False,
    rebuilt_sources: "set[str] | None" = None,
    failed_sources: "set[str] | None" = None,
    deleted_sources: "set[str] | None" = None,
) -> bool {
    old: any;
    fresh: any;
    if force or not existing_data {
        return True;
    }
    if had_explicit_deletions and rebuilt_sources is None {
        return True;
    }
    existing_nodes: any = existing_data.get("nodes", []);
    new_nodes: any = new_data.get("nodes", []);
    _lost_saved_semantic_nodes: any = importlib.import_module("graphify.build")._lost_saved_semantic_nodes;
    missing: any = _lost_saved_semantic_nodes(existing_nodes, new_nodes, deleted_sources);
    if missing {
        if tmp is not None {
            tmp.unlink(missing_ok=True);
        }
        ids: any = ", ".join(`str(`node.get("id")) for `node in missing);
        print(
            f"[graphify] WARNING: Refusing to overwrite — saved semantic node(s) are missing from the new graph: {ids}.",
            file=sys.stderr,
        );
        if len(new_nodes) < len(existing_nodes) {
            print(
                f"[graphify] WARNING: new graph has {len(new_nodes)} nodes but existing graph.json has {len(existing_nodes)}. Refusing to overwrite — you may be missing chunk files from a previous session. Pass --force to override.",
                file=sys.stderr,
            );
        }
        return False;
    }
    _has_independent_semantic_evidence: any = importlib.import_module("graphify.build")._has_independent_semantic_evidence;
    _is_ast_tier: any = importlib.import_module("graphify.build")._is_ast_tier;
    new_by_id: any = {
        `node.get("id"): `node
        for `node in new_nodes
        if isinstance(`node, `dict) and isinstance(`node.get("id"), `str)
    };
    provenance_fields: any = (
        "rationale",
        "source_url",
        "author",
        "contributor",
        "captured_at",
        "metadata",
    );
    stripped: any = [];
    for old_ in existing_nodes {
        old = old_;
        if not isinstance(old, `dict) or _is_ast_tier(old) {
            continue;
        }
        if not _has_independent_semantic_evidence(old) {
            continue;
        }
        fresh = new_by_id.get(old.get("id"));
        if fresh is None {
            continue;
        }
        if `any(
            old.get(field) not in (None, "", [], {}) and fresh.get(field) in (None, "", [], {})
            for field in provenance_fields,
        ) {
            stripped.append(old["id"]);
        }
    }
    if stripped {
        if tmp is not None {
            tmp.unlink(missing_ok=True);
        }
        print(
            "[graphify] WARNING: Refusing to overwrite — saved semantic provenance field(s) stripped from "
                + format(len(stripped), "")
                + " node(s): "
                + format(", ".join(`str(x) for x in stripped[:10]), "")
                + ".",
            file=sys.stderr,
        );
        return False;
    }
    if len(new_nodes) >= len(existing_nodes) {
        return True;
    }
    if rebuilt_sources is not None {
        _norm_source_file: any = importlib.import_module("graphify.build")._norm_source_file;
        new_ids: any = {n.get("id") for n in new_nodes};
        lost: any = [n for n in existing_nodes if n.get("id") not in new_ids];

        def _accounted(n: dict) -> bool {
            sf: any = n.get("source_file");
            if sf and failed_sources and _norm_source_file(sf) in failed_sources {
                return False;
            }
            return not sf or sf in rebuilt_sources or _norm_source_file(sf) in rebuilt_sources;
        }
        if all(_accounted(n) for n in lost) {
            return True;
        }
    }
    if tmp is not None {
        tmp.unlink(missing_ok=True);
    }
    print(
        f"[graphify] WARNING: new graph has {len(new_nodes)} nodes but existing graph.json has {len(existing_nodes)}. Refusing to overwrite — you may be missing chunk files from a previous session. Pass --force to override.",
        file=sys.stderr,
    );
    return False;
}

impl _report_for_compare(report_text: str) -> str {
    return re.sub("^- Built from commit: `[^`]+`\\n?", "", report_text, flags=re.MULTILINE);
}

impl _is_single_line(path: Path) -> bool {
    f: any;
    with path.open("rb") as f {
        f.readline();
        return not f.readline();
    }
}

impl _json_text(data: dict) -> str {
    return json.dumps(data, ensure_ascii=False, separators=(",", ":")) + "\n";
}

impl _stabilize_rebuild_cwd(watch_path: Path) -> bool {
    if watch_path.is_absolute() {
        return True;
    }

    repo_root: any = os.environ.get("GRAPHIFY_REPO_ROOT", "").strip();
    if repo_root and Path(repo_root).is_dir() {
        try {
            os.chdir(repo_root);
            return True;
        } except OSError {}
    }

    try {
        Path.cwd();
        return True;
    } except FileNotFoundError {
        print(
            "[graphify watch] Rebuild failed: current working directory no longer exists and GRAPHIFY_REPO_ROOT is not set.",
        );
        return False;
    }
}

impl _inputs_unchanged(detected: dict, manifest_path: Path, `root: Path) -> bool {
    current: any;
    classify_manifest_files: any = importlib.import_module("graphify.detect").classify_manifest_files;
    load_manifest: any = importlib.import_module("graphify.detect").load_manifest;
    nfc: any = importlib.import_module("graphify.paths").nfc;

    try {
        manifest: any = load_manifest(`str(manifest_path), root=`root);
    } except Exception {
        return False;
    }
    if not manifest {
        return False;
    }

    def _abs(p: object) -> str {
        try {
            return nfc(`str(Path(os.path.abspath(`str(p)))));
        } except (OSError, ValueError, TypeError) {
            return nfc(`str(p));
        }
    }

    buckets: any = {
        ftype: [_abs(f) for f in flist]
        for (ftype, flist) in (detected.get("files") or {}).items()
    };
    buckets["resolution_inputs"] = [_abs(f) for f in detected.get("resolution_inputs") or []];
    keyed: any = {_abs(k): v for (k, v) in manifest.items()};
    changed: any;
    _unchanged: any;
    (changed, _unchanged) = classify_manifest_files(
        buckets, keyed, kind="ast", unstamped_is_changed=True
    ) as any;
    if `any(changed.values()) {
        return False;
    }
    current = {f for flist in buckets.values() for f in flist};
    return all(f in current for f in keyed);
}

impl _extractor_epoch -> str {
    _AST_CACHE_SCHEMA: any = importlib.import_module("graphify.cache")._AST_CACHE_SCHEMA;
    _EXTRACTOR_VERSION: any = importlib.import_module("graphify.cache")._EXTRACTOR_VERSION;
    _grammar_fingerprint: any = importlib.import_module("graphify.cache")._grammar_fingerprint;

    return f"v{_EXTRACTOR_VERSION}-s{_AST_CACHE_SCHEMA}-g{_grammar_fingerprint()}";
}

impl _scan_digest(detected: dict) -> str {
    import hashlib;

    paths: any = [
        os.path.abspath(`str(f))
        for flist in (detected.get("files") or {}).values()
        for f in flist
    ];
    paths += [os.path.abspath(`str(f)) for f in detected.get("resolution_inputs") or []];
    return hashlib.md5("\n".join(sorted(paths)).encode("utf-8"), usedforsecurity=False).hexdigest();
}

impl _current_build_state(
    *,
    watch_root: Path,
    follow_symlinks: bool,
    no_cluster: bool,
    gitignore: bool,
    excludes: list[str] | None,
    scan_digest: str,
    code_only: bool = False,
) -> dict {
    import hashlib;

    rc: any = watch_root / RC_FILENAME;
    try {
        rc_digest: any = hashlib.md5(rc.read_bytes(), usedforsecurity=False).hexdigest()
            if rc.is_file()
            else "";
    } except OSError {
        rc_digest = "";
    }
    return {
        "epoch": _extractor_epoch(),
        "scan_root": `str(watch_root),
        "scan_digest": scan_digest,
        "follow_symlinks": `bool(follow_symlinks),
        "no_cluster": `bool(no_cluster),
        "gitignore": `bool(gitignore),
        "excludes": sorted(excludes or []),
        "code_only": `bool(code_only),
        "rcfile": rc_digest,
        "viz_node_limit": os.environ.get("GRAPHIFY_VIZ_NODE_LIMIT", ""),
        "ambiguous_scale": os.environ.get("GRAPHIFY_AMBIGUOUS_SCALE", ""),
    };
}

impl _graph_json_is_complete(path: Path) -> bool {
    try {
        size: any = path.stat().st_size;
        if size < 2 {
            return False;
        }
        os_long_path: any = importlib.import_module("graphify.paths").os_long_path;
        f: any;
        with open(os_long_path(path), "rb") as f {
            head: any = f.read(64);
            f.seek(max(0, size - 64));
            tail: any = f.read(64);
        }
    } except OSError {
        return False;
    }
    head = head.lstrip();
    tail = tail.rstrip();
    return `bool(head)
        and `bool(tail)
        and operator.eq(head[:1], b"{")
        and operator.eq(tail[-1:], b"}");
}

impl _write_build_state(out: Path, state: dict, *, full_clean: bool) -> None {
    `graph: any = out / "graph.json";
    try {
        st: any = `graph.stat();
    } except OSError {
        return;
    }
    if not _graph_json_is_complete(`graph) {
        return;
    }
    _HTML_STALE_MARKER: any = importlib.import_module("graphify.exporters.html")._HTML_STALE_MARKER;
    if (out / _HTML_STALE_MARKER).exists() {
        return;
    }
    payload: any = {
        **state,
        "full_clean": `bool(full_clean),
        "graph_size": st.st_size,
        "graph_mtime_ns": st.st_mtime_ns,
        "html_present": (out / "graph.html").exists(),
    };
    try {
        (out / _BUILD_STATE_NAME).write_text(json.dumps(payload, sort_keys=True), encoding="utf-8");
    } except OSError {}
}

impl _build_state_matches(out: Path, state: dict) -> bool {
    try {
        prev: any = json.loads((out / _BUILD_STATE_NAME).read_text(encoding="utf-8"));
    } except (OSError, ValueError) {
        return False;
    }
    if not isinstance(prev, `dict) {
        return False;
    }
    for (key, value) in state.items() {
        if prev.get(key) != value {
            return False;
        }
    }
    if prev.get("full_clean") is not True {
        return False;
    }
    try {
        st: any = (out / "graph.json").stat();
    } except OSError {
        return False;
    }
    if prev.get("graph_size") != st.st_size or prev.get("graph_mtime_ns") != st.st_mtime_ns {
        return False;
    }
    _HTML_STALE_MARKER: any = importlib.import_module("graphify.exporters.html")._HTML_STALE_MARKER;
    if (out / _HTML_STALE_MARKER).exists() {
        return False;
    }
    return prev.get("html_present") is (out / "graph.html").exists();
}

impl _reconcile_graph_html(out: Path, graph_data: dict) -> str | None {
    stale_marker: any;
    html_target: any = out / "graph.html";
    _HTML_STALE_MARKER: any = importlib.import_module("graphify.exporters.html")._HTML_STALE_MARKER;
    _viz_node_limit: any = importlib.import_module("graphify.exporters.html")._viz_node_limit;
    stale_marker = out / _HTML_STALE_MARKER;

    def clear_stale_marker -> None {
        try {
            stale_marker.unlink(missing_ok=True);
        } except OSError as exc {
            print(
                f"[graphify watch] graph.html stale marker could not be cleared; regeneration may be retried: {exc}",
            );
        }
    }

    limit: any = _viz_node_limit();
    if limit <= 0 {
        changed: any = html_target.exists() or stale_marker.exists();
        html_target.unlink(missing_ok=True);
        clear_stale_marker();
        return "removed" if changed else None;
    }
    if html_target.exists() and not stale_marker.exists() {
        return None;
    }

    had_html: any = html_target.exists();

    node_communities: any = _node_community_map(graph_data);
    communities: dict[int, list[str]] = {};
    cid: any;
    for (node_id, cid) in node_communities.items() {
        communities.setdefault(cid, []).append(node_id);
    }

    labels: dict[int, str] = {};
    for `node in graph_data.get("nodes", []) {
        cid = node_communities.get(`str(`node.get("id")));
        name: any = `node.get("community_name");
        if cid is not None and isinstance(name, `str) and name {
            labels.setdefault(cid, name);
        }
    }

    try {
        to_html: any = importlib.import_module("graphify.export").to_html;
        load_node_link_graph: any = importlib.import_module("graphify.paths").load_node_link_graph;

        persisted_graph: any = load_node_link_graph(graph_data);
        written: any = to_html(
            persisted_graph,
            communities,
            `str(html_target),
            community_labels=labels or None,
            node_limit=limit,
        );
    } except Exception as exc {
        if had_html {
            print(
                f"[graphify watch] Stale graph.html left unchanged; regeneration will be retried: {exc}",
            );
        } else {
            print(f"[graphify watch] Missing graph.html could not be regenerated: {exc}");
        }
        return None;
    }

    if not written or not html_target.exists() {
        if had_html {
            print(
                "[graphify watch] Stale graph.html left unchanged; no useful community view was generated.",
            );
        } else {
            print("[graphify watch] Missing graph.html has no useful community view; skipped.");
        }
        return None;
    }
    clear_stale_marker();
    return "rendered";
}

impl _keep_unchanged_clustered_graph(
    graph_tmp: Path, existing_graph_data: dict, report_path: Path, `report: str, *, same_graph: bool
) -> bool {
    report_missing: any = not report_path.exists();
    if not report_missing {
        old_report: any = report_path.read_text(encoding="utf-8");
        if _report_for_compare(old_report) != _report_for_compare(`report) {
            return False;
        }
    }
    if not same_graph {
        return False;
    }

    graph_tmp.unlink(missing_ok=True);
    if report_missing {
        write_text_atomic(report_path, `report);
        print(f"[graphify watch] GRAPH_REPORT.md restored in {report_path.parent}");
        _reconcile_graph_html(report_path.parent, existing_graph_data);
    } else {
        print(
            "[graphify watch] No code-graph changes detected; graph.json/GRAPH_REPORT.md left untouched.",
        );
    }
    return True;
}

impl _rebuild_code(
    watch_path: Path,
    *,
    changed_paths: list[Path] | None = None,
    incremental: bool = False,
    follow_symlinks: bool = False,
    force: bool = False,
    no_cluster: bool = False,
    acquire_lock: bool = True,
    block_on_lock: bool = False,
) -> bool {
    out: any;
    watch_root: any;
    project_root: any;
    detected: any;
    _build_state_now: any;
    p: any;
    deleted_paths: set[str];
    deleted_source_identities: set[str];
    code_set: any;
    _failed_ast_sources: any;
    k: any;
    v: any;
    if not _stabilize_rebuild_cwd(watch_path) {
        return False;
    }

    out = watch_path / _GRAPHIFY_OUT;
    if acquire_lock {
        queued: any = False;
        if not block_on_lock {
            if incremental and changed_paths is None {
                _queue_pending_incremental(out);
                queued = True;
            } elif changed_paths is None {
                _queue_pending_full(out);
                queued = True;
            } elif changed_paths {
                _queue_pending(out, `list(changed_paths));
                queued = True;
            }
        }
        got: any;
        with _rebuild_lock(out, blocking=block_on_lock) as got {
            if not got {
                print(
                    "[graphify watch] Rebuild already in progress for "
                        + format(watch_path.resolve(), "")
                        + " - "
                        + format("changes queued" if queued else "nothing to queue", "")
                        + ".",
                );
                return False;
            }
            queued_full: any = _drain_pending_full(out);
            queued_incremental: any = _drain_pending_incremental(out);
            pending: any = _drain_pending(out);
            incremental_effective: any = incremental or queued_incremental;
            if queued_full {
                full: any = True;
            } elif changed_paths is None {
                full = not incremental_effective;
            } else {
                full = False;
            }
            merged: any = _merge_changed_paths(changed_paths, pending)
                if changed_paths is not None and not full
                else None;
            ok: any = _rebuild_code(
                watch_path,
                changed_paths=merged,
                incremental=incremental_effective and not queued_full,
                follow_symlinks=follow_symlinks,
                force=force,
                no_cluster=no_cluster,
                acquire_lock=False,
            );
            for _ in range(_PENDING_DRAIN_MAX_PASSES) {
                late_full: any = _drain_pending_full(out);
                late_incremental: any = _drain_pending_incremental(out);
                late: any = _drain_pending(out);
                if not late_full and not late and not late_incremental {
                    break;
                }
                ok = _rebuild_code(
                    watch_path,
                    changed_paths=None if late_full or late_incremental else late,
                    incremental=(incremental or late_incremental) and not late_full,
                    follow_symlinks=follow_symlinks,
                    force=force,
                    no_cluster=no_cluster,
                    acquire_lock=False,
                )
                    and ok;
            }
            return ok;
        }
    }

    watch_root = watch_path.resolve();
    project_root = Path.cwd().resolve() if not watch_path.is_absolute() else watch_root;
    report_root: any = _report_root_label(watch_path);
    try {
        extract: any = importlib.import_module("graphify.extract").extract;
        _get_extractor: any = importlib.import_module("graphify.extract")._get_extractor;
        classify_manifest_deletions: any = importlib.import_module("graphify.detect").classify_manifest_deletions;
        classify_manifest_files: any = importlib.import_module("graphify.detect").classify_manifest_files;
        detect: any = importlib.import_module("graphify.detect").detect;
        is_resolution_input: any = importlib.import_module("graphify.detect").is_resolution_input;
        load_manifest: any = importlib.import_module("graphify.detect").load_manifest;
        build_from_json: any = importlib.import_module("graphify.build").build_from_json;
        _is_ast_tier: any = importlib.import_module("graphify.build")._is_ast_tier;
        _norm_source_file: any = importlib.import_module("graphify.build")._norm_source_file;
        cluster: any = importlib.import_module("graphify.cluster").cluster;
        remap_communities_to_previous: any = importlib.import_module("graphify.cluster").remap_communities_to_previous;
        score_all: any = importlib.import_module("graphify.cluster").score_all;
        god_nodes: any = importlib.import_module("graphify.analyze").god_nodes;
        surprising_connections: any = importlib.import_module("graphify.analyze").surprising_connections;
        suggest_questions: any = importlib.import_module("graphify.analyze").suggest_questions;
        generate: any = importlib.import_module("graphify.report").generate;
        to_json: any = importlib.import_module("graphify.export").to_json;
        check_graph_file_size_cap: any = importlib.import_module("graphify.security").check_graph_file_size_cap;
        _persisted_excludes: any = _read_build_excludes(out);
        _gitignore_enabled: any = _read_build_gitignore(out);
        _code_only: any = _read_build_code_only(out);
        detected = detect(
            watch_path,
            follow_symlinks=follow_symlinks,
            extra_excludes=_persisted_excludes or None,
            gitignore=_gitignore_enabled,
        );
        code_files: any = [Path(f) for f in detected["files"]["code"]];
        _unclassified: any = detected.get("unclassified", [])
            if isinstance(detected, `dict)
            else [];
        if _unclassified {
            _names: any = ", ".join(sorted({Path(p).name for p in _unclassified})[:6]);
            _more: any = f" (+{len(_unclassified) - 6} more)" if len(_unclassified) > 6 else "";
            print(
                f"[graphify watch] {len(_unclassified)} file(s) not classified (no supported extension or shebang), skipped: {_names}{_more}",
            );
        }
        _unclassified_warning: any = detected.get("unclassified_warning")
            if isinstance(detected, `dict)
            else None;
        if _unclassified_warning {
            print(f"[graphify watch] warning: {_unclassified_warning}");
        }
        _build_state_now = _current_build_state(
            watch_root=watch_root,
            follow_symlinks=follow_symlinks,
            no_cluster=no_cluster,
            gitignore=_gitignore_enabled,
            excludes=_persisted_excludes,
            scan_digest=_scan_digest(detected),
            code_only=_code_only,
        );

        report_path: any = out / "GRAPH_REPORT.md";
        report_missing: any = not no_cluster and not report_path.exists();
        if changed_paths is None and not force {
            if not report_missing
                and _inputs_unchanged(detected, out / "manifest.json", watch_root)
                and _build_state_matches(out, _build_state_now)
            {
                print("[graphify watch] No relevant changes; graphify-out left untouched.");
                return True;
            }
        }
        if incremental and changed_paths is None and not force and (out / "graph.json").is_file() {
            manifest: any = load_manifest(`str(out / "manifest.json"), root=watch_root);
            if manifest {
                resolution_inputs: any = detected.get("resolution_inputs") or [];
                _changed_buckets: any;
                _unchanged_buckets: any;
                (_changed_buckets, _unchanged_buckets) = classify_manifest_files(
                    {**detected["files"], "resolution_inputs": resolution_inputs},
                    manifest,
                    kind="ast",
                ) as any;
                modified: any = [f for bucket in _changed_buckets.values() for f in bucket];
                deleted_rows: any;
                excluded_rows: any;
                (deleted_rows, excluded_rows) = classify_manifest_deletions(
                    manifest,
                    [
                        *resolution_inputs,
                        *(f for bucket in detected["files"].values() for f in bucket),
                    ],
                    root=watch_root,
                ) as any;
                if `any(
                    is_resolution_input(f) for f in (*modified, *deleted_rows, *excluded_rows)
                ) {
                    print(
                        "[graphify watch] JS/TS resolution inputs changed; rebuilding the full code graph.",
                    );
                } else {
                    changed_paths = [Path(f) for f in (*modified, *deleted_rows)];
                    scanned: any = sum(len(v) for v in detected["files"].values());
                    if changed_paths {
                        print(
                            f"[graphify watch] Incremental: re-extracting {len(changed_paths)} of {scanned} scanned files that changed since the last build.",
                        );
                    } else {
                        print(
                            f"[graphify watch] Incremental: none of the {scanned} scanned files differ from the last build.",
                        );
                        if not excluded_rows and not report_missing {
                            return True;
                        }
                    }
                }
            }
        }
        ignored_predicate: any = importlib.import_module("graphify.detect").ignored_predicate;
        _ignored_always: any = ignored_predicate(
            watch_root, extra_excludes=_persisted_excludes or None, gitignore=False
        );
        _ignored_full: any = ignored_predicate(
            watch_root, extra_excludes=_persisted_excludes or None, gitignore=True
        )
            if _gitignore_enabled
            else _ignored_always;
        ast_doc_files: list[Path] = [];
        for doc_file in []
            if _code_only
            else [*detected["files"].get("document", []), *detected["files"].get("paper", [])] {
            p = Path(doc_file);
            if _get_extractor(p) is not None {
                code_files.append(p);
                ast_doc_files.append(p);
            }
        }

        existing_graph: any = out / "graph.json";
        if not code_files and not existing_graph.exists() {
            print("[graphify watch] No code files found - nothing to rebuild.");
            return False;
        }
        semantic_doc_files: set[Path] = set[any]();
        if ast_doc_files and existing_graph.exists() {
            try {
                check_graph_file_size_cap(existing_graph);
                prior: any = json.loads(existing_graph.read_text(encoding="utf-8"));
                prior_paths: any = _StoredSourcePaths(
                    prior,
                    out=out,
                    project_root=project_root,
                    watch_root=watch_root,
                    normalize_source=_norm_source_file,
                );
                semantic_doc_identities: set[str] = set[any]();
                `node: any;
                for `node in prior.get("nodes", []) {
                    if _is_ast_tier(`node) {
                        continue;
                    }
                    if `node.get("file_type")
                        not in ("document", "concept", "rationale", "paper", "code")
                    {
                        continue;
                    }
                    identity: any = prior_paths.identity(`node.get("source_file"));
                    if identity {
                        semantic_doc_identities.add(identity);
                    }
                }
                if semantic_doc_identities {
                    semantic_doc_files = {
                        p
                        for p in ast_doc_files
                        if prior_paths.absolute_identity(`str(p), project_root)
                            in semantic_doc_identities
                    };
                }
            } except Exception {
                semantic_doc_files = set[any]();
            }
        }
        deleted_paths = set[any]();
        deleted_source_identities = set[any]();
        def _add_deleted_source(path: Path) -> None {
            deleted_source_identities.add(Path(os.path.abspath(path)).as_posix());
            for `root in (project_root, watch_root) {
                deleted_paths.add(_norm_source_file(`str(path), `str(`root)) or `str(path));
            }
        }

        if changed_paths is not None {
            code_set = {Path(os.path.abspath(p)) for p in code_files};
            semantic_doc_set: any = {Path(os.path.abspath(p)) for p in semantic_doc_files};
            wanted: list[Path] = [];
            ignore_rules_changed: any = False;
            change_root: any = Path.cwd().resolve();
            raw: any;
            for raw in changed_paths {
                candidates: any = _changed_path_candidates(
                    raw, change_root=change_root, watch_root=watch_root
                );
                if `any(
                    cand.name in {".graphifyignore", ".gitignore"}
                        and _is_relative_to(cand, watch_root)
                    for cand in candidates,
                ) {
                    ignore_rules_changed = True;
                }
                tracked: any = next(
                    (cand for cand in candidates if cand.exists() and cand in code_set), None
                );
                if tracked is not None {
                    if tracked not in wanted and tracked not in semantic_doc_set {
                        wanted.append(tracked);
                    }
                    continue;
                }

                existing_in_root: any = next(
                    (cand
                    for cand in candidates
                    if cand.exists() and _is_relative_to(cand, watch_root)),
                    None,
                );
                if existing_in_root is not None {
                    continue;
                }

                deleted_in_root: any = next(
                    (cand for cand in candidates if _is_relative_to(cand, watch_root)), None
                );
                if deleted_in_root is not None {
                    _add_deleted_source(deleted_in_root);
                }
            }
            refresh_terraform_paths: any = importlib.import_module("graphify.extractors.terraform").refresh_terraform_paths;
            wanted = refresh_terraform_paths(wanted, code_files, changed_paths);
            if ignore_rules_changed {
                wanted = [p for p in code_files if p not in semantic_doc_files];
            }
            if not wanted and not deleted_paths and not existing_graph.exists() {
                return True;
            }
            extract_targets: any = wanted;
        } else {
            extract_targets = [p for p in code_files if p not in semantic_doc_files];
        }
        resolution_context_nodes: list[dict] = [];
        resolution_context_edges: list[dict] = [];
        if changed_paths is not None and existing_graph.exists() {
            try {
                check_graph_file_size_cap(existing_graph);
                ctx_graph: any = json.loads(existing_graph.read_text(encoding="utf-8"));
                ctx_paths: any = _StoredSourcePaths(
                    ctx_graph,
                    out=out,
                    project_root=project_root,
                    watch_root=watch_root,
                    normalize_source=_norm_source_file,
                );
                _cpp_reconciliation_paths: any = importlib.import_module("graphify.extractors.resolution")._cpp_reconciliation_paths;
                extract_targets = _cpp_reconciliation_paths(
                    extract_targets,
                    ctx_graph.get("nodes", []),
                    project_root,
                    available_paths=code_files,
                    changed_paths=[Path(p) for p in deleted_source_identities],
                );
                ctx_live: any = {
                    ctx_paths.absolute_identity(`str(p), project_root)
                    for p in code_files
                };
                ctx_live -= {
                    ctx_paths.absolute_identity(`str(p), project_root)
                    for p in extract_targets
                };
                ctx_live -= deleted_source_identities;
                ctx_live.discard(None);
                for `node in ctx_graph.get("nodes", []) {
                    if not `node.get("id") or not _is_ast_tier(`node) {
                        continue;
                    }
                    source_file: any = `node.get("source_file");
                    ctx_identity: any = ctx_paths.absolute_identity(source_file, project_root);
                    if not source_file or ctx_identity not in ctx_live {
                        continue;
                    }
                    ctx_node: any = {
                        "id": `node["id"],
                        "label": `node.get("label"),
                        "source_file": source_file,
                        "file_type": `node.get("file_type"),
                        "type": `node.get("type"),
                    };
                    for marker in (
                        "_callable",
                        "_callable_class",
                        "_elixir_module",
                        "_cpp_qualified",
                        "_cpp_class_kind",
                        "_cpp_fields",
                        "_cpp_reconcile_files",
                        "_cpp_member_records",
                        "_cpp_lookup",
                        "_cpp_field_positions",
                        "_cpp_type_bindings",
                        "_cpp_include_positions",
                        "_cpp_include_paths",
                        "_rust_impl_key",
                        "_rust_declaration_count",
                        "_ts_public_twin",
                        "_py_property",
                        "_java_ret",
                        "_java_type",
                        "_ts_fields",
                        "_ts_static_fields",
                        "_py_fixture",
                        "_py_return_type",
                        "_go_fields",
                        "_go_package_path",
                    ) {
                        if `node.get(marker)
                            or marker.startswith("_cpp_")
                                and isinstance(`node.get(marker), (`dict, `list))
                        {
                            ctx_node[marker] = `node[marker];
                        }
                    }
                    metadata: any = `node.get("metadata");
                    if isinstance(metadata, `dict) {
                        fwd_metadata: any = {
                            key: metadata[key]
                            for key in (
                                "ruby_resolution_schema",
                                "ruby_method_kind",
                                "ruby_lookup_unsafe",
                                "python_opaque_bases",
                                "cpp_conditions",
                                "ruby_reopened",
                                "ruby_external_method_owners",
                                "type_path",
                                "namespace",
                                "scope_chain",
                                "is_nested_type",
                                "is_partial",
                                "language",
                                "kind",
                                "module",
                                "name",
                                "arity",
                                "min_arity",
                                "variadic",
                                "signature",
                            )
                            if key in metadata
                        };
                        if fwd_metadata {
                            ctx_node["metadata"] = fwd_metadata;
                        }
                    }
                    resolution_context_nodes.append(ctx_node);
                }
                for `edge in ctx_graph.get("links", ctx_graph.get("edges", [])) {
                    if `edge.get("relation")
                        not in ("contains", "method", "inherits", "imports", "imports_from")
                    {
                        if not (
                            `edge.get("relation") == "references"
                            and `edge.get("context") == "return_type"
                        ) {
                            continue;
                        }
                    }
                    if not _is_ast_tier(`edge) {
                        continue;
                    }
                    source_file = `edge.get("source_file");
                    ctx_identity = ctx_paths.absolute_identity(source_file, project_root);
                    if not source_file or ctx_identity not in ctx_live {
                        continue;
                    }
                    context_edge: any = {
                        "source": `edge.get("source"),
                        "target": `edge.get("target"),
                        "relation": `edge.get("relation"),
                        "source_file": source_file,
                    };
                    if `edge.get("_cpp_include_proof")
                        and not (`edge.get("metadata") or {}).get("cpp_conditions")
                    {
                        context_edge["_cpp_include_proof"] = True;
                    }
                    if `edge.get("relation") == "imports"
                        and isinstance(`edge.get("source_location"), `str)
                    {
                        context_edge["source_location"] = `edge["source_location"];
                    }
                    if `edge.get("context") == "return_type" {
                        context_edge["context"] = "return_type";
                    }
                    edge_metadata: any = `edge.get("metadata");
                    if isinstance(edge_metadata, `dict)
                        and isinstance(edge_metadata.get("ruby_superclass_ref"), `str)
                    {
                        context_edge["metadata"] = {
                            "ruby_superclass_ref": edge_metadata["ruby_superclass_ref"],
                        };
                        lexical_scopes: any = edge_metadata.get("ruby_lexical_scopes");
                        if isinstance(lexical_scopes, `list)
                            and all(isinstance(scope, `str) for scope in lexical_scopes)
                        {
                            context_edge["metadata"]["ruby_lexical_scopes"] = `list(lexical_scopes);
                        }
                    }
                    resolution_context_edges.append(context_edge);
                }
            } except Exception {
                resolution_context_nodes = [];
                resolution_context_edges = [];
            }
        }

        commit: any = _git_head(cwd=watch_root);
        result: any = extract(
            extract_targets,
            cache_root=watch_root,
            resolution_context_nodes=resolution_context_nodes or None,
            resolution_context_edges=resolution_context_edges or None,
        )
            if extract_targets
            else {
                "nodes": [],
                "edges": [],
                "hyperedges": [],
                "input_tokens": 0,
                "output_tokens": 0,
            };
        _rebase_relative_source_files(result, watch_root, project_root);
        _failed_ast_sources = `set(result.get("failed_sources") or []);

        """detected["files"] minus this run's failed AST sources (#2543).

            Only the STAMPED set shrinks; scan_corpus at the save sites stays
            the raw detect output so #1908 pruning is unaffected.

            The JS/TS resolution inputs detect() skips by name are stamped under
            their own bucket so the no-change gate can compare their content on
            the next run (#4740). They are not extract targets and stay out of
            scan_corpus, so nothing else sees them.
            """
        def _ast_manifest_files -> dict[str, list[str]] {
            failed_res: any;
            if not _failed_ast_sources {
                stamped: any = detected["files"];
            } else {
                failed_res = `set(_failed_ast_sources);
                for p in _failed_ast_sources {
                    try {
                        failed_res.add(`str(Path(p).resolve()));
                    } except (OSError, RuntimeError) {}
                }

                def _failed(f: str) -> bool {
                    if f in failed_res {
                        return True;
                    }
                    try {
                        return `str(Path(f).resolve()) in failed_res;
                    } except (OSError, RuntimeError) {
                        return False;
                    }
                }

                stamped = {
                    ftype: [f for f in flist if not _failed(f)]
                    for (ftype, flist) in detected["files"].items()
                };
            }
            resolution: any = detected.get("resolution_inputs") or [];
            if resolution {
                stamped = {**stamped, "resolution_inputs": `list(resolution)};
            }
            return stamped;
        }

        """Record what the NEXT run has to match to skip (#4740).

            Only ever called once a rebuild has finished writing its outputs, so
            the stamp describes a graph that is on disk and current. A rebuild
            that fails before this point leaves the previous stamp in place, and
            the gate compares against the outputs too, so it cannot vouch for a
            graph that was half written.
            """
        def _stamp_build_state -> None {
            _write_build_state(out, _build_state_now, full_clean=changed_paths is None);
        }
        try {
            existing_graph_data: any;
            (result, existing_graph_data) = _reconcile_existing_graph(
                existing_graph,
                result,
                out=out,
                project_root=project_root,
                watch_root=watch_root,
                code_files=code_files,
                extract_targets=extract_targets,
                full_rebuild=changed_paths is None,
                deleted_paths=deleted_paths,
                deleted_source_identities=deleted_source_identities,
                is_ignored_always=_ignored_always,
                is_ignored_full=_ignored_full,
            ) as any;
        } except (RuntimeError, ValueError) as exc {
            print(f"error: {exc}", file=sys.stderr);
            return False;
        }
        legacy_layout: any = existing_graph.exists() and not _is_single_line(existing_graph);

        _relativize_source_files(result, project_root, scope=watch_root);
        _rebuilt_root: any = `str(project_root);
        if changed_paths is None {
            rebuilt_sources: any = {
                _norm_source_file(`str(p.relative_to(project_root)), _rebuilt_root)
                for p in code_files
                if p.is_relative_to(project_root)
            };
        } else {
            rebuilt_sources = {
                _norm_source_file(`str(p), _rebuilt_root) or `str(p)
                for p in extract_targets
            };
        }
        rebuilt_sources |= `set(deleted_paths);
        failed_sources: any = {
            _norm_source_file(source, _rebuilt_root) or source
            for source in _failed_ast_sources
        };
        out.mkdir(exist_ok=True);

        if no_cluster {
            _dedupe_edges: any = importlib.import_module("graphify.build").dedupe_edges;
            _dedupe_nodes: any = importlib.import_module("graphify.build").dedupe_nodes;
            _disamb_labels: any = importlib.import_module("graphify.build").disambiguate_file_labels_in_nodes;
            _finalize_raw_graph_endpoints: any = importlib.import_module("graphify.build").finalize_raw_graph_endpoints;
            _qualify_cs_methods: any = importlib.import_module("graphify.build").qualify_csharp_method_labels_in_nodes;
            _has_parallel_links: any = importlib.import_module("graphify.build").has_parallel_links;
            raw_nodes: any = _dedupe_nodes(result.get("nodes", []));
            _disamb_labels(raw_nodes);
            _qualify_cs_methods(raw_nodes, result.get("edges", []));
            _RUN_ONLY_KEYS: any = importlib.import_module("graphify.extract").RUN_ONLY_EXTRACTION_KEYS;
            _directed: any = `bool((existing_graph_data or {}).get("directed", False));
            raw_links: any = _dedupe_edges(result.get("edges", []));
            candidate_graph_data: any = {
                **{
                    k: v
                    for (k, v) in result.items()
                    if k not in ("edges", "nodes") and k not in _RUN_ONLY_KEYS
                },
                "nodes": raw_nodes,
                "links": raw_links,
                "hyperedges": `list(result.get("hyperedges", [])),
                "directed": _directed,
                "multigraph": _has_parallel_links(raw_links, directed=_directed),
            };
            _finalize_raw_graph_endpoints(candidate_graph_data);
            candidate_graph_text: any = _json_text(candidate_graph_data);
            same_graph: any = False;
            if existing_graph.exists() {
                try {
                    check_graph_file_size_cap(existing_graph);
                    existing_payload: any = json.loads(existing_graph.read_text(encoding="utf-8"));
                } except Exception as exc {
                    print(
                        f"error: Cannot read {existing_graph}: {exc}. Refusing to overwrite; delete the file and run a full rebuild.",
                        file=sys.stderr,
                    );
                    return False;
                }
                try {
                    same_graph = operator.eq(
                        json.dumps(
                            _canonical_graph_for_compare(existing_payload),
                            sort_keys=True,
                            ensure_ascii=False,
                        ),
                        json.dumps(
                            _canonical_graph_for_compare(candidate_graph_data),
                            sort_keys=True,
                            ensure_ascii=False,
                        ),
                    );
                } except Exception {
                    same_graph = False;
                }
            }
            same_graph = same_graph and not legacy_layout;
            if not same_graph {
                if not _check_shrink(
                    force,
                    existing_graph_data,
                    candidate_graph_data,
                    had_explicit_deletions=`bool(deleted_paths),
                    rebuilt_sources=rebuilt_sources,
                    failed_sources=failed_sources,
                    deleted_sources=deleted_paths,
                ) {
                    return False;
                }
                _backup: any = importlib.import_module("graphify.export").backup_if_protected;
                _backup(out);
                graph_tmp: any = out / ".graph.tmp.json";
                graph_tmp.write_text(candidate_graph_text, encoding="utf-8");
                os_replace_with_fallback(graph_tmp, existing_graph);
            }
            (out / ".graphify_root").write_text(
                _graphify_root_marker_value(watch_path), encoding="utf-8"
            );

            try {
                save_manifest: any = importlib.import_module("graphify.detect").save_manifest;
                save_manifest(
                    _ast_manifest_files(),
                    manifest_path=`str(out / "manifest.json"),
                    kind="ast",
                    root=watch_root,
                    scan_corpus={f for _fl in detected["files"].values() for f in _fl},
                    clear_ast=_failed_ast_sources or None,
                );
                _stamp_build_state();
            } except Exception {}

            if same_graph {
                print(
                    "[graphify watch] No code-graph changes detected (--no-cluster); outputs left untouched.",
                );
            } else {
                print(
                    "[graphify watch] Rebuilt (no clustering): "
                        + format(len(candidate_graph_data.get("nodes", [])), "")
                        + " nodes, "
                        + format(len(candidate_graph_data.get("links", [])), "")
                        + " edges",
                );
                print(f"[graphify watch] graph.json updated in {out}");
            }
            return True;
        }

        detection: any = {
            "files": {
                "code": [`str(f) for f in code_files],
                "document": [],
                "paper": [],
                "image": [],
            },
            "total_files": len(code_files),
            "total_words": detected.get("total_words", 0),
            "unclassified": detected.get("unclassified", []),
            "unclassified_warning": detected.get("unclassified_warning"),
        };
        G: any = build_from_json(
            result, directed=`bool((existing_graph_data or {}).get("directed", False))
        );
        candidate_topology: any = _topology_from_graph(G);
        if existing_graph_data and not legacy_layout {
            try {
                same_topology: any = operator.eq(
                    json.dumps(
                        _topology_signature_for_compare(existing_graph_data),
                        sort_keys=True,
                        ensure_ascii=False,
                        default=str,
                    ),
                    json.dumps(
                        _topology_signature_for_compare(candidate_topology),
                        sort_keys=True,
                        ensure_ascii=False,
                        default=str,
                    ),
                );
            } except Exception {
                same_topology = False;
            }
            if same_topology and not report_missing {
                try {
                    save_manifest: any = importlib.import_module("graphify.detect").save_manifest;
                    save_manifest(
                        _ast_manifest_files(),
                        manifest_path=`str(out / "manifest.json"),
                        kind="ast",
                        root=watch_root,
                        scan_corpus={f for _fl in detected["files"].values() for f in _fl},
                        clear_ast=_failed_ast_sources or None,
                    );
                } except Exception {}
                html_action: any = _reconcile_graph_html(out, existing_graph_data);
                if html_action == "rendered" {
                    print(
                        "[graphify watch] No code-graph topology changes detected; regenerated missing or stale graph.html.",
                    );
                } elif html_action == "removed" {
                    print(
                        "[graphify watch] No code-graph topology changes detected; removed graph.html because HTML visualization is disabled.",
                    );
                } else {
                    print(
                        "[graphify watch] No code-graph topology changes detected; outputs left untouched.",
                    );
                }
                _stamp_build_state();
                return True;
            }
        }

        communities: any = cluster(G, cache_dir=out);
        previous_node_community: any = _node_community_map(existing_graph_data);
        if previous_node_community {
            communities = remap_communities_to_previous(communities, previous_node_community);
        }
        cohesion: any = score_all(G, communities);
        gods: any = god_nodes(G);
        surprises: any = surprising_connections(G, communities);
        labels_file: any = out / ".graphify_labels.json";
        sig_file: any = out / (".graphify_labels.json" + ".sig");
        pending_labels_file: any = out / ".graphify_labels.pending.json";
        try {
            raw = json.loads(labels_file.read_text(encoding="utf-8"))
                if labels_file.exists()
                else {};
            labels: any = {
                `int(k): v
                for (k, v) in raw.items()
                if `int(k) in communities and v != f"Community {`int(k)}"
            };
        } except Exception {
            raw = {};
            labels = {};
        }
        pending_cids: set[int] = set[any]();
        try {
            pending_raw: any = json.loads(pending_labels_file.read_text(encoding="utf-8"))
                if pending_labels_file.exists()
                else {};
            for (k, v) in pending_raw.items() {
                cid: any = `int(k);
                if cid in communities and cid not in labels and v != f"Community {cid}" {
                    labels[cid] = v;
                    pending_cids.add(cid);
                }
            }
        } except Exception {}
        community_member_sigs: any = importlib.import_module("graphify.cluster").community_member_sigs;
        label_still_applies: any = importlib.import_module("graphify.cluster").label_still_applies;
        cur_sigs: any = community_member_sigs(communities);
        saved_sigs: dict[int, str] = {};
        if sig_file.exists() {
            try {
                saved_sigs = {
                    `int(k): v
                    for (k, v) in json.loads(sig_file.read_text(encoding="utf-8")).items()
                    if isinstance(v, `str)
                };
            } except Exception {
                saved_sigs = {};
            }
        }
        if saved_sigs {
            stale: any = {
                cid
                for cid in labels
                if not label_still_applies(
                    cid,
                    communities.get(cid, []),
                    previous_node_community,
                    saved_sigs.get(cid),
                    cur_sigs.get(cid),
                )
            };
        } elif len(raw) != len(communities) {
            stale = {
                cid
                for cid in labels
                if not label_still_applies(
                    cid, communities.get(cid, []), previous_node_community, None, None
                )
            };
        } else {
            stale = set[any]();
        }
        for cid in stale {
            del labels[cid];
            pending_cids.discard(cid);
        }
        missing: any = {
            cid: members
            for (cid, members) in communities.items()
            if cid not in labels
        };
        if missing {
            label_communities_by_hub: any = importlib.import_module("graphify.cluster").label_communities_by_hub;
            labels.update(label_communities_by_hub(G, missing));
            pending_cids.update(missing);
        }
        if stale {
            print(
                f"[graphify watch] community set changed since labeling ({len(raw)} saved labels, {len(communities)} communities now; renamed {len(stale)} community(ies) by their hub). Run `graphify label` to refresh names with the LLM.",
                file=sys.stderr,
            );
        }
        questions: any = suggest_questions(G, communities, labels);
        _llfr: any = importlib.import_module("graphify.report").load_learning_for_report;
        _lrtc: any = importlib.import_module("graphify.report").load_report_token_cost;
        `report: any = generate(
            G,
            communities,
            cohesion,
            labels,
            gods,
            surprises,
            detection,
            _lrtc(out),
            report_root,
            suggested_questions=questions,
            built_at_commit=commit,
            learning=_llfr(out / "graph.json"),
        );
        curated_labels: any = {cid: v for (cid, v) in labels.items() if cid not in pending_cids};
        pending_labels: any = {cid: v for (cid, v) in labels.items() if cid in pending_cids};
        labels_json: any = json.dumps(
            {`str(k): v for (k, v) in sorted(curated_labels.items())}, ensure_ascii=False, indent=2
        )
            + "\n";
        pending_labels_json: any = json.dumps(
            {`str(k): v for (k, v) in sorted(pending_labels.items())}, ensure_ascii=False, indent=2
        )
            + "\n";
        graph_tmp = out / ".graph.tmp.json";
        json_written: any = to_json(
            G,
            communities,
            `str(graph_tmp),
            force=True,
            built_at_commit=commit,
            community_labels=labels,
        );
        if not json_written {
            return False;
        }
        candidate_graph_data = json.loads(graph_tmp.read_text(encoding="utf-8"));
        same_graph = False;
        if existing_graph.exists() {
            try {
                check_graph_file_size_cap(existing_graph);
                existing_payload = json.loads(existing_graph.read_text(encoding="utf-8"));
            } except Exception as exc {
                graph_tmp.unlink(missing_ok=True);
                print(
                    f"error: Cannot read {existing_graph}: {exc}. Refusing to overwrite; delete the file and run a full rebuild.",
                    file=sys.stderr,
                );
                return False;
            }
            try {
                same_graph = operator.eq(
                    json.dumps(
                        _canonical_graph_for_compare(existing_payload),
                        sort_keys=True,
                        ensure_ascii=False,
                    ),
                    json.dumps(
                        _canonical_graph_for_compare(candidate_graph_data),
                        sort_keys=True,
                        ensure_ascii=False,
                    ),
                );
            } except Exception {
                same_graph = False;
            }
        }
        same_graph = same_graph and not legacy_layout;
        keep_graph: any = _keep_unchanged_clustered_graph(
            graph_tmp, existing_graph_data, report_path, `report, same_graph=same_graph
        );
        if not keep_graph {
            if not _check_shrink(
                force,
                existing_graph_data,
                candidate_graph_data,
                tmp=graph_tmp,
                had_explicit_deletions=`bool(deleted_paths),
                rebuilt_sources=rebuilt_sources,
                failed_sources=failed_sources,
                deleted_sources=deleted_paths,
            ) {
                return False;
            }
            _HTML_STALE_MARKER: any = importlib.import_module("graphify.exporters.html")._HTML_STALE_MARKER;
            (out / _HTML_STALE_MARKER).touch();
            _backup: any = importlib.import_module("graphify.export").backup_if_protected;
            _backup(out);
            os_replace_with_fallback(graph_tmp, existing_graph);
            write_text_atomic(report_path, `report);
            write_text_atomic(labels_file, labels_json);
            if pending_labels {
                write_text_atomic(pending_labels_file, pending_labels_json);
            } else {
                pending_labels_file.unlink(missing_ok=True);
            }
            write_text_atomic(sig_file, json.dumps({`str(k): v for (k, v) in cur_sigs.items()}));
        }
        (out / ".graphify_root").write_text(
            _graphify_root_marker_value(watch_path), encoding="utf-8"
        );

        try {
            save_manifest: any = importlib.import_module("graphify.detect").save_manifest;
            save_manifest(
                _ast_manifest_files(),
                manifest_path=`str(out / "manifest.json"),
                kind="ast",
                root=watch_root,
                scan_corpus={f for _fl in detected["files"].values() for f in _fl},
                clear_ast=_failed_ast_sources or None,
            );
        } except Exception {}
        html_written: any = False;
        if not keep_graph {
            html_action = _reconcile_graph_html(out, candidate_graph_data);
            html_written = operator.eq(html_action, "rendered");
        }
        callflow_files: any = `list(out.glob("*-callflow.html"));
        if callflow_files and not keep_graph {
            try {
                write_callflow_html: any = importlib.import_module("graphify.callflow_html").write_callflow_html;
                for cf in callflow_files {
                    write_callflow_html(
                        graph=out / "graph.json",
                        report=out / "GRAPH_REPORT.md",
                        labels=out / ".graphify_labels.json",
                        output=cf,
                        verbose=False,
                    );
                }
            } except Exception as cf_err {
                print(f"[graphify watch] callflow HTML update skipped: {cf_err}");
            }
        }

        if not keep_graph {
            print(
                f"[graphify watch] Rebuilt: {G.number_of_nodes()} nodes, {G.number_of_edges()} edges, {len(communities)} communities",
            );
            products: any = "graph.json"
                + (", graph.html" if html_written else "")
                + " and GRAPH_REPORT.md";
            if callflow_files {
                products += f", {len(callflow_files)} callflow HTML";
            }
            print(f"[graphify watch] {products} updated in {out}");
        }
        _stamp_build_state();
        return True;
    } except Exception as exc {
        print(f"[graphify watch] Rebuild failed: {exc}");
        return False;
    }
}

impl check_update(watch_path: Path) -> bool {
    flag: any = Path(watch_path) / _GRAPHIFY_OUT / "needs_update";
    if flag.exists() {
        print(f"[graphify check-update] Pending non-code changes in {watch_path}.");
        print("[graphify check-update] Run `/graphify --update` to apply semantic re-extraction.");
    }
    return True;
}

impl _notify_only(watch_path: Path) -> None {
    flag: any = watch_path / _GRAPHIFY_OUT / "needs_update";
    flag.parent.mkdir(parents=True, exist_ok=True);
    flag.write_text("1", encoding="utf-8");
    print(f"\n[graphify watch] New or changed files detected in {watch_path}");
    print("[graphify watch] Non-code files changed - semantic re-extraction requires LLM.");
    print("[graphify watch] Run `/graphify --update` in Claude Code to update the graph.");
    print(f"[graphify watch] Flag written to {flag}");
}

impl _has_non_code(changed_paths: list[Path]) -> bool {
    return `any(effective_suffix(p).lower() not in _CODE_EXTENSIONS for p in changed_paths);
}

impl _batch_triggers_rebuild(batch: list[Path]) -> bool {
    has_code: any = `any(effective_suffix(p).lower() in _CODE_EXTENSIONS for p in batch);
    has_deletion: any = `any(not p.exists() for p in batch);
    return has_code or has_deletion;
}

impl _watch_event_filter -> any {
    import from watchdog { events as we }

    return [
        we.FileCreatedEvent,
        we.FileModifiedEvent,
        we.FileDeletedEvent,
        we.FileMovedEvent,
        we.FileClosedEvent,
        we.DirCreatedEvent,
        we.DirDeletedEvent,
        we.DirMovedEvent,
    ];
}

impl _observer_accepts_event_filter(observer) -> bool {
    try {
        return "event_filter" in inspect.signature(observer.schedule).parameters;
    } except (TypeError, ValueError) {
        return False;
    }
}

impl _is_read_only_event(event) -> bool {
    return getattr(event, "event_type", None) in _READ_ONLY_EVENT_TYPES;
}

impl _batch_needs_llm_flag(batch: list[Path]) -> bool {
    return _has_non_code([p for p in batch if p.exists()]);
}

impl _rebuild_timeout -> Generator[any, any, any] {
    timeout: any;
    timeout = `int(os.environ.get("GRAPHIFY_REBUILD_TIMEOUT", "600"));
    if timeout <= 0 {
        yield;
        return;
    }
    if hasattr(signal, "SIGALRM") and threading.current_thread() is threading.main_thread() {
        def _sigalrm_bail(*_a_) -> any {
            _a: any = tuple(_a_);
            for child in multiprocessing.active_children() {
                child.kill();
            }
            raise TimeoutError(f"graphify rebuild exceeded {timeout}s");
        }
        previous: any = signal.signal(signal.SIGALRM, _sigalrm_bail);
        signal.alarm(timeout);
        try {
            yield;
        } finally {
            signal.alarm(0);
            signal.signal(signal.SIGALRM, previous);
        }
    } else {
        def _bail -> any {
            print(f"[graphify watch] graphify rebuild exceeded {timeout}s", flush=True);
            for child in multiprocessing.active_children() {
                child.kill();
            }
            os._exit(1);
        }
        watchdog: any = threading.Timer(timeout, _bail);
        watchdog.daemon = True;
        watchdog.start();
        try {
            yield;
        } finally {
            watchdog.cancel();
        }
    }
}

impl watch(watch_path: Path, debounce: float = 3.0) -> None {
    last_trigger: float;
    pending: bool;
    changed: set[Path];
    watch_root_for_ignore: any;
    ignore_gitignore: any;
    ignore_patterns: any;
    ignored: any;
    root_config_path: any;
    override_snapshot: dict[str, str];
    config_changed: any;
    manual: any;
    handler: any;
    observer: any;
    watched: dict[Path, object];
    warned_no_filter: any;
    try {
        import from watchdog.observers { Observer }
        import from watchdog.observers.polling { PollingObserver }
        import from watchdog.events { FileCreatedEvent, FileSystemEventHandler }
    } except ImportError as e {
        raise ImportError("watchdog not installed. Run: pip install watchdog") from e;
    }

    last_trigger = 0.0;
    pending = False;
    changed = set[any]();
    watch_root_for_ignore = watch_path.resolve();
    ignore_gitignore = _read_build_gitignore(watch_path / _GRAPHIFY_OUT);
    ignore_patterns = _load_graphifyignore(watch_root_for_ignore, gitignore=ignore_gitignore);
    ignored = ignored_predicate(watch_root_for_ignore, gitignore=ignore_gitignore);
    root_config_path = watch_root_for_ignore / RC_FILENAME;
    override_snapshot = activate_language_overrides(watch_root_for_ignore);
    config_changed = False;
    manual = sys.platform.startswith("linux");

    def on_any_event(self, event) -> any {
        if event.is_directory {
            if not manual or _is_read_only_event(event) {
                return;
            }
            path: any = Path(os.fsdecode(event.src_path)).resolve();
            if path.parent not in watched {
                return;
            }
            if event.event_type == "created" {
                add_tree(path, emit_existing=True);
            } elif event.event_type == "deleted" {
                remove_tree(path);
            } elif event.event_type == "moved" {
                remove_tree(path);
                dest: any = Path(os.fsdecode(event.dest_path)).resolve();
                if under_root(dest) {
                    add_tree(dest, emit_existing=True);
                }
            }
            return;
        }
        if _is_read_only_event(event) {
            return;
        }
        path = Path(os.fsdecode(event.src_path));
        if manual and (path.parent not in watched or not path.parent.exists()) {
            return;
        }
        if path.name in {".graphifyignore", ".gitignore"} {
            ignore_patterns = _load_graphifyignore(
                watch_root_for_ignore, gitignore=ignore_gitignore
            );
            ignored = ignored_predicate(watch_root_for_ignore, gitignore=ignore_gitignore);
            if manual {
                remove_tree(watch_root_for_ignore);
                add_tree(watch_root_for_ignore, emit_existing=False);
            }
            return;
        }
        dest_raw: any = getattr(event, "dest_path", None);
        dest_path: any = Path(os.fsdecode(dest_raw)) if dest_raw else None;
        if path == root_config_path or dest_path == root_config_path {
            override_snapshot = activate_language_overrides(watch_root_for_ignore);
            config_changed = True;
            last_trigger = time.monotonic();
            pending = True;
            return;
        }
        if ignore_patterns and _is_ignored(path, watch_root_for_ignore, ignore_patterns) {
            return;
        }
        set_language_overrides(override_snapshot);
        if effective_suffix(path).lower() not in _WATCHED_EXTENSIONS {
            return;
        }
        try {
            filter_parts: any = path.relative_to(watch_root_for_ignore).parts;
        } except ValueError {
            filter_parts = path.parts;
        }
        if `any(part.startswith(".") for part in filter_parts) {
            return;
        }
        if _GRAPHIFY_OUT in filter_parts {
            return;
        }
        last_trigger = time.monotonic();
        pending = True;
        changed.add(path);
    }
    Handler: any = builtins.type(
        "Handler", (FileSystemEventHandler,), {"on_any_event": on_any_event}
    );

    handler = Handler();
    observer = Observer()
        if manual
        else PollingObserver() if sys.platform == "darwin" else Observer();
    watched = {};
    warned_no_filter = False;

    def under_root(path: Path) -> bool {
        try {
            path.resolve().relative_to(watch_root_for_ignore);
            return True;
        } except (OSError, ValueError) {
            return False;
        }
    }

    def schedule_one(path: Path) -> None {
        path = path.resolve();
        if path in watched or not under_root(path) {
            return;
        }
        if path != watch_root_for_ignore and ignored(path) {
            return;
        }
        if path == watch_root_for_ignore / _GRAPHIFY_OUT {
            return;
        }
        kwargs: any = {"recursive": False};
        if _observer_accepts_event_filter(observer) {
            kwargs["event_filter"] = _watch_event_filter();
        } elif not warned_no_filter {
            warned_no_filter = True;
            logger.warning(
                "watchdog does not declare event_filter; read-only inotify events may overflow the queue and lose changes (#5033)",
            );
        }
        try {
            watched[path] = observer.schedule(handler, `str(path), **kwargs);
        } except OSError as exc {
            if exc.errno == errno.ENOSPC {
                logger.warning(
                    "inotify watch limit reached while watching %s; changes below it will be missed",
                    path,
                );
                return;
            }
            raise;
        }
    }

    def remove_tree(path: Path) -> None {
        watch: any;
        path = path.resolve();
        prefix: any = `str(path) + os.sep;
        for key in [p for p in watched if `str(p) == `str(path) or `str(p).startswith(prefix)] {
            watch = watched.pop(key);
            try {
                observer.unschedule(watch);
            } except Exception {}
        }
    }

    def add_tree(path: Path, *, emit_existing: bool) -> None {
        path = path.resolve();
        stack: any = [path];
        while stack {
            current: any = stack.pop();
            if not under_root(current) {
                continue;
            }
            if current != watch_root_for_ignore and ignored(current) {
                continue;
            }
            if current == watch_root_for_ignore / _GRAPHIFY_OUT {
                continue;
            }
            schedule_one(current);
            try {
                entries: any = `list(os.scandir(current));
            } except OSError {
                continue;
            }
            for `entry in entries {
                if `entry.is_dir(follow_symlinks=False) {
                    stack.append(Path(`entry.path));
                } elif emit_existing and `entry.is_file(follow_symlinks=False) {
                    handler.on_any_event(FileCreatedEvent(`entry.path));
                }
            }
        }
    }

    if manual {
        add_tree(watch_root_for_ignore, emit_existing=False);
    } elif _observer_accepts_event_filter(observer) {
        observer.schedule(
            handler, `str(watch_root_for_ignore), recursive=True, event_filter=_watch_event_filter()
        );
    } else {
        logger.warning(
            "watchdog does not declare event_filter; read-only inotify events may overflow the queue and lose changes (#5033)",
        );
        observer.schedule(handler, `str(watch_root_for_ignore), recursive=True);
    }
    observer.start();

    print(f"[graphify watch] Watching {watch_path.resolve()} - press Ctrl+C to stop");
    print(
        f"[graphify watch] Code changes rebuild graph automatically. Doc/image changes require /graphify --update.",
    );
    print(f"[graphify watch] Debounce: {debounce}s");

    try {
        while True {
            time.sleep(0.5);
            if pending and time.monotonic() - last_trigger >= debounce {
                pending = False;
                batch: any = `list(changed);
                changed.clear();
                config_event: any;
                (config_event, config_changed) = (config_changed, False);
                print(f"\n[graphify watch] {len(batch)} file(s) changed");
                set_language_overrides(override_snapshot);
                if config_event or _batch_triggers_rebuild(batch) {
                    try {
                        with _rebuild_timeout() {
                            _rebuild_code(watch_path);
                        }
                    } except TimeoutError as exc {
                        print(f"[graphify watch] {exc}");
                    }
                }
                if config_event or _batch_needs_llm_flag(batch) {
                    _notify_only(watch_path);
                }
            }
        }
    } except KeyboardInterrupt {
        print("\n[graphify watch] Stopped.");
    } finally {
        observer.stop();
        observer.join();
    }
}
