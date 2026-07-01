# Technical Specification — macOS Call Recorder & AI Assistant

**Version:** 1.0  
**Status:** Draft (Pre-Implementation)  
**Scope:** Local-only, manual-trigger, open-source macOS application for recording calls, transcribing speech, diarizing speakers, summarizing, and extracting action items.

---

## 1. Executive Summary

This document specifies a macOS application that allows the user to **manually record** audio from video and audio calls (Zoom, Teams, FaceTime, browser-based, phone audio), transcribe the conversation locally, identify individual speakers, summarize the call, and generate per-person and team-wide to-do lists. The entire pipeline runs **locally on the Mac** with **strictly open-source** components. No cloud APIs are used. No background listening is implemented; recording is triggered manually by the user.

---

## 2. Requirements Summary (Confirmed)

| Requirement | Decision |
|-------------|----------|
| **Trigger** | Manual start/stop only. No background listening. |
| **Privacy/Legal** | User is responsible for informing participants. App-level privacy features deferred to future releases. |
| **Processing** | 100% local (on-device). No network calls for AI/ML. |
| **Use Case** | Personal productivity. |
| **Call Types** | Mixed — video calls (Zoom, Teams, Meet, Webex) and audio calls (FaceTime audio, phone via Continuity). |
| **Budget** | Strictly open source. Zero API costs. |
| **UI Complexity** | Minimal, easiest viable interface. Menu bar app with simple controls. |

---

## 3. Target Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    macOS Application (Swift/SwiftUI)           │
│                                                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Menu Bar App │  │ Recording UI │  │ Results View │          │
│  │  (SwiftUI)   │  │  (SwiftUI)   │  │  (SwiftUI)   │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│         │                  │                  │                 │
│         └──────────────────┼──────────────────┘                 │
│                            ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Local Processing Pipeline                   │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐  │   │
│  │  │  Audio   │→ │  Speech  │→ │  Speaker │→ │  Local │  │   │
│  │  │  Capture │  │  to Text │  │Diarization│  │  LLM   │  │   │
│  │  │(CoreAudio)│  │(Whisper)│  │(Pyannote)│  │(MLX/   │  │   │
│  │  │+BlackHole │  │          │  │           │  │Llama)  │  │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └────────┘  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                   │
│                            ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Local Storage (SQLite + Filesystem)        │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Technology Stack (Strictly Open Source)

### 4.1 Application Shell
| Component | Technology | License | Rationale |
|-----------|------------|---------|-----------|
| App Framework | Swift + SwiftUI | Apple | Native, modern, lightweight, menu bar friendly. |
| Build System | Xcode / Swift Package Manager | Apple | Standard macOS toolchain. |

### 4.2 Audio Capture
| Component | Technology | License | Rationale |
|-----------|------------|---------|-----------|
| Virtual Audio Driver | **BlackHole 2ch** (or 16ch) | MIT | Industry-standard, open-source, audio server plugin (not KEXT), works on macOS 11+. |
| Audio Routing | Core Audio (AVAudioEngine) | Apple | Native macOS audio APIs. |
| Aggregate Device | Core Audio | Apple | Combines physical microphone + BlackHole into a single recordable input. |

### 4.3 Speech-to-Text
| Component | Technology | License | Rationale |
|-----------|------------|---------|-----------|
| Engine | **OpenAI Whisper** (local) | MIT | State-of-the-art accuracy, multilingual, runs well on Apple Silicon. |
| Implementation | `whisper.cpp` (C++ port) | MIT | Optimized for local inference, no Python dependency, Core ML support available. |

### 4.4 Speaker Diarization
| Component | Technology | License | Rationale |
|-----------|------------|---------|-----------|
| Engine | **Pyannote.audio** | MIT | Best open-source diarization, speaker embedding model. |
| Implementation | Python runtime + ONNX export | MIT | Python required for Pyannote. Can potentially export to ONNX for Swift inference in future. |

### 4.5 Summarization & Action Item Extraction
| Component | Technology | License | Rationale |
|-----------|------------|---------|-----------|
| Engine | **Llama 3 / Mistral** (quantized) | Llama 3: Llama 3 License (open) / Mistral: Apache 2.0 | High-quality open LLMs. |
| Inference Framework | **MLX** (Apple) | MIT | Apple-optimized ML framework for Apple Silicon. Very fast, local, native Swift bindings available. |
| Alternative | **llama.cpp** | MIT | If MLX Swift bindings are insufficient, use llama.cpp via C++ interop. |

