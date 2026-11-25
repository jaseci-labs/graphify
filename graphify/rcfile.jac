"""Project-level configuration: ``<root>/.graphifyrc``.

One ``key=value`` per line, ``#`` comments, blank lines ignored. Keys:

``viz_node_limit=<int>``
    Baked into the generated git hooks (see :mod:`graphify.hooks`).

``query_budget=<positive int>`` and ``query_depth=<int 1-6>``
    Project defaults for the public ``graphify query`` command. Explicit query
    options override these values; absent settings retain budget 2000, depth 2.

``language.<ext>=<language | .ext>``
    Treat files with extension ``<ext>`` as the named language for
    classification, extractor dispatch and cross-file resolution (#2961).
    ``<ext>`` may be written with or without its leading dot; the value is
    either a language name from :data:`LANGUAGE_ALIASES` or an explicit
    extension graphify already knows (``.php``, ``.pas``, ``.sql``, ...)::

        # pfSense: every .inc under this repo is PHP, not Pascal
        language.inc=php
        # a repo whose templates are plain TypeScript
        language.tpl=.ts

    An ambiguous extension (``.inc`` is PHP, Pascal, SQL or assembly
    depending on the project; ``.m`` is Objective-C or MATLAB; ``.h`` is C or
    C++) has no single correct global mapping, so the project declares it.

The parser imports :mod:`graphify.detect` lazily only when it must validate
an explicit extension.  This avoids a module-level import cycle while keeping
typos from silently disabling classification.
"""

import from __future__ { annotations }

import sys;

import threading;

import from pathlib { Path }

glob RC_FILENAME: any = ".graphifyrc";

glob LANGUAGE_ALIASES: dict[str, str];

glob _BOOL_VALUES: any;

glob _local: any;

glob _warned_roots: any;

with entry {
    LANGUAGE_ALIASES = {
        "php": ".php",
        "pascal": ".pas",
        "delphi": ".pas",
        "freepascal": ".pas",
        "sql": ".sql",
        "python": ".py",
        "javascript": ".js",
        "js": ".js",
        "typescript": ".ts",
        "ts": ".ts",
        "c": ".c",
        "cpp": ".cpp",
        "c++": ".cpp",
        "cxx": ".cpp",
        "objc": ".mm",
        "objective-c": ".mm",
        "objectivec": ".mm",
        "java": ".java",
        "kotlin": ".kt",
        "scala": ".scala",
        "groovy": ".groovy",
        "go": ".go",
        "golang": ".go",
        "rust": ".rs",
        "ruby": ".rb",
        "csharp": ".cs",
        "c#": ".cs",
        "swift": ".swift",
        "lua": ".lua",
        "zig": ".zig",
        "elixir": ".ex",
        "julia": ".jl",
        "dart": ".dart",
        "r": ".r",
        "fortran": ".f90",
        "shell": ".sh",
        "bash": ".sh",
        "sh": ".sh",
        "powershell": ".ps1",
        "verilog": ".v",
        "systemverilog": ".sv",
        "terraform": ".tf",
        "hcl": ".hcl",
        "ocaml": ".ml",
        "lisp": ".lisp",
        "commonlisp": ".lisp",
        "markdown": ".md",
        "json": ".json",
        "yaml": ".yaml",
        "html": ".html",
    };
}

def _normalise_ext(raw: str) -> str;

"""Resolve the right-hand side of ``language.<ext>=`` to a canonical suffix.

    Accepts a name from :data:`LANGUAGE_ALIASES` (case-insensitive) or an
    explicit dotted extension. Raises ``ValueError`` for anything else.
    """
def parse_language_value(value: str) -> str;

with entry {
    _BOOL_VALUES = {
        "true": True,
        "1": True,
        "yes": True,
        "on": True,
        "false": False,
        "0": False,
        "no": False,
        "off": False,
    };
}

"""Parse ``<root>/.graphifyrc``. Returns ``{}`` when absent.

    Returned keys: ``viz_node_limit``, ``query_budget``, ``query_depth`` (ints),
    ``demote_docs`` / ``query_demote_docs`` (bools), and ``languages``
    (``{".inc": ".php", ...}``) — each present only when the file sets it.
    Unknown keys are ignored so a newer graphify's options do not break an
    older one. Malformed lines raise ``ValueError`` naming the line.
    """
def load_graphifyrc(`root: Path) -> dict;

with entry {
    _local = threading.local();
    _warned_roots = set[any]();
}

def _active -> dict[str, str];

"""Replace this thread's extension overrides (``{".inc": ".php"}``)."""
def set_language_overrides(mapping: dict[str, str] | None) -> None;

def get_language_overrides -> dict[str, str];

"""Load ``<root>/.graphifyrc`` and make its language overrides active.

    A malformed file is reported once per root on stderr and treated as
    having no overrides — a scan must not die on a config typo, but the
    user must hear about it, or their ``.inc`` silently stays Pascal.
    Returns the mapping now active.
    """
def activate_language_overrides(`root: Path) -> dict[str, str];

"""The suffix graphify should treat ``path`` as having.

    Returns the override target when the file's extension is remapped, else
    the real suffix untouched (case preserved, so callers that distinguish
    ``.F90`` from ``.f90`` keep doing so).
    """
def effective_suffix(path: Path | str) -> str;

"""Extra cache-key material for a remapped file, else ``None``.

    An AST cache entry is keyed by content, and the same bytes parse to a
    different graph under a different extractor — so a ``.inc`` cached as
    Pascal must not be served once the project declares it PHP.
    """
def cache_salt(path: Path | str) -> str | None;
