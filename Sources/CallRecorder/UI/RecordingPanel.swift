import SwiftUI

struct RecordingPanel: View {
    @Environment(AppState.self) var state
    @State private var timer: Timer?
    @State private var tick: Date = .now

    var body: some View {
        VStack(spacing: 12) {
            switch state.recordingState {
            case .idle:
                if !state.modelLoaded {
                    downloadButton
                } else {
                    startButton
                }
            case .recording(let startedAt):
                recordingView(startedAt: startedAt)
            case .processing:
                processingView
            case .needsDownload(let progress):
                downloadProgressView(progress: progress)
            }

            if let err = state.errorMessage {
                Text(err)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .padding()
        .frame(width: 260)
    }

    private var startButton: some View {
        Button(action: { state.startRecording() }) {
            Label("Start Recording", systemImage: "record.circle")
                .font(.title3)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
    }

    private var downloadButton: some View {
        VStack(spacing: 8) {
            Text("Whisper model required")
                .font(.headline)
            Text("~141 MB download")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Download Model") {
                Task { await state.downloadModel() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func recordingView(startedAt: Date) -> some View {
        VStack(spacing: 8) {
            Text(timeString(from: startedAt, at: tick))
                .font(.largeTitle)
                .monospacedDigit()
                .foregroundStyle(.red)
                .onAppear { startTimer() }
                .onDisappear { timer?.invalidate() }
            Button(action: { timer?.invalidate(); state.stopRecording() }) {
                Label("Stop & Process", systemImage: "stop.circle")
                    .font(.title3)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }

    private var processingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Transcribing…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private func downloadProgressView(progress: Double) -> some View {
        VStack(spacing: 8) {
            ProgressView(value: progress)
            Text("Downloading model… \(Int(progress * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            tick = .now
        }
    }

    private func timeString(from date: Date, at now: Date) -> String {
        let d = now.timeIntervalSince(date)
        let m = Int(d) / 60
        let s = Int(d) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
