//
//  AppDelegateExt.swift
//  DeepFinder
//
//

import Foundation
import Carbon
import AppKit
import SwiftUI




class EventHandler {
    private var eventSpec: [EventTypeSpec]
    private var eventHandler: EventHandlerRef?
    let app: AppDelegate

    init(_ app: AppDelegate) {
        self.app = app
        eventSpec = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))]
    }

    func start() {
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            let me = Unmanaged<EventHandler>.fromOpaque(userData!).takeUnretainedValue()
            return me.handleEvent(nextHandler: nextHandler, theEvent: theEvent)
        }, eventSpec.count, &eventSpec, pointer, &eventHandler)
    }

    func stop() {
        if let handler = eventHandler { RemoveEventHandler(handler) }
    }

    private func handleEvent(nextHandler: EventHandlerCallRef?, theEvent: EventRef?) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout.size(ofValue: hotKeyID), nil, &hotKeyID)
        if hotKeyID.id == 1 { AppDelegate.toggleState() }
        return noErr
    }
}

extension AppDelegate {
    static var monitoringTimer: Timer?

    static func startDirectoryMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { timer in
            let folderToWatch = settingsModel.settings.monitoringDirectory
            if !folderToWatch.isEmpty {
                timer.invalidate()
                monitor = DirectoryMonitor(pathsToWatch: [folderToWatch])
                monitor?.start()
            }
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, !AppDelegate.previewIsVisible else { return }
        window.orderOut(nil)
        stopMonitoringClicks()
    }

    func startMonitoringClicks() {
        stopMonitoringClicks()
        AppDelegate.globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let window = AppDelegate.mainWindow else { return }
            if !window.frame.contains(event.locationInWindow) && !AppDelegate.previewIsVisible {
                window.orderOut(nil)
                self.stopMonitoringClicks()
            }
        }
    }

    func stopMonitoringClicks() {
        if let monitor = AppDelegate.globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            AppDelegate.globalClickMonitor = nil
        }
    }

    @objc func showFinderView(_ sender: Any?) {
        if AppDelegate.mainWindow == nil {
            guard let mainScreen = NSScreen.main else { return }
            let windowWidth = mainScreen.frame.size.width * 0.25
            let windowHeight = 80.0
            let contentView = ContentView()
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 80), styleMask: [.titled, .fullSizeContentView, .resizable], backing: .buffered, defer: false)
            window.center()
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.setFrameAutosaveName("Find files")
            window.contentView = NSHostingView(rootView: contentView)
            window.minSize = NSSize(width: 400, height: 50)
            window.maxSize = NSSize(width: 1200, height: 800)
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.delegate = self
            window.setContentSize(NSSize(width: windowWidth, height: windowHeight))
            window.center()
            if var rootView = window.contentView as? NSHostingView<ContentView> {
                rootView.rootView.window = window
            }
            AppDelegate.mainWindow = window
        } else if let hostingView = AppDelegate.mainWindow?.contentView as? NSHostingView<ContentView> {
            hostingView.rootView.viewModel.refreshTrigger.toggle()
        }
        NSApp.activate(ignoringOtherApps: true)
        AppDelegate.mainWindow?.makeKeyAndOrderFront(nil)
        startMonitoringClicks()
    }

    static func toggleState() {
        instance?.showFinderView(nil)
    }

    @objc func statusBarButtonClicked(_ sender: Any?) {}

    @objc func menuFinderClicked(_ sender: Any?) {
        showFinderView(sender)
    }

    @objc func quit(_ sender: Any?) {
        NSApplication.shared.terminate(self)
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == AppDelegate.settingsWindow {
            AppDelegate.settingsWindow = nil
        } else {
            NSApplication.shared.hide(nil)
        }
    }

    @objc func menuSettingsClicked(_ sender: Any?) {
        if AppDelegate.settingsWindow == nil {
            let settingsView = SettingsView()
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 300), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.center()
            window.title = "DeepFinder Settings"
            window.setFrameAutosaveName("DeepFinder Settings")
            window.contentView = NSHostingView(rootView: settingsView)
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.delegate = self
            window.makeKeyAndOrderFront(nil)
            if var rootView = window.contentView as? NSHostingView<SettingsView> {
                rootView.rootView.window = window
            }
            AppDelegate.settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        AppDelegate.settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

extension AppDelegate {
    static func addStatusBarMenu() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
        if let button = statusBarItem.button {
            let originalImage = NSImage(named: "ToolBarIcon")
            button.image = rotateImage(originalImage!, byDegrees: 0)
            button.image?.backgroundColor = .black
            button.action = #selector(statusBarButtonClicked(_:))
        }
        let finderViewItem = NSMenuItem(title: "Finder...", action: #selector(menuFinderClicked(_:)), keyEquivalent: "")
        menu.addItem(finderViewItem)
        let separator1 = NSMenuItem.separator()
        menu.addItem(separator1)
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(menuSettingsClicked(_:)), keyEquivalent: "")
        menu.addItem(settingsItem)
        let separator2 = NSMenuItem.separator()
        menu.addItem(separator2)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        statusBarItem.menu = menu
    }

    static func rotateImage(_ image: NSImage, byDegrees degrees: CGFloat) -> NSImage {
        let imageSize = image.size
        let rotatedImage = NSImage(size: imageSize)
        rotatedImage.lockFocus()
        let transform = NSAffineTransform()
        transform.translateX(by: imageSize.width / 2, yBy: imageSize.height / 2)
        transform.rotate(byDegrees: degrees)
        transform.translateX(by: -imageSize.width / 2, yBy: -imageSize.height / 2)
        transform.concat()
        image.draw(in: NSRect(origin: .zero, size: imageSize))
        rotatedImage.unlockFocus()
        return rotatedImage
    }
}

