"""Deterministic structural extraction from source code using tree-sitter. Outputs nodes+edges dicts."""

import operator;

import from jaclang.comptime { target as target_ }

import from __future__ { annotations }

import hashlib;

import importlib;

import json;

import os;

import posixpath;

import re;

import sys;

import textwrap;

import from bisect { bisect_right }

import from collections { Counter }

import from dataclasses { dataclass, field }

import from pathlib { Path, PurePath }

import from typing { Any, Callable, List, Tuple }

glob _RECURSION_LIMIT: any = 10000;

def _raise_recursion_limit -> None;

"""Redact credential shapes from every rationale node label.

    Rationale labels are free text copied out of comments and docstrings, so
    this runs on every extractor's output (before it is cached) rather than
    relying on each language extractor to call ``redact_secrets`` itself.
    """
def _redact_rationale_labels(result: dict) -> dict;

def _safe_extract(extractor: Callable, path: Path, *, scan_root: Path | None = None) -> dict;

"""File-level node ID matching the skill.md spec: ``{parent_dir}_{stem}`` —
    one parent directory level, no extension. ``rel_path`` MUST be relative to
    the project root so top-level files collapse to a bare stem (``setup.py`` ->
    ``setup``) instead of picking up the root directory name. This must equal the
    ID semantic subagents generate, or AST and semantic extraction split a file
    into two disconnected ghost nodes (#1033)."""
def _file_node_id(rel_path: Path) -> str;

"""Map importable absolute module ids to their scanned file paths.

    A file can be importable from more than one sys.path root inside the scan
    root (for example ``a/src/pkg/mod.py`` as either ``pkg.mod`` or
    ``src.pkg.mod``). Probe each in-root, non-package ancestor the same way the
    shared resolver does. Keeping every candidate lets the extraction passes
    fail closed when the same absolute module name identifies multiple files.
    """
def _python_absolute_import_alias_files(paths, `root) -> tuple[dict[str, set[str]], set[str]];

"""Keep ambiguous Python imports dangling instead of choosing one file.

    The transient module name is also consumed by the symbol-level resolvers;
    removing it here prevents a direct file edge and any later inferred symbol
    or call edge from binding to an arbitrary same-named package. A plain
    ``import helper`` resolved to a scanned loose sibling in the importer's own
    non-package directory is an exception: that directory-local target is
    unambiguous even when another loose directory has its own ``helper.py``.
    """
def _suppress_ambiguous_python_imports(
    edges: list[dict],
    nodes: list[dict],
    raw_calls: list[dict],
    ambiguous_modules: set[str],
    module_alias_files: dict[str, set[str]],
    `root: Path,
) -> None;

"""Module path of a file in a PEP 420 namespace package under a `src/` root.

    `parts` is the file's path relative to the scan root. Returns the parts after
    the nearest `src` directory when the module sits at least one directory below
    it (`airflow/sql/hooks/sql.py`), else None. A loose `src/helpers.py` is left
    alone: its bare name is as likely a third-party import. So is a namespace
    named like a stdlib module, which a bare import means first (#4261)."""
def _namespace_src_module_parts(parts: tuple[str, ...]) -> tuple[str, ...] | None;

"""Repoint Python absolute-import edges to the real file node under a nested
    (e.g. ``src/``) package root (#2072).

    Absolute imports target an id derived from the dotted module path
    (``_make_id('pkg.mod')`` -> ``pkg_mod``), but file-node ids are
    scan-root-relative (``src_pkg_mod`` when the code lives under ``src/``), so
    the edge dangles and is silently dropped — the graph loses most ``imports``
    edges purely because of where the scan started. Build an alias map from the
    dotted-module id to the real file-node id by detecting each ``.py`` file's
    package root (the contiguous run of ancestor dirs carrying a Python initializer)
    and rewrite matching ``imports``/``imports_from`` edge targets. Guards: never
    shadow an existing node id, and drop an alias claimed by more than one file
    (ambiguous -> leave dangling, as before). Files whose package root IS the
    scan root are skipped (ids already coincide)."""
def _repoint_python_package_imports(paths, all_nodes, all_edges, `root) -> None;

"""Repoint Python sibling-import edges to the real file node in directories
    without a Python package initializer (#3430).

    When a Python file below the scan root lives in a non-package directory
    (no package initializer in its immediate parent), plain imports of same-directory
    modules (e.g. `scripts/main.py: import greeter`) target a bare name (`greeter`),
    while the real file node is scan-root-relative (`scripts_greeter`). Because
    the directory is not a package, `_repoint_python_package_imports` skips it
    (levels == 0), leaving the edge dangling and causing downstream member calls
    (`greeter.greet()`) to be dropped.

    This pass is strictly importer-directory-local:
    - Only applies when the importing file's parent directory has no package initializer.
    - Resolves only to unambiguous same-directory candidate modules in the scanned corpus.
    - Never builds a global alias map and never searches outside the importer's directory.
    - Preserves local aliases (e.g. `import greeter as g`).
    """
def _repoint_python_sibling_imports(paths, all_nodes, all_edges, `root) -> None;

"""Repoint Python plain-import edges targeting modules in directories dynamically
    added to sys.path via sys.path.insert / sys.path.append (#5253).

    When a script in a subdirectory (e.g. `src/skills/s/scripts/c.py`) adds another
    non-package directory to sys.path (`sys.path.insert(0, '../../bin')`), a subsequent
    plain import (`import b`) resolves at runtime to `src/bin/b.py`. Repointing the
    import edge here to the canonical file node ID ensures downstream member calls
    (`b.f()`) bind to the function node (`b.f`) in `_resolve_python_member_calls`,
    preventing callers from collapsing onto the file node itself.
    """
def _repoint_python_sys_path_imports(per_file, all_nodes, all_edges, `root) -> None;

glob SEMANTIC_RELATIONS: any;

glob _PYTHON_CONFIG: any;

glob _JS_CONFIG: any;

glob _TS_CONFIG: any;

glob _TSX_CONFIG: any;

glob _JAVA_CONFIG: any;

glob _GROOVY_CONFIG: any;

glob _C_CONFIG: any;

glob _CPP_CONFIG: any;

glob _RUBY_CONFIG: any;

glob _CSHARP_CONFIG: any;

glob _KOTLIN_CONFIG: any;

glob _SCALA_CONFIG: any;

glob _PHP_CONFIG: any;

glob _LUA_CONFIG: any;

glob _SWIFT_CONFIG: any;

glob _RATIONALE_PREFIXES: any;

glob _TS_IMPORT_CALL_RE: any;

glob _TsRangeIndex: any;

glob _TS_EXPORT_TYPE_STAR_RE: any;

glob _TS_TYPED_TAG_RE: any;

glob _TS_QUALIFIED_IMPORT_TYPE_RE: any;

glob _JS_RATIONALE_PREFIXES: any;

glob _JS_DOC_REF_RE: any;

glob _JS_COMMENT_LINE_RE: any;

glob _ASTRO_FRONTMATTER_RE: any;

glob _ASTRO_SCRIPT_RE: any;

glob _ASTRO_NON_JS_TYPE_RE: any;

glob _EJS_SCRIPT_TAG_RE: any;

glob _EJS_INCLUDE_RE: any;

glob _CPP_STRING_TEST_MACROS: any;

glob _CPP_STRING_TEST_RE: any;

glob _CPP_CLI_MARKER_RE: any;

glob _CPP_CLI_CLASS_RE: any;

glob _CPP_CLI_SUFFIX_UNAMBIGUOUS_RE: any;

glob _CPP_CLI_SUFFIX_DECL_RE: any;

glob _CPP_CLI_ATTR_RE: any;

glob _CPP_EXPORT_MACRO_RE: any;

glob _CPP_CONDITIONAL_TOKEN_RE: any;

glob _CPP_CONDITIONAL_VARIANT_LIMIT: any;

glob _CSHARP_CONTEXTUAL_NAMES: any;

glob _CSHARP_ASSIGNMENT_OPERATORS: any;

glob _CSHARP_NAME_FOLLOWERS: any;

glob _CSHARP_BLANK_TABLE: any;

glob _CSHARP_NOT_A_TYPE: any;

glob _CSHARP_MEMBER_DECL_RE: any;

glob _PHP_SCRIPT_RE: any;

glob _PHP_UNPARSED_CAST_RE: any;

glob _PHP_NON_CODE: any;

glob _CASE_INSENSITIVE_EXTS: any;

glob _LANG_FAMILY_BY_EXT: dict[str, str];

glob _LANGUAGE_BUILTIN_BASE_CLASSES: dict[str, frozenset[str]];

glob _LANGUAGE_BUILTIN_BASE_CLASSES_CI: dict[str, frozenset[str]];

glob UNRESOLVED_CALLS_KEY: any;

glob _MAX_PARKED_CALLS_PER_NODE: any;

glob _JS_TS_SUFFIXES: any;

glob _CSHARP_BCL_MEMBER_NAMES: any;

glob _CSHARP_WELL_KNOWN_TYPES: any;

glob _CSHARP_KEYWORD_TYPE_ALIASES: any;

glob _CSHARP_SYSTEM_TYPE_KEYWORDS: any;

glob _CSHARP_KEYWORD_VALUE_TYPES: any;

glob _JVM_NAME_SUFFIXES: any;

glob _JAVA_IMPORT_RE: any;

glob _C_FAMILY_HEADER_EXTS: any;

glob _KOTLIN_IMPORT_TARGET_RESOLVER: any;

glob _PROJECT_XML_MAX_BYTES: any;

glob _EVENT_HANDLER_SIGNATURE_RE: any;

glob _XAML_NON_EVENT_ATTRS: any;

glob _XAML_IDENT_RE: any;

glob _XAML_DESIGN_INSTANCE_TYPE_RE: any;

glob _XAML_TOOLKIT_FIELD_RE: any;

glob _XAML_TOOLKIT_METHOD_RE: any;

glob _XAML_CSHARP_CLASS_CACHE: dict[str, dict[str, list[dict[str, Any]]]];

glob _DISPATCH: dict[str, Any];

glob _EXTRA_FOR_EXTENSION: any;

glob _DEP_MISSING_MARKER: any;

glob _DEP_LOAD_FAILED_MARKER: any;

glob _SHEBANG_DISPATCH: dict[str, Any];

glob _SNIFF_BYTES: any;

glob _OBJC_HEADER_MARKERS: any;

glob _CPP_HEADER_MARKERS: any;

glob _BYTES_PER_WORKER: any;

glob _PARALLEL_THRESHOLD: any;

glob RUN_ONLY_EXTRACTION_KEYS: any;

glob paths: list[Path];

glob arg: any;

glob result: any;

with entry {
    SEMANTIC_RELATIONS = frozenset({
        "inherits",
        "implements",
        "mixes_in",
        "embeds",
        "references",
        "calls",
        "imports",
        "imports_from",
        "re_exports",
        "contains",
        "method",
    });
}

"""Get the name from a node using config.name_field, falling back to child types."""
def _resolve_name(`node, source: bytes, config: LanguageConfig) -> str | None;

"""Return (imported name, local binding) pairs from a Python import node."""
def _python_import_bindings(`node, source: bytes) -> list[tuple[str, str]];

"""Dotted module name, relative to ``root``, of an unresolved relative import.

    ``attempted`` is the file the import would have named (``pkg/missing.py`` or
    ``pkg/__init__.py``). Falls back to ``ref:`` + the raw specifier when the
    import climbs above the scan root, so the id never carries an absolute path.
    """
def _missing_relative_module_name(attempted: Path, `root: Path, raw: str) -> str;

"""True when ``node`` sits in the body of an ``if TYPE_CHECKING:`` block.

    Matches ``TYPE_CHECKING`` and ``<module>.TYPE_CHECKING`` (``typing.``,
    ``t.``, ``typing_extensions.``). Only the guarded body counts: the
    ``else:`` branch of the same ``if`` runs at import time, and so does the
    body of ``if not TYPE_CHECKING:``.
    """
def _python_under_type_checking(`node, source: bytes) -> bool;

def _import_python(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
    scan_root: Path | None = None,
) -> None;

def _import_js(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
) -> None;

def _import_java(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
) -> None;

def _import_c(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
) -> None;

def _import_csharp(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
) -> None;

def _import_kotlin(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
) -> None;

def _import_scala(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
) -> None;

def _import_php(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
) -> None;

"""Recursively unwrap declarator to find the innermost identifier (C)."""
def _get_c_func_name(`node, source: bytes) -> str | None;

with entry {
    _PYTHON_CONFIG = LanguageConfig(
        ts_module="tree_sitter_python",
        class_types=frozenset({"class_definition"}),
        function_types=frozenset({"function_definition"}),
        import_types=frozenset({"import_statement", "import_from_statement"}),
        call_types=frozenset({"call"}),
        call_function_field="function",
        call_accessor_node_types=frozenset({"attribute"}),
        call_accessor_field="attribute",
        call_accessor_object_field="object",
        function_boundary_types=frozenset({"function_definition"}),
        import_handler=_import_python,
    );

    _JS_CONFIG = LanguageConfig(
        ts_module="tree_sitter_javascript",
        class_types=frozenset({"class_declaration"}),
        function_types=frozenset({
            "function_declaration",
            "generator_function_declaration",
            "method_definition",
        }),
        import_types=frozenset({"import_statement", "export_statement"}),
        call_types=frozenset({
            "call_expression",
            "new_expression",
            "jsx_opening_element",
            "jsx_self_closing_element",
        }),
        call_function_field="function",
        call_accessor_node_types=frozenset({"member_expression"}),
        call_accessor_field="property",
        call_accessor_object_field="object",
        function_boundary_types=frozenset({
            "function_declaration",
            "generator_function_declaration",
            "arrow_function",
            "method_definition",
            "function_expression",
            "generator_function",
        }),
        import_handler=_import_js,
    );

    _TS_CONFIG = LanguageConfig(
        ts_module="tree_sitter_typescript",
        ts_language_fn="language_typescript",
        class_types=frozenset({
            "class_declaration",
            "abstract_class_declaration",
            "interface_declaration",
            "enum_declaration",
            "type_alias_declaration",
        }),
        function_types=frozenset({
            "function_declaration",
            "generator_function_declaration",
            "method_definition",
            "method_signature",
            "abstract_method_signature",
        }),
        import_types=frozenset({"import_statement", "export_statement"}),
        call_types=frozenset({"call_expression", "new_expression"}),
        call_function_field="function",
        call_accessor_node_types=frozenset({"member_expression"}),
        call_accessor_field="property",
        call_accessor_object_field="object",
        function_boundary_types=frozenset({
            "function_declaration",
            "generator_function_declaration",
            "arrow_function",
            "method_definition",
            "function_expression",
            "generator_function",
        }),
        import_handler=_import_js,
    );
    _TSX_CONFIG = LanguageConfig(
        ts_module="tree_sitter_typescript",
        ts_language_fn="language_tsx",
        class_types=_TS_CONFIG.class_types,
        function_types=_TS_CONFIG.function_types,
        import_types=_TS_CONFIG.import_types,
        call_types=_TS_CONFIG.call_types | {"jsx_opening_element", "jsx_self_closing_element"},
        call_function_field=_TS_CONFIG.call_function_field,
        call_accessor_node_types=_TS_CONFIG.call_accessor_node_types,
        call_accessor_field=_TS_CONFIG.call_accessor_field,
        call_accessor_object_field=_TS_CONFIG.call_accessor_object_field,
        function_boundary_types=_TS_CONFIG.function_boundary_types,
        import_handler=_TS_CONFIG.import_handler,
    );

    _JAVA_CONFIG = LanguageConfig(
        ts_module="tree_sitter_java",
        class_types=frozenset({
            "class_declaration",
            "interface_declaration",
            "record_declaration",
            "enum_declaration",
            "annotation_type_declaration",
        }),
        function_types=frozenset({"method_declaration", "constructor_declaration"}),
        import_types=frozenset({"import_declaration"}),
        call_types=frozenset({"method_invocation", "object_creation_expression"}),
        call_function_field="name",
        call_accessor_node_types=frozenset(),
        function_boundary_types=frozenset({"method_declaration", "constructor_declaration"}),
        import_handler=_import_java,
    );

    _GROOVY_CONFIG = LanguageConfig(
        ts_module="tree_sitter_groovy",
        class_types=frozenset({"class_declaration", "interface_declaration", "enum_declaration"}),
        function_types=frozenset({"method_declaration", "constructor_declaration"}),
        import_types=frozenset({"import_declaration"}),
        call_types=frozenset({"method_invocation"}),
        call_function_field="name",
        call_accessor_node_types=frozenset(),
        function_boundary_types=frozenset({"method_declaration", "constructor_declaration"}),
        import_handler=_import_java,
    );

    _C_CONFIG = LanguageConfig(
        ts_module="tree_sitter_c",
        class_types=frozenset(),
        function_types=frozenset({"function_definition"}),
        import_types=frozenset({"preproc_include"}),
        call_types=frozenset({"call_expression"}),
        call_function_field="function",
        call_accessor_node_types=frozenset({"field_expression"}),
        call_accessor_field="field",
        function_boundary_types=frozenset({"function_definition"}),
        import_handler=_import_c,
        resolve_function_name_fn=_get_c_func_name,
    );

    _CPP_CONFIG = LanguageConfig(
        ts_module="tree_sitter_cpp",
        class_types=frozenset({
            "class_specifier",
            "struct_specifier",
            "enum_specifier",
            "union_specifier",
        }),
        function_types=frozenset({"function_definition"}),
        import_types=frozenset({"preproc_include"}),
        call_types=frozenset({"call_expression"}),
        call_function_field="function",
        call_accessor_node_types=frozenset({"field_expression", "qualified_identifier"}),
        call_accessor_field="field",
        function_boundary_types=frozenset({"function_definition"}),
        import_handler=_import_c,
        resolve_function_name_fn=_get_cpp_func_name,
    );
}

