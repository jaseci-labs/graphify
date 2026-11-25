"""Terraform block extraction and local module-source topology."""

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

"""Redact a sensitive attribute value; recurse into map AND list values so a
    nested `password` inside a `tags`/`connection` map — or inside a list of
    objects — is redacted too.

    HCL routinely nests objects inside tuples (`list(object(...))` variables,
    `dynamic` blocks, tuple defaults), and `_parse_attr_value` turns those into
    Python lists of dicts. Recursing into dicts but not lists left
    `configs = [{ password = "x" }]` leaking verbatim while the map form
    `config = { password = "x" }` was redacted — the value still reaches
    graph.json and the MCP query/get_node surface unsanitized (#3644 follow-up).
    List elements are recursed under the same key: the list branch is only
    reached when `key` is NOT itself sensitive (a sensitive key redacts the whole
    value above), so a scalar element carries no key signal and is returned
    as-is, while a dict element is checked against its own inner keys."""
def _redact_value(key: str, value: object) -> object;

def _scope_id(directory: str) -> str;

"""Make cached directory-scoped IDs portable before the common merge passes.

    Consume the internal scope metadata even when the file is outside root.
    """
def prepare_terraform(result: dict, path: Path, `root: Path) -> None;

"""Connect module calls to scanned .tf directories without reading new files."""
def resolve_terraform_modules(per_file: list[dict], nodes: list[dict], edges: list[dict]) -> None;

"""Reconcile directory ownership and incoming links on incremental scans.

    Callers pass only the permitted, live corpus. Cached syntax is reused for
    unchanged Terraform files; other languages keep their incremental behavior.
    """
def refresh_terraform_paths(
    changed: list[Path], corpus: list[Path], invalidated: Sequence[Path] = ()
) -> list[Path];

"""Extract Terraform/HCL blocks and the references between them via tree-sitter.

    Nodes: resources, data sources, modules, variables, outputs, providers, and
    locals. Edges: `contains` (file -> block), `references` (block -> the blocks
    it interpolates, e.g. `aws_instance.web` -> `var.region`), and `depends_on`
    (explicit dependency edges).

    Node IDs are scoped by the parent directory, not the file stem, because
    Terraform resources are module(directory)-scoped: a resource defined in
    main.tf is referenced from other .tf files in the same directory. Directory
    scoping lets those cross-file references resolve when per-file extractions
    are merged (stem scoping would split a definition from its references).
    """
def extract_terraform(path: Path) -> dict;
