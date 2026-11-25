import importlib;
import operator;
import from __future__ { annotations }

import from datetime { date }

import json;

import from pathlib { Path }

import networkx as nx;
def _portable_root_label(`root: str) -> str;
def _safe_community_name(label: str) -> str;
def load_report_token_cost(graphify_out: Path) -> dict[str, int];
def load_learning_for_report(graph_path) -> dict | None;
def _learning_section(lines: list, learning: dict | None, top_n: int = 10);

def generate(
    G: nx.Graph,
    communities: dict[int, list[str]],
    cohesion_scores: dict[int, float],
    community_labels: dict[int, str],
    god_node_list: list[dict],
    surprise_list: list[dict],
    detection_result: dict,
    token_cost: dict,
    `root: str,
    suggested_questions: list[dict] | None = None,
    min_community_size: int = 3,
    built_at_commit: str | None = None,
    learning: dict | None = None,
    obsidian: bool = False,
) -> str;
