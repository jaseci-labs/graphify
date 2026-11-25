import importlib;

import operator;

import typing;

import builtins;
import from __future__ { annotations }

import from typing { Any, Callable }

import from pathlib { Path }

import functools;

import hashlib;

import json;

import os;

import re;

import sys;

glob _TSCONFIG_ALIAS_CACHE: dict[str, dict[str, list[str]]];

glob _TSCONFIG_BASEURL_CACHE: "dict[str, Path | None]";

glob _WORKSPACE_MANIFEST_NAMES: any;

glob _PACKAGE_IMPORTS_CACHE: "dict[str, tuple[Path, dict] | None]";

glob _JS_RESOLVE_EXTS: any;

glob _JS_INDEX_FILES: any;

glob _EXPORT_CONDITION_PRIORITY: any;

glob _PLATFORM_EXPORT_CONDITIONS: any;

glob _PLATFORM_SUFFIXES: any;

glob _PLATFORM_PATH_HINTS: any;

glob _BUILD_OUTPUT_SUFFIXES: any;

glob _BUILD_OUTPUT_DIRS: any;

glob _VUE_SCRIPT_RE: any;

glob _VUE_SCRIPT_LANG_RE: any;

glob _HTML_SCRIPT_TAG_RE: any;

glob _NON_JS_SCRIPT_TYPE_RE: any;

glob _JS_PRIMITIVE_TYPES: any;

glob _JS_FACT_NODE_TYPES: any;

glob _SCAN_ROOT_NAMESPACE_CACHE: dict[str, str];

glob _PYTHON_STDLIB_MODULE_NAMES: any;

glob _C_STD_HEADERS: any;

glob _CPP_STD_HEADERS: any;

glob C_STANDARD_INCLUDE_NAMES: any;

glob _DECLDEF_HEADER_SUFFIXES: any;

glob _DECLDEF_IMPL_SUFFIXES: any;

glob _GO_COMMENT_RE: any;

glob _GO_PACKAGE_RE: any;

glob _PHP_SUPERTYPE_RELATIONS: any;

glob _PHP_REPOINT_RELATIONS: any;

glob _pascal_unit_cache: dict[str, dict[str, str]];

glob _pascal_class_stem_cache: dict[str, dict[str, str]];

with entry {
    _TSCONFIG_ALIAS_CACHE = {};
    _TSCONFIG_BASEURL_CACHE = {};

    _WORKSPACE_MANIFEST_NAMES = ("pnpm-workspace.yaml", "package.json");
    _PACKAGE_IMPORTS_CACHE = {};

    _JS_RESOLVE_EXTS = (
        ".ts",
        ".tsx",
        ".mts",
        ".cts",
        ".svelte",
        ".ejs",
        ".js",
        ".jsx",
        ".mjs",
        ".cjs",
    );

    _JS_INDEX_FILES = (
        "index.ts",
        "index.tsx",
        "index.svelte",
        "index.ejs",
        "index.js",
        "index.jsx",
        "index.mjs",
    );
}

def _declared_language_suffixes(target_exts: tuple[str, ...]) -> tuple[str, ...];
def _resolve_js_import_path(candidate: Path) -> Path;
def _strip_jsonc(text: str) -> str;
def _read_tsconfig_aliases(tsconfig: Path, base_dir: Path, seen: set) -> dict[str, list[str]];
def _read_json_config(path: Path) -> "dict | None";
def _find_js_config(start_dir: Path) -> "tuple[Path, Path] | None";
def _load_tsconfig_aliases(start_dir: Path) -> dict[str, list[str]];
def _load_tsconfig_base_url(start_dir: Path) -> "Path | None";
def _match_tsconfig_alias(raw: str, pattern: str) -> "tuple[tuple[int, int], str, bool] | None";
def _resolve_tsconfig_alias(
    raw: str, aliases: dict[str, list[str]], base_url: "Path | None" = None
) -> "Path | None";

def _find_workspace_root(start_dir: Path) -> Path | None;

