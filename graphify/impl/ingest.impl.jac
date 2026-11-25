impl _yaml_str(s: str) -> str {
    out: list[str];
    if s is None {
        return "";
    }
    out = [];
    for ch in `str(s) {
        cp: any = ord(ch);
        if ch == "\\" {
            out.append("\\\\");
        } elif ch == "\"" {
            out.append("\\\"");
        } elif ch == "\n" {
            out.append("\\n");
        } elif ch == "\r" {
            out.append("\\r");
        } elif ch == "\t" {
            out.append("\\t");
        } elif ch == "\x00" {
            out.append("\\0");
        } elif cp == 8232 {
            out.append("\\L");
        } elif cp == 8233 {
            out.append("\\P");
        } elif cp < 32 or cp == 127 {
            out.append(f"\\x{cp:02x}");
        } else {
            out.append(ch);
        }
    }
    return "".join(out);
}

impl _safe_filename(url: str, suffix: str) -> str {
    parsed: any = urllib.parse.urlparse(url);
    name: any = parsed.netloc + parsed.path;
    name = re.sub("[^\\w\\-]", "_", name).strip("_");
    name = re.sub("_+", "_", name)[:80];
    return name + suffix;
}

impl _host_is(host: str, *domains_: str) -> bool {
    domains: any = tuple(domains_);
    return `any(operator.eq(host, domain) or host.endswith(f".{domain}") for domain in domains);
}

