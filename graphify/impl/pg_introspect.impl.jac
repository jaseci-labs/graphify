impl _quote_ident(name: str) -> str {
    return "\"" + name.replace("\"", "\"\"") + "\"";
}

impl introspect_postgres(dsn: str | None = None) -> dict {
    try {
        import psycopg;
    } except ModuleNotFoundError {
        raise ImportError(
            "psycopg is required for --postgres. Install with: pip install 'graphifyy[postgres]'"
        );
    }

    try {
        conn: any = psycopg.connect(dsn or "");
    } except psycopg.OperationalError as exc {
        msg: any = `str(exc).split("\n")[0];
        raise ConnectionError(f"could not connect to PostgreSQL: {msg}") from None;
    }

    try {
        conn.execute("SET TRANSACTION ISOLATION LEVEL SERIALIZABLE READ ONLY DEFERRABLE");
        cur: any;
        with conn.cursor() as cur {
            cur.execute(
                "\n                SELECT table_schema, table_name, table_type\n                FROM information_schema.tables\n                WHERE table_schema NOT IN ('pg_catalog', 'information_schema')\n                ORDER BY table_schema, table_name;\n            ",
            );
            tables: any = cur.fetchall();
            cur.execute(
                "\n                SELECT table_schema, table_name, view_definition\n                FROM information_schema.views\n                WHERE table_schema NOT IN ('pg_catalog', 'information_schema')\n                ORDER BY table_schema, table_name;\n            ",
            );
            views: any = cur.fetchall();
            cur.execute(
                "\n                SELECT routine_schema, routine_name, routine_type,\n                       routine_definition, external_language\n                FROM information_schema.routines\n                WHERE routine_schema NOT IN ('pg_catalog', 'information_schema')\n                ORDER BY routine_schema, routine_name;\n            ",
            );
            routines: any = cur.fetchall();
            cur.execute(
                "\n                SELECT\n                    con.conname AS constraint_name,\n                    ns.nspname AS table_schema,\n                    rel.relname AS table_name,\n                    (SELECT ARRAY_AGG(att.attname ORDER BY k.ord)\n                       FROM UNNEST(con.conkey) WITH ORDINALITY AS k(attnum, ord)\n                       JOIN pg_catalog.pg_attribute att\n                         ON att.attrelid = con.conrelid AND att.attnum = k.attnum\n                    ) AS columns,\n                    fns.nspname AS foreign_table_schema,\n                    frel.relname AS foreign_table_name,\n                    (SELECT ARRAY_AGG(att.attname ORDER BY k.ord)\n                       FROM UNNEST(con.confkey) WITH ORDINALITY AS k(attnum, ord)\n                       JOIN pg_catalog.pg_attribute att\n                         ON att.attrelid = con.confrelid AND att.attnum = k.attnum\n                    ) AS foreign_columns\n                FROM pg_catalog.pg_constraint con\n                JOIN pg_catalog.pg_class rel ON rel.oid = con.conrelid\n                JOIN pg_catalog.pg_namespace ns ON ns.oid = rel.relnamespace\n                JOIN pg_catalog.pg_class frel ON frel.oid = con.confrelid\n                JOIN pg_catalog.pg_namespace fns ON fns.oid = frel.relnamespace\n                WHERE con.contype = 'f'\n                  AND ns.nspname NOT IN ('pg_catalog', 'information_schema')\n                ORDER BY ns.nspname, rel.relname, con.conname;\n            ",
            );
            fks: any = cur.fetchall();
        }
    } finally {
        conn.close();
    }

    ddl: any = [];
    schema: any;
    name: any;
    for (schema, name, ttype) in tables {
        if ttype == "BASE TABLE" {
            ddl.append(f"CREATE TABLE {_quote_ident(schema)}.{_quote_ident(name)} (id INT);");
        }
    }
    body: any;
    for (schema, name, body) in views {
        if body {
            ddl.append(f"CREATE VIEW {_quote_ident(schema)}.{_quote_ident(name)} AS {body};");
        } else {
            ddl.append(f"CREATE VIEW {_quote_ident(schema)}.{_quote_ident(name)} AS SELECT 1;");
        }
    }
    for (constraint_name, t_schema, t_name, cols, r_schema, r_name, r_cols) in fks {
        col_list: any = ", ".join(_quote_ident(c) for c in cols);
        ref_col_list: any = ", ".join(_quote_ident(c) for c in r_cols);
        ddl.append(
            f"ALTER TABLE {_quote_ident(t_schema)}.{_quote_ident(t_name)} ADD CONSTRAINT {_quote_ident(constraint_name)} FOREIGN KEY ({col_list}) REFERENCES {_quote_ident(r_schema)}.{_quote_ident(r_name)}({ref_col_list});",
        );
    }
    for (schema, name, rtype, body, ext_lang) in routines {
        lang: any = (ext_lang or "plpgsql").lower();
        fn_sig: any = f"{_quote_ident(schema)}.{_quote_ident(name)}()";
        stub_body: any = "BEGIN SELECT 1; END;";
        if rtype in ("FUNCTION", "PROCEDURE") {
            actual_body: any = body or stub_body;
            ddl.append(
                f"CREATE FUNCTION {fn_sig} RETURNS void AS $gfx$ {actual_body} $gfx$ LANGUAGE {lang};",
            );
        }
    }

    ddl_string: any = "\n".join(ddl);
    info: any = psycopg.conninfo.conninfo_to_dict(dsn or "");
    host: any = info.get("host", "localhost");
    dbname: any = info.get("dbname", "db");
    virtual_path: any = PurePosixPath(f"postgresql://{host}/{dbname}");
    result: any = extract_sql(virtual_path, content=ddl_string);
    if result.get("error") {
        raise ImportError(
            format(result["error"], "")
                + " (required by --postgres; install with: pip install 'graphifyy[postgres]')",
        );
    }
    return result;
}
