import operator;

import from __future__ { annotations }

import os;

import re;

import subprocess as _sp;

import sys;

import from pathlib { Path }

glob _HOOK_MARKER: any = "# graphify-hook-start";

glob _HOOK_MARKER_END: any = "# graphify-hook-end";

glob _CHECKOUT_MARKER: any = "# graphify-checkout-hook-start";

glob _CHECKOUT_MARKER_END: any = "# graphify-checkout-hook-end";

glob _MERGE_HOOK_MARKER: any = "# graphify-merge-hook-start";

glob _MERGE_HOOK_MARKER_END: any = "# graphify-merge-hook-end";

glob _REWRITE_HOOK_MARKER: any = "# graphify-rewrite-hook-start";

glob _REWRITE_HOOK_MARKER_END: any = "# graphify-rewrite-hook-end";

glob _PYTHON_DETECT: any = "# Detect the correct Python interpreter (handles uv tool, pipx, venv, system installs).\n# _PINNED was recorded at hook-install time; tried first so the hook works even\n# when the graphify launcher is not on PATH (common in GUI clients and CI).\n#\n# Probes check availability with importlib.util.find_spec instead of importing\n# the package: a probe that imports graphify wholesale executes the full package\n# import (10s+ cold on machines with AV-scanned or large site-packages) and used\n# to run up to FOUR times synchronously, stalling every commit before the\n# detached launch even started. find_spec locates the package without executing\n# it, so each probe costs interpreter startup only. The detached rebuild still\n# fails loudly in the log if the package is broken under that interpreter.\n_GFY_PROBE=\"import importlib.util, sys; sys.exit(0 if importlib.util.find_spec('graphify') else 1)\"\nGRAPHIFY_PYTHON=\"\"\n_PINNED='__PINNED_PYTHON__'\nif [ -n \"$_PINNED\" ] && [ -x \"$_PINNED\" ] && \"$_PINNED\" -c \"$_GFY_PROBE\" 2>/dev/null; then\n    GRAPHIFY_PYTHON=\"$_PINNED\"\nfi\n# Second probe: read graphify-out/.graphify_python (written by the skill and\n# CLI; survives uv-tool reinstalls and is the same source the README documents).\nif [ -z \"$GRAPHIFY_PYTHON\" ]; then\n    _GFY_PYTHON_FILE=\"graphify-out/.graphify_python\"\n    if [ -f \"$_GFY_PYTHON_FILE\" ]; then\n        _FROM_FILE=$(cat \"$_GFY_PYTHON_FILE\" 2>/dev/null | tr -d '[:space:]')\n        case \"$_FROM_FILE\" in\n            *[!a-zA-Z0-9/_.@:\\\\-]*) _FROM_FILE=\"\" ;;  # allowlist (covers Windows paths)\n        esac\n        if [ -n \"$_FROM_FILE\" ] && [ -x \"$_FROM_FILE\" ] && \"$_FROM_FILE\" -c \"$_GFY_PROBE\" 2>/dev/null; then\n            GRAPHIFY_PYTHON=\"$_FROM_FILE\"\n        fi\n    fi\nfi\n# Third probe: resolve via the graphify launcher on PATH.\nif [ -z \"$GRAPHIFY_PYTHON\" ]; then\n    GRAPHIFY_BIN=$(command -v graphify 2>/dev/null)\n    if [ -n \"$GRAPHIFY_BIN\" ]; then\n        # Windows pip layout: Scripts/graphify(.exe) sits beside ..\\python.exe\n        # (or .\\python.exe inside a venv's Scripts dir). NOTE: command -v may\n        # return the launcher path WITHOUT the .exe suffix, so this cannot key\n        # on the extension.\n        _GFY_BINDIR=$(dirname \"$GRAPHIFY_BIN\")\n        if [ -x \"$_GFY_BINDIR/../python.exe\" ] && \"$_GFY_BINDIR/../python.exe\" -c \"$_GFY_PROBE\" 2>/dev/null; then\n            GRAPHIFY_PYTHON=\"$_GFY_BINDIR/../python.exe\"\n        elif [ -x \"$_GFY_BINDIR/python.exe\" ] && \"$_GFY_BINDIR/python.exe\" -c \"$_GFY_PROBE\" 2>/dev/null; then\n            GRAPHIFY_PYTHON=\"$_GFY_BINDIR/python.exe\"\n        fi\n    fi\n    if [ -z \"$GRAPHIFY_PYTHON\" ] && [ -n \"$GRAPHIFY_BIN\" ]; then\n        # POSIX launcher: parse the shebang. head -c + tr strip NUL bytes first —\n        # when the launcher is a Windows binary reached without its .exe suffix,\n        # a raw `head -1` reads binary into the command substitution and the\n        # shell warns about ignored null bytes on every commit. Gate on a\n        # leading '#!': a launcher can also be a binary trampoline with no\n        # shebang at all (uv tool installs on Windows), and its bytes must\n        # never reach the shebang parse (#2852).\n        case \"$GRAPHIFY_BIN\" in\n            *.exe) _GFY_HEAD=\"\" ;;\n            *)     _GFY_HEAD=$(head -c 256 \"$GRAPHIFY_BIN\" 2>/dev/null | tr -d '\\000') ;;\n        esac\n        case \"$_GFY_HEAD\" in\n            '#!'*) _SHEBANG=$(printf '%s\\n' \"$_GFY_HEAD\" | head -n 1 | sed 's/^#![[:space:]]*//') ;;\n            *)     _SHEBANG=\"\" ;;\n        esac\n        case \"$_SHEBANG\" in\n            */env\\ *) GRAPHIFY_PYTHON=\"${_SHEBANG#*/env }\" ;;\n            *)         GRAPHIFY_PYTHON=\"$_SHEBANG\" ;;\n        esac\n        # Allowlist: only keep characters valid in a filesystem path to prevent\n        # injection if the shebang contains shell metacharacters.\n        case \"$GRAPHIFY_PYTHON\" in\n            *[!a-zA-Z0-9/_.@:\\\\-]*) GRAPHIFY_PYTHON=\"\" ;;\n        esac\n        if [ -n \"$GRAPHIFY_PYTHON\" ] && ! \"$GRAPHIFY_PYTHON\" -c \"$_GFY_PROBE\" 2>/dev/null; then\n            GRAPHIFY_PYTHON=\"\"\n        fi\n    fi\nfi\n# Fourth probe: uv tool environments. `uv tool install` (the README's\n# recommended method) puts graphify in an isolated venv that no ambient\n# python can import, and on Windows its launcher on PATH is a binary\n# trampoline with no shebang to parse — so the probes above can all miss a\n# healthy install and the hook dies at the last-resort fallback (#2852).\n# Scan the uv tool envs directly; UV_TOOL_DIR overrides the default\n# location. A tool env is adopted only if its python passes the probe, so a\n# co-installed tool without graphify never satisfies it.\n#\n# The snap roots matter because an install made from inside a snap-confined\n# editor lands in that snap's private HOME, which the plain $HOME roots above\n# never see once the hook runs from an ordinary shell. Revisions are globbed\n# rather than pinned: snap rotates them on update, which is exactly what makes\n# a pinned path unsafe (see _is_rotating_prefix).\nif [ -z \"$GRAPHIFY_PYTHON\" ]; then\n    for _GFY_TOOLS in         \"${UV_TOOL_DIR:-}\"         \"$HOME/.local/share/uv/tools\"         \"$HOME/AppData/Roaming/uv/tools\"         \"$HOME\"/snap/*/current/.local/share/uv/tools         \"$HOME\"/snap/*/[0-9]*/.local/share/uv/tools; do\n        [ -n \"$_GFY_TOOLS\" ] || continue\n        for _GFY_CAND in \"$_GFY_TOOLS\"/*/bin/python \"$_GFY_TOOLS\"/*/Scripts/python.exe; do\n            [ -x \"$_GFY_CAND\" ] || continue\n            if \"$_GFY_CAND\" -c \"$_GFY_PROBE\" 2>/dev/null; then\n                GRAPHIFY_PYTHON=\"$_GFY_CAND\"\n                break 2\n            fi\n        done\n    done\nfi\n# Last resort: try python3 / python (works for system/venv installs on PATH).\nif [ -z \"$GRAPHIFY_PYTHON\" ]; then\n    if command -v python3 >/dev/null 2>&1 && python3 -c \"$_GFY_PROBE\" 2>/dev/null; then\n        GRAPHIFY_PYTHON=\"python3\"\n    elif command -v python >/dev/null 2>&1 && python -c \"$_GFY_PROBE\" 2>/dev/null; then\n        GRAPHIFY_PYTHON=\"python\"\n    else\n        echo \"[graphify hook] could not locate a Python with graphify installed. Add the graphify bin dir to PATH or re-run 'graphify hook install' from the env where graphify lives.\" >&2\n        exit 0\n    fi\nfi\n";

