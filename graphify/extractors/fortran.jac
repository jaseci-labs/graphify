"""Fortran extractor. Moved verbatim from graphify/extract.py."""

import from __future__ { annotations }

import re;

import from pathlib { Path }

glob _FORTRAN_CPP_EXTS: any = {".F", ".F90", ".F95", ".F03", ".F08"};

glob _INCLUDE_DIRECTIVE_RE: any;

with entry {
    _INCLUDE_DIRECTIVE_RE = re.compile(b"^[ \\t]*#[ \\t]*include\\b");
}

"""Blank every cpp `#include` directive, preserving line numbers.

    cpp always searches the directory of the file being preprocessed for quoted
    includes and always honours absolute include paths, regardless of
    `-nostdinc`/`-I` — so a malicious capital-F Fortran source containing
    `#include "/etc/passwd"` or `#include "../../../secret"` would inline
    arbitrary host files into the graph we ship to the LLM and persist to disk
    (GHSA-pcc4-rvhr-2pr8, CWE-22/73/200). The `-nostdinc -I /dev/null` mitigation
    did not cover those two cases. Removing the directives entirely keeps macro
    expansion (the reason capital-F files need cpp — `#ifdef MPI`, `#define
    REAL8`) while making host-file reads impossible. Cross-file include fidelity
    is lost, which is an acceptable trade for closing an arbitrary-read vector on
    the default offline path. Each stripped line is blanked (not deleted) so
    reported line numbers still match the original source.
    """
def _strip_include_directives(source: bytes) -> bytes;

"""Run cpp -w -P on a capital-F Fortran file and return preprocessed bytes.

    Falls back to (include-stripped) raw file bytes if cpp is not available.
    Capital-F extensions conventionally require C preprocessor expansion
    (#ifdef MPI, #define REAL8, etc.) before parsing.

    Security (GHSA-pcc4-rvhr-2pr8): every `#include` directive is stripped before
    preprocessing (see `_strip_include_directives`) and the sanitized source is
    fed to cpp on stdin, so cpp never opens the source file's directory or any
    absolute/traversing include path — closing the corpus-side arbitrary
    file-read/exfiltration vector that `-nostdinc -I /dev/null` alone left open.
    Feeding stdin (rather than a file path) also removes the `-I/etc/x.F90`
    argument-injection edge case entirely.
    """
def _cpp_preprocess(path: Path) -> bytes;

"""Extract programs, modules, subroutines, functions, use statements, and calls from Fortran files.

    Capital-F extensions (.F, .F90, etc.) are run through the C preprocessor before
    parsing so #ifdef/#define macros are resolved.
    """
def extract_fortran(path: Path) -> dict;
