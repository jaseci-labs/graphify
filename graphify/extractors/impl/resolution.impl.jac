impl _declared_language_suffixes(target_exts: tuple[str, ...]) -> tuple[str, ...] {
    suffixes: any = [
        source_ext
        for (source_ext, target_ext) in get_language_overrides().items()
        if target_ext in target_exts and Path(f"x{source_ext}").suffix == source_ext
    ];
    return `tuple(sorted(suffixes));
}

impl _resolve_js_import_path(candidate: Path) -> Path {
    candidate = Path(os.path.normpath(candidate));
    try {
        if candidate.is_file() {
            return candidate;
        }
    } except OSError {
        return candidate;
    }
    if candidate.suffix == ".js" {
        for ts_candidate in (candidate.with_suffix(".ts"), candidate.with_suffix(".tsx")) {
            if ts_candidate.is_file()
                and effective_suffix(ts_candidate) in _JS_CACHE_BYPASS_SUFFIXES
            {
                return ts_candidate;
            }
        }
    } elif candidate.suffix == ".jsx" {
        tsx_candidate: any = candidate.with_suffix(".tsx");
        if tsx_candidate.is_file()
            and effective_suffix(tsx_candidate) in _JS_CACHE_BYPASS_SUFFIXES
        {
            return tsx_candidate;
        }
    }

    declared_exts: any = _declared_language_suffixes(_JS_RESOLVE_EXTS);
    ext: any;
    for ext in _JS_RESOLVE_EXTS + declared_exts {
        with_ext: any = candidate.parent / f"{candidate.name}{ext}";
        if with_ext.is_file() and effective_suffix(with_ext) in _JS_CACHE_BYPASS_SUFFIXES {
            return with_ext;
        }
    }
    if candidate.is_dir() {
        for index_name in _JS_INDEX_FILES {
            index_candidate: any = candidate / index_name;
            if index_candidate.is_file()
                and effective_suffix(index_candidate) in _JS_CACHE_BYPASS_SUFFIXES
            {
                return index_candidate;
            }
        }
        for ext in declared_exts {
            index_candidate = candidate / f"index{ext}";
            if index_candidate.is_file() {
                return index_candidate;
            }
        }
    }

    return candidate;
}

impl _strip_jsonc(text: str) -> str {
    pattern: any = re.compile("\"(?:\\\\.|[^\"\\\\])*\"|/\\*.*?\\*/|//[^\\n]*", re.DOTALL);

    def _replace(`match: re.Match) -> str {
        token: any = `match.group(0);
        if token.startswith("\"") {
            return token;
        }
        return "";
    }

    stripped: any = pattern.sub(_replace, text);
    stripped = re.sub(",(\\s*[}\\]])", "\\1", stripped);
    return stripped;
}

impl _read_tsconfig_aliases(tsconfig: Path, base_dir: Path, seen: set) -> dict[str, list[str]] {
    if `str(tsconfig) in seen {
        return {};
    }
    seen.add(`str(tsconfig));
    try {
        raw: any = tsconfig.read_text(encoding="utf-8");
    } except Exception as e {
        print(
            f"  warning: could not read {tsconfig} ({`type(e).__name__}: {e})",
            file=sys.stderr,
            flush=True,
        );
        return {};
    }
    try {
        data: any = json.loads(raw);
    } except json.JSONDecodeError {
        try {
            data = json.loads(_strip_jsonc(raw));
        } except json.JSONDecodeError as e {
            print(
                f"  warning: failed to parse {tsconfig} as JSON/JSONC ({e.msg} at line {e.lineno} col {e.colno})",
                file=sys.stderr,
                flush=True,
            );
            return {};
        }
    } except Exception as e {
        print(
            f"  warning: failed to parse {tsconfig} ({`type(e).__name__}: {e})",
            file=sys.stderr,
            flush=True,
        );
        return {};
    }

    aliases: dict[str, list[str]] = {};
    extends: any = data.get("extends");
    if isinstance(extends, `str) {
        extends_list: any = [extends];
    } elif isinstance(extends, `list) {
        extends_list = [e for e in extends if isinstance(e, `str)];
    } else {
        extends_list = [];
    }
    for ext in extends_list {
        if not ext or ext.startswith("@") {
            continue;
        }
        extended_path: any = _resolve_cached(base_dir / ext);
        if not extended_path.suffix {
            extended_path = extended_path.with_suffix(".json");
        }
        if extended_path.exists() {
            aliases.update(_read_tsconfig_aliases(extended_path, extended_path.parent, seen));
        }
    }
    references: any = data.get("references");
    if isinstance(references, `list) {
        for ref in references {
            if not isinstance(ref, `dict) {
                continue;
            }
            ref_path: any = ref.get("path");
            if not isinstance(ref_path, `str) or not ref_path {
                continue;
            }
            referenced: any = _resolve_cached(base_dir / ref_path);
            if referenced.is_dir() {
                referenced = referenced / "tsconfig.json";
            } elif not referenced.suffix {
                referenced = referenced.with_suffix(".json");
            }
            if referenced.exists() {
                aliases.update(_read_tsconfig_aliases(referenced, referenced.parent, seen));
            }
        }
    }
    compiler_options: any = data.get("compilerOptions", {});
    base_url: any = compiler_options.get("baseUrl") or ".";
    paths_base: any = base_dir / base_url;
    paths: any = compiler_options.get("paths", {});
    for (alias, targets) in paths.items() {
        if not targets {
            continue;
        }
        target_patterns: any = [`str(paths_base / t) for t in targets if isinstance(t, `str) and t];
        if target_patterns {
            aliases[alias] = target_patterns;
        }
    }

    return aliases;
}

impl _read_json_config(path: Path) -> "dict | None" {
    try {
        raw: any = path.read_text(encoding="utf-8", errors="replace");
    } except OSError {
        return None;
    }
    for candidate in (raw, _strip_jsonc(raw)) {
        try {
            data: any = json.loads(candidate);
        } except Exception {
            continue;
        }
        return data if isinstance(data, `dict) else None;
    }
    return None;
}

impl _find_js_config(start_dir: Path) -> "tuple[Path, Path] | None" {
    current: any = _resolve_cached(start_dir);
    for candidate in [current, *current.parents] {
        for name in ("tsconfig.json", "jsconfig.json") {
            config: any = candidate / name;
            if config.exists() {
                return (config, candidate);
            }
        }
    }
    return None;
}

impl _load_tsconfig_aliases(start_dir: Path) -> dict[str, list[str]] {
    found: any = _find_js_config(start_dir);
    if found is None {
        return {};
    }
    config: any;
    candidate: any;
    (config, candidate) = found as any;
    key: any = `str(config);
    if key not in _TSCONFIG_ALIAS_CACHE {
        _TSCONFIG_ALIAS_CACHE[key] = _read_tsconfig_aliases(config, candidate, seen=set[any]());
    }
    return _TSCONFIG_ALIAS_CACHE[key];
}

impl _load_tsconfig_base_url(start_dir: Path) -> "Path | None" {
    found: any = _find_js_config(start_dir);
    if found is None {
        return None;
    }
    config: any;
    candidate: any;
    (config, candidate) = found as any;
    key: any = `str(config);
    if key not in _TSCONFIG_BASEURL_CACHE {
        base_url: any = None;
        data: any = _read_json_config(config);
        if data is not None {
            raw_base: any = data.get("compilerOptions", {}).get("baseUrl");
            if isinstance(raw_base, `str) and raw_base {
                base_url = Path(os.path.normpath(candidate / raw_base));
            }
        }
        _TSCONFIG_BASEURL_CACHE[key] = base_url;
    }
    return _TSCONFIG_BASEURL_CACHE[key];
}

impl _match_tsconfig_alias(raw: str, pattern: str) -> "tuple[tuple[int, int], str, bool] | None" {
    if "*" in pattern {
        if pattern.count("*") != 1 {
            return None;
        }
        prefix: any;
        suffix: any;
        (prefix, suffix) = pattern.split("*", 1) as any;
        if not raw.startswith(prefix) or not raw.endswith(suffix) {
            return None;
        }
        end: any = len(raw) - len(suffix) if suffix else len(raw);
        if end < len(prefix) {
            return None;
        }
        return ((1, -len(prefix)), raw[len(prefix):end], True);
    }

    if raw == pattern {
        return ((0, -len(pattern)), "", False);
    }

    prefix = pattern.rstrip("/");
    if prefix and raw.startswith(prefix + "/") {
        return ((2, -len(prefix)), raw[len(prefix):].lstrip("/"), False);
    }
    return None;
}

