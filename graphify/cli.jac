"""graphify command dispatch — every non-install subcommand.

Extracted verbatim from __main__.main(); __main__ now calls dispatch_command(cmd)
after the install/platform dispatch. Kept out of __main__ to shrink the CLI entry
module. The path-redirect (`graphify <path>` -> extract) re-enters via a lazy
import of main to avoid a cli<->__main__ import cycle.
"""

import importlib;
import builtins;

import operator;

import from jaclang.comptime { target as target_ }

import from __future__ { annotations }

import json;

import math;

import os;

import re;

import sys;

import time;

import from pathlib { Path, PurePosixPath, PureWindowsPath }

"""A provider price flag must be a finite, non-negative number. A NaN, inf
    or negative value parses as a float but flows into cost estimation (price x
    tokens), producing NaN/inf/negative cost reports (#5031), so reject it the
    same way a non-numeric value is rejected."""
def _valid_price(value: float) -> float;

glob _SEARCH_NUDGE: any;

glob _READ_NUDGE: any;

glob _READ_NUDGE_STALE: any;

glob _SEARCH_NUDGE_STALE: any;

glob _COMPACT_CONTEXT: any;

glob _READ_DENY: any;

glob _SEARCH_DENY: any;

glob _HOOK_SOURCE_EXTS: any;

glob _GEMINI_NUDGE_TEXT: any;

glob _DEFAULT_NUDGE_GRAPH: any;

glob EXIT_AMBIGUOUS: any;

glob EXIT_NOT_FOUND: any;

glob _CLOUD_CTA_SHOW_ON: any;

glob _CLOUD_CTA_LARGE_GRAPH_NODES: any;

glob _HINT_MAX_NODES: any;

glob _HINT_GRAPH_MAX_BYTES: any;

glob _HINT_TERM_RE: any;

glob _HINT_SAFE_ARG_RE: any;

glob _HINT_KEYWORDS: any;

glob _HINT_VALUE_FLAGS: any;

glob _SEARCH_COMMANDS: any;

glob _COMMAND_WRAPPERS: any;

glob _HEREDOC_OPEN_RE: any;

glob _BASH_READERS: any;

glob _BASH_READ_SKIP_EXTS: any;

