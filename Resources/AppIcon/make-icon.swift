// Draws PokéBinder's app icon and writes a complete .iconset.
//
//   swift Resources/AppIcon/make-icon.swift <output.iconset>
//   iconutil -c icns <output.iconset> -o Resources/AppIcon.icns
//
// The design is a Poké Ball taken full-bleed rather than a ball floating on a
// background: red above, white below, one black belt across the middle with the
// button sitting on it. Everything is proportional to the icon's side, so the same
// code draws 16pt and 1024pt without a second set of numbers.
//
// The artwork is masked to a superellipse — the shape macOS uses for app icons —
// since it runs to all four edges and would otherwise be a hard square. macOS draws
// a .icns exactly as given, with no mask and no margin of its own, so both are drawn
// here: the body fills 80.5% of the canvas, which is Apple's own icon grid and what
// keeps this icon the same visual size as everything else in the Dock.

import AppKit
import CoreGraphics
import Foundation

// MARK: - Design

enum Design {
    /// Fractions of the icon's side.
    static let beltThickness: CGFloat = 0.062
    static let buttonOuterRadius: CGFloat = 0.148
    static let buttonInnerRadius: CGFloat = 0.094

    /// Flat colour, matching the reference: a warm red, a soft near-black, plain white.
    static let red = CGColor(srgbRed: 0xD9 / 255, green: 0x3A / 255, blue: 0x2E / 255, alpha: 1)
    static let ink = CGColor(srgbRed: 0x26 / 255, green: 0x26 / 255, blue: 0x26 / 255, alpha: 1)
    static let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)

    /// Apple's icon silhouette is a superellipse, not a rounded rectangle: the corner
    /// flows into the straight edge instead of meeting it at a tangent point. n = 5 is
    /// the exponent that matches it closely at icon sizes.
    static let squircleExponent: CGFloat = 5

    /// Apple's icon grid: an 824pt body on a 1024pt canvas. Filling the whole canvas
    /// would make this icon visibly larger than its neighbours in the Dock.
    static let bodyFraction: CGFloat = 824.0 / 1024.0
}

/// The icon's silhouette: a superellipse inscribed in the body square.
func squircle(canvas: CGFloat) -> CGPath {
    let body = canvas * Design.bodyFraction
    let a = body / 2
    let centre = canvas / 2
    let n = 2 / Design.squircleExponent
    let path = CGMutablePath()
    let steps = 720
    for step in 0...steps {
        let t = CGFloat(step) / CGFloat(steps) * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = centre + a * (c < 0 ? -1 : 1) * pow(abs(c), n)
        let y = centre + a * (s < 0 ? -1 : 1) * pow(abs(s), n)
        if step == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()
    return path
}

func drawIcon(canvas side: CGFloat) -> CGImage? {
    guard let ctx = CGContext(
        data: nil,
        width: Int(side),
        height: Int(side),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    // Everything below is clipped to the icon silhouette, so the artwork can run to
    // the edges without squaring off the corners.
    ctx.addPath(squircle(canvas: side))
    ctx.clip()

    // The ball's proportions are relative to the body, not the canvas, so the margin
    // around it never changes the design.
    let body = side * Design.bodyFraction
    let mid = side / 2
    let belt = Design.beltThickness * body

    // White below, red above, belt across the seam.
    ctx.setFillColor(Design.white)
    ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))

    ctx.setFillColor(Design.red)
    ctx.fill(CGRect(x: 0, y: mid + belt / 2, width: side, height: side - (mid + belt / 2)))

    ctx.setFillColor(Design.ink)
    ctx.fill(CGRect(x: 0, y: mid - belt / 2, width: side, height: belt))

    // The button: a black disc on the belt with a white centre.
    let outer = Design.buttonOuterRadius * body
    let inner = Design.buttonInnerRadius * body
    ctx.setFillColor(Design.ink)
    ctx.fillEllipse(in: CGRect(x: mid - outer, y: mid - outer, width: outer * 2, height: outer * 2))
    ctx.setFillColor(Design.white)
    ctx.fillEllipse(in: CGRect(x: mid - inner, y: mid - inner, width: inner * 2, height: inner * 2))

    return ctx.makeImage()
}

// MARK: - Output

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <output.iconset>\n".utf8))
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

/// The ten entries `iconutil` expects, as (point size, scale).
let variants: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1),
    (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)
]

for variant in variants {
    let pixels = variant.points * variant.scale
    guard let image = drawIcon(canvas: CGFloat(pixels)) else {
        FileHandle.standardError.write(Data("could not draw \(pixels)px\n".utf8))
        exit(1)
    }
    let suffix = variant.scale == 1 ? "" : "@\(variant.scale)x"
    let name = "icon_\(variant.points)x\(variant.points)\(suffix).png"
    let url = outputDirectory.appendingPathComponent(name)
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: pixels, height: pixels)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("could not encode \(name)\n".utf8))
        exit(1)
    }
    try png.write(to: url)
    print("wrote \(name) (\(pixels)px)")
}