def _pnpm_workspace_globs(workspace_file: Path) -> list[str];

def _workspace_globs(`root: Path) -> list[str];

def _load_workspace_packages(start_dir: Path) -> dict[str, Path];

with entry {
    _EXPORT_CONDITION_PRIORITY = (
        "source",
        "import",
        "module",
        "svelte",
        "require",
        "default",
        "types",
    );
    _PLATFORM_EXPORT_CONDITIONS = {"native": ("react-native",)};

    _PLATFORM_SUFFIXES = ("web", "native", "ios", "android");
    _PLATFORM_PATH_HINTS = (
        ("native", ("native", "mobile", "ios", "android", "react-native")),
        ("web", ("web", "browser", "desktop", "electron")),
    );
}

def _importer_platform(start_dir: Path) -> str | None;
def _platform_variants(candidate: Path, platform: str | None) -> list[Path];
def _resolve_export_targets(value: Any, platform: str | None = None) -> list[str];
def _resolve_export_target(value: Any) -> str | None;
def _contained_in_package(resolved: Path, package_dir: Path) -> bool;
def _exports_candidates(package_dir: Path, targets: list[str], platform: str | None) -> list[Path];

with entry {
    _BUILD_OUTPUT_SUFFIXES = (".d.ts", ".d.mts", ".d.cts", ".js", ".mjs", ".cjs");
}

def _with_source_twins(
    package_dir: Path, candidates: list[Path], *, root_entry: bool = False
) -> list[Path];

def _package_entry_candidates(
    package_dir: Path, subpath: str, platform: str | None = None
) -> list[Path];

with entry {
    _BUILD_OUTPUT_DIRS = frozenset({"dist", "build", "target", "out", "dist-protected"});
}

def _is_build_output_path(path: Path, package_dir: Path) -> bool;

def _resolve_workspace_import(raw: str, start_dir: Path) -> Path | None;
def _find_js_project_anchor(start_dir: Path) -> Path;
def _load_package_imports(start_dir: Path) -> "tuple[Path, dict] | None";
def _match_subpath_import(raw: str, pattern: str) -> "tuple[int, str, bool] | None";
def _resolve_package_import(raw: str, start_dir: Path) -> "Path | None";
def _resolve_js_module_path(raw: str | Path, start_dir: Path | None = None) -> Path | None;
def _resolve_js_import_target(raw: str, str_path: str) -> "tuple[str, Path | None] | None";
def _resolve_c_include_path(raw: str, str_path: str) -> "Path | None";
def _resolve_lua_import_target(raw_module: str, str_path: str) -> str;

with entry {
    _VUE_SCRIPT_RE = re.compile(
        "(<script\\b(?:\"[^\"]*\"|'[^']*'|[^>\"'])*>)([\\s\\S]*?)(</script\\s*>)", re.IGNORECASE
    );

    _VUE_SCRIPT_LANG_RE = re.compile("\\blang\\s*=\\s*['\"]?([A-Za-z]+)['\"]?", re.IGNORECASE);
}

def _vue_mask_non_script(src: str) -> tuple[str, str | None];

with entry {
    _HTML_SCRIPT_TAG_RE = re.compile(
        "<script\\b((?:\\\"[^\\\"]*\\\"|'[^']*'|[^>\\\"'])*)>([\\s\\S]*?)</script\\s*>",
        re.IGNORECASE,
    );
    _NON_JS_SCRIPT_TYPE_RE = re.compile(
        "\\btype\\s*=\\s*[\"']?(?!module\\b|text/javascript\\b|application/javascript\\b)",
        re.IGNORECASE,
    );
}

def _svelte_mask_non_script(src: str) -> tuple[str, str | None];
def _memo_cwd(path_str: str) -> str;
@functools.lru_cache(maxsize=65536)
def _cached_source_key(source_file: str, root_str: str, _cwd: str) -> str;

def _source_key(source_file: str, `root: Path) -> str;

