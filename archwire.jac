graph layers {
    layer all { *; }
}

graph spaces {
    space graphify_pi: node { "graphify/pi"; }
    space graphifyy: cpython { "."; }
    package graphifyy { ship graphifyy; }
    space graphifyy_dev: cpython {
        scripts.*
            | tests
            | tests.bench_extract
            | tests.bench_query_scoring
            | tests.conftest
            | tests.csharp_extension_harness
            | tests.test_4874_jvm_resolution
            | tests.test_4909_reference_binding_scale
            | tests.test_4978_reconcile_cost
            | tests.test_4992_ts_import_types
            | tests.test_5072_splittable_under_cap_retry
            | tests.test_affected_cli
            | tests.test_affected_defines
            | tests.test_affected_member_seed
            | tests.test_affected_overrides
            | tests.test_affected_path_file_node
            | tests.test_affected_seed_reference_forms
            | tests.test_affected_undirected_incident
            | tests.test_agents_platform
            | tests.test_alias_folding
            | tests.test_analyze
            | tests.test_anthropic_custom_endpoint
            | tests.test_antigravity_install
            | tests.test_apm_fallback_version
            | tests.test_architecture_doc
            | tests.test_astro_extraction
            | tests.test_astro_import_ids
            | tests.test_atomic_canvas_export
            | tests.test_atomic_version_stamp
            | tests.test_atomic_writes
            | tests.test_backend_env_isolation
            | tests.test_backend_extras
            | tests.test_backend_opt_in
            | tests.test_benchmark
            | tests.test_benchmark_raw_graph
            | tests.test_benchmark_real_query
            | tests.test_binary_media_words
            | tests.test_blade_extractor
            | tests.test_build
            | tests.test_build_located_semantic_identity
            | tests.test_build_merge_dedup_scope
            | tests.test_build_merge_ghost_fold_4955
            | tests.test_build_merge_hyperedges_and_prune
            | tests.test_build_merge_shrink_guard
            | tests.test_builtin_global_type_refs
            | tests.test_c_include_resolution
            | tests.test_c_struct_callback_calls
            | tests.test_cache
            | tests.test_cache_long_paths
            | tests.test_cache_stale_import_target
            | tests.test_cache_windows_case_4925
            | tests.test_callflow_html
            | tests.test_cargo_introspect
            | tests.test_cargo_missing_manifest
            | tests.test_carried_hyperedge_remap
            | tests.test_case_only_decl_ids_4904
            | tests.test_case_sensitive_resolution
            | tests.test_charmap_encoding
            | tests.test_chunking
            | tests.test_cjs_module_extension
            | tests.test_claude_cli_backend
            | tests.test_claude_md
            | tests.test_cli_broken_pipe
            | tests.test_cli_export
            | tests.test_cli_help
            | tests.test_cli_without_mcp_extra
            | tests.test_cloud_cta
            | tests.test_cluster
            | tests.test_cluster_ambiguous_scale
            | tests.test_cluster_exclude_hubs
            | tests.test_cobol_extractor
            | tests.test_code_only_scope_4923
            | tests.test_code_only_update_all_hosts
            | tests.test_codebuddy
            | tests.test_community_hub_labels
            | tests.test_community_labels_skill
            | tests.test_compact_graph_json
            | tests.test_confidence
            | tests.test_confidence_score_output
            | tests.test_corrupt_graph_json
            | tests.test_cpp_alias_member_resolution
            | tests.test_cpp_anonymous_namespace_receivers
            | tests.test_cpp_conditional_initializers
            | tests.test_cpp_forward_declarations
            | tests.test_cpp_forward_receiver_completion
            | tests.test_cpp_incremental_type_resolution
            | tests.test_cpp_inherited_member_resolution
            | tests.test_cpp_local_callable_shadowing
            | tests.test_cpp_member_call_by_receiver_type
            | tests.test_cpp_member_declaration_identity
            | tests.test_cpp_method_declarations
            | tests.test_cpp_nested_and_cli
            | tests.test_cpp_objc_cross_file_calls
            | tests.test_cpp_preprocess
            | tests.test_cpp_receiver_chains
            | tests.test_cpp_receiver_parameters
            | tests.test_cpp_split_header_owner
            | tests.test_cpp_std_stubs
            | tests.test_cpp_template_members
            | tests.test_cpp_template_type_params
            | tests.test_cpp_type_alias
            | tests.test_cpp_underscore_ids
            | tests.test_cross_extension_reexport_self_cycle
            | tests.test_cross_language_call_resolution
            | tests.test_cross_repo_external_call_guards
            | tests.test_cross_repo_member_calls
            | tests.test_cross_repo_shared_types
            | tests.test_csharp_call_site_generic_args
            | tests.test_csharp_contextual_keyword_names
            | tests.test_csharp_delegate_declarations
            | tests.test_csharp_directive_encoding
            | tests.test_csharp_enum_members
            | tests.test_csharp_explicit_interface
            | tests.test_csharp_extension_calls
            | tests.test_csharp_extension_keyword_types
            | tests.test_csharp_extension_metadata
            | tests.test_csharp_extension_resolution
            | tests.test_csharp_field_generic_args
            | tests.test_csharp_foreach_loop_variable
            | tests.test_csharp_generic_callsites
            | tests.test_csharp_interface_dispatch
            | tests.test_csharp_member_calls
            | tests.test_csharp_member_chain_calls
            | tests.test_csharp_member_nodes
            | tests.test_csharp_method_owner_labels
            | tests.test_csharp_object_creation
            | tests.test_csharp_overloads
            | tests.test_csharp_partial_classes
            | tests.test_csharp_receiver_type_names
            | tests.test_csharp_static_property_receiver
            | tests.test_csharp_tuple_type_refs
            | tests.test_csharp_type_resolution
            | tests.test_csharp_underscore_collisions
            | tests.test_csharp_var_call_return_type
            | tests.test_csharp_verbatim_interpolation
            | tests.test_dart
            | tests.test_dart_typedef
            | tests.test_dart_underscore_ids
            | tests.test_dedup
            | tests.test_dedup_prefix_derived_words
            | tests.test_dedup_remaps_hyperedges
            | tests.test_dedup_shrink_refuses_force_write
            | tests.test_dedup_survivor_richness
            | tests.test_definition_file_portability
            | tests.test_delphi_form_resolution
            | tests.test_detect
            | tests.test_detect_jinja
            | tests.test_devin
            | tests.test_doc_twin_structure
            | tests.test_docx_to_markdown
            | tests.test_dotnet
            | tests.test_duplicate_annotation_edges
            | tests.test_edge_also_seen
            | tests.test_edge_tier_tie_break
            | tests.test_ejs_extractor
            | tests.test_elixir_defdelegate
            | tests.test_elixir_import_resolution
            | tests.test_elixir_keyword_def_calls
            | tests.test_elixir_qualified_calls
            | tests.test_elixir_underscore_ids
            | tests.test_elixir_unqualified_call_scope
            | tests.test_erlang_extractor
            | tests.test_evidence_binding
            | tests.test_explain_cli
            | tests.test_explain_same_file_tie
            | tests.test_export
            | tests.test_export_control_characters
            | tests.test_export_direction
            | tests.test_export_idempotent_writes
            | tests.test_export_path_length
            | tests.test_ext_tagged_id_clash
            | tests.test_external_stub_endpoints
            | tests.test_extract
            | tests.test_extract_cache_location
            | tests.test_extract_cli
            | tests.test_extract_code_only_cli
            | tests.test_extract_cost_ledger
            | tests.test_extract_memory_release
            | tests.test_extract_path_memo
            | tests.test_extract_php_closures
            | tests.test_extract_reports_skipped_media
            | tests.test_extraction_spec_ids
            | tests.test_extractor_scan_root_context
            | tests.test_extractors_registry
            | tests.test_failed_ast_replacement
            | tests.test_falkordb_integration
            | tests.test_file_id_collision_4854
            | tests.test_file_label_disambiguation
            | tests.test_file_node_id_spec
            | tests.test_file_slice
            | tests.test_file_truncation_warning
            | tests.test_forwarding_review_findings
            | tests.test_frontmatter_and_ssrf_hardening
            | tests.test_gemini_hook
            | tests.test_git_head_stdin
            | tests.test_global_add_tag_inference
            | tests.test_global_graph
            | tests.test_global_manifest_shape
            | tests.test_go_builtin_call_targets
            | tests.test_go_field_owner_package
            | tests.test_go_generic_receiver_methods
            | tests.test_go_generic_type_params
            | tests.test_go_import_repoint
            | tests.test_go_import_shadowing
            | tests.test_go_interface_dispatch
            | tests.test_go_interface_methods
            | tests.test_go_method_value_indirect_calls
            | tests.test_go_package_type_fold
            | tests.test_go_package_var_calls
            | tests.test_go_package_var_type_refs
            | tests.test_go_qualified_resolution
            | tests.test_go_receiver_member_calls
            | tests.test_go_same_file_receiver_calls
            | tests.test_go_same_name_receiver_across_packages
            | tests.test_go_sibling_receiver_with_outside_reference
            | tests.test_go_type_alias
            | tests.test_god_nodes_cli
            | tests.test_god_nodes_exclude_hubs
            | tests.test_google_workspace
            | tests.test_grammar_cache_key
            | tests.test_graph_context_cache_reload
            | tests.test_graph_invariance
            | tests.test_graphdb_push_indexes
            | tests.test_header_import_collision
            | tests.test_hollow_chunks_arm_shrink_guard
            | tests.test_home_sandbox
            | tests.test_hook_bash_read
            | tests.test_hook_chain_survives_skip
            | tests.test_hook_compact
            | tests.test_hook_content_freshness
            | tests.test_hook_corpus_changes
            | tests.test_hook_guard
            | tests.test_hook_guard_token_match
            | tests.test_hook_nudge_wording
            | tests.test_hook_out_of_project_paths
            | tests.test_hook_strict
            | tests.test_hook_strict_grep
            | tests.test_hooks
            | tests.test_hooks_rewrite
            | tests.test_html_script_breakout
            | tests.test_html_theme
            | tests.test_hyperedge_member_shapes
            | tests.test_hyperedge_roundtrip
            | tests.test_hypergraph
            | tests.test_id_normalization_contract
            | tests.test_ignore_file_encoding
            | tests.test_image_vision
            | tests.test_import_cycles_shortest_first
            | tests.test_import_extension_resolution
            | tests.test_import_self_loops
            | tests.test_imported_export_forwarding
            | tests.test_incomplete_build_guard
            | tests.test_incremental
            | tests.test_incremental_mtime_collision
            | tests.test_incremental_unscanned_placeholders
            | tests.test_indirect_call_arrow_single_param_shadow
            | tests.test_indirect_call_block_scoped_shadow
            | tests.test_indirect_call_catch_binding_shadow
            | tests.test_indirect_call_external_import_shadow
            | tests.test_indirect_call_file_scope_callback_shadow
            | tests.test_indirect_call_for_of_binding_shadow
            | tests.test_indirect_call_function_expression_shadow
            | tests.test_indirect_call_nested_closure_shadow
            | tests.test_indirect_dispatch
            | tests.test_indirect_dispatch_assign_return
            | tests.test_indirect_dispatch_getattr
            | tests.test_indirect_dispatch_module_attr
            | tests.test_inferred_confidence_rubric
            | tests.test_ingest
            | tests.test_ingest_capture_race
            | tests.test_ingest_url_type
            | tests.test_inherited_field_receivers
            | tests.test_injection_sentinel_coverage
            | tests.test_install
            | tests.test_install_hook_identity
            | tests.test_install_line_endings
            | tests.test_install_references
            | tests.test_install_roundtrip
            | tests.test_install_strings
            | tests.test_install_upgrade
            | tests.test_install_version_stamp
            | tests.test_install_version_warning
            | tests.test_issue_3405_python_resolution
            | tests.test_issue_3472_source_file_collision
            | tests.test_java_anonymous_class
            | tests.test_java_enum_members
            | tests.test_java_lombok_getter
            | tests.test_java_member_calls
            | tests.test_java_nested_type_identity
            | tests.test_java_overloads
            | tests.test_java_type_resolution
            | tests.test_java_underscore_ids
            | tests.test_js_callback_calls
            | tests.test_js_cjs_barrel_require_call
            | tests.test_js_destructured_export
            | tests.test_js_dynamic_import_affected
            | tests.test_js_dynamic_imports
            | tests.test_js_exported_fn_call_resolution
            | tests.test_js_exported_scalar_bindings
            | tests.test_js_extends_require_4688
            | tests.test_js_import_resolution
            | tests.test_js_member_call_bare_name_fallback
            | tests.test_js_member_collisions
            | tests.test_js_module_level_anonymous_calls
            | tests.test_js_namespace_import_call_edges
            | tests.test_js_nested_function_scope
            | tests.test_js_require_binding_shadow
            | tests.test_js_require_external_package_call
            | tests.test_js_this_member_expressions
            | tests.test_js_walk_order
            | tests.test_jsconfig_baseurl
            | tests.test_json_schema_config
            | tests.test_jsx_component_usage_calls
            | tests.test_kilo_config_merge
            | tests.test_kotlin_generic_type_params
            | tests.test_kotlin_grammar
            | tests.test_kotlin_interface_dispatch
            | tests.test_kotlin_java_call_edges_4935
            | tests.test_kotlin_object_literal
            | tests.test_kotlin_typealias_declarations
            | tests.test_kotlin_underscore_ids
            | tests.test_label_retry
            | tests.test_labeling
            | tests.test_language_override_imports
            | tests.test_language_override_lifecycle
            | tests.test_language_overrides
            | tests.test_language_resolvers
            | tests.test_languages
            | tests.test_learning_overlay_input
            | tests.test_linked_worktree_reconcile
            | tests.test_llm_ambiguous_fragments
            | tests.test_llm_backends
            | tests.test_llm_null_token_counts
            | tests.test_llm_parser
            | tests.test_llm_parser_reasoning
            | tests.test_load_graph_release_rows
            | tests.test_long_path_hashing
            | tests.test_lookup_exit_codes
            | tests.test_loose_sibling_import_resolution
            | tests.test_lost_saved_semantic_nodes
            | tests.test_lua_import
            | tests.test_lua_method_calls
            | tests.test_lua_underscore_ids
            | tests.test_manifest_ingest
            | tests.test_manifest_tomli_required
            | tests.test_markdown_code_spans
            | tests.test_markdown_sections
            | tests.test_mcp_graph_view_cache
            | tests.test_mcp_ingest
            | tests.test_merge_chunks_validation
            | tests.test_merge_graphs_cli
            | tests.test_merge_sweeps_reextract_orphans
            | tests.test_minhash
            | tests.test_module_level_underscore_decl_ids
            | tests.test_msbuild_dir_evidence
            | tests.test_multigraph_compat
            | tests.test_multigraph_diagnostics
            | tests.test_multilang
            | tests.test_nested_type_owners
            | tests.test_no_cluster_run_only_keys
            | tests.test_no_cluster_undeclared_endpoints
            | tests.test_no_dedup_flag
            | tests.test_node_id_canonical
            | tests.test_non_regular_files
            | tests.test_non_string_node_ids
            | tests.test_objc_callable_markers
            | tests.test_objc_category_interfaces
            | tests.test_objc_category_portable_ids
            | tests.test_objc_enum_declarations
            | tests.test_objc_field_table_remap
            | tests.test_objc_member_calls
            | tests.test_objc_method_collisions
            | tests.test_objc_property_ivar_receivers
            | tests.test_obsidian_dangling_member
            | tests.test_obsidian_filename_cap
            | tests.test_obsidian_unicode_tags
            | tests.test_obsidian_vault_migration
            | tests.test_ocaml
            | tests.test_office_incremental
            | tests.test_office_limits
            | tests.test_ollama
            | tests.test_ollama_ctx_sizing
            | tests.test_ollama_live
            | tests.test_ollama_native_chat
            | tests.test_ollama_retry_cap
            | tests.test_openai_custom_endpoint
            | tests.test_opencode_plugin_refresh
            | tests.test_out_dir_evidence
            | tests.test_oversized_document_slicing
            | tests.test_owned_type_sources
            | tests.test_package_json_subpath_imports
            | tests.test_parked_call_site_file
            | tests.test_partial_cache
            | tests.test_partial_extraction_warning
            | tests.test_pascal
            | tests.test_pascal_base_class_resolution
            | tests.test_pascal_call_scoping
            | tests.test_pascal_parse_recovery
            | tests.test_pascal_record_methods
            | tests.test_pascal_resolution
            | tests.test_pascal_singleton_resolution
            | tests.test_path_cli
            | tests.test_path_confidence
            | tests.test_path_type_member
            | tests.test_paths
            | tests.test_pdf_extra_warning
            | tests.test_pdf_slicing
            | tests.test_pdf_token_estimate
            | tests.test_pg_introspect
            | tests.test_phantom_cross_package_call
            | tests.test_phantom_external_import
            | tests.test_php_class_const_initializer_refs
            | tests.test_php_language_construct_calls
            | tests.test_php_member_call_gaps
            | tests.test_php_member_collisions
            | tests.test_php_object_creation
            | tests.test_php_receiver_member_calls
            | tests.test_php_static_call_resolution
            | tests.test_php_type_resolution
            | tests.test_php_unparsed_casts
            | tests.test_pi_guard_install
            | tests.test_pi_install
            | tests.test_pin_hash_seed
            | tests.test_pipeline
            | tests.test_plain_import_member_calls
            | tests.test_pnpm_workspace_globs
            | tests.test_pr10_csharp_overrides
            | tests.test_pr10_resolution_overrides
            | tests.test_pr10_watch_overrides
            | tests.test_prompt_id_rule_matches_ids
            | tests.test_provider_registry
            | tests.test_prs
            | tests.test_prune_source_aliases
            | tests.test_prune_sweeps_orphans
            | tests.test_python_aliased_call_in_method
            | tests.test_python_bare_call_not_enclosing_method
            | tests.test_python_builtin_call_shadowing_4989
            | tests.test_python_decorators
            | tests.test_python_external_import_calls
            | tests.test_python_forward_ref_file_id
            | tests.test_python_import_never_resolves_to_itself
            | tests.test_python_import_resolution
            | tests.test_python_imported_call_caller_collision
            | tests.test_python_inherited_method_calls
            | tests.test_python_injected_factory_calls
            | tests.test_python_lambda_call_shadowing
            | tests.test_python_member_call_language_gate
            | tests.test_python_member_collisions
            | tests.test_python_module_call_exact_name
            | tests.test_python_module_instance_calls
            | tests.test_python_nested_class_identity
            | tests.test_python_param_call_shadowing
            | tests.test_python_parse_release
            | tests.test_python_property_reads
            | tests.test_python_pytest_fixture_receivers
            | tests.test_python_reexport_type_binding
            | tests.test_python_self_type_ref
            | tests.test_python_subscript_type_refs
            | tests.test_python_type_alias
            | tests.test_python_typed_receiver_calls
            | tests.test_python_underscore_resolution
            | tests.test_qualified_annotation_stub_bind
            | tests.test_qualified_type_competition
            | tests.test_query_cli
            | tests.test_query_deterministic_order
            | tests.test_query_fallback_edges
            | tests.test_query_induced_edges
            | tests.test_query_mcp_direction
            | tests.test_query_names_its_graph
            | tests.test_query_seed_order
            | tests.test_query_seeds
            | tests.test_query_source_first
            | tests.test_querylog
            | tests.test_r_extractor
            | tests.test_rationale
            | tests.test_read_hook
            | tests.test_read_path_imports
            | tests.test_reflect
            | tests.test_relation_collapse_precedence
            | tests.test_replace_or_append_section
            | tests.test_report
            | tests.test_report_gap_thresholds
            | tests.test_resolution_collision_index
            | tests.test_resolution_one_parse_per_file
            | tests.test_resolve_memoization
            | tests.test_ruby_bare_self_send_calls
            | tests.test_ruby_resolution
            | tests.test_ruby_underscore_ids
            | tests.test_rust_anonymous_const
            | tests.test_rust_builtin_type_hubs
            | tests.test_rust_case_collisions
            | tests.test_rust_crate_use_scope
            | tests.test_rust_impl_method_collisions
            | tests.test_rust_in_file_call_binding
            | tests.test_rust_macro_argument_calls
            | tests.test_rust_macro_rules
            | tests.test_rust_prelude_trait_edges
            | tests.test_rust_scoped_call_resolution
            | tests.test_rust_self_member_calls
            | tests.test_rust_type_alias_union
            | tests.test_rust_use_trees
            | tests.test_scala_abstract_methods
            | tests.test_scala_context_bounds
            | tests.test_scala_extension_methods
            | tests.test_scala_generic_type_params
            | tests.test_scala_given_instances
            | tests.test_scala_self_type
            | tests.test_scala_top_level_binding
            | tests.test_scala_type_definition
            | tests.test_scala_underscore_ids
            | tests.test_scan_root_contextvar
            | tests.test_scip_ingest
            | tests.test_search_hook
            | tests.test_search_hook_scope
            | tests.test_section_subgraph_index
            | tests.test_security
            | tests.test_semantic_cache_basename_recovery
            | tests.test_semantic_cache_out_root
            | tests.test_semantic_cleanup
            | tests.test_semantic_fragment_sanitize
            | tests.test_semantic_id_remap_root
            | tests.test_semantic_origin_stamp
            | tests.test_semantic_similarity
            | tests.test_serve
            | tests.test_serve_http
            | tests.test_serve_reload_off_loop
            | tests.test_settings_merge
            | tests.test_shrink_guard_dedup_merge_4940
            | tests.test_shrink_guard_replaced_sources
            | tests.test_skill_auto_refresh
            | tests.test_skill_code_only_incremental_update
            | tests.test_skill_codex_semantic_merge
            | tests.test_skill_no_backtick_substitution
            | tests.test_skill_part_a_explicit_root
            | tests.test_skill_persisted_scan_options
            | tests.test_skill_semantic_all_cached
            | tests.test_skill_version_warning
            | tests.test_skill_when_to_build
            | tests.test_skillgen
            | tests.test_skillgen_input_path_injection
            | tests.test_slice_checkpoint_completeness
            | tests.test_solidity_extractor
            | tests.test_solidity_inherited_calls
            | tests.test_source_file_encoding
            | tests.test_source_key_memoization
            | tests.test_sourceless_call_targets
            | tests.test_sql_comma_joins_and_dblink
            | tests.test_sql_cross_file_tables
            | tests.test_sql_go_batches
            | tests.test_sql_non_ascii_table_names
            | tests.test_sql_oracle_editionable
            | tests.test_sql_oracle_packages
            | tests.test_sql_plpgsql_body_reads
            | tests.test_sql_tsql_procedures
            | tests.test_src_layout_import_resolution
            | tests.test_stale_prune
            | tests.test_stat_index_husk
            | tests.test_stat_index_multi_root
            | tests.test_stat_index_portability
            | tests.test_suggest_questions_ambiguous
            | tests.test_svelte_extraction
            | tests.test_swift_builtin_noise
            | tests.test_swift_computed_properties
            | tests.test_swift_cross_file_calls
            | tests.test_swift_generic_type_params
            | tests.test_swift_import_resolution
            | tests.test_swift_macro_declarations
            | tests.test_swift_protocol_dispatch
            | tests.test_swift_protocol_requirements
            | tests.test_swift_self_type_ref
            | tests.test_swift_underscore_ids
            | tests.test_symbol_resolution
            | tests.test_symlinked_root_source_file
            | tests.test_terraform
            | tests.test_terraform_modules
            | tests.test_trailing_newline_not_a_syntax_error
            | tests.test_transcribe
            | tests.test_tree_html
            | tests.test_truncation_full_answer
            | tests.test_ts_abstract_methods
            | tests.test_ts_decorator_chains
            | tests.test_ts_decorators
            | tests.test_ts_export_type_star
            | tests.test_ts_generators
            | tests.test_ts_import_require
            | tests.test_ts_import_type_arguments
            | tests.test_ts_inheritance
            | tests.test_ts_namespace
            | tests.test_ts_new_expression_calls
            | tests.test_ts_parse_warning
            | tests.test_ts_receiver_member_calls
            | tests.test_ts_typed_template_and_annotation
            | tests.test_tsconfig_declaration_targets
            | tests.test_type_only_import_cycles
            | tests.test_typescript_enum_members
            | tests.test_typescript_module_extensions
            | tests.test_unc_probe_guard
            | tests.test_undirected_two_file_import_cycle
            | tests.test_uninstall_global_registration
            | tests.test_uninstall_purge_safety
            | tests.test_uninstall_scope
            | tests.test_uninstall_symlink
            | tests.test_unmapped_at_alias_resolution
            | tests.test_unverified_semantic_shrink
            | tests.test_update_incremental
            | tests.test_update_js_resolution_inputs
            | tests.test_update_lock_contention
            | tests.test_update_manifest_preservation
            | tests.test_update_missing_graph
            | tests.test_update_no_change_gate
            | tests.test_update_partial_manifest
            | tests.test_validate
            | tests.test_variadic_param_refs
            | tests.test_vbnet_extractor
            | tests.test_vue_extraction
            | tests.test_walk_python_tree_iterative
            | tests.test_watch
            | tests.test_watch_identity_cache
            | tests.test_watch_inotify_overflow
            | tests.test_watch_manifest_location
            | tests.test_watch_pruned
            | tests.test_wheel_packaging
            | tests.test_wiki
            | tests.test_wiki_case_only_relabel
            | tests.test_wiki_link_filename_parity
            | tests.test_wiki_truncation_indicator
            | tests.test_word_count_cache
            | tests.test_workers_by_work_size
            | tests.test_yaml_extraction
            | tests.test_zero_node_no_cache
            | tools
            | tools.*;
    }
}

