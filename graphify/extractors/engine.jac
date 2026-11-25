import builtins;

import operator;
import from __future__ { annotations }

import hashlib;

import importlib;

import json;

import re;

import threading;

import from unicodedata { normalize }

import from pathlib { Path }

import from typing { TYPE_CHECKING }

def _csharp_namespace_id(dotted_name: str) -> str;

glob _JSX_ELEMENT_TYPES: any;

glob REFERENCE_CONTEXTS: any;

glob _PYTHON_TYPE_CONTAINERS: any;

glob _PYTHON_ANNOTATION_NOISE: any;

glob _PYTHON_DECORATOR_NOISE: any;

glob _PYTHON_PROPERTY_ACCESSOR_SUFFIXES: any;

glob _CSHARP_TYPE_DECLARATIONS: any;

glob _CSHARP_TYPE_PARAMETER_SCOPE_DECLARATIONS: any;

glob _JAVA_TYPE_PARAMETER_SCOPE_DECLARATIONS: any;

glob _JAVA_BUILTIN_TYPES: any;

glob _JAVA_NAMED_BINDINGS: any;

glob _JAVA_LISTED_BINDINGS: any;

glob _KOTLIN_BUILTIN_TYPES: any;

glob _PY_TYPE_ALIAS_ANNOTATIONS: any;

glob _PY_NEW_TYPE_CALLEES: any;

glob _JS_PRIVATE_MEMBER_PREFIXES: any;

glob _JS_MEMBER_METHOD_TYPES: any;

glob _JAVA_MEMBER_CALLABLE_TYPES: any;

glob _JAVA_LOMBOK_IMPORT_RE: any;

glob _JAVA_TYPE_PARAM_OWNERS: any;

glob _KOTLIN_MEMBER_BODY_TYPES: any;

glob _SWIFT_TYPE_DECL_TYPES: any;

glob _SWIFT_TYPE_NAME_TYPES: any;

glob _SWIFT_MEMBER_CALLABLE_TYPES: any;

glob _RUBY_MEMBER_CALLABLE_TYPES: any;

glob _SCALA_OWNER_TYPES: any;

glob _SCALA_MEMBER_CALLABLE_TYPES: any;

glob _SCALA_PRIVATE_MEMBER_SUFFIXES: any;

glob _CPP_PRIVATE_MEMBER_PREFIXES: any;

glob _CPP_PRIVATE_MEMBER_SUFFIXES: any;

glob _C_PRIMITIVE_TYPE_NODES: any;

glob _METAL_TYPE_QUALIFIER_KEYWORDS: frozenset[str];

glob _CUDA_TYPE_QUALIFIER_KEYWORDS: frozenset[str];

glob _CPP_DIALECT_TYPE_QUALIFIERS: dict[str, frozenset[str]];

glob _PYTEST_FIXTURE_DECORATORS: any;

glob _PYTHON_ITERATOR_WRAPPERS: any;

glob PYTEST_FIXTURE_UNTYPED: any;

glob _SELF_CALL_LANGUAGES: any;

glob _LEXICAL_CALL_LANGUAGES: any;

glob _PYTHON_PROPERTY_DECORATORS: any;

glob _JS_SCOPE_BOUNDARY: any;

glob _CSHARP_LOOP_SEQUENCES: any;

glob _CSHARP_LOOP_DICTIONARIES: any;

glob _TS_STATIC_SUFFIX: any;

glob _TS_FUNCTION_NODES: any;

glob _JS_FUNCTION_VALUE_TYPES: any;

glob _KOTLIN_IDENTIFIERS: any;

glob _RUBY_LOOKUP_MUTATORS: any;

glob _RUBY_EXTERNAL_OWNER_MUTATORS: any;

glob _RUBY_CLASS_FACTORIES: any;

glob _PHP_ROUTING_VERBS: any;

glob _PHP_LANGUAGE_CONSTRUCTS: any;

glob _parser_tls: any;

with entry {
    _JSX_ELEMENT_TYPES = frozenset({"jsx_opening_element", "jsx_self_closing_element"});

    REFERENCE_CONTEXTS = frozenset({
        "field",
        "parameter_type",
        "return_type",
        "generic_arg",
        "attribute",
        "value",
        "type",
    });
}

def _source_location(line: int | str | None) -> str | None;

def _semantic_reference_edge(
    source: str, target: str, context: str, source_file: str, line: int | str | None
) -> dict;

with entry {
    _PYTHON_TYPE_CONTAINERS = frozenset({
        "list",
        "dict",
        "set",
        "tuple",
        "frozenset",
        "type",
        "List",
        "Dict",
        "Set",
        "Tuple",
        "FrozenSet",
        "Type",
        "Optional",
        "Union",
        "Sequence",
        "Iterable",
        "Mapping",
        "MutableMapping",
        "Iterator",
        "Callable",
        "Awaitable",
        "AsyncIterable",
        "AsyncIterator",
        "Coroutine",
        "Generator",
        "AsyncGenerator",
        "ContextManager",
        "AsyncContextManager",
        "Annotated",
        "ClassVar",
        "Final",
        "Literal",
        "Concatenate",
        "ParamSpec",
        "TypeVar",
        "None",
        "Ellipsis",
        "Self",
    });

    _PYTHON_ANNOTATION_NOISE = frozenset({
        "str",
        "int",
        "float",
        "bool",
        "bytes",
        "bytearray",
        "complex",
        "object",
        "True",
        "False",
        "MagicMock",
        "Mock",
        "AsyncMock",
        "NonCallableMock",
        "NonCallableMagicMock",
        "PropertyMock",
        "patch",
        "sentinel",
    });
    _PYTHON_DECORATOR_NOISE = frozenset({
        "property",
        "staticmethod",
        "classmethod",
        "abstractmethod",
        "abstractproperty",
        "cached_property",
        "wraps",
        "lru_cache",
        "cache",
        "singledispatch",
        "singledispatchmethod",
        "total_ordering",
        "contextmanager",
        "asynccontextmanager",
        "overload",
        "override",
        "final",
        "no_type_check",
        "runtime_checkable",
        "dataclass",
    });
    _PYTHON_PROPERTY_ACCESSOR_SUFFIXES = (".setter", ".getter", ".deleter");
}