glob _GIT_C_ESCAPES: any = {
    "a": 7,
    "b": 8,
    "t": 9,
    "n": 10,
    "v": 11,
    "f": 12,
    "r": 13,
    "\"": 34,
    "\\": 92,
};

"""Decode a path as printed by ``git diff --name-only``.

    Even with ``core.quotePath=false`` git wraps a name containing a double
    quote, backslash or control character in double quotes and C-escapes it,
    spelling raw bytes as ``\\ooo`` octal. Unquoted names are returned as-is.
    """
def _unquote_git_path(name: str) -> str;

glob _REBUILD_BODY_COMMIT: any = "import os, signal, sys, threading, multiprocessing\nfrom pathlib import Path\n\nfrom graphify.hooks import _unquote_git_path\n\nchanged_raw = os.environ.get('GRAPHIFY_CHANGED', '')\nchanged = [Path(_unquote_git_path(f.strip())) for f in changed_raw.strip().splitlines() if f.strip()]\n\nif not changed:\n    sys.exit(0)\n\nprint(f'[graphify hook] {len(changed)} file(s) changed - rebuilding graph...')\n\ntry:\n    from graphify.watch import _rebuild_code, _apply_resource_limits\n    _apply_resource_limits()\n    _timeout = int(os.environ.get('GRAPHIFY_REBUILD_TIMEOUT', '600'))\n    if _timeout > 0:\n        if hasattr(signal, 'SIGALRM'):\n            def _sigalrm_bail(*_a):\n                # Killing here, before the exception unwinds, matters: once\n                # TimeoutError starts propagating it passes straight through\n                # the ProcessPoolExecutor with-block's own __exit__, which\n                # calls shutdown(wait=True) and blocks until every worker\n                # exits -- forever, for a worker stuck the way #3341 was,\n                # since the alarm firing never actually stops it. Killing the\n                # workers first means shutdown has nothing left to wait for.\n                for _child in multiprocessing.active_children():\n                    _child.kill()\n                raise TimeoutError(f'graphify rebuild exceeded {_timeout}s')\n            signal.signal(signal.SIGALRM, _sigalrm_bail)\n            signal.alarm(_timeout)\n        else:\n            def _bail():\n                print(f'[graphify hook] graphify rebuild exceeded {_timeout}s', flush=True)\n                for _child in multiprocessing.active_children():\n                    _child.kill()\n                os._exit(1)\n            _watchdog = threading.Timer(_timeout, _bail)\n            _watchdog.daemon = True\n            _watchdog.start()\n    _force = os.environ.get('GRAPHIFY_FORCE', '').lower() in ('1', 'true', 'yes')\n    _root = Path('.')\n    from graphify.paths import GRAPHIFY_OUT as _out\n    _saved = Path(_out) / '.graphify_root'\n    if _saved.exists():\n        _txt = _saved.read_text(encoding='utf-8-sig').strip()\n        if _txt:\n            _candidate = Path(_txt)\n            try:\n                _cwd = Path.cwd().resolve()\n                _resolved = _candidate.resolve()\n                # Python 3.13 no longer raises on a symlink loop (resolve returns\n                # the path unresolved), so require a real directory: a loop or a\n                # dangling target is not a dir and correctly falls back.\n                _in_repo = (_resolved == _cwd or _cwd in _resolved.parents) and _resolved.is_dir()\n            except (OSError, RuntimeError):\n                _in_repo = False\n            if _in_repo:\n                _root = _candidate\n            else:\n                print(f'[graphify hook] ignoring out-of-repo .graphify_root: {_txt}')\n    _rebuild_code(_root, changed_paths=changed, force=_force)\n    # Refresh the work-memory lessons doc when saved Q&A outcomes exist\n    # (best-effort; never fails the hook).\n    try:\n        _md = (_root / _out) / 'memory'\n        if _md.is_dir() and any(_md.glob('*.md')):\n            from graphify.reflect import reflect as _reflect\n            _gj = (_root / _out) / 'graph.json'\n            _reflect(memory_dir=_md, out_path=(_root / _out) / 'reflections' / 'LESSONS.md',\n                     graph_path=_gj if _gj.exists() else None)\n    except Exception:\n        pass\nexcept TimeoutError as exc:\n    print(f'[graphify hook] {exc}')\n    sys.exit(1)\nexcept Exception as exc:\n    print(f'[graphify hook] Rebuild failed: {exc}')\n    sys.exit(1)\n";

