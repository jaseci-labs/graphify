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
def scan_producer_suppression_sites(path: str | Path) -> dict[str, Any];
def diagnose_extraction(
    extraction: dict[str, Any],
    *,
    directed: bool = True,
    `root: str | Path | None = None,
    max_examples: int = 5,
    extract_path: str | Path | None = None,
) -> dict[str, Any];
def _read_json_file(path: str | Path) -> dict[str, Any];
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
