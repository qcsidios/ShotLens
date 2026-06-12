import CoreGraphics
import Foundation

@main
struct APIOnlyAndOCRLayoutRegressionTest {
    static func main() async {
        testAPIOnlySettingsAndFactory()
        testSentenceFragmentsMergeIntoSemanticBlock()
        testParagraphTailLineMergesIntoOneSemanticBlock()
        testVeryShortParagraphTailLineStillMergesIntoSemanticBlock()
        testTinyChineseSemanticTailMergesAndOrphanPunctuationDrops()
        testVisualStyleSeparatesSectionsAndSkipsIcons()
        testMisreadIconPrefixesAreRemovedFromLabels()
        testMenuItemsStaySeparate()
        print("API-only and OCR layout regression passed")
    }

    private static func testAPIOnlySettingsAndFactory() {
        let defaults = UserDefaults.standard
        let keys = [
            TranslationSettings.apiEndpointKey,
            TranslationSettings.apiKeyKey,
            TranslationSettings.modelKey
        ]
        let originalValues = keys.reduce(into: [String: Any]()) { values, key in
            values[key] = defaults.object(forKey: key)
        }
        defer {
            for key in keys {
                if let value = originalValues[key] {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }

        TranslationSettings(
            apiEndpoint: "https://example.com/v1/chat/completions",
            apiKey: "test-key",
            model: "test-model"
        ).save()

        let settings = TranslationSettings.load()
        assertEqual(settings.apiAvailabilityText, "API 已配置", "configured API should be available")
        assertEqual(settings.translationAvailabilitySummary, "API 已配置", "translation summary should only mention API")
        assertEqual(TranslationProviderFactory.create().name, "大模型翻译", "factory should create only API translator")
    }

    private static func testSentenceFragmentsMergeIntoSemanticBlock() {
        let blocks = [
            block("这是一段需要完整翻译的文字，", x: 10, y: 10, width: 220, height: 22),
            block("它被 OCR 拆成了几行，", x: 10, y: 36, width: 190, height: 22),
            block("但语义上应该合并成一句。", x: 10, y: 62, width: 205, height: 22)
        ]

        let merged = TextLayoutOptimizer.merge(blocks)
        assertEqual(merged.count, 1, "sentence fragments should merge into one semantic block")
        assertEqual(
            merged[0].text,
            "这是一段需要完整翻译的文字， 它被 OCR 拆成了几行， 但语义上应该合并成一句。",
            "merged semantic block should keep complete sentence text"
        )
    }

    private static func testMenuItemsStaySeparate() {
        let blocks = [
            block("文件", x: 10, y: 10, width: 48, height: 22),
            block("编辑", x: 10, y: 42, width: 48, height: 22),
            block("显示", x: 10, y: 74, width: 48, height: 22)
        ]

        let merged = TextLayoutOptimizer.merge(blocks)
        assertEqual(merged.map(\.text), ["文件", "编辑", "显示"], "menu-like labels should remain separate")
    }

    private static func testParagraphTailLineMergesIntoOneSemanticBlock() {
        let bodyStyle = style(fontSize: 22, luminance: 0.12, confidence: 0.96)
        let blocks = [
            block("Long OCR paragraphs often arrive as a stack of line boxes,", x: 40, y: 30, width: 520, height: 22, style: bodyStyle),
            block("and the final line can be much shorter than the previous ones", x: 40, y: 58, width: 500, height: 22, style: bodyStyle),
            block("while still belonging to the same paragraph.", x: 40, y: 86, width: 215, height: 22, style: bodyStyle)
        ]

        let merged = TextLayoutOptimizer.merge(blocks)
        assertEqual(merged.count, 1, "short paragraph tail lines should merge into the same semantic rectangle")
        assertEqual(
            merged[0].boundingBox,
            CGRect(x: 40, y: 30, width: 520, height: 78),
            "merged paragraph should render as one normal rectangle covering all lines"
        )
    }

    private static func testVisualStyleSeparatesSectionsAndSkipsIcons() {
        let headingStyle = style(fontSize: 32, luminance: 0.08, confidence: 0.98)
        let bodyStyle = style(fontSize: 20, luminance: 0.34, confidence: 0.96)
        let iconStyle = style(fontSize: 14, luminance: 0.18, confidence: 0.28, strokeDensity: 0.08)
        let blocks = [
            block("Models", x: 32, y: 20, width: 145, height: 34, style: headingStyle),
            block("○", x: 34, y: 66, width: 16, height: 16, style: iconStyle),
            block("Claude Opus 4.1 introduces stronger coding behavior,", x: 60, y: 66, width: 438, height: 20, style: bodyStyle),
            block("especially in long-context refactors and review workflows.", x: 60, y: 91, width: 410, height: 20, style: bodyStyle)
        ]

        let merged = TextLayoutOptimizer.merge(blocks)
        assertEqual(
            merged.map(\.text),
            [
                "Models",
                "Claude Opus 4.1 introduces stronger coding behavior, especially in long-context refactors and review workflows."
            ],
            "visual style should separate headings from body text and icon-like OCR noise should be skipped"
        )
    }

    private static func testVeryShortParagraphTailLineStillMergesIntoSemanticBlock() {
        let bodyStyle = style(fontSize: 22, luminance: 0.16, confidence: 0.97)
        let blocks = [
            block("DeepSeek V4 Pro generated 190M tokens, which is very verbose in comparison to the", x: 16, y: 300, width: 780, height: 24, style: bodyStyle),
            block("average level and therefore its output should be displayed as one paragraph,", x: 16, y: 329, width: 730, height: 24, style: bodyStyle),
            block("average 43M tokens.", x: 16, y: 358, width: 132, height: 24, style: bodyStyle)
        ]

        let merged = TextLayoutOptimizer.merge(blocks)
        assertEqual(merged.count, 1, "a very short final line must not become its own translated rectangle")
        assertEqual(
            merged[0].boundingBox,
            CGRect(x: 16, y: 300, width: 780, height: 82),
            "merged paragraph rectangle must include the full first-to-last-line vertical region"
        )
    }

    private static func testTinyChineseSemanticTailMergesAndOrphanPunctuationDrops() {
        let bodyStyle = style(fontSize: 24, luminance: 0.14, confidence: 0.96)
        let blocks = [
            block("评估 DeepSeek V4 Pro 时，该模型在智能指数上产生了很长的解释，", x: 48, y: 520, width: 760, height: 26, style: bodyStyle),
            block("因此翻译应继续使用上一段的完整语义框，而不是拆出几个字。", x: 48, y: 550, width: 705, height: 26, style: bodyStyle),
            block("指数。", x: 48, y: 580, width: 46, height: 26, style: bodyStyle),
            block("。", x: 105, y: 580, width: 12, height: 26, style: bodyStyle)
        ]

        let merged = TextLayoutOptimizer.merge(blocks)
        assertEqual(merged.count, 1, "tiny semantic tails must merge and orphan punctuation must be dropped")
        assertEqual(
            merged[0].text,
            "评估 DeepSeek V4 Pro 时，该模型在智能指数上产生了很长的解释， 因此翻译应继续使用上一段的完整语义框，而不是拆出几个字。 指数。",
            "merged text should keep semantic tail content but remove standalone punctuation"
        )
        assertEqual(
            merged[0].boundingBox,
            CGRect(x: 48, y: 520, width: 760, height: 86),
            "merged rectangle should cover the whole paragraph region including tiny tail line"
        )
    }

    private static func testMisreadIconPrefixesAreRemovedFromLabels() {
        let labelStyle = style(fontSize: 24, luminance: 0.42, confidence: 0.92)
        let blocks = [
            block("1 推理", x: 70, y: 150, width: 120, height: 26, style: labelStyle),
            block("巴 输入模态", x: 70, y: 230, width: 190, height: 26, style: labelStyle),
            block("B 输出模态", x: 70, y: 310, width: 190, height: 26, style: labelStyle),
            block("... 上下文窗口", x: 70, y: 390, width: 250, height: 26, style: labelStyle),
            block("Y 总参数", x: 70, y: 470, width: 160, height: 26, style: labelStyle),
            block("凸 活跃参数", x: 70, y: 550, width: 190, height: 26, style: labelStyle),
            block("本 许可证", x: 70, y: 630, width: 160, height: 26, style: labelStyle),
            block("C 模型权重", x: 70, y: 710, width: 190, height: 26, style: labelStyle)
        ]

        let merged = TextLayoutOptimizer.merge(blocks)
        assertEqual(
            merged.map(\.text),
            ["推理", "输入模态", "输出模态", "上下文窗口", "总参数", "活跃参数", "许可证", "模型权重"],
            "misread icon prefixes should be removed instead of being translated"
        )
    }

    private static func block(
        _ text: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        style: TextBlockVisualStyle = .unknown
    ) -> TextBlock {
        TextBlock(
            text: text,
            boundingBox: CGRect(x: x, y: y, width: width, height: height),
            detectedLanguage: text.contains(where: { $0.unicodeScalars.contains(where: { (0x4E00...0x9FFF).contains(Int($0.value)) }) }) ? "zh-Hans" : "en",
            visualStyle: style
        )
    }

    private static func style(
        fontSize: CGFloat,
        luminance: CGFloat,
        confidence: Float,
        strokeDensity: CGFloat = 0.18
    ) -> TextBlockVisualStyle {
        TextBlockVisualStyle(
            confidence: confidence,
            estimatedFontSize: fontSize,
            foregroundRed: luminance,
            foregroundGreen: luminance,
            foregroundBlue: luminance,
            foregroundLuminance: luminance,
            strokeDensity: strokeDensity
        )
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fail("\(message). expected=\(expected) actual=\(actual)")
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("API-only and OCR layout regression failed: \(message)\n", stderr)
        exit(1)
    }
}
