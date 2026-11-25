"""Member-level interface dispatch for Kotlin.

`g.greet()` on a `g: Greeter` resolves to the interface's own `.greet()`,
because that is what the call site names. Each implementing `override fun
greet()` is a separate node, so this pass links the interface method to every
implementer through `graphify.interface_dispatch`, as C# and Swift do.

Both ends must be declared in a Kotlin file: `implements` is resolved by name,
and a Java class implementing a Kotlin interface needs the Java extractor's own
evidence before it is claimed here.
"""

import from __future__ { annotations }

glob _KOTLIN_SUFFIXES: any = (".kt", ".kts");

"""Link each Kotlin interface method to every implementer that owns it unambiguously."""
def resolve_kotlin_interface_dispatch(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;
