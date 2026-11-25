import from __future__ { annotations }
import importlib;

import sys;

import threading;

import from pathlib { Path }

glob RC_FILENAME: any = ".graphifyrc";

glob LANGUAGE_ALIASES: dict[str, str];

glob _BOOL_VALUES: any;

glob _local: any;

glob _warned_roots: any;

with entry {
    LANGUAGE_ALIASES = {
        "php": ".php",
        "pascal": ".pas",
        "delphi": ".pas",
        "freepascal": ".pas",
        "sql": ".sql",
        "python": ".py",
        "javascript": ".js",
        "js": ".js",
        "typescript": ".ts",
        "ts": ".ts",
        "c": ".c",
        "cpp": ".cpp",
        "c++": ".cpp",
        "cxx": ".cpp",
        "objc": ".mm",
        "objective-c": ".mm",
        "objectivec": ".mm",
        "java": ".java",
        "kotlin": ".kt",
        "scala": ".scala",
        "groovy": ".groovy",
        "go": ".go",
        "golang": ".go",
        "rust": ".rs",
        "ruby": ".rb",
        "csharp": ".cs",
        "c#": ".cs",
        "swift": ".swift",
        "lua": ".lua",
        "zig": ".zig",
        "elixir": ".ex",
        "julia": ".jl",
        "dart": ".dart",
        "r": ".r",
        "fortran": ".f90",
        "shell": ".sh",
        "bash": ".sh",
        "sh": ".sh",
        "powershell": ".ps1",
        "verilog": ".v",
        "systemverilog": ".sv",
        "terraform": ".tf",
        "hcl": ".hcl",
        "ocaml": ".ml",
        "lisp": ".lisp",
        "commonlisp": ".lisp",
        "markdown": ".md",
        "json": ".json",
        "yaml": ".yaml",
        "html": ".html",
    };
}

def _normalise_ext(raw: str) -> str;
def parse_language_value(value: str) -> str;

with entry {
    _BOOL_VALUES = {
        "true": True,
        "1": True,
        "yes": True,
        "on": True,
        "false": False,
        "0": False,
        "no": False,
        "off": False,
    };
}

def load_graphifyrc(`root: Path) -> dict;

with entry {
    _local = threading.local();
    _warned_roots = set[any]();
}

def _active -> dict[str, str];
def set_language_overrides(mapping: dict[str, str] | None);

def get_language_overrides -> dict[str, str];
def activate_language_overrides(`root: Path) -> dict[str, str];
def effective_suffix(path: Path | str) -> str;
def cache_salt(path: Path | str) -> str | None;
