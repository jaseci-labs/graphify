"""Read-only diagnostics for MultiDiGraph readiness."""

import from __future__ { annotations }

import importlib;
import json;

import re;

import from collections { Counter, defaultdict }

import from copy { deepcopy }

import from pathlib { Path }

import from typing { Any }

import networkx as nx;

glob _SUPPRESSION_DECL_RE: any;

glob _TYPE_TUPLE_RE: any;

with entry {
    _SUPPRESSION_DECL_RE = re.compile("^\\s*(?P<name>seen_[A-Za-z0-9_]+)\\s*[:=]");
    _TYPE_TUPLE_RE = re.compile("set\\[tuple\\[(?P<inside>[^\\]]+)\\]\\]");
}

def _safe_text(value: Any) -> str;

def _edge_list(extraction: dict[str, Any]) -> list[Any];

def _node_ids(extraction: dict[str, Any]) -> set[str];

def _canonical_edge(`edge: Any) -> dict[str, str];

def _exact_signature(`edge: Any) -> str;

def _count_extra(counter: Counter[Any]) -> int;

def _variant_group_count(
    grouped_edges: dict[tuple[str, str], list[dict[str, str]]],
    field: str,
    *,
    relation_sensitive: bool = False,
) -> int;

def _tuple_arity_from_annotation(line: str) -> int;

"""Find likely `seen_*` producer-suppression sets in an extractor file."""
def scan_producer_suppression_sites(path: str | Path) -> dict[str, Any];

"""Summarize graph-integrity risks for one JSON graph/extraction dict.

    Missing ``ref_*`` targets are expected external references produced for
    dependencies outside the scanned corpus. They are counted separately from
    actionable internal dangling endpoints.

    Non-list node containers contribute no node counts. The original input is
    still passed to the protected build attempt so its error remains visible.
    """
def diagnose_extraction(
    extraction: dict[str, Any],
    *,
    directed: bool = True,
    `root: str | Path | None = None,
    max_examples: int = 5,
    extract_path: str | Path | None = None,
) -> dict[str, Any];

"""Read a JSON graph after applying Graphify's graph-load size cap."""
def _read_json_file(path: str | Path) -> dict[str, Any];

"""Diagnose a graph/extraction JSON file without mutating it.

    When `directed` is None, the JSON's "directed" flag is honored. Raw
    extraction JSON that has no "directed" flag defaults to directed analysis.
    """
def diagnose_file(
    path: str | Path,
    *,
    directed: bool | None = None,
    `root: str | Path | None = None,
    max_examples: int = 5,
    extract_path: str | Path | None = None,
) -> dict[str, Any];

def format_diagnostic_json(summary: dict[str, Any]) -> dict[str, Any];

def format_diagnostic_report(summary: dict[str, Any]) -> str;
