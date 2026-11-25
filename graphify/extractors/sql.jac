"""Sql extractor. Moved verbatim from graphify/extract.py."""

import operator;

import from __future__ { annotations }

import re;

import from pathlib { Path }

glob _ROUTINE_RECOVERY_RX: any;

glob _TRIGGER_IDENT: any;

glob _TRIGGER_RECOVERY_RX: any;

glob _TABLE_RECOVERY_RX: any;

glob _BODY_END_RX: any;

glob _BODY_TAIL: any;

glob _DBLINK_SUFFIX: any;

glob _BODY_TABLE_IDENT: any;

glob _BODY_READ_RX: any;

glob _BODY_WRITE_RX: any;

glob _BODY_COMMA_TABLE_RX: any;

glob _BODY_ALIAS_RX: any;

glob _BODY_CTE_RX: any;

glob _BODY_EVENT_RX: any;

glob _BODY_FROM_NOT_TABLE_RX: any;

glob _BODY_NON_TABLES: any;

glob _PACKAGE_RECOVERY_RX: any;

glob _PLSQL_BLOCK_RX: any;

glob _PLSQL_HEAD_END_RX: any;

glob _PLSQL_CALL_SPEC_RX: any;

glob _GO_LINE_RX: any;

with entry {
    _ROUTINE_RECOVERY_RX = re.compile(
        "\\bCREATE\\s+(?:OR\\s+(?:REPLACE|ALTER)\\s+)?(?:(?:NON)?EDITIONABLE\\s+)?(?:FUNCTION|PROC(?:EDURE)?)\\s+(?:IF\\s+NOT\\s+EXISTS\\s+)?((?:\\\"(?:[^\\\"\\n]|\\\"\\\")+\\\"|\\[(?:[^\\]\\n]|\\]\\])+\\]|[\\w$]+)(?:\\s*\\.\\s*(?:\\\"(?:[^\\\"\\n]|\\\"\\\")+\\\"|\\[(?:[^\\]\\n]|\\]\\])+\\]|[\\w$]+))*)",
        re.IGNORECASE,
    );
    _TRIGGER_IDENT = "(?:\\\"(?:[^\\\"\\n]|\\\"\\\")+\\\"|\\[(?:[^\\]\\n]|\\]\\])+\\]|[\\w$]+)(?:\\s*\\.\\s*(?:\\\"(?:[^\\\"\\n]|\\\"\\\")+\\\"|\\[(?:[^\\]\\n]|\\]\\])+\\]|[\\w$]+))*";
    _TRIGGER_RECOVERY_RX = re.compile(
        "\\bCREATE\\s+(?:OR\\s+(?:REPLACE|ALTER)\\s+)?(?:(?:NON)?EDITIONABLE\\s+)?TRIGGER\\s+(?:IF\\s+NOT\\s+EXISTS\\s+)?("
            + _TRIGGER_IDENT
            + ").*?\\bON\\s+("
            + _TRIGGER_IDENT
            + ")",
        re.IGNORECASE | re.DOTALL,
    );
    _TABLE_RECOVERY_RX = re.compile(
        "\\bCREATE\\s+(?:OR\\s+(?:REPLACE|ALTER)\\s+)?TABLE\\s+(?:IF\\s+NOT\\s+EXISTS\\s+)?("
            + _TRIGGER_IDENT
            + ")",
        re.IGNORECASE,
    );
}

"""Blank comment and string-literal spans, preserving every offset.

    One output character per input character: non-newline characters inside
    a blanked span become spaces and newlines are kept, so positions and
    line numbers computed against the masked text are valid against the
    original. Double-quoted and bracket-delimited identifiers are preserved
    verbatim (they carry recoverable routine names); single-quoted strings,
    line comments, and (nesting-aware) block comments are blanked. Used by
    the routine-recovery scan so CREATE PROCEDURE/FUNCTION DDL reachable
    only through a comment or a single-quoted string cannot fabricate a
    routine node when an unrelated parse error arms recovery.

    Returns (masked_text, ident_spans) where ident_spans holds the [start,
    end) of every PRESERVED delimited identifier: preserved spans keep their
    text verbatim, so DDL keywords inside one are still visible in the
    masked text, and the recovery scan must skip a match that starts there
    (identifier data, not DDL — 'SELECT 1 AS [CREATE PROCEDURE x pending]'
    must not mint a routine).
    """
