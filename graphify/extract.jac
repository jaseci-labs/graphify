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

def _raise_recursion_limit;
def _redact_rationale_labels(result: dict) -> dict;

def _safe_extract(extractor: Callable, path: Path, *, scan_root: Path | None = None) -> dict;
def _file_node_id(rel_path: Path) -> str;
def _python_absolute_import_alias_files(paths, `root) -> tuple[dict[str, set[str]], set[str]];
def _suppress_ambiguous_python_imports(
    edges: list[dict],
    nodes: list[dict],
    raw_calls: list[dict],
    ambiguous_modules: set[str],
    module_alias_files: dict[str, set[str]],
    `root: Path,
);
def _namespace_src_module_parts(parts: tuple[str, ...]) -> tuple[str, ...] | None;
def _repoint_python_package_imports(paths, all_nodes, all_edges, `root);
def _repoint_python_sibling_imports(paths, all_nodes, all_edges, `root);
def _repoint_python_sys_path_imports(per_file, all_nodes, all_edges, `root);

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

def _resolve_name(`node, source: bytes, config: LanguageConfig) -> str | None;
def _python_import_bindings(`node, source: bytes) -> list[tuple[str, str]];
def _missing_relative_module_name(attempted: Path, `root: Path, raw: str) -> str;
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
);

def _import_js(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
);

def _import_java(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
);

def _import_c(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
);

def _import_csharp(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
);

def _import_kotlin(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
);

def _import_scala(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
);

def _import_php(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
);
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

def _import_lua(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    edges: list,
    str_path: str,
    scope_stack: list[str] | None = None,
);

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

def _shorten_rationale_label(text: str, width: int = 80) -> str;
def _is_autogenerated_python(source: bytes) -> bool;
def _extract_python_rationale(path: Path, result: dict);

with entry {
    _TS_IMPORT_CALL_RE = re.compile(b"\\bimport\\s*\\(\\s*['\\\"][^'\\\"\\r\\n]+['\\\"]\\s*\\)");
}

def _ts_import_is_code(`root: Any, start: int) -> bool;
def _ts_type_argument_ranges(`root: Any, *, call_only: bool) -> list[tuple[int, int]];

with entry {
    _TsRangeIndex = Tuple[List[int], List[Tuple[int, int]], List[int]];
}

def _ts_ranges_containing(ranges: _TsRangeIndex, offset: int) -> list[tuple[int, int]];
def _ts_build_range_index(`root: Any, *, call_only: bool) -> _TsRangeIndex;
def _ts_error_nodes(`root: Any) -> list[Any];
def _ts_mask_candidate_is_malformed(
    original_root: Any, masked_range: tuple[int, int], errors: list[Any]
) -> bool;

with entry {
    _TS_EXPORT_TYPE_STAR_RE = re.compile(b"\\bexport\\s+(type)\\s*\\*");
}

def _normalize_ts_export_type_star(source: bytes) -> bytes | None;
def _normalize_ts_import_types(source: bytes, *, tsx: bool = False) -> bytes | None;
def extract_python(path: Path, *, `root: Path | None = None) -> dict;

with entry {
    _TS_TYPED_TAG_RE = re.compile(
        b"(?<![A-Za-z0-9_$])(?P<tag>[A-Za-z_$][A-Za-z0-9_$]*)(?P<types><\\s*\\{[^{}]*\\}\\s*\\[\\s*\\]\\s*>)(?=\\s*`)",
    );
    _TS_QUALIFIED_IMPORT_TYPE_RE = re.compile(
        b"\\bimport\\s*\\(\\s*['\\\"][^'\\\"\\r\\n]+['\\\"]\\s*\\)\\s*\\.(?P<name>[A-Za-z_$][A-Za-z0-9_$]*)(?=\\s*<)",
    );
}

def _normalize_ts_tag_and_import_annotations(source: bytes, *, tsx: bool = False) -> bytes | None;
def extract_js(path: Path) -> dict;
def _rescue_js_dynamic_imports(
    path: Path, result: dict, *, type_only_import_offsets: set[int] | None = None
);

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

def _extract_js_rationale(path: Path, result: dict);
def _resolve_rescued_specifier(
    path: Path, raw: str, aliases, base_url
) -> "tuple[str, str, Path | None, bool] | None";
def _emit_rescued_import(
    result: dict,
    existing_ids: set,
    file_node_id: str,
    path: Path,
    raw: str,
    relation: str,
    aliases,
    base_url,
);
def extract_svelte(path: Path) -> dict;

with entry {
    _ASTRO_FRONTMATTER_RE = re.compile("\\A\\s*---[^\\S\\r\\n]*\\r?\\n([\\s\\S]*?)\\r?\\n---");
    _ASTRO_SCRIPT_RE = _HTML_SCRIPT_TAG_RE;
    _ASTRO_NON_JS_TYPE_RE = _NON_JS_SCRIPT_TYPE_RE;
}

def _astro_mask_non_script(src: str) -> str;
def extract_astro(path: Path) -> dict;

