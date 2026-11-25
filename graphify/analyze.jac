"""Graph analysis: god nodes (most connected), surprising connections (cross-community), suggested questions."""

import importlib;
import builtins;

import operator;

import from __future__ { annotations }

import math;

import random;

import re;

import from pathlib { Path }

import networkx as nx;

glob _BUILTIN_NOISE_LABELS: any;

glob _LANG_FAMILY: dict[str, str];

glob _JSON_NOISE_LABELS: frozenset[str];

glob _NETWORKX_RESCALES_SAMPLES_BY_SOURCE: any;

with entry {
    _BUILTIN_NOISE_LABELS = frozenset({
        "str",
        "int",
        "float",
        "bool",
        "bytes",
        "bytearray",
        "complex",
        "object",
        "True",
        "False",
        "MagicMock",
        "Mock",
        "AsyncMock",
        "NonCallableMock",
        "NonCallableMagicMock",
        "PropertyMock",
        "patch",
        "sentinel",
        "Path",
        "Any",
        "Optional",
        "List",
        "Dict",
        "Set",
        "Tuple",
        "Union",
        "Callable",
        "Type",
        "ClassVar",
        "Final",
        "Literal",
        "Protocol",
        "Counter",
        "defaultdict",
        "OrderedDict",
        "datetime",
        "Enum",
        "os",
        "sys",
        "re",
        "json",
        "io",
        "abc",
        "typing",
        "Foundation",
        "SwiftUI",
        "UIKit",
        "AppKit",
        "Combine",
        "String",
        "Int",
        "Double",
        "Float",
        "Bool",
        "Data",
        "URL",
        "Date",
        "UUID",
        "Sendable",
        "Codable",
        "Decodable",
        "Encodable",
        "Equatable",
        "Hashable",
        "Identifiable",
        "Comparable",
        "AnyObject",
        "Error",
        "LocalizedError",
        "NSObject",
        "NSString",
        "NSError",
        "NSLock",
        "View",
        "Color",
        "Font",
        "DispatchQueue",
    });
    _LANG_FAMILY = {
        **{e: "python" for e in (".py", ".pyw")},
        **{
            e: "js"
            for e in (
                ".js",
                ".jsx",
                ".mjs",
                ".cjs",
                ".ejs",
                ".ts",
                ".tsx",
                ".mts",
                ".cts",
                ".vue",
                ".svelte",
            )
        },
        **{e: "go" for e in (".go",)},
        **{e: "rust" for e in (".rs",)},
        **{e: "jvm" for e in (".java", ".kt", ".kts", ".scala")},
        **{e: "c" for e in (".c", ".h", ".cpp", ".cc", ".cxx", ".hpp")},
        **{e: "ruby" for e in (".rb", ".rake")},
        **{e: "swift" for e in (".swift",)},
        **{e: "dotnet" for e in (".cs", ".vb")},
        **{e: "php" for e in (".php",)},
        **{e: "r" for e in (".r",)},
        **{e: "cobol" for e in (".cbl", ".cob", ".cobol", ".cpy")},
        **{e: "solidity" for e in (".sol",)},
        **{e: "erlang" for e in (".erl", ".hrl", ".escript")},
    };
}

"""Return True if two source files belong to different language families."""
def _cross_language(src_a: str, src_b: str) -> bool;

"""Invert communities dict: node_id -> community_id."""
def _node_community_map(communities: dict[int, list[str]]) -> dict[str, int];

"""
    Return True if this node is a file-level hub node (e.g. 'client', 'models')
    or an AST method stub (e.g. '.auth_flow()', '.__init__()').

    These are synthetic nodes created by the AST extractor and should be excluded
    from god nodes, surprising connections, and knowledge gap reporting.
    """
def _is_file_node(G: nx.Graph, node_id: str) -> bool;

with entry {
    _JSON_NOISE_LABELS = frozenset({
        "start",
        "end",
        "name",
        "id",
        "type",
        "properties",
        "value",
        "key",
        "data",
        "items",
        "title",
        "description",
        "version",
        "dependencies",
        "devdependencies",
        "peerdependencies",
        "optionaldependencies",
        "bundleddependencies",
        "bundledependencies",
    });
}

def _is_json_key_node(G: nx.Graph, node_id: str) -> bool;

"""Return the top_n most-connected real entities - the core abstractions.

    File-level hub nodes are excluded: they accumulate import/contains edges
    mechanically and don't represent meaningful architectural abstractions.

    ``exclude_hubs_percentile`` (0-100) suppresses nodes whose degree exceeds
    that percentile of the graph's degree distribution, using the same
    threshold computation ``cluster()`` applies (#3205) - so the one setting
    suppresses utility hubs in the ranking AND in community resolution,
    instead of only the latter. ``None`` keeps the historical ranking.
    """
def god_nodes(
    G: nx.Graph, top_n: int = 10, exclude_hubs_percentile: float | None = None
) -> list[dict];

"""
    Find connections that are genuinely surprising - not obvious from file structure.

    Strategy:
    - Multi-file corpora: cross-file edges between real entities (not concept nodes).
      Sorted AMBIGUOUS → INFERRED → EXTRACTED.
    - Single-file / single-source corpora: cross-community edges that bridge
      distant parts of the graph (betweenness centrality on edges).
      These reveal non-obvious structural couplings.

    Concept nodes (empty source_file, or injected semantic annotations) are excluded
    from surprising connections because they are intentional, not discovered.
    """
