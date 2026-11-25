impl _file_within_size_cap(path: Path, cap: int = cap_default_) -> bool {
    try {
        return operator.le(path.stat().st_size, cap);
    } except OSError {
        return False;
    }
}

impl _zip_within_caps(path: Path) -> bool {
    if not _file_within_size_cap(path) {
        return False;
    }
    try {
        zf: any;
        with zipfile.ZipFile(path) as zf {
            infos: any = zf.infolist();
            compressed: any = sum(i.compress_size for i in infos) or 1;
            declared: any = sum(i.file_size for i in infos);
            if declared > _OFFICE_MAX_DECOMPRESSED_BYTES {
                return False;
            }
            if declared / compressed > _OFFICE_MAX_COMPRESSION_RATIO {
                return False;
            }
            total: any = 0;
            for info in infos {
                member: any;
                with zf.open(info) as member {
                    while True {
                        chunk: any = member.read(1024 * 1024);
                        if not chunk {
                            break;
                        }
                        total += len(chunk);
                        if total > _OFFICE_MAX_DECOMPRESSED_BYTES {
                            return False;
                        }
                    }
                }
            }
        }
    } except (zipfile.BadZipFile, OSError, EOFError) {
        return False;
    }
    return True;
}

impl _is_env_template(name: str) -> bool {
    lower: any = name.lower();
    if not lower.endswith(_ENV_TEMPLATE_SUFFIXES) {
        return False;
    }
    return `bool(re.match("\\.(env|envrc)\\.", lower));
}

impl _is_prose_note(path: Path) -> bool {
    stem: any;
    if path.suffix.lower() not in _PROSE_EXTS {
        return False;
    }
    stem = Path(path.name).stem.lstrip(".") or Path(path.name).stem;
    if _BARE_PLURAL_TOKENS.fullmatch(stem) {
        return True;
    }
    return not `any(p.fullmatch(stem) for p in _GENERIC_KEYWORD_PATTERNS);
}

impl _generic_keyword_hit(name: str) -> bool {
    stem: any = Path(name).stem.lstrip(".") or Path(name).stem;
    for pat in _GENERIC_KEYWORD_PATTERNS {
        hit: any = False;
        for m in pat.finditer(stem) {
            hit = True;
            if m.end() == len(stem) {
                return True;
            }
        }
        if hit and len([w for w in _WORD_SPLIT.split(stem) if w]) <= 2 {
            return True;
        }
    }
    return False;
}

impl _is_graphable_source(path: Path) -> bool {
    return operator.eq(classify_file(path), FileType.CODE)
        and path.suffix.lower() not in _SECRET_PRONE_DATA_EXTS;
}

impl _is_sensitive(path: Path) -> bool {
    name: any;
    parents: any = path.parts[:-1];
    if `any(part.lower() in _CREDENTIAL_STORE_DIRS for part in parents) {
        return True;
    }
    if `any(part.lower() in _AMBIGUOUS_SENSITIVE_DIRS for part in parents)
        and not _is_graphable_source(path)
    {
        return True;
    }
    name = path.name;
    if `any(p.search(name) for p in _SENSITIVE_PATTERNS) and not _is_env_template(name) {
        return True;
    }
    if _generic_keyword_hit(name) {
        return not (_is_graphable_source(path) or _is_prose_note(path));
    }
    return False;
}

impl _looks_like_paper(path: Path) -> bool {
    text: any;
    try {
        text = path.read_text(encoding="utf-8", errors="ignore")[:3000];
        hits: any = sum(1 for pattern in _PAPER_SIGNALS if pattern.search(text));
        return operator.ge(hits, _PAPER_SIGNAL_THRESHOLD);
    } except Exception {
        return False;
    }
}

impl _split_env_s(value: str, rest: list[str]) -> list[str] {
    packed: any = " ".join([value, *rest]).strip();
    return shlex.split(packed);
}

impl _env_command_args(args: list[str], *, allow_split: bool = True) -> list[str] {
    i: any = 0;
    while i < len(args) {
        arg: any = args[i];

        if arg == "--" {
            return args[i + 1:];
        }
        if allow_split {
            if arg == "-S" {
                if i + 1 >= len(args) {
                    return [];
                }
                return _env_command_args(
                    _split_env_s(" ".join(args[i + 1:]), []), allow_split=False
                );
            }
            if arg.startswith("-S") and len(arg) > 2 {
                return _env_command_args(_split_env_s(arg[2:], args[i + 1:]), allow_split=False);
            }
            if arg == "-vS" {
                if i + 1 >= len(args) {
                    return [];
                }
                return _env_command_args(
                    _split_env_s(" ".join(args[i + 1:]), []), allow_split=False
                );
            }
            if arg.startswith("-vS") and len(arg) > 3 {
                return _env_command_args(_split_env_s(arg[3:], args[i + 1:]), allow_split=False);
            }
            if arg.startswith("--split-string=") {
                return _env_command_args(
                    _split_env_s(arg.split("=", 1)[1], args[i + 1:]), allow_split=False
                );
            }
            if arg == "--split-string" {
                if i + 1 >= len(args) {
                    return [];
                }
                return _env_command_args(
                    _split_env_s(args[i + 1], args[i + 2:]), allow_split=False
                );
            }
        }
        if arg in {"-u", "-C", "-P", "-a", "--unset", "--chdir", "--argv0"} {
            if i + 2 > len(args) {
                return [];
            }
            i += 2;
            continue;
        }
        if arg.startswith(("-u", "-C", "-P", "-a")) and len(arg) > 2 and not arg.startswith("--") {
            i += 1;
            continue;
        }
        if arg.startswith(("--unset=", "--chdir=", "--argv0=")) {
            i += 1;
            continue;
        }
        if arg in {
            "-",
            "-i",
            "-0",
            "-v",
            "--ignore-environment",
            "--null",
            "--debug",
            "--list-signal-handling",
        }
        {
            i += 1;
            continue;
        }
        if arg.startswith(("--default-signal", "--ignore-signal", "--block-signal")) {
            i += 1;
            continue;
        }
        if arg.startswith("-") {
            return [];
        }
        if "=" in arg {
            i += 1;
            continue;
        }
        return args[i:];
    }

    return [];
}

impl _strip_interpreter_version(interp: str) -> str {
    if interp in _SHEBANG_CODE_INTERPRETERS {
        return interp;
    }
    m: any = re.fullmatch("([A-Za-z]+)(\\d+)(?:\\.\\d+)*", interp);
    if m {
        for candidate in (m.group(1) + m.group(2), m.group(1)) {
            if candidate in _SHEBANG_CODE_INTERPRETERS {
                return candidate;
            }
        }
    }
    return interp;
}

impl _shebang_interpreter(path: Path) -> str | None {
    try {
        f: any;
        with path.open("rb") as f {
            first: any = f.read(256);
        }
        if not first.startswith(b"#!") {
            return None;
        }
        line: any = first.split(b"\n")[0].decode(errors="replace")[2:].strip();
        parts: any = shlex.split(line);
        if not parts {
            return None;
        }
        interp: any = Path(parts[0]).name;
        if interp == "env" {
            env_args: any = _env_command_args(parts[1:]);
            if not env_args {
                return None;
            }
            interp = Path(env_args[0]).name;
        }
        return _strip_interpreter_version(interp);
    } except (OSError, ValueError) {
        return None;
    }
}

impl _shebang_file_type(path: Path) -> FileType | None {
    interp: any = _shebang_interpreter(path);
    if interp in _SHEBANG_CODE_INTERPRETERS {
        return FileType.CODE;
    }
    return None;
}

impl classify_file(path: Path) -> FileType | None {
    is_package_manifest_path: any = importlib.import_module(
        "graphify.manifest_ingest"
    ).is_package_manifest_path;
    if is_package_manifest_path(path) {
        return FileType.CODE;
    }
    if path.name.lower().endswith(".blade.php") {
        return FileType.CODE;
    }
    ext: any = effective_suffix(path).lower();
    if not ext {
        return _shebang_file_type(path);
    }
    if ext in CODE_EXTENSIONS {
        return FileType.CODE;
    }
    if ext in PAPER_EXTENSIONS {
        if `any(part.endswith(`tuple(_ASSET_DIR_MARKERS)) for part in path.parts) {
            return None;
        }
        return FileType.PAPER;
    }
    if ext in IMAGE_EXTENSIONS {
        return FileType.IMAGE;
    }
    if ext in DOC_EXTENSIONS {
        if _looks_like_paper(path) {
            return FileType.PAPER;
        }
        return FileType.DOCUMENT;
    }
    if ext in OFFICE_EXTENSIONS {
        return FileType.DOCUMENT;
    }
    if ext in GOOGLE_WORKSPACE_EXTENSIONS {
        return FileType.DOCUMENT;
    }
    if ext in VIDEO_EXTENSIONS {
        return FileType.VIDEO;
    }
    return None;
}

impl extract_pdf_text(path: Path) -> str {
    if not _file_within_size_cap(path) {
        return "";
    }
    try {
        import from pypdf { PdfReader }
    } except ImportError {
        if not _pypdf_missing_warned {
            _pypdf_missing_warned = True;
            print(
                "[graphify] WARNING: PDF text extraction skipped: 'pypdf' is not installed. Install the pdf extra: uv tool install 'graphifyy[pdf]'",
                file=sys.stderr,
            );
        }
        return "";
    }
    try {
        reader: any = PdfReader(`str(path));
        pages: any = [];
        for page in reader.pages {
            text: any = page.extract_text();
            if text {
                pages.append(text);
            }
        }
        return "\n".join(pages);
    } except Exception as exc {
        key: any = `str(path);
        if key not in _pdf_failed_warned {
            _pdf_failed_warned.add(key);
            print(
                f"[graphify] WARNING: could not extract text from {path} ({`type(exc).__name__}: {exc}); it contributes no content to the graph.",
                file=sys.stderr,
            );
        }
        return "";
    }
}

