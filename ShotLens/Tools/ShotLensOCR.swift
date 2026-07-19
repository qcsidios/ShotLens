import Foundation
import CoreGraphics
import CoreImage
import ImageIO
import Vision
import Darwin

@main
struct ShotLensOCR {
    static func main() {
        do {
            guard CommandLine.arguments.count == 2 else {
                throw OCRToolError.missingImagePath
            }

            let imageURL = URL(fileURLWithPath: CommandLine.arguments[1])
            let blocks = try recognizeText(in: imageURL)
            let data = try JSONEncoder().encode(blocks)
            FileHandle.standardOutput.write(data)
            exit(0)
        } catch {
            let message = "\(error.localizedDescription)\n"
            if let data = message.data(using: .utf8) {
                FileHandle.standardError.write(data)
            }
            exit(1)
        }
    }

    private static func recognizeText(in imageURL: URL) throws -> [OCRBlockDTO] {
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw OCRToolError.unreadableImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.automaticallyDetectsLanguage = false
        request.minimumTextHeight = 0.004
        request.recognitionLanguages = ["en-US"]
        request.customWords = [
            "AI",
            "API",
            "OCR",
            "JSON",
            "GitHub",
            "ChatGPT",
            "GPT-4o",
            "Claude",
            "Settings",
            "Search",
            "Continue",
            "Cancel",
            "Copy",
            "Save",
            "Download",
            "Upload"
        ]

        let recognitionImage = enhancedRecognitionImage(from: image) ?? image
        let handler = VNImageRequestHandler(cgImage: recognitionImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results else {
            return []
        }

        let imageSize = CGSize(width: image.width, height: image.height)
        return observations.flatMap { observation -> [OCRBlockDTO] in
            guard let candidate = bestCandidate(from: observation) else { return [] }
            return englishBlocks(
                from: candidate,
                observation: observation,
                image: image,
                imageSize: imageSize
            )
        }
    }

    private static func bestCandidate(from observation: VNRecognizedTextObservation) -> VNRecognizedText? {
        observation.topCandidates(5)
            .filter { $0.string.hasCompleteEnglishToken }
            .max { lhs, rhs in
                candidateScore(lhs) < candidateScore(rhs)
            }
    }

    private static func candidateScore(_ candidate: VNRecognizedText) -> Double {
        let text = candidate.string
        let hanCount = text.unicodeScalars.filter { scalar in
            (0x3400...0x4DBF).contains(Int(scalar.value))
                || (0x4E00...0x9FFF).contains(Int(scalar.value))
                || (0xF900...0xFAFF).contains(Int(scalar.value))
        }.count
        let mixedLanguageBonus = text.containsLatinLetter && hanCount > 0 ? 100.0 : 0
        return mixedLanguageBonus + Double(hanCount * 5) + Double(candidate.confidence)
    }

    private static func englishBlocks(
        from candidate: VNRecognizedText,
        observation: VNRecognizedTextObservation,
        image: CGImage,
        imageSize: CGSize
    ) -> [OCRBlockDTO] {
        let text = candidate.string
        guard text.containsLatinLetter else { return [] }

        let ranges = text.completeEnglishRanges
        let blocks = ranges.compactMap { range -> OCRBlockDTO? in
            let fragment = String(text[range])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(
                    of: #"\bGPT-4[0O]\b"#,
                    with: "GPT-4o",
                    options: [.regularExpression, .caseInsensitive]
                )
            guard fragment.hasCompleteEnglishToken else { return nil }

            let normalizedBox: CGRect
            if range == text.startIndex..<text.endIndex {
                normalizedBox = observation.boundingBox
            } else if let fragmentObservation = try? candidate.boundingBox(for: range) {
                normalizedBox = fragmentObservation.boundingBox
            } else {
                return nil
            }
            let boundingBox = normalizedBox.fromVisionNormalized(to: imageSize)
            guard boundingBox.isSafelyInside(imageSize: imageSize) else { return nil }
            return OCRBlockDTO(
                text: fragment,
                boundingBox: OCRRectDTO(rect: boundingBox),
                detectedLanguage: "en",
                visualStyle: estimateVisualStyle(
                    in: image,
                    boundingBox: boundingBox,
                    confidence: candidate.confidence
                )
            )
        }
        return blocks
    }

    /// 轻量提高低对比度浅色字的边缘，不改变尺寸，因此坐标仍可直接映射回原截图。
    private static func enhancedRecognitionImage(from image: CGImage) -> CGImage? {
        let input = CIImage(cgImage: image)
        guard let colorControls = CIFilter(name: "CIColorControls"),
              let sharpen = CIFilter(name: "CISharpenLuminance") else {
            return nil
        }
        colorControls.setValue(input, forKey: kCIInputImageKey)
        colorControls.setValue(0, forKey: kCIInputSaturationKey)
        colorControls.setValue(1.35, forKey: kCIInputContrastKey)
        guard let contrasted = colorControls.outputImage else { return nil }

        sharpen.setValue(contrasted, forKey: kCIInputImageKey)
        sharpen.setValue(0.35, forKey: kCIInputSharpnessKey)
        guard let output = sharpen.outputImage else { return nil }
        return CIContext(options: [.cacheIntermediates: false]).createCGImage(output, from: input.extent)
    }

    private static func estimateVisualStyle(
        in image: CGImage,
        boundingBox: CGRect,
        confidence: Float
    ) -> OCRStyleDTO {
        let imageRect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let sampleRect = boundingBox.integral.intersection(imageRect)
        guard !sampleRect.isNull,
              sampleRect.width >= 1,
              sampleRect.height >= 1,
              let crop = image.cropping(to: sampleRect) else {
            return OCRStyleDTO(confidence: confidence, estimatedFontSize: max(1, boundingBox.height))
        }

        let sampleWidth = min(72, max(1, Int(sampleRect.width.rounded(.up))))
        let sampleHeight = min(48, max(1, Int(sampleRect.height.rounded(.up))))
        var pixels = [UInt8](repeating: 0, count: sampleWidth * sampleHeight * 4)
        let drewImage = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let baseAddress = buffer.baseAddress,
                  let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(
                    data: baseAddress,
                    width: sampleWidth,
                    height: sampleHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: sampleWidth * 4,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                return false
            }
            context.interpolationQuality = .low
            context.draw(crop, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))
            return true
        }

