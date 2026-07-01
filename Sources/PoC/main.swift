import Foundation
import AVFoundation
import whisper

func findModelPath() -> String? {
    if CommandLine.arguments.count > 1 {
        let path = CommandLine.arguments[1]
        if FileManager.default.fileExists(atPath: path) { return path }
    }

    let candidates = [
        "./ggml-base.bin",
        "./models/ggml-base.bin",
        "Dependencies/whisper.spm/models/ggml-base.bin",
        NSHomeDirectory() + "/.cache/whisper/ggml-base.bin",
        NSHomeDirectory() + "/Library/Application Support/CallRecorder/models/ggml-base.bin",
    ]

    for path in candidates {
        let expanded = (path as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: expanded) {
            return expanded
        }
    }
    return nil
}

func resample(_ samples: [Float], from: Double, to: Double) -> [Float] {
    guard from != to else { return samples }
    let ratio = from / to
    let count = Int(Double(samples.count) / ratio)
    var out = [Float](repeating: 0, count: count)
    for i in 0..<count {
        let pos = Double(i) * ratio
        let idx = Int(pos)
        let frac = pos - Double(idx)
        if idx + 1 < samples.count {
            out[i] = Float((1 - frac) * Double(samples[idx]) + frac * Double(samples[idx + 1]))
        } else if idx < samples.count {
            out[i] = samples[idx]
        }
    }
    return out
}

func captureAudio() throws -> [Float] {
    let engine = AVAudioEngine()
    let input = engine.inputNode
    let fmt = input.outputFormat(forBus: 0)
    let sampleRate = fmt.sampleRate
    let channels = Int(fmt.channelCount)

    var buf: [Float] = []

    input.installTap(onBus: 0, bufferSize: 4096, format: fmt) { buffer, _ in
        guard let data = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        if channels == 1 {
            buf.append(contentsOf: UnsafeBufferPointer(start: data[0], count: frames))
        } else {
            var mono = [Float](repeating: 0, count: frames)
            for c in 0..<channels {
                let ptr = UnsafeBufferPointer(start: data[c], count: frames)
                for f in 0..<frames { mono[f] += ptr[f] }
            }
            for f in 0..<frames { mono[f] /= Float(channels) }
            buf.append(contentsOf: mono)
        }
    }

    try engine.start()
    print("Recording... Press ENTER to stop.", terminator: " ")
    fflush(stdout)
    _ = readLine()
    engine.stop()
    input.removeTap(onBus: 0)

    return resample(buf, from: sampleRate, to: 16000.0)
}

func transcribe(modelPath: String, samples: [Float]) {
    let cparams = whisper_context_default_params()
    guard let ctx = whisper_init_from_file_with_params(modelPath, cparams) else {
        print("Failed to load model")
        return
    }
    defer { whisper_free(ctx) }

    let nSamples = Int32(samples.count)
    let duration = Double(nSamples) / 16000.0
    print("Transcribing \(nSamples) samples (\(String(format: "%.1f", duration)) s)...")

    var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
    params.print_realtime = false
    params.print_progress = true
    params.print_timestamps = true
    params.n_threads = Int32(ProcessInfo.processInfo.processorCount)

    let ret = whisper_full(ctx, params, samples, nSamples)
    if ret != 0 {
        print("whisper_full failed: \(ret)")
        return
    }

    let nSegments = whisper_full_n_segments(ctx)
    print("\n=== TRANSCRIPT (\(nSegments) segments) ===")
    for i in 0..<nSegments {
        let t0 = whisper_full_get_segment_t0(ctx, i)
        let t1 = whisper_full_get_segment_t1(ctx, i)
        guard let text = whisper_full_get_segment_text(ctx, i) else { continue }
        let s = String(format: "%02d:%02d", t0 / 6000, (t0 / 100) % 60)
        let e = String(format: "%02d:%02d", t1 / 6000, (t1 / 100) % 60)
        print("[\(s) --> \(e)]  \(String(cString: text))")
    }
}

guard let modelPath = findModelPath() else {
    print("Model not found. Download with:")
    print("  curl -L -o Dependencies/whisper.spm/models/ggml-base.bin \\")
    print("    https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")
    exit(1)
}

print("Model: \(modelPath)")
print("Grant microphone access when prompted, then press ENTER to start recording.")
_ = readLine()

let samples: [Float]
do {
    samples = try captureAudio()
} catch {
    print("Failed to start recording: \(error.localizedDescription)")
    exit(1)
}

let count = samples.count
let seconds = Double(count) / 16000.0
if count < 16000 {
    print("Only \(count) samples (\(String(format: "%.2f", seconds)) s) captured — too short.")
    exit(1)
}

transcribe(modelPath: modelPath, samples: samples)
