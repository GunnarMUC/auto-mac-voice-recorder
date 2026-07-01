import Foundation

struct CallRecord: Identifiable, Codable, Hashable {
    let id: Int64
    let uuid: String
    var title: String
    let startedAt: Date
    var endedAt: Date?
    var durationSeconds: Int?
    let audioFilePath: String
    var status: CallStatus
    var summary: String?
    var decisions: [String]?
    var teamTodos: [String]?
    var perPersonTodos: [String: [String]]?
    var actionItems: [ActionItem]
    var speakerNames: [String: String]
    var transcriptSegments: [TranscriptSegment]

    var formattedDate: String {
        startedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var formattedDuration: String {
        guard let d = durationSeconds else { return "—" }
        let m = d / 60
        let s = d % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }
}

enum CallStatus: String, Codable, Hashable {
    case recording
    case processing
    case completed
    case error
}

struct TranscriptSegment: Identifiable, Codable, Hashable {
    let id: Int64
    let callId: Int64
    var speakerId: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
}

struct ActionItem: Identifiable, Codable, Hashable {
    var id: String { "\(owner):\(task)" }
    var owner: String
    var task: String
    var completed: Bool
}
