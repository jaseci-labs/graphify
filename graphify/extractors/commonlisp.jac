import from __future__ { annotations }
import warnings;

import from pathlib { Path }

glob _CL_DATA_DEFINERS: any;

glob _CL_VALUE_DEFINERS: any;

glob _CL_MACRO_DEFINERS: any;

glob _CL_NOT_DEFINERS: any;

glob _CL_SPECIAL_FORMS: any;

with entry {
    _CL_DATA_DEFINERS = frozenset({
        "defstruct",
        "deftype",
        "define-condition",
        "defvar",
        "defparameter",
        "defconstant",
        "define-symbol-macro",
    });
    _CL_VALUE_DEFINERS = frozenset({"defvar", "defparameter", "defconstant"});
    _CL_MACRO_DEFINERS = frozenset({
        "define-modify-macro",
        "define-compiler-macro",
        "define-setf-expander",
        "defsetf",
    });
    _CL_NOT_DEFINERS = frozenset({
        "default",
        "default-value",
        "defaults",
        "define",
        "defer",
        "deferred",
        "deflate",
        "deftest",
    });
    _CL_SPECIAL_FORMS = frozenset({
        "let",
        "let*",
        "flet",
        "labels",
        "macrolet",
        "if",
        "when",
        "unless",
        "cond",
        "case",
        "ecase",
        "typecase",
        "etypecase",
        "progn",
        "prog1",
        "prog2",
        "block",
        "return-from",
        "tagbody",
        "go",
        "lambda",
        "function",
        "funcall",
        "apply",
        "setf",
        "setq",
        "psetf",
        "psetq",
        "incf",
        "decf",
        "push",
        "pop",
        "loop",
        "do",
        "do*",
        "dolist",
        "dotimes",
        "map",
        "mapcar",
        "mapc",
        "format",
        "print",
        "princ",
        "prin1",
        "write",
        "terpri",
        "and",
        "or",
        "not",
        "null",
        "values",
        "multiple-value-bind",
        "multiple-value-setq",
        "declare",
        "the",
        "locally",
        "eval-when",
        "quote",
        "backquote",
        "error",
        "signal",
        "warn",
        "assert",
        "check-type",
        "handler-case",
        "handler-bind",
        "restart-case",
        "ignore-errors",
        "unwind-protect",
        "catch",
        "throw",
        "with-open-file",
        "with-output-to-string",
        "with-input-from-string",
        "with-slots",
        "with-accessors",
        "defvar",
        "defparameter",
        "defconstant",
        "in-package",
        "require",
        "provide",
        "use-package",
        "t",
        "nil",
    });
}

def extract_commonlisp(path: Path) -> dict;