with entry {
    _SEARCH_NUDGE = json.dumps(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "additionalContext": "graphify: this project has a knowledge graph at graphify-out/graph.json. `graphify query \"<question>\"` returns the files and relations that matter for a question, usually in far fewer tokens than grepping raw files. Finding where something lives is what the graph answers; grep finds exact text in files the graph has already named.",
            },
        },
        ensure_ascii=False,
        separators=(",", ":"),
    )
        + "\n";
    _READ_NUDGE = json.dumps(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "additionalContext": "graphify: this project has a knowledge graph at graphify-out/graph.json. `graphify query \"<question>\"` (scoped subgraph), `graphify explain \"<concept>\"` and `graphify path \"<A>\" \"<B>\"` show which files and lines matter — usually in far fewer tokens than reading source files one by one. Reading a file directly works best once the graph has pointed to the exact lines.",
            },
        },
        ensure_ascii=False,
        separators=(",", ":"),
    )
        + "\n";
    _READ_NUDGE_STALE = json.dumps(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "additionalContext": "graphify-out/graph.json exists but may be STALE for this file (the file changed after the last build). Prefer `graphify query \"<question>\"` for orientation, and run `graphify update` to refresh the graph. Reading the file directly is fine.",
            },
        },
        ensure_ascii=False,
        separators=(",", ":"),
    )
        + "\n";
    _SEARCH_NUDGE_STALE = json.dumps(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "additionalContext": "graphify-out/graph.json exists but may be STALE (pending changes since the last build). Prefer `graphify query \"<question>\"` for orientation once the graph is current; run `graphify update` to refresh it. Searching directly is fine.",
            },
        },
        ensure_ascii=False,
        separators=(",", ":"),
    )
        + "\n";
    _COMPACT_CONTEXT = json.dumps(
        {
            "hookSpecificOutput": {
                "hookEventName": "SessionStart",
                "additionalContext": "graphify: this project has a knowledge graph at graphify-out/graph.json. `graphify query \"<question>\"`, `graphify explain \"<concept>\"` and `graphify path \"<A>\" \"<B>\"` show which files and lines matter, usually in far fewer tokens than reading or grepping raw files.",
            },
        },
        ensure_ascii=False,
        separators=(",", ":"),
    )
        + "\n";
    _READ_DENY = json.dumps(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": "graphify strict mode: this project has a fresh knowledge graph that covers this file. Run `graphify query \"<your question>\"` (or `graphify explain` / `graphify path`) FIRST to orient yourself, then re-issue this Read — it will be allowed. This block fires at most once per session; after one query, read raw files for the exact lines the graph pointed you to.",
            },
        },
        ensure_ascii=False,
        separators=(",", ":"),
    )
        + "\n";
    _SEARCH_DENY = json.dumps(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": "graphify strict mode: this project has a knowledge graph. Run `graphify query \"<your question>\"` (or `graphify explain` / `graphify path`) FIRST to orient yourself, then re-issue this Grep — it will be allowed. This block fires at most once per session.",
            },
        },
        ensure_ascii=False,
        separators=(",", ":"),
    )
        + "\n";
    _HOOK_SOURCE_EXTS = (
        ".py",
        ".js",
        ".cjs",
        ".ts",
        ".tsx",
        ".jsx",
        ".astro",
        ".vue",
        ".svelte",
        ".ejs",
        ".go",
        ".rs",
        ".java",
        ".rb",
        ".c",
        ".h",
        ".cpp",
        ".hpp",
        ".cc",
        ".cs",
        ".kt",
        ".swift",
        ".php",
        ".scala",
        ".lua",
        ".ps1",
        ".psm1",
        ".psd1",
        ".sh",
        ".md",
        ".rst",
        ".txt",
        ".mdx",
    );
    _GEMINI_NUDGE_TEXT = "graphify: knowledge graph at graphify-out/. For focused questions, run `graphify query \"<question>\"` (scoped subgraph, usually much smaller than GRAPH_REPORT.md) instead of grepping raw files. Read GRAPH_REPORT.md only for broad architecture context.";

    _DEFAULT_NUDGE_GRAPH = "graphify-out/graph.json";
    EXIT_AMBIGUOUS = 3;
    EXIT_NOT_FOUND = 4;
}

"""Name the effective graph.json in a hook-guard reminder (#4040).

    The reminder constants spell the default ``graphify-out/graph.json``. When
    ``GRAPHIFY_OUT`` points elsewhere, the reminder must name the graph that was
    actually found. Default output dir: returned byte-identical.
    """
def _nudge_for_out(nudge: str) -> str;

with entry {
    _CLOUD_CTA_SHOW_ON = (1, 5, 20);
    _CLOUD_CTA_LARGE_GRAPH_NODES = 25000;
}

"""Nudge toward Graphify Cloud after a successful local graph build.

    Shown only to humans running the CLI interactively: suppressed in
    non-interactive/CI runs (stdout is not a TTY, which also covers the
    AI-assistant pipeline) and when the user opts out
    (``GRAPHIFY_NO_TIPS``/``GRAPHIFY_NO_CTA``). A per-project counter under
    ``graphify-out/`` shows it on builds ``_CLOUD_CTA_SHOW_ON`` (1, 5, 20) so a
    returning user gets a reminder without a nag on every build, then it stays
    quiet for good.

    ``node_count`` is the size of the graph just built. When it reaches
    ``_CLOUD_CTA_LARGE_GRAPH_NODES`` the graph no longer fits the free plan, so
    the message switches to a scale-specific line (``utm_content=scale``) that
    sells Pro and links to pricing rather than the free signup: pointing these
    users at the free plan would land them straight on its 25k limit. The show
    cadence is the same either way, so this adds no extra nag.
    """
