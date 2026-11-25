"""Community detection on NetworkX graphs. Uses Leiden (graspologic) if available, falls back to Louvain (networkx). Splits oversized communities. Returns cohesion scores."""

import operator;

import from __future__ { annotations }

import contextlib;

import hashlib;

import inspect;

import io;

import json;

import os;

import sys;

import from collections { Counter }

import from pathlib { Path }

import networkx as nx;

glob _PARTITION_CACHE_NAME: any = ".graphify_partition_cache.json";

"""Cheap, order-independent fingerprint of everything that affects the
    partition: the node set, the weighted + confidence-tagged edge set, and the
    clustering parameters.

    Node and edge contributions are folded in by XORing each element's SHA-256,
    so the result is independent of NetworkX's (hash-seed-dependent) iteration
    order without paying for a global sort of nodes or edges - the whole point is
    to be dramatically cheaper than the community detection it guards. Edge
    endpoints are canonicalised as an unordered pair so the (A,B)/(B,A)
    adjacency-order flip #1667 describes does not change the hash.

    Raw ``weight`` and ``confidence`` are hashed (not the post-scaling effective
    weight) together with ``ambiguous_scale``; since the reweight in cluster() is
    a deterministic function of exactly those, equal inputs here mean an
    identical effective graph, hence an identical partition.
    """
def _topology_hash(
    G: nx.Graph, *, resolution: float, exclude_hubs_percentile: float | None, ambiguous_scale: float
) -> str;

"""Return the cached community assignment iff it was computed for exactly this
    topology hash, else None. Any read/parse problem returns None (fail open)."""
def _load_cached_partition(cache_path: "str | Path", topo_hash: str) -> dict[int, list[str]] | None;

"""Persist ``communities`` keyed by ``topo_hash`` beside the graph, atomically."""
def _store_cached_partition(
    cache_path: "str | Path", topo_hash: str, communities: dict[int, list[str]]
) -> None;

"""Context manager to suppress stdout/stderr during library calls.

    graspologic's leiden() emits ANSI escape sequences (progress bars,
    colored warnings) that corrupt PowerShell 5.1's scroll buffer on
    Windows (see issue #19). Redirecting stdout/stderr to devnull during
    the call prevents this without losing any graphify output.
    """
def _suppress_output -> any;

"""Call graspologic_native.leiden() directly, bypassing graspologic's own
    package import.

    graspologic.partition.leiden() is a thin wrapper around exactly this
    native (Rust) call. Importing the *package* — as opposed to the native
    extension module it depends on — pulls in graspologic.layouts, which
    imports umap, which imports pynndescent, which numba-JIT-compiles at
    import time for a layout algorithm this function never calls: measured
    at 7-19s of one-time import cost against a ~1s native call and a ~1.4s
    full round trip (conversion + call + map-back) — see the "third update"
    in GRAPHIFY_BUILD_PERF.md for the measurements this is based on.

    Returns None (the caller falls through to the graspologic.partition.leiden
    path, then to the networkx Louvain fallback) if graspologic_native isn't
    installed, or if `stable` isn't the plain undirected, non-multigraph
    input leiden actually supports — the same shape check
    graspologic.partition.leiden itself makes before calling the same native
    function.
    """
def _native_leiden(stable: nx.Graph, resolution: float) -> dict[str, int] | None;

"""Run community detection. Returns {node_id: community_id}.

    Tries Leiden (graspologic_native directly, then graspologic) first — best
    quality. Falls back to Louvain (built into networkx) if neither is
    installed.

    resolution > 1.0 → more, smaller communities.
    resolution < 1.0 → fewer, larger communities.

    Output from graspologic is suppressed to prevent ANSI escape codes
    from corrupting terminal scroll buffers on Windows PowerShell 5.1.
    """
def _partition(G: nx.Graph, resolution: float = 1.0) -> dict[str, int];

glob _MAX_COMMUNITY_FRACTION: any = 0.25;

glob _MIN_SPLIT_SIZE: any = 10;

glob _COHESION_SPLIT_THRESHOLD: any = 0.05;

glob _COHESION_SPLIT_MIN_SIZE: any = 50;

