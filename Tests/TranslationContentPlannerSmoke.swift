import CoreGraphics
import Foundation

@main
struct TranslationContentPlannerSmoke {
    static func main() throws {
        try assertChineseOnlyIsExcluded()
        try assertMixedTextIsSplitAndReembedded()
        try assertEnglishOnlyStaysSingleItem()
        print("Translation content planner smoke test passed.")
    }

    private static func assertChineseOnlyIsExcluded() throws {
        let plan = TranslationContentPlan.make(from: [block("已经是中文")])
        guard plan.sourceTexts.isEmpty,
              plan.applying([])?.isEmpty == true else {
            throw TestFailure("Chinese-only blocks must not be sent or covered")
        }
    }

    private static func assertMixedTextIsSplitAndReembedded() throws {
        let original = "保留中文 English 中间文字 OpenAI"
        let plan = TranslationContentPlan.make(from: [block(original)])
        guard plan.sourceTexts == ["English", "OpenAI"] else {
            throw TestFailure("Unexpected mixed-language segments: \(plan.sourceTexts)")
        }
        guard plan.applying(["英语", "开放人工智能"])?.map(\.translatedText) == ["保留中文 英语 中间文字 开放人工智能"] else {
            throw TestFailure("Translations were not embedded back into the original text")
        }
    }

    private static func assertEnglishOnlyStaysSingleItem() throws {
        let plan = TranslationContentPlan.make(from: [block("  Open settings  ")])
        guard plan.sourceTexts == ["Open settings"],
              plan.applying(["打开设置"])?.map(\.translatedText) == ["  打开设置  "] else {
            throw TestFailure("English-only block should preserve surrounding whitespace")
        }
    }

    private static func block(_ text: String) -> TextBlock {
        TextBlock(
            text: text,
            boundingBox: CGRect(x: 10, y: 10, width: 200, height: 24),
            detectedLanguage: "und"
        )
    }
}

private struct TestFailure: Error {
    let message: String
    init(_ message: String) { self.message = message }
}
