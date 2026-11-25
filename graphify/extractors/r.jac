import from __future__ { annotations }
import from pathlib { Path }

import from typing { Any }

import from tree_sitter { Node }

glob _CLASS_CONSTRUCTORS: any;

glob _NON_PROJECT_CALLS: any;

with entry {
    _CLASS_CONSTRUCTORS = frozenset({"R6Class", "setRefClass", "ggproto"});
    _NON_PROJECT_CALLS = frozenset({
        "R6Class",
        "c",
        "get",
        "ggproto",
        "library",
        "list",
        "print",
        "require",
        "setClass",
        "setGeneric",
        "setMethod",
        "setRefClass",
        "source",
    });
}

def _unquote(value: str) -> str;
def resolve_r_sourced_calls(per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]);

def extract_r(path: Path) -> dict;
