impl _skill_lock_path(skill_dir: Path) -> Path {
    try {
        real: any = skill_dir.resolve();
    } except (OSError, RuntimeError) {
        real = skill_dir.absolute();
    }
    digest: any = hashlib.sha256(os.path.normcase(`str(real)).encode("utf-8")).hexdigest()[:16];
    return Path.home() / ".cache" / "graphify" / "skill-locks" / f"{digest}.lock";
}

impl _try_skill_lock(fh) -> bool {
    try {
        if fcntl is not None {
            fcntl.flock(fh.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB);
        } else {
            fh.seek(0);
            msvcrt.locking(fh.fileno(), msvcrt.LK_NBLCK, 1);
        }
    } except OSError as exc {
        if exc.errno in (errno.EAGAIN, errno.EWOULDBLOCK, errno.EACCES) {
            return False;
        }
        raise;
    }
    return True;
}

impl _release_skill_lock(fh) -> None {
    with contextlib.suppress(OSError) {
        if fcntl is not None {
            fcntl.flock(fh.fileno(), fcntl.LOCK_UN);
        } else {
            fh.seek(0);
            msvcrt.locking(fh.fileno(), msvcrt.LK_UNLCK, 1);
        }
    }
}

impl _skill_lock(skill_dir: Path, *, `wait: bool = True) -> Generator[any, any, any] {
    path: any = _skill_lock_path(skill_dir);
    held: any = _held_skill_locks.__dict__.setdefault("paths", set[any]());
    if path in held {
        yield True;
        return;
    }
    try {
        path.parent.mkdir(parents=True, exist_ok=True);
        fh: any = open(path, "a+b");
    } except OSError {
        fh = None;
    }
    if fh is None {
        yield None;
        return;
    }
    with fh {
        try {
            locked: any = _try_skill_lock(fh);
            while not locked and `wait {
                time.sleep(0.05);
                locked = _try_skill_lock(fh);
            }
        } except OSError {
            locked = None;
        }
        if not locked {
            yield locked;
            return;
        }
        held.add(path);
        try {
            yield True;
        } finally {
            held.discard(path);
            _release_skill_lock(fh);
        }
    }
}

impl _write_version_stamp(skill_dst: Path, version: str) -> None {
    version_file: any = skill_dst.parent / ".graphify_version";
    fd: any;
    tmp_name: any;
    (fd, tmp_name) = tempfile.mkstemp(
        dir=`str(skill_dst.parent), prefix=".graphify_version.", suffix=".tmp"
    ) as any;
    tmp: any = Path(tmp_name);
    fd_closed: any = False;
    try {
        fh: any;
        with os.fdopen(fd, "w", encoding="utf-8") as fh {
            fd_closed = True;
            fh.write(version);
        }
        with contextlib.suppress(OSError) {
            if version_file.exists() and not version_file.is_symlink() {
                os.chmod(tmp, stat.S_IMODE(version_file.stat().st_mode));
            }
        }
        _os_replace_with_fallback(tmp, version_file);
    } finally {
        if not fd_closed {
            with contextlib.suppress(OSError) {
                os.close(fd);
            }
        }
        with contextlib.suppress(OSError) {
            tmp.unlink(missing_ok=True);
        }
    }
}

impl _always_on(basename: str) -> str {
    path: any = Path(__file__).parent / "always_on" / f"{basename}.md";
    try {
        return path.read_text(encoding="utf-8");
    } except OSError as exc {
        raise RuntimeError(
            f"graphify install is incomplete: missing always-on block '{basename}' at {path}. Reinstall graphifyy (e.g. `uv tool install --reinstall graphifyy`).",
        ) from exc;
    }
}

impl _platform_skill_destination(
    platform_name: str, *, project: bool = False, project_dir: Path | None = None
) -> Path {
    if platform_name == "gemini" {
        if project {
            return (project_dir or Path(".")) / ".gemini" / "skills" / "graphify" / "SKILL.md";
        }
        return Path.home() / ".gemini" / "skills" / "graphify" / "SKILL.md";
    }

    if platform_name == "opencode" {
        if project {
            return (project_dir or Path(".")) / ".opencode" / "skills" / "graphify" / "SKILL.md";
        }
        return Path.home() / ".config" / "opencode" / "skills" / "graphify" / "SKILL.md";
    }

    if platform_name == "hermes" {
        if project {
            return (project_dir or Path(".")) / ".hermes" / "skills" / "graphify" / "SKILL.md";
        }
        if platform.system() == "Windows" {
            local_appdata: any = Path(
                os.environ.get("LOCALAPPDATA") or Path.home() / "AppData" / "Local"
            );
            return local_appdata / "hermes" / "skills" / "graphify" / "SKILL.md";
        }
        return Path.home() / ".hermes" / "skills" / "graphify" / "SKILL.md";
    }

    if platform_name == "devin" {
        if project {
            return (project_dir or Path(".")) / ".devin" / "skills" / "graphify" / "SKILL.md";
        }
        return Path.home() / ".config" / "devin" / "skills" / "graphify" / "SKILL.md";
    }

    if platform_name == "amp" {
        if project {
            return (project_dir or Path(".")) / ".agents" / "skills" / "graphify" / "SKILL.md";
        }
        return Path.home() / ".config" / "agents" / "skills" / "graphify" / "SKILL.md";
    }

    if platform_name == "pi" {
        if project {
            return (project_dir or Path(".")) / ".pi" / "skills" / "graphify" / "SKILL.md";
        }
        return Path.home() / _PLATFORM_CONFIG["pi"]["skill_dst"];
    }

    if platform_name == "agents" {
        if project {
            return (project_dir or Path(".")) / ".agents" / "skills" / "graphify" / "SKILL.md";
        }
        return Path.home() / ".agents" / "skills" / "graphify" / "SKILL.md";
    }

    if platform_name in ("antigravity", "antigravity-windows") {
        if project {
            return (project_dir or Path(".")) / ".agents" / "skills" / "graphify" / "SKILL.md";
        }
        return Path.home() / ".gemini" / "config" / "skills" / "graphify" / "SKILL.md";
    }

    cfg: any = _PLATFORM_CONFIG[platform_name];
    if project {
        return (project_dir or Path(".")) / cfg["skill_dst"];
    }

    if platform_name in ("claude", "windows") and os.environ.get("CLAUDE_CONFIG_DIR") {
        return Path(os.environ["CLAUDE_CONFIG_DIR"]) / "skills" / "graphify" / "SKILL.md";
    }
    return Path.home() / cfg["skill_dst"];
}

impl _packaged_skill_refs_dir(platform_name: str) -> Path | None {
    if platform_name == "gemini" {
        bundle: any = "claude";
    } else {
        bundle = _PLATFORM_CONFIG[platform_name].get("skill_refs");
    }
    if not bundle {
        return None;
    }
    bundle_dir: any = Path(__file__).parent / "skills" / bundle;
    if not bundle_dir.is_dir() {
        return None;
    }
    return bundle_dir / "references";
}

impl _install_skill_references(skill_dst: Path, refs_src: Path) -> None {
    refs_dst: any = skill_dst.parent / "references";
    legacy_staged: any = skill_dst.parent / "references.tmp";
    if not legacy_staged.is_symlink() and legacy_staged.is_dir() {
        shutil.rmtree(legacy_staged, ignore_errors=True);
    }
    staging_root: any = Path(
        tempfile.mkdtemp(dir=`str(skill_dst.parent), prefix=".references.", suffix=".tmp")
    );
    refs_staged: any = staging_root / "references";
    try {
        shutil.copytree(refs_src, refs_staged);
        for path in (refs_staged, *refs_staged.rglob("*")) {
            path.chmod(path.stat().st_mode | stat.S_IWUSR);
        }
        if refs_dst.is_symlink() {
            refs_dst.unlink();
        } elif refs_dst.exists() {
            shutil.rmtree(refs_dst);
        }
        os.replace(refs_staged, refs_dst);
    } finally {
        if staging_root.is_symlink() {
            with contextlib.suppress(OSError) {
                staging_root.unlink();
            }
        } elif staging_root.exists() {
            shutil.rmtree(staging_root, ignore_errors=True);
        }
    }
}

impl _copy_skill_file(
    platform_name: str, *, project: bool = False, project_dir: Path | None = None
) -> Path {
    skill_file: any = "skill.md"
        if platform_name == "gemini"
        else _PLATFORM_CONFIG[platform_name]["skill_file"];
    skill_src: any = Path(__file__).parent / skill_file;
    if not skill_src.exists() {
        print(f"error: {skill_file} not found in package - reinstall graphify", file=sys.stderr);
        sys.exit(1);
    }

    refs_src: any = _packaged_skill_refs_dir(platform_name);
    if refs_src is not None and not refs_src.exists() {
        print(
            f"error: references for '{platform_name}' not found in package ({refs_src}) - reinstall graphify",
            file=sys.stderr,
        );
        sys.exit(1);
    }

    skill_dst: any = _platform_skill_destination(
        platform_name, project=project, project_dir=project_dir
    );
    with _skill_lock(skill_dst.parent) {
        skill_dst.parent.mkdir(parents=True, exist_ok=True);
        if refs_src is not None {
            _install_skill_references(skill_dst, refs_src);
            print("  references       ->  " + format(skill_dst.parent / "references", ""));
        } else {
            orphan_refs: any = skill_dst.parent / "references";
            if orphan_refs.exists() {
                shutil.rmtree(orphan_refs);
            }
        }
        try {
            if skill_dst.exists() and skill_dst.read_bytes() != skill_src.read_bytes() {
                backup: any = skill_dst.with_suffix(skill_dst.suffix + ".bak");
                shutil.copy2(skill_dst, backup);
                print(f"  previous copy    ->  {backup} (differed from the packaged skill)");
            }
        } except OSError {}
        fd: any;
        tmp_name: any;
        (fd, tmp_name) = tempfile.mkstemp(
            dir=`str(skill_dst.parent), prefix=f".{skill_dst.name}.", suffix=".tmp"
        ) as any;
        tmp_dst: any = Path(tmp_name);
        fd_closed: any = False;
        try {
            dst_fh: any;
            with os.fdopen(fd, "wb") as dst_fh {
                fd_closed = True;
                src_fh: any;
                with open(skill_src, "rb") as src_fh {
                    shutil.copyfileobj(src_fh, dst_fh);
                }
            }
            shutil.copymode(skill_src, tmp_dst);
            _os_replace_with_fallback(tmp_dst, skill_dst);
        } finally {
            if not fd_closed {
                with contextlib.suppress(OSError) {
                    os.close(fd);
                }
            }
            with contextlib.suppress(OSError) {
                tmp_dst.unlink(missing_ok=True);
            }
        }

        _write_version_stamp(skill_dst, __version__);
        print(f"  skill installed  ->  {skill_dst}");
    }
    return skill_dst;
}

impl _remove_skill_file(
    platform_name: str, *, project: bool = False, project_dir: Path | None = None
) -> bool {
    skill_dst: any = _platform_skill_destination(
        platform_name, project=project, project_dir=project_dir
    );
    removed: any = False;
    with _skill_lock(skill_dst.parent) {
        if skill_dst.exists() {
            skill_dst.unlink();
            print(f"  skill removed    ->  {skill_dst}");
            removed = True;
        }
        version_file: any = skill_dst.parent / ".graphify_version";
        if version_file.exists() {
            version_file.unlink();
            removed = True;
        }
        refs_dir: any = skill_dst.parent / "references";
        if refs_dir.exists() {
            shutil.rmtree(refs_dir);
            removed = True;
        }
        for d in (skill_dst.parent, skill_dst.parent.parent, skill_dst.parent.parent.parent) {
            try {
                d.rmdir();
            } except OSError {
                break;
            }
        }
    }
    return removed;
}

impl _project_scope_root(path: Path, project_dir: Path) -> Path {
    try {
        rel: any = path.relative_to(project_dir);
    } except ValueError {
        return path;
    }
    return project_dir / rel.parts[0] if rel.parts else path;
}

impl _is_graphify_skill_registration(section: "list[str]") -> bool {
    return `any(
        line.strip().startswith("- **graphify** (`") and "Trigger: `/graphify`" in line
        for line in section,
    );
}

impl _skill_registration_sections(content: str) -> "list[list[str]]" {
    lines: any;
    lines = content.split("\n");
    sections: any = [];
    for (start, line) in enumerate(lines) {
        if line.strip() == _SKILL_REGISTRATION_MARKER {
            end: any = next(
                (j for j in range(start + 1, len(lines)) if lines[j].startswith("# ")), len(lines)
            );
            sections.append(lines[start + 1:end]);
        }
    }
    return sections;
}

impl _remove_skill_registration(
    target: Path, prefix: str, *, only_graphify_written: bool = False
) -> None {
    try {
        if not target.exists() {
            return;
        }
        if _SKILL_REGISTRATION_MARKER.encode("utf-8") not in target.read_bytes() {
            return;
        }
        content: any;
        newline: any;
        (content, newline) = _read_keep_newline(target) as any;
        bom: any = "﻿" if content.startswith("﻿") else "";
        content = content[len(bom):];
        if only_graphify_written {
            written: any = [
                _is_graphify_skill_registration(s)
                for s in _skill_registration_sections(content)
            ];
            if not `any(written) {
                return;
            }
            if not all(written) {
                print(
                    f"{prefix}left as is: {_shown_path(target)} also has a `{_SKILL_REGISTRATION_MARKER}` section graphify did not write",
                    file=sys.stderr,
                );
                print(
                    f"  hint: remove graphify's own `{_SKILL_REGISTRATION_MARKER}` block (the one naming the graphify skill) by hand",
                    file=sys.stderr,
                );
                return;
            }
        }
        cleaned: any = _remove_marker_section(
            content, _SKILL_REGISTRATION_MARKER, boundary_prefix="# "
        );
        if cleaned is None {
            return;
        }
        if cleaned or target.is_symlink() {
            _write_keep_newline(target, bom + cleaned + "\n", newline);
            print(f"{prefix}graphify skill registration removed from {_shown_path(target)}");
        } else {
            target.unlink();
            print(f"{prefix}deleted {target}");
        }
    } except (OSError, UnicodeDecodeError) as exc {
        print(f"{prefix}skipped: {exc.__class__.__name__}: {exc}", file=sys.stderr);
        print(
            f"  hint: remove the `{_SKILL_REGISTRATION_MARKER}` block from {target} manually to finish the uninstall",
            file=sys.stderr,
        );
    }
}

impl _remove_claude_skill_registration(project_dir: Path) -> None {
    _remove_skill_registration(project_dir / ".claude" / "CLAUDE.md", "  CLAUDE.md        ->  ");
    for name in _CLAUDE_AGENTS_MD_FILES {
        _remove_skill_registration(
            project_dir / name, "  AGENTS.md        ->  ", only_graphify_written=True
        );
    }
}

impl _claude_global_registration -> "tuple[Path, str]" {
    config: any = os.environ.get("CLAUDE_CONFIG_DIR");
    if config {
        config_dir: any = Path(config);
        return (config_dir / "CLAUDE.md", `str(config_dir / "skills" / "graphify" / "SKILL.md"));
    }
    return (Path.home() / ".claude" / "CLAUDE.md", "~/.claude/skills/graphify/SKILL.md");
}

impl _codebuddy_global_registration -> Path {
    return Path.home() / ".codebuddy" / "CODEBUDDY.md";
}

impl _print_project_git_add_hint(paths: list[Path]) -> None {
    unique: list[str] = [];
    for path in paths {
        text: any = path.as_posix().rstrip("/");
        if path.exists() and path.is_dir() {
            text += "/";
        }
        if text not in unique {
            unique.append(text);
        }
    }
    if not unique {
        return;
    }
    print();
    print("Project-scoped install. Add to version control:");
    print("  git add " + format(" ".join(unique), ""));
}

impl _claude_pretooluse_hooks(strict: bool = False, project: bool = False) -> "list[dict]" {
    exe: any = _resolve_graphify_exe(project=project);
    if " " in exe and not exe.startswith("\"") {
        exe = f"\"{exe}\"";
    }
    read_cmd: any = f"{exe} hook-guard read" + (" --strict" if strict else "");
    search_cmd: any = f"{exe} hook-guard search" + (" --strict" if strict else "");
    return [
        {
            "matcher": "Bash|Grep",
            "hooks": [{"type": "command", "command": search_cmd, "timeout": 10}],
        },
        {
            "matcher": "Read|Glob",
            "hooks": [{"type": "command", "command": read_cmd, "timeout": 10}],
        },
    ];
}

impl _claude_sessionstart_hooks(project: bool = False) -> "list[dict]" {
    exe: any = _resolve_graphify_exe(project=project);
    if " " in exe and not exe.startswith("\"") {
        exe = f"\"{exe}\"";
    }
    return [
        {
            "matcher": "compact",
            "hooks": [{"type": "command", "command": f"{exe} hook-guard compact", "timeout": 10}],
        },
    ];
}

impl _is_graphify_hook_command(command: str) -> bool {
    lowered: any;
    lowered = command.lower();
    if "graphify" not in lowered {
        return False;
    }
    if `any(sub in lowered for sub in _GRAPHIFY_HOOK_SUBCOMMANDS) {
        return True;
    }
    return _GRAPHIFY_LEGACY_HOOK_MARKER in lowered;
}

impl _is_graphify_hook_entry(`entry: object) -> bool {
    if not isinstance(`entry, `dict) or `entry.get("type") != "command" {
        return False;
    }
    command: any = `entry.get("command");
    return isinstance(command, `str) and _is_graphify_hook_command(command);
}

impl _strip_graphify_hooks(groups: "list") -> "list" {
    kept: "list" = [];
    for group in groups {
        if not isinstance(group, `dict) {
            kept.append(group);
            continue;
        }
        entries: any = group.get("hooks");
        if not isinstance(entries, `list) {
            kept.append(group);
            continue;
        }
        remaining: any = [e for e in entries if not _is_graphify_hook_entry(e)];
        if len(remaining) == len(entries) {
            kept.append(group);
        } elif remaining {
            kept.append({**group, "hooks": remaining});
        }
    }
    return kept;
}

impl _skill_registration(skill_path: str = "~/.claude/skills/graphify/SKILL.md") -> str {
    return f"# graphify\n- **graphify** (`{skill_path}`) - any input to knowledge graph. Trigger: `/graphify`\nWhen the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.\n";
}

impl _shown_path(path: Path) -> str {
    if path.is_symlink() {
        return f"{path} -> {path.resolve()}";
    }
    return `str(path);
}

impl _register_always_on_block(target: Path, prefix: str, registration: str) -> None {
    try {
        existed: any = target.exists();
        content: any;
        newline: any;
        (content, newline) = (_read_keep_newline(target) if existed else ("", "\n")) as any;
        new_content: any = _replace_or_append_section(
            content, _SKILL_REGISTRATION_MARKER, registration, boundary_prefix="# "
        );
        if existed and new_content == content {
            print(f"{prefix}already registered (no change)");
        } elif existed {
            _write_keep_newline(target, new_content, newline);
            print(f"{prefix}skill registered in {_shown_path(target)}");
        } else {
            target.parent.mkdir(parents=True, exist_ok=True);
            _write_keep_newline(target, new_content, newline);
            print(f"{prefix}created at {_shown_path(target)}");
        }
    } except OSError as exc {
        print(f"{prefix}skipped: {exc.__class__.__name__}: {exc}", file=sys.stderr);
        print(
            f"  hint: the skill files were installed; add the graphify block to {target} manually to finish always-on registration",
            file=sys.stderr,
        );
    }
}

impl _canonical_platform(platform_name: str) -> str {
    return _PLATFORM_ALIASES.get(platform_name, platform_name);
}

impl _replace_or_append_section(
    content: str, marker: str, new_section: str, boundary_prefix: str = "## "
) -> str {
    lines: any = content.split("\n");
    starts: any = [i for (i, line) in enumerate(lines) if line.strip() == marker];
    if not starts {
        if content.strip() {
            return content.rstrip() + "\n\n" + new_section.lstrip();
        }
        return new_section.lstrip();
    }

    start: any = starts[-1];
    end: any = len(lines);
    for j in range(start + 1, len(lines)) {
        if lines[j].startswith(boundary_prefix) {
            end = j;
            break;
        }
    }

    head: any = "\n".join(lines[:start]).rstrip();
    tail: any = "\n".join(lines[end:]).lstrip();
    section: any = new_section.strip();

    parts: list[str] = [];
    if head {
        parts.append(head);
    }
    parts.append(section);
    if tail {
        parts.append(tail);
    }
    out: any = "\n\n".join(parts);
    if not out.endswith("\n") {
        out += "\n";
    }
    return out;
}

impl _remove_marker_section(
    content: str, marker: str, boundary_prefix: str = "## "
) -> "str | None" {
    lines: any = content.split("\n");
    removed: any = False;
    while True {
        starts: any = [i for (i, line) in enumerate(lines) if line.strip() == marker];
        if not starts {
            break;
        }
        start: any = starts[-1];
        end: any = len(lines);
        for j in range(start + 1, len(lines)) {
            if lines[j].startswith(boundary_prefix) {
                end = j;
                break;
            }
        }
        head: any = "\n".join(lines[:start]).rstrip();
        tail: any = "\n".join(lines[end:]).lstrip();
        merged: any = head + "\n\n" + tail if head and tail else head or tail;
        lines = merged.split("\n");
        removed = True;
    }
    if not removed {
        return None;
    }
    return "\n".join(lines).rstrip();
}

impl _read_keep_newline(path: Path) -> "tuple[str, str]" {
    raw: any = path.read_bytes().decode("utf-8");
    newline: any = "\r\n" if "\r\n" in raw else "\n";
    return (raw.replace("\r\n", "\n").replace("\r", "\n"), newline);
}

impl _write_keep_newline(path: Path, text: str, newline: str = "\n") -> None {
    if newline != "\n" {
        text = text.replace("\n", newline);
    }
    path.write_text(text, encoding="utf-8", newline="");
}

impl _print_banner -> None {
    if not sys.stdout.isatty() {
        return;
    }
    try {
        if sys.platform == "win32" {
            import ctypes;
            ctypes.windll.kernel32.SetConsoleMode(ctypes.windll.kernel32.GetStdHandle(-11), 7);
        }
        G: any = "\x1b[38;2;17;141;79m";
        D: any = "\x1b[2m";
        R: any = "\x1b[0m";
        lines: any = [f"  {G}{line}{R}" for line in _BANNER_LOGO.splitlines()];
        lines[6] += f"  {D}{__version__}{R}";
        print("\n" + "\n".join(lines) + "\n");
    } except Exception {}
}

impl install(
    platform: str = "claude", *, project: bool = False, project_dir: Path | None = None
) -> None {
    _print_banner();
    platform = _canonical_platform(platform);
    if platform == "gemini" {
        gemini_install(project_dir=project_dir, project=project);
        return;
    }
    if platform == "cursor" {
        _cursor_install(Path("."));
        return;
    }
    if platform == "antigravity" and sys.platform == "win32" {
        platform = "antigravity-windows";
    }
    if platform not in _PLATFORM_CONFIG {
        print(
            "error: unknown platform '"
                + format(platform, "")
                + "'. Choose from: "
                + format(", ".join(_PLATFORM_CONFIG), "")
                + ", gemini, cursor",
            file=sys.stderr,
        );
        sys.exit(1);
    }

    cfg: any = _PLATFORM_CONFIG[platform];
    project_dir = project_dir or Path(".");
    skill_dst: any = _copy_skill_file(platform, project=project, project_dir=project_dir);

    if platform == "kilo" {
        command_src: any = Path(__file__).parent / "command-kilo.md";
        if not command_src.exists() {
            print(
                f"error: command-kilo.md not found in package - reinstall graphify", file=sys.stderr
            );
            sys.exit(1);
        }
        command_dst: any = Path.home() / ".config" / "kilo" / "command" / "graphify.md";
        command_dst.parent.mkdir(parents=True, exist_ok=True);
        shutil.copy(command_src, command_dst);
        print(f"  command installed ->  {command_dst}");
    }

    if cfg["claude_md"] {
        if project {
            claude_md: any = _claude_instructions_file(project_dir);
            if claude_md.name != "AGENTS.md" {
                claude_md = project_dir / ".claude" / "CLAUDE.md";
            }
            skill_ref: any = ".claude/skills/graphify/SKILL.md";
        } elif os.environ.get("CLAUDE_CONFIG_DIR") {
            config_dir: any = Path(os.environ["CLAUDE_CONFIG_DIR"]);
            claude_md = config_dir / "CLAUDE.md";
            skill_ref = `str(config_dir / "skills" / "graphify" / "SKILL.md");
        } else {
            claude_md = Path.home() / ".claude" / "CLAUDE.md";
            skill_ref = "~/.claude/skills/graphify/SKILL.md";
        }
        _register_always_on_block(
            claude_md, "  CLAUDE.md        ->  ", _skill_registration(skill_ref)
        );
    }

    if platform == "codebuddy" {
        _register_always_on_block(
            Path.home() / ".codebuddy" / "CODEBUDDY.md",
            "  CODEBUDDY.md     ->  ",
            _skill_registration("~/.codebuddy/skills/graphify/SKILL.md"),
        );
    }

    if platform == "opencode" {
        _install_opencode_plugin(_opencode_dir(project=project, project_dir=project_dir));
    }

    if project {
        _print_project_git_add_hint([_project_scope_root(skill_dst, project_dir)]);
    }

    print();
    print("Done. Open your AI coding assistant and type:");
    print();
    print("  /graphify .");
    print();
    print("Prefer a hosted version? Graphify Cloud has a free plan, no card required:");
    print(
        "https://app.graphify.com/signup?utm_source=cli&utm_medium=terminal&utm_campaign=oss&utm_content=install",
    );
    print();
}

impl _print_install_usage -> None {
    platforms: any = ", ".join([*_PLATFORM_CONFIG, "gemini", "cursor"]);
    print("Usage: graphify install [--project] [--strict] [--platform P|P]");
    print(f"Platforms: {platforms}");
    print(
        "  --strict  block the first raw Read or dedicated Grep per session unless recently oriented with `graphify query` (Claude Code project hooks only; needs --project; Bash/Glob stay advisory)",
    );
}

impl _gemini_hook(project: bool = False) -> dict {
    exe: any = _resolve_graphify_exe(project=project);
    if " " in exe and not exe.startswith("\"") {
        exe = f"\"{exe}\"";
    }
    return {
        "matcher": "read_file|list_directory",
        "hooks": [{"type": "command", "command": f"{exe} hook-guard gemini"}],
    };
}

impl _warn_shadowing_agents_skill -> None {
    shadow: any = _platform_skill_destination("agents");
    if shadow.exists() {
        print(f"  note: Gemini CLI loads {shadow} ahead of this install. If an older");
        print("        `graphify install --platform gemini` wrote it, delete that folder;");
        print("        if you use the `agents` platform, keep it.");
    }
}

impl gemini_install(project_dir: Path | None = None, *, project: bool = False) -> None {
    project_dir = project_dir or Path(".");
    skill_dst: any = _copy_skill_file("gemini", project=project, project_dir=project_dir);
    if not project {
        _warn_shadowing_agents_skill();
    }

    target: any = project_dir / "GEMINI.md";

    if target.exists() {
        content: any;
        newline: any;
        (content, newline) = _read_keep_newline(target) as any;
        new_content: any = _replace_or_append_section(
            content, _GEMINI_MD_MARKER, _always_on("gemini-md")
        );
    } else {
        (content, newline) = ("", "\n");
        new_content = _always_on("gemini-md");
    }

    if target.exists() and new_content == content {
        print(f"graphify already configured in {target.resolve()} (no change)");
    } else {
        _write_keep_newline(target, new_content, newline);
        print(f"graphify section written to {target.resolve()}");
    }
    _install_gemini_hook(project_dir, project=project);
    if project {
        _print_project_git_add_hint([
            _project_scope_root(skill_dst, project_dir),
            project_dir / "GEMINI.md",
            project_dir / ".gemini",
        ]);
    }
    print();
    print("Gemini CLI will now check the knowledge graph before answering");
    print("codebase questions and rebuild it after code changes.");
}

impl _refuse_to_modify(settings_path: Path) -> "NoReturn" {
    print(
        f"[graphify] refusing to modify {settings_path}: not valid JSON (fix or move it and re-run)",
        file=sys.stderr,
    );
    sys.exit(1);
}

impl _read_settings_for_merge(settings_path: Path) -> dict {
    if not settings_path.exists() {
        return {};
    }
    try {
        settings: any = json.loads(settings_path.read_text(encoding="utf-8-sig"));
    } except (json.JSONDecodeError, UnicodeDecodeError, OSError) {
        settings = None;
    }
    if not isinstance(settings, `dict) {
        _refuse_to_modify(settings_path);
    }
    return settings;
}

impl _write_settings_with_backup(settings_path: Path, settings: dict) -> None {
    output: any = json.dumps(settings, indent=2);
    if settings_path.exists() {
        if settings_path.read_text(encoding="utf-8") == output {
            return;
        }
        backup: any = settings_path.with_name(settings_path.name + ".graphify-bak");
        shutil.copy2(settings_path, backup);
    }
    settings_path.write_text(output, encoding="utf-8");
}

impl _install_gemini_hook(project_dir: Path, project: bool = False) -> None {
    settings_path: any = project_dir / ".gemini" / "settings.json";
    settings_path.parent.mkdir(parents=True, exist_ok=True);
    settings: any = _read_settings_for_merge(settings_path);
    hooks: any = settings.setdefault("hooks", {});
    if not isinstance(hooks, `dict) {
        _refuse_to_modify(settings_path);
    }
    before_tool: any = hooks.setdefault("BeforeTool", []);
    if not isinstance(before_tool, `list) {
        _refuse_to_modify(settings_path);
    }
    hooks["BeforeTool"] = _strip_graphify_hooks(before_tool);
    hooks["BeforeTool"].append(_gemini_hook(project=project));
    _write_settings_with_backup(settings_path, settings);
    print("  .gemini/settings.json  ->  BeforeTool hook registered");
}

impl _uninstall_gemini_hook(project_dir: Path) -> None {
    settings_path: any = project_dir / ".gemini" / "settings.json";
    if not settings_path.exists() {
        return;
    }
    try {
        settings: any = json.loads(settings_path.read_text(encoding="utf-8"));
    } except json.JSONDecodeError {
        return;
    }
    before_tool: any = settings.get("hooks", {}).get("BeforeTool", []);
    if not isinstance(before_tool, `list) {
        return;
    }
    filtered: any = _strip_graphify_hooks(before_tool);
    if filtered == before_tool {
        return;
    }
    settings["hooks"]["BeforeTool"] = filtered;
    _write_settings_with_backup(settings_path, settings);
    print("  .gemini/settings.json  ->  BeforeTool hook removed");
}

impl gemini_uninstall(
    project_dir: Path | None = None, *, project: bool = False, remove_user_skill: bool | None = None
) -> None {
    explicit_dir: any = project_dir is not None;
    project_dir = project_dir or Path(".");
    if remove_user_skill is None {
        remove_user_skill = not project and not explicit_dir;
    }
    if project or explicit_dir and not remove_user_skill {
        _remove_skill_file("gemini", project=True, project_dir=project_dir);
    }
    if remove_user_skill {
        _remove_skill_file("gemini", project=False);
    }

    target: any = project_dir / "GEMINI.md";
    if not target.exists() {
        print("No GEMINI.md found in current directory - nothing to do");
        return;
    }
    content: any;
    newline: any;
    (content, newline) = _read_keep_newline(target) as any;
    cleaned: any = _remove_marker_section(content, _GEMINI_MD_MARKER);
    if cleaned is None {
        print("graphify section not found in GEMINI.md - nothing to do");
        return;
    }
    if cleaned or target.is_symlink() {
        _write_keep_newline(target, cleaned + "\n", newline);
        print(f"graphify section removed from {target.resolve()}");
    } else {
        target.unlink();
        print(f"GEMINI.md was empty after removal - deleted {target.resolve()}");
    }
    _uninstall_gemini_hook(project_dir);
}

impl _vscode_skill_destination -> Path {
    return Path.home() / ".copilot" / "skills" / "graphify" / "SKILL.md";
}

impl vscode_install(project_dir: Path | None = None) -> None {
    skill_src: any = Path(__file__).parent / "skill-vscode.md";
    refs_bundle: any = "vscode";
    if not skill_src.exists() {
        skill_src = Path(__file__).parent / "skill-copilot.md";
        refs_bundle = "copilot";
    }
    skill_dst: any = _vscode_skill_destination();
    with _skill_lock(skill_dst.parent) {
        skill_dst.parent.mkdir(parents=True, exist_ok=True);
        fd: any;
        tmp_name: any;
        (fd, tmp_name) = tempfile.mkstemp(
            dir=`str(skill_dst.parent), prefix=f".{skill_dst.name}.", suffix=".tmp"
        ) as any;
        tmp_dst: any = Path(tmp_name);
        fd_closed: any = False;
        try {
            dst_fh: any;
            with os.fdopen(fd, "wb") as dst_fh {
                fd_closed = True;
                src_fh: any;
                with open(skill_src, "rb") as src_fh {
                    shutil.copyfileobj(src_fh, dst_fh);
                }
            }
            shutil.copymode(skill_src, tmp_dst);
            _os_replace_with_fallback(tmp_dst, skill_dst);
        } finally {
            if not fd_closed {
                with contextlib.suppress(OSError) {
                    os.close(fd);
                }
            }
            with contextlib.suppress(OSError) {
                tmp_dst.unlink(missing_ok=True);
            }
        }
        refs_src: any = Path(__file__).parent / "skills" / refs_bundle / "references";
        if refs_src.exists() {
            _install_skill_references(skill_dst, refs_src);
            print("  references       ->  " + format(skill_dst.parent / "references", ""));
        } else {
            orphan_refs: any = skill_dst.parent / "references";
            if orphan_refs.exists() {
                shutil.rmtree(orphan_refs);
            }
        }
        _write_version_stamp(skill_dst, __version__);
        print(f"  skill installed  ->  {skill_dst}");
    }

    instructions: any = (project_dir or Path(".")) / ".github" / "copilot-instructions.md";
    instructions.parent.mkdir(parents=True, exist_ok=True);
    if instructions.exists() {
        content: any;
        newline: any;
        (content, newline) = _read_keep_newline(instructions) as any;
        new_content: any = _replace_or_append_section(
            content, _VSCODE_INSTRUCTIONS_MARKER, _always_on("vscode-instructions")
        );
        if new_content == content {
            print(f"  {instructions}  ->  already configured (no change)");
        } else {
            _write_keep_newline(instructions, new_content, newline);
            print(
                "  "
                    + format(instructions, "")
                    + "  ->  graphify section "
                    + format("updated" if _VSCODE_INSTRUCTIONS_MARKER in content else "added", ""),
            );
        }
    } else {
        _write_keep_newline(instructions, _always_on("vscode-instructions"));
        print(f"  {instructions}  ->  created");
    }

    print();
    print("VS Code Copilot Chat configured. Type /graphify in the chat panel to build the graph.");
    print("Note: for GitHub Copilot CLI (terminal), use: graphify copilot install");
}

impl vscode_uninstall(project_dir: Path | None = None) -> None {
    skill_dst: any = _vscode_skill_destination();
    with _skill_lock(skill_dst.parent) {
        if skill_dst.exists() {
            skill_dst.unlink();
            print(f"  skill removed    ->  {skill_dst}");
        }
        version_file: any = skill_dst.parent / ".graphify_version";
        if version_file.exists() {
            version_file.unlink();
        }
        refs_dir: any = skill_dst.parent / "references";
        if refs_dir.exists() {
            shutil.rmtree(refs_dir);
        }
        for d in (skill_dst.parent, skill_dst.parent.parent, skill_dst.parent.parent.parent) {
            try {
                d.rmdir();
            } except OSError {
                break;
            }
        }
    }

    instructions: any = (project_dir or Path(".")) / ".github" / "copilot-instructions.md";
    if not instructions.exists() {
        return;
    }
    content: any;
    newline: any;
    (content, newline) = _read_keep_newline(instructions) as any;
    cleaned: any = _remove_marker_section(content, _VSCODE_INSTRUCTIONS_MARKER);
    if cleaned is None {
        return;
    }
    if cleaned or instructions.is_symlink() {
        _write_keep_newline(instructions, cleaned + "\n", newline);
        print(f"  graphify section removed from {instructions}");
    } else {
        instructions.unlink();
        print(f"  {instructions}  ->  deleted (was empty after removal)");
    }
}

impl _kiro_install(project_dir: Path) -> None {
    project_dir = project_dir or Path(".");
    _copy_skill_file("kiro", project=True, project_dir=project_dir);
    steering_dir: any = project_dir / ".kiro" / "steering";
    steering_dir.mkdir(parents=True, exist_ok=True);
    steering_dst: any = steering_dir / "graphify.md";
    if steering_dst.exists()
        and steering_dst.read_text(encoding="utf-8") == _always_on("kiro-steering")
    {
        print(f"  .kiro/steering/graphify.md  ->  already configured (no change)");
    } else {
        action: any = "updated" if steering_dst.exists() else "written";
        steering_dst.write_text(_always_on("kiro-steering"), encoding="utf-8");
        print(f"  .kiro/steering/graphify.md  ->  always-on steering {action}");
    }

    print();
    print("Kiro will now read the knowledge graph before every conversation.");
    print("Use /graphify to build or update the graph.");
}

impl _kiro_uninstall(project_dir: Path) -> None {
    project_dir = project_dir or Path(".");
    removed: any = [];
    skill_dst: any = _platform_skill_destination("kiro", project=True, project_dir=project_dir);
    if _remove_skill_file("kiro", project=True, project_dir=project_dir) {
        removed.append(`str(skill_dst.relative_to(project_dir)));
    }

    steering_dst: any = project_dir / ".kiro" / "steering" / "graphify.md";
    if steering_dst.exists() {
        steering_dst.unlink();
        removed.append(`str(steering_dst.relative_to(project_dir)));
    }

    print("Removed: " + (", ".join(removed) if removed else "nothing to remove"));
}

impl _antigravity_finalize(skill_dst: Path, project_dir: Path) -> None {
    if skill_dst.exists() {
        content: any = skill_dst.read_text(encoding="utf-8");
        if not content.startswith("---\n") {
            frontmatter: any = "---\nname: graphify-manager\ndescription: Rebuild the code graph or perform manual CLI queries when MCP server is offline.\n---\n\n";
            skill_dst.write_text(frontmatter + content, encoding="utf-8");
        }
    }
    rules_path: any = project_dir / _ANTIGRAVITY_RULES_PATH;
    rules_path.parent.mkdir(parents=True, exist_ok=True);
    if rules_path.exists() {
        existing: any = rules_path.read_text(encoding="utf-8");
        if _always_on("antigravity-rules").strip() != existing.strip() {
            rules_path.write_text(_always_on("antigravity-rules"), encoding="utf-8");
            print(f"graphify rule updated at {rules_path.resolve()}");
        } else {
            print(f"graphify rule already configured at {rules_path.resolve()} (no change)");
        }
    } else {
        rules_path.write_text(_always_on("antigravity-rules"), encoding="utf-8");
        print(f"graphify rule written to {rules_path.resolve()}");
    }
    wf_path: any = project_dir / _ANTIGRAVITY_WORKFLOW_PATH;
    wf_path.parent.mkdir(parents=True, exist_ok=True);
    if wf_path.exists() {
        existing = wf_path.read_text(encoding="utf-8");
        if _ANTIGRAVITY_WORKFLOW.strip() != existing.strip() {
            wf_path.write_text(_ANTIGRAVITY_WORKFLOW, encoding="utf-8");
            print(f"graphify workflow updated at {wf_path.resolve()}");
        } else {
            print(f"graphify workflow already configured at {wf_path.resolve()} (no change)");
        }
    } else {
        wf_path.write_text(_ANTIGRAVITY_WORKFLOW, encoding="utf-8");
        print(f"graphify workflow written to {wf_path.resolve()}");
    }
}

impl _antigravity_install(project_dir: Path) -> None {
    install(platform="antigravity");
    _antigravity_finalize(_platform_skill_destination("antigravity"), project_dir);

    print();
    print("Antigravity will now check the knowledge graph before answering");
    print("codebase questions. Run /graphify first to build the graph.");
    print();
    print(
        "To enable full MCP architecture navigation, add this to ~/.gemini/antigravity/mcp_config.json:",
    );
    print("  \"graphify\": {");
    print("    \"command\": \"uv\",");
    print(
        "    \"args\": [\"run\", \"--with\", \"graphifyy\", \"--with\", \"mcp\", \"-m\", \"graphify.serve\", \"${workspace.path}/graphify-out/graph.json\"]",
    );
    print("  }");
}

impl _antigravity_uninstall(project_dir: Path, *, project: bool = False) -> None {
    rules_path: any = project_dir / _ANTIGRAVITY_RULES_PATH;
    if rules_path.exists() {
        rules_path.unlink();
        print(f"graphify rule removed from {rules_path.resolve()}");
    } else {
        print("No graphify Antigravity rule found - nothing to do");
    }
    wf_path: any = project_dir / _ANTIGRAVITY_WORKFLOW_PATH;
    if wf_path.exists() {
        wf_path.unlink();
        print(f"graphify workflow removed from {wf_path.resolve()}");
    }
    skill_dst: any = _platform_skill_destination(
        "antigravity", project=project, project_dir=project_dir
    );
    with _skill_lock(skill_dst.parent) {
        if skill_dst.exists() {
            skill_dst.unlink();
            print(f"graphify skill removed from {skill_dst}");
        }
        version_file: any = skill_dst.parent / ".graphify_version";
        if version_file.exists() {
            version_file.unlink();
        }
        refs_dir: any = skill_dst.parent / "references";
        if refs_dir.exists() {
            shutil.rmtree(refs_dir);
        }
        for d in (skill_dst.parent, skill_dst.parent.parent, skill_dst.parent.parent.parent) {
            try {
                d.rmdir();
            } except OSError {
                break;
            }
        }
    }
}

impl _cursor_install(project_dir: Path) -> None {
    rule_path: any = (project_dir or Path(".")) / _CURSOR_RULE_PATH;
    rule_path.parent.mkdir(parents=True, exist_ok=True);
    if rule_path.exists() and rule_path.read_text(encoding="utf-8") == _CURSOR_RULE {
        print(f"graphify rule at {rule_path} already configured (no change)");
        return;
    }
    action: any = "updated" if rule_path.exists() else "written";
    rule_path.write_text(_CURSOR_RULE, encoding="utf-8");
    print(f"graphify rule {action} at {rule_path.resolve()}");
    print();
    print("Cursor will now always include the knowledge graph context.");
    print("Run /graphify . first to build the graph if you haven't already.");
}

impl _cursor_uninstall(project_dir: Path) -> None {
    rule_path: any = (project_dir or Path(".")) / _CURSOR_RULE_PATH;
    if not rule_path.exists() {
        print("No graphify Cursor rule found - nothing to do");
        return;
    }
    rule_path.unlink();
    print(f"graphify Cursor rule removed from {rule_path.resolve()}");
}

impl _devin_rules_install(project_dir: Path) -> None {
    rules_path: any = (project_dir or Path(".")) / _DEVIN_RULES_PATH;
    rules_path.parent.mkdir(parents=True, exist_ok=True);
    if rules_path.exists() and rules_path.read_text(encoding="utf-8") == _DEVIN_RULES {
        print(f"  {rules_path}  ->  already configured (no change)");
        return;
    }
    action: any = "updated" if rules_path.exists() else "written";
    rules_path.write_text(_DEVIN_RULES, encoding="utf-8");
    print(f"  rules {action}  ->  {rules_path}");
}

impl _devin_rules_uninstall(project_dir: Path) -> None {
    rules_path: any = (project_dir or Path(".")) / _DEVIN_RULES_PATH;
    if not rules_path.exists() {
        return;
    }
    rules_path.unlink();
    print(f"  rules removed  ->  {rules_path}");
}

impl _strip_json_comments(raw: str) -> str {
    result: list[str] = [];
    in_string: any = False;
    escaped: any = False;
    line_comment: any = False;
    block_comment: any = False;
    i: any = 0;

    while i < len(raw) {
        ch: any = raw[i];
        nxt: any = raw[i + 1] if i + 1 < len(raw) else "";

        if line_comment {
            if ch == "\n" {
                line_comment = False;
                result.append(ch);
            }
            i += 1;
            continue;
        }

        if block_comment {
            if ch == "*" and nxt == "/" {
                block_comment = False;
                i += 2;
            } else {
                i += 1;
            }
            continue;
        }

        if in_string {
            result.append(ch);
            if escaped {
                escaped = False;
            } elif ch == "\\" {
                escaped = True;
            } elif ch == "\"" {
                in_string = False;
            }
            i += 1;
            continue;
        }

        if ch == "/" and nxt == "/" {
            line_comment = True;
            i += 2;
            continue;
        }
        if ch == "/" and nxt == "*" {
            block_comment = True;
            i += 2;
            continue;
        }

        result.append(ch);
        if ch == "\"" {
            in_string = True;
        }
        i += 1;
    }

    return re.sub(",(\\s*[}\\]])", "\\1", "".join(result));
}

impl _load_json_like(config_file: Path) -> dict {
    if not config_file.exists() {
        return {};
    }
    try {
        raw: any = config_file.read_text(encoding="utf-8");
        if config_file.suffix == ".jsonc" {
            raw = _strip_json_comments(raw);
        }
        loaded: any = json.loads(raw);
    } except (OSError, json.JSONDecodeError) {
        return {};
    }
    return loaded if isinstance(loaded, `dict) else {};
}

impl _read_json_like_for_merge(config_file: Path) -> dict {
    if not config_file.exists() {
        return {};
    }
    try {
        raw: any = config_file.read_text(encoding="utf-8-sig");
        if config_file.suffix == ".jsonc" {
            raw = _strip_json_comments(raw);
        }
        loaded: any = json.loads(raw);
    } except (OSError, UnicodeDecodeError, json.JSONDecodeError) {
        loaded = None;
    }
    if not isinstance(loaded, `dict) {
        _refuse_to_modify(config_file);
    }
    return loaded;
}

impl _kilo_config_path(project_dir: Path) -> Path {
    kilo_dir: any = (project_dir or Path(".")) / ".kilo";
    json_path: any = kilo_dir / _KILO_CONFIG_JSON_PATH.name;
    if json_path.exists() {
        return json_path;
    }
    jsonc_path: any = kilo_dir / _KILO_CONFIG_JSONC_PATH.name;
    if jsonc_path.exists() {
        return jsonc_path;
    }
    return json_path;
}

impl _kilo_config_write_path(project_dir: Path) -> Path {
    kilo_dir: any = (project_dir or Path(".")) / ".kilo";
    return kilo_dir / _KILO_CONFIG_JSON_PATH.name;
}

impl _install_kilo_plugin(project_dir: Path) -> None {
    config_file: any = _kilo_config_path(project_dir);
    config: any = _read_json_like_for_merge(config_file);

    plugin_file: any = project_dir / _KILO_PLUGIN_PATH;
    plugin_file.parent.mkdir(parents=True, exist_ok=True);
    plugin_file.write_text(_KILO_PLUGIN_JS, encoding="utf-8");
    print(f"  {_KILO_PLUGIN_PATH}  ->  tool.execute.before hook written");

    write_config_file: any = _kilo_config_write_path(project_dir);
    write_config_file.parent.mkdir(parents=True, exist_ok=True);
    plugins: any = config.get("plugin");
    if not isinstance(plugins, `list) {
        plugins = [];
        config["plugin"] = plugins;
    }
    `entry: any = plugin_file.resolve().as_uri();
    if `entry not in plugins {
        plugins.append(`entry);
        write_config_file.write_text(json.dumps(config, indent=2), encoding="utf-8");
        print(f"  {write_config_file.relative_to(project_dir)}  ->  plugin registered");
    } else {
        print(
            f"  {config_file.relative_to(project_dir)}  ->  plugin already registered (no change)"
        );
    }
}

impl _uninstall_kilo_plugin(project_dir: Path) -> None {
    plugin_file: any = project_dir / _KILO_PLUGIN_PATH;
    if plugin_file.exists() {
        plugin_file.unlink();
        print(f"  {_KILO_PLUGIN_PATH}  ->  removed");
    }

    config_file: any = _kilo_config_path(project_dir);
    if not config_file.exists() {
        return;
    }
    write_config_file: any = _kilo_config_write_path(project_dir);
    config: any = _load_json_like(config_file);
    plugins: any = config.get("plugin", []);
    if not isinstance(plugins, `list) {
        plugins = [];
    }
    `entry: any = plugin_file.resolve().as_uri();
    if `entry in plugins {
        config["plugin"] = [plugin for plugin in plugins if plugin != `entry];
        if not config["plugin"] {
            config.pop("plugin");
        }
        write_config_file.parent.mkdir(parents=True, exist_ok=True);
        write_config_file.write_text(json.dumps(config, indent=2), encoding="utf-8");
        print(f"  {write_config_file.relative_to(project_dir)}  ->  plugin deregistered");
    }
}

impl _opencode_dir(*, project: bool, project_dir: Path | None = None) -> Path {
    if project {
        return (project_dir or Path(".")) / ".opencode";
    }
    return Path.home() / ".config" / "opencode";
}

impl _opencode_plugin_is_v1_only(body: str) -> bool {
    return body.startswith(_OPENCODE_PLUGIN_HEADER) and "export default" not in body;
}

impl _opencode_config_names_plugin(opencode_dir: Path) -> bool {
    try {
        raw: any = (opencode_dir / _OPENCODE_CONFIG_PATH.name).read_text(encoding="utf-8");
    } except (OSError, UnicodeDecodeError) {
        return False;
    }
    return f"\"{_OPENCODE_PLUGIN_PATH.as_posix()}\"" in raw;
}

impl _drop_opencode_config_entry(opencode_dir: Path) -> bool {
    config_file: any = opencode_dir / _OPENCODE_CONFIG_PATH.name;
    `entry: any = _OPENCODE_PLUGIN_PATH.as_posix();
    try {
        raw: any = config_file.read_text(encoding="utf-8");
    } except (OSError, UnicodeDecodeError) {
        return False;
    }
    try {
        config: any = json.loads(raw);
    } except ValueError {
        if f"\"{`entry}\"" in raw {
            print(
                f"  {config_file}  ->  not plain JSON, left as is; remove \"{`entry}\" from its plugin list by hand",
            );
        }
        return False;
    }
    if not isinstance(config, `dict) {
        return False;
    }
    changed: any = False;
    for key in ("plugin", "plugins") {
        plugins: any = config.get(key);
        if isinstance(plugins, `list) and `entry in plugins {
            config[key] = [p for p in plugins if p != `entry];
            if not config[key] {
                config.pop(key);
            }
            changed = True;
        }
    }
    if changed {
        _write_text_atomic(config_file, json.dumps(config, indent=2, ensure_ascii=False));
    }
    return changed;
}

