"""graphify install/uninstall subsystem.

The per-platform skill/hook installers and uninstallers, extracted verbatim from
graphify/__main__.py so the CLI dispatcher (`main`) stays readable. Import path is
unchanged: `graphify.__main__` re-exports every name defined here, so
`from graphify.__main__ import claude_install` (etc.) keeps working.

Lives at graphify/install.py (same package dir as __main__) on purpose: the
installers resolve packaged assets via `Path(__file__).parent / "always_on"` and
`/ "skills"`, which only works from within the graphify/ directory.
"""

import operator;

import from jaclang.comptime { target as target_ }

import from __future__ { annotations }

import contextlib;

import errno;

import functools;

import hashlib;

import json;

import os;

import platform;

import re;

import shutil;

import stat;

import sys;

import tempfile;

import threading;

import time;

import from pathlib { Path }

import from typing { Any, NoReturn }

# This module's own copy, as a `from` import would bind it.
glob _GRAPHIFY_OUT: any = _PATHS_OUT;

comptime if target_().os == "windows" {
    glob fcntl: any;

    import msvcrt;
} else {
    glob msvcrt: any;

    import fcntl;
}

glob __version__: any;

glob _pkg_version: any;

glob _held_skill_locks: any;

glob _GRAPHIFY_HOOK_SUBCOMMANDS: any;

glob _GRAPHIFY_LEGACY_HOOK_MARKER: any;

glob _PLATFORM_CONFIG: dict[str, dict[str, Any]];

glob _PLATFORM_ALIASES: dict[str, str];

glob _BANNER_LOGO: any;

glob _CLAUDE_MD_MARKER: any;

glob _CODEBUDDY_MD_MARKER: any;

glob _AGENTS_MD_MARKER: any;

glob _GEMINI_MD_MARKER: any;

glob _SKILL_REGISTRATION_MARKER: any;

glob _VSCODE_INSTRUCTIONS_MARKER: any;

glob _ANTIGRAVITY_RULES_PATH: any;

glob _ANTIGRAVITY_WORKFLOW_PATH: any;

glob _ANTIGRAVITY_WORKFLOW: any;

glob _CURSOR_RULE_PATH: any;

glob _CURSOR_RULE: any;

glob _DEVIN_RULES_PATH: any;

glob _DEVIN_RULES: any;

glob _KILO_PLUGIN_JS: any;

glob _KILO_PLUGIN_PATH: any;

glob _KILO_CONFIG_JSON_PATH: any;

glob _KILO_CONFIG_JSONC_PATH: any;

glob _OPENCODE_PLUGIN_JS: any;

glob _OPENCODE_PLUGIN_PATH: any;

glob _OPENCODE_CONFIG_PATH: any;

glob _OPENCODE_PLUGIN_HEADER: any;

glob _CLAUDE_MD_FILES: any;

glob _CLAUDE_MD_BLOCKERS: any;

glob _CLAUDE_AGENTS_MD_FILES: any;

glob _CLI_INSTALL_COMMANDS: any;

with entry {
    comptime if target_().os == "windows" {
        fcntl = None;
    } else {
        msvcrt = None;
    }

    try {
        import from importlib.metadata { version as _pkg_version }

        __version__ = _pkg_version("graphifyy");
    } except Exception {
        __version__ = "unknown";
    }
}

"""The lock file for ``skill_dir``, kept out of the skill directory.

    Inside it, a project-scope install would leave the file in the user's
    repository, and uninstall would have to delete a file another process may
    still hold - letting that process and a new one both own the lock.
    """
def _skill_lock_path(skill_dir: Path) -> Path;

with entry {
    _held_skill_locks = threading.local();
}

"""Take the lock on ``fh`` without waiting; False if another process holds it.

    Raises OSError when the file system cannot lock at all (e.g. some network
    mounts).
    """
def _try_skill_lock(fh) -> bool;

def _release_skill_lock(fh) -> None;

"""Serialize every process that writes ``skill_dir``.

    Install, uninstall and the CLI's stale-skill refresh (#1805) all write the
    same files and stage through fixed ``SKILL.md.tmp`` / ``references.tmp``
    names, so two of them at once would write through each other - and an
    uninstall racing a refresh could see the refresh put the skill back.

    Yields True while this process holds the lock. With ``wait`` off (the
    refresh) it yields False instead of waiting when another process holds it.
    It yields None when locking is unavailable here (no writable cache
    directory, a file system that refuses to lock): install and uninstall then
    go ahead unlocked, as they did before the lock existed; the refresh skips.

    An OS lock (flock / msvcrt.locking): the OS releases it however the holder
    exits, so a crash or a kill never leaves the directory locked and there is
    no staleness timeout to guess. The lock file is never deleted.
    """
