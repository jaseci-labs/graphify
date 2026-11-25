"""Deterministic "work memory" reflection over graphify-out/memory/.

`graphify reflect` reads the Q&A memory docs that `graphify save-result` files back
into the graph, aggregates their outcome signals (useful / dead_end / corrected), and
writes a single lessons artifact an agent can load at the start of the next session:

  - **Preferred sources** — nodes corroborated by multiple ``useful`` answers.
  - **Tentative** — nodes seen useful only once (not yet corroborated).
  - **Contested** — nodes with both positive and negative signals; recency decides.
  - **Known dead ends** — questions/sources marked ``dead_end``; don't re-derive them.
  - **Corrections** — answers the user corrected, and what the right answer was.

Source nodes are scored, not counted: each citation contributes a signed,
time-decayed value (``useful`` positive, ``dead_end``/``corrected`` negative, with a
half-life so a fresh dead end outweighs a months-old useful). A node is only promoted
to "preferred" once corroborated by enough distinct results; one save can't mint a
trusted lesson. When a graph is in hand, source nodes that no longer exist are dropped.

It is deterministic: no LLM, stable sort orders, byte-stable output for a given input
and a given ``now``. When a graph (`graph.json` + `.graphify_analysis.json`) is available
the lessons are also grouped by community label; without it they degrade to a single
flat section.

The artifact lands at ``graphify-out/reflections/LESSONS.md`` rather than inside the wiki
because ``graphify export wiki`` deletes every ``wiki/*.md`` on each run — a lessons file
written there would be clobbered on the next export.
"""

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

"""Reverse the double-quoted escaping that ingest._yaml_str applies."""
def _yaml_unescape(s: str) -> str;

"""Parse the frontmatter of a memory doc into a dict, or None if it has none.

    Returns the recognised fields (``type``, ``date``, ``question``, ``outcome``,
    ``correction``, ``source_nodes``). ``source_nodes`` is always a list.
    """
def parse_memory_doc(text: str) -> dict[str, Any] | None;

"""Parse every memory doc under ``memory_dir``, sorted by date then filename.

    Each record is the parsed frontmatter plus ``_path`` (the source file). Docs
    without recognisable frontmatter (foreign .md files, the LESSONS.md artifact)
    are skipped.
    """
def load_memory_docs(memory_dir: Path) -> list[dict[str, Any]];

"""Build a lookup from node id AND node label -> community label, or None if the
    graph isn't available.

    Mirrors how `graphify export wiki` reads graph.json + .graphify_analysis.json +
    .graphify_labels.json. Community membership in the analysis sidecar is keyed by
    node id, but `save-result` cites nodes by label, so both are mapped — otherwise a
    cited ``build_from_json()`` never finds its community and every lesson collapses
    into Uncategorized. Best-effort: any missing/unparseable artifact disables grouping.
    """
def _load_node_community(graph_path: Path, analysis_path: Path, labels_path: Path) -> dict[str, str]
    | None;

"""The set of node ids AND labels in the current graph, or None if unavailable.

    Used to drop source nodes from lessons once the code they pointed at is gone
    (deleted/renamed) — a stale lesson shouldn't keep getting recommended. Both ids
    and labels are collected because `save-result` records source nodes by their
    human-readable label (what an agent cites, e.g. ``build_from_json()``), while
    graph nodes are keyed by id (e.g. ``module_build_from_json``). Matching on either
    keeps a still-present node and only drops one that survives under neither name —
    indexing ids alone silently dropped every label-form citation (the common case).
    """
def _load_known_nodes(graph_path: Path) -> set[str] | None;

"""The community a doc belongs to: the plurality community of its source nodes.

    Ties break to the lexicographically-smallest label, so the result is
    deterministic regardless of source-node order. Docs with no resolvable
    community (no source nodes, or no graph) fall into the Uncategorized bucket.
    """
def _doc_community(nodes: list[str], node_community: dict[str, str] | None) -> str;

"""Parse an ISO date/datetime to an aware UTC datetime, or None if unparseable."""
def _parse_dt(date_str: str) -> datetime | None;

"""Time-decay weight in (0, 1]: halves every ``half_life_days``.

    Undated/unparseable signals keep full weight (1.0); future-dated ones are
    clamped to age 0 (also 1.0).
    """
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
) -> None;

"""Split a bucket's scored nodes into preferred / tentative / contested lists."""
def _finalize_sources(bucket: dict[str, Any], min_corroboration: int) -> dict[str, list];

"""Collapse repeated questions to one entry. Docs are processed oldest-first, so
    the last write per question wins (recency — e.g. the most recent correction text).
    Output is deterministically ordered by (date, question). Without this, saving the
    same Q&A twice duplicated lines in the dead-ends / corrections lists, even though
    node scoring already dedups by node.
    """
def _dedupe_by_question(items: list[dict[str, Any]]) -> list[dict[str, Any]];

glob half_life_days_default_: any;

glob min_corroboration_default_: any;

with entry {
    half_life_days_default_ = _DEFAULT_HALF_LIFE_DAYS;
    min_corroboration_default_ = _DEFAULT_MIN_CORROBORATION;
}

"""Aggregate parsed memory docs into a deterministic lessons structure.

    ``now`` anchors the time-decay (pass it explicitly for byte-stable output).
    ``known_nodes`` (when given) gates out source nodes no longer in the graph.
    Returns ``{"total", "counts", "min_corroboration", "preferred", "tentative",
    "contested", "dead_ends", "corrections", "by_community"}``; ``by_community`` is
    empty unless a graph is supplied.
    """
def aggregate_lessons(
    docs: list[dict[str, Any]],
    node_community: dict[str, str] | None = None,
    *,
    now: datetime | None = None,
    half_life_days: float = half_life_days_default_,
    min_corroboration: int = min_corroboration_default_,
    known_nodes: set[str] | None = None,
) -> dict[str, Any];

