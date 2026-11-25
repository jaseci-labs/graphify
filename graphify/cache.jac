import builtins;

import operator;
import from __future__ { annotations }

import atexit;

import hashlib;

import json;

import os;

import re;

import tempfile;

import time;

import warnings;

import from collections.abc { Callable, Iterable }

import from pathlib { Path }

import from typing { Any }

glob _EXTRACTOR_VERSION: any;

glob _pkg_version: any;

glob _AST_CACHE_SCHEMA: any;

glob _GRAMMAR_FINGERPRINT_CACHE: "str | None";

glob _cleaned_ast_dirs: any;

glob _PROMPT_FP_LEN: any;

glob _legacy_semantic_hits: any;

glob _corrupt_cache_entries: any;

glob _prompt_fp_cache: dict[tuple[Any, ...], str];

glob _FRONTMATTER_DELIM: any;

glob _stat_index: dict[str, dict[str, Any]];

glob _stat_index_root: Path | None;

glob _stat_index_anchor: Path | None;

glob _stat_index_dirty: bool;

glob _stat_index_atexit_registered: bool;

glob _stat_index_path: Path | None;

glob _MTIME_GRANULARITY_NS: any;

glob _ROOT_MARKER: any;

glob _CACHED_TARGETS_KEY: any;

with entry {
    try {
        import from importlib.metadata { version as _pkg_version }

        _EXTRACTOR_VERSION = _pkg_version("graphifyy");
    } except Exception {
        _EXTRACTOR_VERSION = "unknown";
    }
    _AST_CACHE_SCHEMA = 55;
    _GRAMMAR_FINGERPRINT_CACHE = None;
}

"""Short stable fingerprint of the installed tree-sitter grammar set.

    AST output depends on the grammar packages, not just graphify's own
    version: upgrading ``tree-sitter-swift`` changes what the extractor
    produces for the same file, so the cache namespace must change too,
    otherwise stale pre-upgrade extractions are served indefinitely
    (#4236). Covers the ``tree-sitter`` runtime, every ``tree-sitter-*``
    distribution, and bundled packs like ``tree-sitter-language-pack``."""
def _grammar_fingerprint -> str;

with entry {
    _cleaned_ast_dirs = set[any]();
}

"""Remove AST cache entries left behind by other graphify versions or
    grammar sets.

    Sweeps sibling ``v*/`` directories and unversioned ``*.json`` entries
    (the pre-versioning layout) under ``cache/ast/``. Best-effort: failures
    are ignored, stragglers are retried on the next run.
    """
def _cleanup_stale_ast_entries(ast_base: Path, current_dir: Path) -> None;

with entry {
    _PROMPT_FP_LEN = 12;
    _legacy_semantic_hits = 0;
    _corrupt_cache_entries = 0;
    _prompt_fp_cache = {};
}

"""Return a short stable fingerprint of an extraction prompt.

    ``prompt`` is either the prompt text itself (the Python extraction path owns
    its system prompt, :func:`graphify.llm._extraction_system`) or a Path to the
    prompt file an agent loaded (the skill path's
    ``references/extraction-spec.md``).

    Line endings and trailing whitespace are normalized before hashing: the same
    spec file checked out with CRLF on Windows must not fingerprint differently
    from the LF checkout that wrote the cache, or every Windows run would look
    like a prompt change and re-bill extraction.
    """
def prompt_fingerprint(prompt: "str | Path") -> str;

"""Fingerprint the caller's extraction prompt, or None when it supplied none.

    ``prompt`` is prompt TEXT; ``prompt_file`` is a path to a file CONTAINING the
    prompt. They are separate parameters rather than one overloaded argument
    because the skill-driven callers are markdown snippets an agent copies with a
    path substituted in — passing that path as ``prompt`` would hash the path
    string itself, yielding a fingerprint that is stable, plausible, and tracks
    nothing about the prompt. A silent wrong fingerprint is the exact failure
    class #1939 is about, so the two are not inferred from each other.

    Best-effort: an unreadable ``prompt_file`` falls back to the flat, unattributed
    layout rather than failing the run — a cache is never worth aborting an
    extraction over. It warns rather than falling back quietly, because that
    fallback silently restores the very behavior this fixes, and the skill-side
    caller substitutes this path by hand.
    """
def _resolve_prompt_fp(
    prompt: "str | Path | None" = None, prompt_file: "str | Path | None" = None
) -> str | None;

with entry {
    _FRONTMATTER_DELIM = re.compile("^---[ \\t]*\\r?$", re.MULTILINE);
}

"""Strip YAML frontmatter from Markdown content, returning only the body."""
def _body_content(content: bytes) -> bytes;

