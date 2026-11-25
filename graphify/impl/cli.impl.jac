impl _valid_price(value: float) -> float {
    if not math.isfinite(value) or value < 0 {
        raise ValueError("price must be finite and non-negative");
    }
    return value;
}

impl _nudge_for_out(nudge: str) -> str {
    out_path: any = importlib.import_module("graphify.paths").out_path;
    try {
        ref: any = out_path("graph.json").as_posix();
    } except Exception {
        return nudge;
    }
    if ref == _DEFAULT_NUDGE_GRAPH {
        return nudge;
    }
    d: any = json.loads(nudge);
    out: any = d["hookSpecificOutput"];
    out["additionalContext"] = out["additionalContext"].replace(_DEFAULT_NUDGE_GRAPH, ref);
    return json.dumps(d, ensure_ascii=False, separators=(",", ":")) + "\n";
}

impl _print_cloud_cta(out_dir: "Path", node_count: int = 0) {
    if os.environ.get("GRAPHIFY_NO_TIPS") or os.environ.get("GRAPHIFY_NO_CTA") {
        return;
    }
    try {
        if not sys.stdout.isatty() {
            return;
        }
    } except Exception {
        return;
    }
    marker: any = out_dir / ".cloud-cta-shown";
    try {
        count: any = `int(marker.read_text(encoding="utf-8").strip()) if marker.exists() else 0;
    } except Exception {
        count = 0;
    }
    count = min(count + 1, max(_CLOUD_CTA_SHOW_ON) + 1);
    try {
        marker.parent.mkdir(parents=True, exist_ok=True);
        marker.write_text(`str(count), encoding="utf-8");
    } except Exception {}
    if count not in _CLOUD_CTA_SHOW_ON {
        return;
    }
    print();
    if node_count >= _CLOUD_CTA_LARGE_GRAPH_NODES {
        print(f"  This graph has {node_count:,} nodes, past the free plan's 25k-per-repo limit.");
        print("  Graphify Pro indexes large repos, keeps them current, and adds");
        print("  cross-repo search and PR review. 14-day trial:");
        print(
            "  https://graphify.com/pricing?utm_source=cli&utm_medium=terminal&utm_campaign=oss&utm_content=scale",
        );
    } else {
        print("  Graphify Cloud: faster indexing, fewer tokens, cross-repo search,");
        print("  and PR review, with your whole SDLC mapped and always current.");
        print(
            "  Free plan, no card: https://app.graphify.com/signup?utm_source=cli&utm_medium=terminal&utm_campaign=oss&utm_content=post-run",
        );
    }
}

impl _default_graph_path -> str {
    return `str(Path(_GRAPHIFY_OUT) / "graph.json");
}

impl _pattern_terms(pattern: str) -> list[str] {
    words: any = _HINT_TERM_RE.findall(re.sub("\\\\.", " ", pattern));
    return [w for w in words if w.lower() not in _HINT_KEYWORDS][:3];
}

impl _rel_to_root(file_path: str, `root: "Path") -> "str | None" {
    if not file_path {
        return None;
    }
    try {
        p: any = Path(file_path.replace("\\", "/"));
        return (p if p.is_absolute() else `root / p).resolve().relative_to(`root).as_posix();
    } except (ValueError, OSError, RuntimeError) {
        return None;
    }
}

impl _search_hint_terms(t: dict) -> list[str] {
    cmd: any = `str(t.get("command") or "");
    if not cmd {
        return _pattern_terms(`str(t.get("pattern") or ""));
    }
    import shlex;
    try {
        tokens: any = shlex.split(cmd);
    } except ValueError {
        return [];
    }
    for (i, tok) in enumerate(tokens) {
        name: any = tok.replace("\\", "/").rsplit("/", 1)[-1].lower().removesuffix(".exe");
        if name not in _SEARCH_COMMANDS or name in ("find", "fd") or i and tokens[i - 1] == "|" {
            continue;
        }
        rest: any = iter(tokens[i + 1:]);
        for arg in rest {
            if arg in ("-e", "--regexp") {
                return _pattern_terms(next(rest, ""));
            }
            if arg in _HINT_VALUE_FLAGS {
                next(rest, None);
                continue;
            }
            if arg.startswith("-") {
                continue;
            }
            return _pattern_terms(arg);
        }
        return [];
    }
    return [];
}

impl _hint_text(value: object, cap: int) -> str {
    text: any = re.sub("[\\x00-\\x1f\\x7f`]", " ", `str(value));
    text = " ".join(text.split());
    return text if len(text) <= cap else text[:cap - 1] + "…";
}

impl _graph_hint(terms: "list[str]", rel_file: "str | None") -> tuple[str, list[str]] {
    base: any;
    lowered: any;
    n: any;
    out_path: any = importlib.import_module("graphify.paths").out_path;
    p: any = out_path("graph.json");
    if p.stat().st_size > _HINT_GRAPH_MAX_BYTES {
        return ("", []);
    }
    nodes: any = json.loads(p.read_text(encoding="utf-8")).get("nodes");
    nodes = [n for n in nodes if isinstance(n, `dict)] if isinstance(nodes, `list) else [];

    def key(n: dict) -> str {
        return `str(n.get("label") or "").lower().removesuffix("()").lstrip(".");
    }

    def line_of(n: dict) -> int {
        m: any = re.match("L(\\d+)", `str(n.get("source_location") or ""));
        return `int(m.group(1)) if m else 0;
    }

    command: any = "";
    if rel_file {
        base = rel_file.rsplit("/", 1)[-1];
        picked: any = sorted(
            (n for n in nodes if n.get("source_file") == rel_file and n.get("label") != base),
            key=line_of,
        )[:_HINT_MAX_NODES];
        if picked and _HINT_SAFE_ARG_RE.fullmatch(base) {
            command = f"graphify explain \"{base}\"";
        }
    } else {
        lowered = [term.lower() for term in terms];
        def mentions_a_term(label: any) -> bool {
            return label in lowered or `any(len(term) >= 5 and term in label for term in lowered);
        }
        ranked: any = sorted(
            ((0 if key(n) in lowered else 1, len(key(n)), n)
            for n in nodes
            if mentions_a_term(key(n))),
            key=lambda (r) -> any { (r[0], r[1]) },
        );
        picked = [n for (_, _, n) in ranked[:_HINT_MAX_NODES]];
        if picked and ranked[0][0] == 0 {
            command = "graphify explain \"" + format(picked[0].get("label"), "") + "\"";
        } elif picked {
            command = "graphify query \"" + format(" ".join(terms), "") + "\"";
        }
    }
    lines: any = [];
    for n in picked {
        loc: any = _hint_text(n.get("source_location") or "", 20);
        src: any = _hint_text(n.get("source_file") or "?", 120);
        lines.append(
            "- "
                + format(_hint_text(n.get("label") or "", 80), "")
                + " ("
                + format(src, "")
                + format(" " + loc if loc else "", "")
                + ")",
        );
    }
    return (command, lines);
}

impl _with_hint(
    nudge: str, terms: "list[str] | None" = None, rel_file: "str | None" = None
) -> str {
    if not terms and not rel_file {
        return nudge;
    }
    try {
        command: any;
        lines: any;
        (command, lines) = _graph_hint(terms or [], rel_file) as any;
        if not command and not lines {
            return nudge;
        }
        d: any = json.loads(nudge);
        out: any = d["hookSpecificOutput"];
        key: any = "permissionDecisionReason"
            if "permissionDecisionReason" in out
            else "additionalContext";
        extra: any = f"\nStart with: `{command}`" if command else "";
        if lines {
            extra += "\nWhat the graph already has for this call:\n" + "\n".join(lines);
        }
        out[key] += extra;
        return json.dumps(d, ensure_ascii=False, separators=(",", ":")) + "\n";
    } except Exception {
        return nudge;
    }
}

impl _stamped_manifest_files(
    files_by_type: dict[str, list[str]],
    sem_result: dict,
    `root: Path,
    partial_source_files: "set[str] | None" = None,
    failed_ast_sources: "set[str] | list[str] | None" = None,
    unverified_semantic_sources: "set[str] | list[str] | None" = None,
) -> dict[str, list[str]] {
    `root = Path(`root);

    def _resolve(value: str) -> Path {
        p: any = Path(value);
        if not p.is_absolute() {
            p = `root / p;
        }
        try {
            return p.resolve();
        } except (OSError, RuntimeError) {
            return p;
        }
    }

    sem_extracted: set[Path] = set[any]();
    for coll in ("nodes", "hyperedges") {
        for item in sem_result.get(coll, []) {
            sf: any = item.get("source_file", "");
            if sf {
                sem_extracted.add(_resolve(sf));
            }
        }
    }
    partial_resolved: any = {_resolve(p) for p in partial_source_files or set[any]()};
    unverified_resolved: any = {_resolve(p) for p in unverified_semantic_sources or set[any]()};
    failed_ast_resolved: any = {_resolve(p) for p in failed_ast_sources or []};
    sem_types: any = {"document", "paper", "image"};
    return {
        ftype: [
            f
            for f in flist
            if _resolve(f) not in failed_ast_resolved
                and (
                    ftype not in sem_types
                    or _resolve(f) in sem_extracted
                        and _resolve(f) not in partial_resolved
                        and _resolve(f) not in unverified_resolved
                )
        ]
        for (ftype, flist) in files_by_type.items()
    };
}

impl _handle_unverified_semantic_shrink(
    unverified_shrink,
    *,
    cli_allow_partial: bool,
    files_by_type,
    sem_result,
    target,
    partial_semantic_files,
    failed_ast_sources,
    semantic_files,
    cached_semantic_files=None,
    sem_cache_mode=None,
    sem_prompt=None,
    cache_root=None,
) -> any {
    cached_keys: any;
    if not unverified_shrink {
        return None;
    }
    incomplete: any = False;
    manifest_files: any = None;
    cleared_semantic: any = None;
    if not cli_allow_partial {
        incomplete = True;
        unverified_sources: any = `set(unverified_shrink.keys());
        manifest_files = _stamped_manifest_files(
            files_by_type,
            sem_result,
            target,
            partial_source_files=partial_semantic_files,
            failed_ast_sources=failed_ast_sources,
            unverified_semantic_sources=unverified_sources,
        );
        stamped: any = {f for _flist in manifest_files.values() for f in _flist};
        cleared_semantic = {`str(p) for p in semantic_files} - stamped;
    }

    def _path_key(value) -> str {
        p: any = Path(value);
        if not p.is_absolute() {
            p = Path(target) / p;
        }
        try {
            return os.path.normcase(`str(p.resolve()));
        } except (OSError, RuntimeError) {
            return os.path.normcase(os.path.abspath(`str(p)));
        }
    }

    cached_keys = {_path_key(p) for p in cached_semantic_files or []};
    cached_sources: any = sorted(sf for sf in unverified_shrink if _path_key(sf) in cached_keys);
    fresh_sources: any = sorted(sf for sf in unverified_shrink if _path_key(sf) not in cached_keys);

    marked: list[Path] = [];
    try {
        _mark_partial: any = importlib.import_module("graphify.cache").mark_semantic_cache_partial;
        marked = _mark_partial(
            sorted(unverified_shrink),
            root=Path(target),
            mode=sem_cache_mode,
            prompt=sem_prompt,
            cache_root=cache_root,
        );
    } except Exception as exc {
        print(
            f"[graphify extract] warning: could not mark degraded semantic cache entries: {exc}",
            file=sys.stderr,
        );
    }

    details: any = ", ".join(
        f"'{sf}' ({prior} -> {fresh} nodes)"
        for (sf, (prior, fresh)) in sorted(unverified_shrink.items()),
    );
    print(
        f"[graphify extract] semantic extraction is incomplete: unverified semantic shrink detected for {details}.",
        file=sys.stderr,
    );
    if cached_sources {
        cached_details: any = ", ".join(
            f"'{sf}' ({unverified_shrink[sf][0]} -> {unverified_shrink[sf][1]} nodes)"
            for sf in cached_sources,
        );
        replay_effect: any = "--allow-partial was passed, so the degraded replay is being written over the existing graph and the prior nodes are dropped."
            if cli_allow_partial
            else "Do NOT pass --allow-partial here: it would write the degraded replay over the larger existing graph and drop the prior nodes.";
        print(
            f"[graphify extract] {cached_details} was replayed from the semantic cache, not freshly extracted, so re-running with the same cache would replay it again. "
                + replay_effect
                + " Re-run to re-extract the marked source(s).",
            file=sys.stderr,
        );
    }
    if marked {
        print(
            "[graphify extract] marked "
                + format(len(marked), "")
                + " semantic cache entr"
                + format("y" if len(marked) == 1 else "ies", "")
                + " partial for re-extraction on the next run: "
                + format(", ".join(`str(p) for p in marked), ""),
            file=sys.stderr,
        );
    }
    if fresh_sources and not cli_allow_partial {
        print(
            "[graphify extract] The shrink guard stays armed for this write; pass --allow-partial to overwrite a larger existing graph anyway.",
            file=sys.stderr,
        );
    }
    return (incomplete, manifest_files, cleared_semantic);
}

impl _stale_graph_sources(
    graph_path: Path, scan_root: Path, seen_files: set[str], detection: dict | None = None
) -> list[str] {
    root_res: any;
    seen_nfc: any;
    excluded_exact: set[str];
    excluded_prefixes: list[str];
    c: any;
    nfc: any = importlib.import_module("graphify.paths").nfc;
    try {
        data: any = json.loads(graph_path.read_text(encoding="utf-8"));
    } except Exception {
        return [];
    }
    if not isinstance(data, `dict) {
        return [];
    }
    try {
        root_res = scan_root.resolve();
    } except (OSError, RuntimeError) {
        root_res = scan_root;
    }
    out_base: any = graph_path.parent.parent;
    try {
        out_base = out_base.resolve();
    } except (OSError, RuntimeError) {}

    def _within_root(p: Path) -> bool {
        try {
            p.relative_to(root_res);
            return True;
        } except ValueError {}
        try {
            p.resolve().relative_to(root_res);
            return True;
        } except (ValueError, OSError, RuntimeError) {
            return False;
        }
    }

    seen_nfc = {nfc(s) for s in seen_files};
    seen_basenames: any = {nfc(os.path.basename(s)) for s in seen_files};

    def _in_seen(p: Path) -> bool {
        if nfc(`str(p)) in seen_nfc {
            return True;
        }
        try {
            return nfc(`str(p.resolve())) in seen_nfc;
        } except (OSError, RuntimeError) {
            return False;
        }
    }
    excluded_exact = set[any]();
    excluded_prefixes = [];
    if detection {
        `entry: any;
        for `entry in `list(detection.get("ignored", []))
            + `list(detection.get("pruned_noise_dirs", [])) {
            e: any = nfc(`str(`entry));
            if e.endswith(os.sep) or e.endswith("/") {
                excluded_prefixes.append(e);
            } else {
                excluded_exact.add(e);
            }
        }
        for `entry in detection.get("skipped_sensitive", []) {
            excluded_exact.add(nfc(`str(`entry).split(" [", 1)[0]));
        }
    }

    def _provably_excluded(c: Path) -> bool {
        s: any;
        spellings: any = [nfc(`str(c))];
        try {
            spellings.append(nfc(`str(c.resolve())));
        } except (OSError, RuntimeError) {}
        for s_ in spellings {
            s = s_;
            if s in excluded_exact {
                return True;
            }
            if `any(s.startswith(pref) for pref in excluded_prefixes) {
                return True;
            }
        }
        try {
            _det_sensitive: any = importlib.import_module("graphify.detect")._is_sensitive;
            if _det_sensitive(c) {
                return True;
            }
        } except Exception {}
        return False;
    }

    stale: list[str] = [];
    kept_alive: list[str] = [];
    checked: set[str] = set[any]();
    for n in data.get("nodes", []) {
        if not isinstance(n, `dict) {
            continue;
        }
        sf: any = n.get("source_file");
        if not sf or not isinstance(sf, `str) or sf in checked {
            continue;
        }
        checked.add(sf);
        if "://" in sf {
            continue;
        }
        p: any = Path(sf);
        if p.is_absolute() {
            candidates: any = [p];
        } else {
            rel: any = sf.replace("\\", "/");
            bases: any = [root_res];
            if out_base != root_res {
                bases.append(out_base);
            }
            candidates = [Path(os.path.normpath(`str(base / rel))) for base in bases];
        }
        in_root: any = [c for c in candidates if _within_root(c)];
        if not in_root {
            continue;
        }
        if `any(_in_seen(c) for c in in_root) {
            continue;
        }
        alive: any = [];
        for c in in_root {
            try {
                if c.exists() {
                    alive.append(c);
                }
            } except OSError {}
        }
        if alive {
            if all(_provably_excluded(c) for c in alive) {
                stale.append(sf);
            } else {
                kept_alive.append(sf);
            }
            continue;
        }
        rel_sf: any = sf.replace("\\", "/");
        if "/" not in rel_sf and nfc(rel_sf) in seen_basenames {
            kept_alive.append(sf);
            continue;
        }
        stale.append(sf);
    }
    if kept_alive {
        print(
            f"[graphify] fail-closed: kept node(s) from {len(kept_alive)} source file(s) that left the scan corpus but still exist on disk (ignore rules or filters changed?). Run a full re-extraction to purge them if the exclusion is intentional.",
            file=sys.stderr,
        );
    }
    return stale;
}

impl _zero_node_stamped_code_sources(
    graph_path: Path, scan_root: Path, unchanged_code: list[str], manifest_path: Path | None = None
) -> list[str] {
    if not unchanged_code {
        return [];
    }
    nfc: any = importlib.import_module("graphify.paths").nfc;
    ast_empty: set[str] = set[any]();
    if manifest_path is not None {
        load_manifest: any = importlib.import_module("graphify.detect").load_manifest;
        for (_k, _v) in load_manifest(`str(manifest_path), root=scan_root).items() {
            if isinstance(_v, `dict) and _v.get("ast_empty") {
                ast_empty.add(nfc(_k));
            }
        }
    }
    try {
        data: any = json.loads(graph_path.read_text(encoding="utf-8"));
    } except Exception {
        return [];
    }
    if not isinstance(data, `dict) {
        return [];
    }
    try {
        root_res: any = scan_root.resolve();
    } except (OSError, RuntimeError) {
        root_res = scan_root;
    }
    out_base: any = graph_path.parent.parent;
    try {
        out_base = out_base.resolve();
    } except (OSError, RuntimeError) {}

    present: set[str] = set[any]();
    for n in data.get("nodes", []) {
        if not isinstance(n, `dict) {
            continue;
        }
        sf: any = n.get("source_file");
        if not sf or not isinstance(sf, `str) {
            continue;
        }
        present.add(nfc(sf));
        p: any = Path(sf);
        if p.is_absolute() {
            try {
                present.add(nfc(`str(p.resolve())));
            } except (OSError, RuntimeError) {}
        } else {
            rel: any = sf.replace("\\", "/");
            for base in (root_res, out_base) {
                present.add(nfc(os.path.normpath(`str(base / rel))));
            }
        }
    }

    _get_extractor: any = importlib.import_module("graphify.extract")._get_extractor;
    healed: list[str] = [];
    for f in unchanged_code {
        p = Path(f);
        if _get_extractor(p) is None {
            continue;
        }
        spellings: any = {nfc(`str(p))};
        try {
            spellings.add(nfc(`str(p.resolve())));
        } except (OSError, RuntimeError) {}
        try {
            spellings.add(nfc(p.resolve().relative_to(root_res).as_posix()));
        } except (ValueError, OSError, RuntimeError) {}
        if spellings & present {
            continue;
        }
        if spellings & ast_empty {
            continue;
        }
        healed.append(f);
    }
    return healed;
}

impl _zero_node_stamped_semantic_sources(
    graph_path: Path, scan_root: Path, unchanged_semantic: list[str]
) -> list[str] {
    if not unchanged_semantic {
        return [];
    }
    nfc: any = importlib.import_module("graphify.paths").nfc;
    try {
        data: any = json.loads(graph_path.read_text(encoding="utf-8"));
    } except Exception {
        return [];
    }
    if not isinstance(data, `dict) {
        return [];
    }
    try {
        root_res: any = scan_root.resolve();
    } except (OSError, RuntimeError) {
        root_res = scan_root;
    }
    out_base: any = graph_path.parent.parent;
    try {
        out_base = out_base.resolve();
    } except (OSError, RuntimeError) {}

    present: set[str] = set[any]();
    for n in data.get("nodes", []) {
        if not isinstance(n, `dict) {
            continue;
        }
        sf: any = n.get("source_file");
        if not sf or not isinstance(sf, `str) {
            continue;
        }
        present.add(nfc(sf));
        p: any = Path(sf);
        if p.is_absolute() {
            try {
                present.add(nfc(`str(p.resolve())));
            } except (OSError, RuntimeError) {}
        } else {
            rel: any = sf.replace("\\", "/");
            base: any;
            for base in (root_res, out_base) {
                present.add(nfc(os.path.normpath(`str(base / rel))));
            }
        }
    }

    hyper_items: any = `list(data.get("hyperedges", []) or []);
    if isinstance((data.get("graph") or {}).get("hyperedges"), `list) {
        hyper_items.extend(data["graph"]["hyperedges"]);
    }
    for h in hyper_items {
        if not isinstance(h, `dict) {
            continue;
        }
        sf = h.get("source_file");
        if not sf or not isinstance(sf, `str) {
            continue;
        }
        present.add(nfc(sf));
        p = Path(sf);
        if p.is_absolute() {
            try {
                present.add(nfc(`str(p.resolve())));
            } except (OSError, RuntimeError) {}
        } else {
            rel = sf.replace("\\", "/");
            for base in (root_res, out_base) {
                present.add(nfc(os.path.normpath(`str(base / rel))));
            }
        }
    }

    healed: list[str] = [];
    for f in unchanged_semantic {
        p = Path(f);
        spellings: any = {nfc(`str(p))};
        try {
            spellings.add(nfc(`str(p.resolve())));
        } except (OSError, RuntimeError) {}
        try {
            spellings.add(nfc(p.resolve().relative_to(root_res).as_posix()));
        } except (ValueError, OSError, RuntimeError) {}
        if spellings & present {
            continue;
        }
        healed.append(f);
    }
    return healed;
}

impl _record_extract_cost(graphify_out: Path, input_tokens: int, output_tokens: int, files: int) {
    cost: any;
    import from datetime { datetime, timezone }
    write_json_atomic: any = importlib.import_module("graphify.paths").write_json_atomic;

    cost_path: any = graphify_out / "cost.json";
    cost = {"runs": [], "total_input_tokens": 0, "total_output_tokens": 0};
    if cost_path.exists() {
        try {
            cost = json.loads(cost_path.read_text(encoding="utf-8"));
            cost.setdefault("runs", []);
            cost.setdefault("total_input_tokens", 0);
            cost.setdefault("total_output_tokens", 0);
            if not isinstance(cost["runs"], `list)
                or not all(
                    `type(cost[k]) is int for k in ("total_input_tokens", "total_output_tokens")
                )
            {
                raise ValueError("unexpected layout");
            }
        } except (OSError, ValueError, AttributeError) as exc {
            print(
                f"[graphify extract] warning: could not read {cost_path}, not updating it: {exc}",
                file=sys.stderr,
            );
            return;
        }
    }
    cost["runs"].append({
        "date": datetime.now(timezone.utc).isoformat(),
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "files": files,
    });
    cost["total_input_tokens"] += input_tokens;
    cost["total_output_tokens"] += output_tokens;
    try {
        write_json_atomic(cost_path, cost, indent=2, ensure_ascii=False);
    } except OSError as exc {
        print(f"[graphify extract] warning: could not write {cost_path}: {exc}", file=sys.stderr);
    }
}

impl _prune_graph_json_sources(graph_path: Path, stale_sources: list[str]) -> int {
    try {
        data: any = json.loads(graph_path.read_text(encoding="utf-8"));
    } except Exception {
        return 0;
    }
    if not isinstance(data, `dict) {
        return 0;
    }
    stale: any = `set(stale_sources);
    links_key: any = "links" if "links" in data else "edges";
    nodes: any = [n for n in data.get("nodes", []) if isinstance(n, `dict)];
    kept_nodes: any = [n for n in nodes if n.get("source_file") not in stale];
    removed_ids: any = {n.get("id") for n in nodes if n.get("source_file") in stale};
    n_removed: any = len(nodes) - len(kept_nodes);
    kept_edges: any = [
        e
        for e in data.get(links_key, [])
        if isinstance(e, `dict)
            and e.get("source_file") not in stale
            and e.get("source") not in removed_ids
            and e.get("target") not in removed_ids
    ];
    kept_hyper: any = [
        h
        for h in data.get("hyperedges", [])
        if isinstance(h, `dict) and h.get("source_file") not in stale
    ];
    if n_removed == 0
        and len(kept_edges) == len(data.get(links_key, []))
        and len(kept_hyper) == len(data.get("hyperedges", []))
    {
        return 0;
    }
    data["nodes"] = kept_nodes;
    data[links_key] = kept_edges;
    if "hyperedges" in data {
        data["hyperedges"] = kept_hyper;
    }
    _backup: any = importlib.import_module("graphify.export").backup_if_protected;
    _backup(graph_path.parent);
    write_json_atomic: any = importlib.import_module("graphify.paths").write_json_atomic;
    write_json_atomic(graph_path, data, compact=True);
    return n_removed;
}

impl _StageTimer.init(enabled: bool) {
    import time as _time;
    self._now = _time.perf_counter;
    self.enabled = enabled;
    self.start = self._now();
    self._last = self.start;
}

impl _StageTimer.mark(stage: str) {
    now: any = self._now();
    if self.enabled {
        print(f"[graphify timing] {stage}: {now - self._last:.1f}s", file=sys.stderr);
    }
    self._last = now;
}

impl _StageTimer.total {
    if self.enabled {
        print(f"[graphify timing] total: {self._now() - self.start:.1f}s", file=sys.stderr);
    }
}

impl _StageTimer.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl _StageTimer.__eq__(other: any) -> bool {
    return self is other;
}

impl _StageTimer.__hash__ -> int {
    return id(self);
}

impl _enforce_graph_size_cap_or_exit(gp: Path) {
    check_graph_file_size_cap: any = importlib.import_module(
        "graphify.security"
    ).check_graph_file_size_cap;
    try {
        check_graph_file_size_cap(gp);
    } except ValueError as exc {
        print(f"error: {exc}", file=sys.stderr);
        sys.exit(1);
    }
}

impl _load_cli_graph(gp: Path) -> any {
    import from networkx.readwrite { json_graph }
    consumed: any = importlib.import_module("graphify.paths").consumed;
    read_graph_json: any = importlib.import_module("graphify.paths").read_graph_json;

    if not gp.exists() {
        print(f"error: graph file not found: {gp}", file=sys.stderr);
        sys.exit(1);
    }
    _enforce_graph_size_cap_or_exit(gp);
    raw: any = read_graph_json(gp);
    if "links" not in raw and "edges" in raw {
        raw = `dict(raw, links=raw["edges"]);
    }
    raw = {**raw, "directed": True};
    raw = `dict(raw, nodes=consumed(raw["nodes"]), links=consumed(raw["links"]));
    return json_graph.node_link_graph(raw, edges="links");
}

impl _hook_strict_enabled(flag: bool) -> bool {
    v: any = os.environ.get("GRAPHIFY_HOOK_STRICT", "").strip().lower();
    if v in ("1", "true", "yes", "on") {
        return True;
    }
    if v in ("0", "false", "no", "off") {
        return False;
    }
    return flag;
}

impl _touch_query_stamp(graph_path: "Path") {
    try {
        write_text_atomic: any = importlib.import_module("graphify.paths").write_text_atomic;
        stamp: any = Path(graph_path).parent / "cache" / "last_query_stamp";
        stamp.parent.mkdir(parents=True, exist_ok=True);
        write_text_atomic(stamp, `str(time.time()));
    } except Exception {}
}

impl _query_stamp_fresh -> bool {
    out_path: any = importlib.import_module("graphify.paths").out_path;
    try {
        ttl: any = `float(os.environ.get("GRAPHIFY_HOOK_STRICT_TTL", "1800"));
        return operator.lt(
            time.time() - out_path("cache", "last_query_stamp").stat().st_mtime, ttl
        );
    } except Exception {
        return False;
    }
}

impl _nudge_allowed(payload: dict) -> bool {
    out_path: any = importlib.import_module("graphify.paths").out_path;
    write_text_atomic: any = importlib.import_module("graphify.paths").write_text_atomic;
    import hashlib;
    stamp: any = _query_stamp_fresh();
    try {
        cap: any = `int(os.environ.get("GRAPHIFY_HOOK_NUDGE_CAP", "5"));
    } except ValueError {
        cap = 0;
    }
    key: any = re.sub("[^A-Za-z0-9_-]", "_", `str(payload.get("session_id") or ""))[:64];
    if not key {
        return not stamp;
    }
    agent: any = `str(payload.get("agent_id") or "");
    if agent {
        key += "-" + hashlib.sha256(agent.encode("utf-8")).hexdigest()[:16];
    }
    try {
        d: any = out_path("cache", "hook_sessions");
        d.mkdir(parents=True, exist_ok=True);
        marker: any = d / f"{key}.nudges";
        try {
            count: any = `int(marker.read_text(encoding="utf-8").strip() or "0");
        } except (OSError, ValueError) {
            count = 0;
        }
        if count and stamp {
            return False;
        }
        if 0 < cap <= count {
            return False;
        }
        write_text_atomic(marker, `str(count + 1));
        if count == 0 {
            _gc_hook_session_markers(d);
        }
        return True;
    } except Exception {
        return not stamp;
    }
}

impl _gc_hook_session_markers(d: "Path") {
    try {
        cutoff: any = time.time() - 86400;
        for `entry in os.scandir(d) {
            try {
                if `entry.stat().st_mtime < cutoff {
                    os.unlink(`entry.path);
                }
            } except OSError {}
        }
    } except OSError {}
}

impl _reset_hook_session(session_id: str) {
    out_path: any = importlib.import_module("graphify.paths").out_path;
    key: any = re.sub("[^A-Za-z0-9_-]", "_", `str(session_id or ""))[:64];
    if not key {
        return;
    }
    d: any = out_path("cache", "hook_sessions");
    if not d.is_dir() {
        return;
    }
    `own: any = re.compile(
        re.escape(key) + "(?:-[0-9a-f]{16})?\\.nudges|" + re.escape(key) + "\\.denied"
    );
    for `entry in os.scandir(d) {
        if `own.fullmatch(`entry.name) {
            try {
                os.unlink(`entry.path);
            } except FileNotFoundError {}
        }
    }
}

impl _mark_session_denied(session_id: str) -> bool {
    out_path: any = importlib.import_module("graphify.paths").out_path;
    sid: any = re.sub("[^A-Za-z0-9_-]", "_", `str(session_id))[:64];
    if not sid {
        return False;
    }
    try {
        d: any = out_path("cache", "hook_sessions");
        d.mkdir(parents=True, exist_ok=True);
        fd: any = os.open(`str(d / f"{sid}.denied"), os.O_CREAT | os.O_EXCL | os.O_WRONLY, 420);
        os.close(fd);
        _gc_hook_session_markers(d);
        return True;
    } except FileExistsError {
        return False;
    } except Exception {
        return False;
    }
}

