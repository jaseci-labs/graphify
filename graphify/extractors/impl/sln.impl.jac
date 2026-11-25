impl extract_sln(path: Path) -> dict {
    try {
        src: any = _read_source_text(path);
    } except OSError {
        return {"nodes": [], "edges": [], "error": f"cannot read {path}"};
    }

    file_nid: any = _make_id(`str(path));
    str_path: any = `str(path);
    nodes: list[dict] = [
        {
            "id": file_nid,
            "label": path.name,
            "file_type": "code",
            "source_file": str_path,
            "source_location": None,
        },
    ];
    edges: list[dict] = [];
    seen_ids: set[str] = set[any]();
    seen_ids.add(file_nid);

    _PROJECT_RE: any = re.compile(
        "Project\\(\"[^\"]*\"\\)\\s*=\\s*\"([^\"]+)\"\\s*,\\s*\"([^\"]+)\"\\s*,\\s*\"([^\"]*)\""
    );
    _DEP_RE: any = re.compile("\\{([0-9a-fA-F-]+)\\}\\s*=\\s*\\{([0-9a-fA-F-]+)\\}");

    guid_to_nid: dict[str, str] = {};

    for m in _PROJECT_RE.finditer(src) {
        proj_name: any = m.group(1);
        proj_path: any = m.group(2).replace("\\", "/");
        proj_guid: any = m.group(3).strip("{}");
        is_solution_folder: any = operator.eq(proj_path, proj_name);
        if is_solution_folder {
            abs_proj: any = proj_name;
        } else {
            try {
                abs_proj = `str((path.parent / proj_path).resolve());
            } except Exception {
                abs_proj = proj_path;
            }
        }
        proj_nid: any = _make_id(abs_proj);
        if proj_nid and proj_nid not in seen_ids {
            seen_ids.add(proj_nid);
            nodes.append({
                "id": proj_nid,
                "label": proj_name,
                "file_type": "code",
                "source_file": abs_proj,
                "source_location": None,
            });
            edges.append({
                "source": file_nid,
                "target": proj_nid,
                "relation": "contains",
                "confidence": "EXTRACTED",
                "source_file": str_path,
                "weight": 1.0,
            });
        }
        if proj_guid {
            guid_to_nid[proj_guid.lower()] = proj_nid;
        }
    }

    in_dep_section: any = False;
    current_proj_guid: str | None = None;
    _PROJECT_LINE_RE: any = re.compile(
        "Project\\(\"[^\"]*\"\\)\\s*=\\s*\"[^\"]+\"\\s*,\\s*\"[^\"]+\"\\s*,\\s*\"\\{([^}]+)\\}\""
    );
    for line in src.splitlines() {
        proj_line_m: any = _PROJECT_LINE_RE.search(line);
        if proj_line_m {
            current_proj_guid = proj_line_m.group(1).lower();
            continue;
        }
        if line.strip() == "EndProject" {
            current_proj_guid = None;
            continue;
        }
        if "ProjectSection(ProjectDependencies)" in line {
            in_dep_section = True;
            continue;
        }
        if in_dep_section and "EndProjectSection" in line {
            in_dep_section = False;
            continue;
        }
        if in_dep_section and current_proj_guid {
            dep_m: any = _DEP_RE.search(line);
            if dep_m {
                to_guid: any = dep_m.group(1).lower();
                from_nid: any = guid_to_nid.get(current_proj_guid);
                to_nid: any = guid_to_nid.get(to_guid);
                if from_nid and to_nid and from_nid != to_nid {
                    edges.append({
                        "source": from_nid,
                        "target": to_nid,
                        "relation": "imports",
                        "confidence": "EXTRACTED",
                        "source_file": str_path,
                        "weight": 1.0,
                    });
                }
            }
        }
    }

    return {"nodes": nodes, "edges": edges};
}
