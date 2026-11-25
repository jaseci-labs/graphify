"""Conservative C++ type lookup for declared member-call receivers.

This is lexical name lookup, not a C++ compiler: dependent types, alias templates,
transitive using directives and arbitrary template specializations remain unresolved.
"""

import builtins;

import operator;

import from __future__ { annotations }

import re;

import posixpath;

import from bisect { bisect_left }

glob _IDENTIFIER: any = "(?:::)?[A-Za-z_]\\w*(?:::[A-Za-z_]\\w*)*";

glob seen_default_: any;

with entry {
    seen_default_ = frozenset();
}

"""Reuse persisted AST facts while keeping scope/include lookup out of extract.py."""
obj CppTypeLookup {
    has nodes: any,
        files: any,
        bindings: any,
        types: any,
        class_scopes: any,
        imports: any,
        namespaces: any,
        directives: any,
        _reachable_cache: any,
        _member_cache: any,
        include_positions: any;

    def init(nodes: list[dict], edges: list[dict]);

    def reachable(source: str, position: int) -> frozenset[str];

    def _binding(
        name: str,
        scope: str,
        source: str,
        position: int,
        completion: tuple[str, int, frozenset[str]] | None,
    ) -> any;

    def _expand(
        name: str,
        scope: str,
        source: str,
        position: int,
        seen: set,
        depth: int = 0,
        completion: tuple[str, int, frozenset[str]] | None = None,
    ) -> tuple[str, str] | None;

    def resolve(
        name: str,
        scope: str,
        source: str,
        position: int,
        access_op: str,
        *,
        use_source: str | None = None,
        use_position: int | None = None,
    ) -> str | None;

    def shadowed_prefix(prefix: str, scope: str, source: str, position: int) -> bool;

    """An unresolved lexical alias must not become an unrelated cross-repo class."""
    def is_alias(name: str, scope: str, source: str, position: int) -> bool;

    """Return an owner, None for absent, or False for an unknown/ambiguous lookup."""
    def member_owner(
        type_nid: str, name: str, kind: str, seen: frozenset[str] = seen_default_
    ) -> str | bool | None;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}
