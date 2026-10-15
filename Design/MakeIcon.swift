import AppKit

let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let bg = NSColor(red: 0.025, green: 0.043, blue: 0.061, alpha: 1)
let cyan = NSColor(red: 0.3, green: 0.91, blue: 0.96, alpha: 1)
let amber = NSColor(red: 1, green: 0.73, blue: 0.32, alpha: 1)
bg.setFill(); NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
NSColor.white.withAlphaComponent(0.10).setFill()
for x in stride(from: 64, through: 960, by: 64) { for y in stride(from: 64, through: 960, by: 64) { NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 3, height: 3)).fill() } }
cyan.setStroke()
let path = NSBezierPath(); path.lineWidth = 24; path.lineCapStyle = .round; path.lineJoinStyle = .round
path.move(to: NSPoint(x: 250, y: 290)); path.line(to: NSPoint(x: 250, y: 700)); path.line(to: NSPoint(x: 420, y: 700))
path.move(to: NSPoint(x: 610, y: 700)); path.line(to: NSPoint(x: 774, y: 700)); path.line(to: NSPoint(x: 774, y: 290)); path.line(to: NSPoint(x: 610, y: 290))
path.move(to: NSPoint(x: 420, y: 290)); path.line(to: NSPoint(x: 250, y: 290)); path.stroke()
amber.setStroke(); let resistor = NSBezierPath(); resistor.lineWidth = 24; resistor.lineJoinStyle = .round
resistor.move(to: NSPoint(x: 420, y: 700)); for i in 0..<7 { resistor.line(to: NSPoint(x: 430 + i * 28, y: i.isMultiple(of: 2) ? 670 : 730)) }; resistor.line(to: NSPoint(x: 610, y: 700)); resistor.stroke()
cyan.setStroke(); let capacitor = NSBezierPath(); capacitor.lineWidth = 24
capacitor.move(to: NSPoint(x: 420, y: 290)); capacitor.line(to: NSPoint(x: 482, y: 290)); capacitor.move(to: NSPoint(x: 482, y: 215)); capacitor.line(to: NSPoint(x: 482, y: 365))
capacitor.move(to: NSPoint(x: 548, y: 215)); capacitor.line(to: NSPoint(x: 548, y: 365)); capacitor.move(to: NSPoint(x: 548, y: 290)); capacitor.line(to: NSPoint(x: 610, y: 290)); capacitor.stroke()
for point in [NSPoint(x: 250, y: 700), NSPoint(x: 774, y: 290)] { bg.setFill(); let circle = NSBezierPath(ovalIn: NSRect(x: point.x - 31, y: point.y - 31, width: 62, height: 62)); circle.fill(); cyan.setStroke(); circle.lineWidth = 14; circle.stroke() }
NSGraphicsContext.restoreGraphicsState()
let output = CommandLine.arguments[1]
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
