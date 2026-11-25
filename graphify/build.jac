import importlib;
import operator;
import from __future__ { annotations }

import json;

import math;

import os;

import re;

import sys;

import unicodedata;

import from collections.abc { Iterable }

import from pathlib { Path }

import networkx as nx;

glob _AST_LOC_RE: any;

glob _GENERIC_RELATIONS: frozenset[str];

glob _STRUCTURAL_MEMBER_RELATIONS: frozenset[str];

glob _MEMBER_USAGE_RELATIONS: frozenset[str];

glob _CONFIDENCE_RANK: dict[str, int];

glob _EVIDENCE_KEYS: tuple[str, ...];

glob _EXTERNAL_STUB_RELATIONS: frozenset[str];

glob _EDGE_LANG_FAMILY: dict[str, str];

glob _FILE_TYPE_SYNONYMS: any;

glob _HE_MEMBER_ALIASES: any;

glob _MCP_GLOBAL_ID_KINDS: any;

with entry {
    _AST_LOC_RE = re.compile("^L\\d");
}

"""AST vs semantic tier. _origin wins when present; unstamped legacy items
    (pre-0.9.16) fall back to shape: deterministic extractors emit
    source_location 'L<line>', the semantic spec emits null (#2334)."""
def _is_ast_tier(item: dict) -> bool;

"""Stamp a loaded legacy item's tier via the _is_ast_tier shape fallback (#2334).

    External import stubs are skipped, and a stamp an earlier run gave one is
    removed: a stub is re-minted from its edges on every write, so a stamped
    copy differed from a fresh build and, read as ``semantic``, was kept after
    its last import edge was gone. Unstamped, every tier decision reads it
    exactly as before (the shape fallback says non-AST).
    """
def _backfill_origin(item: dict) -> None;

"""Saved semantic nodes whose ids are absent from the new graph.

    A node created in this run is not in ``saved_nodes``, so a sourceless stub
    cannot stand in for a missing id. ``deleted_sources`` is the files the user
    removed. A code rebuild is not a deletion: do not pass the rebuilt set.

    An auto-minted import stub (``external`` true, or ``type`` ``external``) is
    rebuilt from the import edges of this run. Dropping one is not a lost
    rationale or document node.

    ``folded`` (when given) maps each saved node id that build_from_json merged
    into an AST twin to that twin's id, so a caller comparing node counts can
    discount it.

    ``dedup_remap`` is the ``{merged-away id: survivor id}`` map entity dedup
    produced this run (#4940). A saved id it folded into a survivor that is in
    the new graph is one node, not a lost one. A survivor that is itself gone
    excuses nothing: the content went with it.
    """
def _lost_saved_semantic_nodes(
    saved_nodes: list,
    new_nodes: list,
    deleted_sources: set[str] | None = None,
    folded: dict[str, str] | None = None,
    dedup_remap: dict[str, str] | None = None,
) -> list[dict];

"""How many fewer nodes the graph may have because dedup merged saved ids (#4940).

    Merging N saved ids into one survivor removes N - 1 nodes when the survivor
    is new this run, and N when it is itself a saved id (that one stays in the
    count of the old graph). Only merges whose survivor is in the new graph
    count: a missing survivor is a loss, not a merge.
    """
def _dedup_shrink_allowance(saved_ids: set, new_ids: set, dedup_remap: dict[str, str]) -> int;

with entry {
    _GENERIC_RELATIONS = frozenset({"references", "uses", "mentions"});
    _STRUCTURAL_MEMBER_RELATIONS = frozenset({"method", "contains"});
    _MEMBER_USAGE_RELATIONS = frozenset({
        "calls",
        "indirect_call",
        "instantiates",
        "uses_static_prop",
        "references_constant",
    });
    _CONFIDENCE_RANK = {"EXTRACTED": 3, "INFERRED": 2, "AMBIGUOUS": 1};
    _EVIDENCE_KEYS = ("confidence", "confidence_score", "source_file", "source_location");
}

"""The provenance fields of one edge (or ``also_seen`` entry), scalars only."""
def _evidence(attrs: dict) -> dict;

def _evidence_sort_key(ev: dict) -> tuple;

"""Every provenance record an edge carries: its own, then each ``also_seen``."""
def edge_evidence(d: dict) -> list[dict];

"""Record ``loser``'s provenance on ``winner`` when the two collapse (#4881).

    Entries that repeat the winner's own provenance, or each other, are dropped,
    so re-feeding a written graph.json through the build is idempotent.
    """
def _fold_also_seen(winner: dict, loser: dict) -> None;

with entry {
    _EXTERNAL_STUB_RELATIONS = frozenset({"imports", "imports_from", "re_exports"});
}

"""Add a leaf node for an external import target so the edge is not dangling.

    The node is tagged ``external`` (and ``file_type='concept'`` so the schema
    validator and community/report code treat it as a non-source concept rather
    than warning on a missing ``file_type``). ``merge-graphs`` reads the
    ``external`` flag to keep these ids global instead of namespacing them per
    repo, so the same stdlib/dependency module unifies across repos (#2873).
    """
def _mint_external_stub(G: "nx.Graph", node_set: set, nid: str) -> None;

"""True for a node minted by :func:`_mint_external_stub` / :func:`mint_external_stubs_in_data`.

    A stub is derived from the import edges that point at it and is minted again
    on every write, so it belongs to no extraction tier: the tier backfill must
    not stamp it (a ``semantic`` stamp made it outlive its last import edge), and
    a rebuild drops it once no edge references it.
    """
