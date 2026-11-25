"""
callflow_html.py — Generate call-flow architecture HTML from graphify knowledge graph outputs.

Reads graph.json plus optional GRAPH_REPORT.md, .graphify_labels.json, and sections JSON,
then produces a self-contained HTML file with:
  - Dark-themed CSS (fixed template)
  - Navigation bar from section list
  - Architecture overview flowchart LR (aggregated section-level edges)
  - Per-section flowchart LR (auto-generated representative intra-section edges)
  - Call detail table scaffolding (headers + representative node rows)
  - Auto-generated section intros and key-file cards

Usage:
  python3 -m graphify export callflow-html
  python3 -m graphify export callflow-html /path/to/project/graphify-out/graph.json
  python3 -m graphify export callflow-html --graph /path/to/graph.json --output docs/architecture.html
"""

import importlib;
import builtins;

import operator;

import from __future__ { annotations }

import json;

import argparse;

import os;

import re;

import sys;

import hashlib;

import from pathlib { Path }

import from collections { Counter, defaultdict }

import from datetime { datetime, timezone }

import from html { escape }

glob CSS: any = ":root {\n  --bg: #0f172a; --surface: #1e293b; --border: #334155;\n  --text: #e2e8f0; --muted: #94a3b8; --accent: #38bdf8;\n  --warn: #fbbf24; --err: #f87171; --ok: #34d399;\n}\n* { box-sizing: border-box; margin: 0; padding: 0; }\nbody { font-family: 'Segoe UI', system-ui, -apple-system, sans-serif; background: var(--bg); color: var(--text); line-height: 1.7; }\n.container { max-width: 1200px; margin: 0 auto; padding: 40px 24px; }\nh1 { font-size: 2.4rem; margin-bottom: 8px; background: linear-gradient(135deg, var(--accent), #a78bfa); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }\nh2 { font-size: 1.7rem; margin: 48px 0 16px; padding-bottom: 8px; border-bottom: 2px solid var(--accent); }\nh3 { font-size: 1.25rem; margin: 32px 0 12px; color: var(--accent); }\nh4 { font-size: 1.05rem; margin: 20px 0 8px; color: var(--warn); }\np { margin: 8px 0; color: var(--muted); }\n.subtitle { color: var(--muted); font-size: 1.1rem; margin-bottom: 32px; }\n.mermaid { background: var(--surface); border: 1px solid var(--border); border-radius: 12px; padding: 24px; margin: 20px 0; overflow-x: auto; position: relative; }\n.mermaid.is-enhanced { padding: 0; overflow: hidden; min-height: 260px; }\n.mermaid-viewport { padding: 54px 24px 24px; overflow: hidden; cursor: grab; touch-action: none; min-height: 260px; }\n.mermaid-viewport.is-dragging { cursor: grabbing; }\n.mermaid-viewport svg { max-width: none !important; height: auto; transform-origin: 0 0; transition: transform 120ms ease; }\n.mermaid-toolbar { position: absolute; top: 10px; right: 10px; z-index: 3; display: flex; align-items: center; gap: 6px; padding: 6px; background: rgba(15,23,42,0.92); border: 1px solid var(--border); border-radius: 8px; box-shadow: 0 8px 24px rgba(0,0,0,0.28); }\n.mermaid-toolbar button, .mermaid-toolbar .zoom-level { height: 28px; min-width: 32px; border: 1px solid var(--border); border-radius: 6px; background: #1e293b; color: var(--text); font: 600 0.78rem system-ui, sans-serif; display: inline-flex; align-items: center; justify-content: center; }\n.mermaid-toolbar button { cursor: pointer; }\n.mermaid-toolbar button:hover { border-color: var(--accent); color: var(--accent); }\n.mermaid-toolbar .zoom-level { min-width: 52px; color: var(--muted); background: transparent; }\n.call-table { width: 100%; border-collapse: collapse; margin: 16px 0; font-size: 0.92rem; }\n.call-table th { background: #1a2744; color: var(--accent); text-align: left; padding: 10px 14px; border: 1px solid var(--border); }\n.call-table td { padding: 8px 14px; border: 1px solid var(--border); vertical-align: top; }\n.call-table tr:nth-child(even) { background: rgba(255,255,255,0.02); }\n.tag { display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 0.8rem; font-weight: 600; }\n.tag-async { background: #7c3aed33; color: #a78bfa; }\n.tag-class { background: #05966933; color: var(--ok); }\n.tag-func { background: #2563eb33; color: var(--accent); }\n.tag-cmd { background: #d9770633; color: var(--warn); }\n.tag-endpoint { background: #dc262633; color: var(--err); }\n.tag-hook { background: #db277733; color: #f472b6; }\n.card { background: var(--surface); border: 1px solid var(--border); border-radius: 10px; padding: 20px; margin: 16px 0; }\n.grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(340px, 1fr)); gap: 16px; margin: 16px 0; }\n.arrow-chain { font-family: 'Fira Code', monospace; font-size: 0.85rem; color: var(--accent); padding: 10px; background: rgba(56,189,248,0.06); border-radius: 6px; }\ncode { font-family: 'Fira Code', 'Cascadia Code', monospace; background: rgba(255,255,255,0.06); padding: 1px 6px; border-radius: 3px; font-size: 0.88em; }\nul, ol { margin: 8px 0 8px 24px; color: var(--muted); }\nli { margin: 4px 0; }\na { color: var(--accent); }\nhr { border: none; border-top: 1px solid var(--border); margin: 40px 0; }\n.nav { position: sticky; top: 0; background: var(--bg); z-index: 10; padding: 12px 0; border-bottom: 1px solid var(--border); display: flex; gap: 20px; flex-wrap: wrap; font-size: 0.9rem; }\n.nav a { text-decoration: none; }\n.nav a:hover { text-decoration: underline; }\n@media (max-width: 768px) { .container { padding: 16px; } h1 { font-size: 1.8rem; } }\n";

