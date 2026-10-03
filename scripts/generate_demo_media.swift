import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct DemoClipSpec {
    let filename: String
    let title: String
    let subtitle: String
    let accent: NSColor
    let bodyHighlights: [BodyHighlight]
    let motion: MotionStyle
}

struct BodyHighlight {
    let rect: CGRect
    let color: NSColor
}

enum MotionStyle {
    case press, pull, squat, hinge, lunge, curl, extensionMove, shoulder, calf, core, carry, generic
}

let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("LiftRankApp/Resources/DemoMedia", isDirectory: true)

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let exerciseClips: [DemoClipSpec] = [
    .init(filename: "demo-horizontal-press.gif", title: "Horizontal Press", subtitle: "Press with chest, front delts, and triceps", accent: .systemBlue, bodyHighlights: [
        .init(rect: CGRect(x: 0.28, y: 0.56, width: 0.16, height: 0.12), color: .systemBlue),
        .init(rect: CGRect(x: 0.56, y: 0.56, width: 0.16, height: 0.12), color: .systemBlue),
        .init(rect: CGRect(x: 0.18, y: 0.40, width: 0.12, height: 0.12), color: .systemBlue),
        .init(rect: CGRect(x: 0.70, y: 0.40, width: 0.12, height: 0.12), color: .systemBlue)
    ], motion: .press),
    .init(filename: "demo-vertical-press.gif", title: "Vertical Press", subtitle: "Drive the bar overhead", accent: .systemTeal, bodyHighlights: [
        .init(rect: CGRect(x: 0.30, y: 0.56, width: 0.12, height: 0.18), color: .systemTeal),
        .init(rect: CGRect(x: 0.58, y: 0.56, width: 0.12, height: 0.18), color: .systemTeal),
        .init(rect: CGRect(x: 0.28, y: 0.28, width: 0.18, height: 0.10), color: .systemTeal)
    ], motion: .press),
    .init(filename: "demo-horizontal-pull.gif", title: "Horizontal Pull", subtitle: "Row with upper back and lats", accent: .systemIndigo, bodyHighlights: [
        .init(rect: CGRect(x: 0.22, y: 0.46, width: 0.18, height: 0.11), color: .systemIndigo),
        .init(rect: CGRect(x: 0.60, y: 0.46, width: 0.18, height: 0.11), color: .systemIndigo),
        .init(rect: CGRect(x: 0.30, y: 0.38, width: 0.40, height: 0.12), color: .systemIndigo)
    ], motion: .pull),
    .init(filename: "demo-vertical-pull.gif", title: "Vertical Pull", subtitle: "Pull elbows to the ribs", accent: .systemPurple, bodyHighlights: [
        .init(rect: CGRect(x: 0.24, y: 0.52, width: 0.15, height: 0.10), color: .systemPurple),
        .init(rect: CGRect(x: 0.61, y: 0.52, width: 0.15, height: 0.10), color: .systemPurple),
        .init(rect: CGRect(x: 0.30, y: 0.38, width: 0.36, height: 0.14), color: .systemPurple)
    ], motion: .pull),
    .init(filename: "demo-squat.gif", title: "Squat", subtitle: "Sit between the hips", accent: .systemOrange, bodyHighlights: [
        .init(rect: CGRect(x: 0.32, y: 0.34, width: 0.14, height: 0.16), color: .systemOrange),
        .init(rect: CGRect(x: 0.54, y: 0.34, width: 0.14, height: 0.16), color: .systemOrange),
        .init(rect: CGRect(x: 0.26, y: 0.18, width: 0.46, height: 0.18), color: .systemOrange)
    ], motion: .squat),
    .init(filename: "demo-hinge.gif", title: "Hip Hinge", subtitle: "Load the posterior chain", accent: .systemRed, bodyHighlights: [
        .init(rect: CGRect(x: 0.30, y: 0.22, width: 0.14, height: 0.18), color: .systemRed),
        .init(rect: CGRect(x: 0.56, y: 0.22, width: 0.14, height: 0.18), color: .systemRed),
        .init(rect: CGRect(x: 0.28, y: 0.40, width: 0.44, height: 0.10), color: .systemRed)
    ], motion: .hinge),
    .init(filename: "demo-lunge.gif", title: "Lunge", subtitle: "Train one leg at a time", accent: .systemGreen, bodyHighlights: [
        .init(rect: CGRect(x: 0.32, y: 0.30, width: 0.12, height: 0.18), color: .systemGreen),
        .init(rect: CGRect(x: 0.58, y: 0.20, width: 0.12, height: 0.20), color: .systemGreen),
        .init(rect: CGRect(x: 0.34, y: 0.18, width: 0.32, height: 0.10), color: .systemGreen)
    ], motion: .lunge),
    .init(filename: "demo-curl.gif", title: "Elbow Flexion", subtitle: "Curl through the biceps", accent: .systemBlue, bodyHighlights: [
        .init(rect: CGRect(x: 0.24, y: 0.52, width: 0.15, height: 0.12), color: .systemBlue),
        .init(rect: CGRect(x: 0.61, y: 0.52, width: 0.15, height: 0.12), color: .systemBlue),
        .init(rect: CGRect(x: 0.20, y: 0.42, width: 0.12, height: 0.12), color: .systemBlue)
    ], motion: .curl),
    .init(filename: "demo-extension.gif", title: "Elbow Extension", subtitle: "Finish with the triceps", accent: .systemTeal, bodyHighlights: [
        .init(rect: CGRect(x: 0.24, y: 0.52, width: 0.15, height: 0.12), color: .systemTeal),
        .init(rect: CGRect(x: 0.61, y: 0.52, width: 0.15, height: 0.12), color: .systemTeal),
        .init(rect: CGRect(x: 0.28, y: 0.44, width: 0.12, height: 0.12), color: .systemTeal)
    ], motion: .extensionMove),
    .init(filename: "demo-shoulder.gif", title: "Shoulder Isolation", subtitle: "Lift through the lateral delts", accent: .systemPink, bodyHighlights: [
        .init(rect: CGRect(x: 0.30, y: 0.52, width: 0.10, height: 0.14), color: .systemPink),
        .init(rect: CGRect(x: 0.60, y: 0.52, width: 0.10, height: 0.14), color: .systemPink),
        .init(rect: CGRect(x: 0.22, y: 0.36, width: 0.16, height: 0.10), color: .systemPink)
    ], motion: .shoulder),
    .init(filename: "demo-calf.gif", title: "Calf / Ankle", subtitle: "Push through the toes", accent: .systemYellow, bodyHighlights: [
        .init(rect: CGRect(x: 0.36, y: 0.14, width: 0.10, height: 0.16), color: .systemYellow),
        .init(rect: CGRect(x: 0.54, y: 0.14, width: 0.10, height: 0.16), color: .systemYellow)
    ], motion: .calf),
    .init(filename: "demo-core.gif", title: "Core", subtitle: "Brace and stabilize", accent: .systemMint, bodyHighlights: [
        .init(rect: CGRect(x: 0.34, y: 0.44, width: 0.32, height: 0.12), color: .systemMint),
        .init(rect: CGRect(x: 0.30, y: 0.30, width: 0.40, height: 0.08), color: .systemMint)
    ], motion: .core)
]