### 4.6 Storage
| Component | Technology | License | Rationale |
|-----------|------------|---------|-----------|
| Structured Data | SQLite (via GRDB.swift or raw) | SQLite: Public Domain | Lightweight, file-based, queryable. |
| Raw Audio Files | Filesystem (configurable directory) | — | WAV or FLAC format for archival. |
| Transcripts | Filesystem (Markdown) or SQLite | — | Human-readable exportable format. |

---

## 5. Detailed Component Specifications

### 5.1 Audio Capture Subsystem

#### 5.1.1 Setup Flow (One-Time)
1. App detects if BlackHole 2ch is installed.
2. If not, prompt user to download and install (or bundle installer).
3. App creates a **Core Audio Aggregate Device** programmatically:
   - **Input Sources:** Physical Microphone + BlackHole 2ch
   - **Output Pass-through:** BlackHole 2ch (so system audio can be routed to it)
4. User may need to set their system output to BlackHole during calls (app can offer a toggle).

#### 5.1.2 Recording Flow (Per Call)
1. User clicks **"Start Recording"** from menu bar.
2. App initializes `AVAudioEngine` with the Aggregate Device as input.
3. Audio is written to a temporary **WAV file** (PCM, 16kHz, mono or stereo) in a buffer.
4. User clicks **"Stop Recording"**.
5. Audio file is finalized and moved to persistent storage.

#### 5.1.3 Audio Format Specifications
- **Format:** Linear PCM WAV
- **Sample Rate:** 16,000 Hz (optimal for Whisper)
- **Channels:** Mono or Stereo (stereo allows channel separation heuristic: left = system audio, right = microphone)
- **Bit Depth:** 16-bit
- **Estimated File Size:** ~1.9 MB per minute (mono, 16kHz, 16-bit)

### 5.2 Transcription Subsystem (Whisper)

#### 5.2.1 Implementation: `whisper.cpp`
- **Repository:** `ggerganov/whisper.cpp`
- **Model:** `ggml-base.bin` or `ggml-small.bin` (trade-off: speed vs. accuracy)
- **Hardware:** Optimized for Apple Silicon (NEON, Metal GPU, Core ML)
- **Integration:** C++ library linked via Swift Package Manager or bridged with a small C wrapper.

#### 5.2.2 Processing Flow
1. Post-recording, audio file is passed to `whisper.cpp`.
2. Model transcribes into text with timestamps.
3. Output format: JSON or custom struct with `start_time`, `end_time`, `text`.
4. Estimated processing time: **~0.5x real-time** (30 min call → ~15 min transcription on M2/M3).

### 5.3 Speaker Diarization Subsystem (Pyannote)

#### 5.3.1 Implementation
- **Repository:** `pyannote/pyannote-audio`
- **Model:** `pyannote/speaker-diarization-3.1` (or latest open version)
- **Runtime:** Embedded Python runtime (via `PythonKit` Swift library or bundled Python with conda/miniforge)
- **Pipeline:**
  1. Load audio file.
  2. Run segmentation + speaker embedding clustering.
  3. Output: list of segments with speaker labels (`SPEAKER_00`, `SPEAKER_01`, etc.) and timestamps.

#### 5.3.2 Integration with Transcription
1. Whisper produces word-level or segment-level timestamps.
2. Pyannote produces speaker-level timestamps.
3. **Alignment step:** Match Whisper segments to Pyannote speaker segments by time overlap.
4. Final transcript format: `Speaker A: [text]`, `Speaker B: [text]`, etc.

#### 5.3.3 Speaker Count Estimation
- Pyannote automatically estimates the number of speakers (usually up to 4-5 reliably).
- For manual calls, app can prompt user to label speakers after processing (e.g., "Who was SPEAKER_00?" → user types "Alice").

### 5.4 LLM Subsystem (Summarization & Todo Extraction)

#### 5.4.1 Implementation: MLX + Llama 3
- **Framework:** `ml-explore/mlx` (Swift bindings: `mlx-swift`)
- **Model:** Meta Llama 3.1 8B Instruct (Q4_K_M quantization) or Mistral 7B Instruct
- **Size:** ~4-5 GB on disk
- **RAM usage:** ~6-8 GB during inference (manageable on 16GB+ Macs)

