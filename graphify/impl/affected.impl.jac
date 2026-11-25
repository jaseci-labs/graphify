impl _node_label(`graph: nx.Graph, node_id: str) -> str {
    data: any = `graph.nodes[node_id];
    return `str(data.get("label") or node_id);
}

impl _format_location(data: dict) -> str {
    source_file: any = data.get("source_file") or "-";
    source_location: any = data.get("source_location");
    if source_location {
        return f"{source_file}:{source_location}";
    }
    return `str(source_file);
}

impl _bare_name(label: str) -> str {
    label = _normalize_label(label);
    return label[:-2] if label.endswith("()") else label;
}

impl _normalize_label(label: str) -> str {
    return unicodedata.normalize("NFC", label).casefold();
}

impl _as_repo_relative(query: str, `root: Path | None = None) -> str {
    path: any = Path(query);
    if path.is_absolute() {
        anchor: any = `root if `root is not None else Path.cwd();
        try {
            return path.relative_to(anchor).as_posix();
        } except ValueError {
            return query;
        }
    }
    return path.as_posix();
}

impl _prefer_file_node(`graph: nx.Graph, node_ids: list[str], query: str) -> str | None {
    query_basename: any = _normalize_label(Path(query).name);
    exact_file_nodes: any = [
        node_id
        for node_id in node_ids
        if `str(`graph.nodes[node_id].get("source_location", "")) == "L1"
            and _normalize_label(`str(`graph.nodes[node_id].get("label", ""))) == query_basename
    ];
    if len(exact_file_nodes) == 1 {
        return exact_file_nodes[0];
    }
    _is_file_node_label: any = importlib.import_module("graphify.build")._is_file_node_label;

    path_file_nodes: any = [
        node_id
        for node_id in node_ids
        if `str(`graph.nodes[node_id].get("source_location", "")) == "L1"
            and _is_file_node_label(
                `str(`graph.nodes[node_id].get("label", "")),
                `str(`graph.nodes[node_id].get("source_file", "")),
            )
    ];
    if len(path_file_nodes) == 1 {
        return path_file_nodes[0];
    }

    l1_nodes: any = [
        node_id
        for node_id in node_ids
        if `str(`graph.nodes[node_id].get("source_location", "")) == "L1"
    ];
    if len(l1_nodes) == 1 {
        return l1_nodes[0];
    }

    basename_nodes: any = [
        node_id
        for node_id in node_ids
        if _normalize_label(`str(`graph.nodes[node_id].get("label", ""))) == query_basename
    ];
    if len(basename_nodes) == 1 {
        return basename_nodes[0];
    }

    return None;
}

impl resolve_reference_forms(`graph: nx.Graph, query: str) -> str | None {
    _find_node_tiers: any = importlib.import_module("graphify.serve")._find_node_tiers;

    source_exact: any;
    exact: any;
    _prefix: any;
    _substring: any;
    (source_exact, exact, _prefix, _substring) = _find_node_tiers(`graph, query) as any;
    for tier in (source_exact, exact) {
        if len(tier) == 1 {
            return `str(tier[0]);
        }
        if tier {
            break;
        }
    }
    return None;
}

impl resolve_seed(`graph: nx.Graph, query: str, `root: Path | None = None) -> str | None {
    query = query.rstrip("/\\") or query;
    if query in `graph {
        return query;
    }
    qualified: any = resolve_reference_forms(`graph, query);
    if qualified is not None {
        return qualified;
    }
    query_lower: any = _normalize_label(query);
    exact_label_matches: any = [
        `str(node_id)
        for (node_id, data) in `graph.nodes(data=True)
        if _normalize_label(`str(data.get("label", ""))) == query_lower
    ];
    if len(exact_label_matches) == 1 {
        return exact_label_matches[0];
    }
    query_bare: any = _bare_name(query_lower);
    bare_name_matches: any = [
        `str(node_id)
        for (node_id, data) in `graph.nodes(data=True)
        if _bare_name(`str(data.get("label", ""))) == query_bare
    ];
    if len(bare_name_matches) == 1 {
        return bare_name_matches[0];
    }
    query_path: any = _normalize_label(_as_repo_relative(query, `root));
    exact_source_matches: any = [
        `str(node_id)
        for (node_id, data) in `graph.nodes(data=True)
        if _normalize_label(`str(data.get("source_file", ""))) in (query_lower, query_path)
    ];
    if len(exact_source_matches) == 1 {
        return exact_source_matches[0];
    }
    if exact_source_matches {
        preferred_file_node: any = _prefer_file_node(
            `graph, exact_source_matches, _as_repo_relative(query, `root)
        );
        if preferred_file_node is not None {
            return preferred_file_node;
        }
    }
    contains_matches: any = [
        `str(node_id)
        for (node_id, data) in `graph.nodes(data=True)
        if query_lower in _normalize_label(`str(data.get("label", "")))
    ];
    if len(contains_matches) == 1 {
        return contains_matches[0];
    }
    return None;
}

impl _supertypes(`graph: nx.DiGraph, type_id: str, cache: dict[str, list[str]]) -> list[str] {
    if type_id in cache {
        return cache[type_id];
    }
    found: list[str] = [];
    seen: any = {type_id};
    frontier: any = [type_id];
    while frontier {
        nxt: any = [];
        for t in frontier {
            base: any;
            for (_s, base, data) in `graph.out_edges(t, data=True) {
                base = `str(base);
                if `str(data.get("relation", "")) in _SUPERTYPE_RELATIONS and base not in seen {
                    seen.add(base);
                    found.append(base);
                    nxt.append(base);
                }
            }
        }
        frontier = nxt;
    }
    cache[type_id] = found;
    return found;
}

