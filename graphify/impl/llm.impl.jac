impl _get_tokenizer -> any {
    try {
        import tiktoken;
    } except ImportError {
        return None;
    }
    try {
        return tiktoken.get_encoding("cl100k_base");
    } except Exception {
        return None;
    }
}

impl _estimate_prompt_tokens(text: str) -> int {
    non_latin: any = len(_NON_LATIN_RE.findall(text));
    return (len(text) - non_latin) // _CHARS_PER_TOKEN + non_latin;
}

impl _resolve_ollama_base_url(`default: str) -> str {
    ollama_base_url: any = os.environ.get("OLLAMA_BASE_URL");
    if ollama_base_url is not None {
        return ollama_base_url;
    }
    ollama_host: any = os.environ.get("OLLAMA_HOST");
    if ollama_host is None {
        return `default;
    }
    host: any = ollama_host.strip();
    if not host {
        return `default;
    }
    if host.isdigit() {
        host = f"localhost:{host}";
    } elif host.startswith(":") and host[1:].isdigit() {
        host = f"localhost{host}";
    }
    if not host.startswith(("http://", "https://")) {
        host = f"http://{host}";
    }
    import from urllib.parse { urlsplit, urlunsplit }
    try {
        parts: any = urlsplit(host);
        if parts.hostname and parts.port is None {
            hostname: any = f"[{parts.hostname}]" if ":" in parts.hostname else parts.hostname;
            userinfo: any = parts.netloc.rsplit("@", 1)[0] + "@" if "@" in parts.netloc else "";
            host = urlunsplit(parts._replace(netloc=f"{userinfo}{hostname}:11434"));
        }
    } except (ValueError, TypeError) {}
    host = host.rstrip("/");
    if not host.endswith("/v1") {
        host = f"{host}/v1";
    }
    return host;
}

impl _resolve_ollama_seed -> int | None {
    raw: any = os.environ.get("GRAPHIFY_OLLAMA_SEED");
    if raw is None or not raw.strip() {
        return None;
    }
    value: any = raw.strip();
    max_seed: any = "9223372036854775807";
    normalized: any = value.lstrip("0") or "0";
    if re.fullmatch("[0-9]+", value) is None
        or len(normalized) > len(max_seed)
        or len(normalized) == len(max_seed) and normalized > max_seed
    {
        raise ValueError(
            f"GRAPHIFY_OLLAMA_SEED must be an ASCII integer in the range 0..{max_seed}."
        );
    }
    return `int(normalized);
}

impl _custom_providers_path(global_: bool = True) -> Path {
    if global_ {
        return Path.home() / ".graphify" / "providers.json";
    }
    return Path(".graphify") / "providers.json";
}

impl provider_base_url_ok(base_url: str, name: str, *, warn: bool = True) -> bool {
    import from urllib.parse { urlparse }
    try {
        parsed: any = urlparse(base_url);
    } except Exception {
        if warn {
            print(
                f"[graphify] WARNING: provider {name!r} has an unparseable base_url; ignoring.",
                file=sys.stderr,
            );
        }
        return False;
    }
    if parsed.scheme not in ("http", "https") {
        if warn {
            print(
                f"[graphify] WARNING: provider {name!r} base_url scheme {parsed.scheme!r} is not http/https; ignoring.",
                file=sys.stderr,
            );
        }
        return False;
    }
    host: any = (parsed.hostname or "").lower();
    is_loopback: any = host in ("localhost", "127.0.0.1", "::1") or host.startswith("127.");
    if warn and parsed.scheme == "http" and not is_loopback {
        print(
            f"[graphify] WARNING: provider {name!r} sends your corpus to {host!r} over plaintext http. Use https unless this is a trusted local endpoint.",
            file=sys.stderr,
        );
    }
    return True;
}

impl _load_custom_providers -> dict[str, dict] {
    local_path: any = _custom_providers_path(global_=False);
    global_path: any = _custom_providers_path(global_=True);
    allow_local: any = os.environ.get("GRAPHIFY_ALLOW_LOCAL_PROVIDERS", "").strip().lower()
        in ("1", "true", "yes");
    if local_path.is_file() and not allow_local {
        print(
            f"[graphify] WARNING: ignoring project-local {local_path} (custom providers control where your corpus and API key are sent). Set GRAPHIFY_ALLOW_LOCAL_PROVIDERS=1 to load it.",
            file=sys.stderr,
        );
    }

