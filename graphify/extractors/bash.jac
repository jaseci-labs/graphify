"""Bash extractor. Moved verbatim from graphify/extract.py."""

import importlib;
import operator;

import from __future__ { annotations }

import os;

import re;

import from pathlib { Path }

import from typing { Any }

glob _BASH_LEADING_EXPANSION: any;

glob _BASH_SOURCE_DIRNAME: any;

glob _BASH_LEADING_VAR: any;

glob _BASH_DIRNAME_IDIOM: any;

with entry {
    _BASH_LEADING_EXPANSION = re.compile("^(?:(?:\\$\\{[^}]*\\}|\\$[A-Za-z_][A-Za-z0-9_]*)/?)+");
}

"""Return the literal path suffix of a variable-built `source` argument, or
    None when the remainder is empty or still holds an expansion.

    ``"${DIR}/lib/x.sh"`` -> ``"lib/x.sh"``.

    When *allow_dotdot* is False (the default — the base is a script-dir guess),
    ``..`` segments are rejected to prevent traversal outside the project tree.
    When True (the base is a tracked var_bases entry — a known directory),
    ``..`` is permitted and the caller normalises with ``os.path.normpath``.
    """
def _bash_source_suffix(raw: str, allow_dotdot: bool = False) -> str | None;

"""True if *target* is *ceiling* or lives beneath it, compared lexically
    (normpath, no filesystem access).

    A ``source`` path built with ``..`` (the ``$VAR/../lib`` idiom, #2596 form 4,
    or a ``$(dirname …)`` prefix) must not be allowed to walk up to an arbitrary
    host path: a corpus is attacker-controllable, and both the ``is_file()``
    existence probe and the recorded absolute ``target_file`` on the emitted edge
    are a corpus-side information leak (``source "$VAR/../../../../etc/passwd"``).
    Callers gate the probe/emit on this so a target that escapes the allowed tree
    is dropped before it is ever stat-ed. Defense in depth only:
    ``resolve_bash_source_edges`` independently keeps a *resolved* edge only when
    the target is itself a scanned corpus file."""
def _within_tree(ceiling: Path, target: Path) -> bool;

"""True when it is safe to stat *target*, a path named by the indexed corpus.

    A ``source`` line or script invocation in a scanned file can name a path the
    OS resolves off-host. The worst case is a UNC path (``\\\\host\\share\\x`` or
    ``//host/share/x``): on Windows, stat-ing one coerces outbound SMB
    authentication to an attacker-chosen host and leaks a NetNTLMv2 response, with
    no LLM call or other setup (GHSA-g6c9-j4vm-mwq4). An absolute path that escapes
    the indexed tree is a weaker, local information leak. The stat itself
    (``exists()`` / ``is_file()``) is the trigger, so every caller MUST check this
    first and short-circuit before probing.

    A UNC path is refused unconditionally. When the scan root is known (the normal
    ``extract()`` flow sets it), the target must stay within that tree. Outside a
    known root (a direct extractor call, e.g. in a unit test), legacy behavior is
    preserved except that UNC paths are still refused.
    """
def _safe_to_probe(target: Path, scan_root: Path | None) -> bool;

"""Resolve *candidate* (a corpus-named path) only when it is safe to stat.

    Returns the resolved path when it stays within the scan root and is not UNC,
    else None. The UNC/out-of-tree check runs on the UNRESOLVED candidate first,
    so a hostile ``//host/share`` path is never passed to ``resolve()`` — which on
    Windows can itself trigger the network round trip (GHSA-g6c9-j4vm-mwq4). The
    resolved path is re-checked to catch an in-tree path that normalizes outside
    the tree. Callers still gate the ``exists()``/``is_file()`` probe on a
    non-None return."""
def _resolve_safe(candidate: Path, scan_root: Path | None) -> "Path | None";

with entry {
    _BASH_SOURCE_DIRNAME = re.compile(
        "\\$\\(dirname\\s+\"\\$\\{?([A-Za-z_][A-Za-z0-9_]*)\\}?\"\\)"
    );
    _BASH_LEADING_VAR = re.compile(
        "^\\$\\{([A-Za-z_][A-Za-z0-9_]*)[^}]*\\}|^\\$([A-Za-z_][A-Za-z0-9_]*)"
    );
    _BASH_DIRNAME_IDIOM = re.compile("dirname[^)]*\\)((?:/\\.\\.)*)");
}

"""Resolve a top-level assignment's value to a directory, or None if untracked.

    Covers the two forms that make a ``source "${VAR}/lib/x.sh"`` target knowable
    statically (#2172):

    * the script-dir idiom ``"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"``,
      including any number of trailing ``/..`` hops (and the ``$0`` spelling)
    * a literal path, absolute or relative to the script's own directory

    Anything else -- a value built from other variables, or command substitution
    we do not model -- is left untracked so the caller keeps its previous
    script-dir guess rather than binding somewhere invented.
    """
def _bash_assignment_base(value: str, script_dir: Path) -> Path | None;

"""Extract functions, source imports, and cross-function calls from a .sh file."""
def extract_bash(path: Path) -> dict;