def _is_external_stub(item: dict) -> bool;

"""Mint external stub nodes for import-family links with an undeclared target.

    The ``--no-cluster`` / incremental write path serializes the raw merged
    extraction directly rather than going through :func:`build_from_json`, so it
    needs the same stubbing to keep the on-disk graph.json free of undeclared
    edge endpoints (#2873). Idempotent: a graph already carrying its stubs (from
    a prior run or the clustered path) is left unchanged.
    """
def mint_external_stubs_in_data(data: dict) -> None;

"""Apply build_from_json's endpoint rules to a raw (``--no-cluster``) graph.

    The clustered path builds the graph with :func:`build_from_json`, which mints
    a typed stub for an import of an external module (#2873) and drops every
    other edge it cannot attach to two declared nodes, after re-pointing an
    endpoint that differs from a declared id only by normalization. The raw
    write paths skip build_from_json, so graph.json kept those edges: a loader
    turns each missing endpoint into an attribute-less phantom node, and a link
    to a missing markdown document kept the target id the extractor built from
    the absolute checkout path.

    A stub is derived from the import edges that point at it, so a stub carried
    over from an earlier graph that no edge references any more is dropped too;
    a fresh build of the same tree would not have it.

    Re-pointing an endpoint also needs the alias index, not just
    normalization: a framework-style ``#import <Kit/ToolEvent.h>`` resolves to
    a real header whose file node is ``kit_event_toolevent``, but the edge the
    extractor emitted names the header by its bare basename (``toolevent``).
    Normalization alone cannot bridge those two ids, so the raw path used to
    mint an external stub for the import and leave the edge on it while the
    clustered path re-pointed it at the real file (#4670). Resolving against the
    shared alias index makes both write paths agree, and only a genuinely
    external import (e.g. ``<Foundation/Foundation.h>``) is left to mint a stub.
    """
def finalize_raw_graph_endpoints(data: dict) -> None;

with entry {
    _EDGE_LANG_FAMILY = {
        ".py": "py",
        ".pyi": "py",
        ".js": "js",
        ".mjs": "js",
        ".cjs": "js",
        ".jsx": "js",
        ".ts": "js",
        ".tsx": "js",
        ".mts": "js",
        ".cts": "js",
        ".go": "go",
        ".rs": "rs",
        ".java": "jvm",
        ".kt": "jvm",
        ".scala": "jvm",
        ".groovy": "jvm",
        ".c": "c",
        ".h": "c",
        ".cc": "c",
        ".cpp": "c",
        ".hpp": "c",
        ".cxx": "c",
        ".hh": "c",
        ".hxx": "c",
        ".cu": "c",
        ".cuh": "c",
        ".metal": "c",
        ".m": "c",
        ".mm": "c",
        ".rb": "rb",
        ".rake": "rb",
        ".php": "php",
        ".cs": "cs",
        ".swift": "swift",
        ".lua": "lua",
        ".vue": "js",
        ".svelte": "js",
        ".astro": "js",
        ".ejs": "js",
        ".kts": "jvm",
        ".gradle": "jvm",
        ".vb": "cs",
        ".razor": "cs",
        ".cshtml": "cs",
        ".xaml": "cs",
        ".phtml": "php",
        ".php3": "php",
        ".php4": "php",
        ".php5": "php",
        ".php7": "php",
        ".phps": "php",
        ".luau": "lua",
        ".cbl": "cobol",
        ".cob": "cobol",
        ".cobol": "cobol",
        ".cpy": "cobol",
        ".r": "r",
        ".sol": "solidity",
        ".erl": "erlang",
        ".hrl": "erlang",
        ".escript": "erlang",
        ".zig": "zig",
        ".ex": "elixir",
        ".exs": "elixir",
        ".jl": "julia",
        ".dart": "dart",
        ".sql": "sql",
        ".sh": "shell",
        ".bash": "shell",
        ".ps1": "powershell",
        ".psm1": "powershell",
        ".psd1": "powershell",
    };
    _FILE_TYPE_SYNONYMS = {
        "markdown": "document",
        "text": "document",
        "tool": "code",
        "library": "code",
        "pattern": "concept",
        "principle": "concept",
        "constraint": "concept",
        "tech": "concept",
        "technology": "concept",
        "data-source": "concept",
        "data_source": "concept",
        "gotcha": "concept",
        "framework": "concept",
    };
    _HE_MEMBER_ALIASES = ("members", "node_ids");
}

"""Coerce a hyperedge member list to hashable scalar ids, deduped in order.

    LLM/subagent drift sometimes emits a member as an object (``{"id": "a_ts"}``)
    instead of a bare id string. Left uncoerced, the dict member is unhashable,
    so the semantic-rekey pass's ``_rekey.get(n, n)`` raised ``TypeError`` and
    aborted the whole merge — destroying a completed extraction (#2486). Object
    members collapse to their non-empty ``id`` (numeric ids str-coerced via
    ``_coerce_id``, matching #2326); members with no usable id are dropped with
    a stderr WARNING naming the hyperedge, never a crash. Hashable scalar refs
    pass through unchanged. A hyperedge that loses every member this way falls
    to the existing no-valid-members drop-with-warning in ``build_from_json``.
    """
def _coerce_hyperedge_member_refs(he: dict, members: list) -> list;

