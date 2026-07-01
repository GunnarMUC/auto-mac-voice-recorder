# Call Recorder — Phase 1

A local-only, open-source macOS menu-bar app for recording calls, transcribing speech with OpenAI Whisper, and storing results in a local SQLite database.

## Features (Phase 1)

- **Menu bar app** — lives in your menu bar, ready when you need it
- **Manual recording** — click to start, click to stop
- **Local transcription** — runs OpenAI Whisper entirely on your Mac (no cloud)
- **Call history** — browse past recordings with transcripts
- **Automatic audio conversion** — resamples recorded audio to Whisper's preferred 16 kHz mono format

## Requirements

- **macOS 14.0+** (Sonoma or later)
- **Apple Silicon Mac** (M1/M2/M3/M4) — Whisper runs fastest on Apple Silicon; Intel Macs may be slower
- **Xcode 15+** (to build from source)
- **BlackHole 2ch** virtual audio driver — required for capturing system audio (see Setup)
- **~1 GB free disk space** — for the Whisper model and temporary files

## Setup

### 1. Install BlackHole (for capturing call audio)

To record both your microphone **and** the other party's audio on a call, you need a virtual audio device.

**Option A — Installer (recommended)**
1. Download [BlackHole 2ch](https://existential.audio/blackhole/) (free, open-source)
2. Run the installer
3. Open **Audio MIDI Setup** (macOS built-in app)
4. Click the **+** button → **Create Aggregate Device**
5. Check both your **physical microphone** and **BlackHole 2ch**
6. Name it "CallRecorder Input" (or any name you like)
7. Set the **Aggregate Device** as your Mac's default **input** in **System Settings → Sound → Input**
8. Set **BlackHole 2ch** as your Mac's default **output** in **System Settings → Sound → Output**

> **Note:** Setting BlackHole as output means you won't hear audio through your speakers. During calls, route the call app (Zoom, Teams, etc.) to use a multi-output device or use a tool like [Loopback](https://rogueamoeba.com/loopback/) for more flexible routing. For Phase 1, the simplest workflow is: set output to BlackHole during the call, record, then switch back to your speakers after.

**Option B — For testing without BlackHole**
- You can test the app by recording only your microphone. Set any microphone as the input and speak. The transcription will only capture your side of the conversation, but it's enough to verify the pipeline works.

### 2. Build the App

```bash
# Clone or navigate to the project directory
cd CallRecorder

# Open in Xcode
open Package.swift
```

In Xcode:
1. Select the **CallRecorder** scheme
2. Choose **My Mac** as the target
3. Press **Cmd+R** to build and run

### 3. First Run

1. The app will appear as a **microphone icon** in your menu bar
2. Click it to open the recording panel
3. The app will prompt you to **download the Whisper model** (~150 MB). Click **Download Model** and wait
4. Once the model is ready, the **Start Recording** button becomes active
5. Grant **Microphone Access** when macOS prompts you

### 4. Recording a Call

1. **Before the call:** Set your system audio output to **BlackHole 2ch** (or your Aggregate Device)
2. **Start the call** in Zoom, Teams, FaceTime, or any other app
3. Click the **Call Recorder** menu bar icon → **Start Recording**
4. Talk normally — the app records everything going into the microphone input (which includes both your mic and the system audio via the Aggregate Device)
5. When the call ends, click **Stop Recording**
6. The app will **transcribe** the audio locally. This takes roughly **0.5×–1× real-time** (a 10-minute call takes 5–10 minutes to transcribe)
7. Once done, view the transcript in **Call History**

## Project Structure

```
CallRecorder/
├── Package.swift                          # Swift Package Manager manifest
├── Sources/CallRecorder/
│   ├── App/
│   │   ├── CallRecorderApp.swift          # @main entry point, MenuBarExtra
│   │   ├── ContentView.swift              # Navigation stack wrapper
│   │   └── AppState.swift                 # Shared state, recording orchestration
│   ├── Audio/
│   │   ├── AudioRecorder.swift            # AVAudioRecorder wrapper (raw capture)
│   │   └── AudioFormatConverter.swift     # Resample to 16 kHz mono WAV for Whisper
│   ├── Transcription/
│   │   ├── WhisperTranscriber.swift       # whisper.cpp C API bridge
│   │   └── ModelManager.swift             # Download & cache Whisper GGML model
│   ├── Storage/
│   │   ├── DatabaseManager.swift          # SQLite persistence layer
│   │   └── CallRecord.swift               # Data model
│   └── UI/
│       ├── RecordingPanel.swift           # Main menu-bar window (start/stop/download)
│       ├── CallHistoryView.swift          # List of past recordings
│       ├── TranscriptDetailView.swift     # Full transcript viewer
│       └── SettingsView.swift             # Model status & app info
```

## Architecture

```
User clicks "Start Recording"
         │
         ▼
┌────────────────────┐
│  AudioRecorder     │  → AVAudioRecorder → raw CAF (48 kHz, stereo)
│  (Core Audio)      │
└────────────────────┘
         │
User clicks "Stop"
         │
         ▼
┌────────────────────┐
│ AudioFormatConverter│ → AVAudioConverter → 16 kHz mono float32 WAV
│ (AVFoundation)     │
└────────────────────┘
         │
         ▼
┌────────────────────┐
│  WhisperTranscriber│ → whisper.cpp (local, GPU-accelerated)
│  (C API via SPM)   │    → timed transcript text
└────────────────────┘
         │
         ▼
┌────────────────────┐
│  DatabaseManager   │ → SQLite.swift → persistent storage
│  (SQLite)          │
└────────────────────┘
         │
         ▼
┌────────────────────┐
│  SwiftUI Views     │ → menu bar window with transcript
└────────────────────┘
```

## Dependencies

| Dependency | Source | License | Purpose |
|------------|--------|---------|---------|
| **whisper.cpp** | [ggerganov/whisper.cpp](https://github.com/ggerganov/whisper.cpp) | MIT | Local speech-to-text |
| **SQLite.swift** | [stephencelis/SQLite.swift](https://github.com/stephencelis/SQLite.swift) | MIT | Local database |
| **BlackHole 2ch** | [Existential Audio](https://existential.audio/blackhole/) | MIT | Virtual audio capture |

## Model

The app downloads the **Whisper Base** model (`ggml-base.bin`, ~150 MB) automatically on first run. This model is a quantized GGML file produced by the whisper.cpp project. It is stored in:

```
~/Library/Application Support/CallRecorder/models/ggml-base.bin
```

You can manually place a different model there (e.g., `ggml-small.bin` for higher accuracy) and the app will use it.

## Known Limitations (Phase 1)

- **No speaker diarization** — Phase 2 will add Pyannote to identify "who said what"
- **No AI summarization** — Phase 2 will add a local LLM (Llama/Mistral via MLX) to generate summaries and action items
- **No auto-start** — recording must be started manually
- **No real-time transcription** — transcription happens after recording stops
- **Audio routing is manual** — you must set up BlackHole and aggregate devices yourself
- **Single-file processing** — one recording at a time

## Privacy

- **Zero network calls** for AI processing (except the one-time model download)
- All audio and transcripts stay on your Mac in `~/Library/Application Support/CallRecorder/`
- You are responsible for informing call participants that you are recording

## Next Steps (Phase 2)

- Speaker diarization (Pyannote.audio) — identify different speakers
- Local LLM summarization (Llama 3.1 via MLX) — summarize calls and extract action items
- Per-person and team to-do lists
- Speaker name labeling
- Export to Markdown/PDF
- Auto-delete old audio files
- Better audio routing wizard

## License

This project is provided as-is for personal productivity. Third-party dependencies retain their own licenses (MIT, Llama 3.1 License, etc.).

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Microphone access denied" | Go to **System Settings → Privacy & Security → Microphone** and enable Call Recorder |
| "No audio in transcript" | Verify BlackHole is selected as output and the Aggregate Device is selected as input |
| "Transcription is slow" | This is normal on CPU; Apple Silicon GPU is used automatically. First run may be slower due to model loading. |
| "Model download failed" | Check your internet connection. The model is downloaded from HuggingFace. You can also manually download `ggml-base.bin` and place it in `~/Library/Application Support/CallRecorder/models/`. |
| "Build errors in Xcode" | Make sure you have **Xcode 15+** and **macOS 14+ SDK** selected. The app uses `MenuBarExtra` which requires macOS 14. |

## Development Notes

- The app is built with **Swift Package Manager** and opened in Xcode via `Package.swift`
- `whisper.cpp` is integrated via SPM as a C++ package with Swift bridging
- `SQLite.swift` provides a type-safe Swift wrapper over SQLite
- The transcription runs on a background `DispatchQueue` and returns via `async/await`
