import SwiftUI

struct ContentView: View {
    @ObservedObject var pixelServer: PixelAgentsServerController
    @ObservedObject var terminalSession: TerminalSession

    var body: some View {
        HSplitView {
            PixelAgentsPane(pixelServer: pixelServer, terminalSession: terminalSession)
                .frame(minWidth: 480, idealWidth: 680)

            TerminalPane(terminalSession: terminalSession)
                .frame(minWidth: 560, idealWidth: 760)
        }
        .background(.regularMaterial)
    }
}
