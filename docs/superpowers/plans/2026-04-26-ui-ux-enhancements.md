# Clarc UI/UX Enhancements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 11 UI/UX enhancements for the Clarc macOS desktop client, improving navigation, first-run experience, information density, and visual polish.

**Architecture:** Each enhancement is a self-contained task that can be implemented independently. All new views follow the existing pattern: SwiftUI views using `@Environment(AppState.self)` and `@Environment(WindowState.self)`, themed with `ClaudeTheme` constants from `ClarcCore`. New components are placed in the appropriate package (`ClarcCore` for models/utilities, `ClarcChatKit` for chat-related UI, `Clarc/Views/` for app-level views).

**Tech Stack:** Swift 6.2+, SwiftUI, macOS 15+, ClarcCore, ClarcChatKit

---

## File Structure

| Task | Files Created/Modified | Purpose |
|------|----------------------|---------|
| 1. Settings Theme Consistency | Modify: `Clarc/Views/SettingsView.swift` | Replace NSColor references with ClaudeTheme |
| 2. Scroll Fade Indicators | Create: `Packages/Sources/ClarcCore/Theme/ScrollFadeModifier.swift` | Reusable fade overlay modifier |
| | Modify: `Clarc/Views/MainView.swift` (project tab bar) | Apply fade to tab scroll |
| | Modify: `Packages/Sources/ClarcChatKit/ChatView.swift` (shortcut bar) | Apply fade to shortcut scroll |
| 3. Adaptive Permission Modal | Modify: `Clarc/Views/Permission/PermissionModal.swift` | Dynamic sizing + risk color |
| 4. Session Search | Modify: `Clarc/Views/Sidebar/HistoryListView.swift` | Add search field + filtering |
| 5. Improved Empty State | Modify: `Clarc/Views/MainView.swift` (detailContent) | Actionable dashboard |
| 6. Context Window Visual | Modify: `Packages/Sources/ClarcChatKit/ChatView.swift` | Add context bar above messages |
| 7. Project Tab Scroll Indicators | Modify: `Clarc/Views/MainView.swift` (chatToolbarArea) | Fade edges on tab overflow |
| 8. Command Palette | Create: `Clarc/Views/CommandPalette.swift` | Spotlight-style overlay |
| | Modify: `Clarc/Views/MainView.swift` | Keyboard shortcut + state |
| | Modify: `Clarc/Views/ProjectWindowView.swift` | Same for project windows |
| 9. Onboarding Improvements | Modify: `Clarc/Views/Onboarding/OnboardingView.swift` | Welcome step + polish |
| 10. Animated Theme Transitions | Modify: `Clarc/Views/MainView.swift` | Replace `.id()` with animation |
| | Modify: `Clarc/Views/ProjectWindowView.swift` | Same |
| 11. Message Bookmarks | Modify: `Packages/Sources/ClarcCore/Models/ChatMessage.swift` | Add `isBookmarked` flag |
| | Modify: `Packages/Sources/ClarcChatKit/MessageBubble.swift` | Bookmark UI |
| | Modify: `Clarc/Views/Sidebar/HistoryListView.swift` | Bookmarks section |
| | Modify: `Clarc/App/AppState.swift` | Bookmark persistence |

---

### Task 1: Settings Theme Consistency

**Files:**
- Modify: `Clarc/Views/SettingsView.swift`

Replace all `Color(NSColor.controlBackgroundColor)` and `Color(NSColor.separatorColor)` references with ClaudeTheme equivalents so the Settings window matches the rest of the app in all themes and modes.

- [ ] **Step 1: Replace background color references**

In `Clarc/Views/SettingsView.swift`, replace all instances of `Color(NSColor.controlBackgroundColor)` with `ClaudeTheme.surfacePrimary`:

```swift
// In themeSection (around line 188), skillMarketSection (line 239), sourceCodeSection (line 275), helpSection (line 306)
// Replace:
.background(Color(NSColor.controlBackgroundColor))
// With:
.background(ClaudeTheme.surfacePrimary)
```

There are 4 occurrences in `GeneralSettingsTab` and 1 in `TerminalSettingsTab` (font preview).

