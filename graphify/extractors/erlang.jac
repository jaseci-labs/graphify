"""Structural extraction for Erlang source and header files."""

import from __future__ { annotations }

import from pathlib { Path }

import from typing { Any, Iterable }

import from tree_sitter { Node }

def _atom(value: str) -> str;

def _descendants(`node: Node) -> Generator[any, any, any];

"""Resolve module-qualified calls by exact module, name, and arity."""
def resolve_erlang_remote_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;

def extract_erlang(path: Path) -> dict;
