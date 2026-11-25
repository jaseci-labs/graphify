impl _common_root(paths: List[str]) -> str {
    p: any;
    if not paths {
        return "";
    }
    parts: any = [Path(p).parent.parts for p in paths if p];
    if not parts {
        return "";
    }
    common: any = parts[0];
    for p in parts[1:] {
        i: any = 0;
        while i < len(common) and i < len(p) and common[i] == p[i] {
            i += 1;
        }
        common = common[:i];
    }
    return `str(Path(*common)) if common else "";
}

impl _make_truncation_leaf(extra: int, total_count: Optional[int] = None) -> Dict[str, Any] {
    return {
        "name": f"(+{extra} more)",
        "total_count": extra if total_count is None else total_count,
        "children": [],
    };
}

impl _attach_files(
    file_nodes: List[Dict[str, Any]],
    *,
    `root: str,
    max_children: int,
    label: Optional[str],
    directory_ids: set[int],
) -> "tuple[Dict[str, Any], int, Dict[str, List[Dict[str, Any]]]]" {
    dir_index: Dict[str, Dict[str, Any]];
    root_node: Dict[str, Any];
    root_path: any = Path(`root);

    by_file: Dict[str, List[Dict[str, Any]]] = defaultdict(list[any]);
    n: any;
    for n in file_nodes {
        by_file[n["source_file"]].append(n);
    }
    dir_index = {};
    label_root: any = label or root_path.name or `root or "/";
    root_node = {"name": label_root, "total_count": 0, "children": []};
    dir_index[`str(root_path)] = root_node;
    directory_ids.add(id(root_node));

    def _ensure_dir(abs_path: Path) -> Dict[str, Any] {
        key: any = `str(abs_path);
        if key in dir_index {
            return dir_index[key];
        }
        if abs_path == abs_path.parent {
            return root_node;
        }
        parent: any = _ensure_dir(abs_path.parent) if abs_path.parent != abs_path else root_node;
        `node: any = {"name": abs_path.name, "total_count": 0, "children": []};
        dir_index[key] = `node;
        directory_ids.add(id(`node));
        parent["children"].append(`node);
        return `node;
    }

    matched_files: any = 0;
    for (src_file, syms) in sorted(by_file.items()) {
        src_path: any = Path(src_file);
        try {
            rel: any = src_path.relative_to(root_path);
            parent_path: any = (root_path / rel).parent;
            matched_files += 1;
        } except ValueError {
            parent_path = root_path;
        }
        parent_dir: any = _ensure_dir(parent_path);
        sym_children: List[Dict[str, Any]] = [];
        for n in syms {
            label = n.get("label", n.get("id", "?"));
            if n.get("file_type") == "code" {
                _is_file_node_label: any = importlib.import_module("graphify.build")._is_file_node_label;
                if _is_file_node_label(label, src_file) {
                    continue;
                }
            }
            sym_children.append({"name": label, "total_count": 1, "children": []});
        }
        sym_children.sort(key=lambda (c) -> any { (c["name"].startswith("_"), c["name"].lower()) });
        if len(sym_children) > max_children {
            extra: any = len(sym_children) - max_children;
            sym_children = sym_children[:max_children] + [_make_truncation_leaf(extra)];
        }
        file_node: any = {
            "name": src_path.name,
            "total_count": len(sym_children) or 1,
            "children": sym_children,
        };
        parent_dir["children"].append(file_node);
    }

    return (root_node, matched_files, by_file);
}

impl _repo_groups(
    file_nodes: List[Dict[str, Any]]
) -> "tuple[Dict[str, List[Dict[str, Any]]], List[Dict[str, Any]]]" {
    groups: Dict[str, List[Dict[str, Any]]] = defaultdict(list[any]);
    untagged: List[Dict[str, Any]] = [];
    for n in file_nodes {
        tag: any = n.get("repo");
        if isinstance(tag, `str) and tag {
            groups[tag].append(n);
        } else {
            untagged.append(n);
        }
    }
    return (groups, untagged);
}

impl build_tree(
    `graph: Dict[str, Any],
    *,
    `root: Optional[str] = None,
    max_children: int = max_children_default_,
    project_label: Optional[str] = None,
) -> Dict[str, Any] {
    directory_ids: set[int];
    if max_children < 0 {
        raise ValueError("--max-children must be nonnegative");
    }
    directory_ids = set[any]();
    nodes: List[Dict[str, Any]] = `list(`graph.get("nodes", []));
    for n in nodes {
        if not n.get("source_file") {
            for alias in ("file", "path", "filepath", "src") {
                val: any = n.get(alias);
                if isinstance(val, `str) and val.strip() {
                    n["source_file"] = n.pop(alias).strip();
                    break;
                }
            }
        }
    }
    file_nodes: any = [n for n in nodes if n.get("source_file")];
    if not file_nodes {
        return {"name": "(empty graph)", "total_count": 0, "children": []};
    }

    explicit_root: any = `root is not None;
    groups: any;
    untagged: any;
    (groups, untagged) = _repo_groups(file_nodes) as any;

    if len(groups) < 2 {
        if `root is None {
            `root = _common_root([n["source_file"] for n in file_nodes]);
        }
        root_node: any;
        matched_files: any;
        by_file: any;
        (root_node, matched_files, by_file) = _attach_files(
            file_nodes,
            root=`root,
            max_children=max_children,
            label=project_label,
            directory_ids=directory_ids,
        ) as any;
        total_matched: any;
        total_files: any;
        (total_matched, total_files) = (matched_files, len(by_file));
        sample: any = min(by_file);
    } else {
        root_node = {"name": project_label or "(merged graph)", "total_count": 0, "children": []};
        directory_ids.add(id(root_node));
        value_: any = 0;
        total_matched = value_;
        total_files = value_;
        sample = "";
        ordered: any = sorted(groups.items());
        if untagged {
            ordered.append((_NO_REPO_LABEL, untagged));
        }
        for (tag, group) in ordered {
            paths: any = [n["source_file"] for n in group];
            if `root is not None {
                group_root: any = `root;
            } elif all(not Path(p).is_absolute() for p in paths) {
                group_root = "";
            } else {
                group_root = _common_root(paths);
            }
            repo_node: any;
            matched: any;
            (repo_node, matched, by_file) = _attach_files(
                group,
                root=group_root,
                max_children=max_children,
                label=tag,
                directory_ids=directory_ids,
            ) as any;
            root_node["children"].append(repo_node);
            total_matched += matched;
            total_files += len(by_file);
            sample = sample or min(by_file);
        }
    }
    if explicit_root and total_matched == 0 {
        raise ValueError(
            f"--root {`root} matched 0 of {total_files} source files (source_file paths are stored repo-relative, e.g. {sample!r})",
        );
    }
    def _finalise(d: Dict[str, Any]) -> int {
        kids: any = d.get("children") or [];
        kids.sort(
            key=lambda (c) -> any {
                (0 if c.get("children") and len(c["children"]) > 0 else 1, c["name"].lower())
            },
        );
        if not kids {
            return d.get("total_count") or 1;
        }
        child_totals: any = [_finalise(c) for c in kids];
        d["total_count"] = sum(child_totals) or 1;
        if id(d) in directory_ids and len(kids) > max_children {
            d["children"] = kids[:max_children] + [
                _make_truncation_leaf(len(kids) - max_children, sum(child_totals[max_children:])),
            ];
        }
        return d["total_count"];
    }

    _finalise(root_node);
    return root_node;
}

impl emit_html(
    tree: Dict[str, Any], *, title: str, header: str, svg_width: int = 6000, svg_height: int = 8000
) -> str {
    data_json: any = json.dumps(tree, ensure_ascii=True, separators=(",", ":")).replace(
        "<", "\\u003c"
    );
    return _HTML_TEMPLATE.format(
        title=_html.escape(title),
        header=_html.escape(header),
        svg_width=svg_width,
        svg_height=svg_height,
        data_json=data_json,
    );
}

impl write_tree_html(
    graph_path: Path,
    output_path: Path,
    *,
    `root: Optional[str] = None,
    max_children: int = max_children_default__,
    project_label: Optional[str] = None,
    top_k_edges: int = 0,
) -> Path {
    check_graph_file_size_cap: any = importlib.import_module("graphify.security").check_graph_file_size_cap;
    check_graph_file_size_cap(graph_path);
    `graph: any = json.loads(graph_path.read_text(encoding="utf-8"));
    tree: any = build_tree(
        `graph, root=`root, max_children=max_children, project_label=project_label
    );
    title: any = format(tree["name"], "") + " — graphify tree viewer";
    header: any = format(tree["name"], "") + " — Knowledge Graph";
    html: any = emit_html(tree, title=title, header=header);
    output_path.parent.mkdir(parents=True, exist_ok=True);
    output_path.write_text(html, encoding="utf-8");
    return output_path;
}