impl _overridden_members(`graph: nx.DiGraph, `node: str, cache: dict[str, list[str]]) -> list[str] {
    owners: any = [
        `str(s)
        for (s, _t, d) in `graph.in_edges(`node, data=True)
        if `str(d.get("relation", "")) == "method"
    ];
    if not owners {
        return [];
    }
    label: any = `graph.nodes[`node].get("label");
    found: list[str] = [];
    for owner in owners {
        for base in _supertypes(`graph, owner, cache) {
            same_name: any = [
                `str(member)
                for (_s, member, data) in `graph.out_edges(base, data=True)
                if `str(data.get("relation", "")) == "method"
                    and `str(member) != `node
                    and `graph.nodes[member].get("label") == label
            ];
            found.extend(_overload_compatible(`graph, `node, same_name));
        }
    }
    return found;
}

impl _java_params(signature: object) -> list[str] | None {
    if not isinstance(signature, `str) {
        return None;
    }
    return [p.replace("...", "[]") for p in signature.split(",")] if signature else [];
}

impl _may_be_same_param(mine: str, theirs: str) -> bool {
    if mine == theirs {
        return True;
    }
    if mine in _JAVA_PRIMITIVES or theirs in _JAVA_PRIMITIVES {
        return False;
    }
    if mine.endswith("[]") and theirs.endswith("[]") {
        a: any;
        b: any;
        (a, b) = (mine[:-2], theirs[:-2]);
        if a in _JAVA_PRIMITIVES or b in _JAVA_PRIMITIVES {
            return operator.eq(a, b);
        }
    }
    return True;
}

impl _overload_compatible(`graph: nx.DiGraph, `node: str, members: list[str]) -> list[str] {
    meta: any = `graph.nodes[`node].get("metadata") or {};
    arity: any = meta.get("arity");
    if not isinstance(arity, `int) {
        return members;
    }
    is_java: any = `str(`graph.nodes[`node].get("source_file") or "").endswith(".java");
    mine: any = _java_params(meta.get("signature")) if is_java else None;
    compatible: any = [];
    for m in members {
        other: any = `graph.nodes[m].get("metadata") or {};
        other_arity: any = other.get("arity");
        if other_arity is None {
            compatible.append(m);
            continue;
        }
        if other_arity != arity {
            continue;
        }
        theirs: any = _java_params(other.get("signature")) if is_java else None;
        if mine is not None
            and theirs is not None
            and len(mine) == len(theirs)
            and not all(_may_be_same_param(a, b) for (a, b) in zip(mine, theirs))
        {
            continue;
        }
        compatible.append(m);
    }
    return compatible;
}

impl affected_nodes(
    `graph: nx.Graph, seed: str, *, relations: Iterable[str] = relations_default_, depth: int = 2
) -> list[AffectedHit] {
    relation_set: any = `set(relations);
    seen: any = {seed};
    queue: deque[tuple[str, int]] = deque([(seed, 0)]);
    hits: list[AffectedHit] = [];
    member_queue: any = deque([seed]);
    while member_queue {
        parent: any = member_queue.popleft();
        if hasattr(`graph, "out_edges") {
            member_edges: any = `graph.out_edges(parent, data=True);
        } else {
            member_edges = [];
            _: any;
            neighbor: any;
            data: any;
            for (_, neighbor, data) in `graph.edges(parent, data=True) {
                if "_src" in data and "_tgt" in data {
                    if data["_src"] == parent {
                        member_edges.append((parent, data["_tgt"], data));
                    }
                } else {
                    member_edges.append((parent, neighbor, data));
                }
            }
        }
        member: any;
        for (_s, member, data) in member_edges {
            if `str(data.get("relation", "")) not in ("method", "contains") {
                continue;
            }
            member = `str(member);
            if member not in seen {
                seen.add(member);
                queue.append((member, 0));
                member_queue.append(member);
            }
        }
    }

    supertype_cache: dict[str, list[str]] = {};
    stepping_stones: set[str] = set[any]();
    while queue {
        current: any;
        current_depth: any;
        (current, current_depth) = queue.popleft() as any;
        if current_depth >= depth {
            continue;
        }
        if isinstance(`graph, nx.DiGraph) {
            for overridden in _overridden_members(`graph, current, supertype_cache) {
                if overridden not in seen {
                    seen.add(overridden);
                    stepping_stones.add(overridden);
                    queue.appendleft((overridden, current_depth));
                }
            }
        }
        if hasattr(`graph, "in_edges") {
            incoming: any = `graph.in_edges(current, data=True);
        } else {
            incoming = [];
            for (_, neighbor, data) in `graph.edges(current, data=True) {
                if "_src" in data and "_tgt" in data {
                    if data["_tgt"] == current {
                        incoming.append((data["_src"], current, data));
                    }
                } else {
                    incoming.append((neighbor, current, data));
                }
            }
        }
        source: any;
        for (source, _target, data) in incoming {
            relation: any = `str(data.get("relation", ""));
            if relation not in relation_set {
                continue;
            }
            source = `str(source);
            queued: any = source in stepping_stones;
            if queued {
                stepping_stones.discard(source);
            } elif source in seen {
                continue;
            }
            seen.add(source);
            hit: any = AffectedHit(
                source,
                current_depth + 1,
                relation,
                via_file=`str(data.get("source_file") or "") or None,
                via_location=`str(data.get("source_location") or "") or None,
            );
            hits.append(hit);
            if not queued {
                queue.append((source, current_depth + 1));
            }
        }
    }

    return hits;
}

impl resolve_seed_outcome(`graph: nx.Graph, query: str, `root: Path | None = None) -> tuple[str
    | None, list[str]] {
    seed: any = resolve_seed(`graph, query, `root);
    if seed is not None {
        return (seed, []);
    }
    find_node_ambiguity: any = importlib.import_module("graphify.serve").find_node_ambiguity;

    normalized: any = query.rstrip("/\\") or query;
    rivals: any = find_node_ambiguity(`graph, normalized);
    return (None, [`str(node_id) for node_id in rivals]);
}

impl format_affected(
    `graph: nx.Graph,
    query: str,
    *,
    relations: Iterable[str] = relations_default__,
    depth: int = 2,
    `root: Path | None = None,
    seed: str | None = None,
) -> str {
    relation_list: any = `tuple(relations);
    if seed is None {
        seed = resolve_seed(`graph, query, `root);
    }
    if seed is None {
        return f"No unique node match for {query}";
    }

    hits: any = affected_nodes(`graph, seed, relations=relation_list, depth=depth);
    lines: any = [
        f"Affected nodes for {_node_label(`graph, seed)}",
        "Relations: " + format(", ".join(relation_list), ""),
        f"Depth: {depth}",
    ];
    if not hits {
        lines.append("No affected nodes found.");
        return "\n".join(lines);
    }

    for hit in hits {
        data: any = `graph.nodes[hit.node_id];
        if hit.via_location {
            location: any = format(hit.via_file or data.get("source_file") or "-", "")
                + ":"
                + format(hit.via_location, "");
        } else {
            location = _format_location(data);
        }
        lines.append(f"- {_node_label(`graph, hit.node_id)} [{hit.via_relation}] {location}");
    }
    return "\n".join(lines);
}

impl load_graph(path: Path) -> nx.Graph {
    import from networkx.readwrite { json_graph }

    try {
        consumed: any = importlib.import_module("graphify.paths").consumed;
        read_graph_json: any = importlib.import_module("graphify.paths").read_graph_json;
        raw: any = read_graph_json(path);
    } except (JSONDecodeError, OSError) as exc {
        raise RuntimeError(
            f"Cannot read graph file {path}: {exc}. Re-run 'graphify extract' to regenerate it."
        ) from exc;
    }
    raw = {**raw, "directed": True};
    if "links" not in raw and "edges" in raw {
        raw = `dict(raw, links=raw["edges"]);
    }
    raw = `dict(raw, nodes=consumed(raw["nodes"]), links=consumed(raw["links"]));
    return json_graph.node_link_graph(raw, edges="links");
}
