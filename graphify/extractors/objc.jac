"""objc — moved verbatim from graphify/extract.py."""

import operator;

import from __future__ { annotations }

import from pathlib { Path }

import from typing { Any }

import re;

glob _OBJC_STEM_PART: any;

glob _CALLABLE: any;

glob _CALLABLE_CLASS: any;

with entry {
    _OBJC_STEM_PART = re.compile("[A-Za-z_][A-Za-z0-9_]*");
    _CALLABLE = ("_callable",);
    _CALLABLE_CLASS = ("_callable", "_callable_class");
}

"""Strip an ObjC category/extension suffix from a file stem (``Foo+Cat`` -> ``Foo``).

    A category (``@interface Foo (Cat)``) or class extension (``@interface Foo ()``)
    declares members of an EXISTING class, so its class node must key to the same id
    as ``Foo.h``'s ``@interface Foo`` instead of minting a second class node (#1556).
    Only the final path segment is considered, and only a well-formed
    ``Name+Suffix`` pair is split.

    Mirrors ``_decldef_class_stem``, which already compares sibling header/impl files
    by the stem before ``+``.
    """
def _objc_category_base_stem(stem: str) -> str;

"""True for ``@interface/@implementation Foo (Cat)`` and ``Foo ()``.

    The grammar emits the parentheses as anonymous children only for a category or
    class extension; a generic class (``@interface Box<T>``) uses
    ``parameterized_arguments`` instead, so it is not matched.
    """
def _objc_is_category(`node) -> bool;

"""Collect ``var -> ClassName`` from ObjC local declarations (``Foo *f = ...;``)
    in a method body, for receiver typing in the cross-file message-send pass
    (#1556). Only a capitalized ``type_identifier`` with a single named declarator
    is recorded; a built-in/lower-cased type or an un-nameable declarator is skipped
    (precision over recall). Reuses the C++ declarator unwrapper (identical grammar).
    """
def _objc_local_var_types(body_node, source: bytes, table: dict[str, str]) -> None;

"""Extract interfaces, implementations, protocols, methods, and imports from .m/.mm/.h files."""
def extract_objc(path: Path) -> dict;
