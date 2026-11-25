impl _distinct_node_labels(G: nx.Graph) -> list[str] {
    labels: any = set[any]();
    for (_, data) in G.nodes(data=True) {
        label: any = data.get("file_type", "Entity").capitalize();
        labels.add(re.sub("[^A-Za-z0-9_]", "", label) or "Entity");
    }
    return sorted(labels);
}

impl push_to_neo4j(
    G: nx.Graph, uri: str, user: str, password: str, communities: dict[int, list[str]] | None = None
) -> dict[str, int] {
    v: any;
    try {
        import from neo4j { GraphDatabase }
    } except ImportError as e {
        raise ImportError("neo4j driver not installed. Run: pip install neo4j") from e;
    }

    node_community: any = _node_community_map(communities) if communities else {};

    def _safe_rel(relation: str) -> str {
        return re.sub("[^A-Z0-9_]", "_", relation.upper().replace(" ", "_").replace("-", "_"))
            or "RELATED_TO";
    }
    def _safe_label(label: str) -> str {
        sanitized: any = re.sub("[^A-Za-z0-9_]", "", label);
        return sanitized or "Entity";
    }

    driver: any = GraphDatabase.driver(uri, auth=(user, password));
    nodes_pushed: any = 0;
    edges_pushed: any = 0;

    session: any;
    with driver.session() as session {
        for label in _distinct_node_labels(G) {
            try {
                session.run(f"CREATE INDEX IF NOT EXISTS FOR (n:{label}) ON (n.id)");
            } except Exception {}
        }

        data: any;
        for (node_id, data) in G.nodes(data=True) {
            props: any = {
                k: v
                for (k, v) in data.items()
                if isinstance(v, (`str, `int, `float, `bool)) and not k.startswith("_")
            };
            props["id"] = node_id;
            cid: any = node_community.get(node_id);
            if cid is not None {
                props["community"] = cid;
            }
            ftype: any = _safe_label(data.get("file_type", "Entity").capitalize());
            session.run(f"MERGE (n:{ftype} {{id: $id}}) SET n += $props", id=node_id, props=props);
            nodes_pushed += 1;
        }

        for (u, v, data) in G.edges(data=True) {
            rel: any = _safe_rel(data.get("relation", "RELATED_TO"));
            props = {
                k: v
                for (k, v) in data.items()
                if isinstance(v, (`str, `int, `float, `bool)) and not k.startswith("_")
            };
            session.run(
                f"MATCH (a {{id: $src}}), (b {{id: $tgt}}) MERGE (a)-[r:{rel}]->(b) SET r += $props",
                src=data.get("_src", u),
                tgt=data.get("_tgt", v),
                props=props,
            );
            edges_pushed += 1;
        }
    }

    driver.close();
    return {"nodes": nodes_pushed, "edges": edges_pushed};
}

impl push_to_falkordb(
    G: nx.Graph,
    uri: str,
    user: str | None = None,
    password: str | None = None,
    communities: dict[int, list[str]] | None = None,
    graph_name: str = "graphify",
) -> dict[str, int] {
    v: any;
    try {
        import from falkordb { FalkorDB }
    } except ImportError as e {
        raise ImportError("falkordb SDK not installed. Run: pip install falkordb") from e;
    }

    import from urllib.parse { urlparse }

    node_community: any = _node_community_map(communities) if communities else {};

    def _safe_rel(relation: str) -> str {
        return re.sub("[^A-Z0-9_]", "_", relation.upper().replace(" ", "_").replace("-", "_"))
            or "RELATED_TO";
    }
    def _safe_label(label: str) -> str {
        sanitized: any = re.sub("[^A-Za-z0-9_]", "", label);
        return sanitized or "Entity";
    }

    parsed: any = urlparse(uri if "://" in uri else f"redis://{uri}");
    connect_user: any = parsed.username or (user if password else None);
    connect_password: any = parsed.password or (password or None);
    db: any = FalkorDB(
        host=parsed.hostname or "localhost",
        port=parsed.port or 6379,
        username=connect_user,
        password=connect_password,
    );
    `graph: any = db.select_graph(graph_name);
    nodes_pushed: any = 0;
    edges_pushed: any = 0;
    for label in _distinct_node_labels(G) {
        try {
            `graph.query(f"CREATE INDEX FOR (n:{label}) ON (n.id)");
        } except Exception {}
    }

    data: any;
    for (node_id, data) in G.nodes(data=True) {
        props: any = {
            k: v
            for (k, v) in data.items()
            if isinstance(v, (`str, `int, `float, `bool)) and not k.startswith("_")
        };
        props["id"] = node_id;
        cid: any = node_community.get(node_id);
        if cid is not None {
            props["community"] = cid;
        }
        ftype: any = _safe_label(data.get("file_type", "Entity").capitalize());
        `graph.query(
            f"MERGE (n:{ftype} {{id: $id}}) SET n += $props", {"id": node_id, "props": props}
        );
        nodes_pushed += 1;
    }

    for (u, v, data) in G.edges(data=True) {
        rel: any = _safe_rel(data.get("relation", "RELATED_TO"));
        props = {
            k: v
            for (k, v) in data.items()
            if isinstance(v, (`str, `int, `float, `bool)) and not k.startswith("_")
        };
        `graph.query(
            f"MATCH (a {{id: $src}}), (b {{id: $tgt}}) MERGE (a)-[r:{rel}]->(b) SET r += $props",
            {"src": data.get("_src", u), "tgt": data.get("_tgt", v), "props": props},
        );
        edges_pushed += 1;
    }

    return {"nodes": nodes_pushed, "edges": edges_pushed};
}