def _python_collect_type_refs(`node, source: bytes, generic: bool, out: list[tuple[str, str]]);
def _csharp_pre_scan_interfaces(root_node, source: bytes) -> set[str];

with entry {
    _CSHARP_TYPE_DECLARATIONS = frozenset({
        "class_declaration",
        "interface_declaration",
        "enum_declaration",
        "struct_declaration",
        "record_declaration",
    });
}

def _csharp_type_name_for_id(`node, class_name: str) -> str;
def _csharp_explicit_interface_name(specifier: str) -> str;
def _csharp_method_signature(`node, source: bytes, params=None) -> tuple[str, dict];
def _csharp_argc(call_node) -> int | None;
def _csharp_creation_argc(`node) -> int;
def _csharp_pick_overload(overloads: list[dict], argc: int | None) -> dict | None;
def _csharp_pre_scan_name_collisions(
    root_node, source: bytes, stem: str
) -> tuple[dict[str, set[str]], dict[str, set[str]], set[str]];
def _csharp_classify_base(name: str, interface_names: set[str]) -> str;

with entry {
    _CSHARP_TYPE_PARAMETER_SCOPE_DECLARATIONS = frozenset({
        "class_declaration",
        "interface_declaration",
        "record_declaration",
        "struct_declaration",
        "method_declaration",
    });
}

def _csharp_type_parameters_in_scope(`node, source: bytes) -> frozenset[str];
def _csharp_collect_type_refs(
    `node,
    source: bytes,
    generic: bool,
    out: list[tuple[str, str, bool, str]],
    `skip: frozenset[str] | None = None,
);
def _csharp_attribute_names(method_node, source: bytes) -> list[tuple[str, bool, str]];

with entry {
    _JAVA_TYPE_PARAMETER_SCOPE_DECLARATIONS = frozenset({
        "class_declaration",
        "interface_declaration",
        "record_declaration",
        "method_declaration",
        "constructor_declaration",
    });
}

def _java_type_parameters_in_scope(`node, source: bytes) -> frozenset[str];

with entry {
    _JAVA_BUILTIN_TYPES = frozenset({
        "Object",
        "String",
        "CharSequence",
        "StringBuilder",
        "StringBuffer",
        "Number",
        "Byte",
        "Short",
        "Integer",
        "Long",
        "Float",
        "Double",
        "Boolean",
        "Character",
        "Void",
        "Class",
        "Enum",
        "Record",
        "Math",
        "System",
        "Thread",
        "Runnable",
        "Comparable",
        "Iterable",
        "Cloneable",
        "AutoCloseable",
        "Appendable",
        "Readable",
        "Process",
        "ProcessBuilder",
        "Runtime",
        "Package",
        "ThreadLocal",
        "InheritableThreadLocal",
        "Throwable",
        "Exception",
        "RuntimeException",
        "Error",
        "IllegalArgumentException",
        "IllegalStateException",
        "NullPointerException",
        "IndexOutOfBoundsException",
        "ArrayIndexOutOfBoundsException",
        "ClassCastException",
        "NumberFormatException",
        "ArithmeticException",
        "UnsupportedOperationException",
        "InterruptedException",
        "CloneNotSupportedException",
        "SecurityException",
        "StackOverflowError",
        "OutOfMemoryError",
        "AssertionError",
        "Collection",
        "List",
        "ArrayList",
        "LinkedList",
        "Vector",
        "Stack",
        "Set",
        "HashSet",
        "LinkedHashSet",
        "TreeSet",
        "SortedSet",
        "NavigableSet",
        "EnumSet",
        "Map",
        "HashMap",
        "LinkedHashMap",
        "TreeMap",
        "SortedMap",
        "NavigableMap",
        "Hashtable",
        "EnumMap",
        "Properties",
        "Queue",
        "Deque",
        "ArrayDeque",
        "PriorityQueue",
        "Iterator",
        "ListIterator",
        "Comparator",
        "Optional",
        "OptionalInt",
        "OptionalLong",
        "OptionalDouble",
        "Collections",
        "Arrays",
        "Objects",
        "Date",
        "Calendar",
        "Random",
        "UUID",
        "Scanner",
        "StringJoiner",
        "StringTokenizer",
        "BitSet",
        "Spliterator",
        "Locale",
        "NoSuchElementException",
        "ConcurrentModificationException",
        "Stream",
        "IntStream",
        "LongStream",
        "DoubleStream",
        "Collector",
        "Collectors",
        "Function",
        "BiFunction",
        "Consumer",
        "BiConsumer",
        "Supplier",
        "Predicate",
        "BiPredicate",
        "UnaryOperator",
        "BinaryOperator",
        "IntFunction",
        "ToIntFunction",
        "ToLongFunction",
        "ToDoubleFunction",
        "Callable",
        "Future",
        "CompletableFuture",
        "CompletionStage",
        "Executor",
        "ExecutorService",
        "Executors",
        "ScheduledExecutorService",
        "TimeUnit",
        "ConcurrentHashMap",
        "ConcurrentMap",
        "CopyOnWriteArrayList",
        "BlockingQueue",
        "CountDownLatch",
        "Semaphore",
        "CyclicBarrier",
        "AtomicInteger",
        "AtomicLong",
        "AtomicBoolean",
        "AtomicReference",
        "Instant",
        "Duration",
        "Period",
        "LocalDate",
        "LocalTime",
        "LocalDateTime",
        "ZonedDateTime",
        "OffsetDateTime",
        "ZoneId",
        "ZoneOffset",
        "DayOfWeek",
        "Month",
        "Year",
        "Clock",
        "DateTimeFormatter",
        "IOException",
        "UncheckedIOException",
        "FileNotFoundException",
        "File",
        "InputStream",
        "OutputStream",
        "Reader",
        "Writer",
        "BufferedReader",
        "BufferedWriter",
        "InputStreamReader",
        "OutputStreamWriter",
        "FileReader",
        "FileWriter",
        "PrintStream",
        "PrintWriter",
        "ByteArrayInputStream",
        "ByteArrayOutputStream",
        "Serializable",
        "Closeable",
        "Path",
        "Paths",
        "Files",
        "BigDecimal",
        "BigInteger",
    });
}

