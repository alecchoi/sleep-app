import AppKit
import Foundation

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size, flipped: false) { rectangle in
    NSColor(red: 0.047, green: 0.059, blue: 0.098, alpha: 1).setFill()
    rectangle.fill()
    let lavender = NSColor(red: 0.773, green: 0.745, blue: 0.965, alpha: 1)
    for diameter: CGFloat in [700, 850] {
        lavender.withAlphaComponent(0.10).setStroke()
        let ring = NSBezierPath(ovalIn: NSRect(x: (1024-diameter)/2, y: (1024-diameter)/2, width: diameter, height: diameter))
        ring.lineWidth = 2
        ring.stroke()
    }
    if let moon = NSImage(systemSymbolName: "moon.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: 420, weight: .regular))?
        .withSymbolConfiguration(.init(paletteColors: [lavender])) {
        moon.draw(in: NSRect(x: 310, y: 295, width: 420, height: 440))
    }
    return true
}
var rectangle = CGRect(origin: .zero, size: size)
guard let cgImage = image.cgImage(forProposedRect: &rectangle, context: nil, hints: nil) else {
    fatalError("Could not render app icon")
}
let representation = NSBitmapImageRep(cgImage: cgImage)
guard let png = representation.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode app icon")
}
try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
try png.write(to: destination)
