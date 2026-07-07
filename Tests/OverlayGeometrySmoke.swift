import CoreGraphics
import Foundation

@main
struct OverlayGeometrySmoke {
    static func main() throws {
        try assertTinySelectionGetsReadableResultSize()

        print("Overlay geometry smoke test passed.")
    }

    private static func assertTinySelectionGetsReadableResultSize() throws {
        let screenshotSize = CGSize(width: 34, height: 16)
        let result = OverlayGeometry.resultFrame(
            screenshotPixelSize: screenshotSize,
            screenPosition: CGPoint(x: 100, y: 100),
            displayScale: 1
        )

        guard result.width >= 120, result.height >= 44 else {
            throw TestFailure("Expected tiny selections to expand to a readable overlay size, got \(result.size)")
        }
        guard result.origin == CGPoint(x: 100, y: 100) else {
            throw TestFailure("Expected expanded overlay to keep the selected top-left anchor, got \(result.origin)")
        }
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
