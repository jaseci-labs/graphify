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
def _rust_collect_type_refs(
    `node,
    source: bytes,
    generic: bool,
    out: list[tuple[str, str]],
    local_types: frozenset[str] = local_types_default_,
);
def _rust_simple_generic_impl_key(`node, source: bytes) -> str | None;
def _rust_use_module(argument: str) -> str;
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

def _rust_macro_arg_calls(token_tree) -> list[tuple[str, int]];
def _rust_qualifier_type(path_node, source: bytes) -> str | None;
def _rust_is_trait_ref(`node, idx: int, role: str) -> bool;
def _rust_type_last_segment(text: str) -> str;
def extract_rust(path: Path) -> dict;
