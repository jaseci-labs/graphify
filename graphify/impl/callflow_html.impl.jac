impl read_json(path: str | Path, `default=None) -> any {
    if not path {
        return `default;
    }
    path = Path(path);
    if not path.exists() {
        return `default;
    }
    try {
        return json.loads(path.read_text(encoding="utf-8"));
    } except json.JSONDecodeError as exc {
        raise SystemExit(f"ERROR: invalid JSON in {path}: {exc}") from exc;
    }
}

impl first_present(mapping: dict, *keys_, `default=None) -> any {
    keys: any = tuple(keys_);
    for key in keys {
        if key in mapping and mapping[key] not in (None, "") {
            return mapping[key];
        }
    }
    return `default;
}

impl first_list(*values_) -> list {
    values: any = tuple(values_);
    for value in values {
        if isinstance(value, `list) {
            return value;
        }
    }
    return [];
}

impl to_float(value, `default: float = 0.0) -> float {
    try {
        return `float(value);
    } except (TypeError, ValueError) {
        return `default;
    }
}

impl endpoint_id(value) -> str {
    if isinstance(value, `dict) {
        value = first_present(value, "id", "node_id", "key", "name", "qualified_name");
    }
    return `str(value or "");
}

impl normalize_node(raw: dict, index: int) -> dict {
    `node: any = `dict(raw);
    node_id: any = first_present(
        `node,
        "id",
        "node_id",
        "key",
        "uid",
        "name",
        "qualified_name",
        "fqname",
        "symbol",
        default=f"node_{index + 1}",
    );
    source_file: any = first_present(
        `node,
        "source_file",
        "file",
        "file_path",
        "filepath",
        "path",
        "module_path",
        "defined_in",
        default="",
    );
    label: any = first_present(
        `node,
        "label",
        "display_name",
        "title",
        "name",
        "qualified_name",
        "fqname",
        "symbol",
        default=node_id,
    );
    community: any = first_present(
        `node,
        "community",
        "community_id",
        "cluster",
        "cluster_id",
        "group",
        "group_id",
        "modularity_class",
        default="unknown",
    );
    node_type: any = first_present(`node, "node_type", "kind", "type", "category", default="");
    file_type: any = first_present(`node, "file_type", "content_type", "artifact_type", default="");
    if not file_type {
        suffix: any = Path(`str(source_file)).suffix.lower();
        file_type = "document" if suffix in {".md", ".mdx", ".rst", ".txt"} else "code";
    }

    `node["id"] = `str(node_id);
    `node["label"] = `str(label);
    `node["community"] = community;
    `node["source_file"] = `str(source_file or "");
    `node["node_type"] = `str(node_type or "");
    `node["file_type"] = `str(file_type or "code");
    return `node;
}

impl normalize_edge(raw: dict, index: int) -> dict | None {
    `edge: any = `dict(raw);
    source: any = endpoint_id(
        first_present(`edge, "source", "src", "from", "from_id", "start", "u")
    );
    target: any = endpoint_id(first_present(`edge, "target", "dst", "to", "to_id", "end", "v"));
    if not source or not target {
        return None;
    }

    relation: any = first_present(
        `edge, "relation", "type", "kind", "label", "predicate", default="relates"
    );
    confidence: any = first_present(
        `edge, "confidence", "evidence", "provenance", default="EXTRACTED"
    );
    score: any = first_present(
        `edge, "confidence_score", "score", "weight", "probability", default=1.0
    );

    `edge["id"] = `str(first_present(`edge, "id", "edge_id", default=f"edge_{index + 1}"));
    `edge["source"] = source;
    `edge["target"] = target;
    `edge["relation"] = `str(relation or "relates").lower();
    `edge["confidence"] = `str(confidence or "EXTRACTED").upper();
    `edge["confidence_score"] = to_float(score, 1.0);
    return `edge;
}

impl _node_link_payload(data: dict) -> tuple[list, list] | None {
    if not isinstance(data.get("nodes"), `list) {
        return None;
    }
    if not isinstance(data.get("links"), `list) and not isinstance(data.get("edges"), `list) {
        return None;
    }

    try {
        load_node_link_graph: any = importlib.import_module("graphify.paths").load_node_link_graph;
        `graph: any = load_node_link_graph({**data, "directed": True, "multigraph": True});
    } except Exception {
        return None;
    }

    nodes: any = [];
    attrs: any;
    for (node_id, attrs) in `graph.nodes(data=True) {
        `node: any = `dict(attrs);
        `node["id"] = node_id;
        nodes.append(`node);
    }

    edges: any = [];
    for (index, (source, target, attrs)) in enumerate(`graph.edges(data=True), 1) {
        `edge: any = `dict(attrs);
        `edge["source"] = `edge.get("_src", `edge.get("source", source));
        `edge["target"] = `edge.get("_tgt", `edge.get("target", target));
        `edge.setdefault("id", f"edge_{index}");
        edges.append(`edge);
    }
    return (nodes, edges);
}

impl load_graph(path: str | Path) -> tuple {
    i: any;
    if path {
        check_graph_file_size_cap: any = importlib.import_module("graphify.security").check_graph_file_size_cap;
        try {
            check_graph_file_size_cap(Path(path));
        } except ValueError as exc {
            raise SystemExit(f"ERROR: {exc}") from exc;
        }
    }
    data: any = read_json(path);
    if not isinstance(data, `dict) {
        raise SystemExit(f"ERROR: graph file must contain a JSON object: {path}");
    }

    graph_block: any = data.get("graph") if isinstance(data.get("graph"), `dict) else {};
    meta_block: any = data.get("metadata") if isinstance(data.get("metadata"), `dict) else {};

    node_link: any = _node_link_payload(data);
    if node_link {
        raw_nodes: any;
        raw_edges: any;
        (raw_nodes, raw_edges) = node_link as any;
    } else {
        raw_nodes = first_list(
            data.get("nodes"),
            data.get("vertices"),
            graph_block.get("nodes"),
            graph_block.get("vertices"),
        );
        raw_edges = first_list(
            data.get("links"), data.get("edges"), graph_block.get("links"), graph_block.get("edges")
        );
    }
    hyperedges: any = first_list(
        data.get("hyperedges"),
        graph_block.get("hyperedges"),
        data.get("groups"),
        graph_block.get("groups"),
    );

    nodes: any = [normalize_node(n, i) for (i, n) in enumerate(raw_nodes) if isinstance(n, `dict)];
    edges: any = [];
    for (i, raw_edge) in enumerate(raw_edges) {
        if not isinstance(raw_edge, `dict) {
            continue;
        }
        `edge: any = normalize_edge(raw_edge, i);
        if `edge {
            edges.append(`edge);
        }
    }

    meta: any = `dict(graph_block);
    meta.update(meta_block);
    for key in (
        "built_at_commit",
        "commit",
        "project_name",
        "repo",
        "repository",
        "language_breakdown",
    ) {
        if data.get(key) and not meta.get(key) {
            meta[key] = data.get(key);
        }
    }
    if meta.get("commit") and not meta.get("built_at_commit") {
        meta["built_at_commit"] = meta["commit"];
    }

    return (nodes, edges, hyperedges, meta);
}

impl load_labels(path: str | Path | None) -> dict {
    data: any = read_json(path, default={});
    if not isinstance(data, `dict) {
        return {};
    }
    if isinstance(data.get("labels"), `dict) {
        data = data["labels"];
    }
    if isinstance(data.get("communities"), `dict) {
        data = data["communities"];
    }
    labels: any = {};
    value: any;
    for (key, value) in data.items() {
        if isinstance(value, `dict) {
            value = first_present(value, "label", "name", "title", default=key);
        }
        labels[`str(key)] = `str(value);
    }
    return labels;
}

impl load_sections(path: str | Path | None) -> list {
    data: any = read_json(path, default=[]);
    if isinstance(data, `dict) and isinstance(data.get("sections"), `list) {
        data = data["sections"];
    }
    if not isinstance(data, `list) {
        raise SystemExit(f"ERROR: sections file must contain a JSON array: {path}");
    }
    return data;
}

impl load_report(path: str | Path | None) -> str {
    if path and os.path.exists(path) {
        return Path(path).read_text(encoding="utf-8");
    }
    return "";
}

impl safe_mermaid_text(text: str) -> str {
    text = `str(text or "");
    text = text.replace("\"", "'");
    text = text.replace("`", "");
    text = text.replace("#", "");
    text = text.replace("|", " ");
    text = text.replace("{", "").replace("}", "");
    text = text.replace("->>", " to ").replace("-->", " to ").replace("->", " to ");
    text = " ".join(text.split());
    return escape(text, quote=False);
}

impl html_comment_text(text: str) -> str {
    return `str(text or "").replace("--", "- -").replace("\n", " ");
}

impl stable_ascii_id(raw: str, prefix: str = "node", limit: int = 48) -> str {
    raw = `str(raw or "");
    digest: any = hashlib.sha1(raw.encode("utf-8"), usedforsecurity=False).hexdigest()[:8];
    slug: any = re.sub("[^A-Za-z0-9_]+", "_", raw);
    slug = re.sub("_+", "_", slug).strip("_");
    if not slug {
        slug = prefix;
    }
    if slug[0].isdigit() {
        slug = f"{prefix}_{slug}";
    }
    return format(slug[:limit].rstrip("_"), "") + "_" + format(digest, "");
}

