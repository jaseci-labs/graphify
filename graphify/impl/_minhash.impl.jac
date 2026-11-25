impl _mh_coeffs(num_perm: int) -> tuple[np.ndarray, np.ndarray] {
    if num_perm not in _MH_COEFFS {
        rng: any = np.random.RandomState(1);
        a: any = rng.randint(1, `int(_MP), num_perm, dtype=np.uint64);
        b: any = rng.randint(0, `int(_MP), num_perm, dtype=np.uint64);
        _MH_COEFFS[num_perm] = (a, b);
    }
    return _MH_COEFFS[num_perm];
}

impl MinHash.init(num_perm: int = 128) {
    self.num_perm = num_perm;
    self.hashvalues = np.full(num_perm, `int(_MH), dtype=np.uint64);
    items_: any = list(_mh_coeffs(num_perm) as any);
    if len(items_) != 2 {
        raise ValueError(
            f"too many values to unpack (expected 2, got {len(items_)})"
                if len(items_) > 2
                else f"not enough values to unpack (expected 2, got {len(items_)})",
        );
    }
    self._a = items_[0];
    self._b = items_[1];
}

impl MinHash.update(v: bytes) -> None {
    hv: any = np.uint64(struct.unpack("<I", hashlib.sha1(v).digest()[:4])[0]);
    phv: any = np.bitwise_and((self._a * hv + self._b) % _MP, _MH);
    self.hashvalues = np.minimum(self.hashvalues, phv);
}

impl MinHash.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl MinHash.__eq__(other: any) -> bool {
    return self is other;
}

impl MinHash.__hash__ -> int {
    return id(self);
}

impl _lsh_integrate(f, lo: float, hi: float, n: int = 128) -> float {
    h: any;
    h = (hi - lo) / n;
    return h * sum(f(lo + i * h) for i in range(n));
}

impl _lsh_false_positive(s: float, _b: float, _r: float) -> float {
    return 1 - (1 - s ** _r) ** _b;
}

impl _lsh_false_negative(s: float, _b: float, _r: float) -> float {
    return 1 - (1 - (1 - s ** _r) ** _b);
}

impl _optimal_lsh_params(threshold: float, num_perm: int) -> tuple[int, int] {
    key: any = (threshold, num_perm);
    if key in _LSH_PARAMS_CACHE {
        return _LSH_PARAMS_CACHE[key];
    }
    best_err: any;
    best: any;
    (best_err, best) = (`float("inf"), (1, 1));
    for b in range(1, num_perm + 1) {
        for r in range(1, num_perm // b + 1) {
            fp: any = _lsh_integrate(
                partial(_lsh_false_positive, _b=`float(b), _r=`float(r)), 0.0, threshold
            );
            fn: any = _lsh_integrate(
                partial(_lsh_false_negative, _b=`float(b), _r=`float(r)), threshold, 1.0
            );
            err: any = 0.5 * fp + 0.5 * fn;
            if err < best_err {
                (best_err, best) = (err, (b, r));
            }
        }
    }
    _LSH_PARAMS_CACHE[key] = best;
    return best;
}

impl MinHashLSH.init(threshold: float = 0.5, num_perm: int = 128) {
    items__: any = list(_optimal_lsh_params(threshold, num_perm) as any);
    if len(items__) != 2 {
        raise ValueError(
            f"too many values to unpack (expected 2, got {len(items__)})"
                if len(items__) > 2
                else f"not enough values to unpack (expected 2, got {len(items__)})",
        );
    }
    self.b = items__[0];
    self.r = items__[1];
    self._tables = [dict[any, any]() for _ in range(self.b)];
    self._keys = set[any]();
}

impl MinHashLSH.insert(key: str, minhash: MinHash) -> None {
    if key in self._keys {
        raise ValueError(f"Key {key!r} already exists in MinHashLSH");
    }
    self._keys.add(key);
    hv: any = minhash.hashvalues;
    for (i, table) in enumerate(self._tables) {
        band: any = hv[i * self.r:(i + 1) * self.r].tobytes();
        table.setdefault(band, []).append(key);
    }
}

impl MinHashLSH.query(minhash: MinHash) -> list[str] {
    hv: any = minhash.hashvalues;
    candidates: set[str] = set[any]();
    for (i, table) in enumerate(self._tables) {
        band: any = hv[i * self.r:(i + 1) * self.r].tobytes();
        candidates.update(table.get(band, []));
    }
    return `list(candidates);
}

impl MinHashLSH.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl MinHashLSH.__eq__(other: any) -> bool {
    return self is other;
}

impl MinHashLSH.__hash__ -> int {
    return id(self);
}
