import importlib;
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

def _skill_lock_path(skill_dir: Path) -> Path;

with entry {
    _held_skill_locks = threading.local();
}

def _try_skill_lock(fh) -> bool;

def _release_skill_lock(fh);
@contextlib.contextmanager
def _skill_lock(skill_dir: Path, *, `wait: bool = True) -> Generator[any, any, any];
def _write_version_stamp(skill_dst: Path, version: str);
@functools.lru_cache(maxsize=None)
def _always_on(basename: str) -> str;
def _platform_skill_destination(
    platform_name: str, *, project: bool = False, project_dir: Path | None = None
) -> Path;
def _packaged_skill_refs_dir(platform_name: str) -> Path | None;
def _install_skill_references(skill_dst: Path, refs_src: Path);
def _copy_skill_file(
    platform_name: str, *, project: bool = False, project_dir: Path | None = None
) -> Path;
def _remove_skill_file(
    platform_name: str, *, project: bool = False, project_dir: Path | None = None
) -> bool;
def _project_scope_root(path: Path, project_dir: Path) -> Path;
def _is_graphify_skill_registration(section: "list[str]") -> bool;
def _skill_registration_sections(content: str) -> "list[list[str]]";
def _remove_skill_registration(target: Path, prefix: str, *, only_graphify_written: bool = False);
def _remove_claude_skill_registration(project_dir: Path);
def _claude_global_registration -> "tuple[Path, str]";
def _codebuddy_global_registration -> Path;

def _print_project_git_add_hint(paths: list[Path]);
def _claude_pretooluse_hooks(strict: bool = False, project: bool = False) -> "list[dict]";
def _claude_sessionstart_hooks(project: bool = False) -> "list[dict]";

with entry {
    _GRAPHIFY_HOOK_SUBCOMMANDS = ("hook-guard", "hook-check");
    _GRAPHIFY_LEGACY_HOOK_MARKER = "graphify-out/";
}

def _is_graphify_hook_command(command: str) -> bool;
def _is_graphify_hook_entry(`entry: object) -> bool;
def _strip_graphify_hooks(groups: "list") -> "list";

def _skill_registration(skill_path: str = "~/.claude/skills/graphify/SKILL.md") -> str;
def _shown_path(path: Path) -> str;
def _register_always_on_block(target: Path, prefix: str, registration: str);

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

def _canonical_platform(platform_name: str) -> str;
def _replace_or_append_section(
    content: str, marker: str, new_section: str, boundary_prefix: str = "## "
) -> str;
def _remove_marker_section(content: str, marker: str, boundary_prefix: str = "## ") -> "str | None";
def _read_keep_newline(path: Path) -> "tuple[str, str]";
def _write_keep_newline(path: Path, text: str, newline: str = "\n");

with entry {
    _BANNER_LOGO = "     ▄▄▀█▀▄▄\n ▄▄▀▀  ▄█▄  ▀▀▄▄\n██▀▀▀▀▀███▀▀▀▀▀▀▀    ▄█████▄                           ██       ██  ▄████\n█ ▀▄  ▄▀            ██▀   ▀▀▀ ██▄███  ██████▄ ██▄████▄ ██▄████▄ ▄▄ █████  ██    ██\n█   ███    ███▀▀█   ██  █████ ██▀     ▄▄▄▄▄██ ██▀  ▀██ ██▀  ▀██ ██  ██    ▀██  ██▀\n█   ▀▀█▄   ▀▀▀▄ █   ██▄   ▄██ ██     ██▀▀▀▀██ ██▄  ▄██ ██    ██ ██  ██     ▀█▄▄█▀\n█      ███     ▀█    ▀████▀██ ██     ▀██████▀ ██▀████▀ ██    ██ ██  ██      ▀██▀\n▀██▀▀▀▀▀█▀▀▀▀▀██▀                             ██                           ▄██\n   ▀▀▄▄ █ ▄▄▀▀                                ██                          ██▀\n       ▀▀▀";
}

def _print_banner;

def install(platform: str = "claude", *, project: bool = False, project_dir: Path | None = None);

def _print_install_usage;

