import Foundation

struct SpeakerSegment: Codable, Hashable {
    let speaker: String
    let start: TimeInterval
    let end: TimeInterval
}

struct DiarizationResult: Codable {
    let segments: [SpeakerSegment]?
    let error: String?
}

enum DiarizationError: LocalizedError {
    case pythonNotFound
    case scriptNotFound
    case executionFailed(String)
    case invalidOutput
    case setupRequired

    var errorDescription: String? {
        switch self {
        case .pythonNotFound: return "Python 3 not found. Install via 'brew install python'."
        case .scriptNotFound: return "Diarization script not found."
        case .executionFailed(let msg): return "Diarization failed: \(msg)"
        case .invalidOutput: return "Invalid diarization output."
        case .setupRequired: return "Python environment not set up. Run Scripts/setup.sh first."
        }
    }
}

final class SpeakerDiarizer {
    private let queue = DispatchQueue(label: "diarize", qos: .userInitiated)

    func findScript() -> URL? {
        let candidates = [
            URL(fileURLWithPath: "Scripts/diarize.py"),
            URL(fileURLWithPath: "../Scripts/diarize.py"),
            Bundle.main.resourceURL?.appending(component: "Scripts/diarize.py"),
            Bundle.main.resourceURL?.appending(component: "diarize.py"),
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

    func diarize(audioFile path: String) async throws -> [SpeakerSegment] {
        guard let scriptURL = findScript() else { throw DiarizationError.scriptNotFound }
        guard let pythonURL = findPython() else { throw DiarizationError.pythonNotFound }

        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                let process = Process()
                process.executableURL = pythonURL
                process.arguments = [scriptURL.path, path]

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
                        continuation.resume(throwing: DiarizationError.executionFailed(errMsg))
                        return
                    }

                    let decoder = JSONDecoder()
                    guard let result = try? decoder.decode(DiarizationResult.self, from: outData) else {
                        continuation.resume(throwing: DiarizationError.invalidOutput)
                        return
                    }

                    if let error = result.error {
                        continuation.resume(throwing: DiarizationError.executionFailed(error))
                        return
                    }

                    continuation.resume(returning: result.segments ?? [])
                } catch {
                    continuation.resume(throwing: DiarizationError.executionFailed(error.localizedDescription))
                }
            }
        }
    }
}
