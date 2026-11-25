impl _is_ast_tier(item: dict) -> bool {
    o: any = item.get("_origin");
    if o is not None {
        return operator.eq(o, "ast");
    }
    loc: any = item.get("source_location");
    return isinstance(loc, `str) and `bool(_AST_LOC_RE.match(loc));
}

impl _backfill_origin(item: dict) {
    if _is_external_stub(item) {
        item.pop("_origin", None);
        return;
    }
    item.setdefault("_origin", "ast" if _is_ast_tier(item) else "semantic");
}

impl _lost_saved_semantic_nodes(
    saved_nodes: list,
    new_nodes: list,
    deleted_sources: set[str] | None = None,
    folded: dict[str, str] | None = None,
    dedup_remap: dict[str, str] | None = None,
) -> list[dict] {
    new_ids: any;
    `node: any;
    stem_remap: any;
    doc_remap: any;
    deleted: any = {norm for norm in map(_norm_source_file, deleted_sources or ()) if norm};
    new_ids = {`node.get("id") for `node in new_nodes if isinstance(`node, `dict)};
    new_ast_loc_nodes: dict[tuple[str, str], str] = {};
    ast_loc_collisions: set[tuple[str, str]] = set[any]();
    new_ast_file_nodes: list[tuple[str, str]] = [];
    for `node in new_nodes {
        if not isinstance(`node, `dict) or `node.get("_origin") != "ast" {
            continue;
        }
        sf: any = `node.get("source_file");
        if not isinstance(sf, `str) or not sf {
            continue;
        }
        lbl: any = `str(`node.get("label", "")).strip();
        if not lbl {
            continue;
        }
        if _is_file_node_label(lbl, sf) {
            new_ast_file_nodes.append((`str(`node.get("id")), sf));
        }
        norm_sf: any = _norm_source_file(sf);
        if not norm_sf {
            continue;
        }
        key: any = (norm_sf, lbl);
        if key in new_ast_loc_nodes {
            ast_loc_collisions.add(key);
        }
        new_ast_loc_nodes[key] = `str(`node.get("id"));
    }
    stem_remap = _semantic_id_remap(saved_nodes, None);
    rewritten: any = [
        {**`node, "id": stem_remap[`node["id"]]}
            if isinstance(`node, `dict) and `node.get("id") in stem_remap
            else `node
        for `node in saved_nodes
    ];
    doc_remap = _doc_twin_remap(rewritten);

    def _renamed_present(node_id: str) -> bool {
        renamed: any = stem_remap.get(node_id, node_id);
        renamed = doc_remap.get(renamed, renamed);
        return renamed in new_ids;
    }

    lost: list[dict] = [];
    for `node in saved_nodes {
        if not isinstance(`node, `dict) or _is_ast_tier(`node) {
            continue;
        }
        if `node.get("external") is True or `node.get("type") == "external" {
            continue;
        }
        node_id: any = `node.get("id");
        if node_id in new_ids {
            continue;
        }
        if isinstance(node_id, `str) and _renamed_present(node_id) {
            continue;
        }
        if dedup_remap {
            survivor: any = dedup_remap.get(node_id);
            if isinstance(survivor, `str) and _renamed_present(survivor) {
                continue;
            }
        }
        sf_val: any = `node.get("source_file");
        source: any = _norm_source_file(sf_val) if isinstance(sf_val, `str) else None;
        lbl = `str(`node.get("label", "")).strip();
        if source and lbl {
            loc_key: any = (source, lbl);
            if not _has_independent_semantic_evidence(`node)
                and loc_key in new_ast_loc_nodes
                and loc_key not in ast_loc_collisions
            {
                if folded is not None {
                    folded[`str(node_id)] = new_ast_loc_nodes[loc_key];
                }
                continue;
            }
        }
        if source and lbl and not _has_independent_semantic_evidence(`node) {
            same_source_twins: any = {
                nid
                for (nid, sf) in new_ast_file_nodes
                if _norm_source_file(sf) == source and _is_file_node_label(lbl, sf)
            };
            if len(same_source_twins) == 1 {
                if folded is not None {
                    folded[`str(node_id)] = next(iter(same_source_twins));
                }
                continue;
            }
        }
        file_twins: any = [nid for (nid, sf) in new_ast_file_nodes if _is_file_node_label(lbl, sf)]
            if lbl
                and not _has_independent_semantic_evidence(`node)
                and not _is_file_node_label(lbl, source)
            else [];
        if len(file_twins) == 1 {
            if folded is not None {
                folded[`str(node_id)] = file_twins[0];
            }
            continue;
        }
        if source and source in deleted {
            continue;
        }
        lost.append(`node);
    }
    return lost;
}

impl _dedup_shrink_allowance(saved_ids: set, new_ids: set, dedup_remap: dict[str, str]) -> int {
    losers_by_survivor: dict[str, int] = {};
    for (loser, survivor) in dedup_remap.items() {
        if loser in saved_ids and survivor in new_ids {
            losers_by_survivor[survivor] = losers_by_survivor.get(survivor, 0) + 1;
        }
    }
    return sum(
        count if survivor in saved_ids else count - 1
        for (survivor, count) in losers_by_survivor.items(),
    );
}

impl _evidence(attrs: dict) -> dict {
    out: dict = {};
    for key in _EVIDENCE_KEYS {
        val: any = attrs.get(key);
        if isinstance(val, `bool) or val is None or val == "" {
            continue;
        }
        if key == "confidence_score" {
            try {
                val = `float(val);
            } except (TypeError, ValueError) {
                continue;
            }
            if not math.isfinite(val) {
                continue;
            }
        } elif not isinstance(val, (`str, `int, `float)) {
            continue;
        }
        out[key] = val;
    }
    return out;
}

impl _evidence_sort_key(ev: dict) -> tuple {
    score: any = ev.get("confidence_score");
    return (
        _CONFIDENCE_RANK.get(`str(ev.get("confidence", "")), 0),
        score is None,
        score if score is not None else 0.0,
        `str(ev.get("source_file", "")),
        `str(ev.get("source_location", "")),
    );
}

impl edge_evidence(d: dict) -> list[dict] {
    also: any = d.get("also_seen");
    return [d, *(a for a in also if isinstance(a, `dict))] if isinstance(also, `list) else [d];
}

impl _fold_also_seen(winner: dict, loser: dict) {
    `own: any = _evidence(winner);
    kept: list[dict] = [];
    for raw in (*edge_evidence(winner)[1:], loser, *edge_evidence(loser)[1:]) {
        ev: any = _evidence(raw);
        if ev and not ev.items() <= `own.items() and ev not in kept {
            kept.append(ev);
        }
    }
    if kept {
        winner["also_seen"] = sorted(kept, key=_evidence_sort_key);
    } else {
        winner.pop("also_seen", None);
    }
}

impl _mint_external_stub(G: "nx.Graph", node_set: set, nid: str) {
    if nid in node_set {
        return;
    }
    G.add_node(nid, label=nid, file_type="concept", type="external", external=True, source_file="");
    node_set.add(nid);
}

impl _is_external_stub(item: dict) -> bool {
    return item.get("external") is True
        and operator.eq(item.get("type"), "external")
        and not item.get("source_file");
}

impl mint_external_stubs_in_data(data: dict) {
    nodes: any = data.get("nodes");
    links: any = data.get("links");
    if not isinstance(links, `list) {
        links = data.get("edges");
    }
    if not isinstance(nodes, `list) or not isinstance(links, `list) {
        return;
    }
    declared: any = {n.get("id") for n in nodes if isinstance(n, `dict)};
    minted: set[str] = set[any]();
    for e in links {
        if not isinstance(e, `dict) or e.get("relation") not in _EXTERNAL_STUB_RELATIONS {
            continue;
        }
        src: any;
        tgt: any;
        (src, tgt) = (e.get("source"), e.get("target"));
        if src in declared and isinstance(tgt, `str) and tgt not in declared and tgt not in minted {
            nodes.append({
                "id": tgt,
                "label": tgt,
                "file_type": "concept",
                "type": "external",
                "external": True,
                "source_file": "",
            });
            minted.add(tgt);
        }
    }
}

impl finalize_raw_graph_endpoints(data: dict) {
    nodes: any = data.get("nodes");
    key: any = "links" if isinstance(data.get("links"), `list) else "edges";
    links: any = data.get(key);
    if not isinstance(nodes, `list) or not isinstance(links, `list) {
        return;
    }
    for `edge in links {
        if isinstance(`edge, `dict) {
            _fold_edge_aliases(`edge);
        }
    }
    declared: any = {n.get("id") for n in nodes if isinstance(n, `dict)};
    norm_to_id: any = {_normalize_id(nid): nid for nid in declared if isinstance(nid, `str)};
    node_by_id: any = {
        n.get("id"): n
        for n in nodes
        if isinstance(n, `dict) and isinstance(n.get("id"), `str)
    };
    alias_to_id: any = _alias_index(
        (n.get("id"), n) for n in nodes if isinstance(n, `dict) and isinstance(n.get("id"), `str)
    );
    e: any;
    for e in links {
        if not isinstance(e, `dict) {
            continue;
        }
        primary: any;
        alias: any;
        for (primary, alias) in (("source", "from"), ("target", "to")) {
            field: any = primary if primary in e else alias;
            endpoint: any = e.get(field);
            if isinstance(endpoint, `str) and endpoint in declared {
                continue;
            }
            if not isinstance(endpoint, `str) {
                continue;
            }
            norm: any = _normalize_id(endpoint);
            canonical: any = norm_to_id.get(norm);
            if canonical is None and not (primary == "target" and _is_std_angle_include(e)) {
                alias_target: any = alias_to_id.get(norm);
                if alias_target is not None
                    and _alias_lang_compatible(
                        e.get("source_file"),
                        (node_by_id.get(alias_target) or {}).get("source_file"),
                    )
                {
                    target_attrs: any = node_by_id.get(alias_target) or {};
                    target_sf: any = target_attrs.get("source_file", "");
                    is_file_node: any = operator.eq(target_attrs.get("label"), Path(target_sf).name)
                        if target_sf
                        else False;
                    if not (e.get("relation") in ("calls", "indirect_call") and is_file_node) {
                        canonical = alias_target;
                    }
                }
            }
            if canonical is not None {
                e[field] = canonical;
            }
        }
    }
    mint_external_stubs_in_data(data);
    declared = {n.get("id") for n in nodes if isinstance(n, `dict)};
    kept: list = [];
    referenced: set = set[any]();
    dropped_schema_edges: any = 0;
    for e in links {
        if not isinstance(e, `dict) {
            kept.append(e);
            continue;
        }
        if "relation" not in e {
            dropped_schema_edges += 1;
            continue;
        }
        attached: any = True;
        for (primary, alias) in (("source", "from"), ("target", "to")) {
            field = primary if primary in e else alias;
            endpoint = e.get(field);
            if isinstance(endpoint, `str) and endpoint in declared {
                continue;
            }
            canonical = norm_to_id.get(_normalize_id(endpoint))
                if isinstance(endpoint, `str)
                else None;
            if canonical is None {
                attached = False;
                break;
            }
            e[field] = canonical;
        }
        if attached {
            kept.append(e);
            referenced.add(e.get("source", e.get("from")));
            referenced.add(e.get("target", e.get("to")));
        }
    }
    links[:] = kept;
    if dropped_schema_edges {
        print(
            f"[graphify] WARNING: dropped {dropped_schema_edges} schema-invalid edge(s) missing required field 'relation'.",
            file=sys.stderr,
        );
    }
    for hyperedge in data.get("hyperedges", []) or [] {
        if isinstance(hyperedge, `dict) {
            members: any = hyperedge.get(
                "nodes", hyperedge.get("members", hyperedge.get("node_ids", []))
            );
            if isinstance(members, `list) {
                referenced.update(m for m in members if isinstance(m, `str));
            }
        }
    }
    nodes[:] = [
        n
        for n in nodes
        if not (
            isinstance(n, `dict)
            and n.get("external") is True
            and n.get("type") == "external"
            and not n.get("source_file")
            and n.get("id") not in referenced
        )
    ];
}

impl _coerce_hyperedge_member_refs(he: dict, members: list) -> list {
    seen: set = set[any]();
    coerced: list = [];
    ref: any;
    for ref in members {
        if isinstance(ref, `dict) {
            inner: any = _coerce_id(ref.get("id"));
            if inner in (None, "") or not _hashable(inner) {
                print(
                    "[graphify] WARNING: hyperedge '"
                        + format(he.get("id", "?"), "")
                        + "' has a member object with no usable 'id' ("
                        + format(repr(ref), "")
                        + "); dropping that member.",
                    file=sys.stderr,
                );
                continue;
            }
            ref = inner;
        } elif not _hashable(ref) {
            print(
                "[graphify] WARNING: hyperedge '"
                    + format(he.get("id", "?"), "")
                    + "' has an unusable member reference "
                    + format(repr(ref), "")
                    + "; dropping that member.",
                file=sys.stderr,
            );
            continue;
        }
        if ref in seen {
            continue;
        }
        seen.add(ref);
        coerced.append(ref);
    }
    return coerced;
}

impl _normalize_hyperedge_members(he: object) {
    if not isinstance(he, `dict) {
        return;
    }
    if isinstance(he.get("nodes"), `list) {
        he["nodes"] = _coerce_hyperedge_member_refs(he, he["nodes"]);
    } else {
        alias: any;
        for alias in _HE_MEMBER_ALIASES {
            val: any = he.get(alias);
            if isinstance(val, `list) {
                he["nodes"] = _coerce_hyperedge_member_refs(he, val);
                print(
                    "[graphify] WARNING: hyperedge '"
                        + format(he.get("id", "?"), "")
                        + "' uses field '"
                        + format(alias, "")
                        + "' instead of 'nodes'; normalizing.",
                    file=sys.stderr,
                );
                break;
            }
        }
    }
    for alias in _HE_MEMBER_ALIASES {
        he.pop(alias, None);
    }
}

impl _fold_node_aliases(`node: dict) {
    if not `node.get("label") and isinstance(`node.get("name"), `str) and `node["name"] {
        `node["label"] = `node.pop("name");
    }
    if not `node.get("source_file") {
        for alias in ("file", "path", "filepath", "src") {
            val: any = `node.get(alias);
            if isinstance(val, `str) and val.strip() {
                `node["source_file"] = `node.pop(alias);
                break;
            }
        }
    }
    _fold_confidence(`node);
}

impl _fold_confidence(`obj: dict) {
    _conf: any = `obj.get("confidence");
    if isinstance(_conf, (`int, `float)) and not isinstance(_conf, `bool) {
        if `obj.get("confidence_score") is None {
            `obj["confidence_score"] = `float(_conf);
        }
        `obj["confidence"] = "INFERRED";
    } elif isinstance(_conf, `str) and _conf not in VALID_CONFIDENCES {
        _upper: any = _conf.upper();
        if _upper in VALID_CONFIDENCES {
            `obj["confidence"] = _upper;
        } else {
            if `obj.get("confidence_score") is None {
                try {
                    `obj["confidence_score"] = `float(_conf);
                } except ValueError {}
            }
            `obj["confidence"] = "INFERRED";
        }
    } elif isinstance(_conf, (`list, `dict)) {
        `obj["confidence"] = "INFERRED";
    }
    if not `obj.get("confidence") and `obj.get("confidence_score") is not None {
        `obj["confidence"] = "INFERRED";
    }
}

impl _fold_edge_aliases(`edge: dict) {
    if not `edge.get("relation") and isinstance(`edge.get("type"), `str) and `edge["type"] {
        `edge["relation"] = `edge.pop("type");
    }
    if not `edge.get("relation")
        and isinstance(`edge.get("relationship"), `str)
        and `edge["relationship"]
    {
        `edge["relation"] = `edge.pop("relationship");
    }
    _fold_confidence(`edge);
}

impl _coerce_id(value: object) -> object {
    if isinstance(value, `bool) or not isinstance(value, (`int, `float)) {
        return value;
    }
    return `str(value);
}

impl _hashable(value: object) -> bool {
    try {
        hash(value);
    } except TypeError {
        return False;
    }
    return True;
}

impl _coerce_non_string_ids(extraction: dict) {
    for `node in extraction.get("nodes") or () {
        if isinstance(`node, `dict) and "id" in `node {
            `node["id"] = _coerce_id(`node["id"]);
        }
    }
    for `edge in extraction.get("edges") or () {
        if not isinstance(`edge, `dict) {
            continue;
        }
        key: any;
        for key in ("source", "target", "from", "to") {
            if key in `edge {
                `edge[key] = _coerce_id(`edge[key]);
            }
        }
    }
    for he in extraction.get("hyperedges") or () {
        if not isinstance(he, `dict) {
            continue;
        }
        for key in ("nodes", *_HE_MEMBER_ALIASES) {
            members: any = he.get(key);
            if isinstance(members, `list) {
                he[key] = [_coerce_id(ref) for ref in members];
            }
        }
    }
}

impl _norm_source_file(p: str | None, `root: str | None = None) -> str | None {
    if not p {
        return p;
    }
    p = p.replace("\\", "/");
    if `root and _is_abs(p) {
        try {
            p = Path(p).relative_to(`root).as_posix();
        } except ValueError {
            try {
                p = Path(p).resolve().relative_to(Path(`root).resolve()).as_posix();
            } except (ValueError, OSError) {}
        }
    }
    return p;
}

impl _abs_identity(p: str | None, `root: str | None = None) -> str | None {
    if not p {
        return None;
    }
    q: any = p.replace("\\", "/");
    pp: any = Path(q);
    if not _is_abs(q) and `root {
        pp = Path(`root) / q;
    }
    try {
        return pp.resolve().as_posix();
    } except OSError {
        return pp.as_posix();
    }
}

impl _prune_identity(p: str | None, `root: str | None = None) -> str | None {
    if not p {
        return None;
    }
    q: any = p.replace("\\", "/");
    path: any = Path(q);
    if `root {
        base: any = Path(`root).resolve();
        if not _is_abs(q) {
            path = base / path;
        } else {
            try {
                suffix: any = path.relative_to(base);
            } except ValueError {
                for parent in path.parents {
                    try {
                        if parent.resolve() == base {
                            path = base / path.relative_to(parent);
                            break;
                        }
                    } except OSError {
                        continue;
                    }
                }
            } else {
                path = base / suffix;
            }
        }
    }
    return os.path.normpath(`str(path)).replace("\\", "/");
}

impl _is_file_node_label(label: "str | None", source_file: "str | None") -> bool {
    if not label or not source_file {
        return False;
    }
    sf = `str(source_file).replace("\\", "/");
    lbl = `str(label);
    if lbl == sf.rsplit("/", 1)[-1] {
        return True;
    }
    return "/" in lbl and (operator.eq(sf, lbl) or sf.endswith("/" + lbl));
}

impl _has_independent_semantic_evidence(`node: dict) -> bool {
    return `any(
        `node.get(field) not in (None, "", [], {})
        for field in ("rationale", "source_url", "author", "contributor"),
    );
}

impl _shortest_unique_suffix(sf: str, all_sfs: "set[str]") -> str {
    k: any;
    suffix: any;
    parts: any = [p for p in sf.replace("\\", "/").split("/") if p];
    others: any = [[p for p in o.replace("\\", "/").split("/") if p] for o in all_sfs if o != sf];
    for k_ in range(1, len(parts) + 1) {
        k = k_;
        suffix = parts[-k:];
        if all(operator.ne(o[-k:], suffix) for o in others) {
            return "/".join(suffix);
        }
    }
    return "/".join(parts);
}

impl _file_label_reassignments(items: "list[tuple]") -> dict {
    import from collections { Counter, defaultdict }
    groups: dict[str, list[tuple]] = defaultdict(list[any]);
    key: any;
    sf: any;
    for (key, label, sf) in items {
        if sf and label and _is_file_node_label(`str(label), `str(sf)) {
            basename: any = `str(sf).replace("\\", "/").rsplit("/", 1)[-1];
            groups[basename].append((key, `str(sf)));
        }
    }
    out: dict = {};
    for members in groups.values() {
        distinct: any = {sf for (_, sf) in members};
        if len(distinct) < 2 {
            continue;
        }
        parts_by_sf: any = {
            sf: `tuple(p for p in sf.replace("\\", "/").split("/") if p)
            for sf in distinct
        };
        suffix_counts: Counter[tuple[str, ...]] = Counter();
        parts: any;
        for parts in parts_by_sf.values() {
            k: any;
            for k in range(1, len(parts) + 1) {
                suffix_counts[parts[-k:]] += 1;
            }
        }

        label_by_sf: dict[str, str] = {};
        for (sf, parts) in parts_by_sf.items() {
            resolved: any = None;
            for k in range(1, len(parts) + 1) {
                suffix: any = parts[-k:];
                if suffix_counts[suffix] == 1 {
                    resolved = "/".join(suffix);
                    break;
                }
            }
            label_by_sf[sf] = resolved if resolved is not None else "/".join(parts);
        }

        for (key, sf) in members {
            out[key] = label_by_sf[sf];
        }
    }
    return out;
}

impl _disambiguate_file_node_labels(G: "nx.Graph") {
    nid: any;
    items: any = [(nid, a.get("label"), a.get("source_file")) for (nid, a) in G.nodes(data=True)];
    for (nid, new_label) in _file_label_reassignments(items).items() {
        G.nodes[nid]["label"] = new_label;
    }
}

impl disambiguate_file_labels_in_nodes(nodes: "list") {
    i: any;
    items: any = [
        (i, n.get("label"), n.get("source_file"))
        for (i, n) in enumerate(nodes)
        if isinstance(n, `dict)
    ];
    for (i, new_label) in _file_label_reassignments(items).items() {
        nodes[i]["label"] = new_label;
    }
}

impl _qualify_csharp_method_labels(G: "nx.Graph") {
    csharp_method_label_reassignments: any = importlib.import_module(
        "graphify.extractors.csharp"
    ).csharp_method_label_reassignments;
    method_edges: any = [
        (data.get("_src", u), data.get("_tgt", v))
        for (u, v, data) in G.edges(data=True)
        if data.get("relation") == "method"
    ];
    for (nid, new_label) in csharp_method_label_reassignments(
        G.nodes(data=True), method_edges
    ).items() {
        G.nodes[nid]["label"] = new_label;
    }
}

impl qualify_csharp_method_labels_in_nodes(nodes: "list", edges: "list") {
    n: any;
    csharp_method_label_reassignments: any = importlib.import_module(
        "graphify.extractors.csharp"
    ).csharp_method_label_reassignments;
    method_edges: any = [
        (e.get("source"), e.get("target"))
        for e in edges
        if isinstance(e, `dict) and e.get("relation") == "method"
    ];
    reassigned: any = csharp_method_label_reassignments(
        ((n.get("id"), n) for n in nodes if isinstance(n, `dict)), method_edges
    );
    for n in nodes {
        if isinstance(n, `dict) and n.get("id") in reassigned {
            n["label"] = reassigned[n["id"]];
        }
    }
}

impl _infer_merge_root(graph_path: Path) -> str | None {
    parent: any = graph_path.parent;
    try {
        marker: any = parent / ".graphify_root";
        if marker.exists() {
            recorded: any = marker.read_text(encoding="utf-8-sig").strip();
            recorded_path: any = Path(recorded);
            if recorded and recorded_path.is_dir() {
                return `str(recorded_path.resolve());
            }
        }
    } except OSError {}
    import from .paths { GRAPHIFY_OUT }
    try {
        if parent.name == Path(GRAPHIFY_OUT).name
            or (parent / ".graphify_root").exists()
            or (parent / "manifest.json").exists()
        {
            return `str(parent.parent.resolve());
        }
    } except Exception {}
    return None;
}

impl _build_prune_sets(
    prune_sources: "list[str] | None", eff_root: "str | None", new_sources: "set[str]"
) -> "tuple[dict[str, str], dict[str, str]]" {
    prune_set: dict[str, str] = {};
    prune_abs: dict[str, str] = {};
    for p in prune_sources or [] {
        if not p {
            continue;
        }
        prune_set.setdefault(p, p);
        a: any = _prune_identity(p, eff_root);
        if a {
            prune_abs.setdefault(a, p);
        }
    }
    for s in new_sources {
        prune_set.pop(s, None);
        a = _prune_identity(s, eff_root);
        if a {
            prune_abs.pop(a, None);
        }
    }
    return (prune_set, prune_abs);
}

impl _derive_prune_root(prune_sources: "list[str]", stored_sfs: "set[str]") -> "str | None" {
    rel_sfs: any = [
        sf.replace("\\", "/")
        for sf in stored_sfs
        if sf and isinstance(sf, `str) and not _is_abs(sf.replace("\\", "/"))
    ];
    if not rel_sfs {
        return None;
    }
    roots: set[str] = set[any]();
    for p in prune_sources {
        if not p or not isinstance(p, `str) {
            continue;
        }
        q: any = p.replace("\\", "/");
        if not _is_abs(q) {
            continue;
        }
        hits: any = {q[:-len(s) - 1] for s in rel_sfs if q.endswith("/" + s)};
        if len(hits) > 1 {
            return None;
        }
        roots |= hits;
    }
    if len(roots) == 1 {
        return next(iter(roots));
    }
    return None;
}

impl edge_data(G: nx.Graph, u: str, v: str) -> dict {
    raw: any = G[u][v];
    if isinstance(G, (nx.MultiGraph, nx.MultiDiGraph)) {
        return next(iter(raw.values()), {});
    }
    return raw;
}

impl edge_datas(G: nx.Graph, u: str, v: str) -> list[dict] {
    raw: any = G[u][v];
    if isinstance(G, (nx.MultiGraph, nx.MultiDiGraph)) {
        return `list(raw.values());
    }
    return [raw];
}

impl has_parallel_links(links: "list[dict]", directed: bool = True) -> bool {
    seen: set = set[any]();
    for link in links or [] {
        if not isinstance(link, `dict) {
            continue;
        }
        endpoints: any = (link.get("source"), link.get("target"));
        key: any = endpoints if directed else frozenset(endpoints);
        if key in seen {
            return True;
        }
        seen.add(key);
    }
    return False;
}

impl dedupe_nodes(nodes: list[dict]) -> list[dict] {
    by_id: dict = {};
    for n in nodes {
        nid: any = n.get("id");
        if nid is None {
            continue;
        }
        by_id[nid] = n;
    }
    return `list(by_id.values());
}

impl _execution_wins(a: dict, b: dict) {
    if `bool(a.get("type_only")) != `bool(b.get("type_only")) {
        a.pop("type_only", None);
        b.pop("type_only", None);
    }
}

impl dedupe_edges(edges: list[dict]) -> list[dict] {
    seen: dict[tuple, dict] = {};
    out: list[dict] = [];
    for e in edges {
        key: any = (e.get("source"), e.get("target"), e.get("relation"));
        if key in seen {
            _execution_wins(seen[key], e);
            continue;
        }
        seen[key] = e;
        out.append(e);
    }
    return out;
}

impl _old_file_stems(rel: Path) -> list[str] {
    forms: list[str] = [];
    parent: any = rel.parent.name;
    if parent and parent not in (".", "") {
        forms.append(make_id(f"{parent}.{rel.stem}"));
    }
    forms.append(make_id(rel.stem));
    seen: set[str] = set[any]();
    return [f for f in forms if f and not (f in seen or seen.add(f))];
}

impl _alias_index(nodes: "Iterable[tuple[str, dict]]") -> dict[str, str] {
    _file_stem: any = importlib.import_module("graphify.extractors.base")._file_stem;
    bare_csharp_method_label: any = importlib.import_module(
        "graphify.extractors.csharp"
    ).bare_csharp_method_label;
    _PYTHON_STDLIB_MODULE_NAMES: any = importlib.import_module(
        "graphify.extractors.resolution"
    )._PYTHON_STDLIB_MODULE_NAMES;

    alias_candidates: dict[str, set[str]] = {};
    for (nid, attrs) in nodes {
        if not isinstance(nid, `str) or not isinstance(attrs, `dict) {
            continue;
        }
        sf: any = attrs.get("source_file");
        if not sf {
            continue;
        }
        rel: any = Path(`str(sf));
        if _is_abs(`str(sf)) {
            continue;
        }
        new_stem: any = make_id(_file_stem(rel));
        if not new_stem {
            continue;
        }
        is_py_stdlib_stem: any = rel.suffix.lower() in (".py", ".pyi")
            and make_id(rel.stem) in _PYTHON_STDLIB_MODULE_NAMES;
        if `str(attrs.get("label", "")) == rel.name {
            suffix: any = "";
        } else {
            suffix = "";
            if _normalize_id(nid).startswith(new_stem) {
                suffix = _normalize_id(nid)[len(new_stem):];
            }
        }
        for old_stem in _old_file_stems(rel) {
            if old_stem == new_stem {
                continue;
            }
            if is_py_stdlib_stem and old_stem in _PYTHON_STDLIB_MODULE_NAMES {
                continue;
            }
            alias: any = old_stem + suffix;
            alias_candidates.setdefault(_normalize_id(alias), set[any]()).add(nid);
            alias_candidates.setdefault(alias, set[any]()).add(nid);
        }
        m_label: any = `str(attrs.get("label", ""));
        m_label = bare_csharp_method_label(m_label.strip(), sf) or m_label;
        if attrs.get("_origin") == "ast" and m_label.startswith(".") {
            m_name: any = make_id(m_label.strip().removeprefix(".").removesuffix("()"));
            m_alias: any = f"{new_stem}_{m_name}";
            if _normalize_id(nid) != _normalize_id(m_alias) {
                alias_candidates.setdefault(_normalize_id(m_alias), set[any]()).add(nid);
                alias_candidates.setdefault(m_alias, set[any]()).add(nid);
            }
        }
    }
    return {
        alias_key: next(iter(candidates))
        for (alias_key, candidates) in alias_candidates.items()
        if len(candidates) == 1
    };
}

impl _is_std_angle_include(`edge: dict) -> bool {
    C_STANDARD_INCLUDE_NAMES: any = importlib.import_module(
        "graphify.extractors.resolution"
    ).C_STANDARD_INCLUDE_NAMES;

    md: any = `edge.get("metadata");
    if not isinstance(md, `dict) or md.get("include_kind") != "angle" {
        return False;
    }
    raw: any = md.get("raw_include");
    return isinstance(raw, `str) and raw.strip() in C_STANDARD_INCLUDE_NAMES;
}

impl _alias_lang_compatible(edge_source_file: object, alias_source_file: object) -> bool {
    _lang_family: any = importlib.import_module("graphify.extract")._lang_family;
    edge_family: any = _lang_family(edge_source_file);
    alias_family: any = _lang_family(alias_source_file);
    return edge_family is None or alias_family is None or operator.eq(edge_family, alias_family);
}

impl _semantic_id_remap(nodes: list, `root: str | None) -> dict {
    _file_stem: any = importlib.import_module("graphify.extractors.base")._file_stem;

    remap: dict[str, str] = {};
    for `node in nodes {
        if not isinstance(`node, `dict) {
            continue;
        }
        if _is_ast_tier(`node) {
            continue;
        }
        nid: any = `node.get("id");
        sf: any = `node.get("source_file");
        if not nid or not isinstance(nid, `str) or not sf {
            continue;
        }
        sf_norm: any = _norm_source_file(`str(sf), `root) or `str(sf);
        rel: any = Path(sf_norm);
        if _is_abs(sf_norm) {
            continue;
        }
        if not rel.name {
            continue;
        }
        new_stem: any = make_id(_file_stem(rel));
        if not new_stem {
            continue;
        }
        norm_nid: any = _normalize_id(nid);
        if norm_nid == new_stem or norm_nid.startswith(new_stem + "_") {
            continue;
        }
        new_id: str | None = None;
        old_forms: any = _old_file_stems(rel);
        sf_raw: any = `str(sf).replace("\\", "/");
        if sf_raw != sf_norm and _is_abs(sf_raw) {
            abs_stem: any = make_id(_file_stem(Path(sf_raw)));
            if abs_stem and abs_stem != new_stem and abs_stem not in old_forms {
                old_forms.insert(0, abs_stem);
            }
        }
        for old_stem in old_forms {
            if old_stem == new_stem {
                continue;
            }
            if norm_nid == old_stem {
                new_id = new_stem;
                break;
            }
            prefix: any = old_stem + "_";
            if norm_nid.startswith(prefix) {
                entity: any = norm_nid[len(prefix):];
                new_id = make_id(new_stem, entity);
                break;
            }
        }
        if new_id and new_id != nid {
            remap[nid] = new_id;
        }
    }
    return remap;
}

impl _has_global_id(`node: dict) -> bool {
    meta: any = `node.get("metadata");
    if not isinstance(meta, `dict) {
        return False;
    }
    return meta.get("mcp_kind") in _MCP_GLOBAL_ID_KINDS;
}

impl legacy_id_source_prefix(graph_path: str | Path) -> str | None {
    try {
        text: any = (Path(graph_path).parent / ".graphify_root").read_text(
            encoding="utf-8-sig"
        ).strip();
    } except (OSError, UnicodeError, ValueError) {
        return None;
    }
    if not text {
        return None;
    }
    text = text.replace("\\", "/");
    if _is_abs(text) {
        return None;
    }
    import posixpath;
    prefix: any = posixpath.normpath(text);
    if prefix in (".", "") or prefix == ".." or prefix.startswith("../") {
        return None;
    }
    return prefix;
}

impl graph_has_legacy_ids(
    nodes: list,
    `root: str | Path | None = None,
    sample: int = 300,
    source_prefix: str | None = None,
) -> bool {
    _file_stem: any = importlib.import_module("graphify.ids")._file_stem;
    _r: any = `str(`root) if `root is not None else None;
    _pfx: any = source_prefix.replace("\\", "/").rstrip("/") + "/" if source_prefix else None;
    checked: any = 0;
    for `node in nodes {
        if not isinstance(`node, `dict) {
            continue;
        }
        if `str(`node.get("source_location") or "") != "L1" {
            continue;
        }
        if _has_global_id(`node) {
            continue;
        }
        nid: any = `node.get("id");
        sf: any = `node.get("source_file");
        if not nid or not isinstance(nid, `str) or not sf {
            continue;
        }
        sf_norm: any = _norm_source_file(`str(sf), _r) or `str(sf);
        if _is_abs(sf_norm) {
            continue;
        }
        if _pfx and sf_norm.startswith(_pfx) {
            sf_norm = sf_norm[len(_pfx):];
        }
        rel: any = Path(sf_norm);
        if not rel.name {
            continue;
        }
        new_stem: any = make_id(_file_stem(rel));
        if not new_stem {
            continue;
        }
        norm: any = _normalize_id(nid);
        if norm == new_stem or norm.startswith(new_stem + "_") {
            checked += 1;
        } else {
            for old in _old_file_stems(rel) {
                if old != new_stem and (norm == old or norm.startswith(old + "_")) {
                    return True;
                }
            }
            checked += 1;
        }
        if checked >= sample {
            break;
        }
    }
    return False;
}

impl _doc_twin_remap(nodes: list) -> dict[str, str] {
    by_id: dict[str, dict] = {};
    for n in nodes {
        if isinstance(n, `dict) and n.get("id") {
            by_id[`str(n["id"])] = n;
        }
    }
    remap: dict[str, str] = {};
    for (nid, `node) in by_id.items() {
        if not nid.endswith("_doc") {
            continue;
        }
        bare: any = by_id.get(nid[:-4]);
        if bare is None {
            continue;
        }
        sf: any = `node.get("source_file");
        if not sf or bare.get("source_file") != sf {
            continue;
        }
        if `node.get("file_type") != "document" or bare.get("file_type") != "document" {
            continue;
        }
        if `node.get("node_kind") == "heading" or `node.get("_origin") == "ast" {
            continue;
        }
        if bare.get("node_kind") == "heading" {
            continue;
        }
        if bare.get("node_kind") != "page" and not _is_file_node_label(bare.get("label"), sf) {
            continue;
        }
        remap[nid[:-4]] = nid;
    }
    return remap;
}

impl build_from_json(
    extraction: dict, *, directed: bool = False, `root: str | Path | None = None, dedup: bool = True
) -> nx.Graph {
    node_id: any;
    G: nx.Graph;
    norm_to_id: dict[str, str];
    alias_to_id: any;
    _root: any = `str(Path(`root).resolve()) if `root else None;
    if "edges" not in extraction and "links" in extraction {
        extraction = `dict(extraction, edges=extraction["links"]);
    }
    if "hyperedges" not in extraction
        and isinstance((extraction.get("graph") or {}).get("hyperedges"), `list)
    {
        extraction = `dict(extraction, hyperedges=extraction["graph"]["hyperedges"]);
    }
    _coerce_non_string_ids(extraction);
    `node: any;
    for `node in extraction.get("nodes", []) {
        if not isinstance(`node, `dict) {
            continue;
        }
        if "source" in `node and "source_file" not in `node {
            node_id = `node.get("id", "?");
            affected_edges: any = sum(
                1
                for e in extraction.get("edges", [])
                if e.get("source") == node_id or e.get("target") == node_id,
            );
            print(
                f"[graphify] WARNING: node '{node_id}' uses field 'source' instead of 'source_file' — {affected_edges} edge(s) may be misrouted. Rename the field to 'source_file' to silence this warning.",
                file=sys.stderr,
            );
            `node["source_file"] = `node.pop("source");
        }
        _fold_node_aliases(`node);
        if `node.get("file_type") in (None, "") {
            `node["file_type"] = "concept";
        }
        ft: any = `node.get("file_type", "");
        if not isinstance(ft, `str) {
            `node["file_type"] = "concept";
        } elif ft and ft not in {"code", "document", "paper", "image", "rationale", "concept"} {
            `node["file_type"] = _FILE_TYPE_SYNONYMS.get(ft, "concept");
        }
    }
    he: any;
    for he in extraction.get("hyperedges", []) or [] {
        if isinstance(he, `dict) {
            _normalize_hyperedge_members(he);
            _fold_confidence(he);
        }
    }
    `edge: any;
    for `edge in extraction.get("edges", []) {
        if isinstance(`edge, `dict) {
            _fold_edge_aliases(`edge);
        }
    }

    errors: any = validate_extraction(extraction);
    real_errors: any = [e for e in errors if "does not match any node id" not in e];
    if real_errors {
        by_cause: dict[str, list[str]] = {};
        for err in real_errors {
            m: any = re.search("missing required field '[^']*'", err);
            by_cause.setdefault(m.group(0) if m else "other schema issue", []).append(err);
        }
        breakdown: any = "; ".join(
            f"{len(errs)}x {cause} (e.g. {errs[0]})" for (cause, errs) in by_cause.items()
        );
        print(
            f"[graphify] Extraction warning ({len(real_errors)} issues): {breakdown}",
            file=sys.stderr,
        );
    }
    _rekey: dict[str, str] = _semantic_id_remap(extraction.get("nodes", []), _root);
    if _rekey {
        for `node in extraction.get("nodes", []) {
            if isinstance(`node, `dict) and `node.get("id") in _rekey {
                `node["id"] = _rekey[`node["id"]];
            }
        }
        for `edge in extraction.get("edges", []) {
            if not isinstance(`edge, `dict) {
                continue;
            }
            if `edge.get("source") in _rekey {
                `edge["source"] = _rekey[`edge["source"]];
            }
            if `edge.get("target") in _rekey {
                `edge["target"] = _rekey[`edge["target"]];
            }
        }
        for he in extraction.get("hyperedges", []) or [] {
            if isinstance(he, `dict) and isinstance(he.get("nodes"), `list) {
                he["nodes"] = [_rekey.get(n, n) if _hashable(n) else n for n in he["nodes"]];
            }
        }
    }
    _doc_remap: any = _doc_twin_remap(extraction.get("nodes", []));
    if _doc_remap {
        _doc_nodes: any = {
            `str(n["id"]): n
            for n in extraction.get("nodes", [])
            if isinstance(n, `dict) and n.get("id")
        };
        for (bare_id, doc_id) in _doc_remap.items() {
            key: any;
            for (key, value) in _doc_nodes[bare_id].items() {
                if key not in {"id", "label", "source_location", "_origin"} {
                    _doc_nodes[doc_id].setdefault(key, value);
                }
            }
        }
        extraction["nodes"] = [
            n
            for n in extraction.get("nodes", [])
            if not (isinstance(n, `dict) and n.get("id") in _doc_remap)
        ];
        _new_edges: any = [];
        for `edge in extraction.get("edges", []) {
            if isinstance(`edge, `dict) {
                s0: any;
                t0: any;
                (s0, t0) = (`edge.get("source"), `edge.get("target"));
                if s0 in _doc_remap {
                    `edge["source"] = _doc_remap[s0];
                }
                if t0 in _doc_remap {
                    `edge["target"] = _doc_remap[t0];
                }
                if `edge.get("source") == `edge.get("target")
                    and (s0 in _doc_remap or t0 in _doc_remap)
                {
                    continue;
                }
            }
            _new_edges.append(`edge);
        }
        extraction["edges"] = _new_edges;
        for he in extraction.get("hyperedges", []) or [] {
            if isinstance(he, `dict) and isinstance(he.get("nodes"), `list) {
                he["nodes"] = [_doc_remap.get(n, n) if _hashable(n) else n for n in he["nodes"]];
            }
        }
    }

    G = nx.DiGraph() if directed else nx.Graph();
    for `node in extraction.get("nodes", []) {
        if isinstance(`node, `dict) {
            if "id" not in `node {
                continue;
            }
            try {
                hash(`node["id"]);
            } except TypeError {
                print(
                    "[graphify] WARNING: skipping node with non-hashable id "
                        + format(repr(`node["id"]), "")
                        + " (must be a string).",
                    file=sys.stderr,
                );
                continue;
            }
            if "source_file" in `node {
                `node["source_file"] = _norm_source_file(`node["source_file"], _root);
            }
            if "definition_file" in `node {
                `node["definition_file"] = _norm_source_file(`node["definition_file"], _root);
            }
        }
        G.add_node(`node["id"], **{k: v for (k, v) in `node.items() if k != "id"});
    }
    node_set: any = `set(G.nodes());
    _loc_nodes: dict[tuple[str, str], str] = {};
    _loc_collisions: set[tuple[str, str]] = set[any]();
    _noloc_nodes: dict[tuple[str, str], str] = {};
    _ast_file_nodes: list[tuple[str, str]] = [];
    _ast_method_nodes: dict[tuple[str, str], list[str]] = {};
    bare_csharp_method_label: any = importlib.import_module(
        "graphify.extractors.csharp"
    ).bare_csharp_method_label;
    nid: any;
    for nid in sorted(node_set) {
        attrs: any = G.nodes[nid];
        label: any = `str(attrs.get("label", "")).strip();
        sf: any = `str(attrs.get("source_file", ""));
        if not label or not sf {
            continue;
        }
        is_ast: any = operator.eq(attrs.get("_origin"), "ast");
        if attrs.get("source_location") or is_ast {
            key = (sf, label);
            if is_ast {
                if key in _loc_nodes and G.nodes[_loc_nodes[key]].get("_origin") == "ast" {
                    _loc_collisions.add(key);
                }
                _loc_nodes[key] = nid;
                if _is_file_node_label(label, sf) {
                    _ast_file_nodes.append((nid, sf));
                }
                m_label: any = bare_csharp_method_label(label, sf) or label;
                if m_label.startswith(".") and m_label.endswith("()") {
                    m_name: any = make_id(m_label.removeprefix(".").removesuffix("()"));
                    _ast_method_nodes.setdefault((sf, m_name), []).append(nid);
                }
            } else {
                _loc_nodes.setdefault(key, nid);
            }
        }
    }
    _ghost_remap: dict[str, str] = {};
    for nid in sorted(node_set) {
        attrs = G.nodes[nid];
        if attrs.get("_origin") == "ast" {
            continue;
        }
        label = `str(attrs.get("label", "")).strip();
        sf = `str(attrs.get("source_file", ""));
        if not label or not sf {
            continue;
        }
        key = (sf, label);
        if key in _loc_collisions {
            continue;
        }
        if key in _loc_nodes and _loc_nodes[key] != nid {
            if not dedup and G.nodes[_loc_nodes[key]].get("_origin") != "ast" {
                continue;
            }
            if _has_independent_semantic_evidence(attrs) {
                continue;
            }
            _noloc_nodes[key] = nid;
        } elif key not in _loc_nodes {
            m_name = make_id(label.removeprefix(".").removesuffix("()"));
            m_candidates: any = _ast_method_nodes.get((sf, m_name), []);
            if len(m_candidates) == 1 {
                _ghost_remap[nid] = m_candidates[0];
            }
        }
    }
    for (key, sem_id) in _noloc_nodes.items() {
        ast_id: any = _loc_nodes.get(key);
        if ast_id is not None {
            _ghost_remap[sem_id] = ast_id;
        }
    }
    if _ast_file_nodes {
        for nid in sorted(node_set) {
            if nid in _ghost_remap {
                continue;
            }
            attrs = G.nodes[nid];
            if attrs.get("_origin") == "ast" {
                continue;
            }
            label = `str(attrs.get("label", "")).strip();
            if not label {
                continue;
            }
            matches: any = {
                ast_id
                for (ast_id, ast_sf) in _ast_file_nodes
                if _is_file_node_label(label, ast_sf)
            };
            if len(matches) == 1
                and not _has_independent_semantic_evidence(attrs)
                and not _is_file_node_label(label, attrs.get("source_file"))
            {
                _ghost_remap[nid] = next(iter(matches));
            }
        }
    }
    ghost_id: any;
    for ghost_id in _ghost_remap {
        G.remove_node(ghost_id);
        node_set.discard(ghost_id);
    }
    if _ghost_remap {
        G.graph.setdefault("_dedup_remap", {}).update(_ghost_remap);
    }
    norm_to_id = {_normalize_id(nid): nid for nid in node_set};
    for (ghost_id, canonical_id) in _ghost_remap.items() {
        norm_to_id[_normalize_id(ghost_id)] = canonical_id;
        norm_to_id[ghost_id] = canonical_id;
    }
    alias_to_id = _alias_index((nid, G.nodes[nid]) for nid in node_set);

    def _resolve_endpoint(
        raw_id: str, edge_source_file: object, relation: str = "", allow_alias: bool = True
    ) -> str {
        norm: any = _normalize_id(raw_id);
        resolved: any = norm_to_id.get(norm);
        if resolved is not None {
            return resolved;
        }
        if not allow_alias {
            return raw_id;
        }
        alias_target: any = alias_to_id.get(norm);
        if alias_target is not None
            and _alias_lang_compatible(edge_source_file, G.nodes[alias_target].get("source_file"))
        {
            target_attrs: any = G.nodes[alias_target];
            target_sf: any = target_attrs.get("source_file", "");
            is_file_node: any = operator.eq(target_attrs.get("label"), Path(target_sf).name)
                if target_sf
                else False;
            if not (relation in ("calls", "indirect_call") and is_file_node) {
                return alias_target;
            }
        }
        return raw_id;
    }
    dropped_schema_edges: any = 0;
    for `edge in sorted(
        extraction.get("edges", []),
        key=lambda (e) -> any {
            (
                `str(e.get("source", e.get("from", ""))),
                `str(e.get("target", e.get("to", ""))),
                `str(e.get("relation", "")),
            )
        },
    ) {
        if "source" not in `edge and "from" in `edge {
            `edge["source"] = `edge["from"];
        }
        if "target" not in `edge and "to" in `edge {
            `edge["target"] = `edge["to"];
        }
        if "source" not in `edge or "target" not in `edge {
            continue;
        }
        src: any;
        tgt: any;
        (src, tgt) = (`edge["source"], `edge["target"]);
        try {
            hash(src);
            hash(tgt);
        } except TypeError {
            print(
                f"[graphify] WARNING: skipping edge with non-hashable endpoint (source={src!r}, target={tgt!r}).",
                file=sys.stderr,
            );
            continue;
        }
        _edge_rel: any = `str(`edge.get("relation", ""));
        if src not in node_set {
            src = _resolve_endpoint(src, `edge.get("source_file"), _edge_rel);
        }
        if tgt not in node_set {
            tgt = _resolve_endpoint(
                tgt,
                `edge.get("source_file"),
                _edge_rel,
                allow_alias=not _is_std_angle_include(`edge),
            );
        }
        if src not in node_set or tgt not in node_set {
            if `edge.get("relation") in _EXTERNAL_STUB_RELATIONS
                and src in node_set
                and tgt not in node_set
                and isinstance(tgt, `str)
            {
                _mint_external_stub(G, node_set, tgt);
            } else {
                continue;
            }
        }
        attrs = {
            k: v
            for (k, v) in `edge.items()
            if k not in ("source", "target", "target_file", "local_alias")
        };
        for _num_key in ("weight", "confidence_score") {
            if _num_key in attrs {
                try {
                    _num_val: any = `float(attrs[_num_key]);
                } except (TypeError, ValueError) {
                    _num_val = 1.0;
                }
                if not math.isfinite(_num_val) or _num_val < 0 {
                    _num_val = 1.0;
                }
                attrs[_num_key] = _num_val;
            }
        }
        if "also_seen" in attrs {
            _fold_also_seen(attrs, {});
        }
        if not attrs.get("source_file") {
            attrs["source_file"] = G.nodes[src].get("source_file")
                or G.nodes[tgt].get("source_file")
                or "";
        }
        if "source_file" in attrs {
            attrs["source_file"] = _norm_source_file(attrs["source_file"], _root);
        }
        if "relation" not in attrs {
            dropped_schema_edges += 1;
            continue;
        }
        if attrs.get("definition_file") {
            attrs["definition_file"] = _norm_source_file(attrs["definition_file"], _root);
        }
        _edge_rel = attrs.get("relation");
        if _edge_rel in ("calls", "imports", "imports_from", "references") {
            src_ext: any = Path(G.nodes[src].get("source_file") or "").suffix.lower();
            tgt_ext: any = Path(G.nodes[tgt].get("source_file") or "").suffix.lower();
            src_fam: any = _EDGE_LANG_FAMILY.get(src_ext);
            tgt_fam: any = _EDGE_LANG_FAMILY.get(tgt_ext);
            if _edge_rel == "calls" {
                if attrs.get("confidence") == "INFERRED"
                    and src_ext
                    and tgt_ext
                    and src_fam != tgt_fam
                {
                    continue;
                }
            } elif src_fam is not None and tgt_fam is not None and src_fam != tgt_fam {
                continue;
            }
        }
        if src == tgt and _edge_rel in ("imports", "imports_from", "re_exports") {
            continue;
        }
        attrs["_src"] = src;
        attrs["_tgt"] = tgt;
        if _edge_rel in _EXTERNAL_STUB_RELATIONS and G.has_edge(src, tgt) {
            _prior: any = G[src][tgt];
            _reverse_dup: any = not G.is_directed()
                and operator.eq(_prior.get("relation"), attrs.get("relation"))
                and operator.eq(_prior.get("_src"), tgt)
                and operator.eq(_prior.get("_tgt"), src);
            if _prior.get("relation") in _EXTERNAL_STUB_RELATIONS and not _reverse_dup {
                _execution_wins(_prior, attrs);
            }
        }
        if not G.is_directed() and G.has_edge(src, tgt) {
            existing: any = edge_data(G, src, tgt);
            existing_rel: any = existing.get("relation");
            incoming_rel: any = attrs.get("relation");
            reverse: any = operator.eq(existing.get("_src"), tgt)
                and operator.eq(existing.get("_tgt"), src);
            if reverse and existing_rel == incoming_rel {
                if incoming_rel in ("imports_from", "re_exports")
                    and not attrs.get("type_only")
                    and not attrs.get("deferred")
                {
                    existing["reverse_import"] = True;
                }
                continue;
            }
            if reverse
                and existing_rel in _STRUCTURAL_MEMBER_RELATIONS
                and incoming_rel in _MEMBER_USAGE_RELATIONS
            {
                continue;
            }
        }
        if G.has_edge(src, tgt) {
            existing_attrs: any = edge_data(G, src, tgt);
            existing_rel = existing_attrs.get("relation");
            if attrs.get("relation") in _GENERIC_RELATIONS
                and existing_rel is not None
                and existing_rel not in _GENERIC_RELATIONS
            {
                continue;
            }
            if existing_rel == attrs.get("relation") {
                existing_conf: any = existing_attrs.get("confidence");
                incoming_conf: any = attrs.get("confidence");
                existing_rank: any = _CONFIDENCE_RANK.get(existing_conf, 0);
                incoming_rank: any = _CONFIDENCE_RANK.get(incoming_conf, 0);
                if existing_rank > incoming_rank {
                    _fold_also_seen(existing_attrs, attrs);
                    continue;
                }
                if existing_rank == incoming_rank {
                    existing_ast: any = operator.eq(existing_attrs.get("_origin"), "ast");
                    incoming_ast: any = operator.eq(attrs.get("_origin"), "ast");
                    if existing_ast != incoming_ast {
                        if existing_ast {
                            _fold_also_seen(existing_attrs, attrs);
                            continue;
                        }
                    } elif existing_attrs.get("source_location")
                        and not attrs.get("source_location")
                    {
                        _fold_also_seen(existing_attrs, attrs);
                        continue;
                    } else {
                        existing_score: any = existing_attrs.get("confidence_score");
                        incoming_score: any = attrs.get("confidence_score");
                        if existing_score is not None
                            and incoming_score is not None
                            and existing_score > incoming_score
                        {
                            _fold_also_seen(existing_attrs, attrs);
                            continue;
                        }
                    }
                }
                _fold_also_seen(attrs, existing_attrs);
                for _key in (*_EVIDENCE_KEYS, "also_seen") {
                    if _key not in attrs {
                        existing_attrs.pop(_key, None);
                    }
                }
            }
        }
        G.add_edge(src, tgt, **attrs);
    }
    if dropped_schema_edges {
        print(
            f"[graphify] WARNING: dropped {dropped_schema_edges} schema-invalid edge(s) missing required field 'relation'.",
            file=sys.stderr,
        );
    }
    hyperedges: any = extraction.get("hyperedges", []);
    if hyperedges {
        kept_hyperedges: any = [];
        for he in hyperedges {
            if isinstance(he, `dict) and he.get("source_file") {
                he["source_file"] = _norm_source_file(he["source_file"], _root);
            }
            if isinstance(he, `dict) and isinstance(he.get("nodes"), `list) {
                valid_members: any = [];
                for m in he["nodes"] {
                    try {
                        hash(m);
                    } except TypeError {
                        continue;
                    }
                    if m not in node_set and isinstance(m, `str) {
                        m = norm_to_id.get(_normalize_id(m), m);
                    }
                    if m in node_set {
                        valid_members.append(m);
                    }
                }
                if not valid_members {
                    print(
                        "[graphify] WARNING: dropping hyperedge "
                            + format(repr(he.get("id", "?")), "")
                            + " — none of its members "
                            + format(repr(he.get("nodes")), "")
                            + " match built nodes.",
                        file=sys.stderr,
                    );
                    continue;
                }
                if valid_members != he["nodes"] {
                    he["nodes"] = valid_members;
                }
            }
            kept_hyperedges.append(he);
        }
        if kept_hyperedges {
            G.graph["hyperedges"] = kept_hyperedges;
        } else {
            G.graph["hyperedges"] = [];
            print(
                f"[graphify] WARNING: all {len(hyperedges)} hyperedge(s) were dropped by member revalidation; graph.json's hyperedge set will be emptied on the next export.",
                file=sys.stderr,
            );
        }
    }
    _disambiguate_file_node_labels(G);
    _qualify_csharp_method_labels(G);
    return G;
}

impl build(
    extractions: list[dict],
    *,
    directed: bool = False,
    dedup: bool = True,
    dedup_llm_backend: str | None = None,
    `root: str | Path | None = None,
    protected_ids: "set[str] | None" = None,
) -> nx.Graph {
    deduplicate_entities: any = importlib.import_module("graphify.dedup").deduplicate_entities;
    combined: dict = {
        "nodes": [],
        "edges": [],
        "hyperedges": [],
        "input_tokens": 0,
        "output_tokens": 0,
    };
    for ext in extractions {
        combined["nodes"].extend(ext.get("nodes", []));
        combined["edges"].extend(ext.get("edges", []));
        combined["hyperedges"].extend(ext.get("hyperedges", []));
        combined["input_tokens"] += ext.get("input_tokens", 0);
        combined["output_tokens"] += ext.get("output_tokens", 0);
    }
    _root: any = `str(Path(`root).resolve()) if `root else None;
    _dedup_collapsed: any = 0;
    _dedup_remap: dict[str, str] = {};
    if dedup and combined["nodes"] {
        _coerce_non_string_ids(combined);
        for n in combined["nodes"] {
            if isinstance(n, `dict) {
                _fold_node_aliases(n);
                if "source_file" in n {
                    n["source_file"] = _norm_source_file(n["source_file"], _root);
                }
                if "definition_file" in n {
                    n["definition_file"] = _norm_source_file(n["definition_file"], _root);
                }
            }
        }
        _before_dedup: any = len(combined["nodes"]);
        items_: any = list(
            deduplicate_entities(
                combined["nodes"],
                combined["edges"],
                communities={},
                dedup_llm_backend=dedup_llm_backend,
                root=_root,
                hyperedges=combined.get("hyperedges"),
                protected_ids=protected_ids,
                remap_out=_dedup_remap,
            ) as any,
        );
        if len(items_) != 2 {
            raise ValueError(
                f"too many values to unpack (expected 2, got {len(items_)})"
                    if len(items_) > 2
                    else f"not enough values to unpack (expected 2, got {len(items_)})",
            );
        }
        combined["nodes"] = items_[0];
        combined["edges"] = items_[1];
        _dedup_collapsed = _before_dedup - len(combined["nodes"]);
    }
    G: any = build_from_json(combined, directed=directed, root=_root, dedup=dedup);
    if _dedup_collapsed {
        G.graph["_dedup_collapsed"] = _dedup_collapsed;
    }
    if _dedup_remap {
        G.graph.setdefault("_dedup_remap", {}).update(_dedup_remap);
    }
    return G;
}

impl take_shrink_accounting(G) -> tuple[int, int] {
    attrs: any = getattr(G, "graph", None);
    if not isinstance(attrs, `dict) {
        return (0, 0);
    }
    collapsed: any = `int(attrs.pop("_dedup_collapsed", 0) or 0);
    pruned: any = `int(attrs.pop("_pruned_node_count", 0) or 0);
    return (collapsed, pruned);
}

impl take_dedup_remap(G) -> dict[str, str] {
    attrs: any = getattr(G, "graph", None);
    if not isinstance(attrs, `dict) {
        return {};
    }
    remap: any = attrs.pop("_dedup_remap", None);
    return `dict(remap) if isinstance(remap, `dict) else {};
}

impl _norm_label(label: str | None) -> str {
    if not isinstance(label, `str) {
        label = "" if label is None else `str(label);
    }
    label = unicodedata.normalize("NFKC", label);
    return re.sub("[\\W_ ]+", " ", label.casefold(), flags=re.UNICODE).strip();
}

impl deduplicate_by_label(nodes: list[dict], edges: list[dict]) -> tuple[list[dict], list[dict]] {
    _CHUNK_SUFFIX: any = re.compile("_c\\d+$");
    canonical: dict[str, dict] = {};
    remap: dict[str, str] = {};

    for `node in nodes {
        key: any = _norm_label(`node.get("label", `node.get("id", "")));
        if not key {
            continue;
        }
        existing: any = canonical.get(key);
        if existing is None {
            canonical[key] = `node;
        } else {
            has_suffix: any = `bool(_CHUNK_SUFFIX.search(`node["id"]));
            existing_has_suffix: any = `bool(_CHUNK_SUFFIX.search(existing["id"]));
            if has_suffix and not existing_has_suffix {
                remap[`node["id"]] = existing["id"];
            } elif existing_has_suffix and not has_suffix {
                remap[existing["id"]] = `node["id"];
                canonical[key] = `node;
            } elif len(`node["id"]) < len(existing["id"]) {
                remap[existing["id"]] = `node["id"];
                canonical[key] = `node;
            } else {
                remap[`node["id"]] = existing["id"];
            }
        }
    }

    if not remap {
        return (nodes, edges);
    }

    print(f"[graphify] Deduplicated {len(remap)} duplicate node(s) by label.", file=sys.stderr);
    deduped_nodes: any = `list(canonical.values());
    deduped_edges: any = [];
    for `edge in edges {
        e: any = `dict(`edge);
        e["source"] = remap.get(e["source"], e["source"]);
        e["target"] = remap.get(e["target"], e["target"]);
        if e["source"] != e["target"] {
            deduped_edges.append(e);
        }
    }
    return (deduped_nodes, deduped_edges);
}