impl node_mermaid_id(`node: dict) -> str {
    return stable_ascii_id(`node.get("id", "unknown"), "node");
}

impl mermaid_section_id(section_id: str) -> str {
    return stable_ascii_id(section_id, "section").upper();
}

impl safe_file_path(path: str) -> str {
    parts: any = path.split("/");
    if len(parts) > 3 {
        return "/".join(parts[-3:]);
    }
    return path;
}

impl safe_filename(text: str, fallback: str = "project") -> str {
    stem: any = re.sub("[^A-Za-z0-9._-]+", "-", `str(text or "")).strip("-._");
    return stem or fallback;
}

impl infer_project_name(graph_path: str, meta: dict) -> str {
    if meta.get("project_name") {
        return meta["project_name"];
    }
    path: any = Path(graph_path).resolve();
    if path.parent.name == GRAPHIFY_OUT_NAME and len(path.parents) > 1 {
        return path.parents[1].name;
    }
    return path.parent.name or "Project";
}

impl resolve_graphify_paths(args) -> dict {
    base: any = Path(args.project).expanduser() if args.project else Path.cwd();
    if args.graphify_out {
        graphify_out: any = Path(args.graphify_out).expanduser();
    } elif args.graph {
        graphify_out = Path(args.graph).expanduser().parent;
    } elif (base / "graph.json").exists() {
        graphify_out = base;
    } else {
        graphify_out = base / GRAPHIFY_OUT;
    }

    project_root: any = graphify_out.parent if graphify_out.name == GRAPHIFY_OUT_NAME else base;
    `graph: any = Path(args.graph).expanduser() if args.graph else graphify_out / "graph.json";
    `report: any = Path(args.report).expanduser()
        if args.report
        else graphify_out / "GRAPH_REPORT.md";
    labels: any = Path(args.labels).expanduser()
        if args.labels
        else graphify_out / ".graphify_labels.json";
    sections: any = Path(args.sections).expanduser() if args.sections else None;
    return {
        "base": project_root,
        "graphify_out": graphify_out,
        "graph": `graph,
        "report": `report,
        "labels": labels,
        "sections": sections,
    };
}

impl is_zh(lang: str) -> bool {
    return (lang or "").lower().startswith("zh");
}

impl pick_text(lang: str, zh: str, en: str) -> str {
    return zh if is_zh(lang) else en;
}

impl detect_lang(lang: str, nodes: list, labels: dict) -> str {
    if lang and lang.lower() != "auto" {
        return lang;
    }
    sample: any = " ".join(
        `list(labels.values())[:50]
            + [`str(n.get("label", "")) for n in nodes[:200]]
            + [`str(n.get("source_file", "")) for n in nodes[:100]],
    );
    return "zh-CN" if re.search("[\\u4e00-\\u9fff]", sample) else "en";
}

impl truncate_text(text: str, limit: int) -> str {
    text = " ".join(`str(text or "").split());
    if len(text) <= limit {
        return text;
    }
    return text[:max(0, limit - 3)].rstrip() + "...";
}

impl humanize_label(label: str, source_file: str = "") -> str {
    label = `str(label or "").strip();
    if not label {
        return Path(source_file).name if source_file else "Unknown";
    }
    if label.startswith(".") and label.endswith("()") {
        return label[1:];
    }
    if label.endswith((".py", ".ts", ".tsx", ".js", ".jsx", ".go", ".rs", ".java", ".rb")) {
        return Path(label).name;
    }
    if "_" in label and " " not in label and len(label) > 28 {
        parts: any = [p for p in label.split("_") if p];
        if parts {
            label = " ".join(parts[-3:]);
        }
    }
    return truncate_text(label, 42);
}

impl node_kind(`node: dict) -> str {
    label: any;
    label = `str(`node.get("label") or `node.get("id") or "").lower();
    source_file: any = `str(`node.get("source_file") or "").lower();
    file_type: any = `str(`node.get("file_type") or "").lower();
    node_type: any = `str(`node.get("node_type") or "").lower();
    if node_type in {"class", "klass", "struct", "interface", "enum", "trait", "model"} {
        return "klass";
    }
    if node_type in {"module", "file", "package", "namespace"} {
        return "module";
    }
    if node_type in {"endpoint", "route", "api", "handler", "controller"} {
        return "api";
    }
    if node_type in {"test", "spec"} {
        return "test";
    }
    if node_type in {"component", "hook", "view", "page"} {
        return "ui";
    }
    if file_type in {"rationale", "document"} {
        return "concept";
    }
    if "test" in source_file or label.startswith("test_") or "spec" in source_file {
        return "test";
    }
    if `any(word in label for word in ("endpoint", "router", "api", "route")) {
        return "api";
    }
    if `any(word in label for word in ("cli", "command", "click", "typer")) {
        return "entry";
    }
    if `any(word in label for word in ("async", "await", "stream", "sse")) {
        return "async";
    }
    raw_label: any = `str(`node.get("label") or "");
    hook_like: any = raw_label.startswith("use")
        and operator.gt(len(raw_label), 3)
        and (raw_label[3].isupper() or raw_label[3] in "_-");
    if `any(word in label for word in ("component", "props", "hook", "store"))
        or hook_like
        or source_file.endswith((".tsx", ".jsx", ".vue", ".svelte"))
    {
        return "ui";
    }
    raw: any = raw_label;
    if raw[:1].isupper() and not raw.endswith("()") {
        return "klass";
    }
    if raw.endswith((
        ".py",
        ".ts",
        ".tsx",
        ".js",
        ".jsx",
        ".go",
        ".rs",
        ".java",
        ".kt",
        ".rb",
        ".php",
        ".cs",
        ".swift",
        ".vue",
        ".svelte",
    )) {
        return "module";
    }
    return "function";
}

