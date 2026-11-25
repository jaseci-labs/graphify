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

def _nudge_for_out(nudge: str) -> str;

with entry {
    _CLOUD_CTA_SHOW_ON = (1, 5, 20);
    _CLOUD_CTA_LARGE_GRAPH_NODES = 25000;
}

def _print_cloud_cta(out_dir: "Path", node_count: int = 0);

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

def _pattern_terms(pattern: str) -> list[str];
def _rel_to_root(file_path: str, `root: "Path") -> "str | None";
def _search_hint_terms(t: dict) -> list[str];
def _hint_text(value: object, cap: int) -> str;
def _graph_hint(terms: "list[str]", rel_file: "str | None") -> tuple[str, list[str]];
def _with_hint(nudge: str, terms: "list[str] | None" = None, rel_file: "str | None" = None) -> str;
def _stamped_manifest_files(
    files_by_type: dict[str, list[str]],
    sem_result: dict,
    `root: Path,
    partial_source_files: "set[str] | None" = None,
    failed_ast_sources: "set[str] | list[str] | None" = None,
    unverified_semantic_sources: "set[str] | list[str] | None" = None,
) -> dict[str, list[str]];
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
def _stale_graph_sources(
    graph_path: Path, scan_root: Path, seen_files: set[str], detection: dict | None = None
) -> list[str];
def _zero_node_stamped_code_sources(
    graph_path: Path, scan_root: Path, unchanged_code: list[str], manifest_path: Path | None = None
) -> list[str];
def _zero_node_stamped_semantic_sources(
    graph_path: Path, scan_root: Path, unchanged_semantic: list[str]
) -> list[str];
def _record_extract_cost(graphify_out: Path, input_tokens: int, output_tokens: int, files: int);
def _prune_graph_json_sources(graph_path: Path, stale_sources: list[str]) -> int;

obj _StageTimer {
    has _now: any,
        enabled: any,
        start: any,
        _last: any;

    def init(enabled: bool);

    def mark(stage: str);

    def total;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def _enforce_graph_size_cap_or_exit(gp: Path);
def _load_cli_graph(gp: Path) -> any;
def _hook_strict_enabled(flag: bool) -> bool;
def _touch_query_stamp(graph_path: "Path");
def _query_stamp_fresh -> bool;
def _nudge_allowed(payload: dict) -> bool;
def _gc_hook_session_markers(d: "Path");
def _reset_hook_session(session_id: str);
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

def _bash_commands(cmd_str: str) -> Generator[any, any, any];
def _bash_invokes_search(cmd_str: str) -> bool;
def _sed_awk_in_place(name: str, args: "list[str]") -> bool;

with entry {
    _BASH_READERS = frozenset({"cat", "head", "tail", "sed", "nl", "less", "more", "bat"});
    _BASH_READ_SKIP_EXTS = (".md", ".rst", ".txt", ".mdx");
}

def _bash_read_target(cmd_str: str, cwd: str = "") -> "str | None";
def _search_is_outside_project(tool_input: dict) -> bool;
def _run_hook_guard(kind: str, strict: bool = False);
def _is_cwd_relative(value: str) -> bool;
def _target_matches_manifest(file_path: str, `root: "Path") -> bool;
def _target_is_indexed(file_path: str, `root: "Path") -> bool;
def _clone_repo(url: str, branch: str | None = None, out_dir: Path | None = None) -> Path;

def _reenter_main;

def dispatch_command(cmd: str);
