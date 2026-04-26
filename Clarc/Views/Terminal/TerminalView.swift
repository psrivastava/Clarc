import SwiftUI
import ClarcCore
import SwiftTerm

// MARK: - TerminalProcess

/// Reference type that manages the lifecycle of a terminal process.
final class TerminalProcess {
    var terminalView: LocalProcessTerminalView?
    private(set) var terminated = false

    func terminate() {
        guard !terminated else { return }
        terminated = true
        terminalView?.terminate()
        terminalView = nil
    }

    deinit {
        terminalView?.terminate()
    }
}

// MARK: - EmbeddedTerminalView

struct EmbeddedTerminalView: NSViewRepresentable {

    let executable: String
    let arguments: [String]
    var environment: [String]?
    var currentDirectory: String?
    var initialCommand: String?
    var onProcessTerminated: ((Int32) -> Void)?
    var process: TerminalProcess?
    var fontName: String = "Menlo-Regular"
    var fontSize: Double = 13
    var colorScheme: String = "default"

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let tv = LocalProcessTerminalView(frame: .zero)

        // Apply font
        let termFont = NSFont(name: fontName, size: CGFloat(fontSize))
            ?? NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        tv.font = termFont

        // Apply color scheme
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let colors = TerminalColorSchemes.colors(for: colorScheme, isDark: isDark)
        tv.nativeBackgroundColor = colors.background
        tv.nativeForegroundColor = colors.foreground
        if let ansi = colors.ansi {
            tv.installColors(ansi)
        }

        tv.processDelegate = context.coordinator
        tv.startProcess(
            executable: executable,
            args: arguments,
            environment: resolvedEnvironment(),
            currentDirectory: currentDirectory
        )

        process?.terminalView = tv

        if let cmd = initialCommand {
            pollAndSend(tv: tv, command: cmd)
        }

        // Auto-focus after being added to the window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            tv.window?.makeFirstResponder(tv)
        }

        return tv
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onTerminated: onProcessTerminated)
    }

    /// Build an environment array that guarantees UTF-8 locale so Korean and other
    /// multibyte characters render correctly in the terminal.
    private func resolvedEnvironment() -> [String] {
        // Start from SwiftTerm's defaults (TERM=xterm-256color, COLORTERM=truecolor)
        // to preserve color support, then override LANG/LC_CTYPE for UTF-8.
        let base = environment ?? Terminal.getEnvironmentVariables(termName: "xterm-256color")
        var env: [String: String] = [:]
        for entry in base {
            let parts = entry.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            env[String(parts[0])] = String(parts[1])
        }
        if env["LANG"] == nil || !(env["LANG"]?.hasSuffix("UTF-8") ?? false) {
            env["LANG"] = "en_US.UTF-8"
        }
        env["LC_CTYPE"] = "UTF-8"
        return env.map { "\($0.key)=\($0.value)" }
    }

    private func pollAndSend(tv: LocalProcessTerminalView, command: String, attempt: Int = 0) {
        guard attempt < 30 else { return }
        let proc = process
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard proc?.terminated != true else { return }
            let terminal = tv.getTerminal()
            let firstLine = terminal.getLine(row: 0)?.translateToString(trimRight: true) ?? ""
            if !firstLine.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    guard proc?.terminated != true else { return }
                    tv.send(data: Array((command + "\r").utf8)[...])
                }
            } else {
                self.pollAndSend(tv: tv, command: command, attempt: attempt + 1)
            }
        }
    }

    final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        nonisolated(unsafe) let onTerminated: ((Int32) -> Void)?

        nonisolated init(onTerminated: ((Int32) -> Void)?) {
            self.onTerminated = onTerminated
        }

        nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        nonisolated func processTerminated(source: TerminalView, exitCode: Int32?) {
            onTerminated?(exitCode ?? -1)
        }
    }
}

// MARK: - Interactive Terminal Popup

struct InteractiveTerminalPopup: View {
    @Environment(AppState.self) private var appState
    @Environment(WindowState.self) private var windowState
    @Environment(\.dismiss) private var environmentDismiss
    let state: InteractiveTerminalState
    @State private var processExited = false
    @State private var exitCode: Int32 = 0
    @State private var process = TerminalProcess()
    @State private var eventMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .foregroundStyle(ClaudeTheme.accent)
                Text(state.title)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(ClaudeTheme.textPrimary)

                Spacer()