"""Canonicalize a hyperedge's member list onto the `nodes` key, in place.

    If `nodes` is already a list it wins (canonical), and only stray alias keys
    are dropped. Otherwise the first alias (`members`, then `node_ids`) that is a
    list is moved to `nodes`, with a single stderr WARNING naming the hyperedge
    id and alias used. Leftover alias keys are always removed so downstream code
    never re-reads them. Whichever branch supplied the list, member VALUES are
    coerced to hashable scalar ids and deduped preserving order (#2486) — see
    ``_coerce_hyperedge_member_refs``.
    """
def _normalize_hyperedge_members(he: object) -> None;

"""Fold legacy node field aliases onto canonical keys, in place (#2194).

    ``name`` -> ``label`` and ``file``/``path``/``filepath`` -> ``source_file``
    (first non-blank alias in that order wins). Uses an empty-check (not mere
    key presence) so a node carrying ``label: ""``/``None`` next to a real
    ``name`` is healed too. When the canonical field already holds a value it
    wins and the alias key is left untouched. Without this fold an alias-only
    node enters the graph with no label/source_file: it fails validation, gets
    ``norm_label == ""`` (invisible to query/explain), and is excluded from every
    label-keyed merge/dedup — a permanent ghost that ``graphify update``
    re-feeds through build_from_json forever.

    A node-level ``confidence``/``confidence_score`` pair is folded through
    ``_fold_confidence`` too (#4529), so nodes share the normalization contract
    edges and hyperedges already have. A node without either field is left
    untouched.
    """
def _fold_node_aliases(`node: dict) -> None;

"""Fold a legacy/drifted ``confidence`` onto the enum, in place (#2194, #4495).

    Shared by nodes, edges and hyperedges, all of which can carry the same
    ``confidence``/``confidence_score`` pair and the same two failure modes.

    A NUMERIC ``confidence`` (pre-enum graphs stored the LLM pass's float —
    1.0/0.95/0.9/0.85 — directly in the field) normalizes to ``INFERRED``:
    numeric confidences only ever came from the LLM semantic pass, and
    LLM-derived edges/hyperedges are INFERRED by definition. The original
    float moves to ``confidence_score`` unless an explicit one is already
    present (the companion field is the authority). Without this fold, every
    reload of a pre-enum graph re-warns once per legacy entry, forever.
    ``bool`` is excluded despite subclassing ``int``: ``True`` is not a score.

    A non-exact-match STRING ``confidence`` is model drift from the same
    semantic pass, not a documented format — the extraction spec asks for the
    enum plus a separate ``confidence_score`` float, so anything else here can
    only have come from a model ignoring that spec, never a user or
    extractor. Two shapes of drift are folded differently:

    * A case variant of a real enum value (a lowercase ``"inferred"``) is
      corrected to its canonical uppercase spelling, nothing more — it IS the
      enum value, just mis-cased, so treating it as an unknown word and
      re-deriving ``confidence_score`` from it (next bullet) would be wrong.
    * Anything else (``"high"``, ``"confirmed"``, ``"medium-high"``, ...)
      folds like the numeric case above: a value that parses as a float
      backfills ``confidence_score``, and the field becomes ``INFERRED``
      regardless of whether it parsed. Without this, a graph with
      model-drifted string confidences re-warns on every command forever,
      identically to the numeric gap above.

    Structured JSON values (lists/objects) carry no usable confidence. They
    fall back to ``INFERRED`` without inventing a numeric score, just like
    an unrecognized nonnumeric string, before validation can hash them.

    ``confidence_score`` itself is NOT popped in either case: it is a
    legitimate companion field the edge loop sanitizes and to_json
    round-trips.
    """
def _fold_confidence(`obj: dict) -> None;

"""Fold legacy edge field aliases onto canonical keys, in place (#2194).

    ``type``/``relationship`` -> ``relation`` (``type`` checked first), then
    ``confidence``/``confidence_score`` via ``_fold_confidence`` (see its own
    docstring for the numeric and string drift cases it folds).
    """
def _fold_edge_aliases(`edge: dict) -> None;

"""Return a str for a numeric id, else the value unchanged.

    ``bool`` is excluded despite subclassing ``int``: an id of ``True`` is not a
    number the model meant to name a node, and ``"True"`` would invent a label.
    """
def _coerce_id(value: object) -> object;

"""True when value can be a dict key / set member (same probe as the
    inline ``try: hash(m)`` in build_from_json's hyperedge revalidation)."""
def _hashable(value: object) -> bool;

"""Coerce numeric node ids and edge/hyperedge references to str, in place (#2326).

    A backend can emit ``{"id": 10}`` where the schema says ``{"id": "10"}``.
    Every id consumer downstream assumes ``str``, so one int id aborted the build
    in three places: ``_pick_winner``'s ``_CHUNK_SUFFIX.search(n["id"])`` raised
    ``TypeError: expected string or bytes-like object``, and ``build_from_json``'s
    ``sorted(node_set)`` raised ``'<' not supported between instances of 'str'
    and 'int'`` — the latter for a lone node with nothing to dedup at all.
    Coercing keeps the node and its edges rather than dropping either, which is
    the same tolerate-and-heal treatment loose backend output already gets at the
    parse chokepoint (#1631) and in the alias folds (#2194).

    Endpoints and hyperedge members are coerced with the nodes, not after: a
    node-only coercion would renumber ``10`` to ``"10"`` and leave every edge
    pointing at the vanished ``10``, trading a loud crash for a silently
    disconnected graph. The legacy ``from``/``to`` endpoint aliases are included
    because dedup reads them directly (#803).

    Runs in BOTH ``build`` (before dedup, which keys on id) and
    ``build_from_json`` (the direct entry that reloads a persisted graph), for
    the same two-site reason as the ``_fold_node_aliases`` fold (#2194). It is
    idempotent, so the nested call on the ``build`` path is a no-op.

    Non-numeric non-str ids (``None``, lists, dicts) are left alone for
    ``validate_extraction`` to report: ``str(None) == "None"`` would fabricate a
    node id that no edge references.
    """
def _coerce_non_string_ids(extraction: dict) -> None;

"""Normalize path separators and relativize absolute paths.

    Converts backslashes to forward slashes (Windows compatibility) and, when
    root is provided, strips the absolute prefix from paths produced by semantic
    subagents so source_file is always repo-relative (fixes #932).
    """
def _norm_source_file(p: str | None, `root: str | None = None) -> str | None;

