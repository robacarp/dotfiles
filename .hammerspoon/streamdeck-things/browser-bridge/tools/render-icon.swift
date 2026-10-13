import AppKit

// Renders an SF Symbol to a square PNG, optionally on a rounded-rect
// background tile (bgHex + cornerRadiusFraction, both optional together).
// Usage: render-icon <symbol> <pointSize> <pixelSize> <hexColor> <outPath> [bgHex] [cornerRadiusFraction]

let args = CommandLine.arguments
guard args.count == 6 || args.count == 8,
      let pointSize = Double(args[2]),
      let pixelSize = Int(args[3]) else {
    FileHandle.standardError.write("usage: render-icon <symbol> <pointSize> <pixelSize> <hexColor> <outPath> [bgHex] [cornerRadiusFraction]\n".data(using: .utf8)!)
    exit(1)
}

let symbolName = args[1]
let hex = args[4]
let outPath = args[5]
let bgHex: String? = args.count == 8 ? args[6] : nil
let cornerRadiusFraction: Double = args.count == 8 ? Double(args[7])! : 0

func color(fromHex hex: String) -> NSColor {
    var s = hex
    if s.hasPrefix("#") { s.removeFirst() }
    var value: UInt64 = 0
    Scanner(string: s).scanHexInt64(&value)
    let r = CGFloat((value & 0xFF0000) >> 16) / 255
    let g = CGFloat((value & 0x00FF00) >> 8) / 255
    let b = CGFloat(value & 0x0000FF) / 255
    return NSColor(red: r, green: g, blue: b, alpha: 1)
}

let config = NSImage.SymbolConfiguration(pointSize: CGFloat(pointSize), weight: .regular)
guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
    .withSymbolConfiguration(config) else {
    FileHandle.standardError.write("symbol not found: \(symbolName)\n".data(using: .utf8)!)
    exit(1)
}

let tinted = NSImage(size: symbol.size, flipped: false) { rect in
    color(fromHex: hex).set()
    symbol.draw(in: rect)
    rect.fill(using: .sourceAtop)
    return true
}

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixelSize,
    pixelsHigh: pixelSize,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    FileHandle.standardError.write("failed to create bitmap rep\n".data(using: .utf8)!)
    exit(1)
}
rep.size = NSSize(width: pixelSize, height: pixelSize)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let glyphFraction: Double
if let bgHex {
    let canvasRect = NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
    let radius = Double(pixelSize) * cornerRadiusFraction
    let path = NSBezierPath(roundedRect: canvasRect, xRadius: radius, yRadius: radius)
    color(fromHex: bgHex).setFill()
    path.fill()
    glyphFraction = 0.5
} else {
    glyphFraction = 0.62
}

let symbolSize = tinted.size
let scale = min(Double(pixelSize) * glyphFraction / symbolSize.width, Double(pixelSize) * glyphFraction / symbolSize.height)
let drawSize = NSSize(width: symbolSize.width * scale, height: symbolSize.height * scale)
let origin = NSPoint(x: (Double(pixelSize) - drawSize.width) / 2, y: (Double(pixelSize) - drawSize.height) / 2)
tinted.draw(in: NSRect(origin: origin, size: drawSize), from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to rasterize\n".data(using: .utf8)!)
    exit(1)
}

try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
