"""Deterministic symbol indexing and conservative cross-file resolution helpers."""

import from __future__ { annotations }

import ast;

import re;

import unicodedata;

import from dataclasses { dataclass }

import from functools { lru_cache }

import from pathlib { Path }

import from collections.abc { Sequence }

import from typing { Any }

"""A Python imported name that can be used as deterministic resolution evidence."""
@dataclass(frozen=True)
class ImportedSymbol {
    has local_name: str;

    has imported_name: str;

    has module_stem: str;

    has source_file: str;

    has source_location: str;
}

"""Normalize a node label into the key used for call resolution."""
def normalise_callable_label(label: str) -> str;

"""Return True when a node is suitable for deterministic symbol lookup.

    Requires ``file_type == "code"`` as the positive gate — only code-class
    nodes participate as call targets. ``_EXCLUDED_FILE_TYPES`` is kept as
    defensive-in-depth against legacy data, but the primary guard is the
    positive code check. Document/paper/image/concept nodes (e.g. a Markdown
    heading whose label happens to match a code identifier) MUST NOT become
    callees for a raw code call.
    """
def node_is_resolvable_symbol(`node: dict[str, Any]) -> bool;

"""Build label -> node id list for conservative cross-file resolution.

    An enum member can never be the target of a call, in any language that
    reaches this shared index — but it is a node like any other, and its
    label can collide with an unrelated bare name (a delegate-typed field
    named the same as one of its own enum's cases, #4245). When *edges* is
    given, a node that is the target of a `case_of` edge is excluded, the
    same way `_build_csharp_type_def_index` already excludes it from TYPE
    lookup (#3795).
    """
def build_label_index(
    nodes: list[dict[str, Any]], edges: "list[dict[str, Any]] | None" = None
) -> dict[str, list[str]];

"""Return all existing source/target/relation edge triples.

    Includes relation so that a prior "contains" or "method" edge does not
    suppress a semantically distinct "calls" edge between the same endpoints (#F5).
    """
def existing_edge_pairs(edges: list[dict[str, Any]]) -> set[tuple[str, str, str]];

"""Return raw calls from all per-file extraction fragments.

    Parameter is ``Sequence[object]`` (not ``Sequence[dict[str, Any] | None]``)
    because external extraction output may contain arbitrary deserialized
    JSON. Defensive against malformed fragments: non-dict per-file entries
    are skipped, non-list ``raw_calls`` are treated as empty, and non-dict
    items inside the list are silently dropped. The downstream resolvers
    assume every returned item is a dict and they expect this guarantee.
    """
def iter_raw_calls(per_file: Sequence[object]) -> list[dict[str, Any]];

"""Return the final module component used to match Graphify source stems."""
def _module_stem(module_name: str | None) -> str;

"""Parse deterministic Python import aliases from one source file.

    Supported forms:
        from helper import transform
        from helper import transform as tx
        from .helper import transform

    The function deliberately does not resolve plain ``import helper`` member
    calls because current raw call records do not preserve the receiver name from
    ``helper.transform()``. That can be added later only after raw call facts are
    extended to include the receiver expression.
    """
def parse_python_import_aliases(path: Path) -> dict[str, ImportedSymbol];

"""Return the stem of a node's source file."""
def _node_source_stem(`node: dict[str, Any]) -> str;

"""Build ``(module_stem, normalized_symbol_name) -> node_ids``.

    This index is stricter than the global label index. It uses both the module
    stem and the symbol label, which allows import evidence to resolve calls that
    global label uniqueness alone cannot safely resolve.
    """
def build_python_symbol_index(nodes: list[dict[str, Any]]) -> dict[tuple[str, str], list[str]];

"""Resolve one imported symbol to exactly one Graphify node id."""
def find_unique_python_symbol(
    symbol_index: dict[tuple[str, str], list[str]], imported: ImportedSymbol
) -> str | None;

"""Resolve raw Python calls using explicit import evidence.

    Only ``from module import symbol [as alias]`` forms are handled. Member calls
    remain skipped because the current raw call fact does not carry receiver
    information.

    Parameter ``per_file`` is ``Sequence[object]`` because external extraction
    output may contain arbitrary deserialized JSON. Non-dict slots are
    treated as empty fragments, and indices past ``len(per_file)`` are also
    treated as empty (paths longer than per_file is tolerated).
    """