impl _install_opencode_plugin(opencode_dir: Path) -> None {
    plugin_file: any = opencode_dir / _OPENCODE_PLUGIN_PATH.relative_to(".opencode");
    _write_text_atomic(plugin_file, _OPENCODE_PLUGIN_JS);
    print(f"  {plugin_file}  ->  tool.execute.before hook written");

    if _drop_opencode_config_entry(opencode_dir) {
        print(f"  {opencode_dir / _OPENCODE_CONFIG_PATH.name}  ->  stale plugin entry removed");
    }
}

impl _uninstall_opencode_plugin(opencode_dir: Path) -> None {
    plugin_file: any = opencode_dir / _OPENCODE_PLUGIN_PATH.relative_to(".opencode");
    if plugin_file.exists() {
        plugin_file.unlink();
        print(f"  {plugin_file}  ->  removed");
    }

    if _drop_opencode_config_entry(opencode_dir) {
        print(f"  {opencode_dir / _OPENCODE_CONFIG_PATH.name}  ->  plugin deregistered");
    }
}

impl _resolve_graphify_exe(project: bool = False) -> str {
    import shutil;
    if project {
        return "graphify";
    }
    found: any = shutil.which("graphify");
    if not found {
        scripts_dir: any = Path(sys.executable).parent;
        for name in ("graphify.exe", "graphify") {
            candidate: any = scripts_dir / name;
            if candidate.exists() {
                found = `str(candidate);
                break;
            }
        }
    }
    return (found or "graphify").replace("\\", "/");
}

impl _install_codex_hook(project_dir: Path, project: bool = False) -> None {
    hooks_path: any = project_dir / ".codex" / "hooks.json";
    hooks_path.parent.mkdir(parents=True, exist_ok=True);

    existing: any = _read_settings_for_merge(hooks_path);

    graphify_exe: any = _resolve_graphify_exe(project=project);
    if " " in graphify_exe and not graphify_exe.startswith("\"") {
        graphify_exe = f"\"{graphify_exe}\"";
    }
    hook_entry: any = {
        "hooks": {
            "PreToolUse": [
                {
                    "matcher": "Bash",
                    "hooks": [{"type": "command", "command": f"{graphify_exe} hook-check"}],
                },
            ],
        },
    };

    hooks: any = existing.setdefault("hooks", {});
    if not isinstance(hooks, `dict) {
        _refuse_to_modify(hooks_path);
    }
    pre_tool: any = hooks.setdefault("PreToolUse", []);
    if not isinstance(pre_tool, `list) {
        _refuse_to_modify(hooks_path);
    }
    hooks["PreToolUse"] = _strip_graphify_hooks(pre_tool);
    hooks["PreToolUse"].extend(hook_entry["hooks"]["PreToolUse"]);
    _write_settings_with_backup(hooks_path, existing);
    print(
        f"  .codex/hooks.json  ->  PreToolUse hook registered ({graphify_exe} hook-check - intentional no-op; Codex Desktop rejects additionalContext on PreToolUse, so graph guidance comes from AGENTS.md)",
    );
}

impl _uninstall_codex_hook(project_dir: Path) -> None {
    hooks_path: any = project_dir / ".codex" / "hooks.json";
    if not hooks_path.exists() {
        return;
    }
    try {
        existing: any = json.loads(hooks_path.read_text(encoding="utf-8"));
    } except json.JSONDecodeError {
        return;
    }
    pre_tool: any = existing.get("hooks", {}).get("PreToolUse", []);
    if not isinstance(pre_tool, `list) {
        return;
    }
    filtered: any = _strip_graphify_hooks(pre_tool);
    if filtered == pre_tool {
        return;
    }
    existing["hooks"]["PreToolUse"] = filtered;
    _write_settings_with_backup(hooks_path, existing);
    print(f"  .codex/hooks.json  ->  PreToolUse hook removed");
}

impl _agents_install(project_dir: Path, platform: str, project: bool = False) -> None {
    target: any = (project_dir or Path(".")) / "AGENTS.md";

    if target.exists() {
        content: any;
        newline: any;
        (content, newline) = _read_keep_newline(target) as any;
        new_content: any = _replace_or_append_section(
            content, _AGENTS_MD_MARKER, _always_on("agents-md")
        );
    } else {
        (content, newline) = ("", "\n");
        new_content = _always_on("agents-md");
    }

    if target.exists() and new_content == content {
        print(f"graphify already configured in {target.resolve()} (no change)");
    } else {
        _write_keep_newline(target, new_content, newline);
        print(f"graphify section written to {target.resolve()}");
    }

    if platform == "codex" {
        _install_codex_hook(project_dir or Path("."), project=project);
    } elif platform == "opencode" {
        _install_opencode_plugin(_opencode_dir(project=True, project_dir=project_dir));
    } elif platform == "kilo" {
        _install_kilo_plugin(project_dir or Path("."));
    }

    print();
    print(f"{platform.capitalize()} will now check the knowledge graph before answering");
    print("codebase questions and rebuild it after code changes.");
    if platform not in ("codex", "opencode", "kilo") {
        print();
        print("Note: unlike Claude Code, there is no PreToolUse hook equivalent for");
        print(f"{platform.capitalize()} — the AGENTS.md rules are the always-on mechanism.");
    }
}

impl _amp_legacy_cleanup -> None {
    legacy: any = Path.home() / ".amp" / "skills" / "graphify";
    if legacy.exists() {
        shutil.rmtree(legacy, ignore_errors=True);
        if not legacy.exists() {
            print(f"  legacy removed   ->  {legacy}");
        }
    }
}

impl _amp_install(project_dir: Path | None = None) -> None {
    _amp_legacy_cleanup();
    _copy_skill_file("amp");
    _agents_install(project_dir or Path("."), "amp");
}

impl _amp_uninstall(project_dir: Path | None = None) -> None {
    removed: any = _remove_skill_file("amp");
    if removed {
        print("skill removed");
    }
    _agents_uninstall(project_dir or Path("."), platform="amp");
}

impl _agents_platform_install(project_dir: Path | None = None) -> None {
    _copy_skill_file("agents");
    _agents_install(project_dir or Path("."), "agents");
}

impl _agents_platform_uninstall(project_dir: Path | None = None) -> None {
    removed: any = _remove_skill_file("agents");
    if removed {
        print("skill removed");
    }
    _agents_uninstall(project_dir or Path("."), platform="agents");
}

impl _project_install(
    platform_name: str, project_dir: Path | None = None, strict: bool = False
) -> None {
    project_dir = project_dir or Path(".");
    platform_name = _canonical_platform(platform_name);
    if platform_name in ("claude", "windows") {
        target: any = claude_install(project_dir, strict=strict, project=True);
        install(platform=platform_name, project=True, project_dir=project_dir);
        _print_project_git_add_hint([project_dir / ".claude", target]);
    } elif platform_name == "gemini" {
        gemini_install(project_dir, project=True);
    } elif platform_name == "cursor" {
        _cursor_install(project_dir);
        _print_project_git_add_hint([project_dir / ".cursor"]);
    } elif platform_name == "kiro" {
        _kiro_install(project_dir);
        _print_project_git_add_hint([project_dir / ".kiro"]);
    } elif platform_name
        in ("aider", "amp", "codex", "opencode", "claw", "droid", "trae", "trae-cn", "hermes")
    {
        skill_dst: any = _copy_skill_file(platform_name, project=True, project_dir=project_dir);
        _agents_install(project_dir, platform_name, project=True);
        hint_paths: any = [_project_scope_root(skill_dst, project_dir), project_dir / "AGENTS.md"];
        if platform_name == "opencode" {
            hint_paths.append(project_dir / ".opencode");
        } elif platform_name == "codex" {
            hint_paths.append(project_dir / ".codex");
        }
        _print_project_git_add_hint(hint_paths);
    } elif platform_name == "devin" {
        skill_dst = _copy_skill_file("devin", project=True, project_dir=project_dir);
        _devin_rules_install(project_dir);
        _print_project_git_add_hint([
            _project_scope_root(skill_dst, project_dir),
            project_dir / ".windsurf",
        ]);
    } elif platform_name == "antigravity" {
        skill_dst = _copy_skill_file("antigravity", project=True, project_dir=project_dir);
        _antigravity_finalize(skill_dst, project_dir);
        _print_project_git_add_hint([
            _project_scope_root(skill_dst, project_dir),
            project_dir / ".agents",
        ]);
    } elif platform_name in ("copilot", "pi", "kimi", "agents") {
        skill_dst = _copy_skill_file(platform_name, project=True, project_dir=project_dir);
        _print_project_git_add_hint([_project_scope_root(skill_dst, project_dir)]);
    } else {
        install(platform=platform_name, project=True, project_dir=project_dir);
    }
}

impl _project_uninstall(platform_name: str, project_dir: Path | None = None) -> None {
    project_dir = project_dir or Path(".");
    platform_name = _canonical_platform(platform_name);
    if platform_name in ("claude", "windows") {
        _remove_skill_file(platform_name, project=True, project_dir=project_dir);
        claude_uninstall(project_dir, project=True);
    } elif platform_name == "gemini" {
        gemini_uninstall(project_dir, project=True);
    } elif platform_name == "cursor" {
        _cursor_uninstall(project_dir);
    } elif platform_name == "kiro" {
        _kiro_uninstall(project_dir);
    } elif platform_name
        in ("aider", "amp", "codex", "opencode", "claw", "droid", "trae", "trae-cn", "hermes")
    {
        _remove_skill_file(platform_name, project=True, project_dir=project_dir);
        _agents_uninstall(project_dir, platform=platform_name);
        if platform_name == "codex" {
            _uninstall_codex_hook(project_dir);
        }
    } elif platform_name == "antigravity" {
        _antigravity_uninstall(project_dir, project=True);
    } elif platform_name == "devin" {
        removed: any = _remove_skill_file("devin", project=True, project_dir=project_dir);
        _devin_rules_uninstall(project_dir);
        if not removed {
            print("nothing to remove");
        }
    } elif platform_name in ("copilot", "pi", "kimi", "agents") {
        removed = _remove_skill_file(platform_name, project=True, project_dir=project_dir);
        if not removed {
            print("nothing to remove");
        }
    } elif platform_name == "codebuddy" {
        codebuddy_uninstall(project_dir, project=True);
    } else {
        _remove_skill_file(platform_name, project=True, project_dir=project_dir);
    }
}

impl _project_uninstall_all(project_dir: Path | None = None) -> None {
    project_dir = project_dir or Path(".");
    print("Uninstalling project-scoped graphify files...\n");
    platform_name: any;
    for platform_name in _PLATFORM_CONFIG {
        _project_uninstall(platform_name, project_dir);
    }
    for platform_name in ("gemini", "cursor") {
        _project_uninstall(platform_name, project_dir);
    }
    print("\nDone.");
}

impl _agents_uninstall(project_dir: Path, platform: str = "") -> None {
    target: any = (project_dir or Path(".")) / "AGENTS.md";

    if not target.exists() {
        print("No AGENTS.md found in current directory - nothing to do");
        if platform == "opencode" {
            _uninstall_opencode_plugin(_opencode_dir(project=True, project_dir=project_dir));
        } elif platform == "kilo" {
            _uninstall_kilo_plugin(project_dir or Path("."));
        }
        return;
    }

    content: any;
    newline: any;
    (content, newline) = _read_keep_newline(target) as any;
    cleaned: any = _remove_marker_section(content, _AGENTS_MD_MARKER);
    if cleaned is None {
        print("graphify section not found in AGENTS.md - nothing to do");
        if platform == "opencode" {
            _uninstall_opencode_plugin(_opencode_dir(project=True, project_dir=project_dir));
        } elif platform == "kilo" {
            _uninstall_kilo_plugin(project_dir or Path("."));
        }
        return;
    }
    if cleaned or target.is_symlink() {
        _write_keep_newline(target, cleaned + "\n", newline);
        print(f"graphify section removed from {target.resolve()}");
    } else {
        target.unlink();
        print(f"AGENTS.md was empty after removal - deleted {target.resolve()}");
    }

    if platform == "opencode" {
        _uninstall_opencode_plugin(_opencode_dir(project=True, project_dir=project_dir));
    } elif platform == "kilo" {
        _uninstall_kilo_plugin(project_dir or Path("."));
    }
}

impl _kilo_uninstall_global -> list[str] {
    removed: any = [];
    command_dst: any = Path.home() / ".config" / "kilo" / "command" / "graphify.md";
    if command_dst.exists() {
        command_dst.unlink();
        removed.append(f"command removed: {command_dst}");
    }
    try {
        command_dst.parent.rmdir();
    } except OSError {}

    skill_dst: any = Path.home() / _PLATFORM_CONFIG["kilo"]["skill_dst"];
    with _skill_lock(skill_dst.parent) {
        if skill_dst.exists() {
            skill_dst.unlink();
            removed.append(f"skill removed: {skill_dst}");
        }
        version_file: any = skill_dst.parent / ".graphify_version";
        if version_file.exists() {
            version_file.unlink();
        }
        refs_dir: any = skill_dst.parent / "references";
        if refs_dir.exists() {
            shutil.rmtree(refs_dir);
        }
        for d in (skill_dst.parent, skill_dst.parent.parent, skill_dst.parent.parent.parent) {
            try {
                d.rmdir();
            } except OSError {
                break;
            }
        }
    }

    return removed;
}

impl _kilo_install(project_dir: Path) -> None {
    install(platform="kilo");
    _agents_install(project_dir or Path("."), "kilo");
}

impl _kilo_uninstall(project_dir: Path) -> None {
    _agents_uninstall(project_dir or Path("."), platform="kilo");
    removed: any = _kilo_uninstall_global();
    print("; ".join(removed) if removed else "nothing to remove");
}

impl _claude_instructions_file(project_dir: Path) -> Path {
    user_md: any;
    name: any;
    for name in _CLAUDE_MD_FILES {
        if (project_dir / name).is_file() {
            return project_dir / name;
        }
    }
    user_md = (
        Path(os.environ.get("CLAUDE_CONFIG_DIR") or Path.home() / ".claude") / "CLAUDE.md"
    ).resolve();
    resolved: any = project_dir.resolve();
    blockers: any = (d / name
    for d in (resolved, *resolved.parents)
    for name in _CLAUDE_MD_BLOCKERS);
    if not `any(b.is_file() and operator.ne(b.resolve(), user_md) for b in blockers) {
        for name in _CLAUDE_AGENTS_MD_FILES {
            if (project_dir / name).is_file() {
                return project_dir / name;
            }
        }
    }
    return project_dir / "CLAUDE.md";
}

impl claude_install(
    project_dir: Path | None = None, strict: bool = False, project: bool = False
) -> Path {
    target: any = _claude_instructions_file(project_dir or Path("."));
    block: any = _always_on("agents-md" if target.name == "AGENTS.md" else "claude-md");

    if target.exists() {
        content: any;
        newline: any;
        (content, newline) = _read_keep_newline(target) as any;
        new_content: any = _replace_or_append_section(content, _CLAUDE_MD_MARKER, block);
    } else {
        (content, newline) = ("", "\n");
        new_content = block;
    }

    if target.exists() and new_content == content {
        print(f"graphify already configured in {target.resolve()} (no change)");
    } else {
        _write_keep_newline(target, new_content, newline);
        print(f"graphify section written to {target.resolve()}");
    }
    _install_claude_hook(project_dir or Path("."), strict=strict, project=project);

    print();
    print("Claude Code will now check the knowledge graph before answering");
    print("codebase questions and rebuild it after code changes.");
    if strict {
        print("Strict mode: Read and dedicated Grep share one block per session");
        print("unless recently oriented with `graphify query`; Bash/Glob stay advisory.");
        print("Toggle with GRAPHIFY_HOOK_STRICT=0.");
    }
    return target;
}

impl _install_claude_hook(project_dir: Path, strict: bool = False, project: bool = False) -> None {
    settings_path: any = project_dir / ".claude" / "settings.json";
    settings_path.parent.mkdir(parents=True, exist_ok=True);

    settings: any = _read_settings_for_merge(settings_path);

    hooks: any = settings.setdefault("hooks", {});
    if not isinstance(hooks, `dict) {
        _refuse_to_modify(settings_path);
    }
    pre_tool: any = hooks.setdefault("PreToolUse", []);
    if not isinstance(pre_tool, `list) {
        _refuse_to_modify(settings_path);
    }

    session_start: any = hooks.setdefault("SessionStart", []);
    if not isinstance(session_start, `list) {
        _refuse_to_modify(settings_path);
    }

    hooks["PreToolUse"] = _strip_graphify_hooks(pre_tool);
    hooks["PreToolUse"].extend(_claude_pretooluse_hooks(strict=strict, project=project));
    hooks["SessionStart"] = _strip_graphify_hooks(session_start);
    hooks["SessionStart"].extend(_claude_sessionstart_hooks(project=project));
    _write_settings_with_backup(settings_path, settings);
    _mode: any = " (strict)" if strict else "";
    print(
        f"  .claude/settings.json  ->  PreToolUse hooks registered (Bash|Grep search + Read/Glob){_mode}",
    );
    print(
        "  .claude/settings.json  ->  SessionStart hook registered (compact: resets the nudge budget)",
    );
}

impl _uninstall_claude_hook(project_dir: Path) -> None {
    claude_dir: any = project_dir / ".claude";
    for name in ("settings.json", "settings.local.json") {
        _strip_graphify_hook(claude_dir / name);
    }
}

impl _strip_graphify_hook(settings_path: Path) -> None {
    if not settings_path.exists() {
        return;
    }
    try {
        settings: any = json.loads(settings_path.read_text(encoding="utf-8"));
    } except json.JSONDecodeError {
        return;
    }
    hooks: any = settings.get("hooks", {});
    if not isinstance(hooks, `dict) {
        return;
    }
    removed: any = [];
    event: any;
    for event in ("PreToolUse", "SessionStart") {
        groups: any = hooks.get(event, []);
        if not isinstance(groups, `list) {
            continue;
        }
        filtered: any = _strip_graphify_hooks(groups);
        if filtered != groups {
            hooks[event] = filtered;
            removed.append(event);
        }
    }
    if not removed {
        return;
    }
    _write_settings_with_backup(settings_path, settings);
    for event in removed {
        print(f"  .claude/{settings_path.name}  ->  {event} hook removed");
    }
}

