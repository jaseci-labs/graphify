import operator;
import from __future__ { annotations }

import re;

import from pathlib { Path }

import from typing { Any }
def extract_powershell(path: Path) -> dict;

glob _PSD1_IMPORT_KEYS: any;

with entry {
    _PSD1_IMPORT_KEYS = frozenset({"RootModule", "NestedModules", "RequiredModules"});
}

def _psd1_collect_string_literals(`node, source: bytes) -> list[str];
def _psd1_module_name(raw: str) -> str;
def extract_powershell_manifest(path: Path) -> dict;
