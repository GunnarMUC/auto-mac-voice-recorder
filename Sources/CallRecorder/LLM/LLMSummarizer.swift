import Foundation

struct CallSummary: Codable, Hashable {
    var summary: String
    var decisions: [String]
    var team_todos: [String]
    var per_person_todos: [String: [String]]
}

enum LLMError: LocalizedError {
    case ollamaNotRunning
    case noModelSelected
    case generationFailed(String)
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .ollamaNotRunning: return "Ollama not running. Start with: ollama serve"
        case .noModelSelected: return "No LLM model selected."
        case .generationFailed(let msg): return "LLM error: \(msg)"
        case .invalidOutput: return "Invalid summary JSON from LLM."
        }
    }
}

final class LLMSummarizer {
    private let ollama = OllamaManager.shared

    func summarize(transcriptPath: String, model: String) async throws -> CallSummary {
        let transcript = try String(contentsOfFile: transcriptPath, encoding: .utf8)

        let systemPrompt = """
        You are a meeting assistant. Given a transcript with speaker labels, produce:
        1. A concise summary (3-5 sentences).
        2. Key decisions made.
        3. A list of action items with owners if clear, otherwise mark as "Team".
        4. A separate per-person to-do list for each speaker.

        Output ONLY valid JSON. No markdown, no explanation. Use this exact structure:
        {
          "summary": "...",
          "decisions": ["...", "..."],
          "team_todos": ["...", "..."],
          "per_person_todos": {
            "SPEAKER_00": ["...", "..."],
            "SPEAKER_01": ["..."],
            ...
          }
        }
        """

        let fullPrompt = """
        \(systemPrompt)

        Transcript:
        \(transcript)

        JSON:
        """

        let raw = try await ollama.generate(model: model, prompt: fullPrompt)
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let result = try? JSONDecoder().decode(CallSummary.self, from: data)
        else {
            throw LLMError.invalidOutput
        }
        return result
    }
}
