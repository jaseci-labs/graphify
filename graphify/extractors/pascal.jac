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

def _pascal_strip_comments(text: str) -> str;
def _pascal_split_sections(text: str) -> tuple[str, int, str, int];
def _pascal_split_uses(s: str) -> list[str];
def _pascal_split_bases(s: str) -> list[str];
def _pascal_find_body(text: str, start: int) -> tuple[int, int];
def _resolve_pascal_callee_factory(
    records: list[tuple], edges: list[dict], module_nid: str
) -> Callable[[str, str], str | None];
def _pascal_parse_health(`root) -> tuple[int, int];
def _normalize_pascal_escaped_string_literals(source: bytes) -> bytes | None;
def _normalize_pascal_compiler_directives(source: bytes) -> bytes | None;
def _extract_pascal_regex(path: Path) -> dict;
def extract_pascal(path: Path) -> dict;
