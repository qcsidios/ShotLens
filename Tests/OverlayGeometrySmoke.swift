import CoreGraphics
import Foundation

@main
struct OverlayGeometrySmoke {
    static func main() throws {
        try assertTinySelectionKeepsCapturedAspectRatio()

        print("Overlay geometry smoke test passed.")
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
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