"""Read JSON with a useful error message."""
def read_json(path: str | Path, `default=None) -> any;

"""Return the first non-empty value for any candidate key."""
def first_present(mapping: dict, *keys_, `default=None) -> any;

"""Return the first list from a set of possible schema locations."""
def first_list(*values_) -> list;

"""Convert graph numeric fields that may be serialized as strings."""
def to_float(value, `default: float = 0.0) -> float;

"""Normalize edge endpoints that may be strings or node-like objects."""
def endpoint_id(value) -> str;

"""Normalize a graphify node across common graph.json schema variants."""
def normalize_node(raw: dict, index: int) -> dict;

"""Normalize graphify edges while preserving original fields."""
def normalize_edge(raw: dict, index: int) -> dict | None;

"""Read current graphify graph.json via NetworkX's node-link parser."""
def _node_link_payload(data: dict) -> tuple[list, list] | None;

"""Load graph.json. Returns normalized (nodes, edges, hyperedges, metadata)."""
def load_graph(path: str | Path) -> tuple;

"""Load community labels from .graphify_labels.json, tolerating wrapper keys."""
def load_labels(path: str | Path | None) -> dict;

"""Load section definitions from JSON file."""
def load_sections(path: str | Path | None) -> list;

"""Load GRAPH_REPORT.md if it exists."""
def load_report(path: str | Path | None) -> str;

"""Sanitize text for use inside a Mermaid node label.

    Replaces characters that Mermaid interprets as syntax:
    - -> (edge arrow) -> text
    - # (comment) -> removed
    - {} (shape syntax) -> removed
    - backticks -> removed
    - " -> '
    - HTML metacharacters -> entities
    """
def safe_mermaid_text(text: str) -> str;

"""Keep generated HTML comments well-formed."""
def html_comment_text(text: str) -> str;

"""Build a Mermaid-safe ASCII identifier with a hash suffix to avoid collisions."""
def stable_ascii_id(raw: str, prefix: str = "node", limit: int = 48) -> str;

"""Generate a safe Mermaid node ID from a graph node.

    Mermaid IDs must match [a-zA-Z][a-zA-Z0-9_]* — no dots, hyphens, slashes.
    """
def node_mermaid_id(`node: dict) -> str;

