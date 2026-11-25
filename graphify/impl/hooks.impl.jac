impl _unquote_git_path(name: str) -> str {
    if len(name) < 2 or not (name.startswith("\"") and name.endswith("\"")) {
        return name;
    }
    body: any = name[1:-1];
    out: any = bytearray();
    i: any = 0;
    while i < len(body) {
        ch: any = body[i];
        if ch != "\\" or i + 1 >= len(body) {
            out += ch.encode("utf-8");
            i += 1;
            continue;
        }
        nxt: any = body[i + 1];
        if nxt in "0123" and i + 3 < len(body) and all(c in "01234567" for c in body[i + 1:i + 4]) {
            out.append(`int(body[i + 1:i + 4], 8));
            i += 4;
        } elif nxt in _GIT_C_ESCAPES {
            out.append(_GIT_C_ESCAPES[nxt]);
            i += 2;
        } else {
            out += ch.encode("utf-8");
            i += 1;
        }
    }
    return os.fsdecode(`bytes(out));
}

impl _detached_launch(rebuild_body: str) -> str {
    launcher: any = _LAUNCHER_TEMPLATE.replace("__REBUILD_BODY__", rebuild_body);
    return "\"$GRAPHIFY_PYTHON\" -c \"" + launcher + "\"\n";
}

impl _load_graphifyrc(`root: Path) -> dict {
    import from graphify.rcfile { load_graphifyrc }
    return load_graphifyrc(`root);
}

impl _git_root(path: Path) -> Path | None {
    current: any = path.resolve();
    for parent in [current, *current.parents] {
        if (parent / ".git").exists() {
            return parent;
        }
    }
    return None;
}

impl _reject_windows_path(value: str, source: str) -> None {
    if os.name == "nt" {
        return;
    }
    if _WINDOWS_DRIVE_RE.match(value) or "\\" in value {
        raise RuntimeError(
            f"git hooks path from {source} looks like a Windows path: {value!r}. On WSL/POSIX this can't resolve to a real directory. Unset it with `git config --local --unset core.hooksPath`, or set a POSIX path.",
        );
    }
}

impl _is_within(child: Path, parent: Path) -> bool {
    try {
        child.resolve().relative_to(parent.resolve());
    } except (ValueError, OSError) {
        return False;
    }
    return True;
}

impl _rev_parse_path(`root: Path, flag: str) -> Path | None {
    raw: any;
    try {
        res: any = _sp.run(
            ["git", "-C", `str(`root), "rev-parse", flag],
            capture_output=True,
            text=True,
            encoding="utf-8",
        );
    } except (OSError, FileNotFoundError) {
        return None;
    }
    if res.returncode != 0 {
        return None;
    }
    raw = res.stdout.strip();
    if not raw or `any(c in raw for c in ("\n", "\r", "\x00")) {
        return None;
    }
    path: any = Path(raw);
    if not path.is_absolute() {
        path = `root / path;
    }
    return path.resolve();
}

impl _builtin_hooks_dir(`root: Path) -> Path | None {
    for flag in ("--git-common-dir", "--git-dir") {
        git_dir: any = _rev_parse_path(`root, flag);
        if git_dir is not None {
            return (git_dir / "hooks").resolve();
        }
    }
    return None;
}

impl _hooks_path_allowed(`root: Path, candidate: Path) -> bool {
    if _is_within(candidate, `root) {
        return True;
    }
    builtin: any = _builtin_hooks_dir(`root);
    return builtin is not None and operator.eq(candidate.resolve(), builtin.resolve());
}

impl _hooks_dir(`root: Path) -> Path {
    raw: any;
    try {
        res: any = _sp.run(
            ["git", "-C", `str(`root), "rev-parse", "--git-path", "hooks"],
            capture_output=True,
            text=True,
            encoding="utf-8",
        );
        if res.returncode != 0 {
            err: any = (res.stderr or "").strip();
            print(
                "[graphify hooks] git could not resolve the hooks path for "
                    + format(`root, "")
                    + ": "
                    + format(err or f"git exited with code {res.returncode}", ""),
                file=sys.stderr,
            );
        } else {
            raw = res.stdout.strip();
            if raw and not `any(c in raw for c in ("\n", "\r", "\x00")) {
                _reject_windows_path(raw, "git rev-parse --git-path hooks");
                d: any = (`root / raw).resolve();
                if _hooks_path_allowed(`root, d) {
                    d.mkdir(parents=True, exist_ok=True);
                    return d;
                }
                print(
                    f"[graphify hooks] refusing hooks path {d}: it is outside {`root.resolve()}. Installing into the default git hooks directory instead (#3869).",
                    file=sys.stderr,
                );
                `default: any = _builtin_hooks_dir(`root);
                if `default is not None {
                    `default.mkdir(parents=True, exist_ok=True);
                    return `default;
                }
            }
        }
    } except (OSError, FileNotFoundError) {}
    d = `root / ".git" / "hooks";
    d.mkdir(parents=True, exist_ok=True);
    return d;
}

impl _install_hook(
    hooks_dir: Path, name: str, script: str, marker: str, marker_end: str = ""
) -> str {
    hook_path: any = hooks_dir / name;
    if hook_path.exists() {
        content: any = hook_path.read_text(encoding="utf-8");
        if marker in content {
            if marker_end and marker_end in content {
                start_idx: any = content.find(marker);
                end_idx: any = content.find(marker_end);
                if start_idx != -1 and end_idx != -1 and end_idx >= start_idx {
                    end_idx += len(marker_end);
                    new_content: any = content[:start_idx] + script.rstrip() + content[end_idx:];
                    if new_content == content {
                        return f"already installed at {hook_path}";
                    }
                    hook_path.write_text(new_content, encoding="utf-8", newline="\n");
                    return f"updated existing {name} hook at {hook_path}";
                }
            }
            return f"already installed at {hook_path}";
        }
        hook_path.write_text(content.rstrip() + "\n\n" + script, encoding="utf-8", newline="\n");
        return f"appended to existing {name} hook at {hook_path}";
    }
    hook_path.write_text("#!/bin/sh\n" + script, encoding="utf-8", newline="\n");
    hook_path.chmod(493);
    return f"installed at {hook_path}";
}

impl _uninstall_hook(hooks_dir: Path, name: str, marker: str, marker_end: str) -> str {
    hook_path: any = hooks_dir / name;
    if not hook_path.exists() {
        return f"no {name} hook found - nothing to remove.";
    }
    content: any = hook_path.read_text(encoding="utf-8");
    if marker not in content {
        return f"graphify hook not found in {name} - nothing to remove.";
    }
    new_content: any = re.sub(
        f"{re.escape(marker)}.*?{re.escape(marker_end)}\\n?", "", content, flags=re.DOTALL
    ).strip();
    if not new_content or new_content in ("#!/bin/bash", "#!/bin/sh") {
        hook_path.unlink();
        return f"removed {name} hook at {hook_path}";
    }
    hook_path.write_text(new_content + "\n", encoding="utf-8", newline="\n");
    return f"graphify removed from {name} at {hook_path} (other hook content preserved)";
}

impl _pinned_python -> str {
    if re.search("[^a-zA-Z0-9/_.@: \\\\-]", sys.executable) {
        return "";
    }
    if _is_rotating_prefix(sys.executable) {
        return "";
    }
    return sys.executable;
}

impl _is_rotating_prefix(path: str) -> bool {
    return `bool(_ROTATING_PREFIX_RE.search(path.replace("\\", "/")));
}

impl _merge_attr_line -> str {
    import from graphify.paths { GRAPHIFY_OUT }
    out: any = GRAPHIFY_OUT;
    if not out or Path(out).is_absolute() or "\\" in out {
        out = "graphify-out";
    }
    return format(out.rstrip("/"), "") + "/graph.json merge=graphify";
}

impl _has_merge_attr(content: str) -> bool {
    for raw in content.splitlines() {
        line: any = raw.strip();
        if not line or line.startswith("#") {
            continue;
        }
        fields: any = line.split();
        if fields and fields[0].endswith("graph.json") and "merge=graphify" in fields[1:] {
            return True;
        }
    }
    return False;
}

impl _register_merge_driver(`root: Path) -> str {
    pinned: any = _pinned_python();
    if pinned {
        driver: any = f"\"{pinned}\" -m graphify merge-driver %O %A %B";
    } else {
        driver = "graphify merge-driver %O %A %B";
    }
    try {
        for (key, value) in (
            ("merge.graphify.name", "graphify graph.json union merge"),
            ("merge.graphify.driver", driver),
        ) {
            _sp.run(
                ["git", "-C", `str(`root), "config", key, value],
                check=True,
                capture_output=True,
                text=True,
            );
        }
    } except (OSError, _sp.CalledProcessError) as exc {
        return f"not registered (git config failed: {exc})";
    }

    line: any = _merge_attr_line();
    attrs: any = `root / ".gitattributes";
    if attrs.exists() {
        content: any = attrs.read_text(encoding="utf-8");
        if _has_merge_attr(content) {
            return f"already registered ({line})";
        }
        if content and not content.endswith("\n") {
            content += "\n";
        }
        attrs.write_text(content + line + "\n", encoding="utf-8", newline="\n");
    } else {
        attrs.write_text(line + "\n", encoding="utf-8", newline="\n");
    }
    return f"registered ({line})";
}

impl _unregister_merge_driver(`root: Path) -> str {
    for key in ("merge.graphify.name", "merge.graphify.driver") {
        try {
            _sp.run(
                ["git", "-C", `str(`root), "config", "--unset", key], capture_output=True, text=True
            );
        } except OSError {}
    }
    attrs: any = `root / ".gitattributes";
    if not attrs.exists() {
        return "not registered - nothing to remove.";
    }
    content: any = attrs.read_text(encoding="utf-8");
    kept: any = [raw for raw in content.splitlines() if not _has_merge_attr(raw)];
    if kept == content.splitlines() {
        return "gitattributes entry not found - nothing to remove.";
    }
    if kept {
        attrs.write_text("\n".join(kept) + "\n", encoding="utf-8", newline="\n");
        return "removed from .gitattributes (other entries preserved)";
    }
    attrs.unlink();
    return "removed (.gitattributes deleted - no other entries)";
}

impl _merge_driver_status(`root: Path) -> str {
    try {
        res: any = _sp.run(
            ["git", "-C", `str(`root), "config", "--get", "merge.graphify.driver"],
            capture_output=True,
            text=True,
        );
        cfg_ok: any = operator.eq(res.returncode, 0) and `bool(res.stdout.strip());
    } except OSError {
        cfg_ok = False;
    }
    attrs: any = `root / ".gitattributes";
    attr_ok: any = attrs.exists() and _has_merge_attr(attrs.read_text(encoding="utf-8"));
    if cfg_ok and attr_ok {
        return "registered";
    }
    if cfg_ok {
        return "partially registered (git config set, .gitattributes line missing)";
    }
    if attr_ok {
        return "partially registered (.gitattributes line set, git config missing)";
    }
    return "not registered";
}

