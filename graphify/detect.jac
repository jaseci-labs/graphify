import importlib;
import builtins;

import operator;
import from __future__ { annotations }

import fnmatch;

import json;

import ntpath;

import os;

import posixpath;

import re;

import shlex;

import stat;

import subprocess;

import sys;

import time;

import unicodedata;

import zipfile;

import from concurrent.futures { ThreadPoolExecutor }

import from enum { Enum }

import from pathlib { Path }

import from typing { Any, Callable, Iterable }

class FileType(builtins.str, Enum) {
    static has CODE: any = "code";

    static has DOCUMENT: any = "document";

    static has PAPER: any = "paper";

    static has IMAGE: any = "image";

    static has VIDEO: any = "video";
}

glob _MANIFEST_PATH: any;

glob _MTIME_COARSE_S: any;

glob _MTIME_SUBSECOND_S: any;

glob CODE_EXTENSIONS: any;

glob DOC_EXTENSIONS: any;

glob PAPER_EXTENSIONS: any;

glob IMAGE_EXTENSIONS: any;

glob OFFICE_EXTENSIONS: any;

glob VIDEO_EXTENSIONS: any;

glob _BINARY_MEDIA_EXTENSIONS: any;

glob CORPUS_WARN_THRESHOLD: any;

glob CORPUS_UPPER_THRESHOLD: any;

glob FILE_COUNT_UPPER: any;

glob UNCLASSIFIED_WARN_MIN_FILES: any;

glob UNCLASSIFIED_WARN_FRACTION: any;

glob _OFFICE_MAX_RAW_BYTES: any;

glob _OFFICE_MAX_DECOMPRESSED_BYTES: any;

glob _OFFICE_MAX_COMPRESSION_RATIO: any;

glob _CREDENTIAL_STORE_DIRS: any;

glob _AMBIGUOUS_SENSITIVE_DIRS: any;

glob _SENSITIVE_PATTERNS: any;

glob _ENV_TEMPLATE_SUFFIXES: any;

glob _GENERIC_KEYWORD_PATTERNS: any;

glob _PROSE_EXTS: any;

glob _BARE_PLURAL_TOKENS: any;

glob _SECRET_PRONE_DATA_EXTS: any;

glob _WORD_SPLIT: any;

glob _PAPER_SIGNALS: any;

glob _PAPER_SIGNAL_THRESHOLD: any;

glob _ASSET_DIR_MARKERS: any;

glob _SHEBANG_CODE_INTERPRETERS: any;

glob _pypdf_missing_warned: any;

glob _pdf_failed_warned: any;

glob _W: any;

glob _MC_FALLBACK: any;

glob _DOCX_WRAPPERS: any;

glob _DOCX_SKIPPED: any;

glob _DOCX_RUN_TEXT: any;

glob _SKIP_DIRS: any;

glob _SKIP_FILES: any;

glob _RESOLUTION_INPUT_NAMES: any;

glob _TS_CONFIG_NAME_RE: any;

glob _JS_SNAPSHOT_TEST_ROOTS: any;

glob _NESTED_SKILL_HOLDERS: any;

glob _GRAPHIFY_INSTALLED_FILES: any;

glob _COVERAGE_ARTIFACT_FILES: any;

glob _COVERAGE_ARTIFACT_DIRS: any;

glob _BUILD_OUTPUT_SUFFIXES: any;

glob _MSBUILD_OBJ_MARKERS: any;

glob _MSBUILD_BIN_MARKERS: any;

glob _VCS_MARKERS: any;

glob _warned_ignore_encodings: any;

glob _PARSED_PATTERN_CACHE: dict[str, tuple[bool, bool, bool, str]];

glob _PARSED_PATTERN_CACHE_MAX: any;

glob _CASEFOLD_PATHS: any;

glob convert_google_workspace_file: any = _wired_convert_google_workspace_file;

glob _os_path: any;

glob _DRIVE_LETTER_RE: any;

