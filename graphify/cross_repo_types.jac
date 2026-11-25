import from __future__ { annotations }
import from collections { defaultdict }

import from typing { TYPE_CHECKING }

glob SHARED_TYPE_RELATION: any = "same_type_as";
def link_shared_type_declarations(merged: "nx.Graph") -> int;
