import from __future__ { annotations }
import json;

import os;

import re;

import time;

import from datetime { datetime, timezone }

import from pathlib { Path }

import from typing { Any }

glob _NODES_RE: any;

with entry {
    _NODES_RE = re.compile("(\\d+)\\s+nodes?\\s+found");
}

def _log_path -> Path | None;

def _log_responses -> bool;

def nodes_from_result(result: str) -> int | None;
def log_query(
    *,
    kind: str,
    question: str,
    corpus: str,
    result: str | None = None,
    nodes_returned: int | None = None,
    duration_ms: float | None = None,
    **extra: Any,
);
