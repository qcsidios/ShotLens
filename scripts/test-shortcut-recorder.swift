import AppKit
import Carbon

@main
struct ShortcutRecorderRegressionTest {
    static func main() {
        _ = NSApplication.shared

        let storageKey = HotKey.storageKey
        let defaults = UserDefaults.standard
        let originalValue = defaults.object(forKey: storageKey)
        defaults.removeObject(forKey: storageKey)
        defer {
            if let originalValue {
                defaults.set(originalValue, forKey: storageKey)
            } else {
                defaults.removeObject(forKey: storageKey)
            }
        }

        let defaultHotKey = HotKey.loadSavedOrDefault(from: defaults)
        guard defaultHotKey == .default else {
            fail("missing saved shortcut did not fall back to default: \(defaultHotKey)")
        }
        guard defaults.data(forKey: storageKey) != nil else {
            fail("missing saved shortcut did not bootstrap default into UserDefaults")
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 120),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        window.contentView = contentView

        let defaultRecorder = ShortcutRecorder(frame: NSRect(x: 20, y: 64, width: 220, height: 36))
        contentView.addSubview(defaultRecorder)
        defaultRecorder.layoutSubtreeIfNeeded()

        let defaultTexts = visibleText(in: defaultRecorder)
        guard defaultTexts.contains(HotKey.default.displayString) else {
            fail("default shortcut is not visible: \(defaultTexts)")
        }
        guard !defaultTexts.contains("按新快捷键") else {
            fail("default shortcut view started in recording state")
        }

        let customHotKey = HotKey(keyCode: 8, modifiers: cmdKey | shiftKey)
        customHotKey.save(to: defaults)
        guard HotKey.loadSavedOrDefault(from: defaults) == customHotKey else {
            fail("custom shortcut was not preserved")
        }

        let recorder = ShortcutRecorder(frame: NSRect(x: 20, y: 20, width: 220, height: 36))
        contentView.addSubview(recorder)
        recorder.layoutSubtreeIfNeeded()

        var changedHotKey: HotKey?
        recorder.onShortcutChanged = { changedHotKey = $0 }

        guard visibleText(in: recorder).contains(customHotKey.displayString) else {
            fail("custom shortcut is not visible: \(visibleText(in: recorder))")
        }

        guard let resetButton = findButton(title: "默认", in: recorder) else {
            fail("reset-to-default button is missing for custom shortcut")
        }
        resetButton.performClick(nil)
        recorder.layoutSubtreeIfNeeded()
        guard HotKey.loadSavedOrDefault(from: defaults) == .default else {
            fail("reset-to-default button did not restore default shortcut")
        }
        guard visibleText(in: recorder).contains(HotKey.default.displayString) else {
            fail("default shortcut is not visible after reset: \(visibleText(in: recorder))")
        }

        customHotKey.save(to: defaults)
        let recordingRecorder = ShortcutRecorder(frame: NSRect(x: 20, y: 20, width: 220, height: 36))
        contentView.addSubview(recordingRecorder)
        recordingRecorder.layoutSubtreeIfNeeded()
        changedHotKey = nil
        recordingRecorder.onShortcutChanged = { changedHotKey = $0 }

        guard window.makeFirstResponder(recorder) else {
            fail("recorder did not become first responder")
        }

        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            characters: ",",
            charactersIgnoringModifiers: ",",
            isARepeat: false,
            keyCode: 43
        ) else {
            fail("failed to create key event")
        }

        _ = recordingRecorder.performKeyEquivalent(with: event)
        guard changedHotKey == nil else {
            fail("shortcut changed without clicking settings button")
        }
        guard HotKey.loadSavedOrDefault(from: defaults) == customHotKey else {
            fail("stored shortcut changed without recording")
        }

        guard let settingsButton = findButton(title: "设置", in: recordingRecorder) else {
            fail("settings button is missing")
        }
        settingsButton.performClick(nil)
        recordingRecorder.layoutSubtreeIfNeeded()

        guard visibleText(in: recordingRecorder).contains("按新快捷键") else {
            fail("clicking settings button did not enter recording state: \(visibleText(in: recordingRecorder))")
        }

        guard recordingRecorder.performKeyEquivalent(with: event) else {
            fail("recorder did not handle command key equivalent after clicking settings button")
        }

        guard changedHotKey == HotKey(keyCode: 43, modifiers: cmdKey) else {
            fail("unexpected hotkey: \(String(describing: changedHotKey))")
        }

        guard window.firstResponder !== recordingRecorder else {
            fail("recorder stayed focused after accepting shortcut")
        }

        print("ShortcutRecorder regression passed")
    }

    private static func visibleText(in view: NSView) -> [String] {
        var values: [String] = []
        if let textField = view as? NSTextField, !textField.stringValue.isEmpty {
            values.append(textField.stringValue)
        }
        if let button = view as? NSButton, !button.title.isEmpty {
            values.append(button.title)
        }
        for subview in view.subviews {
            values.append(contentsOf: visibleText(in: subview))
        }
        return values
    }

    private static func findButton(title: String, in view: NSView) -> NSButton? {
        if let button = view as? NSButton, button.title == title {
            return button
        }
        for subview in view.subviews {
            if let button = findButton(title: title, in: subview) {
                return button
            }
        }
        return nil
    }

    private static func fail(_ message: String) -> Never {
        fputs("ShortcutRecorder regression failed: \(message)\n", stderr)
        exit(1)
    }
}
