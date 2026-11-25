"""Intra-file slicing for oversized text documents (#1369).

The extraction packer (`_pack_chunks_by_tokens`) treats each file as atomic and
`_read_files` caps every file at ``_FILE_CHAR_CAP`` characters, so a document
larger than that cap had everything past the cap silently dropped — the model
never saw it, and nothing in the adaptive-retry path could recover it ("a single
file larger than the budget ... packing can't shrink one big file").

This module splits an oversized *splittable text* document (Markdown, plain
text, reStructuredText) into contiguous ``FileSlice`` units at heading /
paragraph / line boundaries so the whole file gets extracted across several
units. Every slice of a file reports the **parent file path** as its source, so
the resulting nodes are never fragmented per-slice — they merge by source_file
exactly as if the file had been extracted in one pass.

Only plain-text documents are sliced: code files need whole-symbol context, and
PDFs/images are read through their own extractors and have no char-offset model.
"""

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

"""Extracted text of a PDF — the same string `llm._file_to_text` builds.

    Imported lazily from ``detect`` so this module keeps no import-time
    dependency on the extraction stack (``llm`` imports *this* module, so the
    reverse direction would be a cycle).
    """
def _pdf_text(path: Path) -> str;

with entry {
    _CONVERTED_TEXT_CACHE = {};
    _CONVERTED_TEXT_CACHE_MAX = 64;
}

"""The text a unit contributes to the prompt, whatever its container.

    Plain-text files are read directly; converted types (PDF) go through their
    converter. Both `expand_oversized_files` and `read_slice_text` use this, so
    the offsets a slice carries always index the same string the model sees.
    """
def unit_source_text(path: Path) -> str;

with entry {
    _BOUNDARY_SEPARATORS = ("\n#", "\n\n", "\n");
}

"""A contiguous ``[start, end)`` character range of a splittable text file.

    ``index``/``total`` are for logging only. ``path`` is the real file on disk;
    the slice always reports ``path`` as its source so slices don't fragment the
    graph.
    """
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

"""The on-disk path a unit belongs to (the parent file for a slice)."""
def unit_path(unit: "Path | FileSlice | str") -> Path;

"""True for document types that may be sliced.

    Covers plain text read straight off disk and converted types (PDF) whose
    text is produced by a converter. Both are sliceable because
    :func:`unit_source_text` gives the slicing pass the same string the prompt
    will carry; what disqualifies a type is having no text at all (an image) or
    text the reader cannot address by character offset.
    """
def is_splittable_text(path: "Path | FileSlice | str") -> bool;

"""Return a cut index in ``(start, end]`` at the strongest nearby boundary.

    Searches the window ``text[start:end]`` for the latest heading, then blank
    line, then newline, and returns the index just *after* it (a heading cuts
    just *before* the ``#`` so the heading leads the next slice). Falls back to a
    hard cut at ``end`` when the window has no usable boundary, which still makes
    forward progress because ``end > start``.
    """
def _best_cut(text: str, start: int, end: int) -> int;

"""Contiguous ``(start, end)`` ranges covering all of ``text``, each ≤ max_chars.

    Ranges are gap-free and non-overlapping, so concatenating the slices
    reproduces ``text`` exactly — no content is dropped.
    """
def slice_boundaries(text: str, max_chars: int) -> list[tuple[int, int]];

"""Replace each oversized splittable-text file with a list of ``FileSlice``s.

    Files at or below ``max_chars`` (and all non-splittable files) pass through
    unchanged as ``Path``, so behaviour is identical for everything that already
    fit. Precomputed ``FileSlice`` inputs at or below ``max_chars`` pass through
    unchanged (#5106); oversized slices are further split. Unreadable files
    pass through untouched (the reader handles the error).
    """
def expand_oversized_files(
    files: "list[Path | FileSlice]", max_chars: int
) -> list["Path | FileSlice"];

"""Read just this slice's characters from its parent file.

    Goes through :func:`unit_source_text`, so a PDF slice indexes the extracted
    text rather than the container's bytes — the offsets `expand_oversized_files`
    computed and the string the prompt carries are then the same string (#2906).
    """
def read_slice_text(fs: FileSlice) -> str;

"""Split a slice into two halves at a newline near its midpoint, or None.

    Used by the adaptive-retry path when a single slice still overflows the
    model's output: halving it produces a smaller response. Returns None when the
    slice is already too small to split meaningfully.
    """
def bisect_slice(fs: FileSlice) -> tuple[FileSlice, FileSlice] | None;

"""Create a full-range ``FileSlice`` for an eligible splittable text file (#5072).

    Returns None for non-splittable files (code, binary, unreadable).
    """
def make_full_slice(path: "Path | FileSlice") -> FileSlice | None;

"""True when the given slices cover all of parent without gaps.

    Prevents incomplete precomputed slice inputs from being checkpointed or
    cached as a complete extraction of the parent file (#5106).
    """
def is_complete_slice_coverage(parent: "Path | str", slices: "Sequence[FileSlice]") -> bool;