"""Return a form-insensitive absolute identity for a source_file.

    prune/replace matching in build_merge otherwise compares raw strings against
    ``_norm_source_file`` output, so a node whose source_file survived in a THIRD
    form — absolute where prune_sources is relative, or vice versa, or a symlinked
    root — slips past every equality check and its nodes/edges are never pruned
    (silent survival of a deleted file's graph, #2012). Anchoring relative paths
    at ``root`` and resolving both sides to a canonical absolute posix path gives
    a fallback that matches regardless of which form each side happens to hold.
    """
def _abs_identity(p: str | None, `root: str | None = None) -> str | None;

"""Match corpus paths without resolving aliases *inside* the scan root.

    A scan-root symlink is an alternate spelling of the same corpus. A source
    symlink within it is a distinct corpus entry and must not delete its target
    when excluded. Resolve only the root prefix, retaining the lexical suffix.
    """
def _prune_identity(p: str | None, `root: str | None = None) -> str | None;

"""Whether *label* is a file node's label for *source_file* — the bare
    basename, OR a directory-qualified suffix produced by the disambiguation pass
    below (#2032). Used both to recognize file nodes when relabeling and by the
    downstream file-node predicates (analyze/tree/serve)."""
def _is_file_node_label(label: "str | None", source_file: "str | None") -> bool;

"""Do not label-fold a semantic record with evidence of its own.

    A file mention can legitimately be folded into an AST file-self node,
    but such a fold discards the semantic record's independent explanation
    and attribution. Keep these records distinct unless the same-source
    (source_file, label) twin rule already matched them.

    Only genuine provenance counts. `metadata` and `captured_at` are attached
    to ordinary INFERRED mention ghosts by extract.py, so treating them as
    evidence would stop those ghosts folding and let duplicates proliferate
    on real graphs (#4896).
    """
