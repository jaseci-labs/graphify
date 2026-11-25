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

"""True if *path* exists and its on-disk size is within *cap*."""
def _file_within_size_cap(path: Path, cap: int = cap_default_) -> bool;

"""Reject a zip-based office file that is a likely zip/XML bomb.

    Two layers, because the zip central-directory sizes are attacker-controlled:
    1. A cheap pre-filter on the declared sizes (on-disk cap, summed-uncompressed
       cap, compression ratio) that rejects an honest bomb without decompressing.
    2. An authoritative pass that stream-decompresses every member with a hard
       byte ceiling, so a member that under-declares its size in the central
       directory cannot expand past the cap undetected. Decompression is chunked
       and bounded, so checking a bomb never materializes more than the ceiling.
    """
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

"""True for `.env.example` / `.envrc.sample` style committed templates (#2184)."""
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

"""A prose/note file (.md/.rst/...) whose stem is a multi-word topic slug is
    exempt from the generic-keyword drop (#2106). A stem that IS exactly a bare
    keyword (secrets / token / passwords) is NOT exempt — that still reads as a
    credential dump. The one exception is bare plural "tokens" (TOKENS.md),
    which reads as a design-token reference doc rather than a secret store
    (#3527)."""
def _is_prose_note(path: Path) -> bool;

"""True if a generic secret keyword appears load-bearing in the filename.

    Secret-store files name their contents, and in English compounds the
    content noun is the head, which comes last: "github-personal-access-token",
    "api_token", "oauth_token". A keyword that is neither at the end of the
    stem nor in a short (<=2 word) name is a topic word in a descriptive slug
    ("token-economics-of-recall.md", "password-policy-discussion.md") and must
    not cause the file to be silently dropped from the graph (#436, #718).
    """
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

"""True for genuine programming-language source — the only category exempt
    from the ambiguous-dir (Stage 1, #1943) and generic-keyword (Stage 3, #1666)
    drops. Data/serialization formats are NOT exempt even though some route
    through the CODE path for manifest parsing: credentials.json / secrets.yaml
    are exactly the stores those stages must keep catching.
    """
def _is_graphable_source(path: Path) -> bool;

"""Return True if this file likely contains secrets and should be skipped."""
def _is_sensitive(path: Path) -> bool;

"""Heuristic: does this text file read like an academic paper?"""
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

"""Re-tokenize an `env -S`/`--split-string` packed command, prepending the
    operand to any trailing args. Returns the unpacked argv."""
def _split_env_s(value: str, rest: list[str]) -> list[str];

"""Strip leading env(1) options and var assignments, return the trailing
    command argv. Covers macOS/BSD and GNU coreutils env documented spellings.

    POSIX/macOS short forms:
        env [-0iv] [-C workdir] [-P utilpath] [-S string]
            [-u name] [name=value ...] [utility [argument ...]]

    GNU coreutils long/compact forms additionally supported:
        --argv0=ARG / -a ARG / -aARG
        --unset=NAME / --unset NAME / -u NAME / -uNAME
        --chdir=DIR / --chdir DIR / -C DIR / -CDIR
        --split-string=STRING / --split-string STRING
        -S STRING / -SSTRING / -vS STRING / -vSSTRING
        --ignore-environment / --null / --debug / --list-signal-handling
        --default-signal[=SIG] / --ignore-signal[=SIG] / --block-signal[=SIG]

    `-S` / `--split-string` payloads are themselves env-style argument lists
    per the GNU shebang synopsis:
        #!/usr/bin/env -[v]S[option]... [name=value]... command [args]...
    so after splitting the payload we recursively re-parse it with
    `allow_split=False` (a nested -S inside a split payload is rejected to
    bound recursion).

    Unknown hyphen-prefixed args yield [] (we refuse to guess whether
    their next token is an interpreter or an operand).
    """
def _env_command_args(args: list[str], *, allow_split: bool = True) -> list[str];

"""Map a version-suffixed interpreter onto the name it is a version of.

    Shebangs name a specific version as often as the generic one
    (``python3.12``, ``python2.7``, ``lua5.4``, ``php8.2``). Try the name with
    its major version (``python3``), then the bare name (``lua``), and keep the
    original when neither is a known code interpreter.
    """
def _strip_interpreter_version(interp: str) -> str;

"""Return the interpreter name from a shebang line.

    Handles forms that a naive parser misses:
      - `#!/usr/bin/env -S python3 -u`     (env -S split-args form, anywhere)
      - `#!/usr/bin/env -i bash`           (no-operand env flags)
      - `#!/usr/bin/env -u VAR python3`    (env options with operands)
      - `#!/usr/bin/env -C /tmp python3`   (env -C workdir)
      - `#!/usr/bin/env -P /bin python3`   (env -P utilpath)
      - `#!/usr/bin/env DEBUG=1 python3`   (inline var assignment)
      - `#!"/usr/local/bin/python with spaces"`  (shlex handles quotes)

    Returns the basename of the resolved interpreter, with a version suffix
    on a known interpreter dropped (``python3.12`` -> ``python3``), or None if
    there is no shebang / the file is unreadable / parsing fails.
    """
