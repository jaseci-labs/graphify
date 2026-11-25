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

def _headings(lines: list[str]) -> list[tuple[int, int, str]];
def _resolve_inside(source_file: str, `root: Path) -> "Path | None";
def section_root(gp: Path) -> Path;

def is_section_node(`node: dict) -> bool;

glob max_chars_default_: any;

with entry {
    max_chars_default_ = DEFAULT_MAX_CHARS;
}

def read_section(
    `node: dict, `root: Path, max_chars: int = max_chars_default_
) -> "tuple[Section | None, str]";

def format_section(section: Section, label: str) -> str;

with entry {
    _SECTION_VIEW_GRAPH_KEYS = frozenset({"_logical_directed"});
}

def resolve_section_query(G, query: str) -> "tuple[str | None, str]";
