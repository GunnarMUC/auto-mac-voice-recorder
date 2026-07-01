import Foundation
import SwiftUI

@MainActor
@Observable
final class AppState {
    enum RecordingState: Equatable {
        case idle
        case recording(startedAt: Date)
        case processing
        case needsDownload(progress: Double)
    }

    var recordingState: RecordingState = .idle
    var modelLoaded: Bool = false
    var diarizationAvailable: Bool = false
    var ollamaRunning: Bool = false
    var availableModels: [OllamaModel] = []
    var selectedModel: OllamaModel?
    var availableDevices: [AudioDevice] = []
    var selectedDevice: AudioDevice?
    var calls: [CallRecord] = []
    var selectedCall: CallRecord?
    var errorMessage: String? {
        didSet { if errorMessage != nil { clearErrorAfter() } }
    }

    private let recorder = AudioRecorder()
    let transcriber = WhisperTranscriber()
    private let diarizer = SpeakerDiarizer()
    private let aligner = DiarizationAligner()
    private let summarizer = LLMSummarizer()
    private let ollama = OllamaManager.shared
    private let db = DatabaseManager()
    private let modelManager = ModelManager.shared
    private var currentAudioPath: String?
    private var currentCallId: Int64?
    private var errorClearTask: Task<Void, Never>?

    init() {
        refreshDevices()
        loadCalls()
    }

    func refreshDevices() {
        availableDevices = AudioDeviceManager.listInputDevices()
        if selectedDevice == nil || !availableDevices.contains(where: { $0.id == selectedDevice?.id }) {
            selectedDevice = AudioDeviceManager.currentInputDevice() ?? availableDevices.first
        }
    }

    private func clearErrorAfter() {
        errorClearTask?.cancel()
        errorClearTask = Task {
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled { errorMessage = nil }
        }
    }

    func checkModel() async {
        if let path = modelManager.resolveModelPath() {
            modelLoaded = transcriber.loadModel(at: path)
        }
        diarizationAvailable = diarizer.findPython() != nil && diarizer.findScript() != nil
        await refreshOllama()
    }

    func refreshOllama() async {
        ollamaRunning = await ollama.checkRunning()
        if ollamaRunning {
            availableModels = (try? await ollama.listModels()) ?? []
            if selectedModel == nil || !availableModels.contains(where: { $0.name == selectedModel?.name }) {
                selectedModel = availableModels.first
            }
        } else {
            availableModels = []
        }
    }

    func downloadModel() async {
        recordingState = .needsDownload(progress: 0)
        do {
            try await modelManager.downloadIfNeeded { p in
                Task { @MainActor in
                    self.recordingState = .needsDownload(progress: p)
                }
            }
            if let path = modelManager.resolveModelPath() {
                modelLoaded = transcriber.loadModel(at: path)
            }
            recordingState = .idle
        } catch {
            errorMessage = "Download failed: \(error.localizedDescription)"
            recordingState = .idle
        }
    }

    func startRecording() {
        let audioDir = modelManager.whisperModelURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(component: "audio")
        try? FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)

        let dateStr = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let path = audioDir.appending(component: "\(dateStr).wav").path
        currentAudioPath = path

        do {
            try recorder.startRecording(device: selectedDevice)
            recordingState = .recording(startedAt: Date())
            currentCallId = db.insertCall(uuid: UUID().uuidString, audioFilePath: path)
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            currentAudioPath = nil
        }
    }

    func stopRecording() {
        guard case .recording = recordingState else { return }
        let (samples, sampleRate) = recorder.stopRecording()
        recordingState = .processing

        guard let path = currentAudioPath else {
            recordingState = .idle
            return
        }

        AudioRecorder.writeWAV(to: path, samples: samples, sampleRate: sampleRate)
        print("DEBUG: WAV saved to \(path) — \(samples.count) raw samples at \(sampleRate)Hz")

        let duration = samples.isEmpty ? 0 : Int(Double(samples.count) / sampleRate)

        if let callId = currentCallId {
            db.updateCall(id: callId, status: .processing, endedAt: Date(), duration: duration)
            Task {
                await runTranscription(callId: callId, audioPath: path)
            }
        }
    }

    private func runTranscription(callId: Int64, audioPath: String) async {
        do {
            try await transcriber.transcribe(audioFile: audioPath) { [db] text, start, end in
                db.insertSegment(callId: callId, speakerId: "SPEAKER_00", startTime: start, endTime: end, text: text)
            }

            let transcriptSegments = db.fetchSegments(for: callId)

            if diarizationAvailable {
                do {
                    let speakerSegments = try await diarizer.diarize(audioFile: audioPath)
                    let aligned = aligner.align(transcriptSegments: transcriptSegments, speakerSegments: speakerSegments)
                    for seg in aligned {
                        db.updateSegmentSpeaker(callId: callId, startTime: seg.startTime, speaker: seg.speaker)
                    }
                } catch {
                    print("Diarization skipped: \(error.localizedDescription)")
                }
            }

            if ollamaRunning, let model = selectedModel {
                do {
                    var segments = db.fetchSegments(for: callId)
                    if segments.isEmpty { segments = transcriptSegments }
                    let jsonPath = try writeTranscriptJSON(segments: segments)
                    let summary = try await summarizer.summarize(transcriptPath: jsonPath, model: model.name)
                    db.saveSummary(callId: callId, summary: summary)
                    try? FileManager.default.removeItem(atPath: jsonPath)
                } catch {
                    print("Summarization skipped: \(error.localizedDescription)")
                }
            }

            db.markCallCompleted(id: callId)
            recordingState = .idle
            loadCalls()
        } catch {
            db.markCallError(id: callId)
            errorMessage = error.localizedDescription
            recordingState = .idle
        }
    }

    private func writeTranscriptJSON(segments: [TranscriptSegment]) throws -> String {
        let tmp = FileManager.default.temporaryDirectory.appending(component: "transcript-\(UUID().uuidString).json")
        let list = segments.map { seg in
            [
                "speaker": seg.speakerId,
                "text": seg.text,
                "start": seg.startTime,
                "end": seg.endTime,
            ] as [String: Any]
        }
        let data = try JSONSerialization.data(withJSONObject: list, options: [.withoutEscapingSlashes])
        try data.write(to: tmp)
        return tmp.path
    }

    func loadCalls() {
        calls = db.fetchAllCalls()
    }

    func selectCall(_ call: CallRecord) {
        var c = call
        c.transcriptSegments = db.fetchSegments(for: call.id)
        selectedCall = c
    }
}
