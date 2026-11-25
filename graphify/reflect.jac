import operator;
import from __future__ { annotations }

import json;

import re;

import from collections { Counter }

import from datetime { datetime, timezone }

import from pathlib { Path }

import from typing { Any }

glob _UNCATEGORIZED: any = "Uncategorized";

glob LEARNING_SIDECAR_NAME: any = ".graphify_learning.json";

glob _LEARNING_SCHEMA_VERSION: any = 1;

glob _PROVENANCE_CAP: any = 5;

glob _DEFAULT_HALF_LIFE_DAYS: any = 30.0;

glob _DEFAULT_MIN_CORROBORATION: any = 2;

glob _SCORE_NDIGITS: any = 9;

glob _SCALAR_RE: any;

glob _LIST_RE: any;

glob _DQ_ITEM_RE: any;

with entry {
    _SCALAR_RE = re.compile("^([A-Za-z_][\\w-]*):\\s*\"(.*)\"\\s*$");
    _LIST_RE = re.compile("^([A-Za-z_][\\w-]*):\\s*\\[(.*)\\]\\s*$");
    _DQ_ITEM_RE = re.compile("\"((?:[^\"\\\\]|\\\\.)*)\"");
}

def _yaml_unescape(s: str) -> str;
def parse_memory_doc(text: str) -> dict[str, Any] | None;
def load_memory_docs(memory_dir: Path) -> list[dict[str, Any]];
def _load_node_community(graph_path: Path, analysis_path: Path, labels_path: Path) -> dict[str, str]
    | None;
def _load_known_nodes(graph_path: Path) -> set[str] | None;
def _doc_community(nodes: list[str], node_community: dict[str, str] | None) -> str;
def _parse_dt(date_str: str) -> datetime | None;
def _decay(date_str: str, now: datetime, half_life_days: float) -> float;

def _empty_bucket -> dict[str, Any];

def _record_node(
    bucket: dict[str, Any],
    `node: str,
    sign: int,
    weight: float,
    date: str,
    *,
    outcome: str | None = None,
    question: str = "",
);
def _finalize_sources(bucket: dict[str, Any], min_corroboration: int) -> dict[str, list];
def _dedupe_by_question(items: list[dict[str, Any]]) -> list[dict[str, Any]];

glob half_life_days_default_: any;

glob min_corroboration_default_: any;

with entry {
    half_life_days_default_ = _DEFAULT_HALF_LIFE_DAYS;
    min_corroboration_default_ = _DEFAULT_MIN_CORROBORATION;
}

def aggregate_lessons(
    docs: list[dict[str, Any]],
    node_community: dict[str, str] | None = None,
    *,
    now: datetime | None = None,
    half_life_days: float = half_life_days_default_,
    min_corroboration: int = min_corroboration_default_,
    known_nodes: set[str] | None = None,
) -> dict[str, Any];

def _render_bucket(out: list[str], data: dict[str, Any], k: int);
def render_lessons_md(agg: dict[str, Any]) -> str;
def lessons_fresh(
    out_path: Path,
    memory_dir: Path,
    graph_path: Path | None = None,
    analysis_path: Path | None = None,
    labels_path: Path | None = None,
) -> bool;

glob half_life_days_default__: any;

glob min_corroboration_default__: any;

with entry {
    half_life_days_default__ = _DEFAULT_HALF_LIFE_DAYS;
    min_corroboration_default__ = _DEFAULT_MIN_CORROBORATION;
}

def reflect(
    memory_dir: Path,
    out_path: Path,
    graph_path: Path | None = None,
    analysis_path: Path | None = None,
    labels_path: Path | None = None,
    *,
    now: datetime | None = None,
    half_life_days: float = half_life_days_default__,
    min_corroboration: int = min_corroboration_default__,
) -> tuple[Path, dict[str, Any]];
def _build_id_label_maps(
    graph_path: Path
) -> tuple[dict[str, str], dict[str, list[str]], dict[str, dict[str, Any]]];
def _resolve_canonical_id(
    cited: str, id_set: dict[str, str], label_to_ids: dict[str, list[str]]
) -> str | None;
def _resolve_source_path(src: str, graph_path: Path) -> Path | None;
def _content_hash(path: Path) -> str;
def _code_fingerprint(`node: dict[str, Any] | None, graph_path: Path) -> str;
def _provenance_for(
    `node: str, prov_map: dict[str, list], fallback_outcome: str
) -> list[dict[str, str]];
def build_learning_overlay(
    agg: dict[str, Any], graph_path: Path, *, now: datetime | None = None
) -> dict[str, Any];
def write_learning_sidecar(
    agg: dict[str, Any], graph_path: Path, *, now: datetime | None = None
) -> Path;
def load_learning_overlay(graph_path: Path) -> dict[str, dict[str, Any]];
def _is_stale(`entry: dict[str, Any], graph_path: Path) -> bool;
