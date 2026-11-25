"""Return the text of a Markdown section straight from its source file.

A heading node records the line its heading sits on. The section it opens is
found at read time from the current file: it runs to the line before the next
heading of the same or a shallower level, so it includes its subsections. The
boundary is never stored, so an edit inside a section cannot make it stale, and
graphs built before this module existed work unchanged.

Heading detection reuses the Markdown extractor's own rules (ATX headings,
CommonMark fences, leading frontmatter), so what counts as a heading here is
exactly what the extractor turned into a node.
"""

import importlib;
import operator;

import from __future__ { annotations }

import re;

import from dataclasses { dataclass }

import from pathlib { Path }

glob DEFAULT_MAX_CHARS: any = 8000;

glob _MARKDOWN_SUFFIXES: any;

glob _LINE_RE: any;

glob _BODY_CONTROL_RE: any;

glob _SECTION_VIEW_GRAPH_KEYS: any;

with entry {
    _MARKDOWN_SUFFIXES = frozenset({".md", ".mdx", ".qmd", ".skill"});
    _LINE_RE = re.compile("^L(\\d+)$");
    _BODY_CONTROL_RE = re.compile("[\\x00-\\x08\\x0b-\\x1f\\x7f]");
}

@dataclass(frozen=True)
class Section {
    has source_file: str;

    has start: int;

    has end: int;

    has text: str;

    has truncated: bool;

    has moved: bool;
}

"""``(line, level, title)`` for every heading the extractor would emit."""
def _headings(lines: list[str]) -> list[tuple[int, int, str]];

"""The file ``source_file`` names, or None when it falls outside ``root``."""
def _resolve_inside(source_file: str, `root: Path) -> "Path | None";

"""The project root section reads are confined to, for the graph at ``gp``.

    For a graph in ``<project>/graphify-out`` a ``.graphify_root`` marker may
    only narrow the root to a folder inside the project, never widen it, so a
    committed marker cannot open the rest of the disk to reads.
    """
def section_root(gp: Path) -> Path;

def is_section_node(`node: dict) -> bool;

glob max_chars_default_: any;

with entry {
    max_chars_default_ = DEFAULT_MAX_CHARS;
}

"""Read the section a heading (or page) node opens. ``(section, "")`` or ``(None, reason)``."""
def read_section(
    `node: dict, `root: Path, max_chars: int = max_chars_default_
) -> "tuple[Section | None, str]";

def format_section(section: Section, label: str) -> str;

with entry {
    _SECTION_VIEW_GRAPH_KEYS = frozenset({"_logical_directed"});
}

"""Resolve a heading label, node id or ``path::Heading`` to one section node.

    A code symbol that shares a heading's name must not shadow it, so a query
    that is ambiguous or lands on a non-section node is retried against the
    section nodes alone.
    """
def resolve_section_query(G, query: str) -> "tuple[str | None, str]";
