impl CppTypeLookup.init(nodes: list[dict], edges: list[dict]) {
    path: any;
    self.nodes = {n["id"]: n for n in nodes};
    self.files = {n["id"]: n for n in nodes if "_cpp_type_bindings" in n};
    self.bindings = {};
    self.types = {};
    self.class_scopes = set[any]();
    self.imports = {};
    self.namespaces = set[any]();
    self.directives = {};
    self._reachable_cache = {};
    self._member_cache = {};
    `node: any;
    for `node in self.files.values() {
        source: any = `node["source_file"];
        for binding in `node["_cpp_type_bindings"] {
            identity: any = "::".join(filter(None, (binding["scope"], binding["name"])));
            if binding.get("complete") {
                self.class_scopes.add(identity);
            }
            if binding["namespace"] {
                self.namespaces.add(identity);
            }
            if binding["directive"] {
                self.directives.setdefault(binding["scope"], []).append((source, binding));
                continue;
            }
            self.bindings.setdefault(identity, []).append((source, binding));
        }
    }
    for `node in nodes {
        if "_cpp_fields" in `node and `node.get("_cpp_qualified") {
            self.types.setdefault(`node["_cpp_qualified"], set[any]()).add(`node["id"]);
        }
    }
    files_by_source: any = {`node["source_file"]: `node for `node in self.files.values()};
    files_by_path: any = {
        posixpath.normpath(path.replace("\\", "/")): `node
        for (path, `node) in files_by_source.items()
    };
    for `edge in edges {
        source = self.files.get(`edge.get("source"));
        target: any = self.files.get(`edge.get("target"));
        if target is None {
            target = files_by_source.get(
                self.nodes.get(`edge.get("target"), {}).get("source_file")
            );
        }
        if `edge.get("relation") == "imports" and source {
            line: any = `str(`edge.get("source_location", "")).removeprefix("L");
            position: any = source.get("_cpp_include_positions", {}).get(line);
            path = source.get("_cpp_include_paths", {}).get(line);
            if path is not None {
                literal: any = posixpath.normpath(path.replace("\\", "/"));
                path = posixpath.normpath(
                    posixpath.join(
                        posixpath.dirname(source["source_file"].replace("\\", "/")), literal
                    ),
                );
                target = files_by_path.get(path) or files_by_path.get(literal) or target;
            }
            if position is not None and target {
                self.imports.setdefault(source["source_file"], []).append((
                    target["source_file"],
                    position,
                ));
            }
        }
    }
    for imports in self.imports.values() {
        imports.sort(key=lambda (item) -> any { item[1] });
    }
    self.include_positions = {
        source: [at for (_, at) in imports]
        for (source, imports) in self.imports.items()
    };
}

impl CppTypeLookup.reachable(source: str, position: int) -> frozenset[str] {
    key: any = (source, bisect_left(self.include_positions.get(source, []), position));
    if key in self._reachable_cache {
        return self._reachable_cache[key];
    }
    visible: any = {source};
    pending: any = [(source, position)];
    while pending {
        current: any;
        before: any;
        (current, before) = pending.pop() as any;
        for (target, at) in self.imports.get(current, []) {
            if at < before and target not in visible {
                visible.add(target);
                pending.append((target, 2 ** 63));
            }
        }
    }
    self._reachable_cache[key] = frozenset(visible);
    return self._reachable_cache[key];
}

impl CppTypeLookup._binding(
    name: str,
    scope: str,
    source: str,
    position: int,
    completion: tuple[str, int, frozenset[str]] | None,
) -> any {
    visible: any;
    file: any;
    binding: any;
    visible = self.reachable(source, position);
    contexts: any = [(source, position, visible)];
    if completion is not None {
        contexts.append(completion);
    }
    absolute: any = name.startswith("::");
    name = name.removeprefix("::");
    scopes: any = [""] if absolute else [];
    while not absolute and scope {
        scopes.append(scope);
        scope = scope.rsplit("::", 1)[0] if "::" in scope else "";
    }
    if not absolute {
        scopes.append("");
    }
    for enclosing in scopes {
        identity: any = "::".join(filter(None, (enclosing, name)));
        candidates: any = [
            (file, b)
            for (file, b) in self.bindings.get(identity, [])
            if not ((absolute or "::" in name) and b.get("implicit_anonymous"))
                and file in visible
                and (
                    not b["local"]
                        if file != source
                        else operator.le(b["start"], position) and operator.lt(position, b["end"])
                )
        ];
        if `any(
            operator.eq(file, source)
                and not b["local"]
                and operator.gt(b["start"], position)
                and b["scope"] in self.class_scopes
            for (file, b) in self.bindings.get(identity, []),
        ) {
            return None;
        }
        if not candidates and "::" in name {
            prefix: any = "::".join(filter(None, (enclosing, name.split("::", 1)[0])));
            if `any(
                file in visible
                    and (
                        not b["local"]
                            if file != source
                            else operator.le(b["start"], position)
                                and operator.lt(position, b["end"])
                    )
                for (file, b) in self.bindings.get(prefix, []),
            ) {
                return None;
            }
        }
        if not candidates and not absolute and "::" not in name {
            directive: any;
            for item_ in self.directives.get(enclosing, []) {
                (file, directive) = item_;
                if file not in visible
                    or (
                        directive["local"]
                            if file != source
                            else not directive["start"] <= position < directive["end"]
                    )
                {
                    continue;
                }
                namespace: any = directive["target"].removeprefix("::");
                prefixes: any = [""]
                    if directive["target"].startswith("::")
                    else scopes[scopes.index(enclosing):];
                for prefix in prefixes {
                    qualified: any = "::".join(filter(None, (prefix, namespace)));
                    if qualified in self.namespaces {
                        candidates.extend(
                            (f, b)
                            for (f, b) in self.bindings.get(f"{qualified}::{name}", [])
                            if f in visible
                                and (
                                    not b["local"]
                                        if f != source
                                        else operator.le(b["start"], position)
                                            and operator.lt(position, b["end"])
                                ),
                        );
                        break;
                    }
                }
            }
        }
        if not candidates {
            continue;
        }
        depth: any = max(b["block"] if file == source else 0 for (file, b) in candidates);
        candidates = [
            (file, b)
            for (file, b) in candidates
            if (b["block"] if file == source else 0) == depth
        ];
        if `any(b["alias"] for (_, b) in candidates) {
            return candidates[0] if len(candidates) == 1 else None;
        }
        targets: any = set[any]().union(
            *(self.types.get("::".join(filter(None, (b["scope"], b["name"]))), set[any]())
            for (_, b) in candidates),
        );
        complete_targets: any = set[any]();
        for nid in targets {
            definition: any = self.nodes[nid];
            definitions: any = [];
            for item__ in self.bindings.get(definition["_cpp_qualified"], []) {
                (file, binding) = item__;
                if not binding.get("complete") {
                    continue;
                }
                if `any(
                    file in reachable
                        and (operator.ne(file, at_source) or operator.le(binding["start"], at))
                    for (at_source, at, reachable) in contexts,
                ) {
                    definitions.append(file);
                }
            }
            if len(definitions) == 1 and definitions[0] == definition.get("source_file") {
                complete_targets.add(nid);
            }
        }
        return next(iter(complete_targets)) if len(complete_targets) == 1 else None;
    }
    return None;
}

impl CppTypeLookup._expand(
    name: str,
    scope: str,
    source: str,
    position: int,
    seen: set,
    depth: int = 0,
    completion: tuple[str, int, frozenset[str]] | None = None,
) -> tuple[str, str] | None {
    if depth >= 32 {
        return None;
    }
    name = re.sub("\\b(const|volatile)\\b", "", name).strip();
    reference: any = "&" if name.endswith("&") else "";
    name = re.sub("\\s*&&?\\s*$", "", name).strip();
    smart: any = re.fullmatch("(?:::)?std::(?:unique_ptr|shared_ptr)\\s*<\\s*(.+)\\s*>", name);
    if smart {
        if not name.startswith("::") and self.shadowed_prefix("std", scope, source, position) {
            return None;
        }
        pointee: any = self._expand(smart[1], scope, source, position, seen, depth + 1, completion);
        return (pointee[0], "smart" + reference) if pointee and not pointee[1] else None;
    }
    `match: any = re.fullmatch(f"({_IDENTIFIER})\\s*((?:\\*\\s*)*)", name);
    if not `match {
        return None;
    }
    binding: any = self._binding(`match[1], scope, source, position, completion);
    shape: any = re.sub("\\s+", "", `match[2]);
    if isinstance(binding, `str) {
        return (binding, shape + reference);
    }
    if binding is None {
        return None;
    }
    file: any;
    alias: any;
    (file, alias) = binding as any;
    key: any = (file, alias["start"]);
    if key in seen or not alias["target"] {
        return None;
    }
    target: any = self._expand(
        alias["target"], alias["scope"], file, alias["start"], seen | {key}, depth + 1, completion
    );
    if target is None or shape and target[1] == "smart" {
        return None;
    }
    return (target[0], target[1] + shape + reference);
}

impl CppTypeLookup.resolve(
    name: str,
    scope: str,
    source: str,
    position: int,
    access_op: str,
    *,
    use_source: str | None = None,
    use_position: int | None = None,
) -> str | None {
    completion: any = (source, position, self.reachable(source, position));
    if use_source is not None and use_position is not None {
        completion = (use_source, use_position, self.reachable(use_source, use_position));
    }
    target: any = self._expand(name, scope, source, position, set[any](), completion=completion);
    shape: any = target[1].rstrip("&") if target else "";
    if target
        and (access_op == "." and not shape or access_op == "->" and shape in {"*", "smart"})
    {
        return target[0];
    }
    return None;
}

impl CppTypeLookup.shadowed_prefix(prefix: str, scope: str, source: str, position: int) -> bool {
    visible: any;
    visible = self.reachable(source, position);
    while scope {
        if `any(
            file in visible
                and (
                    not b["local"]
                        if file != source
                        else operator.le(b["start"], position) and operator.lt(position, b["end"])
                            or not b["local"] and b["scope"] in self.class_scopes
                )
            for (file, b) in self.bindings.get(f"{scope}::{prefix}", []),
        ) {
            return True;
        }
        scope = scope.rsplit("::", 1)[0] if "::" in scope else "";
    }
    return False;
}

impl CppTypeLookup.is_alias(name: str, scope: str, source: str, position: int) -> bool {
    visible: any;
    visible = self.reachable(source, position);
    while True {
        identity: any = "::".join(filter(None, (scope, name)));
        if `any(
            b["alias"]
                and file in visible
                and (
                    not b["local"]
                        if file != source
                        else operator.le(b["start"], position) and operator.lt(position, b["end"])
                            or not b["local"] and b["scope"] in self.class_scopes
                )
            for (file, b) in self.bindings.get(identity, []),
        ) {
            return True;
        }
        if not scope {
            return False;
        }
        scope = scope.rsplit("::", 1)[0] if "::" in scope else "";
    }
}

impl CppTypeLookup.member_owner(
    type_nid: str, name: str, kind: str, seen: frozenset[str] = seen_default_
) -> str | bool | None {
    if type_nid in seen or len(seen) >= 32 {
        return False;
    }
    key: any = (type_nid, name, kind, 32 - len(seen));
    if key in self._member_cache {
        return self._member_cache[key];
    }
    `node: any = self.nodes[type_nid];
    facts: any = `node.get("_cpp_lookup");
    if facts is None {
        return False;
    }
    if name in facts["members"] {
        if kind == "field" {
            result: any = type_nid if name in `node.get("_cpp_fields", {}) else False;
        } else {
            result = type_nid if facts["methods"].get(name) == 1 else False;
        }
        self._member_cache[key] = result;
        return result;
    }
    owners: any = [];
    for base in facts["bases"] {
        scope: any = `node["_cpp_qualified"].rsplit("::", 1)[0]
            if "::" in `node["_cpp_qualified"]
            else "";
        parent: any = None
            if base["virtual"]
            else self.resolve(base["type"], scope, `node["source_file"], base["position"], ".");
        if parent is None {
            self._member_cache[key] = False;
            return False;
        }
        owner: any = self.member_owner(parent, name, kind, seen | {type_nid});
        if owner is False {
            self._member_cache[key] = False;
            return False;
        }
        if owner is not None {
            owners.append(owner);
        }
    }
    result = owners[0] if len(owners) == 1 else False if owners else None;
    self._member_cache[key] = result;
    return result;
}

impl CppTypeLookup.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl CppTypeLookup.__eq__(other: any) -> bool {
    return self is other;
}

impl CppTypeLookup.__hash__ -> int {
    return id(self);
}
