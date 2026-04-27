import SwiftUI
import ClarcCore
import os

// MARK: - CLI Sessions Tab

/// Standalone sidebar tab that reads Claude Code CLI sessions directly from
/// ~/.claude/projects/ and ~/.claude/history.jsonl. No mixing with AppState
/// session logic — this is a read-only view into CLI history.
struct CLISessionsView: View {
    @Environment(AppState.self) private var appState
    @Environment(WindowState.self) private var windowState
    @State private var cliProjects: [CLIProject] = []
    @State private var expandedProjects: Set<String> = []
    @State private var sessionTitles: [String: String] = [:]
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if cliProjects.isEmpty {
                emptyState
            } else {
                sessionList
            }
        }
        .task { await loadCLISessions() }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            Text("CLI Sessions")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ClaudeTheme.textTertiary)
                .textCase(.uppercase)

            Spacer()

            Text("\(cliProjects.reduce(0) { $0 + $1.sessions.count })")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ClaudeTheme.textTertiary)

            Button {
                Task { await loadCLISessions() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(ClaudeTheme.textTertiary)
            }
            .buttonStyle(.borderless)
            .help("Refresh")
        }
    }

    // MARK: - Session List

    private var sessionList: some View {
        List {
            ForEach(cliProjects) { project in
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedProjects.contains(project.id) },
                        set: { if $0 { expandedProjects.insert(project.id) } else { expandedProjects.remove(project.id) } }
                    )
                ) {
                    ForEach(project.sessions) { session in
                        cliSessionRow(session, projectPath: project.path)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "terminal")
                                .font(.system(size: 10))
                                .foregroundStyle(ClaudeTheme.accent)
                            Text(project.displayName)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            Text("\(project.sessions.count)")
                                .font(.system(size: 11))
                                .foregroundStyle(ClaudeTheme.textTertiary)
                        }
                        Text(project.path)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary.opacity(0.6))
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func cliSessionRow(_ session: CLISession, projectPath: String) -> some View {
        Button {
            resumeCLISession(session, projectPath: projectPath)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.8))
                    .lineLimit(1)

                Text(formattedDate(session.modifiedAt))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                resumeCLISession(session, projectPath: projectPath)
            } label: {
                Label("Resume Session", systemImage: "play.fill")
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(session.id, forType: .string)
            } label: {
                Label("Copy Session ID", systemImage: "doc.on.doc")
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("claude --resume \(session.id)", forType: .string)
            } label: {
                Label("Copy Resume Command", systemImage: "terminal")
            }

            Divider()

            Button(role: .destructive) {
                deleteCLISession(session, projectPath: projectPath)
            } label: {
                Label("Delete Session", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "terminal")
                .font(.system(size: 20))
                .foregroundStyle(ClaudeTheme.textTertiary)
            Text("No CLI sessions found")
                .font(.system(size: 13))
                .foregroundStyle(ClaudeTheme.textSecondary)
            Text("Run `claude` in a project to create sessions")
                .font(.system(size: 11))
                .foregroundStyle(ClaudeTheme.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Delete

    private func deleteCLISession(_ session: CLISession, projectPath: String) {
        let encoded = AppState.claudeProjectDirName(for: projectPath)
        let file = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects/\(encoded)/\(session.id).jsonl")
        try? FileManager.default.removeItem(at: file)
        // Remove from local state
        if let pi = cliProjects.firstIndex(where: { $0.path == projectPath }) {
            let filtered = cliProjects[pi].sessions.filter { $0.id != session.id }
            if filtered.isEmpty {
                cliProjects.remove(at: pi)
            } else {
                cliProjects[pi] = CLIProject(path: cliProjects[pi].path, displayName: cliProjects[pi].displayName, sessions: filtered)
            }
        }
    }

    // MARK: - Resume

    private func resumeCLISession(_ session: CLISession, projectPath: String) {
        // Ensure the project exists in Clarc
        if !appState.projects.contains(where: { $0.path == projectPath }) {
            let name = URL(fileURLWithPath: projectPath).lastPathComponent
            appState.addProject(Project(name: name, path: projectPath, gitHubRepo: nil))
        }

        // Select the project and resume the session
        if let project = appState.projects.first(where: { $0.path == projectPath }) {
            appState.selectProject(project, in: windowState)

            // Add session summary if not already tracked
            if !appState.allSessionSummaries.contains(where: { $0.id == session.id }) {
                let chatSession = ChatSession(
                    id: session.id,
                    projectId: project.id,
                    title: session.title,
                    messages: [],
                    createdAt: session.modifiedAt,
                    updatedAt: session.modifiedAt
                )
                appState.allSessionSummaries.insert(chatSession.summary, at: 0)
                Task { try? await appState.persistence.saveSession(chatSession) }
            }

            appState.selectSession(id: session.id, in: windowState)
        }
    }

    // MARK: - Load

    private func loadCLISessions() async {
        isLoading = true
        defer { isLoading = false }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let projectsDir = home.appendingPathComponent(".claude/projects")
        let fm = FileManager.default

        // Load titles from history.jsonl
        var titles: [String: String] = [:]
        let historyFile = home.appendingPathComponent(".claude/history.jsonl")
        if let data = try? Data(contentsOf: historyFile), let text = String(data: data, encoding: .utf8) {
            for line in text.components(separatedBy: "\n") where !line.isEmpty {
                guard let ld = line.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: ld) as? [String: Any],
                      let sid = obj["sessionId"] as? String,
                      titles[sid] == nil,
                      let display = obj["display"] as? String,
                      !display.isEmpty, !display.hasPrefix("/") else { continue }
                titles[sid] = String(display.prefix(80))
            }
        }
        sessionTitles = titles

        // Scan project directories
        guard let dirs = try? fm.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { return }

        var projects: [CLIProject] = []
        for dir in dirs where dir.hasDirectoryPath {
            let decodedPath = AppState.pathFromClaudeProjectDir(dir.lastPathComponent)
            guard fm.fileExists(atPath: decodedPath) else { continue }

            guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) else { continue }

            let sessions: [CLISession] = files
                .filter { $0.pathExtension == "jsonl" }
                .compactMap { file in
                    let sid = file.deletingPathExtension().lastPathComponent
                    let modDate = (try? fm.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date ?? Date()
                    let title = titles[sid] ?? "Session \(sid.prefix(8))"
                    return CLISession(id: sid, title: title, modifiedAt: modDate)
                }
                .sorted { $0.modifiedAt > $1.modifiedAt }

            guard !sessions.isEmpty else { continue }

            let displayName = URL(fileURLWithPath: decodedPath).lastPathComponent
            projects.append(CLIProject(path: decodedPath, displayName: displayName, sessions: sessions))
        }

        cliProjects = projects.sorted { $0.sessions.first?.modifiedAt ?? .distantPast > $1.sessions.first?.modifiedAt ?? .distantPast }

        // Auto-expand first project
        if let first = cliProjects.first {
            expandedProjects.insert(first.id)
        }
    }

    // MARK: - Helpers

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private func formattedDate(_ date: Date) -> String {
        Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Models

struct CLIProject: Identifiable {
    let path: String
    let displayName: String
    let sessions: [CLISession]
    var id: String { path }
}

struct CLISession: Identifiable {
    let id: String
    let title: String
    let modifiedAt: Date
}
