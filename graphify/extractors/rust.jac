"""Rust extractor. Moved verbatim from graphify/extract.py."""

import operator;

import from __future__ { annotations }

import hashlib;

import re;

import from pathlib { Path }

glob _RUST_BUILTIN_TYPES: frozenset[str];

glob _RUST_TRAIT_METHOD_BLOCKLIST: frozenset[str];

glob _RUST_PRIMITIVE_TYPES: frozenset[str];

glob _RUST_EXPRESSION_MACROS: any;

with entry {
    _RUST_BUILTIN_TYPES = frozenset({
        "String",
        "str",
        "Option",
        "Result",
        "Vec",
        "VecDeque",
        "Box",
        "Rc",
        "Arc",
        "Weak",
        "RefCell",
        "Cell",
        "Cow",
        "Pin",
        "HashMap",
        "HashSet",
        "BTreeMap",
        "BTreeSet",
        "BinaryHeap",
        "Path",
        "PathBuf",
        "OsStr",
        "OsString",
        "CStr",
        "CString",
        "Duration",
        "Instant",
        "SystemTime",
        "Ordering",
        "Range",
        "RangeInclusive",
        "RangeFrom",
        "RangeTo",
        "RangeFull",
        "PhantomData",
        "ManuallyDrop",
        "NonZeroU8",
        "NonZeroU16",
        "NonZeroU32",
        "NonZeroU64",
        "NonZeroUsize",
        "Some",
        "None",
        "Ok",
        "Err",
        "Self",
        "Default",
        "Clone",
        "Copy",
        "Debug",
        "Display",
        "Error",
        "From",
        "Into",
        "TryFrom",
        "TryInto",
        "AsRef",
        "AsMut",
        "Iterator",
        "IntoIterator",
        "Extend",
        "PartialEq",
        "Eq",
        "PartialOrd",
        "Ord",
        "Hash",
        "Send",
        "Sync",
        "Sized",
        "Drop",
        "Deref",
        "DerefMut",
        "Future",
        "Fn",
        "FnMut",
        "FnOnce",
    });
    local_types_default_ = frozenset();
}

glob local_types_default_: any;

"""Walk a Rust type expression; append (name, role) tuples.

    A name in ``_RUST_BUILTIN_TYPES`` is skipped unless ``local_types`` holds it:
    a file that defines its own ``struct Result<T>`` shadows the prelude, and its
    references must survive. Filtering the bare name alone would erase a
    legitimate user type that happens to share a std name.
    """
def _rust_collect_type_refs(
    `node,
    source: bytes,
    generic: bool,
    out: list[tuple[str, str]],
    local_types: frozenset[str] = local_types_default_,
) -> None;

"""Return a stable owner/arity key for a deliberately narrow impl shape."""
def _rust_simple_generic_impl_key(`node, source: bytes) -> str | None;

"""The name a plain `use` imports from: the last path segment of its argument, as
    written (`a::b` -> `b`, `a::b as c` -> `b as c`, `a::*` -> `a`)."""
def _rust_use_module(argument: str) -> str;

"""Each binding of a `use` tree, as the argument of a plain `use` that binds the same
    name, with its line: `a::{b, c as d, e::{self}, f::*}` gives `b`, `c as d`, `a::e`
    and `f::*` (as `use a::b;` and so on would: only the last segment counts). Paths
    keep their text as written."""
def _rust_use_bindings(
    `node, source: bytes, prefix: str = "", self_path: str = ""
) -> list[tuple[str, int]];

with entry {
    _RUST_TRAIT_METHOD_BLOCKLIST = frozenset({
        "new",
        "default",
        "parse",
        "from_str",
        "now",
        "clone",
        "into",
        "from",
        "to_string",
        "to_owned",
        "len",
        "is_empty",
        "iter",
        "next",
        "build",
        "start",
        "run",
        "init",
        "app",
        "get",
        "set",
        "push",
        "pop",
        "insert",
        "remove",
        "contains",
        "collect",
        "map",
        "filter",
        "unwrap",
        "expect",
        "ok",
        "err",
        "some",
        "none",
        "send",
        "recv",
        "lock",
        "read",
        "write",
    });

    _RUST_PRIMITIVE_TYPES = frozenset({
        "bool",
        "char",
        "str",
        "f32",
        "f64",
        "i8",
        "i16",
        "i32",
        "i64",
        "i128",
        "isize",
        "u8",
        "u16",
        "u32",
        "u64",
        "u128",
        "usize",
    });
    _RUST_EXPRESSION_MACROS = frozenset({
        "assert",
        "assert_eq",
        "assert_ne",
        "debug_assert",
        "debug_assert_eq",
        "debug_assert_ne",
        "dbg",
        "eprint",
        "eprintln",
        "format",
        "format_args",
        "panic",
        "print",
        "println",
        "todo",
        "unimplemented",
        "unreachable",
        "vec",
        "write",
        "writeln",
        "debug",
        "error",
        "info",
        "trace",
        "warn",
    });
}

"""Bare `f(...)` calls written inside a macro's arguments.

    Tree-sitter keeps macro arguments as a flat token tree, so `println!("{}", f(x))`
    has no call_expression: it is an `identifier` followed by a `(` token tree.
    A name after `.` or `::` is a method or path call and is left out, as is a
    name followed by `!` (a nested macro, which is its own macro_invocation).
    """
def _rust_macro_arg_calls(token_tree) -> list[tuple[str, int]];

"""The type a `Type::f()` call is qualified by, or None for a module path.

    `Foo`, `crate::a::Foo`, `Foo::<T>`, `Vec::<u8>` and `i32` give their last
    segment without generic arguments; `Self` is returned as is for the caller to
    map to the enclosing impl type. Any other lowercase last segment is a module
    (`fs::read`, `self::helper`), and `<T as Trait>` has no segment of its own:
    both give None.
    """
def _rust_qualifier_type(path_node, source: bytes) -> str | None;

"""Whether ref `idx` collected from a trait position is the trait itself.

    A prelude trait is filtered out (`From<A>` leaves only `A`, as a generic
    argument), and `Fn(A) -> R` sugar, bare or under `for<'a>`, lists its
    parameter and return types as plain types: neither names the trait.
    """
def _rust_is_trait_ref(`node, idx: int, role: str) -> bool;

"""`crate::a::Foo<T>` -> `Foo`: the last path segment, generic arguments dropped.
    A leading `&`, `&'a mut` or `dyn` (`impl Tr for &'a Foo`) is not part of it."""
def _rust_type_last_segment(text: str) -> str;

"""Extract functions, structs, enums, traits, impl methods, statics/consts, and use declarations from a .rs file."""
def extract_rust(path: Path) -> dict;
