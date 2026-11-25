"""Member-level interface dispatch for Go.

`d.provider.GetWithDataSource()` where `provider` is a `pluginContextProvider`
resolves to the interface's own `.GetWithDataSource()` requirement, because that
is what the call site names. The concrete `Provider.GetWithDataSource()` is a
separate node, and nothing joins the two, so a directed walk stops at the
interface — the Go twin of the C# gap #3003 closed.

C# and Swift feed `graphify.interface_dispatch` with the `implements` edges
their extractors read off a declaration. Go has no such declaration: a type
implements an interface by having its methods. So this pass infers the pairs
from method sets and hands them to the shared mechanism, which does the rest
(per-method `dispatches_to` at INFERRED, 0.85 / 0.75 / 0.65 by implementer
count, the single-owner guard). The inferred `implements` pairs only feed the
mechanism; they are not added to the graph.

A named type T implements interface I here when T's methods (value and
pointer receivers alike: the extractor hangs both off T's node) include every
method name I requires. Names only: method nodes carry no signature, and Go has
no overloads to tell apart. The guards:

- Both ends are declared in a `.go` file, as in the C# and Swift passes.
- An interface with no methods (`interface{}`, `any`) or only a type set is
  skipped: every type satisfies the first, and the second is a generics
  constraint, not something a call goes through.
- An interface that embeds another is used only when every embedded interface
  is declared in the corpus, with its methods counted in. `io.Reader` and
  other external interfaces have unknown methods, so such an interface is
  skipped rather than matched on part of its method set.
- An unexported method name (`run()`) can only be implemented in the
  interface's own package, so only types in the same directory count.
- An interface matched by more than `_MAX_IMPLICIT_IMPLEMENTERS` types is
  skipped. Name-only matching makes a lone common name (`Close`, `String`)
  match unrelated types, and past this many the edges say little. The builtin
  `error` and `fmt.Stringer` are not in the corpus, so they never match; a
  local redeclaration of either is matched like any other interface.

Struct embedding is not followed: a type whose method comes from an embedded
field does not own that method node, so it is not matched.
"""

import operator;

import from __future__ { annotations }

import from pathlib { PurePath }

glob _GO_SUFFIXES: any = (".go",);

glob _MAX_IMPLICIT_IMPLEMENTERS: any = 10;

def _is_go_interface(`node: dict | None) -> bool;

"""Link each Go interface method to the methods of every type that satisfies the interface."""
def resolve_go_interface_dispatch(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;
