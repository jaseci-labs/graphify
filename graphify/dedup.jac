"""Entity deduplication pipeline for graphify knowledge graphs.

Pipeline: exact normalization → entropy gate → MinHash/LSH blocking →
Jaro-Winkler verification → same-community boost → union-find merge.
"""

import importlib;
import builtins;

import operator;

import from __future__ { annotations }

import math;

import re;

import sys;

import unicodedata;

import from collections { defaultdict }

import from pathlib { Path }

import from rapidfuzz.distance { DamerauLevenshtein, Jaro, JaroWinkler }

"""True for a character that belongs to a word in a label.

    Letters and digits, plus combining marks (Unicode category M*). ``\\w`` does
    not match marks, so the old ``[\\W_]+`` separator class deleted every vowel
    sign and virama: ``हिंदी`` became ``ह द`` and ``कि``/``की``/``के`` all
    collapsed to ``क``, merging distinct words.
    """
def _is_label_char(ch: str) -> bool;

"""Lowercase + collapse non-word runs to space (Unicode-aware).

    Combining marks stay part of the word (see ``_is_label_char``); punctuation,
    underscores and whitespace collapse to a single space as before. Known gap:
    ZWJ/ZWNJ (category Cf) still count as separators.
    """
def _norm(label: str | None) -> str;

"""Shannon entropy in bits/char of the normalised label."""
def _entropy(label: str) -> float;

"""Return k-gram character shingles of text."""
def _shingles(text: str, k: int = 3) -> set[str];

def _make_minhash(text: str, num_perm: int = 128) -> MinHash;

glob _VARIANT_SUFFIX: any;

glob _DIGIT_RUN: any;

glob _STOPWORDS: any;

glob _FILE_ANCHORED_NONCODE: any;

glob _ENTROPY_THRESHOLD: any;

glob _LSH_THRESHOLD: any;

glob _MERGE_THRESHOLD: any;

glob _COMMUNITY_BOOST: any;

glob _NUM_PERM: any;

glob _CHUNK_SUFFIX: any;

glob _EXTENSION: any;

glob _FILE_STRUCTURE_NODE_KINDS: any;

glob _ACTIVE_PATH_SEGMENTS: any;

glob _ARCHIVED_PATH_SEGMENTS: any;

glob _SHARED_ID_TYPES: any;

glob _RICHNESS_IGNORED_KEYS: any;

with entry {
    _VARIANT_SUFFIX = re.compile("^(.*[a-z])([0-9]+[a-z]*|[a-z]{2,})$");
}

"""True if a and b are sibling model/SKU variants (same stem, different suffix).

    Only applied to short labels (< 12 chars); long labels go through JW normally.
    """
def _is_variant_pair(a: str, b: str) -> bool;

"""Block fuzzy merge for short labels unless it's a same-length single-char substitution.

    Insertions/deletions on short strings (cranel/cranelr, M1/M1 Pro) produce
    high Jaro-Winkler scores due to the prefix bonus but are almost never true
    duplicates — they're abbreviations or variants.
    """
def _short_label_blocked(a: str, b: str, jw_score: float) -> bool;

with entry {
    _DIGIT_RUN = re.compile("\\d+");
}

"""True when two labels carry different embedded numbers (#1284).

    Long labels that differ only in their digit runs ("ADR 0011 §D5" vs
    "ADR 0013 D4", "3.1 Product Goals" vs "1.1 Product Goals", "block3" vs
    "block13", "40%+ retention" vs "<20% retention") are numbered/versioned
    siblings, not duplicates -- but the long shared boilerplate keeps
    Jaro-Winkler above _MERGE_THRESHOLD, and _is_variant_pair only covers
    short trailing suffixes. Digit runs are compared as multisets with
    leading zeros stripped, so zero-padding ("09" vs "9") does not count as
    a difference. (String comparison, not int(): a pathological label with a
    >4300-digit run would crash int() on Python's conversion limit.) Labels
    with identical numbers, or none at all, are unaffected.
    """
def _numeric_tokens_differ(a: str, b: str) -> bool;

