import operator;
import from __future__ { annotations }

import hashlib;

import from pathlib { Path }

glob _GO_PREDECLARED_TYPES: any;

glob _GO_PREDECLARED_FUNCS: any;

glob _GO_TYPE_NODES: any;

with entry {
    _GO_PREDECLARED_TYPES = frozenset({
        "bool",
        "byte",
        "complex64",
        "complex128",
        "error",
        "float32",
        "float64",
        "int",
        "int8",
        "int16",
        "int32",
        "int64",
        "rune",
        "string",
        "uint",
        "uint8",
        "uint16",
        "uint32",
        "uint64",
        "uintptr",
        "any",
        "comparable",
    });
    _GO_PREDECLARED_FUNCS = frozenset({
        "append",
        "cap",
        "clear",
        "close",
        "complex",
        "copy",
        "delete",
        "imag",
        "len",
        "make",
        "max",
        "min",
        "new",
        "panic",
        "print",
        "println",
        "real",
        "recover",
    });
    _GO_TYPE_NODES = frozenset({
        "type_identifier",
        "qualified_type",
        "pointer_type",
        "generic_type",
        "slice_type",
        "array_type",
        "map_type",
        "channel_type",
        "parenthesized_type",
    });
}

def _go_alias_re_exports(alias_node, source: bytes) -> bool;
def _go_type_param_names(decl_node, source: bytes) -> frozenset[str];

glob skip_default_: any;

with entry {
    skip_default_ = frozenset();
}

def _go_collect_type_refs(
    `node,
    source: bytes,
    generic: bool,
    out: list[tuple[str, str]],
    `skip: frozenset[str] = skip_default_,
);
def _go_strip_generic_args(type_text: str) -> str;
def _go_single_type_name(`node, source: bytes) -> str | None;
def _go_inferred_composite_bindings(names, values, source: bytes) -> Generator[any, any, any];
def _go_receiver_type_table(`root, source: bytes, *, package_only: bool = False) -> dict[str, str
    | None];
def _go_struct_field_types(`root, source: bytes) -> dict[str, dict[str, str]];
def extract_go(path: Path) -> dict;
