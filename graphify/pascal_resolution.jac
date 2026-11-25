import from __future__ { annotations }
glob _PASCAL_SUFFIXES: any = (".pas", ".pp", ".dpr", ".dpk", ".inc");

def _pascal_raw_calls(per_file: list[dict]) -> list[dict];
def resolve_pascal_inherited_calls(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
);
