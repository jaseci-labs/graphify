"""ASP.NET Razor component extractor. Moved verbatim from graphify/extract.py."""

import from __future__ { annotations }

import re;

import from pathlib { Path }

"""Extract directives, component refs, and @code/@functions methods from .razor/.cshtml."""
def extract_razor(path: Path) -> dict;
