impl _cross_language(src_a: str, src_b: str) -> bool {
    ext_a: any = Path(src_a).suffix.lower();
    ext_b: any = Path(src_b).suffix.lower();
    fam_a: any = _LANG_FAMILY.get(ext_a);
    fam_b: any = _LANG_FAMILY.get(ext_b);
    if fam_a is None or fam_b is None {
        return False;
    }
    return operator.ne(fam_a, fam_b);
}

impl _node_community_map(communities: dict[int, list[str]]) -> dict[str, int] {
    return {n: cid for (cid, nodes) in communities.items() for n in nodes};
}

impl _is_file_node(G: nx.Graph, node_id: str) -> bool {
    attrs: any = G.nodes[node_id];
    label: any = attrs.get("label", "");
    if not label {
        return False;
    }
    source_file: any = attrs.get("source_file", "");
    if source_file {
        _is_file_node_label: any = importlib.import_module("graphify.build")._is_file_node_label;
        if _is_file_node_label(label, source_file) {
            return True;
        }
    }
    if label.startswith(".") and label.endswith("()") {
        return True;
    }
    bare_csharp_method_label: any = importlib.import_module(
        "graphify.extractors.csharp"
    ).bare_csharp_method_label;
    if bare_csharp_method_label(label, source_file) is not None {
        return True;
    }
    if label.endswith("()") and G.degree(node_id) <= 1 {
        return True;
    }
    return False;
}

impl _is_json_key_node(G: nx.Graph, node_id: str) -> bool {
    attrs: any = G.nodes[node_id];
    src: any = (attrs.get("source_file") or "").lower();
    if not src.endswith(".json") {
        return False;
    }
    label: any = (attrs.get("label") or "").strip().lower();
    return label in _JSON_NOISE_LABELS;
}

impl god_nodes(
    G: nx.Graph, top_n: int = 10, exclude_hubs_percentile: float | None = None
) -> list[dict] {
    degree: any = `dict(G.degree());
    hub_threshold: float | None = None;
    if exclude_hubs_percentile is not None {
        degrees: any = sorted(degree.values());
        if degrees {
            idx: any = max(0, `int(len(degrees) * exclude_hubs_percentile / 100) - 1);
            hub_threshold = degrees[idx];
        }
    }
    sorted_nodes: any = sorted(degree.items(), key=lambda (x) -> any { x[1] }, reverse=True);
    result: any = [];
    for (node_id, deg) in sorted_nodes {
        if hub_threshold is not None and deg > hub_threshold {
            continue;
        }
        if _is_file_node(G, node_id)
            or _is_concept_node(G, node_id)
            or _is_json_key_node(G, node_id)
        {
            continue;
        }
        if G.nodes[node_id].get("label", "") in _BUILTIN_NOISE_LABELS {
            continue;
        }
        result.append({
            "id": node_id,
            "label": G.nodes[node_id].get("label", node_id),
            "degree": deg,
        });
        if len(result) >= top_n {
            break;
        }
    }
    return result;
}

impl surprising_connections(
    G: nx.Graph, communities: dict[int, list[str]] | None = None, top_n: int = 5
) -> list[dict] {
    source_files: any = {
        data.get("source_file", "")
        for (_, data) in G.nodes(data=True)
        if data.get("source_file", "")
    };
    is_multi_source: any = operator.gt(len(source_files), 1);

    if is_multi_source {
        return _cross_file_surprises(G, communities or {}, top_n);
    }
    return _cross_community_surprises(G, communities or {}, top_n);
}

impl _is_concept_node(G: nx.Graph, node_id: str) -> bool {
    data: any = G.nodes[node_id];
    source: any = data.get("source_file", "");
    if not source {
        return True;
    }
    if "." not in source.split("/")[-1] {
        return True;
    }
    return False;
}

