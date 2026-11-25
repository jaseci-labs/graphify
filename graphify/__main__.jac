"""graphify CLI - `graphify install` sets up the Claude Code skill."""

import operator;

import from __future__ { annotations }

import contextlib;

import errno;

import functools;

import io;

import json;

import os;

import platform;

import re;

import shutil;

import subprocess;

import sys;

import from pathlib { Path }

glob __version__: any;

glob _pkg_version: any;

glob _ALWAYS_ON_ALIASES: any;

glob _KIRO_STEERING_MARKER: any;

glob _CODEX_HOOK: any;

glob _HASHSEED_PINNED_COMMANDS: any;

with entry {
    try {
        import from importlib.metadata { version as _pkg_version }

        __version__ = _pkg_version("graphifyy");
    } except Exception {
        __version__ = "unknown";
    }

    _ALWAYS_ON_ALIASES = {
        "_CLAUDE_MD_SECTION": "claude-md",
        "_AGENTS_MD_SECTION": "agents-md",
        "_GEMINI_MD_SECTION": "gemini-md",
        "_VSCODE_INSTRUCTIONS_SECTION": "vscode-instructions",
        "_ANTIGRAVITY_RULES": "antigravity-rules",
        "_KIRO_STEERING": "kiro-steering",
    };
}

def __getattr__(name: str) -> str;

"""Warn if the installed skill is from an older graphify version.

    ``platform_names`` are the platforms installing into this destination
    (resolved here when not given - the call site passes one positional
    argument only, because tests stub this function with one-arg lambdas), so
    the warning can name the exact command that refreshes THIS copy (#3144):
    a plain `graphify install` only refreshes the detected platform, and a
    stale marker at another platform's destination made the warning permanent
    - the user followed the advice, the warning stayed, and only editing the
    marker by hand cleared it.
    """
def _check_skill_version(skill_dst: Path, platform_names: "list[str] | None" = None) -> None;

"""Parse a version string into a comparable integer tuple (``0.9.2`` -> ``(0, 9, 2)``).

    Reads the leading digits of each dot-segment, so pre/post-release suffixes
    (``1.0.0rc1``) compare by their numeric core. A non-numeric or empty segment
    becomes 0, so a malformed stamp degrades to a conservative comparison rather
    than raising.
    """
def _version_tuple(version: str) -> tuple[int, ...];

"""Refresh user-scope skills left behind by a package upgrade (#1805).

    Upgrading the package (``uv tool upgrade graphifyy``, ``pip install -U``)
    does not touch the installed skill copies, and a plain ``graphify install``
    refreshes only the detected platform, so every other platform (codex,
    opencode, gemini, ...) kept running the old skill instructions until each
    was reinstalled by hand. On the first CLI run after an upgrade, re-copy
    every user-scope skill whose ``.graphify_version`` stamp is older than the
    running package - exactly the copies the stale-skill warning would tell the
    user to reinstall.

    Only copies graphify installed are touched (a stamp and SKILL.md exist);
    nothing is installed that was not there before. Left alone, so the
    warning still fires for them:

    * a stamp NEWER than the package - installing would downgrade it (#1568);
    * a directory written by more than one installer (gemini + agents on
      Windows, copilot + ``graphify vscode install``) - the stamp does not
      record which variant is there, and guessing would swap it.

    Directories are grouped by their resolved path, so two platforms sharing
    one directory through a symlink count as shared too.

    A locally edited SKILL.md is kept as ``SKILL.md.bak`` by _copy_skill_file
    (#3144). Output goes to stderr so piped stdout (``--json``, the MCP stdio
    server) stays clean. Set ``GRAPHIFY_NO_AUTO_REFRESH=1`` to opt out, e.g.
    for pinned or centrally managed skill directories.
    """
def _refresh_stale_skills -> None;

"""The version stamped beside ``skill_dst`` if it is older than the package."""
def _stale_stamp(skill_dst: Path) -> str | None;

"""Every platform with a user-scope skill directory, gemini included."""
def _skill_platforms -> list[str];

"""Re-copy one platform's skill and report it in one line on stderr."""
def _refresh_one_skill(name: str, skill_dst: Path, installed: str) -> None;

"""True when the ``opencode`` on PATH can load the plugin graphify writes now.

    That plugin is a default export, which OpenCode reads from 1.3.4 on. Older
    OpenCode 1 releases call every export as a function and fail on it, while
    the plugin they already have keeps working, so it must be left alone.
    Unknown (no ``opencode`` on PATH, no version in its output) counts as no:
    the refresh is a convenience, ``graphify opencode install`` still rewrites.
    """