with entry {
    _stat_index = {};
    _stat_index_root = None;
    _stat_index_anchor = None;
    _stat_index_dirty = False;
    _stat_index_atexit_registered = False;
    _stat_index_path = None;
    _MTIME_GRANULARITY_NS = 2000000000;
}

"""Return the assumed filesystem mtime granularity in nanoseconds.

    Read fresh on every call so the env var can be set after import (and so
    tests can flip it without reloading the module).
    """
def _mtime_granularity_ns -> int;

"""True if ``entry`` provably describes the file's CURRENT content.

    Beyond matching (size, mtime_ns), the entry must be *racily clean* in git's
    sense: we must have read the content strictly after the file's mtime tick
    had already closed. Otherwise a write that landed between our read and the
    end of that tick would have left mtime (and, for a same-length edit, size)
    untouched, and the stored digest would describe content that is no longer
    on disk.

    ``indexed_at_ns`` is the wall clock captured immediately BEFORE the content
    was read. Requiring ``mtime + granularity <= indexed_at`` means any later
    write necessarily lands in a new tick and so changes mtime, making it
    visible to the next signature comparison.

    Entries written by an older graphify carry no ``indexed_at_ns``; they are
    treated as untrusted (one re-read each), and gain the field when rewritten.
    """
def _stat_sig_fresh(`entry: object, st: "os.stat_result") -> bool;

"""Get-or-reset the index entry for ``abs_key`` and stamp when it was read.

    Reuses the existing dict when the stat signature still matches, so
    co-located values (other salts' digests, ``word_count``) survive; resets it
    otherwise, so a stale ``word_count`` cannot outlive the content it counted.

    ``observed_at_ns`` must be the clock reading taken *before* the content was
    read — see :func:`_stat_sig_fresh` for why the ordering matters.
    """
def _stat_entry_for(abs_key: str, st: "os.stat_result", observed_at_ns: int) -> dict;

"""Return ``key`` as a forward-slash relative path from ``anchor``.

    Local duplicate of :func:`graphify.detect._to_relative_for_storage` —
    detect imports cache, so cache cannot import detect without a cycle
    (and pulling detect in during the atexit flush would be fragile).
    Out-of-anchor and already-relative keys pass through unchanged, and
    ``..``-escaping relpaths are rejected (kept absolute), mirroring the
    manifest's portability rules.
    """
def _stat_key_to_relative(key: str, anchor: Path) -> str;

"""Inverse of :func:`_stat_key_to_relative`.

    Re-anchor a stored relative key against ``anchor``. Already-absolute keys
    (legacy indexes, out-of-anchor entries) pass through unchanged so an index
    written by an older graphify remains readable.
    """
def _stat_key_to_absolute(key: str, anchor: Path) -> str;

def _stat_index_file(`root: Path) -> Path;

def _ensure_stat_index(`root: Path, cache_root: "Path | None" = None) -> None;

def _flush_stat_index -> None;

"""Normalize a path for cache identity without folding case.

    Windows spellings can differ in separators and in the optional
    extended-length prefix. Case is not equivalent on every volume a Windows
    process can reach, so the key keeps the caller's case. Use
    paths.os_long_path() for the path handed to the filesystem.
    """
def _normalize_path(path: Path) -> Path;

glob root_default_: any;

with entry {
    root_default_ = Path(".");
}

"""SHA256 of file contents + path relative to root.

    Uses a stat-based fastpath (size + mtime_ns) to skip full reads when the
    file hasn't changed. Falls through to full SHA256 on first encounter, when
    stat changes, and when the recorded signature is not yet provably stable
    (see :func:`_stat_sig_fresh`) — so two different contents can never share a
    digest. Index is flushed atomically at process exit.

    Using the walked path relative to root keeps distinct symlink aliases from
    sharing an extraction entry while preserving portability across machines
    and checkout directories. Falls back to the resolved path when the walked
    path cannot be expressed relative to root.

    For Markdown files (.md), only the body below the YAML frontmatter is hashed,
    so metadata-only changes (e.g. reviewed, status, tags) do not invalidate the cache.

    The path handed to the filesystem comes from os_long_path(); the cache key
    preserves case because case sensitivity belongs to the volume, not the
    platform (#4925).
    """
def file_hash(path: Path, `root: Path = root_default_, cache_root: "Path | None" = None) -> str;

"""Word count with the same (size, mtime_ns) stat-fastpath cache as
    :func:`file_hash`, persisted in the shared stat index.

    ``detect()`` counts words in every PDF/docx/text file to size the corpus,
    which re-opens and re-parses every binary on each run — minutes on a large
    docs corpus even when only a handful of files changed (#1656). This caches
    the count against the file's stat signature so an unchanged file is counted
    once and read from the index thereafter. ``compute(path)`` produces the
    count on a miss. A file that can't be stat'd (e.g. a Windows long path the
    index normalization can't reach) simply recomputes and isn't cached —
    correct, just not accelerated.
    """
