import importlib;
import operator;
import from __future__ { annotations }

import re;

import os;

import unicodedata;

import from pathlib { Path }

import from urllib.parse { unquote }

glob _MD_INLINE_LINK_RE: any;

glob _MD_REF_DEF_RE: any;

glob _MD_REF_LINK_RE: any;

glob _MD_WIKILINK_RE: any;

glob _MD_LINKABLE_EXTS: any;

glob _MD_CITEABLE_EXTS: any;

glob _MD_CODE_SPAN_RE: any;

glob _MD_FILE_SPAN_RE: any;

glob _MD_PATH_MENTION_RE: any;

glob _MD_BARE_MENTION_RE: any;

glob _MD_NS_MENTION_RE: any;

glob _MD_NS_NON_SYMBOL_RE: any;

glob _MD_ATX_HEADING_RE: any;

glob _MD_ATX_CLOSING_RE: any;

glob _MD_FENCE_RE: any;

glob _MD_FRONTMATTER_CLOSE: any;

glob _MD_FRONTMATTER_MAX_LINES: any;

glob _MD_FM_SCALAR_RE: any;

glob _MD_LINK_INDEX_CACHE: "dict[str, dict[str, list[tuple[int, str, Path]]]]";

with entry {
    _MD_INLINE_LINK_RE = re.compile(
        "(?<!\\!)\\[[^\\]]*\\]\\(\\s*(?:<([^<>\\n]+)>\\s*(?:\"[^\"\\n]*\"|\\'[^\\'\\n]*\\'|\\([^()\\n]*\\))?\\s*|<?([^)\\s>]+)>?(?:\\s+[^)]*)?)\\)",
    );

    _MD_REF_DEF_RE = re.compile(
        "^\\s{0,3}\\[([^\\]]+)\\]:\\s*(?:<([^<>\\n]+)>(?=\\s*(?:[\"\\'(]|$))|<?([^\\s>]+)>?)"
    );
    _MD_REF_LINK_RE = re.compile("(?<!\\!)\\[([^\\]]*)\\]\\[([^\\]]*)\\]");

    _MD_WIKILINK_RE = re.compile("(?<!\\!)\\[\\[([^\\]|#]+?)(?:\\\\?\\|[^\\]]*|#[^\\]]*)?\\]\\]");
    _MD_LINKABLE_EXTS = {".md", ".mdx", ".qmd", ".markdown", ".rst", ".txt"};
    _MD_CITEABLE_EXTS = _MD_LINKABLE_EXTS | CODE_EXTENSIONS;
    _MD_CODE_SPAN_RE = re.compile("(?<!`)(`+)(?!`)(.+?)(?<!`)\\1(?!`)");
    _MD_FILE_SPAN_RE = re.compile("^([A-Za-z0-9_./\\-]+\\.([A-Za-z0-9]+))$");
    _MD_PATH_MENTION_RE = re.compile(
        "^([A-Za-z0-9_./\\-]+\\.[A-Za-z0-9]+)::([A-Za-z_]\\w*(?:::[A-Za-z_]\\w*)*)(?:\\(\\))?$"
    );
    _MD_BARE_MENTION_RE = re.compile("^(?:[A-Za-z_]\\w*\\.)*([A-Za-z_]\\w*)(?:\\(\\))?$");
    _MD_NS_MENTION_RE = re.compile("^[A-Za-z_]\\w*(?:(?:::|\\\\)[A-Za-z_]\\w*)+(?:\\(\\))?$");
    _MD_NS_NON_SYMBOL_RE = re.compile("^(?:class|[A-Z][A-Z0-9_]*)$");
    _MD_ATX_HEADING_RE = re.compile("^ {0,3}(#{1,6})[ \\t]+(.+)$");
    _MD_ATX_CLOSING_RE = re.compile("(?:^|[ \\t]+)#+[ \\t]*$");
    _MD_FENCE_RE = re.compile("^\\s*(`{3,}|~{3,})(.*)$");
}

def _fence_open(line: str) -> "tuple[str, int] | None";
def _fence_closes(line: str, fence: "tuple[str, int]") -> bool;

with entry {
    _MD_FRONTMATTER_CLOSE = ("---", "...");
    _MD_FRONTMATTER_MAX_LINES = 200;
    _MD_FM_SCALAR_RE = re.compile("^([A-Za-z0-9_][A-Za-z0-9_\\-. ]*):\\s*(.*)$");
}

def _split_frontmatter(lines: list[str]) -> tuple[list[str], int];
def _parse_frontmatter(fm_lines: list[str]) -> dict;
def _parse_frontmatter_fallback(fm_lines: list[str]) -> dict;

with entry {
    _MD_LINK_INDEX_CACHE = {};
}

def _nfc(s: str) -> str;
def _build_link_index(`root: Path) -> "dict[str, list[tuple[int, str, Path]]]";
def _vault_lookup(target: str, `root: Path) -> "Path | None";
def _percent_decoded(target: str, source_dir: Path) -> str;

def _is_external_link(target: str) -> bool;
def _resolve_markdown_link(
    raw: str, source_dir: Path, wikilink: bool = False, exts: "set[str] | None" = None
) -> "Path | None";
def _code_span_mention(span: str) -> "tuple[str | None, list[str]] | None";
def extract_markdown(path: Path) -> dict;
