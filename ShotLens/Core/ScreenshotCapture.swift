import AppKit
import CoreGraphics
import CoreVideo
import ImageIO
import ScreenCaptureKit

struct CapturedScreenshot {
    let image: CGImage
    let fileURL: URL
}

struct FrozenScreenshot {
    let image: CGImage
    let fileURL: URL
    let screenRect: CGRect
}

/// 截图工具。ShotLens 负责全屏蒙版和选区交互；这里在进程内捕获当前屏幕。
struct ScreenshotCapture {
    func hasScreenCaptureAccess() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    func displayFrames() -> [CGRect] {
        NSScreen.screens.map { $0.frame }
    }

    func scale(for selectionRect: CGRect) -> CGFloat {
        screen(containing: selectionRect)?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 1.0
    }

    func capture(selection rect: CGRect) async throws -> CapturedScreenshot? {
        guard let frozenSnapshot = try await captureFrozenDisplay() else {
            return nil
        }
        return try crop(frozenSnapshot: frozenSnapshot, selection: rect)
    }

    func captureFrozenDisplay() async throws -> FrozenScreenshot? {
        guard let screenRect = displayFrames().unionRect() else {
            return nil
        }
        let image = try await captureVisibleDisplayImage(screenRect: screenRect)
        let outputURL = temporaryPNGURL()
        try writePNG(image, to: outputURL)
        ShotLensLogger.log("冻结屏幕：ScreenCaptureKit 进程内截图，输出 \(outputURL.path)")

        return FrozenScreenshot(
            image: image,
            fileURL: outputURL,
            screenRect: screenRect
        )
    }

    func crop(frozenSnapshot: FrozenScreenshot, selection rect: CGRect) throws -> CapturedScreenshot? {
        let scaleX = CGFloat(frozenSnapshot.image.width) / max(frozenSnapshot.screenRect.width, 1)
        let scaleY = CGFloat(frozenSnapshot.image.height) / max(frozenSnapshot.screenRect.height, 1)
        let minX = max(0, floor((rect.minX - frozenSnapshot.screenRect.minX) * scaleX))
        let maxX = min(
            CGFloat(frozenSnapshot.image.width),
            ceil((rect.maxX - frozenSnapshot.screenRect.minX) * scaleX)
        )
        let minY = max(0, floor((frozenSnapshot.screenRect.maxY - rect.maxY) * scaleY))
        let maxY = min(
            CGFloat(frozenSnapshot.image.height),
            ceil((frozenSnapshot.screenRect.maxY - rect.minY) * scaleY)
        )

        guard maxX > minX, maxY > minY else {
            return nil
        }

        let cropRect = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
        guard let croppedImage = frozenSnapshot.image.cropping(to: cropRect) else {
            throw ScreenshotCaptureError.emptyImage
        }

        let normalizedImage = normalizedCopy(of: croppedImage) ?? croppedImage
        let outputURL = temporaryPNGURL()
        try writePNG(normalizedImage, to: outputURL)
        return CapturedScreenshot(image: normalizedImage, fileURL: outputURL)
    }

    private func temporaryPNGURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ShotLens-\(UUID().uuidString)")
            .appendingPathExtension("png")
    }

    private func captureVisibleDisplayImage(screenRect: CGRect) async throws -> CGImage {
        if #available(macOS 15.2, *) {
            return try await captureScreenRectImage(screenRect)
        }

        return try await captureDisplayComposite(screenRect: screenRect)
    }

    @available(macOS 15.2, *)
    private func captureScreenRectImage(_ screenRect: CGRect) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(in: screenRect) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let image else {
                    continuation.resume(throwing: ScreenshotCaptureError.emptyImage)
                    return
                }

                continuation.resume(returning: normalizedCopy(of: image) ?? image)
            }
        }
    }

    private func captureDisplayComposite(screenRect: CGRect) async throws -> CGImage {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            throw ScreenshotCaptureError.emptyImage
        }
        let content = try await SCShareableContent.current
        let screensByDisplayID = Dictionary(
            uniqueKeysWithValues: screens.compactMap { screen -> (CGDirectDisplayID, NSScreen)? in
                guard let displayID = displayID(for: screen) else { return nil }
                return (displayID, screen)
            }
        )

        let scale = max(screens.map(\.backingScaleFactor).max() ?? 1.0, 1.0)
        let width = max(1, Int(ceil(screenRect.width * scale)))
        let height = max(1, Int(ceil(screenRect.height * scale)))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw ScreenshotCaptureError.emptyImage
        }

        context.interpolationQuality = .none
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: scale, y: -scale)

        for display in content.displays {
            guard let screen = screensByDisplayID[display.displayID] else {
                continue
            }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            if #available(macOS 14.2, *) {
                filter.includeMenuBar = true
            }

            let displayScale = max(CGFloat(filter.pointPixelScale), screen.backingScaleFactor, 1.0)
            let configuration = SCStreamConfiguration()
            configuration.width = max(1, Int(ceil(CGFloat(display.width) * displayScale)))
            configuration.height = max(1, Int(ceil(CGFloat(display.height) * displayScale)))
            configuration.pixelFormat = kCVPixelFormatType_32BGRA
            configuration.showsCursor = false
            configuration.capturesAudio = false
            configuration.queueDepth = 1
            configuration.captureResolution = .best

            let image = try await captureImage(contentFilter: filter, configuration: configuration)

            let destination = CGRect(
                x: screen.frame.minX - screenRect.minX,
                y: screenRect.maxY - screen.frame.maxY,
                width: screen.frame.width,
                height: screen.frame.height
            )
            context.draw(image, in: destination)
        }

        guard let image = context.makeImage() else {
            throw ScreenshotCaptureError.emptyImage
        }
        return image
    }

    private func captureImage(
        contentFilter: SCContentFilter,
        configuration: SCStreamConfiguration
    ) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(
                contentFilter: contentFilter,
                configuration: configuration
            ) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let image else {
                    continuation.resume(throwing: ScreenshotCaptureError.emptyImage)
                    return
                }

                continuation.resume(returning: image)
            }
        }
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
    }

    private func screen(containing rect: CGRect) -> NSScreen? {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
    }

    private func normalizedCopy(of image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            "public.png" as CFString,
            1,
            nil
        ) else {
            throw ScreenshotCaptureError.missingOutput(path: url.path, stderr: "无法创建 PNG 写入目标")
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ScreenshotCaptureError.missingOutput(path: url.path, stderr: "PNG 写入失败")
        }
    }
}

private enum ScreenshotCaptureError: LocalizedError {
    case emptyImage
    case missingOutput(path: String, stderr: String)

    var errorDescription: String? {
        switch self {
        case .emptyImage:
            return "截图文件无法读取或内容为空"
        case .missingOutput(let path, let stderr):
            return stderr.isEmpty
                ? "截图成功但未生成输出文件：\(path)"
                : "截图成功但未生成输出文件：\(path)，stderr：\(stderr)"
        }
    }
}

extension [CGRect] {
    /// 计算多个矩形的最小包围矩形
    func unionRect() -> CGRect? {
        guard let first = self.first else { return nil }
        return self.dropFirst().reduce(first) { $0.union($1) }
    }
}
