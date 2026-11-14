import Foundation
import Darwin

// Diagnostic metadata is aggregate-only. Never persist chat IDs or file names.
struct ScanDiagnostics: Codable, Sendable {
    let scannedAt: Date
    let filesScanned: Int
    let unreadableFolders: Int
    let unreadableFiles: Int
    let permissionErrors: Int
    let transientChanges: Int
}

enum DiagnosticsStore {
    static func fileURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/WhatsCop/last-scan.json")
    }

    static func save(_ report: ScanSnapshot, to url: URL = fileURL()) throws {
        let record = ScanDiagnostics(
            scannedAt: Date(),
            filesScanned: report.total.files,
            unreadableFolders: report.unreadableFolders,
            unreadableFiles: report.unreadableFiles,
            permissionErrors: report.permissionErrors,
            transientChanges: report.skippedChanges
        )
        let destination = url.deletingLastPathComponent()
        var info = stat()
        if lstat(destination.path, &info) == 0 {
            guard info.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR) else {
                throw CocoaError(.fileWriteNoPermission)
            }
        } else {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
        }
        if lstat(url.path, &info) == 0 {
            guard info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else {
                throw CocoaError(.fileWriteNoPermission)
            }
        } else if errno != ENOENT {
            throw CocoaError(.fileWriteNoPermission)
        }
        let data = try JSONEncoder().encode(record)
        try data.write(to: url, options: .atomic)
        if chmod(url.path, mode_t(0o600)) != 0 {
            throw CocoaError(.fileWriteNoPermission)
        }
    }
}
