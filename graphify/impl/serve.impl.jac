impl ToolError.__repr__ -> str {
    return (getattr(builtins.super(ToolError, self), "__repr__") as any)();
}

impl ToolError.__eq__(other: any) -> bool {
    return self is other;
}

impl ToolError.__hash__ -> int {
    return id(self);
}

impl _read_graph(graph_path: str) -> nx.Graph {
    resolved: any = Path(graph_path).resolve();
    if resolved.suffix != ".json" {
        raise ValueError(f"Graph path must be a .json file, got: {graph_path!r}");
    }
    if not resolved.exists() {
        raise FileNotFoundError(f"Graph file not found: {resolved}");
    }
    check_graph_file_size_cap(resolved);
    safe: any = resolved;
    data: any = read_graph_json(safe);
    if "links" not in data and "edges" in data {
        data = `dict(data, links=data["edges"]);
    }
    _logical_directed: any = `bool(data.get("directed", False));
    data = {**data, "directed": True};
    if has_parallel_links(data.get("links"), directed=True) {
        data = {**data, "multigraph": True};
    }
    try {
        _legacy: any = importlib.import_module("graphify.build").graph_has_legacy_ids;
        _legacy_prefix: any = importlib.import_module("graphify.build").legacy_id_source_prefix;
        if _legacy(data.get("nodes", []), source_prefix=_legacy_prefix(safe)) {
            print(
                "[graphify] note: this graph uses the pre-#1504 node-ID scheme; rebuild with `graphify extract --force` for path-qualified IDs.",
                file=sys.stderr,
            );
        }
    } except Exception {}
    G: any = json_graph.node_link_graph(
        `dict(data, nodes=consumed(data["nodes"]), links=consumed(data["links"])), edges="links"
    );
    G.graph["_logical_directed"] = _logical_directed;
    _commit: any = data.get("built_at_commit");
    if isinstance(_commit, `str) and _commit.strip() {
        G.graph["_built_at_commit"] = _commit.strip();
    }
    try {
        _llo: any = importlib.import_module("graphify.reflect").load_learning_overlay;
        G.graph["_learning_overlay"] = _llo(resolved);
    } except Exception {
        G.graph["_learning_overlay"] = {};
    }
    return G;
}

impl _load_graph(graph_path: str) -> nx.Graph {
    try {
        return _read_graph(graph_path);
    } except json.JSONDecodeError as exc {
        print(
            f"error: graph.json is corrupted ({exc}). Re-run /graphify to rebuild.", file=sys.stderr
        );
        sys.exit(1);
    } except (ValueError, FileNotFoundError) as exc {
        print(f"error: {exc}", file=sys.stderr);
        sys.exit(1);
    }
}

impl _communities_from_graph(G: nx.Graph) -> dict[int, list[str]] {
    communities: dict[int, list[str]] = {};
    for (node_id, data) in G.nodes(data=True) {
        cid: any = data.get("community");
        if cid is not None {
            communities.setdefault(`int(cid), []).append(node_id);
        }
    }
    return communities;
}

impl _max_server_contexts -> int {
    raw: any = os.environ.get("GRAPHIFY_MAX_CONTEXTS", "").strip();
    if not raw {
        return 8;
    }
    try {
        return max(1, `int(raw));
    } except ValueError {
        return 8;
    }
}

impl _GraphContextCache.init(max_contexts: int) {
    self._max_contexts = max_contexts;
    self._entries = OrderedDict();
    self._pinned = {};
    self._lock = threading.Lock();
    self._loading = {};
}

impl _GraphContextCache._load_entry(resolved_path: str, key: tuple[int, int]) -> dict {
    try {
        `graph: any = _load_graph(resolved_path);
    } except SystemExit as exc {
        raise RuntimeError(f"could not load graph.json at {resolved_path}") from exc;
    }
    _get_trigram_index(`graph);
    communities: any = _communities_from_graph(`graph);
    `entry: any = {"key": key, "G": `graph, "communities": communities};
    return `entry;
}

impl _GraphContextCache.load(
    resolved_path: str, *, pinned: bool = False
) -> tuple[nx.Graph, dict[int, list[str]]] {
    entries: any = self._pinned if pinned else self._entries;
    loading_key: any = (resolved_path, pinned);
    with self._lock {
        try {
            stat_result: any = Path(resolved_path).stat();
        } except FileNotFoundError {
            raise FileNotFoundError(f"graph.json not found: {resolved_path}") from None;
        }
        key: any = (stat_result.st_mtime_ns, stat_result.st_size);
        `entry: any = entries.get(resolved_path);
        if `entry is not None and `entry["key"] == key {
            if not pinned {
                self._entries.move_to_end(resolved_path);
            }
            return (`entry["G"], `entry["communities"]);
        }

        in_flight: any = self._loading.get(loading_key);
        if `entry is not None and in_flight is not None {
            if not pinned {
                self._entries.move_to_end(resolved_path);
            }
            return (`entry["G"], `entry["communities"]);
        }

        if in_flight is not None {
            wait_event: any;
            build_here: any;
            (wait_event, build_here) = (in_flight, False);
        } else {
            wait_event = threading.Event();
            self._loading[loading_key] = wait_event;
            build_here = True;
        }
    }

    if not build_here {
        wait_event.wait();
        return self.load(resolved_path, pinned=pinned);
    }

    try {
        new_entry: any = self._load_entry(resolved_path, key);
    } except BaseException {
        with self._lock {
            self._loading.pop(loading_key, None);
            wait_event.set();
        }
        raise;
    }

    with self._lock {
        entries[resolved_path] = new_entry;
        if not pinned {
            self._entries.move_to_end(resolved_path);
            while len(self._entries) > self._max_contexts {
                self._entries.popitem(last=False);
            }
        }
        self._loading.pop(loading_key, None);
        wait_event.set();
        return (new_entry["G"], new_entry["communities"]);
    }
}

impl _GraphContextCache.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl _GraphContextCache.__eq__(other: any) -> bool {
    return self is other;
}

impl _GraphContextCache.__hash__ -> int {
    return id(self);
}

impl _node_arg(arguments: dict) -> str {
    v: any = arguments.get("label") or arguments.get("node_id") or arguments.get("id") or "";
    return v if isinstance(v, `str) else `str(v);
}

impl _strip_diacritics(text: str | None) -> str {
    import unicodedata;
    if not isinstance(text, `str) {
        text = "" if text is None else `str(text);
    }
    nfkd: any = unicodedata.normalize("NFKD", text);
    return "".join(c for c in nfkd if not unicodedata.combining(c));
}

impl _search_tokens(text: str) -> list[str] {
    return re.findall("[^\\W_]+", _strip_diacritics(`str(text)).lower());
}

impl _has_chinese(text: str) -> bool {
    return `any(operator.le("一", ch) and operator.le(ch, "鿿") for ch in text);
}

impl _segment_chinese(text: str) -> list[str] {
    if _jieba is not None {
        segments: any = [w for w in _jieba.cut(text) if len(w.strip()) > 0];
    } else {
        segments = [text[i:i + 2] for i in range(len(text) - 1)] or [text];
    }
    if len(text) > 1 and text not in segments {
        segments.append(text);
    }
    return segments;
}

impl _is_searchable(term: str) -> bool {
    if all(operator.le("a", ch) and operator.le(ch, "z") for ch in term) {
        return operator.gt(len(term), 2);
    }
    return True;
}

impl _query_terms(question: str) -> list[str] {
    terms: list[str] = [];
    for raw in question.split() {
        if _has_chinese(raw) {
            seg: any;
            for seg in _segment_chinese(raw.lower().strip()) {
                seg = seg.strip();
                if seg and _is_searchable(seg) {
                    terms.append(seg);
                }
            }
        } else {
            for tok in re.findall("\\w+", raw.lower()) {
                if _is_searchable(tok) {
                    terms.append(tok);
                }
            }
        }
    }
    content: any = [t for t in terms if t not in _QUERY_STOPWORDS];
    return content or terms;
}

impl _is_name_segment(segment: str) -> bool {
    return `bool(segment) and not segment.isdigit() and not _FILE_SUFFIX_RE.match(segment);
}

impl _qualified_tail(norm_label: str) -> tuple[int, str] | None {
    label: any = (norm_label or "").strip();
    if not _QUALIFIER_MAYBE_RE.search(label) {
        return None;
    }
    parts: any = [p for p in re.split(_QUALIFIER_SEPARATORS, label) if p];
    while parts and not _is_name_segment(parts[-1]) {
        parts.pop();
    }
    if not parts {
        return None;
    }
    tail: any = parts[-1];
    if len(parts) > 1 {
        head_tokens: any = len(_search_tokens(" ".join(parts[:-1])));
        if head_tokens {
            return (head_tokens, _name_key(tail));
        }
    }
    words: any = _CAMEL_WORD_RE.findall(tail);
    if len(words) < 2 or not `any(w[:1].isupper() for w in words[1:]) {
        return None;
    }
    head_tokens = len(_search_tokens(" ".join(words[:-1])));
    if not head_tokens {
        return None;
    }
    return (head_tokens, _name_key(words[-1]));
}

impl _name_key(text: str) -> str {
    stripped: any = `str(text or "").strip(_NAME_EDGES + " ").lower();
    return " ".join(re.findall("[^\\W_]+", stripped));
}

impl _flatten_attr_text(val, parts: list[str]) -> None {
    if isinstance(val, `dict) {
        for (k, v) in val.items() {
            parts.append(`str(k));
            _flatten_attr_text(v, parts);
        }
    } elif isinstance(val, (`list, `tuple)) {
        for item in val {
            _flatten_attr_text(item, parts);
        }
    } elif val is not None {
        parts.append(`str(val));
    }
}

impl _node_attributes_text(data: dict) -> tuple[str, str] {
    attrs: any = data.get("attributes");
    if not isinstance(attrs, `dict) or not attrs {
        return ("", "");
    }
    parts: list[str] = [];
    _flatten_attr_text(attrs, parts);
    if not parts {
        return ("", "");
    }
    raw_text: any = " ".join(parts);
    norm: any = _strip_diacritics(raw_text).lower();
    tokens: any = " ".join(_search_tokens(norm));
    return (norm, tokens);
}

impl _compute_idf(G: nx.Graph, terms: list[str]) -> dict[str, float] {
    t: any;
    cache: dict[str, float] = G.graph.setdefault("_idf_cache", {});
    N: any = G.number_of_nodes() or 1;
    uncached: any = [t for t in terms if t not in cache];
    if uncached {
        df: dict[str, int] = {t: 0 for t in uncached};
        for (_, data) in G.nodes(data=True) {
            norm_label: any = (
                data.get("norm_label") or _strip_diacritics(data.get("label") or "")
            ).lower();
            for t in uncached {
                if t in norm_label {
                    df[t] += 1;
                }
            }
        }
        for t in uncached {
            cache[t] = math.log(1 + N / (1 + df[t]));
        }
    }
    return {t: cache.get(t, math.log(1 + N)) for t in terms};
}

impl _trigrams(text: str) -> set[str] {
    if len(text) < 3 {
        return {text} if text else set[any]();
    }
    return {text[i:i + 3] for i in range(len(text) - 2)};
}

impl _node_rationale_text(data: dict) -> str {
    raw: any = data.get("rationale");
    if not raw {
        return "";
    }
    if isinstance(raw, (`list, `tuple)) {
        raw = " ".join(`str(part) for part in raw if part);
    }
    return _strip_diacritics(`str(raw)).lower();
}

impl _node_search_text(data: dict, nid: str) -> str {
    norm_label: any = data.get("norm_label") or _strip_diacritics(data.get("label") or "").lower();
    label_tokens: any = " ".join(_search_tokens(data.get("label") or ""));
    source: any = (data.get("source_file") or "").lower();
    source_tokens: any = " ".join(_search_tokens(data.get("source_file") or ""));
    nid_text: any = `str(nid).lower();
    fields: any = (norm_label, label_tokens, nid_text, source, source_tokens);
    if not nid_text.isascii() {
        nid_folded: any = _strip_diacritics(`str(nid)).lower();
        if nid_folded != nid_text {
            fields += (nid_folded,);
        }
    }
    rationale: any = _node_rationale_text(data);
    if rationale {
        fields += (rationale,);
    }
    attr_norm: any;
    attr_tokens: any;
    (attr_norm, attr_tokens) = _node_attributes_text(data) as any;
    if attr_norm {
        fields += (attr_norm, attr_tokens);
    }
    return "\x00".join(fields);
}

impl _get_trigram_index(G: nx.Graph) -> dict {
    idx: any = G.graph.get("_trigram_index");
    if idx is not None {
        return idx;
    }
    ids: any = `list(G.nodes());
    postings: dict[str, array] = {};
    for (i, nid) in enumerate(ids) {
        for g in _trigrams(_node_search_text(G.nodes[nid], nid)) {
            bucket: any = postings.get(g);
            if bucket is None {
                bucket = array("i");
                postings[g] = bucket;
            }
            bucket.append(i);
        }
    }
    idx = {"ids": ids, "postings": postings, "set_cache": {}};
    G.graph["_trigram_index"] = idx;
    return idx;
}

impl _trigram_candidates(G: nx.Graph, needles: list[str], *, guard_frac: float = 0.1) -> list[str]
    | None {
    s: any;
    g: any;
    idx: any = _get_trigram_index(G);
    ids: any;
    postings: any;
    set_cache: any;
    (ids, postings, set_cache) = (idx["ids"], idx["postings"], idx["set_cache"]);
    n: any = len(ids);
    if n == 0 {
        return [];
    }
    needles = [s for s in needles if s];
    thresh: any = `int(n * guard_frac);
    for s in needles {
        tgs: any = _trigrams(s);
        if not tgs or `any(operator.lt(len(g), 3) for g in tgs) {
            return None;
        }
        present: any = [len(postings[g]) for g in tgs if g in postings];
        if not present {
            continue;
        }
        if min(present) > thresh {
            return None;
        }
    }
    cand: set[int] = set[any]();
    for s in needles {
        sets: list[set] | None = [];
        for g in _trigrams(s) {
            bucket: any = postings.get(g);
            if bucket is None {
                sets = None;
                break;
            }
            cached: any = set_cache.get(g);
            if cached is None {
                cached = `set(bucket);
                set_cache[g] = cached;
            }
            sets.append(cached);
        }
        if not sets {
            continue;
        }
        sets.sort(key=builtins.len);
        hit: any = `set(sets[0]);
        for other in sets[1:] {
            hit &= other;
            if not hit {
                break;
            }
        }
        cand |= hit;
    }
    return [ids[i] for i in sorted(cand)];
}

impl _query_path_weight(terms: list[str], demote_docs: bool = True) -> any {
    keep_tests: any;
    keep_docs: any;
    words: any = {tok for t in terms for tok in _search_tokens(t)};
    keep_tests = `bool(words & _QUERY_TEST_WORDS);
    keep_docs = not demote_docs or `bool(words & _QUERY_DOC_WORDS);

    def weight(data: dict) -> float {
        path: any = `str(data.get("source_file") or "").replace("\\", "/");
        parts: any = path.lower().split("/");
        if not keep_tests
            and (_is_test_path(path) or "testing" in parts[:-1] or parts[-1] == "conftest.py")
        {
            return _QUERY_DEMOTE_WEIGHT;
        }
        if not keep_docs
            and (
                not path
                or data.get("file_type") in ("document", "paper", "image")
                or parts[-1].endswith(_QUERY_DOC_SUFFIXES)
                or `any(p in _QUERY_DOC_DIRS for p in parts[:-1])
            )
        {
            return _QUERY_DEMOTE_WEIGHT;
        }
        return 1.0;
    }

    return weight;
}

impl _score_nodes(G: nx.Graph, terms: list[str]) -> list[tuple[float, str]] {
    return _score_query(G, terms, collect_per_term_seeds=False).ranked;
}

impl _score_query(
    G: nx.Graph, terms: list[str], *, collect_per_term_seeds: bool, path_weight=None
) -> _QueryScores {
    idf: any;
    postings: any;
    nid: any;
    scored: list[tuple[float, str]] = [];
    norm_terms: any = `list(dict.fromkeys(tok for t in terms for tok in _search_tokens(t)));
    n_terms: any = len(norm_terms);
    idf = _compute_idf(G, norm_terms);
    joined: any = " ".join(norm_terms);
    joined_w: any = max((idf.get(t, 1.0) for t in norm_terms), default=1.0);
    candidate_ids: any = _trigram_candidates(G, norm_terms + ([joined] if joined else []));
    scoring_terms: any = norm_terms;
    if candidate_ids is None
        and getattr(G, "_graphify_one_shot_query", False)
        and (index := G.graph.get("_trigram_index")) is not None
    {
        postings = index["postings"];
        scoring_terms = [
            term
            for term in norm_terms
            if len(term) < 3 or all(gram in postings for gram in _trigrams(term))
        ];
    }
    node_iter: any = G.nodes(data=True)
        if candidate_ids is None
        else ((nid, G.nodes[nid]) for nid in candidate_ids);
    best_by_term: dict[str, tuple[tuple, str]] | None = {} if collect_per_term_seeds else None;
    for (nid, data) in node_iter {
        norm_label: any = data.get("norm_label")
            or _strip_diacritics(data.get("label") or "").lower();
        bare_label: any = norm_label.rstrip("()");
        label_tokens: any = " ".join(_search_tokens(data.get("label") or ""));
        source: any = (data.get("source_file") or "").lower();
        rationale: any = _node_rationale_text(data);
        attr_norm: any;
        attr_tokens: any;
        (attr_norm, attr_tokens) = _node_attributes_text(data) as any;
        nid_lower: any = nid.lower() if joined or collect_per_term_seeds else "";
        weight: any = path_weight(data) if path_weight is not None else 1.0;
        score: any = 0.0;
        if joined {
            if joined in (norm_label, bare_label, label_tokens, nid_lower) {
                score += _EXACT_MATCH_BONUS * 10 * joined_w;
            } elif norm_label.startswith(joined)
                or bare_label.startswith(joined)
                or label_tokens.startswith(joined)
            {
                score += _PREFIX_MATCH_BONUS * 10 * joined_w;
            } else {
                qualified: any = _qualified_tail(norm_label);
                if qualified is not None and qualified[0] <= _QUALIFIED_MAX_TOKENS {
                    qualifier_tokens: any;
                    tail_key: any;
                    (qualifier_tokens, tail_key) = qualified as any;
                    if tail_key and tail_key == joined {
                        score += _QUALIFIED_MATCH_BONUS * joined_w / qualifier_tokens;
                    }
                }
            }
        }
        matched: any = 0;
        tiered: any = 0.0;
        for t in scoring_terms {
            w: any = idf.get(t, 1.0);
            tier_value: any = 0.0;
            substr_value: any = 0.0;
            source_value: any = 0.0;
            if t == norm_label or t == bare_label {
                tier_value = _EXACT_MATCH_BONUS * w;
                matched += 1;
            } elif norm_label.startswith(t) or bare_label.startswith(t) {
                tier_value = _PREFIX_MATCH_BONUS * w;
                matched += 1;
            } elif t in norm_label {
                substr_value = _SUBSTRING_MATCH_BONUS * w;
                score += substr_value;
                matched += 1;
            }
            if t in source {
                source_value = _SOURCE_MATCH_BONUS * w;
                score += source_value;
            }
            rationale_value: any = 0.0;
            if rationale and t in rationale {
                rationale_value = _RATIONALE_MATCH_BONUS * w;
                score += rationale_value;
            }
            attr_value: any = 0.0;
            if attr_norm and (t in attr_norm or t in attr_tokens) {
                attr_value = _ATTRIBUTE_MATCH_BONUS * w;
                score += attr_value;
            }
            tiered += tier_value;
            if collect_per_term_seeds and best_by_term is not None {
                if t in (norm_label, bare_label, label_tokens, nid_lower) {
                    singleton: any = _EXACT_MATCH_BONUS * 10 * w;
                } elif norm_label.startswith(t)
                    or bare_label.startswith(t)
                    or label_tokens.startswith(t)
                {
                    singleton = _PREFIX_MATCH_BONUS * 10 * w;
                } else {
                    singleton = 0.0;
                }
                singleton += tier_value
                    + substr_value
                    + source_value
                    + rationale_value
                    + attr_value;
                singleton *= weight;
                if singleton > 0 {
                    key: any = (-singleton, -G.degree(nid), len(data.get("label") or nid), nid);
                    cur: any = best_by_term.get(t);
                    if cur is None or key < cur[0] {
                        best_by_term[t] = (key, nid);
                    }
                }
            }
        }
        if tiered {
            score += tiered * (matched / n_terms) ** 2;
        }
        score *= weight;
        if score > 0 {
            scored.append((score, nid));
        }
    }
    scored.sort(key=lambda (s) -> any { (-s[0], len(G.nodes[s[1]].get("label") or s[1]), s[1]) });
    best_seed_by_term: dict[str, str] = {};
    term_order: tuple[str, ...] = ();
    if collect_per_term_seeds and best_by_term {
        best_seed_by_term = {t: nid for (t, (_key, nid)) in best_by_term.items()};
        term_order = `tuple(
            t
            for (t, _) in sorted(
                best_by_term.items(), key=lambda (kv) -> any { (kv[1][0], kv[0]) }
            ),
        );
    }
    return _QueryScores(ranked=scored, best_seed_by_term=best_seed_by_term, term_order=term_order);
}

impl _pick_scored_endpoint(G: nx.Graph, scored: list[tuple[float, str]], query: str) -> str {
    qtokens: any = `set(_search_tokens(query));
    if not qtokens {
        return scored[0][1];
    }
    for (_score, nid) in scored {
        if qtokens <= `set(_search_tokens(G.nodes[nid].get("label") or nid)) {
            return nid;
        }
    }
    return scored[0][1];
}

impl _pick_seeds(
    scored: list[tuple[float, str]],
    max_k: int = 3,
    gap_ratio: float = 0.2,
    *,
    G: "nx.Graph | None" = None,
    best_seed_by_term: dict[str, str] | None = None,
    term_order: "tuple[str, ...] | list[str] | None" = None,
) -> list[str] {
    ordered_terms: any;
    if not scored {
        return [];
    }
    def _seed_label_key(nid: str) -> str {
        if G is None {
            return nid;
        }
        data: any = G.nodes[nid];
        return data.get("norm_label") or _strip_diacritics(data.get("label") or "").lower() or nid;
    }

    top_score: any = scored[0][0];
    seeds: list[str] = [];
    seen_labels: set[str] = set[any]();
    for (score, nid) in scored {
        if len(seeds) >= max_k {
            break;
        }
        if seeds and score < top_score * gap_ratio {
            break;
        }
        key: any = _seed_label_key(nid);
        if key in seen_labels {
            continue;
        }
        seen_labels.add(key);
        seeds.append(nid);
    }

    if G is not None and best_seed_by_term {
        ordered_terms = [t for t in term_order or () if t in best_seed_by_term];
        ordered_terms += sorted(t for t in best_seed_by_term if t not in `set(ordered_terms));
        for term in ordered_terms {
            best_nid: any = best_seed_by_term[term];
            key = _seed_label_key(best_nid);
            if best_nid not in seeds and (key not in seen_labels or term not in key) {
                seen_labels.add(key);
                seeds.append(best_nid);
            }
        }
    }
    return seeds;
}

impl _normalize_context_filters(filters: list[str] | None) -> list[str] {
    if not filters {
        return [];
    }
    normalized: list[str] = [];
    seen: set[str] = set[any]();
    for value in filters {
        key: any = _strip_diacritics(`str(value)).strip().lower();
        if not key {
            continue;
        }
        key = _CONTEXT_FILTER_ALIASES.get(key, key);
        if key not in seen {
            seen.add(key);
            normalized.append(key);
        }
    }
    return normalized;
}

impl _infer_context_filters(question: str) -> list[str] {
    lowered: any;
    lowered = {
        _strip_diacritics(token).lower()
        for token in question.replace("?", " ").replace(",", " ").split()
    };
    inferred: list[str] = [];
    for (context, hints) in _CONTEXT_HINTS {
        if `any(hint in lowered for hint in hints) {
            inferred.append(context);
        }
    }
    return inferred;
}

impl _resolve_context_filters(
    question: str, explicit_filters: list[str] | None = None
) -> tuple[list[str], str | None] {
    normalized: any = _normalize_context_filters(explicit_filters);
    if normalized {
        return (normalized, "explicit");
    }
    inferred: any = _infer_context_filters(question);
    if inferred {
        return (inferred, "heuristic");
    }
    return ([], None);
}

impl _filter_graph_by_context(G: nx.Graph, context_filters: list[str] | None) -> nx.Graph {
    filters: any;
    relations: any;
    filters = `set(_normalize_context_filters(context_filters));
    if not filters {
        return G;
    }
    relations = `set(filters & _HERITAGE_RELATIONS);
    for context in filters {
        relations |= _CONTEXT_RELATIONS.get(context, frozenset());
    }

    def keep(data: dict) -> bool {
        if data.get("context") in filters {
            return True;
        }
        return data.get("relation") in relations;
    }

    H: any = G.__class__();
    H.add_nodes_from(G.nodes(data=True));
    if isinstance(G, (nx.MultiGraph, nx.MultiDiGraph)) {
        u: any;
        v: any;
        data: any;
        for (u, v, key, data) in G.edges(keys=True, data=True) {
            if keep(data) {
                H.add_edge(u, v, key=key, **data);
            }
        }
    } else {
        for (u, v, data) in G.edges(data=True) {
            if keep(data) {
                H.add_edge(u, v, **data);
            }
        }
    }
    return H;
}

impl _complete_induced_edges(G: nx.Graph, visited: set[str], edges_seen: list[tuple]) -> None {
    directed: any;
    u: any;
    v: any;
    directed = G.is_directed();

    def _key(u: str, v: str) -> any {
        return (u, v) if directed else frozenset((u, v));
    }

    seen: any = {_key(u, v) for (u, v) in edges_seen};
    for (u, v) in G.edges(sorted(visited)) {
        if u == v or v not in visited {
            continue;
        }
        key: any = _key(u, v);
        if key in seen {
            continue;
        }
        seen.add(key);
        edges_seen.append((u, v));
    }
}

impl _bfs(G: nx.Graph, start_nodes: list[str], depth: int) -> tuple[set[str], list[tuple]] {
    n: any;
    degrees: any = [G.degree(n) for n in G.nodes()];
    if degrees {
        degrees_sorted: any = sorted(degrees);
        p99_idx: any = `int(len(degrees_sorted) * 0.99);
        hub_threshold: any = max(50, degrees_sorted[p99_idx]);
    } else {
        hub_threshold = 50;
    }
    seed_set: any = `set(start_nodes);
    visited: set[str] = `set(start_nodes);
    frontier: any = `list(dict.fromkeys(start_nodes));
    edges_seen: list[tuple] = [];
    for _ in range(depth) {
        next_frontier: dict[str, None] = {};
        for n in frontier {
            if n not in seed_set and G.degree(n) >= hub_threshold {
                continue;
            }
            for neighbor in G.neighbors(n) {
                if neighbor not in visited {
                    next_frontier[neighbor] = None;
                    edges_seen.append((n, neighbor));
                }
            }
        }
        visited.update(next_frontier);
        frontier = `list(next_frontier);
    }
    _complete_induced_edges(G, visited, edges_seen);
    return (visited, edges_seen);
}

impl _dfs(G: nx.Graph, start_nodes: list[str], depth: int) -> tuple[set[str], list[tuple]] {
    degrees: any = [G.degree(n) for n in G.nodes()];
    if degrees {
        degrees_sorted: any = sorted(degrees);
        p99_idx: any = `int(len(degrees_sorted) * 0.99);
        hub_threshold: any = max(50, degrees_sorted[p99_idx]);
    } else {
        hub_threshold = 50;
    }
    seed_set: any = `set(start_nodes);
    visited: set[str] = set[any]();
    edges_seen: list[tuple] = [];
    stack: any = [(n, 0) for n in reversed(start_nodes)];
    while stack {
        `node: any;
        d: any;
        (`node, d) = stack.pop() as any;
        if `node in visited or d > depth {
            continue;
        }
        visited.add(`node);
        if `node not in seed_set and G.degree(`node) >= hub_threshold {
            continue;
        }
        for neighbor in G.neighbors(`node) {
            if neighbor not in visited {
                stack.append((neighbor, d + 1));
                edges_seen.append((`node, neighbor));
            }
        }
    }
    _complete_induced_edges(G, visited, edges_seen);
    return (visited, edges_seen);
}

impl _subgraph_to_text(
    G: nx.Graph,
    nodes: set[str],
    edges: list[tuple],
    token_budget: int = 2000,
    *,
    seeds: list[str] | None = None,
    scores: dict[str, float] | None = None,
) -> str {
    lines: any;
    dist: dict[str, int];
    n: any;
    file_rank: any;
    unranked: any;
    char_budget: any = token_budget * 3;
    lines = [];
    overlay: any = getattr(G, "graph", {}).get("_learning_overlay", {}) or {};
    seed_set: any = `set(seeds or []);
    seed_hits: any = [n for n in seeds or [] if n in nodes];
    def _adj(n) -> Generator[any, any, any] {
        if G.is_directed() {
            yield from G.successors(n);
            yield from G.predecessors(n);
        } else {
            yield from G.neighbors(n);
        }
    }
    dist = {n: 0 for n in seed_hits};
    frontier: any;
    hop: any;
    (frontier, hop) = (seed_hits, 0);
    while frontier {
        hop += 1;
        nxt: any = [];
        for n in frontier {
            for nb in _adj(n) {
                if nb in nodes and nb not in dist {
                    dist[nb] = hop;
                    nxt.append(nb);
                }
            }
        }
        frontier = nxt;
    }
    if scores {
        file_best: dict[str, float] = {};
        for n in nodes {
            sc: any = scores.get(n, 0.0);
            if sc > 0 {
                f: any = `str(G.nodes[n].get("source_file") or "");
                if sc > file_best.get(f, 0.0) {
                    file_best[f] = sc;
                }
            }
        }
        file_rank = {
            f: i
            for (i, (f, _)) in enumerate(
                sorted(file_best.items(), key=lambda (kv) -> any { (-kv[1], kv[0]) })
            )
        };
        unranked = len(file_rank);

        def _order(n: str) -> any {
            f: any = `str(G.nodes[n].get("source_file") or "");
            sc: any = scores.get(n, 0.0);
            fr: any = file_rank.get(f, unranked) if sc > 0 else unranked;
            return (fr, -sc, dist.get(n, 1 << 30), -G.degree(n), `str(n));
        }

        seed_hits = sorted(seed_hits, key=_order);
        ordered: any = seed_hits + sorted(nodes - seed_set, key=_order);
    } else {
        ordered = seed_hits
            + sorted(
                nodes - seed_set,
                key=lambda (n) -> any { (dist.get(n, 1 << 30), -G.degree(n), `str(n)) },
            );
    }
    for nid in ordered {
        d: any = G.nodes[nid];
        `entry: any = overlay.get(`str(nid));
        learning_suffix: any = "";
        if `entry {
            status: any = sanitize_label(`str(`entry.get("status", "")));
            if status {
                learning_suffix = " learning="
                    + format(status, "")
                    + format(":stale" if `entry.get("stale") else "", "");
            }
        }
        attrs: any = d.get("attributes");
        attrs_suffix: any = "";
        if isinstance(attrs, `dict) and attrs {
            pairs: any = [];
            v: any;
            for (k, v) in sorted(attrs.items()) {
                if isinstance(v, (`dict, `list)) {
                    v_str: any = json.dumps(v, sort_keys=True);
                } elif isinstance(v, `str) {
                    v_str = f"\"{v}\"";
                } elif isinstance(v, `bool) {
                    v_str = "true" if v else "false";
                } elif v is None {
                    v_str = "null";
                } else {
                    v_str = `str(v);
                }
                if len(v_str) > 60 {
                    v_str = v_str[:57] + "...";
                }
                pairs.append(f"{k}={v_str}");
                if len(pairs) >= 10 {
                    pairs.append("...");
                    break;
                }
            }
            attrs_summary: any = ", ".join(pairs);
            if len(attrs_summary) > 200 {
                attrs_summary = attrs_summary[:197] + "...";
            }
            attrs_suffix = f" attrs={{{sanitize_label(attrs_summary)}}}";
        }
        line: any = "NODE "
            + format(sanitize_label(d.get("label", nid)), "")
            + " [src="
            + format(sanitize_label(`str(d.get("source_file", ""))), "")
            + " loc="
            + format(sanitize_label(`str(d.get("source_location", ""))), "")
            + " community="
            + format(sanitize_label(`str(d.get("community_name") or d.get("community", ""))), "")
            + format(learning_suffix, "")
            + format(attrs_suffix, "")
            + "]";
        lines.append(line);
    }
    for (u, v) in edges {
        if u in nodes and v in nodes {
            for d in edge_datas(G, u, v) {
                src: any = d.get("_src", u);
                tgt: any = d.get("_tgt", v);
                if {src, tgt} != {u, v} {
                    (src, tgt) = (u, v);
                }
                context: any = d.get("context");
                context_suffix: any = f" context={sanitize_label(`str(context))}"
                    if context
                    else "";
                _loc: any = `str(d.get("source_location") or "");
                at_suffix: any = " at="
                    + format(sanitize_label(`str(d.get("source_file") or "")), "")
                    + ":"
                    + format(sanitize_label(_loc), "")
                    if _loc
                    else "";
                line = "EDGE "
                    + format(sanitize_label(G.nodes[src].get("label", src)), "")
                    + " --"
                    + format(sanitize_label(`str(d.get("relation", ""))), "")
                    + " ["
                    + format(sanitize_label(`str(d.get("confidence", ""))), "")
                    + format(context_suffix, "")
                    + "]--> "
                    + format(sanitize_label(G.nodes[tgt].get("label", tgt)), "")
                    + format(at_suffix, "");
                lines.append(line);
            }
        }
    }
    output: any = "\n".join(lines);
    if len(output) > char_budget {
        cut_at: any = output[:char_budget].rfind("\n");
        cut_at = cut_at if cut_at > 0 else char_budget;
        if seed_hits {
            seed_block_end: any = sum(len(lines[i]) + 1 for i in range(len(seed_hits))) - 1;
            cut_at = max(cut_at, min(seed_block_end, len(output)));
        }
        total_nodes: any = sum(1 for l in lines if l.startswith("NODE "));
        shown_nodes: any = output[:cut_at].count("\nNODE ")
            + (1 if output.startswith("NODE ") else 0);
        cut_count: any = total_nodes - shown_nodes;
        if cut_count == 0 {
            total_edges: any = sum(1 for l in lines if l.startswith("EDGE "));
            est_tokens: any = len(output) // 3;
            return f"[i] Complete answer over budget: all {total_nodes} nodes and {total_edges} edges shown (~{est_tokens} tokens vs the requested ~{token_budget}-token budget). Edges are never dropped once every node fits, so this is already the full answer — raising --budget further will not shrink it. Narrow with context_filter=['call'] or use get_node for a specific symbol to reduce size instead.\n\n"
                + output;
        }
        node_chars: any = sum(len(l) + 1 for l in lines if l.startswith("NODE "));
        full_budget: any = (min(node_chars, len(output)) + 2) // 3;
        output = f"[!] TRUNCATED: showing {shown_nodes} of {total_nodes} nodes (~{token_budget}-token budget). The answer may be among the {cut_count} cut nodes — raise the token budget to {full_budget} to get all {total_nodes} (CLI: --budget {full_budget}, MCP: token_budget={full_budget}) or narrow the query (e.g. context_filter=['call'], or get_node for a specific symbol).\n\n"
            + output[:cut_at]
            + f"\n... (truncated — {cut_count} more nodes cut by ~{token_budget}-token budget. Narrow with context_filter=['call'] or use get_node for a specific symbol)";
    }
    return output;
}

impl _cut_lines_to_budget(lines: list[str], token_budget: int, narrow_hint: str) -> str {
    output: any = "\n".join(lines);
    char_budget: any = token_budget * 3;
    if len(output) <= char_budget {
        return output;
    }
    cut_at: any = output[:char_budget].rfind("\n");
    cut_at = cut_at if cut_at > 0 else char_budget;
    kept: any = output[:cut_at];
    shown: any = kept.count("\n") + 1;
    cut_count: any = len(lines) - shown;
    full_budget: any = (len(output) + 2) // 3;
    return f"[!] TRUNCATED: showing {shown} of {len(lines)} lines (~{token_budget}-token budget). Raise the token budget to {full_budget} to get all {len(lines)} (token_budget={full_budget}). {narrow_hint}\n\n"
        + kept
        + f"\n... (truncated — {cut_count} more lines cut by ~{token_budget}-token budget. "
        + narrow_hint
        + ")";
}

impl _display_graph_path(graph_path: str) -> str {
    try {
        p: any = Path(graph_path).resolve();
        try {
            return p.relative_to(Path.cwd().resolve()).as_posix();
        } except ValueError {
            return p.as_posix();
        }
    } except (OSError, RuntimeError, ValueError) {
        return `str(graph_path);
    }
}

impl _traversal_view(G: nx.Graph) -> nx.Graph {
    if not G.is_directed() {
        return G;
    }
    cached: any = G.graph.get("_traversal_view");
    if cached is not None {
        return cached;
    }
    H: any = nx.MultiGraph() if G.is_multigraph() else nx.Graph();
    H.graph.update(G.graph);
    H.add_nodes_from(G.nodes(data=True));
    for (u, v, d) in G.edges(data=True) {
        H.add_edge(u, v, **{**d, "_src": d.get("_src", u), "_tgt": d.get("_tgt", v)});
    }
    G.graph["_traversal_view"] = H;
    return H;
}

impl _query_graph_text(
    G: nx.Graph,
    question: str,
    *,
    mode: str = "bfs",
    depth: int = 3,
    token_budget: int = 2000,
    context_filters: list[str] | None = None,
    graph_path: str | None = None,
    seeds: list[str] | None = None,
    seed_root: Path | None = None,
    demote_docs: bool = True,
) -> str {
    unresolved: list[str] = [];
    ambiguous_refusals: list[str] = [];
    if seeds {
        resolve_seed: any = importlib.import_module("graphify.affected").resolve_seed;
        start_nodes: list[str] = [];
        for value in seeds {
            nid: any = resolve_seed(G, value, seed_root);
            if nid is None {
                refusal: any = _query_name_refusal(G, value);
                if refusal {
                    if refusal not in ambiguous_refusals {
                        ambiguous_refusals.append(refusal);
                    }
                } elif value not in unresolved {
                    unresolved.append(value);
                }
            } elif nid not in start_nodes {
                start_nodes.append(nid);
            }
        }
        if not start_nodes {
            if ambiguous_refusals {
                return "\n".join(ambiguous_refusals);
            }
            return "No unique node match for --seed: " + ", ".join(seeds);
        }
        return _render_query(
            G,
            question,
            start_nodes,
            mode=mode,
            depth=depth,
            token_budget=token_budget,
            context_filters=context_filters,
            graph_path=graph_path,
            given=True,
            unresolved=unresolved,
        );
    }
    _refusal: any = _query_name_refusal(G, question);
    if _refusal {
        return _refusal;
    }
    terms: any = _query_terms(question);
    qs: any = _score_query(
        G,
        terms,
        collect_per_term_seeds=True,
        path_weight=_query_path_weight(terms, demote_docs=demote_docs),
    );
    best_seed_by_term: any = qs.best_seed_by_term;
    intent: any = {t for t in best_seed_by_term if t in _RELATIONAL_INTENT_TERMS};
    if intent and `any(t not in _RELATIONAL_INTENT_TERMS for t in terms) {
        best_seed_by_term = {t: nid for (t, nid) in best_seed_by_term.items() if t not in intent};
    }
    start_nodes = _pick_seeds(
        qs.ranked, G=G, best_seed_by_term=best_seed_by_term, term_order=qs.term_order
    );
    if not start_nodes {
        return _QUERY_NO_MATCH;
    }
    return _render_query(
        G,
        question,
        start_nodes,
        mode=mode,
        depth=depth,
        token_budget=token_budget,
        context_filters=context_filters,
        graph_path=graph_path,
        scores={nid: sc for (sc, nid) in qs.ranked},
    );
}

impl _render_query(
    G: nx.Graph,
    question: str,
    start_nodes: list[str],
    *,
    mode: str,
    depth: int,
    token_budget: int,
    context_filters: list[str] | None,
    graph_path: str | None,
    given: bool = False,
    unresolved: list[str] | None = None,
    scores: dict[str, float] | None = None,
) -> str {
    resolved_filters: any;
    filter_source: any;
    (resolved_filters, filter_source) = _resolve_context_filters(question, context_filters) as any;
    traversal_graph: any = _filter_graph_by_context(_traversal_view(G), resolved_filters);
    nodes: any;
    edges: any;
    (nodes, edges) = (
        _dfs(traversal_graph, start_nodes, depth)
            if mode == "dfs"
            else _bfs(traversal_graph, start_nodes, depth)
    ) as any;
    header_parts: any = [
        f"Traversal: {mode.upper()} depth={depth}",
        "Start"
            + format(" (given)" if given else "", "")
            + ": "
            + format([G.nodes[n].get("label", n) for n in start_nodes], ""),
    ];
    if unresolved {
        header_parts.append(f"Unresolved seeds (skipped): {unresolved}");
    }
    if graph_path {
        header_parts.insert(
            0, f"Graph: {_display_graph_path(graph_path)} ({G.number_of_nodes()} nodes)"
        );
    }
    if resolved_filters {
        label: any = "Context: "
            + format(", ".join(resolved_filters), "")
            + " ("
            + format(filter_source, "");
        if not traversal_graph.number_of_edges() {
            label += ", matched 0 edges";
        }
        header_parts.append(label + ")");
    }
    header_parts.append(f"{len(nodes)} nodes found");
    header: any = " | ".join(header_parts) + "\n\n";
    return header
        + _subgraph_to_text(
            traversal_graph, nodes, edges, token_budget, seeds=start_nodes, scores=scores
        );
}

impl _resolve_path_scoped_symbol(G: nx.Graph, path_part: str, symbol_part: str) -> list[str] {
    nid: any;
    path_tokens: any = " ".join(_search_tokens(path_part));
    norm_path_query: any = _strip_diacritics(path_part).lower().strip();
    symbol_term: any = " ".join(_search_tokens(symbol_part));
    norm_symbol_query: any = _strip_diacritics(symbol_part).lower().strip();
    if not (path_tokens or norm_path_query) or not (symbol_term or norm_symbol_query) {
        return [];
    }
    candidate_ids: any = _trigram_candidates(G, [symbol_term, norm_symbol_query]);
    node_iter: any = G.nodes(data=True)
        if candidate_ids is None
        else ((nid, G.nodes[nid]) for nid in candidate_ids);
    matches: list[str] = [];
    for (nid, d) in node_iter {
        source_file: any = d.get("source_file") or "";
        source_tokens: any = " ".join(_search_tokens(source_file));
        norm_source: any = _strip_diacritics(source_file).lower().strip();
        if not (
            source_tokens == path_tokens
            or norm_source == norm_path_query
            or norm_path_query and norm_source.endswith("/" + norm_path_query)
            or path_tokens and source_tokens.endswith(" " + path_tokens)
        ) {
            continue;
        }
        norm_label: any = d.get("norm_label") or _strip_diacritics(d.get("label") or "").lower();
        bare_label: any = norm_label.rstrip("()");
        label_tokens: any = " ".join(_search_tokens(d.get("label") or ""));
        nid_lower: any = nid.lower();
        if symbol_term == norm_label
            or symbol_term == bare_label
            or symbol_term == label_tokens
            or symbol_term == nid_lower
            or norm_symbol_query == norm_label
            or norm_symbol_query == bare_label
        {
            matches.append(nid);
        }
    }
    return matches;
}

impl _label_has_literal_exact_match(G: nx.Graph, term: str, norm_query: str) -> bool {
    nid: any;
    candidate_ids: any = _trigram_candidates(G, [term, norm_query]);
    node_iter: any = G.nodes(data=True)
        if candidate_ids is None
        else ((nid, G.nodes[nid]) for nid in candidate_ids);
    for (nid, d) in node_iter {
        norm_label: any = d.get("norm_label") or _strip_diacritics(d.get("label") or "").lower();
        bare_label: any = norm_label.rstrip("()");
        label_tokens: any = " ".join(_search_tokens(d.get("label") or ""));
        nid_lower: any = nid.lower();
        nid_norm: any = nid_lower if nid.isascii() else _strip_diacritics(nid).lower();
        if term == norm_label
            or term == bare_label
            or term == label_tokens
            or term == nid_lower
            or norm_query == norm_label
            or norm_query == bare_label
            or norm_query == nid_norm
        {
            return True;
        }
    }
    return False;
}

impl _resolve_python_qualified(G: nx.Graph, label: str) -> list[str] {
    qualified: any = _PY_QUALIFIED_RE.match(label.strip());
    if not qualified {
        return [];
    }
    module_path: any = qualified.group(1).replace(".", "/");
    for path_part in (f"{module_path}.py", f"{module_path}/__init__.py") {
        scoped: any = _resolve_path_scoped_symbol(G, path_part, qualified.group(2));
        if scoped {
            return scoped;
        }
    }
    return [];
}

impl _symbol_name(d: dict) -> str {
    norm_label: any = d.get("norm_label") or _strip_diacritics(d.get("label") or "").lower();
    return norm_label.strip().removeprefix(".").removesuffix("()");
}

impl _split_qualified_member(label: str) -> tuple[list[str], str] | None {
    qualified: any = _QUALIFIED_MEMBER_RE.match(label.strip());
    if not qualified {
        return None;
    }
    owners: any = [_strip_diacritics(p).lower() for p in qualified.group(1).split(".")];
    return (owners, _strip_diacritics(qualified.group(2)).lower());
}

impl _named_nodes(G: nx.Graph, name: str) -> list[str] {
    candidate_ids: any = _trigram_candidates(G, [name]);
    node_iter: any = G.nodes(data=True)
        if candidate_ids is None
        else ((nid, G.nodes[nid]) for nid in candidate_ids);
    return [nid for (nid, d) in node_iter if _symbol_name(d) == name];
}

impl _membership_neighbors(G: nx.Graph, nid: str, *, members: bool) -> list[str] {
    if isinstance(G, nx.DiGraph) {
        edges: any = `list(G.out_edges(nid, data=True)) + `list(G.in_edges(nid, data=True));
    } else {
        edges = `list(G.edges(nid, data=True));
    }
    found: dict[str, None] = {};
    for (u, v, d) in edges {
        if d.get("relation") not in _TYPE_MEMBER_RELATIONS {
            continue;
        }
        if "_src" in d and "_tgt" in d {
            owner: any;
            member: any;
            (owner, member) = (d["_src"], d["_tgt"]);
        } elif isinstance(G, nx.DiGraph) {
            (owner, member) = (u, v);
        } else {
            continue;
        }
        if (owner if members else member) != nid {
            continue;
        }
        other: any = member if members else owner;
        if other != nid {
            found.setdefault(other);
        }
    }
    return `list(found);
}

impl _enclosed_by(G: nx.Graph, nid: str, outer: list[str]) -> bool {
    if not outer {
        return True;
    }
    return `any(
        operator.eq(_symbol_name(G.nodes[parent]), outer[-1])
            and _enclosed_by(G, parent, outer[:-1])
        for parent in _membership_neighbors(G, nid, members=False),
    );
}

impl _qualified_member_owners(G: nx.Graph, qualifiers: list[str]) -> list[str] {
    return [
        owner
        for owner in _named_nodes(G, qualifiers[-1])
        if _membership_neighbors(G, owner, members=True) and _enclosed_by(G, owner, qualifiers[:-1])
    ];
}

impl _members_named(G: nx.Graph, owners: list[str], member: str) -> list[str] {
    hits: dict[str, None] = {};
    for owner in owners {
        for nid in _membership_neighbors(G, owner, members=True) {
            if _symbol_name(G.nodes[nid]) == member {
                hits.setdefault(nid);
            }
        }
    }
    return `list(hits);
}

impl _names_source_file(G: nx.Graph, label: str) -> bool {
    def fold(text: str) -> str {
        return _strip_diacritics(text.strip().replace("\\", "/")).lower();
    }

    query: any = fold(label);
    for (_nid, d) in G.nodes(data=True) {
        source: any = fold(`str(d.get("source_file") or ""));
        if source and (source == query or source.endswith("/" + query)) {
            return True;
        }
    }
    return False;
}

impl _resolve_qualified_member(G: nx.Graph, label: str) -> list[str] {
    split: any = _split_qualified_member(label);
    if not split or _names_source_file(G, label) {
        return [];
    }
    qualifiers: any;
    member: any;
    (qualifiers, member) = split as any;
    return _members_named(G, _qualified_member_owners(G, qualifiers), member);
}

impl _no_member_match_message(G: nx.Graph, label: str) -> str | None {
    split: any = _split_qualified_member(label);
    if not split {
        return None;
    }
    term: any = " ".join(_search_tokens(label));
    norm_query: any = _strip_diacritics(label).lower().strip();
    if _label_has_literal_exact_match(G, term, norm_query) or _names_source_file(G, label) {
        return None;
    }
    qualifiers: any;
    member: any;
    (qualifiers, member) = split as any;
    bare_owners: any = _qualified_member_owners(G, qualifiers[-1:]);
    if not bare_owners {
        return None;
    }
    owner_text: any;
    _: any;
    member_text: any;
    (owner_text, _, member_text) = label.strip().removesuffix("()").rpartition(".") as any;
    msg: any = f"No node matching '{sanitize_label(label)}' found; no type '{sanitize_label(owner_text)}' declares '{sanitize_label(member_text)}'.";
    near: any = _members_named(G, bare_owners, member);
    if near {
        listing: any = "\n".join(
            "  "
                + format(G.nodes[n].get("source_file") or G.nodes[n].get("label") or n, "")
                + "\n    id: "
                + format(n, "")
            for n in near,
        );
        msg += f"\n{listing}\nRetry with the full node id.";
    }
    return msg;
}

impl _find_node_tiers(
    G: nx.Graph, label: str
) -> tuple[list[str], list[str], list[str], list[str]] {
    nid: any;
    wanted: any;
    term: any = " ".join(_search_tokens(label));
    norm_query: any = _strip_diacritics(`str(label)).lower().strip();
    if "::" in label and not _label_has_literal_exact_match(G, term, norm_query) {
        path_part: any;
        _: any;
        symbol_part: any;
        (path_part, _, symbol_part) = label.partition("::") as any;
        (path_part, symbol_part) = (path_part.strip(), symbol_part.strip());
        if path_part and symbol_part {
            scoped: any = _resolve_path_scoped_symbol(G, path_part, symbol_part);
            if scoped {
                return (scoped, [], [], []);
            }
        }
    }
    if _PY_QUALIFIED_RE.match(label.strip())
        and not _label_has_literal_exact_match(G, term, norm_query)
    {
        scoped = _resolve_python_qualified(G, label);
        if scoped {
            return (scoped, [], [], []);
        }
    }

    if not term {
        return ([], [], [], []);
    }
    source_exact: list[str] = [];
    exact: list[str] = [];
    prefix: list[str] = [];
    substring: list[str] = [];
    candidate_ids: any = _trigram_candidates(G, [term, norm_query]);
    node_iter: any = G.nodes(data=True)
        if candidate_ids is None
        else ((nid, G.nodes[nid]) for nid in candidate_ids);
    for (nid, d) in node_iter {
        norm_label: any = d.get("norm_label") or _strip_diacritics(d.get("label") or "").lower();
        bare_label: any = norm_label.rstrip("()");
        label_tokens: any = " ".join(_search_tokens(d.get("label") or ""));
        source_tokens: any = " ".join(_search_tokens(d.get("source_file") or ""));
        nid_lower: any = nid.lower();
        nid_norm: any = nid_lower if nid.isascii() else _strip_diacritics(nid).lower();
        if term == source_tokens {
            source_exact.append(nid);
        } elif term == norm_label
            or term == bare_label
            or term == label_tokens
            or term == nid_lower
            or norm_query == norm_label
            or norm_query == bare_label
            or norm_query == nid_norm
        {
            exact.append(nid);
        } elif norm_label.startswith(term)
            or bare_label.startswith(term)
            or label_tokens.startswith(term)
            or nid_lower.startswith(term)
            or norm_label.startswith(norm_query)
            or bare_label.startswith(norm_query)
        {
            prefix.append(nid);
        } elif term in norm_label or term in label_tokens or norm_query in norm_label {
            substring.append(nid);
        }
    }
    if not (source_exact or exact) {
        members: any = _resolve_qualified_member(G, label);
        if members {
            return ([], members, [], []);
        }
    }
    if len(exact) > 1 {
        def _bare(nid: str) -> str {
            return `str(G.nodes[nid].get("label") or "").strip().lstrip(".").removesuffix("()");
        }
        wanted = `str(label).strip().lstrip(".").removesuffix("()");
        same_case: any = [nid for nid in exact if _bare(nid) == wanted];
        if len(same_case) == 1
            and all(operator.eq(_bare(nid).lower(), wanted.lower()) for nid in exact)
        {
            prefix = [nid for nid in exact if nid != same_case[0]] + prefix;
            exact = same_case;
        }
    }

    if source_exact {
        query_basename: any = _strip_diacritics(Path(label).name).lower();
        preferred: any = [];
        for nid in source_exact {
            if `str(G.nodes[nid].get("source_location", "")) != "L1" {
                continue;
            }
            lbl: any = _strip_diacritics(`str(G.nodes[nid].get("label") or "")).lower();
            if lbl == query_basename or lbl.endswith("/" + query_basename) {
                preferred.append(nid);
            }
        }
        if len(preferred) == 1 {
            source_exact = preferred + [nid for nid in source_exact if nid != preferred[0]];
        }
    }

    return (source_exact, exact, prefix, substring);
}

impl _find_node(G: nx.Graph, label: str) -> list[str] {
    source_exact: any;
    exact: any;
    prefix: any;
    substring: any;
    (source_exact, exact, prefix, substring) = _find_node_tiers(G, label) as any;
    return source_exact + exact + prefix + substring;
}

impl find_node_ambiguity(G: nx.Graph, label: str) -> list[str] {
    for tier in _find_node_tiers(G, label) {
        if tier {
            return _rivals_across_files(G, tier);
        }
    }
    return [];
}

impl _rivals_across_files(G: nx.Graph, tier: list[str]) -> list[str] {
    by_file: dict[tuple[str, str], str] = {};
    for nid in tier {
        data: any = G.nodes[nid];
        file_id: any = (`str(data.get("repo") or ""), `str(data.get("source_file") or ""));
        by_file.setdefault(file_id, nid);
    }
    return `list(by_file.values()) if len(by_file) > 1 else [];
}

impl _near_miss_message(G: nx.Graph, label: str, hits: list[str], *, limit: int = 5) -> str {
    listing: any = [];
    for nid in hits[:limit] {
        d: any = G.nodes[nid];
        name: any = sanitize_label(`str(d.get("label") or nid));
        where: any = " ".join(
            part
            for part in (
                `str(d.get("source_file") or "").strip(),
                `str(d.get("source_location") or "").strip(),
            )
            if part,
        );
        listing.append(f"  {name}" + (f"  {sanitize_label(where)}" if where else ""));
    }
    if len(hits) > limit {
        listing.append(f"  ... and {len(hits) - limit} more");
    }
    example: any = sanitize_label(`str(G.nodes[hits[0]].get("label") or hits[0]));
    source: any = `str(G.nodes[hits[0]].get("source_file") or "").strip();
    example_form: any = f"{sanitize_label(source)}::{example}" if source else example;
    return f"No exact match for '{sanitize_label(label)}'. These names contain it, but none is called that:\n"
        + "\n".join(listing)
        + f"\nRetry with the exact label, a path::symbol form (e.g. {example_form}), or the full node id.";
}

impl _resolve_single_node(G: nx.Graph, label: str) -> tuple[str | None, str | None] {
    if label in G {
        return (label, None);
    }
    source_exact: any;
    exact: any;
    prefix: any;
    substring: any;
    (source_exact, exact, prefix, substring) = _find_node_tiers(G, label) as any;
    if not (source_exact or exact or prefix) {
        if not substring {
            return (None, f"No node matching '{label}' found.");
        }
        return (None, _near_miss_message(G, label, substring));
    }
    tier: any = source_exact or exact or prefix;
    refusal: any = _tier_refusal(
        G, label, tier, file_query=`bool(source_exact) and "::" not in label
    );
    if refusal {
        return (None, refusal);
    }
    return (tier[0], None);
}

impl _query_name_refusal(G: nx.Graph, label: str) -> str | None {
    source_exact: any;
    exact: any;
    _prefix: any;
    _substring: any;
    (source_exact, exact, _prefix, _substring) = _find_node_tiers(G, label) as any;
    tier: any = source_exact or exact;
    if not tier {
        return None;
    }
    refusal: any = _tier_refusal(
        G, label, tier, file_query=`bool(source_exact) and "::" not in label
    );
    return refusal if _is_ambiguity_refusal(refusal) else None;
}

impl _tier_refusal(G: nx.Graph, label: str, tier: list[str], *, file_query: bool) -> str | None {
    rivals: any = _rivals_across_files(G, tier);
    if rivals {
        return _ambiguity_message(G, label, rivals);
    }
    if file_query and len(tier) > 1 and tier == _resolve_python_qualified(G, label) {
        file_query = False;
    }
    if len(tier) > 1 and not file_query {
        return _same_file_ambiguity_message(G, label, tier);
    }
    return None;
}

impl _is_ambiguity_refusal(message: str | None) -> bool {
    return message is not None and message.startswith(_AMBIGUOUS);
}

impl _ambiguity_message(G: nx.Graph, label: str, rivals: list[str]) -> str {
    several_repos: any;
    sources: any;
    several_repos = operator.gt(len({`str(G.nodes[r].get("repo") or "") for r in rivals}), 1);

    def where(r: str) -> str {
        source: any = G.nodes[r].get("source_file") or "";
        repo: any = G.nodes[r].get("repo");
        return f"{repo}/{source}" if several_repos and repo and source else source;
    }

    listing: any = "\n".join(f"  {where(r) or r}\n    id: {r}" for r in rivals);
    symbol: any = G.nodes[rivals[0]].get("label") or label;
    sources = [`str(G.nodes[r].get("source_file") or "") for r in rivals];
    if `any(operator.gt(sources.count(src), 1) for src in sources if src) {
        retry: any = "Retry with the full node id: the same path exists in more than one repo, so a path cannot tell them apart.";
    } else {
        retry = f"Retry with path::symbol using one of the paths above (e.g. <path>::{symbol}) or the full node id.";
    }
    return f"{_AMBIGUOUS}'{label}' matches {len(rivals)} nodes in different files.\n{listing}\n{retry}";
}

impl _same_file_ambiguity_message(G: nx.Graph, label: str, hits: list[str]) -> str {
    source: any = G.nodes[hits[0]].get("source_file");
    where: any = f"in {source}" if source else "with no source file";
    listing: any = "\n".join(
        "  "
            + format(G.nodes[h].get("source_location") or G.nodes[h].get("label", h), "")
            + "\n    id: "
            + format(h, "")
        for h in hits,
    );
    return f"{_AMBIGUOUS}'{label}' matches {len(hits)} nodes {where}.\n{listing}\nRetry with the full node id.";
}

impl _no_scoped_match_message(G: nx.Graph, path_part: str, symbol_part: str) -> str {
    symbol_term: any = " ".join(_search_tokens(symbol_part));
    norm_symbol_query: any = _strip_diacritics(symbol_part).lower().strip();
    others: set[str] = set[any]();
    for (_nid, d) in G.nodes(data=True) {
        norm_label: any = d.get("norm_label") or _strip_diacritics(d.get("label") or "").lower();
        bare_label: any = norm_label.rstrip("()");
        label_tokens: any = " ".join(_search_tokens(d.get("label") or ""));
        if symbol_term == norm_label
            or symbol_term == bare_label
            or symbol_term == label_tokens
            or norm_symbol_query == norm_label
            or norm_symbol_query == bare_label
        {
            sf: any = d.get("source_file") or "";
            if sf {
                others.add(sf);
            }
        }
    }
    msg: any = f"No node matching '{path_part}::{symbol_part}' found; {path_part} defines no '{symbol_part}'.";
    if others {
        msg += "\n" + "\n".join(f"  defined in {s}" for s in sorted(others));
    }
    return msg;
}

impl _resolve_path_endpoint(G: nx.Graph, query: str) -> tuple[str
    | None, list[tuple[float, str]], str | None] {
    if query in G {
        return (query, [], None);
    }
    source_exact: any;
    exact: any;
    _: any;
    (source_exact, exact, _, _) = _find_node_tiers(G, query) as any;
    hits: any = source_exact or exact;
    if hits {
        refusal: any = _tier_refusal(
            G, query, hits, file_query=`bool(source_exact) and "::" not in query
        );
        if refusal {
            return (None, [], refusal);
        }
        return (hits[0], [], None);
    }
    path_part: any;
    sep: any;
    symbol_part: any;
    (path_part, sep, symbol_part) = query.partition("::") as any;
    if sep and path_part.strip() and symbol_part.strip() {
        return (None, [], _no_scoped_match_message(G, path_part.strip(), symbol_part.strip()));
    }
    no_member: any = _no_member_match_message(G, query);
    if no_member {
        return (None, [], no_member);
    }
    terms: any = [t.lower() for t in query.split()];
    scored: any = _score_nodes(G, terms);
    if not scored {
        return (None, [], None);
    }
    if not _query_uses_known_words(G, terms) {
        return (None, [], None);
    }
    return (_pick_scored_endpoint(G, scored, query), scored, None);
}

impl _query_uses_known_words(G: nx.Graph, terms: list[str]) -> bool {
    tokens: any = `list(dict.fromkeys(tok for t in terms for tok in _search_tokens(t)));
    if not tokens {
        return False;
    }
    for token in tokens {
        for (nid, d) in G.nodes(data=True) {
            if token in _search_tokens(nid) or token in _search_tokens(d.get("label") or "") {
                break;
            }
        } else {
            return False;
        }
    }
    return True;
}

impl _path_search_graph(G: nx.Graph, undirected: bool) -> nx.Graph {
    cache: any = G.graph.setdefault("_path_search_graphs", {});
    cached: any = cache.get(undirected);
    if cached is not None {
        return cached;
    }
    if undirected {
        H: any = nx.Graph();
        H.add_nodes_from(sorted(G.nodes));
        H.add_edges_from(sorted((min(u, v), max(u, v)) for (u, v) in G.edges()));
    } else {
        H = nx.DiGraph();
        H.add_nodes_from(sorted(G.nodes));
        H.add_edges_from(
            sorted((d.get("_src", u), d.get("_tgt", v)) for (u, v, d) in G.edges(data=True))
        );
        H.add_edges_from(
            sorted(
                (d.get("_tgt", v), d.get("_src", u))
                for (u, v, d) in G.edges(data=True)
                if d.get("relation") == "contains",
            ),
        );
    }
    cache[undirected] = H;
    return H;
}

impl _path_weakest(hop_datas: list[list[dict]]) -> any {
    weakest: any = None;
    for (hop, datas) in enumerate(hop_datas, 1) {
        for d in datas or [{}] {
            for ev in edge_evidence(d) {
                conf: any = ev.get("confidence");
                score: any = ev.get("confidence_score");
                if conf == "EXTRACTED"
                    or not isinstance(score, (`int, `float))
                    or isinstance(score, `bool)
                    or not math.isfinite(score)
                {
                    score = None;
                }
                rank: any = _CONFIDENCE_RANK.get(`str(conf), 0);
                key: any = (rank, score is None, score or 0.0, hop);
                if weakest is None or key < weakest[0] {
                    weakest = (
                        key,
                        hop,
                        d.get("relation") or "related",
                        conf if rank else None,
                        score,
                    );
                }
            }
        }
    }
    return weakest;
}

impl _path_confidence_line(hop_datas: list[list[dict]]) -> str {
    weakest: any = _path_weakest(hop_datas);
    if weakest is None {
        return "";
    }
    _: any;
    hop: any;
    rel: any;
    conf: any;
    score: any;
    (_, hop, rel, conf, score) = weakest as any;
    if conf is None {
        return f"Path confidence: unknown (hop {hop}: {rel} has no confidence tag)";
    }
    score_str: any = f", score {score:g}" if score is not None else "";
    return f"Path confidence: {conf} (weakest hop {hop}: {rel}{score_str})";
}

impl _path_hop_datas(G: nx.Graph, path_nodes: list[str]) -> list[list[dict]] {
    hop_datas: list[list[dict]] = [];
    for i in range(len(path_nodes) - 1) {
        u: any;
        v: any;
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
        hop_datas.append(fwd or bwd);
    }
    return hop_datas;
}

impl _path_confidence_key(hop_datas: list[list[dict]]) -> any {
    weakest: any = _path_weakest(hop_datas);
    return weakest[0] if weakest is not None else (-1, True, 0.0, 0);
}

impl _path_hub_penalty(G: nx.Graph, path_nodes: list[str]) -> int {
    penalty: any = 0;
    for nid in path_nodes[1:-1] {
        if not G.nodes[nid].get("source_file") {
            penalty += 1;
        }
    }
    return penalty;
}

impl _weakest_shortest_path(
    search_graph: nx.Graph, G: nx.Graph, src_nid: str, tgt_nid: str
) -> any {
    paths: list[list[str]] = [];
    for p in nx.all_shortest_paths(search_graph, src_nid, tgt_nid) {
        paths.append(p);
        if len(paths) > _MAX_SHORTEST_PATHS {
            break;
        }
    }
    capped: any = operator.gt(len(paths), _MAX_SHORTEST_PATHS);
    if capped {
        paths = paths[:_MAX_SHORTEST_PATHS];
    }
    chosen: any = min(
        paths,
        key=lambda (p) -> any {
            (_path_hub_penalty(G, p), _path_confidence_key(_path_hop_datas(G, p)))
        },
    );
    return (chosen, len(paths), capped);
}

impl _confidence_tag(d: dict) -> str {
    conf: any = `str(d.get("confidence") or "");
    score: any = d.get("confidence_score");
    if conf
        and conf != "EXTRACTED"
        and isinstance(score, (`int, `float))
        and not isinstance(score, `bool)
        and math.isfinite(score)
    {
        return f"{conf} {score:.2f}";
    }
    return conf;
}

impl _shortest_path_text(G: nx.Graph, arguments: dict) -> str {
    warnings: list[str];
    src_nid: any;
    src_scored: any;
    src_err: any;
    (src_nid, src_scored, src_err) = _resolve_path_endpoint(G, arguments["source"]) as any;
    if src_err {
        return src_err;
    }
    if src_nid is None {
        return "No node matching source '" + format(arguments["source"], "") + "' found.";
    }
    tgt_nid: any;
    tgt_scored: any;
    tgt_err: any;
    (tgt_nid, tgt_scored, tgt_err) = _resolve_path_endpoint(G, arguments["target"]) as any;
    if tgt_err {
        return tgt_err;
    }
    if tgt_nid is None {
        return "No node matching target '" + format(arguments["target"], "") + "' found.";
    }
    if src_nid == tgt_nid {
        return "'"
            + format(arguments["source"], "")
            + "' and '"
            + format(arguments["target"], "")
            + "' both resolved to the same node '"
            + format(src_nid, "")
            + "'. Use a more specific label or the exact node ID.";
    }
    warnings = [];
    for (name, scored, nid) in (("source", src_scored, src_nid), ("target", tgt_scored, tgt_nid)) {
        if len(scored) >= 2 and nid == scored[0][1] {
            top: any;
            runner: any;
            (top, runner) = (scored[0][0], scored[1][0]);
            if top > 0 and (top - runner) / top < 0.1 {
                warnings.append(
                    f"warning: {name} match was ambiguous (top score {top:g}, runner-up {runner:g})"
                );
            }
        }
    }
    max_hops: any = `int(arguments.get("max_hops", 8));
    undirected: any = `bool(arguments.get("undirected", False));
    try {
        path_nodes: any;
        n_routes: any;
        routes_capped: any;
        (path_nodes, n_routes, routes_capped) = _weakest_shortest_path(
            _path_search_graph(G, undirected), G, src_nid, tgt_nid
        ) as any;
    } except (nx.NetworkXNoPath, nx.NodeNotFound) {
        src_label: any = G.nodes[src_nid].get("label", src_nid);
        tgt_label: any = G.nodes[tgt_nid].get("label", tgt_nid);
        if undirected {
            return f"No path found between '{src_label}' and '{tgt_label}'.";
        }
        return f"No directed path found between '{src_label}' and '{tgt_label}'. Retry with undirected=true to search ignoring edge direction.";
    }
    hops: any = len(path_nodes) - 1;
    if hops > max_hops {
        return f"Path exceeds max_hops={max_hops} ({hops} hops found).";
    }
    segments: any = [];
    hop_datas: list[list[dict]] = [];
    for i in range(len(path_nodes) - 1) {
        u: any;
        v: any;
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
    prefix: any = "\n".join(warnings) + "\n" if warnings else "";
    summary: any = _path_confidence_line(hop_datas);
    if n_routes > 1 and summary {
        summary += " (weakest of "
            + format("256+" if routes_capped else n_routes, "")
            + " equal-length routes)";
    }
    return prefix
        + f"Shortest path ({hops} hops):\n  "
        + " ".join(segments)
        + (f"\n{summary}" if summary else "");
}

impl _filter_blank_stdin -> None {
    w_fd: any;
    saved_fd: any;
    r_fd: any;
    (r_fd, w_fd) = os.pipe() as any;
    saved_fd = os.dup(sys.stdin.fileno());

    def _relay -> None {
        try {
            src: any;
            dst: any;
            with open(saved_fd, "rb") as src, open(w_fd, "wb") as dst {
                for line in src {
                    if line.strip() {
                        dst.write(line);
                        dst.flush();
                    }
                }
            }
        } except Exception {}
    }

    threading.Thread(target=_relay, daemon=True).start();
    os.dup2(r_fd, sys.stdin.fileno());
    os.close(r_fd);
    sys.stdin = open(0, "r", closefd=False);
}

impl _community_header(cid: int, community_name) -> str {
    base: any = f"Community {cid}";
    if community_name {
        clean: any = sanitize_label(`str(community_name));
        if clean and clean != base {
            return f"{base} — {clean}";
        }
    }
    return base;
}

impl _neighbor_lines(G: nx.Graph, nid: str, rel_filter: str = "") -> list[str] {
    def _edge_at(d: dict) -> str {
        loc: any = `str(d.get("source_location") or "");
        return " at="
            + format(sanitize_label(`str(d.get("source_file") or "")), "")
            + ":"
            + format(sanitize_label(loc), "")
            if loc
            else "";
    }
    lines: list[str] = [];
    nb: any;
    for nb in G.successors(nid) {
        d: any;
        for d in edge_datas(G, nid, nb) {
            rel: any = d.get("relation", "");
            if rel_filter and rel_filter not in rel.lower() {
                continue;
            }
            lines.append(
                "  --> "
                    + format(sanitize_label(G.nodes[nb].get("label", nb)), "")
                    + " ["
                    + format(sanitize_label(`str(rel)), "")
                    + "] ["
                    + format(sanitize_label(_confidence_tag(d)), "")
                    + "]"
                    + format(_edge_at(d), ""),
            );
        }
    }
    for nb in G.predecessors(nid) {
        for d in edge_datas(G, nb, nid) {
            rel = d.get("relation", "");
            if rel_filter and rel_filter not in rel.lower() {
                continue;
            }
            lines.append(
                "  <-- "
                    + format(sanitize_label(G.nodes[nb].get("label", nb)), "")
                    + " ["
                    + format(sanitize_label(`str(rel)), "")
                    + "] ["
                    + format(sanitize_label(_confidence_tag(d)), "")
                    + "]"
                    + format(_edge_at(d), ""),
            );
        }
    }
    return lines;
}

impl _warm_graph(resolve, load, project_path) -> None {
    import anyio;

    await anyio.to_thread.run_sync(load, resolve(project_path));
}

impl _after_warm(warm, project_path, run, *args_) -> any {
    args: any = tuple(args_);
    if warm is not None {
        await warm(project_path);
    }
    return run(*args);
}

impl _call_tool(handlers, warm, select, name: str, arguments: dict) -> any {
    import from mcp { types }

    arguments = `dict(arguments or {});
    project_path: any = arguments.pop("project_path", None);
    handler: any = handlers.get(name);
    if not handler {
        return [types.TextContent(type="text", text=f"Unknown tool: {name}")];
    }
    try {
        await warm(project_path);
        select(project_path);
        return [types.TextContent(type="text", text=handler(arguments))];
    } except ToolError {
        raise;
    } except Exception as exc {
        return [types.TextContent(type="text", text=f"Error executing {name}: {exc}")];
    }
}

impl _on_list_tools(list_tools, ctx, params) -> any {
    import from mcp { types }

    return types.ListToolsResult(tools=await list_tools());
}

impl _on_call_tool(call_tool, ctx, params) -> any {
    import from mcp { types }

    try {
        content: any = await call_tool(params.name, `dict(params.arguments or {}));
    } except ToolError as exc {
        return types.CallToolResult(
            content=[types.TextContent(type="text", text=`str(exc))], isError=True
        );
    }
    return types.CallToolResult(content=content);
}

impl _on_list_resources(list_resources, ctx, params) -> any {
    import from mcp { types }

    return types.ListResourcesResult(resources=await list_resources());
}

impl _on_read_resource(read_resource, ctx, params) -> any {
    import from mcp { types }

    text: any = await read_resource(params.uri);
    mime: any = "text/markdown"
        if `str(params.uri).startswith("graphify://report")
        else "text/plain";
    return types.ReadResourceResult(
        contents=[types.TextResourceContents(uri=params.uri, mimeType=mime, text=text)]
    );
}

impl _run_stdio(server, stdio_server) -> None {
    streams: any;
    async with stdio_server() as streams {
        await server.run(streams[0], streams[1], server.create_initialization_options());
    }
}

impl _build_server(graph_path: str) -> any {
    _default_graph_path: any;
    _ctx_cache: any;
    active_graph_path: any;
    G: any;
    communities: any;
    try {
        import from mcp.server { Server }
        import from mcp { types }
    } except ImportError as e {
        raise ImportError("mcp not installed. Run: pip install \"graphifyy[mcp]\"") from e;
    }
    try {
        import from mcp.types { AnyUrl }
    } except ImportError {
        import from pydantic { AnyUrl }
    }

    _paths: any = importlib.import_module("graphify.paths");
    _default_graph_path = `str(Path(graph_path).resolve());
    _ctx_cache = _GraphContextCache(_max_server_contexts());

    """Return the current default or project graph context as a tool error.

        Unlike ``_load_graph``, this never lets a missing or corrupt client
        graph terminate the MCP process; it raises so other projects remain
        available on the same server.
        """
    def _load_ctx(path: str) -> any {
        resolved_path: any = `str(Path(path).resolve());
        return _ctx_cache.load(
            resolved_path, pinned=operator.eq(resolved_path, _default_graph_path)
        );
    }

    """Map an optional project_path to a concrete graph.json path. ``None``
        keeps the server's default graph (backward-compatible); a project_path
        resolves to ``<project_path>/<GRAPHIFY_OUT>/graph.json``, honouring the
        GRAPHIFY_OUT override so worktree/shared-output setups keep working."""
    def _resolve_graph_path(project_path) -> str {
        if not project_path {
            return _default_graph_path;
        }
        return `str(Path(project_path) / _paths.GRAPHIFY_OUT / "graph.json");
    }
    active_graph_path = _default_graph_path;
    try {
        (G, communities) = _load_ctx(_default_graph_path) as any;
    } except (FileNotFoundError, RuntimeError) {
        (G, communities) = (None, {});
    }

    def _select_graph(project_path) -> None {
        path: any = _resolve_graph_path(project_path);
        (G, communities) = _load_ctx(path) as any;
        active_graph_path = `str(Path(path).resolve());
    }

    warm: any = functools.partial(_warm_graph, _resolve_graph_path, _load_ctx);
    def list_tools_now -> list[types.Tool] {
        _tools: any = [
            types.Tool(
                name="query_graph",
                description="Search the knowledge graph using BFS or DFS. Returns relevant nodes and edges as text context.",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "question": {
                            "type": "string",
                            "description": "Natural language question or keyword search",
                        },
                        "mode": {
                            "type": "string",
                            "enum": ["bfs", "dfs"],
                            "default": "bfs",
                            "description": "bfs=broad context, dfs=trace a specific path",
                        },
                        "depth": {
                            "type": "integer",
                            "default": 3,
                            "description": "Traversal depth (1-6)",
                        },
                        "token_budget": {
                            "type": "integer",
                            "default": 2000,
                            "description": "Max output tokens",
                        },
                        "context_filter": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Optional explicit edge-context filter, e.g. ['call', 'field']",
                        },
                        "demote_docs": {
                            "type": "boolean",
                            "default": True,
                            "description": "Rank source code above docs/config (default). Set false for a docs-first corpus so documents are not soft-demoted.",
                        },
                    },
                    "required": ["question"],
                },
            ),
            types.Tool(
                name="get_node",
                description="Get full details for a specific node by label or ID.",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "label": {"type": "string", "description": "Node label or ID to look up"},
                        "node_id": {"type": "string", "description": "Alias for label (node id)"},
                    },
                },
            ),
            types.Tool(
                name="get_section",
                description="Return the text of a Markdown section (a heading node, with its subsections) or a whole Markdown page, read from the source file. Use it instead of opening the .md file after query_graph or get_node lands on a heading.",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "label": {
                            "type": "string",
                            "description": "Heading label, node ID, or 'path/file.md::Heading' when several files share the heading",
                        },
                        "node_id": {"type": "string", "description": "Alias for label (node id)"},
                        "max_chars": {
                            "type": "integer",
                            "default": 8000,
                            "description": "Cap on returned characters",
                        },
                    },
                },
            ),
            types.Tool(
                name="get_neighbors",
                description="Get all direct neighbors of a node with edge details.",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "label": {"type": "string"},
                        "node_id": {"type": "string", "description": "Alias for label (node id)"},
                        "relation_filter": {
                            "type": "string",
                            "description": "Optional: filter by relation type",
                        },
                        "token_budget": {
                            "type": "integer",
                            "default": 2000,
                            "description": "Max output tokens",
                        },
                    },
                },
            ),
            types.Tool(
                name="get_community",
                description="Get all nodes in a community by community ID.",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "community_id": {
                            "type": "integer",
                            "description": "Community ID (0-indexed by size)",
                        },
                        "token_budget": {
                            "type": "integer",
                            "default": 2000,
                            "description": "Max output tokens",
                        },
                    },
                    "required": ["community_id"],
                },
            ),
            types.Tool(
                name="god_nodes",
                description="Return the most connected nodes - the core abstractions of the knowledge graph.",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "top_n": {"type": "integer", "default": 10},
                        "exclude_hubs_percentile": {
                            "type": "number",
                            "description": "Suppress nodes whose degree exceeds this percentile (0-100) of the degree distribution, matching cluster()'s hub exclusion",
                        },
                    },
                },
            ),
            types.Tool(
                name="graph_stats",
                description="Return summary statistics: node count, edge count, communities, confidence breakdown.",
                inputSchema={"type": "object", "properties": {}},
            ),
            types.Tool(
                name="shortest_path",
                description="Find the shortest path between two concepts in the knowledge graph. Follows stored edge direction by default; set undirected=true to ignore it. Ends with the path's confidence, which is that of its weakest hop.",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "source": {
                            "type": "string",
                            "description": "Source concept label or keyword",
                        },
                        "target": {
                            "type": "string",
                            "description": "Target concept label or keyword",
                        },
                        "max_hops": {
                            "type": "integer",
                            "default": 8,
                            "description": "Maximum hops to consider",
                        },
                        "undirected": {
                            "type": "boolean",
                            "default": False,
                            "description": "Ignore stored edge direction when searching",
                        },
                    },
                    "required": ["source", "target"],
                },
            ),
            types.Tool(
                name="list_prs",
                description="List open GitHub PRs with CI status, review state, and graph impact (which communities each PR touches, blast radius). Use this before starting work to check if a PR already covers the area you're about to change.",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "base": {
                            "type": "string",
                            "description": "Base branch to filter PRs by (auto-detected if omitted)",
                        },
                        "repo": {
                            "type": "string",
                            "description": "GitHub repo (owner/repo). Defaults to current repo.",
                        },
                    },
                },
            ),
            types.Tool(
                name="get_pr_impact",
                description="Get detailed graph impact for a specific PR: which files it changes, which knowledge-graph communities are affected, and how many nodes are touched. Use this to assess merge risk or check for overlap with your current work.",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "pr_number": {"type": "integer", "description": "PR number to analyse"},
                        "repo": {
                            "type": "string",
                            "description": "GitHub repo (owner/repo). Defaults to current repo.",
                        },
                    },
                    "required": ["pr_number"],
                },
            ),
            types.Tool(
                name="triage_prs",
                description="Return all actionable open PRs (correct base, not stale) with full graph impact data so you can reason about review priority, merge order, and conflict risk. Call this when the user asks 'what PRs should I review?' or 'what's ready to merge?'",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "base": {
                            "type": "string",
                            "description": "Base branch to filter PRs by (auto-detected if omitted)",
                        },
                        "repo": {
                            "type": "string",
                            "description": "GitHub repo (owner/repo). Defaults to current repo.",
                        },
                    },
                },
            ),
        ];
        for _t in _tools {
            _schema: any = getattr(_t, "inputSchema", None);
            if _schema is None {
                _schema = _t.input_schema;
            }
            _schema.setdefault("properties", {})["project_path"] = {
                "type": "string",
                "description": "Absolute path to a project directory containing graphify-out/graph.json. Optional — defaults to the graph this server was started with.",
            };
        }
        return _tools;
    }

    def _tool_query_graph(arguments: dict) -> str {
        import time as _time;
        querylog: any = importlib.import_module("graphify.querylog");
        question: any = arguments["question"];
        mode: any = arguments.get("mode", "bfs");
        depth: any = min(`int(arguments.get("depth", 3)), 6);
        budget: any = `int(arguments.get("token_budget", 2000));
        context_filter: any = arguments.get("context_filter");
        demote_docs: any = arguments.get("demote_docs", True);
        if isinstance(demote_docs, `str) {
            demote_docs = demote_docs.lower() not in ("false", "0", "no");
        }
        _t0: any = _time.perf_counter();
        result: any = _query_graph_text(
            G,
            question,
            mode=mode,
            depth=depth,
            token_budget=budget,
            context_filters=context_filter,
            graph_path=`str(active_graph_path),
            demote_docs=demote_docs,
        );
        querylog.log_query(
            kind="mcp_query",
            question=question,
            corpus=`str(active_graph_path),
            result=result,
            mode=mode,
            depth=depth,
            token_budget=budget,
            duration_ms=(_time.perf_counter() - _t0) * 1000,
        );
        return result;
    }

    def _tool_get_node(arguments: dict) -> str {
        _is_section_node: any = importlib.import_module("graphify.sections").is_section_node;

        raw: any = _node_arg(arguments);
        if not raw {
            return "Provide a node label or id (accepted keys: label, node_id, id).";
        }
        label: any = raw;
        nid: any;
        err: any;
        (nid, err) = _resolve_single_node(G, label) as any;
        if err {
            return err;
        }
        d: any = G.nodes[nid];
        attrs: any = d.get("attributes");
        attrs_line: any = [];
        if isinstance(attrs, `dict) and attrs {
            raw_attrs: any = json.dumps(attrs, sort_keys=True);
            if len(raw_attrs) > 1000 {
                raw_attrs = raw_attrs[:997] + "...";
            }
            attrs_line = ["  Attributes: " + format(_CONTROL_CHAR_RE.sub("", raw_attrs), "")];
        }
        return "\n".join([
            "Node: " + format(sanitize_label(d.get("label", nid)), ""),
            f"  ID: {sanitize_label(nid)}",
            "  Source: "
                + format(sanitize_label(`str(d.get("source_file", ""))), "")
                + " "
                + format(sanitize_label(`str(d.get("source_location", ""))), ""),
            *(
                [
                    "  Defined in: "
                        + format(sanitize_label(`str(d.get("definition_file", ""))), "")
                        + " "
                        + format(sanitize_label(`str(d.get("definition_location", ""))), ""),
                ]
                    if d.get("definition_file")
                    else []
            ),
            *(
                ["  Section: get_section returns this Markdown section's text"]
                    if _is_section_node(d)
                    else []
            ),
            "  Type: " + format(sanitize_label(`str(d.get("file_type", ""))), ""),
            "  Community: "
                + format(
                    sanitize_label(`str(d.get("community_name") or d.get("community", ""))), ""
                ),
            f"  Degree: {G.degree(nid)}",
            *attrs_line,
        ]);
    }

    def _tool_get_section(arguments: dict) -> str {
        DEFAULT_MAX_CHARS: any = importlib.import_module("graphify.sections").DEFAULT_MAX_CHARS;
        format_section: any = importlib.import_module("graphify.sections").format_section;
        read_section: any = importlib.import_module("graphify.sections").read_section;
        resolve_section_query: any = importlib.import_module("graphify.sections").resolve_section_query;
        section_root: any = importlib.import_module("graphify.sections").section_root;

        raw: any = _node_arg(arguments);
        if not raw {
            return "Provide a node label or id (accepted keys: label, node_id, id).";
        }
        nid: any;
        err: any;
        (nid, err) = resolve_section_query(G, raw) as any;
        if nid is None {
            return err;
        }
        d: any = G.nodes[nid];
        max_chars: any = max(1, `int(arguments.get("max_chars", DEFAULT_MAX_CHARS)));
        section: any;
        reason: any;
        (section, reason) = read_section(
            d, section_root(Path(active_graph_path)), max_chars
        ) as any;
        if section is None {
            return sanitize_label(reason);
        }
        return format_section(section, sanitize_label(d.get("label", nid)));
    }

    def _tool_get_neighbors(arguments: dict) -> str {
        raw: any = _node_arg(arguments);
        if not raw {
            return "Provide a node label or id (accepted keys: label, node_id, id).";
        }
        label: any = raw;
        rel_filter: any = arguments.get("relation_filter", "").lower();
        nid: any;
        err: any;
        (nid, err) = _resolve_single_node(G, label) as any;
        if err {
            return err;
        }
        lines: any = [
            "Neighbors of " + format(sanitize_label(G.nodes[nid].get("label", nid)), "") + ":",
        ];
        lines.extend(_neighbor_lines(G, nid, rel_filter));
        budget: any = `int(arguments.get("token_budget", 2000));
        return _cut_lines_to_budget(
            lines, budget, "Narrow with relation_filter or use get_node for a specific symbol"
        );
    }

    def _tool_get_community(arguments: dict) -> str {
        cid: any = `int(arguments["community_id"]);
        nodes: any = communities.get(cid, []);
        if not nodes {
            return f"Community {cid} not found.";
        }
        header: any = _community_header(cid, G.nodes[nodes[0]].get("community_name"));
        lines: any = [f"{header} ({len(nodes)} nodes):"];
        for n in nodes {
            d: any = G.nodes[n];
            lines.append(
                "  "
                    + format(sanitize_label(d.get("label", n)), "")
                    + " ["
                    + format(sanitize_label(`str(d.get("source_file", ""))), "")
                    + "]",
            );
        }
        budget: any = `int(arguments.get("token_budget", 2000));
        return _cut_lines_to_budget(
            lines, budget, "Raise token_budget or use get_node for specific members"
        );
    }

    def _tool_god_nodes(arguments: dict) -> str {
        _god_nodes: any = importlib.import_module("graphify.analyze").god_nodes;
        _pct: any = arguments.get("exclude_hubs_percentile");
        nodes: any = _god_nodes(
            G,
            top_n=`int(arguments.get("top_n", 10)),
            exclude_hubs_percentile=`float(_pct) if _pct is not None else None,
        );
        lines: any = ["God nodes (most connected):"];
        lines += [
            "  "
                + format(i, "")
                + ". "
                + format(n["label"], "")
                + " - "
                + format(n["degree"], "")
                + " edges"
            for (i, n) in enumerate(nodes, 1)
        ];
        return "\n".join(lines);
    }

    def _tool_graph_stats(_: dict) -> str {
        confs: any = [d.get("confidence", "EXTRACTED") for (_, _, d) in G.edges(data=True)];
        total: any = len(confs) or 1;
        return "Nodes: "
            + format(G.number_of_nodes(), "")
            + "\nEdges: "
            + format(G.number_of_edges(), "")
            + "\nCommunities: "
            + format(len(communities), "")
            + "\nEXTRACTED: "
            + format(round(confs.count("EXTRACTED") / total * 100), "")
            + "%\nINFERRED: "
            + format(round(confs.count("INFERRED") / total * 100), "")
            + "%\nAMBIGUOUS: "
            + format(round(confs.count("AMBIGUOUS") / total * 100), "")
            + "%\n"
            + format(_build_commit_line(), "");
    }

    """Which commit the graph was built from, and whether HEAD has moved on.

        An MCP client cannot stat graph.json, so this is its only staleness
        signal (#3354). HEAD is read at query time from the repo holding the
        graph (the same anchor export.to_json stamps from); no git or no repo
        just drops the HEAD comparison. Empty when the graph has no commit.
        """
    def _build_commit_line -> str {
        commit: any = getattr(G, "graph", {}).get("_built_at_commit");
        if not commit {
            return "";
        }
        _git_head: any = importlib.import_module("graphify.export")._git_head;
        head: any = _git_head(Path(active_graph_path).parent);
        if not head {
            return f"Built at commit: {commit}\n";
        }
        if head == commit {
            return f"Built at commit: {commit} (matches HEAD)\n";
        }
        return f"Built at commit: {commit}\nHEAD is {head[:7]}, graph built at {commit[:7]}: graph may be stale\n";
    }

    def _tool_shortest_path(arguments: dict) -> str {
        return _shortest_path_text(G, arguments);
    }

    def _tool_list_prs(arguments: dict) -> str {
        fetch_prs: any = importlib.import_module("graphify.prs").fetch_prs;
        fetch_worktrees: any = importlib.import_module("graphify.prs").fetch_worktrees;
        format_prs_text: any = importlib.import_module("graphify.prs").format_prs_text;
        _detect_default_branch: any = importlib.import_module("graphify.prs")._detect_default_branch;
        repo: any = arguments.get("repo") or None;
        base: any = arguments.get("base") or _detect_default_branch(repo);
        try {
            prs: any = fetch_prs(repo=repo, base=base);
        } except RuntimeError as e {
            raise ToolError(f"Error: {e}") from e;
        }
        worktrees: any = fetch_worktrees();
        for pr in prs {
            pr.worktree_path = worktrees.get(pr.branch);
        }
        return format_prs_text(prs, base);
    }

    def _tool_get_pr_impact(arguments: dict) -> str {
        fetch_pr_files: any = importlib.import_module("graphify.prs").fetch_pr_files;
        compute_pr_impact: any = importlib.import_module("graphify.prs").compute_pr_impact;
        _gh: any = importlib.import_module("graphify.prs")._gh;
        _parse_ci: any = importlib.import_module("graphify.prs")._parse_ci;
        number: any = `int(arguments["pr_number"]);
        repo: any = arguments.get("repo") or None;
        view_args: any = [
            "pr",
            "view",
            `str(number),
            "--json",
            "title,headRefName,baseRefName,author,isDraft,reviewDecision,statusCheckRollup,updatedAt",
        ];
        if repo {
            view_args += ["--repo", repo];
        }
        pr_data: any = _gh(*view_args);
        if pr_data is None {
            raise ToolError(f"PR #{number} not found or gh not authenticated.");
        }
        files: any = fetch_pr_files(number, repo);
        if not files {
            return f"PR #{number}: no changed files found (may require gh auth).";
        }
        comms: any;
        nodes: any;
        (comms, nodes) = compute_pr_impact(files, G) as any;
        ci: any = _parse_ci(pr_data.get("statusCheckRollup") or []);
        lines: any = [
            "PR #" + format(number, "") + ": " + format(pr_data["title"], ""),
            "CI: "
                + format(ci, "")
                + "  Review: "
                + format(pr_data.get("reviewDecision") or "none", ""),
            "Base: "
                + format(pr_data["baseRefName"], "")
                + "  Author: "
                + format((pr_data.get("author") or {}).get("login", "?"), ""),
            f"\nGraph impact: {nodes} nodes across {len(comms)} communities",
            f"Communities touched: {comms}",
            f"Files changed ({len(files)}):",
        ];
        lines += [f"  {f}" for f in files[:20]];
        if len(files) > 20 {
            lines.append(f"  … and {len(files) - 20} more");
        }
        return "\n".join(lines);
    }

    def _tool_triage_prs(arguments: dict) -> str {
        p: any;
        import from concurrent.futures { ThreadPoolExecutor, as_completed }
        fetch_prs: any = importlib.import_module("graphify.prs").fetch_prs;
        fetch_worktrees: any = importlib.import_module("graphify.prs").fetch_worktrees;
        fetch_pr_files: any = importlib.import_module("graphify.prs").fetch_pr_files;
        compute_pr_impact: any = importlib.import_module("graphify.prs").compute_pr_impact;
        _STATUS_ORDER: any = importlib.import_module("graphify.prs")._STATUS_ORDER;
        _detect_default_branch: any = importlib.import_module("graphify.prs")._detect_default_branch;
        repo: any = arguments.get("repo") or None;
        base: any = arguments.get("base") or _detect_default_branch(repo);
        try {
            prs: any = fetch_prs(repo=repo, base=base);
        } except RuntimeError as e {
            raise ToolError(f"Error: {e}") from e;
        }
        worktrees: any = fetch_worktrees();
        pr: any;
        for pr in prs {
            pr.worktree_path = worktrees.get(pr.branch);
        }
        actionable: any = [
            p
            for p in prs
            if p.base_branch == base and p.status not in ("WRONG-BASE", "STALE")
        ];
        if not actionable {
            return f"No actionable PRs targeting {base}.";
        }
        workers: any = min(8, len(actionable));
        pool: any;
        with ThreadPoolExecutor(max_workers=workers) as pool {
            future_to_pr: any = {
                pool.submit(fetch_pr_files, pr.number, repo): pr
                for pr in actionable
            };
            for fut in as_completed(future_to_pr) {
                pr = future_to_pr[fut];
                try {
                    files: any = fut.result();
                } except Exception {
                    files = [];
                }
                if files {
                    pr.files_changed = files;
                    items_: any = list(compute_pr_impact(files, G) as any);
                    if len(items_) != 2 {
                        raise ValueError(
                            f"too many values to unpack (expected 2, got {len(items_)})"
                                if len(items_) > 2
                                else f"not enough values to unpack (expected 2, got {len(items_)})",
                        );
                    }
                    pr.communities_touched = items_[0];
                    pr.nodes_affected = items_[1];
                }
            }
        }
        header: any = f"Actionable PRs targeting {base}: {len(actionable)}\nRank these by review priority. Higher blast_radius = more graph communities affected = higher merge risk.\n";
        lines: any = [header];
        for p in sorted(
            actionable,
            key=lambda (x) -> any {
                _STATUS_ORDER.index(x.status) if x.status in _STATUS_ORDER else 99
            },
        ) {
            impact: any = f"  blast_radius={p.blast_radius}" if p.blast_radius else "";
            wt: any = f"  worktree={p.worktree_path}" if p.worktree_path else "";
            lines.append(
                "PR #"
                    + format(p.number, "")
                    + " ["
                    + format(p.status, "")
                    + "] CI="
                    + format(p.ci_status, "")
                    + " review="
                    + format(p.review_decision or "none", "")
                    + " age="
                    + format(p.days_old, "")
                    + "d author="
                    + format(p.author, "")
                    + format(impact, "")
                    + format(wt, "")
                    + "\n  title: "
                    + format(p.title, ""),
            );
        }
        return "\n\n".join(lines);
    }

    _handlers: any = {
        "query_graph": _tool_query_graph,
        "get_node": _tool_get_node,
        "get_section": _tool_get_section,
        "get_neighbors": _tool_get_neighbors,
        "get_community": _tool_get_community,
        "god_nodes": _tool_god_nodes,
        "graph_stats": _tool_graph_stats,
        "shortest_path": _tool_shortest_path,
        "list_prs": _tool_list_prs,
        "get_pr_impact": _tool_get_pr_impact,
        "triage_prs": _tool_triage_prs,
    };

    def _load_community_labels -> dict[int, str] {
        labels_path: any = Path(active_graph_path).parent / ".graphify_labels.json";
        if labels_path.exists() {
            try {
                return {
                    `int(k): v
                    for (k, v) in json.loads(labels_path.read_text(encoding="utf-8")).items()
                };
            } except Exception {}
        }
        return {cid: f"Community {cid}" for cid in communities};
    }

    def list_resources_now -> list[types.Resource] {
        return [
            types.Resource(
                uri="graphify://report",
                name="Graph Report",
                description="Full GRAPH_REPORT.md",
                mimeType="text/markdown",
            ),
            types.Resource(
                uri="graphify://stats",
                name="Graph Stats",
                description="Node/edge/community counts and confidence breakdown",
                mimeType="text/plain",
            ),
            types.Resource(
                uri="graphify://god-nodes",
                name="God Nodes",
                description="Top 10 most-connected nodes",
                mimeType="text/plain",
            ),
            types.Resource(
                uri="graphify://surprises",
                name="Surprising Connections",
                description="Cross-community surprising connections",
                mimeType="text/plain",
            ),
            types.Resource(
                uri="graphify://audit",
                name="Confidence Audit",
                description="EXTRACTED/INFERRED/AMBIGUOUS edge breakdown",
                mimeType="text/plain",
            ),
            types.Resource(
                uri="graphify://questions",
                name="Suggested Questions",
                description="Suggested questions for this codebase",
                mimeType="text/plain",
            ),
        ];
    }

    def read_resource_now(uri: AnyUrl) -> str {
        _select_graph(None);
        uri_str: any = `str(uri);
        if uri_str == "graphify://report" {
            report_path: any = Path(active_graph_path).parent / "GRAPH_REPORT.md";
            if report_path.exists() {
                return report_path.read_text(encoding="utf-8");
            }
            return "GRAPH_REPORT.md not found. Run graphify extract first.";
        }
        if uri_str == "graphify://stats" {
            return _tool_graph_stats({});
        }
        if uri_str == "graphify://god-nodes" {
            return _tool_god_nodes({"top_n": 10});
        }
        if uri_str == "graphify://surprises" {
            try {
                surprising_connections: any = importlib.import_module("graphify.analyze").surprising_connections;
                surprises: any = surprising_connections(G, communities, top_n=10);
                if not surprises {
                    return "No surprising connections found.";
                }
                lines: any = ["Surprising cross-community connections:"];
                for s in surprises {
                    lines.append(
                        "  "
                            + format(s.get("source", ""), "")
                            + " <-> "
                            + format(s.get("target", ""), "")
                            + " ["
                            + format(s.get("relation", ""), "")
                            + "]",
                    );
                }
                return "\n".join(lines);
            } except Exception as exc {
                return f"Could not compute surprising connections: {exc}";
            }
        }
        if uri_str == "graphify://audit" {
            confs: any = [d.get("confidence", "EXTRACTED") for (_, _, d) in G.edges(data=True)];
            total: any = len(confs) or 1;
            return "Total edges: "
                + format(total, "")
                + "\nEXTRACTED: "
                + format(confs.count("EXTRACTED"), "")
                + " ("
                + format(round(confs.count("EXTRACTED") / total * 100), "")
                + "%)\nINFERRED: "
                + format(confs.count("INFERRED"), "")
                + " ("
                + format(round(confs.count("INFERRED") / total * 100), "")
                + "%)\nAMBIGUOUS: "
                + format(confs.count("AMBIGUOUS"), "")
                + " ("
                + format(round(confs.count("AMBIGUOUS") / total * 100), "")
                + "%)\n";
        }
        if uri_str == "graphify://questions" {
            try {
                suggest_questions: any = importlib.import_module("graphify.analyze").suggest_questions;
                community_labels: any = _load_community_labels();
                questions: any = suggest_questions(G, communities, community_labels, top_n=10);
                if not questions {
                    return "No suggested questions available.";
                }
                lines = ["Suggested questions:"];
                for q in questions {
                    if isinstance(q, `dict) {
                        lines.append("  - " + format(q.get("question", ""), ""));
                    } else {
                        lines.append(f"  - {q}");
                    }
                }
                return "\n".join(lines);
            } except Exception as exc {
                return f"Could not generate questions: {exc}";
            }
        }
        raise ValueError(f"Unknown resource: {uri_str}");
    }
    list_tools: any = functools.partial(_after_warm, None, None, list_tools_now);
    list_resources: any = functools.partial(_after_warm, None, None, list_resources_now);
    read_resource: any = functools.partial(_after_warm, warm, None, read_resource_now);
    call_tool: any = functools.partial(_call_tool, _handlers, warm, _select_graph);

    if hasattr(Server, "list_tools") {
        server: any = Server("graphify");
        server.list_tools()(list_tools);
        server.call_tool()(call_tool);
        server.list_resources()(list_resources);
        server.read_resource()(read_resource);
    } else {
        try {
            import from importlib.metadata { version as _pkg_version }
            _version: any = _pkg_version("graphifyy");
        } except Exception {
            _version = "0";
        }
        server = Server(
            "graphify",
            version=_version,
            on_list_tools=functools.partial(_on_list_tools, list_tools),
            on_call_tool=functools.partial(_on_call_tool, call_tool),
            on_list_resources=functools.partial(_on_list_resources, list_resources),
            on_read_resource=functools.partial(_on_read_resource, read_resource),
        );
    }

    return server;
}