impl _is_contains_only_ast_node(G: nx.Graph, node_id: str) -> bool {
    _is_ast_tier: any = importlib.import_module("graphify.build")._is_ast_tier;
    attrs: any = G.nodes[node_id];
    if not _is_ast_tier(attrs) {
        return False;
    }
    if G.degree(node_id) != 1 {
        return False;
    }
    edges: any = `list(G.edges(node_id, data=True));
    return operator.eq(len(edges), 1) and operator.eq(edges[0][2].get("relation"), "contains");
}

impl _file_category(path: str) -> str {
    ext: any = "." + path.rsplit(".", 1)[-1].lower() if "." in path else "";
    if ext in CODE_EXTENSIONS {
        return "code";
    }
    if ext in PAPER_EXTENSIONS {
        return "paper";
    }
    if ext in IMAGE_EXTENSIONS {
        return "image";
    }
    return "doc";
}

impl _top_level_dir(path: str) -> str {
    path = path.replace("\\", "/");
    while path.startswith("./") {
        path = path[2:];
    }
    return path.split("/")[0] if "/" in path else ".";
}

impl _surprise_score(
    G: nx.Graph,
    u: str,
    v: str,
    data: dict,
    node_community: dict[str, int],
    u_source: str,
    v_source: str,
    degrees: dict[str, int] | None = None,
) -> tuple[int, list[str]] {
    score: any = 0;
    reasons: list[str] = [];
    conf: any = data.get("confidence", "EXTRACTED");
    relation: any = data.get("relation", "");
    conf_bonus: any = {"AMBIGUOUS": 3, "INFERRED": 2, "EXTRACTED": 1}.get(conf, 1);

    cat_u: any = _file_category(u_source);
    cat_v: any = _file_category(v_source);
    _suppress_structural: any = operator.eq(conf, "INFERRED")
        and relation in ("calls", "uses")
        and (_cross_language(u_source, v_source) or operator.eq({cat_u, cat_v}, {"code", "doc"}));
    if _suppress_structural {
        conf_bonus = 0;
    }

    score += conf_bonus;
    if conf in ("AMBIGUOUS", "INFERRED") {
        reasons.append(f"{conf.lower()} connection - not explicitly stated in source");
    }
    if cat_u != cat_v and not _suppress_structural {
        score += 2;
        reasons.append(f"crosses file types ({cat_u} ↔ {cat_v})");
    }
    top_u: any = (G.nodes[u].get("repo"), _top_level_dir(u_source));
    top_v: any = (G.nodes[v].get("repo"), _top_level_dir(v_source));
    if top_u != top_v and not _suppress_structural {
        score += 2;
        reasons.append("connects across different repos/directories");
    }
    cid_u: any = node_community.get(u);
    cid_v: any = node_community.get(v);
    if cid_u is not None and cid_v is not None and cid_u != cid_v and not _suppress_structural {
        score += 1;
        reasons.append("bridges separate communities");
    }
    if data.get("relation") == "semantically_similar_to" {
        score = `int(score * 1.5);
        reasons.append("semantically similar concepts with no structural link");
    }
    deg_u: any = degrees[u] if degrees is not None else G.degree(u);
    deg_v: any = degrees[v] if degrees is not None else G.degree(v);
    if min(deg_u, deg_v) <= 2 and max(deg_u, deg_v) >= 5 {
        score += 1;
        peripheral: any = G.nodes[u].get("label", u) if deg_u <= 2 else G.nodes[v].get("label", v);
        hub: any = G.nodes[v].get("label", v) if deg_u <= 2 else G.nodes[u].get("label", u);
        reasons.append(f"peripheral node `{peripheral}` unexpectedly reaches hub `{hub}`");
    }

    return (score, reasons);
}

