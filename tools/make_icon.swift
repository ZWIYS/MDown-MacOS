import AppKit

let px = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let rect = NSRect(x: 100, y: 100, width: 824, height: 824)
let body = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)

NSGraphicsContext.saveGraphicsState()
let sh = NSShadow()
sh.shadowColor = NSColor.black.withAlphaComponent(0.28)
sh.shadowBlurRadius = 22
sh.shadowOffset = NSSize(width: 0, height: -10)
sh.set()
NSColor.white.setFill(); body.fill()
NSGraphicsContext.restoreGraphicsState()

NSGradient(colors: [NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1),
                    NSColor(srgbRed: 0.93, green: 0.94, blue: 0.97, alpha: 1)])!.draw(in: body, angle: -90)

func bar(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: NSColor) {
    c.setFill(); NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: h/2, yRadius: h/2).fill()
}
bar(205, 520, 614, 150, NSColor(srgbRed: 1, green: 0.92, blue: 0.52, alpha: 1))
bar(215, 300, 420, 44, NSColor(srgbRed: 0.77, green: 0.89, blue: 1, alpha: 1))
bar(215, 225, 300, 44, NSColor(srgbRed: 1, green: 0.82, blue: 0.89, alpha: 1))
bar(560, 225, 120, 44, NSColor(srgbRed: 0.80, green: 0.93, blue: 0.78, alpha: 1))

let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 330, weight: .heavy),
    .foregroundColor: NSColor(srgbRed: 0.16, green: 0.18, blue: 0.38, alpha: 1)]
let str = NSAttributedString(string: "M↓", attributes: attrs)
let sz = str.size()
str.draw(at: NSPoint(x: (CGFloat(px) - sz.width) / 2, y: 470))

NSGraphicsContext.restoreGraphicsState()
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
