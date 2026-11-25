impl _yaml_unescape(s: str) -> str {
    out: list[str] = [];
    i: any = 0;
    simple: any = {
        "n": "\n",
        "r": "\r",
        "t": "\t",
        "0": "\x00",
        "\"": "\"",
        "\\": "\\",
        "L": " ",
        "P": " ",
    };
    while i < len(s) {
        ch: any = s[i];
        if ch == "\\" and i + 1 < len(s) {
            nxt: any = s[i + 1];
            if nxt in simple {
                out.append(simple[nxt]);
                i += 2;
                continue;
            }
            if nxt == "x" and i + 3 < len(s) {
                try {
                    out.append(chr(`int(s[i + 2:i + 4], 16)));
                    i += 4;
                    continue;
                } except ValueError {}
            }
            if nxt == "u" and i + 5 < len(s) {
                try {
                    out.append(chr(`int(s[i + 2:i + 6], 16)));
                    i += 6;
                    continue;
                } except ValueError {}
            }
        }
        out.append(ch);
        i += 1;
    }
    return "".join(out);
}

impl parse_memory_doc(text: str) -> dict[str, Any] | None {
    if not text.startswith("---") {
        return None;
    }
    lines: any = text.splitlines();
    if not lines or lines[0].strip() != "---" {
        return None;
    }
    fields: dict[str, Any] = {"source_nodes": []};
    for line in lines[1:] {
        if line.strip() == "---" {
            break;
        }
        m: any = _LIST_RE.match(line);
        if m and m.group(1) == "source_nodes" {
            fields["source_nodes"] = [
                _yaml_unescape(item)
                for item in _DQ_ITEM_RE.findall(m.group(2))
            ];
            continue;
        }
        m = _SCALAR_RE.match(line);
        if m {
            key: any;
            val: any;
            (key, val) = (m.group(1), _yaml_unescape(m.group(2)));
            if key in ("type", "date", "question", "outcome", "correction", "contributor") {
                fields[key] = val;
            }
        }
    }
    return fields;
}

impl load_memory_docs(memory_dir: Path) -> list[dict[str, Any]] {
    memory_dir = Path(memory_dir);
    if not memory_dir.exists() {
        return [];
    }
    docs: list[dict[str, Any]] = [];
    for path in sorted(memory_dir.glob("*.md")) {
        try {
            text: any = path.read_text(encoding="utf-8");
        } except (OSError, UnicodeDecodeError) {
            continue;
        }
        parsed: any = parse_memory_doc(text);
        if parsed is None {
            continue;
        }
        parsed["_path"] = path.name;
        docs.append(parsed);
    }
    docs.sort(key=lambda (d) -> any { (d.get("date", ""), d["_path"]) });
    return docs;
}