def _shebang_interpreter(path: Path) -> str | None;

"""Peek at the first line of an extensionless file for a shebang."""
def _shebang_file_type(path: Path) -> FileType | None;

def classify_file(path: Path) -> FileType | None;

with entry {
    _pypdf_missing_warned = False;
    _pdf_failed_warned = set[any]();
}

"""Extract plain text from a PDF file using pypdf.

    Returns ``""`` when the file cannot be read (malformed, encrypted, ...), the
    same as for a PDF with no text, but warns on stderr naming the file and the
    error first (#4527), so a failed read is not mistaken for an empty document.
    """
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

"""Paragraph.text reads only the runs directly under the paragraph, so it drops tracked
    insertions, content controls, simple fields and smart tags."""
def _docx_paragraph_text(p) -> str;

"""Yield the w:p and w:tbl elements of a container in document order, looking through
    content controls and custom XML, with each text box's content after its paragraph."""
def _docx_blocks(container) -> Generator[any, any, any];

def _docx_children(parent, tag: str) -> Generator[any, any, any];

"""A cell's text on one line with pipes escaped, so it cannot break its table row."""
def _docx_cell_markdown(tc) -> str;

"""Convert a .docx file to markdown text using python-docx."""
def docx_to_markdown(path: Path) -> str;

"""Convert an .xlsx file to markdown text using openpyxl."""
def xlsx_to_markdown(path: Path) -> str;

"""Extract structural nodes (sheets, named tables, column headers) from an .xlsx file.

    Returns a nodes/edges dict compatible with the graphify extract pipeline.
    Used in addition to xlsx_to_markdown so Claude sees both structure and content.
    """
def xlsx_extract_structure(path: Path) -> dict;

"""Convert a .docx or .xlsx to a markdown sidecar in out_dir.

    Returns the path of the converted .md file, or None if conversion failed
    or the required library is not installed.
    """
