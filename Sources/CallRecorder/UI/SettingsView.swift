import SwiftUI
import AVFoundation

struct SettingsView: View {
    @Environment(AppState.self) var state
    @AppStorage("autoDeleteDays") private var autoDeleteDays: Int = 30

    var body: some View {
        TabView {
            generalTab.tabItem { Label("General", systemImage: "gearshape") }
            audioTab.tabItem { Label("Audio", systemImage: "speaker.wave.2") }
            modelsTab.tabItem { Label("Models", systemImage: "brain") }
            storageTab.tabItem { Label("Storage", systemImage: "externaldrive") }
        }
        .frame(width: 450, height: 350)
    }

    private var generalTab: some View {
        Form {
            Section("Cleanup") {
                Picker("Auto-delete after", selection: $autoDeleteDays) {
                    Text("Never").tag(0)
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                }
                Button("Delete Old Files Now") {
                    deleteOldFiles()
                }
            }
            Section("BlackHole Setup") {
                HStack {
                    Image(systemName: blackHoleInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(blackHoleInstalled ? .green : .red)
                    Text(blackHoleInstalled ? "BlackHole 2ch detected" : "BlackHole not installed")
                }
                if !blackHoleInstalled {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("To record both mic and system audio:")
                            .font(.caption)
                        Text("1. Download BlackHole 2ch from existential.audio/blackhole")
                        Text("2. Create Aggregate Device in Audio MIDI Setup")
                        Text("3. Set system output to BlackHole during calls")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var audioTab: some View {
        Form {
            Section("Input Devices") {
                List(state.availableDevices) { device in
                    HStack {
                        Text(device.name)
                        Spacer()
                        if device.id == state.selectedDevice?.id {
                            Image(systemName: "checkmark").foregroundStyle(.blue)
                        }
                    }
                    .contentShape(.rect)
                    .onTapGesture { state.selectedDevice = device }
                }
                .frame(minHeight: 80)
                Button("Refresh") { state.refreshDevices() }
            }
        }
    }

    private var modelsTab: some View {
        Form {
            Section("Whisper Model") {
                ForEach(state.whisperModels) { model in
                    HStack {
                        Text(model.name + " (\(model.size))")
                        Spacer()
                        if model.id == state.selectedWhisperModel?.id {
                            Image(systemName: "checkmark").foregroundStyle(.blue)
                        }
                    }
                    .contentShape(.rect)
                    .onTapGesture { state.switchWhisperModel(to: model) }
                }
                Divider()
                ForEach(ModelManager.models.filter { !state.whisperModels.contains($0) }) { model in
                    Button("Download \(model.name) (\(model.size))") {
                        Task { await state.downloadModel(model) }
                    }
                }
            }
            Section("LLM Model") {
                if state.ollamaRunning {
                    ForEach(state.availableModels) { model in
                        HStack {
                            Text(model.name)
                            Spacer()
                            if model.name == state.selectedModel?.name {
                                Image(systemName: "checkmark").foregroundStyle(.blue)
                            }
                        }
                        .contentShape(.rect)
                        .onTapGesture { state.selectedModel = model }
                    }
                } else {
                    Text("Ollama not running")
                        .foregroundStyle(.secondary)
                }
                Button("Refresh") { Task { await state.refreshOllama() } }
            }
        }
    }

    private var storageTab: some View {
        Form {
            Section("Audio Files") {
                HStack {
                    Text("Audio folder size:")
                    Spacer()
                    Text(folderSize)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Database size:")
                    Spacer()
                    Text(databaseSize)
                        .foregroundStyle(.secondary)
                }
                Button("Delete All Audio Files") {
                    deleteOldFiles()
                }
            }
        }
    }

    // MARK: - Helpers

    private var blackHoleInstalled: Bool {
        state.availableDevices.contains { $0.name.lowercased().contains("blackhole") }
    }

    private var folderSize: String {
        let dir = state.modelsDir.deletingLastPathComponent().appending(component: "audio")
        guard let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { return "—" }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    private var databaseSize: String {
        let dir = state.modelsDir.deletingLastPathComponent()
        let dbPath = dir.appending(component: "database.sqlite3")
        let size = (try? FileManager.default.attributesOfItem(atPath: dbPath.path)[.size] as? Int64) ?? 0
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private func deleteOldFiles() {
        guard autoDeleteDays > 0 else { return }
        let cutoff = Date().addingTimeInterval(TimeInterval(-autoDeleteDays * 86400))
        let audioDir = state.modelsDir.deletingLastPathComponent().appending(component: "audio")
        guard let files = try? FileManager.default.contentsOfDirectory(at: audioDir, includingPropertiesForKeys: [.creationDateKey]) else { return }
        for file in files {
            guard let created = (try? file.resourceValues(forKeys: [URLResourceKey.creationDateKey]))?.creationDate,
                  created < cutoff
            else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }
}
