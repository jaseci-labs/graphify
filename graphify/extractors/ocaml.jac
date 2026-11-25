"""OCaml extractor (own module, optional tree-sitter-ocaml dependency).

Handles implementation files (.ml, `language_ocaml`) and interface files
(.mli, `language_ocaml_interface`). Interfaces have no expression bodies, so
they contribute definitions and `open` imports but no `calls` edges.
"""

import from __future__ { annotations }

import from pathlib { Path }

"""Extract modules, values, functions, types, variant constructors, `open`
    imports, and (for .ml) function calls from an OCaml source file."""
def extract_ocaml(path: Path) -> dict;
