"""Single source of truth for the graphify output-directory name.

The output directory is ``graphify-out`` by default and overridable with the
``GRAPHIFY_OUT`` env var (worktrees or shared-output setups, #686). It accepts a
relative name (``"graphify-out-feature"``) or an absolute path
(``"/shared/graphify-out"``).

This used to be duplicated as an identical ``_GRAPHIFY_OUT`` constant in
``__main__``, ``cache``, and ``watch``, while ``security`` and ``callflow_html``
hardcoded the literal ``"graphify-out"`` and silently ignored the override
(#1423). Centralising it here keeps the name in one place. The value is read
once at import time, matching the previous per-module constants — set
``GRAPHIFY_OUT`` before the process starts (the normal worktree/shared-output
flow) and every reader honours it.
"""

import importlib;

import operator;


import from __future__ { annotations }

import errno;

import functools;

import json;

import os;

import re;

import stat;

import sys;

import tempfile;

import from pathlib { Path, PurePosixPath, PureWindowsPath }

"""``GRAPHIFY_OUT``, or ``"graphify-out"`` when it is unset, empty, or names
    the project itself / a parent of it.

    ``os.environ.get(key, default)`` only applies the default when the variable
    is missing, so ``GRAPHIFY_OUT=`` (a blank ``.env`` entry) used to yield
    ``""``: output landed in the project root and ``uninstall --purge`` deleted
    the whole project. ``.`` and ``..`` are never a valid output dir either.
    """
def _out_from_env -> str;

glob GRAPHIFY_OUT: any;

glob _PREREAD_RAW: "_ContextVar[tuple[str, bytes] | None]";

glob _TEST_DIR_SEGMENTS: any;

glob _TEST_FILENAME_PATTERNS: any;

glob GRAPHIFY_OUT_NAME: any;

glob _WINDOWS_MAX_PATH: any;

glob _MIN_STEM_BUDGET: any;

with entry {
    GRAPHIFY_OUT = _out_from_env();

    _PREREAD_RAW = _ContextVar("_PREREAD_RAW", default=None);
}

import from contextvars { ContextVar as _ContextVar }

"""Record ``raw`` as the just-read raw bytes of ``path`` for this context."""
def stash_preread_bytes(path: "str | Path", raw: bytes) -> None;

"""Return raw bytes stashed for ``path`` in this context, else ``None``."""
def take_preread_bytes(path: "str | Path") -> "bytes | None";

"""Return an OS path string safe for open()/stat() on Windows long paths.

    On win32, paths longer than the legacy MAX_PATH (260 chars) are rejected by
    the plain file APIs unless prefixed with the extended-length marker ``\\\\?\\``
    (which also requires a fully-qualified path). Without it, _md5_file /
    save_manifest / count_words silently fail to hash deeply-nested files, so
    their manifest entry never stabilizes and detect_incremental re-flags them
    as changed on every run (#1655), and cache entries under a deep root cannot
    be written at all. cache._normalize_path strips this prefix for stable
    KEYS; this adds it for I/O. Non-win32 and already-prefixed paths pass
    through unchanged.
    """
def os_long_path(path: "str | Path") -> str;

"""``os.replace(src, dst)``, falling back to a copy for a known set of
    Windows quirks (#3508) that raise even when ``src``/``dst`` are the same
    directory on the same drive: ``PermissionError`` (WinError 5/32 --
    destination briefly locked by another handle, antivirus, an open reader)
    and WinError 17 ("cannot move to a different disk drive", observed on some
    Windows/filesystem combinations despite textbook same-volume semantics).
    WinError 17 maps to a plain ``OSError`` in Python, not ``PermissionError``,
    so it's checked via ``winerror`` rather than the exception type. Any other
    failure is a real one and is re-raised.

    ``os.replace`` atomically swaps whatever sits at ``dst`` -- including a
    symlink, which it REPLACES in place rather than following (some callers,
    e.g. install.py's managed skill symlinks, #3286, rely on exactly this).
    A naive ``shutil.copy2(src, dst)`` does the opposite when ``dst`` is a
    symlink: opening it for writing follows the link and overwrites its
    TARGET's content instead. So the fallback copies to a fresh temp file in
    ``dst``'s directory first, renames whatever is currently at ``dst`` (link
    or file) aside as a backup rather than deleting it outright, and only
    then renames the temp copy into ``dst``'s place -- matching replace's
    "whatever was there is gone, a plain file replaces it" semantics. If that
    final rename fails, the backup is renamed straight back so a mid-swap
    failure leaves the original in place rather than leaving ``dst`` missing.
    """