impl _cross_file_surprises(
    G: nx.Graph, communities: dict[int, list[str]], top_n: int
) -> list[dict] {
    node_community: any = _node_community_map(communities);
    degrees: any = `dict(G.degree());
    candidates: any = [];

    for (u, v, data) in G.edges(data=True) {
        relation: any = data.get("relation", "");
        if relation in ("imports", "imports_from", "contains", "method") {
            continue;
        }
        if _is_concept_node(G, u) or _is_concept_node(G, v) {
            continue;
        }
        if _is_file_node(G, u) or _is_file_node(G, v) {
            continue;
        }

        u_source: any = G.nodes[u].get("source_file", "");
        v_source: any = G.nodes[v].get("source_file", "");

        if not u_source or not v_source or u_source == v_source {
            continue;
        }

        score: any;
        reasons: any;
        (score, reasons) = _surprise_score(
            G, u, v, data, node_community, u_source, v_source, degrees
        ) as any;
        src_id: any = data.get("_src", u);
        if src_id not in G.nodes {
            src_id = u;
        }
        tgt_id: any = data.get("_tgt", v);
        if tgt_id not in G.nodes {
            tgt_id = v;
        }
        candidates.append({
            "_score": score,
            "source": G.nodes[src_id].get("label", src_id),
            "target": G.nodes[tgt_id].get("label", tgt_id),
            "source_files": [
                G.nodes[src_id].get("source_file", ""),
                G.nodes[tgt_id].get("source_file", ""),
            ],
            "confidence": data.get("confidence", "EXTRACTED"),
            "relation": relation,
            "why": "; ".join(reasons) if reasons else "cross-file semantic connection",
        });
    }

    candidates.sort(key=lambda (x) -> any { x["_score"] }, reverse=True);
    for c in candidates {
        c.pop("_score");
    }

    if candidates {
        return candidates[:top_n];
    }

    return _cross_community_surprises(G, communities, top_n);
}

impl _cross_community_surprises(
    G: nx.Graph, communities: dict[int, list[str]], top_n: int
) -> list[dict] {
    order: any;
    if not communities {
        if G.number_of_edges() == 0 {
            return [];
        }
        if G.number_of_nodes() > 5000 {
            return [];
        }
        betweenness: any = nx.edge_betweenness_centrality(G);
        top_edges: any = sorted(
            betweenness.items(), key=lambda (x) -> any { x[1] }, reverse=True
        )[:top_n];
        result: any = [];
        u: any;
        v: any;
        for ((u, v), score) in top_edges {
            data: any;
            for data in edge_datas(G, u, v) {
                result.append({
                    "source": G.nodes[u].get("label", u),
                    "target": G.nodes[v].get("label", v),
                    "source_files": [
                        G.nodes[u].get("source_file", ""),
                        G.nodes[v].get("source_file", ""),
                    ],
                    "confidence": data.get("confidence", "EXTRACTED"),
                    "relation": data.get("relation", ""),
                    "note": f"Bridges graph structure (betweenness={score:.3f})",
                });
                if len(result) >= top_n {
                    break;
                }
            }
            if len(result) >= top_n {
                break;
            }
        }
        return result;
    }
    node_community: any = _node_community_map(communities);

    surprises: any = [];
    for (u, v, data) in G.edges(data=True) {
        cid_u: any = node_community.get(u);
        cid_v: any = node_community.get(v);
        if cid_u is None or cid_v is None or cid_u == cid_v {
            continue;
        }
        if _is_file_node(G, u) or _is_file_node(G, v) {
            continue;
        }
        relation: any = data.get("relation", "");
        if relation in ("imports", "imports_from", "contains", "method") {
            continue;
        }
        confidence: any = data.get("confidence", "EXTRACTED");
        src_id: any = data.get("_src", u);
        if src_id not in G.nodes {
            src_id = u;
        }
        tgt_id: any = data.get("_tgt", v);
        if tgt_id not in G.nodes {
            tgt_id = v;
        }
        surprises.append({
            "source": G.nodes[src_id].get("label", src_id),
            "target": G.nodes[tgt_id].get("label", tgt_id),
            "source_files": [
                G.nodes[src_id].get("source_file", ""),
                G.nodes[tgt_id].get("source_file", ""),
            ],
            "confidence": confidence,
            "relation": relation,
            "note": f"Bridges community {cid_u} → community {cid_v}",
            "_pair": `tuple(sorted([cid_u, cid_v])),
        });
    }
    order = {"AMBIGUOUS": 0, "INFERRED": 1, "EXTRACTED": 2};
    surprises.sort(key=lambda (x) -> any { order.get(x["confidence"], 3) });
    seen_pairs: set[tuple] = set[any]();
    deduped: any = [];
    for s in surprises {
        pair: any = s.pop("_pair");
        if pair not in seen_pairs {
            seen_pairs.add(pair);
            deduped.append(s);
        }
    }
    return deduped[:top_n];
}