impl relation_label(relation: str, lang: str) -> str {
    relation = `str(relation or "").strip();
    zh: any = {
        "calls": "调用",
        "uses": "使用",
        "imports": "导入",
        "imports_from": "导入",
        "method": "方法",
        "contains": "包含",
        "rationale_for": "说明",
        "conceptually_related_to": "相关",
        "participate_in": "参与",
        "form": "组成",
    };
    en: any = {
        "calls": "calls",
        "uses": "uses",
        "imports": "imports",
        "imports_from": "imports",
        "method": "method",
        "contains": "contains",
        "rationale_for": "explains",
        "conceptually_related_to": "relates",
        "participate_in": "joins",
        "form": "forms",
    };
    mapped: any = (zh if is_zh(lang) else en).get(relation, relation.replace("_", " "));
    return safe_mermaid_text(mapped);
}

impl preferred_edges(edges: list, allow_structure: bool = False) -> list {
    primary: any = {"calls", "uses", "method", "imports", "imports_from"};
    secondary: any = {"contains", "rationale_for", "conceptually_related_to"};
    selected: any = [];
    for `edge in edges {
        if not should_include_edge(`edge) {
            continue;
        }
        relation: any = `edge.get("relation", "");
        if relation in primary or allow_structure and relation in secondary {
            selected.append(`edge);
        }
    }
    if selected {
        return selected;
    }
    return [`edge for `edge in edges if should_include_edge(`edge)];
}

impl edge_score(`edge: dict) -> float {
    relation: any = `edge.get("relation", "");
    score: any = to_float(`edge.get("confidence_score", 1.0), 1.0);
    if `str(`edge.get("confidence", "")).upper() == "EXTRACTED" {
        score += 2.0;
    }
    if relation in {"calls", "uses", "method"} {
        score += 1.0;
    } elif relation in {"imports", "imports_from"} {
        score += 0.6;
    } elif relation == "contains" {
        score -= 0.2;
    } elif relation == "rationale_for" {
        score -= 0.6;
    }
    return score;
}

impl mermaid_init(scale: float, direction: str = "LR") -> str {
    scale = max(0.65, min(`float(scale or 1.0), 1.8));
    config: any = {
        "theme": "dark",
        "themeVariables": {
            "fontSize": f"{round(15 * scale, 1)}px",
            "fontFamily": "Segoe UI, system-ui, sans-serif",
            "primaryColor": "#1e293b",
            "primaryTextColor": "#e2e8f0",
            "primaryBorderColor": "#38bdf8",
            "secondaryColor": "#0f172a",
            "tertiaryColor": "#334155",
            "lineColor": "#64748b",
            "textColor": "#e2e8f0",
        },
        "flowchart": {
            "htmlLabels": True,
            "curve": "basis",
            "nodeSpacing": round(48 * scale),
            "rankSpacing": round(64 * scale),
            "padding": round(14 * scale),
            "diagramPadding": round(10 * scale),
            "useMaxWidth": True,
        },
    };
    return f"%%{{init: {json.dumps(config, ensure_ascii=False)}}}%%\nflowchart {direction}";
}

impl mermaid_class_defs -> list {
    return [
        "    classDef entry fill:#422006,stroke:#fbbf24,color:#fde68a,stroke-width:1px;",
        "    classDef api fill:#450a0a,stroke:#f87171,color:#fee2e2,stroke-width:1px;",
        "    classDef async fill:#2e1065,stroke:#a78bfa,color:#ede9fe,stroke-width:1px;",
        "    classDef klass fill:#064e3b,stroke:#34d399,color:#d1fae5,stroke-width:1px;",
        "    classDef ui fill:#831843,stroke:#f472b6,color:#fce7f3,stroke-width:1px;",
        "    classDef module fill:#172554,stroke:#60a5fa,color:#dbeafe,stroke-width:1px;",
        "    classDef test fill:#3f3f46,stroke:#a1a1aa,color:#f4f4f5,stroke-width:1px;",
        "    classDef concept fill:#292524,stroke:#a8a29e,color:#fafaf9,stroke-dasharray:4 3;",
        "    classDef function fill:#0f172a,stroke:#38bdf8,color:#e0f2fe,stroke-width:1px;",
    ];
}

impl build_community_index(nodes: list) -> dict {
    idx: any = defaultdict(list[any]);
    for n in nodes {
        cid: any = `str(n.get("community", "unknown"));
        idx[cid].append(n);
    }
    return idx;
}

impl html_anchor_id(raw: str, fallback: str, used: set) -> str {
    raw = `str(raw or fallback or "");
    base: any = re.sub("[^a-z0-9]+", "-", raw.lower()).strip("-");
    if not base {
        base = re.sub("[^a-z0-9]+", "-", `str(fallback or "section").lower()).strip("-");
    }
    if not base {
        base = "section";
    }
    base = base[:48].strip("-") or "section";
    candidate: any = base;
    if candidate in used {
        candidate = format(base, "")
            + "-"
            + format(hashlib.sha1(raw.encode("utf-8"), usedforsecurity=False).hexdigest()[:6], "");
    }
    suffix: any = 2;
    while candidate in used {
        candidate = f"{base}-{suffix}";
        suffix += 1;
    }
    used.add(candidate);
    return candidate;
}

impl normalize_communities(value) -> list {
    if isinstance(value, `list) {
        return value;
    }
    if value in (None, "") {
        return [];
    }
    if isinstance(value, `str) {
        return [part.strip() for part in value.split(",") if part.strip()];
    }
    return [value];
}

impl normalize_sections(sections: list, lang: str) -> list {
    overview_name: any = pick_text(lang, "架构总览", "Architecture Overview");
    normalized: any = [{"id": "overview", "name": overview_name, "communities": []}];
    used: any = {"overview", "hyperedges", "stats"};

    for (index, raw) in enumerate(sections or [], 1) {
        if not isinstance(raw, `dict) {
            continue;
        }
        raw_id: any = `str(
            raw.get("id") or raw.get("key") or raw.get("name") or f"section-{index}"
        );
        raw_name: any = `str(raw.get("name") or raw.get("label") or raw_id);
        if raw_id.lower() == "overview" {
            normalized[0]["name"] = raw_name or overview_name;
            continue;
        }

        sid: any = html_anchor_id(raw_id, f"section-{index}", used);
        normalized.append({
            "id": sid,
            "name": raw_name,
            "communities": normalize_communities(raw.get("communities", raw.get("community"))),
        });
    }
    return normalized;
}

impl label_for_community(cid: str, labels: dict, nodes: list, lang: str) -> str {
    if `str(cid) in labels and labels[`str(cid)] {
        return labels[`str(cid)];
    }
    keywords: any = section_keywords(nodes, 3);
    if keywords {
        return " ".join(word.title() for word in keywords[:3]);
    }
    return pick_text(lang, f"社区 {cid}", f"Community {cid}");
}

impl _community_text(nodes: list, label: str = "") -> str {
    parts: any = [label];
    for `node in nodes[:80] {
        parts.append(`str(`node.get("label", "")));
        parts.append(`str(`node.get("source_file", "")));
        parts.append(`str(`node.get("node_type", "")));
        parts.append(`str(`node.get("file_type", "")));
    }
    return " ".join(parts).lower();
}

impl _keyword_score(text: str, keywords: set[str]) -> int {
    score: any = 0;
    for keyword in keywords {
        score += len(re.findall(f"(?<![a-z0-9]){re.escape(keyword)}(?![a-z0-9])", text));
    }
    return score;
}

impl _rank_grouped_sections(grouped: dict, max_sections: int) -> tuple[list, list] {
    ranked: any = sorted(
        grouped.values(),
        key=lambda (sec) -> any { (sec["priority"], -sec["node_count"], sec["id"]) },
    );
    cap: any = max(1, `int(max_sections or 15));
    selected: any = ranked[:cap];
    overflow: any = ranked[cap:];
    overflow_communities: any = [];
    for sec in overflow {
        overflow_communities.extend(sec["communities"]);
    }
    return (selected, overflow_communities);
}

impl derive_sections_from_communities(
    nodes: list, labels: dict, lang: str, max_sections: int
) -> list {
    comm_idx: any = build_community_index(nodes);
    sections: any = [
        {
            "id": "overview",
            "name": pick_text(lang, "架构总览", "Architecture Overview"),
            "communities": [],
        },
    ];
    grouped: any = {};
    unassigned: any = [];

    cid: any;
    community_nodes: any;
    for (cid, community_nodes) in sorted(
        comm_idx.items(), key=lambda (item) -> any { (-len(item[1]), `str(item[0])) }
    ) {
        label: any = label_for_community(cid, labels, community_nodes, lang);
        text: any = _community_text(community_nodes, label);
        best: any = None;
        best_score: any = 0;
        priority: any;
        sid: any;
        zh_name: any;
        en_name: any;
        for (priority, (sid, zh_name, en_name, keywords)) in enumerate(SECTION_ARCHETYPES) {
            score: any = _keyword_score(text, keywords);
            if score > best_score {
                best = (priority, sid, zh_name, en_name);
                best_score = score;
            }
        }

        if best and best_score >= 2 {
            (priority, sid, zh_name, en_name) = best as any;
            sec: any = grouped.setdefault(
                sid,
                {
                    "id": sid,
                    "name": pick_text(lang, zh_name, en_name),
                    "communities": [],
                    "node_count": 0,
                    "priority": priority,
                },
            );
            sec["communities"].append(cid);
            sec["node_count"] += len(community_nodes);
        } else {
            unassigned.append((cid, community_nodes, label));
        }
    }

    selected: any;
    overflow_communities: any;
    (selected, overflow_communities) = _rank_grouped_sections(
        grouped, max(1, `int(max_sections or 15)) - 1
    ) as any;
    sections.extend(
        {"id": sec["id"], "name": sec["name"], "communities": sec["communities"]}
        for sec in selected,
    );

    remaining_slots: any = max(0, `int(max_sections or 15) - (len(sections) - 1) - 1);
    for (cid, community_nodes, label) in unassigned[:remaining_slots] {
        sections.append({
            "id": `str(label or f"community-{cid}"),
            "name": label,
            "communities": [cid],
        });
    }

    other_communities: any = overflow_communities + [
        cid
        for (cid, _, _) in unassigned[remaining_slots:]
    ];
    if other_communities {
        sections.append({
            "id": "other",
            "name": pick_text(lang, "其他", "Other"),
            "communities": other_communities,
        });
    }
    return sections;
}

impl build_section_node_map(sections: list, comm_idx: dict) -> dict {
    section_nodes: any = {};
    for sec in sections {
        sid: any = sec["id"];
        if sid == "overview" {
            section_nodes[sid] = [];
            continue;
        }
        nodes: any = [];
        for cid in sec.get("communities", []) {
            nodes.extend(comm_idx.get(`str(cid), []));
        }
        section_nodes[sid] = nodes;
    }
    return section_nodes;
}

impl node_in_section(node_id: str, section_node_ids: set) -> bool {
    return node_id in section_node_ids;
}

impl classify_edges(edges: list, section_nodes_map: dict) -> dict {
    node_section: any = {};
    for (sid, nodes) in section_nodes_map.items() {
        for n in nodes {
            node_section[n.get("id")] = sid;
        }
    }

    intra: any = defaultdict(list[any]);
    inter: any = [];
    orphan: any = [];

    for e in edges {
        src: any = e.get("source", "");
        tgt: any = e.get("target", "");
        src_sec: any = node_section.get(src);
        tgt_sec: any = node_section.get(tgt);

        if src_sec is None or tgt_sec is None {
            orphan.append(e);
        } elif src_sec == tgt_sec {
            intra[src_sec].append(e);
        } else {
            inter.append(e);
        }
    }

