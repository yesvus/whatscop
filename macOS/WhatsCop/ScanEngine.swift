import Foundation
import Darwin

struct Usage: Sendable {
    var files = 0
    var logical: Int64 = 0
    var allocated: Int64 = 0
    var olderFiles = 0
    var olderAllocated: Int64 = 0

    mutating func add(size: Int64, allocated: Int64, old: Bool) {
        files += 1
        logical += size
        self.allocated += allocated
        if old {
            olderFiles += 1
            olderAllocated += allocated
        }
    }
}

struct UsageEntry: Identifiable, Sendable {
    let id: String
    let kind: String
    let usage: Usage
}

struct ScanSnapshot: Sendable {
    let total: Usage
    let chats: [UsageEntry]
    let types: [UsageEntry]
    let skippedSymlinks: Int
    let errors: Int
    let olderThanDays: Int
}

enum ScanError: LocalizedError {
    case missingRoot
    case symlinkRoot

    var errorDescription: String? {
        switch self {
        case .missingRoot: return "WhatsApp media folder is missing or unavailable."
        case .symlinkRoot: return "Refusing to scan a symbolic-link media root."
        }
    }
}

enum ScanEngine {
    static var defaultRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers/group.net.whatsapp.WhatsApp.shared/Message/Media")
    }

    static func chatKind(_ id: String) -> String {
        if id.hasSuffix("@g.us") { return "Group" }
        if id.hasSuffix("@newsletter") { return "Channel" }
        if id.hasSuffix("@s.whatsapp.net") { return "Direct" }
        return "Other"
    }

    static func scan(root: URL = defaultRoot, olderThanDays: Int = 90, now: Date = Date()) throws -> ScanSnapshot {
        var rootStat = stat()
        guard lstat(root.path, &rootStat) == 0 else { throw ScanError.missingRoot }
        guard rootStat.st_mode & mode_t(S_IFMT) != mode_t(S_IFLNK) else { throw ScanError.symlinkRoot }
        guard rootStat.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR) else { throw ScanError.missingRoot }

        let cutoff = Int64(now.timeIntervalSince1970) - Int64(olderThanDays) * 86400
        var total = Usage()
        var chats: [String: Usage] = [:]
        var extensions: [String: Usage] = [:]
        var errors = 0
        var skippedSymlinks = 0
        var stack: [(URL, String)] = [(root, "(root files)")]

        while let (folder, chatID) = stack.popLast() {
            let names: [String]
            do {
                names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
            } catch {
                errors += 1
                continue
            }

            for name in names {
                let file = folder.appendingPathComponent(name)
                var info = stat()
                guard lstat(file.path, &info) == 0 else {
                    errors += 1
                    continue
                }
                let fileType = info.st_mode & mode_t(S_IFMT)
                if fileType == mode_t(S_IFLNK) {
                    skippedSymlinks += 1
                    continue
                }
                if fileType == mode_t(S_IFDIR) {
                    let nextChat = folder == root ? name : chatID
                    stack.append((file, nextChat))
                } else if fileType == mode_t(S_IFREG) {
                    let size = max(Int64(0), info.st_size)
                    let allocated = max(Int64(0), Int64(info.st_blocks) * 512)
                    let old = Int64(info.st_mtimespec.tv_sec) < cutoff
                    let ext = file.pathExtension.isEmpty ? "(none)" : "." + file.pathExtension.lowercased()
                    total.add(size: size, allocated: allocated, old: old)
                    var chat = chats[chatID, default: Usage()]
                    chat.add(size: size, allocated: allocated, old: old)
                    chats[chatID] = chat
                    var kind = extensions[ext, default: Usage()]
                    kind.add(size: size, allocated: allocated, old: old)
                    extensions[ext] = kind
                }
            }
        }
        let sortedChats = chats.map { UsageEntry(id: $0.key, kind: chatKind($0.key), usage: $0.value) }
            .sorted { a, b in
                a.usage.allocated == b.usage.allocated ? a.id < b.id : a.usage.allocated > b.usage.allocated
            }
        let sortedTypes = extensions.map { UsageEntry(id: $0.key, kind: "File type", usage: $0.value) }
            .sorted { a, b in
                a.usage.allocated == b.usage.allocated ? a.id < b.id : a.usage.allocated > b.usage.allocated
            }
        return ScanSnapshot(total: total, chats: sortedChats, types: sortedTypes,
                            skippedSymlinks: skippedSymlinks, errors: errors, olderThanDays: olderThanDays)
    }
}