let leaderboardClips: [DemoClipSpec] = [
    .init(filename: "demo-leaderboard-squat.gif", title: "Demo Media", subtitle: "Squat evidence preview", accent: .systemBlue, bodyHighlights: [
        .init(rect: CGRect(x: 0.32, y: 0.36, width: 0.14, height: 0.16), color: .systemBlue),
        .init(rect: CGRect(x: 0.54, y: 0.36, width: 0.14, height: 0.16), color: .systemBlue)
    ], motion: .squat),
    .init(filename: "demo-leaderboard-bench.gif", title: "Demo Media", subtitle: "Bench evidence preview", accent: .systemGreen, bodyHighlights: [
        .init(rect: CGRect(x: 0.26, y: 0.56, width: 0.16, height: 0.12), color: .systemGreen),
        .init(rect: CGRect(x: 0.58, y: 0.56, width: 0.16, height: 0.12), color: .systemGreen)
    ], motion: .press),
    .init(filename: "demo-leaderboard-deadlift.gif", title: "Demo Media", subtitle: "Deadlift evidence preview", accent: .systemOrange, bodyHighlights: [
        .init(rect: CGRect(x: 0.31, y: 0.22, width: 0.14, height: 0.18), color: .systemOrange),
        .init(rect: CGRect(x: 0.55, y: 0.22, width: 0.14, height: 0.18), color: .systemOrange)
    ], motion: .hinge)
]

let allClips = exerciseClips + leaderboardClips
for clip in allClips {
    try writeClip(clip, to: outputDirectory.appendingPathComponent(clip.filename))
}

print("Wrote \(allClips.count) clips to \(outputDirectory.path)")

