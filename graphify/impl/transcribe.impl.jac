impl _model_name -> str {
    return os.environ.get("GRAPHIFY_WHISPER_MODEL", _DEFAULT_MODEL);
}

impl _get_whisper -> any {
    try {
        import from faster_whisper { WhisperModel }
        return WhisperModel;
    } except ImportError as exc {
        raise ImportError(
            "Video transcription requires faster-whisper. Run: pip install 'graphifyy[video]'"
        ) from exc;
    }
}

impl _get_yt_dlp -> any {
    try {
        import yt_dlp;
        return yt_dlp;
    } except ImportError as exc {
        raise ImportError(
            "YouTube/URL download requires yt-dlp. Run: pip install 'graphifyy[video]'"
        ) from exc;
    }
}

impl is_url(path: str) -> bool {
    return `any(path.startswith(p) for p in URL_PREFIXES);
}

impl download_audio(url: str, output_dir: Path) -> Path {
    validate_url: any = importlib.import_module("graphify.security").validate_url;
    validate_url(url);
    yt_dlp: any = _get_yt_dlp();
    output_dir.mkdir(parents=True, exist_ok=True);
    import hashlib;
    url_hash: any = hashlib.sha1(url.encode(), usedforsecurity=False).hexdigest()[:12];
    out_template: any = `str(output_dir / f"yt_{url_hash}.%(ext)s");
    ext: any;
    for ext in (".m4a", ".opus", ".mp3", ".ogg", ".wav", ".webm") {
        candidate: any = output_dir / f"yt_{url_hash}{ext}";
        if candidate.exists() {
            print(f"  cached audio: {candidate.name}");
            return candidate;
        }
    }

    ydl_opts: any = {
        "format": "bestaudio[ext=m4a]/bestaudio/best",
        "outtmpl": out_template,
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
        "postprocessors": [],
    };

    print(f"  downloading audio: {url[:80]} ...", flush=True);
    ydl: any;
    with yt_dlp.YoutubeDL(ydl_opts) as ydl {
        info: any = ydl.extract_info(url, download=True);
        ext = info.get("ext", "m4a");
        downloaded: any = output_dir / f"yt_{url_hash}.{ext}";
        if not downloaded.exists() {
            for p in output_dir.glob(f"yt_{url_hash}.*") {
                downloaded = p;
                break;
            }
        }
        return downloaded;
    }
}

impl build_whisper_prompt(god_nodes: list[dict]) -> str {
    if not god_nodes {
        return _FALLBACK_PROMPT;
    }

    `override: any = os.environ.get("GRAPHIFY_WHISPER_PROMPT");
    if `override {
        return `override;
    }

    labels: any = [n.get("label", "") for n in god_nodes[:10] if n.get("label")];
    if not labels {
        return _FALLBACK_PROMPT;
    }

    topics: any = ", ".join(labels[:5]);
    return f"Technical discussion about {topics}. Use proper punctuation and paragraph breaks.";
}

impl transcribe(
    video_path: Path | str,
    output_dir: Path | None = None,
    initial_prompt: str | None = None,
    force: bool = False,
) -> Path {
    out_dir: any = Path(output_dir) if output_dir else Path(_TRANSCRIPTS_DIR);
    out_dir.mkdir(parents=True, exist_ok=True);

    if is_url(`str(video_path)) {
        audio_path: any = download_audio(`str(video_path), out_dir / "downloads");
    } else {
        audio_path = Path(video_path);
    }

    transcript_path: any = out_dir / (audio_path.stem + ".txt");
    if transcript_path.exists() and not force {
        return transcript_path;
    }

    WhisperModel: any = _get_whisper();
    model_name: any = _model_name();
    prompt: any = initial_prompt or _FALLBACK_PROMPT;

    print(f"  transcribing {audio_path.name} (model={model_name}) ...", flush=True);
    model: any = WhisperModel(model_name, device="cpu", compute_type="int8");
    segments: any;
    info: any;
    (segments, info) = model.transcribe(
        `str(audio_path), beam_size=5, initial_prompt=prompt
    ) as any;

    lines: any = [segment.text.strip() for segment in segments if segment.text.strip()];
    transcript: any = "\n".join(lines);

    transcript_path.write_text(transcript, encoding="utf-8");
    lang: any = info.language if hasattr(info, "language") else "unknown";
    print(f"  transcript saved -> {transcript_path} (lang={lang}, {len(lines)} segments)");
    return transcript_path;
}

impl transcribe_all(
    video_files: list[str], output_dir: Path | None = None, initial_prompt: str | None = None
) -> list[str] {
    if not video_files {
        return [];
    }

    transcript_paths: any = [];
    for vf in video_files {
        try {
            t: any = transcribe(vf, output_dir, initial_prompt=initial_prompt);
            transcript_paths.append(`str(t));
        } except Exception as exc {
            print(f"  warning: could not transcribe {vf}: {exc}");
        }
    }
    return transcript_paths;
}
