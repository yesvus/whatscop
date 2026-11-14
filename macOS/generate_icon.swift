import AppKit
import Foundation

// Remove the neutral-color outer canvas of the supplied macOS icon.
// Flood-fill is restricted to pixels reachable from the image edges;
// internal near-white speech bubble details are retained.
let args = CommandLine.arguments
guard args.count == 3,
      let image = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: args[1]))),
      let output = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: image.pixelsWide,
        pixelsHigh: image.pixelsHigh,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
      ) else {
    fatalError("Usage: swift generate_icon.swift source.png output.png")
}

let w = image.pixelsWide
let h = image.pixelsHigh
let n = w * h
var colors = [NSColor](repeating: .clear, count: n)
var backgroundCandidate = [Bool](repeating: false, count: n)
for y in 0..<h {
    for x in 0..<w {
        let i = y * w + x
        let color = (image.colorAt(x: x, y: y) ?? .white).usingColorSpace(.deviceRGB) ?? .white
        colors[i] = color
        let r = color.redComponent
        let g = color.greenComponent
        let b = color.blueComponent
        backgroundCandidate[i] = !(g > r + 0.045 && g > b - 0.06)
    }
}
var visited = [Bool](repeating: false, count: n)
var queue = [Int]()
queue.reserveCapacity(n / 5)
func enqueue(_ i: Int) {
    if i >= 0 && i < n && !visited[i] && backgroundCandidate[i] {
        visited[i] = true
        queue.append(i)
    }
}
for x in 0..<w {
    enqueue(x)
    enqueue((h - 1) * w + x)
}
for y in 0..<h {
    enqueue(y * w)
    enqueue(y * w + w - 1)
}
var head = 0
while head < queue.count {
    let i = queue[head]
    head += 1
    let x = i % w
    if x > 0 { enqueue(i - 1) }
    if x + 1 < w { enqueue(i + 1) }
    if i >= w { enqueue(i - w) }
    if i + w < n { enqueue(i + w) }
}
for y in 0..<h {
    for x in 0..<w {
        let i = y * w + x
        let c = colors[i]
        output.setColor(
            NSColor(deviceRed: c.redComponent, green: c.greenComponent,
                    blue: c.blueComponent, alpha: visited[i] ? 0 : 1),
            atX: x, y: y
        )
    }
}
guard let png = output.representation(using: .png, properties: [:]) else {
    fatalError("Failed to encode icon")
}
try png.write(to: URL(fileURLWithPath: args[2]), options: .atomic)
print("Icon foreground: \(n - queue.count) pixels, background removed: \(queue.count)")