impl _user_hooks_dir(hooks_dir: Path) -> Path {
    if hooks_dir.name == "_" {
        return hooks_dir.parent;
    }
    return hooks_dir;
}

impl install(path: Path = path_default_) -> str {
    `root: any = _git_root(path);
    if `root is None {
        raise RuntimeError(f"No git repository found at or above {path.resolve()}");
    }

    hooks_dir: any = _user_hooks_dir(_hooks_dir(`root));

    cfg: any = _load_graphifyrc(`root);
    viz_limit: any = cfg.get("viz_node_limit");
    if viz_limit is not None {
        viz_export: any = f"export GRAPHIFY_VIZ_NODE_LIMIT=\"${{GRAPHIFY_VIZ_NODE_LIMIT:-{viz_limit}}}\"\n";
    } else {
        viz_export = "";
    }

    pinned: any = _pinned_python();
    hook: any = _HOOK_SCRIPT.replace("__PINNED_PYTHON__", pinned).replace(
        "__VIZ_LIMIT_EXPORT__", viz_export
    );
    checkout: any = _CHECKOUT_SCRIPT.replace("__PINNED_PYTHON__", pinned).replace(
        "__VIZ_LIMIT_EXPORT__", viz_export
    );
    merge_hook: any = _MERGE_SCRIPT.replace("__PINNED_PYTHON__", pinned).replace(
        "__VIZ_LIMIT_EXPORT__", viz_export
    );
    rewrite_hook: any = _REWRITE_SCRIPT.replace("__PINNED_PYTHON__", pinned).replace(
        "__VIZ_LIMIT_EXPORT__", viz_export
    );

    commit_msg: any = _install_hook(hooks_dir, "post-commit", hook, _HOOK_MARKER, _HOOK_MARKER_END);
    checkout_msg: any = _install_hook(
        hooks_dir, "post-checkout", checkout, _CHECKOUT_MARKER, _CHECKOUT_MARKER_END
    );
    post_merge_msg: any = _install_hook(
        hooks_dir, "post-merge", merge_hook, _MERGE_HOOK_MARKER, _MERGE_HOOK_MARKER_END
    );
    post_rewrite_msg: any = _install_hook(
        hooks_dir, "post-rewrite", rewrite_hook, _REWRITE_HOOK_MARKER, _REWRITE_HOOK_MARKER_END
    );
    merge_msg: any = _register_merge_driver(`root);

    return f"post-commit: {commit_msg}\npost-checkout: {checkout_msg}\npost-merge: {post_merge_msg}\npost-rewrite: {post_rewrite_msg}\nmerge driver: {merge_msg}";
}

impl uninstall(path: Path = path_default__) -> str {
    `root: any = _git_root(path);
    if `root is None {
        raise RuntimeError(f"No git repository found at or above {path.resolve()}");
    }

    hooks_dir: any = _user_hooks_dir(_hooks_dir(`root));
    commit_msg: any = _uninstall_hook(hooks_dir, "post-commit", _HOOK_MARKER, _HOOK_MARKER_END);
    checkout_msg: any = _uninstall_hook(
        hooks_dir, "post-checkout", _CHECKOUT_MARKER, _CHECKOUT_MARKER_END
    );
    post_merge_msg: any = _uninstall_hook(
        hooks_dir, "post-merge", _MERGE_HOOK_MARKER, _MERGE_HOOK_MARKER_END
    );
    post_rewrite_msg: any = _uninstall_hook(
        hooks_dir, "post-rewrite", _REWRITE_HOOK_MARKER, _REWRITE_HOOK_MARKER_END
    );
    merge_msg: any = _unregister_merge_driver(`root);

    return f"post-commit: {commit_msg}\npost-checkout: {checkout_msg}\npost-merge: {post_merge_msg}\npost-rewrite: {post_rewrite_msg}\nmerge driver: {merge_msg}";
}

impl _comparable_block(text: str, marker: str, marker_end: str) -> str | None {
    start: any = text.find(marker);
    end: any = text.find(marker_end, start) if start != -1 else -1;
    if end == -1 {
        return None;
    }
    block: any = text[start:end + len(marker_end)];
    return _VIZ_EXPORT_LINE_RE.sub("", _PINNED_LINE_RE.sub("_PINNED=''", block));
}

impl status(path: Path = path_default___) -> str {
    hooks_dir: any;
    cfg_limit: any;
    `root: any = _git_root(path);
    if `root is None {
        return "Not in a git repository.";
    }
    hooks_dir = _user_hooks_dir(_hooks_dir(`root));
    try {
        cfg: any = _load_graphifyrc(`root);
    } except ValueError as exc {
        cfg = {};
        print(f"  warning: {exc}");
    }
    cfg_limit = cfg.get("viz_node_limit");

    def _check(name: str, marker: str, marker_end: str, script: str) -> str {
        p: any = hooks_dir / name;
        if not p.exists() {
            return "not installed";
        }
        text: any = p.read_text(encoding="utf-8");
        if marker not in text {
            return "not installed (hook exists but graphify not found)";
        }
        if cfg_limit is not None {
            m: any = re.search(
                "export GRAPHIFY_VIZ_NODE_LIMIT=\"(?:\\$\\{GRAPHIFY_VIZ_NODE_LIMIT:-(\\d+)\\}|(\\d+))\"",
                text,
            );
            installed_limit: any = `int(m.group(1) or m.group(2)) if m else None;
            if installed_limit != cfg_limit {
                return "installed (out of date: hook has limit "
                    + format(installed_limit if installed_limit is not None else "unset", "")
                    + ", .graphifyrc has "
                    + format(cfg_limit, "")
                    + ")";
            }
        }
        installed: any = _comparable_block(text, marker, marker_end);
        current: any = _comparable_block(
            script.replace("__VIZ_LIMIT_EXPORT__", ""), marker, marker_end
        );
        if installed is not None and installed != current {
            return "installed (out of date: run `graphify hook install` to refresh it)";
        }
        return "installed";
    }

    commit: any = _check("post-commit", _HOOK_MARKER, _HOOK_MARKER_END, _HOOK_SCRIPT);
    checkout: any = _check(
        "post-checkout", _CHECKOUT_MARKER, _CHECKOUT_MARKER_END, _CHECKOUT_SCRIPT
    );
    post_merge: any = _check(
        "post-merge", _MERGE_HOOK_MARKER, _MERGE_HOOK_MARKER_END, _MERGE_SCRIPT
    );
    post_rewrite: any = _check(
        "post-rewrite", _REWRITE_HOOK_MARKER, _REWRITE_HOOK_MARKER_END, _REWRITE_SCRIPT
    );
    merge: any = _merge_driver_status(`root);

    res: any = f"post-commit: {commit}\npost-checkout: {checkout}\npost-merge: {post_merge}\npost-rewrite: {post_rewrite}\nmerge driver: {merge}";
    if cfg_limit is not None {
        res += f"\nviz node limit: {cfg_limit}";
    }
    return res;
}
