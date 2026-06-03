import AppKit
import SwiftUI

@main
struct CodexPixelTerminalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var pixelServer = PixelAgentsServerController()
    @StateObject private var terminalSession = TerminalSession()

    var body: some Scene {
        WindowGroup("Codex Pixel Terminal") {
            ContentView(pixelServer: pixelServer, terminalSession: terminalSession)
                .frame(minWidth: 1280, minHeight: 760)
                .onAppear {
                    pixelServer.start()
                    terminalSession.start()
                }
                .onDisappear {
                    terminalSession.stop()
                }
        }
        .commands {
            CommandMenu("Codex") {
                Button("Restart Codex") {
                    terminalSession.restart()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("Reload Pixel Agents") {
                    pixelServer.reload()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        PixelAgentsServerController.sharedStop()
        TerminalSession.sharedStop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
