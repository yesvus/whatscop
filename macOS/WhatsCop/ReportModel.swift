import AppKit
import Foundation

@MainActor
final class ReportModel: ObservableObject {
    @Published private(set) var snapshot: ScanSnapshot?
    @Published private(set) var history: [HistoryPoint] = []
    @Published private(set) var isScanning = false
    @Published private(set) var error: String?
    @Published private(set) var historyError: String?
    @Published private(set) var lastScanned: Date?
    @Published private(set) var selectedFolderError: String?
    private var grantedMediaRoot: URL?

    func useSelectedMediaFolder(_ root: URL, olderThanDays: Int) {
        guard root.standardizedFileURL.path == ScanEngine.defaultRoot.standardizedFileURL.path else {
            selectedFolderError = "Select the WhatsApp Media folder, not another directory."
            return
        }
        selectedFolderError = nil
        grantedMediaRoot = root
        refresh(olderThanDays: olderThanDays)
    }

    init() {
        do {
            history = try HistoryStore.load()
        } catch {
            historyError = "Could not read history: \(error.localizedDescription)"
        }
    }

    func refresh(olderThanDays: Int) {
        guard !isScanning else { return }
        isScanning = true
        error = nil
        NSLog("WhatsCop: starting read-only media scan")
        let scanRoot = grantedMediaRoot ?? ScanEngine.defaultRoot
        Task.detached(priority: .userInitiated) { [weak self] in
            // Explicit NSOpenPanel selection is the narrow macOS permission grant.
            let accessed = scanRoot.startAccessingSecurityScopedResource()
            defer {
                if accessed { scanRoot.stopAccessingSecurityScopedResource() }
            }
            do {
                let scan = try ScanEngine.scan(root: scanRoot, olderThanDays: olderThanDays)
                await self?.finish(scan)
            } catch {
                await self?.fail(error.localizedDescription)
            }
        }
    }

    private func finish(_ scan: ScanSnapshot) {
        NSLog("WhatsCop: scanned %d files; folder errors %d, file errors %d, permission errors %d, transient changes %d",
              scan.total.files, scan.unreadableFolders, scan.unreadableFiles, scan.permissionErrors, scan.skippedChanges)
        snapshot = scan
        lastScanned = Date()
        isScanning = false
        do {
            try DiagnosticsStore.save(scan)
        } catch {
            NSLog("WhatsCop: aggregate scan diagnostics could not be saved: %@", error.localizedDescription)
        }
        do {
            history = try HistoryStore.record(snapshot: scan)
            NSLog("WhatsCop: stored %d aggregate history snapshots", history.count)
            historyError = nil
        } catch {
            historyError = "History could not be saved: \(error.localizedDescription)"
            NSLog("WhatsCop: history write error: %@", error.localizedDescription)
        }
    }

    private func fail(_ message: String) {
        error = message
        NSLog("WhatsCop: scan error: %@", message)
        isScanning = false
    }
}

@MainActor
final class UISettings: ObservableObject {
    @Published var revealChatIDs = false
    @Published var olderThanDays = 90
}
