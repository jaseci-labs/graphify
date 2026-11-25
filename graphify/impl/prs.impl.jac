impl _c(code: str, text: str) -> str {
    if _NO_COLOR {
        return text;
    }
    return f"\x1b[{code}m{text}\x1b[0m";
}

impl green(t: str) -> str {
    return _c("32", t);
}

impl red(t: str) -> str {
    return _c("31", t);
}

impl yellow(t: str) -> str {
    return _c("33", t);
}

impl cyan(t: str) -> str {
    return _c("36", t);
}

impl bold(t: str) -> str {
    return _c("1", t);
}

impl dim(t: str) -> str {
    return _c("2", t);
}

impl magenta(t: str) -> str {
    return _c("35", t);
}

impl _pad(s: str, width: int) -> str {
    visible_len: any = len(_ANSI_RE.sub("", s));
    return s + " " * max(0, width - visible_len);
}

impl _classify(pr: "PRInfo", base: str = "v8") -> str {
    if pr.base_branch != base {
        return "WRONG-BASE";
    }
    if pr.ci_status == "FAILURE" {
        return "CI-FAIL";
    }
    if pr.review_decision == "CHANGES_REQUESTED" {
        return "CHANGES-REQ";
    }
    if pr.is_draft {
        return "DRAFT";
    }
    if pr.days_old >= _STALE_DAYS {
        return "STALE";
    }
    if pr.review_decision == "APPROVED" {
        return "APPROVED";
    }
    if pr.ci_status == "PENDING" {
        return "PENDING";
    }
    return "READY";
}

impl _status_color(status: str) -> str {
    return {
        "READY": green(status),
        "APPROVED": bold(green(status)),
        "CI-FAIL": red(status),
        "CHANGES-REQ": red(status),
        "WRONG-BASE": dim(status),
        "STALE": dim(status),
        "DRAFT": yellow(status),
        "PENDING": yellow(status),
    }.get(status, status);
}

impl _ci_icon(status: str) -> str {
    return {
        "SUCCESS": green("✓"),
        "FAILURE": red("✗"),
        "PENDING": yellow("…"),
        "NONE": dim("–"),
    }.get(status, "?");
}

impl _gh(*args_: str) -> list | dict | None {
    args: any = tuple(args_);
    try {
        result: any = subprocess.run(
            ["gh", *args],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=30,
        );
        if result.returncode != 0 {
            return None;
        }
        return json.loads(result.stdout);
    } except (subprocess.TimeoutExpired, json.JSONDecodeError, FileNotFoundError) {
        return None;
    }
}

impl _detect_default_branch(repo: str | None = None) -> str {
    args: any = ["repo", "view"];
    if repo {
        args.append(repo);
    }
    args += ["--json", "defaultBranchRef"];
    data: any = _gh(*args);
    if data and data.get("defaultBranchRef", {}).get("name") {
        return data["defaultBranchRef"]["name"];
    }
    if not repo {
        try {
            result: any = subprocess.run(
                ["git", "symbolic-ref", "refs/remotes/origin/HEAD"],
                stdin=subprocess.DEVNULL,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=5,
            );
            if result.returncode == 0 {
                ref: any = result.stdout.strip();
                return ref.removeprefix("refs/remotes/origin/") or "main";
            }
        } except (subprocess.TimeoutExpired, FileNotFoundError) {}
    }
    return "main";
}

impl _parse_ci(rollup: list) -> str {
    if not rollup {
        return "NONE";
    }
    conclusions: any = {r.get("conclusion") or r.get("state") for r in rollup} - {None, ""};
    if conclusions & (_CI_FAILURE_CONCLUSIONS | {"ERROR"}) {
        return "FAILURE";
    }
    statuses: any = {r.get("status") for r in rollup};
    if statuses & _CI_PENDING_STATUSES or conclusions & {"PENDING", "EXPECTED"} {
        return "PENDING";
    }
    if "SUCCESS" in conclusions {
        return "SUCCESS";
    }
    return "NONE";
}

