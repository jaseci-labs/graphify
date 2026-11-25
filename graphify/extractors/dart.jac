"""Dart extractor. Moved verbatim from graphify/extract.py."""

import operator;

import from __future__ { annotations }

import re;

import from pathlib { Path }

glob _TYPEDEF_LINE: any;

with entry {
    _TYPEDEF_LINE = re.compile("\\s*typedef\\b");
}

"""Extract classes, mixins, functions, imports, generic calls, and annotations from a .dart file using regex."""
def extract_dart(path: Path) -> dict;
