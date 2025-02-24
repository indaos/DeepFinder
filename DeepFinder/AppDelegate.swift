//
//  AppDelegate.swift
//  DeepFinder
//
//

import Cocoa
import Carbon
import SwiftUI
import OpenAI

class SettingsModel: ObservableObject {
    @Published var settings: DSSettings = DSSettings()
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    static var mainWindow: NSWindow?
    static var instance: AppDelegate?
    static var globalClickMonitor: Any?
    static var previewIsVisible = false
    static var previewWindow: PreviewWindow?
    static var gMyHotKeyRef1: EventHotKeyRef?
    static var settingsModel: SettingsModel = SettingsModel()
    static var categoriesData: [DocumentCategory] = []
    static var eventHandler: EventHandler?
    static var settingsWindow: NSWindow?
    static var statusBarItem: NSStatusItem!
    static let menu = NSMenu()
    static var separator1: NSMenuItem!
    static var monitor: DirectoryMonitor?
    
    var assistant: ChatAssitant?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.instance = self
        AppDelegate.addStatusBarMenu()
        AppDelegate.settingsModel.settings = AppDelegate.loadConfigsFromUserDefaults()
        AppDelegate.categoriesData = AppDelegate.loadCategoriesData() ?? initialCategoriesData
        AppDelegate.eventHandler = EventHandler(self)
        AppDelegate.eventHandler?.start()
        _ = AppDelegate.registerHotkeys()
        AppDelegate.startDirectoryMonitoring()
    }
    
    func applicationWillTerminate(_ notification: Notification) {}
}
