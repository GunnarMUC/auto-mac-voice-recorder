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
                    Label("Export Markdown", systemImage: "doc.text")
                }
                Button {
                    exportPDF(call)
                } label: {
                    Label("Export PDF", systemImage: "doc.richtext")
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

    private func exportPDF(_ call: CallRecord) {
        let md = buildMarkdown(call)
        let html = """
        <html><head><meta charset="utf-8"><style>
        body { font-family: -apple-system; padding: 40px; line-height: 1.5; }
        h1 { font-size: 24pt; } h2 { font-size: 18pt; margin-top: 20px; }
        p { margin: 8px 0; } strong { color: #2563eb; }
        </style></head><body>\(md.replacingOccurrences(of: "\n", with: "<br>")
        .replacingOccurrences(of: "## ", with: "<h2>")
        .replacingOccurrences(of: "# ", with: "<h1>")
        .replacingOccurrences(of: "**", with: "<strong>"))
        </body></html>
        """

        let printInfo = NSPrintInfo.shared
        printInfo.topMargin = 20; printInfo.bottomMargin = 20
        printInfo.leftMargin = 40; printInfo.rightMargin = 40

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return }
        var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }

        let graphics = NSGraphicsContext(cgContext: context, flipped: true)
        let attrStr = try? NSAttributedString(
            data: html.data(using: .utf8)!,
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil
        )

        NSGraphicsContext.current = graphics
        let framesetter = CTFramesetterCreateWithAttributedString(attrStr!)
        var page = 0
        let frameRect = CGRect(x: 40, y: 40, width: 515, height: 762)
        var charIndex = 0

        while charIndex < attrStr!.length {
            let path = CGPath(rect: frameRect, transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: charIndex, length: 0), path, nil)
            context.beginPage(mediaBox: &mediaBox)
            CTFrameDraw(frame, context)
            context.endPage()
            let range = CTFrameGetVisibleStringRange(frame)
            if range.length == 0 { break }
            charIndex = range.location + range.length
            page += 1
        }
        NSGraphicsContext.current = nil

        let saveURL = URL(fileURLWithPath: NSHomeDirectory() + "/Desktop/\(uuidFilename(from: call)).pdf")
        pdfData.write(to: saveURL, atomically: true)
        NSWorkspace.shared.activateFileViewerSelecting([saveURL])
    }

    private func buildMarkdown(_ call: CallRecord) -> String {
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
            let name = speakerDisplayName(call, seg.speakerId)
            md += "**\(name)** [\(t)]: \(seg.text)\n\n"
        }
        return md
    }

    private func exportMarkdown(_ call: CallRecord) {
        let md = buildMarkdown(call)
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
