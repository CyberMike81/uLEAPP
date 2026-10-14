import AppKit

// SPDX-License-Identifier: MIT
// Original vector artwork using the bright LEAPP-family palette.
// Existing app icons are references only and are not redistributed.
// Every contour is drawn here; no SF Symbols, font outlines or stock art.
func color(_ value: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
            green: CGFloat((value >> 8) & 255) / 255,
            blue: CGFloat(value & 255) / 255, alpha: 1)
}
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
color(0x8EE563).setFill()
NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 1024, height: 1024), xRadius: 205, yRadius: 205).fill()

let leftPage = NSBezierPath()
leftPage.move(to: NSPoint(x: 108, y: 185))
leftPage.curve(to: NSPoint(x: 512, y: 178), controlPoint1: NSPoint(x: 275, y: 330), controlPoint2: NSPoint(x: 390, y: 300))
leftPage.line(to: NSPoint(x: 512, y: 284))
leftPage.curve(to: NSPoint(x: 145, y: 296), controlPoint1: NSPoint(x: 380, y: 418), controlPoint2: NSPoint(x: 265, y: 432))
leftPage.close()
let rightPage = NSBezierPath()
rightPage.move(to: NSPoint(x: 512, y: 178))
rightPage.curve(to: NSPoint(x: 916, y: 246), controlPoint1: NSPoint(x: 665, y: 325), controlPoint2: NSPoint(x: 796, y: 346))
rightPage.line(to: NSPoint(x: 878, y: 358))
rightPage.curve(to: NSPoint(x: 512, y: 284), controlPoint1: NSPoint(x: 736, y: 438), controlPoint2: NSPoint(x: 625, y: 410))
rightPage.close()
for (path, fill) in [(leftPage, color(0xF34C00)), (rightPage, color(0xFA3B6A))] {
    fill.setFill()
    path.fill()
    NSColor.black.setStroke()
    path.lineWidth = 39
    path.lineJoinStyle = .round
    path.stroke()
}
// Offset right-angle arrows make an original update loop around the badge.
for lower in [false, true] {
    NSGraphicsContext.saveGraphicsState()
    if lower {
        let transform = NSAffineTransform()
        transform.translateX(by: 1024, yBy: 1290)
        transform.rotate(byDegrees: 180)
        transform.concat()
    }
    let shaft = NSBezierPath()
    shaft.move(to: NSPoint(x: 230, y: 600))
    shaft.line(to: NSPoint(x: 230, y: 778))
    shaft.curve(to: NSPoint(x: 298, y: 846), controlPoint1: NSPoint(x: 230, y: 826), controlPoint2: NSPoint(x: 250, y: 846))
    shaft.line(to: NSPoint(x: 678, y: 846))
    shaft.lineWidth = 70
    shaft.lineCapStyle = .round
    NSColor.black.setStroke()
    shaft.stroke()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 650, y: 936))
    head.line(to: NSPoint(x: 812, y: 846))
    head.line(to: NSPoint(x: 650, y: 756))
    head.close()
    NSColor.black.setFill()
    head.fill()
    NSGraphicsContext.restoreGraphicsState()
}
let center = NSBezierPath(ovalIn: NSRect(x: 414, y: 548, width: 196, height: 196))
color(0xFA3B6A).setFill()
center.fill()
NSColor.black.setStroke()
center.lineWidth = 30
center.stroke()
let letter = NSBezierPath()
letter.move(to: NSPoint(x: 474, y: 689))
letter.line(to: NSPoint(x: 474, y: 630))
letter.curve(to: NSPoint(x: 550, y: 630), controlPoint1: NSPoint(x: 474, y: 581), controlPoint2: NSPoint(x: 550, y: 581))
letter.line(to: NSPoint(x: 550, y: 689))
letter.lineWidth = 26
letter.lineCapStyle = .round
NSColor.black.setStroke()
letter.stroke()
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render the icon")
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
