"""pascal — moved verbatim from graphify/extract.py."""

import operator;

import from __future__ { annotations }

import re;

import from pathlib { Path }

import from typing { Any, Callable }

glob _PAS_TOKEN_RE: any;

glob _PAS_MODULE_RE: any;

glob _PAS_USES_RE: any;

glob _PAS_TYPE_HEADER_RE: any;

glob _PAS_END_SEMI_RE: any;

glob _PAS_METHOD_DECL_RE: any;

glob _PAS_IMPL_HEADER_RE: any;

glob _PAS_BEGIN_END_TOKEN_RE: any;

glob _PAS_CALL_RE: any;

glob _PAS_KEYWORDS: any;

with entry {
    _PAS_TOKEN_RE = re.compile("'(?:''|[^'])*'|\\{[^}]*\\}|\\(\\*.*?\\*\\)|//[^\\n]*", re.DOTALL);

    _PAS_MODULE_RE = re.compile(
        "\\b(unit|program|library)\\s+([A-Za-z_][\\w.]*)\\s*;", re.IGNORECASE
    );

    _PAS_USES_RE = re.compile("\\buses\\b\\s*([^;]+);", re.IGNORECASE | re.DOTALL);

    _PAS_TYPE_HEADER_RE = re.compile(
        "\\b(?P<name>[A-Za-z_]\\w*)(?:\\s*<[^>]+>)?\\s*=\\s*(?:packed\\s+)?(?P<kind>class|interface|record)\\b(?:\\s*\\(\\s*(?P<bases>[^)]*)\\s*\\))?",
        re.IGNORECASE,
    );

    _PAS_END_SEMI_RE = re.compile("\\bend\\s*;", re.IGNORECASE);

    _PAS_METHOD_DECL_RE = re.compile(
        "\\b(?:procedure|function|constructor|destructor|operator)\\s+(?P<name>[A-Za-z_]\\w*)(?:\\s*\\([^)]*\\))?(?:\\s*:\\s*[\\w<>,\\s.]+)?\\s*;",
        re.IGNORECASE,
    );

    _PAS_IMPL_HEADER_RE = re.compile(
        "\\b(?:procedure|function|constructor|destructor|operator)\\s+(?P<qual>[A-Za-z_]\\w*(?:\\.[A-Za-z_]\\w*)?)(?:\\s*<[^>]+>)?(?:\\s*\\([^)]*\\))?(?:\\s*:\\s*[\\w<>,\\s.]+)?\\s*;",
        re.IGNORECASE,
    );

    _PAS_BEGIN_END_TOKEN_RE = re.compile("\\b(begin|end|case|try|asm|record)\\b", re.IGNORECASE);

    _PAS_CALL_RE = re.compile("\\b([A-Za-z_]\\w*(?:\\.[A-Za-z_]\\w*)*)\\s*[(;]");

    _PAS_KEYWORDS = frozenset({
        "begin",
        "end",
        "if",
        "then",
        "else",
        "while",
        "do",
        "for",
        "to",
        "downto",
        "repeat",
        "until",
        "case",
        "of",
        "try",
        "finally",
        "except",
        "with",
        "inherited",
        "result",
        "var",
        "const",
        "type",
        "nil",
        "true",
        "false",
        "exit",
        "break",
        "continue",
        "uses",
        "unit",
        "program",
        "library",
        "interface",
        "implementation",
        "initialization",
        "finalization",
        "procedure",
        "function",
        "constructor",
        "destructor",
        "operator",
        "class",
        "record",
        "object",
        "array",
        "string",
        "integer",
        "boolean",
        "real",
        "char",
        "writeln",
        "write",
        "readln",
        "read",
        "assigned",
        "length",
        "high",
        "low",
        "inc",
        "dec",
        "new",
        "dispose",
        "setlength",
        "copy",
        "pos",
        "trim",
        "format",
        "inttostr",
        "strtoint",
        "ord",
        "chr",
        "sizeof",
        "create",
        "free",
        "destroy",
    });
}

"""Strip Pascal comments ({}, (* *), //) while preserving newlines."""
def _pascal_strip_comments(text: str) -> str;

"""Split into (iface_text, iface_offset, impl_text, impl_offset).
    Files without interface/implementation sections (dpr/lpr/inc) return
    the whole text as impl with offset 0.
    """
