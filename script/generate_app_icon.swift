import AppKit
import Darwin
import Foundation

enum IconGenerationError: LocalizedError {
    case bitmapCreationFailed(Int)
    case pngEncodingFailed(Int)
    case iconutilFailed(String)

    var errorDescription: String? {
        switch self {
        case .bitmapCreationFailed(let size):
            return "Unable to create a \(size)x\(size) bitmap."
        case .pngEncodingFailed(let size):
            return "Unable to encode the \(size)x\(size) icon as PNG."
        case .iconutilFailed(let message):
            return "iconutil failed: \(message)"
        }
    }
}

private let fileManager = FileManager.default
private let scriptURL = URL(fileURLWithPath: #filePath)
private let projectRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
private let resourcesDirectory = projectRoot
    .appendingPathComponent("Sources/CodexUsageBar/Resources", isDirectory: true)
private let masterIconURL = resourcesDirectory.appendingPathComponent("AppIcon.png")
private let finalIconURL = resourcesDirectory.appendingPathComponent("AppIcon.icns")

private func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

private func roundedPath(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

private func fillRoundedRect(_ rect: NSRect, radius: CGFloat, fill: NSColor) {
    fill.setFill()
    roundedPath(rect, radius: radius).fill()
}

private func drawIcon(size: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw IconGenerationError.bitmapCreationFailed(size)
    }

    bitmap.size = NSSize(width: size, height: size)
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw IconGenerationError.bitmapCreationFailed(size)
    }

    let scale = CGFloat(size)
    let canvas = NSRect(x: 0, y: 0, width: scale, height: scale)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.shouldAntialias = true

    color(0x000000, alpha: 0).setFill()
    NSBezierPath(rect: canvas).fill()

    let plateRect = canvas.insetBy(dx: scale * 0.075, dy: scale * 0.075)
    let plateRadius = scale * 0.21

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x1F242B, alpha: 0.18)
    shadow.shadowBlurRadius = max(1, scale * 0.035)
    shadow.shadowOffset = NSSize(width: 0, height: -scale * 0.018)
    shadow.set()
    fillRoundedRect(plateRect, radius: plateRadius, fill: color(0xFBFBFC))
    NSGraphicsContext.restoreGraphicsState()

    let plateBorder = roundedPath(plateRect, radius: plateRadius)
    plateBorder.lineWidth = max(0.75, scale * 0.006)
    color(0xD5D8DD).setStroke()
    plateBorder.stroke()

    let innerPlateRect = plateRect.insetBy(dx: scale * 0.024, dy: scale * 0.024)
    let innerPlate = roundedPath(innerPlateRect, radius: plateRadius * 0.82)
    innerPlate.lineWidth = max(0.5, scale * 0.0025)
    color(0xECEEF1).setStroke()
    innerPlate.stroke()

    let windowRect = NSRect(
        x: scale * 0.245,
        y: scale * 0.285,
        width: scale * 0.51,
        height: scale * 0.43
    )
    let outline = roundedPath(windowRect, radius: scale * 0.075)
    outline.lineWidth = max(1.25, scale * 0.036)
    color(0x30343A).setStroke()
    outline.stroke()

    let controlSize = max(1.25, scale * 0.018)
    fillRoundedRect(
        NSRect(x: scale * 0.315, y: scale * 0.625, width: controlSize, height: controlSize),
        radius: controlSize / 2,
        fill: color(0x30343A)
    )
    fillRoundedRect(
        NSRect(x: scale * 0.355, y: scale * 0.625, width: controlSize, height: controlSize),
        radius: controlSize / 2,
        fill: color(0x777D85)
    )

    let barHeight = max(1.5, scale * 0.055)
    fillRoundedRect(
        NSRect(x: scale * 0.315, y: scale * 0.49, width: scale * 0.37, height: barHeight),
        radius: barHeight / 2,
        fill: color(0x2F7EE6)
    )
    fillRoundedRect(
        NSRect(x: scale * 0.315, y: scale * 0.385, width: scale * 0.255, height: barHeight),
        radius: barHeight / 2,
        fill: color(0xB0B5BC)
    )

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw IconGenerationError.pngEncodingFailed(size)
    }
    return png
}

private func writePNG(size: Int, to url: URL) throws {
    try drawIcon(size: size).write(to: url, options: .atomic)
}

private func generate() throws {
    try fileManager.createDirectory(
        at: resourcesDirectory,
        withIntermediateDirectories: true
    )

    let temporaryRoot = fileManager.temporaryDirectory
        .appendingPathComponent("CodexUsageBar-\(UUID().uuidString)", isDirectory: true)
    let iconsetURL = temporaryRoot.appendingPathComponent("AppIcon.iconset", isDirectory: true)
    try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: temporaryRoot) }

    let iconFiles: [(name: String, size: Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024)
    ]

    for iconFile in iconFiles {
        try writePNG(
            size: iconFile.size,
            to: iconsetURL.appendingPathComponent(iconFile.name)
        )
    }
    try writePNG(size: 1024, to: masterIconURL)

    try? fileManager.removeItem(at: finalIconURL)
    let process = Process()
    let errorPipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = [
        "-c", "icns",
        "-o", finalIconURL.path,
        iconsetURL.path
    ]
    process.standardError = errorPipe
    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let message = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw IconGenerationError.iconutilFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    print("Generated \(masterIconURL.path)")
    print("Generated \(finalIconURL.path)")
}

do {
    try generate()
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
