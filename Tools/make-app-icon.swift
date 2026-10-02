import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers

// Renders the Morphe Spartan helmet (rebrand 2026-10-01) — an original
// geometric corinthian silhouette drawn from the ancient armor form in
// the app's rounded-polygon language — white glass on a blue field.
// Geometry lives in a 1024x1024 space, shared with MorpheMarkShape.

let size = 1024
let args = CommandLine.arguments
let outPath = args.count > 1 ? args[1] : "icon.png"
// variants: 0 = white helmet on blue field (DEFAULT — the app icon),
// 1 = blue helmet on transparent (LaunchMark asset)
let variant = args.count > 2 ? Int(args[2]) ?? 0 : 0

let brandBlue: (CGFloat, CGFloat, CGFloat) = (0.161, 0.341, 0.851)   // #2957D9
let markWhite: (CGFloat, CGFloat, CGFloat) = (1.0, 1.0, 1.0)
let mark = variant == 1 ? brandBlue : markWhite

guard let ctx = CGContext(data: nil, width: size, height: size,
                          bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                          bitmapInfo: variant == 1
                              ? CGImageAlphaInfo.premultipliedLast.rawValue
                              : CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("no context")
}

// Flip to a top-left origin so coordinates read like the design space.
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: 1, y: -1)

// Apple-glass rendering on the Spartan blue field (variant 0 only) — a
// depth gradient so the mark reads as an object; variant 1 stays clear.
if variant == 0 {
    let bgColors = [
        CGColor(srgbRed: 0.212, green: 0.420, blue: 0.941, alpha: 1),   // lifted top blue
        CGColor(srgbRed: 0.090, green: 0.192, blue: 0.541, alpha: 1)    // deep base blue
    ] as CFArray
    let bgGradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                                colors: bgColors, locations: [0, 1])!
    ctx.drawLinearGradient(bgGradient,
                           start: CGPoint(x: 512, y: 0),
                           end: CGPoint(x: 512, y: 1024), options: [])
    // Faint ambient white bloom behind the helmet.
    let bloom = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                           colors: [CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.14),
                                    CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0)] as CFArray,
                           locations: [0, 1])!
    ctx.drawRadialGradient(bloom, startCenter: CGPoint(x: 512, y: 470), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 470), endRadius: 430, options: [])
}

/// Rounded polygon path.
func roundedPolygon(_ pts: [CGPoint], radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let n = pts.count
    for i in 0..<n {
        let prev = pts[(i + n - 1) % n]
        let curr = pts[i]
        let next = pts[(i + 1) % n]
        let v1 = CGVector(dx: curr.x - prev.x, dy: curr.y - prev.y)
        let v2 = CGVector(dx: next.x - curr.x, dy: next.y - curr.y)
        let l1 = max(sqrt(v1.dx * v1.dx + v1.dy * v1.dy), 0.001)
        let l2 = max(sqrt(v2.dx * v2.dx + v2.dy * v2.dy), 0.001)
        let r = min(radius, l1 / 2, l2 / 2)
        let pA = CGPoint(x: curr.x - v1.dx / l1 * r, y: curr.y - v1.dy / l1 * r)
        let pB = CGPoint(x: curr.x + v2.dx / l2 * r, y: curr.y + v2.dy / l2 * r)
        if i == 0 { path.move(to: pA) } else { path.addLine(to: pA) }
        path.addQuadCurve(to: pB, control: curr)
    }
    path.closeSubpath()
    return path
}

// Helmet pieces collected into one path so shadow, gradient, and sheen
// apply to the whole mark as a single glass object. Negative space (eye
// band, mouth slits) is the field showing through between pieces.
let markPath = CGMutablePath()

// Low wedge crest above the dome.
let crest: [CGPoint] = [
    CGPoint(x: 432, y: 172), CGPoint(x: 512, y: 120), CGPoint(x: 592, y: 172),
    CGPoint(x: 576, y: 206), CGPoint(x: 512, y: 186), CGPoint(x: 448, y: 206),
]
markPath.addPath(roundedPolygon(crest, radius: 12))

