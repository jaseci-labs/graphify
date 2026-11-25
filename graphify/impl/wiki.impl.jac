impl _safe_filename(name: str, limit: int = 200) -> str {
    s: any = name.replace("/", "-").replace(" ", "_").replace(":", "-");
    s = s.replace("(", "").replace(")", "");
    s = _UNSAFE_SLUG_CHARS.sub("_", s);
    s = s.strip(". ");
    return s[:limit] if s else "unnamed";
}

impl _md_link_to(label: str, slug: str | None) -> str {
    text: any = label.replace("[", "\\[").replace("]", "\\]");
    if slug is None {
        return text;
    }
    return f"[{text}]({slug}.md)";
}

impl _incident_edges(G: nx.Graph, nodes: Iterable[str]) -> Generator[any, any, any] {
    nodes = `list(nodes);
    selected: any = `set(nodes);
    yield from G.edges(nodes, data=True);
    if isinstance(G, nx.DiGraph) {
        for (source, target, data) in G.in_edges(nodes, data=True) {
            if source not in selected {
                yield (source, target, data);
            }
        }
    }
}

impl _community_article(
    G: nx.Graph,
    cid: int,
    nodes: list[str],
    label: str,
    labels: dict[int, str],
    cohesion: float | None,
    node_community: dict[str, int] | None = None,
    community_slugs: dict[int, str] | None = None,
) -> str {
    n: any;
    community_slugs = community_slugs or {};
    top_nodes: any = sorted(nodes, key=lambda (n) -> any { G.degree(n) }, reverse=True)[:25];
    selected: any = `set(nodes);
    cross_counts: Counter[int] = Counter();
    conf_counts: Counter[str] = Counter();
    communities: any = node_community or {};
    for (source, target, data) in _incident_edges(G, nodes) {
        conf_counts[data.get("confidence", "EXTRACTED")] += 1;
        neighbor: any = target if source in selected else source;
        ncid: any = communities.get(neighbor);
        if ncid is not None and ncid != cid {
            cross_counts[ncid] += 1;
        }
    }
    cross: any = sorted(cross_counts.items(), key=lambda (item) -> any { -item[1] });
    total_edges: any = sum(conf_counts.values()) or 1;

    sources: any = sorted({G.nodes[n].get("source_file") or "" for n in nodes} - {""});

    lines: list[str] = [];
    lines += [f"# {label}", ""];

    meta_parts: any = [f"{len(nodes)} nodes"];
    if cohesion is not None {
        meta_parts.append(f"cohesion {cohesion:.2f}");
    }
    lines += ["> " + format(" · ".join(meta_parts), ""), ""];

    lines += ["## Key Concepts", ""];
    for nid in top_nodes {
        d: any = G.nodes[nid];
        node_label: any = d.get("label", nid);
        src: any = d.get("source_file", "");
        degree: any = G.degree(nid);
        src_str: any = f" — `{src}`" if src else "";
        lines.append(f"- **{node_label}** ({degree} connections){src_str}");
    }
    remaining: any = len(nodes) - len(top_nodes);
    if remaining > 0 {
        lines.append(f"- *... and {remaining} more nodes in this community*");
    }
    lines.append("");

    lines += ["## Relationships", ""];
    if cross {
        for (other_cid, count) in cross[:12] {
            other_label: any = labels.get(other_cid, f"Community {other_cid}");
            link: any = _md_link_to(other_label, community_slugs.get(other_cid));
            lines.append(f"- {link} ({count} shared connections)");
        }
    } else {
        lines.append("- No strong cross-community connections detected");
    }
    lines.append("");

    if sources {
        lines += ["## Source Files", ""];
        for src in sources[:20] {
            lines.append(f"- `{src}`");
        }
        lines.append("");
    }

    lines += ["## Audit Trail", ""];
    for conf in ("EXTRACTED", "INFERRED", "AMBIGUOUS") {
        n = conf_counts.get(conf, 0);
        pct: any = round(n / total_edges * 100);
        lines.append(f"- {conf}: {n} ({pct}%)");
    }
    lines.append("");

    lines += ["---", "", f"*Part of the graphify knowledge wiki. See {_INDEX_LINK} to navigate.*"];
    return "\n".join(lines);
}

impl _god_node_article(
    G: nx.Graph,
    nid: str,
    labels: dict[int, str],
    node_community: dict[str, int] | None = None,
    community_slugs: dict[int, str] | None = None,
    god_slugs: dict[str, str] | None = None,
) -> str {
    community_slugs = community_slugs or {};
    god_slugs = god_slugs or {};
    d: any = G.nodes[nid];
    node_label: any = d.get("label", nid);
    src: any = d.get("source_file", "");
    cid: any = (node_community or {}).get(nid);
    community_name: any = labels.get(cid, f"Community {cid}") if cid is not None else None;

    lines: list[str] = [];
    lines += [f"# {node_label}", ""];
    lines += [f"> God node · {G.degree(nid)} connections · `{src}`", ""];

    if cid is not None and community_name {
        lines += [f"**Community:** {_md_link_to(community_name, community_slugs.get(cid))}", ""];
    }
    by_relation: dict[str, list[str]] = {};
    directed: any = isinstance(G, nx.DiGraph);
    connections: any = ((target if source == nid else source, operator.ne(source, nid), data)
    for (source, target, data) in _incident_edges(G, [nid]));
    for (neighbor, incoming, ed) in sorted(
        connections, key=lambda (item) -> any { G.degree(item[0]) }, reverse=True
    ) {
        neighbor_label: any = G.nodes[neighbor].get("label", neighbor);
        rel: any = ed.get("relation", "related");
        conf: any = ed.get("confidence", "");
        conf_str: any = f" `{conf}`" if conf else "";
        dir_str: any = " _(incoming)_" if directed and incoming else "";
        by_relation.setdefault(rel, []).append(
            f"{_md_link_to(neighbor_label, god_slugs.get(neighbor))}{conf_str}{dir_str}"
        );
    }

    lines += ["## Connections by Relation", ""];
    for (rel, targets) in sorted(by_relation.items()) {
        lines.append(f"### {rel}");
        for t in targets[:20] {
            lines.append(f"- {t}");
        }
        if len(targets) > 20 {
            lines.append(
                f"- *…and {len(targets) - 20} more `{rel}` connection(s) not listed (lowest-degree first to go)*",
            );
        }
        lines.append("");
    }

    lines += ["---", "", f"*Part of the graphify knowledge wiki. See {_INDEX_LINK} to navigate.*"];
    return "\n".join(lines);
}

impl _index_md(
    communities: dict[int, list[str]],
    labels: dict[int, str],
    god_nodes_data: list[dict],
    total_nodes: int,
    total_edges: int,
    community_slugs: dict[int, str],
    god_articles: list[tuple[str, str]],
) -> str {
    god_slugs: any = `dict(god_articles);
    lines: list[str] = [
        "# Knowledge Graph Index",
        "",
        "> Auto-generated by graphify. Start here — read community articles for context, then drill into god nodes for detail.",
        "",
        f"**{total_nodes} nodes · {total_edges} edges · {len(communities)} communities**",
        "",
        "---",
        "",
        "## Communities",
        "(sorted by size, largest first)",
        "",
    ];

    for (cid, nodes) in sorted(communities.items(), key=lambda (x) -> any { -len(x[1]) }) {
        label: any = labels.get(cid, f"Community {cid}");
        slug: any = community_slugs.get(cid);
        lines.append(f"- {_md_link_to(label, slug)} — {len(nodes)} nodes");
    }
    lines.append("");

    if god_nodes_data {
        lines += ["## God Nodes", "(most connected concepts — the load-bearing abstractions)", ""];
        for `node in god_nodes_data {
            slug = god_slugs.get(`node.get("id"));
            lines.append(
                "- "
                    + format(_md_link_to(`node["label"], slug), "")
                    + " — "
                    + format(`node["degree"], "")
                    + " connections",
            );
        }
        lines.append("");
    }

    lines += ["---", "", "*Generated by [graphify](https://github.com/Graphify-Labs/graphify)*"];
    return "\n".join(lines);
}