def _print_cloud_cta(out_dir: "Path", node_count: int = 0) -> None;

def _default_graph_path -> str;

with entry {
    _HINT_MAX_NODES = 5;
    _HINT_GRAPH_MAX_BYTES = 24 * 1024 * 1024;
    _HINT_TERM_RE = re.compile("[A-Za-z_][A-Za-z0-9_]{2,}");
    _HINT_SAFE_ARG_RE = re.compile("[\\w.\\-() ]+");
    _HINT_KEYWORDS = frozenset({
        "def",
        "class",
        "function",
        "func",
        "const",
        "let",
        "var",
        "import",
        "export",
        "async",
        "return",
        "struct",
        "interface",
        "type",
        "enum",
        "impl",
        "pub",
    });
    _HINT_VALUE_FLAGS = frozenset({
        "-t",
        "-T",
        "-g",
        "--type",
        "--type-not",
        "--glob",
        "--iglob",
        "-A",
        "-B",
        "-C",
        "-m",
        "--max-count",
        "-j",
        "--threads",
        "-f",
        "--file",
        "--include",
        "--exclude",
        "--exclude-dir",
        "--max-depth",
        "-d",
        "-D",
        "--color",
        "--colour",
    });
}

"""Identifier-like words in a search pattern (regex escapes and declaration
    keywords dropped), at most three."""
def _pattern_terms(pattern: str) -> list[str];

"""The read target as a root-relative POSIX path, the form graph.json stores."""
def _rel_to_root(file_path: str, `root: "Path") -> "str | None";

"""Words the agent searched for: the Grep `pattern`, or the pattern argument of
    a shell content search. Empty when there is nothing to go on."""
def _search_hint_terms(t: dict) -> list[str];

"""A graph field as one inert line: graph.json is repository content, so no
    newline, control character or backtick may reach the model-facing hint."""
def _hint_text(value: object, cap: int) -> str;

"""(command, node lines) for a nudge: nodes whose label matches the searched
    terms, or the symbols in the file being read. ("", []) for an oversized graph
    or no match."""
def _graph_hint(terms: "list[str]", rel_file: "str | None") -> tuple[str, list[str]];

"""Append the call-specific command and matching graph nodes to a nudge or deny.
    Any failure returns the nudge unchanged: a hint must never cost the nudge."""
def _with_hint(nudge: str, terms: "list[str] | None" = None, rel_file: "str | None" = None) -> str;

"""Manifest-safe files dict: only stamp semantic files that actually
    produced output (cache hit or fresh extraction). Files whose chunk failed
    have no source_file entry in sem_result — leaving their semantic_hash
    empty so detect_incremental re-queues them (#933).

    A file in ``partial_source_files`` DID produce output this run, but only a
    truncated fragment of it, so it is excluded from stamping too — otherwise
    detect_incremental would see it "done" and never re-dispatch it, leaving the
    incomplete node set live forever on the warm-incremental path. Same #933
    mechanism: leave it unstamped and it is re-queued next run.

    ``unverified_semantic_sources`` (#3203): files whose semantic extraction
    under-produced compared to their prior representation (e.g. 3 -> 1 nodes).
    They are excluded from stamping unless --allow-partial is set, so the next
    incremental run retries them.

    Both sides of the membership test are resolved against the scan ``root``
    before comparing (#1897): node/edge/hyperedge ``source_file`` values are
    root-relative on a fresh extraction while ``files_by_type`` entries are
    absolute (from detect()), so a raw string comparison never matched and
    every freshly-extracted semantic doc was dropped from the manifest.
    Mirrors the #1890 path normalization in graphify.llm.

    Hyperedges are counted as output (#1920): a chunk whose only result for a
    document is a hyperedge (3+ nodes sharing a concept) is valid output that
    the semantic cache persists per-``source_file`` — omitting it here left the
    doc unstamped, so detect_incremental re-queued it on every run. The stamping
    condition mirrors the cache-write keying (a hyperedge carries its own
    ``source_file``); do not derive it from member nodes.

    ``failed_ast_sources`` (#2543): code files whose AST extractor errored
    (missing optional extra, etc.) or returned zero nodes. They must not be
    stamped as up-to-date or a later install of the extra will never re-run.
    """
def _stamped_manifest_files(
    files_by_type: dict[str, list[str]],
    sem_result: dict,
    `root: Path,
    partial_source_files: "set[str] | None" = None,
    failed_ast_sources: "set[str] | list[str] | None" = None,
    unverified_semantic_sources: "set[str] | list[str] | None" = None,
) -> dict[str, list[str]];