"""Encode trailing Ruby method suffixes (!, ?, =) into safe node ID components (#3077)."""
def _ruby_sanitize_method_name(name: str) -> str;

with entry {
    _RUBY_CONFIG = LanguageConfig(
        ts_module="tree_sitter_ruby",
        class_types=frozenset({"class", "module"}),
        function_types=frozenset({"method", "singleton_method"}),
        import_types=frozenset(),
        call_types=frozenset({"call"}),
        call_function_field="method",
        call_accessor_node_types=frozenset(),
        name_fallback_child_types=("constant", "scope_resolution", "identifier"),
        body_fallback_child_types=("body_statement",),
        function_boundary_types=frozenset({"method", "singleton_method"}),
        sanitize_symbol_name_fn=_ruby_sanitize_method_name,
    );

    _CSHARP_CONFIG = LanguageConfig(
        ts_module="tree_sitter_c_sharp",
        class_types=frozenset({
            "class_declaration",
            "interface_declaration",
            "enum_declaration",
            "struct_declaration",
            "record_declaration",
            "delegate_declaration",
        }),
        function_types=frozenset({"method_declaration"}),
        import_types=frozenset({"using_directive"}),
        call_types=frozenset({"invocation_expression", "object_creation_expression"}),
        call_function_field="function",
        call_accessor_node_types=frozenset({"member_access_expression"}),
        call_accessor_field="name",
        body_fallback_child_types=("declaration_list",),
        function_boundary_types=frozenset({"method_declaration"}),
        import_handler=_import_csharp,
    );

    _KOTLIN_CONFIG = LanguageConfig(
        ts_module="tree_sitter_kotlin",
        class_types=frozenset({"class_declaration", "object_declaration", "type_alias"}),
        function_types=frozenset({"function_declaration"}),
        import_types=frozenset({"import_header", "import"}),
        call_types=frozenset({"call_expression"}),
        call_function_field="",
        call_accessor_node_types=frozenset({"navigation_expression"}),
        call_accessor_field="",
        name_fallback_child_types=("simple_identifier", "identifier"),
        body_fallback_child_types=("function_body", "class_body", "enum_class_body"),
        function_boundary_types=frozenset({"function_declaration"}),
        import_handler=_import_kotlin,
    );

    _SCALA_CONFIG = LanguageConfig(
        ts_module="tree_sitter_scala",
        class_types=frozenset({
            "class_definition",
            "object_definition",
            "trait_definition",
            "enum_definition",
            "given_definition",
        }),
        function_types=frozenset({"function_definition", "function_declaration"}),
        import_types=frozenset({"import_declaration"}),
        call_types=frozenset({"call_expression"}),
        call_function_field="",
        call_accessor_node_types=frozenset({"field_expression"}),
        call_accessor_field="field",
        name_fallback_child_types=("identifier",),
        body_fallback_child_types=("template_body", "enum_body", "with_template_body"),
        function_boundary_types=frozenset({"function_definition"}),
        import_handler=_import_scala,
    );

    _PHP_CONFIG = LanguageConfig(
        ts_module="tree_sitter_php",
        ts_language_fn="language_php",
        class_types=frozenset({
            "class_declaration",
            "interface_declaration",
            "enum_declaration",
            "trait_declaration",
        }),
        function_types=frozenset({
            "function_definition",
            "method_declaration",
            "anonymous_function",
            "arrow_function",
        }),
        import_types=frozenset({"namespace_use_clause"}),
        call_types=frozenset({
            "function_call_expression",
            "member_call_expression",
            "scoped_call_expression",
            "class_constant_access_expression",
            "object_creation_expression",
        }),
        static_prop_types=frozenset({"scoped_property_access_expression"}),
        helper_fn_names=frozenset({"config"}),
        container_bind_methods=frozenset({"bind", "singleton", "scoped", "instance"}),
        event_listener_properties=frozenset({"listen", "subscribe"}),
        call_function_field="function",
        call_accessor_node_types=frozenset({"member_call_expression"}),
        call_accessor_field="name",
        name_fallback_child_types=("name",),
        body_fallback_child_types=(
            "declaration_list",
            "compound_statement",
            "enum_declaration_list",
        ),
        function_boundary_types=frozenset({
            "function_definition",
            "method_declaration",
            "anonymous_function",
            "arrow_function",
        }),
        import_handler=_import_php,
    );
}

"""Extract require('module') from Lua variable_declaration nodes."""
def _import_lua(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
) -> None;

with entry {
    _LUA_CONFIG = LanguageConfig(
        ts_module="tree_sitter_lua",
        ts_language_fn="language",
        class_types=frozenset(),
        function_types=frozenset({"function_declaration"}),
        import_types=frozenset({"variable_declaration"}),
        call_types=frozenset({"function_call"}),
        call_function_field="name",
        call_accessor_node_types=frozenset({"method_index_expression"}),
        call_accessor_field="method",
        call_accessor_object_field="table",
        name_fallback_child_types=("identifier", "method_index_expression"),
        body_fallback_child_types=("block",),
        function_boundary_types=frozenset({"function_declaration"}),
        import_handler=_import_lua,
    );
}

"""Emit module-level ``imports`` edges and report the imported modules.

    A Swift ``import CoreKit`` names a module, not a file path, so — unlike the
    file-resolving JS/TS handlers — there is no existing node for the edge to
    point at. The returned ``(id, label)`` pairs let the extractor materialize a
    ``type=module`` anchor node so the edge survives; without it ``build_from_json``
    prunes every Swift import edge as a dangling/external reference (#1327).
    """
def _import_swift(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
) -> list[tuple[str, str]];

with entry {
    _SWIFT_CONFIG = LanguageConfig(
        ts_module="tree_sitter_swift",
        class_types=frozenset({"class_declaration", "protocol_declaration"}),
        function_types=frozenset({
            "function_declaration",
            "protocol_function_declaration",
            "init_declaration",
            "deinit_declaration",
            "subscript_declaration",
            "macro_declaration",
        }),
        import_types=frozenset({"import_declaration"}),
        call_types=frozenset({"call_expression", "macro_invocation"}),
        call_function_field="",
        call_accessor_node_types=frozenset({"navigation_expression"}),
        call_accessor_field="",
        name_fallback_child_types=("simple_identifier", "type_identifier", "user_type"),
        body_fallback_child_types=(
            "class_body",
            "protocol_body",
            "function_body",
            "enum_class_body",
        ),
        function_boundary_types=frozenset({
            "function_declaration",
            "protocol_function_declaration",
            "init_declaration",
            "deinit_declaration",
            "subscript_declaration",
        }),
        import_handler=_import_swift,
    );

    _RATIONALE_PREFIXES = (
        "# NOTE:",
        "# IMPORTANT:",
        "# HACK:",
        "# WHY:",
        "# RATIONALE:",
        "# TODO:",
        "# FIXME:",
    );
}

"""Collapse whitespace and truncate ``text`` to ``width`` chars for a
    rationale node label, cutting on a word boundary rather than mid-word.
    Shared by the Python and JS/TS rationale extractors (#2206).

    ``textwrap.shorten`` collapses to just the placeholder when the first
    "word" alone exceeds ``width`` (e.g. a docstring/comment that opens with
    an unbroken URL) -- that would emit a content-free label, so fall back to
    a plain character truncation of the normalized text in that case.
    """
def _shorten_rationale_label(text: str, width: int = 80) -> str;

"""Return True if this Python file is auto-generated and its module docstring is noise.

    Covers: Alembic/Flask-Migrate revisions, Django migrations, protobuf/gRPC/OpenAPI stubs.
    Module docstrings in these files are change annotations or boilerplate, not rationale.
    """
def _is_autogenerated_python(source: bytes) -> bool;

"""Post-pass: extract docstrings and rationale comments from Python source.
    Mutates result in-place by appending to result['nodes'] and result['edges'].
    """
def _extract_python_rationale(path: Path, result: dict) -> None;

with entry {
    _TS_IMPORT_CALL_RE = re.compile(b"\\bimport\\s*\\(\\s*['\\\"][^'\\\"\\r\\n]+['\\\"]\\s*\\)");
}

"""Return whether an import-call match starts in executable source.

    Regex matching is only used to locate a literal specifier; comments,
    strings, regular expressions, and template text must never be fed into the
    structural masking pass.  A template substitution is executable again, so
    it is the one exception to the ``template_string`` guard.
    """
def _ts_import_is_code(`root: Any, start: int) -> bool;

"""Collect byte ranges tree-sitter already parsed as type arguments."""
def _ts_type_argument_ranges(`root: Any, *, call_only: bool) -> list[tuple[int, int]];

with entry {
    _TsRangeIndex = Tuple[List[int], List[Tuple[int, int]], List[int]];
}

"""Return the ranges in ``ranges`` that contain ``offset``.

    Scanning the full range list for every match made
    :func:`_normalize_ts_import_types` O(matches x ranges); on a large monorepo
    file with thousands of generic calls and thousands of ``import(...)`` types
    that quadratic blowup pinned a worker at 100% CPU with no output and no file
    I/O, so extraction never finished (#3359).

    Every range containing ``offset`` must start at or before it, so binary-search
    to the last such start and walk left. A range that ends before ``offset`` is
    not itself a hit but must not stop the walk -- a closed sibling can sit inside
    an enclosing range that does contain ``offset``. The index's running maximum of
    ends (``prefix_max_end``) gives the correct stop: once no range at or before
    this position reaches past ``offset``, none of the remaining ones can.
    """
def _ts_ranges_containing(ranges: _TsRangeIndex, offset: int) -> list[tuple[int, int]];

"""Index :func:`_ts_type_argument_ranges` for :func:`_ts_ranges_containing`.

    Returns the ranges sorted by start, split into a bare ``starts`` list for
    :func:`bisect_right`, plus a prefix-maximum of ``end`` values so a lookup can
    tell when no earlier range can still reach a given offset.
    """
def _ts_build_range_index(`root: Any, *, call_only: bool) -> _TsRangeIndex;

"""Return parser error nodes without depending on a grammar's error name."""
def _ts_error_nodes(`root: Any) -> list[Any];

"""Tell whether a masked generic is backed by an actual parse failure.

    A valid runtime comparison can have the same token shape as a generic call
    after the import is replaced (``a < import("x") > (a)``).  Tree-sitter
    exposes the opening ``<`` as a binary operator in the original tree for
    both forms, so the structural second pass alone cannot distinguish them.
    Only repair that ambiguity when the original parser has an error adjacent
    to the candidate's closing angle; that is the signature of the known
    ``import(...)``-type grammar failure.  Valid comparisons, including ones
    nested in another call's arguments, remain byte-for-byte untouched.
    """
def _ts_mask_candidate_is_malformed(
    original_root: Any, masked_range: tuple[int, int], errors: list[Any]
) -> bool;

with entry {
    _TS_EXPORT_TYPE_STAR_RE = re.compile(b"\\bexport\\s+(type)\\s*\\*");
}

"""Rewrite ``export type * from "..."`` to a plain ``export * from "..."``.

    TS 5.0's type-only star re-export has no equivalent in tree-sitter-typescript
    0.23 (the latest release as of #3942): the grammar raises an ERROR on the
    ``type`` keyword in this position and the whole file is dropped, losing
    every symbol, not just the one statement. The construct is erased at
    compile time, the same as ``import type`` / ``export type { X }``, so the
    graph only needs the re-export edge, not the type-only distinction —
    blank out ``type`` (keeping every other byte and offset identical) so the
    grammar parses the ordinary, already-supported ``export * from "..."``
    form instead. Unlike ``import(...)``, this prefix is never ambiguous with
    a runtime expression, so no AST-based disambiguation pass is needed here.
    """
def _normalize_ts_export_type_star(source: bytes) -> bytes | None;

"""Rewrite only syntactic TypeScript ``import(...)`` type arguments.

    The first implementation of #3154 used a ``<...>`` regular expression.
    In semicolon-less code that expression could span two comparison
    operators, so a *runtime* dynamic import was blanked before parsing.  A
    temporary, byte-preserving mask lets tree-sitter identify the actual
    ``type_arguments`` node without asking it to parse the known-invalid
    ``import(...)`` call-site form.  We then rewrite only placeholders inside
    call/new-expression type arguments.  Keeping every replacement the same
    byte length preserves source offsets and line locations.
    """
def _normalize_ts_import_types(source: bytes, *, tsx: bool = False) -> bytes | None;

"""Extract classes, functions, and imports from a .py file via tree-sitter AST."""
def extract_python(path: Path, *, `root: Path | None = None) -> dict;

with entry {
    _TS_TYPED_TAG_RE = re.compile(
        b"(?<![A-Za-z0-9_$])(?P<tag>[A-Za-z_$][A-Za-z0-9_$]*)(?P<types><\\s*\\{[^{}]*\\}\\s*\\[\\s*\\]\\s*>)(?=\\s*`)",
    );
    _TS_QUALIFIED_IMPORT_TYPE_RE = re.compile(
        b"\\bimport\\s*\\(\\s*['\\\"][^'\\\"\\r\\n]+['\\\"]\\s*\\)\\s*\\.(?P<name>[A-Za-z_$][A-Za-z0-9_$]*)(?=\\s*<)",
    );
}

"""Repair two parser gaps without changing runtime expressions or byte offsets.

    A typed tagged template with an object-array type and an import-qualified
    generic type annotation are valid TypeScript, but this grammar can lose
    later declarations. Mask only confirmed type syntax in a temporary parse;
    the original source and line/byte positions remain untouched.
    """
def _normalize_ts_tag_and_import_annotations(source: bytes, *, tsx: bool = False) -> bytes | None;

"""Extract classes, functions, arrow functions, and imports from a .js/.ts/.tsx/.mts/.cts file."""
def extract_js(path: Path) -> dict;