impl _betweenness_centrality(G: nx.Graph, k: int | None, seed: int) -> dict[str, float] {
    i: any;
    v: any;
    w: any;
    if not _NETWORKX_RESCALES_SAMPLES_BY_SOURCE {
        return nx.betweenness_centrality(G, k=k, seed=seed);
    }
    if k is not None and k <= 1 {
        return nx.betweenness_centrality(G, k=k, seed=seed);
    }
    nodes: any = `list(G);
    n: any = len(nodes);
    if k == n {
        k = None;
    }
    index: any = {`node: i for (i, `node) in enumerate(nodes)};
    neighbors: any = [[index[w] for w in G[v]] for v in nodes];
    sources: any = range(n)
        if k is None
        else [index[v] for v in random.Random(seed).sample(nodes, k)];
    scores: any = [0.0] * n;
    dist: any = [-1] * n;
    sigma: any = [0.0] * n;
    delta: any = [0.0] * n;
    preds: list[list[int]] = [[] for _ in range(n)];
    for s in sources {
        dist[s] = 0;
        sigma[s] = 1.0;
        order: any = [s];
        i = 0;
        while i < len(order) {
            v = order[i];
            i += 1;
            next_dist: any = dist[v] + 1;
            sigma_v: any = sigma[v];
            for w in neighbors[v] {
                if dist[w] < 0 {
                    dist[w] = next_dist;
                    order.append(w);
                } elif dist[w] != next_dist {
                    continue;
                }
                sigma[w] += sigma_v;
                preds[w].append(v);
            }
        }
        for w in reversed(order) {
            coeff: any = (1 + delta[w]) / sigma[w];
            for v in preds[w] {
                delta[v] += sigma[v] * coeff;
            }
            if w != s {
                scores[w] += delta[w];
            }
        }
        for v in order {
            dist[v] = -1;
            value_: any = 0.0;
            sigma[v] = value_;
            delta[v] = value_;
            preds[v] = [];
        }
    }
    targets: any = n - 1;
    if targets >= 2 {
        if k is None {
            scale: any = 1 / (targets * (targets - 1));
            scores = [score * scale for score in scores];
        } else {
            source_scale: any = 1 / ((k - 1) * (targets - 1)) if k > 1 else math.nan;
            other_scale: any = 1 / (k * (targets - 1));
            sampled: any = `set(sources);
            scores = [
                score * (source_scale if i in sampled else other_scale)
                for (i, score) in enumerate(scores)
            ];
        }
    }
    return `dict(zip(nodes, scores));
}

impl suggest_questions(
    G: nx.Graph, communities: dict[int, list[str]], community_labels: dict[int, str], top_n: int = 7
) -> list[dict] {
    v: any;
    k: any;
    d: any;
    if community_labels {
        community_labels = {
            `int(k) if isinstance(k, `str) else k: v
            for (k, v) in community_labels.items()
        };
    }

    questions: any = [];
    node_community: any = _node_community_map(communities);
    u: any;
    for (u, v, data) in G.edges(data=True) {
        if data.get("confidence") == "AMBIGUOUS" {
            ul: any = G.nodes[u].get("label", u);
            vl: any = G.nodes[v].get("label", v);
            relation: any = data.get("relation", "related to");
            questions.append({
                "type": "ambiguous_edge",
                "question": f"What is the exact relationship between `{ul}` and `{vl}`?",
                "why": f"Edge tagged AMBIGUOUS (relation: {relation}) - confidence is low.",
                "low_confidence": True,
            });
        }
    }
    if G.number_of_edges() > 0 {
        k = min(100, G.number_of_nodes()) if G.number_of_nodes() > 1000 else None;
        betweenness: any = _betweenness_centrality(G, k, seed=42);
        bridges: any = sorted(
            [
                (n, s)
                for (n, s) in betweenness.items()
                if not _is_file_node(G, n) and not _is_concept_node(G, n) and s > 0
            ],
            key=lambda (x) -> any { x[1] },
            reverse=True,
        )[:3];
        node_id: any;
        score: any;
        for (node_id, score) in bridges {
            label: any = G.nodes[node_id].get("label", node_id);
            cid: any = node_community.get(node_id);
            comm_label: any = community_labels.get(cid, f"Community {cid}")
                if cid is not None
                else "unknown";
            neighbors: any = `list(G.neighbors(node_id));
            neighbor_comms: any = {
                node_community.get(n)
                for n in neighbors
                if node_community.get(n) != cid
            };
            if neighbor_comms {
                other_labels: any = [
                    community_labels.get(c, f"Community {c}")
                    for c in neighbor_comms
                ];
                questions.append({
                    "type": "bridge_node",
                    "question": "Why does `"
                        + format(label, "")
                        + "` connect `"
                        + format(comm_label, "")
                        + "` to "
                        + format(", ".join(f"`{l}`" for l in other_labels), "")
                        + "?",
                    "why": f"High betweenness centrality ({score:.3f}) - this node is a cross-community bridge.",
                });
            }
        }
    }
    degree: any = `dict(G.degree());
    top_nodes: any = sorted(
        [(n, d) for (n, d) in degree.items() if not _is_file_node(G, n)],
        key=lambda (x) -> any { x[1] },
        reverse=True,
    )[:5];
    for (node_id, _) in top_nodes {
        inferred: any = [
            (u, v, d)
            for (u, v, d) in G.edges(node_id, data=True)
            if d.get("confidence") == "INFERRED"
        ];
        if len(inferred) >= 2 {
            label = G.nodes[node_id].get("label", node_id);
            others: any = [];
            for (u, v, d) in inferred[:2] {
                src_id: any = d.get("_src", u);
                if src_id not in G.nodes {
                    src_id = u;
                }
                tgt_id: any = d.get("_tgt", v);
                if tgt_id not in G.nodes {
                    tgt_id = v;
                }
                other_id: any = tgt_id if src_id == node_id else src_id;
                others.append(G.nodes[other_id].get("label", other_id));
            }
            questions.append({
                "type": "verify_inferred",
                "question": f"Are the {len(inferred)} inferred relationships involving `{label}` (e.g. with `{others[0]}` and `{others[1]}`) actually correct?",
                "why": f"`{label}` has {len(inferred)} INFERRED edges - model-reasoned connections that need verification.",
            });
        }
    }
    isolated: any = [
        n
        for n in G.nodes()
        if G.degree(n) <= 1
            and not _is_file_node(G, n)
            and not _is_concept_node(G, n)
            and not _is_contains_only_ast_node(G, n)
            and G.nodes[n].get("file_type") != "rationale"
    ];
    if isolated {
        has_semantic_layer: any = `any(
            G.nodes[n].get("file_type") in ("document", "paper", "image") for n in G.nodes()
        );
        reason: any = "possible documentation gaps or missing edges"
            if has_semantic_layer
            else "possible missing edges";
        labels: any = [G.nodes[n].get("label", n) for n in isolated[:3]];
        questions.append({
            "type": "isolated_nodes",
            "question": "What connects "
                + format(", ".join(f"`{l}`" for l in labels), "")
                + " to the rest of the system?",
            "why": f"{len(isolated)} weakly-connected nodes found - {reason}.",
        });
    }
    import from .cluster { cohesion_score }
    for (cid, nodes) in communities.items() {
        score = cohesion_score(G, nodes);
        if score < 0.15 and len(nodes) >= 5 {
            label = community_labels.get(cid, f"Community {cid}");
            questions.append({
                "type": "low_cohesion",
                "question": f"Should `{label}` be split into smaller, more focused modules?",
                "why": f"Cohesion score {score} - nodes in this community are weakly interconnected.",
            });
        }
    }

    if not questions {
        return [
            {
                "type": "no_signal",
                "question": None,
                "why": "Not enough signal to generate questions. This usually means the corpus has no AMBIGUOUS edges, no bridge nodes, no INFERRED relationships, and all communities are tightly cohesive. Add more files or run with --mode deep to extract richer edges.",
            },
        ];
    }

    import from itertools { zip_longest }

    by_type: dict[str, list[dict]] = {};
    for question in questions {
        by_type.setdefault(question["type"], []).append(question);
    }
    diversified: any = [
        question
        for row in zip_longest(*by_type.values())
        for question in row
        if question is not None
    ];
    return diversified[:top_n];
}