with entry {
    _MANIFEST_PATH = `str(out_path("manifest.json"));
    _MTIME_COARSE_S = 2.0;
    _MTIME_SUBSECOND_S = 0.05;

    CODE_EXTENSIONS = {
        ".py",
        ".ts",
        ".tsx",
        ".mts",
        ".cts",
        ".js",
        ".jsx",
        ".mjs",
        ".cjs",
        ".ejs",
        ".ets",
        ".go",
        ".rs",
        ".vb",
        ".cbl",
        ".cob",
        ".cobol",
        ".cpy",
        ".java",
        ".groovy",
        ".gradle",
        ".cpp",
        ".cc",
        ".cxx",
        ".c",
        ".h",
        ".hpp",
        ".cu",
        ".cuh",
        ".metal",
        ".rb",
        ".rake",
        ".swift",
        ".kt",
        ".kts",
        ".cs",
        ".scala",
        ".php",
        ".lua",
        ".luau",
        ".toc",
        ".zig",
        ".ps1",
        ".psm1",
        ".psd1",
        ".ex",
        ".exs",
        ".m",
        ".mm",
        ".ml",
        ".mli",
        ".jl",
        ".vue",
        ".svelte",
        ".astro",
        ".dart",
        ".v",
        ".sv",
        ".svh",
        ".vh",
        ".sql",
        ".r",
        ".f",
        ".F",
        ".f90",
        ".F90",
        ".f95",
        ".F95",
        ".f03",
        ".F03",
        ".f08",
        ".F08",
        ".pas",
        ".pp",
        ".dpr",
        ".dpk",
        ".lpr",
        ".inc",
        ".dfm",
        ".lfm",
        ".lpk",
        ".sh",
        ".bash",
        ".json",
        ".yaml",
        ".yml",
        ".tf",
        ".tfvars",
        ".hcl",
        ".dm",
        ".dme",
        ".dmi",
        ".dmm",
        ".dmf",
        ".sln",
        ".slnx",
        ".csproj",
        ".fsproj",
        ".vbproj",
        ".xaml",
        ".razor",
        ".cshtml",
        ".cls",
        ".trigger",
        ".lisp",
        ".cl",
        ".lsp",
        ".asd",
        ".robot",
        ".resource",
        ".sol",
        ".erl",
        ".hrl",
        ".escript",
    };
    DOC_EXTENSIONS = {
        ".md",
        ".mdx",
        ".qmd",
        ".skill",
        ".txt",
        ".rst",
        ".html",
        ".j2",
        ".jinja",
        ".jinja2",
    };
    PAPER_EXTENSIONS = {".pdf"};
    IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg"};
    OFFICE_EXTENSIONS = {".docx", ".xlsx"};
    VIDEO_EXTENSIONS = {
        ".mp4",
        ".mov",
        ".webm",
        ".mkv",
        ".avi",
        ".m4v",
        ".mp3",
        ".wav",
        ".m4a",
        ".ogg",
    };
    _BINARY_MEDIA_EXTENSIONS = IMAGE_EXTENSIONS - {".svg"} | VIDEO_EXTENSIONS;

    CORPUS_WARN_THRESHOLD = 50000;
    CORPUS_UPPER_THRESHOLD = 500000;
    FILE_COUNT_UPPER = 500;
    UNCLASSIFIED_WARN_MIN_FILES = 20;
    UNCLASSIFIED_WARN_FRACTION = 0.2;
    _OFFICE_MAX_RAW_BYTES = 50 * 1024 * 1024;
    _OFFICE_MAX_DECOMPRESSED_BYTES = 512 * 1024 * 1024;
    _OFFICE_MAX_COMPRESSION_RATIO = 200;
    cap_default_ = _OFFICE_MAX_RAW_BYTES;
}

glob cap_default_: any;
def _file_within_size_cap(path: Path, cap: int = cap_default_) -> bool;
def _zip_within_caps(path: Path) -> bool;

with entry {
    _CREDENTIAL_STORE_DIRS = frozenset({".ssh", ".gnupg", ".aws", ".gcloud"});
    _AMBIGUOUS_SENSITIVE_DIRS = frozenset({"secrets", ".secrets", "credentials"});
    _SENSITIVE_PATTERNS = [
        re.compile("(^|[\\\\/])\\.(env|envrc)(\\.|$)", re.IGNORECASE),
        re.compile("\\.(pem|key|p12|pfx|cert|crt|der|p8)$", re.IGNORECASE),
        re.compile("(^|[^A-Za-z0-9])(id_rsa|id_dsa|id_ecdsa|id_ed25519)(\\.pub)?$", re.IGNORECASE),
        re.compile("^secring(\\.(gpg|pgp))?$", re.IGNORECASE),
        re.compile(
            "(\\.netrc|\\.pgpass|\\.htpasswd|\\.npmrc|\\.pypirc|\\.git-credentials|\\.boto)$",
            re.IGNORECASE,
        ),
    ];
    _ENV_TEMPLATE_SUFFIXES = (".example", ".sample", ".template", ".dist");
}

def _is_env_template(name: str) -> bool;

with entry {
    _GENERIC_KEYWORD_PATTERNS = [
        re.compile(
            "(?<![a-zA-Z0-9])(credential|secret|passwd|password|private_key)s?(?![a-zA-Z])",
            re.IGNORECASE,
        ),
        re.compile("(?<![a-zA-Z0-9])tokens?(?![a-zA-Z])", re.IGNORECASE),
        re.compile("(?<![a-zA-Z0-9])service[._-]?account(?![a-zA-Z])", re.IGNORECASE),
    ];
    _PROSE_EXTS = frozenset({".md", ".markdown", ".rst", ".org", ".adoc", ".tex"});
    _BARE_PLURAL_TOKENS = re.compile("(?<![a-zA-Z0-9])tokens(?![a-zA-Z])", re.IGNORECASE);
    _SECRET_PRONE_DATA_EXTS = frozenset({
        ".json",
        ".yaml",
        ".yml",
        ".toml",
        ".ini",
        ".cfg",
        ".conf",
        ".config",
        ".xml",
        ".properties",
        ".env",
        ".txt",
        ".tfvars",
    });
    _WORD_SPLIT = re.compile("[-_\\s.]+");
}

def _is_prose_note(path: Path) -> bool;
def _generic_keyword_hit(name: str) -> bool;

with entry {
    _PAPER_SIGNALS = [
        re.compile("\\barxiv\\b", re.IGNORECASE),
        re.compile("\\bdoi\\s*:", re.IGNORECASE),
        re.compile("\\babstract\\b", re.IGNORECASE),
        re.compile("\\bproceedings\\b", re.IGNORECASE),
        re.compile("\\bjournal\\b", re.IGNORECASE),
        re.compile("\\bpreprint\\b", re.IGNORECASE),
        re.compile("\\\\cite\\{"),
        re.compile("\\[\\d+\\]"),
        re.compile("\\[\\n\\d+\\n\\]"),
        re.compile("eq\\.\\s*\\d+|equation\\s+\\d+", re.IGNORECASE),
        re.compile("\\d{4}\\.\\d{4,5}"),
        re.compile("\\bwe propose\\b", re.IGNORECASE),
        re.compile("\\bliterature\\b", re.IGNORECASE),
    ];
    _PAPER_SIGNAL_THRESHOLD = 3;
}

def _is_graphable_source(path: Path) -> bool;
def _is_sensitive(path: Path) -> bool;
def _looks_like_paper(path: Path) -> bool;

with entry {
    _ASSET_DIR_MARKERS = {".imageset", ".xcassets", ".appiconset", ".colorset", ".launchimage"};

    _SHEBANG_CODE_INTERPRETERS = {
        "python",
        "python3",
        "python2",
        "ruby",
        "perl",
        "node",
        "nodejs",
        "bash",
        "sh",
        "dash",
        "zsh",
        "fish",
        "ksh",
        "tcsh",
        "lua",
        "php",
        "julia",
        "Rscript",
    };
}

def _split_env_s(value: str, rest: list[str]) -> list[str];
def _env_command_args(args: list[str], *, allow_split: bool = True) -> list[str];
def _strip_interpreter_version(interp: str) -> str;
def _shebang_interpreter(path: Path) -> str | None;
def _shebang_file_type(path: Path) -> FileType | None;

def classify_file(path: Path) -> FileType | None;

with entry {
    _pypdf_missing_warned = False;
    _pdf_failed_warned = set[any]();
}

def extract_pdf_text(path: Path) -> str;

with entry {
    _W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}";
    _MC_FALLBACK = "{http://schemas.openxmlformats.org/markup-compatibility/2006}Fallback";
    _DOCX_WRAPPERS = frozenset({f"{_W}sdt", f"{_W}customXml"});
    _DOCX_SKIPPED = frozenset({
        f"{_W}del",
        f"{_W}moveFrom",
        f"{_W}rt",
        f"{_W}txbxContent",
        _MC_FALLBACK,
    });
    _DOCX_RUN_TEXT = `tuple(
        f"{_W}{tag}" for tag in ("br", "cr", "noBreakHyphen", "ptab", "t", "tab")
    );
}

