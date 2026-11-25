impl _go_to_targets(words: list[str]) -> list[str] {
    if "DEPENDING" not in words {
        return words[:1];
    }
    targets: list[str] = [];
    `skip: any = False;
    for word in words[:words.index("DEPENDING")] {
        if `skip {
            `skip = False;
        } elif word in _GO_TO_QUALIFIERS {
            `skip = True;
        } else {
            targets.append(word);
        }
    }
    return targets;
}

impl _code_lines(source: str) -> list[tuple[int, str]] {
    line: any;
    physical: any = source.splitlines();
    forced_free: any = `bool(
        re.search(">>\\s*SOURCE\\s+FORMAT\\s+(?:IS\\s+)?FREE", source, re.IGNORECASE)
    );
    fixed_markers: any = sum(
        `bool(re.match("^(?: {6}|\\d{6})[ *\\-/dD]", line)) for line in physical if line.strip()
    );
    nonempty: any = sum(`bool(line.strip()) for line in physical);
    free: any = forced_free or operator.lt(fixed_markers, max(1, nonempty // 2));

    logical: list[tuple[int, str]] = [];
    for (number, line) in enumerate(physical, 1) {
        if free {
            code: any = line.split("*>", 1)[0].rstrip();
            if not code.strip() or code.lstrip().startswith(">>") {
                continue;
            }
            logical.append((number, code));
            continue;
        }

        if len(line) < 7 {
            continue;
        }
        indicator: any = line[6];
        if indicator in "*/" {
            continue;
        }
        code = line[7:72].split("*>", 1)[0].rstrip();
        if not code.strip() {
            continue;
        }
        if indicator == "-" and logical {
            prior_number: any;
            prior: any;
            (prior_number, prior) = logical[-1] as any;
            joiner: any = "" if prior.rstrip().endswith("-") else " ";
            logical[-1] = (prior_number, prior.rstrip() + joiner + code.lstrip());
        } else {
            logical.append((number, code));
        }
    }
    return logical;
}

impl _mask_strings(code: str) -> str {
    return re.sub(
        "'[^']*'|\\\"[^\\\"]*\\\"", lambda (`match) -> any { " " * len(`match.group()) }, code
    );
}

impl _starts_inside_string(code: str, offset: int) -> bool {
    for `match in re.finditer("'(?:''|[^'])*'|\\\"(?:\\\"\\\"|[^\\\"])*\\\"", code) {
        if `match.start() <= offset and offset < `match.end() {
            return True;
        }
    }
    return False;
}

impl extract_cobol(path: Path) -> dict {
    source_file: any;
    nodes: list[dict[str, Any]];
    edges: list[dict[str, Any]];
    seen_ids: set[str];
    seen_edges: set[tuple[str, str, str]];
    group: any;
    try {
        source: any = _read_source_text(path);
    } except OSError as exc {
        return {"nodes": [], "edges": [], "error": `str(exc)};
    }

    source_file = `str(path);
    file_id: any = _make_id(source_file);
    nodes = [];
    edges = [];
    raw_calls: list[dict[str, Any]] = [];
    seen_ids = set[any]();
    seen_edges = set[any]();

    def add_node(
        nid: str,
        label: str,
        line: int,
        *,
        kind: str,
        source_backed: bool = True,
        callable_node: bool = False,
    ) -> str {
        if nid not in seen_ids {
            seen_ids.add(nid);
            item: dict[str, Any] = {
                "id": nid,
                "label": label,
                "file_type": "code",
                "source_location": f"L{line}",
                "metadata": {"language": "cobol", "kind": kind},
            };
            if source_backed {
                item["source_file"] = source_file;
            }
            if callable_node {
                item["_callable"] = True;
            }
            nodes.append(item);
        }
        return nid;
    }

    def add_edge(
        source_id: str,
        target_id: str,
        relation: str,
        line: int,
        *,
        target_file: str | None = None,
        context: str | None = None,
    ) -> None {
        key: any = (source_id, target_id, relation);
        if not source_id or not target_id or source_id == target_id or key in seen_edges {
            return;
        }
        seen_edges.add(key);
        `edge: dict[str, Any] = {
            "source": source_id,
            "target": target_id,
            "relation": relation,
            "confidence": "EXTRACTED",
            "source_file": source_file,
            "source_location": f"L{line}",
            "weight": 1.0,
        };
        if target_file {
            `edge["target_file"] = target_file;
        }
        if context {
            `edge["context"] = context;
        }
        edges.append(`edge);
    }

    add_node(file_id, path.name, 1, kind="file");

    code_lines: any = _code_lines(source);
    current_program: any = file_id;
    current_scope: any = file_id;
    in_procedure: any = False;
    in_exec: any = False;
    paragraphs: dict[tuple[str, str], str] = {};
    pending_performs: list[tuple[str, str, str, int]] = [];
    pending_go_tos: list[tuple[str, str, str, int]] = [];
    program_stack: list[str] = [];

    line: any;
    for (line, code) in code_lines {
        upper: any = code.upper().strip();

        if in_exec {
            if "END-EXEC" in upper {
                in_exec = False;
            }
            continue;
        }
        if re.search("\\bEXEC\\s+(?:SQL|CICS)\\b", upper) {
            if "END-EXEC" not in upper {
                in_exec = True;
            }
            continue;
        }

        if _END_PROGRAM.search(upper) {
            if program_stack {
                current_program = program_stack.pop();
                current_scope = current_program;
                in_procedure = True;
            }
            continue;
        }

        program_match: any = _PROGRAM.search(upper);
        if program_match {
            name: any = program_match.group(1).upper();
            program_stack.append(current_program);
            current_program = add_node(
                _make_id(file_id, "program", name.casefold()),
                name,
                line,
                kind="program",
                callable_node=True,
            );
            add_edge(file_id, current_program, "contains", line);
            current_scope = current_program;
            in_procedure = False;
            continue;
        }

        copy_match: any = _COPY.search(code);
        if copy_match {
            written: any = next(group for group in copy_match.groups() if group);
            copy_name: any = written.rstrip(".");
            copy_path: any = Path(copy_name);
            if not copy_path.suffix {
                copy_path = copy_path.with_suffix(".cpy");
            }
            target: any = path.parent / copy_path;
            reference_id: any = add_node(
                _make_id(current_program, "copybook", copy_name.casefold()),
                Path(copy_name).stem.upper(),
                line,
                kind="copybook_reference",
            );
            add_edge(current_program, reference_id, "contains", line);
            add_edge(
                current_program,
                _make_id(`str(target)),
                "imports_from",
                line,
                target_file=`str(target),
            );
        }

        if "PROCEDURE DIVISION" in upper {
            in_procedure = True;
            current_scope = current_program;
            continue;
        }

        if not in_procedure {
            item: any = _DATA_ITEM.match(upper);
            if item {
                name = item.group(1).upper();
                if name != "FILLER" {
                    item_id: any = add_node(
                        _make_id(current_program, "data", name.casefold()),
                        name,
                        line,
                        kind="data_item",
                    );
                    add_edge(current_program, item_id, "contains", line);
                }
            }
            continue;
        }

        paragraph: any = _PARAGRAPH.match(upper);
        if paragraph and paragraph.group(1) not in _NOT_PARAGRAPHS {
            name = paragraph.group(1).upper();
            key: any = (current_program, name.casefold());
            paragraph_id: any = paragraphs.get(key);
            if paragraph_id is None {
                paragraph_id = add_node(
                    _make_id(current_program, "paragraph", name.casefold()),
                    name,
                    line,
                    kind="section" if paragraph.group(2) else "paragraph",
                    callable_node=True,
                );
                paragraphs[key] = paragraph_id;
                add_edge(current_program, paragraph_id, "contains", line);
            }
            current_scope = paragraph_id;
            continue;
        }

        masked: any = _mask_strings(upper);
        `match: any;
        for `match in _PERFORM.finditer(masked) {
            for group in (`match.group(1), `match.group(2)) {
                if group is None {
                    continue;
                }
                name = group.upper();
                if name not in _PERFORM_MODIFIERS {
                    pending_performs.append((current_scope, current_program, name, line));
                }
            }
        }
        jumps: any = `list(_GO_TO.finditer(masked));
        for (index, `match) in enumerate(jumps) {
            end: any = jumps[index + 1].start() if index + 1 < len(jumps) else len(masked);
            words: any = _GO_TO_WORDS.match(masked, `match.end(), end);
            if words is None {
                continue;
            }
            for name in _go_to_targets(re.split("[\\s,]+", words.group())) {
                pending_go_tos.append((current_scope, current_program, name, line));
            }
        }

        for `match in _CALL.finditer(upper) {
            if _starts_inside_string(upper, `match.start()) {
                continue;
            }
            callee: any = `match.group(2).upper();
            raw_calls.append({
                "caller_nid": current_scope,
                "callee": callee,
                "language": "cobol",
                "source_file": source_file,
                "source_location": f"L{line}",
            });
        }
    }

    caller_id: any;
    program_id: any;
    for (caller_id, program_id, name, line) in pending_performs {
        target_id: any = paragraphs.get((program_id, name.casefold()));
        if target_id is not None {
            add_edge(caller_id, target_id, "calls", line);
        }
    }
    for (caller_id, program_id, name, line) in pending_go_tos {
        target_id = paragraphs.get((program_id, name.casefold()));
        if target_id is not None {
            add_edge(caller_id, target_id, "calls", line, context="go_to");
        }
    }

    clean_edges: any = [
        `edge
        for `edge in edges
        if `edge["source"] in seen_ids
            and (`edge["target"] in seen_ids or `edge["relation"] == "imports_from")
    ];
    return {"nodes": nodes, "edges": clean_edges, "raw_calls": raw_calls};
}
