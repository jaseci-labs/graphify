impl extract_blade(path: Path) -> dict {
    import re;
    try {
        src: any = _read_source_text(path);
    } except OSError {
        return {"error": f"cannot read {path}"};
    }

    file_nid: any = _make_id(`str(path));
    nodes: any = [
        {
            "id": file_nid,
            "label": path.name,
            "file_type": "code",
            "source_file": `str(path),
            "source_location": None,
        },
    ];
    edges: any = [];
    m: any;
    for m in re.finditer("@extends\\(['\\\"]([^'\\\"]+)['\\\"]", src) {
        tgt: any = m.group(1).replace(".", "/");
        tgt_nid: any = _make_id(tgt);
        if tgt_nid not in {n["id"] for n in nodes} {
            nodes.append({
                "id": tgt_nid,
                "label": m.group(1),
                "file_type": "code",
                "source_file": `str(path),
                "source_location": None,
            });
        }
        edges.append({
            "source": file_nid,
            "target": tgt_nid,
            "relation": "extends",
            "confidence": "EXTRACTED",
            "confidence_score": 1.0,
            "source_file": `str(path),
            "source_location": None,
            "weight": 1.0,
        });
    }
    for m in re.finditer("@include\\(['\\\"]([^'\\\"]+)['\\\"]", src) {
        tgt = m.group(1).replace(".", "/");
        tgt_nid = _make_id(tgt);
        if tgt_nid not in {n["id"] for n in nodes} {
            nodes.append({
                "id": tgt_nid,
                "label": m.group(1),
                "file_type": "code",
                "source_file": `str(path),
                "source_location": None,
            });
        }
        edges.append({
            "source": file_nid,
            "target": tgt_nid,
            "relation": "includes",
            "confidence": "EXTRACTED",
            "confidence_score": 1.0,
            "source_file": `str(path),
            "source_location": None,
            "weight": 1.0,
        });
    }
    for m in re.finditer("<livewire:([\\w.\\-]+)", src) {
        tgt_nid = _make_id(m.group(1));
        if tgt_nid not in {n["id"] for n in nodes} {
            nodes.append({
                "id": tgt_nid,
                "label": m.group(1),
                "file_type": "code",
                "source_file": `str(path),
                "source_location": None,
            });
        }
        edges.append({
            "source": file_nid,
            "target": tgt_nid,
            "relation": "uses_component",
            "confidence": "EXTRACTED",
            "confidence_score": 1.0,
            "source_file": `str(path),
            "source_location": None,
            "weight": 1.0,
        });
    }
    for m in re.finditer("wire:click(?:\\.\\w+)*=[\"\\']([^\"\\']+)[\"\\']", src) {
        raw: any = m.group(1).strip();
        if raw.startswith("$") {
            continue;
        }
        name_match: any = re.match("[A-Za-z_]\\w*", raw);
        if not name_match {
            continue;
        }
        method_name: any = name_match.group(0);
        tgt_nid = _make_id(method_name);
        if tgt_nid not in {n["id"] for n in nodes} {
            nodes.append({
                "id": tgt_nid,
                "label": method_name,
                "file_type": "code",
                "source_file": `str(path),
                "source_location": None,
            });
        }
        edges.append({
            "source": file_nid,
            "target": tgt_nid,
            "relation": "binds_method",
            "confidence": "EXTRACTED",
            "confidence_score": 1.0,
            "source_file": `str(path),
            "source_location": None,
            "weight": 1.0,
        });
    }

    return {"nodes": nodes, "edges": edges};
}
