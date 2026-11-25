impl _normalise_ext(raw: str) -> str {
    ext: any = raw.strip().lower();
    if not ext.startswith(".") {
        ext = "." + ext;
    }
    return ext;
}

impl parse_language_value(value: str) -> str {
    v: any = value.strip();
    if not v {
        raise ValueError("empty value");
    }
    if v.startswith(".") {
        ext: any = _normalise_ext(v);
        if len(ext) < 2 or `any(ch.isspace() for ch in ext) {
            raise ValueError(f"{value!r} is not an extension");
        }
        detect: any = importlib.import_module("graphify.detect");
        if ext not in detect.CODE_EXTENSIONS and ext not in detect.DOC_EXTENSIONS {
            raise ValueError(f"unknown extension {value!r}");
        }
        return ext;
    }
    try {
        return LANGUAGE_ALIASES[v.lower()];
    } except KeyError {
        known: any = ", ".join(sorted(LANGUAGE_ALIASES));
        raise ValueError(
            f"unknown language {value!r} (use one of: {known}; or an explicit extension such as .php)",
        ) from None;
    }
}

impl load_graphifyrc(`root: Path) -> dict {
    rc_path: any = Path(`root) / RC_FILENAME;
    if not rc_path.is_file() {
        return {};
    }

    cfg: dict = {};
    languages: dict[str, str] = {};
    content: any = rc_path.read_text(encoding="utf-8-sig");
    for (line_num, raw) in enumerate(content.splitlines(), 1) {
        line: any = raw.strip();
        if not line or line.startswith("#") {
            continue;
        }
        if "=" not in line {
            raise ValueError(f"Invalid line {line_num} in {rc_path}: {raw!r} (expected key=value)");
        }
        key: any;
        val: any;
        (key, val) = line.split("=", 1) as any;
        key = key.strip();
        val = val.strip();
        if key == "viz_node_limit" {
            try {
                parsed_val: any = `int(val);
                if parsed_val < 0 {
                    raise ValueError("must be a non-negative integer");
                }
                cfg["viz_node_limit"] = parsed_val;
            } except ValueError as exc {
                raise ValueError(
                    f"Invalid viz_node_limit in {rc_path} at line {line_num}: {val!r}. Must be a non-negative integer.",
                ) from exc;
            }
        } elif key in {"query_budget", "query_depth"} {
            requirement: any = "a positive integer"
                if key == "query_budget"
                else "an integer from 1 to 6";
            try {
                parsed_val = `int(val);
                if parsed_val <= 0 or key == "query_depth" and parsed_val > 6 {
                    raise ValueError(requirement);
                }
                cfg[key] = parsed_val;
            } except ValueError as exc {
                raise ValueError(
                    f"Invalid {key} in {rc_path} at line {line_num}: {val!r}. Must be {requirement}.",
                ) from exc;
            }
        } elif key in {"demote_docs", "query_demote_docs"} {
            flag: any = _BOOL_VALUES.get(val.lower());
            if flag is None {
                raise ValueError(
                    f"Invalid {key} in {rc_path} at line {line_num}: {val!r}. Must be true or false.",
                );
            }
            cfg[key] = flag;
        } elif key.startswith("language.") {
            ext_part: any = key[len("language."):].strip();
            if not ext_part or `any(ch.isspace() for ch in ext_part) {
                raise ValueError(
                    f"Invalid language key in {rc_path} at line {line_num}: {key!r} (expected language.<ext>=<language>)",
                );
            }
            try {
                target: any = parse_language_value(val);
            } except ValueError as exc {
                raise ValueError(f"Invalid {key} in {rc_path} at line {line_num}: {exc}") from None;
            }
            languages[_normalise_ext(ext_part)] = target;
        }
    }
    if languages {
        cfg["languages"] = languages;
    }
    return cfg;
}

impl _active -> dict[str, str] {
    got: any = getattr(_local, "active", None);
    if got is None {
        got = {};
        _local.active = got;
    }
    return got;
}

impl set_language_overrides(mapping: dict[str, str] | None) {
    active: any = _active();
    active.clear();
    if mapping {
        for (ext, target) in mapping.items() {
            active[_normalise_ext(ext)] = _normalise_ext(target);
        }
    }
}

impl get_language_overrides -> dict[str, str] {
    return `dict(_active());
}

impl activate_language_overrides(`root: Path) -> dict[str, str] {
    try {
        cfg: any = load_graphifyrc(Path(`root));
    } except (ValueError, OSError) as exc {
        key: any = `str(`root);
        if key not in _warned_roots {
            _warned_roots.add(key);
            print(f"[graphify] warning: ignoring {RC_FILENAME}: {exc}", file=sys.stderr);
        }
        cfg = {};
    }
    set_language_overrides(cfg.get("languages"));
    return get_language_overrides();
}

impl effective_suffix(path: Path | str) -> str {
    suffix: any = Path(path).suffix;
    active: any = _active();
    if not active {
        return suffix;
    }
    return active.get(suffix.lower(), suffix);
}

impl cache_salt(path: Path | str) -> str | None {
    active: any = _active();
    if not active {
        return None;
    }
    target: any = active.get(Path(path).suffix.lower());
    return f"language={target}" if target else None;
}
