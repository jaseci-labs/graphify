"""Apex extractor. Moved verbatim from graphify/extract.py."""

import from __future__ { annotations }

import from pathlib { Path }

"""Extract classes, interfaces, enums, methods, and Salesforce constructs from
    Apex .cls and .trigger files using regex (no tree-sitter grammar on PyPI)."""
def extract_apex(path: Path) -> dict;
