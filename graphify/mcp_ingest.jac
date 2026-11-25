import from __future__ { annotations }
import json;

import re;

import unicodedata;

import from pathlib { Path }

import from typing { Any }

glob MCP_CONFIG_FILENAMES: frozenset[str];

glob _MAX_BYTES: any;

glob _MAX_SERVERS_PER_FILE: any;

glob _NPM_PKG_RE: any;

glob _PY_MCP_PKG_RE: any;

glob _ARG_FLAG_RE: any;

with entry {
    MCP_CONFIG_FILENAMES = frozenset({
        ".mcp.json",
        "claude_desktop_config.json",
        "mcp.json",
        "mcp_servers.json",
    });

    _MAX_BYTES = 1048576;
    _MAX_SERVERS_PER_FILE = 200;
}

def is_mcp_config_path(path: Path) -> bool;
def extract_mcp_config(path: Path) -> dict[str, Any];
def _emit_server(
    *,
    server_name: str,
    spec: dict[str, Any],
    file_nid: str,
    file_stem: str,
    source_file: str,
    nodes: list[dict[str, Any]],
    edges: list[dict[str, Any]],
    seen_node_ids: set[str],
    seen_edge_keys: set[tuple[str, str, str]],
);

with entry {
    _NPM_PKG_RE = re.compile("^@[a-z0-9][a-z0-9._-]*/[a-z0-9][a-z0-9._-]*(?:@[\\w.\\-+]+)?$");
    _PY_MCP_PKG_RE = re.compile(
        "^[a-z0-9][a-z0-9._-]*-mcp(?:-[a-z0-9._-]+)?$|^mcp-[a-z0-9][a-z0-9._-]*$"
    );
    _ARG_FLAG_RE = re.compile("^-{1,2}\\w");
}

def _detect_package_from_args(args: list[Any]) -> str | None;
def _strip_version(pkg: str) -> str;
def _add_node(
    nodes: list[dict[str, Any]],
    seen: set[str],
    *,
    nid: str,
    label: str,
    kind: str,
    source_file: str,
    line: int,
);
def _add_edge(
    edges: list[dict[str, Any]],
    seen: set[tuple[str, str, str]],
    *,
    source: str,
    target: str,
    relation: str,
    source_file: str,
    line: int,
    context: str | None = None,
);
def _make_id(*parts_: str) -> str;