with entry {
    _STOPWORDS = frozenset({
        "a",
        "an",
        "the",
        "and",
        "or",
        "of",
        "for",
        "to",
        "in",
        "on",
        "at",
        "by",
        "with",
        "from",
        "as",
        "is",
        "are",
        "be",
        "this",
        "that",
        "its",
    });
}

"""True when tokens x and y read as one word misspelt, not two words (#2576).

    A same-length pair within one substitution/transposition is a typo
    ("manager"/"nanager") -- the same rationale _short_label_blocked applies
    to whole short labels, and unlike Jaro-Winkler it holds at position 0,
    where the prefix bonus gives no help (JW scores "manager"/"nanager" at
    84.92, below threshold, yet it is as much a typo as "managr"). Below 6
    chars JW cannot separate two words from a typo ("pane"/"plane" scores
    94.0), so short length-differing pairs never read as variants. Longer
    pairs fall back to Jaro-Winkler on the merge threshold, so
    "manager"/"managr" (97.14) still reads as one word. Accepted trade, per
    the never-merge-two-distinct-entities bar: "colour"/"color" (5 chars,
    lengths differ) now reads as two words and stays unmerged -- a spelling
    variant kept separate beats a fabricated merge.

    A token that is the other with letters prepended is a derived word, not a
    typo: "synchronous"/"asynchronous" (JW 97.22), "cyclic"/"acyclic",
    "reload"/"preload" name opposite or different things, so they never read
    as variants. Appended letters ("handler"/"handlers") still fall through to
    Jaro-Winkler. This is the token-level counterpart of the label-level
    prefix-extension guard (#1201).
    """
def _same_word_variant(x: str, y: str) -> bool;

"""True when two equal-token-count labels differ in at least one swapped
    content word rather than only typos or function words (#2576, adopted
    from @wilyan09007's PR #2587 and generalized from exactly-one to any
    number of differing positions).

    Whole-string scoring cannot separate a legit restatement from a
    distinguishing-token swap: both edit one short run in the middle of a long
    shared string, so both land in the same Jaro band (#1243). Which token
    differs does separate them. Structured prose names sibling sections from a
    template ("Asset Contribution Flow" / "Asset Consumption Flow", four
    consecutive headings of one operations doc), and those siblings are densest
    inside a single file -- exactly where Jaro-Winkler's prefix bonus still
    applies, and where the shared affixes it rewards are boilerplate.

    Each same-position differing pair is judged on its own: a function word on
    either side is what a restatement swaps, a _same_word_variant pair is one
    word misspelt, and anything else is a distinct content word naming a
    different entity -- one such pair blocks the merge. A restatement differs
    only in stopwords/typos at every position; a template sibling differs in
    at least one distinct content word ("... Contribution Flow Handler" vs
    "... Consumption Flows Handler" blocks on either position). Pairs with
    different token counts are left to the prefix-extension guard (#1201) and
    whole-label scoring. Known gap, out of scope here: fused camelCase labels
    ("AssetContributionFlow" vs "AssetConsumptionFlow") normalize to single
    tokens whose only differing "position" is the whole label, so this guard
    reduces to whole-token _same_word_variant and long fused pairs can still
    clear the JW fallback.
    """
def _content_token_swap(a: str, b: str) -> bool;

with entry {
    _FILE_ANCHORED_NONCODE = frozenset({"rationale", "document"});
}

"""Block label-based merging of file-anchored non-code nodes across files (#1284).

    rationale/document nodes are docstring- and heading-derived and as
    file-anchored as the code they describe (#1205's reasoning, one layer up):
    parallel modules carry near-identical boilerplate ("Django app config for
    apps.<name>. No business logic here...") that differs by one word and sails
    past the JW threshold. Same-file duplicates of these types may still merge.
    """
