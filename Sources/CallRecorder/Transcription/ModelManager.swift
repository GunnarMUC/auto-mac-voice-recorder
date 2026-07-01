import Foundation

struct WhisperModel: Identifiable, Hashable {
    let id: String
    let name: String
    let filename: String
    let size: String
    let downloadURL: String

    func url(in dir: URL) -> URL { dir.appending(component: filename) }
}

final class ModelManager {
    static let shared = ModelManager()

    static let models: [WhisperModel] = [
        WhisperModel(id: "base", name: "Base (fast)", filename: "ggml-base.bin", size: "141 MB",
                     downloadURL: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"),
        WhisperModel(id: "small", name: "Small (accurate)", filename: "ggml-small.bin", size: "466 MB",
                     downloadURL: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin"),
    ]

    let modelsDir: URL
    private let fm = FileManager.default

    private init() {
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appending(component: "CallRecorder", directoryHint: .isDirectory)
        modelsDir = appSupport.appending(component: "models", directoryHint: .isDirectory)
        try? fm.createDirectory(at: modelsDir, withIntermediateDirectories: true)

        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        for model in Self.models {
            let dest = model.url(in: modelsDir)
            if fm.fileExists(atPath: dest.path) { continue }
            let fallback = cwd.appending(path: "Dependencies/whisper.spm/models/\(model.filename)")
            if fm.fileExists(atPath: fallback.path) {
                try? fm.copyItem(at: fallback, to: dest)
            }
        }
    }

    func modelExists(_ model: WhisperModel) -> Bool {
        fm.fileExists(atPath: model.url(in: modelsDir).path)
    }

    func resolvePath(for model: WhisperModel) -> String? {
        let url = model.url(in: modelsDir)
        if fm.fileExists(atPath: url.path) { return url.path }

        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        let fallback = cwd.appending(path: "Dependencies/whisper.spm/models/\(model.filename)")
        if fm.fileExists(atPath: fallback.path) { return fallback.path }
        return nil
    }

    func download(_ model: WhisperModel, progress: @escaping (Double) -> Void) async throws {
        let dest = model.url(in: modelsDir)
        if fm.fileExists(atPath: dest.path) { return }

        let tmpURL = fm.temporaryDirectory.appending(component: model.filename)
        if fm.fileExists(atPath: tmpURL.path) { try fm.removeItem(at: tmpURL) }

        let url = URL(string: model.downloadURL)!
        fm.createFile(atPath: tmpURL.path, contents: nil)
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
                if expected > 0 { progress(Double(written) / Double(expected)) }
            }
        }
        if !buffer.isEmpty { try handle.write(contentsOf: buffer) }
        try handle.close()
        try fm.moveItem(at: tmpURL, to: dest)
    }

    func availableModels() -> [WhisperModel] {
        Self.models.filter { modelExists($0) }
    }

    var anyModelExists: Bool { !availableModels().isEmpty }
}