def _java_collect_type_refs(
    `node,
    source: bytes,
    generic: bool,
    out: list[tuple[str, str]],
    `skip: frozenset[str] | None = None,
    preserve_qualified: bool = False,
);
def _java_receiver_type_name(type_node, source: bytes) -> str | None;
def _java_receiver_chain(`node, source: bytes, depth: int = 0) -> list | None;
def _java_type_chain_leaf(
    chain: list,
    receiver_types: dict,
    bound_names: set[str] | None = None,
    field_names: set[str] | None = None,
) -> list | None;

def _java_declarator_names(declaration_node, source: bytes) -> list[str];

with entry {
    _JAVA_NAMED_BINDINGS = frozenset({
        "formal_parameter",
        "variable_declarator",
        "enhanced_for_statement",
        "resource",
        "catch_formal_parameter",
        "instanceof_expression",
    });
    _JAVA_LISTED_BINDINGS = frozenset({
        "inferred_parameters",
        "record_pattern_component",
        "type_pattern",
    });
}

def _java_bound_names(method_node, source: bytes) -> set[str];

def _java_lambda_parameters(lambda_node, source: bytes) -> list[tuple[str, str | None]];
def _java_method_receiver_types(
    method_node, source: bytes, field_types: dict[str, str]
) -> dict[str, str];
def _java_has_modifier(declaration_node, modifier: str) -> bool;
def _java_annotation_nodes(declaration_node) -> list;
def _java_annotation_names(declaration_node, source: bytes) -> list[tuple[str, str]];
def _java_annotation_class_literal_refs(declaration_node, source: bytes) -> list[str];
def _php_name_text(`node, source: bytes) -> str | None;
def _php_collect_type_refs(`node, source: bytes, generic: bool, out: list[tuple[str, str]]);
def _php_declared_type_name(`node, source: bytes) -> str | None;
def _php_variable_text(`node, source: bytes) -> str | None;
def _php_first_declared_type(`node, source: bytes) -> str | None;
def _php_receiver_type_table(`root, source: bytes, table: dict[str, str]);
def _php_method_return_type_node(method_node) -> any;

with entry {
    _KOTLIN_BUILTIN_TYPES = frozenset({
        "Any",
        "Unit",
        "Nothing",
        "Boolean",
        "Byte",
        "Short",
        "Int",
        "Long",
        "Float",
        "Double",
        "Char",
        "String",
        "CharSequence",
        "Number",
        "Comparable",
        "Enum",
        "Annotation",
        "Pair",
        "Triple",
        "Lazy",
        "Function",
        "Throwable",
        "Exception",
        "RuntimeException",
        "Error",
        "IllegalArgumentException",
        "IllegalStateException",
        "NullPointerException",
        "IndexOutOfBoundsException",
        "ClassCastException",
        "NumberFormatException",
        "ArithmeticException",
        "UnsupportedOperationException",
        "NoSuchElementException",
        "ConcurrentModificationException",
        "StackOverflowError",
        "OutOfMemoryError",
        "AssertionError",
        "InterruptedException",
        "Array",
        "List",
        "MutableList",
        "ArrayList",
        "Set",
        "MutableSet",
        "HashSet",
        "LinkedHashSet",
        "Map",
        "MutableMap",
        "HashMap",
        "LinkedHashMap",
        "Collection",
        "MutableCollection",
        "Iterable",
        "MutableIterable",
        "Iterator",
        "MutableIterator",
        "ListIterator",
        "MutableListIterator",
        "Sequence",
        "Comparator",
        "Regex",
        "MatchResult",
        "StringBuilder",
    });
}

def _kotlin_user_type_name(user_type_node, source: bytes) -> str | None;
def _kotlin_annotation_names(declaration_node, source: bytes) -> list[tuple[str, str]];
def _kotlin_annotation_class_literal_refs(declaration_node, source: bytes) -> list[str];
def _kotlin_type_parameters_in_scope(`node, source: bytes) -> frozenset[str];
def _kotlin_collect_type_refs(
    `node,
    source: bytes,
    generic: bool,
    out: list[tuple[str, str]],
    `skip: frozenset[str] | None = None,
);
def _kotlin_property_type_node(property_node) -> any;
def _kotlin_function_return_type_node(func_node) -> any;
def _swift_declaration_keyword(`node) -> str | None;

with entry {
    _PY_TYPE_ALIAS_ANNOTATIONS = frozenset({
        "TypeAlias",
        "typing.TypeAlias",
        "typing_extensions.TypeAlias",
    });
    _PY_NEW_TYPE_CALLEES = frozenset({"NewType", "typing.NewType", "typing_extensions.NewType"});
}

def _python_alias_name(stmt, source: bytes) -> str | None;
def _python_pre_scan_underscore_collisions(
    root_node, source: bytes, stem: str
) -> dict[str, set[str]];
def _underscore_salted_nid(
    plain_nid: str,
    name: str,
    groups: dict[str, set[str]],
    private_prefixes: tuple[str, ...] = ("_",),
    private_suffixes: tuple[str, ...] = (),
    leaf=None,
) -> str;

with entry {
    _JS_PRIVATE_MEMBER_PREFIXES = ("_", "$", "#");
    _JS_MEMBER_METHOD_TYPES = (
        "method_definition",
        "method_signature",
        "abstract_method_signature",
    );
}

def _js_member_nid(
    class_nid: str, member_node, name: str, source: bytes, groups_cache: dict
) -> str;
def _php_member_nid(
    class_nid: str, member_node, name: str, source: bytes, groups_cache: dict
) -> str;

with entry {
    _JAVA_MEMBER_CALLABLE_TYPES = ("method_declaration", "constructor_declaration");

    _JAVA_LOMBOK_IMPORT_RE = re.compile(
        b"^\\s*import\\s+lombok\\s*\\.\\s*(?:Getter|\\*)\\s*;", re.MULTILINE
    );
}

def _java_lombok_getter_annotation(declaration_node, source: bytes) -> any;
def _java_lombok_getters(field_node, source: bytes) -> list[str];
def _java_member_nid(
    class_nid: str, member_node, name: str, source: bytes, groups_cache: dict
) -> str;
def _java_erase_type(text: str) -> str;

with entry {
    _JAVA_TYPE_PARAM_OWNERS = frozenset({
        "class_declaration",
        "interface_declaration",
        "record_declaration",
        "enum_declaration",
        "method_declaration",
        "constructor_declaration",
    });
}

def _java_type_var_bounds(`node, source: bytes) -> dict[str, str];
def _java_erase_type_var(text: str, bounds: dict[str, str]) -> str;
def _java_method_signature(`node, source: bytes) -> tuple[str, dict];
def _java_argc(call_node) -> int | None;

with entry {
    _KOTLIN_MEMBER_BODY_TYPES = ("class_body", "enum_class_body");
}

def _kotlin_function_name(`node, source: bytes) -> str;
def _kotlin_member_nid(
    class_nid: str, member_node, name: str, source: bytes, groups_cache: dict
) -> str;

