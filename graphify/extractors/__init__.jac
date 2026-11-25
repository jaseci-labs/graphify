"""Per-language extractors, incrementally migrated out of graphify/extract.py.

Dispatch still flows through graphify.extract (the facade re-exports every
moved name), so importing from graphify.extract keeps working unchanged.
LANGUAGE_EXTRACTORS is the registry seed; wiring dispatch through it is a
later, separate step. See MIGRATION.md for how to port another language.
"""

import from __future__ { annotations }

import from pathlib { Path }

import from typing { Callable }

glob LANGUAGE_EXTRACTORS: dict[str, Callable[[Path], dict]];

with entry {
    LANGUAGE_EXTRACTORS = {
        "apex": extract_apex,
        "bash": extract_bash,
        "blade": extract_blade,
        "cobol": extract_cobol,
        "commonlisp": extract_commonlisp,
        "dart": extract_dart,
        "delphi_form": extract_delphi_form,
        "dm": extract_dm,
        "dmf": extract_dmf,
        "dmi": extract_dmi,
        "dmm": extract_dmm,
        "elixir": extract_elixir,
        "erlang": extract_erlang,
        "fortran": extract_fortran,
        "go": extract_go,
        "json": extract_json,
        "julia": extract_julia,
        "lazarus_form": extract_lazarus_form,
        "markdown": extract_markdown,
        "objc": extract_objc,
        "pascal": extract_pascal,
        "powershell": extract_powershell,
        "powershell_manifest": extract_powershell_manifest,
        "r": extract_r,
        "razor": extract_razor,
        "rust": extract_rust,
        "sln": extract_sln,
        "solidity": extract_solidity,
        "sql": extract_sql,
        "terraform": extract_terraform,
        "verilog": extract_verilog,
        "vbnet": extract_vbnet,
        "zig": extract_zig,
    };
}
