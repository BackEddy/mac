// Gera o ícone original do Force TM (1024x1024 PNG) — uso: swift icon.swift saida.png
// Conceito: anel de "força" (aberto no topo, como um botão de energia) com um raio no centro.
// Paleta laranja → magenta, bem diferente do ícone verde do Time Machine.
import AppKit
let S = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: S, pixelsHigh: S, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let size = CGFloat(S), inset: CGFloat = 100
let tile = NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: size - 2*inset, height: size - 2*inset),
                        xRadius: 185, yRadius: 185)

// sombra do bloco
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shadow.shadowBlurRadius = 24; shadow.shadowOffset = NSSize(width: 0, height: -12); shadow.set()
NSColor.black.setFill(); tile.fill()
NSGraphicsContext.restoreGraphicsState()

// fundo laranja → magenta
NSGradient(colors: [NSColor(calibratedRed: 0.86, green: 0.16, blue: 0.47, alpha: 1),
                    NSColor(calibratedRed: 0.98, green: 0.42, blue: 0.20, alpha: 1),
                    NSColor(calibratedRed: 1.00, green: 0.67, blue: 0.18, alpha: 1)])!.draw(in: tile, angle: 90)
// brilho no topo
NSGraphicsContext.saveGraphicsState()
tile.addClip()
NSGradient(starting: NSColor.white.withAlphaComponent(0.20), ending: NSColor.white.withAlphaComponent(0))!
    .draw(in: NSRect(x: inset, y: size/2, width: size - 2*inset, height: size/2 - inset), angle: 90)
NSGraphicsContext.restoreGraphicsState()

let c = NSPoint(x: size/2, y: size/2 - 4)

// sombra suave dos elementos brancos
NSGraphicsContext.saveGraphicsState()
let s2 = NSShadow()
s2.shadowColor = NSColor(calibratedRed: 0.45, green: 0.05, blue: 0.20, alpha: 0.45)
s2.shadowBlurRadius = 18; s2.shadowOffset = NSSize(width: 0, height: -8); s2.set()

// anel aberto no topo (300°)
NSColor.white.setStroke()
let ring = NSBezierPath()
ring.appendArc(withCenter: c, radius: 262, startAngle: 120, endAngle: 60, clockwise: false)
ring.lineWidth = 66; ring.lineCapStyle = .round
ring.stroke()

// raio central
let pts: [(CGFloat, CGFloat)] = [(48, 215), (-110, -18), (-8, -18), (-52, -215), (112, 30), (10, 30), (70, 215)]
let bolt = NSBezierPath()
bolt.move(to: NSPoint(x: c.x + pts[0].0, y: c.y + pts[0].1))
for p in pts.dropFirst() { bolt.line(to: NSPoint(x: c.x + p.0, y: c.y + p.1)) }
bolt.close()
bolt.lineJoinStyle = .round
NSColor.white.setFill(); bolt.fill()
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
