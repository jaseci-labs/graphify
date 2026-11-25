import builtins;
import from __future__ { annotations }

import functools;

import hashlib;

import re;

import unicodedata;

import from pathlib { Path }

glob __all__: any = ["normalize_id", "make_id", "decl_salt", "DeclIdRegistry"];

glob _NONWORD_RE: any;

glob _COLLAPSE_UNDERSCORE_RE: any;

with entry {
    _NONWORD_RE = re.compile("[^\\w]+", re.UNICODE);
    _COLLAPSE_UNDERSCORE_RE = re.compile("_+");
}

@functools.lru_cache(maxsize=1 << 17)
def normalize_id(s: str) -> str;
def decl_salt(name: str) -> str;

obj DeclIdRegistry {
    has _assigned: any,
        _owners: any,
        _by_name: any,
        _salted: any,
        _spelled: any,
        _respelled: any;

    def init(reserved_ids=());

    def resolve(nid: str, name: str, kind: str, taken) -> str;
    def _salt(nid: str, name: str, kind: str, taken) -> str;

    def lookup(name: str, kinds=("type", "fn", "var", "ns", "alias")) -> str | None;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def make_id(*parts_: str) -> str;
def _file_stem(path: Path) -> str;
