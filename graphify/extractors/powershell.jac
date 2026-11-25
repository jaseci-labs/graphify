"""Powershell extractor. Moved verbatim from graphify/extract.py."""

import operator;

import from __future__ { annotations }

import re;

import from pathlib { Path }

import from typing { Any }

"""Extract functions, classes, methods, and using statements from a .ps1 file."""
def extract_powershell(path: Path) -> dict;

glob _PSD1_IMPORT_KEYS: any;

with entry {
    _PSD1_IMPORT_KEYS = frozenset({"RootModule", "NestedModules", "RequiredModules"});
}

"""Recursively collect all string_literal text values under *node*."""
def _psd1_collect_string_literals(`node, source: bytes) -> list[str];

"""Derive a bare module name from a raw string value.

    e.g. 'MyModule.psm1' → 'MyModule', './sub/Util.psm1' → 'Util', 'PSReadLine' → 'PSReadLine'
    """
def _psd1_module_name(raw: str) -> str;

"""Extract module dependency edges from a PowerShell .psd1 manifest file.

    .psd1 files are PowerShell data hashtables, not scripts. tree-sitter-powershell
    parses them correctly (they are syntactically valid PS). We walk the AST looking
    for RootModule, NestedModules, and RequiredModules keys and emit imports_from
    edges for every referenced module.

    RequiredModules supports two forms:
      - Simple string: 'PSReadLine'
      - Module specification: @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
    For the hashtable form we only follow the ModuleName key.
    """
def extract_powershell_manifest(path: Path) -> dict;
