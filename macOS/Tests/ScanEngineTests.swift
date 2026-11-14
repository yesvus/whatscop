import Foundation
import Darwin

@main
struct ScanEngineTests {
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("FAIL: " + message + "\n", stderr)
            exit(1)
        }
    }

    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("WhatsCopTest-" + UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let group = root.appendingPathComponent("demo@g.us")
        let person = root.appendingPathComponent("user@s.whatsapp.net")
        let nested = group.appendingPathComponent("nested")
        try fm.createDirectory(at: nested, withIntermediateDirectories: true)
        try fm.createDirectory(at: person, withIntermediateDirectories: true)
        let oldPhoto = nested.appendingPathComponent("old.jpg")
        try Data(repeating: 0x41, count: 4096).write(to: oldPhoto)
        let newerVideo = group.appendingPathComponent("new.mp4")
        try Data(repeating: 0x42, count: 2048).write(to: newerVideo)
        let otherPhoto = person.appendingPathComponent("other.jpg")
        try Data(repeating: 0x43, count: 1024).write(to: otherPhoto)
        let olderDate = Date(timeIntervalSinceNow: -100 * 86400)
        try fm.setAttributes([.modificationDate: olderDate], ofItemAtPath: oldPhoto.path)
        let before = try fm.attributesOfItem(atPath: oldPhoto.path)[.modificationDate] as! Date

        try fm.createSymbolicLink(at: person.appendingPathComponent("link"), withDestinationURL: oldPhoto)
        let report = try ScanEngine.scan(root: root)
        expect(report.total.files == 3, "counts exact files")
        expect(report.total.logical == 7168, "tracks logical bytes")
        expect(report.total.olderFiles == 1, "counts files older than threshold")
        expect(report.chats.count == 2, "groups by top-level chat")
        expect(report.chats.first?.kind == "Group", "correct chat kind")
        expect(report.types.first(where: { $0.id == ".jpg" })?.usage.files == 2, "aggregates extensions")
        expect(report.skippedSymlinks == 1, "does not follow symlink")
        expect(report.errors == 0, "scan has no unexpected errors")
        let after = try fm.attributesOfItem(atPath: oldPhoto.path)[.modificationDate] as! Date
        expect(before == after, "does not mutate media metadata")
        let linkedRoot = root.appendingPathComponent("root-link")
        try fm.createSymbolicLink(at: linkedRoot, withDestinationURL: group)
        do {
            _ = try ScanEngine.scan(root: linkedRoot)
            expect(false, "must refuse a symbolic-link root")
        } catch ScanError.symlinkRoot {
            // expected
        }

        // A blocked directory is a real permission error, not a vanished-file race.
        let restricted = root.appendingPathComponent("restricted@g.us")
        try fm.createDirectory(at: restricted, withIntermediateDirectories: true)
        try Data(repeating: 0x44, count: 42).write(to: restricted.appendingPathComponent("blocked.jpg"))
        expect(chmod(restricted.path, 0) == 0, "restrict directory")
        defer { _ = chmod(restricted.path, mode_t(0o700)) }
        if geteuid() != 0 {
            let partial = try ScanEngine.scan(root: root)
            expect(partial.unreadableFolders == 1, "counts unreadable directories")
            expect(partial.permissionErrors == 1, "detects denied read access")
            expect(partial.unreadableFiles == 0, "does not report unreadable files as folders")
        }

        print("PASS: native scanner synthetic fixtures (files, symlinks, blocked folders)")
        if CommandLine.arguments.contains("--live") {
            let live = try ScanEngine.scan()
            print("LIVE: \(live.total.files) files, \(live.chats.count) chat folders, \(live.total.allocated) allocated bytes, \(live.errors) errors")
        }
    }
}
