"""Structural extraction for Visual Basic .NET source files."""

import operator;

import from __future__ { annotations }

import re;

import from pathlib { Path }

import from typing { Any }

import from tree_sitter { Node }

glob _TYPE_BLOCKS: any = {
    "class_block": "class",
    "module_block": "module",
    "interface_block": "interface",
    "structure_block": "structure",
    "enum_block": "enum",
};

"""Resolve calls across files that declare the same partial VB type."""
def resolve_vbnet_partial_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;

glob _OPEN_STRING_LINE: any;

with entry {
    _OPEN_STRING_LINE = re.compile(b"(?m)^(?:[^'\"\\r\\n]|\"[^\"\\r\\n]*\")*\"[^\"\\r\\n]*\\r?$");
}

"""Rewrite string literals that span lines so the VB grammar can parse them.

    VB 14 allows a string to cross line breaks, but tree-sitter-vb-dotnet
    0.3.0 only accepts single-line strings (CodeAnt-AI/tree-sitter-vb-dotnet#9).
    The text after the break is then read as code, a ``'`` there starts a
    comment, and an unclosed ``(`` left behind loses the rest of the file.

    Each such literal becomes ``""`` and every line break inside it becomes
    `` _`` plus the break, so the statement stays one logical line and every
    later line keeps its number. Code after the closing quote is kept.
    """
def _flatten_multiline_strings(source: bytes) -> bytes;

def extract_vbnet(path: Path) -> dict;
