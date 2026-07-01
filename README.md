# Call Recorder

A local-only, open-source macOS menu-bar app for recording calls (mic + system audio via BlackHole), transcribing speech with OpenAI Whisper (auto-detect DE/EN), speaker diarization via Pyannote, and AI summarization via Ollama.

## Features

- **Menu bar app** — lives in your menu bar, ready when you need it
- **Manual recording** — click to start, click to stop
- **Audio input picker** — select any input device (microphone, BlackHole, Aggregate Device)
- **Local transcription** — runs OpenAI Whisper entirely on your Mac (no cloud)
- **Language auto-detect** — German and English are supported automatically
- **Speaker diarization** — Pyannote.audio identifies "who said what" (optional, requires Python)
- **AI summarization** — Ollama (qwen2.5, mistral, etc.) generates summary, decisions, team/personal to-dos
- **Call history** — browse past recordings with transcripts and summaries
- **Automatic audio conversion** — resamples recorded audio to Whisper's preferred 16 kHz mono format

## Requirements

- **macOS 14.0+** (Sonoma or later)
- **Apple Silicon Mac** (M1/M2/M3/M4) — Whisper runs fastest on Apple Silicon; Intel Macs may be slower
- **Xcode 15+** (to build from source)
- **BlackHole 2ch** virtual audio driver — required for capturing system audio (see Setup)
- **~1 GB free disk space** — for the Whisper model and temporary files

### Optional

- **Ollama** — for AI summarization (install via `brew install ollama`)
- **Python 3.9+** — for speaker diarization (see `Scripts/setup.sh`)
- **HuggingFace account** — for Pyannote model download

## Setup

### 1. Install BlackHole (for capturing call audio)

To record both your microphone **and** the other party's audio on a call, you need a virtual audio device.

