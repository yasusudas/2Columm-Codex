import AppKit
import SwiftUI

struct TerminalEmulatorView: NSViewRepresentable {
    @ObservedObject var session: TerminalSession

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder

        let textView = TerminalTextView()
        textView.session = session
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = NSColor(calibratedWhite: 0.04, alpha: 1.0)
        textView.textColor = .textColor
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = false

        scrollView.documentView = textView
        context.coordinator.textView = textView

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else {
            return
        }
        if textView.string != session.screenText {
            textView.string = session.screenText
            textView.textColor = NSColor(calibratedWhite: 0.88, alpha: 1.0)
            textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            textView.scrollToEndOfDocument(nil)
        }
    }

    final class Coordinator {
        weak var textView: TerminalTextView?
        let session: TerminalSession

        init(session: TerminalSession) {
            self.session = session
        }
    }
}

final class TerminalTextView: NSTextView {
    weak var session: TerminalSession?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            super.keyDown(with: event)
            return
        }

        if event.modifierFlags.contains(.control),
           let character = event.charactersIgnoringModifiers?.lowercased().unicodeScalars.first,
           character.value >= 64,
           character.value <= 127
        {
            session?.send(String(UnicodeScalar(character.value & 0x1F)!))
            return
        }

        switch event.keyCode {
        case 36:
            session?.send("\r")
        case 48:
            session?.send("\t")
        case 51:
            session?.send("\u{7F}")
        case 53:
            session?.send("\u{1B}")
        case 123:
            session?.send("\u{1B}[D")
        case 124:
            session?.send("\u{1B}[C")
        case 125:
            session?.send("\u{1B}[B")
        case 126:
            session?.send("\u{1B}[A")
        default:
            if let characters = event.characters {
                session?.send(characters)
            }
        }
    }
}
