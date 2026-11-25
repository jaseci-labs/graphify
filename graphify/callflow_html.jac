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
def read_json(path: str | Path, `default=None) -> any;
def first_present(mapping: dict, *keys_, `default=None) -> any;
def first_list(*values_) -> list;
def to_float(value, `default: float = 0.0) -> float;
def endpoint_id(value) -> str;
def normalize_node(raw: dict, index: int) -> dict;
def normalize_edge(raw: dict, index: int) -> dict | None;
def _node_link_payload(data: dict) -> tuple[list, list] | None;
def load_graph(path: str | Path) -> tuple;
def load_labels(path: str | Path | None) -> dict;
def load_sections(path: str | Path | None) -> list;
def load_report(path: str | Path | None) -> str;
def safe_mermaid_text(text: str) -> str;
def html_comment_text(text: str) -> str;
def stable_ascii_id(raw: str, prefix: str = "node", limit: int = 48) -> str;
def node_mermaid_id(`node: dict) -> str;
def mermaid_section_id(section_id: str) -> str;
def safe_file_path(path: str) -> str;
def safe_filename(text: str, fallback: str = "project") -> str;
def infer_project_name(graph_path: str, meta: dict) -> str;
def resolve_graphify_paths(args) -> dict;
def is_zh(lang: str) -> bool;
def pick_text(lang: str, zh: str, en: str) -> str;
def detect_lang(lang: str, nodes: list, labels: dict) -> str;
def truncate_text(text: str, limit: int) -> str;
def humanize_label(label: str, source_file: str = "") -> str;
def node_kind(`node: dict) -> str;
def relation_label(relation: str, lang: str) -> str;
def preferred_edges(edges: list, allow_structure: bool = False) -> list;
def edge_score(`edge: dict) -> float;
def mermaid_init(scale: float, direction: str = "LR") -> str;
def mermaid_class_defs -> list;
def build_community_index(nodes: list) -> dict;
def html_anchor_id(raw: str, fallback: str, used: set) -> str;
def normalize_communities(value) -> list;
def normalize_sections(sections: list, lang: str) -> list;
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
def _rank_grouped_sections(grouped: dict, max_sections: int) -> tuple[list, list];
def derive_sections_from_communities(
    nodes: list, labels: dict, lang: str, max_sections: int
) -> list;
def build_section_node_map(sections: list, comm_idx: dict) -> dict;
def node_in_section(node_id: str, section_node_ids: set) -> bool;
def classify_edges(edges: list, section_nodes_map: dict) -> dict;
def should_include_edge(`edge: dict) -> bool;
def node_degree_scores(edges: list) -> Counter;
def node_importance(`node: dict) -> float;
def select_diagram_nodes(nodes: list, edges: list, max_nodes: int) -> list;
def node_label(`node: dict) -> str;
def group_nodes_by_file(nodes: list) -> dict;
def section_edge_summary(classified_edges: dict) -> dict;
def generate_overview_graph(
    sections: list,
    section_nodes_map: dict,
    classified_edges: dict,
    labels: dict,
    lang: str,
    diagram_scale: float,
) -> str;
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
def generate_nav(sections: list) -> str;
def node_display_name(`node: dict | None, fallback: str = "") -> str;
def format_node_refs(
    node_ids: set, node_by_id: dict, lang: str, empty_text: str, limit: int = 3
) -> str;
def generate_call_table_rows(
    nodes: list,
    section_edges: list,
    lang: str,
    all_edges: list | None = None,
    all_nodes: list | None = None,
) -> str;
def _suggest_tag(label: str, file_type: str, lang: str, kind: str = "") -> str;
def _describe_node(label: str, source_file: str, file_type: str, lang: str) -> str;
def generate_header(sections: list, meta: dict, lang: str) -> str;
def derive_flow_chain(sections: list, classified_edges: dict) -> str;
def generate_overview_cards(
    meta: dict,
    report_text: str,
    sections: list,
    section_nodes_map: dict,
    classified_edges: dict,
    lang: str,
) -> str;
def section_keywords(nodes: list, limit: int = 5) -> list;
def generate_section_intro(sec: dict, nodes: list, edge_count: int, lang: str) -> str;
def generate_section_cards(sec: dict, nodes: list, section_edges: list, lang: str) -> str;

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

def _report_highlights(report_text: str, lang: str) -> str;
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