def cached_word_count(path: Path, `root: Path, compute, cache_root: "Path | None" = None) -> int;

"""Mutate ``payload`` to rewrite absolute ``source_file`` fields as
    forward-slash relative paths from ``root``.

    Mirror of :func:`graphify.watch._relativize_source_files` so cached
    extraction fragments persist in portable form (#777). Out-of-root paths
    pass through unchanged.

    A CWD-relative field is re-anchored too. Extractors stamp ``source_file``
    with the path string ``extract()`` was handed, so relative inputs yield a
    CWD-relative stamp — but the stored format is root-relative, and
    :func:`_absolutize_source_files_in` reads it back as such. When CWD is not
    the inferred root the two disagree and a warm hit resurrects a path that
    names no file (``<root>/src/pages/index.astro`` for an input of
    ``src/pages/index.astro`` under root ``<root>``). Every source_file-GATED
    remap in ``extract()`` then misses — the file-stem prefix pass looks up
    ``Path(source_file).resolve()`` in ``prefix_remap`` — so a warm hit keeps
    the raw-path symbol ids a cold run canonicalizes: symbols stop sharing
    their file node's stem, and for absolute inputs the on-disk path survives
    into the persisted id (#2630). Only rewritten when the CWD-relative
    reading is a real file and the root-relative reading is a different path,
    so a fragment that already stores root-relative (a semantic subagent's,
    see :func:`_normalize_source_file_value`) is left alone.

    Only ``root`` is resolved — ``source_file`` itself is relativized
    symbolically so in-root symlinks keep their original name rather than
    pointing at the resolved target. Same reasoning as
    :func:`graphify.detect._to_relative_for_storage`.
    """
def _relativize_source_files_in(payload: dict, `root: Path) -> None;

"""Portable form of one ``source_file``/``definition_file`` value, or
    ``None`` when the value must be left untouched.

    Single source of truth for the per-field rule in
    :func:`_relativize_source_files_in` so the copy-on-write write path
    (:func:`_save_cached_on_disk`) reproduces it byte-for-byte.
    """
def _relativized_source_value(source: str, root_resolved: Path) -> "str | None";

"""Return ``src`` in portable form: backslashes flipped to forward slashes,
    then relativized against ``root_resolved`` when the path is in-root.

    Windows ``detect()`` emits absolute backslash paths, and a semantic
    fragment carrying one verbatim used to be persisted as-is — poisoning later
    ``graphify update`` runs with a machine-specific ``source_file`` (#2197).
    Out-of-root absolute paths pass through (slash-normalized only), same
    in/out rule and ``..``-rejection as :func:`_relativize_source_files_in`.
    """
def _normalize_source_file_value(src: "str | Path", root_resolved: Path) -> str;

"""Whether cached semantic groups belong to the requested walked path.

    Before walked paths entered the cache salt, a symlink could overwrite its
    target's unversioned semantic entry. Rejecting that mismatched legacy
    payload makes the next extraction self-heal instead of replaying it forever.
    """
def _semantic_entry_matches_path(result: dict, path: Path, `root: Path) -> bool;

with entry {
    _ROOT_MARKER = "$graphify-root$";
}

"""Return the id-slug prefix ``path_str`` contributes above ``rel_str``.

    ``_make_id`` normalizes a whole path string, and normalization distributes
    over path joins (every separator run collapses to one ``_``), so an id
    minted from an absolute path decomposes exactly as
    ``normalize_id(root) + "_" + normalize_id(rel)``. Recovering the root half
    from the file's own two spellings — rather than assuming it equals the
    scan root — keeps the decomposition exact when the extractor was handed an
    unresolved or relative path (a symlinked root such as macOS ``/tmp`` ->
    ``/private/tmp``, or inputs given relative to CWD).

    Returns "" when ``path_str`` contributes no prefix (it already IS the
    relative form) or when the two spellings disagree about the tail — both
    mean "nothing to re-anchor", which leaves the entry untouched.
    """
def _id_anchor(path_str: str, rel_str: str) -> str;

"""Root forms to strip from / restore into one cache entry (#2257).

    Returns ``(id_anchors, id_restore, path_anchors, path_restore)``. The two
    ``*_anchors`` lists are the forms a stored value may have been minted from,
    longest first so a shorter form can't shadow a longer one; the two
    ``*_restore`` values are what the CURRENT run's extractor would mint.

    Several spellings are collected because one entry can hold ids minted from
    different forms: this file's own path as passed and as resolved, plus
    cross-file edge targets minted from ANOTHER in-root file's absolute path
    (which share the scan root's spelling). They collapse to a single marker on
    write; that is safe because extract()'s remap registers both the input-form
    and absolute-resolved-form ids for every path (#1529) and maps them to the
    same canonical id, so restoring either one canonicalizes identically.
    """
def _portability_anchors(
    path: "str | Path", `root: "str | Path"
) -> tuple[list[str], str, list[str], str];

