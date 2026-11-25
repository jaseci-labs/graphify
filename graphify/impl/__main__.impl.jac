impl __getattr__(name: str) -> str {
    base: any = _ALWAYS_ON_ALIASES.get(name);
    if base is not None {
        return _always_on(base);
    }
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}");
}

impl _check_skill_version(skill_dst: Path, platform_names: "list[str] | None" = None) {
    if platform_names is None {
        try {
            platform_names = [
                name
                for name in _skill_platforms()
                if _platform_skill_destination(name) == skill_dst
            ];
        } except Exception {
            platform_names = [];
        }
    }
    version_file: any = skill_dst.parent / ".graphify_version";
    try {
        if not version_file.exists() {
            return;
        }
    } except OSError {
        return;
    }
    try {
        skill_exists: any = skill_dst.exists();
    } except OSError {
        return;
    }
    if not skill_exists {
        print(
            "  warning: skill dir exists but SKILL.md is missing. Run 'graphify install' to repair.",
            file=sys.stderr,
        );
        return;
    }
    try {
        body: any = skill_dst.read_text(encoding="utf-8");
    } except OSError {
        body = "";
    }
    if "references/" in body and not (skill_dst.parent / "references").exists() {
        print(
            "  warning: skill references/ sidecar is missing. Run 'graphify install' to repair.",
            file=sys.stderr,
        );
    }
    try {
        installed: any = version_file.read_text(encoding="utf-8").strip();
    } except OSError {
        return;
    }
    if installed != __version__ {
        if _version_tuple(installed) > _version_tuple(__version__) {
            print(
                f"  warning: skill is from graphify {installed}, but the package is {__version__} (older). Upgrade the package (e.g. 'uv tool upgrade graphifyy' or 'pip install -U graphifyy'); running 'graphify install' would downgrade the skill.",
                file=sys.stderr,
            );
        } else {
            _cmd: any = f"graphify install --platform {platform_names[0]}"
                if platform_names
                else "graphify install";
            print(
                f"  warning: skill at {skill_dst.parent} is from graphify {installed}, package is {__version__}. Run '{_cmd}' to update it (a plain 'graphify install' refreshes only the detected platform).",
                file=sys.stderr,
            );
        }
    }
}

impl _version_tuple(version: str) -> tuple[int, ...] {
    parts: list[int] = [];
    for segment in `str(version).split(".") {
        digits: any = "";
        for ch in segment {
            if ch.isdigit() {
                digits += ch;
            } else {
                break;
            }
        }
        parts.append(`int(digits) if digits else 0);
    }
    return `tuple(parts);
}

impl _refresh_stale_skills {
    name: any;
    if os.environ.get("GRAPHIFY_NO_AUTO_REFRESH", "").strip().lower() in ("1", "true", "yes") {
        return;
    }
    if __version__ == "unknown" {
        return;
    }
    if platform.system() == "Windows" {
        other_os: any = {"claude", "antigravity"};
    } else {
        other_os = {"windows", "antigravity-windows"};
    }
    candidates: any = [("vscode", _vscode_skill_destination)];
    candidates += [
        (name, functools.partial(_platform_skill_destination, name))
        for name in _skill_platforms()
        if name not in other_os
    ];
    writers: dict[Path, list[tuple[str, Path]]] = {};
    for (name, destination) in candidates {
        try {
            skill_dst: any = destination();
        } except Exception {
            continue;
        }
        try {
            real: any = skill_dst.resolve();
        } except (OSError, RuntimeError) {
            real = skill_dst;
        }
        writers.setdefault(real, []).append((name, skill_dst));
    }
    for entries in writers.values() {
        if len(entries) != 1 or entries[0][0] == "vscode" {
            continue;
        }
        (name, skill_dst) = entries[0] as any;
        if _stale_stamp(skill_dst) is None {
            continue;
        }
        owned: any;
        with _skill_lock(skill_dst.parent, wait=False) as owned {
            installed: any = _stale_stamp(skill_dst) if owned else None;
            if installed is not None {
                _refresh_one_skill(name, skill_dst, installed);
            }
        }
    }
}

impl _stale_stamp(skill_dst: Path) -> str | None {
    version_file: any = skill_dst.parent / ".graphify_version";
    try {
        if not (version_file.is_file() and skill_dst.is_file()) {
            return None;
        }
        installed: any = version_file.read_text(encoding="utf-8").strip();
    } except OSError {
        return None;
    }
    if installed == __version__ or _version_tuple(installed) > _version_tuple(__version__) {
        return None;
    }
    return installed;
}

impl _skill_platforms -> list[str] {
    return `list(dict.fromkeys([*_PLATFORM_CONFIG, "gemini"]));
}

