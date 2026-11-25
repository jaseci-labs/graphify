import from __future__ { annotations }
import hashlib;

import re;

import from typing { Any }
def ingest_scip_json(
    doc: object, source_file: str = "", language: str = "python"
) -> dict[str, Any];
def _emit_symbol_node(record: dict[str, Any], nodes: list[dict[str, Any]], seen_node_ids: set[str]);
def _emit_relationships(
    record: dict[str, Any],
    per_doc_index: dict[tuple[str, str], str],
    global_index: dict[str, list[str]],
    nodes: list[dict[str, Any]],
    edges: list[dict[str, Any]],
    seen_node_ids: set[str],
    seen_edges: set[tuple[str, str, str, str | None]],
);
def _resolve_relationship_target(
    target_symbol: str,
    source_doc_path: str,
    per_doc_index: dict[tuple[str, str], str],
    global_index: dict[str, list[str]],
) -> str | None;
def _is_true(value: object) -> bool;
def _scip_relation_for(rel: dict[str, Any]) -> str;
def _first_occurrence_line(occurrences: object) -> int;
def _coerce_str(value: object, `default: str) -> str;
def _make_scip_node_id(symbol: str, source_file: str) -> str;
def _scip_kind_to_file_type(kind: str) -> str;
def _build_scip_metadata(symbol_id: str, kind: str, description: str) -> dict[str, str];