impl _resolve_tsconfig_alias(
    raw: str, aliases: dict[str, list[str]], base_url: "Path | None" = None
) -> "Path | None" {
    best: "tuple[tuple[int, int], str, bool, list[str]] | None" = None;
    targets: any;
    for (pattern, targets) in aliases.items() {
        `match: any = _match_tsconfig_alias(raw, pattern);
        if `match is None {
            continue;
        }
        specificity: any;
        captured: any;
        is_wildcard: any;
        (specificity, captured, is_wildcard) = `match as any;
        if best is None or specificity < best[0] {
            best = (specificity, captured, is_wildcard, targets);
        }
    }

    if best is None {
        if base_url is not None {
            candidate: any = Path(os.path.normpath(base_url / raw));
            resolved: any = _resolve_js_import_path(candidate);
            try {
                if resolved.is_file() {
                    return resolved;
                }
            } except OSError {}
        }
        return None;
    }

    _: any;
    (_, captured, is_wildcard, targets) = best as any;
    first: any = None;
    for target in targets {
        if is_wildcard {
            substituted: any = target.replace("*", captured, 1) if captured else target;
            cand: any = Path(os.path.normpath(substituted));
        } else {
            cand = Path(target);
            if captured {
                cand = Path(os.path.normpath(cand / captured));
            }
        }
        resolved = _resolve_js_import_path(cand);
        try {
            if resolved.is_file() {
                return resolved;
            }
        } except OSError {}
        if first is None {
            first = cand;
        }
    }
    return first;
}

impl _find_workspace_root(start_dir: Path) -> Path | None {
    current: any = _resolve_cached(start_dir);
    for candidate in [current, *current.parents] {
        if (candidate / "pnpm-workspace.yaml").exists() {
            return candidate;
        }
        package_json: any = candidate / "package.json";
        if package_json.is_file() {
            try {
                data: any = json.loads(package_json.read_text(encoding="utf-8"));
            } except Exception {
                continue;
            }
            if "workspaces" in data {
                return candidate;
            }
        }
    }
    return None;
}

impl _pnpm_workspace_globs(workspace_file: Path) -> list[str] {
    globs: list[str] = [];
    in_packages: any = False;
    for raw_line in workspace_file.read_text(encoding="utf-8", errors="replace").splitlines() {
        line: any = raw_line.strip();
        if not line or line.startswith("#") {
            continue;
        }
        if line.startswith("packages:") {
            in_packages = True;
            continue;
        }
        if in_packages and line.startswith("-") {
            value: any = line[1:].strip();
            if value[:1] in ("'", "\"") {
                end: any = value.find(value[0], 1);
                if end < 0 {
                    continue;
                }
                value = value[1:end].strip();
            } else {
                value = re.split("(?:^|\\s)#", value, maxsplit=1)[0].strip();
            }
            if value and not value.startswith("!") {
                globs.append(value);
            }
            continue;
        }
        if in_packages and not raw_line.startswith((" ", "\t")) {
            break;
        }
    }
    return globs;
}

impl _workspace_globs(`root: Path) -> list[str] {
    pnpm_workspace: any = `root / "pnpm-workspace.yaml";
    if pnpm_workspace.exists() {
        return _pnpm_workspace_globs(pnpm_workspace);
    }

    package_json: any = `root / "package.json";
    try {
        data: any = json.loads(package_json.read_text(encoding="utf-8"));
    } except Exception {
        return [];
    }

    workspaces: any = data.get("workspaces");
    if isinstance(workspaces, `list) {
        return [item for item in workspaces if isinstance(item, `str) and not item.startswith("!")];
    }
    if isinstance(workspaces, `dict) {
        packages: any = workspaces.get("packages");
        if isinstance(packages, `list) {
            return [
                item
                for item in packages
                if isinstance(item, `str) and not item.startswith("!")
            ];
        }
    }
    return [];
}

impl _load_workspace_packages(start_dir: Path) -> dict[str, Path] {
    `root: any;
    name: any;
    `root = _find_workspace_root(start_dir);
    if `root is None {
        return {};
    }
    manifest_mtimes: any = `tuple(
        (name, (`root / name).stat().st_mtime_ns)
        for name in _WORKSPACE_MANIFEST_NAMES
        if (`root / name).is_file(),
    );
    key: any = `str((`root, manifest_mtimes));
    if key in _WORKSPACE_PACKAGE_CACHE {
        return _WORKSPACE_PACKAGE_CACHE[key];
    }

    packages: dict[str, Path] = {};
    for pattern in _workspace_globs(`root) {
        try {
            package_dirs: list[Path] = [`root]
                if pattern in (".", "./")
                else `list(`root.glob(pattern));
        } except (ValueError, NotImplementedError) as e {
            print(
                f"  warning: skipped workspace glob {pattern!r} ({`type(e).__name__}: {e})",
                file=sys.stderr,
                flush=True,
            );
            continue;
        }
        for package_dir in package_dirs {
            manifest: any = package_dir / "package.json";
            if not manifest.is_file() {
                continue;
            }
            try {
                data: any = json.loads(manifest.read_text(encoding="utf-8"));
            } except Exception {
                continue;
            }
            name = data.get("name");
            if isinstance(name, `str) and name {
                packages[name] = package_dir;
            }
        }
    }
    _WORKSPACE_PACKAGE_CACHE[key] = packages;
    return packages;
}

impl _importer_platform(start_dir: Path) -> str | None {
    for part in reversed(start_dir.parts) {
        segment: any = part.lower();
        for (platform, hints) in _PLATFORM_PATH_HINTS {
            if segment in hints {
                return platform;
            }
        }
    }
    return None;
}

impl _platform_variants(candidate: Path, platform: str | None) -> list[Path] {
    order: any;
    order = [p for p in (platform,) if p in _PLATFORM_SUFFIXES];
    order.extend(p for p in _PLATFORM_SUFFIXES if p not in order);
    return [candidate.parent / f"{candidate.stem}.{p}{candidate.suffix}" for p in order];
}

impl _resolve_export_targets(value: Any, platform: str | None = None) -> list[str] {
    if isinstance(value, `str) {
        return [value];
    }
    if isinstance(value, `dict) {
        targets: list[str] = [];
        for cond in (
            *_PLATFORM_EXPORT_CONDITIONS.get(platform or "", ()),
            *_EXPORT_CONDITION_PRIORITY,
        ) {
            v: any = value.get(cond);
            if isinstance(v, (`str, `dict)) {
                targets.extend(_resolve_export_targets(v, platform));
            }
        }
        return targets;
    }
    return [];
}

impl _resolve_export_target(value: Any) -> str | None {
    targets: any = _resolve_export_targets(value);
    return targets[0] if targets else None;
}

impl _contained_in_package(resolved: Path, package_dir: Path) -> bool {
    try {
        return _resolve_cached(resolved).is_relative_to(_resolve_cached(package_dir));
    } except ValueError {
        return False;
    }
}

impl _exports_candidates(
    package_dir: Path, targets: list[str], platform: str | None
) -> list[Path] {
    candidates: list[Path] = [];
    for target in targets {
        candidate: any = package_dir / target;
        if not _contained_in_package(candidate, package_dir) {
            continue;
        }
        candidates.append(candidate);
        candidates.extend(_platform_variants(candidate, platform));
    }
    return candidates;
}

impl _with_source_twins(
    package_dir: Path, candidates: list[Path], *, root_entry: bool = False
) -> list[Path] {
    extra: list[Path] = [];
    for candidate in candidates {
        try {
            rel: any = candidate.relative_to(package_dir);
        } except ValueError {
            continue;
        }
        if len(rel.parts) < 2 or rel.parts[0] not in _BUILD_OUTPUT_DIRS {
            continue;
        }
        name: any = rel.name;
        for suffix in _BUILD_OUTPUT_SUFFIXES {
            if name.endswith(suffix) {
                name = name[:-len(suffix)];
                break;
            }
        }
        extra.append(package_dir / "src" / Path(*rel.parts[1:-1]) / name);
    }
    if root_entry {
        extra += [package_dir / "src/index", package_dir / "index"];
    }
    return candidates + [path for path in dict.fromkeys(extra) if path not in candidates];
}

impl _package_entry_candidates(
    package_dir: Path, subpath: str, platform: str | None = None
) -> list[Path] {
    manifest: any = package_dir / "package.json";
    manifest_data: dict[str, Any] = {};
    try {
        manifest_data = json.loads(manifest.read_text(encoding="utf-8"));
    } except Exception {}

    if subpath {
        exports: any = manifest_data.get("exports");
        if isinstance(exports, `dict) {
            subpath_key: any = "./" + subpath;
            targets: any = _resolve_export_targets(exports.get(subpath_key), platform);
            if targets {
                candidates: list[Path] = _exports_candidates(package_dir, targets, platform);
                if candidates {
                    return _with_source_twins(package_dir, candidates);
                }
            } else {
                for (pattern, pattern_value) in exports.items() {
                    if "*" in pattern and pattern.count("*") == 1 {
                        prefix: any;
                        suffix: any;
                        (prefix, suffix) = pattern.split("*", 1) as any;
                        if subpath_key.startswith(prefix)
                            and (not suffix or subpath_key.endswith(suffix))
                        {
                            matched: any = subpath_key[len(prefix):len(subpath_key) - len(suffix)];
                            wildcard_targets: any = [
                                resolved.replace("*", matched)
                                for resolved in _resolve_export_targets(pattern_value, platform)
                                if "*" in resolved
                            ];
                            if wildcard_targets {
                                candidates = _exports_candidates(
                                    package_dir, wildcard_targets, platform
                                );
                                if candidates {
                                    return _with_source_twins(package_dir, candidates);
                                }
                            }
                        }
                    }
                }
            }
        }
        return [package_dir / subpath];
    }

    exports = manifest_data.get("exports");
    if isinstance(exports, `str) {
        return _with_source_twins(package_dir, [package_dir / exports], root_entry=True);
    }
    if isinstance(exports, `dict) {
        dot_targets: any = _resolve_export_targets(exports.get("."), platform);
        if dot_targets {
            return _with_source_twins(
                package_dir,
                _exports_candidates(package_dir, dot_targets, platform),
                root_entry=True,
            );
        }
    }

    candidates = [];
    for key in ("svelte", "module", "main", "types") {
        value: any = manifest_data.get(key);
        if isinstance(value, `str) {
            candidates.append(package_dir / value);
        }
    }
    candidates.append(package_dir / "src/index");
    candidates.append(package_dir / "index");
    return candidates;
}

impl _is_build_output_path(path: Path, package_dir: Path) -> bool {
    try {
        rel: any = _resolve_cached(path).relative_to(_resolve_cached(package_dir));
        return `bool(rel.parts and rel.parts[0] in _BUILD_OUTPUT_DIRS);
    } except ValueError {
        return False;
    }
}

impl _resolve_workspace_import(raw: str, start_dir: Path) -> Path | None {
    packages: any = _load_workspace_packages(start_dir);
    platform: any = _importer_platform(start_dir);
    for (package_name, package_dir) in packages.items() {
        if raw == package_name {
            subpath: any = "";
        } elif raw.startswith(package_name + "/") {
            subpath = raw[len(package_name) + 1:];
        } else {
            continue;
        }
        build_fallback: Path | None = None;
        for candidate in _package_entry_candidates(package_dir, subpath, platform) {
            resolved: any = _resolve_js_import_path(candidate);
            if resolved.is_file() {
                if _is_build_output_path(resolved, package_dir) {
                    if build_fallback is None {
                        build_fallback = resolved;
                    }
                } else {
                    return resolved;
                }
            }
        }
        if build_fallback is not None {
            return build_fallback;
        }
    }
    return None;
}

impl _find_js_project_anchor(start_dir: Path) -> Path {
    _find_vcs_root: any = importlib.import_module("graphify.detect")._find_vcs_root;

    current: any = _resolve_cached(start_dir);
    home: any = Path.home();

    for candidate in [current, *current.parents] {
        if candidate == home {
            break;
        }
        if (candidate / "package.json").is_file() or (candidate / "pnpm-workspace.yaml").is_file() {
            return candidate;
        }
    }

    vcs_root: any = _find_vcs_root(start_dir);
    if vcs_root is not None {
        return vcs_root;
    }

    return current;
}

impl _load_package_imports(start_dir: Path) -> "tuple[Path, dict] | None" {
    current: any = _resolve_cached(start_dir);
    key: any = `str(current);
    if key in _PACKAGE_IMPORTS_CACHE {
        return _PACKAGE_IMPORTS_CACHE[key];
    }
    result: "tuple[Path, dict] | None" = None;
    for candidate in [current, *current.parents] {
        manifest: any = candidate / "package.json";
        if manifest.is_file() {
            data: any = _read_json_config(manifest);
            imports: any = data.get("imports") if isinstance(data, `dict) else None;
            if isinstance(imports, `dict) and imports {
                result = (candidate, imports);
            }
            break;
        }
    }
    _PACKAGE_IMPORTS_CACHE[key] = result;
    return result;
}

impl _match_subpath_import(raw: str, pattern: str) -> "tuple[int, str, bool] | None" {
    if "*" in pattern {
        if pattern.count("*") != 1 {
            return None;
        }
        prefix: any;
        suffix: any;
        (prefix, suffix) = pattern.split("*", 1) as any;
        if not raw.startswith(prefix) or not raw.endswith(suffix) {
            return None;
        }
        end: any = len(raw) - len(suffix) if suffix else len(raw);
        if end < len(prefix) {
            return None;
        }
        return (-len(prefix), raw[len(prefix):end], True);
    }
    if raw == pattern {
        return (-(len(pattern) + 1000000), "", False);
    }
    return None;
}

impl _resolve_package_import(raw: str, start_dir: Path) -> "Path | None" {
    if not raw.startswith("#") {
        return None;
    }
    loaded: any = _load_package_imports(start_dir);
    if loaded is None {
        return None;
    }
    package_dir: any;
    imports: any;
    (package_dir, imports) = loaded as any;
    best: "tuple[int, str, bool, object] | None" = None;
    value: any;
    for (pattern, value) in imports.items() {
        if not isinstance(pattern, `str) or not pattern.startswith("#") {
            continue;
        }
        `match: any = _match_subpath_import(raw, pattern);
        if `match is None {
            continue;
        }
        specificity: any;
        captured: any;
        is_wildcard: any;
        (specificity, captured, is_wildcard) = `match as any;
        if best is None or specificity < best[0] {
            best = (specificity, captured, is_wildcard, value);
        }
    }
    if best is None {
        return None;
    }
    _: any;
    (_, captured, is_wildcard, value) = best as any;
    target: any = _resolve_export_target(value);
    if not isinstance(target, `str) or not target.startswith("./") {
        return None;
    }
    if is_wildcard {
        target = target.replace("*", captured, 1) if captured else target;
    }
    candidate: any = Path(os.path.normpath(package_dir / target));
    resolved: any = _resolve_js_import_path(candidate);
    return resolved if resolved.is_file() else None;
}

impl _resolve_js_module_path(raw: str | Path, start_dir: Path | None = None) -> Path | None {
    if isinstance(raw, Path) {
        return _resolve_js_import_path(raw);
    }
    if start_dir is None {
        return _resolve_js_import_path(Path(raw));
    }
    if raw.startswith(".") {
        specifier: any = raw.split("#", 1)[0].split("?", 1)[0];
        return _resolve_js_import_path(start_dir / specifier);
    }

    aliases: any = _load_tsconfig_aliases(start_dir);
    hit: any = _resolve_tsconfig_alias(raw, aliases, base_url=_load_tsconfig_base_url(start_dir));
    if hit is not None {
        return _resolve_js_import_path(hit);
    }
    if raw.startswith("#") {
        hit = _resolve_package_import(raw, start_dir);
        if hit is not None {
            return hit;
        }
    }

    workspace_hit: any = _resolve_workspace_import(raw, start_dir);
    if workspace_hit is not None {
        return workspace_hit;
    }
    if raw.startswith("@/") and _find_js_config(start_dir) is None {
        subpath: any = raw[2:];
        if subpath {
            anchor: any = _find_js_project_anchor(start_dir);
            if (anchor / "src").is_dir() {
                cand: any = _resolve_js_import_path(anchor / "src" / subpath);
                if cand.is_file() {
                    return cand;
                }
            }
            cand = _resolve_js_import_path(anchor / subpath);
            if cand.is_file() {
                return cand;
            }
        }
    }

    return None;
}

impl _resolve_js_import_target(raw: str, str_path: str) -> "tuple[str, Path | None] | None" {
    if not raw {
        return None;
    }
    resolved_path: any = _resolve_js_module_path(raw, Path(str_path).parent);
    if resolved_path is not None {
        return (_make_id(`str(resolved_path)), resolved_path);
    }
    module_name: any = raw.split("/")[-1];
    if not module_name {
        return None;
    }
    if raw.startswith("@") {
        package_root: any = "/".join(raw.split("/")[:2]);
    } else {
        package_root = raw.split("/")[0];
    }
    return (_make_id("ref", package_root), None);
}

impl _resolve_c_include_path(raw: str, str_path: str) -> "Path | None" {
    if not raw {
        return None;
    }
    candidate: any = _resolve_cached(Path(str_path).parent / raw);
    if candidate.is_file() {
        return candidate;
    }
    return None;
}

impl _resolve_lua_import_target(raw_module: str, str_path: str) -> str {
    if not raw_module {
        return "";
    }
    rel: any = raw_module.replace(".", "/");
    try {
        start_dir: any = Path(str_path).parent;
    } except Exception {
        start_dir = None;
    }
    if start_dir is not None {
        probe: any = start_dir;
        for _ in range(6) {
            suffix: any;
            for suffix in (".lua", ".luau") {
                cand: any = probe / f"{rel}{suffix}";
                if cand.is_file() {
                    return _make_id(`str(cand));
                }
            }
            for suffix in (".lua", ".luau") {
                cand = probe / rel / f"init{suffix}";
                if cand.is_file() {
                    return _make_id(`str(cand));
                }
            }
            if probe.parent == probe {
                break;
            }
            probe = probe.parent;
        }
    }
    return _make_id(raw_module);
}

impl _vue_mask_non_script(src: str) -> tuple[str, str | None] {
    def _blank(s: str) -> str {
        return re.sub("[^\\r\\n]", " ", s);
    }

    out: list[str] = [];
    pos: any = 0;
    lang: str | None = None;
    for m in _VUE_SCRIPT_RE.finditer(src) {
        out.append(_blank(src[pos:m.start()]));
        out.append(_blank(m.group(1)));
        out.append(m.group(2));
        out.append(_blank(m.group(3)));
        pos = m.end();
        if lang is None {
            lang_m: any = _VUE_SCRIPT_LANG_RE.search(m.group(1));
            if lang_m {
                lang = lang_m.group(1).lower();
            }
        }
    }
    out.append(_blank(src[pos:]));
    return ("".join(out), lang);
}

impl _svelte_mask_non_script(src: str) -> tuple[str, str | None] {
    chars: any = [c if c in "\r\n" else " " for c in src];
    lang: str | None = None;
    for m in _HTML_SCRIPT_TAG_RE.finditer(src) {
        if _NON_JS_SCRIPT_TYPE_RE.search(m.group(1)) {
            continue;
        }
        start: any;
        end: any;
        (start, end) = (m.start(2), m.end(2));
        chars[start:end] = src[start:end];
        chars[end:end + 4] = [" ", ";", "", ""];
        if lang is None {
            lang_m: any = _VUE_SCRIPT_LANG_RE.search(m.group(1));
            if lang_m {
                lang = lang_m.group(1).lower();
            }
        }
    }
    return ("".join(chars), lang);
}

impl _memo_cwd(path_str: str) -> str {
    return "" if Path(path_str).is_absolute() else os.getcwd();
}

impl _cached_source_key(source_file: str, root_str: str, _cwd: str) -> str {
    source_path: any = Path(source_file);
    try {
        return `str(source_path.resolve().relative_to(root_str));
    } except Exception {
        return `str(source_path);
    }
}

impl _source_key(source_file: str, `root: Path) -> str {
    if not source_file {
        return "";
    }
    return _cached_source_key(source_file, `str(`root), _memo_cwd(source_file));
}

impl _node_disambiguation_source_key(`node: dict, `root: Path) -> str {
    source_file: any = `str(`node.get("source_file", ""));
    if source_file {
        return _source_key(source_file, `root);
    }
    return _source_key(`str(`node.get("origin_file", "")), `root);
}

impl _disambiguate_colliding_node_ids(
    nodes: list[dict], edges: list[dict], raw_calls: list[dict], `root: Path
) {
    by_id: dict[str, list[dict]] = {};
    folded_files: dict[int, list[str]] = {};
    `node: any;
    for `node in nodes {
        folded: any = `node.pop("_go_folded_files", None);
        if folded {
            folded_files[id(`node)] = folded;
        }
        if `node.get("type") in ("module", "namespace") {
            continue;
        }
        nid: any = `node.get("id");
        if isinstance(nid, `str) and nid {
            by_id.setdefault(nid, []).append(`node);
        }
    }

    remap: dict[tuple[str, str], str] = {};
    ambiguous_ids: set[str] = set[any]();
    old_id: any;
    group: any;
    for (old_id, group) in by_id.items() {
        source_keys: any = {_node_disambiguation_source_key(`node, `root) for `node in group};
        if len(group) < 2 or len(source_keys) < 2 {
            continue;
        }
        ambiguous_ids.add(old_id);
        naive: dict[str, str] = {};
        source_key: any;
        for source_key in source_keys {
            if source_key {
                naive[source_key] = _make_id(source_key, old_id);
            }
        }
        seen: dict[str, int] = {};
        for nid in naive.values() {
            seen[nid] = seen.get(nid, 0) + 1;
        }
        needs_hash: any = {sk for (sk, nid) in naive.items() if seen.get(nid, 0) > 1};
        for `node in group {
            source_key = _node_disambiguation_source_key(`node, `root);
            if not source_key {
                continue;
            }
            if source_key in needs_hash {
                salt: any = hashlib.sha1(source_key.encode("utf-8")).hexdigest()[:6];
                new_id: any = _make_id(source_key, old_id, salt);
            } else {
                new_id = naive.get(source_key) or _make_id(source_key, old_id);
            }
            remap[old_id, source_key] = new_id;
            if new_id != old_id {
                `node["id"] = new_id;
            }
        }
        for `node in group {
            for folded_file in folded_files.get(id(`node), ()) {
                folded_key: any = _source_key(folded_file, `root);
                if folded_key and folded_key not in source_keys {
                    remap.setdefault((old_id, folded_key), `node["id"]);
                }
            }
        }
    }

    if not remap {
        `edge: any;
        for `edge in edges {
            `edge.pop("target_file", None);
        }
        return;
    }

    unambiguous_remaps: dict[str, str] = {};
    for (old_id, group) in by_id.items() {
        if old_id in ambiguous_ids {
            continue;
        }
        candidates: any = {
            `node["id"]
            for `node in group
            if isinstance(`node.get("id"), `str) and `node["id"] != old_id
        };
        if len(candidates) == 1 {
            unambiguous_remaps[old_id] = next(iter(candidates));
        }
    }
    _lang_family: any = importlib.import_module("graphify.extract")._lang_family;

    header_suffixes: any = {".h", ".hpp", ".hh", ".hxx"};
    header_remaps: dict[str, str] = {};
    file_remaps: dict[tuple[str, str], set[str]] = {};
    for old_id in ambiguous_ids {
        for `node in by_id[old_id] {
            source: any = _node_disambiguation_source_key(`node, `root);
            new_id = remap.get((old_id, source));
            if not source or not new_id {
                continue;
            }
            if Path(source).suffix.lower() in header_suffixes {
                header_remaps.setdefault(old_id, new_id);
            }
            family: any = _lang_family(source);
            if family and `node.get("label") == Path(source).name {
                file_remaps.setdefault((old_id, family), set[any]()).add(new_id);
            }
        }
    }

    for `edge in edges {
        edge_source_key: any = _source_key(`str(`edge.get("source_file", "")), `root);
        source_key = (`edge.get("source", ""), edge_source_key);
        target_file: any = `edge.pop("target_file", None);
        if target_file and `edge.get("relation") in ("imports", "imports_from", "re_exports") {
            target_edge_key: any = _source_key(`str(target_file), `root);
        } else {
            target_edge_key = edge_source_key;
        }
        target_key: any = (`edge.get("target", ""), target_edge_key);
        if source_key in remap {
            `edge["source"] = remap[source_key];
        } elif `edge.get("source") in unambiguous_remaps {
            `edge["source"] = unambiguous_remaps[`str(`edge["source"])];
        }
        target: any = `str(`edge.get("target", ""));
        if not target_file
            and target in header_remaps
            and `edge.get("relation") in ("imports", "imports_from")
        {
            family = _lang_family(edge_source_key);
            if family == "native" or effective_suffix(edge_source_key) in header_suffixes {
                `edge["target"] = header_remaps[target];
            } elif family {
                candidates = file_remaps.get((target, family), set[any]());
                if len(candidates) == 1 {
                    `edge["target"] = next(iter(candidates));
                }
            }
        } elif target_key in remap {
            `edge["target"] = remap[target_key];
        } elif `edge.get("target") in unambiguous_remaps {
            `edge["target"] = unambiguous_remaps[`str(`edge["target"])];
        }
    }

    for raw_call in raw_calls {
        call_source_key: any = _source_key(`str(raw_call.get("source_file", "")), `root);
        caller_key: any = (raw_call.get("caller_nid", ""), call_source_key);
        if caller_key in remap {
            raw_call["caller_nid"] = remap[caller_key];
        } elif raw_call.get("caller_nid") in unambiguous_remaps {
            raw_call["caller_nid"] = unambiguous_remaps[`str(raw_call["caller_nid"])];
        }
        if raw_call.get("evidence_owner") {
            eo_key: any = (raw_call.get("evidence_owner", ""), call_source_key);
            if eo_key in remap {
                raw_call["evidence_owner"] = remap[eo_key];
            } elif raw_call.get("evidence_owner") in unambiguous_remaps {
                raw_call["evidence_owner"] = unambiguous_remaps[`str(raw_call["evidence_owner"])];
            }
        }
    }
}

impl _is_type_like_definition(`node: dict) -> bool {
    if `node.get("type") == "namespace" {
        return False;
    }
    label: any = `str(`node.get("label", "")).strip();
    if not label {
        return False;
    }
    if label.endswith(")") or label.startswith(".") {
        return False;
    }
    if "." in label and not `str(`node.get("source_file", "")).lower().endswith(".sql") {
        return False;
    }
    return operator.eq(`node.get("file_type"), "code");
}

impl _cached_realpath(path_str: str, _cwd: str) -> Path {
    return Path(path_str).resolve();
}

impl _resolve_cached(path: "Path | str") -> Path {
    path_str: any = `str(path);
    return _cached_realpath(path_str, _memo_cwd(path_str));
}

impl _js_source_path(source_file: str, `root: Path) -> Path | None {
    if not source_file {
        return None;
    }
    path: any = Path(source_file);
    if not path.is_absolute() {
        path = `root / path;
    }
    try {
        return _resolve_cached(path);
    } except Exception {
        return path;
    }
}

impl _apply_symbol_resolution_facts(
    paths: list[Path],
    nodes: list[dict],
    edges: list[dict],
    `root: Path,
    facts: _SymbolResolutionFacts,
    resolution_context_nodes: list[dict] | None = None,
    raw_calls: list[dict] | None = None,
) {
    path_by_resolved: any;
    symbol_nodes: dict[tuple[Path, str], str];
    member_symbol_keys: set[tuple[Path, str]];
    declared: dict[tuple[Path, str], str];
    target_path: any;
    existing_edges: any;
    named_exports_by_file: dict[Path, dict[str, tuple[Path, str]]];
    export_origins: dict[tuple[Path, str], set[tuple[Path, str]]];
    star_exports_by_file: dict[Path, list[Path]];
    collision_groups: dict[str, list[tuple[dict, bool]]];
    n: any;
    if not (
        facts.declarations
        or facts.imports
        or facts.aliases
        or facts.exports
        or facts.star_exports
        or facts.namespace_exports
        or facts.uses
        or facts.module_imports
    ) {
        `edge: any;
        for `edge in edges {
            `edge.pop("_require_imported_name", None);
            `edge.pop("_require_target_file", None);
        }
        return;
    }

    path_by_resolved = {_resolve_cached(path): path for path in paths};
    source_file_id: any = {_resolve_cached(path): _make_id(`str(path)) for path in paths};

    def reexport_file_target(path: Path) -> tuple[str, str] {
        resolved: any = _resolve_cached(path);
        stored: any = path_by_resolved.get(resolved, resolved);
        try {
            target_is_file: any = resolved.is_file();
        } except OSError {
            target_is_file = False;
        }
        if not target_is_file {
            try {
                relative: any = resolved.relative_to(`root);
            } except ValueError {} else {
                identity: any = relative.as_posix();
                salt: any = hashlib.sha1(identity.encode("utf-8")).hexdigest()[:12];
                return (_make_id("unresolved_reexport", _file_stem(relative), salt), `str(stored));
            }
        }
        return (_make_id(`str(stored)), `str(stored));
    }

    symbol_nodes = {};
    member_symbol_keys = set[any]();

    if resolution_context_nodes {
        _fresh_node_ids: any = {n.get("id") for n in nodes if n.get("id")};
        _fresh_paths: any = {_resolve_cached(p) for p in paths};
        `node: any;
        for `node in resolution_context_nodes {
            nid: any = `node.get("id");
            if not nid or nid in _fresh_node_ids {
                continue;
            }
            source_path: any = _js_source_path(`str(`node.get("source_file", "")), `root);
            if source_path is None or source_path in _fresh_paths {
                continue;
            }
            raw_label: any = `str(`node.get("label", "")).strip();
            label: any = raw_label.strip("()").lstrip(".");
            if not label {
                continue;
            }
            key: any = (source_path, label);
            if raw_label.startswith(".") {
                if key in symbol_nodes {
                    continue;
                }
                member_symbol_keys.add(key);
            } else {
                member_symbol_keys.discard(key);
            }
            symbol_nodes[key] = `str(nid);
        }
    }

    for `node in nodes {
        source_path = _js_source_path(`str(`node.get("source_file", "")), `root);
        if source_path is None {
            continue;
        }
        raw_label = `str(`node.get("label", "")).strip();
        label = raw_label.strip("()").lstrip(".");
        if not label or not `node.get("id") {
            continue;
        }
        key = (source_path, label);
        if raw_label.startswith(".") {
            if key in symbol_nodes {
                continue;
            }
            member_symbol_keys.add(key);
        } else {
            member_symbol_keys.discard(key);
        }
        symbol_nodes[key] = `str(`node["id"]);
    }

    def ensure_symbol_node(path: Path, name: str, line: int) -> str {
        resolved_path: any = _resolve_cached(path);
        existing: any = symbol_nodes.get((resolved_path, name));
        if existing is not None {
            return existing;
        }
        node_id: any = _make_id(_file_stem(path), name);
        symbol_nodes[resolved_path, name] = node_id;
        nodes.append({
            "id": node_id,
            "label": name,
            "file_type": "code",
            "source_file": `str(path),
            "source_location": f"L{line}",
        });
        return node_id;
    }
    if facts.imports {
        declared = {};
        for `node in nodes {
            node_path: any = _js_source_path(`str(`node.get("source_file") or ""), `root);
            if node_path is None {
                continue;
            }
            label = `str(`node.get("label") or "").strip();
            if not label or label.startswith(".") {
                continue;
            }
            bare: any = label[:-2] if label.endswith("()") else label;
            if "." in bare {
                continue;
            }
            declared.setdefault((node_path, normalize_id(bare)), `node["id"]);
        }
        node_by_id: any = {`node.get("id"): `node for `node in nodes};
        refs_by_source: dict[Path, list[dict]] = {};
        for `edge in edges {
            if `edge.get("relation") != "references" {
                continue;
            }
            edge_source: any = _js_source_path(`str(`edge.get("source_file") or ""), `root);
            if edge_source is not None {
                refs_by_source.setdefault(edge_source, []).append(`edge);
            }
        }
        for fact in facts.imports {
            if effective_suffix(fact.file_path).lower()
                not in (".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs")
            {
                continue;
            }
            source_path = _resolve_cached(fact.file_path);
            target_path = _resolve_cached(fact.target_path);
            names: any = {normalize_id(fact.imported_name), normalize_id(fact.local_name)};
            target_nid: any = next(
                (declared[target_path, name] for name in names if (target_path, name) in declared),
                None,
            );
            if not target_nid {
                continue;
            }
            for `edge in refs_by_source.get(source_path, ()) {
                if `edge.get("target") == target_nid {
                    continue;
                }
                `node = node_by_id.get(`edge.get("target"));
                if `node is None or `node.get("source_file") {
                    continue;
                }
                stub_label: any = normalize_id(
                    `str(`node.get("label") or "").strip("()").lstrip(".")
                );
                if stub_label in names {
                    `edge["target"] = target_nid;
                }
            }
        }
    }
    existing_edges = {
        (
            `str(`edge.get("source")),
            `str(`edge.get("target")),
            `str(`edge.get("relation")),
            `str(`edge.get("context") or ""),
            _js_source_path(`str(`edge.get("source_file") or ""), `root),
        )
        for `edge in edges
    };

    def add_edge(
        source: str,
        target: str,
        relation: str,
        context: str,
        line: int,
        source_path: Path,
        target_file: str | None = None,
        local_alias: str | None = None,
        type_only: bool = False,
    ) {
        key: any = (
            source,
            target,
            relation,
            context or "",
            _js_source_path(`str(source_path), `root),
        );
        if key in existing_edges {
            return;
        }
        existing_edges.add(key);
        `edge: any = {
            "source": source,
            "target": target,
            "relation": relation,
            "context": context,
            "confidence": "EXTRACTED",
            "source_file": `str(source_path),
            "source_location": f"L{line}",
            "weight": 1.0,
        };
        if target_file is not None {
            `edge["target_file"] = target_file;
        }
        if local_alias is not None {
            `edge["local_alias"] = local_alias;
        }
        if type_only {
            `edge["type_only"] = True;
        }
        edges.append(`edge);
    }

    for declaration in facts.declarations {
        ensure_symbol_node(declaration.file_path, declaration.name, declaration.line);
    }

    local_aliases_by_file: dict[Path, dict[str, tuple[Path, str]]] = {};
    import_fact: any;
    for import_fact in facts.imports {
        file_path: any = _resolve_cached(import_fact.file_path);
        local_aliases_by_file.setdefault(file_path, {})[import_fact.local_name] = (
            _resolve_cached(import_fact.target_path),
            import_fact.imported_name,
        );
    }

    pending_aliases_by_file: dict[Path, list[_SymbolAliasFact]] = {};
    alias_fact: any;
    for alias_fact in facts.aliases {
        pending_aliases_by_file.setdefault(_resolve_cached(alias_fact.file_path), []).append(
            alias_fact
        );
    }

    for (file_path, aliases) in pending_aliases_by_file.items() {
        local_aliases: any = local_aliases_by_file.setdefault(file_path, {});
        changed: any = True;
        while changed {
            changed = False;
            for alias_fact in aliases {
                if alias_fact.alias in local_aliases {
                    continue;
                }
                origin: tuple[Path, str] | None = local_aliases.get(alias_fact.target_name);
                if origin is not None {
                    local_aliases[alias_fact.alias] = origin;
                    changed = True;
                }
            }
        }
    }

    named_exports_by_file = {};
    export_origins = {};
    star_exports_by_file = {};

    for star_fact in facts.star_exports {
        source_path = _resolve_cached(star_fact.file_path);
        target_path = _resolve_cached(star_fact.target_path);
        star_exports_by_file.setdefault(source_path, []).append(target_path);
        source_id: any = source_file_id.get(source_path);
        if source_id is not None {
            target_id: any;
            target_file: any;
            (target_id, target_file) = reexport_file_target(target_path) as any;
            add_edge(
                source_id,
                target_id,
                "re_exports",
                "export",
                star_fact.line,
                star_fact.file_path,
                target_file=target_file,
                type_only=star_fact.type_only,
            );
        }
    }

    for namespace_fact in facts.namespace_exports {
        source_path = _resolve_cached(namespace_fact.file_path);
        target_path = _resolve_cached(namespace_fact.target_path);
        namespace_id: any = ensure_symbol_node(
            namespace_fact.file_path, namespace_fact.exported_name, namespace_fact.line
        );
        named_exports_by_file.setdefault(source_path, {})[namespace_fact.exported_name] = (
            source_path,
            namespace_fact.exported_name,
        );
        source_id = source_file_id.get(source_path);
        if source_id is not None {
            add_edge(
                source_id,
                namespace_id,
                "contains",
                "namespace_export",
                namespace_fact.line,
                namespace_fact.file_path,
            );
            (target_id, target_file) = reexport_file_target(target_path) as any;
            add_edge(
                source_id,
                target_id,
                "re_exports",
                "export",
                namespace_fact.line,
                namespace_fact.file_path,
                target_file=target_file,
                type_only=namespace_fact.type_only,
            );
        }
    }

    export_fact: any;
    for export_fact in facts.exports {
        file_path = _resolve_cached(export_fact.file_path);
        origin = None;
        if export_fact.target_path is not None and export_fact.target_name is not None {
            origin = (_resolve_cached(export_fact.target_path), export_fact.target_name);
        } elif export_fact.local_name is not None {
            origin = local_aliases_by_file.get(file_path, {}).get(export_fact.local_name);
            if origin is None and (file_path, export_fact.local_name) in symbol_nodes {
                origin = (file_path, export_fact.local_name);
            }
        }
        if origin is None {
            if export_fact.local_name is not None {
                export_origins.setdefault((file_path, export_fact.exported_name), set[any]()).add((
                    file_path,
                    export_fact.local_name,
                ));
            }
            continue;
        }
        export_origins.setdefault((file_path, export_fact.exported_name), set[any]()).add(origin);
        named_exports_by_file.setdefault(file_path, {})[export_fact.exported_name] = origin;
        if origin[0] != file_path {
            source_id = source_file_id.get(file_path);
            if source_id is not None {
                (target_id, target_file) = reexport_file_target(origin[0]) as any;
                add_edge(
                    source_id,
                    target_id,
                    "re_exports",
                    "export",
                    export_fact.line,
                    export_fact.file_path,
                    target_file=target_file,
                    type_only=export_fact.type_only,
                );
            }
        }
    }

    def resolve_exported_origin(
        target_path: Path, imported_name: str, seen: set[tuple[Path, str]] | None = None
    ) -> tuple[Path, str] {
        target_path = _resolve_cached(target_path);
        key: any = (target_path, imported_name);
        if seen is None {
            seen = set[any]();
        }
        if key in seen {
            return key;
        }
        seen.add(key);
        origin: any = named_exports_by_file.get(target_path, {}).get(imported_name);
        if origin is not None {
            return resolve_exported_origin(origin[0], origin[1], seen);
        }
        for star_target in star_exports_by_file.get(target_path, []) {
            star_key: any = (star_target, imported_name);
            if star_key in symbol_nodes and star_key not in member_symbol_keys {
                return star_key;
            }
            resolved: any = resolve_exported_origin(star_target, imported_name, seen);
            if resolved in symbol_nodes and resolved not in member_symbol_keys {
                return resolved;
            }
        }
        return key;
    }

    def exported_candidates(
        key: tuple[Path, str], seen: frozenset[tuple[Path, str]]
    ) -> tuple[set[tuple[Path, str]], bool] {
        if key in seen {
            return (set[any](), True);
        }
        seen = seen | {key};
        origins: any = export_origins.get(key);
        candidates: set[tuple[Path, str]] = set[any]();
        cyclic: any = False;
        if origins is None {
            for path in star_exports_by_file.get(key[0], []) {
                branch: any;
                branch_cyclic: any;
                (branch, branch_cyclic) = exported_candidates((path, key[1]), seen) as any;
                candidates.update(branch);
                cyclic |= branch_cyclic;
            }
            return (candidates, cyclic);
        }
        for origin in origins {
            if origin == key {
                candidates.add(origin);
            } else {
                (branch, branch_cyclic) = exported_candidates(origin, seen) as any;
                candidates.update(branch);
                cyclic |= branch_cyclic;
                if not branch and not branch_cyclic {
                    candidates.add(origin);
                }
            }
        }
        return (candidates, cyclic);
    }
    for `edge in edges {
        imported_name: any = `edge.pop("_require_imported_name", None);
        target_file = `edge.pop("_require_target_file", None);
        if `edge.get("relation") != "imports" or not imported_name or not target_file {
            continue;
        }
        origin_path: any;
        origin_symbol: any;
        (origin_path, origin_symbol) = resolve_exported_origin(
            Path(`str(target_file)), `str(imported_name)
        ) as any;
        target_id = symbol_nodes.get((origin_path, origin_symbol));
        if target_id is None or `edge.get("target") == target_id {
            continue;
        }
        `edge["target"] = target_id;
        `edge["target_file"] = `str(path_by_resolved.get(origin_path, origin_path));
    }
    export_sites: dict[tuple[Path, str, Path], list[_SymbolExportFact]] = {};
    for export_fact in facts.exports {
        if export_fact.target_path is not None and export_fact.target_name is not None {
            site: any = (
                _resolve_cached(export_fact.file_path),
                f"L{export_fact.line}",
                _resolve_cached(export_fact.target_path),
            );
            export_sites.setdefault(site, []).append(export_fact);
        }
    }
    owned_ids: any = {`node.get("id") for `node in nodes};
    for `edge in edges {
        if `edge.get("relation") != "re_exports" or `edge.get("target") in owned_ids {
            continue;
        }
        target_file = `edge.get("target_file");
        source_path = _js_source_path(`str(`edge.get("source_file", "")), `root);
        if not target_file or source_path is None {
            continue;
        }
        target_path = Path(target_file);
        site = (source_path, `str(`edge.get("source_location", "")), _resolve_cached(target_path));
        for export_fact in export_sites.get(site, []) {
            expected: any = _make_id(_file_stem(target_path), export_fact.target_name);
            if `edge.get("target") != expected {
                continue;
            }
            candidates: any;
            _: any;
            (candidates, _) = exported_candidates(
                (_resolve_cached(export_fact.target_path), export_fact.target_name), frozenset()
            ) as any;
            if len(candidates) == 1 {
                origin = next(iter(candidates));
                target_id = symbol_nodes.get(origin);
                if target_id in owned_ids {
                    `edge["target"] = target_id;
                    `edge["target_file"] = `str(path_by_resolved.get(origin[0], origin[0]));
                }
            }
            break;
        }
    }

    for import_fact in facts.imports {
        source_id = source_file_id.get(_resolve_cached(import_fact.file_path));
        if source_id is None {
            continue;
        }
        (origin_path, origin_symbol) = resolve_exported_origin(
            import_fact.target_path, import_fact.imported_name
        ) as any;
        target_id = symbol_nodes.get((origin_path, origin_symbol));
        if target_id is None {
            continue;
        }
        add_edge(
            source_id, target_id, "imports", "import", import_fact.line, import_fact.file_path
        );
    }

    if raw_calls
        and `any(
            fact.imported_name in ("default", "*")
                and effective_suffix(fact.file_path) in _JS_CACHE_BYPASS_SUFFIXES
            for fact in facts.imports,
        )
    {
        default_imports: any = {
            (_resolve_cached(fact.file_path), fact.local_name): _resolve_cached(fact.target_path)
            for fact in facts.imports
            if fact.imported_name == "default"
                and effective_suffix(fact.file_path) in _JS_CACHE_BYPASS_SUFFIXES
        };
        namespace_imports: any = {
            (_resolve_cached(fact.file_path), fact.local_name): _resolve_cached(fact.target_path)
            for fact in facts.imports
            if fact.imported_name == "*"
                and effective_suffix(fact.file_path) in _JS_CACHE_BYPASS_SUFFIXES
        };
        member_nodes: dict[tuple[Path, str, str], set[str]] = {};
        callable_node_ids: set[str] = set[any]();
        fresh_paths: any = {_resolve_cached(path) for path in paths};
        for `node in nodes + [
            `node
            for `node in resolution_context_nodes or []
            if _js_source_path(`str(`node.get("source_file", "")), `root) not in fresh_paths
        ] {
            if not `node.get("_callable") {
                continue;
            }
            callable_node_ids.add(`str(`node["id"]));
            source_path = _js_source_path(`str(`node.get("source_file", "")), `root);
            if source_path is None {
                continue;
            }
            key = (
                source_path,
                `str(`node.get("label", "")),
                `str(`node.get("source_location", "")),
            );
            member_nodes.setdefault(key, set[any]()).add(`str(`node["id"]));
        }
        default_members: dict[Path, dict[str, tuple[str, str]]] = {};
        for call in raw_calls {
            if not call.get("is_member_call")
                or call.get("_js_construct")
                or call.get("ts_this_field")
            {
                continue;
            }
            source_path = _js_source_path(`str(call.get("source_file", "")), `root);
            if source_path is None {
                continue;
            }
            receiver: any = `str(call.get("receiver") or "");
            callee: any = `str(call.get("callee") or "");
            if not receiver or not callee {
                continue;
            }
            if (source_path, receiver) in namespace_imports {
                if call.get("_js_receiver_shadowed") {
                    continue;
                }
                target_path = namespace_imports[source_path, receiver];
                (candidates, _) = exported_candidates((target_path, callee), frozenset()) as any;
                if len(candidates) == 1 {
                    (origin_path, origin_symbol) = next(iter(candidates)) as any;
                    target_id = symbol_nodes.get((origin_path, origin_symbol));
                    if target_id is not None and target_id in callable_node_ids {
                        add_edge(
                            call["caller_nid"],
                            target_id,
                            "calls",
                            "call",
                            `int(`str(call["source_location"]).removeprefix("L")),
                            Path(call["source_file"]),
                            target_file=`str(target_path),
                        );
                        continue;
                    }
                }
            }
            if call.get("_js_receiver_shadowed") {
                continue;
            }
            target_path = default_imports.get((source_path, receiver));
            if target_path is None {
                continue;
            }
            if target_path not in default_members {
                default_members[target_path] = _js_default_object_members(target_path);
            }
            member: any = default_members[target_path].get(callee);
            if member is None {
                continue;
            }
            targets: any = member_nodes.get((target_path, *member), set[any]());
            if len(targets) != 1 {
                continue;
            }
            add_edge(
                call["caller_nid"],
                next(iter(targets)),
                "calls",
                "call",
                `int(`str(call["source_location"]).removeprefix("L")),
                Path(call["source_file"]),
                target_file=`str(target_path),
            );
        }
    }
    import_sites: dict[tuple[Path, str, Path], list[_SymbolImportFact]] = {};
    for import_fact in facts.imports {
        site = (
            _resolve_cached(import_fact.file_path),
            f"L{import_fact.line}",
            _resolve_cached(import_fact.target_path),
        );
        import_sites.setdefault(site, []).append(import_fact);
    }
    superseded: set[int] = set[any]();
    for `edge in edges {
        if `edge.get("relation") != "imports" or `edge.get("target") in owned_ids {
            continue;
        }
        target_file = `edge.get("target_file");
        source_path = _js_source_path(`str(`edge.get("source_file", "")), `root);
        if not target_file or source_path is None {
            continue;
        }
        target_path = Path(target_file);
        site = (source_path, `str(`edge.get("source_location", "")), _resolve_cached(target_path));
        for import_fact in import_sites.get(site, []) {
            if `edge.get("target") != _make_id(_file_stem(target_path), import_fact.imported_name) {
                continue;
            }
            barrel_key: any = (_resolve_cached(import_fact.target_path), import_fact.imported_name);
            (candidates, _) = exported_candidates(barrel_key, frozenset()) as any;
            if len(candidates) == 1 {
                origin = next(iter(candidates));
                if origin != barrel_key and symbol_nodes.get(origin) in owned_ids {
                    superseded.add(id(`edge));
                }
            }
            break;
        }
    }
    if superseded {
        edges[:] = [`edge for `edge in edges if id(`edge) not in superseded];
    }
    provisional_by_loc: dict[tuple[Path, str], list[dict]] = {};
    for `edge in edges {
        if `edge.get("relation") == "imports_from" and `edge.get("context") == "import" {
            src: any = _js_source_path(`str(`edge.get("source_file", "")), `root);
            loc: any = `edge.get("source_location");
            if src is not None and loc {
                provisional_by_loc.setdefault((src, loc), []).append(`edge);
            }
        }
    }

    retracted_edge_ids: set[int] = set[any]();
    for (from_path, to_path, line, local_name) in facts.module_imports {
        try {
            from_rel: any = from_path.relative_to(`root);
            to_rel: any = to_path.relative_to(`root);
        } except ValueError {
            continue;
        }
        source_id = _make_id(_file_stem(from_rel));
        target_id = _make_id(_file_stem(to_rel));

        from_canon: any = _resolve_cached(from_path);
        pkg_dir: any = to_path.parent;
        candidate_targets: set[str] = set[any]();
        try {
            pkg_rel: any = pkg_dir.relative_to(`root);
            candidate_targets.add(_make_id(".".join(pkg_rel.parts)));
            candidate_targets.add(_make_id(_file_stem(pkg_rel)));
            candidate_targets.add(_make_id(`str(pkg_rel)));
        } except ValueError {}
        candidate_targets.add(_make_id(`str(pkg_dir)));
        candidate_targets.add(_make_id(`str(pkg_dir.with_suffix(".py"))));
        try {
            from_rel_parent: any = from_path.parent.relative_to(`root);
            candidate_targets.add(_make_id(`str(from_rel_parent.with_suffix(".py"))));
        } except ValueError {}

        loc_str: any = f"L{line}";
        loc_candidates: any = [
            e
            for e in provisional_by_loc.get((from_canon, loc_str), [])
            if id(e) not in retracted_edge_ids
        ];
        matched_edge: any = None;
        for `edge in loc_candidates {
            if `edge.get("target") in candidate_targets {
                matched_edge = `edge;
                break;
            }
        }

        if matched_edge is not None {
            retracted_edge_ids.add(id(matched_edge));
            existing_edges.discard((
                `str(matched_edge.get("source")),
                `str(matched_edge.get("target")),
                `str(matched_edge.get("relation")),
                `str(matched_edge.get("context") or ""),
            ));
        }

        add_edge(
            source_id,
            target_id,
            "imports_from",
            "submodule_import",
            line,
            from_path,
            local_alias=local_name if local_name != to_path.stem else None,
        );
    }

    if retracted_edge_ids {
        edges[:] = [e for e in edges if id(e) not in retracted_edge_ids];
    }
    owned: any = {`str(n.get("id")) for n in nodes};
    _salt_rx: any = re.compile("[0-9a-f]{6}");
    collision_groups = {};
    for n in nodes {
        nid = n.get("id");
        if not isinstance(nid, `str) {
            continue;
        }
        collision_groups.setdefault(nid, []).append((n, False));
        if len(nid) >= 7 and nid[-7] == "_" and _salt_rx.fullmatch(nid[-6:]) {
            collision_groups.setdefault(nid[:-7], []).append((n, True));
        }
    }
    def _collision_aware(source_id: str, file_path: Path, line: int) -> str {
        group: any = collision_groups.get(source_id, ());
        if not `any(salted for (_, salted) in group) {
            return source_id;
        }
        candidates: any = [
            n
            for (n, salted) in group
            if not salted or _js_source_path(`str(n.get("source_file") or ""), `root) == file_path
        ];
        if len(candidates) < 2 {
            return source_id;
        }

        def _start(`node: dict) -> int {
            try {
                return `int(`str(`node.get("source_location") or "").removeprefix("L"));
            } except ValueError {
                return 0;
            }
        }

        enclosing: any = [n for n in candidates if _start(n) <= line];
        if not enclosing {
            return source_id;
        }
        return `str(max(enclosing, key=_start)["id"]);
    }

    for use_fact in facts.uses {
        file_path = _resolve_cached(use_fact.file_path);
        target_id = None;
        unresolved_origin: any = local_aliases_by_file.get(file_path, {}).get(use_fact.local_name);
        if unresolved_origin is not None {
            (origin_path, origin_symbol) = resolve_exported_origin(*unresolved_origin) as any;
            target_id = symbol_nodes.get((origin_path, origin_symbol));
        }
        if target_id is None and use_fact.relation in ("inherits", "implements") {
            target_id = symbol_nodes.get((file_path, use_fact.local_name));
        }
        if target_id is None {
            continue;
        }
        source_id = _collision_aware(use_fact.source_id, file_path, use_fact.line);
        if use_fact.relation in ("inherits", "implements", "references")
            and source_id not in owned
        {
            continue;
        }
        if use_fact.relation == "calls" and source_id not in owned {
            source_id = source_file_id.get(file_path);
            if source_id is None {
                continue;
            }
        }
        add_edge(
            source_id,
            target_id,
            use_fact.relation,
            use_fact.context,
            use_fact.line,
            use_fact.file_path,
        );
    }
}

impl _parse_js_tree(path: Path) -> any {
    try {
        import from tree_sitter { Language, Parser }
        suffix: any = effective_suffix(path);
        if suffix in (".vue", ".svelte") {
            mask: any = _vue_mask_non_script if suffix == ".vue" else _svelte_mask_non_script;
            masked: any;
            lang: any;
            (masked, lang) = mask(_read_source_text(path, warn=False)) as any;
            source: any = masked.encode("utf-8");
            use_ts: any = lang not in ("js", "jsx");
        } else {
            source = _read_source_bytes(path, warn=False);
            use_ts = suffix in (".ts", ".mts", ".cts");
        }
        if suffix == ".tsx" {
            import tree_sitter_typescript as tstypescript;
            language: any = Language(tstypescript.language_tsx());
        } elif use_ts {
            import tree_sitter_typescript as tstypescript;
            language = Language(tstypescript.language_typescript());
        } else {
            import tree_sitter_javascript as tsjavascript;
            language = Language(tsjavascript.language());
        }
        parser: any = Parser(language);
        return (source, parser.parse(source).root_node);
    } except Exception {
        return None;
    }
}

impl _walk_js_tree(`node) -> Generator[any, any, any] {
    cursor: any = `node.walk();
    while True {
        yield cursor.node;
        if cursor.goto_first_child() {
            continue;
        }
        while not cursor.goto_next_sibling() {
            if not cursor.goto_parent() {
                return;
            }
        }
    }
}

impl _js_module_specifier(`node, source: bytes) -> str | None {
    source_node: any = `node.child_by_field_name("source");
    if source_node is None and `node.type != "export_statement" {
        for child in typing.cast(object, `node).children {
            if child.type == "string" {
                source_node = child;
                break;
            }
            if child.type == "import_require_clause" {
                source_node = next((sub for sub in child.children if sub.type == "string"), None);
                break;
            }
        }
    }
    if source_node is None {
        return None;
    }
    raw: any = _read_text(source_node, source).strip();
    return raw.strip("'\"`") or None;
}

impl _js_named_specifiers(`node, source: bytes, specifier_type: str) -> list[tuple[str, str]] {
    pairs: list[tuple[str, str]] = [];
    for child in _walk_js_tree(`node) {
        if child.type != specifier_type {
            continue;
        }
        name_node: any = child.child_by_field_name("name");
        if name_node is None {
            continue;
        }
        alias_node: any = child.child_by_field_name("alias");
        name: any = _read_text(name_node, source);
        exposed: any = _read_text(alias_node, source) if alias_node is not None else name;
        if name and exposed {
            pairs.append((name, exposed));
        }
    }
    return pairs;
}

impl _js_export_clause(`node) -> any {
    for child in typing.cast(object, `node).children {
        if child.type == "export_clause" {
            return child;
        }
    }
    return None;
}

impl _js_export_statement_is_star(`node) -> bool {
    return `any(operator.eq(child.type, "*") for child in typing.cast(object, `node).children);
}

impl _js_namespace_export_name(`node, source: bytes) -> str | None {
    for child in typing.cast(object, `node).children {
        if child.type != "namespace_export" {
            continue;
        }
        for sub in child.children {
            if sub.type == "identifier" {
                return _read_text(sub, source) or None;
            }
        }
    }
    return None;
}

impl _js_lexical_aliases(`node, source: bytes) -> list[tuple[str, str]] {
    aliases: list[tuple[str, str]] = [];
    if `node.type != "lexical_declaration" {
        return aliases;
    }
    for child in typing.cast(object, `node).children {
        if child.type != "variable_declarator" {
            continue;
        }
        name_node: any = child.child_by_field_name("name");
        value_node: any = child.child_by_field_name("value");
        if name_node is not None
            and value_node is not None
            and value_node.type in ("identifier", "type_identifier")
        {
            aliases.append((_read_text(name_node, source), _read_text(value_node, source)));
        }
    }
    return aliases;
}

impl _js_exported_declaration_names(`node, source: bytes) -> list[str] {
    names: list[str] = [];
    declaration: any = `node.child_by_field_name("declaration");
    if declaration is None {
        return names;
    }

    if declaration.type in ("lexical_declaration", "variable_declaration") {
        names.extend(alias for (alias, _target) in _js_lexical_aliases(declaration, source));
        for declarator in typing.cast(object, declaration).named_children {
            if declarator.type != "variable_declarator" {
                continue;
            }
            name_node: any = declarator.child_by_field_name("name");
            if name_node is not None and name_node.type == "identifier" {
                name: any = _read_text(name_node, source);
                if name not in names {
                    names.append(name);
                }
            }
        }
        return names;
    }

    if declaration.type
        in (
            "class_declaration",
            "abstract_class_declaration",
            "interface_declaration",
            "type_alias_declaration",
            "function_declaration",
        )
    {
        name_node = declaration.child_by_field_name("name");
        if name_node is not None {
            names.append(_read_text(name_node, source));
        }
    }
    return names;
}

impl _js_default_import_name(`node, source: bytes) -> str | None {
    for child in typing.cast(object, `node).children {
        if child.type == "import_clause" {
            for sub in child.children {
                if sub.type == "identifier" {
                    return _read_text(sub, source);
                }
            }
        }
    }
    return None;
}

impl _js_namespace_import_name(`node, source: bytes) -> str | None {
    for child in typing.cast(object, `node).children {
        if child.type == "import_clause" {
            sub: any;
            for sub in child.children {
                if sub.type == "namespace_import" {
                    for nested in typing.cast(object, sub).children {
                        if nested.type == "identifier" {
                            return _read_text(nested, source) or None;
                        }
                    }
                }
            }
        } elif child.type == "namespace_import" {
            for sub in child.children {
                if sub.type == "identifier" {
                    return _read_text(sub, source) or None;
                }
            }
        }
    }
    return None;
}

impl _js_default_export_name(`node, source: bytes) -> str | None {
    if not `any(operator.eq(child.type, "default") for child in typing.cast(object, `node).children) {
        return None;
    }
    declaration: any = `node.child_by_field_name("declaration");
    if declaration is not None {
        name_node: any = declaration.child_by_field_name("name");
        return _read_text(name_node, source) if name_node is not None else None;
    }
    value: any = `node.child_by_field_name("value");
    if value is not None and value.type == "identifier" {
        return _read_text(value, source);
    }
    return None;
}

impl _js_default_object_members(path: Path) -> dict[str, tuple[str, str]] {
    parsed: any = _parse_js_tree(path);
    if parsed is None {
        return {};
    }
    source: any;
    root_node: any;
    (source, root_node) = parsed as any;
    for `node in typing.cast(object, root_node).named_children {
        if `node.type != "export_statement"
            or not `any(operator.eq(child.type, "default") for child in `node.children)
        {
            continue;
        }
        value: any = `node.child_by_field_name("value");
        if value is None or value.type != "object" {
            continue;
        }
        members: dict[str, tuple[str, str]] = {};
        seen: set[str] = set[any]();
        for prop in typing.cast(object, value).named_children {
            if prop.type == "comment" {
                continue;
            }
            key: any = prop.child_by_field_name("name") or prop.child_by_field_name("key");
            if key is None or key.type not in ("property_identifier", "string") {
                return {};
            }
            raw_name: any = _read_text(key, source);
            if "\\" in raw_name {
                return {};
            }
            name: any = raw_name[1:-1] if key.type == "string" else raw_name;
            if name in seen {
                members.pop(name, None);
                continue;
            }
            seen.add(name);
            if prop.type == "method_definition"
                and not `any(child.type in ("get", "set") for child in prop.children)
            {
                members[name] = (f"{raw_name}()", f"L{prop.start_point[0] + 1}");
            }
        }
        return members;
    }
    return {};
}

impl _js_top_level_function_bodies(
    path: Path, root_node, source: bytes
) -> list[tuple[str, object]] {
    bodies: list[tuple[str, object]] = [];
    stem: any = _file_stem(path);
    top_nodes: list = [];
    `node: any;
    for `node in typing.cast(object, root_node).children {
        if `node.type == "export_statement"
            and not `any(operator.eq(c.type, "string") for c in typing.cast(object, `node).children)
        {
            top_nodes.extend(
                c
                for c in typing.cast(object, `node).children
                if c.type in ("function_declaration", "lexical_declaration"),
            );
        } else {
            top_nodes.append(`node);
        }
    }
    for `node in top_nodes {
        if `node.type == "function_declaration" {
            name_node: any = `node.child_by_field_name("name");
            body: any = `node.child_by_field_name("body");
            if name_node is not None and body is not None {
                bodies.append((_make_id(stem, _read_text(name_node, source)), body));
            }
            continue;
        }
        if `node.type != "lexical_declaration" {
            continue;
        }
        for child in typing.cast(object, `node).children {
            if child.type != "variable_declarator" {
                continue;
            }
            name_node = child.child_by_field_name("name");
            value_node: any = child.child_by_field_name("value");
            if name_node is not None
                and value_node is not None
                and value_node.type == "arrow_function"
            {
                bodies.append((_make_id(stem, _read_text(name_node, source)), value_node));
            }
        }
    }
    return bodies;
}

impl _js_call_identifier(`node, source: bytes) -> str | None {
    if `node.type != "call_expression" {
        return None;
    }
    function_node: any = `node.child_by_field_name("function");
    if function_node is None {
        for child in typing.cast(object, `node).children {
            if child.is_named {
                function_node = child;
                break;
            }
        }
    }
    if function_node is not None and function_node.type in ("identifier", "type_identifier") {
        return _read_text(function_node, source);
    }
    return None;
}

impl _ts_heritage_clause_entries(clause_node, source: bytes) -> list[str] {
    out: list[str] = [];
    for child in typing.cast(object, clause_node).children {
        if not child.is_named {
            continue;
        }
        if child.type in ("identifier", "type_identifier") {
            name: any = _read_text(child, source);
            if name {
                out.append(name);
            }
        } elif child.type == "generic_type" {
            name_node: any = child.child_by_field_name("name");
            if name_node is None {
                for sub in child.children {
                    if sub.type in ("type_identifier", "nested_type_identifier", "identifier") {
                        name_node = sub;
                        break;
                    }
                }
            }
            if name_node is not None {
                text: any = _read_text(name_node, source).rsplit(".", 1)[-1];
                if text {
                    out.append(text);
                }
            }
        } elif child.type == "nested_type_identifier" {
            text = _read_text(child, source).rsplit(".", 1)[-1];
            if text {
                out.append(text);
            }
        }
    }
    return out;
}

impl _ts_collect_type_refs(`node, source: bytes, generic: bool, out: list[tuple[str, str]]) {
    if `node is None {
        return;
    }
    t: any = `node.type;
    if t == "type_annotation" {
        c: any;
        for c in typing.cast(object, `node).children {
            if c.is_named {
                _ts_collect_type_refs(c, source, generic, out);
            }
        }
        return;
    }
    if t in ("type_identifier", "identifier") {
        name: any = _read_text(`node, source);
        if name and name not in _JS_PRIMITIVE_TYPES {
            out.append((name, "generic_arg" if generic else "type"));
        }
        return;
    }
    if t == "nested_type_identifier" {
        tail: any = _read_text(`node, source).rsplit(".", 1)[-1];
        if tail and tail not in _JS_PRIMITIVE_TYPES {
            out.append((tail, "generic_arg" if generic else "type"));
        }
        return;
    }
    if t == "generic_type" {
        name_node: any = `node.child_by_field_name("name");
        if name_node is not None {
            text: any = _read_text(name_node, source).rsplit(".", 1)[-1];
            if text and text not in _JS_PRIMITIVE_TYPES {
                out.append((text, "generic_arg" if generic else "type"));
            }
        } else {
            for c in typing.cast(object, `node).children {
                if c.type in ("type_identifier", "nested_type_identifier") {
                    text = _read_text(c, source).rsplit(".", 1)[-1];
                    if text and text not in _JS_PRIMITIVE_TYPES {
                        out.append((text, "generic_arg" if generic else "type"));
                    }
                    break;
                }
            }
        }
        for c in typing.cast(object, `node).children {
            if c.type == "type_arguments" {
                for sub in typing.cast(object, c).children {
                    if sub.is_named {
                        _ts_collect_type_refs(sub, source, True, out);
                    }
                }
            }
        }
        return;
    }
    if `node.is_named {
        for c in typing.cast(object, `node).children {
            if c.is_named {
                _ts_collect_type_refs(c, source, generic, out);
            }
        }
    }
}

impl _ts_walk_class_members(
    class_node, source: bytes, path: Path, class_nid: str, facts: _SymbolResolutionFacts
) {
    line: any = class_node.start_point[0] + 1;
    for child in typing.cast(object, class_node).children {
        if child.type == "class_heritage" {
            saw_clause: any = False;
            for clause in child.children {
                if clause.type == "extends_clause" {
                    saw_clause = True;
                    name: any;
                    for name in _ts_heritage_clause_entries(clause, source) {
                        facts.uses.append(
                            _SymbolUseFact(
                                path, class_nid, name, "inherits", "type", clause.start_point[0] + 1
                            ),
                        );
                    }
                } elif clause.type == "implements_clause" {
                    saw_clause = True;
                    for name in _ts_heritage_clause_entries(clause, source) {
                        facts.uses.append(
                            _SymbolUseFact(
                                path,
                                class_nid,
                                name,
                                "implements",
                                "type",
                                clause.start_point[0] + 1,
                            ),
                        );
                    }
                }
            }
            if not saw_clause {
                for name in _ts_heritage_clause_entries(child, source) {
                    facts.uses.append(
                        _SymbolUseFact(
                            path, class_nid, name, "inherits", "type", child.start_point[0] + 1
                        ),
                    );
                }
            }
        } elif child.type == "extends_type_clause" {
            for name in _ts_heritage_clause_entries(child, source) {
                facts.uses.append(
                    _SymbolUseFact(
                        path, class_nid, name, "inherits", "type", child.start_point[0] + 1
                    ),
                );
            }
        }
    }

    body: any = class_node.child_by_field_name("body");
    if body is None {
        return;
    }

    for member in typing.cast(object, body).children {
        m_line: any = member.start_point[0] + 1;
        if member.type in ("method_definition", "method_signature", "abstract_method_signature") {
            name_node: any = member.child_by_field_name("name");
            if name_node is None {
                continue;
            }
            method_name: any = _read_text(name_node, source);
            method_nid: any = _make_id(class_nid, method_name);
            params: any = member.child_by_field_name("parameters");
            if params is not None {
                for p in typing.cast(object, params).children {
                    if p.type not in ("required_parameter", "optional_parameter") {
                        continue;
                    }
                    type_anno: any = p.child_by_field_name("type");
                    if type_anno is None {
                        continue;
                    }
                    refs: list[tuple[str, str]] = [];
                    _ts_collect_type_refs(type_anno, source, False, refs);
                    role: any;
                    for (name, role) in refs {
                        ctx: any = "generic_arg" if role == "generic_arg" else "parameter_type";
                        facts.uses.append(
                            _SymbolUseFact(path, method_nid, name, "references", ctx, m_line)
                        );
                    }
                }
            }
            return_type: any = member.child_by_field_name("return_type");
            if return_type is not None {
                refs = [];
                _ts_collect_type_refs(return_type, source, False, refs);
                for (name, role) in refs {
                    ctx = "generic_arg" if role == "generic_arg" else "return_type";
                    facts.uses.append(
                        _SymbolUseFact(path, method_nid, name, "references", ctx, m_line)
                    );
                }
            }
        } elif member.type in ("public_field_definition", "property_signature") {
            type_anno = None;
            for c in member.children {
                if c.type == "type_annotation" {
                    type_anno = c;
                    break;
                }
            }
            if type_anno is None {
                continue;
            }
            refs = [];
            _ts_collect_type_refs(type_anno, source, False, refs);
            for (name, role) in refs {
                ctx = "generic_arg" if role == "generic_arg" else "field";
                facts.uses.append(_SymbolUseFact(path, class_nid, name, "references", ctx, m_line));
            }
        }
    }
}

impl _js_require_call_and_specifier(value_node, source: bytes) -> any {
    if value_node is None {
        return None;
    }
    `node: any = value_node;
    if `node.type == "member_expression" {
        `node = `node.child_by_field_name("object");
        if `node is None {
            return None;
        }
    }
    if `node.type != "call_expression" {
        return None;
    }
    fn: any = `node.child_by_field_name("function");
    if fn is None or fn.type != "identifier" or _read_text(fn, source) != "require" {
        return None;
    }
    args: any = `node.child_by_field_name("arguments");
    if args is None {
        return None;
    }
    raw: any = None;
    for arg in typing.cast(object, args).children {
        if arg.type == "string" {
            raw = _read_text(arg, source).strip("'\"` ");
            break;
        }
    }
    if not raw {
        return None;
    }
    return (`node, raw);
}

impl _js_cjs_require_bindings(declarator, source: bytes) -> list[tuple[str, str]] {
    value: any = declarator.child_by_field_name("value");
    if value is None or value.type != "call_expression" {
        return [];
    }
    req: any = _js_require_call_and_specifier(value, source);
    if req is None {
        return [];
    }
    name_node: any = declarator.child_by_field_name("name");
    if name_node is None or name_node.type != "identifier" {
        return [];
    }
    local: any = _read_text(name_node, source);
    if not local {
        return [];
    }
    return [(local, "*"), (local, "default")];
}

impl _js_cjs_default_export_local(right, source: bytes) -> str | None {
    `node: any = right;
    while `node is not None and `node.type == "assignment_expression" {
        `node = `node.child_by_field_name("right");
    }
    if `node is None {
        return None;
    }
    if `node.type == "identifier" {
        return _read_text(`node, source) or None;
    }
    if `node.type
        in (
            "class",
            "class_declaration",
            "function",
            "function_declaration",
            "generator_function",
            "generator_function_declaration",
        )
    {
        name_node: any = `node.child_by_field_name("name");
        if name_node is not None {
            return _read_text(name_node, source) or None;
        }
    }
    return None;
}

impl _js_cjs_export_facts(`node, source: bytes, path: Path) -> list[_SymbolExportFact] {
    if `node.type != "expression_statement" {
        return [];
    }
    assign: any = next((c for c in typing.cast(object, `node).children if c.type == "assignment_expression"), None);
    if assign is None {
        return [];
    }
    left: any = assign.child_by_field_name("left");
    right: any = assign.child_by_field_name("right");
    if left is None or right is None {
        return [];
    }
    line: any = `node.start_point[0] + 1;
    left_str: any = _read_text(left, source);
    out: list[_SymbolExportFact] = [];
    if left_str == "module.exports" {
        local: any = _js_cjs_default_export_local(right, source);
        if local {
            out.append(_SymbolExportFact(path, "default", line, local_name=local));
            if local != "default" {
                out.append(_SymbolExportFact(path, local, line, local_name=local));
            }
        } elif right.type == "object" {
            prop: any;
            for prop in typing.cast(object, right).children {
                if prop.type == "shorthand_property_identifier" {
                    name: any = _read_text(prop, source);
                    if name {
                        out.append(_SymbolExportFact(path, name, line, local_name=name));
                    }
                } elif prop.type == "method_definition" {
                    name_node: any = prop.child_by_field_name("name");
                    if name_node is not None {
                        name = _read_text(name_node, source);
                        if name {
                            out.append(_SymbolExportFact(path, name, line, local_name=name));
                        }
                    }
                } elif prop.type == "pair" {
                    key: any = prop.child_by_field_name("key");
                    val: any = prop.child_by_field_name("value");
                    if key is None {
                        continue;
                    }
                    exported: any = _read_text(key, source);
                    local_name: any = None;
                    if val is not None and val.type == "identifier" {
                        local_name = _read_text(val, source) or None;
                    }
                    if exported {
                        out.append(
                            _SymbolExportFact(
                                path, exported, line, local_name=local_name or exported
                            ),
                        );
                    }
                }
            }
        }
        return out;
    }
    if left.type != "member_expression" {
        return [];
    }
    `obj: any = left.child_by_field_name("object");
    prop = left.child_by_field_name("property");
    if `obj is None or prop is None {
        return [];
    }
    exported = _read_text(prop, source);
    if not exported {
        return [];
    }
    obj_str: any = _read_text(`obj, source);
    if obj_str not in ("exports", "module.exports") {
        return [];
    }
    local = _js_cjs_default_export_local(right, source) or exported;
    out.append(_SymbolExportFact(path, exported, line, local_name=local));
    return out;
}

