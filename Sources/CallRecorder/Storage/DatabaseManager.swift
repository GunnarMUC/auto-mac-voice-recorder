import Foundation
import SQLite

final class DatabaseManager {
    private var db: Connection?
    private let queue = DispatchQueue(label: "db")

    private let calls = Table("calls")
    private let segments = Table("transcript_segments")

    private let id = Expression<Int64>("id")
    private let uuid = Expression<String>("uuid")
    private let title = Expression<String?>("title")
    private let startedAt = Expression<Date>("started_at")
    private let endedAt = Expression<Date?>("ended_at")
    private let durationSeconds = Expression<Int?>("duration_seconds")
    private let audioFilePath = Expression<String>("audio_file_path")
    private let status = Expression<String>("status")
    private let summaryJson = Expression<String?>("summary_json")
    private let todosJson = Expression<String?>("todos_json")
    private let createdAt = Expression<Date>("created_at")

    private let segId = Expression<Int64>("id")
    private let callId = Expression<Int64>("call_id")
    private let speakerId = Expression<String>("speaker_id")
    private let startTime = Expression<Double>("start_time")
    private let endTime = Expression<Double>("end_time")
    private let text = Expression<String>("text")

    init() {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appending(component: "CallRecorder", directoryHint: .isDirectory)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appending(component: "database.sqlite3").path
        do {
            db = try Connection(path)
            try createTables()
        } catch {
            print("DB init error: \(error)")
        }
    }

    private func createTables() throws {
        try db?.run(calls.create(ifNotExists: true) { t in
            t.column(id, primaryKey: .autoincrement)
            t.column(uuid, unique: true)
            t.column(title)
            t.column(startedAt)
            t.column(endedAt)
            t.column(durationSeconds)
            t.column(audioFilePath)
            t.column(status)
            t.column(createdAt)
        })
        try db?.run(segments.create(ifNotExists: true) { t in
            t.column(segId, primaryKey: .autoincrement)
            t.column(callId)
            t.column(speakerId)
            t.column(startTime)
            t.column(endTime)
            t.column(text)
            t.foreignKey(callId, references: calls, id)
        })
        try? db?.run(calls.addColumn(summaryJson, defaultValue: nil))
        try? db?.run(calls.addColumn(todosJson, defaultValue: nil))
    }

    func insertCall(uuid: String, audioFilePath: String) -> Int64? {
        queue.sync {
            do {
                let rowid = try db?.run(calls.insert(
                    self.uuid <- uuid,
                    self.startedAt <- Date(),
                    self.audioFilePath <- audioFilePath,
                    self.status <- CallStatus.recording.rawValue,
                    self.createdAt <- Date()
                ))
                return rowid
            } catch {
                print("Insert call error: \(error)")
                return nil
            }
        }
    }

    func updateCall(id: Int64, status: CallStatus, endedAt: Date, duration: Int) {
        _ = queue.sync {
            let call = calls.filter(self.id == id)
            _ = try? db?.run(call.update(
                self.status <- status.rawValue,
                self.endedAt <- endedAt,
                self.durationSeconds <- duration
            ))
        }
    }

    func saveTodos(callId: Int64, todos: [ActionItem]) {
        _ = queue.sync {
            guard let data = try? JSONEncoder().encode(todos),
                  let json = String(data: data, encoding: .utf8)
            else { return }
            let call = calls.filter(self.id == callId)
            _ = try? db?.run(call.update(self.todosJson <- json))
        }
    }

    func fetchTodos(for callId: Int64) -> [ActionItem] {
        queue.sync {
            guard let db else { return [] }
            do {
                for row in try db.prepare(calls.filter(self.id == callId)) {
                    guard let json = row[todosJson],
                          let data = json.data(using: .utf8),
                          let todos = try? JSONDecoder().decode([ActionItem].self, from: data)
                    else { continue }
                    return todos
                }
                return []
            } catch {
                return []
            }
        }
    }

    func saveSummary(callId: Int64, summary: CallSummary) {
        _ = queue.sync {
            guard let data = try? JSONEncoder().encode(summary),
                  let json = String(data: data, encoding: .utf8)
            else { return }
            let call = calls.filter(self.id == callId)
            _ = try? db?.run(call.update(self.summaryJson <- json))
        }
    }

    func markCallCompleted(id: Int64) {
        _ = queue.sync {
            let call = calls.filter(self.id == id)
            _ = try? db?.run(call.update(self.status <- CallStatus.completed.rawValue))
        }
    }

    func markCallError(id: Int64) {
        _ = queue.sync {
            let call = calls.filter(self.id == id)
            _ = try? db?.run(call.update(self.status <- CallStatus.error.rawValue))
        }
    }

    func updateSegmentSpeaker(callId: Int64, startTime: Double, speaker: String) {
        _ = queue.sync {
            let segment = segments.filter(self.callId == callId && self.startTime == startTime)
            _ = try? db?.run(segment.update(self.speakerId <- speaker))
        }
    }

    func insertSegment(callId: Int64, speakerId: String, startTime: Double, endTime: Double, text: String) {
        _ = queue.sync {
            _ = try? db?.run(segments.insert(
                self.callId <- callId,
                self.speakerId <- speakerId,
                self.startTime <- startTime,
                self.endTime <- endTime,
                self.text <- text
            ))
        }
    }

    func fetchAllCalls() -> [CallRecord] {
        queue.sync {
            guard let db else { return [] }
            do {
                var results: [CallRecord] = []
                for row in try db.prepare(calls.order(createdAt.desc)) {
                    let summary: CallSummary? = row[summaryJson].flatMap { json in
                        guard let data = json.data(using: .utf8) else { return nil }
                        return try? JSONDecoder().decode(CallSummary.self, from: data)
                    }
                    results.append(CallRecord(
                        id: row[id],
                        uuid: row[uuid],
                        title: row[title] ?? "Untitled",
                        startedAt: row[startedAt],
                        endedAt: row[endedAt],
                        durationSeconds: row[durationSeconds],
                        audioFilePath: row[audioFilePath],
                        status: CallStatus(rawValue: row[status]) ?? .error,
                        summary: summary?.summary,
                        decisions: summary?.decisions,
                        teamTodos: summary?.team_todos,
                        perPersonTodos: summary?.per_person_todos,
                        actionItems: [],
                        transcriptSegments: []
                    ))
                }
                return results
            } catch {
                print("Fetch error: \(error)")
                return []
            }
        }
    }

    func fetchSegments(for callId: Int64) -> [TranscriptSegment] {
        queue.sync {
            guard let db else { return [] }
            do {
                let query = segments.filter(self.callId == callId).order(startTime)
                var results: [TranscriptSegment] = []
                for row in try db.prepare(query) {
                    results.append(TranscriptSegment(
                        id: row[segId],
                        callId: row[self.callId],
                        speakerId: row[speakerId],
                        startTime: row[startTime],
                        endTime: row[endTime],
                        text: row[text]
                    ))
                }
                return results
            } catch {
                print("Fetch segments error: \(error)")
                return []
            }
        }
    }
}