"""Recover ``import('…')`` edges the AST pass does not emit for plain JS/TS.

    tree-sitter models ``await import('x')`` as a ``call_expression``, not an
    ``import_statement``, so the specifier only reaches the graph when
    ``walk_calls`` visits that call — which it never does at module scope
    (only function bodies are walked for calls). The Svelte/Astro/Vue
    extractors already patch the same gap by regex because their AST pass
    fails wholesale; plain ``.ts``/``.js`` was left out on the reasoning that
    its AST pass "works". It works for STATIC imports; dynamic ones outside a
    walked body fell through silently (#2575), and because they cluster under
    hub modules the loss compounds with ``affected`` traversal depth.

    Dedupe: a dynamic import the AST pass DID capture is already in the graph
    as an ``imports_from`` edge marked ``deferred`` (``_dynamic_import_js``).
    Re-emitting it here as a second ``dynamic_import`` edge would state the
    same fact twice, so a match whose resolved target already has a deferred
    edge FROM THIS FILE'S NODE is skipped. The source check matters: the AST
    pass anchors the edge on the enclosing function when the ``import()`` is
    written inside one, and that is a different fact from "this file depends on
    that module" — the only one file-level traversal can use (#2584).

    Regex false positives in comments/strings are the precedented trade of
    the Svelte/Vue rescues; a ``//``-prefix guard covers the common case.
    """
def _rescue_js_dynamic_imports(
    path: Path, result: dict, *, type_only_import_offsets: set[int] | None = None
) -> None;

with entry {
    _JS_RATIONALE_PREFIXES = (
        "// NOTE:",
        "// IMPORTANT:",
        "// HACK:",
        "// WHY:",
        "// RATIONALE:",
        "// TODO:",
        "// FIXME:",
        "* NOTE:",
        "* IMPORTANT:",
        "* HACK:",
        "* WHY:",
        "* RATIONALE:",
        "* TODO:",
        "* FIXME:",
    );
    _JS_DOC_REF_RE = re.compile("\\b(ADR[- ]?\\d{1,5}|RFC[- ]?\\d{1,5})\\b", re.IGNORECASE);
    _JS_COMMENT_LINE_RE = re.compile("^\\s*(//|/\\*|\\*)");
}

"""Post-pass: extract rationale comments and doc references from JS/TS source.
    Mutates result in-place by appending to result['nodes'] and result['edges'].
    """
def _extract_js_rationale(path: Path, result: dict) -> None;

"""Resolve a regex-rescued import specifier the way ``_import_js`` does.

    Returns ``(node_id, stub_source_file, resolved_file, is_external)`` — ``resolved_file``
    is the target as a real on-disk file, or None when the specifier is
    external or dangling. Returns None when no target can be minted at all
    (empty bare-import segment). Split out of :func:`_emit_rescued_import` so
    :func:`_rescue_js_dynamic_imports` can resolve a match FIRST and skip
    specifiers the AST pass already emitted, without duplicating the
    resolution rules.
    """
def _resolve_rescued_specifier(
    path: Path, raw: str, aliases, base_url
) -> "tuple[str, str, Path | None, bool] | None";

"""Shared edge/stub emit for the Svelte/Astro/Vue regex-rescue import passes.

    Resolves the specifier the same way ``_import_js`` does — relative paths and
    tsconfig aliases both go through :func:`_resolve_js_module_path` so
    extensionless specifiers probe real on-disk extensions (``../lib/content``
    -> ``content.ts``) instead of a naive ``.js``->``.ts`` suffix swap.

    When the resolved target is a real file on disk, mirror ``_import_js``:
    emit ONLY the edge, stamped with ``target_file``, and mint no stub node.
    The #2169 canonicalization loop in :func:`extract` reads the stamp and
    repoints the edge at the real file node's canonical id. Minting a stub
    here would carry an absolute-path-derived id when the input path is
    absolute — a ghost node (e.g. ``private_tmp_..._src_lib_content``)
    duplicating the real ``src_lib_content`` node and clobbering its label on
    dedupe (#2195). Stub nodes are still minted for unresolved specifiers
    (externals, not-yet-created files) so prior behavior is preserved.
    """
def _emit_rescued_import(
    result: dict,
    existing_ids: set,
    file_node_id: str,
    path: Path,
    raw: str,
    relation: str,
    aliases,
    base_url,
) -> None;

"""Extract imports and symbols from .svelte files: script-block AST + template regex fallback.

    The AST pass parses only the ``<script>`` bodies, blanking the markup and
    style regions so line numbers still line up — the same masking
    :func:`extract_vue` and :func:`extract_astro` use. Feeding the whole file to
    the JS grammar made the template a top-level ERROR at line 1, so every
    ``.svelte`` file was flagged as a syntax error and no symbol inside
    ``<script>`` (functions, classes, runes) was ever reached; only imports
    survived, via the regex rescue below (#3928).

    The grammar follows the first block's declared ``lang`` (``js``/``jsx``→JS,
    ``ts`` or unset→TS, a superset of JS), matching Svelte's own default. Both
    ``<script>`` and ``<script module>`` / ``<script context="module">`` blocks
    are parsed. A ``<script>`` carrying a non-JS ``type`` (``application/ld+json``
    and the like) is masked out rather than parsed as code.

    Svelte template syntax like {#await import('./X.svelte')} lives in the markup
    layer and is invisible to the JS parser, so a regex pass covers those
    dynamic imports.
    """
def extract_svelte(path: Path) -> dict;

with entry {
    _ASTRO_FRONTMATTER_RE = re.compile("\\A\\s*---[^\\S\\r\\n]*\\r?\\n([\\s\\S]*?)\\r?\\n---");
    _ASTRO_SCRIPT_RE = _HTML_SCRIPT_TAG_RE;
    _ASTRO_NON_JS_TYPE_RE = _NON_JS_SCRIPT_TYPE_RE;
}

"""Blank everything in a ``.astro`` file except frontmatter and JS ``<script>`` bodies.

    Every character outside those regions becomes a space (``\\r``/``\\n`` are kept),
    so AST locations match the original file. Scripts with a non-JS ``type``
    (``application/ld+json`` and the like) are blanked too: their bodies are not
    statements and would only add parse errors.
    """
def _astro_mask_non_script(src: str) -> str;

"""Extract imports from .astro files: frontmatter (TS) + template regex fallback.

    Astro files start with a ``---\\n...\\n---`` frontmatter block of TypeScript
    setup code (where almost all imports live), followed by an HTML-with-expressions
    template body, and optionally ``<script>`` blocks for client-side JS. Tree-sitter
    only sees the file usefully through the frontmatter — feeding the whole file to
    the JS parser produces a top-level ERROR node because the template is not valid
    JS, so ``import_statement`` nodes are never reached and static imports are
    silently dropped (#850). Mirrors :func:`extract_svelte` — same regex-rescue
    approach, scanning the frontmatter block and any client-side ``<script>`` blocks
    for static and dynamic imports.

    The AST pass parses only the frontmatter and JS ``<script>`` bodies with the TS
    grammar (Astro's default), blanking everything else so line numbers still
    line up — the same masking as :func:`_vue_mask_non_script`. Parsing the whole
    file flagged every template as a syntax error and dropped frontmatter symbols.
    """
def extract_astro(path: Path) -> dict;

with entry {
    _EJS_SCRIPT_TAG_RE = _HTML_SCRIPT_TAG_RE;
    _EJS_INCLUDE_RE = re.compile("<%(?:_|[-=])?\\s*include\\s*\\(\\s*['\"]([^'\"]+)['\"]");
}

"""Blank an EJS template down to the JavaScript a parser can read.

    Keeps the bodies of code tags (``<% %>`` / ``<%_ %>``) and of JS ``<script>``
    blocks; markup, ``<%# %>`` comments and ``<%= %>``/``<%- %>`` output
    expressions become spaces, with ``\\r``/``\\n`` preserved so AST line
    numbers and byte offsets still match the original file. An output tag inside
    a ``<script>`` body is replaced by a length-preserving ``0`` so the
    surrounding statement still parses (``const x = <%- data %>;``).
    """
def _ejs_mask_non_script(src: str) -> str;

"""Emit the template-composition edge for ``<%- include('partial') %>``.

    EJS resolves an include relative to the including template, so probe the
    template's own directory through :func:`_resolve_js_import_path` — which,
    now that ``.ejs`` is a JS resolve extension, appends ``.ejs``/``index.ejs``
    the way EJS itself does. A relative hit is stamped with ``target_file`` so
    the #2169 canonicalization pass repoints it at the real template node; a
    bare/views-root include that cannot be resolved keeps a stub node, so the
    edge is never dropped.
    """
def _emit_ejs_include(
    result: dict, existing_ids: set, file_node_id: str, path: Path, raw: str, line: int
) -> None;

"""Extract imports, symbols, and `include()` composition from an EJS template.

    EJS is HTML carrying ``<% %>`` scriptlets and inline ``<script>`` blocks, so
    the whole file is not JS: fed to the JS grammar it becomes a top-level ERROR
    and every symbol inside a scriptlet is lost (``_ejs_mask_non_script`` keeps
    only the JS regions, preserving line numbers). The AST pass then reads the
    template's real JavaScript — ``require``/``import`` edges, functions,
    classes — and two regex passes add what no JS grammar can see: dynamic
    ``import('./X')`` calls written in a scriptlet, and the EJS
    ``<%- include('partial') %>`` composition edge an Express view graph is
    built on (#3811, #2511).
    """
def extract_ejs(path: Path) -> dict;

"""Extract imports, symbols, and type refs from a ``.vue`` SFC.

    Masks the non-``<script>`` regions and parses the script with the grammar
    its ``lang`` implies (``tsx``→TSX, ``js``/``jsx``→JS, ``ts`` or unset→TS;
    TS is a superset of JS so it is a safe default). A regex pass then recovers
    ``import('…')`` dynamic imports the AST does not edge.
    """
def extract_vue(path: Path) -> dict;

"""Extract classes, interfaces, methods, constructors, and imports from a .java file."""
def extract_java(path: Path) -> dict;

"""Return True when the file contains Spock-style ``def "feature"()`` methods
    that tree-sitter-groovy cannot parse, detected by checking the raw source."""
def _is_spock_file(path: Path, ts_result: dict) -> bool;

"""Regex-based fallback for Spock spec files where tree-sitter-groovy cannot parse
    ``def "feature name"()`` methods. Merges import edges from the tree-sitter pass
    (which survive reliably) with class and feature-method nodes extracted via regex.
    """
def _extract_spock_fallback(path: Path, ts_result: dict) -> dict;

"""Extract classes, methods, constructors, and imports from a .groovy/.gradle file.

    Falls back to a regex-based Spock extractor when tree-sitter-groovy cannot parse
    ``def "feature name"()`` methods (common in Spock specification classes).
    """
def extract_groovy(path: Path) -> dict;

"""Extract functions and includes from a .c/.h file."""
def extract_c(path: Path) -> dict;

with entry {
    _CPP_STRING_TEST_MACROS = ("TEST_CASE", "TEST_CASE_TEMPLATE", "SCENARIO");
    _CPP_STRING_TEST_RE = re.compile(
        "^[ \\t]*(?:"
            + "|".join(_CPP_STRING_TEST_MACROS)
            + ")\\s*\\(\\s*\"((?:[^\"\\\\]|\\\\.)+)\"",
        re.MULTILINE,
    );
}

"""Append callable nodes for doctest/Catch2 string-named test cases that
    tree-sitter-cpp drops as ERROR nodes (issue #2594).

    The generic C++ pass still recovers the surrounding functions and include
    edges reliably, so this only adds the missing ``TEST_CASE("...")`` nodes and
    their ``contains`` edge from the file node — it does not rebuild the result.

    Matching is line-anchored raw text, mirroring the Spock fallback above; it is
    deliberately not comment/preprocessor aware (a ``TEST_CASE`` disabled behind
    a block comment or ``#if 0`` may still surface as a node, exactly as a
    commented Spock ``def "feature"()`` would).
    """
def _augment_cpp_string_tests(path: Path, result: dict) -> dict;

with entry {
    _CPP_CLI_MARKER_RE = re.compile(
        b"\\b(?:ref|value)\\s+(?:class|struct)\\b|\\binterface\\s+class\\b|\\bgcnew\\b|\\[\\s*(?:assembly|module)\\s*:",
    );
    _CPP_CLI_CLASS_RE = re.compile(
        b"(?:\\b(?:public|private|protected)\\s+)?\\b(?:ref|value)\\s+(?=(?:class|struct)\\b)|(?:\\b(?:public|private|protected)\\s+)?\\binterface\\s+(?=class\\b)",
    );
    _CPP_CLI_SUFFIX_UNAMBIGUOUS_RE = re.compile(b"(?<=[A-Za-z0-9_>])[\\^%](?=\\s*[,)\\]>;])");
    _CPP_CLI_SUFFIX_DECL_RE = re.compile(
        b"(\\b[A-Za-z_][A-Za-z0-9_]*(?:::[A-Za-z_][A-Za-z0-9_]*)+|\\b[A-Z][A-Za-z0-9_]*[a-z][A-Za-z0-9_]*|\\b[A-Z](?=[\\^%])|\\b(?:bool|char|wchar_t|short|int|long|float|double|unsigned|signed)|>)[\\^%](?=\\s+[A-Za-z_])",
    );
    _CPP_CLI_ATTR_RE = re.compile(b"\\[\\s*(?:assembly|module)\\s*:[^\\[\\]]*\\]", re.S);
}

"""Replace a match with spaces, but keep its line breaks.

    Byte length alone is not enough. Both the class-header and the attribute
    pattern can span lines — ``[assembly:AssemblyVersion(\\n  "1.0"\\n)]`` is
    ordinary formatting — and blanking a newline merges two source lines, which
    shifts the reported line number of every symbol below it. Preserving CR and
    LF in place keeps line and column stable as well as offset.
    """
def _blank_keeping_newlines(m: "re.Match[bytes]") -> bytes;

"""Rewrite C++/CLI spellings to standard C++ ones, or None if not C++/CLI.

    The rewrite is **byte-length preserving** — dropped tokens are overwritten
    with spaces, never deleted, and ``gcnew`` becomes ``new`` plus padding — and
    line breaks inside a removed token are kept, so every offset, line and
    column still points at the same place in the file on disk and reported
    source locations stay accurate (#2876).
    """
def _normalize_cpp_cli(source: bytes) -> bytes | None;

with entry {
    _CPP_EXPORT_MACRO_RE = re.compile(
        b"(\\b(?:class|struct)[ \\t\\r\\n]+)((?:[A-Z][A-Z0-9_]*[ \\t\\r\\n]+)+)(?!final[ \\t\\r\\n]*[:{])([A-Za-z_][A-Za-z0-9_]*(?:[ \\t\\r\\n]+final)?[ \\t\\r\\n]*)([:{])",
    );
}

"""Blank an export macro between ``class``/``struct`` and the type name.

    Single ALL-CAPS identifier macros (and stacked ones) are handled.
    Note: paren-attribute macros like ``__declspec(dllexport)`` and
    ``__attribute__((visibility("default")))`` are currently unsupported,
    as well as template specializations (e.g. ``template<> class MODULE_API Widget<int>``).
    """
def _normalize_cpp_export_macros(source: bytes) -> bytes;

with entry {
    _CPP_CONDITIONAL_TOKEN_RE = re.compile(
        b"//(?:\\\\\\r?\\n|[^\\r\\n])*|/\\*[\\s\\S]*?(?:\\*/|\\Z)|\\b[0-9](?:[A-Za-z_0-9.]|'[A-Za-z_0-9])*|(?:u8|u|U|L)?R\"([^ ()\\\\\\t\\v\\f\\r\\n]{0,16})\\(|\"(?:\\\\[\\s\\S]|[^\"\\\\])*\"|\\'(?:\\\\[\\s\\S]|[^\\'\\\\])*\\'|^[ \\t\\v\\f]*#[ \\t]*([A-Za-z_][A-Za-z_0-9]*)(?:\\\\\\r?\\n|[^\\r\\n])*",
        re.MULTILINE,
    );
    _CPP_CONDITIONAL_VARIANT_LIMIT = 32;
}

def _cpp_conditional_tokens(source: bytes) -> Generator[any, any, any];

"""Read conditional ranges only; never evaluate macros or open includes."""
def _cpp_conditional_groups(source: bytes) -> tuple[list[dict], str | None];

