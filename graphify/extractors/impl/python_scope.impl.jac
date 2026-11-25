impl _python_param_names(params_node, source: bytes) -> set[str] {
    out: set[str] = set[any]();
    if params_node is None {
        return out;
    }
    for child in typing.cast(object, params_node).children {
        if child.type == "identifier" {
            out.add(_read_text(child, source));
        } elif child.type
            in (
                "typed_parameter",
                "default_parameter",
                "typed_default_parameter",
                "list_splat_pattern",
                "dictionary_splat_pattern",
            )
        {
            name_n: any = child.child_by_field_name("name");
            if name_n is None {
                name_n = next((c for c in typing.cast(object, child).children if c.type == "identifier"), None);
            }
            if name_n is not None {
                out.add(_read_text(name_n, source));
            }
        }
    }
    return out;
}

impl _python_param_shadow_checker(source: bytes) -> any {
    scopes: dict[int, tuple[set[str], set[str]]];
    scopes = {};

    def rebound_names(body) -> set[str] {
        names: set[str] = set[any]();
        pending = builtins.list(typing.cast(object, body).named_children);
        while pending {
            `node = pending.pop();
            kind = `node.type;
            if kind in ("function_definition", "class_definition") {
                name: any = `node.child_by_field_name("name");
                if name is not None {
                    names.add(_read_text(name, source));
                }
            } elif kind == "global_statement" {
                names.update(_read_text(c, source) for c in typing.cast(object, `node).named_children);
            } elif kind in ("import_statement", "import_from_statement") {
                for item in `node.children_by_field_name("name") {
                    alias: any = item.child_by_field_name("alias");
                    text: any = _read_text(item if alias is None else alias, source);
                    names.add(text.split(".")[0] if kind == "import_statement" else text);
                }
            } elif kind != "lambda" {
                pending.extend(`node.named_children);
            }
        }
        return names;
    }

    def facts(scope, body) -> tuple[set[str], set[str]] {
        if scope.id not in scopes {
            params: any = scope.child_by_field_name("parameters");
            scopes[scope.id] = (_python_param_names(params, source), rebound_names(body));
        }
        return scopes[scope.id];
    }

    def is_shadowed(call, name: str) -> bool {
        `node = typing.cast(object, call);
        nearest: any = True;
        while (parent := `node.parent) is not None {
            if parent.type in ("function_definition", "class_definition") {
                body: any = parent.child_by_field_name("body");
                if `node == body {
                    is_function: any = operator.eq(parent.type, "function_definition");
                    if is_function or nearest {
                        params: any;
                        rebound: any;
                        (params, rebound) = facts(parent, body) as any;
                        if name in rebound {
                            return False;
                        }
                        if is_function and name in params {
                            return True;
                        }
                    }
                    nearest = False;
                }
            }
            `node = parent;
        }
        return False;
    }

    return is_shadowed;
}
