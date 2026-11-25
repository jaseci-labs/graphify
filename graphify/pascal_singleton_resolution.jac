import from __future__ { annotations }
import os;

glob _PASCAL_SUFFIXES: any = (".pas", ".pp", ".dpr", ".dpk", ".inc");

def _is_pascal(source_file: object) -> bool;

def _basename(path: str) -> str;

def _unit_stem(source_file: str) -> str;
def _raw_path_of(result: dict) -> str | None;
def _corpus_path_matcher(corpus_files: set[str]) -> any;
def resolve_pascal_singleton_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
);