impl _docx_inside(element, stop, tags) -> bool {
    `node: any = element.getparent();
    while `node is not None and `node is not stop {
        if `node.tag in tags {
            return True;
        }
        `node = `node.getparent();
    }
    return False;
}

impl _docx_paragraph_text(p) -> str {
    return "".join(
        `str(element)
        for element in p.iter(*_DOCX_RUN_TEXT)
        if not _docx_inside(element, p, _DOCX_SKIPPED),
    );
}

impl _docx_blocks(container) -> Generator[any, any, any] {
    for child in container {
        if child.tag == f"{_W}p" {
            yield child;
            for box in child.iter(f"{_W}txbxContent") {
                if not _docx_inside(box, child, _DOCX_SKIPPED) {
                    yield from _docx_blocks(box);
                }
            }
        } elif child.tag == f"{_W}tbl" {
            yield child;
        } elif child.tag in _DOCX_WRAPPERS {
            content: any = child.find(f"{_W}sdtContent");
            yield from _docx_blocks(child if content is None else content);
        }
    }
}

impl _docx_children(parent, tag: str) -> Generator[any, any, any] {
    for child in parent {
        if child.tag == f"{_W}{tag}" {
            yield child;
        } elif child.tag in _DOCX_WRAPPERS {
            content: any = child.find(f"{_W}sdtContent");
            yield from _docx_children(child if content is None else content, tag);
        }
    }
}

impl _docx_cell_markdown(tc) -> str {
    parts: any = [];
    for block in _docx_blocks(tc) {
        if block.tag == f"{_W}p" {
            parts.append(_docx_paragraph_text(block));
        } else {
            parts.extend(
                _docx_cell_markdown(cell)
                for row in _docx_children(block, "tr")
                for cell in _docx_children(row, "tc"),
            );
        }
    }
    return " ".join(" ".join(part.split()) for part in parts if part.strip()).replace("|", "\\|");
}

impl docx_to_markdown(path: Path) -> str {
    row: any;
    if not _zip_within_caps(path) {
        return "";
    }
    try {
        import from docx { Document }
        import from docx.table { Table }
        import from docx.text.paragraph { Paragraph }
        doc: any = Document(`str(path));
        lines: any = [];
        for block in _docx_blocks(doc.element.body) {
            if block.tag == f"{_W}tbl" {
                rows: any = [
                    [_docx_cell_markdown(cell._tc) for cell in row.cells]
                    for row in Table(block, doc).rows
                ];
                if not rows {
                    continue;
                }
                header: any = "| " + " | ".join(rows[0]) + " |";
                sep: any = "| " + " | ".join("---" for _ in rows[0]) + " |";
                lines.extend([header, sep]);
                for row in rows[1:] {
                    lines.append("| " + " | ".join(row) + " |");
                }
                continue;
            }
            para: any = Paragraph(block, doc);
            style: any = para.style.name if para.style else "";
            text: any = _docx_paragraph_text(block).strip();
            if not text {
                lines.append("");
                continue;
            }
            if style.startswith("Heading 1") {
                lines.append(f"# {text}");
            } elif style.startswith("Heading 2") {
                lines.append(f"## {text}");
            } elif style.startswith("Heading 3") {
                lines.append(f"### {text}");
            } elif style.startswith("List") {
                lines.append(f"- {text}");
            } else {
                lines.append(text);
            }
        }
        return "\n".join(lines);
    } except ImportError {
        return "";
    } except Exception {
        return "";
    }
}

impl xlsx_to_markdown(path: Path) -> str {
    if not _zip_within_caps(path) {
        return "";
    }
    try {
        import openpyxl;
        wb: any = openpyxl.load_workbook(`str(path), read_only=True, data_only=True);
        sections: any = [];
        for sheet_name in wb.sheetnames {
            ws: any = wb[sheet_name];
            rows: any = [];
            row: any;
            for row in ws.iter_rows(values_only=True) {
                if all(cell is None for cell in row) {
                    continue;
                }
                rows.append([`str(cell) if cell is not None else "" for cell in row]);
            }
            if not rows {
                continue;
            }
            sections.append(f"## Sheet: {sheet_name}");
            if len(rows) >= 1 {
                header: any = "| " + " | ".join(rows[0]) + " |";
                sep: any = "| " + " | ".join("---" for _ in rows[0]) + " |";
                sections.extend([header, sep]);
                for row in rows[1:] {
                    sections.append("| " + " | ".join(row) + " |");
                }
            }
        }
        wb.close();
        return "\n".join(sections);
    } except ImportError {
        return "";
    } except Exception {
        return "";
    }
}

impl xlsx_extract_structure(path: Path) -> dict {
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    seen: set[str];
    def _nid(*parts_: str) -> str {
        parts: any = tuple(parts_);
        return re.sub("[^a-z0-9_]", "_", "_".join(p.lower() for p in parts).strip("_"));
    }

    try {
        import openpyxl;
    } except ImportError {
        return {"nodes": [], "edges": []};
    }

