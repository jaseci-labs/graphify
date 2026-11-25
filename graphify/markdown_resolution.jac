"""Cross-file resolution of code-span mentions in Markdown documents.

``extract_markdown`` reports every inline code span that reads as a symbol
name (``Widget``, ``render()``, ``pkg.Widget``, ``src/mod.py::Widget::render``)
as a ``raw_calls`` entry tagged ``language: "markdown"`` instead of guessing a
target id: the symbol is defined in some other file, and only once every file
is extracted and the id-remap passes have run can the mention be matched to
the node that actually exists. Riding the ``raw_calls`` channel means those
passes rewrite the mention's ``caller_nid`` alongside every other raw call,
and the extraction cache round-trips it for free.

This resolver runs from the language-resolver registry (see
``resolver_registry``) with the merged corpus in hand and turns each mention
into a ``references`` edge from the heading (or page) that cites the symbol
to the code node that defines it:

* a path-qualified mention resolves against the cited file only. The file is
  matched by its path relative to the document, then as a segment-aligned
  suffix of a scanned file, and must be unique; the symbol chain is walked
  through ``contains`` / ``method`` edges so ``mod.py::Widget::render`` is
  the ``render`` owned by ``Widget``. The document names the file and the
  symbol verbatim, so the edge is EXTRACTED;
* a bare mention resolves only when exactly one callable or type in the
  corpus carries that label (case-sensitive; language built-ins excluded).
  Only nodes the extractors marked ``_callable`` qualify, for the reason the
  indirect-call pass gives (#1566): a by-name match must land on a real
  function, method or class, never on a same-named data symbol such as a
  JSON key. A dotted mention (``pkg.Widget``, ``Widget.render``) keeps its
  qualifiers, and a candidate survives only when every qualifier is a label
  on its ``contains`` / ``method`` owner chain or a segment (or stem) of its
  source path: ``time.sleep`` never lands on a repo's own ``sleep``, and
  ``Widget.render`` picks the ``render`` that ``Widget`` owns. No other
  tie-breaking: an ambiguous name is a guess, and a guess is not an edge.
  A bare, parenthesis-less method name is held to one more test: a word like
  ``redis`` is prose as often as it is a reference, so a method match survives
  only when the citing section also names the class that owns it (#4609).
  A bare free function name is held to the same test with its defining file in
  place of the owner class: prose-like words (``token``, ``raw``) require the
  citing section to cite that file or a symbol from it (#4804). Evidence is
  section-scoped. Classes, snake_case, camelCase, trailing ``()``, or PascalCase
  in export languages carry sufficient evidence on their own. Links to scanned
  source files also mint doc->file references edges.
  The match is INFERRED (0.95, a named cross-file reference).

An explicit relative cite (``./`` or ``../``) resolves against the document's
directory only; it never falls through to the suffix rule, so a path that
escapes the corpus cannot land on an unrelated copy of the file elsewhere.

The shared cross-file call pass in ``extract`` skips ``markdown`` raw calls,
so a mention never surfaces as a ``calls`` edge.
"""

import operator;

import from __future__ { annotations }

import os;

import re;

import from pathlib { Path }

import from typing { Any }

glob MARKDOWN_MENTION_SUFFIXES: any;

glob _CONTAINMENT_RELATIONS: any;

glob _RELATIVE_PREFIX_RE: any;

glob _CAMEL_CASE_RE: any;

glob _PASCAL_EXPORT_SUFFIXES: any;

with entry {
    MARKDOWN_MENTION_SUFFIXES = frozenset({".md", ".mdx", ".qmd", ".skill"});

    _CONTAINMENT_RELATIONS = frozenset({"contains", "method"});
    _RELATIVE_PREFIX_RE = re.compile("^(\\.\\.?/)+");
}

"""A node's label as a document would write it: no ``()``, no leading dot."""
def _symbol_label(`node: dict[str, Any]) -> str;

with entry {
    _CAMEL_CASE_RE = re.compile("[a-z][A-Z]");
    _PASCAL_EXPORT_SUFFIXES = frozenset({
        ".go",
        ".cs",
        ".vb",
        ".swift",
        ".scala",
        ".pas",
        ".dpr",
        ".lpr",
        ".ps1",
        ".psm1",
    });
}

"""Whether a bare label looks like ordinary prose rather than a distinct code identifier.

    Distinct code identifiers — snake_case (containing ``_``) or camelCase (a
    lowercase letter followed by uppercase) — are exempt from the bare
    free-function evidence test (#4804), while plain single-word lowercase
    names (``token``, ``raw``, ``fail``, ``config``) require evidence. A
    PascalCase label is exempt only in a PascalCase-export language, checked
    by the caller against the target's source file.
    """
def _is_prose_like_label(label: str) -> bool;

"""Whether *source_file*'s language exports identifiers as PascalCase."""
def _is_pascal_case_export_language(source_file: str) -> bool;

def _is_file_node(`node: dict[str, Any]) -> bool;

def _posix(path: str) -> str;

"""The scanned source file a ``path::Name`` mention names, or None.

    Tries the path relative to the citing document first (``../src/mod.py``
    from ``docs/guide.md``), then an exact match, then a unique
    segment-aligned suffix (``src/mod.py`` naming ``/repo/src/mod.py``). A
    cite that is explicitly relative (``./x`` or ``../x``) stops after the
    first step: it names one location, and a suffix match elsewhere would be a
    different file.
    """
def _match_cited_file(cited: str, doc_file: str, source_files: set[str]) -> str | None;

"""The scanned file a normalized cite names by unique segment-aligned suffix."""
def _cited_file_suffix(cited_posix: str, source_files: set[str]) -> str | None;

"""Resolve a cited file even when a partial rebuild mixes path forms.

    Preserved nodes carry project-relative ``source_file`` values while a
    freshly re-extracted document may carry an absolute one, so the
    document-relative join in :func:`_match_cited_file` can miss a file that is
    in the corpus. The suffix fallback fires only when that mixing is detected
    (an absolute citing document against a corpus with relative paths) — with
    uniform path forms the explicit-relative discipline above holds unchanged.
    The result licenses evidence and doc->file citations, both anchored to
    corpus files, so a unique corpus path that is a suffix of the joined path
    is the file the document's own directory tree names.
    """
def _match_cited_file_any_form(
    cited: str,
    doc_file: str,
    source_files: set[str],
    *,
    form_mismatch: bool,
    scan_root: "Path | str | None" = None,
) -> str | None;

"""Resolve an authored Markdown link to a source file strictly against its target."""
def _match_file_link(
    cited: str,
    doc_file: str,
    source_files: set[str],
    *,
    form_mismatch: bool,
    scan_root: "Path | str | None" = None,
) -> str | None;

"""Labels a dotted mention may qualify ``node_id`` with.

    The labels of every node on its ``contains`` / ``method`` owner chain
    (``Widget`` for ``Widget.render``) plus each segment and stem of its
    source path (``pkg`` and ``mod`` for ``pkg.mod.Widget``).
    """
def _evidence(
    node_id: str, nodes_by_id: dict[str, dict[str, Any]], parents: dict[str, set[str]]
) -> set[str];

def _markdown_raw_calls(per_file: list[dict]) -> list[dict];

"""Turn ``language: "markdown"`` raw calls into ``references`` edges in place."""
def resolve_markdown_mentions(
    per_file: list[dict],
    all_nodes: list[dict],
    all_edges: list[dict],
    *,
    scan_root: "Path | str | None" = None,
) -> None;
