impl _topology_hash(
    G: nx.Graph, *, resolution: float, exclude_hubs_percentile: float | None, ambiguous_scale: float
) -> str {
    acc_nodes: any = 0;
    for n in G.nodes() {
        d: any = hashlib.sha256(b"n\x00" + `str(n).encode("utf-8", "replace")).digest();
        acc_nodes ^= int.from_bytes(d, "big");
    }
    acc_edges: any = 0;
    for (u, v, attrs) in G.edges(data=True) {
        a: any;
        b: any;
        (a, b) = sorted((`str(u), `str(v))) as any;
        w: any = repr(`float(attrs.get("weight", 1.0)));
        c: any = `str(attrs.get("confidence", ""));
        payload: any = ("e\x00" + a + "\x01" + b + "\x01" + w + "\x01" + c).encode(
            "utf-8", "replace"
        );
        acc_edges ^= int.from_bytes(hashlib.sha256(payload).digest(), "big");
    }
    h: any = hashlib.sha256();
    h.update(
        repr((
            "topology-v1",
            `float(resolution),
            None if exclude_hubs_percentile is None else `float(exclude_hubs_percentile),
            `float(ambiguous_scale),
            `bool(G.is_directed()),
            G.number_of_nodes(),
            G.number_of_edges(),
        )).encode("utf-8"),
    );
    h.update(acc_nodes.to_bytes(32, "big"));
    h.update(acc_edges.to_bytes(32, "big"));
    return "v1:" + h.hexdigest();
}

impl _load_cached_partition(cache_path: "str | Path", topo_hash: str) -> dict[int, list[str]]
    | None {
    try {
        raw: any = json.loads(Path(cache_path).read_text(encoding="utf-8"));
    } except (OSError, ValueError) {
        return None;
    }
    if not isinstance(raw, `dict) or raw.get("topology_hash") != topo_hash {
        return None;
    }
    comms: any = raw.get("communities");
    if not isinstance(comms, `dict) {
        return None;
    }
    try {
        return {`int(cid): `list(nodes) for (cid, nodes) in comms.items()};
    } except (TypeError, ValueError) {
        return None;
    }
}

impl _store_cached_partition(
    cache_path: "str | Path", topo_hash: str, communities: dict[int, list[str]]
) -> None {
    import from graphify.paths { write_json_atomic }

    write_json_atomic(
        cache_path,
        {
            "version": 1,
            "topology_hash": topo_hash,
            "communities": {`str(cid): nodes for (cid, nodes) in communities.items()},
        },
        ensure_ascii=False,
    );
}

impl _suppress_output -> any {
    return contextlib.redirect_stdout(io.StringIO());
}

impl _native_leiden(stable: nx.Graph, resolution: float) -> dict[str, int] | None {
    try {
        import graspologic_native as gn;
    } except ImportError {
        return None;
    }

    if stable.is_directed() or stable.is_multigraph() {
        return None;
    }
    id_to_node: dict[str, object] = {};
    `node: any;
    for `node in stable.nodes() {
        key: any = `str(`node);
        existing: any = id_to_node.get(key);
        if existing is not None and existing != `node {
            return None;
        }
        id_to_node[key] = `node;
    }

    edges: any = [
        (`str(u), `str(v), `float(attrs.get("weight", 1.0)))
        for (u, v, attrs) in stable.edges(data=True)
    ];

    try {
        old_stderr: any = sys.stderr;
        try {
            sys.stderr = io.StringIO();
            with _suppress_output() {
                _quality: any;
                native_partitions: any;
                (_quality, native_partitions) = gn.leiden(
                    edges=edges,
                    starting_communities=None,
                    resolution=resolution,
                    randomness=0.001,
                    iterations=1,
                    use_modularity=True,
                    seed=42,
                    trials=1,
                ) as any;
            }
        } finally {
            sys.stderr = old_stderr;
        }
    } except Exception {
        return None;
    }

    partition: any = {
        id_to_node[node_id]: community
        for (node_id, community) in native_partitions.items()
    };
    next_community: any = max(partition.values(), default=-1) + 1;
    for `node in stable.nodes() {
        if `node not in partition {
            partition[`node] = next_community;
            next_community += 1;
        }
    }
    return partition;
}

