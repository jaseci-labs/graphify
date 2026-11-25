"""Join the same declared type across repositories in a merged graph (#3007).

`merge-graphs` prefixes every node id with its repo tag, so a contract type that
two services both declare arrives as two unconnected nodes. In a message-bus
codebase that is exactly where the interesting hop lives: the producer references
`SyncProductUpsertToSearchEvent` in one repo, the consumer implements
`IConsumer<SyncProductUpsertToSearchEvent>` in the other, and the merged graph has
no way to get from one to the other even though both sides name the same type.

This pass adds a `same_type_as` edge between type declarations that share both a
namespace and a name and come from different repos. Requiring the namespace keeps
it to types that were declared identically rather than two classes that merely
picked the same short name: on a pair of .NET services with 1440 and 262 declared
types, the namespace-plus-name match produced 7 pairs, all of them the shared
`EventManager.Models.*Event` contracts, and nothing else.

Edges only, no node merging. Two repos can hold copies of a contract that have
drifted, and collapsing them would hide that; a link lets a traversal cross while
each side keeps its own members, file and provenance.
"""

import from __future__ { annotations }

import from collections { defaultdict }

import from typing { TYPE_CHECKING }

glob SHARED_TYPE_RELATION: any = "same_type_as";

"""Link identically declared types across repos. Returns the edge count added.

    A candidate node is a sourced type declaration carrying a namespace and a
    repo tag. A group qualifies when its members span at least two repos, and
    every pair inside a qualifying group gets one edge. Groups are the handful of
    types two repos genuinely share, so the pairwise walk stays small.
    """
def link_shared_type_declarations(merged: "nx.Graph") -> int;