func writeClip(_ spec: DemoClipSpec, to url: URL) throws {
    try? FileManager.default.removeItem(at: url)

    let size = CGSize(width: 240, height: 240)
    let frameCount = 24
    let frameDelay = 1.0 / 12.0

    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.gif.identifier as CFString,
        frameCount,
        nil
    ) else {
        throw NSError(domain: "DemoMedia", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create GIF destination"])
    }

    for frameIndex in 0..<frameCount {
        let progress = Double(frameIndex) / Double(max(1, frameCount - 1))
        guard let image = renderFrame(size: size, progress: progress, spec: spec) else {
            throw NSError(domain: "DemoMedia", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to render frame"])
        }
        let frameProperties: CFDictionary = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: frameDelay
            ]
        ] as CFDictionary
        CGImageDestinationAddImage(destination, image, frameProperties)
    }

    let properties: CFDictionary = [
        kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFLoopCount: 0
        ]
    ] as CFDictionary
    CGImageDestinationSetProperties(destination, properties)

    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "DemoMedia", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to finalize GIF"])
    }
}

func renderFrame(size: CGSize, progress: Double, spec: DemoClipSpec) -> CGImage? {
    let width = Int(size.width)
    let height = Int(size.height)
    let bytesPerRow = width * 4
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    ) else { return nil }

    context.interpolationQuality = .high
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    context.setFillColor(NSColor(red: 0.04, green: 0.05, blue: 0.09, alpha: 1).cgColor)
    context.fill(CGRect(origin: .zero, size: size))

    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [spec.accent.withAlphaComponent(0.18).cgColor, NSColor.clear.cgColor] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        gradient,
        startCenter: CGPoint(x: size.width / 2, y: size.height / 2),
        startRadius: 10,
        endCenter: CGPoint(x: size.width / 2, y: size.height / 2),
        endRadius: 92,
        options: []
    )

    drawStage(in: context, size: size)
    drawFigure(in: context, size: size, highlights: spec.bodyHighlights, accent: spec.accent, motion: spec.motion, progress: progress)
    drawEquipment(in: context, size: size, accent: spec.accent, motion: spec.motion, progress: progress)
    drawText(spec: spec, in: context, size: size)
    drawBadge(in: context, spec: spec)

    return context.makeImage()
}

func drawStage(in context: CGContext, size: CGSize) {
    context.setFillColor(NSColor(white: 1, alpha: 0.04).cgColor)
    context.fill(CGRect(x: 20, y: 28, width: size.width - 40, height: 1.2))
    context.setStrokeColor(NSColor(white: 1, alpha: 0.08).cgColor)
    context.setLineWidth(1.0)
    context.strokeEllipse(in: CGRect(x: 24, y: 24, width: size.width - 48, height: size.height - 48))
}

func drawFigure(in context: CGContext, size: CGSize, highlights: [BodyHighlight], accent: NSColor, motion: MotionStyle, progress: Double) {
    let t = CGFloat(progress)
    let centerX = size.width / 2
    let bob = sin(progress * .pi * 2) * 4
    let torso = CGRect(x: centerX - 17, y: 79 + bob, width: 34, height: 56)
    let head = CGRect(x: centerX - 12, y: 142 + bob, width: 24, height: 24)
    let legLeft = CGRect(x: centerX - 16, y: 36 + bob, width: 11, height: 46)
    let legRight = CGRect(x: centerX + 5, y: 36 + bob, width: 11, height: 46)
    let armLeft = CGRect(x: centerX - 36, y: 91 + bob, width: 14, height: 44)
    let armRight = CGRect(x: centerX + 22, y: 91 + bob, width: 14, height: 44)
    let shoulder = CGRect(x: centerX - 25, y: 123 + bob, width: 50, height: 9)

    roundedRect(head, radius: 12, in: context, fill: NSColor(white: 0.65, alpha: 0.28))
    roundedRect(torso, radius: 10, in: context, fill: NSColor(white: 0.68, alpha: 0.22))
    roundedRect(legLeft, radius: 6, in: context, fill: NSColor(white: 0.68, alpha: 0.22))
    roundedRect(legRight, radius: 6, in: context, fill: NSColor(white: 0.68, alpha: 0.22))
    roundedRect(armLeft, radius: 6, in: context, fill: NSColor(white: 0.68, alpha: 0.22))
    roundedRect(armRight, radius: 6, in: context, fill: NSColor(white: 0.68, alpha: 0.22))
    roundedRect(shoulder, radius: 4, in: context, fill: NSColor(white: 0.68, alpha: 0.16))

    for highlight in highlights {
        let rect = CGRect(
            x: centerX - 48 + highlight.rect.minX * 96,
            y: 43 + highlight.rect.minY * 110,
            width: highlight.rect.width * 96,
            height: highlight.rect.height * 110
        )
        roundedRect(rect.offsetBy(dx: 0, dy: bob / 2), radius: 5, in: context, fill: highlight.color.withAlphaComponent(0.95))
    }

    if motion == .carry {
        context.setFillColor(accent.withAlphaComponent(0.92).cgColor)
        context.fillEllipse(in: CGRect(x: centerX - 65 + t * 18, y: 79, width: 11, height: 11))
        context.fillEllipse(in: CGRect(x: centerX + 54 - t * 18, y: 79, width: 11, height: 11))
    }
}

