import from __future__ { annotations }
import from typing { Any, Callable }

import from pathlib { Path }

import from dataclasses { dataclass, field }

glob _WORKSPACE_PACKAGE_CACHE: dict[str, dict[str, Path]];

glob _JS_CACHE_BYPASS_SUFFIXES: any;

with entry {
    _WORKSPACE_PACKAGE_CACHE = {};

    _JS_CACHE_BYPASS_SUFFIXES = {
        ".js",
        ".jsx",
        ".mjs",
        ".cjs",
        ".ts",
        ".tsx",
        ".mts",
        ".cts",
        ".vue",
        ".svelte",
        ".ejs",
    };
}

@dataclass
class LanguageConfig {
    has ts_module: str;

    has ts_language_fn: str = "language";

    has class_types: frozenset = frozenset();

    has function_types: frozenset = frozenset();

    has import_types: frozenset = frozenset();

    has call_types: frozenset = frozenset();

    has static_prop_types: frozenset = frozenset();

    has helper_fn_names: frozenset = frozenset();

    has container_bind_methods: frozenset = frozenset();

    has event_listener_properties: frozenset = frozenset();

    has name_field: str = "name";

    has name_fallback_child_types: tuple = ();

    has body_field: str = "body";

    has body_fallback_child_types: tuple = ();

    has call_function_field: str = "function";

    has call_accessor_node_types: frozenset = frozenset();

    has call_accessor_field: str = "attribute";

    has call_accessor_object_field: str = "";

    has function_boundary_types: frozenset = frozenset();

    has import_handler: Callable | None = None;

    has resolve_function_name_fn: Callable | None = None;

    has sanitize_symbol_name_fn: Callable[[str], str] | None = None;

    has function_label_parens: bool = True;

    has extra_walk_fn: Callable | None = None;
}

@dataclass(frozen=True)
class _SymbolDeclarationFact {
    has file_path: Path;

    has name: str;

    has line: int;
}

@dataclass(frozen=True)
class _SymbolImportFact {
    has file_path: Path;

    has local_name: str;

    has target_path: Path;

    has imported_name: str;

    has line: int;
}

@dataclass(frozen=True)
class _SymbolAliasFact {
    has file_path: Path;

    has alias: str;

    has target_name: str;

    has line: int;
}

@dataclass(frozen=True)
class _SymbolExportFact {
    has file_path: Path;

    has exported_name: str;

    has line: int;

    has local_name: str | None = None;

    has target_path: Path | None = None;

    has target_name: str | None = None;

    has type_only: bool = False;
}

@dataclass(frozen=True)
class _StarExportFact {
    has file_path: Path;

    has target_path: Path;

    has line: int;

    has type_only: bool = False;
}

@dataclass(frozen=True)
class _NamespaceExportFact {
    has file_path: Path;

    has exported_name: str;

    has target_path: Path;

    has line: int;

    has type_only: bool = False;
}

@dataclass(frozen=True)
class _SymbolUseFact {
    has file_path: Path;

    has source_id: str;

    has local_name: str;

    has relation: str;

    has context: str;

    has line: int;
}

@dataclass
class _SymbolResolutionFacts {
    has declarations: list[_SymbolDeclarationFact] = field(default_factory=list[any]);

    has imports: list[_SymbolImportFact] = field(default_factory=list[any]);

    has aliases: list[_SymbolAliasFact] = field(default_factory=list[any]);

    has exports: list[_SymbolExportFact] = field(default_factory=list[any]);

    has star_exports: list[_StarExportFact] = field(default_factory=list[any]);

    has namespace_exports: list[_NamespaceExportFact] = field(default_factory=list[any]);

    has uses: list[_SymbolUseFact] = field(default_factory=list[any]);

    has module_imports: list[tuple[Path, Path, int, str]] = field(default_factory=list[any]);
}
