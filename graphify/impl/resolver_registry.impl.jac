impl register(resolver: LanguageResolver) -> LanguageResolver {
    _REGISTRY.append(resolver);
    return resolver;
}

impl registered_resolvers -> list[LanguageResolver] {
    return `list(_REGISTRY);
}

impl run_language_resolvers(
    paths: Sequence[Path],
    per_file: list[dict],
    all_nodes: list[dict],
    all_edges: list[dict],
    *,
    resolvers: Sequence[LanguageResolver] | None = None,
) -> None {
    active: any = _REGISTRY if resolvers is None else resolvers;
    effective_suffix: any = importlib.import_module("graphify.rcfile").effective_suffix;
    suffixes_present: any = {effective_suffix(p) for p in paths};
    for resolver in active {
        if not resolver.suffixes & suffixes_present {
            continue;
        }
        try {
            resolver.resolve(per_file, all_nodes, all_edges);
        } except Exception as exc {
            _LOG.warning("%s resolution failed, skipping: %s", resolver.name, exc);
        }
    }
}
