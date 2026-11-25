impl set_active_scan_root(`root: "Path | None") -> "Path | None" {
    previous: any = _ACTIVE_SCAN_ROOT.get();
    _ACTIVE_SCAN_ROOT.set(`root);
    return previous;
}

impl active_scan_root -> "Path | None" {
    return _ACTIVE_SCAN_ROOT.get();
}

impl _make_id(*parts_: str) -> str {
    parts: any = tuple(parts_);
    return make_id(*parts);
}

impl _read_text(`node, source: bytes) -> str {
    return source[`node.start_byte:`node.end_byte].decode("utf-8", errors="replace");
}

impl _read_source_bytes(path: Path, *, warn: bool = True) -> bytes {
    raw: any = _take_preread_bytes(path);
    if raw is None {
        raw = path.read_bytes();
    }
    if raw.isascii() {
        return raw;
    }
    try {
        raw.decode("utf-8");
        return raw;
    } except UnicodeDecodeError {}
    encoding: any;
    for (boms, encoding) in ((_UTF32_BOMS, "utf-32"), (_UTF16_BOMS, "utf-16")) {
        if raw.startswith(boms) {
            try {
                return raw.decode(encoding).encode("utf-8");
            } except UnicodeDecodeError {
                continue;
            }
        }
    }
    for encoding in _SOURCE_FALLBACK_ENCODINGS {
        try {
            text: any = raw.decode(encoding);
        } except UnicodeDecodeError {
            continue;
        }
        key: any = `str(path);
        if warn and key not in _warned_source_encodings {
            _warned_source_encodings.add(key);
            print(
                f"[graphify] WARNING: {path} is not valid UTF-8; read it as {encoding}. Re-save it as UTF-8 if names in the graph look wrong.",
                file=sys.stderr,
            );
        }
        return text.encode("utf-8");
    }
    return raw;
}

impl _read_source_text(path: Path, *, warn: bool = True) -> str {
    text: any = _read_source_bytes(path, warn=warn).decode("utf-8");
    return text.replace("\r\n", "\n").replace("\r", "\n");
}
