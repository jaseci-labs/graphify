import from __future__ { annotations }
import from pathlib { Path }

import from typing { Any, Iterable }

import from tree_sitter { Node }

def _atom(value: str) -> str;

def _descendants(`node: Node) -> Generator[any, any, any];
def resolve_erlang_remote_calls(per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]);

def extract_erlang(path: Path) -> dict;