impl graph_diff(G_old: nx.Graph, G_new: nx.Graph) -> dict {
    u: any;
    v: any;
    d: any;
    old_nodes: any = `set(G_old.nodes());
    new_nodes: any = `set(G_new.nodes());

    added_node_ids: any = new_nodes - old_nodes;
    removed_node_ids: any = old_nodes - new_nodes;

    new_nodes_list: any = [
        {"id": n, "label": G_new.nodes[n].get("label", n)}
        for n in added_node_ids
    ];
    removed_nodes_list: any = [
        {"id": n, "label": G_old.nodes[n].get("label", n)}
        for n in removed_node_ids
    ];

    def edge_key(G: nx.Graph, u: str, v: str, data: dict) -> tuple {
        if G.is_directed() {
            return (u, v, data.get("relation", ""));
        }
        return (min(u, v), max(u, v), data.get("relation", ""));
    }

    def edge_dir(data: dict) -> tuple | None {
        if "_src" in data and "_tgt" in data {
            return (data["_src"], data["_tgt"]);
        }
        return None;
    }

    old_edge_dirs: any = {
        edge_key(G_old, u, v, d): edge_dir(d)
        for (u, v, d) in G_old.edges(data=True)
    };
    new_edge_dirs: any = {
        edge_key(G_new, u, v, d): edge_dir(d)
        for (u, v, d) in G_new.edges(data=True)
    };
    old_edge_keys: any = `set(old_edge_dirs);
    new_edge_keys: any = `set(new_edge_dirs);
    reversed_edge_keys: any = {
        k
        for k in old_edge_keys & new_edge_keys
        if old_edge_dirs[k] and new_edge_dirs[k] and old_edge_dirs[k] != new_edge_dirs[k]
    };
    added_edge_keys: any = new_edge_keys - old_edge_keys | reversed_edge_keys;
    removed_edge_keys: any = old_edge_keys - new_edge_keys | reversed_edge_keys;