impl _parse_pr_dict(item: dict, expected_base: str) -> PRInfo {
    updated_raw: any = item.get("updatedAt");
    if updated_raw {
        updated: any = datetime.fromisoformat(updated_raw.replace("Z", "+00:00"));
    } else {
        updated = datetime.now(timezone.utc);
    }
    return PRInfo(
        number=item.get("number", 0),
        title=item.get("title", ""),
        branch=item.get("headRefName", ""),
        base_branch=item.get("baseRefName", ""),
        author=item["author"]["login"] if item.get("author") else "?",
        is_draft=item.get("isDraft", False),
        review_decision=item.get("reviewDecision") or "",
        ci_status=_parse_ci(item.get("statusCheckRollup") or []),
        updated_at=updated,
        expected_base=expected_base,
    );
}

impl fetch_prs(repo: str | None = None, base: str | None = None, limit: int = 50) -> list[PRInfo] {
    resolved_base: any = base or _detect_default_branch(repo);
    args: any = [
        "pr",
        "list",
        "--state",
        "open",
        "--limit",
        `str(limit),
        "--json",
        _PR_JSON_FIELDS,
    ];
    if repo {
        args += ["--repo", repo];
    }

    raw: any = _gh(*args);
    if raw is None {
        raise RuntimeError("gh CLI not found or not authenticated. Run: gh auth login");
    }

    return [_parse_pr_dict(item, resolved_base) for item in raw];
}

impl fetch_pr(number: int, repo: str | None = None, base: str | None = None) -> PRInfo | None {
    resolved_base: any = base or _detect_default_branch(repo);
    args: any = ["pr", "view", `str(number), "--json", _PR_JSON_FIELDS];
    if repo {
        args += ["--repo", repo];
    }

    raw: any = _gh(*args);
    if raw is None or not isinstance(raw, `dict) {
        return None;
    }
    if raw.get("state") != "OPEN" {
        return None;
    }

    return _parse_pr_dict(raw, resolved_base);
}

impl fetch_pr_files(number: int, repo: str | None = None) -> list[str] {
    args: any = ["pr", "diff", `str(number), "--name-only"];
    if repo {
        args += ["--repo", repo];
    }
    try {
        result: any = subprocess.run(
            ["gh", *args],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=30,
        );
        if result.returncode != 0 {
            return [];
        }
        return [l.strip() for l in result.stdout.splitlines() if l.strip()];
    } except (subprocess.TimeoutExpired, FileNotFoundError) {
        return [];
    }
}

impl _path_match(graph_src: str, pr_file: str) -> bool {
    if graph_src == pr_file {
        return True;
    }
    return graph_src.endswith("/" + pr_file) or pr_file.endswith("/" + graph_src);
}

