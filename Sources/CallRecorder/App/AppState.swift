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
        if modelManager.modelExists {
            modelLoaded = transcriber.loadModel(at: modelManager.whisperModelURL.path)
        }
        diarizationAvailable = diarizer.findPython() != nil && diarizer.findScript() != nil
    }

    func downloadModel() async {
        recordingState = .needsDownload(progress: 0)
        do {
            try await modelManager.downloadIfNeeded { p in
                Task { @MainActor in
                    self.recordingState = .needsDownload(progress: p)
                }
            }
            modelLoaded = transcriber.loadModel(at: modelManager.whisperModelURL.path)
            recordingState = .idle
        } catch {
            errorMessage = "Download failed: \(error.localizedDescription)"
            recordingState = .idle
        }
    }

    func startRecording() {
        let audioDir = modelManager.modelsDir
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

            if diarizationAvailable {
                do {
                    let speakerSegments = try await diarizer.diarize(audioFile: audioPath)
                    let transcriptSegments = db.fetchSegments(for: callId)
                    let aligned = aligner.align(transcriptSegments: transcriptSegments, speakerSegments: speakerSegments)
                    for seg in aligned {
                        db.updateSegmentSpeaker(callId: callId, startTime: seg.startTime, speaker: seg.speaker)
                    }
                } catch {
                    print("Diarization skipped: \(error.localizedDescription)")
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

    func loadCalls() {
        calls = db.fetchAllCalls()
    }

    func selectCall(_ call: CallRecord) {
        var c = call
        c.transcriptSegments = db.fetchSegments(for: call.id)
        selectedCall = c
    }
}
