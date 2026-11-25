import from __future__ { annotations }

import html;

import http.client;

import os;

import re;

import urllib.error;

import urllib.parse;

import urllib.request;

import from collections.abc { Mapping }

import from pathlib { Path }

import from typing { Any }

import ipaddress;

import socket;

glob _ALLOWED_SCHEMES: any = {"http", "https"};

glob _MAX_FETCH_BYTES: any = 52428800;

glob _MAX_TEXT_BYTES: any = 10485760;

glob _MAX_GRAPH_FILE_BYTES: any;

glob _BLOCKED_HOSTS: any;

glob _CGN_NETWORK: any;

glob _NAT64_WKP: any;

glob _CONTROL_CHAR_RE: any;

glob _MAX_LABEL_LEN: any;

glob _SECRET_SHAPE_RE: any;

glob REDACTED_MARKER: any;

glob _METADATA_MAX_VALUE_LEN: any;

glob _METADATA_MAX_LIST_ITEMS: any;

glob _METADATA_MAX_ATTRIBUTES: any;

with entry {
    _MAX_GRAPH_FILE_BYTES = 512 * 1024 * 1024;
}

"""Return the graph.json size cap in bytes.

    Honors the ``GRAPHIFY_MAX_GRAPH_BYTES`` environment variable so users with
    large codebases can raise the limit without editing source. The value may
    be plain bytes (``671088640``) or carry an ``MB`` / ``GB`` suffix
    (``640MB``, ``2GB`` — case-insensitive, binary multipliers: ``MB`` is
    1024*1024 and ``GB`` is 1024*1024*1024, i.e. MiB / GiB).
    Falls back to ``_MAX_GRAPH_FILE_BYTES`` (512 MiB) when the env var is unset,
    blank, or unparseable.

    Read fresh on every call so the env var can be set before import and still
    take effect.
    """
def _max_graph_file_bytes -> int;

with entry {
    _BLOCKED_HOSTS = {"metadata.google.internal", "metadata.google.com"};
    _CGN_NETWORK = ipaddress.ip_network("100.64.0.0/10");
    _NAT64_WKP = ipaddress.ip_network("64:ff9b::/96");
}

"""Return True if *ip* falls in a private/reserved/internal range.

    Shared by validate_url (pre-flight DNS check) and the SSRF-guarded
    connection classes (connect-time check) so both use identical logic.
    NAT64 well-known-prefix addresses are unwrapped to their embedded IPv4
    before the check, since those carry legitimate public traffic.
    """
def _ip_is_blocked(ip: ipaddress.IPv4Address | ipaddress.IPv6Address) -> bool;

"""Raise ValueError if *url* is not http or https, or targets a private/internal IP.

    Blocks file://, ftp://, data:, and any other scheme that could be used
    for SSRF or local file access. Also blocks requests to private/reserved
    IP ranges (127.x, 10.x, 169.254.x, etc.) and cloud metadata endpoints
    to prevent SSRF in cloud environments.
    """
def validate_url(url: str) -> str;

"""Resolve *host* once and return (family, validated_ip) for the first
    address that is not in a blocked range.

    Raises OSError if every resolved address is private/reserved/internal,
    matching the failure mode urllib/http.client expect from connect().
    """
def _resolve_and_validate(host: str, port: int) -> tuple[int, str];

"""HTTPConnection that resolves + validates DNS once, then connects to the
    exact validated IP (no second resolution = no DNS-rebind TOCTOU)."""
class _SSRFGuardedHTTPConnection(http.client.HTTPConnection) {
    def connect -> None;
}

"""HTTPSConnection variant of _SSRFGuardedHTTPConnection.

    Connects to the validated IP but performs the TLS handshake with
    server_hostname set to the original hostname so SNI / certificate
    validation work correctly (validating against the IP would break TLS).
    """
class _SSRFGuardedHTTPSConnection(http.client.HTTPSConnection) {
    def connect -> None;
}

"""urllib handler that routes http:// through _SSRFGuardedHTTPConnection."""
class _SSRFGuardedHTTPHandler(urllib.request.HTTPHandler) {
    def http_open(req) -> any;
}

"""urllib handler that routes https:// through _SSRFGuardedHTTPSConnection."""
class _SSRFGuardedHTTPSHandler(urllib.request.HTTPSHandler) {
    def https_open(req) -> any;
}

"""Redirect handler that re-validates every redirect target.

    Prevents open-redirect SSRF attacks where an http:// URL redirects
    to file:// or an internal address.
    """
class _NoFileRedirectHandler(urllib.request.HTTPRedirectHandler) {
    def redirect_request(req, fp, code, msg, headers, newurl) -> any;
}

def _build_opener -> urllib.request.OpenerDirector;

glob max_bytes_default_: any;

with entry {
    max_bytes_default_ = _MAX_FETCH_BYTES;
}

