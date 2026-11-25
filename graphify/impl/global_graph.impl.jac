impl _load_manifest -> dict {
    name: any;
    if _GLOBAL_MANIFEST.exists() {
        try {
            manifest: any = json.loads(_GLOBAL_MANIFEST.read_text(encoding="utf-8"));
            repos: any = manifest.get("repos") if isinstance(manifest, `dict) else None;
            if not isinstance(repos, `dict) {
                raise ValueError("expected a manifest object with a repos map");
            }
            bad: any = sorted(
                name for (name, info) in repos.items() if not isinstance(info, `dict)
            );
            if bad {
                for name in bad {
                    repos.pop(name);
                }
                print(
                    "[graphify global] dropped "
                        + format(len(bad), "")
                        + " malformed repo entr"
                        + format("y" if len(bad) == 1 else "ies", "")
                        + " ("
                        + format(", ".join(bad), "")
                        + ") from "
                        + format(_GLOBAL_MANIFEST, "")
                        + "; kept "
                        + format(len(repos), "")
                        + " valid repo(s).",
                    file=sys.stderr,
                );
            }
            return manifest;
        } except Exception as exc {
            backup: any = _GLOBAL_MANIFEST.with_suffix(
                _GLOBAL_MANIFEST.suffix + f".corrupt.{`int(datetime.now(timezone.utc).timestamp())}"
            );
            try {
                _GLOBAL_MANIFEST.rename(backup);
                print(
                    f"[graphify global] manifest at {_GLOBAL_MANIFEST} failed to parse ({exc}); moved to {backup} and starting fresh. Restore from the backup if this was unexpected.",
                    file=sys.stderr,
                );
            } except Exception as rename_exc {
                print(
                    f"[graphify global] manifest at {_GLOBAL_MANIFEST} failed to parse ({exc}) and could not be backed up ({rename_exc}). Starting fresh.",
                    file=sys.stderr,
                );
            }
        }
    }
    return {"version": 1, "repos": {}};
}

impl _save_manifest(manifest: dict) -> None {
    _GLOBAL_DIR.mkdir(parents=True, exist_ok=True);
    write_json_atomic: any = importlib.import_module("graphify.paths").write_json_atomic;
    write_json_atomic(_GLOBAL_MANIFEST, manifest, indent=2);
}