impl _unsafe_purge_reason(out: Path, project_dir: Path) -> str | None {
    target: any = out.resolve();
    project: any = project_dir.resolve();
    home: any = Path.home().resolve();
    if target == project or target in project.parents {
        return "the project folder or one of its parents";
    }
    if target == home or target in home.parents {
        return "your home folder or one of its parents";
    }
    if target == Path(target.anchor) {
        return "a filesystem root";
    }
    return None;
}

impl uninstall_all(project_dir: Path | None = None, purge: bool = False) -> None {
    pd: any = project_dir or Path(".");
    out: any = pd / _GRAPHIFY_OUT;
    if purge {
        reason: any = _unsafe_purge_reason(out, pd);
        if reason {
            print(
                f"error: refusing --purge: {out.resolve()} is {reason}. Nothing was changed. Check the GRAPHIFY_OUT environment variable.",
                file=sys.stderr,
            );
            sys.exit(1);
        }
    }
    print("Uninstalling graphify from all detected platforms...\n");
    claude_uninstall(pd, remove_user_skill=True);
    codebuddy_uninstall(pd, remove_user_skill=True);
    gemini_uninstall(pd, remove_user_skill=True);
    vscode_uninstall(pd);
    _cursor_uninstall(pd);
    _kiro_uninstall(pd);
    _antigravity_uninstall(pd);
    _agents_uninstall(pd);
    for platform_name in _PLATFORM_CONFIG {
        _remove_skill_file(platform_name);
    }
    for line in _kilo_uninstall_global() {
        print(f"  {line}");
    }
    _uninstall_opencode_plugin(_opencode_dir(project=True, project_dir=pd));
    _uninstall_opencode_plugin(_opencode_dir(project=False));
    _uninstall_codex_hook(pd);
    try {
        import from graphify.hooks { uninstall as hook_uninstall }
        result: any = hook_uninstall(pd);
        if result {
            print(result);
        }
    } except Exception {}

