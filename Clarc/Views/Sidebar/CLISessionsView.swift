import SwiftUI
import ClarcCore

// MARK: - CLI Sessions Tab

/// Standalone sidebar tab that reads Claude Code CLI sessions directly from
/// ~/.claude/projects/ and ~/.claude/history.jsonl. No mixing with AppState
/// session logic — this is a read-only view into CLI history.
struct CLISessionsView: View {
    @Environment(AppState.self) private var appState
    @Environment(WindowState.self) private var windowState
    @State private var cliProjects: [CLIProject] = []
    @State private var expandedProjects: Set<String> = []
    @State private var expandedGroups: Set<String> = []
    @State private var sessionTitles: [String: String] = [:]
    @State private var isLoading = true
    @State private var focusedItem: FocusItem?
    @State private var groupAssignments: [String: String] = {
        (UserDefaults.standard.dictionary(forKey: "cliSessionGroupAssignments") as? [String: String]) ?? [:]
    }()
    @State private var groupEditorTarget: GroupEditorTarget? = nil

    // Grouped layout is automatic: show it whenever at least one group has been created.
    private var isGrouped: Bool { !allGroupNames.isEmpty }

    // Derived group name → projects list (named groups first, Ungrouped last).
    private var groupedProjects: [(groupName: String, projects: [CLIProject])] {
        var dict: [String: [CLIProject]] = [:]
        for project in cliProjects {
            let group = groupAssignments[project.path] ?? ""
            dict[group, default: []].append(project)
        }
        return dict.map { ($0.key, $0.value) }
            .sorted { a, b in
                if a.0.isEmpty { return false }
                if b.0.isEmpty { return true }
                return a.0.localizedCaseInsensitiveCompare(b.0) == .orderedAscending
            }
    }

    private var allGroupNames: [String] {
        Array(Set(groupAssignments.values)).filter { !$0.isEmpty }.sorted()
    }