"""Fetch *url* and return raw bytes.

    Protections applied:
    - URL scheme validated (http / https only)
    - Redirects re-validated via _NoFileRedirectHandler
    - Response body capped at *max_bytes* (streaming read)
    - Non-2xx status raises urllib.error.HTTPError
    - Network errors propagate as urllib.error.URLError / OSError

    Raises:
        ValueError        - disallowed scheme or redirect target
        urllib.error.HTTPError  - non-2xx HTTP status
        urllib.error.URLError   - DNS / connection failure
        OSError               - size cap exceeded
    """
def safe_fetch(url: str, max_bytes: int = max_bytes_default_, timeout: int = 30) -> bytes;

glob max_bytes_default__: any;

with entry {
    max_bytes_default__ = _MAX_TEXT_BYTES;
}

"""Fetch *url* and return decoded text (UTF-8, replacing bad bytes).

    Wraps safe_fetch with tighter defaults for HTML / text content.
    """
def safe_fetch_text(url: str, max_bytes: int = max_bytes_default__, timeout: int = 15) -> str;

"""Resolve *path* and verify it stays inside *base*.

    *base* defaults to the `graphify-out` directory relative to CWD.
    Also requires the base directory to exist, so a caller cannot
    trick graphify into reading files before any graph has been built.

    Raises:
        ValueError  - path escapes base, or base does not exist
        FileNotFoundError - resolved path does not exist
    """
def validate_graph_path(path: str | Path, base: Path | None = None) -> Path;

"""Reject *path* if its size exceeds the configured graph-file cap.

    Protects callers from memory bombs by failing fast before a multi-GiB
    graph.json is read into memory and JSON-parsed. Silently returns when
    ``path.stat()`` cannot be read — the caller's own existence/path check
    is expected to surface a clearer error in that case.

    The cap is resolved on every call via :func:`_max_graph_file_bytes`, so the
    ``GRAPHIFY_MAX_GRAPH_BYTES`` env var can be set before import and still
    apply.

    Raises:
        ValueError - file size exceeds the cap. The message includes the
        observed size, the cap, and how to raise the limit.
    """
def check_graph_file_size_cap(path: Path) -> None;

with entry {
    _CONTROL_CHAR_RE = re.compile("[\\x00-\\x1f\\x7f]");
    _MAX_LABEL_LEN = 256;
    _SECRET_SHAPE_RE = re.compile(
        "(?s:-----BEGIN [A-Z0-9 ]*PRIVATE KEY(?: BLOCK)?-----(?:.*?-----END [A-Z0-9 ]*PRIVATE KEY(?: BLOCK)?-----|.*))|(?<![A-Za-z0-9])(?:AKIA|ASIA)[0-9A-Z]{16}(?![A-Za-z0-9])|(?<![A-Za-z0-9])gh[pousr]_[A-Za-z0-9]{36,}|(?<![A-Za-z0-9])github_pat_[A-Za-z0-9_]{22,}|(?<![A-Za-z0-9])xox[abeoprs]-[A-Za-z0-9-]{10,}|(?<![A-Za-z0-9])[sr]k_(?:live|test)_[A-Za-z0-9]{10,}|(?<![A-Za-z0-9])sk-(?:ant-|proj-)?(?=[A-Za-z0-9_-]*[0-9])[A-Za-z0-9_-]{20,}|(?<![A-Za-z0-9])AIza[0-9A-Za-z_-]{35}|(?<![A-Za-z0-9])eyJ[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{2,}\\.[A-Za-z0-9_-]{10,}|(?<=\\bBearer )[A-Za-z0-9._~+/=-]{16,}|(?<=://)[^\\s/@]*:[^\\s?#]*(?=@[^\\s@/?#]+)",
    );

    REDACTED_MARKER = "[redacted]";
}

"""Replace credential-shaped substrings in *text* with ``[redacted]``.

    Applied to free text copied out of source files (docstrings and ``# WHY:``
    style comments) before it becomes a node label, so a token pasted into a
    comment does not land in graph.json / graph.html / GRAPH_REPORT.md.
    """
def redact_secrets(text: str | None) -> str;

"""Strip control characters and cap length.

    Safe for embedding in JSON data (inside <script> tags) and plain text.
    For direct HTML injection, wrap the result with html.escape().
    """
def sanitize_label(text: str | None) -> str;

with entry {
    _METADATA_MAX_VALUE_LEN = 512;
    _METADATA_MAX_LIST_ITEMS = 50;
    _METADATA_MAX_ATTRIBUTES = 100;
}

"""Return a control-character-free, HTML-escaped, bounded string."""
def _sanitize_metadata_string(value: object) -> str;

"""Sanitize a metadata value while preserving simple JSON-compatible types."""
def _sanitize_metadata_value(value: object) -> object;

"""Sanitize metadata keys and values before graph export.

    Metadata is less constrained than node labels: it can contain nested
    dicts, lists, source snippets, external index symbols, and docstring
    text. This helper keeps the data JSON-compatible, strips control
    characters, escapes HTML-sensitive characters in strings, caps long
    strings/lists, and drops entries whose key becomes empty after
    sanitization.
    """
def sanitize_metadata(metadata: Mapping[str, Any] | None) -> dict[str, object];