def os_replace_with_fallback(src: "str | Path", dst: "str | Path") -> None;

"""Atomically replace ``path`` with content written by ``write_fn(f)``.

    Writes a temp file in the SAME directory, then ``os.replace``s it into place
    (an atomic rename on one filesystem). A process kill (SIGKILL/Ctrl-C), OOM, or
    ENOSPC mid-write leaves the previous file intact — the destination is
    untouched until the rename. This is NOT a power-loss durability guarantee:
    there is no fsync (matching the rest of the codebase), so an OS/hardware crash
    right after the rename can still expose unflushed bytes on some filesystems.
    The temp file is removed if the write fails.

    A symlinked destination is resolved first so the write goes THROUGH the link
    to its target (rather than replacing the link with a regular file), keeping
    the shared-output/worktree symlink setups this module documents working.
    """
def _atomic_replace(path: "str | Path", write_fn) -> None;

"""Atomically write ``text`` (UTF-8) to ``path``. See :func:`_atomic_replace`."""
def write_text_atomic(path: "str | Path", text: str) -> None;

"""Atomically write ``text`` only if it differs from what is already on disk;
    return ``True`` if a write happened, ``False`` if the file was left untouched.

    Exporters regenerate their whole page set on every ``graph.json`` change and
    used to rewrite every file unconditionally — tens of thousands of identical
    pages per run, which also fires inotify / re-index / sync on unchanged
    content (#3060). Skipping the atomic replace when nothing changed avoids the
    rename entirely, so mtime and inode are preserved.

    The comparison is on DECODED text, never bytes: :func:`write_text_atomic`
    writes in text mode and (on Windows) translates ``\\n`` to ``\\r\\n`` while
    :func:`Path.read_text` translates it back, so a byte compare would report
    every file as changed. A missing or non-UTF-8 destination counts as changed."""
def write_text_atomic_if_changed(path: "str | Path", text: str) -> bool;

"""Atomically write ``obj`` as JSON to ``path``, streaming the encode into the
    temp file rather than materializing the whole string first (matters for very
    large graphs). ``ensure_ascii`` mirrors ``json.dump`` so callers that emit raw
    UTF-8 (non-ASCII labels/paths) keep byte-for-byte output. ``compact`` writes one
    line with no padding after ``,``/``:`` (graph.json, #3413). See :func:`_atomic_replace`."""
