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
def _rightmost_operand(`obj: Node) -> Node;
def _member_callee(callee: Node) -> Node | None;
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

def _callable_signature(declaration: Node, source: bytes) -> str;
def _member_identity(member: Node, source: bytes) -> tuple[str, str, str] | None;
def _collision_groups(declared: list[tuple[str, str]]) -> dict[str, set[str]];

with entry {
    TypeContext = Tuple[Optional[str], FrozenSet[str]];
    VariableTypes = Dict[str, Optional[Tuple[str, TypeContext]]];

    _ELEMENTARY_ALIASES = {"uint": "uint256", "int": "int256", "byte": "bytes1"};
    _MAPPING_VALUE_NAME = re.compile("(.*\\S) ([A-Za-z_$][A-Za-z0-9_$]*)");
}

def _normalize_type(text: str) -> str;
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

def _inherited_call(
    caller_id: str, callee: str, arity: int | None, kind: str, source_file: str, `node: Node
) -> dict[str, Any];
def _c3_linearization(type_id: str, bases: dict[str, list[str]]) -> list[str];
def resolve_solidity_inherited_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
);
def resolve_solidity_type_references(
    _per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
);

def extract_solidity(path: Path) -> dict;