impl _refresh_one_skill(name: str, skill_dst: Path, installed: str) {
    backup: any = skill_dst.with_suffix(skill_dst.suffix + ".bak");
    captured: any = io.StringIO();
    try {
        with contextlib.redirect_stdout(captured) {
            _copy_skill_file(name);
        }
    } except (Exception, SystemExit) as exc {
        detail: any = "" if isinstance(exc, SystemExit) else f": {exc}";
        print(
            f"graphify: could not refresh skill at {skill_dst.parent} ({installed} -> {__version__}){detail}",
            file=sys.stderr,
        );
        return;
    }
    print(
        f"graphify: refreshed skill at {skill_dst.parent} ({installed} -> {__version__}); set GRAPHIFY_NO_AUTO_REFRESH=1 to disable",
        file=sys.stderr,
    );
    for line in captured.getvalue().splitlines() {
        if `str(backup) in line {
            print(line, file=sys.stderr);
        }
    }
}

impl _opencode_loads_current_plugin -> bool {
    exe: any = shutil.which("opencode");
    if exe is None {
        return False;
    }
    try {
        out: any = subprocess.run(
            [exe, "--version"], capture_output=True, text=True, timeout=10
        ).stdout;
    } except (OSError, subprocess.SubprocessError) {
        return False;
    }
    found: any = re.search("(\\d+)\\.(\\d+)\\.(\\d+)", out);
    return found is not None
        and operator.ge(`tuple(`int(part) for part in found.groups()), (1, 3, 4));
}

impl _refresh_v1_opencode_plugins {
    directory: any;
    plugin_file: any;
    if os.environ.get("GRAPHIFY_NO_AUTO_REFRESH", "").strip().lower() in ("1", "true", "yes") {
        return;
    }
    try {
        directories: any = dict.fromkeys(
            d.resolve()
            for d in (
                _opencode_dir(project=True, project_dir=Path.cwd()),
                _opencode_dir(project=True, project_dir=Path.home()),
                _opencode_dir(project=False),
            ),
        );
    } except (OSError, RuntimeError) {
        return;
    }
    loadable: "bool | None" = None;
    for directory_ in directories {
        directory = directory_;
        plugin_file = directory / _OPENCODE_PLUGIN_PATH.relative_to(".opencode");
        def pending -> "bool | None" {
            try {
                body: any = plugin_file.read_text(encoding="utf-8");
            } except (OSError, UnicodeDecodeError) {
                return None;
            }
            if not body.startswith(_OPENCODE_PLUGIN_HEADER) {
                return None;
            }
            if _opencode_plugin_is_v1_only(body) {
                return True;
            }
            return False if _opencode_config_names_plugin(directory) else None;
        }

        stale: any = pending();
        if stale is None {
            continue;
        }
        if stale {
            if loadable is None {
                loadable = _opencode_loads_current_plugin();
            }
            if not loadable {
                continue;
            }
        }
        owned: any;
        with _skill_lock(plugin_file.parent, wait=False) as owned {
            stale = pending() if owned else None;
            if stale is None {
                continue;
            }
            captured: any = io.StringIO();
            try {
                with contextlib.redirect_stdout(captured) {
                    if stale {
                        _install_opencode_plugin(directory);
                        dropped: any = False;
                    } else {
                        dropped = _drop_opencode_config_entry(directory);
                    }
                }
            } except Exception as exc {
                print(f"graphify: could not refresh {plugin_file}: {exc}", file=sys.stderr);
                continue;
            }
        }
        if stale {
            print(
                f"graphify: refreshed {plugin_file} so OpenCode 2 can load it; set GRAPHIFY_NO_AUTO_REFRESH=1 to disable",
                file=sys.stderr,
            );
            for line in captured.getvalue().splitlines() {
                if "by hand" in line {
                    print(line, file=sys.stderr);
                }
            }
        } elif dropped {
            print(
                f"graphify: removed the stale graphify entry from {directory / _OPENCODE_CONFIG_PATH.name}; set GRAPHIFY_NO_AUTO_REFRESH=1 to disable",
                file=sys.stderr,
            );
        }
    }
}

impl _silence_broken_pipe {
    try {
        devnull: any = os.open(os.devnull, os.O_WRONLY);
        os.dup2(devnull, sys.stdout.fileno());
    } except Exception {}
    sys.exit(0);
}

impl _pin_hash_seed_if_needed {
    if len(sys.argv) < 2 or sys.argv[1] not in _HASHSEED_PINNED_COMMANDS {
        return;
    }
    if "PYTHONHASHSEED" in os.environ or "PYTEST_CURRENT_TEST" in os.environ {
        return;
    }
    try {
        _reexec(
            [sys.executable, "-m", "graphify", *sys.argv[1:]], `dict(os.environ, PYTHONHASHSEED="0")
        );
    } except OSError {}
}