impl _detect_url_type(url: str) -> str {
    path: any;
    parsed: any = urllib.parse.urlparse(url);
    host: any = (parsed.hostname or "").rstrip(".");
    if _host_is(host, "twitter.com", "x.com") {
        return "tweet";
    }
    if _host_is(host, "arxiv.org") {
        return "arxiv";
    }
    if _host_is(host, "github.com") {
        return "github";
    }
    if _host_is(host, "youtube.com", "youtu.be") {
        return "youtube";
    }
    path = parsed.path.lower();
    if path.endswith(".pdf") {
        return "pdf";
    }
    if `any(path.endswith(ext) for ext in (".png", ".jpg", ".jpeg", ".webp", ".gif")) {
        return "image";
    }
    return "webpage";
}

impl _fetch_html(url: str) -> str {
    return safe_fetch_text(url);
}

impl _html_to_markdown(html: str, url: str) -> str {
    html = re.sub("<script[^>]*>.*?</script>", "", html, flags=re.DOTALL | re.IGNORECASE);
    html = re.sub("<style[^>]*>.*?</style>", "", html, flags=re.DOTALL | re.IGNORECASE);
    try {
        import from markdownify { markdownify }
        return markdownify(html, heading_style="ATX", bullets="-", strip=["img"]);
    } except ImportError {
        text: any = re.sub("<[^>]+>", " ", html);
        text = re.sub("\\s+", " ", text).strip();
        return text[:8000];
    }
}

impl _fetch_tweet(url: str, author: str | None, contributor: str | None) -> tuple[str, str] {
    parts: any = urllib.parse.urlsplit(url);
    host: any = (parts.hostname or "").rstrip(".");
    if _host_is(host, "x.com") {
        host = host[:-len("x.com")] + "twitter.com";
        netloc: any = f"{host}:{parts.port}" if parts.port else host;
        parts = parts._replace(netloc=netloc);
    }
    oembed_url: any = urllib.parse.urlunsplit(parts);
    oembed_api: any = f"https://publish.twitter.com/oembed?url={urllib.parse.quote(oembed_url)}&omit_script=true";
    try {
        data: any = json.loads(safe_fetch_text(oembed_api));
        tweet_text: any = re.sub("<[^>]+>", "", data.get("html", "")).strip();
        tweet_author: any = data.get("author_name", "unknown");
    } except Exception {
        tweet_text = f"Tweet at {url} (could not fetch content)";
        tweet_author = "unknown";
    }

    now: any = datetime.now(timezone.utc).isoformat();
    content: any = "---\nsource_url: \""
        + format(_yaml_str(url), "")
        + "\"\ntype: tweet\nauthor: \""
        + format(_yaml_str(tweet_author), "")
        + "\"\ncaptured_at: "
        + format(now, "")
        + "\ncontributor: \""
        + format(_yaml_str(contributor or author or "unknown"), "")
        + "\"\n---\n\n# Tweet by @"
        + format(tweet_author, "")
        + "\n\n"
        + format(tweet_text, "")
        + "\n\nSource: "
        + format(url, "")
        + "\n";
    filename: any = _safe_filename(url, ".md");
    return (content, filename);
}

impl _fetch_webpage(url: str, author: str | None, contributor: str | None) -> tuple[str, str] {
    html: any = _fetch_html(url);
    title_match: any = re.search("<title[^>]*>(.*?)</title>", html, re.IGNORECASE | re.DOTALL);
    title: any = re.sub("\\s+", " ", title_match.group(1)).strip() if title_match else url;

    markdown: any = _html_to_markdown(html, url);
    now: any = datetime.now(timezone.utc).isoformat();
    content: any = "---\nsource_url: \""
        + format(_yaml_str(url), "")
        + "\"\ntype: webpage\ntitle: \""
        + format(_yaml_str(title), "")
        + "\"\ncaptured_at: "
        + format(now, "")
        + "\ncontributor: \""
        + format(_yaml_str(contributor or author or "unknown"), "")
        + "\"\n---\n\n# "
        + format(title, "")
        + "\n\nSource: "
        + format(url, "")
        + "\n\n---\n\n"
        + format(markdown[:12000], "")
        + "\n";
    filename: any = _safe_filename(url, ".md");
    return (content, filename);
}

impl _fetch_arxiv(url: str, author: str | None, contributor: str | None) -> tuple[str, str] {
    arxiv_id: any = re.search("(\\d{4}\\.\\d{4,5})", url);
    if arxiv_id {
        api_url: any = f"https://export.arxiv.org/abs/{arxiv_id.group(1)}";
        try {
            html: any = _fetch_html(api_url);
            abstract_match: any = re.search(
                "class=\"abstract[^\"]*\"[^>]*>(.*?)</blockquote>", html, re.DOTALL | re.IGNORECASE
            );
            abstract: any = re.sub("<[^>]+>", "", abstract_match.group(1)).strip()
                if abstract_match
                else "";
            title_match: any = re.search(
                "class=\"title[^\"]*\"[^>]*>(.*?)</h1>", html, re.DOTALL | re.IGNORECASE
            );
            title: any = re.sub("<[^>]+>", " ", title_match.group(1)).strip()
                if title_match
                else arxiv_id.group(1);
            authors_match: any = re.search(
                "class=\"authors\"[^>]*>(.*?)</div>", html, re.DOTALL | re.IGNORECASE
            );
            paper_authors: any = re.sub("<[^>]+>", "", authors_match.group(1)).strip()
                if authors_match
                else "";
        } except Exception {
            (title, abstract, paper_authors) = (arxiv_id.group(1), "", "");
        }
    } else {
        return _fetch_webpage(url, author, contributor);
    }

    now: any = datetime.now(timezone.utc).isoformat();
    content: any = "---\nsource_url: \""
        + format(_yaml_str(url), "")
        + "\"\narxiv_id: \""
        + format(_yaml_str(arxiv_id.group(1) if arxiv_id else ""), "")
        + "\"\ntype: paper\ntitle: \""
        + format(_yaml_str(title), "")
        + "\"\npaper_authors: \""
        + format(_yaml_str(paper_authors), "")
        + "\"\ncaptured_at: "
        + format(now, "")
        + "\ncontributor: \""
        + format(_yaml_str(contributor or author or "unknown"), "")
        + "\"\n---\n\n# "
        + format(title, "")
        + "\n\n**Authors:** "
        + format(paper_authors, "")
        + "\n**arXiv:** "
        + format(arxiv_id.group(1) if arxiv_id else url, "")
        + "\n\n## Abstract\n\n"
        + format(abstract, "")
        + "\n\nSource: "
        + format(url, "")
        + "\n";
    filename: any = "arxiv_" + format(arxiv_id.group(1).replace(".", "_"), "") + ".md"
        if arxiv_id
        else _safe_filename(url, ".md");
    return (content, filename);
}

impl _free_capture_path(target_dir: Path, filename: str) -> Path {
    stem: any;
    suffix: any;
    (stem, suffix) = (Path(filename).stem, Path(filename).suffix);
    out_path: any = target_dir / filename;
    counter: any = 1;
    while True {
        try {
            out_path.lstat();
        } except FileNotFoundError {
            return out_path;
        }
        out_path = target_dir / f"{stem}_{counter}{suffix}";
        counter += 1;
    }
}

impl _write_capture(target_dir: Path, filename: str, content: str | Callable[[], bytes]) -> Path {
    out_path: any = _free_capture_path(target_dir, filename);
    payload: any = content() if callable(content) else content;
    if isinstance(payload, `str) {
        payload = payload.replace("\n", linesep).encode("utf-8");
    }
    while True {
        try {
            handle: any = out_path.open("xb");
        } except FileExistsError {
            out_path = _free_capture_path(target_dir, filename);
            continue;
        }
        try {
            with handle {
                handle.write(payload);
            }
        } except (OSError, UnicodeError) {
            with suppress(OSError) {
                out_path.unlink();
            }
            raise;
        }
        return out_path;
    }
}