def convert_office_file(path: Path, out_dir: Path, `root: "Path | None" = None) -> Path | None;

def count_words(path: Path) -> int;

"""True only for regular files (symlinks followed).

    Named pipes, sockets and device nodes must never reach a reader:
    ``open()`` on a FIFO with no writer blocks forever and never raises, so a
    single ``pipe.py`` in a scanned repository hangs the run with no output.
    A symlink is resolved deliberately — a link pointing at a FIFO blocks
    exactly like the FIFO itself. A path that cannot be stat'ed is treated as
    not readable rather than raising.
    """
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

"""True when ``path`` steers JS/TS module resolution (#4740).

    Deliberately over-approximate: a false positive only costs a slower run, a
    false negative ships a stale graph.
    """
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

"""True for a single file `graphify install` wrote into the project (#4057)."""
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

"""True only when *d* holds files a coverage tool actually generated.

    ``coverage`` is a legitimate package name (a Python package, a Go/Rust module,
    a domain namespace), so pruning it by name alone silently drops real source —
    an entire 5-module package in #2339, with its dependents left in the graph so
    queries still returned plausible neighbours. Prune it only on real evidence,
    mirroring the ``snapshots``/``env`` gating (#1666/#2058): a coverage report
    file, or an Istanbul/lcov HTML report subtree.
    """
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

"""True only when *d* holds evidence a build tool generated it.

    ``out`` is a mainstream SOURCE convention in hexagonal / ports-and-adapters
    codebases — ``adapter/out/`` and ``port/out/`` hold the entire outbound
    layer (persistence adapters, entities, outbound ports) — so pruning it by
    name alone silently drops an architectural layer from the graph: 196 of
    655 .java files on the #3347 corpus, exit code 0, no warning. Prune only
    on real generated-output evidence, mirroring the ``env``/``coverage``/
    ``snapshots`` gating (#1666/#2058/#2339): the IntelliJ ``out/production``
    layout, a Next.js static-export ``_next/`` tree, or compiled artifacts in
    the top two directory levels. An ``out`` that cannot be verified is kept —
    the same keep-on-doubt bias every other gated name has.
    """
def _has_build_output_markers(d: "Path") -> bool;

"""True only when *d* has actual virtualenv/conda structure on disk.

    ``env``/``.env``/``*_env`` is a real source-directory convention (UVM/ASIC
    verification trees, and others), so pruning it by name alone silently drops
    legitimate source with no trace (#2058). Prune it only on real evidence: a
    ``pyvenv.cfg``, an ``activate`` script, a ``lib/python*`` tree, or conda's
    ``conda-meta/`` (``conda create -p ./env`` writes no pyvenv.cfg).
    """
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

"""True when a file ending in one of *markers* sits within *max_depth*
    directory levels below *d*.

    ``bin`` and ``obj`` are MSBuild's output and intermediate dirs, and an
    unignored C# project carries both after its first build: the generated
    GlobalUsings/AssemblyInfo sources land in the graph as file nodes with
    import edges to every implicit namespace, and the build-copied
    appsettings*.json are scanned twice. ``dotnet new`` writes no .gitignore,
    so nothing else stops them. Neither name is safe to prune alone — ``bin``
    is source in Rust's src/bin/, Ruby binstubs and script dirs — so prune
    only on MSBuild's own artifacts, the same keep-on-doubt gating ``out``
    gets (#3347). The walk is bounded by entries scanned, not just depth.
    """
def _has_msbuild_markers(d: "Path", markers: tuple, max_depth: int) -> bool;

"""Return True if this directory name looks like a venv, cache, or dep dir."""
def _is_noise_dir(part: str, parent: "Path | None" = None) -> bool;

with entry {
    _VCS_MARKERS = (".git", ".hg", ".svn", "_darcs", ".fossil");
}

"""Normalize text to NFC so ignore matching survives Unicode form drift.

    macOS (APFS/HFS+) returns filenames in NFD: "ç" comes back as "c" +
    U+0327 COMBINING CEDILLA. Editors write ignore files in NFC, where the
    same "ç" is the single codepoint U+00E7. The two render identically and
    compare unequal, so a pattern like `Orçamento/` silently fails to exclude
    the directory it names — the files are scanned and, for docs/PDFs, sent
    to an LLM despite an explicit rule against it.

    Both sides are normalized to NFC before any fnmatch call. NFC is the form
    Linux and Windows already use, so this is a no-op there and only repairs
    the macOS mismatch.
    """
def _nfc(text: str) -> str;

"""Parse one raw line from a .graphifyignore file per gitignore spec.

    - Strip newline chars
    - Strip inline comments (whitespace + # suffix), but only when # is
      preceded by whitespace — so path#with#hash.py is preserved
    - Unescape \\# to literal #
    - Remove trailing spaces unless escaped with backslash
    - Strip leading whitespace
    - Return empty string for blank lines and full-line comments
    """
def _parse_gitignore_line(raw: str) -> str;

"""Whether ``dot_git`` is a ``.git`` that git itself would accept (#4444).

    A ``.git`` directory needs ``HEAD``, ``objects/`` and ``refs/``, the same
    entries git's own repository check looks for. A ``.git`` file (linked
    worktree, submodule) must start with ``gitdir:``. An empty or partial
    ``.git`` directory, e.g. one left in a home directory, is not a repo and
    must not become the ignore-walk ceiling. No git subprocess is used.
    """
def _is_valid_git_marker(dot_git: Path) -> bool;

def _has_vcs_marker(directory: Path) -> bool;

"""Walk upward from start; return the first directory containing a VCS marker.

    ``.git`` only counts when it is a valid repo marker (#4444).
    """
def _find_vcs_root(start: Path) -> Path | None;

"""Portable comparison key for an existing filesystem path."""
def _path_identity(path: Path) -> str;

"""Return tracked-file keys and their ancestor-directory keys under *root*.

    Gitignore rules do not apply to paths already present in Git's index. Ask
    Git once per scan/predicate construction with NUL-delimited output so every
    valid filename is preserved. Missing Git, a non-Git VCS marker, command
    failure, and malformed output all fail closed to the historical ignore
    behavior rather than making discovery fail (#2759).
    """
def _git_tracked_path_keys(`root: Path) -> tuple[set[str], set[str]];

"""True for a UNC path (``\\\\host\\share`` or ``//host/share``).

    A ``.git`` file in an indexed repo can point ``gitdir:`` (or, through its
    ``commondir``, the shared git dir) at a UNC path. Stat-ing or reading under it
    makes Windows authenticate to the named host over SMB and leak a NetNTLMv2
    response, with no LLM call or other setup (GHSA-g6c9-j4vm-mwq4). Such a gitdir
    is treated as not-a-repo rather than probed. Purely local gitdirs — including
    the absolute local paths that legitimate linked worktrees and submodules use —
    are unaffected.
    """
def _is_unc_path(p: Path) -> bool;

