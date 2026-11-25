import from __future__ { annotations }
import importlib;
import json;

import os;

import re;

import subprocess;

import sys;

import from collections { defaultdict }

import from concurrent.futures { ThreadPoolExecutor, as_completed }

import from dataclasses { dataclass, field }

import from datetime { datetime, timezone }

import from pathlib { Path }

import from typing { TYPE_CHECKING }

glob _USAGE: str = """graphify prs — graph-aware PR dashboard.

Fast terminal overview of open PRs with CI/review state, worktree mapping,
and optional graph-impact analysis (which communities a PR touches) and
Opus-powered triage ranking.

Usage:
  graphify prs                   # dashboard of all open PRs
  graphify prs <number>          # deep dive on one PR
  graphify prs --triage          # Opus ranks your review queue
  graphify prs --worktrees       # show worktree → branch → PR mapping
  graphify prs --conflicts       # PRs sharing graph communities (merge-order risk)
  graphify prs --base <branch>   # filter to PRs targeting this base (default: v8)
""";

glob _NO_COLOR: any;

glob _ANSI_RE: any;

glob _STATUS_ORDER: any;

glob _STALE_DAYS: any;

glob _CI_FAILURE_CONCLUSIONS: any;

glob _CI_PENDING_STATUSES: any;

glob _PR_JSON_FIELDS: any;

glob _TRIAGE_MODEL_DEFAULTS: dict[str, str];

with entry {
    _NO_COLOR = not sys.stdout.isatty() or os.environ.get("NO_COLOR");
}

def _c(code: str, text: str) -> str;

def green(t: str) -> str;

def red(t: str) -> str;

def yellow(t: str) -> str;

def cyan(t: str) -> str;

def bold(t: str) -> str;

def dim(t: str) -> str;

with entry {
    _ANSI_RE = re.compile("\\033\\[[0-9;]*m");
}

def _pad(s: str, width: int) -> str;

@dataclass
class PRInfo {
    has number: int;

    has title: str;

    has branch: str;

    has base_branch: str;

    has author: str;

    has is_draft: bool;

    has review_decision: str;

    has ci_status: str;

    has updated_at: datetime;

    has expected_base: str = "main";

    has worktree_path: str | None = None;

    has communities_touched: list[int] = field(default_factory=list[any]);

    has nodes_affected: int = 0;

    has files_changed: list[str] = field(default_factory=list[any]);

    has status: str {
        getter {
            return _classify(self, self.expected_base);
        }
    }

    has days_old: int {
        getter {
            return (datetime.now(timezone.utc) - self.updated_at).days;
        }
    }

    has blast_radius: str {
        getter {
            if not self.nodes_affected {
                return "";
            }
            n: any = self.nodes_affected;
            c: any = len(self.communities_touched);
            return format(n, "")
                + " node"
                + format("s" if n != 1 else "", "")
                + " / "
                + format(c, "")
                + " communit"
                + format("ies" if c != 1 else "y", "");
        }
    }
}

with entry {
    _STATUS_ORDER = [
        "WRONG-BASE",
        "CI-FAIL",
        "CHANGES-REQ",
        "DRAFT",
        "STALE",
        "PENDING",
        "APPROVED",
        "READY",
    ];
    _STALE_DAYS = 14;
}

def _classify(pr: "PRInfo", base: str = "v8") -> str;

def _status_color(status: str) -> str;

def _ci_icon(status: str) -> str;

def _gh(*args_: str) -> list | dict | None;
def _detect_default_branch(repo: str | None = None) -> str;

with entry {
    _CI_FAILURE_CONCLUSIONS = frozenset({
        "FAILURE",
        "CANCELLED",
        "TIMED_OUT",
        "ACTION_REQUIRED",
        "STARTUP_FAILURE",
    });
    _CI_PENDING_STATUSES = frozenset({"REQUESTED", "QUEUED", "IN_PROGRESS", "WAITING", "PENDING"});
}

def _parse_ci(rollup: list) -> str;

with entry {
    _PR_JSON_FIELDS = "number,title,state,headRefName,baseRefName,author,isDraft,reviewDecision,statusCheckRollup,updatedAt";
}

def _parse_pr_dict(item: dict, expected_base: str) -> PRInfo;

def fetch_prs(repo: str | None = None, base: str | None = None, limit: int = 50) -> list[PRInfo];

def fetch_pr(number: int, repo: str | None = None, base: str | None = None) -> PRInfo | None;

def fetch_pr_files(number: int, repo: str | None = None) -> list[str];
def _path_match(graph_src: str, pr_file: str) -> bool;
def compute_pr_impact(files: list[str], G: "nx.Graph") -> tuple[list[int], int];
def format_prs_text(prs: list["PRInfo"], base: str) -> str;
def fetch_worktrees -> dict[str, str];

def _load_graph_json(graph_path: Path) -> dict | None;
def build_community_labels(data: dict, top_n: int = 4) -> dict[int, list[str]];
def attach_graph_impact(
    prs: list[PRInfo], graph_path: Path, repo: str | None = None, include_wrong_base: bool = False
) -> dict[int, list[str]];

def _truncate(s: str, n: int) -> str;

def render_dashboard(prs: list[PRInfo], base: str = "v8", show_wrong_base: bool = False);

def render_worktrees(prs: list[PRInfo], worktrees: dict[str, str]);

def render_conflicts(
    prs: list[PRInfo], base: str = "v8", community_labels: dict[int, list[str]] | None = None
);

def render_pr_detail(pr: PRInfo, repo: str | None = None);

with entry {
    _TRIAGE_MODEL_DEFAULTS = {
        "claude": "claude-opus-4-7",
        "kimi": "kimi-k2.6",
        "openai": "gpt-4.1-mini",
        "gemini": "gemini-3-flash-preview",
    };
}

def _resolve_triage_backend -> tuple[str, str];

def triage_with_opus(prs: list[PRInfo], base: str);

def cmd_prs(argv: list[str]);