def write_json_atomic(
    path: "str | Path",
    `obj,
    *,
    indent: "int | None" = None,
    ensure_ascii: bool = True,
    compact: bool = False,
) -> None;

with entry {
    _TEST_DIR_SEGMENTS = frozenset({"tests", "test", "spec", "specs", "__tests__"});
    _TEST_FILENAME_PATTERNS = (
        re.compile("^test_.*", re.IGNORECASE),
        re.compile(".*_test\\..+$", re.IGNORECASE),
        re.compile(".*\\.test\\..+$", re.IGNORECASE),
        re.compile(".*\\.spec\\..+$", re.IGNORECASE),
        re.compile(".*_spec\\..+$", re.IGNORECASE),
        re.compile(".*\\.tests\\.ps1$", re.IGNORECASE),
        re.compile(".*Test\\.java$"),
        re.compile(".*Tests\\.java$"),
        re.compile(".*Tests\\.cs$"),
    );
}

"""Classify a source path as a test path (case-insensitive, segment-aware).

    Shared by extract.py and symbol_resolution.py so cross-file call resolution
    treats test mocks/stubs identically. A path is a test path when:
      * any whole path segment equals a known test dir name
        (``tests``/``test``/``spec``/``specs``/``__tests__``), or
      * the filename matches a known test-file naming convention.

    Conservative on purpose: matches segments/filenames, never raw substrings,
    so ``latest.py``, ``src/contest.py`` and ``src/greatest/x.py`` are NON-test.
    """
def _is_test_path(path: str) -> bool;

"""Segments of ``source_file``'s parent directory, POSIX-normalized.

    `_path_proximity_winner` compares every candidate's directory against the
    call site's, and an ambiguous name (``run``, ``get``) brings the same
    candidate files back on every call site, so the parse is memoized. Equal
    tuples here mean equal ``PurePosixPath(...).parent`` values.
    """
@functools.lru_cache(maxsize=65536)
def _parent_parts(source_file: str) -> tuple[str, ...];

"""Pick the candidate whose source file is closest to the call site.

    ``candidate_files`` maps candidate id -> its source_file. Returns a single
    winning candidate id, or ``None`` when no proximity tier yields a unique
    winner. Tiers, in order:

      1. same file as the call site,
      2. same directory,
      3. longest common path-prefix (must be a strict, unique maximum).

    Used only as a secondary tie-break after the test/non-test filter, so the
    god-node guard still holds when proximity is genuinely ambiguous.
    """
def _path_proximity_winner(call_site_file: str, candidate_files: dict[str, str]) -> str | None;

"""Resolve an ambiguous bare-name call to one candidate, or ``None``.

    Shared god-node tie-breaker (#1553) used by both the inline cross-file call
    pass in ``extract.py`` and ``symbol_resolution.resolve_cross_file_raw_calls``
    so the heuristics stay aligned across languages. ``candidates`` is the list
    of node ids sharing the callee's name; ``candidate_files`` maps each id ->
    its source_file. Returns the surviving candidate id only when exactly one
    survives; otherwise ``None`` (caller keeps the god-node guard / ``continue``).

    Tie-breakers, in order:
      1. NON-TEST preference. Classify the call site and each candidate as
         test/non-test. When the call site is NON-test, drop test candidates.
         When the call site IS a test file, prefer test-local candidates
         (same file first, then any test candidate); fall back to the full set
         only if no test candidate exists.
      2. PATH PROXIMITY over whatever survived step 1.
    """
def disambiguate_ambiguous_candidates(
    candidates: list[str], candidate_files: dict[str, str], call_site_file: str
) -> str | None;

with entry {
    GRAPHIFY_OUT_NAME = os.path.basename(os.path.normpath(GRAPHIFY_OUT));
}

"""A path inside the configured output dir, e.g. ``out_path("cache")``.

    ``Path(GRAPHIFY_OUT) / ...`` resolves correctly for both a relative name
    ("graphify-out") and an absolute override ("/shared/graphify-out").
    """
def out_path(*parts_: str) -> Path;

"""Resolve the selected graph's project without interpreting paths via CWD."""
def graph_root_for(gp: Path) -> Path;

"""Default ``graph.json`` path under the configured output dir.

    The package-wide fallback used by serve/build/benchmark/prs and the CLI read
    commands so a ``GRAPHIFY_OUT`` override is honoured everywhere, not just where
    the path is passed explicitly (#1423).
    """
def default_graph_json -> str;

"""Whether *p* is absolute under POSIX **or** Windows rules.

    ``Path.is_absolute()`` and ``os.path.isabs()`` answer for the HOST os only,
    which is the wrong question for a path that was *stored* — a ``source_file``
    in ``graph.json``, a ``prune_sources`` entry, a cache key. Those travel
    between machines (build in Docker/CI, update on a Windows workstation, or
    the reverse), so the host's rules do not describe the string in hand:

    - On Windows, ``WindowsPath("/home/ci/repo/docs/a.md").is_absolute()`` is
      False — no drive letter — so a Linux-built graph's absolute paths read as
      relative and get baked into node IDs or joined under the scan root (#2618).
    - On POSIX, ``PosixPath("C:/Users/u/a.md").is_absolute()`` is False for the
      mirror-image reason (#2197, #1789).

    ``os.path.isabs`` is additionally not stable across supported interpreters:
    Python 3.13 changed ``ntpath.isabs`` so a path starting with a single slash
    is no longer absolute, where 3.10–3.12 said it was. The project supports
    >=3.10, so a guard written on it silently means different things per version.

    Answering for both platforms is the conservative choice for stored paths:
    treating a path as absolute at worst declines to relativize it (the string is
    kept as-is), whereas treating an absolute path as relative corrupts identity.
    Covers drive-letter, UNC, and POSIX-root forms with either separator.

    NOTE: this is for STORED/portable paths. Code resolving a path against the
    real local filesystem (``cli``, ``detect``, ``hooks``) must keep using
    ``Path.is_absolute()`` — there the host's rules are exactly right.
    """
def is_absolute_any_platform(p: "str | Path | None") -> bool;

with entry {
    _WINDOWS_MAX_PATH = 260;
    _MIN_STEM_BUDGET = 16;
}

"""``PC_NAME_MAX`` (bytes per path component) of the filesystem holding
    ``directory``, or ``None`` when it cannot be determined.

    The export directory may not exist yet, so ask its nearest existing
    ancestor, which is on the same filesystem unless something is mounted in
    between.
    """
def _component_name_max(directory: "str | Path") -> int | None;

"""Largest filename stem an exporter may write directly into ``output_dir``.

    Exporters cap note/article filenames so they stay under the filesystem's
    per-component limit (conventionally NAME_MAX=255 bytes, hence the 200
    default). That is the right question on POSIX and the wrong one on Windows,
    where the constraint is on the WHOLE path, not the component: a 200-char
    stem under a perfectly ordinary vault directory such as
    ``C:\\Users\\me\\projects\\svc\\graphify-out\\obsidian`` exceeds MAX_PATH and
    the write dies with ``FileNotFoundError``, aborting the export mid-vault.

    On POSIX it returns the smaller of ``limit`` and the target filesystem's
    real ``PC_NAME_MAX`` less ``reserve`` and the ``.md`` extension. Under the
    conventional 255 that is still ``limit``, so existing output is
    byte-for-byte stable; it only shrinks where the filesystem reports less,
    e.g. eCryptfs, whose filename encryption leaves ~143 bytes (#2109). On
    Windows it returns the smaller of ``limit`` and whatever still fits inside
    MAX_PATH once ``output_dir``, the separator, ``reserve`` (room for
    caller-added prefixes/collision suffixes) and the ``.md`` extension are
    accounted for.

    The Windows budget is a CHARACTER count, but callers that cap UTF-8 BYTES
    may pass it straight through: a string's UTF-8 length is never below its
    character length, so a byte-capped stem always satisfies the character
    ceiling too. The POSIX NAME_MAX budget is in BYTES, which a byte-capping
    caller meets exactly.
    """
def stem_filename_budget(output_dir: "str | Path", *, reserve: int = 0, limit: int = 200) -> int;

"""NFC-normalize a path string.

    macOS (HFS+/APFS) reports filenames in NFD while manifests, graph
    ``source_file`` entries and user input are typically NFC. Comparing raw
    strings makes the same file look like two different paths, so any path
    membership test must normalize BOTH sides (#2210, #2221/#2224).
    """
def nfc(s: str) -> str;

"""A graph file's data with one copy of each string its rows repeat."""
def read_graph_json(path) -> dict;

"""Each row in order, let go as it is taken, so a graph built from them never holds both."""
def consumed(rows: list) -> Generator[any, any, any];

"""``data`` for networkx to build a graph from once, stamped as ``restore_arc_direction`` stamps it."""
def consumed_graph_rows(data: dict) -> dict;

"""Stamp each link's stored direction as ``_src``/``_tgt`` before loading.

    graph.json is written ``directed: false`` but carries true direction in arc
    order (#563), or in ``_src``/``_tgt`` markers on legacy canonicalized files.
    An undirected ``node_link_graph`` load re-orders endpoints by node-list
    position, so readers recover direction from these markers. Existing markers
    win (#2309). Same idiom as the query and merge-graphs loaders (#2261).
    """
def restore_arc_direction(data: dict) -> dict;

"""Load a graphify graph.json into a networkx graph, accepting both writers.

    The clustered writer stores edges under ``links`` (networkx's node-link
    default); the raw ``--no-cluster`` writer stores them under ``edges``.
    Consumers that call ``node_link_graph(data, edges="links")`` directly
    raise ``KeyError: 'links'`` on a raw graph (#2212) — the ``except
    TypeError`` fallback only covers old networkx without the ``edges``
    kwarg, not the missing key. Normalize before parsing, same idiom as
    affected.py/serve.py.

    Accepts a path (size-cap-checked via the security module, then parsed)
    or an already-parsed dict (no size check — the caller owns any cap).
    """
def load_node_link_graph(path_or_data) -> any;
