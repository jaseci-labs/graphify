import from __future__ { annotations }

import json;

import re;

import from pathlib { Path }

glob _RATIONALE_MIN_CHARS: any = 80;

glob _RATIONALE_MIN_WORDS: any = 8;

glob MAX_SEMANTIC_FRAGMENT_BYTES: any;

glob MAX_SEMANTIC_FRAGMENT_NODES: any;

glob MAX_SEMANTIC_FRAGMENT_EDGES: any;

glob MAX_SEMANTIC_FRAGMENT_HYPEREDGES: any;

glob MAX_SEMANTIC_HYPEREDGE_NODES: any;

glob MAX_SEMANTIC_ID_LENGTH: any;

glob VALID_SEMANTIC_FILE_TYPES: any;

glob _SEMANTIC_ID_RE: any;

with entry {
    MAX_SEMANTIC_FRAGMENT_BYTES = 25 * 1024 * 1024;
    MAX_SEMANTIC_FRAGMENT_NODES = 10000;
    MAX_SEMANTIC_FRAGMENT_EDGES = 100000;
    MAX_SEMANTIC_FRAGMENT_HYPEREDGES = 10000;
    MAX_SEMANTIC_HYPEREDGE_NODES = 256;
    MAX_SEMANTIC_ID_LENGTH = 256;
    VALID_SEMANTIC_FILE_TYPES = frozenset({
        "code",
        "document",
        "paper",
        "image",
        "rationale",
        "concept",
    });
    _SEMANTIC_ID_RE = re.compile("^[\\w.:-]+$");
}

"""Return validation errors for an untrusted semantic extraction fragment.

    Empty list means valid. Called by skill merge code before
    sanitize_semantic_fragment() so malformed or malicious agent JSON is
    rejected before it touches the graph. Parameter is `object` (not `dict`)
    because we may be handed arbitrary deserialized JSON — the first check
    rejects anything that isn't a dict.
    """
def validate_semantic_fragment(fragment: object) -> list[str];

"""Load and validate a semantic chunk, rejecting oversize files before parsing.

    The size guard runs against `path.stat().st_size` so an attacker-supplied
    multi-gigabyte chunk file cannot blow up memory at `read_text()` time.
    JSON decode errors are returned as validation errors rather than raised,
    so callers can `continue` past bad chunks without a try/except.
    """
def load_validated_semantic_fragment(path: Path) -> tuple[dict | None, list[str]];

def _validate_semantic_id(errors: list[str], field: str, value: object) -> None;

"""Clean up a semantic extraction fragment in-place.

    Operations:
    1. Removes nodes with ``file_type: "rationale"`` or ``file_type: "concept"``
       that were emitted by an LLM (these are not valid semantic entity types).
    2. Detects nodes whose label reads like a sentence / rationale paragraph
       AND that participate in a ``rationale_for`` edge, then converts the
       label into a ``rationale`` attribute on the target node and removes
       the source-node + its edges. The ``rationale_for`` edge signal applies
       regardless of the source node's ``file_type`` — sentence-like nodes
       with allowed types (``document``, ``code``) are still cleaned up when
       they're explicitly marked as rationale.
    3. Strips nodes whose only distinguishing field is the label itself
       (empty id — likely LLM hallucination).
    4. Filters hyperedges so they cannot reference removed or unknown node
       IDs after the cleanup passes above. A hyperedge with fewer than two
       surviving members is dropped.

    Returns the same dict for convenience.
    """
def sanitize_semantic_fragment(fragment: dict) -> dict;

"""Return True if *label* looks like prose / rationale text rather than an
    entity or concept name.

    Heuristics (no false positives on short-concept-edge-cases):
    - Longer than *_RATIONALE_MIN_CHARS* chars, OR
    - At least *_RATIONALE_MIN_WORDS* whitespace-delimited tokens, AND
    - Contains at least one sentence-ending punctuation mark (``. ! ?``) or a
      colon (common in "Decision: ..." rationales).
    """
def _is_sentence_like_rationale_label(label: str) -> bool;

"""Append one or more rationale strings to *node*'s ``rationale`` attribute.

    If the attribute already exists the new texts are appended with a
    double-newline separator so downstream consumers can distinguish distinct
    rationale fragments.
    """
def _append_rationale_attr(`node: dict, texts: list[str]) -> None;