def _crossfile_fileanchored_blocked(`node: dict, neighbor: dict) -> bool;

obj _UF {
    has _parent: any;

    def init;

    def find(x: str) -> str;

    def union(x: str, y: str) -> None;

    def components -> dict[str, list[str]];

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

with entry {
    _ENTROPY_THRESHOLD = 2.5;
    _LSH_THRESHOLD = 0.7;
    _MERGE_THRESHOLD = 92.0;
    _COMMUNITY_BOOST = 5.0;
    _NUM_PERM = 128;
    _CHUNK_SUFFIX = re.compile("_c\\d+$");
}

"""True for AST-extracted code symbols.

    Code-node identity is the node ID (which already encodes the fully
    qualified path: module/class/symbol). The label is only a display name
    (e.g. a bare ``.draw()`` method name, or a function name shared by two
    parallel backends), so label-based merging conflates distinct symbols
    (#1205). Genuine duplicates — the same symbol re-extracted — share an ID
    and are already collapsed by the exact-ID ``seen_ids`` pre-dedup above,
    so code never needs label-based merging.
    """
def _is_code(`node: dict) -> bool;

with entry {
    _EXTENSION = re.compile("\\.[^./]+$");
}

"""The ID prefixes a node extracted from ``source_file`` may legitimately mint.

    An ID is ``<path>_<entity>``, where the path is the extension-stripped source
    path, each segment slugified and joined with ``_``. Every trailing slice of the
    path counts as a prefix: the stored path may be absolute or repo-relative, and
    graphs built under the pre-#1504 scheme keyed off the bare filename stem.

    Each segment is slugified with ``normalize_id`` (#3352), the same
    Unicode-aware casefold-then-NFKC-then-``[^\\w]+`` recipe every real ID is
    minted with. An ASCII-only slug here silently dropped every non-Latin
    character (Korean, CJK, Cyrillic, ...) instead of preserving it, so a
    node's own defining file was never recognized as the file that ID
    encodes and the definer-wins collision rule (see ``_defines_id``,
    ``_collision_rank``) fell through to arrival-order for any such path.
    """
def _id_prefixes(source_file: str) -> set[str];

"""True when the node's own source_file is the file its ID encodes.

    A doc that *references* an entity mints the ID of the entity's own file, not one
    derived from the doc's path — so the referencing node collides with the defining
    node by construction. This separates the two: the definer owns the ID.
    """
def _defines_id(`node: dict) -> bool;

with entry {
    _FILE_STRUCTURE_NODE_KINDS = frozenset({"page", "heading"});
}

"""True when the node reads as an entity found inside its file, rather than
    as the file itself or a stamped structural part of it (#296).

    Be precise about what is proven and what is assumed, because the two halves
    differ in strength:

    * PROVEN — it is not its file's OWN node. ``_id_prefixes`` enumerates the ID
      a node standing for ``source_file`` itself would carry, in every spelling
      a stored path may take (absolute, repo-relative, or the pre-#1504 bare
      stem). A file's own node IS one of those; an entity extracted from that
      file carries an ``_<entity>`` suffix, so it never equals one. This is a
      reconstruction, not a heuristic.
    * ASSUMED — it is not a section of the file. That rests on ``node_kind``,
      which only a producer that stamps it can attest. `heading`/`page` are
      honoured when present, but ABSENCE OF THE MARKER IS NOT PROOF OF
      ENTITY-NESS: a producer minting sub-file nodes without stamping
      `node_kind` (see the contract above) yields structural nodes that this
      returns True for, and two such nodes sharing a label in different files
      would merge. The conservative fix is on the producer side — stamp
      `node_kind` — not a guess here about what an unstamped node meant.

    A node that cannot be checked at all (no ID, no provenance) answers False
    and stays blocked.
    """
def _reads_as_file_entity(`node: dict) -> bool;

with entry {
    _ACTIVE_PATH_SEGMENTS = frozenset({"in-progress", "in_progress", "active", "current", "wip"});
    _ARCHIVED_PATH_SEGMENTS = frozenset({
        "_done",
        "done",
        "archive",
        "archived",
        "backup",
        "bak",
        "old",
        "attic",
        "graveyard",
        "completed",
    });
}

"""0 for active/in-progress paths, 2 for archived/done paths, 1 otherwise.

    Judged on the DIRECTORY segments of the root-relative rank path — a file
    literally named ``done.md`` is not a marker. Among mixed markers the best
    (lowest) score wins so an active segment is not drowned out by an unrelated
    archive directory higher in the tree (#2532).
    """