with entry {
    _CLAUDE_MD_MARKER = "## graphify";
    _CODEBUDDY_MD_MARKER = "## graphify";
    _AGENTS_MD_MARKER = "## graphify";
    _GEMINI_MD_MARKER = "## graphify";
    _SKILL_REGISTRATION_MARKER = "# graphify";
}

def _gemini_hook(project: bool = False) -> dict;
def _warn_shadowing_agents_skill;
def gemini_install(project_dir: Path | None = None, *, project: bool = False);
def _refuse_to_modify(settings_path: Path) -> "NoReturn";
def _read_settings_for_merge(settings_path: Path) -> dict;
def _write_settings_with_backup(settings_path: Path, settings: dict);

def _install_gemini_hook(project_dir: Path, project: bool = False);

def _uninstall_gemini_hook(project_dir: Path);
def gemini_uninstall(
    project_dir: Path | None = None, *, project: bool = False, remove_user_skill: bool | None = None
);

with entry {
    _VSCODE_INSTRUCTIONS_MARKER = "## graphify";
}

def _vscode_skill_destination -> Path;
def vscode_install(project_dir: Path | None = None);
def vscode_uninstall(project_dir: Path | None = None);

with entry {
    _ANTIGRAVITY_RULES_PATH = Path(".agents") / "rules" / "graphify.md";
    _ANTIGRAVITY_WORKFLOW_PATH = Path(".agents") / "workflows" / "graphify.md";
    _ANTIGRAVITY_WORKFLOW = "---\nname: graphify\ndescription: Turn any folder of files into a navigable knowledge graph\n---\n\n# Workflow: graphify\n\nFollow the graphify skill to run the full pipeline.\n\nIf no path argument is given, use `.` (current directory).\n";
}

def _kiro_install(project_dir: Path);
def _kiro_uninstall(project_dir: Path);
def _antigravity_finalize(skill_dst: Path, project_dir: Path);
def _antigravity_install(project_dir: Path);
def _antigravity_uninstall(project_dir: Path, *, project: bool = False);

with entry {
    _CURSOR_RULE_PATH = Path(".cursor") / "rules" / "graphify.mdc";
    _CURSOR_RULE = "---\ndescription: graphify knowledge graph context\nalwaysApply: true\n---\n\nThis project has a graphify knowledge graph at graphify-out/.\n\n**MANDATORY: Before using Read, Grep, Glob, or Bash to explore the codebase, you MUST run graphify first:**\n- `graphify query \"<question>\"` — scoped subgraph for any codebase or architecture question\n- `graphify path \"<A>\" \"<B>\"` — dependency path between two symbols\n- `graphify explain \"<concept>\"` — all nodes related to a concept\n\nThis applies to YOU and to every subagent you spawn. Include this rule explicitly in every subagent prompt that involves code exploration. Do not skip graphify because files are \"already known\" or because you are executing a plan — the graph surfaces cross-file dependencies and INFERRED edges that grep and Read cannot find.\n\nOnly use Read/Grep/Glob directly when:\n1. graphify has already oriented you and you need to modify or debug specific lines\n2. `graphify-out/graph.json` does not exist yet\n\n- If `graphify-out/wiki/index.md` exists, navigate it instead of reading raw files\n- Read `graphify-out/GRAPH_REPORT.md` only for broad architecture review when query/path/explain do not surface enough context\n- After modifying code files, run `graphify update .` to keep the graph current (AST-only, no API cost)\n";
}

def _cursor_install(project_dir: Path);
def _cursor_uninstall(project_dir: Path);

with entry {
    _DEVIN_RULES_PATH = Path(".windsurf") / "rules" / "graphify.md";
    _DEVIN_RULES = "## graphify\n\nThis project has a graphify knowledge graph at graphify-out/.\n\nRules:\n- For codebase or architecture questions, when `graphify-out/graph.json` exists, first run `graphify query \"<question>\"` (or `graphify path \"<A>\" \"<B>\"` / `graphify explain \"<concept>\"`). These return a scoped subgraph, usually much smaller than `GRAPH_REPORT.md` or raw grep output.\n- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files\n- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context\n- After modifying code files in this session, run `graphify update .` to keep the graph current (AST-only, no API cost)\n";
}