    new_edges_list: any = [];
    for (u, v, d) in G_new.edges(data=True) {
        if edge_key(G_new, u, v, d) in added_edge_keys {
            new_edges_list.append({
                "source": d.get("_src", u),
                "target": d.get("_tgt", v),
                "relation": d.get("relation", ""),
                "confidence": d.get("confidence", ""),
            });
        }
    }

    removed_edges_list: any = [];
    for (u, v, d) in G_old.edges(data=True) {
        if edge_key(G_old, u, v, d) in removed_edge_keys {
            removed_edges_list.append({
                "source": d.get("_src", u),
                "target": d.get("_tgt", v),
                "relation": d.get("relation", ""),
                "confidence": d.get("confidence", ""),
            });
        }
    }

    parts: any = [];
    if new_nodes_list {
        parts.append(
            format(len(new_nodes_list), "")
                + " new node"
                + format("s" if len(new_nodes_list) != 1 else "", ""),
        );
    }
    if new_edges_list {
        parts.append(
            format(len(new_edges_list), "")
                + " new edge"
                + format("s" if len(new_edges_list) != 1 else "", ""),
        );
    }
    if removed_nodes_list {
        parts.append(
            format(len(removed_nodes_list), "")
                + " node"
                + format("s" if len(removed_nodes_list) != 1 else "", "")
                + " removed",
        );
    }
    if removed_edges_list {
        parts.append(
            format(len(removed_edges_list), "")
                + " edge"
                + format("s" if len(removed_edges_list) != 1 else "", "")
                + " removed",
        );
    }
    summary: any = ", ".join(parts) if parts else "no changes";

