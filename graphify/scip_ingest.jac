"""scip_ingest.py — SCIP JSON ingestion (simplified subset).

Reads a simplified SCIP-style JSON structure and converts it into
Graphify nodes and edges. NOT a full SCIP protobuf implementation —
this is a skeleton that consumes the simplified shape described below.

Not wired to the CLI in this phase.

Entry point:
  ingest_scip_json(doc: object, source_file: str = "",
      language: str = "python") -> dict[str, Any]

  Returns {"nodes": [...], "edges": [...]} compatible with Graphify's
  extraction result format. All edges emitted are endpoint-safe — the
  function builds a symbol → node_id index in a first pass and either
  resolves relationship targets via that index or creates a stub
  external node so `build_from_json()` will keep the edge.

Supported (simplified) JSON shape:
  documents[]: { relative_path, language, symbols[] }
  symbols[]:   { symbol, kind, display_name, documentation[],
                 relationships[], occurrences[] }
  relationships[]: { symbol, is_reference, is_implementation,
                     is_type_definition, is_definition }
  occurrences[]: { range[], symbol, symbol_roles }

This shape diverges from the official SCIP protobuf (where occurrences
live on the document, not on each symbol). We consume the simplified
shape that LLM-generated SCIP-style JSON commonly produces. Future
cycles may add document-level occurrence support.
"""

import from __future__ { annotations }

import hashlib;

import re;

import from typing { Any }

"""Convert a SCIP-style JSON document into Graphify nodes and edges.

    Parameter ``doc`` is ``object`` (not ``dict[str, Any]``) because SCIP
    documents come from external tools — we may be handed arbitrary
    deserialized JSON. The first check rejects anything that isn't a dict
    and returns the empty result.

    Two-pass design:
      1. Build a ``symbol_str → node_id`` index across every valid symbol
         in every valid document, plus collect per-symbol metadata.
      2. Emit nodes for every indexed symbol and then emit relationship
         edges. Relationship targets are resolved via the index when
         present; otherwise a stub ``scip_external`` node is added so
         edges never dangle.
    """
def ingest_scip_json(
    doc: object, source_file: str = "", language: str = "python"
) -> dict[str, Any];

"""Append the canonical node for a SCIP symbol record."""
def _emit_symbol_node(
    record: dict[str, Any], nodes: list[dict[str, Any]], seen_node_ids: set[str]
) -> None;

"""Append edges (and stub nodes when needed) for a symbol's relationships.

    Relationship target resolution order:
      1. Same-document `(target_symbol, doc_path)` — duplicate local symbol
         names across files route to THIS file's symbol, not another's.
      2. Unique cross-document match — when the symbol exists in exactly
         one document and that document is different from the source.
      3. Stub external node — for symbols not declared in any document
         OR ambiguous duplicates across multiple documents (refusing to
         guess silently).
    """
def _emit_relationships(
    record: dict[str, Any],
    per_doc_index: dict[tuple[str, str], str],
    global_index: dict[str, list[str]],
    nodes: list[dict[str, Any]],
    edges: list[dict[str, Any]],
    seen_node_ids: set[str],
    seen_edges: set[tuple[str, str, str, str | None]],
) -> None;

"""Resolve a SCIP relationship target to an emitted node id, or None.

    Resolution order:
      1. Same-document match — `(target_symbol, source_doc_path)`.
      2. Unique cross-document match — exactly one node id in the global
         index for this symbol AND it isn't the same document we already
         tried.
      3. None — symbol is either absent globally OR ambiguous (defined in
         multiple documents). The caller emits a stub external node.
    """
def _resolve_relationship_target(
    target_symbol: str,
    source_doc_path: str,
    per_doc_index: dict[tuple[str, str], str],
    global_index: dict[str, list[str]],
) -> str | None;

"""Return True only when value is exactly the boolean True.

    Used for SCIP relationship flags. Truthy strings like ``"false"`` are
    common in untrusted external JSON and must NOT count as a set flag.
    """
def _is_true(value: object) -> bool;

"""Pick the Graphify relation tag for a SCIP relationship dict.

    Flags are accepted only when the value is exactly ``True`` — protects
    against truthy-but-misleading values like ``"false"`` in external JSON.
    """
def _scip_relation_for(rel: dict[str, Any]) -> str;

"""Read the 1-based line number from the first occurrence range, defensively.

    Note: ``bool`` is a subclass of ``int`` in Python — ``isinstance(True, int)``
    is True. We explicitly exclude booleans so a malformed ``range: [True, …]``
    cannot produce ``source_location = "LTrue"``.
    """
def _first_occurrence_line(occurrences: object) -> int;

"""Return ``value`` if it is a string, else the ``default`` (also a string)."""
def _coerce_str(value: object, `default: str) -> str;

"""Derive a stable Graphify node ID from a SCIP symbol identifier.

    Uses SHA-1 truncated to 12 hex chars (48 bits). This is an identifier,
    not a security boundary — collision risk is acceptable at this scale
    given the per-document scoping prefix.
    """
def _make_scip_node_id(symbol: str, source_file: str) -> str;

"""Map SCIP symbol kind to a Graphify file_type."""
def _scip_kind_to_file_type(kind: str) -> str;

"""Build metadata for a SCIP node."""
def _build_scip_metadata(symbol_id: str, kind: str, description: str) -> dict[str, str];
