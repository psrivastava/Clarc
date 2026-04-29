import Foundation
import os

/// Watches one or more directories for filesystem changes using
/// `DispatchSource.makeFileSystemObjectSource`. Event-driven (no polling): the
/// kernel pushes a notification only when something inside the directory
/// changes. Bursts of writes are coalesced via a 300ms debounce before the
/// caller's `onChange` fires.
public actor DirectoryWatcher {

    private struct Entry {
        let source: any DispatchSourceFileSystemObject
        let onChange: @Sendable () -> Void
        var debounceTask: Task<Void, Never>?
    }

    private var entries: [URL: Entry] = [:]
    private let logger = Logger(subsystem: "com.claudework", category: "DirectoryWatcher")
    private static let debounceNanoseconds: UInt64 = 300_000_000

    public init() {}

    /// Begin watching `url`. Re-registering the same URL is a no-op; replacing
    /// the handler requires `unwatch` first. Returns silently if the directory
    /// does not exist (caller can retry later).
    public func watch(url: URL, onChange: @Sendable @escaping () -> Void) {
        let key = url.standardizedFileURL
        if entries[key] != nil { return }

        let fd = open(key.path, O_EVTONLY)
        guard fd >= 0 else {
            logger.debug("Watch skipped (open failed) for \(key.path, privacy: .public)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            Task { await self.handleEvent(url: key) }
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()

        entries[key] = Entry(source: source, onChange: onChange, debounceTask: nil)
        logger.debug("Watching \(key.path, privacy: .public)")
    }

    public func unwatch(url: URL) {
        let key = url.standardizedFileURL
        guard let entry = entries.removeValue(forKey: key) else { return }
        entry.debounceTask?.cancel()
        entry.source.cancel()
    }

    public func unwatchAll() {
        for key in Array(entries.keys) {
            unwatch(url: key)
        }
    }

    private func handleEvent(url: URL) {
        guard let entry = entries[url] else { return }
        let onChange = entry.onChange

        // Directory itself was deleted/renamed: the fd is now stale and the
        // source would keep firing. Tear down and notify caller once so it can
        // re-resolve and re-register.
        let data = entry.source.data
        if data.contains(.delete) || data.contains(.rename) {
            unwatch(url: url)
            onChange()
            return
        }

        entries[url]?.debounceTask?.cancel()
        entries[url]?.debounceTask = Task {
            try? await Task.sleep(nanoseconds: Self.debounceNanoseconds)
            guard !Task.isCancelled else { return }
            onChange()
        }
    }
}