def _has_independent_semantic_evidence(`node: dict) -> bool;

"""Shortest trailing path suffix (basename + k parent dirs) of *sf* that is
    unique among *all_sfs*. `a/b/index.ts` vs `c/b/index.ts` -> `a/b/index.ts`;
    `x/index.ts` vs `y/index.ts` -> `x/index.ts`. Derived from the path (never the
    current label) so relabeling is idempotent across incremental rebuilds."""
def _shortest_unique_suffix(sf: str, all_sfs: "set[str]") -> str;

"""Given (key, label, source_file) triples, return {key: new_label} for file
    nodes whose basename collides with another's — the shortest unique
    directory-qualified suffix (#2032). Keys of non-colliding/basename-unique file
    nodes are omitted (their label stays bare)."""
def _file_label_reassignments(items: "list[tuple]") -> dict;

"""Relabel colliding-basename file nodes on a graph (#2032). Ids/edges are
    never changed — only display labels. Idempotent (labels derive from
    source_file, not the current possibly-qualified label)."""
def _disambiguate_file_node_labels(G: "nx.Graph") -> None;

"""Relabel colliding-basename file nodes on a raw node-dict list, in place
    (#2032). Used by the extract --no-cluster path, which writes the merged
    extraction directly without going through build_from_json."""
def disambiguate_file_labels_in_nodes(nodes: "list") -> None;

"""Give C# method nodes an ``Owner.Name()`` display label (#4883). Ids and
    edges are never changed, and an undirected graph's owner side is read from
    the edge's recorded ``_src``/``_tgt``. Idempotent."""
def _qualify_csharp_method_labels(G: "nx.Graph") -> None;

"""Raw node/edge-list form of :func:`_qualify_csharp_method_labels`, in
    place, for the --no-cluster writers that bypass build_from_json (#4883)."""
def qualify_csharp_method_labels_in_nodes(nodes: "list", edges: "list") -> None;

"""Best-effort scan root for relativizing paths in build_merge when the caller
    passes no ``root`` (#1571).

    Prefers the committed ``graphify-out/.graphify_root`` marker — the authoritative
    scan root graphify records at build/watch time (#686/#1423) — then falls back to
    the directory that contains the output dir (``graph.json``'s grandparent, i.e.
    ``<root>/graphify-out/graph.json`` -> ``<root>``). The grandparent heuristic is
    applied only when ``graph.json``'s own directory actually looks like a graphify
    out-dir (named like one, or holding the marker/manifest); for arbitrary layouts
    (``<root>/graph.json``, #2446) the grandparent is NOT the scan root, and guessing
    it made absolute prune_sources silently no-op. Returns None if neither resolves,
    in which case normalization is a no-op (prior behavior) and prune matching can
    still recover via :func:`_derive_prune_root`.
    """
def _infer_merge_root(graph_path: Path) -> str | None;

"""Prune match sets for build_merge / merge_raw_extraction.

    Returns ``(prune_set, prune_abs)`` mapping every match form of each prune
    entry — the raw string and the :func:`_prune_identity` absolute form —
    back to the ORIGINAL entry, so callers
    can report which entries actually matched something (#2446). Membership
    tests read like the old set-based code (``sf in prune_set``).

    "Replace" wins over a contradictory "delete" of the same source (#1796), in
    both string and absolute-identity space (#2012): every form belonging to a
    source re-extracted this run is removed.
    """
def _build_prune_sets(
    prune_sources: "list[str] | None", eff_root: "str | None", new_sources: "set[str]"
) -> "tuple[dict[str, str], dict[str, str]]";

"""Derive the scan root from absolute prune paths that matched nothing (#2446).

    When build_merge/merge_raw_extraction receive absolute prune_sources but no
    ``root``, :func:`_infer_merge_root`'s guess can be wrong for non-standard
    layouts (``graph.json`` not under ``<root>/graphify-out/``), so every prune
    entry silently no-ops. Each absolute prune path ``P`` that ends with a
    stored RELATIVE source_file ``S`` implies the candidate root
    ``P[:-len(S)-1]``. Within one graph all relative source_files share a single
    scan root, so the candidate is accepted only when it is unique and
    consistent across every suffix-matched entry; on ambiguity (or no suffix
    match at all) returns None and the caller falls through to the zero-match
    warning.
    """
def _derive_prune_root(prune_sources: "list[str]", stored_sfs: "set[str]") -> "str | None";

"""Return one edge attribute dict for (u, v), tolerating MultiGraph.

    For MultiGraph/MultiDiGraph there can be multiple parallel edges;
    this returns the first one (sufficient for callers that only need
    relation/confidence for rendering). Fixes #796.
    """
def edge_data(G: nx.Graph, u: str, v: str) -> dict;

"""Return every edge attribute dict for (u, v); always a list."""
def edge_datas(G: nx.Graph, u: str, v: str) -> list[dict];

"""True when any two link dicts share the same endpoints.

    Used to keep the serialized ``multigraph`` flag consistent with the links
    actually stored (#4500): a simple-graph write-back can restore parallel
    links from ``original_links`` while ``node_link_data`` derived
    ``multigraph: false`` from the in-memory graph, and readers that honour
    the flag then collapse the parallel edges on load.
    """
def has_parallel_links(links: "list[dict]", directed: bool = True) -> bool;

"""Collapse nodes sharing an ``id``, last-writer-wins on attributes.

    Mirrors what ``build_from_json``'s ``G.add_node`` does implicitly (idempotent;
    a later node overwrites an earlier one's attributes). The ``--no-cluster``
    write path dumps the raw node list without building a graph, so same-id nodes
    — e.g. a Swift ``type=module`` anchor emitted once per importing file (#1327)
    — would otherwise appear as duplicates. Insertion order follows each id's
    first appearance; the retained dict is the last one seen.
    """
def dedupe_nodes(nodes: list[dict]) -> list[dict];

"""Fold the ``type_only`` marker of two import edges that collapse to one.

    ``type_only`` flags an import that never runs (``import type``, ``if
    TYPE_CHECKING:``); ``find_import_cycles`` skips such an edge. When two edges
    of one file pair collapse (``G.add_edge`` merges their attributes,
    ``dedupe_edges`` keeps the first), the marker of one side would stand for a
    runtime import on the other and hide its cycle. The surviving edge stays
    ``type_only`` only if every import folded into it is (#3159).
    """
def _execution_wins(a: dict, b: dict) -> None;

"""Collapse exact parallel edges by ``(source, target, relation)``, keeping the
    first occurrence.

    The clustered build path runs edges through a NetworkX ``DiGraph``, which
    collapses parallel edges automatically. The ``--no-cluster`` and incremental
    ``update`` write paths bypass NetworkX and concatenate edge lists raw, so
    duplicates accumulate and edge counts become non-deterministic across build
    modes / repeated updates (#1317). Deduping on the connectivity identity is
    zero-signal-loss and restores idempotency. Callers that intentionally keep
    parallel edges (multigraph output) must not use this. The one attribute that
    is not taken from the first occurrence alone is ``type_only`` (see
    :func:`_execution_wins`).
    """
def dedupe_edges(edges: list[dict]) -> list[dict];

"""Pre-migration stem forms a semantic fragment may have used for ``rel``.

    Ordered longest-first so prefix stripping is greedy and unambiguous:
      - one-parent form: ``parent.stem``  (the old _file_stem rule, #550-era)
      - zero-parent form: ``stem``        (the old llm.py prompt rule, #1509)
    """
def _old_file_stems(rel: Path) -> list[str];

"""Map every OLD-stem spelling of a node to that node's canonical id.

    The pre-migration id recipe keyed a file's node on its stem, so a file at
    ``Kit/Event/ToolEvent.h`` used to be ``toolevent`` and is now
    ``kit_event_toolevent`` (#1504/#1509). An edge endpoint still written in the
    old spelling must resolve to the migrated node instead of dangling, so each
    node registers its old-stem forms as aliases.

    An alias is committed only when EXACTLY ONE node claims it. The old-stem
    form drops the extension and every directory but the immediate parent, so
    "ping.h" and "ping.php" in different directories both alias to bare "ping";
    committing an ambiguous alias would bind an edge to whichever same-stem file
    happened to be seen first, merging unrelated files.

    A Python module whose bare stem is a stdlib name (e.g. ``scripts/logging.py``)
    must not claim the collapsed bare-stem alias ("logging"): that alias would
    capture a genuine external ``import logging`` edge and bind it to this
    same-named local file (#4261). The directory-scoped alias form
    ("scripts_logging") is still registered, so a real stale-id reference to this
    file keeps healing.

    Both the normalized and the raw spelling of every alias are registered, so
    a caller can look an endpoint up with or without normalization.

    Shared by :func:`build_from_json` and :func:`finalize_raw_graph_endpoints`
    so the clustered and the raw (``--no-cluster``) write paths resolve an
    endpoint the same way (#4670).
    """
def _alias_index(nodes: "Iterable[tuple[str, dict]]") -> dict[str, str];

"""True for an include edge written as `<name>` where name is a C/C++
    standard header (`<functional>`, `<stdio.h>`), #5218.

    Such an edge's bare-stem target (`functional`) must stay an external stub:
    the alias index would otherwise bind it to any unique same-named project
    header (`libc/include/libc/functional.h`), the C/C++ counterpart of the
    Python stdlib guard in :func:`_alias_index` (#4261).
    """
def _is_std_angle_include(`edge: dict) -> bool;

