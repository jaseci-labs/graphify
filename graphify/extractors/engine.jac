"""engine — moved verbatim from graphify/extract.py."""

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

"""Walk a Python type annotation; append (name, role) where role is 'type' or 'generic_arg'.

    Builtin/typing containers (list, dict, Optional, Union, …) are not emitted as refs themselves,
    but their nested type arguments still count as generic_arg.
    """
def _python_collect_type_refs(
    `node, source: bytes, generic: bool, out: list[tuple[str, str]]
) -> None;

"""Return names declared as `interface` in this C# compilation unit."""
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

"""A C# type's name as its node id spells it: the arity folds in (#4249).

    `Effect` and `Effect<T>` are different types, so the generic one is named
    the way C# metadata names it (`` Effect`1 ``); arity 0 is the bare name.
    """
def _csharp_type_name_for_id(`node, class_name: str) -> str;

"""The interface's simple name from an explicit-implementation specifier.

    ``Ns.IStore<int>.`` -> ``IStore``: no namespace, no type arguments, the
    spelling an interface declaration's label has.
    """
def _csharp_explicit_interface_name(specifier: str) -> str;

"""A C# method's parameter signature and the argument counts it accepts.

    The signature (``"`1:this Foo,ref int,params int[]"``) tells overloads
    apart; the metadata (``arity``, plus ``min_arity`` for optional, ``params``
    and extension parameters, and ``variadic`` for ``params``) lets a call site
    pick the overload its argument count fits (#4584).
    """
def _csharp_method_signature(`node, source: bytes, params=None) -> tuple[str, dict];

"""Argument count of a C# invocation, or None for anything else."""
def _csharp_argc(call_node) -> int | None;

"""Argument count of a C# `new X(...)` / `new X { ... }` / `: base(...)`.

    No argument list (`new X { A = 1 }`) runs the parameterless constructor.
    """
def _csharp_creation_argc(`node) -> int;

"""The one overload a call with ``argc`` arguments can mean, or None.

    ``overloads`` are the method nodes of one name on one type. Only the
    argument count is known at the call site, so two overloads that both
    accept it (``M(int)`` / ``M(string)``, or ``M(int)`` / ``M(params int[])``)
    stay undecided; C# would pick by argument types, which are not known here
    (#4584).
    """
def _csharp_pick_overload(overloads: list[dict], argc: int | None) -> dict | None;

"""Pre-scan a C# file for declared names that collapse to one node id.

    C# is case-sensitive and `_Name` is the usual spelling of a private member,
    but ``ids.py:make_id`` strips leading/trailing underscores and casefolds, so
    `Action()` / `_Action()`, `Size` / `_Size`, `Load()` / `load()` and the types
    `Pair` / `_Pair` each mint ONE id. ``add_node`` keeps the first declaration
    and drops the second; the dropped method's calls are credited to the
    survivor, and a type's members hang off the other type (#4415). This is
    the Python #3302 collision in C#; the outcome is the same rule
    (``_underscore_salted_nid``).

    Returns ``(type_groups, member_groups, member_ids)``: the first two are
    ``{plain_nid: {raw names}}`` for the ids two or more distinct names would
    share; ``member_ids`` is every member's plain id, which a constructor's or
    indexer's id must not take (a C# method may be spelled like its type in
    another case, and a member may be spelled `This`). Types are keyed the way
    the walk mints them (``_make_id(stem, namespace, name_for_id)``), members
    (methods, properties, enum members) by ``_make_id(type_nid, name)`` where
    ``type_nid`` is the type's FINAL id, already salted when the type itself
    collides. Same-file partial declarations of one type share an id, so their
    members are grouped together. Overloads are one name, never a collision.
    """
def _csharp_pre_scan_name_collisions(
    root_node, source: bytes, stem: str
) -> tuple[dict[str, set[str]], dict[str, set[str]], set[str]];

"""`implements` if the base name is an interface (declared or by I-prefix convention), else `inherits`."""
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

"""Return C# type-parameter names visible from ``node``."""
def _csharp_type_parameters_in_scope(`node, source: bytes) -> frozenset[str];

"""Walk a C# type expression; append (name, role, qualified, qualifier) tuples."""
def _csharp_collect_type_refs(
    `node,
    source: bytes,
    generic: bool,
    out: list[tuple[str, str, bool, str]],
    `skip: frozenset[str] | None = None,
) -> None;

"""Collect attribute names from a C# method/declaration's attribute_list children."""
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

"""Return Java type-parameter names visible from ``node``."""
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

"""Walk a Java type expression; append (name, role) tuples."""
def _java_collect_type_refs(
    `node,
    source: bytes,
    generic: bool,
    out: list[tuple[str, str]],
    `skip: frozenset[str] | None = None,
    preserve_qualified: bool = False,
) -> None;

"""Return the concrete declared type usable for Java receiver resolution."""
def _java_receiver_type_name(type_node, source: bytes) -> str | None;

"""Describe a Java receiver that is itself an expression, for the resolver
    to type from declared return types: `new T()` / `(T) x` -> ["type", "T"],
    `f()` -> ["call", "f", None, argc], `x.f()` -> ["call", "f", <x>, argc],
    `T.FIELD` -> ["field", "FIELD", <T>], and the leaves
    ["this"], ["super"], ["name", "x"]. None when any part is something else."""
def _java_receiver_chain(`node, source: bytes, depth: int = 0) -> list | None;

"""Replace the ["name", x] leaf of a receiver chain with x's declared type
    (["type", T]); a capitalized name nothing declares is a type itself
    (`Foo.create().run()`), as for a plain receiver. A ["field", name, owner]
    is kept only when that owner is such a class name: a local, parameter, or
    field that shadows it is not the class (`AuditLog Service; Service.INSTANCE`).
    Fields stay ["field_type", name] so their type is resolved in the declaring
    class's context. None when x is an untyped local."""
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

"""Every name a Java method binds itself, typed or not: parameters, locals
    (`var` too), lambda, catch, for-each, resource and pattern variables.

    A receiver outside this set and the class's own fields can only be a field
    the class inherits (or one of an enclosing class), never a local."""
def _java_bound_names(method_node, source: bytes) -> set[str];

def _java_lambda_parameters(lambda_node, source: bytes) -> list[tuple[str, str | None]];

"""Build the receiver type table visible to one Java method.

    Current-class fields are the base scope, and parameters shadow them for the
    full method. Conflicting local declarations are omitted because raw call
    facts do not retain lexical scope.
    """
def _java_method_receiver_types(
    method_node, source: bytes, field_types: dict[str, str]
) -> dict[str, str];

"""True when a Java declaration's `modifiers` child contains `modifier`
    (`static`, `final`, ...). Those keywords are unnamed nodes."""
def _java_has_modifier(declaration_node, modifier: str) -> bool;

"""Return annotations from a Java declaration's `modifiers` child."""
def _java_annotation_nodes(declaration_node) -> list;

"""Collect ``(simple, raw)`` annotation names from a Java declaration's
    `modifiers` child. ``raw`` keeps the dotted qualifier of an inline-qualified
    annotation (``@org.pkg.Foo``); it equals ``simple`` when unqualified."""
def _java_annotation_names(declaration_node, source: bytes) -> list[tuple[str, str]];

"""Collect Java type names used as class literals in annotation arguments."""
def _java_annotation_class_literal_refs(declaration_node, source: bytes) -> list[str];

"""Return the unqualified name text from a PHP `name`/`qualified_name` node."""
def _php_name_text(`node, source: bytes) -> str | None;

"""Walk a PHP type expression; append (name, role) tuples."""
def _php_collect_type_refs(`node, source: bytes, generic: bool, out: list[tuple[str, str]]) -> None;

"""The single class name a PHP type annotation names, or None.

    Only `Greeter` and `?Greeter` qualify: a union, an intersection or a primitive names
    no one class, and binding a receiver to the first arm of `A|B` would be a guess.
    """
def _php_declared_type_name(`node, source: bytes) -> str | None;

"""The bare name a PHP `variable_name` binds: `$greeter` -> `greeter`."""
def _php_variable_text(`node, source: bytes) -> str | None;

"""The first single-class type annotation among ``node``'s direct children."""
def _php_first_declared_type(`node, source: bytes) -> str | None;

"""Collect ``name -> TypeName`` for every PHP receiver whose type is written down.

    Four sources, all needed: a typed property (`private Greeter $g;`), a constructor
    promotion (`__construct(private Greeter $g)`), a typed parameter, and
    `$g = new Greeter()`. File-scoped and flat, first binding wins — a parameter
    shadowing a property in another method must not retype the property's own calls.
    Children are pushed reversed so the walk yields document order and "first" means
    first in the file.
    """
def _php_receiver_type_table(`root, source: bytes, table: dict[str, str]) -> None;

"""Return the named_type/primitive_type node sitting after formal_parameters."""
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

"""Return the tail identifier text from a Kotlin user_type node (without generics).

    A qualified supertype like `com.example.Base` lists its segments as flat
    `identifier` children (`com`, `example`, `Base`) separated by `.` tokens, so
    the real type is the LAST segment, not the first — returning the head yielded
    the package root (`com`). Type arguments live in a separate `type_arguments`
    child, so scanning direct children and keeping the last identifier/
    type_identifier segment ignores generics correctly (mirrors the C++ qualified
    base handling, which uses the unqualified tail)."""
def _kotlin_user_type_name(user_type_node, source: bytes) -> str | None;

"""Collect ``(simple, raw)`` annotation names from a Kotlin declaration's
    `modifiers` child, safely handling `use_site_target` and parameters."""
def _kotlin_annotation_names(declaration_node, source: bytes) -> list[tuple[str, str]];

"""Collect Kotlin type names used as class literals in annotation arguments (e.g. ``Customer::class``)."""
def _kotlin_annotation_class_literal_refs(declaration_node, source: bytes) -> list[str];

"""Return Kotlin type-parameter names visible from ``node``.

    A `class Box<T>` or `fun <R> map(...)` binds `T`/`R` as local names, not
    corpus symbols. Walking up to every enclosing declaration's `type_parameters`
    list (the use site is `type_arguments`, a different node, so this never
    collects an instantiation argument) collects them for the scope skip set.
    """
def _kotlin_type_parameters_in_scope(`node, source: bytes) -> frozenset[str];

"""Walk a Kotlin type expression; append (name, role) tuples.

    Generic type parameters in scope (``skip``) are local bindings, not
    references; emitting one mints a sourceless stub (the bare `t` god node a
    `<T>` class or function would otherwise share corpus-wide).
    """
def _kotlin_collect_type_refs(
    `node,
    source: bytes,
    generic: bool,
    out: list[tuple[str, str]],
    `skip: frozenset[str] | None = None,
) -> None;

"""Find the user_type node within a Kotlin property_declaration."""
def _kotlin_property_type_node(property_node) -> any;

"""Find the return-type node of a Kotlin function_declaration (the type after `: ` post-params)."""
def _kotlin_function_return_type_node(func_node) -> any;

"""Return the leading kind token for a Swift class_declaration: class/struct/enum/extension/actor."""
def _swift_declaration_keyword(`node) -> str | None;

with entry {
    _PY_TYPE_ALIAS_ANNOTATIONS = frozenset({
        "TypeAlias",
        "typing.TypeAlias",
        "typing_extensions.TypeAlias",
    });
    _PY_NEW_TYPE_CALLEES = frozenset({"NewType", "typing.NewType", "typing_extensions.NewType"});
}

"""The type name a module-level statement declares as an explicit alias.

    `type Vector = ...` / `type Pair[T] = ...` (PEP 695), `Matrix: TypeAlias = ...`
    and `UserId = NewType("UserId", int)` each declare one. A bare
    `JsonValue = Union[...]` is an alias by convention only and is not one.
    A same-name re-export (`Field: TypeAlias = core.Field`, `type Field =
    core.Field[int]`, or `Field: TypeAlias = Field` after `from core import
    Field`) denotes the original type and declares no new name, so it
    returns None: references keep resolving to the one real `Field`.
    """
def _python_alias_name(stmt, source: bytes) -> str | None;

"""Pre-scan a Python module for name-only differences that collapse to one node id.

    ``ids.py:make_id`` strips leading/trailing underscores from every part before
    normalizing, so ``_get_connection`` and ``get_connection`` mint the SAME id.
    ``add_node`` then silently drops whichever declaration is walked second — no
    warning, exit 0 — so a public method can be entirely absent from the graph
    while its private-by-convention sibling (or a dunder, which strips the same
    way: ``__x``/``__x__``/``x`` all collapse too) occupies the public name (#3302).

    Returns ``{plain_nid: {raw names that would collide on it}}`` for every
    module-level function, module-level class, and direct method of a
    module-level class — the cases the id-minting code actually distinguishes
    via ``parent_class_nid``. Module-level classes share the functions' scope, so
    ``class Session`` / ``def session()`` and ``class Foo`` / ``class FOO``
    (casefold) collide there too (#2810). Methods are keyed under their class's
    *resolved* id: a salted class mints its methods under the salted id, so
    keying them under the plain one would miss every method collision inside it.
    Deliberately does not recurse into nested classes or nested functions: this
    keeps the scope key trivially exact (matching ``_make_id(stem, class_name)``,
    which only holds because Python never populates ``namespace_stack``) rather
    than replicating the corpus-wide id-computation rules for every nesting shape.
    A collision entirely inside an unhandled nested scope is simply not caught
    here — a strict miss, never a false positive, since the map is only ever
    consulted for a nid this same scan actually computed.
    """
def _python_pre_scan_underscore_collisions(
    root_node, source: bytes, stem: str
) -> dict[str, set[str]];

"""Resolve a declaration's real node id against the collision map.

    Shared by the Python and C# pre-scans (#3302, #4415). A name with no
    leading underscore at all is "public" per PEP 8 convention.
    When a collision group has exactly one public member, that member keeps the
    plain id — cross-file/documentation references overwhelmingly target the
    public name, and keeping it stable means an incremental rebuild that adds or
    removes a private-by-convention sibling re-points nothing. Every other
    member of the group (including the public one when it is NOT unique, e.g.
    `_x`/`__x` colliding with no public member at all) is salted, so the outcome
    never depends on declaration order — mirrors the exported/unexported rule
    the Go extractor uses for its own case-only collision (#2779).
    ``private_prefixes`` widens what counts as non-public: JS/TS also marks
    members private with ``$`` and ``#`` (#4475).
    ``private_suffixes`` does the same for a trailing mark: C++ spells a
    private member ``find_`` as often as ``_find``.
    ``leaf`` maps a name to the part whose spelling decides that (Lua judges
    ``M._load`` by ``_load``).
    """
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

"""Node id for a JS/TS class member, salted when a sibling collides (#4475).

    ``make_id`` drops ``_``, ``$`` and ``#``, so ``updateHash`` / ``_updateHash``,
    ``close`` / ``#close`` and ``set`` / ``$set`` in one class body mint one id
    and the second declaration vanished. The member names of the enclosing
    class body are grouped by the id they would get (methods, signatures and
    function-valued fields, the members the walk turns into ``.name()`` nodes),
    then ``_underscore_salted_nid`` applies the Python/C# rule: a unique public
    name keeps the plain id, every other colliding name gets a salted one.
    Members that collide with nothing keep their old id. Getter/setter pairs
    and overloads share one name, so they are not a collision.
    """
def _js_member_nid(
    class_nid: str, member_node, name: str, source: bytes, groups_cache: dict
) -> str;

"""Node id for a PHP method, salted when a sibling differs only by ``_``.

    ``make_id`` drops leading/trailing ``_``, so ``_x()`` / ``x()`` in one
    class, trait, interface or enum body minted one id and the second
    declaration vanished, taking its calls with it (#2810). Sibling
    ``method_declaration`` names are grouped by the id they would get and
    ``_underscore_salted_nid`` applies the Python/C#/JS rule: a unique public
    name keeps the plain id, every other colliding name gets a salted one.
    PHP method names are case-insensitive, so names are casefolded first:
    ``Foo()`` / ``foo()`` are one method, never a collision, and the salt does
    not depend on how a name is cased.
    """
def _php_member_nid(
    class_nid: str, member_node, name: str, source: bytes, groups_cache: dict
) -> str;

with entry {
    _JAVA_MEMBER_CALLABLE_TYPES = ("method_declaration", "constructor_declaration");

    _JAVA_LOMBOK_IMPORT_RE = re.compile(
        b"^\\s*import\\s+lombok\\s*\\.\\s*(?:Getter|\\*)\\s*;", re.MULTILINE
    );
}

"""The ``@Getter`` annotation on a declaration when it is Lombok's.

    ``@lombok.Getter`` always is; a bare ``@Getter`` only when the file
    imports ``lombok.Getter`` or ``lombok.*``. ``@Getter(AccessLevel.NONE)``
    asks for no getter, so it returns None.
    """
def _java_lombok_getter_annotation(declaration_node, source: bytes) -> any;

"""Names of the getters Lombok ``@Getter`` writes for a field (#5148).

    A field annotation covers static and instance fields; a class annotation
    covers instance fields only. The name is ``get`` + the capitalised field
    name, or ``is`` for a primitive ``boolean`` (a ``boolean isX`` keeps its
    own name). Lombok skips a getter when the class already declares a
    zero-argument method of that name, ignoring case.
    """
def _java_lombok_getters(field_node, source: bytes) -> list[str];

"""Node id for a Java method or constructor, salted when a sibling collides.

    ``make_id`` drops a leading ``_`` and folds case, so ``_testFoo()`` /
    ``testFoo()``, ``getId()`` / ``getID()`` and a constructor ``HashCode()`` /
    method ``hashCode()`` in one class body minted one id: the second
    declaration vanished and its calls were credited to the survivor. Group
    the methods and constructors of the enclosing body (a class, interface or
    record body, or an enum's ``enum_body_declarations``) by the id they
    would get, then apply ``_underscore_salted_nid``, the Python/C#/Solidity
    rule (#3302, #4415, #5058): a unique public name keeps the plain id, every
    other colliding name is salted. Members that collide with nothing keep
    their old id; overloads share one name, so they are not a collision.
    """
def _java_member_nid(
    class_nid: str, member_node, name: str, source: bytes, groups_cache: dict
) -> str;

"""A Java type as written, minus generic arguments and whitespace.

    ``List<String>`` and ``List<Integer>`` are one signature after erasure, as
    they are in Java itself (two such methods cannot coexist), and a line break
    inside a type never changes an id.
    """
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

"""``{type variable: its erased bound}`` in scope at a Java method.

    A type variable erases to its first bound (``<T extends Number & Comparable<T>>``
    -> ``Number``) or ``Object`` when it has none, so ``<T extends Number> run(T)``
    and ``<T extends CharSequence> run(T)`` are different overloads (#5251). The
    method's own variables and those of every enclosing type count; an inner
    declaration shadows an outer one.
    """
def _java_type_var_bounds(`node, source: bytes) -> dict[str, str];

"""``text`` with a type variable (or an array of one) replaced by its bound."""
def _java_erase_type_var(text: str, bounds: dict[str, str]) -> str;

"""A Java method's erased parameter signature and the argument counts it accepts.

    The signature (``"String,int[]"``) tells overloads apart; type variables are
    replaced by their erased bounds, as the compiler does. The metadata
    (``arity``, plus ``min_arity`` and ``variadic`` for a ``T...`` parameter)
    lets a call site pick the overload its argument count fits (#5251).
    """
def _java_method_signature(`node, source: bytes) -> tuple[str, dict];

"""Argument count of a Java ``method_invocation``, or None for anything else."""
def _java_argc(call_node) -> int | None;

with entry {
    _KOTLIN_MEMBER_BODY_TYPES = ("class_body", "enum_class_body");
}

def _kotlin_function_name(`node, source: bytes) -> str;

"""Node id for a Kotlin method, salted when a sibling collides.

    ``make_id`` drops a leading ``_`` and folds case, so ``_bar()`` / ``bar()``
    or ``run()`` / ``Run()`` of one class minted one id: the second declaration
    vanished and its calls were credited to the survivor. A ``companion
    object``'s members take the enclosing class's id, so group the functions of
    the class body and its companion body by the id they would get, then apply
    ``_underscore_salted_nid``, the Python/C#/Solidity/Java rule (#3302, #4415,
    #5058, #5151): a unique public name keeps the plain id, every other
    colliding name is salted. Members that collide with nothing keep their old
    id; overloads share one name, so they are not a collision.
    """
def _kotlin_member_nid(
    class_nid: str, member_node, name: str, source: bytes, groups_cache: dict
) -> str;

with entry {
    _SWIFT_TYPE_DECL_TYPES = ("class_declaration", "protocol_declaration");
    _SWIFT_TYPE_NAME_TYPES = ("simple_identifier", "type_identifier", "user_type");
    _SWIFT_MEMBER_CALLABLE_TYPES = ("function_declaration", "protocol_function_declaration");
}

"""The name the class branch reads for a Swift type or extension."""
def _swift_type_decl_name(decl, source: bytes) -> str;

"""Node id for a Swift method, salted when a sibling collides.

    ``make_id`` drops a leading ``_`` and folds case, so ``_flatMap()`` /
    ``flatMap()`` or ``run()`` / ``Run()`` of one type minted one id: the
    second declaration vanished and its calls were credited to the survivor.
    A type's id is its file stem plus its name, so its class body and every
    ``extension`` of it in the file share that id; group the methods of all of
    them by the id they would get, then apply ``_underscore_salted_nid``, the
    Python/C#/Solidity/Java rule (#3302, #4415, #5058, #5151): a unique public
    name keeps the plain id, every other colliding name is salted. Members
    that collide with nothing keep their old id; overloads share one name, so
    they are not a collision.
    """
def _swift_member_nid(
    class_nid: str, member_node, name: str, source: bytes, groups_cache: dict
) -> str;

with entry {
    _RUBY_MEMBER_CALLABLE_TYPES = ("method", "singleton_method");
}

"""Node id for a Ruby method, salted when a sibling collides.

    ``make_id`` drops a leading ``_`` and folds case, so ``_read_attribute`` /
    ``read_attribute`` or ``_where!`` / ``where!`` of one class or module
    minted one id: the second declaration vanished and its calls were credited
    to the survivor. Group the methods of the enclosing class/module body (its
    own ``def``s and those of a ``class << self`` in it) by the id they would
    get, then apply ``_underscore_salted_nid``, the Python/C#/Solidity/Java
    rule (#3302, #4415, #5058, #5151): a unique public name keeps the plain
    id, every other colliding name is salted. ``name`` is the sanitized name
    (``foo!`` -> ``foo_bang``, #3077), so ``foo`` / ``foo!`` / ``foo?`` never
    collide. Members that collide with nothing keep their old id; an
    instance and a singleton method of one name share one name, so they are
    not a collision.
    """
def _ruby_member_nid(
    class_nid: str, member_node, name: str, source: bytes, groups_cache: dict, sanitize
) -> str;

"""``M:load`` and ``M.load`` name one table field; spell both with ``.``."""
def _lua_field_name(name: str) -> str;

def _lua_field_leaf(name: str) -> str;

"""Group a Lua file's table-field functions by the id they would get.

    ``make_id`` drops ``_`` and folds case, so ``function M._load()`` /
    ``function M.load()`` (or ``Runner:_start()`` / ``Runner:start()``) in one
    file minted one id: the second declaration vanished and its calls were
    credited to its twin. Only dotted/colon names are grouped; a bare
    ``_x`` / ``x`` pair is the module-level rule's (#2810).
    """
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

"""Node id for a Scala method, salted when a sibling collides.

    ``make_id`` drops a leading ``_``, a trailing ``_=`` and folds case, so
    ``_enter`` / ``enter``, a getter ``size`` / setter ``size_=`` or
    ``forEach`` / ``foreach`` of one type minted one id: the second
    declaration vanished and its calls were credited to the survivor. A class
    and its companion object share one id, so group the methods of the
    type's body and of its same-named companions in the same scope by the id
    they would get, then apply ``_underscore_salted_nid``, the
    Python/C#/Solidity/Java rule (#3302, #4415, #5058, #5151): a unique public
    name keeps the plain id, every other colliding name is salted. Members
    that collide with nothing keep their old id; overloads share one name, so
    they are not a collision.
    """
def _scala_member_nid(
    class_nid: str, member_node, name: str, source: bytes, groups_cache: dict
) -> str;

with entry {
    _CPP_PRIVATE_MEMBER_PREFIXES = ("_", "~");
    _CPP_PRIVATE_MEMBER_SUFFIXES = ("_",);
}

def _cpp_is_method_declarator(decl) -> bool;

"""Node id for a C++ member function, salted when a sibling collides.

    ``make_id`` drops a leading or trailing ``_`` and ``~`` and folds case, so
    ``find()`` / ``find_()``, ``_bar()`` / ``bar()``, ``Run()`` / ``run()`` and a
    constructor ``Foo()`` / destructor ``~Foo()`` declared in one class body
    minted one id: the second declaration vanished and its calls were credited
    to the survivor. Group the member functions of the class body (the inline
    definitions and the prototypes the walk turns into ``.name()`` nodes, also
    under ``template``) by the id they would get, then apply
    ``_underscore_salted_nid``, the Python/C#/Solidity/Java rule (#3302, #4415,
    #5058, #5151): a unique public name keeps the plain id, every other
    colliding name is salted. Members that collide with nothing keep their old
    id; overloads share one name, so they are not a collision. Operators are
    left alone.
    """
def _cpp_member_nid(
    class_nid: str, member_node, name: str, source: bytes, groups_cache: dict
) -> str;

"""Pre-scan a Swift compilation unit and return (protocol_names, class_like_names)."""
def _swift_pre_scan(root_node, source: bytes) -> tuple[set[str], set[str]];

"""Classify a Swift inheritance_specifier entry as `inherits` or `implements`."""
def _swift_classify_base(
    name: str, kind: str | None, is_first: bool, protocols: set[str], classes: set[str]
) -> str;

"""Return the head type_identifier text from a Swift user_type node (without generics)."""
def _swift_user_type_name(user_type_node, source: bytes) -> str | None;

def _swift_receiver_type_name(`node, source: bytes) -> str | None;

"""Return Swift generic type-parameter names visible from ``node``.

    A `struct Stack<Element>` / `func map<R>(...)` binds `Element`/`R` as local
    names, not corpus symbols. Walking up to every enclosing declaration's
    `type_parameters` list collects them; a parameter's name is the first
    `type_identifier` of its `type_parameter` node (a constraint like
    `T: Equatable` is a separate `user_type` and is left to reference).
    """
def _swift_type_parameters_in_scope(`node, source: bytes) -> frozenset[str];

"""Walk a Swift type expression; append (name, role) tuples (role 'type' or 'generic_arg').

    Generic type parameters in scope (``skip``) are local bindings, not
    references; emitting one mints a sourceless stub (the bare `t` god node a
    `<T>` type or function would otherwise share corpus-wide)."""
def _swift_collect_type_refs(
    `node,
    source: bytes,
    generic: bool,
    out: list[tuple[str, str]],
    `skip: frozenset[str] | None = None,
) -> None;

"""Return the type_annotation child of a Swift property_declaration, if any."""
def _swift_property_type_node(property_node) -> any;

"""Return the type named by an ``@Environment(Type.self)`` attribute argument.

    Structural, whitelist-gated (#2561): only the ``Environment`` wrapper names
    the property's OWN type in its argument — ``@Query(Item.self)`` properties
    hold a *collection* of the argument type, so typing them as the element type
    fabricates member-call edges (measured false edge in the report). The
    argument must be a navigation_expression of exactly
    ``[simple_identifier (uppercase), navigation_suffix ".self"]``; the keypath
    form (``@Environment(\\.dismiss)``, key_path_expression head) and the
    module-dotted form (``@Environment(MyModule.Store.self)``, nested
    navigation_expression head) are skipped — a missed edge, never a wrong one.
    """
def _swift_attribute_type_name(property_node, source: bytes) -> str | None;

"""If a Swift call expression is a static factory call (``Factory.make()``),
    return ``(factory_type, method_name)``; else None (#2561).

    Only the exact depth-1 shape is accepted: a navigation_expression of
    ``[simple_identifier (uppercase), navigation_suffix]``. Deeper chains
    (``A.B.make()``, ``Singleton.shared.make()``) stay untyped — the resolver
    would have to guess the intermediate hop.
    """
def _swift_factory_call(call_node, source: bytes) -> tuple[str, str] | None;

"""Return the bound name of a Swift property (``let x``/``var x = ...``)."""
def _swift_property_name(property_node, source: bytes) -> str | None;

"""If a Swift call expression is a constructor (``Foo()``), return the type name.

    Only upper-cased callees are treated as types so a free-function call like
    ``configure()`` in an initializer is not mistaken for a constructor.
    """
def _swift_constructor_type(call_node, source: bytes) -> str | None;

"""Return the depth-1 receiver name of a Swift member call (``recv.method()``).

    ``vm.update()`` -> ``vm``; ``Type.staticMethod()`` -> ``Type``;
    ``Outer.Builder.method()`` -> ``Outer.Builder``;
    ``Singleton.shared.method()`` -> ``Singleton`` (head of the chain);
    ``self.svc.fetch()`` -> ``svc`` (the property the call is reached through).
    Returns None for anything deeper, so resolution stays depth-1.
    """
def _swift_receiver_name(recv_node, source: bytes) -> str | None;

"""Return the operand a misplaced Swift call suffix really applies to.

    tree-sitter-swift parses ``a + f()`` as ``(a + f)()`` and ``!f()`` as
    ``(!f)()``: the call's callee slot (or a member call's receiver) holds the
    whole operator expression. The call belongs to its last operand. An
    implicit member ``.make()`` is also a ``prefix_expression``; it names no
    receiver, so it is left as is.
    """
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

"""Walk a C type expression; append (name, role) tuples for user-defined types.
    Skips primitive types and qualifiers; recognises type_identifier."""
def _c_collect_type_refs(`node, source: bytes, generic: bool, out: list[tuple[str, str]]) -> None;

"""Return C++ template type-parameter names visible from ``node``.

    A `template<typename T, class U>` binds `T`/`U` as local names, not corpus
    symbols. Walking up to every enclosing `template_declaration`'s
    `template_parameter_list` collects the names from its
    type-parameter children, including a template-template parameter's own name.
    A non-type parameter (`int N`) is a value, not a type, and is left alone.
    """
def _cpp_type_parameters_in_scope(`node, source: bytes) -> frozenset[str];

"""A type name that was written `std::`-qualified (`std::chrono::seconds` ->
    ``seconds``). The reference keeps its tail as its label, but it names the
    standard library, so ``ensure_named_node`` gives it a stub of its own that
    the corpus-wide rewire never maps onto a project symbol (#5219)."""
class _CppStdName(builtins.str) {
    static has __slots__: any = ();
}

glob dialect_quals_default_: any;

with entry {
    dialect_quals_default_ = frozenset();
}

"""Walk a C++ type expression; append (name, role) tuples.
    Resolves qualified_identifier tails (std::string → string) and template_type
    base + arguments (std::vector<HttpClient> → vector + HttpClient as generic_arg).

    Template type parameters in scope (``skip``) are local bindings, not
    references; emitting one mints a sourceless stub (the bare `t` god node a
    `template<typename T>` class or function would otherwise share corpus-wide).

    ``dialect_quals`` holds GPU C++-dialect qualifiers (Metal/CUDA; only non-empty
    for those file extensions) that tree-sitter-cpp misparses as a leading
    `type_identifier`; they are language keywords, not corpus symbols."""
def _cpp_collect_type_refs(
    `node,
    source: bytes,
    generic: bool,
    out: list[tuple[str, str]],
    `skip: frozenset[str] | None = None,
    dialect_quals: frozenset[str] = dialect_quals_default_,
) -> None;

"""A stable label for an anonymous Scala 3 given (`given Show[Int] with`).

    Derived from the implemented type's base name so the given instance gets its
    own scope (`given Show` -> id `..._given_show`), distinct from the trait type
    node `Show` (`..._show`); otherwise its members would be dropped or leak to
    file scope (#4130). Deterministic (no line numbers): two anonymous givens for
    the same type in one file are a Scala ambiguity error, so no real collision.
    """
def _scala_given_synthetic_name(`node, source: bytes) -> str | None;

"""Return Scala type-parameter names visible from ``node``.

    A `class Box[T]` / `def map[R](...)` binds `T`/`R` as local names, not
    corpus symbols. Walking up to every enclosing declaration's `type_parameters`
    list (the use site is `type_arguments`, a distinct node, so an instantiation
    argument is never collected) collects them for the scope skip set. A
    variance-annotated parameter (`[+A]`/`[-B]`) wraps its name one level
    deeper. A bound (`[A: Ordering]`, `[T <: Base]`) names a real type, not a
    parameter, so its `context_bound`/`upper_bound`/`lower_bound` node is skipped.
    """
def _scala_type_parameters_in_scope(`node, source: bytes) -> frozenset[str];

"""Walk a Scala type expression; append (name, role) tuples.
    Handles type_identifier, generic_type (List[T]), and common type wrappers.

    Generic type parameters in scope (``skip``) are local bindings, not
    references; emitting one mints a sourceless stub (the bare `t` god node a
    `[T]` class or method would otherwise share corpus-wide)."""
def _scala_collect_type_refs(
    `node,
    source: bytes,
    generic: bool,
    out: list[tuple[str, str]],
    `skip: frozenset[str] | None = None,
) -> None;

"""Collect the types named by a ``type_parameters`` node's context bounds.

    ``def sort[A: Ordering]`` desugars to an implicit ``Ordering[A]``, so the
    bound is a real dependency the function has on that typeclass -- but
    ``context_bound`` was not referenced anywhere in the extractor, so the
    dependency was invisible wherever it appeared (#2046).

    A ``context_bound`` is a direct child of ``type_parameters``, one per bound.
    A higher-kinded parameter nests a further ``type_parameters`` for its own
    arity brackets (``def program[F[_]: Async: Temporal]``), so this recurses
    rather than reading direct children only -- otherwise both bounds on
    ``program`` are missed.

    ``upper_bound`` (``[T <: Comparable[T]]``) is a distinct node type and is
    deliberately not matched here: a subtype constraint is not a dependency, so
    emitting an edge for it would assert something the source does not say.
    """
def _scala_collect_context_bounds(tp_node, source: bytes, out: list[tuple[str, str]]) -> None;

"""Collect type refs from each typed parameter under a `parameters` node."""
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

"""The `identifier` a Python class base names, or None.

    A parameterized base (`Base[T]`, `Repo[User]`) parses as a `subscript`
    whose `value` field is the base itself; the `[...]` holds only type
    arguments. `mod.Base`, `mod.Base[T]` and calls stay None.

    Known limitation: a subscript whose value is a plain identifier that is not
    a type (`class Dyn(registry['k'])`) is indistinguishable from `Base[int]`
    at the AST level, so it yields the identifier (`registry`) here and may emit
    a spurious `inherits` edge. Harmless unless a corpus class is literally named
    `registry`; the common generic case dominates.
    """
def _python_base_name_node(arg) -> any;

"""`Client`, `mod.Client`, or the item of `Iterator[Client]` /
    `Generator[Client, None, None]` (a yield fixture); anything else is None."""
def _python_annotation_class(type_node, source: bytes) -> str | None;

"""The class a fixture returns or yields: its return annotation, else every
    `return` / `yield` naming one class (`return CliRunner()`, `yield client`
    after `client = Client()`). Anything else is PYTEST_FIXTURE_UNTYPED."""
def _python_fixture_type(func_node, source: bytes, local_types: dict[str, str | None]) -> str;

"""Parameters with no annotation and no default that the body never rebinds:
    the ones pytest may fill with a fixture."""
def _python_untouched_params(func_node, source: bytes) -> set[str];

def _python_is_test_module(str_path: str) -> bool;

"""Identifiers bound as `pattern` targets under a Python AST subtree.

    Recurses through `pattern_list` / `tuple_pattern` / `list_pattern` so tuple
    unpacking (`a, b = ...`, `for a, b in ...`) contributes every bound name.
    """
def _python_collect_assignment_targets(`node, source: bytes, out: set[str]) -> None;

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

"""In-file target of a known current-instance or base-instance method call.

    ``walk_bases=False`` stops after the caller's own class and otherwise keeps
    the plain lookup: JS/TS `extends` edges come from the later symbol pass, so
    the chain is unknown here and an inherited `this.m()` must not be refused.

    The receiver is the caller's own instance, so the lookup starts at the
    enclosing class (skipped for `super`) and walks its in-file bases one level
    at a time, nearest first, the order the ObjC resolver already uses for
    `self`. Two hits on one level are a multiple-inheritance tie this pass
    cannot order, so neither is bound. A method of a class outside that chain is
    never the target: the file-wide name map used to hand `self.save()` in one
    class to whichever class declared save() last. A file-wide hit that is not
    a method (a module-level callable stored on the instance) still binds, as
    before.
    """
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

"""Supertypes of each class, in declaration order, for _lexical_call_target.

    Targets named in ``interfaces`` (C#: those the file declares) are left out. A
    base declared further down the file is still a sourceless stub during the call
    walk, so it is read as the one class of this file that bears its name; two such
    classes, or none, leave it a stub. An anonymous class (a class inside a method)
    is labelled with the type after its ``new``, which is read the same way.
    """
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

"""In-file target of an unqualified call ``m()`` made from a method.

    The nearest class that has an ``m``: the caller's own class and its in-file
    bases (nearest first, as _self_call_target walks them), then the class around
    it, and so on outward; an anonymous class steps out through the method that
    holds it. Two hits on one level are a tie this pass cannot order: neither is
    bound. A name no class on that path declares (a free function, a constructor
    call) keeps the file-wide lookup, as does a walk that reaches a nested class
    shared by several classes of one name, since which class lies around it is
    unknown. A supertype outside this file is invisible, so a method inherited
    from it can lose to an enclosing class that declares the same name.
    """
def _lexical_call_target(
    caller_nid: str,
    callee: str,
    label_to_nid: dict[str, str],
    method_owner: dict[str, str],
    methods_by_owner: dict[tuple[str, str], str],
    class_bases: dict[str, list[str]],
    class_parent: dict[str, str],
) -> str | None;

"""Names bound LOCALLY inside a Python function: parameters plus assignment,
    `for`, `with ... as`, and comprehension targets.

    Used by the indirect-dispatch guard to reject a call-argument identifier that
    is a parameter or a local binding — it names a local value, not the module-
    level function/class that happens to share the name. Nested `function_definition`
    and `class_definition` subtrees are NOT descended into: their bindings belong
    to a different scope.
    """
def _python_local_bound_names(func_def_node, source: bytes) -> set[str];

"""Names rebound by assignment at MODULE scope (top-level `x = ...`, `for`, walrus).

    The module-scope analogue of the per-function shadow set: a dispatch-table value
    whose name is reassigned to data at module level (`handler = build()`) names that
    value, not a same-named function, so it must not manufacture an indirect edge.
    Function and class bodies are not descended into — their bindings are local.
    """
def _python_module_bound_names(`root, source: bytes) -> set[str];

"""Conservative lexical guard for a module or proved module-instance receiver.

    A module-root plain import is the only eligible binding. Other bindings in
    any enclosing scope make the receiver unsafe, regardless of statement order.
    Cache each scope scan because every member call in that scope asks again.
    """
def _python_receiver_shadow_checker(`root, source: bytes, *, module_bindings=None) -> any;

"""Direct module constructor bindings, guarded by the existing lexical scan.

    A constructor must be declared or imported once before the assignment. The
    corpus resolver still has to prove it names a unique visible class. Imports
    under aliases retain the original class name. Conditional bindings, dynamic
    namespace mutation and any other rebindings deliberately stay unresolved.
    """
def _python_module_instance_types(`root, source: bytes) -> any;

with entry {
    _PYTHON_PROPERTY_DECORATORS = frozenset({
        "property",
        "cached_property",
        "functools.cached_property",
    });
}

"""`@property` / `@cached_property` / `@x.getter`: reading the attribute runs it."""
def _python_is_property(func_node, source: bytes) -> bool;

def _same_node(a, b) -> bool;

"""`x.a = ...`, `for x.a in ...`, `del x.a`: not a read of `a`. `x.a += ...`
    is: it reads `a` (the getter runs) before it writes it."""
def _python_attribute_is_store(`node) -> bool;

"""Raw calls for attribute reads that may run a `@property` getter.

    `response.text` names no call, but reading it runs `Response.text` when that
    is a property. Only reads whose receiver is typed the way a member call
    would be are recorded: `self.a` (minus the fields the class assigns,
    `self.a = ...`), a typed local or parameter (`receiver_type`), and
    `self.X.a` with `X` bound to one class (`_python_self_attr_type`). The
    resolver binds them like member calls and keeps only targets marked
    `_py_property`, as a `references` edge, so a plain field or a method reference gets no edge.
    """
def _python_property_reads(
    function_bodies,
    source: bytes,
    str_path: str,
    var_types: dict[str, dict[str, str | None]],
    attr_types: dict[str, dict[str, str | None]],
    method_owner: dict[str, str],
) -> list[dict];

"""``X`` when ``node`` is the attribute ``self.X`` (#2860), else None."""
def _python_self_attr(`node, source: bytes) -> str | None;

"""Yield ``(attr, type_name)`` for every ``self.attr = ...`` in a method body
    (#2860). ``type_name`` is the annotation (``self.attr: T = ...``) or the bare
    class of ``self.attr = Ctor(...)``, and None for any other value so the
    caller can poison the field; ``self.attr = None`` binds nothing. An unchanged
    typed parameter/local also carries its class through ``self.attr = value``."""
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

"""Collect binding identifier names from a JS/TS pattern (a parameter, or a
    declarator LHS). Recurses through destructuring (object/array patterns, rest)
    but never into the default-value side of `x = default` or a type annotation,
    so only names actually bound by the pattern are collected."""
def _js_collect_pattern_idents(`node, source: bytes, bound: set) -> None;

"""Names bound locally inside a JS/TS function, into the FUNCTION-WIDE
    scope: parameters plus `var` declarator targets. Mirrors
    `_python_local_bound_names`: an argument that is a parameter or local
    binding names a local value, not a same-named module function, so it
    must not manufacture an indirect_call edge. Nested function and class
    scopes are not descended into.

    `let`/`const` declarator targets and `for`/`for-in`/`for-of` loop
    bindings are NOT collected here (#2822): unlike `var`, which is
    function-scoped (hoisted) regardless of how deeply it is nested inside
    an if/try/bare-`{}` block or a loop, `let`/`const` (and a `for`/`for-in`
    loop's own binding, whatever keyword it uses) are scoped to exactly the
    block or loop they are declared in. Collecting them into this
    function-wide set suppressed a genuine reference to a same-named module
    callable anywhere else in the function, even far outside the block that
    actually owns the binding. `walk_calls` in this module folds each of
    those into `extra_locals` for exactly its own block/loop subtree
    instead, the same mechanism already used for `catch (e)` bindings.
    """
def _js_local_bound_names(func_node, source: bytes) -> set[str];

"""Names bound by `let`/`const` declarators that are DIRECT children of
    node (not nested inside a further block, loop, function, or class).

    Used to scope a lexical binding to exactly the block or `for` loop it is
    declared in (#2822), rather than the whole enclosing function: `node` is
    a `statement_block` or a C-style `for_statement`, both of which have any
    `lexical_declaration` they directly own as a plain child.
    """
def _js_direct_lexical_names(`node, source: bytes) -> frozenset[str];

"""Names bound by every scope that ENCLOSES ``node``, up to (not including)
    the program: each enclosing function's params and `var`s, plus the
    `let`/`const`, loop and `catch` bindings of each enclosing block.

    A closure body that is tracked on its own (so `walk_calls` starts at that
    body, not at the enclosing function's) never sees the bindings the
    #2241/#2822 folds would have carried down to it. Without them a name
    captured from an enclosing function (`function (item) { confirm({ action:
    function () { del(item) } }) }`) reads as a free reference and resolves to
    any same-named callable in the corpus (#5217). Mirrors exactly what
    `walk_calls` folds into `extra_locals` on its way down.
    """
def _js_enclosing_bound_names(`node, source: bytes) -> set[str];

"""Resolve the receiver binding along the full lexical ancestor chain from
    the call site, so a separately-tracked inner function still sees the outer
    shadowing of the imported name."""
def _js_receiver_shadowed(`node, name: str | None, source: bytes, bindings_by_scope: dict) -> bool;

"""Module-scope names rebound to NON-function data (`const X = {...}`, `let y = 5`).

    The JS/TS module-scope shadow set. Unlike the per-function set, a declarator
    whose value is itself a function (`const cb = () => {}`) is EXCLUDED: that name
    IS a callable we want dispatch tables to resolve to, not a data shadow.
    """
def _js_module_bound_names(`root, source: bytes) -> set[str];

"""True when a JS/TS import specifier names a module outside the scanned corpus.

    Reuses `_resolve_js_import_target`, so this is graphify's own verdict rather
    than a second opinion: a specifier it cannot resolve is an external package
    (the `ref`-namespaced branch). The extra `node_modules` test covers the case
    where resolution *succeeds* but lands in a dependency tree — a `tsconfig`
    `paths` entry mapping a package to its own installed copy
    (`"lucide-react": ["./node_modules/lucide-react"]`) is common, and
    `node_modules` is pruned from every scan, so the target is never a node.
    """
def _js_import_binds_external(raw: str, str_path: str) -> bool;

"""Names an `import` binds to a module OUTSIDE the corpus.

    An imported name is a module-scoped binding: within this file it denotes the
    imported symbol and nothing else. Neither shadow set collects it —
    `_js_local_bound_names` reads parameters and `variable_declarator`s and
    `_js_module_bound_names` only the latter — so the name reaches
    `_emit_indirect_ref` as an unresolved by-name reference, gets resolved against
    the corpus-wide label index, and fabricates an `indirect_call` (INFERRED, 0.8)
    to any unique same-named callable elsewhere in the corpus. That is the symptom
    already fixed for `catch` bindings, single-parameter arrows and untracked
    closures; an import binding is the same class of shadow, and a UI kit makes it
    land constantly because icon names (`Palette`, `Search`, `Filter`) collide with
    ordinary component names.

    Only imports the corpus cannot contain are collected. A relative specifier
    resolves to a real file and that edge is the graph's whole point, so those
    names stay resolvable.
    """
def _js_external_import_names(`root, source: bytes, str_path: str) -> set[str];

"""Yield identifier value-nodes of a JS/TS object/array literal that are
    function-reference candidates: object property VALUES and shorthand properties
    (`{ handler }`), and array elements. Keys and inline methods are not references."""
def _js_dispatch_value_idents(coll_node) -> Generator[any, any, any];

"""Find the body node using config.body_field, falling back to child types."""
def _find_body(`node, config: LanguageConfig) -> any;

"""Recognize unambiguous TypeScript type contexts around an import call."""
def _js_import_is_type_only(`node) -> bool;

"""Detect dynamic import() calls in JS/TS and emit imports_from edges.

    Handles patterns like:
      await import('./foo.js')
      import('./foo.js').then(...)
      const m = await import(`./foo`)

    Returns True if the node was a dynamic import (caller should skip normal call handling).
    """
def _dynamic_import_js(
    `node, source: bytes, caller_nid: str, str_path: str, edges: list, seen_dyn_pairs: set
) -> bool;

"""Recursively unwrap declarator to find the innermost identifier (C++)."""
def _get_cpp_func_name(`node, source: bytes) -> str | None;

"""Return the bare variable name from a C++ declaration declarator, unwrapping
    pointer/reference/init wrappers (``*f``, ``&r``, ``f = Foo()``). Returns None
    for anything that isn't a plain named local (arrays, function pointers,
    structured bindings) so the type table never records a guessed receiver."""
def _cpp_declarator_name(`node, source: bytes) -> str | None;

"""Collect ``param -> ClassName`` from the enclosing function's parameter
    list (#3215). Passing state by ``const&``/``*`` and calling through it is
    the dominant C++ idiom, but the type table was built from local variable
    declarations only, so every call through a parameter receiver was silently
    skipped. Same precision rules as :func:`_cpp_local_var_types`: class-like
    type nodes only, qualified names keyed by their simple tail, and no entry
    ever overwritten (locals win over parameters).
    """
def _cpp_parameter_types(body_node, source: bytes, table: dict[str, str]) -> None;

"""Collect ``field -> ClassName`` from class/struct member declarations
    (#3215), so a member-field receiver (``Inner.IsOk()`` inside a method)
    can be typed. A field name declared with two different types maps to ""
    so the caller can drop it as ambiguous.
    """
def _cpp_field_types(`root, source: bytes, table: dict[str, str]) -> None;

"""Recognize only a whole-file #ifndef NAME / #define NAME wrapper."""
def _cpp_is_header_guard(`node, source: bytes) -> bool;

"""Lexical scope keeps unnamed-namespace barriers without naming their types."""
def _cpp_lookup_scope(`node, source: bytes) -> str;

"""Literal enclosing namespace/type identity; anonymous scopes are unknown."""
def _cpp_qualified_name(`node, name: str, source: bytes) -> str;

"""Literal zero-argument member facts; unsupported syntax stays an ambiguity record."""
def _cpp_member_record(`node, declarator, name: str, source: bytes) -> dict;

def _cpp_plain_template_parameters(`node, source: bytes) -> list[str];

"""Compare only nondependent, parameterless member declarations and definitions."""
def _cpp_zero_arg_member_signature(`node, source: bytes) -> tuple | None;

"""Prove a same-file primary owner instead of erasing arbitrary template arguments.

    shortcut: only unique parameterless primitive-returning members are matched,
    use signature-aware template resolution for overloads or dependent signatures.
    """
def _cpp_primary_template_function_name(`node, source: bytes, classes: dict) -> str | None;

"""Template arguments may depend on a parameter; qualified concrete names do not."""
def _cpp_type_is_dependent(`node, source: bytes) -> bool;

"""Keep qualification and pointer shape; unsupported declarations stay unknown."""
def _cpp_declared_receiver_type(`node, declarator, source: bytes) -> str;

"""A template argument list changes specialization, not the member's name."""
def _cpp_call_name(`node, source: bytes) -> str | None;

"""Pairs of receiver/member names and their following access operators."""
def _cpp_receiver_chain(`node, source: bytes) -> list[list[str]];

"""Persist lexical type declarations; unsupported aliases still shadow outer names."""
def _cpp_resolution_facts(
    `root, source: bytes
) -> tuple[list[dict], dict[str, int], dict[str, str]];

"""Literal bases and member-name barriers, without resolving overloads or dispatch."""
def _cpp_class_lookup_facts(`node, source: bytes) -> dict;

def _cpp_class_fields(`node, source: bytes, positions: dict[str, int]) -> dict[str, str];

"""Lexical lifetimes of named C++ locals/parameters, not corpus callees."""
def _cpp_local_binding_ranges(
    body, source: bytes
) -> dict[str, list[tuple[int, int, str, str, str, bool]]];

"""Collect ``var -> ClassName`` from local variable declarations in a C++
    function body, for receiver-type inference in the cross-file member-call pass
    (#1547). Handles ``Foo f;``, ``Foo* f;``, ``Foo *f = ...;``, ``Foo f = Foo();``.

    Only a class-like (``type_identifier``/``qualified_identifier``) type with a
    single named declarator is recorded — PRECISION over recall: a built-in type
    (``int x``), an ambiguous multi-declarator line, or an un-nameable declarator
    contributes nothing rather than a guess. A qualified type ``ns::Foo`` records
    its simple tail ``Foo`` so it keys to the type's definition node label.
    """
def _cpp_local_var_types(body_node, source: bytes, table: dict[str, str]) -> None;

"""Collect ``var -> Type`` from local ``let``/``var`` bindings in a Swift
    function body, so a member call on the local (``x.method()``) resolves to Type
    in the cross-file member-call pass (#1604).

    Two initializer shapes are recorded, PRECISION over recall:
      - a constructor call ``let x = Type()`` (``_swift_constructor_type``);
      - a static-member access ``let x = Type.shared`` (a navigation_expression
        with an upper-cased head) — the singleton-cached-into-a-local idiom, one
        of the most common Swift call patterns and previously resolved to nothing.
    A factory call (``let x = Factory.make()``) has no in-file type; when
    ``factory`` is given, the pending ``name -> (Factory, method)`` binding is
    stashed there (label-only) for corpus-side resolution against the factory
    method's plain return type (#2561).
    Nested function declarations are not descended into (their locals are scoped
    away); the first binding for a name wins, so a class property of the same name
    already in the table is not overwritten.
    """
def _swift_local_var_types(
    body_node,
    source: bytes,
    table: dict[str, str],
    factory: dict[str, tuple[str, str]] | None = None,
) -> None;

"""Resolve a C# declared type to a receiver-typable class name, or None.

    Predefined primitives (``int``/``bool``/``string``) and ``dynamic`` own no
    definition *inside this corpus*, so an instance lookup on them never binds.
    They are still returned: an extension method (``this string``) dispatches on
    exactly that type name, and dropping the name made every such call
    untypeable before it reached the extension pass (#4828). ``var``
    (``implicit_type``) still carries no name at all.
    """
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

"""What a C# ``foreach`` over a field or property of this type yields.

    Maps the iterated suffix to the element class: ``""`` for a ``T[]`` or a
    sequence of T, ``".Values"`` / ``".Keys"`` for a dictionary's values and
    keys. Iterating a dictionary itself yields ``KeyValuePair`` and is left
    out, as are nested collections, type parameters and primitives.
    """
def _csharp_loop_element_types(type_node, source: bytes) -> dict[str, str];

"""``(field, suffix)`` for a ``foreach`` over ``f``, ``this.f``,
    ``f.Values`` or ``f.Keys``; None for anything else."""
def _csharp_loop_source(expr, source: bytes) -> tuple[str, str] | None;

"""The element type of a C# array or list type, else None (#4246).

    ``xs[i]`` on a ``T[]`` / ``List<T>`` / ``IList<T>`` / ``IReadOnlyList<T>``
    yields a ``T``. A jagged array, a nested collection or any other indexer
    names no single element class, so it stays untyped.
    """
def _csharp_element_type_name(type_node, source: bytes) -> str | None;

"""``[return type, type-parameter count]`` of a C# method declaration (#4266).

    The return type is the class name a receiver of that type would carry
    (``List<T>`` -> ``List``), ``"#i"`` when it is the method's own i-th type
    parameter (bound by the call-site type arguments), or None when no class
    can be named (``void``, a primitive, a class-level type parameter).
    """
def _csharp_return_info(method_node, source: bytes) -> list;

"""``["member", receiver, name, []]`` for ``var x = T.P`` (#5376).

    The variable's type is the declared type of the property or field ``P`` on
    ``T``, which may be declared in another file, so the cross-file pass
    resolves it. Only a plain ``identifier.identifier`` access qualifies.
    """
def _csharp_deferred_member(access, source: bytes) -> list | None;

"""``[receiver, method, type args]`` for ``var x = R.M<A>(...)`` (#4266).

    The variable's type is the return type of the called method, which may be
    declared in another file, so the cross-file pass resolves it. ``receiver``
    is an identifier, ``"this"`` or ``""`` (unqualified call); each type
    argument is its class name or None. Any other call shape returns None.
    """
def _csharp_deferred_call(invocation, source: bytes) -> list | None;

"""Build the SCOPED receiver bindings visible to one C# method (#2299, #2472).

    The C# twin of ``_java_method_receiver_types``, but positional: instead of
    a flat name -> type map, the first element maps each name to a list of
    ``(scope_start_byte, scope_end_byte, type_name)`` bindings and the second
    is the class field/property base scope; ``_csharp_scoped_receiver_type``
    resolves a call site against them by byte offset. C# scoping is per-method,
    so a name rebound in a DIFFERENT method never affects this one (#2299) —
    and, since #2472, an untypable binding (``out var x``) in one lexical scope
    no longer wipes a same-named typed binding in a sibling or nested scope
    (a ``static`` local-function parameter, a declaration in the other branch
    of an ``if``), the regression the #2346 declaration-expression harvest
    exposed under the old method-wide poison rule.

    A receiver_type is stamped iff exactly one binding is lexically visible at
    the call site (innermost scope wins) and it is typed; an untypable or tied
    binding at the call site yields no edge (never a guess). Scope ranges are
    deliberately conservative — a pattern binding (``is T x``, ``case T x:``)
    spans its whole enclosing block, which is over-wide, but over-wide only
    ever produces ties (drop), never a wrong bind. The class-field conflict
    rule is unchanged: a local binding disagreeing with a same-named
    field/property's type drops the name entirely. Residual limitation:
    ``out var x`` itself stays untyped — resolving it from the callee's
    ``out`` parameter signature is a separate, pre-existing gap.
    """
def _csharp_method_receiver_types(
    method_node, source: bytes, field_types: dict[str, str]
) -> tuple[dict[str, list[tuple[int, int, str | list | None]]], dict[str, str | None]];

"""Resolve a C# receiver name to its type at a specific call offset (#2472).

    ``table`` is the (scoped bindings, field base) pair built by
    ``_csharp_method_receiver_types``. Bindings whose scope contains the call
    offset are candidates and the innermost (smallest-range) one wins; no
    candidate at all falls back to the class field/property base scope. A tie
    at the innermost range (an illegal same-declaration-space clash, e.g. a
    parameter redeclared as a top-level local, or two sibling pattern bindings
    of the same name) or an untypable winner yields None — no edge, never a
    guess.
    """
def _csharp_scoped_receiver_type(
    table: tuple[dict[str, list[tuple[int, int, str | list | None]]], dict[str, str | None]] | None,
    name: str | None,
    call_byte: int,
) -> str | list | None;

"""Whether ``name`` is a local, parameter, field or property at ``call_byte``.

    Typed or not: an untyped binding (``var x = F()``, ``x => ...``) is still a
    value, so ``x.M()`` on it must never be read as a static call on a type
    that happens to be named ``x``.
    """
def _csharp_receiver_is_declared(
    table: tuple[dict[str, list[tuple[int, int, str | list | None]]], dict[str, str | None]] | None,
    name: str,
    call_byte: int,
) -> bool;

"""Add TS/JS receiver bindings to ``table`` (name -> TypeName), for member-call
    resolution beyond the constructor-injected `this.field` case (#1630):

      * local ``const/let/var x = new Foo()`` -> ``x: Foo`` (Pattern A);
      * a type-annotated parameter ``(svc: Svc)`` -> ``svc: Svc`` (Pattern B), so a
        call on the param — including inside a returned closure — resolves.

    File-scoped, first-binding-wins (merged into the constructor-injection table,
    which is populated first and therefore wins on a name clash). Only a bare
    ``type_identifier`` (a single class/interface name) is recorded — an array,
    union, generic, qualified, or predefined type is skipped (precision over
    recall, matching the receiver-typed resolvers for Swift/C#/C++)."""
def _ts_receiver_type_table(
    `root,
    source: bytes,
    table: dict[str, str],
    field_table: "dict[str, dict[str, str]] | None" = None,
) -> None;

with entry {
    _TS_STATIC_SUFFIX = "\x00static";
}

"""Put each class's field types on its node as `_ts_fields`.

    Node ids are casefolded, so `class UsecaseVisitor` and `const usecaseVisitor`
    in one file are one node, labeled after either name; classes are matched the
    same way, and two classes folding together keep only the fields they type
    alike."""
def _ts_attach_class_fields(
    result: dict, field_table: dict[str, dict[str, str]], str_path: str
) -> None;

"""Whether ``node`` runs in a `static` method, where `this` is the class.
    Arrow functions keep the enclosing `this`; other functions end the search."""
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

"""The `this` field that ``name`` was destructured from, or None.

    `const { creator } = this` and `const { creator: c } = this` in the function
    around the call (or around an arrow function holding it, since an arrow keeps
    the outer `this`) make `creator` / `c` the `creator` field. The search stops at
    the first function that binds its own `this`, and only reads declarations of
    that function itself, not of functions nested in it."""
def _ts_field_destructured_from_this(ident, name: str, source: bytes) -> str | None;

"""Return the call_expression node if `value_node` is a `require(...)` call
    or `require(...).x` member access. Otherwise None."""
def _find_require_call(value_node) -> any;

"""True only when `value_node` is a literal `require(...)` call (or
    `require(...).x`). `_find_require_call` matches any `identifier(...)` callee,
    so the module-scope binding guard must name-check the callee; otherwise it
    also suppresses real `const x = factory()` nodes and breaks #2604/#2552
    (#4634)."""
def _js_value_is_require(value_node, source: bytes) -> bool;

"""The string literal argument of a `require(...)` call, or None."""
def _js_require_specifier(value_node, source: bytes) -> str | None;

"""True when a `require(...)` binding's specifier resolves to a file in the
    corpus. A require of an external package (`require('some-plugin')`) has no
    file to redirect `new X()`/`extends X` to, so suppressing its local node the
    same way as a resolvable require leaves the use with no edge at all (#4688)
    -- the caller should only suppress the node for the resolvable case."""
def _js_require_resolves_locally(value_node, source: bytes, str_path: str) -> bool;

"""Detect CommonJS require imports inside lexical_declaration / variable_declaration.

    Handles three patterns:
      const { foo, bar } = require('./mod')   → file → mod (imports_from), file → foo, file → bar
      const mod         = require('./mod')   → file → mod (imports_from)
      const x           = require('./mod').y → file → mod (imports_from), file → y

    Returns True if any require import was found.
    """
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

"""Emit a node + `contains` edge for every named `function`/generator
    declaration lexically nested inside *container_node*, scoped under
    *parent_nid*, and track its body so calls made from inside it resolve
    instead of dangling (#2653).

    Recurses through non-function children AND through the bodies of nested
    arrow / function expressions, so a `function` declared inside an arrow
    callback (`useEffect(() => { function h(){} })`) or inside an arrow-defined
    component (`const Panel = () => { function handleClick(){} }`, the React
    idiom that motivated #2653) is captured too. Anonymous closures themselves
    are not noded — they are attributed to the nearest enclosing named scope,
    which is *parent_nid*.
    """
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
) -> None;

"""Emit a node + `contains` edge for every function lexically nested inside
    *container_node*, scoped under *parent_nid*, track its body, and record lexical
    scope hierarchy so calls resolve to local definitions instead of falling through
    to corpus-wide resolution (#3405).

    Recurses through Python statements (including blocks, if/while/for/try/with),
    unwrapping `decorated_definition` when it wraps a `function_definition`.
    """
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
) -> None;

"""Collect the TOPMOST closure nodes (arrow / function expressions) under
    ``node``, without descending into a found closure — its nested closures
    belong to it and are reached by the walk_calls closure descend (#1630)."""
def _js_topmost_closures(`node, out: list) -> None;

"""Classify the symbol an `assignment_expression` LHS defines when its RHS
    is a function. Returns (kind, owner_name, member_name) or None.

      this.foo = fn            → ("this",      None,  "foo")
      exports.foo = fn         → ("exports",   None,  "foo")
      module.exports.foo = fn  → ("exports",   None,  "foo")
      Foo.prototype.bar = fn   → ("prototype", "Foo", "bar")

    An arbitrary identifier receiver is returned as ``("object", name, member)``.
    It is only materialized after the caller proves that the identifier is a
    direct object-literal binding in the enclosing function. Keeping that scope
    check at the caller avoids the bare-named / phantom-god-node failure mode
    that the module-level guard (#1077) prevents.
    """
def _js_member_assignment_target(left, source: bytes) -> any;

"""Materialize callable members assigned in ``body`` (#1322/#3408).

    ``this.X = fn`` members attach to ``this_owner_nid`` — as ``method`` edges
    with a ``.X()`` label when the owner is a named function or class
    (``this_as_method``), and as ``contains`` edges with an ``X()`` label when
    the owner is the file node (the enclosing function is anonymous: an IIFE
    or a callback argument, e.g. an AngularJS ``.service(...)`` body).
    ``api.X = fn`` members attach to the object-literal binding declared in
    the same body, exactly as before — the scope proof that keeps the #1077
    phantom-god-node guard intact.
    """
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
) -> None;

