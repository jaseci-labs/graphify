impl resolve_kotlin_interface_dispatch(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) {
    resolve_interface_dispatch(per_file, all_nodes, all_edges, suffixes=_KOTLIN_SUFFIXES);
}