"""Shared handling for the #3203 unverified-semantic-shrink guard on both the
    raw and clustered write paths (they differ only in where the flag is read
    from — ``merged`` vs ``G.graph``). Always prints the actionable notice.

    The same under-produced source also has to be kept out of the semantic
    cache (#5083): the cache is unversioned and content-hash keyed, so a
    degraded chunk would otherwise be replayed as authoritative on every later
    run, the shrink guard would keep refusing the write, and no LLM call would
    ever be made again. ``save_semantic_cache`` cannot see graph.json (and must
    not: it has no business reading the graph), so the entry is stamped
    ``partial`` here, after the guard has measured the shrink.
    ``cached_semantic_files`` identifies which shrinking sources were REPLAYED
    from the cache this run (as opposed to freshly extracted), so the message
    can call out the poisoned-entry replay instead of repeating the
    ``--allow-partial`` advice — which would commit the degraded replay and
    drop the prior nodes.

    Returns None when there is no shrink, else ``(incomplete, manifest_files,
    cleared_semantic)`` — the latter two are None unless the guard armed
    (``not cli_allow_partial``), so the caller mirrors the original inline logic.
    """
def _handle_unverified_semantic_shrink(
    unverified_shrink,
    *,
    cli_allow_partial: bool,
    files_by_type,
    sem_result,
    target,
    partial_semantic_files,
    failed_ast_sources,
    semantic_files,
    cached_semantic_files=None,
    sem_cache_mode=None,
    sem_prompt=None,
    cache_root=None,
) -> any;

"""Source files graph.json still references but the current scan no longer
    contains (#1909).

    Incremental extract's prune set was historically derived from the manifest
    alone (``manifest - corpus``), so a file that became EXCLUDED
    (.graphifyignore/.gitignore/--exclude changed) without being listed in the
    manifest kept its stale nodes in graph.json forever. Derive prune
    candidates from the graph's own node ``source_file``s instead: anything
    the graph references that the post-exclude detect corpus no longer
    contains is stale, whether the file was deleted or newly excluded.

    Only IN-ROOT paths are candidates: out-of-root/absolute entries
    (--include sources, symlinked external corpora) are never walked by
    detect, so their absence from the corpus is not staleness evidence.
    Relative entries are re-anchored against both the scan root and the
    graph's own output root; only anchors that land inside the scan root
    count. Since #1941 extracts always store source_file relative to the SCAN
    root, so the scan-root anchor is the live one; the out-root anchor stays
    for graphs written by <=0.9.16, which stored them relative to the OUT root
    (e.g. ``../project/x.py``, #555/#1899).
    ``seen_files`` must be the FULL detect output including unclassified
    files, so nodes from walked-but-unsupported sources (e.g. introspected
    Cargo.toml manifests) are not misread as stale.

    Paths are compared NFC-normalized on both sides: macOS reports NFD
    filenames while graph ``source_file`` entries are typically NFC, and a
    raw-string membership test misread every accented live file as stale
    (#2210; same class as the manifest-layer #2221/#2224).

    Fail-closed liveness guard (#2210, mirrors watch.py's excluded-vs-deleted
    distinction): a source missing from the scan corpus is only pruned when
    the file is gone from disk, or when its exclusion is PROVABLE from the
    same scan that produced ``seen_files`` — ``detection``'s ``ignored`` /
    ``pruned_noise_dirs`` / ``skipped_sensitive`` output, or detect's
    sensitivity predicate. An alive file that merely failed the membership
    test (path-spelling drift the normalization didn't cover, walk errors,
    …) is KEPT and reported, never mass-evicted.
    """
