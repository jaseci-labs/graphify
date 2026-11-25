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
def google_workspace_enabled(value: str | None = None) -> bool;
def _safe_yaml_str(value: str) -> str;
def _extract_file_id_from_url(url: str) -> str | None;

def _extract_resource_key(url: str, data: dict[str, Any]) -> str | None;
def read_google_shortcut(path: Path) -> dict[str, str | None];

def _run_gws_export(file_id: str, mime_type: str, output: Path, resource_key: str | None = None);

def _sidecar_path(path: Path, out_dir: Path, `root: "Path | None" = None) -> Path;

def _with_frontmatter(
    path: Path, shortcut: dict[str, str | None], body: str, exported_mime_type: str
) -> str;
def convert_google_workspace_file(
    path: Path,
    out_dir: Path,
    *,
    xlsx_to_markdown: Callable[[Path], str] | None = None,
    `root: "Path | None" = None,
) -> Path | None;
