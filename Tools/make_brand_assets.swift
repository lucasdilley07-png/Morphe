// Brand-kit asset generator (COACH-KIT §9): logo pack + demo share cards.
// Run:  swift Tools/make_brand_assets.swift docs/brand-kit
//
// Same M-mark geometry as make-app-icon.swift (1024 design space), same
// card specs as GlassCard.swift's ShareCardFrame at 3x (1080x1920).
// Demo cards carry a visible DEMO DATA chip — they show coaches what a
// card looks like without pretending anyone logged those numbers.

import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/brand-kit"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// MARK: - Palette (MorpheTheme)

let yellow = NSColor(srgbRed: 1.0, green: 0.839, blue: 0.0, alpha: 1)        // #FFD600
let ink = NSColor(srgbRed: 0.020, green: 0.020, blue: 0.024, alpha: 1)       // #050506
func white(_ alpha: CGFloat) -> NSColor { NSColor(srgbRed: 1, green: 1, blue: 1, alpha: alpha) }

// MARK: - Rendering plumbing

func renderPNG(width: Int, height: Int, name: String, draw: @escaping (NSRect) -> Void) {
    let image = NSImage(size: NSSize(width: width, height: height), flipped: true) { rect in
        draw(rect); return true
    }
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { fatalError("rep") }
    rep.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()
    guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
    let path = "\(outDir)/\(name)"
    try! data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

// MARK: - The M mark (geometry from Tools/make-app-icon.swift)

let leftPanel: [CGPoint] = [
    CGPoint(x: 244, y: 293), CGPoint(x: 390, y: 253),
    CGPoint(x: 390, y: 757), CGPoint(x: 244, y: 694),
]
let rightPanel: [CGPoint] = [
    CGPoint(x: 634, y: 253), CGPoint(x: 780, y: 293),
    CGPoint(x: 780, y: 694), CGPoint(x: 634, y: 757),
]
let centerChevron: [CGPoint] = [
    CGPoint(x: 419, y: 373), CGPoint(x: 512, y: 464), CGPoint(x: 605, y: 373),
    CGPoint(x: 605, y: 559), CGPoint(x: 512, y: 656), CGPoint(x: 419, y: 559),
]

/// Rounded-corner data for one polygon corner: entry point, control, exit.
func roundedCorners(_ pts: [CGPoint], radius: CGFloat) -> [(pA: CGPoint, c: CGPoint, pB: CGPoint)] {
    let n = pts.count
    return (0..<n).map { i in
        let prev = pts[(i + n - 1) % n], curr = pts[i], next = pts[(i + 1) % n]
        let v1 = CGVector(dx: curr.x - prev.x, dy: curr.y - prev.y)
        let v2 = CGVector(dx: next.x - curr.x, dy: next.y - curr.y)
        let l1 = max(hypot(v1.dx, v1.dy), 0.001), l2 = max(hypot(v2.dx, v2.dy), 0.001)
        let r = min(radius, l1 / 2, l2 / 2)
        return (CGPoint(x: curr.x - v1.dx / l1 * r, y: curr.y - v1.dy / l1 * r),
                curr,
                CGPoint(x: curr.x + v2.dx / l2 * r, y: curr.y + v2.dy / l2 * r))
    }
}

func markPath(scale: CGFloat, offset: CGPoint) -> NSBezierPath {
    let path = NSBezierPath()
    for polygon in [leftPanel, rightPanel, centerChevron] {
        let corners = roundedCorners(polygon, radius: polygon.count == 6 ? 17 : 23)
        for (i, corner) in corners.enumerated() {
            func pt(_ point: CGPoint) -> CGPoint {
                CGPoint(x: point.x * scale + offset.x, y: point.y * scale + offset.y)
            }
            let pA = pt(corner.pA), c = pt(corner.c), pB = pt(corner.pB)
            if i == 0 { path.move(to: pA) } else { path.line(to: pA) }
            // Quad -> cubic: c1 = pA + 2/3(c-pA), c2 = pB + 2/3(c-pB).
            path.curve(to: pB,
                       controlPoint1: CGPoint(x: pA.x + (c.x - pA.x) * 2 / 3, y: pA.y + (c.y - pA.y) * 2 / 3),
                       controlPoint2: CGPoint(x: pB.x + (c.x - pB.x) * 2 / 3, y: pB.y + (c.y - pB.y) * 2 / 3))
        }
        path.close()
    }
    return path
}

/// SVG twin of the same geometry (mark only — text-free, so no font risk).
func writeMarkSVG(name: String, fill: String) {
    var d = ""
    for polygon in [leftPanel, rightPanel, centerChevron] {
        let corners = roundedCorners(polygon, radius: polygon.count == 6 ? 17 : 23)
        for (i, corner) in corners.enumerated() {
            let f = { (p: CGPoint) in String(format: "%.1f %.1f", p.x, p.y) }
            d += (i == 0 ? "M \(f(corner.pA)) " : "L \(f(corner.pA)) ")
            d += "Q \(f(corner.c)) \(f(corner.pB)) "
        }
        d += "Z "
    }
    let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
      <path d="\(d)" fill="\(fill)"/>
    </svg>
    """
    let path = "\(outDir)/\(name)"
    try! svg.write(toFile: path, atomically: true, encoding: .utf8)
    print("wrote \(path)")
}

// MARK: - Text helpers

func mono(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    NSFont.monospacedSystemFont(ofSize: size, weight: weight)
}

func drawText(_ string: String, at point: CGPoint, font: NSFont, color: NSColor,
              kern: CGFloat = 0, rightAligned: Bool = false) {
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .kern: kern]
    let attributed = NSAttributedString(string: string, attributes: attrs)
    var origin = point
    if rightAligned {
        // Trailing kern pads the measured width — subtract it so the last
        // glyph, not its kern slot, touches the right edge.
        origin.x -= (attributed.size().width - kern)
    }
    attributed.draw(at: origin)
}

func textWidth(_ string: String, font: NSFont, kern: CGFloat = 0) -> CGFloat {
    NSAttributedString(string: string, attributes: [.font: font, .kern: kern]).size().width - kern
}

// MARK: - Logo pack

for (name, color) in [("morphe-mark-gold", yellow), ("morphe-mark-white", NSColor.white),
                      ("morphe-mark-black", NSColor.black)] {
    renderPNG(width: 1024, height: 1024, name: "\(name).png") { _ in
        color.setFill()
        markPath(scale: 1, offset: .zero).fill()
    }
}
renderPNG(width: 1024, height: 1024, name: "morphe-mark-ink-tile.png") { rect in
    ink.setFill(); rect.fill()
    yellow.setFill()
    markPath(scale: 1, offset: .zero).fill()
}
writeMarkSVG(name: "morphe-mark-gold.svg", fill: "#FFD600")
writeMarkSVG(name: "morphe-mark-white.svg", fill: "#FFFFFF")

// Wordmark: MORPHE, SF Mono black-weight, wide tracking — gold + white.
for (name, color) in [("morphe-wordmark-gold", yellow), ("morphe-wordmark-white", NSColor.white)] {
    let font = mono(220, .black), kern: CGFloat = 66
    let w = textWidth("MORPHE", font: font, kern: kern)
    renderPNG(width: Int(w) + 120, height: 320, name: "\(name).png") { rect in
        drawText("MORPHE", at: CGPoint(x: 60, y: (rect.height - font.capHeight) / 2 - (font.ascender - font.capHeight)),
                 font: font, color: color, kern: kern)
    }
}

// Lockup: mark over wordmark on ink — the social-avatar / header asset.
renderPNG(width: 1600, height: 1600, name: "morphe-lockup-ink.png") { rect in
    ink.setFill(); rect.fill()
    yellow.setFill()
    markPath(scale: 1.05, offset: CGPoint(x: (1600 - 1024 * 1.05) / 2, y: 120)).fill()
    let font = mono(130, .black), kern: CGFloat = 52
    let w = textWidth("MORPHE", font: font, kern: kern)
    drawText("MORPHE", at: CGPoint(x: (rect.width - w) / 2, y: 1180), font: font, color: .white, kern: kern)
    let tagFont = mono(44, .semibold), tagKern: CGFloat = 18
    let tw = textWidth("TRAIN HONEST", font: tagFont, kern: tagKern)
    drawText("TRAIN HONEST", at: CGPoint(x: (rect.width - tw) / 2, y: 1370),
             font: tagFont, color: yellow, kern: tagKern)
}

// MARK: - Demo share cards (ShareCardFrame at 3x = 1080x1920)

let pad: CGFloat = 108          // 36pt * 3

func drawCardChrome(_ rect: NSRect, dateLabel: String, username: String) {
    ink.setFill(); rect.fill()

    // Corner ticks: arm 48, stroke 3, inset 54 (16/1/18pt * 3).
    white(0.35).setFill()
    let arm: CGFloat = 48, stroke: CGFloat = 3, inset: CGFloat = 54
    let w = rect.width, h = rect.height
    for (x, y, horizontal) in [
        (inset, inset, true), (inset, inset, false),
        (w - inset - arm, inset, true), (w - inset - stroke, inset, false),
        (inset, h - inset - stroke, true), (inset, h - inset - arm, false),
        (w - inset - arm, h - inset - stroke, true), (w - inset - stroke, h - inset - arm, false),
    ] {
        NSRect(x: x, y: y, width: horizontal ? arm : stroke,
               height: horizontal ? stroke : arm).fill()
    }

    // Header: wordmark + date + the honesty chip.
    drawText("MORPHE", at: CGPoint(x: pad, y: pad), font: mono(66, .black), color: yellow, kern: 18)
    drawText(dateLabel.uppercased(), at: CGPoint(x: rect.width - pad, y: pad + 14),
             font: mono(33, .semibold), color: white(0.55), kern: 4.8, rightAligned: true)

    let demoFont = mono(27, .semibold)
    let demoW = textWidth("DEMO DATA", font: demoFont, kern: 4)
    let chip = NSRect(x: rect.width - pad - demoW - 36, y: pad + 78, width: demoW + 36, height: 54)
    white(0.30).setStroke()
    let outline = NSBezierPath(rect: chip); outline.lineWidth = 2; outline.stroke()
    drawText("DEMO DATA", at: CGPoint(x: chip.minX + 18, y: chip.minY + 11),
             font: demoFont, color: white(0.45), kern: 4)

    // Footer: hairline + handle + motto.
    white(0.18).setFill()
    NSRect(x: pad, y: rect.height - pad - 84, width: rect.width - pad * 2, height: 3).fill()
    drawText(username.uppercased(), at: CGPoint(x: pad, y: rect.height - pad - 42),
             font: mono(36, .semibold), color: white(0.7), kern: 4.8)
    drawText("TRAIN HONEST", at: CGPoint(x: rect.width - pad, y: rect.height - pad - 42),
             font: mono(36, .bold), color: yellow, kern: 4.8, rightAligned: true)
}

func drawFactRow(_ text: String, y: CGFloat, bullet: Bool = true) {
    if bullet {
        yellow.setFill()
        NSRect(x: pad, y: y + 14, width: 26, height: 10).fill()
    }
    drawText(text, at: CGPoint(x: pad + (bullet ? 48 : 0), y: y),
             font: mono(39, .bold), color: .white, kern: 3.6)
}

let cardW = 1080, cardH = 1920
let contentTop: CGFloat = 620   // upper-third start for the middle block

renderPNG(width: cardW, height: cardH, name: "demo-card-session.png") { rect in
    drawCardChrome(rect, dateLabel: "Aug 4", username: "@morphe_demo")
    drawText("SESSION COMPLETE", at: CGPoint(x: pad, y: contentTop),
             font: mono(36, .semibold), color: white(0.55), kern: 7.2)
    drawText("Lower Body", at: CGPoint(x: pad, y: contentTop + 76),
             font: .systemFont(ofSize: 120, weight: .black), color: .white)
    drawText("Strength", at: CGPoint(x: pad, y: contentTop + 210),
             font: .systemFont(ofSize: 120, weight: .black), color: .white)
    drawText("16 SETS · 5 MOVES · 48 MIN", at: CGPoint(x: pad, y: contentTop + 390),
             font: mono(45, .bold), color: yellow, kern: 3.6)
    drawFactRow("NEW PR · BACK SQUAT", y: contentTop + 500)
    drawFactRow("12-DAY STREAK", y: contentTop + 570)
}

renderPNG(width: cardW, height: cardH, name: "demo-card-pr.png") { rect in
    drawCardChrome(rect, dateLabel: "Aug 4", username: "@morphe_demo")
    drawText("NEW RECORD", at: CGPoint(x: pad, y: contentTop),
             font: mono(36, .semibold), color: white(0.55), kern: 7.2)
    drawText("Back Squat", at: CGPoint(x: pad, y: contentTop + 76),
             font: .systemFont(ofSize: 120, weight: .black), color: .white)
    drawText("225 LB", at: CGPoint(x: pad, y: contentTop + 260),
             font: mono(102, .bold), color: yellow)
    drawText("UP FROM 205 LB", at: CGPoint(x: pad, y: contentTop + 400),
             font: mono(39, .semibold), color: white(0.55), kern: 3.6)
}

renderPNG(width: cardW, height: cardH, name: "demo-card-streak.png") { rect in
    drawCardChrome(rect, dateLabel: "Aug 4", username: "@morphe_demo")
    drawText("CONSISTENCY", at: CGPoint(x: pad, y: contentTop),
             font: mono(36, .semibold), color: white(0.55), kern: 7.2)
    drawText("30", at: CGPoint(x: pad, y: contentTop + 70),
             font: mono(288, .bold), color: yellow)
    drawText("DAY STREAK", at: CGPoint(x: pad, y: contentTop + 420),
             font: mono(54, .bold), color: .white, kern: 9)
    drawText("EVERY DAY EARNED", at: CGPoint(x: pad, y: contentTop + 520),
             font: mono(36, .semibold), color: white(0.55), kern: 4.8)
}

renderPNG(width: cardW, height: cardH, name: "demo-card-week.png") { rect in
    drawCardChrome(rect, dateLabel: "Jul 20 – Jul 26", username: "@morphe_demo")
    drawText("WEEK IN REVIEW", at: CGPoint(x: pad, y: contentTop),
             font: mono(36, .semibold), color: white(0.55), kern: 7.2)
    drawText("5", at: CGPoint(x: pad, y: contentTop + 70),
             font: mono(288, .bold), color: yellow)
    drawText("SESSIONS", at: CGPoint(x: pad, y: contentTop + 420),
             font: mono(54, .bold), color: .white, kern: 9)
    drawText("62 SETS · 214 MIN", at: CGPoint(x: pad, y: contentTop + 530),
             font: mono(45, .bold), color: .white, kern: 3.6)
    drawFactRow("2 NEW PRS", y: contentTop + 640)
    drawFactRow("12-DAY STREAK", y: contentTop + 710)
}

print("brand kit complete -> \(outDir)")
