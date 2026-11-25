import from __future__ { annotations }

import sys;

import from contextvars { ContextVar }

import from pathlib { Path }

glob _ACTIVE_SCAN_ROOT: "ContextVar[Path | None]";

glob _LANGUAGE_BUILTIN_GLOBALS: frozenset[str];

glob _PYTHON_BUILTIN_NAMES: frozenset[str];

glob _UTF32_BOMS: any;

glob _UTF16_BOMS: any;

glob _SOURCE_FALLBACK_ENCODINGS: any;

glob _warned_source_encodings: any;

with entry {
    _ACTIVE_SCAN_ROOT = ContextVar("_ACTIVE_SCAN_ROOT", default=None);
}

"""Set the in-flight scan root, returning the previous value so the caller
    can restore it — extraction nests (a XAML shard re-enters extract())."""
def set_active_scan_root(`root: "Path | None") -> "Path | None";

"""The scan root of the extraction in flight, or None outside extract().

    A direct ``extract_markdown()`` / ``extract_xaml()`` call (no surrounding
    ``extract()``) sees None and the root-dependent behavior stays off."""
def active_scan_root -> "Path | None";

with entry {
    _LANGUAGE_BUILTIN_GLOBALS = frozenset({
        "String",
        "Number",
        "Boolean",
        "Object",
        "Array",
        "Symbol",
        "BigInt",
        "Date",
        "RegExp",
        "Error",
        "TypeError",
        "RangeError",
        "SyntaxError",
        "ReferenceError",
        "EvalError",
        "URIError",
        "Promise",
        "Map",
        "Set",
        "WeakMap",
        "WeakSet",
        "JSON",
        "Math",
        "Reflect",
        "Proxy",
        "Intl",
        "parseInt",
        "parseFloat",
        "isNaN",
        "isFinite",
        "encodeURIComponent",
        "decodeURIComponent",
        "encodeURI",
        "decodeURI",
        "URL",
        "URLSearchParams",
        "FormData",
        "Blob",
        "File",
        "Headers",
        "Request",
        "Response",
        "AbortController",
        "AbortSignal",
        "TextEncoder",
        "TextDecoder",
        "console",
        "str",
        "int",
        "float",
        "bool",
        "list",
        "dict",
        "set",
        "tuple",
        "bytes",
        "len",
        "range",
        "enumerate",
        "zip",
        "map",
        "filter",
        "sum",
        "min",
        "max",
        "print",
        "open",
        "isinstance",
        "type",
        "super",
        "sorted",
        "reversed",
        "any",
        "all",
        "abs",
        "round",
        "next",
        "iter",
        "hash",
        "id",
        "repr",
        "callable",
        "getattr",
        "setattr",
        "hasattr",
        "delattr",
        "vars",
        "dir",
        "Int",
        "Int8",
        "Int16",
        "Int32",
        "Int64",
        "UInt",
        "UInt8",
        "UInt16",
        "UInt32",
        "UInt64",
        "Double",
        "Float",
        "Bool",
        "Character",
        "Sendable",
        "Codable",
        "Decodable",
        "Encodable",
        "Equatable",
        "Hashable",
        "Identifiable",
        "Comparable",
        "CaseIterable",
        "RawRepresentable",
        "CustomStringConvertible",
        "CustomDebugStringConvertible",
        "AnyObject",
        "LocalizedError",
        "Data",
        "UUID",
        "Decimal",
        "Calendar",
        "Locale",
        "TimeZone",
        "Bundle",
        "IndexPath",
        "IndexSet",
        "NotificationCenter",
        "UserDefaults",
        "FileManager",
        "URLSession",
        "URLRequest",
        "URLComponents",
        "JSONDecoder",
        "JSONEncoder",
        "DateFormatter",
        "NumberFormatter",
        "ISO8601DateFormatter",
        "NSObject",
        "NSString",
        "NSError",
        "NSLock",
        "NSAttributedString",
        "DispatchQueue",
        "DispatchGroup",
        "OperationQueue",
        "RunLoop",
        "View",
        "Color",
        "Font",
    });
    _PYTHON_BUILTIN_NAMES = frozenset({
        "ArithmeticError",
        "AssertionError",
        "AttributeError",
        "BaseException",
        "BaseExceptionGroup",
        "BlockingIOError",
        "BrokenPipeError",
        "BufferError",
        "BytesWarning",
        "ChildProcessError",
        "ConnectionAbortedError",
        "ConnectionError",
        "ConnectionRefusedError",
        "ConnectionResetError",
        "DeprecationWarning",
        "EOFError",
        "Ellipsis",
        "EncodingWarning",
        "EnvironmentError",
        "Exception",
        "ExceptionGroup",
        "False",
        "FileExistsError",
        "FileNotFoundError",
        "FloatingPointError",
        "FutureWarning",
        "GeneratorExit",
        "IOError",
        "ImportError",
        "ImportWarning",
        "IndentationError",
        "IndexError",
        "InterruptedError",
        "IsADirectoryError",
        "KeyError",
        "KeyboardInterrupt",
        "LookupError",
        "MemoryError",
        "ModuleNotFoundError",
        "NameError",
        "None",
        "NotADirectoryError",
        "NotImplemented",
        "NotImplementedError",
        "OSError",
        "OverflowError",
        "PendingDeprecationWarning",
        "PermissionError",
        "ProcessLookupError",
        "RecursionError",
        "ReferenceError",
        "ResourceWarning",
        "RuntimeError",
        "RuntimeWarning",
        "StopAsyncIteration",
        "StopIteration",
        "SyntaxError",
        "SyntaxWarning",
        "SystemError",
        "SystemExit",
        "TabError",
        "TimeoutError",
        "True",
        "TypeError",
        "UnboundLocalError",
        "UnicodeDecodeError",
        "UnicodeEncodeError",
        "UnicodeError",
        "UnicodeTranslateError",
        "UnicodeWarning",
        "UserWarning",
        "ValueError",
        "Warning",
        "ZeroDivisionError",
        "abs",
        "aiter",
        "all",
        "anext",
        "any",
        "ascii",
        "bin",
        "bool",
        "breakpoint",
        "bytearray",
        "bytes",
        "callable",
        "chr",
        "classmethod",
        "compile",
        "complex",
        "copyright",
        "credits",
        "delattr",
        "dict",
        "dir",
        "divmod",
        "enumerate",
        "eval",
        "exec",
        "exit",
        "filter",
        "float",
        "format",
        "frozenset",
        "getattr",
        "globals",
        "hasattr",
        "hash",
        "help",
        "hex",
        "id",
        "input",
        "int",
        "isinstance",
        "issubclass",
        "iter",
        "len",
        "license",
        "list",
        "locals",
        "map",
        "max",
        "memoryview",
        "min",
        "next",
        "object",
        "oct",
        "open",
        "ord",
        "pow",
        "print",
        "property",
        "quit",
        "range",
        "repr",
        "reversed",
        "round",
        "set",
        "setattr",
        "slice",
        "sorted",
        "staticmethod",
        "str",
        "sum",
        "super",
        "tuple",
        "type",
        "vars",
        "zip",
    });
}

def _make_id(*parts_: str) -> str;

def _read_text(`node, source: bytes) -> str;