impl compute_pr_impact(files: list[str], G: "nx.Graph") -> tuple[list[int], int] {
    file_comms: dict[str, set[int]] = {};
    file_count: dict[str, int] = {};
    for (_, data) in G.nodes(data=True) {
        src: any = data.get("source_file") or "";
        if not src {
            continue;
        }
        if src not in file_comms {
            file_comms[src] = set[any]();
            file_count[src] = 0;
        }
        c: any = data.get("community");
        if c is not None {
            file_comms[src].add(`int(c));
        }
        file_count[src] += 1;
    }

    comms: set[int] = set[any]();
    nodes: any = 0;
    matched: set[str] = set[any]();
    for f in files {
        for (src, src_comms) in file_comms.items() {
            if src not in matched and _path_match(src, f) {
                comms |= src_comms;
                nodes += file_count[src];
                matched.add(src);
            }
        }
    }
    return (sorted(comms), nodes);
}

impl format_prs_text(prs: list["PRInfo"], base: str) -> str {
    p: any;
    actionable: any = [p for p in prs if p.base_branch == base];
    wrong: any = len(prs) - len(actionable);
    lines: any = [
        f"Open PRs targeting {base}: {len(actionable)}  ({wrong} on wrong base, not shown)\n",
    ];
    for p in sorted(
        actionable,
        key=lambda (x) -> any {
            (_STATUS_ORDER.index(x.status) if x.status in _STATUS_ORDER else 99, x.days_old)
        },
    ) {
        impact: any = f"  blast_radius={p.blast_radius}" if p.blast_radius else "";
        lines.append(
            "#"
                + format(p.number, "")
                + " ["
                + format(p.status, "")
                + "] CI="
                + format(p.ci_status, "")
                + " review="
                + format(p.review_decision or "none", "")
                + " age="
                + format(p.days_old, "")
                + "d author="
                + format(p.author, "")
                + format(impact, "")
                + "\n  "
                + format(p.title, ""),
        );
    }
    return "\n\n".join(lines);
}

impl fetch_worktrees -> dict[str, str] {
    try {
        result: any = subprocess.run(
            ["git", "worktree", "list", "--porcelain"],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=10,
        );
        if result.returncode != 0 {
            return {};
        }
    } except (subprocess.TimeoutExpired, FileNotFoundError) {
        return {};
    }

    mapping: dict[str, str] = {};
    current_path: any = None;
    for line in result.stdout.splitlines() {
        if not line {
            current_path = None;
        } elif line.startswith("worktree ") {
            current_path = line[9:];
        } elif line.startswith("branch refs/heads/") and current_path {
            mapping[line[18:]] = current_path;
        }
    }
    return mapping;
}

impl _load_graph_json(graph_path: Path) -> dict | None {
    if not graph_path.exists() {
        return None;
    }
    check_graph_file_size_cap: any = importlib.import_module("graphify.security").check_graph_file_size_cap;
    try {
        check_graph_file_size_cap(graph_path);
        return json.loads(graph_path.read_text(encoding="utf-8"));
    } except (json.JSONDecodeError, OSError, ValueError) {
        return None;
    }
}

impl build_community_labels(data: dict, top_n: int = 4) -> dict[int, list[str]] {
    comm_labels: dict[int, list[str]] = defaultdict(list[any]);
    for `node in data.get("nodes", []) {
        c: any = `node.get("community");
        if c is None {
            continue;
        }
        label: any = `node.get("label") or `node.get("id") or "";
        if label {
            comm_labels[`int(c)].append(label);
        }
    }
    return {c: labels[:top_n] for (c, labels) in comm_labels.items()};
}

impl attach_graph_impact(
    prs: list[PRInfo], graph_path: Path, repo: str | None = None, include_wrong_base: bool = False
) -> dict[int, list[str]] {
    pr: any;
    data: any = _load_graph_json(graph_path);
    if not data {
        return {};
    }
    file_to_communities: dict[str, set[int]] = {};
    file_to_nodes: dict[str, int] = {};
    for `node in data.get("nodes", []) {
        src: any = `node.get("source_file") or "";
        if not src {
            continue;
        }
        comm: any = `node.get("community");
        if src not in file_to_communities {
            file_to_communities[src] = set[any]();
            file_to_nodes[src] = 0;
        }
        if comm is not None {
            file_to_communities[src].add(`int(comm));
        }
        file_to_nodes[src] += 1;
    }
    actionable: any = [pr for pr in prs if include_wrong_base or pr.status != "WRONG-BASE"];
    workers: any = min(8, len(actionable)) if actionable else 1;
    pool: any;
    with ThreadPoolExecutor(max_workers=workers) as pool {
        future_to_pr: any = {pool.submit(fetch_pr_files, pr.number, repo): pr for pr in actionable};
        for fut in as_completed(future_to_pr) {
            pr = future_to_pr[fut];
            try {
                files: any = fut.result();
            } except Exception {
                files = [];
            }
            pr.files_changed = files;

            comms: set[int] = set[any]();
            nodes: any = 0;
            matched: set[str] = set[any]();
            for f in files {
                for (gf, gcomms) in file_to_communities.items() {
                    if gf not in matched and _path_match(gf, f) {
                        comms |= gcomms;
                        nodes += file_to_nodes.get(gf, 0);
                        matched.add(gf);
                    }
                }
            }
            pr.communities_touched = sorted(comms);
            pr.nodes_affected = nodes;
        }
    }

    return build_community_labels(data);
}

impl _truncate(s: str, n: int) -> str {
    return s if len(s) <= n else s[:n - 1] + "…";
}

