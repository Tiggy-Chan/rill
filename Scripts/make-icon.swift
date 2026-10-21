import AppKit

// Renders the 1024px app icon master: a white drop over a rainy night-blue tile.
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let side = 1024

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let canvas = NSRect(x: 0, y: 0, width: side, height: side)
// macOS icon grid: 824pt tile centered on a 1024pt canvas.
let tile = canvas.insetBy(dx: 100, dy: 100)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
shadow.shadowBlurRadius = 28
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.set()
NSColor.black.setFill()
tilePath.fill()
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.saveGraphicsState()
tilePath.addClip()
NSGradient(colors: [
    NSColor(srgbRed: 0.36, green: 0.62, blue: 0.98, alpha: 1),
    NSColor(srgbRed: 0.09, green: 0.15, blue: 0.36, alpha: 1),
])!.draw(in: tile, angle: -90)

// Deterministic rain streaks.
var seed: UInt64 = 0x5EED
func random() -> CGFloat {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return CGFloat(seed >> 33) / CGFloat(UInt64(1) << 31)
}
NSColor.white.withAlphaComponent(0.16).setStroke()
for _ in 0..<28 {
    let start = NSPoint(x: tile.minX + random() * tile.width, y: tile.minY + random() * tile.height)
    let length = 50 + random() * 80
    let streak = NSBezierPath()
    streak.lineWidth = 5
    streak.lineCapStyle = .round
    streak.move(to: start)
    streak.line(to: NSPoint(x: start.x - length * 0.16, y: start.y - length))
    streak.stroke()
}

let symbolConfig = NSImage.SymbolConfiguration(pointSize: 400, weight: .regular)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
if let drop = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(symbolConfig) {
    let size = drop.size
    let rect = NSRect(x: canvas.midX - size.width / 2, y: canvas.midY - size.height / 2 - 8,
                      width: size.width, height: size.height)
    let glow = NSShadow()
    glow.shadowColor = NSColor(srgbRed: 0.05, green: 0.10, blue: 0.30, alpha: 0.45)
    glow.shadowBlurRadius = 30
    glow.shadowOffset = NSSize(width: 0, height: -14)
    glow.set()
    drop.draw(in: rect)
}
NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.restoreGraphicsState()

try rep.representation(using: .png, properties: [:])!.write(to: output)
