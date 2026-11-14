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
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let scan = try ScanEngine.scan(olderThanDays: olderThanDays)
                await self?.finish(scan)
            } catch {
                await self?.fail(error.localizedDescription)
            }
        }
    }

    private func finish(_ scan: ScanSnapshot) {
        NSLog("WhatsCop: scanned %d files, %d errors", scan.total.files, scan.errors)
        snapshot = scan
        lastScanned = Date()
        isScanning = false
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