impl _load_existing_graph(graph_path: Path) -> "tuple[list, list, list, bool] | None" {
    if not graph_path.exists() {
        return None;
    }
    check_graph_file_size_cap: any = importlib.import_module(
        "graphify.security"
    ).check_graph_file_size_cap;
    check_graph_file_size_cap(graph_path);
    try {
        data: any = json.loads(graph_path.read_text(encoding="utf-8"));
    } except (json.JSONDecodeError, OSError) as exc {
        raise RuntimeError(
            f"Cannot read {graph_path} for incremental merge: {exc}. Delete the file and run a full rebuild.",
        ) from exc;
    }
    links_key: any = "links" if "links" in data else "edges";
    nodes: any = `list(data.get("nodes", []));
    edges: any = `list(data.get(links_key, []));
    top_level: any = data.get("hyperedges");
    if isinstance(top_level, `list) {
        hyperedges: any = top_level;
    } else {
        graph_attrs: any = data.get("graph");
        nested: any = graph_attrs.get("hyperedges") if isinstance(graph_attrs, `dict) else None;
        hyperedges = nested if isinstance(nested, `list) else [];
    }
    for item in nodes + edges {
        if isinstance(item, `dict) {
            _backfill_origin(item);
        }
    }
    return (nodes, edges, hyperedges, `bool(data.get("directed", False)));
}

impl _tier_replacement_sources(
    chunks: "Iterable[dict]",
    `root: "str | Path | None" = None,
    ast_sources: "Iterable[str | Path] | None" = None,
) -> tuple[set[str], set[str]] {
    explicit_ast_sources: set[str] = set[any]();
    if ast_sources is not None {
        s: any;
        for s in ast_sources {
            if s {
                explicit_ast_sources.add(`str(s));
            }
        }
    }
    ch: any;
    for ch in chunks {
        if isinstance(ch, `dict) {
            for s in ch.get("extracted_sources") or [] {
                if s {
                    explicit_ast_sources.add(`str(s));
                }
            }
        }
    }

    new_ast_sources: set[str] = set[any]();
    new_sem_sources: set[str] = set[any]();

    if explicit_ast_sources {
        sf: any;
        for sf in explicit_ast_sources {
            new_ast_sources.add(sf);
            norm: any = _norm_source_file(sf, `root);
            if norm {
                new_ast_sources.add(norm);
            }
        }
    } else {
        for ch in chunks {
            if not isinstance(ch, `dict) {
                continue;
            }
            n: any;
            for n in ch.get("nodes", []) {
                if not isinstance(n, `dict) {
                    continue;
                }
                sf = n.get("source_file");
                if not sf or not _is_ast_tier(n) {
                    continue;
                }
                new_ast_sources.add(sf);
                norm = _norm_source_file(sf, `root);
                if norm {
                    new_ast_sources.add(norm);
                }
            }
        }
    }

    for ch in chunks {
        if not isinstance(ch, `dict) {
            continue;
        }
        for n in ch.get("nodes", []) {
            if not isinstance(n, `dict) {
                continue;
            }
            sf = n.get("source_file");
            if not sf or _is_ast_tier(n) {
                continue;
            }
            new_sem_sources.add(sf);
            norm = _norm_source_file(sf, `root);
            if norm {
                new_sem_sources.add(norm);
            }
        }
    }
    failure_root: any = `str(`root) if `root is not None else None;
    failed_ast: any = {
        _abs_identity(`str(sf), failure_root)
        for ch in chunks
        if isinstance(ch, `dict)
        for sf in ch.get("failed_sources") or []
        if sf
    };
    new_ast_sources = {
        sf
        for sf in new_ast_sources
        if _abs_identity(sf, failure_root) not in failed_ast
    };
    return (new_ast_sources, new_sem_sources);
}

impl merge_raw_extraction(
    new: dict,
    graph_path: str | Path,
    prune_sources: "list[str] | None" = None,
    `root: "str | Path | None" = None,
    *,
    ast_sources: "Iterable[str | Path] | None" = None,
) -> dict {
    _eff_root: any;
    new_ast_sources: any;
    new_sem_sources: any;
    prune_set: any;
    prune_abs: any;
    _prune_root: any;
    sf: any;
    graph_path = Path(graph_path);
    loaded: any = _load_existing_graph(graph_path);
    if loaded is None {
        return new;
    }
    existing_nodes: any;
    existing_edges: any;
    existing_hyperedges: any;
    _: any;
    (existing_nodes, existing_edges, existing_hyperedges, _) = loaded as any;

    _eff_root = `str(Path(`root).resolve()) if `root is not None else _infer_merge_root(graph_path);
    (new_ast_sources, new_sem_sources) = _tier_replacement_sources(
        [new], root=_eff_root, ast_sources=ast_sources
    ) as any;
    new_sources: set[str] = new_ast_sources | new_sem_sources;
    (prune_set, prune_abs) = _build_prune_sets(prune_sources, _eff_root, new_sources) as any;
    _prune_root = _eff_root;

    def _prune_hit(sf: "str | None") -> bool {
        if not sf {
            return False;
        }
        if sf in prune_set {
            return True;
        }
        a: any = _prune_identity(sf, _prune_root);
        return `bool(a) and a in prune_abs;
    }
    if prune_set or prune_abs {
        _stored_sfs: any = {
            item.get("source_file")
            for seq in (existing_nodes, existing_edges, existing_hyperedges)
            for item in seq
            if isinstance(item, `dict)
        };
        _stored_sfs.discard(None);
        if not `any(_prune_hit(sf) for sf in _stored_sfs) {
            _derived: any = _derive_prune_root(prune_sources or [], _stored_sfs);
            if _derived is not None and _derived != _prune_root {
                _prune_root = _derived;
                (prune_set, prune_abs) = _build_prune_sets(
                    prune_sources, _prune_root, new_sources
                ) as any;
            }
        }
    }

    def _dropped(item: dict) -> bool {
        if not isinstance(item, `dict) {
            return True;
        }
        sf: any = item.get("source_file");
        `own: any = new_ast_sources if _is_ast_tier(item) else new_sem_sources;
        if sf in `own or _norm_source_file(sf, _eff_root) in `own {
            return True;
        }
        if not sf {
            return False;
        }
        return _prune_hit(sf);
    }
    unverified_semantic_shrink: dict[str, tuple[int, int]] = {};
    if new_sem_sources {
        prior_sem_counts: dict[str, int] = {};
        n: any;
        for n in existing_nodes {
            if isinstance(n, `dict) and not _is_ast_tier(n) {
                sf = n.get("source_file");
                if sf {
                    canon: any = _norm_source_file(sf, _eff_root) or sf;
                    prior_sem_counts[canon] = prior_sem_counts.get(canon, 0) + 1;
                }
            }
        }

        fresh_sem_counts: dict[str, int] = {};
        for n in new.get("nodes", []) {
            if isinstance(n, `dict) and not _is_ast_tier(n) {
                sf = n.get("source_file");
                if sf {
                    canon = _norm_source_file(sf, _eff_root) or sf;
                    fresh_sem_counts[canon] = fresh_sem_counts.get(canon, 0) + 1;
                }
            }
        }

        for (canon_sf, fresh_count) in fresh_sem_counts.items() {
            prior_count: any = prior_sem_counts.get(canon_sf, 0);
            if prior_count > 1 and fresh_count < prior_count {
                unverified_semantic_shrink[canon_sf] = (prior_count, fresh_count);
            }
        }
    }

    new["nodes"] = [n for n in existing_nodes if not _dropped(n)] + `list(new.get("nodes", []));
    new["edges"] = [e for e in existing_edges if not _dropped(e)] + `list(new.get("edges", []));
    carried_hyper: any = [he for he in existing_hyperedges if not _dropped(he)];
    if carried_hyper or new.get("hyperedges") {
        new["hyperedges"] = carried_hyper + `list(new.get("hyperedges", []));
    }
    if unverified_semantic_shrink {
        new["_unverified_semantic_shrink"] = unverified_semantic_shrink;
    }
    return new;
}

impl build_merge(
    new_chunks: list[dict],
    graph_path: str | Path | None = None,
    prune_sources: list[str] | None = None,
    *,
    directed: bool | None = None,
    dedup: bool = True,
    dedup_llm_backend: str | None = None,
    `root: str | Path | None = None,
    ast_sources: "Iterable[str | Path] | None" = None,
) -> nx.Graph {
    _replace_root: any;
    new_ast_sources: any;
    new_sem_sources: any;
    _spare_isolated: any;
    unverified_semantic_shrink: dict[str, tuple[int, int]];
    _prune_root: any;
    prune_set: any;
    prune_abs: any;
    _matched_prune_entries: set[str];
    he: any;
    G: any;
    _isolated_before: set;
    _disk_ids: any;
    _folds: any;
    new_chunks = `list(new_chunks);
    graph_path = Path(graph_path if graph_path is not None else _default_graph_json());
    _loaded: any = _load_existing_graph(graph_path);
    if _loaded is not None {
        existing_nodes: any;
        existing_edges: any;
        existing_hyperedges: any;
        existing_directed: any;
        (existing_nodes, existing_edges, existing_hyperedges, existing_directed) = _loaded as any;
        had_graph: any = True;
    } else {
        existing_nodes = [];
        existing_edges = [];
        existing_hyperedges = [];
        existing_directed = False;
        had_graph = False;
    }
    if directed is None {
        directed = existing_directed if had_graph else False;
    }
    _eff_root: any = `str(Path(`root).resolve())
        if `root is not None
        else _infer_merge_root(graph_path);
    _replace_root = _eff_root;
    (new_ast_sources, new_sem_sources) = _tier_replacement_sources(
        new_chunks, root=_replace_root, ast_sources=ast_sources
    ) as any;
    new_sources: set[str] = new_ast_sources | new_sem_sources;
    _disk_nodes: any = existing_nodes;
    _disk_n: any = len(existing_nodes);
    def _isolated_sourceless(nodes, edges) -> set {
        linked: any = {
            e.get(k)
            for e in edges
            if isinstance(e, `dict)
            for k in ("source", "target")
            if _hashable(e.get(k))
        };
        return {
            n.get("id")
            for n in nodes
            if isinstance(n, `dict)
                and _hashable(n.get("id"))
                and not n.get("source_file")
                and n.get("id") not in linked
        };
    }
    _spare_isolated = _isolated_sourceless(existing_nodes, existing_edges) | {
        nid
        for ch in new_chunks
        for nid in _isolated_sourceless(ch.get("nodes", []), ch.get("edges", []))
    };
    unverified_semantic_shrink = {};
    if had_graph and new_sem_sources {
        prior_sem_counts: dict[str, int] = {};
        n: any;
        for n in _disk_nodes {
            if isinstance(n, `dict) and not _is_ast_tier(n) {
                sf: any = n.get("source_file");
                if sf {
                    canon: any = _norm_source_file(sf, _replace_root) or sf;
                    prior_sem_counts[canon] = prior_sem_counts.get(canon, 0) + 1;
                }
            }
        }

        fresh_sem_counts: dict[str, int] = {};
        for ch in new_chunks {
            for n in ch.get("nodes", []) {
                if isinstance(n, `dict) and not _is_ast_tier(n) {
                    sf = n.get("source_file");
                    if sf {
                        canon = _norm_source_file(sf, _replace_root) or sf;
                        fresh_sem_counts[canon] = fresh_sem_counts.get(canon, 0) + 1;
                    }
                }
            }
        }

        for (canon_sf, fresh_count) in fresh_sem_counts.items() {
            prior_count: any = prior_sem_counts.get(canon_sf, 0);
            if prior_count > 1 and fresh_count < prior_count {
                unverified_semantic_shrink[canon_sf] = (prior_count, fresh_count);
            }
        }
    }

    if new_sources {
        def _kept(item: dict) -> bool {
            sf: any = item.get("source_file");
            `own: any = new_ast_sources if _is_ast_tier(item) else new_sem_sources;
            return sf not in `own and _norm_source_file(sf, _replace_root) not in `own;
        }
        existing_nodes = [n for n in existing_nodes if _kept(n)];
        existing_edges = [e for e in existing_edges if _kept(e)];
        replaced_n: any = _disk_n - len(existing_nodes);
        if replaced_n {
            print(
                f"[graphify] Replaced {replaced_n} node(s) from re-extracted source file(s).",
                file=sys.stderr,
            );
        }
    }
    _prune_root = _eff_root;
    (prune_set, prune_abs) = _build_prune_sets(prune_sources, _prune_root, new_sources) as any;
    _matched_prune_entries = set[any]();

    def _prune_match(sf: "str | None") -> bool {
        if not sf {
            return False;
        }
        hit: any = prune_set.get(sf);
        if hit is None {
            a: any = _prune_identity(sf, _prune_root);
            if a {
                hit = prune_abs.get(a);
            }
        }
        if hit is None {
            return False;
        }
        _matched_prune_entries.add(hit);
        return True;
    }
    if prune_set or prune_abs {
        _stored_sfs: any = {
            item.get("source_file")
            for seq in (_disk_nodes, existing_edges, existing_hyperedges)
            for item in seq
            if isinstance(item, `dict)
        };
        _stored_sfs.discard(None);
        if not `any(_prune_match(sf) for sf in _stored_sfs) {
            _derived: any = _derive_prune_root(prune_sources or [], _stored_sfs);
            if _derived is not None and _derived != _prune_root {
                _prune_root = _derived;
                (prune_set, prune_abs) = _build_prune_sets(
                    prune_sources, _prune_root, new_sources
                ) as any;
            }
        }
    }
    carried_hyperedges: list[dict] = [];
    if existing_hyperedges {
        carried: any = carried_hyperedges;
        _new_hyperedge_keys: any = {
            (he.get("id"), _norm_source_file(he.get("source_file"), _eff_root) or None)
            for chunk in new_chunks
            for he in chunk.get("hyperedges") or []
            if isinstance(he, `dict) and he.get("id")
        };
        for he in existing_hyperedges {
            if not isinstance(he, `dict) {
                continue;
            }
            sf = he.get("source_file");
            norm: any = _norm_source_file(sf, _eff_root);
            if sf in new_sem_sources or norm in new_sem_sources {
                continue;
            }
            if _prune_match(sf) {
                continue;
            }
            if he.get("id") and (he.get("id"), norm or None) in _new_hyperedge_keys {
                continue;
            }
            carried.append(he);
        }
    }
    if prune_sources {
        fresh_ids: any = {n.get("id") for chunk in new_chunks for n in chunk.get("nodes", [])};
        existing_nodes = [
            n
            for n in existing_nodes
            if not (n.get("id") in fresh_ids and _prune_match(n.get("source_file")))
        ];
    }

    base: any = [
        {"nodes": existing_nodes, "edges": existing_edges, "hyperedges": carried_hyperedges},
    ]
        if had_graph
        else [];
    _protected_ids: any = {n["id"] for n in existing_nodes if isinstance(n, `dict) and n.get("id")}
        if had_graph
        else None;

    all_chunks: any = base + `list(new_chunks);
    G = build(
        all_chunks,
        directed=directed,
        dedup=dedup,
        dedup_llm_backend=dedup_llm_backend,
        root=_eff_root,
        protected_ids=_protected_ids,
    );
    def _sweep_orphans -> list {
        _he_members: any = {
            m
            for he in G.graph.get("hyperedges") or []
            if isinstance(he, `dict)
            for m in he.get("nodes") or []
            if _hashable(m)
        };
        orphaned: any = [
            n
            for (n, d) in G.nodes(data=True)
            if not d.get("source_file")
                and G.degree(n) == 0
                and n not in _spare_isolated
                and n not in _he_members
                and (
                    d.get("file_type") == "code"
                    or _is_external_stub(d)
                    or prune_sources and n not in _isolated_before
                )
        ];
        G.remove_nodes_from(orphaned);
        return orphaned;
    }
    _isolated_before = set[any]();
    if prune_sources {
        _isolated_before = {
            n
            for (n, d) in G.nodes(data=True)
            if not d.get("source_file") and G.degree(n) == 0
        };
        to_remove: any = [n for (n, d) in G.nodes(data=True) if _prune_match(d.get("source_file"))];
        G.remove_nodes_from(to_remove);
        n_nodes: any = len(to_remove);

        edges_to_remove: any = [
            (u, v)
            for (u, v, d) in G.edges(data=True)
            if _prune_match(d.get("source_file"))
        ];
        if edges_to_remove {
            G.remove_edges_from(edges_to_remove);
        }
        if G.graph.get("hyperedges") {
            _pruned_hyperedges: any = [];
            for he in G.graph["hyperedges"] {
                if not isinstance(he, `dict) {
                    _pruned_hyperedges.append(he);
                    continue;
                }
                members: any = he.get("nodes");
                if isinstance(members, `list) {
                    live: any = [m for m in members if _hashable(m) and m in G];
                    if not live {
                        continue;
                    }
                    if live != members {
                        he["nodes"] = live;
                    }
                }
                _pruned_hyperedges.append(he);
            }
            G.graph["hyperedges"] = _pruned_hyperedges;
        }

        orphaned: any = _sweep_orphans();
        n_nodes += len(orphaned);
        _disk_ids = {
            n.get("id")
            for n in _disk_nodes
            if isinstance(n, `dict) and n.get("id") is not None
        };
        G.graph["_pruned_node_count"] = sum(
            1 for nid in (*to_remove, *orphaned) if nid in _disk_ids
        );
        n_files: any = len(_matched_prune_entries);
        if n_nodes {
            print(
                f"[graphify] Pruned {n_nodes} node(s) from {n_files} deleted or excluded source file(s).",
                file=sys.stderr,
            );
        }
        if edges_to_remove {
            print(
                f"[graphify] Pruned {len(edges_to_remove)} edge(s) from deleted or excluded source file(s).",
                file=sys.stderr,
            );
        }

        if not n_nodes and not edges_to_remove {
            if (prune_set or prune_abs) and not _matched_prune_entries {
                _p0: any = next((p for p in prune_sources if p), None);
                sample_prune: any = _norm_source_file(_p0, _prune_root) or _p0;
                sample_sf: any = next(
                    iter(
                        sorted(
                            `str(d.get("source_file"))
                            for (_, d) in G.nodes(data=True)
                            if d.get("source_file"),
                        ),
                    ),
                    None,
                );
                print(
                    f"[graphify] WARNING: {len(prune_sources)} prune source(s) matched no nodes or edges — nothing was removed. Prune entry {sample_prune!r} does not correspond to any stored source_file (e.g. {sample_sf!r}). If these files should have been pruned, pass root= to build_merge so absolute paths relativize to the graph's source_file keys. (#2446)",
                    file=sys.stderr,
                );
            } else {
                print(
                    f"[graphify] {len(prune_sources)} source file(s) deleted or excluded since last run — no matching nodes or edges in graph, already clean.",
                    file=sys.stderr,
                );
            }
        }
    } else {
        _swept: any = _sweep_orphans();
        if _swept {
            _disk_ids = {
                n.get("id")
                for n in _disk_nodes
                if isinstance(n, `dict) and n.get("id") is not None
            };
            G.graph["_pruned_node_count"] = sum(1 for nid in _swept if nid in _disk_ids);
            print(
                f"[graphify] Removed {len(_swept)} source-less node(s) left with no edges by re-extraction.",
                file=sys.stderr,
            );
        }
    }
    if had_graph and not dedup {
        _folds = G.graph.get("_dedup_remap") or {};

        def _in_new_graph(n: dict) -> bool {
            nid: any = n.get("id");
            if nid is None or not _hashable(nid) {
                return True;
            }
            if nid in G {
                return True;
            }
            if _folds.get(nid) in G {
                return True;
            }
            return isinstance(nid, `str)
                and not nid.endswith("_doc")
                and operator.eq(n.get("file_type"), "document")
                and f"{nid}_doc" in G
                and operator.eq(G.nodes[f"{nid}_doc"].get("source_file"), n.get("source_file"));
        }

        lost: any = [n for n in _disk_nodes if isinstance(n, `dict) and not _in_new_graph(n)];

        def _explained(n: dict) -> bool {
            sf: any = n.get("source_file");
            if not sf {
                return True;
            }
            `own: any = new_ast_sources if _is_ast_tier(n) else new_sem_sources;
            if sf in `own or _norm_source_file(sf, _replace_root) in `own {
                return True;
            }
            return _prune_match(sf);
        }

        unexplained: any = [n for n in lost if not _explained(n)];
        if unexplained {
            raise ValueError(
                "graphify: build_merge would drop "
                    + format(len(unexplained), "")
                    + " node(s) from sources that were neither re-extracted nor pruned this run (e.g. "
                    + format(repr(unexplained[0].get("id")), "")
                    + "); graph would go "
                    + format(_disk_n, "")
                    + " → "
                    + format(G.number_of_nodes(), "")
                    + " nodes. Pass prune_sources explicitly if you intend to remove them. (#479)",
            );
        }
    }

    if unverified_semantic_shrink {
        G.graph["_unverified_semantic_shrink"] = unverified_semantic_shrink;
    }
    def _replaced_on_purpose(sf: str) -> bool {
        norm: any = _norm_source_file(sf, _replace_root) or sf;
        if norm in unverified_semantic_shrink {
            return False;
        }
        return sf in new_sem_sources or norm in new_sem_sources or _prune_match(sf);
    }

    _replaced_sources: any = {
        n["source_file"]
        for n in _disk_nodes
        if isinstance(n, `dict)
            and not _is_ast_tier(n)
            and isinstance(n.get("source_file"), `str)
            and n["source_file"]
            and _replaced_on_purpose(n["source_file"])
    };
    if _replaced_sources {
        G.graph["_replaced_sources"] = sorted(_replaced_sources);
    }

    return G;
}

impl prefix_graph_for_global(G: nx.Graph, repo_tag: str, community_offset: int = 0) -> nx.Graph {
    relabel: any = {
        n: f"{repo_tag}::{n}"
        for (n, d) in G.nodes(data=True)
        if not d.get("external")
    };
    H: any = nx.relabel_nodes(G, relabel, copy=True);
    data: any;
    for (`node, data) in H.nodes(data=True) {
        if data.get("external") {
            continue;
        }
        data["repo"] = repo_tag;
        data.setdefault("local_id", `node.split("::", 1)[1]);
        cid: any = data.get("community");
        if community_offset and isinstance(cid, `int) {
            data["local_community"] = cid;
            data["community"] = cid + community_offset;
        }
    }
    for (u, v, data) in H.edges(data=True) {
        if "_src" in data and data["_src"] in relabel {
            data["_src"] = relabel[data["_src"]];
        }
        if "_tgt" in data and data["_tgt"] in relabel {
            data["_tgt"] = relabel[data["_tgt"]];
        }
    }
    hyperedges: any = H.graph.get("hyperedges");
    if isinstance(hyperedges, `list) {
        rewritten: any = [];
        he: any;
        for he in hyperedges {
            if isinstance(he, `dict) {
                he = `dict(he);
                if isinstance(he.get("nodes"), `list) {
                    he["nodes"] = [relabel.get(m, m) if _hashable(m) else m for m in he["nodes"]];
                }
                if he.get("id") {
                    he["id"] = format(repo_tag, "") + "::" + format(he["id"], "");
                }
            }
            rewritten.append(he);
        }
        H.graph["hyperedges"] = rewritten;
    }
    return H;
}

impl distinct_repo_tags(graph_paths: "list[Path]") -> "list[str]" {
    d: any;
    repo_dirs: any = [p.parent.parent for p in graph_paths];
    tags: any = [d.name or "repo" for d in repo_dirs];
    if len(`set(tags)) != len(tags) {
        widened: list[str] = [];
        for d in repo_dirs {
            parent: any = d.parent.name;
            widened.append(f"{parent}_{d.name}" if parent and d.name else d.name or "repo");
        }
        tags = widened;
    }
    seen: dict[str, int] = {};
    unique: list[str] = [];
    for t in tags {
        seen[t] = seen.get(t, 0) + 1;
        unique.append(t if seen[t] == 1 else f"{t}-{seen[t]}");
    }
    return unique;
}

impl prune_repo_from_graph(G: nx.Graph, repo_tag: str) -> int {
    to_remove: any = [n for (n, d) in G.nodes(data=True) if d.get("repo") == repo_tag];
    G.remove_nodes_from(to_remove);
    return len(to_remove);
}