impl render_dashboard(prs: list[PRInfo], base: str = "v8", show_wrong_base: bool = False) -> None {
    p: any;
    actionable: any = [p for p in prs if p.base_branch == base];
    wrong_base: any = [p for p in prs if p.base_branch != base];
    actionable.sort(
        key=lambda (p) -> any {
            (_STATUS_ORDER.index(p.status) if p.status in _STATUS_ORDER else 99, p.days_old)
        },
    );

    print();
    print(bold(f"  graphify prs  ·  base: {base}  ·  {len(actionable)} PRs"));
    print();

    if not actionable {
        print(dim("  No open PRs targeting this base branch."));
    } else {
        print(
            "  "
                + format("#", ">4")
                + "  "
                + format("CI", "2")
                + "  "
                + format("STATUS", "13")
                + "  "
                + format("UPDATED", "8")
                + "  "
                + format("IMPACT", "22")
                + "  TITLE",
        );
        print(
            "  "
                + format("─" * 4, "")
                + "  "
                + format("─" * 2, "")
                + "  "
                + format("─" * 13, "")
                + "  "
                + format("─" * 8, "")
                + "  "
                + format("─" * 22, "")
                + "  "
                + format("─" * 40, ""),
        );

        pr: any;
        for pr in actionable {
            status_str: any = _pad(_status_color(pr.status), 13);
            ci_str: any = _ci_icon(pr.ci_status);
            age: any = f"{pr.days_old}d" if pr.days_old > 0 else "today";
            impact: any = _pad(dim(_truncate(pr.blast_radius, 22)), 22)
                if pr.blast_radius
                else _pad(dim("–"), 22);
            wt: any = " " + format(cyan("⬡"), "") if pr.worktree_path else "  ";
            draft: any = dim(" [draft]") if pr.is_draft else "";
            title: any = _truncate(pr.title, 52);
            num: any = _pad(bold(f"#{pr.number}"), 6);
            print(f"  {num}{wt}  {ci_str}  {status_str}  {age:>6}   {impact}  {title}{draft}");
        }
    }
    by_status: dict[str, int] = {};
    for p in actionable {
        by_status[p.status] = by_status.get(p.status, 0) + 1;
    }

    parts: any = [];
    if by_status.get("READY") {
        parts.append(green(format(by_status["READY"], "") + " ready"));
    }
    if by_status.get("APPROVED") {
        parts.append(bold(green(format(by_status["APPROVED"], "") + " approved")));
    }
    if by_status.get("PENDING") {
        parts.append(yellow(format(by_status["PENDING"], "") + " pending CI"));
    }
    if by_status.get("CI-FAIL") {
        parts.append(red(format(by_status["CI-FAIL"], "") + " CI failing"));
    }
    if by_status.get("CHANGES-REQ") {
        parts.append(red(format(by_status["CHANGES-REQ"], "") + " changes requested"));
    }
    if by_status.get("DRAFT") {
        parts.append(yellow(format(by_status["DRAFT"], "") + " draft"));
    }
    if by_status.get("STALE") {
        parts.append(dim(format(by_status["STALE"], "") + " stale"));
    }

    if wrong_base {
        parts.append(dim(f"{len(wrong_base)} wrong base"));
    }

    print();
    print("  " + format(" · ".join(parts), ""));
    print();

    if wrong_base and show_wrong_base {
        print(dim(f"  ── {len(wrong_base)} PRs targeting wrong base ──"));
        for pr in sorted(wrong_base, key=lambda (p) -> any { p.number }, reverse=True) {
            print(dim(f"  #{pr.number:4}  base={pr.base_branch:12}  {_truncate(pr.title, 60)}"));
        }
        print();
    }
}

impl render_worktrees(prs: list[PRInfo], worktrees: dict[str, str]) -> None {
    print();
    print(bold("  Worktrees"));
    print();
    if not worktrees {
        print(dim("  No active worktrees found."));
        print();
        return;
    }

