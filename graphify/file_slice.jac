import importlib;
import operator;
import from __future__ { annotations }

import os;

import from collections.abc { Sequence }

import from dataclasses { dataclass }

import from pathlib { Path }

glob _SPLITTABLE_TEXT_SUFFIXES: any;

glob _CONVERTED_TEXT_SUFFIXES: any;

glob _CONVERTED_TEXT_CACHE: "dict[tuple, str]";

glob _CONVERTED_TEXT_CACHE_MAX: any;

glob _BOUNDARY_SEPARATORS: any;

glob Unit: any;

with entry {
    _SPLITTABLE_TEXT_SUFFIXES = frozenset({
        ".md",
        ".mdx",
        ".markdown",
        ".txt",
        ".rst",
        ".qmd",
        ".skill",
        ".html",
        ".j2",
        ".jinja",
        ".jinja2",
    });
    _CONVERTED_TEXT_SUFFIXES = frozenset({".pdf"});
}

def _pdf_text(path: Path) -> str;

with entry {
    _CONVERTED_TEXT_CACHE = {};
    _CONVERTED_TEXT_CACHE_MAX = 64;
}

def unit_source_text(path: Path) -> str;

with entry {
    _BOUNDARY_SEPARATORS = ("\n#", "\n\n", "\n");
}

@dataclass(frozen=True)
class FileSlice {
    has path: Path;

    has start: int;

    has end: int;

    has index: int;

    has total: int;
}

with entry {
    Unit = "Path | FileSlice";
}

def unit_path(unit: "Path | FileSlice | str") -> Path;
def is_splittable_text(path: "Path | FileSlice | str") -> bool;
def _best_cut(text: str, start: int, end: int) -> int;
def slice_boundaries(text: str, max_chars: int) -> list[tuple[int, int]];
def expand_oversized_files(
    files: "list[Path | FileSlice]", max_chars: int
) -> list["Path | FileSlice"];
def read_slice_text(fs: FileSlice) -> str;
def bisect_slice(fs: FileSlice) -> tuple[FileSlice, FileSlice] | None;
def make_full_slice(path: "Path | FileSlice") -> FileSlice | None;
def is_complete_slice_coverage(parent: "Path | str", slices: "Sequence[FileSlice]") -> bool;
