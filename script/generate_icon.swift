import AppKit
import Foundation

let outDir = ProcessInfo.processInfo.environment["ICON_OUT"] ?? "build/AppIcon.iconset"
let sourcePath = ProcessInfo.processInfo.environment["ICON_SOURCE"]
    ?? "Resources/AppIconSource.jpg"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    guard let source = NSImage(contentsOfFile: sourcePath) else {
        return image
    }

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let corner = size * 0.22
    let clip = NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner)
    clip.addClip()

    // Aspect-fill the source image so it covers the canvas without distortion.
    let sourceSize = source.size
    let scale = max(size / sourceSize.width, size / sourceSize.height)
    let drawSize = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
    let drawRect = NSRect(
        x: (size - drawSize.width) / 2,
        y: (size - drawSize.height) / 2,
        width: drawSize.width,
        height: drawSize.height
    )
    source.draw(in: drawRect)

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
