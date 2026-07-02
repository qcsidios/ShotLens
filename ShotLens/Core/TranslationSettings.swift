import Foundation

struct TranslationSettings {
    static let didChangeNotification = Notification.Name("ShotLensTranslationSettingsDidChange")
    static let apiEndpointKey = "ShotLens_LLM_APIEndpoint"
    static let apiKeyKey = "ShotLens_LLM_APIKey"
    static let modelKey = "ShotLens_LLM_Model"
    static let defaultFallbackEnabledKey = "ShotLens_LLM_DefaultFallbackEnabled"
    static let defaultAPIEndpoint = "https://api.siliconflow.cn/v1"
    static let defaultAPIKey = "sk-cbmblkvvwgpglgqitsvhoksrvghbpgsqvqfyenpjelcpymzp"
    static let defaultModel = "tencent/Hunyuan-MT-7B"
    static let limitedFreeModelNotice = "腾讯混元模型当前限免；政策结束或出现异常消耗时，默认限免可能停用，建议自备 API。"

    var apiEndpoint: String
    var apiKey: String
    var model: String
    var defaultFallbackEnabled: Bool = true

    var isLLMConfigured: Bool {
        !effectiveAPIEndpoint.isEmpty && !effectiveAPIKey.isEmpty
    }

    var usesDefaultAPIKey: Bool {
        shouldUseDefaultFallback
    }

    var effectiveAPIEndpoint: String {
        let trimmed = apiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        return shouldUseDefaultFallback ? Self.defaultAPIEndpoint : trimmed
    }

    var effectiveAPIKey: String {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return shouldUseDefaultFallback ? Self.defaultAPIKey : trimmed
    }

    var effectiveModel: String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return shouldUseDefaultFallback ? Self.defaultModel : trimmed
    }

    var chatCompletionsURL: URL? {
        let endpoint = normalizedEndpointString
        guard !endpoint.isEmpty else { return nil }

        if endpoint.caseInsensitiveHasSuffixPath("/chat/completions") {
            return URL(string: endpoint)
        }
        if endpoint.caseInsensitiveHasSuffixPath("/models") {
            return URL(string: endpoint.droppingPathSuffix("/models") + "/chat/completions")
        }
        return URL(string: endpoint + "/chat/completions")
    }

    var modelsURL: URL? {
        let endpoint = normalizedEndpointString
        guard !endpoint.isEmpty else { return nil }

        if endpoint.caseInsensitiveHasSuffixPath("/models") {
            return URL(string: endpoint)
        }
        if endpoint.caseInsensitiveHasSuffixPath("/chat/completions") {
            return URL(string: endpoint.droppingPathSuffix("/chat/completions") + "/models")
        }
        return URL(string: endpoint + "/models")
    }

    var apiAvailabilityText: String {
        guard isLLMConfigured else { return "未配置" }
        return usesDefaultAPIKey ? "使用默认限免" : "使用自定义 API"
    }

    var translationAvailabilitySummary: String {
        apiAvailabilityText
    }

    static func load() -> TranslationSettings {
        let defaults = UserDefaults.standard
        let fallbackEnabled = defaults.object(forKey: defaultFallbackEnabledKey) as? Bool ?? true
        let apiKey = defaults.string(forKey: apiKeyKey) ?? ""
        let usesDefaultFallback = fallbackEnabled
            && apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return TranslationSettings(
            apiEndpoint: usesDefaultFallback ? "" : (defaults.string(forKey: apiEndpointKey) ?? ""),
            apiKey: apiKey,
            model: usesDefaultFallback ? "" : (defaults.string(forKey: modelKey) ?? ""),
            defaultFallbackEnabled: fallbackEnabled
        )
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(apiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.apiEndpointKey)
        defaults.set(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.apiKeyKey)
        defaults.set(model.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.modelKey)
        defaults.set(defaultFallbackEnabled, forKey: Self.defaultFallbackEnabledKey)
        defaults.synchronize()
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    static func resetSavedConfiguration() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: apiEndpointKey)
        defaults.removeObject(forKey: apiKeyKey)
        defaults.removeObject(forKey: modelKey)
        defaults.removeObject(forKey: defaultFallbackEnabledKey)
        defaults.synchronize()
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func clearSavedConfiguration() {
        let defaults = UserDefaults.standard
        defaults.set("", forKey: apiEndpointKey)
        defaults.set("", forKey: apiKeyKey)
        defaults.set("", forKey: modelKey)
        defaults.set(false, forKey: defaultFallbackEnabledKey)
        defaults.synchronize()
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    private var shouldUseDefaultFallback: Bool {
        guard defaultFallbackEnabled else { return false }
        return apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var normalizedEndpointString: String {
        effectiveAPIEndpoint
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

}

private extension String {
    func caseInsensitiveHasSuffixPath(_ suffix: String) -> Bool {
        lowercased().hasSuffix(suffix.lowercased())
    }

    func droppingPathSuffix(_ suffix: String) -> String {
        guard caseInsensitiveHasSuffixPath(suffix) else { return self }
        return String(dropLast(suffix.count))
    }
}
