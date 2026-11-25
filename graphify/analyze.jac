import importlib;
import builtins;

import operator;
import from __future__ { annotations }

import math;

import random;

import re;

import typing;

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

def _cross_language(src_a: str, src_b: str) -> bool;
def _node_community_map(communities: dict[int, list[str]]) -> dict[str, int];
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
def god_nodes(
    G: nx.Graph, top_n: int = 10, exclude_hubs_percentile: float | None = None
) -> list[dict];
def surprising_connections(
    G: nx.Graph, communities: dict[int, list[str]] | None = None, top_n: int = 5
) -> list[dict];
def _is_concept_node(G: nx.Graph, node_id: str) -> bool;
def _is_contains_only_ast_node(G: nx.Graph, node_id: str) -> bool;

def _file_category(path: str) -> str;
def _top_level_dir(path: str) -> str;
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
def _cross_file_surprises(G: nx.Graph, communities: dict[int, list[str]], top_n: int) -> list[dict];
def _cross_community_surprises(
    G: nx.Graph, communities: dict[int, list[str]], top_n: int
) -> list[dict];

with entry {
    _NETWORKX_RESCALES_SAMPLES_BY_SOURCE = operator.ge(
        `tuple(`int(p) for p in re.findall("\\d+", nx.__version__)[:2]), (3, 5)
    );
}

def _betweenness_centrality(G: nx.Graph, k: int | None, seed: int) -> dict[str, float];
def suggest_questions(
    G: nx.Graph, communities: dict[int, list[str]], community_labels: dict[int, str], top_n: int = 7
) -> list[dict];
def graph_diff(G_old: nx.Graph, G_new: nx.Graph) -> dict;
def find_import_cycles(G: nx.Graph, max_cycle_length: int = 5, top_n: int = 20) -> list[dict];
