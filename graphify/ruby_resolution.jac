"""Type-aware cross-file resolution for Ruby member calls.

Ruby has no type annotations and reuses method names heavily, so resolving
``obj.method()`` by globally-unique name is both lossy (drops on collision) and
unsafe (can attach to the wrong same-named method). This resolver instead uses
the receiver's *type*, inferred at extraction time from local
``var = ClassName.new`` bindings and carried on each member-call raw_call as
``receiver_type``.

It resolves three shapes, at EXTRACTED (1.0) confidence and only when the
target is certain (single owning class, single owned method) — bail otherwise:

  * ``Processor.new``          -> a ``calls`` edge to the ``Processor`` class
  * ``p.run`` where ``p`` is a ``Processor`` -> a ``calls`` edge to the direct
    or safely inherited ``Processor#run`` instance method
  * bare ``run`` in a subclass -> promote the existing inferred edge when the
    same-kind method is uniquely proven by the extracted inheritance chain

Registered into graphify.resolver_registry and run by extract() after id
disambiguation, so node ids and raw_call caller_nids are final.
"""

import operator;

import from __future__ { annotations }

import re;

import from typing { Any }

"""Normalize a class/method label to a comparison key (drop punctuation)."""
def _key(label: str) -> str;

def _method_name(label: object) -> str;

def _ruby_method_kind(`node: dict | None) -> str | None;

def _ruby_lookup_unsafe(`node: dict | None) -> bool;

glob _BARE_CONST_RE: any;

with entry {
    _BARE_CONST_RE = re.compile("^[A-Z][A-Za-z0-9_]*(?:::[A-Z][A-Za-z0-9_]*)*$");
}

def _ruby_raw_calls(per_file: list[dict]) -> list[dict];

"""Resolve Ruby ``Class.new`` and typed ``var.method`` calls by receiver type.

    Member-call resolution is additive. Inherited bare-call resolution only
    promotes an existing edge whose target is independently proven by ownership
    and ancestry; it never creates or redirects one.
    """
def resolve_ruby_member_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;
