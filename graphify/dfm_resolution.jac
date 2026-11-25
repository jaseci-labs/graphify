"""Cross-file resolution linking a Delphi/Lazarus form to its unit.

A Delphi form is split across two files that the IDE keeps in lockstep: the
design-time form (``PMain.dfm``) and the unit that implements it
(``PMain.pas``). The form file names its class (``object PMainF: TPMainF``)
and binds events by method name (``OnClick = BtnOkClick``); the unit declares
that same class and implements those methods. Neither file references the
other by path -- the pairing is the compiler's, established by the
``{$R *.dfm}`` directive and the shared base name.

Each file is extracted independently (``extract_delphi_form`` /
``extract_lazarus_form`` for the form, ``extract_pascal`` for the unit), so
the form's class node and its event-handler nodes are stubs local to the form
file, disconnected from the real class and methods in the unit. Asking "the
user clicks this control -- where is the code?" therefore dead-ends at the
form file, which is precisely the question a form is usually opened to answer.

This resolver runs after all files are extracted (registered in
``graphify.resolver_registry``), pairs each form file with its sibling unit by
base name, and links:

- the form's class node to the unit's class of the same name, and
- every event-handler stub to that class's method of the same name.

Both links are the compiler's own binding rule, not a name-similarity guess:
Delphi resolves ``OnClick = BtnOkClick`` against the methods of the form class
declared in the paired unit, and nowhere else. The resolver follows the same
rule and stops where the rule stops -- no sibling unit in the corpus, no class
of that name in it, or more than one candidate for a name, and nothing is
emitted. Purely additive: existing nodes and edges are left untouched, so a
form whose unit was not scanned keeps exactly the graph it has today.
"""

import from __future__ { annotations }

glob _FORM_SUFFIX_UNITS: any = {".dfm": (".pas", ".pp"), ".lfm": (".pas", ".pp")};

"""Return the unit file(s) paired with *form_file*, as extracted paths.

    Works on the stored ``source_file`` string rather than ``pathlib`` so the
    result keeps whatever form the corpus uses (absolute or relative, either
    separator): only the extension is substituted.
    """
def _sibling_unit_files(form_file: str, known_files: set[str]) -> list[str];

"""Normalize a node label to a comparable method name.

    Both extractors render a routine as ``Name()``; Pascal is case-insensitive,
    so the comparison is lowercased.
    """
def _method_name(label: str) -> str;

"""Link Delphi/Lazarus form classes and event handlers to their unit.

    Emits, per form file whose sibling unit is in the corpus:

    - ``form class --references[form class]--> unit class``
    - ``handler stub --references[event impl]--> unit method``

    Each emission requires exactly one candidate (same god-node guard as
    ``resolve_pascal_inherited_calls``); an ambiguous name produces no edge
    rather than a guess.
    """
def resolve_dfm_handlers(
    per_file: list[dict], all_nodes: list[dict], all_edges: list[dict]
) -> None;