"""Find names of identifiers exported from a JS module (CJS or ESM)."""
def _js_find_exported_objects(program_node, source: bytes) -> set[str];

"""Handle lexical_declaration (arrow functions, CJS requires, module-level const literals) for JS/TS. Returns True if handled."""
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

"""Emit enum member nodes, and a container node for a TS `namespace`/`module`.

    `namespace Foo {}` parses as `internal_module` (with `name`/`body` fields);
    `module Bar {}` and ambient `declare module "pkg" {}` parse as a named
    `module` node that exposes no fields, so its name and body are found
    positionally. Without this the container was never a node — its members were
    still reached by the default recurse but lost their namespace context. The
    members stay file-contained (parity with C#'s `_csharp_extra_walk`); the
    namespace becomes a sibling marker node so it is queryable. Returns True if
    handled.

    The guard requires `is_named` because the anonymous `module` keyword token
    shares the `module` type string and would otherwise match here.
    """
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

"""Id of a namespace scope, stored in ``scope_chain`` / ``scope_id`` metadata.

    Row and column, not ``start_byte``: a CRLF checkout has one more byte per
    line than an LF checkout of the same file, so a byte offset gave a
    Windows and a Linux build of the same commit different graph.json
    metadata. Row and column are the same for both and just as unique.
    """
