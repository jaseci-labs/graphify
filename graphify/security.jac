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

glob GRAPHIFY_OUT: any = _PATHS_OUT,
     GRAPHIFY_OUT_NAME: any = _PATHS_OUT_NAME;

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

def _max_graph_file_bytes -> int;

with entry {
    _BLOCKED_HOSTS = {"metadata.google.internal", "metadata.google.com"};
    _CGN_NETWORK = ipaddress.ip_network("100.64.0.0/10");
    _NAT64_WKP = ipaddress.ip_network("64:ff9b::/96");
}

def _ip_is_blocked(ip: ipaddress.IPv4Address | ipaddress.IPv6Address) -> bool;
def validate_url(url: str) -> str;
def _resolve_and_validate(host: str, port: int) -> tuple[int, str];

class _SSRFGuardedHTTPConnection(http.client.HTTPConnection) {
    def connect;
}

class _SSRFGuardedHTTPSConnection(http.client.HTTPSConnection) {
    def connect;
}

class _SSRFGuardedHTTPHandler(urllib.request.HTTPHandler) {
    def http_open(req) -> any;
}

class _SSRFGuardedHTTPSHandler(urllib.request.HTTPSHandler) {
    def https_open(req) -> any;
}

class _NoFileRedirectHandler(urllib.request.HTTPRedirectHandler) {
    def redirect_request(req, fp, code, msg, headers, newurl) -> any;
}

def _build_opener -> urllib.request.OpenerDirector;

glob max_bytes_default_: any;

with entry {
    max_bytes_default_ = _MAX_FETCH_BYTES;
}

def safe_fetch(url: str, max_bytes: int = max_bytes_default_, timeout: int = 30) -> bytes;

glob max_bytes_default__: any;

with entry {
    max_bytes_default__ = _MAX_TEXT_BYTES;
}

def safe_fetch_text(url: str, max_bytes: int = max_bytes_default__, timeout: int = 15) -> str;
def validate_graph_path(path: str | Path, base: Path | None = None) -> Path;
def check_graph_file_size_cap(path: Path);

with entry {
    _CONTROL_CHAR_RE = re.compile("[\\x00-\\x1f\\x7f]");
    _MAX_LABEL_LEN = 256;
    _SECRET_SHAPE_RE = re.compile(
        "(?s:-----BEGIN [A-Z0-9 ]*PRIVATE KEY(?: BLOCK)?-----(?:.*?-----END [A-Z0-9 ]*PRIVATE KEY(?: BLOCK)?-----|.*))|(?<![A-Za-z0-9])(?:AKIA|ASIA)[0-9A-Z]{16}(?![A-Za-z0-9])|(?<![A-Za-z0-9])gh[pousr]_[A-Za-z0-9]{36,}|(?<![A-Za-z0-9])github_pat_[A-Za-z0-9_]{22,}|(?<![A-Za-z0-9])xox[abeoprs]-[A-Za-z0-9-]{10,}|(?<![A-Za-z0-9])[sr]k_(?:live|test)_[A-Za-z0-9]{10,}|(?<![A-Za-z0-9])sk-(?:ant-|proj-)?(?=[A-Za-z0-9_-]*[0-9])[A-Za-z0-9_-]{20,}|(?<![A-Za-z0-9])AIza[0-9A-Za-z_-]{35}|(?<![A-Za-z0-9])eyJ[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{2,}\\.[A-Za-z0-9_-]{10,}|(?<=\\bBearer )[A-Za-z0-9._~+/=-]{16,}|(?<=://)[^\\s/@]*:[^\\s?#]*(?=@[^\\s@/?#]+)",
    );

    REDACTED_MARKER = "[redacted]";
}

def redact_secrets(text: str | None) -> str;
def sanitize_label(text: str | None) -> str;

with entry {
    _METADATA_MAX_VALUE_LEN = 512;
    _METADATA_MAX_LIST_ITEMS = 50;
    _METADATA_MAX_ATTRIBUTES = 100;
}

def _sanitize_metadata_string(value: object) -> str;
def _sanitize_metadata_value(value: object) -> object;
def sanitize_metadata(metadata: Mapping[str, Any] | None) -> dict[str, object];