- [ ] **Step 2: Replace border/separator color references**

Replace all instances of `Color(NSColor.separatorColor)` with `ClaudeTheme.border`:

```swift
// Replace:
.strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
// With:
.strokeBorder(ClaudeTheme.border, lineWidth: 0.5)
```

There are 4 occurrences matching the background replacements. Also change `lineWidth: 1` to `lineWidth: 0.5` to match the rest of the app's border weight.

- [ ] **Step 3: Replace system selection color in ThemePickerRow**

In `ThemePickerRow` (around line 551):

```swift
// Replace:
.background(isHovering ? Color(NSColor.selectedContentBackgroundColor).opacity(0.5) : Color.clear)
// With:
.background(isHovering ? ClaudeTheme.sidebarItemHover : Color.clear)
```

- [ ] **Step 4: Replace font preview background in TerminalSettingsTab**

In `TerminalSettingsTab` (around line 492):

```swift
// Replace:
.background(Color(NSColor.controlBackgroundColor))
// With:
.background(ClaudeTheme.codeBackground)
```

Use `codeBackground` here since it's a monospaced font preview — this is semantically a code display.

- [ ] **Step 5: Build and verify**

Run: `./build.sh`
Expected: Clean build. Open Settings window and verify all sections use themed colors that match the main app, both in light and dark mode. Switch between themes and confirm the Settings window updates.

- [ ] **Step 6: Commit**

```bash
git add Clarc/Views/SettingsView.swift
git commit -m "fix: use ClaudeTheme colors in SettingsView for visual consistency"
```

---

### Task 2: Scroll Fade Modifier

**Files:**
- Create: `Packages/Sources/ClarcCore/Theme/ScrollFadeModifier.swift`

A reusable ViewModifier that adds gradient fade overlays on the leading/trailing edges of a horizontal ScrollView, indicating that more content exists in that direction.

- [ ] **Step 1: Create the ScrollFadeModifier**

Create `Packages/Sources/ClarcCore/Theme/ScrollFadeModifier.swift`:

```swift
import SwiftUI

public struct ScrollFadeModifier: ViewModifier {
    let fadeWidth: CGFloat
    let backgroundColor: Color

    public init(fadeWidth: CGFloat = 24, backgroundColor: Color = ClaudeTheme.surfaceElevated) {
        self.fadeWidth = fadeWidth
        self.backgroundColor = backgroundColor
    }

    public func body(content: Content) -> some View {
        content
            .overlay(alignment: .leading) {
                LinearGradient(
                    colors: [backgroundColor, backgroundColor.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: fadeWidth)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .trailing) {
                LinearGradient(
                    colors: [backgroundColor.opacity(0), backgroundColor],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: fadeWidth)
                .allowsHitTesting(false)
            }
    }
}

extension View {
    public func scrollFadeEdges(
        fadeWidth: CGFloat = 24,
        backgroundColor: Color = ClaudeTheme.surfaceElevated
    ) -> some View {
        modifier(ScrollFadeModifier(fadeWidth: fadeWidth, backgroundColor: backgroundColor))
    }
}
```

- [ ] **Step 2: Apply to project tab bar in MainView**

In `Clarc/Views/MainView.swift`, find the `chatToolbarArea` computed property (around line 192). Wrap the tab ScrollView:

```swift
// Replace the ScrollView block:
ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: 4) {
        ForEach(appState.projects.filter { appState.openProjectIds.contains($0.id) }) { project in
            ProjectTabButton(
                project: project,
                isSelected: windowState.selectedProject?.id == project.id,
                projectToDelete: $projectToDelete,
                projectToRename: $projectToRename,
                renameText: $renameText
            )
        }
    }
}
.scrollFadeEdges(backgroundColor: ClaudeTheme.surfaceElevated)
```

- [ ] **Step 3: Apply to shortcut bar in ChatView**

In `Packages/Sources/ClarcChatKit/ChatView.swift`, find the `shortcutBar` computed property (around line 44). Wrap:

```swift
// Replace the ScrollView block in shortcutBar:
ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: 8) {
        ForEach(shortcuts) { shortcut in
            // ... existing button code
        }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 6)
}
.scrollFadeEdges(backgroundColor: ClaudeTheme.surfaceElevated)
```