"""Apply ``fn`` to objc_field_types["tables"] KEYS (#3150).

    That table is the one extractor bucket keyed BY node id, which
    :func:`_rewrite_strings` deliberately never touches - so a cached ObjC
    shard replayed under another root kept absolute-derived class ids as keys
    while the node ids themselves were re-anchored, and the receiver-typing
    pass missed every class.
    """
def _rewrite_id_keyed_table_keys(payload: object, fn) -> None;

"""Apply ``fn`` to every string VALUE reachable in ``obj``, in place.

    Values only, never dict keys: rewriting keys blindly could silently
    collide two entries into one. The single id-keyed bucket -
    ``objc_field_types["tables"]`` - is handled by
    :func:`_rewrite_id_keyed_table_keys` beside each call to this (#3150).
    """
def _rewrite_strings(`obj: object, fn) -> None;

"""Replace the absolute root inside every stored id / path with the marker.

    Walks the WHOLE payload rather than a list of known buckets. The id form is
    self-identifying — a long casefolded path slug that nothing but an
    absolute-path-derived id can start with — so this reaches carriers a
    hand-maintained bucket list misses or has yet to grow: ``nodes[].id``,
    ``edges[].source``/``target``, hyperedge member lists under any of their
    aliases, ``raw_calls[].caller_nid``, ``swift_extensions[].nid``, plus the
    path-valued ``edges[].target_file``, ``bash_sources[].source_file`` and
    ``*_type_table.path``, which resolution passes need pointing at the current
    root to reproduce a cold run's edges.

    Call AFTER :func:`_relativize_source_files_in`: that stores ``source_file``
    as a bare relative path (the #777 format), and running this first would
    leave it marker-prefixed instead, churning the on-disk format for nothing.
    """
def _relativize_ids_in(payload: dict, path: "str | Path", `root: Path) -> None;

"""Build the id/path -> marker rewriter used by both the in-place
    (:func:`_relativize_ids_in`) and copy-on-write (:func:`_save_cached_on_disk`)
    write paths, so the two stay byte-identical."""
def _make_id_anchor_fn(id_anchors: list, path_anchors: list) -> any;

"""Inverse of :func:`_relativize_ids_in` — re-anchor to the current root.

    The restored string is assembled by slicing, never by re-normalizing: the
    stored form (``$graphify-root$_pkg_mod_base``) is a storage encoding, not a valid id,
    and running it back through ``normalize_id`` would drop the marker's ``$``
    and fuse it into the slug. Entries written before #2257 carry no marker and
    pass through untouched — they are swept anyway, since AST entries live under
    a per-version directory (:func:`cache_dir`).
    """
def _absolutize_ids_in(payload: dict, path: "str | Path", `root: Path) -> None;

"""Inverse of :func:`_relativize_source_files_in`.

    Re-anchor relative ``source_file`` fields against ``root`` so callers
    that load a cached fragment see the same absolute-path shape that a
    fresh in-process extraction would produce. Legacy cache entries with
    absolute ``source_file`` values pass through unchanged.
    """
def _absolutize_source_files_in(payload: dict, `root: Path) -> None;

glob root_default__: any;

with entry {
    root_default__ = Path(".");
}

"""Returns the cache directory for ``kind`` - creates it if needed.

    kind is "ast", "semantic", or a mode-namespaced semantic kind such as
    "semantic-deep" (#1894). Separate subdirectories prevent semantic cache
    entries from overwriting AST cache entries for the same source_file (#582).

    AST entries live in graphify-out/cache/ast/v{version}-s{schema}-g{grammars}/, namespaced
    by graphify version, cache-key schema, and tree-sitter grammar set because they depend on extractor
    code and key semantics, not just file contents. Semantic entries are still
    NOT version-namespaced (re-extraction
    costs LLM calls, #1252): they live in graphify-out/cache/semantic/, with
    deep-mode entries beside them in graphify-out/cache/semantic-deep/.

    ``prompt_fp`` (semantic kinds only) adds a p{fingerprint}/ subdirectory so
    entries are attributed to the extraction prompt that produced them (#1939).
    Omitting it yields the historical flat layout, where entries of unknown
    vintage live.
    """
