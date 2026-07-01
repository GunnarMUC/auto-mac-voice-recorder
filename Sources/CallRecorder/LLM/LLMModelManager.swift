import Foundation

final class LLMModelManager {
    static let shared = LLMModelManager()

    let modelName = "mlx-community/Llama-3.1-8B-Instruct-4bit"

    private var hfCache: URL {
        URL(fileURLWithPath: NSHomeDirectory() + "/.cache/huggingface/hub")
    }

    var modelExists: Bool {
        let safeName = modelName.replacingOccurrences(of: "/", with: "--")
        let dir = hfCache.appending(component: "models--\(safeName)")
        return FileManager.default.fileExists(atPath: dir.path)
    }
}
