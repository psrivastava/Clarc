# Clarc — Developer Notes

> Internal developer reference for the `psrivastava` fork.
> User-facing docs → [README.md](README.md)

## Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Mirror of `upstream/main` (ttnear/Clarc). **Never commit here.** |
| `psrivastava` | All custom work. Rebase onto `main` after upstream pulls. |

Remotes: `origin` → psrivastava/Clarc, `upstream` → ttnear/Clarc

## Build

```bash
./build.sh            # clean build only (output: ./build/Build/Products/Release/Clarc.app)
./build.sh --deploy   # build + kill running + ditto to /Applications + checksum verify + launch
```

- `DEVELOPER_DIR` defaults to `xcode-select -p`, override with env var
- Clean build every time (`rm -rf ./build`)
- Full log at `/tmp/clarc-build.log`
- SPM resolution requires network — **will not work from kiro-cli sandbox**; use a regular terminal

Dependencies: **SwiftTerm** (terminal emulation), **Sparkle** (auto-update), **ClarcCore/ClarcChatKit** (internal packages)

## Architecture (Fork Additions)

### Files Changed from Upstream

| File | What was added |
|------|---------------|
| `AppState.swift` | Terminal settings, sidebar tab management, openProjectIds, Claude Code path encoding helpers, CLI session import, sidebar migration |
| `MainView.swift` | CLI sidebar tab, closeable project tabs, sidebar tab context menus, keyboard shortcuts, unified + menu, visibleTabs filtering |
| `ProjectWindowView.swift` | CLI tab support, visibleTabs filtering (shared via `activeSidebarTabs`) |
| `SettingsView.swift` | Terminal settings tab (font/color), sidebar settings section (default tab, visible tabs toggles) |
| `TerminalView.swift` | Font/color scheme passthrough to EmbeddedTerminalView, `TerminalColorSchemes` enum with 6 ANSI palettes |
| `CLISessionsView.swift` | **New file** — standalone CLI sessions sidebar tab |
| `CLAUDE.md` | Fork info, build shortcut |
| `build.sh` | **New file** — build/deploy script |

### Key Patterns

**Claude Code Path Encoding**
```
AppState.claudeProjectDirName(for: path)   // "/Users/x/proj" → "-Users-x-proj"
AppState.pathFromClaudeProjectDir(dirName)  // reverse
```
Used in: session import, CLI sessions view, project creation. Single source of truth — never inline `replacingOccurrences`.

**Sidebar Tab Management**
- `visibleSidebarTabs: [String]` — persisted array of lowercase tab keys (`"history"`, `"cli"`, `"files"`)
- `ensureSidebarTab(_:)` — auto-adds tab on use (e.g. `"files"` when project selected)
- `activeSidebarTabs(hasProject:)` — filters visible tabs by context, used by both MainView and ProjectWindowView
- `sidebarTabKeyToRawValue` — maps stored keys to `SidebarTab.rawValue` (needed because `"cli".capitalized` ≠ `"CLI"`)
- One-time migration (`sidebarTabsMigrated_v1`) resets old "all tabs visible" default to `["history"]`

**Open Project Tabs**
- `openProjectIds: Set<UUID>` — subset of `projects[].id` currently visible as tabs
- Persisted to UserDefaults as `[String]` of UUID strings
- Auto-insert on `addProject()`, `selectProject()`
- Default on first launch: all projects open

**Terminal Settings**
- `terminalFontName`, `terminalFontSize`, `terminalColorScheme` — all UserDefaults-backed
- Font list filtered at init via `NSFont(name:size:) != nil` (only installed fonts shown)
- `TerminalColorSchemes.colors(for:isDark:)` returns bg/fg/ansi colors
- Passed to `EmbeddedTerminalView` in both `InteractiveTerminalPopup` and `InspectorPanel`

### CLISessionsView

Standalone view — reads directly from `~/.claude/projects/` and `~/.claude/history.jsonl`. No coupling to AppState session logic.

**Models:**
- `CLIProject` — path, displayName, sessions array
- `CLISession` — id, title, modifiedAt

**Features:**
- Grouped by project with collapsible disclosure groups
- Folder path subtitle (9pt, head-truncated) on each project header
- Session count badge per project
- Context menu: Resume, Copy ID, Copy Resume Command, Delete
- Resume creates Clarc project if needed, selects it, imports session summary
- Refresh button reloads from disk

### Settings Additions

**General tab → Sidebar section:**
- Default tab picker (History / CLI)
- Visible tabs checkboxes (History, CLI, Files) — at least one must remain

**Terminal tab (new):**
- Font family picker + size stepper + live preview
- Color scheme dropdown

## Known Constraints

- SPM package resolution blocked by kiro-cli sandbox — build from regular terminal
- SwiftTerm requires Metal Toolchain (`xcodebuild -downloadComponent MetalToolchain` on first build)
- `@Observable` macro fails with xcodeproj-generated projects on Xcode 26 beta — upstream uses it, so don't change
- CLI session import uses file modification date as session date (creation date not available in JSONL)

## Merge History

### 2026-04-27 — Merge origin/main (v1.2.0) into psrivastava (`3d522e7`)

Resolved 4 conflicts:

| File | Resolution | Details |
|------|-----------|---------|
| `AppState.swift` | Kept both | Fork's terminal/sidebar settings + upstream's attachment auto-preview settings |
| `MainView.swift` | Kept theirs + fork addition | Upstream's `ClaudeTheme.size()` scaled sizing + fork's `Spacer()`, removed duplicate sparkle icon |
| `SettingsView.swift` | Kept both | Fork's sidebar section (default tab, visible tabs) + upstream's font size section (interface/message steppers) + `fontStepButton` helper |
| `HistoryListView.swift` | Kept theirs | Upstream's scaled sizing with simple empty state (fork's search-aware empty state dropped) |

**Strategy:** Independent features → keep both. Design/layout changes → prefer upstream's newer scaled sizing, preserve useful fork additions (Spacer). Critical fix: ensure proper brace closure when combining sections (sidebarSection needs 3 closing braces before fontSizeSection).
