impl _key(label: object) -> str {
    return `str(label or "").strip().removeprefix(".").removesuffix("()");
}

impl _suffix(source_file: object) -> str {
    return os.path.splitext(`str(source_file or ""))[1].lower();
}

impl _parked_entries(data: dict) -> list[dict] {
    metadata: any = data.get("metadata");
    if not isinstance(metadata, `dict) {
        return [];
    }
    parked: any = metadata.get(UNRESOLVED_CALLS_KEY);
    if not isinstance(parked, `list) {
        return [];
    }
    return [`entry for `entry in parked if isinstance(`entry, `dict)];
}

impl _drop_previous_output(merged: "nx.Graph") {
    stale: any = [
        (u, v)
        for (u, v, data) in merged.edges(data=True)
        if data.get(CROSS_REPO_CALL_MARKER)
    ];
    merged.remove_edges_from(stale);
}

impl _index_declarations(merged: "nx.Graph") -> tuple[dict[str, list[str]], set[str]] {
    by_name: dict[str, list[str]] = defaultdict(list[any]);
    type_ids: set[str] = set[any]();
    for (`node, data) in merged.nodes(data=True) {
        if not data.get("_callable_class") or not data.get("source_file") {
            continue;
        }
        if not data.get("repo") {
            continue;
        }
        name: any = _key(data.get("label"));
        if not name {
            continue;
        }
        by_name[name].append(`node);
        type_ids.add(`node);
    }
    return (by_name, type_ids);
}

impl _index_members(
    merged: "nx.Graph", type_ids: set[str]
) -> dict[str, dict[tuple[str, str], list[str]]] {
    relation: any;
    by_relation: dict[str, dict[tuple[str, str], list[str]]] = {
        relation: defaultdict(list[any])
        for relation in _MEMBER_RELATIONS
    };
    for (u, v, data) in merged.edges(data=True) {
        relation = data.get("relation");
        if relation not in by_relation {
            continue;
        }
        if u in type_ids and v not in type_ids {
            owner: any;
            member: any;
            (owner, member) = (u, v);
        } elif v in type_ids and u not in type_ids {
            (owner, member) = (v, u);
        } else {
            continue;
        }
        name: any = _key(merged.nodes[member].get("label"));
        if name {
            by_relation[relation][owner, name].append(member);
        }
    }
    return by_relation;
}

impl _member_relations(lang: str) -> tuple[str, ...] {
    return ("method", "defines") if lang == "cpp" else ("method",);
}

impl _member_keys(lang: str, callee: str) -> tuple[str, ...] {
    if lang == "objc" {
        selector: any = callee.lstrip("+-");
        return (f"-{selector}", f"+{selector}");
    }
    return (callee,);
}

impl _objc_union_definition(
    merged: "nx.Graph",
    members: dict[tuple[str, str], list[str]],
    candidates: list[str],
    callee: str,
) -> str | None {
    defs: list[str] = [];
    for cand in candidates {
        for member_key in _member_keys("objc", callee) {
            for member in members.get((cand, member_key), []) {
                data: any = merged.nodes[member];
                if data.get("definition_file")
                    or _suffix(data.get("source_file")) in _OBJC_IMPL_SUFFIXES
                {
                    defs.append(member);
                }
            }
        }
    }
    defs = `list(dict.fromkeys(defs));
    return defs[0] if len(defs) == 1 else None;
}

impl _java_overload_target(merged: nx.Graph, targets: list[str], arity: object) -> str | None {
    def meta(`node: str) -> dict {
        found: any = merged.nodes[`node].get("metadata");
        return found if isinstance(found, `dict) else {};
    }

    def line(`node: str) -> int {
        loc: any = `str(merged.nodes[`node].get("source_location") or "");
        return `int(loc[1:]) if loc[1:].isdigit() else 0;
    }

    if not all(isinstance(meta(t).get("arity"), `int) for t in targets) {
        return None;
    }
    fits: any = targets;
    if isinstance(arity, `int) and not isinstance(arity, `bool) {
        accepting: any = [
            t
            for t in targets
            if meta(t).get("min_arity", meta(t)["arity"]) <= arity
                and (arity <= meta(t)["arity"] or meta(t).get("variadic"))
        ];
        if len(accepting) == 1 {
            return accepting[0];
        }
    }
    return min(fits, key=lambda (t) -> any { (line(t), t) });
}

