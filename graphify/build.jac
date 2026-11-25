import importlib;
import operator;
import from __future__ { annotations }

import json;

import math;

import os;

import re;

import sys;

import unicodedata;

import from collections.abc { Iterable }

import from pathlib { Path }

import networkx as nx;

glob _AST_LOC_RE: any;

glob _GENERIC_RELATIONS: frozenset[str];

glob _STRUCTURAL_MEMBER_RELATIONS: frozenset[str];

glob _MEMBER_USAGE_RELATIONS: frozenset[str];

glob _CONFIDENCE_RANK: dict[str, int];

glob _EVIDENCE_KEYS: tuple[str, ...];

glob _EXTERNAL_STUB_RELATIONS: frozenset[str];

glob _EDGE_LANG_FAMILY: dict[str, str];

glob _FILE_TYPE_SYNONYMS: any;

glob _HE_MEMBER_ALIASES: any;

glob _MCP_GLOBAL_ID_KINDS: any;

with entry {
    _AST_LOC_RE = re.compile("^L\\d");
}

def _is_ast_tier(item: dict) -> bool;
def _backfill_origin(item: dict);
def _lost_saved_semantic_nodes(
    saved_nodes: list,
    new_nodes: list,
    deleted_sources: set[str] | None = None,
    folded: dict[str, str] | None = None,
    dedup_remap: dict[str, str] | None = None,
) -> list[dict];
def _dedup_shrink_allowance(saved_ids: set, new_ids: set, dedup_remap: dict[str, str]) -> int;

with entry {
    _GENERIC_RELATIONS = frozenset({"references", "uses", "mentions"});
    _STRUCTURAL_MEMBER_RELATIONS = frozenset({"method", "contains"});
    _MEMBER_USAGE_RELATIONS = frozenset({
        "calls",
        "indirect_call",
        "instantiates",
        "uses_static_prop",
        "references_constant",
    });
    _CONFIDENCE_RANK = {"EXTRACTED": 3, "INFERRED": 2, "AMBIGUOUS": 1};
    _EVIDENCE_KEYS = ("confidence", "confidence_score", "source_file", "source_location");
}

def _evidence(attrs: dict) -> dict;

def _evidence_sort_key(ev: dict) -> tuple;
def edge_evidence(d: dict) -> list[dict];
def _fold_also_seen(winner: dict, loser: dict);

with entry {
    _EXTERNAL_STUB_RELATIONS = frozenset({"imports", "imports_from", "re_exports"});
}

def _mint_external_stub(G: "nx.Graph", node_set: set, nid: str);
def _is_external_stub(item: dict) -> bool;
def mint_external_stubs_in_data(data: dict);
def finalize_raw_graph_endpoints(data: dict);

with entry {
    _EDGE_LANG_FAMILY = {
        ".py": "py",
        ".pyi": "py",
        ".js": "js",
        ".mjs": "js",
        ".cjs": "js",
        ".jsx": "js",
        ".ts": "js",
        ".tsx": "js",
        ".mts": "js",
        ".cts": "js",
        ".go": "go",
        ".rs": "rs",
        ".java": "jvm",
        ".kt": "jvm",
        ".scala": "jvm",
        ".groovy": "jvm",
        ".c": "c",
        ".h": "c",
        ".cc": "c",
        ".cpp": "c",
        ".hpp": "c",
        ".cxx": "c",
        ".hh": "c",
        ".hxx": "c",
        ".cu": "c",
        ".cuh": "c",
        ".metal": "c",
        ".m": "c",
        ".mm": "c",
        ".rb": "rb",
        ".rake": "rb",
        ".php": "php",
        ".cs": "cs",
        ".swift": "swift",
        ".lua": "lua",
        ".vue": "js",
        ".svelte": "js",
        ".astro": "js",
        ".ejs": "js",
        ".kts": "jvm",
        ".gradle": "jvm",
        ".vb": "cs",
        ".razor": "cs",
        ".cshtml": "cs",
        ".xaml": "cs",
        ".phtml": "php",
        ".php3": "php",
        ".php4": "php",
        ".php5": "php",
        ".php7": "php",
        ".phps": "php",
        ".luau": "lua",
        ".cbl": "cobol",
        ".cob": "cobol",
        ".cobol": "cobol",
        ".cpy": "cobol",
        ".r": "r",
        ".sol": "solidity",
        ".erl": "erlang",
        ".hrl": "erlang",
        ".escript": "erlang",
        ".zig": "zig",
        ".ex": "elixir",
        ".exs": "elixir",
        ".jl": "julia",
        ".dart": "dart",
        ".sql": "sql",
        ".sh": "shell",
        ".bash": "shell",
        ".ps1": "powershell",
        ".psm1": "powershell",
        ".psd1": "powershell",
    };
    _FILE_TYPE_SYNONYMS = {
        "markdown": "document",
        "text": "document",
        "tool": "code",
        "library": "code",
        "pattern": "concept",
        "principle": "concept",
        "constraint": "concept",
        "tech": "concept",
        "technology": "concept",
        "data-source": "concept",
        "data_source": "concept",
        "gotcha": "concept",
        "framework": "concept",
    };
    _HE_MEMBER_ALIASES = ("members", "node_ids");
}