def _node_disambiguation_source_key(`node: dict, `root: Path) -> str;
def _disambiguate_colliding_node_ids(
    nodes: list[dict], edges: list[dict], raw_calls: list[dict], `root: Path
);

def _is_type_like_definition(`node: dict) -> bool;

@functools.lru_cache(maxsize=65536)
def _cached_realpath(path_str: str, _cwd: str) -> Path;
def _resolve_cached(path: "Path | str") -> Path;

def _js_source_path(source_file: str, `root: Path) -> Path | None;
def _apply_symbol_resolution_facts(
    paths: list[Path],
    nodes: list[dict],
    edges: list[dict],
    `root: Path,
    facts: _SymbolResolutionFacts,
    resolution_context_nodes: list[dict] | None = None,
    raw_calls: list[dict] | None = None,
);

def _parse_js_tree(path: Path) -> any;

def _walk_js_tree(`node) -> Generator[any, any, any];

def _js_module_specifier(`node, source: bytes) -> str | None;

def _js_named_specifiers(`node, source: bytes, specifier_type: str) -> list[tuple[str, str]];

def _js_export_clause(`node) -> any;

def _js_export_statement_is_star(`node) -> bool;

def _js_namespace_export_name(`node, source: bytes) -> str | None;

def _js_lexical_aliases(`node, source: bytes) -> list[tuple[str, str]];

def _js_exported_declaration_names(`node, source: bytes) -> list[str];
def _js_default_import_name(`node, source: bytes) -> str | None;
def _js_namespace_import_name(`node, source: bytes) -> str | None;
def _js_default_export_name(`node, source: bytes) -> str | None;
def _js_default_object_members(path: Path) -> dict[str, tuple[str, str]];

def _js_top_level_function_bodies(path: Path, root_node, source: bytes) -> list[tuple[str, object]];

def _js_call_identifier(`node, source: bytes) -> str | None;

with entry {
    _JS_PRIMITIVE_TYPES = frozenset({
        "string",
        "number",
        "boolean",
        "any",
        "unknown",
        "void",
        "never",
        "object",
        "null",
        "undefined",
        "bigint",
        "symbol",
        "this",
    });
}

def _ts_heritage_clause_entries(clause_node, source: bytes) -> list[str];
def _ts_collect_type_refs(`node, source: bytes, generic: bool, out: list[tuple[str, str]]);
def _ts_walk_class_members(
    class_node, source: bytes, path: Path, class_nid: str, facts: _SymbolResolutionFacts
);
def _js_require_call_and_specifier(value_node, source: bytes) -> any;
def _js_cjs_require_bindings(declarator, source: bytes) -> list[tuple[str, str]];
def _js_cjs_default_export_local(right, source: bytes) -> str | None;
def _js_cjs_export_facts(`node, source: bytes, path: Path) -> list[_SymbolExportFact];

with entry {
    _JS_FACT_NODE_TYPES = frozenset({
        "export_statement",
        "import_statement",
        "lexical_declaration",
        "variable_declaration",
        "expression_statement",
        "class_declaration",
        "abstract_class_declaration",
        "interface_declaration",
    });
}

def _collect_js_symbol_resolution_facts(paths: list[Path], facts: _SymbolResolutionFacts);
def _parse_python_tree(path: Path) -> any;
def _walk_python_tree(`node) -> Generator[any, any, any];

def _python_import_from_module(`node, source: bytes) -> tuple[int, str] | None;

def _python_imported_names(`node, source: bytes) -> list[tuple[str, str]];

def _is_python_package_dir(directory: Path, suffixes: tuple[str, ...] = (".py",)) -> bool;

def _probe_declared_python_module_candidate(candidate: Path) -> Path | None;
def _probe_python_module_candidate(candidate: Path) -> Path | None;

with entry {
    _SCAN_ROOT_NAMESPACE_CACHE = {};
}

def _infer_scan_root_namespace(`root: Path) -> str;