def _devin_rules_install(project_dir: Path);
def _devin_rules_uninstall(project_dir: Path);

with entry {
    _KILO_PLUGIN_JS = "// graphify Kilo plugin\n// Injects a knowledge graph reminder before bash tool calls when the graph exists.\nimport { existsSync } from \"fs\";\nimport { join } from \"path\";\n\nexport const GraphifyPlugin = async ({ directory }) => {\n  let reminded = false;\n\n  return {\n    \"tool.execute.before\": async (input, output) => {\n      if (reminded) return;\n      if (!existsSync(join(directory, \"graphify-out\", \"graph.json\"))) return;\n\n      if (input.tool === \"bash\") {\n        // Separate with ';' not '&&' — Windows PowerShell 5.1 rejects '&&' as a\n        // statement separator (\"not a valid statement separator\"), which broke\n        // the first bash command in every OpenCode session on Windows (#1646).\n        // ';' works in PowerShell 5.1, Bash, and POSIX shells alike.\n        output.args.command =\n          'echo \"[graphify] Knowledge graph available. Read graphify-out/GRAPH_REPORT.md for god nodes and architecture context before searching files.\" ; ' +\n          output.args.command;\n        reminded = true;\n      }\n    },\n  };\n};\n";
    _KILO_PLUGIN_PATH = Path(".kilo") / "plugins" / "graphify.js";
    _KILO_CONFIG_JSON_PATH = Path(".kilo") / "kilo.json";
    _KILO_CONFIG_JSONC_PATH = Path(".kilo") / "kilo.jsonc";
}

def _strip_json_comments(raw: str) -> str;

def _load_json_like(config_file: Path) -> dict;
def _read_json_like_for_merge(config_file: Path) -> dict;

def _kilo_config_path(project_dir: Path) -> Path;
def _kilo_config_write_path(project_dir: Path) -> Path;
def _install_kilo_plugin(project_dir: Path);
def _uninstall_kilo_plugin(project_dir: Path);

with entry {
    _OPENCODE_PLUGIN_JS = "// graphify OpenCode plugin\n// Injects a knowledge graph reminder before the first shell command of a\n// session when the graph exists.\n//\n// One file for both runtimes. OpenCode 2 reads `id` and `setup()` from the\n// default export; OpenCode 1 (1.3.4 and later) reads `server()` from it. Each\n// ignores the other's function. Nothing is imported from an opencode package:\n// a plain file in .opencode/plugins/ cannot resolve one.\n//\n// IMPORTANT: keep the reminder string free of backticks and $(...) constructs.\n// The hook prepends `echo \"<reminder>\" ; <cmd>` to the user's shell command;\n// backticks inside the double-quoted echo trigger command substitution,\n// which both corrupts tool output and silently executes the very graphify\n// command we are only suggesting. Plain words render fine in opencode's TUI.\nimport { existsSync } from \"fs\";\nimport { join } from \"path\";\n\n// ';' not '&&' — Windows PowerShell 5.1 rejects '&&' as a statement\n// separator, breaking the first shell command of the session (#1646).\nconst REMINDER =\n  'echo \"[graphify] knowledge graph at graphify-out/. For focused questions, run graphify query with your question (scoped subgraph, usually much smaller than GRAPH_REPORT.md) instead of grepping raw files. Read GRAPH_REPORT.md only for broad architecture context.\" ; ';\n\nconst hasGraph = (directory) => existsSync(join(directory, \"graphify-out\", \"graph.json\"));\n\n// A project and a directory above it (often ~) can each hold a copy of this\n// file, and OpenCode loads both. OpenCode 2 fails the second plugin with the\n// same id (\"Duplicate plugin ID\"), so the id carries this file's location. The\n// copies share one record of who was reminded, so a command gets one reminder.\nconst location = [...import.meta.url].reduce((hash, ch) => (Math.imul(hash, 31) + ch.charCodeAt(0)) >>> 0, 7);\nconst reminded = (globalThis.__graphifyReminded ??= new Set());\n\nexport default {\n  id: `graphify-${location.toString(16)}`,\n\n  // OpenCode 2: the command tool is \"shell\", and one server outlives many\n  // sessions, so the reminder is tracked per session.\n  async setup(ctx) {\n    await ctx.tool.hook(\"execute.before\", (event) => {\n      if (event.tool !== \"shell\" || typeof event.input?.command !== \"string\") return;\n      if (reminded.has(event.sessionID)) return;\n      if (!hasGraph(ctx.location.directory)) return;\n\n      event.input = { ...event.input, command: REMINDER + event.input.command };\n      reminded.add(event.sessionID);\n    });\n  },\n\n  // OpenCode 1: the command tool is \"bash\", and the server lives as long as\n  // the session, so the reminder is tracked per project directory.\n  async server({ directory }) {\n    return {\n      \"tool.execute.before\": async (input, output) => {\n        if (input.tool !== \"bash\" || typeof output.args?.command !== \"string\") return;\n        if (reminded.has(directory)) return;\n        if (!hasGraph(directory)) return;\n\n        output.args.command = REMINDER + output.args.command;\n        reminded.add(directory);\n      },\n    };\n  },\n};\n";
    _OPENCODE_PLUGIN_PATH = Path(".opencode") / "plugins" / "graphify.js";
    _OPENCODE_CONFIG_PATH = Path(".opencode") / "opencode.json";
}

