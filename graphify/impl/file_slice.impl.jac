impl _pdf_text(path: Path) -> str {
    import from graphify.detect { extract_pdf_text }
    return extract_pdf_text(path);
}

impl unit_source_text(path: Path) -> str {
    if path.suffix.lower() not in _CONVERTED_TEXT_SUFFIXES {
        return _read_source_text(path, warn=False);
    }
    try {
        st: any = path.stat();
        key: any = (`str(path.resolve()), st.st_size, st.st_mtime_ns);
    } except OSError {
        return _pdf_text(path);
    }
    hit: any = _CONVERTED_TEXT_CACHE.get(key);
    if hit is not None {
        return hit;
    }
    text: any = _pdf_text(path);
    if len(_CONVERTED_TEXT_CACHE) >= _CONVERTED_TEXT_CACHE_MAX {
        _CONVERTED_TEXT_CACHE.clear();
    }
    _CONVERTED_TEXT_CACHE[key] = text;
    return text;
}

impl unit_path(unit: "Path | FileSlice | str") -> Path {
    if isinstance(unit, FileSlice) {
        return unit.path;
    }
    if isinstance(unit, Path) {
        return unit;
    }
    return Path(unit);
}

impl is_splittable_text(path: "Path | FileSlice | str") -> bool {
    suffix: any = unit_path(path).suffix.lower();
    return suffix in _SPLITTABLE_TEXT_SUFFIXES or suffix in _CONVERTED_TEXT_SUFFIXES;
}

impl _best_cut(text: str, start: int, end: int) -> int {
    window: any = text[start:end];
    for sep in _BOUNDARY_SEPARATORS {
        idx: any = window.rfind(sep);
        if idx > 0 {
            if sep == "\n#" {
                return start + idx + 1;
            }
            return start + idx + len(sep);
        }
    }
    return end;
}

impl slice_boundaries(text: str, max_chars: int) -> list[tuple[int, int]] {
    n: any = len(text);
    if n <= max_chars {
        return [(0, n)];
    }
    bounds: list[tuple[int, int]] = [];
    pos: any = 0;
    while pos < n {
        hard: any = min(pos + max_chars, n);
        end: any = _best_cut(text, pos, hard) if hard < n else n;
        if end <= pos {
            end = hard;
        }
        bounds.append((pos, end));
        pos = end;
    }
    return bounds;
}

impl expand_oversized_files(
    files: "list[Path | FileSlice]", max_chars: int
) -> list["Path | FileSlice"] {
    raw_out: list["Path | FileSlice"] = [];
    resplit_parents: set[Path] = set[any]();

    for f in files {
        if isinstance(f, FileSlice) {
            if not is_splittable_text(f.path) {
                raw_out.append(f);
                continue;
            }
            slice_len: any = f.end - f.start;
            if slice_len <= max_chars {
                raw_out.append(f);
                continue;
            }
            try {
                full_text: any = unit_source_text(f.path);
                slice_text: any = full_text[f.start:f.end];
            } except OSError {
                raw_out.append(f);
                continue;
            }
            ranges: any = slice_boundaries(slice_text, max_chars);
            total: any = len(ranges);
            resplit_parents.add(f.path);
            i: any;
            s: any;
            e: any;
            for (i, (s, e)) in enumerate(ranges) {
                raw_out.append(
                    FileSlice(path=f.path, start=f.start + s, end=f.start + e, index=i, total=total)
                );
            }
            continue;
        }

        if not is_splittable_text(f) {
            raw_out.append(f);
            continue;
        }
        try {
            text: any = unit_source_text(f);
        } except OSError {
            raw_out.append(f);
            continue;
        }
        if len(text) <= max_chars {
            raw_out.append(f);
            continue;
        }
        ranges = slice_boundaries(text, max_chars);
        total = len(ranges);
        resplit_parents.add(f);
        for (i, (s, e)) in enumerate(ranges) {
            raw_out.append(FileSlice(path=f, start=s, end=e, index=i, total=total));
        }
    }

    if not resplit_parents {
        return raw_out;
    }
    parent_slice_counts: dict[Path, int] = {};
    u: any;
    for u in raw_out {
        if isinstance(u, FileSlice) and u.path in resplit_parents {
            parent_slice_counts[u.path] = parent_slice_counts.get(u.path, 0) + 1;
        }
    }

    parent_slice_indices: dict[Path, int] = {};
    out: list["Path | FileSlice"] = [];
    for u in raw_out {
        if isinstance(u, FileSlice) and u.path in resplit_parents {
            total = parent_slice_counts[u.path];
            idx: any = parent_slice_indices.get(u.path, 0);
            parent_slice_indices[u.path] = idx + 1;
            if u.index != idx or u.total != total {
                out.append(
                    FileSlice(path=u.path, start=u.start, end=u.end, index=idx, total=total)
                );
            } else {
                out.append(u);
            }
        } else {
            out.append(u);
        }
    }
    return out;
}

impl read_slice_text(fs: FileSlice) -> str {
    return unit_source_text(fs.path)[fs.start:fs.end];
}

impl bisect_slice(fs: FileSlice) -> tuple[FileSlice, FileSlice] | None {
    if fs.end - fs.start <= 1 {
        return None;
    }
    try {
        text: any = unit_source_text(fs.path);
    } except Exception {
        return None;
    }
    mid: any = (fs.start + fs.end) // 2;
    nl: any = text.find("\n", mid, fs.end);
    cut: any = nl + 1 if nl != -1 and fs.start < nl + 1 < fs.end else mid;
    if not fs.start < cut < fs.end {
        return None;
    }
    left: any = FileSlice(fs.path, fs.start, cut, fs.index, fs.total);
    right: any = FileSlice(fs.path, cut, fs.end, fs.index, fs.total);
    return (left, right);
}

impl make_full_slice(path: "Path | FileSlice") -> FileSlice | None {
    if isinstance(path, FileSlice) {
        return path;
    }
    p: any = unit_path(path);
    if not is_splittable_text(p) {
        return None;
    }
    try {
        text: any = unit_source_text(p);
    } except Exception {
        return None;
    }
    return FileSlice(path=p, start=0, end=len(text), index=0, total=1);
}

impl is_complete_slice_coverage(parent: "Path | str", slices: "Sequence[FileSlice]") -> bool {
    s: any;
    if not slices {
        return False;
    }
    parent_path: any = unit_path(parent);
    try {
        total_len: any = len(unit_source_text(parent_path));
    } except Exception {
        return False;
    }

    def _same_path(p1: Path, p2: Path) -> bool {
        if p1 == p2 {
            return True;
        }
        try {
            return operator.eq(
                os.path.normcase(`str(p1.resolve())), os.path.normcase(`str(p2.resolve()))
            );
        } except (OSError, RuntimeError) {
            return False;
        }
    }

    valid_slices: any = [
        s
        for s in slices
        if isinstance(s, FileSlice)
            and _same_path(unit_path(s), parent_path)
            and 0 <= s.start <= s.end
    ];
    if not valid_slices {
        return False;
    }

    sorted_slices: any = sorted(valid_slices, key=lambda (s) -> any { (s.start, s.end) });
    if sorted_slices[0].start > 0 {
        return False;
    }

    current_end: any = 0;
    for s in sorted_slices {
        if s.start > current_end {
            return False;
        }
        current_end = max(current_end, s.end);
    }

    return operator.ge(current_end, total_len);
}
