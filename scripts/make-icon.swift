import AppKit

let destination = CommandLine.arguments[1]
var entries = Data()
func bigEndian(_ value: Int) -> Data {
    var number = UInt32(value).bigEndian
    return withUnsafeBytes(of: &number) { Data($0) }
}
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let p = CGFloat(pixels)
        let rect = NSRect(x: p * 0.08, y: p * 0.08, width: p * 0.84, height: p * 0.84)
        let path = NSBezierPath(roundedRect: rect, xRadius: p * 0.19, yRadius: p * 0.19)
        NSColor(red: 0.09, green: 0.13, blue: 0.16, alpha: 1).setFill()
        path.fill()
        NSColor(red: 0.38, green: 0.85, blue: 0.73, alpha: 1).setStroke()
        let mark = NSBezierPath()
        mark.lineWidth = p * 0.055
        mark.lineCapStyle = .round
        mark.lineJoinStyle = .round
        mark.move(to: NSPoint(x: p * 0.28, y: p * 0.61))
        mark.line(to: NSPoint(x: p * 0.41, y: p * 0.50))
        mark.line(to: NSPoint(x: p * 0.28, y: p * 0.39))
        mark.move(to: NSPoint(x: p * 0.49, y: p * 0.39))
        mark.line(to: NSPoint(x: p * 0.69, y: p * 0.39))
        mark.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let data = bitmap.representation(using: .png, properties: [:])!
        let types = [16: ["icp4", "ic11"], 32: ["icp5", "ic12"], 128: ["ic07", "ic13"], 256: ["ic08", "ic14"], 512: ["ic09", "ic10"]]
        entries.append(Data(types[size]![scale - 1].utf8))
        entries.append(bigEndian(data.count + 8))
        entries.append(data)
    }
}
var icon = Data("icns".utf8)
icon.append(bigEndian(entries.count + 8))
icon.append(entries)
try icon.write(to: URL(fileURLWithPath: destination))