    return {"intra": `dict(intra), "inter": inter, "orphan": orphan, "node_section": node_section};
}

impl should_include_edge(`edge: dict) -> bool {
    conf: any = `str(`edge.get("confidence", "EXTRACTED")).upper();
    score: any = to_float(`edge.get("confidence_score", 1.0), 1.0);

    if conf == "EXTRACTED" {
        return True;
    }
    if conf == "INFERRED" and score >= 0.85 {
        return True;
    }
    return False;
}

impl node_degree_scores(edges: list) -> Counter {
    scores: any = Counter();
    for `edge in edges {
        score: any = edge_score(`edge);
        scores[`edge.get("source", "")] += score;
        scores[`edge.get("target", "")] += score;
    }
    return scores;
}

impl node_importance(`node: dict) -> float {
    for key in ("pagerank", "page_rank", "pageRank", "rank", "centrality", "score") {
        if key in `node {
            return to_float(`node.get(key), 0.0);
        }
    }
    return 0.0;
}

impl select_diagram_nodes(nodes: list, edges: list, max_nodes: int) -> list {
    node_by_id: any;
    scores: any;
    outgoing: any;
    incoming: any;
    selected: any;
    seen: any;
    `edge: any;
    node_by_id = {n.get("id"): n for n in nodes};
    usable_edges: any = preferred_edges(edges, allow_structure=False);
    if not usable_edges {
        usable_edges = preferred_edges(edges, allow_structure=True);
    }
    scores = node_degree_scores(usable_edges);
    outgoing = Counter(`edge.get("source", "") for `edge in usable_edges);
    incoming = Counter(`edge.get("target", "") for `edge in usable_edges);
    selected = [];
    seen = set[any]();

    def add_node(nid: str) -> bool {
        `node: any = node_by_id.get(nid);
        if not `node or nid in seen {
            return False;
        }
        kind: any = node_kind(`node);
        if kind == "concept" and len(selected) >= max(4, max_nodes // 3) {
            return False;
        }
        selected.append(`node);
        seen.add(nid);
        return operator.ge(len(selected), max_nodes);
    }
    entry_candidates: any = sorted(
        node_by_id,
        key=lambda (nid) -> any { (-(outgoing[nid] - incoming[nid]), -outgoing[nid], `str(nid)) },
    );
    nid: any;
    for nid in entry_candidates[:max(3, max_nodes // 3)] {
        if outgoing[nid] > 0 and add_node(nid) {
            return selected;
        }
    }
    for `edge in sorted(usable_edges, key=edge_score, reverse=True) {
        for nid in (`edge.get("source"), `edge.get("target")) {
            if add_node(nid) {
                return selected;
            }
        }
    }

    def fallback_key(`node: dict) -> tuple {
        nid: any = `node.get("id", "");
        kind_penalty: any = 1 if node_kind(`node) == "concept" else 0;
        return (
            kind_penalty,
            -scores.get(nid, 0),
            -node_importance(`node),
            safe_file_path(`node.get("source_file", "")),
            humanize_label(`node.get("label", nid)),
        );
    }

    for `node in sorted(nodes, key=fallback_key) {
        nid = `node.get("id");
        if nid not in seen {
            selected.append(`node);
            seen.add(nid);
        }
        if len(selected) >= max_nodes {
            break;
        }
    }
    return selected;
}

impl node_label(`node: dict) -> str {
    label: any = humanize_label(
        `node.get("label") or `node.get("id"), `node.get("source_file", "")
    );
    source_file: any = safe_file_path(`node.get("source_file", ""));
    if source_file and not label.endswith(Path(source_file).name) {
        return f"{safe_mermaid_text(label)}<br/><small>{safe_mermaid_text(source_file)}</small>";
    }
    return safe_mermaid_text(label);
}

impl group_nodes_by_file(nodes: list) -> dict {
    groups: any = defaultdict(list[any]);
    for `node in nodes {
        source_file: any = safe_file_path(`node.get("source_file", "")) or "External / generated";
        groups[source_file].append(`node);
    }
    return `dict(sorted(groups.items(), key=lambda (item) -> any { (-len(item[1]), item[0]) }));
}

impl section_edge_summary(classified_edges: dict) -> dict {
    node_section: any = classified_edges.get("node_section", {});
    summary: any = defaultdict(lambda -> any { {"count": 0, "relations": Counter()} });
    for `edge in classified_edges.get("inter", []) {
        if not should_include_edge(`edge) {
            continue;
        }
        src_sec: any = node_section.get(`edge.get("source"));
        tgt_sec: any = node_section.get(`edge.get("target"));
        if not src_sec or not tgt_sec or src_sec == tgt_sec {
            continue;
        }
        key: any = (src_sec, tgt_sec);
        summary[key]["count"] += 1;
        summary[key]["relations"][`edge.get("relation", "relates")] += 1;
    }
    return summary;
}

impl generate_overview_graph(
    sections: list,
    section_nodes_map: dict,
    classified_edges: dict,
    labels: dict,
    lang: str,
    diagram_scale: float,
) -> str {
    sec: any;
    lines: any = [mermaid_init(diagram_scale, "LR")];
    section_defs: any = [sec for sec in sections if sec["id"] != "overview"];

    for sec in section_defs {
        sid: any = mermaid_section_id(sec["id"]);
        node_count: any = len(section_nodes_map.get(sec["id"], []));
        label: any = format(safe_mermaid_text(sec.get("name", sec["id"])), "")
            + "<br/><small>"
            + format(node_count, "")
            + " "
            + format(safe_mermaid_text("nodes"), "")
            + "</small>";
        lines.append(f"    {sid}(\"{label}\")");
        lines.append(f"    class {sid} module;");
    }

    aggregated: any = section_edge_summary(classified_edges);
    for ((src, tgt), data) in sorted(
        aggregated.items(), key=lambda (item) -> any { item[1]["count"] }, reverse=True
    )[:12] {
        src_id: any = mermaid_section_id(src);
        tgt_id: any = mermaid_section_id(tgt);
        relation: any;
        _: any;
        (relation, _) = data["relations"].most_common(1)[0] as any;
        label = relation_label(relation, lang);
        if data["count"] > 1 {
            label = format(label, "") + " x" + format(data["count"], "");
        }
        lines.append(f"    {src_id} -->|{label}| {tgt_id}");
    }

    if not aggregated and len(section_defs) > 1 {
        for (prev, cur) in zip(section_defs, section_defs[1:]) {
            lines.append(
                "    "
                    + format(mermaid_section_id(prev["id"]), "")
                    + " -.-> "
                    + format(mermaid_section_id(cur["id"]), ""),
            );
        }
    }

    lines.extend(mermaid_class_defs());
    return "\n".join(lines);
}

impl generate_section_flowchart(
    section_id: str,
    section_name: str,
    nodes: list,
    edges: list,
    lang: str,
    diagram_scale: float,
    max_nodes: int,
    max_edges: int,
) -> str {
    `node: any;
    `edge: any;
    lines: any = [mermaid_init(diagram_scale, "LR")];
    lines.append(
        f"    %% Section: {safe_mermaid_text(section_name)} ({len(nodes)} nodes, {len(edges)} edges)",
    );

    if not nodes {
        empty_label: any = pick_text(lang, f"{section_name} - 无节点", f"{section_name} - no nodes");
        lines.append(f"    empty(\"{safe_mermaid_text(empty_label)}\")");
        lines.extend(mermaid_class_defs());
        return "\n".join(lines);
    }

    selected_nodes: any = select_diagram_nodes(nodes, edges, max_nodes);
    selected_ids: any = {`node.get("id") for `node in selected_nodes};
    visible_edges: any = [
        `edge
        for `edge in preferred_edges(edges, allow_structure=False)
        if `edge.get("source") in selected_ids and `edge.get("target") in selected_ids
    ];
    if not visible_edges {
        visible_edges = [
            `edge
            for `edge in preferred_edges(edges, allow_structure=True)
            if `edge.get("source") in selected_ids and `edge.get("target") in selected_ids
        ];
    }

    groups: any = group_nodes_by_file(selected_nodes);
    class_lines: any = [];
    for (source_file, group) in groups.items() {
        group_id: any = node_mermaid_id({"id": f"{section_id}_{source_file}"});
        if len(groups) > 1 and len(group) > 1 {
            lines.append(f"    subgraph {group_id}[\"{safe_mermaid_text(source_file)}\"]");
            indent: any = "        ";
        } else {
            indent = "    ";
        }
        for `node in group {
            mid: any = node_mermaid_id(`node);
            lines.append(f"{indent}{mid}(\"{node_label(`node)}\")");
            class_lines.append(f"    class {mid} {node_kind(`node)};");
        }
        if len(groups) > 1 and len(group) > 1 {
            lines.append("    end");
        }
    }

    included: any = 0;
    for `edge in sorted(visible_edges, key=edge_score, reverse=True) {
        if included >= max_edges {
            break;
        }
        src_id: any = node_mermaid_id({"id": `edge.get("source", "")});
        tgt_id: any = node_mermaid_id({"id": `edge.get("target", "")});
        rel: any = relation_label(`edge.get("relation", ""), lang);
        lines.append(f"    {src_id} -->|{rel}| {tgt_id}");
        included += 1;
    }

    omitted_nodes: any = max(0, len(nodes) - len(selected_nodes));
    omitted_edges: any = max(0, len(visible_edges) - included);
    if omitted_nodes or omitted_edges {
        lines.append(
            f"    %% Omitted for readability: {omitted_nodes} nodes, {omitted_edges} edges"
        );
    }
    lines.extend(class_lines);
    lines.extend(mermaid_class_defs());
    return "\n".join(lines);
}

impl generate_nav(sections: list) -> str {
    links: any = [];
    for sec in sections {
        links.append(
            "    <a href=\"#"
                + format(escape(sec["id"], quote=True), "")
                + "\">"
                + format(escape(sec["name"]), "")
                + "</a>",
        );
    }
    return "<div class=\"nav\">\n" + "\n".join(links) + "\n</div>";
}