impl _reexec(argv: list[str], env: dict[str, str], windows: bool | None = None) {
    if windows is None {
        windows = operator.eq(os.name, "nt");
    }
    if windows {
        import subprocess;
        sys.stdout.flush();
        sys.stderr.flush();
        raise SystemExit(subprocess.run(argv, env=env).returncode);
    }
    os.execvpe(argv[0], argv, env);
}

impl main {
    _pin_hash_seed_if_needed();
    try {
        _run_cli();
        sys.stdout.flush();
    } except BrokenPipeError {
        _silence_broken_pipe();
    } except OSError as exc {
        if exc.errno in (errno.EPIPE, errno.EINVAL) {
            _silence_broken_pipe();
        } else {
            raise;
        }
    }
}

impl _run_cli {
    _silent_cmds: any;
    _help_flags: any;
    for _stream in (sys.stdout, sys.stderr) {
        if _stream is not None and hasattr(_stream, "reconfigure") {
            try {
                _stream.reconfigure(encoding="utf-8", errors="replace");
            } except Exception {}
        }
    }
    _silent_cmds = {"install", "uninstall", "hook-check", "hook-guard"};
    _FREE_TEXT_CMDS: any = {
        "query",
        "explain",
        "section",
        "path",
        "save-result",
        "install",
        "uninstall",
    };
    _help_flags = {"-h", "--help", "-?"};
    _informational: any = operator.lt(len(sys.argv), 2)
        or sys.argv[1] in {"-v", "--version", "version", *_help_flags}
        or sys.argv[1] not in _FREE_TEXT_CMDS and `any(a in _help_flags for a in sys.argv[2:]);
    if not `any(arg in _silent_cmds for arg in sys.argv) {
        if not _informational {
            _refresh_stale_skills();
            _refresh_v1_opencode_plugins();
        }
        for skill_dst in {_platform_skill_destination(name) for name in _skill_platforms()} {
            _check_skill_version(skill_dst);
        }
    }