"""Convert a section ID (like 'cli-entry') to a safe Mermaid ID (like 'CLI_ENTRY')."""
def mermaid_section_id(section_id: str) -> str;

"""Return a short, safe display path."""
def safe_file_path(path: str) -> str;

"""Create a conservative filename stem from a project name."""
def safe_filename(text: str, fallback: str = "project") -> str;

"""Infer a display project name when graph metadata does not include one."""
def infer_project_name(graph_path: str, meta: dict) -> str;

"""Resolve project root, graphify output dir, and optional files."""
def resolve_graphify_paths(args) -> dict;

"""Return true when localized strings should be Chinese."""
def is_zh(lang: str) -> bool;

"""Small localization helper for generated copy."""
def pick_text(lang: str, zh: str, en: str) -> str;

"""Resolve auto language from labels and node names."""
def detect_lang(lang: str, nodes: list, labels: dict) -> str;

"""Truncate without splitting Mermaid syntax."""
def truncate_text(text: str, limit: int) -> str;

"""Convert graph labels into short labels people can scan in a diagram."""
def humanize_label(label: str, source_file: str = "") -> str;

"""Classify a graph node for Mermaid styling and table tags."""
def node_kind(`node: dict) -> str;

"""Map graph edge relation names to short diagram labels."""
def relation_label(relation: str, lang: str) -> str;

"""Filter to edges that make a readable call-flow diagram."""
def preferred_edges(edges: list, allow_structure: bool = False) -> list;

"""Rank edges by confidence and usefulness for diagrams."""
def edge_score(`edge: dict) -> float;

"""Return a Mermaid init directive that scales diagrams using Mermaid config."""
def mermaid_init(scale: float, direction: str = "LR") -> str;

"""Shared Mermaid-native styles for readable diagrams."""
def mermaid_class_defs -> list;

"""Map community_id (str) -> list of nodes."""
def build_community_index(nodes: list) -> dict;

"""Generate a stable, unique HTML anchor ID."""
def html_anchor_id(raw: str, fallback: str, used: set) -> str;

"""Normalize section community lists from JSON or simple strings."""
def normalize_communities(value) -> list;

"""Ensure sections have safe unique IDs and an overview section first."""
def normalize_sections(sections: list, lang: str) -> list;

"""Choose a readable section name for a community."""
def label_for_community(cid: str, labels: dict, nodes: list, lang: str) -> str;

