import importlib;

import operator;
import from __future__ { annotations }

import builtins;

import errno;

import functools;

import json;

import os;

import re;

import stat;

import sys;

import tempfile;

import typing;

import from pathlib { Path, PurePosixPath, PureWindowsPath }
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
def stash_preread_bytes(path: "str | Path", raw: bytes);
def take_preread_bytes(path: "str | Path") -> "bytes | None";
def os_long_path(path: "str | Path") -> str;
def os_replace_with_fallback(src: "str | Path", dst: "str | Path");
def _atomic_replace(path: "str | Path", write_fn);
def write_text_atomic(path: "str | Path", text: str);
def write_text_atomic_if_changed(path: "str | Path", text: str) -> bool;
def write_json_atomic(
    path: "str | Path",
    `obj,
    *,
    indent: "int | None" = None,
    ensure_ascii: bool = True,
    compact: bool = False,
);

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

def _is_test_path(path: str) -> bool;
@functools.lru_cache(maxsize=65536)
def _parent_parts(source_file: str) -> tuple[str, ...];
def _path_proximity_winner(call_site_file: str, candidate_files: dict[str, str]) -> str | None;
def disambiguate_ambiguous_candidates(
    candidates: list[str], candidate_files: dict[str, str], call_site_file: str
) -> str | None;

with entry {
    GRAPHIFY_OUT_NAME = os.path.basename(os.path.normpath(GRAPHIFY_OUT));
}

def out_path(*parts_: str) -> Path;
def graph_root_for(gp: Path) -> Path;
def default_graph_json -> str;
def is_absolute_any_platform(p: "str | Path | None") -> bool;

with entry {
    _WINDOWS_MAX_PATH = 260;
    _MIN_STEM_BUDGET = 16;
}

def _component_name_max(directory: "str | Path") -> int | None;
def stem_filename_budget(output_dir: "str | Path", *, reserve: int = 0, limit: int = 200) -> int;
def nfc(s: str) -> str;
def read_graph_json(path) -> dict;
def consumed(rows: list) -> Generator[any, any, any];
def consumed_graph_rows(data: dict) -> dict;
def restore_arc_direction(data: dict) -> dict;
def load_node_link_graph(path_or_data) -> any;