        guard drewImage else {
            return OCRStyleDTO(confidence: confidence, estimatedFontSize: max(1, boundingBox.height))
        }

        var borderLuminance: [CGFloat] = []
        var allLuminance: [CGFloat] = []
        borderLuminance.reserveCapacity(sampleWidth * 2 + sampleHeight * 2)
        allLuminance.reserveCapacity(sampleWidth * sampleHeight)

        for y in 0..<sampleHeight {
            for x in 0..<sampleWidth {
                let index = (y * sampleWidth + x) * 4
                let alpha = pixels[index + 3]
                guard alpha > 20 else { continue }
                let luminance = Self.luminance(
                    red: pixels[index],
                    green: pixels[index + 1],
                    blue: pixels[index + 2]
                )
                allLuminance.append(luminance)
                if x == 0 || y == 0 || x == sampleWidth - 1 || y == sampleHeight - 1 {
                    borderLuminance.append(luminance)
                }
            }
        }

        let backgroundLuminance = median(borderLuminance) ?? median(allLuminance) ?? 1
        var foregroundRed: CGFloat = 0
        var foregroundGreen: CGFloat = 0
        var foregroundBlue: CGFloat = 0
        var foregroundLuminance: CGFloat = 0
        var foregroundCount: CGFloat = 0