impl _collect_js_symbol_resolution_facts(paths: list[Path], facts: _SymbolResolutionFacts) {
    path: any;
    `node: any;
    js_paths: any = [path for path in paths if effective_suffix(path) in _JS_CACHE_BYPASS_SUFFIXES];
    if not js_paths {
        return;
    }
    member_facts: any = _SymbolResolutionFacts();
    for path in js_paths {
        parsed: any = _parse_js_tree(path);
        if parsed is None {
            continue;
        }
        source: any;
        root_node: any;
        (source, root_node) = parsed as any;
        indexed: any = [
            `node
            for `node in _walk_js_tree(root_node)
            if `node.type in _JS_FACT_NODE_TYPES
        ];

        for `node in indexed {
            if `node.type == "export_statement" {
                for name in _js_exported_declaration_names(`node, source) {
                    facts.declarations.append(
                        _SymbolDeclarationFact(path, name, `node.start_point[0] + 1)
                    );
                }
            }

            if `node.type == "expression_statement" {
                facts.exports.extend(_js_cjs_export_facts(`node, source, path));
                continue;
            }

            if `node.type in ("lexical_declaration", "variable_declaration") {
                child: any;
                for child in typing.cast(object, `node).children {
                    if child.type != "variable_declarator" {
                        continue;
                    }
                    bindings: any = _js_cjs_require_bindings(child, source);
                    if not bindings {
                        continue;
                    }
                    req: any = _js_require_call_and_specifier(
                        child.child_by_field_name("value"), source
                    );
                    if req is None {
                        continue;
                    }
                    _call: any;
                    raw_module: any;
                    (_call, raw_module) = req as any;
                    target_path: any = _resolve_js_module_path(raw_module, path.parent);
                    if target_path is None {
                        continue;
                    }
                    target_path = _resolve_cached(target_path);
                    line: any = `node.start_point[0] + 1;
                    local_name: any;
                    imported_name: any;
                    for (local_name, imported_name) in bindings {
                        facts.imports.append(
                            _SymbolImportFact(path, local_name, target_path, imported_name, line)
                        );
                    }
                }
                continue;
            }

            if `node.type != "import_statement" {
                continue;
            }
            raw_module = _js_module_specifier(`node, source);
            if raw_module is None {
                continue;
            }
            target_path = _resolve_js_module_path(raw_module, path.parent);
            if target_path is None {
                continue;
            }
            target_path = _resolve_cached(target_path);
            for (imported_name, local_name) in _js_named_specifiers(
                `node, source, "import_specifier"
            ) {
                facts.imports.append(
                    _SymbolImportFact(
                        path, local_name, target_path, imported_name, `node.start_point[0] + 1
                    ),
                );
            }
            default_local: any = _js_default_import_name(`node, source);
            if default_local is not None {
                facts.imports.append(
                    _SymbolImportFact(
                        path, default_local, target_path, "default", `node.start_point[0] + 1
                    ),
                );
            }
            namespace_local: any = _js_namespace_import_name(`node, source);
            if namespace_local is not None {
                facts.imports.append(
                    _SymbolImportFact(
                        path, namespace_local, target_path, "*", `node.start_point[0] + 1
                    ),
                );
            }
            for child in typing.cast(object, `node).children {
                if child.type != "import_require_clause" {
                    continue;
                }
                local_node: any = next((c for c in typing.cast(object, child).children if c.type == "identifier"), None);
                if local_node is None {
                    continue;
                }
                local_name = _read_text(local_node, source);
                if local_name {
                    facts.imports.append(
                        _SymbolImportFact(
                            path, local_name, target_path, "*", `node.start_point[0] + 1
                        ),
                    );
                    facts.imports.append(
                        _SymbolImportFact(
                            path, local_name, target_path, "default", `node.start_point[0] + 1
                        ),
                    );
                }
            }
        }

        for `node in indexed {
            for (alias, target) in _js_lexical_aliases(`node, source) {
                facts.aliases.append(
                    _SymbolAliasFact(path, alias, target, `node.start_point[0] + 1)
                );
            }
        }

        for `node in indexed {
            if `node.type != "export_statement" {
                continue;
            }

            raw_module = _js_module_specifier(`node, source);
            export_clause: any = _js_export_clause(`node);
            stmt_type_only: any = `any(
                operator.eq(child.type, "type") and not child.is_named for child in typing.cast(object, `node).children
            );
            if raw_module is not None {
                target_path = _resolve_js_module_path(raw_module, path.parent);
                if target_path is None {
                    continue;
                }
                target_path = _resolve_cached(target_path);
                namespace_name: any = _js_namespace_export_name(`node, source);
                if namespace_name is not None {
                    facts.namespace_exports.append(
                        _NamespaceExportFact(
                            path,
                            namespace_name,
                            target_path,
                            `node.start_point[0] + 1,
                            type_only=stmt_type_only,
                        ),
                    );
                } elif _js_export_statement_is_star(`node) {
                    facts.star_exports.append(
                        _StarExportFact(
                            path, target_path, `node.start_point[0] + 1, type_only=stmt_type_only
                        ),
                    );
                }
                if export_clause is not None {
                    exported_name: any;
                    for (original_name, exported_name) in _js_named_specifiers(
                        export_clause, source, "export_specifier"
                    ) {
                        facts.exports.append(
                            _SymbolExportFact(
                                path,
                                exported_name,
                                `node.start_point[0] + 1,
                                target_path=target_path,
                                target_name=original_name,
                                type_only=stmt_type_only,
                            ),
                        );
                    }
                }
                continue;
            }

            if export_clause is not None {
                for (local_name, exported_name) in _js_named_specifiers(
                    export_clause, source, "export_specifier"
                ) {
                    facts.exports.append(
                        _SymbolExportFact(
                            path, exported_name, `node.start_point[0] + 1, local_name=local_name
                        ),
                    );
                }
                continue;
            }

            for exported_name in _js_exported_declaration_names(`node, source) {
                facts.exports.append(
                    _SymbolExportFact(
                        path, exported_name, `node.start_point[0] + 1, local_name=exported_name
                    ),
                );
            }
            default_name: any = _js_default_export_name(`node, source);
            if default_name is not None {
                facts.exports.append(
                    _SymbolExportFact(
                        path, "default", `node.start_point[0] + 1, local_name=default_name
                    ),
                );
            }
        }

        for (source_id, body) in _js_top_level_function_bodies(path, root_node, source) {
            for `node in _walk_js_tree(body) {
                imported_name = _js_call_identifier(`node, source);
                if imported_name is None {
                    continue;
                }
                facts.uses.append(
                    _SymbolUseFact(
                        path, source_id, imported_name, "calls", "call", `node.start_point[0] + 1
                    ),
                );
            }
        }

        stem: any = _file_stem(path);
        for `node in indexed {
            if `node.type
                not in ("class_declaration", "abstract_class_declaration", "interface_declaration")
            {
                continue;
            }
            name_node: any = `node.child_by_field_name("name");
            if name_node is None {
                continue;
            }
            class_name: any = _read_text(name_node, source);
            if not class_name {
                continue;
            }
            class_nid: any = _make_id(stem, class_name);
            _ts_walk_class_members(`node, source, path, class_nid, member_facts);
        }
    }
    facts.uses.extend(member_facts.uses);
}

impl _parse_python_tree(path: Path) -> any {
    try {
        import tree_sitter_python as tspython;
        import from tree_sitter { Language, Parser }
        source: any = _read_source_bytes(path, warn=False);
        parser: any = Parser(Language(tspython.language()));
        return (source, parser.parse(source).root_node);
    } except Exception {
        return None;
    }
}

impl _walk_python_tree(`node) -> Generator[any, any, any] {
    stack = builtins.list((typing.cast(object, `node),));
    while stack {
        current = stack.pop();
        yield current;
        stack.extend(reversed(current.children));
    }
}

impl _python_import_from_module(`node, source: bytes) -> tuple[int, str] | None {
    level: any = 0;
    module_name: any = "";
    for child in typing.cast(object, `node).children {
        if child.type == "import" {
            break;
        }
        if child.type == "relative_import" {
            raw: any = _read_text(child, source);
            level = len(raw) - len(raw.lstrip("."));
            remainder: any = raw.lstrip(".");
            if remainder {
                module_name = remainder;
            }
            for sub in child.children {
                if sub.type == "dotted_name" {
                    module_name = _read_text(sub, source);
                }
            }
        } elif child.type == "dotted_name" {
            module_name = _read_text(child, source);
        }
    }
    if level == 0 and not module_name {
        return None;
    }
    return (level, module_name);
}

impl _python_imported_names(`node, source: bytes) -> list[tuple[str, str]] {
    names: list[tuple[str, str]] = [];
    past_import: any = False;
    for child in typing.cast(object, `node).children {
        if child.type == "import" {
            past_import = True;
            continue;
        }
        if not past_import {
            continue;
        }
        if child.type == "dotted_name" {
            name: any = _read_text(child, source);
            names.append((name, name.split(".")[0 if `node.type == "import_statement" else -1]));
        } elif child.type == "aliased_import" {
            name_node: any = child.child_by_field_name("name");
            alias_node: any = child.child_by_field_name("alias");
            if name_node is None {
                continue;
            }
            name = _read_text(name_node, source);
            local: any = _read_text(alias_node, source)
                if alias_node is not None
                else name.split(".")[-1];
            names.append((name, local));
        }
    }
    return names;
}

impl _is_python_package_dir(directory: Path, suffixes: tuple[str, ...] = (".py",)) -> bool {
    if `any(
        (directory / f"__init__{suffix}").is_file()
            and effective_suffix(directory / f"__init__{suffix}") in suffixes
        for suffix in suffixes,
    ) {
        return True;
    }
    return `any(
        (directory / f"__init__{suffix}").is_file()
        for suffix in _declared_language_suffixes(suffixes)
        if suffix not in suffixes,
    );
}

impl _probe_declared_python_module_candidate(candidate: Path) -> Path | None {
    for suffix in _declared_language_suffixes((".py",)) {
        init_path: any = candidate / f"__init__{suffix}";
        if init_path.is_file() {
            return init_path;
        }
        if candidate.name {
            module_path: any = candidate.with_suffix(suffix);
            if module_path.is_file() {
                return module_path;
            }
        }
    }
    return None;
}

impl _probe_python_module_candidate(candidate: Path) -> Path | None {
    if candidate.is_dir() {
        init_path: any = candidate / "__init__.py";
        if init_path.is_file() and effective_suffix(init_path) == ".py" {
            return init_path;
        }
    }
    if candidate.is_file() {
        return candidate;
    }
    if not candidate.name {
        return _probe_declared_python_module_candidate(candidate);
    }
    py_candidate: any = candidate.with_suffix(".py");
    if py_candidate.is_file() and effective_suffix(py_candidate) == ".py" {
        return py_candidate;
    }
    return _probe_declared_python_module_candidate(candidate);
}

impl _infer_scan_root_namespace(`root: Path) -> str {
    key: any = `str(_resolve_cached(`root));
    cached_ns: any = _SCAN_ROOT_NAMESPACE_CACHE.get(key);
    if cached_ns is not None {
        return cached_ns;
    }

    parts: list[str] = [];
    current: any = _resolve_cached(`root);
    parts.append(current.name);
    parent: any = current.parent;

    while parent != current {
        if not (parent / "__init__.py").is_file() {
            break;
        }
        parts.append(parent.name);
        current = parent;
        parent = parent.parent;
    }

    if len(parts) <= 1 {
        _SCAN_ROOT_NAMESPACE_CACHE[key] = "";
        return "";
    }

    parts.reverse();
    namespace: any = ".".join(parts);
    _SCAN_ROOT_NAMESPACE_CACHE[key] = namespace;
    return namespace;
}

impl _resolve_python_module_path(
    module_name: str, current_path: Path, `root: Path, level: int
) -> Path | None {
    stdlib_shadow: any;
    if level > 0 {
        base: any = current_path.parent;
        for _ in range(level - 1) {
            base = base.parent;
        }
        candidate: any = base / module_name.replace(".", "/") if module_name else base;
        return _probe_python_module_candidate(candidate);
    }
    rel: any = module_name.replace(".", "/");
    stdlib_shadow = module_name.split(".", 1)[0] in _PYTHON_STDLIB_MODULE_NAMES;

    def _accept(candidate: Path | None) -> Path | None {
        if candidate is not None
            and stdlib_shadow
            and candidate.name not in ("__init__.py", "__init__.pyi")
        {
            return None;
        }
        return candidate;
    }

    hit: any = _accept(_probe_python_module_candidate(`root / rel));
    if hit is not None {
        return hit;
    }
    ns: any = _infer_scan_root_namespace(`root);
    if ns and (module_name == ns or module_name.startswith(ns + ".")) {
        stripped: any = module_name[len(ns) + 1:] if module_name != ns else "";
        if stripped {
            hit = _accept(_probe_python_module_candidate(`root / stripped.replace(".", "/")));
            if hit is not None {
                return hit;
            }
        } else {
            hit = _accept(_probe_python_module_candidate(`root));
            if hit is not None {
                return hit;
            }
        }
    }

    for anc in current_path.parents {
        try {
            anc.relative_to(`root);
        } except ValueError {
            break;
        }
        if anc == `root {
            continue;
        }
        if _is_python_package_dir(anc) {
            continue;
        }
        cand: any = _accept(_probe_python_module_candidate(anc / rel));
        if cand is not None {
            return cand;
        }
    }
    return None;
}

impl _resolve_python_namespace_dir(
    module_name: str, current_path: Path, `root: Path, level: int
) -> "Path | None" {
    def _namespace(candidate: Path) -> "Path | None" {
        if not candidate.is_dir() or _is_python_package_dir(candidate) {
            return None;
        }
        try {
            _resolve_cached(candidate).relative_to(_resolve_cached(`root));
        } except ValueError {
            return None;
        }
        return candidate;
    }

    if level > 0 {
        base: any = current_path.parent;
        for _ in range(level - 1) {
            base = base.parent;
        }
        return _namespace(base / module_name.replace(".", "/") if module_name else base);
    }
    if not module_name {
        return None;
    }
    rel: any = module_name.replace(".", "/");
    hit: any = _namespace(`root / rel);
    if hit is not None {
        return hit;
    }
    ns: any = _infer_scan_root_namespace(`root);
    if ns and (module_name == ns or module_name.startswith(ns + ".")) {
        stripped: any = module_name[len(ns) + 1:] if module_name != ns else "";
        if stripped {
            hit = _namespace(`root / stripped.replace(".", "/"));
            if hit is not None {
                return hit;
            }
        } else {
            hit = _namespace(`root);
            if hit is not None {
                return hit;
            }
        }
    }
    for anc in current_path.parents {
        try {
            anc.relative_to(`root);
        } except ValueError {
            break;
        }
        if anc == `root or _is_python_package_dir(anc) {
            continue;
        }
        hit = _namespace(anc / rel);
        if hit is not None {
            return hit;
        }
    }
    return None;
}

impl _python_top_level_function_bodies(
    path: Path, root_node, source: bytes
) -> list[tuple[str, object]] {
    def definition(`node) -> any {
        if `node.type == "decorated_definition" {
            return `node.child_by_field_name("definition");
        }
        return `node;
    }

    bodies: list[tuple[str, object]] = [];
    stem: any = _file_stem(path);
    for top in typing.cast(object, root_node).children {
        `node: any = definition(top);
        if `node is None {
            continue;
        }
        name_node: any = `node.child_by_field_name("name");
        body: any = `node.child_by_field_name("body");
        if name_node is None or body is None {
            continue;
        }
        name: any = _read_text(name_node, source);
        if `node.type == "function_definition" {
            bodies.append((_make_id(stem, name), body));
        } elif `node.type == "class_definition" {
            for member in typing.cast(object, body).children {
                method: any = definition(member);
                if method is None or method.type != "function_definition" {
                    continue;
                }
                method_name: any = method.child_by_field_name("name");
                method_body: any = method.child_by_field_name("body");
                if method_name is not None and method_body is not None {
                    bodies.append((
                        _make_id(stem, name, _read_text(method_name, source)),
                        method_body,
                    ));
                }
            }
        }
    }
    return bodies;
}

impl _python_call_identifier(`node, source: bytes) -> str | None {
    n = typing.cast(object, `node);
    if n.type != "call" {
        return None;
    }
    function_node = n.child_by_field_name("function");
    if function_node is not None and function_node.type == "identifier" {
        return _read_text(function_node, source);
    }
    return None;
}

impl _collect_python_symbol_resolution_facts(
    paths: list[Path],
    `root: Path,
    facts: _SymbolResolutionFacts,
    ambiguous_python_modules: set[str] | None = None,
    raw_calls: list[dict] | None = None,
) {
    path: any;
    site: any;
    ambiguous_python_modules = ambiguous_python_modules or set[any]();
    py_paths: any = [path for path in paths if effective_suffix(path) == ".py"];
    if not py_paths {
        return;
    }

    calls_by_file: dict[Path, list[dict]] = {};
    call: any;
    for call in raw_calls or [] {
        source_file: any = call.get("source_file");
        if source_file and not call.get("is_member_call") and not call.get("indirect") {
            calls_by_file.setdefault(_resolve_cached(source_file), []).append(call);
        }
    }
    for path in py_paths {
        parsed: any = _parse_python_tree(path);
        if parsed is None {
            continue;
        }
        source: any;
        root_node: any;
        (source, root_node) = parsed as any;
        imported_names: dict[str, tuple[str, str, str | None]] = {};
        local_import_scopes: dict[str, list[tuple[int, int]]] = {};

        `node: any;
        for `node in _walk_python_tree(root_node) {
            ntype = typing.cast(object, `node).type;
            if ntype in ("import_statement", "import_from_statement") {
                scope: any = `node.parent;
                while scope is not None
                    and scope.type
                        not in ("module", "function_definition", "class_definition", "lambda")
                {
                    scope = scope.parent;
                }
                if scope is not None and scope.type == "function_definition" {
                    local: any;
                    for (_, local) in _python_imported_names(`node, source) {
                        local_import_scopes.setdefault(local, []).append((
                            scope.start_byte,
                            scope.end_byte,
                        ));
                    }
                }
            }
            if ntype != "import_from_statement" {
                continue;
            }
            module: any = _python_import_from_module(`node, source);
            if module is None {
                continue;
            }
            level: any;
            module_name: any;
            (level, module_name) = module as any;
            if level == 0 and _make_id(module_name) in ambiguous_python_modules {
                continue;
            }
            target_path: any = _resolve_python_module_path(module_name, path, `root, level);
            if `node.parent is not None and `node.parent.type == "module" {
                for (imported, local) in _python_imported_names(`node, source) {
                    imported_names[local] = (
                        imported,
                        module_name if level == 0 else "",
                        `str(target_path) if target_path is not None else None,
                    );
                }
            }
            if target_path is not None {
                pkg_dir: any = target_path.parent
                    if target_path.stem == "__init__" and effective_suffix(target_path) == ".py"
                    else None;
            } else {
                pkg_dir = _resolve_python_namespace_dir(module_name, path, `root, level);
                if pkg_dir is None {
                    continue;
                }
            }
            imported_name: any;
            for (imported_name, local_name) in _python_imported_names(`node, source) {
                line: any = `node.start_point[0] + 1;
                if pkg_dir is not None {
                    sub_py: any = pkg_dir / f"{imported_name}.py";
                    sub_pkg: any = pkg_dir / imported_name / "__init__.py";
                    submodule: any = sub_py
                        if sub_py.is_file()
                        else sub_pkg if sub_pkg.is_file() else None;
                    if submodule is None {
                        submodule = _probe_declared_python_module_candidate(
                            pkg_dir / imported_name
                        );
                    }
                    if submodule is not None {
                        imported_module: any = f"{module_name}.{imported_name}"
                            if module_name
                            else imported_name;
                        if level == 0 and _make_id(imported_module) in ambiguous_python_modules {
                            continue;
                        }
                        facts.module_imports.append((path, submodule, line, local_name));
                        continue;
                    }
                }
                if target_path is None {
                    continue;
                }
                facts.imports.append(
                    _SymbolImportFact(path, local_name, target_path, imported_name, line)
                );
                if path.stem == "__init__" {
                    facts.exports.append(
                        _SymbolExportFact(
                            path,
                            local_name,
                            line,
                            target_path=target_path,
                            target_name=imported_name,
                        ),
                    );
                }
            }
        }
        if _resolve_cached(path).is_relative_to(_resolve_cached(`root)) {
            for call in calls_by_file.get(_resolve_cached(path), []) {
                if call.get("callee") in imported_names {
                    scopes: any = local_import_scopes.get(call["callee"], ());
                    site = call.get("_python_call_site");
                    if scopes
                        and (
                            not site
                            or `any(start <= site[0] and site[0] < end for (start, end) in scopes)
                        )
                    {
                        continue;
                    }
                    call["_python_import_binding"] = imported_names[call["callee"]];
                }
            }
        }

        param_shadowed: any = _python_param_shadow_checker(source);
        for (source_id, body) in _python_top_level_function_bodies(path, root_node, source) {
            for `node in _walk_python_tree(body) {
                imported_name = _python_call_identifier(`node, source);
                if imported_name is None {
                    continue;
                }
                if param_shadowed(`node, imported_name) {
                    continue;
                }
                facts.uses.append(
                    _SymbolUseFact(
                        path, source_id, imported_name, "calls", "call", `node.start_point[0] + 1
                    ),
                );
            }
        }
    }
}

impl _augment_symbol_resolution_edges(
    paths: list[Path],
    nodes: list[dict],
    edges: list[dict],
    `root: Path,
    ambiguous_python_modules: set[str] | None = None,
    resolution_context_nodes: list[dict] | None = None,
    raw_calls: list[dict] | None = None,
) {
    facts: any = _SymbolResolutionFacts();
    _collect_js_symbol_resolution_facts(paths, facts);
    _collect_python_symbol_resolution_facts(
        paths, `root, facts, ambiguous_python_modules=ambiguous_python_modules, raw_calls=raw_calls
    );
    if resolution_context_nodes {
        _apply_symbol_resolution_facts(
            paths,
            nodes,
            edges,
            `root,
            facts,
            resolution_context_nodes=resolution_context_nodes,
            raw_calls=raw_calls,
        );
    } elif raw_calls {
        _apply_symbol_resolution_facts(paths, nodes, edges, `root, facts, raw_calls=raw_calls);
    } else {
        _apply_symbol_resolution_facts(paths, nodes, edges, `root, facts);
    }
}

impl _resolve_cross_file_imports(
    per_file: list[dict],
    paths: list[Path],
    all_nodes: list[dict] | None = None,
    all_edges: list[dict] | None = None,
    ambiguous_python_modules: set[str] | None = None,
) -> list[dict] {
    stem_to_entities: dict[str, dict[str, str]];
    bare_to_qualified: dict[str, str];
    edges_by_source: dict[object, list[tuple[int, dict]]];
    path: any;
    own_stems: any;
    name_to_nid: dict[str, str];
    n: any;
    source: any;
    import_targets: dict[str, str];
    ref_sources: dict[str, dict[str, int]];
    try {
        import tree_sitter_python;
    } except ImportError {
        return [];
    }
    ambiguous_python_modules = ambiguous_python_modules or set[any]();
    stem_to_entities = {};
    bare_to_qualified = {};
    file_result: any;
    for file_result in per_file {
        for `node in file_result.get("nodes", []) {
            src: any = `node.get("source_file", "");
            if not src {
                continue;
            }
            src_path: any = Path(src);
            fq_stem: any = _file_stem(src_path);
            label: any = `node.get("label", "");
            nid: any = `node.get("id", "");
            if label
                and not label.endswith((")", ".py"))
                and "_" not in label[:1]
                and `node.get("file_type") != "rationale"
            {
                stem_to_entities.setdefault(fq_stem, {})[label] = nid;
                if src_path.stem not in bare_to_qualified {
                    bare_to_qualified[src_path.stem] = fq_stem;
                }
            }
        }
    }
    new_edges: list[dict] = [];
    node_by_id: any = {`node["id"]: `node for `node in all_nodes if `node.get("id")}
        if all_nodes
        else {};
    repointed_from: set[str] = set[any]();
    TYPE_REPOINT_RELATIONS: any = frozenset({"references", "inherits", "implements", "extends"});
    edges_by_source = {};
    edges_indexed: any = False;

    for item_ in zip(per_file, paths) {
        (file_result, path) = item_;
        str_path: any = `str(path);
        file_srcs: any = {
            n.get("source_file")
            for n in file_result.get("nodes", [])
            if n.get("source_file")
        };
        file_srcs.add(str_path);
        file_srcs.add(path.as_posix());
        own_stems = {_file_stem(Path(s)) for s in file_srcs};
        name_to_nid = {};
        for n in file_result.get("nodes", []) {
            if n.get("source_file") != str_path or n.get("file_type") == "rationale" {
                continue;
            }
            label = n.get("label", "");
            if not label or label.endswith(".py") {
                continue;
            }
            sym_name: any = label[:-2] if label.endswith("()") else label;
            if sym_name and sym_name not in name_to_nid {
                name_to_nid[sym_name] = n["id"];
            }
        }
        if not name_to_nid {
            continue;
        }
        parsed: any = _parse_python_tree(path);
        if parsed is None {
            continue;
        }
        root_node: any;
        (source, root_node) = parsed as any;
        import_targets = {};
        ref_sources = {};

        def _text(n) -> str {
            tn = typing.cast(object, n);
            return typing.cast(object, source)[tn.start_byte:tn.end_byte].decode(
                "utf-8", errors="replace"
            );
        }

        def resolve_import(`node) {
            target_fq: str | None = None;
            absolute_module: str | None = None;
            child: any;
            for child in typing.cast(object, `node).children {
                if child.type == "relative_import" {
                    prefix_text: any = "";
                    dotted_text: any = "";
                    for sub in typing.cast(object, child).children {
                        if sub.type == "import_prefix" {
                            prefix_text = _text(sub);
                        } elif sub.type == "dotted_name" {
                            dotted_text = _text(sub);
                        }
                    }
                    dots: any = prefix_text.count(".") if prefix_text else 1;
                    cur_dir: any = path.parent;
                    for _ in range(dots - 1) {
                        cur_dir = cur_dir.parent;
                    }
                    if dotted_text {
                        candidate: any = cur_dir.joinpath(*dotted_text.split(".")).with_suffix(
                            ".py"
                        );
                    } else {
                        candidate = cur_dir / "__init__.py";
                    }
                    target_fq = _file_stem(candidate);
                    break;
                }
                if child.type == "dotted_name" and target_fq is None {
                    dotted_name: any = _text(child);
                    absolute_module = dotted_name;
                    if _make_id(dotted_name) in ambiguous_python_modules {
                        return;
                    }
                    dotted_as_path: any = "/".join(dotted_name.split("."));
                    if dotted_as_path in stem_to_entities {
                        target_fq = dotted_as_path;
                    } else {
                        suffix_matches: any = [
                            fq
                            for fq in stem_to_entities
                            if fq.endswith(f"/{dotted_as_path}")
                                or fq.endswith(f"\\{dotted_as_path}")
                        ];
                        if len(suffix_matches) == 1 {
                            target_fq = suffix_matches[0];
                        } else {
                            bare: any = dotted_name.split(".")[-1];
                            target_fq = bare_to_qualified.get(bare);
                        }
                    }
                }
            }

            if not target_fq or target_fq not in stem_to_entities {
                return;
            }
            if target_fq in own_stems {
                return;
            }
            past_import_kw: any = False;
            for child in typing.cast(object, `node).children {
                if child.type == "import" {
                    past_import_kw = True;
                    continue;
                }
                if not past_import_kw {
                    continue;
                }
                imported_name: str | None = None;
                local_name: str | None = None;
                if child.type == "dotted_name" {
                    value_: any = _text(child);
                    imported_name = value_;
                    local_name = value_;
                } elif child.type == "aliased_import" {
                    name_node: any = child.child_by_field_name("name");
                    alias_node: any = child.child_by_field_name("alias");
                    if name_node is not None {
                        imported_name = _text(name_node);
                        local_name = _text(alias_node) if alias_node is not None else imported_name;
                    }
                }
                if not imported_name or not local_name {
                    continue;
                }
                if absolute_module is not None
                    and _make_id(f"{absolute_module}.{imported_name}") in ambiguous_python_modules
                {
                    continue;
                }
                tgt_nid: any = stem_to_entities[target_fq].get(imported_name);
                if tgt_nid {
                    import_targets[local_name] = tgt_nid;
                }
            }
        }

        def `visit(`node, current_nid: str | None) {
            vnode = typing.cast(object, `node);
            vtype = vnode.type;
            if vtype == "import_from_statement" {
                resolve_import(`node);
                return;
            }
            if current_nid is None and vtype in ("class_definition", "function_definition") {
                name_node = vnode.child_by_field_name("name");
                if name_node is not None {
                    mapped: any = name_to_nid.get(_text(name_node));
                    if mapped is not None {
                        current_nid = mapped;
                    }
                }
            }
            if vtype == "identifier" and current_nid is not None {
                slot: any = ref_sources.setdefault(_text(`node), {});
                slot.setdefault(current_nid, vnode.start_point[0] + 1);
            }
            for child in typing.cast(object, vnode).children {
                `visit(child, current_nid);
            }
        }

        `visit(root_node, None);

        for (name, tgt_nid) in import_targets.items() {
            for (src_nid, line) in ref_sources.get(name, {}).items() {
                if src_nid == tgt_nid {
                    continue;
                }
                new_edges.append({
                    "source": src_nid,
                    "target": tgt_nid,
                    "relation": "uses",
                    "confidence": "INFERRED",
                    "confidence_score": 0.95,
                    "source_file": str_path,
                    "source_location": f"L{line}",
                    "weight": 0.8,
                });
            }
        }
        if all_edges and import_targets {
            if not edges_indexed {
                `edge: any;
                for (position, `edge) in enumerate(all_edges) {
                    edges_by_source.setdefault(`edge.get("source_file"), []).append((
                        position,
                        `edge,
                    ));
                }
                edges_indexed = True;
            }
            file_edges: any = sorted(
                (`entry for src in file_srcs for `entry in edges_by_source.get(src, ())),
                key=lambda (`entry) -> any { `entry[0] },
            );
            for (_, `edge) in file_edges {
                if `edge.get("relation") not in TYPE_REPOINT_RELATIONS {
                    continue;
                }
                tgt: any = `edge.get("target");
                tgt_node: any = node_by_id.get(tgt);
                if not tgt_node or tgt_node.get("source_file") {
                    continue;
                }
                stub_label: any = tgt_node.get("label", "");
                resolved_id: any = import_targets.get(stub_label);
                if resolved_id and resolved_id != tgt {
                    `edge["target"] = resolved_id;
                    repointed_from.add(tgt);
                }
            }
        }
    }

    if all_nodes is not None and all_edges is not None and repointed_from {
        still_referenced: any = {e.get("source") for e in all_edges} | {
            e.get("target")
            for e in all_edges
        };
        all_nodes[:] = [
            `node
            for `node in all_nodes
            if `node.get("id") not in repointed_from or `node.get("id") in still_referenced
        ];
    }

    return new_edges;
}

impl _cpp_source_key(source_file: str | Path, `root: Path) -> str {
    if not source_file {
        return "";
    }
    try {
        path: any = (`root / source_file).resolve();
        try {
            return os.path.relpath(path, `root.resolve()).replace("\\", "/");
        } except ValueError {
            return path.as_posix();
        }
    } except (OSError, RuntimeError, ValueError) {
        return "";
    }
}

impl _cpp_reconciliation_paths(
    paths: list[Path],
    nodes: list[dict],
    `root: Path,
    available_paths: list[Path] | None = None,
    changed_paths: list[Path] | None = None,
) -> list[Path] {
    selected: any;
    group: any;
    groups: any = [`set(n["_cpp_reconcile_files"]) for n in nodes if n.get("_cpp_reconcile_files")];
    if not groups {
        return paths;
    }
    selected = {_cpp_source_key(p, `root) for p in [*paths, *(changed_paths or [])]} - {""};
    if not `any(group & selected for group in groups) {
        return paths;
    }
    available: any = available_paths
        if available_paths is not None
        else [*paths, *(Path(n["source_file"]) for n in nodes if n.get("source_file"))];
    allowed: any = {_cpp_source_key(p, `root) for p in available} - {""};
    changed: any = True;
    while changed {
        changed = False;
        for group in groups {
            if group & selected {
                additions: any = (group & allowed) - selected;
                selected.update(additions);
                changed = changed or `bool(additions);
            }
        }
    }
    original: any = {_cpp_source_key(p, `root) for p in paths};
    return paths + [
        `root / sf
        for sf in sorted((selected & allowed) - original)
        if (`root / sf).is_file()
    ];
}

impl _cpp_exact_includes(
    resolution_nodes: list[dict], edges: list[dict], `root: Path
) -> dict[str, set[str]] {
    by_id: any = {n["id"]: n for n in resolution_nodes};
    includes: dict[str, set[str]] = {};
    for `edge in edges {
        if `edge.get("relation") != "imports"
            or not `edge.get("_cpp_include_proof")
            or (`edge.get("metadata") or {}).get("cpp_conditions")
        {
            continue;
        }
        source: any = _cpp_source_key(`edge.get("source_file", ""), `root);
        target_file: any = `edge.get("target_file")
            or by_id.get(`edge.get("target"), {}).get("source_file");
        if source and target_file {
            target: any = _cpp_source_key(target_file, `root);
            if target {
                includes.setdefault(source, set[any]()).add(target);
            }
        }
    }

    return includes;
}

impl _cpp_include_path(includes: dict[str, set[str]], start: str, target: str) -> list[str] {
    if not start or not target {
        return [];
    }
    pending: any = [(start, [start])];
    visited: any = {start};
    for (current, path) in pending {
        if current == target {
            return path;
        }
        for following in sorted(includes.get(current, ())) {
            if following not in visited {
                visited.add(following);
                pending.append((following, [*path, following]));
            }
        }
    }
    return [];
}

impl _merge_cpp_forward_classes(
    nodes: list[dict],
    edges: list[dict],
    raw_calls: list[dict],
    resolution_nodes: list[dict],
    context_edges: list[dict],
    `root: Path,
) {
    includes: any = _cpp_exact_includes(resolution_nodes, [*edges, *context_edges], `root);

    groups: dict[str, list[dict]] = {};
    for `node in resolution_nodes {
        qualified: any = `node.get("_cpp_qualified");
        if `node.get("_callable_class") and qualified {
            groups.setdefault(qualified, []).append(`node);
        }
    }
    remap: any = {};
    fresh_objects: any = {id(n) for n in nodes};
    for group in groups.values() {
        if `any(
            n.get("_cpp_class_kind") not in {"forward", "definition"}
                or (n.get("metadata") or {}).get("cpp_conditions")
            for n in group,
        ) {
            continue;
        }
        definitions: any = [n for n in group if n["_cpp_class_kind"] == "definition"];
        if len(definitions) != 1 {
            continue;
        }
        keeper: any = definitions[0];
        if id(keeper) not in fresh_objects {
            continue;
        }
        definition_file: any = _cpp_source_key(keeper["source_file"], `root);
        sites: any = [];
        proof_files: any = {definition_file};
        for declaration in group {
            if declaration["_cpp_class_kind"] != "forward" {
                continue;
            }
            declaration_file: any = _cpp_source_key(declaration["source_file"], `root);
            path: any = _cpp_include_path(includes, definition_file, declaration_file)
                or _cpp_include_path(includes, declaration_file, definition_file);
            if not path {
                continue;
            }
            remap[declaration["id"]] = keeper["id"];
            sites.append({
                "source_file": declaration_file,
                "source_location": declaration.get("source_location", ""),
            });
            proof_files.update(path);
        }
        if sites {
            keeper.setdefault("metadata", {})["cpp_declaration_sites"] = sorted(
                sites, key=lambda (site) -> any { (site["source_file"], site["source_location"]) }
            );
            keeper["_cpp_reconcile_files"] = sorted(proof_files);
        }
    }
    if remap {
        nodes[:] = [n for n in nodes if n["id"] not in remap];
        for `edge in edges {
            for endpoint in ("source", "target") {
                `edge[endpoint] = remap.get(`edge.get(endpoint), `edge.get(endpoint));
            }
        }
        for call in raw_calls {
            call["caller_nid"] = remap.get(call.get("caller_nid"), call.get("caller_nid"));
        }
    }
}

impl _merge_cpp_member_declarations(
    nodes: list[dict],
    edges: list[dict],
    raw_calls: list[dict],
    resolution_nodes: list[dict],
    context_edges: list[dict],
    `root: Path,
) {
    includes: any = _cpp_exact_includes(resolution_nodes, [*edges, *context_edges], `root);
    owners: dict[str, list[dict]] = {};
    members: dict[str, list[dict]] = {};
    for `node in resolution_nodes {
        if `node.get("_callable_class") and `node.get("_cpp_qualified") {
            owners.setdefault(`node["_cpp_qualified"], []).append(`node);
        }
        for record in `node.get("_cpp_member_records", []) {
            members.setdefault(record["qualified"], []).append(`node);
        }
    }
    owned: any = {
        (e.get("source"), e.get("target"))
        for e in [*edges, *context_edges]
        if e.get("relation") == "method"
    };
    fresh_objects: any = {id(n) for n in nodes};
    remap: any = {};
    merged_owners: any = {};
    for (qualified, group) in members.items() {
        if "::" not in qualified or len(group) != 2 {
            continue;
        }
        scope: any;
        name: any;
        (scope, name) = qualified.rsplit("::", 1) as any;
        classes: any = owners.get(scope, []);
        definitions: any = [c for c in classes if c.get("_cpp_class_kind") == "definition"];
        if len(definitions) != 1
            or `any(c.get("_cpp_class_kind") not in {"forward", "definition"} for c in classes)
        {
            continue;
        }
        owner: any = definitions[0];
        if `any(
            operator.ne(len(n["_cpp_member_records"]), 1)
                or not n["_cpp_member_records"][0].get("signature")
                or (n.get("metadata") or {}).get("cpp_conditions")
            for n in group,
        ) {
            continue;
        }
        declarations: any = [
            n
            for n in group
            if n["_cpp_member_records"][0]["kind"] == "declaration"
        ];
        definitions = [n for n in group if n["_cpp_member_records"][0]["kind"] == "definition"];
        if len(declarations) != 1 or len(definitions) != 1 {
            continue;
        }
        declaration: any;
        definition: any;
        (declaration, definition) = (declarations[0], definitions[0]);
        if id(declaration) not in fresh_objects
            or id(definition) not in fresh_objects
            or (owner["id"], declaration["id"]) not in owned
            or declaration["_cpp_member_records"][0]["signature"]
                != definition["_cpp_member_records"][0]["signature"]
        {
            continue;
        }
        declaration_file: any = _cpp_source_key(declaration["source_file"], `root);
        definition_file: any = _cpp_source_key(definition["source_file"], `root);
        path: any = _cpp_include_path(includes, definition_file, declaration_file);
        if not path {
            continue;
        }
        remap[definition["id"]] = declaration["id"];
        merged_owners[declaration["id"]] = owner["id"];
        declaration["definition_file"] = definition["source_file"];
        declaration["definition_location"] = definition.get("source_location", "");
        declaration["_cpp_reconcile_files"] = sorted(
            `set(path) | `set(owner.get("_cpp_reconcile_files", []))
        );
    }
    if remap {
        by_id: any = {n["id"]: n for n in resolution_nodes};
        member_names: dict[str | None, set[str]] = {};
        owner_id: any;
        for (owner_id, member_id) in owned {
            label: any = by_id.get(member_id, {}).get("label", "");
            if label.startswith(".") and label.endswith("()") {
                member_names.setdefault(owner_id, set[any]()).add(label[1:-2]);
            }
        }
        nodes[:] = [n for n in nodes if n["id"] not in remap];
        for `edge in edges {
            for endpoint in ("source", "target") {
                `edge[endpoint] = remap.get(`edge.get(endpoint), `edge.get(endpoint));
            }
        }
        for call in raw_calls {
            for key in ("caller_nid", "evidence_owner") {
                if key in call {
                    call[key] = remap.get(call[key], call[key]);
                }
            }
            owner_id = merged_owners.get(call.get("caller_nid"));
            if owner_id
                and not call.get("is_member_call")
                and call.get("callee") in member_names.get(owner_id, ())
            {
                call["is_member_call"] = True;
                call["receiver"] = "this";
            }
        }
    }
}

impl _decldef_class_stem(source_file: str) -> tuple[str, str] | None {
    if not source_file {
        return None;
    }
    p: any = Path(source_file);
    suffix: any = p.suffix.lower();
    if suffix not in _DECLDEF_HEADER_SUFFIXES and suffix not in _DECLDEF_IMPL_SUFFIXES {
        return None;
    }
    stem: any = p.stem.split("+", 1)[0];
    if not stem {
        return None;
    }
    return (`str(p.parent), stem);
}

impl _source_stem(`node: dict) -> str {
    return Path(`str(`node.get("source_file", ""))).stem;
}

impl _merge_decl_def_classes(all_nodes: list[dict], all_edges: list[dict]) {
    keeper: any;
    e: any;
    by_id: dict[str, list[dict]] = {};
    for n in all_nodes {
        if n.get("file_type") != "code" {
            continue;
        }
        nid: any = n.get("id");
        sf: any = `str(n.get("source_file", ""));
        if not isinstance(nid, `str) or not nid or not sf {
            continue;
        }
        by_id.setdefault(nid, []).append(n);
    }
    cpp_separate: set[str | None] = {
        nid
        for (nid, group) in by_id.items()
        if sum("_cpp_class_kind" in n for n in group) > 1
    };
    while cpp_separate {
        children: any = {
            e.get("target")
            for e in all_edges
            if e.get("source") in cpp_separate
                and e.get("relation") in {"method", "defines", "contains"}
        };
        if children <= cpp_separate {
            break;
        }
        cpp_separate.update(children);
    }
    drop_objs: set[int] = set[any]();
    for (nid, group) in by_id.items() {
        if len(group) < 2 {
            continue;
        }
        if nid in cpp_separate {
            continue;
        }
        if `any(
            record.get("zero_args") for n in group for record in n.get("_cpp_member_records", [])
        ) {
            continue;
        }
        sibling_keys: set[tuple[str, str]] = set[any]();
        headers: list[dict] = [];
        ok: any = True;
        `node: any;
        for `node in group {
            sf = `str(`node.get("source_file", ""));
            ds: any = _decldef_class_stem(sf);
            if ds is None {
                ok = False;
                break;
            }
            sibling_keys.add(ds);
            if Path(sf).suffix.lower() in _DECLDEF_HEADER_SUFFIXES {
                headers.append(`node);
            }
        }
        if not ok {
            continue;
        }
        if len(sibling_keys) != 1 or not headers {
            continue;
        }
        if len(headers) == 1 {
            keeper = headers[0];
        } else {
            base_headers: any = [h for h in headers if "+" not in _source_stem(h)];
            if len(base_headers) > 1 {
                continue;
            }
            keeper = base_headers[0] if base_headers else min(headers, key=_source_stem);
        }
        impls: any = sorted(
            (n
            for n in group
            if n is not keeper
                and Path(`str(n.get("source_file", ""))).suffix.lower() in _DECLDEF_IMPL_SUFFIXES),
            key=lambda (n) -> any {
                (`str(n.get("source_file", "")), `str(n.get("source_location", "")))
            },
        );
        if impls {
            definition: any = impls[0];
            if definition.get("source_file") {
                keeper["definition_file"] = definition["source_file"];
            }
            if definition.get("source_location") {
                keeper["definition_location"] = definition["source_location"];
            }
        }

        for `node in group {
            if `node is not keeper {
                drop_objs.add(id(`node));
            }
        }
    }

    if not drop_objs {
        return;
    }
    all_nodes[:] = [n for n in all_nodes if id(n) not in drop_objs];

    seen_keys: set[tuple] = set[any]();
    rewritten: list[dict] = [];
    for e in all_edges {
        src: any = e.get("source");
        tgt: any = e.get("target");
        if src == tgt {
            continue;
        }
        k: any = (src, tgt, e.get("relation"), e.get("context"));
        if e.get("relation") == "calls" {
            k += (e.get("source_file"), e.get("source_location"));
        }
        if k in seen_keys {
            continue;
        }
        seen_keys.add(k);
        rewritten.append(e);
    }
    all_edges[:] = rewritten;
}

impl _go_package_clause(path: Path) -> str | None {
    try {
        source: any = _read_source_bytes(path, warn=False);
    } except Exception {
        return None;
    }
    m: any = _GO_PACKAGE_RE.search(_GO_COMMENT_RE.sub(b" ", source));
    return m.group(1).decode("ascii") if m else None;
}

impl _merge_go_package_types(all_nodes: list[dict], all_edges: list[dict]) {
    by_id: dict[str, list[dict]] = {};
    n: any;
    for n in all_nodes {
        nid: any = n.get("id");
        label: any = `str(n.get("label", ""));
        if not isinstance(nid, `str) or not nid or n.get("file_type") != "code" {
            continue;
        }
        if not label or "." in label or "(" in label {
            continue;
        }
        if Path(`str(n.get("source_file", ""))).suffix.lower() != ".go" {
            continue;
        }
        by_id.setdefault(nid, []).append(n);
    }

    declaring_files: dict[str, set[str]] = {};
    e: any;
    for e in all_edges {
        if e.get("relation") == "contains" {
            declaring_files.setdefault(`str(e.get("target", "")), set[any]()).add(
                `str(e.get("source_file", ""))
            );
        }
    }

    drop_objs: set[int] = set[any]();
    for (nid, group) in by_id.items() {
        if len(group) < 2 {
            continue;
        }
        by_dir: dict[Path, list[dict]] = {};
        for n in group {
            by_dir.setdefault(Path(`str(n.get("source_file", ""))).parent, []).append(n);
        }
        for members in by_dir.values() {
            if len(members) < 2 {
                continue;
            }
            files: any = [Path(`str(n.get("source_file", ""))) for n in members];
            if `any(f.name.endswith("_test.go") for f in files) {
                clauses: any = {_go_package_clause(f) for f in files};
                if len(clauses) != 1 or None in clauses {
                    continue;
                }
            }
            declared: any = declaring_files.get(nid, set[any]());
            candidates: any = [n for n in members if `str(n.get("source_file", "")) in declared]
                or members;
            keeper: any = min(
                candidates,
                key=lambda (n) -> any {
                    (`str(n.get("source_file", "")), `str(n.get("source_location", "")))
                },
            );
            folded: any = keeper.setdefault("_go_folded_files", []);
            for `node in members {
                if `node is not keeper {
                    drop_objs.add(id(`node));
                    folded.append(`str(`node.get("source_file", "")));
                }
            }
        }
    }

    if drop_objs {
        all_nodes[:] = [n for n in all_nodes if id(n) not in drop_objs];
    }
    stub_renames: dict[tuple[str, str], str] = {};
    for n in all_nodes {
        nid = n.get("id");
        label = `str(n.get("label", ""));
        origin: any = `str(n.get("origin_file", ""));
        if nid in by_id
            and not n.get("source_file")
            and "." in label
            and Path(origin).suffix.lower() == ".go"
        {
            new_id: any = _make_id("go", "ref", label);
            stub_renames[nid, origin] = new_id;
            n["id"] = new_id;
        }
    }
    if stub_renames {
        for e in all_edges {
            renamed: any = stub_renames.get((
                `str(e.get("target", "")),
                `str(e.get("source_file", "")),
            ));
            if renamed {
                e["target"] = renamed;
            }
        }
    }
}

