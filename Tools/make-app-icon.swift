import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers

// Renders the Morphe "M" mark (three angular strokes) on a gold field.
// Geometry lives in a 1024x1024 space, tuned against the reference image.

let size = 1024
let args = CommandLine.arguments
let outPath = args.count > 1 ? args[1] : "icon.png"
// gold variants: 0 = brand yellow (DEFAULT — matches every in-app button),
// 1 = reference gold, 2 = darker gold, 3 = deep gold
let variant = args.count > 2 ? Int(args[2]) ?? 0 : 0

let golds: [(CGFloat, CGFloat, CGFloat)] = [
    (1.0, 0.839, 0.0),       // #FFD600 brand yellow — MorpheTheme.accent
    (0.941, 0.706, 0.161),   // #F0B429 reference
    (0.871, 0.647, 0.110),   // #DEA51C darker gold
    (0.796, 0.573, 0.075),   // #CB9213 deep gold
]
let gold = golds[min(variant, golds.count - 1)]
let ink: (CGFloat, CGFloat, CGFloat) = (0, 0, 0) // pure black

guard let ctx = CGContext(data: nil, width: size, height: size,
                          bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("no context")
}

// Flip to a top-left origin so coordinates read like the design space.
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: 1, y: -1)

// Glass restyle (2026-08-10): same M, Apple-glass rendering — a subtle
// depth gradient replaces the flat field so the mark reads as an object.
let bgColors = [
    CGColor(srgbRed: 0.075, green: 0.075, blue: 0.086, alpha: 1),   // lifted top
    CGColor(srgbRed: 0.016, green: 0.016, blue: 0.020, alpha: 1)    // deep base
] as CFArray
let bgGradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                            colors: bgColors, locations: [0, 1])!
ctx.drawLinearGradient(bgGradient,
                       start: CGPoint(x: 512, y: 0),
                       end: CGPoint(x: 512, y: 1024), options: [])
// Faint ambient gold bloom behind the mark.
let bloom = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                       colors: [CGColor(srgbRed: gold.0, green: gold.1, blue: gold.2, alpha: 0.16),
                                CGColor(srgbRed: gold.0, green: gold.1, blue: gold.2, alpha: 0)] as CFArray,
                       locations: [0, 1])!
ctx.drawRadialGradient(bloom, startCenter: CGPoint(x: 512, y: 470), startRadius: 0,
                       endCenter: CGPoint(x: 512, y: 470), endRadius: 430, options: [])

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

// Panels collected into one path so shadow, gradient, and sheen apply
// to the whole mark as a single glass object.
let markPath = CGMutablePath()

// Left panel: outer edge vertical, top tilts up toward center, bottom tilts
// down toward center.
let left: [CGPoint] = [
    CGPoint(x: 244, y: 293),   // top-left (outer)
    CGPoint(x: 390, y: 253),   // top-right (inner, higher)
    CGPoint(x: 390, y: 757),   // bottom-right (inner, lower)
    CGPoint(x: 244, y: 694),   // bottom-left (outer)
]
markPath.addPath(roundedPolygon(left, radius: 23))

// Right panel: mirror of the left around x = 512.
let right: [CGPoint] = [
    CGPoint(x: 634, y: 253),   // top-left (inner, higher)
    CGPoint(x: 780, y: 293),   // top-right (outer)
    CGPoint(x: 780, y: 694),   // bottom-right (outer)
    CGPoint(x: 634, y: 757),   // bottom-left (inner, lower)
]
markPath.addPath(roundedPolygon(right, radius: 23))

// Center stroke: chevron band pointing down — vertical sides, top V dip,
// bottom V point.
let center: [CGPoint] = [
    CGPoint(x: 419, y: 373),   // top-left
    CGPoint(x: 512, y: 464),   // top dip
    CGPoint(x: 605, y: 373),   // top-right
    CGPoint(x: 605, y: 559),   // right side bottom
    CGPoint(x: 512, y: 656),   // bottom point
    CGPoint(x: 419, y: 559),   // left side bottom
]
markPath.addPath(roundedPolygon(center, radius: 17))

// 1. Soft lift: the mark floats off the field.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 36,
              color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.55))
ctx.addPath(markPath)
ctx.setFillColor(CGColor(srgbRed: gold.0, green: gold.1, blue: gold.2, alpha: 1))
ctx.fillPath()
ctx.restoreGState()

// 2. Glass body: light pours from the top of the M to a deeper base.
ctx.saveGState()
ctx.addPath(markPath)
ctx.clip()
let glassColors = [
    CGColor(srgbRed: 1.0, green: 0.905, blue: 0.36, alpha: 1),      // lit top
    CGColor(srgbRed: gold.0, green: gold.1, blue: gold.2, alpha: 1), // brand mid
    CGColor(srgbRed: 0.83, green: 0.62, blue: 0.0, alpha: 1)        // deep base
] as CFArray
let glass = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                       colors: glassColors, locations: [0, 0.55, 1])!
ctx.drawLinearGradient(glass,
                       start: CGPoint(x: 512, y: 253),
                       end: CGPoint(x: 512, y: 757), options: [])

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
                              CGColor(srgbRed: 1, green: 0.95, blue: 0.7, alpha: 0.18)] as CFArray,
                     locations: [0, 1])!
ctx.drawLinearGradient(rim,
                       start: CGPoint(x: 512, y: 600),
                       end: CGPoint(x: 512, y: 757), options: [])
ctx.restoreGState()

guard let image = ctx.makeImage() else { fatalError("no image") }
let url = URL(fileURLWithPath: outPath) as CFURL
guard let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("no destination")
}
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote \(outPath) variant \(variant)")
