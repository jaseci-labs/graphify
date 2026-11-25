import from __future__ { annotations }

import importlib;
import json;

import hashlib;

import sys;

import from datetime { datetime, timezone }

import from pathlib { Path }

import networkx as nx;

import from networkx.readwrite { json_graph as _jg }

glob _GLOBAL_DIR: any;

glob _GLOBAL_GRAPH: any;

glob _GLOBAL_MANIFEST: any;

with entry {
    _GLOBAL_DIR = Path.home() / ".graphify";
    _GLOBAL_GRAPH = _GLOBAL_DIR / "global-graph.json";
    _GLOBAL_MANIFEST = _GLOBAL_DIR / "global-manifest.json";
}

def _load_manifest -> dict;

def _save_manifest(manifest: dict) -> None;

def _load_global_graph -> nx.Graph;

def _save_global_graph(G: nx.Graph) -> None;

def _file_hash(path: Path) -> str;

"""Add or update a project graph in the global graph.

    Returns a summary dict with keys: repo_tag, nodes_added, nodes_removed, skipped,
    cross_repo_calls.
    Skipped=True means the source graph hasn't changed since last add.
    """
def global_add(source_path: Path, repo_tag: str) -> dict;

"""Remove all nodes for repo_tag from the global graph. Returns count removed."""
def global_remove(repo_tag: str) -> int;

"""Return the manifest repos dict."""
def global_list -> dict;

def global_path -> Path;
