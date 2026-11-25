impl _is_label_char(ch: str) -> bool {
    return ch.isalnum() or unicodedata.category(ch).startswith("M");
}

impl _norm(label: str | None) -> str {
    if not isinstance(label, `str) {
        label = "" if label is None else `str(label);
    }
    label = unicodedata.normalize("NFKC", label).casefold();
    out: list[str] = [];
    pending_sep: any = False;
    for ch in label {
        if _is_label_char(ch) {
            if pending_sep and out {
                out.append(" ");
            }
            pending_sep = False;
            out.append(ch);
        } else {
            pending_sep = True;
        }
    }
    return "".join(out);
}

impl _entropy(label: str) -> float {
    n: any;
    s: any = _norm(label);
    if not s {
        return 0.0;
    }
    freq: dict[str, int] = defaultdict(int);
    for ch in s {
        freq[ch] += 1;
    }
    n = len(s);
    return -sum(c / n * math.log2(c / n) for c in freq.values());
}

impl _shingles(text: str, k: int = 3) -> set[str] {
    if len(text) < k {
        return {text};
    }
    return {text[i:i + k] for i in range(len(text) - k + 1)};
}

impl _make_minhash(text: str, num_perm: int = 128) -> MinHash {
    m: any = MinHash(num_perm=num_perm);
    for shingle in _shingles(text.replace(" ", "")) {
        m.update(shingle.encode("utf-8"));
    }
    return m;
}

impl _is_variant_pair(a: str, b: str) -> bool {
    if a == b {
        return False;
    }
    if max(len(a), len(b)) >= 12 {
        return False;
    }
    ma: any;
    mb: any;
    (ma, mb) = (_VARIANT_SUFFIX.match(a), _VARIANT_SUFFIX.match(b));
    if not (ma and mb) {
        return False;
    }
    return operator.eq(ma.group(1), mb.group(1)) and operator.ne(ma.group(2), mb.group(2));
}

impl _short_label_blocked(a: str, b: str, jw_score: float) -> bool {
    if max(len(a), len(b)) >= 12 {
        return False;
    }
    import from rapidfuzz.distance { DamerauLevenshtein }
    if jw_score >= 97.0 and len(a) == len(b) and DamerauLevenshtein.distance(a, b) <= 1 {
        return False;
    }
    return True;
}

impl _numeric_tokens_differ(a: str, b: str) -> bool {
    if a == b {
        return False;
    }
    return operator.ne(
        sorted(t.lstrip("0") or "0" for t in _DIGIT_RUN.findall(a)),
        sorted(t.lstrip("0") or "0" for t in _DIGIT_RUN.findall(b)),
    );
}

impl _same_word_variant(x: str, y: str) -> bool {
    if len(x) == len(y) and DamerauLevenshtein.distance(x, y) <= 1 {
        return True;
    }
    shorter: any;
    longer: any;
    (shorter, longer) = sorted((x, y), key=builtins.len) as any;
    if len(shorter) < len(longer) and longer.endswith(shorter) {
        return False;
    }
    if min(len(x), len(y)) < 6 {
        return False;
    }
    return operator.ge(JaroWinkler.normalized_similarity(x, y) * 100, _MERGE_THRESHOLD);
}

impl _content_token_swap(a: str, b: str) -> bool {
    tokens_a: any;
    tokens_b: any;
    (tokens_a, tokens_b) = (a.split(), b.split());
    if len(tokens_a) != len(tokens_b) {
        return False;
    }
    for (x, y) in zip(tokens_a, tokens_b) {
        if x == y {
            continue;
        }
        if x in _STOPWORDS or y in _STOPWORDS {
            continue;
        }
        if _same_word_variant(x, y) {
            continue;
        }
        return True;
    }
    return False;
}

impl _crossfile_fileanchored_blocked(`node: dict, neighbor: dict) -> bool {
    if `node.get("file_type") not in _FILE_ANCHORED_NONCODE
        and neighbor.get("file_type") not in _FILE_ANCHORED_NONCODE
    {
        return False;
    }
    return operator.ne(`node.get("source_file") or "", neighbor.get("source_file") or "");
}

impl _UF.init {
    self._parent = {};
}

impl _UF.find(x: str) -> str {
    self._parent.setdefault(x, x);
    while self._parent[x] != x {
        self._parent[x] = self._parent[self._parent[x]];
        x = self._parent[x];
    }
    return x;
}

impl _UF.union(x: str, y: str) -> None {
    self._parent.setdefault(x, x);
    self._parent.setdefault(y, y);
    rx: any;
    ry: any;
    (rx, ry) = (self.find(x), self.find(y));
    if rx != ry {
        self._parent[ry] = rx;
    }
}

impl _UF.components -> dict[str, list[str]] {
    groups: dict[str, list[str]] = defaultdict(list[any]);
    for x in self._parent {
        groups[self.find(x)].append(x);
    }
    return `dict(groups);
}

impl _UF.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl _UF.__eq__(other: any) -> bool {
    return self is other;
}

impl _UF.__hash__ -> int {
    return id(self);
}

impl _is_code(`node: dict) -> bool {
    return operator.eq(`node.get("file_type"), "code");
}

impl _id_prefixes(source_file: str) -> set[str] {
    stem: any = _EXTENSION.sub("", source_file.replace("\\", "/"));
    segments: any = [s for s in (normalize_id(p) for p in stem.split("/")) if s];
    return {"_".join(segments[i:]) for i in range(len(segments))};
}

impl _defines_id(`node: dict) -> bool {
    nid: any;
    nid = `node.get("id") or "";
    source_file: any = `node.get("source_file") or "";
    if not nid or not source_file {
        return False;
    }
    return `any(
        operator.eq(nid, prefix) or nid.startswith(f"{prefix}_")
        for prefix in _id_prefixes(source_file),
    );
}

