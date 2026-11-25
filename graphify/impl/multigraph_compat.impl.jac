impl MultigraphCapabilityResult.error_message -> str {
    if self.ok {
        return f"Graphify MultiDiGraph capability probe passed (Python {self.python_version}, NetworkX {self.networkx_version}).";
    }
    failed: any = "; ".join(f"{check.name}: {check.detail}" for check in self.failed);
    return f"error: --multigraph requires NetworkX keyed MultiDiGraph node-link round-trip support. Detected Python {self.python_version}, NetworkX {self.networkx_version}. Failed capability check(s): {failed}. Default simple graph mode remains available.";
}

impl _check(name: str, func: Callable[[], bool | str]) -> CapabilityCheck {
    try {
        detail: any = func();
    } except Exception as exc {
        return CapabilityCheck(name, False, f"{`type(exc).__name__}: {exc}");
    }
    if detail is True {
        return CapabilityCheck(name, True, "ok");
    }
    if isinstance(detail, `str) {
        return CapabilityCheck(name, False, detail);
    }
    return CapabilityCheck(name, False, f"unexpected result {detail!r}");
}

impl _build_probe_graph -> nx.MultiDiGraph {
    `graph: any = nx.MultiDiGraph();
    `graph.add_node("a", label="A");
    `graph.add_node("b", label="B");
    `graph.add_edge("a", "b", key="calls:a.py:L1", relation="calls", source_file="a.py");
    `graph.add_edge("a", "b", key="imports:a.py:L2", relation="imports", source_file="a.py");
    return `graph;
}

impl _probe_keyed_parallel_edges -> bool | str {
    `graph: any = _build_probe_graph();
    if not `graph.is_multigraph() or not `graph.is_directed() {
        return f"probe graph type was {`type(`graph).__name__}";
    }
    if `graph.number_of_edges("a", "b") != 2 {
        return "expected 2 keyed parallel edges, got "
            + format(`graph.number_of_edges("a", "b"), "");
    }
    keys: any = `set(`graph["a"]["b"].keys());
    expected: any = {"calls:a.py:L1", "imports:a.py:L2"};
    if keys != expected {
        return f"expected keys {sorted(expected)}, got {sorted(keys)}";
    }
    return True;
}

impl _probe_node_link_round_trip -> bool | str {
    `graph: any = _build_probe_graph();
    data: any = json_graph.node_link_data(`graph, edges="links");
    if data.get("multigraph") is not True {
        return "serialized multigraph flag was " + format(repr(data.get("multigraph")), "");
    }
    if data.get("directed") is not True {
        return "serialized directed flag was " + format(repr(data.get("directed")), "");
    }
    links: any = data.get("links");
    if not isinstance(links, `list) or len(links) != 2 {
        length: any = 0 if not isinstance(links, `list) else len(links);
        return f"serialized links length was {length}";
    }
    serialized_keys: set[str] = set[any]();
    for `edge in links {
        if isinstance(`edge, `dict) {
            edge_key: any = `edge.get("key");
            if isinstance(edge_key, `str) {
                serialized_keys.add(edge_key);
            }
        }
    }
    expected: any = {"calls:a.py:L1", "imports:a.py:L2"};
    if serialized_keys != expected {
        return f"serialized keys {sorted(serialized_keys)} did not match {sorted(expected)}";
    }
    loaded: any = json_graph.node_link_graph(data, edges="links");
    if not isinstance(loaded, nx.MultiDiGraph) {
        return f"round-trip graph type was {`type(loaded).__name__}";
    }
    if loaded.number_of_edges("a", "b") != 2 {
        return "round-trip edge count was " + format(loaded.number_of_edges("a", "b"), "");
    }
    loaded_keys: any = `set(loaded["a"]["b"].keys());
    if loaded_keys != expected {
        return f"round-trip keys {sorted(loaded_keys)} did not match {sorted(expected)}";
    }
    return True;
}

impl _probe_duplicate_key_overwrite_semantics -> bool | str {
    `graph: any = nx.MultiDiGraph();
    `graph.add_edge("x", "y", key="same", marker="first");
    `graph.add_edge("x", "y", key="same", marker="second");
    edges: any = `list(`graph.edges(keys=True, data=True));
    if len(edges) != 1 {
        return f"expected one edge after duplicate-key add, got {len(edges)}";
    }
    if edges[0][3].get("marker") != "second" {
        return "expected second attr overwrite, got " + format(repr(edges[0][3].get("marker")), "");
    }
    return True;
}

impl _probe_reserved_key_attr_rejected -> bool | str {
    `graph: any = nx.MultiDiGraph();
    attrs: dict[str, Any] = {"key": "attr-key", "relation": "calls"};
    try {
        `graph.add_edge("a", "b", key="schema-key", **attrs);
    } except TypeError {
        return True;
    }
    return "add_edge accepted duplicate key keyword and attr; loader must not rely on this";
}

impl _probe_remove_edges_from_two_tuple_semantics -> bool | str {
    `graph: any = nx.MultiDiGraph();
    `graph.add_edge("a", "b", key="one");
    `graph.add_edge("a", "b", key="two");
    `graph.remove_edges_from([("a", "b")]);
    remaining: any = `graph.number_of_edges("a", "b");
    if remaining != 1 {
        return f"expected one remaining edge after two-tuple removal, got {remaining}";
    }
    return True;
}

impl _probe_to_undirected_preserves_multigraph_type -> bool | str {
    `graph: any = _build_probe_graph();
    undirected: any = `graph.to_undirected();
    undirected_view: any = `graph.to_undirected(as_view=True);
    if not isinstance(undirected, nx.MultiGraph) {
        return f"to_undirected() returned {`type(undirected).__name__}";
    }
    if not isinstance(undirected_view, nx.MultiGraph) {
        return f"to_undirected(as_view=True) returned {`type(undirected_view).__name__}";
    }
    return True;
}

impl probe_multigraph_capabilities -> MultigraphCapabilityResult {
    checks: any = (
        _check("keyed_parallel_edges", _probe_keyed_parallel_edges),
        _check("node_link_edges_links_round_trip", _probe_node_link_round_trip),
        _check("duplicate_key_overwrite_semantics", _probe_duplicate_key_overwrite_semantics),
        _check("reserved_key_attr_rejected", _probe_reserved_key_attr_rejected),
        _check(
            "remove_edges_from_two_tuple_semantics", _probe_remove_edges_from_two_tuple_semantics
        ),
        _check(
            "to_undirected_preserves_multigraph_type",
            _probe_to_undirected_preserves_multigraph_type,
        ),
    );
    return MultigraphCapabilityResult(
        python_version=f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
        networkx_version=nx.__version__,
        checks=checks,
    );
}

impl require_multigraph_capabilities -> MultigraphCapabilityResult {
    result: any = probe_multigraph_capabilities();
    if not result.ok {
        raise RuntimeError(result.error_message());
    }
    return result;
}
