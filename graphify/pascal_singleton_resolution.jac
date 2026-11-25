"""Cross-file resolution of Pascal/Delphi calls made through a global object.

Delphi's dominant application idiom is the global singleton: a unit declares
``var DM: TDM = nil;`` next to the data module it holds, every other unit
``uses`` it, and the work happens in ``DM.OpenPeriod``, ``PDM.Recalculate``,
``dtmTabele.Refresh``. The per-file pass cannot resolve any of it -- it
discards the qualifier and looks the bare member name up in the CALLER's own
scope (``_resolve_pascal_callee_factory``), which is the wrong object, so the
call is reported as a raw call and the business logic of the application
arrives in the graph as unconnected routines.

This resolver runs once every file is extracted, so it can see both halves:
the ``var`` block that gives ``DM`` its type, and the class that type names.
Resolution follows the compiler:

1. the qualifier must not be shadowed -- the extractor already withholds it
   when the routine declares a parameter, a local, or a class field of that
   name (a Delphi form publishes its components as plain fields, so ``Query``
   inside a form method is the component, never a global of the same name);
2. the variable must be visible: declared in the calling file itself or in a
   unit its ``uses`` clause names. Pascal identifier visibility is NOT
   transitive, so the direct uses clause is exactly the right scope;
3. the variable's type, that type's class, and the method must each resolve
   to exactly one candidate, or nothing is emitted.

Unit names are matched against the INDEXED CORPUS rather than against the
disk. The per-file ``imports`` pass resolves a unit name by scanning
``_pascal_project_root`` -- the highest ancestor directly holding ``.pas``
files -- and in the standard Delphi layout, with the ``.dpr`` in
``Projects/App/`` and units in sibling ``DataModules/`` and ``Forms/`` trees,
that root is the project subdirectory alone, so cross-directory units resolve
to nothing. Matching names against the files actually extracted sidesteps
that here without changing what the per-file pass emits.

Only ``calls`` edges are added, only for raw calls that nothing else
resolved, and only between nodes that already exist.
"""

import from __future__ { annotations }

import os;

glob _PASCAL_SUFFIXES: any = (".pas", ".pp", ".dpr", ".dpk", ".inc");

def _is_pascal(source_file: object) -> bool;

def _basename(path: str) -> str;

def _unit_stem(source_file: str) -> str;

"""The path a per-file extraction result carries, as the extractor wrote it."""
def _raw_path_of(result: dict) -> str | None;

"""Map an extractor path onto the one the merged graph uses.

    A per-file result keeps the path the extractor was handed -- absolute, in
    the platform's own separators -- while the id-remap pass relativises
    `source_file` on the merged nodes. The two therefore never compare equal,
    and `extract.py` says as much where it builds its own call index: *key on
    stable node ids, not source_file strings*. Call sites here do exactly
    that, via `caller_nid`; a unit that only DECLARES globals has no call to
    anchor on, so its path is matched instead -- by basename, then by
    requiring the corpus path to be a tail of the extractor's, which is what
    relativising leaves behind. An ambiguous match yields nothing.
    """
def _corpus_path_matcher(corpus_files: set[str]) -> any;

"""Resolve ``Global.Method()`` calls to the method of the global's class.

    Purely additive: every edge emitted is a ``calls`` edge for a raw call the
    per-file pass could not resolve, and each requires an unambiguous
    variable, type and method. Ambiguity produces no edge rather than a guess.
    """
def resolve_pascal_singleton_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;
