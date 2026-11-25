import from __future__ { annotations }
glob DISPATCH_RELATION: any = "dispatches_to";

glob _DISPATCH_CONFIDENCE_BY_IMPLEMENTER_COUNT: any = {1: 0.85, 2: 0.75};

glob _DISPATCH_CONFIDENCE_FLOOR: any = 0.65;
def _dispatch_confidence(implementer_count: int) -> float;
def declared_in(`node: dict | None, suffixes: tuple[str, ...]) -> bool;
def method_label(`node: dict) -> str;
def resolve_interface_dispatch(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict], *, suffixes: tuple[str, ...]
);
def _implementing_pairs(
    declared: set[str], candidates: set[str], interface_name: str, node_by_id: dict
) -> list[tuple[str, str]];
def _overload_pairs(
    declared: set[str], candidates: set[str], node_by_id: dict
) -> list[tuple[str, str]];
