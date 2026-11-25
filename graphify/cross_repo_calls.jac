"""Finish member calls that cross a repository boundary in a merged graph (#3152).

A single-repo build can only bind ``obj.method()`` when the receiver's type is
declared in that same build. When the type lives in another repository the
resolver holds the receiver type and drops the call anyway, so ``graph.json`` —
the only artifact ``merge-graphs`` and ``global add`` consume — records nothing,
and no merge-time pass can recover what was never written down. A two-repo call
graph was therefore missing exactly the edges that make it a call graph: eight
edges when the code sits in one corpus, seven after merging the same code from
two repos.

The resolvers now park those calls on the caller node as
``metadata.unresolved_calls`` entries (names only, no node ids — see
``_park_unresolved_member_call``). This pass reads them back after the graphs are
composed and emits the ``calls`` edge when the receiver's type resolves to
exactly one declaration in another repo, keeping the single-definition guard the
single-repo resolvers use: an ambiguous name still fabricates nothing. An ObjC
class split ``@interface``(.h)/``@implementation``(.m) across repos is the one
exception — several same-named candidates bind to the sole one that DEFINES the
selector (#1556), two definitions still being an ambiguity.

Edges only, no node merging or renaming, so the pass composes with the prefixing
and pruning already in place. Every edge it adds is tagged, and it clears its own
previous output before recomputing: ``global add`` composes one repo at a time
and revisits the same pairs on every add, and recomputing from the parked entries
keeps the result identical whether three repos arrived together or one at a time.
"""

import operator;

import from __future__ { annotations }

import os;

import from collections { defaultdict }

import from typing { TYPE_CHECKING }

glob CROSS_REPO_CALL_MARKER: any = "_cross_repo_call";

glob UNRESOLVED_CALLS_KEY: any = "unresolved_calls";

glob _LANG_SUFFIXES: dict[str, frozenset[str]];

glob _MEMBER_RELATIONS: any;

glob _OBJC_IMPL_SUFFIXES: any;

with entry {
    _LANG_SUFFIXES = {
        "cpp": frozenset({".cpp", ".cc", ".cxx", ".hpp", ".hh", ".hxx", ".h", ".cu", ".cuh"}),
        "csharp": frozenset({".cs"}),
        "go": frozenset({".go"}),
        "java": frozenset({".java"}),
        "kotlin": frozenset({".kt", ".kts"}),
        "objc": frozenset({".h", ".m", ".mm"}),
        "swift": frozenset({".swift"}),
        "php": frozenset({".php", ".phtml", ".php3", ".php4", ".php5", ".php7", ".phps"}),
        "typescript": frozenset({
            ".ts",
            ".tsx",
            ".mts",
            ".cts",
            ".js",
            ".jsx",
            ".mjs",
            ".cjs",
            ".vue",
            ".svelte",
            ".astro",
        }),
    };
    _MEMBER_RELATIONS = ("defines", "method");
    _OBJC_IMPL_SUFFIXES = frozenset({".m", ".mm"});
}

"""Normalize a node label or a parked name to its bare identifier.

    Type labels are plain (``Greeter``) while method labels carry the extractor's
    decoration (``.greet()``). Case is preserved: every language that parks calls
    here is case-sensitive, and folding case would let `greeter` answer for
    `Greeter`. Objective-C's ``+``/``-`` sigil is deliberately kept, so an ObjC
    ``-greet`` and a C++ ``.greet()`` stay distinct members of a shared header.
    """
def _key(label: object) -> str;

def _suffix(source_file: object) -> str;

def _parked_entries(data: dict) -> list[dict];

"""Clear the edges this pass added on an earlier run.

    Recompute-from-scratch is what makes an incremental ``global add`` agree with
    a single ``merge-graphs`` of the same inputs, and it is also how a repo whose
    types moved stops answering for calls it no longer owns.
    """
def _drop_previous_output(merged: "nx.Graph") -> None;

"""Index sourced type declarations by bare name. Returns (index, id set)."""
def _index_declarations(merged: "nx.Graph") -> tuple[dict[str, list[str]], set[str]];

"""Index each declaration's members by relation, then by name.

    The merged graph is undirected, and a ``method`` edge carries no reliable
    direction once composed, so the owner is identified as the endpoint that is a
    type declaration. A nested declaration puts a type on both ends; that pair is
    skipped rather than guessed at.

    Kept per relation rather than pooled: ``defines`` covers fields as well as
    C++'s in-class member declarations, so only a language that needs it may look
    there, and only when no ``method`` of that name exists.
    """
def _index_members(
    merged: "nx.Graph", type_ids: set[str]
) -> dict[str, dict[tuple[str, str], list[str]]];

"""Which owner→member relations may answer a call parked by ``lang``.

    Only C++ models an in-class declaration (``void bar();`` in a header) as a
    field, so only a C++ entry may fall back to ``defines``; for every other
    language a ``defines`` target is a field, and a field cannot answer a call.
    """
def _member_relations(lang: str) -> tuple[str, ...];

"""Which member-index keys a parked callee may answer to.

    An ObjC selector carries no class/instance distinction, so both sigils are
    tried; a type declaring `+greet` and `-greet` both is an ambiguity, not a hit.
    A selector cannot itself begin with a sigil, so stripping one first keeps an
    entry that already carries it from asking for `--greet`.
    """
def _member_keys(lang: str, callee: str) -> tuple[str, ...];

"""The sole DEFINITION of an ObjC selector across same-named candidates.

    An ObjC class whose `@interface` (`.h`) and `@implementation` (`.m`) live in
    different repositories surfaces as several same-named candidates that
    ``_merge_decl_def_classes`` folds within a repo but cannot across the boundary
    (its id embeds the directory, #1556). The candidate that DEFINES the selector —
    an impl in `.m`/`.mm`, or a folded node naming its impl in ``definition_file`` —
    is the target; a bare header declaration is not. Two candidates that both define
    it are two unrelated classes and stay ambiguous, so the single-definition guard
    still holds for the collision it was meant to catch.
    """
def _objc_union_definition(
    merged: "nx.Graph",
    members: dict[tuple[str, str], list[str]],
    candidates: list[str],
    callee: str,
) -> str | None;

"""The one Java overload in ``targets`` a call with ``arity`` arguments means.

    ``targets`` are the same-named methods of one type, one node per overload
    (#5251). Exactly one that accepts the count wins; when several do, or none
    does, or the parked entry predates argument counts, the first declared
    stands for the name, as it did when overloads were a single node. Anything
    that is not a recorded overload (no ``arity``) stays ambiguous.
    """
def _java_overload_target(merged: nx.Graph, targets: list[str], arity: object) -> str | None;

"""Emit `calls` edges for parked member calls another repo answers.

    Returns the number of edges added. Idempotent: the pass drops its own earlier
    output first, so re-merging or adding a repo twice cannot duplicate an edge.
    """
def link_cross_repo_member_calls(merged: "nx.Graph") -> int;