impl link_cross_repo_member_calls(merged: "nx.Graph") -> int {
    `entry: any;
    target: any;
    _drop_previous_output(merged);
    parked_nodes: any = [
        (`node, data)
        for (`node, data) in merged.nodes(data=True)
        if _parked_entries(data)
    ];
    if not parked_nodes {
        return 0;
    }

    by_name: any;
    type_ids: any;
    (by_name, type_ids) = _index_declarations(merged) as any;
    if not by_name {
        return 0;
    }
    members_by_relation: any = _index_members(merged, type_ids);
    csharp_resolver: any = None;
    if `any(
        operator.eq(`str(`entry.get("lang") or ""), "csharp")
        for (_, data) in parked_nodes
        for `entry in _parked_entries(data),
    ) {
        CsharpNameResolver: any = importlib.import_module(
            "graphify.extractors.csharp"
        ).CsharpNameResolver;

        resolver_nodes: any = [`dict(data, id=`node) for (`node, data) in merged.nodes(data=True)];
        resolver_edges: any = [
            `dict(data, source=source, target=target)
            for (source, target, data) in merged.edges(data=True)
        ];
        csharp_resolver = CsharpNameResolver(resolver_nodes, resolver_edges);
    }

    added: any = 0;
    for (caller, caller_data) in parked_nodes {
        caller_repo: any = caller_data.get("repo");
        if not caller_repo {
            continue;
        }
        for `entry in _parked_entries(caller_data) {
            lang: any = `str(`entry.get("lang") or "");
            suffixes: any = _LANG_SUFFIXES.get(lang);
            receiver_type: any = _key(`entry.get("receiver_type"));
            callee: any = _key(`entry.get("callee"));
            if not suffixes or not receiver_type or not callee {
                continue;
            }
            candidates: any = [
                `node
                for `node in by_name.get(receiver_type, [])
                if merged.nodes[`node].get("repo") != caller_repo
                    and _suffix(merged.nodes[`node].get("source_file")) in suffixes
            ];
            if not candidates {
                continue;
            }
            if lang == "objc" and len(candidates) > 1 {
                target = _objc_union_definition(
                    merged, members_by_relation["method"], candidates, callee
                );
                if target is None {
                    continue;
                }
            } else {
                if len(candidates) != 1 {
                    continue;
                }
                if lang == "csharp" {
                    resolved: any;
                    _decisive: any;
                    (resolved, _decisive) = csharp_resolver.resolve_type_name(
                        receiver_type,
                        `dict(caller_data, id=caller),
                        `str(caller_data.get("source_file") or ""),
                    ) as any;
                    if resolved != candidates[0] {
                        continue;
                    }
                }
                targets: list[str] = [];
                for relation in _member_relations(lang) {
                    members: any = members_by_relation[relation];
                    for member_key in _member_keys(lang, callee) {
                        targets.extend(members.get((candidates[0], member_key), []));
                    }
                    if targets {
                        break;
                    }
                }
                if len(targets) > 1 and lang == "java" {
                    picked: any = _java_overload_target(merged, targets, `entry.get("arity"));
                    if picked is None {
                        continue;
                    }
                    target = picked;
                } elif len(targets) != 1 {
                    continue;
                } else {
                    target = targets[0];
                }
            }
            if target == caller or merged.has_edge(caller, target) {
                continue;
            }
            metadata: any = `entry.get("metadata");
            conditions: any = metadata.get("cpp_conditions")
                if lang == "cpp" and isinstance(metadata, `dict)
                else None;
            merged.add_edge(
                caller,
                target,
                relation="calls",
                context="cross_repo",
                confidence="INFERRED",
                confidence_score=0.85,
                source_file=`str(`entry.get("file") or caller_data.get("source_file") or ""),
                source_location=`entry.get("line"),
                weight=1.0,
                _src=caller,
                _tgt=target,
                **{CROSS_REPO_CALL_MARKER: True},
                **(
                    {"metadata": {"cpp_conditions": conditions}}
                        if isinstance(conditions, `list) and conditions
                        else {}
                ),
            );
            added += 1;
        }
    }
    return added;
}
