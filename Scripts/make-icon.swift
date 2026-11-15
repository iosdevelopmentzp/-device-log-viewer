import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

ctx.saveGState()
let tileShadow = NSShadow()
tileShadow.shadowColor = color(0x000000, 0.28)
tileShadow.shadowBlurRadius = 24
tileShadow.shadowOffset = NSSize(width: 0, height: -10)
tileShadow.set()
color(0x0E3A47).setFill()
tilePath.fill()
ctx.restoreGState()

ctx.saveGState()
tilePath.addClip()
NSGradient(colors: [color(0x2A9D9A), color(0x17646F), color(0x0D3542)], atLocations: [0, 0.55, 1], colorSpace: .sRGB)!.draw(in: tile, angle: -90)
NSGradient(colors: [color(0xFFFFFF, 0.16), color(0xFFFFFF, 0)])!.draw(in: NSRect(x: tile.minX, y: tile.midY, width: tile.width, height: tile.height / 2), angle: -90)
ctx.restoreGState()

let sheet = NSRect(x: 252, y: 196, width: 470, height: 632)
let sheetPath = NSBezierPath(roundedRect: sheet, xRadius: 52, yRadius: 52)
ctx.saveGState()
let sheetShadow = NSShadow()
sheetShadow.shadowColor = color(0x06222A, 0.45)
sheetShadow.shadowBlurRadius = 40
sheetShadow.shadowOffset = NSSize(width: 0, height: -18)
sheetShadow.set()
color(0xF7F4EC).setFill()
sheetPath.fill()
ctx.restoreGState()

let rows: [(CGFloat, UInt32)] = [(300, 0x9AA3AE), (230, 0x4A90E2), (330, 0x9AA3AE), (260, 0xF5A623), (290, 0xE5484D), (210, 0x9AA3AE), (250, 0x9AA3AE)]
for (index, row) in rows.enumerated() {
    let y = sheet.maxY - 96 - CGFloat(index) * 72
    color(row.1).setFill()
    NSBezierPath(ovalIn: NSRect(x: sheet.minX + 52, y: y, width: 30, height: 30)).fill()
    color(0x3B4652, 0.55).setFill()
    NSBezierPath(roundedRect: NSRect(x: sheet.minX + 106, y: y + 3, width: row.0, height: 24), xRadius: 12, yRadius: 12).fill()
}

let lensCenter = NSPoint(x: 624, y: 384)
let lensRadius: CGFloat = 122
let lens = NSRect(x: lensCenter.x - lensRadius, y: lensCenter.y - lensRadius, width: lensRadius * 2, height: lensRadius * 2)

ctx.saveGState()
let lensShadow = NSShadow()
lensShadow.shadowColor = color(0x06222A, 0.5)
lensShadow.shadowBlurRadius = 30
lensShadow.shadowOffset = NSSize(width: 0, height: -12)
lensShadow.set()

let handle = NSBezierPath()
handle.lineWidth = 62
handle.lineCapStyle = .round
let angle = -CGFloat.pi / 4
handle.move(to: NSPoint(x: lensCenter.x + cos(angle) * (lensRadius + 20), y: lensCenter.y + sin(angle) * (lensRadius + 20)))
handle.line(to: NSPoint(x: lensCenter.x + cos(angle) * (lensRadius + 128), y: lensCenter.y + sin(angle) * (lensRadius + 128)))
color(0xF5A623).setStroke()
handle.stroke()

let ring = NSBezierPath(ovalIn: lens)
ring.lineWidth = 40
ring.stroke()
ctx.restoreGState()

color(0xFFFFFF, 0.35).setFill()
NSBezierPath(ovalIn: lens.insetBy(dx: 20, dy: 20)).fill()
let glint = NSBezierPath()
glint.lineWidth = 18
glint.lineCapStyle = .round
glint.appendArc(withCenter: lensCenter, radius: lensRadius - 50, startAngle: 110, endAngle: 160)
color(0xFFFFFF, 0.85).setStroke()
glint.stroke()

image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
