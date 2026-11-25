import builtins;

import importlib;

import operator;
import from __future__ { annotations }

import atexit;

import hashlib;

import json;

import os;

import re;

import tempfile;

import time;

import typing;

import warnings;

import from collections.abc { Callable, Iterable }

import from pathlib { Path }

import from typing { Any }

glob _GRAPHIFY_OUT: any = _PATHS_OUT;

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

glob _os_long_path: any = _wired_os_long_path;

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

def _grammar_fingerprint -> str;

with entry {
    _cleaned_ast_dirs = set[any]();
}

def _cleanup_stale_ast_entries(ast_base: Path, current_dir: Path);

with entry {
    _PROMPT_FP_LEN = 12;
    _legacy_semantic_hits = 0;
    _corrupt_cache_entries = 0;
    _prompt_fp_cache = {};
}

def prompt_fingerprint(prompt: "str | Path") -> str;
def _resolve_prompt_fp(
    prompt: "str | Path | None" = None, prompt_file: "str | Path | None" = None
) -> str | None;

with entry {
    _FRONTMATTER_DELIM = re.compile("^---[ \\t]*\\r?$", re.MULTILINE);
}

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

def _mtime_granularity_ns -> int;
def _stat_sig_fresh(`entry: object, st: "os.stat_result") -> bool;
def _stat_entry_for(abs_key: str, st: "os.stat_result", observed_at_ns: int) -> dict;
def _stat_key_to_relative(key: str, anchor: Path) -> str;
def _stat_key_to_absolute(key: str, anchor: Path) -> str;

def _stat_index_file(`root: Path) -> Path;

def _ensure_stat_index(`root: Path, cache_root: "Path | None" = None);

def _flush_stat_index;
def _normalize_path(path: Path) -> Path;

glob root_default_: any;

with entry {
    root_default_ = Path(".");
}

def file_hash(path: Path, `root: Path = root_default_, cache_root: "Path | None" = None) -> str;
def cached_word_count(path: Path, `root: Path, compute, cache_root: "Path | None" = None) -> int;
def _relativize_source_files_in(payload: dict, `root: Path);
def _relativized_source_value(source: str, root_resolved: Path) -> "str | None";
def _normalize_source_file_value(src: "str | Path", root_resolved: Path) -> str;
def _semantic_entry_matches_path(result: dict, path: Path, `root: Path) -> bool;

with entry {
    _ROOT_MARKER = "$graphify-root$";
}

def _id_anchor(path_str: str, rel_str: str) -> str;
def _portability_anchors(
    path: "str | Path", `root: "str | Path"
) -> tuple[list[str], str, list[str], str];
def _rewrite_id_keyed_table_keys(payload: object, fn);
def _rewrite_strings(`obj: object, fn);
def _relativize_ids_in(payload: dict, path: "str | Path", `root: Path);
def _make_id_anchor_fn(id_anchors: list, path_anchors: list) -> any;
def _absolutize_ids_in(payload: dict, path: "str | Path", `root: Path);
def _absolutize_source_files_in(payload: dict, `root: Path);

glob root_default__: any;

with entry {
    root_default__ = Path(".");
}

def cache_dir(
    `root: Path = root_default__, kind: str = "ast", prompt_fp: str | None = None
) -> Path;
def _salted_key(h: str, salt: str | None) -> str;

glob root_default___: any;

with entry {
    root_default___ = Path(".");
}

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
def _present_target_files(result: dict, `root: Path) -> list[str];
def _rewrite_strings_cow(`obj: object, fn) -> any;
def _relativize_source_files_cow(payload: dict, `root: Path) -> dict;
def _relativize_ids_cow(payload: dict, path: "str | Path", `root: Path) -> dict;
def _save_cached_on_disk(result: dict, p: Path, `root: Path, kind: str) -> dict;

glob root_default____: any;

with entry {
    root_default____ = Path(".");
}

def save_cached(
    path: Path,
    result: dict,
    `root: Path = root_default____,
    kind: str = "ast",
    cache_root: Path | None = None,
    prompt: "str | Path | None" = None,
    prompt_file: "str | Path | None" = None,
    salt: str | None = None,
);

glob root_default_____: any;

with entry {
    root_default_____ = Path(".");
}

def cached_files(`root: Path = root_default_____) -> set[str];

glob root_default______: any;

with entry {
    root_default______ = Path(".");
}

def clear_cache(`root: Path = root_default______);
def prune_semantic_cache(`root: Path, live_hashes: set[str]) -> int;

glob root_default_______: any;

with entry {
    root_default_______ = Path(".");
}

def check_semantic_cache(
    files: list[str],
    `root: Path = root_default_______,
    mode: str | None = None,
    prompt: "str | Path | None" = None,
    prompt_file: "str | Path | None" = None,
    cache_root: "Path | None" = None,
) -> tuple[list[dict], list[dict], list[dict], list[str]];
def _group_has_partial_marker(group: dict) -> bool;
def _semantic_source_matcher(`root: Path) -> tuple[Callable[[str | Path], Path], Callable[[
    str | Path,
], str]];

glob root_default________: any;

with entry {
    root_default________ = Path(".");
}

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

def mark_semantic_cache_partial(
    files: Iterable[str | Path],
    `root: Path = root_default_________,
    *,
    mode: str | None = None,
    prompt: "str | Path | None" = None,
    prompt_file: "str | Path | None" = None,
    cache_root: "Path | None" = None,
) -> list[Path];
def drop_unreported_chunk_sources(out_dir: Path, `root: Path) -> tuple[list[str], int];

glob root_default__________: any;

with entry {
    root_default__________ = Path(".");
}

def scope_semantic_result(
    result: dict,
    `root: Path = root_default__________,
    allowed_source_files: "Iterable[str | Path] | None" = None,
) -> tuple[set[str], int];