"""Resolve ``$GIT_DIR/info/exclude`` for the repo rooted at ``vcs_root``.

    ``info/exclude`` is where git records local-only, uncommitted excludes — and
    where ``git worktree add`` writes nested worktree paths — so a repo can ignore
    a directory without any ``.gitignore`` entry. graphify only read
    ``.gitignore``/``.graphifyignore``, so it walked into those worktree copies and
    the graph exploded (#1810). Handles the linked-worktree/submodule case where
    ``.git`` is a file (``gitdir: <path>``) and the real excludes live in the
    shared common git dir. Returns None when there is no readable exclude file.
    """
def _git_info_exclude(vcs_root: Path) -> Path | None;

"""Return the main worktree's root for a linked-worktree dir, else None.

    ``git worktree add`` gives the linked checkout a ``.git`` FILE reading
    ``gitdir: <main>/.git/worktrees/<name>``, and writes a ``commondir`` file
    inside that gitdir pointing back at the shared git dir ``<main>/.git`` —
    so the main checkout's root is the common dir's parent. A submodule's
    ``.git`` file points at ``<super>/.git/modules/<name>``, which carries no
    ``commondir``; a bare repo's shared git dir is not named ``.git`` (it has
    no main working tree); and a moved/deleted main checkout leaves ``cd``
    dangling — all three fall through to None and stay scannable (#4683).
    No git subprocess is used.
    """
def _linked_worktree_main_root(directory: Path) -> Path | None;

"""Resolve git's user-wide excludes file (``core.excludesFile``).

    This is where people keep machine-wide rules for local settings and secret
    files so they don't repeat them in every repo; git ignores those files but
    graphify read them (#4335). Asks git for the configured path (``--path``
    expands ``~``) and falls back to git's default,
    ``$XDG_CONFIG_HOME/git/ignore`` or ``~/.config/git/ignore``, when the key
    is unset or git is unavailable. Only applies inside a git repo, like git.
    Returns None when there is no readable file.
    """
def _git_global_excludes(vcs_root: Path) -> Path | None;

with entry {
    _warned_ignore_encodings = set[any]();
}

"""Read an ignore file, preferring UTF-8 but never silently dropping a rule.

    These files were read with ``errors="ignore"``, which turns a mis-encoded
    byte into *no* byte. An ignore file saved in the host's ANSI codepage — the
    historical Notepad default on Windows, and still what ``Set-Content`` writes
    without ``-Encoding`` — is not valid UTF-8, so ``Orçamento/`` decoded to
    the pattern ``Oramento/``. That matches nothing, and nothing said so: the
    directory was scanned despite an explicit exclusion, which for a rule
    covering documents or PDFs means they reach the semantic pass anyway.

    So: UTF-8 (BOM-tolerant) first, since that is what the format should be and
    what every other reader here assumes. Only if that fails do we fall back to
    the host encoding, then to latin-1, which cannot fail and maps every byte to
    a codepoint — a rule spelled in some third encoding still comes out wrong,
    but it comes out *whole*, and the warning names the file so it is fixable.
    Decoding never raises, matching the previous contract.
    """
def _read_ignore_text(path: Path) -> str;

"""Read .gitignore/.graphifyignore directly inside *d* (not its ancestors).

    Merges .gitignore and .graphifyignore for this one directory (#1363):
    .gitignore is read first and .graphifyignore last, so .graphifyignore
    patterns (including `!` negations) win on conflict via last-match-wins;
    adding a .graphifyignore can only ever exclude MORE, never re-include a
    .gitignore-excluded file (#945 kept: a dir with only a .gitignore still
    gets sensible defaults).

    Shared by `_load_graphifyignore` (ancestor chain, loaded once before the
    scan) and the live os.walk loop in `detect()` (called per-directory as
    each descendant is visited), so nested ignore files *below* the scan
    root are honored too — previously only the scan root and its ancestors
    were read, so e.g. `vendor/sub/.gitignore` was silently ignored (#1206).
    """
def _load_dir_own_ignore(d: Path, *, gitignore: bool = True) -> list[tuple[Path, str]];

"""Read .graphifyignore files and return (anchor_dir, pattern) pairs.

    Patterns are returned outer-first so that inner (closer) rules are
    appended last and win via last-match-wins semantics — matching gitignore
    behavior exactly.

    Walk ceiling: the nearest VCS root if inside a repo, otherwise the scan
    root itself (hermetic — no leakage across unrelated sibling projects).

    Covers the scan root and its ancestors only — directories *below* the
    scan root are picked up live during the os.walk in `detect()` instead,
    since they aren't known until the walk reaches them (#1206).
    """