- [ ] **Step 4: Build and verify**

Run: `./build.sh`
Expected: Clean build. When many projects are open, the tab bar shows subtle gradient fades on edges where tabs overflow.

- [ ] **Step 5: Commit**

```bash
git add Packages/Sources/ClarcCore/Theme/ScrollFadeModifier.swift Clarc/Views/MainView.swift Packages/Sources/ClarcChatKit/ChatView.swift
git commit -m "feat: add scroll fade indicators for horizontal overflow areas"
```

---

### Task 3: Adaptive Permission Modal

**Files:**
- Modify: `Clarc/Views/Permission/PermissionModal.swift`

Make the permission modal dynamically sized based on content, and add a color-coded risk border based on tool category.

- [ ] **Step 1: Read the full PermissionModal**

Read `/Users/srivpra/MyProjects/Clarc/Clarc/Views/Permission/PermissionModal.swift` completely to understand the current layout.

- [ ] **Step 2: Replace fixed frame with flexible sizing**

In `PermissionModal.swift`, find the `.frame(width: 480, height: 380)` line (around line 26). Replace:

```swift
// Replace:
.frame(width: 480, height: 380)
// With:
.frame(width: 500)
.frame(minHeight: 280, maxHeight: 560)
```

This allows the modal to grow vertically based on content while keeping a consistent width.

- [ ] **Step 3: Add risk-level border color**

Add a computed property and apply it to the modal background:

```swift
// Add computed property inside PermissionModal:
private var riskColor: Color {
    switch ToolCategory(toolName: request.toolName) {
    case .readOnly: return ClaudeTheme.statusSuccess
    case .fileModification: return ClaudeTheme.statusWarning
    case .execution: return ClaudeTheme.statusError
    case .mcp, .unknown: return ClaudeTheme.textTertiary
    }
}

// Add after .background(ClaudeTheme.surfaceElevated):
.overlay(
    RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusLarge)
        .strokeBorder(riskColor.opacity(0.5), lineWidth: 2)
)
```

- [ ] **Step 4: Expand the scrollable detail area**

In the `detailRow` function, change the max height from 120 to 200:

```swift
// Replace:
.frame(maxHeight: 120)
// With:
.frame(minHeight: 40, maxHeight: 240)
```

- [ ] **Step 5: Add a risk badge to the header**

In the `headerSection`, add a risk level indicator after the tool name:

```swift
// In headerSection, after the Text(request.toolName) line, add:
Text(LocalizedStringKey(riskLabel))
    .font(.caption)
    .foregroundStyle(riskColor)
    .padding(.horizontal, 8)
    .padding(.vertical, 2)
    .background(riskColor.opacity(0.12), in: Capsule())

// Add computed property:
private var riskLabel: String {
    switch ToolCategory(toolName: request.toolName) {
    case .readOnly: return "Read Only"
    case .fileModification: return "File Edit"
    case .execution: return "Execution"
    case .mcp: return "MCP"
    case .unknown: return "Unknown"
    }
}
```

- [ ] **Step 6: Build and verify**

Run: `./build.sh`
Expected: Permission modal resizes based on content. Read-only tools show green border/badge, file modifications show yellow/orange, execution shows red.

- [ ] **Step 7: Commit**

```bash
git add Clarc/Views/Permission/PermissionModal.swift
git commit -m "feat: adaptive permission modal with risk-level indicators"
```

---

### Task 4: Session Search in History

**Files:**
- Modify: `Clarc/Views/Sidebar/HistoryListView.swift`

Add a search field to the history sidebar that filters sessions by title.

- [ ] **Step 1: Add search state**

In `HistoryListView`, add state properties after the existing `@State` declarations (around line 10):

```swift
@State private var isSearching = false
@State private var searchText = ""
@FocusState private var isSearchFocused: Bool
```

- [ ] **Step 2: Add search button to header**

In the `headerRow` computed property, add a search button before the filter toggle:

```swift
// In headerRow HStack, before the showAllProjects toggle button, add:
Button {
    withAnimation(.easeInOut(duration: 0.15)) {
        isSearching.toggle()
        if isSearching { isSearchFocused = true }
        else { searchText = "" }
    }
} label: {
    Image(systemName: "magnifyingglass")
        .font(.system(size: 11))
        .foregroundStyle(isSearching ? ClaudeTheme.accent : ClaudeTheme.textTertiary)
}
.buttonStyle(.borderless)
.help("Search Sessions")
```

- [ ] **Step 3: Add search bar below header**

In the `body`, after `headerRow` and before the `if sessions.isEmpty` check, add:

```swift
if isSearching {
    HStack(spacing: 6) {
        Image(systemName: "magnifyingglass")
            .font(.system(size: 11))
            .foregroundStyle(ClaudeTheme.textTertiary)
        TextField("Search sessions...", text: $searchText)
            .font(.system(size: 12))
            .textFieldStyle(.plain)
            .focused($isSearchFocused)
        if !searchText.isEmpty {
            Button {
                searchText = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(ClaudeTheme.textTertiary)
            }
            .buttonStyle(.borderless)
        }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(ClaudeTheme.inputBackground)
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .padding(.horizontal, 8)
    .padding(.bottom, 4)
    .onExitCommand {
        withAnimation(.easeInOut(duration: 0.15)) {
            isSearching = false
            searchText = ""
        }
    }
}
```

- [ ] **Step 4: Filter sessions by search text**

Modify the `sessions` computed property to apply the search filter:

```swift
// Replace:
private var sessions: [DisplaySession] {
    if windowState.isProjectWindow || !showAllProjects {
        return currentProjectSessions
    } else {
        return allProjectSessions
    }
}

// With:
private var sessions: [DisplaySession] {
    let base: [DisplaySession]
    if windowState.isProjectWindow || !showAllProjects {
        base = currentProjectSessions
    } else {
        base = allProjectSessions
    }
    guard !searchText.isEmpty else { return base }
    let query = searchText.lowercased()
    return base.filter { $0.title.lowercased().contains(query) }
}
```

- [ ] **Step 5: Update empty state to distinguish search miss from no history**

Modify the `emptyState` to show a search-specific message:

```swift
// Replace the emptyState computed property:
private var emptyState: some View {
    VStack(spacing: 8) {
        Spacer()
        if !searchText.isEmpty {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20))
                .foregroundStyle(ClaudeTheme.textTertiary)
            Text("No sessions matching \"\(searchText)\"")
                .font(.system(size: 13))
                .foregroundStyle(ClaudeTheme.textSecondary)
        } else {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 20))
                .foregroundStyle(ClaudeTheme.textTertiary)
            Text("No chat history")
                .font(.system(size: 13))
                .foregroundStyle(ClaudeTheme.textSecondary)
        }
        Spacer()
    }
    .frame(maxWidth: .infinity)
}
```

- [ ] **Step 6: Build and verify**

Run: `./build.sh`
Expected: History sidebar has a search icon. Clicking it reveals a search field that filters sessions by title in real time.

- [ ] **Step 7: Commit**

```bash
git add Clarc/Views/Sidebar/HistoryListView.swift
git commit -m "feat: add session search to history sidebar"
```

---

### Task 5: Improved Empty State

**Files:**
- Modify: `Clarc/Views/MainView.swift`

Replace the minimal "Select a Project" placeholder with an actionable dashboard showing quick actions and keyboard shortcut hints.

- [ ] **Step 1: Create the empty state dashboard**

In `Clarc/Views/MainView.swift`, replace the empty state block in `detailContent` (lines 259-273) with a richer dashboard:

```swift
// Replace the else block that starts with VStack(spacing: 16) { Image(systemName: "sparkle") ...
// With:
VStack(spacing: 32) {
    Spacer()

    VStack(spacing: 12) {
        Image(systemName: "sparkle")
            .font(.system(size: 48))
            .foregroundStyle(ClaudeTheme.accent)
        Text("Welcome to Clarc")
            .font(.title.weight(.semibold))
            .foregroundStyle(ClaudeTheme.textPrimary)
        Text("A native macOS client for Claude Code")
            .font(.subheadline)
            .foregroundStyle(ClaudeTheme.textSecondary)
    }

    HStack(spacing: 16) {
        EmptyStateActionCard(
            icon: "folder.badge.plus",
            title: "Add Project",
            subtitle: "Open a local folder",
            action: { showFilePicker = true }
        )
        EmptyStateActionCard(
            icon: "arrow.down.circle",
            title: "Clone Repo",
            subtitle: "Clone from GitHub",
            action: { showGitHubSheet = true }
        )
    }
    .frame(maxWidth: 400)

    VStack(alignment: .leading, spacing: 8) {
        Text("Keyboard Shortcuts")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(ClaudeTheme.textTertiary)
            .textCase(.uppercase)
        HStack(spacing: 24) {
            ShortcutHint(keys: "⌘N", label: "New Chat")
            ShortcutHint(keys: "⌘K", label: "Command Palette")
            ShortcutHint(keys: "⌘1-3", label: "Sidebar Tabs")
            ShortcutHint(keys: "⌘4", label: "Inspector")
        }
    }
    .padding(16)
    .background(ClaudeTheme.surfaceSecondary.opacity(0.5), in: RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusMedium))

    Spacer()
}
.frame(maxWidth: .infinity, maxHeight: .infinity)
.background(ClaudeTheme.background)
```

- [ ] **Step 2: Create helper views**

Add these helper structs at the bottom of `MainView.swift` (before the `#Preview`):

```swift
struct EmptyStateActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(ClaudeTheme.accent)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ClaudeTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(ClaudeTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                isHovered ? ClaudeTheme.surfaceTertiary : ClaudeTheme.surfaceSecondary,
                in: RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusMedium)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusMedium)
                    .strokeBorder(isHovered ? ClaudeTheme.accent.opacity(0.3) : ClaudeTheme.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

struct ShortcutHint: View {
    let keys: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Text(keys)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(ClaudeTheme.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(ClaudeTheme.surfaceTertiary, in: RoundedRectangle(cornerRadius: 4))
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(ClaudeTheme.textSecondary)
        }
    }
}
```

- [ ] **Step 3: Build and verify**

Run: `./build.sh`
Expected: When no project is selected, the detail area shows a branded welcome dashboard with action cards and shortcut hints.

- [ ] **Step 4: Commit**

```bash
git add Clarc/Views/MainView.swift
git commit -m "feat: improved empty state with action cards and shortcut hints"
```

---

### Task 6: Context Window Visual Indicator

**Files:**
- Modify: `Packages/Sources/ClarcChatKit/ChatView.swift`

Add a thin, color-coded progress bar at the top of the chat area that shows context window usage. This gives users an at-a-glance view of how much context remains.

- [ ] **Step 1: Create the context bar view**

In `Packages/Sources/ClarcChatKit/ChatView.swift`, add a new struct at the end of the file:

```swift
struct ContextProgressBar: View {
    let percentage: Double

    private var barColor: Color {
        if percentage >= 90 { return ClaudeTheme.statusError }
        if percentage >= 70 { return ClaudeTheme.statusWarning }
        return ClaudeTheme.accent
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(ClaudeTheme.border.opacity(0.3))
                Rectangle()
                    .fill(barColor)
                    .frame(width: geo.size.width * min(percentage / 100, 1.0))
                    .animation(.easeInOut(duration: 0.5), value: percentage)
            }
        }
        .frame(height: 2)
    }
}
```

- [ ] **Step 2: Integrate into ChatView body**

In the `ChatView` body, add the context bar between the shortcut bar and the message scroll view:

```swift
// In ChatView.body, replace the VStack(spacing: 0) content with:
public var body: some View {
    VStack(spacing: 0) {
        if windowState.selectedProject != nil && !shortcuts.isEmpty {
            shortcutBar
        }

        if let contextPct = chatBridge.lastTurnContextUsedPercentage, contextPct > 0 {
            ContextProgressBar(percentage: min(contextPct, 100))
        }

        messageScrollView

        InputBarView()

        StatusLineView()
    }
    .background(ClaudeTheme.background)
    // ... rest of existing modifiers
```

- [ ] **Step 3: Build and verify**

