import operator;
import from __future__ { annotations }

import os;

import re;

import from pathlib { Path }

import from typing { Any }

glob MARKDOWN_MENTION_SUFFIXES: any;

glob _CONTAINMENT_RELATIONS: any;

glob _RELATIVE_PREFIX_RE: any;

glob _CAMEL_CASE_RE: any;

glob _PASCAL_EXPORT_SUFFIXES: any;

with entry {
    MARKDOWN_MENTION_SUFFIXES = frozenset({".md", ".mdx", ".qmd", ".skill"});

    _CONTAINMENT_RELATIONS = frozenset({"contains", "method"});
    _RELATIVE_PREFIX_RE = re.compile("^(\\.\\.?/)+");
}

def _symbol_label(`node: dict[str, Any]) -> str;

with entry {
    _CAMEL_CASE_RE = re.compile("[a-z][A-Z]");
    _PASCAL_EXPORT_SUFFIXES = frozenset({
        ".go",
        ".cs",
        ".vb",
        ".swift",
        ".scala",
        ".pas",
        ".dpr",
        ".lpr",
        ".ps1",
        ".psm1",
    });
}

def _is_prose_like_label(label: str) -> bool;
def _is_pascal_case_export_language(source_file: str) -> bool;

def _is_file_node(`node: dict[str, Any]) -> bool;

def _posix(path: str) -> str;
def _match_cited_file(cited: str, doc_file: str, source_files: set[str]) -> str | None;
def _cited_file_suffix(cited_posix: str, source_files: set[str]) -> str | None;
def _match_cited_file_any_form(
    cited: str,
    doc_file: str,
    source_files: set[str],
    *,
    form_mismatch: bool,
    scan_root: "Path | str | None" = None,
) -> str | None;
def _match_file_link(
    cited: str,
    doc_file: str,
    source_files: set[str],
    *,
    form_mismatch: bool,
    scan_root: "Path | str | None" = None,
) -> str | None;
def _evidence(
    node_id: str, nodes_by_id: dict[str, dict[str, Any]], parents: dict[str, set[str]]
) -> set[str];

def _markdown_raw_calls(per_file: list[dict]) -> list[dict];
def resolve_markdown_mentions(
    per_file: list[dict],
    all_nodes: list[dict],
    all_edges: list[dict],
    *,
    scan_root: "Path | str | None" = None,
);
