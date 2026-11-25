import operator;
import from __future__ { annotations }

import hashlib;

import json;

import re;

import from collections.abc { Sequence }

import from pathlib { Path }

glob _TF_META_HEADS: any;

glob _SENSITIVE_KEY_RE: any;

glob _REDACTED: any;

glob _PAIRED_VALUE_KEYS: any;

with entry {
    _TF_META_HEADS = frozenset({"count", "each", "self", "path", "terraform"});
    _SENSITIVE_KEY_RE = re.compile(
        "(password|passwd|secret|token|api[-_]?key|access[-_]?key|private[-_]?key|credential|client[-_]?secret|connection[-_]?string|sas[-_]?token|auth|passphrase)",
        re.IGNORECASE,
    );
    _REDACTED = REDACTED_MARKER;
    _PAIRED_VALUE_KEYS = frozenset({"value", "valuefrom", "value_from"});
}

def _redact_value(key: str, value: object) -> object;

def _scope_id(directory: str) -> str;
def prepare_terraform(result: dict, path: Path, `root: Path);
def resolve_terraform_modules(per_file: list[dict], nodes: list[dict], edges: list[dict]);
def refresh_terraform_paths(
    changed: list[Path], corpus: list[Path], invalidated: Sequence[Path] = ()
) -> list[Path];
def extract_terraform(path: Path) -> dict;
