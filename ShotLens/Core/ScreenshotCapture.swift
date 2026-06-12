import AppKit
import CoreGraphics
import ImageIO

struct CapturedScreenshot {
    let image: CGImage
    let fileURL: URL
}

struct FrozenScreenshot {
    let image: CGImage
    let fileURL: URL
    let screenRect: CGRect
}

/// 截图工具。ShotLens 负责全屏蒙版和选区交互；这里仅按选区调用系统截图。
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
        try await capture(rect: rect, purpose: "选区截图")
    }

    func captureFrozenDisplay() async throws -> FrozenScreenshot? {
        guard let screenRect = displayFrames().unionRect() else {
            return nil
        }
        guard let captured = try await capture(rect: screenRect, purpose: "冻结全屏") else {
            return nil
        }
        return FrozenScreenshot(
            image: captured.image,
            fileURL: captured.fileURL,
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

    private func capture(rect: CGRect, purpose: String) async throws -> CapturedScreenshot? {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShotLens-\(UUID().uuidString)")
            .appendingPathExtension("png")
        let captureRect = screencaptureRect(for: rect)
        let rectArgument = "\(captureRect.x),\(captureRect.y),\(captureRect.width),\(captureRect.height)"
        ShotLensLogger.log("\(purpose)：调用系统截图 -R \(rectArgument)，输出 \(outputURL.path)")

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = [
                "-x",
                "-R",
                rectArgument,
                outputURL.path
            ]
            let stderr = Pipe()
            process.standardError = stderr
            let resumeState = ScreenshotProcessResumeState(continuation: continuation)
            let timeout = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                }
            }

            process.terminationHandler = { process in
                timeout.cancel()
                let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
                let errorText = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                guard process.terminationStatus == 0 else {
                    resumeState.resume(.failure(ScreenshotCaptureError.commandFailed(
                        status: process.terminationStatus,
                        stderr: errorText
                    )))
                    return
                }

                guard FileManager.default.fileExists(atPath: outputURL.path) else {
                    resumeState.resume(.failure(ScreenshotCaptureError.missingOutput(
                        path: outputURL.path,
                        stderr: errorText
                    )))
                    return
                }

                guard let image = loadImage(from: outputURL) else {
                    resumeState.resume(.failure(ScreenshotCaptureError.emptyImage))
                    return
                }

                resumeState.resume(.success(CapturedScreenshot(image: image, fileURL: outputURL)))
            }

            do {
                try process.run()
                DispatchQueue.global().asyncAfter(deadline: .now() + 15, execute: timeout)
            } catch {
                timeout.cancel()
                resumeState.resume(.failure(error))
            }
        }
    }

    private func temporaryPNGURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ShotLens-\(UUID().uuidString)")
            .appendingPathExtension("png")
    }

    private func screencaptureRect(for selectionRect: CGRect) -> (x: Int, y: Int, width: Int, height: Int) {
        let displayUnion = displayFrames().unionRect() ?? selectionRect
        let x = selectionRect.minX - displayUnion.minX
        let y = displayUnion.maxY - selectionRect.maxY

        return (
            x: max(0, Int(x.rounded(.down))),
            y: max(0, Int(y.rounded(.down))),
            width: max(1, Int(selectionRect.width.rounded(.up))),
            height: max(1, Int(selectionRect.height.rounded(.up)))
        )
    }

    private func screen(containing rect: CGRect) -> NSScreen? {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
    }

    private func loadImage(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return normalizedCopy(of: image) ?? image
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

private final class ScreenshotProcessResumeState: @unchecked Sendable {
    private let lock = NSLock()
    private var hasResumed = false
    private let continuation: CheckedContinuation<CapturedScreenshot?, Error>

    init(continuation: CheckedContinuation<CapturedScreenshot?, Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Result<CapturedScreenshot?, Error>) {
        lock.lock()
        defer { lock.unlock() }
        guard !hasResumed else { return }
        hasResumed = true

        switch result {
        case .success(let screenshot):
            continuation.resume(returning: screenshot)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

private enum ScreenshotCaptureError: LocalizedError {
    case emptyImage
    case commandFailed(status: Int32, stderr: String)
    case missingOutput(path: String, stderr: String)

    var errorDescription: String? {
        switch self {
        case .emptyImage:
            return "截图文件无法读取或内容为空"
        case .commandFailed(let status, let stderr):
            return stderr.isEmpty
                ? "系统截图命令失败，退出码 \(status)"
                : "系统截图命令失败，退出码 \(status)：\(stderr)"
        case .missingOutput(let path, let stderr):
            return stderr.isEmpty
                ? "系统截图命令成功但未生成输出文件：\(path)"
                : "系统截图命令成功但未生成输出文件：\(path)，stderr：\(stderr)"
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
