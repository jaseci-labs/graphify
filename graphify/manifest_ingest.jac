import from __future__ { annotations }
import re;

import xml.etree.ElementTree as ET;

import from pathlib { Path }

import from typing { Any }

glob __all__: any = [
    "is_package_manifest_path",
    "extract_package_manifest",
    "PACKAGE_MANIFEST_NAMES",
];

glob PACKAGE_MANIFEST_NAMES: dict[str, str];

glob _MAX_MANIFEST_BYTES: any;

glob _TOMLI_REQUIRED: any;

glob _PARSERS: any;

with entry {
    PACKAGE_MANIFEST_NAMES = {
        "apm.yml": "apm",
        "apm.yaml": "apm",
        "pyproject.toml": "python",
        "cargo.toml": "cargo",
        "go.mod": "go",
        "pom.xml": "maven",
    };

    _MAX_MANIFEST_BYTES = 2000000;

    _TOMLI_REQUIRED = "Package-manifest ingestion on Python < 3.11 needs tomli. Install with: pip install 'tomli' (or reinstall graphifyy, which declares tomli for python_version < '3.11').";
}

def _load_toml_module -> any;
def is_package_manifest_path(path: Path) -> bool;
def _pkg_id(name: str) -> str;
def extract_package_manifest(path: Path) -> dict[str, Any];
def _coerce_deps(value: Any) -> list[str];

def _parse_apm(text: str) -> dict | None;
def _parse_apm_fallback(text: str) -> dict | None;
def _pep508_name(spec: str) -> str;

def _parse_pyproject(text: str) -> dict | None;
def _parse_cargo(text: str) -> dict | None;

def _parse_gomod(text: str) -> dict | None;

def _parse_pom(text: str) -> dict | None;

with entry {
    _PARSERS = {
        "apm": _parse_apm,
        "python": _parse_pyproject,
        "cargo": _parse_cargo,
        "go": _parse_gomod,
        "maven": _parse_pom,
    };
}
