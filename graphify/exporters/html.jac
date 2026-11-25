"""html — moved verbatim from graphify/export.py."""

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

"""Return the effective viz node limit, honoring GRAPHIFY_VIZ_NODE_LIMIT env var.

    Falls back to MAX_NODES_FOR_VIZ when the env var is unset, empty, or non-integer.
    Set to 0 to disable HTML viz unconditionally (useful for CI runners).
    """
def _viz_node_limit -> int;

def _html_styles -> str;

def _hyperedge_script(hyperedges_json: str) -> str;

def _html_script(nodes_json: str, edges_json: str, legend_json: str) -> str;

"""Return a portable label for the graph.html <title>.

    Tracked artifacts must not embed the generator host absolute path
    (regression of #433; reported again as #2598 on Windows). Keep from the
    configured output-dir bare name (``graphify-out`` / ``GRAPHIFY_OUT``
    basename) onward — portable in every case; otherwise fall back to a
    cwd-relative label, and finally the filename only.
    """
def _html_document_title(output_path: str) -> str;

"""Generate an interactive vis.js HTML visualization of the graph.

    Features: node size by degree, click-to-inspect panel, search box,
    community filter, physics clustering by community, confidence-styled edges.
    Raises ValueError if graph exceeds MAX_NODES_FOR_VIZ.

    If member_counts is provided (aggregated community view), node sizes are
    based on community member counts rather than graph degree.

    If node_limit is set and the graph exceeds it, automatically builds an
    aggregated community-level meta-graph instead of raising ValueError.

    Returns True when the output was written. Returns False when an aggregated
    view would contain fewer than two communities and is intentionally skipped.
    """
def to_html(
    G: nx.Graph,
    communities: dict[int, list[str]],
    output_path: str,
    community_labels: dict[int, str] | None = None,
    member_counts: dict[int, int] | None = None,
    node_limit: int | None = None,
    learning_overlay: dict | None = None,
) -> bool;
