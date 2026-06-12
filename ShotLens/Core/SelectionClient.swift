import Foundation
import CoreGraphics

struct SelectionClient {
    func select(frozenScreenshot: FrozenScreenshot? = nil) async throws -> CGRect? {
        let helperURL = try locateHelper()
        return try await runHelper(helperURL: helperURL, frozenScreenshot: frozenScreenshot)
    }

    private func locateHelper() throws -> URL {
        guard let executableURL = Bundle.main.executableURL else {
            throw SelectionClientError.helperMissing
        }

        let helperURL = executableURL
            .deletingLastPathComponent()
            .appendingPathComponent("ShotLensSelect")

        guard FileManager.default.isExecutableFile(atPath: helperURL.path) else {
            throw SelectionClientError.helperMissing
        }

        return helperURL
    }

    private func runHelper(helperURL: URL, frozenScreenshot: FrozenScreenshot?) async throws -> CGRect? {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = helperURL
            process.arguments = helperArguments(for: frozenScreenshot)

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr
            let resumeState = SelectionProcessResumeState(continuation: continuation)
            let timeout = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                }
            }

            process.terminationHandler = { finishedProcess in
                timeout.cancel()
                let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
                let errorText = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                guard finishedProcess.terminationStatus == 0 else {
                    resumeState.resume(.failure(SelectionClientError.helperFailed(errorText)))
                    return
                }

                do {
                    let response = try JSONDecoder().decode(SelectionResponse.self, from: outputData)
                    resumeState.resume(.success(response.rect))
                } catch {
                    resumeState.resume(.failure(SelectionClientError.invalidHelperOutput(error.localizedDescription)))
                }
            }

            do {
                try process.run()
                DispatchQueue.global().asyncAfter(deadline: .now() + 120, execute: timeout)
            } catch {
                timeout.cancel()
                resumeState.resume(.failure(error))
            }
        }
    }

    private func helperArguments(for frozenScreenshot: FrozenScreenshot?) -> [String] {
        guard let frozenScreenshot else { return [] }
        return [
            "--frozen-image", frozenScreenshot.fileURL.path,
            "--screen-x", "\(frozenScreenshot.screenRect.minX)",
            "--screen-y", "\(frozenScreenshot.screenRect.minY)",
            "--screen-width", "\(frozenScreenshot.screenRect.width)",
            "--screen-height", "\(frozenScreenshot.screenRect.height)"
        ]
    }
}

private final class SelectionProcessResumeState: @unchecked Sendable {
    private let lock = NSLock()
    private var hasResumed = false
    private let continuation: CheckedContinuation<CGRect?, Error>

    init(continuation: CheckedContinuation<CGRect?, Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Result<CGRect?, Error>) {
        lock.lock()
        defer { lock.unlock() }
        guard !hasResumed else { return }
        hasResumed = true

        switch result {
        case .success(let rect):
            continuation.resume(returning: rect)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

private struct SelectionResponse: Decodable {
    let cancelled: Bool
    let x: CGFloat?
    let y: CGFloat?
    let width: CGFloat?
    let height: CGFloat?

    var rect: CGRect? {
        guard !cancelled,
              let x,
              let y,
              let width,
              let height else {
            return nil
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

private enum SelectionClientError: LocalizedError {
    case helperMissing
    case helperFailed(String)
    case invalidHelperOutput(String)

    var errorDescription: String? {
        switch self {
        case .helperMissing:
            return "截图选择 helper 不存在或不可执行"
        case .helperFailed(let message):
            return message.isEmpty ? "截图选择 helper 执行失败" : message
        case .invalidHelperOutput(let message):
            return "截图选择 helper 输出无效：\(message)"
        }
    }
}