with entry {
    _SWIFT_TYPE_DECL_TYPES = ("class_declaration", "protocol_declaration");
    _SWIFT_TYPE_NAME_TYPES = ("simple_identifier", "type_identifier", "user_type");
    _SWIFT_MEMBER_CALLABLE_TYPES = ("function_declaration", "protocol_function_declaration");
}

def _swift_type_decl_name(decl, source: bytes) -> str;
def _swift_member_nid(
    class_nid: str, member_node, name: str, source: bytes, groups_cache: dict
) -> str;

with entry {
    _RUBY_MEMBER_CALLABLE_TYPES = ("method", "singleton_method");
}

def _ruby_member_nid(
    class_nid: str, member_node, name: str, source: bytes, groups_cache: dict, sanitize
) -> str;
def _lua_field_name(name: str) -> str;

def _lua_field_leaf(name: str) -> str;
def _lua_pre_scan_field_collisions(`root, source: bytes, stem: str) -> dict[str, set[str]];

with entry {
    _SCALA_OWNER_TYPES = (
        "class_definition",
        "object_definition",
        "trait_definition",
        "enum_definition",
        "given_definition",
    );
    _SCALA_MEMBER_CALLABLE_TYPES = ("function_definition", "function_declaration");
    _SCALA_PRIVATE_MEMBER_SUFFIXES = ("_=",);
}

def _scala_member_nid(
    class_nid: str, member_node, name: str, source: bytes, groups_cache: dict
) -> str;

with entry {
    _CPP_PRIVATE_MEMBER_PREFIXES = ("_", "~");
    _CPP_PRIVATE_MEMBER_SUFFIXES = ("_",);
}

def _cpp_is_method_declarator(decl) -> bool;
def _cpp_member_nid(
    class_nid: str, member_node, name: str, source: bytes, groups_cache: dict
) -> str;
def _swift_pre_scan(root_node, source: bytes) -> tuple[set[str], set[str]];
def _swift_classify_base(
    name: str, kind: str | None, is_first: bool, protocols: set[str], classes: set[str]
) -> str;
def _swift_user_type_name(user_type_node, source: bytes) -> str | None;

def _swift_receiver_type_name(`node, source: bytes) -> str | None;
def _swift_type_parameters_in_scope(`node, source: bytes) -> frozenset[str];
def _swift_collect_type_refs(
    `node,
    source: bytes,
    generic: bool,
    out: list[tuple[str, str]],
    `skip: frozenset[str] | None = None,
);
def _swift_property_type_node(property_node) -> any;
def _swift_attribute_type_name(property_node, source: bytes) -> str | None;
def _swift_factory_call(call_node, source: bytes) -> tuple[str, str] | None;
def _swift_property_name(property_node, source: bytes) -> str | None;
def _swift_constructor_type(call_node, source: bytes) -> str | None;
def _swift_receiver_name(recv_node, source: bytes) -> str | None;
def _swift_operand_tail(`node) -> any;

