import SwiftUI

@main
struct CallRecorderApp: App {
    @State private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environment(state)
        } label: {
            switch state.recordingState {
            case .idle, .needsDownload:
                Image(systemName: "mic")
            case .recording:
                Image(systemName: "mic.fill")
                    .foregroundStyle(.red)
            case .processing:
                Image(systemName: "mic.badge.plus")
            }
        }

        Window("Call History", id: "history") {
            NavigationSplitView {
                CallHistoryView()
                    .environment(state)
            } detail: {
                TranscriptDetailView()
                    .environment(state)
            }
            .frame(minWidth: 600, minHeight: 400)
        }
        .defaultSize(width: 700, height: 500)
    }
}

struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(AppState.self) var state

    var body: some View {
        VStack(spacing: 0) {
            RecordingPanel()
                .environment(state)

            Divider()

            Button {
                state.loadCalls()
                openWindow(id: "history")
            } label: {
                Label("Call History", systemImage: "clock.arrow.circlepath")
            }
            .keyboardShortcut("h")

            Divider()

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Label("Quit", systemImage: "xmark")
            }
            .keyboardShortcut("q")
        }
        .environment(state)
        .task { await state.checkModel() }
    }
}
