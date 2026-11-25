impl google_workspace_enabled(value: str | None = None) -> bool {
    raw: any = value if value is not None else os.environ.get("GRAPHIFY_GOOGLE_WORKSPACE", "");
    return raw.strip().lower() in {"1", "true", "yes", "on"};
}

impl _safe_yaml_str(value: str) -> str {
    if value is None {
        return "";
    }
    out: list[str] = [];
    for ch in `str(value) {
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
        } elif cp == 133 {
            out.append("\\x85");
        } elif cp < 32 or cp == 127 {
            out.append(f"\\x{cp:02x}");
        } else {
            out.append(ch);
        }
    }
    return "".join(out);
}

impl _extract_file_id_from_url(url: str) -> str | None {
    if not url {
        return None;
    }
    parsed: any = urllib.parse.urlparse(url);
    query: any = urllib.parse.parse_qs(parsed.query);
    if query.get("id") {
        return query["id"][0];
    }
    `match: any = re.search(
        "/(?:document|spreadsheets|presentation|file)/d/([^/?#]+)", parsed.path
    );
    if `match {
        return `match.group(1);
    }
    return None;
}

impl _extract_resource_key(url: str, data: dict[str, Any]) -> str | None {
    for key in ("resource_key", "resourceKey") {
        value: any = data.get(key);
        if value {
            return `str(value);
        }
    }
    if not url {
        return None;
    }
    parsed: any = urllib.parse.urlparse(url);
    query: any = urllib.parse.parse_qs(parsed.query);
    if query.get("resourcekey") {
        return query["resourcekey"][0];
    }
    return None;
}

impl read_google_shortcut(path: Path) -> dict[str, str | None] {
    try {
        data: any = json.loads(path.read_text(encoding="utf-8"));
    } except Exception as exc {
        raise RuntimeError(f"could not read Google Workspace shortcut {path}: {exc}") from exc;
    }

    url: any = `str(data.get("url") or "");
    file_id: any = data.get("doc_id")
        or data.get("file_id")
        or data.get("fileId")
        or data.get("id")
        or _extract_file_id_from_url(url);
    if not file_id {
        resource_id: any = `str(data.get("resource_id") or "");
        if ":" in resource_id {
            file_id = resource_id.split(":", 1)[1];
        }
    }

    if not file_id {
        raise RuntimeError(f"Google Workspace shortcut {path} does not include a Drive file ID");
    }

    return {
        "file_id": `str(file_id),
        "url": url or None,
        "resource_key": _extract_resource_key(url, data),
        "account": `str(data.get("email")) if data.get("email") else None,
    };
}

impl _run_gws_export(file_id: str, mime_type: str, output: Path, resource_key: str | None = None) {
    exe: any = shutil.which("gws");
    if not exe {
        raise RuntimeError(
            "gws is required for Google Workspace export. Install it from https://github.com/googleworkspace/cli and run `gws auth login -s drive`.",
        );
    }

    params: dict[str, str] = {"fileId": file_id, "mimeType": mime_type};
    _: any = resource_key;
    output = output.resolve();
    output.parent.mkdir(parents=True, exist_ok=True);
    timeout: any = `int(os.environ.get("GRAPHIFY_GOOGLE_WORKSPACE_TIMEOUT", "120"));
    result: any = subprocess.run(
        [exe, "drive", "files", "export", "--params", json.dumps(params), "-o", output.name],
        capture_output=True,
        cwd=output.parent,
        text=True,
        timeout=timeout,
    );
    if result.returncode != 0 {
        stderr: any = (result.stderr or result.stdout or "").strip();
        if len(stderr) > 1200 {
            stderr = stderr[:1200] + "...";
        }
        raise RuntimeError(f"gws export failed for {file_id}: {stderr}");
    }
}

impl _sidecar_path(path: Path, out_dir: Path, `root: "Path | None" = None) -> Path {
    import unicodedata;
    if `root is None {
        `root = out_dir.parent.parent;
    }
    try {
        key: any = path.resolve().relative_to(Path(`root).resolve()).as_posix();
    } except (ValueError, OSError) {
        key = `str(path.resolve());
    }
    name_hash: any = hashlib.sha256(unicodedata.normalize("NFC", key).encode()).hexdigest()[:8];
    return out_dir / f"{path.stem}_{name_hash}.md";
}

impl _with_frontmatter(
    path: Path, shortcut: dict[str, str | None], body: str, exported_mime_type: str
) -> str {
    source_url: any = shortcut.get("url") or "";
    account: any = shortcut.get("account") or "";
    account_line: any = "";
    if account {
        account_hash: any = hashlib.sha256(account.encode()).hexdigest()[:12];
        account_line = f"google_account_hash: \"{account_hash}\"\n";
    }
    return "---\nsource_file: \""
        + format(_safe_yaml_str(`str(path)), "")
        + "\"\nsource_type: \"google_workspace\"\ngoogle_file_id: \""
        + format(_safe_yaml_str(shortcut["file_id"] or ""), "")
        + "\"\ngoogle_export_mime_type: \""
        + format(_safe_yaml_str(exported_mime_type), "")
        + "\"\nsource_url: \""
        + format(_safe_yaml_str(source_url), "")
        + "\"\n"
        + format(account_line, "")
        + "---\n\n<!-- converted from Google Workspace shortcut: "
        + format(path.name, "")
        + " -->\n\n"
        + format(body.strip(), "")
        + "\n";
}

