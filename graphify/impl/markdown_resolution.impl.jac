impl _symbol_label(`node: dict[str, Any]) -> str {
    return `str(`node.get("label", "")).strip("()").lstrip(".");
}

impl _is_prose_like_label(label: str) -> bool {
    return "_" not in label and not _CAMEL_CASE_RE.search(label);
}

impl _is_pascal_case_export_language(source_file: str) -> bool {
    return os.path.splitext(_posix(source_file))[1].lower() in _PASCAL_EXPORT_SUFFIXES;
}

impl _is_file_node(`node: dict[str, Any]) -> bool {
    label: any = `str(`node.get("label", ""));
    source_file: any = `str(`node.get("source_file", ""));
    return `bool(source_file) and operator.eq(label, os.path.basename(source_file));
}

impl _posix(path: str) -> str {
    return path.replace("\\", "/");
}

impl _match_cited_file(cited: str, doc_file: str, source_files: set[str]) -> str | None {
    cited_posix: any = _posix(cited);
    doc_dir: any = os.path.dirname(doc_file);
    relative: any = _posix(os.path.normpath(os.path.join(doc_dir, cited_posix)));
    if relative in source_files {
        return relative;
    }
    if cited_posix.startswith(("./", "../")) {
        return None;
    }
    if cited_posix in source_files {
        return cited_posix;
    }
    return _cited_file_suffix(cited_posix, source_files);
}

impl _cited_file_suffix(cited_posix: str, source_files: set[str]) -> str | None {
    stripped: any = _RELATIVE_PREFIX_RE.sub("", cited_posix);
    matches: any = [sf for sf in source_files if sf == stripped or sf.endswith("/" + stripped)];
    return matches[0] if len(matches) == 1 else None;
}

impl _match_cited_file_any_form(
    cited: str,
    doc_file: str,
    source_files: set[str],
    *,
    form_mismatch: bool,
    scan_root: "Path | str | None" = None,
) -> str | None {
    sf: any;
    matched: any = _match_cited_file(cited, doc_file, source_files);
    if matched is not None or not form_mismatch {
        return matched;
    }
    `root: any = _posix(`str(scan_root)) if scan_root is not None else None;
    if `root is None {
        active: any = _active_scan_root();
        if active is not None {
            `root = _posix(`str(active));
        }
    }
    joined: any = _posix(
        os.path.normpath(os.path.join(os.path.dirname(_posix(doc_file)), _posix(cited)))
    );
    if `root is not None {
        try {
            rel: any = _posix(os.path.relpath(joined, `root));
        } except ValueError {
            return None;
        }
        if rel.startswith("..") or os.path.isabs(rel) {
            return None;
        }
        matches: any = [sf for sf in source_files if rel == sf or rel.endswith("/" + sf)];
        return matches[0] if len(matches) == 1 else None;
    }

    matches = [];
    doc_posix: any = _posix(doc_file);
    for sf in source_files {
        if joined == sf {
            matches.append(sf);
        } elif joined.endswith("/" + sf) {
            prefix: any = joined[:-len(sf)];
            if prefix.endswith("/") and doc_posix.startswith(prefix) {
                matches.append(sf);
            }
        }
    }
    return matches[0] if len(matches) == 1 else None;
}