glob _REBUILD_BODY_CHECKOUT: any = "from graphify.watch import _rebuild_code, _apply_resource_limits\nfrom pathlib import Path\nimport os, signal, sys, threading, multiprocessing\ntry:\n    _apply_resource_limits()\n    _timeout = int(os.environ.get('GRAPHIFY_REBUILD_TIMEOUT', '600'))\n    if _timeout > 0:\n        if hasattr(signal, 'SIGALRM'):\n            def _sigalrm_bail(*_a):\n                # Killing here, before the exception unwinds, matters: once\n                # TimeoutError starts propagating it passes straight through\n                # the ProcessPoolExecutor with-block's own __exit__, which\n                # calls shutdown(wait=True) and blocks until every worker\n                # exits -- forever, for a worker stuck the way #3341 was,\n                # since the alarm firing never actually stops it. Killing the\n                # workers first means shutdown has nothing left to wait for.\n                for _child in multiprocessing.active_children():\n                    _child.kill()\n                raise TimeoutError(f'graphify rebuild exceeded {_timeout}s')\n            signal.signal(signal.SIGALRM, _sigalrm_bail)\n            signal.alarm(_timeout)\n        else:\n            def _bail():\n                print(f'[graphify] graphify rebuild exceeded {_timeout}s', flush=True)\n                for _child in multiprocessing.active_children():\n                    _child.kill()\n                os._exit(1)\n            _watchdog = threading.Timer(_timeout, _bail)\n            _watchdog.daemon = True\n            _watchdog.start()\n    _force = os.environ.get('GRAPHIFY_FORCE', '').lower() in ('1', 'true', 'yes')\n    # post-checkout: branch switch can touch arbitrary files; full rebuild path\n    # (no changed_paths) is correct here. The flock inside _rebuild_code still\n    # prevents pile-ups when commit + checkout fire back-to-back.\n    _root = Path('.')\n    from graphify.paths import GRAPHIFY_OUT as _out\n    _saved = Path(_out) / '.graphify_root'\n    if _saved.exists():\n        _txt = _saved.read_text(encoding='utf-8-sig').strip()\n        if _txt:\n            _candidate = Path(_txt)\n            try:\n                _cwd = Path.cwd().resolve()\n                _resolved = _candidate.resolve()\n                # Python 3.13 no longer raises on a symlink loop (resolve returns\n                # the path unresolved), so require a real directory: a loop or a\n                # dangling target is not a dir and correctly falls back.\n                _in_repo = (_resolved == _cwd or _cwd in _resolved.parents) and _resolved.is_dir()\n            except (OSError, RuntimeError):\n                _in_repo = False\n            if _in_repo:\n                _root = _candidate\n            else:\n                print(f'[graphify] ignoring out-of-repo .graphify_root: {_txt}')\n    _rebuild_code(_root, force=_force)\n    # Refresh the work-memory lessons doc when saved Q&A outcomes exist\n    # (best-effort; never fails the hook).\n    try:\n        _md = (_root / _out) / 'memory'\n        if _md.is_dir() and any(_md.glob('*.md')):\n            from graphify.reflect import reflect as _reflect\n            _gj = (_root / _out) / 'graph.json'\n            _reflect(memory_dir=_md, out_path=(_root / _out) / 'reflections' / 'LESSONS.md',\n                     graph_path=_gj if _gj.exists() else None)\n    except Exception:\n        pass\nexcept TimeoutError as exc:\n    print(f'[graphify] {exc}')\n    sys.exit(1)\nexcept Exception as exc:\n    print(f'[graphify] Rebuild failed: {exc}')\n    sys.exit(1)\n";

