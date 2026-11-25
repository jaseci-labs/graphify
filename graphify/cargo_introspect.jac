"""Cargo manifest introspection for workspace-internal crate dependencies."""

import from __future__ { annotations }

import importlib;
import os;

import re;

import from pathlib { Path }

import from typing { Any }

glob _CONFIDENCE_EXTRACTED: any = "EXTRACTED";

glob _MAX_DISCOVERY_DEPTH: any = 2;

def _load_toml(path: Path) -> dict[str, Any];

"""A Cargo.toml's `[package] name` as Rust spells it in a path (`-` -> `_`).

    Returns None when the manifest has no package name, cannot be read, or
    cannot be parsed. Callers that scope a Rust import to a crate treat "no
    name" as "no crate", never as an error, so this stays silent.
    """
def package_name(manifest: Path) -> str | None;

"""Find a Cargo.toml under *root* when none sits directly at the root.

    A bounded-depth search rather than an unbounded walk: a Tauri app's
    crate lives in src-tauri/, a polyglot repo's in rust/ or crates/, but
    going arbitrarily deep risks matching a vendored or example manifest
    nested well inside an unrelated dependency (#3678). Reuses the same
    noise-directory pruning the AST scanner already applies (venvs, caches,
    node_modules, build output) so those never get searched into. A
    genuinely ambiguous layout with more than one candidate at the same
    depth is resolved by sorted path order rather than guessed at; the
    caller is free to point --cargo at a subdirectory directly for a repo
    where that is not the right answer.
    """
def _discover_root_manifest(`root: Path) -> Path | None;

def _member_manifest_paths(`root: Path, root_data: dict[str, Any]) -> list[Path];

"""Return crate nodes and internal dependency edges from Cargo manifests."""
def introspect_cargo(`root: str | Path) -> dict[str, Any];