with entry {
    _C_PRIMITIVE_TYPE_NODES = frozenset({
        "primitive_type",
        "sized_type_specifier",
        "auto",
        "placeholder_type_specifier",
    });
    _METAL_TYPE_QUALIFIER_KEYWORDS = frozenset({
        "kernel",
        "vertex",
        "fragment",
        "device",
        "constant",
        "threadgroup",
        "threadgroup_imageblock",
        "thread",
        "ray_data",
        "object_data",
    });
    _CUDA_TYPE_QUALIFIER_KEYWORDS = frozenset({
        "__global__",
        "__device__",
        "__host__",
        "__shared__",
        "__constant__",
        "__managed__",
        "__restrict__",
        "__forceinline__",
        "__noinline__",
        "__grid_constant__",
        "__launch_bounds__",
    });
    _CPP_DIALECT_TYPE_QUALIFIERS = {
        ".metal": _METAL_TYPE_QUALIFIER_KEYWORDS,
        ".cu": _CUDA_TYPE_QUALIFIER_KEYWORDS,
        ".cuh": _CUDA_TYPE_QUALIFIER_KEYWORDS,
    };
}

def _c_collect_type_refs(`node, source: bytes, generic: bool, out: list[tuple[str, str]]);
def _cpp_type_parameters_in_scope(`node, source: bytes) -> frozenset[str];

class _CppStdName(builtins.str) {
    static has __slots__: any = ();
}

glob dialect_quals_default_: any;

with entry {
    dialect_quals_default_ = frozenset();
}

def _cpp_collect_type_refs(
    `node,
    source: bytes,
    generic: bool,
    out: list[tuple[str, str]],
    `skip: frozenset[str] | None = None,
    dialect_quals: frozenset[str] = dialect_quals_default_,
);
def _scala_given_synthetic_name(`node, source: bytes) -> str | None;
def _scala_type_parameters_in_scope(`node, source: bytes) -> frozenset[str];
def _scala_collect_type_refs(
    `node,
    source: bytes,
    generic: bool,
    out: list[tuple[str, str]],
    `skip: frozenset[str] | None = None,
);
def _scala_collect_context_bounds(tp_node, source: bytes, out: list[tuple[str, str]]);
def _python_collect_param_refs(params_node, source: bytes) -> list[tuple[str, str]];

with entry {
    _PYTEST_FIXTURE_DECORATORS = frozenset({"pytest.fixture", "fixture", "pytest_asyncio.fixture"});
    _PYTHON_ITERATOR_WRAPPERS = frozenset({
        "Iterator",
        "Iterable",
        "Generator",
        "AsyncIterator",
        "AsyncIterable",
        "AsyncGenerator",
    });
    PYTEST_FIXTURE_UNTYPED = "?";
}

def _python_is_pytest_fixture(func_node, source: bytes) -> bool;
def _python_base_name_node(arg) -> any;
def _python_annotation_class(type_node, source: bytes) -> str | None;
def _python_fixture_type(func_node, source: bytes, local_types: dict[str, str | None]) -> str;
def _python_untouched_params(func_node, source: bytes) -> set[str];

def _python_is_test_module(str_path: str) -> bool;
def _python_collect_assignment_targets(`node, source: bytes, out: set[str]);

with entry {
    _SELF_CALL_LANGUAGES = frozenset({
        "tree_sitter_python",
        "tree_sitter_javascript",
        "tree_sitter_typescript",
        "tree_sitter_swift",
        "tree_sitter_ruby",
        "tree_sitter_php",
    });
}

def _self_call_target(
    caller_nid: str,
    callee: str,
    receiver: str,
    label_to_nid: dict[str, str],
    scope_parents: dict[str, str],
    method_owner: dict[str, str],
    methods_by_owner: dict[tuple[str, str], str],
    class_bases: dict[str, list[str]],
    walk_bases: bool = True,
    require_method_owner: bool = False,
) -> str | None;

with entry {
    _LEXICAL_CALL_LANGUAGES = {
        "tree_sitter_java": ("inherits", "implements"),
        "tree_sitter_c_sharp": ("inherits", "implements"),
        "tree_sitter_scala": ("inherits", "mixes_in"),
        "tree_sitter_cpp": ("inherits",),
    };
}

def _lexical_class_bases(
    edges: list[dict],
    relations: tuple[str, ...],
    label_by_nid: dict[str, str],
    nid_to_sf: dict[str, str],
    method_owner: dict[str, str],
    methods_by_owner: dict[tuple[str, str], str],
    class_parent: dict[str, str],
    interfaces: set[str],
) -> dict[str, list[str]];
def _lexical_call_target(
    caller_nid: str,
    callee: str,
    label_to_nid: dict[str, str],
    method_owner: dict[str, str],
    methods_by_owner: dict[tuple[str, str], str],
    class_bases: dict[str, list[str]],
    class_parent: dict[str, str],
) -> str | None;
def _python_local_bound_names(func_def_node, source: bytes) -> set[str];
def _python_module_bound_names(`root, source: bytes) -> set[str];
def _python_receiver_shadow_checker(`root, source: bytes, *, module_bindings=None) -> any;
def _python_module_instance_types(`root, source: bytes) -> any;