def _stale_graph_sources(
    graph_path: Path, scan_root: Path, seen_files: set[str], detection: dict | None = None
) -> list[str];

"""Manifest-stamped code files with a registered extractor but ZERO nodes
    in the existing graph.json (#2543 heal).

    The failed-source unstamping only covers failures that happen AFTER it
    shipped; a manifest poisoned by an earlier run (extraction failed, hashes
    stamped anyway) keeps reporting the file unchanged forever, and the only
    documented recovery was deleting graphify-out/. A stamped file that the
    graph has no nodes for, despite an extractor being wired up for it, is
    exactly that state — re-queue it as changed. Bounded by the same no-wedge
    property: if it fails again this run it is now left unstamped, and if it
    succeeds its nodes enter graph.json so the next scan stops re-queuing it.

    A file the extractor declines by design (data JSON, #2879) is a legitimate
    stamped-but-zero-node row, not a poisoned one. Its manifest row carries
    ``ast_empty: true``; skip those here or the heal re-queues them on every
    incremental forever. A pre-#2879 manifest lacks the marker, so such a file
    is re-queued once more, then stamped with it and left alone thereafter.

    Membership mirrors the ``source_file`` spellings extracts store (#1897/
    #1941: scan-root-relative, forward slash; absolute for out-of-root) and
    compares NFC-normalized (#2210/#2221).
    """
def _zero_node_stamped_code_sources(
    graph_path: Path, scan_root: Path, unchanged_code: list[str], manifest_path: Path | None = None
) -> list[str];

"""Manifest-stamped semantic files (doc/paper/image) with ZERO nodes
    and ZERO hyperedges in the existing graph.json (#2927 heal).

    A manifest poisoned before #2927 (edge-only result cached and stamped)
    keeps reporting the file unchanged forever, freezing it out of the graph.
    Re-queue any unchanged semantic file that has neither nodes nor hyperedges
    in graph.json. If it succeeds, its nodes enter graph.json; if it produces
    no nodes or fails, it is now left unstamped, so this cannot wedge.

    Membership mirrors the ``source_file`` spellings extracts store (#1897/
    #1941: scan-root-relative, forward slash; absolute for out-of-root) and
    compares NFC-normalized (#2210/#2221).
    """
def _zero_node_stamped_semantic_sources(
    graph_path: Path, scan_root: Path, unchanged_semantic: list[str]
) -> list[str];

"""Append this run's token usage to graphify-out/cost.json, the same ledger the
    skill writes, so `graphify extract` refreshes are counted too (#1769). An
    unreadable ledger is left alone rather than replaced with one run."""
def _record_extract_cost(
    graphify_out: Path, input_tokens: int, output_tokens: int, files: int
) -> None;

"""Drop nodes/edges/hyperedges owned by ``stale_sources`` from graph.json
    in place. Returns the number of nodes removed.

    Used by the ``--no-cluster`` incremental early-exit: that path never runs
    ``build_merge`` (it would raw-dump only the new chunks), so an
    exclusion-only change must prune the existing raw graph directly or the
    newly-excluded file's nodes survive forever (#1909).
    ``stale_sources`` comes from :func:`_stale_graph_sources`, i.e. the
    graph's own ``source_file`` spellings, so exact string matching is enough.
    """
def _prune_graph_json_sources(graph_path: Path, stale_sources: list[str]) -> int;