    pr_by_branch: any = {p.branch: p for p in prs};
    for (branch, path) in sorted(worktrees.items()) {
        pr: any = pr_by_branch.get(branch);
        if pr {
            status: any = _status_color(pr.status);
            print(f"  {cyan(path)}");
            print(
                "    "
                    + format(dim("branch:"), "")
                    + " "
                    + format(branch, "")
                    + "  ->  PR "
                    + format(bold(f"#{pr.number}"), "")
                    + "  ["
                    + format(status, "")
                    + "]  "
                    + format(_truncate(pr.title, 50), ""),
            );
        } else {
            print(f"  {cyan(path)}");
            print(
                "    "
                    + format(dim("branch:"), "")
                    + " "
                    + format(branch, "")
                    + "  "
                    + format(dim("(no open PR)"), ""),
            );
        }
        print();
    }
}

impl render_conflicts(
    prs: list[PRInfo], base: str = "v8", community_labels: dict[int, list[str]] | None = None
) -> None {
    ps: any;
    actionable: any = [p for p in prs if p.base_branch == base and p.communities_touched];
    if not actionable {
        print(dim("\n  No graph impact data - run with a valid graph.json to detect conflicts.\n"));
        return;
    }
    comm_to_prs: dict[int, list[PRInfo]] = {};
    pr: any;
    for pr in actionable {
        for c in pr.communities_touched {
            comm_to_prs.setdefault(c, []).append(pr);
        }
    }

    conflicts: any = {c: ps for (c, ps) in comm_to_prs.items() if len(ps) > 1};
    if not conflicts {
        print(green("\n  No community overlap between open PRs - safe to merge in any order.\n"));
        return;
    }

    print();
    print(bold("  Community conflicts (PRs sharing the same graph community)"));
    print();
    labels: any = community_labels or {};
    for (comm, ps) in sorted(conflicts.items(), key=lambda (x) -> any { -len(x[1]) }) {
        comm_label_str: any = "";
        if comm in labels and labels[comm] {
            comm_label_str = dim("  — " + ", ".join(labels[comm]));
        }
        print(
            "  "
                + format(yellow(f"Community {comm}"), "")
                + format(comm_label_str, "")
                + "  ("
                + format(len(ps), "")
                + " PRs overlap)",
        );
        for pr in ps {
            print(
                f"    #{pr.number:4}  {_pad(_status_color(pr.status), 13)}  {_truncate(pr.title, 55)}",
            );
        }
        print();
    }
}

impl render_pr_detail(pr: PRInfo, repo: str | None = None) -> None {
    print();
    print(bold(f"  PR #{pr.number}  ·  {_status_color(pr.status)}"));
    print(f"  {pr.title}");
    print();
    print(
        "  "
            + format(dim("branch:"), "")
            + "  "
            + format(pr.branch, "")
            + "  ->  "
            + format(pr.base_branch, ""),
    );
    print("  " + format(dim("author:"), "") + "  " + format(pr.author, ""));
    print("  " + format(dim("updated:"), "") + " " + format(pr.days_old, "") + "d ago");
    print(
        "  "
            + format(dim("CI:"), "")
            + "      "
            + format(_ci_icon(pr.ci_status), "")
            + " "
            + format(pr.ci_status, ""),
    );
    if pr.review_decision {
        print("  " + format(dim("review:"), "") + " " + format(pr.review_decision, ""));
    }
    if pr.worktree_path {
        print("  " + format(dim("worktree:"), "") + " " + format(cyan(pr.worktree_path), ""));
    }
    if pr.blast_radius {
        print();
        print("  " + format(bold("Graph impact:"), "") + "  " + format(pr.blast_radius, ""));
        print("  " + format(dim("communities:"), "") + " " + format(pr.communities_touched, ""));
        if pr.files_changed {
            print(
                "  " + format(dim("files changed:"), "") + " " + format(len(pr.files_changed), "")
            );
            for f in pr.files_changed[:10] {
                print(f"    {dim(f)}");
            }
            if len(pr.files_changed) > 10 {
                print(dim(f"    … and {len(pr.files_changed) - 10} more"));
            }
        }
    }
    print();
}