with entry {
    _PYTHON_PROPERTY_DECORATORS = frozenset({
        "property",
        "cached_property",
        "functools.cached_property",
    });
}

def _python_is_property(func_node, source: bytes) -> bool;

def _same_node(a, b) -> bool;
def _python_attribute_is_store(`node) -> bool;
def _python_property_reads(
    function_bodies,
    source: bytes,
    str_path: str,
    var_types: dict[str, dict[str, str | None]],
    attr_types: dict[str, dict[str, str | None]],
    method_owner: dict[str, str],
) -> list[dict];
def _python_self_attr(`node, source: bytes) -> str | None;
def _python_self_attr_bindings(
    body, source: bytes, local_types: dict[str, str | None] | None = None
) -> Generator[any, any, any];

with entry {
    _JS_SCOPE_BOUNDARY = frozenset({
        "function_declaration",
        "function_expression",
        "function",
        "arrow_function",
        "method_definition",
        "class_declaration",
        "class",
        "generator_function",
        "generator_function_declaration",
    });
}

def _js_collect_pattern_idents(`node, source: bytes, bound: set);
def _js_local_bound_names(func_node, source: bytes) -> set[str];
def _js_direct_lexical_names(`node, source: bytes) -> frozenset[str];
def _js_enclosing_bound_names(`node, source: bytes) -> set[str];
def _js_receiver_shadowed(`node, name: str | None, source: bytes, bindings_by_scope: dict) -> bool;
def _js_module_bound_names(`root, source: bytes) -> set[str];
def _js_import_binds_external(raw: str, str_path: str) -> bool;
def _js_external_import_names(`root, source: bytes, str_path: str) -> set[str];
def _js_dispatch_value_idents(coll_node) -> Generator[any, any, any];
def _find_body(`node, config: LanguageConfig) -> any;
def _js_import_is_type_only(`node) -> bool;
def _dynamic_import_js(
    `node, source: bytes, caller_nid: str, str_path: str, edges: list, seen_dyn_pairs: set
) -> bool;
def _get_cpp_func_name(`node, source: bytes) -> str | None;
def _cpp_declarator_name(`node, source: bytes) -> str | None;
def _cpp_parameter_types(body_node, source: bytes, table: dict[str, str]);
def _cpp_field_types(`root, source: bytes, table: dict[str, str]);
def _cpp_is_header_guard(`node, source: bytes) -> bool;
def _cpp_lookup_scope(`node, source: bytes) -> str;
def _cpp_qualified_name(`node, name: str, source: bytes) -> str;
def _cpp_member_record(`node, declarator, name: str, source: bytes) -> dict;

def _cpp_plain_template_parameters(`node, source: bytes) -> list[str];
def _cpp_zero_arg_member_signature(`node, source: bytes) -> tuple | None;
def _cpp_primary_template_function_name(`node, source: bytes, classes: dict) -> str | None;
def _cpp_type_is_dependent(`node, source: bytes) -> bool;
def _cpp_declared_receiver_type(`node, declarator, source: bytes) -> str;
def _cpp_call_name(`node, source: bytes) -> str | None;
def _cpp_receiver_chain(`node, source: bytes) -> list[list[str]];
def _cpp_resolution_facts(
    `root, source: bytes
) -> tuple[list[dict], dict[str, int], dict[str, str]];
def _cpp_class_lookup_facts(`node, source: bytes) -> dict;

def _cpp_class_fields(`node, source: bytes, positions: dict[str, int]) -> dict[str, str];
def _cpp_local_binding_ranges(
    body, source: bytes
) -> dict[str, list[tuple[int, int, str, str, str, bool]]];
def _cpp_local_var_types(body_node, source: bytes, table: dict[str, str]);
def _swift_local_var_types(
    body_node,
    source: bytes,
    table: dict[str, str],
    factory: dict[str, tuple[str, str]] | None = None,
);
def _csharp_receiver_type_name(type_node, source: bytes) -> str | None;

with entry {
    _CSHARP_LOOP_SEQUENCES = frozenset({
        "List",
        "IList",
        "IReadOnlyList",
        "IEnumerable",
        "ICollection",
        "IReadOnlyCollection",
        "HashSet",
        "ISet",
        "SortedSet",
        "Queue",
        "Stack",
        "LinkedList",
    });
    _CSHARP_LOOP_DICTIONARIES = frozenset({
        "Dictionary",
        "IDictionary",
        "IReadOnlyDictionary",
        "SortedDictionary",
        "SortedList",
        "ConcurrentDictionary",
    });
}

