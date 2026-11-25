"""Sln extractor. Moved verbatim from graphify/extract.py."""

import operator;

import from __future__ { annotations }

import re;

import from pathlib { Path }

"""Extract projects and inter-project dependencies from a .sln file."""
def extract_sln(path: Path) -> dict;