"""Print per-stage wall-clock timings to stderr when --timing is set (#1490).

    Monotonic (perf_counter), diagnostic-only: emits ``[graphify timing] <stage>:
    N.Ns`` after each stage and a final total. Off by default, so normal output is
    byte-identical and machine-read stdout is untouched.
    """
obj _StageTimer {
    has _now: any,
        enabled: any,
        start: any,
        _last: any;

    def init(enabled: bool);

    def mark(stage: str) -> None;

    def total -> None;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""Reject oversized graph files before parsing (CLI exit-on-fail flavor).

    Delegates to ``graphify.security.check_graph_file_size_cap`` and turns the
    raised ``ValueError`` into a CLI-style ``error: ...`` message + exit 1.
    Use this from ``__main__.py`` subcommands that already use the ``print +
    sys.exit(1)`` idiom. Library/MCP/loader callers (``serve._load_graph``,
    ``build``, ``benchmark``, ``tree_html``, ``callflow_html``, ``prs``,
    ``global_graph``, ``watch``, ``export``) call the security helper directly
    and let the ``ValueError`` propagate.
    """
def _enforce_graph_size_cap_or_exit(gp: Path) -> None;

"""Load graph.json as a directed graph for a node-lookup command, or exit 1.

    Directed so stored caller->callee direction survives the load.
    """
def _load_cli_graph(gp: Path) -> any;

"""Resolve strict mode: GRAPHIFY_HOOK_STRICT env overrides the baked-in flag
    (truthy forces on without a reinstall, falsy is the kill switch); unset defers
    to the flag the installed hook command carried."""
def _hook_strict_enabled(flag: bool) -> bool;

"""Record that graphify oriented the agent recently, next to the queried graph.
    The strict guard suppresses its block while this stamp is fresh. Fail-silent."""
def _touch_query_stamp(graph_path: "Path") -> None;

"""True if a query/explain/path ran within GRAPHIFY_HOOK_STRICT_TTL (default
    1800s) — recent orientation, so strict mode does not block raw Read/Grep."""
def _query_stamp_fresh -> bool;

"""Whether to emit a soft read/search nudge for this tool call (#3435).

    The nudge is advisory context that used to be re-injected on EVERY qualifying
    Read/Glob/Grep/Bash call — thousands of times per session, far more tokens
    than the graph queries it asks for. Budgets are per agent: the session id,
    plus the ``agent_id`` Claude Code sends for subagents (which share the
    parent's session id but start with an empty context). Per agent:

    * the first nudge always fires. The query stamp is project-wide and cannot
      say which agent queried, so it must not silence a fresh subagent or session;
    * after that, a fresh query stamp (query/explain/path within
      GRAPHIFY_HOOK_STRICT_TTL) means someone oriented recently, so no nudge;
    * at most GRAPHIFY_HOOK_NUDGE_CAP nudges (default 5; 0 or a non-number
      disables the cap), counted in a marker next to the strict-mode ones.

    Calls without a session id cannot be counted: only the stamp applies.
    Fail-open: on a marker error, only the stamp applies. Compaction keeps the
    session id but drops the earlier nudges from the model's context, so
    ``hook-guard compact`` (Claude Code SessionStart, source "compact") deletes
    the session's counters, see _reset_hook_session.
    """
def _nudge_allowed(payload: dict) -> bool;

"""Best-effort removal of per-session hook markers older than 24h."""
def _gc_hook_session_markers(d: "Path") -> None;

"""Give a compacted Claude Code session its hook budget back.

    After compaction the session id stays the same, but the model no longer
    sees the nudges it was given, and _nudge_allowed has already spent the cap.
    Deletes the session's nudge counter, the counter of every subagent of it
    (``<key>-<16 hex>``, the per-agent key _nudge_allowed builds) and the
    strict-mode deny marker, so the next qualifying call nudges again and strict
    mode can redirect once more. Other sessions' markers are untouched. Errors
    propagate: the caller fails open.
    """
def _reset_hook_session(session_id: str) -> None;

"""Atomically claim a one-time strict block for this session. Returns True only
    on the FIRST call for a given session id (O_EXCL create wins once); every later
    call — or any error — returns False, so a session is blocked at most once and an
    agent can never be stranded. Best-effort GC of markers older than 24h."""
def _mark_session_denied(session_id: str) -> bool;

with entry {
    _SEARCH_COMMANDS = frozenset({
        "grep",
        "egrep",
        "fgrep",
        "zgrep",
        "rg",
        "ripgrep",
        "find",
        "fd",
        "ack",
        "ag",
    });
    _COMMAND_WRAPPERS = frozenset({
        "sudo",
        "command",
        "exec",
        "nohup",
        "time",
        "nice",
        "ionice",
        "env",
        "xargs",
        "timeout",
        "stdbuf",
        "doas",
    });
    _HEREDOC_OPEN_RE = re.compile("<<-?\\s*(['\\\"]?)(\\w+)\\1");
}

"""Yield ``(name, args, piped)`` for each command a Bash string executes.

    The command parsing behind _bash_invokes_search (#3121): heredoc bodies are
    dropped, quoted spans become one placeholder word ``Q``, and the string is
    split at shell operators and substitution boundaries. In each segment the
    executable is the first token after ``VAR=value`` prefixes and wrappers
    (sudo/xargs/env and their flags). ``name`` is its basename, lowercased, with
    any ``.exe`` removed; ``args`` are the tokens after it; ``piped`` says the
    segment reads a pipe. A word in prose, a quoted argument or a heredoc body is
    never yielded as a command.
    """
def _bash_commands(cmd_str: str) -> Generator[any, any, any];

"""Whether a Bash command actually RUNS a search tool (#3121).

    The old test was a plain substring scan over the whole command string,
    including quoted arguments and heredoc bodies - so `git commit -m "add
    flag support"` fired ("flag " contains "ag "), prose containing "find "
    fired, and a design doc written via heredoc fired if its body mentioned
    grep. Every false positive injects a nudge where graphify has nothing to
    contribute and trains the agent to skim the line.

    Decide on the command's executed tokens instead: drop heredoc bodies and
    quoted spans, split on shell operators, and match the executable at each
    command position (wrappers like sudo/xargs/env skipped; `git grep` and
    `VAR=x grep ...` still count; a search-tool name inside prose does not).
    `sed` and `awk` count too when they open a file themselves: run on files, they
    are a grep or a read of the codebase by another name. Reading a pipe, editing
    in place, or naming no file (a program alone reads stdin) does not count.
    """
def _bash_invokes_search(cmd_str: str) -> bool;

"""Whether sed/awk edits its files in place (`-i`, `--in-place`, `-Ei`)."""
def _sed_awk_in_place(name: str, args: "list[str]") -> bool;

with entry {
    _BASH_READERS = frozenset({"cat", "head", "tail", "sed", "nl", "less", "more", "bat"});
    _BASH_READ_SKIP_EXTS = (".md", ".rst", ".txt", ".mdx");
}

"""The in-project source file a Bash command prints, as an absolute path.

    The Read tool gets the read nudge; `cat src/app.py`, `sed -n 1,80p
    src/app.py`, `head -50 src/app.py` and the like read the same code through
    Bash and got nothing (#3121's parser only looked for searches). Uses
    _bash_commands, so only executed commands count, never a reader named in
    prose, quotes or a heredoc body.

    A file counts when a reader names it as an operand (or `< file`), it exists,
    its extension is a graphed code extension, it resolves inside the project
    (CLAUDE_PROJECT_DIR or cwd) and outside the graph output (#1840, #4961).
    Relative paths resolve against the Bash tool's ``cwd`` from the hook payload
    when it is inside the project. Writes are not reads: a stdout redirect
    (`cat > x.py`, `sed -n 1p a.py > b.py`) or `sed -i` disqualifies the
    command, and a reader with no file operand (`echo x | cat`) reads stdin.
    Paths with shell expansion are skipped. None when nothing qualifies.
    """
def _bash_read_target(cmd_str: str, cwd: str = "") -> "str | None";

"""Skip only searches whose literal targets are all outside the project.

    Structured Grep paths and simple grep/rg commands are supported. Shell
    composition, expansion, wrappers and unknown options remain advisory as
    before; this is deliberately not a shell interpreter or an access gate.
    """
def _search_is_outside_project(tool_input: dict) -> bool;

"""Shell-agnostic PreToolUse guard (#522).

    Reads the tool-call JSON from stdin and, when a fresh in-project knowledge graph
    exists, nudges the agent to use graphify instead of grepping/reading raw files.
    Replaces the old inline bash hooks that failed to parse on Windows.

    Fails open everywhere: any error, or a non-matching tool call, prints nothing
    and the caller exits 0, so a legitimate tool call is never blocked by a bug.

    In strict mode (opt-in), the FIRST raw Read of indexed, fresh code or dedicated
    Grep in the project is DENIED with a redirect to `graphify query`, then
    downgrades to the soft nudge. The two tools share one block per session.
    Bash and Glob stay nudge-only: a compound shell command has no single
    parseable target and blocking file listing would strand navigation. A Bash
    command that prints an in-project code file (cat/head/tail/sed -n/nl/less/
    more/bat, see _bash_read_target) gets the Read nudge for that file, through
    the same budget, and is never denied.
    Out-of-project and graph-output targets are ignored; stale graphs never block.
    """
def _run_hook_guard(kind: str, strict: bool = False) -> None;

"""Whether *value* is anchored at the current working directory.

    The hook's out-of-project guard needs "is this path resolved against cwd?",
    and ``Path.is_absolute()`` is the wrong question for it on Windows. A
    driveless rooted path like ``/tmp/x.py`` — the form POSIX-shaped hosts, WSL
    and Git Bash send — is NOT absolute there (no drive letter), but it is not
    cwd-relative either: Windows anchors it at the current DRIVE root, so
    ``Path("/somewhere/else/x.py").resolve()`` is ``C:\\somewhere\\else\\x.py``,
    which is outside the project unless the project sits at ``C:\\``. Reading it
    as cwd-relative made the guard declare it in-project and emit the read nudge
    (and, in strict mode, the once-per-session deny) for files the graph has
    nothing to say about.

    ``C:x.py`` is the same trap from the other side: drive-relative, anchored at
    that drive's current directory rather than cwd.

    So the test is "no root and no drive", not "not absolute". These stay the
    host's own rules — the path is about to be resolved against this filesystem,
    so ``paths.is_absolute_any_platform`` (for stored, portable paths) is
    deliberately not used. On POSIX ``root`` is set exactly when the path is
    absolute and ``drive`` is always empty, so this is unchanged there.
    """
def _is_cwd_relative(value: str) -> bool;

"""Confirm a newer-mtime target still matches its saved extraction hashes."""
def _target_matches_manifest(file_path: str, `root: "Path") -> bool;

"""Guard the strict deny: only block a read of a file the graph actually indexes.
    Reads manifest.json (cheap, capped); on any doubt (missing/corrupt/oversized
    manifest, unresolvable path) returns True so the once-per-session deny still
    applies — that block is self-limiting, so erring toward it is safe."""
def _target_is_indexed(file_path: str, `root: "Path") -> bool;

"""Clone a GitHub repo to a local cache dir and return the path.

    Clones into ~/.graphify/repos/<owner>/<repo> by default so repeated
    runs on the same URL reuse the existing clone (git pull instead of clone).
    """
def _clone_repo(url: str, branch: str | None = None, out_dir: Path | None = None) -> Path;

def _reenter_main -> None;

def dispatch_command(cmd: str) -> None;