def _csharp_loop_element_types(type_node, source: bytes) -> dict[str, str];
def _csharp_loop_source(expr, source: bytes) -> tuple[str, str] | None;
def _csharp_element_type_name(type_node, source: bytes) -> str | None;
def _csharp_return_info(method_node, source: bytes) -> list;
def _csharp_deferred_member(access, source: bytes) -> list | None;
def _csharp_deferred_call(invocation, source: bytes) -> list | None;
def _csharp_method_receiver_types(
    method_node, source: bytes, field_types: dict[str, str]
) -> tuple[dict[str, list[tuple[int, int, str | list | None]]], dict[str, str | None]];
def _csharp_scoped_receiver_type(
    table: tuple[dict[str, list[tuple[int, int, str | list | None]]], dict[str, str | None]] | None,
    name: str | None,
    call_byte: int,
) -> str | list | None;
def _csharp_receiver_is_declared(
    table: tuple[dict[str, list[tuple[int, int, str | list | None]]], dict[str, str | None]] | None,
    name: str,
    call_byte: int,
) -> bool;
def _ts_receiver_type_table(
    `root,
    source: bytes,
    table: dict[str, str],
    field_table: "dict[str, dict[str, str]] | None" = None,
);

with entry {
    _TS_STATIC_SUFFIX = "\x00static";
}

def _ts_attach_class_fields(result: dict, field_table: dict[str, dict[str, str]], str_path: str);
def _ts_in_static_method(`node) -> bool;

with entry {
    _TS_FUNCTION_NODES = frozenset({
        "arrow_function",
        "method_definition",
        "function_declaration",
        "function_expression",
        "generator_function_declaration",
        "generator_function",
    });
}