Run: `./build.sh`
Expected: A thin 2px bar appears at the top of the chat area after the first response, showing context usage. It's green below 70%, yellow/orange 70-90%, red above 90%.

- [ ] **Step 4: Commit**

```bash
git add Packages/Sources/ClarcChatKit/ChatView.swift
git commit -m "feat: add context window usage progress bar to chat view"
```

---

### Task 7: Command Palette (Cmd+K)

**Files:**
- Create: `Clarc/Views/CommandPalette.swift`
- Modify: `Clarc/Views/MainView.swift`
- Modify: `Clarc/Views/ProjectWindowView.swift`

A spotlight-style overlay that unifies project switching, session switching, new chat, settings navigation, and theme switching.

- [ ] **Step 1: Create CommandPalette.swift**

Create `Clarc/Views/CommandPalette.swift`:

```swift
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

        // Actions
        items.append(PaletteItem(icon: "square.and.pencil", title: "New Chat", subtitle: "Start a new conversation", category: "Actions") {
            appState.startNewChat(in: windowState)
        })
        items.append(PaletteItem(icon: "gearshape", title: "Open Settings", subtitle: "App preferences", category: "Actions") {
            openSettings()
        })

        // Themes
        for theme in AppTheme.allCases {
            items.append(PaletteItem(icon: "paintpalette", title: "Theme: \(theme.displayName)", subtitle: "Switch color theme", category: "Themes") {
                appState.selectedTheme = theme
            })
        }

        // Projects
        for project in appState.projects {
            items.append(PaletteItem(icon: "folder.fill", title: project.name, subtitle: project.path, category: "Projects") {
                appState.selectProject(project, in: windowState)
                if !appState.openProjectIds.contains(project.id) {
                    appState.openProjectIds.insert(project.id)
                }
            })
        }

        // Sessions
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
```

- [ ] **Step 2: Integrate into MainView**

In `Clarc/Views/MainView.swift`, add state and overlay:

Add state property:
```swift
@State private var showCommandPalette = false
```

Add keyboard shortcut and overlay. In the `body`, chain onto the `HSplitView`:

```swift
// After the existing .onChange(of: appState.visibleSidebarTabs) modifier, add:
.onKeyPress(keys: [.init("k")], phases: .down) { press in
    guard press.modifiers == .command else { return .ignored }
    withAnimation(.easeOut(duration: 0.15)) { showCommandPalette.toggle() }
    return .handled
}
.overlay {
    if showCommandPalette {
        CommandPalette(isPresented: $showCommandPalette)
    }
}
```

- [ ] **Step 3: Integrate into ProjectWindowView**

In `Clarc/Views/ProjectWindowView.swift`, add the same state and overlay pattern:

```swift
@State private var showCommandPalette = false
```

Add the same `.onKeyPress` and `.overlay` modifiers to the HSplitView in ProjectWindowView's body (matching the pattern from MainView).

- [ ] **Step 4: Build and verify**

Run: `./build.sh`
Expected: Pressing Cmd+K opens a spotlight-style overlay. Type to filter projects, sessions, actions. Arrow keys to navigate, Enter to select, Escape to close.

- [ ] **Step 5: Commit**

```bash
git add Clarc/Views/CommandPalette.swift Clarc/Views/MainView.swift Clarc/Views/ProjectWindowView.swift
git commit -m "feat: add Command Palette (Cmd+K) for unified navigation"
```

---

### Task 8: Onboarding Improvements

**Files:**
- Modify: `Clarc/Views/Onboarding/OnboardingView.swift`

Add a welcome step before CLI check, improve visual hierarchy, and add feature highlights.

- [ ] **Step 1: Add a two-step onboarding flow**

Rewrite `OnboardingView.swift` to include a welcome screen before the CLI check:

```swift
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
                .font(.system(size: 48))
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
```

- [ ] **Step 2: Build and verify**

Run: `./build.sh`
Expected: Onboarding now shows a welcome screen with feature highlights. "Continue" advances to CLI check. "Back" returns. Slide transition between steps.

- [ ] **Step 3: Commit**

