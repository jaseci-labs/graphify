"""Cross-file resolution of Pascal/Delphi base classes to their declaration.

The per-file extractors resolve a base class name with
``_pascal_resolve_class``, which maps a name to a file by NAMING CONVENTION
alone: ``TFooBar`` is assumed to live in ``FooBar.pas``. When no such file
exists the extractor creates a stub node in the inheriting file instead, as it
must -- a single file cannot know where a name it does not declare comes from.

The convention holds for RTL-style code and breaks on most real Delphi. A base
class declared in a unit named anything else -- ``TXForm`` in ``XFormP.pas``,
``TPrzodek`` in ``Obiekty.pas`` -- produces one private stub per inheriting
file, so an inheritance hierarchy that is one tree in the compiler arrives in
the graph as hundreds of disconnected two-node fragments. Two things break
with it:

- "what inherits from X" answers with one class instead of hundreds, and
- ``resolve_pascal_inherited_calls`` walks the ``inherits`` chain to resolve a
  call to an inherited method, so a chain severed at its first link resolves
  almost nothing.

This resolver runs after all files are extracted, with the full corpus
available, and retargets those ``inherits`` edges onto the node where the class
is actually declared. It is registered BEFORE ``pascal_inherited_calls`` so the
call resolver walks a repaired chain.

A declared class is distinguished from a stub structurally: the extractor emits
a ``contains`` edge from the enclosing module/file node to every type it
declares, and nothing contains a stub. The retarget then requires a unique
declaration -- preferring one in a unit the inheriting file actually imports,
exactly as the compiler would -- and leaves the stub untouched when the name is
ambiguous or unknown, so an external base class (``IDispatch``, RTL types)
keeps the graph it has today.
"""

import from __future__ { annotations }

glob _PASCAL_SUFFIXES: any = (".pas", ".pp", ".dpr", ".dpk", ".inc");

def _is_pascal(source_file: object) -> bool;

"""Point Pascal ``inherits`` edges at the class's real declaration.

    Mutates ``all_edges`` in place (retargeting, then deduplicating). The stub
    node the extractor created in the inheriting file is left in place once its
    ``inherits`` edge is retargeted; it becomes an orphan (at most one per
    inheriting file), which is harmless graph noise. Keeping it avoids changing
    the node-list length, which the incremental-rebuild scratch slice relies on.
    Purely a repair: no new relation is introduced and no edge is created
    between classes that were not already related by an ``inherits`` the
    extractor emitted.
    """
def resolve_pascal_base_classes(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;