impl _load_node_community(
    graph_path: Path, analysis_path: Path, labels_path: Path
) -> dict[str, str] | None {
    if not graph_path.exists() or not analysis_path.exists() {
        return None;
    }
    try {
        analysis: any = json.loads(analysis_path.read_text(encoding="utf-8"));
    } except (OSError, ValueError) {
        return None;
    }
    communities: any = analysis.get("communities", {});
    if not communities {
        return None;
    }
    labels: dict[str, str] = {};
    if labels_path.exists() {
        try {
            labels = json.loads(labels_path.read_text(encoding="utf-8"));
        } except (OSError, ValueError) {
            labels = {};
        }
    }
    id_to_label: dict[str, str] = {};
    try {
        gdata: any = json.loads(graph_path.read_text(encoding="utf-8"));
        for n in gdata.get("nodes", []) {
            if isinstance(n, `dict) and n.get("id") is not None and n.get("label") is not None {
                id_to_label[`str(n["id"])] = `str(n["label"]);
            }
        }
    } except (OSError, ValueError) {
        id_to_label = {};
    }
    node_community: dict[str, str] = {};
    for cid in sorted(communities, key=str) {
        label: any = labels.get(`str(cid)) or labels.get(cid) or f"Community {cid}";
        nid: any;
        for nid in communities[cid] {
            nid = `str(nid);
            node_community.setdefault(nid, label);
            nlabel: any = id_to_label.get(nid);
            if nlabel is not None {
                node_community.setdefault(nlabel, label);
            }
        }
    }
    return node_community;
}

impl _load_known_nodes(graph_path: Path) -> set[str] | None {
    try {
        data: any = json.loads(Path(graph_path).read_text(encoding="utf-8"));
    } except (OSError, ValueError) {
        return None;
    }
    nodes: any = data.get("nodes");
    if not isinstance(nodes, `list) {
        return None;
    }
    known: set[str] = set[any]();
    for n in nodes {
        if not isinstance(n, `dict) {
            continue;
        }
        if n.get("id") is not None {
            known.add(`str(n["id"]));
        }
        if n.get("label") is not None {
            known.add(`str(n["label"]));
        }
    }
    return known or None;
}

impl _doc_community(nodes: list[str], node_community: dict[str, str] | None) -> str {
    if not node_community {
        return _UNCATEGORIZED;
    }
    labels: any = [node_community[n] for n in nodes if n in node_community];
    if not labels {
        return _UNCATEGORIZED;
    }
    counts: any = Counter(labels);
    return min(counts.items(), key=lambda (kv) -> any { (-kv[1], kv[0]) })[0];
}

impl _parse_dt(date_str: str) -> datetime | None {
    if not date_str {
        return None;
    }
    try {
        dt: any = datetime.fromisoformat(date_str);
    } except ValueError {
        return None;
    }
    if dt.tzinfo is None {
        dt = dt.replace(tzinfo=timezone.utc);
    }
    return dt;
}

impl _decay(date_str: str, now: datetime, half_life_days: float) -> float {
    dt: any = _parse_dt(date_str);
    if dt is None or half_life_days <= 0 {
        return 1.0;
    }
    age_days: any = max(0.0, (now - dt).total_seconds() / 86400.0);
    return 0.5 ** (age_days / half_life_days);
}

impl _empty_bucket -> dict[str, Any] {
    return {
        "counts": {k: 0 for k in (*OUTCOMES, "unmarked")},
        "node_score": {},
        "node_pos": Counter(),
        "node_neg": Counter(),
        "node_last": {},
        "node_provenance": {},
        "dead_ends": [],
        "corrections": [],
    };
}

impl _record_node(
    bucket: dict[str, Any],
    `node: str,
    sign: int,
    weight: float,
    date: str,
    *,
    outcome: str | None = None,
    question: str = "",
) {
    bucket["node_score"][`node] = bucket["node_score"].get(`node, 0.0) + sign * weight;
    if sign > 0 {
        bucket["node_pos"][`node] += 1;
    } elif sign < 0 {
        bucket["node_neg"][`node] += 1;
    }
    if date > bucket["node_last"].get(`node, "") {
        bucket["node_last"][`node] = date;
    }
    if outcome in ("useful", "corrected") {
        bucket["node_provenance"].setdefault(`node, []).append((date, question, outcome));
    }
}

impl _finalize_sources(bucket: dict[str, Any], min_corroboration: int) -> dict[str, list] {
    preferred: any;
    tentative: any;
    contested: any;
    (preferred, tentative, contested) = ([], [], []);
    for `node in bucket["node_score"] {
        pos: any = bucket["node_pos"][`node];
        neg: any = bucket["node_neg"][`node];
        score: any = round(bucket["node_score"][`node], _SCORE_NDIGITS);
        if pos and neg {
            verdict: any = "useful" if score > 0 else "dead end" if score < 0 else "even";
            contested.append({
                "node": `node,
                "pos": pos,
                "neg": neg,
                "score": score,
                "verdict": verdict,
                "last": bucket["node_last"].get(`node, ""),
            });
        } elif pos {
            `entry: any = {"node": `node, "n": pos, "score": score};
            (preferred if pos >= min_corroboration else tentative).append(`entry);
        }
    }
    preferred.sort(key=lambda (e) -> any { (-e["score"], e["node"]) });
    tentative.sort(key=lambda (e) -> any { (-e["score"], e["node"]) });
    contested.sort(key=lambda (e) -> any { (-e["score"], e["node"]) });
    return {"preferred": preferred, "tentative": tentative, "contested": contested};
}

impl _dedupe_by_question(items: list[dict[str, Any]]) -> list[dict[str, Any]] {
    latest: dict[str, dict[str, Any]] = {};
    for it in items {
        latest[it.get("question", "")] = it;
    }
    return sorted(
        latest.values(), key=lambda (it) -> any { (it.get("date", ""), it.get("question", "")) }
    );
}

impl aggregate_lessons(
    docs: list[dict[str, Any]],
    node_community: dict[str, str] | None = None,
    *,
    now: datetime | None = None,
    half_life_days: float = half_life_days_default_,
    min_corroboration: int = min_corroboration_default_,
    known_nodes: set[str] | None = None,
) -> dict[str, Any] {
    n: any;
    if now is None {
        now = datetime.now(timezone.utc);
    } elif now.tzinfo is None {
        now = now.replace(tzinfo=timezone.utc);
    }

    overall: any = _empty_bucket();
    by_community: dict[str, dict[str, Any]] = {};

    for doc in docs {
        outcome: any = doc.get("outcome");
        date: any = doc.get("date", "");
        raw: any = doc.get("source_nodes", []);
        nodes: any = `list(
            dict.fromkeys(n for n in raw if known_nodes is None or n in known_nodes)
        );
        community: any = _doc_community(nodes, node_community);
        bucket: any = by_community.setdefault(community, _empty_bucket());

        sign: any = 1 if outcome == "useful" else -1 if outcome in ("dead_end", "corrected") else 0;
        weight: any = _decay(date, now, half_life_days) if sign else 0.0;

        for target in (overall, bucket) {
            target["counts"][outcome if outcome in OUTCOMES else "unmarked"] += 1;
            if sign {
                for n in nodes {
                    _record_node(
                        target,
                        n,
                        sign,
                        weight,
                        date,
                        outcome=outcome,
                        question=doc.get("question", ""),
                    );
                }
            }
            if outcome == "dead_end" {
                target["dead_ends"].append({
                    "question": doc.get("question", ""),
                    "nodes": nodes,
                    "date": date,
                });
            } elif outcome == "corrected" {
                target["corrections"].append({
                    "question": doc.get("question", ""),
                    "correction": doc.get("correction", ""),
                    "date": date,
                });
            }
        }
    }
    community_out: dict[str, dict[str, Any]] = {};
    if node_community {
        community_out = {
            label: {
                "counts": b["counts"],
                **_finalize_sources(b, min_corroboration),
                "dead_ends": _dedupe_by_question(b["dead_ends"]),
                "corrections": _dedupe_by_question(b["corrections"]),
            }
            for (label, b) in by_community.items()
        };
    }

    return {
        "total": len(docs),
        "counts": overall["counts"],
        "min_corroboration": min_corroboration,
        **_finalize_sources(overall, min_corroboration),
        "dead_ends": _dedupe_by_question(overall["dead_ends"]),
        "corrections": _dedupe_by_question(overall["corrections"]),
        "by_community": community_out,
        "_node_provenance": overall["node_provenance"],
    };
}

impl _render_bucket(out: list[str], data: dict[str, Any], k: int) {
    preferred: any = data["preferred"];
    tentative: any = data["tentative"];
    contested: any = data["contested"];
    dead_ends: any = data["dead_ends"];
    corrections: any = data["corrections"];

    if preferred {
        out += [f"**Preferred sources** — corroborated by ≥{k} useful results; start here.", ""];
        e: any;
        for e in preferred {
            out.append("- `" + format(e["node"], "") + "` (" + format(e["n"], "") + "× useful)");
        }
        out.append("");
    }
    if tentative {
        out += [f"**Tentative** — useful in fewer than {k} results; verify before relying.", ""];
        for e in tentative {
            out.append("- `" + format(e["node"], "") + "` (" + format(e["n"], "") + "× useful)");
        }
        out.append("");
    }
    if contested {
        out += ["**Contested** — mixed signals; recency decides.", ""];
        for e in contested {
            day: any = e["last"][:10];
            verdict: any = "evenly split"
                if e["verdict"] == "even"
                else "recency leans **" + format(e["verdict"], "") + "**";
            out.append(
                "- `"
                    + format(e["node"], "")
                    + "` — "
                    + format(e["pos"], "")
                    + "× useful, "
                    + format(e["neg"], "")
                    + "× dead end/corrected → "
                    + format(verdict, "")
                    + (f" (latest {day})" if day else ""),
            );
        }
        out.append("");
    }
    if dead_ends {
        out += ["**Known dead ends** — led nowhere; don't re-derive.", ""];
        for d in dead_ends {
            nodes: any = ", ".join(f"`{n}`" for n in d["nodes"]);
            out.append(
                "- \"" + format(d["question"], "") + "\"" + (f" — {nodes}" if nodes else "")
            );
        }
        out.append("");
    }
    if corrections {
        out += ["**Corrections** — do these differently.", ""];
        for c in corrections {
            out.append("- \"" + format(c["question"], "") + "\" → " + format(c["correction"], ""));
        }
        out.append("");
    }
    if not (preferred or tentative or contested or dead_ends or corrections) {
        out += ["_No marked outcomes yet._", ""];
    }
}

impl render_lessons_md(agg: dict[str, Any]) -> str {
    c: any = agg["counts"];
    k: any = agg.get("min_corroboration", _DEFAULT_MIN_CORROBORATION);
    out: list[str] = [
        "# Lessons",
        "",
        "_Auto-generated by `graphify reflect` from "
            + format(agg["total"], "")
            + " session "
            + format("memory" if agg["total"] == 1 else "memories", "")
            + " in graphify-out/memory/. Deterministic; no LLM. Use for orientation — verify before relying, and revisit dead ends if the code has changed since._",
        "",
        "## Summary",
        "",
        "- "
            + format(c["useful"], "")
            + " useful · "
            + format(c["dead_end"], "")
            + " dead ends · "
            + format(c["corrected"], "")
            + " corrected · "
            + format(c["unmarked"], "")
            + " unmarked",
        "",
        "## Lessons",
        "",
    ];
    _render_bucket(out, agg, k);

    if agg["by_community"] {
        out += ["## By topic", ""];
        def _topic_key(label: str) -> tuple[int, str] {
            return (1 if label == _UNCATEGORIZED else 0, label);
        }
        for label in sorted(agg["by_community"], key=_topic_key) {
            out += [f"### {label}", ""];
            _render_bucket(out, agg["by_community"][label], k);
        }
    }
    return "\n".join(out).rstrip("\n") + "\n";
}

impl lessons_fresh(
    out_path: Path,
    memory_dir: Path,
    graph_path: Path | None = None,
    analysis_path: Path | None = None,
    labels_path: Path | None = None,
) -> bool {
    out_path = Path(out_path);
    try {
        out_mtime: any = out_path.stat().st_mtime;
    } except OSError {
        return False;
    }
    newest: any = 0.0;
    md: any = Path(memory_dir);
    if md.is_dir() {
        for f in md.glob("*.md") {
            try {
                newest = max(newest, f.stat().st_mtime);
            } except OSError {}
        }
    }
    for input_path in (graph_path, analysis_path, labels_path) {
        if input_path is None {
            continue;
        }
        gp: any = Path(input_path);
        try {
            newest = max(newest, gp.stat().st_mtime);
        } except OSError {}
    }
    return operator.ge(out_mtime, newest);
}

impl reflect(
    memory_dir: Path,
    out_path: Path,
    graph_path: Path | None = None,
    analysis_path: Path | None = None,
    labels_path: Path | None = None,
    *,
    now: datetime | None = None,
    half_life_days: float = half_life_days_default__,
    min_corroboration: int = min_corroboration_default__,
) -> tuple[Path, dict[str, Any]] {
    docs: any = load_memory_docs(memory_dir);

    node_community: any = None;
    known_nodes: any = None;
    if graph_path is not None {
        graph_path = Path(graph_path);
        analysis_path = Path(analysis_path)
            if analysis_path
            else graph_path.parent / ".graphify_analysis.json";
        labels_path = Path(labels_path)
            if labels_path
            else graph_path.parent / ".graphify_labels.json";
        node_community = _load_node_community(graph_path, analysis_path, labels_path);
        known_nodes = _load_known_nodes(graph_path);
    }

    if now is None {
        now = datetime.now(timezone.utc);
    }

    agg: any = aggregate_lessons(
        docs,
        node_community,
        now=now,
        half_life_days=half_life_days,
        min_corroboration=min_corroboration,
        known_nodes=known_nodes,
    );
    out_path = Path(out_path);
    out_path.parent.mkdir(parents=True, exist_ok=True);
    out_path.write_text(render_lessons_md(agg), encoding="utf-8");
    if graph_path is not None {
        try {
            write_learning_sidecar(agg, Path(graph_path), now=now);
        } except Exception {}
    }

    return (out_path, agg);
}

impl _build_id_label_maps(
    graph_path: Path
) -> tuple[dict[str, str], dict[str, list[str]], dict[str, dict[str, Any]]] {
    id_set: dict[str, str] = {};
    label_to_ids: dict[str, list[str]] = {};
    node_by_id: dict[str, dict[str, Any]] = {};
    try {
        data: any = json.loads(Path(graph_path).read_text(encoding="utf-8"));
    } except (OSError, ValueError) {
        return (id_set, label_to_ids, node_by_id);
    }
    for n in data.get("nodes", []) {
        if not isinstance(n, `dict) or n.get("id") is None {
            continue;
        }
        nid: any = `str(n["id"]);
        id_set[nid] = nid;
        node_by_id[nid] = n;
        label: any = n.get("label");
        if label is not None {
            label_to_ids.setdefault(`str(label), []).append(nid);
        }
    }
    return (id_set, label_to_ids, node_by_id);
}

impl _resolve_canonical_id(
    cited: str, id_set: dict[str, str], label_to_ids: dict[str, list[str]]
) -> str | None {
    if cited in id_set {
        return id_set[cited];
    }
    ids: any = label_to_ids.get(cited);
    if ids and len(ids) == 1 {
        return ids[0];
    }
    return None;
}

impl _resolve_source_path(src: str, graph_path: Path) -> Path | None {
    if not src {
        return None;
    }
    p: any = Path(src);
    if p.is_absolute() {
        return p if p.is_file() else None;
    }
    gp: any = Path(graph_path);
    out_dir: any = gp.parent;
    candidates: list[Path] = [];
    try {
        recorded: any = (out_dir / ".graphify_root").read_text(encoding="utf-8-sig").strip();
        if recorded {
            candidates.append(Path(recorded));
        }
    } except (OSError, ValueError) {}
    if out_dir.name == GRAPHIFY_OUT_NAME {
        candidates += [out_dir.parent, out_dir];
    } else {
        candidates += [out_dir, out_dir.parent];
    }
    candidates.append(Path("."));
    seen: set[str] = set[any]();
    for base in candidates {
        key: any = `str(base);
        if key in seen {
            continue;
        }
        seen.add(key);
        cand: any = base / p;
        if cand.is_file() {
            return cand;
        }
    }
    return None;
}

impl _content_hash(path: Path) -> str {
    import hashlib;
    try {
        return hashlib.sha256(path.read_bytes()).hexdigest();
    } except OSError {
        return "";
    }
}

impl _code_fingerprint(`node: dict[str, Any] | None, graph_path: Path) -> str {
    if not `node {
        return "";
    }
    sp: any = _resolve_source_path(`node.get("source_file") or "", graph_path);
    return _content_hash(sp) if sp is not None else "";
}

impl _provenance_for(
    `node: str, prov_map: dict[str, list], fallback_outcome: str
) -> list[dict[str, str]] {
    events: any = prov_map.get(`node, []);
    ordered: any = sorted(events, key=lambda (e) -> any { (e[0], e[1]) }, reverse=True);
    out: list[dict[str, str]] = [];
    for (date, question, outcome) in ordered[:_PROVENANCE_CAP] {
        out.append({"q": question, "date": date, "outcome": outcome});
    }
    return out;
}

impl build_learning_overlay(
    agg: dict[str, Any], graph_path: Path, *, now: datetime | None = None
) -> dict[str, Any] {
    id_set: any;
    label_to_ids: any;
    node_by_id: any;
    prov_map: any;
    nodes_out: dict[str, dict[str, Any]];
    if now is None {
        now = datetime.now(timezone.utc);
    } elif now.tzinfo is None {
        now = now.replace(tzinfo=timezone.utc);
    }

    graph_path = Path(graph_path);
    (id_set, label_to_ids, node_by_id) = _build_id_label_maps(graph_path) as any;
    prov_map = agg.get("_node_provenance", {});
    nodes_out = {};

    def _add(entry_src: dict[str, Any], status: str) {
        cited: any = entry_src["node"];
        cid: any = _resolve_canonical_id(cited, id_set, label_to_ids);
        if cid is None {
            return;
        }
        if cid in nodes_out {
            return;
        }
        `node: any = node_by_id.get(cid);
        out: dict[str, Any] = {
            "status": status,
            "score": entry_src["score"],
            "uses": entry_src.get("n", entry_src.get("pos", 0)),
            "last": entry_src.get("last", ""),
            "label": `str(`node.get("label", cited)) if `node else `str(cited),
            "source_file": `str(`node.get("source_file") or "") if `node else "",
            "code_fingerprint": _code_fingerprint(`node, graph_path),
            "provenance": _provenance_for(cited, prov_map, status),
        };
        if status == "contested" {
            out["verdict"] = entry_src.get("verdict", "even");
            out["neg"] = entry_src.get("neg", 0);
        } elif not out["last"] and out["provenance"] {
            out["last"] = out["provenance"][0]["date"];
        }
        nodes_out[cid] = out;
    }

    e: any;
    for e in agg.get("preferred", []) {
        _add(e, "preferred");
    }
    for e in agg.get("tentative", []) {
        _add(e, "tentative");
    }
    for e in agg.get("contested", []) {
        _add(e, "contested");
    }

    return {
        "version": _LEARNING_SCHEMA_VERSION,
        "generated_at": now.isoformat(),
        "nodes": nodes_out,
    };
}

impl write_learning_sidecar(
    agg: dict[str, Any], graph_path: Path, *, now: datetime | None = None
) -> Path {
    overlay: any = build_learning_overlay(agg, graph_path, now=now);
    sidecar: any = Path(graph_path).parent / LEARNING_SIDECAR_NAME;
    sidecar.write_text(
        json.dumps(overlay, indent=2, sort_keys=True, ensure_ascii=False) + "\n", encoding="utf-8"
    );
    return sidecar;
}

impl load_learning_overlay(graph_path: Path) -> dict[str, dict[str, Any]] {
    sidecar: any = Path(graph_path).parent / LEARNING_SIDECAR_NAME;
    try {
        data: any = json.loads(sidecar.read_text(encoding="utf-8"));
    } except (OSError, ValueError) {
        return {};
    }
    nodes: any = data.get("nodes") if isinstance(data, `dict) else None;
    if not isinstance(nodes, `dict) {
        return {};
    }
    out: dict[str, dict[str, Any]] = {};
    for (nid, `entry) in nodes.items() {
        if not isinstance(`entry, `dict) {
            continue;
        }
        source: any = `entry.get("source_file");
        if source is not None and not isinstance(source, `str) {
            continue;
        }
        merged: any = `dict(`entry);
        try {
            merged["stale"] = _is_stale(`entry, graph_path);
        } except (OSError, ValueError) {
            merged["stale"] = True;
        }
        out[`str(nid)] = merged;
    }
    return out;
}

impl _is_stale(`entry: dict[str, Any], graph_path: Path) -> bool {
    src: any = `entry.get("source_file", "");
    if not src {
        return False;
    }
    sp: any = _resolve_source_path(src, graph_path);
    if sp is None {
        return True;
    }
    stored: any = `entry.get("code_fingerprint", "");
    if not stored {
        return True;
    }
    return operator.ne(_content_hash(sp), stored);
}