"""Deterministic, LLM-free community labels: name each community after its
    highest-degree member — the structural hub — so a report reads ``auth`` /
    ``log_action`` instead of ``Community 70``. Degree is measured on the full graph
    ``G``; ties break by node id for run-to-run stability. A community whose members
    are all absent from ``G`` falls back to ``Community {cid}``.

    Used as the default (no-backend) labeler; an LLM naming pass, when configured,
    overrides these with richer names.
    """
def label_communities_by_hub(G: nx.Graph, communities: dict[int, list[str]]) -> dict[int, str];

"""Per-community membership fingerprints: ``{cid: sha256(sorted member ids)}``.

    Persisted next to ``.graphify_labels.json`` so a later ``cluster-only`` can tell
    which communities actually changed since labeling. A cid whose members no longer
    hash the same is a different community — reusing its old (LLM) label there is the
    "stale label after re-scoping" bug this guards against. Deterministic; independent
    of cid index, node order, and machine.
    """
def community_member_sigs(communities: dict[int, list[str]]) -> dict[int, str];

"""Run Leiden community detection. Returns {community_id: [node_ids]}.

    Community IDs are stable across runs: 0 = largest community after splitting.
    Oversized communities (> 25% of graph nodes, min 10) are split by running
    a second Leiden pass on the subgraph.

    Accepts directed or undirected graphs. DiGraphs are converted to undirected
    internally since Louvain/Leiden require undirected input.

    resolution: passed to Leiden/Louvain. >1.0 = more smaller communities,
        <1.0 = fewer larger communities. Default 1.0.
    exclude_hubs_percentile: if set (0-100), nodes whose degree exceeds this
        percentile are excluded from partitioning and reattached to their
        majority-vote neighbour community afterwards. Nodes whose only
        neighbours are excluded hubs follow them, by the same vote. Useful for
        staging/utility super-hubs that inflate god-node rankings (#919).
    ambiguous_scale: multiplier applied to the ``weight`` attribute of
        ``AMBIGUOUS`` edges before partitioning. Default 0.5 — halves the
        modularity contribution of low-confidence edges so they do not
        glue otherwise-independent clusters together. Set to 1.0 to disable
        (treat AMBIGUOUS edges identically to EXTRACTED/INFERRED), or 0.0
        to drop them from clustering entirely (they still appear in the
        graph and in `/graphify path`/`explain` output — only partitioning
        is affected). Overridden by ``GRAPHIFY_AMBIGUOUS_SCALE`` env var
        when that is set to a parseable float. See #4199.
    cache_dir: if set, a directory (normally the graphify-out/ beside
        graph.json) where the computed partition is persisted keyed by a hash
        of the graph topology. When ``cluster()`` is next called with a graph
        whose topology hash matches the cached one, the cached assignment is
        reused instead of re-running community detection — it is exactly what a
        recompute would produce for the same graph. Any cache miss, missing or
        corrupt sidecar, or unwritable directory falls through to a normal
        recompute (fail open). Omit (``None``) to disable caching entirely.
    """
def cluster(
    G: nx.Graph,
    resolution: float = 1.0,
    exclude_hubs_percentile: float | None = None,
    ambiguous_scale: float = 0.5,
    cache_dir: "str | Path | None" = None,
) -> dict[int, list[str]];

"""Run a second Leiden pass on a community subgraph to split it further."""
def _split_community(G: nx.Graph, nodes: list[str]) -> list[list[str]];

"""Ratio of actual intra-community edges to maximum possible."""
def cohesion_score(G: nx.Graph, community_nodes: list[str]) -> float;

def score_all(G: nx.Graph, communities: dict[int, list[str]]) -> dict[int, float];

"""Remap community IDs to maximize overlap with a previous assignment.

    Uses greedy one-to-one matching by intersection size, then assigns fresh IDs
    to unmatched communities in deterministic order (size desc, lexical tie-break).
    """
def remap_communities_to_previous(
    communities: dict[int, list[str]], previous_node_community: dict[str, int]
) -> dict[int, list[str]];

"""Whether a saved label still names this community (#2298).

    An equal membership signature keeps the label. Otherwise the label stays
    only when the nodes shared with the previous assignment are a strict
    majority of both the previous set and the current set. A one-node fragment
    of a large community fails that test, so remap reusing the old id is not
    enough to keep the name.
    """
def label_still_applies(
    cid: int,
    current_members: list[str],
    previous_node_community: dict[str, int],
    saved_sig: str | None,
    current_sig: str | None,
) -> bool;