def _load_graphifyignore(`root: Path, *, gitignore: bool = True) -> list[tuple[Path, str]];

with entry {
    _PARSED_PATTERN_CACHE = {};
    _PARSED_PATTERN_CACHE_MAX = 100000;
}

"""Split one gitignore-style pattern into its matching flags, cached.

    Returns (negated, directory_only, path_relative, stripped). ``stripped``
    is empty for patterns that match nothing (bare "!", bare "/").
    """
def _parse_ignore_pattern(pattern: str) -> tuple[bool, bool, bool, str];

with entry {
    _CASEFOLD_PATHS = operator.ne(os.path.normcase("Aa"), "Aa");
}

"""String-space equivalent of ``_nfc(str(target.relative_to(anchor)).replace(os.sep, "/"))``.

    Returns None where ``relative_to`` raises ValueError (target not under
    anchor). ``relative_to`` is purely lexical — a parts-prefix check — so this
    performs the same comparison on the already-parsed ``parts`` tuples instead
    of constructing a Path object (and, on 3.12+, walking ``parents``
    quadratically) per pattern per scanned entry. That construction was the
    dominant cost of large scans (see CHANGELOG: 76k-file vault, 50+ min).
    """
def _lexical_relative(target: Path, target_parts: tuple[str, ...], anchor: Path) -> str | None;

"""Recursive ``**``-aware segment match, memoized via an explicit dict.

    Lifted out of ``_match_anchored_ignore_pattern`` (was a per-call
    ``@lru_cache`` closure): the decorated inner closure referenced itself, so
    every call leaked a reference cycle for the GC to reclaim on this hot path.
    A plain dict passed in avoids both the cycle and the per-call cache setup.
    """
def _match_globstar_parts(
    path_parts: tuple[str, ...],
    pattern_parts: tuple[str, ...],
    path_idx: int,
    pattern_idx: int,
    memo: dict[tuple[int, int], bool],
) -> bool;

"""Match an anchored gitignore pattern without letting ``*`` cross ``/``."""
def _match_anchored_ignore_pattern(path: str, pattern: str) -> bool;

"""Return True if the path should be ignored per .graphifyignore patterns.

    Uses gitignore last-match-wins semantics: all patterns are evaluated in
    order; the final matching pattern determines the result. Negation patterns
    (starting with !) un-ignore a previously ignored path.

    Enforces gitignore's parent-exclusion rule: a ! pattern cannot re-include
    a file whose ancestor directory is already excluded.

    _cache: optional dict shared across calls within the same scan. Ancestor
    directory results are memoised so files under the same subtree don't
    re-evaluate the same patterns repeatedly.
    """
def _is_ignored(
    path: Path,
    `root: Path,
    patterns: list[tuple[Path, str]],
    *,
    _cache: dict[Path, bool] | None = None,
) -> bool;

"""Apply ignore rules while preserving Git-tracked paths.

    ``patterns`` combines Git and graph-specific rules. ``explicit_patterns``
    contains only .graphifyignore/--exclude rules, which remain authoritative
    even for tracked files. A tracked file's ancestor directories are preserved
    from Git-only pruning so the walk can reach the file (#2759).
    """
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

"""Build a per-path predicate answering "would detect() exclude this path?".

    Mirrors detect()'s ignore decisions for a single existing path WITHOUT
    re-walking the corpus, from the same machinery detect() uses: the ancestor
    .graphifyignore/.gitignore chain (_load_graphifyignore), CLI/persisted
    ``--exclude`` patterns appended last at the root anchor (#947), nested
    per-directory ignore files along the path's own lineage (#1206), the
    _is_noise_dir directory pruning, and _SKIP_FILES. The sensitive-file
    heuristic (_is_sensitive) is deliberately NOT included: callers use this
    predicate as positive evidence of a live ignore RULE (#2495), and a
    heuristic match is not user intent.

    Nested patterns are loaded lazily, once per directory, into one shared
    pattern list. That accumulation cannot cross-contaminate results — a
    pattern only ever matches paths under its anchor directory, so patterns
    from a sibling subtree are inert — which is the same invariant detect()'s
    live os.walk relies on, and it keeps the shared _is_ignored cache valid.
    """
def ignored_predicate(
    `root: Path, *, extra_excludes: list[str] | None = None, gitignore: bool = True
) -> Callable[[Path], bool];

"""Return whether ``root`` has any direct symlinked child.

    Kept for callers that import the private helper, but detection no longer
    enables symlink following automatically. Following symlinks is now an
    explicit opt-in, and out-of-root symlink targets are never indexed.
    """
def _auto_follow_symlinks(`root: Path) -> bool;

"""True when ``path`` resolves to a target inside ``root``."""
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

"""MD5 of file contents streamed in 64KB chunks — for change detection only."""
def _md5_file(path: Path) -> str;

"""Stat + MD5 a single file; returns None on OSError (e.g. deleted mid-run)."""
def _stat_and_hash(path_str: str) -> tuple[str, float, str] | None;