glob SECTION_ARCHETYPES: any = [
    (
        "extract-pipeline",
        "提取管线",
        "Extraction Pipeline",
        {
            "extract",
            "extractor",
            "tree",
            "sitter",
            "parser",
            "language",
            "python",
            "javascript",
            "typescript",
            "rust",
            "java",
            "go",
            "ast",
            "calls",
            "imports",
            "multilang",
        },
    ),
    (
        "build-graph",
        "图谱构建",
        "Graph Build",
        {
            "build",
            "graph",
            "merge",
            "dedup",
            "node",
            "edge",
            "hyperedge",
            "json",
            "schema",
            "normalize",
            "confidence",
        },
    ),
    (
        "analysis-clustering",
        "分析聚类",
        "Analysis & Clustering",
        {
            "cluster",
            "community",
            "leiden",
            "cohesion",
            "analyze",
            "god",
            "surprise",
            "question",
            "query",
            "path",
            "explain",
            "benchmark",
        },
    ),
    (
        "outputs-docs",
        "输出文档",
        "Outputs & Docs",
        {
            "export",
            "html",
            "wiki",
            "obsidian",
            "canvas",
            "svg",
            "graphml",
            "report",
            "callflow",
            "mermaid",
            "tree",
            "documentation",
        },
    ),
    (
        "cli-skills",
        "CLI 与技能安装",
        "CLI & Skill Installers",
        {
            "main",
            "install",
            "uninstall",
            "skill",
            "agent",
            "claude",
            "codex",
            "opencode",
            "aider",
            "copilot",
            "kiro",
            "vscode",
            "hook",
            "command",
        },
    ),
    (
        "ingest-cache-update",
        "摄取与增量更新",
        "Ingestion & Updates",
        {
            "ingest",
            "fetch",
            "download",
            "url",
            "html",
            "markdown",
            "cache",
            "manifest",
            "watch",
            "update",
            "incremental",
            "transcribe",
            "video",
            "audio",
            "google",
        },
    ),
    (
        "serve-api",
        "服务 API",
        "Serving API",
        {
            "serve",
            "api",
            "request",
            "response",
            "endpoint",
            "router",
            "handle",
            "upload",
            "search",
            "delete",
            "enrich",
        },
    ),
    (
        "security-global",
        "安全与全局图",
        "Security & Global Graph",
        {
            "security",
            "safe",
            "ssrf",
            "xss",
            "path",
            "traversal",
            "global",
            "prefix",
            "prune",
            "repo",
            "clone",
        },
    ),
    (
        "tests-fixtures",
        "测试与样例",
        "Tests & Fixtures",
        {"test", "tests", "fixture", "fixtures", "sample", "assert", "pytest", "mock"},
    ),
];

def _community_text(nodes: list, label: str = "") -> str;

def _keyword_score(text: str, keywords: set[str]) -> int;

"""Return selected grouped sections and overflow communities."""
def _rank_grouped_sections(grouped: dict, max_sections: int) -> tuple[list, list];

"""Derive architecture-oriented sections when no sections JSON is supplied."""
def derive_sections_from_communities(
    nodes: list, labels: dict, lang: str, max_sections: int
) -> list;

"""Map section_id -> list of nodes belonging to its communities."""
def build_section_node_map(sections: list, comm_idx: dict) -> dict;

"""Check if a node belongs to a section."""
def node_in_section(node_id: str, section_node_ids: set) -> bool;

"""Classify edges as intra-section or inter-section.

    Returns:
        {
            "intra": {section_id: [edges]},
            "inter": [edges],
            "orphan": [edges]  # one endpoint not in any section
        }
    """
def classify_edges(edges: list, section_nodes_map: dict) -> dict;

"""Decide whether to auto-include an edge in Mermaid output."""
def should_include_edge(`edge: dict) -> bool;

"""Score nodes by useful edge participation."""
def node_degree_scores(edges: list) -> Counter;

"""Use graphify centrality fields when available."""
def node_importance(`node: dict) -> float;

"""Select a compact, connected subset of nodes for readable diagrams."""
def select_diagram_nodes(nodes: list, edges: list, max_nodes: int) -> list;

"""Build a readable Mermaid node label."""
def node_label(`node: dict) -> str;

"""Group selected nodes by source file for Mermaid subgraphs."""
def group_nodes_by_file(nodes: list) -> dict;

"""Aggregate inter-section edge counts and relation names."""
def section_edge_summary(classified_edges: dict) -> dict;

"""Generate a readable section-level architecture overview."""
def generate_overview_graph(
    sections: list,
    section_nodes_map: dict,
    classified_edges: dict,
    labels: dict,
    lang: str,
    diagram_scale: float,
) -> str;

"""Generate a compact, human-readable call-flow chart for a section."""
def generate_section_flowchart(
    section_id: str,
    section_name: str,
    nodes: list,
    edges: list,
    lang: str,
    diagram_scale: float,
    max_nodes: int,
    max_edges: int,
) -> str;

"""Generate the sticky navigation bar."""
def generate_nav(sections: list) -> str;

"""Readable node label for tables and summaries."""
def node_display_name(`node: dict | None, fallback: str = "") -> str;