with entry {
    _UTF32_BOMS = (b"\xff\xfe\x00\x00", b"\x00\x00\xfe\xff");
    _UTF16_BOMS = (b"\xff\xfe", b"\xfe\xff");
    _SOURCE_FALLBACK_ENCODINGS = ("cp1252", "latin-1");
    _warned_source_encodings = set[any]();
}

"""Read a source file as the UTF-8 bytes tree-sitter parses.

    tree-sitter treats its input as UTF-8. Raw bytes in another encoding were
    parsed as-is: a UTF-16 file (interleaved NUL bytes) produced no nodes at
    all, and a Windows-1252 identifier was cut at its first non-UTF-8 byte
    (``CaféOrder`` came out as ``Order``) — both silently.

    Valid UTF-8, with or without a BOM, is returned byte-for-byte, so node ids,
    byte offsets and cache keys for those files are unchanged. A UTF-16 or
    UTF-32 file with a BOM is decoded exactly and re-encoded as UTF-8. Anything
    else is decoded as cp1252, then latin-1 (which cannot fail), so names come
    out whole; line numbers are unchanged in every case. ``warn`` names the file
    once per process on that last, guessed path — pass ``warn=False`` from
    secondary passes that re-read a file the extractor already read.
    """
def _read_source_bytes(path: Path, *, warn: bool = True) -> bytes;

"""``_read_source_bytes`` as text, for extractors that work on ``str``.

    Matches ``path.read_text(encoding="utf-8")`` exactly for every valid UTF-8
    file, including its universal-newline translation (``\\r\\n`` and a lone
    ``\\r`` both become ``\\n``) and a kept BOM, so regex extractors see the same
    text they always did.
    """
def _read_source_text(path: Path, *, warn: bool = True) -> str;
