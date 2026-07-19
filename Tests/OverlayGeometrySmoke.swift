import CoreGraphics
import Foundation

@main
struct OverlayGeometrySmoke {
    static func main() throws {
        try assertTinySelectionKeepsCapturedAspectRatio()
        try assertPixelRectKeepsExactTopLeftAnchor()
        try assertTextRemovalPreservesBackgroundVariation()

        print("Overlay geometry smoke test passed.")
    }

    private static func assertPixelRectKeepsExactTopLeftAnchor() throws {
        let result = OverlayGeometry.displayRect(
            forPixelRect: CGRect(x: 100.1, y: 50.1, width: 300.3, height: 100.2),
            screenshotPixelSize: CGSize(width: 1_001, height: 501),
            displayBounds: CGRect(x: 0, y: 0, width: 500, height: 250)
        )
        let expected = CGRect(
            x: 100.1 / 1_001 * 500,
            y: 50.1 / 501 * 250,
            width: 300.3 / 1_001 * 500,
            height: 100.2 / 501 * 250
        )
        guard result.approximatelyEquals(expected, tolerance: 0.001) else {
            throw TestFailure("Pixel mapping moved the OCR anchor: expected \(expected), got \(result)")
        }
    }

    private static func assertTextRemovalPreservesBackgroundVariation() throws {
        let image = try makeGradientImageWithDarkText()
        let sourceRect = CGRect(x: 20, y: 10, width: 40, height: 20)
        let style = TextBlockVisualStyle(
            confidence: 1,
            estimatedFontSize: 12,
            foregroundRed: 0,
            foregroundGreen: 0,
            foregroundBlue: 0,
            foregroundLuminance: 0,
            strokeDensity: 0.2
        )
        guard let patch = OverlayTextBackgroundRestorer.restoredPatch(
            from: image,
            pixelRect: sourceRect,
            sourceStyle: style
        ) else {
            throw TestFailure("Expected a reconstructed background patch")
        }
        let pixels = try rgbaPixels(from: patch)
        var hasDarkPixel = false
        var redValues = Set<UInt8>()
        for index in stride(from: 0, to: pixels.count, by: 4) {
            hasDarkPixel = hasDarkPixel
                || (pixels[index] < 18 && pixels[index + 1] < 18 && pixels[index + 2] < 18)
            redValues.insert(pixels[index])
        }
        guard !hasDarkPixel else {
            throw TestFailure("Original glyph pixels were not removed")
        }
        guard redValues.count >= 12 else {
            throw TestFailure("Background reconstruction collapsed into a flat color block")
        }
    }

    private static func assertTinySelectionKeepsCapturedAspectRatio() throws {
        let screenshotSize = CGSize(width: 34, height: 16)
        let result = OverlayGeometry.resultFrame(
            screenshotPixelSize: screenshotSize,
            screenPosition: CGPoint(x: 100, y: 100),
            displayScale: 1
        )

        guard result.size == screenshotSize else {
            throw TestFailure("Expected tiny selections to preserve the selected screenshot size, got \(result.size)")
        }
        guard result.origin == CGPoint(x: 100, y: 100) else {
            throw TestFailure("Expected overlay to keep the selected top-left anchor, got \(result.origin)")
        }
    }

    private static func makeGradientImageWithDarkText() throws -> CGImage {
        let width = 80
        let height = 40
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                pixels[index] = UInt8(60 + x * 2)
                pixels[index + 1] = UInt8(110 + y)
                pixels[index + 2] = 160
                pixels[index + 3] = 255
                if (18...21).contains(y), (25...54).contains(x) {
                    pixels[index] = 0
                    pixels[index + 1] = 0
                    pixels[index + 2] = 0
                }
            }
        }
        return try makeImage(width: width, height: height, pixels: &pixels)
    }

    private static func rgbaPixels(from image: CGImage) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &pixels,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw TestFailure("Unable to read reconstructed pixels")
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return pixels
    }

    private static func makeImage(width: Int, height: Int, pixels: inout [UInt8]) throws -> CGImage {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let image = context.makeImage() else {
            throw TestFailure("Unable to create gradient test image")
        }
        return image
    }
}

private extension CGRect {
    func approximatelyEquals(_ other: CGRect, tolerance: CGFloat) -> Bool {
        abs(minX - other.minX) <= tolerance
            && abs(minY - other.minY) <= tolerance
            && abs(width - other.width) <= tolerance
            && abs(height - other.height) <= tolerance
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