    if purge {
        import shutil as _shutil;
        if out.exists() {
            _shutil.rmtree(out);
            print(f"\n  {_GRAPHIFY_OUT}/  ->  deleted (--purge)");
        } else {
            print(f"\n  {_GRAPHIFY_OUT}/  ->  not found (nothing to purge)");
        }
    }

    print("\nDone. Run 'pip uninstall graphifyy' to remove the package itself.");
}

impl claude_uninstall(
    project_dir: Path | None = None, *, project: bool = False, remove_user_skill: bool | None = None
) -> None {
    explicit_dir: any = project_dir is not None;
    project_dir = project_dir or Path(".");
    if remove_user_skill is None {
        remove_user_skill = not project and not explicit_dir;
    }
    if project or explicit_dir and not remove_user_skill {
        _remove_skill_file("claude", project=True, project_dir=project_dir);
        _remove_claude_skill_registration(project_dir);
    }
    if remove_user_skill {
        _remove_skill_file("claude", project=False);
        _remove_skill_registration(
            _claude_global_registration()[0], "  CLAUDE.md        ->  ", only_graphify_written=True
        );
    }

    md_targets: any = [
        project_dir / "CLAUDE.md",
        project_dir / ".claude" / "CLAUDE.md",
        project_dir / "CLAUDE.local.md",
        project_dir / ".claude" / "CLAUDE.local.md",
    ];
    existing: any = [t for t in md_targets if t.exists()];
    removed_any: any = False;
    for target in existing {
        if _strip_graphify_md_section(target) {
            removed_any = True;
        }
    }
    kept: any = [];
    for name in _CLAUDE_AGENTS_MD_FILES {
        try {
            if _CLAUDE_MD_MARKER
                in (project_dir / name).read_text(encoding="utf-8", errors="replace")
            {
                kept.append(project_dir / name);
            }
        } except OSError {
            continue;
        }
    }

    if kept {
        for agents_md in kept {
            print(
                f"graphify section in {agents_md} left in place: other agents read it too (`graphify codex uninstall` removes it)",
            );
        }
    } elif not existing {
        print("No CLAUDE.md found in current directory - nothing to do");
    } elif not removed_any {
        print("graphify section not found in CLAUDE.md - nothing to do");
    }

    _uninstall_claude_hook(project_dir);
}

