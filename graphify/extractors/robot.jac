import from __future__ { annotations }
import builtins;

import os;

import re;

import from pathlib { Path }

glob _ROBOT_STDLIBS: any;

glob _ROBOT_VAR_RE: any;

glob _BDD_PREFIXES: any;

with entry {
    _ROBOT_STDLIBS = frozenset({
        "BuiltIn",
        "Collections",
        "DateTime",
        "Dialogs",
        "Easter",
        "OperatingSystem",
        "Process",
        "Remote",
        "Reserved",
        "Screenshot",
        "String",
        "Telnet",
        "XML",
    });

    _ROBOT_VAR_RE = re.compile("\\$\\{([^}]*)\\}");
}

def _resolve_robot_import(raw: str, source_path: Path) -> Path | None;

with entry {
    _BDD_PREFIXES = ("given ", "when ", "then ", "and ", "but ");
}

def _kw_id(name: str) -> str;
def extract_robot(path: Path) -> dict;
