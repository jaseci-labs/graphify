import operator;
import from __future__ { annotations }

import re;

import from pathlib { Path }

import from typing { Any }

glob _NAME: any = "[A-Z0-9][A-Z0-9-]*";

glob _PROGRAM: any;

glob _PARAGRAPH: any;

glob _PERFORM: any;

glob _COPY: any;

glob _GO_TO: any;

glob _GO_TO_WORDS: any;

glob _CALL: any;

glob _END_PROGRAM: any;

glob _DATA_ITEM: any;

glob _NOT_PARAGRAPHS: any;

glob _PERFORM_MODIFIERS: any;

glob _GO_TO_QUALIFIERS: any;

with entry {
    _PROGRAM = re.compile(f"\\bPROGRAM-ID\\s*\\.\\s*({_NAME})", re.IGNORECASE);
    _PARAGRAPH = re.compile(f"^({_NAME})(?:\\s+(SECTION))?\\s*\\.\\s*$", re.IGNORECASE);
    _PERFORM = re.compile(
        f"\\bPERFORM\\s+({_NAME})(?:\\s+(?:THRU|THROUGH)\\s+({_NAME}))?\\b", re.IGNORECASE
    );
    _COPY = re.compile(
        f"\\bCOPY\\s+(?:'([^']+)'|\\\"([^\\\"]+)\\\"|({_NAME}(?:\\.[A-Z0-9-]+)?))", re.IGNORECASE
    );
    _GO_TO = re.compile("\\bGO\\s+TO\\s+", re.IGNORECASE);
    _GO_TO_WORDS = re.compile(f"{_NAME}(?:[\\s,]+{_NAME})*", re.IGNORECASE);
    _CALL = re.compile("\\bCALL\\s+(['\\\"])([A-Z0-9-]+)\\1", re.IGNORECASE);
    _END_PROGRAM = re.compile("\\bEND\\s+PROGRAM\\b", re.IGNORECASE);
    _DATA_ITEM = re.compile(f"^\\s*(?:0[1-9]|[1-4][0-9]|66|77|88)\\s+({_NAME})\\b", re.IGNORECASE);
    _NOT_PARAGRAPHS = frozenset({
        "IDENTIFICATION",
        "ENVIRONMENT",
        "DATA",
        "PROCEDURE",
        "FILE",
        "WORKING-STORAGE",
        "LOCAL-STORAGE",
        "LINKAGE",
        "CONFIGURATION",
        "INPUT-OUTPUT",
        "STOP",
        "EXIT",
        "GOBACK",
        "CONTINUE",
        "DISPLAY",
        "MOVE",
        "COMPUTE",
        "ADD",
        "SUBTRACT",
        "MULTIPLY",
        "DIVIDE",
        "PERFORM",
        "COPY",
        "CALL",
        "IF",
        "ELSE",
        "END-IF",
        "END-PERFORM",
        "END-EXEC",
    });
    _PERFORM_MODIFIERS = frozenset({"UNTIL", "VARYING", "TIMES", "WITH", "TEST", "FOREVER"});
    _GO_TO_QUALIFIERS = frozenset({"OF", "IN"});
}

def _go_to_targets(words: list[str]) -> list[str];
def _code_lines(source: str) -> list[tuple[int, str]];

def _mask_strings(code: str) -> str;
def _starts_inside_string(code: str, offset: int) -> bool;

def extract_cobol(path: Path) -> dict;