impl _bash_commands(cmd_str: str) -> Generator[any, any, any] {
    text: any = cmd_str;
    m: any = _HEREDOC_OPEN_RE.search(text);
    while m {
        nl_idx: any = text.find("\n", m.end());
        if nl_idx == -1 {
            break;
        }
        term: any = re.compile("^\\s*" + re.escape(m.group(2)) + "\\s*$", re.MULTILINE);
        t: any = term.search(text, nl_idx + 1);
        if t is None {
            text = text[:nl_idx + 1];
            break;
        }
        text = text[:nl_idx + 1] + text[t.end():];
        m = _HEREDOC_OPEN_RE.search(text, nl_idx + 1);
    }
    text = re.sub("'[^']*'", "Q", text);
    text = re.sub("\"[^\"]*\"", "Q", text);
    parts: any = re.split("(\\|\\|?|[;&\\n]|\\$\\(|`|\\(|\\)|\\{|\\})", text);
    piped: any = False;
    for index in range(0, len(parts), 2) {
        if index > 0 and parts[index - 1] in ("|", "||") {
            piped = operator.eq(parts[index - 1], "|");
        }
        tokens: any = parts[index].split();
        if not tokens {
            continue;
        }
        segment_piped: any;
        (segment_piped, piped) = (piped, False);
        i: any = 0;
        while i < len(tokens) {
            tok: any = tokens[i];
            if "=" in tok.split("/")[-1] and not tok.startswith(("-", "/")) {
                i += 1;
                continue;
            }
            name: any = tok.replace("\\", "/").rsplit("/", 1)[-1].lower();
            name = name[:-4] if name.endswith(".exe") else name;
            if name in _COMMAND_WRAPPERS {
                i += 1;
                while i < len(tokens) and tokens[i].startswith("-") {
                    i += 1;
                }
                continue;
            }
            yield (name, tokens[i + 1:], segment_piped);
            break;
        }
    }
}

impl _bash_invokes_search(cmd_str: str) -> bool {
    for (name, args, piped) in _bash_commands(cmd_str) {
        if name in _SEARCH_COMMANDS {
            return True;
        }
        if name == "git"
            and `any(operator.eq(t2, "grep") for t2 in args[:3] if not t2.startswith("-"))
        {
            return True;
        }
        if name in ("sed", "awk") and not piped {
            operands: any = [t2 for t2 in args if not t2.startswith("-") and "=" not in t2];
            if not _sed_awk_in_place(name, args) and len(operands) >= 2 {
                return True;
            }
        }
    }
    return False;
}

impl _sed_awk_in_place(name: str, args: "list[str]") -> bool {
    return `any(
        t2.startswith("--in-place")
            or (
                t2.startswith("-i")
                    if name == "awk"
                    else t2.startswith("-") and not t2.startswith("--") and "i" in t2
            )
        for t2 in args,
    );
}

impl _bash_read_target(cmd_str: str, cwd: str = "") -> "str | None" {
    p: any;
    out_path: any = importlib.import_module("graphify.paths").out_path;
    try {
        `root: any = Path(os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()).resolve();
        base: any = `root;
        if cwd and not _is_cwd_relative(cwd) {
            c: any = Path(cwd).resolve();
            if c.is_relative_to(`root) {
                base = c;
            }
        }
        outs: any = [];
        for o in (out_path(), Path("graphify-out")) {
            outs.append((`root / o if _is_cwd_relative(`str(o)) else o).resolve());
        }
    } except (OSError, RuntimeError, ValueError) {
        return None;
    }
    for (name, args, _piped) in _bash_commands(cmd_str) {
        if name not in _BASH_READERS {
            continue;
        }
        if name == "sed"
            and (
                _sed_awk_in_place(name, args)
                or not `any(
                    a in ("--quiet", "--silent")
                        or a.startswith("-") and not a.startswith("--") and "n" in a
                    for a in args,
                )
            )
        {
            continue;
        }
        files: "list[str]" = [];
        it: any = iter(args);
        tok: any;
        for tok in it {
            if ">" in tok {
                if tok.split(">", 1)[0] in ("", "1", "&") {
                    files = [];
                    break;
                }
                if tok.endswith(">") {
                    next(it, None);
                }
                continue;
            }
            if tok.startswith("<<") {
                if tok in ("<<", "<<-", "<<<") {
                    next(it, None);
                }
                continue;
            }
            if tok == "<" {
                tok = next(it, "");
            } elif tok.startswith("<") {
                tok = tok[1:];
            } elif name == "sed" and tok in ("-e", "-f", "--expression", "--file") {
                next(it, None);
                continue;
            } elif tok.startswith("-") {
                continue;
            }
            files.append(tok);
        }
        for f in files {
            if not f or re.search("[$`~*?\\[\\]{}]", f) {
                continue;
            }
            seg: any = f.lower().replace("\\", "/").rsplit("/", 1)[-1];
            ext: any = "." + seg.rsplit(".", 1)[-1];
            if "." not in seg or ext not in _HOOK_SOURCE_EXTS or ext in _BASH_READ_SKIP_EXTS {
                continue;
            }
            try {
                p = Path(f.replace("\\", "/"));
                p = (base / p if _is_cwd_relative(`str(p)) else p).resolve();
                if p.is_file()
                    and p.is_relative_to(`root)
                    and not `any(p.is_relative_to(o) for o in outs)
                {
                    return `str(p);
                }
            } except (OSError, RuntimeError, ValueError) {
                continue;
            }
        }
    }
    return None;
}

impl _search_is_outside_project(tool_input: dict) -> bool {
    command: any;
    `root: any;
    command = `str(tool_input.get("command") or "");
    if command {
        import shlex;
        if `any(c in command for c in "$`;&|<>\n\\") {
            return False;
        }
        try {
            tokens: any = shlex.split(command);
        } except ValueError {
            return False;
        }
        if not tokens
            or tokens[0].rsplit("/", 1)[-1] not in {
                "grep",
                "egrep",
                "fgrep",
                "zgrep",
                "rg",
                "ripgrep",
            }
        {
            return False;
        }
        positional: any = [];
        explicit_pattern: any = False;
        options: any = True;
        args: any = iter(tokens[1:]);
        for arg in args {
            if options and arg == "--" {
                options = False;
            } elif options and arg in ("-e", "--regexp", "-f", "--file") {
                if next(args, None) is None {
                    return False;
                }
                explicit_pattern = True;
            } elif options and arg.startswith(("--regexp=", "--file=")) {
                explicit_pattern = True;
            } elif options and arg in _HINT_VALUE_FLAGS {
                if next(args, None) is None {
                    return False;
                }
            } elif options and arg.startswith("--") {
                if arg.split("=", 1)[0] in _HINT_VALUE_FLAGS and "=" in arg {
                    continue;
                }
                if arg not in {
                    "--ignore-case",
                    "--line-number",
                    "--recursive",
                    "--fixed-strings",
                    "--word-regexp",
                    "--invert-match",
                }
                {
                    return False;
                }
            } elif options and arg.startswith("-") {
                if not re.fullmatch("-[nriIvVwxlLchHqsoEFGPRUa]+", arg) {
                    return False;
                }
            } else {
                positional.append(arg);
            }
        }
        paths: any = positional if explicit_pattern else positional[1:];
    } else {
        paths = [`str(tool_input.get("path") or "")];
    }
    if not paths
        or `any(not p or operator.eq(p, "-") or re.search("[$`*?\\[\\]{}~]", p) for p in paths)
    {
        return False;
    }
    comptime if target_().os == "windows" {
        if command and `any(p.startswith("/") for p in paths) {
            return False;
        }
    } else {
        if command and False {
            return False;
        }
    }
    try {
        `root = Path(os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()).resolve();
        return all(not Path(p).resolve().is_relative_to(`root) for p in paths);
    } except (ValueError, OSError, RuntimeError) {
        return False;
    }
}

impl _run_hook_guard(kind: str, strict: bool = False) {
    `root: any;
    out_dirs: list[Path];
    out_path: any = importlib.import_module("graphify.paths").out_path;
    if kind == "gemini" {
        payload: any = {"decision": "allow"};
        try {
            if out_path("graph.json").is_file() {
                payload["additionalContext"] = _GEMINI_NUDGE_TEXT;
            }
        } except Exception {}
        sys.stdout.write(json.dumps(payload, ensure_ascii=False, separators=(",", ":")));
        return;
    }
    try {
        d: any = json.loads(sys.stdin.buffer.read().decode("utf-8", "replace"));
    } except Exception {
        return;
    }
    if not isinstance(d, `dict) {
        return;
    }
    if kind == "compact" {
        try {
            if d.get("hook_event_name", "SessionStart") != "SessionStart"
                or d.get("source") != "compact"
            {
                return;
            }
            _reset_hook_session(`str(d.get("session_id") or ""));
            if out_path("graph.json").is_file() {
                sys.stdout.write(_nudge_for_out(_COMPACT_CONTEXT));
            }
        } except Exception {}
        return;
    }
    t: any = d.get("tool_input", d);
    if not isinstance(t, `dict) {
        return;
    }
    try {
        bash_read: any = False;
        if kind == "search" and d.get("tool_name") in (None, "Bash") {
            target: any = _bash_read_target(
                `str(t.get("command", "") or ""), `str(d.get("cwd") or "")
            );
            if target {
                (kind, t, bash_read) = ("read", {"file_path": target}, True);
            }
        }
        if kind == "search" {
            cmd_str: any = `str(t.get("command", "") or "");
            pattern: any = t.get("pattern");
            is_grep_tool: any = not cmd_str
                and isinstance(pattern, `str)
                and `bool(pattern)
                and d.get("tool_name") in (None, "Grep");
            is_bash_search: any = `bool(cmd_str) and _bash_invokes_search(cmd_str);
            if not (is_grep_tool or is_bash_search) or not out_path("graph.json").is_file() {
                return;
            }
            search_stale: any = False;
            try {
                if out_path("needs_update").exists() {
                    search_stale = True;
                }
            } except Exception {}
            if is_grep_tool {
                path: any = t.get("path", ".");
                if not isinstance(path, `str) {
                    return;
                }
                `root = Path(os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()).resolve();
                target = Path(path.replace("\\", "/"));
                if _is_cwd_relative(path) {
                    target = `root / target;
                }
                target = target.resolve();
                if not target.is_relative_to(`root) {
                    return;
                }
                output: any;
                for output in (out_path(), `root / "graphify-out") {
                    if _is_cwd_relative(`str(output)) {
                        output = `root / output;
                    }
                    if target.is_relative_to(output.resolve()) {
                        return;
                    }
                }
                indexed: any = not target.is_file() or _target_is_indexed(`str(target), `root);
                if indexed
                    and _hook_strict_enabled(strict)
                    and not out_path("needs_update").exists()
                    and not _query_stamp_fresh()
                    and _mark_session_denied(`str(d.get("session_id") or ""))
                {
                    sys.stdout.write(_with_hint(_SEARCH_DENY, terms=_search_hint_terms(t)));
                    return;
                }
                if not search_stale and target.is_file() and indexed {
                    try {
                        if os.stat(`str(target)).st_mtime
                            > os.stat(`str(out_path("graph.json"))).st_mtime
                            and not _target_matches_manifest(`str(target), `root)
                        {
                            search_stale = True;
                        }
                    } except OSError {}
                }
            }
            if not _search_is_outside_project(t) and _nudge_allowed(d) {
                nudge: any = _SEARCH_NUDGE_STALE if search_stale else _SEARCH_NUDGE;
                sys.stdout.write(_with_hint(_nudge_for_out(nudge), terms=_search_hint_terms(t)));
            }
        } elif kind == "read" {
            vals: any = [
                `str(t.get("file_path") or ""),
                `str(t.get("pattern") or ""),
                `str(t.get("path") or ""),
            ];
            tails: any = [
                "." + seg.rsplit(".", 1)[-1]
                for v in vals
                if v
                for seg in [v.lower().replace("\\", "/").rsplit("/", 1)[-1]]
                if "." in seg
            ];
            if not `any(tl in _HOOK_SOURCE_EXTS for tl in tails) {
                return;
            }
            `root = Path(os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd());
            try {
                `root = `root.resolve();
            } except (OSError, RuntimeError) {}
            out_dirs = [];
            try {
                cfg_out: any = out_path();
                if _is_cwd_relative(`str(cfg_out)) {
                    cfg_out = `root / cfg_out;
                }
                out_dirs.append(cfg_out.resolve());
            } except (OSError, RuntimeError) {}
            try {
                def_out: any = (`root / "graphify-out").resolve();
                if def_out not in out_dirs {
                    out_dirs.append(def_out);
                }
            } except (OSError, RuntimeError) {}

            def _is_under_out(target: str) -> bool {
                if not target {
                    return False;
                }
                try {
                    norm: any = target.replace("\\", "/");
                    p: any = Path(norm);
                    if _is_cwd_relative(norm) {
                        p = `root / p;
                    }
                    resolved: any = p.resolve();
                    for od in out_dirs {
                        try {
                            resolved.relative_to(od);
                            return True;
                        } except ValueError {}
                        try {
                            rel: any = os.path.relpath(`str(resolved).lower(), `str(od).lower());
                            if rel == "."
                                or not rel.startswith(".." + os.sep)
                                    and rel != ".."
                                    and not os.path.isabs(rel)
                            {
                                return True;
                            }
                        } except (ValueError, OSError) {}
                    }
                } except (ValueError, OSError, RuntimeError) {}
                return False;
            }

            out_candidates: any = [
                `str(t.get("file_path") or ""),
                `str(t.get("path") or ""),
                `str(t.get("pattern") or ""),
            ];
            if t.get("path") and t.get("pattern") {
                out_candidates.append(
                    format(t.get("path"), "") + "/" + format(t.get("pattern"), "")
                );
            }
            if `any(_is_under_out(c) for c in out_candidates if c) {
                return;
            }
            path_vals: any = [`str(t.get("file_path") or ""), `str(t.get("path") or "")];
            explicit: any = [v for v in path_vals if v];
            if explicit {
                in_project: any = False;
                for v in explicit {
                    p: any = Path(v);
                    if _is_cwd_relative(v) {
                        in_project = True;
                        break;
                    }
                    try {
                        p.resolve().relative_to(`root);
                        in_project = True;
                        break;
                    } except (ValueError, OSError, RuntimeError) {
                        continue;
                    }
                }
                if not in_project {
                    return;
                }
            }
            try {
                gmtime: any = os.stat(`str(out_path("graph.json"))).st_mtime;
            } except OSError {
                return;
            }
            stale: any = False;
            fp: any = `str(t.get("file_path") or "");
            if fp {
                try {
                    stale = operator.gt(os.stat(fp).st_mtime, gmtime);
                    if stale and _target_matches_manifest(fp, `root) {
                        stale = False;
                    }
                } except OSError {
                    stale = False;
                }
            }
            try {
                if out_path("needs_update").exists() {
                    stale = True;
                }
            } except Exception {}
            if stale {
                if _nudge_allowed(d) {
                    sys.stdout.write(_nudge_for_out(_READ_NUDGE_STALE));
                }
                return;
            }
            tool_name: any = d.get("tool_name");
            if not bash_read
                and _hook_strict_enabled(strict)
                and tool_name in (None, "Read")
                and not _query_stamp_fresh()
                and _target_is_indexed(fp, `root)
                and _mark_session_denied(`str(d.get("session_id") or ""))
            {
                sys.stdout.write(_with_hint(_READ_DENY, rel_file=_rel_to_root(fp, `root)));
                return;
            }
            if _nudge_allowed(d) {
                sys.stdout.write(
                    _with_hint(_nudge_for_out(_READ_NUDGE), rel_file=_rel_to_root(fp, `root))
                );
            }
        }
    } except Exception {}
}

impl _is_cwd_relative(value: str) -> bool {
    pure: any = PureWindowsPath(value) if os.name == "nt" else PurePosixPath(value);
    return not pure.root and not pure.drive;
}

impl _target_matches_manifest(file_path: str, `root: "Path") -> bool {
    _md5_file: any = importlib.import_module("graphify.detect")._md5_file;
    _nfc: any = importlib.import_module("graphify.detect")._nfc;
    out_path: any = importlib.import_module("graphify.paths").out_path;
    try {
        f: any;
        with out_path("manifest.json").open("rb") as f {
            raw: any = f.read(2000001);
        }
        if len(raw) > 2000000 {
            return False;
        }
        manifest: any = json.loads(raw);
        if not isinstance(manifest, `dict) {
            return False;
        }
        p: any = Path(os.path.abspath(file_path));
        rel: any = _nfc(p.relative_to(`root).as_posix());
        `entry: any = manifest.get(rel, manifest.get(_nfc(`str(p))));
        if not isinstance(`entry, `dict) {
            return False;
        }
        if "hash" in `entry and "ast_hash" not in `entry {
            hashes: any = [`entry["hash"]];
        } else {
            hashes = [`entry.get("ast_hash", ""), `entry.get("semantic_hash", "")];
        }
        if not all(isinstance(h, `str) for h in hashes) {
            return False;
        }
        hashes = [h for h in hashes if h];
        if not hashes or len(`set(hashes)) != 1 {
            return False;
        }
        return operator.eq(hashes[0], _md5_file(p));
    } except Exception {
        return False;
    }
}

impl _target_is_indexed(file_path: str, `root: "Path") -> bool {
    keys: any;
    out_path: any = importlib.import_module("graphify.paths").out_path;
    if not file_path {
        return True;
    }
    try {
        mp: any = out_path("manifest.json");
        st: any = mp.stat();
        if st.st_size > 2000000 {
            return True;
        }
        manifest: any = json.loads(mp.read_text(encoding="utf-8"));
        if not isinstance(manifest, `dict) or not manifest {
            return True;
        }
        p: any = Path(file_path);
        rels: any = set[any]();
        try {
            rels.add(p.resolve().relative_to(`root).as_posix());
        } except (ValueError, OSError, RuntimeError) {}
        rels.add(p.name);
        keys = {`str(k).replace("\\", "/") for k in manifest};
        abskey: any = `str(p).replace("\\", "/");
        def recorded(rel: any) -> bool {
            return rel in keys or `any(k.endswith("/" + rel) or k == rel for k in keys);
        }
        return abskey in keys or `any(r and recorded(r) for r in rels);
    } except Exception {
        return True;
    }
}

impl _clone_repo(url: str, branch: str | None = None, out_dir: Path | None = None) -> Path {
    import subprocess as _sp;
    import re as _re;
    url = url.rstrip("/");
    if not url.endswith(".git") {
        git_url: any = url + ".git";
    } else {
        git_url = url;
        url = url[:-4];
    }
    m: any = _re.search("github\\.com[:/]([^/]+)/([^/]+?)(?:\\.git)?$", url);
    if not m {
        print(f"error: not a recognised GitHub URL: {url}", file=sys.stderr);
        sys.exit(1);
    }
    owner: any;
    repo: any;
    (owner, repo) = (m.group(1), m.group(2));

    if out_dir {
        dest: any = out_dir;
    } else {
        dest = Path.home() / ".graphify" / "repos" / owner / repo;
    }

    if branch and branch.startswith("-") {
        print(f"error: invalid branch name: {branch!r}", file=sys.stderr);
        sys.exit(1);
    }

    if dest.exists() {
        print(f"Repo already cloned at {dest} - pulling latest...", flush=True);
        cmd: any = ["git", "-C", `str(dest), "pull"];
        if branch {
            cmd += ["origin", "--", branch];
        }
        result: any = _sp.run(cmd, capture_output=True, text=True);
        if result.returncode != 0 {
            print(f"warning: git pull failed:\n{result.stderr}", file=sys.stderr);
        }
    } else {
        dest.parent.mkdir(parents=True, exist_ok=True);
        print(f"Cloning {url} -> {dest} ...", flush=True);
        cmd = ["git", "clone", "--depth", "1"];
        if branch {
            cmd += ["--branch", branch];
        }
        cmd += ["--", git_url, `str(dest)];
        result = _sp.run(cmd, capture_output=True, text=True);
        if result.returncode != 0 {
            print(f"error: git clone failed:\n{result.stderr}", file=sys.stderr);
            sys.exit(1);
        }
    }

    print(f"Ready at: {dest}", flush=True);
    return dest;
}

impl _reenter_main {
    main: any = importlib.import_module("graphify.__main__").main;
    main();
}

impl dispatch_command(cmd: str) {
    G: any;
    u: any;
    v: any;
    d: any;
    html_stale_marker: any;
    _MERGE_MAX_BYTES: any;
    link: any;
    has_path: any;
    target: any;
    manifest_path: any;
    _ctx_root: any;
    _chunk_stats: any;
    if cmd == "provider" {
        _custom_providers_path: any = importlib.import_module(
            "graphify.llm"
        )._custom_providers_path;
        BACKENDS: any = importlib.import_module("graphify.llm").BACKENDS;
        import json as _json;
        subcmd: any = sys.argv[2] if len(sys.argv) > 2 else "";
        global_path: any = _custom_providers_path(global_=True);

        if subcmd == "list" {
            global_path.parent.mkdir(parents=True, exist_ok=True);
            existing: dict = {};
            if global_path.is_file() {
                try {
                    existing = _json.loads(global_path.read_text(encoding="utf-8"));
                } except Exception {}
            }
            if not existing {
                print("No custom providers registered.");
            } else {
                name: any;
                for name in existing {
                    print(
                        "  "
                            + format(name, "")
                            + "  ("
                            + format(existing[name].get("base_url", ""), "")
                            + ")",
                    );
                }
            }
        } elif subcmd == "show" {
            name = sys.argv[3] if len(sys.argv) > 3 else "";
            if not name {
                print("Usage: graphify provider show <name>", file=sys.stderr);
                sys.exit(1);
            }
            existing = {};
            if global_path.is_file() {
                try {
                    existing = _json.loads(global_path.read_text(encoding="utf-8"));
                } except Exception {}
            }
            if name not in existing {
                print(f"Provider '{name}' not found.", file=sys.stderr);
                sys.exit(1);
            }
            print(_json.dumps({name: existing[name]}, indent=2));
        } elif subcmd == "add" {
            args: any = sys.argv[3:];
            name = args[0] if args and not args[0].startswith("-") else "";
            if not name {
                print(
                    "Usage: graphify provider add <name> --base-url URL --default-model MODEL --env-key KEY",
                    file=sys.stderr,
                );
                sys.exit(1);
            }
            if name in BACKENDS {
                print(
                    f"Error: '{name}' is a built-in provider and cannot be overridden.",
                    file=sys.stderr,
                );
                sys.exit(1);
            }
            base_url: any = "";
            default_model: any = "";
            env_key: any = "";
            pricing_input: any = 0.0;
            pricing_output: any = 0.0;
            i: any = 1;
            while i < len(args) {
                a: any = args[i];
                if a == "--base-url" and i + 1 < len(args) {
                    base_url = args[i + 1];
                    i += 2;
                } elif a.startswith("--base-url=") {
                    base_url = a.split("=", 1)[1];
                    i += 1;
                } elif a == "--default-model" and i + 1 < len(args) {
                    default_model = args[i + 1];
                    i += 2;
                } elif a.startswith("--default-model=") {
                    default_model = a.split("=", 1)[1];
                    i += 1;
                } elif a == "--env-key" and i + 1 < len(args) {
                    env_key = args[i + 1];
                    i += 2;
                } elif a.startswith("--env-key=") {
                    env_key = a.split("=", 1)[1];
                    i += 1;
                } elif a == "--pricing-input" and i + 1 < len(args) {
                    try {
                        pricing_input = _valid_price(`float(args[i + 1]));
                    } except ValueError {
                        print(
                            f"Error: invalid price for --pricing-input: '{args[i + 1]}' (expected a finite, non-negative number)",
                            file=sys.stderr,
                        );
                        sys.exit(1);
                    }
                    i += 2;
                } elif a.startswith("--pricing-input=") {
                    val: any = a.split("=", 1)[1];
                    try {
                        pricing_input = _valid_price(`float(val));
                    } except ValueError {
                        print(
                            f"Error: invalid price for --pricing-input: '{val}' (expected a finite, non-negative number)",
                            file=sys.stderr,
                        );
                        sys.exit(1);
                    }
                    i += 1;
                } elif a == "--pricing-output" and i + 1 < len(args) {
                    try {
                        pricing_output = _valid_price(`float(args[i + 1]));
                    } except ValueError {
                        print(
                            f"Error: invalid price for --pricing-output: '{args[i + 1]}' (expected a finite, non-negative number)",
                            file=sys.stderr,
                        );
                        sys.exit(1);
                    }
                    i += 2;
                } elif a.startswith("--pricing-output=") {
                    val = a.split("=", 1)[1];
                    try {
                        pricing_output = _valid_price(`float(val));
                    } except ValueError {
                        print(
                            f"Error: invalid price for --pricing-output: '{val}' (expected a finite, non-negative number)",
                            file=sys.stderr,
                        );
                        sys.exit(1);
                    }
                    i += 1;
                } else {
                    i += 1;
                }
            }
            if not base_url or not default_model or not env_key {
                print(
                    "Error: --base-url, --default-model, and --env-key are required.",
                    file=sys.stderr,
                );
                sys.exit(1);
            }
            provider_base_url_ok: any = importlib.import_module(
                "graphify.llm"
            ).provider_base_url_ok;
            if not provider_base_url_ok(base_url, name) {
                print(
                    f"Error: refusing to add provider with unsafe base_url {base_url!r}.",
                    file=sys.stderr,
                );
                sys.exit(1);
            }
            global_path.parent.mkdir(parents=True, exist_ok=True);
            existing = {};
            if global_path.is_file() {
                try {
                    existing = _json.loads(global_path.read_text(encoding="utf-8"));
                } except Exception {}
            }
            existing[name] = {
                "base_url": base_url,
                "default_model": default_model,
                "env_key": env_key,
                "pricing": {"input": pricing_input, "output": pricing_output},
                "temperature": 0,
            };
            global_path.write_text(_json.dumps(existing, indent=2) + "\n", encoding="utf-8");
            print(f"Provider '{name}' added. Use with: graphify extract . --backend {name}");
        } elif subcmd == "remove" {
            name = sys.argv[3] if len(sys.argv) > 3 else "";
            if not name {
                print("Usage: graphify provider remove <name>", file=sys.stderr);
                sys.exit(1);
            }
            existing = {};
            if global_path.is_file() {
                try {
                    existing = _json.loads(global_path.read_text(encoding="utf-8"));
                } except Exception {}
            }
            if name not in existing {
                print(f"Provider '{name}' not found.", file=sys.stderr);
                sys.exit(1);
            }
            del existing[name];
            global_path.write_text(_json.dumps(existing, indent=2) + "\n", encoding="utf-8");
            print(f"Provider '{name}' removed.");
        } else {
            print("Usage: graphify provider [add|list|show|remove]", file=sys.stderr);
            if subcmd {
                sys.exit(1);
            }
        }
    } elif cmd == "prs" {
        cmd_prs: any = importlib.import_module("graphify.prs").cmd_prs;
        cmd_prs(sys.argv[2:]);
    } elif cmd == "hook" {
        hook_install: any = importlib.import_module("graphify.hooks").install;
        hook_uninstall: any = importlib.import_module("graphify.hooks").uninstall;
        hook_status: any = importlib.import_module("graphify.hooks").status;

        subcmd = sys.argv[2] if len(sys.argv) > 2 else "";
        if subcmd == "install" {
            print(hook_install(Path(".")));
        } elif subcmd == "uninstall" {
            print(hook_uninstall(Path(".")));
        } elif subcmd == "status" {
            print(hook_status(Path(".")));
        } else {
            print("Usage: graphify hook [install|uninstall|status]", file=sys.stderr);
            sys.exit(1);
        }
    } elif cmd == "query" {
        _query_usage: any = "Usage: graphify query \"<question>\" [--dfs] [--no-doc-demotion] [--context C] [--seed X] [--budget N] [--depth N] [--graph path]";
        if len(sys.argv) < 3 {
            print(_query_usage, file=sys.stderr);
            sys.exit(1);
        }
        if len(sys.argv) == 3 and sys.argv[2] in ("--help", "-h") {
            print(_query_usage);
            return;
        }
        _QUERY_NO_MATCH: any = importlib.import_module("graphify.serve")._QUERY_NO_MATCH;
        _is_ambiguity_refusal: any = importlib.import_module(
            "graphify.serve"
        )._is_ambiguity_refusal;
        _query_graph_text: any = importlib.import_module("graphify.serve")._query_graph_text;
        sanitize_label: any = importlib.import_module("graphify.security").sanitize_label;
        import from networkx.readwrite { json_graph }
        querylog: any = importlib.import_module("graphify.querylog");

        question: any = sys.argv[2];
        use_dfs: any = "--dfs" in sys.argv;
        demote_docs_flag: bool | None = None;
        if "--no-doc-demotion" in sys.argv or "--no-demote-docs" in sys.argv {
            demote_docs_flag = False;
        } elif "--demote-docs" in sys.argv or "--doc-demotion" in sys.argv {
            demote_docs_flag = True;
        }
        budget: int | None = None;
        depth: int | None = None;
        graph_path: any = _default_graph_path();
        context_filters: list[str] = [];
        seeds: list[str] = [];
        args = sys.argv[3:];
        i = 0;
        while i < len(args) {
            if args[i] in ("--no-doc-demotion", "--no-demote-docs") {
                demote_docs_flag = False;
                i += 1;
            } elif args[i] in ("--demote-docs", "--doc-demotion") {
                demote_docs_flag = True;
                i += 1;
            } elif args[i] == "--budget" and i + 1 < len(args) {
                try {
                    budget = `int(args[i + 1]);
                } except ValueError {
                    print(f"error: --budget must be an integer", file=sys.stderr);
                    sys.exit(1);
                }
                i += 2;
            } elif args[i].startswith("--budget=") {
                try {
                    budget = `int(args[i].split("=", 1)[1]);
                } except ValueError {
                    print(f"error: --budget must be an integer", file=sys.stderr);
                    sys.exit(1);
                }
                i += 1;
            } elif args[i] == "--depth" or args[i].startswith("--depth=") {
                if args[i] == "--depth" {
                    if i + 1 >= len(args) {
                        print("error: --depth needs an integer from 1 to 6", file=sys.stderr);
                        sys.exit(1);
                    }
                    raw_depth: any = args[i + 1];
                    i += 2;
                } else {
                    raw_depth = args[i].split("=", 1)[1];
                    i += 1;
                }
                try {
                    depth = `int(raw_depth);
                    if not 1 <= depth <= 6 {
                        raise ValueError("out of range");
                    }
                } except ValueError {
                    print("error: --depth must be an integer from 1 to 6", file=sys.stderr);
                    sys.exit(1);
                }
            } elif args[i] == "--context" and i + 1 < len(args) {
                context_filters.append(args[i + 1]);
                i += 2;
            } elif args[i].startswith("--context=") {
                context_filters.append(args[i].split("=", 1)[1]);
                i += 1;
            } elif args[i] == "--seed" and i + 1 < len(args) {
                seeds.append(args[i + 1]);
                i += 2;
            } elif args[i].startswith("--seed=") and args[i].split("=", 1)[1] {
                seeds.append(args[i].split("=", 1)[1]);
                i += 1;
            } elif args[i] == "--seed" or args[i] == "--seed=" {
                print("error: --seed needs a value (node id, label or file path)", file=sys.stderr);
                sys.exit(1);
            } elif args[i] == "--graph" and i + 1 < len(args) {
                graph_path = args[i + 1];
                i += 2;
            } else {
                i += 1;
            }
        }
        gp: any = Path(graph_path).resolve();
        if not gp.exists() {
            print(f"error: graph file not found: {gp}", file=sys.stderr);
            sys.exit(1);
        }
        if not gp.suffix == ".json" {
            print(f"error: graph file must be a .json file", file=sys.stderr);
            sys.exit(1);
        }
        _enforce_graph_size_cap_or_exit(gp);
        try {
            import json as _json;
            import networkx as _nx;

            consumed_graph_rows: any = importlib.import_module(
                "graphify.paths"
            ).consumed_graph_rows;
            read_graph_json: any = importlib.import_module("graphify.paths").read_graph_json;
            _raw: any = read_graph_json(gp);
            if "links" not in _raw and "edges" in _raw {
                _raw = `dict(_raw, links=_raw["edges"]);
            }
            try {
                _legacy: any = importlib.import_module("graphify.build").graph_has_legacy_ids;
                _legacy_prefix: any = importlib.import_module(
                    "graphify.build"
                ).legacy_id_source_prefix;
                _legacy_ids: any = _legacy(_raw.get("nodes", []), source_prefix=_legacy_prefix(gp));
            } except Exception {
                _legacy_ids = False;
            }
            _rows: any = consumed_graph_rows(`dict(_raw, links=_raw.get("links", [])));
            del _raw;
            G = json_graph.node_link_graph(_rows, edges="links");
            try {
                if _legacy_ids {
                    print(
                        "[graphify] note: this graph uses the pre-#1504 node-ID scheme; rebuild with `graphify extract --force` to get path-qualified IDs (fixes same-name-file collisions).",
                        file=sys.stderr,
                    );
                }
            } except Exception {}
        } except Exception as exc {
            print(f"error: could not load graph: {exc}", file=sys.stderr);
            sys.exit(1);
        }
        RC_FILENAME: any = importlib.import_module("graphify.rcfile").RC_FILENAME;
        load_graphifyrc: any = importlib.import_module("graphify.rcfile").load_graphifyrc;

