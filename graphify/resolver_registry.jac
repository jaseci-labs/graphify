"""Registry for cross-file, language-specific resolution passes.

Some call/reference edges can only be resolved with language-specific knowledge
(receiver typing, qualified member calls, framework conventions). Historically
these ran as a hand-wired sequence of suffix-gated
``if <lang>_paths: try: _resolve_<lang>(...)`` blocks at the tail of
``extract.extract()``. That pattern is the de-facto extension point for
per-language resolution; this module formalizes it so a new language plugs in by
registering one ``LanguageResolver`` instead of editing ``extract()``'s body.

This module deliberately knows nothing about any specific language — languages
register themselves (see ``extract.py``), keeping the dependency direction one
way (``extract`` → ``resolver_registry``) and this seam small and reviewable on
its own, separate from the multi-thousand-line ``extract`` module.
"""

import from __future__ { annotations }

import importlib;
import logging;

import from collections.abc { Sequence }

import from dataclasses { dataclass }

import from pathlib { Path }

import from typing { Callable }

glob _LOG: any;

glob _REGISTRY: list[LanguageResolver];

with entry {
    _LOG = logging.getLogger(__name__);
}

"""One cross-file, language-specific resolution pass.

    ``resolve`` has the signature ``(per_file, all_nodes, all_edges) -> None`` and
    mutates ``all_nodes`` / ``all_edges`` in place, matching the existing
    member-call resolvers. ``suffixes`` gates activation: the pass runs only when
    the corpus contains at least one file with one of these extensions.
    """
@dataclass(frozen=True)
class LanguageResolver {
    has name: str;

    has suffixes: frozenset;

    has resolve: Callable;
}

with entry {
    _REGISTRY = [];
}

"""Append a resolver to the global registry and return it (for inline use)."""
def register(resolver: LanguageResolver) -> LanguageResolver;

"""Return a copy of the registered resolvers, in registration order."""
def registered_resolvers -> list[LanguageResolver];

"""Run every resolver whose suffix appears in ``paths``.

    Behaviorally identical to the prior hand-wired sequence of suffix-gated,
    try/except-wrapped passes: same activation rule (suffix present), same
    failure handling (log a warning and continue to the next pass), same
    execution order (registration order).

    ``resolvers`` defaults to the global registry; tests pass an explicit list to
    exercise the driver in isolation.
    """
def run_language_resolvers(
    paths: Sequence[Path],
    per_file: list[dict],
    all_nodes: list[dict],
    all_edges: list[dict],
    *,
    resolvers: Sequence[LanguageResolver] | None = None,
) -> None;