"""Return ``key`` as a forward-slash relative path from ``root``.

    Keys outside ``root`` (out-of-tree symlinked sources, external --include
    paths) and already-relative keys pass through unchanged — mirrors the
    fallback in :func:`graphify.watch._relativize_source_files` so the
    on-disk artifact survives the round-trip even when some paths cannot be
    portably encoded.

    Only ``root`` is resolved — the key itself is relativized symbolically
    so an in-root symlink (e.g. ``alias.py -> sub/target.py``) is stored
    under its own name. Resolving the key would point the stored entry at
    the symlink target, and the original key would then miss on reload and
    re-extract on every incremental run.

    Both sides of ``relpath`` are NFC'd first: stamped keys may already be
    NFC while ``Path(root).resolve()`` is NFD on macOS, and a mixed-form
    compare would mark an in-root file as ``../…`` and keep it absolute
    (#2221 / #777).
    """
def _to_relative_for_storage(key: str, `root: Path) -> str;

with entry {
    _DRIVE_LETTER_RE = re.compile("^[A-Za-z]:[\\\\/]");
}

"""True if ``key`` is absolute under ANY platform's path syntax, not
    just the current one.

    ``Path.is_absolute()`` only recognizes the CURRENT platform's own
    syntax: a POSIX-style ``/abs/path`` key loaded on Windows (or a
    ``C:\\...``/UNC key loaded on POSIX) is wrongly judged relative, and
    :func:`_to_absolute_from_storage` then joins it onto ``root`` instead of
    leaving it alone — silently producing a nonsense path rather than the
    unreachable-but-at-least-recognizable foreign one (#1964 review: a
    manifest genuinely can move between platforms, per this module's own
    "mix of call sites/versions" scope).
    """
def _looks_absolute(key: str) -> bool;

"""``normpath`` an absolute ``key`` under its OWN platform's syntax.

    ``os.path.normpath`` applies the current platform's rules, so on Windows
    it rewrites a POSIX key ``/home/u/foo.py`` to ``\\home\\u\\foo.py`` —
    a string POSIX can no longer read back, since ``posixpath`` does not
    treat ``\\`` as a separator. Pick the flavor from the key itself: a
    drive letter or leading backslash is Windows, a leading ``/`` that the
    current platform does not consider absolute is POSIX.
    """
def _normpath_own_flavor(key: str) -> str;

"""Inverse of :func:`_to_relative_for_storage`.

    Re-anchor a stored key against ``root``. Already-absolute keys
    (legacy manifests, out-of-root entries, or a foreign-platform key —
    see :func:`_looks_absolute`) are not re-anchored, so that newly-loaded
    manifests from before this change remain readable; they are only
    dot-segment normalized under their own platform's syntax
    (:func:`_normpath_own_flavor`).
    Uses ``Path(root).resolve()`` so the produced absolute path matches
    what :func:`detect` returns (which also resolves the scan root).
    NFC both sides so a relative key and an NFD-resolved root still join
    to the same string form the rest of the manifest path uses (#2221).

    The joined result is lexically normalized (``os.path.normpath``, not
    ``.resolve()``) so a stray ``..``/``.`` segment collapses to the same
    string an equivalent absolute key would use — otherwise two keys for
    the same file (one absolute, one relative-with-dot-segments, the kind
    of mismatch a foreign tool or an older graphify version can leave
    behind, per this function's own caller) fail to canonicalize to the
    same value and the duplicate collapse this function exists for misses
    them (#1964 review). Only the key's own dot segments are normalized,
    never symlinks — ``normpath`` never touches the filesystem, matching
    :func:`_to_relative_for_storage`'s own choice not to resolve the key.
    """
def _to_absolute_from_storage(key: str, `root: Path) -> str;

"""Canonicalize each raw key via ``key_fn``, keeping the more recently
    observed entry when two distinct raw keys collapse to the same
    canonical one (#1964).

    A manifest written across a mix of graphify versions/call sites — some
    passing ``root`` to relativize keys, some not (an outdated installed
    skill runbook, for one) — can end up with both an absolute and a
    relative key for the same file, each carrying different data. A plain
    dict comprehension over such a manifest silently keeps whichever raw
    key happens to iterate last, an artifact of on-disk JSON key order that
    has nothing to do with which entry is actually current — so a fresher
    hash could be discarded in favor of a stale one purely because of how
    the keys happened to accumulate, letting detect_incremental() call a
    genuinely changed file unchanged.

    Ties are broken by each entry's own ``seen`` timestamp (when present on
    both sides and they disagree) rather than iteration order, since that
    field exists specifically to record when an entry was last confirmed
    current. Legacy scalar/partial entries (no ``seen``, or either side not
    a dict) fall back to the historical last-wins behavior, unchanged.
    """
