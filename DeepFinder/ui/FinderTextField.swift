//
//  FinderTextField.swift
//  DeepFinder
//
//
import AppKit
import SwiftUI

/*

struct FinderTextField: NSViewRepresentable {
    var placeholder: String
    @Binding var text: String
    var onCommit: () -> Void
    
    /// Array of strings to show in the drop-down history list
    var history: [String]
    
    init(_ placeholder: String,
         text: Binding<String>,
         history: [String] = [],
         onCommit: @escaping () -> Void) {
        self.placeholder = placeholder
        self._text = text
        self.history = history
        self.onCommit = onCommit
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSComboBox {
        let comboBox = NSComboBox()
        comboBox.translatesAutoresizingMaskIntoConstraints = false

        // Populate the combo box with history values
        comboBox.addItems(withObjectValues: history)
    //    comboBox.frame.size.height = 160

        // Optional: auto-complete user input from the history list
        // comboBox.completes = true
        
        // Configure appearance
        comboBox.placeholderString = placeholder
        comboBox.stringValue = text
        comboBox.delegate = context.coordinator
        comboBox.isBordered = false
        comboBox.drawsBackground = false
        comboBox.focusRingType = .none
        
        NSLayoutConstraint.activate([
            comboBox.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        return comboBox
    }
    
    func updateNSView(_ nsView: NSComboBox, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    class Coordinator: NSObject, NSComboBoxDelegate {
        var parent: FinderTextField
        
        init(_ parent: FinderTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let comboBox = obj.object as? NSComboBox {
                // Update the SwiftUI binding whenever text changes
                parent.text = comboBox.stringValue
            }
        }
        
        /// This handles the commit when Enter is pressed
        func control(_ control: NSControl,
                     textView: NSTextView,
                     doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onCommit()
                return true
            }
            return false
        }
    }
}
*/

struct FinderTextField: NSViewRepresentable {
    var placeholder: String
    @Binding var text: String
    var onCommit: () -> Void

    init(_ placeholder: String, text: Binding<String>, onCommit: @escaping () -> Void) {
        self.placeholder = placeholder
        self._text = text
        self.onCommit = onCommit
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField(string: text)
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.drawsBackground = false
        textField.target = nil
        textField.focusRingType = .none
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text { nsView.stringValue = text }
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: FinderTextField
        init(_ parent: FinderTextField) { self.parent = parent }
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onCommit()
                return true
            }
            return false
        }
    }
}