                if processExited {
                    HStack(spacing: 4) {
                        Image(systemName: exitCode == 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(exitCode == 0 ? ClaudeTheme.statusSuccess : ClaudeTheme.statusError)
                        Text(exitCode == 0 ? "exit 0" : "exit \(exitCode)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(ClaudeTheme.textTertiary)
                    }
                }

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("w", modifiers: .command)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            ClaudeThemeDivider()

            // Terminal
            EmbeddedTerminalView(
                executable: state.executable,
                arguments: state.arguments,
                environment: state.environment,
                currentDirectory: state.currentDirectory,
                initialCommand: state.initialCommand,
                onProcessTerminated: { code in
                    Task { @MainActor in
                        exitCode = code
                        processExited = true
                    }
                },
                process: process,
                fontName: appState.terminalFontName,
                fontSize: appState.terminalFontSize,
                colorScheme: appState.terminalColorScheme
            )
            .padding(8)
            .background(ClaudeTheme.codeBackground)
            .frame(minHeight: 700)
        }
        .frame(minWidth: 800, idealWidth: 900, minHeight: 760, idealHeight: 860)
        .background(ClaudeTheme.surfaceElevated)
        .onAppear {
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // keyCode 53 = Escape
                if event.keyCode == 53 {
                    dismiss()
                    return nil
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
            dismiss()
        }
    }

    private func dismiss() {
        process.terminate()
        if windowState.interactiveTerminal != nil {
            appState.dismissInteractiveTerminal(exitCode: exitCode, in: windowState)
        } else {
            environmentDismiss()
        }
    }
}

// MARK: - Terminal Color Schemes

enum TerminalColorSchemes {
    struct TermColors {
        let background: NSColor
        let foreground: NSColor
        let ansi: [SwiftTerm.Color]?
    }

    private static func c(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> SwiftTerm.Color {
        SwiftTerm.Color(red: UInt16(r) << 8, green: UInt16(g) << 8, blue: UInt16(b) << 8)
    }

    private static func ns(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> NSColor {
        NSColor(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)
    }

    static func colors(for scheme: String, isDark: Bool) -> TermColors {
        switch scheme {
        case "solarizedDark":
            return TermColors(
                background: ns(0, 43, 54), foreground: ns(131, 148, 150),
                ansi: [c(7,54,66), c(220,50,47), c(133,153,0), c(181,137,0),
                       c(38,139,210), c(211,54,130), c(42,161,152), c(238,232,213),
                       c(0,43,54), c(203,75,22), c(88,110,117), c(101,123,131),
                       c(131,148,150), c(108,113,196), c(147,161,161), c(253,246,227)])
        case "solarizedLight":
            return TermColors(
                background: ns(253, 246, 227), foreground: ns(101, 123, 131),
                ansi: [c(238,232,213), c(220,50,47), c(133,153,0), c(181,137,0),
                       c(38,139,210), c(211,54,130), c(42,161,152), c(7,54,66),
                       c(253,246,227), c(203,75,22), c(147,161,161), c(131,148,150),
                       c(101,123,131), c(108,113,196), c(88,110,117), c(0,43,54)])
        case "dracula":
            return TermColors(
                background: ns(40, 42, 54), foreground: ns(248, 248, 242),
                ansi: [c(33,34,44), c(255,85,85), c(80,250,123), c(241,250,140),
                       c(98,114,164), c(255,121,198), c(139,233,253), c(248,248,242),
                       c(68,71,90), c(255,110,110), c(105,255,148), c(255,255,165),
                       c(123,139,189), c(255,146,223), c(164,255,255), c(255,255,255)])
        case "nord":
            return TermColors(
                background: ns(46, 52, 64), foreground: ns(216, 222, 233),
                ansi: [c(59,66,82), c(191,97,106), c(163,190,140), c(235,203,139),
                       c(129,161,193), c(180,142,173), c(136,192,208), c(229,233,240),
                       c(76,86,106), c(191,97,106), c(163,190,140), c(235,203,139),
                       c(129,161,193), c(180,142,173), c(143,188,187), c(236,239,244)])
        case "monokai":
            return TermColors(
                background: ns(39, 40, 34), foreground: ns(248, 248, 242),
                ansi: [c(39,40,34), c(249,38,114), c(166,226,46), c(244,191,117),
                       c(102,217,239), c(174,129,255), c(161,239,228), c(248,248,242),
                       c(117,113,94), c(249,38,114), c(166,226,46), c(244,191,117),
                       c(102,217,239), c(174,129,255), c(161,239,228), c(249,248,245)])
        default:
            let bg: NSColor = isDark ? ns(0x1A, 0x1A, 0x18) : ns(0xE8, 0xE5, 0xDC)
            let fg: NSColor = isDark ? ns(0xCC, 0xC9, 0xC0) : ns(0x3C, 0x39, 0x29)
            return TermColors(background: bg, foreground: fg, ansi: nil)
        }
    }
}