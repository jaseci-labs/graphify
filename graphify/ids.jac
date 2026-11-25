"""Single source of truth for node-ID normalization.

Three independent producers must agree on node IDs or the graph splits a single
entity into disconnected ghost nodes:

1. The AST extractor (``extract._make_id``) — deterministic, per-language.
2. The semantic subagents (LLM) — follow the node-ID spec in the skill prompt.
3. The graph builder (``build._normalize_id``) — reconciles edge endpoints when
   the LLM emits IDs with slightly different punctuation or casing than the AST.

Historically the normalization recipe was copy-pasted into ``extract._make_id``
and ``build._normalize_id`` and kept in sync only by mirrored docstrings, which
is exactly how the recurring ID-drift bug class crept in (#811 Unicode collapse,
#550 same-filename collisions, #1033 AST-vs-LLM file-node mismatch, #1104). This
module exists so the recipe lives in one place and the two callers can no longer
diverge.

The recipe: iterate ``casefold`` then NFKC-normalize to a fixpoint (casefold can
*expand* a character into a base letter plus a combining mark — ``İ`` -> ``i`` +
U+0307 — and NFKC then recomposes what can be recomposed; because the two do not
commute and neither is a fixpoint of the other, a single pass is not
caseless-stable), then replace runs of non-word characters with a single
underscore (``re.UNICODE`` so CJK/Cyrillic/Arabic/accented-Latin letters survive
instead of collapsing to a per-file node), collapse repeated underscores, then
strip leading/trailing underscores.

Casefolding runs BEFORE the non-word filter, not after. With it last, the
combining marks casefold introduces were never filtered: ``İslemYap`` produced
``i̇slemyap`` — an id containing U+0307, which is not a ``\\w`` character — and a
second pass collapsed it to ``i_slemyap``, so the function was not idempotent
and the builder's re-normalization disagreed with the extractor's ``make_id``
for any Turkish identifier (#2614).

Casefolding runs in a FIXPOINT LOOP, not once. A single ``NFKC(casefold(...))``
left ``normalize_id(s) != normalize_id(s.casefold())`` for some combining-mark
sequences (Greek ypogegrammeni U+0345 followed by a combining accent):
pre-casefolding turns U+0345 into ``ι``, which NFKC composes with the accent into
a precomposed char the single pass never reached. Iterating to a fixpoint —
casefold first, on the raw input — makes the result caseless-stable regardless of
how many times the caller has already casefolded.
"""

import builtins;

import from __future__ { annotations }

import functools;

import hashlib;

import re;

import unicodedata;

import from pathlib { Path }

glob __all__: any = ["normalize_id", "make_id", "decl_salt", "DeclIdRegistry"];

glob _NONWORD_RE: any;

glob _COLLAPSE_UNDERSCORE_RE: any;

with entry {
    _NONWORD_RE = re.compile("[^\\w]+", re.UNICODE);
    _COLLAPSE_UNDERSCORE_RE = re.compile("_+");
}