impl _partition(G: nx.Graph, resolution: float = 1.0) -> dict[str, int] {
    stable: any = nx.Graph();
    stable.add_nodes_from(sorted(G.nodes(), key=str));
    edge_rows: any = sorted(
        G.edges(data=True),
        key=lambda (row) -> any {
            (*sorted((`str(row[0]), `str(row[1]))), `float(row[2].get("weight", 1.0)))
        },
    );
    for (src, tgt, attrs) in edge_rows {
        stable.add_edge(src, tgt, **attrs);
    }
    del edge_rows;

    native_result: any = _native_leiden(stable, resolution);
    if native_result is not None {
        return native_result;
    }

    try {
        import from graspologic.partition { leiden }
        lsig: any = inspect.signature(leiden).parameters;
        kwargs: dict = {};
        if "random_seed" in lsig {
            kwargs["random_seed"] = 42;
        }
        if "trials" in lsig {
            kwargs["trials"] = 1;
        }
        if "resolution" in lsig {
            kwargs["resolution"] = resolution;
        }
        old_stderr: any = sys.stderr;
        try {
            sys.stderr = io.StringIO();
            with _suppress_output() {
                result: any = leiden(stable, **kwargs);
            }
        } finally {
            sys.stderr = old_stderr;
        }
        return result;
    } except ImportError {}
    kwargs = {"seed": 42, "threshold": 0.0001, "resolution": resolution};
    if "max_level" in inspect.signature(nx.community.louvain_communities).parameters {
        kwargs["max_level"] = 10;
    }
    communities: any = nx.community.louvain_communities(stable, **kwargs);
    return {`node: cid for (cid, nodes) in enumerate(communities) for `node in nodes};
}

impl label_communities_by_hub(G: nx.Graph, communities: dict[int, list[str]]) -> dict[int, str] {
    labels: dict[int, str] = {};
    for (cid, members) in communities.items() {
        present: any = [n for n in members if n in G];
        if not present {
            labels[cid] = f"Community {cid}";
            continue;
        }
        hub: any = min(present, key=lambda (n) -> any { (-G.degree(n), `str(n)) });
        name: any = `str(G.nodes[hub].get("label") or hub).strip();
        if name.endswith("()") {
            name = name[:-2];
        }
        labels[cid] = name or f"Community {cid}";
    }
    return labels;
}

impl community_member_sigs(communities: dict[int, list[str]]) -> dict[int, str] {
    import hashlib;

    sigs: dict[int, str] = {};
    for (cid, members) in communities.items() {
        h: any = hashlib.sha256();
        for nid in sorted(`str(n) for n in members) {
            h.update(nid.encode("utf-8", "replace"));
            h.update(b"\x00");
        }
        sigs[cid] = h.hexdigest()[:16];
    }
    return sigs;
}

