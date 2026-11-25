import from __future__ { annotations }
import ast;

import re;

import unicodedata;

import from dataclasses { dataclass }

import from functools { lru_cache }

import from pathlib { Path }

import from collections.abc { Sequence }

import from typing { Any }

@dataclass(frozen=True)
class ImportedSymbol {
    has local_name: str;

    has imported_name: str;

    has module_stem: str;

    has source_file: str;

    has source_location: str;
}

def normalise_callable_label(label: str) -> str;
def node_is_resolvable_symbol(`node: dict[str, Any]) -> bool;
def build_label_index(
    nodes: list[dict[str, Any]], edges: "list[dict[str, Any]] | None" = None
) -> dict[str, list[str]];
def existing_edge_pairs(edges: list[dict[str, Any]]) -> set[tuple[str, str, str]];
def iter_raw_calls(per_file: Sequence[object]) -> list[dict[str, Any]];
def _module_stem(module_name: str | None) -> str;
def parse_python_import_aliases(path: Path) -> dict[str, ImportedSymbol];
def _node_source_stem(`node: dict[str, Any]) -> str;
def build_python_symbol_index(nodes: list[dict[str, Any]]) -> dict[tuple[str, str], list[str]];
def find_unique_python_symbol(
    symbol_index: dict[tuple[str, str], list[str]], imported: ImportedSymbol
) -> str | None;
def resolve_python_import_guided_calls(
    per_file: Sequence[object],
    paths: Sequence[Path],
    all_nodes: list[dict[str, Any]],
    all_edges: list[dict[str, Any]],
) -> list[dict[str, Any]];
@lru_cache(maxsize=4096)
def _rust_crate_root(source_file: str) -> str | None;
def rust_scoped_call_survivors(
    qualifier: str,
    candidates: Sequence[str],
    nid_to_source_file: dict[str, str],
    caller_file: str = "",
    nid_to_label: "dict[str, str] | None" = None,
) -> list[str];
def resolve_cross_file_raw_calls(
    per_file: Sequence[dict[str, Any] | None],
    all_nodes: list[dict[str, Any]],
    all_edges: list[dict[str, Any]],
) -> list[dict[str, Any]];
def _bash_make_id(*parts_: str) -> str;

def _file_node_id_for_path(path: Path, `root: Path) -> str;
def resolve_bash_source_edges(
    per_file: Sequence[dict | None],
    paths: Sequence[Path],
    `root: Path,
    existing_edges: list[dict] | None = None,
) -> list[dict];