glob _LAUNCHER_TEMPLATE: any = "import os, subprocess, sys\n_src = '''\n__REBUILD_BODY__\n'''\n_log = os.environ.get('GRAPHIFY_REBUILD_LOG') or os.path.join(os.path.expanduser('~'), '.cache', 'graphify-rebuild.log')\ntry:\n    os.makedirs(os.path.dirname(_log), exist_ok=True)\n    _out = open(_log, 'a', buffering=1, encoding='utf-8', errors='replace')\nexcept OSError:\n    _out = subprocess.DEVNULL\n_kw = dict(stdout=_out, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, cwd=os.getcwd(), close_fds=True)\n_cmd = [sys.executable, '-c', _src]\nif os.name == 'nt':\n    _flags = 0x08000000 | 0x00000200  # CREATE_NO_WINDOW | CREATE_NEW_PROCESS_GROUP\n    try:\n        subprocess.Popen(_cmd, creationflags=_flags | 0x01000000, **_kw)  # + CREATE_BREAKAWAY_FROM_JOB\n    except OSError:\n        subprocess.Popen(_cmd, creationflags=_flags, **_kw)\nelse:\n    subprocess.Popen(_cmd, start_new_session=True, **_kw)\n";

"""Return a POSIX-sh line that runs ``rebuild_body`` as a detached background
    Python process via ``$GRAPHIFY_PYTHON``.

    Replaces the old ``nohup ... &`` form, which failed on Git for Windows'
    shell (no nohup/setsid) and let the rebuild silently never run (#1161).
    The launcher writes the child's output to ``$GRAPHIFY_REBUILD_LOG`` and
    returns the instant the child is spawned, so the git hook never blocks.
    """
def _detached_launch(rebuild_body: str) -> str;

glob _WORKTREE_GUARD: any = "_GFY_GITDIR=$(CDPATH= cd \"$(git rev-parse --git-dir 2>/dev/null)\" 2>/dev/null && pwd)\n_GFY_COMMONDIR=$(CDPATH= cd \"$(git rev-parse --git-common-dir 2>/dev/null)\" 2>/dev/null && pwd)\nif [ -n \"$_GFY_COMMONDIR\" ] && [ \"$_GFY_GITDIR\" != \"$_GFY_COMMONDIR\" ]; then\n    exit 0\nfi\n";

glob _TOPLEVEL_ANCHOR: any = "if [ -z \"${GIT_WORK_TREE:-}\" ] && [ \"${_GFY_COMMONDIR##*/}\" = \".git\" ]; then\n    _GFY_TOP=${_GFY_COMMONDIR%/*}\nelse\n    _GFY_TOP=$(git rev-parse --show-toplevel 2>/dev/null)\nfi\n[ -n \"$_GFY_TOP\" ] && cd \"$_GFY_TOP\" || exit 0\n[ -n \"$_GFY_GITDIR\" ] && GIT_DIR=$_GFY_GITDIR\n";

glob _HOOK_SCRIPT: any;

glob _CHECKOUT_SCRIPT: any;

glob _MERGE_SCRIPT: any;

glob _REWRITE_SCRIPT: any;

glob _WINDOWS_DRIVE_RE: any;

glob _ROTATING_PREFIX_RE: any;

glob _PINNED_LINE_RE: any;

glob _VIZ_EXPORT_LINE_RE: any;

