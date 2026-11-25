import operator;
import from __future__ { annotations }

import from collections { Counter }

import from collections.abc { Iterable, Iterator }

import from pathlib { Path }

import re;

import networkx as nx;

glob _SLUG_SUFFIX_RESERVE: any = 5;

glob _UNSAFE_SLUG_CHARS: any;

glob _INDEX_LINK: any;

glob stem_filename_budget: any = _wired_stem_filename_budget;

with entry {
    _UNSAFE_SLUG_CHARS = re.compile("[<>:\"/\\\\|?*#%\\x00-\\x1f\\x7f]");
    _INDEX_LINK = "[index](index.md)";
}

def _safe_filename(name: str, limit: int = 200) -> str;
def _md_link_to(label: str, slug: str | None) -> str;
def _incident_edges(G: nx.Graph, nodes: Iterable[str]) -> Generator[any, any, any];

def _community_article(
    G: nx.Graph,
    cid: int,
    nodes: list[str],
    label: str,
    labels: dict[int, str],
    cohesion: float | None,
    node_community: dict[str, int] | None = None,
    community_slugs: dict[int, str] | None = None,
) -> str;

def _god_node_article(
    G: nx.Graph,
    nid: str,
    labels: dict[int, str],
    node_community: dict[str, int] | None = None,
    community_slugs: dict[int, str] | None = None,
    god_slugs: dict[str, str] | None = None,
) -> str;
def _index_md(
    communities: dict[int, list[str]],
    labels: dict[int, str],
    god_nodes_data: list[dict],
    total_nodes: int,
    total_edges: int,
    community_slugs: dict[int, str],
    god_articles: list[tuple[str, str]],
) -> str;
def to_wiki(
    G: nx.Graph,
    communities: dict[int, list[str]],
    output_dir: str | Path,
    community_labels: dict[int, str] | None = None,
    cohesion: dict[int, float] | None = None,
    god_nodes_data: list[dict] | None = None,
) -> int;