def resolve_python_import_guided_calls(
    per_file: Sequence[object],
    paths: Sequence[Path],
    all_nodes: list[dict[str, Any]],
    all_edges: list[dict[str, Any]],
) -> list[dict[str, Any]];

"""The crate a Rust file belongs to: the nearest directory holding a
    ``Cargo.toml``, else the directory above the nearest ``src``. None when
    neither is found (a flat layout this pass cannot place)."""
@lru_cache(maxsize=4096)
def _rust_crate_root(source_file: str) -> str | None;

"""Return the candidates a Rust ``module::function()`` qualifier verifies.

    The qualifier is matched right-to-left against each candidate's file path:
    the last segment must BE the defining module (``<seg>.rs`` or
    ``<seg>/mod.rs``), and every remaining segment must match the successive
    parent directory. Matching stops at ``crate``/``super``/``self`` — those
    are root-relative, and resolving the root needs a module-tree model this
    deliberately does not attempt; segments to their right are still verified.
    Matching only the last segment let ``std::fs::read()`` bind to an
    unrelated local ``fs.rs`` (shadowing std module names with wrapper modules
    is common Rust); the directory walk fails that on ``std`` vs ``src``.
    Candidates not defined in a ``.rs`` file are skipped — a bare stem match
    let a Rust ``b::helper()`` bind to a Python ``b.py``.

    A candidate must live in the caller's crate (see ``_rust_crate_root``):
    ``crate::util::f()`` in crate_a never means crate_b's ``util.rs``. Methods
    are skipped, since a module path names a free function, never an impl's.

    Returns [] outright when the qualifier disqualifies resolution: a bare
    ``crate``/``super``/``self`` names no module file, and an UpperCamelCase
    segment is a type (``Type::method()`` / ``Enum::Variant`` — rustc enforces
    the case convention), which keeps its pre-existing skipped behavior.
    """
def rust_scoped_call_survivors(
    qualifier: str,
    candidates: Sequence[str],
    nid_to_source_file: dict[str, str],
    caller_file: str = "",
    nid_to_label: "dict[str, str] | None" = None,
) -> list[str];

"""Resolve unqualified raw calls conservatively after all files are known.

    This intentionally preserves Graphify's existing behavior:
    - member calls are skipped;
    - ambiguous labels are skipped;
    - only a single unique candidate is emitted;
    - emitted edges are INFERRED because the raw call alone is not import proof.
    """
def resolve_cross_file_raw_calls(
    per_file: Sequence[dict[str, Any] | None],
    all_nodes: list[dict[str, Any]],
    all_edges: list[dict[str, Any]],
) -> list[dict[str, Any]];

"""Bash symbol node ID via the single shared recipe (#1378).

    Previously an inline copy to dodge an import cycle; ``graphify.ids`` is
    dependency-free, so it can be imported directly.
    """
def _bash_make_id(*parts_: str) -> str;

def _file_node_id_for_path(path: Path, `root: Path) -> str;

"""Resolve Bash source/import edges and source-backed function calls.

    Defensive against malformed extraction fragments: non-dict ``per_file``
    entries, missing ``bash_sources``/``raw_calls`` keys, non-dict items in
    those lists, and missing/empty ``id`` / ``target_path`` / ``caller_nid``
    fields all yield silent skips rather than ``KeyError``.

    ``bash_sources[].target_path`` contract (Graphify static-analysis policy):
        - Absolute paths: resolved as-is.
        - Relative paths: resolved against the *source file's* directory
          (i.e. ``Path(path).parent / target_path``).
          NOTE: this is a deterministic static-analysis policy chosen by
          Graphify, NOT bash runtime semantics. At runtime, ``source ./X``
          is resolved against the shell's current working directory. We
          prefer source-file-relative because static analysis cannot know
          the future CWD; resolving against the file being analyzed gives
          deterministic, reproducible edges across runs.
        - Inputs of type ``str`` and ``pathlib.Path`` are processed.
          Anything else is silently skipped.
    """
def resolve_bash_source_edges(
    per_file: Sequence[dict | None],
    paths: Sequence[Path],
    `root: Path,
    existing_edges: list[dict] | None = None,
) -> list[dict];