def _docx_inside(element, stop, tags) -> bool;
def _docx_paragraph_text(p) -> str;
def _docx_blocks(container) -> Generator[any, any, any];

def _docx_children(parent, tag: str) -> Generator[any, any, any];
def _docx_cell_markdown(tc) -> str;
def docx_to_markdown(path: Path) -> str;
def xlsx_to_markdown(path: Path) -> str;
def xlsx_extract_structure(path: Path) -> dict;
def convert_office_file(path: Path, out_dir: Path, `root: "Path | None" = None) -> Path | None;

def count_words(path: Path) -> int;
def _is_regular_file(path: Path) -> bool;

with entry {
    _SKIP_DIRS = {
        "venv",
        ".venv",
        "node_modules",
        "__pycache__",
        ".git",
        "dist",
        "build",
        "target",
        "site-packages",
        "lib64",
        ".pytest_cache",
        ".mypy_cache",
        ".ruff_cache",
        ".tox",
        ".nox",
        ".eggs",
        "*.egg-info",
        "graphify-out",
        "lcov-report",
        "visual-tests",
        "visual-test",
        "__snapshots__",
        "storybook-static",
        "dist-protected",
        ".next",
        ".nuxt",
        ".turbo",
        ".angular",
        ".idea",
        ".cache",
        ".parcel-cache",
        ".svelte-kit",
        ".terraform",
        ".serverless",
        ".graphify",
        ".obsidian",
        ".smart-env",
        ".worktrees",
    };
    _SKIP_FILES = {
        "package-lock.json",
        "yarn.lock",
        "pnpm-lock.yaml",
        "Cargo.lock",
        "poetry.lock",
        "Gemfile.lock",
        "composer.lock",
        "go.sum",
        "go.work.sum",
        ".graphifyinclude",
    };
    _RESOLUTION_INPUT_NAMES = frozenset({
        "package.json",
        "package-lock.json",
        "pnpm-lock.yaml",
        "yarn.lock",
        "jsconfig.json",
    });
    _TS_CONFIG_NAME_RE = re.compile("^tsconfig(\\.[^/\\\\]+)?\\.json$");
}

def is_resolution_input(path: "Path | str") -> bool;

with entry {
    _JS_SNAPSHOT_TEST_ROOTS = frozenset({"__tests__", "__test__"});
    _NESTED_SKILL_HOLDERS = frozenset({(".pi", "agent"), (".config", "kilo")});
    _GRAPHIFY_INSTALLED_FILES = frozenset({
        (".agents", "rules", "graphify.md"),
        (".agents", "workflows", "graphify.md"),
        (".cursor", "rules", "graphify.mdc"),
        (".kilo", "plugins", "graphify.js"),
        (".kiro", "steering", "graphify.md"),
        (".opencode", "plugins", "graphify.js"),
        (".windsurf", "rules", "graphify.md"),
    });
}

def _is_installed_graphify_file(path: "Path") -> bool;

with entry {
    _COVERAGE_ARTIFACT_FILES = frozenset({
        "lcov.info",
        "coverage-final.json",
        "coverage-summary.json",
        "clover.xml",
        "coverage.xml",
        "cobertura-coverage.xml",
        "jacoco.xml",
        ".coverage",
        "index.html",
    });
    _COVERAGE_ARTIFACT_DIRS = frozenset({"lcov-report", "html-report"});
}

def _has_coverage_artifacts(d: "Path") -> bool;

with entry {
    _BUILD_OUTPUT_SUFFIXES = (
        ".class",
        ".jar",
        ".o",
        ".obj",
        ".exe",
        ".dll",
        ".pyc",
        ".js.map",
        ".css.map",
        ".d.ts",
    );
}

def _has_build_output_markers(d: "Path") -> bool;
def _has_venv_markers(d: "Path") -> bool;

with entry {
    _MSBUILD_OBJ_MARKERS = (
        "project.assets.json",
        ".nuget.dgspec.json",
        ".nuget.g.props",
        ".filelistabsolute.txt",
    );
    _MSBUILD_BIN_MARKERS = (".deps.json", ".runtimeconfig.json", ".pdb");
}

def _has_msbuild_markers(d: "Path", markers: tuple, max_depth: int) -> bool;
def _is_noise_dir(part: str, parent: "Path | None" = None) -> bool;

with entry {
    _VCS_MARKERS = (".git", ".hg", ".svn", "_darcs", ".fossil");
}

def _nfc(text: str) -> str;
def _parse_gitignore_line(raw: str) -> str;
def _is_valid_git_marker(dot_git: Path) -> bool;

def _has_vcs_marker(directory: Path) -> bool;
def _find_vcs_root(start: Path) -> Path | None;
def _path_identity(path: Path) -> str;
def _git_tracked_path_keys(`root: Path) -> tuple[set[str], set[str]];
def _is_unc_path(p: Path) -> bool;
def _git_info_exclude(vcs_root: Path) -> Path | None;
def _linked_worktree_main_root(directory: Path) -> Path | None;
def _git_global_excludes(vcs_root: Path) -> Path | None;

