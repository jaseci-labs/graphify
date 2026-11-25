import from __future__ { annotations }
import re;

import from pathlib { Path }

import from typing { Any }

glob _ELIXIR_CONTAINER_KEYWORDS: any;

glob _ELIXIR_DEF_KEYWORDS: any;

glob _ELIXIR_PRIVATE_SUFFIXES: any;

with entry {
    _ELIXIR_CONTAINER_KEYWORDS = frozenset({"defmodule", "defprotocol", "defimpl"});
    _ELIXIR_DEF_KEYWORDS = frozenset({
        "def",
        "defp",
        "defmacro",
        "defmacrop",
        "defguard",
        "defguardp",
        "defdelegate",
    });
    _ELIXIR_PRIVATE_SUFFIXES = ("!", "?");
}

def extract_elixir(path: Path) -> dict;