"""True unless the edge's own file and the alias target's file are both in
    a KNOWN, DIFFERENT language family (#4941).

    The uniqueness check in :func:`_alias_index` only protects against
    ambiguity between same-stem files, never against a same-named node whose
    real identity is in another language entirely: a Dart `PunchType` enum
    reference and an unrelated `PunchType.java` file both collapse to the
    bare old-stem alias "punchtype", and since only the Java file ever
    registers it, the alias commits unconditionally and binds the Dart
    reference onto the Java file. Permissive when either side's family is
    unknown (no source_file, or an extension outside the known map), so a
    legitimate same-language or provenance-less alias still resolves exactly
    as before.
    """
def _alias_lang_compatible(edge_source_file: object, alias_source_file: object) -> bool;

"""Re-derive non-AST node ids from ``source_file`` using the canonical
    full-path stem, so a cached/LLM fragment carrying a pre-migration short id
    reconciles with the AST node instead of spawning a ghost (#1504/#1509).

    Drift-proof by construction: the new id is computed from ``source_file`` in
    code, never trusted from the fragment's own ``id`` string. AST-origin nodes
    are skipped (they are already canonical via the extract() post-pass)."""
def _semantic_id_remap(nodes: list, `root: str | None) -> dict;

with entry {
    _MCP_GLOBAL_ID_KINDS = frozenset({"mcp_command", "mcp_package", "env_var"});
}

"""Whether ``node``'s ID is global by construction rather than file-derived."""
def _has_global_id(`node: dict) -> bool;

"""The scan-root prefix that a graph's stored ``source_file`` values carry.

    A build scoped to a subfolder from its parent (``graphify update sub``)
    stores ``source_file`` relative to the build's cwd (``sub/pkg/mod.py``,
    #2603) while every id is minted relative to the scan root (``pkg_mod``).
    The relative ``.graphify_root`` marker next to the graph records exactly
    that offset (``sub``). Returns it in normalized POSIX form, or None when
    there is no offset: no marker, an absolute marker (the build anchored
    source_file at the scan root itself), ``.``, or a path leaving the cwd.
    """
def legacy_id_source_prefix(graph_path: str | Path) -> str | None;

"""Whether a loaded graph still uses pre-#1504 node IDs (parent-dir / filename
    stem) rather than the full repo-relative path. Read-only consumers (query,
    serve) use this to nudge the user to rebuild, since they don't re-extract.

    Heuristic and cheap: only **file-level** nodes (source_location ``L1``) are
    inspected, because their ID is unambiguously the file stem. Symbol nodes are
    skipped — some extractors scope a symbol by package/directory (Go's
    ``_make_id(pkg_dir, name)`` → ``sub_thing``), which can coincide with an old
    file-stem form and would otherwise false-positive. Nodes whose ID is global by
    construction (see ``_MCP_GLOBAL_ID_KINDS``) are skipped for the same reason.
    Returns True as soon as one file node's ID matches an OLD stem form but not the
    canonical full-path form.

    ``source_prefix`` (see :func:`legacy_id_source_prefix`) is the cwd->scan-root
    offset stored source_file values carry; it is stripped before the stem is
    derived, since ids never include it. Without it a fresh subfolder build reads
    as legacy: ``sub/pkg/mod.py`` wants ``sub_pkg_mod``, and the real ``pkg_mod``
    looks exactly like the old one-parent form."""
