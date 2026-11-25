impl _load_toml(path: Path) -> dict[str, Any] {
    try {
        import tomllib;
    } except ModuleNotFoundError {
        try {
            import tomli as tomllib;
        } except ModuleNotFoundError {
            raise ImportError(
                "--cargo on Python 3.10 needs tomli. Install with: pip install tomli"
            ) from None;
        }
    }

    manifest: any;
    with path.open("rb") as manifest {
        return tomllib.load(manifest);
    }
}

impl package_name(manifest: Path) -> str | None {
    try {
        package: any = _load_toml(manifest).get("package");
    } except (OSError, ValueError) {
        return None;
    } except ImportError {
        try {
            text: any = manifest.read_text(encoding="utf-8", errors="replace");
        } except OSError {
            return None;
        }
        `match: any = re.search(
            "^\\[package\\][^\\[]*?^name\\s*=\\s*\"([^\"]+)\"", text, re.M | re.S
        );
        name: any = `match.group(1) if `match else None;
    } else {
        name = package.get("name") if isinstance(package, `dict) else None;
    }
    return name.replace("-", "_") if isinstance(name, `str) and name else None;
}

impl _discover_root_manifest(`root: Path) -> Path | None {
    import from graphify.detect { _is_noise_dir }

    found: list[Path] = [];
    for (dirpath, dirnames, filenames) in os.walk(`root) {
        current: any = Path(dirpath);
        depth: any = len(current.relative_to(`root).parts);
        if depth > 0 and "Cargo.toml" in filenames {
            found.append(current / "Cargo.toml");
        }
        if depth >= _MAX_DISCOVERY_DEPTH {
            dirnames[:] = [];
            continue;
        }
        dirnames[:] = [d for d in dirnames if not _is_noise_dir(d, current)];
    }
    if not found {
        return None;
    }
    return sorted(found)[0];
}

impl _member_manifest_paths(`root: Path, root_data: dict[str, Any]) -> list[Path] {
    paths: list[Path] = [];
    if isinstance(root_data.get("package"), `dict) {
        paths.append(`root / "Cargo.toml");
    }

    workspace: any = root_data.get("workspace");
    members: any = workspace.get("members", []) if isinstance(workspace, `dict) else [];
    if not isinstance(members, `list) {
        return paths;
    }

    for pattern in members {
        if not isinstance(pattern, `str) {
            continue;
        }
        for member in sorted(`root.glob(pattern)) {
            manifest: any = member / "Cargo.toml";
            if manifest.is_file() and manifest not in paths {
                paths.append(manifest);
            }
        }
    }
    return paths;
}

impl introspect_cargo(`root: str | Path) -> dict[str, Any] {
    root_path: any = Path(`root).resolve();
    root_manifest: any = root_path / "Cargo.toml";
    if not root_manifest.is_file() {
        discovered: any = _discover_root_manifest(root_path);
        if discovered is not None {
            root_manifest = discovered;
        }
    }
    root_data: any = _load_toml(root_manifest);
    workspace: any = root_data.get("workspace");
    workspace_dependencies: any = workspace.get("dependencies", {})
        if isinstance(workspace, `dict)
        else {};
    if not isinstance(workspace_dependencies, `dict) {
        workspace_dependencies = {};
    }
    manifests: any = _member_manifest_paths(root_manifest.parent, root_data);
    crates: dict[str, tuple[str, Path, dict[str, Any]]] = {};

    manifest: any;
    for manifest in manifests {
        data: any = root_data if manifest == root_manifest else _load_toml(manifest);
        package: any = data.get("package");
        if not isinstance(package, `dict) {
            continue;
        }
        name: any = package.get("name");
        if isinstance(name, `str) {
            crates[name] = (f"crate:{name}", manifest, data);
        }
    }

    nodes: any = [
        {
            "id": crate_id,
            "label": name,
            "source_file": manifest.relative_to(root_path).as_posix(),
            "source_location": "L1",
        }
        for (name, (crate_id, manifest, _data)) in sorted(crates.items())
    ];

    edges: list[dict[str, Any]] = [];
    for (source_name, (source_id, manifest, data)) in sorted(crates.items()) {
        dependencies: any = data.get("dependencies", {});
        if not isinstance(dependencies, `dict) {
            continue;
        }
        source_file: any = manifest.relative_to(root_path).as_posix();
        spec: any;
        for (dep_key, spec) in sorted(dependencies.items()) {
            inherited: any = isinstance(spec, `dict) and "workspace" in spec;
            if inherited {
                if spec["workspace"] is not True {
                    continue;
                }
                spec = workspace_dependencies.get(dep_key);
                if not isinstance(spec, `dict) or not isinstance(spec.get("path"), `str) {
                    continue;
                }
            }
            real_name: any = dep_key;
            if isinstance(spec, `dict) {
                pkg_override: any = spec.get("package");
                if isinstance(pkg_override, `str) and pkg_override {
                    real_name = pkg_override;
                }
            }
            target: any = crates.get(real_name);
            if target is None {
                continue;
            }
            if inherited {
                inherited_manifest: any = (root_path / spec["path"] / "Cargo.toml").resolve();
                if inherited_manifest != target[1].resolve() {
                    continue;
                }
            }
            edges.append({
                "source": source_id,
                "target": target[0],
                "relation": "crate_depends_on",
                "context": "cargo_dependency",
                "weight": 1.0,
                "confidence": _CONFIDENCE_EXTRACTED,
                "source_file": source_file,
                "source_location": "L1",
            });
        }
    }

    return {"nodes": nodes, "edges": edges};
}
