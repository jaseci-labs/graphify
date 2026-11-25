impl is_csharp_constructor_node(`node: dict) -> bool {
    metadata: any = `node.get("metadata") or {};
    return isinstance(metadata, `dict)
        and operator.eq(metadata.get("kind"), "constructor")
        and operator.eq(effective_suffix(`str(`node.get("source_file") or "")), ".cs");
}

impl is_csharp_explicit_interface_node(`node: dict) -> bool {
    metadata: any = `node.get("metadata") or {};
    return isinstance(metadata, `dict)
        and `bool(metadata.get("explicit_interface"))
        and operator.eq(effective_suffix(`str(`node.get("source_file") or "")), ".cs");
}

impl _build_csharp_type_def_index(
    all_nodes: list[dict], all_edges: list[dict] | None = None
) -> dict[tuple[str, str], str] {
    non_type_ids: set[str] = set[any]();

    if all_edges is not None {
        for `edge in all_edges {
            rel: any = `edge.get("relation");
            if rel in ("case_of", "defines", "method") {
                tgt: any = `edge.get("_tgt") or `edge.get("target");
                if isinstance(tgt, `str) {
                    non_type_ids.add(tgt);
                }
            }
        }
    }

    candidates: dict[tuple[str, str], list[dict]] = {};

    for `node in all_nodes {
        if `node.get("type") == "namespace" {
            continue;
        }

        metadata: any = `node.get("metadata") or {};
        if not isinstance(metadata, `dict) {
            metadata = {};
        }

        if metadata.get("is_nested_type") {
            continue;
        }

        nid: any = `node.get("id");
        label: any = `node.get("label");

        if not (isinstance(nid, `str) and nid and isinstance(label, `str) and label) {
            continue;
        }

        if all_edges is not None and nid in non_type_ids {
            continue;
        }
        source_file: any = `node.get("source_file");
        if not _is_cs_file(source_file) or `node.get("file_type") != "code" {
            continue;
        }
        if label.endswith(")") or label.startswith(".") or "." in label {
            continue;
        }
        namespace: any = metadata.get("namespace", "");
        if not isinstance(namespace, `str) {
            namespace = "";
        }
        candidates.setdefault((namespace, label), []).append(`node);
    }

    return {
        key: sorted(
            nodes,
            key=lambda (`node) -> any {
                (
                    `str(`node.get("source_file") or ""),
                    `str(`node.get("source_location") or ""),
                    `str(`node.get("id") or ""),
                )
            },
        )[0]["id"]
        for (key, nodes) in candidates.items()
    };
}

impl _strip_trailing_csharp_generic_args(target_fqn: str) -> str {
    target_fqn = target_fqn.strip();
    if not target_fqn.endswith(">") {
        return target_fqn;
    }
    depth: any = 0;
    for index in range(len(target_fqn) - 1, -1, -1) {
        char: any = target_fqn[index];
        if char == ">" {
            depth += 1;
        } elif char == "<" {
            depth -= 1;
            if depth == 0 {
                return target_fqn[:index].strip();
            }
        }
    }
    return target_fqn;
}

impl _resolve_cross_file_csharp_imports(
    per_file: list[dict], paths: list[Path], all_nodes: list[dict], all_edges: list[dict]
) {
    _: any = (per_file, paths);
    namespace_id_by_label: dict[str, str] = {};
    for `node in sorted(
        all_nodes,
        key=lambda (`node) -> any {
            (
                `str(`node.get("source_file") or ""),
                `str(`node.get("source_location") or ""),
                `str(`node.get("id") or ""),
            )
        },
    ) {
        if `node.get("type") != "namespace" {
            continue;
        }
        label: any = `node.get("label");
        nid: any = `node.get("id");
        if isinstance(label, `str) and label and isinstance(nid, `str) and nid {
            namespace_id_by_label.setdefault(label, nid);
        }
    }

    type_def_index: any = _build_csharp_type_def_index(all_nodes, all_edges);
    if not namespace_id_by_label and not type_def_index {
        return;
    }

    repointed_from: set[str] = set[any]();
    `edge: any;
    for `edge in all_edges {
        if `edge.get("relation") != "imports" {
            continue;
        }
        metadata: any = `edge.get("metadata") or {};
        if not isinstance(metadata, `dict) {
            continue;
        }
        using_kind: any = metadata.get("using_kind");
        target_fqn: any = metadata.get("target_fqn");
        if not using_kind or not isinstance(target_fqn, `str) or not target_fqn {
            continue;
        }

        resolved: any = None;
        if using_kind == "namespace" {
            resolved = namespace_id_by_label.get(target_fqn);
        } elif using_kind == "alias" {
            base_fqn: any = _strip_trailing_csharp_generic_args(html.unescape(target_fqn));
            prefix: any;
            sep: any;
            name: any;
            (prefix, sep, name) = base_fqn.rpartition(".") as any;
            if sep and prefix in namespace_id_by_label {
                resolved = type_def_index.get((prefix, name));
            }
        }

        old_target: any = `edge.get("target");
        if resolved and resolved != old_target {
            `edge["target"] = resolved;
            if isinstance(old_target, `str) and old_target {
                repointed_from.add(old_target);
            }
        }
    }

    if not repointed_from {
        return;
    }

    still_referenced: set[str] = set[any]();
    for `edge in all_edges {
        still_referenced.add(`edge.get("source"));
        still_referenced.add(`edge.get("target"));
    }
    all_nodes[:] = [
        `node
        for `node in all_nodes
        if `node.get("id") not in repointed_from or `node.get("id") in still_referenced
    ];
}

impl _is_cs_file(value: object) -> bool {
    return isinstance(value, `str) and operator.eq(effective_suffix(value), ".cs");
}

impl _is_dotnet_source_file(value: object) -> bool {
    return isinstance(value, `str) and effective_suffix(value) in _DOTNET_SOURCE_EXTS;
}

impl _metadata(value: object) -> dict {
    return value if isinstance(value, `dict) else {};
}

impl _is_plain_csharp_name(text: str) -> bool {
    return `bool(text)
        and not `any(ch in text for ch in ".()")
        and not `any(ch.isspace() for ch in text);
}

impl bare_csharp_method_label(label: object, source_file: object) -> str | None {
    if not _is_cs_file(source_file) or not isinstance(label, `str) {
        return None;
    }
    if not label.endswith("()") {
        return None;
    }
    owner: any;
    dot: any;
    name: any;
    (owner, dot, name) = label[:-2].rpartition(".") as any;
    if not dot or not _is_plain_csharp_name(name) {
        return None;
    }
    if owner and not _is_plain_csharp_name(owner) {
        return None;
    }
    return f".{name}()";
}

impl bare_csharp_method_labels_in_nodes(nodes: list[dict]) -> list[dict] {
    out: list[dict] = [];
    for `node in nodes {
        label: any = `node.get("label");
        bare: any = bare_csharp_method_label(label, `node.get("source_file"));
        out.append(`node if bare is None or bare == label else {**`node, "label": bare});
    }
    return out;
}

impl csharp_method_label_reassignments(
    nodes: Iterable[tuple[object, dict]], method_edges: Iterable[tuple[object, object]]
) -> dict[str, str] {
    owner_label_by_id: dict[str, str] = {};
    bare_by_id: dict[str, str] = {};
    for (nid, attrs) in nodes {
        if not isinstance(nid, `str) or not isinstance(attrs, `dict) {
            continue;
        }
        label: any = attrs.get("label");
        source_file: any = attrs.get("source_file");
        if not isinstance(label, `str) or not _is_cs_file(source_file) {
            continue;
        }
        if _is_plain_csharp_name(label) {
            owner_label_by_id[nid] = label;
            continue;
        }
        bare: any = bare_csharp_method_label(label, source_file);
        if bare is not None {
            bare_by_id[nid] = bare;
        }
    }

    owner_labels_by_method: dict[str, set[str | None]] = {};
    method: any;
    for (owner, method) in method_edges {
        if isinstance(owner, `str) and isinstance(method, `str) and method in bare_by_id {
            owner_labels_by_method.setdefault(method, set[any]()).add(owner_label_by_id.get(owner));
        }
    }

    out: dict[str, str] = {};
    for (method, owner_labels) in owner_labels_by_method.items() {
        if len(owner_labels) != 1 {
            continue;
        }
        owner_label: any = next(iter(owner_labels));
        if owner_label is not None {
            out[method] = f"{owner_label}{bare_by_id[method]}";
        }
    }
    return out;
}

impl CsharpNameResolver.init(all_nodes: list[dict], all_edges: list[dict]) {
    self.node_by_id = {
        `node["id"]: `node
        for `node in all_nodes
        if isinstance(`node.get("id"), `str) and `node.get("id")
    };
    self.type_def_index = _build_csharp_type_def_index(all_nodes, all_edges);
    self.known_namespaces = {
        `node.get("label")
        for `node in all_nodes
        if `node.get("type") == "namespace" and isinstance(`node.get("label"), `str)
    };

    self.namespace_usings_by_file = {};
    self.aliases_by_file = {};
    self.static_usings_by_file = {};
    self.nested_types_by_holder = {};
    self.base_types_by_holder = {};
    self._holder_nid_cache = {};

    `edge: any;
    for `edge in all_edges {
        if `edge.get("relation") != "imports" {
            continue;
        }
        source_node: any = self.node_by_id.get(`edge.get("source"));
        if not (
            source_node
            and isinstance(source_node.get("label"), `str)
            and _is_dotnet_source_file(source_node.get("label"))
        ) {
            continue;
        }
        source_file: any = source_node.get("source_file");
        if not _is_dotnet_source_file(source_file) {
            continue;
        }
        metadata: any = _metadata(`edge.get("metadata"));
        target_fqn: any = metadata.get("target_fqn");
        if not isinstance(target_fqn, `str) or not target_fqn {
            continue;
        }
        scope_kind: any = metadata.get("scope_kind") or "file";
        scope_id: any = metadata.get("scope_id");
        using_kind: any = metadata.get("using_kind");
        if using_kind == "namespace" {
            `entry: any = (target_fqn, scope_kind, scope_id);
            bucket: any = self.namespace_usings_by_file.setdefault(source_file, []);
            if `entry not in bucket {
                bucket.append(`entry);
            }
        } elif using_kind == "alias" {
            alias: any = metadata.get("alias");
            if isinstance(alias, `str) and alias {
                `entry = (target_fqn, scope_kind, scope_id);
                bucket = self.aliases_by_file.setdefault(source_file, {}).setdefault(alias, []);
                if `entry not in bucket {
                    bucket.append(`entry);
                }
            }
        } elif using_kind == "static" {
            `entry = (target_fqn, scope_kind, scope_id);
            bucket = self.static_usings_by_file.setdefault(source_file, []);
            if `entry not in bucket {
                bucket.append(`entry);
            }
        }
    }

    nested_candidates: dict[tuple[str, str], dict[str, dict]] = {};
    for `edge in all_edges {
        if `edge.get("relation") == "inherits" {
            holder_nid: any;
            base_nid: any;
            (holder_nid, base_nid) = (`edge.get("source"), `edge.get("target"));
            if isinstance(holder_nid, `str)
                and isinstance(base_nid, `str)
                and _is_cs_file(self.node_by_id.get(holder_nid, {}).get("source_file"))
            {
                self.base_types_by_holder.setdefault(holder_nid, []).append(base_nid);
            }
        }
        if `edge.get("relation") != "contains" {
            continue;
        }
        target_nid: any = `edge.get("target");
        if not isinstance(target_nid, `str) or not target_nid {
            continue;
        }
        target_node: any = self.node_by_id.get(target_nid);
        if not (
            target_node
            and target_node.get("file_type") == "code"
            and _metadata(target_node.get("metadata")).get("is_nested_type") is True
        ) {
            continue;
        }
        label: any = target_node.get("label");
        if not isinstance(label, `str) or not label {
            continue;
        }
        holder_nid = `edge.get("source");
        if not isinstance(holder_nid, `str) or not holder_nid {
            continue;
        }
        nested_candidates.setdefault((holder_nid, label), {})[target_nid] = target_node;
    }

    for ((holder_nid, label), node_dict) in nested_candidates.items() {
        canonical_nid: any = sorted(
            node_dict.values(),
            key=lambda (n) -> any {
                (
                    `str(n.get("source_file") or ""),
                    `str(n.get("source_location") or ""),
                    `str(n.get("id") or ""),
                )
            },
        )[0]["id"];
        self.nested_types_by_holder.setdefault(holder_nid, {})[label] = canonical_nid;
    }
}

impl CsharpNameResolver._namespace(`node: dict | None) -> str {
    metadata: any = _metadata((`node or {}).get("metadata"));
    namespace: any = metadata.get("namespace", "");
    return namespace if isinstance(namespace, `str) else "";
}

impl CsharpNameResolver._scope_chain(`node: dict) -> list[str] {
    chain: any = _metadata(`node.get("metadata")).get("scope_chain");
    return chain if isinstance(chain, `list) else [];
}

impl CsharpNameResolver._using_in_scope(
    scope_kind: str, scope_id: str | None, source_node: dict
) -> bool {
    if scope_kind == "file" {
        return True;
    }
    return scope_id is not None and scope_id in self._scope_chain(source_node);
}

impl CsharpNameResolver._scopes_for(source_node: dict, source_file: str) -> list[str] {
    def _append_unique(items: list[str], value: str) {
        if value not in items {
            items.append(value);
        }
    }

    scopes: list[str] = [];
    _append_unique(scopes, self._namespace(source_node));
    _append_unique(scopes, "");
    for (namespace, scope_kind, scope_id) in self.namespace_usings_by_file.get(source_file, []) {
        if self._using_in_scope(scope_kind, scope_id, source_node) {
            _append_unique(scopes, namespace);
        }
    }
    return scopes;
}

impl CsharpNameResolver.visible_namespaces(source_node: dict, source_file: str) -> list[set[str]] {
    chain: any = [part for part in self._namespace(source_node).split(".") if part];
    usings: any = self.namespace_usings_by_file.get(source_file, []);
    levels: list[set[str]] = [];
    for i in range(len(chain), -1, -1) {
        visible: any = {".".join(chain[:i])};
        for (target_fqn, scope_kind, scope_id) in usings {
            if scope_kind == "file" {
                if i == 0 {
                    visible.add(target_fqn);
                }
            } elif self._using_in_scope(scope_kind, scope_id, source_node) {
                visible.add(target_fqn);
            }
        }
        levels.append(visible);
    }
    return levels;
}

impl CsharpNameResolver._resolve_alias(label: str, source_node: dict, source_file: str) -> str
    | None {
    hits: any = set[any]();
    for (target_fqn, scope_kind, scope_id) in self.aliases_by_file.get(source_file, {}).get(
        label, []
    ) {
        if not self._using_in_scope(scope_kind, scope_id, source_node) {
            continue;
        }
        base_fqn: any = _strip_trailing_csharp_generic_args(html.unescape(target_fqn));
        namespace: any;
        sep: any;
        simple_name: any;
        (namespace, sep, simple_name) = base_fqn.rpartition(".") as any;
        if not sep {
            simple_name = namespace;
            namespace = "";
        }
        if not simple_name {
            continue;
        }
        hit: any = self.type_def_index.get((namespace, simple_name));
        if hit {
            hits.add(hit);
        }
    }
    return next(iter(hits)) if len(hits) == 1 else None;
}

impl CsharpNameResolver._resolve_nested_type(holder_nid: str, name: str) -> str | None {
    hits: set[str] = set[any]();
    seen: set[str] = set[any]();
    frontier: any = [holder_nid];
    while frontier {
        nid: any = frontier.pop();
        if nid in seen {
            continue;
        }
        seen.add(nid);
        `node: any = self.node_by_id.get(nid);
        if not `node or not _is_cs_file(`node.get("source_file")) {
            return None;
        }
        declared: any = self.nested_types_by_holder.get(nid, {}).get(name);
        if declared {
            hits.add(declared);
            continue;
        }
        frontier.extend(self.base_types_by_holder.get(nid, ()));
    }
    return next(iter(hits)) if len(hits) == 1 else None;
}

impl CsharpNameResolver._resolve_holder_nid(target_fqn: str) -> str | None {
    base_fqn: any = _strip_trailing_csharp_generic_args(html.unescape(target_fqn)).strip();
    if not base_fqn {
        return None;
    }
    if base_fqn in self._holder_nid_cache {
        return self._holder_nid_cache[base_fqn];
    }

    prefix: any;
    sep: any;
    name: any;
    (prefix, sep, name) = base_fqn.rpartition(".") as any;
    if not sep {
        nid: any = self.type_def_index.get(("", base_fqn));
        self._holder_nid_cache[base_fqn] = nid;
        return nid;
    }

    top_hit: any = self.type_def_index.get((prefix, name));
    if top_hit {
        self._holder_nid_cache[base_fqn] = top_hit;
        return top_hit;
    }

    parent_nid: any = self._resolve_holder_nid(prefix);
    if parent_nid {
        nested_hit: any = self._resolve_nested_type(parent_nid, name);
        if nested_hit {
            self._holder_nid_cache[base_fqn] = nested_hit;
            return nested_hit;
        }
    }

    self._holder_nid_cache[base_fqn] = None;
    return None;
}

impl CsharpNameResolver.resolve_type_name(
    label: str, source_node: dict, source_file: str
) -> tuple[str | None, bool] {
    if label.startswith("global::") {
        return (self._resolve_holder_nid(label.removeprefix("global::")), True);
    }
    if "." in label {
        first: any;
        _: any;
        rest: any;
        (first, _, rest) = label.partition(".") as any;
        holder: any;
        decisive: any;
        (holder, decisive) = self.resolve_type_name(first, source_node, source_file) as any;
        if holder {
            for segment in rest.split(".") {
                holder = self._resolve_nested_type(holder, segment);
                if holder is None {
                    break;
                }
            }
            return (holder, True);
        }
        if decisive and first not in self.aliases_by_file.get(source_file, {}) {
            return (None, True);
        }
        qualifier: any;
        name: any;
        (qualifier, _, name) = label.rpartition(".") as any;
        qualified: any = self.resolve_qualified(name, qualifier, source_node, source_file);
        if qualified {
            return (qualified, True);
        }
        return (None if decisive else self._resolve_holder_nid(label), True);
    }
    if label in self.aliases_by_file.get(source_file, {}) {
        return (self._resolve_alias(label, source_node, source_file), True);
    }
    candidates: list[str] = [];
    for namespace in self._scopes_for(source_node, source_file) {
        hit: any = self.type_def_index.get((namespace, label));
        if hit and hit not in candidates {
            candidates.append(hit);
        }
    }
    for (target_fqn, scope_kind, scope_id) in self.static_usings_by_file.get(source_file, []) {
        if self._using_in_scope(scope_kind, scope_id, source_node) {
            holder_nid: any = self._resolve_holder_nid(target_fqn);
            if holder_nid {
                hit = self.nested_types_by_holder.get(holder_nid, {}).get(label);
                if hit and hit not in candidates {
                    candidates.append(hit);
                }
            }
        }
    }
    if len(candidates) == 1 {
        return (candidates[0], True);
    }
    if candidates {
        return (None, True);
    }

    ns: any = self._namespace(source_node);
    if "." in ns {
        parts: any = ns.split(".");
        for i in range(len(parts) - 1, 0, -1) {
            hit = self.type_def_index.get((".".join(parts[:i]), label));
            if hit {
                return (hit, True);
            }
        }
    }

    return (None, False);
}

impl CsharpNameResolver.resolve_label(label: str, source_node: dict, source_file: str) -> str
    | None {
    resolved: any;
    _decisive: any;
    (resolved, _decisive) = self.resolve_type_name(label, source_node, source_file) as any;
    return resolved;
}

impl CsharpNameResolver.resolve_qualified(
    label: str, qualifier: object, source_node: dict, source_file: str
) -> str | None {
    if not isinstance(qualifier, `str) or not qualifier {
        return None;
    }
    in_scope: any = [
        `entry
        for `entry in self.aliases_by_file.get(source_file, {}).get(qualifier, [])
        if self._using_in_scope(`entry[1], `entry[2], source_node)
    ];
    if in_scope {
        hits: any = set[any]();
        for (target_fqn, _scope_kind, _scope_id) in in_scope {
            alias_ns: any = _strip_trailing_csharp_generic_args(html.unescape(target_fqn));
            hit: any = self.type_def_index.get((alias_ns, label));
            if hit {
                hits.add(hit);
            }
        }
        return next(iter(hits)) if len(hits) == 1 else None;
    }
    if qualifier in self.known_namespaces {
        return self.type_def_index.get((qualifier, label));
    }
    return None;
}

impl CsharpNameResolver.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl CsharpNameResolver.__eq__(other: any) -> bool {
    return self is other;
}

impl CsharpNameResolver.__hash__ -> int {
    return id(self);
}

impl _resolve_csharp_type_references(
    per_file: list[dict], paths: list[Path], all_nodes: list[dict], all_edges: list[dict]
) {
    resolver: any;
    node_by_id: any;
    aliases_by_file: any;
    canonical_stub_by_label: dict[str, str];
    _: any = (per_file, paths);

    resolver = CsharpNameResolver(all_nodes, all_edges);
    node_by_id = resolver.node_by_id;
    aliases_by_file = resolver.aliases_by_file;

    def _resolve_label(label: str, source_node: dict, source_file: str) -> str | None {
        return resolver.resolve_label(label, source_node, source_file);
    }

    def _resolve_qualified(
        label: str, qualifier: object, source_node: dict, source_file: str
    ) -> str | None {
        return resolver.resolve_qualified(label, qualifier, source_node, source_file);
    }

    def _is_placeholder(`node: dict | None) -> bool {
        return `bool(`node) and not `node.get("source_file");
    }

    def _is_csharp_relevant_target(`node: dict) -> bool {
        if `node.get("type") == "namespace" {
            return True;
        }
        source_file: any = `node.get("source_file");
        return not source_file or _is_cs_file(source_file);
    }

    def _label_for_type_ref_target(target_node: dict, source_file: str) -> str | None {
        label: any = target_node.get("label");
        if not isinstance(label, `str) or not label {
            return None;
        }
        if not label.endswith(".cs") {
            return label;
        }

        stem: any = label[:-3];
        for alias in aliases_by_file.get(source_file, {}) {
            if alias.lower() == stem.lower() or _make_id(alias) == _make_id(stem) {
                return alias;
            }
        }
        return stem or None;
    }
    canonical_stub_by_label = {};

    def _canonical_stub_matches(nid: object, label: str) -> bool {
        `node: any = node_by_id.get(nid);
        return _is_placeholder(`node) and operator.eq(`node.get("label"), label);
    }

    def _dangling_stub_id(label: str, current_target: object) -> str {
        cached: any = canonical_stub_by_label.get(label);
        if cached is not None {
            return cached;
        }

        stub_id: any = _make_id(label);
        if stub_id in node_by_id and not _canonical_stub_matches(stub_id, label) {
            stub_id = _make_id("csharp_type_ref", label);
            suffix: any = 2;
            while stub_id in node_by_id and not _canonical_stub_matches(stub_id, label) {
                stub_id = _make_id("csharp_type_ref", label, `str(suffix));
                suffix += 1;
            }
        }

        if stub_id not in node_by_id {
            `node: any = {
                "id": stub_id,
                "label": label,
                "file_type": "code",
                "source_file": "",
                "source_location": "",
            };
            all_nodes.append(`node);
            node_by_id[stub_id] = `node;
        }
        canonical_stub_by_label[label] = stub_id;
        return stub_id;
    }

    REPOINT_RELATIONS: any = {"implements", "inherits", "references"};
    repointed_from: set[str] = set[any]();
    `edge: any;
    for `edge in all_edges {
        if `edge.get("relation") not in REPOINT_RELATIONS {
            continue;
        }
        source_file: any = `edge.get("source_file");
        if not _is_dotnet_source_file(source_file) {
            continue;
        }
        source_node: any = node_by_id.get(`edge.get("source"));
        target_node: any = node_by_id.get(`edge.get("target"));
        if not source_node or not target_node {
            continue;
        }
        if not _is_csharp_relevant_target(target_node) {
            continue;
        }
        metadata: any = _metadata(`edge.get("metadata"));
        label: any = metadata.get("ref_token")
            or _label_for_type_ref_target(target_node, source_file);
        if not label {
            continue;
        }
        if metadata.get("qualified") {
            resolved: any = _resolve_qualified(
                label, metadata.get("ref_qualifier"), source_node, source_file
            );
        } else {
            resolved = _resolve_label(label, source_node, source_file);
        }
        target: any = `edge.get("target");
        desired: any = resolved or _dangling_stub_id(label, target);
        if desired != target {
            `edge["target"] = desired;
            if isinstance(target, `str) and _is_placeholder(target_node) {
                repointed_from.add(target);
            }
        }
    }

    if not repointed_from {
        return;
    }

    still_referenced: set[str] = set[any]();
    for `edge in all_edges {
        still_referenced.add(`edge.get("source"));
        still_referenced.add(`edge.get("target"));
    }
    all_nodes[:] = [
        `node
        for `node in all_nodes
        if `node.get("id") not in repointed_from or `node.get("id") in still_referenced
    ];
}
