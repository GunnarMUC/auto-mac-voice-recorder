import SwiftUI

struct TranscriptDetailView: View {
    @Environment(AppState.self) var state

    var body: some View {
        Group {
            if let call = state.selectedCall {
                transcriptContent(call)
            } else {
                ContentUnavailableView(
                    "No Call Selected",
                    systemImage: "mic.slash",
                    description: Text("Select a recording from the history.")
                )
            }
        }
    }

    private func transcriptContent(_ call: CallRecord) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(call.title)
                        .font(.title2)
                        .bold()
                    HStack {
                        Label(call.formattedDate, systemImage: "calendar")
                        Spacer()
                        Label(call.formattedDuration, systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            if let summary = call.summary {
                Section("Summary") {
                    Text(summary)
                        .textSelection(.enabled)
                }
            }

            if let decisions = call.decisions, !decisions.isEmpty {
                Section("Decisions") {
                    ForEach(decisions, id: \.self) { d in
                        Label(d, systemImage: "checkmark.circle")
                    }
                }
            }

            if let todos = call.teamTodos, !todos.isEmpty {
                Section("Team To-Dos") {
                    ForEach(todos, id: \.self) { t in
                        Label(t, systemImage: "person.3")
                    }
                }
            }

            if let personTodos = call.perPersonTodos {
                ForEach(Array(personTodos.keys).sorted(), id: \.self) { speaker in
                    if let items = personTodos[speaker], !items.isEmpty {
                        Section("\(speaker) To-Dos") {
                            ForEach(items, id: \.self) { item in
                                Label(item, systemImage: "person")
                            }
                        }
                    }
                }
            }

            if call.transcriptSegments.isEmpty && call.status == .completed {
                Section {
                    Text("No transcript segments found.")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(call.transcriptSegments) { seg in
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(seg.speakerId)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                            Spacer()
                            Text(timestamp(seg.startTime, seg.endTime))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Text(seg.text)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .navigationTitle("Transcript")
    }

    private func timestamp(_ start: TimeInterval, _ end: TimeInterval) -> String {
        let fmt = DateComponentsFormatter()
        fmt.allowedUnits = [.minute, .second]
        fmt.zeroFormattingBehavior = .pad
        let s = fmt.string(from: start) ?? "0:00"
        let e = fmt.string(from: end) ?? "0:00"
        return "\(s) → \(e)"
    }
}