@contextlib.contextmanager
def _skill_lock(skill_dir: Path, *, `wait: bool = True) -> Generator[any, any, any];

"""Atomically write ``.graphify_version`` beside ``skill_dst``.

    Matches the SKILL.md install path: unique temp file in the same directory,
    then ``os.replace``. Unlike ``Path.write_text`` (and unlike
    ``paths.write_text_atomic``, which resolves through symlinks), ``os.replace``
    replaces a managed symlink in place — consistent with SKILL.md /
    ``references/`` and crash-safe against a half-written stamp (#3286).
    """
def _write_version_stamp(skill_dst: Path, version: str) -> None;

"""Read a packaged always-on instruction block from graphify/always_on/.

    The six always-on blocks (CLAUDE.md / AGENTS.md / GEMINI.md / VS Code
    Copilot instructions / Antigravity rules / Kiro steering) live as committed
    markdown next to this module, generated by tools/skillgen from a single
    human-edited fragment and guarded against drift by ``skillgen --check``. The
    installer injects them verbatim via ``_replace_or_append_section``, so the
    bytes here must match the former triple-quoted constant exactly — the
    always-on-roundtrip validator proves that.
    """
@functools.lru_cache(maxsize=None)
def _always_on(basename: str) -> str;

"""Return the skill destination for a platform and scope."""
def _platform_skill_destination(
    platform_name: str, *, project: bool = False, project_dir: Path | None = None
) -> Path;

"""Return the packaged references source dir for a progressive platform, else None.

    A platform opts into progressive disclosure by setting ``skill_refs`` in its
    ``_PLATFORM_CONFIG`` entry. The value names a bundle under
    ``graphify/skills/<bundle>/references/``. Reuse keys (e.g. trae-cn) point at
    their twin's bundle.

    ``gemini`` has no ``_PLATFORM_CONFIG`` entry: it installs claude's
    ``skill.md`` body verbatim (see ``_copy_skill_file``). Since that body is the
    lean progressive core that links to ``references/``, gemini needs claude's
    references/ sidecar too, or its SKILL.md ships with dead pointers. So gemini
    resolves to the claude bundle rather than opting out.

    Bundles ship one platform-group at a time. A host whose bundle directory
    ``graphify/skills/<bundle>/`` is not in this build has not gone progressive
    yet, so this returns None and the host installs today's monolithic SKILL.md
    with no references/ sidecar. Only when the bundle directory IS present does
    this return the references path; if that directory then lacks its
    ``references/`` subdir, ``_copy_skill_file`` hard-fails (a malformed bundle,
    the empty-sidecar regression the wheel-content test also guards).
    """
def _packaged_skill_refs_dir(platform_name: str) -> Path | None;

"""Atomically install a packaged references/ sidecar next to SKILL.md.

    Stages the packaged dir into a unique temporary directory (copytree), drops
    any stale ``references/`` already on disk, then ``os.replace``-renames the
    staged dir into place. The rename is atomic on the same filesystem, so an
    interrupted install never leaves a half-written references/ visible to the
    agent.
    """
def _install_skill_references(skill_dst: Path, refs_src: Path) -> None;

"""Copy a packaged skill file and write its version stamp.

    For progressive platforms (those with ``skill_refs`` set), the packaged
    ``references/`` sidecar is installed alongside SKILL.md and the single
    ``.graphify_version`` stamp covers both. For monolith platforms (no
    ``skill_refs``), any orphan ``references/`` left by a prior progressive
    install is removed so the on-disk layout matches the package.
    """
def _copy_skill_file(
    platform_name: str, *, project: bool = False, project_dir: Path | None = None
) -> Path;

"""Remove a platform skill file and its version stamp without touching other scopes."""
def _remove_skill_file(
    platform_name: str, *, project: bool = False, project_dir: Path | None = None
) -> bool;

"""Return the top-level project artifact for a project-scoped skill path."""
def _project_scope_root(path: Path, project_dir: Path) -> Path;

"""Whether a `# graphify` section is the registration graphify writes.

    Every version of the registration has had the bullet naming the graphify
    skill and the `/graphify` trigger, which a hand-written section has no
    reason to repeat.
    """
def _is_graphify_skill_registration(section: "list[str]") -> bool;

"""The body of each exact `# graphify` section, bounded as
    _remove_marker_section bounds it: up to the next H1."""
def _skill_registration_sections(content: str) -> "list[list[str]]";

"""Remove the skill registration _register_always_on_block wrote into *target*.

    *only_graphify_written* is for the user's global CLAUDE.md / CODEBUDDY.md,
    which every `graphify uninstall` visits, also for users who never installed
    the skill there. Only a `# graphify` section carrying graphify's
    registration bullet goes; a hand-written `# graphify` section stays, and a
    file holding both is left as is, with a hint, rather than guessed at.

    Degrades instead of raising, as the install side does (#3474): a CLAUDE.md
    that nix/home-manager links into a read-only store must not abort an
    uninstall halfway, with later platforms not yet cleaned.
    """
def _remove_skill_registration(
    target: Path, prefix: str, *, only_graphify_written: bool = False
) -> None;

"""Remove the project-scoped Claude skill registration file/section."""
def _remove_claude_skill_registration(project_dir: Path) -> None;

"""The CLAUDE.md a global (non-project) Claude install registers the skill in,
    and the skill path that registration names: the same choice install() makes.

    CLAUDE_CONFIG_DIR relocates both, as it does the skill copy (#527, #2694).
    """
def _claude_global_registration -> "tuple[Path, str]";

"""The CODEBUDDY.md `install --platform codebuddy` registers the skill in."""
def _codebuddy_global_registration -> Path;

def _print_project_git_add_hint(paths: list[Path]) -> None;

"""graphify's Claude/Codebuddy PreToolUse hooks, resolved at install time.

    The command invokes `graphify hook-guard <search|read>` via the absolute exe
    path (`_resolve_graphify_exe`) — or, for a project-scoped install, via the
    bare `graphify` command, since that config gets committed (#3129). Either
    form parses under sh, cmd.exe and PowerShell alike — this is the #522 fix,
    and mirrors the codex hook. Matchers are
    "Bash|Grep" and "Read|Glob" and the command always contains "graphify", so the
    existing install/uninstall filters find and replace both old bash hooks and
    these. "Grep" is in the search matcher because current Claude Code routes
    content search through its dedicated Grep tool, not Bash (#1986) — a
    Bash-only matcher never fired on the agent's primary search path.

    When ``strict`` is set, both hooks carry ``--strict`` so Read and dedicated
    Grep share one block per session; Bash and Glob remain advisory. The
    ``GRAPHIFY_HOOK_STRICT`` env var can force it on or off without a reinstall.

    Each entry carries a ``timeout`` (#3314): unset, Claude Code defaults a
    command hook to 600s, so a single wedged guard (a stuck filesystem, a
    hung subprocess) stalls the surrounding tool call for ten minutes on
    every Bash/Grep/Read/Glob call -- the four highest-frequency tools an
    agent uses. The guard itself measures ~170ms warm; 10s is generous
    headroom over that while still two orders of magnitude below the
    unset default.
    """
def _claude_pretooluse_hooks(strict: bool = False, project: bool = False) -> "list[dict]";

"""graphify's Claude Code SessionStart hook: matcher "compact" only.

    Claude Code fires SessionStart with source "compact" after an auto or manual
    compaction, keeping the session id. The model has lost the earlier nudges by
    then, but their per-session budget is spent, so `hook-guard compact` resets
    it (and the strict-mode deny marker) and restates the graph in one line.
    Same command form and timeout as _claude_pretooluse_hooks; the command
    carries "hook-guard", so the install/uninstall filters recognise it.
    """
def _claude_sessionstart_hooks(project: bool = False) -> "list[dict]";

with entry {
    _GRAPHIFY_HOOK_SUBCOMMANDS = ("hook-guard", "hook-check");
    _GRAPHIFY_LEGACY_HOOK_MARKER = "graphify-out/";
}

"""True when a hook ``command`` string is one graphify installed.

    Matches graphify's own guard/check subcommands (current installs) or the
    ``graphify-out/`` path its pre-#522 inline bash guard gated on (legacy
    installs). Deliberately command-scoped: the old ``"graphify" in str(group)``
    match also caught an unrelated group whose command path merely contained the
    word "graphify" (#4359).
    """
def _is_graphify_hook_command(command: str) -> bool;

"""True when a single ``hooks[]`` element is a graphify command entry.

    Non-dict and non-command entries are never graphify's (the old uninstall
    filter called ``.get`` on every entry and raised ``AttributeError`` on a
    plain string, #4359).
    """
def _is_graphify_hook_entry(`entry: object) -> bool;

"""Drop graphify's own hook entries from *groups*, keeping everything else.

    Only the individual entries graphify installed are removed, so a user
    command sharing graphify's group survives and a group is dropped only once
    removal leaves it with no hooks. Non-dict groups and non-list ``hooks`` are
    passed through untouched, and a group without a graphify entry is never
    rewritten. This replaces the old group-level ``"graphify" in str(group)``
    filter, which removed whole groups (and other tools' commands in them) and
    any unrelated group whose command path happened to contain the word (#4359).
    """
def _strip_graphify_hooks(groups: "list") -> "list";

def _skill_registration(skill_path: str = "~/.claude/skills/graphify/SKILL.md") -> str;

"""Name *path* for install/uninstall output, plus the file it points to when it
    is a symlink. Writing through a symlinked CLAUDE.md edits the target, so
    printing only the link hid which file was changed (#3805)."""
def _shown_path(path: Path) -> str;

"""Idempotently add or refresh an always-on registration in *target*, degrading
    instead of raising.

    Uses _replace_or_append_section (the same marker-anchored helper claude_install
    and gemini_install already use, here with the H1 boundary_prefix so it stays
    paired with _remove_claude_skill_registration's own H1 match) rather than a
    bare append, so a stale or edited block gets refreshed on re-install instead
    of the bare "graphify" substring check silently treating any unrelated
    mention of the word as already-registered and skipping every re-run (#3668).

    Written through the shared _read_keep_newline/_write_keep_newline pair, so an
    existing file's own line endings survive the read-modify-write: a plain
    read_text/write_text round-trip turns a bare-LF file into CRLF on Windows (and
    a CRLF file into LF elsewhere) just to append a few lines (#3668/#4360).

    The skill files are copied before this runs, so a *target* that cannot be
    read or written must not abort an otherwise-complete install (#3474). That
    happens whenever the dotfile is managed declaratively -- nix/home-manager
    symlinks ``~/.claude/CLAUDE.md`` into a read-only /nix/store, and chezmoi or
    stow with read-only sources leave the same shape.
    """
def _register_always_on_block(target: Path, prefix: str, registration: str) -> None;

with entry {
    _PLATFORM_CONFIG = {
        "claude": {
            "skill_file": "skill.md",
            "skill_dst": Path(".claude") / "skills" / "graphify" / "SKILL.md",
            "claude_md": True,
            "skill_refs": "claude",
        },
        "codex": {
            "skill_file": "skill-codex.md",
            "skill_dst": Path(".codex") / "skills" / "graphify" / "SKILL.md",
            "claude_md": False,
            "skill_refs": "codex",
        },
        "opencode": {
            "skill_file": "skill-opencode.md",
            "skill_dst": Path(".config") / "opencode" / "skills" / "graphify" / "SKILL.md",
            "claude_md": False,
            "skill_refs": "opencode",
        },
        "kilo": {
            "skill_file": "skill-kilo.md",
            "skill_dst": Path(".config") / "kilo" / "skills" / "graphify" / "SKILL.md",
            "claude_md": False,
            "skill_refs": "kilo",
        },
        "aider": {
            "skill_file": "skill-aider.md",
            "skill_dst": Path(".aider") / "graphify" / "SKILL.md",
            "claude_md": False,
        },
        "copilot": {
            "skill_file": "skill-copilot.md",
            "skill_dst": Path(".copilot") / "skills" / "graphify" / "SKILL.md",
            "claude_md": False,
            "skill_refs": "copilot",
        },
        "claw": {
            "skill_file": "skill-claw.md",
            "skill_dst": Path(".openclaw") / "skills" / "graphify" / "SKILL.md",
            "claude_md": False,
            "skill_refs": "claw",
        },
        "droid": {
            "skill_file": "skill-droid.md",
            "skill_dst": Path(".factory") / "skills" / "graphify" / "SKILL.md",
            "claude_md": False,
            "skill_refs": "droid",
        },
        "trae": {
            "skill_file": "skill-trae.md",
            "skill_dst": Path(".trae") / "skills" / "graphify" / "SKILL.md",
            "claude_md": False,
            "skill_refs": "trae",
        },
        "trae-cn": {
            "skill_file": "skill-trae.md",
            "skill_dst": Path(".trae-cn") / "skills" / "graphify" / "SKILL.md",
            "claude_md": False,
            "skill_refs": "trae",
        },
        "hermes": {
            "skill_file": "skill-claw.md",
            "skill_dst": Path(".hermes") / "skills" / "graphify" / "SKILL.md",
            "claude_md": False,
            "skill_refs": "claw",
        },
        "kiro": {
            "skill_file": "skill-kiro.md",
            "skill_dst": Path(".kiro") / "skills" / "graphify" / "SKILL.md",
            "claude_md": False,
            "skill_refs": "kiro",
        },
        "pi": {
            "skill_file": "skill-pi.md",
            "skill_dst": Path(".pi") / "agent" / "skills" / "graphify" / "SKILL.md",
            "claude_md": False,
            "skill_refs": "pi",
        },
        "codebuddy": {
            "skill_file": "skill.md",
            "skill_dst": Path(".codebuddy") / "skills" / "graphify" / "SKILL.md",
            "claude_md": False,
            "skill_refs": "claude",
        },
        "antigravity": {
            "skill_file": "skill.md",
            "skill_dst": Path(".agents") / "skills" / "graphify" / "SKILL.md",
            "claude_md": False,
            "skill_refs": "claude",
        },
        "antigravity-windows": {
            "skill_file": "skill-windows.md",
            "skill_dst": Path(".agents") / "skills" / "graphify" / "SKILL.md",
            "claude_md": False,
            "skill_refs": "windows",
        },
        "windows": {
            "skill_file": "skill-windows.md",
            "skill_dst": Path(".claude") / "skills" / "graphify" / "SKILL.md",
            "claude_md": True,
            "skill_refs": "windows",
        },
        "kimi": {
            "skill_file": "skill.md",
            "skill_dst": Path(".kimi") / "skills" / "graphify" / "SKILL.md",
            "claude_md": False,
            "skill_refs": "claude",
        },
        "amp": {
            "skill_file": "skill-amp.md",
            "skill_dst": Path(".agents") / "skills" / "graphify" / "SKILL.md",
            "claude_md": False,
            "skill_refs": "amp",
        },
        "agents": {
            "skill_file": "skill-agents.md",
            "skill_dst": Path(".agents") / "skills" / "graphify" / "SKILL.md",
            "claude_md": False,
            "skill_refs": "agents",
        },
        "devin": {
            "skill_file": "skill-devin.md",
            "skill_dst": Path(".config") / "devin" / "skills" / "graphify" / "SKILL.md",
            "claude_md": False,
        },
    };
    _PLATFORM_ALIASES = {"skills": "agents"};
}

"""Resolve a CLI platform alias to its real _PLATFORM_CONFIG key."""
def _canonical_platform(platform_name: str) -> str;

"""Idempotently update or append a graphify-owned section in shared files.

    If no line is exactly ``marker`` (the heading, at column 0), append
    ``new_section`` to the end (with a blank-line separator if there's existing
    content).

    If a real ``marker`` heading exists, replace the existing section in place.
    The section runs from that heading to the line before the next
    ``boundary_prefix`` heading (default the next H2), or to EOF if none
    follows. This lets older installs receive the updated copy without users
    having to uninstall and reinstall (issue #580).

    ``boundary_prefix`` must match whatever level ``marker`` itself is (``"# "``
    for an H1 marker, the default ``"## "`` for an H2 one) — mirrors
    ``_remove_marker_section``'s own ``boundary_prefix`` so an insert and its
    matching removal agree on where a section ends (#3668).

    The heading is matched only when a line *is* exactly ``marker`` (after
    stripping surrounding whitespace), never as a substring. Matching ``##
    graphify`` inside a bullet or an inline reference used to anchor the replace
    on that mention and delete every line from there to the next heading,
    silently destroying hand-curated content (#1688). When several exact
    headings exist, the last one is used, since graphify's section is appended.
    """
def _replace_or_append_section(
    content: str, marker: str, new_section: str, boundary_prefix: str = "## "
) -> str;

"""Remove every section whose heading line is exactly ``marker``.

    The heading is matched only when a line *is* exactly ``marker`` (after
    stripping surrounding whitespace), never as a substring. The old uninstall
    regex ``## graphify`` was unanchored, so it matched inside a user's
    ``### graphify`` heading and deleted hand-written content (#2062) — the same
    class of bug the install side hardened against in #1688. Each section runs to
    the line before the next ``boundary_prefix`` heading (default the next H2) or
    EOF, mirroring ``_replace_or_append_section``. All exact-heading sections are
    removed (pre-#1688 installs could leave duplicates).

    Returns None when no exact ``marker`` line exists — the caller must then leave
    the file untouched. This doubles as the guard: a substring mention (a bullet,
    an inline reference, a deeper ``###`` heading) never triggers a strip.
    """
def _remove_marker_section(content: str, marker: str, boundary_prefix: str = "## ") -> "str | None";

"""Read *path* as UTF-8 and return ``(text, newline)``.

    ``text`` uses bare ``
`` internally, so the section helpers
    (``_replace_or_append_section`` / ``_remove_marker_section``) work on it
    unchanged, and ``newline`` is the file's own dominant line ending (``"
"``
    or ``"
"``) so a later write can put it back.

    ``Path.read_text`` opens in universal-newline mode and folds every ``
``
    to ``
``, so the file's convention is lost before the write side ever sees
    it; a plain ``write_text`` then re-emits the platform default and rewrites
    the WHOLE file's endings, turning an LF file into CRLF on Windows (or a CRLF
    file into LF on Linux) just to merge in a few lines (#4360). Reading the bytes
    and normalising here keeps the original ending to restore.
    """
def _read_keep_newline(path: Path) -> "tuple[str, str]";

"""Write bare-``
`` *text* using *newline* endings, without translation.

    ``newline=""`` stops ``write_text`` from translating on the way out; the one
    conversion from bare ``
`` to the file's own ending happens here, so every
    install/uninstall writer shares a single line-ending contract (#4360). A file
    with no prior convention (a fresh install) is written with plain LF, matching
    what the other install writers already emit.
    """
def _write_keep_newline(path: Path, text: str, newline: str = "\n") -> None;

with entry {
    _BANNER_LOGO = "     ▄▄▀█▀▄▄\n ▄▄▀▀  ▄█▄  ▀▀▄▄\n██▀▀▀▀▀███▀▀▀▀▀▀▀    ▄█████▄                           ██       ██  ▄████\n█ ▀▄  ▄▀            ██▀   ▀▀▀ ██▄███  ██████▄ ██▄████▄ ██▄████▄ ▄▄ █████  ██    ██\n█   ███    ███▀▀█   ██  █████ ██▀     ▄▄▄▄▄██ ██▀  ▀██ ██▀  ▀██ ██  ██    ▀██  ██▀\n█   ▀▀█▄   ▀▀▀▄ █   ██▄   ▄██ ██     ██▀▀▀▀██ ██▄  ▄██ ██    ██ ██  ██     ▀█▄▄█▀\n█      ███     ▀█    ▀████▀██ ██     ▀██████▀ ██▀████▀ ██    ██ ██  ██      ▀██▀\n▀██▀▀▀▀▀█▀▀▀▀▀██▀                             ██                           ▄██\n   ▀▀▄▄ █ ▄▄▀▀                                ██                          ██▀\n       ▀▀▀";
}

"""Green graphify logo banner on graphify install. TTY-only, never raises."""
def _print_banner -> None;

def install(
    platform: str = "claude", *, project: bool = False, project_dir: Path | None = None
) -> None;

def _print_install_usage -> None;

with entry {
    _CLAUDE_MD_MARKER = "## graphify";
    _CODEBUDDY_MD_MARKER = "## graphify";
    _AGENTS_MD_MARKER = "## graphify";
    _GEMINI_MD_MARKER = "## graphify";
    _SKILL_REGISTRATION_MARKER = "# graphify";
}

"""Gemini CLI BeforeTool hook, resolved to a shell-agnostic `graphify` call.

    A project-scoped install emits the bare command, since .gemini/settings.json
    is then committed and an installing machine's path is wrong there (#3129).
    """
def _gemini_hook(project: bool = False) -> dict;

"""Gemini CLI prefers ~/.agents/skills over ~/.gemini/skills for a skill of
    the same name. Before #2800 a Windows gemini install wrote there, so an old
    copy can hide the one just installed. It may belong to the `agents`
    platform, so point at it rather than delete it."""
def _warn_shadowing_agents_skill -> None;

"""Copy skill file, write GEMINI.md section, and install BeforeTool hook."""
def gemini_install(project_dir: Path | None = None, *, project: bool = False) -> None;

"""Abort a hook install rather than clobber a config file we can't parse (#2167)."""
def _refuse_to_modify(settings_path: Path) -> "NoReturn";

"""Load an existing settings/hooks JSON file for a read-modify-write merge.

    A missing file yields a fresh ``{}`` (first install). An existing file that
    cannot be parsed as a JSON object aborts via ``_refuse_to_modify`` instead of
    silently falling back to ``{}`` — the old fallback rewrote the whole file and
    destroyed every setting the user had (#2167). Reads with ``utf-8-sig`` so a
    UTF-8 BOM (the most likely parse-error trigger, same class as #2163) is
    tolerated rather than fatal.
    """
def _read_settings_for_merge(settings_path: Path) -> dict;

"""Serialize ``settings`` to ``settings_path``, backing up the previous file.

    Skips the write entirely when the output is identical to what is on disk
    (idempotent re-install: no backup churn, no mtime churn). Otherwise copies
    the existing file to ``<name>.graphify-bak`` (single rolling backup) before
    overwriting, so one bad merge can never destroy the user's config (#2167).
    """
def _write_settings_with_backup(settings_path: Path, settings: dict) -> None;

def _install_gemini_hook(project_dir: Path, project: bool = False) -> None;

def _uninstall_gemini_hook(project_dir: Path) -> None;

"""Remove the graphify section from GEMINI.md, uninstall hook, and remove skill file.

    Scope rules (#2215): a bare call removes the user-global skill; passing
    ``project_dir`` (or ``project=True``) scopes skill removal to that project
    and leaves the global tree untouched, unless ``remove_user_skill=True``
    explicitly opts back into the global delete (as ``uninstall_all`` does).
    """
def gemini_uninstall(
    project_dir: Path | None = None, *, project: bool = False, remove_user_skill: bool | None = None
) -> None;

with entry {
    _VSCODE_INSTRUCTIONS_MARKER = "## graphify";
}

"""Skill path written by ``graphify vscode install``.

    The same directory as the ``copilot`` platform's user-scope skill, but with
    the VS Code variant of SKILL.md, so the version stamp there cannot tell which
    of the two is installed.
    """
def _vscode_skill_destination -> Path;

"""Install graphify skill for VS Code Copilot Chat + write .github/copilot-instructions.md."""
def vscode_install(project_dir: Path | None = None) -> None;

"""Remove graphify VS Code Copilot Chat skill and .github/copilot-instructions.md section."""
def vscode_uninstall(project_dir: Path | None = None) -> None;

with entry {
    _ANTIGRAVITY_RULES_PATH = Path(".agents") / "rules" / "graphify.md";
    _ANTIGRAVITY_WORKFLOW_PATH = Path(".agents") / "workflows" / "graphify.md";
    _ANTIGRAVITY_WORKFLOW = "---\nname: graphify\ndescription: Turn any folder of files into a navigable knowledge graph\n---\n\n# Workflow: graphify\n\nFollow the graphify skill to run the full pipeline.\n\nIf no path argument is given, use `.` (current directory).\n";
}

"""Write graphify skill + steering file for Kiro IDE/CLI."""
def _kiro_install(project_dir: Path) -> None;

"""Remove graphify skill + steering file for Kiro."""
def _kiro_uninstall(project_dir: Path) -> None;

"""Write Antigravity's always-on layer next to an installed skill.

    Injects the native tool-discovery YAML frontmatter into *skill_dst*, then
    writes ``.agents/rules/graphify.md`` and ``.agents/workflows/graphify.md``
    under *project_dir*. Shared by the global ``antigravity install`` and the
    project-scoped ``install --project --platform antigravity`` paths, so both lay
    down the rules/workflows that the uninstall path already expects to remove.
    """
def _antigravity_finalize(skill_dst: Path, project_dir: Path) -> None;

"""Install graphify for Google Antigravity (global skill + .agents/rules + .agents/workflows)."""
def _antigravity_install(project_dir: Path) -> None;

"""Remove graphify Antigravity rules, workflow, and skill files."""
def _antigravity_uninstall(project_dir: Path, *, project: bool = False) -> None;

with entry {
    _CURSOR_RULE_PATH = Path(".cursor") / "rules" / "graphify.mdc";
    _CURSOR_RULE = "---\ndescription: graphify knowledge graph context\nalwaysApply: true\n---\n\nThis project has a graphify knowledge graph at graphify-out/.\n\n**MANDATORY: Before using Read, Grep, Glob, or Bash to explore the codebase, you MUST run graphify first:**\n- `graphify query \"<question>\"` — scoped subgraph for any codebase or architecture question\n- `graphify path \"<A>\" \"<B>\"` — dependency path between two symbols\n- `graphify explain \"<concept>\"` — all nodes related to a concept\n\nThis applies to YOU and to every subagent you spawn. Include this rule explicitly in every subagent prompt that involves code exploration. Do not skip graphify because files are \"already known\" or because you are executing a plan — the graph surfaces cross-file dependencies and INFERRED edges that grep and Read cannot find.\n\nOnly use Read/Grep/Glob directly when:\n1. graphify has already oriented you and you need to modify or debug specific lines\n2. `graphify-out/graph.json` does not exist yet\n\n- If `graphify-out/wiki/index.md` exists, navigate it instead of reading raw files\n- Read `graphify-out/GRAPH_REPORT.md` only for broad architecture review when query/path/explain do not surface enough context\n- After modifying code files, run `graphify update .` to keep the graph current (AST-only, no API cost)\n";
}

"""Write .cursor/rules/graphify.mdc with alwaysApply: true."""
def _cursor_install(project_dir: Path) -> None;

"""Remove .cursor/rules/graphify.mdc."""
def _cursor_uninstall(project_dir: Path) -> None;

with entry {
    _DEVIN_RULES_PATH = Path(".windsurf") / "rules" / "graphify.md";
    _DEVIN_RULES = "## graphify\n\nThis project has a graphify knowledge graph at graphify-out/.\n\nRules:\n- For codebase or architecture questions, when `graphify-out/graph.json` exists, first run `graphify query \"<question>\"` (or `graphify path \"<A>\" \"<B>\"` / `graphify explain \"<concept>\"`). These return a scoped subgraph, usually much smaller than `GRAPH_REPORT.md` or raw grep output.\n- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files\n- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context\n- After modifying code files in this session, run `graphify update .` to keep the graph current (AST-only, no API cost)\n";
}

"""Write .windsurf/rules/graphify.md for always-on Devin context."""
def _devin_rules_install(project_dir: Path) -> None;

"""Remove .windsurf/rules/graphify.md."""
def _devin_rules_uninstall(project_dir: Path) -> None;

with entry {
    _KILO_PLUGIN_JS = "// graphify Kilo plugin\n// Injects a knowledge graph reminder before bash tool calls when the graph exists.\nimport { existsSync } from \"fs\";\nimport { join } from \"path\";\n\nexport const GraphifyPlugin = async ({ directory }) => {\n  let reminded = false;\n\n  return {\n    \"tool.execute.before\": async (input, output) => {\n      if (reminded) return;\n      if (!existsSync(join(directory, \"graphify-out\", \"graph.json\"))) return;\n\n      if (input.tool === \"bash\") {\n        // Separate with ';' not '&&' — Windows PowerShell 5.1 rejects '&&' as a\n        // statement separator (\"not a valid statement separator\"), which broke\n        // the first bash command in every OpenCode session on Windows (#1646).\n        // ';' works in PowerShell 5.1, Bash, and POSIX shells alike.\n        output.args.command =\n          'echo \"[graphify] Knowledge graph available. Read graphify-out/GRAPH_REPORT.md for god nodes and architecture context before searching files.\" ; ' +\n          output.args.command;\n        reminded = true;\n      }\n    },\n  };\n};\n";
    _KILO_PLUGIN_PATH = Path(".kilo") / "plugins" / "graphify.js";
    _KILO_CONFIG_JSON_PATH = Path(".kilo") / "kilo.json";
    _KILO_CONFIG_JSONC_PATH = Path(".kilo") / "kilo.jsonc";
}

"""Remove JSONC-style comments while leaving string content intact."""
def _strip_json_comments(raw: str) -> str;

def _load_json_like(config_file: Path) -> dict;

"""JSON/JSONC counterpart of ``_read_settings_for_merge`` (#2167).

    A missing file yields ``{}``. An existing file that does not parse as a JSON
    object aborts via ``_refuse_to_modify`` instead of falling back to ``{}`` -
    that fallback made the installer rewrite the user's config with only
    graphify's entry. Reads with ``utf-8-sig`` so a UTF-8 BOM is tolerated.
    """
def _read_json_like_for_merge(config_file: Path) -> dict;

def _kilo_config_path(project_dir: Path) -> Path;

"""Write automated Kilo edits to kilo.json so existing JSONC stays untouched."""
def _kilo_config_write_path(project_dir: Path) -> Path;

"""Write graphify.js plugin and register it without rewriting user JSONC."""
def _install_kilo_plugin(project_dir: Path) -> None;

"""Remove graphify.js plugin and deregister it without rewriting user JSONC."""
def _uninstall_kilo_plugin(project_dir: Path) -> None;

with entry {
    _OPENCODE_PLUGIN_JS = "// graphify OpenCode plugin\n// Injects a knowledge graph reminder before the first shell command of a\n// session when the graph exists.\n//\n// One file for both runtimes. OpenCode 2 reads `id` and `setup()` from the\n// default export; OpenCode 1 (1.3.4 and later) reads `server()` from it. Each\n// ignores the other's function. Nothing is imported from an opencode package:\n// a plain file in .opencode/plugins/ cannot resolve one.\n//\n// IMPORTANT: keep the reminder string free of backticks and $(...) constructs.\n// The hook prepends `echo \"<reminder>\" ; <cmd>` to the user's shell command;\n// backticks inside the double-quoted echo trigger command substitution,\n// which both corrupts tool output and silently executes the very graphify\n// command we are only suggesting. Plain words render fine in opencode's TUI.\nimport { existsSync } from \"fs\";\nimport { join } from \"path\";\n\n// ';' not '&&' — Windows PowerShell 5.1 rejects '&&' as a statement\n// separator, breaking the first shell command of the session (#1646).\nconst REMINDER =\n  'echo \"[graphify] knowledge graph at graphify-out/. For focused questions, run graphify query with your question (scoped subgraph, usually much smaller than GRAPH_REPORT.md) instead of grepping raw files. Read GRAPH_REPORT.md only for broad architecture context.\" ; ';\n\nconst hasGraph = (directory) => existsSync(join(directory, \"graphify-out\", \"graph.json\"));\n\n// A project and a directory above it (often ~) can each hold a copy of this\n// file, and OpenCode loads both. OpenCode 2 fails the second plugin with the\n// same id (\"Duplicate plugin ID\"), so the id carries this file's location. The\n// copies share one record of who was reminded, so a command gets one reminder.\nconst location = [...import.meta.url].reduce((hash, ch) => (Math.imul(hash, 31) + ch.charCodeAt(0)) >>> 0, 7);\nconst reminded = (globalThis.__graphifyReminded ??= new Set());\n\nexport default {\n  id: `graphify-${location.toString(16)}`,\n\n  // OpenCode 2: the command tool is \"shell\", and one server outlives many\n  // sessions, so the reminder is tracked per session.\n  async setup(ctx) {\n    await ctx.tool.hook(\"execute.before\", (event) => {\n      if (event.tool !== \"shell\" || typeof event.input?.command !== \"string\") return;\n      if (reminded.has(event.sessionID)) return;\n      if (!hasGraph(ctx.location.directory)) return;\n\n      event.input = { ...event.input, command: REMINDER + event.input.command };\n      reminded.add(event.sessionID);\n    });\n  },\n\n  // OpenCode 1: the command tool is \"bash\", and the server lives as long as\n  // the session, so the reminder is tracked per project directory.\n  async server({ directory }) {\n    return {\n      \"tool.execute.before\": async (input, output) => {\n        if (input.tool !== \"bash\" || typeof output.args?.command !== \"string\") return;\n        if (reminded.has(directory)) return;\n        if (!hasGraph(directory)) return;\n\n        output.args.command = REMINDER + output.args.command;\n        reminded.add(directory);\n      },\n    };\n  },\n};\n";
    _OPENCODE_PLUGIN_PATH = Path(".opencode") / "plugins" / "graphify.js";
    _OPENCODE_CONFIG_PATH = Path(".opencode") / "opencode.json";
}

"""OpenCode's config dir: <project>/.opencode, or ~/.config/opencode globally.

    OpenCode loads plugins from <dir>/plugins/ in both. The global dir has no
    .opencode/ segment, so it cannot be built by joining _OPENCODE_PLUGIN_PATH
    onto a base the way the project one is (#3398).
    """
def _opencode_dir(*, project: bool, project_dir: Path | None = None) -> Path;

with entry {
    _OPENCODE_PLUGIN_HEADER = "// graphify OpenCode plugin";
}

"""True for a graphify plugin written before the OpenCode 2 entrypoint.

    Releases up to 0.9.74 exported a named ``GraphifyPlugin`` function and
    nothing else. OpenCode 2 needs a default export, so it rejects the file
    with "Plugin must export a default definition" (#3554, #3732).
    """
def _opencode_plugin_is_v1_only(body: str) -> bool;

"""True when opencode.json still mentions the bare plugin path."""
def _opencode_config_names_plugin(opencode_dir: Path) -> bool;

"""Remove the plugin entry older releases wrote into opencode.json.

    The entry was the bare path ``.opencode/plugins/graphify.js``. OpenCode
    loads every file in ``.opencode/plugins/`` on its own, so the entry was
    never needed, and OpenCode 2 reads a bare path as an npm package name and
    fails to install it (#3732). Returns True when the config changed.
    """
def _drop_opencode_config_entry(opencode_dir: Path) -> bool;

"""Write graphify.js into <opencode_dir>/plugins/, where OpenCode discovers it.

    ``opencode_dir`` comes from _opencode_dir. Both files are replaced
    atomically. The CLI refresh can run this while OpenCode is watching them,
    and it must never see half a plugin.
    """
def _install_opencode_plugin(opencode_dir: Path) -> None;

"""Remove graphify.js plugin and deregister from opencode.json."""
def _uninstall_opencode_plugin(opencode_dir: Path) -> None;

"""Return the absolute path to the graphify executable, with forward slashes.

    With *project* set, return the bare ``graphify`` command instead. A
    project-scoped install writes hook config the installer then tells the user
    to commit, so an absolute path resolved from the installing machine is wrong
    for every other clone: it names a directory that does not exist there, and
    the drive letter and ``.EXE`` casing do not even survive between two Windows
    checkouts. A committed hook refers to ``graphify`` the way it would refer to
    ``git`` or ``node``, and PATH resolves it per machine (#3129).

    Falls back to bare 'graphify' if resolution fails. Using an absolute path
    ensures the hook works in environments where the venv Scripts/ directory is
    not on PATH (e.g. VS Code Codex extension on Windows).

    The path is normalized to forward slashes so it survives every shell that
    runs the hook command. On Windows, Claude Code runs command-type hooks
    through Git Bash by default, where an unquoted backslash is an escape
    character: a raw ``C:\\Users\\me\\graphify.EXE`` collapses to
    ``C:Usersmegraphify.EXE: command not found`` and the guard silently fails.
    Forward slashes are accepted by Git Bash, cmd.exe, and PowerShell alike, and
    ``.replace`` is a no-op on POSIX where paths already use forward slashes.
    """
def _resolve_graphify_exe(project: bool = False) -> str;

"""Add graphify PreToolUse hook to .codex/hooks.json.

    A project-scoped install emits the bare command, since .codex/hooks.json is
    then committed and an installing machine's path is wrong there (#3129).
    """
def _install_codex_hook(project_dir: Path, project: bool = False) -> None;

"""Remove graphify PreToolUse hook from .codex/hooks.json."""
def _uninstall_codex_hook(project_dir: Path) -> None;

"""Write the graphify section to the local AGENTS.md for always-on platforms."""
def _agents_install(project_dir: Path, platform: str, project: bool = False) -> None;

"""Best-effort removal of the pre-fix ~/.amp/skills/graphify install dir.

    Older graphify versions wrote the Amp skill to ~/.amp/skills, which Amp does
    not search. Clean it up on install so a stale, never-loaded copy does not
    linger. Failures are ignored (the new path is what matters).
    """
def _amp_legacy_cleanup -> None;

"""User-scope Amp install: skill into ~/.config/agents/skills + AGENTS.md."""
def _amp_install(project_dir: Path | None = None) -> None;

"""User-scope Amp uninstall: remove the skill and the AGENTS.md section."""
def _amp_uninstall(project_dir: Path | None = None) -> None;

"""`graphify agents install`: skill into ~/.agents/skills + AGENTS.md.

    The amp-twin of the generic Agent-Skills target. Mirrors _amp_install but
    lands the skill at the spec's user-global ~/.agents/skills (set in
    _platform_skill_destination). Wiring AGENTS.md keeps it honest with the
    rendered hooks reference, which points at `graphify agents install`. The bare
    `graphify install --platform agents` path stays skill-only (via install()),
    exactly as amp's `--platform amp` does.
    """
def _agents_platform_install(project_dir: Path | None = None) -> None;

"""`graphify agents uninstall`: remove the skill and the AGENTS.md section."""
def _agents_platform_uninstall(project_dir: Path | None = None) -> None;

"""Install platform skill/config files in the current project."""
def _project_install(
    platform_name: str, project_dir: Path | None = None, strict: bool = False
) -> None;

"""Remove project-scoped platform skill/config files only."""
def _project_uninstall(platform_name: str, project_dir: Path | None = None) -> None;

"""Remove project-scoped install files without touching user-scope installs."""
def _project_uninstall_all(project_dir: Path | None = None) -> None;

"""Remove the graphify section from the local AGENTS.md."""
def _agents_uninstall(project_dir: Path, platform: str = "") -> None;

def _kilo_uninstall_global -> list[str];

"""Install native Kilo skill + command globally and always-on project wiring locally."""
def _kilo_install(project_dir: Path) -> None;

"""Remove Kilo always-on project wiring and global skill/command files."""
def _kilo_uninstall(project_dir: Path) -> None;

with entry {
    _CLAUDE_MD_FILES = ("CLAUDE.md", ".claude/CLAUDE.md");
    _CLAUDE_MD_BLOCKERS = (*_CLAUDE_MD_FILES, "CLAUDE.local.md");
    _CLAUDE_AGENTS_MD_FILES = ("AGENTS.md", ".claude/AGENTS.md");
}

"""The file Claude Code reads project instructions from, for `claude install`.

    An existing CLAUDE.md (or .claude/CLAUDE.md) wins. With no CLAUDE.md-style
    file in the project or any directory above it, Claude Code reads the
    project's AGENTS.md instead, so that file is returned: creating a CLAUDE.md
    beside it would hide it, and every AGENTS.md above it, from Claude Code.
    Otherwise a new CLAUDE.md, as before. Claude Code's user-level CLAUDE.md
    ($CLAUDE_CONFIG_DIR/CLAUDE.md, default ~/.claude/CLAUDE.md) is user memory
    and blocks nothing, even when it sits in an ancestor. Claude Code's
    non-default modes (settings `instructionFiles`) are not read: the default decides.
    """
def _claude_instructions_file(project_dir: Path) -> Path;

"""Write the graphify section to the file Claude Code reads: CLAUDE.md, or
    the project's AGENTS.md when Claude Code reads that instead. Returns that file."""
def claude_install(
    project_dir: Path | None = None, strict: bool = False, project: bool = False
) -> Path;

"""Add graphify PreToolUse hook to .claude/settings.json.

    A project-scoped install emits the bare command, since .claude/settings.json
    is then committed and an installing machine's path is wrong there (#3129).
    """
def _install_claude_hook(project_dir: Path, strict: bool = False, project: bool = False) -> None;

"""Remove the graphify PreToolUse hook from .claude/settings.json and its
    local-only sibling .claude/settings.local.json.

    A user may relocate the hook into settings.local.json so it is not committed
    to a shared repo, so uninstall has to clean whichever file holds it (#1731).
    """
def _uninstall_claude_hook(project_dir: Path) -> None;

"""Drop graphify PreToolUse and SessionStart hooks from a single Claude
    settings file, if present."""
def _strip_graphify_hook(settings_path: Path) -> None;

"""Why ``rmtree(out)`` must not run for ``--purge``, or None when it is safe.

    The output dir may legitimately live outside the project (an absolute
    ``GRAPHIFY_OUT``), so this only rejects targets whose deletion would take
    the project, the home directory, or a filesystem root with it.
    """
def _unsafe_purge_reason(out: Path, project_dir: Path) -> str | None;

"""Remove graphify from every platform detected in the current project."""
def uninstall_all(project_dir: Path | None = None, purge: bool = False) -> None;

"""Remove the graphify skill tree (SKILL.md + references/) and the graphify
    section from CLAUDE.md and its local-only variants, plus the PreToolUse hook.

    Mirrors gemini_uninstall: the bare `graphify uninstall` and `graphify claude
    uninstall` must remove the installed skill, not just strip CLAUDE.md, or the
    progressive-disclosure tree (SKILL.md + references/) is orphaned (#1121).

    A user may relocate the section/hook into the local-only files Claude Code
    supports so they are not committed to a shared repo, so uninstall also cleans
    CLAUDE.local.md, .claude/CLAUDE.local.md and .claude/settings.local.json (#1731).

    Scope rules (#2215): a bare call removes the user-global skill; passing
    ``project_dir`` (or ``project=True``) scopes skill removal to that project
    and leaves the global tree untouched, unless ``remove_user_skill=True``
    explicitly opts back into the global delete (as ``uninstall_all`` does).
    """
def claude_uninstall(
    project_dir: Path | None = None, *, project: bool = False, remove_user_skill: bool | None = None
) -> None;

"""Strip the ## graphify section from one CLAUDE.md-style file.

    Returns True if a section was removed. Deletes the file if nothing else
    remains after removal.
    """
def _strip_graphify_md_section(target: Path) -> bool;

"""Install the graphify skill and CODEBUDDY.md section for CodeBuddy."""
def codebuddy_install(project_dir: Path | None = None) -> None;

"""Add graphify PreToolUse hook to .codebuddy/settings.json."""
def _install_codebuddy_hook(project_dir: Path) -> None;

"""Remove graphify PreToolUse hook from .codebuddy/settings.json."""
def _uninstall_codebuddy_hook(project_dir: Path) -> None;

"""Remove the graphify skill tree (SKILL.md + references/) and the CODEBUDDY.md section.

    Scope rules (#2215): a bare call removes the user-global skill; passing
    ``project_dir`` (or ``project=True``) scopes skill removal to that project
    and leaves the global tree untouched, unless ``remove_user_skill=True``
    explicitly opts back into the global delete (as ``uninstall_all`` does).
    """
def codebuddy_uninstall(
    project_dir: Path | None = None, *, project: bool = False, remove_user_skill: bool | None = None
) -> None;

with entry {
    _CLI_INSTALL_COMMANDS = frozenset({
        "agents",
        "aider",
        "amp",
        "antigravity",
        "claude",
        "claw",
        "codebuddy",
        "codex",
        "copilot",
        "cursor",
        "devin",
        "droid",
        "gemini",
        "hermes",
        "install",
        "kilo",
        "kiro",
        "opencode",
        "pi",
        "skills",
        "trae",
        "trae-cn",
        "uninstall",
        "vscode",
    });
}

"""Handle `graphify <install-command>` dispatch (install/uninstall + every
    per-platform install target). Returns True if cmd was an install command and
    was handled, False otherwise so the caller can continue its own dispatch.
    Moved verbatim from __main__.main().
    """
def dispatch_install_cli(cmd: str) -> bool;
