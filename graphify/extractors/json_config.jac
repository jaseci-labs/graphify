"""Json_config extractor. Moved verbatim from graphify/extract.py."""

import from __future__ { annotations }

import os;

import from pathlib { Path }

"""The on-disk config a relative `extends` names, or None (#5223).

    tsc resolves a relative or absolute `extends` against the citing config's
    directory and, when that file is missing and the value does not end in
    `.json`, retries with `.json` appended. Anything else is a package
    specifier, resolved through node_modules, and stays a stub.
    """
def _local_extends_target(config: Path, ref: str) -> "Path | None";

"""Directory a config's `compilerOptions.paths` targets resolve against.

    tsc uses `baseUrl` when one is in effect (the config's own, else the nearest
    one inherited through `extends`, each resolved against the config declaring
    it), and otherwise the directory of the config declaring `paths`. Returns
    None when the chain leaves the scan (a package `extends`) before a baseUrl
    is found, since the base can then not be known (#5223).
    """
def _paths_base(config: Path) -> "Path | None";

glob _CONFIG_JSON_NAMES: any;

glob _CONFIG_JSON_KEYS: any;

glob _SCHEMA_DEFINITION_KEYS: any;

with entry {
    _CONFIG_JSON_NAMES = frozenset({
        "package.json",
        "tsconfig.json",
        "jsconfig.json",
        "composer.json",
        "deno.json",
        "deno.jsonc",
        "bower.json",
        "manifest.json",
        "app.json",
        "now.json",
        "vercel.json",
        "angular.json",
        "nest-cli.json",
        "biome.json",
        "biome.jsonc",
        "renovate.json",
        ".babelrc",
        ".babelrc.json",
        ".eslintrc.json",
        ".prettierrc.json",
        ".prettierrc",
        "babel.config.json",
    });

    _CONFIG_JSON_KEYS = frozenset({
        "dependencies",
        "devDependencies",
        "peerDependencies",
        "optionalDependencies",
        "bundleDependencies",
        "bundledDependencies",
        "extends",
        "$schema",
        "compilerOptions",
    });
    _SCHEMA_DEFINITION_KEYS = frozenset({"$defs", "definitions", "$id"});
}

"""True if a .json file is a recognized config/manifest worth AST-extracting.

    Matches by filename first (cheap), then falls back to a top-level key probe
    so arbitrarily-named config files (e.g. ``api.tsconfig.json``,
    ``foo.eslintrc.json``) are still picked up. Returns False for data JSON so it
    is skipped by the structural pass (#1224).

    A JSON Schema is *not* a config manifest. `$schema` sits in the probe's key
    set because configs legitimately carry it, but it is also the defining marker
    of a schema -- so a schema document satisfied the probe and was walked in
    full, re-opening the keyword-node explosion #1224 closed (#2255). One 160 KB
    contract contributed 362 keyword nodes and ~12 schema-only communities. The
    filename branches above run first, so `biome.json`/`renovate.json`/
    `package.json` never depended on the probe; the probe only decides the fate
    of arbitrarily-named files, which is why narrowing it is low-risk.

    Documented boundary: a hand-written schema carrying `$schema` but no
    `$defs`/`definitions`/`$id` is still walked. Catching it would need a
    keyword-density heuristic, which would risk skipping a real config whose keys
    happen to overlap schema vocabulary -- the worse error, since it drops
    structure silently (#1224). Pinned by
    ``tests/test_json_schema_config.py::test_minimal_schema_without_defs_or_id_is_still_walked``.
    """
def _is_config_json(path: Path, obj_node, source: bytes) -> bool;

"""Extract structure and dependency edges from a *config/manifest* .json file.

    Data-shaped JSON (eval fixtures, datasets, GeoJSON, API response dumps) is
    deliberately skipped — AST-walking it produced hundreds of orphan key-nodes
    and duplicate communities that swamped real structure (#1224). JSON Schema
    documents are skipped for the same reason (#2255). Recognition is by filename
    (package.json, tsconfig.json, …) or a top-level key probe (dependencies /
    extends / $schema / compilerOptions)."""
def extract_json(path: Path) -> dict;
