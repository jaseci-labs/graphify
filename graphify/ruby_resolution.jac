import operator;
import from __future__ { annotations }

import re;

import from typing { Any }
def _key(label: str) -> str;

def _method_name(label: object) -> str;

def _ruby_method_kind(`node: dict | None) -> str | None;

def _ruby_lookup_unsafe(`node: dict | None) -> bool;

glob _BARE_CONST_RE: any;

with entry {
    _BARE_CONST_RE = re.compile("^[A-Z][A-Za-z0-9_]*(?:::[A-Z][A-Za-z0-9_]*)*$");
}

def _ruby_raw_calls(per_file: list[dict]) -> list[dict];
def resolve_ruby_member_calls(per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]);