#### 5.4.2 Prompt Engineering
```
System: You are a meeting assistant. Given a transcript with speaker labels, produce:
1. A concise summary (3-5 sentences).
2. Key decisions made.
3. A list of action items. For each action item, identify the owner if clear from context, or mark as "Team" if shared.
4. A separate per-person to-do list for each speaker mentioned.

Transcript:
[Input transcript here]

Output as JSON with fields: summary, decisions, action_items[], per_person_todos{}
```

#### 5.4.3 Output Format (Structured JSON)
```json
{
  "summary": "Brief summary of the call.",
  "decisions": ["Decision 1", "Decision 2"],
  "team_todos": ["Team-wide action item 1", "Team-wide action item 2"],
  "per_person_todos": {
    "Alice": ["Alice's task 1", "Alice's task 2"],
    "Bob": ["Bob's task 1"]
  }
}
```

### 5.5 Data Model (SQLite Schema)

```sql
-- Calls table
CREATE TABLE calls (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid TEXT UNIQUE NOT NULL,
    title TEXT,
    started_at INTEGER NOT NULL, -- Unix timestamp
    ended_at INTEGER,
    duration_seconds INTEGER,
    audio_file_path TEXT NOT NULL,
    status TEXT NOT NULL, -- 'recording', 'processing', 'completed', 'error'
    speaker_count INTEGER,
    summary TEXT,
    created_at INTEGER DEFAULT (strftime('%s', 'now'))
);

-- Transcript segments table
CREATE TABLE transcript_segments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    call_id INTEGER NOT NULL,
    speaker_id TEXT NOT NULL, -- e.g., SPEAKER_00, later renamed to name
    start_time REAL NOT NULL, -- seconds from start
    end_time REAL NOT NULL,
    text TEXT NOT NULL,
    FOREIGN KEY (call_id) REFERENCES calls(id)
);

-- Action items table
CREATE TABLE action_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    call_id INTEGER NOT NULL,
    owner TEXT, -- NULL = team-wide
    task TEXT NOT NULL,
    completed INTEGER DEFAULT 0,
    FOREIGN KEY (call_id) REFERENCES calls(id)
);

-- Speakers table (for manual labeling)
CREATE TABLE speakers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    call_id INTEGER NOT NULL,
    speaker_label TEXT NOT NULL, -- SPEAKER_00
    display_name TEXT, -- user-assigned name
    FOREIGN KEY (call_id) REFERENCES calls(id)
);
```

---

## 6. User Interface Design (Minimal)

### 6.1 Menu Bar Icon (Primary Interface)
- **Idle:** Microphone icon (gray)
- **Recording:** Red circle with elapsed timer (e.g., "🔴 12:34")
- **Processing:** Spinner icon (or yellow indicator)
- **Click:** Dropdown menu

### 6.2 Menu Bar Dropdown
```
┌──────────────────────────┐
│  Call Recorder           │
│  ───────────────────────  │
│  🟢 Start Recording      │
│  🔴 Stop Recording       │  (visible during recording)
│  ───────────────────────  │
│  📋 Recent Calls         │
│     → Call with Alice & Bob (12:30)
│     → Team Standup (11:00)
│  ───────────────────────  │
│  ⚙️ Settings             │
│  ❌ Quit                 │
└──────────────────────────┘
```

### 6.3 Recording Window (During Recording)
- Floating, compact window (optional, can be hidden)
- Shows:
  - Elapsed time (large)
  - Audio level meter (visual feedback)
  - "Stop & Process" button (red, prominent)
  - Optional: "Add Note" button (quick timestamped note)

### 6.4 Results Window (Post-Processing)
- Call title (editable) + date/time
- **Summary** tab: Executive summary, key decisions
- **Transcript** tab: Full diarized transcript with speaker names
- **Action Items** tab:
  - Team to-do list
  - Per-person to-do lists (collapsible sections)
  - Checkboxes to mark complete
- **Export** button: Markdown, PDF, or JSON

### 6.5 Settings Panel
- Audio device selection (BlackHole device, microphone)
- Model selection (Whisper: tiny/base/small; LLM: Llama/Mistral model path)
- Storage directory
- Auto-delete audio after processing (toggle, default: OFF)
- Storage limit (auto-delete oldest calls when limit exceeded)

