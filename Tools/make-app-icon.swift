import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers

// Renders the Morphe "M" mark (three angular strokes) on a gold field.
// Geometry lives in a 1024x1024 space, tuned against the reference image.

let size = 1024
let args = CommandLine.arguments
let outPath = args.count > 1 ? args[1] : "icon.png"
// gold variants: 0 = reference-ish, 1 = darker gold, 2 = deep gold
let variant = args.count > 2 ? Int(args[2]) ?? 1 : 1

let golds: [(CGFloat, CGFloat, CGFloat)] = [
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

ctx.setFillColor(CGColor(srgbRed: ink.0, green: ink.1, blue: ink.2, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

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

ctx.setFillColor(CGColor(srgbRed: gold.0, green: gold.1, blue: gold.2, alpha: 1))

// Left panel: outer edge vertical, top tilts up toward center, bottom tilts
// down toward center.
let left: [CGPoint] = [
    CGPoint(x: 244, y: 293),   // top-left (outer)
    CGPoint(x: 390, y: 253),   // top-right (inner, higher)
    CGPoint(x: 390, y: 757),   // bottom-right (inner, lower)
    CGPoint(x: 244, y: 694),   // bottom-left (outer)
]
ctx.addPath(roundedPolygon(left, radius: 23))
ctx.fillPath()

// Right panel: mirror of the left around x = 512.
let right: [CGPoint] = [
    CGPoint(x: 634, y: 253),   // top-left (inner, higher)
    CGPoint(x: 780, y: 293),   // top-right (outer)
    CGPoint(x: 780, y: 694),   // bottom-right (outer)
    CGPoint(x: 634, y: 757),   // bottom-left (inner, lower)
]
ctx.addPath(roundedPolygon(right, radius: 23))
ctx.fillPath()

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
ctx.addPath(roundedPolygon(center, radius: 17))
ctx.fillPath()

guard let image = ctx.makeImage() else { fatalError("no image") }
let url = URL(fileURLWithPath: outPath) as CFURL
guard let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("no destination")
}
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote \(outPath) variant \(variant)")
