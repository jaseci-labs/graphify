"""Cross-file resolution for Pascal/Delphi calls to inherited methods.

The per-file Pascal/Delphi extractors (``extract_pascal``,
``_extract_pascal_regex``) resolve calls to a method on the caller's own
class, its ancestor chain, or a file-level free function -- but only within
the single file being extracted (each file is extracted independently; see
``_resolve_pascal_callee_factory`` in ``extract.py``). Real Delphi/MTM-style
codebases very commonly split a class across two files -- a code-generator
base class (e.g. Sistec's ``Th0Xxx``) and a manual descendant that extends it
in a separate unit (``Th5Xxx``) -- so a call from the manual descendant to a
method it inherits from the generated base falls outside any one file's own
scope. The per-file pass reports these as ``raw_calls`` instead of guessing.

This resolver runs after all files are extracted (registered in
``graphify.resolver_registry``), with the full merged node/edge corpus
available, so it can walk an ``inherits`` chain across file boundaries. It
intentionally does NOT fall back to a global by-name match the way the
per-file pass's final tier does -- an unqualified call resolving to a
specific ancestor mirrors Delphi's actual method-lookup semantics (nearest
ancestor in the chain), so walking `inherits` is a structurally justified
resolution, not a heuristic guess; guessing by name across an entire
multi-thousand-file corpus is not the same bet.
"""

import from __future__ { annotations }

glob _PASCAL_SUFFIXES: any = (".pas", ".pp", ".dpr", ".dpk", ".inc");

def _pascal_raw_calls(per_file: list[dict]) -> list[dict];

"""Resolve Pascal/Delphi calls to a method inherited across file boundaries.

    Purely additive: only emits edges for raw calls the per-file pass could
    not resolve locally (see module docstring). Each emission requires a
    single owning class at the nearest matching level of the caller's
    ``inherits`` chain (god-node guard, same principle as
    ``resolve_ruby_member_calls``) -- an ambiguous or unresolved name
    produces no edge rather than a guess.
    """
def resolve_pascal_inherited_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;