with entry {
    _HOOK_SCRIPT = "# graphify-hook-start\n# Auto-rebuilds the knowledge graph after each commit (code files only, no LLM needed).\n# Installed by: graphify hook install\n(\n\n# Deterministic clustering: networkx louvain iterates string-keyed sets whose\n# order is randomized per-process by PYTHONHASHSEED, so community assignments\n# churn run-to-run. Pinning it makes graphify-out reproducible.\nexport PYTHONHASHSEED=0\n__VIZ_LIMIT_EXPORT__\n# Git for Windows/MSYS hooks can inherit fragile pipe handles from GUI clients\n# and agent shells. Keep hook-triggered rebuilds sequential by default there;\n# explicit GRAPHIFY_MAX_WORKERS still wins for users who want parallelism.\nif [ -n \"${WINDIR:-}\" ] || [ -n \"${MSYSTEM:-}\" ]; then\n    export GRAPHIFY_MAX_WORKERS=\"${GRAPHIFY_MAX_WORKERS:-1}\"\nfi\n\n# Skip during a rebase or merge to avoid blocking --continue with unstaged changes\n# git exports GIT_DIR to hooks; the rev-parse fallback only runs when invoked by\n# hand (each git exec costs 1s+ on AV-scanned Windows machines).\nGIT_DIR=${GIT_DIR:-$(git rev-parse --git-dir 2>/dev/null)}\n[ -d \"$GIT_DIR/rebase-merge\" ] && exit 0\n[ -d \"$GIT_DIR/rebase-apply\" ] && exit 0\n[ -f \"$GIT_DIR/MERGE_HEAD\" ] && exit 0\n[ \"${GRAPHIFY_SKIP_HOOK:-0}\" = \"1\" ] && exit 0\n\n"
        + _WORKTREE_GUARD
        + _TOPLEVEL_ANCHOR
        + "\n# CHERRY_PICK_HEAD can't be the skip signal: git leaves it on disk while post-commit\n# runs, so every pick was silenced (#4490, same trap as MERGE_HEAD in #4463). For a\n# range pick or revert, skip every step but the last and rebuild once from\n# sequencer/head, so a tracked graph.json isn't rewritten between steps. sequencer/ is\n# trusted only when its first todo line is the commit just made; a stale one left by\n# `git reset --hard` would otherwise silence every later commit.\n_GFY_SEQ_BASE=\"\"\nif [ -f \"$GIT_DIR/sequencer/todo\" ]; then\n    IFS= read -r _GFY_FIRST < \"$GIT_DIR/sequencer/todo\"\n    _GFY_VERB=${_GFY_FIRST%% *}\n    _GFY_REST=${_GFY_FIRST#* }\n    case \"$_GFY_REST\" in\n        *\" \"*) _GFY_SUBJ=${_GFY_REST#* } ;;\n        *)     _GFY_SUBJ=\"\" ;;\n    esac\n    _GFY_SEQ_LIVE=0\n    _GFY_Q='\"'\n    case \"$_GFY_VERB\" in\n        pick)   [ \"$(git log -1 --format=%s 2>/dev/null)\" = \"$_GFY_SUBJ\" ] && _GFY_SEQ_LIVE=1 ;;\n        revert) [ \"$(git log -1 --format=%s 2>/dev/null)\" = \"Revert ${_GFY_Q}${_GFY_SUBJ}${_GFY_Q}\" ] && _GFY_SEQ_LIVE=1 ;;\n    esac\n    if [ \"$_GFY_SEQ_LIVE\" = \"1\" ]; then\n        _GFY_PENDING=0\n        while IFS= read -r _GFY_STEP || [ -n \"$_GFY_STEP\" ]; do\n            [ -n \"$_GFY_STEP\" ] && _GFY_PENDING=$((_GFY_PENDING + 1))\n        done < \"$GIT_DIR/sequencer/todo\"\n        [ \"$_GFY_PENDING\" -gt 1 ] && exit 0\n        [ -f \"$GIT_DIR/sequencer/head\" ] && IFS= read -r _GFY_SEQ_BASE < \"$GIT_DIR/sequencer/head\"\n    fi\nfi\n\n# core.quotePath=false: by default git prints a non-ASCII path as a quoted\n# octal-escaped string, which matches no file on disk, so the edit was silently\n# left out of the rebuild. Names git still quotes are decoded in the rebuild.\nCHANGED=$(git -c core.quotePath=false diff --name-only HEAD~1 HEAD 2>/dev/null || git -c core.quotePath=false diff --name-only HEAD 2>/dev/null)\n# Last pick of a range: cover every commit picked since the sequence began, not only this one.\nif [ -n \"$_GFY_SEQ_BASE\" ]; then\n    CHANGED=$(git -c core.quotePath=false diff --name-only \"$_GFY_SEQ_BASE\" HEAD 2>/dev/null)\nfi\nif [ -z \"$CHANGED\" ]; then\n    exit 0\nfi\n\n# Skip when only output-dir artifacts changed (avoids rebuild loop when graph\n# outputs are tracked in git). The dir is whatever GRAPHIFY_OUT names, the same\n# source the rebuild body reads (#1423): a literal graphify-out/ here let a\n# commit touching only a renamed output dir's graph.json trigger a full rebuild.\n_GFY_OUT=\"${GRAPHIFY_OUT:-graphify-out}\"\n_GFY_OUT=\"${_GFY_OUT%/}\"\n# The leading ( on each pattern is POSIX and keeps bash 3.2 (macOS /bin/sh)\n# from mis-parsing the pattern's ) as the end of the $(...) substitution.\n_NON_GRAPH=$(printf '%s\n' \"$CHANGED\" | while IFS= read -r _GFY_F; do\n    case \"$_GFY_F\" in\n        (\"$_GFY_OUT\"/*) ;;\n        (*) printf '%s\n' \"$_GFY_F\" ;;\n    esac\ndone)\nif [ -z \"$_NON_GRAPH\" ]; then\n    exit 0\nfi\n\n"
        + _PYTHON_DETECT
        + "\nexport GRAPHIFY_CHANGED=\"$CHANGED\"\n\n# Run the rebuild detached so git commit returns immediately. Full-repo rebuilds\n# can take hours; blocking the post-commit hook stalls the shell. The Python\n# launcher below detaches the child cross-platform, so it works on Git for\n# Windows' shell too (which lacks the coreutils backgrounding tools) (#1161).\n_GRAPHIFY_LOG=\"${HOME}/.cache/graphify-rebuild.log\"\nmkdir -p \"$(dirname \"$_GRAPHIFY_LOG\")\"\nexport GRAPHIFY_REBUILD_LOG=\"$_GRAPHIFY_LOG\"\necho \"[graphify hook] launching background rebuild (log: $_GRAPHIFY_LOG)\"\n"
        + _detached_launch(_REBUILD_BODY_COMMIT)
        + ")\n# graphify-hook-end\n";

    _CHECKOUT_SCRIPT = "# graphify-checkout-hook-start\n# Auto-rebuilds the knowledge graph (code only) when switching branches.\n# Installed by: graphify hook install\n(\n\n# Deterministic clustering: networkx louvain iterates string-keyed sets whose\n# order is randomized per-process by PYTHONHASHSEED, so community assignments\n# churn run-to-run. Pinning it makes graphify-out reproducible.\nexport PYTHONHASHSEED=0\n__VIZ_LIMIT_EXPORT__\n# Git for Windows/MSYS hooks can inherit fragile pipe handles from GUI clients\n# and agent shells. Keep hook-triggered rebuilds sequential by default there;\n# explicit GRAPHIFY_MAX_WORKERS still wins for users who want parallelism.\nif [ -n \"${WINDIR:-}\" ] || [ -n \"${MSYSTEM:-}\" ]; then\n    export GRAPHIFY_MAX_WORKERS=\"${GRAPHIFY_MAX_WORKERS:-1}\"\nfi\n\nPREV_HEAD=$1\nNEW_HEAD=$2\nBRANCH_SWITCH=$3\n\n# Only run on branch switches, not file checkouts\nif [ \"$BRANCH_SWITCH\" != \"1\" ]; then\n    exit 0\nfi\n\n# A no-op checkout (e.g. `git checkout -b` with no start point) reports a\n# branch switch but leaves the tree unchanged ΓÇö nothing to rebuild (#2421).\n[ \"$PREV_HEAD\" = \"$NEW_HEAD\" ] && exit 0\n\n# Only run if the output dir exists (graph has been built before). Resolve it\n# from GRAPHIFY_OUT like the rebuild body does (#1423): a literal graphify-out/\n# here made the branch-switch rebuild a silent no-op for every renamed output dir.\n_GFY_OUT=\"${GRAPHIFY_OUT:-graphify-out}\"\nif [ ! -d \"${_GFY_OUT%/}\" ]; then\n    exit 0\nfi\n\n# Skip during rebase/merge/cherry-pick\n# git exports GIT_DIR to hooks; the rev-parse fallback only runs when invoked by\n# hand (each git exec costs 1s+ on AV-scanned Windows machines).\nGIT_DIR=${GIT_DIR:-$(git rev-parse --git-dir 2>/dev/null)}\n[ -d \"$GIT_DIR/rebase-merge\" ] && exit 0\n[ -d \"$GIT_DIR/rebase-apply\" ] && exit 0\n[ -f \"$GIT_DIR/MERGE_HEAD\" ] && exit 0\n[ -f \"$GIT_DIR/CHERRY_PICK_HEAD\" ] && exit 0\n\n# Honor the same opt-out as post-commit: without this, GRAPHIFY_SKIP_HOOK=1\n# suppressed commit-triggered rebuilds but not branch-switch ones (#1809).\n[ \"${GRAPHIFY_SKIP_HOOK:-0}\" = \"1\" ] && exit 0\n\n"
        + _WORKTREE_GUARD
        + _TOPLEVEL_ANCHOR
        + _PYTHON_DETECT
        + "\n_GRAPHIFY_LOG=\"${HOME}/.cache/graphify-rebuild.log\"\nmkdir -p \"$(dirname \"$_GRAPHIFY_LOG\")\"\nexport GRAPHIFY_REBUILD_LOG=\"$_GRAPHIFY_LOG\"\necho \"[graphify] Branch switched - launching background rebuild (log: $_GRAPHIFY_LOG)\"\n"
        + _detached_launch(_REBUILD_BODY_CHECKOUT)
        + ")\n# graphify-checkout-hook-end\n";

    _MERGE_SCRIPT = "# graphify-merge-hook-start\n# Auto-rebuilds the knowledge graph (code only) after a merge, unscoped.\n# The git merge driver graphify registers for graph.json does a pure union\n# of both sides, which can resurrect a symbol that was deleted on one side\n# (#2418). Nothing else ever re-extracts that symbol's file unless it is\n# touched again, so the phantom node would otherwise persist indefinitely;\n# an unscoped rebuild here re-derives the graph from the merged tree and\n# drops it like any other stale node.\n# Installed by: graphify hook install\n(\n\n# Deterministic clustering: networkx louvain iterates string-keyed sets whose\n# order is randomized per-process by PYTHONHASHSEED, so community assignments\n# churn run-to-run. Pinning it makes graphify-out reproducible.\nexport PYTHONHASHSEED=0\n__VIZ_LIMIT_EXPORT__\n# Git for Windows/MSYS hooks can inherit fragile pipe handles from GUI clients\n# and agent shells. Keep hook-triggered rebuilds sequential by default there;\n# explicit GRAPHIFY_MAX_WORKERS still wins for users who want parallelism.\nif [ -n \"${WINDIR:-}\" ] || [ -n \"${MSYSTEM:-}\" ]; then\n    export GRAPHIFY_MAX_WORKERS=\"${GRAPHIFY_MAX_WORKERS:-1}\"\nfi\n\n# Only run if graphify-out/ exists (graph has been built before)\nif [ ! -d \"graphify-out\" ]; then\n    exit 0\nfi\n\n# git leaves MERGE_HEAD on disk while post-merge runs and deletes it only\n# after the hook returns, so it must not be checked here: that skipped every\n# merge that makes a merge commit (#4463). The checks below are belt and\n# braces for any quirk that lands here mid rebase or cherry-pick.\n# git exports GIT_DIR to hooks; the rev-parse fallback only runs when invoked\n# by hand (each git exec costs 1s+ on AV-scanned Windows machines).\nGIT_DIR=${GIT_DIR:-$(git rev-parse --git-dir 2>/dev/null)}\n[ -d \"$GIT_DIR/rebase-merge\" ] && exit 0\n[ -d \"$GIT_DIR/rebase-apply\" ] && exit 0\n[ -f \"$GIT_DIR/CHERRY_PICK_HEAD\" ] && exit 0\n\n# Honor the same opt out the commit and checkout hooks already respect.\n[ \"${GRAPHIFY_SKIP_HOOK:-0}\" = \"1\" ] && exit 0\n\n"
        + _WORKTREE_GUARD
        + _TOPLEVEL_ANCHOR
        + _PYTHON_DETECT
        + "\n_GRAPHIFY_LOG=\"${HOME}/.cache/graphify-rebuild.log\"\nmkdir -p \"$(dirname \"$_GRAPHIFY_LOG\")\"\nexport GRAPHIFY_REBUILD_LOG=\"$_GRAPHIFY_LOG\"\necho \"[graphify] Merge completed - launching background rebuild (log: $_GRAPHIFY_LOG)\"\n"
        + _detached_launch(_REBUILD_BODY_CHECKOUT)
        + ")\n# graphify-merge-hook-end\n";

    _REWRITE_SCRIPT = "# graphify-rewrite-hook-start\n# Auto-rebuilds the knowledge graph (code only) when a rebase finishes, including\n# `git pull --rebase`. post-commit cannot cover it: it skips while rebase-merge/\n# exists, and every replayed commit is made under it. git runs post-rewrite once,\n# after the last commit, with the tree in its final state (#4490).\n# Installed by: graphify hook install\n(\n\n# Deterministic clustering: networkx louvain iterates string-keyed sets whose\n# order is randomized per-process by PYTHONHASHSEED, so community assignments\n# churn run-to-run. Pinning it makes graphify-out reproducible.\nexport PYTHONHASHSEED=0\n__VIZ_LIMIT_EXPORT__\n# Git for Windows/MSYS hooks can inherit fragile pipe handles from GUI clients\n# and agent shells. Keep hook-triggered rebuilds sequential by default there;\n# explicit GRAPHIFY_MAX_WORKERS still wins for users who want parallelism.\nif [ -n \"${WINDIR:-}\" ] || [ -n \"${MSYSTEM:-}\" ]; then\n    export GRAPHIFY_MAX_WORKERS=\"${GRAPHIFY_MAX_WORKERS:-1}\"\nfi\n\n# git writes the old/new sha pairs of the rewritten commits to stdin; drain them so\n# git never blocks on a full pipe. Skipped when run by hand, where stdin is a terminal.\n[ -t 0 ] || cat >/dev/null\n\n# $1 is \"rebase\" or \"amend\". An amend already rebuilt through post-commit.\n[ \"${1:-}\" = \"rebase\" ] || exit 0\n\n# Only run if the output dir exists (graph has been built before). Resolve it from\n# GRAPHIFY_OUT like the rebuild body does (#1423), not a literal graphify-out/.\n_GFY_OUT=\"${GRAPHIFY_OUT:-graphify-out}\"\nif [ ! -d \"${_GFY_OUT%/}\" ]; then\n    exit 0\nfi\n\n# No rebase-merge/ or rebase-apply/ check, unlike post-commit and post-checkout: git\n# removes rebase-merge/ only after post-rewrite returns, so it is still on disk here\n# and would skip every rebase (the same trap as MERGE_HEAD in post-merge, #4463).\n\n# Honor the same opt out the commit and checkout hooks already respect.\n[ \"${GRAPHIFY_SKIP_HOOK:-0}\" = \"1\" ] && exit 0\n\n"
        + _WORKTREE_GUARD
        + _TOPLEVEL_ANCHOR
        + _PYTHON_DETECT
        + "\n_GRAPHIFY_LOG=\"${HOME}/.cache/graphify-rebuild.log\"\nmkdir -p \"$(dirname \"$_GRAPHIFY_LOG\")\"\nexport GRAPHIFY_REBUILD_LOG=\"$_GRAPHIFY_LOG\"\necho \"[graphify] Rebase completed - launching background rebuild (log: $_GRAPHIFY_LOG)\"\n"
        + _detached_launch(_REBUILD_BODY_CHECKOUT)
        + ")\n# graphify-rewrite-hook-end\n";
}