impl _resolve_cross_file_java_imports(per_file: list[dict], paths: list[Path]) -> list[dict] {
    try {
        import tree_sitter_java as tsjava;
        import from tree_sitter { Language, Parser }
    } except ImportError {
        return [];
    }

    language: any = Language(tsjava.language());
    parser: any = Parser(language);
    imports_by_path: dict[str, list[tuple[str, str, int]]] = {};
    pkg_by_src: dict[str, str] = {};
    path: any;
    file_result: any;
    for (path, file_result) in zip(paths, per_file) {
        try {
            source: any = _read_source_bytes(path, warn=False);
            tree: any = parser.parse(source);
        } except Exception {
            continue;
        }
        imports_by_path[`str(path)] = _java_import_rows(tree.root_node, source);
        pkg: any = "";
        for child in tree.root_node.children {
            if child.type == "package_declaration" {
                pkg = _read_text(child, source).strip()[len("package"):].strip().rstrip(
                    ";"
                ).strip();
                break;
            }
        }
        pkg_by_src[`str(path)] = pkg;
        `node: any;
        for `node in file_result.get("nodes", []) {
            src: any = `node.get("source_file");
            if src {
                pkg_by_src.setdefault(src, pkg);
            }
        }
    }

    def _pkg_matches(imp_pkg: str, tgt_pkg: str) -> bool {
        if imp_pkg == tgt_pkg {
            return True;
        }
        if tgt_pkg {
            if not imp_pkg.startswith(tgt_pkg + ".") {
                return False;
            }
            rest: any = imp_pkg[len(tgt_pkg) + 1:];
        } else {
            rest = imp_pkg;
        }
        return `bool(rest) and all(seg[:1].isupper() for seg in rest.split("."));
    }
    name_to_ids: dict[str, list[tuple[str, str]]] = {};
    for file_result in per_file {
        for `node in file_result.get("nodes", []) {
            label: any = `node.get("label", "");
            nid: any = `node.get("id", "");
            src = `node.get("source_file", "");
            if not label or not nid or not src {
                continue;
            }
            if label.endswith(")") or label.endswith(".java") {
                continue;
            }
            if not label[0].isalpha() or not label[0].isupper() {
                continue;
            }
            name_to_ids.setdefault(label, []).append((nid, pkg_by_src.get(src, "")));
        }
    }
    new_edges: list[dict] = [];
    seen_pairs: set[tuple[str, str]] = set[any]();
    for path in paths {
        file_nid: any = _make_id(`str(path));
        for (last, imp_pkg, at_line) in imports_by_path.get(`str(path), ()) {
            for (tgt_nid, tgt_pkg) in name_to_ids.get(last, []) {
                if tgt_nid == file_nid {
                    continue;
                }
                if not _pkg_matches(imp_pkg, tgt_pkg) {
                    continue;
                }
                key: any = (file_nid, tgt_nid);
                if key in seen_pairs {
                    continue;
                }
                seen_pairs.add(key);
                new_edges.append({
                    "source": file_nid,
                    "target": tgt_nid,
                    "relation": "imports",
                    "confidence": "EXTRACTED",
                    "confidence_score": 1.0,
                    "source_file": `str(path),
                    "source_location": f"L{at_line}",
                    "weight": 1.0,
                });
            }
        }
    }

    return new_edges;
}

impl _java_import_rows(root_node, source: bytes) -> list[tuple[str, str, int]] {
    rows: list[tuple[str, str, int]];
    rows = [];

    def walk(n) {
        if n.type == "import_declaration" {
            raw: any = _read_text(n, source).strip();
            body: any = raw[len("import"):].strip().rstrip(";").strip();
            if body.startswith("static ") {
                body = body[len("static "):].strip();
            }
            if body.endswith(".*") {
                return;
            }
            parts: any = body.split(".");
            last: any = parts[-1];
            imp_pkg: any = ".".join(parts[:-1]);
            if last and last[0].islower() and len(parts) >= 2 {
                last = parts[-2];
                imp_pkg = ".".join(parts[:-2]);
            }
            rows.append((last, imp_pkg, n.start_point[0] + 1));
        }
        for child in typing.cast(object, n).children {
            walk(child);
        }
    }

    walk(root_node);
    return rows;
}

impl _go_import_path_for_file(
    source_file: str | Path, `root: Path, module_cache: dict[Path, str | None] | None = None
) -> str | None {
    cache: any = module_cache if module_cache is not None else {};
    path: any = Path(source_file);
    if not path.is_absolute() {
        path = `root / path;
    }
    try {
        directory: any = _resolve_cached(path).parent;
    } except OSError {
        directory = path.absolute().parent;
    }

    module_dir: Path | None = None;
    module_path: str | None = None;
    for candidate in (directory, *directory.parents) {
        if candidate in cache {
            cached: any = cache[candidate];
            if cached {
                (module_dir, module_path) = (candidate, cached);
            }
            break;
        }
        go_mod: any = candidate / "go.mod";
        if not go_mod.is_file() {
            continue;
        }
        try {
            `match: any = re.search(
                "(?m)^\\s*module\\s+([^\\s]+)", go_mod.read_text(encoding="utf-8")
            );
        } except (OSError, UnicodeError) {
            `match = None;
        }
        module_dir = candidate;
        module_path = `match.group(1) if `match else None;
        cache[candidate] = module_path;
        break;
    }

    if not module_dir or not module_path {
        return None;
    }
    try {
        relative_dir: any = directory.relative_to(module_dir);
    } except ValueError {
        return None;
    }
    suffix: any = relative_dir.as_posix();
    return module_path if suffix == "." else f"{module_path}/{suffix}";
}

impl _resolve_go_type_references(
    per_file: list[dict],
    paths: list[Path],
    all_nodes: list[dict],
    all_edges: list[dict],
    `root: Path,
    resolution_context_nodes: list[dict] | None = None,
    resolution_context_edges: list[dict] | None = None,
) {
    node_ids: any;
    external_stub_ids: dict[str, str];
    new_nodes: list[dict];
    `edge: any;
    imports_by_file: dict[str, dict[str, str]] = {};
    actual_path_by_file: dict[str, Path] = {};
    for (path, result) in zip(paths, per_file) {
        imports: any = result.get("go_imports") or {};
        `node: any;
        for `node in result.get("nodes", []) {
            source_file: any = `node.get("source_file");
            if source_file {
                imports_by_file[`str(source_file)] = imports;
                actual_path_by_file[`str(source_file)] = path;
            }
        }
    }

    if not imports_by_file {
        return;
    }

    definition_nodes: any = all_nodes + (resolution_context_nodes or []);
    definition_edges: any = all_edges + (resolution_context_edges or []);
    contained: any = {
        `edge.get("target")
        for `edge in definition_edges
        if `edge.get("relation") == "contains"
    };
    module_cache: dict[Path, str | None] = {};
    fqn_to_ids: dict[str, list[str]] = {};
    for `node in definition_nodes {
        source_file = `str(`node.get("source_file") or "");
        label: any = `str(`node.get("label") or "");
        nid: any = `node.get("id");
        if not source_file
            or not label
            or not nid
            or nid not in contained
            or not _is_type_like_definition(`node)
        {
            continue;
        }
        actual_path: any = actual_path_by_file.get(source_file, Path(source_file));
        package_path: any = _go_import_path_for_file(actual_path, `root, module_cache);
        if package_path {
            fqn_to_ids.setdefault(f"{package_path}.{label}", []).append(nid);
        }
    }

    qualified_stubs: any = {
        `node["id"]: `str(`node.get("label") or "")
        for `node in all_nodes
        if `node.get("id")
            and not `node.get("source_file")
            and "." in `str(`node.get("label") or "")
    };
    if not qualified_stubs {
        return;
    }

    node_ids = {`node.get("id") for `node in all_nodes if `node.get("id")};
    external_stub_ids = {};
    new_nodes = [];

    def external_stub(fqn: str) -> str {
        existing: any = external_stub_ids.get(fqn);
        if existing {
            return existing;
        }
        nid: any = _make_id("go", "type", fqn);
        if nid not in node_ids {
            new_nodes.append({
                "id": nid,
                "label": fqn,
                "file_type": "code",
                "source_file": "",
                "source_location": "",
            });
            node_ids.add(nid);
        }
        external_stub_ids[fqn] = nid;
        return nid;
    }

    repointed_from: set[str] = set[any]();
    for `edge in all_edges {
        if `edge.get("relation") not in {"references", "embeds"} {
            continue;
        }
        target: any = `edge.get("target");
        qualified: any = qualified_stubs.get(target);
        if not qualified {
            continue;
        }
        alias: any;
        _: any;
        type_name: any;
        (alias, _, type_name) = qualified.rpartition(".") as any;
        import_path: any = imports_by_file.get(`str(`edge.get("source_file") or ""), {}).get(alias);
        if not import_path or not type_name {
            continue;
        }
        fqn: any = f"{import_path}.{type_name}";
        candidates: any = fqn_to_ids.get(fqn, []);
        `edge["target"] = candidates[0] if len(candidates) == 1 else external_stub(fqn);
        repointed_from.add(`str(target));
    }

    if new_nodes {
        all_nodes.extend(new_nodes);
    }

    if not repointed_from {
        return;
    }
    referenced: any = {
        endpoint
        for `edge in all_edges
        for endpoint in (`edge.get("source"), `edge.get("target"))
    };
    all_nodes[:] = [
        `node
        for `node in all_nodes
        if `node.get("id") not in repointed_from or `node.get("id") in referenced
    ];
}

impl _resolve_java_type_references(
    per_file: list[dict], paths: list[Path], all_nodes: list[dict], all_edges: list[dict]
) {
    source: any;
    pkg: any;
    imps: dict[str, str];
    `node: any;
    node_ids: any;
    external_stub_ids: dict[str, str];
    new_nodes: list[dict];
    try {
        import tree_sitter_java as tsjava;
        import from tree_sitter { Language, Parser }
    } except ImportError {
        return;
    }

    language: any = Language(tsjava.language());
    parser: any = Parser(language);
    pkg_by_file: dict[str, str] = {};
    imports_by_file: dict[str, dict[str, str]] = {};
    for (path, result) in zip(paths, per_file) {
        srcs: any = {n.get("source_file") for n in result.get("nodes", []) if n.get("source_file")};
        if not srcs {
            continue;
        }
        try {
            source = _read_source_bytes(path, warn=False);
            tree: any = parser.parse(source);
        } except Exception {
            continue;
        }
        pkg = "";
        imps = {};

        def walk(n) {
            if n.type == "package_declaration" {
                pkg = _read_text(n, source).strip()[len("package"):].strip().rstrip(";").strip();
            } elif n.type == "import_declaration" {
                body: any = _read_text(n, source).strip()[len("import"):].strip().rstrip(
                    ";"
                ).strip();
                if body.startswith("static ") {
                    body = body[len("static "):].strip();
                }
                if body.endswith(".*") or "." not in body {
                    return;
                }
                simple: any = body.split(".")[-1];
                if simple and simple[0].isupper() {
                    imps[simple] = body;
                }
            }
            for child in typing.cast(object, n).children {
                walk(child);
            }
        }

        walk(tree.root_node);
        for s in srcs {
            pkg_by_file[s] = pkg;
            imports_by_file[s] = imps;
        }
    }
    fqn_to_id: dict[str, str] = {};
    node_by_id: any = {`node.get("id"): `node for `node in all_nodes if `node.get("id")};
    type_parent_by_id: dict[str, str] = {};
    `edge: any;
    for `edge in all_edges {
        if `edge.get("relation") != "contains" {
            continue;
        }
        child: any = node_by_id.get(`edge.get("target"));
        parent: any = node_by_id.get(`edge.get("source"));
        if not child or not parent {
            continue;
        }
        child_src: any = child.get("source_file", "");
        parent_label: any = parent.get("label", "");
        if child_src
            and parent.get("source_file") == child_src
            and parent_label[:1].isupper()
            and not parent_label.endswith(".java")
        {
            type_parent_by_id[child["id"]] = parent["id"];
        }
    }

    for `node in all_nodes {
        label: any = `node.get("label", "");
        src: any = `node.get("source_file", "");
        nid: any = `node.get("id", "");
        if not (label and src and nid) or src not in pkg_by_file {
            continue;
        }
        if not label[:1].isupper() or label.endswith(")") or label.endswith(".java") {
            continue;
        }
        pkg = pkg_by_file[src];
        fqn_to_id.setdefault(f"{pkg}.{label}" if pkg else label, nid);
        type_path: any = [label];
        seen: any = {nid};
        parent_id: any = type_parent_by_id.get(nid);
        while parent_id and parent_id not in seen {
            seen.add(parent_id);
            parent = node_by_id[parent_id];
            type_path.append(parent["label"]);
            parent_id = type_parent_by_id.get(parent_id);
        }
        if len(type_path) > 1 {
            nested_name: any = ".".join(reversed(type_path));
            fqn_to_id.setdefault(f"{pkg}.{nested_name}" if pkg else nested_name, nid);
        }
    }
    stub_label: dict[str, str] = {
        `node["id"]: `node.get("label", "")
        for `node in all_nodes
        if `node.get("id")
            and not `node.get("source_file")
            and (`node.get("label", "")[:1].isupper() or "." in `node.get("label", ""))
    };
    if not stub_label {
        return;
    }
    REPOINT_RELATIONS: any = {"implements", "inherits", "extends", "imports", "references"};

    node_ids = {n.get("id") for n in all_nodes if n.get("id")};
    external_stub_ids = {};
    new_nodes = [];

    def _external_stub(fqn: str) -> str {
        nid: any = external_stub_ids.get(fqn);
        if nid {
            return nid;
        }
        nid = _make_id(fqn);
        if nid not in node_ids {
            new_nodes.append({
                "id": nid,
                "label": fqn,
                "file_type": "code",
                "source_file": "",
                "source_location": "",
            });
            node_ids.add(nid);
        }
        external_stub_ids[fqn] = nid;
        return nid;
    }

    repointed_from: set[str] = set[any]();
    for `edge in all_edges {
        if `edge.get("relation") not in REPOINT_RELATIONS {
            continue;
        }
        tgt: any = `edge.get("target");
        label = stub_label.get(tgt);
        if not label {
            continue;
        }
        ref_file: any = `edge.get("source_file", "");
        if "." in label {
            resolved: any = fqn_to_id.get(label);
            if resolved and resolved != tgt {
                `edge["target"] = resolved;
                repointed_from.add(tgt);
            }
            continue;
        }
        fqn: any = imports_by_file.get(ref_file, {}).get(label);
        if fqn {
            resolved = fqn_to_id.get(fqn);
            if resolved is None {
                head: any = fqn.split(".")[:-1];
                while resolved is None and head and head[-1][:1].isupper() {
                    head.pop();
                    resolved = fqn_to_id.get(".".join(head + [label]));
                }
            }
            if resolved is None {
                `edge["target"] = _external_stub(fqn);
                repointed_from.add(tgt);
                continue;
            }
        } else {
            pkg = pkg_by_file.get(ref_file, "");
            resolved = fqn_to_id.get(f"{pkg}.{label}" if pkg else label);
        }
        if resolved and resolved != tgt {
            `edge["target"] = resolved;
            repointed_from.add(tgt);
        }
    }

    if new_nodes {
        all_nodes.extend(new_nodes);
    }
    seen_attribute_refs: set[tuple] = set[any]();
    deduped_edges: list[dict] = [];
    for `edge in all_edges {
        if `edge.get("relation") == "references"
            and `edge.get("context") == "attribute"
            and `edge.get("source_file", "") in pkg_by_file
        {
            key: any = (
                `edge.get("source"),
                `edge.get("target"),
                `edge.get("relation"),
                `edge.get("context"),
                `edge.get("source_file"),
                `edge.get("source_location"),
            );
            if key in seen_attribute_refs {
                continue;
            }
            seen_attribute_refs.add(key);
        }
        deduped_edges.append(`edge);
    }
    all_edges[:] = deduped_edges;

    if not repointed_from {
        return;
    }
    still_referenced: set[str] = set[any]();
    for `edge in all_edges {
        still_referenced.add(`edge.get("source"));
        still_referenced.add(`edge.get("target"));
    }
    all_nodes[:] = [
        `node
        for `node in all_nodes
        if `node.get("id") not in repointed_from or `node.get("id") in still_referenced
    ];
}

impl _php_fqn_from_raw(raw: str, ns: str, uses: dict[str, str]) -> str {
    raw = raw.strip();
    if raw.startswith("\\") {
        return raw[1:];
    }
    if "\\" in raw {
        first: any;
        rest: any;
        (first, rest) = raw.split("\\", 1) as any;
        mapped: any = uses.get(first.lower());
        if mapped {
            return f"{mapped}\\{rest}";
        }
        return f"{ns}\\{raw}" if ns else raw;
    }
    mapped = uses.get(raw.lower());
    if mapped {
        return mapped;
    }
    return f"{ns}\\{raw}" if ns else raw;
}

impl _resolve_php_type_references(
    per_file: list[dict], paths: list[Path], all_nodes: list[dict], all_edges: list[dict]
) {
    source: any;
    namespaces: list[str];
    uses: dict[str, str];
    raws: dict[tuple[str, str], str | None];
    node_ids: any;
    external_stub_ids: dict[str, str];
    new_nodes: list[dict];
    tgt: any;
    try {
        import tree_sitter_php as tsphp;
        import from tree_sitter { Language, Parser }
    } except ImportError {
        return;
    }

    lang_fn: any = getattr(tsphp, "language_php", None) or getattr(tsphp, "language", None);
    if lang_fn is None {
        return;
    }
    language: any = Language(lang_fn());
    parser: any = Parser(language);

    ns_by_file: dict[str, str] = {};
    uses_by_file: dict[str, dict[str, str]] = {};
    raw_by_file: dict[str, dict[tuple[str, str], str | None]] = {};

    for (path, result) in zip(paths, per_file) {
        srcs: any = {n.get("source_file") for n in result.get("nodes", []) if n.get("source_file")};
        if not srcs {
            continue;
        }
        try {
            source = _read_source_bytes(path, warn=False);
            tree: any = parser.parse(source);
        } except Exception {
            continue;
        }

        namespaces = [];
        uses = {};
        raws = {};

        def _record_raw(relation: str, raw: str) {
            bare: any = raw.rsplit("\\", 1)[-1].strip().lower();
            if not bare {
                return;
            }
            key: any = (relation, bare);
            if key in raws and raws[key] != raw {
                raws[key] = None;
            } else {
                raws.setdefault(key, raw);
            }
        }

        def _record_use_clause(clause, prefix: str) {
            target: any = None;
            alias: any = None;
            saw_as: any = False;
            for c in typing.cast(object, clause).children {
                if c.type in ("function", "const") {
                    return;
                }
                if c.type == "as" {
                    saw_as = True;
                } elif c.type in ("qualified_name", "name") {
                    if saw_as {
                        alias = _read_text(c, source);
                    } elif target is None {
                        target = _read_text(c, source);
                    }
                }
            }
            if not target {
                return;
            }
            fqn: any = (f"{prefix}\\{target}" if prefix else target).lstrip("\\");
            key: any = (alias or fqn.rsplit("\\", 1)[-1]).strip().lower();
            if key {
                uses.setdefault(key, fqn);
            }
        }

        def walk(n) {
            t: any = n.type;
            if t == "namespace_definition" {
                c: any;
                for c in typing.cast(object, n).children {
                    if c.type == "namespace_name" {
                        namespaces.append(_read_text(c, source));
                        break;
                    }
                }
            } elif t == "namespace_use_declaration" {
                prefix: any = "";
                group: any = None;
                for c in typing.cast(object, n).children {
                    if c.type == "namespace_name" {
                        prefix = _read_text(c, source);
                    } elif c.type == "namespace_use_group" {
                        group = c;
                    } elif c.type == "namespace_use_clause" {
                        _record_use_clause(c, "");
                    }
                }
                if group is not None {
                    for c in typing.cast(object, group).children {
                        if c.type == "namespace_use_clause" {
                            _record_use_clause(c, prefix);
                        }
                    }
                }
                return;
            } elif t == "class_declaration" {
                child: any;
                for child in typing.cast(object, n).children {
                    if child.type == "base_clause" {
                        sub: any;
                        for sub in typing.cast(object, child).children {
                            if sub.type in ("name", "qualified_name") {
                                _record_raw("inherits", _read_text(sub, source));
                            }
                        }
                    } elif child.type == "class_interface_clause" {
                        for sub in typing.cast(object, child).children {
                            if sub.type in ("name", "qualified_name") {
                                _record_raw("implements", _read_text(sub, source));
                            }
                        }
                    } elif child.type == "declaration_list" {
                        for member in typing.cast(object, child).children {
                            if member.type != "use_declaration" {
                                continue;
                            }
                            for sub in member.children {
                                if sub.type in ("name", "qualified_name") {
                                    _record_raw("mixes_in", _read_text(sub, source));
                                }
                            }
                        }
                    }
                }
            }
            for child in typing.cast(object, n).children {
                walk(child);
            }
        }

        walk(tree.root_node);
        if len(`set(namespaces)) > 1 {
            continue;
        }
        ns: any = namespaces[0] if namespaces else "";
        for s in srcs {
            ns_by_file[s] = ns;
            uses_by_file[s] = uses;
            raw_by_file[s] = raws;
        }
    }

    if not ns_by_file {
        return;
    }
    fqn_to_id: dict[str, str] = {};
    for `node in all_nodes {
        label: any = `node.get("label", "");
        src: any = `node.get("source_file", "");
        nid: any = `node.get("id", "");
        if not (label and src and nid) or src not in ns_by_file {
            continue;
        }
        if label.endswith(")") or "." in label {
            continue;
        }
        ns = ns_by_file[src];
        fqn: any = f"{ns}\\{label}" if ns else label;
        fqn_to_id.setdefault(fqn.lower(), nid);
    }

    node_ids = {n.get("id") for n in all_nodes if n.get("id")};
    stub_label: dict[str, str] = {
        n["id"]: n.get("label", "")
        for n in all_nodes
        if n.get("id") and not n.get("source_file") and n.get("label")
    };

    external_stub_ids = {};
    new_nodes = [];

    def _external_stub(fqn: str) -> str {
        key: any = fqn.lower();
        nid: any = external_stub_ids.get(key);
        if nid {
            return nid;
        }
        nid = _make_id(fqn);
        if nid not in node_ids {
            new_nodes.append({
                "id": nid,
                "label": fqn,
                "file_type": "code",
                "source_file": "",
                "source_location": "",
            });
            node_ids.add(nid);
        }
        external_stub_ids[key] = nid;
        return nid;
    }

    repointed_from: set[str] = set[any]();
    `edge: any;
    for `edge in all_edges {
        relation: any = `edge.get("relation");
        if relation not in _PHP_REPOINT_RELATIONS {
            continue;
        }
        ref_file: any = `edge.get("source_file", "");
        if ref_file not in ns_by_file {
            continue;
        }
        tgt = `edge.get("target");
        label = stub_label.get(tgt);
        uses = uses_by_file.get(ref_file, {});
        if not label and relation == "imports" {
            label = next((alias for alias in uses if _make_id(alias) == tgt), "");
        }
        if not label {
            continue;
        }
        bare: any = label.strip().lower();
        ns = ns_by_file[ref_file];

        raw: any = None;
        if relation in _PHP_SUPERTYPE_RELATIONS {
            raw = raw_by_file.get(ref_file, {}).get((relation, bare));
        }

        explicit: any = False;
        if raw and "\\" in raw {
            fqn = _php_fqn_from_raw(raw, ns, uses);
            explicit = True;
        } elif bare in uses {
            fqn = uses[bare];
            explicit = True;
        } elif ns {
            fqn = f"{ns}\\{label}";
        } else {
            continue;
        }

        resolved: any = fqn_to_id.get(fqn.lower());
        if resolved and resolved != tgt {
            `edge["target"] = resolved;
            repointed_from.add(tgt);
        } elif explicit and resolved is None {
            `edge["target"] = _external_stub(fqn);
            repointed_from.add(tgt);
        }
    }

    if new_nodes {
        all_nodes.extend(new_nodes);
    }
    if not repointed_from {
        return;
    }

    still_referenced: set[str] = set[any]();
    for `edge in all_edges {
        still_referenced.add(`edge.get("source"));
        still_referenced.add(`edge.get("target"));
    }
    all_nodes[:] = [
        n
        for n in all_nodes
        if n.get("id") not in repointed_from or n.get("id") in still_referenced
    ];
}

impl _pascal_project_root(from_path: Path) -> Path {
    best: any = from_path.parent;
    current: any = from_path.parent;
    for _ in range(12) {
        if len(current.parts) <= 1 {
            break;
        }
        pas_count: any = sum(1 for _ in current.glob("*.pas"));
        dpr_count: any = sum(1 for _ in current.glob("*.dpr"));
        if pas_count >= 2 or dpr_count >= 1 {
            best = current;
        }
        parent: any = current.parent;
        if parent == current {
            break;
        }
        current = parent;
    }
    return best;
}

impl _pascal_resolve_unit(from_path: Path, unit_name: str) -> str {
    `root: any = _pascal_project_root(from_path);
    root_key: any = `str(`root);
    if root_key not in _pascal_unit_cache {
        unit_map: dict[str, str] = {};
        for ext in (".pas", ".pp", ".dpr", ".dpk", ".inc") {
            for f in `root.rglob("*" + ext) {
                unit_map[f.stem.lower()] = _make_id(`str(f));
            }
        }
        _pascal_unit_cache[root_key] = unit_map;
    }
    return _pascal_unit_cache[root_key].get(unit_name.lower(), _make_id(unit_name));
}

impl _pascal_resolve_class(from_path: Path, class_name: str) -> str | None {
    prefix: any = class_name[:1];
    unit_name: any = class_name[1:] if prefix in ("T", "I") else class_name;

    `root: any = _pascal_project_root(from_path);
    root_key: any = `str(`root);
    if root_key not in _pascal_class_stem_cache {
        stem_map: dict[str, str] = {};
        for ext in (".pas", ".pp", ".dpr", ".dpk") {
            for f in `root.rglob("*" + ext) {
                stem_map[f.stem.lower()] = _file_stem(f);
            }
        }
        _pascal_class_stem_cache[root_key] = stem_map;
    }

    file_stem: any = _pascal_class_stem_cache[root_key].get(unit_name.lower());
    if file_stem {
        return _make_id(file_stem, class_name);
    }
    return None;
}
