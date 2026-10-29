import AppKit
import Carbon.HIToolbox
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = ClipboardStore()
    private var statusItem: NSStatusItem!
    private var pollTimer: Timer?
    private var hotKey: HotKey?

    private var pasteAutomatically: Bool {
        get { UserDefaults.standard.bool(forKey: "pasteAutomatically") }
        set { UserDefaults.standard.set(newValue, forKey: "pasteAutomatically") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: "ClipStack"
        )

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.store.poll()
        }

        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey)) { [weak self] in
            self?.showMenuAtCursor()
        }

    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild(menu)
    }

    private func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()

        if store.items.isEmpty {
            let empty = NSMenuItem(title: "No clipboard history yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }

        for (index, item) in store.items.enumerated() {
            let key: String
            switch index {
            case 0..<9: key = String(index + 1)
            case 9: key = "0"
            default: key = ""
            }
            let menuItem = NSMenuItem(
                title: Self.menuTitle(for: item),
                action: #selector(selectItem(_:)),
                keyEquivalent: key
            )
            menuItem.keyEquivalentModifierMask = []
            menuItem.target = self
            menuItem.representedObject = item

            switch item.kind {
            case .text:
                menuItem.toolTip = String((item.text ?? "").prefix(1500))
            case .image:
                menuItem.image = store.thumbnail(for: item)
            case .files:
                let paths = item.paths ?? []
                menuItem.toolTip = paths.joined(separator: "\n")
                if let first = paths.first {
                    let icon = NSWorkspace.shared.icon(forFile: first)
                    icon.size = NSSize(width: 16, height: 16)
                    menuItem.image = icon
                }
            }
            menu.addItem(menuItem)
        }

        menu.addItem(.separator())

        let auto = NSMenuItem(
            title: "Paste Automatically",
            action: #selector(togglePasteAutomatically(_:)),
            keyEquivalent: ""
        )
        auto.target = self
        auto.state = pasteAutomatically ? .on : .off
        menu.addItem(auto)

        let login = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        let clear = NSMenuItem(title: "Clear History", action: #selector(clearHistory(_:)), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit ClipStack", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private static func menuTitle(for item: ClipItem) -> String {
        switch item.kind {
        case .text:
            return truncate(collapse(item.text ?? ""), to: 60)
        case .image:
            if let w = item.pixelWidth, let h = item.pixelHeight, w > 0, h > 0 {
                return "Image \(w)×\(h)"
            }
            return "Image"
        case .files:
            let names = (item.paths ?? []).map { ($0 as NSString).lastPathComponent }
            guard names.count > 1 else { return names.first ?? "File" }
            return "\(names.count) files: " + truncate(names.joined(separator: ", "), to: 50)
        }
    }

    private static func collapse(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func truncate(_ text: String, to limit: Int) -> String {
        text.count > limit ? String(text.prefix(limit)) + "…" : text
    }

    private func showMenuAtCursor() {
        let menu = NSMenu()
        rebuild(menu)
        menu.popUp(positioning: menu.items.first, at: NSEvent.mouseLocation, in: nil)
    }

    // MARK: - Actions

    @objc private func selectItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ClipItem else { return }
        store.restore(item)

        if pasteAutomatically, AXIsProcessTrusted() {
            // Give the menu time to close and focus to return to the target app.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                Self.sendCmdV()
            }
        }
    }

    @objc private func togglePasteAutomatically(_ sender: NSMenuItem) {
        let turningOn = !pasteAutomatically
        pasteAutomatically = turningOn
        if turningOn, !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Launch at login toggle failed: \(error)")
        }
    }

    @objc private func clearHistory(_ sender: NSMenuItem) {
        store.clear()
    }

    private static func sendCmdV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(kVK_ANSI_V)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false) else { return }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