def _collapse_manifest_duplicates(
    items: Iterable[tuple[str, Any]], key_fn: Callable[[str], str]
) -> dict[str, Any];

"""When a manifest lives under <repo>/graphify-out/manifest.json and root
    is a subfolder of <repo>, stored relative keys are anchored to <repo> (#3785)."""
def _manifest_storage_anchor(manifest_path: str | Path | None, `root: Path | None) -> Path | None;

glob manifest_path_default_: any;

with entry {
    manifest_path_default_ = _MANIFEST_PATH;
}

"""Load the manifest from a previous run. Returns {} on any error.

    When ``root`` is provided, stored relative keys are re-anchored against
    it so callers see absolute paths regardless of on-disk format. Legacy
    manifests with absolute keys pass through unchanged, so a graphify-out/
    written by an older version (or by a caller that didn't supply ``root``
    to :func:`save_manifest`) remains readable.

    Keys are NFC-normalized on load so a manifest written under one Unicode
    form still matches a scan that yields the other (#2221).
    """
def load_manifest(
    manifest_path: str = manifest_path_default_, *, `root: Path | None = None
) -> dict;

"""Longest directory prefix of ``abs_key`` whose suffix is in ``relative_keys``.

    The suffix is forward-slash and NFC. ``src/c.py`` beats a shorter ``c.py``.
    Prefixes ``""``, ``"/"``, and ``"\\"`` are skipped so a shorter suffix can
    still match. The prefix that remains must be a real directory.
    """
def _checkout_prefix(abs_key: str, relative_keys: set[str]) -> str | None;

"""Absolute keys that still name a previous checkout (#3581).

    A key is a candidate only when :func:`_to_relative_for_storage` keeps it
    absolute against ``storage_root`` (a sibling row that becomes relative,
    including #3785, is not a candidate). Candidates that share one directory
    prefix are a previous checkout when that group has at least two keys. One
    absolute key is an include row and stays. ``storage_root is None`` yields
    an empty set.
    """
def _previous_checkout_absolute_keys(
    existing_keys: Iterable[Any], storage_root: Path | None, relative_keys: set[str]
) -> set[str];

glob manifest_path_default__: any;

with entry {
    manifest_path_default__ = _MANIFEST_PATH;
}

"""Save current file mtimes + content hashes for change detection.

    kind="ast"      — written by `graphify update` (AST-only rebuild). Stamps
                      ast_hash; preserves an existing semantic_hash only when
                      the file content is unchanged (mtime + hash match).
    kind="semantic" — written by `graphify extract` after semantic extraction.
                      Stamps semantic_hash; preserves existing ast_hash.
    kind="both"     — full pipeline: stamps both hashes (default).

    When ``root`` is provided, keys are relativized against it before write
    (forward-slash, posix-style) so the on-disk manifest is portable across
    machines and checkout locations (#777). Out-of-root entries are written
    as absolute so they continue to round-trip on the saving machine.
    When ``root`` is None the legacy absolute-keyed format is preserved.

    ``scan_corpus`` (#1908): full-scan callers pass the COMPLETE detect
    corpus (absolute paths) so seeded rows for in-root files that are still
    alive on disk but no longer part of the scan (newly excluded via
    .graphifyignore/.gitignore/--exclude) are dropped instead of surviving
    forever and masquerading as deletions in detect_incremental. It must be
    the RAW detect output, not a stamp-filtered subset — pruning to a
    filtered set would erase rows the filter merely omitted (failed chunks,
    --code-only doc rows). When this argument is set, two or more absolute
    keys that share a directory prefix and match relative keys this save writes
    are a previous checkout and are dropped (#3581). A single include row stays.
    Callers saving a SUBSET of files (changed_paths hooks, skill runbooks, #917)
    must leave this None so their untouched rows, including out-of-root rows,
    are preserved.

    ``clear_semantic`` (#1948): files that were dispatched this run but
    produced no stamped output (e.g. the LLM omitted their chunk on a
    --force re-run) are absent from ``files``, so the seed loop below would
    otherwise copy their prior semantic_hash verbatim — masking the omission
    and making detect_incremental(kind="semantic") report them unchanged.
    Pass the set of such files (any path form ``scan_corpus`` accepts) to
    force their seeded semantic_hash to "" instead of inheriting it.

    ``clear_ast`` (#2543): same idea for AST failures (missing optional extra,
    zero-node anomalous extract). Blanks BOTH ``ast_hash`` and
    ``semantic_hash`` on the seeded row so either detect_incremental kind
    re-queues the file after the failure is fixed, without deleting
    graphify-out/.

    ``ast_empty`` (#2879): code files the AST extractor declined by design this
    run (data JSON, etc.) — stamped as up-to-date yet contributing zero nodes.
    Marks their row ``ast_empty: true`` so the #2543 heal can tell an intentional
    empty from a poisoned stamp and stop re-queuing them. Preserved across
    incrementals for unchanged rows; dropped once a file starts producing nodes.
    """
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
) -> None;