with entry {
    _EJS_SCRIPT_TAG_RE = _HTML_SCRIPT_TAG_RE;
    _EJS_INCLUDE_RE = re.compile("<%(?:_|[-=])?\\s*include\\s*\\(\\s*['\"]([^'\"]+)['\"]");
}

def _ejs_mask_non_script(src: str) -> str;
def _emit_ejs_include(
    result: dict, existing_ids: set, file_node_id: str, path: Path, raw: str, line: int
);
def extract_ejs(path: Path) -> dict;
def extract_vue(path: Path) -> dict;
def extract_java(path: Path) -> dict;
def _is_spock_file(path: Path, ts_result: dict) -> bool;
def _extract_spock_fallback(path: Path, ts_result: dict) -> dict;
def extract_groovy(path: Path) -> dict;
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

def _blank_keeping_newlines(m: "re.Match[bytes]") -> bytes;
def _normalize_cpp_cli(source: bytes) -> bytes | None;

with entry {
    _CPP_EXPORT_MACRO_RE = re.compile(
        b"(\\b(?:class|struct)[ \\t\\r\\n]+)((?:[A-Z][A-Z0-9_]*[ \\t\\r\\n]+)+)(?!final[ \\t\\r\\n]*[:{])([A-Za-z_][A-Za-z0-9_]*(?:[ \\t\\r\\n]+final)?[ \\t\\r\\n]*)([:{])",
    );
}

def _normalize_cpp_export_macros(source: bytes) -> bytes;

with entry {
    _CPP_CONDITIONAL_TOKEN_RE = re.compile(
        b"//(?:\\\\\\r?\\n|[^\\r\\n])*|/\\*[\\s\\S]*?(?:\\*/|\\Z)|\\b[0-9](?:[A-Za-z_0-9.]|'[A-Za-z_0-9])*|(?:u8|u|U|L)?R\"([^ ()\\\\\\t\\v\\f\\r\\n]{0,16})\\(|\"(?:\\\\[\\s\\S]|[^\"\\\\])*\"|\\'(?:\\\\[\\s\\S]|[^\\'\\\\])*\\'|^[ \\t\\v\\f]*#[ \\t]*([A-Za-z_][A-Za-z_0-9]*)(?:\\\\\\r?\\n|[^\\r\\n])*",
        re.MULTILINE,
    );
    _CPP_CONDITIONAL_VARIANT_LIMIT = 32;
}

def _cpp_conditional_tokens(source: bytes) -> Generator[any, any, any];
def _cpp_conditional_groups(source: bytes) -> tuple[list[dict], str | None];
def _cpp_expression_conditional_groups(source: bytes, groups: list[dict]) -> set[int];
def _recover_cpp_conditional_initializers(path: Path, source: bytes, original: dict) -> dict;
def _stamp_cpp_condition_provenance(nodes: list[dict], edges: list[dict]);
def extract_cpp(path: Path) -> dict;
def extract_ruby(path: Path) -> dict;
def _csharp_string_opener(source: bytes, i: int) -> "tuple[int, int, bool, bool]";
def _csharp_broken_escape_offsets(source: bytes) -> list[int];
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
def _csharp_used_as_name(source: bytes, start: int, stop: int) -> bool;
def _csharp_contextual_name_offsets(source: bytes) -> list[int];
def _escape_csharp_contextual_names(source: bytes) -> bytes | None;

with entry {
    _CSHARP_BLANK_TABLE = `bytes(b if b in (10, 13) else 32 for b in range(256));
}

def _csharp_token_end(source: bytes, i: int) -> int;
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

def _csharp_branch_member_sigs(text: bytearray, start: int, end: int) -> set[tuple[bytes, int]];
def _blank_csharp_preprocessor(source: bytes) -> bytes | None;
def extract_csharp(path: Path) -> dict;
def extract_kotlin(path: Path) -> dict;
def extract_scala(path: Path) -> dict;

with entry {
    _PHP_SCRIPT_RE = re.compile(
        "<script\\b(?:\\\"[^\\\"]*\\\"|'[^']*'|[^>\\\"'])*>([\\s\\S]*?)</script\\s*>", re.IGNORECASE
    );
}

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

def _php_blank_unparsed_casts(source: bytes) -> bytes;
def extract_php(path: Path) -> dict;
def extract_lua(path: Path) -> dict;
def extract_swift(path: Path) -> dict;
def _canonicalize_csharp_namespace_nodes(all_nodes: list[dict], all_edges: list[dict]);

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
def _is_top_level_function_definition(`node: dict) -> bool;
def _rewire_unique_stub_nodes(nodes: list[dict], edges: list[dict], `root: Path | None = None);
def _augment_js_reexport_edges(
    paths: list[Path], nodes: list[dict], edges: list[dict], `root: Path
);
def _remap_objc_field_tables(per_file: list, mapping: dict);
def _merge_swift_extensions(per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]);
def _merge_csharp_partial_class_nodes(
    per_file: list[dict],
    all_nodes: list[dict],
    all_edges: list[dict],
    paths: list[Path],
    `root: Path,
);
def _drop_shadowed_csharp_partial_bases(all_nodes: list[dict], all_edges: list[dict]);

with entry {
    UNRESOLVED_CALLS_KEY = "unresolved_calls";
    _MAX_PARKED_CALLS_PER_NODE = 64;
}

def _park_unresolved_member_call(
    caller_node: dict | None, callee: str, receiver_type: str, lang: str, raw_call: dict
);
def _resolve_swift_member_calls(per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]);
def _stamp_python_fixture_paths(per_file: "list[dict | None]", `root: Path);
def _resolve_python_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
);