with entry {
    _warned_ignore_encodings = set[any]();
}

def _read_ignore_text(path: Path) -> str;
def _load_dir_own_ignore(d: Path, *, gitignore: bool = True) -> list[tuple[Path, str]];
def _load_graphifyignore(`root: Path, *, gitignore: bool = True) -> list[tuple[Path, str]];

with entry {
    _PARSED_PATTERN_CACHE = {};
    _PARSED_PATTERN_CACHE_MAX = 100000;
}

def _parse_ignore_pattern(pattern: str) -> tuple[bool, bool, bool, str];

with entry {
    _CASEFOLD_PATHS = operator.ne(os.path.normcase("Aa"), "Aa");
}

def _lexical_relative(target: Path, target_parts: tuple[str, ...], anchor: Path) -> str | None;
def _match_globstar_parts(
    path_parts: tuple[str, ...],
    pattern_parts: tuple[str, ...],
    path_idx: int,
    pattern_idx: int,
    memo: dict[tuple[int, int], bool],
) -> bool;
def _match_anchored_ignore_pattern(path: str, pattern: str) -> bool;
def _is_ignored(
    path: Path,
    `root: Path,
    patterns: list[tuple[Path, str]],
    *,
    _cache: dict[Path, bool] | None = None,
) -> bool;
def _is_scan_ignored(
    path: Path,
    `root: Path,
    patterns: list[tuple[Path, str]],
    explicit_patterns: list[tuple[Path, str]],
    tracked_files: set[str],
    tracked_dirs: set[str],
    *,
    cache: dict[Path, bool],
    explicit_cache: dict[Path, bool],
) -> bool;
def ignored_predicate(
    `root: Path, *, extra_excludes: list[str] | None = None, gitignore: bool = True
) -> Callable[[Path], bool];
def _auto_follow_symlinks(`root: Path) -> bool;
def _resolves_under_root(path: Path, `root: Path) -> bool;

