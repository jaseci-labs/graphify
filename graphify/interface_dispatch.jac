"""Member-level dispatch from an interface requirement to its implementer(s).

A call through an injected dependency lands on the interface's method node,
because that is what the call site names: `_report.Build()` where `_report` is
an `IReport` resolves to `IReport.Build()`. The implementing method is a
separate node, and nothing joins the two, so a directed walk stops at the
interface and every chain through an injected dependency is cut at that point.

This resolver runs after all files are extracted, with the merged corpus
available, and links the interface's method to every implementing method:

    ireport_ireport_build  --dispatches_to-->  report_report_build
    ireport_ireport_build  --dispatches_to-->  alternatereport_alternatereport_build

For a static structural graph the question a call through the interface asks
is "what can this reach", not "which one does it reach at runtime" — with N
implementers the answer is all N, not none. Each implementer is still subject
to the single-owner guard `resolve_pascal_inherited_calls` and
`resolve_ruby_member_calls` already use: an implementer that itself declares
more than one method of the same name is ambiguous and is skipped on its own,
independently of its siblings, unless the overloads pair up one-to-one by
signature or parameter count (C#, #4584).

The join is per method rather than per call site, so one edge per implementer
reconnects every call that reaches the interface method. Confidence is
`INFERRED` and falls as the candidate set grows, on the extraction rubric's own
tiers: 0.85 ("strong inference") for a single implementer — the target is
forced, the source text just never names it — 0.75 for two, and a 0.65 floor
("weak inference") from three on, rather than inventing finer-grained
precision the rubric does not have.

The mechanism knows no language. Each language registers a thin wrapper
(`graphify.csharp_dispatch` for C# interfaces, #3003) that fixes the file
suffixes both ends of a pair must be declared in: `implements` is resolved by
name, so a same-named type from another language is a collision, not an
implementation. A language whose interfaces have the same shape (Swift
protocols, for one) adds a wrapper, not a second copy of the algorithm.
"""

import from __future__ { annotations }

glob DISPATCH_RELATION: any = "dispatches_to";

glob _DISPATCH_CONFIDENCE_BY_IMPLEMENTER_COUNT: any = {1: 0.85, 2: 0.75};

glob _DISPATCH_CONFIDENCE_FLOOR: any = 0.65;

"""INFERRED confidence for a dispatch edge, given how many implementers exist.

    One implementer is forced — "strong inference". Three or more floors at
    "weak inference" instead of continuing to fall per extra implementer.
    """
def _dispatch_confidence(implementer_count: int) -> float;

"""True when the node is a declaration that lives in a file with one of ``suffixes``.

    Every end of a dispatch pair has to pass this. A sourceless stub minted for
    a dangling reference carries no members worth dispatching to, and a
    cross-language pair is a name collision rather than an implementation. The
    suffix is the effective one, so a `.graphifyrc` language declaration counts
    (#2961).
    """
def declared_in(`node: dict | None, suffixes: tuple[str, ...]) -> bool;

"""Return a method node's bare name, for matching.

    Case is kept: C# and Swift are case sensitive, and an implementing member
    must spell the interface member exactly, so folding case could only pair a
    declaration with a member that does not implement it.

    The name is cut at the first parenthesis rather than by stripping a trailing
    `()`. Today the extractors label every method `.Name()`, so the two are the
    same, but the pair match is keyed on this string and a label that ever carried
    a signature would silently stop matching instead of failing visibly.
    """
def method_label(`node: dict) -> str;

"""Link each interface method to every implementation that owns it unambiguously.

    Purely additive: the existing call edge to the interface method is left in
    place, since the call site really does name the interface. ``suffixes`` is
    the language gate: the interface and each implementer must both be
    declared in a file with one of these extensions.
    """
def resolve_interface_dispatch(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict], *, suffixes: tuple[str, ...]
) -> None;

"""Pair an interface's methods of one name with the implementer's members.

    A C# explicit implementation (``int IA.Get()``) implements a member of its
    own interface and wins over a public ``Get()`` for it; it never implements
    another interface. So the interface methods are paired with the explicit
    implementations of this interface first, and only the ones left over with
    the ordinary members (``int IA.Get()`` explicit beside a public
    ``int Get(int)`` implementing ``IA.Get(int)``). Languages without explicit
    implementations see a single ordinary pass.
    """
def _implementing_pairs(
    declared: set[str], candidates: set[str], interface_name: str, node_by_id: dict
) -> list[tuple[str, str]];

"""Pair an interface's methods of one name with an implementer's.

    One of each pairs up as always. Otherwise (C# overloads, #4584) each
    interface method pairs with the one implementer method of the same declared
    signature, else of the same parameter count among those no signature
    claimed; no unique match, no edge. An implementer method takes at most one
    interface method, so an overload implemented on a base class is not pinned
    on a sibling of the same count.
    """
def _overload_pairs(
    declared: set[str], candidates: set[str], node_by_id: dict
) -> list[tuple[str, str]];