graph import {
    graphify.pi.index --> "tests/pi.test" { default }
    graphify.paths --> graphify.__main__ { GRAPHIFY_OUT }
    graphify.install --> graphify.__main__ {
        _AGENTS_MD_MARKER,
        _ANTIGRAVITY_RULES_PATH,
        _ANTIGRAVITY_WORKFLOW,
        _ANTIGRAVITY_WORKFLOW_PATH,
        _CLAUDE_MD_MARKER,
        _CODEBUDDY_MD_MARKER,
        _CURSOR_RULE,
        _CURSOR_RULE_PATH,
        _DEVIN_RULES,
        _DEVIN_RULES_PATH,
        _GEMINI_MD_MARKER,
        _KILO_CONFIG_JSONC_PATH,
        _KILO_CONFIG_JSON_PATH,
        _KILO_PLUGIN_JS,
        _KILO_PLUGIN_PATH,
        _OPENCODE_CONFIG_PATH,
        _OPENCODE_PLUGIN_HEADER,
        _OPENCODE_PLUGIN_JS,
        _OPENCODE_PLUGIN_PATH,
        _PLATFORM_ALIASES,
        _PLATFORM_CONFIG,
        _VSCODE_INSTRUCTIONS_MARKER,
        _agents_install,
        _agents_platform_install,
        _agents_platform_uninstall,
        _agents_uninstall,
        _always_on,
        _amp_install,
        _amp_legacy_cleanup,
        _amp_uninstall,
        _antigravity_finalize,
        _antigravity_install,
        _antigravity_uninstall,
        _canonical_platform,
        _claude_pretooluse_hooks,
        _copy_skill_file,
        _cursor_install,
        _cursor_uninstall,
        _devin_rules_install,
        _devin_rules_uninstall,
        _drop_opencode_config_entry,
        _gemini_hook,
        _install_claude_hook,
        _install_codebuddy_hook,
        _install_codex_hook,
        _install_gemini_hook,
        _install_kilo_plugin,
        _install_opencode_plugin,
        _install_skill_references,
        _kilo_config_path,
        _kilo_config_write_path,
        _kilo_install,
        _kilo_uninstall,
        _kilo_uninstall_global,
        _kiro_install,
        _kiro_uninstall,
        _load_json_like,
        _opencode_config_names_plugin,
        _opencode_dir,
        _opencode_plugin_is_v1_only,
        _packaged_skill_refs_dir,
        _platform_skill_destination,
        _print_banner,
        _print_install_usage,
        _print_project_git_add_hint,
        _project_install,
        _project_scope_root,
        _project_uninstall,
        _project_uninstall_all,
        _remove_claude_skill_registration,
        _remove_skill_file,
        _replace_or_append_section,
        _resolve_graphify_exe,
        _skill_lock,
        _skill_registration,
        _strip_graphify_hook,
        _strip_graphify_md_section,
        _strip_json_comments,
        _uninstall_claude_hook,
        _uninstall_codebuddy_hook,
        _uninstall_codex_hook,
        _uninstall_gemini_hook,
        _uninstall_kilo_plugin,
        _uninstall_opencode_plugin,
        _vscode_skill_destination,
        claude_install,
        claude_uninstall,
        codebuddy_install,
        codebuddy_uninstall,
        dispatch_install_cli,
        gemini_install,
        gemini_uninstall,
        install,
        uninstall_all,
        vscode_install,
        vscode_uninstall,
    }
    graphify.cli --> graphify.__main__ {
        _GEMINI_NUDGE_TEXT,
        _HOOK_SOURCE_EXTS,
        _READ_NUDGE,
        _SEARCH_NUDGE,
        _StageTimer,
        _clone_repo,
        _default_graph_path,
        _enforce_graph_size_cap_or_exit,
        _run_hook_guard,
        dispatch_command,
    }
    graphify.paths --> graphify.cli {
        GRAPHIFY_OUT,
        GRAPHIFY_OUT_NAME,
        consumed,
        consumed_graph_rows,
        graph_root_for,
        load_node_link_graph,
        nfc,
        out_path,
        read_graph_json,
        restore_arc_direction,
        write_json_atomic,
        write_text_atomic,
    }
    graphify.cache --> graphify.cli {
        check_semantic_cache,
        file_hash,
        mark_semantic_cache_partial,
        prune_semantic_cache,
        save_semantic_cache,
        scope_semantic_result,
    }
    graphify.detect --> graphify.cli {
        _is_sensitive,
        _md5_file,
        _nfc,
        detect,
        detect_incremental,
        load_manifest,
        save_manifest,
    }
    graphify.extract --> graphify.cli { RUN_ONLY_EXTRACTION_KEYS, _get_extractor, extract }
    graphify.export --> graphify.cli {
        MALFORMED_GRAPH,
        attach_hyperedges,
        backup_if_protected,
        existing_graph_node_count,
        existing_graph_node_counts_by_source,
        push_to_falkordb,
        push_to_neo4j,
        to_canvas,
        to_cypher,
        to_graphml,
        to_html,
        to_json,
        to_obsidian,
        to_svg,
    }
    graphify.security --> graphify.cli { check_graph_file_size_cap, sanitize_label }
    graphify.__main__ --> graphify.cli { main }
    graphify.llm --> graphify.cli {
        BACKENDS,
        _custom_providers_path,
        _extraction_system,
        _format_backend_env_keys,
        _get_backend_api_key,
        _partial_source_files,
        _stamp_semantic_origin,
        _strip_partial_markers,
        _validate_ollama_base_url,
        backend_disabled_by_env,
        detect_backend_with_source,
        estimate_cost,
        extract_corpus_parallel,
        generate_community_labels,
        provider_base_url_ok,
    }
    graphify.prs --> graphify.cli { cmd_prs }
    graphify.hooks --> graphify.cli { install, status, uninstall }
    graphify.serve --> graphify.cli {
        _QUERY_NO_MATCH,
        _ambiguity_message,
        _confidence_tag,
        _is_ambiguity_refusal,
        _path_confidence_line,
        _query_graph_text,
        _resolve_path_endpoint,
        _resolve_single_node,
        _weakest_shortest_path,
    }
    graphify.querylog --> graphify.cli;
    graphify.build --> graphify.cli {
        _is_ast_tier,
        build,
        build_from_json,
        build_merge,
        dedupe_edges,
        dedupe_nodes,
        disambiguate_file_labels_in_nodes,
        distinct_repo_tags,
        edge_datas,
        edge_evidence,
        finalize_raw_graph_endpoints,
        graph_has_legacy_ids,
        has_parallel_links,
        legacy_id_source_prefix,
        merge_raw_extraction,
        prefix_graph_for_global,
        qualify_csharp_method_labels_in_nodes,
        take_shrink_accounting,
    }
    graphify.rcfile --> graphify.cli { RC_FILENAME, load_graphifyrc }
    graphify.affected --> graphify.cli {
        DEFAULT_AFFECTED_RELATIONS,
        format_affected,
        load_graph,
        resolve_seed_outcome,
    }
    graphify.analyze --> graphify.cli { god_nodes, suggest_questions, surprising_connections }
    graphify.ingest --> graphify.cli { ingest, save_query_result }
    graphify.reflect --> graphify.cli { lessons_fresh, load_learning_overlay, reflect }
    graphify.sections --> graphify.cli {
        DEFAULT_MAX_CHARS,
        format_section,
        read_section,
        resolve_section_query,
        section_root,
    }
    graphify.diagnostics --> graphify.cli {
        diagnose_file,
        format_diagnostic_json,
        format_diagnostic_report,
    }
    graphify.watch --> graphify.cli {
        _git_head,
        _read_build_excludes,
        _read_build_gitignore,
        _rebuild_code,
        _write_build_config,
        check_update,
        watch,
    }
    graphify.cluster --> graphify.cli {
        cluster,
        community_member_sigs,
        label_communities_by_hub,
        label_still_applies,
        remap_communities_to_previous,
        score_all,
    }
    graphify.report --> graphify.cli { generate, load_learning_for_report }
    graphify.exporters.html --> graphify.cli { _HTML_STALE_MARKER, _viz_node_limit }
    graphify.tree_html --> graphify.cli { DEFAULT_MAX_CHILDREN, write_tree_html }
    graphify.cross_repo_types --> graphify.cli { link_shared_type_declarations }
    graphify.cross_repo_calls --> graphify.cli { link_cross_repo_member_calls }
    graphify.callflow_html --> graphify.cli { write_callflow_html }
    graphify.wiki --> graphify.cli { to_wiki }
    graphify.benchmark --> graphify.cli { print_benchmark, run_benchmark }
    graphify.global_graph --> graphify.cli { global_add, global_list, global_path, global_remove }
    graphify.extractors.terraform --> graphify.cli { refresh_terraform_paths }
    graphify.extractors.resolution --> graphify.cli { _cpp_reconciliation_paths }
    graphify.pg_introspect --> graphify.cli { introspect_postgres }
    graphify.cargo_introspect --> graphify.cli { introspect_cargo }
    graphify.semantic_cleanup --> graphify.cli { load_validated_semantic_fragment }
    graphify.cache --> graphify.extract { load_cached, save_cached }
    graphify.cargo_introspect --> graphify.extract { package_name }
    graphify.security --> graphify.extract { redact_secrets, sanitize_metadata }
    graphify.mcp_ingest --> graphify.extract { extract_mcp_config, is_mcp_config_path }
    graphify.manifest_ingest --> graphify.extract {
        extract_package_manifest,
        is_package_manifest_path,
    }
    graphify.resolver_registry --> graphify.extract {
        LanguageResolver,
        register,
        run_language_resolvers,
    }
    graphify.ruby_resolution --> graphify.extract { resolve_ruby_member_calls }
    graphify.csharp_dispatch --> graphify.extract { resolve_csharp_interface_dispatch }
    graphify.go_dispatch --> graphify.extract { resolve_go_interface_dispatch }
    graphify.kotlin_dispatch --> graphify.extract { resolve_kotlin_interface_dispatch }
    graphify.swift_dispatch --> graphify.extract { resolve_swift_protocol_dispatch }
    graphify.pascal_class_resolution --> graphify.extract { resolve_pascal_base_classes }
    graphify.dfm_resolution --> graphify.extract { resolve_dfm_handlers }
    graphify.pascal_resolution --> graphify.extract { resolve_pascal_inherited_calls }
    graphify.pascal_singleton_resolution --> graphify.extract { resolve_pascal_singleton_calls }
    graphify.cpp_resolution --> graphify.extract { CppTypeLookup }
    graphify.markdown_resolution --> graphify.extract {
        MARKDOWN_MENTION_SUFFIXES,
        resolve_markdown_mentions,
    }
    graphify.rcfile --> graphify.extract {
        activate_language_overrides,
        cache_salt,
        effective_suffix,
        get_language_overrides,
        set_language_overrides,
    }
    graphify.extractors.engine --> graphify.extract {
        PYTEST_FIXTURE_UNTYPED,
        REFERENCE_CONTEXTS,
        _CSHARP_TYPE_PARAMETER_SCOPE_DECLARATIONS,
        _C_PRIMITIVE_TYPE_NODES,
        _JAVA_BUILTIN_TYPES,
        _JAVA_TYPE_PARAMETER_SCOPE_DECLARATIONS,
        _JS_FUNCTION_VALUE_TYPES,
        _JS_SCOPE_BOUNDARY,
        _PYTHON_ANNOTATION_NOISE,
        _PYTHON_TYPE_CONTAINERS,
        _RUBY_CLASS_FACTORIES,
        _c_collect_type_refs,
        _cpp_collect_type_refs,
        _cpp_declarator_name,
        _cpp_is_header_guard,
        _cpp_local_var_types,
        _csharp_attribute_names,
        _csharp_classify_base,
        _csharp_collect_type_refs,
        _csharp_extra_walk,
        _csharp_namespace_id,
        _csharp_namespace_name,
        _csharp_pick_overload,
        _csharp_pre_scan_interfaces,
        _csharp_type_parameters_in_scope,
        _dynamic_import_js,
        _extract_generic,
        _find_body,
        _find_require_call,
        _get_cpp_func_name,
        _java_annotation_names,
        _java_collect_type_refs,
        _java_extra_walk,
        _java_type_parameters_in_scope,
        _js_collect_pattern_idents,
        _js_dispatch_value_idents,
        _js_extra_walk,
        _js_import_is_type_only,
        _js_local_bound_names,
        _js_member_assignment_target,
        _js_module_bound_names,
        _kotlin_collect_type_refs,
        _kotlin_function_return_type_node,
        _kotlin_property_type_node,
        _kotlin_user_type_name,
        _php_collect_type_refs,
        _php_method_return_type_node,
        _php_name_text,
        _python_collect_assignment_targets,
        _python_collect_param_refs,
        _python_collect_type_refs,
        _python_local_bound_names,
        _python_module_bound_names,
        _python_param_names,
        _read_csharp_type_name,
        _require_imports_js,
        _ruby_const_last_name,
        _ruby_extra_walk,
        _ruby_local_class_bindings,
        _ruby_new_class_name,
        _scala_collect_type_refs,
        _semantic_reference_edge,
        _source_location,
        _swift_classify_base,
        _swift_collect_type_refs,
        _swift_constructor_type,
        _swift_declaration_keyword,
        _swift_extra_walk,
        _swift_local_var_types,
        _swift_pre_scan,
        _swift_property_name,
        _swift_property_type_node,
        _swift_receiver_name,
        _swift_user_type_name,
        _ts_decorator_name,
        _ts_descendant_decorators,
        _ts_emit_decorator_edges,
        _ts_extra_walk,
        _ts_method_name,
        _ts_receiver_type_table,
    }
    graphify.extractors.base --> graphify.extract {
        _LANGUAGE_BUILTIN_GLOBALS,
        _PYTHON_BUILTIN_NAMES,
        _file_stem,
        _make_id,
        _read_source_bytes,
        _read_source_text,
        _read_text,
        active_scan_root,
        set_active_scan_root,
    }
    graphify.extractors.apex --> graphify.extract { extract_apex }
    graphify.extractors.bash --> graphify.extract { extract_bash }
    graphify.extractors.blade --> graphify.extract { extract_blade }
    graphify.extractors.cobol --> graphify.extract { extract_cobol }
    graphify.extractors.csharp --> graphify.extract {
        CsharpNameResolver,
        _is_cs_file,
        _is_dotnet_source_file,
        _resolve_cross_file_csharp_imports,
        _resolve_csharp_type_references,
        bare_csharp_method_labels_in_nodes,
        is_csharp_constructor_node,
        is_csharp_explicit_interface_node,
    }
    graphify.extractors.dart --> graphify.extract { extract_dart }
    graphify.extractors.dm --> graphify.extract {
        extract_dm,
        extract_dmf,
        extract_dmi,
        extract_dmm,
    }
    graphify.extractors.elixir --> graphify.extract { extract_elixir }
    graphify.extractors.erlang --> graphify.extract { extract_erlang, resolve_erlang_remote_calls }
    graphify.extractors.fortran --> graphify.extract { _cpp_preprocess, extract_fortran }
    graphify.extractors.go --> graphify.extract { _GO_PREDECLARED_FUNCS, extract_go }
    graphify.extractors.json_config --> graphify.extract { extract_json }
    graphify.extractors.yaml_config --> graphify.extract { extract_yaml }
    graphify.extractors.commonlisp --> graphify.extract { extract_commonlisp }
    graphify.extractors.markdown --> graphify.extract { _MD_LINK_INDEX_CACHE, extract_markdown }
    graphify.extractors.ocaml --> graphify.extract { extract_ocaml }
    graphify.extractors.pascal_forms --> graphify.extract {
        extract_delphi_form,
        extract_lazarus_form,
    }
    graphify.extractors.powershell --> graphify.extract {
        extract_powershell,
        extract_powershell_manifest,
    }
    graphify.extractors.r --> graphify.extract { extract_r, resolve_r_sourced_calls }
    graphify.extractors.razor --> graphify.extract { extract_razor }
    graphify.extractors.robot --> graphify.extract { extract_robot }
    graphify.extractors.rust --> graphify.extract { extract_rust }
    graphify.extractors.sln --> graphify.extract { extract_sln }
    graphify.extractors.solidity --> graphify.extract {
        extract_solidity,
        resolve_solidity_inherited_calls,
        resolve_solidity_type_references,
    }
    graphify.extractors.sql --> graphify.extract { _norm_ident, extract_sql }
    graphify.extractors.terraform --> graphify.extract {
        extract_terraform,
        prepare_terraform,
        resolve_terraform_modules,
    }
    graphify.extractors.verilog --> graphify.extract { extract_verilog }
    graphify.extractors.vbnet --> graphify.extract { extract_vbnet, resolve_vbnet_partial_calls }
    graphify.extractors.zig --> graphify.extract { extract_zig }
    graphify.paths --> graphify.extract { disambiguate_ambiguous_candidates }
    graphify.extractors.models --> graphify.extract {
        LanguageConfig,
        _JS_CACHE_BYPASS_SUFFIXES,
        _NamespaceExportFact,
        _StarExportFact,
        _SymbolAliasFact,
        _SymbolDeclarationFact,
        _SymbolExportFact,
        _SymbolImportFact,
        _SymbolResolutionFacts,
        _SymbolUseFact,
        _WORKSPACE_PACKAGE_CACHE,
    }
    graphify.extractors.resolution --> graphify.extract {
        _DECLDEF_HEADER_SUFFIXES,
        _DECLDEF_IMPL_SUFFIXES,
        _EXPORT_CONDITION_PRIORITY,
        _HTML_SCRIPT_TAG_RE,
        _JS_INDEX_FILES,
        _JS_PRIMITIVE_TYPES,
        _JS_RESOLVE_EXTS,
        _NON_JS_SCRIPT_TYPE_RE,
        _PACKAGE_IMPORTS_CACHE,
        _PYTHON_STDLIB_MODULE_NAMES,
        _SCAN_ROOT_NAMESPACE_CACHE,
        _TSCONFIG_ALIAS_CACHE,
        _TSCONFIG_BASEURL_CACHE,
        _VUE_SCRIPT_LANG_RE,
        _VUE_SCRIPT_RE,
        _WORKSPACE_MANIFEST_NAMES,
        _apply_symbol_resolution_facts,
        _augment_symbol_resolution_edges,
        _cached_realpath,
        _cached_source_key,
        _collect_js_symbol_resolution_facts,
        _collect_python_symbol_resolution_facts,
        _contained_in_package,
        _cpp_exact_includes,
        _cpp_include_path,
        _cpp_reconciliation_paths,
        _cpp_source_key,
        _decldef_class_stem,
        _disambiguate_colliding_node_ids,
        _find_workspace_root,
        _go_import_path_for_file,
        _is_python_package_dir,
        _is_type_like_definition,
        _js_call_identifier,
        _js_default_export_name,
        _js_default_import_name,
        _js_export_clause,
        _js_export_statement_is_star,
        _js_exported_declaration_names,
        _js_lexical_aliases,
        _js_module_specifier,
        _js_named_specifiers,
        _js_namespace_export_name,
        _js_source_path,
        _js_top_level_function_bodies,
        _load_tsconfig_aliases,
        _load_tsconfig_base_url,
        _load_workspace_packages,
        _match_tsconfig_alias,
        _merge_cpp_forward_classes,
        _merge_cpp_member_declarations,
        _merge_decl_def_classes,
        _merge_go_package_types,
        _node_disambiguation_source_key,
        _package_entry_candidates,
        _parse_js_tree,
        _parse_python_tree,
        _pascal_class_stem_cache,
        _pascal_project_root,
        _pascal_resolve_class,
        _pascal_resolve_unit,
        _pascal_unit_cache,
        _pnpm_workspace_globs,
        _probe_python_module_candidate,
        _python_call_identifier,
        _python_import_from_module,
        _python_imported_names,
        _python_top_level_function_bodies,
        _read_tsconfig_aliases,
        _resolve_c_include_path,
        _resolve_cross_file_imports,
        _resolve_cross_file_java_imports,
        _resolve_export_target,
        _resolve_go_type_references,
        _resolve_java_type_references,
        _resolve_js_import_path,
        _resolve_js_import_target,
        _resolve_js_module_path,
        _resolve_lua_import_target,
        _resolve_php_type_references,
        _resolve_python_module_path,
        _resolve_python_namespace_dir,
        _resolve_tsconfig_alias,
        _resolve_workspace_import,
        _source_key,
        _strip_jsonc,
        _svelte_mask_non_script,
        _ts_collect_type_refs,
        _ts_heritage_clause_entries,
        _ts_walk_class_members,
        _vue_mask_non_script,
        _walk_js_tree,
        _walk_python_tree,
        _workspace_globs,
    }
    graphify.symbol_resolution --> graphify.extract {
        resolve_bash_source_edges,
        rust_scoped_call_survivors,
    }
    graphify.extractors.pascal --> graphify.extract {
        _PAS_BEGIN_END_TOKEN_RE,
        _PAS_CALL_RE,
        _PAS_END_SEMI_RE,
        _PAS_IMPL_HEADER_RE,
        _PAS_KEYWORDS,
        _PAS_METHOD_DECL_RE,
        _PAS_MODULE_RE,
        _PAS_TOKEN_RE,
        _PAS_TYPE_HEADER_RE,
        _PAS_USES_RE,
        _extract_pascal_regex,
        _pascal_find_body,
        _pascal_split_bases,
        _pascal_split_sections,
        _pascal_split_uses,
        _pascal_strip_comments,
        extract_pascal,
    }
    graphify.extractors.objc --> graphify.extract {
        _objc_category_base_stem,
        _objc_local_var_types,
        extract_objc,
    }
    graphify.extractors.julia --> graphify.extract { extract_julia }
    graphify.detect --> graphify.extract {
        CODE_EXTENSIONS,
        _is_ignored,
        _is_installed_graphify_file,
        _is_noise_dir,
        _load_graphifyignore,
        _resolves_under_root,
        _shebang_interpreter,
    }
    graphify.ids --> graphify.mcp_ingest { make_id }
    graphify.security --> graphify.mcp_ingest { sanitize_label }
    graphify.extractors.base --> graphify.mcp_ingest { _file_stem }
    graphify.build --> graphify.ruby_resolution { _is_file_node_label }
    graphify.ids --> graphify.build { _file_stem, make_id, normalize_id }
    graphify.paths --> graphify.build { GRAPHIFY_OUT, default_graph_json, is_absolute_any_platform }
    graphify.validate --> graphify.build { VALID_CONFIDENCES, validate_extraction }
    graphify.extractors.csharp --> graphify.build {
        bare_csharp_method_label,
        csharp_method_label_reassignments,
    }
    graphify.extractors.base --> graphify.build { _file_stem }
    graphify.extractors.resolution --> graphify.build {
        C_STANDARD_INCLUDE_NAMES,
        _PYTHON_STDLIB_MODULE_NAMES,
    }
    graphify.extract --> graphify.build { _lang_family }
    graphify.dedup --> graphify.build { deduplicate_entities }
    graphify.security --> graphify.build { check_graph_file_size_cap }
    graphify.extractors.models --> graphify.extractors.resolution {
        LanguageConfig,
        _JS_CACHE_BYPASS_SUFFIXES,
        _NamespaceExportFact,
        _StarExportFact,
        _SymbolAliasFact,
        _SymbolDeclarationFact,
        _SymbolExportFact,
        _SymbolImportFact,
        _SymbolResolutionFacts,
        _SymbolUseFact,
        _WORKSPACE_PACKAGE_CACHE,
    }
    graphify.extractors.base --> graphify.extractors.resolution {
        _LANGUAGE_BUILTIN_GLOBALS,
        _file_stem,
        _make_id,
        _read_source_bytes,
        _read_source_text,
        _read_text,
    }
    graphify.extractors.python_scope --> graphify.extractors.resolution {
        _python_param_shadow_checker,
    }
    graphify.ids --> graphify.extractors.resolution { normalize_id }
    graphify.rcfile --> graphify.extractors.resolution { effective_suffix, get_language_overrides }
    graphify.detect --> graphify.extractors.resolution { _find_vcs_root }
    graphify.extract --> graphify.extractors.resolution { _lang_family }
    graphify._minhash --> graphify.dedup { MinHash, MinHashLSH }
    graphify.ids --> graphify.dedup { normalize_id }
    graphify.build --> graphify.dedup { _is_abs, _is_ast_tier }
    graphify.llm --> graphify.dedup {
        BACKENDS,
        _call_llm,
        _format_backend_env_keys,
        _get_backend_api_key,
    }
    graphify.extractors.base --> graphify.llm { _read_source_text }
    graphify.file_slice --> graphify.llm {
        FileSlice,
        bisect_slice,
        expand_oversized_files,
        is_complete_slice_coverage,
        make_full_slice,
        read_slice_text,
        unit_path,
    }
    graphify.detect --> graphify.llm { extract_pdf_text }
    graphify.build --> graphify.llm { _coerce_hyperedge_member_refs }
    graphify.cache --> graphify.llm { save_semantic_cache }
    graphify.extractors.base --> graphify.markdown_resolution {
        _LANGUAGE_BUILTIN_GLOBALS,
        active_scan_root,
    }
    graphify.extractors.base --> graphify.extractors.engine {
        _LANGUAGE_BUILTIN_GLOBALS,
        _file_stem,
        _make_id,
        _read_source_bytes,
        _read_text,
    }
    graphify.ids --> graphify.extractors.engine { DeclIdRegistry, normalize_id }
    graphify.extractors.models --> graphify.extractors.engine { LanguageConfig }
    graphify.extractors.python_scope --> graphify.extractors.engine {
        _python_param_names,
        _python_param_shadow_checker,
    }
    graphify.extractors.resolution --> graphify.extractors.engine { _resolve_js_import_target }
    graphify.security --> graphify.extractors.engine { sanitize_metadata }
    graphify.extractors.base --> graphify.extractors.apex {
        _file_stem,
        _make_id,
        _read_source_text,
    }
    graphify.extractors.base --> graphify.extractors.bash {
        _file_stem,
        _make_id,
        _read_source_bytes,
        _read_text,
        active_scan_root,
    }
    graphify.security --> graphify.extractors.bash { sanitize_metadata }
    graphify.extractors.base --> graphify.extractors.cobol { _make_id, _read_source_text }
    graphify.extractors.base --> graphify.extractors.dart {
        _file_stem,
        _make_id,
        _read_source_text,
    }
    graphify.extractors.engine --> graphify.extractors.dart { _underscore_salted_nid }
    graphify.ids --> graphify.extractors.dart { normalize_id }
    graphify.extractors.base --> graphify.extractors.dm {
        _file_stem,
        _make_id,
        _read_source_bytes,
        _read_source_text,
        _read_text,
    }
    graphify.extractors.base --> graphify.extractors.elixir {
        _LANGUAGE_BUILTIN_GLOBALS,
        _file_stem,
        _make_id,
        _read_source_bytes,
    }
    graphify.extractors.engine --> graphify.extractors.elixir { _underscore_salted_nid }
    graphify.ids --> graphify.extractors.elixir { normalize_id }
    graphify.extractors.base --> graphify.extractors.erlang {
        _file_stem,
        _make_id,
        _read_source_bytes,
        _read_text,
    }
    graphify.extractors.base --> graphify.extractors.fortran {
        _file_stem,
        _make_id,
        _read_source_bytes,
        _read_text,
    }
    graphify.ids --> graphify.extractors.go { DeclIdRegistry }
    graphify.extractors.base --> graphify.extractors.go {
        _LANGUAGE_BUILTIN_GLOBALS,
        _file_stem,
        _make_id,
        _read_source_bytes,
        _read_text,
    }
    graphify.extractors.resolution --> graphify.extractors.go { _go_import_path_for_file }
    graphify.extractors.base --> graphify.extractors.json_config {
        _file_stem,
        _make_id,
        _read_text,
    }
    graphify.extractors.resolution --> graphify.extractors.json_config {
        _read_json_config,
        _resolve_js_module_path,
    }
    graphify.ids --> graphify.extractors.json_config { normalize_id }
    graphify.extractors.base --> graphify.extractors.yaml_config { _file_stem, _make_id }
    graphify.ids --> graphify.extractors.yaml_config { normalize_id }
    graphify.extractors.base --> graphify.extractors.commonlisp {
        _file_stem,
        _make_id,
        _read_source_bytes,
    }
    graphify.security --> graphify.extractors.commonlisp { redact_secrets }
    graphify.detect --> graphify.extractors.markdown {
        CODE_EXTENSIONS,
        DOC_EXTENSIONS,
        _SKIP_DIRS,
        classify_file,
        ignored_predicate,
    }
    graphify.extractors.base --> graphify.extractors.markdown {
        _file_stem,
        _make_id,
        _read_source_text,
        active_scan_root,
    }
    graphify.security --> graphify.extractors.markdown { sanitize_metadata }
    graphify.extractors.base --> graphify.extractors.ocaml {
        _file_stem,
        _make_id,
        _read_source_bytes,
        _read_text,
    }
    graphify.rcfile --> graphify.extractors.ocaml { effective_suffix }
    graphify.extractors.base --> graphify.extractors.pascal_forms {
        _file_stem,
        _make_id,
        _read_source_text,
    }
    graphify.extractors.base --> graphify.extractors.powershell {
        _file_stem,
        _make_id,
        _read_source_bytes,
        _read_text,
    }
    graphify.extractors.base --> graphify.extractors.r {
        _file_stem,
        _make_id,
        _read_source_bytes,
        _read_text,
    }
    graphify.extractors.base --> graphify.extractors.razor {
        _file_stem,
        _make_id,
        _read_source_text,
    }
    graphify.security --> graphify.extractors.razor { sanitize_metadata }
    graphify.extractors.base --> graphify.extractors.robot { _file_stem, _make_id }
    graphify.rcfile --> graphify.extractors.robot { effective_suffix }
    graphify.ids --> graphify.extractors.rust { DeclIdRegistry }
    graphify.extractors.base --> graphify.extractors.rust {
        _LANGUAGE_BUILTIN_GLOBALS,
        _file_stem,
        _make_id,
        _read_source_bytes,
        _read_text,
    }
    graphify.extractors.base --> graphify.extractors.solidity {
        _file_stem,
        _make_id,
        _read_source_bytes,
        _read_text,
    }
    graphify.extractors.engine --> graphify.extractors.solidity { _underscore_salted_nid }
    graphify.extractors.base --> graphify.extractors.sql {
        _file_stem,
        _make_id,
        _read_source_bytes,
    }
    graphify.extractors.base --> graphify.extractors.verilog {
        _file_stem,
        _make_id,
        _read_source_bytes,
        _read_text,
    }
    graphify.extractors.base --> graphify.extractors.vbnet {
        _file_stem,
        _make_id,
        _read_source_bytes,
        _read_text,
    }
    graphify.extractors.base --> graphify.extractors.zig {
        _file_stem,
        _make_id,
        _read_source_bytes,
        _read_text,
    }
    graphify.extractors.base --> graphify.symbol_resolution { _file_stem, _read_source_text }
    graphify.ids --> graphify.symbol_resolution { make_id }
    graphify.paths --> graphify.symbol_resolution { disambiguate_ambiguous_candidates }
    graphify.security --> graphify.symbol_resolution { sanitize_metadata }
    graphify.rcfile --> graphify.symbol_resolution { effective_suffix }
    graphify.extractors.base --> graphify.extractors.pascal {
        _file_stem,
        _make_id,
        _read_source_bytes,
        _read_source_text,
    }
    graphify.extractors.resolution --> graphify.extractors.pascal {
        _pascal_resolve_class,
        _pascal_resolve_unit,
    }
    graphify.extractors.base --> graphify.extractors.objc {
        _file_stem,
        _make_id,
        _read_source_bytes,
        _read_text,
    }
    graphify.extractors.engine --> graphify.extractors.objc {
        _cpp_declarator_name,
        _semantic_reference_edge,
        _underscore_salted_nid,
    }
    graphify.extractors.resolution --> graphify.extractors.objc { _resolve_c_include_path }
    graphify.security --> graphify.extractors.objc { sanitize_metadata }
    graphify.ids --> graphify.extractors.julia { DeclIdRegistry }
    graphify.extractors.base --> graphify.extractors.julia {
        _file_stem,
        _make_id,
        _read_source_bytes,
        _read_text,
    }
    graphify.extractors.engine --> graphify.extractors.julia { _semantic_reference_edge }
    graphify.security --> graphify.export { check_graph_file_size_cap, sanitize_label }
    graphify.analyze --> graphify.export { _node_community_map }
    graphify.build --> graphify.export {
        _dedup_shrink_allowance,
        _lost_saved_semantic_nodes,
        edge_datas,
        has_parallel_links,
        take_dedup_remap,
        take_shrink_accounting,
    }
    graphify.paths --> graphify.export {
        os_replace_with_fallback,
        stem_filename_budget,
        write_json_atomic,
        write_text_atomic,
        write_text_atomic_if_changed,
    }
    graphify.exporters.graphdb --> graphify.export { push_to_falkordb, push_to_neo4j }
    graphify.exporters.base --> graphify.export { COMMUNITY_COLORS }
    graphify.exporters.html --> graphify.export { to_html }
    graphify.build --> graphify.analyze { _is_ast_tier, _is_file_node_label, edge_datas }
    graphify.extractors.csharp --> graphify.analyze { bare_csharp_method_label }
    graphify.detect --> graphify.analyze {
        CODE_EXTENSIONS,
        DOC_EXTENSIONS,
        IMAGE_EXTENSIONS,
        PAPER_EXTENSIONS,
    }
    graphify.cluster --> graphify.analyze { cohesion_score }
    graphify.analyze --> graphify.exporters.graphdb { _node_community_map }
    graphify.exporters.base --> graphify.exporters.html { COMMUNITY_COLORS }
    graphify.analyze --> graphify.exporters.html { _node_community_map }
    graphify.paths --> graphify.exporters.html { GRAPHIFY_OUT_NAME, write_text_atomic }
    graphify.security --> graphify.exporters.html { sanitize_label }
    graphify.reflect --> graphify.exporters.html { load_learning_overlay }
    graphify.paths --> graphify.prs { default_graph_json }
    graphify.security --> graphify.prs { check_graph_file_size_cap }
    graphify.llm --> graphify.prs { BACKENDS, _default_model_for_backend, _get_backend_api_key }
    graphify.paths --> graphify.serve;
    graphify.paths --> graphify.serve {
        _is_test_path,
        consumed,
        default_graph_json,
        read_graph_json,
    }
    graphify.security --> graphify.serve {
        _CONTROL_CHAR_RE,
        check_graph_file_size_cap,
        sanitize_label,
    }
    graphify.build --> graphify.serve {
        _CONFIDENCE_RANK,
        edge_datas,
        edge_evidence,
        graph_has_legacy_ids,
        has_parallel_links,
        legacy_id_source_prefix,
    }
    graphify.reflect --> graphify.serve { load_learning_overlay }
    graphify.affected --> graphify.serve { resolve_seed }
    graphify.querylog --> graphify.serve;
    graphify.sections --> graphify.serve {
        DEFAULT_MAX_CHARS,
        format_section,
        is_section_node,
        read_section,
        resolve_section_query,
        section_root,
    }
    graphify.analyze --> graphify.serve { god_nodes, suggest_questions, surprising_connections }
    graphify.export --> graphify.serve { _git_head }
    graphify.prs --> graphify.serve {
        _STATUS_ORDER,
        _detect_default_branch,
        _gh,
        _parse_ci,
        compute_pr_impact,
        fetch_pr_files,
        fetch_prs,
        fetch_worktrees,
        format_prs_text,
    }
    graphify.build --> graphify.affected { _is_file_node_label }
    graphify.serve --> graphify.affected { _find_node_tiers, find_node_ambiguity }
    graphify.paths --> graphify.affected { consumed, read_graph_json }
    graphify.extractors.base --> graphify.sections { _read_source_text }
    graphify.extractors.markdown --> graphify.sections {
        _MD_ATX_CLOSING_RE,
        _MD_ATX_HEADING_RE,
        _fence_closes,
        _fence_open,
        _split_frontmatter,
    }
    graphify.security --> graphify.sections { redact_secrets, sanitize_label }
    graphify.paths --> graphify.sections { GRAPHIFY_OUT, graph_root_for }
    graphify.serve --> graphify.sections { _resolve_single_node }
    graphify.build --> graphify.diagnostics { build_from_json }
    graphify.security --> graphify.diagnostics { check_graph_file_size_cap }
    graphify.paths --> graphify.watch {
        GRAPHIFY_OUT,
        is_absolute_any_platform,
        load_node_link_graph,
        nfc,
        os_long_path,
        os_replace_with_fallback,
        write_text_atomic,
    }
    graphify.detect --> graphify.watch {
        CODE_EXTENSIONS,
        DOC_EXTENSIONS,
        IMAGE_EXTENSIONS,
        PAPER_EXTENSIONS,
        _is_ignored,
        _load_graphifyignore,
        classify_manifest_deletions,
        classify_manifest_files,
        detect,
        ignored_predicate,
        is_resolution_input,
        load_manifest,
        save_manifest,
    }
    graphify.rcfile --> graphify.watch {
        RC_FILENAME,
        activate_language_overrides,
        effective_suffix,
        set_language_overrides,
    }
    graphify.build --> graphify.watch {
        _backfill_origin,
        _has_independent_semantic_evidence,
        _is_ast_tier,
        _is_external_stub,
        _load_existing_graph,
        _lost_saved_semantic_nodes,
        _norm_source_file,
        build_from_json,
        dedupe_edges,
        dedupe_nodes,
        disambiguate_file_labels_in_nodes,
        finalize_raw_graph_endpoints,
        has_parallel_links,
        qualify_csharp_method_labels_in_nodes,
    }
    graphify.extract --> graphify.watch {
        RUN_ONLY_EXTRACTION_KEYS,
        _file_node_id,
        _get_extractor,
        _safe_extract_with_xaml_root,
        extract,
    }
    graphify.extractors.base --> graphify.watch { _make_id }
    graphify.extractors.markdown --> graphify.watch { extract_markdown }
    graphify.markdown_resolution --> graphify.watch { MARKDOWN_MENTION_SUFFIXES, _is_file_node }
    graphify.dedup --> graphify.watch { _namespace_reference_stub_collisions }
    graphify.cache --> graphify.watch {
        _AST_CACHE_SCHEMA,
        _EXTRACTOR_VERSION,
        _grammar_fingerprint,
    }
    graphify.exporters.html --> graphify.watch { _HTML_STALE_MARKER, _viz_node_limit }
    graphify.export --> graphify.watch { backup_if_protected, to_html, to_json }
    graphify.cluster --> graphify.watch {
        cluster,
        community_member_sigs,
        label_communities_by_hub,
        label_still_applies,
        remap_communities_to_previous,
        score_all,
    }
    graphify.analyze --> graphify.watch { god_nodes, suggest_questions, surprising_connections }
    graphify.report --> graphify.watch {
        generate,
        load_learning_for_report,
        load_report_token_cost,
    }
    graphify.security --> graphify.watch { check_graph_file_size_cap }
    graphify.extractors.terraform --> graphify.watch { refresh_terraform_paths }
    graphify.extractors.resolution --> graphify.watch { _cpp_reconciliation_paths }
    graphify.callflow_html --> graphify.watch { write_callflow_html }
    graphify.export --> graphify.report { _obsidian_safe_stem }
    graphify.reflect --> graphify.report {
        aggregate_lessons,
        load_learning_overlay,
        load_memory_docs,
    }
    graphify.analyze --> graphify.report {
        _is_concept_node,
        _is_contains_only_ast_node,
        _is_file_node,
        find_import_cycles,
    }
    graphify.build --> graphify.tree_html { _is_file_node_label }
    graphify.security --> graphify.tree_html { check_graph_file_size_cap }
    graphify.serve --> graphify.benchmark { _query_graph_text, _read_graph }
    graphify.paths --> graphify.benchmark { default_graph_json }
    graphify.paths --> graphify.global_graph { restore_arc_direction, write_json_atomic }
    graphify.security --> graphify.global_graph { check_graph_file_size_cap }
    graphify.build --> graphify.global_graph { prefix_graph_for_global, prune_repo_from_graph }
    graphify.cross_repo_calls --> graphify.global_graph { link_cross_repo_member_calls }
    graphify.extract --> graphify.pg_introspect { extract_sql }
    graphify.build --> graphify.semantic_cleanup { _normalize_hyperedge_members }
    graphify.extractors.apex --> graphify.extractors { extract_apex }
    graphify.extractors.bash --> graphify.extractors { extract_bash }
    graphify.extractors.blade --> graphify.extractors { extract_blade }
    graphify.extractors.cobol --> graphify.extractors { extract_cobol }
    graphify.extractors.commonlisp --> graphify.extractors { extract_commonlisp }
    graphify.extractors.dart --> graphify.extractors { extract_dart }
    graphify.extractors.dm --> graphify.extractors {
        extract_dm,
        extract_dmf,
        extract_dmi,
        extract_dmm,
    }
    graphify.extractors.elixir --> graphify.extractors { extract_elixir }
    graphify.extractors.erlang --> graphify.extractors { extract_erlang }
    graphify.extractors.fortran --> graphify.extractors { extract_fortran }
    graphify.extractors.go --> graphify.extractors { extract_go }
    graphify.extractors.json_config --> graphify.extractors { extract_json }
    graphify.extractors.julia --> graphify.extractors { extract_julia }
    graphify.extractors.markdown --> graphify.extractors { extract_markdown }
    graphify.extractors.objc --> graphify.extractors { extract_objc }
    graphify.extractors.pascal --> graphify.extractors { extract_pascal }
    graphify.extractors.pascal_forms --> graphify.extractors {
        extract_delphi_form,
        extract_lazarus_form,
    }
    graphify.extractors.powershell --> graphify.extractors {
        extract_powershell,
        extract_powershell_manifest,
    }
    graphify.extractors.r --> graphify.extractors { extract_r }
    graphify.extractors.razor --> graphify.extractors { extract_razor }
    graphify.extractors.rust --> graphify.extractors { extract_rust }
    graphify.extractors.sln --> graphify.extractors { extract_sln }
    graphify.extractors.solidity --> graphify.extractors { extract_solidity }
    graphify.extractors.sql --> graphify.extractors { extract_sql }
    graphify.extractors.terraform --> graphify.extractors { extract_terraform }
    graphify.extractors.verilog --> graphify.extractors { extract_verilog }
    graphify.extractors.vbnet --> graphify.extractors { extract_vbnet }
    graphify.extractors.zig --> graphify.extractors { extract_zig }
    graphify.extract --> tests.bench_extract { collect_files, extract }
    graphify.cache --> tests.bench_extract { clear_cache }
    graphify.serve --> tests.bench_query_scoring {
        _get_trigram_index,
        _pick_seeds,
        _query_terms,
        _score_nodes,
        _score_query,
        _search_tokens,
    }
    graphify.llm --> tests.conftest { backend_detection_env_vars }
    graphify.cache --> tests.conftest;
    graphify.resolver_registry --> tests.csharp_extension_harness;
    graphify.extract --> tests.csharp_extension_harness {
        _CSHARP_BCL_MEMBER_NAMES,
        extract,
        extract_csharp,
    }
    graphify.extractors.csharp --> tests.csharp_extension_harness { CsharpNameResolver }
    graphify.affected --> tests.test_4874_jvm_resolution { affected_nodes, resolve_seed }
    graphify.build --> tests.test_4874_jvm_resolution { build_from_json }
    graphify.extract --> tests.test_4874_jvm_resolution { extract }
    graphify.extractors.resolution --> tests.test_4909_reference_binding_scale;
    graphify.extractors.base --> tests.test_4909_reference_binding_scale { _make_id }
    graphify.extractors.models --> tests.test_4909_reference_binding_scale {
        _SymbolImportFact,
        _SymbolResolutionFacts,
    }
    graphify.extract --> tests.test_4978_reconcile_cost;
    graphify.build --> tests.test_4978_reconcile_cost { _backfill_origin }
    graphify.watch --> tests.test_4978_reconcile_cost { _rebuild_code }
    graphify.extract --> tests.test_4992_ts_import_types { extract_js }
    graphify.llm --> tests.test_5072_splittable_under_cap_retry;
    graphify.file_slice --> tests.test_5072_splittable_under_cap_retry {
        FileSlice,
        is_splittable_text,
        read_slice_text,
        unit_source_text,
    }
    graphify.__main__ --> tests.test_affected_cli;
    graphify.affected --> tests.test_affected_cli { resolve_seed }
    graphify.paths --> tests.test_affected_cli { GRAPHIFY_OUT_NAME }
    graphify.cli --> tests.test_affected_cli { EXIT_NOT_FOUND }
    graphify.affected --> tests.test_affected_defines {
        DEFAULT_AFFECTED_RELATIONS,
        affected_nodes,
        resolve_seed,
    }
    graphify.affected --> tests.test_affected_member_seed { affected_nodes }
    graphify.affected --> tests.test_affected_overrides { affected_nodes, load_graph }
    graphify.extract --> tests.test_affected_overrides { extract }
    graphify.affected --> tests.test_affected_path_file_node { load_graph, resolve_seed }
    graphify.__main__ --> tests.test_affected_seed_reference_forms;
    graphify.affected --> tests.test_affected_seed_reference_forms {
        resolve_seed,
        resolve_seed_outcome,
    }
    graphify.paths --> tests.test_affected_seed_reference_forms { GRAPHIFY_OUT_NAME }
    graphify.cli --> tests.test_affected_seed_reference_forms { EXIT_AMBIGUOUS, EXIT_NOT_FOUND }
    graphify.affected --> tests.test_affected_undirected_incident { affected_nodes }
    graphify.__main__ --> tests.test_agents_platform;
    graphify.build --> tests.test_alias_folding {
        _fold_confidence,
        _fold_edge_aliases,
        _fold_node_aliases,
        build_from_json,
    }
    graphify.build --> tests.test_analyze { build_from_json }
    graphify.cluster --> tests.test_analyze { cluster }
    graphify.analyze --> tests.test_analyze {
        _betweenness_centrality,
        _file_category,
        _is_concept_node,
        _is_json_key_node,
        _surprise_score,
        find_import_cycles,
        god_nodes,
        graph_diff,
        suggest_questions,
        surprising_connections,
    }
    graphify.extract --> tests.test_analyze { _make_id }
    graphify.llm --> tests.test_anthropic_custom_endpoint;
    graphify.__main__ --> tests.test_antigravity_install;
    graphify.manifest_ingest --> tests.test_apm_fallback_version { _parse_apm_fallback }
    graphify.extract --> tests.test_architecture_doc { extract }
    graphify.detect --> tests.test_astro_extraction { CODE_EXTENSIONS }
    graphify.extract --> tests.test_astro_extraction {
        _astro_mask_non_script,
        _make_id,
        extract_astro,
    }
    graphify.extract --> tests.test_astro_import_ids { _file_node_id, _make_id, extract }
    graphify.export --> tests.test_atomic_canvas_export { to_canvas, to_obsidian }
    graphify.install --> tests.test_atomic_version_stamp;
    graphify.paths --> tests.test_atomic_writes {
        _WINDOWS_MAX_PATH,
        _atomic_replace,
        os_replace_with_fallback,
        write_json_atomic,
        write_text_atomic,
    }
    graphify.export --> tests.test_atomic_writes { to_json }
    graphify.detect --> tests.test_atomic_writes { save_manifest }
    graphify.llm --> tests.test_backend_env_isolation;
    graphify.llm --> tests.test_backend_extras { _backend_pkg_hint }
    graphify.llm --> tests.test_backend_opt_in;
    graphify.benchmark --> tests.test_benchmark {
        _SAMPLE_QUESTIONS,
        _hr,
        _query_subgraph_tokens,
        _safe,
        print_benchmark,
        run_benchmark,
    }
    graphify.benchmark --> tests.test_benchmark_raw_graph { run_benchmark }
    graphify.benchmark --> tests.test_benchmark_real_query {
        _estimate_tokens,
        _query_subgraph_tokens,
        run_benchmark,
    }
    graphify.serve --> tests.test_benchmark_real_query {
        _load_graph,
        _query_graph_text,
        _read_graph,
    }
    graphify.cache --> tests.test_binary_media_words;
    graphify.detect --> tests.test_binary_media_words;
    graphify.extract --> tests.test_blade_extractor { extract }
    graphify.build --> tests.test_build;
    graphify.build --> tests.test_build {
        _EDGE_LANG_FAMILY,
        _derive_prune_root,
        _is_ast_tier,
        _norm_source_file,
        _semantic_id_remap,
        build,
        build_from_json,
        build_merge,
        dedupe_edges,
        dedupe_nodes,
        edge_data,
        edge_datas,
        graph_has_legacy_ids,
        has_parallel_links,
        legacy_id_source_prefix,
        merge_raw_extraction,
    }
    graphify.cluster --> tests.test_build { cluster }
    graphify.validate --> tests.test_build { validate_extraction }
    graphify.export --> tests.test_build { to_json }
    graphify.ids --> tests.test_build { make_id }
    graphify.extract --> tests.test_build { _LANG_FAMILY_BY_EXT, extract, extract_js }
    graphify.watch --> tests.test_build { _rebuild_code }
    graphify.build --> tests.test_build_located_semantic_identity {
        build,
        build_from_json,
        build_merge,
    }
    graphify.build --> tests.test_build_merge_dedup_scope;
    graphify.build --> tests.test_build_merge_dedup_scope { build, build_merge }
    graphify.dedup --> tests.test_build_merge_dedup_scope { deduplicate_entities }
    graphify.build --> tests.test_build_merge_ghost_fold_4955 { build_merge }
    graphify.export --> tests.test_build_merge_ghost_fold_4955 { to_json }
    graphify.build --> tests.test_build_merge_hyperedges_and_prune {
        _infer_merge_root,
        build_merge,
        merge_raw_extraction,
    }
    graphify.export --> tests.test_build_merge_hyperedges_and_prune { to_json }
    graphify.build --> tests.test_build_merge_shrink_guard;
    graphify.build --> tests.test_build_merge_shrink_guard { build_merge, merge_raw_extraction }
    graphify.extract --> tests.test_builtin_global_type_refs { extract }
    graphify.extract --> tests.test_c_include_resolution { extract }
    graphify.build --> tests.test_c_include_resolution { build }
    graphify.extract --> tests.test_c_struct_callback_calls { extract }
    graphify.cache --> tests.test_cache;
    graphify.cache --> tests.test_cache {
        _GRAPHIFY_OUT,
        _body_content,
        cache_dir,
        cached_files,
        check_semantic_cache,
        clear_cache,
        file_hash,
        load_cached,
        mark_semantic_cache_partial,
        prompt_fingerprint,
        prune_semantic_cache,
        save_cached,
        save_semantic_cache,
        scope_semantic_result,
    }
    graphify.extract --> tests.test_cache;
    graphify.extract --> tests.test_cache { _make_id, extract }
    graphify.cache --> tests.test_cache_long_paths { cache_dir, load_cached, save_cached }
    graphify.paths --> tests.test_cache_long_paths { _WINDOWS_MAX_PATH }
    graphify.cache --> tests.test_cache_stale_import_target { load_cached, save_cached }
    graphify.watch --> tests.test_cache_stale_import_target { _rebuild_code }
    graphify.cache --> tests.test_cache_windows_case_4925;
    graphify.callflow_html --> tests.test_callflow_html {
        derive_sections_from_communities,
        generate_call_table_rows,
        load_graph,
        write_callflow_html,
    }
    graphify.cargo_introspect --> tests.test_cargo_introspect { introspect_cargo }
    graphify.build --> tests.test_carried_hyperedge_remap { build_from_json, build_merge }
    graphify.export --> tests.test_carried_hyperedge_remap { to_json }
    graphify.extract --> tests.test_case_only_decl_ids_4904 { extract }
    graphify.ids --> tests.test_case_only_decl_ids_4904 { DeclIdRegistry }
    graphify.extract --> tests.test_case_sensitive_resolution { extract }
    graphify.llm --> tests.test_charmap_encoding;
    graphify.llm --> tests.test_chunking;
    graphify.llm --> tests.test_chunking {
        _FILE_CHAR_CAP,
        _extract_with_adaptive_retry,
        _extraction_system,
        _pack_chunks_by_tokens,
        expand_oversized_files,
        extract_corpus_parallel,
    }
    graphify.cache --> tests.test_chunking {
        load_cached,
        save_semantic_cache,
        scope_semantic_result,
    }
    graphify.build --> tests.test_chunking { build, build_merge }
    graphify.export --> tests.test_chunking { to_json }
    graphify.file_slice --> tests.test_chunking { FileSlice }
    graphify.detect --> tests.test_cjs_module_extension { CODE_EXTENSIONS }
    graphify.extract --> tests.test_cjs_module_extension {
        _DISPATCH,
        _JS_CACHE_BYPASS_SUFFIXES,
        _JS_RESOLVE_EXTS,
        extract_js,
    }
    graphify.analyze --> tests.test_cjs_module_extension { _LANG_FAMILY }
    graphify.cli --> tests.test_cjs_module_extension { _HOOK_SOURCE_EXTS }
    graphify.llm --> tests.test_claude_cli_backend;
    graphify.__main__ --> tests.test_claude_md {
        _CLAUDE_MD_MARKER,
        _CLAUDE_MD_SECTION,
        claude_install,
        claude_uninstall,
    }
    graphify.install --> tests.test_claude_md { _SKILL_REGISTRATION_MARKER, _project_install }
    graphify.build --> tests.test_cli_export { build_from_json }
    graphify.cluster --> tests.test_cli_export { cluster, score_all }
    graphify.analyze --> tests.test_cli_export { god_nodes, surprising_connections }
    graphify.export --> tests.test_cli_export;
    graphify.export --> tests.test_cli_export { to_json, to_obsidian }
    graphify.cli --> tests.test_cli_export { dispatch_command }
    graphify.install --> tests.test_cli_help { _PLATFORM_CONFIG }
    graphify.cli --> tests.test_cloud_cta;
    graphify.build --> tests.test_cluster { build_from_json }
    graphify.cluster --> tests.test_cluster;
    graphify.cluster --> tests.test_cluster {
        _partition,
        cluster,
        cohesion_score,
        remap_communities_to_previous,
        score_all,
    }
    graphify.cluster --> tests.test_cluster_ambiguous_scale { cluster }
    graphify.cluster --> tests.test_cluster_exclude_hubs { cluster }
    graphify.extract --> tests.test_cobol_extractor { extract }
    graphify.watch --> tests.test_code_only_scope_4923 { _current_build_state, _rebuild_code }
    tools.skillgen.gen --> tests.test_code_only_update_all_hosts;
    graphify.__main__ --> tests.test_codebuddy {
        _CODEBUDDY_MD_MARKER,
        _PLATFORM_CONFIG,
        _platform_skill_destination,
        codebuddy_install,
        codebuddy_uninstall,
        install,
        main,
    }
    graphify --> tests.test_codebuddy;
    graphify.cluster --> tests.test_community_hub_labels {
        community_member_sigs,
        label_communities_by_hub,
    }
    graphify.export --> tests.test_community_labels_skill { to_json }
    graphify.watch --> tests.test_compact_graph_json { _rebuild_code }
    graphify.export --> tests.test_compact_graph_json { to_json }
    graphify.cli --> tests.test_compact_graph_json { _prune_graph_json_sources }
    graphify.global_graph --> tests.test_compact_graph_json;
    graphify.build --> tests.test_confidence { build_from_json }
    graphify.cluster --> tests.test_confidence { cluster, score_all }
    graphify.analyze --> tests.test_confidence { god_nodes, surprising_connections }
    graphify.export --> tests.test_confidence { to_json }
    graphify.report --> tests.test_confidence { generate }
    graphify.__main__ --> tests.test_confidence_score_output;
    graphify.build --> tests.test_confidence_score_output { build_from_json }
    graphify.export --> tests.test_confidence_score_output { to_json }
    graphify.extract --> tests.test_confidence_score_output { extract }
    graphify.serve --> tests.test_confidence_score_output {
        _confidence_tag,
        _neighbor_lines,
        _shortest_path_text,
    }
    graphify.build --> tests.test_corrupt_graph_json { build_merge }
    graphify.affected --> tests.test_corrupt_graph_json { load_graph }
    graphify.diagnostics --> tests.test_corrupt_graph_json { _read_json_file }
    graphify.extract --> tests.test_cpp_alias_member_resolution { extract, extract_cpp }
    graphify.extract --> tests.test_cpp_anonymous_namespace_receivers { extract }
    graphify.extract --> tests.test_cpp_conditional_initializers;
    graphify.build --> tests.test_cpp_forward_declarations { build_from_json, build_merge }
    graphify.export --> tests.test_cpp_forward_declarations { to_json }
    graphify.extract --> tests.test_cpp_forward_declarations { extract }
    graphify.extractors.resolution --> tests.test_cpp_forward_declarations {
        _cpp_include_path,
        _cpp_reconciliation_paths,
        _merge_cpp_forward_classes,
    }
    graphify.watch --> tests.test_cpp_forward_declarations {
        _rebase_relative_source_files,
        _rebuild_code,
    }
    graphify.extract --> tests.test_cpp_forward_receiver_completion { extract }
    graphify.extract --> tests.test_cpp_incremental_type_resolution;
    graphify.watch --> tests.test_cpp_incremental_type_resolution { _rebuild_code }
    graphify.extract --> tests.test_cpp_inherited_member_resolution {
        _resolve_cpp_member_calls,
        extract,
        extract_cpp,
    }
    graphify.cache --> tests.test_cpp_inherited_member_resolution;
    graphify.cpp_resolution --> tests.test_cpp_inherited_member_resolution { CppTypeLookup }
    graphify.extract --> tests.test_cpp_local_callable_shadowing { extract }
    graphify.extract --> tests.test_cpp_member_call_by_receiver_type { extract }
    graphify.build --> tests.test_cpp_member_declaration_identity { build_from_json }
    graphify.export --> tests.test_cpp_member_declaration_identity { to_json }
    graphify.extract --> tests.test_cpp_member_declaration_identity { extract }
    graphify.watch --> tests.test_cpp_member_declaration_identity { _rebuild_code }
    graphify.extract --> tests.test_cpp_method_declarations { extract }
    graphify.extract --> tests.test_cpp_nested_and_cli {
        _normalize_cpp_cli,
        _normalize_cpp_export_macros,
        extract_cpp,
    }
    graphify.build --> tests.test_cpp_objc_cross_file_calls { build_from_json }
    graphify.extract --> tests.test_cpp_objc_cross_file_calls { extract }
    graphify.extract --> tests.test_cpp_preprocess;
    graphify.extract --> tests.test_cpp_receiver_chains { extract }
    graphify.cache --> tests.test_cpp_receiver_chains;
    graphify.extract --> tests.test_cpp_receiver_parameters { extract }
    graphify.extract --> tests.test_cpp_split_header_owner { extract }
    graphify.extract --> tests.test_cpp_std_stubs { extract }
    graphify.cache --> tests.test_cpp_template_members { cache_dir }
    graphify.extract --> tests.test_cpp_template_members { extract }
    graphify.extract --> tests.test_cpp_template_type_params { extract }
    graphify.extract --> tests.test_cpp_type_alias { extract }
    graphify.extract --> tests.test_cpp_underscore_ids { extract }
    graphify.build --> tests.test_cross_extension_reexport_self_cycle { build }
    graphify.export --> tests.test_cross_extension_reexport_self_cycle { to_json }
    graphify.extract --> tests.test_cross_extension_reexport_self_cycle { extract }
    graphify.analyze --> tests.test_cross_extension_reexport_self_cycle { find_import_cycles }
    graphify.extract --> tests.test_cross_language_call_resolution { extract }
    graphify.build --> tests.test_cross_repo_external_call_guards { prefix_graph_for_global }
    graphify.cross_repo_calls --> tests.test_cross_repo_external_call_guards {
        CROSS_REPO_CALL_MARKER,
        link_cross_repo_member_calls,
    }
    graphify.extract --> tests.test_cross_repo_external_call_guards { extract }
    graphify.cross_repo_calls --> tests.test_cross_repo_member_calls {
        CROSS_REPO_CALL_MARKER,
        link_cross_repo_member_calls,
    }
    graphify.extract --> tests.test_cross_repo_member_calls { extract }
    graphify.extract --> tests.test_csharp_call_site_generic_args { extract }
    graphify.extract --> tests.test_csharp_contextual_keyword_names;
    graphify.extract --> tests.test_csharp_contextual_keyword_names {
        _escape_csharp_contextual_names,
        extract,
    }
    graphify.cache --> tests.test_csharp_contextual_keyword_names;
    graphify.extract --> tests.test_csharp_delegate_declarations { extract }
    graphify.extract --> tests.test_csharp_directive_encoding { extract }
    graphify.extractors.base --> tests.test_csharp_directive_encoding;
    graphify.cache --> tests.test_csharp_directive_encoding;
    graphify.extract --> tests.test_csharp_enum_members { extract }
    graphify.extract --> tests.test_csharp_explicit_interface { extract }
    graphify.cache --> tests.test_csharp_explicit_interface;
    tests.csharp_extension_harness --> tests.test_csharp_extension_calls {
        FIXTURES,
        STRATEGIES,
        STRATEGY_IDS,
        expected_pairs,
        line_of,
        strategy_bindings,
    }
    graphify.extract --> tests.test_csharp_extension_keyword_types { extract }
    graphify.extract --> tests.test_csharp_extension_metadata { extract, extract_csharp }
    tests.csharp_extension_harness --> tests.test_csharp_extension_resolution {
        FIXTURES,
        corpus,
        expected_pairs,
        graph_bindings,
    }
    graphify.extract --> tests.test_csharp_field_generic_args { extract }
    graphify.extract --> tests.test_csharp_foreach_loop_variable { extract }
    graphify.extract --> tests.test_csharp_generic_callsites { extract }
    graphify.extract --> tests.test_csharp_interface_dispatch { extract }
    graphify.csharp_dispatch --> tests.test_csharp_interface_dispatch {
        _method_label,
        resolve_csharp_interface_dispatch,
    }
    graphify.extract --> tests.test_csharp_member_calls { extract }
    graphify.extract --> tests.test_csharp_member_chain_calls { extract }
    graphify.extract --> tests.test_csharp_member_nodes { extract }
    graphify.extract --> tests.test_csharp_method_owner_labels { extract }
    graphify.extractors.csharp --> tests.test_csharp_method_owner_labels {
        bare_csharp_method_label,
        csharp_method_label_reassignments,
    }
    graphify.watch --> tests.test_csharp_method_owner_labels { _rebuild_code }
    graphify.build --> tests.test_csharp_method_owner_labels {
        build_from_json,
        finalize_raw_graph_endpoints,
    }
    graphify.analyze --> tests.test_csharp_method_owner_labels { _is_file_node }
    graphify.build --> tests.test_csharp_object_creation { build_from_json, edge_data }
    graphify.extract --> tests.test_csharp_object_creation { extract }
    graphify.watch --> tests.test_csharp_object_creation { _rebuild_code }
    graphify.extract --> tests.test_csharp_overloads { extract }
    graphify.extract --> tests.test_csharp_partial_classes {
        _merge_csharp_partial_class_nodes,
        extract,
        extract_csharp,
    }
    graphify.cache --> tests.test_csharp_partial_classes;
    graphify.cache --> tests.test_csharp_partial_classes { save_cached }
    graphify.extract --> tests.test_csharp_receiver_type_names { extract }
    graphify.cache --> tests.test_csharp_receiver_type_names;
    graphify.extract --> tests.test_csharp_static_property_receiver { extract }
    graphify.extract --> tests.test_csharp_tuple_type_refs { extract }
    graphify.extract --> tests.test_csharp_type_resolution { extract }
    graphify.extractors.base --> tests.test_csharp_type_resolution { _file_stem, _make_id }
    graphify.extractors.csharp --> tests.test_csharp_type_resolution { CsharpNameResolver }
    graphify.extract --> tests.test_csharp_underscore_collisions { extract }
    graphify.extract --> tests.test_csharp_var_call_return_type { extract }
    graphify.extract --> tests.test_csharp_verbatim_interpolation {
        _csharp_broken_escape_offsets,
        _normalize_csharp_verbatim_interpolation,
        extract,
    }
    graphify.extract --> tests.test_dart { _file_stem, _make_id, extract_dart }
    graphify.extract --> tests.test_dart_typedef { extract_dart }
    graphify.extract --> tests.test_dart_underscore_ids { extract }
    graphify.dedup --> tests.test_dedup {
        _collision_rank,
        _content_token_swap,
        _defines_id,
        _entropy,
        _id_prefixes,
        _is_variant_pair,
        _lifecycle_penalty,
        _norm,
        _numeric_tokens_differ,
        _reads_as_file_entity,
        _same_word_variant,
        _shingles,
        _short_label_blocked,
        deduplicate_entities,
    }
    graphify.build --> tests.test_dedup { build, build_merge }
    graphify.build --> tests.test_dedup_prefix_derived_words { build }
    graphify.dedup --> tests.test_dedup_prefix_derived_words { deduplicate_entities }
    graphify.extract --> tests.test_dedup_prefix_derived_words { extract }
    graphify.build --> tests.test_dedup_remaps_hyperedges { build }
    graphify.dedup --> tests.test_dedup_remaps_hyperedges { _remap_hyperedge_members }
    graphify.__main__ --> tests.test_dedup_shrink_refuses_force_write;
    graphify.build --> tests.test_dedup_shrink_refuses_force_write { build, build_merge }
    graphify.export --> tests.test_dedup_shrink_refuses_force_write { to_json }
    graphify.dedup --> tests.test_dedup_survivor_richness {
        _content_richness,
        _pick_winner,
        deduplicate_entities,
    }
    graphify.build --> tests.test_definition_file_portability { build_from_json }
    graphify.cache --> tests.test_definition_file_portability {
        _absolutize_source_files_in,
        _relativize_source_files_in,
    }
    graphify.extract --> tests.test_definition_file_portability { extract }
    graphify.extract --> tests.test_delphi_form_resolution { extract }
    graphify.detect --> tests.test_detect;
    graphify.detect --> tests.test_detect {
        FileType,
        _is_ignored,
        _is_sensitive,
        _lexical_relative,
        _load_graphifyignore,
        _looks_absolute,
        _looks_like_paper,
        _match_anchored_ignore_pattern,
        _nfc,
        _shebang_interpreter,
        _to_absolute_from_storage,
        classify_file,
        count_words,
        detect,
        detect_incremental,
        load_manifest,
        save_manifest,
    }
    graphify.extract --> tests.test_detect { collect_files }
    graphify.cache --> tests.test_detect;
    graphify.cache --> tests.test_detect { save_cached }
    graphify.install --> tests.test_detect;
    graphify.install --> tests.test_detect {
        _PLATFORM_CONFIG,
        _copy_skill_file,
        _platform_skill_destination,
    }
    graphify.detect --> tests.test_detect_jinja { DOC_EXTENSIONS }
    graphify.__main__ --> tests.test_devin {
        _PLATFORM_CONFIG,
        _devin_rules_install,
        _devin_rules_uninstall,
        _platform_skill_destination,
        _remove_skill_file,
        install,
        main,
    }
    graphify --> tests.test_devin;
    graphify.build --> tests.test_doc_twin_structure { build_from_json }
    graphify.extract --> tests.test_doc_twin_structure { extract }
    graphify.detect --> tests.test_docx_to_markdown { docx_to_markdown }
    graphify.extract --> tests.test_dotnet {
        _get_extractor,
        _xaml_codebehind_path,
        extract,
        extract_csproj,
        extract_razor,
        extract_sln,
        extract_slnx,
        extract_xaml,
    }
    graphify.detect --> tests.test_dotnet { CODE_EXTENSIONS }
    graphify.diagnostics --> tests.test_duplicate_annotation_edges { diagnose_extraction }
    graphify.extract --> tests.test_duplicate_annotation_edges { extract }
    graphify.__main__ --> tests.test_edge_also_seen;
    graphify.build --> tests.test_edge_also_seen { build_from_json, edge_data }
    graphify.serve --> tests.test_edge_also_seen { _shortest_path_text }
    graphify.extract --> tests.test_edge_also_seen { extract }
    graphify.build --> tests.test_edge_tier_tie_break { build_from_json, build_merge, edge_data }
    graphify.cluster --> tests.test_edge_tier_tie_break { cluster }
    graphify.export --> tests.test_edge_tier_tie_break { to_json }
    graphify.extract --> tests.test_ejs_extractor {
        _DISPATCH,
        _JS_CACHE_BYPASS_SUFFIXES,
        _JS_RESOLVE_EXTS,
        _LANG_FAMILY_BY_EXT,
        _make_id,
        extract,
        extract_ejs,
    }
    graphify.detect --> tests.test_ejs_extractor { CODE_EXTENSIONS }
    graphify.analyze --> tests.test_ejs_extractor { _LANG_FAMILY }
    graphify.cli --> tests.test_ejs_extractor { _HOOK_SOURCE_EXTS }
    graphify.extract --> tests.test_elixir_defdelegate { extract }
    graphify.extract --> tests.test_elixir_import_resolution { extract }
    graphify.watch --> tests.test_elixir_import_resolution { _rebuild_code }
    graphify.extract --> tests.test_elixir_keyword_def_calls { extract }
    graphify.extract --> tests.test_elixir_qualified_calls { extract }
    graphify.watch --> tests.test_elixir_qualified_calls { _rebuild_code }
    graphify.extract --> tests.test_elixir_underscore_ids { extract }
    graphify.extract --> tests.test_elixir_unqualified_call_scope { extract }
    graphify.watch --> tests.test_elixir_unqualified_call_scope { _rebuild_code }
    graphify.extract --> tests.test_erlang_extractor { extract }
    graphify.llm --> tests.test_evidence_binding;
    graphify.file_slice --> tests.test_evidence_binding { FileSlice }
    graphify.validate --> tests.test_evidence_binding { validate_extraction }
    graphify.diagnostics --> tests.test_evidence_binding {
        diagnose_extraction,
        format_diagnostic_report,
    }
    graphify.__main__ --> tests.test_explain_cli;
    graphify.cli --> tests.test_explain_cli { EXIT_AMBIGUOUS }
    graphify.__main__ --> tests.test_explain_same_file_tie;
    graphify.cli --> tests.test_explain_same_file_tie { EXIT_AMBIGUOUS }
    graphify.serve --> tests.test_explain_same_file_tie { _resolve_single_node }
    graphify.build --> tests.test_export { build_from_json }
    graphify.cluster --> tests.test_export { cluster }
    graphify.export --> tests.test_export {
        MALFORMED_GRAPH,
        _obsidian_safe_stem,
        backup_if_protected,
        existing_graph_node_count,
        to_canvas,
        to_cypher,
        to_graphml,
        to_html,
        to_json,
        to_obsidian,
    }
    graphify.exporters.html --> tests.test_export { _html_document_title, _hyperedge_script }
    graphify.build --> tests.test_export_control_characters { build_from_json }
    graphify.export --> tests.test_export_control_characters {
        _obsidian_safe_stem,
        to_cypher,
        to_graphml,
        to_json,
        to_obsidian,
        to_svg,
    }
    graphify.paths --> tests.test_export_direction { load_node_link_graph }
    graphify.watch --> tests.test_export_direction { _reconcile_graph_html }
    graphify.global_graph --> tests.test_export_direction { global_add }
    graphify.paths --> tests.test_export_idempotent_writes { write_text_atomic_if_changed }
    graphify.export --> tests.test_export_idempotent_writes { to_obsidian }
    graphify.wiki --> tests.test_export_idempotent_writes { to_wiki }
    graphify.export --> tests.test_export_path_length;
    graphify.export --> tests.test_export_path_length {
        _obsidian_safe_stem,
        to_canvas,
        to_obsidian,
    }
    graphify.wiki --> tests.test_export_path_length;
    graphify.wiki --> tests.test_export_path_length { _safe_filename, to_wiki }
    graphify.paths --> tests.test_export_path_length {
        _MIN_STEM_BUDGET,
        _WINDOWS_MAX_PATH,
        stem_filename_budget,
    }
    graphify.build --> tests.test_ext_tagged_id_clash { build }
    graphify.extract --> tests.test_ext_tagged_id_clash { extract, extract_js }
    graphify.build --> tests.test_external_stub_endpoints {
        _backfill_origin,
        build_from_json,
        mint_external_stubs_in_data,
        prefix_graph_for_global,
    }
    graphify.watch --> tests.test_external_stub_endpoints { _rebuild_code }
    graphify.build --> tests.test_extract { build_from_json }
    graphify.extract --> tests.test_extract;
    graphify.extract --> tests.test_extract {
        LanguageConfig,
        _DISPATCH,
        _TSX_CONFIG,
        _TS_CONFIG,
        _extract_generic,
        _file_stem,
        _get_extractor,
        _make_id,
        _resolve_python_member_calls,
        _rewire_unique_stub_nodes,
        _semantic_reference_edge,
        collect_files,
        extract,
        extract_bash,
        extract_dart,
        extract_js,
        extract_json,
        extract_markdown,
        extract_objc,
        extract_python,
    }
    graphify.detect --> tests.test_extract { _is_ignored, _is_noise_dir, _load_graphifyignore }
    graphify.extractors.base --> tests.test_extract { _file_stem }
    graphify.ids --> tests.test_extract { make_id }
    graphify.extractors.sql --> tests.test_extract { extract_sql }
    graphify.markdown_resolution --> tests.test_extract { MARKDOWN_MENTION_SUFFIXES }
    graphify.cache --> tests.test_extract;
    graphify.cache --> tests.test_extract { save_cached }
    graphify.affected --> tests.test_extract { resolve_seed }
    graphify.serve --> tests.test_extract { _resolve_single_node }
    graphify.analyze --> tests.test_extract { god_nodes, surprising_connections }
    graphify.cluster --> tests.test_extract { cluster, score_all }
    graphify.report --> tests.test_extract { generate }
    graphify.extract --> tests.test_extract_cache_location;
    graphify.cache --> tests.test_extract_cache_location;
    graphify.cache --> tests.test_extract_cache_location { file_hash, load_cached }
    graphify.__main__ --> tests.test_extract_cli;
    graphify.extract --> tests.test_extract_cli;
    graphify.cli --> tests.test_extract_cli { _stamped_manifest_files }
    graphify.cache --> tests.test_extract_cli {
        check_semantic_cache,
        file_hash,
        save_semantic_cache,
    }
    graphify.detect --> tests.test_extract_cli { save_manifest }
    graphify.__main__ --> tests.test_extract_cost_ledger;
    graphify.export --> tests.test_extract_memory_release;
    graphify.export --> tests.test_extract_memory_release { to_json }
    graphify.paths --> tests.test_extract_path_memo;
    graphify.extract --> tests.test_extract_path_memo { extract }
    graphify.extract --> tests.test_extract_php_closures { extract, extract_php }
    graphify.extract --> tests.test_extraction_spec_ids { _file_stem, _make_id }
    graphify.extractors.base --> tests.test_extractor_scan_root_context;
    graphify.extractors.markdown --> tests.test_extractor_scan_root_context;
    graphify.extract --> tests.test_extractors_registry;
    graphify.extractors --> tests.test_extractors_registry { LANGUAGE_EXTRACTORS }
    graphify.extractors.terraform --> tests.test_extractors_registry { extract_terraform }
    graphify.__main__ --> tests.test_failed_ast_replacement;
    graphify.extract --> tests.test_failed_ast_replacement;
    graphify.build --> tests.test_failed_ast_replacement { build_merge, merge_raw_extraction }
    graphify.build --> tests.test_falkordb_integration { build_from_json }
    graphify.export --> tests.test_falkordb_integration { push_to_falkordb }
    graphify.build --> tests.test_file_id_collision_4854 { build }
    graphify.extract --> tests.test_file_id_collision_4854 { extract }
    graphify.cache --> tests.test_file_id_collision_4854;
    graphify.build --> tests.test_file_label_disambiguation {
        _disambiguate_file_node_labels,
        _file_label_reassignments,
        _is_file_node_label,
        _shortest_unique_suffix,
        build_from_json,
        disambiguate_file_labels_in_nodes,
    }
    graphify.extract --> tests.test_file_label_disambiguation { extract }
    graphify.serve --> tests.test_file_label_disambiguation { _find_node }
    graphify.extract --> tests.test_file_node_id_spec { extract }
    graphify.llm --> tests.test_file_slice;
    graphify.file_slice --> tests.test_file_slice {
        FileSlice,
        bisect_slice,
        expand_oversized_files,
        is_complete_slice_coverage,
        is_splittable_text,
        make_full_slice,
        read_slice_text,
        slice_boundaries,
        unit_path,
    }
    graphify.llm --> tests.test_file_truncation_warning;
    graphify.extract --> tests.test_forwarding_review_findings { extract }
    graphify.extractors.resolution --> tests.test_forwarding_review_findings {
        _apply_symbol_resolution_facts,
        _js_exported_declaration_names,
        _parse_js_tree,
        _walk_js_tree,
    }
    graphify.extractors.models --> tests.test_forwarding_review_findings {
        _SymbolExportFact,
        _SymbolResolutionFacts,
    }
    graphify.extractors.base --> tests.test_forwarding_review_findings { _file_stem, _make_id }
    graphify.export --> tests.test_frontmatter_and_ssrf_hardening { _obsidian_tag }
    graphify.google_workspace --> tests.test_frontmatter_and_ssrf_hardening { _safe_yaml_str }
    graphify.security --> tests.test_frontmatter_and_ssrf_hardening { _ip_is_blocked }
    graphify.__main__ --> tests.test_gemini_hook { _gemini_hook }
    graphify.export --> tests.test_git_head_stdin;
    graphify.watch --> tests.test_git_head_stdin;
    graphify.__main__ --> tests.test_global_add_tag_inference;
    graphify.build --> tests.test_global_add_tag_inference { distinct_repo_tags }
    graphify.global_graph --> tests.test_global_add_tag_inference { global_add }
    graphify.build --> tests.test_global_graph { prefix_graph_for_global, prune_repo_from_graph }
    graphify.global_graph --> tests.test_global_graph {
        _load_global_graph,
        global_add,
        global_list,
        global_remove,
    }
    graphify.dedup --> tests.test_global_graph { deduplicate_entities }
    graphify.global_graph --> tests.test_global_manifest_shape;
    graphify.extract --> tests.test_go_builtin_call_targets { extract }
    graphify.extract --> tests.test_go_field_owner_package { extract }
    graphify.extract --> tests.test_go_generic_receiver_methods { extract }
    graphify.extract --> tests.test_go_generic_type_params { extract }
    graphify.extract --> tests.test_go_import_repoint { extract }
    graphify.extract --> tests.test_go_import_shadowing { extract }
    graphify.extract --> tests.test_go_interface_dispatch { extract }
    graphify.go_dispatch --> tests.test_go_interface_dispatch {
        _MAX_IMPLICIT_IMPLEMENTERS,
        resolve_go_interface_dispatch,
    }
    graphify.extract --> tests.test_go_interface_methods { extract }
    graphify.extract --> tests.test_go_method_value_indirect_calls { extract }
    graphify.extract --> tests.test_go_package_type_fold { extract }
    graphify.extract --> tests.test_go_package_var_calls { extract }
    graphify.extract --> tests.test_go_package_var_type_refs { extract }
    graphify.extract --> tests.test_go_qualified_resolution { extract }
    graphify.build --> tests.test_go_qualified_resolution { build_from_json, build_merge }
    graphify.export --> tests.test_go_qualified_resolution { to_json }
    graphify.extract --> tests.test_go_receiver_member_calls { extract }
    graphify.watch --> tests.test_go_receiver_member_calls { _rebuild_code }
    graphify.extract --> tests.test_go_same_file_receiver_calls { extract }
    graphify.extract --> tests.test_go_same_name_receiver_across_packages { extract }
    graphify.extract --> tests.test_go_sibling_receiver_with_outside_reference { extract }
    graphify.extract --> tests.test_go_type_alias { extract }
    graphify.extractors.go --> tests.test_go_type_alias { extract_go }
    graphify.__main__ --> tests.test_god_nodes_cli;
    graphify.analyze --> tests.test_god_nodes_exclude_hubs { god_nodes }
    graphify.__main__ --> tests.test_god_nodes_exclude_hubs;
    graphify.export --> tests.test_god_nodes_exclude_hubs { to_json }
    graphify.google_workspace --> tests.test_google_workspace;
    graphify.cache --> tests.test_grammar_cache_key;
    graphify.serve --> tests.test_graph_context_cache_reload { _GraphContextCache }
    graphify.exporters.graphdb --> tests.test_graphdb_push_indexes {
        _distinct_node_labels,
        push_to_falkordb,
        push_to_neo4j,
    }
    graphify.build --> tests.test_header_import_collision { build }
    graphify.extract --> tests.test_header_import_collision { extract }
    graphify.extractors.resolution --> tests.test_header_import_collision {
        _disambiguate_colliding_node_ids,
    }
    graphify.__main__ --> tests.test_hollow_chunks_arm_shrink_guard;
    graphify.__main__ --> tests.test_home_sandbox { claude_uninstall }
    graphify.hooks --> tests.test_hook_chain_survives_skip {
        _CHECKOUT_MARKER_END,
        _HOOK_MARKER_END,
        install,
    }
    graphify.install --> tests.test_hook_compact;
    graphify.cli --> tests.test_hook_compact;
    graphify.paths --> tests.test_hook_content_freshness;
    graphify.detect --> tests.test_hook_content_freshness;
    graphify.detect --> tests.test_hook_content_freshness { save_manifest }
    tests.test_hook_strict --> tests.test_hook_content_freshness {
        _fixture,
        _invoke,
        _is_deny,
        _read,
    }
    graphify.cache --> tests.test_hook_content_freshness { file_hash }
    graphify.cli --> tests.test_hook_strict;
    graphify.install --> tests.test_hook_strict { _claude_pretooluse_hooks }
    graphify.watch --> tests.test_hook_corpus_changes { _rebuild_code }
    graphify.__main__ --> tests.test_hook_guard;
    graphify.cli --> tests.test_hook_guard;
    graphify.cli --> tests.test_hook_guard_token_match { _bash_invokes_search }
    graphify.cli --> tests.test_hook_nudge_wording;
    graphify.cli --> tests.test_hook_out_of_project_paths;
    graphify.cli --> tests.test_hook_out_of_project_paths { _is_cwd_relative }
    tests.test_hook_strict --> tests.test_hook_strict_grep { _fixture, _invoke, _is_deny, _read }
    graphify.paths --> tests.test_hook_strict_grep;
    graphify.cli --> tests.test_hook_strict_grep;
    graphify.hooks --> tests.test_hooks {
        _CHECKOUT_MARKER,
        _CHECKOUT_SCRIPT,
        _HOOK_MARKER,
        _HOOK_SCRIPT,
        _MERGE_HOOK_MARKER,
        _MERGE_SCRIPT,
        _PYTHON_DETECT,
        _REBUILD_BODY_CHECKOUT,
        _REBUILD_BODY_COMMIT,
        _REWRITE_HOOK_MARKER,
        _REWRITE_SCRIPT,
        _TOPLEVEL_ANCHOR,
        _WORKTREE_GUARD,
        _detached_launch,
        _hooks_dir,
        _load_graphifyrc,
        _pinned_python,
        _unquote_git_path,
        install,
        status,
        uninstall,
    }
    graphify.watch --> tests.test_hooks;
    graphify.hooks --> tests.test_hooks_rewrite { install }
    tests.test_hooks --> tests.test_hooks_rewrite { _LAUNCH_LINE, _SH_ONLY }
    graphify.exporters.html --> tests.test_html_script_breakout { to_html }
    graphify.tree_html --> tests.test_html_script_breakout { emit_html }
    graphify.export --> tests.test_html_theme { to_html }
    graphify.build --> tests.test_hyperedge_member_shapes { build_from_json }
    graphify.llm --> tests.test_hyperedge_member_shapes { _sanitize_fragment }
    graphify.build --> tests.test_hyperedge_roundtrip { build_from_json }
    graphify.export --> tests.test_hyperedge_roundtrip { to_json }
    graphify.build --> tests.test_hypergraph { build_from_json }
    graphify.export --> tests.test_hypergraph { attach_hyperedges, to_json }
    graphify.report --> tests.test_hypergraph { generate }
    graphify.build --> tests.test_id_normalization_contract { _normalize_id }
    graphify.extract --> tests.test_id_normalization_contract { _make_id }
    graphify.ids --> tests.test_id_normalization_contract { make_id, normalize_id }
    graphify.mcp_ingest --> tests.test_id_normalization_contract { _make_id }
    graphify.symbol_resolution --> tests.test_id_normalization_contract { _bash_make_id }
    graphify.detect --> tests.test_ignore_file_encoding;
    graphify.detect --> tests.test_ignore_file_encoding { _read_ignore_text, detect }
    graphify.llm --> tests.test_image_vision;
    graphify.detect --> tests.test_image_vision;
    graphify.analyze --> tests.test_import_cycles_shortest_first { find_import_cycles }
    graphify.extract --> tests.test_import_extension_resolution {
        _make_id,
        _resolve_js_module_path,
        extract_js,
        extract_svelte,
    }
    graphify.build --> tests.test_import_self_loops { build_from_json }
    graphify.extract --> tests.test_import_self_loops { extract }
    graphify.extract --> tests.test_imported_export_forwarding { extract }
    graphify.extractors.resolution --> tests.test_imported_export_forwarding;
    graphify.__main__ --> tests.test_incomplete_build_guard;
    graphify.extract --> tests.test_incremental { _make_id, extract }
    graphify.detect --> tests.test_incremental_mtime_collision;
    graphify.watch --> tests.test_incremental_unscanned_placeholders { _rebuild_code }
    graphify.extract --> tests.test_indirect_call_arrow_single_param_shadow { extract }
    graphify.extract --> tests.test_indirect_call_block_scoped_shadow { extract, extract_js }
    graphify.extract --> tests.test_indirect_call_catch_binding_shadow { extract }
    graphify.extract --> tests.test_indirect_call_external_import_shadow { extract }
    graphify.extract --> tests.test_indirect_call_file_scope_callback_shadow { extract }
    graphify.extract --> tests.test_indirect_call_for_of_binding_shadow { extract }
    graphify.extract --> tests.test_indirect_call_function_expression_shadow { extract }
    graphify.affected --> tests.test_indirect_call_nested_closure_shadow { affected_nodes }
    graphify.extract --> tests.test_indirect_call_nested_closure_shadow { extract }
    graphify.affected --> tests.test_indirect_dispatch { affected_nodes }
    graphify.extract --> tests.test_indirect_dispatch { extract, extract_python }
    graphify.affected --> tests.test_indirect_dispatch_assign_return { affected_nodes }
    graphify.extract --> tests.test_indirect_dispatch_assign_return { extract_python }
    graphify.affected --> tests.test_indirect_dispatch_getattr { affected_nodes }
    graphify.extract --> tests.test_indirect_dispatch_getattr { extract_python }
    graphify.extract --> tests.test_indirect_dispatch_module_attr { extract }
    graphify.export --> tests.test_inferred_confidence_rubric { _CONFIDENCE_SCORE_DEFAULTS }
    graphify.extract --> tests.test_inferred_confidence_rubric { extract }
    graphify.ingest --> tests.test_ingest { save_query_result }
    graphify.ingest --> tests.test_ingest_capture_race;
    graphify.ingest --> tests.test_ingest_url_type;
    graphify.ingest --> tests.test_ingest_url_type { _detect_url_type }
    graphify.extract --> tests.test_inherited_field_receivers { _bind_member_field_tables, extract }
    graphify.llm --> tests.test_injection_sentinel_coverage {
        _neutralise_injection_sentinels,
        _wrap_untrusted,
    }
    graphify.install --> tests.test_install;
    graphify.install --> tests.test_install {
        _PLATFORM_CONFIG,
        _claude_pretooluse_hooks,
        _gemini_hook,
        _install_codex_hook,
        _is_graphify_hook_command,
        _platform_skill_destination,
        _remove_claude_skill_registration,
        _remove_marker_section,
        install,
        uninstall_all,
    }
    graphify.__main__ --> tests.test_install {
        _agents_install,
        _agents_uninstall,
        _cursor_install,
        _cursor_uninstall,
        _install_claude_hook,
        _kilo_install,
        _kilo_uninstall,
        _platform_skill_destination,
        codebuddy_install,
        codebuddy_uninstall,
        gemini_install,
        gemini_uninstall,
        install,
        main,
        vscode_install,
    }
    graphify --> tests.test_install;
    graphify.cli --> tests.test_install;
    graphify.install --> tests.test_install_hook_identity;
    graphify.install --> tests.test_install_line_endings;
    graphify --> tests.test_install_references;
    graphify.__main__ --> tests.test_install_references;
    graphify.__main__ --> tests.test_install_references { main }
    graphify --> tests.test_install_roundtrip;
    graphify.__main__ --> tests.test_install_roundtrip;
    graphify.__main__ --> tests.test_install_strings {
        _AGENTS_MD_SECTION,
        _ANTIGRAVITY_RULES,
        _CLAUDE_MD_SECTION,
        _CURSOR_RULE,
        _DEVIN_RULES,
        _GEMINI_MD_SECTION,
        _GEMINI_NUDGE_TEXT,
        _KIRO_STEERING,
        _OPENCODE_PLUGIN_JS,
        _READ_NUDGE,
        _SEARCH_NUDGE,
        _VSCODE_INSTRUCTIONS_SECTION,
        _skill_registration,
    }
    graphify.__main__ --> tests.test_install_upgrade;
    graphify.__main__ --> tests.test_install_version_stamp;
    graphify.__main__ --> tests.test_install_version_warning;
    graphify.install --> tests.test_install_version_warning {
        __version__,
        _copy_skill_file,
        _platform_skill_destination,
    }
    graphify.extract --> tests.test_issue_3405_python_resolution { extract }
    graphify.build --> tests.test_issue_3472_source_file_collision { build, build_merge }
    graphify.extract --> tests.test_java_anonymous_class { extract }
    graphify.extract --> tests.test_java_enum_members { extract }
    graphify.extract --> tests.test_java_lombok_getter { extract }
    graphify.extract --> tests.test_java_member_calls { extract, extract_java }
    graphify.cache --> tests.test_java_member_calls;
    graphify.cache --> tests.test_java_member_calls { save_cached }
    graphify.watch --> tests.test_java_member_calls { _rebuild_code }
    graphify.extract --> tests.test_java_nested_type_identity { extract, extract_java }
    graphify.watch --> tests.test_java_nested_type_identity { _rebuild_code }
    graphify.cache --> tests.test_java_nested_type_identity;
    graphify.extract --> tests.test_java_overloads { extract }
    graphify.build --> tests.test_java_type_resolution { build_from_json }
    graphify.extract --> tests.test_java_type_resolution { extract }
    graphify.extract --> tests.test_java_underscore_ids { extract }
    graphify.extract --> tests.test_js_callback_calls { extract }
    graphify.extract --> tests.test_js_cjs_barrel_require_call { extract }
    graphify.extract --> tests.test_js_destructured_export { extract }
    graphify.affected --> tests.test_js_dynamic_import_affected { affected_nodes }
    graphify.extract --> tests.test_js_dynamic_import_affected { _file_node_id, extract }
    graphify.affected --> tests.test_js_dynamic_imports {
        DEFAULT_AFFECTED_RELATIONS,
        affected_nodes,
    }
    graphify.extract --> tests.test_js_dynamic_imports { _file_node_id, extract }
    graphify.extract --> tests.test_js_exported_fn_call_resolution { extract }
    graphify.extract --> tests.test_js_exported_scalar_bindings { extract, extract_js }
    graphify.extract --> tests.test_js_extends_require_4688 { _make_id, extract }
    graphify.build --> tests.test_js_import_resolution { build_from_json }
    graphify.export --> tests.test_js_import_resolution { to_json }
    graphify.extract --> tests.test_js_import_resolution {
        _file_node_id,
        _file_stem,
        _make_id,
        extract,
    }
    graphify.analyze --> tests.test_js_import_resolution { find_import_cycles }
    graphify.extract --> tests.test_js_member_call_bare_name_fallback { extract }
    graphify.extract --> tests.test_js_member_collisions { cache_salt, extract, extract_js }
    graphify.build --> tests.test_js_member_collisions { build, build_merge }
    graphify.cluster --> tests.test_js_member_collisions { cluster }
    graphify.export --> tests.test_js_member_collisions { to_json }
    graphify.cache --> tests.test_js_member_collisions { save_cached }
    graphify.extract --> tests.test_js_module_level_anonymous_calls { extract }
    graphify.extract --> tests.test_js_namespace_import_call_edges { extract }
    graphify.extract --> tests.test_js_nested_function_scope { extract }
    graphify.extract --> tests.test_js_require_binding_shadow { _make_id, extract }
    graphify.extract --> tests.test_js_require_external_package_call { _make_id, extract }
    graphify.extract --> tests.test_js_this_member_expressions { extract }
    graphify.extractors.resolution --> tests.test_js_walk_order { _parse_js_tree, _walk_js_tree }
    graphify.extract --> tests.test_jsconfig_baseurl { _make_id, extract }
    graphify.extractors.json_config --> tests.test_json_schema_config { extract_json }
    graphify.extract --> tests.test_jsx_component_usage_calls { extract }
    graphify.install --> tests.test_kilo_config_merge {
        _install_kilo_plugin,
        _uninstall_kilo_plugin,
    }
    graphify.extract --> tests.test_kotlin_generic_type_params { extract }
    graphify.extract --> tests.test_kotlin_grammar { extract }
    graphify.watch --> tests.test_kotlin_grammar { _rebuild_code }
    graphify.extract --> tests.test_kotlin_interface_dispatch { extract }
    graphify.extract --> tests.test_kotlin_java_call_edges_4935 { extract }
    graphify.extract --> tests.test_kotlin_object_literal { extract }
    graphify.extract --> tests.test_kotlin_typealias_declarations { extract }
    graphify.extract --> tests.test_kotlin_underscore_ids { extract }
    graphify.llm --> tests.test_label_retry;
    graphify.llm --> tests.test_labeling {
        _community_label_lines,
        _parse_label_response,
        generate_community_labels,
        label_communities,
    }
    graphify.__main__ --> tests.test_labeling;
    graphify.watch --> tests.test_labeling { _reconcile_graph_html }
    graphify.cluster --> tests.test_labeling;
    graphify.cluster --> tests.test_labeling { community_member_sigs }
    graphify.extractors.resolution --> tests.test_language_override_imports {
        _resolve_js_module_path,
        _resolve_python_module_path,
        _resolve_python_namespace_dir,
    }
    graphify.rcfile --> tests.test_language_override_imports {
        activate_language_overrides,
        set_language_overrides,
    }
    graphify.extract --> tests.test_language_override_imports { extract }
    graphify.watch --> tests.test_language_override_lifecycle;
    graphify.detect --> tests.test_language_override_lifecycle { detect_incremental, save_manifest }
    graphify.rcfile --> tests.test_language_override_lifecycle { set_language_overrides }
    graphify.rcfile --> tests.test_language_overrides;
    graphify.rcfile --> tests.test_language_overrides {
        activate_language_overrides,
        cache_salt,
        effective_suffix,
        load_graphifyrc,
        parse_language_value,
        set_language_overrides,
    }
    graphify.detect --> tests.test_language_overrides { FileType, classify_file, detect }
    graphify.extract --> tests.test_language_overrides {
        _get_extractor,
        _lang_family,
        _lang_is_case_insensitive,
        _worker_init,
        extract,
        extract_cpp,
        extract_pascal,
        extract_php,
    }
    graphify.extractors.ocaml --> tests.test_language_overrides { extract_ocaml }
    graphify.extractors.robot --> tests.test_language_overrides { extract_robot }
    graphify.resolver_registry --> tests.test_language_overrides {
        LanguageResolver,
        run_language_resolvers,
    }
    graphify.hooks --> tests.test_language_overrides { _load_graphifyrc }
    graphify.resolver_registry --> tests.test_language_resolvers {
        LanguageResolver,
        registered_resolvers,
        run_language_resolvers,
    }
    graphify.extract --> tests.test_language_resolvers;
    graphify.extract --> tests.test_languages {
        _file_stem,
        _get_extractor,
        _is_cpp_header,
        _is_objc_header,
        _make_id,
        collect_files,
        extract,
        extract_apex,
        extract_c,
        extract_commonlisp,
        extract_cpp,
        extract_csharp,
        extract_csproj,
        extract_dm,
        extract_dmf,
        extract_dmi,
        extract_dmm,
        extract_elixir,
        extract_fortran,
        extract_go,
        extract_groovy,
        extract_java,
        extract_js,
        extract_julia,
        extract_kotlin,
        extract_markdown,
        extract_objc,
        extract_php,
        extract_powershell,
        extract_powershell_manifest,
        extract_python,
        extract_razor,
        extract_robot,
        extract_ruby,
        extract_scala,
        extract_sln,
        extract_swift,
        extract_verilog,
        extract_xaml,
        extract_zig,
    }
    graphify.detect --> tests.test_languages { CODE_EXTENSIONS }
    graphify.build --> tests.test_languages { build_from_json }
    graphify.extractors.markdown --> tests.test_languages {
        _parse_frontmatter_fallback,
        _resolve_markdown_link,
    }
    graphify.extractors.base --> tests.test_languages { _file_stem, _make_id }
    graphify.extractors.robot --> tests.test_languages { _kw_id, _resolve_robot_import }
    graphify.reflect --> tests.test_learning_overlay_input {
        LEARNING_SIDECAR_NAME,
        load_learning_overlay,
    }
    graphify.detect --> tests.test_linked_worktree_reconcile { detect, ignored_predicate }
    graphify.watch --> tests.test_linked_worktree_reconcile { _reconcile_existing_graph }
    graphify.llm --> tests.test_llm_ambiguous_fragments;
    graphify.cache --> tests.test_llm_ambiguous_fragments {
        check_semantic_cache,
        save_semantic_cache,
    }
    graphify.llm --> tests.test_llm_backends;
    graphify.llm --> tests.test_llm_backends { _FILE_CHAR_CAP }
    graphify.file_slice --> tests.test_llm_backends { FileSlice }
    graphify.llm --> tests.test_llm_null_token_counts;
    graphify.llm --> tests.test_llm_parser;
    graphify.llm --> tests.test_llm_parser_reasoning;
    graphify.paths --> tests.test_load_graph_release_rows {
        consumed,
        load_node_link_graph,
        restore_arc_direction,
    }
    graphify.detect --> tests.test_long_path_hashing;
    graphify.__main__ --> tests.test_lookup_exit_codes;
    graphify.cli --> tests.test_lookup_exit_codes { EXIT_AMBIGUOUS, EXIT_NOT_FOUND }
    graphify.build --> tests.test_loose_sibling_import_resolution { build_from_json }
    graphify.extract --> tests.test_loose_sibling_import_resolution {
        _file_node_id,
        _repoint_python_sibling_imports,
        extract,
    }
    graphify.build --> tests.test_lost_saved_semantic_nodes {
        _lost_saved_semantic_nodes,
        build_from_json,
    }
    graphify.export --> tests.test_lost_saved_semantic_nodes { to_json }
    graphify.watch --> tests.test_lost_saved_semantic_nodes { _check_shrink }
    graphify.build --> tests.test_lua_import { build_from_json }
    graphify.extract --> tests.test_lua_import { extract }
    graphify.extract --> tests.test_lua_method_calls { extract }
    graphify.extract --> tests.test_lua_underscore_ids { extract }
    graphify.build --> tests.test_manifest_ingest { build_from_json }
    graphify.detect --> tests.test_manifest_ingest { FileType, classify_file }
    graphify.extract --> tests.test_manifest_ingest { extract }
    graphify.manifest_ingest --> tests.test_manifest_ingest {
        extract_package_manifest,
        is_package_manifest_path,
    }
    graphify.cache --> tests.test_manifest_ingest { load_cached }
    graphify.manifest_ingest --> tests.test_manifest_tomli_required {
        _TOMLI_REQUIRED,
        _load_toml_module,
        _parse_cargo,
        _parse_pyproject,
        extract_package_manifest,
    }
    graphify.extract --> tests.test_markdown_code_spans { extract }
    graphify.extractors.markdown --> tests.test_markdown_code_spans {
        _code_span_mention,
        extract_markdown,
    }
    graphify.markdown_resolution --> tests.test_markdown_code_spans {
        _match_cited_file,
        _match_cited_file_any_form,
        resolve_markdown_mentions,
    }
    graphify.watch --> tests.test_markdown_code_spans { _rebuild_code }
    graphify.extractors.markdown --> tests.test_markdown_sections { extract_markdown }
    graphify.sections --> tests.test_markdown_sections {
        _MARKDOWN_SUFFIXES,
        read_section,
        resolve_section_query,
        section_root,
    }
    graphify.watch --> tests.test_markdown_sections { _rebuild_code }
    graphify.extract --> tests.test_markdown_sections { _DISPATCH }
    tests.test_serve_http --> tests.test_markdown_sections { _call_tool, _client, _init_session }
    graphify.serve --> tests.test_markdown_sections;
    graphify.serve --> tests.test_serve_http;
    graphify.prs --> tests.test_serve_http;
    graphify.serve --> tests.test_mcp_graph_view_cache {
        _load_graph,
        _path_search_graph,
        _query_graph_text,
        _shortest_path_text,
        _traversal_view,
    }
    graphify.mcp_ingest --> tests.test_mcp_ingest {
        MCP_CONFIG_FILENAMES,
        extract_mcp_config,
        is_mcp_config_path,
    }
    graphify.extract --> tests.test_mcp_ingest { _get_extractor, extract_json }
    graphify.__main__ --> tests.test_merge_chunks_validation;
    graphify.semantic_cleanup --> tests.test_merge_chunks_validation { validate_semantic_fragment }
    graphify.build --> tests.test_merge_graphs_cli { distinct_repo_tags }
    graphify.build --> tests.test_merge_sweeps_reextract_orphans {
        build_from_json,
        build_merge,
        take_shrink_accounting,
    }
    graphify._minhash --> tests.test_minhash { MinHash, MinHashLSH, _optimal_lsh_params }
    graphify.dedup --> tests.test_minhash;
    graphify.extract --> tests.test_module_level_underscore_decl_ids { extract }
    graphify.ids --> tests.test_module_level_underscore_decl_ids { DeclIdRegistry }
    graphify.detect --> tests.test_msbuild_dir_evidence { detect }
    graphify.multigraph_compat --> tests.test_multigraph_compat {
        CapabilityCheck,
        MultigraphCapabilityResult,
        probe_multigraph_capabilities,
        require_multigraph_capabilities,
    }
    graphify.__main__ --> tests.test_multigraph_diagnostics;
    graphify.diagnostics --> tests.test_multigraph_diagnostics {
        diagnose_extraction,
        diagnose_file,
        format_diagnostic_json,
        format_diagnostic_report,
        scan_producer_suppression_sites,
    }
    graphify.extract --> tests.test_multilang {
        extract,
        extract_go,
        extract_js,
        extract_rust,
        extract_sql,
    }
    graphify.extractors.sql --> tests.test_multilang { _mask_sql_comments }
    graphify.ids --> tests.test_multilang { make_id }
    graphify.extract --> tests.test_nested_type_owners { extract }
    graphify.extract --> tests.test_no_cluster_run_only_keys { RUN_ONLY_EXTRACTION_KEYS, extract }
    graphify.build --> tests.test_no_cluster_undeclared_endpoints { finalize_raw_graph_endpoints }
    graphify.watch --> tests.test_no_cluster_undeclared_endpoints { _rebuild_code }
    graphify.__main__ --> tests.test_no_dedup_flag;
    graphify.build --> tests.test_no_dedup_flag;
    graphify.build --> tests.test_no_dedup_flag { build }
    graphify.extract --> tests.test_node_id_canonical { _make_id, extract }
    graphify.detect --> tests.test_non_regular_files { _is_regular_file }
    graphify.build --> tests.test_non_string_node_ids {
        _coerce_non_string_ids,
        build,
        build_from_json,
    }
    graphify.extract --> tests.test_objc_callable_markers { extract }
    graphify.extract --> tests.test_objc_category_interfaces { extract }
    graphify.extract --> tests.test_objc_category_portable_ids { extract }
    graphify.extractors.base --> tests.test_objc_category_portable_ids { _make_id }
    graphify.extract --> tests.test_objc_enum_declarations { extract }
    graphify.extract --> tests.test_objc_field_table_remap { _remap_objc_field_tables, extract }
    graphify.cache --> tests.test_objc_field_table_remap { _absolutize_ids_in, _relativize_ids_in }
    graphify.extractors.base --> tests.test_objc_field_table_remap { _make_id }
    graphify.extract --> tests.test_objc_member_calls { extract }
    graphify.extract --> tests.test_objc_method_collisions { extract }
    graphify.extract --> tests.test_objc_property_ivar_receivers { extract }
    graphify.export --> tests.test_obsidian_dangling_member { to_canvas, to_obsidian }
    graphify.export --> tests.test_obsidian_filename_cap { to_canvas, to_obsidian }
    graphify.export --> tests.test_obsidian_unicode_tags { _obsidian_tag, to_obsidian }
    graphify.build --> tests.test_obsidian_vault_migration { build_from_json }
    graphify.export --> tests.test_obsidian_vault_migration {
        _adopt_pre_manifest_notes,
        _is_graphify_note,
        to_obsidian,
    }
    graphify.extract --> tests.test_ocaml { extract_ocaml }
    graphify.detect --> tests.test_office_incremental;
    graphify.detect --> tests.test_office_limits;
    graphify.llm --> tests.test_ollama;
    graphify.llm --> tests.test_ollama {
        BACKENDS,
        _validate_ollama_base_url,
        detect_backend,
        extract_files_direct,
    }
    graphify.llm --> tests.test_ollama_ctx_sizing;
    graphify.llm --> tests.test_ollama_live;
    graphify.llm --> tests.test_ollama_native_chat;
    graphify.llm --> tests.test_ollama_retry_cap;
    graphify.llm --> tests.test_openai_custom_endpoint;
    graphify.__main__ --> tests.test_opencode_plugin_refresh;
    graphify.install --> tests.test_opencode_plugin_refresh { _OPENCODE_PLUGIN_JS, __version__ }
    graphify.paths --> tests.test_opencode_plugin_refresh;
    graphify.detect --> tests.test_out_dir_evidence { detect }
    graphify.detect --> tests.test_oversized_document_slicing { DOC_EXTENSIONS }
    graphify.file_slice --> tests.test_oversized_document_slicing {
        _SPLITTABLE_TEXT_SUFFIXES,
        expand_oversized_files,
        is_splittable_text,
        read_slice_text,
        slice_boundaries,
    }
    graphify.llm --> tests.test_oversized_document_slicing { _FILE_CHAR_CAP, _read_files }
    graphify.extract --> tests.test_owned_type_sources { extract }
    graphify.extract --> tests.test_package_json_subpath_imports { _make_id, extract }
    graphify.extractors.resolution --> tests.test_package_json_subpath_imports {
        _resolve_js_module_path,
    }
    graphify.extract --> tests.test_parked_call_site_file { extract }
    graphify.llm --> tests.test_partial_cache;
    graphify.cache --> tests.test_partial_cache {
        _group_has_partial_marker,
        load_cached,
        save_semantic_cache,
    }
    graphify.cli --> tests.test_partial_cache { _stamped_manifest_files }
    graphify.extract --> tests.test_partial_extraction_warning;
    graphify.extract --> tests.test_partial_extraction_warning { extract }
    graphify.extract --> tests.test_pascal {
        _DISPATCH,
        _extract_pascal_regex,
        extract_delphi_form,
        extract_lazarus_form,
        extract_lazarus_package,
        extract_pascal,
    }
    graphify.detect --> tests.test_pascal { CODE_EXTENSIONS }
    graphify.extract --> tests.test_pascal_base_class_resolution { extract, extract_pascal }
    graphify.pascal_class_resolution --> tests.test_pascal_base_class_resolution {
        resolve_pascal_base_classes,
    }
    graphify.extract --> tests.test_pascal_call_scoping { _extract_pascal_regex, extract_pascal }
    graphify.extract --> tests.test_pascal_parse_recovery { extract_pascal }
    graphify.extractors.pascal --> tests.test_pascal_parse_recovery {
        _normalize_pascal_compiler_directives,
        _normalize_pascal_escaped_string_literals,
    }
    graphify.extract --> tests.test_pascal_record_methods { _extract_pascal_regex, extract_pascal }
    graphify.extract --> tests.test_pascal_resolution { extract, extract_pascal }
    graphify.resolver_registry --> tests.test_pascal_resolution { registered_resolvers }
    graphify.extract --> tests.test_pascal_singleton_resolution { extract, extract_pascal }
    graphify.pascal_singleton_resolution --> tests.test_pascal_singleton_resolution {
        resolve_pascal_singleton_calls,
    }
    graphify.__main__ --> tests.test_path_cli;
    graphify.cli --> tests.test_path_cli { EXIT_AMBIGUOUS, EXIT_NOT_FOUND }
    graphify.serve --> tests.test_path_cli { _shortest_path_text }
    graphify.__main__ --> tests.test_path_confidence;
    graphify.build --> tests.test_path_confidence { build_from_json }
    graphify.serve --> tests.test_path_confidence { _path_confidence_line, _shortest_path_text }
    graphify.__main__ --> tests.test_path_type_member;
    graphify.cli --> tests.test_path_type_member { EXIT_AMBIGUOUS, EXIT_NOT_FOUND }
    graphify.extract --> tests.test_path_type_member { extract }
    graphify.serve --> tests.test_path_type_member {
        _find_node_tiers,
        _resolve_path_endpoint,
        _resolve_single_node,
        _shortest_path_text,
    }
    graphify.paths --> tests.test_paths {
        _is_test_path,
        disambiguate_ambiguous_candidates,
        is_absolute_any_platform,
    }
    graphify.detect --> tests.test_pdf_extra_warning;
    graphify.file_slice --> tests.test_pdf_slicing;
    graphify.file_slice --> tests.test_pdf_slicing {
        FileSlice,
        bisect_slice,
        expand_oversized_files,
        is_splittable_text,
        read_slice_text,
        unit_source_text,
    }
    graphify.llm --> tests.test_pdf_slicing { _FILE_CHAR_CAP, _file_to_text, _read_files }
    graphify.llm --> tests.test_pdf_token_estimate {
        _FILE_CHAR_CAP,
        _estimate_file_tokens,
        _file_to_text,
        _get_tokenizer,
        _read_files,
    }
    graphify.pg_introspect --> tests.test_pg_introspect { introspect_postgres }
    graphify.validate --> tests.test_pg_introspect { validate_extraction }
    graphify.extract --> tests.test_phantom_cross_package_call { extract }
    graphify.build --> tests.test_phantom_external_import { build_from_json }
    graphify.extract --> tests.test_phantom_external_import {
        _make_id,
        _resolve_js_import_target,
        extract,
    }
    graphify.extract --> tests.test_php_class_const_initializer_refs { extract }
    graphify.extract --> tests.test_php_language_construct_calls { extract }
    graphify.build --> tests.test_php_member_call_gaps { build_from_json }
    graphify.extract --> tests.test_php_member_call_gaps { _resolve_php_member_calls, extract }
    graphify.rcfile --> tests.test_php_member_call_gaps { set_language_overrides }
    graphify.extract --> tests.test_php_member_collisions { extract }
    graphify.extract --> tests.test_php_object_creation { extract }
    graphify.extract --> tests.test_php_receiver_member_calls { extract }
    graphify.extract --> tests.test_php_static_call_resolution { extract }
    graphify.extract --> tests.test_php_type_resolution { extract }
    graphify.extract --> tests.test_php_unparsed_casts {
        _PHP_CONFIG,
        _extract_generic,
        _php_blank_unparsed_casts,
        extract,
        extract_php,
    }
    graphify.install --> tests.test_pi_guard_install { dispatch_install_cli }
    graphify.install --> tests.test_pi_install {
        _platform_skill_destination,
        _remove_skill_file,
        install,
    }
    graphify.__main__ --> tests.test_pin_hash_seed;
    graphify.detect --> tests.test_pipeline { detect }
    graphify.extract --> tests.test_pipeline { collect_files, extract }
    graphify.build --> tests.test_pipeline { build_from_json }
    graphify.cluster --> tests.test_pipeline { cluster, score_all }
    graphify.analyze --> tests.test_pipeline {
        god_nodes,
        suggest_questions,
        surprising_connections,
    }
    graphify.report --> tests.test_pipeline { generate }
    graphify.export --> tests.test_pipeline { to_html, to_json, to_obsidian }
    graphify.extract --> tests.test_plain_import_member_calls { extract }
    graphify.build --> tests.test_plain_import_member_calls { build_from_json }
    graphify.extract --> tests.test_pnpm_workspace_globs { extract }
    tests.test_csharp_interface_dispatch --> tests.test_pr10_csharp_overrides { _INJECTED }
    tests.test_csharp_partial_classes --> tests.test_pr10_csharp_overrides { _HALVES, _find }
    tests.test_language_overrides --> tests.test_pr10_csharp_overrides {
        _no_overrides_leak,
        _quiet_extract,
    }
    graphify.extractors.resolution --> tests.test_pr10_resolution_overrides;
    graphify.rcfile --> tests.test_pr10_resolution_overrides {
        activate_language_overrides,
        set_language_overrides,
    }
    tests.test_language_overrides --> tests.test_pr10_resolution_overrides { _quiet_extract }
    tests.test_language_override_lifecycle --> tests.test_pr10_watch_overrides {
        drive_watch,
        graph_labels,
    }
    graphify.ids --> tests.test_prompt_id_rule_matches_ids { make_id, normalize_id }
    graphify.llm --> tests.test_provider_registry;
    graphify.cli --> tests.test_provider_registry;
    graphify.prs --> tests.test_prs {
        PRInfo,
        _classify,
        _detect_default_branch,
        _gh,
        _parse_ci,
        _parse_pr_dict,
        _path_match,
        attach_graph_impact,
        build_community_labels,
        cmd_prs,
        compute_pr_impact,
        fetch_pr,
        fetch_pr_files,
        fetch_prs,
        fetch_worktrees,
        format_prs_text,
    }
    graphify.build --> tests.test_prune_source_aliases { build_merge, merge_raw_extraction }
    graphify.build --> tests.test_prune_sweeps_orphans { build_from_json, build_merge }
    graphify.extract --> tests.test_python_aliased_call_in_method { extract }
    graphify.extract --> tests.test_python_bare_call_not_enclosing_method { extract }
    graphify.extract --> tests.test_python_builtin_call_shadowing_4989 { extract }
    graphify.extract --> tests.test_python_decorators { _file_stem, _make_id, extract }
    graphify.extract --> tests.test_python_external_import_calls { extract }
    graphify.extract --> tests.test_python_forward_ref_file_id { extract }
    graphify.extract --> tests.test_python_import_never_resolves_to_itself { extract }
    graphify.extract --> tests.test_python_import_resolution { extract }
    graphify.extractors.resolution --> tests.test_python_import_resolution {
        _SCAN_ROOT_NAMESPACE_CACHE,
        _infer_scan_root_namespace,
        _resolve_python_module_path,
    }
    graphify.analyze --> tests.test_python_import_resolution { find_import_cycles }
    graphify.build --> tests.test_python_import_resolution { build_from_json }
    graphify.extract --> tests.test_python_imported_call_caller_collision { extract }
    graphify.extract --> tests.test_python_inherited_method_calls { extract, extract_python }
    graphify.watch --> tests.test_python_inherited_method_calls { _rebuild_code }
    graphify.cache --> tests.test_python_inherited_method_calls;
    graphify.cache --> tests.test_python_inherited_method_calls { save_cached }
    graphify.extract --> tests.test_python_injected_factory_calls { extract, extract_python }
    graphify.watch --> tests.test_python_injected_factory_calls { _rebuild_code }
    graphify.cache --> tests.test_python_injected_factory_calls;
    graphify.cache --> tests.test_python_injected_factory_calls { save_cached }
    graphify.extract --> tests.test_python_lambda_call_shadowing { extract, extract_python }
    graphify.watch --> tests.test_python_lambda_call_shadowing { _rebuild_code }
    graphify.extract --> tests.test_python_member_call_language_gate {
        _resolve_python_member_calls,
        extract,
    }
    graphify.rcfile --> tests.test_python_member_call_language_gate { set_language_overrides }
    graphify.extract --> tests.test_python_member_collisions { extract }
    graphify.extract --> tests.test_python_module_call_exact_name { extract }
    graphify.extract --> tests.test_python_module_instance_calls { extract }
    graphify.extract --> tests.test_python_nested_class_identity { extract }
    graphify.extract --> tests.test_python_param_call_shadowing { extract, extract_python }
    graphify.extractors.resolution --> tests.test_python_parse_release;
    graphify.extractors.resolution --> tests.test_python_parse_release { _parse_python_tree }
    graphify.extract --> tests.test_python_parse_release { extract }
    graphify.extract --> tests.test_python_property_reads { extract, extract_python }
    graphify.watch --> tests.test_python_property_reads { _rebuild_code }
    graphify.cache --> tests.test_python_property_reads;
    graphify.cache --> tests.test_python_property_reads { save_cached }
    graphify.extract --> tests.test_python_pytest_fixture_receivers { extract, extract_python }
    graphify.watch --> tests.test_python_pytest_fixture_receivers { _rebuild_code }
    graphify.cache --> tests.test_python_pytest_fixture_receivers;
    graphify.cache --> tests.test_python_pytest_fixture_receivers { save_cached }
    graphify.build --> tests.test_python_reexport_type_binding { build_from_json }
    graphify.extract --> tests.test_python_reexport_type_binding { extract }
    graphify.extract --> tests.test_python_self_type_ref { extract }
    graphify.extract --> tests.test_python_subscript_type_refs { extract_python }
    graphify.extractors.engine --> tests.test_python_subscript_type_refs {
        _python_collect_type_refs,
    }
    graphify.extract --> tests.test_python_type_alias { extract }
    graphify.extract --> tests.test_python_typed_receiver_calls { extract }
    graphify.extract --> tests.test_python_underscore_resolution { extract, extract_python }
    graphify.build --> tests.test_python_underscore_resolution { build }
    graphify.build --> tests.test_qualified_annotation_stub_bind { build_from_json }
    graphify.extract --> tests.test_qualified_annotation_stub_bind { extract }
    graphify.extract --> tests.test_qualified_type_competition { extract }
    graphify.watch --> tests.test_qualified_type_competition { _rebuild_code }
    graphify.__main__ --> tests.test_query_cli;
    graphify.cli --> tests.test_query_cli { _graph_root_for }
    graphify.__main__ --> tests.test_query_induced_edges;
    graphify.serve --> tests.test_query_induced_edges {
        _bfs,
        _dfs,
        _filter_graph_by_context,
        _query_graph_text,
    }
    graphify.serve --> tests.test_query_mcp_direction {
        _load_graph,
        _query_graph_text,
        _traversal_view,
    }
    graphify.build --> tests.test_query_names_its_graph { build_from_json }
    graphify.serve --> tests.test_query_names_its_graph { _display_graph_path, _query_graph_text }
    graphify.serve --> tests.test_query_seed_order { _pick_seeds, _query_graph_text, _score_query }
    graphify.__main__ --> tests.test_query_seeds;
    graphify.serve --> tests.test_query_seeds { _query_graph_text }
    graphify.serve --> tests.test_query_source_first {
        _QUERY_DEMOTE_WEIGHT,
        _query_graph_text,
        _query_path_weight,
        _query_terms,
        _score_nodes,
        _score_query,
        _subgraph_to_text,
    }
    graphify.querylog --> tests.test_querylog { _log_path, log_query, nodes_from_result }
    graphify.extract --> tests.test_r_extractor { extract, extract_r }
    graphify.build --> tests.test_r_extractor { build }
    graphify.extract --> tests.test_rationale {
        _redact_rationale_labels,
        extract,
        extract_js,
        extract_python,
    }
    graphify.build --> tests.test_rationale { build_from_json }
    graphify.__main__ --> tests.test_read_hook { _claude_pretooluse_hooks }
    graphify.extractors.base --> tests.test_read_path_imports { _file_stem }
    graphify.ids --> tests.test_read_path_imports { _file_stem }
    graphify.build --> tests.test_read_path_imports { graph_has_legacy_ids }
    graphify.ingest --> tests.test_reflect { save_query_result }
    graphify.reflect --> tests.test_reflect {
        LEARNING_SIDECAR_NAME,
        _code_fingerprint,
        _is_stale,
        aggregate_lessons,
        build_learning_overlay,
        lessons_fresh,
        load_learning_overlay,
        load_memory_docs,
        parse_memory_doc,
        reflect,
        render_lessons_md,
        write_learning_sidecar,
    }
    graphify.build --> tests.test_reflect { build_from_json }
    graphify.cluster --> tests.test_reflect { cluster, score_all }
    graphify.analyze --> tests.test_reflect { god_nodes, surprising_connections }
    graphify.export --> tests.test_reflect { to_json }
    graphify.build --> tests.test_relation_collapse_precedence { build_from_json, edge_data }
    graphify.extract --> tests.test_relation_collapse_precedence { extract }
    graphify.__main__ --> tests.test_replace_or_append_section { _replace_or_append_section }
    graphify.build --> tests.test_report { build_from_json }
    graphify.cluster --> tests.test_report { cluster, score_all }
    graphify.analyze --> tests.test_report { god_nodes, surprising_connections }
    graphify.report --> tests.test_report { _portable_root_label, generate, load_report_token_cost }
    graphify.export --> tests.test_report { _obsidian_safe_stem }
    graphify.analyze --> tests.test_report_gap_thresholds { suggest_questions }
    graphify.report --> tests.test_report_gap_thresholds { generate }
    graphify.extractors.models --> tests.test_resolution_collision_index {
        _SymbolResolutionFacts,
        _SymbolUseFact,
    }
    graphify.extractors.resolution --> tests.test_resolution_collision_index {
        _apply_symbol_resolution_facts,
        _js_source_path,
    }
    graphify.extractors.resolution --> tests.test_resolution_one_parse_per_file;
    graphify.extractors.resolution --> tests.test_resolve_memoization {
        _cached_realpath,
        _resolve_cached,
    }
    graphify.extract --> tests.test_ruby_bare_self_send_calls { extract }
    graphify.extract --> tests.test_ruby_resolution { extract, extract_ruby }
    graphify.ruby_resolution --> tests.test_ruby_resolution { resolve_ruby_member_calls }
    graphify.extract --> tests.test_ruby_underscore_ids { extract }
    graphify.build --> tests.test_rust_anonymous_const { build_from_json }
    graphify.extract --> tests.test_rust_anonymous_const { extract }
    graphify.extract --> tests.test_rust_builtin_type_hubs { extract }
    graphify.extract --> tests.test_rust_case_collisions { extract }
    graphify.extract --> tests.test_rust_crate_use_scope { extract }
    graphify.extract --> tests.test_rust_impl_method_collisions { extract }
    graphify.extract --> tests.test_rust_in_file_call_binding { extract }
    graphify.extractors.rust --> tests.test_rust_in_file_call_binding { extract_rust }
    graphify.extract --> tests.test_rust_macro_argument_calls { extract }
    graphify.extractors.rust --> tests.test_rust_macro_rules { extract_rust }
    graphify.extract --> tests.test_rust_prelude_trait_edges { extract }
    graphify.extract --> tests.test_rust_scoped_call_resolution { extract }
    graphify.extract --> tests.test_rust_self_member_calls {
        _resolve_rust_self_member_calls,
        extract,
    }
    graphify.extractors.rust --> tests.test_rust_self_member_calls { extract_rust }
    graphify.cache --> tests.test_rust_self_member_calls;
    graphify.cache --> tests.test_rust_self_member_calls { save_cached }
    graphify.extract --> tests.test_rust_type_alias_union { extract }
    graphify.extractors.rust --> tests.test_rust_type_alias_union { extract_rust }
    graphify.extractors.rust --> tests.test_rust_use_trees;
    graphify.extract --> tests.test_rust_use_trees { extract }
    graphify.watch --> tests.test_rust_use_trees { _rebuild_code }
    graphify.__main__ --> tests.test_rust_use_trees;
    graphify.cache --> tests.test_rust_use_trees;
    graphify.cache --> tests.test_rust_use_trees { save_cached }
    graphify.extract --> tests.test_scala_abstract_methods { extract }
    graphify.extract --> tests.test_scala_context_bounds { extract_scala }
    graphify.extract --> tests.test_scala_extension_methods { extract, extract_scala }
    graphify.extract --> tests.test_scala_generic_type_params { extract }
    graphify.extract --> tests.test_scala_given_instances { extract_scala }
    graphify.affected --> tests.test_scala_self_type { affected_nodes }
    graphify.extract --> tests.test_scala_self_type { extract_scala }
    graphify.extract --> tests.test_scala_top_level_binding { extract_scala }
    graphify.extract --> tests.test_scala_type_definition { extract_scala }
    graphify.extract --> tests.test_scala_underscore_ids { extract }
    graphify.extractors.base --> tests.test_scan_root_contextvar;
    graphify.scip_ingest --> tests.test_scip_ingest {
        _build_scip_metadata,
        _make_scip_node_id,
        _scip_kind_to_file_type,
        ingest_scip_json,
    }
    graphify.build --> tests.test_scip_ingest { build_from_json }
    graphify.validate --> tests.test_scip_ingest { validate_extraction }
    graphify.__main__ --> tests.test_search_hook { _claude_pretooluse_hooks, _resolve_graphify_exe }
    graphify.cli --> tests.test_search_hook_scope { _run_hook_guard, _search_is_outside_project }
    graphify.serve --> tests.test_section_subgraph_index;
    graphify.serve --> tests.test_section_subgraph_index {
        _get_trigram_index,
        _resolve_single_node,
    }
    graphify.sections --> tests.test_section_subgraph_index { resolve_section_query }
    graphify.security --> tests.test_security {
        _MAX_FETCH_BYTES,
        _MAX_GRAPH_FILE_BYTES,
        _MAX_TEXT_BYTES,
        _METADATA_MAX_LIST_ITEMS,
        _METADATA_MAX_VALUE_LEN,
        _max_graph_file_bytes,
        _sanitize_metadata_string,
        _sanitize_metadata_value,
        check_graph_file_size_cap,
        redact_secrets,
        safe_fetch,
        safe_fetch_text,
        sanitize_label,
        sanitize_metadata,
        validate_graph_path,
        validate_url,
    }
    graphify.cache --> tests.test_semantic_cache_basename_recovery {
        load_cached,
        save_semantic_cache,
    }
    graphify.cache --> tests.test_semantic_cache_out_root {
        check_semantic_cache,
        file_hash,
        load_cached,
        save_semantic_cache,
    }
    graphify.llm --> tests.test_semantic_cache_out_root { extract_corpus_parallel }
    graphify.semantic_cleanup --> tests.test_semantic_cleanup;
    graphify.llm --> tests.test_semantic_fragment_sanitize { _parse_llm_json, _sanitize_fragment }
    graphify.build --> tests.test_semantic_id_remap_root { _semantic_id_remap, build_from_json }
    graphify.extractors.base --> tests.test_semantic_id_remap_root { _file_stem }
    graphify.build --> tests.test_semantic_origin_stamp {
        _is_ast_tier,
        build_from_json,
        build_merge,
    }
    graphify.llm --> tests.test_semantic_origin_stamp { _stamp_semantic_origin }
    graphify.export --> tests.test_semantic_origin_stamp { to_json }
    graphify.watch --> tests.test_semantic_origin_stamp { _rebuild_code }
    graphify.build --> tests.test_semantic_similarity { build_from_json }
    graphify.analyze --> tests.test_semantic_similarity { _surprise_score, surprising_connections }
    graphify.report --> tests.test_semantic_similarity { generate }
    graphify.serve --> tests.test_serve;
    graphify.serve --> tests.test_serve {
        _EXACT_MATCH_BONUS,
        _SOURCE_MATCH_BONUS,
        _bfs,
        _communities_from_graph,
        _community_header,
        _compute_idf,
        _cut_lines_to_budget,
        _dfs,
        _filter_graph_by_context,
        _find_node,
        _get_trigram_index,
        _infer_context_filters,
        _load_graph,
        _neighbor_lines,
        _node_arg,
        _node_search_text,
        _normalize_context_filters,
        _pick_seeds,
        _qualified_tail,
        _query_graph_text,
        _query_terms,
        _resolve_context_filters,
        _resolve_path_endpoint,
        _resolve_single_node,
        _score_nodes,
        _score_query,
        _search_tokens,
        _shortest_path_text,
        _strip_diacritics,
        _subgraph_to_text,
        _trigram_candidates,
        _trigrams,
    }
    graphify.serve --> tests.test_serve_reload_off_loop;
    graphify.install --> tests.test_settings_merge {
        _install_claude_hook,
        _install_codebuddy_hook,
        _install_codex_hook,
        _install_gemini_hook,
    }
    graphify.build --> tests.test_shrink_guard_dedup_merge_4940 {
        _dedup_shrink_allowance,
        _lost_saved_semantic_nodes,
        build,
        build_merge,
        take_dedup_remap,
    }
    graphify.cluster --> tests.test_shrink_guard_dedup_merge_4940 { cluster }
    graphify.export --> tests.test_shrink_guard_dedup_merge_4940 { to_json }
    graphify.dedup --> tests.test_shrink_guard_dedup_merge_4940 { deduplicate_entities }
    graphify.__main__ --> tests.test_shrink_guard_replaced_sources;
    graphify.llm --> tests.test_shrink_guard_replaced_sources;
    graphify.build --> tests.test_shrink_guard_replaced_sources { build_merge }
    graphify.export --> tests.test_shrink_guard_replaced_sources { to_json }
    graphify.__main__ --> tests.test_skill_auto_refresh;
    graphify.install --> tests.test_skill_auto_refresh;
    graphify.install --> tests.test_skill_auto_refresh {
        _PLATFORM_CONFIG,
        __version__,
        _platform_skill_destination,
    }
    tools.skillgen.gen --> tests.test_skill_code_only_incremental_update;
    tools.skillgen.gen --> tests.test_skill_codex_semantic_merge;
    graphify.extract --> tests.test_skill_part_a_explicit_root { extract }
    tools.skillgen.gen --> tests.test_skill_part_a_explicit_root;
    graphify.paths --> tests.test_skill_persisted_scan_options;
    tools.skillgen.gen --> tests.test_skill_persisted_scan_options;
    graphify.detect --> tests.test_skill_persisted_scan_options { detect, save_manifest }
    graphify.watch --> tests.test_skill_persisted_scan_options {
        _read_build_excludes,
        _read_build_gitignore,
        _write_build_config,
    }
    graphify.cache --> tests.test_skill_semantic_all_cached { save_semantic_cache }
    tools.skillgen.gen --> tests.test_skill_semantic_all_cached;
    graphify.__main__ --> tests.test_skill_version_warning;
    tools.skillgen.gen --> tests.test_skillgen;
    graphify.__main__ --> tests.test_skillgen;
    graphify.__main__ --> tests.test_skillgen { __version__ }
    graphify.cache --> tests.test_skillgen { check_semantic_cache, drop_unreported_chunk_sources }
    graphify.export --> tests.test_skillgen { to_json }
    graphify.llm --> tests.test_slice_checkpoint_completeness;
    graphify.cache --> tests.test_slice_checkpoint_completeness { check_semantic_cache }
    graphify.file_slice --> tests.test_slice_checkpoint_completeness { FileSlice }
    graphify.extract --> tests.test_solidity_extractor { extract }
    graphify.extract --> tests.test_solidity_inherited_calls { extract }
    graphify.watch --> tests.test_solidity_inherited_calls { _rebuild_code }
    graphify.extract --> tests.test_source_file_encoding { extract }
    graphify.extractors.base --> tests.test_source_file_encoding;
    graphify.extractors.base --> tests.test_source_file_encoding {
        _read_source_bytes,
        _read_source_text,
    }
    graphify.file_slice --> tests.test_source_file_encoding { unit_source_text }
    graphify.llm --> tests.test_source_file_encoding { _file_to_text }
    graphify.extractors.resolution --> tests.test_source_key_memoization {
        _cached_source_key,
        _source_key,
    }
    graphify.extract --> tests.test_sourceless_call_targets { extract }
    graphify.extract --> tests.test_sql_comma_joins_and_dblink { extract_sql }
    graphify.extractors.sql --> tests.test_sql_comma_joins_and_dblink { _routine_body_refs }
    graphify.extract --> tests.test_sql_cross_file_tables { extract }
    graphify.extract --> tests.test_sql_go_batches { extract_sql }
    graphify.extractors.sql --> tests.test_sql_non_ascii_table_names { extract_sql }
    graphify.extractors.sql --> tests.test_sql_oracle_editionable { extract_sql }
    graphify.extractors.sql --> tests.test_sql_oracle_packages { extract_sql }
    graphify.extract --> tests.test_sql_plpgsql_body_reads { extract_sql }
    graphify.extract --> tests.test_sql_tsql_procedures { extract, extract_sql }
    graphify.extract --> tests.test_src_layout_import_resolution {
        _namespace_src_module_parts,
        extract,
    }
    graphify.extractors.resolution --> tests.test_src_layout_import_resolution {
        _resolve_python_module_path,
    }
    graphify.build --> tests.test_src_layout_import_resolution { build_from_json }
    graphify.cli --> tests.test_stale_prune { _stale_graph_sources }
    graphify.detect --> tests.test_stale_prune { detect }
    graphify.cache --> tests.test_stat_index_husk;
    graphify.cache --> tests.test_stat_index_multi_root;
    graphify.cache --> tests.test_stat_index_portability;
    graphify.analyze --> tests.test_suggest_questions_ambiguous { suggest_questions }
    graphify.extract --> tests.test_svelte_extraction { _make_id, extract_svelte }
    graphify.analyze --> tests.test_swift_builtin_noise { god_nodes }
    graphify.extract --> tests.test_swift_builtin_noise { extract }
    graphify.extract --> tests.test_swift_computed_properties { extract_swift }
    graphify.build --> tests.test_swift_cross_file_calls { build_from_json }
    graphify.extract --> tests.test_swift_cross_file_calls { extract }
    graphify.extract --> tests.test_swift_generic_type_params { extract }
    graphify.build --> tests.test_swift_import_resolution { build_from_json }
    graphify.dedup --> tests.test_swift_import_resolution { deduplicate_entities }
    graphify.extract --> tests.test_swift_import_resolution { extract }
    graphify.extract --> tests.test_swift_macro_declarations { extract }
    graphify.extract --> tests.test_swift_protocol_dispatch;
    graphify.extract --> tests.test_swift_protocol_dispatch { extract }
    graphify.swift_dispatch --> tests.test_swift_protocol_dispatch {
        resolve_swift_protocol_dispatch,
    }
    graphify.resolver_registry --> tests.test_swift_protocol_dispatch { registered_resolvers }
    graphify.extract --> tests.test_swift_protocol_requirements { extract_swift }
    graphify.extract --> tests.test_swift_self_type_ref { extract }
    graphify.extract --> tests.test_swift_underscore_ids { extract }
    graphify.symbol_resolution --> tests.test_symbol_resolution;
    graphify.symbol_resolution --> tests.test_symbol_resolution {
        _bash_make_id,
        build_label_index,
        build_python_symbol_index,
        find_unique_python_symbol,
        iter_raw_calls,
        node_is_resolvable_symbol,
        normalise_callable_label,
        parse_python_import_aliases,
        resolve_bash_source_edges,
        resolve_cross_file_raw_calls,
        resolve_python_import_guided_calls,
    }
    graphify.extract --> tests.test_symbol_resolution { _make_id }
    graphify.build --> tests.test_symlinked_root_source_file { build_from_json, build_merge }
    graphify.cluster --> tests.test_symlinked_root_source_file { cluster }
    graphify.export --> tests.test_symlinked_root_source_file { to_json }
    graphify.extract --> tests.test_symlinked_root_source_file { extract }
    graphify.build --> tests.test_terraform { build_from_json }
    graphify.extract --> tests.test_terraform { extract_terraform }
    graphify.serve --> tests.test_terraform { _load_graph, _query_graph_text, _subgraph_to_text }
    graphify.export --> tests.test_terraform { to_json }
    graphify.extractors.terraform --> tests.test_terraform { _redact_value }
    graphify.build --> tests.test_terraform_modules { build_from_json }
    graphify.extract --> tests.test_terraform_modules;
    graphify.extract --> tests.test_terraform_modules { _DISPATCH, extract, extract_terraform }
    graphify.extractors.terraform --> tests.test_terraform_modules { prepare_terraform }
    graphify.cache --> tests.test_terraform_modules;
    graphify.cache --> tests.test_terraform_modules { load_cached, save_cached }
    graphify.watch --> tests.test_terraform_modules { _rebuild_code }
    graphify.extract --> tests.test_trailing_newline_not_a_syntax_error {
        extract,
        extract_c,
        extract_cpp,
    }
    graphify.transcribe --> tests.test_transcribe {
        VIDEO_EXTENSIONS,
        build_whisper_prompt,
        transcribe,
        transcribe_all,
    }
    graphify.tree_html --> tests.test_tree_html { build_tree }
    graphify.__main__ --> tests.test_truncation_full_answer;
    graphify.serve --> tests.test_truncation_full_answer { _cut_lines_to_budget, _subgraph_to_text }
    graphify.extract --> tests.test_ts_abstract_methods { extract }
    graphify.extract --> tests.test_ts_decorator_chains { _file_stem, _make_id, extract }
    graphify.extract --> tests.test_ts_decorators { _file_stem, _make_id, extract }
    graphify.extract --> tests.test_ts_export_type_star { _normalize_ts_export_type_star, extract }
    graphify.extract --> tests.test_ts_generators { _file_stem, _make_id, extract }
    graphify.extract --> tests.test_ts_import_require { _file_node_id, _make_id, extract }
    graphify.extract --> tests.test_ts_import_type_arguments { _normalize_ts_import_types, extract }
    graphify.extract --> tests.test_ts_inheritance { _file_stem, _make_id, extract }
    graphify.extract --> tests.test_ts_namespace { _file_stem, _make_id, extract }
    graphify.extract --> tests.test_ts_new_expression_calls { extract, extract_js }
    graphify.extract --> tests.test_ts_parse_warning { extract }
    graphify.extract --> tests.test_ts_receiver_member_calls { extract }
    graphify.extract --> tests.test_tsconfig_declaration_targets { collect_files, extract }
    graphify.build --> tests.test_tsconfig_declaration_targets { build_from_json }
    graphify.analyze --> tests.test_type_only_import_cycles { find_import_cycles }
    graphify.build --> tests.test_type_only_import_cycles { build_from_json, dedupe_edges }
    graphify.extract --> tests.test_type_only_import_cycles { extract }
    graphify.extract --> tests.test_typescript_enum_members { extract }
    graphify.detect --> tests.test_typescript_module_extensions { CODE_EXTENSIONS }
    graphify.analyze --> tests.test_typescript_module_extensions { _LANG_FAMILY }
    graphify.extract --> tests.test_typescript_module_extensions {
        _DISPATCH,
        _JS_CACHE_BYPASS_SUFFIXES,
        _JS_RESOLVE_EXTS,
        extract_js,
    }
    graphify.detect --> tests.test_unc_probe_guard;
    graphify.extractors.bash --> tests.test_unc_probe_guard;
    graphify.extractors.base --> tests.test_unc_probe_guard { set_active_scan_root }
    graphify.analyze --> tests.test_undirected_two_file_import_cycle { find_import_cycles }
    graphify.build --> tests.test_undirected_two_file_import_cycle { build_from_json }
    graphify.export --> tests.test_undirected_two_file_import_cycle { to_json }
    graphify.extract --> tests.test_undirected_two_file_import_cycle { extract }
    graphify.watch --> tests.test_undirected_two_file_import_cycle { _rebuild_code }
    graphify.install --> tests.test_uninstall_global_registration;
    graphify.install --> tests.test_uninstall_global_registration {
        _SKILL_REGISTRATION_MARKER,
        claude_uninstall,
        codebuddy_uninstall,
        install,
        uninstall_all,
    }
    graphify.hooks --> tests.test_uninstall_purge_safety;
    graphify.install --> tests.test_uninstall_purge_safety;
    graphify.paths --> tests.test_uninstall_purge_safety;
    graphify.install --> tests.test_uninstall_scope {
        _project_uninstall,
        claude_uninstall,
        codebuddy_uninstall,
        gemini_install,
        gemini_uninstall,
    }
    graphify.install --> tests.test_uninstall_symlink {
        _AGENTS_MD_MARKER,
        _CLAUDE_MD_MARKER,
        _CODEBUDDY_MD_MARKER,
        _GEMINI_MD_MARKER,
        _SKILL_REGISTRATION_MARKER,
        _VSCODE_INSTRUCTIONS_MARKER,
        _agents_uninstall,
        _remove_claude_skill_registration,
        claude_uninstall,
        codebuddy_uninstall,
        gemini_uninstall,
        vscode_uninstall,
    }
    graphify.extract --> tests.test_unmapped_at_alias_resolution {
        _make_id,
        _resolve_rescued_specifier,
        extract,
    }
    graphify.extractors.resolution --> tests.test_unmapped_at_alias_resolution {
        _resolve_js_import_target,
        _resolve_js_module_path,
    }
    graphify.__main__ --> tests.test_unverified_semantic_shrink;
    graphify.build --> tests.test_unverified_semantic_shrink { build_merge, merge_raw_extraction }
    graphify.llm --> tests.test_unverified_semantic_shrink;
    graphify.cache --> tests.test_unverified_semantic_shrink {
        _resolve_prompt_fp,
        cache_dir,
        file_hash,
        load_cached,
    }
    graphify.extract --> tests.test_update_incremental;
    graphify.watch --> tests.test_update_incremental { _rebuild_code }
    graphify.extract --> tests.test_update_js_resolution_inputs;
    graphify.watch --> tests.test_update_js_resolution_inputs { _rebuild_code }
    graphify.extract --> tests.test_update_lock_contention;
    graphify.watch --> tests.test_update_lock_contention {
        _drain_pending,
        _drain_pending_full,
        _drain_pending_incremental,
        _queue_pending,
        _queue_pending_full,
        _rebuild_code,
        _rebuild_lock,
    }
    graphify.detect --> tests.test_update_manifest_preservation {
        detect_incremental,
        load_manifest,
        save_manifest,
    }
    tools.skillgen.gen --> tests.test_update_manifest_preservation;
    graphify.watch --> tests.test_update_missing_graph { _rebuild_code }
    graphify.extract --> tests.test_update_no_change_gate;
    graphify.watch --> tests.test_update_no_change_gate;
    graphify.watch --> tests.test_update_no_change_gate {
        _inputs_unchanged,
        _rebuild_code,
        _scan_digest,
        _write_build_state,
    }
    graphify.detect --> tests.test_update_no_change_gate { detect, load_manifest }
    graphify.exporters.html --> tests.test_update_no_change_gate { _HTML_STALE_MARKER }
    tools.skillgen.gen --> tests.test_update_partial_manifest;
    graphify.validate --> tests.test_validate { assert_valid, validate_extraction }
    graphify.build --> tests.test_validate { build, build_from_json }
    graphify.extract --> tests.test_variadic_param_refs { extract }
    graphify.extract --> tests.test_vbnet_extractor { cache_salt, extract }
    graphify.validate --> tests.test_vbnet_extractor { validate_extraction }
    graphify.cache --> tests.test_vbnet_extractor;
    graphify.cache --> tests.test_vbnet_extractor { save_cached }
    graphify.extractors.vbnet --> tests.test_vbnet_extractor { extract_vbnet }
    graphify.detect --> tests.test_vue_extraction { CODE_EXTENSIONS }
    graphify.extract --> tests.test_vue_extraction {
        _make_id,
        _vue_mask_non_script,
        extract,
        extract_vue,
    }
    graphify.extractors.resolution --> tests.test_walk_python_tree_iterative { _walk_python_tree }
    graphify.watch --> tests.test_watch;
    graphify.watch --> tests.test_watch {
        _PENDING_FILENAME,
        _PENDING_FULL_FILENAME,
        _WATCHED_EXTENSIONS,
        _batch_needs_llm_flag,
        _batch_triggers_rebuild,
        _check_shrink,
        _drain_pending,
        _is_read_only_event,
        _is_remote_source,
        _merge_changed_paths,
        _notify_only,
        _observer_accepts_event_filter,
        _queue_pending,
        _rebase_relative_source_files,
        _rebuild_code,
        _rebuild_lock,
        _reconcile_existing_graph,
        _reconcile_graph_html,
        _relativize_source_files,
        _watch_event_filter,
        _write_build_config,
        check_update,
        watch,
    }
    graphify.cluster --> tests.test_watch;
    graphify.cluster --> tests.test_watch { community_member_sigs }
    graphify.detect --> tests.test_watch;
    graphify.detect --> tests.test_watch { detect }
    graphify.extract --> tests.test_watch;
    graphify.build --> tests.test_watch_identity_cache { _norm_source_file }
    graphify.watch --> tests.test_watch_identity_cache;
    graphify.watch --> tests.test_watch_identity_cache { _StoredSourcePaths }
    graphify.watch --> tests.test_watch_inotify_overflow { _watch_event_filter }
    graphify.watch --> tests.test_watch_manifest_location { _rebuild_code }
    graphify.detect --> tests.test_watch_manifest_location { detect_incremental }
    graphify.watch --> tests.test_watch_pruned;
    graphify.__main__ --> tests.test_wheel_packaging { _PLATFORM_CONFIG }
    graphify.wiki --> tests.test_wiki { _community_article, _god_node_article, _index_md, to_wiki }
    graphify.wiki --> tests.test_wiki_case_only_relabel { to_wiki }
    graphify.wiki --> tests.test_wiki_link_filename_parity { _safe_filename, to_wiki }
    graphify.wiki --> tests.test_wiki_truncation_indicator { _god_node_article }
    graphify.cache --> tests.test_word_count_cache;
    graphify.extract --> tests.test_workers_by_work_size;
    graphify.extract --> tests.test_workers_by_work_size { _BYTES_PER_WORKER, _default_max_workers }
    graphify.detect --> tests.test_yaml_extraction { FileType, classify_file }
    graphify.extractors.yaml_config --> tests.test_yaml_extraction {
        _file_stem,
        _make_id,
        extract_yaml,
    }
    graphify.extract --> tests.test_zero_node_no_cache;
    graphify.cache --> tests.test_zero_node_no_cache { load_cached }
    tools.skillgen.gen --> tools.skillgen.__main__ { main }
    graphify.ids ++> graphify.manifest_ingest { make_id }
    graphify.security ++> graphify.paths { check_graph_file_size_cap }
    graphify.paths ++> graphify.security { GRAPHIFY_OUT, GRAPHIFY_OUT_NAME }
    graphify.paths ++> graphify.cluster { write_json_atomic }
    graphify.paths ++> graphify.transcribe { out_path as _out_path }
    graphify.security ++> graphify.transcribe { validate_url }
    graphify.security ++> graphify.ingest { safe_fetch, safe_fetch_text, validate_url }
    graphify.transcribe ++> graphify.ingest { download_audio }
    graphify.ingest ++> graphify.reflect { OUTCOMES }
    graphify.paths ++> graphify.reflect { GRAPHIFY_OUT_NAME }
    graphify.paths ++> graphify.callflow_html {
        GRAPHIFY_OUT,
        GRAPHIFY_OUT_NAME,
        load_node_link_graph,
    }
    graphify.security ++> graphify.callflow_html { check_graph_file_size_cap }
    graphify.paths ++> graphify.wiki { stem_filename_budget, write_text_atomic_if_changed }
    graphify.security ++> graphify.scip_ingest { sanitize_metadata }
    graphify.paths ++> graphify.cache {
        GRAPHIFY_OUT as _GRAPHIFY_OUT,
        os_long_path as _os_long_path,
        stash_preread_bytes as _stash_preread_bytes,
        os_replace_with_fallback as _os_replace_with_fallback,
    }
    graphify.ids ++> graphify.cache { normalize_id }
    graphify.detect ++> graphify.cache { IMAGE_EXTENSIONS }
    graphify.google_workspace ++> graphify.detect {
        GOOGLE_WORKSPACE_EXTENSIONS,
        convert_google_workspace_file,
        google_workspace_enabled,
    }
    graphify.paths ++> graphify.detect {
        GRAPHIFY_OUT,
        GRAPHIFY_OUT_NAME,
        os_long_path,
        out_path,
        write_json_atomic,
    }
    graphify.rcfile ++> graphify.detect {
        activate_language_overrides,
        cache_salt,
        effective_suffix,
    }
    graphify.manifest_ingest ++> graphify.detect { is_package_manifest_path }
    graphify.cache as _cache ++> graphify.detect;
    graphify.detect ++> graphify.rcfile { CODE_EXTENSIONS, DOC_EXTENSIONS }
    graphify.ids ++> graphify.extractors.base { make_id }
    graphify.paths ++> graphify.extractors.base { take_preread_bytes as _take_preread_bytes }
    graphify.extractors.base ++> graphify.file_slice { _read_source_text }
    graphify.detect ++> graphify.file_slice { extract_pdf_text }
    graphify.detect ++> graphify.cargo_introspect { _is_noise_dir }
    graphify.rcfile ++> graphify.interface_dispatch { effective_suffix }
    graphify.interface_dispatch ++> graphify.csharp_dispatch { resolve_interface_dispatch }
    graphify.extractors.base ++> graphify.extractors.blade { _make_id, _read_source_text }
    graphify.extractors.base ++> graphify.extractors.csharp { _make_id }
    graphify.rcfile ++> graphify.extractors.csharp { effective_suffix }
    graphify.extractors.base ++> graphify.extractors.python_scope { _read_text }
    graphify.extractors.base ++> graphify.extractors.sln { _make_id, _read_source_text }
    graphify.extractors.base ++> graphify.extractors.terraform { _make_id, _read_source_bytes }
    graphify.security ++> graphify.extractors.terraform {
        REDACTED_MARKER,
        _CONTROL_CHAR_RE,
        _METADATA_MAX_ATTRIBUTES,
        _METADATA_MAX_LIST_ITEMS,
        _METADATA_MAX_VALUE_LEN,
    }
    graphify.interface_dispatch ++> graphify.go_dispatch {
        declared_in,
        method_label,
        resolve_interface_dispatch,
    }
    graphify.interface_dispatch ++> graphify.kotlin_dispatch { resolve_interface_dispatch }
    graphify.extractors.base ++> graphify.pascal_singleton_resolution { _make_id }
    graphify.rcfile ++> graphify.resolver_registry { effective_suffix }
    graphify.interface_dispatch ++> graphify.swift_dispatch { resolve_interface_dispatch }
    graphify.extractors.csharp ++> graphify.cross_repo_calls { CsharpNameResolver }
    graphify.rcfile ++> graphify.hooks { load_graphifyrc }
    graphify.paths ++> graphify.hooks { GRAPHIFY_OUT }
    graphify.paths ++> graphify.install {
        GRAPHIFY_OUT as _GRAPHIFY_OUT,
        os_replace_with_fallback as _os_replace_with_fallback,
        write_text_atomic as _write_text_atomic,
    }
    graphify.hooks ++> graphify.install { uninstall as hook_uninstall }
    include graphify.detect ++> graphify.manifest {
        save_manifest,
        load_manifest,
        detect_incremental,
    }
}