impl _strip_graphify_md_section(target: Path) -> bool {
    try {
        content: any;
        newline: any;
        (content, newline) = _read_keep_newline(target) as any;
    } except (OSError, UnicodeDecodeError) {
        return False;
    }
    cleaned: any = _remove_marker_section(content, _CLAUDE_MD_MARKER);
    if cleaned is None {
        return False;
    }
    if cleaned or target.is_symlink() {
        _write_keep_newline(target, cleaned + "\n", newline);
        print(f"graphify section removed from {target.resolve()}");
    } else {
        target.unlink();
        print(f"{target.name} was empty after removal - deleted {target.resolve()}");
    }
    return True;
}

impl codebuddy_install(project_dir: Path | None = None) -> None {
    _copy_skill_file("codebuddy", project=`bool(project_dir), project_dir=project_dir);
    target: any = (project_dir or Path(".")) / "CODEBUDDY.md";

    if target.exists() {
        content: any;
        newline: any;
        (content, newline) = _read_keep_newline(target) as any;
        new_content: any = _replace_or_append_section(
            content, _CODEBUDDY_MD_MARKER, _always_on("claude-md")
        );
    } else {
        (content, newline) = ("", "\n");
        new_content = _always_on("claude-md");
    }

    if target.exists() and new_content == content {
        print(f"graphify already configured in {target.resolve()} (no change)");
    } else {
        _write_keep_newline(target, new_content, newline);
        print(f"graphify section written to {target.resolve()}");
    }
    _install_codebuddy_hook(project_dir or Path("."));

    print();
    print("CodeBuddy will now check the knowledge graph before answering");
    print("codebase questions and rebuild it after code changes.");
}

impl _install_codebuddy_hook(project_dir: Path) -> None {
    settings_path: any = project_dir / ".codebuddy" / "settings.json";
    settings_path.parent.mkdir(parents=True, exist_ok=True);

    settings: any = _read_settings_for_merge(settings_path);

    hooks: any = settings.setdefault("hooks", {});
    if not isinstance(hooks, `dict) {
        _refuse_to_modify(settings_path);
    }
    pre_tool: any = hooks.setdefault("PreToolUse", []);
    if not isinstance(pre_tool, `list) {
        _refuse_to_modify(settings_path);
    }

    hooks["PreToolUse"] = _strip_graphify_hooks(pre_tool);
    hooks["PreToolUse"].extend(_claude_pretooluse_hooks());
    _write_settings_with_backup(settings_path, settings);
    print(f"  .codebuddy/settings.json  ->  PreToolUse hooks registered");
}

impl _uninstall_codebuddy_hook(project_dir: Path) -> None {
    settings_path: any = project_dir / ".codebuddy" / "settings.json";
    if not settings_path.exists() {
        return;
    }
    try {
        settings: any = json.loads(settings_path.read_text(encoding="utf-8"));
    } except json.JSONDecodeError {
        return;
    }
    pre_tool: any = settings.get("hooks", {}).get("PreToolUse", []);
    if not isinstance(pre_tool, `list) {
        return;
    }
    filtered: any = _strip_graphify_hooks(pre_tool);
    if filtered == pre_tool {
        return;
    }
    settings["hooks"]["PreToolUse"] = filtered;
    _write_settings_with_backup(settings_path, settings);
    print(f"  .codebuddy/settings.json  ->  PreToolUse hook removed");
}