// Dome + brow + nose guard: the brow underside runs flat at y 460 and the
// nose descends between the eye openings to its tip.
let dome: [CGPoint] = [
    CGPoint(x: 336, y: 460), CGPoint(x: 326, y: 352), CGPoint(x: 366, y: 258),
    CGPoint(x: 452, y: 204), CGPoint(x: 512, y: 194), CGPoint(x: 572, y: 204),
    CGPoint(x: 658, y: 258), CGPoint(x: 698, y: 352), CGPoint(x: 688, y: 460),
    CGPoint(x: 548, y: 460), CGPoint(x: 548, y: 688), CGPoint(x: 512, y: 716),
    CGPoint(x: 476, y: 688), CGPoint(x: 476, y: 460),
]
markPath.addPath(roundedPolygon(dome, radius: 20))

// Cheek guards, tapering to the jaw.
let cheekLeft: [CGPoint] = [
    CGPoint(x: 338, y: 492), CGPoint(x: 462, y: 492), CGPoint(x: 462, y: 640),
    CGPoint(x: 430, y: 766), CGPoint(x: 396, y: 830), CGPoint(x: 344, y: 770),
    CGPoint(x: 324, y: 640), CGPoint(x: 330, y: 548),
]
markPath.addPath(roundedPolygon(cheekLeft, radius: 16))
let cheekRight: [CGPoint] = [
    CGPoint(x: 686, y: 492), CGPoint(x: 562, y: 492), CGPoint(x: 562, y: 640),
    CGPoint(x: 594, y: 766), CGPoint(x: 628, y: 830), CGPoint(x: 680, y: 770),
    CGPoint(x: 700, y: 640), CGPoint(x: 694, y: 548),
]
markPath.addPath(roundedPolygon(cheekRight, radius: 16))

// 1. Soft lift: the mark floats off the field.
ctx.saveGState()
if variant == 0 {
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 36,
                  color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.35))
}
ctx.addPath(markPath)
ctx.setFillColor(CGColor(srgbRed: mark.0, green: mark.1, blue: mark.2, alpha: 1))
ctx.fillPath()
ctx.restoreGState()

// 2. Glass body: light pours from the top of the M to a deeper base.
ctx.saveGState()
ctx.addPath(markPath)
ctx.clip()
let glassColors = variant == 1
    ? [CGColor(srgbRed: 0.306, green: 0.471, blue: 0.941, alpha: 1), // lit blue top
       CGColor(srgbRed: brandBlue.0, green: brandBlue.1, blue: brandBlue.2, alpha: 1),
       CGColor(srgbRed: 0.098, green: 0.212, blue: 0.573, alpha: 1)] as CFArray
    : [CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1),      // lit white top
       CGColor(srgbRed: 0.929, green: 0.949, blue: 1.0, alpha: 1),  // cool mid
       CGColor(srgbRed: 0.788, green: 0.843, blue: 0.957, alpha: 1)] as CFArray
let glass = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                       colors: glassColors, locations: [0, 0.55, 1])!
ctx.drawLinearGradient(glass,
                       start: CGPoint(x: 512, y: 120),
                       end: CGPoint(x: 512, y: 830), options: [])

// 3. Specular sheen: the bubble highlight — a broad ellipse of white
// falling off across the upper half, clipped to the mark.
ctx.saveGState()
let sheenRect = CGRect(x: 160, y: 180, width: 704, height: 300)
ctx.addEllipse(in: sheenRect)
ctx.clip()
let sheen = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                       colors: [CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.42),
                                CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.0)] as CFArray,
                       locations: [0, 1])!
ctx.drawLinearGradient(sheen,
                       start: CGPoint(x: 512, y: 200),
                       end: CGPoint(x: 512, y: 480), options: [])
ctx.restoreGState()

// 4. Bottom edge glow: a whisper of reflected light along the base.
let rim = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                     colors: [CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.0),
                              CGColor(srgbRed: 0.75, green: 0.84, blue: 1, alpha: 0.18)] as CFArray,
                     locations: [0, 1])!
ctx.drawLinearGradient(rim,
                       start: CGPoint(x: 512, y: 640),
                       end: CGPoint(x: 512, y: 830), options: [])
ctx.restoreGState()

guard let image = ctx.makeImage() else { fatalError("no image") }
let url = URL(fileURLWithPath: outPath) as CFURL
guard let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("no destination")
}
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote \(outPath) variant \(variant)")
