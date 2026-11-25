import operator;
import from __future__ { annotations }

import re;

import from pathlib { Path }

glob _TYPEDEF_LINE: any;

with entry {
    _TYPEDEF_LINE = re.compile("\\s*typedef\\b");
}

def extract_dart(path: Path) -> dict;