---

## 7. File Storage Layout

```
~/Library/Application Support/CallRecorder/
├── audio/
│   ├── 2025-01-15_143022_call.wav
│   ├── 2025-01-15_151045_call.wav
│   └── ...
├── transcripts/
│   ├── 2025-01-15_143022_call.md
│   └── ...
├── models/
│   ├── whisper/
│   │   └── ggml-base.bin
│   ├── llm/
│   │   └── llama-3.1-8b-instruct-Q4_K_M.gguf
│   └── pyannote/
│       └── ... (ONNX or Python model files)
├── database.sqlite3
└── config.json
```

---

## 8. Processing Pipeline Flow (Sequence Diagram)

```
User          App UI        AudioEngine      Whisper        Pyannote      LLM (MLX)       SQLite
 │              │               │               │              │              │               │
 │─Click Start──>│              │               │              │              │               │
 │              │─Init Capture──>│               │              │              │               │
 │              │               │─Recording───>  │              │              │               │
 │              │<─Audio Buffer──│               │              │              │               │
 │              │               │               │              │              │               │
 │─Click Stop───>│              │               │              │              │               │
 │              │─Finalize─────>│               │              │              │               │
 │              │               │─WAV File─────>│              │              │               │
 │              │              │               │              │              │               │
 │              │─Transcribe────────────────────>│              │              │               │
 │              │              │<─Raw Text─────│              │              │               │
 │              │─Diarize──────────────────────────────────────>│              │               │
 │              │              │<─Speaker Segments─────────────│              │               │
 │              │              │               │              │              │               │
 │              │─Align & Merge Transcript + Speakers                         │               │
 │              │              │               │              │              │               │
 │              │─Summarize─────────────────────────────────────────────────────>│               │
 │              │              │<─JSON Result────────────────────────────────│              │               │
 │              │              │               │              │              │              │               │
 │              │─Save to DB──────────────────────────────────────────────────────────────────────>│
 │<─Show Results│              │               │              │              │               │
```

---

## 9. Key Technical Decisions & Trade-offs

### 9.1 Python vs. Pure Swift
| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| **Pure Swift** | Single language, easier packaging, no runtime dependencies | Pyannote not available in Swift; would need to rewrite diarization | ❌ Not viable |
| **Swift + PythonKit** | Can call Pyannote directly from Swift | Requires Python runtime installed on user machine | ⚠️ Backup option |
| **Swift + Embedded Python** | Bundles Python + Pyannote in app bundle | Very large app size (~2GB+); complex packaging | ⚠️ Possible |
| **Swift + whisper.cpp + ONNX diarization** | All native, no Python | Diarization model would need ONNX export; more dev work | 🎯 **Future optimization** |
| **Swift + whisper.cpp + Python subprocess for Pyannote** | Clean separation; Python environment isolated | Requires managing Python env; IPC overhead | ✅ **MVP Approach** |

**MVP Decision:**
- **Whisper:** `whisper.cpp` linked directly in Swift (C++ interop).
- **Pyannote:** Python script invoked as subprocess with bundled Python environment (via `conda-pack` or `uv` or `PyOxidizer`).
- **LLM:** `mlx-swift` (Swift bindings) or `llama.cpp` via C++ interop.

### 9.2 Diarization Accuracy Expectations
- **2-3 speakers:** High accuracy (~90%+)
- **4-5 speakers:** Moderate accuracy (~75-85%)
- **6+ speakers:** Lower accuracy, may require manual correction
- **Mitigation:** UI allows user to merge/split speaker segments and rename speakers post-hoc.

### 9.3 LLM Performance Expectations (M-Series Mac)
- **Llama 3.1 8B Q4:** ~20-50 tokens/sec on M2/M3 Pro (sufficient for 5-10 min summary processing)
- **Context window:** 8K tokens (enough for ~30-45 min call transcript)
- **Longer calls:** Will require chunking or summarization in stages.

---

## 10. Milestones & Phasing

### Phase 1: Foundation (MVP)
- [ ] SwiftUI menu bar app shell
- [ ] Audio capture via Core Audio + BlackHole (manual setup)
- [ ] WAV file recording (start/stop)
- [ ] `whisper.cpp` integration (local transcription)
- [ ] SQLite data storage
- [ ] Basic transcript display