def cache_dir(
    `root: Path = root_default__, kind: str = "ast", prompt_fp: str | None = None
) -> Path;

"""Derive the on-disk key from a content hash plus optional salt."""
def _salted_key(h: str, salt: str | None) -> str;

glob root_default___: any;

with entry {
    root_default___ = Path(".");
}

"""Return cached extraction for this file if hash matches, else None.

    Cache key: SHA256 of file contents.
    Cache value: stored as graphify-out/cache/{kind}/{hash}.json (AST entries
    under the per-version subdirectory, see :func:`cache_dir`).

    ``root`` anchors the content-hash key and source_file relativization (it
    must stay the inferred common parent so keys remain portable). ``cache_root``
    decouples *where* the cache directory lives from that anchor — the cache is
    an output and must not land inside a read-only/analyzed source tree (#1774).
    When ``cache_root`` is None the location falls back to ``root`` (unchanged
    behavior for existing callers).

    AST entries written by other graphify versions — including the legacy
    flat cache/ layout (pre-0.5.3) and the unversioned cache/ast/ layout —
    are deliberately not consulted: they were produced by a different
    extractor and may be stale.

    ``prompt`` (semantic kinds) is the extraction prompt — text, or a Path to
    the prompt file — that the caller is about to extract with. It selects the
    p{fingerprint}/ namespace, so an entry produced by a different prompt is a
    miss rather than a silent stale hit (#1939). When it is given and the
    fingerprinted namespace misses, ``allow_legacy`` (default True) falls back
    to a flat-layout entry: those predate fingerprinting, so their vintage is
    unknowable — they are served rather than re-billed, and the hit is counted
    so :func:`check_semantic_cache` can report N to the user. Callers that must
    not mix vintages within one entry (see :func:`save_semantic_cache`'s
    ``merge_existing``) pass allow_legacy=False.
    ``salt`` folds extra material into the key for an entry whose validity
    depends on more than the file's bytes — a file the project remaps to
    another language (#2961) parses to a different graph from the same
    content, so it must not hit the entry produced under the old extractor.
    Returns None if no cache entry or file has changed.
    """
def load_cached(
    path: Path,
    `root: Path = root_default___,
    kind: str = "ast",
    cache_root: Path | None = None,
    prompt: "str | Path | None" = None,
    prompt_file: "str | Path | None" = None,
    allow_legacy: bool = True,
    allow_partial: bool = False,
    salt: str | None = None,
) -> dict | None;

with entry {
    _CACHED_TARGETS_KEY = "_cached_target_files";
}

def _target_file_present(target: str, `root: Path) -> bool;

"""The ``target_file`` stamps in ``result`` that name an existing file."""
def _present_target_files(result: dict, `root: Path) -> list[str];

"""Copy-on-write counterpart of :func:`_rewrite_strings`.

    Returns ``obj`` itself when ``fn`` changes no reachable string VALUE, and
    otherwise a NEW dict/list that shares every unchanged child by reference and
    holds fresh containers only on the paths where something changed. Same
    value-only traversal rule as :func:`_rewrite_strings` (dict keys and the id-
    keyed ``objc_field_types["tables"]`` bucket are handled separately), so the
    produced value is byte-identical to deep-copying then rewriting in place —
    without ever mutating ``obj``.
    """
def _rewrite_strings_cow(`obj: object, fn) -> any;

"""Copy-on-write counterpart of :func:`_relativize_source_files_in`.

    Returns ``payload`` unchanged (same object) when no ``source_file`` /
    ``definition_file`` field needs rewriting, else a new payload that shallow-
    copies only the affected buckets and their affected item dicts, sharing the
    rest by reference. Never mutates ``payload``.
    """
def _relativize_source_files_cow(payload: dict, `root: Path) -> dict;

"""Copy-on-write counterpart of :func:`_relativize_ids_in`.

    Returns ``payload`` unchanged when nothing anchors, else a new payload with
    fresh containers only where ids/paths (and the id-keyed
    ``objc_field_types["tables"]`` keys) were anchored. Never mutates ``payload``.
    """
def _relativize_ids_cow(payload: dict, path: "str | Path", `root: Path) -> dict;

"""Build the portable on-disk payload for :func:`save_cached` WITHOUT
    mutating the caller's ``result``.

    Replaces the former ``copy.deepcopy(result)`` + three in-place rewrites with
    a copy-on-write transform: fresh dicts/lists are allocated only for the
    sub-objects whose fields actually change (``source_file``/``definition_file``
    relativization and root-marker id/path anchoring), and everything else is
    shared by reference. The returned object is byte-identical to the old
    deepcopy path's output. ``result`` is left exactly as the caller passed it.
    """
def _save_cached_on_disk(result: dict, p: Path, `root: Path, kind: str) -> dict;

glob root_default____: any;

with entry {
    root_default____ = Path(".");
}