def _lifecycle_penalty(rank_path: str) -> int;

"""The root-relative form of ``source_file`` used for collision ranking.

    With a scan root, an absolute stored path and its repo-relative twin rank
    identically, and the checkout location's own segments never participate
    (#2532). A relative stored path is already root-relative and is used as-is;
    unlike ``_source_key`` in extractors/resolution.py, it is not resolved
    against the CWD, so a run from a subdirectory of the root keys it the same
    (#4281). Without a root (or when relativizing fails) the normalized stored
    path is used as-is.
    """
def _rank_path(source_file: str, `root: Path | None) -> str;

glob mentions_default_: any;

glob outranked_default_: any;

with entry {
    mentions_default_ = frozenset();
    outranked_default_ = frozenset();
}

"""A total order for choosing the survivor of an ID collision, independent of
    the order the colliding nodes arrive in.

    The winner is the node with the SMALLEST rank. A node whose ``source_file``
    defines the ID always outranks a mere reference, and a definer listed in
    ``outranked`` ranks behind the other definers (#4859); among equally-(non-)defining
    nodes an active/in-progress path outranks an archived/done one (#2532); then
    it prefers the shorter, more canonical label over a longer qualified variant,
    then breaks any remaining tie lexically on label and finally on the REVERSED
    segments of the root-relative path. Basename-first comparison decides two
    in-repo colliders by segments present in both path forms, so absolute and
    repo-relative spellings of the same layout order identically — fully
    deterministic regardless of arrival order (#1851) or checkout location.

    Neither side of the first key is exempt from the second: when the ID is
    encoded by neither node's own file, both read as mere references and tie
    there too, so a node with no ``source_file`` at all used to win purely on
    an empty reversed path sorting before any real one — the sourced node was
    the one actually telling us where the entity lives, and it was the one
    getting dropped (#4492). A ``source_file`` beats none right after the
    first key, mirroring the same rule ``_pick_winner`` already applies one
    level up (#3775/#3786). It changes no collision between two sourced
    nodes, since both sides of that key agree there.

    ``outranked`` (see ``_outranked_by_ast``) holds the ``(id, file)`` of non-AST
    definers that another file's AST node also defines. A doc whose own path
    prefixes a code entity's id (``pkg.md`` beside ``pkg/test_x.py``) defines it
    too, and used to take it on a shorter label, so its next re-extract deleted the
    code node (#4859). Such a definer now ranks right behind the other definers;
    same-file pairs (#2091), same-stem twins, and collisions with one definer
    rank as before.

    ``mentions`` (see ``_mentions``) holds the ``(id, file)`` of nodes read as a
    mention of a document rather than the document itself. Such a node ranks as a
    reference even though its id is a path slice, so a real document outranks it
    whatever the label lengths are (#4281). The set only ever contains path-slice
    ids, so the survivor of every other collision is chosen exactly as before. It
    also holds a shorter path-slice id from a file that has its own page
    (``_slice_references``), so a bare ``protocol`` inside docs/protocol.md cannot
    outrank the real top-level protocol.md on label length.
    """
def _collision_rank(
    `node: dict,
    `root: Path | None = None,
    mentions: "frozenset | set" = mentions_default_,
    outranked: "frozenset | set" = outranked_default_,
) -> tuple;

"""``(id, root-relative file)`` of non-AST definers that an AST node from
    another file also defines, while their own file has no AST definer (#4859).

    The AST node is extracted fact and the other is an inference about it, so the
    AST node keeps the id. The check is strict on ``_origin == "ast"``, as in the
    build ghost pass: fresh semantic chunks arrive unstamped. A file that has its
    own AST definer (#2091 enrichment) is never listed, and an AST node with the
    same full stem (an ``x.py``/``x.html`` twin, or a slug twin such as
    ``pkg/service.py`` and ``pkg_service.py``) never counts against it.
    """
def _outranked_by_ast(
    nodes: list[dict], `root: Path | None, mentions: "frozenset | set"
) -> set[tuple[str, str]];

