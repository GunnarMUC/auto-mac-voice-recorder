import Foundation

struct OllamaModel: Identifiable, Hashable, Codable {
    let name: String
    var id: String { name }
}

struct OllamaListResponse: Codable {
    let models: [OllamaModelListEntry]
}

struct OllamaModelListEntry: Codable {
    let name: String
}

struct OllamaGenerateResponse: Codable {
    let response: String
    let done: Bool
}

final class OllamaManager {
    static let shared = OllamaManager()
    private let base = URL(string: "http://localhost:11434")!

    func checkRunning() async -> Bool {
        guard let url = URL(string: "http://localhost:11434/api/tags") else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func listModels() async throws -> [OllamaModel] {
        let (data, _) = try await URLSession.shared.data(from: base.appendingPathComponent("api/tags"))
        let decoded = try JSONDecoder().decode(OllamaListResponse.self, from: data)
        return decoded.models.map { OllamaModel(name: $0.name) }
    }

    func generate(model: String, prompt: String) async throws -> String {
        let url = base.appendingPathComponent("api/generate")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        let decoded = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)
        return decoded.response
    }
}
