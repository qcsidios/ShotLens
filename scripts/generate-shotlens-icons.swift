#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation
import ImageIO

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("ShotLens/Resources")
let iconset = resources.appendingPathComponent("ShotLensIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let iconSpecs: [(String, Int)] = [
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

for (name, size) in iconSpecs {
    let image = drawAppIcon(size: size)
    try writePNG(image, to: iconset.appendingPathComponent(name))
}

let menuBarImage = drawMenuBarTemplateIcon(size: 64)
try writePNG(menuBarImage, to: resources.appendingPathComponent("ShotLensMenuBarTemplate.png"))

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = [
    "-c", "icns",
    iconset.path,
    "-o", resources.appendingPathComponent("ShotLens.icns").path
]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else {
    throw NSError(domain: "ShotLensIconGenerator", code: Int(process.terminationStatus))
}

try FileManager.default.copyItem(
    at: resources.appendingPathComponent("ShotLens.icns"),
    to: replacing(resources.appendingPathComponent("ShotLensIcon.icns"))
)

func replacing(_ url: URL) -> URL {
    if FileManager.default.fileExists(atPath: url.path) {
        try? FileManager.default.removeItem(at: url)
    }
    return url
}

func drawAppIcon(size: Int) -> CGImage {
    let dimension = CGFloat(size)
    let image = NSImage(size: NSSize(width: dimension, height: dimension))
    image.lockFocus()
    drawSimpleLogo(size: dimension, includeBackground: true, glyphColor: .white)
    image.unlockFocus()

    var rect = NSRect(x: 0, y: 0, width: dimension, height: dimension)
    return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
}

func drawMenuBarTemplateIcon(size: Int) -> CGImage {
    let dimension = CGFloat(size)
    let image = NSImage(size: NSSize(width: dimension, height: dimension))
    image.lockFocus()
    drawSimpleLogo(size: dimension, includeBackground: false, glyphColor: .black)
    image.unlockFocus()

    var rect = NSRect(x: 0, y: 0, width: dimension, height: dimension)
    return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
}

func drawSimpleLogo(size: CGFloat, includeBackground: Bool, glyphColor: NSColor) {
    if includeBackground {
        NSColor(calibratedRed: 0.035, green: 0.039, blue: 0.044, alpha: 1).setFill()
        NSBezierPath(
            roundedRect: NSRect(x: size * 0.065, y: size * 0.065, width: size * 0.87, height: size * 0.87),
            xRadius: size * 0.235,
            yRadius: size * 0.235
        ).fill()
    }

    let text = "译" as NSString
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * (includeBackground ? 0.48 : 0.72), weight: .black),
        .foregroundColor: glyphColor
    ]
    let textSize = text.size(withAttributes: attributes)
    text.draw(
        in: NSRect(
            x: (size - textSize.width) / 2,
            y: (size - textSize.height) / 2 + size * 0.02,
            width: textSize.width,
            height: textSize.height
        ),
        withAttributes: attributes
    )
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        throw NSError(domain: "ShotLensIconGenerator", code: 1)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "ShotLensIconGenerator", code: 2)
    }
}
