import builtins;

import operator;
import from __future__ { annotations }

import html;

import from collections.abc { Iterable }

import from pathlib { Path }
def is_csharp_constructor_node(`node: dict) -> bool;
def is_csharp_explicit_interface_node(`node: dict) -> bool;
def _build_csharp_type_def_index(
    all_nodes: list[dict], all_edges: list[dict] | None = None
) -> dict[tuple[str, str], str];

def _strip_trailing_csharp_generic_args(target_fqn: str) -> str;
def _resolve_cross_file_csharp_imports(
    per_file: list[dict], paths: list[Path], all_nodes: list[dict], all_edges: list[dict]
);

glob _DOTNET_SOURCE_EXTS: any = (".cs", ".razor", ".cshtml");

def _is_cs_file(value: object) -> bool;

def _is_dotnet_source_file(value: object) -> bool;

def _metadata(value: object) -> dict;

def _is_plain_csharp_name(text: str) -> bool;
def bare_csharp_method_label(label: object, source_file: object) -> str | None;
def bare_csharp_method_labels_in_nodes(nodes: list[dict]) -> list[dict];
def csharp_method_label_reassignments(
    nodes: Iterable[tuple[object, dict]], method_edges: Iterable[tuple[object, object]]
) -> dict[str, str];

obj CsharpNameResolver {
    has node_by_id: any,
        type_def_index: any,
        known_namespaces: any,
        namespace_usings_by_file: any,
        aliases_by_file: any,
        static_usings_by_file: any,
        nested_types_by_holder: any,
        base_types_by_holder: any,
        _holder_nid_cache: any;

    def init(all_nodes: list[dict], all_edges: list[dict]);

    static def _namespace(`node: dict | None) -> str;

    static def _scope_chain(`node: dict) -> list[str];

    def _using_in_scope(scope_kind: str, scope_id: str | None, source_node: dict) -> bool;

    def _scopes_for(source_node: dict, source_file: str) -> list[str];
    def visible_namespaces(source_node: dict, source_file: str) -> list[set[str]];

    def _resolve_alias(label: str, source_node: dict, source_file: str) -> str | None;

    def _resolve_nested_type(holder_nid: str, name: str) -> str | None;

    def _resolve_holder_nid(target_fqn: str) -> str | None;
    def resolve_type_name(label: str, source_node: dict, source_file: str) -> tuple[str
        | None, bool];

    def resolve_label(label: str, source_node: dict, source_file: str) -> str | None;

    def resolve_qualified(label: str, qualifier: object, source_node: dict, source_file: str) -> str
        | None;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def _resolve_csharp_type_references(
    per_file: list[dict], paths: list[Path], all_nodes: list[dict], all_edges: list[dict]
);
