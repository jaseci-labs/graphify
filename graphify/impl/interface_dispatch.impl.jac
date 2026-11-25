impl _dispatch_confidence(implementer_count: int) -> float {
    return _DISPATCH_CONFIDENCE_BY_IMPLEMENTER_COUNT.get(
        implementer_count, _DISPATCH_CONFIDENCE_FLOOR
    );
}

impl declared_in(`node: dict | None, suffixes: tuple[str, ...]) -> bool {
    if not `node {
        return False;
    }
    source_file: any = `node.get("source_file");
    return `bool(source_file) and effective_suffix(`str(source_file)) in suffixes;
}

impl method_label(`node: dict) -> str {
    label: any = `str(`node.get("label", "")).strip().removeprefix(".");
    return label.split("(", 1)[0];
}

impl resolve_interface_dispatch(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict], *, suffixes: tuple[str, ...]
) -> None {
    if not `any(declared_in(result, suffixes) for result in per_file if isinstance(result, `dict))
        and not `any(declared_in(n, suffixes) for n in all_nodes)
    {
        return;
    }

    node_by_id: any = {n.get("id"): n for n in all_nodes};

    implementers: dict[str, set[str]] = {};
    methods_of: dict[str, dict[str, set[str]]] = {};
    for e in all_edges {
        rel: any = e.get("relation");
        if rel == "implements" {
            implementers.setdefault(e.get("target"), set[any]()).add(e.get("source"));
        } elif rel == "method" {
            owner: any;
            method_nid: any;
            (owner, method_nid) = (e.get("source"), e.get("target"));
            mnode: any = node_by_id.get(method_nid);
            if mnode is None or not declared_in(mnode, suffixes) {
                continue;
            }
            if (mnode.get("metadata") or {}).get("kind") == "constructor" {
                continue;
            }
            name: any = method_label(mnode);
            if name {
                methods_of.setdefault(owner, {}).setdefault(name, set[any]()).add(method_nid);
            }
        }
    }

    if not implementers or not methods_of {
        return;
    }
    existing_pairs: any = {
        (e.get("source"), e.get("target"))
        for e in all_edges
        if e.get("relation") == DISPATCH_RELATION
    };
    new_edges: list[dict] = [];

    for (interface_nid, impls) in implementers.items() {
        interface_node: any = node_by_id.get(interface_nid);
        if interface_node is None or not declared_in(interface_node, suffixes) {
            continue;
        }
        interface_methods: any = methods_of.get(interface_nid, {});
        if not interface_methods {
            continue;
        }
        gated_impls: list[tuple[str, dict]] = [];
        impl_nid: any;
        for impl_nid in impls {
            impl_node: any = node_by_id.get(impl_nid);
            if impl_node is not None and declared_in(impl_node, suffixes) {
                gated_impls.append((impl_nid, impl_node));
            }
        }
        if not gated_impls {
            continue;
        }
        score: any = _dispatch_confidence(len(gated_impls));

        interface_name: any = method_label(interface_node).split("<", 1)[0].strip();
        for (impl_nid, impl_node) in gated_impls {
            impl_methods: any = methods_of.get(impl_nid, {});
            for (name, declared) in interface_methods.items() {
                for (source, target) in _implementing_pairs(
                    declared, impl_methods.get(name, set[any]()), interface_name, node_by_id
                ) {
                    if source == target or (source, target) in existing_pairs {
                        continue;
                    }
                    existing_pairs.add((source, target));
                    new_edges.append({
                        "source": source,
                        "target": target,
                        "relation": DISPATCH_RELATION,
                        "context": "call",
                        "confidence": "INFERRED",
                        "confidence_score": score,
                        "source_file": `str(impl_node.get("source_file", "")),
                        "source_location": impl_node.get("source_location"),
                        "weight": 1.0,
                    });
                }
            }
        }
    }

    all_edges.extend(new_edges);
}

impl _implementing_pairs(
    declared: set[str], candidates: set[str], interface_name: str, node_by_id: dict
) -> list[tuple[str, str]] {
    def _explicit(nid: str) -> str | None {
        meta: any = (node_by_id.get(nid) or {}).get("metadata");
        return meta.get("explicit_interface") if isinstance(meta, `dict) else None;
    }

    `own: any = {c for c in candidates if _explicit(c) == interface_name};
    ordinary: any = {c for c in candidates if not _explicit(c)};
    pairs: any = _overload_pairs(declared, `own, node_by_id) if `own else [];
    left: any = declared - {source for (source, _) in pairs};
    if left and ordinary {
        pairs += _overload_pairs(left, ordinary, node_by_id);
    }
    return pairs;
}

impl _overload_pairs(
    declared: set[str], candidates: set[str], node_by_id: dict
) -> list[tuple[str, str]] {
    if len(declared) == 1 and len(candidates) == 1 {
        return [(next(iter(declared)), next(iter(candidates)))];
    }

    def _meta(nid: str) -> dict {
        meta: any = (node_by_id.get(nid) or {}).get("metadata");
        return meta if isinstance(meta, `dict) else {};
    }

    pairs: dict[str, str] = {};
    for key in ("signature", "arity") {
        taken: any = `set(pairs.values());
        for source in sorted(declared) {
            want: any = _meta(source).get(key);
            if source in pairs or want is None {
                continue;
            }
            hits: any = [c for c in candidates if c not in taken and _meta(c).get(key) == want];
            if len(hits) == 1 {
                pairs[source] = hits[0];
            }
        }
    }
    targets: any = `list(pairs.values());
    return [(s, t) for (s, t) in pairs.items() if targets.count(t) == 1];
}
