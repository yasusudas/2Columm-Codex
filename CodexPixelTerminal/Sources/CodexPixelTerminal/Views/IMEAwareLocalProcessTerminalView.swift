import AppKit
import SwiftTerm

final class IMEAwareLocalProcessTerminalView: LocalProcessTerminalView {
    private let markedTextView = NSTextField(labelWithString: "")
    private var markedText = ""
    private var markedTextSelection = NSRange(location: 0, length: 0)
    private var markedAttributedText = NSAttributedString(string: "")

    override init(frame: CGRect) {
        super.init(frame: frame)
        installMarkedTextView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        installMarkedTextView()
    }

    override func layout() {
        super.layout()
        positionMarkedTextView()
    }

    func synchronizeMarkedTextAppearance() {
        markedTextView.font = font
        markedTextView.textColor = nativeForegroundColor
        markedTextView.backgroundColor = nativeBackgroundColor.withAlphaComponent(0.97)
        markedTextView.layer?.borderColor = nativeForegroundColor.withAlphaComponent(0.35).cgColor
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        hideMarkedText()

        if let attributedString = string as? NSAttributedString {
            super.insertText(attributedString.string as NSString, replacementRange: replacementRange)
        } else if let text = string as? String {
            super.insertText(text as NSString, replacementRange: replacementRange)
        } else {
            super.insertText(string, replacementRange: replacementRange)
        }
    }

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)

        let text = plainText(from: string)
        guard !text.isEmpty else {
            hideMarkedText()
            return
        }

        markedText = text
        markedTextSelection = normalizedSelection(selectedRange, text: text)
        markedAttributedText = attributedMarkedText(from: string, text: text)
        markedTextView.attributedStringValue = markedAttributedText
        markedTextView.isHidden = false
        synchronizeMarkedTextAppearance()
        positionMarkedTextView()
    }

    override func unmarkText() {
        super.unmarkText()
        hideMarkedText()
    }

    override func hasMarkedText() -> Bool {
        !markedText.isEmpty
    }

    override func markedRange() -> NSRange {
        guard hasMarkedText() else {
            return NSRange(location: NSNotFound, length: 0)
        }
        return NSRange(location: 0, length: (markedText as NSString).length)
    }

    override func selectedRange() -> NSRange {
        guard hasMarkedText() else {
            return super.selectedRange()
        }
        return markedTextSelection
    }

    override func attributedSubstring(
        forProposedRange range: NSRange,
        actualRange: NSRangePointer?
    ) -> NSAttributedString? {
        guard hasMarkedText() else {
            return nil
        }

        let markedRange = markedRange()
        let safeRange = NSIntersectionRange(range, markedRange)
        guard safeRange.location != NSNotFound, safeRange.length > 0 else {
            actualRange?.pointee = NSRange(location: NSNotFound, length: 0)
            return nil
        }

        actualRange?.pointee = safeRange
        return markedAttributedText.attributedSubstring(from: safeRange)
    }

    override func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        [
            .backgroundColor,
            .font,
            .foregroundColor,
            .underlineColor,
            .underlineStyle,
        ]
    }

    override func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        actualRange?.pointee = hasMarkedText() ? markedRange() : range
        return super.firstRect(forCharacterRange: range, actualRange: nil)
    }

    override func characterIndex(for point: NSPoint) -> Int {
        NSNotFound
    }

    private func installMarkedTextView() {
        markedTextView.isHidden = true
        markedTextView.isBordered = false
        markedTextView.isBezeled = false
        markedTextView.isEditable = false
        markedTextView.isSelectable = false
        markedTextView.drawsBackground = true
        markedTextView.focusRingType = .none
        markedTextView.lineBreakMode = .byClipping
        markedTextView.maximumNumberOfLines = 1
        markedTextView.wantsLayer = true
        markedTextView.layer?.cornerRadius = 2
        markedTextView.layer?.borderWidth = 1
        addSubview(markedTextView)
        synchronizeMarkedTextAppearance()
    }

    private func hideMarkedText() {
        markedText = ""
        markedTextSelection = NSRange(location: 0, length: 0)
        markedAttributedText = NSAttributedString(string: "")
        markedTextView.isHidden = true
        markedTextView.stringValue = ""
    }

    private func attributedMarkedText(from value: Any, text: String) -> NSAttributedString {
        let attributed: NSMutableAttributedString
        if let attributedString = value as? NSAttributedString {
            attributed = NSMutableAttributedString(attributedString: attributedString)
        } else {
            attributed = NSMutableAttributedString(string: text)
        }

        let fullRange = NSRange(location: 0, length: attributed.length)
        if attributed.length > 0 {
            attributed.addAttributes(
                [
                    .font: font,
                    .foregroundColor: nativeForegroundColor,
                    .underlineColor: nativeForegroundColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                ],
                range: fullRange
            )
        }

        return attributed
    }

    private func positionMarkedTextView() {
        guard !markedTextView.isHidden else {
            return
        }

        let caretRect = caretRectInLocalCoordinates()
        let inset: CGFloat = 3
        let availableWidth = max(48, bounds.width - caretRect.minX - inset)
        let textSize = markedAttributedText.boundingRect(
            with: NSSize(width: availableWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size
        let height = max(ceil(textSize.height) + 4, ceil(font.ascender - font.descender) + 4)
        let width = min(max(ceil(textSize.width) + 8, 18), max(18, bounds.width - (inset * 2)))
        let x = min(max(caretRect.minX, inset), max(inset, bounds.width - width - inset))
        let y = min(max(caretRect.minY, inset), max(inset, bounds.height - height - inset))

        markedTextView.frame = NSRect(x: x, y: y, width: width, height: height)
    }

    private func caretRectInLocalCoordinates() -> NSRect {
        var actualRange = NSRange(location: 0, length: 0)
        let screenRect = super.firstRect(
            forCharacterRange: NSRange(location: 0, length: 0),
            actualRange: &actualRange
        )

        guard let window, !screenRect.isEmpty else {
            return NSRect(
                x: 4,
                y: max(4, bounds.height - ceil(font.pointSize) - 8),
                width: 1,
                height: ceil(font.pointSize)
            )
        }

        let windowRect = window.convertFromScreen(screenRect)
        return convert(windowRect, from: nil)
    }

    private func plainText(from value: Any) -> String {
        if let attributedString = value as? NSAttributedString {
            return attributedString.string
        }
        if let text = value as? String {
            return text
        }
        if let text = value as? NSString {
            return text as String
        }
        return String(describing: value)
    }

    private func normalizedSelection(_ range: NSRange, text: String) -> NSRange {
        let textLength = (text as NSString).length
        guard range.location != NSNotFound else {
            return NSRange(location: textLength, length: 0)
        }

        let location = min(max(range.location, 0), textLength)
        let remainingLength = textLength - location
        let length = min(max(range.length, 0), remainingLength)
        return NSRange(location: location, length: length)
    }
}