def _render_bucket(out: list[str], data: dict[str, Any], k: int) -> None;

"""Render the aggregate into the deterministic LESSONS.md markdown body."""
def render_lessons_md(agg: dict[str, Any]) -> str;

"""True if ``out_path`` exists and is at least as new as every input that
    feeds it (the memory docs, and the graph/sidecars when one is used).

    Lets ``graphify reflect --if-stale`` skip a redundant run — e.g. when the git
    post-commit hook just regenerated ``LESSONS.md`` and an agent then runs reflect
    again at the start of a session. A missing output is never fresh (it must be
    built). Mtime-based and best-effort; it only gates whether to *recompute*, not
    what the recomputation produces (that stays deterministic).
    """
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

"""Scan ``memory_dir``, write the lessons doc to ``out_path``, return (path, agg).

    If ``graph_path`` is given lessons are grouped by community and source nodes no
    longer in the graph are dropped; otherwise the doc is a single flat section.
    """
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

"""From graph.json build:

    - ``id_set``: id -> id (every node id, so an id-form citation resolves to itself)
    - ``label_to_ids``: label -> [ids] (so a label-form citation can be resolved,
      and ambiguity — one label, many ids — can be detected and skipped)
    - ``node_by_id``: id -> node dict (for source_file lookup)

    Best-effort; an unreadable/garbage graph yields empty maps.
    """
def _build_id_label_maps(
    graph_path: Path
) -> tuple[dict[str, str], dict[str, list[str]], dict[str, dict[str, Any]]];

"""Resolve a cited node (a label OR an id) to a single canonical node id.

    Returns None if the citation is unresolved (stale — gone from the graph) or
    ambiguous (a label shared by >1 node id). Such citations can't be displayed
    against a single node, so the caller skips them.
    """
def _resolve_canonical_id(
    cited: str, id_set: dict[str, str], label_to_ids: dict[str, list[str]]
) -> str | None;

"""Locate a node's ``source_file`` on disk, returning an existing file or None.

    ``source_file`` is stored relative to the PROJECT root, but graph.json may
    live in ``<root>/graphify-out/`` (so its own dir is not the root) or directly
    at the root (``extract --out .``). Resolve the root in the most-likely order
    and return the first candidate where the file actually exists, so a defeated
    heuristic or a stale marker can never strand the file (every node would then
    look "changed"). The same search runs at write and read time, so the writer
    and reader resolve to the same file.

    Order: the committed ``.graphify_root`` marker (#686/#1423 — authoritative for
    an absolute/elsewhere ``GRAPHIFY_OUT`` override); then the layout-appropriate
    root *first* — graph.json's parent's parent for the ``graphify-out`` layout,
    or graph.json's own dir for a flat layout — which avoids matching a same-named
    file one directory up; then the other of the two; then the cwd.
    """
def _resolve_source_path(src: str, graph_path: Path) -> Path | None;

"""SHA256 of file CONTENT only (no path mixed in), so the fingerprint is
    independent of which root resolved the file — write and read agree, and a
    committed sidecar stays valid across machines/checkouts."""
def _content_hash(path: Path) -> str;

"""Content hash of the node's ``source_file``, or '' if unavailable.

    Coarse on purpose — a file-level hash over-flags (any edit to the file marks
    every node in it stale) rather than under-flags, which is the safe direction
    for a "re-verify" hint.
    """
def _code_fingerprint(`node: dict[str, Any] | None, graph_path: Path) -> str;

"""Most-recent-first, capped provenance entries for a node.

    ``prov_map`` is the aggregate's private per-node (date, question, outcome)
    trail. ``fallback_outcome`` covers an entry with no recorded trail (shouldn't
    happen for preferred/tentative/contested, which all have ≥1 positive event).
    """
def _provenance_for(
    `node: str, prov_map: dict[str, list], fallback_outcome: str
) -> list[dict[str, str]];

"""Project the reflect aggregate into the sidecar's ``{version, generated_at,
    nodes}`` structure, keyed by canonical node id.

    Built from preferred + tentative + contested (NOT dead_ends — those stay
    query-scoped, surfaced only in the report). Citations that don't resolve to
    exactly one node id are skipped.
    """
def build_learning_overlay(
    agg: dict[str, Any], graph_path: Path, *, now: datetime | None = None
) -> dict[str, Any];

"""Write ``.graphify_learning.json`` next to ``graph_path`` deterministically.

    Sorted keys + indent=2 so re-runs on identical input (and a fixed ``now``)
    are byte-identical. Returns the sidecar path.
    """
def write_learning_sidecar(
    agg: dict[str, Any], graph_path: Path, *, now: datetime | None = None
) -> Path;

"""Load the sidecar next to ``graph_path`` and return ``{node_id -> entry}``
    with a recomputed ``stale: bool`` per entry. An unreadable or malformed
    sidecar yields {}; malformed entries are ignored individually.

    Staleness: recompute ``file_hash(source_file)`` and compare to the entry's
    stored ``code_fingerprint``. Matching fingerprints -> not stale. Differing,
    missing-but-recomputable, or a vanished file -> stale (the safe, over-flagging
    direction). An entry with no stored fingerprint AND no current file is not
    marked stale (nothing to re-verify).
    """
def load_learning_overlay(graph_path: Path) -> dict[str, dict[str, Any]];

"""True if the node's source file changed (or vanished) since the fingerprint
    was taken. Uses the same file resolution + content hash as the writer, so a
    freshly-written verdict on unchanged code is never spuriously stale."""
def _is_stale(`entry: dict[str, Any], graph_path: Path) -> bool;
