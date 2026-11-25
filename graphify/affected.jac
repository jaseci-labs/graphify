import importlib;
import operator;
import from __future__ { annotations }

import json;

import from collections { deque }

import from json { JSONDecodeError }

import from dataclasses { dataclass }

import from pathlib { Path }

import from typing { Iterable }

import unicodedata;

import networkx as nx;

glob DEFAULT_AFFECTED_RELATIONS: any = (
    "calls",
    "indirect_call",
    "references",
    "imports",
    "imports_from",
    "dynamic_import",
    "re_exports",
    "inherits",
    "extends",
    "implements",
    "uses",
    "mixes_in",
    "embeds",
    "defines",
    "requires",
);

glob _SUPERTYPE_RELATIONS: any;

glob _JAVA_PRIMITIVES: any;

with entry {
    _SUPERTYPE_RELATIONS = frozenset({"inherits", "extends", "implements"});
}

@dataclass(frozen=True)
class AffectedHit {
    has node_id: str;

    has depth: int;

    has via_relation: str;

    has via_file: "str | None" = None;

    has via_location: "str | None" = None;
}

def _node_label(`graph: nx.Graph, node_id: str) -> str;

def _format_location(data: dict) -> str;
def _bare_name(label: str) -> str;

def _normalize_label(label: str) -> str;
def _as_repo_relative(query: str, `root: Path | None = None) -> str;
def _prefer_file_node(`graph: nx.Graph, node_ids: list[str], query: str) -> str | None;
def resolve_reference_forms(`graph: nx.Graph, query: str) -> str | None;

def resolve_seed(`graph: nx.Graph, query: str, `root: Path | None = None) -> str | None;
def _supertypes(`graph: nx.DiGraph, type_id: str, cache: dict[str, list[str]]) -> list[str];
def _overridden_members(`graph: nx.DiGraph, `node: str, cache: dict[str, list[str]]) -> list[str];

with entry {
    _JAVA_PRIMITIVES = frozenset({
        "boolean",
        "byte",
        "char",
        "short",
        "int",
        "long",
        "float",
        "double",
    });
}

def _java_params(signature: object) -> list[str] | None;
def _may_be_same_param(mine: str, theirs: str) -> bool;
def _overload_compatible(`graph: nx.DiGraph, `node: str, members: list[str]) -> list[str];

glob relations_default_: any;

with entry {
    relations_default_ = DEFAULT_AFFECTED_RELATIONS;
}

def affected_nodes(
    `graph: nx.Graph, seed: str, *, relations: Iterable[str] = relations_default_, depth: int = 2
) -> list[AffectedHit];
def resolve_seed_outcome(`graph: nx.Graph, query: str, `root: Path | None = None) -> tuple[str
    | None, list[str]];

glob relations_default__: any;

with entry {
    relations_default__ = DEFAULT_AFFECTED_RELATIONS;
}

def format_affected(
    `graph: nx.Graph,
    query: str,
    *,
    relations: Iterable[str] = relations_default__,
    depth: int = 2,
    `root: Path | None = None,
    seed: str | None = None,
) -> str;

def load_graph(path: Path) -> nx.Graph;
