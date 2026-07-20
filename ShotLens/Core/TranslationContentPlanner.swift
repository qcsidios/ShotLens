import Foundation

/// 只把 OCR 文本中的拉丁字母片段送去翻译；已有中文保持原样并参与最终排版。
struct TranslationContentPlan {
    private enum Part {
        case preserved(String)
        case translated(index: Int)
    }

    private struct BlockPlan {
        let original: TextBlock
        let parts: [Part]
    }

    let sourceTexts: [String]
    private let blockPlans: [BlockPlan]

    static func make(from blocks: [TextBlock]) -> TranslationContentPlan {
        var sourceTexts: [String] = []
        var blockPlans: [BlockPlan] = []

        for block in blocks {
            let parts = makeParts(for: block.text, sourceTexts: &sourceTexts)
            guard parts.contains(where: { part in
                if case .translated = part { return true }
                return false
            }) else {
                continue
            }
            blockPlans.append(BlockPlan(original: block, parts: parts))
        }

        return TranslationContentPlan(sourceTexts: sourceTexts, blockPlans: blockPlans)
    }

    func applying(_ translations: [String]) -> [TranslatedBlock]? {
        applyingAvailable(translations.map(Optional.some))
    }

    func applyingAvailable(_ translations: [String?]) -> [TranslatedBlock]? {
        guard translations.count == sourceTexts.count else { return nil }

        return blockPlans.compactMap { plan in
            var values: [String] = []
            for part in plan.parts {
                switch part {
                case .preserved(let value):
                    values.append(value)
                case .translated(let index):
                    guard let translation = translations[index] else { return nil }
                    values.append(translation)
                }
            }
            return TranslatedBlock(original: plan.original, translatedText: values.joined())
        }
    }

    private static func makeParts(for text: String, sourceTexts: inout [String]) -> [Part] {
        guard text.containsHanCharacter else {
            guard text.containsLatinLetter else { return [.preserved(text)] }
            return makeTranslatedPart(text, sourceTexts: &sourceTexts)
        }

        var parts: [Part] = []
        var buffer = ""
        var bufferingHan: Bool?

        func flush() {
            guard !buffer.isEmpty else { return }
            if bufferingHan == true || !buffer.containsLatinLetter {
                parts.append(.preserved(buffer))
            } else {
                parts.append(contentsOf: makeTranslatedPart(buffer, sourceTexts: &sourceTexts))
            }
            buffer = ""
        }

        for character in text {
            let isHan = character.isHanCharacter
            if let bufferingHan, bufferingHan != isHan {
                flush()
            }
            bufferingHan = isHan
            buffer.append(character)
        }
        flush()
        return parts
    }

    private static func makeTranslatedPart(_ text: String, sourceTexts: inout [String]) -> [Part] {
        let leading = String(text.prefix { $0.isWhitespace })
        let trailing = String(text.reversed().prefix { $0.isWhitespace }.reversed())
        let contentStart = text.index(text.startIndex, offsetBy: leading.count)
        let contentEnd = text.index(text.endIndex, offsetBy: -trailing.count)
        let content = String(text[contentStart..<contentEnd])
        guard content.containsLatinLetter else { return [.preserved(text)] }

        var parts: [Part] = []
        if !leading.isEmpty { parts.append(.preserved(leading)) }
        let index = sourceTexts.count
        sourceTexts.append(content)
        parts.append(.translated(index: index))
        if !trailing.isEmpty { parts.append(.preserved(trailing)) }
        return parts
    }
}

private extension String {
    var containsHanCharacter: Bool {
        contains(where: \.isHanCharacter)
    }

    var containsLatinLetter: Bool {
        unicodeScalars.contains { scalar in
            (65...90).contains(Int(scalar.value))
                || (97...122).contains(Int(scalar.value))
                || (0x00C0...0x024F).contains(Int(scalar.value))
        }
    }
}

private extension Character {
    var isHanCharacter: Bool {
        unicodeScalars.contains { scalar in
            (0x3400...0x4DBF).contains(Int(scalar.value))
                || (0x4E00...0x9FFF).contains(Int(scalar.value))
                || (0xF900...0xFAFF).contains(Int(scalar.value))
        }
    }
}
