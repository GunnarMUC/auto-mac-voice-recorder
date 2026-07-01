import Foundation

final class ModelManager {
    static let shared = ModelManager()

    let modelsDir: URL
    let whisperModelURL: URL

    private let fallbackURL: URL

    private init() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appending(component: "CallRecorder", directoryHint: .isDirectory)
        modelsDir = appSupport.appending(component: "models", directoryHint: .isDirectory)
        whisperModelURL = modelsDir.appending(component: "ggml-base.bin")

        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        fallbackURL = cwd.appending(path: "Dependencies/whisper.spm/models/ggml-base.bin")

        try? fm.createDirectory(at: modelsDir, withIntermediateDirectories: true)

        if !fm.fileExists(atPath: whisperModelURL.path) && fm.fileExists(atPath: fallbackURL.path) {
            try? fm.copyItem(at: fallbackURL, to: whisperModelURL)
        }
    }

    var modelExists: Bool {
        FileManager.default.fileExists(atPath: whisperModelURL.path)
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
        try FileManager.default.moveItem(at: tmpURL, to: whisperModelURL)
    }
}
