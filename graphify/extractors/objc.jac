import operator;
import from __future__ { annotations }

import from pathlib { Path }

import from typing { Any }

import re;

glob _OBJC_STEM_PART: any;

glob _CALLABLE: any;

glob _CALLABLE_CLASS: any;

with entry {
    _OBJC_STEM_PART = re.compile("[A-Za-z_][A-Za-z0-9_]*");
    _CALLABLE = ("_callable",);
    _CALLABLE_CLASS = ("_callable", "_callable_class");
}

def _objc_category_base_stem(stem: str) -> str;
def _objc_is_category(`node) -> bool;
def _objc_local_var_types(body_node, source: bytes, table: dict[str, str]);
def extract_objc(path: Path) -> dict;
