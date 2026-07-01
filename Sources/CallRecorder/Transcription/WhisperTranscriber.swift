import Foundation
import whisper

final class WhisperTranscriber {
    private var context: OpaquePointer?
    private let queue = DispatchQueue(label: "transcribe", qos: .userInitiated)

    var isLoaded: Bool { context != nil }

    func loadModel(at path: String) -> Bool {
        if context != nil { return true }
        let cparams = whisper_context_default_params()
        guard let ctx = whisper_init_from_file_with_params(path, cparams) else {
            return false
        }
        context = ctx
        return true
    }

    func unload() {
        if let ctx = context {
            whisper_free(ctx)
            context = nil
        }
    }

    func transcribe(audioFile path: String, onSegment: @escaping (String, TimeInterval, TimeInterval) -> Void) async throws {
        guard let ctx = context else {
            throw TranscriptionError.modelNotLoaded
        }

        guard let samples = AudioRecorder.loadWavSamples(path) else {
            throw TranscriptionError.invalidAudio
        }

        let duration = Double(samples.count) / 16000.0
        print("DEBUG: Loaded \(samples.count) samples from \(path) — \(String(format: "%.1f", duration))s")

        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
                params.print_realtime = false
                params.print_progress = true
                params.n_threads = Int32(ProcessInfo.processInfo.processorCount)

                let nSamples = Int32(samples.count)
                print("DEBUG: Calling whisper_full with \(nSamples) samples, threads=\(params.n_threads)")
                let ret = whisper_full(ctx, params, samples, nSamples)
                print("DEBUG: whisper_full returned \(ret)")
                guard ret == 0 else {
                    continuation.resume(throwing: TranscriptionError.transcriptionFailed(ret))
                    return
                }

                let nSegments = whisper_full_n_segments(ctx)
                print("DEBUG: Got \(nSegments) segments")
                for i in 0..<nSegments {
                    let t0 = whisper_full_get_segment_t0(ctx, i)
                    let t1 = whisper_full_get_segment_t1(ctx, i)
                    guard let textPtr = whisper_full_get_segment_text(ctx, i) else { continue }
                    let text = String(cString: textPtr)
                    let start = Double(t0) / 100.0
                    let end = Double(t1) / 100.0
                    print("DEBUG: Segment \(i): [\(start)-\(end)] \(text.prefix(80))")
                    onSegment(text, start, end)
                }
                continuation.resume()
            }
        }
    }

    deinit {
        unload()
    }
}

enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case invalidAudio
    case transcriptionFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "Model not loaded"
        case .invalidAudio: return "Could not read audio file"
        case .transcriptionFailed(let code): return "Transcription failed (\(code))"
        }
    }
}
