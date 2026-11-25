import from __future__ { annotations }
import os;

import from pathlib { Path }
def _local_extends_target(config: Path, ref: str) -> "Path | None";
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

def _is_config_json(path: Path, obj_node, source: bytes) -> bool;
def extract_json(path: Path) -> dict;
