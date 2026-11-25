import operator;
import from __future__ { annotations }
import from pathlib { Path }

import importlib;

import json;

import networkx as nx;

glob _html_escape: any;

glob MAX_NODES_FOR_VIZ: any;

glob _HTML_STALE_MARKER: any;

with entry {
    _html_escape = importlib.import_module("html").escape;

    MAX_NODES_FOR_VIZ = 5000;
    _HTML_STALE_MARKER = ".graph.html.stale";
}

def _viz_node_limit -> int;

def _html_styles -> str;

def _hyperedge_script(hyperedges_json: str) -> str;

def _html_script(nodes_json: str, edges_json: str, legend_json: str) -> str;
def _html_document_title(output_path: str) -> str;
def to_html(
    G: nx.Graph,
    communities: dict[int, list[str]],
    output_path: str,
    community_labels: dict[int, str] | None = None,
    member_counts: dict[int, int] | None = None,
    node_limit: int | None = None,
    learning_overlay: dict | None = None,
) -> bool;