    return {
        "new_nodes": new_nodes_list,
        "removed_nodes": removed_nodes_list,
        "new_edges": new_edges_list,
        "removed_edges": removed_edges_list,
        "summary": summary,
    };
}

impl find_import_cycles(G: nx.Graph, max_cycle_length: int = 5, top_n: int = 20) -> list[dict] {
    def _endpoint_source_file(node_id: str) -> str {
        attrs: any = G.nodes.get(node_id, {});
        src_file: any = attrs.get("source_file", "");
        return src_file if isinstance(src_file, `str) else "";
    }
    file_graph: any = nx.DiGraph();

    u: any;
    v: any;
    for (u, v, data) in G.edges(data=True) {
        rel: any = data.get("relation", "");
        if rel not in ("imports_from", "re_exports") {
            continue;
        }
        forward: any = not data.get("deferred") and not data.get("type_only");
        reverse: any = `bool(data.get("reverse_import"));
        if not forward and not reverse {
            continue;
        }

        src_file_attr: any = data.get("source_file", "");
        if not isinstance(src_file_attr, `str) or not src_file_attr {
            continue;
        }

        u_file: any = _endpoint_source_file(u);
        v_file: any = _endpoint_source_file(v);
        if u_file == src_file_attr {
            tgt_file: any = v_file;
        } elif v_file == src_file_attr {
            tgt_file = u_file;
        } else {
            tgt_file = v_file if v_file and v_file != src_file_attr else u_file;
        }

        if not tgt_file {
            continue;
        }

        if forward {
            file_graph.add_edge(src_file_attr, tgt_file);
        }
        if reverse {
            file_graph.add_edge(tgt_file, src_file_attr);
        }
    }

    if not file_graph.edges() {
        return [];
    }
    cycles: list[list[str]] = [];
    if max_cycle_length >= 2 {
        for (u, v) in file_graph.edges() {
            if len(cycles) >= top_n * 10 {
                break;
            }
            if u < v and file_graph.has_edge(v, u) {
                cycles.append([u, v]);
            }
        }
    }
    cycle: any;
    for cycle in nx.simple_cycles(file_graph, length_bound=max_cycle_length) {
        if len(cycle) <= max_cycle_length {
            cycles.append(cycle);
        }
        if len(cycles) >= top_n * 10 {
            break;
        }
    }
    cycles.sort(key=builtins.len);
    seen: set[tuple[str, ...]] = set[any]();
    unique_cycles: list[list[str]] = [];
    for cycle in cycles {
        core: any = `list(cycle);
        if not core {
            continue;
        }
        min_idx: any = core.index(min(core));
        normalized: any = `tuple(core[min_idx:] + core[:min_idx]);
        if normalized not in seen {
            seen.add(normalized);
            unique_cycles.append(`list(normalized));
            if len(unique_cycles) >= top_n {
                break;
            }
        }
    }

    result: list[dict] = [];
    for cycle in unique_cycles {
        result.append({"cycle": cycle, "length": len(cycle), "why": "circular dependency"});
    }

    return result;
}