```bash
git add Clarc/Views/Onboarding/OnboardingView.swift
git commit -m "feat: improved onboarding with welcome step and feature highlights"
```

---

### Task 9: Animated Theme Transitions

**Files:**
- Modify: `Clarc/Views/MainView.swift`
- Modify: `Clarc/Views/ProjectWindowView.swift`

Replace the `.id(appState.themeRevision)` hard reconstruction with a smooth animation.

- [ ] **Step 1: Replace .id() with .animation() in MainView**

In `Clarc/Views/MainView.swift`, find `.id(appState.themeRevision)` (around line 71). Replace:

```swift
// Replace:
.id(appState.themeRevision)
// With:
.animation(.easeInOut(duration: 0.3), value: appState.themeRevision)
```

- [ ] **Step 2: Do the same in ProjectWindowView**

In `Clarc/Views/ProjectWindowView.swift`, find `.id(appState.themeRevision)` and make the same replacement:

```swift
// Replace:
.id(appState.themeRevision)
// With:
.animation(.easeInOut(duration: 0.3), value: appState.themeRevision)
```

- [ ] **Step 3: Build and verify**

Run: `./build.sh`
Expected: Switching themes in Settings produces a smooth 300ms color crossfade instead of an abrupt view reconstruction. All themed colors transition smoothly.

- [ ] **Step 4: Commit**

```bash
git add Clarc/Views/MainView.swift Clarc/Views/ProjectWindowView.swift
git commit -m "feat: smooth animated theme transitions"
```

---

### Task 10: Message Bookmarks

**Files:**
- Modify: `Packages/Sources/ClarcCore/Models/ChatMessage.swift`
- Modify: `Packages/Sources/ClarcChatKit/MessageBubble.swift`
- Modify: `Clarc/App/AppState.swift`

Let users bookmark important assistant messages for quick reference.

- [ ] **Step 1: Add isBookmarked property to ChatMessage**

In `Packages/Sources/ClarcCore/Models/ChatMessage.swift`, make three changes:

1. Add the property after `isCompactBoundary` (around line 34):

```swift
public var isBookmarked: Bool
```

2. Add `isBookmarked` to the explicit `CodingKeys` enum (around line 71-73):

```swift
private enum CodingKeys: String, CodingKey {
    case id, role, blocks, isStreaming, isResponseComplete, timestamp, attachmentPaths, duration, isError, isCompactBoundary, isBookmarked
    case content, toolCalls
}
```

3. Add to `init(from decoder:)` (after the `isCompactBoundary` decode, around line 86):

```swift
isBookmarked = try container.decodeIfPresent(Bool.self, forKey: .isBookmarked) ?? false
```

4. Add to `encode(to encoder:)` (after the `isCompactBoundary` encode, around line 116):

```swift
if isBookmarked { try container.encode(isBookmarked, forKey: .isBookmarked) }
```

5. Add to the memberwise `init()` — add parameter `isBookmarked: Bool = false` and assignment `self.isBookmarked = isBookmarked`.

- [ ] **Step 2: Add bookmark toggle method to AppState**

In `Clarc/App/AppState.swift`, add a method to toggle bookmark status:

```swift
// Add near the other session methods:
func toggleBookmark(messageId: UUID, in window: WindowState) async {
    guard let sessionId = window.currentSessionId,
          var state = sessionStates[sessionId] else { return }
    guard let index = state.messages.firstIndex(where: { $0.id == messageId }) else { return }
    state.messages[index].isBookmarked.toggle()
    sessionStates[sessionId] = state
    // Persist the change
    if let project = window.selectedProject {
        var session = ChatSession(
            id: sessionId,
            projectId: project.id,
            title: allSessionSummaries.first(where: { $0.id == sessionId })?.title ?? "Untitled",
            messages: state.messages,
            createdAt: allSessionSummaries.first(where: { $0.id == sessionId })?.createdAt ?? Date(),
            updatedAt: Date(),
            isPinned: allSessionSummaries.first(where: { $0.id == sessionId })?.isPinned ?? false
        )
        await persistence.saveSession(session)
    }
}
```

- [ ] **Step 3: Add bookmark button to MessageBubble**