with entry {
    _PYTHON_STDLIB_MODULE_NAMES = frozenset({
        "abc",
        "aifc",
        "annotationlib",
        "antigravity",
        "argparse",
        "array",
        "ast",
        "asynchat",
        "asyncio",
        "asyncore",
        "atexit",
        "audioop",
        "base64",
        "bdb",
        "binascii",
        "bisect",
        "builtins",
        "bz2",
        "cProfile",
        "calendar",
        "cgi",
        "cgitb",
        "chunk",
        "cmath",
        "cmd",
        "code",
        "codecs",
        "codeop",
        "collections",
        "colorsys",
        "compileall",
        "compression",
        "concurrent",
        "configparser",
        "contextlib",
        "contextvars",
        "copy",
        "copyreg",
        "crypt",
        "csv",
        "ctypes",
        "curses",
        "dataclasses",
        "datetime",
        "dbm",
        "decimal",
        "difflib",
        "dis",
        "doctest",
        "email",
        "encodings",
        "ensurepip",
        "enum",
        "errno",
        "faulthandler",
        "fcntl",
        "filecmp",
        "fileinput",
        "fnmatch",
        "fractions",
        "ftplib",
        "functools",
        "gc",
        "genericpath",
        "getopt",
        "getpass",
        "gettext",
        "glob",
        "graphlib",
        "grp",
        "gzip",
        "hashlib",
        "heapq",
        "hmac",
        "html",
        "http",
        "idlelib",
        "imaplib",
        "imghdr",
        "imp",
        "importlib",
        "inspect",
        "io",
        "ipaddress",
        "itertools",
        "json",
        "keyword",
        "lib2to3",
        "linecache",
        "locale",
        "logging",
        "lzma",
        "mailbox",
        "mailcap",
        "marshal",
        "math",
        "mimetypes",
        "mmap",
        "modulefinder",
        "msilib",
        "msvcrt",
        "multiprocessing",
        "netrc",
        "nis",
        "nntplib",
        "nt",
        "ntpath",
        "nturl2path",
        "numbers",
        "opcode",
        "operator",
        "optparse",
        "os",
        "ossaudiodev",
        "pathlib",
        "pdb",
        "pickle",
        "pickletools",
        "pipes",
        "pkgutil",
        "platform",
        "plistlib",
        "poplib",
        "posix",
        "posixpath",
        "pprint",
        "profile",
        "pstats",
        "pty",
        "pwd",
        "py_compile",
        "pyclbr",
        "pydoc",
        "pydoc_data",
        "pyexpat",
        "queue",
        "quopri",
        "random",
        "re",
        "readline",
        "reprlib",
        "resource",
        "rlcompleter",
        "runpy",
        "sched",
        "secrets",
        "select",
        "selectors",
        "shelve",
        "shlex",
        "shutil",
        "signal",
        "site",
        "smtpd",
        "smtplib",
        "sndhdr",
        "socket",
        "socketserver",
        "spwd",
        "sqlite3",
        "sre_compile",
        "sre_constants",
        "sre_parse",
        "ssl",
        "stat",
        "statistics",
        "string",
        "stringprep",
        "struct",
        "subprocess",
        "sunau",
        "symtable",
        "sys",
        "sysconfig",
        "syslog",
        "tabnanny",
        "tarfile",
        "telnetlib",
        "tempfile",
        "termios",
        "textwrap",
        "this",
        "threading",
        "time",
        "timeit",
        "tkinter",
        "token",
        "tokenize",
        "tomllib",
        "trace",
        "traceback",
        "tracemalloc",
        "tty",
        "turtle",
        "turtledemo",
        "types",
        "typing",
        "unicodedata",
        "unittest",
        "urllib",
        "uu",
        "uuid",
        "venv",
        "warnings",
        "wave",
        "weakref",
        "webbrowser",
        "winreg",
        "winsound",
        "wsgiref",
        "xdrlib",
        "xml",
        "xmlrpc",
        "zipapp",
        "zipfile",
        "zipimport",
        "zlib",
        "zoneinfo",
    });
    _C_STD_HEADERS = frozenset({
        "assert.h",
        "complex.h",
        "ctype.h",
        "errno.h",
        "fenv.h",
        "float.h",
        "inttypes.h",
        "iso646.h",
        "limits.h",
        "locale.h",
        "math.h",
        "setjmp.h",
        "signal.h",
        "stdalign.h",
        "stdarg.h",
        "stdatomic.h",
        "stdbit.h",
        "stdbool.h",
        "stdckdint.h",
        "stddef.h",
        "stdint.h",
        "stdio.h",
        "stdlib.h",
        "stdnoreturn.h",
        "string.h",
        "tgmath.h",
        "threads.h",
        "time.h",
        "uchar.h",
        "wchar.h",
        "wctype.h",
    });
    _CPP_STD_HEADERS = frozenset({
        "algorithm",
        "any",
        "array",
        "atomic",
        "barrier",
        "bit",
        "bitset",
        "charconv",
        "chrono",
        "codecvt",
        "compare",
        "complex",
        "concepts",
        "condition_variable",
        "coroutine",
        "debugging",
        "deque",
        "exception",
        "execution",
        "expected",
        "filesystem",
        "flat_map",
        "flat_set",
        "format",
        "forward_list",
        "fstream",
        "functional",
        "future",
        "generator",
        "hazard_pointer",
        "initializer_list",
        "inplace_vector",
        "iomanip",
        "ios",
        "iosfwd",
        "iostream",
        "istream",
        "iterator",
        "latch",
        "limits",
        "linalg",
        "list",
        "locale",
        "map",
        "mdspan",
        "memory",
        "memory_resource",
        "mutex",
        "new",
        "numbers",
        "numeric",
        "optional",
        "ostream",
        "print",
        "queue",
        "random",
        "ranges",
        "ratio",
        "rcu",
        "regex",
        "scoped_allocator",
        "semaphore",
        "set",
        "shared_mutex",
        "simd",
        "source_location",
        "span",
        "spanstream",
        "sstream",
        "stack",
        "stacktrace",
        "stdexcept",
        "stdfloat",
        "stop_token",
        "streambuf",
        "string",
        "string_view",
        "strstream",
        "syncstream",
        "system_error",
        "text_encoding",
        "thread",
        "tuple",
        "type_traits",
        "typeindex",
        "typeinfo",
        "unordered_map",
        "unordered_set",
        "utility",
        "valarray",
        "variant",
        "vector",
        "version",
        "cassert",
        "ccomplex",
        "cctype",
        "cerrno",
        "cfenv",
        "cfloat",
        "cinttypes",
        "ciso646",
        "climits",
        "clocale",
        "cmath",
        "csetjmp",
        "csignal",
        "cstdalign",
        "cstdarg",
        "cstdbool",
        "cstddef",
        "cstdint",
        "cstdio",
        "cstdlib",
        "cstring",
        "ctgmath",
        "ctime",
        "cuchar",
        "cwchar",
        "cwctype",
    });
    C_STANDARD_INCLUDE_NAMES = _C_STD_HEADERS | _CPP_STD_HEADERS;
}