"""``(id, root-relative file)`` of nodes read as a MENTION of a document (#4281).

    A semantic fragment sometimes mints the bare id of a file it only points at:
    ``protocol`` inside docs/firmware/protocol.md, standing for docs/protocol.md. A
    node is read as such a mention when both hold:

    - another node of its OWN file points at it with a ``references`` edge whose own
      source_file is that file, and
    - its id is itself a path slice of that file (``_id_prefixes``), so it names a
      document. An entity id such as ``x_intro`` is the target of ordinary intra-file
      ``references`` edges and never counts.

    ``_path_qualify_dropped_collisions`` and ``_collision_rank`` both read this one
    set, so a single definition decides whether a mention is renamed and whether it
    loses a survivor tie.

    Heuristic boundary: this is INFERRED from the edges an LLM chose to emit, not
    stated by the source. A missing or reversed edge gives no evidence, and the id is
    then renamed per file like any other. A real document whose own node is linked to
    its file-level id the same way (an entity named like its file, which
    ``_doc_twin_remap`` already treats as the file itself) reads as a mention, and
    that collision collapses exactly as it did before.
    """
def _mentions(nodes: list[dict], edges: list[dict], `root: Path | None) -> set[tuple[str, str]];

"""Root-relative files that have a node spelled with their own full stem (#4281).

    Such a file already has its page, so a shorter path-slice id it also mints
    (``protocol`` inside docs/protocol.md, next to ``docs_protocol``) may be a
    reference to another file rather than that file's own page."""
def _own_page_files(nodes: list[dict], `root: Path | None) -> set[str];

"""``(id, file)`` of nodes whose id is a SHORTER path slice of a file that has its
    own page (#4281). They rank as references, like a ``_mentions`` entry."""
def _slice_references(nodes: list[dict], `root: Path | None) -> set[tuple[str, str]];

"""True when exact-ID records came from the same source file.

    Exact IDs can also collide across files through references or slugged-path
    ambiguity (#1504).  Keep those records isolated rather than importing
    attributes whose provenance belongs to another file.
    """
def _same_source_entity(survivor: dict, duplicate: dict) -> bool;

"""Fill the survivor's absent/None attributes from a same-source duplicate,
    without overriding values the survivor already has (#2091)."""
def _merge_missing_attributes(survivor: dict, duplicate: dict) -> dict;

with entry {
    _SHARED_ID_TYPES = ("module", "namespace");
}

"""Report an ID collision in proportion to what dropping the loser actually costs.

    Cross-reference to a defining node: the structural entity and its edges survive;
    foreign-file attributes stay isolated, so no collision warning is needed. Same
    file, different labels: the extractor emitted two labels for one entity and one is
    discarded — note it. Two files that both encode this ID: they are distinct entities
    and one is genuinely lost — warn, and point at the extraction split that keeps them
    apart (#1504).
    """
def _report_id_collision(nid: str, survivor: dict, losers: list[dict]) -> None;

"""The extension-stripped, slugified full-path stem a file's own IDs start with."""
def _full_stem(source_file: str) -> str;

"""``x.html``'s own spelling of an ID it shares with ``x.py`` (#4281).

    Only applies when the ID is spelled with the node's FULL path stem, i.e.
    the ID collides because the extension was stripped. Returns None for an ID
    that only matches a trailing path slice (a bare ``protocol``): that is a
    reference to another file's entity, not a distinct entity, and is left to
    the collapse-and-warn path.
    """
def _extension_qualified_id(`node: dict) -> str | None;

"""Keep ``x.py`` and ``x.html`` apart when both derive the same ID (#4281).

    The ID is built from the extension-stripped path, so two files that differ
    only by extension mint the same ID. The best-ranked file keeps it; the
    others get an extension-qualified ID. Edges and hyperedges follow the
    renamed node by ``source_file``, compared in root-relative form because
    semantic edges can still carry an absolute path here while nodes were
    already made relative. Anything else (an ID no file derives from its own
    path, or a bare ID shared across different paths) is left to the existing
    collapse-and-warn path.
    """
