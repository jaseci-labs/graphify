"""C# cross-file resolution.

The config-driven C# *extractor* (``extract_csharp`` → ``_extract_generic``)
still lives in ``graphify/extract.py``; per ``extractors/MIGRATION.md`` the
config-driven languages cannot be ported one-by-one until the shared
``_extract_generic`` core moves as its own coordinated batch. This module is
the C# home for the parts that *are* cleanly separable — today, the cross-file
type-reference resolver below — and is where ``extract_csharp`` will land when
the core migration happens.
"""

import builtins;

import operator;

import from __future__ { annotations }

import html;

import from collections.abc { Iterable }

import from pathlib { Path }

"""A C# constructor node (instance, static or primary).

    A constructor carries its type's name but is reached only through `new`
    or a `: base(...)` / `: this(...)` initializer, never by that name, so the
    name-keyed call indexes leave it out.
    """
def is_csharp_constructor_node(`node: dict) -> bool;

"""A C# explicit interface implementation (``int IA.Get()``).

    It is reachable only through the interface, so the name-keyed call indexes
    leave it out; the interface member reaches it by dispatch.
    """
def is_csharp_explicit_interface_node(`node: dict) -> bool;

"""Return deterministic ``(namespace, name) -> node_id`` C# type definitions."""
def _build_csharp_type_def_index(
    all_nodes: list[dict], all_edges: list[dict] | None = None
) -> dict[tuple[str, str], str];

def _strip_trailing_csharp_generic_args(target_fqn: str) -> str;

"""Re-point resolvable C# ``using`` import edges to canonical internal nodes.

    Namespace imports resolve only to canonical C# namespace nodes. Alias imports
    resolve only when the alias target's prefix is a known canonical namespace and
    the simple type name exists in the shared C# type-definition index. ``using
    static`` and nested type aliases remain deliberate gaps because they need
    member/nested-type modeling beyond this import pass.
    """
def _resolve_cross_file_csharp_imports(
    per_file: list[dict], paths: list[Path], all_nodes: list[dict], all_edges: list[dict]
) -> None;

glob _DOTNET_SOURCE_EXTS: any = (".cs", ".razor", ".cshtml");

def _is_cs_file(value: object) -> bool;

def _is_dotnet_source_file(value: object) -> bool;

def _metadata(value: object) -> dict;

def _is_plain_csharp_name(text: str) -> bool;

"""Return the ``.Name()`` resolver form of a C# method label, else ``None``.

    Accepts both the extractor's bare ``.Name()`` and the owner-qualified
    ``Owner.Name()`` display form the graph build assigns (#4883). Extraction
    emits, and call resolution, interface dispatch, and the method-ghost index
    match on, the bare form, so anything reading labels back from a persisted
    graph normalizes through here. C# method and type names never contain a
    dot (an explicit interface implementation is still labeled ``.Build()``),
    so the split is unambiguous.
    """
def bare_csharp_method_label(label: object, source_file: object) -> str | None;

"""Copy of *nodes* with owner-qualified C# method labels reverted to ``.Name()``.

    Nodes that need no change are returned as-is; changed nodes are shallow
    copies, so the caller's list and dicts are never mutated.
    """
def bare_csharp_method_labels_in_nodes(nodes: list[dict]) -> list[dict];

"""Return ``{method_id: "Owner.Name()"}`` display labels for C# methods (#4883).

    *nodes* are ``(id, attrs)`` pairs and *method_edges* are ``(owner_id,
    method_id)`` pairs from ``method`` edges. A method with zero or several
    distinct owner labels, or an owner whose label is not a plain type name,
    is omitted and keeps its bare ``.Name()`` label. Derived from the bare form,
    so applying it to already-qualified labels is a no-op.
    """
def csharp_method_label_reassignments(
    nodes: Iterable[tuple[object, dict]], method_edges: Iterable[tuple[object, object]]
) -> dict[str, str];

"""Namespace/using/alias-aware C# simple-name resolution.

    Factored out of ``_resolve_csharp_type_references`` so the member-call pass
    (``_resolve_csharp_member_calls`` in ``graphify/extract.py``) can type a
    receiver with the same scoping rules the type-reference side already applies
    (the core of #1620), instead of bailing on any corpus-wide bare-name clash.

    Built from graph-stamped facts only: the ``(namespace, name)`` type-definition
    index plus the per-file ``using``/alias import edges (each carrying its lexical
    scope — ``("file", None)`` applies file-wide; ``("namespace", scope_id)``
    applies only where ``scope_id`` is in the referencing node's ``scope_chain``).
    """
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

    """Namespaces visible to extension-method lookup, innermost level first.

        C# 12.8.10.3: for each enclosing namespace declaration — innermost first,
        ending with the compilation unit — consider that namespace and the
        ``using namespace`` directives declared at that level. A file-level
        using belongs to the compilation unit, so it is only considered at the
        outermost level; that is why an extension declared in an inner namespace
        wins over one imported at the top of the file (#4828).

        A namespace-scoped using is treated as visible at every level inside it.
        That is coarser than the spec but only ever adds candidates at a deeper
        level than the directive's own, and the caller drops ties.
        """
    def visible_namespaces(source_node: dict, source_file: str) -> list[set[str]];

    def _resolve_alias(label: str, source_node: dict, source_file: str) -> str | None;

    def _resolve_nested_type(holder_nid: str, name: str) -> str | None;

    def _resolve_holder_nid(target_fqn: str) -> str | None;

    """Resolve a simple type name to a definition node id, with a verdict.

        Returns ``(node_id, decisive)``:
          * ``(nid, True)`` — exactly one in-scope definition (or alias target).
          * ``(None, True)`` — the name is claimed by this file's scoping (an
            alias, or >1 in-scope candidates): genuinely ambiguous/unresolvable,
            the caller must NOT fall back to a looser corpus-wide match.
          * ``(None, False)`` — scoping knows nothing about the name; a caller
            may fall back (e.g. to the corpus-wide unique bare-name match).
        """
    def resolve_type_name(label: str, source_node: dict, source_file: str) -> tuple[str
        | None, bool];

    def resolve_label(label: str, source_node: dict, source_file: str) -> str | None;

    def resolve_qualified(label: str, qualifier: object, source_node: dict, source_file: str) -> str
        | None;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""Arbitrate all C# ``inherits``/``implements``/``references`` targets.

    The extractor emits provisional same-file bindings and sourceless stubs. This
    pass is the single soundness gate: it uses only graph-stamped namespace/import
    facts, keeps a binding only when the referenced simple name resolves to one
    in-scope real type definition, and otherwise leaves the edge on a dangling stub.
    """
def _resolve_csharp_type_references(
    per_file: list[dict], paths: list[Path], all_nodes: list[dict], all_edges: list[dict]
) -> None;
