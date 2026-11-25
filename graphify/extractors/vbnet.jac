import operator;
import from __future__ { annotations }

import re;

import from pathlib { Path }

import from typing { Any }

import from tree_sitter { Node }

glob _TYPE_BLOCKS: any = {
    "class_block": "class",
    "module_block": "module",
    "interface_block": "interface",
    "structure_block": "structure",
    "enum_block": "enum",
};
def resolve_vbnet_partial_calls(per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]);

glob _OPEN_STRING_LINE: any;

with entry {
    _OPEN_STRING_LINE = re.compile(b"(?m)^(?:[^'\"\\r\\n]|\"[^\"\\r\\n]*\")*\"[^\"\\r\\n]*\\r?$");
}

def _flatten_multiline_strings(source: bytes) -> bytes;

def extract_vbnet(path: Path) -> dict;