def _csharp_scope_id(`node) -> str;

def _csharp_namespace_name(`node, source: bytes) -> str;

"""Handle C# namespaces, enum members, and transparent class-member wrappers."""
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

"""Handle enum_entry for Swift. Returns True if handled."""
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

"""The type an `extension_definition` extends, or None if it names no type.

    The receiver is the single parameter of the first non-`using` parameter
    clause: `extension (using c: Ctx)(x: Int)` extends `Int`, not `Ctx`. A
    generic (`List[A]`) or qualified (`pkg.Thing`) receiver binds to its type
    name. A receiver typed by the extension's own type parameter
    (`extension [T](t: T)`) extends every type, so there is no type to own it.
    """
def _scala_extension_receiver_name(`node, source: bytes) -> str | None;

"""Emit a node per Scala 3 enum case with a case_of edge, and scope extension
    methods to their receiver type. Returns True if handled.

    tree-sitter-scala wraps the members of an `enum` in `enum_case_definitions`,
    whose children are `simple_enum_case` (`case Red`) or `full_enum_case`
    (`case Add(x: Int, y: Int)`); both carry the case name as an `identifier`
    child. Without this the enum type is a class-like container whose members
    were never emitted, leaving the type a leaf. This is the Scala parity of
    Java #1719 (enum_constant), Kotlin #1738 (enum_entry), and Swift.

    Case constructor parameter types (`Add(x: Int)`) and per-case `extends`
    arguments are not linked; the case node and its case_of edge are the fix
    for the dropped members.
    """
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

"""The name a typedef declarator introduces: `Handle`, `*HandlePtr`,
    `(*Fn)(int)`, `Arr[4]` each wrap one `type_identifier`."""
def _cpp_declarator_type_name(declarator, source: bytes) -> str | None;

"""`Bar` for `ns::Bar` or `ns::Bar<T>`: the name a qualified type ends in."""
def _cpp_type_last_name(type_node, source: bytes) -> str | None;

"""The type names a namespace- or file-scope `using X = ...;` or `typedef`
    declares. A member alias (`using value_type = T;` in a class) is not one: it
    sits in every container and C++ member ids are not class-qualified, so they
    would fold into one hub. Neither is the struct a C-style
    `typedef struct Foo {...} Foo;` names (the struct's own node is it), nor a
    same-name re-export (`using Bar = ns::Bar;`), which denotes the original
    type and declares no new name. An include guard or `#if`/`#ifdef` block is
    a conditional wrapper, not a scope, so an alias inside one keeps the scope
    around it."""
def _cpp_alias_names(`node, source: bytes) -> list[str];

"""Emit a node per C++ enumerator with a case_of edge. Returns True if handled.

    An `enum` / `enum class` is now a class-like container, so its body
    (`enumerator_list`) is walked with the enum as parent. Each member is an
    `enumerator` node (`Red`, `Green = 2`) whose name is its `name` field
    (an `identifier`). Without this the enum type is a memberless leaf. This is
    the C++ parity of Java #1719 (enum_constant), Swift, and Scala.

    A namespace- or file-scope alias (`using X = ...;`, `typedef ... X;`) also
    gets a type node contained by the file, so a type reference to it lands on
    a sourced declaration instead of a sourceless stub. Returns False for it:
    the walk goes on, so a typedef'd struct body still gets its own node.
    C++ never populates namespace_stack, so the id is the one
    ensure_named_node looks up for a name declared in this file.
    """
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

"""Emit a node per PHP 8.1 enum case with a case_of edge. Returns True if handled.

    A PHP `enum` is in class_types, so its type and methods are captured, but the
    cases (`case Hearts = 'H';`) nest in the `enum_declaration_list` body as
    `enum_case` nodes that nothing handled — they were dropped, leaving the enum a
    caseless leaf. Each case carries its name in a `name` field. Emit a node plus a
    `case_of` edge per case, the PHP parity of Java #1719 (enum_constant), Swift,
    Scala, and C++.
    """
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

"""Handle enum_constant for Java. Returns True if handled."""
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

"""Handle enum_entry for Kotlin. Returns True if handled (#1700 Kotlin half)."""
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

"""Dotted package FQN from the file's ``package_header``, or None.

    Grammar 1.1.0 puts the path in a ``qualified_identifier`` child; older
    forks use an ``identifier`` that spans the whole dotted text. Either way
    the node's text IS the FQN.
    """
def _kotlin_package_name(`root, source: bytes) -> str | None;

"""Flatten a Kotlin ``navigation_expression`` chain into its dotted
    identifier segments (``com.example.Foo.bar`` -> [com, example, Foo, bar]).

    Returns None when any segment is not a plain identifier — a receiver that
    is an expression, a call, ``this``, a string literal, etc. must never read
    as a qualified name (#2550). Older grammars with a different navigation
    shape also bail here, preserving their current behavior.
    """
def _kotlin_nav_identifier_segments(nav, source: bytes) -> list[str] | None;

with entry {
    _KOTLIN_IDENTIFIERS = ("identifier", "simple_identifier", "type_identifier");
}

"""`Greeter`, `a.b.Greeter`, `Greeter?` and `Box<T>` name `Greeter`/`Box`; other types name nothing."""
def _kotlin_type_name(type_node, source: bytes) -> str | None;

"""The type a Kotlin binding declares, or `Name` for `= Name(...)`; "" when neither says."""
def _kotlin_declared_type(decl, initializer, source: bytes) -> str;

def _kotlin_binding_name(decl, source: bytes) -> str | None;

"""Type of `name` if this (multi-)variable declaration binds it ("" if untyped), else None."""
def _kotlin_variable_binding(decl, name: str, initializer, source: bytes) -> str | None;

def _kotlin_property_binding(prop, name: str, source: bytes) -> str | None;

"""Declared type of receiver `name` at `call`, by Kotlin's lexical scoping.

    "" means a binding in scope hides the name but gives no type, None that
    nothing in this file binds it (an inherited or top-level property elsewhere).
    """
def _kotlin_receiver_type(call, name: str, source: bytes, *, this_field: bool = False) -> str
    | None;

"""1-based line of the first ERROR/MISSING node under ``root`` (#2551).

    Descends the first erroring child at each level (document order), so it
    lands on the earliest error region. Some recoveries set ``has_error``
    without materializing an ERROR/MISSING child (zero-width recovery); the
    deepest still-erroring node's line is reported for those.
    """
def _first_parse_error_line(`root) -> int;

"""1-based line of the first ERROR that spans more than one line.

    The #2551 warning gate selects on a multiline region (or a total loss), so
    that region is the actionable location. Earlier single-line recoveries can
    sit far above it: in a decorator-heavy TS file, `@(Link().toMany())` errors
    on line 14 but keeps every symbol, while the multiline chain on line 33 is
    the one the reader needs (#4711).
    """
def _first_multiline_error_line(`root) -> int;

"""True if any materialized ERROR node spans more than one line (a
    recovery region large enough to plausibly drop symbols, vs a tiny
    single-line recovery that extracts completely)."""
def _has_multiline_error(`root) -> bool;

"""The callee identifier of a C# call-site name node.

    A plain `identifier` reads as-is; a `generic_name` (`Get<int>`) reads its
    identifier child so the type-argument list never leaks into the callee
    name (#3406). Falls back to raw text for anything else.
    """
def _csharp_bare_call_name(name_node, source: bytes) -> str;

"""``(name, receiver)`` nodes of a C# member call's ``function``, else None.

    `recv.M()` is a member_access_expression (`expression` + `name` fields).
    `recv?.M()` is the same call behind a null check: a
    conditional_access_expression whose `condition` is the receiver and whose
    member_binding_expression child carries the name. Reading both shapes here
    keeps `?.` on the receiver-typed path; the raw-text fallback split
    `_window?.Refresh` on the dot and recorded the receiver as `_window?`,
    which no receiver table types, so the call was dropped (#3797).
    """
def _csharp_member_call_parts(fn_node) -> any;

"""Resolve a C# type name, whether it was qualified, and its qualifier prefix."""
def _read_csharp_type_name(`node, source: bytes) -> tuple[str, bool, str] | None;

"""Return ``ClassName`` if ``node`` is a ``ClassName.new(...)`` call, else None.

    Only a bare capitalized constant receiver counts (``Processor.new``);
    namespaced (``A::B.new``) and dynamic receivers are intentionally ignored so
    the binding stays unambiguous.
    """
def _ruby_new_class_name(`node, source: bytes) -> str | None;

"""The single class a Python annotation or constructor callee names, else None.

    ``Request``, ``httpx.Request``, ``"Request"``, ``Optional[Request]`` and
    ``Request | None`` all name ``Request``. A container (``list[Request]``), a
    union of two classes, or a lowercase callee (``make_client``,
    ``Client.from_url``) names no single class, so it stays untyped.
    """
def _python_class_ref(`node, source: bytes) -> str | None;

"""Map ``name -> ClassName`` for the parameters and locals of one Python function.

    Typed from a class annotation on a parameter or local (``request: Request``,
    ``x: Client = ...``), a constructor call (``client = Client(...)``) or a
    context manager (``with Client(...) as client``). Same 100%-confidence
    contract as the Ruby table: the table is flow-insensitive, so a name bound
    to anything that is not one class -- an untyped parameter, a factory call, a
    loop target, a second class, tuple unpacking, a lambda parameter, a ``match``
    capture, an import -- maps to ``None`` for the whole function and is never
    resolved. Nested functions are their own caller and are not entered. Calls
    inside a lambda or a nested class body are attributed to this function, so
    every name those bind is poisoned rather than typed.
    """
def _python_local_class_bindings(
    body_node, source: bytes, *, factory_bindings: dict[str, list[int]] | None = None
) -> dict[str, str | None];

"""Map ``local_var -> ClassName`` for ``var = ClassName.new`` within one Ruby
    method body, not descending into nested method definitions.

    100%-confidence contract: a variable assigned more than once, or to anything
    other than a single ``Constant.new``, maps to ``None`` (ambiguous) so callers
    never resolve it. Only the certain single-binding case carries a type.
    """
def _ruby_local_class_bindings(body_node, source: bytes) -> dict[str, str | None];

"""Collect every name bound as a local variable or parameter in one Ruby
    method body (the method's own parameters plus in-body assignments, block
    parameters, ``for`` variables and ``rescue`` captures).

    A paren-less ``identifier`` in Ruby is a method call on ``self`` (``build``)
    *unless* a local of that name is in scope — the exact rule Ruby's own parser
    uses to tell ``build`` (a send) from ``x`` (a variable read). The call-walk
    uses this set to make that distinction; see the bare-self-send branch there.

    Deliberately over-inclusive and does not descend into nested ``def`` bodies
    (which open their own scope): a missed binding only suppresses a candidate
    call (fail-closed), it never invents a wrong edge.
    """
def _ruby_local_names(body_node, source: bytes) -> frozenset[str];

"""Last constant of a ``constant`` or ``scope_resolution`` (``A::B::C`` -> ``C``)."""
def _ruby_const_last_name(`node, source: bytes) -> str;

"""Full constant path of a ``constant`` or ``scope_resolution`` (``A::B::C`` kept whole)."""
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

"""Whether a lexical body can alter Ruby method lookup dynamically."""
def _ruby_body_has_lookup_barrier(body_node, source: bytes) -> bool;

"""Whether any lexical scope in a file activates or defines a refinement.

    ``using`` affects method lookup for definitions in its lexical scope, while
    ``refine`` can hide method bodies behind a dynamic lookup layer.  The
    extractor does not model that lexical activation precisely, so inherited
    implicit-self promotion fails closed for the whole file.
    """
def _ruby_file_has_refinement_barrier(root_node, source: bytes) -> bool;

"""Return explicit constant owners modified outside their class body."""
def _ruby_external_method_owners(root_node, source: bytes) -> list[str];

with entry {
    _RUBY_CLASS_FACTORIES = frozenset({("Struct", "new"), ("Class", "new"), ("Data", "define")});
}

"""Ruby: a constant assignment whose RHS is ``Struct.new(...)``,
    ``Class.new(Super)`` or ``Data.define(...)`` defines a class named after the
    constant (#1640). Synthesize the class node, attach block-defined methods via
    ``method`` (by recursing the block with the new node as parent), and emit an
    ``inherits`` edge for ``Class.new(Super)``. Returns True if handled.
    """
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

"""True if a Lua `function_call` node invokes `require`, parenthesized or not."""
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

"""Walk up the AST to extract grouped routing prefixes (#3409)."""
def _php_get_route_name(closure_node, src: bytes) -> str | None;

with entry {
    _parser_tls = threading.local();
}

def _get_parser(ts_module: str, ts_language_fn: str) -> any;

def _build_parser(ts_module: str, ts_language_fn: str) -> any;

"""Generic AST extractor driven by LanguageConfig.

    ``source_override`` parses the given bytes instead of reading ``path``, while
    still keying nodes/edges off ``path``. Lets container formats (e.g. Vue SFCs)
    mask the wrapper and parse just the embedded ``<script>``.
    """
def _extract_generic(
    path: Path,
    config: LanguageConfig,
    *,
    source_override: bytes | None = None,
    scan_root: Path | None = None,
    preserve_call_sites: bool = False,
) -> dict;

"""Mark the member nodes that stand for both a public `name` and `#name`.

    A class's `foo` and `#foo` get one node id (ids drop `#`), labeled after
    whichever is declared first, and a public property (`newResponse = () => ..`)
    has no node of its own, so it shares the `#newResponse()` node. A call
    written `c.foo()` may only reach that node when the class really declares a
    public `foo`; with `#foo` alone the public `foo` comes from somewhere else (a
    base class), and the node is not its target. The mark lives on the node so
    a changed-files rebuild, which reads unchanged files from graph.json, sees it.
    """
def _ts_mark_public_twins(`root, source: bytes, result: dict) -> None;

"""Return the head symbol of a Python `decorator` node.

    The Python twin of `_ts_decorator_name`, differing only in grammar node
    names: `@traced` -> the identifier; `@retry(times=3)` -> the `function` of
    the `call`; `@app.route("/")` / `@mod.deco` -> the `attribute` (the symbol
    itself, not the module alias it is reached through).
    """
def _python_decorator_name(deco_node, source: bytes) -> str | None;

"""The symbol a decorator expression applies: the outermost call's name.

    `f` -> f; `f()` / `x.f()` -> f; `@Component({...})` -> Component. A
    parenthesized decorator is unwrapped first. tree-sitter-typescript 0.23.2
    cannot parse a call chain in decorator position (`@(Link().toMany())`): it
    wraps `Link().` in an ERROR and parses `toMany()` as a SIBLING of the ERROR
    inside the parentheses. The applied decorator is still that outermost call,
    which is the last named call child, never the one buried in the ERROR
    (#4711). Without this the whole parenthesized decorator contributed no edge,
    though most of its expression parsed.
    """
def _ts_decorator_target_name(expr, source: bytes) -> str | None;

"""Return the head symbol of a TS `decorator` node.

    `@Injectable` -> the identifier; `@Component({...})` / `@Input()` -> the
    `function` of the call_expression; `@ng.Component()` / `@core.Injectable` ->
    the `property` of the member_expression (the imported symbol, not the
    namespace alias); `@(Link().toMany())` -> the outermost call, `toMany`.
    """
def _ts_decorator_name(deco_node, source: bytes) -> str | None;

"""Name of a `method_definition`, matching the id the function-types branch
    builds (`_make_id(class_nid, name)`)."""
def _ts_method_name(method_node, source: bytes) -> str | None;

"""Collect `decorator` nodes under `node` (e.g. parameter decorators inside a
    method's formal_parameters, or a field's own decorator), without crossing into
    a nested class or a nested method, which own their own decorators."""
def _ts_descendant_decorators(`node) -> list;

"""Emit `references` edges (context="decorator") from a class and its members
    to the symbols of the TS decorators applied to them.

    Decorators only occur on classes, class members, and parameters, so a single
    pass over the class declaration covers them. Members that are graph nodes
    (methods, incl. the constructor) own their decorators and their parameter
    decorators; members that are not nodes (fields, parameters) attribute to the
    enclosing class. Targets go through `ensure_named_node`, so a decorator
    imported from another module (the common case — `@Component` from
    `@angular/core`) becomes a sourceless stub the corpus rewire collapses onto
    the real definition.
    """
def _ts_emit_decorator_edges(
    class_node, class_nid: str, stem: str, source: bytes, ensure_named_node, add_edge
) -> None;