    providers: dict[str, dict] = {};
    paths: any = [local_path, global_path] if allow_local else [global_path];
    for path in paths {
        if path.is_file() {
            try {
                data: any = json.loads(path.read_text(encoding="utf-8"));
                if isinstance(data, `dict) {
                    cfg: any;
                    for (name, cfg) in data.items() {
                        if not (isinstance(name, `str) and isinstance(cfg, `dict)) {
                            continue;
                        }
                        if name in BACKENDS or name in providers {
                            continue;
                        }
                        if not provider_base_url_ok(`str(cfg.get("base_url", "")), name) {
                            continue;
                        }
                        if "pricing" not in cfg {
                            cfg = `dict(cfg, pricing={"input": 0.0, "output": 0.0});
                        }
                        providers[name] = cfg;
                    }
                }
            } except Exception {}
        }
    }
    return providers;
}

impl _resolve_max_tokens(`default: int) -> int {
    raw: any = os.environ.get("GRAPHIFY_MAX_OUTPUT_TOKENS", "").strip();
    if raw {
        try {
            v: any = `int(raw);
            if v > 0 {
                return v;
            }
        } except ValueError {}
    }
    return `default;
}

impl _openai_max_tokens_kwarg(backend: str, max_tokens: int) -> dict[str, int] {
    key: any = "max_tokens" if backend == "deepseek" else "max_completion_tokens";
    return {key: max_tokens};
}

impl _provider_extra_headers(raw: object, name: str = "") -> dict[str, str] | None {
    if raw is None {
        return None;
    }
    if not isinstance(raw, `dict) {
        print(
            f"[graphify] WARNING: provider {name!r} extra_headers is not an object; ignoring.",
            file=sys.stderr,
        );
        return None;
    }
    headers: dict[str, str] = {};
    for (key, value) in raw.items() {
        if not (isinstance(key, `str) and isinstance(value, `str)) {
            print(
                f"[graphify] WARNING: provider {name!r} extra_headers entry {key!r} is not a string pair; ignoring it.",
                file=sys.stderr,
            );
            continue;
        }
        if key.strip().lower() == "authorization" {
            print(
                f"[graphify] WARNING: provider {name!r} extra_headers cannot set Authorization; ignoring it.",
                file=sys.stderr,
            );
            continue;
        }
        headers[key] = value;
    }
    return headers or None;
}

impl _model_requires_default_temperature(model: str) -> bool {
    m: any = (model or "").lower();
    base: any = m.rsplit("/", 1)[-1];
    if base.startswith("gpt-5") {
        return True;
    }
    for fam in ("o1", "o3", "o4") {
        if base == fam or base.startswith(fam + "-") {
            return True;
        }
    }
    return False;
}

impl _resolve_temperature(`default: float | None, model: str = "") -> float | None {
    raw: any = os.environ.get("GRAPHIFY_LLM_TEMPERATURE", "").strip();
    if raw {
        if raw.lower() in ("none", "omit", "default") {
            return None;
        }
        try {
            return `float(raw);
        } except ValueError {
            print(
                f"[graphify] GRAPHIFY_LLM_TEMPERATURE={raw!r} is not a number or 'none'; falling back to the backend default.",
                file=sys.stderr,
            );
        }
    }
    if _model_requires_default_temperature(model) {
        return None;
    }
    return `default;
}

impl _bedrock_inference_config(max_tokens: int, model: str = "") -> dict {
    cfg: dict = {"maxTokens": max_tokens};
    temp: any = _resolve_temperature(0, model);
    if temp is not None {
        cfg["temperature"] = temp;
    }
    return cfg;
}

impl _no_window_kwargs -> dict {
    import subprocess;
    comptime if target().os == "windows" {
        return {"creationflags": subprocess.CREATE_NO_WINDOW};
    }
    return {};
}

impl _resolve_api_timeout(`default: float = 600.0) -> float {
    raw: any = os.environ.get("GRAPHIFY_API_TIMEOUT", "").strip();
    if raw {
        try {
            v: any = `float(raw);
            if v > 0 {
                return v;
            }
        } except ValueError {}
    }
    return `default;
}

impl _resolve_max_retries(`default: int = 6) -> int {
    raw: any = os.environ.get("GRAPHIFY_MAX_RETRIES", "").strip();
    if raw {
        try {
            v: any = `int(raw);
            if v >= 0 {
                return v;
            }
        } except ValueError {}
    }
    return `default;
}

impl _resolve_max_retry_depth(`default: int = 3) -> int {
    raw: any = os.environ.get("GRAPHIFY_MAX_RETRY_DEPTH", "").strip();
    if raw {
        try {
            v: any = `int(raw);
            if v >= 0 {
                return v;
            }
        } except ValueError {}
    }
    return `default;
}

impl _thinking_disabled_via_env -> bool {
    return os.environ.get("GRAPHIFY_DISABLE_THINKING", "").strip().lower()
        in ("1", "true", "yes", "on");
}

impl _extraction_system(*, deep: bool = False) -> str {
    if not deep {
        return _EXTRACTION_SYSTEM;
    }
    return _EXTRACTION_SYSTEM + _DEEP_EXTRACTION_SUFFIX;
}

impl _file_to_text(path: Path) -> str {
    if path.suffix.lower() == ".pdf" {
        extract_pdf_text: any = importlib.import_module("graphify.detect").extract_pdf_text;
        return extract_pdf_text(path);
    }
    return _read_source_text(path);
}

impl _resolve_under_root(path: Path, `root: Path) -> Path | None {
    try {
        resolved_root: any = `root.resolve();
        resolved_path: any = path.resolve();
        resolved_path.relative_to(resolved_root);
    } except (OSError, RuntimeError, ValueError) {
        return None;
    }
    return resolved_path;
}

impl _neutralise_injection_sentinels(text: str) -> str {
    return _INJECTION_SENTINELS.sub(
        lambda (m) -> any { m.group(0)[0] + "​" + m.group(0)[1:] }, text
    );
}

impl _wrap_untrusted(rel: str, content: str) -> str {
    sha: any = hashlib.sha256(content.encode("utf-8", errors="replace")).hexdigest();
    safe: any = _neutralise_injection_sentinels(content);
    return f"<untrusted_source path=\"{rel}\" sha256=\"{sha}\">\n{safe}\n</untrusted_source>";
}

impl _read_files(units: "list[Path | FileSlice]", `root: Path) -> str {
    parts: list[str] = [];
    for u in units {
        p: any = unit_path(u);
        safe_path: any = _resolve_under_root(p, `root);
        if safe_path is None {
            print(f"[graphify] skipping {p}: symlink target outside corpus root", file=sys.stderr);
            continue;
        }
        try {
            rel: any = p.relative_to(`root).as_posix();
        } except ValueError {
            rel = Path(p).as_posix();
        }
        try {
            if isinstance(u, FileSlice) {
                content: any = read_slice_text(u);
            } else {
                content = _file_to_text(safe_path);
            }
        } except OSError {
            continue;
        }
        if len(content) > _FILE_CHAR_CAP {
            if not _file_truncation_warned {
                _file_truncation_warned = True;
                print(
                    f"[graphify] WARNING: file {rel} exceeds {_FILE_CHAR_CAP} characters and was truncated",
                    file=sys.stderr,
                );
            }
        }
        parts.append(_wrap_untrusted(rel, content[:_FILE_CHAR_CAP]));
    }
    return "\n\n".join(parts);
}

impl _label_identifiers(label: str) -> list[str] {
    if not label {
        return [];
    }
    base: any = label.split("(", 1)[0];
    return [t for t in _LABEL_IDENT_RE.findall(base) if len(t) >= 3];
}

impl _dispatched_source_text(units: "list[Path | FileSlice]", `root: Path) -> dict[Path, str] {
    by_path: dict[Path, str] = {};
    for u in units {
        p: any = unit_path(u);
        safe: any = _resolve_under_root(p, `root);
        if safe is None {
            continue;
        }
        try {
            content: any = read_slice_text(u) if isinstance(u, FileSlice) else _file_to_text(safe);
        } except Exception {
            continue;
        }
        by_path[safe] = by_path.get(safe, "") + content[:_FILE_CHAR_CAP].lower();
    }
    return by_path;
}

impl _bind_node_evidence(result: dict, text_units: "list[Path | FileSlice]", `root: Path) -> int {
    n: any;
    src: any;
    nodes: any = result.get("nodes");
    if not nodes {
        return 0;
    }
    if not `any(
        isinstance(n, `dict) and operator.eq(n.get("file_type"), "code") and n.get("source_file")
        for n in nodes,
    ) {
        return 0;
    }
    source_by_path: any = _dispatched_source_text(text_units, `root);
    if not source_by_path {
        return 0;
    }
    downgraded: any = 0;
    for n in nodes {
        if not isinstance(n, `dict) or n.get("file_type") != "code" {
            continue;
        }
        sf: any = n.get("source_file");
        if not sf {
            continue;
        }
        p: any = Path(sf);
        if not p.is_absolute() {
            p = `root / p;
        }
        try {
            key: any = p.resolve();
        } except (OSError, RuntimeError) {
            continue;
        }
        src = source_by_path.get(key);
        if src is None {
            continue;
        }
        idents: any = _label_identifiers(`str(n.get("label", "")))
            + _label_identifiers(`str(n.get("id", "")));
        if not idents {
            continue;
        }
        if `any(ident.lower() in src for ident in idents) {
            continue;
        }
        _conf: any = n.get("confidence");
        if isinstance(_conf, `str) {
            _conf = _conf.upper();
        }
        if _conf in (None, "", "EXTRACTED") and not n.get(_VERIFICATION_FIELD) {
            n[_VERIFICATION_FIELD] = _UNVERIFIED_VALUE;
            downgraded += 1;
        }
    }
    return downgraded;
}

impl _is_vision_image(path: Path) -> bool {
    return path.suffix.lower() in _VISION_IMAGE_EXTENSIONS;
}

impl _partition_semantic_files(
    units: "list[Path | FileSlice]"
) -> tuple["list[Path | FileSlice]", list[Path]] {
    text_units: any = [u for u in units if isinstance(u, FileSlice) or not _is_vision_image(u)];
    image_files: any = [u for u in units if not isinstance(u, FileSlice) and _is_vision_image(u)];
    return (text_units, image_files);
}

impl _build_image_refs(
    image_files: list[Path], `root: Path, *, read_bytes: bool = True
) -> list[_ImageRef] {
    refs: list[_ImageRef] = [];
    for p in image_files {
        abs_path: any = _resolve_under_root(p, `root);
        if abs_path is None {
            print(
                f"[graphify] skipping image {p}: symlink target outside corpus root",
                file=sys.stderr,
            );
            continue;
        }
        try {
            rel: any = p.relative_to(`root).as_posix();
        } except ValueError {
            rel = Path(p).as_posix();
        }
        media: any = _IMAGE_MEDIA_TYPES.get(p.suffix.lower(), "image/png");
        raw: bytes | None = None;
        if read_bytes {
            try {
                raw = abs_path.read_bytes();
            } except OSError as exc {
                print(f"[graphify] could not read image {rel}: {exc}", file=sys.stderr);
                raw = None;
            }
            if raw is not None and len(raw) > _MAX_IMAGE_BYTES {
                print(
                    f"[graphify] image {rel} is {len(raw) // 1024} KB, over the {_MAX_IMAGE_BYTES // (1024 * 1024)} MB inline-image limit for this backend; sending it as a reference node without inline pixels.",
                    file=sys.stderr,
                );
                raw = None;
            }
        }
        refs.append(_ImageRef(abs_path, rel, media, raw));
    }
    return refs;
}

impl _strip_pixels(refs: list[_ImageRef]) -> list[_ImageRef] {
    return [replace(r, raw=None) for r in refs];
}

impl _backend_supports_vision(backend: str) -> bool {
    if backend == "ollama" {
        return operator.eq(os.environ.get("GRAPHIFY_OLLAMA_VISION", "").strip(), "1");
    }
    return `bool(BACKENDS.get(backend, {}).get("vision", False));
}

impl _image_notes(refs: list[_ImageRef], *, with_paths: bool = False) -> str {
    if not refs {
        return "";
    }
    if with_paths {
        header: any = "Use the Read tool to open and view each image file at the path below, then emit one node per image";
    } else {
        header = "The following image file(s) are attached as visual input. Emit one node per image";
    }
    lines: any = [
        "=== IMAGES ===",
        f"{header} with \"file_type\":\"image\" and the listed source_file, a label describing what it depicts (diagram, screenshot, chart, photo, UI, logo), and edges to any code/doc nodes the image clearly references.",
    ];
    for (i, r) in enumerate(refs, 1) {
        note: any = f"[image {i}] source_file: {r.rel}";
        if with_paths {
            note += f"  path: {r.path}";
        }
        if r.raw is None and not with_paths {
            note += " (not shown: unreadable or exceeds size limit)";
        }
        lines.append(note);
    }
    return "\n".join(lines);
}

impl _with_image_notes(
    user_message: str, refs: list[_ImageRef], *, with_paths: bool = False
) -> str {
    notes: any = _image_notes(refs, with_paths=with_paths);
    if not notes {
        return user_message;
    }
    if not user_message.strip() {
        return notes;
    }
    return f"{user_message}\n\n{notes}";
}

impl _anthropic_content(user_message: str, refs: list[_ImageRef]) -> any {
    blocks: any = [
        {"type": "image", "source": {"type": "base64", "media_type": r.media_type, "data": r.b64}}
        for r in refs
        if r.raw
    ];
    text: any = _with_image_notes(user_message, refs);
    if not blocks {
        return text;
    }
    return [*blocks, {"type": "text", "text": text}];
}

impl _openai_content(user_message: str, refs: list[_ImageRef]) -> any {
    parts: list[dict] = [
        {
            "type": "image_url",
            "image_url": {"url": f"data:{r.media_type};base64,{r.b64}", "detail": "auto"},
        }
        for r in refs
        if r.raw
    ];
    text: any = _with_image_notes(user_message, refs);
    if not parts {
        return text;
    }
    return [{"type": "text", "text": text}, *parts];
}

impl _bedrock_content(user_message: str, refs: list[_ImageRef]) -> list[dict] {
    content: list[dict] = [
        {"image": {"format": r.bedrock_format, "source": {"bytes": r.raw}}}
        for r in refs
        if r.raw
    ];
    content.append({"text": _with_image_notes(user_message, refs)});
    return content;
}

impl _sanitize_fragment(parsed: dict) -> dict {
    for key in ("nodes", "edges", "hyperedges") {
        value: any = parsed.get(key);
        if value is None {
            continue;
        }
        if not isinstance(value, `list) {
            parsed[key] = [];
            continue;
        }
        parsed[key] = [`entry for `entry in value if isinstance(`entry, `dict)];
    }
    hyperedges: any = parsed.get("hyperedges");
    if hyperedges {
        _coerce_hyperedge_member_refs: any = importlib.import_module(
            "graphify.build"
        )._coerce_hyperedge_member_refs;
        for he in hyperedges {
            if isinstance(he.get("nodes"), `list) {
                he["nodes"] = _coerce_hyperedge_member_refs(he, he["nodes"]);
            }
        }
    }
    return parsed;
}

impl _balanced_object(text: str, start: int) -> str | None {
    depth: any = 0;
    in_string: any = False;
    escape: any = False;
    for i in range(start, len(text)) {
        ch: any = text[i];
        if escape {
            escape = False;
            continue;
        }
        if ch == "\\" {
            escape = True;
            continue;
        }
        if ch == "\"" {
            in_string = not in_string;
            continue;
        }
        if in_string {
            continue;
        }
        if ch == "{" {
            depth += 1;
        } elif ch == "}" {
            depth -= 1;
            if depth == 0 {
                return text[start:i + 1];
            }
        }
    }
    return None;
}

impl _json_object_candidates(text: str) -> list[int] {
    idx: any;
    preferred: list[int] = [];
    rest: list[int] = [];
    idx = text.find("{");
    while idx != -1 {
        bucket: any = preferred
            if `any(k in text[idx:idx + 200] for k in _FRAGMENT_KEY_TOKENS)
            else rest;
        if len(bucket) < _MAX_OBJECT_CANDIDATES {
            bucket.append(idx);
        } elif len(preferred) >= _MAX_OBJECT_CANDIDATES and len(rest) >= _MAX_OBJECT_CANDIDATES {
            break;
        }
        idx = text.find("{", idx + 1);
    }
    return preferred + rest;
}

impl _json_fragment_candidates(text: str) -> Generator[any, any, any] {
    for `match in sorted(
        _FENCE_RE.finditer(text),
        key=lambda (m) -> any { m.group(1).strip().lower() not in ("json", "") },
    ) {
        yield (`match.group(2).strip(), `match.start(2), `match.end(2));
    }
    for start in _json_object_candidates(text) {
        blob: any = _balanced_object(text, start);
        if blob is not None {
            yield (blob, start, start + len(blob));
        }
    }
}

impl _parse_llm_json(raw: str) -> dict {
    def is_fragment(candidate: any) -> bool {
        return isinstance(candidate, `dict)
            and `any(_sanitize_fragment(candidate).get(k) for k in _FRAGMENT_KEYS);
    }
    parsed: any;
    start: any;
    end: any;
    cand: any;
    if len(raw) > _LLM_JSON_MAX_BYTES {
        print(
            f"[graphify] LLM response exceeds {_LLM_JSON_MAX_BYTES} bytes ({len(raw)} bytes); refusing to parse and dropping chunk.",
            file=sys.stderr,
        );
        return {"nodes": [], "edges": [], "hyperedges": []};
    }

    stripped: any = _THINK_BLOCK_RE.sub(" ", raw).strip();

    try {
        parsed = json.loads(stripped);
        if isinstance(parsed, `dict) {
            return _sanitize_fragment(parsed);
        }
        if isinstance(parsed, `list) {
            frags: any = [fragment for fragment in parsed if is_fragment(fragment)];
            if len(frags) == 1 {
                return _sanitize_fragment(frags[0]);
            }
            print(
                "[graphify] LLM returned an array instead of one graph fragment; refusing to accept only its first object.",
                file=sys.stderr,
            );
            return {"nodes": [], "edges": [], "hyperedges": []};
        }
    } except json.JSONDecodeError {}
    empty_fragment: dict | None = None;
    fallback: dict | None = None;
    content: list[tuple[dict, int, int]] = [];
    candidate: any;
    for item__ in _json_fragment_candidates(stripped) {
        (candidate, start, end) = item__;
        if `any(
            operator.le(left, start) and operator.le(end, right) for (_, left, right) in content
        ) {
            continue;
        }
        try {
            parsed = json.loads(candidate);
        } except json.JSONDecodeError {
            continue;
        }
        if isinstance(parsed, `list) {
            frags = [fragment for fragment in parsed if is_fragment(fragment)];
            if len(frags) > 1 {
                print(
                    "[graphify] LLM returned an array of graph fragments; refusing to accept only its first object.",
                    file=sys.stderr,
                );
                return {"nodes": [], "edges": [], "hyperedges": []};
            }
            if len(frags) == 1 {
                parsed = frags[0];
            }
        }
        if not isinstance(parsed, `dict) {
            continue;
        }
        if `any(k in parsed for k in _FRAGMENT_KEYS) {
            cand = _sanitize_fragment(parsed);
            if `any(cand.get(k) for k in _FRAGMENT_KEYS) {
                content.append((cand, start, end));
                continue;
            }
            if empty_fragment is None {
                empty_fragment = cand;
            }
        } elif fallback is None {
            fallback = parsed;
        }
    }

    distinct: dict[str, dict] = {};
    for item___ in content {
        (cand, start, end) = item___;
        if `any(
            operator.le(left, start)
                and operator.le(end, right)
                and operator.ne((left, right), (start, end))
            for (_, left, right) in content,
        ) {
            continue;
        }
        signature: any = json.dumps({k: cand.get(k, []) for k in _FRAGMENT_KEYS}, sort_keys=True);
        distinct.setdefault(signature, cand);
    }
    if len(distinct) > 1 {
        print(
            "[graphify] LLM returned multiple independent graph fragments; refusing to cache only the first as a complete extraction.",
            file=sys.stderr,
        );
        return {"nodes": [], "edges": [], "hyperedges": []};
    }
    if distinct {
        return next(iter(distinct.values()));
    }
    for weaker in (empty_fragment, fallback) {
        if weaker is not None {
            return _sanitize_fragment(weaker);
        }
    }

    print(
        f"[graphify] LLM returned invalid JSON, skipping chunk (first 200 chars: {raw[:200]!r})",
        file=sys.stderr,
    );
    return {"nodes": [], "edges": [], "hyperedges": []};
}

impl _anthropic_response_text(content, `default: str | None = None) -> str | None {
    if not content {
        return `default;
    }
    for block in content {
        block_type: any = getattr(block, "type", None);
        if block_type is not None and block_type != "text" {
            continue;
        }
        text: any = getattr(block, "text", None);
        if isinstance(text, `str) and text.strip() {
            return text;
        }
    }
    return `default;
}

impl _bedrock_response_text(resp: dict, `default: str = "") -> str {
    content: any = resp.get("output", {}).get("message", {}).get("content", []);
    if not isinstance(content, `list) {
        return `default;
    }
    for block in content {
        if not isinstance(block, `dict) {
            continue;
        }
        text: any = block.get("text");
        if isinstance(text, `str) and text.strip() {
            return text;
        }
    }
    return `default;
}

impl _response_is_hollow(raw_content: str | None, parsed: dict) -> bool {
    if raw_content is None or not raw_content.strip() {
        return True;
    }
    nodes: any = parsed.get("nodes");
    edges: any = parsed.get("edges");
    hyperedges: any = parsed.get("hyperedges");
    return not nodes and not edges and not hyperedges;
}

impl _mark_hollow(result: dict, raw_content: str | None, backend: str | None) -> dict {
    if _response_is_hollow(raw_content, result) and result.get("finish_reason") != "length" {
        print(
            "[graphify] "
                + format(backend or "backend", "")
                + " returned a hollow response (content="
                + format("empty" if not (raw_content or "").strip() else "no nodes/edges", "")
                + ", output_tokens="
                + format(result.get("output_tokens", 0), "")
                + "); will retry the same chunk (a hollow response is not a size problem, so the chunk is not bisected).",
            file=sys.stderr,
        );
        result["finish_reason"] = "hollow";
    }
    return result;
}

impl _backend_env_keys(backend: str) -> list[str] {
    cfg: any = BACKENDS[backend];
    keys: any = cfg.get("env_keys");
    if keys {
        return `list(keys);
    }
    env_key: any = cfg.get("env_key");
    if env_key {
        return [env_key];
    }
    return [];
}

impl _get_backend_api_key(backend: str) -> str {
    for env_key in _backend_env_keys(backend) {
        value: any = os.environ.get(env_key);
        if value {
            return value;
        }
    }
    return "";
}

impl _format_backend_env_keys(backend: str) -> str {
    keys: any = _backend_env_keys(backend);
    return " or ".join(keys) if keys else "AWS_PROFILE or AWS_REGION";
}

impl _default_model_for_backend(backend: str) -> str {
    cfg: any = BACKENDS[backend];
    model_env_key: any = cfg.get("model_env_key");
    if model_env_key {
        model: any = os.environ.get(model_env_key);
        if model {
            return model;
        }
    }
    return cfg["default_model"];
}

impl _backend_pkg_hint(pkg: str, extra: str) -> str {
    return f"the '{pkg}' package is required for this backend but is not installed. Install it with:  uv tool install \"graphifyy[{extra}]\" --force  (uv tool), or  pip install {pkg}  (pip/venv install).";
}

impl _ollama_request_extras(
    user_message: str, max_completion_tokens: int, system_prompt: str = ""
) -> dict {
    num_ctx_raw: any = os.environ.get("GRAPHIFY_OLLAMA_NUM_CTX", "").strip();
    estimated_input: any = _estimate_prompt_tokens(user_message)
        + _estimate_prompt_tokens(system_prompt);
    auto_num_ctx: any = min(estimated_input + max_completion_tokens + 2000, 131072);
    auto_num_ctx = max(auto_num_ctx, 8192);
    if num_ctx_raw {
        try {
            num_ctx: any = `int(num_ctx_raw);
        } except ValueError {
            print(
                f"[graphify] GRAPHIFY_OLLAMA_NUM_CTX={num_ctx_raw!r} is not a valid integer; using auto-derived value ({auto_num_ctx}).",
                file=sys.stderr,
            );
            num_ctx = auto_num_ctx;
        } else {
            if num_ctx < estimated_input {
                print(
                    f"[graphify] warning: GRAPHIFY_OLLAMA_NUM_CTX={num_ctx} is smaller than the estimated chunk input (~{estimated_input} tokens). Ollama will silently truncate the prompt and return empty responses. Try --token-budget {max(1024, num_ctx // 3)} or increase NUM_CTX.",
                    file=sys.stderr,
                );
            }
        }
    } else {
        num_ctx = auto_num_ctx;
    }
    keep_alive: any = os.environ.get("GRAPHIFY_OLLAMA_KEEP_ALIVE", "30m");
    return {"options": {"num_ctx": num_ctx}, "keep_alive": keep_alive};
}

impl _call_ollama_native(
    client, base_url: str, kwargs: dict, user_message: str, images: list[_ImageRef]
) -> tuple[str | None, int, int, str] | None {
    `root: any = base_url.rstrip("/");
    if `root.endswith("/v1") {
        `root = `root[:-len("/v1")];
    }
    if `root in _OLLAMA_NO_NATIVE {
        return None;
    }
    import from openai { APIStatusError }

    extra: any = kwargs.get("extra_body", {});
    options: any = `dict(extra.get("options", {}));
    options["num_predict"] = kwargs["max_completion_tokens"];
    if "temperature" in kwargs {
        options["temperature"] = kwargs["temperature"];
    }
    if "seed" in kwargs {
        options["seed"] = kwargs["seed"];
    }
    user: dict = {"role": "user", "content": _with_image_notes(user_message, images)};
    pixels: any = [r.b64 for r in images if r.raw];
    if pixels {
        user["images"] = pixels;
    }
    body: dict = {
        "model": kwargs["model"],
        "messages": [*kwargs["messages"][:-1], user],
        "stream": False,
        "options": options,
        "keep_alive": extra.get("keep_alive", "30m"),
    };
    if _thinking_disabled_via_env() {
        body["think"] = False;
    }
    try {
        data: any = client.post(f"{`root}/api/chat", body=body, cast_to=object);
    } except APIStatusError as exc {
        if exc.status_code not in (404, 405) or "model" in `str(exc).lower() {
            raise;
        }
        _OLLAMA_NO_NATIVE.add(`root);
        print(
            f"[graphify] {`root}/api/chat is not available; falling back to the OpenAI-compatible /v1 endpoint, which ignores num_ctx.",
            file=sys.stderr,
        );
        return None;
    }
    data = data or {};
    message: any = data.get("message") or {};
    finish_reason: any = "length" if data.get("done_reason") == "length" else "stop";
    return (
        message.get("content"),
        data.get("prompt_eval_count") or 0,
        data.get("eval_count") or 0,
        finish_reason,
    );
}

impl _call_openai_compat(
    base_url: str,
    api_key: str,
    model: str,
    user_message: str,
    temperature: float | None = 0,
    reasoning_effort: str | None = None,
    max_completion_tokens: int = 8192,
    *,
    backend: str = "",
    deep_mode: bool = False,
    images: list[_ImageRef] | None = None,
    extra_body: dict | None = None,
    extra_headers: dict[str, str] | None = None,
) -> dict {
    ollama_seed: any = _resolve_ollama_seed() if backend == "ollama" else None;
    try {
        import from openai { OpenAI }
    } except ImportError as exc {
        extra: any = backend if backend in ("kimi", "gemini", "openai", "ollama") else "openai";
        raise ImportError(_backend_pkg_hint("openai", extra)) from exc;
    }
    _retries: any = _resolve_max_retries();
    if backend == "ollama" and not os.environ.get("GRAPHIFY_MAX_RETRIES", "").strip() {
        _retries = 0;
    }
    client: any = OpenAI(
        api_key=api_key,
        base_url=base_url,
        timeout=_resolve_api_timeout(),
        max_retries=_retries,
        **({"default_headers": extra_headers} if extra_headers else {}),
    );
    kwargs: dict = {
        "model": model,
        "messages": [
            {"role": "system", "content": _extraction_system(deep=deep_mode)},
            {"role": "user", "content": _openai_content(user_message, images or [])},
        ],
        **_openai_max_tokens_kwarg(backend, max_completion_tokens),
        "stream": False,
    };
    if temperature is not None {
        kwargs["temperature"] = temperature;
    }
    if reasoning_effort is not None {
        kwargs["reasoning_effort"] = reasoning_effort;
    }
    if ollama_seed is not None {
        kwargs["seed"] = ollama_seed;
    }
    if extra_body is not None {
        kwargs["extra_body"] = extra_body;
    } elif "moonshot" in base_url {
        kwargs["extra_body"] = {"thinking": {"type": "disabled"}};
    } elif _thinking_disabled_via_env() {
        kwargs["extra_body"] = {"thinking": {"type": "disabled"}};
    }
    if backend == "ollama" and extra_body is None {
        kwargs["extra_body"] = {
            **kwargs.get("extra_body", {}),
            **_ollama_request_extras(
                user_message, max_completion_tokens, kwargs["messages"][0]["content"]
            ),
        };
    }
    native: any = None;
    if backend == "ollama" and extra_body is None {
        native = _call_ollama_native(client, base_url, kwargs, user_message, images or []);
    }
    if native is not None {
        raw_content: any;
        input_tokens: any;
        output_tokens: any;
        finish_reason: any;
        (raw_content, input_tokens, output_tokens, finish_reason) = native as any;
    } else {
        resp: any = client.chat.completions.create(**kwargs);
        if not resp.choices or resp.choices[0].message is None {
            raise ValueError("LLM returned empty or filtered response");
        }
        raw_content = resp.choices[0].message.content;
        input_tokens = resp.usage.prompt_tokens or 0 if resp.usage else 0;
        output_tokens = resp.usage.completion_tokens or 0 if resp.usage else 0;
        finish_reason = resp.choices[0].finish_reason;
    }
    result: any = _parse_llm_json(raw_content or "{}");
    result["input_tokens"] = input_tokens;
    result["output_tokens"] = output_tokens;
    result["model"] = model;
    result["finish_reason"] = finish_reason;
    _mark_hollow(result, raw_content, backend);
    output_tokens = result["output_tokens"];
    if output_tokens < 50 and backend == "ollama" {
        print(
            "[graphify] warning: ollama returned very few tokens — likely causes: (1) VRAM pressure: check `nvidia-smi` and reduce chunk size with --token-budget (e.g. --token-budget 4096) or set GRAPHIFY_OLLAMA_NUM_CTX to a smaller value; (2) model too small for JSON instruction following — try a larger model with --model (e.g. --model qwen2.5-coder:14b).",
            file=sys.stderr,
        );
    }
    return result;
}

impl _claude_prompt_cache_enabled -> bool {
    raw: any = os.environ.get("GRAPHIFY_CLAUDE_PROMPT_CACHE", "").strip().lower();
    if raw in ("", "1", "true", "yes", "on") {
        return True;
    }
    if raw in ("0", "false", "no", "off") {
        return False;
    }
    raise ValueError("GRAPHIFY_CLAUDE_PROMPT_CACHE must be 1/true/yes/on or 0/false/no/off");
}

impl _call_claude(
    api_key: str,
    model: str,
    user_message: str,
    max_tokens: int = 8192,
    *,
    deep_mode: bool = False,
    images: list[_ImageRef] | None = None,
) -> dict {
    try {
        import anthropic;
    } except ImportError as exc {
        raise ImportError(_backend_pkg_hint("anthropic", "anthropic")) from exc;
    }

    cache_enabled: any = _claude_prompt_cache_enabled();
    client: any = anthropic.Anthropic(
        api_key=api_key,
        base_url=BACKENDS["claude"]["base_url"],
        timeout=_resolve_api_timeout(),
        max_retries=_resolve_max_retries(),
    );
    resp: any = client.messages.create(
        model=model,
        max_tokens=max_tokens,
        system=[
            {
                "type": "text",
                "text": _extraction_system(deep=deep_mode),
                "cache_control": {"type": "ephemeral"},
            },
        ]
            if cache_enabled
            else _extraction_system(deep=deep_mode),
        messages=[{"role": "user", "content": _anthropic_content(user_message, images or [])}],
    );
    raw_content: any = _anthropic_response_text(resp.content);
    result: any = _parse_llm_json(raw_content or "{}");
    usage: any = resp.usage;
    result["input_tokens"] = (usage.input_tokens or 0)
        + (getattr(usage, "cache_read_input_tokens", 0) or 0)
        + (getattr(usage, "cache_creation_input_tokens", 0) or 0)
        if usage
        else 0;
    result["output_tokens"] = usage.output_tokens or 0 if usage else 0;
    result["model"] = model;
    result["finish_reason"] = "length" if resp.stop_reason == "max_tokens" else "stop";
    _mark_hollow(result, raw_content, "claude");
    return result;
}

impl _envelope_after_preamble(stdout: str) -> any {
    decoder: any = json.JSONDecoder();
    for (idx, ch) in enumerate(stdout) {
        if ch not in "[{" {
            continue;
        }
        try {
            value: any;
            _: any;
            (value, _) = decoder.raw_decode(stdout, idx) as any;
        } except json.JSONDecodeError {
            continue;
        }
        if isinstance(value, (`dict, `list)) {
            return value;
        }
    }
    return None;
}

impl _claude_cli_envelope(stdout: str) -> dict {
    try {
        envelope: any = json.loads(stdout);
    } except json.JSONDecodeError as exc {
        envelope = _envelope_after_preamble(stdout);
        if envelope is None {
            raise RuntimeError(
                f"claude -p produced unparseable JSON envelope: {exc}; first 500 chars of stdout: {stdout[:500]!r}",
            ) from exc;
        }
    }
    if isinstance(envelope, `list) {
        result_events: any = [
            e
            for e in envelope
            if isinstance(e, `dict) and e.get("type") == "result"
        ];
        if result_events {
            return result_events[-1];
        }
        if envelope and isinstance(envelope[-1], `dict) {
            return envelope[-1];
        }
        raise RuntimeError(
            f"claude -p returned a JSON array with no result object; first 500 chars of stdout: {stdout[:500]!r}",
        );
    }
    return envelope;
}

impl _claude_cli_error(stdout: str) -> str {
    try {
        envelope: any = _claude_cli_envelope(stdout);
    } except RuntimeError {
        return "";
    }
    if not envelope.get("is_error") {
        return "";
    }
    detail: any = envelope.get("result");
    if isinstance(detail, `str) and detail.strip() {
        return detail.strip();
    }
    return "unspecified error";
}

impl _claude_cli_supports_json_schema(claude_cmd: str) -> bool {
    import subprocess;

    cached: any = _JSON_SCHEMA_SUPPORT.get(claude_cmd);
    if cached is not None {
        return cached;
    }
    try {
        proc: any = subprocess.run(
            [claude_cmd, "--help"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=30,
            check=False,
            **_no_window_kwargs(),
        );
        supported: any = "--json-schema" in (proc.stdout or "");
    } except (OSError, SubprocessError) {
        supported = False;
    }
    _JSON_SCHEMA_SUPPORT[claude_cmd] = supported;
    return supported;
}

impl _call_claude_cli(
    user_message: str,
    max_tokens: int = 8192,
    *,
    deep_mode: bool = False,
    images: list[_ImageRef] | None = None,
) -> dict {
    import platform;
    import shutil;
    import subprocess;
    claude_cmd: any = "claude";
    if platform.system() == "Windows" {
        cmd_path: any = shutil.which("claude.cmd");
        if cmd_path {
            claude_cmd = cmd_path;
        } elif shutil.which("claude") is None {
            raise RuntimeError(
                "Claude Code CLI not found on $PATH. Install from https://claude.ai/code and run `claude` once to authenticate.",
            );
        }
    } elif shutil.which("claude") is None {
        raise RuntimeError(
            "Claude Code CLI not found on $PATH. Install from https://claude.ai/code and run `claude` once to authenticate.",
        );
    }
    add_dir_args: list[str] = [];
    if images {
        user_message = _with_image_notes(user_message, images, with_paths=True);
        seen_dirs: set[str] = set[any]();
        for r in images {
            d: any = `str(r.path.parent);
            if d not in seen_dirs {
                seen_dirs.add(d);
                add_dir_args.extend(["--add-dir", d]);
            }
        }
    }

    combined_message: any = _extraction_system(deep=deep_mode)
        + "\n\n---\n"
        + "Now extract the knowledge graph from the following source file(s) "
        + "and output ONLY the JSON object described above. No prose, no "
        + "preamble, no markdown fences.\n\n"
        + user_message;
    cli_args: any = [
        claude_cmd,
        "-p",
        "--output-format",
        "json",
        "--no-session-persistence",
        *add_dir_args,
    ];
    cli_model: any = os.environ.get("GRAPHIFY_CLAUDE_CLI_MODEL", "").strip();
    if cli_model {
        cli_args.extend(["--model", cli_model]);
    }
    if _claude_cli_supports_json_schema(claude_cmd) {
        cli_args.extend(["--json-schema", _EXTRACTION_JSON_SCHEMA]);
    }
    proc: any = subprocess.run(
        cli_args,
        input=combined_message,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=_resolve_api_timeout(),
        check=False,
        **_no_window_kwargs(),
    );
    cli_error: any = _claude_cli_error(proc.stdout);
    if proc.returncode != 0 {
        detail: any = proc.stderr.strip() or cli_error or "(no stderr, no error envelope)";
        raise RuntimeError(f"claude -p exited {proc.returncode}: {detail[:500]}");
    }
    if cli_error {
        raise RuntimeError(f"claude -p reported an error: {cli_error[:500]}");
    }

    envelope: any = _claude_cli_envelope(proc.stdout);
    structured: any = envelope.get("structured_output");
    if isinstance(structured, `dict) {
        raw_content: any = json.dumps(structured);
    } else {
        raw_content = envelope.get("result", "");
    }
    result: any = _parse_llm_json(raw_content or "{}");
    usage: any = envelope.get("usage") or {};
    result["input_tokens"] = `int(usage.get("input_tokens", 0) or 0)
        + `int(usage.get("cache_read_input_tokens", 0) or 0)
        + `int(usage.get("cache_creation_input_tokens", 0) or 0);
    result["output_tokens"] = `int(usage.get("output_tokens", 0) or 0);
    model_usage: any = envelope.get("modelUsage") or {};
    result["model"] = next(iter(model_usage), "claude-code-plan");
    stop_reason: any = envelope.get("stop_reason", "");
    result["finish_reason"] = "length" if stop_reason == "max_tokens" else "stop";
    _mark_hollow(result, raw_content, "claude-cli");
    return result;
}

impl _azure_client(api_key: str, endpoint: str) -> any {
    try {
        import from openai { AzureOpenAI }
    } except ImportError as exc {
        raise ImportError(
            "Azure OpenAI requires the openai package. Run: pip install openai"
        ) from exc;
    }
    api_version: any = os.environ.get("AZURE_OPENAI_API_VERSION", "2024-12-01-preview").strip();
    timeout_raw: any = os.environ.get("GRAPHIFY_API_TIMEOUT", "").strip();
    timeout_s: float = 600.0;
    if timeout_raw {
        try {
            v: any = `float(timeout_raw);
            if v > 0 {
                timeout_s = v;
            }
        } except ValueError {}
    }
    return AzureOpenAI(
        api_key=api_key,
        azure_endpoint=endpoint,
        api_version=api_version,
        timeout=timeout_s,
        max_retries=_resolve_max_retries(),
    );
}

impl _call_azure(
    api_key: str,
    endpoint: str,
    model: str,
    user_message: str,
    temperature: float | None = 0,
    max_tokens: int = 8192,
    *,
    deep_mode: bool = False,
) -> dict {
    client: any = _azure_client(api_key, endpoint);
    kwargs: dict = {
        "model": model,
        "messages": [
            {"role": "system", "content": _extraction_system(deep=deep_mode)},
            {"role": "user", "content": user_message},
        ],
        "max_completion_tokens": max_tokens,
    };
    if temperature is not None {
        kwargs["temperature"] = temperature;
    }
    resp: any = client.chat.completions.create(**kwargs);
    if not resp.choices or resp.choices[0].message is None {
        raise ValueError("Azure OpenAI returned empty or filtered response");
    }
    raw_content: any = resp.choices[0].message.content;
    result: any = _parse_llm_json(raw_content or "{}");
    result["input_tokens"] = resp.usage.prompt_tokens or 0 if resp.usage else 0;
    result["output_tokens"] = resp.usage.completion_tokens or 0 if resp.usage else 0;
    result["model"] = model;
    result["finish_reason"] = resp.choices[0].finish_reason;
    _mark_hollow(result, raw_content, "azure");
    return result;
}

impl _call_bedrock(
    model: str,
    user_message: str,
    max_tokens: int = 8192,
    *,
    deep_mode: bool = False,
    images: list[_ImageRef] | None = None,
) -> dict {
    try {
        import boto3;
        import botocore.config;
        import botocore.exceptions;
    } except ImportError as exc {
        raise ImportError(
            "AWS Bedrock extraction requires boto3. Run: pip install graphifyy[bedrock]"
        ) from exc;
    }

    region: any = os.environ.get("AWS_REGION")
        or os.environ.get("AWS_DEFAULT_REGION")
        or "us-east-1";
    profile: any = os.environ.get("AWS_PROFILE");
    session: any = boto3.Session(profile_name=profile, region_name=region);
    client: any = session.client(
        "bedrock-runtime",
        config=botocore.config.Config(
            read_timeout=_resolve_api_timeout(),
            connect_timeout=10,
            retries={"max_attempts": _resolve_max_retries() + 1, "mode": "adaptive"},
        ),
    );

    try {
        resp: any = client.converse(
            modelId=model,
            system=[{"text": _extraction_system(deep=deep_mode)}],
            messages=[{"role": "user", "content": _bedrock_content(user_message, images or [])}],
            inferenceConfig=_bedrock_inference_config(max_tokens, model),
        );
    } except botocore.exceptions.ClientError as exc {
        code: any = exc.response["Error"]["Code"];
        msg: any = exc.response["Error"]["Message"];
        raise RuntimeError(f"Bedrock API error ({code}): {msg}") from exc;
    }

    text: any = _bedrock_response_text(resp, default="{}");
    result: any = _parse_llm_json(text);
    usage: any = resp.get("usage", {});
    result["input_tokens"] = usage.get("inputTokens", 0) or 0;
    result["output_tokens"] = usage.get("outputTokens", 0) or 0;
    result["model"] = model;
    result["finish_reason"] = "length" if resp.get("stopReason") == "max_tokens" else "stop";
    _mark_hollow(result, text, "bedrock");
    return result;
}

impl extract_files_direct(
    files: list[Path],
    backend: str | None = None,
    api_key: str | None = None,
    model: str | None = None,
    `root: Path = root_default_,
    *,
    deep_mode: bool = False,
) -> dict {
    files = [f if isinstance(f, (Path, FileSlice)) else Path(f) for f in files];
    if backend is None {
        if backend_disabled_by_env() {
            raise ValueError(
                "LLM backend disabled by GRAPHIFY_BACKEND=none. Unset it (or pass backend= explicitly) to run semantic extraction.",
            );
        }
        backend = detect_backend();
        if backend is None {
            raise ValueError(
                "No LLM backend configured. Set one of: GEMINI_API_KEY, ANTHROPIC_API_KEY, OPENAI_API_KEY, DEEPSEEK_API_KEY, MOONSHOT_API_KEY, AZURE_OPENAI_API_KEY+AZURE_OPENAI_ENDPOINT, OLLAMA_BASE_URL, or AWS credentials. Pass backend= explicitly to select a provider.",
            );
        }
    }
    if backend not in BACKENDS {
        raise ValueError(f"Unknown backend {backend!r}. Available: {sorted(BACKENDS)}");
    }

    cfg: any = BACKENDS[backend];
    key: any = api_key or _get_backend_api_key(backend);
    if not key and backend == "ollama" {
        ollama_url: any = _resolve_ollama_base_url(cfg.get("base_url", ""));
        _validate_ollama_base_url(ollama_url);
        print(
            f"[graphify] WARNING: ollama backend selected with no OLLAMA_API_KEY set; sending corpus to {ollama_url}. Set OLLAMA_API_KEY (any non-empty value) to suppress this warning.",
            file=sys.stderr,
        );
        key = "ollama";
    }
    if not key and backend not in ("bedrock", "claude-cli") {
        raise ValueError(
            f"No API key for backend '{backend}'. Set {_format_backend_env_keys(backend)} or pass api_key=.",
        );
    }
    mdl: any = model or _default_model_for_backend(backend);
    text_files: any;
    image_files: any;
    (text_files, image_files) = _partition_semantic_files(files) as any;
    user_msg: any = _read_files(text_files, `root);
    vision: any = _backend_supports_vision(backend);
    read_bytes: any = vision and backend not in _PATH_IMAGE_BACKENDS;
    image_refs: any = _build_image_refs(image_files, `root, read_bytes=read_bytes)
        if image_files
        else [];
    if image_refs and not vision {
        image_refs = _strip_pixels(image_refs);
    }
    max_out: any = _resolve_max_tokens(cfg.get("max_tokens", 8192));

    if backend == "claude" {
        result: any = _call_claude(
            key, mdl, user_msg, max_tokens=max_out, deep_mode=deep_mode, images=image_refs
        );
    } elif backend == "claude-cli" {
        result = _call_claude_cli(
            user_msg, max_tokens=max_out, deep_mode=deep_mode, images=image_refs
        );
    } elif backend == "bedrock" {
        result = _call_bedrock(
            mdl, user_msg, max_tokens=max_out, deep_mode=deep_mode, images=image_refs
        );
    } elif backend == "azure" {
        endpoint: any = os.environ.get("AZURE_OPENAI_ENDPOINT", "").strip();
        if not endpoint {
            raise ValueError(
                "Azure OpenAI backend requires AZURE_OPENAI_ENDPOINT to be set (e.g. https://my-resource.openai.azure.com/).",
            );
        }
        result = _call_azure(
            key,
            endpoint,
            mdl,
            user_msg,
            temperature=_resolve_temperature(cfg.get("temperature", 0), mdl),
            max_tokens=max_out,
            deep_mode=deep_mode,
        );
    } else {
        result = _call_openai_compat(
            cfg["base_url"],
            key,
            mdl,
            user_msg,
            temperature=_resolve_temperature(cfg.get("temperature", 0), mdl),
            reasoning_effort=cfg.get("reasoning_effort"),
            max_completion_tokens=_resolve_max_tokens(
                cfg.get("max_completion_tokens") or cfg.get("max_tokens", 8192)
            ),
            backend=backend,
            deep_mode=deep_mode,
            images=image_refs,
            extra_body=cfg.get("extra_body"),
            extra_headers=_provider_extra_headers(cfg.get("extra_headers"), backend),
        );
    }
    if isinstance(result, `dict) {
        try {
            _n_unverified: any = _bind_node_evidence(result, text_files, `root);
            if _n_unverified {
                print(
                    f"[graphify] {_n_unverified} semantic node(s) had no evidence in the source and were flagged verification=unverified",
                    file=sys.stderr,
                );
            }
        } except Exception as _exc {
            print(f"[graphify] evidence-binding skipped: {_exc}", file=sys.stderr);
        }
    }
    return result;
}

impl _pdf_text_for_estimate(path: Path) -> str {
    try {
        st: any = path.stat();
        key: any = (`str(path), st.st_size, st.st_mtime_ns);
    } except OSError {
        return "";
    }
    hit: any = _PDF_ESTIMATE_CACHE.get(key);
    if hit is not None {
        return hit;
    }
    text: any = _file_to_text(path);
    if len(_PDF_ESTIMATE_CACHE) >= _PDF_ESTIMATE_CACHE_MAX {
        _PDF_ESTIMATE_CACHE.clear();
    }
    _PDF_ESTIMATE_CACHE[key] = text;
    return text;
}

impl _estimate_file_tokens(unit: "Path | FileSlice") -> int {
    if isinstance(unit, FileSlice) {
        if _TOKENIZER is None {
            return (min(unit.end - unit.start, _FILE_CHAR_CAP) + _PER_FILE_OVERHEAD_CHARS)
                // _CHARS_PER_TOKEN;
        }
        try {
            content: any = read_slice_text(unit)[:_FILE_CHAR_CAP];
        } except OSError {
            return 0;
        }
        return len(_TOKENIZER.encode(content, disallowed_special=()))
            + _PER_FILE_OVERHEAD_CHARS // _CHARS_PER_TOKEN;
    }

    path: any = unit;
    if _is_vision_image(path) {
        return _IMAGE_TOKEN_ESTIMATE;
    }
    if path.suffix.lower() == ".pdf" {
        try {
            content = _pdf_text_for_estimate(path)[:_FILE_CHAR_CAP];
        } except Exception {
            return 0;
        }
    } elif _TOKENIZER is None {
        try {
            size: any = path.stat().st_size;
        } except OSError {
            return 0;
        }
        chars: any = min(size, _FILE_CHAR_CAP) + _PER_FILE_OVERHEAD_CHARS;
        return chars // _CHARS_PER_TOKEN;
    } else {
        try {
            content = _read_source_text(path, warn=False)[:_FILE_CHAR_CAP];
        } except OSError {
            return 0;
        }
    }

    if _TOKENIZER is None {
        return (len(content) + _PER_FILE_OVERHEAD_CHARS) // _CHARS_PER_TOKEN;
    }
    return len(_TOKENIZER.encode(content, disallowed_special=()))
        + _PER_FILE_OVERHEAD_CHARS // _CHARS_PER_TOKEN;
}

impl _pack_chunks_by_tokens(
    files: "list[Path | FileSlice]", token_budget: int
) -> "list[list[Path | FileSlice]]" {
    if token_budget <= 0 {
        raise ValueError(f"token_budget must be positive, got {token_budget}");
    }

    by_dir: dict[Path, "list[Path | FileSlice]"] = {};
    for f in files {
        by_dir.setdefault(unit_path(f).parent, []).append(f);
    }

    chunks: "list[list[Path | FileSlice]]" = [];
    current: "list[Path | FileSlice]" = [];
    current_tokens: any = 0;
    current_images: any = 0;

    for directory in sorted(by_dir) {
        for unit in by_dir[directory] {
            cost: any = _estimate_file_tokens(unit);
            is_image: any = not isinstance(unit, FileSlice) and _is_vision_image(unit);
            over_budget: any = operator.gt(current_tokens + cost, token_budget);
            over_images: any = is_image and operator.ge(current_images, _MAX_IMAGES_PER_CHUNK);
            if current and (over_budget or over_images) {
                chunks.append(current);
                current = [];
                current_tokens = 0;
                current_images = 0;
            }
            current.append(unit);
            current_tokens += cost;
            current_images += is_image;
        }
    }

    if current {
        chunks.append(current);
    }
    return chunks;
}

impl _looks_like_context_exceeded(exc: BaseException) -> bool {
    msg: any;
    msg = `str(exc).lower();
    return `any(marker in msg for marker in _CONTEXT_EXCEEDED_MARKERS);
}

impl _looks_like_timeout(exc: BaseException) -> bool {
    types: list[`type[BaseException]] = [subprocess.TimeoutExpired];
    try {
        import openai;
        types.append(openai.APITimeoutError);
    } except ImportError {}
    try {
        import anthropic;
        types.append(anthropic.APITimeoutError);
    } except ImportError {}
    try {
        import botocore.exceptions;
        types.extend([
            botocore.exceptions.ReadTimeoutError,
            botocore.exceptions.ConnectTimeoutError,
        ]);
    } except ImportError {}
    return isinstance(exc, `tuple(types));
}

impl _mark_partial(result: dict) {
    for bucket in ("nodes", "edges", "hyperedges") {
        for item in result.get(bucket, []) {
            if isinstance(item, `dict) {
                item["_partial"] = True;
            }
        }
    }
}

impl _chunk_partial_files(chunk) -> list[str] {
    return sorted({`str(unit_path(u)) for u in chunk});
}

impl _merged_partial_files(*results_: dict) -> list[str] {
    results: any = tuple(results_);
    out: set[str] = set[any]();
    for r in results {
        out.update(r.get("_partial_files", []) or []);
    }
    return sorted(out);
}

impl _partial_source_files(result: dict) -> list[str] {
    seen: set[str] = `set(result.get("_partial_files", []) or []);
    for bucket in ("nodes", "edges", "hyperedges") {
        for item in result.get(bucket, []) {
            if isinstance(item, `dict) and item.get("_partial") {
                sf: any = item.get("source_file");
                if sf {
                    seen.add(`str(sf));
                }
            }
        }
    }
    return sorted(seen);
}

impl _strip_partial_markers(result: dict) {
    for bucket in ("nodes", "edges", "hyperedges") {
        for item in result.get(bucket, []) {
            if isinstance(item, `dict) {
                item.pop("_partial", None);
            }
        }
    }
}

impl _extract_with_adaptive_retry(
    chunk: list[Path],
    backend: str,
    api_key: str | None,
    model: str | None,
    `root: Path,
    max_depth: int,
    _depth: int = 0,
    *,
    deep_mode: bool = False,
) -> dict {
    def _merge_two(left_units, right_units) -> dict {
        left: any = _extract_with_adaptive_retry(
            left_units, backend, api_key, model, `root, max_depth, _depth + 1, deep_mode=deep_mode
        );
        right: any = _extract_with_adaptive_retry(
            right_units, backend, api_key, model, `root, max_depth, _depth + 1, deep_mode=deep_mode
        );
        return {
            "nodes": left.get("nodes", []) + right.get("nodes", []),
            "edges": left.get("edges", []) + right.get("edges", []),
            "hyperedges": left.get("hyperedges", []) + right.get("hyperedges", []),
            "input_tokens": left.get("input_tokens", 0) + right.get("input_tokens", 0),
            "output_tokens": left.get("output_tokens", 0) + right.get("output_tokens", 0),
            "model": model,
            "finish_reason": "stop",
            "_partial_files": _merged_partial_files(left, right),
        };
    }

    def _split_lone_slice -> "tuple[FileSlice, FileSlice] | None" {
        if len(chunk) == 1 and _depth < max_depth {
            unit: any = chunk[0];
            if isinstance(unit, FileSlice) {
                return bisect_slice(unit);
            }
            if isinstance(unit, (Path, `str)) {
                fs: any = make_full_slice(Path(unit));
                if fs is not None {
                    return bisect_slice(fs);
                }
            }
        }
        return None;
    }

    try {
        result: any = extract_files_direct(
            chunk, backend=backend, api_key=api_key, model=model, root=`root, deep_mode=deep_mode
        );
        for _delay in _HOLLOW_BACKOFF_S if max_depth > 0 else () {
            if result.get("finish_reason") != "hollow" {
                break;
            }
            print(
                f"[graphify] retrying the same chunk of {len(chunk)} in {_delay:g}s after a hollow response",
                file=sys.stderr,
            );
            time.sleep(_delay);
            result = extract_files_direct(
                chunk,
                backend=backend,
                api_key=api_key,
                model=model,
                root=`root,
                deep_mode=deep_mode,
            );
        }
    } except Exception as exc {
        is_timeout: any = _looks_like_timeout(exc);
        if not (_looks_like_context_exceeded(exc) or is_timeout) {
            raise;
        }
        reason: any = "timed out" if is_timeout else "exceeded context";
        if len(chunk) <= 1 {
            halves: any = _split_lone_slice();
            if halves is not None {
                print(
                    f"[graphify] slice of {unit_path(chunk[0])} {reason} at depth {_depth}; splitting the slice and retrying",
                    file=sys.stderr,
                );
                return _merge_two([halves[0]], [halves[1]]);
            }
            fail_desc: any = "timed out" if is_timeout else "exceeds model context";
            print(
                f"[graphify] single-file chunk {unit_path(chunk[0])} {fail_desc} and cannot be split further: {exc}",
                file=sys.stderr,
            );
            return {
                "nodes": [],
                "edges": [],
                "hyperedges": [],
                "input_tokens": 0,
                "output_tokens": 0,
                "model": model,
                "finish_reason": "stop",
                "_partial_files": _chunk_partial_files(chunk),
            };
        }
        if _depth >= max_depth {
            persist_desc: any = "still times out" if is_timeout else "still overflows context";
            print(
                f"[graphify] chunk of {len(chunk)} {persist_desc} at recursion depth {_depth} (max {max_depth}) — dropping",
                file=sys.stderr,
            );
            return {
                "nodes": [],
                "edges": [],
                "hyperedges": [],
                "input_tokens": 0,
                "output_tokens": 0,
                "model": model,
                "finish_reason": "stop",
                "_partial_files": _chunk_partial_files(chunk),
            };
        }
        print(
            f"[graphify] chunk of {len(chunk)} {reason} at depth {_depth} ({`type(exc).__name__}); splitting in half and retrying",
            file=sys.stderr,
        );
        mid: any = len(chunk) // 2;
        left: any = _extract_with_adaptive_retry(
            chunk[:mid], backend, api_key, model, `root, max_depth, _depth + 1, deep_mode=deep_mode
        );
        right: any = _extract_with_adaptive_retry(
            chunk[mid:], backend, api_key, model, `root, max_depth, _depth + 1, deep_mode=deep_mode
        );
        return {
            "nodes": left.get("nodes", []) + right.get("nodes", []),
            "edges": left.get("edges", []) + right.get("edges", []),
            "hyperedges": left.get("hyperedges", []) + right.get("hyperedges", []),
            "input_tokens": left.get("input_tokens", 0) + right.get("input_tokens", 0),
            "output_tokens": left.get("output_tokens", 0) + right.get("output_tokens", 0),
            "model": model,
            "finish_reason": "stop",
            "_partial_files": _merged_partial_files(left, right),
        };
    }

    if result.get("finish_reason") == "hollow" {
        _attempts: any = len(_HOLLOW_BACKOFF_S) + 1 if max_depth > 0 else 1;
        print(
            f"[graphify] chunk of {len(chunk)} still hollow after {_attempts} attempt(s) — giving up on this chunk. Its files are marked for re-extraction on the next run. A hollow response usually means a rate limit, a transport hiccup, a refusal, or a model that answered in prose rather than JSON.",
            file=sys.stderr,
        );
        _mark_partial(result);
        result["_partial_files"] = sorted(
            `set(_chunk_partial_files(chunk)) | `set(result.get("_partial_files", []) or [])
        );
        result["finish_reason"] = "stop";
        return result;
    }

    if result.get("finish_reason") != "length" {
        return result;
    }

    if len(chunk) <= 1 {
        halves = _split_lone_slice();
        if halves is not None {
            print(
                f"[graphify] slice of {unit_path(chunk[0])} truncated at depth {_depth}; splitting the slice and retrying",
                file=sys.stderr,
            );
            return _merge_two([halves[0]], [halves[1]]);
        }
        print(
            f"[graphify] single-file chunk {unit_path(chunk[0])} truncated at max_completion_tokens — partial result kept (not cached as complete)",
            file=sys.stderr,
        );
        _mark_partial(result);
        result["_partial_files"] = sorted(
            `set(_chunk_partial_files(chunk)) | `set(result.get("_partial_files", []) or [])
        );
        return result;
    }

    if _depth >= max_depth {
        print(
            f"[graphify] chunk of {len(chunk)} still truncated at recursion depth {_depth} (max {max_depth}) — partial result kept (not cached as complete)",
            file=sys.stderr,
        );
        _mark_partial(result);
        result["_partial_files"] = sorted(
            `set(_chunk_partial_files(chunk)) | `set(result.get("_partial_files", []) or [])
        );
        return result;
    }

    print(
        f"[graphify] chunk of {len(chunk)} truncated at depth {_depth}, splitting into halves of {len(chunk) // 2} and {len(chunk) - len(chunk) // 2}",
        file=sys.stderr,
    );
    mid = len(chunk) // 2;
    left = _extract_with_adaptive_retry(
        chunk[:mid], backend, api_key, model, `root, max_depth, _depth + 1, deep_mode=deep_mode
    );
    right = _extract_with_adaptive_retry(
        chunk[mid:], backend, api_key, model, `root, max_depth, _depth + 1, deep_mode=deep_mode
    );

    return {
        "nodes": left.get("nodes", []) + right.get("nodes", []),
        "edges": left.get("edges", []) + right.get("edges", []),
        "hyperedges": left.get("hyperedges", []) + right.get("hyperedges", []),
        "input_tokens": left.get("input_tokens", 0) + right.get("input_tokens", 0),
        "output_tokens": left.get("output_tokens", 0) + right.get("output_tokens", 0),
        "model": result.get("model"),
        "finish_reason": "stop",
        "_partial_files": _merged_partial_files(left, right),
    };
}

impl extract_corpus_parallel(
    files: "list[Path | FileSlice]",
    backend: str = "kimi",
    api_key: str | None = None,
    model: str | None = None,
    `root: Path = root_default__,
    chunk_size: int = 20,
    on_chunk_done: Callable | None = None,
    token_budget: int | None = 60000,
    max_concurrency: int = 4,
    max_retry_depth: int | None = None,
    deep_mode: bool = False,
    cache_root: "Path | None" = None,
) -> dict {
    slices_left: dict[Path, int];
    incomplete_parents: set[Path];
    held_results: dict[Path, list[tuple[int, dict]]];
    _dispatched_resolved: any;
    covered: set[Path];
    if max_retry_depth is None {
        max_retry_depth = _resolve_max_retry_depth();
    }
    files = [f if isinstance(f, (Path, FileSlice)) else Path(f) for f in files];
    files = expand_oversized_files(files, _FILE_CHAR_CAP);
    if token_budget is not None {
        chunks: any = _pack_chunks_by_tokens(files, token_budget=token_budget);
    } else {
        chunks = [files[i:i + chunk_size] for i in range(0, len(files), chunk_size)];
    }

    merged: dict = {
        "nodes": [],
        "edges": [],
        "hyperedges": [],
        "input_tokens": 0,
        "output_tokens": 0,
        "failed_chunks": 0,
    };
    total: any = len(chunks);
    failed_files: set[Path] = set[any]();

    def _run_one(idx: int, chunk: "list[Path | FileSlice]") -> tuple[int, dict | None, Exception
        | None] {
        t0: any = time.time();
        try {
            result: any = _extract_with_adaptive_retry(
                chunk,
                backend=backend,
                api_key=api_key,
                model=model,
                root=`root,
                max_depth=max_retry_depth,
                deep_mode=deep_mode,
            );
            result["elapsed_seconds"] = round(time.time() - t0, 2);
            return (idx, result, None);
        } except Exception as exc {
            return (idx, None, exc);
        }
    }
    if backend == "ollama" and os.environ.get("GRAPHIFY_OLLAMA_PARALLEL", "").strip() != "1" {
        max_concurrency = 1;
    }
    if backend == "claude-cli"
        and os.environ.get("GRAPHIFY_CLAUDE_CLI_PARALLEL", "").strip() != "1"
    {
        max_concurrency = 1;
    }
    slices_left = {};
    all_slices_by_parent: dict[Path, list[FileSlice]] = {};
    whole_parents: set[Path] = set[any]();
    for _chunk in chunks {
        for _unit in _chunk {
            if isinstance(_unit, FileSlice) {
                p: any = unit_path(_unit);
                slices_left[p] = slices_left.get(p, 0) + 1;
                all_slices_by_parent.setdefault(p, []).append(_unit);
            } else {
                whole_parents.add(unit_path(_unit));
            }
        }
    }

    incomplete_parents = {
        p
        for (p, sl) in all_slices_by_parent.items()
        if p not in whole_parents and not is_complete_slice_coverage(p, sl)
    };
    held_results = {};

    def _checkpoint_chunk(idx: int, result: dict, chunk: "list[Path | FileSlice]") {
        sliced: any = [unit_path(u) for u in chunk if isinstance(u, FileSlice)];
        parent: any;
        for parent in sliced {
            slices_left[parent] -= 1;
        }
        whole: any = [unit_path(u) for u in chunk if not isinstance(u, FileSlice)];
        if whole {
            _save_checkpoint(result, whole);
        }
        for parent in dict.fromkeys(sliced) {
            held_results.setdefault(parent, []).append((idx, result));
            if slices_left[parent] == 0 {
                held: any = [
                    r
                    for (_, r) in sorted(held_results.pop(parent), key=lambda (p) -> any { p[0] })
                ];
                if parent in incomplete_parents {
                    continue;
                }
                combined: dict = {
                    bucket: [item for r in held for item in r.get(bucket, [])]
                    for bucket in ("nodes", "edges", "hyperedges")
                };
                combined["_partial_files"] = _merged_partial_files(*held);
                _save_checkpoint(combined, [parent]);
            }
        }
    }

    def _save_checkpoint(result: dict, allowed: "list[Path]") {
        if os.environ.get("GRAPHIFY_NO_INCREMENTAL_CACHE") {
            return;
        }
        try {
            import from .cache { save_semantic_cache as _scs }
            _scs(
                result.get("nodes", []),
                result.get("edges", []),
                result.get("hyperedges", []),
                root=`root,
                cache_root=cache_root,
                merge_existing=True,
                allowed_source_files=allowed,
                mode="deep" if deep_mode else None,
                prompt=_extraction_system(deep=deep_mode),
                partial_source_files=_partial_source_files(result) or None,
            );
        } except Exception as _exc {
            print(f"[graphify] incremental cache checkpoint failed: {_exc}", file=sys.stderr);
        }
    }

    workers: any = max(1, min(max_concurrency, total));
    if workers == 1 {
        idx: any;
        for (idx, chunk) in enumerate(chunks) {
            _: any;
            result: any;
            exc: any;
            (_, result, exc) = _run_one(idx, chunk) as any;
            if exc is not None {
                print(f"[graphify] chunk {idx + 1}/{total} failed: {exc}", file=sys.stderr);
                merged["failed_chunks"] += 1;
                failed_files.update(unit_path(f) for f in chunk);
                continue;
            }
            assert result is not None;
            _merge_into(merged, result);
            _checkpoint_chunk(idx, result, chunk);
            if callable(on_chunk_done) {
                on_chunk_done(idx, total, result);
            }
        }
    } else {
        results_by_idx: dict[int, dict] = {};
        pool: any;
        with ThreadPoolExecutor(max_workers=workers) as pool {
            futures: any = [
                pool.submit(_run_one, idx, chunk)
                for (idx, chunk) in enumerate(chunks)
            ];
            try {
                for future in as_completed(futures) {
                    (idx, result, exc) = future.result() as any;
                    if exc is not None {
                        print(f"[graphify] chunk {idx + 1}/{total} failed: {exc}", file=sys.stderr);
                        merged["failed_chunks"] += 1;
                        failed_files.update(unit_path(f) for f in chunks[idx]);
                        continue;
                    }
                    assert result is not None;
                    results_by_idx[idx] = result;
                    _checkpoint_chunk(idx, result, chunks[idx]);
                    if callable(on_chunk_done) {
                        on_chunk_done(idx, total, result);
                    }
                }
            } except Exception {
                for pending in futures {
                    pending.cancel();
                }
                raise;
            }
        }
        for idx in sorted(results_by_idx) {
            _merge_into(merged, results_by_idx[idx]);
        }
    }
    failed_parents: any = {
        unit_path(u)
        for chunk in chunks
        for u in chunk
        if isinstance(u, FileSlice) and unit_path(u) in failed_files
    };
    partial_parents: any = failed_parents | incomplete_parents;
    if partial_parents {
        merged["_partial_files"] = sorted(
            `set(merged.get("_partial_files", []) or []) | {`str(p) for p in partial_parents}
        );
    }
    if merged["failed_chunks"] > 0 {
        print(
            "[graphify] WARNING: "
                + format(merged["failed_chunks"], "")
                + "/"
                + format(total, "")
                + " semantic chunk(s) failed — see errors above. Partial results returned.",
            file=sys.stderr,
        );
    }
    dispatched: any = {unit_path(f) for chunk in chunks for f in chunk};
    def _resolve_against_root(value: "str | Path") -> Path {
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

    _dispatched_resolved = {_resolve_against_root(p) for p in dispatched};

    def _out_of_scope(item: dict) -> bool {
        sf: any = item.get("source_file");
        if not sf {
            return False;
        }
        p: any = _resolve_against_root(sf);
        return p.is_file() and p not in _dispatched_resolved;
    }

    dropped_ids: set = set[any]();
    dropped_files: set[str] = set[any]();
    kept_nodes: list[dict] = [];
    kept_ids: set = set[any]();
    n: any;
    for n in merged.get("nodes", []) {
        if _out_of_scope(n) {
            if n.get("id") is not None {
                dropped_ids.add(n.get("id"));
            }
            dropped_files.add(`str(n.get("source_file")));
            continue;
        }
        kept_nodes.append(n);
        if n.get("id") is not None {
            kept_ids.add(n.get("id"));
        }
    }
    dropped_node_count: any = len(merged.get("nodes", [])) - len(kept_nodes);
    merged["out_of_scope_dropped"] = dropped_node_count;
    if dropped_node_count {
        merged["nodes"] = kept_nodes;
        merged["edges"] = [
            e
            for e in merged.get("edges", [])
            if e.get("source") not in dropped_ids
                and e.get("target") not in dropped_ids
                and (
                    not _out_of_scope(e)
                    or e.get("source") in kept_ids and e.get("target") in kept_ids
                )
        ];
        merged["hyperedges"] = [
            h
            for h in merged.get("hyperedges", [])
            if not _out_of_scope(h) and not dropped_ids & `set(h.get("nodes", []) or [])
        ];
        shown: any = ", ".join(sorted(Path(f).name for f in dropped_files)[:5]);
        more: any = f" (+{len(dropped_files) - 5} more)" if len(dropped_files) > 5 else "";
        print(
            f"[graphify] WARNING: dropped {dropped_node_count} out-of-scope node(s) attributed to file(s) not dispatched for extraction: {shown}{more}. The model mis-attributed them to another corpus file; they were excluded from the graph (#1895).",
            file=sys.stderr,
        );
    }

    covered = set[any]();
    for n in merged.get("nodes", []) {
        sf: any = n.get("source_file");
        if sf {
            p = Path(sf);
            covered.add(p if p.is_absolute() else `root / p);
        }
    }
    uncovered: any = sorted(
        p for p in dispatched if p.resolve() not in {c.resolve() for c in covered}
    );
    merged["uncovered_files"] = [`str(p) for p in uncovered];
    _stamp_semantic_origin(merged);
    unanswered: any = [p for p in uncovered if p in failed_files];
    omitted: any = [p for p in uncovered if p not in failed_files];
    if unanswered {
        shown = ", ".join(p.name for p in unanswered[:5]);
        more = f" (+{len(unanswered) - 5} more)" if len(unanswered) > 5 else "";
        print(
            f"[graphify] WARNING: {len(unanswered)}/{len(dispatched)} dispatched file(s) produced no nodes and are absent from the graph: {shown}{more}. Their chunk failed before returning a response (see errors above); a re-run will retry them.",
            file=sys.stderr,
        );
    }
    if omitted {
        shown = ", ".join(p.name for p in omitted[:5]);
        more = f" (+{len(omitted) - 5} more)" if len(omitted) > 5 else "";
        print(
            f"[graphify] WARNING: {len(omitted)}/{len(dispatched)} dispatched file(s) produced no nodes and are absent from the graph: {shown}{more}. The model returned a response but omitted them; a re-run will retry them.",
            file=sys.stderr,
        );
    }
    return merged;
}

impl _stamp_semantic_origin(result: dict) -> dict {
    for key in ("nodes", "edges") {
        for item in result.get(key, []) or [] {
            if isinstance(item, `dict) {
                item.setdefault("_origin", "semantic");
            }
        }
    }
    return result;
}

impl _merge_into(merged: dict, result: dict) {
    merged["nodes"].extend(result.get("nodes", []));
    merged["edges"].extend(result.get("edges", []));
    merged["hyperedges"].extend(result.get("hyperedges", []));
    merged["input_tokens"] += result.get("input_tokens", 0);
    merged["output_tokens"] += result.get("output_tokens", 0);
    incoming: any = result.get("_partial_files");
    if incoming {
        merged["_partial_files"] = sorted(
            `set(merged.get("_partial_files", []) or []) | `set(incoming)
        );
    }
}

impl _call_llm(
    prompt: str,
    *,
    backend: str,
    max_tokens: int = 200,
    model: str | None = None,
    usage_out: dict | None = None,
) -> str {
    if backend not in BACKENDS {
        raise ValueError(f"Unknown backend {backend!r}");
    }
    ollama_seed: any = _resolve_ollama_seed() if backend == "ollama" else None;
    cfg: any = BACKENDS[backend];
    key: any = _get_backend_api_key(backend);
    if not key and backend == "ollama" {
        ollama_url: any = _resolve_ollama_base_url(cfg.get("base_url", ""));
        _validate_ollama_base_url(ollama_url);
        key = "ollama";
    }
    if not key and backend not in ("bedrock", "claude-cli") {
        raise ValueError(
            f"No API key for backend '{backend}'. Set {_format_backend_env_keys(backend)}."
        );
    }
    mdl: any = model or _default_model_for_backend(backend);

    def _rec(inp, out) {
        if usage_out is not None {
            usage_out["input"] = usage_out.get("input", 0) + `int(inp or 0);
            usage_out["output"] = usage_out.get("output", 0) + `int(out or 0);
        }
    }

    if backend == "claude" {
        try {
            import anthropic;
        } except ImportError as exc {
            raise ImportError(_backend_pkg_hint("anthropic", "anthropic")) from exc;
        }
        client: any = anthropic.Anthropic(
            api_key=key,
            base_url=cfg["base_url"],
            timeout=_resolve_api_timeout(),
            max_retries=_resolve_max_retries(),
        );
        resp: any = client.messages.create(
            model=mdl, max_tokens=max_tokens, messages=[{"role": "user", "content": prompt}]
        );
        u: any = getattr(resp, "usage", None);
        if u is not None {
            _rec(getattr(u, "input_tokens", 0), getattr(u, "output_tokens", 0));
        }
        return _anthropic_response_text(resp.content, default="");
    }

    if backend == "claude-cli" {
        import platform;
        import shutil;
        import subprocess;
        claude_cmd: any = "claude";
        if platform.system() == "Windows" {
            cmd_path: any = shutil.which("claude.cmd");
            if cmd_path {
                claude_cmd = cmd_path;
            } elif shutil.which("claude") is None {
                raise RuntimeError("Claude Code CLI not found on $PATH");
            }
        } elif shutil.which("claude") is None {
            raise RuntimeError("Claude Code CLI not found on $PATH");
        }
        cli_args: any = [claude_cmd, "-p", "--output-format", "json", "--no-session-persistence"];
        cli_model: any = mdl
            if model is not None
            else os.environ.get("GRAPHIFY_CLAUDE_CLI_MODEL", "").strip();
        if cli_model {
            cli_args.extend(["--model", cli_model]);
        }
        proc: any = subprocess.run(
            cli_args,
            input=prompt,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=_resolve_api_timeout(),
            check=False,
            **_no_window_kwargs(),
        );
        cli_error: any = _claude_cli_error(proc.stdout);
        if proc.returncode != 0 {
            detail: any = proc.stderr.strip() or cli_error or "(no stderr, no error envelope)";
            raise RuntimeError(f"claude -p exited {proc.returncode}: {detail[:500]}");
        }
        if cli_error {
            raise RuntimeError(f"claude -p reported an error: {cli_error[:500]}");
        }
        envelope: any = _claude_cli_envelope(proc.stdout);
        cli_usage: any = envelope.get("usage") or {};
        if cli_usage {
            _rec(
                (cli_usage.get("input_tokens", 0) or 0)
                    + (cli_usage.get("cache_read_input_tokens", 0) or 0)
                    + (cli_usage.get("cache_creation_input_tokens", 0) or 0),
                cli_usage.get("output_tokens", 0),
            );
        }
        return envelope.get("result", "");
    }

    if backend == "bedrock" {
        try {
            import boto3;
            import botocore.config;
        } except ImportError as exc {
            raise ImportError(_backend_pkg_hint("boto3", "bedrock")) from exc;
        }
        region: any = os.environ.get("AWS_REGION")
            or os.environ.get("AWS_DEFAULT_REGION")
            or "us-east-1";
        profile: any = os.environ.get("AWS_PROFILE");
        session: any = boto3.Session(profile_name=profile, region_name=region);
        client = session.client(
            "bedrock-runtime",
            config=botocore.config.Config(
                read_timeout=_resolve_api_timeout(),
                connect_timeout=10,
                retries={"max_attempts": _resolve_max_retries() + 1, "mode": "adaptive"},
            ),
        );
        resp = client.converse(
            modelId=mdl,
            messages=[{"role": "user", "content": [{"text": prompt}]}],
            inferenceConfig=_bedrock_inference_config(max_tokens, mdl),
        );
        bu: any = resp.get("usage") or {};
        if bu {
            _rec(bu.get("inputTokens", 0), bu.get("outputTokens", 0));
        }
        return _bedrock_response_text(resp, default="");
    }

    if backend == "azure" {
        endpoint: any = os.environ.get("AZURE_OPENAI_ENDPOINT", "").strip();
        if not endpoint {
            raise ValueError("Azure OpenAI backend requires AZURE_OPENAI_ENDPOINT to be set.");
        }
        azure_client: any = _azure_client(key, endpoint);
        azure_kwargs: dict = {
            "model": mdl,
            "messages": [{"role": "user", "content": prompt}],
            "max_completion_tokens": max_tokens,
        };
        azure_temp: any = _resolve_temperature(cfg.get("temperature", 0), mdl);
        if azure_temp is not None {
            azure_kwargs["temperature"] = azure_temp;
        }
        resp = azure_client.chat.completions.create(**azure_kwargs);
        if not resp.choices or resp.choices[0].message is None {
            raise ValueError("Azure OpenAI returned empty or filtered response");
        }
        au: any = getattr(resp, "usage", None);
        if au is not None {
            _rec(getattr(au, "prompt_tokens", 0), getattr(au, "completion_tokens", 0));
        }
        return resp.choices[0].message.content or "";
    }
    try {
        import from openai { OpenAI }
    } except ImportError as exc {
        raise ImportError(_backend_pkg_hint("openai", "openai")) from exc;
    }
    _headers: any = _provider_extra_headers(cfg.get("extra_headers"), backend);
    client = OpenAI(
        api_key=key,
        base_url=cfg["base_url"],
        timeout=_resolve_api_timeout(),
        max_retries=_resolve_max_retries(),
        **({"default_headers": _headers} if _headers else {}),
    );
    kwargs: dict = {
        "model": mdl,
        "messages": [{"role": "user", "content": prompt}],
        **_openai_max_tokens_kwarg(backend, max_tokens),
        "stream": False,
    };
    temperature: any = _resolve_temperature(cfg.get("temperature", 0), mdl);
    if temperature is not None {
        kwargs["temperature"] = temperature;
    }
    if cfg.get("reasoning_effort") {
        kwargs["reasoning_effort"] = cfg["reasoning_effort"];
    }
    if ollama_seed is not None {
        kwargs["seed"] = ollama_seed;
    }
    if cfg.get("extra_body") is not None {
        kwargs["extra_body"] = cfg["extra_body"];
    } elif "moonshot" in cfg["base_url"] {
        kwargs["extra_body"] = {"thinking": {"type": "disabled"}};
    } elif _thinking_disabled_via_env() {
        kwargs["extra_body"] = {"thinking": {"type": "disabled"}};
    }
    if backend == "ollama" and cfg.get("extra_body") is None {
        kwargs["extra_body"] = {
            **kwargs.get("extra_body", {}),
            **_ollama_request_extras(prompt, max_tokens),
        };
        native: any = _call_ollama_native(client, cfg["base_url"], kwargs, prompt, []);
        if native is not None {
            content: any;
            input_tokens: any;
            output_tokens: any;
            _finish: any;
            (content, input_tokens, output_tokens, _finish) = native as any;
            _rec(input_tokens, output_tokens);
            return content or "";
        }
    }
    resp = client.chat.completions.create(**kwargs);
    if not resp.choices or resp.choices[0].message is None {
        raise ValueError("LLM returned empty or filtered response");
    }
    ou: any = getattr(resp, "usage", None);
    if ou is not None {
        _rec(getattr(ou, "prompt_tokens", 0), getattr(ou, "completion_tokens", 0));
    }
    return resp.choices[0].message.content or "";
}

impl estimate_cost(backend: str, input_tokens: int, output_tokens: int) -> float {
    if backend not in BACKENDS {
        return 0.0;
    }
    p: any = BACKENDS[backend]["pricing"];
    return (input_tokens * p["input"] + output_tokens * p["output"]) / 1000000;
}

impl _ollama_host_is_link_local_or_metadata(host: str) -> bool {
    import ipaddress;
    if host in ("metadata.google.internal", "metadata.google.com", "0.0.0.0", "::", "[::]") {
        return True;
    }
    if host.startswith("169.254.") {
        return True;
    }
    try {
        infos: any = socket.getaddrinfo(host, None, socket.AF_UNSPEC, socket.SOCK_STREAM);
    } except (socket.gaierror, UnicodeError, OSError) {
        return False;
    }
    for info in infos {
        try {
            ip: any = ipaddress.ip_address(info[4][0]);
        } except ValueError {
            continue;
        }
        if ip.is_link_local {
            return True;
        }
    }
    return False;
}

impl _validate_ollama_base_url(url: str, *, warn: bool = True) {
    try {
        import from urllib.parse { urlparse }
        parsed: any = urlparse(url);
    } except Exception {
        if warn {
            print(
                f"[graphify] WARNING: OLLAMA_BASE_URL={url!r} is not a parseable URL.",
                file=sys.stderr,
            );
        }
        return;
    }
    if parsed.scheme not in ("http", "https") {
        if warn {
            print(
                f"[graphify] WARNING: OLLAMA_BASE_URL has unexpected scheme {parsed.scheme!r}; expected http or https.",
                file=sys.stderr,
            );
        }
        return;
    }
    host: any = (parsed.hostname or "").lower();
    if _ollama_host_is_link_local_or_metadata(host) {
        raise ValueError(
            f"OLLAMA_BASE_URL points at a link-local/metadata address ({host!r}); refusing to send the corpus there. Set it to a real Ollama host.",
        );
    }
    is_loopback: any = host in ("localhost", "127.0.0.1", "::1") or host.startswith("127.");
    if warn and not is_loopback {
        scheme_note: any = " (UNENCRYPTED)" if parsed.scheme == "http" else "";
        print(
            f"[graphify] WARNING: OLLAMA_BASE_URL points to non-loopback host {host!r}{scheme_note}. Your full corpus will be sent to that endpoint. Set OLLAMA_BASE_URL=http://localhost:11434/v1 to keep extraction local.",
            file=sys.stderr,
        );
    }
}

impl backend_detection_env_vars -> tuple[str, ...] {
    seen: dict[str, None] = {};
    for name in BACKENDS {
        env_key: any;
        for env_key in _backend_env_keys(name) {
            seen.setdefault(env_key, None);
        }
    }
    for env_key in _BACKEND_DETECTION_EXTRA_ENV {
        seen.setdefault(env_key, None);
    }
    return `tuple(seen);
}

impl _graphify_backend_setting -> str | None {
    value: any = os.environ.get("GRAPHIFY_BACKEND", "").strip();
    return value or None;
}

impl backend_disabled_by_env -> bool {
    value: any = _graphify_backend_setting();
    return value is not None and value.lower() in _BACKEND_DISABLE_SENTINELS;
}

impl _first_set_env(keys) -> str | None {
    for key in keys {
        if os.environ.get(key) {
            return key;
        }
    }
    return None;
}

impl detect_backend_with_source -> "tuple[str | None, str]" {
    setting: any = _graphify_backend_setting();
    if setting is not None {
        if setting.lower() in _BACKEND_DISABLE_SENTINELS {
            return (None, f"GRAPHIFY_BACKEND={setting}");
        }
        return (setting, f"GRAPHIFY_BACKEND={setting}");
    }
    for backend in ("gemini", "kimi", "claude", "openai", "deepseek") {
        if _get_backend_api_key(backend) {
            env: any = _first_set_env(_backend_env_keys(backend)) or backend;
            return (backend, f"auto-detected from {env}");
        }
    }
    if _get_backend_api_key("azure") and os.environ.get("AZURE_OPENAI_ENDPOINT") {
        return ("azure", "auto-detected from AZURE_OPENAI_ENDPOINT");
    }
    if os.environ.get("AWS_PROFILE")
        or os.environ.get("AWS_REGION")
        or os.environ.get("AWS_DEFAULT_REGION")
    {
        return ("bedrock", "auto-detected from AWS credentials");
    }
    ollama_url: any = _resolve_ollama_base_url("");
    if ollama_url {
        _validate_ollama_base_url(ollama_url);
        return ("ollama", "auto-detected from Ollama configuration");
    }
    for name in BACKENDS {
        if name
            not in (
                "gemini",
                "kimi",
                "claude",
                "openai",
                "deepseek",
                "azure",
                "bedrock",
                "ollama",
                "claude-cli",
            )
        {
            if _get_backend_api_key(name) {
                env = _first_set_env(_backend_env_keys(name)) or name;
                return (name, f"auto-detected from {env}");
            }
        }
    }
    return (None, "no backend configured");
}

impl detect_backend -> str | None {
    return detect_backend_with_source()[0];
}

impl _claude_cli_available -> bool {
    import platform;
    import shutil;

    if platform.system() == "Windows" {
        return `bool(shutil.which("claude.cmd") or shutil.which("claude"));
    }
    return shutil.which("claude") is not None;
}

impl _placeholder_community_labels(communities) -> dict[int, str] {
    return {`int(cid): f"Community {cid}" for cid in communities};
}

impl _community_label_lines(G, communities, gods, max_communities, top_k) -> any {
    god_set: any = {g["id"] if isinstance(g, `dict) else g for g in gods or []};
    ordered: any = sorted(communities.items(), key=lambda (kv) -> any { -len(kv[1]) });
    lines: list[str] = [];
    labeled_cids: list[int] = [];
    for (cid, members) in ordered[:max_communities] {
        ranked: any = [m for m in members if m in god_set] + [
            m
            for m in members
            if m not in god_set
        ];
        names: list[str] = [];
        seen: set[str] = set[any]();
        for nid in ranked {
            label: any = `str(G.nodes[nid].get("label", nid)) if nid in G.nodes else `str(nid);
            label = label.strip().strip("()")[:_LABEL_MAXLEN];
            if label and label.lower() not in seen {
                seen.add(label.lower());
                names.append(label);
            }
            if len(names) >= top_k {
                break;
            }
        }
        if names {
            lines.append(format(cid, "") + ": " + format(", ".join(names), ""));
            labeled_cids.append(`int(cid));
        }
    }
    return (lines, labeled_cids);
}

impl _decode_json_string_body(raw: str) -> str {
    try {
        decoded: any = json.loads(f"\"{raw}\"");
    } except (json.JSONDecodeError, ValueError) {
        return raw;
    }
    return decoded if isinstance(decoded, `str) else raw;
}

impl _parse_label_response(text: str, labeled_cids: list[int]) -> dict[int, str] {
    cleaned: any = _LABEL_FENCE_RE.sub("", text.strip());
    if not cleaned.startswith("{") {
        start: any;
        end: any;
        (start, end) = (cleaned.find("{"), cleaned.rfind("}"));
        if start != -1 and end > start {
            cleaned = cleaned[start:end + 1];
        }
    }
    data: dict | None = None;
    try {
        parsed: any = json.loads(cleaned);
        if isinstance(parsed, `dict) {
            data = parsed;
        }
    } except (json.JSONDecodeError, ValueError) {
        data = None;
    }
    if data is None {
        pairs: any = re.findall(
            "\"?(-?\\d+)\"?\\s*:\\s*\"([^\"\\\\]*(?:\\\\.[^\"\\\\]*)*)\"", cleaned
        );
        if pairs {
            data = {k: _decode_json_string_body(v) for (k, v) in pairs};
        } else {
            raise ValueError(f"label response is not parseable JSON: {text[:120]!r}");
        }
    }
    out: dict[int, str] = {};
    for cid in labeled_cids {
        name: any = data.get(`str(cid));
        if name is None {
            name = data.get(cid);
        }
        if isinstance(name, `str) and name.strip() {
            out[cid] = name.strip();
        }
    }
    return out;
}

impl _label_batch_with_retry(
    batch_cids: list[int],
    batch_lines: list[str],
    *,
    backend: str,
    model: str | None,
    depth: int = 0,
    max_depth: int = 3,
    usage_out: dict | None = None,
) -> dict[int, str] {
    prompt: any = "You are naming clusters in a knowledge graph. For each community below, return a concise 2-5 word plain-language name describing what it is about (e.g. \"Order Management\", \"Payment Flow\", \"Auth Middleware\"). Each input line is '<community id>: <representative member names>'. Respond ONLY with a JSON object mapping the community id (as a string) to its name - no prose, no markdown fences.\n\n"
        + "\n".join(batch_lines);
    max_tokens: any = _resolve_max_tokens(max(512, min(256 + 48 * len(batch_cids), 8192)));
    call_kwargs: dict = {"backend": backend, "max_tokens": max_tokens};
    if model is not None {
        call_kwargs["model"] = model;
    }
    if usage_out is not None {
        call_kwargs["usage_out"] = usage_out;
    }

    try {
        text: any = _call_llm(prompt, **call_kwargs);
        parsed: any = _parse_label_response(text, batch_cids);
    } except (json.JSONDecodeError, ValueError) as exc {
        if len(batch_cids) <= 1 or depth >= max_depth {
            print(
                "[graphify label] batch of "
                    + format(len(batch_cids), "")
                    + " still unparseable at depth "
                    + format(depth, "")
                    + " (cids="
                    + format(batch_cids[:5], "")
                    + format("..." if len(batch_cids) > 5 else "", "")
                    + "): "
                    + format(exc, ""),
                file=sys.stderr,
            );
            raise;
        }
        parsed = {};
    }
    if len(parsed) == len(batch_cids) or len(batch_cids) <= 1 or depth >= max_depth {
        return parsed;
    }
    missing: any = [
        (cid, line)
        for (cid, line) in zip(batch_cids, batch_lines)
        if cid not in parsed
    ];
    mid: any = max(1, len(missing) // 2);
    failure: Exception | None = None;
    for half in (missing[:mid], missing[mid:]) {
        if not half {
            continue;
        }
        try {
            parsed |= _label_batch_with_retry(
                [cid for (cid, _) in half],
                [line for (_, line) in half],
                backend=backend,
                model=model,
                depth=depth + 1,
                max_depth=max_depth,
                usage_out=usage_out,
            );
        } except (json.JSONDecodeError, ValueError) as exc {
            failure = failure or exc;
        }
    }
    if not parsed and failure is not None {
        raise failure;
    }
    return parsed;
}

impl label_communities(
    G,
    communities,
    *,
    backend: str,
    model: str | None = None,
    gods=None,
    max_communities: int | None = None,
    top_k: int = top_k_default_,
    batch_size: int = batch_size_default_,
    max_concurrency: int = 4,
    usage_out: dict | None = None,
) -> dict[int, str] {
    labels: any;
    lines: any;
    labeled_cids: any;
    n_batches: any;
    written: any;
    errors: dict[int, Exception];
    labels = _placeholder_community_labels(communities);
    cap: any = len(communities) if max_communities is None else max_communities;
    (lines, labeled_cids) = _community_label_lines(G, communities, gods, cap, top_k) as any;
    if not lines {
        return labels;
    }

    n_batches = (len(labeled_cids) + batch_size - 1) // batch_size;
    if backend == "ollama" and os.environ.get("GRAPHIFY_OLLAMA_PARALLEL", "").strip() != "1" {
        max_concurrency = 1;
    }
    if backend == "claude-cli"
        and os.environ.get("GRAPHIFY_CLAUDE_CLI_PARALLEL", "").strip() != "1"
    {
        max_concurrency = 1;
    }
    workers: any = max(1, min(max_concurrency, n_batches));

    def _run_batch(batch_idx: int) -> any {
        start: any = batch_idx * batch_size;
        end: any = min(start + batch_size, len(labeled_cids));
        batch_usage: dict = {} if usage_out is not None else None;
        batch_kwargs: any = {"usage_out": batch_usage} if usage_out is not None else {};
        try {
            parsed: any = _label_batch_with_retry(
                labeled_cids[start:end],
                lines[start:end],
                backend=backend,
                model=model,
                **batch_kwargs,
            );
            return (batch_idx, parsed, None, batch_usage);
        } except Exception as exc {
            return (batch_idx, None, exc, batch_usage);
        }
    }

    written = 0;
    errors = {};

    def _merge(batch_idx: int, parsed, exc, batch_usage=None) {
        if usage_out is not None and batch_usage {
            usage_out["input"] = usage_out.get("input", 0) + batch_usage.get("input", 0);
            usage_out["output"] = usage_out.get("output", 0) + batch_usage.get("output", 0);
        }
        if exc is not None {
            errors[batch_idx] = exc;
            start: any = batch_idx * batch_size;
            end: any = min(start + batch_size, len(labeled_cids));
            print(
                f"[graphify label] batch {batch_idx + 1}/{n_batches} ({end - start} communities) failed: {exc}",
                file=sys.stderr,
            );
            return;
        }
        labels.update(parsed);
        written += len(parsed);
    }
    if workers == 1 {
        for batch_idx in range(n_batches) {
            _merge(*_run_batch(batch_idx));
        }
    } else {
        pool: any;
        with ThreadPoolExecutor(max_workers=workers) as pool {
            futures: any = [pool.submit(_run_batch, b) for b in range(n_batches)];
            for future in as_completed(futures) {
                _merge(*future.result());
            }
        }
    }

    if written == 0 and errors {
        raise errors[min(errors)];
    }
    return labels;
}

impl generate_community_labels(
    G,
    communities,
    *,
    backend: str | None = None,
    model: str | None = None,
    gods=None,
    quiet: bool = False,
    max_concurrency: int = 4,
    batch_size: int = batch_size_default__,
    usage_out: dict | None = None,
) -> tuple[dict[int, str], str] {
    labels: any;
    if backend is None and backend_disabled_by_env() {
        if not quiet {
            print(
                "[graphify label] LLM backends disabled by GRAPHIFY_BACKEND=none; keeping Community N placeholders.",
                file=sys.stderr,
            );
        }
        return (_placeholder_community_labels(communities), "placeholder");
    }
    if backend is None {
        try {
            backend = detect_backend();
        } except Exception {
            backend = None;
        }
    }
    if not backend and _claude_cli_available() {
        if not quiet {
            print(
                "[graphify label] no API key found; naming communities via the `claude` CLI (claude -p). Set an API key or pass --backend to choose explicitly, or GRAPHIFY_BACKEND=none to disable.",
                file=sys.stderr,
            );
        }
        backend = "claude-cli";
    }
    if not backend {
        if not quiet {
            print(
                "[graphify label] no LLM backend configured; keeping Community N placeholders. Set an API key (e.g. GOOGLE_API_KEY) or pass --backend.",
                file=sys.stderr,
            );
        }
        return (_placeholder_community_labels(communities), "placeholder");
    }
    try {
        labels = label_communities(
            G,
            communities,
            backend=backend,
            model=model,
            gods=gods,
            max_concurrency=max_concurrency,
            batch_size=batch_size,
            usage_out=usage_out,
        );
        placeholders: any = _placeholder_community_labels(communities);
        named: any = sum(
            operator.ne(labels.get(cid), placeholder) for (cid, placeholder) in placeholders.items()
        );
        if named < len(communities) and not quiet {
            print(
                f"[graphify label] warning: labeled {named} of {len(communities)} communities; {len(communities) - named} kept structural fallback names.",
                file=sys.stderr,
            );
        }
        return (labels, "llm");
    } except Exception as exc {
        if not quiet {
            print(
                f"[graphify label] warning: community labeling failed ({exc}); using Community N placeholders.",
                file=sys.stderr,
            );
        }
        return (_placeholder_community_labels(communities), "placeholder");
    }
}