def graph_has_legacy_ids(
    nodes: list,
    `root: str | Path | None = None,
    sample: int = 300,
    source_prefix: str | None = None,
) -> bool;

"""Map a markdown quick-scan's bare doc node ``<slug>`` to the semantic
    ``<slug>_doc`` node for the SAME file (#1799).

    The markdown quick-scan (``extract_markdown``) mints a file node with the
    bare id ``_make_id(path)`` while the semantic pass mints ``<slug>_doc`` for
    the same document. A ``graphify update`` after a semantic build leaves both,
    splitting the file's edges across two disconnected nodes. Canonicalize to the
    semantic ``_doc`` node (it carries the richer references/hyperedges). Gated to
    ``file_type == "document"`` on BOTH twins with an identical ``source_file``,
    so an unrelated code symbol ``foo`` and ``foo_doc`` never merge. The bare
    record must be a page/file node; an AST record or a heading at the `_doc`
    ID is never a semantic twin. Legacy unmarked file twins remain supported.
    """
def _doc_twin_remap(nodes: list) -> dict[str, str];

"""Build a NetworkX graph from an extraction dict.

    directed=True produces a DiGraph that preserves edge direction (source→target).
    directed=False (default) produces an undirected Graph for backward compatibility.
    root: if given, absolute source_file paths from semantic subagents are made
        relative to root so all nodes share a consistent path key (#932).
    dedup=False preserves distinct non-AST IDs rather than coalescing nodes by
        file and label. AST/semantic and document-file twin reconciliation
        remain enabled.
    """
def build_from_json(
    extraction: dict, *, directed: bool = False, `root: str | Path | None = None, dedup: bool = True
) -> nx.Graph;

"""Merge multiple extraction results into one graph.

    directed=True produces a DiGraph that preserves edge direction (source→target).
    directed=False (default) produces an undirected Graph for backward compatibility.
    dedup=True (default) runs entity deduplication before building the graph.
    dedup_llm_backend: if set (e.g. "gemini", "claude", or "kimi"), uses LLM to resolve
        ambiguous pairs in the 75–92 Jaro-Winkler score zone.
    root: if given, absolute source_file paths are made relative to root (#932).
    protected_ids: optional set of node IDs to protect from being collapsed with
        other protected nodes during incremental merge (#3477).

    With dedup disabled, extractions are merged in order and the last node's
    attributes win (NetworkX add_node overwrites). With dedup enabled, nodes
    sharing an ID use a deterministic survivor and retain missing attributes
    from duplicate records of the same source entity. Genuine cross-file ID
    collisions remain isolated and are reported.
    """
def build(
    extractions: list[dict],
    *,
    directed: bool = False,
    dedup: bool = True,
    dedup_llm_backend: str | None = None,
    `root: str | Path | None = None,
    protected_ids: "set[str] | None" = None,
) -> nx.Graph;

"""Read and remove the #3774 counters.

    ``build`` / ``build_merge`` stash these on ``G.graph`` for the extract
    CLI. ``to_json`` also removes them so any other writer cannot persist
    them into graph.json.
    """
def take_shrink_accounting(G) -> tuple[int, int];

"""Read and remove the ``{merged-away id: survivor id}`` map (#4940).

    ``build`` stashes it on ``G.graph`` when entity dedup merged nodes.
    ``to_json`` calls this to excuse a saved id the merge folded into a twin,
    and it also drops the key so it is never persisted into graph.json.
    """
def take_dedup_remap(G) -> dict[str, str];

"""Canonical dedup key — Unicode-aware, preserves CJK/word characters."""
def _norm_label(label: str | None) -> str;

"""Merge nodes that share a normalised label, rewriting edge references.

    Prefers IDs without chunk suffixes (_c\\d+) and shorter IDs when tied.
    Drops self-loops created by the merge.

    Dormant: this is NOT wired into ``build()`` — the active dedup path is
    ``deduplicate_entities`` (imported and called in ``build``), which supersedes
    it. The previous "Called in build() automatically" note was never true. It
    also merges by label alone with no ``file_type`` guard, so it must not be
    enabled for code nodes: same-label symbols from different files/packages
    (e.g. two ``Account`` types) would collapse into one — the cross-file
    conflation ``deduplicate_entities`` deliberately avoids for code (#1205).
    """
def deduplicate_by_label(nodes: list[dict], edges: list[dict]) -> tuple[list[dict], list[dict]];

"""Load (nodes, edges, hyperedges, directed) from an existing graph.json for
    an incremental merge, accepting both the ``links`` and ``edges`` spellings
    and either hyperedge persistence slot (top-level or ``graph.hyperedges``).

    Reads the JSON directly instead of going through node_link_graph().
    The latter rebuilds an undirected nx.Graph and then enumerating
    edges() yields endpoints based on node insertion order, which
    silently flips directional edges (e.g. `calls`) when the callee
    was inserted before the caller. The _src/_tgt direction-preserving
    attrs are popped before saving in export.py, so going through the
    NetworkX round-trip loses direction permanently (#760).

    Returns None when the file does not exist. Raises RuntimeError when it
    exists but cannot be parsed — callers must refuse to overwrite rather
    than silently replace a possibly-recoverable graph.
    """
def _load_existing_graph(graph_path: Path) -> "tuple[list, list, list, bool] | None";

"""Compute (new_ast_sources, new_sem_sources) for tier-scoped replacement.

    #3411: AST replacement ownership is derived from explicit extraction
    provenance (ast_sources or chunk-level "extracted_sources"), so cross-file
    stub nodes emitted by extractors (e.g. .sln project stubs or ProjectReference
    stubs) do not pollute the replacement set and wipe the target project's
    nodes/edges. Falls back to AST node source_file only when no provenance is
    provided.
    """
def _tier_replacement_sources(
    chunks: "Iterable[dict]",
    `root: "str | Path | None" = None,
    ast_sources: "Iterable[str | Path] | None" = None,
) -> tuple[set[str], set[str]];