    if len(sys.argv) >= 2 and sys.argv[1] in ("-v", "--version", "version") {
        print(f"graphify {__version__}");
        return;
    }

    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help", "-?") {
        _print_banner();
        print("Usage: graphify <command>");
        print();
        print("Commands:");
        _platform_values: any = "|".join([*_PLATFORM_CONFIG, "gemini", "cursor"]);
        print(f"  install [--platform P]  copy skill to platform config dir ({_platform_values})");
        print("  uninstall               remove graphify from all detected platforms in one shot");
        print("    --purge                 also delete graphify-out/ directory");
        print("  path \"A\" \"B\"            shortest path between two nodes in graph.json");
        print("    --graph <path>          path to graph.json (default graphify-out/graph.json)");
        print("    --directed              force a directed search (the default;");
        print("                            the JSON 'directed' flag is NOT consulted)");
        print("    --undirected            ignore edge direction");
        print("  explain \"X\"             plain-language explanation of a node and its neighbors");
        print("    --all                   list every connection (default: the 20 most connected)");
        print("    --graph <path>          path to graph.json (default graphify-out/graph.json)");
        print(
            "  section \"X\"             print the text of a Markdown section (heading and subsections)",
        );
        print(
            "                            \"docs/api.md#X\" picks X in one file when several share it",
        );
        print("    --max-chars N           cap on printed characters (default 8000)");
        print("    --graph <path>          path to graph.json (default graphify-out/graph.json)");
        print("  diagnose multigraph    report same-endpoint edge collapse risk in graph.json");
        print("    --graph <path>          path to graph/extraction JSON");
        print("                            (default graphify-out/graph.json)");
        print("    --json                  emit machine-readable JSON");
        print("    --max-examples N        max same-endpoint examples to print (default 5)");
        print("    --directed              force directed post-build simulation");
        print("    --undirected            force undirected post-build simulation");
        print("                            (default follows JSON directed flag;");
        print("                             raw extraction with no flag defaults directed)");
        print("    --extract-path PATH     extractor source for suppression scan");
        print(
            "  clone <github-url>      clone a GitHub repo locally and print its path for /graphify"
        );
        print(
            "  merge-driver <base> <current> <other>  git merge driver: union-merge two graph.json files (set up via hook install)",
        );
        print(
            "  merge-graphs <g1> <g2>  merge two or more graph.json files into one cross-repo graph"
        );
        print("    --out <path>            output path (default: graphify-out/merged-graph.json)");
        print("    --previous <path>       restore the previous merged clustering's community ids");
        print(
            "                            (by node id) instead of each input's own per-source ids,"
        );
        print("                            so a later cluster-only run reuses labels correctly");
        print("    --branch <branch>       checkout a specific branch (default: repo default)");
        print(
            "    --out <dir>             clone to a custom directory (default: ~/.graphify/repos/<owner>/<repo>)",
        );
        print("  add <url>               fetch a URL and save it to ./raw, then update the graph");
        print("    --author \"Name\"         tag the author of the content");
        print("    --contributor \"Name\"    tag who added it to the corpus");
        print("    --dir <path>            target directory (default: ./raw)");
        print("  watch <path>            watch a folder and rebuild the graph on code changes");
        print(
            "  update <path>           re-extract code files and update the graph (no LLM needed)"
        );
        print(
            "    --force                 overwrite graph.json even if the rebuild has fewer nodes"
        );
        print(
            "                            (also: GRAPHIFY_FORCE=1 env var; use after refactors that delete code)",
        );
        print("    --no-cluster            skip clustering, write raw extraction only");
        print(
            "  cluster-only <path>     rerun clustering on an existing graph.json and regenerate report",
        );
        print(
            "    --no-viz                skip graph.html generation (useful for >5000 node graphs / CI)",
        );
        print(
            "    --graph <path>          path to graph.json (default <path>/graphify-out/graph.json)",
        );
        print(
            "    --no-label              keep 'Community N' placeholders (skip LLM community naming)",
        );
        print(
            "    --backend=<name>        backend to use for community naming (default: auto-detect)"
        );
        print(
            "    --model=<name>          model to use for community naming (claude-cli also reads GRAPHIFY_CLAUDE_CLI_MODEL)",
        );
        print(
            "    --max-concurrency=N     parallel community-labeling LLM calls (default 4; forced to 1 for ollama/claude-cli)",
        );
        print(
            "    --batch-size=N          communities per labeling LLM call (default 100, sized for ~16k context; use 40 for 8k)",
        );
        print(
            "  label <path>            (re)name communities with the configured LLM backend, regenerate report",
        );
        print(
            "    --missing-only         keep existing labels and only name missing/placeholder communities",
        );
        print("    --backend=<name>        backend to use (default: auto-detect from API keys)");
        print(
            "    --model=<name>          model to use for community naming (claude-cli also reads GRAPHIFY_CLAUDE_CLI_MODEL)",
        );
        print(
            "    --max-concurrency=N     parallel labeling LLM calls (default 4; forced to 1 for ollama/claude-cli)",
        );
        print("    --batch-size=N          communities per labeling LLM call (default 100)");
        print("  query \"<question>\"       BFS traversal of graph.json for a question");
        print("    --dfs                   use depth-first instead of breadth-first");
        print("    --context C             explicit edge-context filter (repeatable)");
        print("    --seed X                start at node X (id, label or file path; repeatable)");
        print("                            instead of the question's keyword matches");
        print("    --budget N, --budget=N  cap output at N tokens (default 2000)");
        print("    --depth N, --depth=N    traversal depth 1-6 (default 2)");
        print(
            "                            absent options use the selected graph project's .graphifyrc",
        );
        print(
            "                            query_budget / query_depth. Explicit options override project values.",
        );
        print("    --graph <path>          path to graph.json (default graphify-out/graph.json)");
        print("  query, path and explain exit 0 with an answer, 3 when a name is ambiguous");
        print("  (the candidates are listed), 4 when no node matches");
        print("  affected \"X\"             reverse traversal to find nodes impacted by X");
        print("    --relation R            edge relation to traverse in reverse (repeatable)");
        print("    --depth N               reverse traversal depth (default 2)");
        print("    --graph <path>          path to graph.json (default graphify-out/graph.json)");
        print("  god-nodes               list the most connected nodes (architectural hubs)");
        print("    --top N                 how many to show (default 10)");
        print("    --graph <path>          path to graph.json (default graphify-out/graph.json)");
        print("    --json                  emit JSON instead of text");
        print("  prs                     PR dashboard: CI state, review status, worktree mapping");
        print(
            "  save-result             save a Q&A result to graphify-out/memory/ for graph feedback loop",
        );
        print("    --question Q            the question asked");
        print("    --answer A              the answer to save");
        print("    --type T                query type: query|path_query|explain (default: query)");
        print("    --nodes N1 N2 ...       source node labels cited in the answer");
        print("    --outcome O             work-memory signal: useful|dead_end|corrected");
        print(
            "    --correction TEXT       what the right answer was (pairs with --outcome corrected)"
        );
        print("    --memory-dir DIR        memory directory (default: graphify-out/memory)");
        print(
            "  reflect                 aggregate graphify-out/memory/ outcomes into a deterministic lessons doc",
        );
        print("    --memory-dir DIR        memory directory (default: graphify-out/memory)");
        print(
            "    --out FILE              output path (default: graphify-out/reflections/LESSONS.md)"
        );
        print(
            "    --graph PATH            graph.json, for community grouping + dropping stale nodes (optional)",
        );
        print(
            "    --analysis PATH         .graphify_analysis.json (optional, auto-detected next to --graph)",
        );
        print(
            "    --labels PATH           .graphify_labels.json (optional, auto-detected next to --graph)",
        );
        print("    --half-life-days N      signal weight halves every N days (default 30)");
        print("    --min-corroboration N   distinct useful results to prefer a node (default 2)");
        print(
            "  check-update <path>     check needs_update flag and notify if semantic re-extraction is pending (cron-safe)",
        );
        print("  tree                    emit a D3 v7 collapsible-tree HTML for graph.json");
        print("    --graph PATH            path to graph.json (default graphify-out/graph.json)");
        print("    --output HTML           output path (default graphify-out/GRAPH_TREE.html)");
        print("    --root PATH             filesystem root for the hierarchy");
        print("    --max-children N        cap children per node (default 200)");
        print("    --top-k-edges N         per-symbol outbound edges in inspector (default 12)");
        print("    --label NAME            project label in header");
        print(
            "  extract <path>          headless full extraction (AST + semantic LLM) for CI/scripts"
        );
        print(
            "    --backend B             gemini|kimi|claude|openai|deepseek|ollama (default: whichever API key is set)",
        );
        print(
            "                            openai also reaches self-hosted OpenAI-compatible servers (llama.cpp,",
        );
        print(
            "                            vLLM, LM Studio): set OPENAI_BASE_URL (e.g. http://localhost:8080/v1)",
        );
        print("                            and OPENAI_MODEL to the model name your server serves");
        print(
            "                            claude also reaches custom Anthropic-compatible endpoints (LiteLLM",
        );
        print(
            "                            proxy, gateways): set ANTHROPIC_BASE_URL and ANTHROPIC_MODEL",
        );
        print(
            "                            GRAPHIFY_CLAUDE_PROMPT_CACHE=0 disables Claude system-prompt caching",
        );
        print("                            (default: enabled; set 1 to explicitly enable)");
        print("    --model M               override backend default model");
        print("    --mode deep             aggressive INFERRED-edge semantic extraction");
        print("    --force                 full re-scan and re-dispatch: skip the incremental");
        print(
            "                            manifest gate and semantic cache reads (env: GRAPHIFY_FORCE=1)",
        );
        print("    --max-workers N         AST extraction subprocess count (default: cpu_count)");
        print(
            "    --token-budget N        per-chunk token cap for semantic extraction (default: 60000)",
        );
        print(
            "    --max-concurrency N     parallel semantic chunks in flight (default: 4; set 1 for local LLMs)",
        );
        print(
            "    --api-timeout S         per-request timeout in seconds for the LLM client (default: 600)",
        );
        print(
            "    --out DIR, --output DIR output dir (default: <path>); writes <DIR>/graphify-out/"
        );
        print(
            "    --google-workspace      export .gdoc/.gsheet/.gslides shortcuts via gws before extraction",
        );
        print(
            "    --no-gitignore         ignore .gitignore and .git/info/exclude (prioritizes .graphifyignore)",
        );
        print("    --no-cluster            skip clustering, write raw extraction only");
        print(
            "    --code-only             index code (local AST, no API key) and skip doc/paper/image files",
        );
        print("    --postgres DSN          extract schema from a live PostgreSQL database");
        print("                            maps tables, views, functions + FK relationships;");
        print("                            column-level detail is not represented in the graph");
        print("    --cargo                 extract crate→crate deps from Cargo.toml");
        print("    --global                also merge the resulting graph into the global graph");
        print("    --as <tag>              repo tag for --global (default: target directory name)");
        print("  provider [list|show|add|remove]  manage custom LLM providers");
        print(
            "  global add <graph.json>  add/update a project graph in the global graph (~/.graphify/global-graph.json)",
        );
        print("    --as <tag>               repo tag (default: parent directory name)");
        print("  global remove <tag>      remove a repo's nodes from the global graph");
        print("  global list              list repos in the global graph");
        print("  global path              print path to the global graph file");
        print("  benchmark [graph.json]  measure token reduction vs naive full-corpus approach");
        print(
            "  export html             emit interactive graph.html [--graph PATH] [--labels PATH] [--node-limit N, default 5000] [--no-viz]",
        );
        print("  export callflow-html    emit Mermaid-based architecture/call-flow HTML");
        print(
            "                          [GRAPH|DIR] [--graph PATH] [--labels PATH] [--report PATH] [--sections PATH] [--output HTML]",
        );
        print(
            "                          [--lang auto|zh-CN|en] [--max-sections N] [--diagram-scale N]",
        );
        print(
            "  export obsidian         emit Obsidian vault notes + canvas [--graph PATH] [--labels PATH] [--dir PATH]",
        );
        print(
            "  export wiki             emit wiki markdown articles [--graph PATH] [--labels PATH]"
        );
        print("  export svg              emit graph.svg [--graph PATH] [--labels PATH]");
        print("  export graphml          emit GraphML [--graph PATH]");
        print(
            "  export neo4j            emit Cypher or push to Neo4j [--graph PATH] [--push URI] [--user U] [--password P]",
        );
        print(
            "                          (or set NEO4J_PASSWORD instead of --password to keep it off argv)",
        );
        print(
            "  export falkordb         emit Cypher or push to FalkorDB [--graph PATH] [--push URI] [--user U] [--password P]",
        );
        print(
            "                          (or set FALKORDB_PASSWORD instead of --password to keep it off argv)",
        );
        print(
            "  hook install            install post-commit/post-checkout/post-merge/post-rewrite git hooks (all platforms)",
        );
        print("  hook uninstall          remove git hooks");
        print("  hook status             check if git hooks are installed");
        print("  gemini install          write GEMINI.md section + BeforeTool hook (Gemini CLI)");
        print("  gemini uninstall        remove GEMINI.md section + BeforeTool hook");
        print("  cursor install          write .cursor/rules/graphify.mdc (Cursor)");
        print("  cursor uninstall        remove .cursor/rules/graphify.mdc");
        print(
            "  claude install          write graphify section to CLAUDE.md (or the AGENTS.md Claude Code reads) + PreToolUse hook",
        );
        print("  claude uninstall        remove graphify section from CLAUDE.md + PreToolUse hook");
        print(
            "  codebuddy install       write graphify section to CODEBUDDY.md + PreToolUse hook (CodeBuddy)",
        );
        print(
            "  codebuddy uninstall     remove graphify section from CODEBUDDY.md + PreToolUse hook"
        );
        print("  codex install           write graphify section to AGENTS.md (Codex)");
        print("  codex uninstall         remove graphify section from AGENTS.md");
        print(
            "  opencode install        write graphify section to AGENTS.md + tool.execute.before plugin (OpenCode)",
        );
        print("  opencode uninstall      remove graphify section from AGENTS.md + plugin");
        print(
            "  kilo install            install native Kilo skill + command + AGENTS.md + .kilo plugin",
        );
        print(
            "  kilo uninstall          remove native Kilo skill + command + AGENTS.md + .kilo plugin",
        );
        print("  aider install           write graphify section to AGENTS.md (Aider)");
        print("  aider uninstall         remove graphify section from AGENTS.md");
        print("  amp install             copy graphify skill + write AGENTS.md section (Amp)");
        print("  amp uninstall           remove graphify skill + AGENTS.md section (Amp)");
        print(
            "  copilot install         copy graphify skill to ~/.copilot/skills (GitHub Copilot CLI)",
        );
        print("  copilot uninstall       remove graphify skill from ~/.copilot/skills");
        print(
            "  vscode install          configure VS Code Copilot Chat (skill + .github/copilot-instructions.md)",
        );
        print("  vscode uninstall        remove VS Code Copilot Chat configuration");
        print("  claw install            write graphify section to AGENTS.md (OpenClaw)");
        print("  claw uninstall          remove graphify section from AGENTS.md");
        print("  droid install           write graphify section to AGENTS.md (Factory Droid)");
        print("  droid uninstall        remove graphify section from AGENTS.md");
        print("  trae install            write graphify section to AGENTS.md (Trae)");
        print("  trae uninstall         remove graphify section from AGENTS.md");
        print("  trae-cn install         write graphify section to AGENTS.md (Trae CN)");
        print("  trae-cn uninstall      remove graphify section from AGENTS.md");
        print(
            "  antigravity install     write .agents/rules + .agents/workflows + skill (Google Antigravity)",
        );
        print("  antigravity uninstall   remove .agents/rules, .agents/workflows, and skill");
        print("  hermes install          write skill to ~/.hermes/skills/graphify/ (Hermes)");
        print("  hermes uninstall        remove skill from ~/.hermes/skills/graphify/");
        print(
            "  kiro install            write skill to .kiro/skills/graphify/ + steering file (Kiro IDE/CLI)",
        );
        print("  kiro uninstall          remove skill + steering file");
        print(
            "  pi install              write skill to ~/.pi/agent/skills/graphify/ (Pi coding agent)",
        );
        print("  pi uninstall            remove skill from ~/.pi/agent/skills/graphify/");
        print("  pi guard install        register the native Pi guard extension via `pi install`");
        print("  pi guard uninstall      unregister it via `pi remove`");
        print(
            "  pi guard path           print the guard package path (e.g. for `omp plugin install`)"
        );
        print(
            "  devin install           write skill to ~/.config/devin/skills/graphify/ (Devin CLI)"
        );
        print("  devin uninstall         remove skill from ~/.config/devin/skills/graphify/");
        print();
        print("Prefer a hosted version? Graphify Cloud has a free plan, no card required:");
        print(
            "https://app.graphify.com/signup?utm_source=cli&utm_medium=terminal&utm_campaign=oss&utm_content=help",
        );
        print();
        return;
    }

    cmd: any = sys.argv[1];
    if cmd not in _FREE_TEXT_CMDS and `any(a in _help_flags for a in sys.argv[2:]) {
        print(f"Run 'graphify --help' for full usage.");
        return;
    }

    if dispatch_install_cli(cmd) {
        return;
    }
    dispatch_command(cmd);
}
