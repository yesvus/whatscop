import SwiftUI
import AppKit

@MainActor
final class ReportModel: ObservableObject {
    @Published private(set) var snapshot: ScanSnapshot?
    @Published private(set) var isScanning = false
    @Published private(set) var error: String?
    @Published private(set) var lastScanned: Date?

    func refresh(olderThanDays: Int) {
        guard !isScanning else { return }
        isScanning = true
        error = nil
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let result = try ScanEngine.scan(olderThanDays: olderThanDays)
                await self?.didFinish(result)
            } catch {
                await self?.didFail(error.localizedDescription)
            }
        }
    }

    private func didFinish(_ result: ScanSnapshot) {
        snapshot = result
        lastScanned = Date()
        isScanning = false
    }

    private func didFail(_ description: String) {
        error = description
        isScanning = false
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 26, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 13))
    }
}

struct DiskRow: View {
    let label: String
    let detail: String
    let usage: Usage
    let total: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).lineLimit(1).truncationMode(.middle)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text(Self.bytes(usage.allocated))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(nsColor: .separatorColor).opacity(0.45))
                    Capsule().fill(Color.accentColor)
                        .frame(width: geo.size.width * min(1, CGFloat(usage.allocated) / CGFloat(max(total, 1))))
                }
            }
            .frame(height: 5)
            Text(detail + " · " + usage.files.formatted() + " files")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .binary)
    }
}

@MainActor
final class UISettings: ObservableObject {
    @Published var showChatIDs = false
    @Published var olderThanDays = 90
    @Published var selectedTab = 0
}

struct ReportView: View {
    @StateObject private var model = ReportModel()
    @StateObject private var settings = UISettings()

    private let ageOptions = [30, 90, 180, 365]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 13) {
                Image(systemName: "externaldrive.fill.badge.person.crop")
                    .font(.system(size: 31))
                    .foregroundStyle(.tint)
                    .frame(width: 50, height: 50)
                    .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text("WhatsCop").font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("WhatsApp media · read-only disk analysis")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                if model.isScanning {
                    ProgressView().controlSize(.small)
                }
                Button {
                    model.refresh(olderThanDays: settings.olderThanDays)
                } label: {
                    Label("Scan again", systemImage: "arrow.clockwise")
                }.disabled(model.isScanning)
            }

            if let snapshot = model.snapshot {
                HStack(spacing: 12) {
                    StatTile(title: "Allocated media", value: DiskRow.bytes(snapshot.total.allocated),
                             subtitle: snapshot.total.files.formatted() + " files")
                    StatTile(title: "Conversations", value: snapshot.chats.count.formatted(),
                             subtitle: "folders with media")
                    StatTile(title: "Older than " + String(snapshot.olderThanDays) + " days",
                             value: DiskRow.bytes(snapshot.total.olderAllocated),
                             subtitle: snapshot.total.olderFiles.formatted() + " files · not necessarily disposable")
                }

                HStack(spacing: 14) {
                    Picker("Modified before", selection: $settings.olderThanDays) {
                        ForEach(ageOptions, id: \.self) { days in Text("\(days) days").tag(days) }
                    }
                    .frame(width: 180)
                    .onChange(of: settings.olderThanDays) { newValue in
                        model.refresh(olderThanDays: newValue)
                    }
                    Toggle("Reveal chat IDs", isOn: $settings.showChatIDs)
                        .toggleStyle(.checkbox)
                    Spacer()
                    if let last = model.lastScanned {
                        Text("Scanned " + last.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }

                Picker("Details", selection: $settings.selectedTab) {
                    Text("Conversations").tag(0)
                    Text("File types").tag(1)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if settings.selectedTab == 0 {
                            ForEach(Array(snapshot.chats.enumerated()), id: \.element.id) { index, entry in
                                DiskRow(label: settings.showChatIDs ? entry.id : "Conversation #\(index + 1)",
                                        detail: entry.kind,
                                        usage: entry.usage, total: snapshot.total.allocated)
                                if index < snapshot.chats.count - 1 { Divider() }
                            }
                        } else {
                            ForEach(snapshot.types) { entry in
                                DiskRow(label: entry.id, detail: "Media file type",
                                        usage: entry.usage, total: snapshot.total.allocated)
                                if entry.id != snapshot.types.last?.id { Divider() }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(minHeight: 230)
                if snapshot.errors > 0 {
                    Label("\(snapshot.errors) entries could not be read; numbers may be incomplete.",
                          systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                if snapshot.skippedSymlinks > 0 {
                    Text("\(snapshot.skippedSymlinks) symbolic links skipped.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            } else if model.isScanning {
                Spacer()
                HStack { Spacer(); ProgressView("Scanning file metadata…"); Spacer() }
                Spacer()
            } else if let error = model.error {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "externaldrive.badge.xmark")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)
                    Text(error).font(.headline)
                    Text("WhatsApp may not be installed, or macOS may deny access.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }

            Divider()
            HStack {
                Label("Analysis only — never deletes messages or media", systemImage: "lock.shield")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Text("APFS estimates may differ from recoverable space")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
        .padding(24)
        .frame(minWidth: 690, idealWidth: 780, minHeight: 610, idealHeight: 680)
        .task { model.refresh(olderThanDays: settings.olderThanDays) }
    }
}

@main
struct WhatsCopApp: App {
    var body: some Scene {
        WindowGroup("WhatsCop") {
            ReportView()
        }
        .windowResizability(.contentSize)
    }
}