def _disambiguate_defining_collisions(
    nodes: list[dict], edges: list[dict], hyperedges: list[dict] | None, `root: Path | None
) -> tuple[list[dict], list[dict]];

"""Path-qualify semantic ids that dropped the directory, per file (#4281).

    Semantic extraction sometimes mints an id from the bare filename stem, so
    ``a/x.md`` and ``b/x.md`` both emit ``x``. This is the sibling of
    ``_disambiguate_defining_collisions`` for different directories rather than
    different extensions. Every colliding node is renamed to
    ``<full path stem><rest of id>``, computed from the node's OWN source_file;
    no file keeps the bare id, because picking one would be a guess.

    Heuristic boundary:
    - only ids spelled with a SHORTER-than-full path stem of the node's own file
      are candidates (an id already carrying the full stem is left alone), and
      AST-tier nodes are never touched;
    - a source_file that is still absolute after rooting (no root, outside the
      root, or the other platform's form) is never qualified, so the checkout
      location cannot leak into an id;
    - a group acts only when its files have at least two distinct full stems; a
      lone candidate is left to ``build_from_json``'s semantic id remap;
    - a node read as a MENTION of a document (``_mentions``: a path-slice id that
      another node of its own file ``references``) is not a candidate, so it is not
      renamed onto the mentioning file's own page. That reading is inferred from LLM
      edges: with a missing or reversed edge the node is renamed like any other, and
      a collision with a real document whose own node is linked to its file-level id
      collapses as it did before. If two or more other files also mint the mention's
      id it cannot be pointed at any one of them, so it stays on the bare id and
      ``build_from_json`` then folds it into its own file's page;
    - a file whose full stem IS the id (``protocol.md`` for ``protocol``) defines it,
      keeps the bare id, and counts toward the collision, so ``docs/protocol.md``
      next to it is still renamed. A candidate whose bare id names another input
      file is renamed only if its own file has no other node spelled with its own
      full stem. If it has one (``docs_protocol`` next to ``protocol``), the bare id
      may be a reference, so it stays on the definer-wins collapse-and-warn path as
      before. Known boundary: when the LLM drops the folder AND also emits another
      node spelled with the file's full stem, the file counts as having its own page
      and falls back to the collapse it got before this change (#4281);
    - a reference to the bare id from ANOTHER file cannot be attributed to one
      file, so it is left unresolved (one warning per id) rather than guessed;
    - if the new id is already used by a node of a different file, or two files
      of a group map to the same new id, the first file in sorted order keeps it
      and the rest stay on the bare id and take the collapse-and-warn path.
    """
def _path_qualify_dropped_collisions(
    nodes: list[dict], edges: list[dict], hyperedges: list[dict] | None, `root: Path | None
) -> tuple[list[dict], list[dict]];

"""Whether semantic extraction marked a node as a cross-document stub."""
def _is_reference_stub(`node: dict) -> bool;

"""Keep semantic references distinct from another file's defining node.

    Semantic extraction marks a node it emitted solely for a referenced entity
    with ``metadata.graphify_reference_stub``. Preserve every marked node under
    ``<citing-file>__ref__<original-id>`` instead of silently dropping it when
    its target ID collides with another file's node. Edges from the citing file
    follow its namespaced endpoint.

    The marker distinguishes reference stubs from two independent documents
    that happen to share an ID. Path specificity cannot make that distinction:
    it regresses genuine nested-path definitions.

    With preserve_saved_semantics, AST-only updates retain saved semantic
    evidence even when it predates the reference-stub marker. A scan root is
    required to distinguish source files; full builds keep their definer rules.
    """
def _namespace_reference_stub_collisions(
    nodes: list[dict],
    edges: list[dict],
    hyperedges: list[dict] | None,
    `root: Path | None,
    *,
    preserve_saved_semantics: bool = False,
) -> tuple[list[dict], list[dict]];

"""Rewire hyperedge member ids onto dedup survivors, in place.

    Members come in both shapes the rest of the codebase tolerates — a bare id
    string, or an object carrying one — so both are handled;
    ``_normalize_hyperedge_members`` fixes the SHAPE but never resolves a member
    against surviving node ids, which is why this is needed as well.

    Two members that remap onto the same survivor collapse to one entry. That
    shrinks the group, but honestly: they were the same entity, and the previous
    behaviour dropped the loser without promoting it, which shrank the group
    *and* lost the participant. Order is preserved so a rebuilt graph does not
    churn.
    """