"""Render node references as readable labels instead of internal IDs."""
def format_node_refs(
    node_ids: set, node_by_id: dict, lang: str, empty_text: str, limit: int = 3
) -> str;

"""Generate call table row scaffolding for a section's nodes.

    The Caller/Callee columns make a claim about the whole graph ("External
    entry / no inbound edge"), so they must be computed from the whole graph.
    Built from ``section_edges`` alone they only see edges whose *both*
    endpoints sit in this section, so a node called from anywhere else is
    mislabelled an entry point. Section coverage makes that the common case
    rather than a corner case: only ``max_sections`` communities are rendered,
    so most callers are not in any rendered section at all.

    ``all_edges``/``all_nodes`` are the full graph; ``all_nodes`` also lets
    out-of-section callers render as labels instead of raw node ids. Both
    default to None, preserving the previous behaviour for other callers.
    """
def generate_call_table_rows(
    nodes: list,
    section_edges: list,
    lang: str,
    all_edges: list | None = None,
    all_nodes: list | None = None,
) -> str;

"""Heuristic tag suggestion based on label name and file type."""
def _suggest_tag(label: str, file_type: str, lang: str, kind: str = "") -> str;

"""Generate a compact human-readable description for a graph node."""
def _describe_node(label: str, source_file: str, file_type: str, lang: str) -> str;

"""Generate the HTML header, title, subtitle, and nav."""
def generate_header(sections: list, meta: dict, lang: str) -> str;

"""Derive a readable section flow from inter-section edges."""
def derive_flow_chain(sections: list, classified_edges: dict) -> str;

"""Generate generic overview cards."""
def generate_overview_cards(
    meta: dict,
    report_text: str,
    sections: list,
    section_nodes_map: dict,
    classified_edges: dict,
    lang: str,
) -> str;

"""Pick representative words from labels and file names."""
def section_keywords(nodes: list, limit: int = 5) -> list;

"""Generate the section introductory paragraph."""
def generate_section_intro(sec: dict, nodes: list, edge_count: int, lang: str) -> str;

"""Generate key file and design-note cards for a section."""
def generate_section_cards(sec: dict, nodes: list, section_edges: list, lang: str) -> str;

"""Options for call-flow architecture HTML generation."""
obj CallflowOptions {
    has project: any,
        graphify_out: any,
        `graph: any,
        `report: any,
        labels: any,
        sections: any,
        output: any,
        lang: any,
        max_sections: any,
        diagram_scale: any,
        max_diagram_nodes: any,
        max_diagram_edges: any;

    def init(
        project: str | Path | None = None,
        *,
        graphify_out: str | Path | None = None,
        `graph: str | Path | None = None,
        `report: str | Path | None = None,
        labels: str | Path | None = None,
        sections: str | Path | None = None,
        output: str | Path | None = None,
        lang: str = "auto",
        max_sections: int = 15,
        diagram_scale: float = 1.0,
        max_diagram_nodes: int = 18,
        max_diagram_edges: int = 24,
    );

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""Extract a compact highlights card from GRAPH_REPORT.md."""
def _report_highlights(report_text: str, lang: str) -> str;

"""Generate call-flow architecture HTML from graphify output files."""
def write_callflow_html(
    project: str | Path | None = None,
    *,
    graphify_out: str | Path | None = None,
    `graph: str | Path | None = None,
    `report: str | Path | None = None,
    labels: str | Path | None = None,
    sections: str | Path | None = None,
    output: str | Path | None = None,
    lang: str = "auto",
    max_sections: int = 15,
    diagram_scale: float = 1.0,
    max_diagram_nodes: int = 18,
    max_diagram_edges: int = 24,
    verbose: bool = False,
) -> Path;

def main -> any;

with entry:__main__ {
    main();
}