"""Load ``<root>/.graphifyrc``; the parser lives in :mod:`graphify.rcfile`.

    Kept as the hooks-side name so callers and tests need not move. Returns
    ``viz_node_limit`` (used here) alongside any other option the file sets.
    """
def _load_graphifyrc(`root: Path) -> dict;

"""Walk up to find .git directory."""
def _git_root(path: Path) -> Path | None;

with entry {
    _WINDOWS_DRIVE_RE = re.compile("^[A-Za-z]:[\\\\/]");
}

"""Raise if a hooks path looks like a Windows absolute path (#1385).

    On POSIX/WSL ``Path("C:\\Users\\...").is_absolute()`` is False, so an absolute
    Windows hooks path gets joined under the repo root and mkdir'd as a literal
    junk directory (backslashes and all), while install reports success and the
    real ``.git/hooks`` gets nothing. Fail loudly instead so the user can fix it.
    """
def _reject_windows_path(value: str, source: str) -> None;

"""True if `child` is `parent` or a path underneath it."""
def _is_within(child: Path, parent: Path) -> bool;

"""Resolve one ``git rev-parse`` path flag against ``root``.

    ``-c core.hooksPath=`` is not used: an empty value makes ``--git-path hooks``
    print ``./`` instead of the real hooks directory.
    """
def _rev_parse_path(`root: Path, flag: str) -> Path | None;

