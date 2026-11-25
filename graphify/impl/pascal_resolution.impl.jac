impl _pascal_raw_calls(per_file: list[dict]) -> list[dict] {
    calls: list[dict] = [];
    for result in per_file {
        if not isinstance(result, `dict) {
            continue;
        }
        for rc in result.get("raw_calls", []) {
            if not isinstance(rc, `dict) {
                continue;
            }
            if `str(rc.get("source_file", "")).endswith(_PASCAL_SUFFIXES) {
                calls.append(rc);
            }
        }
    }
    return calls;
}

impl resolve_pascal_inherited_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None {
    class_bases: dict[str, list[str]];
    class_procs: dict[str, dict[str, list[str]]];
    node_by_id: any = {n.get("id"): n for n in all_nodes};

    class_bases = {};
    owner_of: dict[str, str] = {};
    class_procs = {};
    for e in all_edges {
        if e.get("relation") == "inherits" {
            class_bases.setdefault(e["source"], []).append(e["target"]);
        } elif e.get("relation") == "method" {
            owner: any;
            method_nid: any;
            (owner, method_nid) = (e.get("source"), e.get("target"));
            owner_of[method_nid] = owner;
            mnode: any = node_by_id.get(method_nid);
            if mnode is None {
                continue;
            }
            name_lower: any = `str(mnode.get("label", "")).removesuffix("()").lower();
            bucket: any = class_procs.setdefault(owner, {}).setdefault(name_lower, []);
            if method_nid not in bucket {
                bucket.append(method_nid);
            }
        }
    }

    existing_pairs: any = {(e.get("source"), e.get("target")) for e in all_edges};

    def _resolve(owner: str, name_lower: str) -> str | None {
        seen_bases: set[str] = set[any]();
        queue: any = `list(class_bases.get(owner, []));
        while queue {
            base: any = queue.pop(0);
            if base in seen_bases {
                continue;
            }
            seen_bases.add(base);
            candidates: any = class_procs.get(base, {}).get(name_lower);
            if candidates {
                return candidates[0] if len(candidates) == 1 else None;
            }
            queue.extend(class_bases.get(base, []));
        }
        return None;
    }

    for rc in _pascal_raw_calls(per_file) {
        caller: any = rc.get("caller_nid");
        name_lower = rc.get("callee");
        if not caller or not name_lower {
            continue;
        }
        if rc.get("qualifier") {
            continue;
        }
        owner = owner_of.get(caller);
        if not owner {
            continue;
        }
        target: any = _resolve(`str(owner), `str(name_lower));
        if not target or target == caller {
            continue;
        }
        pair: any = (caller, target);
        if pair in existing_pairs {
            continue;
        }
        existing_pairs.add(pair);
        all_edges.append({
            "source": caller,
            "target": target,
            "relation": "calls",
            "context": "call",
            "confidence": "EXTRACTED",
            "confidence_score": 1.0,
            "source_file": rc.get("source_file", ""),
            "source_location": rc.get("source_location"),
            "weight": 1.0,
        });
    }
}
