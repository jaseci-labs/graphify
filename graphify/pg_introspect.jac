import from __future__ { annotations }
import from pathlib { Path, PurePosixPath }
def _quote_ident(name: str) -> str;
def introspect_postgres(dsn: str | None = None) -> dict;