impl _resolve_triage_backend -> tuple[str, str] {
    BACKENDS: any = importlib.import_module("graphify.llm").BACKENDS;
    _get_backend_api_key: any = importlib.import_module("graphify.llm")._get_backend_api_key;
    _default_model_for_backend: any = importlib.import_module("graphify.llm")._default_model_for_backend;

    explicit: any = os.environ.get("GRAPHIFY_TRIAGE_BACKEND", "").strip();
    if explicit in BACKENDS {
        model: any = os.environ.get("GRAPHIFY_TRIAGE_MODEL")
            or _TRIAGE_MODEL_DEFAULTS.get(explicit)
            or _default_model_for_backend(explicit);
        return (explicit, model);
    }

    for b in ("claude", "kimi", "openai", "gemini") {
        if _get_backend_api_key(b) {
            model = os.environ.get("GRAPHIFY_TRIAGE_MODEL")
                or _TRIAGE_MODEL_DEFAULTS.get(b)
                or _default_model_for_backend(b);
            return (b, model);
        }
    }

    import shutil;
    if shutil.which("claude") {
        return ("claude-cli", "claude-code-plan");
    }

    return ("ollama", _default_model_for_backend("ollama"));
}

impl triage_with_opus(prs: list[PRInfo], base: str) -> None {
    try {
        BACKENDS: any = importlib.import_module("graphify.llm").BACKENDS;
        _get_backend_api_key: any = importlib.import_module("graphify.llm")._get_backend_api_key;
    } except ImportError {
        print(red("  graphify.llm not available - cannot run triage."), file=sys.stderr);
        sys.exit(1);
    }

    candidates: any = [
        p
        for p in prs
        if p.base_branch == base and p.status not in ("WRONG-BASE", "STALE")
    ];
    if not candidates {
        print(dim("  No actionable PRs to triage."));
        return;
    }

    lines: any = [];
    for pr in candidates {
        impact: any = f", blast_radius={pr.blast_radius}" if pr.blast_radius else "";
        lines.append(
            "PR #"
                + format(pr.number, "")
                + " ["
                + format(pr.status, "")
                + "] CI="
                + format(pr.ci_status, "")
                + " review="
                + format(pr.review_decision or "none", "")
                + " age="
                + format(pr.days_old, "")
                + "d author="
                + format(pr.author, "")
                + format(impact, "")
                + "\n  title: "
                + format(pr.title, ""),
        );
    }

    prompt: any = "You are a senior engineer helping triage a PR review queue. Given these open PRs, rank them by review priority for the repo maintainer. For each PR give: priority number, one sentence on what action to take and why. Be direct and specific. Format each as: #<number> — <action>.\n\n"
        + "\n\n".join(lines);

    try {
        backend: any;
        model: any;
        (backend, model) = _resolve_triage_backend() as any;
    } except Exception as e {
        print(red(f"  Could not resolve triage backend: {e}"), file=sys.stderr);
        sys.exit(1);
    }

    print();
    print(bold("  Triage") + dim(f" ({backend} / {model})"));
    print();

    try {
        if backend == "claude" {
            import anthropic;
            client: any = anthropic.Anthropic(api_key=_get_backend_api_key("claude"));
            stream: any;
            with client.messages.stream(
                model=model, max_tokens=1024, messages=[{"role": "user", "content": prompt}]
            ) as stream {
                print("  ", end="", flush=True);
                for text in stream.text_stream {
                    print(text.replace("\n", "\n  "), end="", flush=True);
                }
            }
            print("\n");
        } elif backend in ("kimi", "openai", "gemini", "ollama") {
            import from openai { OpenAI }
            cfg: any = BACKENDS[backend];
            api_key: any = _get_backend_api_key(backend) or "ollama";
            client = OpenAI(api_key=api_key, base_url=cfg.get("base_url", ""));
            with client.chat.completions.create(
                model=model,
                max_tokens=1024,
                stream=True,
                messages=[{"role": "user", "content": prompt}],
            ) as stream {
                print("  ", end="", flush=True);
                for chunk in stream {
                    delta: any = chunk.choices[0].delta.content if chunk.choices else None;
                    if delta {
                        print(delta.replace("\n", "\n  "), end="", flush=True);
                    }
                }
            }
            print("\n");
        } elif backend == "claude-cli" {
            import platform as _platform;
            import shutil as _shutil;
            import subprocess as _sp;
            _claude: any = "claude";
            if _platform.system() == "Windows" {
                _claude = _shutil.which("claude.cmd") or _shutil.which("claude") or "claude";
            }
            proc: any = _sp.run(
                [_claude, "-p", "--no-session-persistence"],
                input=prompt,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=120,
            );
            if proc.returncode != 0 {
                print(red(f"  claude -p failed: {proc.stderr.strip()[:300]}"), file=sys.stderr);
            } else {
                try {
                    result: any = json.loads(proc.stdout).get("result") or proc.stdout;
                } except json.JSONDecodeError {
                    result = proc.stdout;
                }
                for line in result.splitlines() {
                    print(f"  {line}");
                }
                print();
            }
        }
    } except Exception as e {
        print("\n\n  " + format(red(f"Triage failed: {e}"), ""), file=sys.stderr);
    }
}

