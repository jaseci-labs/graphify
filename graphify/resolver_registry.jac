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

@dataclass(frozen=True)
class LanguageResolver {
    has name: str;

    has suffixes: frozenset;

    has resolve: Callable;
}

with entry {
    _REGISTRY = [];
}

def register(resolver: LanguageResolver) -> LanguageResolver;
def registered_resolvers -> list[LanguageResolver];
def run_language_resolvers(
    paths: Sequence[Path],
    per_file: list[dict],
    all_nodes: list[dict],
    all_edges: list[dict],
    *,
    resolvers: Sequence[LanguageResolver] | None = None,
);