def _resolve_python_module_path(
    module_name: str, current_path: Path, `root: Path, level: int
) -> Path | None;
def _resolve_python_namespace_dir(
    module_name: str, current_path: Path, `root: Path, level: int
) -> "Path | None";
def _python_top_level_function_bodies(
    path: Path, root_node, source: bytes
) -> list[tuple[str, object]];

def _python_call_identifier(`node, source: bytes) -> str | None;

def _collect_python_symbol_resolution_facts(
    paths: list[Path],
    `root: Path,
    facts: _SymbolResolutionFacts,
    ambiguous_python_modules: set[str] | None = None,
    raw_calls: list[dict] | None = None,
);

def _augment_symbol_resolution_edges(
    paths: list[Path],
    nodes: list[dict],
    edges: list[dict],
    `root: Path,
    ambiguous_python_modules: set[str] | None = None,
    resolution_context_nodes: list[dict] | None = None,
    raw_calls: list[dict] | None = None,
);
def _resolve_cross_file_imports(
    per_file: list[dict],
    paths: list[Path],
    all_nodes: list[dict] | None = None,
    all_edges: list[dict] | None = None,
    ambiguous_python_modules: set[str] | None = None,
) -> list[dict];

with entry {
    _DECLDEF_HEADER_SUFFIXES = frozenset({".h", ".hpp", ".hh", ".hxx"});

    _DECLDEF_IMPL_SUFFIXES = frozenset({".m", ".mm", ".cpp", ".cc", ".cxx", ".c"});
}

def _cpp_source_key(source_file: str | Path, `root: Path) -> str;
def _cpp_reconciliation_paths(
    paths: list[Path],
    nodes: list[dict],
    `root: Path,
    available_paths: list[Path] | None = None,
    changed_paths: list[Path] | None = None,
) -> list[Path];
def _cpp_exact_includes(
    resolution_nodes: list[dict], edges: list[dict], `root: Path
) -> dict[str, set[str]];

