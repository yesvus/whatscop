import AppKit
import SwiftUI
import Charts

struct OverviewView: View {
    @ObservedObject var model: ReportModel
    @ObservedObject var settings: UISettings

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            ScanBanner(model: model, olderThanDays: settings.olderThanDays)
            if let report = model.snapshot {
                HStack(spacing: 10) {
                    MetricTile(systemName: "externaldrive",
                               title: "Allocated media",
                               value: Display.bytes(report.total.allocated),
                               detail: report.total.files.formatted() + " files")
                    MetricTile(systemName: "bubble.left.and.bubble.right",
                               title: "Conversations",
                               value: report.chats.count.formatted(),
                               detail: "Folders containing media")
                    MetricTile(systemName: "calendar",
                               title: "Older than \(report.olderThanDays) days",
                               value: Display.bytes(report.total.olderAllocated),
                               detail: report.total.olderFiles.formatted() + " files · may still be needed")
                }
                HStack(spacing: 10) {
                    Picker("Older than", selection: $settings.olderThanDays) {
                        ForEach([30, 90, 180, 365], id: \.self) { d in
                            Text("\(d) days").tag(d)
                        }
                    }
                    .frame(width: 200)
                    .onChange(of: settings.olderThanDays) { value in
                        model.refresh(olderThanDays: value)
                    }
                    Spacer()
                    if let date = model.lastScanned {
                        Text("Last scan: " + date.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(alignment: .top, spacing: 10) {
                    CardPanel(title: "Largest conversations", icon: "bubble.left.and.bubble.right") {
                        ForEach(Array(report.chats.prefix(5).enumerated()), id: \.element.id) { i, row in
                            MediaRow(label: "Conversation #\(i + 1)", kind: row.kind,
                                     usage: row.usage, total: report.total.allocated)
                            if i < min(report.chats.count, 5) - 1 { Divider() }
                        }
                    }
                    CardPanel(title: "Media file types", icon: "chart.pie") {
                        ForEach(Array(report.types.prefix(5).enumerated()), id: \.element.id) { i, row in
                            MediaRow(label: row.id, kind: "File type",
                                     usage: row.usage, total: report.total.allocated)
                            if i < min(report.types.count, 5) - 1 { Divider() }
                        }
                    }
                }
                if report.errors > 0 {
                    Label("Some folders could not be scanned (\(report.errors) errors).",
                          systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.system(size: 11))
                }
            } else if model.isScanning {
                LoadingPlaceholder(message: "Scanning WhatsApp media metadata…")
            } else {
                Text(model.error ?? "No scan results yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Spacer(minLength: 0)
            PrivacyFooter()
        }
        .padding(23)
        .frame(width: 790, height: 655)
    }
}

struct ConversationsView: View {
    @ObservedObject var model: ReportModel
    @ObservedObject var settings: UISettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Conversations").font(.system(size: 20, weight: .semibold))
                    Text("Largest media folders, sorted by allocated size")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Reveal identifiers", isOn: $settings.revealChatIDs)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
            }
            if let report = model.snapshot {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(report.chats.enumerated()), id: \.element.id) { i, row in
                            MediaRow(label: settings.revealChatIDs ? row.id : "Conversation #\(i + 1)",
                                     kind: row.kind, usage: row.usage,
                                     total: report.total.allocated)
                            Divider()
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .background(Color(nsColor: .controlBackgroundColor),
                            in: RoundedRectangle(cornerRadius: 11))
                HStack {
                    Text("\(report.chats.count) folders · \(report.total.files.formatted()) files")
                    Spacer()
                    Text("Identifiers are hidden by default")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            } else {
                LoadingPlaceholder(message: model.error ?? "Scan to view conversations")
            }
            PrivacyFooter()
        }
        .padding(24)
        .frame(width: 790, height: 655)
    }
}

struct HistoryView: View {
    @ObservedObject var model: ReportModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Storage history").font(.system(size: 20, weight: .semibold))
                    Text("A private summary saved after each complete scan")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(model.history.count) daily snapshots")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }

            if let last = model.history.last {
                HStack(spacing: 10) {
                    MetricTile(systemName: "externaldrive", title: "Latest usage",
                               value: Display.bytes(last.allocated),
                               detail: last.timestamp.formatted(date: .abbreviated, time: .shortened))
                    MetricTile(systemName: "chart.line.uptrend.xyaxis", title: "Since first scan",
                               value: Display.signedBytes(last.allocated - (model.history.first?.allocated ?? last.allocated)),
                               detail: "Net change across tracked days")
                    MetricTile(systemName: "clock.arrow.circlepath", title: "Tracked days",
                               value: String(model.history.count),
                               detail: "One snapshot per UTC day")
                }
                CardPanel(title: "Allocated storage over time", icon: "chart.xyaxis.line") {
                    if model.history.count < 2 {
                        VStack(spacing: 10) {
                            Image(systemName: "chart.xyaxis.line")
                                .font(.system(size: 29)).foregroundStyle(.secondary)
                            Text("History starts with today's scan")
                                .font(.system(size: 13, weight: .medium))
                            Text("Scan again on another day to see the trend.")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 230)
                    } else {
                        Chart(model.history) { item in
                            LineMark(x: .value("Date", item.timestamp),
                                     y: .value("Allocated bytes", item.allocated))
                                .foregroundStyle(Color.accentColor)
                            PointMark(x: .value("Date", item.timestamp),
                                      y: .value("Allocated bytes", item.allocated))
                                .foregroundStyle(Color.accentColor)
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 280)
                        .padding(.vertical, 12)
                    }
                }
                if let issue = model.historyError {
                    Label(issue, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.system(size: 11))
                }
                Text("History stores only the scan date, total size, file count and chat count.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            } else {
                LoadingPlaceholder(message: "No history yet. Run your first scan from Overview.")
            }
            Spacer(minLength: 0)
            PrivacyFooter()
        }
        .padding(24)
        .frame(width: 790, height: 655)
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            if let icon = Display.icon() {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 98, height: 98)
            }
            Text("WhatsCop").font(.system(size: 23, weight: .bold, design: .rounded))
            Text("Version 0.3.0")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Text("A small native macOS utility for understanding WhatsApp media storage.")
                .multilineTextAlignment(.center)
                .font(.system(size: 12))
                .frame(width: 440)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 9) {
                Label("All scans run locally; no telemetry or uploads", systemImage: "network.slash")
                Label("Messages, media contents and WhatsApp databases are never opened",
                      systemImage: "lock")
                Label("Disk history contains aggregate sizes only", systemImage: "chart.bar.xaxis")
                Label("WhatsApp media is never deleted or modified", systemImage: "checkmark.shield")
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.top, 13)
            Button("View source on GitHub") {
                if let url = URL(string: "https://github.com/yesvus/whatscop") {
                    NSWorkspace.shared.open(url)
                }
            }
            .padding(.top, 8)
            Spacer()
            PrivacyFooter()
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .frame(width: 790, height: 655)
    }
}

@MainActor
final class PreferencesController: NSTabViewController {
    let model = ReportModel()
    let settings = UISettings()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "WhatsCop"
        tabStyle = .toolbar
        transitionOptions = []
        addTab("Overview", icon: "square.grid.2x2", view: OverviewView(model: model, settings: settings))
        addTab("Conversations", icon: "bubble.left.and.bubble.right", view: ConversationsView(model: model, settings: settings))
        addTab("History", icon: "chart.xyaxis.line", view: HistoryView(model: model))
        addTab("About", icon: "info.circle", view: AboutView())
    }

    private func addTab<V: View>(_ title: String, icon: String, view: V) {
        let controller = NSHostingController(rootView: view)
        let item = NSTabViewItem(viewController: controller)
        item.label = title
        item.identifier = title
        item.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        addTabViewItem(item)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let tabs = PreferencesController()
        let window = NSWindow(contentViewController: tabs)
        window.title = "WhatsCop"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.fullScreenNone]
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
        tabs.model.refresh(olderThanDays: tabs.settings.olderThanDays)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@MainActor
@main
struct WhatsCopApp {
    // NSApplication.delegate is weak; keep a strong reference for the app lifetime.
    private static let retainedDelegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = retainedDelegate
        // Manual AppKit entry points must complete launch before entering the run loop.
        app.finishLaunching()
        app.run()
    }
}
