import importlib;
import operator;
import from __future__ { annotations }

import builtins;

import functools;

import json;

import math;

import os;

import re;

import sys;

import warnings;

import from array { array }

import from collections { OrderedDict }

import from pathlib { Path }

import threading;

import from typing { NamedTuple }

import networkx as nx;

import from networkx.readwrite { json_graph }

glob _jieba: any;

glob _QUERY_STOPWORDS: any;

glob _EXACT_MATCH_BONUS: any;

glob _PREFIX_MATCH_BONUS: any;

glob _SUBSTRING_MATCH_BONUS: any;

glob _SOURCE_MATCH_BONUS: any;

glob _RATIONALE_MATCH_BONUS: any;

glob _ATTRIBUTE_MATCH_BONUS: any;

glob _QUALIFIED_MATCH_BONUS: any;

glob _QUALIFIED_MAX_TOKENS: any;

glob _QUALIFIER_SEPARATORS: any;

glob _NAME_EDGES: any;

glob _CAMEL_WORD_RE: any;

glob _QUALIFIER_MAYBE_RE: any;

glob _FILE_SUFFIX_RE: any;

glob _QUERY_DEMOTE_WEIGHT: any;

glob _QUERY_TEST_WORDS: any;

glob _QUERY_DOC_WORDS: any;

glob _QUERY_DOC_SUFFIXES: any;

glob _QUERY_DOC_DIRS: any;

glob _RELATIONAL_INTENT_TERMS: frozenset[str];

glob _CONTEXT_HINTS: tuple[tuple[str, tuple[str, ...]], ...];

glob _CONTEXT_FILTER_ALIASES: dict[str, str];

glob _HERITAGE_RELATIONS: any;

glob _CONTEXT_RELATIONS: dict[str, frozenset[str]];

glob _QUERY_NO_MATCH: any;

glob _PY_QUALIFIED_RE: any;

glob _TYPE_MEMBER_RELATIONS: any;

glob _QUALIFIED_MEMBER_RE: any;

glob _AMBIGUOUS: any;

glob _MAX_SHORTEST_PATHS: any;

glob _MCPASGIApp: any;

glob _ApiKeyMiddleware: any;

with entry {
    try {
        with warnings.catch_warnings() {
            warnings.simplefilter("ignore", SyntaxWarning);
            import jieba as _jieba;
        }
    } except (ImportError, SyntaxError) {
        _jieba = None;
    }
}

