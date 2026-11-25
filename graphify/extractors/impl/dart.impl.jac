impl extract_dart(path: Path) -> dict {
    src_clean: any;
    nodes: any;
    edges: any;
    defined: set[str];
    nid: any;
    try {
        src: any = _read_source_text(path);
    } except OSError {
        return {"error": f"cannot read {path}"};
    }
    comment_string_pattern: any = re.compile(
        "\"\"\"(?:\\\\.|[\\s\\S])*?\"\"\"|'''(?:\\\\.|[\\s\\S])*?'''|\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'|/\\*[\\s\\S]*?\\*/|//[^\\n]*",
    );
    def _comment_replace(`match: re.Match) -> str {
        token: any = `match.group(0);
        if token.startswith("/") {
            return "\n" * token.count("\n");
        }
        return token;
    }
    src_clean = comment_string_pattern.sub(_comment_replace, src);

    def _line_at(offset: int) -> int {
        return src_clean[:offset].count("\n") + 1;
    }

    stem: any = _file_stem(path);
    file_nid: any = _make_id(`str(path));
    part_of_match: any = re.search(
        "^\\s*part\\s+of\\s+['\\\"]([^'\\\"]+)['\\\"]", src_clean, re.MULTILINE
    );
    is_part: any = False;
    part_of_line: any = None;
    if part_of_match {
        parent_ref: any = part_of_match.group(1);
        if parent_ref.endswith(".dart") {
            try {
                parent_path: any = (path.parent / parent_ref).resolve();
                if parent_path.exists() {
                    stem = _file_stem(parent_path);
                    file_nid = _make_id(`str(parent_path));
                    is_part = True;
                    part_of_line = _line_at(part_of_match.start(1));
                }
            } except Exception {}
        }
    }
    own_nid: any = _make_id(`str(path));
    nodes = [
        {
            "id": own_nid,
            "label": path.name,
            "file_type": "code",
            "source_file": `str(path),
            "source_location": None,
        },
    ];
    edges = [];
    defined = set[any]();

    source_file_default_: any = `str(path);

    def add_node(
        nid: str,
        label: str,
        ftype: str = "code",
        source_file: str | None = source_file_default_,
        line: int | None = None,
    ) -> None {
        if nid not in defined {
            nodes.append({
                "id": nid,
                "label": label,
                "file_type": ftype,
                "source_file": source_file,
                "source_location": f"L{line}" if line else None,
            });
            defined.add(nid);
        }
    }

    def add_edge(
        src_id: str,
        tgt_id: str,
        relation: str,
        weight: float = 1.0,
        context: str | None = None,
        line: int | None = None,
    ) -> None {
        `edge: any = {
            "source": src_id,
            "target": tgt_id,
            "relation": relation,
            "confidence": "EXTRACTED",
            "confidence_score": 1.0,
            "source_file": `str(path),
            "source_location": f"L{line}" if line else None,
            "weight": weight,
        };
        if context {
            `edge["context"] = context;
        }
        edges.append(`edge);
    }

    def _split_types(text: str) -> list[str] {
        parts: any = [];
        current: any = [];
        depth: any = 0;
        for char in text {
            if char == "<" {
                depth += 1;
                current.append(char);
            } elif char == ">" {
                depth -= 1;
                current.append(char);
            } elif char == "," and depth == 0 {
                parts.append("".join(current).strip());
                current = [];
            } else {
                current.append(char);
            }
        }
        if current {
            parts.append("".join(current).strip());
        }
        return [p for p in parts if p];
    }

    def _find_matching_brace(text: str, start_pos: int) -> int {
        brace_count: any = 0;
        in_double_quote: any = False;
        in_single_quote: any = False;
        escape: any = False;

        first_brace: any = text.find("{", start_pos);
        if first_brace == -1 {
            return len(text);
        }

        brace_count = 1;
        i: any = first_brace + 1;
        n: any = len(text);
        while i < n {
            char: any = text[i];
            if escape {
                escape = False;
                i += 1;
                continue;
            }
            if char == "\\" {
                escape = True;
                i += 1;
                continue;
            }
            if text[i:i + 3] == "\"\"\"" and not in_single_quote {
                i += 3;
                end: any = text.find("\"\"\"", i);
                i = end + 3 if end != -1 else n;
                continue;
            }
            if text[i:i + 3] == "'''" and not in_double_quote {
                i += 3;
                end = text.find("'''", i);
                i = end + 3 if end != -1 else n;
                continue;
            }
            if char == "\"" and not in_single_quote {
                in_double_quote = not in_double_quote;
            } elif char == "'" and not in_double_quote {
                in_single_quote = not in_single_quote;
            } elif not in_double_quote and not in_single_quote {
                if char == "{" {
                    brace_count += 1;
                } elif char == "}" {
                    brace_count -= 1;
                    if brace_count == 0 {
                        return i + 1;
                    }
                }
            }
            i += 1;
        }
        return len(text);
    }
    class_pattern: any = "^\\s*(?:(?:abstract|sealed|base|interface|final|mixin)\\s+)*(?:class|mixin|enum|extension\\s+type)\\s+(\\w+)";
    m: any;
    for m in re.finditer(class_pattern, src_clean, re.MULTILINE) {
        class_name: any = m.group(1);
        class_line: any = _line_at(m.start(1));
        class_nid: any = _make_id(stem, class_name);
        add_node(class_nid, class_name, line=class_line);
        add_edge(file_nid, class_nid, "defines", line=class_line);
        start_idx: any = m.end();
        rest: any = src_clean[start_idx:start_idx + 500];
        if rest.lstrip().startswith("<") {
            offset: any = rest.find("<");
            depth: any = 1;
            i: any = offset + 1;
            while i < len(rest) and depth > 0 {
                if rest[i] == "<" {
                    depth += 1;
                } elif rest[i] == ">" {
                    depth -= 1;
                }
                i += 1;
            }
            rest = rest[i:];
        }
        if rest.lstrip().startswith("(") {
            offset = rest.find("(");
            depth = 1;
            i = offset + 1;
            while i < len(rest) and depth > 0 {
                if rest[i] == "(" {
                    depth += 1;
                } elif rest[i] == ")" {
                    depth -= 1;
                }
                i += 1;
            }
            rest = rest[i:];
        }

        header_end: any = rest.find("{");
        if header_end == -1 {
            header_end = rest.find(";");
        }
        if header_end == -1 {
            header_end = len(rest);
        }
        header: any = rest[:header_end];

        mixins_list: any = [];
        interfaces_list: any = [];

        def _consume_generic_args(text: str) -> tuple[str | None, str] {
            if not text.strip().startswith("<") {
                return (None, text);
            }
            start_idx: any = text.find("<");
            depth: any = 1;
            i: any = start_idx + 1;
            while i < len(text) and depth > 0 {
                if text[i] == "<" {
                    depth += 1;
                } elif text[i] == ">" {
                    depth -= 1;
                    if depth == 0 {
                        return (text[start_idx + 1:i], text[i + 1:]);
                    }
                }
                i += 1;
            }
            return (None, text);
        }
        base_entries: list[tuple[str, str | None]] = [];
        extends_m: any = re.search("^\\s*(extends|on)\\s+([a-zA-Z0-9_.]+)", header);
        if extends_m {
            is_on: any = operator.eq(extends_m.group(1), "on");
            base_class: any = extends_m.group(2);
            header = header[extends_m.end():];
            generics: any;
            (generics, header) = _consume_generic_args(header) as any;
            base_entries.append((base_class, generics));

            if is_on {
                while True {
                    comma_m: any = re.match("\\s*,\\s*([a-zA-Z0-9_.]+)", header);
                    if not comma_m {
                        break;
                    }
                    header = header[comma_m.end():];
                    extra_generics: any;
                    (extra_generics, header) = _consume_generic_args(header) as any;
                    base_entries.append((comma_m.group(1), extra_generics));
                }
            }
        }
        with_m: any = re.search("^\\s*with\\s+", header);
        if with_m {
            rest_header: any = header[with_m.end():];
            impl_idx: any = rest_header.find("implements");
            if impl_idx != -1 {
                mixins_str: any = rest_header[:impl_idx];
                header = rest_header[impl_idx:];
            } else {
                mixins_str = rest_header;
                header = "";
            }
            mixins_list = _split_types(mixins_str);
        }
        impl_m: any = re.search("^\\s*implements\\s+", header);
        if impl_m {
            interfaces_list = _split_types(header[impl_m.end():]);
        }
        for (base_class, generics) in base_entries {
            base_nid: any = _make_id(base_class);
            add_node(base_nid, base_class, source_file=None);
            add_edge(class_nid, base_nid, "inherits", line=class_line);
            if generics {
                for gen in _split_types(generics) {
                    gen_clean: any = gen.split("<")[0].strip();
                    if gen_clean not in {
                        "String",
                        "int",
                        "double",
                        "bool",
                        "num",
                        "dynamic",
                        "Object",
                        "void",
                    }
                    {
                        gen_nid: any = _make_id(gen_clean);
                        add_node(gen_nid, gen_clean, source_file=None);
                        add_edge(class_nid, gen_nid, "references", line=class_line);
                    }
                }
            }
        }
        for mixin in mixins_list {
            mixin_clean: any = mixin.split("<")[0].strip();
            mixin_nid: any = _make_id(mixin_clean);
            add_node(mixin_nid, mixin_clean, source_file=None);
            add_edge(class_nid, mixin_nid, "mixes_in", line=class_line);
        }
        for interface in interfaces_list {
            interface_clean: any = interface.split("<")[0].strip();
            interface_nid: any = _make_id(interface_clean);
            add_node(interface_nid, interface_clean, source_file=None);
            add_edge(class_nid, interface_nid, "implements", line=class_line);
        }
        start_idx = m.start();
        brace_pos: any = src_clean.find("{", start_idx);
        semi_pos: any = src_clean.find(";", start_idx);

        has_body: any = operator.ne(brace_pos, -1);
        if has_body and semi_pos != -1 and semi_pos < brace_pos {
            has_body = False;
        }

        if has_body {
            end_pos: any = _find_matching_brace(src_clean, start_idx);
            class_body: any = src_clean[brace_pos:end_pos];
            for em in re.finditer("\\bon<(\\w+)>\\s*\\(", class_body) {
                event_name: any = em.group(1);
                event_nid: any = _make_id(event_name);
                add_node(event_nid, event_name, source_file=None);
                add_edge(
                    class_nid,
                    event_nid,
                    "calls",
                    context="bloc_event",
                    line=_line_at(brace_pos + em.start(1)),
                );
            }
            for sm in re.finditer(
                "\\b(?:emit|yield)\\s*\\(?\\s*(?:const\\s+)?([A-Z]\\w*)\\b", class_body
            ) {
                state_name: any = sm.group(1);
                if state_name not in {"String", "List", "Map", "Set", "Future", "Stream", "Object"}
                {
                    state_nid: any = _make_id(state_name);
                    add_node(state_nid, state_name, source_file=None);
                    add_edge(
                        class_nid,
                        state_nid,
                        "calls",
                        context="emit_state",
                        line=_line_at(brace_pos + sm.start(1)),
                    );
                }
            }
            am: any;
            for am in re.finditer(
                "\\b(?:\\w*[Bb]loc\\w*|context\\.read<\\w+>\\(\\))\\.add\\(\\s*(?:const\\s+)?([A-Z]\\w*)\\b",
                class_body,
            ) {
                event_name = am.group(1);
                if event_name not in {"String", "List", "Map", "Set", "Future", "Stream", "Object"}
                {
                    event_nid = _make_id(event_name);
                    add_node(event_nid, event_name, source_file=None);
                    add_edge(
                        class_nid,
                        event_nid,
                        "calls",
                        context="bloc_add_event",
                        line=_line_at(brace_pos + am.start(1)),
                    );
                }
            }
            rm: any;
            for rm in re.finditer(
                "\\bref\\.(?:watch|read|listen)\\s*\\(\\s*(\\w+)\\b", class_body
            ) {
                provider_name: any = rm.group(1);
                provider_nid: any = _make_id(provider_name);
                add_node(provider_nid, provider_name, source_file=None);
                add_edge(
                    class_nid,
                    provider_nid,
                    "references",
                    context="riverpod_reference",
                    line=_line_at(brace_pos + rm.start(1)),
                );
            }
            bm: any;
            for bm in re.finditer(
                "\\bBloc(?:Builder|Listener|Consumer|Provider|Selector)\\s*<\\s*([a-zA-Z0-9_]+)\\b",
                class_body,
            ) {
                bloc_name: any = bm.group(1);
                if bloc_name not in {
                    "String",
                    "int",
                    "double",
                    "bool",
                    "num",
                    "dynamic",
                    "Object",
                    "void",
                }
                {
                    bloc_nid: any = _make_id(bloc_name);
                    add_node(bloc_nid, bloc_name, source_file=None);
                    add_edge(
                        class_nid,
                        bloc_nid,
                        "references",
                        context="bloc_widget_binding",
                        line=_line_at(brace_pos + bm.start(1)),
                    );
                }
            }
            lm: any;
            for lm in re.finditer("\\b(?:read|watch|select|of)\\s*<([a-zA-Z0-9_]+)>", class_body) {
                bloc_name = lm.group(1);
                if bloc_name not in {
                    "String",
                    "int",
                    "double",
                    "bool",
                    "num",
                    "dynamic",
                    "Object",
                    "void",
                }
                {
                    bloc_nid = _make_id(bloc_name);
                    add_node(bloc_nid, bloc_name, source_file=None);
                    add_edge(
                        class_nid,
                        bloc_nid,
                        "references",
                        context="bloc_lookup",
                        line=_line_at(brace_pos + lm.start(1)),
                    );
                }
            }
        }
    }
    annotation_pattern: any = "@(\\w+)(?:\\([^)]*\\))?";
    for am in re.finditer(annotation_pattern, src_clean) {
        annotation_name: any = am.group(1);
        if annotation_name in {"override", "deprecated", "required", "protected", "mustCallSuper"} {
            continue;
        }
        annotation_pos: any = am.end();
        intervening_text: any = src_clean[annotation_pos:annotation_pos + 300];

        class_m: any = re.search(
            "^\\s*(?:(?:abstract|sealed|base|interface|final|mixin)\\s+)*(?:class|mixin|enum|extension\\s+type)\\s+(\\w+)",
            intervening_text,
            re.MULTILINE,
        );
        func_m: any = re.search(
            "^\\s*(?:factory\\s+|static\\s+|async\\s+|external\\s+|abstract\\s+)?(?:\\([^)]+\\)|[a-zA-Z0-9_<>,.?]+)(?:\\s+[a-zA-Z0-9_<>,.?]+){0,3}\\s+(\\w+)\\s*\\(",
            intervening_text,
            re.MULTILINE,
        );

        target_nid: any = None;
        target_name: any = None;
        target_type: any = None;

        if class_m and func_m {
            if class_m.start() < func_m.start() {
                target_name = class_m.group(1);
                target_type = "class";
                target_nid = _make_id(stem, target_name);
            } else {
                target_name = func_m.group(1);
                target_type = "function";
                target_nid = _make_id(stem, target_name);
            }
        } elif class_m {
            target_name = class_m.group(1);
            target_type = "class";
            target_nid = _make_id(stem, target_name);
        } elif func_m {
            target_name = func_m.group(1);
            target_type = "function";
            target_nid = _make_id(stem, target_name);
        }

        if target_nid and target_name {
            actual_intervening: any = intervening_text[:min(
                class_m.start() if class_m else 300, func_m.start() if func_m else 300
            )];
            if ";" not in actual_intervening
                and "}" not in actual_intervening
                and "{" not in actual_intervening
            {
                annotation_line: any = _line_at(am.start(1));
                annotation_nid: any = _make_id("annotation", annotation_name.lower());
                add_node(annotation_nid, f"@{annotation_name}", ftype="concept", source_file=None);
                add_edge(target_nid, annotation_nid, "configures", line=annotation_line);
                if annotation_name.lower() == "riverpod" {
                    if target_type == "class" {
                        provider_name = target_name[0].lower() + target_name[1:] + "Provider"
                            if len(target_name) > 1
                            else target_name.lower() + "Provider";
                    } else {
                        provider_name = target_name + "Provider";
                    }
                    provider_nid = _make_id(provider_name);
                    add_node(
                        provider_nid,
                        provider_name,
                        ftype="concept",
                        source_file=`str(path),
                        line=annotation_line,
                    );
                    add_edge(
                        target_nid,
                        provider_nid,
                        "defines",
                        context="riverpod_provider",
                        line=annotation_line,
                    );
                }
            }
        }
    }
    typedef_pattern: any = "^\\s*typedef\\s+(\\w+)\\s*(?:<[^>]+>)?\\s*=\\s*([^;]+);";
    legacy_typedef_pattern: any = "^[ \\t]*typedef[ \\t]+(?:[\\w<>,.?]+(?:\\([^()\\n]*\\)[\\w<>,.?]*)?[ \\t]+)*?(?!Function\\b)(\\w+)[ \\t]*(?:<[^>\\n]+>)?[ \\t]*\\(";
    typedef_builtins: any = {
        "String",
        "int",
        "double",
        "bool",
        "num",
        "dynamic",
        "Object",
        "List",
        "Map",
        "Set",
        "void",
        "Function",
    };
    for pattern in (typedef_pattern, legacy_typedef_pattern) if "typedef" in src_clean else () {
        for m in re.finditer(pattern, src_clean, re.MULTILINE) {
            typedef_name: any = m.group(1);
            typedef_line: any = _line_at(m.start(1));
            typedef_nid: any = _make_id(stem, typedef_name);
            if typedef_nid in defined {
                continue;
            }
            add_node(typedef_nid, typedef_name, line=typedef_line);
            add_edge(file_nid, typedef_nid, "defines", line=typedef_line);
            named: any = re.fullmatch(
                "([\\w.]+)\\s*(?:<.*>)?\\s*\\??", m.group(2).strip(), re.DOTALL
            )
                if pattern is typedef_pattern
                else None;
            target_type = named.group(1).split(".")[-1] if named else "";
            if target_type and target_type not in typedef_builtins {
                target_nid = _make_id(target_type);
                add_node(target_nid, target_type, source_file=None);
                add_edge(
                    typedef_nid, target_nid, "references", context="typedef", line=typedef_line
                );
            }
        }
    }
    ext_pattern: any = "^\\s{0,4}extension\\s+(?:(\\w+)\\s*(?:<[^>]+>)?\\s+)?on\\s+(\\w+)";
    for m in re.finditer(ext_pattern, src_clean, re.MULTILINE) {
        ext_name: any = m.group(1) or f"{stem}_anonymous_extension";
        target_class: any = m.group(2);
        ext_line: any = _line_at(m.start(2));

        ext_nid: any = _make_id(stem, ext_name);
        label: any = m.group(1) or f"Extension on {target_class}";
        add_node(ext_nid, label, line=ext_line);
        add_edge(file_nid, ext_nid, "defines", line=ext_line);

        target_nid = _make_id(target_class);
        add_node(target_nid, target_class, source_file=None);
        add_edge(ext_nid, target_nid, "extends", line=ext_line);
    }
    var_pattern: any = "^\\s{0,2}(?:late\\s+)?(?:(?:final|const|var)\\s+)?(?:\\([^)]+\\)\\s+|([a-zA-Z0-9_<>,.?]+(?:\\s+[a-zA-Z0-9_<>,.?]+){0,3})\\s+)?(?:(\\w+)|(?:\\w+\\s*)?\\(([^)]+)\\))\\s*(?:=|$|;)";
    for m in re.finditer(var_pattern, src_clean, re.MULTILINE) {
        var_type: any = m.group(1);
        single_name: any = m.group(2);
        destructured_names: any = m.group(3);

        if not re.match("^\\s*(?:late|final|const|var)\\b", m.group(0)) and not var_type {
            continue;
        }
        if _TYPEDEF_LINE.match(m.group(0)) {
            continue;
        }

        if single_name {
            if single_name not in {"if", "for", "while", "switch", "catch", "return"} {
                var_line: any = _line_at(m.start(2));
                var_nid: any = _make_id(stem, single_name);
                add_node(var_nid, single_name, line=var_line);
                add_edge(file_nid, var_nid, "defines", line=var_line);

                if var_type
                    and var_type not in {
                        "String",
                        "int",
                        "double",
                        "bool",
                        "num",
                        "dynamic",
                        "Object",
                        "List",
                        "Map",
                        "Set",
                        "void",
                    }
                {
                    clean_type: any = var_type.split("<")[0].split(".")[-1].strip();
                    type_nid: any = _make_id(clean_type);
                    add_node(type_nid, clean_type, source_file=None);
                    add_edge(
                        file_nid, type_nid, "references", context="variable_type", line=var_line
                    );
                }
            }
        } elif destructured_names {
            destructure_line: any = _line_at(m.start(3));
            name: any;
            for name in [n.strip() for n in destructured_names.split(",") if n.strip()] {
                if ":" in name {
                    name = name.split(":")[-1].strip();
                }
                if re.match("^[a-zA-Z_]\\w*$", name) and not re.match("^[A-Z]", name) {
                    if name not in {"if", "for", "while", "switch", "catch", "return"} {
                        var_nid = _make_id(stem, name);
                        add_node(var_nid, name, line=destructure_line);
                        add_edge(file_nid, var_nid, "defines", line=destructure_line);
                    }
                }
            }
        }
    }
    method_pattern: any = "^\\s{0,2}(?:factory\\s+|static\\s+|async\\s+|external\\s+|abstract\\s+)?(?:\\([^)]+\\)|[a-zA-Z0-9_<>,.?]+)(?:\\s+[a-zA-Z0-9_<>,.?]+){0,3}\\s+(\\w+(?:\\.\\w+)?)\\s*\\(";
    method_matches: list[tuple[re.Match, str]] = [];
    for m in re.finditer(method_pattern, src_clean, re.MULTILINE) {
        if _TYPEDEF_LINE.match(m.group(0)) {
            continue;
        }
        raw_name: any = m.group(1);
        name = raw_name.split(".")[-1];
        if name in {
            "if",
            "for",
            "while",
            "switch",
            "catch",
            "return",
            "void",
            "dynamic",
            "final",
            "const",
            "get",
            "set",
        }
        {
            continue;
        }
        if re.match("^[A-Z]", name) {
            continue;
        }
        method_matches.append((m, name));
    }
    method_names: dict[str, set[str]] = {};
    for (_, name) in method_matches {
        if normalize_id(name) and not re.match("^_+[A-Z]", name) {
            method_names.setdefault(_make_id(stem, name), set[any]()).add(name);
        }
    }
    method_groups: any = {nid: names for (nid, names) in method_names.items() if len(names) >= 2};
    for (m, name) in method_matches {
        method_line: any = _line_at(m.start(1));
        nid = _underscore_salted_nid(_make_id(stem, name), name, method_groups);
        add_node(nid, name, line=method_line);
        add_edge(file_nid, nid, "defines", line=method_line);
        start_idx = m.start();
        brace_pos = src_clean.find("{", start_idx);
        semi_pos = src_clean.find(";", start_idx);
        arrow_pos: any = src_clean.find("=>", start_idx);

        has_body = operator.ne(brace_pos, -1);
        if has_body and semi_pos != -1 and semi_pos < brace_pos {
            has_body = False;
        }
        if has_body and arrow_pos != -1 and arrow_pos < brace_pos {
            has_body = False;
        }

        if has_body {
            end_pos = _find_matching_brace(src_clean, start_idx);
            func_body: any = src_clean[brace_pos:end_pos];
            for rm in re.finditer("\\bref\\.(?:watch|read|listen)\\s*\\(\\s*(\\w+)\\b", func_body) {
                provider_name = rm.group(1);
                provider_nid = _make_id(provider_name);
                add_node(provider_nid, provider_name, source_file=None);
                add_edge(
                    nid,
                    provider_nid,
                    "references",
                    context="riverpod_reference",
                    line=_line_at(brace_pos + rm.start(1)),
                );
            }
            for am in re.finditer(
                "\\b(?:\\w*[Bb]loc\\w*|context\\.read<\\w+>\\(\\))\\.add\\(\\s*(?:const\\s+)?([A-Z]\\w*)\\b",
                func_body,
            ) {
                event_name = am.group(1);
                if event_name not in {"String", "List", "Map", "Set", "Future", "Stream", "Object"}
                {
                    event_nid = _make_id(event_name);
                    add_node(event_nid, event_name, source_file=None);
                    add_edge(
                        nid,
                        event_nid,
                        "calls",
                        context="bloc_add_event",
                        line=_line_at(brace_pos + am.start(1)),
                    );
                }
            }
            for lm in re.finditer("\\b(?:read|watch|select|of)\\s*<([a-zA-Z0-9_]+)>", func_body) {
                bloc_name = lm.group(1);
                if bloc_name not in {
                    "String",
                    "int",
                    "double",
                    "bool",
                    "num",
                    "dynamic",
                    "Object",
                    "void",
                }
                {
                    bloc_nid = _make_id(bloc_name);
                    add_node(bloc_nid, bloc_name, source_file=None);
                    add_edge(
                        nid,
                        bloc_nid,
                        "references",
                        context="bloc_lookup",
                        line=_line_at(brace_pos + lm.start(1)),
                    );
                }
            }
            for nm in re.finditer(
                "\\b(?:go|push|goNamed|pushNamed|replace|replaceNamed)\\s*\\(\\s*(?:context\\s*,\\s*)?['\\\"]([a-zA-Z0-9_/?=&%-]+)['\\\"]",
                func_body,
            ) {
                route_path: any = nm.group(1);
                route_nid: any = _make_id(
                    "route",
                    route_path.replace("/", "_").replace("?", "_").replace("=", "_").replace(
                        "&", "_"
                    ),
                );
                add_node(route_nid, f"Route {route_path}", ftype="concept", source_file=None);
                add_edge(
                    nid,
                    route_nid,
                    "navigates",
                    context="route_path",
                    line=_line_at(brace_pos + nm.start(1)),
                );
            }

            for cm in re.finditer(
                "\\b(?:go|push|goNamed|pushNamed|replace|replaceNamed)\\s*\\(\\s*(?:context\\s*,\\s*)?([A-Z][a-zA-Z0-9_]*\\.[a-zA-Z0-9_]+)",
                func_body,
            ) {
                route_const: any = cm.group(1);
                route_nid = _make_id("route", route_const.replace(".", "_"));
                add_node(route_nid, route_const, ftype="concept", source_file=None);
                add_edge(
                    nid,
                    route_nid,
                    "navigates",
                    context="route_const",
                    line=_line_at(brace_pos + cm.start(1)),
                );
            }

            for om in re.finditer(
                "\\b(?:push|replace)\\s*\\(\\s*(?:context\\s*,\\s*)?.*?\\b([A-Z]\\w*(?:Route|Screen|Page))\\b",
                func_body,
            ) {
                route_class: any = om.group(1);
                route_nid = _make_id(route_class);
                add_node(route_nid, route_class, source_file=None);
                add_edge(
                    nid,
                    route_nid,
                    "navigates",
                    context="route_object",
                    line=_line_at(brace_pos + om.start(1)),
                );
            }
        }
    }
    quoted: any = "(?:'[^']*'|\"[^\"]*\")";
    condition: any = f"if\\s*\\(\\s*[\\w.]+\\s*(?:==\\s*{quoted}\\s*)?\\)\\s*";
    branch_re: any = re.compile(f"{condition}(['\"])(?P<uri>[^'\"]+)\\1");
    for (kind, relation) in (("import", "imports"), ("export", "exports")) {
        directive_re: any = re.compile(
            f"^\\s*{kind}\\s+(['\"])(?P<uri>[^'\"]+)\\1(?P<branches>(?:\\s*{condition}{quoted})*)",
            re.MULTILINE,
        );
        for m in directive_re.finditer(src_clean) {
            uris: list[tuple[str, int, str | None]] = [(m.group("uri"), m.start("uri"), None)];
            for bm in branch_re.finditer(m.group("branches")) {
                uris.append((
                    bm.group("uri"),
                    m.start("branches") + bm.start("uri"),
                    "conditional_uri",
                ));
            }
            for (pkg, offset, context) in uris {
                tgt_nid: any = _make_id(pkg);
                add_node(tgt_nid, pkg, source_file=None);
                add_edge(file_nid, tgt_nid, relation, context=context, line=_line_at(offset));
            }
        }
    }
    generic_call_pattern: any = "\\b\\w+<([a-zA-Z0-9_.]+(?:<[a-zA-Z0-9_.,\\s<>]+>)?)\\s*>\\s*\\(";
    type_blacklist: any = {
        "String",
        "int",
        "double",
        "bool",
        "num",
        "dynamic",
        "Object",
        "List",
        "Map",
        "Set",
        "Future",
        "Stream",
        "void",
    };
    for m in re.finditer(generic_call_pattern, src_clean) {
        type_name: any = m.group(1).split(".")[-1].strip();
        clean_name: any = type_name.split("<")[0].strip();
        if clean_name not in type_blacklist {
            target_nid = _make_id(clean_name);
            add_node(target_nid, clean_name, source_file=None);
            add_edge(
                file_nid, target_nid, "references", context="type_lookup", line=_line_at(m.start(1))
            );
        }
    }

    if is_part {
        part_edges: any = [
            {**e, "source": own_nid, "relation": "contains"}
            for e in edges
            if e["source"] == file_nid and e["relation"] == "defines"
        ];
        add_edge(file_nid, own_nid, "includes", line=part_of_line);
        edges.extend(part_edges);
    }

    return {"nodes": nodes, "edges": edges};
}
