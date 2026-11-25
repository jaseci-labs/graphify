import importlib;
import operator;
import from __future__ { annotations }

import os;

import re;

import from pathlib { Path }

import from typing { Any }

glob _BASH_LEADING_EXPANSION: any;

glob _BASH_SOURCE_DIRNAME: any;

glob _BASH_LEADING_VAR: any;

glob _BASH_DIRNAME_IDIOM: any;

with entry {
    _BASH_LEADING_EXPANSION = re.compile("^(?:(?:\\$\\{[^}]*\\}|\\$[A-Za-z_][A-Za-z0-9_]*)/?)+");
}

def _bash_source_suffix(raw: str, allow_dotdot: bool = False) -> str | None;
def _within_tree(ceiling: Path, target: Path) -> bool;
def _safe_to_probe(target: Path, scan_root: Path | None) -> bool;
def _resolve_safe(candidate: Path, scan_root: Path | None) -> "Path | None";

with entry {
    _BASH_SOURCE_DIRNAME = re.compile(
        "\\$\\(dirname\\s+\"\\$\\{?([A-Za-z_][A-Za-z0-9_]*)\\}?\"\\)"
    );
    _BASH_LEADING_VAR = re.compile(
        "^\\$\\{([A-Za-z_][A-Za-z0-9_]*)[^}]*\\}|^\\$([A-Za-z_][A-Za-z0-9_]*)"
    );
    _BASH_DIRNAME_IDIOM = re.compile("dirname[^)]*\\)((?:/\\.\\.)*)");
}

def _bash_assignment_base(value: str, script_dir: Path) -> Path | None;
def extract_bash(path: Path) -> dict;