        graph_root: any = _graph_root_for(gp);
        try {
            project_settings: any = load_graphifyrc(graph_root);
        } except (ValueError, OSError) as exc {
            print(
                f"warning: ignoring project settings in {graph_root / RC_FILENAME}: {exc}",
                file=sys.stderr,
            );
            project_settings = {};
        }
        effective_budget: any = budget
            if budget is not None
            else project_settings.get("query_budget", 2000);
        effective_depth: any = depth
            if depth is not None
            else project_settings.get("query_depth", 2);
        effective_demote_docs: any = demote_docs_flag
            if demote_docs_flag is not None
            else project_settings.get(
                "demote_docs", project_settings.get("query_demote_docs", True)
            );

        import time as _time;
        _t0: any = _time.perf_counter();
        _mode: any = "dfs" if use_dfs else "bfs";
        G._graphify_one_shot_query = not seeds and G.graph.get("_trigram_index") is None;
        _result: any = _query_graph_text(
            G,
            question,
            mode=_mode,
            depth=effective_depth,
            token_budget=effective_budget,
            context_filters=context_filters,
            graph_path=`str(gp),
            seeds=seeds or None,
            seed_root=graph_root,
            demote_docs=effective_demote_docs,
        );
        querylog.log_query(
            kind="query",
            question=question,
            corpus=`str(gp),
            result=_result,
            mode=_mode,
            depth=effective_depth,
            token_budget=effective_budget,
            duration_ms=(_time.perf_counter() - _t0) * 1000,
            seeds=seeds or None,
            demote_docs=effective_demote_docs,
        );
        _touch_query_stamp(gp);
        print(_result);
        if _is_ambiguity_refusal(_result) {
            sys.exit(EXIT_AMBIGUOUS);
        }
        if _result == _QUERY_NO_MATCH or _result.startswith("No unique node match for --seed:") {
            sys.exit(EXIT_NOT_FOUND);
        }
    } elif cmd == "affected" {
        if len(sys.argv) < 3 {
            print(
                "Usage: graphify affected \"<node-or-label>\" [--relation R] [--depth N] [--graph path]",
                file=sys.stderr,
            );
            sys.exit(1);
        }
        DEFAULT_AFFECTED_RELATIONS: any = importlib.import_module(
            "graphify.affected"
        ).DEFAULT_AFFECTED_RELATIONS;
        format_affected: any = importlib.import_module("graphify.affected").format_affected;
        load_graph: any = importlib.import_module("graphify.affected").load_graph;
        resolve_seed_outcome: any = importlib.import_module(
            "graphify.affected"
        ).resolve_seed_outcome;
        query: any = sys.argv[2];
        graph_path = _default_graph_path();
        depth = 2;
        relations: list[str] = [];
        args = sys.argv[3:];
        i = 0;
        while i < len(args) {
            if args[i] == "--graph" and i + 1 < len(args) {
                graph_path = args[i + 1];
                i += 2;
            } elif args[i].startswith("--graph=") {
                graph_path = args[i].split("=", 1)[1];
                i += 1;
            } elif args[i] == "--depth" and i + 1 < len(args) {
                try {
                    depth = `int(args[i + 1]);
                } except ValueError {
                    print("error: --depth must be an integer", file=sys.stderr);
                    sys.exit(1);
                }
                i += 2;
            } elif args[i].startswith("--depth=") {
                try {
                    depth = `int(args[i].split("=", 1)[1]);
                } except ValueError {
                    print("error: --depth must be an integer", file=sys.stderr);
                    sys.exit(1);
                }
                i += 1;
            } elif args[i] == "--relation" and i + 1 < len(args) {
                relations.append(args[i + 1]);
                i += 2;
            } elif args[i].startswith("--relation=") {
                relations.append(args[i].split("=", 1)[1]);
                i += 1;
            } else {
                i += 1;
            }
        }
        gp = Path(graph_path).resolve();
        if not gp.exists() {
            print(f"error: graph file not found: {gp}", file=sys.stderr);
            sys.exit(1);
        }
        if not gp.suffix == ".json" {
            print("error: graph file must be a .json file", file=sys.stderr);
            sys.exit(1);
        }
        try {
            `graph: any = load_graph(gp);
        } except Exception as exc {
            print(f"error: could not load graph: {exc}", file=sys.stderr);
            sys.exit(1);
        }
        GRAPHIFY_OUT_NAME: any = importlib.import_module("graphify.paths").GRAPHIFY_OUT_NAME;
        graph_root = gp.parent.parent if gp.parent.name == GRAPHIFY_OUT_NAME else gp.parent;
        seed: any;
        rivals: any;
        (seed, rivals) = resolve_seed_outcome(`graph, query, graph_root) as any;
        if seed is None {
            if rivals {
                _ambiguity_message: any = importlib.import_module(
                    "graphify.serve"
                )._ambiguity_message;

                print(_ambiguity_message(`graph, query, rivals), file=sys.stderr);
                sys.exit(EXIT_AMBIGUOUS);
            }
            print(f"No unique node match for {query}", file=sys.stderr);
            sys.exit(EXIT_NOT_FOUND);
        }
        print(
            format_affected(
                `graph,
                query,
                relations=relations or DEFAULT_AFFECTED_RELATIONS,
                depth=depth,
                root=graph_root,
                seed=seed,
            ),
        );
    } elif cmd in ("god-nodes", "god_nodes") {
        load_graph: any = importlib.import_module("graphify.affected").load_graph;
        god_nodes: any = importlib.import_module("graphify.analyze").god_nodes;
        sanitize_label: any = importlib.import_module("graphify.security").sanitize_label;
        graph_path = _default_graph_path();
        top_n: any = 10;
        gn_exclude_hubs: float | None = None;
        as_json: any = "--json" in sys.argv;
        args = sys.argv[2:];
        i = 0;
        while i < len(args) {
            if args[i] == "--graph" and i + 1 < len(args) {
                graph_path = args[i + 1];
                i += 2;
            } elif args[i].startswith("--graph=") {
                graph_path = args[i].split("=", 1)[1];
                i += 1;
            } elif args[i] == "--top" and i + 1 < len(args) {
                try {
                    top_n = `int(args[i + 1]);
                } except ValueError {
                    print("error: --top must be an integer", file=sys.stderr);
                    sys.exit(1);
                }
                i += 2;
            } elif args[i].startswith("--top=") {
                try {
                    top_n = `int(args[i].split("=", 1)[1]);
                } except ValueError {
                    print("error: --top must be an integer", file=sys.stderr);
                    sys.exit(1);
                }
                i += 1;
            } elif args[i] == "--exclude-hubs" and i + 1 < len(args) {
                try {
                    gn_exclude_hubs = `float(args[i + 1]);
                } except ValueError {
                    print(
                        "error: --exclude-hubs must be a number (percentile 0-100)", file=sys.stderr
                    );
                    sys.exit(1);
                }
                i += 2;
            } elif args[i].startswith("--exclude-hubs=") {
                try {
                    gn_exclude_hubs = `float(args[i].split("=", 1)[1]);
                } except ValueError {
                    print(
                        "error: --exclude-hubs must be a number (percentile 0-100)", file=sys.stderr
                    );
                    sys.exit(1);
                }
                i += 1;
            } else {
                i += 1;
            }
        }
        gp = Path(graph_path).resolve();
        if not gp.exists() {
            print(f"error: graph file not found: {gp}", file=sys.stderr);
            sys.exit(1);
        }
        if not gp.suffix == ".json" {
            print("error: graph file must be a .json file", file=sys.stderr);
            sys.exit(1);
        }
        try {
            G = load_graph(gp);
        } except Exception as exc {
            print(f"error: could not load graph: {exc}", file=sys.stderr);
            sys.exit(1);
        }
        gods: any = god_nodes(G, top_n=top_n, exclude_hubs_percentile=gn_exclude_hubs);
        if as_json {
            print(json.dumps(gods, indent=2));
        } else {
            print("God nodes (most connected):");
            n: any;
            for (rank, n) in enumerate(gods, 1) {
                print(
                    "  "
                        + format(rank, "")
                        + ". "
                        + format(sanitize_label(`str(n["label"])), "")
                        + " - "
                        + format(n["degree"], "")
                        + " edges",
                );
            }
        }
    } elif cmd == "save-result" {
        import argparse as _ap;

        p: any = _ap.ArgumentParser(prog="graphify save-result");
        p.add_argument("--question", required=True);
        p.add_argument("--answer", default=None);
        p.add_argument("--answer-file", dest="answer_file", default=None);
        p.add_argument("--type", dest="query_type", default="query");
        p.add_argument("--nodes", nargs="*", default=[]);
        p.add_argument("--outcome", choices=("useful", "dead_end", "corrected"), default=None);
        p.add_argument("--correction", default=None);
        p.add_argument("--memory-dir", default=`str(Path(_GRAPHIFY_OUT) / "memory"));
        opts: any = p.parse_args(sys.argv[2:]);
        if opts.answer_file {
            opts.answer = Path(opts.answer_file).read_text(encoding="utf-8").strip();
        } elif not opts.answer {
            p.error("--answer or --answer-file is required");
        }
        _sqr: any = importlib.import_module("graphify.ingest").save_query_result;

        out: any = _sqr(
            question=opts.question,
            answer=opts.answer,
            memory_dir=Path(opts.memory_dir),
            query_type=opts.query_type,
            source_nodes=opts.nodes or None,
            outcome=opts.outcome,
            correction=opts.correction,
        );
        print(f"Saved to {out}");
    } elif cmd == "reflect" {
        import argparse as _ap;

        p = _ap.ArgumentParser(prog="graphify reflect");
        p.add_argument("--memory-dir", default=`str(Path(_GRAPHIFY_OUT) / "memory"));
        p.add_argument("--out", default=`str(Path(_GRAPHIFY_OUT) / "reflections" / "LESSONS.md"));
        p.add_argument("--graph", default=None);
        p.add_argument("--analysis", default=None);
        p.add_argument("--labels", default=None);
        p.add_argument(
            "--half-life-days",
            type=float,
            default=30.0,
            help="signal weight halves every N days (default 30)",
        );
        p.add_argument(
            "--min-corroboration",
            type=int,
            default=2,
            help="distinct useful results to promote a node to preferred (default 2)",
        );
        p.add_argument(
            "--if-stale",
            action="store_true",
            help="skip when LESSONS.md is already newer than every input (e.g. the git hook just refreshed it)",
        );
        opts = p.parse_args(sys.argv[2:]);
        _reflect: any = importlib.import_module("graphify.reflect").reflect;
        _lessons_fresh: any = importlib.import_module("graphify.reflect").lessons_fresh;

        graph_arg: any = opts.graph;
        if graph_arg is None {
            default_graph: any = Path(_GRAPHIFY_OUT) / "graph.json";
            if default_graph.exists() {
                graph_arg = `str(default_graph);
            }
        }

        _gp: any = Path(graph_arg) if graph_arg else None;
        _analysis_path: any = None;
        _labels_path: any = None;
        if _gp is not None {
            _analysis_path = Path(opts.analysis)
                if opts.analysis
                else _gp.parent / ".graphify_analysis.json";
            _labels_path = Path(opts.labels)
                if opts.labels
                else _gp.parent / ".graphify_labels.json";
        }

        if opts.if_stale
            and _lessons_fresh(
                Path(opts.out), Path(opts.memory_dir), _gp, _analysis_path, _labels_path
            )
        {
            print(f"Lessons already up to date -> {opts.out} (skipped; omit --if-stale to force)");
        } else {
            out_path: Path | None;
            agg: any;
            (out_path, agg) = _reflect(
                memory_dir=Path(opts.memory_dir),
                out_path=Path(opts.out),
                graph_path=_gp,
                analysis_path=_analysis_path,
                labels_path=_labels_path,
                half_life_days=opts.half_life_days,
                min_corroboration=opts.min_corroboration,
            ) as any;
            c: any = agg["counts"];
            print(
                "Reflected "
                    + format(agg["total"], "")
                    + " memories ("
                    + format(c["useful"], "")
                    + " useful, "
                    + format(c["dead_end"], "")
                    + " dead ends, "
                    + format(c["corrected"], "")
                    + " corrected) -> "
                    + format(out_path, ""),
            );
        }
    } elif cmd == "path" {
        if len(sys.argv) < 4 {
            print(
                "Usage: graphify path \"<source>\" \"<target>\" [--graph path] [--directed|--undirected]",
                file=sys.stderr,
            );
            sys.exit(1);
        }
        _confidence_tag: any = importlib.import_module("graphify.serve")._confidence_tag;
        _is_ambiguity_refusal: any = importlib.import_module(
            "graphify.serve"
        )._is_ambiguity_refusal;
        _resolve_path_endpoint: any = importlib.import_module(
            "graphify.serve"
        )._resolve_path_endpoint;
        import from networkx.readwrite { json_graph }
        import from networkx { NetworkXNoPath, NodeNotFound }
        import networkx as _nx;

        source_label: any = sys.argv[2];
        target_label: any = sys.argv[3];
        graph_path = _default_graph_path();
        args = sys.argv[4:];
        direction_flag: str | None = None;
        for (i, a) in enumerate(args) {
            if a == "--graph" and i + 1 < len(args) {
                graph_path = args[i + 1];
            } elif a == "--directed" {
                if direction_flag == "undirected" {
                    print(
                        "error: --directed and --undirected are mutually exclusive", file=sys.stderr
                    );
                    sys.exit(1);
                }
                direction_flag = "directed";
            } elif a == "--undirected" {
                if direction_flag == "directed" {
                    print(
                        "error: --directed and --undirected are mutually exclusive", file=sys.stderr
                    );
                    sys.exit(1);
                }
                direction_flag = "undirected";
            }
        }
        undirected: any = operator.eq(direction_flag, "undirected");
        gp = Path(graph_path).resolve();
        if not gp.exists() {
            print(f"error: graph file not found: {gp}", file=sys.stderr);
            sys.exit(1);
        }
        _enforce_graph_size_cap_or_exit(gp);
        consumed: any = importlib.import_module("graphify.paths").consumed;
        read_graph_json: any = importlib.import_module("graphify.paths").read_graph_json;
        _raw = read_graph_json(gp);
        if "links" not in _raw and "edges" in _raw {
            _raw = `dict(_raw, links=_raw["edges"]);
        }
        _raw = {**_raw, "directed": True, "multigraph": True};
        _raw = `dict(_raw, nodes=consumed(_raw["nodes"]), links=consumed(_raw["links"]));
        G = json_graph.node_link_graph(_raw, edges="links");
        src_nid: any;
        src_scored: any;
        src_err: any;
        (src_nid, src_scored, src_err) = _resolve_path_endpoint(G, source_label) as any;
        tgt_nid: any;
        tgt_scored: any;
        tgt_err: any;
        (tgt_nid, tgt_scored, tgt_err) = _resolve_path_endpoint(G, target_label) as any;
        _nid: any;
        for (_label, _nid, _err) in (
            (source_label, src_nid, src_err),
            (target_label, tgt_nid, tgt_err),
        ) {
            if _err or _nid is None {
                print(_err or f"No node matching '{_label}' found.", file=sys.stderr);
                sys.exit(EXIT_AMBIGUOUS if _is_ambiguity_refusal(_err) else EXIT_NOT_FOUND);
            }
        }
        if src_nid == tgt_nid {
            print(
                f"'{source_label}' and '{target_label}' both resolved to the same node '{src_nid}'. Use a more specific label or the exact node ID.",
                file=sys.stderr,
            );
            sys.exit(EXIT_AMBIGUOUS);
        }
        for (_name, _scored, _nid) in (
            ("source", src_scored, src_nid),
            ("target", tgt_scored, tgt_nid),
        ) {
            if len(_scored) >= 2 and _nid == _scored[0][1] {
                _top: any;
                _runner: any;
                (_top, _runner) = (_scored[0][0], _scored[1][0]);
                if _top > 0 and (_top - _runner) / _top < 0.1 {
                    print(
                        f"warning: {_name} match was ambiguous (top score {_top:g}, runner-up {_runner:g})",
                        file=sys.stderr,
                    );
                }
            }
        }
        _weakest_shortest_path: any = importlib.import_module(
            "graphify.serve"
        )._weakest_shortest_path;
        try {
            if undirected {
                _und: any = _nx.Graph();
                _und.add_nodes_from(sorted(G.nodes));
                _und.add_edges_from(sorted((min(u, v), max(u, v)) for (u, v) in G.edges()));
                path_nodes: any;
                _n_routes: any;
                _routes_capped: any;
                (path_nodes, _n_routes, _routes_capped) = _weakest_shortest_path(
                    _und, G, src_nid, tgt_nid
                ) as any;
            } else {
                _dg: any = _nx.DiGraph();
                _dg.add_nodes_from(sorted(G.nodes));
                _dg.add_edges_from(
                    sorted((d.get("_src", u), d.get("_tgt", v)) for (u, v, d) in G.edges(data=True))
                );
                _dg.add_edges_from(
                    sorted(
                        (d.get("_tgt", v), d.get("_src", u))
                        for (u, v, d) in G.edges(data=True)
                        if d.get("relation") == "contains",
                    ),
                );
                (path_nodes, _n_routes, _routes_capped) = _weakest_shortest_path(
                    _dg, G, src_nid, tgt_nid
                ) as any;
            }
        } except Exception as exc {
            if not isinstance(exc, (NetworkXNoPath, NodeNotFound)) {
                raise;
            }
            if undirected {
                print(f"No path found between '{source_label}' and '{target_label}'.");
            } else {
                print(
                    f"No directed path found between '{source_label}' and '{target_label}'. Re-run with --undirected to search ignoring edge direction.",
                );
            }
            sys.exit(0);
        }
        hops: any = len(path_nodes) - 1;
        segments: any = [];
        hop_datas: list[list[dict]] = [];
        edge_datas: any = importlib.import_module("graphify.build").edge_datas;
        edge_evidence: any = importlib.import_module("graphify.build").edge_evidence;
        _path_confidence_line: any = importlib.import_module(
            "graphify.serve"
        )._path_confidence_line;
        for i in range(len(path_nodes) - 1) {
            (u, v) = (path_nodes[i], path_nodes[i + 1]);
            fwd: any;
            bwd: any;
            (fwd, bwd) = ([], []);
            for (a, b) in ((u, v), (v, u)) {
                if G.has_edge(a, b) {
                    for d in edge_datas(G, a, b) {
                        (fwd if d.get("_src", a) == u else bwd).append(d);
                    }
                }
            }
            datas: any = fwd or bwd;
            hop_datas.append(datas);
            forward: any = `bool(fwd);
            rels: any = sorted({d.get("relation") for d in datas if d.get("relation")});
            rel: any = "/".join(rels) if rels else "related";
            confs: any = sorted({
                _confidence_tag(e)
                for d in datas
                for e in edge_evidence(d)
                if e.get("confidence")
            });
            conf_str: any = " [" + format("/".join(confs), "") + "]" if confs else "";
            if i == 0 {
                segments.append(G.nodes[u].get("label", u));
            }
            if forward {
                segments.append(
                    "--"
                        + format(rel, "")
                        + format(conf_str, "")
                        + "--> "
                        + format(G.nodes[v].get("label", v), ""),
                );
            } else {
                segments.append(
                    "<--"
                        + format(rel, "")
                        + format(conf_str, "")
                        + "-- "
                        + format(G.nodes[v].get("label", v), ""),
                );
            }
        }
        print(f"Shortest path ({hops} hops):\n  " + " ".join(segments));
        _summary: any = _path_confidence_line(hop_datas);
        if _summary and _n_routes > 1 {
            _summary += " (weakest of "
                + format("256+" if _routes_capped else _n_routes, "")
                + " equal-length routes)";
        }
        if _summary {
            print(_summary);
        }
        querylog: any = importlib.import_module("graphify.querylog");
        querylog.log_query(
            kind="path",
            question=f"{sys.argv[2]} -> {sys.argv[3]}",
            corpus=`str(gp),
            nodes_returned=hops,
        );
        _touch_query_stamp(gp);
    } elif cmd == "explain" {
        _explain_usage: any = "Usage: graphify explain \"<node>\" [--all] [--graph path]";
        if len(sys.argv) < 3 {
            print(_explain_usage, file=sys.stderr);
            sys.exit(1);
        }
        if len(sys.argv) == 3 and sys.argv[2] in ("--help", "-h") {
            print(_explain_usage);
            return;
        }
        _confidence_tag: any = importlib.import_module("graphify.serve")._confidence_tag;
        _is_ambiguity_refusal: any = importlib.import_module(
            "graphify.serve"
        )._is_ambiguity_refusal;
        _resolve_single_node: any = importlib.import_module("graphify.serve")._resolve_single_node;

        label: any = sys.argv[2];
        graph_path = _default_graph_path();
        args = sys.argv[3:];
        show_all: any = "--all" in args;
        for (i, a) in enumerate(args) {
            if a == "--graph" and i + 1 < len(args) {
                graph_path = args[i + 1];
            }
        }
        gp = Path(graph_path).resolve();
        G = _load_cli_graph(gp);
        nid: any;
        refusal: any;
        (nid, refusal) = _resolve_single_node(G, label) as any;
        if nid is None {
            print(refusal);
            sys.exit(EXIT_AMBIGUOUS if _is_ambiguity_refusal(refusal) else EXIT_NOT_FOUND);
        }
        d = G.nodes[nid];
        print("Node: " + format(d.get("label", nid), ""));
        print(f"  ID:        {nid}");
        print(
            (
                "  Source:    "
                + format(d.get("source_file", ""), "")
                + " "
                + format(d.get("source_location", ""), "")
            ).rstrip(),
        );
        print("  Type:      " + format(d.get("file_type", ""), ""));
        print("  Community: " + format(d.get("community_name") or d.get("community", ""), ""));
        try {
            _llo: any = importlib.import_module("graphify.reflect").load_learning_overlay;
            sanitize_label: any = importlib.import_module("graphify.security").sanitize_label;
            _overlay: any = _llo(gp);
            _entry: any = _overlay.get(`str(nid));
            if _entry {
                _status: any = sanitize_label(`str(_entry.get("status", "")));
                if _status == "contested" {
                    _line: any = "  Lesson: contested (useful "
                        + format(_entry.get("uses", 0), "")
                        + " / dead-end "
                        + format(_entry.get("neg", 0), "")
                        + ")";
                } elif _status == "preferred" {
                    _line = "  Lesson: preferred source (start here) — "
                        + format(_entry.get("uses", 0), "")
                        + " useful, score="
                        + format(_entry.get("score", 0), "");
                } else {
                    _line = "  Lesson: "
                        + format(_status or "tentative", "")
                        + " — "
                        + format(_entry.get("uses", 0), "")
                        + " useful, score="
                        + format(_entry.get("score", 0), "");
                }
                if _entry.get("stale") {
                    _line += " [code changed since — re-verify]";
                }
                print(_line);
            }
        } except Exception {}
        print(f"  Degree:    {G.degree(nid)}");
        edge_datas: any = importlib.import_module("graphify.build").edge_datas;
        connections: list[tuple[str, str, dict]] = [];
        nb: any;
        for nb in G.successors(nid) {
            _ed: any;
            for _ed in edge_datas(G, nid, nb) {
                connections.append(("out" if _ed.get("_src", nid) == nid else "in", nb, _ed));
            }
        }
        for nb in G.predecessors(nid) {
            for _ed in edge_datas(G, nb, nid) {
                connections.append(("in" if _ed.get("_src", nb) == nb else "out", nb, _ed));
            }
        }
        if connections {
            print(f"\nConnections ({len(connections)}):");
            connections.sort(key=lambda (c) -> any { G.degree(c[1]) }, reverse=True);
            shown: any = connections if show_all else connections[:20];
            direction: any;
            edata: any;
            for (direction, nb, edata) in shown {
                rel = edata.get("relation", "");
                conf: any = _confidence_tag(edata);
                arrow: any = "-->" if direction == "out" else "<--";
                loc: any = edata.get("source_location") or "";
                sfile: any = edata.get("source_file") or "";
                at: any = f" {sfile}:{loc}" if loc else "";
                print(
                    "  "
                        + format(arrow, "")
                        + " "
                        + format(G.nodes[nb].get("label", nb), "")
                        + " ["
                        + format(rel, "")
                        + "] ["
                        + format(conf, "")
                        + "]"
                        + format(at, ""),
                );
            }
            if len(connections) > len(shown) {
                remainder: any = connections[len(shown):];
                print(f"  ... and {len(remainder)} more (--all lists all {len(connections)})");
                by_file: dict[tuple[str, str], int] = {};
                for (direction, _nb, edata) in remainder {
                    sfile = edata.get("source_file") or "(unknown file)";
                    key: any = (direction, sfile);
                    by_file[key] = by_file.get(key, 0) + 1;
                }
                grouped: any = sorted(by_file.items(), key=lambda (kv) -> any { (-kv[1], kv[0]) });
                print("  Grouped by file:");
                for ((direction, sfile), count) in grouped[:20] {
                    arrow = "-->" if direction == "out" else "<--";
                    noun: any = "connection" if count == 1 else "connections";
                    print(f"    {arrow} {sfile}: {count} {noun}");
                }
                if len(grouped) > 20 {
                    print(f"    ... and {len(grouped) - 20} more files");
                }
            }
        }
        querylog: any = importlib.import_module("graphify.querylog");
        querylog.log_query(
            kind="explain", question=sys.argv[2], corpus=`str(gp), nodes_returned=len(connections)
        );
        _touch_query_stamp(gp);
    } elif cmd == "section" {
        _section_usage: any = "Usage: graphify section \"<heading>\" | \"path/file.md#<heading>\" [--max-chars N] [--graph path]";
        if len(sys.argv) < 3 {
            print(_section_usage, file=sys.stderr);
            sys.exit(1);
        }
        if len(sys.argv) == 3 and sys.argv[2] in ("--help", "-h") {
            print(_section_usage);
            return;
        }
        _is_ambiguity_refusal: any = importlib.import_module(
            "graphify.serve"
        )._is_ambiguity_refusal;
        DEFAULT_MAX_CHARS: any = importlib.import_module("graphify.sections").DEFAULT_MAX_CHARS;
        format_section: any = importlib.import_module("graphify.sections").format_section;
        read_section: any = importlib.import_module("graphify.sections").read_section;
        resolve_section_query: any = importlib.import_module(
            "graphify.sections"
        ).resolve_section_query;
        section_root: any = importlib.import_module("graphify.sections").section_root;

        label = sys.argv[2];
        graph_path = _default_graph_path();
        max_chars: any = DEFAULT_MAX_CHARS;
        args = sys.argv[3:];
        for (i, a) in enumerate(args) {
            if a == "--graph" and i + 1 < len(args) {
                graph_path = args[i + 1];
            } elif a == "--max-chars" and i + 1 < len(args) {
                try {
                    max_chars = max(1, `int(args[i + 1]));
                } except ValueError {
                    print(
                        f"error: --max-chars needs an integer, got {args[i + 1]!r}", file=sys.stderr
                    );
                    sys.exit(1);
                }
            }
        }
        gp = Path(graph_path).resolve();
        G = _load_cli_graph(gp);
        (nid, refusal) = resolve_section_query(G, label) as any;
        if nid is None {
            print(refusal);
            sys.exit(EXIT_AMBIGUOUS if _is_ambiguity_refusal(refusal) else EXIT_NOT_FOUND);
        }
        d = G.nodes[nid];
        section: any;
        reason: any;
        (section, reason) = read_section(d, section_root(gp), max_chars) as any;
        if section is None {
            print(reason, file=sys.stderr);
            sys.exit(1);
        }
        print(format_section(section, `str(d.get("label", nid))));
        querylog: any = importlib.import_module("graphify.querylog");
        querylog.log_query(kind="section", question=label, corpus=`str(gp), nodes_returned=1);
        _touch_query_stamp(gp);
    } elif cmd == "diagnose" {
        subcmd = sys.argv[2] if len(sys.argv) > 2 else "";
        if subcmd != "multigraph" {
            print(
                "Usage: graphify diagnose multigraph [--graph path] [--json] [--max-examples N] [--directed] [--undirected] [--extract-path path]",
                file=sys.stderr,
            );
            sys.exit(1);
        }

        graph_path = Path(_default_graph_path());
        max_examples: any = 5;
        directed: bool | None = None;
        direction_flag = None;
        json_output: any = False;
        extract_path: Path | None = None;

        i = 3;
        while i < len(sys.argv) {
            arg: any = sys.argv[i];
            if arg == "--graph" {
                i += 1;
                if i >= len(sys.argv) {
                    print("error: --graph requires a path", file=sys.stderr);
                    sys.exit(1);
                }
                graph_path = Path(sys.argv[i]);
            } elif arg == "--json" {
                json_output = True;
            } elif arg == "--max-examples" {
                i += 1;
                if i >= len(sys.argv) {
                    print("error: --max-examples requires an integer", file=sys.stderr);
                    sys.exit(1);
                }
                try {
                    max_examples = `int(sys.argv[i]);
                } except ValueError {
                    print("error: --max-examples requires an integer", file=sys.stderr);
                    sys.exit(1);
                }
                if max_examples < 0 {
                    print("error: --max-examples must be >= 0", file=sys.stderr);
                    sys.exit(1);
                }
            } elif arg == "--directed" {
                if direction_flag == "undirected" {
                    print(
                        "error: --directed and --undirected are mutually exclusive", file=sys.stderr
                    );
                    sys.exit(1);
                }
                direction_flag = "directed";
                directed = True;
            } elif arg == "--undirected" {
                if direction_flag == "directed" {
                    print(
                        "error: --directed and --undirected are mutually exclusive", file=sys.stderr
                    );
                    sys.exit(1);
                }
                direction_flag = "undirected";
                directed = False;
            } elif arg == "--extract-path" {
                i += 1;
                if i >= len(sys.argv) {
                    print("error: --extract-path requires a path", file=sys.stderr);
                    sys.exit(1);
                }
                extract_path = Path(sys.argv[i]);
            } else {
                print(f"error: unknown diagnose option {arg}", file=sys.stderr);
                sys.exit(1);
            }
            i += 1;
        }

        diagnose_file: any = importlib.import_module("graphify.diagnostics").diagnose_file;
        format_diagnostic_json: any = importlib.import_module(
            "graphify.diagnostics"
        ).format_diagnostic_json;
        format_diagnostic_report: any = importlib.import_module(
            "graphify.diagnostics"
        ).format_diagnostic_report;

        try {
            summary: any = diagnose_file(
                graph_path,
                directed=directed,
                root=Path(".").resolve(),
                max_examples=max_examples,
                extract_path=extract_path,
            );
        } except Exception as exc {
            print(f"error: {exc}", file=sys.stderr);
            sys.exit(1);
        }

        if json_output {
            print(json.dumps(format_diagnostic_json(summary), indent=2));
        } else {
            print(format_diagnostic_report(summary));
        }
    } elif cmd == "add" {
        if len(sys.argv) < 3 {
            print(
                "Usage: graphify add <url> [--author Name] [--contributor Name] [--dir ./raw]",
                file=sys.stderr,
            );
            sys.exit(1);
        }
        _ingest: any = importlib.import_module("graphify.ingest").ingest;

        url: any = sys.argv[2];
        author: str | None = None;
        contributor: str | None = None;
        target_dir: any = Path("raw");
        args = sys.argv[3:];
        i = 0;
        while i < len(args) {
            if args[i] == "--author" and i + 1 < len(args) {
                author = args[i + 1];
                i += 2;
            } elif args[i] == "--contributor" and i + 1 < len(args) {
                contributor = args[i + 1];
                i += 2;
            } elif args[i] == "--dir" and i + 1 < len(args) {
                target_dir = Path(args[i + 1]);
                i += 2;
            } else {
                i += 1;
            }
        }
        try {
            saved: any = _ingest(url, target_dir, author=author, contributor=contributor);
            print(f"Saved to {saved}");
            print("Run /graphify --update in your AI assistant to update the graph.");
        } except Exception as exc {
            print(f"error: {exc}", file=sys.stderr);
            sys.exit(1);
        }
    } elif cmd == "watch" {
        watch_path: Path | None = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(".");
        if not watch_path.exists() {
            print(f"error: path not found: {watch_path}", file=sys.stderr);
            sys.exit(1);
        }
        _watch: any = importlib.import_module("graphify.watch").watch;

        try {
            _watch(watch_path);
        } except ImportError as exc {
            print(f"error: {exc}", file=sys.stderr);
            sys.exit(1);
        }
    } elif cmd in ("cluster-only", "label") {
        force_relabel: any = operator.eq(cmd, "label");
        no_viz: any = "--no-viz" in sys.argv;
        no_label: any = "--no-label" in sys.argv;
        missing_only: any = "--missing-only" in sys.argv;
        co_timing: any = "--timing" in sys.argv;
        _backend_arg: any = next((a for a in sys.argv if a.startswith("--backend=")), None);
        label_backend: any = _backend_arg.split("=", 1)[1] if _backend_arg else None;
        _model_arg: any = next((a for a in sys.argv if a.startswith("--model=")), None);
        label_model: any = _model_arg.split("=", 1)[1] if _model_arg else None;
        _min_cs_arg: any = next(
            (a for a in sys.argv if a.startswith("--min-community-size=")), None
        );
        min_community_size: any = `int(_min_cs_arg.split("=")[1]) if _min_cs_arg else 3;
        args = sys.argv[2:];
        watch_path = None;
        graph_override: Path | None = None;
        co_resolution: float = 1.0;
        co_exclude_hubs: float | None = None;
        label_max_concurrency: int = 4;
        label_batch_size: int = 100;
        label_max_concurrency_explicit: any = False;
        label_batch_size_explicit: any = False;
        i_arg: any = 0;
        while i_arg < len(args) {
            a = args[i_arg];
            if a == "--graph" and i_arg + 1 < len(args) {
                graph_override = Path(args[i_arg + 1]);
                i_arg += 2;
            } elif a == "--backend" and i_arg + 1 < len(args) {
                label_backend = args[i_arg + 1];
                i_arg += 2;
            } elif a.startswith("--backend=") {
                label_backend = a.split("=", 1)[1];
                i_arg += 1;
            } elif a == "--model" and i_arg + 1 < len(args) {
                label_model = args[i_arg + 1];
                i_arg += 2;
            } elif a.startswith("--model=") {
                label_model = a.split("=", 1)[1];
                i_arg += 1;
            } elif a == "--resolution" and i_arg + 1 < len(args) {
                co_resolution = `float(args[i_arg + 1]);
                i_arg += 2;
            } elif a.startswith("--resolution=") {
                co_resolution = `float(a.split("=", 1)[1]);
                i_arg += 1;
            } elif a == "--exclude-hubs" and i_arg + 1 < len(args) {
                co_exclude_hubs = `float(args[i_arg + 1]);
                i_arg += 2;
            } elif a.startswith("--exclude-hubs=") {
                co_exclude_hubs = `float(a.split("=", 1)[1]);
                i_arg += 1;
            } elif a == "--max-concurrency" and i_arg + 1 < len(args) {
                label_max_concurrency = `int(args[i_arg + 1]);
                label_max_concurrency_explicit = True;
                i_arg += 2;
            } elif a.startswith("--max-concurrency=") {
                label_max_concurrency = `int(a.split("=", 1)[1]);
                label_max_concurrency_explicit = True;
                i_arg += 1;
            } elif a == "--batch-size" and i_arg + 1 < len(args) {
                label_batch_size = `int(args[i_arg + 1]);
                label_batch_size_explicit = True;
                i_arg += 2;
            } elif a.startswith("--batch-size=") {
                label_batch_size = `int(a.split("=", 1)[1]);
                label_batch_size_explicit = True;
                i_arg += 1;
            } elif a in ("--no-viz", "--missing-only") or a.startswith("--min-community-size=") {
                i_arg += 1;
            } elif a.startswith("--") {
                i_arg += 1;
            } elif watch_path is None {
                watch_path = Path(a);
                i_arg += 1;
            } else {
                i_arg += 1;
            }
        }
        if watch_path is None {
            watch_path = Path(".");
        }
        graph_json: any = graph_override
            if graph_override is not None
            else watch_path / _GRAPHIFY_OUT / "graph.json";
        if not graph_json.exists() {
            print(f"error: no graph found at {graph_json} — run /graphify first", file=sys.stderr);
            sys.exit(1);
        }
        import from networkx.readwrite { json_graph as _jg }
        build_from_json: any = importlib.import_module("graphify.build").build_from_json;
        cluster: any = importlib.import_module("graphify.cluster").cluster;
        score_all: any = importlib.import_module("graphify.cluster").score_all;
        remap_communities_to_previous: any = importlib.import_module(
            "graphify.cluster"
        ).remap_communities_to_previous;
        god_nodes: any = importlib.import_module("graphify.analyze").god_nodes;
        surprising_connections: any = importlib.import_module(
            "graphify.analyze"
        ).surprising_connections;
        suggest_questions: any = importlib.import_module("graphify.analyze").suggest_questions;
        generate: any = importlib.import_module("graphify.report").generate;
        to_json: any = importlib.import_module("graphify.export").to_json;
        to_html: any = importlib.import_module("graphify.export").to_html;

        stages: any = _StageTimer(co_timing);
        print("Loading existing graph...");
        check_graph_file_size_cap: any = importlib.import_module(
            "graphify.security"
        ).check_graph_file_size_cap;
        try {
            check_graph_file_size_cap(graph_json);
        } except ValueError {
            try {
                _over_cap_bytes: any = graph_json.stat().st_size;
            } except OSError {
                _over_cap_bytes = -1;
            }
            print(
                f"warning: graph.json exceeds cap ({_over_cap_bytes} bytes); continuing with best-effort visualization",
                file=sys.stderr,
            );
        }
        _raw = json.loads(graph_json.read_text(encoding="utf-8"));
        _directed: any = `bool(_raw.get("directed", False));
        G = build_from_json(_raw, directed=_directed);
        print(f"Graph: {G.number_of_nodes()} nodes, {G.number_of_edges()} edges");
        stages.mark("load");
        print("Re-clustering...");
        communities: dict[int, list[str]] = cluster(
            G,
            resolution=co_resolution,
            exclude_hubs_percentile=co_exclude_hubs,
            cache_dir=graph_json.parent,
        );
        previous_node_community: any = {
            n["id"]: n["community"]
            for n in _raw.get("nodes", [])
            if n.get("community") is not None and n.get("id") is not None
        };
        if previous_node_community {
            communities = remap_communities_to_previous(communities, previous_node_community);
        }
        stages.mark("cluster");
        cohesion: dict[int, float] = score_all(G, communities);
        gods = god_nodes(G, exclude_hubs_percentile=co_exclude_hubs);
        surprises: any = surprising_connections(G, communities);
        stages.mark("analyze");
        _out_name: any = Path(_GRAPHIFY_OUT).name;
        if graph_override is not None and graph_json.parent.name == _out_name {
            out = graph_json.parent;
        } else {
            out = watch_path / _GRAPHIFY_OUT;
        }
        out.mkdir(parents=True, exist_ok=True);
        labels_path: any = out / ".graphify_labels.json";
        existing_labels: dict[int, str] = {};
        if labels_path.exists() {
            try {
                existing_labels = {
                    `int(k): v
                    for (k, v) in json.loads(labels_path.read_text(encoding="utf-8")).items()
                    if isinstance(v, `str)
                };
            } except Exception {
                existing_labels = {};
            }
        }
        label_token_usage: any = {"input": 0, "output": 0};
        placeholder_only: any = False;
        if labels_path.exists() and not force_relabel {
            _ignored_label_flags: any = [
                flag
                for (flag, given) in (
                    ("--backend", label_backend is not None),
                    ("--model", label_model is not None),
                    ("--batch-size", label_batch_size_explicit),
                    ("--max-concurrency", label_max_concurrency_explicit),
                )
                if given
            ];
            if _ignored_label_flags {
                print(
                    "[graphify] warning: "
                        + format("/".join(_ignored_label_flags), "")
                        + " ignored: reusing saved labels at "
                        + format(labels_path, "")
                        + ". Run `graphify label` to relabel, or delete the labels file.",
                    file=sys.stderr,
                );
            }
            community_member_sigs: any = importlib.import_module(
                "graphify.cluster"
            ).community_member_sigs;
            label_communities_by_hub: any = importlib.import_module(
                "graphify.cluster"
            ).label_communities_by_hub;
            label_still_applies: any = importlib.import_module(
                "graphify.cluster"
            ).label_still_applies;
            sig_path: any = labels_path.parent / (labels_path.name + ".sig");
            saved_sigs: dict[int, str] = {};
            if sig_path.exists() {
                try {
                    saved_sigs = {
                        `int(k): v
                        for (k, v) in json.loads(sig_path.read_text(encoding="utf-8")).items()
                        if isinstance(v, `str)
                    };
                } except Exception {
                    saved_sigs = {};
                }
            }
            cur_sigs: any = community_member_sigs(communities);
            count_mismatch: any = operator.ne(len(existing_labels), len(communities));
            labels: dict[int, str] = {};
            hub_labels: dict[int, str] | None = None;
            changed: any = 0;
            cid: any;
            for cid in communities {
                have_label: any = cid in existing_labels
                    and operator.ne(existing_labels[cid], f"Community {cid}");
                if saved_sigs {
                    fresh: any = have_label
                        and label_still_applies(
                            cid,
                            communities[cid],
                            previous_node_community,
                            saved_sigs.get(cid),
                            cur_sigs.get(cid),
                        );
                } elif count_mismatch {
                    fresh = have_label
                        and label_still_applies(
                            cid, communities[cid], previous_node_community, None, None
                        );
                } else {
                    fresh = have_label;
                }
                if fresh {
                    labels[cid] = existing_labels[cid];
                } else {
                    if hub_labels is None {
                        hub_labels = label_communities_by_hub(G, communities);
                    }
                    labels[cid] = hub_labels[cid];
                    if have_label {
                        changed += 1;
                    }
                }
            }
            if changed {
                print(
                    f"[graphify] community set changed since labeling ({len(existing_labels)} saved labels, {len(communities)} communities now; renamed {changed} community(ies) by their hub). Run `graphify label` to refresh names with the LLM.",
                    file=sys.stderr,
                );
            }
        } elif no_label and not force_relabel {
            labels = {cid: f"Community {cid}" for cid in communities};
            placeholder_only = True;
        } else {
            label_communities_by_hub: any = importlib.import_module(
                "graphify.cluster"
            ).label_communities_by_hub;
            generate_community_labels: any = importlib.import_module(
                "graphify.llm"
            ).generate_community_labels;
            print("Labeling communities...");
            hub_labels = label_communities_by_hub(G, communities);
            label_communities_input: any = communities;
            labels = `dict(hub_labels);
            if missing_only {
                labels = {cid: existing_labels.get(cid, hub_labels[cid]) for cid in communities};
                label_communities_input = {
                    cid: members
                    for (cid, members) in communities.items()
                    if cid not in existing_labels or existing_labels.get(cid) == f"Community {cid}"
                };
            }
            generated_labels: any;
            _: any;
            (generated_labels, _) = generate_community_labels(
                G,
                label_communities_input,
                backend=label_backend,
                model=label_model,
                gods=gods,
                max_concurrency=label_max_concurrency,
                batch_size=label_batch_size,
                usage_out=label_token_usage,
            ) as any;
            labels.update({
                cid: v
                for (cid, v) in generated_labels.items()
                if v and v != f"Community {cid}" and v != `str(cid)
            });
        }
        stages.mark("label");
        questions: any = suggest_questions(G, communities, labels);
        _commit: any = _raw.get("built_at_commit");
        if not _commit {
            _gh: any = importlib.import_module("graphify.watch")._git_head;
            _commit = _gh(cwd=watch_path);
        }
        _backup: any = importlib.import_module("graphify.export").backup_if_protected;
        _HTML_STALE_MARKER: any = importlib.import_module(
            "graphify.exporters.html"
        )._HTML_STALE_MARKER;
        _backup(out);
        html_stale_marker = out / _HTML_STALE_MARKER;

        def _clear_html_stale_marker {
            try {
                html_stale_marker.unlink(missing_ok=True);
            } except OSError as exc {
                print(
                    f"warning: graph.html stale marker could not be cleared; regeneration may be retried: {exc}",
                    file=sys.stderr,
                );
            }
        }

        stale_marker_preexisted: any = html_stale_marker.exists();
        html_stale_marker.touch();
        if not to_json(
            G,
            communities,
            `str(out / "graph.json"),
            community_labels=labels,
            built_at_commit=_commit,
            original_links=_raw.get("links") or _raw.get("edges") or [],
        ) {
            if not stale_marker_preexisted {
                _clear_html_stale_marker();
            }
            print(
                "graph.json NOT written: refusing to overwrite (see warning above). GRAPH_REPORT.md, .graphify_labels.json and .graphify_analysis.json left untouched.",
                file=sys.stderr,
            );
            sys.exit(1);
        }
        tokens: any = label_token_usage;
        _llfr: any = importlib.import_module("graphify.report").load_learning_for_report;
        `report: any = generate(
            G,
            communities,
            cohesion,
            labels,
            gods,
            surprises,
            {"warning": "cluster-only mode — file stats not available"},
            tokens,
            `str(watch_path),
            suggested_questions=questions,
            min_community_size=min_community_size,
            built_at_commit=_commit,
            learning=_llfr(out / "graph.json"),
        );
        (out / "GRAPH_REPORT.md").write_text(`report, encoding="utf-8");
        stages.mark("report");
        analysis: any = {
            "communities": {`str(k): v for (k, v) in communities.items()},
            "cohesion": {`str(k): v for (k, v) in cohesion.items()},
            "gods": gods,
            "surprises": surprises,
            "questions": questions,
        };
        (out / ".graphify_analysis.json").write_text(
            json.dumps(analysis, indent=2, ensure_ascii=False), encoding="utf-8"
        );
        if not placeholder_only {
            write_json_atomic: any = importlib.import_module("graphify.paths").write_json_atomic;
            write_text_atomic: any = importlib.import_module("graphify.paths").write_text_atomic;
            write_json_atomic(
                labels_path, {`str(k): v for (k, v) in labels.items()}, ensure_ascii=False
            );
            community_member_sigs: any = importlib.import_module(
                "graphify.cluster"
            ).community_member_sigs;
            write_text_atomic(
                labels_path.parent / (labels_path.name + ".sig"),
                json.dumps({`str(k): v for (k, v) in community_member_sigs(communities).items()}),
            );
        }
        html_target: any = out / "graph.html";
        if no_viz {
            if html_target.exists() {
                html_target.unlink();
            }
            _clear_html_stale_marker();
            stages.mark("export");
            stages.total();
            print(
                f"Done - {len(communities)} communities. GRAPH_REPORT.md and graph.json updated (--no-viz; graph.html removed).",
            );
        } else {
            html_written: any = False;
            skip_reason: str | None = None;
            try {
                _viz_node_limit: any = importlib.import_module(
                    "graphify.exporters.html"
                )._viz_node_limit;
                viz_limit: any = _viz_node_limit();
                if viz_limit <= 0 {
                    html_target.unlink(missing_ok=True);
                    _clear_html_stale_marker();
                    skip_reason = "GRAPHIFY_VIZ_NODE_LIMIT=0 disables HTML visualization";
                } else {
                    html_written = to_html(
                        G,
                        communities,
                        `str(html_target),
                        community_labels=labels or None,
                        node_limit=viz_limit,
                    );
                    if html_written {
                        _clear_html_stale_marker();
                    } else {
                        skip_reason = "no useful community aggregation could be generated";
                        if html_target.exists() {
                            skip_reason += "; existing graph.html left unchanged";
                        }
                    }
                }
            } except ValueError as viz_err {
                skip_reason = `str(viz_err);
                if html_target.exists() {
                    skip_reason += "; existing graph.html left unchanged";
                }
            }

            if skip_reason {
                print(f"Skipped graph.html: {skip_reason}");
            }
            stages.mark("export");
            stages.total();
            if html_written {
                print(
                    f"Done - {len(communities)} communities. GRAPH_REPORT.md, graph.json and graph.html updated.",
                );
            } else {
                print(
                    f"Done - {len(communities)} communities. GRAPH_REPORT.md and graph.json updated.",
                );
            }
        }
    } elif cmd == "update" {
        force: any = os.environ.get("GRAPHIFY_FORCE", "").lower() in ("1", "true", "yes");
        no_cluster: any = False;
        args = sys.argv[2:];
        watch_arg: str | None = None;
        for a in args {
            if a == "--force" {
                force = True;
                continue;
            }
            if a == "--no-cluster" {
                no_cluster = True;
                continue;
            }
            if a.startswith("-") {
                print(f"error: unknown update option: {a}", file=sys.stderr);
                sys.exit(2);
            }
            if watch_arg is not None {
                print("error: update accepts at most one path argument", file=sys.stderr);
                sys.exit(2);
            }
            watch_arg = a;
        }

        if watch_arg is not None {
            watch_path = Path(watch_arg);
        } else {
            saved = Path(_GRAPHIFY_OUT) / ".graphify_root";
            if saved.exists() {
                watch_path = Path(saved.read_text(encoding="utf-8-sig").strip());
            } else {
                watch_path = Path(".");
            }
        }
        if not watch_path.exists() {
            print(f"error: path not found: {watch_path}", file=sys.stderr);
            sys.exit(1);
        }
        _rebuild_code: any = importlib.import_module("graphify.watch")._rebuild_code;

        print(f"Updating code graph in {watch_path} (no LLM needed)...");
        ok: any = _rebuild_code(
            watch_path, incremental=True, force=force, no_cluster=no_cluster, block_on_lock=True
        );
        if ok {
            print(
                "Code graph updated. For doc/paper/image changes run /graphify --update in your AI assistant.",
            );
            if not (
                os.environ.get("GEMINI_API_KEY")
                or os.environ.get("GOOGLE_API_KEY")
                or os.environ.get("MOONSHOT_API_KEY")
                or os.environ.get("DEEPSEEK_API_KEY")
                or os.environ.get("GRAPHIFY_NO_TIPS")
            ) {
                print(
                    "Tip: set GEMINI_API_KEY or GOOGLE_API_KEY to use Gemini for semantic extraction.",
                );
            }
        } else {
            print("Nothing to update or rebuild failed — check output above.", file=sys.stderr);
            sys.exit(1);
        }
    } elif cmd == "hook-check" {
        sys.exit(0);
    } elif cmd == "hook-guard" {
        _run_hook_guard(
            sys.argv[2] if len(sys.argv) > 2 else "", strict="--strict" in sys.argv[3:]
        );
        sys.exit(0);
    } elif cmd == "check-update" {
        if len(sys.argv) < 3 {
            print("Usage: graphify check-update <path>", file=sys.stderr);
            sys.exit(1);
        }
        check_update: any = importlib.import_module("graphify.watch").check_update;

        check_update(Path(sys.argv[2]).resolve());
        sys.exit(0);
    } elif cmd == "tree" {
        import from typing { Optional as _Opt }
        write_tree_html: any = importlib.import_module("graphify.tree_html").write_tree_html;
        DEFAULT_MAX_CHILDREN: any = importlib.import_module(
            "graphify.tree_html"
        ).DEFAULT_MAX_CHILDREN;
        graph_path = Path(_GRAPHIFY_OUT) / "graph.json";
        output_path: "_Opt[Path]" = None;
        `root: "_Opt[str]" = None;
        max_children: any = DEFAULT_MAX_CHILDREN;
        top_k_edges: any = 0;
        project_label: "_Opt[str]" = None;
        args = sys.argv[2:];
        i_arg = 0;
        while i_arg < len(args) {
            a = args[i_arg];
            if a == "--graph" and i_arg + 1 < len(args) {
                graph_path = Path(args[i_arg + 1]);
                i_arg += 2;
            } elif a == "--output" and i_arg + 1 < len(args) {
                output_path = Path(args[i_arg + 1]);
                i_arg += 2;
            } elif a == "--root" and i_arg + 1 < len(args) {
                `root = args[i_arg + 1];
                i_arg += 2;
            } elif a == "--max-children" and i_arg + 1 < len(args) {
                max_children = `int(args[i_arg + 1]);
                i_arg += 2;
            } elif a == "--top-k-edges" and i_arg + 1 < len(args) {
                top_k_edges = `int(args[i_arg + 1]);
                i_arg += 2;
            } elif a == "--label" and i_arg + 1 < len(args) {
                project_label = args[i_arg + 1];
                i_arg += 2;
            } elif a in ("-h", "--help") {
                print("Usage: graphify tree [--graph PATH] [--output HTML]");
                print(
                    "  --graph PATH         path to graph.json (default graphify-out/graph.json)"
                );
                print("  --output HTML        output path (default graphify-out/GRAPH_TREE.html)");
                print(
                    "  --root PATH          filesystem root (default: longest common dir of all source_files)",
                );
                print("  --max-children N     cap visible children per node (default 200)");
                print(
                    "  --top-k-edges N      pre-compute top-K outbound edges per symbol (default 12)",
                );
                print("  --label NAME         project label shown in the page header");
                return;
            } else {
                i_arg += 1;
            }
        }
        if not graph_path.is_file() {
            print(f"error: graph.json not found at {graph_path}", file=sys.stderr);
            sys.exit(1);
        }
        _enforce_graph_size_cap_or_exit(graph_path);
        if output_path is None {
            output_path = graph_path.parent / "GRAPH_TREE.html";
        }
        try {
            out = write_tree_html(
                graph_path=graph_path,
                output_path=output_path,
                root=`root,
                max_children=max_children,
                top_k_edges=top_k_edges,
                project_label=project_label,
            );
        } except ValueError as exc {
            print(f"error: {exc}", file=sys.stderr);
            sys.exit(1);
        }
        size_kb: any = out.stat().st_size / 1024;
        print(f"wrote {out} ({size_kb:.1f} KB)");
        print(f"open with: xdg-open {out}  (or file://{out.resolve()})");
        sys.exit(0);
    } elif cmd == "merge-driver" {
        if len(sys.argv) < 5 {
            print("Usage: graphify merge-driver <base> <current> <other>", file=sys.stderr);
            sys.exit(1);
        }
        _base_path: any;
        _current_path: any;
        _other_path: any;
        (_base_path, _current_path, _other_path) = (sys.argv[2], sys.argv[3], sys.argv[4]);
        _MERGE_MAX_BYTES = 50 * 1024 * 1024;
        _MERGE_MAX_NODES: any = 100000;
        import networkx as _nx;
        import from networkx.readwrite { json_graph as _jg }
        def _load_graph(p: str) -> any {
            path_obj: any = Path(p);
            try {
                size: any = path_obj.stat().st_size;
            } except OSError as exc {
                raise RuntimeError(f"cannot stat {p}: {exc}") from exc;
            }
            if size > _MERGE_MAX_BYTES {
                raise RuntimeError(
                    f"graph.json {p} is {size} bytes, exceeds {_MERGE_MAX_BYTES}-byte cap"
                );
            }
            data: any = json.loads(path_obj.read_text(encoding="utf-8"));
            _lnlg: any = importlib.import_module("graphify.paths").load_node_link_graph;
            return (_lnlg(data), data);
        }
        try {
            G_cur: any;
            (G_cur, _) = _load_graph(_current_path) as any;
            G_oth: any;
            (G_oth, _) = _load_graph(_other_path) as any;
        } except Exception as exc {
            print(f"[graphify merge-driver] error loading graphs: {exc}", file=sys.stderr);
            sys.exit(1);
        }
        merged: dict = _nx.compose(G_cur, G_oth);
        if merged.number_of_nodes() > _MERGE_MAX_NODES {
            print(
                f"[graphify merge-driver] merged graph has {merged.number_of_nodes()} nodes, exceeds {_MERGE_MAX_NODES}-node cap; aborting merge.",
                file=sys.stderr,
            );
            sys.exit(1);
        }
        try {
            out_data: any = _jg.node_link_data(merged, edges="links");
        } except TypeError {
            out_data = _jg.node_link_data(merged);
        }
        for _link in out_data.get("links", []) {
            _ts: any;
            _tt: any;
            (_ts, _tt) = (_link.pop("_src", None), _link.pop("_tgt", None));
            if _ts is not None and _tt is not None {
                items_: any = list((_ts, _tt));
                if len(items_) != 2 {
                    raise ValueError(
                        f"too many values to unpack (expected 2, got {len(items_)})"
                            if len(items_) > 2
                            else f"not enough values to unpack (expected 2, got {len(items_)})",
                    );
                }
                _link["source"] = items_[0];
                _link["target"] = items_[1];
            }
        }
        write_json_atomic: any = importlib.import_module("graphify.paths").write_json_atomic;
        write_json_atomic(_current_path, out_data, compact=True);
        sys.exit(0);
    } elif cmd == "merge-graphs" {
        args = sys.argv[2:];
        graph_paths: list[Path] = [];
        out_path = Path(_GRAPHIFY_OUT) / "merged-graph.json";
        previous_path: "Path | None" = None;
        i = 0;
        while i < len(args) {
            if args[i] == "--out" and i + 1 < len(args) {
                out_path = Path(args[i + 1]);
                i += 2;
            } elif args[i] == "--previous" and i + 1 < len(args) {
                previous_path = Path(args[i + 1]);
                i += 2;
            } else {
                graph_paths.append(Path(args[i]));
                i += 1;
            }
        }
        if len(graph_paths) < 2 {
            print(
                "Usage: graphify merge-graphs <graph1.json> <graph2.json> [...] [--out merged.json] [--previous previous-merged-graph.json]",
                file=sys.stderr,
            );
            sys.exit(1);
        }
        previous_community: dict[str, int] = {};
        if previous_path is not None {
            if not previous_path.exists() {
                print(f"error: --previous file not found: {previous_path}", file=sys.stderr);
                sys.exit(1);
            }
            try {
                _prev_raw: any = json.loads(previous_path.read_text(encoding="utf-8"));
            } except (json.JSONDecodeError, OSError, UnicodeDecodeError) as e {
                print(
                    f"error: --previous file is not readable JSON: {previous_path} ({e})",
                    file=sys.stderr,
                );
                sys.exit(1);
            }
            for _n in _prev_raw.get("nodes", []) {
                if isinstance(_n, `dict)
                    and isinstance(_n.get("community"), `int)
                    and _n.get("id")
                {
                    previous_community[_n["id"]] = _n["community"];
                }
            }
        }
        import networkx as _nx;
        import from networkx.readwrite { json_graph as _jg }
        _prefix: any = importlib.import_module("graphify.build").prefix_graph_for_global;
        distinct_repo_tags: any = importlib.import_module("graphify.build").distinct_repo_tags;
        graphs: any = [];
        for gp in graph_paths {
            if not gp.exists() {
                print(f"error: not found: {gp}", file=sys.stderr);
                sys.exit(1);
            }
            _enforce_graph_size_cap_or_exit(gp);
            data: any = json.loads(gp.read_text(encoding="utf-8"));
            if "links" not in data and "edges" in data {
                data = `dict(data, links=data["edges"]);
            }
            data = `dict(
                data,
                links=[
                    {
                        **link,
                        "_src": link.get("_src", link.get("source")),
                        "_tgt": link.get("_tgt", link.get("target")),
                    }
                    for link in data.get("links", [])
                ],
            );
            try {
                G = _jg.node_link_graph(data, edges="links");
            } except TypeError {
                G = _jg.node_link_graph(data);
            }
            if "hyperedges" not in G.graph and isinstance(data.get("hyperedges"), `list) {
                G.graph["hyperedges"] = data["hyperedges"];
            }
            graphs.append(G);
        }
        def _to_simple(g: "_nx.Graph") -> "_nx.Graph" {
            if `type(g) is not _nx.Graph {
                return _nx.Graph(g);
            }
            return g;
        }
        repo_tags: any = distinct_repo_tags(graph_paths);
        naive_tags: any = [gp.parent.parent.name for gp in graph_paths];
        if len(`set(naive_tags)) != len(naive_tags) {
            print(
                "  note: repo dir names collide; using distinct tags: "
                    + format(", ".join(repo_tags), ""),
            );
        }
        merged = _nx.Graph();
        input_node_total: any = sum(g.number_of_nodes() for g in graphs);
        collected_hyperedges: list = [];
        community_offset: any = 0;
        repo_tag: any;
        for item_ in zip(graphs, repo_tags) {
            (G, repo_tag) = item_;
            prefixed: any = _to_simple(_prefix(G, repo_tag, community_offset=community_offset));
            hes: any = prefixed.graph.get("hyperedges");
            if isinstance(hes, `list) {
                collected_hyperedges.extend(h for h in hes if isinstance(h, `dict));
            }
            cids: any = [
                d["community"]
                for (_, d) in prefixed.nodes(data=True)
                if isinstance(d.get("community"), `int)
            ];
            if cids {
                community_offset = max(community_offset, max(cids) + 1);
            }
            merged = _nx.compose(merged, prefixed);
        }
        _link_shared: any = importlib.import_module(
            "graphify.cross_repo_types"
        ).link_shared_type_declarations;
        shared_links: any = _link_shared(merged);
        if shared_links {
            print(f"  linked {shared_links} type declaration(s) shared across repos");
        }
        _link_calls: any = importlib.import_module(
            "graphify.cross_repo_calls"
        ).link_cross_repo_member_calls;
        call_links: any = _link_calls(merged);
        if call_links {
            print(f"  resolved {call_links} member call(s) across repos");
        }
        if previous_path is not None {
            _restored: any = 0;
            for (_nid, _data) in merged.nodes(data=True) {
                if _nid in previous_community {
                    _data["community"] = previous_community[_nid];
                    _restored += 1;
                } else {
                    _data.pop("community", None);
                }
            }
            print(
                f"  restored the previous merged community on {_restored} node(s) from {previous_path}",
            );
        }
        merged.graph.pop("hyperedges", None);
        if collected_hyperedges {
            _attach: any = importlib.import_module("graphify.export").attach_hyperedges;
            _attach(merged, collected_hyperedges);
        }
        try {
            out_data = _jg.node_link_data(merged, edges="links");
        } except TypeError {
            out_data = _jg.node_link_data(merged);
        }
        for link in out_data.get("links", []) {
            tsrc: any = link.pop("_src", None);
            ttgt: any = link.pop("_tgt", None);
            if tsrc is not None and ttgt is not None {
                link["source"] = tsrc;
                link["target"] = ttgt;
            }
        }
        out_data["hyperedges"] = merged.graph.get("hyperedges", []);
        out_path.parent.mkdir(parents=True, exist_ok=True);
        write_json_atomic: any = importlib.import_module("graphify.paths").write_json_atomic;
        write_json_atomic(out_path, out_data, compact=True);
        unified: any = input_node_total - merged.number_of_nodes();
        if unified > 0 {
            print(f"  unified {unified} external node(s) shared across repos");
        }
        print(
            f"Merged {len(graphs)} graphs -> {merged.number_of_nodes()} nodes, {merged.number_of_edges()} edges",
        );
        print(f"Written to: {out_path}");
    } elif cmd == "clone" {
        if len(sys.argv) < 3 {
            print(
                "Usage: graphify clone <github-url> [--branch <branch>] [--out <dir>]",
                file=sys.stderr,
            );
            sys.exit(1);
        }
        url = sys.argv[2];
        branch: str | None = None;
        out_dir: Path | None = None;
        args = sys.argv[3:];
        i = 0;
        while i < len(args) {
            if args[i] == "--branch" and i + 1 < len(args) {
                branch = args[i + 1];
                i += 2;
            } elif args[i] == "--out" and i + 1 < len(args) {
                out_dir = Path(args[i + 1]);
                i += 2;
            } else {
                i += 1;
            }
        }
        local_path: any = _clone_repo(url, branch=branch, out_dir=out_dir);
        print(local_path);
    } elif cmd == "export" {
        subcmd = sys.argv[2] if len(sys.argv) > 2 else "";
        if subcmd
            not in (
                "html",
                "callflow-html",
                "obsidian",
                "wiki",
                "svg",
                "graphml",
                "neo4j",
                "falkordb",
            )
        {
            print("Usage: graphify export <format>", file=sys.stderr);
            print(
                "  html      [--graph PATH] [--labels PATH] [--node-limit N] [--no-viz]",
                file=sys.stderr,
            );
            print(
                "  callflow-html [GRAPH|DIR] [--graph PATH] [--labels PATH] [--report PATH] [--sections PATH] [--output HTML]",
                file=sys.stderr,
            );
            print(
                "            [--lang auto|zh-CN|en] [--max-sections N] [--diagram-scale N]",
                file=sys.stderr,
            );
            print("  obsidian  [--graph PATH] [--labels PATH] [--dir PATH]", file=sys.stderr);
            print("  wiki      [--graph PATH] [--labels PATH]", file=sys.stderr);
            print("  svg       [--graph PATH] [--labels PATH]", file=sys.stderr);
            print("  graphml   [--graph PATH]", file=sys.stderr);
            print(
                "  neo4j     [--graph PATH] [--push URI] [--user U] [--password P]", file=sys.stderr
            );
            print(
                "            (or set NEO4J_PASSWORD instead of --password to keep it off argv)",
                file=sys.stderr,
            );
            print(
                "  falkordb  [--graph PATH] [--push URI] [--user U] [--password P]", file=sys.stderr
            );
            print(
                "            (or set FALKORDB_PASSWORD instead of --password to keep it off argv)",
                file=sys.stderr,
            );
            sys.exit(1);
        }
        args = sys.argv[3:];
        graph_path = Path(_GRAPHIFY_OUT) / "graph.json";
        graph_path_explicit: any = False;
        labels_path = Path(_GRAPHIFY_OUT) / ".graphify_labels.json";
        labels_path_explicit: any = False;
        report_path: any = Path(_GRAPHIFY_OUT) / "GRAPH_REPORT.md";
        report_path_explicit: any = False;
        sections_path: Path | None = None;
        callflow_output: Path | None = None;
        callflow_lang: any = "auto";
        callflow_max_sections: any = 15;
        callflow_diagram_scale: any = 1.0;
        callflow_max_diagram_nodes: any = 18;
        callflow_max_diagram_edges: any = 24;
        analysis_path: any = Path(_GRAPHIFY_OUT) / ".graphify_analysis.json";
        node_limit: any = 5000;
        no_viz = False;
        obsidian_dir: any = Path(_GRAPHIFY_OUT) / "obsidian";
        push_uri: str | None = None;
        push_user: any = "neo4j";
        push_password: str | None = (
            os.environ.get("FALKORDB_PASSWORD")
                if subcmd == "falkordb"
                else os.environ.get("NEO4J_PASSWORD")
        )
            or None;
        i = 0;
        while i < len(args) {
            a = args[i];
            if a == "--graph" and i + 1 < len(args) {
                graph_path = Path(args[i + 1]);
                graph_path_explicit = True;
                i += 2;
            } elif a == "--labels" and i + 1 < len(args) {
                labels_path = Path(args[i + 1]);
                labels_path_explicit = True;
                i += 2;
            } elif a == "--report" and i + 1 < len(args) {
                report_path = Path(args[i + 1]);
                report_path_explicit = True;
                i += 2;
            } elif a == "--sections" and i + 1 < len(args) {
                sections_path = Path(args[i + 1]);
                i += 2;
            } elif a == "--output" and i + 1 < len(args) {
                callflow_output = Path(args[i + 1]).expanduser();
                if not callflow_output.is_absolute() {
                    callflow_output = Path.cwd() / callflow_output;
                }
                i += 2;
            } elif a == "--lang" and i + 1 < len(args) {
                callflow_lang = args[i + 1];
                i += 2;
            } elif a == "--max-sections" and i + 1 < len(args) {
                callflow_max_sections = `int(args[i + 1]);
                i += 2;
            } elif a == "--diagram-scale" and i + 1 < len(args) {
                callflow_diagram_scale = `float(args[i + 1]);
                i += 2;
            } elif a == "--max-diagram-nodes" and i + 1 < len(args) {
                callflow_max_diagram_nodes = `int(args[i + 1]);
                i += 2;
            } elif a == "--max-diagram-edges" and i + 1 < len(args) {
                callflow_max_diagram_edges = `int(args[i + 1]);
                i += 2;
            } elif a in ("-h", "--help") and subcmd == "callflow-html" {
                print(
                    "Usage: graphify export callflow-html [GRAPH|DIR] [--graph PATH] [--labels PATH]",
                );
                print("  --report PATH          path to GRAPH_REPORT.md");
                print("  --sections PATH        JSON section definitions");
                print(
                    "  --output HTML          output path (default graphify-out/<project>-callflow.html)",
                );
                print("  --lang LANG            auto, zh-CN, en, etc. (default auto)");
                print("  --max-sections N       maximum auto-derived sections (default 15)");
                print("  --diagram-scale N      Mermaid diagram scale (default 1.0)");
                print("  --max-diagram-nodes N  representative nodes per section (default 18)");
                print("  --max-diagram-edges N  representative edges per section (default 24)");
                sys.exit(0);
            } elif a == "--node-limit" and i + 1 < len(args) {
                node_limit = `int(args[i + 1]);
                i += 2;
            } elif a == "--no-viz" {
                no_viz = True;
                i += 1;
            } elif a == "--dir" and i + 1 < len(args) {
                obsidian_dir = Path(args[i + 1]);
                i += 2;
            } elif a == "--push" and i + 1 < len(args) {
                push_uri = args[i + 1];
                i += 2;
            } elif a == "--user" and i + 1 < len(args) {
                push_user = args[i + 1];
                i += 2;
            } elif a == "--password" and i + 1 < len(args) {
                push_password = args[i + 1];
                i += 2;
            } elif subcmd == "callflow-html" and not a.startswith("-") and not graph_path_explicit {
                candidate: any = Path(a);
                if candidate.name == "graph.json" or candidate.suffix.lower() == ".json" {
                    graph_path = candidate;
                } elif (candidate / "graph.json").exists() {
                    graph_path = candidate / "graph.json";
                } else {
                    graph_path = candidate / _GRAPHIFY_OUT / "graph.json";
                }
                graph_path_explicit = True;
                i += 1;
            } else {
                i += 1;
            }
        }

        graph_path = graph_path.expanduser();
        if graph_path_explicit {
            graph_out_dir: any = graph_path.parent;
            if not labels_path_explicit {
                labels_path = graph_out_dir / ".graphify_labels.json";
            }
            if not report_path_explicit {
                report_path = graph_out_dir / "GRAPH_REPORT.md";
            }
        }
        labels_path = labels_path.expanduser();
        report_path = report_path.expanduser();

        if not graph_path.exists() {
            print(
                f"error: graph not found: {graph_path}. Run /graphify <path> first.",
                file=sys.stderr,
            );
            sys.exit(1);
        }

        if subcmd == "callflow-html" {
            _write_callflow_html: any = importlib.import_module(
                "graphify.callflow_html"
            ).write_callflow_html;
            out = _write_callflow_html(
                graph=graph_path,
                report=report_path,
                labels=labels_path,
                sections=sections_path,
                output=callflow_output,
                lang=callflow_lang,
                max_sections=callflow_max_sections,
                diagram_scale=callflow_diagram_scale,
                max_diagram_nodes=callflow_max_diagram_nodes,
                max_diagram_edges=callflow_max_diagram_edges,
                verbose=True,
            );
            print(f"callflow HTML written - open in any browser: {out}");
            sys.exit(0);
        }

        import from networkx.readwrite { json_graph as _jg }
        build_from_json: any = importlib.import_module("graphify.build").build_from_json;
        check_graph_file_size_cap: any = importlib.import_module(
            "graphify.security"
        ).check_graph_file_size_cap;
        _over_cap: any = False;
        try {
            check_graph_file_size_cap(graph_path);
        } except ValueError as _cap_err {
            if subcmd == "html" {
                _over_cap = True;
                try {
                    _over_cap_bytes = graph_path.stat().st_size;
                } except OSError {
                    _over_cap_bytes = -1;
                }
                print(
                    f"warning: graph.json exceeds cap ({_over_cap_bytes} bytes); falling back to community-aggregation view (node_limit=5000)",
                    file=sys.stderr,
                );
            } else {
                print(f"error: {_cap_err}", file=sys.stderr);
                sys.exit(1);
            }
        }
        _raw = json.loads(graph_path.read_text(encoding="utf-8"));
        if "links" not in _raw and "edges" in _raw {
            _raw = `dict(_raw, links=_raw["edges"]);
        }
        _rad: any = importlib.import_module("graphify.paths").restore_arc_direction;
        _raw = _rad(_raw);
        try {
            G = _jg.node_link_graph(_raw, edges="links");
        } except TypeError {
            G = _jg.node_link_graph(_raw);
        }
        if isinstance(_raw.get("hyperedges"), `list) {
            G.graph["hyperedges"] = _raw["hyperedges"];
        }
        communities = {};
        if analysis_path.exists() {
            _an: any = json.loads(analysis_path.read_text(encoding="utf-8"));
            communities = {`int(k): v for (k, v) in _an.get("communities", {}).items()};
            cohesion = {`int(k): v for (k, v) in _an.get("cohesion", {}).items()};
            gods_data: any = _an.get("gods", []);
        } else {
            cohesion = {};
            gods_data = [];
        }
        reconstructed: dict[int, list[str]] = {};
        for (node_id, data) in G.nodes(data=True) {
            cid_raw: any = data.get("community");
            if cid_raw is None {
                continue;
            }
            try {
                cid = `int(cid_raw);
            } except (TypeError, ValueError) {
                continue;
            }
            reconstructed.setdefault(cid, []).append(`str(node_id));
        }
        if not communities {
            if reconstructed {
                communities = reconstructed;
            }
        } elif reconstructed {
            sidecar_partition: any = {
                frozenset(`str(n) for n in nodes)
                for nodes in communities.values()
            };
            fresh_partition: any = {frozenset(nodes) for nodes in reconstructed.values()};
            if sidecar_partition != fresh_partition {
                sidecar_node_count: any = len({n for block in sidecar_partition for n in block});
                fresh_node_count: any = len({n for block in fresh_partition for n in block});
                print(
                    f"warning: {analysis_path} is stale ({sidecar_node_count} node(s) recorded vs {fresh_node_count} in graph.json) — reconstructing communities from graph.json instead. Run `graphify cluster-only .` to refresh the sidecar and its cohesion/god-node data.",
                    file=sys.stderr,
                );
                communities = reconstructed;
                score_all: any = importlib.import_module("graphify.cluster").score_all;
                god_nodes: any = importlib.import_module("graphify.analyze").god_nodes;
                cohesion = score_all(G, communities);
                gods_data = god_nodes(G);
            }
        }

        labels = {};
        if labels_path.exists() {
            labels = {
                `int(k): v
                for (k, v) in json.loads(labels_path.read_text(encoding="utf-8")).items()
            };
        }

        out_dir = graph_path.parent;

        if subcmd == "html" {
            to_html: any = importlib.import_module("graphify.export").to_html;
            if no_viz {
                html_target = out_dir / "graph.html";
                if html_target.exists() {
                    html_target.unlink();
                }
                print("--no-viz: skipped graph.html");
            } else {
                _effective_node_limit: any = 5000 if _over_cap else node_limit;
                to_html(
                    G,
                    communities,
                    `str(out_dir / "graph.html"),
                    community_labels=labels or None,
                    node_limit=_effective_node_limit,
                );
                if G.number_of_nodes() <= _effective_node_limit {
                    print(f"graph.html written - open in any browser, no server needed");
                }
                if _over_cap {
                    sys.exit(0);
                }
            }
        } elif subcmd == "obsidian" {
            _to_obsidian: any = importlib.import_module("graphify.export").to_obsidian;
            _to_canvas: any = importlib.import_module("graphify.export").to_canvas;
            n = _to_obsidian(
                G,
                communities,
                `str(obsidian_dir),
                community_labels=labels or None,
                cohesion=cohesion or None,
            );
            print(f"Obsidian vault: {n} notes in {obsidian_dir}/");
            _to_canvas(
                G, communities, `str(obsidian_dir / "graph.canvas"), community_labels=labels or None
            );
            print(f"Canvas: {obsidian_dir}/graph.canvas");
            print(f"Open {obsidian_dir}/ as a vault in Obsidian.");
        } elif subcmd == "wiki" {
            _to_wiki: any = importlib.import_module("graphify.wiki").to_wiki;
            god_nodes: any = importlib.import_module("graphify.analyze").god_nodes;
            if not communities {
                print(
                    "error: .graphify_analysis.json is missing or empty — refusing to export wiki to prevent data loss.\nRun `graphify extract .` (or `graphify cluster-only .`) to regenerate community data first.",
                    file=sys.stderr,
                );
                sys.exit(1);
            }
            if not gods_data {
                gods_data = god_nodes(G);
            }
            n = _to_wiki(
                G,
                communities,
                `str(out_dir / "wiki"),
                community_labels=labels or None,
                cohesion=cohesion or None,
                god_nodes_data=gods_data,
            );
            print(f"Wiki: {n} articles written to {out_dir}/wiki/");
            print(f"  {out_dir}/wiki/index.md  ->  agent entry point");
        } elif subcmd == "svg" {
            _to_svg: any = importlib.import_module("graphify.export").to_svg;
            _to_svg(G, communities, `str(out_dir / "graph.svg"), community_labels=labels or None);
            print(f"graph.svg written - embeds in Obsidian, Notion, GitHub READMEs");
        } elif subcmd == "graphml" {
            _to_graphml: any = importlib.import_module("graphify.export").to_graphml;
            _to_graphml(G, communities, `str(out_dir / "graph.graphml"));
            print(f"graph.graphml written - open in Gephi, yEd, or any GraphML tool");
        } elif subcmd == "neo4j" {
            if push_uri {
                _push: any = importlib.import_module("graphify.export").push_to_neo4j;
                if push_password is None {
                    print("error: --password required for --push", file=sys.stderr);
                    sys.exit(1);
                }
                result: any = _push(
                    G, uri=push_uri, user=push_user, password=push_password, communities=communities
                );
                print(
                    "Pushed to Neo4j: "
                        + format(result["nodes"], "")
                        + " nodes, "
                        + format(result["edges"], "")
                        + " edges",
                );
            } else {
                _to_cypher: any = importlib.import_module("graphify.export").to_cypher;
                _to_cypher(G, `str(out_dir / "cypher.txt"));
                print(f"cypher.txt written - import with: cypher-shell < {out_dir}/cypher.txt");
            }
        } elif subcmd == "falkordb" {
            if push_uri {
                _push_falkordb: any = importlib.import_module("graphify.export").push_to_falkordb;
                result = _push_falkordb(
                    G, uri=push_uri, user=push_user, password=push_password, communities=communities
                );
                print(
                    "Pushed to FalkorDB: "
                        + format(result["nodes"], "")
                        + " nodes, "
                        + format(result["edges"], "")
                        + " edges",
                );
            } else {
                _to_cypher: any = importlib.import_module("graphify.export").to_cypher;
                _to_cypher(G, `str(out_dir / "cypher.txt"));
                print(
                    f"cypher.txt written ({out_dir}/cypher.txt) - statements are OpenCypher. FalkorDB's GRAPH.QUERY runs one statement at a time (no bulk script import), so load a graph with: graphify export falkordb --push falkordb://localhost:6379",
                );
            }
        }
    } elif cmd == "benchmark" {
        run_benchmark: any = importlib.import_module("graphify.benchmark").run_benchmark;
        print_benchmark: any = importlib.import_module("graphify.benchmark").print_benchmark;

        graph_path = sys.argv[2] if len(sys.argv) > 2 else _default_graph_path();
        _enforce_graph_size_cap_or_exit(Path(graph_path));
        corpus_words: any = None;
        detect_path: any = Path(".graphify_detect.json");
        if detect_path.exists() {
            try {
                detect_data: any = json.loads(detect_path.read_text(encoding="utf-8"));
                corpus_words = detect_data.get("total_words");
            } except Exception {}
        }
        result = run_benchmark(graph_path, corpus_words=corpus_words);
        print_benchmark(result);
    } elif cmd == "global" {
        subcmd = sys.argv[2] if len(sys.argv) > 2 else "";
        _global_add: any = importlib.import_module("graphify.global_graph").global_add;
        _global_remove: any = importlib.import_module("graphify.global_graph").global_remove;
        _global_list: any = importlib.import_module("graphify.global_graph").global_list;
        _global_path: any = importlib.import_module("graphify.global_graph").global_path;
        if subcmd == "add" {
            args = sys.argv[3:];
            source: any = None;
            tag: any = None;
            i = 0;
            while i < len(args) {
                if args[i] == "--as" and i + 1 < len(args) {
                    tag = args[i + 1];
                    i += 2;
                } elif not source {
                    source = Path(args[i]);
                    i += 1;
                } else {
                    i += 1;
                }
            }
            if not source {
                print("Usage: graphify global add <graph.json> [--as <repo-tag>]", file=sys.stderr);
                sys.exit(1);
            }
            if not tag {
                distinct_repo_tags: any = importlib.import_module(
                    "graphify.build"
                ).distinct_repo_tags;
                tag = distinct_repo_tags([source.absolute()])[0];
            }
            try {
                result = _global_add(source, tag);
                if result["skipped"] {
                    print(f"'{tag}' unchanged since last add - global graph not modified.");
                } else {
                    print(
                        "Added '"
                            + format(tag, "")
                            + "' to global graph: +"
                            + format(result["nodes_added"], "")
                            + " nodes, -"
                            + format(result["nodes_removed"], "")
                            + " pruned. Global: "
                            + format(_global_path(), ""),
                    );
                    if result.get("cross_repo_calls") {
                        print(
                            "  resolved "
                                + format(result["cross_repo_calls"], "")
                                + " member call(s) across repos",
                        );
                    }
                }
            } except Exception as exc {
                print(f"error: {exc}", file=sys.stderr);
                sys.exit(1);
            }
        } elif subcmd == "remove" {
            if len(sys.argv) <= 3 {
                print("Usage: graphify global remove <repo-tag>", file=sys.stderr);
                sys.exit(1);
            }
            tag = sys.argv[3];
            try {
                removed: any = _global_remove(tag);
                print(f"Removed '{tag}' from global graph ({removed} nodes pruned).");
            } except KeyError as exc {
                print(f"error: {exc}", file=sys.stderr);
                sys.exit(1);
            }
        } elif subcmd == "list" {
            repos: any = _global_list();
            if not repos {
                print("Global graph is empty. Use 'graphify global add' to add a project.");
            } else {
                print(f"Global graph: {_global_path()}");
                for (tag, info) in repos.items() {
                    print(
                        "  "
                            + format(tag, "")
                            + ": "
                            + format(info.get("node_count", "?"), "")
                            + " nodes, added "
                            + format(info.get("added_at", "?")[:10], ""),
                    );
                }
            }
        } elif subcmd == "path" {
            print(_global_path());
        } else {
            print("Usage: graphify global [add|remove|list|path]", file=sys.stderr);
            sys.exit(1);
        }
    } elif cmd == "extract" {
        if len(sys.argv) < 3 {
            print(
                "Usage: graphify extract <path> [--backend gemini|kimi|claude|openai|deepseek|ollama] [--model M] [--mode deep] [--out DIR|--output DIR] [--google-workspace] [--no-cluster] [--no-gitignore] [--code-only] [--no-dedup] [--max-workers N] [--token-budget N] [--max-concurrency N] [--api-timeout S] [--postgres DSN] [--cargo] [--allow-partial] [--allow-dedup-shrink] [--timing]",
                file=sys.stderr,
            );
            sys.exit(1);
        }

        has_path = True;
        if sys.argv[2].startswith("-") {
            has_path = False;
            target = Path(".").resolve();
        } else {
            target = Path(sys.argv[2]).resolve();
            if not target.exists() {
                print(f"error: path not found: {target}", file=sys.stderr);
                sys.exit(1);
            }
        }

        backend: str | None = None;
        model: str | None = None;
        extract_mode: str | None = None;
        out_dir = None;
        cli_postgres_dsn: str | None = None;
        cli_cargo: bool = False;
        cli_allow_partial: bool = False;
        cli_allow_dedup_shrink: bool = False;
        no_cluster = False;
        dedup_llm: any = False;
        no_dedup: any = False;
        google_workspace: any = False;
        global_merge: any = False;
        code_only: any = False;
        no_gitignore: any = False;
        global_repo_tag: str | None = None;
        cli_max_workers: int | None = None;
        cli_token_budget: int | None = None;
        cli_max_concurrency: int | None = None;
        cli_api_timeout: float | None = None;
        cli_resolution: float = 1.0;
        cli_exclude_hubs: float | None = None;
        cli_excludes: list[str] = [];
        cli_timing: bool = False;
        force = os.environ.get("GRAPHIFY_FORCE", "").lower() in ("1", "true", "yes");

        def _parse_int(name: str, raw: str) -> int {
            try {
                v: any = `int(raw);
            } except ValueError {
                print(f"error: {name} must be a positive integer (got {raw!r})", file=sys.stderr);
                sys.exit(2);
            }
            if v <= 0 {
                print(f"error: {name} must be > 0 (got {v})", file=sys.stderr);
                sys.exit(2);
            }
            return v;
        }

        def _parse_float(name: str, raw: str) -> float {
            try {
                v: any = `float(raw);
            } except ValueError {
                print(f"error: {name} must be a positive number (got {raw!r})", file=sys.stderr);
                sys.exit(2);
            }
            if v <= 0 {
                print(f"error: {name} must be > 0 (got {v})", file=sys.stderr);
                sys.exit(2);
            }
            return v;
        }

        args = sys.argv[3:] if has_path else sys.argv[2:];
        i = 0;
        while i < len(args) {
            a = args[i];
            if a == "--backend" and i + 1 < len(args) {
                backend = args[i + 1];
                i += 2;
            } elif a.startswith("--backend=") {
                backend = a.split("=", 1)[1];
                i += 1;
            } elif a == "--model" and i + 1 < len(args) {
                model = args[i + 1];
                i += 2;
            } elif a.startswith("--model=") {
                model = a.split("=", 1)[1];
                i += 1;
            } elif a == "--mode" and i + 1 < len(args) {
                extract_mode = args[i + 1];
                i += 2;
            } elif a.startswith("--mode=") {
                extract_mode = a.split("=", 1)[1];
                i += 1;
            } elif a in ("--out", "--output") and i + 1 < len(args) {
                out_dir = Path(args[i + 1]);
                i += 2;
            } elif a.startswith(("--out=", "--output=")) {
                out_dir = Path(a.split("=", 1)[1]);
                i += 1;
            } elif a == "--no-cluster" {
                no_cluster = True;
                i += 1;
            } elif a == "--dedup-llm" {
                dedup_llm = True;
                i += 1;
            } elif a == "--no-dedup" {
                no_dedup = True;
                i += 1;
            } elif a == "--code-only" {
                code_only = True;
                i += 1;
            } elif a == "--google-workspace" {
                google_workspace = True;
                i += 1;
            } elif a == "--no-gitignore" {
                no_gitignore = True;
                i += 1;
            } elif a == "--global" {
                global_merge = True;
                i += 1;
            } elif a == "--as" and i + 1 < len(args) {
                global_repo_tag = args[i + 1];
                i += 2;
            } elif a == "--max-workers" and i + 1 < len(args) {
                cli_max_workers = _parse_int("--max-workers", args[i + 1]);
                i += 2;
            } elif a.startswith("--max-workers=") {
                cli_max_workers = _parse_int("--max-workers", a.split("=", 1)[1]);
                i += 1;
            } elif a == "--token-budget" and i + 1 < len(args) {
                cli_token_budget = _parse_int("--token-budget", args[i + 1]);
                i += 2;
            } elif a.startswith("--token-budget=") {
                cli_token_budget = _parse_int("--token-budget", a.split("=", 1)[1]);
                i += 1;
            } elif a == "--max-concurrency" and i + 1 < len(args) {
                cli_max_concurrency = _parse_int("--max-concurrency", args[i + 1]);
                i += 2;
            } elif a.startswith("--max-concurrency=") {
                cli_max_concurrency = _parse_int("--max-concurrency", a.split("=", 1)[1]);
                i += 1;
            } elif a == "--api-timeout" and i + 1 < len(args) {
                cli_api_timeout = _parse_float("--api-timeout", args[i + 1]);
                i += 2;
            } elif a.startswith("--api-timeout=") {
                cli_api_timeout = _parse_float("--api-timeout", a.split("=", 1)[1]);
                i += 1;
            } elif a == "--resolution" and i + 1 < len(args) {
                cli_resolution = _parse_float("--resolution", args[i + 1]);
                i += 2;
            } elif a.startswith("--resolution=") {
                cli_resolution = _parse_float("--resolution", a.split("=", 1)[1]);
                i += 1;
            } elif a == "--exclude-hubs" and i + 1 < len(args) {
                cli_exclude_hubs = `float(args[i + 1]);
                i += 2;
            } elif a.startswith("--exclude-hubs=") {
                cli_exclude_hubs = `float(a.split("=", 1)[1]);
                i += 1;
            } elif a == "--exclude" and i + 1 < len(args) {
                cli_excludes.append(args[i + 1]);
                i += 2;
            } elif a.startswith("--exclude=") {
                cli_excludes.append(a.split("=", 1)[1]);
                i += 1;
            } elif a == "--postgres" and i + 1 < len(args) {
                cli_postgres_dsn = args[i + 1];
                i += 2;
            } elif a.startswith("--postgres=") {
                cli_postgres_dsn = a.split("=", 1)[1];
                i += 1;
            } elif a == "--cargo" {
                cli_cargo = True;
                i += 1;
            } elif a == "--force" {
                force = True;
                i += 1;
            } elif a == "--allow-partial" {
                cli_allow_partial = True;
                i += 1;
            } elif a == "--allow-dedup-shrink" {
                cli_allow_dedup_shrink = True;
                i += 1;
            } elif a == "--timing" {
                cli_timing = True;
                i += 1;
            } else {
                i += 1;
            }
        }

        if not has_path and cli_postgres_dsn is None {
            print("error: must specify a path to scan or a --postgres DSN", file=sys.stderr);
            sys.exit(1);
        }

        if no_dedup and dedup_llm {
            print(
                "error: --no-dedup and --dedup-llm are mutually exclusive (--dedup-llm is a tiebreaker inside the dedup pass)",
                file=sys.stderr,
            );
            sys.exit(2);
        }

        _VALID_MODES: any = {"deep"};
        if extract_mode is not None and extract_mode not in _VALID_MODES {
            print(
                "error: unknown --mode '"
                    + format(extract_mode, "")
                    + "'. Available: "
                    + format(", ".join(sorted(_VALID_MODES)), ""),
                file=sys.stderr,
            );
            sys.exit(2);
        }
        deep_mode: any = operator.eq(extract_mode, "deep");
        if deep_mode {
            print("[graphify extract] deep mode enabled: richer semantic extraction");
        }
        if cli_api_timeout is not None {
            os.environ["GRAPHIFY_API_TIMEOUT"] = `str(cli_api_timeout);
        }
        if cli_max_workers is not None {
            os.environ["GRAPHIFY_MAX_WORKERS"] = `str(cli_max_workers);
        }
        out_root: any = out_dir.resolve() if out_dir else target;
        graphify_out: any = out_root / _GRAPHIFY_OUT;
        graphify_out.mkdir(parents=True, exist_ok=True);
        _write_build_cfg: any = importlib.import_module("graphify.watch")._write_build_config;
        _read_build_ex: any = importlib.import_module("graphify.watch")._read_build_excludes;
        _read_build_gi: any = importlib.import_module("graphify.watch")._read_build_gitignore;
        _effective_gitignore: any = False if no_gitignore else _read_build_gi(graphify_out);
        _effective_excludes: any = cli_excludes or _read_build_ex(graphify_out);
        _write_build_cfg(
            graphify_out,
            excludes=cli_excludes or None,
            gitignore=False if no_gitignore else None,
            code_only=True if code_only else None,
        );

        stages = _StageTimer(cli_timing);

        _detect: any = importlib.import_module("graphify.detect").detect;
        _detect_incremental: any = importlib.import_module("graphify.detect").detect_incremental;
        _save_manifest: any = importlib.import_module("graphify.detect").save_manifest;
        manifest_path = graphify_out / "manifest.json";
        existing_graph_path: any = graphify_out / "graph.json";
        incremental_mode: any = existing_graph_path.exists() if has_path else False;
        incremental_mode = incremental_mode and not force;
        merge_existing_graph: any = incremental_mode or code_only and existing_graph_path.exists();
        if force and code_only and existing_graph_path.exists() {
            print(
                "[graphify extract] --force --code-only: full AST re-scan, existing semantic layer preserved (no semantic pass this run)",
            );
        }
        if force {
            print("[graphify extract] --force: full re-scan, semantic cache reads skipped");
        } elif incremental_mode and not manifest_path.exists() {
            print(
                "[graphify extract] manifest.json missing; using existing graph.json as the incremental baseline (all files re-checked; nodes for files outside this run's scope are preserved)",
            );
        }

        if not has_path {
            detection: any = {};
            code_files: any = [];
            doc_files: any = [];
            paper_files: any = [];
            image_files: any = [];
            video_files: any = [];
            deleted_files: any = [];
            excluded_files: any = [];
            graph_stale_sources: any = [];
            unchanged_total: any = 0;
            files_by_type: any = {};
        } elif incremental_mode {
            print(f"[graphify extract] incremental scan of {target}");
            detection = _detect_incremental(
                target,
                manifest_path=`str(manifest_path),
                google_workspace=google_workspace or None,
                extra_excludes=_effective_excludes or None,
                gitignore=_effective_gitignore,
                cache_root=out_root,
            );
            files_by_type = detection.get("files", {});
            new_by_type: any = detection.get("new_files", {});
            code_files = [Path(p) for p in new_by_type.get("code", [])];
            doc_files = [Path(p) for p in new_by_type.get("document", [])];
            paper_files = [Path(p) for p in new_by_type.get("paper", [])];
            image_files = [Path(p) for p in new_by_type.get("image", [])];
            video_files = [Path(p) for p in new_by_type.get("video", [])];
            deleted_files = `list(detection.get("deleted_files", []));
            excluded_files = `list(detection.get("excluded_files", []));
            unchanged_total = sum(len(v) for v in detection.get("unchanged_files", {}).values());
            _seen_files: any = {f for _fl in files_by_type.values() for f in _fl};
            _seen_files.update(detection.get("unclassified", []));
            graph_stale_sources = _stale_graph_sources(
                existing_graph_path, target, _seen_files, detection=detection
            );
            _healed_sources: any = _zero_node_stamped_code_sources(
                existing_graph_path,
                target,
                detection.get("unchanged_files", {}).get("code", []),
                manifest_path,
            );
            if _healed_sources {
                print(
                    f"[graphify extract] re-queuing {len(_healed_sources)} manifest-stamped code file(s) with no nodes in graph.json (prior failed extraction, #2543)",
                );
                code_files.extend(Path(p) for p in _healed_sources);
            }
            _unchanged_sem: list[str] = [];
            for _k in ("document", "paper", "image") {
                _unchanged_sem.extend(detection.get("unchanged_files", {}).get(_k, []));
            }
            _healed_sem_sources: any = _zero_node_stamped_semantic_sources(
                existing_graph_path, target, _unchanged_sem
            );
            if _healed_sem_sources {
                print(
                    f"[graphify extract] re-queuing {len(_healed_sem_sources)} manifest-stamped semantic file(s) with no nodes or hyperedges in graph.json (prior empty/edge-only extraction, #2927)",
                );
                _healed_sem_set: any = `set(_healed_sem_sources);
                _p: any;
                for _p in detection.get("unchanged_files", {}).get("document", []) {
                    if _p in _healed_sem_set {
                        doc_files.append(Path(_p));
                    }
                }
                for _p in detection.get("unchanged_files", {}).get("paper", []) {
                    if _p in _healed_sem_set {
                        paper_files.append(Path(_p));
                    }
                }
                for _p in detection.get("unchanged_files", {}).get("image", []) {
                    if _p in _healed_sem_set {
                        image_files.append(Path(_p));
                    }
                }
            }
        } else {
            print(f"[graphify extract] scanning {target}");
            detection = _detect(
                target,
                google_workspace=google_workspace or None,
                extra_excludes=_effective_excludes or None,
                cache_root=out_root,
                gitignore=_effective_gitignore,
            );
            files_by_type = detection.get("files", {});
            code_files = [Path(p) for p in files_by_type.get("code", [])];
            doc_files = [Path(p) for p in files_by_type.get("document", [])];
            paper_files = [Path(p) for p in files_by_type.get("paper", [])];
            image_files = [Path(p) for p in files_by_type.get("image", [])];
            video_files = [Path(p) for p in files_by_type.get("video", [])];
            deleted_files = [];
            excluded_files = [];
            graph_stale_sources = [];
            unchanged_total = 0;
            if existing_graph_path.exists() {
                _seen_files = {f for _fl in files_by_type.values() for f in _fl};
                _seen_files.update(detection.get("unclassified", []));
                graph_stale_sources = _stale_graph_sources(
                    existing_graph_path, target, _seen_files, detection=detection
                );
            }
        }

        semantic_files: any = doc_files + paper_files + image_files;
        if code_only and semantic_files {
            print(
                f"[graphify extract] --code-only: skipping {len(semantic_files)} non-code file(s) ({len(doc_files)} docs, {len(paper_files)} papers, {len(image_files)} images) — no LLM extraction",
            );
            semantic_files = [];
            doc_files = [];
            paper_files = [];
            image_files = [];
        }
        if deep_mode and incremental_mode and not code_only {
            _deep_all: any = [
                Path(p)
                for _ftype in ("document", "paper", "image")
                for p in files_by_type.get(_ftype, [])
            ];
            if len(_deep_all) != len(semantic_files) {
                print(
                    f"[graphify extract] deep mode: widening semantic pass from {len(semantic_files)} changed to {len(_deep_all)} live doc/paper/image file(s); the deep semantic cache decides what is re-extracted",
                );
            }
            semantic_files = _deep_all;
        }
        if incremental_mode {
            _excl_note: any = f"; {len(excluded_files)} excluded" if excluded_files else "";
            print(
                f"[graphify extract] {len(code_files)} code, {len(doc_files)} docs, {len(paper_files)} papers, {len(image_files)} images changed; {unchanged_total} unchanged; {len(deleted_files)} deleted{_excl_note}",
            );
        } else {
            print(
                f"[graphify extract] found {len(code_files)} code, {len(doc_files)} docs, {len(paper_files)} papers, {len(image_files)} images",
            );
        }
        _ignored: any = sorted(detection.get("ignored", []));
        if _ignored {
            _examples: any = [];
            for _entry in _ignored[:3] {
                _rel: any = Path(os.path.relpath(_entry, target)).as_posix();
                if _entry.endswith(os.sep) {
                    _rel += "/";
                }
                _examples.append(repr(_rel));
            }
            _more: any = f" (+{len(_ignored) - 3} more)" if len(_ignored) > 3 else "";
            print(
                "[graphify extract] "
                    + format(len(_ignored), "")
                    + " path(s) ignored by ignore rules (pruned directories count once): "
                    + format(", ".join(_examples), "")
                    + format(_more, ""),
            );
            _vcs_hint: any = "--no-gitignore bypasses VCS ignore rules only"
                if _effective_gitignore
                else "VCS ignore rules disabled";
            print(
                f"[graphify extract] Review ignore rules if source is missing; {_vcs_hint}; .graphifyignore and --exclude still apply.",
            );
        }
        _unclassified: any = detection.get("unclassified", [])
            if isinstance(detection, `dict)
            else [];
        if _unclassified {
            _names: any = ", ".join(sorted({Path(p).name for p in _unclassified})[:6]);
            _more = f" (+{len(_unclassified) - 6} more)" if len(_unclassified) > 6 else "";
            print(
                f"[graphify extract] {len(_unclassified)} file(s) not classified (no supported extension or shebang), skipped: {_names}{_more}",
            );
        }
        _unclassified_warning: any = detection.get("unclassified_warning")
            if isinstance(detection, `dict)
            else None;
        if _unclassified_warning {
            print(f"[graphify extract] warning: {_unclassified_warning}");
        }
        _sensitive: any = detection.get("skipped_sensitive", [])
            if isinstance(detection, `dict)
            else [];
        _sec: any = [s for s in _sensitive if " [" not in s];
        if _sec {
            _snames: any = ", ".join(sorted({Path(p).name for p in _sec})[:6]);
            _smore: any = f" (+{len(_sec) - 6} more)" if len(_sec) > 6 else "";
            print(
                f"[graphify extract] {len(_sec)} file(s) skipped as potentially sensitive (rename or move if wrongly flagged): {_snames}{_smore}",
            );
        }
        if video_files {
            print(
                f"[graphify extract] {len(video_files)} audio/video file(s) detected but not extracted (headless extract has no transcription step)",
            );
        }
        stages.mark("detect");
        BACKENDS: any = importlib.import_module("graphify.llm").BACKENDS;
        _detect_backend_with_source: any = importlib.import_module(
            "graphify.llm"
        ).detect_backend_with_source;
        _backend_disabled_by_env: any = importlib.import_module(
            "graphify.llm"
        ).backend_disabled_by_env;
        _estimate_cost: any = importlib.import_module("graphify.llm").estimate_cost;
        _extract_corpus_parallel: any = importlib.import_module(
            "graphify.llm"
        ).extract_corpus_parallel;
        _format_backend_env_keys: any = importlib.import_module(
            "graphify.llm"
        )._format_backend_env_keys;
        _get_backend_api_key: any = importlib.import_module("graphify.llm")._get_backend_api_key;
        needs_llm: any = `bool(semantic_files) or dedup_llm;
        backend_source: any = None;
        if backend is None and needs_llm and _backend_disabled_by_env() {
            skipped: any = len(semantic_files);
            print(
                f"[graphify extract] GRAPHIFY_BACKEND=none: skipping LLM work ({skipped} non-code file(s) and LLM dedup kept out); indexing code only.",
            );
            semantic_files = [];
            doc_files = [];
            paper_files = [];
            image_files = [];
            dedup_llm = False;
            needs_llm = False;
        } elif backend is None and needs_llm {
            (backend, backend_source) = _detect_backend_with_source() as any;
            if backend and backend_source.startswith("auto-detected") {
                print(
                    f"[graphify] using backend '{backend}' ({backend_source}); pass --backend or set GRAPHIFY_BACKEND to choose explicitly, or GRAPHIFY_BACKEND=none to disable LLM work.",
                );
            }
        }
        if backend is not None and backend not in BACKENDS {
            print(
                "error: unknown backend '"
                    + format(backend, "")
                    + "'. Available: "
                    + format(", ".join(sorted(BACKENDS)), ""),
                file=sys.stderr,
            );
            sys.exit(1);
        }
        if needs_llm {
            if backend is None {
                reasons: any = [];
                if semantic_files {
                    reasons.append(
                        f"{len(semantic_files)} doc/paper/image file(s) need semantic extraction"
                    );
                }
                if dedup_llm {
                    reasons.append("--dedup-llm was passed");
                }
                hint: any = "";
                if semantic_files {
                    hint = " Or pass --code-only to index just the code (local AST, no key) and skip the non-code files.";
                }
                print(
                    "error: no LLM API key found ("
                        + "; ".join(reasons)
                        + "). Set GEMINI_API_KEY or GOOGLE_API_KEY (gemini), MOONSHOT_API_KEY (kimi), ANTHROPIC_API_KEY (claude), OPENAI_API_KEY (openai), DEEPSEEK_API_KEY (deepseek), or pass --backend. A code-only corpus needs no key."
                        + hint,
                    file=sys.stderr,
                );
                sys.exit(1);
            }
            if backend == "ollama" {
                _validate_ollama_base_url: any = importlib.import_module(
                    "graphify.llm"
                )._validate_ollama_base_url;
                _oll_url: any = os.environ.get(
                    "OLLAMA_BASE_URL", BACKENDS["ollama"].get("base_url", "")
                );
                try {
                    _validate_ollama_base_url(_oll_url, warn=False);
                } except ValueError as exc {
                    print(f"error: {exc}", file=sys.stderr);
                    sys.exit(2);
                }
            }
            if not _get_backend_api_key(backend) {
                allow_no_key: any = False;
                if backend == "ollama" {
                    import from urllib.parse { urlparse }
                    ollama_url: any = os.environ.get(
                        "OLLAMA_BASE_URL", BACKENDS["ollama"].get("base_url", "")
                    );
                    try {
                        host: any = (urlparse(ollama_url).hostname or "").lower();
                    } except Exception {
                        host = "";
                    }
                    allow_no_key = host in ("localhost", "127.0.0.1", "::1")
                        or host.startswith("127.");
                } elif backend == "bedrock" {
                    allow_no_key = `bool(
                        os.environ.get("AWS_PROFILE")
                            or os.environ.get("AWS_REGION")
                            or os.environ.get("AWS_DEFAULT_REGION")
                            or os.environ.get("AWS_ACCESS_KEY_ID"),
                    );
                } elif backend == "claude-cli" {
                    import shutil as _shutil;
                    allow_no_key = _shutil.which("claude") is not None;
                    if not allow_no_key {
                        print(
                            "error: backend 'claude-cli' requires the `claude` CLI on $PATH (install Claude Code and run `claude` once to authenticate).",
                            file=sys.stderr,
                        );
                        sys.exit(1);
                    }
                }
                if not allow_no_key {
                    print(
                        f"error: backend '{backend}' requires {_format_backend_env_keys(backend)} to be set.",
                        file=sys.stderr,
                    );
                    sys.exit(1);
                }
            }
        }
        if not code_only and semantic_files {
            _write_build_cfg(graphify_out, excludes=None, code_only=False);
        }
        _extraction_incomplete: any = False;
        if detection.get("walk_errors") {
            _extraction_incomplete = True;
        }

        if incremental_mode {
            refresh_terraform_paths: any = importlib.import_module(
                "graphify.extractors.terraform"
            ).refresh_terraform_paths;
            code_files = refresh_terraform_paths(
                code_files,
                [Path(p) for p in files_by_type.get("code", [])],
                [Path(p) for p in [*deleted_files, *excluded_files, *graph_stale_sources]],
            );
        }
        ast_result: dict = {"nodes": [], "edges": [], "input_tokens": 0, "output_tokens": 0};
        if code_files or incremental_mode and existing_graph_path.exists() {
            _ast_extract: any = importlib.import_module("graphify.extract").extract;
            ast_kwargs: dict = {"cache_root": out_root, "root": target};
            if cli_max_workers is not None {
                ast_kwargs["max_workers"] = cli_max_workers;
            }
            if incremental_mode and existing_graph_path.exists() {
                _ctx_nodes: list[dict] = [];
                _ctx_edges: list[dict] = [];
                try {
                    _ctx_is_ast_tier: any = importlib.import_module("graphify.build")._is_ast_tier;
                    check_graph_file_size_cap: any = importlib.import_module(
                        "graphify.security"
                    ).check_graph_file_size_cap;
                    check_graph_file_size_cap(existing_graph_path);
                    _ctx_graph: any = json.loads(existing_graph_path.read_text(encoding="utf-8"));
                    _ctx_root = Path(os.path.abspath(target));

                    def _ctx_identity(source_file) -> str | None {
                        if not source_file {
                            return None;
                        }
                        _p: any = Path(`str(source_file));
                        if not _p.is_absolute() {
                            _p = _ctx_root / _p;
                        }
                        return Path(os.path.abspath(_p)).as_posix();
                    }

                    _ctx_live: any = {
                        _ctx_identity(f)
                        for _flist in detection.get("unchanged_files", {}).values()
                        for f in _flist
                    };
                    _ctx_live.discard(None);
                    _cpp_reconciliation_paths: any = importlib.import_module(
                        "graphify.extractors.resolution"
                    )._cpp_reconciliation_paths;
                    code_files = _cpp_reconciliation_paths(
                        `list(code_files),
                        _ctx_graph.get("nodes", []),
                        _ctx_root,
                        available_paths=[Path(p) for p in files_by_type.get("code", [])],
                        changed_paths=[
                            Path(p)
                            for p in [*deleted_files, *excluded_files, *graph_stale_sources]
                        ],
                    );
                    _ctx_live.difference_update(_ctx_identity(p) for p in code_files);
                    for _node in _ctx_graph.get("nodes", []) {
                        if not _node.get("id") or not _ctx_is_ast_tier(_node) {
                            continue;
                        }
                        _sf: any = _node.get("source_file");
                        if not _sf or _ctx_identity(_sf) not in _ctx_live {
                            continue;
                        }
                        _ctx_node: any = {
                            "id": _node["id"],
                            "label": _node.get("label"),
                            "source_file": _sf,
                            "file_type": _node.get("file_type"),
                            "type": _node.get("type"),
                        };
                        for _marker in (
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
                            if _node.get(_marker)
                                or _marker.startswith("_cpp_")
                                    and isinstance(_node.get(_marker), (`dict, `list))
                            {
                                _ctx_node[_marker] = _node[_marker];
                            }
                        }
                        _metadata: any = _node.get("metadata");
                        if isinstance(_metadata, `dict) {
                            _fwd_metadata: any = {
                                key: _metadata[key]
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
                                if key in _metadata
                            };
                            if _fwd_metadata {
                                _ctx_node["metadata"] = _fwd_metadata;
                            }
                        }
                        _ctx_nodes.append(_ctx_node);
                    }
                    for _edge in _ctx_graph.get("links", _ctx_graph.get("edges", [])) {
                        if _edge.get("relation")
                            not in ("contains", "method", "inherits", "imports", "imports_from")
                        {
                            if not (
                                _edge.get("relation") == "references"
                                and _edge.get("context") == "return_type"
                            ) {
                                continue;
                            }
                        }
                        if not _ctx_is_ast_tier(_edge) {
                            continue;
                        }
                        _sf = _edge.get("source_file");
                        if not _sf or _ctx_identity(_sf) not in _ctx_live {
                            continue;
                        }
                        _ctx_edge: any = {
                            "source": _edge.get("source"),
                            "target": _edge.get("target"),
                            "relation": _edge.get("relation"),
                            "source_file": _sf,
                        };
                        if _edge.get("_cpp_include_proof")
                            and not (_edge.get("metadata") or {}).get("cpp_conditions")
                        {
                            _ctx_edge["_cpp_include_proof"] = True;
                        }
                        if _edge.get("relation") == "imports"
                            and isinstance(_edge.get("source_location"), `str)
                        {
                            _ctx_edge["source_location"] = _edge["source_location"];
                        }
                        if _edge.get("context") == "return_type" {
                            _ctx_edge["context"] = "return_type";
                        }
                        _edge_metadata: any = _edge.get("metadata");
                        if isinstance(_edge_metadata, `dict)
                            and isinstance(_edge_metadata.get("ruby_superclass_ref"), `str)
                        {
                            _ctx_edge["metadata"] = {
                                "ruby_superclass_ref": _edge_metadata["ruby_superclass_ref"],
                            };
                            _lexical_scopes: any = _edge_metadata.get("ruby_lexical_scopes");
                            if isinstance(_lexical_scopes, `list)
                                and all(isinstance(_scope, `str) for _scope in _lexical_scopes)
                            {
                                _ctx_edge["metadata"]["ruby_lexical_scopes"] = `list(
                                    _lexical_scopes
                                );
                            }
                        }
                        _ctx_edges.append(_ctx_edge);
                    }
                } except Exception {
                    (_ctx_nodes, _ctx_edges) = ([], []);
                }
                _ctx_graph = None;
                if _ctx_nodes {
                    ast_kwargs["resolution_context_nodes"] = _ctx_nodes;
                }
                if _ctx_edges {
                    ast_kwargs["resolution_context_edges"] = _ctx_edges;
                }
                del _ctx_nodes, _ctx_edges;
            }
            print(f"[graphify extract] AST extraction on {len(code_files)} code files...");
            try {
                ast_result = _ast_extract(code_files, **ast_kwargs) if code_files else ast_result;
            } except Exception as exc {
                print(f"[graphify extract] AST extraction failed: {exc}", file=sys.stderr);
                if not cli_allow_partial {
                    sys.exit(1);
                }
                ast_result = {"nodes": [], "edges": [], "input_tokens": 0, "output_tokens": 0};
                _extraction_incomplete = True;
            }
            del ast_kwargs;
        }
        stages.mark("AST extract");
        check_semantic_cache: any = importlib.import_module("graphify.cache").check_semantic_cache;
        _prune_semantic_cache: any = importlib.import_module("graphify.cache").prune_semantic_cache;
        _save_semantic_cache: any = importlib.import_module("graphify.cache").save_semantic_cache;
        _scope_semantic_result: any = importlib.import_module(
            "graphify.cache"
        ).scope_semantic_result;
        sem_result: dict = {
            "nodes": [],
            "edges": [],
            "hyperedges": [],
            "input_tokens": 0,
            "output_tokens": 0,
        };
        _partial_semantic_files: set[str] = set[any]();
        sem_cache_hits: any = 0;
        sem_cache_misses: any = 0;
        _cached_semantic_paths: list[str] = [];
        uncached_paths: list[str] = [];
        sem_cache_mode: any = "deep" if deep_mode else None;
        _sem_prompt_for: any = importlib.import_module("graphify.llm")._extraction_system;
        sem_prompt: any = _sem_prompt_for(deep=deep_mode);
        if semantic_files {
            sem_paths_str: any = [`str(p) for p in semantic_files];
            if force {
                cached_nodes: any;
                cached_edges: any;
                cached_hyperedges: any;
                (cached_nodes, cached_edges, cached_hyperedges) = ([], [], []);
                uncached_paths = `list(sem_paths_str);
            } else {
                (
                    cached_nodes,
                    cached_edges,
                    cached_hyperedges,
                    uncached_paths,
                ) = check_semantic_cache(
                    sem_paths_str,
                    root=target,
                    cache_root=out_root,
                    mode=sem_cache_mode,
                    prompt=sem_prompt,
                ) as any;
            }
            sem_cache_hits = len(semantic_files) - len(uncached_paths);
            sem_cache_misses = len(uncached_paths);
            _uncached_set: any = `set(uncached_paths);
            _cached_semantic_paths = [p for p in sem_paths_str if p not in _uncached_set];
            sem_result["nodes"].extend(cached_nodes);
            sem_result["edges"].extend(cached_edges);
            sem_result["hyperedges"].extend(cached_hyperedges);
            if sem_cache_hits {
                print(
                    f"[graphify extract] semantic cache: {sem_cache_hits} hit / {sem_cache_misses} miss",
                );
            }

            if uncached_paths {
                _via: any = f"{backend}" + (f", {backend_source}" if backend_source else "");
                print(
                    f"[graphify extract] semantic extraction on {len(uncached_paths)} files via {_via}...",
                );
                corpus_kwargs: dict = {
                    "backend": backend,
                    "model": model,
                    "root": target,
                    "cache_root": out_root,
                };
                if deep_mode {
                    corpus_kwargs["deep_mode"] = True;
                }
                if cli_token_budget is not None {
                    corpus_kwargs["token_budget"] = cli_token_budget;
                }
                if cli_max_concurrency is not None {
                    corpus_kwargs["max_concurrency"] = cli_max_concurrency;
                }
                _chunk_stats = {"total": 0, "succeeded": 0};
                def _progress(idx: int, total: int, _result: dict) {
                    _chunk_stats["total"] = total;
                    _chunk_stats["succeeded"] += 1;
                    print(f"[graphify extract] chunk {idx + 1}/{total} done", flush=True);
                }
                corpus_kwargs["on_chunk_done"] = _progress;

                try {
                    fresh = _extract_corpus_parallel(
                        [Path(p) for p in uncached_paths], **corpus_kwargs
                    );
                } except ImportError as exc {
                    print(f"error: {exc}", file=sys.stderr);
                    sys.exit(1);
                } except Exception as exc {
                    print(f"[graphify extract] semantic extraction failed: {exc}", file=sys.stderr);
                    fresh = {
                        "nodes": [],
                        "edges": [],
                        "hyperedges": [],
                        "input_tokens": 0,
                        "output_tokens": 0,
                    };
                    _extraction_incomplete = True;
                }
                if uncached_paths and _chunk_stats["succeeded"] == 0 {
                    print(
                        f"[graphify extract] error: all semantic chunks failed for backend '{backend}' ({len(uncached_paths)} uncached files) - see per-chunk errors above. If you see 'requires the X package', run `pip install X` and retry.",
                        file=sys.stderr,
                    );
                    sys.exit(1);
                }
                if _chunk_stats["total"] and _chunk_stats["succeeded"] < _chunk_stats["total"] {
                    _extraction_incomplete = True;
                }
                _dropped_files: any;
                _dropped_items: any;
                (_dropped_files, _dropped_items) = _scope_semantic_result(
                    fresh, target, uncached_paths
                ) as any;
                if _dropped_files {
                    print(
                        "[graphify extract] dropped "
                            + format(_dropped_items, "")
                            + " out-of-scope item(s) attributed to "
                            + format(len(_dropped_files), "")
                            + " file(s) not dispatched this run: "
                            + format(", ".join(sorted(_dropped_files)), ""),
                    );
                }
                _partial_sf: any = importlib.import_module("graphify.llm")._partial_source_files;
                _strip_partial: any = importlib.import_module(
                    "graphify.llm"
                )._strip_partial_markers;
                _partial_semantic_files = `set(_partial_sf(fresh));
                _omitted_files: any = `list(fresh.get("uncovered_files") or []);
                if _omitted_files or _partial_semantic_files {
                    _extraction_incomplete = True;
                    _coverage_note: any = "";
                    if _omitted_files and not _partial_semantic_files {
                        _coverage_note = " None of this run's chunks came back truncated — the model returned complete, well-formed responses that simply did not address every file. Retrying with the same --token-budget will likely omit the same files again; try a smaller --token-budget to split the corpus into more, smaller chunks.";
                    }
                    print(
                        f"[graphify extract] semantic extraction is incomplete: {len(_omitted_files)} dispatched file(s) produced no nodes and {len(_partial_semantic_files)} came back truncated or hollow.{_coverage_note} The shrink guard stays armed for this write; pass --allow-partial to overwrite a larger existing graph anyway.",
                        file=sys.stderr,
                    );
                }
                try {
                    _save_semantic_cache(
                        fresh.get("nodes", []),
                        fresh.get("edges", []),
                        fresh.get("hyperedges", []),
                        root=target,
                        cache_root=out_root,
                        allowed_source_files=uncached_paths,
                        mode=sem_cache_mode,
                        prompt=sem_prompt,
                        partial_source_files=_partial_semantic_files or None,
                    );
                } except Exception as exc {
                    print(
                        f"[graphify extract] warning: could not write semantic cache: {exc}",
                        file=sys.stderr,
                    );
                }
                _strip_partial(fresh);
                sem_result["nodes"].extend(fresh.get("nodes", []));
                sem_result["edges"].extend(fresh.get("edges", []));
                sem_result["hyperedges"].extend(fresh.get("hyperedges", []));
                sem_result["input_tokens"] += fresh.get("input_tokens", 0);
                sem_result["output_tokens"] += fresh.get("output_tokens", 0);
            }
        }
        try {
            _file_hash: any = importlib.import_module("graphify.cache").file_hash;
            _live_hashes: set[str] = set[any]();
            for _kind in ("document", "paper", "image") {
                for _fp in files_by_type.get(_kind, []) {
                    _abs: any = Path(_fp);
                    if not _abs.is_absolute() {
                        _abs = Path(target) / _abs;
                    }
                    if not _abs.is_file() {
                        continue;
                    }
                    try {
                        _live_hashes.add(_file_hash(_abs, target, cache_root=out_root));
                    } except OSError {}
                }
            }
            if has_path {
                _prune_semantic_cache(out_root, _live_hashes);
            }
        } except Exception as exc {
            print(
                f"[graphify extract] warning: could not prune semantic cache: {exc}",
                file=sys.stderr,
            );
        }
        stages.mark("semantic extract");

        pg_result: dict = {"nodes": [], "edges": []};
        if cli_postgres_dsn is not None {
            introspect_postgres: any = importlib.import_module(
                "graphify.pg_introspect"
            ).introspect_postgres;
            print(f"[graphify extract] introspecting PostgreSQL schema...");
            try {
                pg_result = introspect_postgres(cli_postgres_dsn);
            } except (ConnectionError, ImportError) as exc {
                print(f"error: {exc}", file=sys.stderr);
                sys.exit(1);
            }
            print(
                "[graphify extract] PostgreSQL: "
                    + format(len(pg_result["nodes"]), "")
                    + " nodes, "
                    + format(len(pg_result["edges"]), "")
                    + " edges",
            );
        }

        cargo_result: dict = {"nodes": [], "edges": []};
        if cli_cargo {
            introspect_cargo: any = importlib.import_module(
                "graphify.cargo_introspect"
            ).introspect_cargo;
            print("[graphify extract] introspecting Cargo workspace...");
            try {
                cargo_result = introspect_cargo(target);
            } except FileNotFoundError {
                print(
                    "[graphify extract] --cargo: no Cargo.toml at scan root, skipping crate edges"
                );
            } except (ConnectionError, ImportError, OSError) as exc {
                print(f"error: {exc}", file=sys.stderr);
                sys.exit(1);
            }
            print(
                "[graphify extract] Cargo: "
                    + format(len(cargo_result["nodes"]), "")
                    + " nodes, "
                    + format(len(cargo_result["edges"]), "")
                    + " edges",
            );
        }
        _stamp_sem: any = importlib.import_module("graphify.llm")._stamp_semantic_origin;
        _stamp_sem(sem_result);
        merged = {
            "nodes": `list(ast_result.get("nodes", []))
                + `list(sem_result.get("nodes", []))
                + `list(pg_result.get("nodes", []))
                + `list(cargo_result.get("nodes", [])),
            "edges": `list(ast_result.get("edges", []))
                + `list(sem_result.get("edges", []))
                + `list(pg_result.get("edges", []))
                + `list(cargo_result.get("edges", [])),
            "hyperedges": `list(sem_result.get("hyperedges", [])),
            "input_tokens": ast_result.get("input_tokens", 0) + sem_result.get("input_tokens", 0),
            "output_tokens": ast_result.get("output_tokens", 0)
                + sem_result.get("output_tokens", 0),
            "extracted_sources": `list(ast_result.get("extracted_sources", [])),
            "failed_sources": `list(ast_result.get("failed_sources", [])),
        };

        graph_json_path: any = graphify_out / "graph.json";
        analysis_path = graphify_out / ".graphify_analysis.json";
        _failed_ast_sources: any = `list(ast_result.get("failed_sources") or []);
        if _failed_ast_sources {
            _existing_counts_by_source: any = importlib.import_module(
                "graphify.export"
            ).existing_graph_node_counts_by_source;
            _shrink_malformed: any = importlib.import_module("graphify.export").MALFORMED_GRAPH;
            _existing_counts: any = _existing_counts_by_source(graph_json_path);
            if _existing_counts is _shrink_malformed {
                _protected_failures: any = `list(_failed_ast_sources);
            } else {
                def _shrink_path_key(value) -> str {
                    p: any = Path(value);
                    if not p.is_absolute() {
                        p = Path(target) / p;
                    }
                    try {
                        return os.path.normcase(`str(p.resolve()));
                    } except (OSError, RuntimeError) {
                        return os.path.normcase(os.path.abspath(`str(p)));
                    }
                }

                _counts_by_key: any = {
                    _shrink_path_key(sf): n
                    for (sf, n) in (_existing_counts or {}).items()
                    if n
                };
                _protected_failures = [
                    sf
                    for sf in _failed_ast_sources
                    if _counts_by_key.get(_shrink_path_key(sf))
                ];
            }
            if _protected_failures {
                _extraction_incomplete = True;
            }
            print(
                "[graphify extract] AST extraction incomplete for "
                    + format(len(_failed_ast_sources), "")
                    + " source(s): "
                    + format(", ".join(sorted(_failed_ast_sources)), "")
                    + "; failed sources will not replace saved AST records and remain pending for retry.",
                file=sys.stderr,
            );
        }
        _ast_empty_sources: any = `list(ast_result.get("skipped_sources") or []);
        _manifest_files: any = _stamped_manifest_files(
            files_by_type,
            sem_result,
            target,
            partial_source_files=_partial_semantic_files,
            failed_ast_sources=_failed_ast_sources,
        );
        _stamped_semantic: any = {f for _flist in _manifest_files.values() for f in _flist};
        _cleared_semantic: any = {`str(p) for p in semantic_files} - _stamped_semantic;
        _cleared_ast: any = `set(_failed_ast_sources);
        _scan_corpus: any = {f for _fl in files_by_type.values() for f in _fl}
            if has_path
            else None;

        def _invalidate_file_manifest_for_db_graph {
            if has_path {
                return;
            }
            try {
                manifest_path.unlink(missing_ok=True);
            } except OSError as exc {
                print(f"error: could not invalidate file manifest: {exc}", file=sys.stderr);
                sys.exit(1);
            }
        }

        if no_cluster {
            _dedupe_edges: any = importlib.import_module("graphify.build").dedupe_edges;
            _dedupe_nodes: any = importlib.import_module("graphify.build").dedupe_nodes;
            _has_parallel_links: any = importlib.import_module("graphify.build").has_parallel_links;
            _backup: any = importlib.import_module("graphify.export").backup_if_protected;
            _existing_graph_node_count: any = importlib.import_module(
                "graphify.export"
            ).existing_graph_node_count;
            if incremental_mode
                and not code_files
                and not semantic_files
                and not deleted_files
                and not pg_result.get("nodes")
                and not pg_result.get("edges")
                and not cargo_result.get("nodes")
                and not cargo_result.get("edges")
            {
                if graph_stale_sources {
                    _n_pruned: any = _prune_graph_json_sources(
                        existing_graph_path, graph_stale_sources
                    );
                    if _n_pruned {
                        print(
                            f"[graphify extract] pruned {_n_pruned} node(s) from {len(graph_stale_sources)} source file(s) no longer in the scan (deleted or excluded).",
                        );
                    }
                }
                print(
                    "[graphify extract] no incremental changes detected (--no-cluster); outputs left untouched.",
                );
                try {
                    _save_manifest(
                        _manifest_files,
                        manifest_path=`str(manifest_path),
                        kind="both",
                        root=target,
                        scan_corpus=_scan_corpus,
                        clear_semantic=_cleared_semantic,
                        clear_ast=_cleared_ast or None,
                        ast_empty=_ast_empty_sources or None,
                    );
                } except Exception as exc {
                    print(
                        f"[graphify extract] warning: could not write manifest: {exc}",
                        file=sys.stderr,
                    );
                }
                stages.total();
                sys.exit(0);
            }

            if merge_existing_graph {
                _merge_raw_extraction: any = importlib.import_module(
                    "graphify.build"
                ).merge_raw_extraction;
                _raw_prune_sources: list[str] = `list(deleted_files);
                _src: any;
                for _src in `list(excluded_files) + graph_stale_sources {
                    if _src not in _raw_prune_sources {
                        _raw_prune_sources.append(_src);
                    }
                }
                try {
                    merged = _merge_raw_extraction(
                        merged,
                        graph_path=existing_graph_path,
                        prune_sources=_raw_prune_sources or None,
                        root=target,
                    );
                } except RuntimeError as exc {
                    print(f"error: {exc}", file=sys.stderr);
                    sys.exit(1);
                }
                _shrink: any = _handle_unverified_semantic_shrink(
                    merged.get("_unverified_semantic_shrink"),
                    cli_allow_partial=cli_allow_partial,
                    files_by_type=files_by_type,
                    sem_result=sem_result,
                    target=target,
                    partial_semantic_files=_partial_semantic_files,
                    failed_ast_sources=_failed_ast_sources,
                    semantic_files=semantic_files,
                    cached_semantic_files=_cached_semantic_paths,
                    sem_cache_mode=sem_cache_mode,
                    sem_prompt=sem_prompt,
                    cache_root=out_root,
                );
                if _shrink is not None and _shrink[0] {
                    _extraction_incomplete = True;
                    _manifest_files = _shrink[1];
                    _stamped_semantic = {f for _flist in _manifest_files.values() for f in _flist};
                    _cleared_semantic = _shrink[2];
                }
            }
            merged["nodes"] = _dedupe_nodes(merged["nodes"]);
            merged["edges"] = _dedupe_edges(merged["edges"]);
            merged["multigraph"] = _has_parallel_links(
                merged["edges"], directed=`bool(merged.get("directed", False))
            );
            _disamb_labels: any = importlib.import_module(
                "graphify.build"
            ).disambiguate_file_labels_in_nodes;
            _disamb_labels(merged["nodes"]);
            _qualify_cs_methods: any = importlib.import_module(
                "graphify.build"
            ).qualify_csharp_method_labels_in_nodes;
            _qualify_cs_methods(merged["nodes"], merged["edges"]);
            _finalize_raw_graph_endpoints: any = importlib.import_module(
                "graphify.build"
            ).finalize_raw_graph_endpoints;
            _finalize_raw_graph_endpoints(merged);
            _node_sf: any = {n.get("id"): n.get("source_file") for n in merged["nodes"]};
            for _e in merged["edges"] {
                if not _e.get("source_file") {
                    _e["source_file"] = _node_sf.get(_e.get("source"))
                        or _node_sf.get(_e.get("target"))
                        or "";
                }
            }
            if _extraction_incomplete and not cli_allow_partial {
                _shrink_malformed: any = importlib.import_module("graphify.export").MALFORMED_GRAPH;
                _existing_n: any = _existing_graph_node_count(graph_json_path);
                _malformed: any = _existing_n is _shrink_malformed;
                _shrinks: any = isinstance(_existing_n, `int)
                    and operator.lt(len(merged["nodes"]), _existing_n);
                if _malformed or _shrinks {
                    _detail: any = f"the existing {graph_json_path} is present but unparseable (corrupt or a mid-write), so a shrink cannot be ruled out"
                        if _malformed
                        else "smaller than the existing "
                            + format(graph_json_path, "")
                            + " ("
                            + format(len(merged["nodes"]), "")
                            + " < "
                            + format(_existing_n, "")
                            + " nodes)";
                    print(
                        f"[graphify extract] error: extraction was incomplete (an AST/semantic pass failed) and the resulting --no-cluster graph is {_detail}. Refusing to overwrite a complete graph with a partial one. Re-run after fixing the failures, or pass --allow-partial to overwrite anyway.",
                        file=sys.stderr,
                    );
                    sys.exit(1);
                }
            }
            _backup(graphify_out);
            _invalidate_file_manifest_for_db_graph();
            write_json_atomic: any = importlib.import_module("graphify.paths").write_json_atomic;
            _RUN_ONLY_KEYS: any = importlib.import_module(
                "graphify.extract"
            ).RUN_ONLY_EXTRACTION_KEYS;
            write_json_atomic(
                graph_json_path,
                {k: v for (k, v) in merged.items() if k not in _RUN_ONLY_KEYS},
                compact=True,
            );
            try {
                (graphify_out / ".graphify_root").write_text(
                    `str(Path(target).resolve()), encoding="utf-8"
                );
            } except OSError {}
            stages.mark("write");
            cost: any = _estimate_cost(backend, merged["input_tokens"], merged["output_tokens"]);
            print(
                "[graphify extract] wrote "
                    + format(graph_json_path, "")
                    + " — "
                    + format(len(merged["nodes"]), "")
                    + " nodes, "
                    + format(len(merged["edges"]), "")
                    + " edges (no clustering)",
            );
            if merged["input_tokens"] or merged["output_tokens"] {
                print(
                    "[graphify extract] tokens: "
                        + format(merged["input_tokens"], ",")
                        + " in / "
                        + format(merged["output_tokens"], ",")
                        + " out, est. cost: $"
                        + format(cost, ".4f"),
                );
                _record_extract_cost(
                    graphify_out,
                    merged["input_tokens"],
                    merged["output_tokens"],
                    detection.get("total_files", 0),
                );
            }
            try {
                if has_path {
                    _save_manifest(
                        _manifest_files,
                        manifest_path=`str(manifest_path),
                        kind="both",
                        root=target,
                        scan_corpus=_scan_corpus,
                        clear_semantic=_cleared_semantic,
                        clear_ast=_cleared_ast or None,
                        ast_empty=_ast_empty_sources or None,
                    );
                }
            } except Exception as exc {
                print(
                    f"[graphify extract] warning: could not write manifest: {exc}", file=sys.stderr
                );
            }
            if global_merge {
                _global_add: any = importlib.import_module("graphify.global_graph").global_add;
                _tag: any = global_repo_tag or target.name;
                try {
                    result = _global_add(graphify_out / "graph.json", _tag);
                    if result["skipped"] {
                        print(f"[graphify global] '{_tag}' unchanged since last add - skipped.");
                    } else {
                        print(
                            "[graphify global] '"
                                + format(_tag, "")
                                + "' merged into global graph (+"
                                + format(result["nodes_added"], "")
                                + " nodes, -"
                                + format(result["nodes_removed"], "")
                                + " pruned).",
                        );
                    }
                } except Exception as exc {
                    print(
                        f"[graphify global] warning: failed to merge into global graph: {exc}",
                        file=sys.stderr,
                    );
                }
            }
            stages.total();
            sys.exit(0);
        }
        _build: any = importlib.import_module("graphify.build").build;
        build_from_json: any = importlib.import_module("graphify.build").build_from_json;
        _build_merge: any = importlib.import_module("graphify.build").build_merge;
        cluster: any = importlib.import_module("graphify.cluster").cluster;
        score_all: any = importlib.import_module("graphify.cluster").score_all;
        to_json: any = importlib.import_module("graphify.export").to_json;
        god_nodes: any = importlib.import_module("graphify.analyze").god_nodes;
        surprising_connections: any = importlib.import_module(
            "graphify.analyze"
        ).surprising_connections;
        dedup_backend: any = backend if dedup_llm else None;
        if merge_existing_graph {
            _prune_sources: list[str] = `list(deleted_files);
            for _src in `list(excluded_files) + graph_stale_sources {
                if _src not in _prune_sources {
                    _prune_sources.append(_src);
                }
            }
            try {
                G = _build_merge(
                    [merged],
                    graph_path=existing_graph_path,
                    prune_sources=_prune_sources or None,
                    dedup=not no_dedup,
                    dedup_llm_backend=dedup_backend,
                    root=target,
                );
                _shrink = _handle_unverified_semantic_shrink(
                    G.graph.get("_unverified_semantic_shrink") if hasattr(G, "graph") else None,
                    cli_allow_partial=cli_allow_partial,
                    files_by_type=files_by_type,
                    sem_result=sem_result,
                    target=target,
                    partial_semantic_files=_partial_semantic_files,
                    failed_ast_sources=_failed_ast_sources,
                    semantic_files=semantic_files,
                    cached_semantic_files=_cached_semantic_paths,
                    sem_cache_mode=sem_cache_mode,
                    sem_prompt=sem_prompt,
                    cache_root=out_root,
                );
                if _shrink is not None and _shrink[0] {
                    _extraction_incomplete = True;
                    _manifest_files = _shrink[1];
                    _stamped_semantic = {f for _flist in _manifest_files.values() for f in _flist};
                    _cleared_semantic = _shrink[2];
                }
            } except ValueError as exc {
                print(f"[graphify extract] {exc}", file=sys.stderr);
                sys.exit(1);
            }
        } else {
            G = _build([merged], dedup=not no_dedup, dedup_llm_backend=dedup_backend, root=target);
        }
        stages.mark("build");
        value_: any = {};
        ast_result = value_;
        sem_result = value_;
        pg_result = value_;
        cargo_result = value_;
        fresh = value_;
        value__: any = [];
        cached_nodes = value__;
        cached_edges = value__;
        cached_hyperedges = value__;
        merged = {"input_tokens": merged["input_tokens"], "output_tokens": merged["output_tokens"]};
        if G.number_of_nodes() == 0 {
            print(
                "[graphify extract] graph is empty — extraction produced no nodes. Possible causes: all files skipped, binary-only corpus, or LLM returned no edges.",
                file=sys.stderr,
            );
            sys.exit(1);
        }

        communities = cluster(
            G,
            resolution=cli_resolution,
            exclude_hubs_percentile=cli_exclude_hubs,
            cache_dir=graphify_out,
        );
        stages.mark("cluster");
        cohesion = score_all(G, communities);
        try {
            gods = god_nodes(G, exclude_hubs_percentile=cli_exclude_hubs);
        } except Exception {
            gods = [];
        }
        try {
            surprises = surprising_connections(G, communities);
        } except Exception {
            surprises = [];
        }
        stages.mark("analyze");

        _backup: any = importlib.import_module("graphify.export").backup_if_protected;
        _backup(graphify_out);
        _invalidate_file_manifest_for_db_graph();
        _take_shrink_accounting: any = importlib.import_module(
            "graphify.build"
        ).take_shrink_accounting;
        _dedup_collapsed: any;
        _pruned_nodes: any;
        (_dedup_collapsed, _pruned_nodes) = _take_shrink_accounting(G) as any;
        _force_write: any = cli_allow_partial or not _extraction_incomplete;
        _dedup_shrink_counts: tuple[int, int] | None = None;
        if not _extraction_incomplete
            and not no_dedup
            and not cli_allow_dedup_shrink
            and _dedup_collapsed > 0
        {
            _existing_graph_node_count: any = importlib.import_module(
                "graphify.export"
            ).existing_graph_node_count;
            _existing_n = _existing_graph_node_count(graph_json_path);
            _new_n: any = G.number_of_nodes();
            if isinstance(_existing_n, `int) and _new_n < _existing_n - _pruned_nodes {
                _dedup_shrink_counts = (_existing_n, _new_n);
            }
        }
        if _dedup_shrink_counts is not None {
            _old_n: any;
            (_old_n, _new_n) = _dedup_shrink_counts as any;
            print(
                f"[graphify extract] error: dedup merged {_dedup_collapsed} node(s); writing would shrink the graph from {_old_n} nodes to {_new_n} nodes. Refusing to overwrite {graph_json_path}. Pass --allow-dedup-shrink to write the smaller graph.",
                file=sys.stderr,
            );
            sys.exit(1);
        }
        _gh: any = importlib.import_module("graphify.watch")._git_head;
        _wrote: any = to_json(
            G,
            communities,
            `str(graph_json_path),
            force=_force_write,
            built_at_commit=_gh(cwd=Path(target).resolve()),
        );
        if not _wrote {
            print(
                f"[graphify extract] error: extraction was incomplete (an AST/semantic pass failed) and the resulting graph is smaller than the existing {graph_json_path}. Refusing to overwrite a complete graph with a partial one. Re-run after fixing the failures, or pass --allow-partial to overwrite anyway.",
                file=sys.stderr,
            );
            sys.exit(1);
        }
        try {
            (graphify_out / ".graphify_root").write_text(
                `str(Path(target).resolve()), encoding="utf-8"
            );
        } except OSError {}
        stages.mark("export");
        if merged.get("output_tokens", 0) > 0 {
            (graphify_out / ".graphify_semantic_marker").write_text(
                json.dumps({"output_tokens": merged["output_tokens"]}), encoding="utf-8"
            );
        }
        if global_merge {
            _global_add: any = importlib.import_module("graphify.global_graph").global_add;
            _tag = global_repo_tag or target.name;
            try {
                result = _global_add(graphify_out / "graph.json", _tag);
                if result["skipped"] {
                    print(f"[graphify global] '{_tag}' unchanged since last add - skipped.");
                } else {
                    print(
                        "[graphify global] '"
                            + format(_tag, "")
                            + "' merged into global graph (+"
                            + format(result["nodes_added"], "")
                            + " nodes, -"
                            + format(result["nodes_removed"], "")
                            + " pruned).",
                    );
                }
            } except Exception as exc {
                print(
                    f"[graphify global] warning: failed to merge into global graph: {exc}",
                    file=sys.stderr,
                );
            }
        }
        analysis = {
            "communities": {`str(k): v for (k, v) in communities.items()},
            "cohesion": {`str(k): v for (k, v) in cohesion.items()},
            "gods": gods,
            "surprises": surprises,
            "tokens": {"input": merged["input_tokens"], "output": merged["output_tokens"]},
        };
        write_json_atomic: any = importlib.import_module("graphify.paths").write_json_atomic;
        write_json_atomic(analysis_path, analysis, indent=2);
        try {
            if has_path {
                _save_manifest(
                    _manifest_files,
                    manifest_path=`str(manifest_path),
                    kind="both",
                    root=target,
                    scan_corpus=_scan_corpus,
                    clear_semantic=_cleared_semantic,
                    clear_ast=_cleared_ast or None,
                    ast_empty=_ast_empty_sources or None,
                );
            }
        } except Exception as exc {
            print(f"[graphify extract] warning: could not write manifest: {exc}", file=sys.stderr);
        }

        cost = _estimate_cost(backend, merged["input_tokens"], merged["output_tokens"]);
        print(
            f"[graphify extract] wrote {graph_json_path}: {G.number_of_nodes()} nodes, {G.number_of_edges()} edges, {len(communities)} communities",
        );
        print(f"[graphify extract] wrote {analysis_path}");
        if incremental_mode {
            _excl_note = f", {len(excluded_files)} excluded" if excluded_files else "";
            print(
                f"[graphify extract] incremental summary: {sem_cache_hits + unchanged_total} files cached/unchanged, {len(code_files) + sem_cache_misses} re-extracted, {len(deleted_files)} deleted{_excl_note}",
            );
        } elif sem_cache_hits {
            print(
                f"[graphify extract] semantic cache: {sem_cache_hits} cached, {sem_cache_misses} re-extracted",
            );
        }
        if merged["input_tokens"] or merged["output_tokens"] {
            print(
                "[graphify extract] tokens: "
                    + format(merged["input_tokens"], ",")
                    + " in / "
                    + format(merged["output_tokens"], ",")
                    + " out, est. cost (~"
                    + format(backend, "")
                    + "): $"
                    + format(cost, ".4f"),
            );
            _record_extract_cost(
                graphify_out,
                merged["input_tokens"],
                merged["output_tokens"],
                detection.get("total_files", 0),
            );
        }
        print(
            f"[graphify extract] next: run `graphify cluster-only {graphify_out.parent}` to generate GRAPH_REPORT.md and name communities",
        );
        _print_cloud_cta(graphify_out, G.number_of_nodes());
        stages.total();
    } elif cmd == "cache-check" {
        check_semantic_cache: any = importlib.import_module("graphify.cache").check_semantic_cache;
        if len(sys.argv) < 3 {
            print(
                "Usage: graphify cache-check <files_from> [--root <dir>] [--mode <m> | --deep] [--prompt-file <path>]",
                file=sys.stderr,
            );
            sys.exit(1);
        }
        files_from: any = Path(sys.argv[2]);
        `root = Path(".");
        cache_mode: str | None = None;
        prompt_file: str | None = None;
        i = 3;
        while i < len(sys.argv) {
            if sys.argv[i] == "--root" and i + 1 < len(sys.argv) {
                `root = Path(sys.argv[i + 1]);
                i += 2;
            } elif sys.argv[i] == "--mode" and i + 1 < len(sys.argv) {
                cache_mode = sys.argv[i + 1];
                i += 2;
            } elif sys.argv[i].startswith("--mode=") {
                cache_mode = sys.argv[i].split("=", 1)[1];
                i += 1;
            } elif sys.argv[i] == "--deep" {
                cache_mode = "deep";
                i += 1;
            } elif sys.argv[i] == "--prompt-file" and i + 1 < len(sys.argv) {
                prompt_file = sys.argv[i + 1];
                i += 2;
            } elif sys.argv[i].startswith("--prompt-file=") {
                prompt_file = sys.argv[i].split("=", 1)[1];
                i += 1;
            } else {
                i += 1;
            }
        }
        files: any = [f for f in files_from.read_text(encoding="utf-8").splitlines() if f.strip()];
        uncached: any;
        (cached_nodes, cached_edges, cached_hyperedges, uncached) = check_semantic_cache(
            files, `root, mode=cache_mode, prompt_file=prompt_file
        ) as any;
        out = `root / _GRAPHIFY_OUT;
        out.mkdir(parents=True, exist_ok=True);
        if cached_nodes or cached_edges or cached_hyperedges {
            (out / ".graphify_cached.json").write_text(
                json.dumps(
                    {"nodes": cached_nodes, "edges": cached_edges, "hyperedges": cached_hyperedges},
                    ensure_ascii=False,
                ),
                encoding="utf-8",
            );
        }
        (out / ".graphify_uncached.txt").write_text("\n".join(uncached), encoding="utf-8");
        print(f"Cache: {len(files) - len(uncached)} hit, {len(uncached)} miss");
    } elif cmd == "merge-chunks" {
        import glob as _glob;
        if len(sys.argv) < 3 {
            print("Usage: graphify merge-chunks <chunk_files...> --out <path>", file=sys.stderr);
            sys.exit(1);
        }
        out_path = None;
        chunk_args: list[str] = [];
        i = 2;
        while i < len(sys.argv) {
            if sys.argv[i] == "--out" and i + 1 < len(sys.argv) {
                out_path = Path(sys.argv[i + 1]);
                i += 2;
            } else {
                chunk_args.append(sys.argv[i]);
                i += 1;
            }
        }
        if not out_path {
            print("error: --out <path> required", file=sys.stderr);
            sys.exit(1);
        }
        chunk_files: list[str] = [];
        for arg in chunk_args {
            expanded: any = _glob.glob(arg);
            chunk_files.extend(sorted(expanded) if expanded else [arg]);
        }
        merged = {
            "nodes": [],
            "edges": [],
            "hyperedges": [],
            "input_tokens": 0,
            "output_tokens": 0,
        };
        seen_ids: set[str] = set[any]();
        valid_chunks: any = 0;
        load_validated_semantic_fragment: any = importlib.import_module(
            "graphify.semantic_cleanup"
        ).load_validated_semantic_fragment;
        for cf in chunk_files {
            chunk: any;
            _chunk_errs: any;
            (chunk, _chunk_errs) = load_validated_semantic_fragment(Path(cf)) as any;
            if _chunk_errs {
                print(
                    "[graphify merge-chunks] warning: skipping invalid chunk "
                        + format(cf, "")
                        + ": "
                        + format("; ".join(_chunk_errs[:3]), ""),
                    file=sys.stderr,
                );
                continue;
            }
            valid_chunks += 1;
            for n in chunk.get("nodes", []) {
                if n.get("id") not in seen_ids {
                    seen_ids.add(n["id"]);
                    merged["nodes"].append(n);
                }
            }
            merged["edges"].extend(chunk.get("edges", []));
            merged["hyperedges"].extend(chunk.get("hyperedges", []));
            for _tok in ("input_tokens", "output_tokens") {
                _v: any = chunk.get(_tok, 0);
                merged[_tok] += _v if isinstance(_v, (`int, `float)) else 0;
            }
        }
        if not valid_chunks {
            print(
                f"[graphify merge-chunks] error: no valid chunks to merge; refusing to write {out_path}",
                file=sys.stderr,
            );
            sys.exit(1);
        }
        out_path.parent.mkdir(parents=True, exist_ok=True);
        write_json_atomic: any = importlib.import_module("graphify.paths").write_json_atomic;
        write_json_atomic(out_path, merged, ensure_ascii=False);
        chunk_summary: any = f"{valid_chunks} chunks"
            if valid_chunks == len(chunk_files)
            else f"{valid_chunks} of {len(chunk_files)} chunks";
        print(
            "Merged "
                + format(chunk_summary, "")
                + ": "
                + format(len(merged["nodes"]), "")
                + " nodes, "
                + format(len(merged["edges"]), "")
                + " edges, "
                + format(merged["input_tokens"], ",")
                + " in / "
                + format(merged["output_tokens"], ",")
                + " out tokens",
        );
    } elif cmd == "merge-semantic" {
        if len(sys.argv) < 3 {
            print(
                "Usage: graphify merge-semantic --cached <path> --new <path> --out <path>",
                file=sys.stderr,
            );
            sys.exit(1);
        }
        cached_path: Path | None = None;
        new_path: Path | None = None;
        out_path2: Path | None = None;
        i = 2;
        while i < len(sys.argv) {
            if sys.argv[i] == "--cached" and i + 1 < len(sys.argv) {
                cached_path = Path(sys.argv[i + 1]);
                i += 2;
            } elif sys.argv[i] == "--new" and i + 1 < len(sys.argv) {
                new_path = Path(sys.argv[i + 1]);
                i += 2;
            } elif sys.argv[i] == "--out" and i + 1 < len(sys.argv) {
                out_path2 = Path(sys.argv[i + 1]);
                i += 2;
            } else {
                i += 1;
            }
        }
        if not out_path2 {
            print("error: --out <path> required", file=sys.stderr);
            sys.exit(1);
        }
        empty: dict = {"nodes": [], "edges": [], "hyperedges": []};
        cached_data: any = json.loads(cached_path.read_text(encoding="utf-8"))
            if cached_path and cached_path.exists()
            else empty;
        new_data: any = json.loads(new_path.read_text(encoding="utf-8"))
            if new_path and new_path.exists()
            else empty;
        seen_ids2: set[str] = set[any]();
        all_nodes: list[dict] = [];
        for n in cached_data.get("nodes", []) + new_data.get("nodes", []) {
            if n.get("id") not in seen_ids2 {
                seen_ids2.add(n["id"]);
                all_nodes.append(n);
            }
        }
        merged2: any = {
            "nodes": all_nodes,
            "edges": cached_data.get("edges", []) + new_data.get("edges", []),
            "hyperedges": cached_data.get("hyperedges", []) + new_data.get("hyperedges", []),
        };
        out_path2.parent.mkdir(parents=True, exist_ok=True);
        write_json_atomic: any = importlib.import_module("graphify.paths").write_json_atomic;
        write_json_atomic(out_path2, merged2, ensure_ascii=False);
        print(
            "Merged: "
                + format(len(merged2["nodes"]), "")
                + " nodes, "
                + format(len(merged2["edges"]), "")
                + " edges",
        );
    } elif Path(cmd).exists() or cmd in (".", "..") or cmd.startswith(("./", "../", "/", "~")) {
        sys.argv.insert(2, sys.argv[1]);
        sys.argv[1] = "extract";
        _reenter_main();
    } else {
        print(f"error: unknown command '{cmd}'", file=sys.stderr);
        print("Run 'graphify --help' for usage.", file=sys.stderr);
        sys.exit(1);
    }
}
