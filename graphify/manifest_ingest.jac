"""Deterministic package-manifest ingestion (#1377).

Package manifests (``apm.yml``, ``pyproject.toml``, ``Cargo.toml``, ``go.mod``,
``pom.xml``) declare a package and its dependencies. Left to the LLM document path, the same
package gets a different file-anchored node id from its own manifest than from
each dependent's dependency reference, so it splits into duplicate nodes. This
module parses manifests deterministically and emits ONE canonical package node
per package -- keyed by NAME via :func:`graphify.ids.make_id` -- plus
``depends_on`` edges, so a package referenced from N manifests collapses to a
single hub node (the dependency stub and the package's own definition node share
the canonical id and merge at build time).

Mirrors ``mcp_ingest``: recognized by filename, routed to the deterministic AST
path (never the LLM), so a manifest is extracted exactly once.
"""

import from __future__ { annotations }

import re;

import xml.etree.ElementTree as ET;

import from pathlib { Path }

import from typing { Any }

glob __all__: any = [
    "is_package_manifest_path",
    "extract_package_manifest",
    "PACKAGE_MANIFEST_NAMES",
];

glob PACKAGE_MANIFEST_NAMES: dict[str, str];

glob _MAX_MANIFEST_BYTES: any;

glob _TOMLI_REQUIRED: any;

glob _PARSERS: any;

with entry {
    PACKAGE_MANIFEST_NAMES = {
        "apm.yml": "apm",
        "apm.yaml": "apm",
        "pyproject.toml": "python",
        "cargo.toml": "cargo",
        "go.mod": "go",
        "pom.xml": "maven",
    };

    _MAX_MANIFEST_BYTES = 2000000;

    _TOMLI_REQUIRED = "Package-manifest ingestion on Python < 3.11 needs tomli. Install with: pip install 'tomli' (or reinstall graphifyy, which declares tomli for python_version < '3.11').";
}

"""Return a tomllib-compatible module, or raise ImportError (#3283).

    Returning ``None`` used to look identical to a virtual workspace root with
    nothing to emit, so missing ``tomli`` on Python 3.10 silently dropped every
    ``Cargo.toml`` / ``pyproject.toml``. Raise instead: the caller
    (``extract_package_manifest``) surfaces this as a visible per-manifest error
    rather than dropping the file silently. In practice the runtime ``tomli``
    dependency (python_version < '3.11') keeps this path unreachable for a
    standard install.
    """
def _load_toml_module -> any;

"""True if ``path`` is a recognized package manifest (by filename)."""
def is_package_manifest_path(path: Path) -> bool;

"""Canonical package node id, keyed by package NAME so every reference to the
    same package -- its own manifest and any dependent's dependency line -- maps
    to one node."""
def _pkg_id(name: str) -> str;

"""Parse a package manifest into a canonical package node + ``depends_on`` edges."""
def extract_package_manifest(path: Path) -> dict[str, Any];

"""A dependency block may be a list of names or a name->spec map."""
def _coerce_deps(value: Any) -> list[str];

def _parse_apm(text: str) -> dict | None;

"""Minimal line parser for apm.yml when PyYAML is unavailable: a top-level
    ``name:``/``version:`` plus a simple ``dependencies:`` block (list items or
    a name map)."""
def _parse_apm_fallback(text: str) -> dict | None;

"""`requests>=2.0` -> `requests`; `pkg[extra]==1; python_version<'3.9'` -> `pkg`."""
def _pep508_name(spec: str) -> str;

def _parse_pyproject(text: str) -> dict | None;

"""Cargo.toml: name/version from ``[package]``, runtime deps from
    ``[dependencies]`` plus every ``[target.<cfg>.dependencies]`` table (mirrors
    ``_parse_pyproject``'s runtime-only scope; dev-/build-dependencies excluded)."""
def _parse_cargo(text: str) -> dict | None;

def _parse_gomod(text: str) -> dict | None;

def _parse_pom(text: str) -> dict | None;

with entry {
    _PARSERS = {
        "apm": _parse_apm,
        "python": _parse_pyproject,
        "cargo": _parse_cargo,
        "go": _parse_gomod,
        "maven": _parse_pom,
    };
}
