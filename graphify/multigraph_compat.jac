"""Runtime compatibility probe for Graphify MultiDiGraph mode.

Verifies that the current NetworkX runtime supports the behaviors a future
opt-in --multigraph build will rely on. The probe is BEHAVIOR-based, not
version-based — both NX 3.4.2 (Py 3.10 lane) and NX 3.6.1+ (Py 3.11+ lane)
pass. The probe result is cached for the process lifetime via lru_cache.

No call sites added yet; downstream multigraph PRs will gate on
require_multigraph_capabilities() before enabling MDG mode.
"""

import from __future__ { annotations }

import from collections.abc { Callable }

import from dataclasses { dataclass }

import from functools { lru_cache }

import sys;

import from typing { Any }

import networkx as nx;

import from networkx.readwrite { json_graph }

@dataclass(frozen=True)
class CapabilityCheck {
    has name: str;

    has ok: bool;

    has detail: str;
}

@dataclass(frozen=True)
class MultigraphCapabilityResult {
    has python_version: str;

    has networkx_version: str;

    has checks: tuple[CapabilityCheck, ...];

    has ok: bool {
        getter {
            return all(check.ok for check in self.checks);
        }
    }

    has failed: tuple[CapabilityCheck, ...] {
        getter {
            return `tuple(check for check in self.checks if not check.ok);
        }
    }

    def error_message -> str;
}

def _check(name: str, func: Callable[[], bool | str]) -> CapabilityCheck;

def _build_probe_graph -> nx.MultiDiGraph;

def _probe_keyed_parallel_edges -> bool | str;

def _probe_node_link_round_trip -> bool | str;

def _probe_duplicate_key_overwrite_semantics -> bool | str;

"""Verify the Python language guarantee that NetworkX add_edge inherits.

    Python forbids passing the same keyword argument twice — once explicitly
    and once via **kwargs. This probe confirms that protection still applies
    to nx.MultiDiGraph.add_edge: a future loader that builds attrs from JSON
    will be reliably protected from accidentally setting `key` via attrs while
    also passing `key=` explicitly.

    The probe always passes on any Python 3.x version. Its purpose is to
    document the invariant explicitly in the probe suite so that if a future
    Python version relaxes this rule (extremely unlikely), the probe surfaces
    the regression.
    """
def _probe_reserved_key_attr_rejected -> bool | str;

def _probe_remove_edges_from_two_tuple_semantics -> bool | str;

def _probe_to_undirected_preserves_multigraph_type -> bool | str;

@lru_cache(maxsize=1)
def probe_multigraph_capabilities -> MultigraphCapabilityResult;

def require_multigraph_capabilities -> MultigraphCapabilityResult;