func drawEquipment(in context: CGContext, size: CGSize, accent: NSColor, motion: MotionStyle, progress: Double) {
    let phase = CGFloat(progress)
    context.setStrokeColor(NSColor(white: 1, alpha: 0.16).cgColor)
    context.setLineWidth(4)
    context.setLineCap(.round)
    switch motion {
    case .press:
        context.move(to: CGPoint(x: 46, y: 100))
        context.addLine(to: CGPoint(x: 194, y: 100))
        context.strokePath()
        context.setFillColor(accent.cgColor)
        context.fillEllipse(in: CGRect(x: 46 + phase * 9, y: 95, width: 9, height: 9))
        context.fillEllipse(in: CGRect(x: 185 - phase * 9, y: 95, width: 9, height: 9))
    case .pull:
        context.move(to: CGPoint(x: 59, y: 118))
        context.addLine(to: CGPoint(x: 181, y: 118))
        context.strokePath()
        context.setFillColor(accent.cgColor)
        context.fillEllipse(in: CGRect(x: 110 + sin(Double(phase) * .pi * 2) * 8, y: 113, width: 10, height: 10))
    case .squat, .hinge, .lunge:
        context.move(to: CGPoint(x: 52, y: 53))
        context.addLine(to: CGPoint(x: 188, y: 53))
        context.strokePath()
        context.setFillColor(accent.cgColor)
        context.fillEllipse(in: CGRect(x: 51 + phase * 9, y: 48, width: 9, height: 9))
    case .curl, .extensionMove, .shoulder, .calf, .core, .carry, .generic:
        context.move(to: CGPoint(x: 60, y: 66))
        context.addLine(to: CGPoint(x: 180, y: 66))
        context.strokePath()
        context.setFillColor(accent.cgColor)
        context.fillEllipse(in: CGRect(x: 65 + phase * 100, y: 61, width: 7, height: 7))
    }
}

func drawText(spec: DemoClipSpec, in context: CGContext, size: CGSize) {
    let title = NSAttributedString(string: spec.title, attributes: [
        .font: NSFont.systemFont(ofSize: 18, weight: .bold),
        .foregroundColor: NSColor.white
    ])
    let subtitle = NSAttributedString(string: spec.subtitle, attributes: [
        .font: NSFont.systemFont(ofSize: 10, weight: .medium),
        .foregroundColor: NSColor(white: 1.0, alpha: 0.82)
    ])
    let badge = NSAttributedString(string: "LIFTRANK DEMO MEDIA", attributes: [
        .font: NSFont.systemFont(ofSize: 8, weight: .bold),
        .foregroundColor: NSColor.white.withAlphaComponent(0.82),
        .kern: 1.0
    ])

    let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsContext
    title.draw(in: CGRect(x: 12, y: 10, width: size.width - 24, height: 22))
    subtitle.draw(in: CGRect(x: 12, y: size.height - 24, width: size.width - 24, height: 14))
    badge.draw(in: CGRect(x: 12, y: 2, width: size.width - 24, height: 10))
    NSGraphicsContext.restoreGraphicsState()
}

func drawBadge(in context: CGContext, spec: DemoClipSpec) {
    let rect = CGRect(x: 148, y: 188, width: 84, height: 20)
    let path = CGPath(roundedRect: rect, cornerWidth: 10, cornerHeight: 10, transform: nil)
    context.addPath(path)
    context.setFillColor(spec.accent.withAlphaComponent(0.2).cgColor)
    context.fillPath()
    context.addPath(path)
    context.setStrokeColor(spec.accent.withAlphaComponent(0.55).cgColor)
    context.setLineWidth(1.0)
    context.strokePath()
}

func roundedRect(_ rect: CGRect, radius: CGFloat, in context: CGContext, fill: NSColor) {
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.addPath(path)
    context.setFillColor(fill.cgColor)
    context.fillPath()
}
