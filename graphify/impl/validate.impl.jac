impl validate_extraction(data: dict) -> list[str] {
    if not isinstance(data, `dict) {
        return ["Extraction must be a JSON object"];
    }

    errors: list[str] = [];
    node_ids: set = set[any]();
    if "nodes" not in data {
        errors.append("Missing required key 'nodes'");
    } elif not isinstance(data["nodes"], `list) {
        errors.append("'nodes' must be a list");
    } else {
        i: any;
        for (i, `node) in enumerate(data["nodes"]) {
            if not isinstance(`node, `dict) {
                errors.append(f"Node {i} must be an object");
                continue;
            }
            field: any;
            for field in REQUIRED_NODE_FIELDS {
                if field not in `node {
                    errors.append(
                        "Node "
                            + format(i, "")
                            + " (id="
                            + format(repr(`node.get("id", "?")), "")
                            + ") missing required field '"
                            + format(field, "")
                            + "'",
                    );
                }
            }
            if "id" in `node {
                try {
                    hash(`node["id"]);
                } except TypeError {
                    errors.append(
                        "Node "
                            + format(i, "")
                            + " has non-hashable id "
                            + format(repr(`node["id"]), "")
                            + " - id must be a string",
                    );
                } else {
                    node_ids.add(`node["id"]);
                }
            }
            if "file_type" in `node
                and (
                    not isinstance(`node["file_type"], `str)
                    or `node["file_type"] not in VALID_FILE_TYPES
                )
            {
                errors.append(
                    "Node "
                        + format(i, "")
                        + " (id="
                        + format(repr(`node.get("id", "?")), "")
                        + ") has invalid file_type '"
                        + format(`node["file_type"], "")
                        + "' - must be one of "
                        + format(sorted(VALID_FILE_TYPES), ""),
                );
            }
        }
    }
    edge_list: any = data.get("edges") if "edges" in data else data.get("links");
    if edge_list is None {
        errors.append("Missing required key 'edges'");
    } elif not isinstance(edge_list, `list) {
        errors.append("'edges' must be a list");
    } else {
        for (i, `edge) in enumerate(edge_list) {
            if not isinstance(`edge, `dict) {
                errors.append(f"Edge {i} must be an object");
                continue;
            }
            for field in REQUIRED_EDGE_FIELDS {
                if field not in `edge {
                    errors.append(f"Edge {i} missing required field '{field}'");
                }
            }
            if "confidence" in `edge
                and (
                    not isinstance(`edge["confidence"], `str)
                    or `edge["confidence"] not in VALID_CONFIDENCES
                )
            {
                errors.append(
                    "Edge "
                        + format(i, "")
                        + " has invalid confidence '"
                        + format(`edge["confidence"], "")
                        + "' - must be one of "
                        + format(sorted(VALID_CONFIDENCES), ""),
                );
            }
            for endpoint in ("source", "target") {
                if endpoint not in `edge {
                    continue;
                }
                val: any = `edge[endpoint];
                try {
                    unmatched: any = `bool(node_ids) and val not in node_ids;
                } except TypeError {
                    errors.append(
                        f"Edge {i} {endpoint} {val!r} is non-hashable - must be a string"
                    );
                    continue;
                }
                if unmatched {
                    errors.append(f"Edge {i} {endpoint} '{val}' does not match any node id");
                }
            }
        }
    }

    return errors;
}

impl assert_valid(data: dict) {
    errors: any = validate_extraction(data);
    if errors {
        msg: any = f"Extraction JSON has {len(errors)} error(s):\n"
            + "\n".join(f"  • {e}" for e in errors);
        raise ValueError(msg);
    }
}