"""Save extraction result for this file.

    ``salt`` must match what the corresponding :func:`load_cached` passes
    (see there); it namespaces the key, not the directory.

    Stores as graphify-out/cache/{kind}/{hash}.json where hash = SHA256 of current file contents.
    result should be a dict with 'nodes' and 'edges' lists.

    ``root`` anchors the content-hash key and source_file relativization;
    ``cache_root`` (when given) is where the cache directory is written, decoupled
    from ``root`` so the cache never lands inside the analyzed source tree (#1774).

    ``prompt`` (semantic kinds) is the extraction prompt that produced ``result``
    — text, or a Path to the prompt file. It stamps the entry into the
    p{fingerprint}/ namespace so a later run under a different prompt does not
    replay it (#1939). Writes always land in the fingerprinted namespace when a
    prompt is given: an entry of known vintage is never written back into the
    flat unknown-vintage layout.

    No-ops if `path` is not a regular file. Subagent-produced semantic fragments
    occasionally carry a directory path in `source_file`; skipping them prevents
    IsADirectoryError from aborting the whole batch.
    """
def save_cached(
    path: Path,
    result: dict,
    `root: Path = root_default____,
    kind: str = "ast",
    cache_root: Path | None = None,
    prompt: "str | Path | None" = None,
    prompt_file: "str | Path | None" = None,
    salt: str | None = None,
) -> None;

glob root_default_____: any;

with entry {
    root_default_____ = Path(".");
}

"""Return set of file hashes that have a valid cache entry (any kind)."""
def cached_files(`root: Path = root_default_____) -> set[str];

glob root_default______: any;

with entry {
    root_default______ = Path(".");
}

"""Delete all cache entries (ast/, semantic/, semantic-deep/, and legacy
    flat entries)."""
def clear_cache(`root: Path = root_default______) -> None;

"""Remove orphaned semantic cache entries, returning the count pruned.

    The semantic cache is content-hash-keyed (``{file_hash}.json`` under
    ``cache/semantic/``) and deliberately UNVERSIONED — entries are produced by
    the LLM from file contents, so invalidating them on every release would
    re-bill extraction. Because it is unversioned it is also never swept by the
    AST version-cleanup, so every content change or file deletion leaves a
    permanent orphan entry that accumulates unbounded.

    This sweeps ``cache/semantic/*.json`` AND ``cache/semantic-deep/*.json``
    (the ``--mode deep`` namespace, #1894) and deletes any entry whose stem
    (the content hash) is not in ``live_hashes`` — the hashes of the current
    live document set. Both namespaces are pruned against the SAME live set:
    liveness is content-based and mode-independent, so a hash that is live for
    one namespace is live for both. Skipping the deep namespace would re-grow
    the unbounded-orphan problem this function fixed (#1527). ``*.tmp``
    atomic-write temporaries are skipped, and only these directories are
    touched (never ``cache/ast/**`` or anything else). The unversioned design
    is preserved: we prune by liveness, not by version.

    The sweep recurses into the per-prompt-fingerprint subdirs (#1939) for the
    same reason it covers the deep namespace: a glob that stopped at the top
    level would leave every fingerprinted entry permanently unprunable. Entries
    under a fingerprint other than the current one are pruned by liveness only,
    never swept wholesale the way :func:`_cleanup_stale_ast_entries` sweeps old
    AST versions — two hosts with different prompts (verbose vs compact
    extraction-spec) can share one graphify-out/, and a wholesale sweep would
    have each run delete the other's entries and re-bill extraction on every
    alternation. Liveness keeps the total bounded by live docs × prompts seen.

    Best-effort, mirroring :func:`_cleanup_stale_ast_entries`: each unlink is
    wrapped in ``try/except OSError`` and a failure is ignored. The worst-case
    failure mode is benign — a surviving orphan costs only one re-extraction of
    one doc on a future run, never incorrect output.
    """
def prune_semantic_cache(`root: Path, live_hashes: set[str]) -> int;

glob root_default_______: any;

with entry {
    root_default_______ = Path(".");
}

"""Check semantic extraction cache for a list of absolute file paths.

    Returns (cached_nodes, cached_edges, cached_hyperedges, uncached_files).
    Uncached files need Claude extraction; cached files are merged directly.

    ``mode`` selects the cache namespace: ``None`` (the default) reads
    ``cache/semantic/`` — byte-identical to the historical behavior, so
    existing callers that omit it (including older installed skill flows)
    are unaffected. A non-None mode (e.g. ``"deep"``) reads
    ``cache/semantic-{mode}/`` instead, so deep-mode results never shadow
    (or get shadowed by) standard-mode entries for the same content (#1894).

    ``prompt`` is the extraction prompt this run will use for the uncached
    files — the prompt text (Python path) or a Path to the prompt file the
    agent loaded (skill path, ``references/extraction-spec.md``). Supplying it
    restricts hits to entries produced by that same prompt, so an upgrade that
    changed the prompt re-extracts instead of replaying the older vintage
    (#1939). Entries written before fingerprinting existed still hit — their
    vintage is unknowable and dropping them would re-bill a whole corpus — but
    a warning reports how many were served. Omitting ``prompt`` keeps the
    historical behavior for existing callers.

    ``cache_root`` decouples *where* the cache is read from the key-anchor
    ``root``, mirroring :func:`load_cached` and :func:`save_semantic_cache`
    (#1774 / #1990). With ``--out``, pass the corpus as ``root`` (so content-hash
    keys and relative-path resolution stay anchored to the source tree) and the
    output directory as ``cache_root``. Omitting it keeps ``root`` for both.
    """
