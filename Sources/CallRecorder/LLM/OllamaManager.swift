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

    private let hosts = [
        "http://127.0.0.1:11434",
        "http://localhost:11434",
    ]

    func checkRunning() async -> Bool {
        for host in hosts {
            guard let url = URL(string: "\(host)/api/tags") else { continue }
            do {
                let (_, response) = try await URLSession.shared.data(from: url)
                if (response as? HTTPURLResponse)?.statusCode == 200 { return true }
            } catch {
                continue
            }
        }
        return false
    }

    func listModels() async throws -> [OllamaModel] {
        var lastError: Error? = nil
        for host in hosts {
            guard let url = URL(string: "\(host)/api/tags") else { continue }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let decoded = try JSONDecoder().decode(OllamaListResponse.self, from: data)
                return decoded.models.map { OllamaModel(name: $0.name) }
            } catch {
                lastError = error
                continue
            }
        }
        throw lastError ?? URLError(.cannotConnectToHost)
    }

    func generate(model: String, prompt: String) async throws -> String {
        for host in hosts {
            guard let url = URL(string: "\(host)/api/generate") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = [
                "model": model,
                "prompt": prompt,
                "stream": false,
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            do {
                let (data, _) = try await URLSession.shared.data(for: req)
                let decoded = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)
                return decoded.response
            } catch {
                continue
            }
        }
        throw URLError(.cannotConnectToHost)
    }
}
