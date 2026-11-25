"""Optional Google Workspace shortcut export support.

Google Drive for desktop stores native Docs, Sheets, and Slides as small JSON
shortcut files (.gdoc, .gsheet, .gslides). Those files are pointers, not the
document content. This module exports them to Markdown sidecars via the
googleworkspace CLI (`gws`) so Graphify can extract their actual contents.
"""

import from __future__ { annotations }

import hashlib;

import json;

import os;

import re;

import shutil;

import subprocess;

import tempfile;

import urllib.parse;

import from pathlib { Path }

import from typing { Callable, Any }

glob GOOGLE_WORKSPACE_EXTENSIONS: any = {".gdoc", ".gsheet", ".gslides"};

"""Return True when Google Workspace shortcut export is enabled."""
def google_workspace_enabled(value: str | None = None) -> bool;

"""Escape a value for a YAML double-quoted scalar.

    Same escaping as graphify.ingest._yaml_str (F-009): backslash, quote,
    tab, NUL and other C0/DEL controls, plus the Unicode line breaks
    U+2028, U+2029 and U+0085, so a hostile shortcut url or file id cannot
    break out of the scalar and inject sibling frontmatter keys.
    """
def _safe_yaml_str(value: str) -> str;

"""Extract a Drive file ID from common Google Docs/Drive URL shapes."""
def _extract_file_id_from_url(url: str) -> str | None;

def _extract_resource_key(url: str, data: dict[str, Any]) -> str | None;

"""Read a .gdoc/.gsheet/.gslides shortcut and return export metadata."""
def read_google_shortcut(path: Path) -> dict[str, str | None];

def _run_gws_export(
    file_id: str, mime_type: str, output: Path, resource_key: str | None = None
) -> None;

def _sidecar_path(path: Path, out_dir: Path, `root: "Path | None" = None) -> Path;

def _with_frontmatter(
    path: Path, shortcut: dict[str, str | None], body: str, exported_mime_type: str
) -> str;

"""Export a Google Workspace shortcut to a Markdown sidecar.

    Returns the converted Markdown path, or None when conversion is unsupported
    or produced no readable content.
    """
def convert_google_workspace_file(
    path: Path,
    out_dir: Path,
    *,
    xlsx_to_markdown: Callable[[Path], str] | None = None,
    `root: "Path | None" = None,
) -> Path | None;