def _ts_field_destructured_from_this(ident, name: str, source: bytes) -> str | None;
def _find_require_call(value_node) -> any;
def _js_value_is_require(value_node, source: bytes) -> bool;
def _js_require_specifier(value_node, source: bytes) -> str | None;
def _js_require_resolves_locally(value_node, source: bytes, str_path: str) -> bool;
def _require_imports_js(
    `node, source: bytes, importer_nid: str, stem: str, edges: list, str_path: str
) -> bool;

with entry {
    _JS_FUNCTION_VALUE_TYPES = frozenset({
        "arrow_function",
        "function_expression",
        "function",
        "generator_function",
    });
}

def _scan_js_nested_function_declarations(
    container_node,
    parent_nid: str,
    *,
    source: bytes,
    config,
    add_node,
    add_edge,
    callable_def_nids: set | None,
    local_bound_names: dict | None,
    function_bodies: list,
    scope_parents: dict[str, str] | None = None,
    lexical_nids_by_scope: dict[str, dict[str, str]] | None = None,
);
def _scan_python_nested_function_declarations(
    container_node,
    parent_nid: str,
    *,
    source: bytes,
    config,
    add_node,
    add_edge,
    callable_def_nids: set | None,
    local_bound_names: dict | None,
    function_bodies: list,
    scope_parents: dict[str, str] | None = None,
    lexical_nids_by_scope: dict[str, dict[str, str]] | None = None,
);
def _js_topmost_closures(`node, out: list);
def _js_member_assignment_target(left, source: bytes) -> any;
def _js_scan_member_assignments(
    body,
    this_owner_nid: str,
    source: bytes,
    *,
    this_as_method: bool,
    add_node_fn,
    add_edge_fn,
    function_bodies: list,
    closure_locals_by_body: dict | None = None,
);
def _js_find_exported_objects(program_node, source: bytes) -> set[str];
def _js_extra_walk(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    str_path: str,
    nodes: list,
    edges: list,
    seen_ids: set,
    function_bodies: list,
    parent_class_nid: str | None,
    add_node_fn,
    add_edge_fn,
    callable_def_nids: set | None = None,
    local_bound_names: dict | None = None,
    closure_locals_by_body: dict | None = None,
    config=None,
    js_member_groups: dict | None = None,
    scope_parents: dict | None = None,
    lexical_nids_by_scope: dict | None = None,
    decl_node_fn=None,
    decl_lookup_fn=None,
) -> bool;
def _ts_extra_walk(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    str_path: str,
    nodes: list,
    edges: list,
    seen_ids: set,
    function_bodies: list,
    parent_class_nid: str | None,
    add_node_fn,
    add_edge_fn,
    walk_fn,
    decl_node_fn=None,
    namespace_stack: list[str] | None = None,
) -> bool;
def _csharp_scope_id(`node) -> str;

def _csharp_namespace_name(`node, source: bytes) -> str;
def _csharp_extra_walk(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    str_path: str,
    nodes: list,
    edges: list,
    seen_ids: set,
    function_bodies: list,
    parent_class_nid: str | None,
    add_node_fn,
    add_edge_fn,
    walk_fn,
    namespace_stack: list[str],
    scope_stack: list[str],
    member_groups: dict[str, set[str]] | None = None,
) -> bool;
def _swift_extra_walk(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    str_path: str,
    nodes: list,
    edges: list,
    seen_ids: set,
    function_bodies: list,
    parent_class_nid: str | None,
    add_node_fn,
    add_edge_fn,
    ensure_named_node_fn,
) -> bool;
def _scala_extension_receiver_name(`node, source: bytes) -> str | None;
def _scala_extra_walk(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    str_path: str,
    nodes: list,
    edges: list,
    seen_ids: set,
    function_bodies: list,
    parent_class_nid: str | None,
    add_node_fn,
    add_edge_fn,
    walk_fn,
    ensure_named_node_fn,
) -> bool;
def _cpp_declarator_type_name(declarator, source: bytes) -> str | None;
def _cpp_type_last_name(type_node, source: bytes) -> str | None;
def _cpp_alias_names(`node, source: bytes) -> list[str];
def _cpp_extra_walk(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    str_path: str,
    nodes: list,
    edges: list,
    seen_ids: set,
    function_bodies: list,
    parent_class_nid: str | None,
    add_node_fn,
    add_edge_fn,
    decl_node_fn=None,
) -> bool;
def _php_extra_walk(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    str_path: str,
    nodes: list,
    edges: list,
    seen_ids: set,
    function_bodies: list,
    parent_class_nid: str | None,
    add_node_fn,
    add_edge_fn,
) -> bool;
def _java_extra_walk(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    str_path: str,
    nodes: list,
    edges: list,
    seen_ids: set,
    function_bodies: list,
    parent_class_nid: str | None,
    add_node_fn,
    add_edge_fn,
    walk_fn,
) -> bool;
def _kotlin_extra_walk(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    str_path: str,
    nodes: list,
    edges: list,
    seen_ids: set,
    function_bodies: list,
    parent_class_nid: str | None,
    add_node_fn,
    add_edge_fn,
    walk_fn,
) -> bool;
def _kotlin_package_name(`root, source: bytes) -> str | None;
def _kotlin_nav_identifier_segments(nav, source: bytes) -> list[str] | None;

with entry {
    _KOTLIN_IDENTIFIERS = ("identifier", "simple_identifier", "type_identifier");
}

def _kotlin_type_name(type_node, source: bytes) -> str | None;
def _kotlin_declared_type(decl, initializer, source: bytes) -> str;

def _kotlin_binding_name(decl, source: bytes) -> str | None;
def _kotlin_variable_binding(decl, name: str, initializer, source: bytes) -> str | None;

def _kotlin_property_binding(prop, name: str, source: bytes) -> str | None;
def _kotlin_receiver_type(call, name: str, source: bytes, *, this_field: bool = False) -> str
    | None;
def _first_parse_error_line(`root) -> int;
def _first_multiline_error_line(`root) -> int;
def _has_multiline_error(`root) -> bool;
def _csharp_bare_call_name(name_node, source: bytes) -> str;
def _csharp_member_call_parts(fn_node) -> any;
def _read_csharp_type_name(`node, source: bytes) -> tuple[str, bool, str] | None;
def _ruby_new_class_name(`node, source: bytes) -> str | None;
def _python_class_ref(`node, source: bytes) -> str | None;
def _python_local_class_bindings(
    body_node, source: bytes, *, factory_bindings: dict[str, list[int]] | None = None
) -> dict[str, str | None];
def _ruby_local_class_bindings(body_node, source: bytes) -> dict[str, str | None];
def _ruby_local_names(body_node, source: bytes) -> frozenset[str];
def _ruby_const_last_name(`node, source: bytes) -> str;
def _ruby_const_full_name(`node, source: bytes) -> str;

with entry {
    _RUBY_LOOKUP_MUTATORS = frozenset({
        "alias_method",
        "attr",
        "attr_accessor",
        "attr_reader",
        "attr_writer",
        "define_method",
        "define_singleton_method",
        "include",
        "extend",
        "module_function",
        "prepend",
        "refine",
        "remove_method",
        "undef_method",
        "using",
    });

    _RUBY_EXTERNAL_OWNER_MUTATORS = _RUBY_LOOKUP_MUTATORS
        | frozenset({"class_eval", "class_exec", "module_eval", "module_exec"});
}

def _ruby_body_has_lookup_barrier(body_node, source: bytes) -> bool;
def _ruby_file_has_refinement_barrier(root_node, source: bytes) -> bool;
def _ruby_external_method_owners(root_node, source: bytes) -> list[str];

with entry {
    _RUBY_CLASS_FACTORIES = frozenset({("Struct", "new"), ("Class", "new"), ("Data", "define")});
}

def _ruby_extra_walk(
    `node,
    source: bytes,
    file_nid: str,
    stem: str,
    str_path: str,
    nodes: list,
    edges: list,
    seen_ids: set,
    function_bodies: list,
    parent_class_nid: str | None,
    add_node,
    add_edge,
    walk,
    callable_def_nids: set,
    callable_class_nids: set,
    ruby_namespace: list,
    ruby_lexical_scopes: list,
) -> bool;
def _lua_is_require_call(`node, source: bytes) -> bool;

with entry {
    _PHP_ROUTING_VERBS = frozenset({
        "get",
        "post",
        "put",
        "patch",
        "delete",
        "options",
        "any",
        "match",
        "map",
    });
    _PHP_LANGUAGE_CONSTRUCTS = frozenset({
        "array",
        "die",
        "empty",
        "eval",
        "exit",
        "isset",
        "list",
        "unset",
    });
}

def _php_get_route_name(closure_node, src: bytes) -> str | None;

with entry {
    _parser_tls = threading.local();
}

def _get_parser(ts_module: str, ts_language_fn: str) -> any;

def _build_parser(ts_module: str, ts_language_fn: str) -> any;
def _extract_generic(
    path: Path,
    config: LanguageConfig,
    *,
    source_override: bytes | None = None,
    scan_root: Path | None = None,
    preserve_call_sites: bool = False,
) -> dict;
def _ts_mark_public_twins(`root, source: bytes, result: dict);
def _python_decorator_name(deco_node, source: bytes) -> str | None;
def _ts_decorator_target_name(expr, source: bytes) -> str | None;
def _ts_decorator_name(deco_node, source: bytes) -> str | None;
def _ts_method_name(method_node, source: bytes) -> str | None;
def _ts_descendant_decorators(`node) -> list;
def _ts_emit_decorator_edges(
    class_node, class_nid: str, stem: str, source: bytes, ensure_named_node, add_edge
);