def check_semantic_cache(
    files: list[str],
    `root: Path = root_default_______,
    mode: str | None = None,
    prompt: "str | Path | None" = None,
    prompt_file: "str | Path | None" = None,
    cache_root: "Path | None" = None,
) -> tuple[list[dict], list[dict], list[dict], list[str]];

"""True if any node/edge/hyperedge in a per-file group carries the internal
    ``_partial`` truncation marker set by the adaptive-retry give-up sites.

    The marker rides the item dicts up through every chunk merge, so it reaches
    ``save_semantic_cache`` on BOTH the incremental checkpoint path (llm.py) and
    the final authoritative save (cli.py) without either caller having to thread
    an extra argument — the final save would otherwise overwrite a checkpoint's
    ``partial`` flag with a clean-looking entry.
    """
def _group_has_partial_marker(group: dict) -> bool;

"""Shared path-identity machinery for the semantic-scope guards (#1757/#2926).

    ``save_semantic_cache``'s write allowlist and ``scope_semantic_result``'s
    graph-feed filter must agree on exactly which ``source_file`` values are in
    scope, so both derive their matching from this one implementation rather
    than parallel copies that could drift apart.

    Returns ``(source_identity, normalize_value)`` closed over ``root``:

    - ``normalize_value(src)`` maps a raw ``source_file`` to its portable
      relative forward-slash form (#2197),
    - ``source_identity(value)`` maps any form (relative or absolute, against
      the walked or the resolved root) to the single canonical walked path
      that identities are compared against.
    """
def _semantic_source_matcher(`root: Path) -> tuple[Callable[[str | Path], Path], Callable[[
    str | Path,
], str]];

glob root_default________: any;

with entry {
    root_default________ = Path(".");
}

"""Save semantic extraction results to cache, keyed by source_file.

    Groups nodes and edges by source_file, then saves one cache entry per file
    under cache/semantic/ (separate from AST entries in cache/ast/) to prevent
    hash-key collisions (#582).

    ``mode`` selects the cache namespace, mirroring
    :func:`check_semantic_cache`: ``None`` (the default) writes
    ``cache/semantic/`` — byte-identical to the historical behavior for
    existing callers that omit it — while a non-None mode (e.g. ``"deep"``)
    writes ``cache/semantic-{mode}/`` so richer deep-mode results never
    overwrite standard-mode entries and vice versa (#1894).

    When ``merge_existing`` is True, any already-cached entry for a file is
    unioned with the new results before saving instead of being overwritten.
    This lets callers checkpoint incrementally (e.g. once per chunk) without
    dropping a prior slice of a large file that was split across chunks.

    When ``allowed_source_files`` is provided, only those files may be used as
    cache-write keys. Semantic nodes can legitimately mention another corpus
    file, but a model must not be able to replace that file's complete cache
    entry unless the file was part of the current extraction batch (#1757).

    When ``partial_source_files`` is provided, entries for those files are
    stamped ``partial: True`` — the extraction was truncated, so the entry is
    incomplete and :func:`load_cached` must treat it as a miss. Partial-ness is
    ALSO detected intrinsically from a ``_partial`` marker on any grouped item,
    so the flag survives even when a caller (e.g. cli.py's final save) does not
    pass ``partial_source_files``.

    ``prompt`` is the extraction prompt that produced these results — text, or
    a Path to the prompt file. It stamps entries into the p{fingerprint}/
    namespace so a later run under a different prompt re-extracts rather than
    replaying them (#1939). Pass the same prompt here as to
    :func:`check_semantic_cache`, or the write lands in a namespace the next
    read won't consult.

    ``cache_root`` decouples *where* the cache directory is written from the
    source-key anchor ``root`` — mirroring the same split that :func:`load_cached`
    and :func:`save_cached` already expose (#1774). When given, cache files land
    under ``cache_root`` while ``source_file`` paths are still resolved and
    relativized against ``root``. When omitted, ``root`` is used for both
    purposes (unchanged behaviour for existing callers). This fixes checkpoints
    and the final save going to the corpus tree instead of ``--out`` (#1990,
    #1991).

    Returns the number of files cached.
    """
