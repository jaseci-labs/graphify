import from __future__ { annotations }
import networkx as nx;

import re;
def _distinct_node_labels(G: nx.Graph) -> list[str];
def push_to_neo4j(
    G: nx.Graph, uri: str, user: str, password: str, communities: dict[int, list[str]] | None = None
) -> dict[str, int];
def push_to_falkordb(
    G: nx.Graph,
    uri: str,
    user: str | None = None,
    password: str | None = None,
    communities: dict[int, list[str]] | None = None,
    graph_name: str = "graphify",
) -> dict[str, int];