"""Git's own hooks directory, ignoring core.hooksPath.

    ``--git-path hooks`` follows core.hooksPath, so the default is derived from
    the common git dir. A linked worktree's hooks live in the main repo's
    ``.git/hooks``, which is outside the worktree root.
    """
def _builtin_hooks_dir(`root: Path) -> Path | None;

"""Allow in-repo hook dirs (Husky) and git's own hooks dir only.

    A core.hooksPath that resolves anywhere else is repository-controlled
    local config. Honoring it makes `hook install` write outside the repo (#3869).
    """
def _hooks_path_allowed(`root: Path, candidate: Path) -> bool;

"""Return the git hooks directory, respecting core.hooksPath if set (e.g. Husky).

    Asks git itself via ``rev-parse --git-path hooks`` rather than parsing
    ``.git/config`` with configparser: git legally allows duplicate keys and
    sections (VS Code writes such configs), which a strict configparser rejects
    with DuplicateOptionError/DuplicateSectionError, so every hook command
    printed a spurious "could not read core.hooksPath" warning (#1907). git
    resolves core.hooksPath, includeIf, and linked worktrees (where .git is a
    file, not a directory) correctly in one place. Genuinely corrupt configs
    are still surfaced: git itself fails on them, and its stderr is printed.
    """
def _hooks_dir(`root: Path) -> Path;

"""Install a single git hook, appending if an existing hook is present, or updating
    an existing graphify block in-place."""
def _install_hook(
    hooks_dir: Path, name: str, script: str, marker: str, marker_end: str = ""
) -> str;

"""Remove graphify section from a git hook using start/end markers."""
def _uninstall_hook(hooks_dir: Path, name: str, marker: str, marker_end: str) -> str;

"""Return sys.executable if its path is shell-safe, else an empty string.

    Applies the same allowlist used in _PYTHON_DETECT: rejects any character
    that is not a valid plain filesystem path character, preventing $(...),
    backtick, double-quote, semicolon, etc. from being injected into generated
    shell scripts or the merge-driver command line. The allowlist includes ':'
    and '\\' so Windows paths (C:\\...) are accepted, and a plain space so
    Windows profile paths (C:\\Users\\First Last\\...) are too — a space cannot
    start a substitution or a new command, and every consumer quotes the value:
    the hook scripts embed it as '$_PINNED' (single-quoted, then referenced as
    "$_PINNED") and _register_merge_driver double-quotes it (#2166). Before that
    a space rejected the whole path, so hooks installed under any Windows user
    whose profile name contains a space silently pinned nothing. An empty return
    means callers must fall back to the `graphify` launcher on PATH — safe
    degradation.
    """
def _pinned_python -> str;

with entry {
    _ROTATING_PREFIX_RE = re.compile("/snap/[^/]+/(\\d+|current)/");
}

"""True if `path` lives under a directory the packaging system rotates.

    A pin is only worth writing if it will still resolve tomorrow. An interpreter
    inside a snap revision will not: the revision number changes on update and the
    old tree is removed, which silently kills every hook pinned to it — observed
    across 15 repositories at once when an editor snap moved past its revision.

    Returning "" here is the documented safe degradation: the hook falls through to
    its other probes, including the uv-tools scan, which searches snap-confined
    homes too.
    """
def _is_rotating_prefix(path: str) -> bool;

"""The .gitattributes line assigning the graphify merge driver to graph.json.

    The graph lives under the configured output directory (graphify.paths,
    GRAPHIFY_OUT env override). gitattributes patterns are repo-relative, so an
    absolute output-dir override cannot be expressed there — fall back to the
    default name in that case.
    """
def _merge_attr_line -> str;

"""True if a (non-comment) `<...>graph.json ... merge=graphify` line exists."""
def _has_merge_attr(content: str) -> bool;

"""Register the graph.json union merge driver in git config + .gitattributes (#1902).

    README and CHANGELOG 0.7.0 document `graphify merge-driver` as being set up
    by `hook install`, but install never actually registered it. Writes go
    through `git config` (never hand-edit .git/config — in a linked worktree the
    effective config is not at root/.git/config). The interpreter is pinned the
    same way the hook scripts pin it, so the driver works even when the graphify
    launcher is not on PATH at merge time.
    """
def _register_merge_driver(`root: Path) -> str;

