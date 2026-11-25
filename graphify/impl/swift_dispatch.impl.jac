impl resolve_swift_protocol_dispatch(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None {
    resolve_interface_dispatch(per_file, all_nodes, all_edges, suffixes=_SWIFT_SUFFIXES);
}
