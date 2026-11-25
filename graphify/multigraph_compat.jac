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
def _probe_reserved_key_attr_rejected -> bool | str;

def _probe_remove_edges_from_two_tuple_semantics -> bool | str;

def _probe_to_undirected_preserves_multigraph_type -> bool | str;

@lru_cache(maxsize=1)
def probe_multigraph_capabilities -> MultigraphCapabilityResult;

def require_multigraph_capabilities -> MultigraphCapabilityResult;
