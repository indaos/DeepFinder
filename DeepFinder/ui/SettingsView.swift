//
//  SettingsView.swift
//  DeepFinder
//
//

import Foundation
import SwiftUI


struct DSSettings: Identifiable, Equatable, Codable {
    var id = UUID()
    var hotKey: String = ""
    var numKeyWords: Double = 20
    var openAiKey: String = ""
    var ollamaUrl: String = ""
    var temperature: Double = 0
    var topp: Double = 1
    var numResultFiles: Double = 5000
    var monitoringDirectory: String = ""
    var removeSensitiveData: Bool = true
    var searchHistory: [String] = []
    
    
    mutating func addSearchQuery(_ query: String) {
        guard !query.isEmpty else { return }
        searchHistory.removeAll { $0 == query }
        searchHistory.insert(query, at: 0)
        if searchHistory.count > 10 {
            searchHistory = Array(searchHistory.prefix(10))
        }
    }
}

struct SettingsView: View {
    @State private var apiKey = ""
    @State private var keyShortcut = "______"
    @State private var numKeyWords: Double = 20
    @State private var numResultFiles: Double = 5000
    @State private var ollamaUrl = ""
    @State private var temperature: Double = 0
    @State private var topp: Double = 1
    @State private var monitoringDirectory = ""
    @State private var removeSensitiveData: Bool = true
    @State var isRecording = false
    var window: NSWindow?
    @State private var isExpanded1 = true
    @State private var isExpanded2 = false
    @State private var isExpanded3 = false
    @State private var isExpanded4 = false
    @State var tabSelection: Int = 1
    @State private var categoriesData: [DocumentCategory] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            TabView(selection: $tabSelection) {
                VStack(alignment: .leading, spacing: 24) {
                    DisclosureGroup("OpenAI", isExpanded: $isExpanded1) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("API Key:", systemImage: "key.icloud").font(.headline)
                                TextField("Enter API Key", text: $apiKey)
                                    .frame(width: 200)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            HStack {
                                Label("Temperature: \(String(format: "%.1f", temperature))", systemImage: "thermometer.variable").font(.headline)
                                Slider(value: $temperature, in: 0...2, step: 0.1)
                                    .frame(width: 150)
                            }
                            HStack {
                                Label("Top-p: \(String(format: "%.1f", topp))", systemImage: "target").font(.headline)
                                Slider(value: $topp, in: 0...1, step: 0.1)
                                    .frame(width: 150)
                            }
                            
                            Toggle("Remove sensitive data before sharing with AI", isOn: $removeSensitiveData)
                                .toggleStyle(CheckboxToggleStyle())
                        }
                    }
                    DisclosureGroup("Ollama", isExpanded: $isExpanded2) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("URL:", systemImage: "network").font(.headline)
                                TextField("Enter URL", text: $ollamaUrl)
                                    .frame(width: 200)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                    }
                    DisclosureGroup("HotKey", isExpanded: $isExpanded3) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("HotKey: \(keyShortcut)", systemImage: "keyboard").font(.headline)
                                Button(action: { isRecording ? stopRecording() : startRecording() }) {
                                    Text(isRecording ? "Stop" : "Record")
                                        .frame(maxWidth: .infinity)
                                }
                                .frame(width: 200)
                                .cornerRadius(8)
                            }
                        }
                    }
                    DisclosureGroup("Result Constraints", isExpanded: $isExpanded4) {
                        VStack(spacing: 12) {
                            HStack {
                                Label("Max Keywords: \(Int(numKeyWords))", systemImage: "text.word.spacing").font(.headline)
                                Slider(value: $numKeyWords, in: 1...100, step: 1)
                                    .frame(width: 150)
                            }
                            HStack {
                                Label("Max Results per Keyword: \(Int(numResultFiles))", systemImage: "text.word.spacing").font(.headline)
                                Slider(value: $numResultFiles, in: 1...200000, step: 1000)
                                    .frame(width: 150)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 1))
                .onAppear { fillInSettings() }
                .tabItem { Label("Home", systemImage: "house") }
                .navigationTitle("Home view")
                .tag(1)
                .toolbar(.visible, for: .automatic)
                
                CategoryManagerView(categoriesData: $categoriesData, monitoringDirectory: $monitoringDirectory)
                    .padding(.horizontal)
                    .tabItem { Label("Classification", systemImage: "tray.full") }
                    .navigationTitle("Classification")
                    .tag(2)
                    .toolbar(.visible, for: .automatic)
            }
            HStack {
                Button("Save") {
                    stopRecording()
                    saveSettings()
                    window?.orderOut(nil)
                }
                .padding()
            }
        }
        .frame(width: 500, height: 500)
        .padding()
        .background(KeyCaptureView(isRecording: $isRecording) { capturedKeys, event in
            stopRecording()
            if AppDelegate.registerHotkeys(capturedKeys) {
                keyShortcut = capturedKeys
                saveSettings()
            } else {
                showAlert(capturedKeys)
            }
        })
    }
    
    func showAlert(_ hotkey: String) {
        let alert = NSAlert()
        alert.messageText = "Hotkey \(hotkey) is already in use!"
        alert.informativeText = "Repeat and try installing another hotkey"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        _ = alert.runModal()
    }
    
    private func startRecording() { isRecording = true }
    private func stopRecording() { isRecording = false }
    
    func saveSettings() {
        var settings = DSSettings()
        settings.openAiKey = apiKey
        settings.hotKey = keyShortcut
        settings.numKeyWords = numKeyWords
        settings.ollamaUrl = ollamaUrl
        settings.temperature = temperature
        settings.topp = topp
        settings.numResultFiles = numResultFiles
        settings.monitoringDirectory = monitoringDirectory
        settings.removeSensitiveData = removeSensitiveData
        AppDelegate.saveConfigsToUserDefaults(settings: settings)
        AppDelegate.settingsModel.settings = settings
        AppDelegate.saveCategoriesData(categoriesData)
        AppDelegate.categoriesData = categoriesData
    }
    
    func fillInSettings() {
        let settings = AppDelegate.loadConfigsFromUserDefaults()
        apiKey = settings.openAiKey
        numKeyWords = settings.numKeyWords
        keyShortcut = settings.hotKey
        ollamaUrl = settings.ollamaUrl
        temperature = settings.temperature
        numResultFiles = settings.numResultFiles
        monitoringDirectory = settings.monitoringDirectory
        removeSensitiveData = settings.removeSensitiveData
        topp = settings.topp
        categoriesData = AppDelegate.loadCategoriesData() ?? initialCategoriesData
        AppDelegate.categoriesData = categoriesData
    }
}

struct KeyCaptureView: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onCapture: (String, NSEvent) -> Void
    
    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onCapture = onCapture
        return view
    }
    
    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.isRecording = isRecording
        if isRecording { nsView.startRecording() }
    }
}

class KeyCaptureNSView: NSView {
    var onCapture: ((String, NSEvent) -> Void)?
    var isRecording = false
    override var acceptsFirstResponder: Bool { true }
    func startRecording() { window?.makeFirstResponder(self) }
    func stopRecording() { window?.makeFirstResponder(nil) }
    override func keyDown(with event: NSEvent) {
        if isRecording { onCapture?(shortcutString(from: event), event) }
    }
    private func shortcutString(from event: NSEvent) -> String {
        var keys = [String]()
        if event.modifierFlags.contains(.command) { keys.append("cmd") }
        if event.modifierFlags.contains(.control) { keys.append("ctrl") }
        if event.modifierFlags.contains(.shift) { keys.append("shift") }
        if event.modifierFlags.contains(.option) { keys.append("opt") }
        if let characters = event.charactersIgnoringModifiers { keys.append(contentsOf: characters.map(String.init)) }
        return keys.joined(separator: "-")
    }
}
