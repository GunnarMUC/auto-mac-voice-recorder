[![License](https://img.shields.io/badge/License-Apache%202.0-blue)](LICENSE)n

# Call Recorder

A local-only, open-source macOS menu-bar app for recording calls (mic + system audio via BlackHole), transcribing speech with OpenAI Whisper (auto-detect DE/EN), speaker diarization via Pyannote, and AI summarization via Ollama.

## Features

- **Menu bar app** — lives in your menu bar, ready when you need it
- **Manual recording** — click to start, click to stop
- **Audio input picker** — select any input device (microphone, BlackHole, Aggregate Device)
- **Whisper model picker** — choose between Base (141 MB, fast) and Small (466 MB, accurate) models
- **Local transcription** — runs OpenAI Whisper entirely on your Mac (no cloud)
- **Language auto-detect** — German and English are supported automatically
- **Speaker diarization** — Pyannote.audio identifies "who said what" (optional, requires Python)
- **Speaker labeling** — rename SPEAKER_00 to real names, persisted per call
- **AI summarization** — Ollama (qwen2.5, mistral, etc.) generates summary, decisions, team/personal to-dos
- **To-Do management** — checkable action items with completion tracking
- **Call history** — browse past recordings with transcripts, summaries, and speaker labels
- **Export** — Markdown + PDF export to Desktop
- **Settings panel** — device management, model selection, storage cleanup, BlackHole setup guide
- **Auto-cleanup** — configurable auto-delete of old audio files (7/30/90 days)

## Requirements

- **macOS 14.0+** (Sonoma or later)
- **Apple Silicon Mac** (M1/M2/M3/M4)
- **Xcode 15+** (to build from source)
- **BlackHole 2ch** virtual audio driver — for capturing system audio
- **~1 GB free disk space** — for the Whisper model and temporary files

### Optional

- **Ollama** — for AI summarization (`brew install ollama`)
- **Python 3.9+** — for speaker diarization (`Scripts/setup.sh`)

## Quick Start

```bash
# 1. Install Ollama (optional, for AI summaries)
brew install ollama && ollama pull qwen2.5:7b && ollama serve

# 2. Build & run
swift run CallRecorder
```

The app appears as a microphone icon in your menu bar.

## Menu Structure

```
Audio Input ▶      → Select microphone or Aggregate Device
Whisper Model ▶    → Base (141 MB) / Small (466 MB) + Download
LLM Model ▶        → Select Ollama model for summaries
─────────────────────────
🔴 Start Recording / Stop & Process
─────────────────────────
📋 Call History     → Transcript + Summary + Speaker Labels + To-Dos + Export
⚙️ Settings         → General / Audio / Models / Storage
─────────────────────────
✕ Quit
```

## Features in Detail

### Recording

1. Select your input device (Audio Input menu)
2. Click **Start Recording**
3. Click **Stop & Process**
4. Whisper transcribes (~0.5× real-time), then diarization and summarization run (if available)
5. View results in **Call History**

### Transcription

- **Base model** (~141 MB): fast, good enough for English
- **Small model** (~466 MB): better DE/EN accuracy, recommended
- Language auto-detection with timestamps

### Speaker Diarization (optional)

Requires Python environment: `bash Scripts/setup.sh` + `huggingface-cli login`

After diarization, each transcript segment gets a speaker label (SPEAKER_00, etc.). Rename speakers directly in the transcript view.

### AI Summarization (via Ollama)

Requires Ollama running with at least one model pulled. The LLM analyzes the transcript and generates:

- **Summary** — 3-5 sentence overview
- **Decisions** — key decisions made
- **Team To-Dos** — shared action items
- **Per-Person To-Dos** — tasks assigned to each speaker

To-do items are checkable directly in the UI and persist across app restarts.

### Export

- **Markdown** — full transcript with summary, decisions, to-dos
- **PDF** — formatted document saved to Desktop

### Settings Panel

| Tab | Content |
|-----|---------|
| General | Audio cleanup (7/30/90 days), BlackHole detection + setup guide |
| Audio | Input device selection and refresh |
| Models | Whisper model switch/download, Ollama model selection |
| Storage | Audio folder size, database size, manual cleanup |

## Project Structure

```
CallRecorder/
├── Package.swift                              # Swift Package Manager manifest
├── Dependencies/whisper.spm/                  # whisper.cpp (local SPM package)
├── Scripts/
│   ├── diarize.py                             # Pyannote speaker diarization
│   ├── summarize.py                           # MLX-based summarization (reference)
│   └── setup.sh                               # Python env setup
├── Sources/CallRecorder/
│   ├── App/
│   │   ├── CallRecorderApp.swift              # @main entry point, MenuBarExtra
│   │   └── AppState.swift                     # Observable state, orchestration
│   ├── Audio/
│   │   ├── AudioRecorder.swift                # AVAudioEngine → 16 kHz WAV
│   │   └── AudioDeviceManager.swift           # Core Audio device enumeration
│   ├── Transcription/
│   │   ├── WhisperTranscriber.swift           # whisper.cpp C API bridge
│   │   └── ModelManager.swift                 # Multi-model download/cache (base, small)
│   ├── SpeakerDiarization/
│   │   ├── SpeakerDiarizer.swift              # Python subprocess (Pyannote)
│   │   └── DiarizationAligner.swift           # Whisper + speaker segment merge
│   ├── LLM/
│   │   ├── OllamaManager.swift                # Ollama HTTP API client
│   │   ├── LLMSummarizer.swift                # Summarization bridge
│   │   └── LLMModelManager.swift              # MLX model cache (reference)
│   ├── Storage/
│   │   ├── DatabaseManager.swift              # SQLite.swift persistence
│   │   └── CallRecord.swift                   # Data models (Call, Segment, ActionItem)
│   └── UI/
│       ├── CallHistoryView.swift              # Recording list
│       ├── TranscriptDetailView.swift         # Transcript + summary + to-dos + export
│       └── SettingsView.swift                 # Settings panel (4 tabs)
├── Sources/PoC/                               # CLI proof-of-concept
├── TODO.md                                    # Open points and known issues
└── call-recorder-spec.md                      # Full technical specification
```

## Dependencies

| Dependency | Source | License | Purpose |
|------------|--------|---------|---------|
| **whisper.cpp** | [ggerganov/whisper.cpp](https://github.com/ggerganov/whisper.cpp) | MIT | Local speech-to-text |
| **SQLite.swift** | [stephencelis/SQLite.swift](https://github.com/stephencelis/SQLite.swift) | MIT | Local database |
| **Ollama** | [ollama/ollama](https://github.com/ollama/ollama) | MIT | Local LLM inference |
| **Pyannote.audio** | [pyannote/pyannote-audio](https://github.com/pyannote/pyannote-audio) | MIT | Speaker diarization |
| **BlackHole 2ch** | [Existential Audio](https://existential.audio/blackhole/) | MIT | Virtual audio capture |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Microphone access denied" | System Settings → Privacy → Microphone → enable Call Recorder |
| "No audio in transcript" | Verify BlackHole is set as output, Aggregate Device as input |
| "Transcription is slow" | Normal on CPU; Apple Silicon GPU used automatically |
| DE/EN mix-up | Switch to Small model in Whisper Model menu (better accuracy) |
| "No Ollama models show" | Run `ollama serve` in background, click Refresh in menu |
| "Ollama summary missing" | Check `ollama serve` is running; model pulled via `ollama pull` |
| "Speaker labels all SPEAKER_00" | Diarization requires Python setup: `bash Scripts/setup.sh` |

## Privacy

- **Zero network calls** for AI processing (except one-time model download)
- All audio, transcripts, and summaries stay on your Mac in `~/Library/Application Support/CallRecorder/`
- Ollama runs on `127.0.0.1:11434` — no data leaves your machine
- You are responsible for informing call participants that you are recording

## Development

```bash
swift run CallRecorder    # Menu bar app
swift run PoC <model>     # CLI tool for testing
```

Built with **Swift Package Manager** and **SwiftUI** for macOS 14+.