def _pascal_split_sections(text: str) -> tuple[str, int, str, int];

"""Split a uses list string, handling 'Foo in ''bar.pas''' syntax."""
def _pascal_split_uses(s: str) -> list[str];

"""Split inheritance list, handling generics like TList<T, U>."""
def _pascal_split_bases(s: str) -> list[str];

"""Find balanced begin..end after start. Returns (body_start, body_end).
    Returns (0, 0) if no begin found.
    """
def _pascal_find_body(text: str, start: int) -> tuple[int, int];

"""Build a scoped call resolver for a single Pascal/Delphi file.

    ``records`` is the list of raw per-procedure tuples produced by either
    Pascal extractor; only the trailing ``(..., container, name_lower)``
    fields and the leading ``proc_nid`` are used, so both extractors' tuple
    shapes work unmodified (regex: proc_nid, line, body_text, container,
    name_lower; tree-sitter: proc_nid, body_node, container, name_lower).

    Resolution order for a call to ``name_lower`` from ``caller_nid``:
      1. A method declared on the caller's own class.
      2. A method declared on an ancestor class (BFS up ``inherits`` edges,
         which are already resolved by this point).
      3. A file-level free function (declared directly under the module).
      4. A global by-name match, but only when unambiguous (exactly one
         procedure with that name anywhere in the file).

    Returns None (no edge emitted) when the name is ambiguous at every
    level -- guessing at a same-named method on an unrelated class is worse
    than omitting the edge. Same-named methods on unrelated classes are a
    common Pascal/Delphi pattern (property accessors, generated wrapper
    classes such as TLB import units): without this scoping, a flat
    file-wide by-name lookup silently collapses onto whichever declaration
    happens to be inserted last, producing wrong cross-class edges. Mirrors
    the "god-node guard" already used by ``resolve_ruby_member_calls`` for
    the analogous Ruby ambiguous-method-name problem.
    """
def _resolve_pascal_callee_factory(
    records: list[tuple], edges: list[dict], module_nid: str
) -> Callable[[str, str], str | None];

"""Return ``(bytes inside ERROR nodes, -first error byte)``; lower is better.

    Error COUNT is the wrong measure here: tree-sitter answers a failure in the
    first declaration by wrapping the entire unit in one ERROR node, which by
    count (1) would outrank a parse that recovered everything but a handful of
    statements (68). Bytes swallowed by ERROR nodes tracks what the extractor
    actually loses. Only the outermost ERROR is measured -- its children are
    already inside it -- and the first error's position breaks ties, so a plain
    ``<`` comparison means "parses better".
    """
def _pascal_parse_health(`root) -> tuple[int, int];

"""Blank the leading escaped apostrophe of Pascal string literals.

    Returns ``None`` when the source holds no such literal. Each replacement is
    the same byte length as what it replaces, so every downstream offset, line
    and column is preserved.
    """
def _normalize_pascal_escaped_string_literals(source: bytes) -> bytes | None;

"""Disguise ``{$...}`` compiler directives as ordinary ``{...}`` comments."""
def _normalize_pascal_compiler_directives(source: bytes) -> bytes | None;

"""Regex fallback for Pascal/Delphi extraction when tree-sitter-pascal
    is unavailable. Produces the same node/edge schema as the tree-sitter pass.
    """
def _extract_pascal_regex(path: Path) -> dict;

"""Extract units, classes, procedures, uses-imports, and calls from Pascal/Delphi files.

    Produces nodes for:
    - The file itself
    - unit / program / library declarations
    - class and interface type declarations
    - procedure / function implementations (including qualified TClass.Method names)

    Produces edges for:
    - file --contains--> module
    - module --imports--> other file node (via uses clause, resolved to path-based IDs)
    - class --inherits--> base class
    - class/module --contains--> method forward declaration
    - class/module --contains--> procedure/function implementation
    - procedure --calls--> other procedure (within the same file)

    Uses tree-sitter-pascal when available; falls back to a regex-based extractor
    (_extract_pascal_regex) when it isn't installed or fails to parse, so Pascal
    extraction works out of the box without an extra pip install.
    """
def extract_pascal(path: Path) -> dict;