        for y in 0..<sampleHeight {
            for x in 0..<sampleWidth {
                let index = (y * sampleWidth + x) * 4
                let alpha = pixels[index + 3]
                guard alpha > 20 else { continue }
                let red = CGFloat(pixels[index]) / 255
                let green = CGFloat(pixels[index + 1]) / 255
                let blue = CGFloat(pixels[index + 2]) / 255
                let pixelLuminance = Self.luminance(red: pixels[index], green: pixels[index + 1], blue: pixels[index + 2])
                guard abs(pixelLuminance - backgroundLuminance) >= 0.16 else { continue }

                foregroundRed += red
                foregroundGreen += green
                foregroundBlue += blue
                foregroundLuminance += pixelLuminance
                foregroundCount += 1
            }
        }

        let totalPixels = CGFloat(max(1, sampleWidth * sampleHeight))
        guard foregroundCount > 0 else {
            return OCRStyleDTO(
                confidence: confidence,
                estimatedFontSize: max(1, boundingBox.height),
                foregroundRed: backgroundLuminance,
                foregroundGreen: backgroundLuminance,
                foregroundBlue: backgroundLuminance,
                foregroundLuminance: backgroundLuminance,
                strokeDensity: 0
            )
        }

        return OCRStyleDTO(
            confidence: confidence,
            estimatedFontSize: max(1, boundingBox.height),
            foregroundRed: foregroundRed / foregroundCount,
            foregroundGreen: foregroundGreen / foregroundCount,
            foregroundBlue: foregroundBlue / foregroundCount,
            foregroundLuminance: foregroundLuminance / foregroundCount,
            strokeDensity: min(1, foregroundCount / totalPixels)
        )
    }

    private static func luminance(red: UInt8, green: UInt8, blue: UInt8) -> CGFloat {
        let r = CGFloat(red) / 255
        let g = CGFloat(green) / 255
        let b = CGFloat(blue) / 255
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private static func median(_ values: [CGFloat]) -> CGFloat? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }

}

private struct OCRBlockDTO: Encodable {
    let text: String
    let boundingBox: OCRRectDTO
    let detectedLanguage: String
    let visualStyle: OCRStyleDTO
}

private struct OCRStyleDTO: Encodable {
    let confidence: Float
    let estimatedFontSize: CGFloat
    let foregroundRed: CGFloat
    let foregroundGreen: CGFloat
    let foregroundBlue: CGFloat
    let foregroundLuminance: CGFloat
    let strokeDensity: CGFloat

    init(
        confidence: Float,
        estimatedFontSize: CGFloat,
        foregroundRed: CGFloat = 0,
        foregroundGreen: CGFloat = 0,
        foregroundBlue: CGFloat = 0,
        foregroundLuminance: CGFloat = -1,
        strokeDensity: CGFloat = 0
    ) {
        self.confidence = confidence
        self.estimatedFontSize = estimatedFontSize
        self.foregroundRed = foregroundRed
        self.foregroundGreen = foregroundGreen
        self.foregroundBlue = foregroundBlue
        self.foregroundLuminance = foregroundLuminance
        self.strokeDensity = strokeDensity
    }
}

private struct OCRRectDTO: Encodable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat

    init(rect: CGRect) {
        x = rect.origin.x
        y = rect.origin.y
        width = rect.width
        height = rect.height
    }
}

private enum OCRToolError: LocalizedError {
    case missingImagePath
    case unreadableImage

    var errorDescription: String? {
        switch self {
        case .missingImagePath:
            return "缺少图片路径"
        case .unreadableImage:
            return "无法读取截图图片"
        }
    }
}

private extension CGRect {
    func fromVisionNormalized(to imageSize: CGSize) -> CGRect {
        let pixelX = origin.x * imageSize.width
        let pixelY = (1.0 - origin.y - size.height) * imageSize.height
        let pixelWidth = size.width * imageSize.width
        let pixelHeight = size.height * imageSize.height
        return CGRect(x: pixelX, y: pixelY, width: pixelWidth, height: pixelHeight)
    }

