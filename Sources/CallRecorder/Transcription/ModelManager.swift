import Foundation

final class ModelManager {
    static let shared = ModelManager()

    var whisperModelURL: URL { _whisperModelURL }
    var modelsDir: URL { _modelsDir }

    private let _modelsDir: URL
    private let _whisperModelURL: URL
    private let fallbackCandidates: [URL]

    private init() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appending(component: "CallRecorder", directoryHint: .isDirectory)
        _modelsDir = appSupport.appending(component: "models", directoryHint: .isDirectory)
        _whisperModelURL = _modelsDir.appending(component: "ggml-base.bin")

        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        fallbackCandidates = [
            cwd.appending(path: "Dependencies/whisper.spm/models/ggml-base.bin"),
            cwd.appending(path: "../Dependencies/whisper.spm/models/ggml-base.bin"),
            Bundle.main.resourceURL?.appending(path: "Dependencies/whisper.spm/models/ggml-base.bin") ?? cwd,
        ].filter { fm.fileExists(atPath: $0.path) }

        try? fm.createDirectory(at: _modelsDir, withIntermediateDirectories: true)

        if !fm.fileExists(atPath: _whisperModelURL.path), let fallback = fallbackCandidates.first {
            try? fm.copyItem(at: fallback, to: _whisperModelURL)
        }
    }

    var modelExists: Bool {
        let fm = FileManager.default
        if fm.fileExists(atPath: _whisperModelURL.path) { return true }
        if let fallback = fallbackCandidates.first, fm.fileExists(atPath: fallback.path) { return true }
        return false
    }

    func resolveModelPath() -> String? {
        let fm = FileManager.default
        if fm.fileExists(atPath: _whisperModelURL.path) { return _whisperModelURL.path }
        if let fallback = fallbackCandidates.first, fm.fileExists(atPath: fallback.path) { return fallback.path }
        return nil
    }

    func downloadIfNeeded(progress: @escaping (Double) -> Void) async throws {
        if modelExists { return }
        let url = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")!
        let tmpURL = FileManager.default.temporaryDirectory.appending(component: "ggml-base.bin")
        if FileManager.default.fileExists(atPath: tmpURL.path) {
            try FileManager.default.removeItem(at: tmpURL)
        }

        FileManager.default.createFile(atPath: tmpURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: tmpURL)
        defer { try? handle.close() }

        let (bytes, response) = try await URLSession.shared.bytes(from: url)
        let expected = response.expectedContentLength
        var written: Int64 = 0
        var buffer = Data()

        for try await byte in bytes {
            buffer.append(byte)
            if buffer.count >= 65536 {
                try handle.write(contentsOf: buffer)
                written += Int64(buffer.count)
                buffer.removeAll()
                if expected > 0 {
                    progress(Double(written) / Double(expected))
                }
            }
        }
        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
        }
        try handle.close()
        try FileManager.default.moveItem(at: tmpURL, to: _whisperModelURL)
    }
}
