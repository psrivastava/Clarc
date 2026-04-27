import SwiftUI
import ClarcCore

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var step = 0
    @State private var isCheckingCLI = false
    @State private var cliInstalled = false
    @State private var cliVersion: String?
    @State private var cliError: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Group {
                switch step {
                case 0: welcomeStep
                case 1: cliCheckStep
                default: cliCheckStep
                }
            }
            .frame(maxWidth: 460)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            Spacer()

            HStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { i in
                    Circle()
                        .fill(i == step ? ClaudeTheme.accent : ClaudeTheme.textTertiary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: step)
                }
            }
            .padding(.bottom, 16)

            navigationButtons
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 40)
        .frame(width: 560, height: 480)
        .background(ClaudeTheme.background)
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkle")
                .font(.system(size: 56))
                .foregroundStyle(ClaudeTheme.accent)

            VStack(spacing: 8) {
                Text("Welcome to Clarc")
                    .font(.title.weight(.bold))
                    .foregroundStyle(ClaudeTheme.textPrimary)
                Text("A native macOS client for Claude Code CLI")
                    .font(.body)
                    .foregroundStyle(ClaudeTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "bubble.left.and.text.bubble.right", title: "Chat with Claude", description: "Send messages and review AI-generated code")
                FeatureRow(icon: "folder.fill", title: "Project Management", description: "Switch between projects with tabbed interface")
                FeatureRow(icon: "terminal", title: "Built-in Terminal", description: "Run commands without leaving the app")
                FeatureRow(icon: "lock.shield", title: "Permission Control", description: "Review and approve tool actions before execution")
            }
            .padding(16)
        }
    }

    // MARK: - CLI Check

    private var cliCheckStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "terminal")
                .font(.system(size: ClaudeTheme.size(48)))
                .foregroundStyle(ClaudeTheme.accent)

            Text("Claude CLI Installation Check")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(ClaudeTheme.textPrimary)

            if isCheckingCLI {
                ProgressView("Checking...")
            } else if cliInstalled {
                Label("Installed — \(cliVersion ?? "")", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(ClaudeTheme.statusSuccess)
                    .font(.body)
            } else {
                VStack(spacing: 12) {
                    Label("Claude CLI not found", systemImage: "xmark.circle.fill")
                        .foregroundStyle(ClaudeTheme.statusError)
                        .font(.body)

                    if let error = cliError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(ClaudeTheme.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Install command:")
                            .font(.subheadline)
                            .foregroundStyle(ClaudeTheme.textSecondary)
                        HStack {
                            Text("npm install -g @anthropic-ai/claude-code")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(ClaudeTheme.textPrimary)
                                .textSelection(.enabled)
                                .padding(8)
                                .background(ClaudeTheme.codeBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString("npm install -g @anthropic-ai/claude-code", forType: .string)
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .foregroundStyle(ClaudeTheme.textSecondary)
                            }
                            .buttonStyle(.borderless)
                            .help("Copy")
                        }
                    }
                }

                Button("Check Again") {
                    Task { await checkCLI() }
                }
                .buttonStyle(ClaudeSecondaryButtonStyle())
                .padding(.top, 4)
            }
        }
        .task {
            await checkCLI()
        }
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack {
            if step > 0 {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.3)) { step -= 1 }
                }
                .buttonStyle(ClaudeSecondaryButtonStyle())
            }

            Spacer()

            if step == 0 {
                Button("Continue") {
                    withAnimation(.easeInOut(duration: 0.3)) { step = 1 }
                }
                .buttonStyle(ClaudeAccentButtonStyle())
            } else {
                Button("Get Started") {
                    appState.skipGitHubLogin()
                }
                .buttonStyle(ClaudeAccentButtonStyle())
                .disabled(!cliInstalled)
            }
        }
    }

    // MARK: - Helpers

    private func checkCLI() async {
        isCheckingCLI = true
        cliError = nil
        do {
            let version = try await appState.claude.checkVersion()
            cliVersion = version
            cliInstalled = true
            appState.claudeInstalled = true
        } catch {
            cliInstalled = false
            cliError = error.localizedDescription
            let binary = await appState.claude.findClaudeBinary()
            if let binary {
                cliError = "Binary found: \(binary), but version check failed"
                cliInstalled = true
                appState.claudeInstalled = true
            }
        }
        isCheckingCLI = false
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(ClaudeTheme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ClaudeTheme.textPrimary)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(ClaudeTheme.textSecondary)
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
}
