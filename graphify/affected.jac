import importlib;
import operator;

import from __future__ { annotations }

import json;

import from collections { deque }

import from json { JSONDecodeError }

import from dataclasses { dataclass }

import from pathlib { Path }

import from typing { Iterable }

import unicodedata;

import networkx as nx;

glob DEFAULT_AFFECTED_RELATIONS: any = (
    "calls",
    "indirect_call",
    "references",
    "imports",
    "imports_from",
    "dynamic_import",
    "re_exports",
    "inherits",
    "extends",
    "implements",
    "uses",
    "mixes_in",
    "embeds",
    "defines",
    "requires",
);

glob _SUPERTYPE_RELATIONS: any;

glob _JAVA_PRIMITIVES: any;

with entry {
    _SUPERTYPE_RELATIONS = frozenset({"inherits", "extends", "implements"});
}

@dataclass(frozen=True)
class AffectedHit {
    has node_id: str;

    has depth: int;

    has via_relation: str;

    has via_file: "str | None" = None;

    has via_location: "str | None" = None;
}

def _node_label(`graph: nx.Graph, node_id: str) -> str;

def _format_location(data: dict) -> str;

"""Lowercased label with the callable decoration (trailing "()") removed."""
def _bare_name(label: str) -> str;

def _normalize_label(label: str) -> str;

"""Repo-relative form of a path query, for matching a stored `source_file`.

    The graph stores repo-relative paths, so `./src/x.py` and
    `/abs/repo/src/x.py` name the same file as `src/x.py` and yet matched
    nothing. `affected` then printed an empty list and exited 0 — a blast-radius
    tool answering "nothing depends on this" about a file with sixteen
    dependents, and indistinguishable from a genuine zero or a typo.

    An absolute path is anchored to `root` when given — the repo root derived
    from the graph's own location — so a seed resolves regardless of the caller's
    working directory (#2706: an absolute-path seed previously only matched when
    cwd happened to be the analysed repo root, which no editor or script can
    guarantee). `root` falls back to the current directory to preserve the prior
    behaviour when a caller has no graph location to derive it from.

    Non-path queries pass through unchanged: `Path("myFunc()").as_posix()` is
    `"myFunc()"`, so label resolution is untouched. An absolute path rooted
    outside `root` is left alone — no basename guessing.
    """
def _as_repo_relative(query: str, `root: Path | None = None) -> str;

"""Return the file-level node when a source_file query matches many nodes."""
def _prefer_file_node(`graph: nx.Graph, node_ids: list[str], query: str) -> str | None;

"""Resolve the reference forms `explain` accepts but `resolve_seed` did not.

    `explain` resolves a `path::Symbol` reference (#3485) and a dotted Python
    name (`pkg.mod.func` / `pkg.mod:func`, #4366) to a single node; `affected` and
    `query --seed` rejected both with "No unique node match" even when `explain`
    resolved the very same string. Following the README's own advice ("use the
    precise ID returned by the graph") therefore forced a caller through
    `explain` first just to obtain an id (#4792).

    Only the two path-qualified forms are handled here — they carry their own
    disambiguating context, so a match is never a guess. A bare name keeps going
    through `resolve_seed`'s existing tiers, where an exact-name tie must stay
    unresolved rather than be broken by graph-iteration order.

    Returns the unique node id, or None to fall through to the ordinary tiers.
    """
def resolve_reference_forms(`graph: nx.Graph, query: str) -> str | None;

def resolve_seed(`graph: nx.Graph, query: str, `root: Path | None = None) -> str | None;

"""Every type ``type_id`` derives from, nearest first (cycles cut)."""
def _supertypes(`graph: nx.DiGraph, type_id: str, cache: dict[str, list[str]]) -> list[str];

"""The supertype members ``node`` overrides: same-named methods of the types
    its class derives from. A call bound to one of them can run ``node`` at
    runtime (`visitor.head()` typed `NodeVisitor` runs `FormattingVisitor.head`)."""
def _overridden_members(`graph: nx.DiGraph, `node: str, cache: dict[str, list[str]]) -> list[str];

with entry {
    _JAVA_PRIMITIVES = frozenset({
        "boolean",
        "byte",
        "char",
        "short",
        "int",
        "long",
        "float",
        "double",
    });
}

"""A recorded erased signature as its parameter list, ``T...`` as ``T[]``
    (a variadic parameter is an array one, so it overrides ``T[]``)."""
def _java_params(signature: object) -> list[str] | None;

"""False only when two erased parameter types can never be one type: a
    primitive differs from anything else, or two arrays differ in a primitive
    element. Two different reference types may still match (a type variable
    erases to its bound, `save(T)` overridden by `save(String)`)."""
def _may_be_same_param(mine: str, theirs: str) -> bool;

"""The ``members`` of one supertype that ``node`` can override (#5251).

    Overloads of a name are separate nodes with one label, so the label alone
    would tie ``run(int)`` to a supertype's ``run()``. An override has the same
    declared parameter count (a ``T...`` parameter counts as one, like ``T[]``)
    and parameter types that can be the same: a primitive never matches another
    type, but two reference types may (a generic supertype's ``save(T)`` is
    overridden by ``save(String)``), so those stay. A node without a recorded
    arity (other languages) keeps the label-only match.
    """
def _overload_compatible(`graph: nx.DiGraph, `node: str, members: list[str]) -> list[str];

glob relations_default_: any;

with entry {
    relations_default_ = DEFAULT_AFFECTED_RELATIONS;
}

def affected_nodes(
    `graph: nx.Graph, seed: str, *, relations: Iterable[str] = relations_default_, depth: int = 2
) -> list[AffectedHit];

"""Resolve a seed and report why it failed, so the CLI can set an exit code.

    `affected` printed "No unique node match" and still exited 0, so a script
    could not branch on the outcome the README documents (3 = ambiguous,
    4 = no match) while `explain` already follows it (#4792). Returns
    ``(node_id, [])`` on success, ``(None, rivals)`` when the query is the
    ambiguous name of several nodes, and ``(None, [])`` when nothing matched.
    """
def resolve_seed_outcome(`graph: nx.Graph, query: str, `root: Path | None = None) -> tuple[str
    | None, list[str]];

glob relations_default__: any;

with entry {
    relations_default__ = DEFAULT_AFFECTED_RELATIONS;
}

def format_affected(
    `graph: nx.Graph,
    query: str,
    *,
    relations: Iterable[str] = relations_default__,
    depth: int = 2,
    `root: Path | None = None,
    seed: str | None = None,
) -> str;

def load_graph(path: Path) -> nx.Graph;
