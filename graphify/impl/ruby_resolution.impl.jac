impl _key(label: str) -> str {
    return re.sub("[^a-zA-Z0-9]+", "", `str(label)).lower();
}

impl _method_name(label: object) -> str {
    return `str(label or "").strip("()").lstrip(".");
}

impl _ruby_method_kind(`node: dict | None) -> str | None {
    metadata: any = `node.get("metadata") if isinstance(`node, `dict) else None;
    if not isinstance(metadata, `dict) {
        return None;
    }
    kind: any = metadata.get("ruby_method_kind");
    return kind if kind in {"instance", "singleton"} else None;
}

impl _ruby_lookup_unsafe(`node: dict | None) -> bool {
    metadata: any = `node.get("metadata") if isinstance(`node, `dict) else None;
    return isinstance(metadata, `dict)
        and `bool(metadata.get("ruby_lookup_unsafe") or metadata.get("ruby_reopened"));
}

impl _ruby_raw_calls(per_file: list[dict]) -> list[dict] {
    calls: list[dict] = [];
    for result in per_file {
        if not isinstance(result, `dict) {
            continue;
        }
        for rc in result.get("raw_calls", []) {
            if not isinstance(rc, `dict) {
                continue;
            }
            sf: any = `str(rc.get("source_file", ""));
            if sf.endswith((".rb", ".rake")) {
                calls.append(rc);
            }
        }
    }
    return calls;
}