def save_semantic_cache(
    nodes: list[dict],
    edges: list[dict],
    hyperedges: list[dict] | None = None,
    `root: Path = root_default________,
    merge_existing: bool = False,
    allowed_source_files: Iterable[str | Path] | None = None,
    mode: str | None = None,
    prompt: "str | Path | None" = None,
    prompt_file: "str | Path | None" = None,
    partial_source_files: Iterable[str | Path] | None = None,
    cache_root: "Path | None" = None,
) -> int;

glob root_default_________: any;

with entry {
    root_default_________ = Path(".");
}

"""Stamp the serving semantic cache entry for each file ``partial: True``.

    The semantic cache is deliberately unversioned and content-hash keyed, so a
    degraded extraction — e.g. a document chunk that returned only its
    file-level node — is otherwise replayed as authoritative on every later
    run. The #3203 shrink guard keeps refusing the graph write while the cache
    keeps suppressing the LLM call that could heal it, so the corpus is stuck
    until an operator deletes the entry by hand (#5083).

    The guard compares against graph.json, which :func:`save_semantic_cache`
    deliberately does not read (the cache writer does not know the graph), so
    the CLI marks the entry after the fact instead. ``load_cached`` already
    treats ``partial`` as a miss: the next run re-dispatches the file and a
    complete extraction overwrites the same content-hash key with a clean
    entry, which is the self-healing path the ``_partial`` truncation flag
    already uses.

    Marks the entry the read path would actually serve — the
    prompt-fingerprint namespace when it exists, else the pre-fingerprint flat
    layout ``load_cached`` falls back to — so a legacy entry cannot keep
    shadowing the marked one.

    ``files`` may be absolute, or relative to ``root`` (the shape of the shrink
    guard's canonical ``source_file`` keys). Returns the entry paths actually
    marked. Best-effort: a missing, unreadable or already-partial entry is
    skipped rather than failing the extraction.
    """
def mark_semantic_cache_partial(
    files: Iterable[str | Path],
    `root: Path = root_default_________,
    *,
    mode: str | None = None,
    prompt: "str | Path | None" = None,
    prompt_file: "str | Path | None" = None,
    cache_root: "Path | None" = None,
) -> list[Path];

"""Treat a dispatched file with no coverage entry as unread (skill path, #2225).

    A semantic subagent reports how many lines of each file it read in its chunk's
    ``coverage`` map. A file it never opened can still get nodes guessed from its
    name, and has no entry (or 0), so a check of the reported counts alone passes it
    and the guesses are cached as a complete extraction. This finds every file in
    ``.graphify_uncached.txt`` that is non-empty on disk, is not an image (images
    have no line count) and has no positive count; drops what the chunk files
    attribute to it; and returns those files, verbatim, for the caller to mark
    partial so the next ``--update`` re-dispatches them.

    Items are dropped by ``source_file``, never by id: a file that was read can
    mint the same deterministic id. An edge or hyperedge from a file that was read
    is dropped only when it points at an id that no kept chunk node, AST node or
    cached node still carries. A chunk with no ``coverage`` map at all did not
    follow the contract, so files it holds items for are not judged; with no map
    anywhere, nothing is. Returns ``(unread_files, dropped_item_count)``.
    """
def drop_unreported_chunk_sources(out_dir: Path, `root: Path) -> tuple[list[str], int];

glob root_default__________: any;

with entry {
    root_default__________ = Path(".");
}

"""Scope an extraction result in place to the files actually dispatched (#2926).

    Graph-side mirror of the ``allowed_source_files`` write-guard in
    :func:`save_semantic_cache` (#1757). A model can attribute stray
    nodes/edges to a corpus file that was not part of the current extraction
    batch; :func:`build_merge` derives its replace-set from the source_files
    present in the new chunks, so such a stray fragment would REPLACE that
    file's entire prior contribution in graph.json — while its manifest entry
    still says unchanged, so no later incremental run re-dispatches it and the
    loss is permanent until a full rebuild.

    Nodes and hyperedges whose ``source_file`` resolves outside
    ``allowed_source_files`` are dropped from ``result`` (mutated in place);
    items without a ``source_file`` pass through. An edge whose own
    ``source_file`` is outside the allowlist is kept when both endpoint ids are
    kept nodes (#2276). An edge or hyperedge that survives
    the scope filter but references a dropped node id is dropped too (#1916
    mirror), unless that id is also defined by a kept node (duplicate
    attribution must not be over-pruned).

    Path matching shares :func:`_semantic_source_matcher` with
    :func:`save_semantic_cache` (relative against ``root``, walked-path
    identity). That kept edge can still be skipped by the cache write.

    Returns ``(dropped_source_files, dropped_item_count)`` for logging;
    ``dropped_source_files`` holds the normalized ``source_file`` strings of
    every group that had at least one item removed.
    """
def scope_semantic_result(
    result: dict,
    `root: Path = root_default__________,
    allowed_source_files: "Iterable[str | Path] | None" = None,
) -> tuple[set[str], int];