def _scan_sql(text: str) -> tuple[str, list[tuple[int, int]]];

with entry {
    _BODY_END_RX = re.compile(
        "^[ \\t]*(?:GO(?:[ \\t]+\\d+)?[ \\t\\r]*;?[ \\t\\r]*$|(?:CREATE|ALTER)\\b(?!\\s+TABLE\\s+[#@]))",
        re.IGNORECASE | re.MULTILINE,
    );
    _BODY_TAIL = "(?![\\w$@]|\\s*\\.)";
    _DBLINK_SUFFIX = "(?:@(?:\\\"(?:[^\\\"\\n]|\\\"\\\")+\\\"|\\[(?:[^\\]\\n]|\\]\\])+\\]|[\\w$.]+))";
    _BODY_TABLE_IDENT = _TRIGGER_IDENT + "(?:" + _DBLINK_SUFFIX + ")?";
    _BODY_READ_RX = re.compile(
        "\\b(?:FROM|JOIN)\\s+(" + _BODY_TABLE_IDENT + ")" + _BODY_TAIL, re.IGNORECASE
    );
    _BODY_WRITE_RX = re.compile(
        "\\b(INSERT(?:\\s+INTO)?|UPDATE(?:\\s+TOP\\s*\\([^)]*\\))?|DELETE(?:\\s+TOP\\s*\\([^)]*\\))?(?:\\s+FROM)?|MERGE(?:\\s+INTO)?|INTO)\\s+("
            + _BODY_TABLE_IDENT
            + ")"
            + _BODY_TAIL,
        re.IGNORECASE,
    );
    _BODY_COMMA_TABLE_RX = re.compile(
        "\\s*,\\s*(" + _BODY_TABLE_IDENT + ")" + _BODY_TAIL, re.IGNORECASE
    );
    _BODY_ALIAS_RX = re.compile("\\s+(?:AS\\s+)?([A-Za-z_][\\w$]*)", re.IGNORECASE);
    _BODY_CTE_RX = re.compile(
        "(?:\\bWITH\\s+(?:RECURSIVE\\s+)?|,\\s*)([\\w$]+)\\s*(?:\\([^()]*\\))?\\s+AS\\s*\\(",
        re.IGNORECASE,
    );
    _BODY_EVENT_RX = re.compile("(?:\\b(?:ON|FOR|AFTER|BEFORE|OF)|,)\\s*$", re.IGNORECASE);
    _BODY_FROM_NOT_TABLE_RX = re.compile(
        "(?:\\b(?:EXTRACT|TRIM|SUBSTRING|OVERLAY|POSITION)\\s*\\([^()]*|\\bDISTINCT\\s+|\\bFETCH\\s+(?:NEXT|PRIOR|FIRST|LAST|(?:ABSOLUTE|RELATIVE)\\s+\\S+)\\s+)$",
        re.IGNORECASE,
    );
    _BODY_NON_TABLES = frozenset({
        "select",
        "where",
        "set",
        "dual",
        "null",
        "true",
        "false",
        "first",
        "skip",
        "rows",
        "next",
        "only",
        "lateral",
        "values",
        "when",
        "then",
        "output",
        "default",
        "cascade",
        "with",
        "top",
        "statistics",
        "into",
        "as",
        "on",
        "using",
        "not",
        "exists",
        "inserted",
        "deleted",
        "openquery",
        "openrowset",
        "opendatasource",
        "inner",
        "left",
        "right",
        "full",
        "cross",
        "outer",
        "join",
        "group",
        "order",
        "having",
        "union",
        "except",
        "intersect",
        "option",
        "for",
        "from",
        "where",
        "pivot",
        "unpivot",
        "tablesample",
        "natural",
        "apply",
    });
}