impl _reads_as_file_entity(`node: dict) -> bool {
    nid: any = `node.get("id") or "";
    source_file: any = `node.get("source_file") or "";
    if not nid or not source_file {
        return False;
    }
    if `node.get("node_kind") in _FILE_STRUCTURE_NODE_KINDS {
        return False;
    }
    return nid not in _id_prefixes(source_file);
}

impl _lifecycle_penalty(rank_path: str) -> int {
    segments: any = [s for s in rank_path.casefold().split("/") if s];
    marked: any = [
        0 if s in _ACTIVE_PATH_SEGMENTS else 2
        for s in segments[:-1]
        if s in _ACTIVE_PATH_SEGMENTS or s in _ARCHIVED_PATH_SEGMENTS
    ];
    return min(marked) if marked else 1;
}

impl _rank_path(source_file: str, `root: Path | None) -> str {
    normalized: any = source_file.replace("\\", "/");
    if `root is not None and normalized and Path(normalized).is_absolute() {
        try {
            return Path(normalized).resolve().relative_to(`root).as_posix();
        } except Exception {}
    }
    return normalized;
}

impl _collision_rank(
    `node: dict,
    `root: Path | None = None,
    mentions: "frozenset | set" = mentions_default_,
    outranked: "frozenset | set" = outranked_default_,
) -> tuple {
    label: any = `node.get("label") or "";
    rank_path: any = _rank_path(`node.get("source_file") or "", `root);
    key: any = (`node.get("id"), rank_path);
    return (
        not _defines_id(`node) or key in mentions,
        key in outranked and operator.ne(`node.get("_origin"), "ast"),
        not `node.get("source_file"),
        _lifecycle_penalty(rank_path),
        len(label),
        label,
        `tuple(reversed([s for s in rank_path.split("/") if s and s != "."])),
    );
}

impl _outranked_by_ast(
    nodes: list[dict], `root: Path | None, mentions: "frozenset | set"
) -> set[tuple[str, str]] {
    stem: any;
    ast_defs: dict[str, list[tuple[str, str]]] = defaultdict(list[any]);
    others: list[tuple[str, str, str]] = [];
    for `node in nodes {
        nid: any = `node.get("id") or "";
        source_file: any = `node.get("source_file") or "";
        rank_path: any = _rank_path(source_file, `root);
        if not nid or not _defines_id(`node) or (nid, rank_path) in mentions {
            continue;
        }
        `entry: any = (rank_path, _full_stem(source_file));
        if `node.get("_origin") == "ast" {
            ast_defs[nid].append(`entry);
        } else {
            others.append((nid, *`entry));
        }
    }
    outranked: any = set[any]();
    for item_ in others {
        (nid, rank_path, stem) = item_;
        defs: any = ast_defs.get(nid, []);
        if defs
            and rank_path not in {rp for (rp, _) in defs}
            and `any(operator.ne(ast_stem, stem) for (_, ast_stem) in defs)
        {
            outranked.add((nid, rank_path));
        }
    }
    return outranked;
}

impl _mentions(nodes: list[dict], edges: list[dict], `root: Path | None) -> set[tuple[str, str]] {
    def key(sf) -> any {
        return _rank_path(sf, `root) if sf and isinstance(sf, `str) else "";
    }

    `own: dict[str, set[str]] = defaultdict(set[any]);
    for `node in nodes {
        nid: any = `node.get("id");
        if nid and isinstance(nid, `str) {
            `own[key(`node.get("source_file"))].add(nid);
        }
    }
    found: set[tuple[str, str]] = set[any]();
    for `edge in edges {
        if not isinstance(`edge, `dict) or `edge.get("relation") != "references" {
            continue;
        }
        k: any = key(`edge.get("source_file"));
        source: any;
        target: any;
        (source, target) = (`edge.get("source"), `edge.get("target"));
        if k
            and isinstance(source, `str)
            and isinstance(target, `str)
            and source != target
            and source in `own[k]
            and target in `own[k]
            and target in _id_prefixes(k)
        {
            found.add((target, k));
        }
    }
    return found;
}

impl _own_page_files(nodes: list[dict], `root: Path | None) -> set[str] {
    _is_abs: any = importlib.import_module("graphify.build")._is_abs;

    files: set[str] = set[any]();
    for `node in nodes {
        nid: any;
        sf: any;
        (nid, sf) = (`node.get("id"), `node.get("source_file"));
        if not nid or not isinstance(nid, `str) or not sf or not isinstance(sf, `str) {
            continue;
        }
        k: any = _rank_path(sf, `root);
        if _is_abs(k) {
            continue;
        }
        full: any = _full_stem(k);
        if nid == full or nid.startswith(f"{full}_") {
            files.add(k);
        }
    }
    return files;
}

impl _slice_references(nodes: list[dict], `root: Path | None) -> set[tuple[str, str]] {
    own_page: any = _own_page_files(nodes, `root);
    found: set[tuple[str, str]] = set[any]();
    for `node in nodes {
        nid: any;
        sf: any;
        (nid, sf) = (`node.get("id"), `node.get("source_file"));
        if not nid or not isinstance(nid, `str) or not sf or not isinstance(sf, `str) {
            continue;
        }
        k: any = _rank_path(sf, `root);
        if k in own_page and nid in _id_prefixes(k) and nid != _full_stem(k) {
            found.add((nid, k));
        }
    }
    return found;
}

impl _same_source_entity(survivor: dict, duplicate: dict) -> bool {
    keep_file: any = survivor.get("source_file") or "";
    lose_file: any = duplicate.get("source_file") or "";
    return `bool(keep_file) and operator.eq(keep_file, lose_file);
}

impl _merge_missing_attributes(survivor: dict, duplicate: dict) -> dict {
    merged: any = `dict(survivor);
    for (key, value) in duplicate.items() {
        if key == "_origin" {
            continue;
        }
        if value is None {
            continue;
        }
        if merged.get(key) is None {
            merged[key] = value;
        }
    }
    return merged;
}

impl _report_id_collision(nid: str, survivor: dict, losers: list[dict]) -> None {
    group: any = (survivor, *losers);
    if survivor.get("type") in _SHARED_ID_TYPES
        and all(operator.eq(n.get("type"), survivor.get("type")) for n in group)
        and all(operator.eq(n.get("label"), survivor.get("label")) for n in group)
    {
        return;
    }
    keep_file: any = survivor.get("source_file") or "";
    keep_label: any = survivor.get("label") or "";
    for loser in losers {
        lose_file: any = loser.get("source_file") or "";
        lose_label: any = loser.get("label") or "";
        if lose_file == keep_file {
            if _norm(lose_label) != _norm(keep_label) {
                print(
                    f"[graphify] note: node '{nid}' was extracted twice from '{keep_file}' under different labels — keeping '{keep_label}', dropping '{lose_label}'.",
                    file=sys.stderr,
                );
            }
        } elif _defines_id(survivor) and not _defines_id(loser) {
            continue;
        } else {
            print(
                f"[graphify] WARNING: node '{nid}' is minted by two different files — keeping '{keep_label}' from '{keep_file}', dropping '{lose_label}' from '{lose_file}'. An ID is derived from the source path plus the entity name, so this one does not identify a single entity and the dropped node is lost. To keep them distinct, run 'graphify extract' per subfolder and merge with 'graphify merge-graphs'.",
                file=sys.stderr,
            );
        }
    }
}

impl _full_stem(source_file: str) -> str {
    stem: any = _EXTENSION.sub("", source_file.replace("\\", "/"));
    return "_".join(s for s in (normalize_id(p) for p in stem.split("/")) if s);
}

impl _extension_qualified_id(`node: dict) -> str | None {
    nid: any = `node.get("id") or "";
    source_file: any = `node.get("source_file") or "";
    ext_match: any = _EXTENSION.search(source_file.replace("\\", "/"));
    full: any = _full_stem(source_file);
    if not (nid and full and ext_match) {
        return None;
    }
    if nid != full and not nid.startswith(f"{full}_") {
        return None;
    }
    return f"{full}_{normalize_id(ext_match.group(0))}{nid[len(full):]}";
}

impl _disambiguate_defining_collisions(
    nodes: list[dict], edges: list[dict], hyperedges: list[dict] | None, `root: Path | None
) -> tuple[list[dict], list[dict]] {
    d: any;
    def key(sf) -> any {
        return _rank_path(sf, `root) if sf else "";
    }

    by_id: dict[str, list[dict]] = defaultdict(list[any]);
    for `node in nodes {
        nid: any = `node.get("id");
        if nid and `node.get("source_file") and _extension_qualified_id(`node) {
            by_id[nid].append(`node);
        }
    }
    taken: any = {n.get("id") for n in nodes if n.get("id")};
    renames: dict[tuple[str, str], str] = {};
    for (nid, definers) in by_id.items() {
        if len({key(d["source_file"]) for d in definers}) < 2 {
            continue;
        }
        winner: any = min(definers, key=lambda (d) -> any { _collision_rank(d, `root) });
        for d in sorted(definers, key=lambda (d) -> any { key(d["source_file"]) }) {
            k: any = key(d["source_file"]);
            if k == key(winner["source_file"]) or (nid, k) in renames {
                continue;
            }
            if _full_stem(d["source_file"]) != _full_stem(winner["source_file"]) {
                continue;
            }
            if _EXTENSION.search(d["source_file"])
                and _EXTENSION.search(winner["source_file"])
                and _EXTENSION.search(d["source_file"]).group(0).lower()
                    == _EXTENSION.search(winner["source_file"]).group(0).lower()
            {
                continue;
            }
            new_id: any = _extension_qualified_id(d);
            if new_id and new_id not in taken {
                taken.add(new_id);
                renames[nid, k] = new_id;
            }
        }
    }
    if not renames {
        return (nodes, edges);
    }
    out_nodes: any = [
        `dict(`node, id=renames[`node.get("id"), key(`node.get("source_file"))])
            if (`node.get("id"), key(`node.get("source_file"))) in renames
            else `node
        for `node in nodes
    ];
    for coll in (edges, hyperedges or []) {
        for item in coll {
            if not isinstance(item, `dict) {
                continue;
            }
            k = key(item.get("source_file"));
            for end in ("source", "target") {
                new_id = renames.get((item.get(end), k));
                if new_id {
                    item[end] = new_id;
                }
            }
            members: any = item.get("nodes");
            if isinstance(members, `list) {
                item["nodes"] = [
                    renames.get((m, k), m) if isinstance(m, `str) else m
                    for m in members
                ];
            }
        }
    }
    return (out_nodes, edges);
}

impl _path_qualify_dropped_collisions(
    nodes: list[dict], edges: list[dict], hyperedges: list[dict] | None, `root: Path | None
) -> tuple[list[dict], list[dict]] {
    k: any;
    m: any;
    _is_abs: any = importlib.import_module("graphify.build")._is_abs;
    _is_ast_tier: any = importlib.import_module("graphify.build")._is_ast_tier;

    def key(sf) -> any {
        return _rank_path(sf, `root) if sf and isinstance(sf, `str) else "";
    }

    """``(new id, matched shorter prefix)`` for a candidate node, else None."""
    def qualified_id(`node: dict) -> tuple[str, str] | None {
        nid: any = `node.get("id");
        sf: any = `node.get("source_file");
        if not nid or not isinstance(nid, `str) or not sf or not isinstance(sf, `str) {
            return None;
        }
        if _is_ast_tier(`node) {
            return None;
        }
        rel: any = key(sf);
        if _is_abs(rel) {
            return None;
        }
        full: any = _full_stem(rel);
        matching: any = [p for p in _id_prefixes(rel) if nid == p or nid.startswith(f"{p}_")];
        if not full or not matching {
            return None;
        }
        longest: any = max(matching, key=builtins.len);
        if longest == full {
            return None;
        }
        return (full + nid[len(longest):], longest);
    }

    named_files: any = {
        _full_stem(key(n["source_file"]))
        for n in nodes
        if isinstance(n.get("source_file"), `str) and n["source_file"]
    };
    mentions: any = _mentions(nodes, edges, `root);
    by_id: dict[str, list[dict]] = defaultdict(list[any]);
    owners: dict[str, set[str]] = defaultdict(set[any]);
    kept_bare: set[tuple[str, str]] = set[any]();
    `node: any;
    for `node in nodes {
        nid: any = `node.get("id");
        if not nid or not isinstance(nid, `str) {
            continue;
        }
        k = key(`node.get("source_file"));
        owners[nid].add(k);
        if not qualified_id(`node) {
            continue;
        }
        if (nid, k) in mentions {
            kept_bare.add((nid, k));
        } else {
            by_id[nid].append(`node);
        }
    }
    own_page: any = _own_page_files(nodes, `root);

    renames: dict[tuple[str, str], str] = {};
    claimed: dict[str, str] = {};
    for nid in sorted(by_id) {
        members: any = by_id[nid];
        definers: any = {o for o in owners[nid] if o and not _is_abs(o) and _full_stem(o) == nid};
        files: any = {key(m["source_file"]) for m in members} | definers;
        if len(files) < 2 {
            continue;
        }
        if len({_full_stem(f) for f in files}) < 2 {
            continue;
        }
        for m in sorted(members, key=lambda (m) -> any { key(m["source_file"]) }) {
            k = key(m["source_file"]);
            if (nid, k) in renames or (nid, k) in kept_bare {
                continue;
            }
            if (qualified_id(m) or ("", ""))[1] in named_files and k in own_page {
                kept_bare.add((nid, k));
                continue;
            }
            qualified: any = qualified_id(m);
            new_id: any = qualified[0] if qualified else None;
            if new_id is None
                or `any(operator.ne(o, k) for o in owners.get(new_id, ()))
                or claimed.get(new_id, k) != k
            {
                kept_bare.add((nid, k));
                continue;
            }
            claimed[new_id] = k;
            renames[nid, k] = new_id;
        }
    }
    if not renames {
        return (nodes, edges);
    }

    out_nodes: any = [];
    for `node in nodes {
        new_id = renames.get((`str(`node.get("id") or ""), key(`node.get("source_file"))));
        out_nodes.append(`dict(`node, id=new_id) if new_id else `node);
    }
    renamed_ids: any = {nid for (nid, _) in renames};
    unattributed: dict[str, int] = defaultdict(int);
    for coll in (edges, hyperedges or []) {
        for item in coll {
            if not isinstance(item, `dict) {
                continue;
            }
            k = key(item.get("source_file"));
            refs: any = [item.get("source"), item.get("target")];
            members = item.get("nodes");
            if isinstance(members, `list) {
                refs += members;
            }
            ref: any;
            for ref in refs {
                if isinstance(ref, `str)
                    and ref in renamed_ids
                    and (ref, k) not in renames
                    and (ref, k) not in kept_bare
                {
                    unattributed[ref] += 1;
                }
            }
            for end in ("source", "target") {
                ref = item.get(end);
                new_id = renames.get((ref, k)) if isinstance(ref, `str) else None;
                if new_id {
                    item[end] = new_id;
                }
            }
            if isinstance(members, `list) {
                item["nodes"] = [
                    renames.get((m, k), m) if isinstance(m, `str) else m
                    for m in members
                ];
            }
        }
    }
    for nid in sorted(unattributed) {
        print(
            f"[graphify] WARNING: node '{nid}' was minted by several files and renamed per file; {unattributed[nid]} reference(s) from other files could not be attributed and were left unresolved.",
            file=sys.stderr,
        );
    }
    return (out_nodes, edges);
}

impl _is_reference_stub(`node: dict) -> bool {
    metadata: any = `node.get("metadata");
    return isinstance(metadata, `dict) and metadata.get("graphify_reference_stub") is True;
}

impl _namespace_reference_stub_collisions(
    nodes: list[dict],
    edges: list[dict],
    hyperedges: list[dict] | None,
    `root: Path | None,
    *,
    preserve_saved_semantics: bool = False,
) -> tuple[list[dict], list[dict]] {
    nid: any;
    taken: any;
    source_key: any;
    candidate: any;
    def key(source_file: object) -> str {
        return _rank_path(source_file, `root) if isinstance(source_file, `str) else "";
    }

    by_id: dict[str, list[dict]] = defaultdict(list[any]);
    for `node in nodes {
        nid = `node.get("id");
        if isinstance(nid, `str) and nid {
            by_id[nid].append(`node);
        }
    }

    taken = {`node.get("id") for `node in nodes if `node.get("id")};
    renames: dict[tuple[str, str], str] = {};
    members: any;
    for item__ in by_id.items() {
        (nid, members) = item__;
        if len({key(`node.get("source_file")) for `node in members}) < 2 {
            continue;
        }
        ast_sources: any = {
            key(`node.get("source_file"))
            for `node in members
            if `node.get("_origin") == "ast"
        };
        stubs: any = [
            `node
            for `node in members
            if _is_reference_stub(`node)
                or preserve_saved_semantics
                    and `root is not None
                    and `node.get("_origin") == "semantic"
                    and key(`node.get("source_file"))
                    and ast_sources
                    and key(`node.get("source_file")) not in ast_sources
        ];
        if not stubs {
            continue;
        }
        source_keys: any = {key(`node.get("source_file")) for `node in stubs};
        if "" in source_keys {
            continue;
        }
        candidates: any = {
            source_key: f"{_full_stem(source_key)}__ref__{nid}"
            for source_key in source_keys
            if _full_stem(source_key)
        };
        if len(candidates) != len(source_keys) {
            continue;
        }
        if len(`set(candidates.values())) != len(candidates) {
            continue;
        }
        if `any(candidate in taken for candidate in candidates.values()) {
            if not preserve_saved_semantics {
                continue;
            }
            reserved: any = taken | `set(candidates.values());
            for source_key in sorted(candidates) {
                base: any = candidates[source_key];
                candidate = base;
                suffix: any = 2;
                while candidate in taken or candidate != base and candidate in reserved {
                    candidate = f"{base}__{suffix}";
                    suffix += 1;
                }
                candidates[source_key] = candidate;
                reserved.add(candidate);
            }
        }
        renames.update(
            ((nid, source_key), candidate) for (source_key, candidate) in candidates.items()
        );
        taken.update(candidates.values());
    }

    if not renames {
        return (nodes, edges);
    }

    out_nodes: any = [
        `dict(`node, id=renames[`node["id"], key(`node.get("source_file"))])
            if (`node.get("id"), key(`node.get("source_file"))) in renames
            else `node
        for `node in nodes
    ];
    for collection in (edges, hyperedges or []) {
        for item in collection {
            if not isinstance(item, `dict) {
                continue;
            }
            if preserve_saved_semantics and item.get("_origin") == "ast" {
                continue;
            }
            source_key = key(item.get("source_file"));
            for endpoint in ("source", "target") {
                value: any = item.get(endpoint);
                replacement: any = renames.get((value, source_key));
                if replacement {
                    item[endpoint] = replacement;
                }
            }
            members = item.get("nodes");
            if isinstance(members, `list) {
                item["nodes"] = [
                    renames.get((member, source_key), member)
                        if isinstance(member, `str)
                        else member
                    for member in members
                ];
            }
        }
    }
    return (out_nodes, edges);
}

impl _remap_hyperedge_members(hyperedges: list[dict], remap: dict[str, str]) -> None {
    for he in hyperedges {
        if not isinstance(he, `dict) {
            continue;
        }
        members: any = he.get("nodes");
        if not isinstance(members, `list) {
            continue;
        }
        seen: set = set[any]();
        rewired: list = [];
        for m in members {
            if isinstance(m, `str) {
                new_id: any = remap.get(m, m);
                `entry: any = new_id;
            } elif isinstance(m, `dict) {
                raw: any = m.get("id");
                new_id = remap.get(raw, raw) if isinstance(raw, `str) else raw;
                `entry = `dict(m, id=new_id) if new_id != raw else m;
            } else {
                (new_id, `entry) = (None, m);
            }
            if isinstance(new_id, `str) {
                if new_id in seen {
                    continue;
                }
                seen.add(new_id);
            }
            rewired.append(`entry);
        }
        he["nodes"] = rewired;
    }
}

impl deduplicate_entities(
    nodes: list[dict],
    edges: list[dict],
    *,
    communities: dict[str, int],
    dedup_llm_backend: str | None = None,
    `root: str | Path | None = None,
    hyperedges: "list[dict] | None" = None,
    protected_ids: "set[str] | None" = None,
    remap_out: "dict[str, str] | None" = None,
) -> tuple[list[dict], list[dict]] {
    root_resolved: Path | None;
    mentions: any;
    outranked: any;
    survivor: any;
    uf: any;
    exact_merges: any;
    prot_by_root: dict[str, str];
    nodes_by_id: dict[str, tuple[int, dict]];
    repos_seen: any = {n.get("repo") for n in nodes if n.get("repo")};
    if len(repos_seen) > 1 {
        raise ValueError(
            f"deduplicate_entities: nodes span multiple repos {sorted(repos_seen)!r}. Cross-project dedup is disabled — run dedup per-repo before merging.",
        );
    }

    if len(nodes) <= 1 {
        return (nodes, edges);
    }
    try {
        root_resolved = Path(`root).resolve() if `root else None;
    } except Exception {
        root_resolved = None;
    }
    (nodes, edges) = _disambiguate_defining_collisions(
        nodes, edges, hyperedges, root_resolved
    ) as any;
    (nodes, edges) = _path_qualify_dropped_collisions(
        nodes, edges, hyperedges, root_resolved
    ) as any;
    (nodes, edges) = _namespace_reference_stub_collisions(
        nodes, edges, hyperedges, root_resolved
    ) as any;
    mentions = _mentions(nodes, edges, root_resolved) | _slice_references(nodes, root_resolved);
    outranked = _outranked_by_ast(nodes, root_resolved, mentions);
    seen_ids: dict[str, dict] = {};
    dropped: dict[str, list[dict]] = defaultdict(list[any]);
    `node: any;
    for `node in nodes {
        nid: any = `node.get("id", "");
        if not nid {
            continue;
        }
        incumbent: any = seen_ids.get(nid);
        if incumbent is None {
            seen_ids[nid] = `node;
        } elif _collision_rank(`node, root_resolved, mentions, outranked)
            < _collision_rank(incumbent, root_resolved, mentions, outranked)
        {
            seen_ids[nid] = `node;
            dropped[nid].append(incumbent);
        } else {
            dropped[nid].append(`node);
        }
    }
    losers: any;
    for (nid, losers) in dropped.items() {
        survivor = seen_ids[nid];
        same_source: any = sorted(
            (l for l in losers if _same_source_entity(survivor, l)),
            key=lambda (l) -> any { _collision_rank(l, root_resolved, mentions, outranked) },
        );
        for loser in same_source {
            survivor = _merge_missing_attributes(survivor, loser);
        }
        seen_ids[nid] = survivor;
    }

    for (nid, losers) in dropped.items() {
        _report_id_collision(nid, seen_ids[nid], losers);
    }

    unique_nodes: any = `list(seen_ids.values());

    if len(unique_nodes) <= 1 {
        return (unique_nodes, edges);
    }
    norm_to_nodes: dict[str, list[dict]] = defaultdict(list[any]);
    for `node in unique_nodes {
        if _is_code(`node) {
            continue;
        }
        key: any = _norm(`node.get("label", `node.get("id", "")));
        if key {
            norm_to_nodes[key].append(`node);
        }
    }

    uf = _UF();
    exact_merges = 0;

    protected_set: set[str] = `set(protected_ids) if protected_ids is not None else set[any]();
    prot_by_root = {pid: pid for pid in protected_set};

    def _get_prot(nid: str) -> str | None {
        return prot_by_root.get(uf.find(nid));
    }

    def _union_with_prot(x: str, y: str) -> None {
        px: any = _get_prot(x);
        py: any = _get_prot(y);
        uf.union(x, y);
        new_root: any = uf.find(x);
        prot: any = px or py;
        if prot is not None {
            prot_by_root[new_root] = prot;
        }
    }

    def _crossfile_union(left: dict, right: dict, *, with_prot: bool) -> None {
        if _crossfile_fileanchored_blocked(left, right) {
            return;
        }
        left_id: any = left["id"];
        right_id: any = right["id"];
        if with_prot {
            px: any = _get_prot(left_id);
            py: any = _get_prot(right_id);
            if px is not None and py is not None and px != py {
                return;
            }
        }
        if uf.find(left_id) == uf.find(right_id) {
            return;
        }
        if with_prot {
            _union_with_prot(left_id, right_id);
        } else {
            uf.union(left_id, right_id);
        }
        exact_merges += 1;
    }

    def _crossfile_join(members: list[dict], *, with_prot: bool) -> None {
        for (index, left) in enumerate(members) {
            for right in members[index + 1:] {
                _crossfile_union(left, right, with_prot=with_prot);
            }
        }
    }

    for (key, group) in norm_to_nodes.items() {
        if len(group) <= 1 {
            continue;
        }
        by_file: dict[str, list[dict]] = defaultdict(list[any]);
        for `node in group {
            sf: any = `node.get("source_file") or "";
            by_file[sf].append(`node);
        }
        for (sf, file_group) in by_file.items() {
            if not sf {
                continue;
            }
            if len(file_group) > 1 {
                if protected_set {
                    prot_file: any = [n for n in file_group if n.get("id") in protected_set];
                    inc_file: any = [n for n in file_group if n.get("id") not in protected_set];
                    if prot_file and not inc_file {
                        continue;
                    }
                    if prot_file and inc_file {
                        winner: any = _pick_winner(prot_file);
                        for `node in inc_file {
                            px: any = _get_prot(winner["id"]);
                            py: any = _get_prot(`node["id"]);
                            if px is not None and py is not None and px != py {
                                continue;
                            }
                            if uf.find(winner["id"]) != uf.find(`node["id"]) {
                                _union_with_prot(winner["id"], `node["id"]);
                                exact_merges += 1;
                            }
                        }
                    } else {
                        winner = _pick_winner(file_group);
                        for `node in file_group {
                            if uf.find(winner["id"]) != uf.find(`node["id"]) {
                                _union_with_prot(winner["id"], `node["id"]);
                                exact_merges += 1;
                            }
                        }
                    }
                } else {
                    winner = _pick_winner(file_group);
                    for `node in file_group {
                        uf.union(winner["id"], `node["id"]);
                    }
                    exact_merges += len(file_group) - 1;
                }
            }
        }
        mergeable: any = sorted(
            (n
            for n in group
            if (
                n.get("file_type") == "concept"
                or n.get("file_type") in _FILE_ANCHORED_NONCODE and _reads_as_file_entity(n)
            )
                and (n.get("source_file") or "")
                and _entropy(n.get("label", "")) >= _ENTROPY_THRESHOLD),
            key=lambda (n) -> any { n["id"] },
        );
        if len(mergeable) > 1 {
            if protected_set {
                prot_members: any = [n for n in mergeable if n.get("id") in protected_set];
                inc_members: any = [n for n in mergeable if n.get("id") not in protected_set];
                if not inc_members {
                    continue;
                }
                if prot_members {
                    canonical_winner: any = _pick_winner(prot_members);
                    for inc in inc_members {
                        _crossfile_union(canonical_winner, inc, with_prot=True);
                    }
                    _crossfile_join(inc_members, with_prot=True);
                } else {
                    _crossfile_join(inc_members, with_prot=True);
                }
            } else {
                _crossfile_join(mergeable, with_prot=False);
            }
        }
    }
    candidates: list[dict] = [];
    seen_norms: set[str] = set[any]();
    for `node in unique_nodes {
        if _is_code(`node) {
            continue;
        }
        key = _norm(`node.get("label", `node.get("id", "")));
        if key and key not in seen_norms {
            seen_norms.add(key);
            if _entropy(`node.get("label", "")) >= _ENTROPY_THRESHOLD {
                candidates.append(`node);
            }
        }
    }

    fuzzy_merges: any = 0;
    if len(candidates) >= 2 {
        lsh: any = MinHashLSH(threshold=_LSH_THRESHOLD, num_perm=_NUM_PERM);
        minhashes: dict[str, MinHash] = {};
        candidates_by_id: dict[str, dict] = {};
        norm_cache: dict[str, str] = {};

        for `node in candidates {
            node_id: any = `node["id"];
            candidates_by_id[node_id] = `node;
            nl: any = _norm(`node.get("label", `node.get("id", "")));
            norm_cache[node_id] = nl;
            m: any = _make_minhash(nl);
            minhashes[node_id] = m;
            try {
                lsh.insert(node_id, m);
            } except ValueError {}
        }

        for `node in candidates {
            node_id = `node["id"];
            norm_label: any = norm_cache[node_id];
            neighbors: any = lsh.query(minhashes[node_id]);

            for neighbor_id in neighbors {
                if neighbor_id == node_id {
                    continue;
                }
                if uf.find(node_id) == uf.find(neighbor_id) {
                    continue;
                }

                if protected_set {
                    px = _get_prot(node_id);
                    py = _get_prot(neighbor_id);
                    if px is not None and py is not None and px != py {
                        continue;
                    }
                }

                neighbor: any = candidates_by_id.get(neighbor_id);
                if neighbor is None {
                    continue;
                }

                neighbor_norm: any = norm_cache.get(neighbor_id)
                    or _norm(neighbor.get("label", neighbor.get("id", "")));
                _xfile: any = operator.ne(
                    `node.get("source_file") or "", neighbor.get("source_file") or ""
                );
                if _xfile and max(len(norm_label), len(neighbor_norm)) >= 12 {
                    score: any = Jaro.normalized_similarity(norm_label, neighbor_norm) * 100;
                } else {
                    score = JaroWinkler.normalized_similarity(norm_label, neighbor_norm) * 100;
                }

                if _is_variant_pair(norm_label, neighbor_norm) {
                    continue;
                }
                if _short_label_blocked(norm_label, neighbor_norm, score) {
                    continue;
                }
                _lo: any;
                _hi: any;
                (_lo, _hi) = sorted((norm_label, neighbor_norm), key=builtins.len) as any;
                if _hi.startswith(_lo) and _hi != _lo {
                    continue;
                }
                if _numeric_tokens_differ(norm_label, neighbor_norm) {
                    continue;
                }
                if _content_token_swap(norm_label, neighbor_norm) {
                    continue;
                }
                if _crossfile_fileanchored_blocked(`node, neighbor) {
                    continue;
                }

                c1: any = communities.get(node_id);
                c2: any = communities.get(neighbor_id);
                if c1 is not None
                    and c2 is not None
                    and c1 == c2
                    and min(len(norm_label), len(neighbor_norm)) >= 12
                {
                    score += _COMMUNITY_BOOST;
                }

                if score >= _MERGE_THRESHOLD {
                    if norm_label == neighbor_norm {
                        sf_a: any = `node.get("source_file") or "";
                        sf_b: any = neighbor.get("source_file") or "";
                        if sf_a != sf_b {
                            continue;
                        }
                    }
                    if protected_set {
                        px = _get_prot(node_id);
                        py = _get_prot(neighbor_id);
                        if px is not None and py is not None and px != py {
                            continue;
                        }
                        if node_id in protected_set {
                            winner = `node;
                        } elif neighbor_id in protected_set {
                            winner = neighbor;
                        } else {
                            winner = _pick_winner([`node, neighbor]);
                        }
                        _union_with_prot(winner["id"], node_id);
                        _union_with_prot(winner["id"], neighbor_id);
                    } else {
                        winner = _pick_winner([`node, neighbor]);
                        uf.union(winner["id"], node_id);
                        uf.union(winner["id"], neighbor_id);
                    }
                    fuzzy_merges += 1;
                }
            }
        }
    }
    if dedup_llm_backend is not None {
        _llm_tiebreak(
            candidates,
            uf,
            communities,
            backend=dedup_llm_backend,
            protected_set=protected_set,
            get_prot=_get_prot,
            union_with_prot=_union_with_prot,
        );
    }
    components: any = uf.components();
    remap: dict[str, str] = {};
    nodes_by_id = {n["id"]: (i, n) for (i, n) in enumerate(unique_nodes)};
    enriched_by_id: dict[str, dict] = {};
    for (`root, members) in components.items() {
        if len(members) == 1 {
            continue;
        }
        group_nodes: any = [
            n
            for (_, n) in sorted(
                (nodes_by_id[m] for m in members if m in nodes_by_id),
                key=lambda (pair) -> any { pair[0] },
            )
        ];
        if protected_set {
            prot_in_group: any = [n for n in group_nodes if n.get("id") in protected_set];
            if prot_in_group {
                winner = _pick_winner(prot_in_group);
            } else {
                winner = _pick_winner(group_nodes) if group_nodes else {"id": `root};
            }
        } else {
            winner = _pick_winner(group_nodes) if group_nodes else {"id": `root};
        }
        winner_id: any = winner["id"];
        merged: any = winner;
        for `node in group_nodes {
            if `node["id"] != winner_id {
                merged = _merge_missing_attributes(merged, `node);
            }
        }
        if merged != winner {
            enriched_by_id[winner_id] = merged;
        }
        for member in members {
            if member != winner_id {
                remap[member] = winner_id;
            }
        }
    }
    if not remap {
        return (unique_nodes, edges);
    }

    if remap_out is not None {
        remap_out.update(remap);
    }
    total: any = len(remap);
    msg: any = f"[graphify] Deduplicated {total} node(s)";
    parts: list[str] = [];
    if exact_merges {
        parts.append(f"{exact_merges} exact");
    }
    if fuzzy_merges {
        parts.append(f"{fuzzy_merges} fuzzy");
    }
    if parts {
        msg += " (" + format(", ".join(parts), "") + ")";
    }
    print(msg + ".", flush=True);
    if hyperedges {
        _remap_hyperedge_members(hyperedges, remap);
    }

    deduped_nodes: any = [
        enriched_by_id.get(n["id"], n)
        for n in unique_nodes
        if n["id"] not in remap
    ];
    deduped_edges: any = [];
    for `edge in edges {
        e: any = `dict(`edge);
        src: any = e["source"] if "source" in e else e.get("from");
        tgt: any = e["target"] if "target" in e else e.get("to");
        if src is None or tgt is None {
            continue;
        }
        e["source"] = remap.get(src, src);
        e["target"] = remap.get(tgt, tgt);
        e.pop("from", None);
        e.pop("to", None);
        if e["source"] != e["target"] or src == tgt {
            deduped_edges.append(e);
        }
    }

    return (deduped_nodes, deduped_edges);
}

impl _content_richness(n: dict) -> int {
    score: any = 0;
    for (key, value) in n.items() {
        if key in _RICHNESS_IGNORED_KEYS {
            continue;
        }
        if value is None or value == "" or value == [] or value == {} {
            continue;
        }
        score += 1;
        if key == "attributes" and isinstance(value, `dict) {
            score += len(value);
        } elif key == "_merged_from" and isinstance(value, `list) {
            score += len(value);
        }
    }
    return score;
}

impl _pick_winner(nodes: list[dict]) -> dict {
    if not nodes {
        raise ValueError("Cannot pick winner from empty list");
    }

    def _score(n: dict) -> tuple[int, int, int, int, int] {
        has_suffix: any = `bool(_CHUNK_SUFFIX.search(n["id"]));
        has_source: any = `bool(n.get("source_file"));
        no_source: any = 0 if has_source else 1;
        no_location: any = 0 if has_source and n.get("source_location") else 1;
        return (
            1 if has_suffix else 0,
            no_source,
            no_location,
            -_content_richness(n),
            len(n["id"]),
        );
    }

    return min(nodes, key=_score);
}

impl _llm_tiebreak(
    candidates: list[dict],
    uf: _UF,
    communities: dict[str, int],
    *,
    backend: str,
    batch_size: int = 30,
    low: float = 75.0,
    high: float = 92.0,
    protected_set: set[str] | None = None,
    get_prot=None,
    union_with_prot=None,
) -> None {
    a: any;
    b: any;
    try {
        BACKENDS: any = importlib.import_module("graphify.llm").BACKENDS;
        _format_backend_env_keys: any = importlib.import_module("graphify.llm")._format_backend_env_keys;
        _get_backend_api_key: any = importlib.import_module("graphify.llm")._get_backend_api_key;
        if backend not in BACKENDS {
            print(
                f"[graphify] --dedup-llm: unknown backend {backend!r}, skipping LLM tiebreaker.",
                flush=True,
            );
            return;
        }
        if not _get_backend_api_key(backend) {
            env_keys: any = _format_backend_env_keys(backend);
            print(
                f"[graphify] --dedup-llm: {env_keys} not set, skipping LLM tiebreaker.", flush=True
            );
            return;
        }
    } except ImportError {
        return;
    }

    ambiguous: list[tuple[dict, dict, float]] = [];
    for (i, `node) in enumerate(candidates) {
        norm_i: any = _norm(`node.get("label", `node.get("id", "")));
        for j in range(i + 1, len(candidates)) {
            neighbor: any = candidates[j];
            if uf.find(`node["id"]) == uf.find(neighbor["id"]) {
                continue;
            }
            norm_j: any = _norm(neighbor.get("label", neighbor.get("id", "")));
            _xfile: any = operator.ne(
                `node.get("source_file") or "", neighbor.get("source_file") or ""
            );
            if _xfile and max(len(norm_i), len(norm_j)) >= 12 {
                score: any = Jaro.normalized_similarity(norm_i, norm_j) * 100;
            } else {
                score = JaroWinkler.normalized_similarity(norm_i, norm_j) * 100;
            }
            if _is_variant_pair(norm_i, norm_j) {
                continue;
            }
            if _short_label_blocked(norm_i, norm_j, score) {
                continue;
            }
            _lo: any;
            _hi: any;
            (_lo, _hi) = sorted((norm_i, norm_j), key=builtins.len) as any;
            if _hi.startswith(_lo) and _hi != _lo {
                continue;
            }
            if _numeric_tokens_differ(norm_i, norm_j) {
                continue;
            }
            if _content_token_swap(norm_i, norm_j) {
                continue;
            }
            if _crossfile_fileanchored_blocked(`node, neighbor) {
                continue;
            }
            c1: any = communities.get(`node["id"]);
            c2: any = communities.get(neighbor["id"]);
            if c1 is not None
                and c2 is not None
                and c1 == c2
                and min(len(norm_i), len(norm_j)) >= 12
            {
                score += _COMMUNITY_BOOST;
            }
            if low <= score < high {
                if protected_set and get_prot is not None {
                    px: any = get_prot(`node["id"]);
                    py: any = get_prot(neighbor["id"]);
                    if px is not None and py is not None and px != py {
                        continue;
                    }
                }
                ambiguous.append((`node, neighbor, score));
            }
        }
    }

    if not ambiguous {
        return;
    }

    try {
        _call_llm: any = importlib.import_module("graphify.llm")._call_llm;
    } except ImportError as exc {
        print(
            f"[graphify] --dedup-llm: cannot import _call_llm ({exc}); skipping LLM tiebreaker.",
            flush=True,
        );
        return;
    }

    for batch_start in range(0, len(ambiguous), batch_size) {
        batch: any = ambiguous[batch_start:batch_start + batch_size];
        pairs_text: any = "\n".join(
            format(i + 1, "")
                + ". \""
                + format(a["label"], "")
                + "\" vs \""
                + format(b["label"], "")
                + "\""
            for (i, (a, b, _)) in enumerate(batch),
        );
        prompt: any = f"For each pair below, answer only 'yes' or 'no': are they the same real-world concept?\n\n{pairs_text}\n\nReply with one line per pair: '1. yes', '2. no', etc.";
        try {
            response: any = _call_llm(prompt, backend=backend, max_tokens=200);
            lines: any = response.strip().splitlines();
            line: any;
            for line in lines {
                line = line.strip();
                if not line {
                    continue;
                }
                parts: any = line.split(".", 1);
                if len(parts) != 2 {
                    continue;
                }
                try {
                    idx: any = `int(parts[0].strip()) - 1;
                } except ValueError {
                    continue;
                }
                if 0 <= idx < len(batch) {
                    answer: any = parts[1].strip().lower();
                    if answer.startswith("yes") {
                        _: any;
                        (a, b, _) = batch[idx] as any;
                        if protected_set and get_prot is not None and union_with_prot is not None {
                            px = get_prot(a["id"]);
                            py = get_prot(b["id"]);
                            if px is not None and py is not None and px != py {
                                continue;
                            }
                            if a["id"] in protected_set {
                                winner: any = a;
                            } elif b["id"] in protected_set {
                                winner = b;
                            } else {
                                winner = _pick_winner([a, b]);
                            }
                            union_with_prot(winner["id"], a["id"]);
                            union_with_prot(winner["id"], b["id"]);
                        } else {
                            winner = _pick_winner([a, b]);
                            uf.union(winner["id"], a["id"]);
                            uf.union(winner["id"], b["id"]);
                        }
                    }
                }
            }
        } except Exception as exc {
            print(f"[graphify] --dedup-llm batch failed: {exc}", flush=True);
        }
    }
}
