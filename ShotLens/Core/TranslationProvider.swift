import Foundation

/// 翻译引擎协议。ShotLens 只保留 OpenAI-compatible API 翻译。
protocol TranslationProvider {
    /// 引擎名称，用于调试和未来 UI 展示
    var name: String { get }

    /// 批量翻译文本
    /// - Parameters:
    ///   - texts: 待翻译的原文数组
    ///   - sourceLanguage: 源语言 BCP-47 代码，如 "en"、"zh-Hans"
    ///   - targetLanguage: 目标语言 BCP-47 代码
    /// - Returns: 译文数组，与 texts 一一对应
    func translate(_ texts: [String], from sourceLanguage: String, to targetLanguage: String) async throws -> [String]
}

/// 翻译引擎工厂
struct TranslationProviderFactory {
    /// 创建 API 翻译引擎实例
    static func create() -> TranslationProvider {
        let settings = TranslationSettings.load()
        if settings.isLLMConfigured {
            return LLMTranslator(settings: settings)
        }
        return UnavailableTranslator()
    }
}

private struct UnavailableTranslator: TranslationProvider {
    let name = "未配置翻译"

    func translate(_ texts: [String], from sourceLanguage: String, to targetLanguage: String) async throws -> [String] {
        throw TranslationError.llmNotConfigured
    }
}

enum TranslationError: LocalizedError {
    case missingSourceLanguage
    case llmNotConfigured
    case invalidLLMEndpoint
    case invalidLLMResponse
    case llmHTTPError(statusCode: Int, body: String)
    case llmResponseCountMismatch(expected: Int, actual: Int)

    var errorDescription: String? {
        switch self {
        case .missingSourceLanguage:
            return "未识别到源语言"
        case .llmNotConfigured:
            return "未配置 API 翻译"
        case .invalidLLMEndpoint:
            return "API 地址无效"
        case .invalidLLMResponse:
            return "API 翻译返回格式无效"
        case .llmHTTPError(let statusCode, let body):
            return "API 请求失败：HTTP \(statusCode) \(body)"
        case .llmResponseCountMismatch(let expected, let actual):
            return "API 翻译数量不匹配：期望 \(expected)，实际 \(actual)"
        }
    }
}
