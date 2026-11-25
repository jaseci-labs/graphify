impl _max_graph_file_bytes -> int {
    raw: any = os.environ.get("GRAPHIFY_MAX_GRAPH_BYTES", "").strip();
    if not raw {
        return _MAX_GRAPH_FILE_BYTES;
    }
    text: any = raw.upper();
    multiplier: any = 1;
    if text.endswith("GB") {
        multiplier = 1024 * 1024 * 1024;
        text = text[:-2].strip();
    } elif text.endswith("MB") {
        multiplier = 1024 * 1024;
        text = text[:-2].strip();
    }
    try {
        value: any = `int(text);
    } except ValueError {
        return _MAX_GRAPH_FILE_BYTES;
    }
    if value <= 0 {
        return _MAX_GRAPH_FILE_BYTES;
    }
    return value * multiplier;
}

impl _ip_is_blocked(ip: ipaddress.IPv4Address | ipaddress.IPv6Address) -> bool {
    if isinstance(ip, ipaddress.IPv6Address) and ip in _NAT64_WKP {
        ip = ipaddress.ip_address(`int(ip) & 4294967295);
    }
    return ip.is_private
        or ip.is_reserved
        or ip.is_loopback
        or ip.is_link_local
        or ip.is_multicast
        or ip.is_unspecified
        or ip in _CGN_NETWORK;
}

impl validate_url(url: str) -> str {
    parsed: any = urllib.parse.urlparse(url);
    if parsed.scheme.lower() not in _ALLOWED_SCHEMES {
        raise ValueError(
            f"Blocked URL scheme '{parsed.scheme}' - only http and https are allowed. Got: {url!r}"
        );
    }

    if parsed.username is not None or parsed.password is not None {
        raise ValueError(f"Blocked URL containing embedded credentials. Got: {url!r}");
    }

    try {
        port: any = parsed.port;
    } except ValueError as exc {
        raise ValueError(f"Blocked URL with an invalid port. Got: {url!r}") from exc;
    }
    if port == 0 {
        raise ValueError(f"Blocked URL with port 0. Got: {url!r}");
    }

    hostname: any = parsed.hostname;
    if not hostname {
        raise ValueError(f"Blocked URL without a hostname. Got: {url!r}");
    }

    if hostname {
        if hostname.lower() in _BLOCKED_HOSTS {
            raise ValueError(f"Blocked cloud metadata endpoint '{hostname}'. Got: {url!r}");
        }
        try {
            infos: any = socket.getaddrinfo(hostname, None, socket.AF_UNSPEC, socket.SOCK_STREAM);
            for info in infos {
                addr: any = info[4][0];
                ip: any = ipaddress.ip_address(addr);
                if _ip_is_blocked(ip) {
                    raise ValueError(
                        f"Blocked private/internal IP {addr} (resolved from '{hostname}'). Got: {url!r}",
                    );
                }
            }
        } except socket.gaierror as exc {
            raise ValueError(
                f"DNS resolution failed for '{hostname}': {exc}. Got: {url!r}"
            ) from exc;
        }
    }

    return url;
}

impl _resolve_and_validate(host: str, port: int) -> tuple[int, str] {
    infos: any = socket.getaddrinfo(host, port, socket.AF_UNSPEC, socket.SOCK_STREAM);
    for (family, _type, _proto, _canon, sockaddr) in infos {
        addr: any = sockaddr[0];
        try {
            ip: any = ipaddress.ip_address(addr);
        } except ValueError {
            continue;
        }
        if _ip_is_blocked(ip) {
            raise OSError(f"SSRF blocked: IP {addr} resolved from '{host}' is private/reserved");
        }
        return (family, addr);
    }
    raise OSError(f"SSRF blocked: no usable address resolved from '{host}'");
}

impl _SSRFGuardedHTTPConnection.connect {
    family: any;
    ip: any;
    (family, ip) = _resolve_and_validate(self.host, self.port) as any;
    self.sock = socket.create_connection((ip, self.port), self.timeout, self.source_address);
    if self._tunnel_host {
        self._tunnel();
    }
}

impl _SSRFGuardedHTTPSConnection.connect {
    family: any;
    ip: any;
    (family, ip) = _resolve_and_validate(self.host, self.port) as any;
    sock: any = socket.create_connection((ip, self.port), self.timeout, self.source_address);
    if self._tunnel_host {
        self.sock = sock;
        self._tunnel();
        sock = self.sock;
    }
    self.sock = self._context.wrap_socket(sock, server_hostname=self.host);
}

impl _SSRFGuardedHTTPHandler.http_open(req) -> any {
    return self.do_open(_SSRFGuardedHTTPConnection, req);
}

impl _SSRFGuardedHTTPSHandler.https_open(req) -> any {
    return self.do_open(_SSRFGuardedHTTPSConnection, req);
}

