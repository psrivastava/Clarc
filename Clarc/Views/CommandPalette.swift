import SwiftUI
import ClarcCore
import ClarcChatKit

struct CommandPalette: View {
    @Environment(AppState.self) private var appState
    @Environment(WindowState.self) private var windowState
    @Environment(\.openSettings) private var openSettings
    @Binding var isPresented: Bool

    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                searchField
                ClaudeThemeDivider()
                resultsList
            }
            .frame(width: 520)
            .frame(maxHeight: 400)
            .background(ClaudeTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusMedium))
            .shadow(color: .black.opacity(0.2), radius: 30)
            .padding(.top, 80)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onKeyPress(.escape) { dismiss(); return .handled }
        .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
        .onKeyPress(.downArrow) { moveSelection(1); return .handled }
        .onKeyPress(.return) { executeSelected(); return .handled }
        .onAppear {
            query = ""
            selectedIndex = 0
            isSearchFocused = true
        }
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(ClaudeTheme.textTertiary)
            TextField("Search projects, sessions, actions...", text: $query)
                .font(.system(size: 16))
                .textFieldStyle(.plain)
                .foregroundStyle(ClaudeTheme.textPrimary)
                .focused($isSearchFocused)
                .onChange(of: query) { _, _ in selectedIndex = 0 }
        }
        .padding(16)
    }

    // MARK: - Results

    private var filteredResults: [PaletteItem] {
        let items = allItems
        guard !query.isEmpty else { return Array(items.prefix(12)) }
        let q = query.lowercased()
        return items.filter { $0.title.lowercased().contains(q) || $0.subtitle.lowercased().contains(q) }
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredResults.enumerated()), id: \.element.id) { index, item in
                        PaletteRow(item: item, isSelected: index == selectedIndex)
                            .id(index)
                            .onTapGesture { execute(item) }
                    }
                }
                .padding(4)
            }
            .onChange(of: selectedIndex) { _, newIndex in
                proxy.scrollTo(newIndex, anchor: .center)
            }
        }
    }

    // MARK: - Items

    private var allItems: [PaletteItem] {
        var items: [PaletteItem] = []

        items.append(PaletteItem(icon: "square.and.pencil", title: "New Chat", subtitle: "Start a new conversation", category: "Actions") {
            appState.startNewChat(in: windowState)
        })
        items.append(PaletteItem(icon: "gearshape", title: "Open Settings", subtitle: "App preferences", category: "Actions") {
            openSettings()
        })

        for theme in AppTheme.allCases {
            items.append(PaletteItem(icon: "paintpalette", title: "Theme: \(theme.displayName)", subtitle: "Switch color theme", category: "Themes") {
                appState.selectedTheme = theme
            })
        }

        for project in appState.projects {
            items.append(PaletteItem(icon: "folder.fill", title: project.name, subtitle: project.path, category: "Projects") {
                appState.selectProject(project, in: windowState)
                if !appState.openProjectIds.contains(project.id) {
                    appState.openProjectIds.insert(project.id)
                }
            })
        }

        let summaries = appState.allSessionSummaries.prefix(20)
        for session in summaries {
            items.append(PaletteItem(icon: "bubble.left", title: session.title, subtitle: "Session", category: "Sessions") {
                if let project = appState.projects.first(where: { $0.id == session.projectId }) {
                    appState.selectProject(project, in: windowState)
                    if !appState.openProjectIds.contains(project.id) {
                        appState.openProjectIds.insert(project.id)
                    }
                }
                appState.selectSession(id: session.id, in: windowState)
            })
        }

        return items
    }

    // MARK: - Navigation

    private func moveSelection(_ delta: Int) {
        let count = filteredResults.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + delta + count) % count
    }

    private func executeSelected() {
        guard selectedIndex < filteredResults.count else { return }
        execute(filteredResults[selectedIndex])
    }

    private func execute(_ item: PaletteItem) {
        dismiss()
        item.action()
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.15)) { isPresented = false }
    }
}

// MARK: - Palette Item

struct PaletteItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let category: String
    let action: () -> Void
}

struct PaletteRow: View {
    let item: PaletteItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? ClaudeTheme.accent : ClaudeTheme.textSecondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 14))
                    .foregroundStyle(ClaudeTheme.textPrimary)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(ClaudeTheme.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            Text(item.category)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ClaudeTheme.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(ClaudeTheme.surfaceSecondary, in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            isSelected ? ClaudeTheme.accentSubtle : Color.clear,
            in: RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusSmall)
        )
        .contentShape(Rectangle())
    }
}
