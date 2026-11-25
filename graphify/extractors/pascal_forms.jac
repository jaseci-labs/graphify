"""Pascal_forms extractor. Moved verbatim from graphify/extract.py."""

import from __future__ { annotations }

import from pathlib { Path }

import from typing { Any }

"""Extract component hierarchy from Lazarus .lfm form files.

    .lfm is a text-based declarative format for UI component trees, structured as:
        object ComponentName: TClassName
          PropertyName = Value
          OnEvent = HandlerName
          object ChildName: TChildClass
            ...
          end
        end

    Produces nodes for:
    - The form file itself
    - Each component class encountered (TForm1, TButton, TPanel, ...)
    - Event handler names referenced by OnXxx properties

    Produces edges for:
    - file --contains--> root form class
    - parent component --contains--> child component class
    - component --references--> event handler (context: "event")
    """
def extract_lazarus_form(path: Path) -> dict;

"""Extract component hierarchy from Delphi .dfm form files.

    .dfm files come in two formats:
    - Text (same `object Name: TClassName ... end` syntax as .lfm)
    - Binary (starts with a TPF0/FF0A magic header — unreadable as text)

    Binary .dfm files are skipped gracefully: an empty result is returned
    so the rest of the pipeline is unaffected.  Convert binary forms to
    text in the Delphi IDE via File → Save As (Text DFM) if you want them
    indexed.

    Text .dfm files are parsed identically to .lfm: component containment
    (`contains`) and event handler references (`references`, context "event").
    """
def extract_delphi_form(path: Path) -> dict;