impl _NoFileRedirectHandler.redirect_request(req, fp, code, msg, headers, newurl) -> any {
    validate_url(newurl);
    return super.redirect_request(req, fp, code, msg, headers, newurl);
}

impl _build_opener -> urllib.request.OpenerDirector {
    return urllib.request.build_opener(
        _SSRFGuardedHTTPHandler, _SSRFGuardedHTTPSHandler, _NoFileRedirectHandler
    );
}

impl safe_fetch(url: str, max_bytes: int = max_bytes_default_, timeout: int = 30) -> bytes {
    validate_url(url);
    opener: any = _build_opener();
    req: any = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 graphify/1.0"});

    resp: any;
    with opener.open(req, timeout=timeout) as resp {
        status: any = getattr(resp, "status", None) or getattr(resp, "code", None);
        if status is not None and not 200 <= status < 300 {
            raise urllib.error.HTTPError(url, status, f"HTTP {status}", {}, None);
        }

        chunks: list[bytes] = [];
        total: any = 0;
        while True {
            chunk: any = resp.read(65536);
            if not chunk {
                break;
            }
            total += len(chunk);
            if total > max_bytes {
                raise OSError(
                    f"Response from {url!r} exceeds size limit ({max_bytes // 1048576} MB). Aborting download.",
                );
            }
            chunks.append(chunk);
        }
    }

    return b"".join(chunks);
}

impl safe_fetch_text(url: str, max_bytes: int = max_bytes_default__, timeout: int = 15) -> str {
    raw: any = safe_fetch(url, max_bytes=max_bytes, timeout=timeout);
    return raw.decode("utf-8", errors="replace");
}

impl validate_graph_path(path: str | Path, base: Path | None = None) -> Path {
    if base is None {
        resolved_hint: any = Path(path).resolve();
        for candidate in [resolved_hint, *resolved_hint.parents] {
            if candidate.name == GRAPHIFY_OUT_NAME {
                base = candidate;
                break;
            }
        }
        if base is None {
            base = Path(GRAPHIFY_OUT).resolve();
        }
    }

    base = base.resolve();
    if not base.exists() {
        raise ValueError(
            f"Graph base directory does not exist: {base}. Run /graphify first to build the graph."
        );
    }

    resolved: any = Path(path).resolve();
    try {
        resolved.relative_to(base);
    } except ValueError {
        raise ValueError(
            f"Path {path!r} escapes the allowed directory {base}. Only paths inside graphify-out/ are permitted.",
        );
    }

    if not resolved.exists() {
        raise FileNotFoundError(f"Graph file not found: {resolved}");
    }

    return resolved;
}

impl check_graph_file_size_cap(path: Path) {
    cap: any = _max_graph_file_bytes();
    try {
        size: any = path.stat().st_size;
    } except OSError {
        return;
    }
    if size > cap {
        raise ValueError(
            f"graph file {path} is {size:_d} bytes, exceeds {cap:_d}-byte cap\n(set GRAPHIFY_MAX_GRAPH_BYTES=<bytes> or GRAPHIFY_MAX_GRAPH_BYTES=<N>GB to raise the limit)",
        );
    }
}

impl redact_secrets(text: str | None) -> str {
    if not text {
        return "" if text is None else text;
    }
    return _SECRET_SHAPE_RE.sub(REDACTED_MARKER, `str(text));
}

impl sanitize_label(text: str | None) -> str {
    if text is None {
        return "";
    }
    clean = typing.cast(object, _CONTROL_CHAR_RE).sub("", `str(text));
    if len(clean) > _MAX_LABEL_LEN {
        clean = clean[:_MAX_LABEL_LEN];
    }
    return clean;
}

impl _sanitize_metadata_string(value: object) -> str {
    text: any = _CONTROL_CHAR_RE.sub("", `str(value));
    text = html.escape(text, quote=True);
    if len(text) > _METADATA_MAX_VALUE_LEN {
        text = text[:_METADATA_MAX_VALUE_LEN];
    }
    return text;
}

impl _sanitize_metadata_value(value: object) -> object {
    if isinstance(value, `bool) {
        return value;
    }
    if isinstance(value, `str) {
        return _sanitize_metadata_string(value);
    }
    if isinstance(value, `dict) {
        return sanitize_metadata(value);
    }
    if isinstance(value, (`list, `tuple)) {
        return [_sanitize_metadata_value(item) for item in value[:_METADATA_MAX_LIST_ITEMS]];
    }
    if isinstance(value, (`int, `float)) or value is None {
        return value;
    }
    return _sanitize_metadata_string(value);
}

impl sanitize_metadata(metadata: Mapping[str, Any] | None) -> dict[str, object] {
    if metadata is None {
        return {};
    }

    result: dict[str, object] = {};
    for (key, value) in metadata.items() {
        clean_key: any = _sanitize_metadata_string(key);
        if not clean_key {
            continue;
        }
        result[clean_key] = _sanitize_metadata_value(value);
    }
    return result;
}