impl serve(graph_path: str | None = None) -> None {
    graph_path = graph_path or _default_graph_json();
    try {
        import from mcp.server.stdio { stdio_server }
    } except ImportError as e {
        raise ImportError("mcp not installed. Run: pip install \"graphifyy[mcp]\"") from e;
    }
    import asyncio;

    server: any = _build_server(graph_path);
    _filter_blank_stdin();
    asyncio.run(_run_stdio(server, stdio_server));
}

impl _mcp_asgi_call(app, scope, receive, send) -> None {
    await app._manager.handle_request(scope, receive, send);
}

impl _mcp_asgi_init(app, manager) -> None {
    app._manager = manager;
}

impl _api_key_call(gate, scope, receive, send) -> None {
    if scope["type"] != "http" {
        await gate.app(scope, receive, send);
        return;
    }
    import hmac;
    headers: any = `dict(scope.get("headers") or []);
    provided: any = headers.get(b"x-api-key");
    if provided is None {
        scheme: any;
        _: any;
        token: any;
        (scheme, _, token) = headers.get(b"authorization", b"").partition(b" ") as any;
        if scheme.lower() == b"bearer" and token {
            provided = token.strip();
        }
    }
    if provided is None or not hmac.compare_digest(provided, gate._expected) {
        body: any = b"{\"error\": \"unauthorized\"}";
        await send({
            "type": "http.response.start",
            "status": 401,
            "headers": [
                (b"content-type", b"application/json"),
                (b"content-length", `str(len(body)).encode("ascii")),
            ],
        });
        await send({"type": "http.response.body", "body": body});
        return;
    }
    await gate.app(scope, receive, send);
}

