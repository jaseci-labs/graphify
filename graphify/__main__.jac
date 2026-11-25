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
def _check_skill_version(skill_dst: Path, platform_names: "list[str] | None" = None);
def _version_tuple(version: str) -> tuple[int, ...];
def _refresh_stale_skills;
def _stale_stamp(skill_dst: Path) -> str | None;
def _skill_platforms -> list[str];
def _refresh_one_skill(name: str, skill_dst: Path, installed: str);
def _opencode_loads_current_plugin -> bool;
def _refresh_v1_opencode_plugins;

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

def _silence_broken_pipe;

with entry {
    _HASHSEED_PINNED_COMMANDS = frozenset({"update", "extract", "cluster-only", "label"});
}

def _pin_hash_seed_if_needed;
def _reexec(argv: list[str], env: dict[str, str], windows: bool | None = None);
def main;

def _run_cli;

with entry:__main__ {
    main();
}
