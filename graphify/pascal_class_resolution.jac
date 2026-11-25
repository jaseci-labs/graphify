import from __future__ { annotations }
glob _PASCAL_SUFFIXES: any = (".pas", ".pp", ".dpr", ".dpk", ".inc");

def _is_pascal(source_file: object) -> bool;
def resolve_pascal_base_classes(per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]);
