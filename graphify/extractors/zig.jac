"""Zig extractor (tree-sitter). Moved verbatim from graphify/extract.py."""

import operator;

import from __future__ { annotations }

import from pathlib { Path }

import from typing { Any }

"""True for a tagged union (`union(enum)` / `union(SomeTag)`), whose members
    are discriminant cases, not for a bare `union { ... }` whose members are typed
    data fields. A tagged union_declaration carries the tag in parentheses, so it
    has a `(` child; a bare union has none."""
def _is_tagged_union(`node) -> bool;

"""Extract functions, structs, enums, unions, and imports from a .zig file."""
def extract_zig(path: Path) -> dict;
