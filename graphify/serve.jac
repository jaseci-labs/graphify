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

"""Raised by a tool handler to signal an error result.

    A normal string return is sent as an ordinary (successful) text result. A
    ToolError is instead turned into a tool result with ``isError: true`` so a
    client that only checks ``isError`` can tell a genuine failure — e.g. the
    ``gh`` CLI missing or a PR that cannot be resolved — from success.
    """
obj ToolError(Exception) {
    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""Load graph.json exactly as the MCP server does, raising on a bad path
    or file (ValueError, FileNotFoundError, json.JSONDecodeError) so a library
    caller such as the benchmark can handle it."""
def _read_graph(graph_path: str) -> nx.Graph;

def _load_graph(graph_path: str) -> nx.Graph;

"""Reconstruct community dict from community property stored on nodes."""
def _communities_from_graph(G: nx.Graph) -> dict[int, list[str]];

"""Return the project-context LRU capacity (default 8, minimum 1).

    ``GRAPHIFY_MAX_CONTEXTS`` overrides the default. Invalid or blank values
    use 8; zero and negative values clamp to 1, since each request needs a
    graph context. The server's configured default graph is pinned separately
    and does not count against this limit.
    """
def _max_server_contexts -> int;

"""Thread-safe graph contexts: one pinned default plus an LRU of projects."""
obj _GraphContextCache {
    has _max_contexts: any,
        _entries: any,
        _pinned: any,
        _lock: any,
        _loading: any;

    def init(max_contexts: int);

    """Build one entry for an already-resolved path and known file key.

        ``_load_graph`` is also used by the CLI, where invalid input terminates
        the process. A client-supplied ``project_path`` must instead become a
        tool error, so the shared MCP server can continue serving other graphs.
        """
    def _load_entry(resolved_path: str, key: tuple[int, int]) -> dict;

    """Return a fresh context, retaining project contexts by LRU order.

        ``resolved_path`` is resolved by the caller, making this method the
        sole owner of file statting and cache-key construction.

        ``pinned=True`` is reserved for the server's configured default graph;
        it remains warm without consuming a project-cache slot.

        The actual rebuild (``_load_entry``, which parses graph.json and builds
        its trigram index) runs outside ``_lock`` so a slow reload of one path
        never blocks a request for another (#5177). While a rebuild for THIS
        path is already in flight, a caller that still has an old entry for it
        gets that stale entry back immediately rather than queuing behind the
        rebuild; a caller with no entry yet (the path's first ever load) has
        nothing stale to serve and waits for the one in-flight build instead
        of starting a redundant second one.
        """
    def load(resolved_path: str, *, pinned: bool = False) -> tuple[nx.Graph, dict[int, list[str]]];

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""The node identifier a lookup tool was called with.

    ``get_node``/``get_neighbors`` historically read ``arguments["label"]`` only, so a client that
    passes the node under ``node_id`` (or ``id``) — several of the agent frameworks graphify targets
    do — raised ``KeyError('label')`` instead of being served. Accept the common spellings; callers
    treat an empty string as "no identifier given" and answer with guidance rather than a traceback.
    """
def _node_arg(arguments: dict) -> str;

def _strip_diacritics(text: str | None) -> str;

"""Split text into word tokens, stripping punctuation and diacritics.

    `_` is a separator, exactly like `-`. `\\w` counts underscore as a word
    character but not hyphen, so `graph_first_guard` stayed one token while the
    label `graph-first-guard.py` split into three — and the query matched
    nothing. Both the query and the node label pass through here, so splitting
    on `_` keeps the two sides consistent and snake_case lookups still resolve
    (their tokens simply match the same way). Found 2026-07-29: the graph could
    not find the underscore spelling of its own `local_id`.
    """
def _search_tokens(text: str) -> list[str];

def _has_chinese(text: str) -> bool;

"""Segment Chinese text and keep the original term for exact matching."""
def _segment_chinese(text: str) -> list[str];

"""True if term is Chinese, non-English, or an English word longer than 2 chars."""
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

"""Split a query into searchable terms, segmenting Chinese text, then drop
    question/filler words (`_QUERY_STOPWORDS`, English plus common German/
    Romance-language fillers) so content words drive seeding. Falls back to the
    unfiltered terms if the query is all stopwords, so a question like "how does
    it work" or "wie funktioniert das" still seeds on something."""
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

"""True if `segment` names something rather than being an extension or a number."""
def _is_name_segment(segment: str) -> bool;

"""Split a label into `(qualifier_token_count, tail_key)`, or `None` if unqualified.

    `public.sweep_widget_state()` -> `(1, "sweep widget state")`: the tail is the
    part a query would actually name. Segments are split on punctuation, so
    `fmt.Println` -> `(1, "println")` and `App\\Http\\handle` -> `(2, "handle")`.
    The CamelCase fallback below only fires on a cased label (an inner lower->upper
    transition); the scorer's callers pass the already-lowercased `norm_label`, so
    in practice only the separator path runs — the fallback is defensive.
    """
def _qualified_tail(norm_label: str) -> tuple[int, str] | None;

"""Token-joined form of an already-normalized name, for comparing two names.

    `norm_label` has been lowercased and had its diacritics stripped already, so
    splitting on non-alphanumerics is all `_search_tokens` would add here — and
    skipping the per-call Unicode normalization matters, this runs on the whole
    graph.
    """
def _name_key(text: str) -> str;

def _flatten_attr_text(val, parts: list[str]) -> None;

"""The node's `attributes` key-value pairs normalized and tokenized for search."""
def _node_attributes_text(data: dict) -> tuple[str, str];

"""IDF weights for query terms, cached in G.graph['_idf_cache'].

    Common terms like 'error' or 'exception' that match hundreds of nodes get
    low weights; rare identifiers like 'FooBarService' get high weights.
    Cache is stored on the graph object itself so it auto-invalidates when
    a hot-reload replaces G with a new object.
    """
def _compute_idf(G: nx.Graph, terms: list[str]) -> dict[str, float];

"""Character trigrams of `text`; for <3-char text the whole string is the key."""
def _trigrams(text: str) -> set[str];

"""The node's `rationale` attribute normalized like a label (diacritics
    folded, lower-cased) for substring matching. Semantic cleanup writes it as
    one string (several sources joined with blank lines); an extractor may hand
    over a list — join it. Missing or empty -> "" so callers can `if rationale`.
    """
def _node_rationale_text(data: dict) -> str;

"""Concatenate every field _score_nodes / _find_node match a query against, so
    one trigram index over this text is a complete candidate generator for both.

    - `rationale` (normalized via `_node_rationale_text`) feeds _score_nodes'
      rationale tier (#2293); appended last, and only when present, so every
      other field position is unchanged.

    - `norm_label` and `source_file` feed _score_nodes' per-term substring tiers.
    - `label_tokens` (the space-joined token form) feeds _find_node's
      `term in label_tokens` branch, where a multi-word `term` can span a token
      boundary that punctuation hides in `norm_label` (e.g. query "foo bar" matches
      label "foo.bar" only via its tokenized form).
    - `source_tokens` feeds _find_node's exact source-file path lookup, where a
      query like "app/api/example/route.ts" tokenizes to "app api example route ts".
    - `nid` feeds the whole-query `joined == nid_lower` tier.
    - a trailing diacritic-folded `nid` feeds _find_node's `norm_query == nid_norm`
      tier. Every query path folds through `_strip_diacritics` (NFKD), so a raw-only
      id field leaves the needle and the posting under different normal forms and
      the node is dropped before any predicate runs (#2467). Hangul is the common
      case: NFKD decomposes a syllable into conjoining jamo, which have combining
      class 0 and therefore survive the combining-character filter. The field is
      appended only when the fold actually differs, so the text an all-ASCII graph
      indexes — and every field position the other readers rely on — is unchanged.

    NUL separators stop a trigram from spanning two fields (a query never contains
    NUL, so a cross-field trigram can never be a real match).
    """
def _node_search_text(data: dict, nid: str) -> str;

"""Lazily build and cache a trigram -> node-position postings map on the graph.

    Cached on `G.graph` so it auto-invalidates when a hot-reload swaps in a
    fresh graph object, exactly like `_idf_cache`. `set_cache` memoizes per-trigram
    id-sets across queries within one graph generation.
    """
def _get_trigram_index(G: nx.Graph) -> dict;

"""Node IDs whose text could contain any `needle` as a substring, via the
    trigram index — a *superset* the caller then re-scores with the exact predicates.

    Returns candidates in graph-iteration order (so order-sensitive callers like
    _find_node stay byte-identical to a full scan), or **None** when the index isn't
    worth it — a needle is too short to trigram, or its rarest trigram is still
    common enough that the candidate set would approach the whole graph. The caller
    falls back to the full scan, preserving the never-worse contract. The guard is
    cheap: postings-length lookups only, no set intersection.
    """
def _trigram_candidates(G: nx.Graph, needles: list[str], *, guard_frac: float = 0.1) -> list[str]
    | None;

"""Per-query scoring result, returned by the private `_score_query` helper.

    `ranked` is the existing ordered `(score, node_id)` ranking produced by the
    combined query scorer (the value `_score_nodes` always returned). When the
    caller asks for it via `collect_per_term_seeds=True`, `best_seed_by_term`
    additionally carries the winning node id for each normalized search token —
    the seed `_pick_seeds` would have picked for that token via the now-retired
    per-token `_score_nodes([token])` rescoring pass — computed in the *same*
    per-node traversal so the query path makes exactly one graph scoring pass
    regardless of query length. Empty when `collect_per_term_seeds=False`.
    """
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

"""Score multiplier per node for `query`: tests, docs, images, config files
    and nodes without a source file count `_QUERY_DEMOTE_WEIGHT`, unless the
    question itself asks about tests (or docs); everything else counts 1.0."""
def _query_path_weight(terms: list[str], demote_docs: bool = True) -> any;

"""Combined query scorer returning the existing ranked `(score, node_id)` list.

    Backwards-compatible thin wrapper around `_score_query` for path, explain,
    tests, and every other caller that only needs the combined ranking. The
    per-term seed metadata computed by `_score_query` (when requested) is
    discarded here so existing callers see no API or runtime-cost change.
    """
def _score_nodes(G: nx.Graph, terms: list[str]) -> list[tuple[float, str]];

"""Single-pass combined scorer that optionally also records the best seed
    for each normalized query token.

    The combined ranking is byte-identical to what `_score_nodes` produced
    before the refactor; `_score_nodes` is now a thin wrapper that asks for
    `collect_per_term_seeds=False` and returns only `.ranked`.

    When `collect_per_term_seeds=True`, the per-token singleton winner is
    computed alongside the combined score in the *same* per-node visit (it
    reuses the same `norm_label` / `label_tokens` / `source` already evaluated
    for the combined tier), so `_query_graph_text` can feed `best_seed_by_term`
    straight into `_pick_seeds` and skip the T additional whole-graph rescoring
    passes the old per-token `_score_nodes([token])` loop ran.

    Singleton-winner semantics match the legacy per-token path exactly. The
    score itself mirrors `_score_nodes([token])` with `n_terms == 1` (so the
    coverage term is 1 and the per-token tier is unscaled) plus the broader
    joined-singlet tier (which also checks `label_tokens` and `nid_lower`).
    Tie-break order is (1) highest singleton score, (2) highest graph degree,
    (3) shortest displayed label, (4) lexicographically smallest node id —
    exactly what `max(tied, key=degree)` over a sort by `(-score, label_len,
    nid)` produced in the legacy `_pick_seeds` per-token loop. The combined
    trigram candidate set (needles `norm_terms + [joined]`) is a superset of
    each per-token `[t]` candidate set, so iterating combined candidates
    discovers every non-zero singleton-score node for every term.
    """
def _score_query(
    G: nx.Graph, terms: list[str], *, collect_per_term_seeds: bool, path_weight=None
) -> _QueryScores;

"""Pick a path endpoint from a _score_nodes result, preferring full-token matches.

    The full-query tier in _score_nodes only fires when the query equals or
    prefixes a label, so a query that is a token *subset* of the intended label
    (query "Reject-everything judge" vs. label "Degenerate Reject-Everything
    Judge") gets no bonus, and a node prefix-matching one rare token (label
    "Rejection Summary") can out-score it on IDF alone. Committing to scored[0]
    then anchors the path on an unrelated — often disconnected — node and yields
    a false "No path found". Scan the score-ordered list and take the first
    candidate whose label contains EVERY query token; when the top candidate
    already full-matches, or no candidate does, this is exactly scored[0].

    `scored` must be non-empty (both callers return early on no match).
    """
def _pick_scored_endpoint(G: nx.Graph, scored: list[tuple[float, str]], query: str) -> str;

"""Select BFS seed nodes, stopping when score drops too far below the top.

    Prevents high-frequency noise terms (error, exception) from stealing seed
    slots from a dominant identifier match. When FooBarService scores 1000 and
    error nodes score 1.0, only FooBarService is seeded — the score gap is 99.9%
    which is well above the 20% threshold that would allow additional seeds.

    That same gap_ratio cutoff has a failure mode on multi-term natural-language
    queries: if one term happens to hit an EXACT label match on a node that is
    otherwise unrelated to the query's intent (e.g. a common word that is also
    used as an unrelated identifier or field name elsewhere in the corpus), it
    can outscore every SUBSTRING match on the query's other, actually-relevant
    terms by ~1000x (see `_EXACT_MATCH_BONUS` vs. `_SUBSTRING_MATCH_BONUS`).
    The 20%-gap cutoff then silently discards all of those substring-tier
    seeds, so the BFS traversal only ever explores the neighborhood of the one
    unrelated exact match — see #1445.

    When `G` and `best_seed_by_term` are supplied, this guarantees at least one
    seed per distinct query term that has any match at all, so one term's
    incidental collision cannot starve out the others. The per-token winners
    in `best_seed_by_term` are precomputed by `_score_query` (during the same
    traversal that produced `scored`) so this function no longer rescores the
    graph per term — see #1445 and the `_score_query` docstring. The #1766
    label cap yields to this guarantee only when the term is absent from the
    shared label, since a seeded same-label node then can't cover it (#5027).

    Coverage scaling in _score_nodes (#1602) now dampens a lone collision's
    exact tier on multi-term queries, which brings label-matching relevant
    nodes back inside the gap window; this per-term guarantee remains
    load-bearing for relevant nodes matched only via substrings, whose flat
    scores a dampened collision can still exceed.
    """
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

"""Append edges between visited nodes that the traversal never recorded (#2323).

    Both traversals only record an edge that *discovers* an unvisited neighbour,
    so what they return is a traversal tree, not the induced subgraph over the
    nodes they return. `_bfs` marks every seed visited up front, so an edge
    between two seeds can never be recorded — the reported symptom, where both
    endpoints render and the edge between them does not. It drops ordinary
    cross-edges for the same reason. `_dfs` appends on push rather than on
    visit, so it already captured those; its one gap is an edge between two
    non-seed hubs, since neither endpoint is ever expanded.

    Scans only edges incident to `visited`, so cost tracks the subgraph rather
    than the whole graph, bounded by O(2E) overall. A visited hub is rescanned
    in full even though the traversal deliberately did not expand it — that is
    unavoidable, since a hub-to-hub edge is exactly the case `_dfs` misses.
    `G` here is the context-filtered `traversal_graph` (see
    `_query_graph_text`), so a filtered-out relation cannot reappear.

    Self-loops are skipped. A recursive function legitimately carries one, but
    neither traversal has ever recorded one (`n` is always already visited when
    its own self-loop is examined), and surfacing them is a separate output
    change from the missing edges reported here.

    Dedup keys on the ordered pair for directed graphs and the unordered pair
    otherwise: on a DiGraph `u->v` and `v->u` are genuinely distinct edges
    (mutual recursion, circular imports), and collapsing them would drop a real
    one. On a multigraph the traversal still records one entry per pair; the
    renderer expands it into one line per parallel edge (`_subgraph_to_text`,
    #4500).

    Traversal edges keep their discovery order; completions are appended after.
    """
def _complete_induced_edges(G: nx.Graph, visited: set[str], edges_seen: list[tuple]) -> None;

def _bfs(G: nx.Graph, start_nodes: list[str], depth: int) -> tuple[set[str], list[tuple]];

def _dfs(G: nx.Graph, start_nodes: list[str], depth: int) -> tuple[set[str], list[tuple]];

"""Render subgraph as text, cutting at token_budget (approx 3 chars/token).

    seeds: exact-match nodes rendered first before the degree-sorted expansion,
    so the queried symbol always appears at the top of the output.

    scores: `query`'s node scores. When given, the answer is file-first: seeds
    and then the other nodes are grouped by file, best-scoring file first.
    """
def _subgraph_to_text(
    G: nx.Graph,
    nodes: set[str],
    edges: list[tuple],
    token_budget: int = 2000,
    *,
    seeds: list[str] | None = None,
    scores: dict[str, float] | None = None,
) -> str;

"""Render pre-built lines under the same ~3-chars/token budget rule as
    _subgraph_to_text; over-budget output is cut at a line boundary with a count and a
    narrowing hint instead of flooding the caller's context window."""
def _cut_lines_to_budget(lines: list[str], token_budget: int, narrow_hint: str) -> str;

"""Render a graph path for the query header.

    Relative to the CWD when it sits underneath it — `graphify-out/graph.json`,
    which is the ordinary case and stays short. Absolute otherwise, because a
    graph outside the directory you are standing in is precisely the situation
    the header exists to make visible (#2789). Always POSIX separators so the
    line reads the same on either platform. Falls back to the path as given if
    it cannot be resolved; this is a display helper and must never be the reason
    a query fails.
    """
def _display_graph_path(graph_path: str) -> str;

"""Undirected copy of `G` for BFS/DFS, with true direction kept per edge.

    `_load_graph` forces `directed: True` so renderers can recover stored arc
    order (#2309), and on a DiGraph `G.neighbors()` yields successors only. The
    query traversals rely on `neighbors()`, so a seed with no outgoing edges — a
    leaf function that is only ever called, imported and contained — expanded
    to nothing: `query_graph` over MCP answered with the seed alone while the
    CLI `query`, which loads the same file undirected, returned the callers,
    the test and the neighbouring modules. Every other MCP tool was unaffected:
    `get_neighbors` walks successors and predecessors explicitly, and
    `shortest_path` builds its own graph from `_src`/`_tgt`.

    Mirrors the CLI loader: traverse undirected, stash `_src`/`_tgt` on each
    edge so `_subgraph_to_text` still renders caller->callee regardless of the
    side the traversal reached the edge from. Markers already present on an
    edge win, for the same reason as in the CLI (#2309). An undirected input is
    returned as-is, so the CLI path is unchanged.

    Mutual arcs `u->v` and `v->u` (mutual recursion, a circular import) fold
    into one undirected edge on a plain `DiGraph` input, the later one winning
    — the same fold the CLI loader performs when `json_graph.node_link_graph`
    reads the undirected on-disk graph into an `nx.Graph`, which is what keeps
    the two surfaces' output identical. The renderer shows one edge per pair
    in any case. On a `MultiDiGraph` input the copy is a `MultiGraph` and the
    stored keys are not carried over: a key is unique per unordered pair on an
    undirected multigraph, so mutual arcs that happen to share a key would
    fold there too; letting networkx assign the keys keeps both, and nothing
    downstream reads the key.

    Built once per graph object and cached on `G.graph`, like the trigram index.
    It used to be rebuilt on every query, copying every edge of the graph, which
    was most of a warm `query_graph` call. Sharing it is safe because nothing
    downstream writes to it: `_filter_graph_by_context` builds a new graph when
    a filter applies, and the traversals and the renderer only read. A hot
    reload swaps in a fresh `G`, so a cached view never outlives its graph.
    """
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

"""Nodes whose source_file matches path_part and label/id matches symbol_part.

    Backs the `path::Symbol` query form (#3485): a bare path resolves to the
    FILE node (`_find_node_tiers`'s own `source_exact` tier, which prefers
    the file over its members once #2032-disambiguated), and a bare symbol
    name can be ambiguous across files -- the same-named local declaration
    guard from #3176 exists for exactly that case, and its own suggested
    retry ("the repo-relative path") pointed at a form that resolved to the
    wrong node or nothing at all, since no prior tier combined a path with
    a label. This combines both constraints in one query, so a specific
    symbol in a specific file is reachable without needing its opaque id.
    """
def _resolve_path_scoped_symbol(G: nx.Graph, path_part: str, symbol_part: str) -> list[str];

"""Does the RAW, unsplit query already exact-match some node's own label/id?

    Mirrors the `exact` tier's own condition below, run early and standalone so
    `_find_node_tiers` can tell a literal `::`-bearing label (Rust modules, C++
    namespaces) from a deliberately path-scoped query before choosing between
    them. A real label essentially never equals a whole `path::symbol` string
    verbatim, so this is a safe way to prefer the literal interpretation
    whenever one genuinely exists.
    """
def _label_has_literal_exact_match(G: nx.Graph, term: str, norm_query: str) -> bool;

with entry {
    _PY_QUALIFIED_RE = re.compile(
        "^([A-Za-z_]\\w*(?:\\.[A-Za-z_]\\w*)*)[.:]([A-Za-z_]\\w*)(?:\\(\\))?$"
    );
}

"""Nodes named by a dotted Python symbol such as `pkg.mod.func` (#4366)."""
def _resolve_python_qualified(G: nx.Graph, label: str) -> list[str];

with entry {
    _TYPE_MEMBER_RELATIONS = frozenset({"method", "defines", "contains"});
    _QUALIFIED_MEMBER_RE = re.compile(
        "^([A-Za-z_]\\w*(?:\\.[A-Za-z_]\\w*)*)\\.([A-Za-z_]\\w*)(?:\\(\\))?$"
    );
}

"""A node's label folded to its bare name, so the member `.Build()` reads `build`."""
def _symbol_name(d: dict) -> str;

"""`(owner chain, member)` of a `Type.Member` query, folded, or None for another form."""
def _split_qualified_member(label: str) -> tuple[list[str], str] | None;

def _named_nodes(G: nx.Graph, name: str) -> list[str];

"""The members of *nid* (``members=True``) or the nodes that own it.

    Direction comes from the edge's `_src`/`_tgt` markers (#2309, and the CLI
    loaders that read a graph undirected stamp them on every link), else from
    the stored arc of a directed graph. An undirected edge without markers says
    nothing about which end owns the other, so it is skipped: counting it both
    ways would let a member pose as its type's owner.
    """
def _membership_neighbors(G: nx.Graph, nid: str, *, members: bool) -> list[str];

"""Is *nid* nested in types named by *outer*, outermost first?"""
def _enclosed_by(G: nx.Graph, nid: str, outer: list[str]) -> bool;

"""Nodes named `qualifiers[-1]` that own members, nested as the rest of the chain says."""
def _qualified_member_owners(G: nx.Graph, qualifiers: list[str]) -> list[str];

def _members_named(G: nx.Graph, owners: list[str], member: str) -> list[str];

"""Is *label* a file name (`utils.py`) or path some node was extracted from?

    Case-insensitive, like the `source_exact` tier's own path match.
    """
def _names_source_file(G: nx.Graph, label: str) -> bool;

"""Member nodes named by `Type.Member` through their declaring type (#4884).

    A file name such as `config.json` has the same shape, and names the file
    even when a `Config` type declares a `Json` member, so it resolves nothing.
    A namespace qualifier (`Acme.Io.Type.Member`) matches nothing either: the
    file, not the namespace node, owns the type, so only enclosing types can
    qualify it.
    """
def _resolve_qualified_member(G: nx.Graph, label: str) -> list[str];

"""Refusal for a `Type.Member` endpoint whose type declares no such member (#4884).

    Scoring the query instead lands on the type itself, so a path to the type
    reads as a path to the member. Returns None when the query is a node's own
    id or label, or a file name, or when no type of that name owns members:
    those keep their ordinary match. Same-named members of a type with that bare
    name (a namespace-qualified query, say) are listed for a retry.
    """
def _no_member_match_message(G: nx.Graph, label: str) -> str | None;

"""Return match tiers in precedence order: (source_exact, exact, prefix, substring).

    Split out of `_find_node` so callers that must not guess between equally-good
    matches can inspect the winning tier alone. `_find_node` flattens these, and
    its consumers take `[0]` — which resolves by graph-iteration order when one
    tier holds several nodes from different files. See `find_node_ambiguity`.
    """
def _find_node_tiers(G: nx.Graph, label: str) -> tuple[list[str], list[str], list[str], list[str]];

"""Return node IDs whose label or ID matches the search term (diacritic-insensitive).

    Results are ordered by precedence: exact source-file path match first, then
    exact (label/ID) match, then prefix match, then substring match. Node-ID exact
    matches are grouped with label exact matches.
    """
def _find_node(G: nx.Graph, label: str) -> list[str];

"""Return rival candidates when the winning match tier spans several source files.

    `_find_node` ranks matches but never reports that a tie was broken, so callers
    taking `[0]` present one arbitrary file as the answer. Two workspaces that each
    define `MetricsPort` put both nodes in the same `exact` tier, separated only by
    `G.nodes()` iteration order — reorder the graph and the same query answers with
    a different file, equally confidently.

    Returns one representative node id per distinct file (repo plus source file)
    when the winning tier is split that way, else `[]`. Several matches *within one file* (a file
    node plus its members) are ordinary precedence, not ambiguity, and return `[]`.

    `_disambiguate_file_node_labels` (#2032) already relabels colliding *file*
    nodes; this covers the symbol case it does not reach.
    """
def find_node_ambiguity(G: nx.Graph, label: str) -> list[str];

"""One node id per distinct file in *tier*, or `[]` for a single file.

    A file is its repo plus its source_file. A merged graph keeps source_file relative
    to each repo, so two repos that both have `dup.py` hold two files, not one (#4512).
    A single-repo graph has no `repo` attribute and groups by source_file alone.
    """
def _rivals_across_files(G: nx.Graph, tier: list[str]) -> list[str];

"""`No exact match`, then the substring matches that are the closest names (#3917).

    A substring tier means the query sits *inside* a label (`mailcontroller` ->
    `EmailController`), so a hit is a search result, not the symbol the caller
    named. Listing them, labelled as substring hits, lets the caller retry with
    the real name instead of trusting a different node as the answer.
    """
def _near_miss_message(G: nx.Graph, label: str, hits: list[str], *, limit: int = 5) -> str;

"""Shared node resolution for the `explain` CLI command and the get_node /
    get_neighbors MCP tools.

    Returns ``(node_id, None)`` when *label* resolves to a single winner via the
    tiered `_find_node` ranking, or ``(None, message)`` when there is no match or
    the winning tier holds several nodes, in different files or in one, as the
    `path` endpoints refuse them. Routing both tools through this keeps get_node
    from silently returning a `G.nodes()` iteration-order match for a hub name
    while get_neighbors reports the same lookup as ambiguous (#ADR-0001).

    A prefix match still resolves: the caller started typing the real name
    (`Email` -> `EmailController`). A substring match does not: the query sits
    in the middle of an unrelated label (`MailController` -> `EmailController`),
    which is a search hit, so it comes back as a near miss with suggestions
    instead of a different node presented as the answer (#3917).

    A node id names exactly one node, so it resolves before any ranking: the
    refusals tell the caller to retry with the id, and an id that tokenizes
    like a source path must not lose to that file's node (#5343).
    """
def _resolve_single_node(G: nx.Graph, label: str) -> tuple[str | None, str | None];

"""Refuse a `query`/`--seed` value only when it is a literal node NAME that
    matches several nodes, not when it is merely a search keyword.

    `query` doubles as keyword search, so a bare term that prefix- or
    substring-matches several labels (`client` -> `AlphaClient`, `BetaClient`) is a
    legitimate exploratory search and must still score, not be refused. Only an
    EXACT-tier tie (the term is itself the name of two or more nodes, as in #4511's
    `.nonce()`) is a genuinely ambiguous node reference and gets the same refusal
    `explain`/`path` give. Returns the refusal message, or None to fall through to
    scoring. (`explain`/`path`/get_node keep using `_resolve_single_node`, where a
    prefix shorthand still resolves but a substring hit is a near miss, not an answer.)
    """
def _query_name_refusal(G: nx.Graph, label: str) -> str | None;

"""Refusal message when the winning *tier* names more than one node, else None.

    Shared by `explain`, get_node / get_neighbors and the `path` endpoints so all
    of them refuse the same lookups. A file-path query is the one exception: its
    tier is the file node followed by its members, which is precedence, not a tie.
    """
def _tier_refusal(G: nx.Graph, label: str, tier: list[str], *, file_query: bool) -> str | None;

with entry {
    _AMBIGUOUS = "Ambiguous: ";
}

"""True for a refusal that lists candidates, False for a miss (no node matched)."""
def _is_ambiguity_refusal(message: str | None) -> bool;

def _ambiguity_message(G: nx.Graph, label: str, rivals: list[str]) -> str;

def _same_file_ambiguity_message(G: nx.Graph, label: str, hits: list[str]) -> str;

"""Refusal for a `file::symbol` endpoint whose file defines no such symbol (#4264).

    Fail closed like `explain` instead of scoring the bare name across other
    files, and name the files that DO define the symbol so the user can retarget.
    """
def _no_scoped_match_message(G: nx.Graph, path_part: str, symbol_part: str) -> str;

"""Resolve one endpoint of the `path` CLI / `shortest_path` tool (#3913).

    A hit in `_find_node`'s exact tiers — the `path::symbol` form, a full node
    id, an exact label or source path — names the node outright, so it is used
    as-is, and refused with the candidate list when it spans several files (the
    answer `explain` gives). Scoring alone tokenized those forms instead: the
    path half of `path::symbol` pulled the route to the file node, and an id's
    tokens to its containing class. Only a query without an exact hit falls
    through to `_score_nodes`, which ranks the multi-word and partial labels
    the tiers cannot.

    Several hits in one file are refused too, unless the query is a file path
    (whose tier is the file node followed by its members): two same-named
    symbols of one file were split by graph order behind a score-tie warning,
    and `path::symbol` cannot separate them — only the node id can.

    A name made of words the graph doesn't know is a miss, not the top of a
    weak ranking (#5079): `explain` already answers "No node matching" for it,
    and routing from the closest-sounding label instead prints a path through
    a symbol nobody asked about.

    An exact node-id key wins outright: it cannot name another node, so the
    tier match below must not turn it into an ambiguity with a label whose
    tokens normalize to the same words (#5361) — the same precedence
    `_resolve_single_node` gives an id for `explain` (#5343).

    Returns ``(node_id, scored, None)``, where ``scored`` is empty unless the
    score fallback picked the node; ``(None, [], message)`` when ambiguous; and
    ``(None, [], None)`` when nothing matches.
    """
def _resolve_path_endpoint(G: nx.Graph, query: str) -> tuple[str
    | None, list[tuple[float, str]], str | None];

"""Whether every word of the query occurs in some node's name.

    Scoring ranks by token overlap, so a made-up name still finds candidates:
    `zzqqxx_no_such_symbol_9137` matches `no_such_symbol_helper()` on `no`,
    `symbol` and `helper`, and the route through that symbol prints as if it
    were the one asked for (#5079). The scored fallback is only honest when
    the query is at least partly in the graph's vocabulary, so each token has
    to occur somewhere — then the query shares a word with what it routes
    through (`Rejection judge` -> `Rejection Summary`, its tokens once said
    whole). A token that appears nowhere (`zzqqxx`, `9137`) means the name the
    caller asked for isn't in the graph, which is what `explain` reports too.

    Looser than `explain`'s resolution on purpose: there any substring hit is
    a "near miss" worth refusing with suggestions, but `path` answers with a
    route rather than a name, and a caller still typing (`draft-generator` for
    `draft-generator.ts`) needs the score fallback's ranking.

    One pass per token, each stopping at the first node that carries it; the
    vocabulary is `_search_tokens` pieces of labels and ids, the same split the
    scorer uses.
    """
def _query_uses_known_words(G: nx.Graph, terms: list[str]) -> bool;

"""The sorted, materialized graph `_shortest_path_text` searches.

    Deterministic path (#2074): the hash-seeded undirected view picked an
    arbitrary route among equal-length paths, so the search runs on a graph
    built from sorted node and edge lists, which makes the chosen path
    canonical. Serve's shared G is left untouched (its degree feeds query-seed
    tie-breaks).

    Built once per graph object and direction mode, and cached on `G.graph`
    like the trigram index: rebuilding it from every edge was nearly all of a
    `shortest_path` call. Only `nx.shortest_path` reads it, and a hot reload
    swaps in a fresh `G`, so a cached graph never outlives its source.
    """
def _path_search_graph(G: nx.Graph, undirected: bool) -> nx.Graph;

"""The weakest hop of a path, or None when no hop carries confidence.

    Each hop is ranked by the weakest evidence it carries (`_CONFIDENCE_RANK`,
    then the lowest `confidence_score`; a missing score never counts as weaker
    than a present one). EXTRACTED is 1.0 by definition, so its score is neither
    ranked nor printed, matching the per-hop tags. Returns
    `(key, hop, rel, conf, score)` where `key` sorts weakest-first.
    """
def _path_weakest(hop_datas: list[list[dict]]) -> any;

"""Overall confidence of a path: its weakest hop (#4885).

    A path is only as sure as its least certain hop (see `_path_weakest`). A hop
    with no recognised confidence tag ranks below AMBIGUOUS and makes the whole
    path unknown.
    """
def _path_confidence_line(hop_datas: list[list[dict]]) -> str;

with entry {
    _MAX_SHORTEST_PATHS = 256;
}

"""Per-hop edge-data lists for a node path, honouring `_src` direction
    markers (#2309) the same way the path renderer does."""
def _path_hop_datas(G: nx.Graph, path_nodes: list[str]) -> list[list[dict]];

"""Sortable, weakest-first key for a whole path. A path that carries no
    confidence evidence at all is 'unknown' and sorts below any tagged path."""
def _path_confidence_key(hop_datas: list[list[dict]]) -> any;

"""Count of intermediate hops this path passes through a sourceless hub
    node (#5153): a node with no `source_file`, almost always a stdlib/
    third-party import stub that hundreds of unrelated files import. Such a
    node carries no semantic claim about how the two endpoints relate, so a
    route through it is a true shortest path but not a meaningful one — the
    weakest-hop tiebreak alone cannot tell it apart from a route of plain
    `imports`/`contains` edges between real files, since both can carry the
    identical EXTRACTED confidence on every hop. Endpoints are never counted:
    the caller explicitly asked about them, hub-ness or not.
    """
def _path_hub_penalty(G: nx.Graph, path_nodes: list[str]) -> int;

"""Among all shortest paths `src_nid` -> `tgt_nid`, the most conservative one.

    A path is only as sure as its weakest hop, so when several routes tie on
    length the reported confidence should reflect the weakest of them, not an
    arbitrary route networkx happens to return first (#4881). A route through
    a sourceless import hub (`_path_hub_penalty`) is preferred away from
    first, since it is "shortest" by accident of degree rather than by
    carrying any claim about the two endpoints (#5153); the weakest-hop rule
    then still breaks any further tie among the remaining, equally
    hub-free routes. Enumeration is bounded by `_MAX_SHORTEST_PATHS`. Raises
    `nx.NetworkXNoPath` / `nx.NodeNotFound` exactly like `nx.shortest_path`,
    so callers keep their existing error handling. Returns `(path_nodes,
    n_routes, capped)`.
    """
def _weakest_shortest_path(search_graph: nx.Graph, G: nx.Graph, src_nid: str, tgt_nid: str) -> any;

"""An edge's confidence label, with its stored score when it carries one.

    Renders ``INFERRED 0.75`` for a scored non-EXTRACTED edge (#4882).
    EXTRACTED is 1.0 by definition, so it stays bare; a missing, boolean or
    non-finite score keeps the bare label rather than printing a guess.
    """
def _confidence_tag(d: dict) -> str;

"""Body of the `shortest_path` MCP tool (module-level so tests can call it
    without an mcp install).

    Directed by default (#2487): the returned path must follow stored
    caller→callee direction; pass ``undirected=True`` to ignore it.
    """
def _shortest_path_text(G: nx.Graph, arguments: dict) -> str;

"""Filter blank lines from stdin before MCP reads it.

    Some MCP clients (Claude Desktop, etc.) send blank lines between JSON
    messages. The MCP stdio transport tries to parse every line as a
    JSONRPCMessage, so a bare newline triggers a Pydantic ValidationError.
    This installs an OS-level pipe that relays stdin while dropping blanks.
    """
def _filter_blank_stdin -> None;

def _community_header(cid: int, community_name) -> str;

"""One output line per relationship incident to ``nid``.

    Parallel edges between the same pair each render as their own line with
    their own metadata (#4500); ``edge_data()`` would return only the first.
    """
def _neighbor_lines(G: nx.Graph, nid: str, rel_filter: str = "") -> list[str];

"""Load (or reload) the target graph in a worker thread (#5371).

    ``_ctx_cache.load`` parses graph.json and builds its trigram index,
    which takes seconds on a large graph. Run on the event loop, it stops
    every other request, so the stale entry ``load`` hands concurrent
    callers during a rebuild (#5177) was never reachable. After this
    returns, ``_select_graph`` is a cache hit, or gets the current
    entry while another call's rebuild is still in flight.

    Only the load leaves the loop. ``_select_graph`` and the handler still
    run with no await between them, so the shared ``G`` cannot be rebound
    by another call in the middle of a handler.
    """
async def _warm_graph(resolve, load, project_path) -> None;

"""``run(*args)``, once ``warm`` (when given) has loaded the graph."""
async def _after_warm(warm, project_path, run, *args_) -> any;

async def _call_tool(handlers, warm, select, name: str, arguments: dict) -> any;
async def _on_list_tools(list_tools, ctx, params) -> any;

async def _on_call_tool(call_tool, ctx, params) -> any;

async def _on_list_resources(list_resources, ctx, params) -> any;

async def _on_read_resource(read_resource, ctx, params) -> any;

async def _run_stdio(server, stdio_server) -> None;

"""Build the configured low-level MCP Server (shared by every transport).

    All graph query tools and resources are registered here over a single
    ``mcp.server.Server`` instance; the caller picks the transport (stdio or
    Streamable HTTP) and runs it. Hot-reload of graph.json works the same way
    regardless of transport, since reloads happen inside the tool handlers.
    """
def _build_server(graph_path: str) -> any;

"""Start the MCP server over stdio (the default, per-developer transport)."""
def serve(graph_path: str | None = None) -> None;

async def _mcp_asgi_call(app, scope, receive, send) -> None;

def _mcp_asgi_init(app, manager) -> None;

with entry {
    _MCPASGIApp = builtins.type(
        "_MCPASGIApp", (), {"__init__": _mcp_asgi_init, "__call__": _mcp_asgi_call}
    );
}

async def _api_key_call(gate, scope, receive, send) -> None;

def _api_key_init(gate, app, api_key: str) -> None;

with entry {
    _ApiKeyMiddleware = builtins.type(
        "_ApiKeyMiddleware", (), {"__init__": _api_key_init, "__call__": _api_key_call}
    );
}

"""Build the Starlette ASGI app for the Streamable HTTP transport.

    Split out from :func:`serve_http` (which blocks on uvicorn) so the wiring
    can be exercised with an in-process ASGI test client.

    ``session_timeout`` reaps stateful sessions idle for that many seconds so a
    long-running shared server does not leak memory when IDE clients disconnect
    without sending a DELETE. ``None`` (or <= 0) disables reaping; it is forced
    to ``None`` in stateless mode, which has no sessions to reap.
    """
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

"""Start the MCP server over Streamable HTTP (MCP spec 2025-03-26).

    Serves the same tools/resources as the stdio transport, so a single shared
    process can host the graph for a whole team. Clients point their IDE MCP
    config at ``http://<host>:<port><path>`` (default ``/mcp``).

    ``api_key`` (or the ``GRAPHIFY_API_KEY`` env var) enables a simple header
    check (``Authorization: Bearer <key>`` or ``X-API-Key: <key>``). OAuth is a
    deliberate follow-up. Binding ``0.0.0.0`` exposes the server beyond
    localhost — set an api_key when you do.
    """
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
) -> None;

def _main(argv: list[str] | None = None) -> None;

with entry:__main__ {
    _main();
}