### Phase 2: Intelligence
- [ ] Pyannote diarization integration (Python subprocess)
- [ ] Transcript + diarization alignment
- [ ] MLX LLM integration (Llama 3.1 8B)
- [ ] Summary & action item extraction
- [ ] Per-person to-do list generation
- [ ] Results window with tabs

### Phase 3: Polish
- [ ] Speaker manual labeling (rename SPEAKER_00 → "Alice")
- [ ] To-do checkboxes & persistence
- [ ] Export to Markdown/PDF
- [ ] Searchable call history
- [ ] Audio storage management (auto-delete old)
- [ ] BlackHole auto-setup / bundled installer
- [ ] Settings panel

### Phase 4: Future (Out of Scope for Now)
- [ ] Real-time transcription
- [ ] Calendar integration (auto-suggest recording)
- [ ] Cloud sync option (iCloud)
- [ ] Privacy mode (consent recording, automatic notification)
- [ ] Multi-language support (Whisper already supports this)
- [ ] Mobile companion app (iOS)

---

## 11. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Pyannote is Python-only** | High | Bundle Python runtime or use subprocess with standalone environment. Document setup if bundling is too complex. |
| **BlackHole installation friction** | Medium | Provide clear setup wizard. Consider bundling audio driver installer. Document step-by-step. |
| **MLX Swift bindings immature** | Medium | Fallback to `llama.cpp` with Swift C++ interop. Both are viable. |
| **Large model download on first run** | Low-Medium | Progressive download UI. Models are 500MB (Whisper base) + 4GB (Llama 8B). Can offer model size choice. |
| **Apple Silicon only (MLX)** | Medium | `llama.cpp` works on Intel too. MLX is Apple Silicon only. If Intel support needed, use llama.cpp. |
| **User sets wrong audio device** | Low | App validates audio input levels before recording. Warn if silent. |

---

## 12. Open Source License Compliance

| Component | License | Notes |
|-----------|---------|-------|
| BlackHole | MIT | Attribution required. |
| whisper.cpp | MIT | Attribution required. |
| Pyannote.audio | MIT | Attribution required. |
| Llama 3.1 | Llama 3.1 License | Acceptable license for open-source projects. No commercial restriction for personal use. |
| Mistral | Apache 2.0 | Very permissive. |
| MLX | MIT | Apple open-source. |
| GRDB.swift | MIT | SQLite wrapper. |
| Python | PSF | Bundled runtime. |

**Action:** Include `LICENSE-THIRD-PARTY.md` in app bundle and distribution.

---

## 13. macOS Permissions Required

| Permission | Purpose | When Needed |
|------------|---------|-------------|
| **Microphone** | Capture local user's voice | First recording |
| **Accessibility** (optional) | Detect if call app is active | Future auto-detection (not MVP) |
| **Files & Folders** | Store audio and transcripts in Application Support | Always |
| **System Extension** (if bundling driver) | Install audio driver | Setup (if we create our own driver) |

---

## 14. Performance Targets (MVP)

| Metric | Target | Notes |
|--------|--------|-------|
| App launch time | < 2 seconds | Menu bar app should be instant. |
| Recording start latency | < 1 second | From click to active capture. |
| Transcription speed | 0.5x - 1x real-time | 30 min call in 15-30 min processing. |
| Diarization speed | 0.3x real-time | 30 min call in ~10 min. |
| LLM summary speed | < 5 minutes | For typical 30 min call. |
| Total processing time | < 1 hour for 30 min call | Batch process acceptable for personal use. |
| App memory footprint | < 2 GB idle | LLM loaded on demand. |
| Disk space (models) | ~5 GB | Whisper base + Llama 8B quantized. |

---

## 15. Success Criteria

1. User can start/stop recording from menu bar.
2. Audio from both mic and system output is captured in sync.
3. Full transcript is produced with speaker labels (even if generic at first).
4. Call summary is generated locally.
5. Action items and per-person to-do lists are extracted and displayed.
6. All processing completes without internet connectivity.
7. No cloud services or API keys are required.

---

## 16. Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-01-15 | AI Assistant | Initial specification based on user requirements. |

---

*End of Technical Specification.*