extension AppDelegate {
    static func registerHotKeyIfAvailable(hotKey: (keyCode: UInt32, modifierFlags: UInt32), hotKeyID: EventHotKeyID) -> EventHotKeyRef? {
        var hotKeyRef: EventHotKeyRef? = nil
        let status = RegisterEventHotKey(hotKey.keyCode, hotKey.modifierFlags, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        return status == noErr ? hotKeyRef : nil
    }

    static func registerHotkeys(_ key: String? = nil) -> Bool {
        if let hoteKey = key == nil ? AppDelegate.settingsModel.settings.hotKey  : key {
            var gMyHotKeyID1 = EventHotKeyID(signature: OSType(0x484b3454), id: 1)
            let shortcut1 = hoteKey
            if let hotKey1 = convertShortcutStringToHotKey(shortcut: shortcut1) {
                gMyHotKeyRef1 = registerHotKeyIfAvailable(hotKey: hotKey1, hotKeyID: gMyHotKeyID1)
                if gMyHotKeyRef1 != nil {
                    print("Hotkey \(shortcut1) registered successfully.")
                    return true
                } else {
                    print("Hotkey \(shortcut1) is already in use.")
                }
            }
        }
        return false
    }

    static func unregisterHotkeys() {
        if let ref = gMyHotKeyRef1 {
            UnregisterEventHotKey(ref)
            gMyHotKeyRef1 = nil
            print("Hotkey 1 unregistered successfully.")
        }
    }

    static func shortcutString(from event: NSEvent) -> String {
        var keys = [String]()
        if event.modifierFlags.contains(.command) { keys.append("cmd") }
        if event.modifierFlags.contains(.control) { keys.append("ctrl") }
        if event.modifierFlags.contains(.shift) { keys.append("shift") }
        if event.modifierFlags.contains(.option) { keys.append("opt") }
        if let chars = event.charactersIgnoringModifiers { keys.append(contentsOf: chars.map { String($0) }) }
        return keys.joined(separator: "-")
    }
}

extension AppDelegate {
    static func convertShortcutStringToHotKey(shortcut: String) -> (keyCode: UInt32, modifierFlags: UInt32)? {
        let parts = shortcut.split(separator: "-")
        guard let keyChar = parts.last else { return nil }
        var keyCode: UInt32 = 0
        var modifierFlags: UInt32 = 0
        switch keyChar.lowercased() {
        case "1": keyCode = UInt32(kVK_ANSI_1)
        case "2": keyCode = UInt32(kVK_ANSI_2)
        case "3": keyCode = UInt32(kVK_ANSI_3)
        case "4": keyCode = UInt32(kVK_ANSI_4)
        case "5": keyCode = UInt32(kVK_ANSI_5)
        case "6": keyCode = UInt32(kVK_ANSI_6)
        case "7": keyCode = UInt32(kVK_ANSI_7)
        case "8": keyCode = UInt32(kVK_ANSI_8)
        case "9": keyCode = UInt32(kVK_ANSI_9)
        case "0": keyCode = UInt32(kVK_ANSI_0)
        case "a": keyCode = UInt32(kVK_ANSI_A)
        case "b": keyCode = UInt32(kVK_ANSI_B)
        case "c": keyCode = UInt32(kVK_ANSI_C)
        case "d": keyCode = UInt32(kVK_ANSI_D)
        case "e": keyCode = UInt32(kVK_ANSI_E)
        case "f": keyCode = UInt32(kVK_ANSI_F)
        case "g": keyCode = UInt32(kVK_ANSI_G)
        case "h": keyCode = UInt32(kVK_ANSI_H)
        case "i": keyCode = UInt32(kVK_ANSI_I)
        case "j": keyCode = UInt32(kVK_ANSI_J)
        case "k": keyCode = UInt32(kVK_ANSI_K)
        case "l": keyCode = UInt32(kVK_ANSI_L)
        case "m": keyCode = UInt32(kVK_ANSI_M)
        case "n": keyCode = UInt32(kVK_ANSI_N)
        case "o": keyCode = UInt32(kVK_ANSI_O)
        case "p": keyCode = UInt32(kVK_ANSI_P)
        case "q": keyCode = UInt32(kVK_ANSI_Q)
        case "r": keyCode = UInt32(kVK_ANSI_R)
        case "s": keyCode = UInt32(kVK_ANSI_S)
        case "t": keyCode = UInt32(kVK_ANSI_T)
        case "u": keyCode = UInt32(kVK_ANSI_U)
        case "v": keyCode = UInt32(kVK_ANSI_V)
        case "w": keyCode = UInt32(kVK_ANSI_W)
        case "x": keyCode = UInt32(kVK_ANSI_X)
        case "y": keyCode = UInt32(kVK_ANSI_Y)
        case "z": keyCode = UInt32(kVK_ANSI_Z)
        case "f1": keyCode = UInt32(kVK_F1)
        case "f2": keyCode = UInt32(kVK_F2)
        case "f3": keyCode = UInt32(kVK_F3)
        case "f4": keyCode = UInt32(kVK_F4)
        case "f5": keyCode = UInt32(kVK_F5)
        case "f6": keyCode = UInt32(kVK_F6)
        case "f7": keyCode = UInt32(kVK_F7)
        case "f8": keyCode = UInt32(kVK_F8)
        case "f9": keyCode = UInt32(kVK_F9)
        case "f10": keyCode = UInt32(kVK_F10)
        case "f11": keyCode = UInt32(kVK_F11)
        case "f12": keyCode = UInt32(kVK_F12)
        case "return": keyCode = UInt32(kVK_Return)
        case "tab": keyCode = UInt32(kVK_Tab)
        case "space": keyCode = UInt32(kVK_Space)
        default: return nil
        }
        if parts.contains("cmd") { modifierFlags |= UInt32(cmdKey) }
        if parts.contains("ctrl") { modifierFlags |= UInt32(controlKey) }
        if parts.contains("shift") { modifierFlags |= UInt32(shiftKey) }
        if parts.contains("opt") { modifierFlags |= UInt32(optionKey) }
        return (keyCode, modifierFlags)
    }
}

extension NSFont {
    func withTraits(traits: NSFontDescriptor.SymbolicTraits) -> NSFont? {
        let descriptor = fontDescriptor.withSymbolicTraits(traits)
        return NSFont(descriptor: descriptor, size: pointSize)
    }
}

extension String {
    var fourCharCodeValue: FourCharCode {
        var result: FourCharCode = 0
        if let data = self.data(using: .macOSRoman) {
            for (i, byte) in data.enumerated() {
                result += FourCharCode(byte) << (8 * (3 - i))
            }
        }
        return result
    }
}

extension AppDelegate {
    static func saveConfigsToUserDefaults(settings: DSSettings? = nil) {
        var settingsToSave = settings ?? AppDelegate.settingsModel.settings
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(settingsToSave) {
            UserDefaults.standard.set(encoded, forKey: "settings")
        }
    }

    static func loadConfigsFromUserDefaults() -> DSSettings {
        if let savedSettings = UserDefaults.standard.object(forKey: "settings") as? Data {
            let decoder = JSONDecoder()
            if let loadedSettings = try? decoder.decode(DSSettings.self, from: savedSettings) {
                return loadedSettings
            }
        }
        return DSSettings()
    }

    static func saveCategoriesData(_ categories: [DocumentCategory]) {
        let encoder = JSONEncoder()
        do {
            let encodedData = try encoder.encode(categories)
            UserDefaults.standard.set(encodedData, forKey: "categoriesData")
        } catch {
        }
    }

    static func loadCategoriesData() -> [DocumentCategory]? {
        guard let savedData = UserDefaults.standard.data(forKey: "categoriesData") else {
            return nil
        }
        let decoder = JSONDecoder()
        do {
            let categories = try decoder.decode([DocumentCategory].self, from: savedData)
            return categories
        } catch {
            return nil
        }
    }
}