impl _load_global_graph -> nx.Graph {
    if _GLOBAL_GRAPH.exists() {
        check_graph_file_size_cap: any = importlib.import_module("graphify.security").check_graph_file_size_cap;
        check_graph_file_size_cap(_GLOBAL_GRAPH);
        data: any = json.loads(_GLOBAL_GRAPH.read_text(encoding="utf-8"));
        if "links" not in data and "edges" in data {
            data = `dict(data, links=data["edges"]);
        }
        try {
            return _jg.node_link_graph(data, edges="links");
        } except TypeError {
            return _jg.node_link_graph(data);
        }
    }
    return nx.Graph();
}

impl _save_global_graph(G: nx.Graph) -> None {
    _GLOBAL_DIR.mkdir(parents=True, exist_ok=True);
    try {
        data: any = _jg.node_link_data(G, edges="links");
    } except TypeError {
        data = _jg.node_link_data(G);
    }
    write_json_atomic: any = importlib.import_module("graphify.paths").write_json_atomic;
    write_json_atomic(_GLOBAL_GRAPH, data, compact=True);
}

impl _file_hash(path: Path) -> str {
    h: any = hashlib.sha256();
    h.update(path.read_bytes());
    return h.hexdigest()[:16];
}

impl global_add(source_path: Path, repo_tag: str) -> dict {
    prefix_graph_for_global: any = importlib.import_module("graphify.build").prefix_graph_for_global;
    prune_repo_from_graph: any = importlib.import_module("graphify.build").prune_repo_from_graph;

    if not source_path.exists() {
        raise FileNotFoundError(f"graph not found: {source_path}");
    }

    manifest: any = _load_manifest();
    src_hash: any = _file_hash(source_path);

    existing: any = manifest["repos"].get(repo_tag, {});
    existing_path: any = existing.get("source_path", "");
    if existing_path and existing_path != `str(source_path.resolve()) {
        print(
            f"[graphify global] warning: repo tag '{repo_tag}' previously pointed to {existing_path!r}, now updating to {`str(source_path.resolve())!r}. Use --as <tag> to give it a different name.",
            file=sys.stderr,
        );
    }
    if existing.get("source_hash") == src_hash {
        return {
            "repo_tag": repo_tag,
            "nodes_added": 0,
            "nodes_removed": 0,
            "skipped": True,
            "cross_repo_calls": 0,
        };
    }
    check_graph_file_size_cap: any = importlib.import_module("graphify.security").check_graph_file_size_cap;
    check_graph_file_size_cap(source_path);
    data: any = json.loads(source_path.read_text(encoding="utf-8"));
    if "links" not in data and "edges" in data {
        data = `dict(data, links=data["edges"]);
    }
    restore_arc_direction: any = importlib.import_module("graphify.paths").restore_arc_direction;
    data = restore_arc_direction(data);
    try {
        src_G: any = _jg.node_link_graph(data, edges="links");
    } except TypeError {
        src_G = _jg.node_link_graph(data);
    }
    prefixed: any = prefix_graph_for_global(src_G, repo_tag);
    G: any = _load_global_graph();
    removed: any = prune_repo_from_graph(G, repo_tag);
    external_labels: any = {
        d.get("label", ""): n
        for (n, d) in G.nodes(data=True)
        if not d.get("source_file") and d.get("label")
    };
    remap: any = {};
    `node: any;
    for (`node, data) in prefixed.nodes(data=True) {
        if not data.get("source_file") and data.get("label") in external_labels {
            remap[`node] = external_labels[data["label"]];
        }
    }
    for (`node, data) in prefixed.nodes(data=True) {
        if `node not in remap {
            G.add_node(`node, **data);
        }
    }
    u: any;
    v: any;
    for (u, v, data) in prefixed.edges(data=True) {
        u = remap.get(u, u);
        v = remap.get(v, v);
        for key in ("_src", "_tgt") {
            if data.get(key) in remap {
                data = {**data, key: remap[data[key]]};
            }
        }
        if u != v {
            G.add_edge(u, v, **data);
        }
    }

    added: any = prefixed.number_of_nodes() - len(remap);
    link_cross_repo_member_calls: any = importlib.import_module("graphify.cross_repo_calls").link_cross_repo_member_calls;

    cross_repo_calls: any = link_cross_repo_member_calls(G);
    _save_global_graph(G);

    manifest["repos"][repo_tag] = {
        "added_at": datetime.now(timezone.utc).isoformat(),
        "source_path": `str(source_path.resolve()),
        "node_count": added,
        "edge_count": prefixed.number_of_edges(),
        "source_hash": src_hash,
    };
    _save_manifest(manifest);

    return {
        "repo_tag": repo_tag,
        "nodes_added": added,
        "nodes_removed": removed,
        "skipped": False,
        "cross_repo_calls": cross_repo_calls,
    };
}

impl global_remove(repo_tag: str) -> int {
    prune_repo_from_graph: any = importlib.import_module("graphify.build").prune_repo_from_graph;

    manifest: any = _load_manifest();
    if repo_tag not in manifest["repos"] {
        raise KeyError(f"repo '{repo_tag}' not in global graph");
    }

    G: any = _load_global_graph();
    removed: any = prune_repo_from_graph(G, repo_tag);
    _save_global_graph(G);

    del manifest["repos"][repo_tag];
    _save_manifest(manifest);
    return removed;
}

impl global_list -> dict {
    return _load_manifest().get("repos", {});
}

impl global_path -> Path {
    return _GLOBAL_GRAPH;
}