impl cluster(
    G: nx.Graph,
    resolution: float = 1.0,
    exclude_hubs_percentile: float | None = None,
    ambiguous_scale: float = 0.5,
    cache_dir: "str | Path | None" = None,
) -> dict[int, list[str]] {
    d: any;
    hub_nodes: set[str];
    votes: dict[int, int];
    nb: any;
    if G.number_of_nodes() == 0 {
        return {};
    }
    if G.is_directed() {
        G = G.to_undirected();
    }
    if G.number_of_edges() == 0 {
        return {i: [n] for (i, n) in enumerate(sorted(G.nodes))};
    }
    env_scale: any = os.environ.get("GRAPHIFY_AMBIGUOUS_SCALE");
    if env_scale is not None {
        try {
            ambiguous_scale = `float(env_scale);
        } except ValueError {}
    }
    _cache_path: any = None;
    _topo_hash: any = None;
    if cache_dir is not None {
        try {
            _cache_path = Path(cache_dir) / _PARTITION_CACHE_NAME;
            _topo_hash = _topology_hash(
                G,
                resolution=resolution,
                exclude_hubs_percentile=exclude_hubs_percentile,
                ambiguous_scale=ambiguous_scale,
            );
            _cached: any = _load_cached_partition(_cache_path, _topo_hash);
            if _cached is not None {
                return _cached;
            }
        } except Exception {
            _cache_path = None;
        }
    }

    if ambiguous_scale != 1.0
        and `any(operator.eq(d.get("confidence"), "AMBIGUOUS") for (_, _, d) in G.edges(data=True))
    {
        G = G.copy();
        for (u, v, d) in G.edges(data=True) {
            if d.get("confidence") == "AMBIGUOUS" {
                base: any = `float(d.get("weight", 1.0));
                d["weight"] = base * ambiguous_scale;
            }
        }
    }
    hub_nodes = set[any]();
    if exclude_hubs_percentile is not None {
        degrees: any = sorted(d for (_, d) in G.degree());
        if degrees {
            idx: any = max(0, `int(len(degrees) * exclude_hubs_percentile / 100) - 1);
            threshold: any = degrees[idx];
            hub_nodes = {n for (n, d) in G.degree() if d > threshold};
        }
    }
    excluded: any = hub_nodes;
    isolates: any = [n for n in G.nodes() if G.degree(n) == 0 and n not in excluded];
    connected_nodes: any = [n for n in G.nodes() if G.degree(n) > 0 and n not in excluded];
    stranded: list[str] = [];
    if hub_nodes {
        stranded = [
            n
            for n in connected_nodes
            if (nbs := [nb for nb in G.neighbors(n) if nb != n])
                and all(nb in hub_nodes for nb in nbs)
        ];
        if stranded {
            _stranded: any = `set(stranded);
            connected_nodes = [n for n in connected_nodes if n not in _stranded];
        }
    }
    connected: any = G.subgraph(connected_nodes);

    raw: dict[int, list[str]] = {};
    if connected.number_of_nodes() > 0 {
        partition: any = _partition(connected, resolution=resolution);
        `node: any;
        cid: any;
        for (`node, cid) in partition.items() {
            raw.setdefault(cid, []).append(`node);
        }
    }
    next_cid: any = max(raw.keys(), default=-1) + 1;
    for `node in isolates {
        raw[next_cid] = [`node];
        next_cid += 1;
    }
    if hub_nodes {
        node_community: dict[str, int] = {n: cid for (cid, nodes) in raw.items() for n in nodes};
        for hub in sorted(hub_nodes) {
            votes = {};
            for nb in G.neighbors(hub) {
                cid = node_community.get(nb);
                if cid is not None {
                    votes[cid] = votes.get(cid, 0) + 1;
                }
            }
            if votes {
                best: any = min(votes, key=lambda (c) -> any { (-votes[c], c) });
                raw.setdefault(best, []).append(hub);
                node_community[hub] = best;
            } else {
                raw[next_cid] = [hub];
                node_community[hub] = next_cid;
                next_cid += 1;
            }
        }
        for `node in sorted(stranded, key=str) {
            votes = {};
            for nb in G.neighbors(`node) {
                if nb == `node {
                    continue;
                }
                cid = node_community[nb];
                votes[cid] = votes.get(cid, 0) + 1;
            }
            best = min(votes, key=lambda (c) -> any { (-votes[c], c) });
            raw[best].append(`node);
            node_community[`node] = best;
        }
    }
    max_size: any = max(_MIN_SPLIT_SIZE, `int(G.number_of_nodes() * _MAX_COMMUNITY_FRACTION));
    final_communities: list[list[str]] = [];
    nodes: any;
    for nodes in raw.values() {
        if len(nodes) > max_size {
            final_communities.extend(_split_community(G, nodes));
        } else {
            final_communities.append(nodes);
        }
    }
    second_pass: list[list[str]] = [];
    for nodes in final_communities {
        if len(nodes) >= _COHESION_SPLIT_MIN_SIZE
            and cohesion_score(G, nodes) < _COHESION_SPLIT_THRESHOLD
        {
            splits: any = _split_community(G, nodes);
            second_pass.extend(splits if len(splits) > 1 else [nodes]);
        } else {
            second_pass.append(nodes);
        }
    }
    final_communities = second_pass;
    final_communities.sort(
        key=lambda (nodes) -> any { (-len(nodes), `tuple(sorted(map(str, nodes)))) }
    );
    result: any = {i: sorted(nodes) for (i, nodes) in enumerate(final_communities)};
    if _cache_path is not None and _topo_hash is not None {
        try {
            _store_cached_partition(_cache_path, _topo_hash, result);
        } except Exception {}
    }
    return result;
}

impl _split_community(G: nx.Graph, nodes: list[str]) -> list[list[str]] {
    subgraph: any = G.subgraph(nodes);
    if subgraph.number_of_edges() == 0 {
        return [[n] for n in sorted(nodes)];
    }
    try {
        sub_partition: any = _partition(subgraph);
        sub_communities: dict[int, list[str]] = {};
        for (`node, cid) in sub_partition.items() {
            sub_communities.setdefault(cid, []).append(`node);
        }
        if len(sub_communities) <= 1 {
            return [sorted(nodes)];
        }
        return [sorted(v) for v in sub_communities.values()];
    } except Exception {
        return [sorted(nodes)];
    }
}

impl cohesion_score(G: nx.Graph, community_nodes: list[str]) -> float {
    n: any = len(community_nodes);
    if n <= 1 {
        return 1.0;
    }
    subgraph: any = G.subgraph(community_nodes);
    actual: any = subgraph.number_of_edges() - nx.number_of_selfloops(subgraph);
    possible: any = n * (n - 1) / 2;
    return actual / possible if possible > 0 else 0.0;
}

impl score_all(G: nx.Graph, communities: dict[int, list[str]]) -> dict[int, float] {
    return {cid: cohesion_score(G, nodes) for (cid, nodes) in communities.items()};
}

impl remap_communities_to_previous(
    communities: dict[int, list[str]], previous_node_community: dict[str, int]
) -> dict[int, list[str]] {
    new_cid: any;
    old_cid: any;
    if not communities {
        return {};
    }
    overlaps: list[tuple[int, int, int]] = [];
    nodes: any;
    for item_ in communities.items() {
        (new_cid, nodes) = item_;
        counts: any = Counter(
            previous_node_community[`node]
            for `node in `set(nodes)
            if `node in previous_node_community,
        );
        overlaps.extend((count, old_cid, new_cid) for (old_cid, count) in counts.items());
    }
    overlaps.sort(key=lambda (x) -> any { (-x[0], x[1], x[2]) });

    new_to_final: dict[int, int] = {};
    used_old_ids: set[int] = set[any]();
    matched_new_ids: set[int] = set[any]();
    _overlap: any;
    for item__ in overlaps {
        (_overlap, old_cid, new_cid) = item__;
        if old_cid in used_old_ids or new_cid in matched_new_ids {
            continue;
        }
        new_to_final[new_cid] = old_cid;
        used_old_ids.add(old_cid);
        matched_new_ids.add(new_cid);
    }

    unmatched: any = [cid for cid in communities if cid not in matched_new_ids];
    unmatched.sort(
        key=lambda (cid) -> any { (-len(communities[cid]), `tuple(sorted(communities[cid]))) }
    );
    next_id: any = 0;
    for new_cid_ in unmatched {
        new_cid = new_cid_;
        while next_id in used_old_ids {
            next_id += 1;
        }
        new_to_final[new_cid] = next_id;
        used_old_ids.add(next_id);
        next_id += 1;
    }

    remapped: dict[int, list[str]] = {};
    for item___ in communities.items() {
        (new_cid, nodes) = item___;
        remapped[new_to_final[new_cid]] = sorted(nodes);
    }
    return `dict(sorted(remapped.items(), key=lambda (kv) -> any { kv[0] }));
}

impl label_still_applies(
    cid: int,
    current_members: list[str],
    previous_node_community: dict[str, int],
    saved_sig: str | None,
    current_sig: str | None,
) -> bool {
    if saved_sig is not None and current_sig is not None and saved_sig == current_sig {
        return True;
    }
    saved: any = {`str(`node) for (`node, old) in previous_node_community.items() if old == cid};
    current: any = {`str(`node) for `node in current_members};
    if not saved or not current {
        return False;
    }
    overlap: any = len(saved & current);
    return operator.gt(overlap * 2, len(saved)) and operator.gt(overlap * 2, len(current));
}