    func isSafelyInside(imageSize: CGSize) -> Bool {
        let edgeMargin = max(1, min(imageSize.width, imageSize.height) * 0.002)
        return minX > edgeMargin
            && minY > edgeMargin
            && maxX < imageSize.width - edgeMargin
            && maxY < imageSize.height - edgeMargin
    }
}

private extension String {
    var containsLatinLetter: Bool {
        unicodeScalars.contains { scalar in
            (65...90).contains(Int(scalar.value))
                || (97...122).contains(Int(scalar.value))
                || (0x00C0...0x024F).contains(Int(scalar.value))
        }
    }

    var hasCompleteEnglishToken: Bool {
        let tokens = split { character in
            !character.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
        }
        return tokens.contains { token in
            let value = String(token)
            let latinCount = value.unicodeScalars.filter { scalar in
                (65...90).contains(Int(scalar.value))
                    || (97...122).contains(Int(scalar.value))
                    || (0x00C0...0x024F).contains(Int(scalar.value))
            }.count
            if latinCount >= 2 { return true }
            if value == "A" || value == "a" || value == "I" { return true }
            return latinCount == 1
                && value.unicodeScalars.contains(where: { CharacterSet.decimalDigits.contains($0) })
        }
    }

    /// 只保留由完整英文词组成的片段。中文、图标、装饰符号以及 OCR 产生的孤立字母
    /// 都是硬边界，不让它们进入翻译请求。
    var completeEnglishRanges: [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var segmentStart = startIndex
        var index = startIndex

        func appendSegment(_ segment: Range<String.Index>) {
            var tokens: [Range<String.Index>] = []
            var tokenStart: String.Index?
            var cursor = segment.lowerBound
            while cursor < segment.upperBound {
                let next = self.index(after: cursor)
                if self[cursor].isLatinLetterOrDigit {
                    if tokenStart == nil { tokenStart = cursor }
                } else if let start = tokenStart {
                    tokens.append(start..<cursor)
                    tokenStart = nil
                }
                cursor = next
            }
            if let start = tokenStart { tokens.append(start..<segment.upperBound) }

            var phraseStart: String.Index?
            var phraseEnd: String.Index?
            for token in tokens {
                let tokenText = String(self[token])
                if tokenText.hasCompleteEnglishToken {
                    if phraseStart == nil { phraseStart = token.lowerBound }
                    phraseEnd = token.upperBound
                } else if phraseStart != nil,
                          tokenText.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) }) {
                    phraseEnd = token.upperBound
                } else if let start = phraseStart, let end = phraseEnd {
                    ranges.append(start..<end)
                    phraseStart = nil
                    phraseEnd = nil
                }
            }
            if let start = phraseStart, let end = phraseEnd {
                ranges.append(start..<end)
            }
        }

        while index < endIndex {
            let next = self.index(after: index)
            if self[index].isEnglishOCRBoundary {
                if segmentStart < index { appendSegment(segmentStart..<index) }
                segmentStart = next
            }
            index = next
        }
        if segmentStart < endIndex { appendSegment(segmentStart..<endIndex) }
        return ranges
    }
}

private extension Character {
    var isLatinLetterOrDigit: Bool {
        unicodeScalars.allSatisfy { scalar in
            CharacterSet.decimalDigits.contains(scalar)
                || (65...90).contains(Int(scalar.value))
                || (97...122).contains(Int(scalar.value))
                || (0x00C0...0x024F).contains(Int(scalar.value))
        }
    }

    var isEnglishOCRBoundary: Bool {
        if unicodeScalars.contains(where: { scalar in
            (0x3400...0x4DBF).contains(Int(scalar.value))
                || (0x4E00...0x9FFF).contains(Int(scalar.value))
                || (0xF900...0xFAFF).contains(Int(scalar.value))
        }) {
            return true
        }
        if unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || CharacterSet.whitespacesAndNewlines.contains($0) }) {
            return false
        }
        return !"'’-‐‑–—.,:;!?/\\%+&()[]{}".contains(self)
    }
}