impl codebuddy_uninstall(
    project_dir: Path | None = None, *, project: bool = False, remove_user_skill: bool | None = None
) -> None {
    explicit_dir: any = project_dir is not None;
    project_dir = project_dir or Path(".");
    if remove_user_skill is None {
        remove_user_skill = not project and not explicit_dir;
    }
    if project or explicit_dir and not remove_user_skill {
        _remove_skill_file("codebuddy", project=True, project_dir=project_dir);
    }
    if remove_user_skill {
        _remove_skill_file("codebuddy", project=False);
        _remove_skill_registration(
            _codebuddy_global_registration(), "  CODEBUDDY.md     ->  ", only_graphify_written=True
        );
    }
    target: any = project_dir / "CODEBUDDY.md";

    if not target.exists() {
        print("No CODEBUDDY.md found in current directory - nothing to do");
        return;
    }

    content: any;
    newline: any;
    (content, newline) = _read_keep_newline(target) as any;
    cleaned: any = _remove_marker_section(content, _CODEBUDDY_MD_MARKER);
    if cleaned is None {
        print("graphify section not found in CODEBUDDY.md - nothing to do");
        return;
    }
    if cleaned or target.is_symlink() {
        _write_keep_newline(target, cleaned + "\n", newline);
        print(f"graphify section removed from {target.resolve()}");
    } else {
        target.unlink();
        print(f"CODEBUDDY.md was empty after removal - deleted {target.resolve()}");
    }

    _uninstall_codebuddy_hook(project_dir or Path("."));
}