def detect(
    `root: Path,
    *,
    follow_symlinks: bool | None = None,
    google_workspace: bool | None = None,
    extra_excludes: list[str] | None = None,
    cache_root: Path | None = None,
    gitignore: bool = True,
) -> dict;

with entry {
    _os_path = os_long_path;
}

def _md5_file(path: Path) -> str;
def _stat_and_hash(path_str: str) -> tuple[str, float, str] | None;
def _to_relative_for_storage(key: str, `root: Path) -> str;

with entry {
    _DRIVE_LETTER_RE = re.compile("^[A-Za-z]:[\\\\/]");
}

def _looks_absolute(key: str) -> bool;
def _normpath_own_flavor(key: str) -> str;
def _to_absolute_from_storage(key: str, `root: Path) -> str;
def _collapse_manifest_duplicates(
    items: Iterable[tuple[str, Any]], key_fn: Callable[[str], str]
) -> dict[str, Any];
def _manifest_storage_anchor(manifest_path: str | Path | None, `root: Path | None) -> Path | None;

glob manifest_path_default_: any;

with entry {
    manifest_path_default_ = _MANIFEST_PATH;
}

def load_manifest(
    manifest_path: str = manifest_path_default_, *, `root: Path | None = None
) -> dict;
def _checkout_prefix(abs_key: str, relative_keys: set[str]) -> str | None;
def _previous_checkout_absolute_keys(
    existing_keys: Iterable[Any], storage_root: Path | None, relative_keys: set[str]
) -> set[str];

glob manifest_path_default__: any;

with entry {
    manifest_path_default__ = _MANIFEST_PATH;
}

def save_manifest(
    files: dict[str, list[str]],
    manifest_path: str = manifest_path_default__,
    *,
    kind: str = "both",
    `root: Path | None = None,
    scan_corpus: set[str] | list[str] | None = None,
    clear_semantic: set[str] | list[str] | None = None,
    clear_ast: set[str] | list[str] | None = None,
    ast_empty: set[str] | list[str] | None = None,
);
def _mtime_may_hide_a_rewrite(current_mtime: float, stored: dict) -> bool;
def classify_manifest_files(
    file_buckets: dict[str, list[str]],
    manifest: dict,
    *,
    kind: str = "ast",
    unstamped_is_changed: bool = True,
) -> tuple[dict[str, list[str]], dict[str, list[str]]];
def classify_manifest_deletions(
    manifest: dict, scanned: Iterable[str], *, `root: Path | None = None
) -> tuple[list[str], list[str]];

glob manifest_path_default___: any;

with entry {
    manifest_path_default___ = _MANIFEST_PATH;
}

def detect_incremental(
    `root: Path,
    manifest_path: str = manifest_path_default___,
    *,
    follow_symlinks: bool | None = None,
    google_workspace: bool | None = None,
    kind: str = "semantic",
    extra_excludes: list[str] | None = None,
    gitignore: bool = True,
    cache_root: Path | None = None,
) -> dict;
