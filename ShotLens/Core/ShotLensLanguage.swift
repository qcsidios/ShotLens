import Foundation

enum ShotLensLanguage {
    static func preferredSourceLanguage(for blocks: [TextBlock]) -> String {
        let ranked = blocks
            .map(\.detectedLanguage)
            .filter { !$0.isEmpty && $0 != "und" }
            .reduce(into: [String: Int]()) { counts, language in
                counts[canonicalIdentifier(for: language), default: 0] += 1
            }
            .sorted { lhs, rhs in
                if lhs.value != rhs.value {
                    return lhs.value > rhs.value
                }
                return lhs.key < rhs.key
            }

        return ranked.first?.key ?? "und"
    }

    static func isSameTranslationLanguage(_ sourceIdentifier: String, _ targetIdentifier: String) -> Bool {
        guard
            let sourceLanguage = languageCode(for: sourceIdentifier),
            let targetLanguage = languageCode(for: targetIdentifier)
        else {
            return false
        }

        if sourceLanguage != targetLanguage {
            return false
        }

        if sourceLanguage == "zh" {
            let sourceScript = chineseScript(for: sourceIdentifier)
            let targetScript = chineseScript(for: targetIdentifier)
            return sourceScript == nil || targetScript == nil || sourceScript == targetScript
        }

        return true
    }

    static func canonicalIdentifier(for identifier: String) -> String {
        let language = Locale.Language(identifier: identifier)
        guard let languageCode = language.languageCode?.identifier else {
            return identifier
        }

        if languageCode == "zh" {
            if let script = chineseScript(for: identifier) {
                return "zh-\(script)"
            }
            return "zh-Hans"
        }

        return languageCode
    }

    private static func languageCode(for identifier: String) -> String? {
        Locale.Language(identifier: identifier).languageCode?.identifier
    }

    private static func chineseScript(for identifier: String) -> String? {
        let language = Locale.Language(identifier: identifier)
        if let script = language.script?.identifier {
            return script
        }

        let normalized = identifier.lowercased()
        if normalized.contains("hant") || normalized.contains("-tw") || normalized.contains("-hk") || normalized.contains("-mo") {
            return "Hant"
        }
        if normalized.contains("hans") || normalized.contains("-cn") || normalized.contains("-sg") {
            return "Hans"
        }
        return nil
    }
}
