impl _load_toml_module -> any {
    try {
        import tomllib as _toml;
        return _toml;
    } except ImportError {
        try {
            import tomli as _toml;
            return _toml;
        } except ImportError as exc {
            raise ImportError(_TOMLI_REQUIRED) from exc;
        }
    }
}

impl is_package_manifest_path(path: Path) -> bool {
    return path.name.lower() in PACKAGE_MANIFEST_NAMES;
}

impl _pkg_id(name: str) -> str {
    return make_id("pkg", name);
}

impl extract_package_manifest(path: Path) -> dict[str, Any] {
    try {
        if path.stat().st_size > _MAX_MANIFEST_BYTES {
            return {"nodes": [], "edges": [], "error": "manifest too large to index"};
        }
        text: any = path.read_text(encoding="utf-8", errors="replace");
    } except OSError as exc {
        return {"nodes": [], "edges": [], "error": f"manifest read error: {exc}"};
    }

    eco: any = PACKAGE_MANIFEST_NAMES[path.name.lower()];
    try {
        info: any = _PARSERS[eco](text);
    } except Exception as exc {
        return {"nodes": [], "edges": [], "error": f"manifest parse error: {exc}"};
    }
    if isinstance(info, `dict) and info.get("skipped") {
        return {"nodes": [], "edges": [], "skipped": info["skipped"]};
    }
    if not info or not info.get("name") {
        return {"nodes": [], "edges": []};
    }

    name: any = info["name"];
    str_path: any = `str(path);
    pkg_nid: any = _pkg_id(name);
    `node: dict[str, Any] = {
        "id": pkg_nid,
        "label": name,
        "file_type": "code",
        "type": "package",
        "ecosystem": eco,
        "source_file": str_path,
        "source_location": "L1",
    };
    if info.get("version") {
        `node["version"] = info["version"];
    }
    nodes: list[dict] = [`node];
    edges: list[dict] = [];

    seen: set[str] = set[any]();
    for dep in info.get("deps", []) {
        if not dep {
            continue;
        }
        dep_nid: any = _pkg_id(dep);
        if dep_nid == pkg_nid or dep_nid in seen {
            continue;
        }
        seen.add(dep_nid);
        edges.append({
            "source": pkg_nid,
            "target": dep_nid,
            "relation": "depends_on",
            "context": "dependency",
            "confidence": "EXTRACTED",
            "confidence_score": 1.0,
            "source_file": str_path,
            "source_location": "L1",
            "weight": 1.0,
        });
    }
    return {"nodes": nodes, "edges": edges};
}

impl _coerce_deps(value: Any) -> list[str] {
    if isinstance(value, `dict) {
        return [`str(k) for k in value];
    }
    if isinstance(value, `list) {
        out: list[str] = [];
        for item in value {
            if isinstance(item, `str) {
                out.append(item);
            } elif isinstance(item, `dict) and item {
                out.append(`str(next(iter(item))));
            }
        }
        return out;
    }
    return [];
}

impl _parse_apm(text: str) -> dict | None {
    try {
        import yaml;
    } except ImportError {
        return _parse_apm_fallback(text);
    }
    data: any = yaml.safe_load(text);
    if not isinstance(data, `dict) {
        return None;
    }
    return {
        "name": data.get("name"),
        "version": data.get("version"),
        "deps": _coerce_deps(data.get("dependencies")),
    };
}

impl _parse_apm_fallback(text: str) -> dict | None {
    name: any = None;
    version: any = None;
    deps: list[str] = [];
    in_deps: any = False;
    for line in text.splitlines() {
        if not in_deps {
            m: any = re.match("^name:\\s*[\"\\']?([^\"\\'\\s#]+)", line);
            if m {
                name = m.group(1);
                continue;
            }
            m = re.match("^version:\\s*[\"\\']?([^\"\\'\\s#]+)", line);
            if m {
                version = m.group(1);
                continue;
            }
        }
        if re.match("^dependencies:\\s*$", line) {
            in_deps = True;
            continue;
        }
        if in_deps {
            dm: any = re.match("^\\s*-\\s*[\"\\']?([^\"\\'\\s#:]+)", line)
                or re.match("^\\s{2,}([A-Za-z0-9._/@-]+)\\s*:", line);
            if dm {
                deps.append(dm.group(1));
            } elif re.match("^\\S", line) {
                in_deps = False;
            }
        }
    }
    return {"name": name, "version": version, "deps": deps} if name else None;
}

impl _pep508_name(spec: str) -> str {
    return re.split("[\\s<>=!~;\\[\\(]", spec.strip(), maxsplit=1)[0];
}

impl _parse_pyproject(text: str) -> dict | None {
    _toml: any = _load_toml_module();
    data: any = _toml.loads(text);
    proj: any = data.get("project", {}) if isinstance(data.get("project"), `dict) else {};
    poetry: any = (data.get("tool", {}) or {}).get("poetry", {})
        if isinstance(data.get("tool"), `dict)
        else {};
    name: any = proj.get("name") or (poetry.get("name") if isinstance(poetry, `dict) else None);
    if not name {
        return None;
    }
    deps: list[str] = [
        _pep508_name(s)
        for s in proj.get("dependencies") or []
        if isinstance(s, `str)
    ];
    if isinstance(poetry, `dict) {
        for dep in poetry.get("dependencies") or {} {
            if `str(dep).lower() != "python" {
                deps.append(`str(dep));
            }
        }
    }
    return {
        "name": name,
        "version": proj.get("version")
            or (poetry.get("version") if isinstance(poetry, `dict) else None),
        "deps": deps,
    };
}

impl _parse_cargo(text: str) -> dict | None {
    _toml: any = _load_toml_module();
    data: any = _toml.loads(text);
    pkg: any = data.get("package", {}) if isinstance(data.get("package"), `dict) else {};
    name: any = pkg.get("name");
    if not isinstance(name, `str) or not name {
        if isinstance(data.get("workspace"), `dict) {
            return {"name": None, "skipped": "virtual workspace root Cargo.toml"};
        }
        return None;
    }
    version: any = pkg.get("version");
    if not isinstance(version, `str) {
        version = None;
    }
    deps: any = _coerce_deps(data.get("dependencies"));
    targets: any = data.get("target");
    if isinstance(targets, `dict) {
        for cfg in targets.values() {
            if isinstance(cfg, `dict) {
                deps += _coerce_deps(cfg.get("dependencies"));
            }
        }
    }
    return {"name": name, "version": version, "deps": deps};
}

impl _parse_gomod(text: str) -> dict | None {
    name: any = None;
    deps: list[str] = [];
    in_block: any = False;
    for line in text.splitlines() {
        s: any = line.strip();
        if name is None {
            m: any = re.match("^module\\s+(\\S+)", s);
            if m {
                name = m.group(1);
                continue;
            }
        }
        if re.match("^require\\s*\\(", s) {
            in_block = True;
            continue;
        }
        if in_block {
            if s.startswith(")") {
                in_block = False;
                continue;
            }
            dm: any = re.match("^(\\S+)\\s+v\\S+", s);
            if dm {
                deps.append(dm.group(1));
            }
        } else {
            dm = re.match("^require\\s+(\\S+)\\s+v\\S+", s);
            if dm {
                deps.append(dm.group(1));
            }
        }
    }
    return {"name": name, "version": None, "deps": deps} if name else None;
}

impl _parse_pom(text: str) -> dict | None {
    props: dict[str, str];
    `root: any = ET.fromstring(text);
    if `root.tag.startswith("{") {
        namespace: any = `root.tag.split("}", 1)[0] + "}";
        for element in `root.iter() {
            if isinstance(element.tag, `str) and element.tag.startswith(namespace) {
                element.tag = element.tag[len(namespace):];
            }
        }
    }
    aid: any = `root.findtext("artifactId");
    gid: any = `root.findtext("groupId") or `root.findtext("parent/groupId");
    version: any = `root.findtext("version") or `root.findtext("parent/version");
    if not aid {
        return None;
    }
    props = {};
    for prop in `root.findall("properties/*") {
        if isinstance(prop.tag, `str) and prop.text {
            props[prop.tag] = prop.text.strip();
        }
    }
    for (key, value) in (
        ("project.groupId", gid),
        ("project.artifactId", aid),
        ("project.version", version),
        ("project.parent.groupId", `root.findtext("parent/groupId")),
        ("project.parent.version", `root.findtext("parent/version")),
    ) {
        if value {
            props.setdefault(key, value.strip());
        }
    }

    def _resolve(value: str | None) -> str | None {
        if not value {
            return value;
        }
        return re.sub(
            "\\$\\{([^}]+)\\}",
            lambda (m) -> any { props.get(m.group(1), m.group(0)) },
            value.strip(),
        );
    }

    gid = _resolve(gid);
    version = _resolve(version);
    name: any = f"{gid}:{aid}" if gid else aid;
    deps: list[str] = [];
    for dep in `root.findall("dependencies/dependency")
        + `root.findall("profiles/profile/dependencies/dependency") {
        da: any = _resolve(dep.findtext("artifactId"));
        dg: any = _resolve(dep.findtext("groupId"));
        if da {
            deps.append(f"{dg}:{da}" if dg else da);
        }
    }
    return {"name": name, "version": version, "deps": deps};
}