impl node_display_name(`node: dict | None, fallback: str = "") -> str {
    if not `node {
        return `str(fallback or "");
    }
    label: any = `str(`node.get("label") or `node.get("id") or fallback or "");
    return humanize_label(label, `node.get("source_file", ""));
}

impl format_node_refs(
    node_ids: set, node_by_id: dict, lang: str, empty_text: str, limit: int = 3
) -> str {
    if not node_ids {
        return escape(empty_text);
    }
    parts: any = [];
    for nid in sorted(
        node_ids, key=lambda (item) -> any { node_display_name(node_by_id.get(item), item).lower() }
    )[:limit] {
        `node: any = node_by_id.get(nid);
        label: any = node_display_name(`node, nid);
        source: any = safe_file_path((`node or {}).get("source_file", ""));
        if source {
            parts.append(
                f"<code>{escape(label)}</code><br><small style=\"color:var(--muted)\">{escape(source)}</small>",
            );
        } else {
            parts.append(f"<code>{escape(label)}</code>");
        }
    }
    if len(node_ids) > limit {
        parts.append(
            escape(
                pick_text(lang, f"+{len(node_ids) - limit} 个更多", f"+{len(node_ids) - limit} more")
            ),
        );
    }
    return "<br>".join(parts);
}

impl generate_call_table_rows(
    nodes: list,
    section_edges: list,
    lang: str,
    all_edges: list | None = None,
    all_nodes: list | None = None,
) -> str {
    n: any;
    if not nodes {
        return "";
    }
    node_by_id: any = {n.get("id"): n for n in all_nodes or nodes};
    callers: any = defaultdict(set[any]);
    callees: any = defaultdict(set[any]);
    for e in all_edges if all_edges is not None else section_edges {
        src: any = e.get("source", "");
        tgt: any = e.get("target", "");
        if e.get("relation")
            in ("calls", "imports", "imports_from", "uses", "method", "indirect_call")
        {
            callers[tgt].add(src);
            callees[src].add(tgt);
        }
    }

    rows: any = [];
    for (i, n) in enumerate(nodes[:30], 1) {
        nid: any = n.get("id", "");
        label: any = n.get("label", nid);
        source_file: any = safe_file_path(n.get("source_file", ""));
        file_type: any = n.get("file_type", "code");
        tag: any = _suggest_tag(label, file_type, lang, node_kind(n));

        caller_text: any = format_node_refs(
            callers.get(nid, set[any]()),
            node_by_id,
            lang,
            pick_text(lang, "外部入口 / 无直接入边", "External entry / no inbound edge"),
        );
        callee_text: any = format_node_refs(
            callees.get(nid, set[any]()),
            node_by_id,
            lang,
            pick_text(lang, "无直接出边", "No direct outbound edge"),
        );

        rows.append(
            f"<tr>\n  <td>{i}</td>\n  <td><code>{escape(label)}</code><br><small style=\"color:var(--muted)\">{escape(source_file)}</small></td>\n  <td>{tag}</td>\n  <td>{caller_text}</td>\n  <td>{callee_text}</td>\n  <td>{escape(_describe_node(label, source_file, file_type, lang))}</td>\n</tr>",
        );
    }

    return "\n".join(rows);
}

impl _suggest_tag(label: str, file_type: str, lang: str, kind: str = "") -> str {
    lower: any;
    lower = label.lower();
    names: any = {
        "concept": ("概念", "Concept", "tag-func"),
        "entry": ("入口", "Entry", "tag-cmd"),
        "api": ("API", "API", "tag-endpoint"),
        "async": ("异步", "Async", "tag-async"),
        "klass": ("类", "Class", "tag-class"),
        "ui": ("UI", "UI", "tag-hook"),
        "module": ("模块", "Module", "tag-class"),
        "test": ("测试", "Test", "tag-func"),
        "function": ("函数", "Function", "tag-func"),
    };
    if kind in names {
        zh: any;
        en: any;
        cls: any;
        (zh, en, cls) = names[kind] as any;
        return f"<span class=\"tag {cls}\">{pick_text(lang, zh, en)}</span>";
    }
    if file_type == "rationale" {
        return "<span class=\"tag tag-func\">"
            + format(pick_text(lang, "概念", "Concept"), "")
            + "</span>";
    }
    if `any(kw in lower for kw in ("cli", "command", "scan", "serve", "chat", "config")) {
        if "group" in lower or "command" in lower {
            return "<span class=\"tag tag-cmd\">"
                + format(pick_text(lang, "CLI命令", "CLI"), "")
                + "</span>";
        }
    }
    if `any(kw in lower for kw in ("router", "endpoint", "api", "/api/")) {
        return "<span class=\"tag tag-endpoint\">"
            + format(pick_text(lang, "API端点", "API"), "")
            + "</span>";
    }
    if `any(kw in lower for kw in ("async", "await", "stream")) {
        return "<span class=\"tag tag-async\">"
            + format(pick_text(lang, "异步", "Async"), "")
            + "</span>";
    }
    if `any(kw in lower for kw in ("class", "model", "schema", "dataclass", "pydantic")) {
        return "<span class=\"tag tag-class\">"
            + format(pick_text(lang, "类", "Class"), "")
            + "</span>";
    }
    if `any(kw in lower for kw in ("hook", "usestate", "useeffect", "store")) {
        return "<span class=\"tag tag-hook\">Hook</span>";
    }
    if `any(kw in lower for kw in ("component", "props", "tsx", "jsx", "render")) {
        return "<span class=\"tag tag-class\">"
            + format(pick_text(lang, "组件", "Component"), "")
            + "</span>";
    }
    return "<span class=\"tag tag-func\">"
        + format(pick_text(lang, "函数", "Function"), "")
        + "</span>";
}

impl _describe_node(label: str, source_file: str, file_type: str, lang: str) -> str {
    lower: any = label.lower();
    source: any = source_file or pick_text(lang, "项目", "project");
    if file_type == "rationale" {
        return pick_text(lang, f"设计说明：{label}", f"Design note for {label}.");
    }
    if file_type == "document" {
        return pick_text(lang, f"文档入口，描述 {label} 相关能力。", f"Documentation node describing {label}.");
    }
    if label.endswith(".py") or label.endswith(".tsx") or label.endswith(".ts") {
        return pick_text(lang, f"{source} 中的模块文件，承载该层主要实现。", f"Module file in {source}.");
    }
    if "config" in lower {
        return pick_text(
            lang, "读取、解析或持久化项目配置。", "Reads, resolves, or persists project configuration."
        );
    }
    if "scan" in lower {
        return pick_text(lang, "触发项目扫描或处理扫描状态。", "Starts scanning or handles scan status.");
    }
    if "ingest" in lower or "clone" in lower or "git" in lower {
        return pick_text(
            lang,
            "把本地目录或远程仓库转换为分析上下文。",
            "Turns a local path or remote repository into analysis context.",
        );
    }
    if "prompt" in lower {
        return pick_text(lang, "构造发送给 LLM 的结构化提示。", "Builds structured prompts for model calls.");
    }
    if "analy" in lower {
        return pick_text(
            lang,
            "编排分析流程并产出结构化文档数据。",
            "Orchestrates analysis and returns structured documentation data.",
        );
    }
    if "graph" in lower or "dependency" in lower {
        return pick_text(
            lang, "构建依赖关系并提供排序或图形化数据。", "Builds dependency relationships and graph data."
        );
    }
    if "export" in lower or "markdown" in lower or "html" in lower {
        return pick_text(lang, "将文档数据导出为目标格式。", "Exports documentation data to a target format.");
    }
    if "chat" in lower or "rag" in lower or "retrieve" in lower {
        return pick_text(
            lang, "支撑检索增强问答或流式聊天。", "Supports retrieval-augmented Q&A or streaming chat."
        );
    }
    if "wiki" in lower or "page" in lower or "sidebar" in lower {
        return pick_text(
            lang,
            "组织文档页面、侧边栏或内容读取。",
            "Organizes documentation pages, navigation, or content lookup.",
        );
    }
    if "cache" in lower or "hash" in lower {
        return pick_text(lang, "缓存分析结果或生成缓存键。", "Caches analysis results or computes cache keys.");
    }
    if "test" in lower {
        return pick_text(
            lang, "验证导入、入口点或版本等基础行为。", "Verifies imports, entry points, or version behavior."
        );
    }
    return pick_text(lang, f"{source} 中的 {label} 节点。", f"{label} node in {source}.");
}

impl generate_header(sections: list, meta: dict, lang: str) -> str {
    project_name: any = `str(meta.get("project_name", "Project"));
    commit: any = `str(meta.get("built_at_commit", "unknown"))[:7];

    if lang.startswith("zh") {
        title: any = f"{project_name} — 完整调用流程与架构文档";
        subtitle: any = "由 graphify 知识图谱生成："
            + format(meta.get("node_count", "?"), "")
            + " 个节点、"
            + format(meta.get("edge_count", "?"), "")
            + " 条边、"
            + format(meta.get("community_count", "?"), "")
            + " 个社区。Commit: "
            + format(commit, "");
    } else {
        title = f"{project_name} — Complete Call Flow & Architecture Documentation";
        subtitle = "Generated from graphify knowledge graph: "
            + format(meta.get("node_count", "?"), "")
            + " nodes, "
            + format(meta.get("edge_count", "?"), "")
            + " edges, "
            + format(meta.get("community_count", "?"), "")
            + " communities. Commit: "
            + format(commit, "");
    }

    return f"<h1>{escape(title)}</h1>\n<p class=\"subtitle\">{escape(subtitle)}</p>\n\n{generate_nav(sections)}\n";
}

impl derive_flow_chain(sections: list, classified_edges: dict) -> str {
    section_names: any;
    order: any;
    incoming: any;
    section_names = {sec["id"]: sec.get("name", sec["id"]) for sec in sections};
    order = [sec["id"] for sec in sections if sec["id"] != "overview"];
    if not order {
        return "Graph nodes -> documentation";
    }