    private var visibleItems: [FocusItem] {
        var items: [FocusItem] = []
        if isGrouped {
            for (group, projects) in groupedProjects {
                let groupKey = group.isEmpty ? "__ungrouped__" : group
                items.append(.group(groupKey))
                guard expandedGroups.contains(groupKey) else { continue }
                for project in projects {
                    items.append(.folder(project.id))
                    if expandedProjects.contains(project.id) {
                        items.append(contentsOf: project.sessions.map { .session($0.id) })
                    }
                }
            }
        } else {
            for project in cliProjects {
                items.append(.folder(project.id))
                if expandedProjects.contains(project.id) {
                    items.append(contentsOf: project.sessions.map { .session($0.id) })
                }
            }
        }
        return items
    }

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
                    .onKeyPress(.upArrow) { moveFocus(-1); return .handled }
                    .onKeyPress(.downArrow) { moveFocus(1); return .handled }
                    .onKeyPress(.rightArrow) { expandFocused(); return .handled }
                    .onKeyPress(.leftArrow) { collapseFocused(); return .handled }
                    .onKeyPress(.return) { activateFocused(); return .handled }
            }
        }
        .task { await loadCLISessions() }
        .sheet(item: $groupEditorTarget) { target in
            GroupNameEditorSheet(target: target) { newName in
                applyGroupEdit(target: target, name: newName)
            }
        }
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
            if isGrouped {
                ForEach(groupedProjects, id: \.groupName) { entry in
                    let groupKey = entry.groupName.isEmpty ? "__ungrouped__" : entry.groupName
                    let label = entry.groupName.isEmpty ? "Ungrouped" : entry.groupName
                    let totalSessions = entry.projects.reduce(0) { $0 + $1.sessions.count }

                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedGroups.contains(groupKey) },
                            set: { if $0 { expandedGroups.insert(groupKey) } else { expandedGroups.remove(groupKey) } }
                        )
                    ) {
                        ForEach(entry.projects) { project in
                            projectDisclosure(project)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(entry.groupName.isEmpty ? ClaudeTheme.textTertiary : ClaudeTheme.accent)
                            Text(label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(entry.groupName.isEmpty ? ClaudeTheme.textTertiary : .primary)
                            Spacer()
                            Text("\(totalSessions)")
                                .font(.system(size: 11))
                                .foregroundStyle(ClaudeTheme.textTertiary)
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            if !entry.groupName.isEmpty {
                                Button {
                                    groupEditorTarget = GroupEditorTarget(kind: .rename(from: entry.groupName), projectPath: nil)
                                } label: {
                                    Label("Rename Group…", systemImage: "pencil")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    deleteGroup(named: entry.groupName)
                                } label: {
                                    Label("Delete Group", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            } else {
                ForEach(cliProjects) { project in
                    projectDisclosure(project)
                }
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func projectDisclosure(_ project: CLIProject) -> some View {
        let currentGroup = groupAssignments[project.path]

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
                    if let grp = currentGroup {
                        Text(grp)
                            .font(.system(size: 9))
                            .foregroundStyle(ClaudeTheme.accent.opacity(0.7))
                            .lineLimit(1)
                    }
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
            .contentShape(Rectangle())
            .contextMenu {
                groupingContextMenu(for: project)
                Divider()
                Button {
                    if let first = project.sessions.first {
                        resumeCLISession(first, projectPath: project.path)
                    }
                } label: {
                    Label("Resume Latest Session", systemImage: "play.fill")
                }
                .disabled(project.sessions.isEmpty)
            }
        }
    }

    @ViewBuilder
    private func groupingContextMenu(for project: CLIProject) -> some View {
        let currentGroup = groupAssignments[project.path]

        Menu("Group") {
            ForEach(allGroupNames, id: \.self) { name in
                Button {
                    groupAssignments[project.path] = name
                    saveGroupAssignments()
                    expandedGroups.insert(name)
                } label: {
                    Label(name, systemImage: currentGroup == name ? "checkmark" : "folder")
                }
            }

            if !allGroupNames.isEmpty { Divider() }

            Button {
                groupEditorTarget = GroupEditorTarget(kind: .create, projectPath: project.path)
            } label: {
                Label("New Group…", systemImage: "plus")
            }

            if currentGroup != nil {
                Divider()
                Button(role: .destructive) {
                    groupAssignments.removeValue(forKey: project.path)
                    saveGroupAssignments()
                } label: {
                    Label("Remove from Group", systemImage: "xmark.circle")
                }
            }
        }
    }

    private func cliSessionRow(_ session: CLISession, projectPath: String) -> some View {
        Button {
            focusedItem = .session(session.id)
            loadPreview(session, projectPath: projectPath)
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
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(focusedItem == .session(session.id) ? ClaudeTheme.accent.opacity(0.15) : .clear)
                .padding(.horizontal, -4)
        )
        .contextMenu {
            Button {
                resumeCLISession(session, projectPath: projectPath)
            } label: {
                Label("Resume Session", systemImage: "play.fill")
            }

            Divider()

            if let project = cliProjects.first(where: { $0.path == projectPath }) {
                groupingContextMenu(for: project)
            }

            Divider()

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

    // MARK: - Load Preview

    private func loadPreview(_ session: CLISession, projectPath: String) {
        let encoded = AppState.claudeProjectDirName(for: projectPath)
        let home = FileManager.default.homeDirectoryForCurrentUser
        let file = home.appendingPathComponent(".claude/projects/\(encoded)/\(session.id).jsonl")

        var messages: [String] = []
        if let data = try? Data(contentsOf: file), let text = String(data: data, encoding: .utf8) {
            let lines = text.components(separatedBy: "\n").reversed()
            for line in lines where messages.count < 3 {
                guard !line.isEmpty,
                      let ld = line.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: ld) as? [String: Any],
                      let type = obj["type"] as? String, type == "user",
                      let msg = obj["message"] as? [String: Any],
                      let content = msg["content"] as? String,
                      !content.hasPrefix("<") else { continue }
                let clean = String(content.prefix(120))
                if !clean.isEmpty { messages.append(clean) }
            }
            if messages.isEmpty {
                for line in lines where messages.count < 3 {
                    guard !line.isEmpty,
                          let ld = line.data(using: .utf8),
                          let obj = try? JSONSerialization.jsonObject(with: ld) as? [String: Any],
                          let type = obj["type"] as? String, type == "user",
                          let msg = obj["message"] as? [String: Any],
                          let content = msg["content"] as? [[String: Any]] else { continue }
                    for block in content {
                        if let text = block["text"] as? String, !text.hasPrefix("<"), !text.isEmpty {
                            messages.append(String(text.prefix(120)))
                            break
                        }
                    }
                }
            }
        }

        guard windowState.selectedProject == nil else { return }
        windowState.previewCLISession = CLISessionPreview(
            sessionId: session.id,
            title: session.title,
            projectPath: projectPath,
            modifiedAt: session.modifiedAt,
            recentMessages: messages.reversed()
        )
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

    // MARK: - Keyboard Navigation

    private func moveFocus(_ delta: Int) {
        let items = visibleItems
        guard !items.isEmpty else { return }
        guard let current = focusedItem, let idx = items.firstIndex(of: current) else {
            focusedItem = items.first; return
        }
        let next = idx + delta
        guard items.indices.contains(next) else { return }
        focusedItem = items[next]
    }

    private func expandFocused() {
        switch focusedItem {
        case .group(let id): expandedGroups.insert(id)
        case .folder(let id): expandedProjects.insert(id)
        case .session, .none: break
        }
    }

    private func collapseFocused() {
        switch focusedItem {
        case .group(let id):
            expandedGroups.remove(id)
        case .folder(let id):
            expandedProjects.remove(id)
            if isGrouped {
                for (group, projects) in groupedProjects where projects.contains(where: { $0.id == id }) {
                    focusedItem = .group(group.isEmpty ? "__ungrouped__" : group)
                    break
                }
            }
        case .session(let sid):
            if let project = cliProjects.first(where: { $0.sessions.contains { $0.id == sid } }) {
                expandedProjects.remove(project.id)
                focusedItem = .folder(project.id)
            }
        case .none: break
        }
    }

    private func activateFocused() {
        switch focusedItem {
        case .group(let id):
            if expandedGroups.contains(id) { expandedGroups.remove(id) } else { expandedGroups.insert(id) }
        case .folder(let id):
            if expandedProjects.contains(id) { expandedProjects.remove(id) } else { expandedProjects.insert(id) }
        case .session(let sid):
            if let project = cliProjects.first(where: { $0.sessions.contains { $0.id == sid } }),
               let session = project.sessions.first(where: { $0.id == sid }) {
                loadPreview(session, projectPath: project.path)
            }
        case .none: break
        }
    }

    // MARK: - Group Operations

    private func applyGroupEdit(target: GroupEditorTarget, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        switch target.kind {
        case .create:
            if let path = target.projectPath {
                groupAssignments[path] = trimmed
                expandedGroups.insert(trimmed)
            }
        case .rename(let oldName):
            for (path, group) in groupAssignments where group == oldName {
                groupAssignments[path] = trimmed
            }
            if expandedGroups.contains(oldName) {
                expandedGroups.remove(oldName)
                expandedGroups.insert(trimmed)
            }
        }
        saveGroupAssignments()
    }

    private func deleteGroup(named groupName: String) {
        for (path, group) in groupAssignments where group == groupName {
            groupAssignments.removeValue(forKey: path)
        }
        expandedGroups.remove(groupName)
        saveGroupAssignments()
    }

    // MARK: - Delete Session

    private func deleteCLISession(_ session: CLISession, projectPath: String) {
        let encoded = AppState.claudeProjectDirName(for: projectPath)
        let file = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects/\(encoded)/\(session.id).jsonl")
        try? FileManager.default.removeItem(at: file)
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
        if !appState.projects.contains(where: { $0.path == projectPath }) {
            let name = URL(fileURLWithPath: projectPath).lastPathComponent
            appState.addProject(Project(name: name, path: projectPath, gitHubRepo: nil))
        }
        guard let project = appState.projects.first(where: { $0.path == projectPath }) else { return }
        if windowState.selectedProject?.id != project.id {
            appState.openProjectIds.insert(project.id)
            windowState.selectedProject = project
            UserDefaults.standard.set(project.id.uuidString, forKey: "selectedProjectId")
        }
        let chatSession = ChatSession(
            id: session.id, projectId: project.id, title: session.title,
            messages: [], createdAt: session.modifiedAt, updatedAt: session.modifiedAt
        )
        if !appState.allSessionSummaries.contains(where: { $0.id == session.id }) {
            appState.allSessionSummaries.insert(chatSession.summary, at: 0)
            Task { try? await appState.persistence.saveSession(chatSession) }
        }
        windowState.previewCLISession = nil
        Task { await appState.resumeSession(chatSession, in: windowState) }
    }

    // MARK: - Persistence

    private func saveGroupAssignments() {
        UserDefaults.standard.set(groupAssignments, forKey: "cliSessionGroupAssignments")
    }

    // MARK: - Load

    private func loadCLISessions() async {
        isLoading = true
        defer { isLoading = false }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let projectsDir = home.appendingPathComponent(".claude/projects")
        let fm = FileManager.default

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
        if let first = cliProjects.first { expandedProjects.insert(first.id) }
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private func formattedDate(_ date: Date) -> String {
        Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Group Name Editor Sheet

struct GroupEditorTarget: Identifiable {
    enum Kind {
        case create
        case rename(from: String)
    }
    let id = UUID()
    let kind: Kind
    let projectPath: String?

    var title: String {
        switch kind {
        case .create: return "New Group"
        case .rename: return "Rename Group"
        }
    }

    var placeholder: String {
        switch kind {
        case .create: return "e.g. Work, Personal…"
        case .rename(let old): return old
        }
    }
}

struct GroupNameEditorSheet: View {
    let target: GroupEditorTarget
    let onConfirm: (String) -> Void

    @State private var name: String = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text(target.title)
                .font(.headline)
            TextField(target.placeholder, text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
                .focused($fieldFocused)
                .onSubmit { commit() }
            HStack(spacing: 12) {
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { commit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .buttonStyle(.borderedProminent)
                    .tint(ClaudeTheme.accent)
            }
        }
        .padding(24)
        .onAppear {
            if case .rename(let old) = target.kind { name = old }
            fieldFocused = true
        }
    }

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onConfirm(trimmed)
        dismiss()
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

enum FocusItem: Hashable {
    case group(String)
    case folder(String)
    case session(String)
}
