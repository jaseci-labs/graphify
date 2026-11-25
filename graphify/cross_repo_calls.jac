import importlib;
import operator;
import from __future__ { annotations }

import os;

import from collections { defaultdict }

import from typing { TYPE_CHECKING }

glob CROSS_REPO_CALL_MARKER: any = "_cross_repo_call";

glob UNRESOLVED_CALLS_KEY: any = "unresolved_calls";

glob _LANG_SUFFIXES: dict[str, frozenset[str]];

glob _MEMBER_RELATIONS: any;

glob _OBJC_IMPL_SUFFIXES: any;

with entry {
    _LANG_SUFFIXES = {
        "cpp": frozenset({".cpp", ".cc", ".cxx", ".hpp", ".hh", ".hxx", ".h", ".cu", ".cuh"}),
        "csharp": frozenset({".cs"}),
        "go": frozenset({".go"}),
        "java": frozenset({".java"}),
        "kotlin": frozenset({".kt", ".kts"}),
        "objc": frozenset({".h", ".m", ".mm"}),
        "swift": frozenset({".swift"}),
        "php": frozenset({".php", ".phtml", ".php3", ".php4", ".php5", ".php7", ".phps"}),
        "typescript": frozenset({
            ".ts",
            ".tsx",
            ".mts",
            ".cts",
            ".js",
            ".jsx",
            ".mjs",
            ".cjs",
            ".vue",
            ".svelte",
            ".astro",
        }),
    };
    _MEMBER_RELATIONS = ("defines", "method");
    _OBJC_IMPL_SUFFIXES = frozenset({".m", ".mm"});
}

def _key(label: object) -> str;

def _suffix(source_file: object) -> str;

def _parked_entries(data: dict) -> list[dict];
def _drop_previous_output(merged: "nx.Graph");
def _index_declarations(merged: "nx.Graph") -> tuple[dict[str, list[str]], set[str]];
def _index_members(
    merged: "nx.Graph", type_ids: set[str]
) -> dict[str, dict[tuple[str, str], list[str]]];
def _member_relations(lang: str) -> tuple[str, ...];
def _member_keys(lang: str, callee: str) -> tuple[str, ...];
def _objc_union_definition(
    merged: "nx.Graph",
    members: dict[tuple[str, str], list[str]],
    candidates: list[str],
    callee: str,
) -> str | None;
def _java_overload_target(merged: nx.Graph, targets: list[str], arity: object) -> str | None;
def link_cross_repo_member_calls(merged: "nx.Graph") -> int;