    outgoing: any = defaultdict(Counter);
    incoming = Counter();
    for ((src, tgt), data) in section_edge_summary(classified_edges).items() {
        outgoing[src][tgt] += data["count"];
        incoming[tgt] += data["count"];
    }

    start: any = min(order, key=lambda (sid) -> any { (incoming.get(sid, 0), order.index(sid)) });
    chain: any = [start];
    seen: any = {start};
    current: any = start;
    while len(chain) < min(7, len(order)) {
        candidates: any = [
            (count, tgt)
            for (tgt, count) in outgoing.get(current, {}).items()
            if tgt not in seen
        ];
        if candidates {
            _: any;
            nxt: any;
            (_, nxt) = max(candidates) as any;
        } else {
            remaining: any = [sid for sid in order if sid not in seen];
            if not remaining {
                break;
            }
            nxt = remaining[0];
        }
        chain.append(nxt);
        seen.add(nxt);
        current = nxt;
    }
    return " -> ".join(section_names.get(sid, sid) for sid in chain);
}

impl generate_overview_cards(
    meta: dict,
    report_text: str,
    sections: list,
    section_nodes_map: dict,
    classified_edges: dict,
    lang: str,
) -> str {
    rows: any = [];
    for sec in sections {
        if sec["id"] == "overview" {
            continue;
        }
        communities: any = ", ".join(`str(c) for c in sec.get("communities", []));
        node_count: any = len(section_nodes_map.get(sec["id"], []));
        rows.append(
            "<tr><td>"
                + format(escape(sec["name"]), "")
                + "</td><td>"
                + format(node_count, "")
                + "</td><td><code>"
                + format(escape(communities), "")
                + "</code></td></tr>",
        );
    }

    `flow: any = derive_flow_chain(sections, classified_edges);
    layer_title: any = pick_text(lang, "架构层次", "Architecture Layers");
    layer_cols: any = pick_text(
        lang,
        "<tr><th>层</th><th>节点</th><th>社区</th></tr>",
        "<tr><th>Layer</th><th>Nodes</th><th>Communities</th></tr>",
    );
    flow_title: any = pick_text(lang, "核心数据流", "Core Flow");
    return "<div class=\"grid\">\n  <div class=\"card\">\n    <h4>"
        + format(layer_title, "")
        + "</h4>\n    <table style=\"width:100%;font-size:0.85rem;\">\n      "
        + format(layer_cols, "")
        + "\n      "
        + format("".join(rows), "")
        + "\n    </table>\n  </div>\n  <div class=\"card\">\n    <h4>"
        + format(flow_title, "")
        + "</h4>\n    <div class=\"arrow-chain\">"
        + format(escape(`flow), "")
        + "</div>\n  </div>\n</div>";
}

impl section_keywords(nodes: list, limit: int = 5) -> list {
    counts: any = Counter();
    stopwords: any = {
        "the",
        "and",
        "for",
        "with",
        "from",
        "this",
        "that",
        "class",
        "function",
        "method",
        "file",
        "src",
        "lib",
        "core",
        "index",
        "main",
        "init",
        "py",
        "ts",
        "tsx",
        "js",
        "jsx",
        "go",
        "rs",
        "java",
        "html",
        "css",
    };
    for `node in nodes {
        text: any = (
            format(`node.get("label", ""), "") + " " + format(`node.get("source_file", ""), "")
        ).replace("/", " ").replace("_", " ").replace("-", " ");
        for raw in text.split() {
            word: any = "".join(ch for ch in raw.lower() if ch.isalnum());
            if len(word) < 3 or word in stopwords {
                continue;
            }
            counts[word] += 1;
        }
    }
    return [word for (word, _) in counts.most_common(limit)];
}

impl generate_section_intro(sec: dict, nodes: list, edge_count: int, lang: str) -> str {
    file_counts: any = Counter(n.get("source_file") for n in nodes if n.get("source_file"));
    files: any = [safe_file_path(path) for (path, _) in file_counts.most_common(3)];
    keywords: any = section_keywords(nodes, 4);
    if is_zh(lang) {
        file_text: any = "、".join(files) if files else "未标注源文件";
        keyword_text: any = "、".join(keywords) if keywords else sec.get("name", sec["id"]);
        text: any = format(sec.get("name", sec["id"]), "")
            + " 汇集了与 "
            + format(keyword_text, "")
            + " 相关的实现，主要分布在 "
            + format(file_text, "")
            + "。本节覆盖 "
            + format(len(nodes), "")
            + " 个节点、"
            + format(edge_count, "")
            + " 条内部边，图中只展示最有代表性的调用关系以保持可读性。";
    } else {
        file_text = ", ".join(files) if files else "unmapped files";
        keyword_text = ", ".join(keywords) if keywords else sec.get("name", sec["id"]);
        text = format(sec.get("name", sec["id"]), "")
            + " groups implementation around "
            + format(keyword_text, "")
            + ", mostly in "
            + format(file_text, "")
            + ". This section covers "
            + format(len(nodes), "")
            + " nodes and "
            + format(edge_count, "")
            + " internal edges; the diagram shows only representative relationships to stay readable.";
    }
    return f"<p>{escape(text)}</p>";
}

impl generate_section_cards(sec: dict, nodes: list, section_edges: list, lang: str) -> str {
    file_counts: any = defaultdict(int);
    for n in nodes {
        source_file: any = n.get("source_file") or "";
        if source_file {
            file_counts[source_file] += 1;
        }
    }
    top_files: any = sorted(
        file_counts.items(), key=lambda (item) -> any { (-item[1], item[0]) }
    )[:8];
    if top_files {
        file_rows: any = "\n".join(
            "<tr><td><code>"
                + format(escape(safe_file_path(path)), "")
                + "</code></td><td>"
                + format(count, "")
                + " "
                + format(escape(pick_text(lang, "个节点", "nodes")), "")
                + "</td></tr>"
            for (path, count) in top_files,
        );
    } else {
        file_rows = "<tr><td colspan=\"2\">"
            + format(escape(pick_text(lang, "无源文件映射", "No source file mapping")), "")
            + "</td></tr>";
    }

    relation_counts: any = Counter(
        `edge.get("relation", "relates") for `edge in section_edges if should_include_edge(`edge)
    );
    relation_text: any = ", ".join(
        f"{relation_label(rel, lang)} x{count}" for (rel, count) in relation_counts.most_common(4)
    );
    if not relation_text {
        relation_text = pick_text(lang, "未检测到高置信调用边", "No high-confidence call edges detected");
    }
    note: any = pick_text(
        lang,
        f"本节由 graphify 社区聚类生成。关系概况：{relation_text}。图表优先展示高置信、跨节点调用或使用关系，完整节点清单位于表格中。",
        f"This section comes from graphify community clustering. Relationship summary: {relation_text}. The diagram prioritizes high-confidence calls or usage relationships; the table keeps the broader node inventory.",
    );
    key_files: any = pick_text(lang, "关键文件", "Key Files");
    role: any = pick_text(lang, "覆盖节点", "Coverage");
    design_notes: any = pick_text(lang, "设计备注", "Design Notes");
    return f"<div class=\"grid\">\n  <div class=\"card\">\n    <h4>{key_files}</h4>\n    <table style=\"width:100%;font-size:0.85rem;\">\n      <tr><th>File</th><th>{role}</th></tr>\n      {file_rows}\n    </table>\n  </div>\n  <div class=\"card\">\n    <h4>{design_notes}</h4>\n    <p>{escape(note)}</p>\n  </div>\n</div>";
}

impl CallflowOptions.init(
    project: str | Path | None = None,
    *,
    graphify_out: str | Path | None = None,
    `graph: str | Path | None = None,
    `report: str | Path | None = None,
    labels: str | Path | None = None,
    sections: str | Path | None = None,
    output: str | Path | None = None,
    lang: str = "auto",
    max_sections: int = 15,
    diagram_scale: float = 1.0,
    max_diagram_nodes: int = 18,
    max_diagram_edges: int = 24,
) {
    self.project = `str(project) if project is not None else None;
    self.graphify_out = `str(graphify_out) if graphify_out is not None else None;
    self.graph = `str(`graph) if `graph is not None else None;
    self.report = `str(`report) if `report is not None else None;
    self.labels = `str(labels) if labels is not None else None;
    self.sections = `str(sections) if sections is not None else None;
    self.output = `str(output) if output is not None else None;
    self.lang = lang;
    self.max_sections = max_sections;
    self.diagram_scale = diagram_scale;
    self.max_diagram_nodes = max_diagram_nodes;
    self.max_diagram_edges = max_diagram_edges;
}

impl CallflowOptions.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl CallflowOptions.__eq__(other: any) -> bool {
    return self is other;
}

impl CallflowOptions.__hash__ -> int {
    return id(self);
}

impl _report_highlights(report_text: str, lang: str) -> str {
    if not report_text.strip() {
        return "";
    }

    lines: any = report_text.splitlines();
    keep: list[str] = [];
    in_gods: any = False;
    in_summary: any = False;
    for line in lines {
        stripped: any = line.strip();
        if stripped.startswith("## ") {
            in_summary = operator.eq(stripped, "## Summary");
            in_gods = stripped.startswith("## God Nodes");
            continue;
        }
        if in_summary and stripped.startswith("- ") {
            keep.append(stripped[2:]);
        } elif in_gods and re.match("^\\d+\\.", stripped) {
            keep.append(stripped);
        }
        if len(keep) >= 6 {
            break;
        }
    }

    if not keep {
        return "";
    }

    title: any = pick_text(lang, "图谱报告摘要", "Graph Report Highlights");
    items: any = "\n".join(f"      <li>{escape(item)}</li>" for item in keep);
    return f"<div class=\"card\">\n    <h4>{title}</h4>\n    <ul>\n{items}\n    </ul>\n  </div>";
}

impl write_callflow_html(
    project: str | Path | None = None,
    *,
    graphify_out: str | Path | None = None,
    `graph: str | Path | None = None,
    `report: str | Path | None = None,
    labels: str | Path | None = None,
    sections: str | Path | None = None,
    output: str | Path | None = None,
    lang: str = "auto",
    max_sections: int = 15,
    diagram_scale: float = 1.0,
    max_diagram_nodes: int = 18,
    max_diagram_edges: int = 24,
    verbose: bool = False,
) -> Path {
    args: any = CallflowOptions(
        project,
        graphify_out=graphify_out,
        graph=`graph,
        report=`report,
        labels=labels,
        sections=sections,
        output=output,
        lang=lang,
        max_sections=max_sections,
        diagram_scale=diagram_scale,
        max_diagram_nodes=max_diagram_nodes,
        max_diagram_edges=max_diagram_edges,
    );

    paths: any = resolve_graphify_paths(args);
    if not paths["graph"].exists() {
        raise FileNotFoundError(
            "graphify output not found: "
                + format(paths["graph"], "")
                + ". Run graphify first or pass --graph /path/to/graph.json.",
        );
    }
    nodes: any;
    edges: any;
    hyperedges: any;
    meta: any;
    (nodes, edges, hyperedges, meta) = load_graph(paths["graph"]) as any;
    labels = load_labels(paths["labels"]);
    lang = detect_lang(args.lang, nodes, labels);
    if paths["sections"] {
        sections = load_sections(paths["sections"]);
    } else {
        sections = derive_sections_from_communities(nodes, labels, lang, args.max_sections);
    }
    sections = normalize_sections(sections, lang);
    report_text: any = load_report(paths["report"]);

    if not nodes {
        raise ValueError("graph.json contains 0 nodes");
    }
    if len(sections) <= 1 {
        raise ValueError("no sections defined");
    }

    if verbose and len(nodes) >= 5000 {
        print(
            "WARNING: Large graph -- Mermaid rendering may be slow. Consider --max-sections 5.",
            file=sys.stderr,
        );
    }

    node_ids: any = {`node.get("id") for `node in nodes};
    missing_endpoint_edges: any = [
        `edge
        for `edge in edges
        if `edge.get("source") not in node_ids or `edge.get("target") not in node_ids
    ];
    if verbose and missing_endpoint_edges {
        print(
            f"WARNING: {len(missing_endpoint_edges)} edges reference nodes not present in graph.json.",
            file=sys.stderr,
        );
    }

    meta["project_name"] = infer_project_name(`str(paths["graph"]), meta);
    meta["node_count"] = len(nodes);
    meta["edge_count"] = len(edges);
    meta["hyperedge_count"] = len(hyperedges);

    if args.output {
        output_path: any = Path(args.output).expanduser();
        if not output_path.is_absolute() {
            output_path = paths["base"] / output_path;
        }
    } else {
        output_path = paths["graphify_out"]
            / (format(safe_filename(meta["project_name"]), "") + "-callflow.html");
    }

    if verbose {
        print(f"Loaded: {len(nodes)} nodes, {len(edges)} edges, {len(sections)} sections");
        print("Graph: " + format(paths["graph"], ""));
    }
    comm_idx: any = build_community_index(nodes);
    meta["community_count"] = len(comm_idx);
    section_nodes_map: any = build_section_node_map(sections, comm_idx);
    classified: any = classify_edges(edges, section_nodes_map);
    html: any = [];
    doc_title: any = format(meta.get("project_name", "Project"), "") + " — 完整调用流程与架构文档"
        if lang.startswith("zh")
        else format(meta.get("project_name", "Project"), "")
            + " — Complete Call Flow & Architecture Documentation";
    html.append(
        f"<!DOCTYPE html>\n<html lang=\"{escape(lang, quote=True)}\">\n<head>\n<meta charset=\"UTF-8\">\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n<title>{escape(doc_title)}</title>\n<script src=\"https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js\"></script>\n<style>\n{CSS}\n</style>\n</head>\n<body>\n<div class=\"container\">\n",
    );
    html.append(generate_header(sections, meta, lang));
    overview_name: any = sections[0].get("name", "Architecture Overview")
        if sections
        else "Architecture Overview";
    html.append(
        f"<!-- ====== Architecture Overview ====== -->\n<h2 id=\"overview\">1. {escape(`str(overview_name))}</h2>\n\n<div class=\"mermaid\">\n",
    );
    html.append(
        generate_overview_graph(
            sections, section_nodes_map, classified, labels, lang, args.diagram_scale
        ),
    );
    html.append("</div>\n");
    html.append(
        generate_overview_cards(meta, report_text, sections, section_nodes_map, classified, lang)
    );
    report_card: any = _report_highlights(report_text, lang);
    if report_card {
        html.append(f"<div class=\"grid\">\n  {report_card}\n</div>");
    }
    html.append("<hr>");
    section_num: any = 1;
    for sec in sections {
        if sec["id"] == "overview" {
            continue;
        }
        section_num += 1;
        sid: any = sec["id"];
        name: any = sec.get("name", sid);
        sec_nodes: any = section_nodes_map.get(sid, []);
        sec_edges: any = classified.get("intra", {}).get(sid, []);

        edge_count: any = len(sec_edges);
        h3_title: any = pick_text(lang, "调用明细", "Call Details");
        number_header: any = "#";
        function_header: any = pick_text(lang, "节点", "Node");
        type_header: any = pick_text(lang, "类型", "Type");
        caller_header: any = pick_text(lang, "调用方", "Caller");
        callee_header: any = pick_text(lang, "被调用/依赖", "Callees");
        desc_header: any = pick_text(lang, "说明", "Description");

        html.append(
            f"<!-- ====== {section_num}. {html_comment_text(name)} ====== -->\n<h2 id=\"{escape(`str(sid), quote=True)}\">{section_num}. {escape(`str(name))}</h2>\n{generate_section_intro(sec, sec_nodes, edge_count, lang)}\n\n<div class=\"mermaid\">\n{generate_section_flowchart(sid, name, sec_nodes, sec_edges, lang, args.diagram_scale, args.max_diagram_nodes, args.max_diagram_edges)}\n</div>\n\n<h3>{h3_title}</h3>\n<table class=\"call-table\">\n<tr>\n  <th style=\"width:5%\">{number_header}</th>\n  <th style=\"width:28%\">{function_header}</th>\n  <th style=\"width:10%\">{type_header}</th>\n  <th style=\"width:17%\">{caller_header}</th>\n  <th style=\"width:20%\">{callee_header}</th>\n  <th style=\"width:20%\">{desc_header}</th>\n</tr>\n{generate_call_table_rows(sec_nodes, sec_edges, lang, edges, nodes)}\n</table>\n\n{generate_section_cards(sec, sec_nodes, sec_edges, lang)}\n<hr>\n",
        );
    }
    if hyperedges {
        html.append(
            "<h2 id=\"hyperedges\">Group Relationships (Hyperedges)</h2>\n<div class=\"grid\">\n"
        );
        for he in hyperedges[:9] {
            hid: any = he.get("id", "?");
            hlabel: any = he.get("label", hid);
            hnodes: any = he.get("nodes", []);
            hrel: any = he.get("relation", "");
            html.append(
                f"  <div class=\"card\">\n    <h4>{escape(`str(hlabel))}</h4>\n    <p><code>{escape(`str(hrel))}</code> — {len(hnodes)} participants</p>\n    <ul>",
            );
            for hn in hnodes[:5] {
                html.append(f"      <li><code>{escape(`str(hn))}</code></li>");
            }
            if len(hnodes) > 5 {
                html.append(f"      <li>... and {len(hnodes) - 5} more</li>");
            }
            html.append("    </ul>\n  </div>");
        }
        html.append("</div>\n<hr>");
    }
    total_sections: any = sum(1 for s in sections if s["id"] != "overview");
    html.append(
        "<h2 id=\"stats\">Project Statistics</h2>\n\n<div class=\"grid\">\n  <div class=\"card\">\n    <h4>Graph</h4>\n    <table style=\"width:100%;font-size:0.85rem;\">\n      <tr><td>Nodes</td><td>"
            + format(len(nodes), "")
            + "</td></tr>\n      <tr><td>Edges</td><td>"
            + format(len(edges), "")
            + "</td></tr>\n      <tr><td>Hyperedges</td><td>"
            + format(len(hyperedges), "")
            + "</td></tr>\n      <tr><td>Communities</td><td>"
            + format(len(comm_idx), "")
            + "</td></tr>\n      <tr><td>Documented Sections</td><td>"
            + format(total_sections, "")
            + "</td></tr>\n    </table>\n  </div>\n  <div class=\"card\">\n    <h4>Edge Confidence</h4>\n    <table style=\"width:100%;font-size:0.85rem;\">\n      <tr><td>EXTRACTED</td><td>"
            + format(sum(1 for e in edges if e.get("confidence") == "EXTRACTED"), "")
            + "</td></tr>\n      <tr><td>INFERRED</td><td>"
            + format(sum(1 for e in edges if e.get("confidence") == "INFERRED"), "")
            + "</td></tr>\n      <tr><td>AMBIGUOUS</td><td>"
            + format(sum(1 for e in edges if e.get("confidence") == "AMBIGUOUS"), "")
            + "</td></tr>\n    </table>\n  </div>\n</div>\n",
    );
    html.append(
        "<div style=\"text-align:center; padding:40px 0; color: var(--muted); font-size:0.9rem;\">\n  <p>"
            + format(escape(`str(meta.get("project_name", "Project"))), "")
            + " — Architecture Documentation</p>\n  <p>Generated: "
            + format(datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"), "")
            + " · graphify callflow-html</p>\n</div>\n",
    );
    html.append(
        "</div><!-- .container -->\n\n<script>\n(function () {\n  const mermaidConfig = {\n    startOnLoad: false,\n    theme: 'dark',\n    securityLevel: 'loose',\n    flowchart: { htmlLabels: true, useMaxWidth: true },\n    themeVariables: {\n      primaryColor: '#1e293b',\n      primaryTextColor: '#e2e8f0',\n      primaryBorderColor: '#38bdf8',\n      secondaryColor: '#0f172a',\n      tertiaryColor: '#334155',\n      lineColor: '#64748b',\n      textColor: '#e2e8f0',\n    }\n  };\n\n  mermaid.initialize(mermaidConfig);\n\n  function clamp(value, min, max) {\n    return Math.min(max, Math.max(min, value));\n  }\n\n  function enhanceMermaidDiagrams() {\n    document.querySelectorAll('.mermaid').forEach((container) => {\n      if (container.dataset.zoomReady === 'true') return;\n      const svg = container.querySelector('svg');\n      if (!svg) return;\n\n      container.dataset.zoomReady = 'true';\n      container.classList.add('is-enhanced');\n\n      const viewport = document.createElement('div');\n      viewport.className = 'mermaid-viewport';\n      svg.parentNode.insertBefore(viewport, svg);\n      viewport.appendChild(svg);\n\n      const toolbar = document.createElement('div');\n      toolbar.className = 'mermaid-toolbar';\n      toolbar.innerHTML = [\n        '<button type=\"button\" data-action=\"zoom-out\" title=\"Zoom out\">-</button>',\n        '<span class=\"zoom-level\" data-role=\"level\">100%</span>',\n        '<button type=\"button\" data-action=\"zoom-in\" title=\"Zoom in\">+</button>',\n        '<button type=\"button\" data-action=\"fit\" title=\"Fit width\">Fit</button>',\n        '<button type=\"button\" data-action=\"reset\" title=\"Reset view\">Reset</button>'\n      ].join('');\n      container.insertBefore(toolbar, viewport);\n\n      const state = { scale: 1, x: 0, y: 0, dragging: false, startX: 0, startY: 0, originX: 0, originY: 0 };\n      const level = toolbar.querySelector('[data-role=\"level\"]');\n\n      function applyTransform() {\n        svg.style.transform = `translate(${state.x}px, ${state.y}px) scale(${state.scale})`;\n        level.textContent = `${Math.round(state.scale * 100)}%`;\n      }\n\n      function zoomBy(delta) {\n        state.scale = clamp(state.scale + delta, 0.25, 3);\n        applyTransform();\n      }\n\n      function reset() {\n        state.scale = 1;\n        state.x = 0;\n        state.y = 0;\n        applyTransform();\n      }\n\n      function fitWidth() {\n        const rawWidth = svg.viewBox && svg.viewBox.baseVal && svg.viewBox.baseVal.width\n          ? svg.viewBox.baseVal.width\n          : svg.getBoundingClientRect().width / state.scale;\n        if (!rawWidth) {\n          reset();\n          return;\n        }\n        state.scale = clamp((viewport.clientWidth - 48) / rawWidth, 0.25, 1.4);\n        state.x = 0;\n        state.y = 0;\n        applyTransform();\n      }\n\n      toolbar.addEventListener('click', (event) => {\n        const button = event.target.closest('button[data-action]');\n        if (!button) return;\n        const action = button.dataset.action;\n        if (action === 'zoom-in') zoomBy(0.15);\n        if (action === 'zoom-out') zoomBy(-0.15);\n        if (action === 'fit') fitWidth();\n        if (action === 'reset') reset();\n      });\n\n      viewport.addEventListener('wheel', (event) => {\n        if (!event.ctrlKey && !event.metaKey) return;\n        event.preventDefault();\n        zoomBy(event.deltaY < 0 ? 0.1 : -0.1);\n      }, { passive: false });\n\n      viewport.addEventListener('pointerdown', (event) => {\n        if (event.button !== 0) return;\n        state.dragging = true;\n        state.startX = event.clientX;\n        state.startY = event.clientY;\n        state.originX = state.x;\n        state.originY = state.y;\n        viewport.classList.add('is-dragging');\n        viewport.setPointerCapture(event.pointerId);\n      });\n\n      viewport.addEventListener('pointermove', (event) => {\n        if (!state.dragging) return;\n        state.x = state.originX + event.clientX - state.startX;\n        state.y = state.originY + event.clientY - state.startY;\n        applyTransform();\n      });\n\n      function endDrag(event) {\n        if (!state.dragging) return;\n        state.dragging = false;\n        viewport.classList.remove('is-dragging');\n        if (viewport.hasPointerCapture(event.pointerId)) {\n          viewport.releasePointerCapture(event.pointerId);\n        }\n      }\n\n      viewport.addEventListener('pointerup', endDrag);\n      viewport.addEventListener('pointercancel', endDrag);\n      applyTransform();\n    });\n  }\n\n  function renderMermaid() {\n    const result = mermaid.run\n      ? mermaid.run({ querySelector: '.mermaid' })\n      : Promise.resolve();\n    Promise.resolve(result)\n      .then(enhanceMermaidDiagrams)\n      .catch((error) => {\n        console.error('Mermaid render failed:', error);\n        enhanceMermaidDiagrams();\n      });\n  }\n\n  if (document.readyState === 'loading') {\n    document.addEventListener('DOMContentLoaded', renderMermaid);\n  } else {\n    renderMermaid();\n  }\n})();\n</script>\n\n</body>\n</html>",
    );
    output = "\n".join(html);
    output_path.parent.mkdir(parents=True, exist_ok=True);
    output_path.write_text(output, encoding="utf-8");
    mermaid_count: any = output.count("<div class=\"mermaid\">");
    table_count: any = output.count("<table class=\"call-table\">");
    section_count: any = output.count("<h2 id=");

    if verbose {
        print(f"Call-flow HTML written: {output_path}");
        print(
            f"  Sections: {section_count}  |  Mermaid diagrams: {mermaid_count}  |  Call tables: {table_count}",
        );
        print("  Diagrams use Mermaid init directives plus interactive zoom/pan controls.");
    }

    return output_path;
}

impl main -> any {
    parser: any = argparse.ArgumentParser(
        description="Generate call-flow architecture HTML from graphify knowledge graph outputs"
    );
    parser.add_argument(
        "project", nargs="?", default=None, help="Project root or graphify output directory"
    );
    parser.add_argument("--graphify-out", default=None, help="Path to graphify output directory");
    parser.add_argument("--graph", default=None, help="Path to graph.json");
    parser.add_argument("--report", default=None, help="Path to GRAPH_REPORT.md");
    parser.add_argument("--labels", default=None, help="Path to .graphify_labels.json");
    parser.add_argument(
        "--sections", default=None, help="Path to sections JSON file; auto-derived when omitted"
    );
    parser.add_argument("--output", default=None, help="Output HTML path");
    parser.add_argument(
        "--lang", default="auto", help="HTML language: auto, zh-CN, en, etc. (default: auto)"
    );
    parser.add_argument(
        "--max-sections",
        type=int,
        default=15,
        help="Maximum auto-derived sections, excluding overview",
    );
    parser.add_argument(
        "--diagram-scale",
        type=float,
        default=1.0,
        help="Mermaid-native diagram scale via init directive (0.65-1.8)",
    );
    parser.add_argument(
        "--max-diagram-nodes",
        type=int,
        default=18,
        help="Maximum representative nodes per section diagram",
    );
    parser.add_argument(
        "--max-diagram-edges",
        type=int,
        default=24,
        help="Maximum representative edges per section diagram",
    );
    args: any = parser.parse_args();

    try {
        write_callflow_html(
            args.project,
            graphify_out=args.graphify_out,
            graph=args.graph,
            report=args.report,
            labels=args.labels,
            sections=args.sections,
            output=args.output,
            lang=args.lang,
            max_sections=args.max_sections,
            diagram_scale=args.diagram_scale,
            max_diagram_nodes=args.max_diagram_nodes,
            max_diagram_edges=args.max_diagram_edges,
            verbose=True,
        );
    } except (FileNotFoundError, ValueError, SystemExit) as exc {
        print(f"ERROR: {exc}", file=sys.stderr);
        sys.exit(1);
    }
}
