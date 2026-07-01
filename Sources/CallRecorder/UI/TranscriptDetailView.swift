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

            let uniqueSpeakers = Array(Set(call.transcriptSegments.map(\.speakerId))).sorted()
            if !uniqueSpeakers.isEmpty {
                Section("Speaker Names") {
                    ForEach(uniqueSpeakers, id: \.self) { speakerId in
                        HStack {
                            Text(speakerId + ":")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Name", text: Binding(
                                get: { call.speakerNames[speakerId] ?? "" },
                                set: { state.renameSpeaker(callId: call.id, oldId: speakerId, newName: $0) }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }

            if !call.actionItems.isEmpty {
                Section("To-Dos") {
                    ForEach(call.actionItems) { item in
                        Button {
                            state.toggleActionItem(item)
                        } label: {
                            HStack {
                                Image(systemName: item.completed ? "checkmark.square" : "square")
                                    .foregroundStyle(item.completed ? .green : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.task)
                                        .strikethrough(item.completed)
                                        .foregroundStyle(item.completed ? .secondary : .primary)
                                    Text(item.owner)
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section {
                Button {
                    exportMarkdown(call)
                } label: {
                    Label("Export to Markdown", systemImage: "square.and.arrow.up")
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
                            Text(speakerDisplayName(call, seg.speakerId))
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

    private func exportMarkdown(_ call: CallRecord) {
        var md = ""
        md += "# \(call.title)\n\n"
        md += "**Date:** \(call.formattedDate)\n"
        md += "**Duration:** \(call.formattedDuration)\n\n"

        if let summary = call.summary {
            md += "## Summary\n\n\(summary)\n\n"
        }

        if let decisions = call.decisions, !decisions.isEmpty {
            md += "## Decisions\n\n"
            for d in decisions { md += "- \(d)\n" }
            md += "\n"
        }

        if !call.actionItems.isEmpty {
            md += "## To-Dos\n\n"
            for item in call.actionItems {
                let check = item.completed ? "[x]" : "[ ]"
                md += "- \(check) **\(item.owner):** \(item.task)\n"
            }
            md += "\n"
        }

        md += "## Transcript\n\n"
        for seg in call.transcriptSegments {
            let t = timestamp(seg.startTime, seg.endTime)
            md += "**\(seg.speakerId)** [\(t)]: \(seg.text)\n\n"
        }

        let saveURL = URL(fileURLWithPath: NSHomeDirectory() + "/Desktop/\(uuidFilename(from: call)).md")
        try? md.write(to: saveURL, atomically: true, encoding: .utf8)
        NSWorkspace.shared.activateFileViewerSelecting([saveURL])
    }

    private func uuidFilename(from call: CallRecord) -> String {
        let formatter = ISO8601DateFormatter()
        let dateStr = formatter.string(from: call.startedAt)
            .replacingOccurrences(of: ":", with: "-")
            .prefix(19)
        return "Call_\(dateStr)"
    }

    private func speakerDisplayName(_ call: CallRecord, _ id: String) -> String {
        call.speakerNames[id] ?? id
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