impl dispatch_install_cli(cmd: str) -> bool {
    if cmd not in _CLI_INSTALL_COMMANDS {
        return False;
    }
    if cmd == "install" {
        default_platform: any = "windows" if platform.system() == "Windows" else "claude";
        selected_platform: str | None = None;
        project_scope: any = False;
        strict: any = False;
        args: any = sys.argv[2:];
        i: any = 0;
        while i < len(args) {
            arg: any = args[i];
            if arg in ("-h", "--help") {
                _print_install_usage();
                return True;
            }
            if arg == "--project" {
                project_scope = True;
                i += 1;
            } elif arg == "--strict" {
                strict = True;
                i += 1;
            } elif arg.startswith("--platform=") {
                candidate: any = arg.split("=", 1)[1];
                if selected_platform and selected_platform != candidate {
                    print("error: specify install platform only once", file=sys.stderr);
                    sys.exit(1);
                }
                selected_platform = candidate;
                i += 1;
            } elif arg == "--platform" {
                if i + 1 >= len(args) {
                    print("error: --platform requires a value", file=sys.stderr);
                    sys.exit(1);
                }
                candidate = args[i + 1];
                if selected_platform and selected_platform != candidate {
                    print("error: specify install platform only once", file=sys.stderr);
                    sys.exit(1);
                }
                selected_platform = candidate;
                i += 2;
            } elif arg.startswith("-") {
                print(f"error: unknown install option '{arg}'", file=sys.stderr);
                sys.exit(1);
            } else {
                if selected_platform and selected_platform != arg {
                    print("error: specify install platform only once", file=sys.stderr);
                    sys.exit(1);
                }
                selected_platform = arg;
                i += 1;
            }
        }
        chosen_platform: any = selected_platform or default_platform;
        if project_scope {
            _project_install(chosen_platform, Path("."), strict=strict);
        } else {
            if strict {
                print(
                    "note: --strict applies to the project PreToolUse hook; run `graphify install --project --strict` or `graphify claude install --strict`.",
                    file=sys.stderr,
                );
            }
            install(platform=chosen_platform);
        }
    } elif cmd == "uninstall" {
        args = sys.argv[2:];
        purge: any = "--purge" in args;
        project_scope = "--project" in args;
        selected_platform = None;
        i = 0;
        while i < len(args) {
            arg = args[i];
            if arg in ("--purge", "--project") {
                i += 1;
            } elif arg.startswith("--platform=") {
                selected_platform = arg.split("=", 1)[1];
                i += 1;
            } elif arg == "--platform" {
                if i + 1 >= len(args) {
                    print("error: --platform requires a value", file=sys.stderr);
                    sys.exit(1);
                }
                selected_platform = args[i + 1];
                i += 2;
            } elif arg.startswith("-") {
                print(f"error: unknown uninstall option '{arg}'", file=sys.stderr);
                sys.exit(1);
            } else {
                selected_platform = arg;
                i += 1;
            }
        }
        if project_scope {
            if selected_platform {
                _project_uninstall(selected_platform, Path("."));
            } else {
                _project_uninstall_all(Path("."));
            }
        } else {
            uninstall_all(purge=purge);
        }
    } elif cmd == "claude" {
        subcmd: any = sys.argv[2] if len(sys.argv) > 2 else "";
        if subcmd == "install" {
            _strict: any = "--strict" in sys.argv[3:];
            if "--project" in sys.argv[3:] {
                _project_install("claude", Path("."), strict=_strict);
            } else {
                claude_install(strict=_strict);
            }
        } elif subcmd == "uninstall" {
            if "--project" in sys.argv[3:] {
                _project_uninstall("claude", Path("."));
            } else {
                claude_uninstall();
            }
        } else {
            print("Usage: graphify claude [install|uninstall]", file=sys.stderr);
            sys.exit(1);
        }
    } elif cmd == "codebuddy" {
        subcmd = sys.argv[2] if len(sys.argv) > 2 else "";
        if subcmd == "install" {
            codebuddy_install();
        } elif subcmd == "uninstall" {
            codebuddy_uninstall();
        } else {
            print("Usage: graphify codebuddy [install|uninstall]", file=sys.stderr);
            sys.exit(1);
        }
    } elif cmd == "gemini" {
        subcmd = sys.argv[2] if len(sys.argv) > 2 else "";
        if subcmd == "install" {
            gemini_install(project="--project" in sys.argv[3:]);
        } elif subcmd == "uninstall" {
            gemini_uninstall(project="--project" in sys.argv[3:]);
        } else {
            print("Usage: graphify gemini [install|uninstall]", file=sys.stderr);
            sys.exit(1);
        }
    } elif cmd == "cursor" {
        subcmd = sys.argv[2] if len(sys.argv) > 2 else "";
        if subcmd == "install" {
            _cursor_install(Path("."));
        } elif subcmd == "uninstall" {
            _cursor_uninstall(Path("."));
        } else {
            print("Usage: graphify cursor [install|uninstall]", file=sys.stderr);
            sys.exit(1);
        }
    } elif cmd == "vscode" {
        subcmd = sys.argv[2] if len(sys.argv) > 2 else "";
        if subcmd == "install" {
            vscode_install();
        } elif subcmd == "uninstall" {
            vscode_uninstall();
        } else {
            print("Usage: graphify vscode [install|uninstall]", file=sys.stderr);
            sys.exit(1);
        }
    } elif cmd == "copilot" {
        subcmd = sys.argv[2] if len(sys.argv) > 2 else "";
        if subcmd == "install" {
            if "--project" in sys.argv[3:] {
                _project_install("copilot", Path("."));
            } else {
                install(platform="copilot");
            }
        } elif subcmd == "uninstall" {
            if "--project" in sys.argv[3:] {
                _project_uninstall("copilot", Path("."));
            } else {
                removed: any = _remove_skill_file("copilot");
                print("skill removed" if removed else "nothing to remove");
            }
        } else {
            print("Usage: graphify copilot [install|uninstall]", file=sys.stderr);
            sys.exit(1);
        }
    } elif cmd == "kilo" {
        subcmd = sys.argv[2] if len(sys.argv) > 2 else "";
        if subcmd == "install" {
            _kilo_install(Path("."));
        } elif subcmd == "uninstall" {
            _kilo_uninstall(Path("."));
        } else {
            print("Usage: graphify kilo [install|uninstall]", file=sys.stderr);
            sys.exit(1);
        }
    } elif cmd == "kiro" {
        subcmd = sys.argv[2] if len(sys.argv) > 2 else "";
        if subcmd == "install" {
            _kiro_install(Path("."));
        } elif subcmd == "uninstall" {
            _kiro_uninstall(Path("."));
        } else {
            print("Usage: graphify kiro [install|uninstall]", file=sys.stderr);
            sys.exit(1);
        }
    } elif cmd == "devin" {
        subcmd = sys.argv[2] if len(sys.argv) > 2 else "";
        if subcmd == "install" {
            if "--project" in sys.argv[3:] {
                _project_install("devin", Path("."));
            } else {
                install(platform="devin");
            }
        } elif subcmd == "uninstall" {
            if "--project" in sys.argv[3:] {
                _project_uninstall("devin", Path("."));
            } else {
                removed = _remove_skill_file("devin");
                print("skill removed" if removed else "nothing to remove");
            }
        } else {
            print("Usage: graphify devin [install|uninstall]", file=sys.stderr);
            sys.exit(1);
        }
    } elif cmd == "pi" {
        subcmd = sys.argv[2] if len(sys.argv) > 2 else "";
        if subcmd == "install" {
            if "--project" in sys.argv[3:] {
                _project_install("pi", Path("."));
            } else {
                install("pi");
            }
        } elif subcmd == "uninstall" {
            if "--project" in sys.argv[3:] {
                _project_uninstall("pi", Path("."));
            } else {
                _remove_skill_file("pi");
            }
        } elif subcmd == "guard" and sys.argv[3:] in (["install"], ["uninstall"], ["path"]) {
            package_path: any = Path(__file__).resolve().parent / "pi";
            if sys.argv[3] == "path" {
                print(package_path);
                return True;
            }
            pi: any = shutil.which("pi");
            if not pi {
                print("error: install Pi (pi) and add it to PATH first", file=sys.stderr);
                sys.exit(1);
            }
            import subprocess;
            verb: any = "install" if sys.argv[3] == "install" else "remove";
            result: any = subprocess.run([pi, verb, `str(package_path)], check=False);
            if result.returncode {
                sys.exit(result.returncode);
            }
        } else {
            print(
                "Usage: graphify pi [install|uninstall] | graphify pi guard [install|uninstall|path]",
                file=sys.stderr,
            );
            sys.exit(1);
        }
    } elif cmd == "amp" {
        subcmd = sys.argv[2] if len(sys.argv) > 2 else "";
        if subcmd == "install" {
            if "--project" in sys.argv[3:] {
                _project_install("amp", Path("."));
            } else {
                _amp_install(Path("."));
            }
        } elif subcmd == "uninstall" {
            if "--project" in sys.argv[3:] {
                _project_uninstall("amp", Path("."));
            } else {
                _amp_uninstall(Path("."));
            }
        } else {
            print("Usage: graphify amp [install|uninstall]", file=sys.stderr);
            sys.exit(1);
        }
    } elif cmd in ("agents", "skills") {
        subcmd = sys.argv[2] if len(sys.argv) > 2 else "";
        if subcmd == "install" {
            if "--project" in sys.argv[3:] {
                _project_install("agents", Path("."));
            } else {
                _agents_platform_install(Path("."));
            }
        } elif subcmd == "uninstall" {
            if "--project" in sys.argv[3:] {
                _project_uninstall("agents", Path("."));
            } else {
                _agents_platform_uninstall(Path("."));
            }
        } else {
            print(f"Usage: graphify {cmd} [install|uninstall]", file=sys.stderr);
            sys.exit(1);
        }
    } elif cmd in ("aider", "codex", "opencode", "claw", "droid", "trae", "trae-cn", "hermes") {
        subcmd = sys.argv[2] if len(sys.argv) > 2 else "";
        if subcmd == "install" {
            if "--project" in sys.argv[3:] {
                _project_install(cmd, Path("."));
            } else {
                _agents_install(Path("."), cmd);
            }
        } elif subcmd == "uninstall" {
            if "--project" in sys.argv[3:] {
                _project_uninstall(cmd, Path("."));
            } else {
                _agents_uninstall(Path("."), platform=cmd);
                if cmd == "codex" {
                    _uninstall_codex_hook(Path("."));
                }
            }
        } else {
            print(f"Usage: graphify {cmd} [install|uninstall]", file=sys.stderr);
            sys.exit(1);
        }
    } elif cmd == "antigravity" {
        subcmd = sys.argv[2] if len(sys.argv) > 2 else "";
        if subcmd == "install" {
            if "--project" in sys.argv[3:] {
                _project_install("antigravity", Path("."));
            } else {
                _antigravity_install(Path("."));
            }
        } elif subcmd == "uninstall" {
            if "--project" in sys.argv[3:] {
                _project_uninstall("antigravity", Path("."));
            } else {
                _antigravity_uninstall(Path("."));
            }
        } else {
            print("Usage: graphify antigravity [install|uninstall]", file=sys.stderr);
            sys.exit(1);
        }
    }
    return True;
}
