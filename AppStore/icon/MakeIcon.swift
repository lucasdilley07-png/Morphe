import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let S = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0,
    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { fatalError("ctx") }

func c(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r, g, b, a])!
}

let f = Double(S) / 1024.0
let yellow = c(1.0, 0.839, 0.0)            // #FFD600
let yellowDeep = c(0.96, 0.74, 0.0)        // warmer lower edge

// --- Background: near-black vertical gradient (MorpheTheme ink range) ---
let bgTop = c(0.086, 0.086, 0.094)         // ~#161618
let bgBot = c(0.035, 0.035, 0.043)         // ~#09090B
let bgGrad = CGGradient(colorsSpace: cs, colors: [bgTop, bgBot] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bgGrad, start: CGPoint(x: 0, y: Double(S)), end: CGPoint(x: 0, y: 0), options: [])

// --- Radial yellow glow behind the mark ---
let glowCenter = CGPoint(x: Double(S) * 0.5, y: Double(S) * 0.54)
let glowGrad = CGGradient(colorsSpace: cs,
    colors: [c(1.0, 0.839, 0.0, 0.20), c(1.0, 0.839, 0.0, 0.0)] as CFArray,
    locations: [0, 1])!
ctx.drawRadialGradient(glowGrad,
    startCenter: glowCenter, startRadius: 0,
    endCenter: glowCenter, endRadius: Double(S) * 0.46, options: [])

// --- The "M": bold strokes, round joins, soft glow shadow ---
func p(_ x: Double, _ y: Double) -> CGPoint {
    // y given in top-origin design space; flip for CG bottom-origin.
    CGPoint(x: x * f, y: Double(S) - y * f)
}

let t: CGFloat = 118 * f          // stroke thickness
let topY = 312.0
let botY = 716.0
let valleyY = 596.0
let leftX = 286.0
let rightX = 738.0
let midX = 512.0

let mPath = CGMutablePath()
// Left leg (bottom -> top)
mPath.move(to: p(leftX, botY));   mPath.addLine(to: p(leftX, topY))
// Left diagonal (top of left leg -> center valley)
mPath.addLine(to: p(midX, valleyY))
// Right diagonal (center valley -> top of right leg)
mPath.addLine(to: p(rightX, topY))
// Right leg (top -> bottom)
mPath.addLine(to: p(rightX, botY))

ctx.setLineWidth(t)
ctx.setLineJoin(.round)
ctx.setLineCap(.round)

// Glow pass (blurred yellow shadow under the stroke).
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 38 * f, color: c(1.0, 0.85, 0.0, 0.55))
ctx.addPath(mPath)
ctx.setStrokeColor(yellow)
ctx.strokePath()
ctx.restoreGState()

// Solid mark with a subtle top->bottom gradient for depth.
ctx.saveGState()
ctx.addPath(mPath)
ctx.setStrokeColor(yellow)
ctx.replacePathWithStrokedPath()
ctx.clip()
let markGrad = CGGradient(colorsSpace: cs, colors: [yellow, yellowDeep] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(markGrad, start: CGPoint(x: 0, y: Double(S)), end: CGPoint(x: 0, y: 0), options: [])
ctx.restoreGState()

guard let img = ctx.makeImage() else { fatalError("img") }
let outURL = URL(fileURLWithPath: CommandLine.arguments[1])
guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil) else { fatalError("dest") }
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)
print("wrote \(outURL.path)")
