import importlib;
import operator;
import from __future__ { annotations }

import builtins;

import contextlib;

import errno;

import inspect;

import json;

import logging;

import os;

import posixpath;

import multiprocessing;

import re;

import signal;

import sys;

import threading;

import time;

import from pathlib { Path }

import from typing { Callable }

glob _GRAPHIFY_OUT: any = _PATHS_OUT;

glob logger: any;

glob _PENDING_FILENAME: any;

glob _PENDING_FULL_FILENAME: any;

glob _PENDING_INCREMENTAL_FILENAME: any;

glob _PENDING_DRAIN_MAX_PASSES: any;

glob _BUILD_CONFIG_FILENAME: any;

glob _WIN_LOCK_CONTENDED_ERRNOS: any;

glob _WATCHED_EXTENSIONS: any;

glob _CODE_EXTENSIONS: any;

glob _PORTABLE_PATH_KEYS: any;

glob _REMOTE_SOURCE_RE: any;

glob _SKIP: any;

glob _BUILD_STATE_NAME: any;

glob _READ_ONLY_EVENT_TYPES: any;

glob parser: any;

glob args: any;

glob argparse: any;

with entry {
    logger = logging.getLogger(__name__);
    _PENDING_FILENAME = ".pending_changes";
    _PENDING_FULL_FILENAME = ".pending_full";
    _PENDING_INCREMENTAL_FILENAME = ".pending_incremental";
    _PENDING_DRAIN_MAX_PASSES = 20;
}

"""Append ``changed_paths`` to ``out_dir/.pending_changes`` (one per line).

    Used by a post-commit hook process that cannot acquire ``_rebuild_lock``
    so its change set is not silently dropped (#1059). The lock-holding
    process drains this file before and after its rebuild and merges the
    contents with its own change set.

    Opened in append mode so concurrent writers do not clobber each other on
    POSIX; each ``write()`` of a small payload is effectively atomic. A
    trailing newline is always written so partial-line corruption stays
    confined to the offending entry and is skipped on drain.
    """
def _queue_pending(out_dir: Path, changed_paths: list[Path]) -> None;

"""Read + unlink ``out_dir/.pending_changes`` and return deduplicated paths.

    Returns an empty list if the file does not exist. Empty/whitespace lines
    are silently skipped so a partial concurrent write that left only a
    fragment cannot poison the merge.
    """
def _drain_pending(out_dir: Path) -> list[Path];

"""Record that a full-corpus rebuild was requested but could not run.

    Full requests (watcher, post-checkout hook) have no path list to append to
    ``.pending_changes``, so they leave a marker file instead. The lock-holder
    consumes it and runs one more full pass before releasing (#4274).

    A derived incremental request has no path list either, but it needs a pass of
    its own kind rather than a full one; that is
    :func:`_queue_pending_incremental`.
    """
def _queue_pending_full(out_dir: Path) -> None;

"""Consume the full-rebuild marker. Returns True if one was queued."""
def _drain_pending_full(out_dir: Path) -> bool;

"""Record that an incremental rebuild was requested but could not run.

    An incremental request names no paths: it derives its change set from the
    manifest *inside* the lock (#4740). So it cannot append to
    ``.pending_changes``, and ``.pending_full`` would be a lie — the drain runs
    after the lock the caller then wins, so a full marker would upgrade that
    caller's own pass to a full rebuild. This third marker says the one thing the
    other two cannot: run an incremental pass.
    """
def _queue_pending_incremental(out_dir: Path) -> None;

"""Consume the incremental-rebuild marker. Returns True if one was queued."""
def _drain_pending_incremental(out_dir: Path) -> bool;

with entry {
    _BUILD_CONFIG_FILENAME = ".graphify_build.json";
}

"""Persist corpus-shaping options under ``out_dir``.

    Best effort and non clobbering: omitted options retain their existing values.
    ``code_only`` records that the graph was built with ``extract --code-only``
    so a later hook/update/watch rebuild keeps that scope (#4923).
    """
def _write_build_config(
    out_dir: Path,
    *,
    excludes: "list[str] | None",
    gitignore: bool | None = None,
    code_only: bool | None = None,
) -> None;

