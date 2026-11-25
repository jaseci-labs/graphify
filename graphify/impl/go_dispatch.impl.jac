impl _is_go_interface(`node: dict | None) -> bool {
    meta: any = (`node or {}).get("metadata");
    return isinstance(meta, `dict)
        and operator.eq(meta.get("language"), "go")
        and operator.eq(meta.get("kind"), "interface");
}

impl resolve_go_interface_dispatch(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None {
    interfaces: any;
    method_names: dict[str, set[str]];
    embeds: dict[str, set[str]];
    iface: any;
    interfaces = {
        n.get("id"): n
        for n in all_nodes
        if _is_go_interface(n) and declared_in(n, _GO_SUFFIXES)
    };
    if not interfaces {
        return;
    }
    node_by_id: any = {n.get("id"): n for n in all_nodes};

    method_names = {};
    embeds = {};
    type_set_constrained: set[str] = set[any]();
    for e in all_edges {
        rel: any;
        source: any;
        (rel, source) = (e.get("relation"), e.get("source"));
        if rel == "method" {
            mnode: any = node_by_id.get(e.get("target"));
            if mnode is not None and declared_in(mnode, _GO_SUFFIXES) and method_label(mnode) {
                method_names.setdefault(source, set[any]()).add(method_label(mnode));
            }
        } elif source in interfaces and rel == "embeds" {
            embeds.setdefault(source, set[any]()).add(e.get("target"));
        } elif source in interfaces
            and rel == "references"
            and e.get("context") == "type_constraint"
        {
            type_set_constrained.add(source);
        }
    }

    visiting_default_: any = frozenset();

    def required(iface: str, visiting: frozenset[str] = visiting_default_) -> set[str] | None {
        names: any = `set(method_names.get(iface, ()));
        for embedded in embeds.get(iface, ()) {
            if embedded not in interfaces or embedded in visiting {
                return None;
            }
            inner: any = required(embedded, visiting | {iface});
            if inner is None {
                return None;
            }
            names |= inner;
        }
        return names;
    }

    candidates: any = {
        owner: names
        for (owner, names) in method_names.items()
        if owner not in interfaces and declared_in(node_by_id.get(owner), _GO_SUFFIXES)
    };
    inferred: list[dict] = [];
    iface_node: any;
    for item_ in interfaces.items() {
        (iface, iface_node) = item_;
        if iface in type_set_constrained or not method_names.get(iface) {
            continue;
        }
        needed: any = required(iface);
        if not needed {
            continue;
        }
        package: any = PurePath(`str(iface_node.get("source_file"))).parent;
        same_package_only: any = `any(not name[:1].isupper() for name in needed);
        impls: any = [
            owner
            for (owner, names) in candidates.items()
            if needed <= names
                and (
                    not same_package_only
                    or PurePath(`str(node_by_id[owner].get("source_file"))).parent == package
                )
        ];
        if 0 < len(impls) <= _MAX_IMPLICIT_IMPLEMENTERS {
            inferred.extend(
                {"source": `impl, "target": iface, "relation": "implements"} for `impl in impls
            );
        }
    }
    if not inferred {
        return;
    }
    edges: any = all_edges + inferred;
    resolve_interface_dispatch(per_file, all_nodes, edges, suffixes=_GO_SUFFIXES);
    all_edges.extend(edges[len(all_edges) + len(inferred):]);
}