def _opencode_loads_current_plugin -> bool;

"""Rewrite OpenCode plugins an older release left behind (#3554, #3732).

    Releases up to 0.9.74 wrote a plugin only OpenCode 1 can load, and an
    opencode.json entry OpenCode 2 fails on. Upgrading OpenCode to 2 turns both
    into a load error on every start, and upgrading graphify touches neither.
    So on a CLI run, replace such a plugin with the current one and drop the
    entry.

    Two directories are checked: the working directory, where the install
    writes the plugin, and the home directory, where it lands when the install
    was run from there (OpenCode then loads it for every project below home).
    Only a plugin graphify wrote is touched. The entry is dropped beside a
    current plugin too: a checkout or a failed write can bring it back alone.

    An old plugin is replaced only when the installed OpenCode can load the new
    one (see _opencode_loads_current_plugin), and under the directory's lock,
    without waiting: when another graphify process is already at it, this one
    leaves it to them. ``GRAPHIFY_NO_AUTO_REFRESH=1`` opts out, as it does for
    skills.
    """
def _refresh_v1_opencode_plugins -> None;

with entry {
    _KIRO_STEERING_MARKER = "graphify: A knowledge graph of this project";

    _CODEX_HOOK = {
        "hooks": {
            "PreToolUse": [
                {
                    "matcher": "Bash",
                    "hooks": [{"type": "command", "command": "graphify hook-check"}],
                },
            ],
        },
    };
}

"""Handle a downstream reader that closed the pipe early. Redirect stdout to
    devnull so the interpreter's shutdown flush does not raise a second time, then
    exit 0 — the reader (head, `Select-Object -First N`, `sed q`) has what it needs."""
def _silence_broken_pipe -> None;

with entry {
    _HASHSEED_PINNED_COMMANDS = frozenset({"update", "extract", "cluster-only", "label"});
}

"""Re-exec with PYTHONHASHSEED=0 for commands whose output must be
    deterministic run-to-run (#3641).

    PYTHONHASHSEED is read once at interpreter startup; setting it on
    os.environ from inside an already-running process has no effect on that
    process's own hash randomization, so pinning it requires restarting the
    interpreter with it set from the start. The generated git hooks already
    export it for exactly this reason: networkx's Louvain implementation
    iterates string-keyed sets whose order is randomized per-process, so
    community assignments otherwise churn between runs with no code change.
    A bare `graphify update .` (which the CLAUDE.md template tells agents to
    run after every code change) skipped this, re-clustering differently
    every time and producing a large, spurious graphify-out diff.

    Only re-execs for the commands whose output actually depends on
    clustering, and only when the caller has not already set
    PYTHONHASHSEED themselves — an explicit choice is left alone. Degrades
    instead of raising if the re-exec itself fails, since an unusual host
    that disallows it should still be able to run graphify, just without
    this determinism guarantee.

    Also does nothing under pytest: dozens of existing tests call main()
    directly with a monkeypatched sys.argv to simulate a full CLI run in
    process, an approach that only works because main() was previously
    side-effect-free at the point it starts. A real os.execvpe there would
    replace the test process running those tests, not something to launch
    for real -- PYTEST_CURRENT_TEST is set by pytest for exactly the
    duration of a running test's setup/call/teardown, so this only ever
    skips the pin inside an actual test, never a real invocation.
    """
def _pin_hash_seed_if_needed -> None;

"""Replace the current command with `argv` run under `env`.

    On POSIX this is a real os.execvpe. On Windows os.exec* does not replace
    the process: CPython spawns a new one and the calling process exits at
    once, so the caller sees the command "finish" while the work continues
    detached, and the exiting parent intermittently dies with an access
    violation (exit 139 / 0xC0000005) instead (#3799). There the child is
    run with subprocess and waited for, and its exit status is propagated.
    """
def _reexec(argv: list[str], env: dict[str, str], windows: bool | None = None) -> None;

"""Console entry point. Wraps the CLI so that when a downstream consumer closes
    stdout early, graphify treats it as success instead of crashing with an
    unhandled write-to-closed-pipe error and exit 255 — which made CI wrappers and
    agent harnesses read a successful query as a command failure (#1807)."""
def main -> None;

def _run_cli -> None;

with entry:__main__ {
    main();
}