1. Download [BlackHole 2ch](https://existential.audio/blackhole/) (free, open-source)
2. Run the installer
3. Open **Audio MIDI Setup** (macOS built-in app)
4. Click the **+** button → **Create Aggregate Device**
5. Check both your **physical microphone** and **BlackHole 2ch**
6. Name it "CallRecorder Input" (or any name you like)
7. Select the Aggregate Device in the app's **Audio Input** menu
8. Set **BlackHole 2ch** as your Mac's default **output** in **System Settings → Sound → Output**

> **Note:** Setting BlackHole as output means you won't hear audio through your speakers. During calls, route the call app (Zoom, Teams, etc.) to use a multi-output device or use a tool like [Loopback](https://rogueamoeba.com/loopback/) for more flexible routing.

### 2. Install Ollama (for AI summarization)

```bash
brew install ollama
ollama pull qwen2.5:7b    # or mistral:7b, mistral-nemo, etc.
ollama serve               # start in background
```

### 3. Setup Python Environment (for speaker diarization, optional)

```bash
bash Scripts/setup.sh
huggingface-cli login --token YOUR_HF_TOKEN
```

### 4. Build & Run

```bash
swift run CallRecorder
```

The app will appear as a microphone icon in your menu bar.

### 5. First Run

1. Click the menu bar icon → select **Start Recording** (or **Download Model** if required)
2. Grant **Microphone Access** when macOS prompts you
3. In **LLM Model** menu → **Connect/Refresh** → select a model (e.g. `qwen2.5:7b`)

### 6. Recording a Call

1. **Before the call:** Set your system audio output to **BlackHole 2ch** (or your Aggregate Device)
2. Select your Aggregate Device in the app's **Audio Input** menu
3. Click **Start Recording**
4. When the call ends, click **Stop & Process**
5. The app transcribes locally (~0.5× real-time), then runs diarization (if enabled) and summarization
6. View results in **Call History** — transcript with speaker labels + summary + to-dos

## Project Structure

```
CallRecorder/
├── Package.swift                              # Swift Package Manager manifest
├── Dependencies/whisper.spm/                  # whisper.cpp (local SPM package)
├── Scripts/
│   ├── diarize.py                             # Pyannote speaker diarization
│   ├── summarize.py                           # MLX-based LLM summarization (reference)
│   └── setup.sh                               # Python env setup
├── Sources/CallRecorder/
│   ├── App/
│   │   ├── CallRecorderApp.swift              # @main entry point, MenuBarExtra
│   │   └── AppState.swift                     # Observable state, recording orchestration
│   ├── Audio/
│   │   ├── AudioRecorder.swift                # AVAudioEngine capture → 16 kHz WAV
│   │   └── AudioDeviceManager.swift           # Core Audio input device enumeration
│   ├── Transcription/
│   │   ├── WhisperTranscriber.swift           # whisper.cpp C API bridge
│   │   └── ModelManager.swift                 # Download & cache Whisper GGML model
│   ├── SpeakerDiarization/
│   │   ├── SpeakerDiarizer.swift              # Python subprocess bridge (Pyannote)
│   │   └── DiarizationAligner.swift           # Merge Whisper + speaker segments
│   ├── LLM/
│   │   ├── OllamaManager.swift                # Ollama HTTP API client
│   │   ├── LLMSummarizer.swift                # Swift bridge for summarization
│   │   └── LLMModelManager.swift              # Model cache check (reference)
│   ├── Storage/
│   │   ├── DatabaseManager.swift              # SQLite persistence via SQLite.swift
│   │   └── CallRecord.swift                   # Data models
│   └── UI/
│       ├── CallHistoryView.swift              # List of past recordings
│       └── TranscriptDetailView.swift         # Full transcript + summary view
├── Sources/PoC/                               # CLI proof-of-concept tool
└── call-recorder-spec.md                      # Full technical specification
```

## Architecture

```
User clicks "Start Recording"
         │
         ▼
┌──────────────────────┐
│  AudioRecorder       │ → AVAudioEngine tap → 16 kHz mono WAV
│  (selected device)   │
└──────────────────────┘
         │
User clicks "Stop & Process"
         │
         ▼
┌──────────────────────┐
│  WhisperTranscriber  │ → whisper.cpp (local, GPU via Accelerate)
│  (auto-detect DE/EN) │    → timed transcript segments
└──────────────────────┘
         │
         ▼
┌──────────────────────┐
│  SpeakerDiarizer     │ → Pyannote.audio (Python subprocess)
│  (optional)          │    → speaker segments
└──────────────────────┘
         │
         ▼
┌──────────────────────┐
│  DiarizationAligner  │ → Merge transcript + speaker segments
└──────────────────────┘
         │
         ▼
┌──────────────────────┐
│  LLMSummarizer       │ → Ollama (local HTTP API)
│  (qwen2.5/mistral)   │    → summary + decisions + to-dos
└──────────────────────┘
         │
         ▼
┌──────────────────────┐
│  DatabaseManager     │ → SQLite.swift → persistent storage
│  (SQLite)            │
└──────────────────────┘
         │
         ▼
┌──────────────────────┐
│  SwiftUI Views       │ → MenuBarExtra + History window
└──────────────────────┘
```

## Dependencies

| Dependency | Source | License | Purpose |
|------------|--------|---------|---------|
| **whisper.cpp** | [ggerganov/whisper.cpp](https://github.com/ggerganov/whisper.cpp) | MIT | Local speech-to-text |
| **SQLite.swift** | [stephencelis/SQLite.swift](https://github.com/stephencelis/SQLite.swift) | MIT | Local database |
| **Ollama** | [ollama/ollama](https://github.com/ollama/ollama) | MIT | Local LLM inference |
| **Pyannote.audio** | [pyannote/pyannote-audio](https://github.com/pyannote/pyannote-audio) | MIT | Speaker diarization |
| **BlackHole 2ch** | [Existential Audio](https://existential.audio/blackhole/) | MIT | Virtual audio capture |

## Model

The app downloads the **Whisper Base** model (`ggml-base.bin`, ~150 MB) automatically on first run. It is stored in:

```
~/Library/Application Support/CallRecorder/models/ggml-base.bin
```

You can manually place a different model there (e.g., `ggml-small.bin` for higher accuracy) and the app will use it.

## Language Support

Whisper auto-detects the spoken language. German and English are fully supported; other languages may work but are not explicitly tested.

## Known Limitations

- **No real-time transcription** — transcription runs after recording stops
- **Audio output routing is manual** — BlackHole must be set as system output
- **Single-file processing** — one recording at a time
- **Speaker diarization requires Python setup** — see `Scripts/setup.sh`
- **LLM summarization requires Ollama** — install via brew + pull a model

## Next Steps (Phase 3)

- Speaker manual labeling (rename SPEAKER_00 → "Alice")
- To-do checkboxes & persistence
- Export to Markdown/PDF
- Real-time transcription
- Better audio routing wizard

## Privacy

- **Zero network calls** for AI processing (except the one-time model download)
- All audio and transcripts stay on your Mac in `~/Library/Application Support/CallRecorder/`
- If Ollama is used, summarization runs locally via its HTTP API on `127.0.0.1:11434`
- You are responsible for informing call participants that you are recording

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Microphone access denied" | Go to **System Settings → Privacy & Security → Microphone** and enable Call Recorder |
| "No audio in transcript" | Verify BlackHole is selected as output and the Aggregate Device is selected as input |
| "Transcription is slow" | Normal on CPU; Apple Silicon GPU used automatically |
| "Model download failed" | Manually download from [HuggingFace](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin) → `~/Library/Application Support/CallRecorder/models/` |
| "No Ollama models show" | Run `ollama serve` in background, then click "Connect/Refresh" in the menu |
| "Ollama summary missing" | Check `ollama serve` is running; model must be pulled via `ollama pull` |
| "Speaker labels are all SPEAKER_00" | Diarization optional — run `bash Scripts/setup.sh` + `huggingface-cli login` |

## Development

```bash
# Build & run the menu bar app
swift run CallRecorder

# Build & run the CLI PoC (for testing without UI)
swift run PoC <model-path>
```

Built with **Swift Package Manager** and **SwiftUI** for macOS 14+.
