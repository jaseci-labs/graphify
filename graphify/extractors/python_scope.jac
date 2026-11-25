"""Python parameter scoping shared by the AST extractor and the import resolver."""

import operator;

import from __future__ { annotations }

"""Plain parameter identifiers declared on a Python `parameters` node.

    Covers positional/keyword params plus `*args` / `**kwargs` and typed or
    default forms — anything that binds a local name the function body can shadow
    a module-level definition with.
    """
def _python_param_names(params_node, source: bytes) -> set[str];

"""Return ``is_shadowed(call, name)``: does *name* at *call* read a parameter
    of an enclosing function?

    Walks outward the way Python resolves a free name. A function's parameters
    are visible only from its body: a default, annotation or decorator is
    evaluated in the scope around it. A nested ``def``/``class``, an import or
    ``global`` in a nearer scope rebinds the name, so the walk stops there and
    the ordinary lookup decides. A class body is visible only to code directly
    in it, never to its methods.
    """
def _python_param_shadow_checker(source: bytes) -> any;
