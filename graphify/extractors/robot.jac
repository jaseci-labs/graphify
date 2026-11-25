"""Robot Framework extractor for .robot/.resource files (issue #3192)."""

import from __future__ { annotations }

import builtins;

import os;

import re;

import from pathlib { Path }

glob _ROBOT_STDLIBS: any;

glob _ROBOT_VAR_RE: any;

glob _BDD_PREFIXES: any;

with entry {
    _ROBOT_STDLIBS = frozenset({
        "BuiltIn",
        "Collections",
        "DateTime",
        "Dialogs",
        "Easter",
        "OperatingSystem",
        "Process",
        "Remote",
        "Reserved",
        "Screenshot",
        "String",
        "Telnet",
        "XML",
    });

    _ROBOT_VAR_RE = re.compile("\\$\\{([^}]*)\\}");
}

"""Resolve a Settings-section import path relative to the importing file.

    Preserves the relative/absolute form of source_path so the target ID
    matches the ID the imported file's own extraction produces (same approach
    as the JS relative-import resolver). Robot matches variable names case-,
    space-, and underscore-insensitively, so ``${curdir}`` and ``${Cur_Dir}``
    resolve like ``${CURDIR}``. Returns None when the path holds any other
    (unresolvable) ${VARIABLE} or %{ENV_VAR}.
    """
def _resolve_robot_import(raw: str, source_path: Path) -> Path | None;

with entry {
    _BDD_PREFIXES = ("given ", "when ", "then ", "and ", "but ");
}

"""Node ID for a keyword, normalized the way Robot Framework matches
    keyword names: case-, space-, and underscore-insensitive. Stripping
    spaces/underscores before _make_id means ``Open Session``,
    ``open_session``, and ``OpenSession`` all share one node ID, exactly as
    Robot resolves them to one keyword."""
def _kw_id(name: str) -> str;

"""Extract suites, test cases, user keywords, imports, and keyword calls
    from Robot Framework .robot/.resource files via the official robot.api
    parser (no maintained tree-sitter grammar exists for Robot Framework).

    Nodes: the suite/resource file, its test cases, and its user keywords.
    Edges: `contains` (file -> test case / keyword), `imports` (file -> the
    Resource/Library/Variables files it pulls in, resolved onto the imported
    file's own node; non-stdlib named libraries like SeleniumLibrary get stub
    nodes so suites sharing a library cluster together), and `calls`
    (test case / keyword / suite fixture -> the keyword it invokes).

    Keyword nodes are keyed by bare keyword name (not stem-qualified),
    normalized the way Robot matches keywords (case-, space-, and
    underscore-insensitive, see _kw_id): Robot resolves keywords globally by
    name across imported resources, so bare IDs make cross-file call edges
    land on the defining node without a separate resolution pass. Two files
    defining the same keyword name deliberately merge into one node - that
    mirrors Robot's own single global namespace (where such duplicates are
    ambiguous). Test case nodes stay stem-qualified because test names repeat
    across suites. Calls to keywords never defined in the corpus (e.g.
    BuiltIn's Log) are dropped by build_from_json like any external reference.
    """
def extract_robot(path: Path) -> dict;
