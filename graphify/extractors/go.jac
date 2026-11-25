"""Go extractor. Moved verbatim from graphify/extract.py."""

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

"""Whether `type A = pkg.A` (or `pkg.A[...]`) re-exports another package's type
    under its own name. Such an alias denotes that very type and declares no new
    name, so it gets no node: references to `A` keep resolving to the original
    instead of tying between the two. Any other alias introduces a name."""
def _go_alias_re_exports(alias_node, source: bytes) -> bool;

"""Names bound by a declaration's generic type parameters.

    Covers a function/type's own `[T any, R comparable]` list and, for a method,
    the receiver's `(b Box[T])` type arguments (Go methods cannot declare their
    own type parameters; they reuse the receiver's). These names are local
    bindings, not corpus symbols, so a signature's use of them must not mint a
    sourceless stub.
    """
def _go_type_param_names(decl_node, source: bytes) -> frozenset[str];

glob skip_default_: any;

with entry {
    skip_default_ = frozenset();
}

"""Walk a Go type expression; append (name, role) tuples.

    Names in ``skip`` (the enclosing declaration's generic type parameters) are
    local bindings, not references, and are dropped.
    """
def _go_collect_type_refs(
    `node,
    source: bytes,
    generic: bool,
    out: list[tuple[str, str]],
    `skip: frozenset[str] = skip_default_,
) -> None;

"""Drop a generic instantiation's type arguments from a receiver type's text.

    ``(b *Box[T])`` reads its ``type`` field as ``*Box[T]`` verbatim (after the
    leading ``*`` is stripped, ``Box[T]``), but the type declaration's own id
    is keyed on the bare name alone: ``type Box[T any] struct {...}`` captures
    ``[T any]`` as a separate ``type_parameter_list``, never part of the name.
    Without stripping this before building an id from it, a generic receiver's
    id never matched its own type's id, so a generic type's methods attached
    to a node disconnected from the type itself (#3368) — this must run
    everywhere a receiver's raw type text turns into an id, not only one of
    them, or the two computations silently disagree.
    """
def _go_strip_generic_args(type_text: str) -> str;

"""The one declared type a Go type expression names, or None.

    `Greeter`, `*Greeter`, `pkg.Greeter` and `*pkg.Greeter` qualify, and generic
    arguments do not change the receiver's base type. A slice, map or channel
    element is not the receiver of `x.M()`. A qualified type keeps its package
    qualifier as written (`pkg.Greeter`): no bare local name can stand for it, so
    the resolver binds it only through the file's import of `pkg`.
    """
def _go_single_type_name(`node, source: bytes) -> str | None;

"""Pair same-position declared names with composite-literal values.

    Shared by `x := T{}` (`short_var_declaration`) and `var x = T{}` (a
    type-less `var_spec`): both bind a name to the type of a same-position
    `T{}` / `&T{}` value. Yields (name text, inferred type) for each pair
    that is in fact a composite literal.
    """
def _go_inferred_composite_bindings(names, values, source: bytes) -> Generator[any, any, any];

"""Collect declared or composite-literal receiver types, preserving unknown bindings.

    Unknown local bindings shadow package variables. Package-only tables exclude
    fields and function bodies so unrelated scopes cannot supply a receiver type.
    """
def _go_receiver_type_table(`root, source: bytes, *, package_only: bool = False) -> dict[str, str
    | None];

"""``struct name -> {field name -> TypeName}`` for every struct this file declares.

    Only a named field whose type `_go_single_type_name` accepts is kept, the same rule
    the flat receiver table applies. Unlike that table it stays keyed by the struct, so a
    method in another file of the package can read the fields of its own receiver.
    """
def _go_struct_field_types(`root, source: bytes) -> dict[str, dict[str, str]];

"""Extract functions, methods, type declarations, and imports from a .go file."""
def extract_go(path: Path) -> dict;
