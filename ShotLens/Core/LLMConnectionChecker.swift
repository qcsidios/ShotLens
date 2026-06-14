import Foundation

enum ConnectionCheckResult: Equatable {
    case available
    case unavailable
    case transientFailure
}

struct LLMConnectionChecker {
    let settings: TranslationSettings

    func isAvailable() async -> Bool {
        await checkAvailability() == .available
    }

    func checkAvailability() async -> ConnectionCheckResult {
        guard settings.isLLMConfigured else {
            return .unavailable
        }

        do {
            try await LLMTranslator(settings: settings)
                .validateConnectivity(from: "en", to: "zh-Hans")
            return .available
        } catch {
            ShotLensLogger.log("API 测试失败", error: error)
            return classify(error)
        }
    }

    private func classify(_ error: Error) -> ConnectionCheckResult {
        if let translationError = error as? TranslationError {
            switch translationError {
            case .llmHTTPError(let statusCode, _):
                if statusCode == 401 || statusCode == 403 || statusCode == 404 {
                    return .unavailable
                }
                if statusCode == 408 || statusCode == 409 || statusCode == 425 || statusCode == 429 || statusCode >= 500 {
                    return .transientFailure
                }
                return .unavailable
            case .invalidLLMEndpoint, .llmNotConfigured:
                return .unavailable
            case .invalidLLMResponse, .missingSourceLanguage, .llmResponseCountMismatch:
                return .unavailable
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return .transientFailure
        }
        return .unavailable
    }
}