impl to_wiki(
    G: nx.Graph,
    communities: dict[int, list[str]],
    output_dir: str | Path,
    community_labels: dict[int, str] | None = None,
    cohesion: dict[int, float] | None = None,
    god_nodes_data: list[dict] | None = None,
) -> int {
    used_slugs: set[str];
    cid: any;
    nodes: any;
    out: any = Path(output_dir);
    out.mkdir(parents=True, exist_ok=True);

    if not communities {
        raise ValueError(
            "communities dict is empty — refusing to clear wiki/. Run `graphify extract .` or `graphify cluster-only .` first.",
        );
    }
    import sys as _sys;
    _g_nodes: any = `set(G.nodes);
    _orig_total: any = sum(len(ns) for ns in communities.values());
    communities = {
        cid: [n for n in nodes if n in _g_nodes]
        for (cid, nodes) in communities.items()
    };
    communities = {cid: nodes for (cid, nodes) in communities.items() if nodes};
    _kept_total: any = sum(len(ns) for ns in communities.values());
    if _kept_total < _orig_total {
        print(
            f"wiki: dropped {_orig_total - _kept_total} stale node ID(s) not in graph ({len(communities)} communities remaining)",
            file=_sys.stderr,
        );
    }

    if not communities {
        raise ValueError(
            "all community node IDs are stale — none exist in the graph. Re-run `graphify extract .` to regenerate .graphify_analysis.json.",
        );
    }
    produced: set[str] = set[any]();

    labels: any = community_labels or {cid: f"Community {cid}" for cid in communities};
    cohesion = cohesion or {};
    god_nodes_data = god_nodes_data or [];
    node_community: dict[str, int] = {
        n: cid
        for (cid, nodes) in communities.items()
        for n in nodes
    };

    count: any = 0;
    used_slugs = {"index"};
    _slug_limit: any = stem_filename_budget(out, reserve=_SLUG_SUFFIX_RESERVE);

    def _unique_slug(base: str) -> str {
        slug: any = base;
        n: any = 2;
        while slug.casefold() in used_slugs {
            slug = f"{base}_{n}";
            n += 1;
        }
        used_slugs.add(slug.casefold());
        return slug;
    }
    community_slugs: dict[int, str] = {};
    for cid in communities {
        label: any = labels.get(cid, f"Community {cid}");
        slug: any = _unique_slug(_safe_filename(label, _slug_limit));
        community_slugs[cid] = slug;
    }

    god_articles: list[tuple[str, str]] = [];
    for node_data in god_nodes_data {
        nid: any = node_data.get("id");
        if nid and nid in G {
            slug = _unique_slug(_safe_filename(node_data["label"], _slug_limit));
            god_articles.append((nid, slug));
        }
    }
    god_slugs: any = `dict(god_articles);
    for (cid, nodes) in communities.items() {
        label = labels.get(cid, f"Community {cid}");
        article: any = _community_article(
            G, cid, nodes, label, labels, cohesion.get(cid), node_community, community_slugs
        );
        fname: any = f"{community_slugs[cid]}.md";
        write_text_atomic_if_changed(out / fname, article);
        produced.add(fname);
        count += 1;
    }

    for (nid, slug) in god_articles {
        article = _god_node_article(G, nid, labels, node_community, community_slugs, god_slugs);
        fname = f"{slug}.md";
        write_text_atomic_if_changed(out / fname, article);
        produced.add(fname);
        count += 1;
    }
    write_text_atomic_if_changed(
        out / "index.md",
        _index_md(
            communities,
            labels,
            god_nodes_data,
            G.number_of_nodes(),
            G.number_of_edges(),
            community_slugs,
            god_articles,
        ),
    );
    produced.add("index.md");
    produced_by_fold: any = {name.casefold(): name for name in sorted(produced)};
    for old_article in out.glob("*.md") {
        if old_article.name in produced {
            continue;
        }
        wanted: any = produced_by_fold.get(old_article.name.casefold());
        if wanted is None {
            old_article.unlink();
        } elif old_article.name != wanted {
            target: any = out / wanted;
            if target.exists() and not target.samefile(old_article) {
                old_article.unlink();
            } else {
                temp: any = out / f".{wanted}.case-tmp";
                old_article.rename(temp);
                temp.rename(target);
            }
        }
    }

    return count;
}