"""Return the persisted ``--exclude`` patterns for this graph, or []."""
def _read_build_excludes(out_dir: Path) -> list[str];

"""Return whether rebuilds should honor VCS ignore files (default True)."""
def _read_build_gitignore(out_dir: Path) -> bool;

"""Return whether the graph was built with ``--code-only`` (default False).

    A rebuild has no CLI flag of its own, so this record is the only way it can
    tell a deliberately code-only graph from a full one (#4923).
    """
def _read_build_code_only(out_dir: Path) -> bool;

"""Concatenate path lists, preserving order and dropping duplicates.

    Used to combine a hook process's own ``changed_paths`` with the drained
    contents of ``.pending_changes`` so the lock-holding rebuild covers
    every queued commit's worth of files (#1059).
    """
def _merge_changed_paths(*sources_: "list[Path] | None") -> list[Path];

with entry {
    _WIN_LOCK_CONTENDED_ERRNOS = frozenset({errno.EACCES, errno.EDEADLK});
}

"""One non-blocking msvcrt lock attempt: None on success, else the error."""
def _win_try_lock(fh, msvcrt, offset: int) -> OSError | None;

"""Per-repo advisory lock around a rebuild.

    Yields True if acquired, False if another rebuild is already running and
    ``blocking`` is False. Uses fcntl.flock (POSIX) or msvcrt.locking (Windows)
    so the lock is released automatically if the process is killed (no stale-lock
    cleanup needed).

    While the lock is held, ``.rebuild.lock`` contains the owning PID followed
    by a newline so external pollers (publish scripts, etc.) can read it.
    On successful release the file is unlinked so downstream tooling that
    waits for the lock to clear by polling for its absence unblocks promptly.

    Falls back to a no-op yield(True) on platforms without fcntl or msvcrt.
    On Windows, a filesystem where msvcrt.locking is unsupported (e.g. the WSL
    share \\wsl.localhost) also gets yield(True), with a warning on stderr,
    instead of waiting forever for a lock that can never be taken (#4924). That
    path leaves an existing ``.rebuild.lock`` untouched: it may belong to a
    flock holder on the other side of the share.
    """
@contextlib.contextmanager
def _rebuild_lock(out_dir: Path, *, blocking: bool = False) -> Generator[any, any, any];

"""Best-effort nice + memory cap. Called from inline hook scripts.

    GRAPHIFY_REBUILD_MEMORY_LIMIT_MB caps RSS-ish memory. Uses RLIMIT_DATA on
    macOS (RLIMIT_AS is unreliable under Apple's libmalloc) and RLIMIT_AS on
    Linux. Silently skips if the platform doesn't support it.
    """
def _apply_resource_limits -> None;

"""Return current git HEAD commit hash, or None outside a repo.

    ``cwd`` selects the repository to ask (#2316). Without it the command
    inherits the caller's working directory, so `graphify update <target>`
    stamped the *invoking* repo's commit into the target's graph.json — the
    same CWD-anchoring mistake as the manifest path, but writing wrong
    provenance rather than a misplaced file.
    """
def _git_head(cwd: Path | str | None = None) -> str | None;

with entry {
    _WATCHED_EXTENSIONS = CODE_EXTENSIONS | DOC_EXTENSIONS | PAPER_EXTENSIONS | IMAGE_EXTENSIONS;
    _CODE_EXTENSIONS = CODE_EXTENSIONS;
}

def _report_root_label(watch_path: Path) -> str;

"""The value to write into ``.graphify_root``.

    Ordinarily preserves the caller-supplied path verbatim (relative or
    absolute) so a committed ``graphify-out/.graphify_root`` stays portable
    across clones and CI runners (#777): a relative marker like ``.`` is
    meaningless outside the CWD it was written from, but every normal reader
    of it (the generated git hooks, an unqualified ``graphify watch``) only
    runs with that same CWD anyway.

    That assumption breaks when ``GRAPHIFY_OUT`` itself is an absolute,
    shared location (the multi-worktree / shared-output setup from #686):
    the same marker file is then reachable from any worktree's CWD, not just
    the one that wrote it, so a relative value silently resolves against
    whichever worktree happens to be reading it instead of the one that was
    actually scanned (#3375). Resolve to an absolute path in that case, since
    portability across clones is not the goal there to begin with, the
    output directory is already outside any one clone.
    """
