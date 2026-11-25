import from __future__ { annotations }

import from pathlib { Path, PurePosixPath }

"""Double-quote a PostgreSQL identifier, escaping embedded double-quotes."""
def _quote_ident(name: str) -> str;

"""Connect to PostgreSQL, reconstruct DDL, and extract via extract_sql()."""
def introspect_postgres(dsn: str | None = None) -> dict;
