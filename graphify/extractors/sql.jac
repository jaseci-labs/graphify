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

def _package_members(masked: str, start: int, limit: int) -> list[tuple[str, int, tuple[int, int]
    | None, bool]];

with entry {
    _GO_LINE_RX = re.compile(
        "^[ \\t]*(GO(?:[ \\t]+\\d+)?)[ \\t\\r]*;?[ \\t\\r]*$", re.IGNORECASE | re.MULTILINE
    );
}

def _go_separators(source: bytes) -> list[tuple[int, int]];
def _mask_sql_comments(text: str) -> str;
def _clean_part(part: str) -> str;
def _clean_ident(name: str) -> str;
def _norm_ident(name: str) -> str;
def extract_sql(path: Path, content: str | bytes | None = None) -> dict;