impl resolve_ruby_member_calls(per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]) {
    node_by_id: dict[str, dict];
    external_method_owners: any;
    class_def_nids: dict[str, list[str]];
    method_name: any;
    ruby_class_nids: any;
    class_labels: dict[str, set[str]];
    inheritance: dict[str, set[str]];
    methods_by_kind: dict[tuple[str, str, str], set[str]];
    ambiguous_method_names: set[tuple[str, str]];
    owner: any;
    fq_label_map: dict[tuple[str, ...], list[str]];
    existing_pairs: any;
    node_by_id = {`str(`node["id"]): `node for `node in all_nodes if `node.get("id")};

    ruby_file_nodes: any = [
        `node
        for `node in all_nodes
        if `str(`node.get("source_file", "")).endswith((".rb", ".rake"))
            and _is_file_node_label(`node.get("label"), `node.get("source_file"))
    ];
    ruby_context_complete: any = `bool(ruby_file_nodes)
        and all(
            isinstance(`node.get("metadata"), `dict)
                and operator.eq(`node["metadata"].get("ruby_resolution_schema"), 1)
            for `node in ruby_file_nodes,
        );
    unsafe_ruby_files: any = {
        `str(`node.get("source_file"))
        for `node in ruby_file_nodes
        if _ruby_lookup_unsafe(`node)
    };
    external_method_owners = {
        owner
        for `node in ruby_file_nodes
        for metadata in [`node.get("metadata")]
        if isinstance(metadata, `dict)
        for owners in [metadata.get("ruby_external_method_owners", [])]
        if isinstance(owners, `list)
        for owner in owners
        if isinstance(owner, `str)
    };
    class_def_nids = {};
    method_index: dict[tuple[str, str], str] = {};
    method_owners: dict[str, set[str]] = {};
    inheritance_edges: list[tuple[str, str, str | None, list[str] | None]] = [];
    for e in all_edges {
        if e.get("relation") == "inherits" {
            src: any;
            tgt: any;
            (src, tgt) = (e.get("source"), e.get("target"));
            if src and tgt {
                metadata: any = e.get("metadata");
                candidate_base: any = metadata.get("ruby_superclass_ref")
                    if isinstance(metadata, `dict)
                    else None;
                raw_base: any = candidate_base if isinstance(candidate_base, `str) else None;
                candidate_scopes: any = metadata.get("ruby_lexical_scopes")
                    if isinstance(metadata, `dict)
                    else None;
                lexical_scopes: any = candidate_scopes
                    if isinstance(candidate_scopes, `list)
                        and all(isinstance(scope, `str) for scope in candidate_scopes)
                    else None;
                inheritance_edges.append((`str(src), `str(tgt), raw_base, lexical_scopes));
            }
            continue;
        }
        if e.get("relation") != "method" {
            continue;
        }
        (src, tgt) = (e.get("source"), e.get("target"));
        if not src or not tgt {
            continue;
        }
        (src, tgt) = (`str(src), `str(tgt));
        cnode: any = node_by_id.get(src);
        if cnode is not None {
            class_source: any = `str(cnode.get("source_file", ""));
            method_source: any = `str(node_by_id.get(tgt, {}).get("source_file", ""));
            if not class_source.endswith((".rb", ".rake"))
                or not method_source.endswith((".rb", ".rake"))
            {
                continue;
            }
            clabel: any = `str(cnode.get("label", ""));
            class_def_nids.setdefault(_key(clabel), []).append(src);
            if "::" in clabel {
                class_def_nids.setdefault(_key(clabel.split("::")[-1]), []).append(src);
            }
        }
        tnode: any = node_by_id.get(tgt);
        if tnode is not None {
            method_name = _method_name(tnode.get("label"));
            method_index[src, method_name] = tgt;
            method_owners.setdefault(tgt, set[any]()).add(src);
        }
    }
    for n in all_nodes {
        nid: any = n.get("id");
        sf: any = `str(n.get("source_file", ""));
        label: any = `str(n.get("label", ""));
        if nid and sf.endswith((".rb", ".rake")) and _BARE_CONST_RE.match(label) {
            class_def_nids.setdefault(_key(label), []).append(`str(nid));
            if "::" in label {
                class_def_nids.setdefault(_key(label.split("::")[-1]), []).append(`str(nid));
            }
        }
    }
    for k in `list(class_def_nids) {
        class_def_nids[k] = sorted(`set(class_def_nids[k]));
    }

    ruby_class_nids = {nid for nids in class_def_nids.values() for nid in nids};
    class_labels = {};
    for nid in ruby_class_nids {
        label = `str(node_by_id.get(nid, {}).get("label", ""));
        class_labels.setdefault(label, set[any]()).add(nid);
    }
    def _resolve_base(raw_base: str | None, lexical_scopes: list[str] | None) -> str | None {
        if not raw_base or lexical_scopes is None {
            return None;
        }
        reference: any = raw_base.removeprefix("::");
        ref_parts: any = [part for part in reference.split("::") if part];
        if not ref_parts {
            return None;
        }
        if raw_base.startswith("::") {
            lookup_scopes: any = [""];
        } elif lexical_scopes {
            lookup_scopes = lexical_scopes;
        } else {
            lookup_scopes = [""];
        }
        for scope in lookup_scopes {
            candidate_label: any = "::".join([
                *[part for part in scope.split("::") if part],
                *ref_parts,
            ]);
            candidates: any = class_labels.get(candidate_label, set[any]());
            if len(candidates) == 1 {
                return next(iter(candidates));
            }
            if len(candidates) > 1 {
                return None;
            }
            if scope and len(ref_parts) > 1 {
                first_prefix_label: any = "::".join([
                    *[part for part in scope.split("::") if part],
                    ref_parts[0],
                ]);
                if class_labels.get(first_prefix_label) {
                    return None;
                }
            }
        }
        return None;
    }

    inheritance = {};
    for (source, edge_target, raw_base, lexical_scopes) in inheritance_edges {
        if source not in ruby_class_nids {
            continue;
        }
        resolved: any = _resolve_base(raw_base, lexical_scopes);
        target_node: any = node_by_id.get(edge_target);
        target_label: any = `str(target_node.get("label", "")) if target_node else "";
        target_source: any = `str(target_node.get("source_file", "")) if target_node else "";
        raw_tail: any = `str(raw_base or "").removeprefix("::").split("::")[-1];
        edge_matches_reference: any = `bool(
            target_node
                and raw_tail
                and operator.eq(_key(target_label.split("::")[-1]), _key(raw_tail)),
        );
        if resolved is not None
            and (resolved == edge_target or not target_source and edge_matches_reference)
        {
            inheritance.setdefault(source, set[any]()).add(resolved);
        }
    }

    methods_by_kind = {};
    ambiguous_method_names = set[any]();
    method_nid: any;
    owners: any;
    for (method_nid, owners) in method_owners.items() {
        method_name = _method_name(node_by_id[method_nid].get("label"));
        method_kind: any = _ruby_method_kind(node_by_id.get(method_nid));
        if len(owners) != 1 or method_kind is None {
            ambiguous_method_names.update((owner, method_name) for owner in owners);
            continue;
        }
        owner = next(iter(owners));
        methods_by_kind.setdefault((owner, method_name, method_kind), set[any]()).add(method_nid);
    }

    def _has_external_method_owner(label: str) -> bool {
        label_parts: any;
        owner_parts: any;
        label_parts = `tuple(part for part in label.split("::") if part);
        for raw_owner in external_method_owners {
            is_prefix: any = raw_owner.endswith("::*");
            owner_ref: any = raw_owner.removesuffix("::*") if is_prefix else raw_owner;
            owner_parts = `tuple(part for part in owner_ref.removeprefix("::").split("::") if part);
            if not owner_parts {
                continue;
            }
            if is_prefix {
                if owner_ref.startswith("::") {
                    if label_parts[:len(owner_parts)] == owner_parts {
                        return True;
                    }
                } elif `any(
                    operator.eq(label_parts[index:index + len(owner_parts)], owner_parts)
                    for index in range(len(label_parts) - len(owner_parts) + 1),
                ) {
                    return True;
                }
                continue;
            }
            if owner_ref.startswith("::") and label_parts == owner_parts {
                return True;
            }
            if not owner_ref.startswith("::") and label_parts[-len(owner_parts):] == owner_parts {
                return True;
            }
        }
        return False;
    }

    def _segment_path(label: str) -> list[str] {
        return [s.strip().lower() for s in `str(label).split("::") if s.strip()];
    }
    fq_label_map = {};
    last_segment_map: dict[str, list[str]] = {};
    for nid in sorted({nid for nids in class_def_nids.values() for nid in nids}) {
        segs: any = _segment_path(`str(node_by_id.get(nid, {}).get("label", "")));
        if segs {
            fq_label_map.setdefault(`tuple(segs), []).append(nid);
            last_segment_map.setdefault(segs[-1], []).append(nid);
        }
    }

    existing_pairs = {(e.get("source"), e.get("target")) for e in all_edges};

    def _unique_class(name: str) -> str | None {
        nids: any = class_def_nids.get(_key(name), []);
        return nids[0] if len(nids) == 1 else None;
    }
    def _class_by_const_path(raw: str) -> str | None {
        segs: any = `tuple(_segment_path(raw));
        if not segs {
            return None;
        }
        if raw.strip().startswith("::") {
            nids: any = fq_label_map.get(segs, []);
            return nids[0] if len(nids) == 1 else None;
        }
        hits: any = {
            nid
            for (path, nids) in fq_label_map.items()
            if len(path) >= len(segs) and path[-len(segs):] == segs
            for nid in nids
        };
        return next(iter(hits)) if len(hits) == 1 else None;
    }

    def _emit(
        caller: str, target: str, rc: dict[str, Any], relation: str = "calls", context: str = "call"
    ) {
        if not caller or not target or caller == target {
            return;
        }
        if (caller, target) in existing_pairs {
            return;
        }
        existing_pairs.add((caller, target));
        all_edges.append({
            "source": caller,
            "target": target,
            "relation": relation,
            "context": context,
            "confidence": "EXTRACTED",
            "confidence_score": 1.0,
            "source_file": rc.get("source_file", ""),
            "source_location": rc.get("source_location"),
            "weight": 1.0,
        });
    }
    def _inherited_method(owner: str, name: str, kind: str) -> str | None {
        current: any = owner;
        seen: set[str] = set[any]();
        first: any = True;
        while current not in seen {
            seen.add(current);
            `node: any = node_by_id.get(current);
            label: any = `str(`node.get("label", "")) if `node else "";
            if current not in ruby_class_nids
                or len(class_labels.get(label, set[any]())) != 1
                or _ruby_lookup_unsafe(`node)
                or _has_external_method_owner(label)
            {
                return None;
            }
            if (current, name) in ambiguous_method_names {
                return None;
            }
            candidates: any = methods_by_kind.get((current, name, kind), set[any]());
            if candidates {
                if first or len(candidates) != 1 {
                    return None;
                }
                return next(iter(candidates));
            }
            bases: any = inheritance.get(current, set[any]());
            if len(bases) != 1 {
                return None;
            }
            current = next(iter(bases));
            first = False;
        }
        return None;
    }
    def _promote_inferred(caller: str, target: str, callee: str, rc: dict) {
        matches: any = [
            `edge
            for `edge in all_edges
            if `edge.get("source") == caller
                and `edge.get("target") == target
                and `edge.get("relation") == "calls"
                and `edge.get("context") == "call"
                and `edge.get("confidence") == "INFERRED"
                and `edge.get("source_file") == rc.get("source_file", "")
                and `edge.get("source_location") == rc.get("source_location")
                and _method_name(node_by_id.get(target, {}).get("label")) == callee
        ];
        if len(matches) == 1 {
            matches[0]["confidence"] = "EXTRACTED";
            matches[0]["confidence_score"] = 1.0;
        }
    }
    rc: any;
    for rc in _ruby_raw_calls(per_file) {
        if not rc.get("is_mixin") {
            continue;
        }
        caller: any = `str(rc.get("caller_nid", ""));
        module_name: any = rc.get("callee");
        if not caller or not module_name {
            continue;
        }
        raw_ref: any = `str(module_name);
        absolute: any = raw_ref.startswith("::");
        ref_segs: any = _segment_path(raw_ref);
        caller_node: any = node_by_id.get(caller);
        caller_segs: any = []
            if absolute
            else _segment_path(`str(caller_node.get("label", "")) if caller_node else "");
        target: str | None = None;
        for i in range(len(caller_segs), -1, -1) {
            nids: any = fq_label_map.get(`tuple(caller_segs[:i] + ref_segs), []);
            if len(nids) == 1 {
                target = nids[0];
                break;
            }
            if len(nids) > 1 {
                break;
            }
        }
        if target is None and len(ref_segs) == 1 and not absolute {
            nids = last_segment_map.get(ref_segs[0], []);
            if len(nids) == 1 {
                target = nids[0];
            }
        }
        if target is not None {
            _emit(caller, target, rc, relation="mixes_in", context="mixin");
        }
    }
    if ruby_context_complete {
        for rc in _ruby_raw_calls(per_file) {
            if rc.get("is_mixin") or rc.get("is_member_call") is not False {
                continue;
            }
            caller = `str(rc.get("caller_nid", ""));
            callee: any = `str(rc.get("callee", ""));
            caller_kind: any = _ruby_method_kind(node_by_id.get(caller));
            owners = method_owners.get(caller, set[any]());
            caller_file: any = `str(node_by_id.get(caller, {}).get("source_file", ""));
            if not caller
                or not callee
                or caller_kind is None
                or len(owners) != 1
                or caller_file in unsafe_ruby_files
            {
                continue;
            }
            target = _inherited_method(next(iter(owners)), callee, caller_kind);
            if target is not None and target != caller {
                _promote_inferred(caller, target, callee, rc);
            }
        }
    }

    for rc in _ruby_raw_calls(per_file) {
        if not rc.get("is_member_call") {
            continue;
        }
        caller = `str(rc.get("caller_nid", ""));
        callee = rc.get("callee");
        if not caller or not callee {
            continue;
        }
        receiver: any = rc.get("receiver");
        if receiver and `str(receiver).lstrip(":")[:1].isupper() {
            recv_raw: any = `str(receiver);
            class_nid: any = _class_by_const_path(recv_raw)
                if "::" in recv_raw
                else _unique_class(recv_raw);
            if class_nid is not None {
                if callee == "new" {
                    _emit(caller, class_nid, rc);
                } else {
                    method_nid = method_index.get((class_nid, `str(callee)));
                    _emit(caller, method_nid or class_nid, rc);
                }
            }
            continue;
        }
        receiver_type: any = rc.get("receiver_type");
        if not receiver_type {
            continue;
        }
        class_nid = _unique_class(`str(receiver_type));
        if class_nid is None {
            continue;
        }
        method_nid = method_index.get((class_nid, `str(callee)));
        if method_nid is None
            and ruby_context_complete
            and not unsafe_ruby_files
            and not external_method_owners
        {
            method_nid = _inherited_method(class_nid, `str(callee), "instance");
        }
        if method_nid is None {
            continue;
        }
        _emit(caller, method_nid, rc);
    }
}
