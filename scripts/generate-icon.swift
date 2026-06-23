import AppKit

// Renders the FocusSlot app icon to a 1024x1024 PNG.
// Usage: swift scripts/generate-icon.swift <output.png>

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"

let size = 1024
let canvas = NSRect(x: 0, y: 0, width: size, height: size)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1)
}

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Could not create bitmap")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Rounded "squircle" plate, inset like a native macOS icon.
let inset: CGFloat = 100
let plate = NSRect(x: inset, y: inset, width: CGFloat(size) - inset * 2, height: CGFloat(size) - inset * 2)
let radius: CGFloat = 185
let platePath = NSBezierPath(roundedRect: plate, xRadius: radius, yRadius: radius)

// Brand gradient: blue -> indigo (matches the app theme).
let gradient = NSGradient(colors: [
    color(59, 130, 246),   // blue-500
    color(67, 56, 202)     // indigo-700
])!
gradient.draw(in: platePath, angle: -90)

// Soft top highlight for depth.
platePath.addClip()
let highlight = NSGradient(colors: [
    NSColor(white: 1, alpha: 0.22),
    NSColor(white: 1, alpha: 0.0)
])!
let highlightRect = NSRect(x: plate.minX, y: plate.midY, width: plate.width, height: plate.height / 2)
highlight.draw(in: highlightRect, angle: -90)

// White time-block glyph via SF Symbol.
let config = NSImage.SymbolConfiguration(pointSize: 460, weight: .semibold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
if let symbol = NSImage(systemSymbolName: "calendar.badge.clock", accessibilityDescription: "FocusSlot")?
    .withSymbolConfiguration(config) {
    let box: CGFloat = 520
    let s = symbol.size
    let scale = min(box / s.width, box / s.height)
    let w = s.width * scale
    let h = s.height * scale
    let rect = NSRect(
        x: (CGFloat(size) - w) / 2,
        y: (CGFloat(size) - h) / 2 - 6,
        width: w,
        height: h
    )

    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0, alpha: 0.28)
    shadow.shadowBlurRadius = 22
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()

    symbol.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
}

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode PNG")
}
try! png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
_ = canvas
