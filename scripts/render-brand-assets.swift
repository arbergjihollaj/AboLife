import AppKit
import CoreText

// Reuses the exact typographic mark ("a.") from design-lab's Spatial concept.
// AppKit supplies the same macOS system font; no generated illustration is used.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let iconDirectory = root.appendingPathComponent("AboLife/Assets.xcassets/AppIcon.appiconset")
let markDirectory = root.appendingPathComponent("AboLife/Assets.xcassets/AppMark.imageset")
let mint = CGColor(red: 140 / 255, green: 245 / 255, blue: 212 / 255, alpha: 1)
let ink = CGColor(red: 19 / 255, green: 44 / 255, blue: 43 / 255, alpha: 1)
let tile = CGColor(red: 17 / 255, green: 29 / 255, blue: 41 / 255, alpha: 1)

func render(pixels: Int, appIcon: Bool) throws -> Data {
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext
    else { throw NSError(domain: "AboLife.Brand", code: 1) }
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    context.setAllowsAntialiasing(true)
    if appIcon {
        context.setFillColor(tile)
        context.addPath(
            CGPath(
                roundedRect: CGRect(x: 64, y: 64, width: 896, height: 896),
                cornerWidth: 202, cornerHeight: 202, transform: nil))
        context.fillPath()
    }
    let circle =
        appIcon
        ? CGRect(x: 200, y: 200, width: 624, height: 624)
        : CGRect(x: 0, y: 0, width: 1024, height: 1024)
    context.setFillColor(mint)
    context.fillEllipse(in: circle)
    let font = NSFont.systemFont(ofSize: circle.width * 0.82, weight: .semibold)
    let text = NSAttributedString(
        string: "a.",
        attributes: [
            .font: font,
            .kern: -circle.width * 0.025,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): ink,
        ])
    let line = CTLineCreateWithAttributedString(text)
    let bounds = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
    context.textMatrix = .identity
    context.textPosition = CGPoint(x: circle.midX - bounds.midX, y: circle.midY - bounds.midY)
    CTLineDraw(line, context)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "AboLife.Brand", code: 2)
    }
    return png
}

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        try render(pixels: size * scale, appIcon: true)
            .write(to: iconDirectory.appendingPathComponent("icon_\(size)x\(size)@\(scale)x.png"))
    }
}
for scale in 1...3 {
    try render(pixels: 28 * scale, appIcon: false)
        .write(to: markDirectory.appendingPathComponent("mark\(scale).png"))
}
try render(pixels: 512, appIcon: true).write(to: root.appendingPathComponent("web/public/icon.png"))
try render(pixels: 1024, appIcon: true).write(to: root.appendingPathComponent("docs/images/abolife-logo.png"))
print("Generated 10 macOS icon sizes, 3 brand scales, web icon and documentation master.")