impl cmd_prs(argv: list[str]) -> None {
    pr_number: int | None;
    base: str | None = None;
    repo: str | None = None;
    do_triage: any = False;
    do_worktrees: any = False;
    do_conflicts: any = False;
    show_wrong_base: any = False;
    pr_number = None;
    graph_path: any = Path(_default_graph_json());

    i: any = 0;
    while i < len(argv) {
        arg: any = argv[i];
        if arg == "--triage" {
            do_triage = True;
        } elif arg == "--worktrees" {
            do_worktrees = True;
        } elif arg == "--conflicts" {
            do_conflicts = True;
        } elif arg == "--wrong-base" {
            show_wrong_base = True;
        } elif arg in ("--base", "-b") and i + 1 < len(argv) {
            base = argv[i + 1];
            i += 1;
        } elif arg.startswith("--base=") {
            base = arg.split("=", 1)[1];
        } elif arg in ("--repo", "-R") and i + 1 < len(argv) {
            repo = argv[i + 1];
            i += 1;
        } elif arg.startswith("--graph=") {
            graph_path = Path(arg.split("=", 1)[1]);
        } elif arg == "--graph" and i + 1 < len(argv) {
            graph_path = Path(argv[i + 1]);
            i += 1;
        } elif arg.lstrip("#").isdigit() {
            pr_number = `int(arg.lstrip("#"));
        } elif arg in ("-h", "--help") {
            print(__doc__);
            return;
        }
        i += 1;
    }

    if base is None {
        base = _detect_default_branch(repo);
    }

    try {
        prs: any = fetch_prs(repo=repo, base=base);
    } except RuntimeError as e {
        print(red(f"  Error: {e}"), file=sys.stderr);
        sys.exit(1);
    }

    worktrees: any = fetch_worktrees();
    for pr in prs {
        pr.worktree_path = worktrees.get(pr.branch);
    }

    if pr_number is not None {
        `match: any = next((p for p in prs if p.number == pr_number), None);
        if not `match {
            `match = fetch_pr(pr_number, repo=repo, base=base);
            if `match and `match.branch {
                `match.worktree_path = worktrees.get(`match.branch);
            }
        }
        if not `match {
            print(red(f"  PR #{pr_number} not found in open PRs."), file=sys.stderr);
            sys.exit(1);
        }
        if graph_path.exists() {
            attach_graph_impact([`match], graph_path, repo, include_wrong_base=True);
        }
        render_pr_detail(`match, repo);
        return;
    }
    community_labels: dict[int, list[str]] = {};
    needs_impact: any = graph_path.exists() and (do_triage or do_conflicts);
    if needs_impact {
        community_labels = attach_graph_impact(prs, graph_path, repo);
    }

    if do_triage {
        render_dashboard(prs, base, show_wrong_base);
        triage_with_opus(prs, base);
        return;
    }

    if do_worktrees {
        render_worktrees(prs, worktrees);
        return;
    }

    if do_conflicts {
        render_dashboard(prs, base, show_wrong_base);
        render_conflicts(prs, base, community_labels);
        return;
    }

    render_dashboard(prs, base, show_wrong_base);
}