"""Remove the merge-driver git config keys and the .gitattributes line."""
def _unregister_merge_driver(`root: Path) -> str;

"""Report whether the merge driver is registered (config + gitattributes)."""
def _merge_driver_status(`root: Path) -> str;

"""Return the user-editable hooks directory.

    Husky 9 sets core.hooksPath to .husky/_ (wrapper scripts auto-generated by
    Husky), while user-editable hooks live in the parent .husky/. Return the
    parent when the resolved dir ends in '_' so install/status/uninstall target
    the correct location (#987).
    """
def _user_hooks_dir(hooks_dir: Path) -> Path;

glob path_default_: any;

with entry {
    path_default_ = Path(".");
}

"""Install graphify's post-commit, post-checkout, post-merge, and post-rewrite hooks in the nearest git repo."""
def install(path: Path = path_default_) -> str;

glob path_default__: any;

with entry {
    path_default__ = Path(".");
}

"""Remove graphify's post-commit, post-checkout, post-merge, and post-rewrite hooks."""
def uninstall(path: Path = path_default__) -> str;

with entry {
    _PINNED_LINE_RE = re.compile("^_PINNED='[^'\\n]*'$", re.MULTILINE);
    _VIZ_EXPORT_LINE_RE = re.compile("^export GRAPHIFY_VIZ_NODE_LIMIT=.*\\n", re.MULTILINE);
}

"""The graphify block in *text* with its per-install values blanked out, or
    None when the block has no end marker (install cannot rewrite those either)."""
def _comparable_block(text: str, marker: str, marker_end: str) -> str | None;

glob path_default___: any;

with entry {
    path_default___ = Path(".");
}

"""Check if graphify hooks are installed."""
def status(path: Path = path_default___) -> str;
