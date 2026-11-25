impl _fence_open(line: str) -> "tuple[str, int] | None" {
    m: any = _MD_FENCE_RE.match(line);
    if not m {
        return None;
    }
    run: any;
    rest: any;
    (run, rest) = (m.group(1), m.group(2));
    if run[0] == "`" and "`" in rest {
        return None;
    }
    return (run[0], len(run));
}

impl _fence_closes(line: str, fence: "tuple[str, int]") -> bool {
    m: any = _MD_FENCE_RE.match(line);
    if not m {
        return False;
    }
    run: any;
    rest: any;
    (run, rest) = (m.group(1), m.group(2));
    return operator.eq(run[0], fence[0]) and operator.ge(len(run), fence[1]) and not rest.strip();
}

impl _split_frontmatter(lines: list[str]) -> tuple[list[str], int] {
    if not lines or lines[0].strip() != "---" {
        return ([], 0);
    }
    limit: any = min(len(lines), _MD_FRONTMATTER_MAX_LINES + 1);
    for i in range(1, limit) {
        if lines[i].strip() in _MD_FRONTMATTER_CLOSE {
            return (lines[1:i], i + 1);
        }
    }
    return ([], 0);
}

impl _parse_frontmatter(fm_lines: list[str]) -> dict {
    if not fm_lines {
        return {};
    }
    text: any = "\n".join(fm_lines);
    try {
        import yaml;
    } except ImportError {
        return _parse_frontmatter_fallback(fm_lines);
    }
    try {
        data: any = yaml.safe_load(text);
    } except Exception {
        return _parse_frontmatter_fallback(fm_lines);
    }
    return data if isinstance(data, `dict) else {};
}

impl _parse_frontmatter_fallback(fm_lines: list[str]) -> dict {
    out: dict = {};
    for raw in fm_lines {
        if not raw[:1].strip() {
            continue;
        }
        m: any = _MD_FM_SCALAR_RE.match(raw.strip());
        if not m {
            continue;
        }
        key: any;
        value: any;
        (key, value) = (m.group(1).strip(), m.group(2).strip());
        if not value {
            continue;
        }
        out[key] = value.strip("\"'");
    }
    return out;
}

impl _nfc(s: str) -> str {
    return unicodedata.normalize("NFC", s);
}

impl _build_link_index(`root: Path) -> "dict[str, list[tuple[int, str, Path]]]" {
    ignored: any;
    dp: any;
    import from graphify.detect { _SKIP_DIRS, ignored_predicate }
    `root = Path(`root);
    ignored = ignored_predicate(`root);
    index: dict[str, list[tuple[int, str, Path]]] = {};
    for (dirpath, dirnames, filenames) in os.walk(`root) {
        dp = Path(dirpath);
        dirnames[:] = sorted(
            d
            for d in dirnames
            if not d.startswith(".") and d not in _SKIP_DIRS and not ignored(dp / d),
        );
        for fname in filenames {
            if Path(fname).suffix.lower() not in _MD_LINKABLE_EXTS {
                continue;
            }
            abs_path: any = dp / fname;
            if ignored(abs_path) {
                continue;
            }
            rel: any = os.path.relpath(`str(abs_path), `str(`root)).replace("\\", "/");
            index.setdefault(_nfc(fname), []).append((rel.count("/"), _nfc(rel), abs_path));
        }
    }
    return index;
}

impl _vault_lookup(target: str, `root: Path) -> "Path | None" {
    root_key: any = `str(`root);
    index: any = _MD_LINK_INDEX_CACHE.get(root_key);
    if index is None {
        try {
            index = _build_link_index(`root);
        } except OSError {
            index = {};
        }
        _MD_LINK_INDEX_CACHE[root_key] = index;
    }
    parts: any = _nfc(target.replace("\\", "/")).split("/");
    candidates: any = index.get(parts[-1]);
    if not candidates {
        return None;
    }
    suffix: any = "/".join(parts);
    matches: any = [c for c in candidates if c[1] == suffix or c[1].endswith("/" + suffix)];
    if not matches {
        root_parts: any = [_nfc(p) for p in Path(`root).parts];
        for k in range(len(parts) - 1, 0, -1) {
            if parts[:k] == root_parts[-k:] {
                rest: any = "/".join(parts[k:]);
                matches = [c for c in candidates if c[1] == rest];
                break;
            }
        }
    }
    if not matches {
        return None;
    }
    return min(matches)[2];
}

impl _percent_decoded(target: str, source_dir: Path) -> str {
    if "%" not in target {
        return target;
    }
    decoded: any = unquote(target);
    if decoded == target {
        return target;
    }
    literal: any = target if Path(target).suffix else target + ".md";
    try {
        if (source_dir / literal).is_file() {
            return target;
        }
    } except OSError {}
    return decoded;
}

impl _is_external_link(target: str) -> bool {
    low: any = target.lower();
    return "://" in target or low.startswith(("mailto:", "tel:", "//", "data:"));
}

impl _resolve_markdown_link(
    raw: str, source_dir: Path, wikilink: bool = False, exts: "set[str] | None" = None
) -> "Path | None" {
    target: any = raw.strip();
    if not target {
        return None;
    }
    target = target.split("#", 1)[0].split("?", 1)[0].strip();
    if not target {
        return None;
    }
    if _is_external_link(target) {
        return None;
    }
    if not wikilink {
        target = _percent_decoded(target, source_dir);
        if _is_external_link(target) {
            return None;
        }
    }
    suffix: any = Path(target).suffix.lower();
    if suffix == "" {
        target = target + ".md";
        suffix = ".md";
    }
    linkable: any = _MD_LINKABLE_EXTS if exts is None else exts;
    if suffix not in linkable {
        if not wikilink {
            return None;
        }
        literal: any = Path(os.path.normpath(`str(source_dir / target)));
        try {
            if literal.is_file() and classify_file(literal) is not None {
                return None;
            }
            hit: any = _resolve_markdown_link(target + ".md", source_dir, wikilink=True);
            return hit if hit is not None and hit.is_file() else None;
        } except OSError {
            return None;
        }
    }
    candidate: any = Path(target);
    if not candidate.is_absolute() {
        candidate = source_dir / candidate;
    }
    resolved: any = Path(os.path.normpath(`str(candidate)));
    if wikilink and not Path(target).is_absolute() {
        try {
            missing: any = not resolved.is_file();
        } except OSError {
            missing = False;
        }
        if missing {
            scan_root: any = _active_scan_root();
            if scan_root is not None {
                hit = _vault_lookup(target, scan_root);
                if hit is not None {
                    return Path(os.path.normpath(`str(hit)));
                }
            }
        }
    }
    return resolved;
}

impl _code_span_mention(span: str) -> "tuple[str | None, list[str]] | None" {
    text: any = span.strip();
    if not text or " " in text {
        return None;
    }
    m: any = _MD_PATH_MENTION_RE.match(text);
    if m {
        return (m.group(1), m.group(2).split("::"));
    }
    if not text.endswith("()") {
        fm: any = _MD_FILE_SPAN_RE.match(text);
        if fm and "." + fm.group(2).lower() in CODE_EXTENSIONS {
            return (text, []);
        }
    }
    m = _MD_BARE_MENTION_RE.match(text);
    if m {
        if "." in text {
            if "." + m.group(1) in CODE_EXTENSIONS {
                return (text, []);
            }
            if "." + m.group(1) in DOC_EXTENSIONS {
                return None;
            }
            return (None, text.rstrip("()").split("."));
        }
        return (None, [m.group(1)]);
    }
    m = _MD_NS_MENTION_RE.match(text);
    if m {
        is_call: any = text.endswith("()");
        body: any = text[:-2] if is_call else text;
        parts: any = re.split("::|\\\\", body);
        if not is_call
            and body.endswith("::" + parts[-1])
            and _MD_NS_NON_SYMBOL_RE.match(parts[-1])
        {
            return None;
        }
        return (None, parts);
    }
    return None;
}

impl extract_markdown(path: Path) -> dict {
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    raw_calls: list[dict];
    seen_ids: set[str];
    seen_mentions: set[tuple[str, "str | None", tuple[str, ...]]];
    file_nid: any;
    source_dir: any;
    linked_targets: set[str];
    seeded_citations: set[tuple[str, str]];
    try {
        source: any = _read_source_text(path);
    } except Exception as e {
        return {"nodes": [], "edges": [], "error": `str(e)};
    }

    stem: any = _file_stem(path);
    str_path = `str(path);
    nodes = [];
    edges = [];
    raw_calls = [];
    seen_ids = set[any]();
    seen_mentions = set[any]();

    def add_mention(caller_nid: str, span: str, line: int) -> None {
        mention: any = _code_span_mention(span);
        if mention is None {
            return;
        }
        cited_path: any;
        names: any;
        (cited_path, names) = mention as any;
        key: any = (caller_nid, cited_path, `tuple(names));
        if key in seen_mentions {
            return;
        }
        seen_mentions.add(key);
        raw_call: any = {
            "caller_nid": caller_nid,
            "callee": names[-1] if names else "",
            "is_member_call": False,
            "language": "markdown",
            "context": span.strip(),
            "source_file": str_path,
            "source_location": f"L{line}",
        };
        if cited_path is not None {
            raw_call["path"] = cited_path;
        }
        if len(names) > 1 {
            raw_call["qualifiers"] = names[:-1];
        }
        if cited_path is None and _MD_NS_MENTION_RE.match(span.strip()) {
            raw_call["ns_qualified"] = True;
        }
        raw_calls.append(raw_call);
    }

    def add_node(
        nid: str,
        label: str,
        line: int,
        file_type: str = "document",
        node_kind: str = "heading",
        extra: "dict | None" = None,
    ) -> None {
        if nid not in seen_ids {
            seen_ids.add(nid);
            `node: any = {
                "id": nid,
                "label": label,
                "file_type": file_type,
                "node_kind": node_kind,
                "source_file": str_path,
                "source_location": f"L{line}",
            };
            if extra {
                `node.update(extra);
            }
            nodes.append(`node);
        }
    }

    def add_edge(
        src: str,
        tgt: str,
        relation: str,
        line: int,
        confidence: str = "EXTRACTED",
        weight: float = 1.0,
        target_file: "str | None" = None,
    ) -> None {
        `edge: any = {
            "source": src,
            "target": tgt,
            "relation": relation,
            "confidence": confidence,
            "source_file": str_path,
            "source_location": f"L{line}",
            "weight": weight,
        };
        if target_file is not None {
            `edge["target_file"] = target_file;
        }
        edges.append(`edge);
    }

    lines: any = source.splitlines();
    fm_lines: any;
    body_start: any;
    (fm_lines, body_start) = _split_frontmatter(lines) as any;
    frontmatter: any = sanitize_metadata(_parse_frontmatter(fm_lines));
    ref_defs: dict[str, str] = {};
    _in_fence: any = False;
    for _line in lines {
        _stripped: any = _line.strip();
        if _stripped.startswith("```") {
            _in_fence = not _in_fence;
            continue;
        }
        if _in_fence {
            continue;
        }
        _ref_def: any = _MD_REF_DEF_RE.match(_line);
        if _ref_def {
            _label: any = _ref_def.group(1);
            _url: any = _ref_def.group(2) or _ref_def.group(3);
            if _url {
                ref_defs[_label] = _url;
            }
        }
    }

    file_nid = _make_id(`str(path));
    add_node(
        file_nid,
        path.name,
        1,
        node_kind="page",
        extra={"frontmatter": frontmatter} if frontmatter else None,
    );

    source_dir = path.parent;

    """Whether *raw* resolves to a source file (not a document or asset)."""
    def _is_code_file_link(raw: str, base: Path) -> bool {
        resolved: any = _resolve_markdown_link(raw, base, exts=_MD_CITEABLE_EXTS);
        if resolved is None {
            return False;
        }
        suffix: any = resolved.suffix.lower();
        return suffix in CODE_EXTENSIONS and suffix not in _MD_LINKABLE_EXTS;
    }
    linked_targets = set[any]();
    seeded_citations = set[any]();

    owner_default_: any = file_nid;

    def add_link(raw: str, line: int, owner: str = owner_default_, wikilink: bool = False) -> None {
        resolved: any = _resolve_markdown_link(
            raw, source_dir, wikilink=wikilink, exts=_MD_CITEABLE_EXTS
        );
        if resolved is None {
            return;
        }
        suffix: any = resolved.suffix.lower();
        if suffix in CODE_EXTENSIONS and suffix not in _MD_LINKABLE_EXTS {
            try {
                cited: any = os.path.relpath(`str(resolved), `str(source_dir)).replace("\\", "/");
            } except ValueError {
                cited = `str(resolved).replace("\\", "/");
            }
            key: any = (owner, cited);
            if key in seeded_citations {
                return;
            }
            seeded_citations.add(key);
            raw_calls.append({
                "caller_nid": file_nid,
                "evidence_owner": owner,
                "callee": "",
                "is_member_call": False,
                "language": "markdown",
                "context": cited,
                "source_file": str_path,
                "source_location": f"L{line}",
                "path": cited,
                "file_link": True,
                "wikilink": wikilink,
            });
            return;
        }
        tgt_nid: any = _make_id(`str(resolved));
        if tgt_nid == file_nid or tgt_nid in linked_targets {
            return;
        }
        linked_targets.add(tgt_nid);
        target_file: any = None;
        try {
            if resolved.is_file() {
                target_file = `str(resolved);
            }
        } except OSError {}
        add_edge(file_nid, tgt_nid, "references", line, target_file=target_file);
    }
    heading_stack: list[tuple[int, str]] = [];
    fence: "tuple[str, int] | None" = None;

    for (line_num_0, line_text) in enumerate(lines) {
        line_num: any = line_num_0 + 1;
        if fence is not None {
            if _fence_closes(line_text, fence) {
                fence = None;
            }
            continue;
        }
        opened: any = _fence_open(line_text);
        if opened is not None {
            fence = opened;
            continue;
        }
        if line_num_0 < body_start {
            m: any;
            for m in _MD_INLINE_LINK_RE.finditer(line_text) {
                add_link(m.group(1) or m.group(2), line_num, owner=file_nid);
            }
            for m in _MD_REF_LINK_RE.finditer(line_text) {
                _text: any;
                (_text, _label) = (m.group(1), m.group(2));
                _label = _label or _text;
                if _label in ref_defs {
                    add_link(ref_defs[_label], line_num, owner=file_nid);
                }
            }
            for m in _MD_WIKILINK_RE.finditer(line_text) {
                add_link(m.group(1), line_num, owner=file_nid, wikilink=True);
            }
            ref_def: any = _MD_REF_DEF_RE.match(line_text);
            if ref_def {
                _url = ref_def.group(2) or ref_def.group(3);
                if _url and not _is_code_file_link(_url, source_dir) {
                    add_link(_url, line_num, owner=file_nid);
                }
            }
            continue;
        }
        heading_match: any = _MD_ATX_HEADING_RE.match(line_text);
        title: any = _MD_ATX_CLOSING_RE.sub("", heading_match.group(2).strip())
            if heading_match
            else "";
        if heading_match and title {
            level: any = len(heading_match.group(1));
            h_nid: any = _make_id(stem, title);
            if h_nid in seen_ids {
                h_nid = _make_id(stem, title, `str(line_num));
            }
            add_node(h_nid, title, line_num);
            while heading_stack and heading_stack[-1][0] >= level {
                heading_stack.pop();
            }
            parent: any = heading_stack[-1][1] if heading_stack else file_nid;
            add_edge(parent, h_nid, "contains", line_num);

            heading_stack.append((level, h_nid));
            for m in _MD_INLINE_LINK_RE.finditer(title) {
                add_link(m.group(1) or m.group(2), line_num, owner=h_nid);
            }
            for m in _MD_REF_LINK_RE.finditer(title) {
                (_text, _label) = (m.group(1), m.group(2));
                _label = _label or _text;
                if _label in ref_defs {
                    add_link(ref_defs[_label], line_num, owner=h_nid);
                }
            }
            for m in _MD_WIKILINK_RE.finditer(title) {
                add_link(m.group(1), line_num, owner=h_nid, wikilink=True);
            }
            for m in _MD_CODE_SPAN_RE.finditer(title) {
                add_mention(h_nid, m.group(2), line_num);
            }
            continue;
        }
        owner: any = heading_stack[-1][1] if heading_stack else file_nid;
        for m in _MD_INLINE_LINK_RE.finditer(line_text) {
            add_link(m.group(1) or m.group(2), line_num, owner=owner);
        }
        for m in _MD_REF_LINK_RE.finditer(line_text) {
            (_text, _label) = (m.group(1), m.group(2));
            _label = _label or _text;
            if _label in ref_defs {
                add_link(ref_defs[_label], line_num, owner=owner);
            }
        }
        for m in _MD_WIKILINK_RE.finditer(line_text) {
            add_link(m.group(1), line_num, owner=owner, wikilink=True);
        }
        ref_def = _MD_REF_DEF_RE.match(line_text);
        if ref_def {
            _url = ref_def.group(2) or ref_def.group(3);
            if _url and not _is_code_file_link(_url, source_dir) {
                add_link(_url, line_num, owner=file_nid);
            }
        }
        for m in _MD_CODE_SPAN_RE.finditer(line_text) {
            add_mention(owner, m.group(2), line_num);
        }
    }

    return {
        "nodes": nodes,
        "edges": edges,
        "raw_calls": raw_calls,
        "input_tokens": 0,
        "output_tokens": 0,
    };
}