def _graphify_root_marker_value(watch_path: Path) -> str;

def _is_relative_to(path: Path, `root: Path) -> bool;

"""Return plausible absolute locations for a hook-provided changed path.

    Git hooks pass paths relative to the repository root. Watch callers may
    also pass paths relative to the watched root. Keep both interpretations so
    a graph rooted at ``src`` accepts ``src/app.py`` and ``app.py``.
    """
def _changed_path_candidates(raw: Path, *, change_root: Path, watch_root: Path) -> list[Path];

with entry {
    _PORTABLE_PATH_KEYS = ("source_file", "definition_file");
}

def _relativize_source_files(payload: dict, `root: Path, *, scope: Path | None = None) -> None;

"""Rebase cache-root-relative source paths onto the project root."""
def _rebase_relative_source_files(payload: dict, source_root: Path, target_root: Path) -> None;

"""Resolve source_file values across current and legacy graph roots."""
obj _StoredSourcePaths {
    has project_root: any,
        watch_root: any,
        _normalize_source: any,
        existing_source_root: any,
        _identity_cache: any,
        _in_watch_root_cache: any,
        _absolute_identity_cache: any,
        _rebased_cache: any,
        legacy_watch_relative: any;

    def init(existing: dict, *, out: Path, project_root: Path, watch_root: Path, normalize_source);

    """Whether stored relative source_file paths resolve under ``root``.

        Samples the first ``sample`` relative entries: the first hit accepts
        the anchor; ``sample`` consecutive misses reject it. A graph with no
        relative sources returns True (any anchor is harmless there). The
        bound keeps the check O(sample) on large graphs; its known limit is a
        commit that deletes ``sample``-plus files whose nodes happen to sort
        first — the anchor then falls back to the marker, matching the
        pre-fix behavior (no worse).
        """
    def _anchors_stored_sources(existing: dict, `root: Path, sample: int = 25) -> bool;

    def normalize(source_file: str | None) -> str | None;

    def absolute_identity(source_file: str | None, `root: Path) -> str | None;

    def _absolute_identity_uncached(source_file: str | None, `root: Path) -> str | None;

    def identity(source_file: str | None) -> str | None;

    def _identity_uncached(source_file: str | None) -> str | None;

    def in_watch_root(source_file: str | None) -> bool;

    def is_evicted(item: dict, identities: set[str]) -> bool;

    def rebase_preserved(item: dict) -> None;

    """The source_file a preserved item is stored with, or None to leave it as is."""
    def _rebased_uncached(source_file: str | None) -> str | None;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

with entry {
    _REMOTE_SOURCE_RE = re.compile("^[A-Za-z][A-Za-z0-9+.\\-]+://?");
}

def _is_remote_source(source_file: str) -> bool;

"""Reconcile Markdown links without losing semantic-backed targets.

    Semantic-backed documents are deliberately skipped by the AST quick scan
    (#1915/#1954), so their canonical file node can be absent. Re-point an
    authored link only when both files have unique representatives. If either
    side is ambiguous, retain the existing AST edge instead of guessing or
    deleting it. A link removed from its owning Markdown source is pruned.

    Only authored links are owned here. A code-span mention (a ``references``
    edge the markdown_mentions resolver emits) targets a code symbol rather
    than a file representative, so it is left to the AST ownership rule above:
    re-extracting the document regenerates it and re-extracting the code side
    keeps or drops it with the target node.
    """
def _reconcile_markdown_links(
    result: dict,
    preserved_edges: list[dict],
    preserved_nodes: list[dict],
    code_files: list[Path],
    extract_targets: list[Path],
    full_rebuild: bool,
    project_root: Path,
    source_paths,
) -> list[dict];

"""Missing source paths that were never scanned but an unchanged file still points at.

    An extractor can mint a node for a file that is not in the checkout: the
    target of an unresolved dynamic import (``import('./queue.js')``) or a
    project a ``.sln`` / ``<ProjectReference>`` names. The node carries that
    path as its ``source_file``, but it is the REFERRING file's output. The
    corpus sweep read the missing path as a deleted source and evicted it, so
    the unchanged referrer's preserved edges to it dangled and were dropped,
    while a full rebuild of the same tree keeps both.

    Deletion evidence (#1795) is the previous scan: a path listed in
    manifest.json was a real file and is evicted as before. A path that was
    never scanned cannot have been deleted; its nodes stay while a referrer
    that is not re-extracted this run still points at them. A re-extracted
    referrer re-emits them (or not) itself. A path whose nodes carry a
    ``source_location``, or that is the ``source_file`` of any edge, was
    extracted itself and is evicted even if the manifest is stale. Without a
    readable manifest that lists today's files, the old behaviour is kept.
    """
def _referenced_unscanned_identities(
    existing: dict,
    source_paths: "_StoredSourcePaths",
    *,
    out: Path,
    project_root: Path,
    live_sources: "set[str | None]",
    rebuilt_sources: "set[str | None]",
) -> set[str];

"""Merge fresh extraction with preserved graph entries and evict stale sources.

    ``is_ignored_always``/``is_ignored_full`` (#2495) report whether a LIVE
    ignore rule matches a path, mirroring the detect() call that produced
    ``code_files`` (detect.ignored_predicate). ``is_ignored_always`` covers
    .graphifyignore + persisted ``--exclude`` patterns — unambiguous
    graph-level intent, honored on every rebuild. ``is_ignored_full`` adds
    .gitignore-driven rules, honored only on a full rebuild (an explicit
    ``graphify update``) so the incremental/hook path keeps preserving a
    deliberately-graphed .gitignore'd tree (#1795).
    """
def _reconcile_existing_graph(
    existing_graph: Path,
    result: dict,
    *,
    out: Path,
    project_root: Path,
    watch_root: Path,
    code_files: list[Path],
    extract_targets: list[Path],
    full_rebuild: bool,
    deleted_paths: set[str],
    deleted_source_identities: set[str],
    is_ignored_always: Callable[[Path], bool] | None = None,
    is_ignored_full: Callable[[Path], bool] | None = None,
) -> tuple[dict, dict];

def _node_community_map(graph_data: dict) -> dict[str, int];

def _canonical_graph_for_compare(graph_data: dict) -> dict;

def _canonical_topology_for_compare(graph_data: dict) -> dict;

with entry {
    _SKIP = object();
}

"""Order-independent topology fingerprint, equivalent to comparing the
    sorted canonical form of ``_canonical_topology_for_compare`` but computed in
    a single O(N+E) pass with no global sort and no full-graph re-serialize.

    For each node/edge/hyperedge we hash *exactly* the same canonical per-element
    JSON that ``_canonical_topology_for_compare`` used as its sort key (same field
    stripping: nodes drop community/community_name/norm_label; links & edges
    normalise _src/_tgt -> source/target and drop confidence_score), then combine
    the per-element digests order-independently (modular SUM, which — unlike XOR —
    preserves multiset multiplicity so duplicate/parallel elements can't cancel).
    Each list is replaced by a tiny {count, digest} summary; the surrounding
    metadata (built_at_commit dropped, graph schema_version/graphify_version
    dropped) is carried through unchanged so the overall equality verdict is
    identical to the old sort-and-serialize compare.
    """
def _topology_signature_for_compare(graph_data: dict) -> dict;

def _topology_from_graph(G) -> dict;

"""Return True (ok to proceed) or False (shrink refused).

    When False, cleans up *tmp* if provided and prints a warning to stderr.

    The shrink-guard exists to catch SILENT shrinkage from failed extraction
    chunks (a half-written semantic pass leaving thousands of nodes
    unaccounted for). When ``had_explicit_deletions`` is True, the caller
    has declared which files were removed (e.g. the post-commit hook saw
    a ``D`` in ``git diff --name-only``) and a smaller graph is the expected
    outcome — skip the guard so legitimate refactors don't require ``--force``.

    ``rebuilt_sources`` (when given) is the set of source files re-extracted this
    run. A net shrink is legitimate — not a failed chunk — when every *lost* node
    belonged to one of those files (a symbol removed from a re-extracted file) or
    carries no source_file. Only an unexplained loss (a node from a file we did
    NOT touch — e.g. a dropped semantic/doc node) refuses the write. This lets a
    plain ``graphify update`` after deleting a function refresh the graph without
    ``--force`` (#1116 left stale nodes write-blocked even though build dropped them).
    Files in ``failed_sources`` never account for lost nodes: extraction did not
    complete, so their disappearance is the silent shrink this guard protects.

    A larger total is not enough when a saved semantic id is gone (#2229).
    ``deleted_sources`` is the files the user removed. A semantic node on one of
    those files may go. A semantic node on a file that is still present may not.
    The rebuilt set is not that list: an update re-extracts code and must not
    treat a rationale node on that file as a deleted symbol.
    """
def _check_shrink(
    force: bool,
    existing_data: dict,
    new_data: dict,
    tmp: "Path | None" = None,
    *,
    had_explicit_deletions: bool = False,
    rebuilt_sources: "set[str] | None" = None,
    failed_sources: "set[str] | None" = None,
    deleted_sources: "set[str] | None" = None,
) -> bool;

def _report_for_compare(report_text: str) -> str;

"""True when ``path`` holds one line (the compact graph.json layout, #3413)."""
def _is_single_line(path: Path) -> bool;

def _json_text(data: dict) -> str;

"""Ensure relative rebuild paths have a usable CWD before queue/lock setup.

    Detached git hooks can inherit a transient working directory that is deleted
    before the background rebuild starts. In that state Path.cwd(),
    Path('.').resolve(), and relative graphify-out mkdirs raise FileNotFoundError
    before the normal rebuild error handling can run. Hooks that know the repo
    root export GRAPHIFY_REPO_ROOT so the rebuild can recover by chdir'ing there.
    """
def _stabilize_rebuild_cwd(watch_path: Path) -> bool;

"""True when nothing that can change the code graph changed since the last run.

    Compares the fresh scan against the previous run's manifest by CONTENT
    (``ast_hash``), never by mtime alone, over three input sets: every detected
    bucket, the manifest rows the scan no longer covers, and the JS/TS resolution
    inputs. A tsconfig/jsconfig/package.json edit can move a .ts result without
    touching a source file, and the lock files are resolution inputs the scan
    skips by name, so detect() reports them separately (#4740).

    Fails closed. A missing or unreadable manifest, a row that cannot be verified,
    or anything this cannot prove unchanged returns False so the caller takes the
    full path: a false "changed" only costs time, a false "unchanged" ships a
    stale graph.
    """
def _inputs_unchanged(detected: dict, manifest_path: Path, `root: Path) -> bool;

with entry {
    _BUILD_STATE_NAME = ".graphify_build_state.json";
}

"""Identity of the extraction pipeline behind the current AST output.

    The same triple the AST cache is namespaced by, so anything that invalidates
    cached fragments also invalidates a graph built from the old ones. Without it
    the gate would skip a graph the current extractor would not reproduce, which
    is how the legacy-stub and legacy-marker heals work (#4740).
    """
def _extractor_epoch -> str;

"""Fingerprint of WHICH files the scan covers, not what they contain (#4740).

    The manifest cannot answer this on its own: a source whose extraction fails
    is deliberately left unstamped (#2543), so it has no row and a row-based
    comparison cannot tell "same file, still failing" from "file is new". Only
    the in-scope path set separates those, and it is also what catches an edit to
    an ignore rule, a rename and an outright deletion.
    """
def _scan_digest(detected: dict) -> str;

"""Everything besides file content that a rebuild's output depends on (#4740).

    A different scan root, file set, ignore set, output shape or extractor
    necessarily writes a different graph, so the previous run's stamp cannot
    vouch for it.
    """
def _current_build_state(
    *,
    watch_root: Path,
    follow_symlinks: bool,
    no_cluster: bool,
    gitignore: bool,
    excludes: list[str] | None,
    scan_digest: str,
    code_only: bool = False,
) -> dict;

"""Cheap structural check that ``path`` holds a whole JSON object (#4748).

    Deliberately not a full ``json.load``. graph.json is capped at 512 MiB by
    default (``GRAPHIFY_MAX_GRAPH_BYTES``), and the rebuild that just wrote it is
    still holding its own copy of the graph, so parsing it again can add a
    gigabyte of peak RSS to answer one question: did the bytes land whole.
    Reading the first and last non-whitespace byte answers that for the failure
    this guards, a partial or truncated publish, which the atomic replace can
    still produce through its non-atomic fallback.

    Says nothing about corruption in the middle of the file. That would change
    mtime, which the caller's own stat comparison catches.
    """
def _graph_json_is_complete(path: Path) -> bool;

"""Stamp what the next run has to match to skip (#4740).

    Refuses to stamp unless the outputs it is about to describe are on disk and
    whole. A stamp is a promise that the next run may skip, so writing one over a
    graph.json that a failed or partial publish left behind turns that promise
    into a stale graph nothing ever repairs (#4748). Any doubt means no stamp,
    which costs the next run a full rebuild and nothing else.
    """
def _write_build_state(out: Path, state: dict, *, full_clean: bool) -> None;

"""True when ``out`` still holds exactly what the last stamped rebuild wrote.

    Fails closed on anything it cannot prove: a missing or unreadable stamp, a
    graph.json another writer replaced or partly wrote, a pending HTML re-render,
    or a last rebuild that was itself incremental (which is never a sound base
    for skipping a full one).
    """
def _build_state_matches(out: Path, state: dict) -> bool;

"""Reconcile missing, stale, or explicitly disabled HTML visualization.

    The unchanged-topology update path deliberately avoids clustering and
    rewriting core artifacts. HTML is independently derivable, so rebuild it
    from the communities and names already stored in graph.json when absent or
    marked stale by a prior failed render.

    Returns ``"rendered"`` or ``"removed"`` when it changed the HTML state,
    otherwise ``None``.
    """
def _reconcile_graph_html(out: Path, graph_data: dict) -> str | None;

"""Keep a matching graph if the report already matches or can be restored."""
def _keep_unchanged_clustered_graph(
    graph_tmp: Path, existing_graph_data: dict, report_path: Path, `report: str, *, same_graph: bool
) -> bool;

"""Re-run AST extraction + build + optional cluster + report for code files. No LLM needed.

    When ``force`` is True the node-count safety check in ``to_json`` is bypassed
    so the rebuilt graph overwrites graph.json even if it has fewer nodes.
    Use this after refactors that legitimately delete code.

    When ``changed_paths`` is provided, only those files are re-extracted; nodes
    for unchanged files are preserved from the existing graph. Deleted paths
    in ``changed_paths`` (paths that no longer exist on disk) are dropped from
    the preserved set. When ``changed_paths`` is None the full code corpus is
    re-extracted (used by the watcher and post-checkout hook).

    ``incremental`` asks for the change set to be derived from the manifest
    instead of from ``changed_paths`` (#4740). It applies only when
    ``changed_paths`` is None and ``force`` is False, so an explicit list always
    wins and ``--force`` always means a full rebuild. A manifest that is
    missing, unreadable or empty leaves the full path in place: "no rows" means
    "unknown", never "nothing changed".

    ``acquire_lock`` (default True) takes a non-blocking per-repo flock around
    the rebuild so concurrent post-commit hooks across multiple repos do not
    pile up. Returns False with a log line if the lock is held. Pass
    ``block_on_lock=True`` to wait instead of skip (used by the interactive
    ``graphify update`` CLI).

    ``no_cluster`` skips community detection and writes raw merged extraction
    JSON to graphify-out/graph.json (mirrors ``extract --no-cluster``).

    Returns True on success, False on error or skipped-due-to-lock.
    """
def _rebuild_code(
    watch_path: Path,
    *,
    changed_paths: list[Path] | None = None,
    incremental: bool = False,
    follow_symlinks: bool = False,
    force: bool = False,
    no_cluster: bool = False,
    acquire_lock: bool = True,
    block_on_lock: bool = False,
) -> bool;

"""Check for pending semantic update flag and notify the user if set.

    Cron-safe: always returns True so cron jobs do not alarm.
    Non-code file changes (docs, papers, images) require LLM-backed
    re-extraction via `/graphify --update` — this function only signals
    that the update is needed.
    """
def check_update(watch_path: Path) -> bool;

"""Write a flag file and print a notification (fallback for non-code-only corpora)."""
def _notify_only(watch_path: Path) -> None;

def _has_non_code(changed_paths: list[Path]) -> bool;

"""True when a debounced watch batch needs an immediate rebuild.

    Code changes always rebuild (AST extraction needs no LLM). Deletions of
    ANY watched file also rebuild: eviction needs no LLM either — the full
    corpus reconcile drops nodes whose source is gone from disk. Without
    this, a doc-only deletion batch would sit behind the needs_update flag
    until the next code event or a manual `graphify update` (#2580).
    """
def _batch_triggers_rebuild(batch: list[Path]) -> bool;

"""Watchdog events that mean a file actually changed, not just was read.

    Passing this as ``event_filter`` keeps ``IN_OPEN`` and
    ``IN_CLOSE_NOWRITE`` out of the inotify mask. The recursive watch-setup
    walk then produces no events of its own, so it cannot overflow the kernel
    queue and trigger watchdog's rebuild loop (#5033).
    """
def _watch_event_filter -> any;

"""True when this watchdog's ``schedule()`` declares ``event_filter``.

    ``event_filter`` was added in watchdog 4.0. Graphify does not pin a minimum
    watchdog version, so detect support instead of raising TypeError on older
    installs. Introspection failures are treated as unsupported; the caller
    warns on that path so a future signature change is visible.
    """
def _observer_accepts_event_filter(observer) -> bool;

with entry {
    _READ_ONLY_EVENT_TYPES = frozenset({"opened", "closed_no_write"});
}

"""True for watchdog events that mean a file was merely READ, not changed.

    On Linux, inotify (watchdog >= 2.3) reports ``opened`` and, since watchdog 4,
    ``closed_no_write`` for every file open/close — including the watcher's own
    AST rebuild reading the tree, hook guards stat-ing sources, and editors or
    agents reading files. Counting those as changes makes the watcher re-trigger
    itself forever ("N file(s) changed" while nothing was modified), burn CPU and
    keep re-writing the ``needs_update`` flag. Only creation, modification, move,
    deletion and close-after-write are changes; macOS (PollingObserver) never
    emits these, so the filter is a no-op there.
    """
def _is_read_only_event(event) -> bool;

"""True when the batch contains a non-code file that still exists on disk.

    Only surviving non-code files need the needs_update flag (LLM-backed
    re-extraction); deleted ones are already handled by the rebuild's
    reconcile sweep, so a pure-deletion batch must not leave a stale flag.
    """
def _batch_needs_llm_flag(batch: list[Path]) -> bool;

"""Bound one watch-loop rebuild by GRAPHIFY_REBUILD_TIMEOUT seconds (0 disables).

    Mirrors the hook rebuild (#791, #2148): SIGALRM raises TimeoutError where it
    exists; elsewhere (Windows) a timer thread kills the pool workers and exits
    the process, since nothing can interrupt the main thread (#2173).
    """
@contextlib.contextmanager
def _rebuild_timeout -> Generator[any, any, any];

"""
    Watch watch_path for new or modified files and auto-update the graph.

    For code-only changes: re-runs AST extraction + rebuild immediately (no LLM).
    For doc/paper/image changes: writes a needs_update flag and notifies the user
    to run /graphify --update (LLM extraction required).

    debounce: seconds to wait after the last change before triggering (avoids
    running on every keystroke when many files are saved at once).
    """
def watch(watch_path: Path, debounce: float = 3.0) -> None;

with entry:__main__ {
    import argparse;
    parser = argparse.ArgumentParser(
        description="Watch a folder and auto-update the graphify graph"
    );
    parser.add_argument("path", nargs="?", default=".", help="Folder to watch (default: .)");
    parser.add_argument(
        "--debounce",
        type=float,
        default=3.0,
        help="Seconds to wait after last change before updating (default: 3)",
    );
    args = parser.parse_args();
    watch(Path(args.path), debounce=args.debounce);
}
