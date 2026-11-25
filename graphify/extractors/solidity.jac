"""Structural extraction for Solidity source files."""

import operator;

import from __future__ { annotations }

import os;

import re;

import from pathlib { Path }

import from typing { Any, Dict, FrozenSet, Optional, Tuple }

import from tree_sitter { Node }

glob _IDENTIFIER: any;

glob _TYPE_DECLARATIONS: any;

glob _SIMPLE_MEMBERS: any;

glob TypeContext: any;

glob VariableTypes: any;

glob _ELEMENTARY_ALIASES: any;

glob _MAPPING_VALUE_NAME: any;

glob _BUILTIN_MEMBER_TYPES: any;

glob _BUILTIN_CALL_TYPES: any;

with entry {
    _IDENTIFIER = re.compile("[A-Za-z_$][A-Za-z0-9_$]*");

    _TYPE_DECLARATIONS = {
        "contract_declaration": "contract",
        "interface_declaration": "interface",
        "library_declaration": "library",
    };
}

def _unquote(value: str) -> str;

"""The receiver of a member call whose object tree-sitter-solidity merged
    with a preceding operator (see :func:`_callee_text`)."""
def _rightmost_operand(`obj: Node) -> Node;

"""The ``member_expression`` of a member call ``recv.f(..)``, else ``None``."""
def _member_callee(callee: Node) -> Node | None;

"""The callee as written, e.g. ``super.supportsInterface`` or ``_check``.

    tree-sitter-solidity parses ``a || super.f(x)`` as a call of the member
    ``(a || super).f``: the binary expression is swallowed into the member's
    object. Read the right-most operand as the receiver instead, so the call
    is seen as ``super.f`` (and ``a && b.c(x)`` as ``b.c``). A prefix operator
    is swallowed the same way: ``!Lib.f(x)`` parses as ``(!Lib).f``.
    """
def _callee_text(callee: Node, source: bytes) -> str;

with entry {
    _SIMPLE_MEMBERS = {
        "struct_declaration": "struct",
        "enum_declaration": "enum",
        "event_definition": "event",
        "error_declaration": "error",
        "state_variable_declaration": "state_variable",
    };
}

"""``arity:types`` of a function, modifier or constructor, the part of its
    id that keeps overloads apart."""
def _callable_signature(declaration: Node, source: bytes) -> str;

"""``(kind, name, signature)`` a contract member's node id is made from,
    as extract_solidity's ``add_member`` mints it; ``None`` for a member that
    gets no id there."""
def _member_identity(member: Node, source: bytes) -> tuple[str, str, str] | None;

"""``{plain id: {names}}`` for the plain ids two or more distinct names
    would share. ``make_id`` drops a leading ``_`` and folds case, so
    ``_grantRole(bytes32,address)`` and ``grantRole(bytes32,address)`` in one
    contract mint ONE id; an overload is one name, never a collision."""
def _collision_groups(declared: list[tuple[str, str]]) -> dict[str, set[str]];

with entry {
    TypeContext = Tuple[Optional[str], FrozenSet[str]];
    VariableTypes = Dict[str, Optional[Tuple[str, TypeContext]]];

    _ELEMENTARY_ALIASES = {"uint": "uint256", "int": "int256", "byte": "bytes1"};
    _MAPPING_VALUE_NAME = re.compile("(.*\\S) ([A-Za-z_$][A-Za-z0-9_$]*)");
}

"""One spelling per type: whitespace collapsed (``mapping(a => b)`` ->
    ``mapping(a=>b)``) and the elementary aliases expanded (``uint`` ->
    ``uint256``), so a receiver's type compares equal to a ``using`` target or
    a parameter written differently."""
def _normalize_type(text: str) -> str;

"""The value type of ``mapping(K=>V)`` or the element type of ``T[]`` /
    ``T[n]`` (normalized text), else ``None``."""
def _element_type(text: str) -> str | None;

with entry {
    _BUILTIN_MEMBER_TYPES = {
        "msg.sender": "address",
        "msg.value": "uint256",
        "tx.origin": "address",
        "block.timestamp": "uint256",
        "block.number": "uint256",
        "block.chainid": "uint256",
    };
    _BUILTIN_CALL_TYPES = {
        "keccak256": "bytes32",
        "sha256": "bytes32",
        "blockhash": "bytes32",
        "abi.encode": "bytes",
        "abi.encodePacked": "bytes",
        "abi.encodeWithSelector": "bytes",
        "abi.encodeWithSignature": "bytes",
        "abi.encodeCall": "bytes",
    };
}

"""A call or modifier the contract itself does not declare, for
    :func:`resolve_solidity_inherited_calls`. ``kind`` is ``inherited`` (bare
    ``f()`` / ``this.f()``, ``emit E()``, ``revert Err()``), ``super``
    (``super.f()``), ``modifier`` or ``qualified`` (``Lib.f()``,
    ``revert Errors.Err()``, with a ``qualifier``)."""
def _inherited_call(
    caller_id: str, callee: str, arity: int | None, kind: str, source_file: str, `node: Node
) -> dict[str, Any];

"""Solidity's C3 linearization of ``type_id``, most derived first.

    ``bases`` lists each type's direct bases in declaration order
    (``contract C is A, B`` -> ``[A, B]``); Solidity treats the LAST one as
    the most derived, so they are merged right to left. Falls back to a
    right-to-left depth-first order when the bases cannot be merged (a cycle
    or an inconsistent hierarchy), so a broken graph still resolves.
    """
def _c3_linearization(type_id: str, bases: dict[str, list[str]]) -> list[str];

"""Bind calls, ``super`` calls and modifiers a contract inherits.

    The extractor binds ``f()`` and ``onlyX`` only inside the declaring
    contract, so a call to a function or modifier declared in a base contract
    (often in another file) got no edge. Runs after
    :func:`resolve_solidity_type_references` has bound each ``inherits`` edge
    to the base's real node, and walks the caller contract's C3 linearization
    as the compiler does: the first contract that declares a matching member
    wins (``super.f()`` starts after the caller's own contract, as the plain
    lookup does once the extractor found nothing there); several same-arity
    overloads in that contract are ambiguous and get no edge.

    A qualified call (``Lib.f()``, ``Base.f()``, ``revert Errors.Err()``) binds
    to the member of the one library/contract/interface of that name the
    caller's file declares or imports directly; no edge when the name or the
    (name, arity) is ambiguous.

    A call on a receiver of a contract or interface type (``IERC20 token;
    token.transfer()``, ``IERC20(a).transfer()``, ``Ownable(x).owner()``,
    ``token().clock()``) binds by name and arity through that type's
    linearization, as the compiler looks it up: an interface method links to
    the interface's own declaration, never to a guessed implementer. No edge
    when the receiver's type is unknown, is not exactly one visible
    contract/interface, when the name/arity is ambiguous, or when a public
    state variable of that name (its getter) comes first.

    A call attached by a ``using`` directive (``using SafeCast for uint256;
    x.toUint48()``, ``using EnumerableSet for EnumerableSet.AddressSet;
    _set.add(a)``) binds to the library or free function it attaches: the
    directives of the caller's contract and file, and the ``global`` ones of
    the receiver's type, whose target is ``*`` or the receiver's declared
    type, offering a function of that name with one more parameter than the
    call passes (the receiver) and the receiver's type as its first. Only a
    single such function is linked; no edge when the receiver's type is
    unknown, a directive's library is ambiguous, or two functions fit.
    """
def resolve_solidity_inherited_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;

"""Bind inheritance and using references to types in the file or its imports."""
def resolve_solidity_type_references(
    _per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;

def extract_solidity(path: Path) -> dict;
