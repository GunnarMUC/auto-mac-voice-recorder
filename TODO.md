# Open Points

## Phase 3 (Current)

- [x] **Better language detection (DE/EN)** — Model-Picker für `ggml-base.bin` und `ggml-small.bin`. Small model (~466 MB) verbessert DE/EN-Erkennung.
- [x] **Speaker manual labeling** — SPEAKER_00 → freier Name. Editierbar im Transcript-View, persistiert in DB.
- [x] **To-Do Checkboxen** — Action Items mit ✓ und Durchstreichen, persistiert in DB.
- [x] **Export to Markdown** — Exportiert Transcript + Summary + ToDos als .md auf den Desktop.

## Phase 4 (Partial)

- [x] **Export to PDF** — PDF-Generierung via CoreGraphics + HTML-Rendering, speichert auf Desktop.
- [x] **Auto-delete old audio files** — Konfigurierbare Aufbewahrungsdauer (7/30/90 Tage), manueller Cleanup-Button.
- [x] **Audio routing wizard** — BlackHole-Erkennung + Setup-Anleitung im Settings-Panel.
- [x] **Settings panel** — Fenster mit 4 Tabs: General (Cleanup, BlackHole), Audio (Device-Auswahl), Models (Whisper + LLM), Storage (Nutzung).
- [ ] **Real-time transcription** — Audio während Aufnahme transkribieren (komplex, später).
- [ ] **Calendar integration** — EventKit-Kalender-Anbindung (später).

## Known Issues

- **Menu bar UI fragility** — MenuBarExtra with complex view hierarchies can cause rendering issues. Current inline structure avoids crashes but limits UI complexity.
- **Core ML model not found** — Whisper tries to load a Core ML encoder model but it's not bundled. Transcription works via Accelerate/GPU without it.
- **Ollama generates raw JSON only** — Performs well with `qwen2.5:7b` and `mistral:7b`, but JSON output quality varies by model. Larger models (14b) may give better results.
- **Python dependencies (Pyannote)** — Speaker diarization requires Python 3.9+ + torch + pyannote.audio, setup via `Scripts/setup.sh`. Notarizing the app with bundled Python is complex — better for advanced users.