def _cpp_include_path(includes: dict[str, set[str]], start: str, target: str) -> list[str];
def _merge_cpp_forward_classes(
    nodes: list[dict],
    edges: list[dict],
    raw_calls: list[dict],
    resolution_nodes: list[dict],
    context_edges: list[dict],
    `root: Path,
);
def _merge_cpp_member_declarations(
    nodes: list[dict],
    edges: list[dict],
    raw_calls: list[dict],
    resolution_nodes: list[dict],
    context_edges: list[dict],
    `root: Path,
);
def _decldef_class_stem(source_file: str) -> tuple[str, str] | None;
def _source_stem(`node: dict) -> str;
def _merge_decl_def_classes(all_nodes: list[dict], all_edges: list[dict]);

with entry {
    _GO_COMMENT_RE = re.compile(b"//[^\\n]*|/\\*.*?\\*/", re.DOTALL);
    _GO_PACKAGE_RE = re.compile(b"^\\s*package\\s+([A-Za-z_][A-Za-z0-9_]*)", re.MULTILINE);
}

def _go_package_clause(path: Path) -> str | None;
def _merge_go_package_types(all_nodes: list[dict], all_edges: list[dict]);
def _resolve_cross_file_java_imports(per_file: list[dict], paths: list[Path]) -> list[dict];
def _java_import_rows(root_node, source: bytes) -> list[tuple[str, str, int]];
def _go_import_path_for_file(
    source_file: str | Path, `root: Path, module_cache: dict[Path, str | None] | None = None
) -> str | None;
def _resolve_go_type_references(
    per_file: list[dict],
    paths: list[Path],
    all_nodes: list[dict],
    all_edges: list[dict],
    `root: Path,
    resolution_context_nodes: list[dict] | None = None,
    resolution_context_edges: list[dict] | None = None,
);
def _resolve_java_type_references(
    per_file: list[dict], paths: list[Path], all_nodes: list[dict], all_edges: list[dict]
);

with entry {
    _PHP_SUPERTYPE_RELATIONS = ("inherits", "implements", "mixes_in");
    _PHP_REPOINT_RELATIONS = frozenset({
        "inherits",
        "implements",
        "mixes_in",
        "imports",
        "references",
    });
}

def _php_fqn_from_raw(raw: str, ns: str, uses: dict[str, str]) -> str;
def _resolve_php_type_references(
    per_file: list[dict], paths: list[Path], all_nodes: list[dict], all_edges: list[dict]
);

with entry {
    _pascal_unit_cache = {};

    _pascal_class_stem_cache = {};
}

def _pascal_project_root(from_path: Path) -> Path;
def _pascal_resolve_unit(from_path: Path, unit_name: str) -> str;
def _pascal_resolve_class(from_path: Path, class_name: str) -> str | None;
