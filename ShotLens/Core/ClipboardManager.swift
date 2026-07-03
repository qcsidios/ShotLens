import AppKit
import CoreGraphics

/// 剪贴板管理器。同时写入截图（PNG）和纯文本译文。
struct ClipboardManager {
    /// 将刚完成框选的原始截图写入系统剪贴板。
    @MainActor
    func copyImageToClipboard(image: CGImage, pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            pasteboard.setData(pngData, forType: .png)
        }
    }

    /// 将翻译后的截图和译文文本写入系统剪贴板
    /// - Parameters:
    ///   - translatedImage: 标注了译文的合成截图
    ///   - translatedText: 纯文本译文（多行，按原文顺序）
    func copyToClipboard(image: CGImage, text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // 写入 PNG 图片
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            pasteboard.setData(pngData, forType: .png)
        }

        // 写入纯文本（用户粘贴到备忘录、聊天等场景）
        pasteboard.setString(text, forType: .string)
    }
}
