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

# This module's own bindings, as a `from` import makes them: tests patch them here.
glob stem_filename_budget: any = _wired_stem_filename_budget;

with entry {
    _UNSAFE_SLUG_CHARS = re.compile("[<>:\"/\\\\|?*#%\\x00-\\x1f\\x7f]");
    _INDEX_LINK = "[index](index.md)";
}

"""Make a label safe for use as a filename across platforms AND as a
    markdown link destination.

    Substitutes characters that Windows reserves in filenames
    (< > : " / \\ | ? *) plus the ones that would make the emitted link stop
    matching the file on disk, and strips trailing dots/spaces, also reserved.
    Falls back to 'unnamed' for empty results and caps length at ``limit``
    chars (default 200) to stay well under common filesystem limits; ``to_wiki``
    lowers ``limit`` when the wiki directory leaves less than that inside
    Windows' MAX_PATH window (#2655).

    Parentheses are DROPPED rather than substituted: every callable node is
    labelled ``foo()``, and substituting would leave a trailing ``foo__`` on
    each of them — and would mangle Python dunders (``__init__()`` ->
    ``_init_``) if the resulting runs were then collapsed. Dropping keeps
    ``__init__`` intact. Two labels that collapse to one slug are still
    separated by ``_unique_slug``.
    """
def _safe_filename(name: str, limit: int = 200) -> str;

"""Link to the exact on-disk filename (#2597), or render plain text."""
def _md_link_to(label: str, slug: str | None) -> str;

"""Yield each incident edge once, including reciprocal and parallel edges."""
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

"""Render index.md.

    Takes the exact slugs for community IDs and god-node IDs.
    Two communities, or two god nodes, can share a label while owning separate
    files, and a label lookup cannot tell them apart: it points every row at
    whichever was registered first and orphans the rest (#3032/#3033).
    """
def _index_md(
    communities: dict[int, list[str]],
    labels: dict[int, str],
    god_nodes_data: list[dict],
    total_nodes: int,
    total_edges: int,
    community_slugs: dict[int, str],
    god_articles: list[tuple[str, str]],
) -> str;

"""Generate a Wikipedia-style wiki from the graph.

    Writes:
      - index.md            — agent entry point, catalog of all articles
      - <CommunityName>.md  — one article per community
      - <GodNodeLabel>.md   — one article per god node

    Returns the number of articles written (excluding index.md).
    """
def to_wiki(
    G: nx.Graph,
    communities: dict[int, list[str]],
    output_dir: str | Path,
    community_labels: dict[int, str] | None = None,
    cohesion: dict[int, float] | None = None,
    god_nodes_data: list[dict] | None = None,
) -> int;