def _coerce_hyperedge_member_refs(he: dict, members: list) -> list;
def _normalize_hyperedge_members(he: object);
def _fold_node_aliases(`node: dict);
def _fold_confidence(`obj: dict);
def _fold_edge_aliases(`edge: dict);
def _coerce_id(value: object) -> object;
def _hashable(value: object) -> bool;
def _coerce_non_string_ids(extraction: dict);
def _norm_source_file(p: str | None, `root: str | None = None) -> str | None;
def _abs_identity(p: str | None, `root: str | None = None) -> str | None;
def _prune_identity(p: str | None, `root: str | None = None) -> str | None;
def _is_file_node_label(label: "str | None", source_file: "str | None") -> bool;
def _has_independent_semantic_evidence(`node: dict) -> bool;
def _shortest_unique_suffix(sf: str, all_sfs: "set[str]") -> str;
def _file_label_reassignments(items: "list[tuple]") -> dict;
def _disambiguate_file_node_labels(G: "nx.Graph");
def disambiguate_file_labels_in_nodes(nodes: "list");
def _qualify_csharp_method_labels(G: "nx.Graph");
def qualify_csharp_method_labels_in_nodes(nodes: "list", edges: "list");
def _infer_merge_root(graph_path: Path) -> str | None;
def _build_prune_sets(
    prune_sources: "list[str] | None", eff_root: "str | None", new_sources: "set[str]"
) -> "tuple[dict[str, str], dict[str, str]]";
def _derive_prune_root(prune_sources: "list[str]", stored_sfs: "set[str]") -> "str | None";
def edge_data(G: nx.Graph, u: str, v: str) -> dict;
def edge_datas(G: nx.Graph, u: str, v: str) -> list[dict];
def has_parallel_links(links: "list[dict]", directed: bool = True) -> bool;
def dedupe_nodes(nodes: list[dict]) -> list[dict];
def _execution_wins(a: dict, b: dict);
def dedupe_edges(edges: list[dict]) -> list[dict];
def _old_file_stems(rel: Path) -> list[str];
def _alias_index(nodes: "Iterable[tuple[str, dict]]") -> dict[str, str];
def _is_std_angle_include(`edge: dict) -> bool;
def _alias_lang_compatible(edge_source_file: object, alias_source_file: object) -> bool;
def _semantic_id_remap(nodes: list, `root: str | None) -> dict;

with entry {
    _MCP_GLOBAL_ID_KINDS = frozenset({"mcp_command", "mcp_package", "env_var"});
}

def _has_global_id(`node: dict) -> bool;
def legacy_id_source_prefix(graph_path: str | Path) -> str | None;
def graph_has_legacy_ids(
    nodes: list,
    `root: str | Path | None = None,
    sample: int = 300,
    source_prefix: str | None = None,
) -> bool;
def _doc_twin_remap(nodes: list) -> dict[str, str];
def build_from_json(
    extraction: dict, *, directed: bool = False, `root: str | Path | None = None, dedup: bool = True
) -> nx.Graph;
def build(
    extractions: list[dict],
    *,
    directed: bool = False,
    dedup: bool = True,
    dedup_llm_backend: str | None = None,
    `root: str | Path | None = None,
    protected_ids: "set[str] | None" = None,
) -> nx.Graph;
def take_shrink_accounting(G) -> tuple[int, int];
def take_dedup_remap(G) -> dict[str, str];
def _norm_label(label: str | None) -> str;
def deduplicate_by_label(nodes: list[dict], edges: list[dict]) -> tuple[list[dict], list[dict]];
def _load_existing_graph(graph_path: Path) -> "tuple[list, list, list, bool] | None";
def _tier_replacement_sources(
    chunks: "Iterable[dict]",
    `root: "str | Path | None" = None,
    ast_sources: "Iterable[str | Path] | None" = None,
) -> tuple[set[str], set[str]];
def merge_raw_extraction(
    new: dict,
    graph_path: str | Path,
    prune_sources: "list[str] | None" = None,
    `root: "str | Path | None" = None,
    *,
    ast_sources: "Iterable[str | Path] | None" = None,
) -> dict;
def build_merge(
    new_chunks: list[dict],
    graph_path: str | Path | None = None,
    prune_sources: list[str] | None = None,
    *,
    directed: bool | None = None,
    dedup: bool = True,
    dedup_llm_backend: str | None = None,
    `root: str | Path | None = None,
    ast_sources: "Iterable[str | Path] | None" = None,
) -> nx.Graph;
def prefix_graph_for_global(G: nx.Graph, repo_tag: str, community_offset: int = 0) -> nx.Graph;
def distinct_repo_tags(graph_paths: "list[Path]") -> "list[str]";
def prune_repo_from_graph(G: nx.Graph, repo_tag: str) -> int;
