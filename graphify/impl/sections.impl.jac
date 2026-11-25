impl _headings(lines: list[str]) -> list[tuple[int, int, str]] {
    _: any;
    body_start: any;
    (_, body_start) = _split_frontmatter(lines) as any;
    out: list[tuple[int, int, str]] = [];
    fence: any = None;
    for (i, text) in enumerate(lines) {
        if fence is not None {
            if _fence_closes(text, fence) {
                fence = None;
            }
            continue;
        }
        opened: any = _fence_open(text);
        if opened is not None {
            fence = opened;
            continue;
        }
        if i < body_start {
            continue;
        }
        m: any = _MD_ATX_HEADING_RE.match(text);
        title: any = _MD_ATX_CLOSING_RE.sub("", m.group(2).strip()) if m else "";
        if m and title {
            out.append((i + 1, len(m.group(1)), title));
        }
    }
    return out;
}

impl _resolve_inside(source_file: str, `root: Path) -> "Path | None" {
    candidate: any = Path(source_file);
    if not candidate.is_absolute() {
        candidate = `root / candidate;
    }
    try {
        resolved: any = candidate.resolve();
        resolved.relative_to(`root.resolve());
    } except (OSError, RuntimeError, ValueError) {
        return None;
    }
    return resolved;
}

impl section_root(gp: Path) -> Path {
    GRAPHIFY_OUT: any = importlib.import_module("graphify.paths").GRAPHIFY_OUT;
    graph_root_for: any = importlib.import_module("graphify.paths").graph_root_for;

    `root: any = graph_root_for(gp);
    out: any = Path(GRAPHIFY_OUT).parts;
    if out and not Path(GRAPHIFY_OUT).is_absolute() and gp.parent.parts[-len(out):] == out {
        project: any = gp.parent.parents[len(out) - 1];
        try {
            `root.resolve().relative_to(project.resolve());
        } except (OSError, RuntimeError, ValueError) {
            return project;
        }
    }
    return `root;
}

impl is_section_node(`node: dict) -> bool {
    kind: any = `node.get("node_kind");
    suffix: any = Path(`str(`node.get("source_file") or "")).suffix.lower();
    return kind in ("heading", "page") and suffix in _MARKDOWN_SUFFIXES;
}

impl read_section(
    `node: dict, `root: Path, max_chars: int = max_chars_default_
) -> "tuple[Section | None, str]" {
    start: any;
    level: any;
    label: any = `str(`node.get("label") or "");
    source_file: any = `str(`node.get("source_file") or "");
    if not is_section_node(`node) {
        return (
            None,
            f"'{label}' is not a Markdown heading or page. get_section reads Markdown sections only.",
        );
    }
    if `node.get("repo") {
        return (
            None,
            f"'{label}' comes from a merged multi-repo graph. Read it from that repo's own graph.",
        );
    }
    path: any = _resolve_inside(source_file, `root);
    if path is None {
        return (None, f"Refusing to read '{source_file}': it is outside the project.");
    }
    try {
        lines: any = _read_source_text(path, warn=False).splitlines();
    } except (OSError, UnicodeError) as exc {
        return (None, f"Could not read {source_file}: {exc}");
    }

    moved: any = False;
    if `node.get("node_kind") == "page" {
        _: any;
        body_start: any;
        (_, body_start) = _split_frontmatter(lines) as any;
        end: any;
        (start, end) = (body_start + 1, len(lines));
    } else {
        m: any = _LINE_RE.match(`str(`node.get("source_location") or "").strip());
        recorded: any = `int(m.group(1)) if m else 0;
        heads: any = _headings(lines);
        same: any = [
            h
            for h in heads
            if h[2] == label or sanitize_label(h[2]) == sanitize_label(label)
        ];
        exact: any = [h for h in same if h[0] == recorded];
        hit: any = exact[0] if exact else same[0] if len(same) == 1 else None;
        if hit is None {
            return (
                None,
                f"'{label}' is no longer at line {recorded} of {source_file}. Run `graphify update .` to refresh the graph.",
            );
        }
        moved = operator.ne(hit[0], recorded);
        (start, level) = (hit[0], hit[1]);
        end = next((ln - 1 for (ln, lv, _) in heads if ln > start and lv <= level), len(lines));
    }
    while end > start and not lines[end - 1].strip() {
        end -= 1;
    }
    if end < start {
        return (None, f"{source_file} has no text for '{label}'.");
    }
    body: any = "\n".join(_BODY_CONTROL_RE.sub("", ln) for ln in lines[start - 1:end]);
    body = redact_secrets(body);
    truncated: any = operator.gt(len(body), max_chars);
    if truncated {
        body = body[:max_chars];
    }
    return (Section(sanitize_label(source_file), start, end, body, truncated, moved), "");
}

impl format_section(section: Section, label: str) -> str {
    header: any = f"Section: {label}  [{section.source_file}:L{section.start}-L{section.end}]";
    notes: any = [];
    if section.moved {
        notes.append(
            "The heading moved since indexing; run `graphify update .` to refresh the graph."
        );
    }
    if section.truncated {
        notes.append(
            f"Truncated; read {section.source_file} lines {section.start}-{section.end} for the rest.",
        );
    }
    return "\n".join([header, *(f"Note: {n}" for n in notes), "", section.text]);
}

impl resolve_section_query(G, query: str) -> "tuple[str | None, str]" {
    _resolve_single_node: any = importlib.import_module("graphify.serve")._resolve_single_node;

    nid: any;
    err: any;
    (nid, err) = _resolve_single_node(G, query) as any;
    if nid is not None and is_section_node(G.nodes[nid]) {
        return (nid, "");
    }
    sections: any = G.subgraph([n for (n, d) in G.nodes(data=True) if is_section_node(d)]);
    sections.graph = {
        k: v
        for (k, v) in G.graph.items()
        if not k.startswith("_") or k in _SECTION_VIEW_GRAPH_KEYS
    };
    sec_nid: any;
    _: any;
    (sec_nid, _) = _resolve_single_node(sections, query) as any;
    if sec_nid is not None {
        return (sec_nid, "");
    }
    return (nid, err or "");
}
