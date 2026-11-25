"""mcp_ingest.py — Extract MCP (Model Context Protocol) server configuration files.

Reads `.mcp.json` / `claude_desktop_config.json` / `mcp.json` / `mcp_servers.json`
and turns the `mcpServers` map into Graphify nodes and edges.

Symmetry with `serve.py`: Graphify exposes itself AS an MCP server. This module
indexes MCP servers AS a corpus type, completing the loop — an agent that runs
graphify with `--mcp` can now query its own configured MCP layer.

Entry point:
  extract_mcp_config(path: Path) -> dict[str, list[dict]]

  Returns `{"nodes": [...], "edges": [...]}` compatible with Graphify's
  extraction-result format. Returns `{"nodes": [...], "edges": [...], "error": "..."}`
  when the file is malformed, too large, or has no `mcpServers` map — the empty
  result keeps it indistinguishable from "no MCP config here" for downstream
  callers.

Detected filenames (case-sensitive, matched on basename):
  - .mcp.json                       (Claude Code project config)
  - claude_desktop_config.json      (Claude Desktop)
  - mcp.json                        (generic / per-tool)
  - mcp_servers.json                (alternate naming)

Schema emitted:
  Node kinds:
    - file              the config file itself (label = filename)
    - mcp_server        one per entry under mcpServers
    - mcp_command       executable (npx, uvx, node, python, ...) — global ID
    - mcp_package       npm / pypi package id parsed from args — global ID
    - env_var           env variable NAME only — global ID. VALUES ARE NEVER READ.

  Edge relations:
    - contains          file -> mcp_server
    - references        mcp_server -> mcp_command
    - references        mcp_server -> mcp_package
    - requires_env      mcp_server -> env_var   (new relation; distinguishes
                                                  env dependencies from generic refs)

Security:
  - Env var VALUES are never read, persisted, labelled, or surfaced. Only env
    var NAMES become nodes. (`env: {"API_KEY": "sk-..."}` -> node "API_KEY" only.)
  - File size capped at 1 MiB (matches extract_json).
  - All labels go through `sanitize_label` (control characters stripped, length
    capped) before emission.
  - Args are NOT persisted as nodes/edges to avoid leaking paths or secrets that
    some servers embed as positional args.

Cross-config emergent edges:
  Because `mcp_command`, `mcp_package`, and `env_var` nodes use global IDs (no
  per-file stem prefix), the same package or env var across two MCP configs
  produces shared nodes — naturally surfacing "what configs depend on this
  thing?" via graph traversal. Server nodes ARE stem-scoped so two configs
  declaring different servers under the same key (e.g., both have "filesystem")
  do not collide.
"""

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

"""Return True when ``path`` is a recognised MCP config filename."""
def is_mcp_config_path(path: Path) -> bool;

"""Parse an MCP config file into Graphify nodes and edges.

    Behaviour matches other extractors in `extract.py`:
      - returns ``{"nodes": [...], "edges": [...]}`` on success
      - returns ``{"nodes": [], "edges": [], "error": "<reason>"}`` on parse
        failure, oversize file, or missing ``mcpServers`` map
    """
def extract_mcp_config(path: Path) -> dict[str, Any];

"""Emit nodes/edges for one entry under ``mcpServers``."""
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
) -> None;

with entry {
    _NPM_PKG_RE = re.compile("^@[a-z0-9][a-z0-9._-]*/[a-z0-9][a-z0-9._-]*(?:@[\\w.\\-+]+)?$");
    _PY_MCP_PKG_RE = re.compile(
        "^[a-z0-9][a-z0-9._-]*-mcp(?:-[a-z0-9._-]+)?$|^mcp-[a-z0-9][a-z0-9._-]*$"
    );
    _ARG_FLAG_RE = re.compile("^-{1,2}\\w");
}

"""Return the first arg that looks like an npm or pypi package id, else None.

    Skips short flags (-y, --yes) and option arguments (--local-timezone=UTC).
    """
def _detect_package_from_args(args: list[Any]) -> str | None;

"""Drop the ``@version`` suffix from an npm package id, preserving the scope.

    Scoped:   ``@scope/name`` or ``@scope/name@1.2.3`` — there are at most two
              ``@`` chars; the second is the version separator.
    Unscoped: ``name`` or ``name@1.2.3``.
    """
def _strip_version(pkg: str) -> str;

"""Append a node if not already present. ``kind`` is metadata, not file_type."""
def _add_node(
    nodes: list[dict[str, Any]],
    seen: set[str],
    *,
    nid: str,
    label: str,
    kind: str,
    source_file: str,
    line: int,
) -> None;

"""Append an edge if (source, target, relation) is not already present."""
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
) -> None;

"""Build a stable node ID via the single shared recipe (#1378)."""
def _make_id(*parts_: str) -> str;