impl _download_binary(url: str, suffix: str, target_dir: Path) -> Path {
    return _write_capture(
        target_dir, _safe_filename(url, suffix), lambda -> any { safe_fetch(url) }
    );
}

impl ingest(
    url: str, target_dir: Path, author: str | None = None, contributor: str | None = None
) -> Path {
    out: any;
    target_dir.mkdir(parents=True, exist_ok=True);
    url_type: any = _detect_url_type(url);

    try {
        validate_url(url);
    } except ValueError as exc {
        raise ValueError(f"ingest: {exc}") from exc;
    }

    try {
        if url_type == "pdf" {
            out = _download_binary(url, ".pdf", target_dir);
            print(f"Downloaded PDF: {out.name}");
            return out;
        }

        if url_type == "image" {
            suffix: any = Path(urllib.parse.urlparse(url).path).suffix or ".jpg";
            out = _download_binary(url, suffix, target_dir);
            print(f"Downloaded image: {out.name}");
            return out;
        }

        if url_type == "youtube" {
            import from graphify.transcribe { download_audio }
            out = download_audio(url, target_dir);
            print(f"Downloaded audio: {out.name}");
            return out;
        }

        if url_type == "tweet" {
            content: any;
            filename: any;
            (content, filename) = _fetch_tweet(url, author, contributor) as any;
        } elif url_type == "arxiv" {
            (content, filename) = _fetch_arxiv(url, author, contributor) as any;
        } else {
            (content, filename) = _fetch_webpage(url, author, contributor) as any;
        }
    } except (urllib.error.HTTPError, urllib.error.URLError, OSError) as exc {
        raise RuntimeError(f"ingest: failed to fetch {url!r}: {exc}") from exc;
    }

    out_path: any = _write_capture(target_dir, filename, content);
    print(f"Saved {url_type}: {out_path.name}");
    return out_path;
}

impl save_query_result(
    question: str,
    answer: str,
    memory_dir: Path,
    query_type: str = "query",
    source_nodes: list[str] | None = None,
    outcome: str | None = None,
    correction: str | None = None,
) -> Path {
    if outcome is not None and outcome not in OUTCOMES {
        raise ValueError(f"outcome must be one of {OUTCOMES}, got {outcome!r}");
    }

    memory_dir = Path(memory_dir);
    memory_dir.mkdir(parents=True, exist_ok=True);

    now: any = datetime.now(timezone.utc);
    slug: any = re.sub("[^\\w]", "_", question.lower())[:50].strip("_");
    filename: any = "query_"
        + format(now.strftime("%Y%m%d_%H%M%S"), "")
        + "_"
        + format(uuid.uuid4().hex[:8], "")
        + "_"
        + format(slug, "")
        + ".md";

    frontmatter_lines: any = [
        "---",
        f"type: \"{query_type}\"",
        f"date: \"{now.isoformat()}\"",
        f"question: \"{_yaml_str(question)}\"",
        "contributor: \"graphify\"",
    ];
    if outcome {
        frontmatter_lines.append(f"outcome: \"{_yaml_str(outcome)}\"");
    }
    if correction {
        frontmatter_lines.append(f"correction: \"{_yaml_str(correction)}\"");
    }
    if source_nodes {
        nodes_str: any = ", ".join(f"\"{_yaml_str(n)}\"" for n in source_nodes[:10]);
        frontmatter_lines.append(f"source_nodes: [{nodes_str}]");
    }
    frontmatter_lines.append("---");

    body_lines: any = ["", f"# Q: {question}", "", "## Answer", "", answer];
    if outcome or correction {
        body_lines += ["", "## Outcome", ""];
        if outcome {
            body_lines.append(f"- Signal: {outcome}");
        }
        if correction {
            body_lines.append(f"- Correction: {correction}");
        }
    }
    if source_nodes {
        body_lines += ["", "## Source Nodes", ""];
        body_lines += [f"- {n}" for n in source_nodes];
    }

    content: any = "\n".join(frontmatter_lines + body_lines);
    out_path: any = memory_dir / filename;
    out_path.write_text(content, encoding="utf-8");
    return out_path;
}
