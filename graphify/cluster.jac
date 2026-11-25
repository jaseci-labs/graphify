import importlib;
import operator;
import from __future__ { annotations }

import contextlib;

import builtins;

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
def _topology_hash(
    G: nx.Graph, *, resolution: float, exclude_hubs_percentile: float | None, ambiguous_scale: float
) -> str;
def _load_cached_partition(cache_path: "str | Path", topo_hash: str) -> dict[int, list[str]] | None;
def _store_cached_partition(
    cache_path: "str | Path", topo_hash: str, communities: dict[int, list[str]]
);
def _suppress_output -> any;
def _native_leiden(stable: nx.Graph, resolution: float) -> dict[str, int] | None;
def _partition(G: nx.Graph, resolution: float = 1.0) -> dict[str, int];

glob _MAX_COMMUNITY_FRACTION: any = 0.25;

glob _MIN_SPLIT_SIZE: any = 10;

glob _COHESION_SPLIT_THRESHOLD: any = 0.05;

glob _COHESION_SPLIT_MIN_SIZE: any = 50;
def label_communities_by_hub(G: nx.Graph, communities: dict[int, list[str]]) -> dict[int, str];
def community_member_sigs(communities: dict[int, list[str]]) -> dict[int, str];
def cluster(
    G: nx.Graph,
    resolution: float = 1.0,
    exclude_hubs_percentile: float | None = None,
    ambiguous_scale: float = 0.5,
    cache_dir: "str | Path | None" = None,
) -> dict[int, list[str]];
def _split_community(G: nx.Graph, nodes: list[str]) -> list[list[str]];
def cohesion_score(G: nx.Graph, community_nodes: list[str]) -> float;

def score_all(G: nx.Graph, communities: dict[int, list[str]]) -> dict[int, float];
def remap_communities_to_previous(
    communities: dict[int, list[str]], previous_node_community: dict[str, int]
) -> dict[int, list[str]];
def label_still_applies(
    cid: int,
    current_members: list[str],
    previous_node_community: dict[str, int],
    saved_sig: str | None,
    current_sig: str | None,
) -> bool;
