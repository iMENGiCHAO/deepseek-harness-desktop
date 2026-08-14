import AppKit
import Foundation

let outDir = CommandLine.arguments.dropFirst().first ?? "build/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let corner = size * 0.22
    let background = NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner)
    let colors = [
        NSColor(srgbRed: 0.08, green: 0.15, blue: 0.34, alpha: 1),
        NSColor(srgbRed: 0.16, green: 0.32, blue: 0.92, alpha: 1)
    ]
    NSGradient(colors: colors)?.draw(in: background, angle: -60)

    let text = "dsh"
    let font = NSFont(name: "AvenirNext-Heavy", size: size * 0.27)
        ?? NSFont.systemFont(ofSize: size * 0.27, weight: .heavy)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]
    let string = NSAttributedString(string: text, attributes: attrs)
    let textSize = string.size()
    let origin = NSPoint(
        x: (size - textSize.width) / 2,
        y: (size - textSize.height) / 2 - size * 0.04
    )
    string.draw(at: origin)

    // Status dot: a small green accent under the wordmark.
    let dotRect = NSRect(x: size * 0.47, y: size * 0.185, width: size * 0.06, height: size * 0.06)
    NSColor(srgbRed: 0.35, green: 0.95, blue: 0.55, alpha: 1).setFill()
    NSBezierPath(ovalIn: dotRect).fill()

    return image
}

func writePNG(_ image: NSImage, size: CGFloat, to url: URL) {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return }
    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    if let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: url)
    }
}

let master = drawIcon(size: 1024)
let entries: [(CGFloat, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]
for (px, name) in entries {
    writePNG(master, size: px, to: URL(fileURLWithPath: outDir).appendingPathComponent(name))
}
print("icon set written to \(outDir)")