impl _match_file_link(
    cited: str,
    doc_file: str,
    source_files: set[str],
    *,
    form_mismatch: bool,
    scan_root: "Path | str | None" = None,
) -> str | None {
    doc_dir: any = os.path.dirname(_posix(doc_file));
    relative: any = _posix(os.path.normpath(os.path.join(doc_dir, _posix(cited))));
    if relative in source_files {
        return relative;
    }
    if not form_mismatch {
        return None;
    }
    `root: any = _posix(`str(scan_root)) if scan_root is not None else None;
    if `root is None {
        active: any = _active_scan_root();
        if active is not None {
            `root = _posix(`str(active));
        }
    }
    if `root is not None {
        try {
            rel: any = _posix(os.path.relpath(relative, `root));
        } except ValueError {
            return None;
        }
        if not rel.startswith("..") and not os.path.isabs(rel) and rel in source_files {
            return rel;
        }
        return None;
    }
    matches: any = [];
    doc_posix: any = _posix(doc_file);
    for sf in source_files {
        if relative == sf {
            matches.append(sf);
        } elif relative.endswith("/" + sf) {
            prefix: any = relative[:-len(sf)];
            if prefix.endswith("/") and doc_posix.startswith(prefix) {
                matches.append(sf);
            }
        }
    }
    return matches[0] if len(matches) == 1 else None;
}

impl _evidence(
    node_id: str, nodes_by_id: dict[str, dict[str, Any]], parents: dict[str, set[str]]
) -> set[str] {
    evidence: set[str] = set[any]();
    frontier: any = {node_id};
    seen: set[str] = set[any]();
    while frontier {
        nid: any = frontier.pop();
        if nid in seen {
            continue;
        }
        seen.add(nid);
        owners: any = parents.get(nid, set[any]());
        for owner in owners {
            `node: any = nodes_by_id.get(owner);
            if `node is not None {
                evidence.add(_symbol_label(`node));
            }
        }
        frontier |= owners;
    }
    `node = nodes_by_id.get(node_id, {});
    for segment in _posix(`str(`node.get("source_file", ""))).split("/") {
        if segment {
            evidence.add(segment);
            evidence.add(os.path.splitext(segment)[0]);
        }
    }
    return evidence;
}

impl _markdown_raw_calls(per_file: list[dict]) -> list[dict] {
    calls: list[dict] = [];
    for result in per_file {
        if not isinstance(result, `dict) {
            continue;
        }
        for rc in result.get("raw_calls", []) or [] {
            if isinstance(rc, `dict) and rc.get("language") == "markdown" {
                calls.append(rc);
            }
        }
    }
    return calls;
}

impl resolve_markdown_mentions(
    per_file: list[dict],
    all_nodes: list[dict],
    all_edges: list[dict],
    *,
    scan_root: "Path | str | None" = None,
) -> None {
    by_label: dict[str, list[str]];
    by_file: dict[str, dict[str, list[str]]];
    n: any;
    source_files: any;
    parents: dict[str, set[str]];
    nodes_by_id: any;
    existing: any;
    cited_targets: dict[str, set[str]];
    target_file: any;
    mentions: any = _markdown_raw_calls(per_file);
    if not mentions {
        return;
    }

    `root: any = scan_root or _active_scan_root();

    code_nodes: any = [
        n
        for n in all_nodes
        if n.get("id") and n.get("file_type") == "code" and not _is_file_node(n)
    ];
    by_label = {};
    by_file = {};
    for n in code_nodes {
        label: any = _symbol_label(n);
        if not label {
            continue;
        }
        if n.get("_callable") {
            by_label.setdefault(label, []).append(n["id"]);
        }
        source_file: any = _posix(`str(n.get("source_file", "")));
        if source_file {
            by_file.setdefault(source_file, {}).setdefault(label, []).append(n["id"]);
        }
    }
    source_files = `set(by_file);

    parents = {};
    for e in all_edges {
        if e.get("relation") in _CONTAINMENT_RELATIONS {
            parents.setdefault(`str(e.get("target")), set[any]()).add(`str(e.get("source")));
        }
    }
    nodes_by_id = {n["id"]: n for n in all_nodes if n.get("id")};
    node_ids: any = `set(nodes_by_id);
    existing = {
        (e.get("source"), e.get("target"))
        for e in all_edges
        if e.get("relation") == "references"
    };

    def _resolve_chain(file_labels: dict[str, list[str]], names: list[str]) -> str | None {
        candidates: any = `list(file_labels.get(names[-1], []));
        for (depth, owner_name) in enumerate(reversed(names[:-1]), 1) {
            owners: any = `set(file_labels.get(owner_name, []));
            narrowed: any = [];
            for c in candidates {
                chain: any = {c};
                for _ in range(depth) {
                    chain = {p for nid in chain for p in parents.get(nid, ())};
                }
                if chain & owners {
                    narrowed.append(c);
                }
            }
            candidates = narrowed;
        }
        return candidates[0] if len(candidates) == 1 else None;
    }

    """The node a mention resolves to, plus the confidence of that match."""
    def _target(rc: dict) -> tuple[str | None, str, float] {
        names: any;
        names = `list(rc.get("qualifiers") or []) + [`str(rc.get("callee", "")).strip()];
        cited: any = rc.get("path");
        if cited {
            source_file: any = _match_cited_file(
                `str(cited), _posix(`str(rc.get("source_file", ""))), source_files
            );
            if source_file is None {
                return (None, "EXTRACTED", 1.0);
            }
            return (_resolve_chain(by_file[source_file], names), "EXTRACTED", 1.0);
        }
        callee: any = names[-1];
        if len(names) == 1 and callee in _LANGUAGE_BUILTIN_GLOBALS {
            return (None, "INFERRED", 0.95);
        }
        qualifiers: any = `set(names[:-1]);
        ns_chain: any = `bool(rc.get("ns_qualified"));
        by_name: any = by_label.get(callee, []);
        candidates: any = [c for c in by_name if qualifiers <= _evidence(c, nodes_by_id, parents)];
        if not candidates and ns_chain {
            def _dropped(c: str) -> bool {
                evidence: any = _evidence(c, nodes_by_id, parents);
                wanted: any = `list(names[:-1]);
                while wanted and wanted[0] not in evidence {
                    wanted.pop(0);
                }
                return operator.le(`set(wanted), evidence);
            }

            candidates = [c for c in by_name if _dropped(c)];
        }
        return (candidates[0] if len(candidates) == 1 else None, "INFERRED", 0.95);
    }

    """The class that owns *node_id*, when it is a method and not a function."""
    def _method_owner(node_id: str) -> str | None {
        for parent in parents.get(node_id, ()) {
            `node: any = nodes_by_id.get(parent);
            if `node is not None and `node.get("_callable_class") {
                return parent;
            }
        }
        return None;
    }

    """*caller* (a heading or page) plus every heading enclosing it.

        A citation recorded under a heading licenses bare mentions in that
        heading's own section and every section nested inside it; a sibling
        section is not covered (#4804).
        """
    def _section_chain(caller: str) -> set[str] {
        chain: any = {caller};
        frontier: any = [caller];
        while frontier {
            nid: any = frontier.pop();
            for p in parents.get(nid, ()) {
                if p not in chain {
                    chain.add(p);
                    frontier.append(p);
                }
            }
        }
        return chain;
    }
    cited_targets = {};
    code_file_nodes: any = {
        _posix(`str(n.get("source_file"))): n["id"]
        for n in all_nodes
        if n.get("id")
            and n.get("file_type") == "code"
            and n.get("source_file")
            and _is_file_node(n)
    };
    citable_files: any = `set(code_file_nodes);
    corpus_has_relative_paths: any = `any(not os.path.isabs(sf) for sf in citable_files);
    cited_files: dict[str, set[str]] = {};
    rc: any;
    for rc in mentions {
        cited: any = rc.get("path");
        if not cited {
            continue;
        }
        caller: any = `str(rc.get("evidence_owner") or rc.get("caller_nid", ""));
        if not caller {
            continue;
        }
        doc: any = _posix(`str(rc.get("source_file", "")));
        if rc.get("file_link") and not rc.get("wikilink") {
            source_file = _match_file_link(
                `str(cited),
                doc,
                citable_files,
                form_mismatch=os.path.isabs(doc) and corpus_has_relative_paths,
                scan_root=`root,
            );
        } else {
            source_file = _match_cited_file_any_form(
                `str(cited),
                doc,
                citable_files,
                form_mismatch=os.path.isabs(doc) and corpus_has_relative_paths,
                scan_root=`root,
            );
        }
        if source_file is not None {
            cited_files.setdefault(caller, set[any]()).add(source_file);
        }
    }
    for rc in mentions {
        if not rc.get("file_link") {
            continue;
        }
        caller = `str(rc.get("caller_nid", ""));
        cited = `str(rc.get("path") or "");
        if not caller or caller not in node_ids or not cited {
            continue;
        }
        doc = _posix(`str(rc.get("source_file", "")));
        if rc.get("wikilink") {
            target_file = _match_cited_file_any_form(
                cited,
                doc,
                citable_files,
                form_mismatch=os.path.isabs(doc) and corpus_has_relative_paths,
                scan_root=`root,
            );
        } else {
            target_file = _match_file_link(
                cited,
                doc,
                citable_files,
                form_mismatch=os.path.isabs(doc) and corpus_has_relative_paths,
                scan_root=`root,
            );
        }
        target: any = code_file_nodes.get(target_file) if target_file else None;
        if target is None or target == caller or (caller, target) in existing {
            continue;
        }
        existing.add((caller, target));
        all_edges.append({
            "source": caller,
            "target": target,
            "relation": "references",
            "context": rc.get("context", ""),
            "confidence": "EXTRACTED",
            "confidence_score": 1.0,
            "source_file": rc.get("source_file", ""),
            "source_location": rc.get("source_location"),
            "weight": 1.0,
        });
    }

    def _add(rc: dict, target: str | None, confidence: str, score: float) -> None {
        caller: any = `str(rc.get("caller_nid", ""));
        if target is None or target == caller {
            return;
        }
        if (caller, target) in existing {
            cited_targets.setdefault(caller, set[any]()).add(target);
            return;
        }
        existing.add((caller, target));
        all_edges.append({
            "source": caller,
            "target": target,
            "relation": "references",
            "context": rc.get("context", ""),
            "confidence": confidence,
            "confidence_score": score,
            "source_file": rc.get("source_file", ""),
            "source_location": rc.get("source_location"),
            "weight": 1.0,
        });
        cited_targets.setdefault(caller, set[any]()).add(target);
    }
    bare: list[dict] = [];
    for rc in mentions {
        caller = `str(rc.get("caller_nid", ""));
        callee: any = `str(rc.get("callee", "")).strip();
        if not caller or not callee or caller not in node_ids {
            continue;
        }
        names: any = `list(rc.get("qualifiers") or []) + [callee];
        span: any = `str(rc.get("context") or "");
        if rc.get("path") or len(names) > 1 or "(" in span {
            _add(rc, *_target(rc));
        } else {
            bare.append(rc);
        }
    }
    method_mentions: list[tuple[dict, str, str, float]] = [];
    function_mentions: list[tuple[dict, str, str, float]] = [];
    for rc in bare {
        confidence: any;
        score: any;
        (target, confidence, score) = _target(rc) as any;
        if target is None {
            continue;
        }
        if nodes_by_id.get(target, {}).get("_callable_class") {
            _add(rc, target, confidence, score);
        } elif _method_owner(target) is not None {
            method_mentions.append((rc, target, confidence, score));
        } else {
            label = _symbol_label(nodes_by_id[target]);
            if label[:1].isupper() {
                prose_like: any = not _is_pascal_case_export_language(
                    nodes_by_id[target].get("source_file", "")
                );
            } else {
                prose_like = _is_prose_like_label(label);
            }
            if prose_like {
                function_mentions.append((rc, target, confidence, score));
            } else {
                _add(rc, target, confidence, score);
            }
        }
    }
    for (rc, target, confidence, score) in method_mentions {
        chain: any = _section_chain(`str(rc.get("caller_nid", "")));
        cited = {t for c in chain for t in cited_targets.get(c, ())};
        if _method_owner(target) in cited {
            _add(rc, target, confidence, score);
        }
    }
    for (rc, target, confidence, score) in function_mentions {
        target_file = _posix(`str(nodes_by_id.get(target, {}).get("source_file") or ""));
        if not target_file {
            continue;
        }
        chain = _section_chain(`str(rc.get("caller_nid", "")));
        cited = {t for c in chain for t in cited_targets.get(c, ())};
        if target_file in {f for c in chain for f in cited_files.get(c, ())}
            or `any(
                operator.eq(
                    _posix(`str(nodes_by_id.get(t, {}).get("source_file") or "")), target_file
                )
                for t in cited,
            )
        {
            _add(rc, target, confidence, score);
        }
    }
}