"""(relation, table name as written, offset) for each table a masked
    routine body reads (`FROM`/`JOIN`) or writes (`INSERT`/`UPDATE`/`DELETE`/
    `MERGE`/`SELECT ... INTO`), in source order. Temp tables and variables never
    match the identifier atom; CTE names and keywords are dropped; the target of
    `UPDATE o ... FROM dbo.Orders o` is resolved through the alias.

    With ``plsql`` a bare `INTO` is not a write: PL/SQL's `SELECT`/`FETCH`/
    `RETURNING ... INTO` name a variable, not the table T-SQL's creates."""
def _routine_body_refs(masked: str, *, plsql: bool = False) -> list[tuple[str, str, int]];

with entry {
    _PACKAGE_RECOVERY_RX = re.compile(
        "\\bCREATE\\s+(?:OR\\s+REPLACE\\s+)?(?:(?:NON)?EDITIONABLE\\s+)?PACKAGE\\s+(BODY\\s+(?!(?:IS|AS)\\b))?(?:IF\\s+NOT\\s+EXISTS\\s+)?("
            + _TRIGGER_IDENT
            + ")",
        re.IGNORECASE,
    );
    _PLSQL_BLOCK_RX = re.compile(
        "(?<![\\w$#.:\\\"])(?:(?:PROCEDURE|FUNCTION)\\s+(\\\"(?:[^\\\"\\n]|\\\"\\\")+\\\"|[\\w$#]+)|(BEGIN|CASE)|END(?:\\s+(IF|LOOP)|\\s+CASE)?)(?![\\w$#\\\"])",
        re.IGNORECASE,
    );
    _PLSQL_HEAD_END_RX = re.compile(";|(?<![\\w$#.])(?:IS|AS)(?![\\w$#])", re.IGNORECASE);
    _PLSQL_CALL_SPEC_RX = re.compile("\\s*(?:LANGUAGE|EXTERNAL)\\b", re.IGNORECASE);
}

"""(name, offset, body span or None, is_definition) for each subprogram
    declared at package level between masked[start] (the end of the package
    name) and masked[limit]. A member whose END is not found gets no span."""
def _package_members(masked: str, start: int, limit: int) -> list[tuple[str, int, tuple[int, int]
    | None, bool]];

with entry {
    _GO_LINE_RX = re.compile(
        "^[ \\t]*(GO(?:[ \\t]+\\d+)?)[ \\t\\r]*;?[ \\t\\r]*$", re.IGNORECASE | re.MULTILINE
    );
}

"""Byte spans of the `GO [n]` batch-separator lines in a T-SQL script.

    A bare `go` on its own line is a column or alias, not a separator, only when the last
    non-blank character before it is a comma or the first one after it is a comma or `)`.
    Any keyword may precede a real separator (`SET NOCOUNT ON` / `GO`), so none is consulted.
    """
def _go_separators(source: bytes) -> list[tuple[int, int]];

"""Masked text only — see _scan_sql for the span-reporting form."""
def _mask_sql_comments(text: str) -> str;

"""One name part without T-SQL brackets. The parser hands over `dbo].[Orders`
    for `[dbo].[Orders]`, so a part may keep only one of its two brackets; `]]`
    inside a bracketed name is an escaped `]`."""
def _clean_part(part: str) -> str;

"""Display form of an object name: T-SQL brackets removed, schema kept.

    `[dbo].[Orders]` and the parser's `dbo].[Orders` both give `dbo.Orders`.
    Double-quoted parts keep their quotes. Labels only: node ids come from the
    text as written and are not touched.
    """
def _clean_ident(name: str) -> str;

"""Normalize a SQL identifier for name-based reference resolution.

    Splits on `.`, strips one pair of surrounding delimiters from each part
    (double quotes for Postgres/ANSI, backticks for MySQL, brackets for
    T-SQL), lowercases, and rejoins. So `"public"."users"`, `public.users`,
    and `PUBLIC.USERS` all normalize to `public.users`, and `[dbo].[Orders]`,
    the parser's `dbo].[Orders` and `dbo.Orders` to `dbo.orders`. Used ONLY for
    `table_nids` keys and lookups — node ids and display labels keep the
    original text.
    """
def _norm_ident(name: str) -> str;

"""Extract tables, views, functions, and relationships from .sql files via tree-sitter."""
def extract_sql(path: Path, content: str | bytes | None = None) -> dict;
