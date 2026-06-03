import SwiftUI

struct TerminalPane: View {
    @ObservedObject var terminalSession: TerminalSession

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Circle()
                    .fill(terminalSession.status.color)
                    .frame(width: 8, height: 8)
                Text("Codex CLI")
                    .font(.headline)
                if terminalSession.terminalTitle != "Codex CLI" {
                    Text(terminalSession.terminalTitle)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Text(terminalSession.status.label)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Spacer()
                Button("Restart") {
                    terminalSession.restart()
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.bar)

            Divider()

            TerminalEmulatorView(session: terminalSession)
                .background(Color(nsColor: .textBackgroundColor))
        }
    }
}

private extension TerminalSession.Status {
    var label: String {
        switch self {
        case .idle:
            "idle"
        case .starting:
            "starting"
        case .running:
            "running"
        case .exited:
            "exited"
        case .failed:
            "failed"
        }
    }

    var color: Color {
        switch self {
        case .idle:
            .secondary
        case .starting:
            .yellow
        case .running:
            .green
        case .exited:
            .orange
        case .failed:
            .red
        }
    }
}