obj ToolError(Exception) {
    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def _read_graph(graph_path: str) -> nx.Graph;

def _load_graph(graph_path: str) -> nx.Graph;
def _communities_from_graph(G: nx.Graph) -> dict[int, list[str]];
def _max_server_contexts -> int;

obj _GraphContextCache {
    has _max_contexts: any,
        _entries: any,
        _pinned: any,
        _lock: any,
        _loading: any;

    def init(max_contexts: int);
    def _load_entry(resolved_path: str, key: tuple[int, int]) -> dict;
    def load(resolved_path: str, *, pinned: bool = False) -> tuple[nx.Graph, dict[int, list[str]]];

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def _node_arg(arguments: dict) -> str;

def _strip_diacritics(text: str | None) -> str;
def _search_tokens(text: str) -> list[str];

def _has_chinese(text: str) -> bool;
def _segment_chinese(text: str) -> list[str];
def _is_searchable(term: str) -> bool;

with entry {
    _QUERY_STOPWORDS = frozenset({
        "how",
        "what",
        "why",
        "when",
        "where",
        "which",
        "who",
        "whom",
        "whose",
        "does",
        "did",
        "is",
        "are",
        "was",
        "were",
        "be",
        "been",
        "being",
        "can",
        "could",
        "should",
        "would",
        "will",
        "shall",
        "may",
        "might",
        "must",
        "has",
        "have",
        "had",
        "the",
        "and",
        "but",
        "not",
        "for",
        "from",
        "with",
        "without",
        "into",
        "onto",
        "off",
        "that",
        "this",
        "these",
        "those",
        "there",
        "here",
        "its",
        "their",
        "them",
        "they",
        "about",
        "any",
        "all",
        "some",
        "work",
        "works",
        "working",
        "get",
        "gets",
        "got",
        "getting",
        "der",
        "die",
        "das",
        "den",
        "dem",
        "ein",
        "eine",
        "und",
        "oder",
        "nicht",
        "wie",
        "wer",
        "wann",
        "wo",
        "warum",
        "wieso",
        "welche",
        "welcher",
        "welches",
        "ist",
        "sind",
        "wird",
        "wurde",
        "hat",
        "haben",
        "kann",
        "koennen",
        "können",
        "soll",
        "muss",
        "sich",
        "bei",
        "mit",
        "von",
        "fuer",
        "für",
        "ueber",
        "über",
        "nach",
        "aus",
        "gibt",
        "es",
        "funktioniert",
        "geaendert",
        "geändert",
        "aendert",
        "ändert",
        "pourquoi",
        "quand",
        "quel",
        "quelle",
        "quels",
        "quelles",
        "quoi",
        "qui",
        "que",
        "est",
        "sont",
        "fonctionne",
        "cette",
        "dans",
        "avec",
        "où",
        "cómo",
        "como",
        "qué",
        "cuál",
        "cuáles",
        "cuándo",
        "dónde",
        "donde",
        "porque",
        "por",
        "para",
        "funciona",
        "está",
        "están",
        "hay",
        "qual",
        "quais",
        "quando",
        "onde",
        "são",
        "estão",
        "tem",
        "uma",
        "não",
        "perché",
        "cosa",
        "quale",
        "quali",
        "dove",
        "funziona",
        "sono",
        "che",
        "della",
    });
}

def _query_terms(question: str) -> list[str];

with entry {
    _EXACT_MATCH_BONUS = 1000.0;
    _PREFIX_MATCH_BONUS = 100.0;
    _SUBSTRING_MATCH_BONUS = 1.0;
    _SOURCE_MATCH_BONUS = 0.5;
    _RATIONALE_MATCH_BONUS = 0.75;
    _ATTRIBUTE_MATCH_BONUS = 0.75;
    _QUALIFIED_MATCH_BONUS = 500.0;
    _QUALIFIED_MAX_TOKENS = 4;
    _QUALIFIER_SEPARATORS = "\\.{1,}|::|/|\\\\|:|@";
    _NAME_EDGES = "()[]{}";

    _CAMEL_WORD_RE = re.compile("[A-Z]+(?![a-z])|[A-Z][a-z0-9]*|[a-z0-9]+");
    _QUALIFIER_MAYBE_RE = re.compile("[.::/\\\\:@]|[a-z0-9][A-Z]");
    _FILE_SUFFIX_RE = re.compile(
        "^(?:py|pyi|js|jsx|ts|tsx|mjs|cjs|go|rs|java|kt|kts|c|h|cc|cpp|hpp|cs|rb|php|swift|scala|lua|sh|bash|sql|md|rst|txt|ya?ml|toml|json|ini|cfg|html?|css|scss|vue|svelte|ex|exs|erl|hs|ml|clj|dart|proto|graphql)$",
    );
}

def _is_name_segment(segment: str) -> bool;
def _qualified_tail(norm_label: str) -> tuple[int, str] | None;
def _name_key(text: str) -> str;

def _flatten_attr_text(val, parts: list[str]);
def _node_attributes_text(data: dict) -> tuple[str, str];
def _compute_idf(G: nx.Graph, terms: list[str]) -> dict[str, float];
def _trigrams(text: str) -> set[str];
def _node_rationale_text(data: dict) -> str;
def _node_search_text(data: dict, nid: str) -> str;
def _get_trigram_index(G: nx.Graph) -> dict;
def _trigram_candidates(G: nx.Graph, needles: list[str], *, guard_frac: float = 0.1) -> list[str]
    | None;

class _QueryScores(NamedTuple) {
    has ranked: list[tuple[float, str]];

    has best_seed_by_term: dict[str, str];

    has term_order: tuple[str, ...] = ();
}

with entry {
    _QUERY_DEMOTE_WEIGHT = 0.3;
    _QUERY_TEST_WORDS = frozenset({"test", "tests", "testing", "testcase", "unittest"});
    _QUERY_DOC_WORDS = frozenset({"doc", "docs", "documentation", "readme"});
    _QUERY_DOC_SUFFIXES = (
        ".md",
        ".rst",
        ".txt",
        ".yml",
        ".yaml",
        ".toml",
        ".cfg",
        ".ini",
        ".json",
    );
    _QUERY_DOC_DIRS = frozenset({"doc", "docs", "example", "examples"});
}

def _query_path_weight(terms: list[str], demote_docs: bool = True) -> any;
def _score_nodes(G: nx.Graph, terms: list[str]) -> list[tuple[float, str]];
def _score_query(
    G: nx.Graph, terms: list[str], *, collect_per_term_seeds: bool, path_weight=None
) -> _QueryScores;
def _pick_scored_endpoint(G: nx.Graph, scored: list[tuple[float, str]], query: str) -> str;
def _pick_seeds(
    scored: list[tuple[float, str]],
    max_k: int = 3,
    gap_ratio: float = 0.2,
    *,
    G: "nx.Graph | None" = None,
    best_seed_by_term: dict[str, str] | None = None,
    term_order: "tuple[str, ...] | list[str] | None" = None,
) -> list[str];

with entry {
    _RELATIONAL_INTENT_TERMS = frozenset({
        "call",
        "calls",
        "called",
        "caller",
        "callers",
        "invoke",
        "invokes",
        "invoked",
        "use",
        "uses",
        "used",
        "using",
        "import",
        "imports",
        "imported",
        "export",
        "exports",
        "exported",
        "extend",
        "extends",
        "extended",
        "implement",
        "implements",
        "implemented",
        "depend",
        "depends",
        "reference",
        "references",
        "referenced",
    });

    _CONTEXT_HINTS = (
        ("call", ("call", "calls", "called", "caller", "callers", "invoke", "invokes", "invoked")),
        ("import", ("import", "imports", "imported", "module", "modules")),
        ("field", ("field", "fields", "member", "members", "property", "properties")),
        ("parameter_type", ("parameter", "parameters", "param", "params", "argument", "arguments")),
        ("return_type", ("return", "returns", "returned")),
        ("generic_arg", ("generic", "generics", "template", "templates")),
    );

    _CONTEXT_FILTER_ALIASES = {
        "param": "parameter_type",
        "params": "parameter_type",
        "parameter": "parameter_type",
        "parameters": "parameter_type",
        "argument": "parameter_type",
        "arguments": "parameter_type",
        "arg": "parameter_type",
        "args": "parameter_type",
        "return": "return_type",
        "returns": "return_type",
        "returned": "return_type",
        "generic": "generic_arg",
        "generics": "generic_arg",
        "template": "generic_arg",
        "templates": "generic_arg",
        "annotation": "attribute",
        "annotations": "attribute",
        "decorator": "attribute",
        "decorators": "attribute",
        "calls": "call",
        "called": "call",
        "invoke": "call",
        "invocation": "call",
        "fields": "field",
        "property": "field",
        "properties": "field",
        "member": "field",
        "members": "field",
        "imports": "import",
        "imported": "import",
        "module": "import",
        "modules": "import",
        "exports": "export",
        "exported": "export",
        "inherit": "inherits",
        "inherited": "inherits",
        "inheritance": "inherits",
        "subclass": "inherits",
        "subclasses": "inherits",
        "superclass": "inherits",
        "implements": "implements",
        "implemented": "implements",
        "interface": "implements",
        "interfaces": "implements",
        "extends": "extends",
    };
    _HERITAGE_RELATIONS = frozenset({"inherits", "implements", "extends"});
    _CONTEXT_RELATIONS = {"call": frozenset({"calls"})};
}

def _normalize_context_filters(filters: list[str] | None) -> list[str];

def _infer_context_filters(question: str) -> list[str];

def _resolve_context_filters(
    question: str, explicit_filters: list[str] | None = None
) -> tuple[list[str], str | None];

def _filter_graph_by_context(G: nx.Graph, context_filters: list[str] | None) -> nx.Graph;
def _complete_induced_edges(G: nx.Graph, visited: set[str], edges_seen: list[tuple]);

def _bfs(G: nx.Graph, start_nodes: list[str], depth: int) -> tuple[set[str], list[tuple]];

def _dfs(G: nx.Graph, start_nodes: list[str], depth: int) -> tuple[set[str], list[tuple]];
def _subgraph_to_text(
    G: nx.Graph,
    nodes: set[str],
    edges: list[tuple],
    token_budget: int = 2000,
    *,
    seeds: list[str] | None = None,
    scores: dict[str, float] | None = None,
) -> str;
def _cut_lines_to_budget(lines: list[str], token_budget: int, narrow_hint: str) -> str;
def _display_graph_path(graph_path: str) -> str;
def _traversal_view(G: nx.Graph) -> nx.Graph;

with entry {
    _QUERY_NO_MATCH = "No matching nodes found.";
}

def _query_graph_text(
    G: nx.Graph,
    question: str,
    *,
    mode: str = "bfs",
    depth: int = 3,
    token_budget: int = 2000,
    context_filters: list[str] | None = None,
    graph_path: str | None = None,
    seeds: list[str] | None = None,
    seed_root: Path | None = None,
    demote_docs: bool = True,
) -> str;

def _render_query(
    G: nx.Graph,
    question: str,
    start_nodes: list[str],
    *,
    mode: str,
    depth: int,
    token_budget: int,
    context_filters: list[str] | None,
    graph_path: str | None,
    given: bool = False,
    unresolved: list[str] | None = None,
    scores: dict[str, float] | None = None,
) -> str;
def _resolve_path_scoped_symbol(G: nx.Graph, path_part: str, symbol_part: str) -> list[str];
def _label_has_literal_exact_match(G: nx.Graph, term: str, norm_query: str) -> bool;

with entry {
    _PY_QUALIFIED_RE = re.compile(
        "^([A-Za-z_]\\w*(?:\\.[A-Za-z_]\\w*)*)[.:]([A-Za-z_]\\w*)(?:\\(\\))?$"
    );
}

def _resolve_python_qualified(G: nx.Graph, label: str) -> list[str];

with entry {
    _TYPE_MEMBER_RELATIONS = frozenset({"method", "defines", "contains"});
    _QUALIFIED_MEMBER_RE = re.compile(
        "^([A-Za-z_]\\w*(?:\\.[A-Za-z_]\\w*)*)\\.([A-Za-z_]\\w*)(?:\\(\\))?$"
    );
}

def _symbol_name(d: dict) -> str;
def _split_qualified_member(label: str) -> tuple[list[str], str] | None;

def _named_nodes(G: nx.Graph, name: str) -> list[str];
def _membership_neighbors(G: nx.Graph, nid: str, *, members: bool) -> list[str];
def _enclosed_by(G: nx.Graph, nid: str, outer: list[str]) -> bool;
def _qualified_member_owners(G: nx.Graph, qualifiers: list[str]) -> list[str];

def _members_named(G: nx.Graph, owners: list[str], member: str) -> list[str];
def _names_source_file(G: nx.Graph, label: str) -> bool;
def _resolve_qualified_member(G: nx.Graph, label: str) -> list[str];
def _no_member_match_message(G: nx.Graph, label: str) -> str | None;
def _find_node_tiers(G: nx.Graph, label: str) -> tuple[list[str], list[str], list[str], list[str]];
def _find_node(G: nx.Graph, label: str) -> list[str];
def find_node_ambiguity(G: nx.Graph, label: str) -> list[str];
def _rivals_across_files(G: nx.Graph, tier: list[str]) -> list[str];
def _near_miss_message(G: nx.Graph, label: str, hits: list[str], *, limit: int = 5) -> str;
def _resolve_single_node(G: nx.Graph, label: str) -> tuple[str | None, str | None];
def _query_name_refusal(G: nx.Graph, label: str) -> str | None;
def _tier_refusal(G: nx.Graph, label: str, tier: list[str], *, file_query: bool) -> str | None;

with entry {
    _AMBIGUOUS = "Ambiguous: ";
}

def _is_ambiguity_refusal(message: str | None) -> bool;

def _ambiguity_message(G: nx.Graph, label: str, rivals: list[str]) -> str;

def _same_file_ambiguity_message(G: nx.Graph, label: str, hits: list[str]) -> str;
def _no_scoped_match_message(G: nx.Graph, path_part: str, symbol_part: str) -> str;
def _resolve_path_endpoint(G: nx.Graph, query: str) -> tuple[str
    | None, list[tuple[float, str]], str | None];
def _query_uses_known_words(G: nx.Graph, terms: list[str]) -> bool;
def _path_search_graph(G: nx.Graph, undirected: bool) -> nx.Graph;
def _path_weakest(hop_datas: list[list[dict]]) -> any;
def _path_confidence_line(hop_datas: list[list[dict]]) -> str;

with entry {
    _MAX_SHORTEST_PATHS = 256;
}

def _path_hop_datas(G: nx.Graph, path_nodes: list[str]) -> list[list[dict]];
def _path_confidence_key(hop_datas: list[list[dict]]) -> any;
def _path_hub_penalty(G: nx.Graph, path_nodes: list[str]) -> int;
def _weakest_shortest_path(search_graph: nx.Graph, G: nx.Graph, src_nid: str, tgt_nid: str) -> any;
def _confidence_tag(d: dict) -> str;
def _shortest_path_text(G: nx.Graph, arguments: dict) -> str;
def _filter_blank_stdin;

def _community_header(cid: int, community_name) -> str;
def _neighbor_lines(G: nx.Graph, nid: str, rel_filter: str = "") -> list[str];
async def _warm_graph(resolve, load, project_path);
async def _after_warm(warm, project_path, run, *args_) -> any;

async def _call_tool(handlers, warm, select, name: str, arguments: dict) -> any;
async def _on_list_tools(list_tools, ctx, params) -> any;

async def _on_call_tool(call_tool, ctx, params) -> any;

async def _on_list_resources(list_resources, ctx, params) -> any;

async def _on_read_resource(read_resource, ctx, params) -> any;

async def _run_stdio(server, stdio_server);
def _build_server(graph_path: str) -> any;
def serve(graph_path: str | None = None);

async def _mcp_asgi_call(app, scope, receive, send);

def _mcp_asgi_init(app, manager);

with entry {
    _MCPASGIApp = builtins.type(
        "_MCPASGIApp", (), {"__init__": _mcp_asgi_init, "__call__": _mcp_asgi_call}
    );
}

async def _api_key_call(gate, scope, receive, send);

def _api_key_init(gate, app, api_key: str);

with entry {
    _ApiKeyMiddleware = builtins.type(
        "_ApiKeyMiddleware", (), {"__init__": _api_key_init, "__call__": _api_key_call}
    );
}

def _build_http_app(
    graph_path: str,
    *,
    host: str = "127.0.0.1",
    port: int = 8080,
    api_key: str | None = None,
    path: str = "/mcp",
    json_response: bool = False,
    stateless: bool = False,
    session_timeout: float | None = 3600.0,
) -> any;
def serve_http(
    graph_path: str | None = None,
    *,
    host: str = "127.0.0.1",
    port: int = 8080,
    api_key: str | None = None,
    path: str = "/mcp",
    json_response: bool = False,
    stateless: bool = False,
    session_timeout: float | None = 3600.0,
);

def _main(argv: list[str] | None = None);

with entry:__main__ {
    _main();
}
