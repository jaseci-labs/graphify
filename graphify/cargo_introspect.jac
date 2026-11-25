import from __future__ { annotations }
import importlib;
import os;

import re;

import from pathlib { Path }

import from typing { Any }

glob _CONFIDENCE_EXTRACTED: any = "EXTRACTED";

glob _MAX_DISCOVERY_DEPTH: any = 2;

def _load_toml(path: Path) -> dict[str, Any];
def package_name(manifest: Path) -> str | None;
def _discover_root_manifest(`root: Path) -> Path | None;

def _member_manifest_paths(`root: Path, root_data: dict[str, Any]) -> list[Path];
def introspect_cargo(`root: str | Path) -> dict[str, Any];
