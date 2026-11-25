impl extract_elixir(path: Path) -> dict {
    source: any;
    `root: any;
    stem: any;
    str_path: any;
    nodes: list[dict];
    edges: list[dict];
    seen_ids: set[str];
    function_bodies: list[tuple[str, Any]];
    file_nid: any;
    call_scope: dict[str | None, list[str]];
    enclosing: dict[str, str | None];
    module_names: dict[str, str];
    aliases: dict[str | None, dict[str, str]];
    module_defs: dict[tuple[str, str], str];
    _IMPORT_KEYWORDS: any;
    def_groups: dict[tuple[str, int, int], dict[str, set[str]]];
    module_nid_by_name: any;
    _MODULE_REF: any;
    seen_call_pairs: set[tuple[str, str]];
    raw_calls: list[dict];
    _SKIP_KEYWORDS: any;
    try {
        import tree_sitter_elixir as tselixir;
        import from tree_sitter { Language, Parser }
    } except ImportError {
        return {"nodes": [], "edges": [], "error": "tree_sitter_elixir not installed"};
    }

    try {
        language: any = Language(tselixir.language());
        parser: any = Parser(language);
        source = _read_source_bytes(path);
        tree: any = parser.parse(source);
        `root = tree.root_node;
    } except Exception as e {
        return {"nodes": [], "edges": [], "error": `str(e)};
    }

    stem = _file_stem(path);
    str_path = `str(path);
    nodes = [];
    edges = [];
    seen_ids = set[any]();
    function_bodies = [];

    def add_node(nid: str, label: str, line: int, **attrs) -> None {
        if nid not in seen_ids {
            seen_ids.add(nid);
            `node: any = {
                "id": nid,
                "label": label,
                "file_type": "code",
                "source_file": str_path,
                "source_location": f"L{line}",
            };
            `node.update(attrs);
            nodes.append(`node);
        }
    }

    def add_edge(
        src: str,
        tgt: str,
        relation: str,
        line: int,
        confidence: str = "EXTRACTED",
        weight: float = 1.0,
        context: str | None = None,
    ) -> None {
        `edge: any = {
            "source": src,
            "target": tgt,
            "relation": relation,
            "confidence": confidence,
            "source_file": str_path,
            "source_location": f"L{line}",
            "weight": weight,
        };
        if context {
            `edge["context"] = context;
        }
        edges.append(`edge);
    }

    file_nid = _make_id(`str(path));
    add_node(file_nid, path.name, 1);
    call_scope = {};
    enclosing = {};
    module_names = {};
    aliases = {};
    module_defs = {};

    _IMPORT_KEYWORDS = frozenset({"alias", "import", "require", "use"});

    def _get_alias_text(`node) -> str | None {
        for child in `node.children {
            if child.type == "alias" {
                return source[child.start_byte:child.end_byte].decode("utf-8", errors="replace");
            }
        }
        return None;
    }

    """Every module named by an alias/import/require/use argument.

        Handles the single form (``alias Foo.Bar`` -> ``["Foo.Bar"]``) and the
        multi-alias brace form (``alias Foo.{Bar, Baz}`` ->
        ``["Foo.Bar", "Foo.Baz"]``), which the grammar represents as a ``dot``
        node holding the base alias and a trailing ``tuple`` of member aliases.
        """
    def _get_alias_modules(`node) -> list[str] {
        def _text(n) -> str {
            return source[n.start_byte:n.end_byte].decode("utf-8", errors="replace");
        }

        for child in `node.children {
            if child.type == "alias" {
                return [_text(child)];
            }
            if child.type == "dot" {
                base: any = None;
                tuple_node: any = None;
                for sub in child.children {
                    if sub.type == "alias" and base is None {
                        base = _text(sub);
                    } elif sub.type == "tuple" {
                        tuple_node = sub;
                    }
                }
                if base and tuple_node is not None {
                    members: any = [_text(m) for m in tuple_node.children if m.type == "alias"];
                    if members {
                        return [f"{base}.{m}" for m in members];
                    }
                }
                return [_text(child)];
            }
        }
        return [];
    }

    """The module given for keyword ``key`` in an argument list, e.g. the
        `for:` of `defimpl Proto, for: Type` or the `as:` of `alias A.B, as: C`.
        The grammar holds it in a trailing `keywords` node as a `pair` whose
        keyword is `key:` and whose value is an `alias`."""
    def _get_keyword_alias(`node, key: str) -> str | None {
        for child in `node.children {
            if child.type != "keywords" {
                continue;
            }
            for pair in child.children {
                if pair.type != "pair" {
                    continue;
                }
                kw: any = None;
                val: any = None;
                for sub in pair.children {
                    if sub.type == "keyword" {
                        kw = source[sub.start_byte:sub.end_byte].decode("utf-8", errors="replace");
                    } elif sub.type == "alias" {
                        val = source[sub.start_byte:sub.end_byte].decode("utf-8", errors="replace");
                    }
                }
                if kw and kw.rstrip(": ").strip() == key and val {
                    return val;
                }
            }
        }
        return None;
    }

    """Expand the first segment of a module reference through the `alias`
        tables visible from ``scope`` (or `__MODULE__` to the current module)."""
    def _expand_module(name: str, scope: str | None) -> str {
        first: any;
        _: any;
        rest: any;
        (first, _, rest) = name.partition(".") as any;
        target: any = None;
        if first == "__MODULE__" {
            if scope is not None and scope not in module_names {
                scope = enclosing.get(scope);
            }
            target = (module_names.get(scope) if scope is not None else None) or None;
        } else {
            seen: set[str | None] = set[any]();
            container: any = scope;
            while container not in seen {
                seen.add(container);
                target = aliases.get(container, {}).get(first);
                if target is not None or container is None {
                    break;
                }
                container = enclosing.get(container);
            }
        }
        if target is None {
            return name;
        }
        return f"{target}.{rest}" if rest else target;
    }

    def _record_aliases(arguments_node, scope: str | None) -> None {
        modules: any = [_expand_module(m, scope) for m in _get_alias_modules(arguments_node)];
        as_name: any = _get_keyword_alias(arguments_node, "as");
        table: any = aliases.setdefault(scope, {});
        if as_name and len(modules) == 1 {
            table[as_name] = modules[0];
        } elif not as_name {
            for module in modules {
                table[module.rsplit(".", 1)[-1]] = module;
            }
        }
    }

    def _register_module(nid: str, name: str, parent: str | None) -> None {
        parent_name: any = module_names.get(parent) if parent is not None else None;
        if parent_name {
            first: any = name.split(".", 1)[0];
            aliases.setdefault(parent, {})[first] = f"{parent_name}.{first}";
            name = f"{parent_name}.{name}";
        }
        module_names[nid] = name;
    }
    """The body of a keyword-form definition (`def f(x), do: expr`).

        tree-sitter-elixir puts the keyword body in the `arguments` node's
        trailing `keywords` child, as the value of the `pair` whose keyword
        is `do:` (#4207). Returns the value node, or None when the definition
        uses a `do_block` (or has no keyword body at all).
        """
    def _get_do_keyword_body(`node) -> any {
        if `node is None {
            return None;
        }
        for child in `node.children {
            if child.type != "keywords" {
                continue;
            }
            for pair in child.children {
                if pair.type != "pair" {
                    continue;
                }
                keyword_text: any = None;
                for sub in pair.children {
                    if sub.type == "keyword" {
                        keyword_text = source[sub.start_byte:sub.end_byte].decode(
                            "utf-8", errors="replace"
                        );
                    } elif keyword_text is not None and keyword_text.rstrip(": ").strip() == "do" {
                        return sub;
                    }
                }
            }
        }
        return None;
    }

    def _call_keyword(`node) -> str | None {
        for child in `node.children {
            if child.type == "identifier" {
                return source[child.start_byte:child.end_byte].decode("utf-8", errors="replace");
            }
        }
        return None;
    }

    def _def_name(arguments_node) -> str | None {
        child: any;
        for child in arguments_node.children {
            while child.type == "binary_operator" {
                head: any = None;
                sub: any;
                for sub in child.children {
                    if sub.type in ("call", "identifier", "binary_operator") {
                        head = sub;
                        break;
                    }
                }
                if head is None {
                    break;
                }
                child = head;
            }
            if child.type == "call" {
                for sub in child.children {
                    if sub.type == "identifier" {
                        return source[sub.start_byte:sub.end_byte].decode(
                            "utf-8", errors="replace"
                        );
                    }
                }
            } elif child.type == "identifier" {
                return source[child.start_byte:child.end_byte].decode("utf-8", errors="replace");
            }
        }
        return None;
    }
    def_groups = {};

    """Id for a def, salted when a sibling def differs only by `_`/case/`!`/`?`.

        ``make_id`` drops ``_``, ``!`` and ``?`` and folds case, so
        ``__schema__`` / ``schema``, ``get`` / ``get!`` or ``valid?`` / ``valid``
        of one module minted one id: the second def vanished and its calls were
        credited to its twin. Group the defs of the enclosing module (or of
        the file, outside any module) by the id they would get, then apply
        ``_underscore_salted_nid``, the Python/C#/Solidity/Java rule (#3302,
        #4415, #5058, #5151): a unique public name keeps the plain id, every
        other colliding name is salted. Defs that collide with nothing keep
        their old id; clauses of one function share one name, so they are not
        a collision.
        """
    def _def_nid(container: str, def_node, func_name: str) -> str {
        scope: any = def_node.parent;
        while scope is not None
            and not (scope.type == "call" and _call_keyword(scope) in _ELIXIR_CONTAINER_KEYWORDS)
        {
            scope = scope.parent;
        }
        if scope is None {
            scope = `root;
        }
        key: any = (container, scope.start_byte, scope.end_byte);
        groups: any = def_groups.get(key);
        if groups is None {
            names: dict[str, set[str]] = {};
            stack: any = `list(scope.children);
            while stack {
                n: any = stack.pop();
                if n.type == "call" {
                    keyword: any = _call_keyword(n);
                    if keyword in _ELIXIR_CONTAINER_KEYWORDS {
                        continue;
                    }
                    if keyword in _ELIXIR_DEF_KEYWORDS {
                        args: any = next((c for c in n.children if c.type == "arguments"), None);
                        name: any = _def_name(args) if args is not None else None;
                        if name and normalize_id(name) {
                            names.setdefault(_make_id(container, name), set[any]()).add(name);
                        }
                        continue;
                    }
                }
                stack.extend(n.children);
            }
            groups = {nid: ns for (nid, ns) in names.items() if len(ns) >= 2};
            def_groups[key] = groups;
        }
        return _underscore_salted_nid(
            _make_id(container, func_name),
            func_name,
            groups,
            private_suffixes=_ELIXIR_PRIVATE_SUFFIXES,
        );
    }

    def walk(`node, parent_module_nid: str | None = None) -> None {
        if `node.type != "call" {
            child: any;
            for child in `node.children {
                walk(child, parent_module_nid);
            }
            return;
        }

        identifier_node: any = None;
        arguments_node: any = None;
        do_block_node: any = None;
        for child in `node.children {
            if child.type == "identifier" {
                identifier_node = child;
            } elif child.type == "arguments" {
                arguments_node = child;
            } elif child.type == "do_block" {
                do_block_node = child;
            }
        }

        if identifier_node is None {
            for child in `node.children {
                walk(child, parent_module_nid);
            }
            return;
        }

        keyword: any = source[identifier_node.start_byte:identifier_node.end_byte].decode(
            "utf-8", errors="replace"
        );
        line: any = `node.start_point[0] + 1;

        if keyword == "defmodule" {
            module_name: any = _get_alias_text(arguments_node) if arguments_node else None;
            if not module_name {
                return;
            }
            module_nid: any = _make_id(stem, module_name);
            add_node(
                module_nid,
                module_name,
                line,
                **({"_elixir_module": True} if parent_module_nid is None else {}),
            );
            add_edge(file_nid, module_nid, "contains", line);
            enclosing[module_nid] = parent_module_nid;
            _register_module(module_nid, module_name, parent_module_nid);
            if do_block_node {
                for child in do_block_node.children {
                    walk(child, parent_module_nid=module_nid);
                }
            }
            return;
        }

        if keyword == "defprotocol" {
            proto_name: any = _get_alias_text(arguments_node) if arguments_node else None;
            if not proto_name {
                return;
            }
            proto_nid: any = _make_id(stem, proto_name);
            add_node(
                proto_nid,
                proto_name,
                line,
                **({"_elixir_module": True} if parent_module_nid is None else {}),
            );
            add_edge(parent_module_nid or file_nid, proto_nid, "contains", line);
            enclosing[proto_nid] = parent_module_nid;
            _register_module(proto_nid, proto_name, parent_module_nid);
            if do_block_node {
                for child in do_block_node.children {
                    walk(child, parent_module_nid=proto_nid);
                }
            }
            return;
        }

        if keyword == "defimpl" {
            proto_name = _get_alias_text(arguments_node) if arguments_node else None;
            if not proto_name {
                return;
            }
            target: any = _get_keyword_alias(arguments_node, "for");
            impl_nid: any = _make_id(stem, "defimpl", proto_name, target or "");
            label: any = f"{proto_name} (for {target})" if target else proto_name;
            add_node(impl_nid, label, line);
            add_edge(parent_module_nid or file_nid, impl_nid, "contains", line);
            enclosing[impl_nid] = parent_module_nid;
            module_names[impl_nid] = f"{proto_name}.{target}" if target else "";
            add_edge(impl_nid, _make_id(stem, proto_name), "implements", line);
            if do_block_node {
                for child in do_block_node.children {
                    walk(child, parent_module_nid=impl_nid);
                }
            }
            return;
        }
        if keyword
            in ("def", "defp", "defmacro", "defmacrop", "defguard", "defguardp", "defdelegate")
        {
            func_name: any = None;
            if arguments_node {
                for child in arguments_node.children {
                    while child.type == "binary_operator" {
                        head: any = None;
                        sub: any;
                        for sub in child.children {
                            if sub.type in ("call", "identifier", "binary_operator") {
                                head = sub;
                                break;
                            }
                        }
                        if head is None {
                            break;
                        }
                        child = head;
                    }
                    if child.type == "call" {
                        for sub in child.children {
                            if sub.type == "identifier" {
                                func_name = source[sub.start_byte:sub.end_byte].decode(
                                    "utf-8", errors="replace"
                                );
                                break;
                            }
                        }
                    } elif child.type == "identifier" {
                        func_name = source[child.start_byte:child.end_byte].decode(
                            "utf-8", errors="replace"
                        );
                        break;
                    }
                }
            }
            if not func_name {
                return;
            }
            container: any = parent_module_nid or file_nid;
            func_nid: any = _def_nid(container, `node, func_name);
            add_node(func_nid, f"{func_name}()", line);
            enclosing[func_nid] = parent_module_nid;
            if parent_module_nid {
                add_edge(parent_module_nid, func_nid, "method", line);
            } else {
                add_edge(file_nid, func_nid, "contains", line);
            }
            module_defs.setdefault((container, func_name), func_nid);
            if do_block_node {
                function_bodies.append((func_nid, do_block_node));
            } else {
                keyword_body: any = _get_do_keyword_body(arguments_node);
                if keyword_body is not None {
                    function_bodies.append((func_nid, keyword_body));
                }
            }
            return;
        }

        if keyword in _IMPORT_KEYWORDS and arguments_node {
            for module_name in _get_alias_modules(arguments_node) {
                tgt_nid: any = _make_id(module_name);
                add_edge(file_nid, tgt_nid, "imports", line, context="import");
                if keyword in ("import", "use") {
                    call_scope.setdefault(parent_module_nid, []).append(module_name);
                }
            }
            if keyword == "alias" {
                _record_aliases(arguments_node, parent_module_nid);
            }
            return;
        }

        for child in `node.children {
            walk(child, parent_module_nid);
        }
    }

    walk(`root);

    module_nid_by_name = {name: nid for (nid, name) in module_names.items()};
    _MODULE_REF = re.compile("(__MODULE__|[A-Z]\\w*)(\\.[A-Z]\\w*)*");

    seen_call_pairs = set[any]();
    raw_calls = [];
    _SKIP_KEYWORDS = frozenset({
        "def",
        "defp",
        "defmodule",
        "defmacro",
        "defmacrop",
        "defstruct",
        "defprotocol",
        "defimpl",
        "defguard",
        "defdelegate",
        "alias",
        "import",
        "require",
        "use",
        "if",
        "unless",
        "case",
        "cond",
        "with",
        "for",
    });

    """import/use targets visible to a call inside ``caller_nid``: its own
        module's, each enclosing module's, then the file's top-level ones."""
    def _call_scope_for(caller_nid: str) -> list[str] {
        scope: list[str] = [];
        seen: set[str] = set[any]();
        container: any = enclosing.get(caller_nid);
        while container is not None and container not in seen {
            seen.add(container);
            scope.extend(call_scope.get(container, ()));
            container = enclosing.get(container);
        }
        scope.extend(call_scope.get(None, ()));
        return scope;
    }

    def walk_calls(`node, caller_nid: str) -> None {
        if `node.type != "call" {
            child: any;
            for child in `node.children {
                walk_calls(child, caller_nid);
            }
            return;
        }
        for child in `node.children {
            if child.type == "identifier" {
                kw: any = source[child.start_byte:child.end_byte].decode("utf-8", errors="replace");
                if kw in _SKIP_KEYWORDS {
                    if kw == "alias" {
                        c: any;
                        for c in `node.children {
                            if c.type == "arguments" {
                                _record_aliases(c, caller_nid);
                            }
                        }
                    }
                    for c in `node.children {
                        walk_calls(c, caller_nid);
                    }
                    return;
                }
                break;
            }
        }
        callee_name: str | None = None;
        is_member_call: bool = False;
        receiver_module: str | None = None;
        for child in `node.children {
            if child.type == "dot" {
                is_member_call = True;
                dot_text: any = source[child.start_byte:child.end_byte].decode(
                    "utf-8", errors="replace"
                );
                parts: any = dot_text.rstrip(".").split(".");
                if parts {
                    callee_name = parts[-1];
                }
                if child.child_count == 3 {
                    receiver: any = child.children[0];
                    receiver_text: any = source[receiver.start_byte:receiver.end_byte].decode(
                        "utf-8", errors="replace"
                    );
                    if _MODULE_REF.fullmatch(receiver_text) {
                        receiver_module = _expand_module(receiver_text, caller_nid);
                    }
                }
                break;
            }
            if child.type == "identifier" {
                callee_name = source[child.start_byte:child.end_byte].decode(
                    "utf-8", errors="replace"
                );
                break;
            }
        }
        if callee_name and (receiver_module or callee_name not in _LANGUAGE_BUILTIN_GLOBALS) {
            if receiver_module is not None {
                mod_nid: any = module_nid_by_name.get(receiver_module);
                tgt_nid: any = module_defs.get((mod_nid, callee_name)) if mod_nid else None;
            } elif is_member_call {
                tgt_nid = None;
            } else {
                own_container: any = enclosing.get(caller_nid) or file_nid;
                tgt_nid = module_defs.get((own_container, callee_name));
                if tgt_nid is None {
                    for scope_name in _call_scope_for(caller_nid) {
                        scope_nid: any = module_nid_by_name.get(scope_name);
                        if scope_nid is None {
                            continue;
                        }
                        tgt_nid = module_defs.get((scope_nid, callee_name));
                        if tgt_nid is not None {
                            break;
                        }
                    }
                }
            }
            if tgt_nid and tgt_nid != caller_nid {
                pair: any = (caller_nid, tgt_nid);
                if pair not in seen_call_pairs {
                    seen_call_pairs.add(pair);
                    add_edge(
                        caller_nid,
                        tgt_nid,
                        "calls",
                        `node.start_point[0] + 1,
                        confidence="EXTRACTED",
                        weight=1.0,
                        context="call",
                    );
                }
            } else {
                raw_calls.append({
                    "caller_nid": caller_nid,
                    "callee": callee_name,
                    "is_member_call": is_member_call,
                    "source_file": str_path,
                    "source_location": f"L{`node.start_point[0] + 1}",
                    "elixir_call_scope": _call_scope_for(caller_nid),
                    **{"elixir_module": receiver_module} if receiver_module else {},
                });
            }
        }
        for child in `node.children {
            walk_calls(child, caller_nid);
        }
    }

    for (caller_nid, body) in function_bodies {
        walk_calls(body, caller_nid);
    }

    clean_edges: any = [
        e
        for e in edges
        if e["source"] in seen_ids and (e["target"] in seen_ids or e["relation"] == "imports")
    ];
    return {
        "nodes": nodes,
        "edges": clean_edges,
        "raw_calls": raw_calls,
        "input_tokens": 0,
        "output_tokens": 0,
    };
}
