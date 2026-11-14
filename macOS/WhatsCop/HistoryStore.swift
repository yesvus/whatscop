import Foundation
import Darwin

struct HistoryPoint: Codable, Identifiable, Sendable {
    var day: String
    var timestamp: Date
    var allocated: Int64
    var files: Int
    var chats: Int

    var id: String { day }
}

// Only aggregated totals, never chat identifiers, message content, media names or paths.
enum HistoryStore {
    static func defaultFile() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/WhatsCop/history.json")
    }

    private static func ensureRegularFile(_ url: URL) throws {
        var info = stat()
        if lstat(url.path, &info) == 0 {
            guard info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else {
                throw CocoaError(.fileReadNoPermission)
            }
        } else if errno != ENOENT {
            throw CocoaError(.fileReadNoPermission)
        }
    }

    static func load(file: URL = defaultFile()) throws -> [HistoryPoint] {
        try ensureRegularFile(file)
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        let data = try Data(contentsOf: file)
        return try JSONDecoder().decode([HistoryPoint].self, from: data)
            .sorted { $0.day < $1.day }
    }

    static func record(snapshot: ScanSnapshot, at date: Date = Date(),
                       file: URL = defaultFile()) throws -> [HistoryPoint] {
        // Incomplete scans must not pollute trend history.
        if snapshot.errors > 0 { return try load(file: file) }
        var points = try load(file: file)
        let stamp = ISO8601DateFormatter()
        stamp.formatOptions = [.withFullDate]
        let day = stamp.string(from: date)
        let item = HistoryPoint(day: day, timestamp: date,
                                allocated: snapshot.total.allocated,
                                files: snapshot.total.files,
                                chats: snapshot.chats.count)
        // A single snapshot per UTC day. Most recent complete scan wins.
        points.removeAll { $0.day == day }
        points.append(item)
        points.sort { $0.day < $1.day }
        if points.count > 180 { points.removeFirst(points.count - 180) }
        let parent = file.deletingLastPathComponent()
        var info = stat()
        if lstat(parent.path, &info) == 0 {
            guard info.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR) else {
                throw CocoaError(.fileWriteNoPermission)
            }
        } else {
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
        }
        try ensureRegularFile(file)
        let data = try JSONEncoder().encode(points)
        try data.write(to: file, options: [.atomic])
        if chmod(file.path, mode_t(0o600)) != 0 {
            throw CocoaError(.fileWriteNoPermission)
        }
        return points
    }
}
