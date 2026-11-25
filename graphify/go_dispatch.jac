import operator;
import from __future__ { annotations }

import from pathlib { PurePath }

glob _GO_SUFFIXES: any = (".go",);

glob _MAX_IMPLICIT_IMPLEMENTERS: any = 10;

def _is_go_interface(`node: dict | None) -> bool;
def resolve_go_interface_dispatch(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
);
