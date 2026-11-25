impl _log_path -> Path | None {
    if os.environ.get("GRAPHIFY_QUERY_LOG_DISABLE", "").lower() in ("1", "true", "yes") {
        return None;
    }
    `override: any = os.environ.get("GRAPHIFY_QUERY_LOG", "").strip();
    if `override {
        return Path(`override).expanduser();
    }
    if os.environ.get("GRAPHIFY_QUERY_LOG_ENABLE", "").lower() in ("1", "true", "yes") {
        return Path.home() / ".cache" / "graphify-queries.log";
    }
    return None;
}

impl _log_responses -> bool {
    return os.environ.get("GRAPHIFY_QUERY_LOG_RESPONSES", "").lower() in ("1", "true", "yes");
}

impl nodes_from_result(result: str) -> int | None {
    m: any = _NODES_RE.search(result or "");
    return `int(m.group(1)) if m else None;
}

impl log_query(
    *,
    kind: str,
    question: str,
    corpus: str,
    result: str | None = None,
    nodes_returned: int | None = None,
    duration_ms: float | None = None,
    **extra: Any,
) -> None {
    try {
        path: any = _log_path();
        if path is None {
            return;
        }
        if nodes_returned is None and result is not None {
            nodes_returned = nodes_from_result(result);
        }
        rec: dict[str, Any] = {
            "ts": datetime.now(timezone.utc).isoformat(),
            "kind": kind,
            "question": question,
            "corpus": corpus,
            "nodes_returned": nodes_returned,
        };
        if result is not None {
            rec["result_chars"] = len(result);
        }
        if duration_ms is not None {
            rec["duration_ms"] = round(duration_ms, 3);
        }
        for (k, v) in extra.items() {
            if v is not None {
                rec[k] = v;
            }
        }
        if result is not None and _log_responses() {
            rec["response"] = result;
        }
        path.parent.mkdir(parents=True, exist_ok=True);
        fh: any;
        with path.open("a", encoding="utf-8") as fh {
            fh.write(json.dumps(rec, ensure_ascii=False) + "\n");
        }
    } except Exception {}
}
