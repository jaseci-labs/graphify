"""julia — moved verbatim from graphify/extract.py."""

import from __future__ { annotations }

import from pathlib { Path }

"""Extract modules, structs, functions, imports, and calls from a .jl file."""
def extract_julia(path: Path) -> dict;
