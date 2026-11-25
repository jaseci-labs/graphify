"""Verilog extractor. Moved verbatim from graphify/extract.py."""

import from __future__ { annotations }

import re;

import from pathlib { Path }

"""First `simple_identifier` under node in pre-order, or None.

    tree-sitter-verilog 1.0.3 nests declaration names a few levels deep instead
    of exposing a `name` field. Scope the search to the right child node (e.g.
    `function_identifier`) or this returns the return-type instead of the name.
    """
def _sv_first_identifier(`node, source: bytes) -> str | None;

def _sv_child(`node, type_name: str) -> object | None;

glob _SV_BUILTIN_TYPES: any;

glob _SV_NON_TYPE_WORDS: any;

glob _SV_PARENS_INNER: any;

glob _SV_PARENS: any;

glob _SV_FUNC_RE: any;

glob _SV_TASK_RE: any;

glob _SV_PARAM_RE: any;

with entry {
    _SV_BUILTIN_TYPES = frozenset({
        "bit",
        "logic",
        "reg",
        "wire",
        "int",
        "integer",
        "shortint",
        "longint",
        "byte",
        "time",
        "real",
        "shortreal",
        "void",
        "string",
        "type",
        "event",
        "mailbox",
        "semaphore",
        "process",
        "chandle",
    });

    _SV_NON_TYPE_WORDS = frozenset({
        "return",
        "if",
        "else",
        "for",
        "foreach",
        "while",
        "case",
        "begin",
        "end",
        "function",
        "task",
        "class",
        "endclass",
        "endfunction",
        "endtask",
    });

    _SV_PARENS_INNER = "(?:[^()]|\\([^()]*\\))*";

    _SV_PARENS = "\\(" + _SV_PARENS_INNER + "\\)";
    _SV_FUNC_RE = re.compile(
        "\\bfunction\\s+(?:([A-Za-z_]\\w*(?:\\s*#\\s*"
            + _SV_PARENS
            + ")?)\\s+)?(\\w+)\\s*\\(("
            + _SV_PARENS_INNER
            + ")\\)\\s*;",
        re.MULTILINE,
    );
    _SV_TASK_RE = re.compile(
        "\\btask\\s+(\\w+)\\s*\\((" + _SV_PARENS_INNER + ")\\)\\s*;", re.MULTILINE
    );

    _SV_PARAM_RE = re.compile(
        "\\s*(?:input|output|inout|ref|const\\s+ref)?\\s*([A-Za-z_]\\w*(?:\\s*#\\s*"
            + _SV_PARENS
            + ")?)\\s+\\w+",
    );
}

def _sv_strip_comments(text: str) -> str;

def _sv_split_type_list(text: str) -> list[str];

glob skip_default_: any;

with entry {
    skip_default_ = frozenset();
}

def _sv_collect_type_refs(
    type_text: str, generic: bool = False, `skip: frozenset[str] = skip_default_
) -> list[tuple[str, str]];

def _augment_systemverilog_semantics(
    raw: str,
    stem: str,
    str_path: str,
    file_nid: str,
    nodes: list[dict],
    edges: list[dict],
    seen_ids: set[str],
) -> None;

"""Extract modules, functions, tasks, package imports, instantiations, and
    SystemVerilog class semantics (inherits/implements edges, field/parameter/
    return-type references) from .v/.sv files."""
def extract_verilog(path: Path) -> dict;
