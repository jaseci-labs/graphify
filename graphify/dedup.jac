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
def _is_label_char(ch: str) -> bool;
def _norm(label: str | None) -> str;
def _entropy(label: str) -> float;
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

def _is_variant_pair(a: str, b: str) -> bool;
def _short_label_blocked(a: str, b: str, jw_score: float) -> bool;

with entry {
    _DIGIT_RUN = re.compile("\\d+");
}

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

def _same_word_variant(x: str, y: str) -> bool;
def _content_token_swap(a: str, b: str) -> bool;

with entry {
    _FILE_ANCHORED_NONCODE = frozenset({"rationale", "document"});
}

def _crossfile_fileanchored_blocked(`node: dict, neighbor: dict) -> bool;

obj _UF {
    has _parent: any;

    def init;

    def find(x: str) -> str;

    def union(x: str, y: str);

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

def _is_code(`node: dict) -> bool;

with entry {
    _EXTENSION = re.compile("\\.[^./]+$");
}

def _id_prefixes(source_file: str) -> set[str];
def _defines_id(`node: dict) -> bool;

with entry {
    _FILE_STRUCTURE_NODE_KINDS = frozenset({"page", "heading"});
}

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

def _lifecycle_penalty(rank_path: str) -> int;
def _rank_path(source_file: str, `root: Path | None) -> str;

glob mentions_default_: any;

glob outranked_default_: any;

with entry {
    mentions_default_ = frozenset();
    outranked_default_ = frozenset();
}

def _collision_rank(
    `node: dict,
    `root: Path | None = None,
    mentions: "frozenset | set" = mentions_default_,
    outranked: "frozenset | set" = outranked_default_,
) -> tuple;
def _outranked_by_ast(
    nodes: list[dict], `root: Path | None, mentions: "frozenset | set"
) -> set[tuple[str, str]];
def _mentions(nodes: list[dict], edges: list[dict], `root: Path | None) -> set[tuple[str, str]];
def _own_page_files(nodes: list[dict], `root: Path | None) -> set[str];
def _slice_references(nodes: list[dict], `root: Path | None) -> set[tuple[str, str]];
def _same_source_entity(survivor: dict, duplicate: dict) -> bool;
def _merge_missing_attributes(survivor: dict, duplicate: dict) -> dict;

with entry {
    _SHARED_ID_TYPES = ("module", "namespace");
}

def _report_id_collision(nid: str, survivor: dict, losers: list[dict]);
def _full_stem(source_file: str) -> str;
def _extension_qualified_id(`node: dict) -> str | None;
def _disambiguate_defining_collisions(
    nodes: list[dict], edges: list[dict], hyperedges: list[dict] | None, `root: Path | None
) -> tuple[list[dict], list[dict]];
def _path_qualify_dropped_collisions(
    nodes: list[dict], edges: list[dict], hyperedges: list[dict] | None, `root: Path | None
) -> tuple[list[dict], list[dict]];
def _is_reference_stub(`node: dict) -> bool;
def _namespace_reference_stub_collisions(
    nodes: list[dict],
    edges: list[dict],
    hyperedges: list[dict] | None,
    `root: Path | None,
    *,
    preserve_saved_semantics: bool = False,
) -> tuple[list[dict], list[dict]];
def _remap_hyperedge_members(hyperedges: list[dict], remap: dict[str, str]);
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

def _content_richness(n: dict) -> int;
def _pick_winner(nodes: list[dict]) -> dict;
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
);
