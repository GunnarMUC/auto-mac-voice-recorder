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
        whisperMenu
        llmMenu

        Divider()

        switch state.recordingState {
        case .idle:
            if state.modelLoaded {
                startButton
            } else {
                downloadButton
            }
        case .recording(let startedAt):
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
            processingItem
        case .needsDownload(let progress):
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

    // MARK: - Whisper Model

    @ViewBuilder
    private var whisperMenu: some View {
        if state.whisperModels.isEmpty {
            Menu("Whisper Model") {
                ForEach(ModelManager.models) { model in
                    Button {
                        Task { await state.downloadModel(model) }
                    } label: {
                        Text("Download \(model.name) — \(model.size)")
                    }
                }
            }
        } else {
            Menu(state.selectedWhisperModel?.name ?? "Whisper Model") {
                ForEach(state.whisperModels) { model in
                    Button {
                        state.switchWhisperModel(to: model)
                    } label: {
                        HStack {
                            Text(model.name)
                            if model.id == state.selectedWhisperModel?.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                Divider()
                Text("Download more:").foregroundStyle(.secondary)
                ForEach(ModelManager.models.filter { !state.whisperModels.contains($0) }) { model in
                    Button {
                        Task { await state.downloadModel(model) }
                    } label: {
                        Text("Download \(model.name) — \(model.size)")
                    }
                }
            }
        }
    }

    // MARK: - LLM Model

    @ViewBuilder
    private var llmMenu: some View {
        Menu(state.selectedModel?.name ?? "LLM Model") {
            Button("Connect/Refresh") {
                Task { await state.refreshOllama() }
            }
            Divider()
            if state.availableModels.isEmpty {
                Text("No models found").foregroundStyle(.secondary)
            } else {
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
        ForEach(ModelManager.models) { model in
            Button("Download \(model.name) (\(model.size))") {
                Task { await state.downloadModel(model) }
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
