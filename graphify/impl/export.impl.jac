impl backup_if_protected(out_dir: Path) -> "Path | None" {
    out: any;
    backup_dir: any;
    name: any;
    if os.environ.get("GRAPHIFY_NO_BACKUP") {
        return None;
    }
    out = Path(out_dir);
    if not (out / "graph.json").exists() {
        return None;
    }

    is_semantic: any = (out / ".graphify_semantic_marker").exists();
    is_curated: any = False;
    labels_file: any = out / ".graphify_labels.json";
    if labels_file.exists() {
        try {
            labels: any = json.loads(labels_file.read_text(encoding="utf-8"));
            is_curated = `any(operator.ne(v, f"Community {k}") for (k, v) in labels.items());
        } except Exception {}
    }

    if not is_semantic and not is_curated {
        return None;
    }

    reason: any = "+".join(
        filter(None, ["semantic" if is_semantic else "", "curated" if is_curated else ""])
    );
    today: any = date.today().isoformat();
    backup_dir = out / today;
    graph_src: any = out / "graph.json";

    try {
        if backup_dir.exists() and (backup_dir / "graph.json").exists() {
            src_hash: any = hashlib.sha256(graph_src.read_bytes()).hexdigest();
            bak_hash: any = hashlib.sha256((backup_dir / "graph.json").read_bytes()).hexdigest();
            if src_hash == bak_hash
                and all(
                    (backup_dir / name).exists()
                    for name in _BACKUP_ARTIFACTS
                    if (out / name).exists(),
                )
            {
                return backup_dir;
            }
        }
        backup_dir.mkdir(parents=True, exist_ok=True);
        copied: any = 0;
        failed: list[str] = [];
        for name in _BACKUP_ARTIFACTS {
            src: any = out / name;
            if src.exists() {
                try {
                    shutil.copy2(src, backup_dir / name);
                    copied += 1;
                } except Exception {
                    failed.append(name);
                }
            }
        }
        if failed {
            print(
                "[graphify] warning: backup incomplete - could not copy "
                    + format(", ".join(failed), "")
                    + " -> "
                    + format(backup_dir.name, "")
                    + "/ - continuing with overwrite",
                file=sys.stderr,
            );
            return None;
        }
        if copied {
            print(f"[graphify] backed up {reason} graph ({copied} files) -> {backup_dir.name}/");
        }
        return backup_dir;
    } except Exception as exc {
        print(
            f"[graphify] warning: backup failed ({exc}) - continuing with overwrite",
            file=sys.stderr,
        );
        return None;
    }
}

impl _obsidian_tag(name: str) -> str {
    tag: any = re.sub("[^\\w\\-/]", "", name.replace(" ", "_"));
    if not tag.strip("_-/") {
        return "unnamed";
    }
    if tag.isdigit() {
        return f"c{tag}";
    }
    return tag;
}

impl _strip_diacritics(text: str | None) -> str {
    import unicodedata;
    if not isinstance(text, `str) {
        text = "" if text is None else `str(text);
    }
    nfkd: any = unicodedata.normalize("NFKD", text);
    return "".join(c for c in nfkd if not unicodedata.combining(c));
}

impl _yaml_str(s: str) -> str {
    if s is None {
        return "";
    }
    out: list[str] = [];
    for ch in `str(s) {
        cp: any = ord(ch);
        if ch == "\\" {
            out.append("\\\\");
        } elif ch == "\"" {
            out.append("\\\"");
        } elif ch == "\n" {
            out.append("\\n");
        } elif ch == "\r" {
            out.append("\\r");
        } elif ch == "\t" {
            out.append("\\t");
        } elif ch == "\x00" {
            out.append("\\0");
        } elif cp == 8232 {
            out.append("\\L");
        } elif cp == 8233 {
            out.append("\\P");
        } elif cp < 32 or cp == 127 {
            out.append(f"\\x{cp:02x}");
        } else {
            out.append(ch);
        }
    }
    return "".join(out);
}

impl _graphify_version -> str | None {
    try {
        import from importlib.metadata { version }

        return version("graphifyy");
    } except Exception {
        return None;
    }
}

impl attach_hyperedges(G: nx.Graph, hyperedges: list) {
    h: any;
    existing: any = G.graph.get("hyperedges", []);
    seen_ids: any = {h["id"] for h in existing if h.get("id")};
    for h in hyperedges {
        if h.get("id") and h["id"] not in seen_ids {
            existing.append(h);
            seen_ids.add(h["id"]);
        }
    }
    G.graph["hyperedges"] = existing;
}

impl _git_head(cwd: "str | Path | None" = None) -> str | None {
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

impl _load_existing_graph_nodes(path: "str | Path") -> any {
    p: any = Path(path);
    if not p.exists() {
        return None;
    }
    check_graph_file_size_cap: any = importlib.import_module(
        "graphify.security"
    ).check_graph_file_size_cap;
    try {
        check_graph_file_size_cap(p);
    } except Exception {
        return None;
    }
    try {
        raw: any = p.read_text(encoding="utf-8");
    } except Exception {
        try {
            return MALFORMED_GRAPH if p.stat().st_size > 0 else None;
        } except Exception {
            return None;
        }
    }
    if not raw.strip() {
        return None;
    }
    try {
        data: any = json.loads(raw);
    } except Exception {
        return MALFORMED_GRAPH;
    }
    nodes: any = data.get("nodes") if isinstance(data, `dict) else None;
    return nodes if isinstance(nodes, `list) else MALFORMED_GRAPH;
}

impl existing_graph_node_count(path: "str | Path") -> any {
    nodes: any = _load_existing_graph_nodes(path);
    if not isinstance(nodes, `list) {
        return nodes;
    }
    return len(nodes);
}

impl existing_graph_node_counts_by_source(path: "str | Path") -> any {
    nodes: any = _load_existing_graph_nodes(path);
    if not isinstance(nodes, `list) {
        return nodes;
    }
    counts: dict[str, int] = {};
    for n in nodes {
        if isinstance(n, `dict) {
            sf: any = n.get("source_file") or "";
            counts[sf] = counts.get(sf, 0) + 1;
        }
    }
    return counts;
}

impl to_json(
    G: nx.Graph,
    communities: dict[int, list[str]],
    output_path: str,
    *,
    force: bool = False,
    built_at_commit: str | None = None,
    community_labels: dict[int, str] | None = None,
    original_links: "list[dict] | None" = None,
) -> bool {
    existing_ids: any;
    `node: any;
    link: any;
    take_dedup_remap: any = importlib.import_module("graphify.build").take_dedup_remap;
    take_shrink_accounting: any = importlib.import_module("graphify.build").take_shrink_accounting;
    dedup_remap: any = take_dedup_remap(G);
    take_shrink_accounting(G);
    replaced_sources: any = `set(G.graph.pop("_replaced_sources", None) or ());
    existing_path: any = Path(output_path);
    if not force and existing_path.exists() {
        check_graph_file_size_cap: any = importlib.import_module(
            "graphify.security"
        ).check_graph_file_size_cap;
        try {
            check_graph_file_size_cap(existing_path);
        } except Exception {
            oversized: any = True;
        } else {
            oversized = False;
        }
        if not oversized {
            try {
                raw: any = existing_path.read_text(encoding="utf-8");
            } except Exception {
                raw = "";
            }
            if not raw.strip() {
                existing_n: any = 0;
                existing_nodes: any = [];
            } else {
                try {
                    existing_data: any = json.loads(raw);
                    del raw;
                    existing_nodes = existing_data.get("nodes", []);
                    del existing_data;
                    if not isinstance(existing_nodes, `list) {
                        existing_nodes = [];
                    }
                    existing_n = len(existing_nodes);
                } except Exception as exc {
                    import sys as _sys;
                    print(
                        f"[graphify] WARNING: existing {existing_path} could not be read to verify the new graph is not smaller ({exc}). Refusing to overwrite; pass force=True to override.",
                        file=_sys.stderr,
                    );
                    return False;
                }
            }
            new_n: any = G.number_of_nodes();
            _dedup_shrink_allowance: any = importlib.import_module(
                "graphify.build"
            )._dedup_shrink_allowance;
            _lost_saved_semantic_nodes: any = importlib.import_module(
                "graphify.build"
            )._lost_saved_semantic_nodes;
            new_node_list: any = [
                {"id": node_id, **{key: value for (key, value) in attrs.items() if key != "id"}}
                for (node_id, attrs) in G.nodes(data=True)
            ];
            folded: dict[str, str] = {};
            missing: any = _lost_saved_semantic_nodes(
                existing_nodes, new_node_list, replaced_sources, folded, dedup_remap=dedup_remap
            );
            if missing {
                import sys as _sys;
                ids: any = ", ".join(`str(`node.get("id")) for `node in missing);
                print(
                    f"[graphify] WARNING: Refusing to overwrite — saved semantic node(s) are missing from the new graph: {ids}.",
                    file=_sys.stderr,
                );
                return False;
            }
            existing_ids = {n.get("id") for n in existing_nodes if isinstance(n, `dict)};
            merged: any = sum(twin in existing_ids for twin in folded.values());
            if dedup_remap {
                merged += _dedup_shrink_allowance(existing_ids, `set(G.nodes), dedup_remap);
            }
            if new_n < existing_n - merged {
                import sys as _sys;
                print(
                    f"[graphify] WARNING: new graph has {new_n} nodes but existing graph.json has {existing_n} (net -{existing_n - new_n}). Refusing to overwrite. Possible causes: missing chunk files from a previous session, or fuzzy dedup collapsed same-named symbols across files during an --update on an already-current graph. Run a full rebuild (/graphify .) to be safe, or pass force=True only if you have verified the reduction is legitimate.",
                    file=_sys.stderr,
                );
                return False;
            }
            del existing_nodes, new_node_list, existing_ids;
        }
    }

    node_community: any = _node_community_map(communities);
    _labels: dict[int, str] = {`int(k): v for (k, v) in (community_labels or {}).items()};
    try {
        data: any = json_graph.node_link_data(G, edges="links");
    } except TypeError {
        data = json_graph.node_link_data(G);
    }

    def _json_sort_key(item: dict) -> str {
        return json.dumps(item, ensure_ascii=False, sort_keys=True, separators=(",", ":"));
    }

    for `node in data["nodes"] {
        cid: any = node_community.get(`node["id"]);
        `node["community"] = cid;
        if cid is not None and _labels {
            `node["community_name"] = _labels.get(cid, f"Community {cid}");
        }
        `node["norm_label"] = _strip_diacritics(`node.get("label", "")).lower();
    }
    if original_links is not None {
        node_ids: any = {n["id"] for n in data["nodes"]};
        data["links"] = [
            `dict(link)
            for link in original_links
            if isinstance(link, `dict)
                and link.get("source") in node_ids
                and link.get("target") in node_ids
        ];
        if has_parallel_links(data["links"], directed=`bool(data.get("directed", True))) {
            data["multigraph"] = True;
        }
    }
    for link in data["links"] {
        if "confidence_score" not in link {
            conf: any = link.get("confidence", "EXTRACTED");
            link["confidence_score"] = _CONFIDENCE_SCORE_DEFAULTS.get(conf, 1.0);
        }
        true_src: any = link.pop("_src", None);
        true_tgt: any = link.pop("_tgt", None);
        if true_src is not None and true_tgt is not None {
            link["source"] = true_src;
            link["target"] = true_tgt;
        }
    }
    def _canonical(item: dict, lead: tuple[str, ...]) -> dict {
        leading: any;
        leading = [k for k in lead if k in item];
        rest: any = sorted(k for k in item if k not in leading);
        return {k: item[k] for k in (*leading, *rest)};
    }

    def _canonicalize_in_place(items: list, lead: tuple[str, ...]) {
        for (i, item) in enumerate(items) {
            items[i] = _canonical(item, lead);
        }
    }

    _canonicalize_in_place(data["nodes"], ("id", "label"));
    _canonicalize_in_place(data["links"], ("source", "target", "relation"));
    data["nodes"].sort(key=_json_sort_key);
    data["links"].sort(key=_json_sort_key);
    if "hyperedges" not in getattr(G, "graph", {}) {
        _prev_hyperedges: any = None;
        try {
            if existing_path.exists() {
                check_graph_file_size_cap: any = importlib.import_module(
                    "graphify.security"
                ).check_graph_file_size_cap;
                check_graph_file_size_cap(existing_path);
                _prev: any = json.loads(existing_path.read_text(encoding="utf-8"));
                if isinstance(_prev, `dict) {
                    _prev_hyperedges = _prev.get("hyperedges");
                }
                del _prev;
            }
        } except Exception {
            _prev_hyperedges = None;
        }
        if _prev_hyperedges {
            print(
                f"[graphify] WARNING: graph carries no hyperedge metadata but {existing_path} already holds {len(_prev_hyperedges)} hyperedge(s); writing an empty set. Rebuild from the original extraction if this is unexpected.",
                file=sys.stderr,
            );
        }
    }
    hyperedges: any = sorted(getattr(G, "graph", {}).get("hyperedges", []), key=_json_sort_key);
    if isinstance(data.get("graph"), `dict) and "hyperedges" in data["graph"] {
        data["graph"]["hyperedges"] = hyperedges;
    }
    data["hyperedges"] = hyperedges;
    graph_metadata: any = data.setdefault("graph", {});
    graph_metadata["schema_version"] = GRAPH_SCHEMA_VERSION;
    graphify_version: any = _graphify_version();
    if graphify_version is not None {
        graph_metadata["graphify_version"] = graphify_version;
    }
    commit: any = built_at_commit
        if built_at_commit is not None
        else _git_head(Path(output_path).resolve().parent);
    if commit {
        data["built_at_commit"] = commit;
    }
    write_json_atomic: any = importlib.import_module("graphify.paths").write_json_atomic;
    write_json_atomic(output_path, data, compact=True);
    return True;
}

impl prune_dangling_edges(graph_data: dict) -> tuple[dict, int] {
    node_ids: any = {n["id"] for n in graph_data["nodes"]};
    links_key: any = "links" if "links" in graph_data else "edges";
    before: any = len(graph_data[links_key]);
    graph_data[links_key] = [
        e
        for e in graph_data[links_key]
        if e["source"] in node_ids and e["target"] in node_ids
    ];
    return (graph_data, before - len(graph_data[links_key]));
}

impl _cypher_escape(s: str) -> str {
    s = "".join(ch for ch in s if ch >= " " or ch == "\t");
    return s.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n").replace("\r", "\\r");
}

impl _cypher_label(raw: str, fallback: str) -> str {
    cleaned: any = _CYPHER_IDENT_RE.sub("", raw or "");
    if not cleaned or not cleaned[0].isalpha() {
        return fallback;
    }
    return cleaned;
}

impl to_cypher(G: nx.Graph, output_path: str) {
    lines: any = ["// Neo4j Cypher import - generated by /graphify", ""];
    data: any;
    for (node_id, data) in G.nodes(data=True) {
        label: any = _cypher_escape(data.get("label", node_id));
        node_id_esc: any = _cypher_escape(node_id);
        ftype: any = _cypher_label(
            (data.get("file_type", "unknown") or "unknown").capitalize(), "Entity"
        );
        lines.append(f"MERGE (n:{ftype} {{id: '{node_id_esc}'}}) SET n.label = '{label}';");
    }
    lines.append("");
    u: any;
    v: any;
    for (u, v, data) in G.edges(data=True) {
        (u, v) = (data.get("_src", u), data.get("_tgt", v));
        rel: any = _cypher_label(
            (data.get("relation", "RELATES_TO") or "RELATES_TO").upper(), "RELATES_TO"
        );
        conf: any = _cypher_escape(data.get("confidence", "EXTRACTED"));
        u_esc: any = _cypher_escape(u);
        v_esc: any = _cypher_escape(v);
        lines.append(
            f"MATCH (a {{id: '{u_esc}'}}), (b {{id: '{v_esc}'}}) MERGE (a)-[:{rel} {{confidence: '{conf}'}}]->(b);",
        );
    }
    f: any;
    with open(output_path, "w", encoding="utf-8") as f {
        f.write("\n".join(lines));
    }
}

impl _strip_xml_illegal(s: str) -> str {
    return _XML_ILLEGAL_RE.sub("", s);
}

impl _cap_filename(s: str, limit: int = 200) -> str {
    b: any = s.encode("utf-8");
    if len(b) <= limit {
        return s;
    }
    digest: any = hashlib.sha1(s.encode("utf-8")).hexdigest()[:8];
    keep: any = limit - 9;
    truncated: any = b[:keep].decode("utf-8", "ignore");
    return f"{truncated}_{digest}";
}

impl _is_graphify_note(path: Path) -> bool {
    try {
        fh: any;
        with path.open("r", encoding="utf-8", errors="replace") as fh {
            head: any = fh.read(_NOTE_FRONTMATTER_PROBE_BYTES);
        }
    } except OSError {
        return False;
    }
    if path.name.startswith(_COMMUNITY_PREFIX) and _COMMUNITY_QUERY_MARKER in head {
        return True;
    }
    if not head.startswith("---") {
        return False;
    }
    for line in head.splitlines()[1:] {
        if line.strip() == "---" {
            return False;
        }
        if _GRAPHIFY_TAG_RE.match(line) {
            return True;
        }
    }
    return False;
}

impl _adopt_pre_manifest_notes(out: Path) -> set[str] {
    try {
        candidates: any = sorted(out.glob("*.md"));
    } except OSError {
        return set[any]();
    }
    return {p.name for p in candidates if _is_graphify_note(p)};
}

impl _obsidian_safe_stem(label: str, limit: int = 200) -> str {
    cleaned: any = re.sub(
        "[\\\\/*?:\"<>|#^[\\]]", "", _CONTROL_TO_SPACE_RE.sub(" ", label)
    ).strip();
    cleaned = re.sub("\\.(md|mdx|qmd|markdown)$", "", cleaned, flags=re.IGNORECASE);
    if cleaned.startswith(".") and re.search("\\w", cleaned.lstrip("."), flags=re.UNICODE) {
        cleaned = "dot-" + cleaned.lstrip(".");
    }
    if not re.search("\\w", cleaned, flags=re.UNICODE) {
        return "unnamed";
    }
    return _cap_filename(cleaned, limit);
}

impl _dedup_node_filenames(G: nx.Graph, safe_name) -> dict[str, str] {
    node_filenames: dict[str, str] = {};
    used: set[str] = set[any]();
    for (node_id, data) in G.nodes(data=True) {
        base: any = safe_name(data.get("label", node_id));
        candidate: any = base;
        n: any = 1;
        while candidate.lower() in used {
            candidate = f"{base}_{n}";
            n += 1;
        }
        used.add(candidate.lower());
        node_filenames[node_id] = candidate;
    }
    return node_filenames;
}

impl to_obsidian(
    G: nx.Graph,
    communities: dict[int, list[str]],
    output_dir: str,
    community_labels: dict[int, str] | None = None,
    cohesion: dict[int, float] | None = None,
) -> int {
    out: any;
    _owned: set[str];
    _written: list[str];
    _skipped: list[str];
    node_community: any;
    _stem_limit: any;
    out = Path(output_dir);
    out.mkdir(parents=True, exist_ok=True);
    _manifest_path: any = out / ".graphify_obsidian_manifest.json";
    try {
        _owned = `set(json.loads(_manifest_path.read_text(encoding="utf-8")).get("files", []));
        _manifest_existed: any = True;
    } except (OSError, ValueError) {
        _owned = set[any]();
        _manifest_existed = False;
    }
    if not _manifest_existed {
        _owned |= _adopt_pre_manifest_notes(out);
    }
    _written = [];
    _skipped = [];
    def _owned_write(rel_name: str, content: str) -> bool {
        target: any = out / rel_name;
        if target.exists() and rel_name not in _owned {
            _skipped.append(rel_name);
            return False;
        }
        target.parent.mkdir(parents=True, exist_ok=True);
        write_text_atomic_if_changed(target, content);
        _written.append(rel_name);
        return True;
    }

    node_community = _node_community_map(communities);
    _stem_limit = stem_filename_budget(out, reserve=_DEDUP_SUFFIX_RESERVE);
    node_filename: any = _dedup_node_filenames(
        G, lambda (label) -> any { _obsidian_safe_stem(label, _stem_limit) }
    );
    def _dominant_confidence(node_id: str) -> str {
        confs: any = [];
        for (u, v, edata) in G.edges(node_id, data=True) {
            confs.append(edata.get("confidence", "EXTRACTED"));
        }
        if not confs {
            return "EXTRACTED";
        }
        return Counter(confs).most_common(1)[0][0];
    }
    _FTYPE_TAG: any = {
        "code": "graphify/code",
        "document": "graphify/document",
        "paper": "graphify/paper",
        "image": "graphify/image",
    };
    node_notes_written: any = 0;
    node_id: any;
    data: any;
    for (node_id, data) in G.nodes(data=True) {
        label: any = data.get("label", node_id);
        cid: any = node_community.get(node_id);
        community_name: any = community_labels.get(cid, f"Community {cid}")
            if community_labels and cid is not None
            else f"Community {cid}";
        ftype: any = data.get("file_type", "");
        ftype_tag: any = _FTYPE_TAG.get(
            ftype, f"graphify/{_obsidian_tag(ftype)}" if ftype else "graphify/document"
        );
        dom_conf: any = _dominant_confidence(node_id);
        conf_tag: any = f"graphify/{_obsidian_tag(dom_conf)}";
        comm_tag: any = f"community/{_obsidian_tag(community_name)}";
        node_tags: any = [ftype_tag, conf_tag, comm_tag];

        lines: list[str] = [];
        lines += [
            "---",
            "source_file: \"" + format(_yaml_str(data.get("source_file", "")), "") + "\"",
            f"type: \"{_yaml_str(ftype)}\"",
            f"community: \"{_yaml_str(community_name)}\"",
        ];
        if data.get("source_location") {
            lines.append(
                "location: \"" + format(_yaml_str(`str(data["source_location"])), "") + "\""
            );
        }
        lines.append("tags:");
        for tag in node_tags {
            lines.append(f"  - {tag}");
        }
        lines += ["---", "", f"# {label}", ""];
        neighbors: any = `list(G.neighbors(node_id));
        if neighbors {
            lines.append("## Connections");
            for neighbor in sorted(
                neighbors, key=lambda (n) -> any { G.nodes[n].get("label", n) }
            ) {
                neighbor_label: any = node_filename[neighbor];
                for edata in sorted(
                    edge_datas(G, node_id, neighbor),
                    key=lambda (d) -> any {
                        (`str(d.get("relation", "")), `str(d.get("confidence", "EXTRACTED")))
                    },
                ) {
                    relation: any = edata.get("relation", "");
                    confidence: any = edata.get("confidence", "EXTRACTED");
                    lines.append(f"- [[{neighbor_label}]] - `{relation}` [{confidence}]");
                }
            }
            lines.append("");
        }
        inline_tags: any = " ".join(f"#{t}" for t in node_tags);
        lines.append(inline_tags);

        fname: any = node_filename[node_id] + ".md";
        if _owned_write(fname, "\n".join(lines)) {
            node_notes_written += 1;
        }
    }
    inter_community_edges: dict[int, dict[int, int]] = {};
    for cid in communities {
        inter_community_edges[cid] = {};
    }
    for (u, v) in G.edges() {
        cu: any = node_community.get(u);
        cv: any = node_community.get(v);
        if cu is not None and cv is not None and cu != cv {
            inter_community_edges.setdefault(cu, {});
            inter_community_edges.setdefault(cv, {});
            inter_community_edges[cu][cv] = inter_community_edges[cu].get(cv, 0) + 1;
            inter_community_edges[cv][cu] = inter_community_edges[cv].get(cu, 0) + 1;
        }
    }
    def _community_reach(node_id: str) -> int {
        neighbor_cids: any = {
            node_community[nb]
            for nb in G.neighbors(node_id)
            if nb in node_community and node_community[nb] != node_community.get(node_id)
        };
        return len(neighbor_cids);
    }

    def _community_name(cid) -> str {
        return community_labels.get(cid, f"Community {cid}")
            if community_labels and cid is not None
            else f"Community {cid}";
    }
    community_filename: dict = {};
    used_community: set[str] = set[any]();
    _community_stem_limit: any = stem_filename_budget(
        out, reserve=_DEDUP_SUFFIX_RESERVE + len(_COMMUNITY_PREFIX)
    );
    for cid in communities {
        base: any = f"{_COMMUNITY_PREFIX}{_obsidian_safe_stem(_community_name(cid), _community_stem_limit)}";
        candidate: any = base;
        n: any = 1;
        while candidate.lower() in used_community {
            candidate = f"{base}_{n}";
            n += 1;
        }
        used_community.add(candidate.lower());
        community_filename[cid] = candidate;
    }

    community_notes_written: any = 0;
    for (cid, all_members) in communities.items() {
        community_name = _community_name(cid);
        members: any = [m for m in all_members if m in G and m in node_filename];
        n_members: any = len(members);
        coh_value: any = cohesion.get(cid) if cohesion else None;

        lines = [];
        lines.append("---");
        lines.append("type: community");
        if coh_value is not None {
            lines.append(f"cohesion: {coh_value:.2f}");
        }
        lines.append(f"members: {n_members}");
        lines.append("---");
        lines.append("");
        lines.append(f"# {community_name}");
        lines.append("");
        if coh_value is not None {
            cohesion_desc: any = "tightly connected"
                if coh_value >= 0.7
                else "moderately connected" if coh_value >= 0.4 else "loosely connected";
            lines.append(f"**Cohesion:** {coh_value:.2f} - {cohesion_desc}");
        }
        lines.append(f"**Members:** {n_members} nodes");
        lines.append("");
        lines.append("## Members");
        for node_id in sorted(members, key=lambda (n) -> any { G.nodes[n].get("label", n) }) {
            data = G.nodes[node_id];
            node_label: any = node_filename[node_id];
            ftype = data.get("file_type", "");
            source: any = data.get("source_file", "");
            `entry: any = f"- [[{node_label}]]";
            if ftype {
                `entry += f" - {ftype}";
            }
            if source {
                `entry += f" - {source}";
            }
            lines.append(`entry);
        }
        lines.append("");
        comm_tag_name: any = _obsidian_tag(community_name);
        lines.append("## Live Query (requires Dataview plugin)");
        lines.append("");
        lines.append("```dataview");
        lines.append(f"TABLE source_file, type FROM #community/{comm_tag_name}");
        lines.append("SORT file.name ASC");
        lines.append("```");
        lines.append("");
        cross: any = inter_community_edges.get(cid, {});
        if cross {
            lines.append("## Connections to other communities");
            for (other_cid, edge_count) in sorted(cross.items(), key=lambda (x) -> any { -x[1] }) {
                other_fname: any = community_filename.get(other_cid)
                    or f"{_COMMUNITY_PREFIX}{_obsidian_safe_stem(_community_name(other_cid), _community_stem_limit)}";
                lines.append(
                    "- "
                        + format(edge_count, "")
                        + " edge"
                        + format("s" if edge_count != 1 else "", "")
                        + " to [["
                        + format(other_fname, "")
                        + "]]",
                );
            }
            lines.append("");
        }
        bridge_nodes: any = [
            (node_id, G.degree(node_id), _community_reach(node_id))
            for node_id in members
            if _community_reach(node_id) > 0
        ];
        bridge_nodes.sort(key=lambda (x) -> any { (-x[2], -x[1]) });
        top_bridges: any = bridge_nodes[:5];
        if top_bridges {
            lines.append("## Top bridge nodes");
            for (node_id, degree, reach) in top_bridges {
                node_label = node_filename[node_id];
                lines.append(
                    "- [["
                        + format(node_label, "")
                        + "]] - degree "
                        + format(degree, "")
                        + ", connects to "
                        + format(reach, "")
                        + " "
                        + format("community" if reach == 1 else "communities", ""),
                );
            }
        }

        fname = community_filename[cid] + ".md";
        if _owned_write(fname, "\n".join(lines)) {
            community_notes_written += 1;
        }
    }
    graph_config: any = {
        "colorGroups": [
            {
                "query": f"tag:#community/{_obsidian_tag(label)}",
                "color": {
                    "a": 1,
                    "rgb": `int(COMMUNITY_COLORS[cid % len(COMMUNITY_COLORS)].lstrip("#"), 16),
                },
            }
            for (cid, label) in sorted((community_labels or {}).items())
        ],
    };
    _owned_write(".obsidian/graph.json", json.dumps(graph_config, indent=2));
    stale: any = _owned - `set(_written) - `set(_skipped);
    pruned: any = 0;
    for rel_name in sorted(stale) {
        target: any = (out / rel_name).resolve();
        if out.resolve() not in target.parents {
            continue;
        }
        try {
            target.unlink(missing_ok=True);
            pruned += 1;
        } except OSError {}
    }
    if pruned {
        print(
            f"[graphify] pruned {pruned} note(s) for nodes no longer in the graph", file=sys.stderr
        );
    }
    try {
        _manifest_path.write_text(
            json.dumps({"files": sorted(`set(_written))}, indent=2), encoding="utf-8"
        );
    } except OSError {}
    if _skipped {
        shown: any = ", ".join(_skipped[:5])
            + (f" (+{len(_skipped) - 5} more)" if len(_skipped) > 5 else "");
        print(
            f"[graphify] WARNING: skipped {len(_skipped)} pre-existing file(s) graphify did not create, to avoid overwriting your notes: {shown}. Export into an empty directory (or the default graphify-out/obsidian) to get the full vault.",
            file=sys.stderr,
        );
    }

    return node_notes_written + community_notes_written;
}

impl to_canvas(
    G: nx.Graph,
    communities: dict[int, list[str]],
    output_path: str,
    community_labels: dict[int, str] | None = None,
    node_filenames: dict[str, str] | None = None,
) {
    _stem_limit: any;
    n: any;
    CANVAS_COLORS: any = ["1", "2", "3", "4", "5", "6"];
    _stem_limit = stem_filename_budget(Path(output_path).parent, reserve=_DEDUP_SUFFIX_RESERVE);
    if node_filenames is None {
        node_filenames = _dedup_node_filenames(
            G, lambda (label) -> any { _obsidian_safe_stem(label, _stem_limit) }
        );
    }
    if not communities and G.number_of_nodes() > 0 {
        communities = {0: [`str(n) for n in G.nodes()]};
    }

    num_communities: any = len(communities);
    cols: any = math.ceil(math.sqrt(num_communities)) if num_communities > 0 else 1;
    rows: any = math.ceil(num_communities / cols) if num_communities > 0 else 1;

    canvas_nodes: list[dict] = [];
    canvas_edges: list[dict] = [];
    gap: any = 80;
    group_x_offsets: list[int] = [];
    group_y_offsets: list[int] = [];
    sorted_cids: any = sorted(communities.keys());
    group_sizes: dict[int, tuple[int, int]] = {};
    group_cols: dict[int, int] = {};
    cid: any;
    for cid in sorted_cids {
        members: any = [m for m in communities[cid] if m in G and m in node_filenames];
        n = len(members);
        inner_cols: any = max(1, math.ceil(math.sqrt(n)));
        w: any = max(600, 220 * inner_cols);
        h: any = max(400, 100 * math.ceil(n / inner_cols) + 120);
        group_sizes[cid] = (w, h);
        group_cols[cid] = inner_cols;
    }
    col_widths: list[int] = [];
    row_heights: list[int] = [];
    col_idx: any;
    for col_idx in range(cols) {
        max_w: any = 0;
        row_idx: any;
        for row_idx in range(rows) {
            linear: any = row_idx * cols + col_idx;
            if linear < len(sorted_cids) {
                cid = sorted_cids[linear];
                _: any;
                (w, _) = group_sizes[cid] as any;
                max_w = max(max_w, w);
            }
        }
        col_widths.append(max_w);
    }

    for row_idx in range(rows) {
        max_h: any = 0;
        for col_idx in range(cols) {
            linear = row_idx * cols + col_idx;
            if linear < len(sorted_cids) {
                cid = sorted_cids[linear];
                (_, h) = group_sizes[cid] as any;
                max_h = max(max_h, h);
            }
        }
        row_heights.append(max_h);
    }
    group_layout: dict[int, tuple[int, int, int, int]] = {};
    idx: any;
    for (idx, cid) in enumerate(sorted_cids) {
        col_idx = idx % cols;
        row_idx = idx // cols;
        gx: any = sum(col_widths[:col_idx]) + col_idx * gap;
        gy: any = sum(row_heights[:row_idx]) + row_idx * gap;
        gw: any;
        gh: any;
        (gw, gh) = group_sizes[cid] as any;
        group_layout[cid] = (gx, gy, gw, gh);
    }
    all_canvas_nodes: set[str] = set[any]();
    for members in communities.values() {
        all_canvas_nodes.update(members);
    }
    for (idx, cid) in enumerate(sorted_cids) {
        members = communities[cid];
        community_name: any = community_labels.get(cid, f"Community {cid}")
            if community_labels and cid is not None
            else f"Community {cid}";
        (gx, gy, gw, gh) = group_layout[cid] as any;
        canvas_color: any = CANVAS_COLORS[idx % len(CANVAS_COLORS)];
        canvas_nodes.append({
            "id": f"g{cid}",
            "type": "group",
            "label": community_name,
            "x": gx,
            "y": gy,
            "width": gw,
            "height": gh,
            "color": canvas_color,
        });
        inner_cols = group_cols[cid];
        members = [m for m in members if m in G and m in node_filenames];
        sorted_members: any = sorted(members, key=lambda (n) -> any { G.nodes[n].get("label", n) });
        for (m_idx, node_id) in enumerate(sorted_members) {
            col: any = m_idx % inner_cols;
            row: any = m_idx // inner_cols;
            nx_x: any = gx + 20 + col * (180 + 20);
            nx_y: any = gy + 80 + row * (60 + 20);
            fname: any = node_filenames.get(
                node_id, _obsidian_safe_stem(G.nodes[node_id].get("label", node_id), _stem_limit)
            );
            canvas_nodes.append({
                "id": f"n_{node_id}",
                "type": "file",
                "file": f"{fname}.md",
                "x": nx_x,
                "y": nx_y,
                "width": 180,
                "height": 60,
            });
        }
    }
    all_edges_weighted: list[tuple[float, str, str, str]] = [];
    u: any;
    v: any;
    for (u, v, edata) in G.edges(data=True) {
        (u, v) = (edata.get("_src", u), edata.get("_tgt", v));
        if u in all_canvas_nodes and v in all_canvas_nodes {
            weight: any = edata.get("weight", 1.0);
            relation: any = edata.get("relation", "");
            conf: any = edata.get("confidence", "EXTRACTED");
            label: any = f"{relation} [{conf}]" if relation else f"[{conf}]";
            all_edges_weighted.append((weight, u, v, label));
        }
    }

    all_edges_weighted.sort(key=lambda (x) -> any { -x[0] });
    for (weight, u, v, label) in all_edges_weighted[:200] {
        canvas_edges.append({
            "id": f"e_{u}_{v}",
            "fromNode": f"n_{u}",
            "toNode": f"n_{v}",
            "label": label,
        });
    }

    canvas_data: any = {"nodes": canvas_nodes, "edges": canvas_edges};
    write_json_atomic(output_path, canvas_data, indent=2);
}

impl to_graphml(G: nx.Graph, communities: dict[int, list[str]], output_path: str) {
    H: any = G.copy();
    node_community: any = _node_community_map(communities);
    node_id: any;
    for node_id in H.nodes() {
        H.nodes[node_id]["community"] = node_community.get(node_id, -1);
    }
    _: any;
    attrs: any;
    for (_, attrs) in H.nodes(data=True) {
        k: any;
        for k in [k for k in attrs if k.startswith("_")] {
            del attrs[k];
        }
    }
    for (_, _, attrs) in H.edges(data=True) {
        for k in [k for k in attrs if k.startswith("_")] {
            del attrs[k];
        }
    }
    def _graphml_safe(val) -> any {
        if val is None {
            return "";
        }
        if isinstance(val, `bool) or isinstance(val, (`int, `float)) {
            return val;
        }
        if isinstance(val, `str) {
            return _strip_xml_illegal(val);
        }
        try {
            return _strip_xml_illegal(json.dumps(val, default=str, sort_keys=True));
        } except (TypeError, ValueError) {
            return _strip_xml_illegal(`str(val));
        }
    }
    _id_remap: any = {n: _strip_xml_illegal(n) for n in H.nodes if isinstance(n, `str)};
    _id_remap = {k: v for (k, v) in _id_remap.items() if k != v};
    if _id_remap {
        H = nx.relabel_nodes(H, _id_remap, copy=True);
    }

    key: any;
    val: any;
    for (key, val) in `list(H.graph.items()) {
        H.graph[key] = _graphml_safe(val);
    }
    for node_id in H.nodes() {
        for (key, val) in `list(H.nodes[node_id].items()) {
            H.nodes[node_id][key] = _graphml_safe(val);
        }
    }
    for attrs_ in H.edges(data=True) {
        items_: any = list(attrs_);
        if len(items_) < 1 {
            raise ValueError(
                f"not enough values to unpack (expected at least 1, got {len(items_)})"
            );
        }
        _ = items_[0:len(items_) - 1];
        attrs = items_[len(items_) - 1];
        for (key, val) in `list(attrs.items()) {
            attrs[key] = _graphml_safe(val);
        }
    }
    out: any = Path(output_path);
    tmp: any = out.with_name(out.name + ".tmp");
    try {
        nx.write_graphml(H, `str(tmp));
        os_replace_with_fallback(`str(tmp), `str(out));
    } finally {
        if tmp.exists() {
            try {
                tmp.unlink();
            } except OSError {}
        }
    }
}

impl to_svg(
    G: nx.Graph,
    communities: dict[int, list[str]],
    output_path: str,
    community_labels: dict[int, str] | None = None,
    figsize: tuple[int, int] = (20, 14),
) {
    try {
        import matplotlib;
        matplotlib.use("Agg");
        import matplotlib.pyplot as plt;
        import matplotlib.patches as mpatches;
    } except ImportError as e {
        raise ImportError("matplotlib not installed. Run: pip install matplotlib") from e;
    }

    node_community: any = _node_community_map(communities);

    fig: any;
    ax: any;
    (fig, ax) = plt.subplots(figsize=figsize, facecolor="#1a1a2e") as any;
    ax.set_facecolor("#1a1a2e");
    ax.axis("off");

    pos: any = nx.spring_layout(G, seed=42, k=2.0 / (G.number_of_nodes() ** 0.5 + 1));

    degree: any = `dict(G.degree());
    max_deg: any = max(degree.values(), default=1) or 1;

    node_colors: any = [
        COMMUNITY_COLORS[node_community.get(n, 0) % len(COMMUNITY_COLORS)]
        for n in G.nodes()
    ];
    node_sizes: any = [300 + 1200 * (degree.get(n, 1) / max_deg) for n in G.nodes()];
    for (u, v, data) in G.edges(data=True) {
        conf: any = data.get("confidence", "EXTRACTED");
        style: any = "solid" if conf == "EXTRACTED" else "dashed";
        alpha: any = 0.6 if conf == "EXTRACTED" else 0.3;
        x0: any;
        y0: any;
        (x0, y0) = pos[u] as any;
        x1: any;
        y1: any;
        (x1, y1) = pos[v] as any;
        ax.plot(
            [x0, x1],
            [y0, y1],
            color="#aaaaaa",
            linewidth=0.8,
            linestyle=style,
            alpha=alpha,
            zorder=1,
        );
    }

    nx.draw_networkx_nodes(G, pos, ax=ax, node_color=node_colors, node_size=node_sizes, alpha=0.9);
    nx.draw_networkx_labels(
        G,
        pos,
        ax=ax,
        labels={n: _strip_xml_illegal(`str(G.nodes[n].get("label", n))) for n in G.nodes()},
        font_size=7,
        font_color="white",
    );
    if community_labels {
        patches: any = [
            mpatches.Patch(
                color=COMMUNITY_COLORS[cid % len(COMMUNITY_COLORS)],
                label=_strip_xml_illegal(f"{label} ({len(communities.get(cid, []))})"),
            )
            for (cid, label) in sorted(community_labels.items())
        ];
        ax.legend(
            handles=patches,
            loc="upper left",
            framealpha=0.7,
            facecolor="#2a2a4e",
            labelcolor="white",
            fontsize=8,
        );
    }

    plt.tight_layout();
    plt.savefig(output_path, format="svg", bbox_inches="tight", facecolor=fig.get_facecolor());
    plt.close(fig);
}
