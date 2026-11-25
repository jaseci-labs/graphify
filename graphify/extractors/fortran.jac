import from __future__ { annotations }
import re;

import from pathlib { Path }

glob _FORTRAN_CPP_EXTS: any = {".F", ".F90", ".F95", ".F03", ".F08"};

glob _INCLUDE_DIRECTIVE_RE: any;

with entry {
    _INCLUDE_DIRECTIVE_RE = re.compile(b"^[ \\t]*#[ \\t]*include\\b");
}

def _strip_include_directives(source: bytes) -> bytes;
def _cpp_preprocess(path: Path) -> bytes;
def extract_fortran(path: Path) -> dict;