"""Merge the existing raw graph.json forward into a fresh raw extraction
    (the ``extract --no-cluster`` incremental path, #2169).

    Replace/prune semantics mirror :func:`build_merge` exactly, so the raw and
    clustered incremental paths can't drift:

    - sources re-extracted this run REPLACE their prior contribution PER TIER
      (#2333/#2336, #3411): existing nodes/edges/hyperedges owned by them are dropped
      only when the new extraction contains the same tier (AST vs semantic,
      per :func:`_is_ast_tier`) for that source, matched in both raw and
      :func:`_norm_source_file` form (#1007). AST replacement ownership is derived
      from explicit extraction provenance (``ast_sources`` or chunk-level
      ``extracted_sources``), falling back to AST node source_file only when no
      provenance is provided (#3411);
    - ``prune_sources`` (deleted / excluded / graph-stale files) are dropped,
      with the ``_abs_identity`` third-form fallback (#2012), and "replace" wins
      over a contradictory "delete" of a re-extracted source (#1796);
    - everything else — nodes/edges/hyperedges owned by unchanged files — is
      carried forward unchanged.

    Survivors are PREPENDED to ``new``'s lists (existing-first), so the caller's
    ``dedupe_nodes`` last-writer-wins keeps fresh attributes for re-extracted
    nodes while ``dedupe_edges`` first-wins never resurrects a replaced edge
    (replaced sources' edges were already dropped above). Token counters and
    every other key of ``new`` are left untouched. Returns ``new``, mutated in
    place. Raises RuntimeError (via :func:`_load_existing_graph`) when the
    existing graph is present but unparseable — the caller must refuse to
    overwrite it. No-op when ``graph_path`` does not exist.
    """
def merge_raw_extraction(
    new: dict,
    graph_path: str | Path,
    prune_sources: "list[str] | None" = None,
    `root: "str | Path | None" = None,
    *,
    ast_sources: "Iterable[str | Path] | None" = None,
) -> dict;

"""Load existing graph.json and return it merged with ``new_chunks``.

    Does NOT write to disk — the caller persists the result, e.g. via
    ``export.to_json(G, communities, graph_path, force=True)`` after
    clustering. ``graph_path`` is read-only here.

    Re-extracted files REPLACE their prior contribution per tier (#2333/#2336, #3411):
    a source_file present in new_chunks has its existing nodes/edges dropped
    for each tier (AST vs semantic, per :func:`_is_ast_tier`) the new chunks
    actually contain, so a changed file's stale nodes/edges don't accumulate
    while a one-tier re-extract keeps the other tier's layer intact. AST replacement
    ownership is derived from explicit extraction provenance (``ast_sources`` or
    chunk-level ``extracted_sources``), falling back to AST node source_file only
    when no provenance is provided (#3411). Files absent from new_chunks are
    preserved unchanged; deleted files are removed via prune_sources (tier-blind).
    Safe to call repeatedly.
    root: if given, absolute source_file paths in new_chunks are made relative (#932).
    directed: if None (default), honor the on-disk graph's own ``directed`` flag
    when one exists, so an incremental merge can't silently flip a directed
    graph undirected (#2342). Falls back to False when there is no existing
    graph to inherit from. An explicit True/False always overrides the on-disk
    flag.
    """
def build_merge(
    new_chunks: list[dict],
    graph_path: str | Path | None = None,
    prune_sources: list[str] | None = None,
    *,
    directed: bool | None = None,
    dedup: bool = True,
    dedup_llm_backend: str | None = None,
    `root: str | Path | None = None,
    ast_sources: "Iterable[str | Path] | None" = None,
) -> nx.Graph;

"""Return a copy of G with all node IDs prefixed with repo_tag::.

    Labels are preserved unchanged (for display). A 'local_id' attribute
    is added to each node so the original ID can be recovered. Edges and
    their directional attributes (_src/_tgt) are rewritten to match the new
    prefixed IDs. The 'repo' attribute is set on every node.

    community_offset shifts each node's integer 'community' id into a shared
    id space and records the original in 'local_community': every input graph
    numbers its communities from 0, so ids carried across a merge unchanged
    collide and the aggregated community view fuses unrelated communities
    into one meta-node (#3014). 0 (the default) leaves communities untouched.
    """
def prefix_graph_for_global(G: nx.Graph, repo_tag: str, community_offset: int = 0) -> nx.Graph;

"""Return a unique, human-meaningful repo tag per input graph for merge-graphs.

    The naive tag (the ``graphify-out`` parent dir name) is NOT unique across
    inputs: ``src/graphify-out`` and ``frontend/src/graphify-out`` both yield
    ``src``. Prefixing both node sets with ``src::`` then makes same-stem nodes
    (a backend ``src/app.js`` and a frontend ``App.jsx``, both bare ``app``)
    collide, so ``nx.compose`` silently merges two unrelated entities and invents
    cross-runtime edges (#1729). Colliding tags are widened with their own parent
    dir (``frontend_src``), then an index suffix guarantees uniqueness so no two
    graphs ever share a prefix.
    """
def distinct_repo_tags(graph_paths: "list[Path]") -> "list[str]";

"""Remove all nodes tagged with repo_tag from G in-place. Returns count removed."""
def prune_repo_from_graph(G: nx.Graph, repo_tag: str) -> int;
