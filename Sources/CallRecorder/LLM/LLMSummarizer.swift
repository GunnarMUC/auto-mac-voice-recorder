import Foundation

struct CallSummary: Codable, Hashable {
    var summary: String
    var decisions: [String]
    var team_todos: [String]
    var per_person_todos: [String: [String]]
}

enum LLMError: LocalizedError {
    case pythonNotFound
    case scriptNotFound
    case modelNotDownloaded
    case executionFailed(String)
    case invalidOutput
    case setupRequired

    var errorDescription: String? {
        switch self {
        case .pythonNotFound: return "Python 3 not found."
        case .scriptNotFound: return "Summarizer script not found."
        case .modelNotDownloaded: return "LLM model not downloaded yet."
        case .executionFailed(let msg): return "Summarization failed: \(msg)"
        case .invalidOutput: return "Invalid summary output."
        case .setupRequired: return "Run Scripts/setup.sh to install MLX."
        }
    }
}

final class LLMSummarizer {
    private let queue = DispatchQueue(label: "llm", qos: .userInitiated)

    func findScript() -> URL? {
        let candidates = [
            URL(fileURLWithPath: "Scripts/summarize.py"),
            URL(fileURLWithPath: "../Scripts/summarize.py"),
            Bundle.main.resourceURL?.appending(component: "Scripts/summarize.py"),
        ]
        for url in candidates {
            if let url, FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    func findPython() -> URL? {
        let candidates = [
            URL(fileURLWithPath: "/usr/local/bin/python3"),
            URL(fileURLWithPath: "/opt/homebrew/bin/python3"),
            URL(fileURLWithPath: "/usr/bin/python3"),
            URL(fileURLWithPath: "Scripts/.venv/bin/python3"),
        ]
        for url in candidates {
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    func summarize(transcriptPath: String) async throws -> CallSummary {
        guard let scriptURL = findScript() else { throw LLMError.scriptNotFound }
        guard let pythonURL = findPython() else { throw LLMError.pythonNotFound }

        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                let process = Process()
                process.executableURL = pythonURL
                process.arguments = [scriptURL.path, transcriptPath]

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

                    guard process.terminationStatus == 0 else {
                        let errMsg = String(data: errData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: LLMError.executionFailed(errMsg))
                        return
                    }

                    let decoder = JSONDecoder()
                    guard let result = try? decoder.decode(CallSummary.self, from: outData) else {
                        continuation.resume(throwing: LLMError.invalidOutput)
                        return
                    }
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: LLMError.executionFailed(error.localizedDescription))
                }
            }
        }
    }
}
