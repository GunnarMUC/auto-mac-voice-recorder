# Open Points

## Phase 3 (Current)

- [x] **Better language detection (DE/EN)** — Model-Picker für `ggml-base.bin` und `ggml-small.bin`. Small model (~466 MB) verbessert DE/EN-Erkennung.
- [x] **Speaker manual labeling** — SPEAKER_00 → freier Name. Editierbar im Transcript-View, persistiert in DB.
- [x] **To-Do Checkboxen** — Action Items mit ✓ und Durchstreichen, persistiert in DB.
- [x] **Export to Markdown** — Exportiert Transcript + Summary + ToDos als .md auf den Desktop.

## Phase 4 (Future)

- [ ] **Real-time transcription** — Transcribe audio while recording, not just after stopping.
- [ ] **Audio routing wizard** — Auto-detect input devices and guide user through BlackHole + Aggregate Device setup.
- [ ] **Export to PDF** — In addition to Markdown export, add PDF export with proper formatting.
- [ ] **Auto-delete old audio files** — Configurable storage limit with automatic cleanup of old recordings.
- [ ] **Settings panel** — Dedicated settings window for model selection (Whisper, Pyannote, Ollama), storage directory, device management.
- [ ] **Calendar integration** — Suggest recording based on calendar events.

## Known Issues

- **Menu bar UI fragility** — MenuBarExtra with complex view hierarchies can cause rendering issues. Current inline structure avoids crashes but limits UI complexity.
- **Core ML model not found** — Whisper tries to load a Core ML encoder model but it's not bundled. Transcription works via Accelerate/GPU without it.
- **Ollama generates raw JSON only** — Performs well with `qwen2.5:7b` and `mistral:7b`, but JSON output quality varies by model. Larger models (14b) may give better results.
- **Python dependencies (Pyannote)** — Speaker diarization requires Python 3.9+ + torch + pyannote.audio, setup via `Scripts/setup.sh`. Notarizing the app with bundled Python is complex — better for advanced users.
