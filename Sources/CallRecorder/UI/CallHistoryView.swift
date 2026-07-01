import SwiftUI

struct CallHistoryView: View {
    @Environment(AppState.self) var state

    var body: some View {
        List(state.calls) { call in
            Button(action: { state.selectCall(call) }) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        statusIcon(call.status)
                        Text(call.title)
                            .font(.headline)
                            .lineLimit(1)
                        Spacer()
                        Text(call.formattedDuration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(call.formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Call History")
        .onAppear { state.loadCalls() }
    }

    private func statusIcon(_ status: CallStatus) -> some View {
        switch status {
        case .recording: return Image(systemName: "record.circle").foregroundStyle(.red)
        case .processing: return Image(systemName: "gear").foregroundStyle(.orange)
        case .completed: return Image(systemName: "checkmark.circle").foregroundStyle(.green)
        case .error: return Image(systemName: "exclamationmark.circle").foregroundStyle(.red)
        }
    }
}
