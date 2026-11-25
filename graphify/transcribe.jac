import from __future__ { annotations }

import os;

import from pathlib { Path }

glob VIDEO_EXTENSIONS: any = {
    ".mp4",
    ".mov",
    ".webm",
    ".mkv",
    ".avi",
    ".m4v",
    ".mp3",
    ".wav",
    ".m4a",
    ".ogg",
};

glob URL_PREFIXES: any = ("http://", "https://", "www.");

glob _DEFAULT_MODEL: any = "base";

glob _TRANSCRIPTS_DIR: any;

glob _FALLBACK_PROMPT: any;

with entry {
    _TRANSCRIPTS_DIR = `str(_out_path("transcripts"));
    _FALLBACK_PROMPT = "Use proper punctuation and paragraph breaks.";
}

def _model_name -> str;

def _get_whisper -> any;

def _get_yt_dlp -> any;

"""Return True if the string looks like a URL rather than a file path."""
def is_url(path: str) -> bool;

"""Download audio-only stream from a URL using yt-dlp.

    Returns the path to the downloaded audio file (.m4a or .opus).
    Uses cached file if already downloaded.
    """
def download_audio(url: str, output_dir: Path) -> Path;

"""Build a domain hint for Whisper from god nodes extracted from the corpus.

    Formats the top god node labels into a topic string for Whisper.
    The coding agent (Claude Code, Codex, etc.) generates the actual one-sentence
    domain hint from these labels and passes it via GRAPHIFY_WHISPER_PROMPT or
    as initial_prompt — no separate API call needed here.
    """
def build_whisper_prompt(god_nodes: list[dict]) -> str;

"""Transcribe a video/audio file or URL to a .txt transcript.

    If video_path is a URL, audio is downloaded first via yt-dlp.
    Returns the path to the saved transcript file.
    Uses cached transcript if it exists unless force=True.

    initial_prompt: domain hint for Whisper (built from corpus god nodes).
    force: re-transcribe even if transcript already exists.
    """
def transcribe(
    video_path: Path | str,
    output_dir: Path | None = None,
    initial_prompt: str | None = None,
    force: bool = False,
) -> Path;

"""Transcribe a list of video/audio files or URLs, return paths to transcript .txt files.

    Already-transcribed files are returned from cache instantly.
    initial_prompt is shared across all files — built once from corpus god nodes.
    """
def transcribe_all(
    video_files: list[str], output_dir: Path | None = None, initial_prompt: str | None = None
) -> list[str];
