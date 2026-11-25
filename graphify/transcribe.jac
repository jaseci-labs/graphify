import from __future__ { annotations }
import importlib;
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
def is_url(path: str) -> bool;
def download_audio(url: str, output_dir: Path) -> Path;
def build_whisper_prompt(god_nodes: list[dict]) -> str;
def transcribe(
    video_path: Path | str,
    output_dir: Path | None = None,
    initial_prompt: str | None = None,
    force: bool = False,
) -> Path;
def transcribe_all(
    video_files: list[str], output_dir: Path | None = None, initial_prompt: str | None = None
) -> list[str];