def surprising_connections(
    G: nx.Graph, communities: dict[int, list[str]] | None = None, top_n: int = 5
) -> list[dict];

"""
    Return True if this node is a manually-injected semantic concept node
    rather than a real entity found in source code.

    Signals:
    - Empty source_file
    - source_file doesn't look like a real file path (no extension)
    """
def _is_concept_node(G: nx.Graph, node_id: str) -> bool;

"""AST declarations (type aliases, enum members, local consts, JSON keys)
    whose only edge is the structural `contains` from their declaring file are
    working as designed, not documentation gaps (#4205)."""
def _is_contains_only_ast_node(G: nx.Graph, node_id: str) -> bool;

def _file_category(path: str) -> str;

"""Return the first path component - used to detect cross-repo edges.

    A path with no "/" is a file at the scan root, so its top-level directory
    is the root itself ("."), not the filename: otherwise every pair of
    root-level files would look like it crosses repos/directories. "." keeps
    root files distinct from an absolute path outside the root, whose first
    component is "". Backslashes and a leading "./" are normalised first,
    since a graph.json loaded without build_from_json can still carry them.
    """
def _top_level_dir(path: str) -> str;

"""Score how surprising a cross-file edge is. Returns (score, reasons)."""
def _surprise_score(
    G: nx.Graph,
    u: str,
    v: str,
    data: dict,
    node_community: dict[str, int],
    u_source: str,
    v_source: str,
    degrees: dict[str, int] | None = None,
) -> tuple[int, list[str]];

"""
    Cross-file edges between real code/doc entities, ranked by a composite
    surprise score rather than confidence alone.

    Surprise score accounts for:
    - Confidence (AMBIGUOUS > INFERRED > EXTRACTED)
    - Cross file-type (code↔paper is more surprising than code↔code)
    - Cross-repo (different top-level directory)
    - Cross-community (Leiden says structurally distant)
    - Peripheral→hub (low-degree node reaching a god node)

    Each result includes a 'why' field explaining what makes it non-obvious.
    """
def _cross_file_surprises(G: nx.Graph, communities: dict[int, list[str]], top_n: int) -> list[dict];

"""
    For single-source corpora: find edges that bridge different communities.
    These are surprising because Leiden grouped everything else tightly -
    these edges cut across the natural structure.

    Falls back to high-betweenness edges if no community info is provided.
    """
def _cross_community_surprises(
    G: nx.Graph, communities: dict[int, list[str]], top_n: int
) -> list[dict];

with entry {
    _NETWORKX_RESCALES_SAMPLES_BY_SOURCE = operator.ge(
        `tuple(`int(p) for p in re.findall("\\d+", nx.__version__)[:2]), (3, 5)
    );
}

"""The scores of ``nx.betweenness_centrality(G, k=k, seed=seed)``, bit for bit.

    Unweighted, normalized and without endpoints, the only form used here. networkx
    keeps the search state in dicts keyed by node id and rebuilds the path counts and
    predecessor lists over the whole graph for each source. This numbers the nodes
    once, keeps the same state in lists, and resets only the entries a source reached.
    The search order, the accumulation order and the rescale for sampled sources
    follow networkx 3.5 and later. Older networkx rescaled sampled scores differently,
    so there this returns networkx's own result.
    """
def _betweenness_centrality(G: nx.Graph, k: int | None, seed: int) -> dict[str, float];

"""
    Generate questions the graph is uniquely positioned to answer.
    Based on: AMBIGUOUS edges, bridge nodes, underexplored god nodes, isolated nodes.
    Each question has a 'type', 'question', and 'why' field.
    Interleave question types before applying top_n so an abundant early type
    cannot crowd out later signals. Preserve the existing order within each type
    and category generation order when the limit is smaller than the type count.
    """
def suggest_questions(
    G: nx.Graph, communities: dict[int, list[str]], community_labels: dict[int, str], top_n: int = 7
) -> list[dict];

"""Compare two graph snapshots and return what changed.

    Returns:
        {
          "new_nodes": [{"id": ..., "label": ...}],
          "removed_nodes": [{"id": ..., "label": ...}],
          "new_edges": [{"source": ..., "target": ..., "relation": ..., "confidence": ...}],
          "removed_edges": [...],
          "summary": "3 new nodes, 5 new edges, 1 node removed"
        }
    """
def graph_diff(G_old: nx.Graph, G_new: nx.Graph) -> dict;

"""Detect circular import dependencies at the file level.

    Collapses symbol-level nodes to their parent file (using source_file attr
    or 'contains' edges), builds a directed file-level graph from imports_from
    edges, then finds simple cycles.

    Args:
        G: The full knowledge graph (may be undirected or directed).
        max_cycle_length: Only report cycles with at most this many files.
        top_n: Maximum number of cycles to return (shortest first).

    Returns:
        List of cycle records with stable structure:
        {
          "cycle": ["a.ts", "b.ts"],
          "length": 2,
          "why": "circular dependency"
        }
    """
def find_import_cycles(G: nx.Graph, max_cycle_length: int = 5, top_n: int = 20) -> list[dict];