"""Find candidates lexically; recovered trees must later confirm the scope."""
def _cpp_expression_conditional_groups(source: bytes, groups: list[dict]) -> set[int];

"""Recover expression directives with separate, bounded syntactic branch views.

    shortcut: branch-wise views do not enumerate configurations, use a compilation
    database and a real configured frontend when configuration semantics are needed.
    """
def _recover_cpp_conditional_initializers(path: Path, source: bytes, original: dict) -> dict;

"""Apply recovered source ranges to later resolver edges and parked callsites."""
def _stamp_cpp_condition_provenance(nodes: list[dict], edges: list[dict]) -> None;

"""Extract functions, classes, and includes from a .cpp/.cc/.cxx/.hpp file.

    C++/CLI sources are normalized to standard C++ first (#2876); see
    :func:`_normalize_cpp_cli`.

    Recovers doctest/Catch2 ``TEST_CASE("name")`` test cases that tree-sitter-cpp
    drops as ERROR nodes (issue #2594), mirroring the Spock fallback for Groovy.
    """
def extract_cpp(path: Path) -> dict;

"""Extract classes, methods, singleton methods, and calls from a .rb file."""
def extract_ruby(path: Path) -> dict;

"""Read a possible string-literal opener at ``i``.

    Returns ``(prefix_end, quote_run, interpolated, verbatim)``. ``quote_run`` is
    0 when no string starts here, and ``prefix_end`` is always where the run of
    ``$``/``@`` characters stopped — the caller needs that even on a miss, so it
    can resume past the run instead of re-walking it from the next byte (a long
    run in malformed source would otherwise cost O(n^2)).

    C# lets the ``$`` and ``@`` prefixes appear in either order and repeat, and
    a raw string literal opens with a run of three or more quotes, so the prefix
    is read as a set of flags rather than matched as fixed spellings.
    """
def _csharp_string_opener(source: bytes, i: int) -> "tuple[int, int, bool, bool]";

"""Offsets of the ``""`` pairs that trigger the #3376 grammar bug.

    A verbatim interpolated string whose text ends with an interpolation hole,
    then an escaped quote, then the terminator — the ``}`` ``""`` ``"``
    adjacency — is rejected by tree-sitter-c-sharp 0.23.5 even though it is
    valid C#. Every neighbouring spelling parses, so only that adjacency is
    reported here.

    The file is walked once so a ``$@"`` written inside a comment, a char
    literal or another string is never mistaken for code.
    """
def _csharp_broken_escape_offsets(source: bytes) -> list[int];

"""Neutralize the one verbatim-interpolated spelling the C# grammar rejects, or None.

    A verbatim interpolated string whose text ends with an interpolation hole,
    an escaped quote and then the terminator is valid C# — ``dotnet build``
    accepts it — but tree-sitter-c-sharp 0.23.5 rejects it, so it is partially
    extracted and every member after that line is silently missing from the
    graph. 0.23.5 is the newest release, so there is no grammar bump to take
    (#3376).

    Only the trailing ``""`` escape is overwritten, with two spaces. The
    rewrite is **byte-length preserving** — nothing is inserted or deleted and
    no line break is touched — so every offset, line and column still points at
    the same place in the file on disk and reported source locations stay
    accurate (the #2876 contract). The interpolation hole itself is kept, so
    identifiers referenced inside it still resolve.

    Returns None unless the file genuinely needs it AND the rewrite fixes it:
    a file that already parses is never touched, and if the masked source still
    has errors the original is used, leaving today's behaviour exactly as it is.
    """
def _normalize_csharp_verbatim_interpolation(source: bytes) -> bytes | None;

with entry {
    _CSHARP_CONTEXTUAL_NAMES = frozenset((
        b"partial",
        b"required",
        b"async",
        b"nint",
        b"nuint",
        b"with",
    ));
    _CSHARP_ASSIGNMENT_OPERATORS = (
        b"<<=",
        b">>=",
        b"??=",
        b"+=",
        b"-=",
        b"*=",
        b"/=",
        b"%=",
        b"&=",
        b"|=",
        b"^=",
        b"++",
        b"--",
    );
    _CSHARP_NAME_FOLLOWERS = frozenset(b"=+-*/%&|^<>!?.[;,)]}:");
}

def _csharp_word_byte(b: int) -> bool;

"""Whether the contextual keyword at ``source[start:stop]`` stands where only a name can."""
def _csharp_used_as_name(source: bytes, start: int, stop: int) -> bool;

"""Offsets of the contextual keywords in ``source`` that stand where only a name can.

    The file is walked once, skipping comments, char literals and strings, so a
    word inside one is never reported. An ``@``-escaped name is already read as
    a name and is not reported either.
    """
def _csharp_contextual_name_offsets(source: bytes) -> list[int];

"""Escape the contextual-keyword names the C# grammar rejects, or None.

    A local, parameter or field named ``partial``, ``required``, ``async``,
    ``nint``, ``nuint`` or ``with`` is valid C# -- ``dotnet build`` accepts it --
    but tree-sitter-c-sharp 0.23.5 reads the word as its keyword where a
    statement starts with it (``partial |= x;``, ``required.Add(1);``,
    ``async = 2;``, ``nint = 1;``) and ``with`` in ``var with = 1;`` (#5043).
    The statement becomes an ERROR, and when it is the last statement of an
    ``if`` block that an ``else`` block follows, the recovery takes the rest of
    the file with it, leaving only the file node.

    ``@name`` is the same identifier as ``name`` to the compiler, and the grammar
    reads it as a name. The ``@`` takes the place of a blank next to the name
    (the one after it, else the one before), so the rewrite is **byte-length
    preserving**: no line break moves and every reported line and column still
    points at the file on disk (the #2876 contract). An occurrence with no
    blank next to it is left as it is.

    The occurrences of one word are escaped together, so a local's declaration
    and its uses keep one spelling and a call on it still binds through its
    declared type. A word is left unescaped when the file parses without it, so
    a word the grammar already reads correctly everywhere keeps its spelling.
    Returns None unless the file has an error and the rewrite clears it; a file
    that still fails keeps today's behaviour exactly.
    """
def _escape_csharp_contextual_names(source: bytes) -> bytes | None;

with entry {
    _CSHARP_BLANK_TABLE = `bytes(b if b in (10, 13) else 32 for b in range(256));
}

"""End (exclusive) of the comment, char or string literal opening at ``i``.

    Returns ``i`` when no such token opens there. A line-bounded token (a ``//``
    comment, a char literal, a regular string) stops *before* its newline, so
    the caller still sees the next line start. Holes of interpolated strings
    are walked as code, so a quote inside ``{...}`` does not end the string.
    """
def _csharp_token_end(source: bytes, i: int) -> int;

"""True when ``{}`` and ``()`` in ``text[start:end]`` each net to zero.

    Comments, char and string literals are skipped.
    """
def _csharp_branch_balanced(text: bytearray, start: int, end: int) -> bool;

with entry {
    _CSHARP_NOT_A_TYPE = frozenset({
        b"return",
        b"new",
        b"await",
        b"throw",
        b"if",
        b"while",
        b"for",
        b"foreach",
        b"switch",
        b"case",
        b"using",
        b"lock",
        b"catch",
        b"when",
        b"is",
        b"as",
        b"in",
        b"out",
        b"ref",
        b"else",
        b"yield",
        b"nameof",
        b"typeof",
        b"sizeof",
        b"default",
        b"var",
        b"goto",
        b"fixed",
        b"checked",
        b"unchecked",
        b"and",
        b"or",
        b"not",
    });

    _CSHARP_MEMBER_DECL_RE = re.compile(
        b"([A-Za-z_][A-Za-z0-9_]*|[>\\]?*])\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*(?:<[^<>(){};]*>)?\\s*(\\(|\\{|=>)",
    );
}

"""(name, arity) of the members a branch declares at its own brace depth.

    A heuristic, not a parse: a declaration is an identifier preceded by a
    type-like token (an identifier that is not a statement keyword, or ``>``,
    ``]``, ``?``, ``*``) and followed by ``(`` (arity = top-level commas + 1, 0
    for ``()``) or by ``{``/``=>`` (a property or type, arity -1). Both branches
    of a group sit at the same place in the file, so a shared (name, arity)
    means the same member of the same type is declared twice.
    """
def _csharp_branch_member_sigs(text: bytearray, start: int, end: int) -> set[tuple[bytes, int]];

"""Blank C# preprocessor directives and the ``#if`` branches that derail parsing, or None.

    tree-sitter-c-sharp parses the raw text, directives and all branches
    together. Its error recovery around a directive can close the enclosing
    class early, so every later member loses its type owner, its field typing
    and its calls.

    Every directive line (``#if``/``#elif``/``#else``/``#endif``, and also
    ``#region``, ``#pragma``, ``#nullable``, ``#define`` ...) is blanked. The
    first branch of each ``#if`` group is always kept. A later ``#elif`` /
    ``#else`` branch is kept too, so members that exist only there (an
    older-framework fallback) stay in the graph (#2631), unless keeping it
    would derail the parse:

    * its ``{}`` or ``()`` do not net to zero on their own (``class A : B {``
      ``#else`` ``class A {``), or
    * it declares a member (name + arity) that a kept branch of the same group
      already declares (``void Write(Span<char> s)`` ``#else``
      ``void Write(string s)`` sharing one body).

    Nested groups are decided first, so an outer branch is judged on what is
    left of it. No symbols are evaluated. Measured against the compiler on
    Newtonsoft.Json, Dapper and AutoMapper.

    The rewrite is **byte-length preserving**: removed bytes become spaces and
    every ``\\n``/``\\r`` is kept, so every remaining byte keeps its line and
    column and source locations stay accurate (the #2876 contract).

    A ``#`` line inside a comment or a multi-line string is not a directive;
    comments and string literals are skipped while looking for line starts.
    Returns None when the file has no directive.
    """
def _blank_csharp_preprocessor(source: bytes) -> bytes | None;

"""Extract C# type declarations, methods, namespaces, and usings from a .cs file."""
def extract_csharp(path: Path) -> dict;

"""Extract classes, objects, functions, and imports from a .kt/.kts file."""
def extract_kotlin(path: Path) -> dict;

"""Extract classes, objects, functions, and imports from a .scala file."""
def extract_scala(path: Path) -> dict;

with entry {
    _PHP_SCRIPT_RE = re.compile(
        "<script\\b(?:\\\"[^\\\"]*\\\"|'[^']*'|[^>\\\"'])*>([\\s\\S]*?)</script\\s*>", re.IGNORECASE
    );
}

"""Blank everything outside inline ``<script>`` bodies, keeping line numbers.

    tree-sitter-php treats non-PHP spans (including inline ``<script>`` blocks)
    as opaque text, so JS declared there is invisible to the PHP grammar (#2320).
    Mirrors :func:`_vue_mask_non_script`'s approach: replace every character
    outside a script body with a space (preserving ``\\r``/``\\n`` so source
    locations still line up), leaving only the script content for a JS parse.
    A ``<script src="…"></script>`` with no body masks to an empty region,
    which parses as empty JS and contributes nothing — no special-casing needed.
    Returns ``(masked_source, had_script)``; the caller skips the JS pass
    entirely when ``had_script`` is False.
    """
def _php_mask_to_script_blocks(src: str) -> tuple[str, bool];

with entry {
    _PHP_UNPARSED_CAST_RE = re.compile(
        b"\\(\\s*void\\s*\\)|\\(\\s*(?:string|int|integer|float|double|real|bool|boolean|array|object|binary)\\s*\\)(?=\\s*match\\s*\\()",
        re.IGNORECASE,
    );
    _PHP_NON_CODE = frozenset({
        "comment",
        "string",
        "encapsed_string",
        "heredoc",
        "nowdoc",
        "text",
    });
}

"""Blank `(void)` casts and casts on `match` to spaces, outside strings and
    comments, keeping every byte offset and line number (#4202)."""
def _php_blank_unparsed_casts(source: bytes) -> bytes;

"""Extract classes, functions, methods, namespace uses, and calls from a .php file.

    Also parses any inline ``<script>`` blocks as JavaScript (#2320): the PHP
    grammar sees those spans as opaque markup, so a page mixing PHP with
    client-side JS previously indexed only its PHP half. The JS pass masks
    everything else to blanks (preserving line numbers) and reuses the same
    file node id, so JS symbols land under the one file node like any other
    PHP symbol; a same-name PHP/JS collision (rare — different languages,
    same file) is resolved by keeping the PHP node, since PHP is the file's
    primary language, and dropping every JS edge that touches the id the
    dropped JS node would have used, so no edge from the discarded symbol
    is left to silently attach to the unrelated PHP node sharing its id.
    """
def extract_php(path: Path) -> dict;

"""Extract functions, methods, require() imports, and calls from a .lua file."""
def extract_lua(path: Path) -> dict;

"""Extract classes, structs, protocols, functions, imports, and calls from a .swift file."""
def extract_swift(path: Path) -> dict;

"""Collapse duplicate C# namespace node entries to one canonical node per label."""
def _canonicalize_csharp_namespace_nodes(all_nodes: list[dict], all_edges: list[dict]) -> None;

with entry {
    _CASE_INSENSITIVE_EXTS = frozenset({
        ".php",
        ".phtml",
        ".php3",
        ".php4",
        ".php5",
        ".php7",
        ".phps",
        ".sql",
        ".nim",
        ".nims",
        ".nimble",
        ".cbl",
        ".cob",
        ".cobol",
        ".cpy",
        ".vb",
    });
}

"""True when the file's language resolves identifiers case-insensitively (#1581)."""
def _lang_is_case_insensitive(source_file: object) -> bool;

with entry {
    _LANG_FAMILY_BY_EXT = {
        ".js": "jsts",
        ".jsx": "jsts",
        ".mjs": "jsts",
        ".cjs": "jsts",
        ".ts": "jsts",
        ".tsx": "jsts",
        ".mts": "jsts",
        ".cts": "jsts",
        ".vue": "jsts",
        ".svelte": "jsts",
        ".astro": "jsts",
        ".ejs": "jsts",
        ".java": "jvm",
        ".kt": "jvm",
        ".kts": "jvm",
        ".scala": "jvm",
        ".groovy": "jvm",
        ".gradle": "jvm",
        ".c": "native",
        ".h": "native",
        ".cpp": "native",
        ".cc": "native",
        ".cxx": "native",
        ".hpp": "native",
        ".cu": "native",
        ".cuh": "native",
        ".metal": "native",
        ".m": "native",
        ".mm": "native",
        ".swift": "native",
        ".py": "python",
        ".go": "go",
        ".rs": "rust",
        ".cbl": "cobol",
        ".cob": "cobol",
        ".cobol": "cobol",
        ".cpy": "cobol",
        ".r": "r",
        ".sol": "solidity",
        ".erl": "erlang",
        ".hrl": "erlang",
        ".escript": "erlang",
        ".rb": "ruby",
        ".rake": "ruby",
        ".php": "php",
        ".phtml": "php",
        ".php3": "php",
        ".php4": "php",
        ".php5": "php",
        ".php7": "php",
        ".phps": "php",
        ".cs": "dotnet",
        ".vb": "dotnet",
        ".razor": "dotnet",
        ".cshtml": "dotnet",
        ".xaml": "dotnet",
        ".lua": "lua",
        ".luau": "lua",
        ".zig": "zig",
        ".ex": "elixir",
        ".exs": "elixir",
        ".jl": "julia",
        ".dart": "dart",
        ".sql": "sql",
        ".sh": "shell",
        ".bash": "shell",
        ".ps1": "powershell",
        ".psm1": "powershell",
        ".psd1": "powershell",
    };
}

"""Interop family of the file's language, or None when unknown/not code."""
def _lang_family(source_file: object) -> str | None;

with entry {
    _LANGUAGE_BUILTIN_BASE_CLASSES = {
        "php": frozenset({
            "Throwable",
            "Exception",
            "ErrorException",
            "Error",
            "TypeError",
            "ValueError",
            "ArgumentCountError",
            "ArithmeticError",
            "DivisionByZeroError",
            "RuntimeException",
            "LogicException",
            "InvalidArgumentException",
            "DomainException",
            "LengthException",
            "OutOfRangeException",
            "OutOfBoundsException",
            "RangeException",
            "OverflowException",
            "UnderflowException",
            "UnexpectedValueException",
            "BadFunctionCallException",
            "BadMethodCallException",
            "JsonException",
        }),
        "jvm": frozenset({
            "Throwable",
            "Exception",
            "RuntimeException",
            "Error",
            "IllegalArgumentException",
            "IllegalStateException",
            "UnsupportedOperationException",
            "IndexOutOfBoundsException",
            "NullPointerException",
            "IOException",
        }),
        "python": frozenset({
            "BaseException",
            "Exception",
            "ValueError",
            "TypeError",
            "KeyError",
            "IndexError",
            "RuntimeError",
            "NotImplementedError",
            "AttributeError",
            "OSError",
            "IOError",
            "StopIteration",
            "Warning",
            "UserWarning",
            "DeprecationWarning",
        }),
        "jsts": frozenset({
            "Error",
            "TypeError",
            "RangeError",
            "SyntaxError",
            "ReferenceError",
            "EvalError",
            "URIError",
            "AggregateError",
        }),
        "dotnet": frozenset({
            "Exception",
            "ApplicationException",
            "SystemException",
            "ArgumentException",
            "ArgumentNullException",
            "ArgumentOutOfRangeException",
            "InvalidOperationException",
            "NotImplementedException",
            "NotSupportedException",
        }),
        "ruby": frozenset({
            "Exception",
            "StandardError",
            "RuntimeError",
            "ArgumentError",
            "TypeError",
            "NameError",
            "NoMethodError",
            "IOError",
        }),
    };
    _LANGUAGE_BUILTIN_BASE_CLASSES_CI = {
        family: frozenset(name.lower() for name in names)
        for (family, names) in _LANGUAGE_BUILTIN_BASE_CLASSES.items()
    };
}

def _node_label_key(`node: dict, fold: bool = False) -> str;