"""Normalize a single ID string to its canonical form.

    Guarantees, all enforced by tests:

    - Idempotent: ``normalize_id(normalize_id(s)) == normalize_id(s)``.
    - The result contains only ``\\w`` characters and ``_``.
    - Caseless-stable: ``normalize_id(s) == normalize_id(s.casefold())``.

    casefold and NFKC do not commute, and neither is a fixpoint of the other:
    casefolding a char can expand it into a base letter plus a combining mark
    (``İ`` -> ``i`` + U+0307), and NFKC can then recompose that mark with an
    adjacent one into a different precomposed char. A single ``NFKC(casefold(...))``
    pass therefore left ``normalize_id(s) != normalize_id(s.casefold())`` for some
    combining-mark sequences (e.g. Greek ypogegrammeni U+0345 followed by a
    combining accent): pre-casefolding turned U+0345 into ``ι`` which NFKC then
    composed with the accent, reaching a form the single-pass recipe never saw.

    So iterate ``casefold`` then ``NFKC`` to a fixpoint (casefold FIRST, on the
    raw input, so a caller that pre-casefolds lands on the same fixpoint). The
    loop is bounded — Unicode caseless folding converges in one or two steps —
    with a hard cap as a termination guard. Only then apply the ``[^\\w]+`` filter,
    so every combining mark casefold introduced has been fully normalized before
    it is filtered (#2614 and its combining-mark follow-on).

    Performance: the result is memoised (``functools.lru_cache``) because the same
    id strings recur across the AST extractor, the builder's edge-endpoint
    reconciliation and the dedup pass, and pure-ASCII inputs — the overwhelming
    majority of real identifiers — take an ASCII fast-path. For a pure-ASCII ``s``,
    ``s.casefold() == s.lower()`` stays ASCII, NFKC is the identity on ASCII, and the
    loop therefore reaches its fixpoint at ``s.lower()`` in two passes; computing
    ``s.lower()`` directly is byte-identical to running the loop, verified by a
    differential check over every identifier harvested from this source tree plus an
    adversarial Unicode set. Non-ASCII inputs still run the full fixpoint loop, so
    semantics are unchanged for every input.
    """
@functools.lru_cache(maxsize=1 << 17)
def normalize_id(s: str) -> str;

"""Stable 12-hex digest appended when a declaration id collides (#4854)."""
def decl_salt(name: str) -> str;

"""Assign unique ids to declarations in one file.

    Ownership is keyed by the id the declaration would have used plus its kind.
    The first declaration to claim an id keeps it; a later one whose names
    normalize alike is salted apart when it is a different kind spelled
    differently (``class Foo`` / ``function foo``, #4904) or the same kind
    spelled differently only by leading/trailing underscores (``_save`` /
    ``save``, #2810). A same-kind respelling that differs otherwise (``Foo`` /
    ``FOO``) and an identical spelling (prototype + body, a reopened class) reuse
    the id. A reference lookup by name only answers when exactly one
    declaration in the file spells that name; an ambiguous name keeps the
    caller's existing fallback.
    """
obj DeclIdRegistry {
    has _assigned: any,
        _owners: any,
        _by_name: any,
        _salted: any,
        _spelled: any,
        _respelled: any;

    def init(reserved_ids=());

    def resolve(nid: str, name: str, kind: str, taken) -> str;

    """Mint and record a salted id for ``name``; the caller records ownership."""
    def _salt(nid: str, name: str, kind: str, taken) -> str;

    def lookup(name: str, kinds=("type", "fn", "var", "ns", "alias")) -> str | None;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""Build a canonical node ID from one or more name parts.

    Parts are joined with ``_`` (after stripping stray ``_``/``.`` edges from each
    part) and then run through :func:`normalize_id`, so the result is identical to
    what the builder produces from the joined string.
    """
def make_id(*parts_: str) -> str;

"""Stem used as the node-ID prefix for a file and its symbols.

    The full path (extension dropped) is preserved as path segments; ``make_id``
    later collapses the separators to underscores. Using every segment — not just
    the immediate parent dir (#1504) — means same-named files in different
    directories get distinct IDs instead of colliding into one
    last-writer-wins node:

        docs/v1/api/README.md -> docs/v1/api/README -> docs_v1_api_readme
        docs/v2/api/README.md -> docs/v2/api/README -> docs_v2_api_readme

    Top-level files keep a bare stem (``setup.py`` -> ``setup``). When passed an
    absolute path the whole path is encoded; the extract() id-remap post-pass
    re-derives the canonical repo-relative form from ``source_file`` so the on-disk
    location can't leak into the persisted IDs (#502).

    Returns "" for a path with no name (``Path('.')`` — a source_file that equals
    the scan root, so it has no per-file stem). Guarding here keeps
    ``path.with_suffix("")`` from raising ``ValueError: '.' has an empty name`` and
    protects every caller, not just ``_semantic_id_remap`` (#1618)."""
def _file_stem(path: Path) -> str;