impl _api_key_init(gate, app, api_key: str) -> None {
    gate.app = app;
    gate._expected = api_key.encode("utf-8");
}

impl _build_http_app(
    graph_path: str,
    *,
    host: str = "127.0.0.1",
    port: int = 8080,
    api_key: str | None = None,
    path: str = "/mcp",
    json_response: bool = False,
    stateless: bool = False,
    session_timeout: float | None = 3600.0,
) -> any {
    manager: any;
    try {
        import from starlette.applications { Starlette }
        import from starlette.middleware { Middleware }
        import from starlette.routing { Route }

        import from mcp.server.streamable_http_manager { StreamableHTTPSessionManager }
        import from mcp.server.transport_security { TransportSecuritySettings }
    } except ImportError as e {
        raise ImportError(
            "HTTP transport needs the mcp extra (mcp + starlette + uvicorn). Run: pip install \"graphifyy[mcp]\"",
        ) from e;
    }
    api_key = (api_key or "").strip() or None;

    server: any = _build_server(graph_path);
    if host in ("0.0.0.0", "::", "") {
        security: any = TransportSecuritySettings(enable_dns_rebinding_protection=False);
    } else {
        bind: any = "[" + format(host.strip("[]"), "") + "]" if ":" in host else host;
        allowed: any = {bind, "localhost", "127.0.0.1"};
        allowed |= {f"{h}:{port}" for h in `list(allowed)};
        security = TransportSecuritySettings(allowed_hosts=sorted(allowed));
    }
    idle_timeout: any = None
        if stateless or not session_timeout or session_timeout <= 0
        else session_timeout;

    manager = StreamableHTTPSessionManager(
        app=server,
        json_response=json_response,
        stateless=stateless,
        security_settings=security,
        session_idle_timeout=idle_timeout,
    );

    def lifespan(_app) -> any {
        return manager.run();
    }

    middleware: any = [];
    if api_key {
        middleware.append(Middleware(_ApiKeyMiddleware, api_key=api_key));
    }

    return Starlette(
        routes=[Route(path, endpoint=_MCPASGIApp(manager))],
        middleware=middleware,
        lifespan=lifespan,
    );
}

impl serve_http(
    graph_path: str | None = None,
    *,
    host: str = "127.0.0.1",
    port: int = 8080,
    api_key: str | None = None,
    path: str = "/mcp",
    json_response: bool = False,
    stateless: bool = False,
    session_timeout: float | None = 3600.0,
) -> None {
    graph_path = graph_path or _default_graph_json();
    try {
        import uvicorn;
    } except ImportError as e {
        raise ImportError(
            "HTTP transport needs the mcp extra (mcp + starlette + uvicorn). Run: pip install \"graphifyy[mcp]\"",
        ) from e;
    }

    api_key = (api_key or "").strip() or None;

    app: any = _build_http_app(
        graph_path,
        host=host,
        port=port,
        api_key=api_key,
        path=path,
        json_response=json_response,
        stateless=stateless,
        session_timeout=session_timeout,
    );

    auth_note: any = "api-key required" if api_key else "no auth (set --api-key to require one)";
    print(
        f"graphify MCP server (streamable-http) on http://{host}:{port}{path} - {auth_note}",
        file=sys.stderr,
    );
    if host in ("0.0.0.0", "::", "") and not api_key {
        print(
            "WARNING: binding "
                + format(host or "0.0.0.0", "")
                + " with no api-key exposes the graph unauthenticated on the network. Set --api-key (or GRAPHIFY_API_KEY).",
            file=sys.stderr,
        );
    }
    uvicorn.run(app, host=host, port=port);
}

impl _main(argv: list[str] | None = None) -> None {
    import argparse;
    import os;

    parser: any = argparse.ArgumentParser(
        prog="python -m graphify.serve",
        description="Serve a graphify knowledge graph over MCP (stdio or Streamable HTTP).",
    );
    parser.add_argument(
        "graph_path",
        nargs="?",
        default=None,
        help="Path to graph.json (default: graphify-out/graph.json)",
    );
    parser.add_argument(
        "--graph",
        dest="graph_flag",
        default=None,
        metavar="PATH",
        help="Path to graph.json — alias for the positional argument",
    );
    parser.add_argument(
        "--transport",
        choices=["stdio", "http"],
        default="stdio",
        help="Transport to serve on (default: stdio)",
    );
    parser.add_argument("--host", default="127.0.0.1", help="HTTP bind host (default: 127.0.0.1)");
    parser.add_argument("--port", type=int, default=8080, help="HTTP bind port (default: 8080)");
    parser.add_argument(
        "--api-key",
        default=os.environ.get("GRAPHIFY_API_KEY"),
        help="Require this key on the HTTP transport (env: GRAPHIFY_API_KEY)",
    );
    parser.add_argument("--path", default="/mcp", help="HTTP mount path (default: /mcp)");
    parser.add_argument(
        "--json-response",
        action="store_true",
        help="Return plain JSON responses instead of SSE streams",
    );
    parser.add_argument(
        "--stateless",
        action="store_true",
        help="Run without per-session state (for load-balanced / CI deployments)",
    );
    parser.add_argument(
        "--session-timeout",
        type=float,
        default=3600.0,
        help="Reap stateful sessions idle this many seconds (default: 3600; 0 disables)",
    );
    args: any = parser.parse_args(argv);
    graph_path: any = args.graph_flag or args.graph_path or _default_graph_json();

    if args.transport == "http" {
        serve_http(
            graph_path,
            host=args.host,
            port=args.port,
            api_key=args.api_key,
            path=args.path,
            json_response=args.json_response,
            stateless=args.stateless,
            session_timeout=args.session_timeout,
        );
    } else {
        serve(graph_path);
    }
}
