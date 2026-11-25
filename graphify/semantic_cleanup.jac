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

def validate_semantic_fragment(fragment: object) -> list[str];
def load_validated_semantic_fragment(path: Path) -> tuple[dict | None, list[str]];

def _validate_semantic_id(errors: list[str], field: str, value: object);
def sanitize_semantic_fragment(fragment: dict) -> dict;
def _is_sentence_like_rationale_label(label: str) -> bool;
def _append_rationale_attr(`node: dict, texts: list[str]);
