import SwiftUI

@main
struct CallRecorderApp: App {
    @State private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environment(state)
        } label: {
            switch state.recordingState {
            case .idle, .needsDownload:
                Image(systemName: "mic")
            case .recording:
                Image(systemName: "mic.fill")
                    .foregroundStyle(.red)
            case .processing:
                Image(systemName: "mic.badge.plus")
            }
        }

        Window("Call History", id: "history") {
            NavigationSplitView {
                CallHistoryView()
                    .environment(state)
            } detail: {
                TranscriptDetailView()
                    .environment(state)
            }
            .frame(minWidth: 600, minHeight: 400)
        }
        .defaultSize(width: 700, height: 500)
    }
}

struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(AppState.self) var state

    var body: some View {
        devicesMenu
        llmMenu

        switch state.recordingState {
        case .idle:
            if state.modelLoaded {
                Divider()
                startButton
            } else {
                downloadButton
            }
        case .recording(let startedAt):
            Divider()
            Text(timeString(from: startedAt, at: .now))
                .font(.title3)
                .monospacedDigit()
                .foregroundStyle(.red)
            if let device = state.selectedDevice {
                Text(device.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Divider()
            stopButton
        case .processing:
            Divider()
            processingItem
        case .needsDownload(let progress):
            Divider()
            downloadProgressItem(progress: progress)
        }

        Divider()
        historyButton
        Divider()
        quitButton
    }

    // MARK: - Devices

    private var devicesMenu: some View {
        Menu(state.selectedDevice?.name ?? "Select Audio Input") {
            Button("Refresh Devices", action: { state.refreshDevices() })
            Divider()
            ForEach(state.availableDevices) { device in
                Button {
                    state.selectedDevice = device
                } label: {
                    HStack {
                        Text(device.name)
                        if device.id == state.selectedDevice?.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }

    // MARK: - LLM Model

    private var llmMenu: some View {
        if state.ollamaRunning && !state.availableModels.isEmpty {
            Menu(state.selectedModel?.name ?? "Select Summary Model") {
                Button("Refresh Models") {
                    Task { await state.refreshOllama() }
                }
                Divider()
                ForEach(state.availableModels) { model in
                    Button {
                        state.selectedModel = model
                    } label: {
                        HStack {
                            Text(model.name)
                            if model.name == state.selectedModel?.name {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } else {
            Button("Connect to Ollama...") {
                Task { await state.refreshOllama() }
            }
        }
    }

    // MARK: - Buttons

    private var startButton: some View {
        Button(action: { state.startRecording() }) {
            HStack {
                Image(systemName: "record.circle")
                    .foregroundStyle(.red)
                Text("Start Recording")
                    .foregroundStyle(.red)
            }
        }
    }

    private var stopButton: some View {
        Button(action: { state.stopRecording() }) {
            HStack {
                Image(systemName: "stop.circle")
                    .foregroundStyle(.red)
                Text("Stop & Process")
            }
        }
    }

    private var historyButton: some View {
        Button {
            state.loadCalls()
            openWindow(id: "history")
        } label: {
            Label("Call History", systemImage: "clock.arrow.circlepath")
        }
        .keyboardShortcut("h")
    }

    private var quitButton: some View {
        Button(action: { NSApplication.shared.terminate(nil) }) {
            Label("Quit", systemImage: "xmark")
        }
        .keyboardShortcut("q")
    }

    // MARK: - Other items

    private var downloadButton: some View {
        VStack(spacing: 4) {
            Text("Whisper model required")
                .font(.caption)
            Text("~141 MB download")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Button("Download Model") {
                Task { await state.downloadModel() }
            }
        }
    }

    private var processingItem: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.7)
            Text("Transcribing…")
                .font(.caption)
        }
    }

    private func downloadProgressItem(progress: Double) -> some View {
        VStack(spacing: 4) {
            ProgressView(value: progress)
            Text("Downloading… \(Int(progress * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private func timeString(from date: Date, at now: Date) -> String {
    let d = now.timeIntervalSince(date)
    let m = Int(d) / 60
    let s = Int(d) % 60
    return String(format: "%02d:%02d", m, s)
}
