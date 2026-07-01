# Open Points

## Phase 3 (Completed)

- [x] Better language detection (DE/EN) — Model-Picker for `ggml-base.bin` / `ggml-small.bin`
- [x] Speaker manual labeling — SPEAKER_00 → free name, persisted in DB
- [x] To-Do Checkboxen — Action Items with ✓ and strikethrough
- [x] Export to Markdown — Transcript + Summary + ToDos as .md on Desktop

## Phase 4 (Completed except Real-time + Calendar)

- [x] Export to PDF — CoreGraphics + HTML rendering, saves to Desktop
- [x] Auto-delete old audio files — Configurable retention (7/30/90 days), manual cleanup
- [x] Audio routing wizard — BlackHole detection + setup instructions in Settings
- [x] Settings panel — 4 tabs: General, Audio, Models, Storage
- [ ] Real-time transcription — Transcribe while recording (complex)
- [ ] Calendar integration — EventKit binding

## Known Issues

- **Menu bar UI fragility** — MenuBarExtra with complex view hierarchies can cause rendering issues. Current inline structure avoids crashes but limits UI complexity.
- **Core ML model not found** — Whisper tries to load a Core ML encoder model but it's not bundled. Transcription works via Accelerate/GPU without it.
- **Ollama JSON output quality varies** — Good with `qwen2.5:7b` / `mistral:7b`, larger models (14b) may give better results.
- **Python dependencies (Pyannote)** — Speaker diarization requires Python 3.9+ + torch + pyannote.audio. Setup via `Scripts/setup.sh`.
