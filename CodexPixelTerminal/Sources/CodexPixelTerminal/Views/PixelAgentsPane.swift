import SwiftUI

struct PixelAgentsPane: View {
    @ObservedObject var pixelServer: PixelAgentsServerController

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Circle()
                    .fill(pixelServer.status.color)
                    .frame(width: 8, height: 8)
                Text("Pixel Agents")
                    .font(.headline)
                Text(pixelServer.status.label)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Spacer()
                Button("Reload") {
                    pixelServer.reload()
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.bar)

            Divider()

            PixelAgentsWebView(url: pixelServer.webURL, reloadToken: pixelServer.reloadToken)
                .overlay(alignment: .bottomLeading) {
                    if !pixelServer.message.isEmpty {
                        Text(pixelServer.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                            .padding(10)
                    }
                }
        }
    }
}

private extension PixelAgentsServerController.Status {
    var label: String {
        switch self {
        case .idle:
            "idle"
        case .starting:
            "starting"
        case .running:
            "running"
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
        case .failed:
            .red
        }
    }
}
