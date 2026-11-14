import Foundation

@main
struct HistoryStoreTests {
    static func expect(_ value: @autoclosure () -> Bool, _ message: String) {
        guard value() else { fatalError(message) }
    }
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("WhatsCopHistoryTest-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("nested/history.json")

        let snapshot = ScanSnapshot(total: Usage(files: 3, logical: 1000, allocated: 4096,
                                               olderFiles: 1, olderAllocated: 1024),
                                    chats: [], types: [], skippedSymlinks: 0, errors: 0, olderThanDays: 90)
        let sameDay = Date(timeIntervalSince1970: 1_783_000_000)
        var points = try HistoryStore.record(snapshot: snapshot, at: sameDay, file: file)
        expect(points.count == 1, "first point")
        points = try HistoryStore.record(snapshot: snapshot, at: sameDay.addingTimeInterval(3600), file: file)
        expect(points.count == 1, "dedupes date")
        points = try HistoryStore.record(snapshot: snapshot, at: sameDay.addingTimeInterval(86400), file: file)
        expect(points.count == 2, "appends next date")
        let encoded = try String(contentsOf: file, encoding: .utf8)
        expect(!encoded.contains("@g.us"), "no chat identifiers")
        let persisted = try HistoryStore.load(file: file)
        expect(persisted.count == 2, "round-trip")
        let incomplete = ScanSnapshot(total: Usage(), chats: [], types: [], skippedSymlinks: 0,
                                      errors: 1, olderThanDays: 90)
        let preserved = try HistoryStore.record(snapshot: incomplete, file: file)
        expect(preserved.count == 2, "incomplete scans are skipped")
        let linked = root.appendingPathComponent("history-link.json")
        try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: file)
        do {
            _ = try HistoryStore.record(snapshot: snapshot, file: linked)
            fatalError("Symlink path must be rejected")
        } catch {
            // Expected.
        }
        print("PASS: local snapshot history, same-day replacement, incomplete scan and symlink guard")
    }
}