def _remap_hyperedge_members(hyperedges: list[dict], remap: dict[str, str]) -> None;

"""Deduplicate near-identical entities in a knowledge graph.

    Args:
        nodes: list of node dicts with at minimum {"id": str, "label": str}
        edges: list of edge dicts with {"source": str, "target": str, ...}
        communities: mapping of node_id -> community_id (from cluster())
        remap_out: if given, filled with ``{merged-away id: surviving id}`` for
            every node this call dropped. Lets a caller tell a node that was
            folded into a twin from one that was lost (#4940).
        dedup_llm_backend: if set, use LLM to resolve ambiguous pairs
        root: scan root; ID-collision ranking judges source paths relative to
            it so path form and checkout location cannot flip the survivor (#2532)
        hyperedges: when given, member ids are rewired to survivors IN PLACE,
            the same way edge endpoints are. Optional and mutating rather than
            returned so existing two-tuple callers are unaffected (#2805).

    Returns:
        (deduped_nodes, deduped_edges) with edges rewired to survivors
    """
def deduplicate_entities(
    nodes: list[dict],
    edges: list[dict],
    *,
    communities: dict[str, int],
    dedup_llm_backend: str | None = None,
    `root: str | Path | None = None,
    hyperedges: "list[dict] | None" = None,
    protected_ids: "set[str] | None" = None,
    remap_out: "dict[str, str] | None" = None,
) -> tuple[list[dict], list[dict]];

with entry {
    _RICHNESS_IGNORED_KEYS = frozenset({
        "id",
        "label",
        "norm_label",
        "file_type",
        "source_file",
        "source_location",
    });
}

"""How much actual content a node carries, for survivor selection (#3372).

    Counts populated fields beyond the identity/placement baseline, weighting
    ``attributes`` by entry count and ``_merged_from`` by its history length —
    a node that already absorbed prior merges is the established record.
    """
def _content_richness(n: dict) -> int;

"""Pick the canonical survivor: no chunk suffix, then real provenance,
    then richer content, then shorter ID.

    ID length used to be the primary signal after the chunk-suffix check,
    which made a passing one-line mention on a shallow page (short id, one
    fewer path segment) beat the dedicated, enriched page for the same entity
    — every time the pattern occurred, the established node's content was
    discarded (#3372). Content richness now decides first; ID shape only
    breaks ties between equally-rich candidates, preserving the old
    deterministic ordering there.

    ``source_file``/``source_location`` are in ``_RICHNESS_IGNORED_KEYS``, so
    richness alone cannot tell a real, located declaration apart from a
    source-less stub carrying a couple of incidental bookkeeping keys (e.g.
    ``external``/``type``/``_origin``) — the stub could out-score and replace
    the genuine record purely on field count (#3775). Provenance is checked
    ahead of richness, in two steps: a node with a ``source_file`` always
    beats one without, and among nodes that both have one, a node that also
    has a ``source_location`` beats one that doesn't (the codebase genuinely
    emits ``source_location: None`` on some records, so this is a real
    distinction, not a hypothetical one — richness ignores it too, the same
    gap #3775 closed one level up). The location step only counts a
    ``source_location`` when ``source_file`` is also present — a location
    with no file isn't a real provenance signal and must not out-rank a
    fully bare candidate on its own. Each step only changes the outcome
    when the two sides disagree; whenever they agree (both or neither have
    a source file, and both or neither have a counted location), the
    existing richness-then-length ordering decides as before.
    """
def _pick_winner(nodes: list[dict]) -> dict;

"""Batch-resolve ambiguous pairs (score in [low, high)) via LLM."""
def _llm_tiebreak(
    candidates: list[dict],
    uf: _UF,
    communities: dict[str, int],
    *,
    backend: str,
    batch_size: int = 30,
    low: float = 75.0,
    high: float = 92.0,
    protected_set: set[str] | None = None,
    get_prot=None,
    union_with_prot=None,
) -> None;