impl convert_google_workspace_file(
    path: Path,
    out_dir: Path,
    *,
    xlsx_to_markdown: Callable[[Path], str] | None = None,
    `root: "Path | None" = None,
) -> Path | None {
    ext: any = path.suffix.lower();
    if ext not in GOOGLE_WORKSPACE_EXTENSIONS {
        return None;
    }

    shortcut: any = read_google_shortcut(path);
    out_dir.mkdir(parents=True, exist_ok=True);
    out_path: any = _sidecar_path(path, out_dir, root=`root);

    if ext == ".gdoc" {
        tmp: any;
        with tempfile.NamedTemporaryFile("w+b", suffix=".md", delete=False, dir=out_dir) as tmp {
            tmp_path: any = Path(tmp.name);
        }
        try {
            _run_gws_export(
                shortcut["file_id"] or "", "text/markdown", tmp_path, shortcut.get("resource_key")
            );
            body: any = tmp_path.read_text(encoding="utf-8", errors="replace");
        } finally {
            tmp_path.unlink(missing_ok=True);
        }
        if not body.strip() {
            return None;
        }
        out_path.write_text(
            _with_frontmatter(path, shortcut, body, "text/markdown"), encoding="utf-8"
        );
        return out_path;
    }

    if ext == ".gslides" {
        with tempfile.NamedTemporaryFile("w+b", suffix=".txt", delete=False, dir=out_dir) as tmp {
            tmp_path = Path(tmp.name);
        }
        try {
            _run_gws_export(
                shortcut["file_id"] or "", "text/plain", tmp_path, shortcut.get("resource_key")
            );
            body = tmp_path.read_text(encoding="utf-8", errors="replace");
        } finally {
            tmp_path.unlink(missing_ok=True);
        }
        if not body.strip() {
            return None;
        }
        out_path.write_text(
            _with_frontmatter(path, shortcut, body, "text/plain"), encoding="utf-8"
        );
        return out_path;
    }

    if ext == ".gsheet" {
        if xlsx_to_markdown is None {
            raise RuntimeError(
                "Google Sheets export requires the office extra: pip install graphifyy[office,google]",
            );
        }
        with tempfile.NamedTemporaryFile("w+b", suffix=".xlsx", delete=False, dir=out_dir) as tmp {
            tmp_path = Path(tmp.name);
        }
        try {
            _run_gws_export(
                shortcut["file_id"] or "",
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                tmp_path,
                shortcut.get("resource_key"),
            );
            body = xlsx_to_markdown(tmp_path);
        } finally {
            tmp_path.unlink(missing_ok=True);
        }
        if not body.strip() {
            return None;
        }
        out_path.write_text(
            _with_frontmatter(
                path,
                shortcut,
                body,
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            ),
            encoding="utf-8",
        );
        return out_path;
    }

    return None;
}
