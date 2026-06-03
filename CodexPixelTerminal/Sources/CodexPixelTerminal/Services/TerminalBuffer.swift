import Foundation

final class TerminalBuffer {
    private enum ParserState {
        case normal
        case escape
        case csi(String)
        case osc
    }

    private let columns: Int
    private let rows: Int
    private var grid: [[Character]]
    private var cursorX = 0
    private var cursorY = 0
    private var savedX = 0
    private var savedY = 0
    private var state: ParserState = .normal

    init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        self.grid = Array(
            repeating: Array(repeating: " ", count: columns),
            count: rows
        )
    }

    func reset() {
        grid = Array(
            repeating: Array(repeating: " ", count: columns),
            count: rows
        )
        cursorX = 0
        cursorY = 0
        state = .normal
    }

    func process(_ text: String) {
        for scalar in text.unicodeScalars {
            process(scalar)
        }
    }

    func render() -> String {
        grid.map { row in
            String(row).trimmingCharacters(in: .whitespaces)
        }
        .joined(separator: "\n")
    }

    private func process(_ scalar: UnicodeScalar) {
        switch state {
        case .normal:
            processNormal(scalar)
        case .escape:
            processEscape(scalar)
        case let .csi(buffer):
            processCSI(buffer: buffer, scalar: scalar)
        case .osc:
            if scalar.value == 7 {
                state = .normal
            }
        }
    }

    private func processNormal(_ scalar: UnicodeScalar) {
        switch scalar.value {
        case 0x1B:
            state = .escape
        case 0x0D:
            cursorX = 0
        case 0x0A:
            lineFeed()
        case 0x08:
            cursorX = max(0, cursorX - 1)
        case 0x09:
            cursorX = min(columns - 1, cursorX + 4)
        case 0x20...0x10FFFF:
            put(Character(String(scalar)))
        default:
            break
        }
    }

    private func processEscape(_ scalar: UnicodeScalar) {
        switch scalar {
        case "[":
            state = .csi("")
        case "]":
            state = .osc
        case "7":
            savedX = cursorX
            savedY = cursorY
            state = .normal
        case "8":
            cursorX = savedX
            cursorY = savedY
            state = .normal
        case "c":
            reset()
        default:
            state = .normal
        }
    }

    private func processCSI(buffer: String, scalar: UnicodeScalar) {
        if scalar.value >= 0x40, scalar.value <= 0x7E {
            handleCSI(final: Character(String(scalar)), params: buffer)
            state = .normal
        } else {
            state = .csi(buffer + String(scalar))
        }
    }

    private func handleCSI(final: Character, params: String) {
        if params.contains("?1049"), final == "h" || final == "l" {
            clearScreen()
            cursorX = 0
            cursorY = 0
            return
        }

        let numbers = params
            .split(separator: ";", omittingEmptySubsequences: false)
            .map { part -> Int in
                let cleaned = part.filter(\.isNumber)
                return Int(cleaned) ?? 0
            }

        func value(_ index: Int, default defaultValue: Int) -> Int {
            guard numbers.indices.contains(index), numbers[index] != 0 else {
                return defaultValue
            }
            return numbers[index]
        }

        switch final {
        case "A":
            cursorY = max(0, cursorY - value(0, default: 1))
        case "B":
            cursorY = min(rows - 1, cursorY + value(0, default: 1))
        case "C":
            cursorX = min(columns - 1, cursorX + value(0, default: 1))
        case "D":
            cursorX = max(0, cursorX - value(0, default: 1))
        case "G":
            cursorX = min(columns - 1, max(0, value(0, default: 1) - 1))
        case "H", "f":
            cursorY = min(rows - 1, max(0, value(0, default: 1) - 1))
            cursorX = min(columns - 1, max(0, value(1, default: 1) - 1))
        case "J":
            if value(0, default: 0) >= 2 {
                clearScreen()
            } else {
                clearFromCursorToEnd()
            }
        case "K":
            clearLineFromCursor()
        case "P":
            deleteCharacters(value(0, default: 1))
        case "X":
            eraseCharacters(value(0, default: 1))
        case "s":
            savedX = cursorX
            savedY = cursorY
        case "u":
            cursorX = savedX
            cursorY = savedY
        default:
            break
        }
    }

    private func put(_ character: Character) {
        guard cursorY >= 0, cursorY < rows else {
            return
        }
        if cursorX >= columns {
            cursorX = 0
            lineFeed()
        }
        grid[cursorY][cursorX] = character
        cursorX += 1
    }

    private func lineFeed() {
        if cursorY >= rows - 1 {
            grid.removeFirst()
            grid.append(Array(repeating: " ", count: columns))
        } else {
            cursorY += 1
        }
    }

    private func clearScreen() {
        grid = Array(
            repeating: Array(repeating: " ", count: columns),
            count: rows
        )
    }

    private func clearFromCursorToEnd() {
        guard cursorY < rows else {
            return
        }
        clearLineFromCursor()
        if cursorY + 1 < rows {
            for row in (cursorY + 1)..<rows {
                grid[row] = Array(repeating: " ", count: columns)
            }
        }
    }

    private func clearLineFromCursor() {
        guard cursorY < rows else {
            return
        }
        for column in cursorX..<columns {
            grid[cursorY][column] = " "
        }
    }

    private func deleteCharacters(_ count: Int) {
        guard cursorY < rows, cursorX < columns else {
            return
        }
        let safeCount = min(count, columns - cursorX)
        for column in cursorX..<(columns - safeCount) {
            grid[cursorY][column] = grid[cursorY][column + safeCount]
        }
        for column in (columns - safeCount)..<columns {
            grid[cursorY][column] = " "
        }
    }

    private func eraseCharacters(_ count: Int) {
        guard cursorY < rows, cursorX < columns else {
            return
        }
        let end = min(columns, cursorX + count)
        for column in cursorX..<end {
            grid[cursorY][column] = " "
        }
    }
}