with entry {
    _JS_TS_SUFFIXES = (".ts", ".tsx", ".mts", ".cts", ".js", ".jsx", ".mjs", ".cjs");
}

def _resolve_typescript_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
);
def _attach_cpp_out_of_line_methods(
    nodes: list[dict],
    edges: list[dict],
    raw_calls: list[dict],
    *,
    context_nodes: list[dict] | None = None,
    context_edges: list[dict] | None = None,
);
def _resolve_cpp_member_calls(per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]);

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

def _csharp_keyword_type(name: str) -> str;
def _csharp_overload_index(nodes: list[dict], edges: list[dict]) -> dict;
def _csharp_collapse_overloads(candidates: list[str], argc: object, index: dict) -> list[str];
def _resolve_csharp_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
);
def _resolve_csharp_extension_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
);
def _bind_member_field_tables(
    per_file: list[dict], all_nodes: list[dict], *, lang: str
) -> dict[str, dict[str, str]];
def _resolve_php_member_calls(per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]);
def _resolve_java_member_calls(per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]);
def _resolve_objc_member_calls(per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]);
def _kotlin_package_index(per_file: list[dict]) -> dict[str, list[dict]];

with entry {
    _JVM_NAME_SUFFIXES = frozenset({".java", ".kt", ".kts"});
    _JAVA_IMPORT_RE = re.compile("(?m)^\\s*import\\s+(?:static\\s+)?([\\w.]+)\\s*;");
}

def _jvm_package_name(path: Path, result: dict) -> tuple[str, str] | None;
def _jvm_imports_by_file(path: Path, result: dict) -> dict[str, str];
def _resolve_jvm_references(
    per_file: list[dict], paths: list[Path], all_nodes: list[dict], all_edges: list[dict]
);
def _resolve_kotlin_import_targets(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
);

with entry {
    _C_FAMILY_HEADER_EXTS = frozenset({".h", ".hpp", ".hh", ".hxx", ".cuh", ".inl"});
}

def _resolve_c_include_edges(
    edges: list[dict], resolution_nodes: list[dict], `root: Path | None = None
);
def _resolve_csharp_constructor_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
);
def _resolve_csharp_qualified_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
);
def _resolve_kotlin_qualified_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
);
def _resolve_rust_self_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
);
def _resolve_go_member_calls(per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]);
def _resolve_elixir_import_targets(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
);
def _resolve_elixir_qualified_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
);
def _jvm_scope_index(
    all_nodes: list[dict], all_edges: list[dict]
) -> tuple[dict[str, str], dict[str, list[str]], dict[str, str], set[str]];
def _jvm_reachable_candidates(
    candidates: list[str],
    caller: str,
    callee: str,
    index: tuple[dict[str, str], dict[str, list[str]], dict[str, str], set[str]],
    imported_symbols: set[str],
) -> list[str];
def _resolve_kotlin_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
);

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

def _project_xml_is_safe(src: bytes) -> bool;
def extract_lazarus_package(path: Path) -> dict;
def _check_tree_sitter_version;
def extract_slnx(path: Path) -> dict;
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

def _sniff_head(path: Path, head: bytes | None = None) -> bytes;
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

def _is_objc_source(path: Path) -> bool;
def _is_cpp_header(path: Path, head: bytes | None = None) -> bool;
def _get_extractor(path: Path, *, sniff_headers: bool = True) -> Any | None;

def _safe_extract_with_xaml_root(extractor, path: Path, `root: Path) -> dict;
def _worker_init(language_overrides: dict[str, str]);
def _extract_single_file(args: tuple) -> tuple[int, dict];
def _spawn_cannot_reimport_main -> bool;

with entry {
    _BYTES_PER_WORKER = 500000;
}

def _default_max_workers(uncached_work: list[tuple[int, Path]]) -> int;
def _extract_parallel(
    uncached_work: list[tuple[int, Path]],
    per_file: list[dict | None],
    `root: Path,
    max_workers: int | None,
    total_files: int,
    cache_location: Path | None = None,
) -> bool;
def _extract_sequential(
    uncached_work: list[tuple[int, Path]],
    per_file: list[dict | None],
    `root: Path,
    total_files: int,
    cache_location: Path | None = None,
);

with entry {
    _PARALLEL_THRESHOLD = 20;
}

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