"""Was this manifest row written in the same tick as the file it describes?

    The incremental gate treats "mtime unchanged" as proof the content is
    unchanged. That is only true while the filesystem can distinguish the two
    writes: an edit keeping the file the same length and landing in the same
    timestamp tick moves neither size nor mtime, so the file silently skips
    re-extraction and the graph keeps serving the old content.

    ``seen`` records when the row was stamped. If the file's mtime falls inside
    the same tick, this row cannot prove currency and the caller pays for one
    MD5. Every other row — the whole settled corpus, and any manifest written
    by an earlier run — keeps the free stat-only fastpath.

    Rows predating ``seen`` are treated as safe: they necessarily come from an
    earlier process, where a later write would have had to move mtime.
    """
def _mtime_may_hide_a_rewrite(current_mtime: float, stored: dict) -> bool;

"""Split ``file_buckets`` into (changed, unchanged) against ``manifest``.

    This is the comparison ``detect_incremental`` has always used: mtime first
    (free, no disk IO beyond stat), content hash only when mtime moved or when
    the racily-clean window needs it. A missing row, a row with no usable hash,
    a language change, or an unknown row format all count as changed, so a caller
    can only ever over-report change.

    Factored out so the ``graphify update`` no-change gate in
    :func:`graphify.watch._rebuild_code` reaches the same verdict from an
    already-computed ``detect()`` result instead of paying for a second scan
    (#4740). ``file_buckets`` is not required to come from ``detect()["files"]``:
    the gate passes a synthetic bucket holding the JS/TS resolution inputs that
    the manifest stamps but the scan skips.

    ``unstamped_is_changed=False`` is for that gate. A file with no row (or a row
    whose hash was blanked after a failed extraction, #2543) is then treated as
    unchanged: it contributed no nodes, so re-extraction cannot change the graph,
    and only the gate's own file-set digest can tell "same file, still failing"
    from "new file". The incremental path keeps the default, where such a file is
    re-queued until it extracts.
    """
def classify_manifest_files(
    file_buckets: dict[str, list[str]],
    manifest: dict,
    *,
    kind: str = "ast",
    unstamped_is_changed: bool = True,
) -> tuple[dict[str, list[str]], dict[str, list[str]]];

"""Split manifest rows that left the scan into (deleted, excluded).

    A row whose file is gone from DISK is a genuine deletion (its cached nodes
    are ghosts); a row whose file still exists but is out of the current scan was
    EXCLUDED by a changed ignore rule and must not be reported as deleted
    (#1908). Mirrors the watch-side excluded-vs-deleted distinction (#1795).

    ``scanned`` must name every row the caller expects to see, including sources
    that carry manifest rows without being part of the scan corpus
    (``detect()["resolution_inputs"]``, #4740), or those rows read as excluded on
    every run.
    """
def classify_manifest_deletions(
    manifest: dict, scanned: Iterable[str], *, `root: Path | None = None
) -> tuple[list[str], list[str]];

glob manifest_path_default___: any;

with entry {
    manifest_path_default___ = _MANIFEST_PATH;
}

"""Like detect(), but returns only new or modified files since the last run.

    kind="semantic" (default for extract): a file is "changed" when its
        semantic_hash is missing or its content has changed since the last
        semantic extraction pass. Use this for `graphify extract` so that
        files touched by `graphify update` (AST-only) are re-extracted
        semantically.
    kind="ast": a file is "changed" when its ast_hash is missing or its
        content has changed. Use this for `graphify update`.

    Fast path: mtime unchanged + hash matches → unchanged (free, no disk IO
    beyond stat). Slow path: mtime bumped → compare MD5 against the relevant
    hash field before re-extracting.

    Backwards compatible with legacy manifests storing plain float mtime values
    or {mtime, hash} dicts (treated as ast_hash only; semantic_hash = miss).

    The ``follow_symlinks`` flag is forwarded to :func:`detect` so in-root
    symlinked sub-trees are scanned consistently between full and incremental
    runs. ``None`` (default) does not follow symlinked directories; callers must
    opt in explicitly, and resolved targets outside the scan root are skipped.

    ``cache_root`` is forwarded to :func:`detect`'s own word-count cache the
    same way the fresh-scan (non-incremental) call site already does. Without
    it, an incremental run with a ``--out`` destination outside the scan root
    falls back to anchoring the cache at the scan root itself, leaking
    ``graphify-out/cache/stat-index.json`` there even though the fresh-scan
    path stays clean (#3847).
    """
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