In `Packages/Sources/ClarcChatKit/MessageBubble.swift`, find where the copy button is rendered for assistant messages (look for the `isCopied` state or the copy button). Add a bookmark button next to it.

Since MessageBubble is in ClarcChatKit (which doesn't have direct access to AppState), use the existing `ChatBridge` pattern. Add a bookmark handler to ChatBridge first.

In `Packages/Sources/ClarcChatKit/ChatBridge.swift`, add:

```swift
// Add property:
public var toggleBookmarkHandler: (@MainActor @Sendable (UUID) async -> Void)?

// Add method:
public func toggleBookmark(messageId: UUID) async {
    await toggleBookmarkHandler?(messageId)
}
```

Then in `Clarc/App/AppState.swift`, in the `setupChatBridge` method, wire it up:

```swift
bridge.toggleBookmarkHandler = { [weak self, weak window] messageId in
    guard let self, let window else { return }
    await self.toggleBookmark(messageId: messageId, in: window)
}
```

Now in `MessageBubble.swift`, for assistant messages, add a bookmark button in the hover overlay area (near the copy button):

```swift
// Add in the assistant message actions area (near copy button):
Button {
    Task { await chatBridge.toggleBookmark(messageId: message.id) }
} label: {
    Image(systemName: message.isBookmarked ? "bookmark.fill" : "bookmark")
        .font(.system(size: 11))
        .foregroundStyle(message.isBookmarked ? ClaudeTheme.accent : ClaudeTheme.textTertiary)
}
.buttonStyle(.borderless)
.help(message.isBookmarked ? "Remove Bookmark" : "Bookmark")
```

- [ ] **Step 4: Build and verify**

Run: `./build.sh`
Expected: Hovering over assistant messages shows a bookmark icon next to the copy button. Clicking it toggles the bookmark state (filled/unfilled). Bookmarked messages persist across sessions.

- [ ] **Step 5: Commit**

```bash
git add Packages/Sources/ClarcCore/Models/ChatMessage.swift Packages/Sources/ClarcChatKit/MessageBubble.swift Packages/Sources/ClarcChatKit/ChatBridge.swift Clarc/App/AppState.swift
git commit -m "feat: add message bookmark functionality"
```

---

### Task 11: Onboarding — Step Indicator Dots

**Files:**
- Modify: `Clarc/Views/Onboarding/OnboardingView.swift`

Add step indicator dots to the onboarding view so users know where they are in the flow.

- [ ] **Step 1: Add step dots**

In the `OnboardingView` body, add dots between the content and navigation buttons:

```swift
// In the body, between Spacer() (the second one) and navigationButtons, add:
HStack(spacing: 8) {
    ForEach(0..<2, id: \.self) { i in
        Circle()
            .fill(i == step ? ClaudeTheme.accent : ClaudeTheme.textTertiary.opacity(0.3))
            .frame(width: 8, height: 8)
            .animation(.easeInOut(duration: 0.2), value: step)
    }
}
.padding(.bottom, 16)
```

- [ ] **Step 2: Build and verify**

Run: `./build.sh`
Expected: Two dots appear between content and buttons, indicating current step. Active dot uses accent color.

- [ ] **Step 3: Commit**

```bash
git add Clarc/Views/Onboarding/OnboardingView.swift
git commit -m "feat: add step indicator dots to onboarding"
```

---

## Execution Order

The tasks are designed to be independent. Recommended execution order for minimal conflicts:

1. **Task 1** (Settings Theme) — standalone, no dependencies
2. **Task 2** (Scroll Fade) — creates reusable modifier, used in later tasks
3. **Task 3** (Permission Modal) — standalone
4. **Task 4** (Session Search) — standalone
5. **Task 5** (Empty State) — modifies MainView, do before Task 7
6. **Task 6** (Context Bar) — modifies ChatView
7. **Task 7** (Command Palette) — modifies MainView, do after Task 5
8. **Task 8** (Onboarding) — standalone
9. **Task 9** (Theme Transitions) — modifies MainView, do after Tasks 5 & 7
10. **Task 10** (Bookmarks) — touches multiple files, do last
11. **Task 11** (Step Dots) — modifies onboarding, do after Task 8
