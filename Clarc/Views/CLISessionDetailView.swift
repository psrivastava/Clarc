import SwiftUI
import ClarcCore

struct CLISessionDetailView: View {
    let preview: CLISessionPreview
    @Environment(AppState.self) private var appState
    @Environment(WindowState.self) private var windowState

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "terminal")
                    .font(.system(size: 40))
                    .foregroundStyle(ClaudeTheme.accent)

                VStack(spacing: 4) {
                    Text(preview.title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(ClaudeTheme.textPrimary)
                    Text(preview.projectPath)
                        .font(.caption)
                        .foregroundStyle(ClaudeTheme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }

                HStack(spacing: 16) {
                    Label(String(preview.sessionId.prefix(8)) + "…", systemImage: "number")
                    Label(preview.modifiedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                }
                .font(.system(size: 12))
                .foregroundStyle(ClaudeTheme.textSecondary)

                if !preview.recentMessages.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Messages")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ClaudeTheme.textTertiary)
                            .textCase(.uppercase)
                        ForEach(preview.recentMessages, id: \.self) { msg in
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(ClaudeTheme.accent)
                                Text(msg)
                                    .font(.system(size: 13))
                                    .foregroundStyle(ClaudeTheme.textSecondary)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(ClaudeTheme.surfaceSecondary.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .frame(maxWidth: 500)
                }

                Button { resume() } label: {
                    Label("Resume Session", systemImage: "play.fill")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(ClaudeTheme.accent)
                .controlSize(.large)
            }
            .padding(40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ClaudeTheme.background)
    }

    private func resume() {
        let p = preview
        if !appState.projects.contains(where: { $0.path == p.projectPath }) {
            appState.addProject(Project(name: URL(fileURLWithPath: p.projectPath).lastPathComponent, path: p.projectPath, gitHubRepo: nil))
        }
        guard let project = appState.projects.first(where: { $0.path == p.projectPath }) else { return }

        if windowState.selectedProject?.id != project.id {
            appState.openProjectIds.insert(project.id)
            windowState.selectedProject = project
            UserDefaults.standard.set(project.id.uuidString, forKey: "selectedProjectId")
        }

        let session = ChatSession(id: p.sessionId, projectId: project.id, title: p.title, messages: [], createdAt: p.modifiedAt, updatedAt: p.modifiedAt)
        if !appState.allSessionSummaries.contains(where: { $0.id == p.sessionId }) {
            appState.allSessionSummaries.insert(session.summary, at: 0)
            Task { try? await appState.persistence.saveSession(session) }
        }
        windowState.previewCLISession = nil
        Task { await appState.resumeSession(session, in: windowState) }
    }
}