"""A free/top-level function def (label ``name()``), not a method or type.

    Methods carry a leading dot (``.foo()``) or a qualifier (``Class.foo()``);
    excluding those keeps a bare-name reference from binding to a receiver-scoped
    method, which the receiver-typed resolvers own (#1781).
    """
def _is_top_level_function_definition(`node: dict) -> bool;

"""Map unresolved no-source stubs to a unique real definition with the same label."""
def _rewire_unique_stub_nodes(
    nodes: list[dict], edges: list[dict], `root: Path | None = None
) -> None;

"""Compatibility wrapper for the JS/TS symbol-resolution post-pass."""
def _augment_js_reexport_edges(
    paths: list[Path], nodes: list[dict], edges: list[dict], `root: Path
) -> None;

"""Rewrite objc_field_types["tables"] KEYS through an id remap (#3150).

    The #2591 field->type tables are the one extractor bucket keyed BY class
    node id. The #1529 passes rewrote node ids, edge endpoints,
    raw_calls[].caller_nid and swift_extensions[].nid but not these keys, so
    whenever a common absolute prefix was stripped (always via
    `graphify update <dir>`) the table keys went stale, every
    field_types_by_class.get(cls) missed, and [self.<field> ...] sends
    resolved to nothing - #2591 was inert through the CLI.
    """
def _remap_objc_field_tables(per_file: list, mapping: dict) -> None;

"""Collapse cross-file Swift `extension Foo` nodes into the canonical `Foo`.

    tree-sitter-swift reuses `class_declaration` for both `class Foo` and
    `extension Foo`, and node ids carry the file stem, so each file that
    extends `Foo` produces its own `Foo` node. The match is done by label:
    when exactly one non-extension declaration shares the label, extension
    nodes redirect onto it. Extensions of types outside the corpus (no match)
    and ambiguous labels (more than one match) are left untouched — picking
    arbitrarily would invent edges.
    """
def _merge_swift_extensions(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;

"""Collapse C# `partial class Foo` halves split across files into ONE node
    (#2332), without crossing assembly boundaries (#2411).

    The per-file extractor mints class ids with the file stem, so each file
    declaring `partial class Foo` produces its own `Foo` node: members split
    across the halves and cross-half calls don't resolve (two candidate types
    make every receiver-typed lookup bail as ambiguous). Group partial-stamped
    type nodes by (assembly, namespace, type path) — same-named types in
    different namespaces are distinct types, non-partial same-named types are
    separate declarations. The type path carries the enclosing types and each
    arity (`` Outer`1.Inner ``): nested ids omit the enclosing type, so the
    path is what keeps same-named nested types under different outers apart,
    and the arity keeps `Foo` and `Foo<T>` apart. The `partial` keyword only
    fuses declarations compiled into the SAME assembly, so the key also
    carries the nearest ancestor directory holding a
    `*.csproj`/`*.fsproj`/`*.vbproj` — same-named halves under
    different project dirs are genuinely distinct types and stay apart. Halves
    with NO project file on any ancestor (up to the scan root) all key to ""
    and still merge together, so single-project/snippet corpora behave exactly
    as before; the probe runs only for groups that are otherwise ambiguous.
    The canonical node is the sorted-first half by (source_file,
    source_location, id); every edge endpoint and raw-call caller is remapped
    onto it. Member node ids are left untouched — only the class-level nodes
    collapse.

    Must run AFTER _disambiguate_colliding_node_ids (so a half whose id collides
    with another file's node is already salted apart, and every edge still sits
    on its own half when it is rewired) and BEFORE _rewire_unique_stub_nodes /
    _resolve_csharp_type_references and the resolver registry, so every later
    pass sees one definition per partial type.
    """
def _merge_csharp_partial_class_nodes(
    per_file: list[dict],
    all_nodes: list[dict],
    all_edges: list[dict],
    paths: list[Path],
    `root: Path,
) -> None;

"""Drop a merged partial type's placeholder base when a real base of the
    same name sits next to it.

    Every half of a partial type may repeat the base list, and C# requires
    the halves to agree. Each half's base name is resolved in its own file's
    scope, so a half whose file the resolver cannot see the base from (a
    sibling nested base without `using static` for its holder, say) leaves a
    placeholder edge while another half binds the real type. After the merge
    the type then has two same-named bases, and lookups through the base chain
    bail as ambiguous. A placeholder spelled with the bare name is the
    unresolved spelling of the resolved base, so it goes. One written
    qualified (`Other.IFoo`) or through a `using` alias of that name can be a
    different type that only shares the simple name, so it stays.
    """
def _drop_shadowed_csharp_partial_bases(all_nodes: list[dict], all_edges: list[dict]) -> None;

with entry {
    UNRESOLVED_CALLS_KEY = "unresolved_calls";
    _MAX_PARKED_CALLS_PER_NODE = 64;
}

"""Keep a member call whose receiver type is declared nowhere in this corpus.

    A single-repo build can only bind ``obj.method()`` when the receiver's type is
    declared in the same build, so a call into another repository is dropped with
    the receiver type already in hand and nothing about it reaches ``graph.json``
    — the one artifact ``merge-graphs`` and ``global add`` consume. Parking the
    pair on the caller node lets a merged graph finish the edge (#3152).

    The payload carries names only, never node ids: ids are rewritten by the
    remaps and again by the repo prefixing, and a stale id inside metadata would
    fail silently (#3150 was that bug). Names survive every rewrite.
    """
def _park_unresolved_member_call(
    caller_node: dict | None, callee: str, receiver_type: str, lang: str, raw_call: dict
) -> None;

"""Resolve cross-file Swift member calls (``recv.method()``) to the real
    definition of the receiver's type (#1356).

    The shared cross-file call pass drops every ``is_member_call`` because a bare
    method name (``update``) collides across the corpus and inflates god-nodes
    (#543/#1219). Swift extractors record the receiver of each member call and a
    per-file ``name -> type`` table (``swift_type_table``); this pass uses them to
    type the receiver, then emits an edge ONLY when that type name resolves to
    exactly one definition. A type-qualified call (``Type.staticMethod()``) is
    EXTRACTED (the type is named explicitly in source); an instance call typed via
    local inference (``obj.method()``) is INFERRED. The shared-pass member-call drop
    stays intact: this is purely additive and fires only on receiver-typed Swift calls.

    Must run after id-disambiguation so node ids and caller_nids are final.
    """
def _resolve_swift_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;

"""Repo-relative locations for the pytest-fixture arm of
    _resolve_python_member_calls. A re-extracted file carries absolute paths while
    an unchanged file's context node (changed-files rebuild) is repo-relative; the
    arm walks directories, so it gets one form. In memory only: results were cached
    before resolution."""
def _stamp_python_fixture_paths(per_file: "list[dict | None]", `root: Path) -> None;

"""Resolve cross-file Python qualified class-method calls (``ClassName.method()``)
    to the class-qualified method node (#1446).

    The shared cross-file call pass drops every ``is_member_call`` because a bare
    method name (``log``) collides across the corpus and inflates god-nodes
    (#543/#1219). That guard is right for *instance* calls (``obj.method()``) but
    misses *class-qualified* calls (``ClassName.method()``), where the receiver is
    an explicitly-named class — an exact, unambiguous reference. This pass uses the
    receiver captured by the extractor, and when it is a capitalized name resolving
    to exactly one class node that owns the called method, emits an EXTRACTED
    ``calls`` edge. Purely additive (only member calls the shared pass skipped),
    with a single-definition god-node guard.

    Must run after id-disambiguation so node ids and caller_nids are final.
    """
def _resolve_python_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;

with entry {
    _JS_TS_SUFFIXES = (".ts", ".tsx", ".mts", ".cts", ".js", ".jsx", ".mjs", ".cjs");
}

"""Resolve cross-file TS/JS member calls via constructor-injection type tables (#1316).

    ``this.repo.findById()`` drops out in the shared cross-file pass because bare
    ``findById`` collides across the corpus (god-node guard).  TS constructors with
    parameter-property modifiers (``private repo: IUserRepository``) produce a
    per-file type table mapping field names to their declared types.  This pass
    looks up the receiver field's type, finds a single-definition class/interface
    owning a method with the callee name, and emits a ``calls`` edge — EXTRACTED
    when the receiver names the type in source (``Type.method()``), INFERRED when
    the type came from the table (the Swift/C#/Java tiering).

    Origin gate (#2553): a name-only match is not evidence the caller can even
    see the matched type. ``import type { Repo } from 'external-pkg'`` plus
    ``this.repo.save()`` must not fabricate an edge to an unrelated local
    ``class Repo`` in another file. The matched type must be origin-verified:
    defined in the caller's own file, a named import of the caller's file, or
    contained in a module the caller's file imports. Otherwise EMIT NOTHING —
    a false call edge is worse than a missing one (the C++ resolver's bar).

    A receiver typed to a class this corpus declares nowhere is parked on the caller
    for a merged graph to finish (#3152); the gate above never sees it, since it only
    vets a name that did match locally.
    """
def _resolve_typescript_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;

"""Attach qualified definitions only to a unique explicitly included owner."""
def _attach_cpp_out_of_line_methods(
    nodes: list[dict],
    edges: list[dict],
    raw_calls: list[dict],
    *,
    context_nodes: list[dict] | None = None,
    context_edges: list[dict] | None = None,
) -> None;

"""Resolve cross-file C++ member calls (``f.bar()``, ``f->bar()``,
    ``Foo::bar()``, ``this->bar()``) to the real definition of the receiver's type
    (#1547).

    The shared cross-file pass drops every ``is_member_call`` because a bare method
    name (``bar``) collides across the corpus and inflates god-nodes (#543/#1219).
    The C++ extractor records lexical receiver bindings, access chains and
    class-scoped field types. Older scoped-call records also use a per-file
    ``var -> ClassName`` table (``cpp_type_table``).
    This pass types the receiver, then emits an edge ONLY when that type resolves
    to exactly ONE definition (the god-node guard).

    Receiver typing, by precision tier:
      * ``Foo::bar()`` — the scope ``Foo`` names the type explicitly -> EXTRACTED.
      * ``this->bar()`` — the receiver is the caller's own enclosing class -> EXTRACTED.
      * ``f.bar()`` / ``f->bar()`` and field chains — declared receiver types -> INFERRED.
    A receiver whose type can't be inferred locally is SKIPPED (no guess): a false
    call edge is worse than a missing one. The ``_merge_decl_def_classes`` pass has
    already folded each header/impl class pair into one node, so a paired class is a
    single definition and clears the single-definition guard.

    Must run after id-disambiguation so node ids and caller_nids are final.
    """
def _resolve_cpp_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;

with entry {
    _CSHARP_BCL_MEMBER_NAMES = frozenset({
        "Add",
        "Any",
        "Cast",
        "Clear",
        "Compare",
        "CompareTo",
        "Concat",
        "Contains",
        "CopyTo",
        "Count",
        "Dispose",
        "Equals",
        "First",
        "ForEach",
        "Format",
        "GetEnumerator",
        "GetHashCode",
        "GetType",
        "GetValue",
        "IndexOf",
        "Insert",
        "Join",
        "Keys",
        "Last",
        "Length",
        "Parse",
        "Remove",
        "Replace",
        "Select",
        "Split",
        "Substring",
        "ToArray",
        "ToDictionary",
        "ToLower",
        "ToList",
        "ToString",
        "ToUpper",
        "Trim",
        "TryParse",
        "Values",
        "Where",
    });

    _CSHARP_WELL_KNOWN_TYPES = frozenset({
        "bool",
        "byte",
        "char",
        "decimal",
        "double",
        "dynamic",
        "float",
        "int",
        "long",
        "nint",
        "nuint",
        "object",
        "sbyte",
        "short",
        "string",
        "uint",
        "ulong",
        "ushort",
        "void",
    });
    _CSHARP_KEYWORD_TYPE_ALIASES = {
        "bool": "Boolean",
        "byte": "Byte",
        "sbyte": "SByte",
        "char": "Char",
        "decimal": "Decimal",
        "double": "Double",
        "float": "Single",
        "int": "Int32",
        "uint": "UInt32",
        "nint": "IntPtr",
        "nuint": "UIntPtr",
        "long": "Int64",
        "ulong": "UInt64",
        "short": "Int16",
        "ushort": "UInt16",
        "object": "Object",
        "string": "String",
    };
    _CSHARP_SYSTEM_TYPE_KEYWORDS = {v: k for (k, v) in _CSHARP_KEYWORD_TYPE_ALIASES.items()};
    _CSHARP_KEYWORD_VALUE_TYPES = frozenset(_CSHARP_KEYWORD_TYPE_ALIASES) - {"object", "string"};
}

"""The C# keyword spelling of a built-in type name, else ``name`` unchanged."""
def _csharp_keyword_type(name: str) -> str;

"""Method nodes by id and their owning type, for C# methods with an arity."""
def _csharp_overload_index(nodes: list[dict], edges: list[dict]) -> dict;

"""Fold the overloads of one C# method among ``candidates`` into one (#4584).

    Overloads of a name on one type are separate nodes, so a bare-name lookup
    sees them as rival definitions and, all in one file, no tie-breaker can
    choose. The call's argument count picks the overload when exactly one fits;
    otherwise the first declared one stands for the name, as it did when the
    overloads were a single node. ``index`` is ``_csharp_overload_index``.
    """
def _csharp_collapse_overloads(candidates: list[str], argc: object, index: dict) -> list[str];

"""Resolve C# member calls (``recv.Method()``) to the receiver's declared type
    (#1609), namespace-aware (#1620).

    The shared cross-file pass drops every ``is_member_call`` because a bare method
    name collides across the corpus — and for C# an in-file bare match silently
    mis-bound ``_server.Save()`` to an unrelated ``Cache.Save()``. The C# extractor
    records each member call's receiver and stamps ``receiver_type`` on the raw
    call from a METHOD-scoped ``name -> Type`` table of class fields/properties
    plus the declaring method's params/locals (#2299 — per-method like Java, so a
    name rebound in a different method never poisons this one; same-method
    conflicts and untypable rebindings are still POISONED, so a shadowing local of
    a different type produces no edge rather than a wrong one). This pass resolves
    the stamped type name with the same namespace/using/alias scoping machinery the
    type-reference pass uses (``CsharpNameResolver``), so a class name duplicated
    across namespaces still binds to the one in scope; only when scoping knows
    nothing about the name does it fall back to the corpus-wide unique bare-name
    match (the god-node guard). An untypable/ambiguous receiver is skipped — never
    a guess.

    Receiver typing, by precision tier:
      * ``this.M()`` — receiver is the caller's own enclosing class -> EXTRACTED.
      * ``base.M()`` — the caller's single resolvable base class -> EXTRACTED.
      * ``Type.M()`` (capitalized) — the type is named explicitly in source -> EXTRACTED.
      * ``recv.M()`` / ``this.recv.M()`` — ``recv`` typed via the extractor's
        method-scoped field/property/param/local table (``receiver_type`` on the
        raw call) -> INFERRED.

    A method not declared on the receiver's type is looked up through its
    ``inherits`` chain; a chain containing an unresolvable (out-of-corpus) base
    poisons the lookup — the method may live there, so no edge is emitted.

    Must run after id-disambiguation so node ids and caller_nids are final.
    """
def _resolve_csharp_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;

"""Bind C# extension-method calls (``recv.Ext()``) to their declaration (#4828).

    An extension invocation is static dispatch: the receiver is the first
    argument of a method declared on a *static class*, not a member of the
    receiver's type. ``_resolve_csharp_member_calls`` therefore cannot see it —
    it looks the name up on the receiver's type and its base chain, and an
    extension lives on a sibling type — so a widely used helper had no callers
    in the graph and looked dead.

    The declaration side now records ``extended_type`` (plus arity and a
    type-parameter marker) on the extension node; this pass joins call sites to
    it. Every rule is a C# resolution rule, and anything unprovable is dropped:

      * the receiver's declared type must be in the corpus and its base chain
        fully resolved — an out-of-corpus base may declare an *instance* member
        of that name, which always wins over an extension;
      * the receiver type must declare no instance member of that name;
      * the declaring static class's namespace must be visible at the call site,
        walking the enclosing namespace declarations outward (a file-level
        ``using`` belongs to the compilation unit, so an inner-namespace
        extension wins);
      * the extended type must be the receiver's type or one of its resolved
        base types or interfaces;
      * the declaration must accept the call's argument count, using the same
        ``arity``/``min_arity`` facts #4584 already records (the receiver is one
        parameter short of the call);
      * more than one surviving declaration is ambiguous and binds nothing.

    An open generic (``this T``) or ``this object`` declaration applies to any
    receiver, but only when no exact/base match exists — C# prefers the
    non-generic candidate.

    A receiver whose type the corpus never declares (``string``, ``int``, a
    third-party type) cannot have its instance members enumerated, so the
    instance-wins rule is replaced by two conservative proofs: the member name
    is not one a BCL type owns (``ToString``, ``GetValue``, …), and no regular
    method anywhere in the corpus has that name. Such an edge is INFERRED 0.75,
    one tier below a receiver whose declaration table typed it.

    A chained receiver (``v.ToString().Mask()``) has no type at all: typing it
    needs the inner call's return type, which for a BCL call the corpus does not
    know. The same two proofs apply, with no type-compatibility filter — only a
    name that is unique enough to survive them binds (``v.ToString().Mask()``
    does; anything named like an ordinary member does not). A capitalized
    untyped receiver is a type name (``Convert.ToInt32(x)``), never a value an
    extension can apply to, so it is skipped.

    A keyword type and its System type are one type (``bool`` receiver,
    ``this Boolean``), unless the corpus declares a type of that name. And
    ``x.Value`` on a keyword value type can only be ``Nullable<T>.Value``
    (``char? c; c.Value.IsWs()``), so its type is T.
    """
def _resolve_csharp_extension_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;

"""Bind the exported per-file field tables (#3151) to class node ids.

    Entries are keyed by class label + source_file so they survive every id
    remap; here they are matched back to the one class node carrying that
    label (disambiguated by source_file basename when several share it).
    An entry that stays ambiguous binds nothing - guessing would attach a
    field table to the wrong class.
    """
def _bind_member_field_tables(
    per_file: list[dict], all_nodes: list[dict], *, lang: str
) -> dict[str, dict[str, str]];

"""Resolve PHP ``ClassName::method()`` / ``self::``/``static::``/``parent::``
    static calls against the receiver's class (#3872).

    The shared engine's PHP branch used to treat ``scoped_call_expression`` as a
    bare function call named after the *scope* (``Helper::format()`` bound the
    callee name to ``"Helper"``), so the cross-file bare-name pass silently
    resolved every static call to whichever node happened to share the class's
    label — almost always the class definition itself — instead of the actual
    method, and did so with the generic import-evidence confidence gate even
    though the receiver class is named explicitly in source. The engine now
    captures the real method name as the callee and the scope text as the
    receiver and marks it a member call; this resolver binds it to the class's
    actual method node, mirroring ``_resolve_java_member_calls``.

    ``self::``/``static::`` and ``$this->`` resolve to the enclosing class (exact
    — the keyword names it as unambiguously as a literal class name would).
    ``parent::`` resolves through a single `inherits` edge from the enclosing
    class. Whatever the scope, the method is looked up the `inherits` chain
    level by level: the nearest class that provides it wins (its own method,
    else one from a trait it uses), and a tie on that level binds nothing. Each call site gets its own edge, so a repeat call
    keeps its line (the build folds it into `also_seen`). A
    ``$var::method()`` dynamic scope is left unresolved — PHP has no
    declared-type table for it to resolve against, and guessing would risk the
    same over-connection the #543/#1219 guard exists to prevent. Every other
    scope is treated as a class reference regardless of case (PHP class and
    method names are case-insensitive) or namespace qualification (a
    fully-qualified ``\\App\\Models\\User::method()`` or ``App\\Models\\User::``
    matches the class's own unqualified label by its last segment).
    """
def _resolve_php_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;

"""Resolve Java member calls against the receiver's declared type.

    Explicit type receivers, ``this`` and ``super`` are exact. Fields declared on the
    caller's class plus method parameters and explicit locals are inferred from
    the extractor's method-scoped type table. A missing or ambiguous receiver
    type is skipped rather than falling back to a bare method-name match.

    A bare `m()` or `field.m()` the caller's file could not bind names a member
    the class inherits from a supertype in another file: the nearest supertype
    declaring it is the target, and a tie on one level binds nothing.

    A receiver that is itself a call (`builder().size(3).build()`), a `new T()`
    or a cast is typed step by step from the declared return types the
    extractor put on method nodes (`_java_ret`). A class-qualified static
    field (`Service.INSTANCE.get()`, and `Service.INSTANCE.other().m()`) is
    the same walk: the field's declared type on that class, including one
    inherited from a superclass, types the next step. A local, parameter, or
    field that shadows the class name is not that class. An instance field
    accessed as `Type.field` is not.
    """
def _resolve_java_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;

"""Resolve cross-file Objective-C message sends (``[recv sel]``) to the real
    definition of the receiver's type (#1556).

    The ObjC extractor keeps its same-file selector matching (alloc/init refs,
    dot-syntax accesses, @selector) and additionally emits ``raw_calls`` for every
    message send, with the receiver and the reconstructed selector as the callee.
    This pass types the receiver and emits a cross-file ``calls`` edge ONLY when the
    type resolves to exactly ONE definition (the god-node guard).

    Receiver typing:
      * ``self`` / ``super`` — the caller's own enclosing class -> EXTRACTED.
      * Capitalized receiver (``[Foo new]``) — the type named explicitly -> EXTRACTED.
      * ``[f doThing]`` — ``f`` typed via the file's ``Foo *f`` local table -> INFERRED.
      * ``[self.bar doIt]`` / ``[_ivarBar doIt]`` — the field typed via the class's
        ``@property``/ivar table (locals shadow fields for the bare-identifier
        form) -> INFERRED. Only the exact ``self.<field>`` receiver shape is
        captured; a dotted receiver like ``Foo.shared`` is never passed through,
        because ``_key`` would strip the dot and collide with a real ``FooShared``.
    An uninferable receiver is SKIPPED (no guess), so an ambiguous selector across
    classes never fans out. A receiver typed to a class this corpus declares nowhere
    is parked on the caller for a merged graph to finish (#3152).
    ``_merge_decl_def_classes`` folds each @interface/@impl
    pair into one node, so a paired class clears the single-definition guard.
    ``@protocol`` declarations are excluded from the receiver-type index: a protocol
    is a contract, not a message receiver, and ObjC keeps protocol and class names in
    separate namespaces, so a same-named pair used to both mis-bind a message to the
    protocol's declaration and, when a real class existed, trip the god-node guard.

    Must run after id-disambiguation so node ids and caller_nids are final.
    """
def _resolve_objc_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;

"""Group per-file results by the Kotlin package they declare.

    ``kotlin_package`` is stamped by the generic engine from the file's
    ``package_header`` (see extractors/engine.py); every node in the file
    inherits it. Files with no package header contribute nothing.
    """
def _kotlin_package_index(per_file: list[dict]) -> dict[str, list[dict]];

with entry {
    _JVM_NAME_SUFFIXES = frozenset({".java", ".kt", ".kts"});
    _JAVA_IMPORT_RE = re.compile("(?m)^\\s*import\\s+(?:static\\s+)?([\\w.]+)\\s*;");
}

"""Return ``(source_file, package)`` for a JVM file, or None.

    Kotlin already stamps ``kotlin_package`` on the per-file result. Java has
    no equivalent field, so read the one package declaration directly. The
    declaration is a single line and does not need a second tree-sitter parse.
    """
def _jvm_package_name(path: Path, result: dict) -> tuple[str, str] | None;

"""simple name -> written FQN, for imports in one Java/Kotlin file."""
def _jvm_imports_by_file(path: Path, result: dict) -> dict[str, str];

"""Resolve Java/Kotlin type references through one JVM-wide symbol index.

    Java and Kotlin share package names and class names. The language-specific
    resolvers each build an index from one extension, so a Kotlin import of a
    Java class never sees the Java class, and a Java import of a Kotlin class
    is parked as external. Build the package/name index once over both
    languages and repoint only when the written FQN names exactly one sourced
    type node.

    This runs before the shared call-evidence pass: a Kotlin member call can
    only bind to a Java method after the import edge reaches the Java class.
    """
def _resolve_jvm_references(
    per_file: list[dict], paths: list[Path], all_nodes: list[dict], all_edges: list[dict]
) -> None;

"""Rewrite Kotlin ``imports`` edge targets from the bare last segment to the
    node the written FQN actually names (#2526).

    ``_import_kotlin`` emits ``file --imports--> _make_id(last_segment)`` with
    the full dotted path stamped as ``metadata.target_fqn``. That target dangles
    (node ids carry a file-stem prefix), so build pruned every Kotlin import and
    the import-evidence promotion in the shared call pass never fired. Here the
    per-file ``kotlin_package`` declarations index each package's importable
    (non-member) symbols by exact label; an edge whose ``target_fqn`` splits
    into a known package P plus a Name defined exactly ONCE in P is rewritten to
    that node id. The FQN is written verbatim in source, so the match is exact —
    confidence stays EXTRACTED. Anything else (external dependency, ambiguous
    name) is left untouched and dangles like other languages' external imports.

    Must run BEFORE the shared call pass builds its import-evidence index (it is
    invoked directly in extract(), not via the tail registry run).
    """
def _resolve_kotlin_import_targets(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;

with entry {
    _C_FAMILY_HEADER_EXTS = frozenset({".h", ".hpp", ".hh", ".hxx", ".cuh", ".inl"});
}

"""Resolve unresolved C/C++/ObjC include edges to matching header file nodes (#4354, #5218).

    When a quoted #include / #import is outside the including file's directory,
    _resolve_c_include_path cannot resolve it, so per-file extraction emits a
    fallback edge targeting a bare stem ID with metadata={"raw_include": ..., "include_kind": "quoted"}.
    This pass runs after canonical node IDs and collision disambiguation are
    established, but before import-evidence indexing.

    Resolution rules:
    1. Only processes unresolved quoted or angle includes (metadata.include_kind
       is "quoted" or "angle" and metadata.raw_include is present). An angle
       include is considered only when it has a directory component
       (`<liba/Bus.h>`); a bare `<name>` is left alone (#5218).
    2. Explicit relative (./ or ../) or absolute paths that failed sibling
       resolution are never resolved via corpus fallback.
    3. Matches the full include path as a path suffix, not merely the basename
       when the include contains directory components.
    4. Prefers exact-case matches over case-insensitive matches.
    5. If no exact-case candidate exists, falls back to case-insensitive matching.
    6. If multiple candidates remain, uses longest-shared-directory-prefix as a
       tie-breaker. Resolves only when one candidate has a strictly greater score
       than all others; ties remain unresolved. This is a heuristic and does not
       claim to reproduce compiler include-order semantics.
    7. Resolved edges point to the canonical target file node ID.
    8. Unresolved edges remain untouched for external stub creation.
    """
def _resolve_c_include_edges(
    edges: list[dict], resolution_nodes: list[dict], `root: Path | None = None
) -> None;

"""Link a C# construction to the constructor overload it runs.

    `new X(a, b)` already has a `calls` edge to the type X (in-file or from
    the shared/qualified passes). This adds one to the X constructor whose
    parameter count fits two arguments, and links a constructor's
    `: this(...)` to its own type's overload and `: base(...)` to its base
    type's. Additive: the edge to the type stays.

    Fail closed, never a guess across types or overloads:
      * the type is the one the caller's own `calls` edges already bound for
        that name; none, or two types with the name, gives no edge;
      * `: base(...)` needs exactly one resolvable `inherits` target, and no
        unresolved (out-of-corpus) base;
      * exactly one non-static constructor (explicit or primary) must accept
        the argument count (``_csharp_pick_overload``); a type with no
        declared constructor gets no edge.
    """
def _resolve_csharp_constructor_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;

"""Resolve C# constructions that name their namespace (#2997).

    `new Infra.Data.Cache()` reaches the shared pass as the bare name `Cache`,
    so a second `Cache` in another namespace makes it ambiguous and it gets no
    edge, even though the source says which one it means. The reference paths
    (field, property, parameter, return) already honour the qualifier through
    `CsharpNameResolver`; this is the construction twin, built the way
    `_resolve_kotlin_qualified_calls` handles the same shape in Kotlin.

    The prefix must equal a declared namespace exactly. A partially qualified
    `new Data.Cache()` under `using Infra;` stays unresolved rather than
    guessing at the using directives in scope. Exactly one candidate produces an
    edge; zero or several leave the call alone. The pass is additive: an
    ambiguous bare name never had an edge to overwrite.
    """
def _resolve_csharp_qualified_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;

"""Resolve Kotlin fully-qualified call expressions (#2550).

    ``com.example.nav.NavGraph()`` parses to a nested navigation_expression
    chain; the engine flattens it and stamps the raw_call with
    ``qualified_prefix="com.example.nav"`` + ``lang="kotlin"`` when EVERY chain
    segment is a plain identifier. The shared pass skips member calls, so these
    raw_calls produced no edge at all — this pass is strictly additive.

    Resolution, guarded by exactly-one-candidate at every step:
      * prefix == a declared package FQN P -> candidates are P's top-level
        callables (functions/classes the file node `contains`) named callee;
      * prefix == P + "." + TypeName where TypeName is a class/object declared
        in P -> candidates are that type's methods (`method` edges, `.callee()`
        label).
    Zero or 2+ candidates -> no edge. The FQN is written verbatim in source, so
    a unique match is EXTRACTED.
    """
def _resolve_kotlin_qualified_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;

"""Resolve cross-file Rust `self.method()` calls (#2234).

    The shared cross-file pass drops every is_member_call — a bare method name
    (``log``) has no import evidence and collides with any top-level function
    named ``log`` in the corpus (#543/#1219). Rust is the only member-call-heavy
    language with no recovery pass behind that guard: `self.apply_block()`
    inside `impl Foo { .. }` types the receiver as `Foo` syntactically, no
    inference needed, but nothing used that signal. rust.py now records that
    type on each self-call raw_call as `rust_self_type`; this pass matches it.

    Unlike the Kotlin/Swift equivalents, this does NOT require the type name to
    resolve to exactly one node: Rust routinely splits `impl Foo { .. }` across
    as many files as it likes (one struct can have a dozen impl blocks scattered
    through a crate), and rust.py mints a SEPARATE graph node per (file, type
    name) pair rather than merging them, so requiring a single node would
    refuse the exact split-impl-block shape this issue is about. Instead,
    every node carrying the type's bare label pools its methods together, and
    a call resolves only when exactly one method across the WHOLE pool matches
    the callee name — two impl blocks (however many files apart) defining the
    same method name still bail, a real ambiguity rather than a false one.

    Pooling across every same-labeled node is only safe when they are all
    impl blocks for ONE real type; it must not also fire when the bare name is
    shared by two UNRELATED types, which would link a call to a method that
    only exists on the wrong one (concretely: one type overrides a trait
    method the other relies on the default for, so only the override gets an
    explicit method node). A struct/enum/trait DECLARATION gets a `contains`
    edge from its file; an impl block never does. So the type name itself is
    treated as ambiguous, and pooling skipped entirely, whenever 2+ nodes
    sharing the bare label are real declarations rather than impl blocks.

    Only `self.` receivers are handled: a non-self receiver needs local type
    inference this pass does not attempt, left for a future extension.

    Simple unbounded generic impls use a persisted owner/arity marker instead
    of their parameter-spelling-sensitive labels (`Bucket<T>` vs `Bucket<U>`).
    That path additionally requires exactly one bare declaration and never
    falls back to bare-label pooling when marker context is missing.
    """
def _resolve_rust_self_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;

"""Resolve Go member calls (``g.Greet()``) through the receiver's declared type.

    Local bindings carry their receiver type; only unbound names may fall back to
    package variables. Fields resolve through their owning struct. Always INFERRED:
    the method target comes from the receiver's declared type.

    Names are matched case-sensitively, unlike the sibling resolvers. Go exports by
    capitalisation, so `Run` and `run` on one type are two different methods with two
    different visibilities, and folding them would pick whichever came last.

    A receiver typed to a type this corpus declares nowhere is parked on the caller for
    a merged graph to finish (#3152).

    A package-qualified type (`plugins.Client`, `*svc.Greeter`), the usual shape of a
    dependency injected from another package, resolves through the caller's import of
    that package: only a declaration whose file sits at the imported path qualifies.
    """
def _resolve_go_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;

"""Resolve Elixir cross-file alias/import/require/use edges (#2556).

    extract_elixir mints a module's own node id with the defining file's stem
    (``_make_id(stem, module_name)``) but an alias/import/require/use target
    with just the bare module name (``_make_id(module_name)``) — the two can
    only ever match when a module refers to itself, so almost every
    cross-file reference was silently dropped as dangling at build time
    (13% of edges on a real 900-file project).

    Exact match only, per the issue's own finding: id-suffix matching
    (``application`` latching onto ``..._oauthapplications_update_application``)
    produced wrong resolutions in testing on a real corpus; matching a
    module's own id (already exact, since both sides run through the same
    ``_make_id``) needs no heuristics. A name matching zero modules is left
    exactly as extracted — the generic external-reference handling already
    turns an unresolved bare id into a leaf stub, the correct outcome for a
    genuinely external (stdlib/hex) name. A name matching 2+ modules (e.g.
    two files each defining the same module name, most likely a genuine
    corpus oddity) also leaves the edge alone rather than guessing.
    """
def _resolve_elixir_import_targets(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;

"""Resolve Elixir remote calls that name their module (#4206).

    extract_elixir expands the receiver of `App.Accounts.get_user(id)` /
    `Accounts.get_user(id)` (through the caller's `alias` table and
    `__MODULE__`) and stamps it on the raw_call as ``elixir_module``; calls
    into a module of the same file are linked there already. The shared pass
    skips member calls, so this pass is strictly additive, like
    `_resolve_csharp_qualified_calls`.

    The module must match exactly one top-level module in the corpus and the
    function must be one of its own defs. A module outside the corpus (Ecto's
    `Repo`, `Enum`, `Map`) gets no edge rather than a same-named guess.
    """
def _resolve_elixir_qualified_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;

"""Per-corpus tables for deciding which classes a bare Kotlin/Java call can reach.

    Returns ``(owner_of, bases_of, enclosing_of, sourceless)``: method id ->
    declaring class, class -> its ``inherits`` targets, nested class -> its
    enclosing class, and the ids of nodes with no ``source_file`` (the stubs
    left for classes declared outside the corpus).
    """
def _jvm_scope_index(
    all_nodes: list[dict], all_edges: list[dict]
) -> tuple[dict[str, str], dict[str, list[str]], dict[str, str], set[str]];

"""Drop bare-call candidates the caller's class cannot reach (#4935).

    A bare ``getString(1)`` can name a member of the caller's own class, of a
    superclass, or of an enclosing class. When a class in that chain extends a
    class outside the corpus, an unresolved base may declare the member, and
    the corpus-wide name match then binds the call to a same-named method of an
    unrelated class (``Activity.getString`` became ``Prefs.getString``). In that
    case keep only candidates that are not class members, that belong to the
    chain, or that the file imports by name (``import pkg.Obj.member``,
    ``import static``). A caller whose chain is fully in the corpus is left
    alone, so a receiver lambda such as ``with(p) { getString() }`` keeps the
    edge it has today.
    """
def _jvm_reachable_candidates(
    candidates: list[str],
    caller: str,
    callee: str,
    index: tuple[dict[str, str], dict[str, list[str]], dict[str, str], set[str]],
    imported_symbols: set[str],
) -> list[str];

"""Resolve Kotlin object/class-qualified member calls across files (#1698).

    ``Receiver.method()`` (exactly two navigation segments, a capitalized
    receiver — an object singleton or a class/companion member) resolves
    in-file through the engine's own bare-name lookup, so a call reaches
    ``raw_calls`` here only when that lookup already failed: the receiver and
    the callee are declared in different files. The shared cross-file pass
    skips every ``is_member_call`` unconditionally (a bare method name like
    ``log`` collides across the corpus and inflates god-nodes, #543/#1219),
    and Kotlin deliberately never stamps ``member_receiver`` for this shape
    either (see ``extractors/engine.py``), so nothing else can ever answer it.

    Guarded by exactly-one-candidate at both steps, the same god-node guard
    ``_resolve_kotlin_qualified_calls`` uses just above: a receiver name
    matching 2+ declared types, or a method name matching 2+ methods of the
    matched type, yields no edge. The receiver names the type explicitly in
    source, so a unique match is EXTRACTED (mirrors the type-qualified case
    in ``_resolve_swift_member_calls``, #1356).
    """
def _resolve_kotlin_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;

with entry {
    _KOTLIN_IMPORT_TARGET_RESOLVER = LanguageResolver(
        "kotlin_import_targets", frozenset({".kt", ".kts"}), _resolve_kotlin_import_targets
    );
    register_language_resolver(
        LanguageResolver("terraform_modules", frozenset({".tf"}), resolve_terraform_modules)
    );
    register_language_resolver(
        LanguageResolver("swift_member_calls", frozenset({".swift"}), _resolve_swift_member_calls)
    );
    register_language_resolver(
        LanguageResolver("python_member_calls", frozenset({".py"}), _resolve_python_member_calls)
    );
    register_language_resolver(
        LanguageResolver(
            "ruby_member_calls", frozenset({".rb", ".rake"}), resolve_ruby_member_calls
        ),
    );
    register_language_resolver(
        LanguageResolver(
            "typescript_member_calls", frozenset(_JS_TS_SUFFIXES), _resolve_typescript_member_calls
        ),
    );
    register_language_resolver(
        LanguageResolver(
            "cpp_member_calls",
            frozenset({".cpp", ".cc", ".cxx", ".hpp", ".cu", ".cuh", ".metal", ".h"}),
            _resolve_cpp_member_calls,
        ),
    );
    register_language_resolver(
        LanguageResolver(
            "objc_member_calls", frozenset({".m", ".mm", ".h"}), _resolve_objc_member_calls
        ),
    );
    register_language_resolver(
        LanguageResolver("csharp_member_calls", frozenset({".cs"}), _resolve_csharp_member_calls)
    );
    register_language_resolver(
        LanguageResolver(
            "csharp_extension_calls", frozenset({".cs"}), _resolve_csharp_extension_calls
        ),
    );
    register_language_resolver(
        LanguageResolver("java_member_calls", frozenset({".java"}), _resolve_java_member_calls)
    );
    register_language_resolver(
        LanguageResolver("php_member_calls", frozenset({".php"}), _resolve_php_member_calls)
    );
    register_language_resolver(
        LanguageResolver(
            "rust_self_member_calls", frozenset({".rs"}), _resolve_rust_self_member_calls
        ),
    );
    register_language_resolver(
        LanguageResolver("vbnet_partial_calls", frozenset({".vb"}), resolve_vbnet_partial_calls)
    );
    register_language_resolver(
        LanguageResolver("r_sourced_calls", frozenset({".r", ".R"}), resolve_r_sourced_calls)
    );
    register_language_resolver(
        LanguageResolver(
            "solidity_type_references", frozenset({".sol"}), resolve_solidity_type_references
        ),
    );
    register_language_resolver(
        LanguageResolver(
            "solidity_inherited_calls", frozenset({".sol"}), resolve_solidity_inherited_calls
        ),
    );
    register_language_resolver(
        LanguageResolver(
            "erlang_remote_calls",
            frozenset({".erl", ".hrl", ".escript"}),
            resolve_erlang_remote_calls,
        ),
    );
    register_language_resolver(
        LanguageResolver(
            "elixir_import_targets", frozenset({".ex", ".exs"}), _resolve_elixir_import_targets
        ),
    );
    register_language_resolver(
        LanguageResolver(
            "elixir_qualified_calls", frozenset({".ex", ".exs"}), _resolve_elixir_qualified_calls
        ),
    );
    register_language_resolver(
        LanguageResolver(
            "pascal_base_classes",
            frozenset({".pas", ".pp", ".dpr", ".dpk", ".inc"}),
            resolve_pascal_base_classes,
        ),
    );
    register_language_resolver(
        LanguageResolver(
            "pascal_inherited_calls",
            frozenset({".pas", ".pp", ".dpr", ".dpk", ".inc"}),
            resolve_pascal_inherited_calls,
        ),
    );
    register_language_resolver(
        LanguageResolver(
            "pascal_singleton_calls",
            frozenset({".pas", ".pp", ".dpr", ".dpk", ".inc"}),
            resolve_pascal_singleton_calls,
        ),
    );
    register_language_resolver(
        LanguageResolver("dfm_form_handlers", frozenset({".dfm", ".lfm"}), resolve_dfm_handlers)
    );
    register_language_resolver(
        LanguageResolver(
            "kotlin_qualified_calls", frozenset({".kt", ".kts"}), _resolve_kotlin_qualified_calls
        ),
    );
    register_language_resolver(
        LanguageResolver(
            "kotlin_member_calls", frozenset({".kt", ".kts"}), _resolve_kotlin_member_calls
        ),
    );
    register_language_resolver(
        LanguageResolver("go_member_calls", frozenset({".go"}), _resolve_go_member_calls)
    );
    register_language_resolver(
        LanguageResolver(
            "csharp_qualified_calls", frozenset({".cs"}), _resolve_csharp_qualified_calls
        ),
    );
    register_language_resolver(
        LanguageResolver(
            "csharp_constructor_calls", frozenset({".cs"}), _resolve_csharp_constructor_calls
        ),
    );
    register_language_resolver(
        LanguageResolver(
            "csharp_interface_dispatch", frozenset({".cs"}), resolve_csharp_interface_dispatch
        ),
    );
    register_language_resolver(
        LanguageResolver(
            "swift_protocol_dispatch", frozenset({".swift"}), resolve_swift_protocol_dispatch
        ),
    );
    register_language_resolver(
        LanguageResolver("go_interface_dispatch", frozenset({".go"}), resolve_go_interface_dispatch)
    );
    register_language_resolver(
        LanguageResolver(
            "kotlin_interface_dispatch",
            frozenset({".kt", ".kts"}),
            resolve_kotlin_interface_dispatch,
        ),
    );
    register_language_resolver(
        LanguageResolver("markdown_mentions", MARKDOWN_MENTION_SUFFIXES, resolve_markdown_mentions)
    );
    _PROJECT_XML_MAX_BYTES = 2 * 1024 * 1024;
}

"""Reject XML that declares DTDs or entities.

    Stdlib ``xml.etree.ElementTree`` does not cap entity expansion, so a
    crafted project file could trigger a billion-laughs style DoS. External
    entity resolution is already disabled by pyexpat defaults, but rejecting
    ``<!DOCTYPE`` / ``<!ENTITY`` outright is defense in depth.

    Legitimate MSBuild and Lazarus package files never contain a DOCTYPE
    or ENTITY declaration, so this is a zero-false-positive screen.
    """
def _project_xml_is_safe(src: bytes) -> bool;

"""Extract package metadata from Lazarus .lpk package files (XML format).

    .lpk is an XML file listing the package name, required dependencies,
    and the Pascal units that belong to the package.

    Produces nodes for:
    - The package file itself
    - The package (by name)
    - Each required package (dependency)
    - Each listed unit file (resolved to path-based IDs where possible)

    Produces edges for:
    - file --contains--> package
    - package --imports--> required dependency (context: "import")
    - package --contains--> listed unit
    """
def extract_lazarus_package(path: Path) -> dict;

"""Raise a clear error if tree-sitter is too old for the new Language API."""
def _check_tree_sitter_version -> None;

"""Extract projects and inter-project dependencies from a .slnx file.

    .slnx is the XML-based replacement for the legacy .sln format. Projects
    are listed as ``<Project Path="..."/>`` elements (optionally nested inside
    ``<Folder>`` elements) and build-order dependencies as ``<BuildDependency
    Project="..."/>`` children. Unlike .sln there are no GUIDs -- projects are
    identified by their path.
    """
def extract_slnx(path: Path) -> dict;

"""Extract packages, project refs, and target framework from a .csproj/.fsproj/.vbproj."""
def extract_csproj(path: Path) -> dict;

def _xml_local_name(name: str) -> str;

with entry {
    _EVENT_HANDLER_SIGNATURE_RE = re.compile(
        "\\(\\s*object\\??\\s+\\w+\\s*,\\s*[\\w.]*EventArgs(?:<[^>]*>)?\\s+\\w+\\s*\\)"
    );
    _XAML_NON_EVENT_ATTRS = frozenset({
        "Name",
        "Content",
        "Text",
        "Title",
        "Tag",
        "ToolTip",
        "Header",
        "Class",
        "Key",
        "Uid",
        "DataContext",
        "Style",
        "Source",
    });
    _XAML_IDENT_RE = re.compile("[A-Za-z_]\\w*");
    _XAML_DESIGN_INSTANCE_TYPE_RE = re.compile(
        "\\bType\\s*=\\s*(?:\\{x:Type\\s+)?(?P<type>[\\w.:+]+)"
    );
}

def _xaml_markup_extension(value: str) -> tuple[str, str] | None;

def _xaml_split_markup_args(args: str) -> list[str];

def _xaml_static_resource_key(value: str) -> str | None;

def _xaml_binding_refs(value: str) -> tuple[str | None, str | None];

def _xaml_codebehind_path(path: Path) -> Path | None;

def _xaml_codebehind_symbols(path: Path, class_name: str | None) -> tuple[dict
    | None, dict[str, dict], list[dict]];

def _xaml_type_simple_name(type_ref: str) -> str | None;

def _xaml_explicit_viewmodel_names(tree) -> tuple[bool, list[str]];

def _xaml_prism_autowire_viewmodel(tree) -> bool;

def _xaml_inferred_viewmodel_names(view_name: str | None) -> list[str];

def _xaml_project_root(path: Path) -> Path;

def _xaml_csharp_class_nodes(path: Path) -> dict[str, list[dict]];

def _xaml_pascal_name(name: str) -> str | None;

with entry {
    _XAML_TOOLKIT_FIELD_RE = re.compile("\\b(?P<name>_?m?_?[A-Za-z_]\\w*)\\s*(?:=.*)?;");
    _XAML_TOOLKIT_METHOD_RE = re.compile("\\b(?P<name>[A-Za-z_]\\w*)\\s*\\(");
    _XAML_CSHARP_CLASS_CACHE = {};
}

def _xaml_communitytoolkit_members(vm_node: dict) -> tuple[dict[str, dict], list[dict]];

"""Extract WPF/XAML structure, bindings, x:Class, and event handler references."""
def extract_xaml(path: Path) -> dict;

with entry {
    _DISPATCH = {
        ".py": extract_python,
        ".js": extract_js,
        ".jsx": extract_js,
        ".mjs": extract_js,
        ".cjs": extract_js,
        ".ts": extract_js,
        ".tsx": extract_js,
        ".mts": extract_js,
        ".cts": extract_js,
        ".go": extract_go,
        ".rs": extract_rust,
        ".r": extract_r,
        ".sol": extract_solidity,
        ".java": extract_java,
        ".groovy": extract_groovy,
        ".gradle": extract_groovy,
        ".c": extract_c,
        ".h": extract_c,
        ".cpp": extract_cpp,
        ".cc": extract_cpp,
        ".cxx": extract_cpp,
        ".hpp": extract_cpp,
        ".cu": extract_cpp,
        ".cuh": extract_cpp,
        ".metal": extract_cpp,
        ".rb": extract_ruby,
        ".rake": extract_ruby,
        ".cs": extract_csharp,
        ".cbl": extract_cobol,
        ".cob": extract_cobol,
        ".cobol": extract_cobol,
        ".cpy": extract_cobol,
        ".vb": extract_vbnet,
        ".kt": extract_kotlin,
        ".kts": extract_kotlin,
        ".scala": extract_scala,
        ".php": extract_php,
        ".swift": extract_swift,
        ".lua": extract_lua,
        ".luau": extract_lua,
        ".toc": extract_lua,
        ".zig": extract_zig,
        ".ps1": extract_powershell,
        ".psm1": extract_powershell,
        ".psd1": extract_powershell_manifest,
        ".ex": extract_elixir,
        ".exs": extract_elixir,
        ".erl": extract_erlang,
        ".hrl": extract_erlang,
        ".escript": extract_erlang,
        ".m": extract_objc,
        ".mm": extract_objc,
        ".jl": extract_julia,
        ".f": extract_fortran,
        ".F": extract_fortran,
        ".f90": extract_fortran,
        ".F90": extract_fortran,
        ".f95": extract_fortran,
        ".F95": extract_fortran,
        ".f03": extract_fortran,
        ".F03": extract_fortran,
        ".f08": extract_fortran,
        ".F08": extract_fortran,
        ".vue": extract_vue,
        ".svelte": extract_svelte,
        ".astro": extract_astro,
        ".ejs": extract_ejs,
        ".dart": extract_dart,
        ".ml": extract_ocaml,
        ".mli": extract_ocaml,
        ".lisp": extract_commonlisp,
        ".cl": extract_commonlisp,
        ".lsp": extract_commonlisp,
        ".asd": extract_commonlisp,
        ".v": extract_verilog,
        ".sv": extract_verilog,
        ".svh": extract_verilog,
        ".vh": extract_verilog,
        ".sql": extract_sql,
        ".md": extract_markdown,
        ".mdx": extract_markdown,
        ".qmd": extract_markdown,
        ".skill": extract_markdown,
        ".pas": extract_pascal,
        ".pp": extract_pascal,
        ".dpr": extract_pascal,
        ".dpk": extract_pascal,
        ".lpr": extract_pascal,
        ".inc": extract_pascal,
        ".dfm": extract_delphi_form,
        ".lfm": extract_lazarus_form,
        ".lpk": extract_lazarus_package,
        ".sh": extract_bash,
        ".bash": extract_bash,
        ".json": extract_json,
        ".yaml": extract_yaml,
        ".yml": extract_yaml,
        ".tf": extract_terraform,
        ".tfvars": extract_terraform,
        ".hcl": extract_terraform,
        ".dm": extract_dm,
        ".dme": extract_dm,
        ".dmi": extract_dmi,
        ".dmm": extract_dmm,
        ".dmf": extract_dmf,
        ".sln": extract_sln,
        ".slnx": extract_slnx,
        ".csproj": extract_csproj,
        ".fsproj": extract_csproj,
        ".vbproj": extract_csproj,
        ".xaml": extract_xaml,
        ".razor": extract_razor,
        ".cshtml": extract_razor,
        ".robot": extract_robot,
        ".resource": extract_robot,
        ".cls": extract_apex,
        ".trigger": extract_apex,
    };
    _EXTRA_FOR_EXTENSION = {
        ".vb": "vbnet",
        ".r": "r",
        ".sol": "solidity",
        ".erl": "erlang",
        ".hrl": "erlang",
        ".escript": "erlang",
        ".sql": "sql",
        ".tf": "terraform",
        ".tfvars": "terraform",
        ".hcl": "terraform",
        ".dm": "dm",
        ".dme": "dm",
        ".ml": "ocaml",
        ".mli": "ocaml",
        ".lisp": "commonlisp",
        ".cl": "commonlisp",
        ".lsp": "commonlisp",
        ".asd": "commonlisp",
        ".robot": "robot",
        ".resource": "robot",
    };
    _DEP_MISSING_MARKER = "not installed";
    _DEP_LOAD_FAILED_MARKER = "failed to load";
    _SHEBANG_DISPATCH = {
        "python": extract_python,
        "python2": extract_python,
        "python3": extract_python,
        "bash": extract_bash,
        "sh": extract_bash,
        "dash": extract_bash,
        "zsh": extract_bash,
        "ksh": extract_bash,
        "node": extract_js,
        "nodejs": extract_js,
        "ruby": extract_ruby,
        "lua": extract_lua,
        "php": extract_php,
        "julia": extract_julia,
        "Rscript": extract_r,
    };
    _SNIFF_BYTES = 256 * 1024;

    _OBJC_HEADER_MARKERS = (
        b"@interface",
        b"@protocol",
        b"@implementation",
        b"@import",
        b"#import",
    );
}

"""First _SNIFF_BYTES of ``path``, or ``head`` when the caller already read it."""
def _sniff_head(path: Path, head: bytes | None = None) -> bytes;

"""Whether a `.h` file is Objective-C rather than C/C++ (#1475).

    `.h` is shared by C, C++, and ObjC; the suffix map routes it to extract_c,
    which silently drops every @interface/@protocol/@property/method (1 node, 0
    edges). Sniffing for an ObjC-only directive reroutes genuine ObjC headers to
    extract_objc while leaving every C/C++ header on its existing extractor.
    """
def _is_objc_header(path: Path, head: bytes | None = None) -> bool;

with entry {
    _CPP_HEADER_MARKERS = (
        b"class ",
        b"namespace ",
        b"template",
        b"::",
        b"public:",
        b"private:",
        b"protected:",
        b"extern \"C\"",
    );
}

"""Whether a `.m` file is Objective-C rather than MATLAB/Octave (#1702).

    `.m` is shared by Objective-C implementation files and MATLAB (also Octave).
    The suffix map routes `.m` to extract_objc unconditionally, which force-parses
    MATLAB through the Objective-C tree-sitter grammar and emits garbage nodes/edges
    (worse than skipping). A genuine ObjC `.m` always carries an ObjC directive
    (@implementation/@interface/@import/#import); MATLAB has none of them. Reuses
    the same marker set as the `.h` sniff. `.mm` is unambiguously Objective-C++ and
    is not sniffed.
    """
def _is_objc_source(path: Path) -> bool;

"""Whether a `.h` file is C++ rather than plain C (#1547).

    Mirrors `_is_objc_header`: sniffs for a C++-only token. Used only to reroute
    a `.h` from extract_c to extract_cpp when no ObjC marker is present (ObjC has
    priority). Conservative by construction — a plain C header matches nothing
    here and keeps its existing extract_c routing.
    """
def _is_cpp_header(path: Path, head: bytes | None = None) -> bool;

"""Return the correct extractor function for a file, or None if unsupported.

    ``sniff_headers=False`` answers the weaker question "does any extractor own
    this file" without reading it, for callers that only test for None (the #4978
    reconcile loop). It is NOT interchangeable with the default: a C++ header
    asked this way resolves to extract_c, which loses the class. Never use it to
    pick a grammar for an actual parse.
    """
def _get_extractor(path: Path, *, sniff_headers: bool = True) -> Any | None;

def _safe_extract_with_xaml_root(extractor, path: Path, `root: Path) -> dict;

"""Pool initializer. Under ``spawn`` a worker re-imports the package and
    starts with no overrides; hand it the parent's so `_get_extractor` and the
    cache key agree across processes (#2961)."""
def _worker_init(language_overrides: dict[str, str]) -> None;

"""Worker function for parallel extraction. Runs in a subprocess.

    Must be at module level (not a closure) so it can be pickled by
    ProcessPoolExecutor.

    Args:
        args: (index, path_str, root_str, cache_location_str) tuple. ``root``
            anchors hash keys / node ids / the XAML boundary; ``cache_location``
            is where the cache dir is written, decoupled per #1774. A legacy
            3-tuple (no cache_location) is still accepted for back-compat.

    Returns:
        (index, result_dict) so results can be placed back in order.
    """
def _extract_single_file(args: tuple) -> tuple[int, dict];

"""True when a spawn-based process pool cannot bootstrap because the caller's
    ``__main__`` has no importable file — stdin (``… | python -``), ``python -c``,
    or a REPL.

    Under the spawn start method (the Windows default, and macOS since 3.8) each
    worker re-imports the parent's ``__main__`` by its ``__file__`` path. For a
    stdin/-c/REPL caller that path is missing or bogus (``<stdin>``), so every
    worker dies during bootstrap and the pool raises ``BrokenProcessPool`` before
    any work is done. The shipped SKILL.md pipes a heredoc into the interpreter,
    so on Windows this is the common path, not an edge case — detecting it up
    front lets the caller run sequentially without a wall of worker tracebacks
    (#3669). A script WITH a real ``__main__`` file but no ``if __name__ ==
    "__main__"`` guard is a different failure this does not (and cannot) catch
    here; that one still surfaces via the ``BrokenProcessPool`` fallback.

    A ``__main__`` that has a module spec is re-imported by NAME, never by path
    (``multiprocessing.spawn.get_preparation_data``), and a spec named
    ``__main__`` is skipped in the worker altogether. That covers ``python -m``
    and zip-based launchers, notably the ``graphify.exe`` console script pip/uv
    install on Windows, whose ``__file__`` (``...\\graphify.exe\\__main__.py``)
    is not a file on disk — reading it as a stdin caller ran every Windows CLI
    extraction on one core."""
def _spawn_cannot_reimport_main -> bool;

with entry {
    _BYTES_PER_WORKER = 500000;
}

"""Worker count for the extraction pool when the caller passed none.

    GRAPHIFY_MAX_WORKERS (``--max-workers`` sets it too) wins, bounded by the
    number of files, exactly as before. Otherwise start one worker per
    ``_BYTES_PER_WORKER`` of uncached source, capped at the CPU count. A big
    job still gets every core (the old cap of 8 cost a 32-thread box 4x,
    #792); a small one no longer starts a process per core that each load
    graphify and the grammars for under a second of work.
    """
def _default_max_workers(uncached_work: list[tuple[int, Path]]) -> int;

"""Extract uncached files in parallel using ProcessPoolExecutor.

    Returns True if the pool ran to completion. Returns False if the pool
    failed in a recoverable way (typically Windows-spawn without an
    ``if __name__ == "__main__"`` guard in the calling script, which causes
    BrokenProcessPool); the caller should fall back to sequential extraction.
    """
def _extract_parallel(
    uncached_work: list[tuple[int, Path]],
    per_file: list[dict | None],
    `root: Path,
    max_workers: int | None,
    total_files: int,
    cache_location: Path | None = None,
) -> bool;

"""Extract uncached files sequentially (fallback for small batches)."""
def _extract_sequential(
    uncached_work: list[tuple[int, Path]],
    per_file: list[dict | None],
    `root: Path,
    total_files: int,
    cache_location: Path | None = None,
) -> None;

with entry {
    _PARALLEL_THRESHOLD = 20;
}

"""Extract AST nodes and edges from a list of code files.

    Two-pass process:
    1. Per-file structural extraction (classes, functions, imports)
    2. Cross-file import resolution: turns file-level imports into
       class-level INFERRED edges (DigestAuth --uses--> Response)

    Args:
        paths: files to extract from
        root: explicit anchor for source_file relativization, node ids, and
            symbol resolution. Pass the SCAN root whenever the cache lives
            somewhere else (`--out`); without it the anchor falls back to
            cache_root and every scanned file reads as out-of-root (#1941).
        cache_root: explicit root for graphify-out/cache/ (overrides the
            inferred common path prefix). Pass Path('.') when running on a
            subdirectory so the cache stays at ./graphify-out/cache/.
            Anchors ids/source_file only as a fallback when `root` is unset.
        parallel: if True and there are >= _PARALLEL_THRESHOLD uncached files,
            use ProcessPoolExecutor for multi-core extraction.
        max_workers: max subprocess count. Defaults to GRAPHIFY_MAX_WORKERS
            if set, else one worker per _BYTES_PER_WORKER of uncached source
            up to cpu_count; always bounded by len(uncached_work).
        resolution_context_nodes: read-only AST nodes from files that are NOT
            being extracted this run (an incremental rebuild's unchanged
            corpus, #2406). They extend the cross-file resolution indexes —
            the shared direct-call pass's label/file indexes, the
            indirect_call callable guard (via the persisted `_callable` /
            `_callable_class` markers, #2438), and the member-call resolvers
            run by `run_language_resolvers` (#2437) — so a changed caller can
            still bind `foo()`, `obj.method()`, or `submit(handler)` to an
            unchanged callee. They are never parsed, mutated, or returned;
            raw_calls come only from `paths`, so only edges sourced by the
            re-extracted files are emitted.
        resolution_context_edges: structural resolver edges from the same
            unchanged corpus (#2437). These map receiver types to their methods
            and preserve inheritance evidence for language-specific resolvers.
            Read-only, same contract as
            resolution_context_nodes: they widen the resolvers' view but only
            fresh results are appended to the returned nodes/edges.
        release_parse_memo: no effect; kept so existing callers still work.
            Python resolution no longer memoizes parsed trees, so there is
            nothing to release.
    """
def extract(
    paths: list[Path],
    cache_root: Path | None = None,
    *,
    `root: Path | None = None,
    parallel: bool = True,
    max_workers: int | None = None,
    resolution_context_nodes: list[dict] | None = None,
    resolution_context_edges: list[dict] | None = None,
    release_parse_memo: bool = False,
) -> dict;

with entry {
    RUN_ONLY_EXTRACTION_KEYS = frozenset({
        "extracted_sources",
        "failed_sources",
        "skipped_sources",
    });
}

def collect_files(
    target: Path, *, follow_symlinks: bool = False, `root: Path | None = None
) -> list[Path];

with entry:__main__ {
    if len(sys.argv) < 2 {
        print("Usage: python -m graphify.extract <file_or_dir> ...", file=sys.stderr);
        sys.exit(1);
    }

    paths = [];
    for arg_ in sys.argv[1:] {
        arg = arg_;
        paths.extend(collect_files(Path(arg)));
    }

    result = extract(paths);
    print(json.dumps(result, indent=2));
}
