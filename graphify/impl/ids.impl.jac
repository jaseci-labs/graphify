impl normalize_id(s: str) -> str {
    if s.isascii() {
        cur: any = s.lower();
    } else {
        cur = s;
        for _ in range(6) {
            nxt: any = unicodedata.normalize("NFKC", cur.casefold());
            if nxt == cur {
                break;
            }
            cur = nxt;
        }
    }
    cur = _NONWORD_RE.sub("_", cur);
    cur = _COLLAPSE_UNDERSCORE_RE.sub("_", cur);
    return cur.strip("_");
}

impl decl_salt(name: str) -> str {
    return hashlib.sha1(name.encode("utf-8", "replace"), usedforsecurity=False).hexdigest()[:12];
}

impl DeclIdRegistry.init(reserved_ids=()) {
    self._assigned = {};
    self._owners = {rid: ("file", rid) for rid in reserved_ids};
    self._by_name = {};
    self._salted = set[any]();
    self._spelled = {};
    self._respelled = {};
}

impl DeclIdRegistry.resolve(nid: str, name: str, kind: str, taken) -> str {
    key: any = (kind, nid);
    owner: any = self._owners.get(nid);
    if owner == key {
        first: any = self._spelled.get(nid, name);
        if name == first or name.strip("_") != first.strip("_") {
            return self._assigned[key];
        }
        respelled: any = self._respelled.get((kind, nid, name));
        if respelled is not None {
            return respelled;
        }
        candidate: any = self._salt(nid, name, kind, taken);
        self._owners[candidate] = (kind, candidate);
        self._assigned[kind, candidate] = candidate;
        self._respelled[kind, nid, name] = candidate;
        return candidate;
    }
    if nid not in taken and owner is None {
        self._owners[nid] = key;
        self._assigned[key] = nid;
        self._spelled[nid] = name;
        self._by_name.setdefault((kind, normalize_id(name)), set[any]()).add(nid);
        return nid;
    }
    assigned: any = self._assigned.get(key);
    if assigned is not None {
        return assigned;
    }
    if nid in taken
        and owner is not None
        and owner[0] != "file"
        and nid not in self._salted
        and (owner[0] == kind or self._spelled.get(nid) == name)
    {
        return nid;
    }
    candidate = self._salt(nid, name, kind, taken);
    self._owners[candidate] = key;
    self._assigned[key] = candidate;
    return candidate;
}

impl DeclIdRegistry._salt(nid: str, name: str, kind: str, taken) -> str {
    base: any = make_id(nid, decl_salt(name));
    candidate: any = base;
    counter: any = 2;
    while candidate in taken or candidate in self._owners {
        candidate = make_id(base, `str(counter));
        counter += 1;
    }
    self._salted.add(candidate);
    self._spelled[candidate] = name;
    self._by_name.setdefault((kind, normalize_id(name)), set[any]()).add(candidate);
    return candidate;
}

impl DeclIdRegistry.lookup(name: str, kinds=("type", "fn", "var", "ns", "alias")) -> str | None {
    norm: any = normalize_id(name);
    exact: any = {
        i
        for kind in kinds
        for i in self._by_name.get((kind, norm), ())
        if self._spelled.get(i) == name
    };
    if len(exact) == 1 {
        return next(iter(exact));
    }
    for kind in kinds {
        ids: any = self._by_name.get((kind, norm));
        if ids {
            return next(iter(ids)) if len(ids) == 1 else None;
        }
    }
    return None;
}

impl DeclIdRegistry.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl DeclIdRegistry.__eq__(other: any) -> bool {
    return self is other;
}

impl DeclIdRegistry.__hash__ -> int {
    return id(self);
}

impl make_id(*parts_: str) -> str {
    parts: any = tuple(parts_);
    return normalize_id("_".join(p.strip("_.") for p in parts if p));
}

impl _file_stem(path: Path) -> str {
    if not path.name {
        return "";
    }
    return path.with_suffix("").as_posix();
}