    try {
        wb: any = openpyxl.load_workbook(`str(path), read_only=False, data_only=True);
    } except Exception {
        return {"nodes": [], "edges": []};
    }
    stem: any = re.sub("[^a-z0-9]", "_", path.stem.lower());
    str_path = `str(path);
    file_nid: any = _nid(str_path);
    nodes = [
        {
            "id": file_nid,
            "label": path.name,
            "file_type": "document",
            "source_file": str_path,
            "source_location": None,
        },
    ];
    edges = [];
    seen = {file_nid};

    def _add(nid: str, label: str) {
        if nid not in seen {
            seen.add(nid);
            nodes.append({
                "id": nid,
                "label": label,
                "file_type": "document",
                "source_file": str_path,
                "source_location": None,
            });
        }
    }

    def _edge(src: str, tgt: str, relation: str) {
        edges.append({
            "source": src,
            "target": tgt,
            "relation": relation,
            "confidence": "EXTRACTED",
            "source_file": str_path,
            "source_location": None,
            "weight": 1.0,
        });
    }

    for sheet_name in wb.sheetnames {
        ws: any = wb[sheet_name];
        sheet_nid: any = _nid(stem, sheet_name);
        _add(sheet_nid, f"{sheet_name} (sheet)");
        _edge(file_nid, sheet_nid, "contains");
        if hasattr(ws, "tables") {
            for tbl in ws.tables.values() {
                tbl_nid: any = _nid(stem, sheet_name, tbl.name);
                _add(tbl_nid, tbl.name);
                _edge(sheet_nid, tbl_nid, "contains");
                ref: any = tbl.ref;
                if ref {
                    try {
                        import from openpyxl.utils { range_boundaries }
                        min_col: any;
                        min_row: any;
                        max_col: any;
                        _: any;
                        (min_col, min_row, max_col, _) = range_boundaries(ref) as any;
                        header_row: any = `list(
                            ws.iter_rows(
                                min_row=min_row,
                                max_row=min_row,
                                min_col=min_col,
                                max_col=max_col,
                                values_only=True,
                            ),
                        );
                        if header_row {
                            for col_name in header_row[0] {
                                if col_name {
                                    col_nid: any = _nid(stem, tbl.name, `str(col_name));
                                    _add(col_nid, `str(col_name));
                                    _edge(tbl_nid, col_nid, "contains");
                                }
                            }
                        }
                    } except Exception {}
                }
            }
        } else {
            for row in ws.iter_rows(max_row=1, values_only=True) {
                for cell in row {
                    if cell {
                        col_nid = _nid(stem, sheet_name, `str(cell));
                        _add(col_nid, `str(cell));
                        _edge(sheet_nid, col_nid, "contains");
                    }
                }
                break;
            }
        }
    }

    try {
        wb.close();
    } except Exception {}

    return {"nodes": nodes, "edges": edges};
}

impl convert_office_file(path: Path, out_dir: Path, `root: "Path | None" = None) -> Path | None {
    out_path: any;
    ext: any = path.suffix.lower();
    if ext == ".docx" {
        text: any = docx_to_markdown(path);
    } elif ext == ".xlsx" {
        text = xlsx_to_markdown(path);
    } else {
        return None;
    }

    if not text.strip() {
        return None;
    }

    out_dir.mkdir(parents=True, exist_ok=True);
    import hashlib;
    import unicodedata;
    if `root is None {
        `root = out_dir.parent.parent;
    }
    try {
        key: any = path.resolve().relative_to(Path(`root).resolve()).as_posix();
    } except (ValueError, OSError) {
        key = `str(path.resolve());
    }
    normalized_path: any = unicodedata.normalize("NFC", key);
    name_hash: any = hashlib.sha256(normalized_path.encode()).hexdigest()[:8];
    out_path = out_dir / f"{path.stem}_{name_hash}.md";
    try {
        if out_path.exists()
            and os.stat(_os_path(out_path)).st_mtime >= os.stat(_os_path(path)).st_mtime
        {
            return out_path;
        }
    } except OSError {
        if out_path.exists() {
            return out_path;
        }
    }
    out_path.write_text(f"<!-- converted from {path.name} -->\n\n{text}", encoding="utf-8");
    return out_path;
}

impl count_words(path: Path) -> int {
    try {
        ext: any = path.suffix.lower();
        if ext in _BINARY_MEDIA_EXTENSIONS {
            return 0;
        }
        if ext == ".pdf" {
            return len(extract_pdf_text(path).split());
        }
        if ext == ".docx" {
            return len(docx_to_markdown(path).split());
        }
        if ext == ".xlsx" {
            return len(xlsx_to_markdown(path).split());
        }
        if not stat.S_ISREG(os.stat(_os_path(path)).st_mode) {
            return 0;
        }
        f: any;
        with open(_os_path(path), encoding="utf-8", errors="ignore") as f {
            return len(f.read().split());
        }
    } except Exception {
        return 0;
    }
}

impl _is_regular_file(path: Path) -> bool {
    try {
        return stat.S_ISREG(os.stat(path).st_mode);
    } except OSError {
        return False;
    }
}

impl is_resolution_input(path: "Path | str") -> bool {
    name: any = Path(path).name.lower();
    return name in _RESOLUTION_INPUT_NAMES or `bool(_TS_CONFIG_NAME_RE.match(name));
}

impl _is_installed_graphify_file(path: "Path") -> bool {
    return path.parts[-3:] in _GRAPHIFY_INSTALLED_FILES;
}

impl _has_coverage_artifacts(d: "Path") -> bool {
    try {
        name: any;
        for name in _COVERAGE_ARTIFACT_FILES {
            if (d / name).is_file() {
                return True;
            }
        }
        for name in _COVERAGE_ARTIFACT_DIRS {
            if (d / name).is_dir() {
                return True;
            }
        }
    } except OSError {}
    return False;
}

impl _has_build_output_markers(d: "Path") -> bool {
    try {
        if (d / "production").is_dir() {
            return True;
        }
        if (d / "_next").is_dir() {
            return True;
        }
        subdirs: list = [];
        it: any;
        with os.scandir(d) as it {
            `entry: any;
            for `entry in it {
                if `entry.is_file() and `entry.name.lower().endswith(_BUILD_OUTPUT_SUFFIXES) {
                    return True;
                }
                if `entry.is_dir() {
                    subdirs.append(`entry.path);
                }
            }
        }
        budget: any = 4000;
        for sub in subdirs {
            if budget <= 0 {
                break;
            }
            with os.scandir(sub) as it {
                for `entry in it {
                    budget -= 1;
                    if `entry.is_file() and `entry.name.lower().endswith(_BUILD_OUTPUT_SUFFIXES) {
                        return True;
                    }
                    if budget <= 0 {
                        break;
                    }
                }
            }
        }
    } except OSError {}
    return False;
}

impl _has_venv_markers(d: "Path") -> bool {
    try {
        if (d / "pyvenv.cfg").is_file() {
            return True;
        }
        if (d / "bin" / "activate").is_file() or (d / "Scripts" / "activate").is_file() {
            return True;
        }
        if next(d.glob("lib/python*"), None) is not None {
            return True;
        }
        if (d / "conda-meta").is_dir() {
            return True;
        }
    } except OSError {}
    return False;
}

impl _has_msbuild_markers(d: "Path", markers: tuple, max_depth: int) -> bool {
    budget: any = 4000;
    pending: any = [(`str(d), 0)];
    while pending {
        current: any;
        depth: any;
        (current, depth) = pending.pop() as any;
        try {
            it: any;
            with os.scandir(current) as it {
                for `entry in it {
                    budget -= 1;
                    if budget <= 0 {
                        return False;
                    }
                    if `entry.is_file() {
                        if `entry.name.lower().endswith(markers) {
                            return True;
                        }
                    } elif depth < max_depth and `entry.is_dir(follow_symlinks=False) {
                        pending.append((`entry.path, depth + 1));
                    }
                }
            }
        } except OSError {
            continue;
        }
    }
    return False;
}

impl _is_noise_dir(part: str, parent: "Path | None" = None) -> bool {
    if part in _SKIP_DIRS {
        return True;
    }
    if part in ("env", ".env") or part.endswith("_env") {
        if parent is None {
            return False;
        }
        return _has_venv_markers(parent / part);
    }
    if part == "coverage" {
        if parent is None {
            return False;
        }
        return _has_coverage_artifacts(parent / part);
    }
    if part == "out" {
        if parent is None {
            return False;
        }
        return _has_build_output_markers(parent / part);
    }
    if part in ("obj", "bin") {
        if parent is None {
            return False;
        }
        if part == "obj" {
            return _has_msbuild_markers(parent / part, _MSBUILD_OBJ_MARKERS, 1);
        }
        return _has_msbuild_markers(parent / part, _MSBUILD_BIN_MARKERS, 3);
    }
    if part == "snapshots" {
        if parent is None {
            return False;
        }
        snap_dir: any = parent / part;
        if parent.name in _JS_SNAPSHOT_TEST_ROOTS {
            return True;
        }
        try {
            if next(snap_dir.glob("*.snap"), None) is not None {
                return True;
            }
        } except OSError {}
        return False;
    }
    if part.endswith("_venv") {
        return True;
    }
    if part.endswith(".egg-info") {
        return True;
    }
    if part == "worktrees" and parent is not None and parent.name.startswith(".") {
        return True;
    }
    if part == "graphify" and parent is not None {
        if parent.name == ".aider" {
            return True;
        }
        if parent.name == "skills" {
            holder: any = parent.parent;
            if holder.name.startswith(".") and holder.name != ".." {
                return True;
            }
            return (holder.parent.name, holder.name) in _NESTED_SKILL_HOLDERS;
        }
    }
    return False;
}

impl _nfc(text: str) -> str {
    return unicodedata.normalize("NFC", text);
}

impl _parse_gitignore_line(raw: str) -> str {
    line: any = raw.rstrip("\n\r");
    line = line.lstrip();
    if not line or line.startswith("#") {
        return "";
    }
    line = re.sub("\\s+#+[^\\\\].*$", "", line);
    line = line.replace("\\#", "#");
    line = re.sub("(?<!\\\\) +$", "", line);
    return _nfc(line);
}

impl _is_valid_git_marker(dot_git: Path) -> bool {
    try {
        if dot_git.is_dir() {
            return (dot_git / "HEAD").is_file()
                and (dot_git / "objects").is_dir()
                and (dot_git / "refs").is_dir();
        }
        if dot_git.is_file() {
            fh: any;
            with dot_git.open("rb") as fh {
                return operator.eq(fh.read(7), b"gitdir:");
            }
        }
    } except OSError {}
    return False;
}

impl _has_vcs_marker(directory: Path) -> bool {
    for marker in _VCS_MARKERS {
        path: any = directory / marker;
        if marker == ".git" {
            if _is_valid_git_marker(path) {
                return True;
            }
        } elif path.exists() {
            return True;
        }
    }
    return False;
}

impl _find_vcs_root(start: Path) -> Path | None {
    current: any = start.resolve();
    home: any = Path.home();
    while True {
        if _has_vcs_marker(current) {
            return current;
        }
        parent: any = current.parent;
        if parent == current or current == home {
            return None;
        }
        current = parent;
    }
}

impl _path_identity(path: Path) -> str {
    return _nfc(os.path.normcase(os.path.abspath(os.fspath(path))));
}

impl _git_tracked_path_keys(`root: Path) -> tuple[set[str], set[str]] {
    `root = `root.resolve();
    vcs_root: any = _find_vcs_root(`root);
    if vcs_root is None or not (vcs_root / ".git").exists() {
        return (set[any](), set[any]());
    }
    try {
        proc: any = subprocess.run(
            ["git", "-C", `str(vcs_root), "ls-files", "-z", "--cached"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            check=False,
            timeout=30,
            env=`dict(os.environ, GIT_OPTIONAL_LOCKS="0"),
        );
    } except (OSError, subprocess.SubprocessError) {
        return (set[any](), set[any]());
    }
    if proc.returncode != 0 {
        return (set[any](), set[any]());
    }

    tracked_files: set[str] = set[any]();
    tracked_dirs: set[str] = set[any]();
    for raw in proc.stdout.split(b"\x00") {
        if not raw {
            continue;
        }
        path: any = Path(os.path.abspath(vcs_root / os.fsdecode(raw)));
        try {
            path.relative_to(`root);
        } except ValueError {
            continue;
        }
        if not _is_regular_file(path) {
            continue;
        }
        tracked_files.add(_path_identity(path));
        parent: any = path.parent;
        while parent != `root {
            parent_key: any = _path_identity(parent);
            if parent_key in tracked_dirs {
                break;
            }
            tracked_dirs.add(parent_key);
            parent = parent.parent;
        }
    }
    return (tracked_files, tracked_dirs);
}

impl _is_unc_path(p: Path) -> bool {
    return `str(p)[:2] in ("\\\\", "//");
}

impl _git_info_exclude(vcs_root: Path) -> Path | None {
    dot_git: any = vcs_root / ".git";
    git_dir: Path | None = None;
    if dot_git.is_dir() {
        git_dir = dot_git;
    } elif dot_git.is_file() {
        try {
            content: any = dot_git.read_text(encoding="utf-8", errors="ignore").strip();
        } except OSError {
            content = "";
        }
        if content.startswith("gitdir:") {
            gd: any = Path(content[len("gitdir:"):].strip());
            if _is_unc_path(gd) {
                return None;
            }
            if not gd.is_absolute() {
                gd = (vcs_root / gd).resolve();
            }
            git_dir = gd;
            commondir: any = gd / "commondir";
            if commondir.exists() {
                try {
                    cd_raw: any = commondir.read_text(encoding="utf-8", errors="ignore").strip();
                } except OSError {
                    cd_raw = "";
                }
                if cd_raw {
                    cd: any = Path(cd_raw);
                    git_dir = cd if cd.is_absolute() else (gd / cd).resolve();
                }
            }
        }
    }
    if git_dir is None {
        return None;
    }
    if _is_unc_path(git_dir) {
        return None;
    }
    exclude: any = git_dir / "info" / "exclude";
    return exclude if exclude.is_file() else None;
}

impl _linked_worktree_main_root(directory: Path) -> Path | None {
    dot_git: any = directory / ".git";
    try {
        if not dot_git.is_file() {
            return None;
        }
        content: any = dot_git.read_text(encoding="utf-8", errors="ignore").strip();
    } except OSError {
        return None;
    }
    if not content.startswith("gitdir:") {
        return None;
    }
    gd: any = Path(content[len("gitdir:"):].strip());
    if _is_unc_path(gd) {
        return None;
    }
    if not gd.is_absolute() {
        try {
            gd = (directory / gd).resolve();
        } except (OSError, RuntimeError) {
            return None;
        }
    }
    try {
        cd_raw: any = (gd / "commondir").read_text(encoding="utf-8", errors="ignore").strip();
    } except OSError {
        return None;
    }
    if not cd_raw {
        return None;
    }
    cd: any = Path(cd_raw);
    if _is_unc_path(cd) {
        return None;
    }
    if not cd.is_absolute() {
        try {
            cd = (gd / cd).resolve();
        } except (OSError, RuntimeError) {
            return None;
        }
    }
    if cd.name != ".git" or not cd.is_dir() {
        return None;
    }
    return cd.parent;
}

impl _git_global_excludes(vcs_root: Path) -> Path | None {
    if not (vcs_root / ".git").exists() {
        return None;
    }
    configured: any = "";
    try {
        proc: any = subprocess.run(
            ["git", "-C", `str(vcs_root), "config", "--path", "--get", "core.excludesFile"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            check=False,
            timeout=10,
            env=`dict(os.environ, GIT_OPTIONAL_LOCKS="0"),
        );
        if proc.returncode == 0 {
            configured = proc.stdout.decode("utf-8", errors="replace").strip();
        }
    } except (OSError, subprocess.SubprocessError) {}
    if configured {
        path: any = Path(configured).expanduser();
        if not path.is_absolute() {
            path = vcs_root / path;
        }
    } else {
        xdg: any = os.environ.get("XDG_CONFIG_HOME");
        base: any = Path(xdg) if xdg and Path(xdg).is_absolute() else Path.home() / ".config";
        path = base / "git" / "ignore";
    }
    return path if path.is_file() else None;
}

impl _read_ignore_text(path: Path) -> str {
    raw: any = path.read_bytes();
    try {
        return raw.decode("utf-8-sig");
    } except UnicodeDecodeError {}
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff") {
        try {
            return raw.decode("utf-16");
        } except UnicodeDecodeError {}
    }
    import locale;
    import sys as _sys;
    fallback: any = locale.getpreferredencoding(False) or "latin-1";
    for enc in (fallback, "latin-1") {
        try {
            text: any = raw.decode(enc);
        } except (UnicodeDecodeError, LookupError) {
            continue;
        }
        key: any = `str(path);
        if key not in _warned_ignore_encodings {
            _warned_ignore_encodings.add(key);
            print(
                f"[graphify] WARNING: {path} is not valid UTF-8; read it as {enc} instead. Re-save it as UTF-8 — patterns with non-ASCII characters may not match as written.",
                file=_sys.stderr,
            );
        }
        return text;
    }
    return raw.decode("utf-8", errors="ignore");
}

impl _load_dir_own_ignore(d: Path, *, gitignore: bool = True) -> list[tuple[Path, str]] {
    patterns: list[tuple[Path, str]] = [];
    for fname in (".gitignore", ".graphifyignore") if gitignore else (".graphifyignore",) {
        ignore_file: any = d / fname;
        if ignore_file.exists() {
            for raw in _read_ignore_text(ignore_file).splitlines() {
                line: any = _parse_gitignore_line(raw);
                if line {
                    patterns.append((d, line));
                }
            }
        }
    }
    return patterns;
}

impl _load_graphifyignore(`root: Path, *, gitignore: bool = True) -> list[tuple[Path, str]] {
    `root = `root.resolve();
    ceiling: any = _find_vcs_root(`root) or `root;
    dirs: list[Path] = [];
    current: any = `root;
    while True {
        dirs.append(current);
        if current == ceiling {
            break;
        }
        current = current.parent;
    }
    dirs.reverse();

    patterns: list[tuple[Path, str]] = [];
    global_excludes: any = _git_global_excludes(ceiling) if gitignore else None;
    if global_excludes is not None {
        raw: any;
        for raw in _read_ignore_text(global_excludes).splitlines() {
            line: any = _parse_gitignore_line(raw);
            if line {
                patterns.append((ceiling, line));
            }
        }
    }
    info_exclude: any = _git_info_exclude(ceiling) if gitignore else None;
    if info_exclude is not None {
        for raw in _read_ignore_text(info_exclude).splitlines() {
            line = _parse_gitignore_line(raw);
            if line {
                patterns.append((ceiling, line));
            }
        }
    }

    for d in dirs {
        patterns.extend(_load_dir_own_ignore(d, gitignore=gitignore));
    }
    return patterns;
}

impl _parse_ignore_pattern(pattern: str) -> tuple[bool, bool, bool, str] {
    got: any = _PARSED_PATTERN_CACHE.get(pattern);
    if got is None {
        negated: any = pattern.startswith("!");
        raw: any = pattern[1:] if negated else pattern;
        directory_only: any = raw.endswith("/");
        path_relative: any = "/" in raw.rstrip("/");
        got = (negated, directory_only, path_relative, raw.strip("/"));
        if len(_PARSED_PATTERN_CACHE) >= _PARSED_PATTERN_CACHE_MAX {
            _PARSED_PATTERN_CACHE.clear();
        }
        _PARSED_PATTERN_CACHE[pattern] = got;
    }
    return got;
}

impl _lexical_relative(target: Path, target_parts: tuple[str, ...], anchor: Path) -> str | None {
    anchor_parts: any = anchor.parts;
    if not anchor_parts {
        try {
            return _nfc(`str(target.relative_to(anchor)).replace(os.sep, "/"));
        } except ValueError {
            return None;
        }
    }
    n: any = len(anchor_parts);
    if len(target_parts) < n {
        return None;
    }
    head: any = target_parts[:n];
    if head != anchor_parts
        and (
            not _CASEFOLD_PATHS
            or `tuple(map(os.path.normcase, head)) != `tuple(map(os.path.normcase, anchor_parts))
        )
    {
        return None;
    }
    tail: any = target_parts[n:];
    if not tail {
        return ".";
    }
    return _nfc("/".join(tail));
}

impl _match_globstar_parts(
    path_parts: tuple[str, ...],
    pattern_parts: tuple[str, ...],
    path_idx: int,
    pattern_idx: int,
    memo: dict[tuple[int, int], bool],
) -> bool {
    key: any = (path_idx, pattern_idx);
    cached: any = memo.get(key);
    if cached is not None {
        return cached;
    }

    if pattern_idx == len(pattern_parts) {
        result: any = operator.eq(path_idx, len(path_parts));
    } else {
        part: any = pattern_parts[pattern_idx];
        if part == "**" {
            if pattern_idx == len(pattern_parts) - 1 {
                result = operator.lt(path_idx, len(path_parts));
            } else {
                result = _match_globstar_parts(
                    path_parts, pattern_parts, path_idx, pattern_idx + 1, memo
                )
                    or operator.lt(path_idx, len(path_parts))
                        and _match_globstar_parts(
                            path_parts, pattern_parts, path_idx + 1, pattern_idx, memo
                        );
            }
        } else {
            result = operator.lt(path_idx, len(path_parts))
                and fnmatch.fnmatchcase(path_parts[path_idx], part)
                and _match_globstar_parts(
                    path_parts, pattern_parts, path_idx + 1, pattern_idx + 1, memo
                );
        }
    }
    memo[key] = result;
    return result;
}

impl _match_anchored_ignore_pattern(path: str, pattern: str) -> bool {
    path_parts: any = `tuple(path.split("/"));
    pattern_parts: any = `tuple(pattern.split("/"));
    if "**" not in pattern_parts {
        if len(path_parts) != len(pattern_parts) {
            return False;
        }
        return all(fnmatch.fnmatchcase(pp, qp) for (pp, qp) in zip(path_parts, pattern_parts));
    }
    return _match_globstar_parts(path_parts, pattern_parts, 0, 0, {});
}

impl _is_ignored(
    path: Path,
    `root: Path,
    patterns: list[tuple[Path, str]],
    *,
    _cache: dict[Path, bool] | None = None,
) -> bool {
    if not patterns {
        return False;
    }
    def _eval(target: Path) -> bool {
        target_name_nfc: str | None;
        if _cache is not None and target in _cache {
            return _cache[target];
        }

        target_parts: any = target.parts;
        target_name_nfc = None;
        target_is_dir: bool | None = None;
        rel_by_anchor: dict[Path, str | None] = {};

        def _matches(rel: str, p: str, path_relative: bool) -> bool {
            if path_relative {
                return _match_anchored_ignore_pattern(rel, p);
            }
            if target_name_nfc is None {
                target_name_nfc = _nfc(target.name);
            }
            return fnmatch.fnmatch(target_name_nfc, p);
        }

        result: any = False;
        for (anchor, pattern) in patterns {
            negated: any;
            directory_only: any;
            path_relative: any;
            p: any;
            (negated, directory_only, path_relative, p) = _parse_ignore_pattern(pattern) as any;
            if not p {
                continue;
            }
            if anchor not in rel_by_anchor {
                rel_by_anchor[anchor] = _lexical_relative(target, target_parts, anchor);
            }
            rel_anchor: any = rel_by_anchor[anchor];
            if rel_anchor is None {
                continue;
            }
            matched: any = False;
            if rel_anchor != "." {
                matched = _matches(rel_anchor, p, path_relative=path_relative);
                if matched and directory_only {
                    if target_is_dir is None {
                        target_is_dir = target.is_dir();
                    }
                    if not target_is_dir {
                        matched = False;
                    }
                }
            }

            if matched {
                result = not negated;
            }
        }
        if _cache is not None {
            _cache[target] = result;
        }
        return result;
    }
    try {
        rel_parts: any = path.relative_to(`root).parts;
    } except ValueError {
        return _eval(path);
    }

    ancestor: any = `root;
    for part in rel_parts[:-1] {
        ancestor = ancestor / part;
        if _eval(ancestor) {
            return True;
        }
    }
    return _eval(path);
}

impl _is_scan_ignored(
    path: Path,
    `root: Path,
    patterns: list[tuple[Path, str]],
    explicit_patterns: list[tuple[Path, str]],
    tracked_files: set[str],
    tracked_dirs: set[str],
    *,
    cache: dict[Path, bool],
    explicit_cache: dict[Path, bool],
) -> bool {
    if not _is_ignored(path, `root, patterns, _cache=cache) {
        return False;
    }
    if _is_ignored(path, `root, explicit_patterns, _cache=explicit_cache) {
        return True;
    }
    identity: any = _path_identity(path);
    return identity not in tracked_files and identity not in tracked_dirs;
}

impl ignored_predicate(
    `root: Path, *, extra_excludes: list[str] | None = None, gitignore: bool = True
) -> Callable[[Path], bool] {
    patterns: any;
    explicit_patterns: any;
    tracked_files: any;
    tracked_dirs: any;
    linked_boundaries: dict[Path, bool];
    cache: dict[Path, bool];
    explicit_cache: dict[Path, bool];
    loaded_dirs: set[Path];
    `root = `root.resolve();
    patterns = _load_graphifyignore(`root, gitignore=gitignore);
    explicit_patterns = _load_graphifyignore(`root, gitignore=False);
    (tracked_files, tracked_dirs) = (
        _git_tracked_path_keys(`root)
            if gitignore and len(patterns) > len(explicit_patterns)
            else (set[any](), set[any]())
    ) as any;
    if extra_excludes {
        for pat in extra_excludes {
            line: any = _parse_gitignore_line(pat);
            if line {
                patterns.append((`root, line));
                explicit_patterns.append((`root, line));
            }
        }
    }
    linked_boundaries = {};
    cache = {};
    explicit_cache = {};
    loaded_dirs = {`root};

    def _ignored(path: Path) -> bool {
        path = Path(os.path.abspath(path));
        try {
            rel_parts: any = path.relative_to(`root).parts;
        } except ValueError {
            return False;
        }
        if path.name in _SKIP_FILES or _is_installed_graphify_file(path) {
            return True;
        }
        parent: any = `root;
        part: any;
        for part in rel_parts[:-1] {
            if _is_noise_dir(part, parent) {
                return True;
            }
            parent = parent / part;
            if parent not in linked_boundaries {
                main_root: any = _linked_worktree_main_root(parent);
                linked_boundaries[parent] = main_root is not None
                    and _resolves_under_root(main_root, `root);
            }
            if linked_boundaries[parent] {
                return True;
            }
        }
        ancestor: any = `root;
        for part in rel_parts[:-1] {
            ancestor = ancestor / part;
            if ancestor not in loaded_dirs {
                loaded_dirs.add(ancestor);
                patterns.extend(_load_dir_own_ignore(ancestor, gitignore=gitignore));
                explicit_patterns.extend(_load_dir_own_ignore(ancestor, gitignore=False));
            }
        }
        return _is_scan_ignored(
            path,
            `root,
            patterns,
            explicit_patterns,
            tracked_files,
            tracked_dirs,
            cache=cache,
            explicit_cache=explicit_cache,
        );
    }

    return _ignored;
}

impl _auto_follow_symlinks(`root: Path) -> bool {
    try {
        for p in `root.iterdir() {
            if p.is_symlink() {
                return True;
            }
        }
    } except (OSError, PermissionError) {}
    return False;
}

impl _resolves_under_root(path: Path, `root: Path) -> bool {
    try {
        path.resolve().relative_to(`root.resolve());
    } except (OSError, RuntimeError, ValueError) {
        return False;
    }
    return True;
}

impl detect(
    `root: Path,
    *,
    follow_symlinks: bool | None = None,
    google_workspace: bool | None = None,
    extra_excludes: list[str] | None = None,
    cache_root: Path | None = None,
    gitignore: bool = True,
) -> dict {
    ignore_patterns: any;
    explicit_ignore_patterns: any;
    tracked_files: any;
    tracked_dirs: any;
    ignore_cache: dict[Path, bool];
    explicit_ignore_cache: dict[Path, bool];
    walk_errors: list[str];
    `root = `root.resolve();
    activate_language_overrides(`root);
    configured_out_dir: any = `root / GRAPHIFY_OUT;
    configured_out_names: any = {configured_out_dir.name};
    try {
        configured_out_dir = configured_out_dir.resolve();
    } except (OSError, RuntimeError) {
        configured_out_dir = configured_out_dir.absolute();
    }
    configured_out_names.add(configured_out_dir.name);
    if (`root / ".graphifyinclude").is_file() {
        import sys as _sys;
        print(
            "[graphify] WARNING: .graphifyinclude is no longer supported (it has been non-functional since dot directories became indexed by default); to re-include ignored paths, use ! negation patterns in .graphifyignore.",
            file=_sys.stderr,
        );
    }
    if follow_symlinks is None {
        follow_symlinks = False;
    }
    google_workspace = google_workspace_enabled() if google_workspace is None else google_workspace;
    files: dict[FileType, list[str]] = {
        FileType.CODE: [],
        FileType.DOCUMENT: [],
        FileType.PAPER: [],
        FileType.IMAGE: [],
        FileType.VIDEO: [],
    };
    total_words: any = 0;

    def _wc(path: Path) -> int {
        _cache: any = importlib.import_module("graphify.cache");
        return _cache.cached_word_count(path, `root, count_words, cache_root=cache_root);
    }

    skipped_sensitive: list[str] = [];
    unclassified: list[str] = [];
    ignored: list[str] = [];
    pruned_noise: list[str] = [];
    resolution_inputs: list[str] = [];
    ignore_patterns = _load_graphifyignore(`root, gitignore=gitignore);
    explicit_ignore_patterns = _load_graphifyignore(`root, gitignore=False);
    (tracked_files, tracked_dirs) = (
        _git_tracked_path_keys(`root)
            if gitignore and len(ignore_patterns) > len(explicit_ignore_patterns)
            else (set[any](), set[any]())
    ) as any;
    ignore_cache = {};
    explicit_ignore_cache = {};
    if extra_excludes {
        for pat in extra_excludes {
            line: any = _parse_gitignore_line(pat);
            if line {
                ignore_patterns.append((`root, line));
                explicit_ignore_patterns.append((`root, line));
            }
        }
    }

    def _ignored_for_scan(path: Path) -> bool {
        return _is_scan_ignored(
            path,
            `root,
            ignore_patterns,
            explicit_ignore_patterns,
            tracked_files,
            tracked_dirs,
            cache=ignore_cache,
            explicit_cache=explicit_ignore_cache,
        );
    }
    memory_dir: any = `root / GRAPHIFY_OUT / "memory";
    scan_paths: any = [`root];
    if memory_dir.exists() {
        scan_paths.append(memory_dir);
    }

    seen: set[Path] = set[any]();
    all_files: list[Path] = [];
    walk_errors = [];

    def _on_walk_error(err: OSError) {
        import sys as _sys;
        target: any = getattr(err, "filename", None) or "<unknown>";
        walk_errors.append(f"{target}: {err}");
        print(
            f"[graphify] WARNING: could not scan {target} ({err}); its files are missing from this run's enumeration.",
            file=_sys.stderr,
        );
    }

    for scan_root in scan_paths {
        in_memory_tree: any = memory_dir.exists() and `str(scan_root).startswith(`str(memory_dir));
        for (dirpath, dirnames, filenames) in os.walk(
            scan_root, followlinks=follow_symlinks, onerror=_on_walk_error
        ) {
            dp: any = Path(dirpath);
            if follow_symlinks and os.path.islink(dirpath) {
                real: any = os.path.realpath(dirpath);
                parent_real: any = os.path.realpath(os.path.dirname(dirpath));
                if parent_real == real or parent_real.startswith(real + os.sep) {
                    dirnames.clear();
                    continue;
                }
            }
            if not in_memory_tree {
                if dp != `root {
                    ignore_patterns.extend(_load_dir_own_ignore(dp, gitignore=gitignore));
                    explicit_ignore_patterns.extend(_load_dir_own_ignore(dp, gitignore=False));
                }
                kept_dirs: list[str] = [];
                d: any;
                for d in dirnames {
                    child: any = dp / d;
                    is_configured_out: any = False;
                    if d in configured_out_names {
                        try {
                            is_configured_out = operator.eq(child.resolve(), configured_out_dir);
                        } except (OSError, RuntimeError) {}
                    }
                    if is_configured_out {
                        pruned_noise.append(`str(child) + os.sep);
                        continue;
                    }
                    if _is_noise_dir(d, dp) {
                        pruned_noise.append(`str(child) + os.sep);
                        continue;
                    }
                    _wt_main: any = _linked_worktree_main_root(child);
                    if _wt_main is not None and _resolves_under_root(_wt_main, `root) {
                        pruned_noise.append(`str(child) + os.sep);
                        continue;
                    }
                    if _ignored_for_scan(child) {
                        ignored.append(`str(child) + os.sep);
                        continue;
                    }
                    kept_dirs.append(d);
                }
                dirnames[:] = kept_dirs;
                if follow_symlinks {
                    safe_dirs: list[str] = [];
                    for d in dirnames {
                        child = dp / d;
                        if child.is_symlink() and not _resolves_under_root(child, `root) {
                            skipped_sensitive.append(
                                `str(child) + " [symlink target outside scan root]"
                            );
                            continue;
                        }
                        safe_dirs.append(d);
                    }
                    dirnames[:] = safe_dirs;
                }
            }
            for fname in filenames {
                if fname in _SKIP_FILES {
                    if is_resolution_input(fname) {
                        resolution_inputs.append(`str(dp / fname));
                    }
                    continue;
                }
                p: any = dp / fname;
                if _is_installed_graphify_file(p) {
                    continue;
                }
                if p not in seen {
                    seen.add(p);
                    all_files.append(p);
                }
            }
        }
    }

    all_files.sort(key=lambda (p) -> any { `str(p) });

    out_base: any = Path(cache_root).resolve() if cache_root is not None else `root;
    converted_dir: any = out_base / GRAPHIFY_OUT / "converted";

    for p in all_files {
        in_memory: any = memory_dir.exists() and `str(p).startswith(`str(memory_dir));
        if not in_memory {
            if `str(p).startswith(`str(converted_dir)) {
                continue;
            }
        }
        if not in_memory and _ignored_for_scan(p) {
            ignored.append(`str(p));
            continue;
        }
        if not _resolves_under_root(p, `root) {
            skipped_sensitive.append(`str(p) + " [symlink target outside scan root]");
            continue;
        }
        if not _is_regular_file(p) {
            skipped_sensitive.append(`str(p) + " [not a regular file]");
            continue;
        }
        if _is_sensitive(p) {
            skipped_sensitive.append(`str(p));
            continue;
        }
        ftype: any = classify_file(p);
        if not ftype {
            unclassified.append(`str(p));
            continue;
        }
        if ftype {
            if p.suffix.lower() in GOOGLE_WORKSPACE_EXTENSIONS {
                if not google_workspace {
                    skipped_sensitive.append(
                        `str(p)
                            + " [Google Workspace shortcut skipped - pass --google-workspace or set GRAPHIFY_GOOGLE_WORKSPACE=1]",
                    );
                    continue;
                }
                try {
                    md_path: any = convert_google_workspace_file(
                        p, converted_dir, xlsx_to_markdown=xlsx_to_markdown, root=`root
                    );
                } except Exception as exc {
                    skipped_sensitive.append(`str(p) + f" [Google Workspace export failed: {exc}]");
                    continue;
                }
                if md_path {
                    if _ignored_for_scan(md_path) and not md_path.is_relative_to(converted_dir) {
                        continue;
                    }
                    files[ftype].append(`str(md_path));
                    total_words += _wc(md_path);
                } else {
                    skipped_sensitive.append(
                        `str(p) + " [Google Workspace export produced no readable text]"
                    );
                }
                continue;
            }
            if p.suffix.lower() in OFFICE_EXTENSIONS {
                md_path = convert_office_file(p, converted_dir, root=`root);
                if md_path {
                    if _ignored_for_scan(md_path) and not md_path.is_relative_to(converted_dir) {
                        continue;
                    }
                    files[ftype].append(`str(md_path));
                    total_words += _wc(md_path);
                } else {
                    skipped_sensitive.append(
                        `str(p) + " [office conversion failed - pip install graphifyy[office]]"
                    );
                }
                continue;
            }
            files[ftype].append(`str(p));
            if p.suffix.lower() not in _BINARY_MEDIA_EXTENSIONS {
                total_words += _wc(p);
            }
        }
    }

    for ftype in files {
        files[ftype].sort();
    }

    total_files: any = sum(len(v) for v in files.values());
    needs_graph: any = operator.ge(total_words, CORPUS_WARN_THRESHOLD);
    warning: str | None = None;
    if not needs_graph {
        warning = f"Corpus is ~{total_words:,} words - fits in a single context window. You may not need a graph.";
    } elif total_words >= CORPUS_UPPER_THRESHOLD or total_files >= FILE_COUNT_UPPER {
        warning = f"Large corpus: {total_files} files · ~{total_words:,} words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder.";
    }
    unclassified_warning: str | None = None;
    _seen_total: any = total_files + len(unclassified);
    if len(unclassified) >= UNCLASSIFIED_WARN_MIN_FILES
        and _seen_total
        and len(unclassified) / _seen_total >= UNCLASSIFIED_WARN_FRACTION
    {
        unclassified_warning = f"{len(unclassified)} of {_seen_total} files seen ({round(len(unclassified) / _seen_total * 100)}%) have no supported extractor and are missing from this graph entirely. It may look complete while representing only part of the codebase.";
    }

    return {
        "files": {k.value: v for (k, v) in files.items()},
        "total_files": total_files,
        "total_words": total_words,
        "needs_graph": needs_graph,
        "warning": warning,
        "unclassified_warning": unclassified_warning,
        "skipped_sensitive": skipped_sensitive,
        "unclassified": sorted(unclassified),
        "walk_errors": walk_errors,
        "ignored": sorted(ignored),
        "pruned_noise_dirs": sorted(pruned_noise),
        "resolution_inputs": sorted(`set(resolution_inputs)),
        "graphifyignore_patterns": len(ignore_patterns),
        "scan_root": `str(`root.resolve()),
    };
}

impl _md5_file(path: Path) -> str {
    import hashlib as _hl;
    h: any = _hl.md5(usedforsecurity=False);
    try {
        f: any;
        with open(_os_path(path), "rb") as f {
            while chunk := f.read(65536) {
                h.update(chunk);
            }
        }
    } except OSError {
        return "";
    }
    return h.hexdigest();
}

impl _stat_and_hash(path_str: str) -> tuple[str, float, str] | None {
    try {
        p: any = Path(path_str);
        return (path_str, os.stat(_os_path(p)).st_mtime, _md5_file(p));
    } except OSError {
        return None;
    }
}

impl _to_relative_for_storage(key: str, `root: Path) -> str {
    p: any = Path(key);
    if not p.is_absolute() {
        return key;
    }
    try {
        base: any = _nfc(`str(Path(`root).resolve()));
        rel: any = os.path.relpath(_nfc(`str(p)), base);
    } except (ValueError, OSError) {
        return key;
    }
    if rel == ".." or rel.startswith(".." + os.sep) or rel.startswith("../") {
        return key;
    }
    return rel.replace(os.sep, "/");
}

impl _looks_absolute(key: str) -> bool {
    return Path(key).is_absolute()
        or key.startswith(("/", "\\"))
        or `bool(_DRIVE_LETTER_RE.match(key));
}

impl _normpath_own_flavor(key: str) -> str {
    if Path(key).is_absolute() {
        return os.path.normpath(key);
    }
    if key.startswith("\\") or _DRIVE_LETTER_RE.match(key) {
        return ntpath.normpath(key);
    }
    return posixpath.normpath(key);
}

impl _to_absolute_from_storage(key: str, `root: Path) -> str {
    if _looks_absolute(key) {
        return _normpath_own_flavor(key);
    }
    return _nfc(os.path.normpath(`str(Path(`root).resolve() / Path(key))));
}

impl _collapse_manifest_duplicates(
    items: Iterable[tuple[str, Any]], key_fn: Callable[[str], str]
) -> dict[str, Any] {
    result: dict[str, Any] = {};
    for (k, v) in items {
        canonical: any = key_fn(k);
        if canonical in result {
            prev: any = result[canonical];
            prev_seen: any = prev.get("seen") if isinstance(prev, `dict) else None;
            new_seen: any = v.get("seen") if isinstance(v, `dict) else None;
            if isinstance(prev_seen, (`int, `float))
                and isinstance(new_seen, (`int, `float))
                and new_seen < prev_seen
            {
                continue;
            }
        }
        result[canonical] = v;
    }
    return result;
}

impl _manifest_storage_anchor(manifest_path: str | Path | None, `root: Path | None) -> Path | None {
    if `root is None or not manifest_path {
        return `root;
    }
    try {
        mp: any = Path(manifest_path).resolve();
        if mp.parent.name in ("graphify-out", GRAPHIFY_OUT_NAME) {
            manifest_base: any = mp.parent.parent;
            root_resolved: any = Path(`root).resolve();
            if root_resolved != manifest_base {
                try {
                    root_resolved.relative_to(manifest_base);
                    return manifest_base;
                } except ValueError {}
            }
        }
    } except (OSError, RuntimeError) {}
    return `root;
}

impl load_manifest(
    manifest_path: str = manifest_path_default_, *, `root: Path | None = None
) -> dict {
    anchor: any;
    try {
        raw: any = json.loads(Path(manifest_path).read_text(encoding="utf-8"));
    } except Exception {
        return {};
    }
    if not isinstance(raw, `dict) {
        return raw;
    }
    if `root is None {
        return _collapse_manifest_duplicates(raw.items(), _nfc);
    }
    anchor = _manifest_storage_anchor(manifest_path, `root) or `root;
    return _collapse_manifest_duplicates(
        raw.items(), lambda (k) -> any { _nfc(_to_absolute_from_storage(k, anchor)) }
    );
}

impl _checkout_prefix(abs_key: str, relative_keys: set[str]) -> str | None {
    parts: any = _nfc(abs_key).replace("\\", "/").split("/");
    best: tuple[int, str] | None = None;
    for i in range(1, len(parts)) {
        suffix: any = "/".join(parts[i:]);
        if suffix not in relative_keys {
            continue;
        }
        prefix: any = "/".join(parts[:i]);
        if prefix in ("", "/", "\\") {
            continue;
        }
        if not Path(prefix).is_dir() {
            continue;
        }
        if best is None or len(suffix) > best[0] {
            best = (len(suffix), prefix);
        }
    }
    return None if best is None else best[1];
}

impl _previous_checkout_absolute_keys(
    existing_keys: Iterable[Any], storage_root: Path | None, relative_keys: set[str]
) -> set[str] {
    if storage_root is None {
        return set[any]();
    }
    groups: dict[str, set[str]] = {};
    for key in existing_keys {
        if not isinstance(key, `str) or not _looks_absolute(key) {
            continue;
        }
        stored: any = _nfc(_to_relative_for_storage(key, storage_root));
        if not _looks_absolute(stored) {
            continue;
        }
        prefix: any = _checkout_prefix(stored, relative_keys);
        if prefix is None {
            continue;
        }
        groups.setdefault(prefix, set[any]()).add(key);
    }
    stale: set[str] = set[any]();
    for keys in groups.values() {
        if len(keys) >= 2 {
            stale.update(keys);
        }
    }
    return stale;
}

impl save_manifest(
    files: dict[str, list[str]],
    manifest_path: str = manifest_path_default__,
    *,
    kind: str = "both",
    `root: Path | None = None,
    scan_corpus: set[str] | list[str] | None = None,
    clear_semantic: set[str] | list[str] | None = None,
    clear_ast: set[str] | list[str] | None = None,
    ast_empty: set[str] | list[str] | None = None,
) {
    scan_set: any;
    clear_set: any;
    clear_ast_set: any;
    ast_empty_set: any;
    root_res: Path | None;
    storage_root: any;
    f: any;
    if `root is not None {
        activate_language_overrides(Path(`root));
    }
    existing: any = load_manifest(manifest_path, root=`root);
    def _path_index(paths: set[str] | list[str] | None) -> set[str] | None {
        if paths is None {
            return None;
        }
        indexed: set[str] = set[any]();
        for p in paths {
            indexed.add(p);
            indexed.add(_nfc(p));
        }
        return indexed;
    }

    scan_set = _path_index(scan_corpus);
    clear_set = _path_index(clear_semantic);
    clear_ast_set = _path_index(clear_ast);
    ast_empty_set = _path_index(ast_empty);
    try {
        root_res = Path(`root).resolve() if `root is not None else None;
    } except (OSError, RuntimeError) {
        root_res = Path(`root) if `root is not None else None;
    }

    def _in_scan(path_str: str) -> bool {
        if path_str in scan_set or _nfc(path_str) in scan_set {
            return True;
        }
        try {
            resolved: any = `str(Path(path_str).resolve());
            return resolved in scan_set or _nfc(resolved) in scan_set;
        } except (OSError, RuntimeError) {
            return False;
        }
    }

    def _in_clear(path_str: str) -> bool {
        if clear_set is None {
            return False;
        }
        if path_str in clear_set or _nfc(path_str) in clear_set {
            return True;
        }
        try {
            resolved: any = `str(Path(path_str).resolve());
            return resolved in clear_set or _nfc(resolved) in clear_set;
        } except (OSError, RuntimeError) {
            return False;
        }
    }

    def _in_clear_ast(path_str: str) -> bool {
        if clear_ast_set is None {
            return False;
        }
        if path_str in clear_ast_set or _nfc(path_str) in clear_ast_set {
            return True;
        }
        try {
            resolved: any = `str(Path(path_str).resolve());
            return resolved in clear_ast_set or _nfc(resolved) in clear_ast_set;
        } except (OSError, RuntimeError) {
            return False;
        }
    }

    def _in_ast_empty(path_str: str) -> bool {
        if ast_empty_set is None {
            return False;
        }
        if path_str in ast_empty_set or _nfc(path_str) in ast_empty_set {
            return True;
        }
        try {
            resolved: any = `str(Path(path_str).resolve());
            return resolved in ast_empty_set or _nfc(resolved) in ast_empty_set;
        } except (OSError, RuntimeError) {
            return False;
        }
    }

    def _in_root(path_str: str) -> bool {
        if root_res is None {
            return False;
        }
        p: any = Path(path_str);
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

    def _normalise_entry(`entry) -> any {
        if isinstance(`entry, (`int, `float)) {
            return {"mtime": `entry, "ast_hash": "", "semantic_hash": ""};
        }
        if isinstance(`entry, `dict) and "hash" in `entry and "ast_hash" not in `entry {
            return {
                "mtime": `entry.get("mtime", 0),
                "ast_hash": `entry["hash"],
                "semantic_hash": "",
            };
        }
        if isinstance(`entry, `dict) {
            return `entry;
        }
        return None;
    }
    all_files: any = [f for file_list in files.values() for f in file_list];
    storage_root = _manifest_storage_anchor(manifest_path, `root) if `root is not None else None;
    stale_checkout: set[str] = set[any]();
    if scan_set is not None and storage_root is not None {
        new_rels: set[str] = set[any]();
        for f in all_files {
            stored: any = _nfc(_to_relative_for_storage(_nfc(f), storage_root));
            if not _looks_absolute(stored) {
                new_rels.add(stored);
            }
        }
        stale_checkout = _previous_checkout_absolute_keys(existing.keys(), storage_root, new_rels);
    }
    manifest: dict[str, dict] = {};
    `entry: dict;
    for (f, `entry) in existing.items() {
        normalised: any = _normalise_entry(`entry);
        if normalised is None {
            continue;
        }
        try {
            if not Path(f).exists() {
                continue;
            }
        } except OSError {
            continue;
        }
        if f in stale_checkout {
            continue;
        }
        if scan_set is not None and not _in_scan(f) and _in_root(f) {
            continue;
        }
        if clear_ast_set is not None and _in_clear_ast(f) {
            normalised = {k: v for (k, v) in normalised.items() if k != "ast_empty"};
            normalised = {**normalised, "ast_hash": "", "semantic_hash": ""};
        } elif clear_set is not None and _in_clear(f) {
            normalised = {**normalised, "semantic_hash": ""};
        }
        manifest[f] = normalised;
    }

    pool: any;
    with ThreadPoolExecutor() as pool {
        raw: any = pool.map(_stat_and_hash, all_files);
    }
    hashed: dict[str, tuple[float, str]] = {r[0]: (r[1], r[2]) for r in raw if r is not None};

    for f in all_files {
        if f not in hashed {
            continue;
        }
        mtime: any;
        h: any;
        (mtime, h) = hashed[f] as any;
        key: any = _nfc(f);
        prev: any = _normalise_entry(existing.get(key, {})) or {};
        current_lang: any = cache_salt(f);
        lang_changed: any = operator.ne(current_lang, prev.get("language"));
        if kind in ("ast", "both") {
            ast_h: any = h;
        } elif lang_changed {
            ast_h = "";
        } else {
            ast_h = prev.get("ast_hash", "");
        }
        if kind in ("semantic", "both") {
            sem_h: any = h;
        } elif lang_changed {
            sem_h = "";
        } else {
            sem_h = prev.get("semantic_hash", "") if h == prev.get("ast_hash", "") else "";
        }
        prev_seen: any = prev.get("seen");
        is_unchanged: any = isinstance(prev_seen, (`int, `float))
            and operator.eq(mtime, prev.get("mtime"))
            and (operator.eq(ast_h, prev.get("ast_hash", "")) if kind in ("ast", "both") else True)
            and (
                operator.eq(sem_h, prev.get("semantic_hash", ""))
                    if kind in ("semantic", "both")
                    else True
            )
            and not lang_changed
            and not _in_clear_ast(f)
            and not _in_clear(f);
        `entry = {
            "mtime": mtime,
            "seen": prev_seen if is_unchanged else time.time(),
            "ast_hash": ast_h,
            "semantic_hash": sem_h,
        };
        if current_lang is not None {
            `entry["language"] = current_lang;
        }
        if _in_ast_empty(f) {
            `entry["ast_empty"] = True;
        } elif not lang_changed and prev.get("ast_empty") and ast_h == prev.get("ast_hash", "") {
            `entry["ast_empty"] = True;
        }
        manifest[key] = `entry;
    }
    if storage_root is not None {
        manifest = _collapse_manifest_duplicates(
            manifest.items(), lambda (k) -> any { _nfc(_to_relative_for_storage(k, storage_root)) }
        );
    } else {
        manifest = _collapse_manifest_duplicates(manifest.items(), _nfc);
    }
    manifest_p: any = Path(manifest_path);
    if manifest_p.is_file() {
        try {
            disk_raw: any = json.loads(manifest_p.read_text(encoding="utf-8"));
            if isinstance(disk_raw, `dict) and disk_raw == manifest {
                return;
            }
        } except Exception {}
    }

    write_json_atomic: any = importlib.import_module("graphify.paths").write_json_atomic;
    write_json_atomic(manifest_path, manifest, indent=2);
}

impl _mtime_may_hide_a_rewrite(current_mtime: float, stored: dict) -> bool {
    seen: any = stored.get("seen");
    if not isinstance(seen, (`int, `float)) {
        return False;
    }
    delta: any = `float(seen) - `float(current_mtime);
    coarse: any = `float(current_mtime).is_integer();
    window: any = _MTIME_COARSE_S if coarse else _MTIME_SUBSECOND_S;
    if delta < 0 {
        return operator.lt(-delta, window);
    }
    return operator.lt(delta, window);
}

impl classify_manifest_files(
    file_buckets: dict[str, list[str]],
    manifest: dict,
    *,
    kind: str = "ast",
    unstamped_is_changed: bool = True,
) -> tuple[dict[str, list[str]], dict[str, list[str]]] {
    new_files: dict[str, list[str]] = {k: [] for k in file_buckets};
    unchanged_files: dict[str, list[str]] = {k: [] for k in file_buckets};

    for (ftype, file_list) in file_buckets.items() {
        for f in file_list {
            stored: any = manifest.get(_nfc(f));
            try {
                current_mtime: any = os.stat(_os_path(Path(f))).st_mtime;
            } except Exception {
                current_mtime = 0;
            }
            stored_lang: any = stored.get("language") if isinstance(stored, `dict) else None;
            if stored is None {
                changed: any = unstamped_is_changed;
            } elif cache_salt(f) != stored_lang {
                changed = True;
            } elif isinstance(stored, (`int, `float)) {
                changed = operator.ne(current_mtime, stored);
            } elif isinstance(stored, `dict) {
                if "hash" in stored and "ast_hash" not in stored {
                    stored = {
                        "mtime": stored.get("mtime", 0),
                        "ast_hash": stored["hash"],
                        "semantic_hash": "",
                    };
                }
                hash_key: any = "semantic_hash" if kind == "semantic" else "ast_hash";
                stored_hash: any = stored.get(hash_key, "");
                if not stored_hash {
                    changed = unstamped_is_changed;
                } else {
                    stored_mtime: any = stored.get("mtime");
                    if isinstance(stored_mtime, `dict) {
                        stored_mtime = stored_mtime.get("mtime");
                    }
                    if not isinstance(stored_mtime, (`int, `float)) {
                        stored_mtime = None;
                    }
                    if stored_mtime is None or current_mtime != stored_mtime {
                        changed = operator.ne(_md5_file(Path(f)), stored_hash);
                    } elif _mtime_may_hide_a_rewrite(current_mtime, stored) {
                        changed = operator.ne(_md5_file(Path(f)), stored_hash);
                    } else {
                        changed = False;
                    }
                }
            } else {
                changed = True;
            }

            if changed {
                new_files[ftype].append(f);
            } else {
                unchanged_files[ftype].append(f);
            }
        }
    }

    return (new_files, unchanged_files);
}

impl classify_manifest_deletions(
    manifest: dict, scanned: Iterable[str], *, `root: Path | None = None
) -> tuple[list[str], list[str]] {
    root_res: Path | None;
    f: any;
    try {
        root_res = Path(`root).resolve() if `root is not None else None;
    } except (OSError, RuntimeError) {
        root_res = Path(`root) if `root is not None else None;
    }

    def _in_root(path_str: str) -> bool {
        if root_res is None {
            return True;
        }
        p: any = Path(path_str);
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

    current_files: any = {_nfc(f) for f in scanned};
    deleted_files: list[str] = [];
    excluded_files: list[str] = [];
    for f in manifest {
        if not _in_root(f) {
            continue;
        }
        if _nfc(f) in current_files {
            continue;
        }
        try {
            alive: any = Path(f).exists();
        } except OSError {
            alive = False;
        }
        (excluded_files if alive else deleted_files).append(f);
    }

    return (deleted_files, excluded_files);
}

impl detect_incremental(
    `root: Path,
    manifest_path: str = manifest_path_default___,
    *,
    follow_symlinks: bool | None = None,
    google_workspace: bool | None = None,
    kind: str = "semantic",
    extra_excludes: list[str] | None = None,
    gitignore: bool = True,
    cache_root: Path | None = None,
) -> dict {
    full: any = detect(
        `root,
        follow_symlinks=follow_symlinks,
        google_workspace=google_workspace,
        extra_excludes=extra_excludes,
        gitignore=gitignore,
        cache_root=cache_root,
    );
    manifest: any = load_manifest(manifest_path, root=`root);

    if not manifest {
        full["incremental"] = True;
        full["new_files"] = full["files"];
        full["unchanged_files"] = {k: [] for k in full["files"]};
        full["new_total"] = full["total_files"];
        full["deleted_files"] = [];
        full["excluded_files"] = [];
        return full;
    }

    new_files: any;
    unchanged_files: any;
    (new_files, unchanged_files) = classify_manifest_files(
        full["files"], manifest, kind=kind
    ) as any;
    deleted_files: any;
    excluded_files: any;
    (deleted_files, excluded_files) = classify_manifest_deletions(
        manifest,
        [f for flist in full["files"].values() for f in flist]
            + `list(full.get("resolution_inputs", [])),
        root=`root,
    ) as any;

    new_total: any = sum(len(v) for v in new_files.values());
    full["incremental"] = True;
    full["new_files"] = new_files;
    full["unchanged_files"] = unchanged_files;
    full["new_total"] = new_total;
    full["deleted_files"] = deleted_files;
    full["excluded_files"] = excluded_files;
    return full;
}