def _opencode_dir(*, project: bool, project_dir: Path | None = None) -> Path;

with entry {
    _OPENCODE_PLUGIN_HEADER = "// graphify OpenCode plugin";
}

def _opencode_plugin_is_v1_only(body: str) -> bool;
def _opencode_config_names_plugin(opencode_dir: Path) -> bool;
def _drop_opencode_config_entry(opencode_dir: Path) -> bool;
def _install_opencode_plugin(opencode_dir: Path);
def _uninstall_opencode_plugin(opencode_dir: Path);
def _resolve_graphify_exe(project: bool = False) -> str;
def _install_codex_hook(project_dir: Path, project: bool = False);
def _uninstall_codex_hook(project_dir: Path);
def _agents_install(project_dir: Path, platform: str, project: bool = False);
def _amp_legacy_cleanup;
def _amp_install(project_dir: Path | None = None);
def _amp_uninstall(project_dir: Path | None = None);
def _agents_platform_install(project_dir: Path | None = None);
def _agents_platform_uninstall(project_dir: Path | None = None);
def _project_install(platform_name: str, project_dir: Path | None = None, strict: bool = False);
def _project_uninstall(platform_name: str, project_dir: Path | None = None);
def _project_uninstall_all(project_dir: Path | None = None);
def _agents_uninstall(project_dir: Path, platform: str = "");

def _kilo_uninstall_global -> list[str];
def _kilo_install(project_dir: Path);
def _kilo_uninstall(project_dir: Path);

with entry {
    _CLAUDE_MD_FILES = ("CLAUDE.md", ".claude/CLAUDE.md");
    _CLAUDE_MD_BLOCKERS = (*_CLAUDE_MD_FILES, "CLAUDE.local.md");
    _CLAUDE_AGENTS_MD_FILES = ("AGENTS.md", ".claude/AGENTS.md");
}

def _claude_instructions_file(project_dir: Path) -> Path;
def claude_install(
    project_dir: Path | None = None, strict: bool = False, project: bool = False
) -> Path;
def _install_claude_hook(project_dir: Path, strict: bool = False, project: bool = False);
def _uninstall_claude_hook(project_dir: Path);
def _strip_graphify_hook(settings_path: Path);
def _unsafe_purge_reason(out: Path, project_dir: Path) -> str | None;
def uninstall_all(project_dir: Path | None = None, purge: bool = False);
def claude_uninstall(
    project_dir: Path | None = None, *, project: bool = False, remove_user_skill: bool | None = None
);
def _strip_graphify_md_section(target: Path) -> bool;
def codebuddy_install(project_dir: Path | None = None);
def _install_codebuddy_hook(project_dir: Path);
def _uninstall_codebuddy_hook(project_dir: Path);
def codebuddy_uninstall(
    project_dir: Path | None = None, *, project: bool = False, remove_user_skill: bool | None = None
);

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

def dispatch_install_cli(cmd: str) -> bool;
