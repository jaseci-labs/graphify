"""MinHash + band-LSH — datasketch-compatible drop-in (no scipy).

datasketch.lsh has `from scipy.integrate import quad` at module level.
scipy's array_api_compat layer then lazily loads numpy.testing, which calls
platform.machine() at import time to set test-skip decorator constants — and
that in turn spawns cmd.exe via subprocess, hanging for minutes under EDR
software in corporate Windows environments.

Covers the exact MinHash/MinHashLSH API surface used by dedup.py.
Hash family (Mersenne-prime permutations) and LSH band structure are
equivalent to datasketch so dedup quality is unchanged.
"""

import builtins;

import from __future__ { annotations }

import hashlib;

import struct;

import from functools { partial }

import numpy as np;

glob _MP: any;

glob _MH: any;

glob _MH_COEFFS: any;

glob _LSH_PARAMS_CACHE: dict[tuple[float, int], tuple[int, int]];

with entry {
    _MP = np.uint64((1 << 61) - 1);
    _MH = np.uint64(4294967295);
    _MH_COEFFS = {};
}

def _mh_coeffs(num_perm: int) -> tuple[np.ndarray, np.ndarray];

"""MinHash sketch — same API as datasketch.MinHash for the subset used here."""
obj MinHash {
    has num_perm: any,
        hashvalues: any,
        _a: any,
        _b: any;

    static has __slots__: any = ("num_perm", "hashvalues", "_a", "_b");

    def init(num_perm: int = 128);

    def update(v: bytes) -> None;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""Numerical integration — replaces scipy.integrate.quad for LSH param search."""
def _lsh_integrate(f, lo: float, hi: float, n: int = 128) -> float;

with entry {
    _LSH_PARAMS_CACHE = {};
}

def _lsh_false_positive(s: float, _b: float, _r: float) -> float;

def _lsh_false_negative(s: float, _b: float, _r: float) -> float;

"""Find (bands, rows) that minimise weighted FP+FN error, without scipy."""
def _optimal_lsh_params(threshold: float, num_perm: int) -> tuple[int, int];

"""Band-hashing LSH — same API as datasketch.MinHashLSH for the subset used here."""
obj MinHashLSH {
    has b: any,
        r: any,
        _tables: any,
        _keys: any;

    def init(threshold: float = 0.5, num_perm: int = 128);

    def insert(key: str, minhash: MinHash) -> None;

    def query(minhash: MinHash) -> list[str];

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}
