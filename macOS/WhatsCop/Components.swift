import SwiftUI
import AppKit

enum Display {
    static func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .binary)
    }
    static func signedBytes(_ count: Int64) -> String {
        if count == 0 { return "No change" }
        return (count > 0 ? "+" : "−") + bytes(abs(count))
    }
    static func icon() -> NSImage? {
        guard let file = Bundle.main.path(forResource: "AppIcon", ofType: "icns") else { return nil }
        return NSImage(contentsOfFile: file)
    }
}

struct MetricTile: View {
    var systemName: String
    var title: String
    var value: String
    var detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: systemName)
                    .foregroundStyle(Color.accentColor)
                    .font(.system(size: 13))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 25, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(height: 28, alignment: .topLeading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.38)))
    }
}

struct MediaRow: View {
    let label: String
    let kind: String
    let usage: Usage
    let total: Int64

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: kind == "File type" ? "doc" : "folder")
                .font(.system(size: 16))
                .foregroundStyle(Color.accentColor)
                .frame(width: 33, height: 33)
                .background(Color.accentColor.opacity(0.09),
                            in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 8)
                    Text(Display.bytes(usage.allocated))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(nsColor: .separatorColor).opacity(0.55))
                        Capsule().fill(Color.accentColor)
                            .frame(width: geo.size.width * min(1, CGFloat(usage.allocated) /
                                CGFloat(max(total, 1))))
                    }
                }
                .frame(height: 4)
                HStack {
                    Text(kind)
                    Spacer()
                    Text("\(usage.files.formatted()) files")
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

struct CardPanel<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .padding(.bottom, 2)
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.38)))
    }
}

struct ScanBanner: View {
    @ObservedObject var model: ReportModel
    let olderThanDays: Int

    var body: some View {
        HStack(spacing: 12) {
            if let icon = Display.icon() {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 49, height: 49)
            } else {
                Image(systemName: "externaldrive")
                    .frame(width: 49, height: 49)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("WhatsCop")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                Text("WhatsApp media · private disk analysis")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.isScanning { ProgressView().controlSize(.small) }
            Button {
                model.refresh(olderThanDays: olderThanDays)
            } label: {
                Label("Scan again", systemImage: "arrow.clockwise")
            }
            .disabled(model.isScanning)
        }
    }
}

struct PrivacyFooter: View {
    var body: some View {
        VStack(spacing: 8) {
            Divider()
            HStack(spacing: 7) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(Color.accentColor)
                Text("Read-only — WhatsCop never deletes messages or media")
                Spacer()
                Text("APFS sizes are estimates")
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
    }
}

struct LoadingPlaceholder: View {
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text(message).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
