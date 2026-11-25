import from __future__ { annotations }
glob _FORM_SUFFIX_UNITS: any = {".dfm": (".pas", ".pp"), ".lfm": (".pas", ".pp")};
def _sibling_unit_files(form_file: str, known_files: set[str]) -> list[str];
def _method_name(label: str) -> str;
def resolve_dfm_handlers(per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]);
